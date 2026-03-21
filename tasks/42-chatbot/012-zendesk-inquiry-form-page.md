---
title: "問い合わせフォームページの作成（Zendesk連携）"
date: 2026-03-22
project: 42-chatbot
status: todo
progress: 0/4
priority: high
tags: [zendesk, mock-platform, ui, inquiry-form]
---

## 背景・目的

Widget の bot メッセージに常時表示される問い合わせボタン（メールアイコン）は実装済みだが、遷移先が `GET /api/v1/zendesk/form` → 外部 Zendesk URL へのリダイレクトになっており、実際のフォームページが存在しない。ユーザーがボタンを押しても有効なページに到達できない状態。

mock-platform（Next.js）に問い合わせフォームページを新設し、バックエンドの Zendesk チケット作成 API と連携させる。

## 要件定義

- **目的**: 問い合わせボタンの遷移先として機能するフォームページを作成し、ユーザーが問い合わせ内容を入力→Zendesk チケット作成→完了確認まで一貫して行えるようにする
- **スコープ**:
  - やること: mock-platform に `/inquiry` ページを新設
  - やること: バックエンドに `POST /api/v1/zendesk/tickets` エンドポイントを新設
  - やること: widget の問い合わせボタンの遷移先を `/inquiry` ページに変更
  - やること: フォーム送信後の完了画面を表示
  - やらないこと: Zendesk Embedded SDK の導入（外部依存を増やさない）
  - やらないこと: 既存のエスカレーション機能（条件付き自動 Zendesk チケット作成）への変更
  - やらないこと: フォームの入力バリデーションの高度化（基本的な必須チェックのみ）
- **成功基準**:
  1. 問い合わせボタン押下 → フォームページが表示される
  2. フォームに件名・本文を入力して送信 → Zendesk チケットが作成される
  3. 送信後に完了画面（チケット番号表示）が表示される
  4. Zendesk 未設定時はフォーム送信でエラーメッセージが表示される

## 技術検討

### 現状の構成

- **widget**: `MessageBubble.tsx` の問い合わせボタンが `window.open(zendeskFormUrl, "_blank")` で `{apiUrl}/api/v1/zendesk/form` を開く
- **バックエンド**: `GET /api/v1/zendesk/form` が外部 Zendesk URL へ 302 リダイレクト
- **mock-platform**: Next.js アプリ（port 9002）。`/dashboard` のみ存在
- **ZendeskClient**: `create_ticket(TicketCreate)` が実装済み。`TicketCreate` は subject, body, requester_email, tags, custom_fields を受け取る

### アプローチ

1. **mock-platform に `/inquiry` ページを新設**: Next.js の `app/inquiry/page.tsx` として作成。JWT を localStorage から取得してバックエンド API に認証付きリクエスト
2. **バックエンドに `POST /api/v1/zendesk/tickets` を新設**: リクエストボディの subject/body を受け取り、`ZendeskClient.create_ticket()` を呼び出す。JWT からユーザー情報を取得してチケットに付与
3. **widget の遷移先を変更**: `zendeskFormUrl` を mock-platform の `/inquiry` URL に変更。`apiUrl` ではなく mock-platform の origin を使う必要があるため、widget の設定で mock-platform URL を渡す方法を検討

### リスク

- **CORS**: mock-platform（port 9002）から FastAPI（port 8000）への POST。既に `allow_origins=["http://localhost:9002"]` が設定済みなので問題なし
- **認証**: JWT は localStorage にあるため、inquiry ページからバックエンド API に `Authorization: Bearer` ヘッダーで渡せる
- **widget → mock-platform への遷移**: widget は `apiUrl`（port 8000）しか知らない。mock-platform の URL を知る方法が必要。`window.location.origin` が mock-platform 内で動作している場合はそのまま使える（widget は mock-platform の dashboard 上で動いているため、`window.location.origin` = `http://localhost:9002`）

## タスク

- [ ] mock-platform に `/inquiry` フォームページを作成
- [ ] バックエンドに `POST /api/v1/zendesk/tickets` エンドポイントを追加
- [ ] widget の問い合わせボタン遷移先を inquiry ページに変更
- [ ] テスト追加

## 各タスクの詳細

### サブタスク1: mock-platform に `/inquiry` フォームページを作成

