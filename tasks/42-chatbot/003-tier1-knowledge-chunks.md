---
title: "Tier 1: 制度説明ナレッジチャンク追加"
date: 2026-03-22
project: 42-chatbot
status: in_progress
progress: 1/4
priority: high
tags: [rag, knowledge, zendesk, cs-support]
---

## 概要

Zendesk問い合わせ分析（339件）で特定した7トピックについて、Q&A形式のナレッジチャンクを新規追加し、RAGの回答品質を向上させる。対象は「制度の仕組み・計算方法」に関する質問群（44件/339件 = 13%）。開発コストほぼゼロで全体の13%をカバーできる最もROIの高い施策。

## 決定事項

| 項目 | 決定 |
|------|------|
| スコープ | Tier 1（制度説明）の7トピックを1タスクで一括実装 |
| 情報ソース | 既存約款 + CSチーム知見のハイブリッド |
| チャンク形式 | Q&A形式（既存 `qa_list.yaml` に準拠） |
| ファイル構成 | トピックごとに独立YAMLファイル（7ファイル） |
| テスト方法 | 目視レビュー（AI評価スクリプトは使わない） |
| 並列実行 | 7トピックを並列サブエージェントで作成 |

## タスク

- [x] ST-1: 7つのYAMLナレッジチャンクを作成
- [ ] ST-2: テストCSVを作成
- [ ] ST-3: seed_knowledge.py で取り込み確認
- [ ] ST-4: 目視レビュー + PR作成

---

### ST-1: 7つのYAMLナレッジチャンクを作成

**意図**: Zendeskで頻出する制度関連の質問に対し、RAGが正確に回答できるようナレッジベースを拡充する。

**配置先**: `src/app/services/agent/knowledge/chunks/general/`

**ブランチ**: `feature/tier1-knowledge-chunks`（mainから作成）

| ファイル名 | トピック | Zendesk件数 | 想定チャンク数 |
|-----------|---------|------------|-------------|
| `faq_再エネ賦課金.yaml` | 再エネ賦課金の仕組み・計算方法 | 13 | 5-7 |
| `faq_容量拠出負担金.yaml` | 容量拠出負担金の説明・算定・解約後タイムライン | 10 | 5-7 |
| `faq_GPA精算.yaml` | GPA精算書・FIPプレミアムの仕組み | 8 | 4-5 |
| `faq_RE100環境証書.yaml` | RE100・非化石証書の説明 | 5 | 3-4 |
| `faq_先物取引EEX.yaml` | 先物取引・EEXの仕組み | 3 | 2-3 |
| `faq_政府補助金.yaml` | 政府補助金の適用ルール | 3 | 2-3 |
| `faq_託送料金.yaml` | 託送料金の概要 | 2 | 2-3 |

合計: 約25-32チャンク

**YAMLフォーマット**（既存 `qa_list.yaml` に準拠）:

```yaml
source: zendesk_inquiry_analysis
generated_at: '2026-03-22T00:00:00+00:00'
chunk_count: N
chunks:
  - id: 1
    metadata:
      doc_type: Q&A
      category: 請求
      source: zendesk_inquiry_analysis
    content: |
      【Q&A】【請求】
      Q: 再エネ賦課金とは何ですか？どのように計算されますか？
      A: 再エネ賦課金（再生可能エネルギー発電促進賦課金）は...
```

**フォーマットルール**:
- `source`: すべて `zendesk_inquiry_analysis` に統一
- `doc_type`: `Q&A`
- `category`: トピックに応じて `請求`, `契約`, `制度` 等
- `content`: 既存 qa_list.yaml と同じ `【Q&A】【カテゴリ】` プレフィックス形式
- Q にはZendeskの実質問（または集約した代表質問）を使用
- A には約款の正式な定義 + CSチームの実務知見を組み合わせて記述
- content は YAML block scalar (`|`) を使用（可読性重視）
- ファイルは UTF-8 で保存

**参照すべきデータ**:
- `analysis/rag_evaluation - zendesk_inquiry_useful_questions.csv` — Zendesk実質問
- `src/app/services/agent/knowledge/chunks/約款/` — 約款の正式な定義
- `src/app/services/agent/knowledge/chunks/general/cs_team_knowledge.yaml` — CS現場知見

**並列実行**: 7トピックは独立しているため、サブエージェントに各1トピックを割り振って並列作成可能。

---

### ST-2: テストCSVを作成

**意図**: ナレッジ追加後の回答品質を目視レビューで確認するための質問集。

**配置先**: `analysis/eval_tests/tier1_制度説明.csv`

```csv
id,topic,question,expected_points
T-001,再エネ賦課金,電力料単価の計算方法を教えてください,"計算式の構成要素を列挙;再エネ賦課金の位置づけ"
T-002,容量拠出負担金,電力停止済みなのに請求されている理由,"容量拠出負担金の仕組み;対象期間の説明"
...
```

- 各トピックから代表的な質問を2-3件抽出（計15-20件）
- `expected_points`: 回答に含まれるべきポイントをセミコロン区切り
- Zendeskの実質問をそのまま使用

---

### ST-3: seed_knowledge.py で取り込み確認

**意図**: 作成したYAMLファイルがパイプラインで正しく取り込めることを確認する。

```bash
docker compose exec app uv run python scripts/seed_knowledge.py --force
```

注: `--force` は全チャンクを削除して再シードする（新規ファイルのみの差分投入ではない）。

**確認ポイント**:
- エラーなく完了すること
- 新規チャンクが DB に登録されていること

---

### ST-4: 目視レビュー + PR作成

**意図**: テストCSVの質問をチャットボットに投げ、回答品質を目視で確認する。

**手順**:
1. テストCSVの質問をチャットボットに投入
2. 回答が `expected_points` を満たしているか確認
3. 問題があればチャンク内容を修正
4. PRを作成

---

## 依存関係

- ST-1 → ST-2（テストCSVはチャンク内容を踏まえて作成）
- ST-1 + ST-2 → ST-3（取り込み確認）
- ST-3 → ST-4（目視レビュー）

## スコープ外

- AI評価スクリプトの実行
- 既存チャンクの修正
- Tier 2（手続きFAQ）の作業
- 新しい metadata フィールドの追加
