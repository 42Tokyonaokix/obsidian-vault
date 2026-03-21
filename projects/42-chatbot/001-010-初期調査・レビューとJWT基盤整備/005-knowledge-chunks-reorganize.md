---
title: "knowledge chunks をカテゴリ別サブディレクトリに再編成"
date: 2026-03-21
project: 42-chatbot
tags: [knowledge-base, yaml, refactor, rag]
---

## 概要

`src/app/services/agent/knowledge/chunks/` 配下の YAML チャンクファイルをフラット構造からカテゴリ別サブディレクトリ構造に再編成した。PR #33。

## 作業内容

### 背景

RAG 検索のナレッジベースとなる YAML チャンクファイルが全てフラットに配置されており、20 件以上のファイルが混在して管理しづらい状態だった。メタデータフィルタリング機能の追加に合わせ、カテゴリ別に整理。

### 新ディレクトリ構造

| ディレクトリ | 内容 | ファイル数 |
|---|---|---|
| `general/` | CS チームナレッジ、QA リスト、DGP ナレッジベース、計算式テンプレート | 4 |
| `DGM操作/` | システムマニュアル QA、DGM メニュー、操作手順 | 4 |
| `地域託送約款/` | 各電力会社の託送供給等約款 | 9 |
| `約款/` | DGP 利用規約、供給条件説明書、重要事項説明書、電気需給約款 | 13 |

### 変更の種類

- **移動のみ**: 託送約款 9 社分、cs_team_knowledge、qa_list、システムマニュアル等
- **新規追加**: formula_templates、DGM メニュー、操作手順、DGP ナレッジベース、各種約款の電圧・RE 区分別ファイル
- **削除**: 旧フラット配置のファイル（サブディレクトリに移動済み）

## 決定事項

- ブランチ `refactor/knowledge-chunks-reorganize` で PR #33 として main に提出
- Docker/widget 修正（PR #30）とは別 issue・別 PR に分離

## 次にやること

- PR #33 のレビュー・マージ
- RAG 検索のチャンクローダーがサブディレクトリを再帰的に読み込むか確認
- metadata filtering 機能の実装再開
