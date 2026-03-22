---
title: "PR: Tier 2 エスカレーション・問い合わせフォーム・RAGメタデータフィルタリング統合"
date: 2026-03-22
project: 42-chatbot
tags: [pr, tier2, inquiry, zendesk, rag, metadata-filtering, widget, grafana, docker, bugfix]
---

## 概要

feat/tier2-port-and-inquiry-form ブランチの全実装を main に統合する PR。Tier 2 エスカレーション移植、問い合わせフォーム（カテゴリ選択+LLM下書き生成）、RAGメタデータフィルタリング、Grafanaダッシュボード再構成、Docker/Widget バグ修正を含む。40ファイル変更、+4,691/-196行。

## 変更内容

### 1. Tier 2 エスカレーション移植（024）

旧アーキテクチャ（ContextVar + HTMX/Jinja2）の `feat/tier2-escalation-enrichment` ブランチから機能エッセンスを手動移植。直接マージは16件のコンフリクトにより断念。

- **`src/app/services/summary.py`（新規）**: TAG_DEFINITIONS（8カテゴリ）、`generate_structured_summary()`（LLM 1回でカテゴリ検出+推奨項目抽出+会話サマリ生成）
- **`src/app/services/agent/multi_agent/nodes/escalation.py`**: `_is_business_related()` を `tuple[bool, str | None]` に拡張（業務判定＋カテゴリタグ同時検出）、チケットに business_tag 付与
- **`src/app/services/agent/multi_agent/state.py`**: `business_tag` フィールド追加
- **`src/app/services/agent/knowledge/chunks/general/faq_手続き案内.yaml`（新規）**: スタッフ対応誘導 Q&A 7件

### 2. 問い合わせフォーム（025）

Widget から `/inquiry?thread_id=xxx` で遷移し、カテゴリ選択 → LLM 下書き生成 → 編集・送信の流れで Zendesk チケットを作成。

- **`POST /api/v1/zendesk/draft`（新規）**: thread_id + category → Redis 会話取得 → LLM 構造化サマリ → subject/body/business_tag 返却。エラー: 404/422/502
- **`POST /api/v1/zendesk/tickets` 拡張**: `business_tag` パラメータ追加（オプショナル、デフォルト "other"）
- **`mock-platform/app/inquiry/page.tsx`（全面書き換え）**: カテゴリドロップダウン（8カテゴリ）、「会話から下書きを生成」ボタン、ローディング/エラー表示、Suspense boundary
- **`widget/src/components/ChatPanel.tsx`**: inquiryUrl に `thread_id` クエリパラメータ付与
- **`src/app/services/summary.py` 拡張**: `dicts_to_messages()` ヘルパー、`category` パラメータで ■ 箇条書きフォーマット切替

### 3. RAG メタデータフィルタリング（026）

voltage_type / area のハード除外フィルタを SingleReact + React Widget に移植。

- **`src/app/services/retrieval/advanced/filters/voltage_filter.py`（+136行）**: `exclude_mismatched_voltage_type()`、`detect_area()`、`filter_by_area()`、area 9エリア定義
- **`src/app/services/agent/tools/knowledge_search.py`（+52行）**: RunnableConfig から voltage_type/area 取得、post-filter 適用
- **`src/app/api/v1/chat.py` / `schemas/chat.py`**: voltage_type/area パラメータ追加
- **`src/app/services/agent/single_react.py`**: 既存 config.metadata パイプライン活用
- **`widget/src/components/FilterSelector.tsx`（新規）**: Shadow DOM 対応インラインスタイルの選択 UI
- **`widget/src/hooks/useFilterCookie.ts`（新規）**: Cookie 永続化（365日、encodeURIComponent）
- **`widget/src/hooks/useConversation.ts` / `useSSE.ts`**: フィルタ値を SSE リクエストに伝播

### 4. Grafana ダッシュボード再構成

- `fastapi.json` → 5分割: application-performance, chat-quality, infrastructure, llm-costs, postgresql, service-health
- 障害シナリオベースの構成に変更

### 5. Docker / Widget バグ修正

- **Docker build**: postgres Dockerfile 修正、mock-platform rebuild で inquiry ページ解決
- **Widget**: IME Enter 誤送信防止、RELATED_QUESTIONS デリミタリーク修正（バッファリングアルゴリズム）
- **Widget cross-origin**: API URL 解決修正
- **docker-compose.dev.yml**: env_file パスを `./env_file/development.local.env` → `.env` に修正

## テスト

- **バックエンド**: summary structured 13件、zendesk draft 8件、single_react streaming 130件
- **フロントエンド**: conversation 95件、input-area 75件
- **フィルタリング**: voltage_filter 174件、knowledge_search_filter 179件、chat_schema 82件
- **合計**: 47テスト全パス（メタデータフィルタリング）+ 21テスト全パス（問い合わせフォーム）

## 変更ファイル一覧（40ファイル）

| カテゴリ | 新規 | 変更 | 削除 |
|---------|------|------|------|
| バックエンド API/サービス | 3 | 5 | 0 |
| ナレッジチャンク | 1 | 0 | 0 |
| Widget (React) | 3 | 7 | 0 |
| テスト | 5 | 2 | 0 |
| Grafana ダッシュボード | 5 | 0 | 1 |
| ドキュメント | 2 | 0 | 0 |
| Docker/インフラ | 1 | 0 | 0 |
| mock-platform | 1 | 0 | 0 |

## 設計ドキュメント

- `docs/superpowers/specs/2026-03-22-inquiry-page-design.md`
- `docs/superpowers/plans/2026-03-22-inquiry-page.md`

## 残課題

- E2E 手動テスト（ブラウザでログイン → チャット → フィルタ選択 → 問い合わせ → 下書き生成の一連フロー）
- EscalationOffer.tsx（チャット内エスカレーション提案 UI）は未実装
- Docker 環境内での pytest 実行環境整備
- multi_agent の qa_search へのフィルタ適用はスコープ外
