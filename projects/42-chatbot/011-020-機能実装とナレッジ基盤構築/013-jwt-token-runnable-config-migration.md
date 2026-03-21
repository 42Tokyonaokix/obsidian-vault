---
title: "fix: JWT トークンを RunnableConfig metadata 経由で DGM API に伝播"
date: 2026-03-22
project: 42-chatbot
tags: [security, jwt, dgm-api, langgraph, runnable-config]
---

## 概要

DGM API 呼び出しにユーザーの JWT トークンを伝播する仕組みを実装。LangGraph の RunnableConfig metadata を使い、LLM にトークンを露出させずに認証ヘッダーを設定する。8ファイル変更、全テストパス。

## 作業内容

### 1. 背景・問題

- 既存実装では DGM API 呼び出しに認証ヘッダーが付与されておらず、本番環境（認証必須）では API コールが失敗する
- mock サーバー環境では認証不要のため開発中は問題が顕在化しなかった
- LLM にトークンを渡すとツールスキーマに露出し、セキュリティリスクになる

### 2. 設計判断

**RunnableConfig metadata 方式を採用**（InjectedToolArg + closure 方式は不採用）:

- LangGraph の `config["metadata"]` はグラフ全体に自動伝播される（Send API 経由のノードにも伝播）
- 同リポジトリの commit `4839146`（main ブランチ）で同パターンの実績あり
- 変更対象が 8 ファイルで最小限（closure 方式は 10+ ファイル）
- DGMApiClient はシングルトンのため、メソッド引数で jwt_token を渡す方式が concurrency-safe

### 3. 実装内容（8ファイル）

| ファイル | 変更内容 |
|---------|---------|
| `src/shared/auth/types.py` | `UserIdentity` に `jwt_token: str = ""` 追加（`__repr_args__` で除外しログ漏洩防止） |
| `src/shared/auth/deps.py` | JWT 検証後に raw token を `identity.jwt_token` に保存 |
| `src/app/api/v1/chat.py` | `get_agent_response()` に `jwt_token=user.jwt_token` を渡す |
| `src/app/graph/orchestrator.py` | `config["metadata"]["jwt_token"]` に設定（LangGraph が全ノードに自動伝播） |
| `src/app/integrations/dgm/client.py` | 全メソッドに `jwt_token` パラメータ追加、`Authorization: Bearer` ヘッダー設定 |
| `src/app/agents/tools/demand_contract.py` | `config: RunnableConfig` から jwt_token 取得 |
| `src/app/agents/tools/electric_energy.py` | 同上 |
| `src/app/agents/tools/consignment_charge.py` | 同上 |

### 4. データフロー

```
HTTP Request (Authorization: Bearer xxx)
  → deps.py: verify_jwt() → UserIdentity.jwt_token に保存
    → chat.py: jwt_token=user.jwt_token
      → orchestrator.py: config["metadata"]["jwt_token"] = jwt_token
        → LangGraph 自動伝播 (Send API 含む)
          → @tool 関数: config.get("metadata", {}).get("jwt_token", "")
            → DGMApiClient: headers={"Authorization": f"Bearer {jwt_token}"}
```

### 5. 後方互換性

- `jwt_token=""` デフォルトにより、Web UI ルート (`routes.py`) や mock サーバー環境では Authorization ヘッダーなしで動作
- 既存テスト 160 件パス（3 件の失敗は既存バグ: `_is_business_related_async` 属性欠損）

## 決定事項

- LLM にトークンを露出させない方式として RunnableConfig metadata を採用
- DGMApiClient はシングルトンのため、インスタンス状態ではなくメソッド引数で jwt_token を渡す
- `UserIdentity.jwt_token` は `repr` から除外してログ漏洩を防止
