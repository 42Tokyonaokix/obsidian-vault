---
title: "スキルルーター・番号帯プレフィックスの実装"
date: 2026-03-21
project: 02_obsidian-vault
tags: [skill, refactoring, implementation]
---

## 概要

003で設計したスキルルーターとグループ番号帯プレフィックスを実装した。

## 作業内容

### 1. スキルディレクトリのリネーム

6つの自作スキルに `01-` プレフィックスを付与:

| 変更前 | 変更後 |
|--------|--------|
| obsidian-read | 01-obsidian-read |
| obsidian-write | 01-obsidian-write |
| tasks-add | 01-tasks-add |
| tasks-daily | 01-tasks-daily |
| tasks-list | 01-tasks-list |
| tasks-update | 01-tasks-update |

各 SKILL.md の `name` フィールドも更新。

### 2. サブスキルの description 最適化

ルーターが優先マッチするよう、サブスキルから広いキーワード（タスク、TODO、ナレッジベース、vault、Obsidian）を除去し、各スキル固有のトリガーのみに絞った。

### 3. ルータースキル `01-tasks` の作成

`~/.claude/skills/01-tasks/SKILL.md` を新規作成:

- 広いトリガーワードを集約した description
- 6サブスキルへのルーティングテーブル
- dot 記法のフロー図
- 曖昧な場合は1つ質問してからルーティング

## 決定事項

- 00/02 番号帯（プラグイン管理スキル）はリネーム対象外
- 01 番号帯のみ自作スキルとして管理
- サジェスト機能でプレフィックスなしの名前入力でもマッチすることを確認済み
