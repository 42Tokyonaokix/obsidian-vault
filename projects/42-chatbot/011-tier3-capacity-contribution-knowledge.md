---
title: "Tier 3: 容量拠出金制度ナレッジチャンク作成 & A-3 設計整理"
date: 2026-03-22
project: 42-chatbot
tags: [tier3, knowledge-chunks, capacity-market, rag, fact-check]
---

## 概要

A-3（容量拠出負担金シミュレーション）の ST-1 として、OCCTO公式資料ベースの容量拠出金制度の構造的説明ナレッジ（6チャンク）を作成。ファクトチェックで約定価格の誤り（Net CONE とエリアプライスの混同）を発見・修正。

## 作業内容

### 1. Zendesk 問い合わせ分析

`analysis/zendesk_masked-3_filtered.json` を分析し、容量拠出関連 34 件の内訳を特定:
- 解約後の請求（20件・59%）— 最多パターン
- 値上がり・来年度単価（7件・21%）
- 金額・計算（4件・12%）
- 制度説明・請求タイミング（3件・9%）

### 2. guide_容量拠出金制度.yaml 作成（6チャンク）

`src/app/services/agent/knowledge/chunks/general/guide_容量拠出金制度.yaml`:

| # | 内容 | source |
|---|------|--------|
| 1 | 制度概要（法的根拠・目的・負担者） | occto_official |
| 2 | 算定方法（4ステップ） | occto_official |
| 3 | メインオークション約定価格の推移（2024〜2027年度、エリア別） | occto_official |
| 4 | 請求スケジュールと年次精算 | occto_official |
| 5 | 解約後の請求が続く理由（3つの理由 + 最終請求時期目安） | occto_official |
| 6 | DGにおける転嫁方法（算定式・変動要因） | dgm_terms |

### 3. ファクトチェック & 修正

別エージェントによるレビューで以下を発見・修正:

- **約定価格の混同**: 初版で Net CONE（指標価格: 9,425 / 9,557 / 5,601 円/kW）をエリアプライスとして記載していた。正しくはエリア別の約定価格（例: 2025年度 北海道・九州 5,242 / その他 3,495 円/kW）
- **マルチプライス方式**: 2025年度以降はエリアごとに異なる約定価格が設定される制度変更を反映
- **source メタデータ**: チャンク6の source を `occto_official` → `dgm_terms` に修正

### 4. A-3 タスクファイル更新

`tasks/42-chatbot/009-a3-capacity-contribution-simulator.md` を更新:
- Zendesk分析結果を追記
- ST-1 完了マーク
- 設計判断（専用ツール不要、既存ツール + プロンプト拡充で対応）を明記

### 5. A-2/A-3 の設計方針すり合わせ

- **A-3**: 専用計算ツールは作らない。既存 data_agent ツール（`get_demand_contract`, `get_endpoint_monthly_charge`）+ `knowledge_data.md` のルール記載で LLM が回答生成
- **A-2**: `utilities.py` に営業日計算（jpholiday）を追加、`billing_schedule` ツール新設、`knowledge_data.md` に請求サイクル詳細を追記

## 決定事項

- 既存 `faq_容量拠出負担金.yaml`（7チャンク、DG固有Q&A）と新規 `guide_容量拠出金制度.yaml`（6チャンク、制度解説）は補完関係
- A-1, A-4 は Tier 2 設計と並行のため今回スキップ

## 次にやること

- A-3 ST-2: `knowledge_data.md` の容量拠出負担金セクション拡充（約定価格推移、解約後ルール、対象期間マッピング）
- A-3 ST-3/ST-4: `seed_knowledge.py` 実行 + RAG検索精度確認 + 統合テスト
- A-2: 本格実装（営業日カレンダー、請求スケジュールツール）
