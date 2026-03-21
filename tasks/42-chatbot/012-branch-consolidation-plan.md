---
title: "ブランチ統合: 4ブランチを feat/tier2-port-and-inquiry-form に集約"
date: 2026-03-22
project: 42-chatbot
status: todo
progress: 0/7
priority: high
tags: [git, merge, branch-consolidation, architecture-migration]
---

## 背景・目的

ユーザーのアイデア: 「どうやら一つ一つのタスクを別々のブランチにプッシュしていたらしいのだが、どれかひとつのブランチに統合したいと考えているんだ。昨日から自分達が作ってきたブランチを全部統合するためのプランを立て直してほしい」

4つの分散ブランチ（IME fix, dashboard, docker fix, task/002）を `feat/tier2-port-and-inquiry-form` に統合し、mainへのクリーンなマージ可能状態を作る。task/002 は旧アーキテクチャ（`src.app.*` import）で実装されているため merge 不可。手動移植+import書き換えで対応する。

## 要件定義

PM Agentが整理した要件。

- **目的**: 複数ブランチに散らばった最近2日間の作業を `feat/tier2-port-and-inquiry-form` に統合し、mainへのクリーンなマージ可能状態を作ること。ブランチが分散したまま各ブランチで作業が続くと、統合難易度が時間とともに指数関数的に上がるため、今が最もコストの低いタイミング。
- **スコープ**:
  - やること: 4ブランチの統合（ime-fix, docker-fix, dashboard, task/002）+ PR整理 + 動作確認
  - やらないこと: PR #11（Naoki/useful_features）の統合（2週間前の別作業）、mainへの実際のマージ（レビュー後のフェーズ）
- **成功基準**:
  1. `feat/tier2-port-and-inquiry-form` に対象4ブランチの変更がすべて含まれている
  2. `docker compose up` でサービスが正常起動する
  3. 旧パス `src/app/graph/`, `src/app/agents/tools/` への参照が残っていない
  4. 重複PR（#30, #31）がクローズされている

## 技術検討

Architect Agentの技術的分析。

### 統合対象ブランチ

**現在のブランチ `feat/tier2-port-and-inquiry-form`**（origin/mainから19コミット先行）
- 既に含む: `refactor/knowledge-chunks-reorganize` + `user-data-access` のすべて
- 新アーキテクチャ: `app.services.*`、Protocol+Factory方式、StructLog、DI注入
- **未コミットファイルあり**: `src/app/api/v1/zendesk.py`, `widget/src/components/EscalationOffer.tsx`

| # | ブランチ | コミット | ファイル | コンフリクト | 統合方式 |
|---|---|---|---|---|---|
| 1 | `fix/ime-and-delimiter-leak` | 1 | 6 | なし | git merge |
| 2 | `dashboard-rebuild` | 1 | 7（全新規） | なし | git merge |
| 3 | `fix/docker-and-widget-cross-origin` | 1 | 5 | ChatPanel.tsx, Dockerfile | git merge + 手動解消 |
| 4 | `task/002-rag-metadata-filtering` | 20 | 39 | **全面的** | 手動移植 |

※ `feat/tier2-escalation-enrichment` は `task/002` に完全包含済み（個別対応不要）

### アーキテクチャ差異（task/002 vs 現ブランチ）

| 項目 | task/002（旧） | 現ブランチ（新） |
|---|---|---|
| importパス | `src.app.*` | `app.*` / `app.services.*` |
| 設定 | `src.shared.config.settings.Settings`（フラット） | `app.core.config`（群別クラス） |
| エージェント | `src/app/agents/` | `src/app/services/agent/` |
| オーケストレーター | `src/app/graph/orchestrator.py` | `src/app/services/agent/multi_agent/orchestrator.py` |
| RAG | `src/app/rag/` | `src/app/services/retrieval/` |
| Mock API | `mock_server/` | `mock-dgm-api/` |
| ログ | 標準logging | StructLog |
| DI | なし | FastAPI Depends |

### 既にポート済みの機能（現ブランチに存在）
- `src/app/services/summary.py` — TAG_DEFINITIONS, StructuredSummary, generate_structured_summary() (193行)
- `src/app/services/agent/multi_agent/nodes/escalation.py` — make_evaluate_response_node, make_zendesk_ticket_node
- OrchestratorState に business_tag フィールド
- `src/app/api/v1/zendesk.py`（未コミット）
- `widget/src/components/EscalationOffer.tsx`（未コミット）

