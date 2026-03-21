---
title: "Claude Sandbox Container の設計"
date: 2026-03-21
project: dotfiles
tags: [docker, claude-code, sandbox, design]
---

## 概要

Claude Code を Docker コンテナ内で起動し、~/naoki/ ディレクトリだけが見える隔離環境で自律駆動させるための設計を行った。

## 作業内容

### 目的

Claude に自律駆動させる際、ホスト上の不要なファイル（~/dgm-backend/, ~/legacy/ 等）に触れさせず、余計なリスクヘッジを取らせないためのサンドボックス。

### 検討したアプローチ

| アプローチ | 採否 | 理由 |
|-----------|------|------|
| Dockerfile + 起動スクリプト | 採用 | シンプルで目的に合う |
| Docker Compose | 不採用 | 単体コンテナにはオーバー |
| Dev Container (VS Code) | 不採用 | CLI用途には余分な設定が多い |

### 設計の要点

**Dockerfile:**
- Ubuntu 24.04 ベース（ホストWSLと同じ）
- git, Node.js 24 (NodeSource), Python 3, uv, gh, jq, Claude Code をインストール
- naoki ユーザー (UID=1000) で実行

**マウント構成:**
| ホスト | コンテナ内 | モード |
|--------|-----------|--------|
| ~/naoki/ | /home/naoki/naoki/ | rw |
| ~/.claude/ | /home/naoki/.claude/ | rw (OAuth token refresh に必要) |
| ~/.ssh/ | /home/naoki/.ssh/ | ro |
| ~/.gitconfig | /home/naoki/.gitconfig | ro |
| ~/.config/gh/ | /home/naoki/.config/gh/ | ro |

**起動スクリプト (`run-claude.sh`):**
- `docker run -it --rm` で対話起動、終了時に自動削除
- 引数を Claude Code に透過的にパススルー

### Docker-in-Docker

使わない。42-chatbot の compose.yml はホスト側で実行する前提。Docker Socket マウントはホストの全コンテナを触れてしまうため、隔離の意味が薄れる。将来必要になったらオプションで追加。

### スペックレビュー結果

2回のレビューを実施:
1. 1回目: `.gitconfig` 未マウント、gh CLI 未対応、Dockerfile ドラフト未記載 等の指摘 → 全件修正
2. 2回目: Approved。軽微な推奨（credential helper パス依存の明記、認証方式の明示、同時起動不可の記載）のみ

## 決定事項

- 認証は OAuth 前提（~/.claude/ マウント）。API キーは将来必要なら追加
- 同時起動は不可（--name 固定）
- SSH鍵はパスフレーズなし前提
- crontab (pull-all-repos) はホスト側で継続

## 次にやること

設計スペック (`~/naoki/docs/superpowers/specs/2026-03-21-claude-sandbox-container-design.md`) に基づいて Dockerfile と run-claude.sh を実装する。
