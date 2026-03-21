---
title: "Tier 2 エスカレーション移植 & 問い合わせフォームページ作成"
date: 2026-03-22
project: 42-chatbot
tags: [zendesk, escalation, inquiry-form, tier2, widget, mock-platform]
---

## 概要

feat/tier2-escalation-enrichment ブランチ（旧アーキテクチャベース）のTier 2機能を現アーキテクチャに移植し、加えて問い合わせフォームページを新設。ブランチ `feat/tier2-port-and-inquiry-form` に push済み。

## 作業内容

### 1. ブランチ整理・マージ

- `refactor/knowledge-chunks-reorganize` → main に fast-forward マージ（PR #33 相当）
- `feat/tier2-escalation-enrichment` → main への直接マージは旧アーキテクチャとの大量コンフリクト（16件の modify/delete）で断念
- 代わりに Tier 2 のエッセンスを手動で現アーキテクチャに移植する方針に変更

### 2. Tier 2 移植（4ファイル新規/変更）

**`src/app/services/summary.py`（新規）:**
- `TagDefinition` / `StructuredSummary` データクラス
- `TAG_DEFINITIONS`: 8カテゴリ（口座振替依頼書、支払方法変更、ID/パスワード再発行、DGM設定メール再送、名義変更、容量変更、解約・切替、その他）
- `generate_structured_summary()`: LLM 1回呼び出しでカテゴリ検出+推奨項目抽出+会話サマリ生成
- `_parse_structured_output()`: LLM出力の `TAG: <slug>` パース

**`src/app/services/agent/multi_agent/nodes/escalation.py`（変更）:**
- `_is_business_related()` を拡張: `bool` → `tuple[bool, str | None]` に変更（業務判定＋カテゴリタグ検出を1回のLLM呼び出しで実行）
- エスカレーション判定プロンプトにタグ選択指示を追加
- `evaluate_response_node`: `business_tag` を state に書き込み
- `create_zendesk_ticket_node`: チケットの tags に `business_tag` を追加、本文に【カテゴリ】を記載

**`src/app/services/agent/multi_agent/state.py`（変更）:**
- `OrchestratorState` に `business_tag: str | None` フィールドを追加

**`src/app/services/agent/knowledge/chunks/general/faq_手続き案内.yaml`（新規）:**
- 7件のスタッフ対応誘導 Q&A チャンク（口座振替、支払方法変更、アカウント発行、名義変更、容量変更、解約、メール再送）
- 各チャンクは「問い合わせボタンからご連絡ください」で閉じる構成

### 3. 問い合わせフォームページ（012タスク、4ファイル新規/変更）

**`src/app/api/v1/zendesk.py`（変更）:**
- 既存 `GET /form`（リダイレクト）に加え `POST /tickets` エンドポイントを追加
- JWT認証（`CurrentUserDep`）でユーザーの email をチケットに設定
- `ZendeskClient.create_ticket()` を呼び出し、`ticket_id` を返却
- Zendesk 未設定時は 503 エラー

**`src/app/api/v1/router.py`（変更）:**
- `zendesk.router` を v1 router に登録

**`mock-platform/app/inquiry/page.tsx`（新規）:**
- 件名・本文フォーム → `POST /api/v1/zendesk/tickets` に送信
- JWT は localStorage から取得して Authorization ヘッダーに設定
- 送信成功: チケット番号表示 + ダッシュボードへ戻るボタン
- 送信失敗: エラーメッセージ表示
- 未認証時はログインページにリダイレクト

**widget（3ファイル変更）:**
- `ChatPanel.tsx`: `inquiryUrl = window.location.origin + '/inquiry'` を構築して渡す
- `MessageList.tsx`: `inquiryUrl` prop をパススルー
- `MessageBubble.tsx`: Good/Bad ボタンの右横にメールアイコンの問い合わせボタンを常時表示
- `widget.css.ts`: `.contact-btn` スタイル追加

### 4. 検証

- Python インポートチェック: `summary.py`, `escalation.py`, `zendesk.py` の全ルートOK
- TypeScript: エラーなし（`import.meta.env` の既知エラーを除く）
- Widget ビルド: 成功

## 決定事項

- `feat/tier2-escalation-enrichment` の直接マージは断念。旧アーキテクチャ（`src/app/graph/`, `src/app/web/`, `src/app/integrations/`）をベースとしており、16件のコンフリクトが発生するため
- Tier 2 の機能エッセンス（TAG_DEFINITIONS, business_tag 検出, 手続き案内チャンク）のみを現アーキテクチャに手動移植
- 問い合わせボタンの遷移先は、外部 Zendesk URL リダイレクトではなく mock-platform 内の `/inquiry` ページに変更
- `EscalationOffer.tsx`（条件付きエスカレーション UI）は今回のスコープ外として除外

## 次にやること

- `ZENDESK_SUBDOMAIN` 環境変数を `.env` に設定して動作確認
- Docker環境での統合テスト
- 010（IME Enter問題）と 011（related questions混入）の修正も別途マージが必要
