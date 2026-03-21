---
title: "RAG メタデータフィルタリングを新アーキテクチャ（SingleReact + React Widget）に移植"
date: 2026-03-22
project: 42-chatbot
tags: [rag, metadata, filtering, port, single-react, widget]
---

## 概要

task/002-rag-metadata-filtering ブランチ（旧アーキテクチャ: ContextVar + HTMX/Jinja2）で完成済みの voltage_type / area フィルタリング機能を、新アーキテクチャ（SingleReact + config.metadata + React Widget）に移植。14ファイル変更、47テスト全パス。

## 作業内容

### ブランチ調査

- 全リモートブランチ（25本）を調査し、新アーキテクチャで途中実装しているブランチが存在しないことを確認
- 旧ブランチ `task/002-rag-metadata-filtering` の実装内容を精査（38ファイル、旧アーキテクチャ）
- Obsidian ノート 014 の作業記録を参照して実装仕様を確認

### 旧 vs 新アーキテクチャの差分分析

主な違いは2点のみ:
- **状態の渡し方**: ContextVar（暗黙的）→ RunnableConfig config.metadata（明示的）
- **UI**: HTMX/Jinja2 テンプレート → React ウィジェット

single_react.py の `astream()` は既に `voltage_type`/`area` パラメータを受け付けて config.metadata に格納する実装が存在（L292-293, L314-315）。ツール側とAPI側の接続が未実装だった。

### 実装（5タスク、Subagent-Driven Development）

| # | 内容 | ファイル |
|---|------|---------|
| 1 | フィルタロジック移植 | `voltage_filter.py` (+136行: exclude_mismatched_voltage_type/area, detect_area, filter_by_area) |
| 2 | knowledge_search フィルタ適用 | `knowledge_search.py` (+52行: RunnableConfig から取得、post-filter 適用、ログ出力) |
| 3 | chat.py API パラメータ追加 | `chat.py`, `schemas/chat.py` (+10行) |
| 4 | React Widget UI + Cookie | `FilterSelector.tsx` (新規), `useFilterCookie.ts` (新規), `ChatPanel.tsx`, `useSSE.ts`, `useConversation.ts` 修正 |
| 5 | テスト | `test_voltage_filter.py` 拡張, `test_knowledge_search_filter.py` (新規), `test_chat_schema.py` (新規) |

### コードレビュー指摘と対応

各タスクで Spec Review + Code Quality Review の2段階レビューを実施。
- `filter_by_voltage_type` の「高圧・特別高圧」バリアント未対応 → 修正
- `readCookie` の `split("=")[1]` が `=` を含む値で壊れる → `substring(indexOf("=") + 1)` に修正
- subagent がスコープ外のコミットを追加（zendesk draft, inquiry page 等）→ すべてリバート

## 決定事項

- フィルタ方式: ハード除外（タグ付き不一致 → 除外）+ null パススルー（タグなし → 通過）
- area も voltage_type も post-filter で統一（DB フィルタだと untagged チャンクが除外されるため）
- Cookie 永続化: `dgp_voltage_type`, `dgp_area`（encodeURIComponent で日本語対応、365日有効期限）
- ainvoke() パスへの対応は現時点では不要（未使用）
- multi_agent の qa_search への対応はスコープ外

## 技術的ポイント

- LangGraph の `create_react_agent` は `RunnableConfig` を自動的にツールに伝播する。`config: RunnableConfig` パラメータを追加するだけで metadata にアクセス可能
- ScoredChunk → dict 変換が必要（filter 関数が `result.get("metadata", {})` を期待するため）
- トレース記録はフィルタ前のデータを使用（フィルタ効果分析に必要）
- Widget は Shadow DOM 内で動作するため、FilterSelector のスタイルはすべてインラインで記述

## 次にやること

- `feat/tier2-port-and-inquiry-form` へのマージまたは PR 作成
- E2E 手動検証（Docker 環境でのフィルタ動作確認）
- タスク 013 のステータス更新
