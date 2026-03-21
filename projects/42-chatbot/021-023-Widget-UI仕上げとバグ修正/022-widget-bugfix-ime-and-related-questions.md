---
title: "Widget バグ修正: IME Enter誤送信 & 関連質問テキスト混入"
date: 2026-03-22
project: 42-chatbot
tags: [widget, bugfix, ime, streaming, related-questions]
---

## 概要

チャットウィジェットの2つのバグを修正。(1) 日本語IME変換確定のEnterキーでメッセージが誤送信される問題、(2) SingleReactOrchestratorのストリーミングで関連質問テキストがメッセージ本文に混入する問題。

## 作業内容

### Bug 010: IME Enter 誤送信

`widget/src/components/InputArea.tsx` の `handleKeyDown` で、Enter キー検出時に `e.nativeEvent.isComposing` をチェックしていなかったため、日本語入力の変換確定操作がメッセージ送信として誤検知されていた。

**修正**: 条件に `&& !e.nativeEvent.isComposing` を1行追加。

**テスト**: `input-area.test.tsx` に3テスト追加（通常Enter送信/IME Enter非送信/Shift+Enter非送信）。

### Bug 011: 関連質問テキストのメッセージ本文混入

`SingleReactOrchestrator.astream()` がLLMの `agent` ノードからのトークンを無条件に `token` SSEイベントとして送出していた。LLMプロンプトが `[RELATED_QUESTIONS]` デリミタで関連質問を本文末尾に埋め込む設計のため、デリミタ以降のテキストもメッセージ本文としてフロントエンドに流れていた。`_extract_related_questions()` の除去処理はストリーム完了後にしか実行されない。

**修正（バックエンド）**: `astream()` に `full_answer` バッファと `delimiter_found` フラグを追加。蓄積テキストで `[RELATED_QUESTIONS]` を検知したらトークン送出を停止。トークン分割境界をまたぐケースにも対応。

**修正（フロントエンド防御層）**: `useConversation.ts` の `onRelated` と `onDone` コールバックで、メッセージ本文から `[RELATED_QUESTIONS]` 以降を除去する防御的サニタイズを追加。

**テスト**: バックエンド10件（`_extract_related_questions` 4件 + streaming delimiter検知 6件）、フロントエンド4件（onRelated/onDoneサニタイズ）。

## 決定事項

- IME対応は `nativeEvent.isComposing` のインラインチェックを採用。`compositionstart/end` + `useRef` は冗長として却下。
- 関連質問混入修正はバックエンド根本修正 + フロントエンド防御層の2段構えを採用。フロントエンドのみの事後フィルタリングは却下。
- `MultiAgentOrchestrator` は `ui_resource` 方式で問題なし。`SingleReactOrchestrator` のプロンプト設計を統一するリファクタは別タスクとして切り出し。

## 次にやること

- ブランチ `fix/010-011-widget-bugfixes` をpush・PRを作成しマージする
- Vault タスク PR（https://github.com/42Tokyonaokix/obsidian-vault/pull/1）をマージする
