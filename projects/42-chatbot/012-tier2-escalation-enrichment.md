---
title: "Tier 2: Zendesk エスカレーション強化（カテゴリタグ・構造化サマリ）"
date: 2026-03-22
project: 42-chatbot
tags: [tier2, escalation, zendesk, structured-summary]
---

## 概要

Zendeskエスカレーション機能にカテゴリタグ自動検出と構造化サマリを追加。チケットに業務タグを付与し、問い合わせフォームに推奨入力項目の下書きを自動生成する仕組みを構築。

## 作業内容

### ブランチ

`feat/tier2-escalation-enrichment`（`origin/zendesk-contact-form` ベース）

### 設計

- brainstorming → spec → plan の3段階で設計
- 設計ドキュメント: `docs/superpowers/specs/2026-03-22-tier2-escalation-enrichment-design.md`
- 実装計画: `docs/superpowers/plans/2026-03-22-tier2-escalation-enrichment.md`

### 実装（7タスク、全完了）

1. **TagDefinition・StructuredSummary データモデル追加** (`src/app/services/summary.py`)
   - `TagDefinition` frozen dataclass（slug, label, description, fields）
   - `TAG_DEFINITIONS` 8カテゴリ（billing×2, system×1, ops×1, contract×3, other）
   - ASCIIスラグ（例: `billing__payment_method_change`）でZendesk API互換性確保

2. **OrchestratorState に business_tag フィールド追加** (`src/app/graph/state.py`)

3. **構造化サマリ生成** (`src/app/services/summary.py`)
   - `generate_structured_summary()`: 単一LLMコールでカテゴリ検出 + 推奨項目抽出 + サマリ生成
   - `_parse_structured_output()`: `TAG: <slug>` 行パース、fallback to `"other"`
   - 既存の `generate_conversation_summary()` は破壊変更なし

4. **エスカレーションフローにタグ統合** (`src/app/graph/nodes/escalation.py`)
   - `_check_business_relevance_and_tag()`: 業務関連性判定 + タグ返却（`tuple[bool, str | None]`）
   - `evaluate_response`: business_tag を state に設定
   - `create_zendesk_ticket_node`: チケットタグに business_tag 追加

5. **問い合わせフォームにタグ透過** (`src/app/web/routes.py`, テンプレート)
   - hidden field で business_tag をフォーム経由で渡す
   - `submit_contact_form` でバリデーション後 Zendesk タグに追加

6. **手続き案内ナレッジチャンク** (`src/app/services/agent/knowledge/chunks/general/faq_手続き案内.yaml`)
   - 担当者対応が必要な7手続きのQ&Aチャンク
   - 口座振替依頼書、支払方法変更、DGMアカウント、名義変更、容量変更、解約、メール再送

7. **全体統合検証**: 21テスト全パス

### コミット履歴

```
c7862db feat: add staff-required procedure guidance knowledge chunks
fa87241 feat: pass business_tag through contact form to Zendesk ticket
a1e608d feat: integrate business tag detection into escalation flow
04e4490 feat: add generate_structured_summary() with category tag detection
743c76e feat: add business_tag field to OrchestratorState
cd91e35 feat: add TagDefinition, StructuredSummary, TAG_DEFINITIONS to summary.py
```

### テスト

- `tests/services/test_summary_structured.py` — 12テスト（データモデル、パーサー、LLM統合）
- `tests/services/agent/multi_agent/test_escalation_tag.py` — 5テスト（タグ検出、エスカレーション）
- `tests/web/test_contact_form_tag.py` — 4テスト（フォームタグ透過）

## 設計判断

- **フォーム項目**: 動的フォームフィールドではなく、サマリ下書きにセクション追加する方式を採用（ユーザーが自由に編集可能）
- **タグ命名**: ZendeskのASCII制約に合わせてスラグ形式、日本語ラベルは別フィールド
- **後方互換**: 既存関数は変更せず、新規関数を追加（`generate_structured_summary` は `generate_conversation_summary` と共存）
- **Tier 3 統合**: A-1（契約容量変更）とA-4（解約・切替）をエスカレーションカテゴリとして統合（シミュレーション機能ではなくZendeskチケット発行で対応）

## ステータス

実装完了、PR未作成。`zendesk-contact-form` ブランチへのマージ待ち。
