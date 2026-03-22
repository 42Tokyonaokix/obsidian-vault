---
title: "ディレクトリ構成・機能役割分担・処理フロー図"
date: 2026-03-22
project: 42-chatbot
tags: [architecture, documentation]
---

## 概要

42-chatbot のディレクトリ構成ごとの機能役割分担と、ユーザーリクエストの処理フローを図示・整理した。

## ディレクトリ構成と機能役割

```
42-chatbot/
├── src/app/              ← FastAPI バックエンド（本体）
│   ├── main.py           ← アプリケーションファクトリ・ライフサイクル管理
│   ├── core/             ← インフラ基盤（設定・認証・DB・Redis・DI・ログ・メトリクス）
│   ├── models/           ← SQLAlchemy ORM モデル（Document, Chunk, QueryTrace 等）
│   ├── api/v1/           ← REST API エンドポイント
│   │   ├── chat.py       ← POST /chat/stream（SSEストリーミング）
│   │   ├── health.py     ← ヘルスチェック
│   │   ├── feedback.py   ← フィードバック
│   │   ├── zendesk.py    ← Zendesk エスカレーション
│   │   └── admin/        ← 管理 API（9サブルーター）
│   └── services/         ← ビジネスロジック層
│       ├── agent/        ← LangGraph ReAct エージェント・ツール・プロンプト
│       ├── retrieval/    ← プラガブル RAG 検索（flat_vector/raptor/vkg/hybrid/advanced）
│       ├── llm/          ← LLM サービス（ChatModel・Embeddings）
│       ├── dgm_api/      ← DGM API クライアント（契約・電力データ取得）
│       ├── guardrails/   ← 入出力ガードレール（PII・インジェクション検知）
│       ├── document/     ← ドキュメント処理（PDF解析・チャンキング）
│       ├── cache/        ← Redis 会話キャッシュ
│       ├── tasks/        ← Celery バックグラウンドジョブ
│       ├── raptor/       ← RAPTOR 階層クラスタリング・要約
│       ├── vkg/          ← Vector Knowledge Graph（Apache AGE）
│       └── zendesk/      ← Zendesk API クライアント
│
├── widget/               ← React 19 チャットウィジェット（Shadow DOM, Vite）
├── admin/                ← React 19 管理画面 SPA（React Router 7, TanStack Table, Cytoscape.js）
├── dashboard-frontend/   ← 補助ダッシュボード
│
├── mock-dgm-api/         ← FastAPI DGM API モック（契約・電力・課金データ）
├── mock-platform/        ← Next.js プラットフォームモック（JWT発行・JWKS）
│
├── docker/               ← Docker 設定（app, postgres, nginx, grafana, prometheus）
├── docker-compose*.yml   ← サービスオーケストレーション
│
├── alembic/              ← DB マイグレーション
├── tests/                ← pytest テストスイート
├── scripts/              ← ユーティリティスクリプト（RAG評価・ナレッジseed・診断）
├── analysis/             ← 評価テストフィクスチャ
├── docs/                 ← ドキュメント（アーキテクチャ・API・デプロイ・管理者マニュアル）
└── Makefile              ← 開発コマンド（lint, test, format, up, down）
```

---

## 1. src/app/main.py — アプリケーションファクトリ

### Lifespan で初期化されるサービス（起動時）

| # | サービス | 詳細 |
|---|---------|------|
| 1 | Logging | structlog + JSON 出力 |
| 2 | PostgreSQL | AsyncEngine, AGE 拡張ロード, 5回リトライ (指数バックオフ 2-30s) |
| 3 | Redis | async Redis (decode_responses=True), 5回リトライ |
| 4 | ConversationCache | TTL 1800s, 最大20メッセージ/会話 |
| 5 | ChatModelService | OpenAI GPT-4o-mini (設定変更可) |
| 6 | EmbeddingService | text-embedding-3-small (1536次元) |
| 7 | RetrievalStrategy | flat_vector / raptor / vkg / hybrid / advanced から動的選択 |
| 8 | TraceService | QueryTrace を DB 記録 (保持期間 90日) |
| 9 | LangGraph Checkpointer | PostgreSQL ベース会話状態永続化 |
| 10 | Guardrail Pipelines | 入力・出力ガードレールパイプライン |
| 11 | DGM API Client | httpx.AsyncClient, circuit breaker (閾値5, 回復30s) |
| 12 | Zendesk Client | httpx.AsyncClient, Basic Auth |
| 13 | Agent Orchestrator | single_react (デフォルト) or multi_agent |

### ミドルウェアスタック（外側→内側）

