---
title: "Zendesk エスカレーション UI 接続 & 常時問い合わせボタン追加"
date: 2026-03-22
project: 42-chatbot
tags: [zendesk, escalation, widget, ui, feedback]
---

## 概要

バックエンド実装済みの Zendesk エスカレーション機能をフロントエンドに接続し、加えて全 bot メッセージに常時表示する「問い合わせ」ボタンを Good/Bad フィードバックボタンの横に追加。

## 作業内容

### 1. エスカレーション UI 接続（前半セッション）

バックエンドの `evaluate_response` ノードが `ui_resource` を state に設定していたが、SSE ストリームに乗っていなかった問題を修正。

**変更ファイル:**

- `src/app/services/agent/multi_agent/orchestrator.py` — `astream()` で `ui_resource` を `StreamEvent` として yield
- `src/app/api/v1/chat.py` — `ui_resource` イベントタイプを SSE として転送
- `widget/src/hooks/useSSE.ts` — `onUIResource` コールバック追加
- `widget/src/hooks/useConversation.ts` — `UIResourceData` 型と `escalationOffer` state 追加
- `widget/src/components/EscalationOffer.tsx` — 新規コンポーネント（確認/拒否ボタン）
- `widget/src/components/ChatPanel.tsx` — エスカレーション UI レンダリング
- `widget/src/styles/widget.css.ts` — エスカレーション CSS

**エスカレーション発動条件:**

1. bot 回答に失敗パターン含む（`FAILURE_PATTERNS` リスト）
2. LLM がビジネス関連と判定
3. `zendesk_client` が設定済み
4. `merged_by_llm=True` でない

### 2. 常時問い合わせボタン（後半セッション）

Good/Bad ボタンの右横にメールアイコンの「問い合わせ」ボタンを全 bot メッセージに常時表示。

**変更ファイル:**

- `src/app/api/v1/zendesk.py` — 新規。`GET /api/v1/zendesk/form` → Zendesk フォームへ 302 リダイレクト
- `src/app/api/v1/router.py` — zendesk router 追加
- `widget/src/components/MessageBubble.tsx` — 問い合わせボタン追加（`zendeskFormUrl` prop）
- `widget/src/components/MessageList.tsx` — `zendeskFormUrl` prop パススルー
- `widget/src/components/ChatPanel.tsx` — `${apiUrl}/api/v1/zendesk/form` を構築して渡す
- `widget/src/styles/widget.css.ts` — `.contact-btn` スタイル

**仕組み:**

- ボタンクリック → `window.open(apiUrl + '/api/v1/zendesk/form', '_blank')` → バックエンドが 302 → `https://{ZENDESK_SUBDOMAIN}.zendesk.com/hc/ja/requests/new`
- 未設定時は `support.zendesk.com` がデフォルト

### 3. ビルド問題の発見

widget ソース変更後 `npm run build` を再実行しないと `dist/widget.js` に反映されない。Docker は `widget/dist` をボリュームマウントしているため、ビルド忘れで変更が反映されない。

## 決定事項

- Zendesk フォームへの遷移はバックエンドリダイレクト方式（`GET /api/v1/zendesk/form`）を採用。フロントエンドが subdomain を知る必要がない
- 問い合わせボタンは条件なし常時表示。エスカレーション（条件付き）とは独立
- Good/Bad フィードバックボタンは既に動作していた（ローカル state + API POST）。見た目が地味なだけだった

## 次にやること

- `ZENDESK_SUBDOMAIN` 環境変数を `.env` に設定
- widget 変更後のビルドを CI/CD または watch モードで自動化する検討
- エスカレーション条件付き UI のテスト（失敗パターンを含む質問で確認）
