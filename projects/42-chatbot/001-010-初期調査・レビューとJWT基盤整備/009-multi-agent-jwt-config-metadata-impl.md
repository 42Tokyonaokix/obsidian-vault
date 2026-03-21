---
title: "Multi-Agent jwt_token を config.metadata 方式に移行（実装）"
date: 2026-03-22
project: 42-chatbot
tags: [security, multi-agent, jwt, refactor, implementation]
---

## 概要

008 で策定した計画に基づき、MultiAgentOrchestrator の Data Agent ツール7つの jwt_token をツール引数から RunnableConfig.metadata 方式に移行した。全203テストパス。

## 作業内容

### T-1: Protocol astream シグネチャ修正

`src/app/services/agent/protocol.py` の `AgentOrchestrator.astream()` に `user_email: str = ""` と `jwt_token: str = ""` パラメータを追加。chat.py が既に渡していたが Protocol に定義がなかった問題を解消。

### T-2: MultiAgentOrchestrator.astream() で config 組み立て

`orchestrator.py` の `astream()` に `jwt_token: str = ""` パラメータを追加し、LangGraph config dict を組み立て:

```python
config = {
    "metadata": {
        "user_id": user_id,
        "tenant_id": tenant_id,
        "user_email": user_email,
        "jwt_token": jwt_token,
    },
}
```

`self._graph.astream(input, config=config, stream_mode="updates")` に渡すことで、根本原因（config が一切渡されていなかった）を修正。

### T-3: execute_task_node に config: RunnableConfig 追加

`execute_task_node(state: dict)` → `execute_task_node(state: dict, config: RunnableConfig)` に変更。LangGraph が Send 先ノードに config を自動引き継ぎする仕組みを活用。

`agent.ainvoke({"messages": messages}, config=config)` に修正（リトライ時の `retry_agent.ainvoke` も同様）。これにより ephemeral agent 内のツールが config.metadata 経由で jwt_token にアクセス可能になった。

### T-4: Data Agent ツール全7件を config.metadata 方式に変更

対象4ファイル7ツール:

| ファイル | ツール | 変更 |
|---------|--------|------|
| demand_contract.py | get_demand_contract, list_demand_contracts | `jwt_token: str` → `*, config: RunnableConfig` |
| electric_energy.py | get_electric_energy | 同上 |
| endpoint_monthly_charge.py | get_endpoint_monthly_charge, get_fuel_cost_adjustment, get_renewable_energy_surcharge | 同上 |
| charge_breakdown.py | get_charge_breakdown | 同上 |

各ツールの変更パターン:
1. `from langchain_core.runnables import RunnableConfig` を追加
2. 関数シグネチャから `jwt_token: str` を削除、`*, config: RunnableConfig` を追加
3. 関数冒頭で `jwt_token = config.get("metadata", {}).get("jwt_token", "")` で取得
4. docstring から jwt_token の記述を削除

### T-5: テスト更新・追加

**更新**: `test_billing_tools.py` — 全既存テストの `tool.ainvoke({"jwt_token": ...})` → `tool.ainvoke({...}, config=_TEST_CONFIG)` に変更

**更新**: `test_execute_task.py` — 全ノード呼び出しに `_TEST_CONFIG` を第2引数として追加

**新規**: `test_jwt_config_metadata.py` — 以下の検証テストを追加:
- `test_all_seven_tools_exclude_jwt_token_from_schema`: 7ツール全てのJSON Schemaに jwt_token が含まれないことを検証（LLM不可視の確認）
- `test_config_not_in_schema`: config パラメータもスキーマに露出しないことを検証
- 各ツールの `config.metadata["jwt_token"]` → API client 呼び出しの end-to-end テスト
- `test_empty_jwt_when_metadata_missing`: metadata が空の場合のフォールバック検証

## 決定事項

- **tenant_id はスコープ外**: 今回は jwt_token のみ移行。tenant_id のツール引数→config.metadata 移行は後続タスクとする
- **merge.py / state.py は変更不要**: LangGraph の config 自動引き継ぎにより、Send payload や OrchestratorState への jwt_token フィールド追加は不要
- **テスト方針**: `tool.ainvoke(input, config=config)` 形式で config を渡すのが LangChain の標準パターン

## 次にやること

- chatbot リポジトリでコミット・PR 作成
- vault のタスク 004 のステータスを done に更新
- 後続タスク: tenant_id も config.metadata に移行（SingleReact との完全統一）