1. **CorrelationIdMiddleware** — リクエスト相関ID付与
2. **CORSMiddleware** — `http://localhost:9002` 許可
3. **StructLogMiddleware** — リクエストコンテキストを structlog にバインド
4. **JWTAuthMiddleware** — RS256 JWT 検証 (JWKS キャッシュ TTL 300s)

### ルーター

- `GET /widget.js` — コンパイル済みウィジェット配信
- `/api/v1` — メイン API ルーター
- `/health`, `/health/detail` — ヘルスチェック
- `/metrics` — Prometheus メトリクス

---

## 2. src/app/core/ — インフラ基盤

### config.py — 22の設定クラス

| 設定クラス | Prefix | 主要フィールド |
|-----------|--------|--------------|
| DatabaseSettings | DB_ | host, port, name, user, password → `postgresql+asyncpg://...` |
| RedisSettings | REDIS_ | host, port, db → `redis://...` |
| AppSettings | APP_ | name, debug, log_level, environment |
| LLMSettings | LLM_ | provider, model_name, temperature, max_tokens |
| EmbeddingSettings | EMBEDDING_ | model_name, dimensions(1536), batch_size |
| RetrievalSettings | RETRIEVAL_ | strategy, top_k(5), rrf_k(60), vector_weight(0.7) |
| GuardrailSettings | GUARDRAIL_ | enable_input, enable_output, max_input_length(4000) |
| AgentSettings | AGENT_ | architecture, recursion_limit(15), timeout(60s) |
| AuthSettings | AUTH_ | jwks_url, algorithm(RS256), issuer, audience |
| StreamSettings | STREAM_ | keepalive_interval(15s), max_tokens(4096) |
| CacheSettings | CACHE_ | conversation_ttl(1800s), max_messages(20) |
| DGMApiSettings | DGM_API_ | base_url, circuit breaker(5失敗/30s回復), retry(3回) |
| ZendeskSettings | ZENDESK_ | subdomain, email, api_token, retry(3回) |
| CalculateSettings | CALCULATE_ | max_power(10000) |
| CelerySettings | CELERY_ | broker_url, concurrency(2), max_memory(500MB) |
| RaptorSettings | RAPTOR_ | umap(50次元/30近傍), hdbscan(min3), max_summary(1024) |
| VKGSettings | VKG_ | entry_points(3), max_hops(2) |
| HybridSettings | HYBRID_ | flat(0.4), raptor(0.3), vkg(0.3) |
| TraceSettings | TRACE_ | enabled, retention_days(90) |
| AdvancedRAGSettings | ADVANCED_RAG_ | multi_query, DenseX, reranking, keyword |
| ClassifierSettings | CLASSIFIER_ | model_name(gpt-4o-mini) |
| MultiAgentSettings | MULTI_AGENT_ | max_retries(2), task_timeout(30s) |

### auth.py — JWT 認証ミドルウェア

- **UserClaims**: user_id, tenant_id, permissions, roles, email, raw_token
- **PUBLIC_PATHS**: /health, /docs, /openapi.json, /widget.js, /metrics
- **REQUIRED_PERMISSIONS**: `{"chat"}`
- RS256 署名検証 → audience/issuer チェック → 有効期限 → 権限チェック

### その他 core ファイル

| ファイル | 役割 |
|---------|------|
| database.py | AsyncEngine 作成, AGE 拡張ロード, DbSession DI |
| redis.py | async Redis クライアント作成, RedisClient DI |
| logging.py | structlog 設定, StructLogMiddleware (request_id, duration_ms) |
| metrics.py | Prometheus カスタムメトリクス (llm_requests, llm_latency, llm_tokens, celery_queue_depth) |
| dependencies.py | 15+ の Annotated DI 型エイリアス + require_admin 認可 |
| celery_app.py | Celery 設定 (Redis broker, ack_late, reject_on_worker_lost) |

---

## 3. src/app/models/ — SQLAlchemy ORM

| テーブル | 主要カラム | 用途 |
|---------|-----------|------|
| source_documents | id, filename, file_path, status(UPLOADING/PROCESSING/COMPLETED/FAILED), celery_task_id, total_chunks | アップロード PDF 管理 |
| chunks | id, content, embedding(Vector 1536), source_document_id, chunk_index, status(PENDING/APPROVED/REJECTED), page_number, section_header, meta(JSONB) | テキストチャンク + ベクトル埋め込み |
| propositions | id, content, source_chunk_id(FK→chunks), embedding(Vector 1536), status | DenseX 原子的事実 |
| raptor_summaries | id, tree_level, cluster_id, language, content, embedding, member_chunk_ids(ARRAY), member_summary_ids(ARRAY), cluster_needs_attention | RAPTOR 階層要約 |
| query_traces | id, thread_id, query, strategy_used, trace_data(JSON), total_results, latency_ms | 検索トレース記録 |
| graph_entities | id, name_ja, name_en, entity_type, description, source_chunk_id, age_node_id, status | VKG エンティティ |
| graph_relationships | id, source_entity_id(FK), target_entity_id(FK), relation_type, source_chunk_id, status | VKG リレーション |
| graph_entity_embeddings | id, entity_id(FK, unique), embedding(Vector 1536) | VKG エンティティ埋め込み |
| widget_feedback | thread_id, message_id, rating(1-5), comment | ウィジェットフィードバック |

