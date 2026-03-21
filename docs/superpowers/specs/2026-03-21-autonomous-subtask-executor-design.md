# 自律サブタスク実行システム設計

## 概要

Obsidian vault のタスクを自律的に実行・レビュー・通知する仕組み。`#autorun` タグ付きタスクを検出し、3者エージェントチームで brainstorming → ユーザー承認 → 計画作成 → 実装 → 検証 → Discord 通知の一連のフローを実行する。

## コンポーネント

### 1. discord-notify.sh

- 場所: `~/naoki/02_obsidian-vault/scripts/discord-notify.sh`
- 機能: Discord Webhook でメッセージ送信
- 環境変数: `DISCORD_WEBHOOK_URL`
- インターフェース: `discord-notify.sh "メッセージ"`
- エラー時: 非ゼロ exit code、stderr に出力（通知失敗でタスク実行は止めない）

### 2. 01-tasks-execute スキル

- 場所: `~/.claude/skills/01-tasks-execute/SKILL.md`
- 役割: メインオーケストレーター

#### 実行フロー (13ステップ)

1. `#autorun` タグ付き + `status: todo` のタスクをスキャン
2. 優先度順 (high > medium > low)、同優先度は日付昇順でタスク選定
3. `discord-notify.sh` で開始通知（タスク名、プロジェクト）
4. タスクの `status` を `in_progress` に更新（01-tasks-update 経由）
5. 3者エージェントチーム brainstorming（詳細は後述「brainstorming エージェントチーム仕様」）
6. brainstorming の会話ログをユーザーに提示、承認を待つ
   - **承認**: ステップ7へ進む
   - **却下**: タスクの `status` を `todo` に戻し、`tags` から `autorun` を除去、Discord 通知（却下理由付き）、終了
   - **修正依頼**: ユーザーのフィードバックを追加コンテキストとして brainstorming を再実行（ステップ5へ戻る、最大2回まで。超過時は `tags` から `autorun` を除去 + Discord 通知でエスカレーション）
7. 承認後、auto-writing-plans でスペック + 実装計画を生成
8. 対象リポジトリ（タスク frontmatter の `repo` フィールドで指定）に `task/{id}-{slug}` ブランチを作成。ブランチが既に存在する場合はタイムスタンプ付き `task/{id}-{slug}-{YYYYMMDDHHmmss}` で作成
9. auto-executing-plans で実装を実行
10. auto-verification で検証（テスト実行、コマンド出力の証拠収集）
    - **検証成功**: ステップ11へ
    - **検証失敗**: Discord 通知でエスカレーション、タスク `status` を `todo` に戻す、ブランチは保持（デバッグ用）、終了
11. タスクファイルの進捗・ステータスを更新（01-tasks-update 経由）
12. `discord-notify.sh` で完了通知（成功、変更サマリ、ブランチ名）
13. エラー・不明点発生時（任意のステップで）: 停止 + タスク `status` を `todo` に戻す + Discord 通知でエスカレーション（どのステップで失敗したか、エラー内容を含む）

#### タスク選定ルール

- frontmatter `tags` に `autorun` を含む
- `status: todo`（`in_progress` はスキップ = 並行実行防止）
- 優先度: high > medium > low
- 同優先度内は date 昇順（古いものから）

#### タスク frontmatter 例

```yaml
---
title: "機能Xの実装"
date: 2026-03-21
project: my-project
status: todo
progress: 0/3
priority: high
tags: [autorun]
repo: ~/naoki/01_Digital-Grid/42-chatbot
---
```

- `repo`: 実装対象のリポジトリパス。省略時は vault 自体 (`~/naoki/02_obsidian-vault`)
- `tags` に `autorun` を含めることでオプトイン

### 3. brainstorming エージェントチーム仕様

#### 実装方式

3つの Agent tool 呼び出しを**順次実行**する。各エージェントは前のエージェントの出力を受け取る。

#### フロー

1. **PM エージェント** (Agent tool, model: sonnet)
   - 入力: タスクファイル全文 + プロジェクト構造の概要
   - 出力: 要件定義書（目的、スコープ、成功基準、制約条件）
   - 指示: 「ユーザーの立場からこのタスクの要件を整理せよ。何を作るのか、何を作らないのか、完了条件は何か」

2. **アーキテクトエージェント** (Agent tool, model: sonnet)
   - 入力: タスクファイル全文 + PM の要件定義書 + 対象リポジトリのコードベース概要
   - 出力: 技術設計書（アプローチ、コンポーネント構成、ファイル構造、依存関係）
   - 指示: 「PM の要件に基づいて技術設計を行え。既存コードとの整合性を重視し、2-3のアプローチを比較した上で推奨案を示せ」