- **目的**: ユーザーが問い合わせ内容を入力・送信できるフォーム画面を提供する
- **やること**:
  - `mock-platform/app/inquiry/page.tsx` を新規作成
  - フォーム項目: 件名（text）、問い合わせ内容（textarea）
  - JWT を localStorage から取得し、API リクエストに使用
  - 送信時: `POST http://localhost:8000/api/v1/zendesk/tickets` にリクエスト
  - 送信成功: チケット番号と「送信完了」メッセージを表示
  - 送信失敗: エラーメッセージを表示
  - ダッシュボードへ戻るリンクを配置
- **技術的ポイント**: 難易度 M。Next.js の Client Component として実装。既存の dashboard/page.tsx のパターン（JWT 取得、認証チェック）を踏襲
- **対象ファイル**: `mock-platform/app/inquiry/page.tsx`（新規）
- **前提/依存**: なし（サブタスク2と並列可能。API 未実装の間はフォームUIだけ先に作れる）
- **完了条件**: `/inquiry` にアクセスしてフォームが表示される

### サブタスク2: バックエンドに `POST /api/v1/zendesk/tickets` エンドポイントを追加

- **目的**: フォームからの問い合わせを受け取り、Zendesk チケットを作成する
- **やること**:
  - `src/app/api/v1/zendesk.py` に `POST /tickets` エンドポイントを追加
  - リクエストボディ: `{ subject: str, body: str }`
  - JWT から `email` を取得してチケットの `requester_email` に設定
  - `app.state.zendesk_client.create_ticket()` を呼び出し
  - レスポンス: `{ ticket_id: int, status: str }` を返す
  - Zendesk 未設定時: 適切なエラーレスポンス（503）
- **技術的ポイント**: 難易度 S。既存の `ZendeskClient.create_ticket()` と `TicketCreate` モデルをそのまま使える。JWT 認証は既存の `get_current_user` 依存関数を使用
- **対象ファイル**: `src/app/api/v1/zendesk.py`（既存に追加）
- **前提/依存**: なし
- **完了条件**: `POST /api/v1/zendesk/tickets` が正常にチケットを作成し、ticket_id を返す

### サブタスク3: widget の問い合わせボタン遷移先を inquiry ページに変更

- **目的**: 問い合わせボタンが実際のフォームページに遷移するようにする
- **やること**:
  - `ChatPanel.tsx` の `zendeskFormUrl` を `${window.location.origin}/inquiry` に変更
  - widget は mock-platform（ホストページ）の iframe/Shadow DOM 内で動作しているため、`window.location.origin` で mock-platform の origin（`http://localhost:9002`）が取得できる
  - 既存の `GET /api/v1/zendesk/form` リダイレクトエンドポイントは削除または残置（inquiry ページに直接遷移するため不要になる）
- **技術的ポイント**: 難易度 S。1行の URL 変更
- **対象ファイル**: `widget/src/components/ChatPanel.tsx` L51
- **前提/依存**: サブタスク1 が完了していること
- **完了条件**: 問い合わせボタン押下で `/inquiry` ページが新タブで開かれる

### サブタスク4: テスト追加

- **目的**: エンドポイントの正常動作を検証する
- **やること**:
  - `POST /api/v1/zendesk/tickets` のテスト（正常系・Zendesk未設定時のエラー系）
  - `tests/api/test_zendesk.py` を新規作成
- **技術的ポイント**: 難易度 S。既存のテストパターン（`test_chat_stream.py` 等）を踏襲
- **対象ファイル**: `tests/api/test_zendesk.py`（新規）
- **前提/依存**: サブタスク2 が完了していること
- **完了条件**: テストが pass すること

## 前提条件・依存関係

- サブタスク1（フロントエンド）とサブタスク2（バックエンド）は並列実施可能
- サブタスク3はサブタスク1に依存
- サブタスク4はサブタスク2に依存
- 既存の ZendeskClient、TicketCreate モデル、JWT 認証基盤は変更不要

## 補足

- 本タスクは mock-platform（開発用プラットフォーム）にページを追加するもの。本番環境では DGM プラットフォーム側に同等のページを用意する必要がある
- `GET /api/v1/zendesk/form` の外部リダイレクトエンドポイントは、inquiry ページ導入後は不要になるが、互換性のため残置してもよい
- エスカレーション機能（条件付き自動チケット作成）は本タスクとは独立。本タスクはユーザーが能動的に問い合わせるフローを提供する
