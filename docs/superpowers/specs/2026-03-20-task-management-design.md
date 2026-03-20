# タスク管理機能 設計スペック

## 目的

Obsidian vaultにタスク管理機能を追加する。プロジェクト単位のタスクと横断的なTODOの両方を管理し、Claudeがスキル経由で操作できるようにする。

## ディレクトリ構造

```
tasks/
  _global/           ← プロジェクト横断TODO
    001-slug.md
  {project-name}/    ← プロジェクト単位のタスク
    001-slug.md
```

- `tasks/` をトップレベルに新設（`projects/`, `knowledge/` と並列）
- `_global/` は横断的なタスク用の特別ディレクトリ
- プロジェクト名はケバブケース（`projects/` と同じ命名規則）
- ファイル命名は既存ルール踏襲: `{NNN}-{slug}.md`

## タスクファイルフォーマット

1ファイル = 1タスクグループ（サブタスクをネストして含む）

```markdown
---
title: "タスクグループのタイトル"
date: 2026-03-20
project: project-name
status: todo
progress: 0/3
priority: high
tags: []
---

## 概要

タスクグループの説明。1〜2行。

## タスク

- [ ] サブタスク1
  - [ ] さらにネストしたタスク
- [ ] サブタスク2
- [ ] サブタスク3
```

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

### チェックボックスの記法

- `- [ ]` — 未着手
- `- [/]` — 進行中
- `- [x]` — 完了

### statusの自動決定ルール

- 全サブタスク未着手 → `todo`
- 1つでも着手 → `in_progress`
- 全サブタスク完了 → `done`

## registry.mdとの関係

タスクはregistry.mdに含めない。理由: タスクは頻繁に状態が変わるため、registry更新が負担になる。frontmatterスキャンで一覧取得する。

## write-and-push.shの更新

`git add` の対象に `tasks/` を追加する。

## WRITING_GUIDE.mdの更新

タスク管理セクションを追加し、以下を記載する:
- タスクファイルのフォーマット
- frontmatterフィールドの説明
- チェックボックスの記法
- statusの自動決定ルール

## スコープ外

- `manage-tasks` スキルの作成（別途brainstormingで設計する）
- 今日のタスク抽出ロジック（スキルと一緒に設計する）
- タスクの優先順位付けロジック（同上）