全モデルに `TimestampMixin` (created_at, updated_at) 適用。embedding カラムには HNSW インデックス (cosine_ops)。

---

## 4. src/app/api/v1/ — REST API エンドポイント

### 公開 API

| メソッド | パス | 機能 | 依存注入 |
|---------|------|------|---------|
| POST | /chat/stream | SSE ストリーミングチャット | Orchestrator, Guardrails, User, Cache, JWT |
| GET | /chat/history/{thread_id} | 会話履歴取得 (Redis) | User, Cache |
| GET | /health | ヘルスチェック | DB, Redis |
| GET | /health/detail | 詳細ヘルス (PG version, AGE, Redis) | DB, Redis |
| POST | /feedback | フィードバック送信 | User, DB |

### 管理 API（AdminUserDep 必須 = admin ロール必要）

| サブルーター | エンドポイント | 機能 |
|------------|------------|------|
| **upload** | POST /admin/upload | PDF アップロード → Celery タスク |
| | GET /admin/documents/{id}/status | ドキュメント処理状況 |
| **review** | GET /admin/review/chunks | チャンク一覧 (カーソルページネーション) |
| | GET /admin/review/chunks/summary | ステータス別集計 |
| | GET /admin/review/chunks/{id} | チャンク詳細 |
| | POST /admin/review/chunks/{id}/review | APPROVE/REJECT/REVERT |
| | POST /admin/review/chunks/{id}/edit | 内容編集 (自動 APPROVE) |
| | POST /admin/review/chunks/batch | バッチレビュー |
| **conversations** | GET /admin/conversations | 会話一覧 (LangGraph checkpointer 直接クエリ) |
| | GET /admin/conversations/{thread_id} | 会話詳細 |
| **health_admin** | GET /admin/health/status | 全サービス状態・Celery キュー・メトリクス |
| **zendesk_admin** | GET /admin/zendesk/tickets | Zendesk チケット一覧 |
| **raptor** | GET/POST /admin/raptor/summaries/* | RAPTOR 要約レビュー・編集・バッチ |
| | POST /admin/raptor/trigger/{level} | クラスタリング手動トリガー |
| **graph** | GET/POST /admin/graph/entities/* | グラフエンティティレビュー・編集・バッチ |
| | GET /admin/graph/explorer | Cytoscape.js 用ノード/エッジ取得 |
| **traces** | GET /admin/traces | クエリトレース一覧 |
| | GET /admin/traces/{id} | トレース詳細 (trace_data JSON) |
| **proposition** | GET/POST /admin/propositions/* | Proposition レビュー・編集・バッチ |

---

## 5. src/app/services/agent/ — エージェントオーケストレーション

### protocol.py — 契約定義

- **SourceCitation**: chunk_id, content, score, source_document_id, metadata
- **OrchestratorResult**: answer, thread_id, sources, related_questions, model, latency_ms
- **StreamEvent**: event_type (status/token/sources/related/done/error), data
- **AgentOrchestrator Protocol**: ainvoke(), astream()

### single_react.py — ReAct 単一エージェント

- LangGraph `create_react_agent` ラッパー
- ツール: knowledge_search, expand_context, calculate, energy_calculate, lookup_contract, lookup_energy, zendesk_escalation
- ストリーム: status → token → sources → related → done
- ソース抽出: ToolMessage から正規表現でパース、chunk_id で重複排除
- 関連質問: `[RELATED_QUESTIONS]` デリミタで分割

### tools/ — 7つのツールファクトリ（クロージャベース DI）

| ツール | 機能 | 依存 |
|-------|------|------|
| knowledge_search | RAG 検索 + QueryTrace 記録 | retrieval_strategy, trace_service |
| expand_context | 同一ドキュメント内の隣接チャンク取得 | session_factory |
| lookup_contract | DGM API 契約照会 (cache → circuit breaker → API) | dgm_client, cache, circuit_breaker |
| lookup_energy | DGM API 電力照会 (期間フィルタ対応) | dgm_client, cache, circuit_breaker |
| calculate | サンドボックス数式評価 (simpleeval) | settings |
| energy_calculate | エネルギー料金計算 (従量電灯B/低圧電力) | — |
| zendesk_escalation | Zendesk チケット作成 (直近10メッセージ添付) | zendesk_client, conversation_cache |

### multi_agent/ — マルチエージェントオーケストレーター

```
classify_intent → route_or_fanout → execute_task(並列) → merge_results → evaluate_response → add_related_questions
```

- **IntentClassification**: primary_agent(qa/data), category, clarification_needed, tasks
- **Task**: id, description, agent, status(PENDING/IN_PROGRESS/COMPLETED/FAILED/RETRYING)
- **OrchestratorState**: messages, intent_classification, agent_results, tasks, retry_round
- **execute_task_node**: エフェメラル ReAct エージェント生成、タスクタイムアウト、QA ノードレベルリトライ
- **evaluate_response**: 失敗パターン検出 → エスカレーション提案
- **qa_agent / data_agent**: カテゴリ知識付きエフェメラルエージェント

### prompts/ — Markdown プロンプトシステム

- `load_prompt(name)`: Markdown ファイルからプロンプト読み込み
- `@filename.md` ディレクティブで再帰的インクルード展開

---

## 6. src/app/services/retrieval/ — プラガブル RAG 検索

### 5つの検索戦略

| 戦略 | 方式 | 特徴 |
|------|------|------|
| **flat_vector** | pgvector コサイン + BM25 + RRF | ベースライン。APPROVED チャンクのみ |
| **raptor** | チャンク + 要約の collapsed-tree 検索 | 階層的要約を含む。言語フィルタあり |
| **vkg** | エンティティ検索 + Cypher グラフ走査 | Apache AGE で 1..max_hops 走査 |
| **hybrid** | flat_vector + raptor + vkg 並列実行 | asyncio.gather で3戦略同時、重み付き RRF |
| **advanced** | キーワード抽出 + クエリ拡張 + リランク | Multi-query, DenseX, Cohere リランク |

### サポートモジュール

| モジュール | 役割 |
|-----------|------|
| protocol.py | ScoredChunk, RetrievalStrategy Protocol |
| registry.py | 戦略名 → クラスのマッピング |
| trace.py | TraceService — fire-and-forget で QueryTrace を DB 記録 |
| tokenizer.py | MeCab (Fugashi) 日本語形態素解析 |
| rrf.py | Reciprocal Rank Fusion 実装 |

---

## 7. src/app/services/llm/ — LLM サービス

| ファイル | クラス/関数 | 役割 |
|---------|-----------|------|
| service.py | ChatModelService | LangChain BaseChatModel ラッパー (agenerate, astream) |
| factory.py | create_chat_service, create_embedding_service | LLM/Embedding プロバイダファクトリ |
| embeddings.py | EmbeddingService | LangChain Embeddings ラッパー (aembed, aembed_query) |

---

## 8. src/app/services/dgm_api/ — DGM API クライアント

| ファイル | クラス | 役割 |
|---------|-------|------|
| client.py | DGMApiClient | httpx.AsyncClient + tenacity リトライ。get_contract(), get_energy() |
| cache.py | DGMApiCache | Redis ユーザー別キャッシュ (contract TTL 600s, energy TTL 300s) |
| circuit_breaker.py | AsyncCircuitBreaker | CLOSED→OPEN→HALF_OPEN 状態遷移 (5失敗で OPEN, 30s で HALF_OPEN) |
| models.py | ContractInfo, EnergyReading, DGMApiError | レスポンスモデル + カスタム例外 |

---

## 9. src/app/services/guardrails/ — 入出力ガードレール

| ファイル | 機能 |
|---------|------|
| pipeline.py | GuardrailPipeline — バリデータ順次実行、最初の失敗で短絡 |
| validators.py | PII 検出 (カード/メール/電話/マイナンバー)、インジェクション検知、長さ制限、出力 PII マスク |
| domain_validators.py | コヒーレンス検証 (ランダム文字列拒否)、スコープ検証 (競合他社クエリ拒否) |
| patterns.py | PII_PATTERNS, INJECTION_PATTERNS, ERROR_MESSAGES (日英) |
| openai_checks.py | OpenAI Moderation API (プレースホルダー) |

---

## 10. src/app/services/document/ — PDF 処理

| ファイル | 関数 | 役割 |
|---------|------|------|
| extraction.py | validate_pdf | マジックバイト検証、暗号化チェック |
| | is_scanned_pdf | 画像のみ PDF 検出 (テキスト抽出不可、90% 画像カバレッジ) |
| | extract_text | pymupdf4llm で Markdown 形式テキスト抽出 |
| chunking.py | detect_section_boundaries | LLM でセクション境界を検出 (長文は重複グループ分割で並列処理) |
| | create_chunks_from_sections | セクション境界からチャンク辞書を生成 |

---

## 11. src/app/services/cache/ — 会話キャッシュ

- **ConversationCache**: Redis ベースの高速キャッシュ層
  - `get_messages(thread_id)` → list[dict] | None
  - `append_message(thread_id, message)` — max_messages でトリム
  - `clear(thread_id)` — キャッシュ削除
  - TTL ベース自動期限切れ、JSON シリアライズ (ensure_ascii=False)

---

## 12. src/app/services/tasks/ — Celery バックグラウンドジョブ

| タスク | キュー | 機能 |
|-------|-------|------|
| process_pdf | pdf_processing | PDF 検証 → テキスト抽出 → セクション検出 → PENDING チャンク作成 |
| embed_and_index | embedding | APPROVED チャンクの埋め込み生成 (FOR UPDATE ロックで競合防止) |
| cluster_and_summarize | raptor | UMAP + HDBSCAN クラスタリング → 日英要約生成 (Redis 分散ロック) |
| embed_raptor_summary | embedding | RAPTOR 要約の埋め込み生成 |
| extract_entities | vkg | チャンクからエンティティ/リレーション抽出 |
| embed_graph_entity | embedding | グラフエンティティの埋め込み生成 |
| extract_propositions | default | チャンクから Proposition 抽出 |
| embed_proposition | embedding | Proposition の埋め込み生成 |

---

## 13. src/app/services/raptor/ — RAPTOR 階層要約

| ファイル | 機能 |
|---------|------|
| clustering.py | UMAP 次元削減 + HDBSCAN クラスタリング。ノイズポイントは最近傍クラスタに強制割当 |
| summarization.py | JA_SUMMARY_PROMPT / EN_SUMMARY_PROMPT で日英二言語要約。クラスタサイズ → パラグラフ数マッピング |

---

## 14. src/app/services/vkg/ — Vector Knowledge Graph

- **extraction.py**: LLM ベースのエンティティ/リレーション抽出
  - エンティティ種別: contract, tariff_plan, meter, facility, company, regulation
  - ExtractedEntity → ExtractedRelationship → ExtractedGraph
  - EXTRACTION_PROMPT で構造化出力を取得

---

## 15. src/app/services/zendesk/ — Zendesk 連携

| ファイル | 役割 |
|---------|------|
| models.py | TicketCreate (subject, body, email, tags), TicketResponse, ZendeskApiError |
| client.py | ZendeskClient — list_tickets(), create_ticket() (tenacity リトライ) |

---

## 16. widget/ — React チャットウィジェット

### アーキテクチャ

- **Shadow DOM** 内で動作 → ホストページの CSS と完全分離
- **IIFE** (即時実行関数) として widget.js をバンドル
- **adoptedStyleSheets** で CSS 注入 (FOUC ゼロ)
- Vite ビルド → 単一 widget.js (React 同梱、es2020 ターゲット)

### コンポーネント階層

```
Widget (IIFE, Shadow DOM)
└── App
    ├── useAuth() → postMessage で JWT ハンドシェイク
    │   状態遷移: initializing → waiting_auth → authenticated | unauthenticated
    │   最大10回リトライ、500ms 間隔
    ├── AuthGate — 未認証時表示 (ロックアイコン + ローカライズテキスト)
    ├── Bubble — フローティングチャットバブル (DGM ロゴ / X アイコン)
    └── ChatPanel
        ├── MessageList — スクロール可能メッセージ表示 (自動スクロール)
        │   ├── MessageBubble — 個別メッセージ (Markdown レンダリング、👍/👎 フィードバック)
        │   └── StatusMessage — パルスアニメーション状態表示
        ├── InputArea — テキスト入力 (Enter で送信、IME 対応)
        ├── ChipRow — 関連質問ピルボタン (横スクロール)
        └── useConversation()
            ├── messages 状態管理
            ├── useSSE() → fetch-event-stream で SSE ストリーミング
            └── sessionStorage (thread_id 保持)
```

### ユーティリティ

| ファイル | 機能 |
|---------|------|
| i18n.ts | 日英バイリンガル (ステータス、認証ゲート、ウェルカム、サジェスト) |
| markdown.ts | marked + DOMPurify → 安全な HTML 変換 (ヘッダー → ボールド段落) |
| postMessage.ts | CHATBOT_READY ハンドシェイクプロトコル |
| theme.ts | デザイントークン (色、間隔、タイポグラフィ) |
| widget.css.ts | CSS-in-TS (レスポンシブ: desktop/tablet/mobile) |

---

## 17. admin/ — React 管理画面 SPA

### ページ構成

| ページ | 機能 |
|-------|------|
| DashboardPage | サマリーカード (会話数、保留チャンク、Zendesk チケット、ヘルス) |
| ConversationsPage | 検索・フィルタ付き会話一覧 → ConversationDetailPage |
| RAGManagementPage | PDF アップロード (ドラッグ&ドロップ) + チャンクレビューテーブル + ステータス集計 |
| KnowledgeGraphPage | Cytoscape.js グラフ可視化 + エンティティ詳細パネル + 種別フィルタ |
| TracesPage | 実行トレース一覧 + トレース詳細 JSON + ミニグラフ |
| HealthPage | 15秒自動更新、サービス状態・Celery 統計・リクエストメトリクス・LLM 使用量 |
| ZendeskPage | エスカレーションチケット一覧 |
| UsersPage | ユーザー/テナント一覧 (読み取り専用) |

### 技術構成

- React 19 + React Router 7 + BrowserRouter
- TanStack Table v8 (テーブル)
- Cytoscape.js + fcose レイアウト (グラフ)
- Tailwind CSS v4
- Lucide React (アイコン)
- `lib/api.ts`: Bearer JWT 付き fetch ラッパー

---

## 18. dashboard-frontend/ — テナント向けダッシュボード

| ページ | 機能 |
|-------|------|
| MetricsPage | トークン使用量・リクエスト数・レイテンシ (Recharts) |
| SessionsPage | アクティブセッション管理 (kill 機能) |
| IngestPage | ドキュメントアップロード・削除・再インデックス |
| CollectionsPage | ベクトルコレクション管理 (作成/削除/リネーム) |
| PermissionsPage | テナントアクセス制御 |

- React 18 + React Router 6 + TenantProvider コンテキスト
- WebSocket サポート (リアルタイム更新)
- Recharts でチャート表示

---

## 19. mock-dgm-api/ — DGM API モック

### エンドポイント

| メソッド | パス | 機能 |
|---------|------|------|
| GET | /health | ヘルスチェック |
| GET | /api/v1/tenants/{tenant_id}/users/{user_id}/contract | 契約情報 (customer_id, demand_category, charge_menu 等) |
| GET | /api/v1/tenants/{tenant_id}/users/{user_id}/energy?period=YYYY-MM | 電力使用量 (kwh, demand, billing) |
| POST | /api/v1/billing/endpoint/{endpoint_id}/charges | 月額料金計算 (基本/従量/燃料費/再エネ) |
| GET | /api/v1/billing/endpoints | エンドポイント一覧 |
| POST | /api/v1/billing/consignment/charges | 託送料金計算 |

### 内部構成

- **models.py**: DemandContract, RetailContract, ChargeMenu, ConsignmentMenu, EnergyData, FuelCostAdjustmentPrice, RenewableEnergyPrice
- **calculators.py**: EndpointMonthlyChargeCalculator (基本料金/従量料金/夏季/燃料費/再エネ/力率割引)
- **data.py**: テナント別モックデータ (EPC_JP_06688 等)
- **generators.py**: エリア別燃料費調整単価、再エネ賦課金 (3.49 円/kWh)
- JWT 検証: mock-platform JWKS で Bearer トークン検証、tenant_id/user_id 一致確認

---

## 20. mock-platform/ — 認証プラットフォームモック

### エンドポイント

| メソッド | パス | 機能 |
|---------|------|------|
| POST | /api/token | JWT 発行 (RS256, 1時間有効) |
| GET | /api/jwks | 公開鍵 JWK エンドポイント (Cache-Control: 300s) |

### JWT クレーム

```json
{
  "userId": "...",
  "tenantId": "...",
  "permissions": ["chat"],
  "roles": ["user"],
  "email": "...",
  "iss": "mock-dgm-platform",
  "aud": "42-chatbot",
  "exp": "+1h"
}
```

- Next.js 15 App Router
- `jose` ライブラリで RS256 鍵ペア生成・署名
- ログインフォーム → localStorage に JWT 保存

---

## 21. docker/ — Docker 設定

### Dockerfile 構成

| イメージ | ステージ | 内容 |
|---------|--------|------|
| **app** | 1. widget-builder (node:20-alpine) | widget/ ビルド → widget.js |
| | 2. builder (python:3.12-slim) | uv sync で Python 依存解決 |
| | 3. runtime (python:3.12-slim) | 非 root ユーザー (appuser), uvicorn 起動 |
| **nginx** | 1. admin-builder (node:20-alpine) | admin/ SPA ビルド |
| | 2. runtime (nginx:alpine) | nginx.conf + admin dist 配信 |
| **postgres** | 1. pgvector ビルド | pgvector/pgvector:pg16 ベース |
| | 2. AGE ビルド | Apache AGE v1.5.0-rc0 ソースコンパイル |
| | 3. runtime | 初期化スクリプトで pgvector + age 拡張作成 |

### nginx.conf

- リバースプロキシ: `http://app:8000`
- `/admin` → admin SPA 配信
- CORS ヘッダー (widget リクエスト用)

---

## 22. docker-compose — サービス構成

### 全9サービス

| サービス | ポート | 役割 |
|---------|-------|------|
| postgres | 5432 | PostgreSQL 16 + pgvector + AGE (appendonly 永続化) |
| redis | 6379 | Redis 7 (appendonly, キャッシュ + Celery ブローカー) |
| app | 8000 | FastAPI メインアプリ |
| celery-worker | — | Celery ワーカー (5キュー: default, pdf_processing, embedding, raptor, vkg) |
| mock-dgm-api | 9003 | DGM API モック |
| mock-platform | 9002 | 認証プラットフォームモック |
| prometheus | 9090 | メトリクス収集 (15s スクレイプ, 7日保持) |
| grafana | 3001 | ダッシュボード (admin/admin, 匿名閲覧可) |
| nginx | 9080 | リバースプロキシ + admin SPA 配信 |

### 環境別オーバーライド

- **dev**: --reload, APP_DEBUG=true, ソースマウント, env_file
- **prod**: APP_LOG_JSON=true, restart: unless-stopped

---

## 23. alembic/ — DB マイグレーション

| リビジョン | 内容 |
|-----------|------|
| 0002 | chunks テーブル (pgvector 1536次元, HNSW インデックス) |
| 0003 | チャンクレビューキューテーブル |
| 0004a | widget_feedback テーブル |
| 0004b | raptor_summaries テーブル |
| 0005 | graph_entities, graph_relationships, query_traces |
| 0006 | chunks に metadata JSONB カラム追加 |
| 0007 | propositions テーブル |

---

## 24. tests/ — テストスイート

### テスト構成

| カテゴリ | ファイル数 | カバー範囲 |
|---------|----------|-----------|
| api/ | 10 | chat_stream, admin系, health, upload, review, graph, raptor, zendesk, metrics |
| core/ | 6 | auth, celery, config, logging, redis, retry |
| models/ | 3 | chunk, chunk_metadata, document |
| services/ | 10+ | chunking, embedding, extraction, llm, orchestrator, retrieval, tracing, zendesk |
| services/multi_agent/ | 7 | classifier, document_lookup, escalation, merge, models, orchestrator, registry |
| services/retrieval/ | 5 | keyword_extractor, query_expansion, ranking, reranker, voltage_filter |
| mock_dgm_api/ | 2 | billing_endpoints, calculators |

- pytest + pytest-asyncio
- conftest.py: DB/モック/JWT 共有フィクスチャ
- test_alembic_chain.py: マイグレーションチェーン検証

---

## 25. scripts/ — ユーティリティスクリプト

| スクリプト | 機能 |
|-----------|------|
| diagnose_rag_pipeline.py | RAG パイプライン診断 (各ステップの中間結果出力) |
| run_evaluate_local.py | ローカル評価 (テストケース CSV → GPT-4o 採点 → 結果 CSV) |
| run_evaluate_qa_direct.py | QA エージェント直接評価 (orchestrator バイパス) |
| run_rag_eval.py | RAG 評価 (ライブチャットボットに質問送信) |
| run_rag_evaluation.py | RAG 多次元評価 (relevance, accuracy, completeness: 1-5) |
| run_ragas_evaluation.py | RAGAS 評価 (Faithfulness, AnswerRelevancy, ContextPrecision) |
| seed_knowledge.py | ナレッジ初期化 (YAML/MD → chunks + source_documents + embedding) |

---

## 26. docs/ — ドキュメント

| ファイル | 内容 |
|---------|------|
| architecture.md/.en.md | システムアーキテクチャ図・コンポーネント説明 |
| api-reference.md/.en.md | REST API エンドポイント一覧 |
| deployment.md/.en.md | デプロイ手順 (Docker Compose, Kubernetes) |
| developer-guide.md/.en.md | 開発者セットアップ・ワークフロー |
| admin-manual.md/.en.md | 管理画面使用マニュアル |
| superpowers/specs/ | 設計仕様書 (Tier1 知識チャンク、Tier2 操作分類) |
| superpowers/plans/ | 実装計画 |

---

## 27. analysis/ — 評価データ

- `eval_tests/` — RAG 評価テストデータ・結果 CSV
  - rag_evaluation.csv — テスト質問 + 期待回答
  - tier1_制度説明.csv — ドメイン特化テストケース
  - *_results.csv — 評価実行結果

---

## 28. Makefile — 開発コマンド

| ターゲット | コマンド |
|-----------|---------|
| up | widget ビルド → docker-compose (dev オーバーライド) 起動 |
| down | コンテナ停止 |
| lint | ruff check + mypy |
| format | ruff format/fix |
| test | pytest -v |
| test-quick | pytest -x -q (fail fast) |
| migrate | alembic upgrade head |
| migrate-create | alembic revision --autogenerate |

---

## 処理フロー

```
┌─────────────────────────────────────────────────────────────┐
│              ユーザー（ブラウザ）                               │
│           Chat Widget（React + Shadow DOM）                   │
└───────────────────────┬─────────────────────────────────────┘
                        │ POST /api/v1/chat/stream
                        │ Bearer JWT
                        ▼
┌─────────────────────────────────────────────────────────────┐
│                   FastAPI Server :8000                       │
│                                                             │
│  ① ミドルウェア                                              │
│     CorrelationId → CORS → StructLog → JWT認証              │
│                        │                                     │
│  ② chat_stream() ハンドラ                                    │
│     言語検出 → 入力ガードレール → Redis にユーザーメッセージ保存   │
│                        │                                     │
│  ③ SingleReactOrchestrator（LangGraph）                      │
│     ┌──────────────────────────────────────────────┐        │
│     │ PostgreSQL からチェックポイント履歴をロード       │        │
│     │ システムプロンプト + ユーザーコンテキスト構築      │        │
│     │                                              │        │
│     │ ループ（最大15回）:                             │        │
│     │   LLM がツールを選択                           │        │
│     │     ├─ knowledge_search  → RAG 検索           │        │
│     │     ├─ expand_context    → 関連チャンク取得     │        │
│     │     ├─ lookup_contract   → DGM API 契約照会    │        │
│     │     ├─ lookup_energy     → DGM API 電力照会    │        │
│     │     ├─ calculate         → 料金計算            │        │
│     │     ├─ zendesk_escalation→ チケット作成         │        │
│     │     └─ （回答）          → トークン生成         │        │
│     │                                              │        │
│     │   status / token イベントをリアルタイム送出      │        │
│     └──────────────────────────────────────────────┘        │
│                        │                                     │
│  ④ 出力ガードレール → Redis にボット応答キャッシュ              │
│     sources / related / done イベント送出                     │
└───────────────────────┬─────────────────────────────────────┘
                        │ SSE Stream
                        │ (status, token, sources, related, done)
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  Widget がリアルタイムレンダリング                              │
│  ・status → スピナー表示                                     │
│  ・token  → メッセージをストリーミング表示                      │
│  ・sources → 参照元をメッセージ下に表示                        │
│  ・related → フォローアップ質問を提示                          │
│  ・done   → 入力欄を有効化                                   │
└─────────────────────────────────────────────────────────────┘
```

## RAG 検索パイプライン詳細

```
knowledge_search(query)
  │
  ├─ 戦略選択（flat_vector / raptor / vkg / hybrid / advanced）
  │
  ├─ EmbeddingService でクエリをベクトル化（text-embedding-3-small）
  │
  ├─ pgvector コサイン類似度検索（APPROVED チャンクのみ）
  │   + BM25 スコアリング（日本語 MeCab トークナイズ）
  │   + RRF 融合（ハイブリッド時）
  │
  ├─ voltage_type / area メタデータフィルタ適用
  │
  ├─ QueryTrace を DB に記録（監査・分析用）
  │
  └─ ソース引用付きで結果を返却
```

## 技術スタック

| レイヤー | 技術 |
|---------|------|
| バックエンド | FastAPI, LangGraph, Celery, SQLAlchemy 2.0 async |
| データベース | PostgreSQL 16 + pgvector + Apache AGE |
| キャッシュ | Redis 7 (async) |
| LLM | OpenAI GPT-4o + text-embedding-3-small |
| 認証 | JWT (RS256) + JWKS |
| Widget | React 19, Vite, Shadow DOM |
| Admin | React 19, React Router 7, TanStack Table, Cytoscape.js |
| Dashboard | React 18, React Router 6, Recharts |
| 監視 | Prometheus, Grafana, structlog |
| コンテナ | Docker Compose, Nginx |
