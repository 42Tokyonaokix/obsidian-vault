---
title: "スキル分解とルーター設計"
date: 2026-03-20
project: obsidian-vault-setup
tags: [skill, task-management, architecture]
---

## 概要

manage-tasksスキルを4つの個別スキルに分解し、ルータースキル`tasks`を新設する設計を行った。

## 作業内容

### 背景

manage-tasks は1つの SKILL.md に5操作（追加・一覧・更新・分解・デイリー）を詰め込んでいた。操作ごとにスキルを分割してClaudeが適切なスキルを発見・使用しやすくする。

### 実施済み: スキル分解

manage-tasks を以下4スキルに分解した（decompose は add に統合）:

| スキル | 役割 |
|--------|------|
| tasks-add | タスク追加（曖昧なタスクの対話的分解も含む） |
| tasks-list | タスク一覧表示 |
| tasks-update | ステータス・進捗の更新 |
| tasks-daily | デイリープランニング |

### 設計済み・未実装: ルータースキルと description 最適化

#### 通し番号 → 不採用

- ディレクトリ名 = スキル識別子のため、`01-tasks-add` だと `/01-tasks-add` になり不便
- Claude は description でスキルを発見するため番号は無意味

#### ルータースキル `tasks` → 採用

全タスク関連キーワードを広くキャッチする `tasks` スキルを新設し、ルーティングテーブルでサブスキルに振り分ける設計:

- `tasks` の description に広いトリガーワードを集約
- 各サブスキルの description は狭くして、ルーターが優先マッチ
- フロー図はルーター SKILL.md 内に dot 記法で埋め込み

#### ルーティングテーブル

| ユーザーの意図 | 振り分け先 |
|---------------|-----------|
| タスク追加・作成・分解 | tasks-add |
| タスク一覧・確認 | tasks-list |
| ステータス更新・完了 | tasks-update |
| 今日のタスク・デイリー | tasks-daily |

## 決定事項

- スキル名に通し番号は付けない
- ルータースキル `tasks` を作成してサブスキルに振り分ける
- サブスキルの description を狭めてルーター優先マッチにする
- フロー図はルータースキル内に埋め込む

## 次にやること

- `~/.claude/skills/tasks/SKILL.md` の作成（ルーター本体）
- 各サブスキルの description を狭める
- 動作確認（ルーター経由 & 直接呼び出し）
