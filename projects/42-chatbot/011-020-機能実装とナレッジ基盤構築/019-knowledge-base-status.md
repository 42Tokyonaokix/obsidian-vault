---
title: "ナレッジベース現状マップ（2026-03-22時点）"
date: 2026-03-22
project: 42-chatbot
tags: [knowledge-base, rag, chunks, status]
---

## 概要

42-chatbot のナレッジベース（YAML チャンク + Markdown システム文書）の現状を棚卸し。全 38 YAML ファイル + 6 Markdown 文書の内訳・Zendesk Tier との対応・カバレッジギャップを整理。

## 作業内容

### 1. ディレクトリ構造

```
src/app/services/agent/knowledge/
├── chunks/
│   ├── general/          (12 files)
│   ├── DGM操作/          (4 files)
│   ├── 地域託送約款/      (9 files)
│   └── 約款/             (13 files)
├── DGM_BY_MENU.md
├── DGM_QUESTIONS.md
├── DGM_SCREENS.md
├── DGM_SCREENS_DATA_DETAILS.md
├── DGM_SCREENS_ORIGINAL.md
└── PLATFORM_MANUAL.md
```

### 2. YAML チャンク詳細

#### general/ (12 files, 174 chunks)

| ファイル名 | chunks | doc_type | 追加時期 |
|-----------|--------|----------|---------|
| qa_list.yaml | 92 | Q&A | 既存 (03-03) |
| cs_team_knowledge.yaml | 24 | CSチーム現場知見 | 既存 (03-03) |
| DGPナレッジベース.yaml | 16 | ナレッジベース | 既存 |
| formula_templates.yaml | 7 | 計算テンプレート | 既存 |
| faq_容量拠出負担金.yaml | 7 | Q&A (請求) | Tier 1 (03-22) |
| guide_容量拠出金制度.yaml | 6 | 制度解説 | Tier 1/3 (03-22) |
| faq_再エネ賦課金.yaml | 6 | Q&A (制度) | Tier 1 (03-22) |
| faq_GPA精算.yaml | 5 | Q&A (精算) | Tier 1 (03-22) |
| faq_RE100環境証書.yaml | 4 | Q&A (RE100) | Tier 1 (03-22) |
| faq_政府補助金.yaml | 3 | Q&A (制度) | Tier 1 (03-22) |
| faq_託送料金.yaml | 3 | Q&A (託送) | Tier 1 (03-22) |
| faq_先物取引EEX.yaml | 3 | Q&A (取引) | Tier 1 (03-22) |

- 既存 (qa_list + cs_team + DGP + formula): **139 chunks**
- Tier 1 新規 (7 FAQ + 制度解説): **37 chunks**
- 評価結果: 12件テスト質問で 92% PASS (Note 017)

#### DGM操作/ (4 files, 156 chunks)

| ファイル名 | chunks | doc_type |
|-----------|--------|----------|
| system_manual_qa.yaml | 100 | Q&A |
| システムマニュアル_202511.yaml | 28 | システムマニュアル |
| dgm_menu.yaml | 18 | DGMメニュー |
| procedures.yaml | 10 | 手順ガイド |

- dgm_menu.yaml は chunk_count フィールド未設定（id 数でカウント）
- procedures.yaml の 10 chunks は Tier 2 escalation enrichment (Note 012) で追加

#### 地域託送約款/ (9 files, 2,620 chunks)

| ファイル名 | chunks |
|-----------|--------|
| 北海道電力ネットワーク_託送供給等約款.yaml | 390 |
| 東北電力ネットワーク_託送供給等約款.yaml | 382 |
| 北陸電力送配電_託送供給等約款.yaml | 362 |
| 中国電力ネットワーク_託送供給等約款.yaml | 324 |
| 関西電力送配電_託送供給等約款.yaml | 300 |
| 九州電力送配電_託送供給等約款.yaml | 222 |
| 四国電力送配電_託送供給等約款.yaml | 218 |
| 東京電力送配電_託送供給等約款.yaml | 218 |
| 中部電力パワーグリッド_託送供給等約款.yaml | 204 |

- 全チャンクの **73%** (2,620/3,564) を占める
- 全ファイルに `metadata.area` 付与済み → RAG metadata filter 対象
- **沖縄電力は未収録** (9/10 地域)

#### 約款/ (13 files, 614 chunks)

| ファイル名 | chunks | voltage_type |
|-----------|--------|-------------|
| Digital_Grid_Platform_利用規約.yaml | 131 | — |
| 電気需給約款_低圧_RE0.yaml | 117 | 低圧 |
| 電気需給約款_低圧_再エネメニューあり.yaml | 109 | 低圧 |
| 電気需給約款_高圧特別高圧_再エネメニューあり.yaml | 86 | 高圧特別高圧 |
| 電気需給約款_高圧特別高圧_RE0.yaml | 86 | 高圧特別高圧 |
| 供給条件説明書_高圧.yaml | 20 | 高圧 |
| 供給条件説明書_高圧_RE100.yaml | 18 | 高圧 |
| 重要事項説明書_高圧_RE100.yaml | 17 | 高圧 |
| 供給条件説明書_低圧_RE100.yaml | 8 | 低圧 |
| 重要事項説明書_低圧_RE100.yaml | 8 | 低圧 |
| 重要事項説明書_低圧.yaml | 7 | 低圧 |
| 重要事項説明書_高圧.yaml | 5 | 高圧 |
| 供給条件説明書_低圧.yaml | 4 | 低圧 |

