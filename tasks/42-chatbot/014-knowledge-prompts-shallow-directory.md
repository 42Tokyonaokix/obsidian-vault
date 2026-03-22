---
title: "ナレッジ・プロンプトファイルのルート浅階層への移動リファクタ"
date: 2026-03-22
project: 42-chatbot
status: todo
progress: 0/4
priority: medium
tags: []
---

## 背景・目的

YAMLドキュメントファイルとMDプロンプトファイルのネストが深すぎて編集が難しくなっている。ルートまたは浅い所にディレクトリを作り直して可読性を向上させたい。

現在の配置:
- `src/app/services/agent/knowledge/chunks/{category}/{file}.yaml` — ルートから深さ6
- `src/app/services/agent/prompts/` / `src/app/services/agent/multi_agent/prompts/` — 深さ5-6
- `src/app/services/agent/knowledge/*.md` — 深さ5

コンテンツファイル（YAMLナレッジチャンク・MDナレッジドキュメント・MDプロンプト）をPythonロジックとは分離し、ルートから3段階以内のパスでアクセスできる専用ディレクトリへ移動する。

## 要件定義

### 目的
YAML/MDコンテンツファイルをルート直下の浅いディレクトリに集約し、編集の容易さと可読性を向上させる。ナレッジYAMLやプロンプトMDはドメイン専門家（CS・コンプライアンス担当）が頻繁に編集するコンテンツであり、`src/app/services/agent/...` という実装の内部構造を知らなくても編集できる状態が望ましい。

### スコープ
やること:
- YAML 39件 + MD 16件のファイル移動（git mv）
- コード参照箇所の修正（seed_knowledge.py, loader.py, multi_agent/prompts/__init__.py）
- テスト修正（test_seed_knowledge.py の endswith 検証など）
- Docker関連修正（Dockerfile COPY, docker-compose.dev.yml volume mount）

やらないこと:
- DB再シードの運用判断
- ファイル内容の変更
- docs/ 配下のドキュメント（既に適切な場所にある）
- Pythonパッケージ構造の変更（loader.py等はパッケージ内に残す）

### 成功基準
1. 移動後の全コンテンツファイルがルートから3階層以内でアクセスできる
2. `pytest` 全テストパス
3. `scripts/seed_knowledge.py --dry-run` 正常終了
4. アプリケーション起動時のプロンプトロード正常
5. 旧パスに残存ファイルなし
6. Docker build 成功

### 却下した選択肢
| 案 | 却下理由 |
|---|---|
| YAMLのみ移動、プロンプトMDはそのまま | 課題はプロンプトMDにも同様に存在。中途半端 |
| プロンプトMDをPythonパッケージ外のルートへ完全分離 | loader.py が `Path(__file__).parent` で自己完結しており、書き換えコスト高い |
| `docs/` 以下に統合 | docsは静的ドキュメント。LLM実行時コンテンツとは性質が異なる |
| シンボリックリンク | Docker/Windows環境で不安定 |
| 環境変数による完全外部化 | ローカル・Docker・テスト3環境でenv必要。メリット薄い |

## 技術検討

### パスロードの仕組み（2系統）

1. **seed_knowledge.py 系**: `Path(__file__).resolve().parent.parent / "src" / "app" / ...` でハードコード構築。`KNOWLEDGE_DIR`, `CHUNK_YAML_DIR`, `SYS_DOCS_DIR` の3定数。YAML ナレッジチャンクと知識MDの両方を管理。
2. **プロンプトloader系**: `loader.py` と `multi_agent/prompts/__init__.py` がそれぞれ `PROMPTS_DIR = Path(__file__).parent` で自パッケージ基準。loader.py は `@include` ディレクティブを再帰展開（system_prompt.md → knowledge_common.md等）。multi_agent側は `@include` 未使用。

### 技術的実現性
| サブタスク | 難易度 | 根拠 |
|---|---|---|
| YAML+知識MD移動 | S | seed_knowledge.py の定数2-3箇所 |
| 単一agent prompts移動 | M | @include制約あり。PROMPTS_DIR変更必要 |
| multi_agent prompts移動 | S | @include未使用。PROMPTS_DIR変更のみ |
| テスト更新 | S | endswith検証1件 + 実ファイル参照テスト確認 |
| Docker修正 | S | COPY命令・volume mount追加 |

