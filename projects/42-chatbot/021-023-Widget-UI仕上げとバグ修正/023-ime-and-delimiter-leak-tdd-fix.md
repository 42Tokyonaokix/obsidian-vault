---
title: "IME Enter誤送信 & RELATED_QUESTIONS部分デリミタリーク修正（TDD再実装）"
date: 2026-03-22
project: 42-chatbot
tags: [widget, bugfix, ime, streaming, tdd, related-questions]
---

## 概要

022で中途半端だった2つのバグをTDD駆動で再実装。(1) IME Enter誤送信修正がmainに未反映だった問題を正しくmainベースで適用、(2) `[RELATED_QUESTIONS]` デリミタがチャンク境界をまたぐ際に部分テキスト（`[RELATED` 等）がUIにリークする問題をバッファリングアルゴリズムで根本修正。PR #35。

## 作業内容

### 022の問題点

前回の実装（ブランチ `fix/010-011-widget-bugfixes`）は以下の問題を抱えていた:

1. **IME修正がmainに未反映**: ブランチにコミットされていたがpush/マージされておらず、mainには修正が入っていなかった
2. **デリミタリーク**: `SingleReactOrchestrator.astream()` でデリミタ `[RELATED_QUESTIONS]` がチャンク境界をまたぐと、既にyield済みの部分テキスト（例: `[RELATED`）がフロントエンドに流れていた。フロントエンドの防御は完全なデリミタ文字列のみを検索するため、部分文字列は除去されなかった

### Bug 1: IME Enter 誤送信（再適用）

`widget/src/components/InputArea.tsx` L41 に `!e.nativeEvent.isComposing` ガードを追加。コード自体は022と同一だが、今回はmainベースのブランチから正しく適用。

テスト6件追加（`input-area.test.tsx`）:
- 通常Enter送信 / IME composing中のEnter非送信 / Shift+Enter非送信
- compositionstart→compositionend→Enterのライフサイクル
- 空入力Enter / disabled状態Enter

### Bug 2: デリミタ部分テキストリーク修正

**根本原因**: 旧実装は各トークンチャンクを即座にyieldしていた。デリミタがチャンク境界をまたぐと、最初のチャンク（例: `"Answer\n\n[RELATED"`）は完全なデリミタを含まないため即座にyieldされ、次のチャンクで初めてデリミタが完成する。既にyield済みのテキストは取り消せない。

**修正**: `_stream_filter_delimiter()` 関数を新規追加。バッファリングアルゴリズムで、デリミタのプレフィックスに一致する末尾テキストを保留する。

アルゴリズム:
1. `full_answer` に全テキストを蓄積
2. 各チャンク処理時、デリミタ `[RELATED_QUESTIONS]` のプレフィックスに一致する末尾を検出
3. 一致部分は「安全にyieldできない」として保留（`yielded_len` で管理）
4. 次のチャンクでプレフィックスが解消されたら保留分もyield
5. 完全なデリミタが見つかったらデリミタ以前のみyield、以降は破棄
6. ストリーム終了時にデリミタが見つからなければ保留分をflush

テスト10件追加（`test_single_react_streaming.py`）:
- デリミタなし / 単一チャンク内 / チャンク境界（リークなし検証）
- チャンク内デリミタ / デリミタ後スキップ
- プレフィックス保留→解放 / 偽アラーム解放
- 改行前デリミタ / 1文字ずつチャンク / 空回答

**フロントエンド防御層**: `useConversation.ts` の `onRelated`/`onDone` コールバックで `[RELATED_QUESTIONS]` 以降を除去するサニタイズも追加（多層防御）。テスト4件追加。

## 決定事項

- バッファリングアルゴリズムはプレフィックスマッチングの線形探索で実装。デリミタ長20文字程度なので性能影響は無視できる
- `_stream_filter_delimiter` を独立関数として抽出し、`astream()` 本体と同じロジックをテスト可能に
- フロントエンド防御層はバックエンド修正が完全でも残す（多層防御の原則）

## 次にやること

- PR #35 をレビュー・マージ
- 実機テストで IME 動作確認（Chrome/Safari）
- 実機テストで関連質問テキストリーク非発生を確認
