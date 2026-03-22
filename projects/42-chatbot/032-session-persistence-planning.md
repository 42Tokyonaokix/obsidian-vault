---
title: "セッション永続化 & 選択UI の設計・タスク起票"
date: 2026-03-22
project: 42-chatbot
tags: [conversation, persistence, ui, postgres, planning]
---

## 概要

会話セッションの永続化とChatGPT/Geminiライクなセッション選択UIの設計を行い、タスクファイル（015）を起票した。

## 作業内容

### 現状調査

PostgreSQLに格納されているデータを調査。以下が判明：

- **アプリテーブル**: source_documents, chunks, raptor_summaries, graph_entities, graph_relationships, graph_entity_embeddings, propositions, query_traces, widget_feedback
- **LangGraph checkpointer**: checkpoints, checkpoint_blobs, checkpoint_writes
- **会話履歴の二層構成**:
  - Redis キャッシュ（TTL 30分、最大20メッセージ）— `GET /chat/history/{thread_id}` はここからのみ取得
  - PostgreSQL（LangGraph AsyncPostgresSaver）— 永続化されているがユーザー向けAPIからは参照されていない

### 設計判断

以下を対話で決定：

1. **UI方式**: サイドバーにセッション一覧を表示し、クリックで切り替えるChatGPT方式
2. **表示項目**: タイトル（LLM自動生成）+ 最後のメッセージ
3. **認証・セキュリティ**: JWTの`user_id`でフィルタするユーザー向けAPIを新設（Admin APIとは別）。他ユーザーのセッションは返さない
4. **削除方式**: 論理削除（`deleted_at`タイムスタンプ）。UIから非表示にするがDBには残す

### 起票したタスク

`tasks/42-chatbot/015-session-persistence-and-selection.md` に5サブタスクで起票：

1. セッション管理のデータ層設計・実装
2. セッション一覧・履歴取得APIの新設
3. セッションタイトル自動生成（LLM）
4. セッション論理削除API
5. ウィジェットUIにサイドバー＋セッション選択を実装

## 決定事項

- checkpointerのテーブルに直接手を入れるのはLangGraphアップグレード時のリスクがあるため、別テーブル新設の方が安全（実装時に最終判断）
- セッション名の手動編集は今回のスコープ外
- 物理削除はしない

## 次にやること

- タスク015の実装着手（サブタスク1のデータ層設計から）
