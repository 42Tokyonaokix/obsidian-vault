---
title: "42-chatbot 全リポジトリ コードレビュー"
date: 2026-03-20
project: 42-chatbot
tags: [code-review, security, architecture, production-readiness]
---

## 概要

42-chatbot リポジトリ全体（486コミット）を対象としたコードレビュー。アーキテクチャは優秀だが、クリティカルなセキュリティ問題3件と未接続の出力ガードレールの修正が本番デプロイ前に必要。

## 作業内容

### 良い点

1. **教科書的な設定管理** — Pydantic Settingsで`SecretStr`、グループ化されたenvプレフィックス、`@lru_cache`シングルトン (`src/app/core/config.py`)
2. **クリーンなDI** — FastAPIの`Annotated[..., Depends()]`型エイリアスを全体で活用
3. **7層の入力ガードレールパイプライン** — 長さ、一貫性、スコープ、PII正規表現、インジェクション正規表現、Presidio PII、LLMインジェクション検知（オプションライブラリ未インストール時のフォールバック付き）
4. **回復力パターン** — DGM APIクライアントにtenacityリトライ＋非同期サーキットブレーカー（CLOSED/OPEN/HALF_OPEN状態遷移）
5. **マルチステージDockerビルド** — Nodeウィジェットビルド、uv Pythondeps、非rootランタイムユーザー
6. **デュアルオーケストレータ構成** — SingleReactとMultiAgentが同一プロトコルを満たし、設定で切替可能
7. **テストファイル90件** — ユニット、サービス、APIレイヤーをカバー
8. **構造化ログ** — structlogで相関ID付き、本番用JSON出力
9. **安全な数式評価** — simpleevalにリソース制限付き
10. **適切な起動シーケンス** — Postgres/Redis接続にエクスポネンシャルバックオフ、クリーンシャットダウン

### クリティカル（必ず修正）

| # | 問題 | 場所 |
|---|------|------|
| C1 | **gitignoreされていないディレクトリにAPIキーが露出** — `env_file/`に本物の`sk-svcacct-...` OpenAIキーがあり、`.gitignore`に入っていない。`git add .`一発でコミットされてしまう。 | `env_file/development.local.env:5` |
| C2 | **アップロードサイズ制限なし** — `await file.read()`がファイル全体をメモリに読み込み、上限なし。数GBのファイルでDoS攻撃が可能。 | `src/app/api/v1/admin/upload.py:51` |
| C3 | **スレッド所有権チェックなし** — `GET /chat/history/{thread_id}`が認証済みの任意のユーザーに他ユーザーの会話履歴を返す。UUIDは秘密情報ではない。 | `src/app/api/v1/chat.py:42-55` |

### 重要（修正すべき）

| # | 問題 | 場所 |
|---|------|------|
| I1 | CORSが`localhost:9002`にハードコード — ステージング/本番で動かない | `src/app/main.py:249` |
| I2 | サーキットブレーカーの`is_open`がロックなしで状態変更（データ競合） | `src/app/services/dgm_api/circuit_breaker.py:46-55` |
| I3 | どのエンドポイントにもレートリミットなし — LLM APIコストが青天井 | — |
| I4 | **出力ガードレールパイプラインが構築済みだが未接続** — LLM出力がサニタイズなしでユーザーに直接渡される | `src/app/services/guardrails/__init__.py:59-71` |
| I5 | `validate_output_safety`が恒久的に`return True`のプレースホルダー | `src/app/services/guardrails/validators.py:84-91` |
| I6 | 本番docker-composeがモックサービス＋デフォルト`postgres`パスワードのまま | `docker-compose.prod.yml` |
| I7 | 認証システムが重複 — `src/app/core/auth.py`(PyJWT)と`src/shared/auth/jwt_validator.py`(python-jose、importが壊れている) | — |
| I8 | PII電話番号パターンがメーターID・契約番号に誤検知する可能性 | `src/app/services/guardrails/patterns.py:15-16` |

### 軽微（あれば良い）

- **M1**: DGM APIクライアントにリクエスト処理の重複コードが約150行
- **M2**: 言語検知がCJK範囲で判定（中国語・韓国語も引っかかる）— `fast-langdetect`の方が正確
- **M3**: オーケストレータの`model`パラメータが`Any`型 — `BaseChatModel`にすべき
- **M4**: BM25インデックスの`rebuild_bm25_index()`が起動時に呼ばれない
- **M5**: `/metrics`が`PUBLIC_PATHS`に含まれ認証不要 — 運用情報が漏洩する
- **M6**: `compose.override.yml`が未追跡かつ未ignore

## 決定事項

### 優先対応の推奨事項

1. **即時対応**: `env_file/`を`.gitignore`に追加し、OpenAIキーをローテーション
2. **スレッド所有権の追加**: 会話キーを`{tenant_id}:{thread_id}`形式に変更
3. **出力ガードレールの接続**: コードは存在する — `main.py`と`chat.py`での接続だけで有効化できる
4. **レートリミット追加**: 最低限`/api/v1/chat/stream`にテナント別トークンバケット
5. **本番compose修正**: モック/デフォルト値をすべてオーバーライド

### 総合評価

**本番投入可能か？** いいえ — 修正が必要。

アーキテクチャはガードレール、サーキットブレーカー、構造化ログ、クリーンなDIなど優れたパターンが多い。しかし、3つのクリティカルなセキュリティ問題（APIキー露出リスク、アップロードサイズ無制限、スレッド所有権チェック欠如）と、未接続の出力ガードレールパイプラインを本番デプロイ前に対処する必要がある。

## 次にやること

- C1〜C3のクリティカル問題を最優先で修正
- I4の出力ガードレール接続
- I1〜I3のインフラ系改善
- 本番docker-compose設定の整備
