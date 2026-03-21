---
title: "Multi-Agent jwt_token 設計分析と config.metadata 移行計画"
date: 2026-03-22
project: 42-chatbot
tags: [security, multi-agent, jwt, architecture]
---

## 概要

MultiAgentOrchestrator の Data Agent ツール7つが jwt_token をツール引数で受け取る設計（LLM にトークンが露出）を分析し、SingleReact と同じ RunnableConfig.metadata 方式への移行計画を策定した。

## 作業内容

### 現行 multi_agent 実装の全体構造を調査

KB ブランチ（Naoki/Knowledge_base）から移植済みの 3ノード構成を確認:

1. **classify_intent**（タスク生成）: `ChatOpenAI.with_structured_output(IntentClassification)` で5カテゴリ分類 + タスク分解
2. **execute_task**（全力タスク処理）: `Send()` による並列ディスパッチ、エフェメラル QA/Data Agent
3. **merge_results**（タスクのマージ）: 単一タスクはパススルー、複数タスクは LLM マージ

### jwt_token の問題を特定

**2つの非互換を発見:**

1. **astream() シグネチャ不一致**: chat.py が `jwt_token=jwt_token` を渡しているが、`MultiAgentOrchestrator.astream()` にパラメータがない → 受け取れていない
2. **設計方式の違い**:
   - SingleReact: `config.metadata["jwt_token"]` 経由（LLM にトークン不可視）
   - MultiAgent: ツール引数として `jwt_token: str` を定義（LLM がトークンを見る）

**根本原因**: `execute_task_node` が `agent.ainvoke({"messages": messages})` で config を渡していない。Send() は per-task state dict を渡す仕組みで LangGraph config とは別経路のため、ツール引数方式で迂回していた。

### セキュリティリスクの評価

- LLM コンテキストにトークンが載る → プロンプトインジェクションで漏洩リスク
- LangSmith トレースにトークンが記録されるリスク
- LLM が回答文中でトークンを引用するリスク
- ただし JWT は有効期限あり、社内チャットボットなので致命度は中程度

### 解決策の設計（AI 3エージェントブレスト）

PM・Architect・Critic の3エージェントで検討し、以下の方針を決定:

**採用**: グラフレベルの RunnableConfig.metadata 経由注入
- `orchestrator.astream()` → `_graph.astream(input, config={"metadata": {"jwt_token": ...}})` → LangGraph が Send 先ノードに config 自動引き継ぎ → `execute_task_node(state, config: RunnableConfig)` → `agent.ainvoke(messages, config=config)` → ツール内で `config.metadata["jwt_token"]` 取得

**却下した代替案**:
- OrchestratorState に jwt_token フィールド追加 → トレース漏洩リスク
- Send payload に jwt_token 含める → messages 混入リスク
- ContextVar → 並列リクエスト間で値混入リスク
- DGM Client に jwt_token を set → シングルトンで並列不可
- get_data_tools() クロージャ束縛 → リクエストスコープの値を DI に混入

## 決定事項

### タスク構成（5サブタスク、優先度 high）

1. **T-1**: Protocol の astream に `jwt_token: str = ""` を追加
2. **T-2**: `MultiAgentOrchestrator.astream()` で config を組み立て graph に渡す
3. **T-3**: `execute_task_node` に `config: RunnableConfig` を追加し `agent.ainvoke` に転送
4. **T-4**: Data Agent ツール全7件を config.metadata 方式に変更
5. **T-5**: テスト追加・既存テスト更新

### スコープ外（後続タスク）

- tenant_id もツール引数から config.metadata に移行（SingleReact との完全統一）
- ainvoke() のシグネチャに jwt_token 等を追加
- SystemMessage の tenant_id 注入整理

## 次にやること

- 上記タスク構成に基づいて実装ブランチを作成し、T-1 から順に着手
- LangGraph の Send 先ノードへの config 自動引き継ぎを実装初期に検証