### コンフリクト詳細

**fix/docker-and-widget-cross-origin:**
- `docker/app/Dockerfile`: 両方がgcc/g++追加。現ブランチは`build-essential`含む上位互換 → 現ブランチ側採用
- `widget/src/components/ChatPanel.tsx`: querySelector方式 vs props方式 → props方式に統一推奨（`document.currentScript`キャプチャが技術的に優位）

**task/002-rag-metadata-filtering:**
- `git merge` 不可。`src.app.*` vs `app.*` のimportパス差異が全15 Pythonファイルに及ぶ
- `src.shared.config.settings.Settings` と `app.core.config` の構造的不整合
- `src/app/graph/orchestrator.py` が `src.app.agents.data_agent` をimport（現アーキに存在しない）

### task/002 から移植する機能のマッピング

| 機能 | task/002のパス | 新アーキの移植先 |
|---|---|---|
| ContractContext (ContextVar) | `src.app.agents.tools.contract_context` | `app.services.agent.tools.contract_context`（新規） |
| VoltageFilter | `src.app.rag.filters.voltage_filter` | `app.services.retrieval.filters.voltage_filter`（新規） |
| RAG search + filter統合 | `src.app.agents.tools.qa_search` | `app.services.agent.tools.knowledge_search.py` に追記 |
| Admin analytics API | `src.app.api.admin.analytics` | `app.api.admin.analytics`（新規） |
| Admin schemas | `src.app.api.admin.schemas` | `app.api.admin.schemas`（新規） |
| Summary追加関数 | `get_session_structured_summary`, `get_session_summary` | `app.services.summary.py` に追記 |
| Feedback API改善 | `src.app.api.v1.feedback` | `app.api.v1.feedback` に追記 |
| Grafana dashboard | `docker/grafana/provisioning/dashboards/unresolved-analysis.json` | そのままコピー |
| ナレッジチャンク | `faq_手続き案内.yaml` | そのままコピー |

### 移植対象外（明示的除外）
- `src/app/web/routes.py` および `src/app/web/templates/` 配下全て（HTMX/Jinja2 UI → React widgetに統一）
- `docs/architecture*.drawio`, `docs/observability-*.md`（設計ドキュメント）
- `uv.lock`（ターゲットブランチで `uv lock` を再実行して生成）
- `tests/web/` 配下（Web UI テスト → 除外対象UIに依存）

### 技術的リスク
1. **高**: task/002の`orchestrator.py`は現ブランチと構造が大きく異なる（旧: フラット関数、新: Protocol+Factory）。機械的import置換では不十分で設計パターンの翻訳が必要
2. **高**: `summary.py` の差分統合 — 両ブランチで独立に実装されたため意味的コンフリクトの可能性
3. **中**: `contract_context` の ContextVar が AsyncIO スコープ越えで無効化される可能性
4. **低**: `document.currentScript` の ESM非対応（現在はIIFE形式のため問題なし）

## 議論サマリー

Critic Agentによる PM・Architectの見解の突き合わせ。

### 合意点
1. 統合先ブランチは `feat/tier2-port-and-inquiry-form`（mainから19コミット先行、既にエスカレーション移植+問い合わせフォーム搭載）
2. task/002 の `git merge` は不可（importパス差異が全ファイルに及ぶ）
3. 低リスクブランチ（IME, dashboard, docker）を先行統合
4. task/002のHTMX/Jinja2 Web UIは移植しない（React widgetに統一）
5. PR #11は対象外（2週間前の別作業）

### 論点と裁定

**論点1: task/002の統合手法**
- PM: merge方式 or 手動移植（両方残す）
- Architect: 手動移植一択
- **裁定**: Architectの手動移植を採用。importパスが全面的に異なり、cherry-pickでもコンフリクトが発生するため。

**論点2: タスク粒度**
- PM: task/002を1タスクとして扱う（2-4h）
- Architect: task/002を3タスクに分解（コア / Orchestrator / Summary+Admin）
- **裁定**: Architectの分解を採用。各フェーズで動作確認を入れるべき。ただし`summary.py`は既に存在するため差分統合として扱う。

