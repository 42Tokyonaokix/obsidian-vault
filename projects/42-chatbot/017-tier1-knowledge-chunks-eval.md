---
title: "Tier 1: 制度説明ナレッジチャンク評価・取り込み完了"
date: 2026-03-22
project: 42-chatbot
tags: [rag, knowledge, evaluation, seed]
---

## 概要

ST-1で作成済みの7つのFAQ YAMLチャンク（+ 制度解説1ファイル）に対し、テストCSV作成・seed取り込み・目視レビューを実施しST-2〜ST-4を完了した。

## 作業内容

### ST-2: テストCSV作成
- `analysis/eval_tests/tier1_制度説明.csv` に12件のテスト質問を作成
- 8ファイル×1〜2件の代表的質問を選定
- カラム: `id, category, question, expected_answer`（run_rag_evaluation.py の EvaluationRow 互換）

### ST-3: seed_knowledge.py で取り込み確認
- `refactor/knowledge-chunks-reorganize` ブランチ上で作業
- seed_knowledge.py に2つの修正が必要だった:
  1. **YAMLパースエラーハンドリング**: 3つの約款YAML（供給条件説明書_低圧_RE100, 重要事項説明書_低圧, 電気需給約款_低圧_再エネメニューあり）にパースエラーあり → try/except でスキップ
  2. **chunk_index の型変換**: 一部チャンクのIDが文字列（例: `dgm_menu_03_eu`）で整数カラムに入らない → `int()` 変換 + fallback
  3. **コンテナ内パス不整合**: `Path(__file__).resolve().parent.parent` が `/` を返す → monkey-patch で `/app/src/app/services/agent/knowledge` に修正
- 結果: 38 YAML + 6 MD = 41 SourceDocuments, 3450 Chunks を正常にシード

### ST-4: 目視レビュー
- `run_rag_eval.py`（HTTP方式）で全12件を評価
- 全件エラーなし、平均レスポンス10.5秒
- 11/12件（92%）が期待ポイントを満たす回答
- T-003（電力停止後の請求理由）のみDGM APIエラーの影響で一般論に留まる（RAGチャンク品質の問題ではない）

## 決定事項

| 項目 | 決定 |
|------|------|
| ブランチ | `refactor/knowledge-chunks-reorganize` 上で作業（ST-1チャンクが存在するため） |
| テスト件数 | 12件（当初17-19件の計画を絞り込み） |
| 合否基準 | expected_points の80%以上を充足 → 92%で PASS |
| 約款YAMLパースエラー | スキップで対応（Tier 1スコープ外） |

## 次にやること

- コミット・PR作成（refactor/knowledge-chunks-reorganize → main）
- 約款YAML 3ファイルのパースエラー修正（別タスク）
