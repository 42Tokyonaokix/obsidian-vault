---
title: "Claude Sandbox Container の実装"
date: 2026-03-21
project: dotfiles
status: in_progress
progress: 2/5
priority: high
tags: [docker, claude-code, sandbox]
---

## 概要

Claude Code を ~/naoki/ に閉じ込めた Docker コンテナ内で動かすための Dockerfile と起動スクリプトを実装する。設計スペックは `docs/superpowers/specs/2026-03-21-claude-sandbox-container-design.md` に確定済み。

## タスク

- [x] Dockerfile を作成 (`~/naoki/docker/Dockerfile`)
  - [x] Ubuntu 24.04 ベース
  - [x] git, bash, jq, openssh-client, python3, gh をインストール
  - [x] NodeSource で Node.js 24 をインストール
  - [x] npm install -g @anthropic-ai/claude-code
  - [x] uv インストーラ実行
  - [x] naoki ユーザー作成 (UID=1000, GID=1000)
- [x] 起動スクリプトを作成 (`~/naoki/scripts/run-claude.sh`)
  - [x] 5つのボリュームマウント (naoki/, .claude/, .ssh/:ro, .gitconfig:ro, .config/gh/:ro)
  - [x] TERM, LANG 環境変数の引き渡し
  - [x] 引数の透過的パススルー ($@)
- [ ] イメージをビルドして動作確認
  - [ ] docker build -t claude-sandbox
  - [ ] claude --version がコンテナ内で実行できる
  - [ ] git pull/push がコンテナ内から動作する
- [ ] Claude Code の対話モードで正常動作を確認
  - [ ] TUI が正しく表示される
  - [ ] ~/naoki/ 配下のファイルが見える
  - [ ] ~/naoki/ 以外のホストファイルが見えない
- [ ] Obsidian に完了記録を書く