**論点3: 動作確認のタイミング**
- PM: 低リスク統合後+task/002統合後の2回
- Architect: 最終タスクで1回
- **裁定**: PMの2回確認を採用。task/002移植前にベースライン確認で問題切り分けを容易にする。

**論点4: 未コミットファイルの扱い**
- 両者とも明示的に言及なし
- **裁定**: `zendesk.py`, `EscalationOffer.tsx` を最初にコミットしてベースライン確定。後続タスクでの混乱を防ぐ。

## 設計判断

- **task/002は`git merge`不可、手動移植**: importパス`src.app.*` vs `app.*`の差異が全15 Pythonファイルに及ぶため
- **ChatPanel.tsxはprops方式に統一**: `document.currentScript`キャプチャ→props渡しが技術的に優位（querySelector方式のファイル名依存を排除）
- **HTMX/Jinja2 Web UIは移植しない**: React widgetベースに統一。2つのUI系統の並走はメンテコスト高
- **task/002のcherry-pickは不採用**: ほぼ全ファイルでコンフリクトが発生し、手動移植とコスト同等

## タスク

- [ ] T1: 未コミットファイルのステージング
- [ ] T2: 低リスク3ブランチの統合（IME + dashboard + docker）
- [ ] T3: 中間動作確認
- [ ] T4: task/002 RAGフィルタ コアモジュール移植
- [ ] T5: task/002 Orchestrator + State 統合
- [ ] T6: task/002 Summary差分統合 + Admin API + Feedback API移植
- [ ] T7: 統合テスト + PRクリーンアップ

## 各タスクの詳細

### T1: 未コミットファイルのステージング

- **目的**: 後続タスクのベースラインを確定させる
- **やること**:
  - `src/app/api/v1/zendesk.py`（未コミット）をコミット
  - `widget/src/components/EscalationOffer.tsx`（未コミット）をコミット
  - `analysis/` 配下の未コミットファイルを `.gitignore` に追加 or コミット
- **技術的ポイント**: これらは `feat/tier2-escalation-enrichment` の機能を現アーキに移植した途中成果物
- **前提/依存**: なし（最初に実行）
- **完了条件**: `git status` でuntracked fileがクリーン
- **見積**: 15min

### T2: 低リスク3ブランチの統合

- **目的**: コンフリクトリスクの低いブランチから順に統合し、安定したベースを作る
- **やること**:
  1. `git merge origin/dashboard-rebuild` — 全新規ファイル（Grafana JSON 7つ）、コンフリクトなし
  2. `git merge fix/ime-and-delimiter-leak` — IME Enter誤送信防止 + デリミタリーク修正、コンフリクトなし
  3. `git merge fix/docker-and-widget-cross-origin` — Docker build修正 + widget cross-origin
     - `docker/app/Dockerfile`: 現ブランチ側採用（`build-essential`含む上位互換）
     - `widget/src/components/ChatPanel.tsx`: props方式に統一（`apiUrl` を props で受け取り、inline querySelector を削除）
     - `widget/src/main.tsx`: `document.currentScript` キャプチャを採用
     - `widget/src/App.tsx`: `scriptOrigin` props 受け渡しを採用
- **技術的ポイント**: リスクの低い順に取り込むことで各マージ後に動作確認可能。コンフリクト発生時の原因特定が容易
- **対象ファイル**:
  - dashboard: `docker/grafana/dashboards/*.json`（7ファイル、全新規）
  - IME: `src/app/services/agent/single_react.py`, `widget/src/components/InputArea.tsx`, `widget/src/hooks/useConversation.ts`, テスト3ファイル
  - docker: `docker/app/Dockerfile`, `docker/postgres/Dockerfile`, `widget/src/App.tsx`, `widget/src/components/ChatPanel.tsx`, `widget/src/main.tsx`
- **前提/依存**: T1完了後
- **完了条件**: 3ブランチが統合済み、`git log` で全コミットが含まれている
- **見積**: 1h

### T3: 中間動作確認

- **目的**: task/002移植前にクリーンなベースラインを確認する
- **やること**:
  - `docker compose up` でサービス起動確認
  - `cd widget && npm run build` で widget ビルド成功確認
  - import エラーがないことを確認
