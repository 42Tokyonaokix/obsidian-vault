---
title: "RAG メタデータフィルタリングを新アーキテクチャに移植"
date: 2026-03-22
project: 42-chatbot
status: todo
progress: 0/5
priority: high
tags: [rag, metadata, filtering, port, single-react]
---

## 背景・目的

`task/002-rag-metadata-filtering` ブランチで voltage_type / area のハード除外フィルタリングが旧アーキテクチャ（ContextVar パターン、HTMX/Jinja2 UI）で完成済み（9コミット、テスト23件パス）。現在のメインブランチは新アーキテクチャ（single_react + config.metadata + React ウィジェット）に移行済みのため、この機能を新アーキテクチャに移植する。

旧ブランチの作業記録: `projects/42-chatbot/011-020-機能実装とナレッジ基盤構築/014-rag-metadata-filtering.md`

## スコープ

### やること
- フィルタロジック（ハード除外関数 + エリア検出）を新アーキテクチャに移植
- knowledge_search ツールで config.metadata から voltage_type/area を取得してフィルタ適用
- chat.py API で voltage_type/area をリクエストから受け取り astream() に渡す
- React ウィジェットに voltage_type / area 選択 UI を追加
- 選択値の Cookie 永続化

### やらないこと
- DGM API からの自動取得（将来拡張。今回は UI 選択方式）
- ソフト優先（並び替え）ロジックの変更（既存の filter_by_voltage_type はそのまま）

## 設計判断

- **フィルタ方式**: ハード除外（タグ付きで不一致 → 除外）+ null パススルー（タグなし → 通過）。旧ブランチで検証済みの方式をそのまま踏襲
- **area も post-filter**: DB フィルタだと untagged チャンクが除外されてしまうため、voltage_type と同じく post-filter で統一
- **状態の渡し方**: ContextVar ではなく config.metadata（新アーキテクチャ標準）。single_react.py の astream() は既に voltage_type/area パラメータを受け付けて config.metadata に入れている（L292-293, L314-315）
- **Cookie 永続化**: React ウィジェット側で document.cookie に保存。旧実装では urllib.parse.quote/unquote で URL エンコードが必要だった（日本語値の latin-1 エンコードエラー回避）

## タスク

- [ ] フィルタロジック移植（exclude 関数 + detect_area）
- [ ] knowledge_search ツールにフィルタ適用
- [ ] chat.py API に voltage_type / area パラメータ追加
- [ ] React ウィジェットに選択 UI + Cookie 永続化
- [ ] 統合テスト

## 各タスクの詳細

### サブタスク1: フィルタロジック移植（exclude 関数 + detect_area）

- **目的**: 旧ブランチのハード除外関数を新アーキテクチャのフィルタモジュールに追加
- **やること**:
  - `src/app/services/retrieval/advanced/filters/voltage_filter.py` に以下を追加:
    - `exclude_mismatched_voltage_type(results, voltage_type)` — タグ付き不一致を除外、タグなし通過
    - `exclude_mismatched_area(results, area)` — 同上
    - `detect_area(query)` — クエリからエリア名検出（AREA_PATTERNS 辞書）
    - `filter_by_area(results, area)` — エリアのソフト優先（並び替え）
  - ソース: `git show task/002-rag-metadata-filtering:src/app/rag/filters/voltage_filter.py` の L1-200
- **技術的ポイント**:
  - 純粋関数なのでそのままコピー可能。import パスの変更不要（同じファイルに追加）
  - voltage_type の表記揺れ: チャンクメタデータに「高圧特別高圧」「高圧・特別高圧」の2パターンあり、両方にマッチさせる
- **完了条件**: 関数が追加され、単体テストがパスする

### サブタスク2: knowledge_search ツールにフィルタ適用

- **目的**: 検索結果に対して voltage_type/area のハード除外フィルタを適用する
- **やること**:
  - `src/app/services/agent/tools/knowledge_search.py` の `knowledge_search` 関数を修正:
    - `RunnableConfig` パラメータを追加（現在は `query: str` のみ）
    - `config.get("metadata", {})` から `voltage_type` / `area` を取得
    - `retrieval_strategy.retrieve()` の結果に `exclude_mismatched_voltage_type()` と `exclude_mismatched_area()` を適用
  - 旧実装の参考: `git show task/002-rag-metadata-filtering:src/app/agents/tools/qa_search.py`
