---
title: "Docker ビルド修正と widget クロスオリジン API ルーティング対応"
date: 2026-03-21
project: 42-chatbot
tags: [docker, widget, cross-origin, dev-environment]
---

## 概要

ローカル開発環境の起動を妨げていた3つの問題（Dockerビルド失敗、DB未作成、widget API ルーティング不一致）を修正し、ブラウザからチャットエージェントを利用可能にした。

## 作業内容

### 問題1: app Dockerfile ビルド失敗

`python:3.12-slim` に `gcc`/`g++` が含まれておらず、`hdbscan` 等の native extension のコンパイルに失敗していた。

**修正**: `docker/app/Dockerfile` の builder ステージに `gcc g++` パッケージを追加。

### 問題2: mock_dgm データベース未作成

`docker/postgres/initdb.d/02-create-mock-db.sh` が存在していたが、Dockerfile に COPY が記述されていなかった。mock-dgm-api が起動時に DB 不在でエラー。

**修正**: `docker/postgres/Dockerfile` に COPY と chmod を追加。既存の volume がある場合は `docker compose down -v` で再初期化が必要。

### 問題3: widget の API リクエスト先不一致

widget は `window.location.origin`（= `http://localhost:9002` mock-platform）を API URL として使用していた。dev 環境では FastAPI が `:8000` で動作するため、API リクエストが到達しなかった。

**修正**: `document.currentScript` を IIFE 実行時にキャプチャし、script タグの `src` 属性から origin を取得。これを `main.tsx` → `App.tsx` → `ChatPanel.tsx` に prop として伝搬。本番（nginx 経由の同一 origin）では `window.location.origin` にフォールバック。

### 追加の問題: JWT 署名検証エラー

mock-platform は起動ごとに RSA 鍵ペアを再生成するが、JWT は localStorage に保持される。mock-platform 再起動後にページリロードしても古い JWT が使われるため `Signature verification failed` が発生。Logout → 再ログインで解決。

## 決定事項

- widget の API URL 解決は `document.currentScript.src` の origin を使う方式を採用
- Dockerfile の修正は別ブランチ `fix/docker-and-widget-cross-origin` で PR #30 として main に提出

## 次にやること

- PR #30 のレビュー・マージ
- エージェントとの実際の会話テスト（OPENAI_API_KEY 設定済み）
- metadata filtering 機能の作業再開（元ブランチ `Naoki/metadata_filtering`）
