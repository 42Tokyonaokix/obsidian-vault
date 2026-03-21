---
title: "42-chatbot リポジトリ実装解説"
date: 2026-03-20
project: 42-chatbot
tags: [architecture, rag, langgraph, fastapi, react, documentation]
---

## 概要

42-chatbot リポジトリの実装内容を詳細に解説。DigitalGrid社のエネルギー管理プラットフォーム(DGM)向けAIチャットボットで、ReActエージェント、プラガブルRAG検索、SSEストリーミング、管理画面を備えたエンタープライズシステム。

## 作業内容

### プロジェクト全体像

DGMプラットフォーム上に埋め込みウィジェットとして提供されるAIチャットボット。ユーザーはFAQ質問や契約・電力データの問い合わせを単一の会話で行え、対応できない場合はZendeskへ自動エスカレーションされる。

### アーキテクチャ

```
┌─────────────┐   ┌─────────────┐   ┌──────────────────┐
│  Chat Widget │   │   Admin SPA │   │  DGM Platform    │
│  (React 19)  │   │  (React 19) │   │  (JWT Provider)  │
└──────┬───────┘   └──────┬──────┘   └────────┬─────────┘
       │ SSE              │ REST              │ JWKS
       └──────────┬───────┘                   │
                  ▼                           ▼
            ┌──────────┐              ┌────────────┐
            │  Nginx   │──────────────│  FastAPI   │
            │  (Proxy) │              │  (Python)  │
            └──────────┘              └─────┬──────┘
                                            │
                    ┌───────────┬────────────┼────────────┐
                    ▼           ▼            ▼            ▼
              ┌──────────┐ ┌────────┐ ┌──────────┐ ┌──────────┐
              │PostgreSQL│ │ Redis  │ │  Celery  │ │ DGM API  │
              │+pgvector │ │        │ │ Worker   │ │ Zendesk  │
              │+AGE      │ │        │ │          │ │ OpenAI   │
              └──────────┘ └────────┘ └──────────┘ └──────────┘
```

### 技術スタック

| レイヤー | 技術 |
|---------|------|
| バックエンド | Python 3.12+, FastAPI, SQLAlchemy 2.0 (async), LangGraph (ReActエージェント), LangChain |
| LLM | OpenAI GPT-4o-mini (チャット), text-embedding-3-small (埋め込み) |
| DB | PostgreSQL 16 + pgvector (ベクトル検索) + Apache AGE (グラフDB) |
| キャッシュ/キュー | Redis 7 (キャッシュ + Celeryブローカー) |
| チャットウィジェット | React 19, TypeScript, Shadow DOM, SSE (fetch-event-stream) |
| 管理画面 | React 19, TypeScript, Radix UI, TailwindCSS 4, Cytoscape.js |
| インフラ | Docker Compose, Nginx, Prometheus + Grafana |

### コア機能詳細

#### 1. ReActエージェント

`src/app/services/agent/single_react.py` にてLangGraphベースのReActパターンを実装。以下の7ツールを状況に応じて使い分ける:

| ツール | 機能 |
|--------|------|
| `knowledge_search` | ナレッジベースからRAG検索 |
| `expand_context` | ドメイン知識で補足 |
| `lookup_contract` | DGM APIで契約情報を取得 |
| `lookup_energy` | DGM APIで電力使用量を取得 |
| `calculate` | 数式計算 |
| `energy_calculate` | 電力特化の計算 |
| `zendesk_escalation` | Zendeskチケット作成（エスカレーション） |

ツールはファクトリ関数（クロージャ）で生成され、依存(retrieval_strategy, dgm_client, chat_service)をキャプチャする。モジュールレベルの可変状態を回避する設計。

#### 2. RAG検索パイプライン

`src/app/services/retrieval/` に4つのプラガブルな検索戦略を実装。設定で切り替え可能:

- **Flat Vector** (`flat_vector.py`): pgvectorコサイン類似度 + BM25 + Reciprocal Rank Fusion。ベースライン戦略
- **RAPTOR** : 階層的クラスタリング(HDBSCAN) + LLM要約による多層検索
- **VKG (Vector Knowledge Graph)**: エンティティ/関係抽出 + Apache AGEグラフ走査
- **Hybrid**: 複数戦略をRRFで統合

検索の流れ:
1. クエリをOpenAI text-embedding-3-smallで1536次元ベクトルに変換
2. pgvectorでAPPROVEDチャンクに対してコサイン類似度検索（HNSWインデックス）
3. BM25スコアリング（日本語はfugashi/MeCabトークナイザ、英語は標準トークナイザ）
4. Reciprocal Rank Fusionでランキング統合
5. Top-k結果を返却
6. QueryTraceに検索履歴を記録（戦略、レイテンシ、結果数）

#### 3. ドキュメント取り込み

Celeryバックグラウンドタスクで処理:

```
PDF Upload → pymupdf4llm抽出 → チャンク分割 (PENDING)
  → 管理者レビュー (APPROVE/REJECT/EDIT) ← PRスタイルの3キューシステム
  → 承認済みチャンクをpgvectorにインデックス
  → RAPTOR/VKGの追加処理 (有効時)
```

Celeryキュー: `default`, `pdf_processing`, `embedding`, `raptor`, `vkg`

#### 4. チャットストリーミング (SSE)

`POST /api/v1/chat/stream` でServer-Sent Eventsを返却:

