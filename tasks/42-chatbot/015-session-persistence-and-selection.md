---
title: "セッション永続化 & 選択UI（ChatGPT/Gemini方式）"
date: 2026-03-22
project: 42-chatbot
status: todo
progress: 0/5
priority: high
tags: [conversation, persistence, ui, postgres]
---

## 背景・目的

現在の会話履歴はRedisキャッシュ（TTL 30分、最大20メッセージ）に依存しており、セッションを跨いで過去の会話を継続できない。ChatGPTやGeminiのように、サイドバーから過去のセッションを選択して会話を再開できるようにしたい。PostgreSQL（LangGraph checkpointer）にはデータが永続化されているので、そこから取得する仕組みを作る。

## スコープ

### やること
- PostgreSQLのcheckpointerからユーザーごとのセッション一覧を取得するAPIを新設
- セッション履歴をPostgreSQLから取得するAPIを新設（Redisフォールバック→PostgreSQL）
- セッションのタイトル自動生成（LLMで会話内容から要約）
- セッション論理削除API（`deleted_at`をセット、DBからは参照可能のまま）
- ウィジェットUIにサイドバーを追加し、セッション一覧表示・選択・新規作成・削除を実装

### やらないこと
- セッション名の手動編集（将来追加可能だが今回は対象外）
- Admin APIの改修（既存のまま）
- 物理削除

## 設計判断

- **認証・セキュリティ**: 新設するユーザー向けAPIではJWTの`user_id`で必ずフィルタし、他ユーザーのセッションは絶対に返さない。Admin APIとは別のエンドポイントとして新設する。
- **論理削除方式**: `deleted_at`タイムスタンプを使い、UIからは非表示にするがPostgreSQLには残す。checkpointerテーブルにメタデータとして保存する or セッション管理用の軽量テーブルを新設するかは実装時に判断。
- **タイトル自動生成**: 最初のユーザーメッセージに対してLLMで短いタイトルを生成。会話開始時に非同期で実行。
- **セッション一覧の表示項目**: タイトル（自動生成）、最後のメッセージ内容。
- **履歴取得のフォールバック**: history APIはまずRedisを見て、なければPostgreSQL（checkpointer）から復元する。

## タスク

- [ ] サブタスク1: セッション管理のデータ層設計・実装
- [ ] サブタスク2: セッション一覧・履歴取得APIの新設
- [ ] サブタスク3: セッションタイトル自動生成
- [ ] サブタスク4: セッション論理削除API
- [ ] サブタスク5: ウィジェットUIにサイドバー＋セッション選択を実装

## 各タスクの詳細

### サブタスク1: セッション管理のデータ層設計・実装

- **目的**: セッションのメタデータ（タイトル、deleted_at等）を永続化する仕組みを作る
- **やること**: checkpointerのメタデータに`title`と`deleted_at`を追加する方式か、セッション管理用の軽量テーブル（`conversation_sessions`）を新設する方式かを調査・実装する。checkpointerの`checkpoints`テーブルのmetadata JSONBカラムにはすでに`user_id`、`tenant_id`が格納されている。
- **技術的ポイント**: LangGraphの`AsyncPostgresSaver`が管理するテーブル構造に手を入れるのはアップグレード時のリスクがあるため、別テーブル新設の方が安全かもしれない
- **完了条件**: セッションメタデータの保存・取得が可能な状態

### サブタスク2: セッション一覧・履歴取得APIの新設

- **目的**: ウィジェットから呼べるユーザー向けのセッションAPIを作る
- **やること**:
  - `GET /api/v1/chat/sessions` — JWTの`user_id`に紐づくセッション一覧を返す（`deleted_at`がnullのものだけ）。レスポンスにはタイトル、最後のメッセージ、日時を含む
  - `GET /api/v1/chat/history/{thread_id}` — 既存エンドポイントを改修し、Redisにデータがない場合はPostgreSQL（checkpointer）からフォールバック取得する
- **技術的ポイント**: checkpointerからメッセージを復元するには`AsyncPostgresSaver.aget`でcheckpointをデシリアライズする必要がある。既存の`admin/conversations.py`に実装例がある。`user_id`フィルタを必ず適用してセキュリティを担保する。
- **完了条件**: 自分のセッション一覧が取得でき、過去の会話履歴がPostgreSQLから復元できる

### サブタスク3: セッションタイトル自動生成

- **目的**: セッション一覧に表示するタイトルをLLMで自動生成する
- **やること**: 会話の最初のやり取り（ユーザーメッセージ + アシスタント応答）からLLMで短いタイトル（〜30文字程度）を生成し、セッションメタデータに保存する
- **技術的ポイント**: チャットストリーム完了後に非同期（fire-and-forget）で実行。タイトル未生成のセッションは最初のユーザーメッセージをフォールバック表示。
- **完了条件**: 新規セッションの初回応答後にタイトルが自動生成され保存される

### サブタスク4: セッション論理削除API

- **目的**: ユーザーがUIからセッションを非表示にできるようにする
- **やること**: `DELETE /api/v1/chat/sessions/{thread_id}` — `deleted_at`にタイムスタンプをセットする。JWTの`user_id`が一致するセッションのみ削除可能。
- **完了条件**: 削除したセッションが一覧に表示されなくなるが、PostgreSQLには残っている

### サブタスク5: ウィジェットUIにサイドバー＋セッション選択を実装

- **目的**: ChatGPT/Geminiライクなセッション選択UIをウィジェットに追加する
- **やること**:
  - サイドバーコンポーネントの新規作成（セッション一覧表示）
  - 各セッション行: タイトル + 最後のメッセージ
  - 「新しい会話」ボタン
  - セッションクリックで切り替え（履歴をロードして表示）
  - セッション削除ボタン（確認ダイアログ付き）
  - レスポンシブ対応（モバイルではハンバーガーメニュー等）
- **技術的ポイント**: 現在の`widget/`は`App.tsx` → `ChatPanel.tsx`の単一パネル構成。サイドバーを追加するにはレイアウトの変更が必要。`widget/src/hooks/`にAPI呼び出しのカスタムフックを追加する形が既存の構造と合う。
- **完了条件**: サイドバーからセッションを選択・作成・削除でき、選択したセッションの会話履歴が表示される

## 前提条件・依存関係

- LangGraph checkpointerのPostgreSQLテーブル（`checkpoints`, `checkpoint_blobs`）にデータが永続化されている前提
- JWT認証ミドルウェアが正常に動作し、`user_id`が取得できる前提
- checkpointerのメタデータに`user_id`、`tenant_id`がすでに保存されている（`admin/conversations.py`で確認済み）

## 補足

- 既存の`GET /admin/conversations`エンドポイント（`src/app/api/v1/admin/conversations.py`）にcheckpointerからの会話復元ロジックの実装例がある
- `src/app/services/agent/checkpointer.py`にcheckpointerの初期化コードがある
- `src/app/services/cache/conversation.py`がRedisキャッシュ層の実装
- `widget/src/components/`に既存のウィジェットコンポーネントがある
