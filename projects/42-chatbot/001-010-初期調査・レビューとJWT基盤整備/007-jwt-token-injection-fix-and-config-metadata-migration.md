---
title: "JWT トークン注入バグ修正と config metadata 自動注入への移行"
date: 2026-03-21
project: 42-chatbot
tags: [jwt, security, langchain, tool-design, bugfix]
---

## 概要

LLM が DGM API ツール呼び出し時に誤った tenant_id/user_id を使用する問題を修正。tool 引数から config metadata 自動注入パターンに移行し、ユーザー識別情報の安全な伝播を実現した。

## 作業内容

### 背景: JWT トークン注入バグの発見

`user-data-access` ブランチのマージにより、JWT トークンが `RunnableConfig` metadata 経由で安全に注入される仕組みが導入された。しかし `tenant_id` / `user_id` は依然として LLM が tool call 引数として渡す設計のままだった。

### 問題の症状

- ログイン時は `tenant-1` / `user-1` だが、LLM は古い会話履歴から `tenant-001` / `user-001` で API 呼び出し
- mock-dgm-api が `403 Forbidden` を返し、電力データ取得に失敗
- orphaned tool call (`lookup_contract` の `call_7r4C7cJn2kPB6R7LX0QQhyi9`) が毎回 repair される

```
GET /api/v1/tenants/tenant-001/users/user-001/energy → 403 Forbidden
dgm_api_error: status_code=403, tenant_id=tenant-001, user_id=user-001
lookup_energy_error: status_code=403
```

### 根本原因

1. **LLM がユーザー ID を自分で決定する設計** — SystemMessage で `tenant_id=tenant-1` と通知しているが、LLM がチェックポイント(会話履歴)に残る古い ID を使い続ける
2. **会話履歴の汚染** — 以前のセッションで `tenant-001` を使った tool call が LangGraph チェックポイントに保存され、新しいリクエストでもそのコンテキストが引き継がれる

### 修正内容

`jwt_token` と同じパターンで `tenant_id` / `user_id` も config metadata から自動注入するよう変更。

#### lookup_contract.py

```python
# Before: LLM が引数を渡す
async def lookup_contract(tenant_id: str, user_id: str, config: RunnableConfig) -> str:
    jwt_token = config.get("metadata", {}).get("jwt_token", "")

# After: config metadata から自動取得
async def lookup_contract(config: RunnableConfig) -> str:
    metadata = config.get("metadata", {})
    jwt_token = metadata.get("jwt_token", "")
    tenant_id = metadata.get("tenant_id", "")
    user_id = metadata.get("user_id", "")
```

#### lookup_energy.py

```python
# Before: tenant_id, user_id, period が LLM 引数
async def lookup_energy(tenant_id: str, user_id: str, period: str = "", *, config: RunnableConfig) -> str:

# After: period のみ LLM 引数、残りは config から
async def lookup_energy(period: str = "", *, config: RunnableConfig) -> str:
    metadata = config.get("metadata", {})
    tenant_id = metadata.get("tenant_id", "")
    user_id = metadata.get("user_id", "")
```

#### テスト更新

- `test_phase6_tools.py`: 全 tool.ainvoke() から `tenant_id`/`user_id` 引数を削除、config metadata 経由に統一
- `test_connectivity.py`: `test_lookup_contract_hides_sensitive_params` / `test_lookup_energy_hides_sensitive_params` — jwt_token に加え tenant_id, user_id, config が LLM スキーマに含まれないことを検証

### データフロー（修正後）

```
ログイン (mock-platform:9002)
  → JWT 発行 (userId=user-1, tenantId=tenant-1)
  → chat.py: JwtTokenDep で raw token 抽出
  → chat.py: CurrentUserDep で UserClaims 生成
  → orchestrator.astream(jwt_token=..., user_id=..., tenant_id=...)
  → config["metadata"] にセット
  → LLM が lookup_energy() を引数なしで呼び出し
  → tool 内で config.metadata から tenant_id/user_id/jwt_token を取得
  → DGM API 呼び出し (正しい ID で認証)
```

### 関連修正（同セッション内）

| 修正 | ファイル | 内容 |
|------|---------|------|
| user-data-access マージ | 複数 | JWT を RunnableConfig metadata 経由で注入する仕組み |
| mock-platform デフォルト ID 変更 | `mock-platform/app/page.tsx` | `user-001` → `user-1`, `tenant-001` → `tenant-1` |
| mock-dgm-api リビルド | Docker | 新しい `/users/{user_id}/` ルートを反映 |
| JWKS キャッシュ問題 | Docker | mock-platform リビルド後に app 再起動が必要 |
| knowledge seed 修正 | `scripts/seed_knowledge.py` | `glob("*.yaml")` → `rglob("*.yaml")` |
| orphaned tool call 修復 | `single_react.py` | `_repair_orphaned_tool_calls()` 関数追加 |

## 決定事項

- **ユーザー識別情報は LLM に渡さない** — セキュリティとデータ整合性の両面で、`tenant_id`/`user_id` は config metadata 経由で自動注入する設計に統一
- `tool_call_schema`（LLM が見るスキーマ）に `jwt_token`/`tenant_id`/`user_id`/`config` が含まれないことをテストで保証
- `lookup_energy` の `period` パラメータのみ LLM 引数として残す（ユーザーが期間を指定するユースケースがあるため）

## 次にやること

- [ ] multi-agent tools（demand_contract, electric_energy, charge_breakdown, endpoint_monthly_charge）も同じ config metadata パターンに移行
- [ ] 5件の failing cache テスト修正（test_dgm_cache.py, test_billing_endpoints.py）
- [ ] 3件の壊れた YAML ファイル修正（供給条件説明書_低圧_RE100, 重要事項説明書_低圧, 電気需給約款_低圧_再エネメニューあり）
- [ ] 未コミット変更のコミットと PR 作成
