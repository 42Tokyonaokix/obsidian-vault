---
title: "フロントエンド UI 接続状況の調査"
date: 2026-03-22
project: 42-chatbot
tags: [frontend, docker, nginx, investigation]
---

## 概要

ポート80/8000がlocalhostから使えない原因を調査。UIコード（widget/dashboard/admin）は存在するがDocker/nginxに未接続であることを確認。

## 作業内容

### ポート調査

- `localhost:8000` → 接続成功（401 Unauthorized）— FastAPI バックエンドは正常稼働
- `localhost:9080` → 接続成功（200 OK）— nginx は稼働中だがプレースホルダーを配信
- `localhost:80` → ホスト側にマッピングなし（docker-compose で `9080:80`）

### 発見した UI コード

| ディレクトリ | 内容 | 技術スタック |
|---|---|---|
| `widget/` | チャットウィジェット | React + Vite + TypeScript |
| `dashboard-frontend/` | ダッシュボード | React + Vite + Tailwind |
| `admin/` | 管理画面 | React + Vite + shadcn/ui |

3つとも `src/` にソースコードが存在し、コンポーネント・ページ・フックが実装済み。

### 現状の問題

1. **docker-compose.yml にフロントエンドのサービス定義がない** — widget / dashboard / admin はビルド・配信されていない
2. **nginx はプレースホルダーを配信中** — `docker/nginx/placeholder/index.html` に `"SPA build pending. Run Plan 03 first."` と記載
3. **Plan 03 が未完了** — nginx の Dockerfile コメントに `admin/ directory from Plan 03` が必要と明記

### Docker Compose のポートマッピング（現状）

| サービス | ホスト:コンテナ |
|---|---|
| app (FastAPI) | 8000:8000 |
| nginx | 9080:80 |
| postgres | 5432:5432 |
| redis | 6379:6379 |
| mock-dgm-api | 9003:9003 |
| mock-platform | 9002:9002 |
| prometheus | 9090:9090 |
| grafana | 3001:3000 |

## 決定事項

- ポート80/8000の「使えない」は、UIが未接続であることが原因（バックエンドAPI自体は稼働中）
- フロントエンドの接続には Plan 03 の実施が必要

## 次にやること

- Plan 03 を実施して admin UI を nginx 経由で配信する
- widget / dashboard-frontend も docker-compose に統合する
- nginx の設定を更新して SPA ルーティング + API プロキシを構成する
