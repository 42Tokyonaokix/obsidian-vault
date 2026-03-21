---
title: "Multi-Agent Data Agent ツールの jwt_token を config.metadata 方式に移行"
date: 2026-03-22
project: 42-chatbot
status: todo
progress: 0/5
priority: high
tags: [security, multi-agent, jwt, refactor]
---

## 概要

MultiAgentOrchestrator の Data Agent ツール7つが jwt_token をツール引数で受け取る設計（LLM にトークンが露出）を、SingleReact と同じ RunnableConfig.metadata 方式に統一する。現在 astream() が jwt_token を受け取っておらず Data Agent が認証なしで動作している機能不全も同時に解消する。

## タスク

- [ ] T-1: Protocol の astream に jwt_token: str = "" を追加
  - `src/app/services/agent/protocol.py` の `AgentOrchestrator.astream()` シグネチャ修正
  - chat.py が既に jwt_token を渡しているが Protocol に定義がない問題を解消
- [ ] T-2: MultiAgentOrchestrator.astream() で config を組み立て graph に渡す
  - `orchestrator.py` の astream() に `jwt_token: str = ""` パラメータ追加
  - `config = {"metadata": {"jwt_token": jwt_token, "tenant_id": tenant_id, "user_id": user_id}}` を組み立て
  - `self._graph.astream(..., config=config)` に渡す
  - 根本原因（config が一切渡されていない）の修正
- [ ] T-3: execute_task_node に config: RunnableConfig を追加し agent.ainvoke に転送
  - `execute_task_node(state: dict)` → `execute_task_node(state: dict, config: RunnableConfig)` に変更
  - `agent.ainvoke({"messages": messages}, config=config)` に修正（リトライ時も同様）
  - LangGraph の graph-level config 自動引き継ぎを活用（Send payload/merge.py の変更不要）
- [ ] T-4: Data Agent ツール全7件を config.metadata 方式に変更
  - 各ツールの引数から `jwt_token: str` を削除
  - `*, config: RunnableConfig` パラメータを追加
  - `config.get("metadata", {}).get("jwt_token", "")` で取得
  - docstring から jwt_token の記述を削除
  - 対象:
    - [ ] demand_contract.py: get_demand_contract, list_demand_contracts
    - [ ] electric_energy.py: get_electric_energy
    - [ ] endpoint_monthly_charge.py: get_endpoint_monthly_charge, get_fuel_cost_adjustment, get_renewable_energy_surcharge
    - [ ] charge_breakdown.py: get_charge_breakdown
- [ ] T-5: テスト追加・既存テスト更新
  - config.metadata から jwt_token が正しく取得されることの単体テスト
  - execute_task_node が config を agent.ainvoke に転送することのテスト
  - ツール JSON Schema に jwt_token が含まれないことの確認（LLM から不可視の検証）
