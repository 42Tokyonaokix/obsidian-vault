---
title: "42-chatbot 実装タイムライン（2026-02〜03）"
date: 2026-03-22
project: 42-chatbot
tags: [timeline, summary, implementation]
---

## 概要

42-chatbot の実装履歴を時系列で整理したサマリーノート。既存のプロジェクトノート 001-017 は個別セッションの記録として残し、本ノートを全体タイムラインの一次参照とする。

## 作業内容

### Phase 0: 初期構築 (2026-02-16 ~ 02-27)

開発者: Naoki + Ali（チームメンバー）。main ブランチ上で基盤構築。

| 日付 | 内容 | 補足 |
|------|------|------|
| 02-16 | リポジトリ初期化、RAG実装、mock-api-server、PDF loader | 初コミット |
| 02-17 | 託送料金 API skill 追加 | |
| 02-19~20 | mock-backend-api、multi-agent (web/calc)、Zendesk ticket node、container functions | PR #1, #2, #3 |
| 02-22~23 | セッション管理UI、request validation、rate limiting、architecture.drawio | |
| 02-25 | monitoring stack (Grafana, PostgreSQL exporter)、user/company DB追加 | PR #5 (Ali) |
| 02-26~27 | observability dashboards、PDF chunking strategy | |

### Phase 1: cs_support ブランチ開発 (2026-03-01 ~ 03-21)

開発者: Naoki。`Naoki/cs_support` ブランチで機能開発。**main に未マージ（23コミット）。**

