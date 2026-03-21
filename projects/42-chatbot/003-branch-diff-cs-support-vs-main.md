---
title: "Naoki/cs_support vs main ブランチ差分分析"
date: 2026-03-21
project: 42-chatbot
tags: [branch-diff, migration, cs_support]
---

## 概要

Naoki/cs_supportブランチとmainブランチのsrc/差分を分析。mainへの移植時に不足している可能性がある実装を特定した。

## ブランチ構造の違い

| 項目 | Naoki/cs_support | main |
|------|-----------------|------|
| アーキテクチャ | フラット（`src/app/agents/`, `src/app/graph/`, `src/app/rag/`） | サービス階層（`src/app/services/agent/`, `src/app/services/retrieval/`） |
| ファイル数（src/） | ~87ファイル変更 | ~185ファイル |
| 差分規模 | +5,430行 / -904行 | — |

## mainに存在しない実装（要移植）

### 1. エリア（電力会社）フィルタ — 重要度: 高

- **ブランチ**: `src/app/rag/filters/area_filter.py`（102行）
- **main**: 対応ファイルなし
- **内容**:
  - `AREA_ALIASES`: ~60パターンの電力会社名エイリアス辞書
  - `detect_area(query)`: ユーザークエリから電力会社エリアを検出
  - `apply_area_filter(results, area)`: 検索結果をエリアでフィルタ/ブースト
- **影響**: 地域託送約款など、エリア固有ドキュメントの検索精度に直結

### 2. アクションエージェント＋アクションツール — 重要度: 高

- **ブランチ**: `src/app/agents/action_agent.py` + 5ツール
- **main**: 対応ファイルなし
- **ツール一覧**:
  - `update_address.py` — 住所変更
  - `reset_credentials.py` — 認証情報リセット
  - `invoice_reissue.py` — 請求書再発行
  - `data_export.py` — データエクスポート
  - `update_company_name.py` — 社名変更
- **DGMクライアント依存**: mainのDGMクライアントに以下のwrite系メソッドが不足:
  - `update_location()`, `reset_credentials()`, `invoice_reissue()`, `data_export()`, `update_company_name()`

### 3. Web UI（HTMX + Jinja2）— 重要度: 高

- **ブランチ**: `src/app/web/routes.py`（562行）+ テンプレート群
- **main**: `src/app/web/` ディレクトリ自体が存在しない
- **内容**:
  - HTMX ベースのチャットUI
  - セッション管理（作成・切替・削除・リネーム）
  - SSEストリーミング（`/send-stream`エンドポイント）
  - 進捗表示UI（`progress_settings.html`, `progress_step.html`）
  - Cookie ベースの進捗表示設定

### 4. 評価モジュール — 重要度: 中

- **ブランチ**: `src/evaluation/local.py`（383行）
- **main**: 対応ファイルなし
- **内容**: LangSmith不要のローカル評価。CSV テストケース読み込み → チャットボット実行 → LLM評価スコアリング

### 5. SSE進捗イベント系スキーマ — 重要度: 中

- **ブランチ**: `src/app/api/v1/schemas.py` に追加
- **内容**: `ProgressEvent`, `TaskListEvent`, `TaskProgressEvent`, `ProgressDisplaySettings` — Web UIのリアルタイム進捗表示に必要

## mainに移植済み（構造は異なるが機能あり）

### ✅ マルチエージェントオーケストレーター
- main: `src/app/services/agent/multi_agent/orchestrator.py`
- タスクベース並列実行、Send API、リトライ機構 → 移植済み

### ✅ グラフノード（classifier, escalation, related_questions, merge, execute_task）
- main: `src/app/services/agent/multi_agent/nodes/`
- 5ノードすべて存在

### ✅ ガードレール（coherence, scope）
- main: `src/app/services/guardrails/domain_validators.py`
- 1ファイルに統合されているが機能は移植済み

### ✅ RAGモジュール（keyword_extractor, reranker, query_expansion, ranking）
- main: `src/app/services/retrieval/advanced/`
- ブランチの `src/app/rag/` に対応

### ✅ ツール群（qa_search, charge_breakdown, document_lookup, endpoint_monthly_charge）
- main: `src/app/services/agent/multi_agent/agents/tools/`

### ✅ プロンプトシステム（Markdownベース + loader）
- main: `src/app/services/agent/prompts/`

### ✅ DGMクライアント（read系メソッド）
- main: `src/app/services/dgm_api/client.py`
- ※ write系メソッドは未移植（上記 #2 参照）

## 要確認ポイント（mainでの実装内容を精査が必要）

### A. QAノードレベルリトライ（クエリ再解釈）
- ブランチ: `_reinterpret_query()` でLLMによるクエリ書き換え後にリトライ
- mainのorchestratorにこの機構があるか要確認

### B. contextvarsによる検索結果受け渡し
- ブランチ: `qa_search.py` の `_last_search_results`（thread-local）
- エージェント実行後にオーケストレーターがログ用に取得
- mainの実装方式を確認する必要あり

### C. カテゴリ別エージェント生成
- ブランチ: `create_qa_agent(category=...)`, `create_data_agent(category=...)`
- カテゴリに応じてプロンプト・ツールセットを切り替え
- mainのエージェントファクトリがこれに対応しているか確認

### D. Anthropicプロンプトキャッシュ
- ブランチ: `create_cached_system_message()` で `cache_control={"type": "ephemeral"}`
- mainに同等の実装があるか確認

### E. OrchestratorState の `add_or_reset_list` リデューサー
- `None` でリスト リセット、`list` でextend — タスク/結果蓄積の核心ロジック
- mainのstate定義を確認

### F. conversation_history / keyword_search ツール
- ブランチ: 独立ツールとして存在
- main: multi_agent/agents/tools/ に含まれていない可能性あり

## 次にやること

1. 上記「mainに存在しない実装」#1〜#5 を優先度順に移植
2. 「要確認ポイント」A〜F をmainのコードで確認し、不足があれば追加
3. 特にエリアフィルタ（#1）とアクションエージェント（#2）は機能要件として重要
