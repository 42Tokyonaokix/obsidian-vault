---
title: "Widget フィルタ選択UI追加とRAGメタデータフィルタリング統合"
date: 2026-03-22
project: 42-chatbot
tags: [widget, rag, metadata-filtering, voltage-type, area]
---

## 概要

Widget（チャットパネル）にフィルタ選択画面を追加。JWT認証後・チャット開始前に voltage_type / area を選択させ、セッション中保持してRAG検索に適用する仕組みを構築。

## 作業内容

### バックエンド（前セッションで完了済み）
- `ChatStreamRequest` に `voltage_type` / `area` フィールド追加
- `chat.py` → orchestrator → `config["metadata"]` 経由でツールに伝播
- `qa_search` / `knowledge_search` ツールが `config.metadata` からフィルタ取得
- `flat_vector.py` で SQL レベルのメタデータフィルタリング（未タグチャンクはパススルー）
- `voltage_filter.py` に `detect_area()`, `exclude_mismatched_voltage_type()`, `exclude_mismatched_area()` 追加

### Widget（本セッション）
- `AuthGate.tsx` を拡張: 認証後にフィルタ選択モード（voltage_type/area ドロップダウン + 開始ボタン）を表示
  - デフォルト: 高圧 / 東京電力
  - 選択は必須（スキップ不可）、セッション中は変更不可
- `App.tsx`: フィルタ状態管理（`sessionStorage` に保存）、authenticated + !filters → フィルタ選択画面 → ChatPanel の遷移制御
- `ChatPanel.tsx` → `useConversation` → `useSSE` → リクエストボディに `voltage_type` / `area` を含めて送信
- `i18n.ts`: フィルタ選択画面のラベル（ja/en）追加
- `widget.css.ts`: フィルタフォーム用スタイル追加

### インフラ修正
- `main.py`: widget.js の `Cache-Control` を `no-cache` に変更（開発中のキャッシュ問題対策）
- `docker-compose.dev.yml`: `env_file` パスを `.env` に修正
- `mock-platform/dashboard/page.tsx`: widget.js URL に `Date.now()` キャッシュバスター追加

## 決定事項

- フィルタ選択は AuthGate コンポーネントを拡張して実装（新コンポーネント不要）。将来的に認証情報からドキュメント種別を自動取得する想定があるため、AuthGate に統合
- セッション中のフィルタ変更は不可（変えたければパネルを閉じて再度開く）
- デフォルト値: 高圧 / 東京電力（関東）

## 次にやること

- デバッグ用 `console.log` の除去
- widget.js の `Cache-Control` を本番用に戻す（ETag ベース等）
- git commit（未コミット）
