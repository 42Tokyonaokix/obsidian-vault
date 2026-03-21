---
title: "問い合わせフォーム: カテゴリ選択 + LLM下書き生成機能"
date: 2026-03-22
project: 42-chatbot
tags: [tier2, inquiry, zendesk, frontend, api]
---

## 概要

問い合わせフォーム（/inquiry）にカテゴリ選択と LLM による下書き自動生成機能を実装。Widget から thread_id 付きで遷移し、会話ログからカテゴリ別の推奨項目 + サマリを自動プリフィルする。

## 作業内容

### 背景

- 既存の inquiry ページは件名+本文のみのシンプルなフォーム
- Docker リビルド未実施で page not found 状態だった
- Tier 2 設計スペックで定義されたカテゴリタグ・構造化サマリがフォームに未統合

### 実装内容

#### バックエンド（Python/FastAPI）

1. **`dicts_to_messages()` ヘルパー** (`src/app/services/summary.py`)
   - Redis ConversationCache の `list[dict]` を LangChain `list[BaseMessage]` に変換

2. **`generate_structured_summary()` 拡張** (`src/app/services/summary.py`)
   - `category` パラメータ追加（指定時は ■ 箇条書きフォーマット、未指定時は既存の自動判定）
   - `_build_category_prompt()` 新設：カテゴリ別推奨項目を LLM に抽出させるプロンプト
   - 後方互換性維持（既存の escalation.py からの呼び出しは影響なし）

3. **`POST /api/v1/zendesk/draft`** (`src/app/api/v1/zendesk.py`)
   - thread_id + category → Redis から会話取得 → LLM で構造化サマリ生成 → subject/body/business_tag を返却
   - エラーハンドリング: 404（会話なし）、422（不正カテゴリ）、502（LLM 障害）

4. **`POST /api/v1/zendesk/tickets` に `business_tag` 追加**
   - オプショナルパラメータ、デフォルト "other"
   - 不正値は "other" にフォールバック

#### フロントエンド

5. **Widget** (`widget/src/components/ChatPanel.tsx`)
   - 問い合わせボタンのリンクに `?thread_id=xxx` を付与

6. **Inquiry ページ** (`mock-platform/app/inquiry/page.tsx`)
   - カテゴリドロップダウン（8カテゴリ、バックエンド TAG_DEFINITIONS のミラー）
   - 「会話から下書きを生成」ボタン（thread_id がある場合のみ表示）
   - ローディングスピナー、エラー表示
   - business_tag を送信時に含める

### テスト

- `tests/services/test_summary_structured.py`: 13 テスト（dicts_to_messages, パーサー, プロンプトビルダー）
- `tests/api/test_zendesk_draft.py`: 8 テスト（draft 正常系/異常系, tickets business_tag）

### コミット一覧

| SHA | メッセージ |
|-----|----------|
| `9699702` | feat: add dicts_to_messages helper and structured output parser tests |
| `eedb42d` | feat: extend generate_structured_summary with category parameter |
| `ea71404` | feat: add POST /api/v1/zendesk/draft endpoint |
| `defdd20` | feat: pass thread_id in inquiry URL query parameter |
| `b75cfb8` | feat: inquiry page with category selection and LLM draft generation |

### 動作確認

- `http://localhost:9002/inquiry` → HTTP 200
- `POST /api/v1/zendesk/draft` → 認証なしで適切にエラー返却

## 設計ドキュメント

- スペック: `docs/superpowers/specs/2026-03-22-inquiry-page-design.md`
- 実装計画: `docs/superpowers/plans/2026-03-22-inquiry-page.md`

## 残課題

- E2E 手動テスト（ブラウザでログイン → チャット → 問い合わせ → 下書き生成の一連フロー）
- EscalationOffer.tsx（チャット内エスカレーション提案 UI）は未実装（別タスク）
- Docker 環境内でのテスト実行環境整備（pytest が Docker venv に未インストール）
