---
title: "ディレクトリ構成・機能役割分担・処理フロー図"
date: 2026-03-22
project: 42-chatbot
tags: [architecture, documentation]
---

## 概要

42-chatbot のディレクトリ構成ごとの機能役割分担と、ユーザーリクエストの処理フローを図示・整理した。

## ディレクトリ構成と機能役割

```
42-chatbot/
├── src/app/              ← FastAPI バックエンド（本体）
│   ├── main.py           ← アプリケーションファクトリ・ライフサイクル管理
│   ├── core/             ← インフラ基盤（設定・認証・DB・Redis・DI・ログ・メトリクス）
│   ├── models/           ← SQLAlchemy ORM モデル（Document, Chunk, QueryTrace 等）
│   ├── api/v1/           ← REST API エンドポイント
│   │   ├── chat.py       ← POST /chat/stream（SSEストリーミング）
│   │   ├── health.py     ← ヘルスチェック
│   │   ├── feedback.py   ← フィードバック
│   │   ├── zendesk.py    ← Zendesk エスカレーション
│   │   └── admin/        ← 管理 API（9サブルーター）
│   └── services/         ← ビジネスロジック層
│       ├── agent/        ← LangGraph ReAct エージェント・ツール・プロンプト
│       ├── retrieval/    ← プラガブル RAG 検索（flat_vector/raptor/vkg/hybrid/advanced）
│       ├── llm/          ← LLM サービス（ChatModel・Embeddings）
│       ├── dgm_api/      ← DGM API クライアント（契約・電力データ取得）
│       ├── guardrails/   ← 入出力ガードレール（PII・インジェクション検知）
│       ├── document/     ← ドキュメント処理（PDF解析・チャンキング）
│       ├── cache/        ← Redis 会話キャッシュ
│       ├── tasks/        ← Celery バックグラウンドジョブ
│       ├── raptor/       ← RAPTOR 階層クラスタリング・要約
│       ├── vkg/          ← Vector Knowledge Graph（Apache AGE）
│       └── zendesk/      ← Zendesk API クライアント
│
├── widget/               ← React 19 チャットウィジェット（Shadow DOM, Vite）
├── admin/                ← React 19 管理画面 SPA（React Router 7, TanStack Table, Cytoscape.js）
├── dashboard-frontend/   ← 補助ダッシュボード
│
├── mock-dgm-api/         ← FastAPI DGM API モック（契約・電力・課金データ）
├── mock-platform/        ← Next.js プラットフォームモック（JWT発行・JWKS）
│
├── docker/               ← Docker 設定（app, postgres, nginx, grafana, prometheus）
├── docker-compose*.yml   ← サービスオーケストレーション
│
├── alembic/              ← DB マイグレーション
├── tests/                ← pytest テストスイート
├── scripts/              ← ユーティリティスクリプト（RAG評価・ナレッジseed・診断）
├── analysis/             ← 評価テストフィクスチャ
├── docs/                 ← ドキュメント（アーキテクチャ・API・デプロイ・管理者マニュアル）
└── Makefile              ← 開発コマンド（lint, test, format, up, down）
```

## 各レイヤーの役割まとめ

| レイヤー | ディレクトリ | 役割 |
|---------|------------|------|
| **フロントエンド** | `widget/` | ユーザー向けチャット UI（埋め込み型） |
| **管理画面** | `admin/` | ドキュメント管理・RAG設定・会話履歴・グラフ可視化 |
| **API** | `src/app/api/v1/` | REST エンドポイント・ミドルウェア（CORS/JWT/ログ） |
| **エージェント** | `src/app/services/agent/` | LangGraph ReAct ループ・ツール選択・プロンプト管理 |
| **検索** | `src/app/services/retrieval/` | プラガブル RAG（ベクトル検索・BM25・RRF融合） |
| **外部連携** | `src/app/services/dgm_api/` | DGM プラットフォーム API 呼び出し |
| **安全性** | `src/app/services/guardrails/` | 入出力バリデーション・有害コンテンツ検知 |
| **基盤** | `src/app/core/` | 設定・認証・DB・Redis・DI・メトリクス |
| **非同期処理** | `src/app/services/tasks/` | Celery ジョブ（PDF処理・埋め込み生成・RAPTOR・VKG） |
| **モック** | `mock-dgm-api/`, `mock-platform/` | 開発用外部サービスモック |