- **技術的ポイント**: task/002移植中に問題が発生した場合、低リスクブランチ由来か task/002 由来かを切り分けるためのチェックポイント
- **前提/依存**: T2完了後
- **完了条件**: サービス起動OK、widgetビルドOK
- **見積**: 30min

### T4: task/002 RAGフィルタ コアモジュール移植

- **目的**: RAGメタデータフィルタリングのコア機能を新アーキテクチャに移植
- **やること**:
  1. `src/app/services/retrieval/filters/voltage_filter.py` を新規作成（task/002の `src/app/rag/filters/voltage_filter.py` から、import を `app.*` 形式に修正）
  2. `src/app/services/agent/tools/contract_context.py` を新規作成（task/002の `src/app/agents/tools/contract_context.py` から移植）
  3. `src/app/core/config.py` に `CONTRACT_FILTER_ENABLED: bool = False` を追加
  4. `src/app/services/agent/tools/knowledge_search.py` に ContractContext ポストフィルタリングを追加
  5. テスト移植: `tests/unit/rag/test_voltage_filter.py`, `tests/unit/agents/test_contract_context.py`（import パス修正）
- **技術的ポイント**:
  - 既存の `RetrievalStrategy` プロトコルへの侵食を最小化するため、フィルタリングはツール層で行う
  - ContextVar がAsyncIOスコープ越えで無効化されないか要確認
- **対象ファイル**: 新規3ファイル + 既存1ファイル変更 + テスト2ファイル
- **前提/依存**: T3完了後
- **完了条件**: `pytest tests/unit/rag/ tests/unit/agents/` が通過
- **見積**: 2h

### T5: task/002 Orchestrator + State 統合

- **目的**: ContractContext をオーケストレーターパイプラインに統合
- **やること**:
  1. `src/app/services/agent/multi_agent/orchestrator.py` に ContractContext の set/clear を追加（task/002の `orchestrator.py` L678付近を参考）
  2. `src/app/api/v1/schemas/chat.py` に `voltage_type: str | None` と `area: str | None` を ChatStreamRequest に追加
  3. `src/app/api/v1/chat.py` のエンドポイントでフィルタ値を受け取りorchestratorに渡す
- **技術的ポイント**:
  - 旧アーキのフラット関数 `get_agent_response()` を新アーキの Protocol+Factory 方式に翻訳する必要がある
  - **最大リスク**: 機械的なimport置換では不十分で、設計パターンの翻訳が必要
- **対象ファイル**: `orchestrator.py`, `schemas/chat.py`, `chat.py`
- **前提/依存**: T4完了後
- **完了条件**: filter付きchatリクエストが正しく処理される
- **見積**: 1.5h

### T6: task/002 Summary差分統合 + Admin API + Feedback API移植

- **目的**: Summary追加機能と管理APIを新アーキテクチャに移植
- **やること**:
  1. `src/app/services/summary.py`（既存193行）に task/002 の差分を統合:
     - `get_session_structured_summary()` を追加（`ConversationCache` 方式に書き換え）
     - `get_session_summary()` を追加
  2. `src/app/api/admin/schemas.py` を新規作成（task/002から移植、import修正）
  3. `src/app/api/admin/analytics.py` を新規作成（`DbSession` DI方式に書き換え）
  4. `src/app/api/v1/feedback.py` の改善分を移植
  5. `src/app/api/v1/schemas.py` への追加分を移植
  6. `docker/grafana/provisioning/dashboards/unresolved-analysis.json` をコピー
  7. ナレッジチャンク `faq_手続き案内.yaml` をコピー
  8. テスト移植: `tests/services/test_summary_structured.py`, `tests/services/agent/multi_agent/test_escalation_tag.py`
- **技術的ポイント**:
  - `summary.py` は両ブランチで独立に実装されたため、行単位ではなく機能単位で差分を確認
  - DB接続: 旧アーキの `AsyncSessionLocal` を新アーキの `DbSession` 依存注入に書き換え
  - `admin/analytics.py` の `FeedbackRepo`, `ChatRepository` への依存確認要
- **対象ファイル**: 既存1ファイル変更 + 新規4ファイル + コピー2ファイル + テスト2ファイル
- **前提/依存**: T5完了後
- **完了条件**: `pytest tests/services/` が通過、admin APIエンドポイント疎通確認
- **見積**: 2h

