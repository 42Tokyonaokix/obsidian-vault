---
title: "mainブランチ オープンPR整理・マージ計画"
date: 2026-03-22
project: 42-chatbot
status: done
progress: 6/6
priority: high
tags: [git, merge, pr-cleanup]
---

## 背景・目的

ユーザーの問い: 「mainに出されたプルリクで、このブランチに存在しない機能がある気がするから、どんなものがあるのかを調査して、いい感じにコンフリクトを回避するようなマージ計画を立てて」

mainブランチに対するオープンPR 5件（#11, #28, #30, #31, #33）と、未PR化のリモートブランチ `feat/tier2-escalation-enrichment` の状態を整理し、マージ/クローズの判断を確定させる。ローカルmainのリモート同期を前提条件として処理し、コンフリクトのない順序でmainを最新状態にする。

## 要件定義

PM Agentが整理した要件。

- **目的**: mainブランチへの全オープンPRを整理し、コンフリクトなく・機能を損なわずにmainを最新状態にすること。放置するとPR #33（89ファイル変更）のdivergenceが日々拡大するため、今が最もコストの低いタイミング。
- **スコープ**:
  - やること: 各PRの採用/クローズ判断、ChatPanel.tsxの設計判断文書化、マージ順序確定と実行
  - やらないこと: PR #11の機能移植の実装作業（判断記録のみ）、PR #33自体の品質改善
- **成功基準**:
  1. mainが有効PRを取り込んだ状態になっている
  2. 重複・obsolete PRがクローズされている
  3. PR #11の機能価値判断が記録されている

## 技術検討

Architect Agentの技術的分析。

### 現状のブランチ状態

| PR | ブランチ | 状態 |
|---|---|---|
| #28 | `user-data-access` | 現ブランチに**マージ済み**（0コミット差） |
| #30 | `fix/docker-and-widget-cross-origin` | 1コミット未マージ（PR #31と**完全同一差分**） |
| #31 | `Naoki/metadata_filtering` | 1コミット未マージ（PR #30と**完全同一差分**） |
| #33 | `refactor/knowledge-chunks-reorganize` | 現ブランチ自身のPR。89ファイル・15020行追加 |
| #11 | `Naoki/useful_features` | 4コミット未マージ。**510コミット前の旧アーキテクチャベース** |
| (未PR) | `feat/tier2-escalation-enrichment` | 11コミット未マージ。旧パス(`src/app/graph/`)依存あり |

### コンフリクト分析

**PR #30/#31 vs 現ブランチ（2ファイルでコンフリクト）:**
- `docker/app/Dockerfile` — 両方がgcc/g++追加。現ブランチは `gcc g++ build-essential`（上位互換）、PRは `gcc g++` のみ。現ブランチの方が保守的。
- `widget/src/components/ChatPanel.tsx` — 同じ問題を異なる方法で解決。現ブランチはscriptタグからapiUrlをランタイム検出（`querySelector`方式）、PRはpropsとして受け渡し。
- `docker/postgres/Dockerfile`, `widget/src/App.tsx`, `widget/src/main.tsx` — 自動マージ可能

**PR #11 vs 現ブランチ:**
- 旧アーキテクチャベース（`src/app/agents/` → 新: `src/app/services/agent/`、`src/app/graph/` → 再構築済み、`mock_server/` → `mock-dgm-api/`）
- そのままマージすると現アーキテクチャが破壊される
- 移植価値のある機能: guardrails（coherence_guard, scope_guard）、RRF ranking、月次請求ツール（endpoint_monthly_charge）

**feat/tier2-escalation-enrichment vs 現ブランチ:**
- `src/app/graph/nodes/escalation.py` 等が旧パス依存
- `src/app/services/summary.py` と `widget/src/components/EscalationOffer.tsx` が未コミット状態で現ブランチに存在（移植作業途中と推測）
- import パス `src.app.*` vs `app.*` の混在問題あり

### 技術的リスク
1. ローカルmainがリモートより18コミット先行 — pushしないとPRのmergeable判定が正しく出ない
2. 旧.pycキャッシュによるstaleバイトコード参照の可能性
3. `document.currentScript` はESM（`type="module"`）で `null` になる仕様制限

## 議論サマリー

