# Knowledge Base Setup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Obsidian vaultをナレッジベースとして使うための初期構造・ガイドライン・スクリプトを整備する

**Architecture:** ディレクトリ構造（projects/ + knowledge/）、registry.md（目次）、WRITING_GUIDE.md（ガイドライン）、write-and-push.sh（自動push）の4要素で構成。すべてマークダウンとシェルスクリプトのみ。

**Tech Stack:** Markdown, Bash, Git

**Spec:** `docs/superpowers/specs/2026-03-20-knowledge-base-design.md`

---

## File Structure

| Action | Path | Responsibility |
|--------|------|---------------|
| Create | `.gitignore` | Obsidianキャッシュ等の除外 |
| Create | `projects/.gitkeep` | projectsディレクトリの保持 |
| Create | `knowledge/.gitkeep` | knowledgeディレクトリの保持 |
| Create | `registry.md` | 全ノートの目次 |
| Create | `WRITING_GUIDE.md` | Claude向け書き込み・読み込みガイドライン |
| Create | `scripts/write-and-push.sh` | 自動コミット＆プッシュスクリプト |
| Delete | `ようこそ.md` | Obsidianデフォルトファイル（不要） |

---

### Task 1: .gitignoreの作成

**Files:**
- Create: `.gitignore`

- [ ] **Step 1: .gitignoreを作成**

```
# Obsidian
.obsidian/workspace.json
.obsidian/workspace-mobile.json
.obsidian/plugins/
.obsidian/community-plugins.json
.obsidian/hotkeys.json

# OS
.DS_Store
Thumbs.db
```

保持するObsidian設定: `app.json`, `appearance.json`, `core-plugins.json`, `graph.json`（vaultの基本設定）

- [ ] **Step 2: コミット**

```bash
git add .gitignore
git commit -m "chore: add .gitignore for Obsidian cache and OS files"
```

---

### Task 2: ディレクトリ構造の作成

**Files:**
- Create: `projects/.gitkeep`
- Create: `knowledge/.gitkeep`
- Delete: `ようこそ.md`

- [ ] **Step 1: ディレクトリを作成し、デフォルトファイルを削除**

```bash
mkdir -p projects knowledge
touch projects/.gitkeep knowledge/.gitkeep
rm -f ようこそ.md
```

- [ ] **Step 2: コミット**

```bash
git add projects/.gitkeep knowledge/.gitkeep
git rm -f ようこそ.md 2>/dev/null || true
git commit -m "chore: create projects/ and knowledge/ directories, remove default note"
```

---

### Task 3: registry.mdの作成

**Files:**
- Create: `registry.md`

- [ ] **Step 1: registry.mdを作成**

```markdown
# Registry

## projects

(まだノートはありません)

## knowledge

(まだノートはありません)
```

- [ ] **Step 2: コミット**

```bash
git add registry.md
git commit -m "docs: add registry.md as note index"
```

---

### Task 4: WRITING_GUIDE.mdの作成

**Files:**
- Create: `WRITING_GUIDE.md`

- [ ] **Step 1: WRITING_GUIDE.mdを作成**

以下の内容をすべて含めること:

```markdown
# Writing Guide

このvaultにノートを書き込む・読み込む際のルール。

## ディレクトリ構造

- `projects/{project-name}/` — プロジェクト作業記録
- `projects/{project-name}/{sub-project}/` — サブプロジェクト（最大2階層）
- `knowledge/{category}/` — 汎用ナレッジ
- フォルダ名はケバブケース（例: `webapp-dev`, `python-tips`）
- 新しいフォルダは必要に応じて作成してよい

## ファイル命名

- `{NNN}-{slug}.md`（例: `001-initial-setup.md`）
- 対象フォルダ内の最大番号 + 1 で採番（3桁ゼロ埋め）
- 999件を超えたら4桁に移行（既存ファイルはリネームしない）

## テンプレート

### 作業記録（projects用）

\```yaml
---
title: "タイトル"
date: YYYY-MM-DD
project: project-name
tags: []
---
\```

セクション:
- `## 概要` — 必須。何をしたか1〜2行で。registry.mdに転記する
- `## 作業内容` — 具体的な作業の詳細
- `## 決定事項` — このセッションで決めたこと（あれば）
- `## 次にやること` — 引き継ぎ事項（あれば）