| イベント | 内容 |
|---------|------|
| `status` | エージェントの状態（検索中、API問い合わせ中...） |
| `token` | 生成テキストの差分 |
| `sources` | 参照ソース（文書名、チャンク、スコア） |
| `related` | 関連質問の提案 |
| `done` | 完了 |
| `error` | エラー（ガードレールブロック等） |

#### 5. 入出力ガードレール

入力バリデーション:
- 言語検出（日本語/英語、CJK文字ヒューリスティック）
- 文字数制限（デフォルト4000文字）
- PII検出
- インジェクション防止
- ブラックリストパターン

出力サニタイズ:
- DOMPurifyによるXSS防止（ウィジェット側）

#### 6. 認証・認可

- DGMプラットフォームからJWT (RS256) を受け取り、JWKSエンドポイントで署名検証
- ウィジェットはホストページから`postMessage`でJWTを受信（Shadow DOM内で動作）
- トークンからuser_id, tenant_id, permissionsを抽出
- "chat"パーミッションが必要

#### 7. 会話永続化

- **高速層**: Redisに直近メッセージをキャッシュ
- **永続層**: PostgreSQL (LangGraph AsyncPostgresSaver) でチェックポイント保存
- **セッション管理**: UUID v1のthread_idでスレッドベースの状態管理

### データモデル

| モデル | 用途 | 主要フィールド |
|--------|------|--------------|
| SourceDocument | アップロードPDF管理 | filename, status (UPLOADING→PROCESSING→COMPLETED/FAILED), celery_task_id |
| Chunk | 文書チャンク + 埋め込み | content, embedding (Vector 1536), status (PENDING/APPROVED/REJECTED), HNSWインデックス |
| QueryTrace | 検索クエリの記録 | query, strategy_used, trace_data (JSON), latency_ms |
| GraphEntity | ナレッジグラフノード | entity_type, entity_content, relationship_type, embedding |
| RaptorSummary | RAPTOR階層的要約 | level, cluster_id, summary, embedding, source_chunk_ids |

### API エンドポイント

#### チャット
- `POST /api/v1/chat/stream` — SSEチャットストリーム
- `GET /api/v1/chat/history/{thread_id}` — 会話履歴取得

#### 管理 (`/api/v1/admin/`)
- ドキュメント管理: upload, list
- チャンクレビュー: list, approve, reject, edit
- 会話管理: list, search, thread詳細
- クエリトレース: list, detail
- ナレッジグラフ: entities, relationships, search
- RAPTOR: summaries, trigger-clustering
- Zendesk: tickets CRUD
- ヘルス: admin, metrics (Prometheus)

#### パブリック
- `GET /widget.js` — 埋め込みウィジェットバンドル
- `GET /docs` — OpenAPIドキュメント

### 設計パターン

- **Protocol-Based Abstractions**: RetrievalStrategy, AgentOrchestratorをProtocolで定義。構造的型付けで疎結合
- **Service Registry**: `RETRIEVAL_REGISTRY`, `ORCHESTRATOR_REGISTRY`で遅延ロード（ファクトリ関数）
- **Tool Factories**: クロージャで依存をキャプチャ、モジュールレベル可変状態を排除
- **Async-First**: 全I/Oがノンブロッキング（asyncpg, redis, httpx）
- **Dependency Injection**: FastAPIの`Depends()`でCurrentUser, DbSession等を注入
- **Checkpoint-Based Persistence**: LangGraphのAsyncPostgresSaverでスレッドスコープの会話状態

### Docker構成

| サービス | ポート | 役割 |
|---------|--------|------|
| postgres | 5432 | DB (pgvector + AGE) |
| redis | 6379 | キャッシュ + Celeryブローカー |
| app | 8000 | FastAPIアプリ |
| celery-worker | - | バックグラウンドタスク |
| mock-dgm-api | 9003 | DGM APIモック（開発用） |
| prometheus | 9090 | メトリクス収集 |
| grafana | 3001 | ダッシュボード |
| nginx | 80/443 | リバースプロキシ |

### 監視・オブザーバビリティ

- **Prometheus メトリクス**: llm_requests_total, llm_latency_seconds, llm_tokens_total, celery_queue_depth, FastAPI自動計装
- **Grafana ダッシュボード**: プリコンフィグ済み
- **構造化ログ**: structlogによるJSON形式、相関IDの伝播 (asgi-correlation-id)
- **LangSmithトレーシング**: オプションのLLMオブザーバビリティ

### セキュリティ

- JWT署名検証 (RS256 via JWKS)
- CORS設定（DGMプラットフォームオリジンのホワイトリスト）
- 入出力ガードレール（PII検出、インジェクション防止）
- Pydantic SecretStrによるAPIキー管理
- Nginxレート制限
- HTTPS対応

## 決定事項

- エンタープライズ向けに設計された本格的なAIチャットボットであり、RAG検索・エージェントオーケストレーション・オブザーバビリティ・セキュリティが網羅的に実装されている
- 検索戦略のプラガブル設計により、Flat Vector → RAPTOR → VKG → Hybridと段階的に高度化できる構造

## 次にやること

- 各検索戦略の性能比較・チューニング
- 本番デプロイに向けたセキュリティ強化（コードレビュー 001で検出された課題の対応）
- ドキュメント取り込みパイプラインのテスト拡充
