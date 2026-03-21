---
title: "タスクプランニングスキル再設計"
date: 2026-03-22
project: 02_obsidian-vault
tags: [skill, planning, obsidian, tasks]
---

## 概要

`01-tasks-add` と `01-tasks-add-auto` を「タスク列挙」から「実装着手可能なプランニング」に再定義し、Obsidian への出力を大幅に拡充した。

## 作業内容

### 背景

ブレストや対話で話し合った内容に対して、Obsidian に出力されるタスクファイルの情報量が少なすぎる問題があった。概要 + チェックボックスだけでは、タスクファイルを見たエージェントがそのまま実装に着手できない。

ユーザーとの対話で明確になった方針:
- **ユーザーとの会話 = プランニング過程そのもの** — 会話で出た内容をすべてObsidianに出力する
- **会話に出ていない推測は書かない** — AIが勝手に補完した内容は載せない
- `01-tasks-add` と `01-tasks-add-auto` は別々の方向性で改善する

### 設計（brainstorming）

3つのアプローチを検討:
- **A: タスクファイルをプラン文書に拡張**（採用）— 既存の Obsidian 構造・frontmatter と互換。1ファイルで完結
- B: プラン文書とタスクファイルを分離 — 2ファイル管理が必要で却下
- C: タスクファイル廃止してプラン文書に一本化 — 既存スキル（list, update, daily）との互換性が崩れるため却下

スペック: `docs/superpowers/specs/2026-03-22-task-planning-skill-redesign.md`
プラン: `docs/superpowers/plans/2026-03-22-task-planning-skill-redesign.md`

### 実装内容

**`01-tasks-add` の改修:**
- 「対話型プランニング + タスク追加」に再定義
- 3原則を追加: 会話内容をすべて記録、推測は書かない、実装可能なプラン
- テンプレートを拡張: 背景・目的、スコープ（やること/やらないこと）、設計判断、各タスクの詳細、前提条件、補足
- 「会話内容の追跡」セクション追加: 対話中に何を追跡してテンプレートに流し込むかの指示
- 直接コミット（従来通り）

**`01-tasks-add-auto` の改修:**
- 「AIエージェントによるプランニング + PRベースの承認」に再定義
- 3エージェント（PM/Architect/Critic）のプロンプトは変更なし
- テンプレートを拡張: 要件定義、技術検討、議論サマリー、設計判断、各タスクの詳細 + PM判断ログ、アーキテクト技術調査メモ、Critic議論ログ（生出力の全文保存）
- Step 4: ターミナルへの詳細表示を廃止 → ブランチ `task/{project}/{slug}` でPR作成
- Step 5: ターミナルでの承認を廃止 → PR上でレビュー、マージで完了

**`01-tasks` ルーターの更新:**
- トリガーに「プランニング」「計画して」「AIプランニング」を追加
- ルーティングテーブルとdot graphのラベルを更新

**dotfiles 同期:**
- `~/dotfiles/claude/skills/tasks-add/SKILL.md` を `01-tasks-add` と同期

### 変更ファイル

| ファイル | 変更 |
|---------|------|
| `~/.claude/skills/01-tasks-add/SKILL.md` | 全面書き換え |
| `~/.claude/skills/01-tasks-add-auto/SKILL.md` | 全面書き換え |
| `~/.claude/skills/01-tasks/SKILL.md` | トリガー・ルーティングテーブル更新 |
| `~/dotfiles/claude/skills/tasks-add/SKILL.md` | 01-tasks-add と同期 |

## 所感

- 他スキル（list, update, daily, execute）は変更不要。frontmatter スキーマが変わっていないため互換性が保たれた
- `01-tasks-execute` はタスクファイルの情報量が増えたことで、実装着手しやすくなるはず
