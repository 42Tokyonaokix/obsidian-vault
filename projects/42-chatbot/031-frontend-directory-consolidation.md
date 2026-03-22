---
title: "フロントエンド3ディレクトリを frontend/ に統合"
date: 2026-03-22
project: 42-chatbot
tags: [refactor, frontend, directory-structure]
---

## 概要

admin/, dashboard-frontend/, widget/ の3フロントエンドを frontend/ 配下に移動し、ディレクトリ構成を整理した。

## 作業内容

### 移動

- `admin/` → `frontend/admin/`
- `dashboard-frontend/` → `frontend/dashboard/`
- `widget/` → `frontend/widget/`

### パス参照の修正（15ファイル）

- `docker/app/Dockerfile` — widget ビルド・コピーパス
- `docker/nginx/Dockerfile` — admin ビルド・コピーパス
- `src/app/main.py` — widget.js 配信パス解決
- `docker-compose.yml`, `docker-compose.dev.yml` — コメント・ボリュームマウント
- `Makefile` — ビルドコマンド
- `README.md`, `README.en.md` — ディレクトリツリー
- `docs/` 配下6ファイル — パス参照
- `.gitignore` — コメント

### 確認事項

- widget ビルド成功（`frontend/widget/dist/widget.js` 生成）
- Python からの widget.js パス解決が正しいことを確認
- dashboard-frontend はどこからも参照されていなかった（独立SPA）

## 決定事項

- モノレポ化（pnpm workspaces等）はスコープ外。純粋なディレクトリ移動のみ
- widget は性質が異なる（IIFE、Shadow DOM）が、見通しの良さを優先して同じ frontend/ にまとめた

## 次にやること

- admin の npm ci + ビルド確認（node_modules 未インストールのため未検証）
- dashboard の npm ci + ビルド確認（同上）