Critic Agentによる PM・Architectの見解の突き合わせ。

### 合意点
1. **PR #11 のそのままマージは不可**。旧アーキテクチャ依存のため、機能抽出+現アーキテクチャへの移植方式が必要
2. **PR #30 と #31 は実質同一**。一方を採用し他方をクローズすべき
3. **マージ順序の設計が重要**。放置でdivergence拡大

### 論点と裁定

**論点1: ChatPanel.tsx の実装方式**
- Architect: props方式（PR #31）を推奨。`document.currentScript`のESM非対応リスクを指摘
- PM: 設計判断を文書化すべきとだけ述べ、具体的推奨なし
- **裁定**: 現mainのChatPanel.tsxは既にquerySelector方式+inquiryUrl追加済みで動作している。PR #30/#31をマージするとinquiryUrlの行が衝突する可能性がある。**mainが大きく進んだ今、PR #30/#31はそのままマージするより、必要ならmain上で直接修正する方が安全**

**論点2: escalation-enrichmentの扱い**
- Architect: 7タスクに分解して個別移植
- PM: escalation-enrichmentの個別移植タスクには言及なし
- **裁定**: escalation-enrichmentはmain向けPRではない（base branchが別）。アーキテクトの分解は技術的に正確だが、今回の「mainのPR整理」スコープでは過剰。整理対象に含めるが、移植実作業は別タスク

**論点3: PR #28の扱い**
- 両者とも見落としていたが、調査結果から**既にマージ済み**（0コミット差）。クローズ候補

**論点4: PR #11 移植タスクの粒度**
- Architect: guardrails/月次請求ツール/RAG機能の3タスク（各M）
- PM: 移植作業はスコープ外と明言
- **裁定**: PMの判断を採用。510コミット前の分岐、85ファイル変更の移植は独立プロジェクトレベル。今回は判断記録のみ

## 設計判断

- **PR #30/#31**: 両方クローズ推奨。Dockerfile変更は現ブランチが上位互換（`build-essential`含む）。ChatPanel.tsxは現ブランチの方式で動作確認済み。postgres/Dockerfileの `02-create-mock-db.sh` 追加のみ価値があるが、これは独立して取り込み可能
- **PR #28**: クローズ（既にマージ済み）
- **PR #33**: mainにマージ（本体）
- **PR #11**: クローズ。移植価値のある機能（guardrails, RRF ranking, 月次請求ツール）は別タスクとして起票
- **feat/tier2-escalation-enrichment**: base branchの確認と整理。mainマージは別タスク

## タスク

- [x] T0: ローカルmainをリモートにpush
- [x] T1: PR #28 の状態確認・クローズ
- [x] T2: PR #30/#31 の採用判断・処理
- [x] T3: PR #33 のマージ
- [x] T4: feat/tier2-escalation-enrichment の整理
- [x] T5: PR #11 の機能価値判定・記録・クローズ
- [x] T6: 重複・obsolete PRのクローズ完了確認

## 各タスクの詳細

### T0: ローカルmainをリモートにpush

- **目的**: PRのmergeable判定を正しく行うための前提条件を整える
- **やること**: `git push origin main` で18コミット分をリモートに反映
- **技術的ポイント**: ローカルmainがリモートより先行している状態を解消。これをやらないとGitHub上のPR差分が正しく表示されない
- **前提/依存**: なし（最初に実行）
- **完了条件**: `git log origin/main..main` が空になること

### T1: PR #28 の状態確認・クローズ

- **目的**: マージ済みPRをクローズして整理
- **やること**: PR #28 の差分がmainに含まれていることを確認し、コメント付きでクローズ
- **技術的ポイント**: `git log --oneline HEAD..origin/user-data-access` が空（0コミット差）であることを確認済み
- **前提/依存**: T0完了後
- **完了条件**: PR #28 がクローズされていること

### T2: PR #30/#31 の採用判断・処理

- **目的**: 重複PRを整理し、必要な変更だけ取り込む
- **やること**:
  1. PR #30 と #31 が完全同一差分であることを最終確認
  2. mainのChatPanel.tsxが既にapiUrl解決機能を持つことを確認
  3. `docker/postgres/Dockerfile` の `02-create-mock-db.sh` 追加のみ価値があれば個別に取り込み
  4. 両PRにクローズ理由をコメントしてクローズ
