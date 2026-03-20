---
title: "タスク管理機能の設計と実装"
date: 2026-03-20
project: obsidian-vault-setup
tags: []
---

## 概要

Obsidian vaultにタスク管理機能を追加。ディレクトリ構造・ファイルフォーマット・ドキュメント・管理スキルを設計・実装した。

## 作業内容

- brainstormingでタスク管理のアーキテクチャを設計
  - データ保存: Markdownファイル（Obsidianで閲覧・編集可能）
  - ファイル構成: タスクグループごとに1ファイル
  - 置き場所: `tasks/` トップレベルディレクトリ新設
  - ステータス: frontmatter + チェックボックスのハイブリッド
  - 横断TODO: `tasks/_global/` に配置
- subagent-driven developmentで4タスクを実装:
  - `tasks/` `tasks/_global/` ディレクトリ作成
  - `write-and-push.sh` に `tasks/` を追加
  - `WRITING_GUIDE.md` にタスク管理セクション追加
  - サンプルタスクファイル作成
- `manage-tasks` スキルを設計・作成（`~/.claude/skills/manage-tasks/`）
  - CRUD（追加・一覧・更新・完了）
  - タスク分解（brainstormingラッパー）
  - デイリープランニング（priority→放置期間ソート、対話で調整）

## 決定事項

- タスクはregistry.mdに含めない（frontmatterスキャンで一覧取得）
- frontmatterフィールド: title, date, project, status, progress, priority, tags
- チェックボックス記法: `[ ]`未着手, `[/]`進行中, `[x]`完了
- statusはサブタスクの状態から自動決定
- スキルは1つに集約（`manage-tasks`）、分割せず全機能を含める
- 優先順位ソート: priority(high>medium>low) → dateの古い順

## 次にやること

- `manage-tasks` スキルの実運用テスト
- デイリープランニングのロジック改善（使いながら調整）
- 必要に応じてスキルのトリガー条件を調整