### T7: 統合テスト + PRクリーンアップ

- **目的**: 全体動作確認と重複PRの整理
- **やること**:
  1. 全テスト実行:
     ```bash
     uv run pytest tests/ -x --tb=short
     cd widget && npm test
     cd widget && npm run build
     ```
  2. 旧パス参照がないことを確認: `grep -r "src\.app\." src/ --include="*.py"` で旧import残存をチェック
  3. `.pyc` キャッシュクリア: `find . -name "*.pyc" -delete && find . -name "__pycache__" -type d -exec rm -rf {} +`
  4. PR整理:
     - PR #30, #31: クローズ（fix/docker の内容は統合済み）
     - PR #28: クローズ（user-data-access は既にマージ済み）
     - PR #33: 説明文更新（統合した変更内容を反映）
  5. `git diff origin/main...HEAD` で意図しない変更が混入していないか最終確認
- **技術的ポイント**: 旧.pycキャッシュが残っていると実行時にstaleバイトコードを参照する可能性あり
- **前提/依存**: T4-T6すべて完了後
- **完了条件**: テスト全通過、旧パス参照なし、重複PRクローズ済み
- **見積**: 1h

## 前提条件・依存関係

```
T1 (未コミットファイル) ──→ T2 (低リスク3ブランチ) ──→ T3 (中間確認)
                                                          ↓
                           T4 (RAGフィルタ コア) ──→ T5 (Orchestrator)
                                                          ↓
                                    T6 (Summary + Admin) ──→ T7 (統合テスト)
```

合計見積: 8-9h

## 補足

- `task/002-rag-metadata-filtering` は `feat/tier2-escalation-enrichment` の11コミットを完全に含む。escalation-enrichment を個別に統合する必要はない
- `sessions.html` の電圧フィルタUIは現アーキ（React widget）とは別実装（HTMX）のため移植しない。将来的にReact widgetにフィルタUIを追加する場合は別タスク
- PR #11（Naoki/useful_features）は510コミット前の分岐であり本タスクの対象外。guardrails、RRF ranking等の移植価値は別途評価

## PM 判断ログ

ユーザーの「立て直し」という言葉は以前に何らかのプランが存在したか、試みたが失敗した経緯があることを示唆している。単純な「マージ計画」ではなく、既に複雑な状態になっていることを前提にプランを組む必要がある。

最大のリスクは明確に `task/002-rag-metadata-filtering` だ。20コミット・39ファイルという規模に加えて、旧アーキテクチャパス依存という「構造的不整合」を抱えている。これは「コンフリクトを直せば動く」レベルではなく、「コードが混入した時点でサービスが壊れる可能性がある」レベルのリスクだ。

分岐点として最初に検討したのは「全部まとめてoctopus mergeする」アプローチだったが、task/002のアーキ依存問題があるため即座に却下した。次に「task/002を除く3ブランチを先に統合し、その後task/002の取り込み方針を別途決める」という二段階アプローチが最もリスクコントロールできると判断した。

PR #11は「昨日から」の時間的範囲外であり、混入させると今回の統合タスクが別プロジェクトになってしまう。

却下した選択肢:
- **Octopus merge**: task/002の旧アーキ依存問題を解消しないまま全部まとめるとデバッグコストが爆発
- **Squash merge**: コミット履歴の情報損失のデメリットが大きい（task/002の20コミットはレビューに有用）
- **Cherry-pick**: 20コミット中ほぼ全てでコンフリクト発生、手動移植とコスト同等

## アーキテクト技術調査メモ

### 新アーキテクチャの確認結果

現ブランチ (`feat/tier2-port-and-inquiry-form`) の新アーキテクチャ:
- RAG: `/src/app/services/retrieval/` — Protocol+Factory方式（`RetrievalStrategy`プロトコル、`ScoredChunk`）
- 知識検索ツール: `/src/app/services/agent/tools/knowledge_search.py` — クロージャ注入方式（モジュールレベルstateなし）
- Zendesk: `/src/app/services/zendesk/client.py` + `models.py` — `ZendeskClient`クラス、httpxで注入済み
- `summary.py`: `/src/app/services/summary.py` — `TAG_DEFINITIONS`, `StructuredSummary`, `generate_structured_summary()` 実装済み（193行）
- エスカレーション: `/src/app/services/agent/multi_agent/nodes/escalation.py` — `make_evaluate_response_node`, `make_zendesk_ticket_node` ポート済み
- 状態: `OrchestratorState`に `business_tag: str | None` フィールド済み
- API: `/src/app/api/v1/chat.py` — SSE streaming、`/src/app/api/v1/schemas/chat.py` 分離済み
- `zendesk.py`: `/src/app/api/v1/zendesk.py` が未コミットで既に存在（新アーキパスで実装済み）