### 汎用ナレッジ（knowledge用）

\```yaml
---
title: "タイトル"
date: YYYY-MM-DD
category: category-name
tags: []
---
\```

セクション:
- `## 概要` — 必須。何についてのノートか1〜2行で。registry.mdに転記する
- `## 内容` — 本文

### 共通ルール

- frontmatterは必須（title, date, tags）
- tagsは空配列でもよいが、フィールド自体は省略しない
- 概要は必須（registry.mdに転記するため）

## 書き込み手順

1. このファイルを読む
2. `git pull` で最新化する
3. registry.md を読んで、対象フォルダの最新番号を確認する
4. ノートを作成する（テンプレートに従う）
5. registry.md に1行追加する
6. `scripts/write-and-push.sh "コミットメッセージ"` を実行する

## 読み込み手順

1. `git pull` で最新化する
2. registry.md を読んで対象ノートを特定する
3. 対象ノートを読む

## コミットメッセージ形式

- projects用: `docs({project-name}): {slug}`
  - 例: `docs(webapp-dev): auth-implementation`
- knowledge用: `docs(knowledge/{category}): {slug}`
  - 例: `docs(knowledge/python): asyncio-basics`

## registry.md の更新ルール

ノートを書いたら必ずregistry.mdにも1行追加する。

新しいフォルダを作った場合、registryにもセクションを追加する:

\```markdown
### {folder-path}
| # | タイトル | 日付 | 概要 |
|---|---------|------|------|
| 001 | ノートタイトル | YYYY-MM-DD | 概要テキスト |
\```
```

注意: 上記の `\``` ` はプラン中のエスケープ表記。実ファイルでは通常の ` ``` ` にすること。

- [ ] **Step 2: コミット**

```bash
git add WRITING_GUIDE.md
git commit -m "docs: add WRITING_GUIDE.md with read/write procedures and templates"
```

---

### Task 5: write-and-push.shの作成

**Files:**
- Create: `scripts/write-and-push.sh`

- [ ] **Step 1: scriptsディレクトリとスクリプトを作成**

```bash
mkdir -p scripts
```

`scripts/write-and-push.sh`:

```bash
#!/bin/bash
set -e

if [ -z "$1" ]; then
  echo "Usage: $0 <commit-message>"
  exit 1
fi

VAULT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$VAULT_DIR"

git add projects/ knowledge/ registry.md WRITING_GUIDE.md
git diff --cached --quiet && echo "No changes to commit" && exit 0
git commit -m "$1"
git pull --rebase
git push
```

- [ ] **Step 2: 実行権限を付与**

```bash
chmod +x scripts/write-and-push.sh
```

- [ ] **Step 3: コミット**

```bash
git add scripts/write-and-push.sh
git commit -m "feat: add write-and-push.sh for automated commit and push"
```

---

### Task 6: 動作確認

- [ ] **Step 1: ディレクトリ構造を確認**

```bash
ls -la projects/ knowledge/ scripts/
cat registry.md
cat WRITING_GUIDE.md
```

期待: projects/, knowledge/ にそれぞれ .gitkeep が存在。registry.md と WRITING_GUIDE.md の内容がスペック通り。

- [ ] **Step 2: スクリプトの実行権限を確認**

```bash
test -x scripts/write-and-push.sh && echo "OK" || echo "FAIL"
```

期待: `OK`

- [ ] **Step 3: git statusがクリーンであることを確認**

```bash
git status
```

期待: `nothing to commit, working tree clean`