### リスク
- **Docker volume mount**: `docker-compose.dev.yml` が `./src:/app/src` のみマウント。新設ディレクトリの追加が必須
- **Dockerfile COPY**: `COPY src/ ./src/` だけではルートの `knowledge/` `prompts/` がイメージに入らない
- **`@include` 制約**: single_agent の4ファイルは同一ディレクトリに配置必須（base_dirがPROMPTS_DIR固定のため）

## 議論サマリー

### 合意点
- ルート直下に `knowledge/` と `prompts/` を新設する方向
- 修正すべきコード箇所の特定（seed_knowledge.py, loader.py, multi_agent __init__.py, テスト）
- シンボリックリンク、docs/統合、環境変数外部化を却下
- ファイル内容は変更しない
- 優先度 medium

### 論点と裁定

**サブタスク粒度**: PMは7ステップ、アーキテクトは4タスク。
→ **アーキテクトの4タスク構成を採用**。PMの7ステップは細かすぎる。特に「物理移動」と「パス修正」を別タスクにすると、移動直後にテストが壊れた状態のコミットが生まれる。移動+パス修正を一括にすれば各コミットをグリーンに保てる。

**Docker volume mount**: PMは見落とし、アーキテクトが指摘。
→ **アーキテクト採用**。Dockerfile の `COPY` 追加と docker-compose.dev.yml のマウント追加が必須。

**`@include` 制約**: PMは認識するも対処方針なし、アーキテクトは PROMPTS_DIR 設定化を提案。
→ **アーキテクト採用**。ただし「設定化」は大げさで、実際は `PROMPTS_DIR` 定数の値を1行変えるだけ。

## 設計判断

### 移動先ディレクトリ構造（確定）
```
42-chatbot/
├── knowledge/
│   ├── chunks/          # YAML 39ファイル (サブディレクトリ構造維持)
│   │   ├── general/
│   │   ├── 約款/
│   │   ├── 地域託送約款/
│   │   └── DGM操作/
│   └── docs/            # MD 6ファイル (DGM_SCREENS等)
├── prompts/
│   ├── single_agent/    # MD 4ファイル (system_prompt, knowledge_*)
│   └── multi_agent/     # MD 6ファイル (classifier_system, qa_agent等)
```

### 採用アプローチ
- Pythonロジック（loader.py等）はパッケージ内に残し、`PROMPTS_DIR` 定数のみ新パスに変更
- `git mv` でファイル移動（履歴追跡を維持）
- Docker関連はファイル移動と同一タスクで修正（壊れた状態のコミットを防ぐ）

## タスク

- [ ] knowledge/ ディレクトリ移動 + seed_knowledge.py + Docker修正
- [ ] 単一エージェントプロンプトMD移動 + loader.py PROMPTS_DIR修正
- [ ] マルチエージェントプロンプトMD移動 + __init__.py PROMPTS_DIR修正
- [ ] 全体動作確認 + 旧パス残存チェック

## 各タスクの詳細

### サブタスク1: knowledge/ ディレクトリ移動 + seed_knowledge.py + Docker修正

- **目的**: YAML ナレッジチャンク39件と知識MD 6件をルート直下の `knowledge/` に移動し、参照コードを修正する
- **やること**:
  - `knowledge/chunks/` と `knowledge/docs/` をルートに新設
  - YAML 39件を `git mv src/app/services/agent/knowledge/chunks/* knowledge/chunks/`
  - MD 6件を `git mv src/app/services/agent/knowledge/*.md knowledge/docs/`
  - `scripts/seed_knowledge.py` の `KNOWLEDGE_DIR` を `Path(__file__).resolve().parent.parent / "knowledge"` に変更
  - `SYS_DOCS_DIR` を `KNOWLEDGE_DIR / "docs"` に変更
  - `docker-compose.dev.yml` に `./knowledge:/app/knowledge:cached` volume追加
  - `docker/app/Dockerfile` に `COPY knowledge/ ./knowledge/` 追加
  - `tests/services/test_seed_knowledge.py` の `endswith("knowledge/chunks")` 検証を実行確認（同名維持なら修正不要）
