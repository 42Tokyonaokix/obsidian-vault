# manage-tasks スキル 設計スペック

## 目的

タスク管理の全操作を1つのスキルに集約する。CRUD、タスク分解、デイリープランニングを提供。

## 機能

### 1. タスク追加
- タスクファイルをWRITING_GUIDE.mdのテンプレートに従って作成
- frontmatter + チェックボックス生成
- registry.mdには含めない

### 2. タスク一覧
- `tasks/` 全ファイルのfrontmatterをスキャン
- status, priority, progress を表示

### 3. タスク更新
- チェックボックスの状態変更
- frontmatter(status/progress)を自動同期
  - 全サブタスク未着手 → status: todo
  - 1つでも着手 → status: in_progress
  - 全サブタスク完了 → status: done
  - progress: 完了数/全数 を自動計算

### 4. タスク分解（brainstormingラッパー）
- 曖昧なタスク入力をユーザーと対話して明確化
- サブタスクに分解
- タスクファイルとして保存

### 5. デイリープランニング
- トリガー: 「今日のタスク」/ セッション開始時に自動提案
- ロジック:
  1. tasks/ 全ファイルのfrontmatterスキャン
  2. status: todo or in_progress を抽出
  3. ソート: priority(high>medium>low) → dateの古い順
  4. ユーザーに提示、対話で調整（追加・除外・優先度変更）

## 発動トリガー

- 明示的: 「タスク追加して」「タスク一覧」「完了にして」「今日のタスク」
- 自動: 会話の文脈からタスク操作と判断した場合、セッション開始時のデイリー提案
- 日本語キーワード: 「タスク」「やること」「TODO」「今日何する」

## ファイル操作ルール

- 全操作はWRITING_GUIDE.mdのルールに従う
- 操作前に `git pull` で最新化
- 操作後に `scripts/write-and-push.sh` でコミット&プッシュ

## 配置

`~/.claude/skills/manage-tasks/SKILL.md`

## スコープ外

- Obsidianプラグイン連携
- 外部サービス連携（Linear, Jira等）
- 通知機能