### task/002 の旧アーキテクチャ

パス体系: `src.app.*`（`src.` プレフィックスあり）
- RAG: `/src/app/rag/` + `/src/app/agents/tools/qa_search.py` — モジュールレベルContextVar方式
- Orchestrator: `/src/app/graph/orchestrator.py` — `get_agent_response()` 関数
- 設定: `src.shared.config.settings.Settings`（単一フラットクラス）
- Web UI: `/src/app/web/routes.py` — HTMX+Jinja2、`get_agent_response`直接呼び出し

### マージ可否のシミュレーション結果

fix/ime-and-delimiter-leak: `git merge-tree` の出力は `merged`（コンフリクトなし確定）
dashboard-rebuild: 全7ファイルが新規JSON追加。コンフリクトなし
fix/docker-and-widget-cross-origin: 2ファイルでコンフリクト（Dockerfile書き方違い、ChatPanel.tsx設計差異）
task/002: `git merge` 不可。以下の理由:
- `src.app.*` vs `app.*` のパス差異は全ファイルに及ぶ
- コンフリクト解消後もimportエラーが大量に残る
- `src.shared.config.settings.Settings` が `app.core.config` と構造的に異なり、設定アクセスが全面的に壊れる

### 却下した技術案
- **git merge task/002**: import全壊、手動解消のコストが手動移植と変わらずgit履歴が汚染される
- **task/002を基底にrebase**: 19コミットの新アーキインフラ（StructLogミドルウェア、DI注入、DBエンジン生成）を旧アーキ上にリベースすると逆方向の移植になり工数増大
- **mainから新ブランチ切り直し**: 現ブランチ19コミット分の再作業で無意味
- **旧HTMX Web UIを全移植**: React widgetとの2系統並走はメンテコスト高

## Critic 議論ログ

### 合意点
1. 統合先は `feat/tier2-port-and-inquiry-form`。mainから19コミット先行、既にエスカレーション移植+問い合わせフォーム搭載
2. task/002 の git merge は不可（importパス差異が全ファイルに及ぶ）
3. 低リスクブランチ（IME, dashboard, docker）を先行統合
4. task/002のHTMX/Jinja2 Web UIは移植しない（React widgetに統一）
5. PR #11は対象外（2週間前の別作業）

### 論点と裁定

**論点1: task/002の統合手法**
- PM: merge方式 or 手動移植（両方残す）
- Architect: 手動移植一択
- 裁定: Architectの手動移植を採用。cherry-pickでもほぼ全ファイルでコンフリクト発生

**論点2: タスク粒度**
- PM: task/002を1タスクとして扱う（2-4h）
- Architect: task/002を3タスクに分解（コア / Orchestrator / Summary+Admin）
- 裁定: Architectの分解を採用。各フェーズで動作確認を入れるべき。summary.pyは差分統合として扱う

**論点3: 動作確認のタイミング**
- PM: 低リスク統合後+task/002統合後の2回
- Architect: 最終タスクで1回
- 裁定: PMの2回確認を採用。task/002移植前にベースライン確認で問題切り分けを容易にする

**論点4: 未コミットファイルの扱い**
- 両者とも明示的に言及なし
- 裁定: zendesk.py, EscalationOffer.tsx を最初にコミットしてベースライン確定

### 品質チェック
- ターゲットブランチの特定: OK
- 統合対象ブランチの網羅性: OK（4ブランチ全て確認）
- コンフリクト予測: OK
- 既存ポート済みコードの考慮: OK（summary.py, escalation.py等が既存であることを確認）
- 移植除外の明確化: OK（HTMX, docs, uv.lock）
- import方式の統一基準: OK（`app.*`に統一、`src.`プレフィックスなし）