- **技術的ポイント**: 難易度S。seed_knowledge.py のパス定数2-3箇所の変更。endswith テストは移動後も `knowledge/chunks` で終わるため通過する見込みだが要実行確認
- **対象ファイル**: `scripts/seed_knowledge.py`, `docker-compose.dev.yml`, `docker/app/Dockerfile`, `tests/services/test_seed_knowledge.py`
- **前提/依存**: なし（他タスクと独立）
- **完了条件**: YAML/MDが `knowledge/` 以下に移動完了。seed_knowledge.py --dry-run 成功。Docker build 成功

### サブタスク2: 単一エージェントプロンプトMD移動 + loader.py PROMPTS_DIR修正

- **目的**: 単一エージェント用プロンプトMD 4件を `prompts/single_agent/` に移動し、ローダーのパス参照を修正する
- **やること**:
  - `prompts/single_agent/` をルートに新設
  - MD 4件 (system_prompt.md, knowledge_common.md, knowledge_qa.md, knowledge_data.md) を git mv
  - `src/app/services/agent/prompts/loader.py` の `PROMPTS_DIR` 定数を新パスに変更
  - `docker-compose.dev.yml` に `./prompts:/app/prompts:cached` volume追加（サブタスク1で未追加の場合）
  - `docker/app/Dockerfile` に `COPY prompts/ ./prompts/` 追加
- **技術的ポイント**: 難易度M。`@include` ディレクティブ（system_prompt.md → knowledge_common.md等）が base_dir = PROMPTS_DIR で解決されるため、4ファイルが同一ディレクトリに配置されていることが必須。`PROMPTS_DIR` の値を新パスに変えれば `@include` は問題なく動作する
- **対象ファイル**: `src/app/services/agent/prompts/loader.py`, `docker-compose.dev.yml`, `docker/app/Dockerfile`
- **前提/依存**: サブタスク1と独立して実施可能だが、Docker修正は共通するため順序を合わせると効率的
- **完了条件**: `load_prompt("system_prompt")` が正常にプロンプトを返す。`@include` が展開される。テスト `test_prompt_loader.py` パス

### サブタスク3: マルチエージェントプロンプトMD移動 + __init__.py PROMPTS_DIR修正

- **目的**: マルチエージェント用プロンプトMD 6件を `prompts/multi_agent/` に移動する
- **やること**:
  - MD 6件 (classifier_system.md, data_agent.md, escalation.md, merge.md, qa_agent.md, related_questions.md) を git mv
  - `src/app/services/agent/multi_agent/prompts/__init__.py` の `PROMPTS_DIR` 定数を新パスに変更
- **技術的ポイント**: 難易度S。`@include` 未使用のため単純なパス変更のみ
- **対象ファイル**: `src/app/services/agent/multi_agent/prompts/__init__.py`
- **前提/依存**: サブタスク2と同パターン。Docker修正はサブタスク2で完了済み（prompts/ ディレクトリごとマウント/COPY）
- **完了条件**: マルチエージェントのプロンプト読み込みが正常動作

### サブタスク4: 全体動作確認 + 旧パス残存チェック

- **目的**: 全変更の統合的な動作確認と、旧パスの完全クリーンアップ
- **やること**:
  - `pytest` 全テスト実行
  - `scripts/seed_knowledge.py --dry-run` 実行
  - `grep -r "services/agent/knowledge" . --include="*.py"` で旧パス残存チェック
  - `grep -r "services/agent/prompts" . --include="*.py"` で旧パス残存チェック（ただしloader.pyなどPythonモジュール自体は除外）
  - `grep -r "services/agent/multi_agent/prompts" . --include="*.py"` で旧パス残存チェック
  - 旧ディレクトリが空であることを確認し削除
  - Docker build + 起動確認
- **技術的ポイント**: 個別タスクでは検出できない統合的な問題（CI設定、import順序）の最終確認
- **対象ファイル**: テスト全般、CI設定
- **前提/依存**: サブタスク1-3すべて完了後
- **完了条件**: 成功基準1-6すべて充足

## 前提条件・依存関係

- サブタスク1-3は互いに独立して実施可能（ただし Docker 修正は共通するため順序を合わせると効率的）
- サブタスク4はサブタスク1-3すべての完了が前提
- 移動後、DB再シードが必要かどうかは運用判断（本タスクのスコープ外）

