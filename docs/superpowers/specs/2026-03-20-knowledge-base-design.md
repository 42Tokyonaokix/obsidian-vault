# ナレッジベース設計

## 背景

Obsidian vaultをナレッジベースとして構築する。主にClaude（AIエージェント）が書き手・読み手となり、ユーザー（naoki）も読み書きする。別プロジェクトで作業中のエージェントが、作業完了後にこのvaultに直接書き込む運用を想定。

## 要件

- **用途**: PC上のあらゆる作業の知識を蓄積
- **読み書き**: Claude（主に書き手＋読み手）、naoki（読み手＋時々書き手）
- **主要ユースケース**: プロジェクトの作業記録・引き継ぎ、汎用ナレッジの蓄積
- **規模**: 年間数千件ペース（1時間に1件程度）
- **方針**: Obsidian機能はシンプルに（フォルダ＋マークダウン基本）

## 1. ディレクトリ構造

```
02_obsidian-vault/
  projects/           ← プロジェクト作業記録
    {project-name}/
      {sub-project}/  ← 必要に応じてネスト
  knowledge/           ← 汎用ナレッジ
    {category}/
  registry.md          ← 全ノートの目次
  WRITING_GUIDE.md     ← Claudeへの書き込みガイドライン
  scripts/
    write-and-push.sh  ← 自動コミット＆プッシュ
  .obsidian/           ← Obsidian設定
```

### ルール

- プロジェクト名・カテゴリ名はケバブケース（例: `webapp-dev`, `python-tips`）
- 新しいプロジェクトやカテゴリのフォルダは必要になった時点で作成
- ネストは最大2階層（`projects/big-project/sub-project/`）まで

## 2. ファイル命名規則

```
{NNN}-{slug}.md
```

- `NNN`: フォルダ内での通し番号、3桁ゼロ埋め（001, 002, ...）
- `slug`: 内容を短く表す英語のケバブケース（例: `initial-setup`, `asyncio-basics`）
- 採番は対象フォルダ内の最大番号 + 1
- 999件を超えたら4桁に移行（0001〜）

### 例

```
projects/webapp-dev/001-initial-setup.md
projects/webapp-dev/002-auth-implementation.md
knowledge/python/001-asyncio-basics.md
```

## 3. ノートテンプレート

### 作業記録（projects用）

```markdown
---
title: "認証機能の実装"
date: 2026-03-20
project: webapp-dev
tags: []
---

## 概要
何をしたか、1〜2行の要約

## 作業内容
具体的な作業の詳細

## 決定事項
このセッションで決めたこと（あれば）

## 次にやること
引き継ぎ事項（あれば）
```

### 汎用ナレッジ（knowledge用）

```markdown
---
title: "asyncioの基本"
date: 2026-03-20
category: python
tags: []
---

## 概要
何についてのノートか、1〜2行の要約

## 内容
本文
```

### 共通ルール

- frontmatterは必須（title, date, tags）
- `tags`は空配列でもよいが、フィールド自体は省略しない
- セクションは必要なものだけ使う（「決定事項」「次にやること」がなければ省略可）
- `概要`は必須（registry.mdに転記するため）

## 4. レジストリファイル（registry.md）

Claudeがノートを探すための目次ファイル。

```markdown
# Registry

## projects

### webapp-dev
| # | タイトル | 日付 | 概要 |
|---|---------|------|------|
| 001 | 認証機能の実装 | 2026-03-20 | Firebase Authを使った認証フローの構築 |

### webapp-dev/docker-optimization
| # | タイトル | 日付 | 概要 |
|---|---------|------|------|
| 001 | Dockerfile見直し | 2026-03-22 | マルチステージビルドへの移行 |

## knowledge

### python
| # | タイトル | 日付 | 概要 |
|---|---------|------|------|
| 001 | asyncioの基本 | 2026-03-20 | async/awaitの基本パターンと使い分け |
```

### ルール

- ノートを書いたら必ずレジストリにも1行追加する
- プロジェクト/カテゴリごとにテーブルを分ける
- 新しいフォルダを作ったらレジストリにもセクションを追加する
- Claudeが読みに来るときは、まずこのファイルを読んで対象を絞り込む

## 5. 書き込みガイドライン（WRITING_GUIDE.md）

別プロジェクトから書き込みに来るClaudeが最初に読むファイル。

### 書き込み手順

1. このファイルを読む
2. `git pull` で最新化
3. registry.md を読んで、対象フォルダの最新番号を確認する
4. ノートを作成する（テンプレートに従う）
5. registry.md に1行追加する
6. `scripts/write-and-push.sh "docs({project}): {slug}"` を実行

### コミットメッセージ形式

```
docs({project-name}): {slug}
```

例: `docs(webapp-dev): auth-implementation`

## 6. 自動pushスクリプト（scripts/write-and-push.sh）

ノート書き込み後にコミット＆プッシュを自動化するスクリプト。

```bash
#!/bin/bash
set -e

VAULT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$VAULT_DIR"

git add -A
git diff --cached --quiet && echo "No changes to commit" && exit 0
git commit -m "$1"
git pull --rebase
git push
```

- 引数にコミットメッセージを渡す
- `pull --rebase` で他のエージェントの書き込みとの競合を最小化