- voltage_type メタデータ付与済み → RAG metadata filter 対象
- 電気需給約款_低圧_再エネメニューあり (109), 重要事項説明書_低圧 (7), 供給条件説明書_低圧_RE100 (8) の 3ファイルに YAMLパースエラーあり（seed時にスキップ対応、Note 017）

#### Markdown システム文書 (6 files)

| ファイル名 | 内容 |
|-----------|------|
| DGM_BY_MENU.md | DGMメニュー構造 |
| DGM_QUESTIONS.md | DGM Q&A |
| DGM_SCREENS.md | DGM画面構成 |
| DGM_SCREENS_DATA_DETAILS.md | DGM画面データ詳細 |
| DGM_SCREENS_ORIGINAL.md | DGM画面（元データ） |
| PLATFORM_MANUAL.md | プラットフォームマニュアル |

seed_knowledge.py で各ファイル 1 SourceDocument として取り込み。

### 3. 合計

| カテゴリ | ファイル数 | チャンク数 | 割合 |
|---------|----------|----------|------|
| general/ | 12 | 174 | 4.9% |
| DGM操作/ | 4 | 156 | 4.4% |
| 地域託送約款/ | 9 | 2,620 | 73.5% |
| 約款/ | 13 | 614 | 17.2% |
| **YAML 合計** | **38** | **3,564** | |
| Markdown | 6 | 6 | — |
| **総計** | **44** | **3,570** | |

Note 017 の seed 結果は 41 SourceDocuments / 3,450 Chunks（YAML パースエラー3件スキップ + 一部 chunk_count 差異による）。

### 4. Seeding メカニズム

- **スクリプト**: `scripts/seed_knowledge.py`
- **実行**: `docker compose exec app uv run python scripts/seed_knowledge.py [--force] [--dry-run]`
- **処理**: YAML rglob + MD glob → SourceDocument + Chunk 作成 → embedding batch (50件単位) → DB bulk insert
- **ステータス**: 全チャンク APPROVED
- **冪等性**: `--force` なしで既存スキップ

### 5. Zendesk Tier 対応マップ

339件の Zendesk 問い合わせ分析（Note 006）に基づく対応状況:

| Tier | 説明 | 件数 | 対応状況 | 対応ナレッジ |
|------|------|------|---------|------------|
| 1 | RAGナレッジ拡充で即対応 | 44 (13%) | **完了** | 7 FAQ + guide_容量拠出金制度 (37 chunks) |
| 2 | 手続きFAQ + エスカレーション改善 | 42 (12%) | **設計済み** | procedures.yaml (10 chunks) + escalation enrichment spec |
| 3 | ツール開発が必要 (A-1~A-4) | 93 (27%) | **一部** | guide_容量拠出金制度 (A-3関連) のみ |
| 4 | エスカレーション最適化 | 133 (39%) | **設計済み** | business_tag + structured_summary 実装済み |
| 5 | 既存RAGで部分カバー | ~27 (8%) | 部分対応 | qa_list (92), cs_team_knowledge (24) |

### 6. カバレッジギャップ

| 領域 | 現状 | 不足 |
|------|------|------|
| 約款「読み解き」FAQ | 条文は 614 chunks あるが Q&A 形式なし | 契約書・クラウドサイン系 (Tier 2/4: 26件) 未対応 |
| DGM トラブルシューティング | system_manual_qa (100), procedures (10) | ID/PW 発行手順、ミエルカ関連が不足 |
| 口座振替・支払い | なし | 口座振替依頼書 (10件), 支払方法変更 (10件) 未対応 |
| インバランス・ネガワット | なし | Tier 4: 23件未対応 |
| 代理店報酬通知書 | なし | Tier 4: 19件未対応 |
| 沖縄電力 託送約款 | なし | 9/10 地域のみ収録 |

### 7. メタデータフィールド

チャンクメタデータで使用されているフィールド:

| フィールド | 用途 | 対象 |
|-----------|------|------|
| doc_type | Q&A, 制度解説, 手順ガイド等 | 全 YAML |
| category | 請求, 契約変更, 手続き等 | 一部 YAML |
| source | zendesk_inquiry_analysis, manual_procedures 等 | 一部 YAML |
| voltage_type | 低圧, 高圧, 高圧特別高圧 | 約款/ のみ |
| area | 電力会社名 | 地域託送約款/ のみ |
| filename, page | PDF由来情報 | PDF抽出チャンクのみ |

### 8. RAG Metadata Filtering 対応状況

- **voltage_type filter**: 実装済み (task/002 ブランチ)。Cookie UI で選択、ContextVar でパイプラインに伝播、ハード除外
- **area filter**: 実装済み (task/002 ブランチ)。同上
- **null passthrough**: メタデータ未設定チャンクはフィルタを通過（general/ 等に影響なし）
- **テスト**: 23件全パス

## 決定事項

- Tier 1 ナレッジチャンクは完了 (7 FAQ + 制度解説)、92% PASS で品質確認済み
- 地域託送約款が全チャンクの 73% を占めるため metadata filter の効果が最も高い
- YAML パースエラー 3件は別タスクで修正予定（seed 時にスキップで回避中）
- dgm_menu.yaml の chunk_count フィールド未設定は軽微（動作に影響なし）

## 次にやること

- Tier 2 手続きFAQ チャンク追加（口座振替, ID/PW, 請求書操作, 名義変更）
- DGM トラブルシューティングチャンク補強
- 約款「読み解き」FAQ の作成検討
- YAML パースエラー 3件の修正
- 沖縄電力 託送約款追加の要否判断
