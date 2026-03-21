---
title: "Obsidian Summarize スキルの設計と実装"
date: 2026-03-22
project: 02_obsidian-vault
tags: [skill, obsidian, summarize]
---

## 概要

プロジェクトノートが増えてサイドバーが見づらくなる問題に対し、`01-obsidian-summarize` スキルを新設。AIがノートをグルーピングし、サマリーファイル + サブディレクトリで整理する機能を実装した。

## 作業内容

### 背景

`projects/42-chatbot/` が20ファイルに膨らみ、Obsidianサイドバーでの一覧が見づらくなっていた。関連するファイル群をまとめてサブディレクトリに移動し、サマリーファイルで俯瞰できるようにしたい。

### 設計（brainstorming）

3つのアプローチを検討:
- **A: 独立スキル `01-obsidian-summarize` を新設**（採用）— 責務が明確、既存スキルに影響なし
- B: `01-obsidian-write` の拡張 — 責務が膨らむため却下

設計で決定した事項:
- AIが内容を読んで自動でグルーピングを提案（ユーザーは承認のみ）
- サマリーファイル = インデックステーブル + まとめ読み物
- ファイル名: `{start}-{end}-{slug}.md`、サブディレクトリは同名（`.md` なし）
- registry.md は読み取りのみ（更新しない）
- `projects/` のみ対象（`tasks/` は対象外）
- ユーザーの明示的な指示でのみ発動

スペック: `docs/superpowers/specs/2026-03-22-obsidian-summarize-design.md`
プラン: `docs/superpowers/plans/2026-03-22-obsidian-summarize.md`

### 実装内容

**Task 1: `01-obsidian-summarize` スキル作成**
- `~/.claude/skills/01-obsidian-summarize/SKILL.md` を新規作成
- ワークフロー: git pull → ファイル読み込み → グルーピング提案 → ユーザー承認 → サマリー生成 → git mv → コミット
- サマリーファイルテンプレート: frontmatter（type: summary, range）+ インデックステーブル + まとめ
- エッジケース: 番号なしファイル、重複番号、再実行（インクリメンタル）、3件未満、日本語ファイル名

**Task 2: ルーター更新**
- `01-tasks` にトリガー6件追加: 「まとめて」「サマリー」「summarize」「整理して」「ノートをまとめて」「プロジェクトまとめ」
- ルーティングテーブル行追加: `ノートまとめ・サマリー・整理 → 01-obsidian-summarize`
- dot graph にノード・エッジ追加

**Task 3: dotfiles同期**
- `~/dotfiles/claude/skills/obsidian-summarize/SKILL.md` を作成（`name: obsidian-summarize`）
- dotfiles リポジトリにコミット

### 変更ファイル

| ファイル | 変更 |
|---------|------|
| `~/.claude/skills/01-obsidian-summarize/SKILL.md` | 新規作成 |
| `~/.claude/skills/01-tasks/SKILL.md` | トリガー・ルーティングテーブル・dot graph更新 |
| `~/dotfiles/claude/skills/obsidian-summarize/SKILL.md` | 新規作成（同期コピー） |

## 所感

- 既存スキルへの影響なし。ルーターに1行追加のみ
- 再実行時のインクリメンタル動作は、「ルート直下の .md のみ対象」というルールで自然に実現
- サマリーファイルの `type: summary` frontmatter で再実行時のスキップも明確
