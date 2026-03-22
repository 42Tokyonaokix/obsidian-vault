---
title: "fix: JWT トークン注入を InjectedToolArg パターンに移行"
date: 2026-03-21
project: 42-chatbot
status: done
progress: 6/6
priority: critical
tags: [bug, security, dgm-api]
---

## 概要

LLM がツール引数として `jwt_token` を生成しようとして空文字になるバグを修正する。LangChain `InjectedToolArg` + `RunnableConfig` metadata 経由で認証トークンを注入するパターンに全 DGM API ツールを移行し、middleware から raw token を伝播させる。

## 実行方針: 短期サイクル（実装→テスト→修正の反復）

各サブタスクで「実装 → pytest 実行 → 失敗分析 → 修正」を1サイクルとし、green になるまで繰り返す。次のサブタスクに進む前に必ず全テスト pass を確認する。

## タスク

- [x] **1. 棚卸し + 回帰テスト先行作成**
  - `jwt_token` を引数に持つ全ツール関数を grep で列挙
  - 修正完了時に pass すべきテスト `tests/services/test_jwt_injection.py` を先に書く（現状は FAIL で OK）
  - テスト内容: ツールスキーマに `jwt_token` が露出しないこと、`Bearer ''` が送出されないこと
  - **サイクル**: テスト作成 → `pytest tests/services/test_jwt_injection.py` → 全件 FAIL を確認

- [x] **2. UserClaims に raw_token 追加**
  - `auth.py` の UserClaims に `raw_token: str` フィールド追加（`repr=False`）
  - middleware で検証済み token を保存
  - **サイクル**: 実装 → `pytest tests/core/` → green 確認

- [x] **3. Chat API → Orchestrator の token 伝播**
  - `chat.py` で `user.raw_token` を orchestrator に渡す
  - `single_react.py` の `astream`/`ainvoke` で `config["metadata"]["jwt_token"]` に設定
  - **サイクル**: 実装 → `pytest tests/api/ tests/services/agent/` → green 確認

- [x] **4. single_react 系ツールの InjectedToolArg 移行**
  - `lookup_contract.py`, `lookup_energy.py` を修正
  - `jwt_token` → `Annotated[str, InjectedToolArg]` + `RunnableConfig` から取得
  - **サイクル**: 実装 → `pytest tests/services/test_jwt_injection.py tests/services/agent/tools/` → 該当テスト green 確認

- [x] **5. multi_agent 系ツールの InjectedToolArg 移行**
  - `demand_contract.py`, `electric_energy.py`, `charge_breakdown.py`, `endpoint_monthly_charge.py`
  - **サイクル**: 実装 → `pytest tests/services/test_jwt_injection.py tests/services/agent/multi_agent/` → green 確認

- [x] **6. 全体回帰テスト + クリーンアップ**
  - `pytest tests/ -q` で全体 pass 数が修正前（1033）以上、新規 fail なし
  - `test_repair_orphaned_tool_calls.py` の `jwt_token: ""` を削除
  - **サイクル**: 全テスト実行 → 差分確認 → 残存 fail があれば修正

## 制約

- DGMApiClient のメソッドシグネチャ（`get_contract(tenant_id, jwt_token)` 等）は変更しない
- raw_token は `repr=False` でログ漏洩を防止
- Alembic 関連の既存 26 fail はスコープ外
