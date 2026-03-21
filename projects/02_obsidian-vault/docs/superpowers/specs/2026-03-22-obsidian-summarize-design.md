# Obsidian Summarize Skill Design

## 背景・課題

Obsidian vaultの `projects/` ディレクトリにファイルが増え（例: `42-chatbot/` は20ファイル）、サイドバーでの一覧が見づらくなっている。関連するファイル群をグルーピングし、サマリーファイルで俯瞰できるようにしたい。

## 設計概要

`01-obsidian-summarize` スキルを新設する。ユーザーが対象プロジェクトを指定すると、AIが全ファイルを読んでグルーピングを提案し、承認後にサブディレクトリへの移動とサマリーファイル生成を行う。

## スキルの流れ

1. `git pull` で最新化
2. 対象ディレクトリのルート直下の `.md` ファイルを全件読む（サブディレクトリ内のファイルは対象外）
3. 内容をもとにグルーピングを提案（ターミナルに表示）
   - 例: 「001-007: 初期調査とレビュー」「008-014: 機能実装」
   - グルーピングは連続番号の範囲で行う（飛び番号にしない）
4. ユーザーが承認（or グループ名・まとめ方の修正指示）
5. 各グループのサマリーファイルを生成
6. サブディレクトリを作成し、元ファイルを `git mv` で移動
7. `write-and-push.sh` でコミット

## ファイル構造

### Before

```
projects/42-chatbot/
  001-full-repo-code-review.md
  002-repository-implementation-deep-dive.md
  ...
  020-widget-filter-ui.md
  drafts/
```

### After

```
projects/42-chatbot/
  001-007-初期調査とレビュー.md        ← サマリー
  001-007-初期調査とレビュー/
    001-full-repo-code-review.md
    ...
    007-jwt-token-injection-fix.md
  008-014-機能実装.md                  ← サマリー
  008-014-機能実装/
    008-multi-agent-jwt-token-analysis.md
    ...
    014-rag-metadata-filtering.md
  015-020-デプロイとUI.md              ← サマリー
  015-020-デプロイとUI/
    015-three-feature-push.md
    ...
    020-widget-filter-ui.md
  drafts/                              ← そのまま
```

### 命名規則

- サマリーファイル名: `{start}-{end}-{slug}.md`（番号は3桁ゼロ埋め）
- サブディレクトリ名: サマリーファイルと同名（`.md` 拡張子なし）
- `drafts/`、`docs/` など既存サブディレクトリは対象外
- 既にサブディレクトリにまとめ済みのファイルは対象外（ルートの `.md` のみ対象）

## サマリーファイルテンプレート

```yaml
---
title: "001-007 初期調査とレビュー"
date: YYYY-MM-DD
project: project-name
type: summary
range: [1, 7]
tags: []
---
```

```markdown
## インデックス

| # | タイトル | 日付 | 概要 |
|---|---------|------|------|
| 001 | ... | ... | ... |
| 002 | ... | ... | ... |
...

## まとめ

グループ全体の流れ・成果・意思決定をまとめた読み物。
AIが全ファイルを読んで生成する。
```

### frontmatter フィールド

| フィールド | 説明 |
|-----------|------|
| `title` | `{start}-{end} {グループ名}` |
| `date` | サマリー作成日 |
| `project` | プロジェクト名 |
| `type` | `summary`（通常ノートと区別） |
| `range` | `[start, end]`（番号の範囲） |
| `tags` | 空配列 |

### サマリー本文の構成

1. **インデックス**: 各ファイルの番号・タイトル・日付・1行要約のテーブル（registry.mdから引用）
2. **まとめ**: グループ全体の流れ・成果・意思決定を読み物としてまとめたもの

## スキル配置

| ファイル | 説明 |
|---------|------|
| `~/.claude/skills/01-obsidian-summarize/SKILL.md` | スキル本体 |
| `~/dotfiles/claude/skills/obsidian-summarize/SKILL.md` | dotfiles同期コピー |

## ルーター更新

`~/.claude/skills/01-tasks/SKILL.md` に追加:

- **トリガーワード**: 「まとめて」「サマリー」「summarize」「整理して」
- **ルーティングテーブル行**: `ノートまとめ・サマリー → 01-obsidian-summarize`
- **dot graph**: ノード・エッジ追加

## 対象外

- registry.md の更新（変更しない）
- 自動発動（ユーザーの明示的な指示でのみ発動）
- タスクファイル（`tasks/` ディレクトリ）の整理（`projects/` のみ対象）

## トリガーワード一覧

`description` フィールドに設定するトリガー:
- 「まとめて」「サマリー」「summarize」「整理して」「ノートをまとめて」「プロジェクトまとめ」