- **技術的ポイント**:
  - LangGraph の create_react_agent は RunnableConfig を自動的にツールに伝播する。`lookup_contract.py` が同パターンの実装例（L66-71）
  - retrieve() の戻り値は `list[ChunkResult]` で、各 ChunkResult に `.metadata` dict がある。exclude 関数は `result.get("metadata", {})` を期待するので、ChunkResult → dict 変換が必要かもしれない（要確認）
- **完了条件**: knowledge_search が config.metadata の voltage_type/area を使ってフィルタリングした結果を返す

### サブタスク3: chat.py API に voltage_type / area パラメータ追加

- **目的**: フロントエンドから voltage_type / area を受け取り、orchestrator.astream() に渡す経路を開通する
- **やること**:
  - `src/app/api/v1/schemas/chat.py` の `ChatStreamRequest` に `voltage_type: str | None = None` と `area: str | None = None` を追加
  - `src/app/api/v1/chat.py` の `chat_stream()` で `orchestrator.astream()` 呼び出しに `voltage_type=request.voltage_type, area=request.area` を追加（L106-114）
  - single_react.py の astream() は既にこれらのパラメータを受け付けている（L292-293）ので変更不要
- **完了条件**: API に voltage_type/area を POST すると、orchestrator 経由で knowledge_search ツールの config.metadata に到達する

### サブタスク4: React ウィジェットに選択 UI + Cookie 永続化

- **目的**: ユーザーが voltage_type と area を選択できる UI をウィジェットに追加し、選択値を Cookie に保存する
- **やること**:
  - ウィジェットに voltage_type / area のドロップダウン or セレクタを追加
  - 選択値を Cookie に保存（`dgp_voltage_type`, `dgp_area`）、次回ロード時に復元
  - チャット送信時に選択値を API リクエスト body に含める
  - 旧実装の参考: `git show task/002-rag-metadata-filtering:src/app/web/templates/sessions.html`（ドロップダウン UI）
- **技術的ポイント**:
  - 旧実装では Cookie に日本語値を保存する際に `urllib.parse.quote/unquote` で URL エンコードが必要だった。React 側でも `encodeURIComponent` / `decodeURIComponent` で同等の処理が必要
  - voltage_type 選択肢: 低圧 / 高圧 / 特別高圧（+ 未選択）
  - area 選択肢: 北海道電力〜沖縄電力の10社（+ 未選択）
- **完了条件**: ウィジェットで voltage_type/area を選択でき、選択値が Cookie に保存され、チャット送信時に API に渡される

### サブタスク5: 統合テスト

- **目的**: フィルタリングが E2E で正しく動作することを確認
- **やること**:
  - フィルタロジックの単体テスト（exclude 関数、detect_area）
  - knowledge_search ツールが config.metadata からフィルタを適用するテスト
  - API エンドポイントが voltage_type/area を受け取れるテスト
  - 旧ブランチのテスト参考: `git show task/002-rag-metadata-filtering:tests/web/test_filter_cookies.py`
- **完了条件**: 全テストパス

## 前提条件・依存関係

- `feat/tier2-port-and-inquiry-form` ブランチがベース（main にマージ後に着手、または同ブランチ上で作業）
- single_react.py の astream() が既に voltage_type/area を config.metadata に渡す実装済み（変更不要）
- 旧ブランチ `task/002-rag-metadata-filtering` のコードを参照用として使う（直接マージはしない）

## 補足

- 旧ブランチの全実装: 9タスク・9コミット、テスト23件パス（Obsidian ノート 014 参照）
- 旧ブランチの ContextVar モジュール（`contract_context.py`）は不要。config.metadata パターンで代替済み
- CONTRACT_FILTER_ENABLED フラグ（旧 settings.py）は今回不要。フィルタは voltage_type/area が None なら自動スキップする設計
