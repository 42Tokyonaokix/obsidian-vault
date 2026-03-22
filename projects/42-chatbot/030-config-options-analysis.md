---
title: "設定オプション過多問題の分析"
date: 2026-03-22
project: 42-chatbot
tags: [config, analysis, refactoring]
---

## 概要

42-chatbotの環境変数ベース設定オプション（100個以上）を棚卸しし、「オプション過多」問題の構造を分析した。

## 作業内容

### オプション総数

config.pyのPydantic Settingsクラスから全環境変数を抽出。計100個以上の設定パラメータが存在。

### カテゴリ別内訳

| カテゴリ | 個数 | 代表パラメータ |
|----------|------|---------------|
| DB/Redis/Auth/インフラ | ~20 | DB_HOST, REDIS_PORT, AUTH_JWKS_URL |
| LLM/Embedding | ~6 | LLM_MODEL_NAME, LLM_TEMPERATURE |
| Retrieval基本 | ~5 | RETRIEVAL_STRATEGY, RETRIEVAL_TOP_K |
| Advanced RAG | ~15 | MULTI_QUERY_ENABLED, RERANKING_ENABLED等6フラグ + 各種閾値 |
| Agent | ~8 | AGENT_ARCHITECTURE, RECURSION_LIMIT |
| RAPTOR | ~5 | UMAP_N_COMPONENTS, HDBSCAN_MIN_CLUSTER_SIZE |
| VKG | ~3 | VKG_ENTRY_POINTS, VKG_MAX_HOPS |
| Hybrid | ~3 | HYBRID_WEIGHT_FLAT/RAPTOR/VKG |
| DGM API | ~10 | タイムアウト、サーキットブレーカー、リトライ |
| Zendesk | ~6 | ZENDESK_SUBDOMAIN, リトライ設定 |
| Guardrail/Cache/Stream/Trace | ~10 | 各種TTL、有効フラグ |
| Celery | ~4 | ブローカー、ワーカー設定 |
| Classifier/Multi-Agent | ~6 | CLASSIFIER_MODEL_NAME, タスクリトライ |

### 主要な「選択式」オプション（組み合わせ爆発の原因）

1. **検索戦略** (`RETRIEVAL_STRATEGY`): flat_vector / raptor / vkg / hybrid / advanced の5択
2. **エージェント構成** (`AGENT_ARCHITECTURE`): single_react / multi_agent の2択
3. **Advanced RAGフィーチャーフラグ**: 6個のON/OFFスイッチ
4. **モデル選択が4箇所に分散**: LLM本体、クエリ拡張、Proposition抽出、分類器

### 問題の構造

1. **検索パイプラインの組み合わせ爆発**: 5戦略 × 6フラグ × 多数の閾値。advancedだけで15+設定
2. **モデル選択の分散**: 4箇所で別々にモデル指定可能
3. **戦略間の設定重複**: flat_vectorの重み設定とadvancedのRRF設定が別系統で共存
4. **ランタイム変更不可**: 全て環境変数のためデプロイ時にしか変更できない
5. **未使用戦略の残存**: raptor/vkg/hybridは実運用で使われていない可能性

## 決定事項

- まだなし。分析フェーズ。

## 次にやること

- どの戦略を残すか判断（不要戦略の削除検討）
- プリセット化や設定の階層化の検討
- Advanced RAGの設定をシンプルにする方法の検討
