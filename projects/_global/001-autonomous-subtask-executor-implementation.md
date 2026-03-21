---
title: "自律サブタスク実行システムの実装"
date: 2026-03-21
project: _global
tags: [claude-code, skills, automation, discord]
---

## 概要

01-tasks-execute スキルと3つのsuperpowersラッパースキル、Discord通知ヘルパーを実装し、Obsidian vaultのタスクを自律的に実行する仕組みを構築した。

## 作業内容

### 実装したコンポーネント

| コンポーネント | 場所 | 役割 |
|---------------|------|------|
| discord-notify.sh | `scripts/discord-notify.sh` | Discord Webhook 通知（jq/sed JSON エスケープ、10秒タイムアウト） |
| auto-writing-plans | `~/.claude/skills/auto-writing-plans/` | superpowers:writing-plans の自律ラッパー |
| auto-executing-plans | `~/.claude/skills/auto-executing-plans/` | superpowers:executing-plans の自律ラッパー |
| auto-verification | `~/.claude/skills/auto-verification/` | superpowers:verification-before-completion の自律ラッパー |
| 01-tasks-execute | `~/.claude/skills/01-tasks-execute/` | メインオーケストレーター（12ステップフロー） |
| 01-tasks ルーター | `~/.claude/skills/01-tasks/` | execute ルート追加 |

### 実行フロー

1. `#autorun` タグ付きタスクをスキャン → 優先度順に選定
2. Discord 開始通知
3. 3者エージェントチーム（PM/アーキテクト/批評家）で brainstorming
4. ユーザー承認ゲート（承認/却下/修正依頼）
5. auto-writing-plans で実装計画生成
6. `task/{id}-{slug}` ブランチ作成
7. サブタスクごとに: auto-executing-plans → auto-verification → 進捗更新
8. Discord 完了通知

### 処理粒度

- brainstorming: タスクファイル全体
- 計画作成・実装・検証: サブタスク（チェックボックス）ごと

### 安全策

- `#autorun` タグによるオプトイン必須
- ブランチ隔離（main 直接変更禁止）
- brainstorming 後のユーザー承認ゲート
- 失敗時は status を todo に戻す + Discord エスカレーション

### 同時に実装したもの

- Claude Sandbox Container（`~/naoki/docker/Dockerfile` + `~/naoki/scripts/run-claude.sh`）

## 決定事項

- Discord 通知は Webhook 方式（CLI Anything は Discord に不適合）
- タスク選定は `#autorun` タグによるシンプルなオプトイン（段階的自律は将来対応）
- 処理粒度は brainstorming がファイル単位、実装がサブタスク単位
- 失敗時の専用ステータス（failed/blocked）は導入せず、todo に戻す運用

## 次にやること

- `DISCORD_WEBHOOK_URL` 環境変数の設定
- Docker コンテナのビルド・動作確認
- 実際のタスクに `#autorun` タグを付けてエンドツーエンドテスト