3. **批評家エージェント** (Agent tool, model: opus)
   - 入力: タスクファイル全文 + PM の要件定義書 + アーキテクトの技術設計書
   - 出力: レビュー（問題点、見落とし、エッジケース、改善提案）
   - 指示: 「PM の要件とアーキテクトの設計をレビューせよ。穴、見落とし、過剰設計、不整合を指摘し、改善案を示せ」

#### 会話ログのフォーマット

ユーザーに提示する形式:

```markdown
## Brainstorming: {タスクタイトル}

### PM: 要件定義
{PM の出力}

### アーキテクト: 技術設計
{アーキテクトの出力}

### 批評家: レビュー
{批評家の出力}

---
承認しますか？ (承認 / 却下 / 修正依頼)
```

#### 終了条件

批評家のレビューが完了した時点で1ラウンド終了。ユーザーに提示して承認を待つ。

### 4. auto-writing-plans スキル

- 場所: `~/.claude/skills/auto-writing-plans/SKILL.md`
- 役割: superpowers:writing-plans のラッパー
- 入力: brainstorming の会話ログ（承認済み）をコンテキストとして渡す。具体的には、PM の要件定義 + アーキテクトの技術設計 + 批評家のレビューを結合した文字列
- 動作: superpowers:writing-plans を呼び出し、対話なしで実装計画を生成
- 出力: `docs/superpowers/plans/YYYY-MM-DD-<feature-name>.md` に書き出し

### 5. auto-executing-plans スキル

- 場所: `~/.claude/skills/auto-executing-plans/SKILL.md`
- 役割: superpowers:executing-plans のラッパー
- 入力: 計画ファイルパス
- 動作: 計画を対話なしで逐次実行
- 安全策: タイムアウト30分（超過時エスカレーション）
- 注意: `write-and-push.sh` はタスクファイル更新専用。実装コードのコミットは対象リポジトリ内で通常の git commit を使用

### 6. auto-verification スキル

- 場所: `~/.claude/skills/auto-verification/SKILL.md`
- 役割: superpowers:verification-before-completion のラッパー
- 動作: 実装結果の検証を自動実行
- 出力スキーマ:
  ```
  status: pass | fail
  evidence:
    - command: "実行したコマンド"
      output: "コマンド出力（末尾100行以内）"
      result: pass | fail
  summary: "検証結果の要約（1-2文）"
  ```
- fail 時: `summary` にどの検証が失敗したかを明記

### 7. 01-tasks ルーター更新

- `01-tasks/SKILL.md` のルーティングテーブルに追加:
  - トリガー: 「タスク実行」「自律実行」「autorun」「execute」
  - 委譲先: `01-tasks-execute`

## 安全策

| メカニズム | 詳細 |
|-----------|------|
| オプトイン | `#autorun` タグ必須。タグなしタスクは一切実行しない |
| ブランチ隔離 | main 直接変更禁止。`task/{id}-{slug}` ブランチで作業 |
| ユーザー承認ゲート | brainstorming 後に必ず承認を取る。却下・修正依頼も可 |
| エスカレーション | 不明点・エラー・タイムアウト時は停止 + Discord 通知 |
| 並行実行防止 | `status: in_progress` のタスクはスキャン対象外 |
| 失敗時リカバリ | `status` を `todo` に戻す。ブランチは保持（デバッグ用） |

## 起動方法

### 手動起動
ユーザーが「タスク実行して」「autorun」等と指示 → 01-tasks ルーター → 01-tasks-execute

### 自動起動
`/loop` コマンド（superpowers プラグインの定期実行機能）で定期実行:
```
/loop 10m /01-tasks-execute
```
注: `/loop` は Claude Code セッション内で動作。セッション外の自動起動は本スコープ外。

## 依存関係

- 既存スキル: 01-tasks-update, 01-tasks-list
- superpowers: writing-plans, executing-plans, verification-before-completion
- 外部: `DISCORD_WEBHOOK_URL` 環境変数の設定
- スクリプト: `write-and-push.sh`（タスクファイル更新のコミット・プッシュ専用）

## スコープ外

- タスクの `failed` / `blocked` ステータス追加（現行の todo/in_progress/done で運用。失敗時は todo に戻す）
- セッション外での自動起動（cron 等）
- 複数タスクの並行実行