## 補足

- `test_source_document_creation_with_completed_status` にハードコードパス `/app/src/app/services/agent/knowledge/chunks/qa_list.yaml` があるが、SourceDocument モデル構築テストであり機能テストではないため実害なし。ただし将来的な混乱を避けるため修正推奨。
- `test_prompt_loader.py` は `patch.object(loader, "PROMPTS_DIR", base)` で仮ディレクトリに差し替えるパターン。実ファイルのパスには依存しないが、一部テスト（`test_load_prompt_knowledge_common_contains_dgp_or_dgm` 等）は実際の knowledge_common.md の内容を読むため、移動後にファイルが存在することが必要。

## PM 判断ログ

最初にアイデアを読んだとき、「ディレクトリを移動するだけ」という表面的にはシンプルな変更に見えた。しかし実際にコードを調査すると、これは単なるファイルの移動ではなく、コードベースの複数箇所に埋め込まれたハードコードパスを連動して修正しなければならない作業だと確認できた。

特に気になった点が3つある。

1つ目は、`scripts/seed_knowledge.py` が `Path(__file__)` を起点に `src/app/services/agent/knowledge/chunks` と `src/app/services/agent/knowledge/` を絶対パスで組み立てていること。さらにテストコード (`test_seed_knowledge.py`) が `CHUNK_YAML_DIR` が `"knowledge/chunks"` で終わることを文字列マッチで直接検証している。つまり、ディレクトリ移動と同時にこのテストの期待値も修正しなければテストが壊れる。

2つ目は、プロンプトMDファイルのロードメカニズム。`prompts/loader.py` は `PROMPTS_DIR = Path(__file__).parent` として自分自身のあるディレクトリを基準にする設計になっている。つまり、ファイルをPythonパッケージ外（たとえばルートの `prompts/` など）に移動した場合、loader.pyも移動するかパスを書き換えるかのどちらかが必要になる。同様に `multi_agent/prompts/__init__.py` も `Path(__file__).parent` 方式を採用している。

3つ目は、ユーザーが「ルートまたは浅い所」と言っているが、プロンプトMDはPythonパッケージ（`__init__.py` が存在する）の一部として機能している。完全にルートへ出してしまうと、ローダーの設計思想（パッケージローカル）が崩れる。ルート移動かどうかは慎重に判断すべきだと感じた。

代替案として「srcレベルの浅い場所に移す」「ルートにdataやcontentディレクトリを切る」の2方向が思い浮かんだが、ローダーの変更コストとテストへの波及が問題なので、段階的に「中間の浅さ」に着地させる案が現実的だと判断した。

優先度は medium とした。「編集が難しい」という課題は開発速度に影響を与えているが、アプリケーション動作を直接壊しているわけではない。ただし、プロンプトMDやYAMLは今後も頻繁に編集が想定されるファイルであり、放置するとエンジニアの認知コストが蓄積し続ける技術的負債になる。

## アーキテクト技術調査メモ

**パスロードの仕組み — 2系統に分かれている**

1. **プロンプト MD (単一エージェント側)**: `src/app/services/agent/prompts/loader.py` が `PROMPTS_DIR = Path(__file__).parent` でモジュール自身のディレクトリを基準に解決する。`load_prompt("system_prompt")` は `prompts/system_prompt.md` を読み、`@knowledge_common.md` のような `@include` ディレクティブを再帰的に展開する。つまり **prompts/ ディレクトリに入っている .md は全部ここに同居している必要がある**。

2. **プロンプト MD (マルチエージェント側)**: `src/app/services/agent/multi_agent/prompts/__init__.py` も同様に `PROMPTS_DIR = Path(__file__).parent` で自パッケージのディレクトリを基準にする。`_load("classifier_system")` は `multi_agent/prompts/classifier_system.md` を直接読む。`@include` 機能はここでは使っていない。

3. **YAML ナレッジチャンク**: `scripts/seed_knowledge.py` の `KNOWLEDGE_DIR / "chunks"` が唯一のパス参照元。`Path(__file__).resolve().parent.parent / "src" / "app" / "services" / "agent" / "knowledge"` という絶対パス構築になっている。つまり seed スクリプトを `scripts/` から実行することを前提に、**ハードコードされた相対構築**。