- **技術的ポイント**: Dockerfile変更は現ブランチが上位互換。ChatPanel.tsxは設計方式が異なるが現方式で動作確認済み
- **前提/依存**: T0完了後
- **完了条件**: PR #30, #31 が適切にクローズされていること

### T3: PR #33 のマージ

- **目的**: 現ブランチの89ファイル変更をmainに統合
- **やること**: GitHub上でPR #33 をマージ（squash mergeまたはmerge commit）
- **技術的ポイント**: T0でpush後、GitHub上でmergeable状態になっているはず。CIがあれば通過確認
- **前提/依存**: T0, T1, T2 完了後（クリーンな状態でマージ）
- **完了条件**: PR #33 がmainにマージされ、CIが通過

### T4: feat/tier2-escalation-enrichment の整理

- **目的**: 未PR化ブランチの状態を明確にし、次のアクションを決定
- **やること**:
  1. ブランチの内容（11コミット）をレビュー
  2. 旧アーキテクチャパス依存箇所を特定
  3. `src/app/services/summary.py` 等の未コミットファイルとの関係を整理
  4. PR作成するか、別タスクとして起票するか判断
- **技術的ポイント**: `src/app/graph/` パスの旧依存、import パス `src.app.*` vs `app.*` の混在。現ブランチに未コミットの移植途中ファイルが存在
- **前提/依存**: T3完了後（mainが最新状態になってから判断）
- **完了条件**: ブランチの扱い方針が決定・記録されていること

### T5: PR #11 の機能価値判定・記録・クローズ

- **目的**: 旧アーキテクチャPRを整理しつつ、価値ある機能の移植計画を残す
- **やること**:
  1. PR #11 の85ファイルから移植価値のある機能を最終判定:
     - `guardrails` (coherence_guard, scope_guard): 移植価値**あり** — 現アーキテクチャの `src/app/services/guardrails/` に移植
     - `RRF ranking` (ranking.py): 移植価値**あり** — 検索精度向上
     - `endpoint_monthly_charge.py`: 移植価値**あり** — 月次請求ツール
     - `mock_server/` 計算ロジック: 移植価値**検討** — `mock-dgm-api/` に移植可能だが優先度低
     - `prompts/` ディレクトリ: 移植価値**なし** — 現アーキテクチャで `src/app/services/agent/prompts/` に再設計済み
     - `src/app/agents/web_agent.py`: 移植価値**なし** — 旧設計
  2. 上記判定結果をPR #11にコメントとして記録
  3. PR #11 をクローズ（理由: 旧アーキテクチャベースのためマージ不可。価値ある機能は別タスクで移植）
- **技術的ポイント**: 分岐が510コミット前のため `git merge` は不可。機能単位でのcherry-pickも import パス書き換えが必要
- **前提/依存**: T3完了後
- **完了条件**: PR #11 にコメント付きでクローズ。移植価値のある機能リストが記録されていること

### T6: 重複・obsolete PRのクローズ完了確認

- **目的**: 最終チェック
- **やること**: `gh pr list --state open --base main` でオープンPRがゼロ（または意図的に残したもののみ）であることを確認
- **前提/依存**: T1-T5 すべて完了後
- **完了条件**: オープンPRが想定通りの状態であること

## 前提条件・依存関係

```
T0 (push main) ──→ T1 (#28 クローズ) ──→ T3 (#33 マージ)
                ──→ T2 (#30/#31 処理)  ──→ T3
                                            ──→ T4 (escalation整理)
                                            ──→ T5 (#11 判定・クローズ)
                                                 ──→ T6 (最終確認)
```

- T0が全タスクの前提条件（リモート同期）
- T1, T2 は並列実行可能
- T3 は T1, T2 完了後（クリーンな状態でマージするため）
- T4, T5 は T3 完了後（mainが最新になってから判断）
- T6 は全タスク完了後の最終確認

## 補足

- PR #30 と #31 の `docker/postgres/Dockerfile` にある `02-create-mock-db.sh` 追加は、mock_dgm データベースの初期化に必要。現ブランチにこの変更がない場合は個別に取り込むことを検討
- `widget/src/main.tsx` の `document.currentScript` キャプチャは、将来ESM移行時に壊れる可能性あり。現時点ではIIFE形式のため問題ないが、ESM移行時に要対応