## 処理フロー

```
┌─────────────────────────────────────────────────────────────┐
│              ユーザー（ブラウザ）                               │
│           Chat Widget（React + Shadow DOM）                   │
└───────────────────────┬─────────────────────────────────────┘
                        │ POST /api/v1/chat/stream
                        │ Bearer JWT
                        ▼
┌─────────────────────────────────────────────────────────────┐
│                   FastAPI Server :8000                       │
│                                                             │
│  ① ミドルウェア                                              │
│     CorrelationId → CORS → StructLog → JWT認証              │
│                        │                                     │
│  ② chat_stream() ハンドラ                                    │
│     言語検出 → 入力ガードレール → Redis にユーザーメッセージ保存   │
│                        │                                     │
│  ③ SingleReactOrchestrator（LangGraph）                      │
│     ┌──────────────────────────────────────────────┐        │
│     │ PostgreSQL からチェックポイント履歴をロード       │        │
│     │ システムプロンプト + ユーザーコンテキスト構築      │        │
│     │                                              │        │
│     │ ループ（最大15回）:                             │        │
│     │   LLM がツールを選択                           │        │
│     │     ├─ knowledge_search  → RAG 検索           │        │
│     │     ├─ expand_context    → 関連チャンク取得     │        │
│     │     ├─ lookup_contract   → DGM API 契約照会    │        │
│     │     ├─ lookup_energy     → DGM API 電力照会    │        │
│     │     ├─ calculate         → 料金計算            │        │
│     │     ├─ zendesk_escalation→ チケット作成         │        │
│     │     └─ （回答）          → トークン生成         │        │
│     │                                              │        │
│     │   status / token イベントをリアルタイム送出      │        │
│     └──────────────────────────────────────────────┘        │
│                        │                                     │
│  ④ 出力ガードレール → Redis にボット応答キャッシュ              │
│     sources / related / done イベント送出                     │
└───────────────────────┬─────────────────────────────────────┘
                        │ SSE Stream
                        │ (status, token, sources, related, done)
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  Widget がリアルタイムレンダリング                              │
│  ・status → スピナー表示                                     │
│  ・token  → メッセージをストリーミング表示                      │
│  ・sources → 参照元をメッセージ下に表示                        │
│  ・related → フォローアップ質問を提示                          │
│  ・done   → 入力欄を有効化                                   │
└─────────────────────────────────────────────────────────────┘
```

## RAG 検索パイプライン詳細

```
knowledge_search(query)
  │
  ├─ 戦略選択（flat_vector / raptor / vkg / hybrid / advanced）
  │
  ├─ EmbeddingService でクエリをベクトル化（text-embedding-3-small）
  │
  ├─ pgvector コサイン類似度検索（APPROVED チャンクのみ）
  │   + BM25 スコアリング（日本語 MeCab トークナイズ）
  │   + RRF 融合（ハイブリッド時）
  │
  ├─ voltage_type / area メタデータフィルタ適用
  │
  ├─ QueryTrace を DB に記録（監査・分析用）
  │
  └─ ソース引用付きで結果を返却
```

## 技術スタック

| レイヤー | 技術 |
|---------|------|
| バックエンド | FastAPI, LangGraph, Celery, SQLAlchemy 2.0 async |
| データベース | PostgreSQL 16 + pgvector + Apache AGE |
| キャッシュ | Redis 7 (async) |
| LLM | OpenAI GPT-4o + text-embedding-3-small |
| 認証 | JWT (RS256) + JWKS |
| Widget | React 19, Vite, Shadow DOM |
| Admin | React 19, React Router 7, TanStack Table, Cytoscape.js |
| 監視 | Prometheus, Grafana, structlog |
| コンテナ | Docker Compose, Nginx |