| 日付 | 内容 |
|------|------|
| 03-01 | agentic chunking 修正、markdown chunking 一本化 |
| 03-02~03 | YAML chunk 分割、expand_section_context tool |
| 03-04 | DenseX, multi-query, sub-query, memory, ReAct agent (PR #7) |
| 03-07 | triple hybrid search strategy |
| 03-09 | mock_server 計算ロジック・契約DB追加 |
| 03-11~12 | prompt追加、system_manual_knowledge |
| 03-15 | Classifier gpt-4o化、mergeロジック強化、ナレッジ拡充 |
| 03-17 | **Action Agent (Phase 3)**: 5 self-service tools, audit log, CRUD, system prompt |
| 03-21 | area filter、action agent オーケストレーター統合、プロンプト整理、チャンク階層化 |

**cs_support の主要未マージ機能:**
- Action Agent（5 self-service tools: 住所変更、認証情報リセット、請求書再発行、データエクスポート、社名変更）
- エリアフィルタ（60+ 正規表現パターン）
- プロンプトサブディレクトリ構造
- 約款ドキュメント修正

### Phase 2: main v1.0 構築 (2026-03-04 ~ 03-20)

開発者: Claude Code（自動生成）。main ブランチ上で Auth/Admin/Docs 等を Phase 1-20 として段階的に構築。

| Phase | 日付 | 内容 |
|-------|------|------|
| 1-10 | 03-04 | Auth infrastructure (JWT/RBAC), dashboard scaffold, admin API, permissions, collections |
| 15 | 03-19 | mock server upgrade (6 billing endpoints), billing tools (endpoint_monthly_charge, charge_breakdown), document_lookup |
| 16 | 03-19 | guardrails (coherence/scope validators), evaluation framework (seed CSV, LLM-judge scripts) |
| 11 | 03-19 | README, SECURITY.md, docs/ (bilingual architecture, api-reference, deployment, admin-manual, developer-guide) |
| 20 | 03-20 | tech debt cleanup, SSE callbacks, Nyquist validation backfill → **v1.0 milestone** |

### Phase 3: Naoki 改善作業 (2026-03-20 ~ 03-22)

開発者: Naoki + Claude Code。Obsidian vault と連動した改善サイクル。

| 日付 | 内容 | Note # | ブランチ |
|------|------|--------|---------|
| 03-20 | 全リポジトリコードレビュー | 001, 002 | — |
| 03-21 | cs_support vs main ブランチ差分分析 | 003 | — |
| 03-21 | Docker/widget cross-origin fix | 004 | fix/docker-and-widget-cross-origin (PR #30) |
| 03-21 | knowledge chunks 再編成 (flat → 4 subdirs) | 005 | refactor/knowledge-chunks-reorganize (PR #33) |
| 03-21 | Zendesk 339件分析 → 5-Tier分類 | 006 | — |
| 03-21 | JWT token injection fix (config.metadata pattern) | 007 | refactor/knowledge-chunks-reorganize |
| 03-22 | Multi-agent JWT 設計分析 | 008 | — |
| 03-22 | Multi-agent JWT config.metadata 移行 (7 tools, 203 tests) | 009 | refactor/knowledge-chunks-reorganize |
| 03-22 | Tier 2 operation classification 設計 | — | refactor/knowledge-chunks-reorganize |
| 03-22 | Tier 1 knowledge chunk 設計 + 追加 (7 FAQ + guide) | 011 | refactor/knowledge-chunks-reorganize |
| 03-22 | Tier 2 escalation enrichment 設計 + 実装 | 012 | task/002-rag-metadata-filtering |
| 03-22 | RAG metadata filtering (ContextVar, Cookie UI, 23 tests) | 014 | task/002-rag-metadata-filtering |
| 03-22 | 3機能群 段階的push (16 commits) | 015 | task/002-rag-metadata-filtering |
| 03-22 | フロントエンド UI 接続状況調査 | 016 | — |
| 03-22 | Tier 1 評価 (12 test questions, 3450 chunks seed, 92% PASS) | 017 | refactor/knowledge-chunks-reorganize |

## 決定事項

### 技術的決定

| 項目 | 計画 | 実際の採用 | 理由 |
|------|------|-----------|------|
| JWT伝播方式 | InjectedToolArg パターン (Task 001) | config.metadata パターン | LangGraph の RunnableConfig 自動伝播を活用、LLM に credentials が露出しない |
| RAG metadata filtering | DGM API contract lookup → SQL filter (Task 002 ST-1~6) | ContextVar + Cookie UI → post-filter | DGM API が既に voltage_type/power_area を返す。UI 選択ベースの方がシンプル |
| Knowledge chunk 構造 | フラット配置 | カテゴリ別4サブディレクトリ | general/DGM操作/地域託送約款/約款 の意味的分類で管理性向上 |

### ブランチ状態 (2026-03-22 時点)

| ブランチ | 状態 | 備考 |
|---------|------|------|
| main | v1.0 完了 (Phase 20) | Auth, Admin, Docs, Billing tools |
| Naoki/cs_support | 23 commits 未マージ | Action Agent, area filter, prompt整理 |
| refactor/knowledge-chunks-reorganize | アクティブ | JWT fix, knowledge chunks, Tier 1 eval |
| task/002-rag-metadata-filtering | stash あり | Tier 2 escalation, RAG filter, 3機能群 push 済 |

### Obsidian タスクとの乖離

| タスク | Vault ステータス | 実際の状態 | 乖離の内容 |
|--------|----------------|-----------|-----------|
| 001 JWT fix | todo (0/6) | **完了** | config.metadata方式で実装済み。InjectedToolArgは不採用 |
| 002 RAG metadata filtering | in_progress (0/7) | **完了** | Cookie UI + ContextVar方式で実装済み。当初のST-1~7とはアプローチが異なる |
| 003 Tier 1 knowledge chunks | in_progress (1/4) | **完了** | ST-1~ST-4全完了。12件テスト、3450 chunks seed、92% PASS |
| 004 Multi-agent JWT | done (5/5) | done | 一致 |
| 005 Tier 2 escalation | done (4/4) | **設計のみ完了** | 実装は task/002 ブランチの一部コミットのみ |

## 次にやること

- cs_support の未マージ機能 (action agent, area filter) の main 統合判断
- refactor/knowledge-chunks-reorganize → main のPR作成
- Tier 2 手続きFAQ の実装
- A-2 (請求スケジュール照会) の着手
- Vault タスクファイルのステータス更新
