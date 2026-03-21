# タスク管理機能 実装計画

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Obsidian vaultにタスク管理のインフラ（ディレクトリ、フォーマット、ドキュメント）を構築する

**Architecture:** `tasks/` トップレベルディレクトリにMarkdownファイルでタスクを管理。frontmatterでクイックスキャン、本文チェックボックスで詳細表示。

**Tech Stack:** Markdown, Bash (write-and-push.sh)

---

### Task 1: tasksディレクトリの作成

**Files:**
- Create: `tasks/.gitkeep`
- Create: `tasks/_global/.gitkeep`

- [ ] **Step 1: ディレクトリとgitkeepファイルを作成**

```bash
mkdir -p tasks/_global
touch tasks/.gitkeep tasks/_global/.gitkeep
```

- [ ] **Step 2: コミット**

```bash
git add tasks/
git commit -m "feat(tasks): create tasks directory structure"
```

---

### Task 2: write-and-push.shの更新

**Files:**
- Modify: `scripts/write-and-push.sh` (line 12)

- [ ] **Step 1: git addの対象にtasks/を追加**

現在の行:
```bash
git add projects/ knowledge/ registry.md WRITING_GUIDE.md
```

変更後:
```bash
git add projects/ knowledge/ tasks/ registry.md WRITING_GUIDE.md
```

- [ ] **Step 2: コミット**

```bash
git add scripts/write-and-push.sh
git commit -m "feat(tasks): add tasks/ to write-and-push.sh git add targets"
```

---

### Task 3: WRITING_GUIDE.mdにタスク管理セクションを追加

**Files:**
- Modify: `WRITING_GUIDE.md`

- [ ] **Step 1: WRITING_GUIDE.mdの末尾にタスク管理セクションを追加**

以下の内容を追加する:

````markdown

## タスク管理

### ディレクトリ構造

- `tasks/{project-name}/` — プロジェクト単位のタスク
- `tasks/_global/` — プロジェクト横断TODO
- フォルダ名はケバブケース（`projects/` と同じ命名規則）
- ファイル命名は既存ルール踏襲: `{NNN}-{slug}.md`
- 1ファイル = 1タスクグループ（サブタスクをネスト）

### タスクファイルテンプレート

`````yaml
---
title: "タスクグループのタイトル"
date: YYYY-MM-DD
project: project-name
status: todo
progress: 0/N
priority: high
tags: []
---
`````

セクション:
- `## 概要` — 必須。タスクグループの説明1〜2行
- `## タスク` — チェックボックスでサブタスク一覧

### チェックボックスの記法

- `- [ ]` — 未着手
- `- [/]` — 進行中
- `- [x]` — 完了

### frontmatterフィールド

| フィールド | 必須 | 値 |
|-----------|------|-----|
| title | yes | タスクグループのタイトル |
| date | yes | 作成日 YYYY-MM-DD |
| project | yes | プロジェクト名（`_global` も可） |
| status | yes | `todo` / `in_progress` / `done` |
| progress | yes | `完了数/全数`（トップレベルのサブタスクのみカウント） |
| priority | yes | `high` / `medium` / `low` |
| tags | yes | タグ配列（空でもフィールドは省略しない） |

### statusの自動決定ルール

- 全サブタスク未着手 → `todo`
- 1つでも着手 → `in_progress`
- 全サブタスク完了 → `done`

### registry.mdとの関係

タスクはregistry.mdに含めない。frontmatterスキャンで一覧取得する。
````

- [ ] **Step 2: コミット**

```bash
git add WRITING_GUIDE.md
git commit -m "docs: add task management section to WRITING_GUIDE.md"
```

---

### Task 4: サンプルタスクファイルの作成

**Files:**
- Create: `tasks/_global/001-setup-task-management-skill.md`

- [ ] **Step 1: サンプルタスクファイルを作成**

```markdown
---
title: "タスク管理スキルの設計と作成"
date: 2026-03-20
project: _global
status: todo
progress: 0/3
priority: high
tags: []
---

## 概要

manage-tasksスキルを設計・実装する。タスクの追加・更新・完了・一覧取得をスキル経由で操作できるようにする。

## タスク

- [ ] スキルのbrainstormingと設計
- [ ] スキルの実装
- [ ] 動作確認とドキュメント整備
```

- [ ] **Step 2: コミット**

```bash
git add tasks/
git commit -m "feat(tasks): add sample task file for skill creation"
```