4. **知識 MD (DGM_SCREENS.md 等)**: 同じ `seed_knowledge.py` が `SYS_DOCS_DIR = KNOWLEDGE_DIR` として `*.md` を glob する。knowledge/ 直下のMDファイルを全部 DB に入れる設計。

**テストでの参照**

- `tests/services/test_prompt_loader.py` はファイルを直接読まずに `patch.object(loader, "PROMPTS_DIR", base)` で仮ディレクトリに差し替える。実ファイルのパスに依存していない設計になっている。ただし `test_load_prompt_knowledge_common_contains_dgp_or_dgm` と `test_get_category_knowledge_*` は実際の `knowledge_common.md` 等を読む。つまり **prompts/ 内 MD ファイルの内容に依存するテストが存在する**。
- `tests/services/test_seed_knowledge.py` の `test_seed_script_has_chunk_yaml_dir_constant` は `str(sk.CHUNK_YAML_DIR).endswith("knowledge/chunks")` でパスのサフィックスを検証している。**移動先でもサフィックスが `knowledge/chunks` でなければこのテストが壊れる**。
- `test_source_document_creation_with_completed_status` はフィクスチャ文字列として `/app/src/app/services/agent/knowledge/chunks/qa_list.yaml` を直接書いているが、これは SourceDocument モデルの構築テストであり機能テストでないため実害はない。

**`@include` の設計が移動の障壁になる箇所**

`system_prompt.md` の末尾に `@knowledge_common.md`, `@knowledge_qa.md`, `@knowledge_data.md` の3行がある。`_resolve_includes` の `base_dir` は `PROMPTS_DIR`（= loader.py の親）で固定されているため、include 先のファイルが同じディレクトリに存在しないと `<!-- file not found: ... -->` になってしまう。これが **単一エージェントの prompts/ 内 MD を他のディレクトリに分離できない最大の技術的制約**。

**Docker関連の注意点**

`docker-compose.dev.yml` が `./src:/app/src` のみマウントしている。新設ルート `knowledge/` と `prompts/` もコンテナにマウントされるよう volume mount 追加が必要。さらに本番用の Dockerfile は `COPY src/ ./src/` でソースをコピーしているが、ルートに移動したファイルは `COPY knowledge/ ./knowledge/` と `COPY prompts/ ./prompts/` を明示的に追加しなければ本番イメージに含まれない。

## Critic 議論ログ

### 合意点

1. **ルートレベルへの分離が妥当** — 両者とも `knowledge/` と `prompts/` をルート直下に新設する方向で合意。現在の6階層は深すぎるという認識は一致。

2. **修正すべきコード箇所の特定** — `seed_knowledge.py` のハードコードパス、`loader.py` の `PROMPTS_DIR`、`multi_agent/prompts/__init__.py` の `PROMPTS_DIR`、テストの `endswith` 検証。両者ともこれらを正しく列挙している。

3. **却下案** — シンボリックリンク、docs/ への統合、環境変数完全外部化。両者とも同じ理由で却下。

4. **ファイル内容は変更しない** — 移動とパス参照の修正のみ。

### 論点と裁定

**論点1: サブタスク粒度 — 7ステップ vs 4タスク**
PMの7ステップは論理的に正しいが細かすぎる。「物理移動」と「パス修正」を別タスクにすると移動直後にテストが壊れた状態のコミットが生まれる。→ **アーキテクトの4タスク構成を採用**。

**論点2: Docker volume マウント**
PMは見落とし。アーキテクトが `docker-compose.dev.yml` と Dockerfile の両方で修正必要と指摘。→ **アーキテクト採用。重要な見落とし。**

**論点3: `@include` 制約**
PMは認識のみ。アーキテクトは PROMPTS_DIR 設定化を提案（実際は定数値の1行変更）。→ **アーキテクト採用。**

### 品質チェック結果
- スコープ: 適切。YAML 39件 + MD 16件 + コード5-6ファイル修正。1PRに収まる
- サブタスク粒度: 4タスクが適正
- 見落とし: Dockerfile の COPY 命令追加を両者とも明示的に言及しきれていなかったため補完
- YAGNI: 過剰な分解なし
- 優先度 medium: 妥当。DX改善だが編集頻度が高く生産性に直結