## PM 判断ログ

ユーザーの最初の言葉「このブランチに存在しない機能がある気がする」という感覚的な問いかけから始まっているが、プロジェクトコンテキストを読むと、すでにかなり詳細な分析が終わっている。つまり「調査フェーズ」は実質完了しており、今必要なのは「マージ計画の策定と実行」だ。ユーザーが確認した目的にも「機能を洗い出し、コンフリクトを最小限に抑えるマージ戦略を策定すること」とある。

気になった点がいくつかある。

まず PR #11 の扱いだ。「旧アーキテクチャベース」「大半が現アーキテクチャと互換性なし」という分析があるが、それでも「85ファイル/6684行」のコードに含まれる機能の価値判断がまだ行われていない。RAGデータ特化・メモリ参照・処理フロー表示という機能は現アーキテクチャに移植する価値があるのか、それとも捨てるのか。この判断なしにマージ計画は立てられない。PR #11 は「マージする」のではなく「機能を抽出して現アーキテクチャに移植するか否かを決める」という問いとして扱うべきだ。

次に PR #30 と #31 の関係だ。「同内容の修正」とある。これは一方をマージすれば他方は不要になる、つまり先にどちらをマージするかを決めればコンフリクト問題が消える。ただし `ChatPanel.tsx` の実装差異（ランタイム検出 vs props渡し）は設計判断を含むため、単純に「どちらが正しいか」ではなく「どちらのアプローチを採用するか」という意思決定が必要だ。

判断の分岐点は二つある。

一つ目：PR #30/#31 についてはコンフリクトの解消方針を先に決める必要がある。現ブランチのアプローチ（scriptタグからランタイム検出）は柔軟だが複雑、PRのアプローチ（propsとして渡す）はシンプルだが呼び出し側に依存する。現ブランチが「先にいる」状況なので、現ブランチの実装を正とするのが自然ではあるが、これはアーキテクチャ判断なので明示的に確認が要る。

二つ目：マージ順序の設計だ。PR #33（現ブランチ）がmainにマージされる前に PR #30/#31 をmainにマージしてしまうと、現ブランチがrebaseする必要が生じる。逆に現ブランチを先にマージすれば PR #30/#31 は不要になるかもしれない。この「順序」の判断がマージ計画の核心だ。

## アーキテクト技術調査メモ

### ブランチ・PR の実際の状態

ローカルの `main` / `feat/tier2-port-and-inquiry-form` / `refactor/knowledge-chunks-reorganize` は全て同一コミット `25b81dc` を指している。これはリモートの `origin/main`（`1895be3`）より 18 コミット先行している。

### PR #31 (Naoki/metadata_filtering) の技術詳細

アプローチが現ブランチとズレている。現 HEAD は ChatPanel 内部でスクリプトタグを `querySelector` で検索する inline 方式。PR #31 は `document.currentScript`（モジュール実行時のみ有効）を `main.tsx` で捕捉し、props チェーン（`App → ChatPanel`）で渡す方式。

現 HEAD の方式に問題がある: `querySelector('script[src*="widget.js"]')` は Shadow DOM 外のドキュメントを検索するので cross-origin での動作は安定しているが、ファイル名依存という脆弱性がある。PR #31 の `document.currentScript` 方式は**スクリプト実行時点でのみ有効**であり、`type="module"` では `null` になる（仕様上の制限）。現ブランチが widget を IIFE として出力しているなら PR #31 方式の方が信頼性が高い。

### feat/tier2-escalation-enrichment の技術詳細

最も複雑。旧アーキテクチャ（`src/app/agents/`, `src/app/graph/`, `src/shared/config/settings.py` ベース）の上に構築されている。現 HEAD は新アーキテクチャ（`app.core.config`, `structlog`, `app.services.agent/`）。

提供する機能の価値は高い:
- Tier 2 エスカレーション強化（カテゴリタグ＋構造化サマリ）: `TAG_DEFINITIONS` 8カテゴリ、`generate_structured_summary()` の LLM 呼び出し
- 管理 API 追加（低評価フィードバック一覧、未解決分析）
- Grafana ダッシュボード（未解決率推移）
- Jinja2 テンプレート群（HTMX ベースの問い合わせフォーム UI）

