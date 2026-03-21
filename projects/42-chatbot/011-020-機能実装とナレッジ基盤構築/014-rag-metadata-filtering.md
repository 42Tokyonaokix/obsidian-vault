---
title: "RAG メタデータフィルタリング: UI選択ベースの voltage_type / area フィルタ実装"
date: 2026-03-22
project: 42-chatbot
tags: [rag, metadata, filtering, contract, ui]
---

## 概要

セッション一覧ページに voltage_type / area の選択 UI を追加し、選択値を Cookie に保存してRAG検索時にハード除外フィルタリングを適用する機能を実装。タグ付きチャンクの不一致を除外し、タグなし/generalチャンクは通過させる方式。

## 作業内容

### Brainstorming (3-Agent Team)
- PM: 要件整理。DGM API が既に voltage_type/power_area を返すことを発見し、タスクファイルの前提（plan_type マッピング必要）との乖離を修正
- Architect: ContextVar パターンを推奨。voltage_type は post-filter（表記揺れ対応）、area は DB フィルタの設計
- Critic: 2つの重大問題を指摘 — (1) user_id→契約取得APIが未定義、(2) area DB フィルタが Q&A を除外する問題

### ユーザー判断
- DGM API 連携は不要。ログイン画面（セッション一覧ページ）に選択 UI を配置
- フィルタロジック: タグ付きで不一致 → 除外、タグなし → 通過
- area も post-filter 方式（DB フィルタだと untagged チャンクが除外されるため）

### 実装（9タスク、9コミット）

| # | 内容 | ファイル |
|---|------|---------|
| 1 | ContractContext ContextVar モジュール | `src/app/agents/tools/contract_context.py` (新規) |
| 2 | ハード除外フィルタ関数追加 | `src/app/rag/filters/voltage_filter.py` |
| 3 | CONTRACT_FILTER_ENABLED フラグ | `src/shared/config/settings.py` |
| 4 | orchestrator に ContractContext 注入 | `src/app/graph/orchestrator.py` |
| 5 | qa_search.py で ContractContext 使用 | `src/app/agents/tools/qa_search.py` |
| 6 | sessions.html にフィルタ選択 UI | `src/app/web/templates/sessions.html`, `routes.py` |
| 7 | chat.html にフィルタ表示 + hidden field | `src/app/web/templates/chat.html`, `routes.py` |
| 8 | 統合テスト + Cookie URL-encoding 修正 | `tests/web/test_filter_cookies.py` |
| 9 | lint 修正 | 各ファイル |

### テスト結果
- 新規テスト 23件: 全パス
- 既存テスト: 1件の pre-existing failure（test_escalation.py — 本実装とは無関係）

### 技術的ポイント
- Cookie に日本語値を保存する際は `urllib.parse.quote/unquote` で URL エンコードが必要（latin-1 エンコードエラー回避）
- voltage_type の表記揺れ対応: チャンクメタデータに「高圧特別高圧」「高圧・特別高圧」の2パターンがあり、「高圧」「特別高圧」クエリの両方にマッチさせる
- 契約コンテキスト由来はハード除外、クエリ検出由来はソフト優先（既存の並べ替え方式を維持）

## 決定事項

- フィルタ方式: ハード除外（タグ不一致を除外）+ null パススルー（タグなしは通過）
- area も voltage_type も post-filter で統一（DB フィルタだと untagged チャンクが除外されるため）
- DGM API 連携ではなく UI 選択方式を採用（将来的に API 連携に拡張可能な設計）
- ブランチ: `task/002-rag-metadata-filtering`

## 次にやること

- E2E 手動検証（Docker 環境でのフィルタ動作確認）
- PR 作成・レビュー
- タスクファイル（002-rag-metadata-filtering.md）のサブタスク更新