しかし `src/app/graph/orchestrator.py`（`src.app.agents.data_agent` 等をインポート）は現アーキテクチャにそのままでは動かない。

重要な観察: `src/app/services/summary.py` と `widget/src/components/EscalationOffer.tsx` が未コミット状態で存在しており、escalation-enrichment の機能を現アーキテクチャに移植しようとした作業が途中と読める。

### PR #11 (Naoki/useful_features) の技術詳細

分岐点は `9fd61b2`（510コミット前）。追加する機能:
1. `mock_server/` への計算ロジック・契約 DB 追加（`mock-dgm-api/` が新名称）
2. `src/app/agents/tools/endpoint_monthly_charge.py`（月次請求ツール）
3. `prompts/` ディレクトリへの各エージェントプロンプト markdown
4. `src/app/guardrails/input/coherence_guard.py` / `scope_guard.py`（guardrails 実装）
5. `src/app/rag/ranking.py`（RRF 実装）、`keyword_extractor.py`

guardrails の実装は `src.app.guardrails.base.BaseGuardrail` 基底クラスに依存しており、現 HEAD では `src/app/guardrails/input/` が空ディレクトリ。`src/app/services/guardrails/` が現アーキテクチャの guardrails 実装場所。

### 技術的リスク
1. **高**: PR escalation-enrichment の import パスが `src.app.*` 形式と `app.*` 形式で混在。同一プロセスで混在すると `ModuleNotFoundError`
2. **高**: 旧 `.pyc` キャッシュが存在する場合、stale なバイトコードを参照する可能性
3. **中**: `document.currentScript` の Shadow DOM 互換性。IIFE 形式なら問題ないが、ESM 移行時にサイレントに壊れる
4. **低**: PR #11 のテストが旧パス前提（`from src.app.guardrails.input...`）

### 却下した技術案
- **PR #11 を `git merge`**: 分岐が510コミット前、旧設定形式が現 `app.core.config` と衝突。却下
- **escalation-enrichment をそのまま `git merge`**: 旧パス依存で動かない。却下
- **旧 HTMX web UI を現アーキテクチャに全移植**: React widget との並走はメンテコスト高。却下

## Critic 議論ログ

### 合意点（PM・アーキテクト一致）

1. PR #11 のそのままマージは不可。85ファイル変更、旧アーキテクチャ依存。両者とも「機能抽出+現アーキテクチャへの移植」方式を推奨。
2. PR #30 と #31 は実質同一。一方を採用し他方をクローズすべき。
3. マージ順序の設計が重要。放置するとmainとの乖離が拡大する。

### 論点と裁定

**論点1: ChatPanel.tsx の実装方式（props方式 vs querySelector方式）**
- アーキテクト: props方式推奨、ESM非対応リスク指摘
- PM: 文書化すべきとのみ
- 裁定: 現mainのChatPanel.tsxは既にquerySelector方式+inquiryUrl追加済みで動作中。PR #30/#31をマージするとinquiryUrlの行が衝突する。mainが大きく進んだ今、PR #30/#31はそのままマージするより必要ならmain上で直接修正する方が安全。

**論点2: escalation-enrichmentの扱い**
- アーキテクト: 7タスクに分解して個別移植
- PM: 言及なし
- 裁定: main向けPRではない。今回のスコープでは整理対象に含めるが移植実作業は別タスク。

**論点3: PR #28の扱い**
- 両者とも見落としていた
- 裁定: 既にマージ済み（0コミット差）。クローズ候補。

**論点4: PR #11 移植タスクの粒度**
- アーキテクト: 3タスク（各M）
- PM: スコープ外と明言
- 裁定: PMの判断を採用。510コミット前の分岐、85ファイル変更の移植は独立プロジェクトレベル。今回は判断記録のみ。

### 品質チェック
- アーキテクトの7タスク案はスコープが大きすぎる（5つのMサイズタスク）→ 判断記録のみに縮小
- PMの5サブタスク案は適切だがPR #28確認が抜け → T1として追加
- **見落とし前提条件**: ローカルmainがリモートより18コミット先行。`git push origin main` が先に必要 → T0として追加
- 優先度 high は妥当
