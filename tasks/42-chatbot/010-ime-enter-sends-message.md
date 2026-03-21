---
title: "IME変換確定のEnterキーでメッセージが誤送信される問題の修正"
date: 2026-03-22
project: 42-chatbot
status: todo
progress: 0/2
priority: high
tags: [widget, bugfix, ime, ux]
---

## 背景・目的

ユーザーから「日本語の確定をするために押した改行ボタン（Enter）でメッセージが送信されてしまう」という報告があった。チャットウィジェットの `InputArea.tsx` で Enter キーの検出時に IME composition 状態を考慮していないため、日本語入力の変換確定操作がメッセージ送信として誤検知される。日本語ユーザー全員が毎メッセージで踏む致命的なUXバグであり、即座に修正が必要。

## 要件定義

- **目的**: 日本語入力中にEnterキーを押した際、IMEの変換確定操作がメッセージ送信として誤検知される問題を解消する。修正範囲を最小に絞って確実に直す。
- **スコープ**:
  - やること: `InputArea.tsx` の `handleKeyDown` に IME composition 中の Enter キーイベントを無視するガードを追加
  - やること: 修正に対応するユニットテストを追加
  - やらないこと: Shift+Enter による改行挙動の変更（既存仕様を維持）
  - やらないこと: 送信ボタンの挙動変更（送信ボタンは IME と無関係）
  - やらないこと: `useConversation` や `useSSE` 側の変更（InputArea 単体で完結する問題）
- **成功基準**:
  1. IME on で Enter を押して変換確定しても、メッセージが送信されない
  2. IME を使わない英語入力、または変換確定後に Enter を押した場合は従来通り送信される
  3. Shift+Enter による改行動作が維持されている
  4. 追加したテストが pass する

## 技術検討

### 現状コード (`InputArea.tsx` L39-47)
```typescript
const handleKeyDown = useCallback(
  (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  },
  [handleSend],
);
```

- `compositionstart` / `compositionend` のイベントリスナーはコードベースに一切存在しない
- IME 入力フローでは、ブラウザが `compositionstart` → `keydown(Enter)` → `compositionend` の順でイベントを発火する
- React の `nativeEvent.isComposing` は Chrome/Firefox/Safari で一貫して動作する（React v17以降）
- `textarea` の `onChange` は composition を意識せず正しく動作しており、問題は `onKeyDown` ハンドラのみに局所化されている

### 推奨アプローチ
`e.nativeEvent.isComposing` のインラインチェックを追加する。1行変更で完結。

### 却下した代替案
- **`compositionstart/compositionend` + `useRef` でフラグ管理**: 動作するが `nativeEvent.isComposing` が同等の情報を1行で提供するため冗長
- **ライブラリ導入 (`use-composition-input` 等)**: バンドルサイズコストが変更規模に対して過剰

### リスク
- Safari は `compositionend` の後に `keydown` を発火するため `isComposing` が `false` になる場合がある。ただしこの場合 Safari では元から問題が発生しにくいため、実際の影響は限定的。修正後に Safari での動作確認を推奨。

## 議論サマリー

### 合意点
- PM・アーキテクトともに `InputArea.tsx` L41 の `handleKeyDown` に IME composing ガードがないことが原因と特定
- 修正は `nativeEvent.isComposing` の1行チェックで完結する点で完全一致
- `compositionstart/end + useRef` 方式は冗長として却下する点も一致
- 優先度 high で一致

### 裁定
両者の分析が完全に合致しているため、論点なし。最小修正方針を採用。PMが提案した「JSDocコメント更新」サブタスクは独立タスクにするほどではなく、コード変更時に併せて更新すればよいため削除。

## 設計判断

- **採用**: `nativeEvent.isComposing` のインラインチェック — 最小変更、標準的なReact IME対応パターン、依存追加なし
- **却下**: `compositionstart/end` イベントハンドラ + `useRef` — 同じ効果を冗長に実現するだけ
- **却下**: IME 入力ライブラリの導入 — 問題の規模に対してオーバーキル

## タスク

- [ ] `InputArea.tsx` の `handleKeyDown` に `e.nativeEvent.isComposing` ガードを追加
- [ ] IME シナリオのユニットテストを追加

## 各タスクの詳細

### サブタスク1: `InputArea.tsx` の `handleKeyDown` に IME ガードを追加

- **目的**: IME composition 中の Enter キーでメッセージが送信されないようにする
- **やること**: L41 の条件 `e.key === "Enter" && !e.shiftKey` を `e.key === "Enter" && !e.shiftKey && !e.nativeEvent.isComposing` に変更
- **技術的ポイント**: 難易度 S。1行の条件追加のみ。TypeScript 型 `React.KeyboardEvent<HTMLTextAreaElement>` の `nativeEvent` は `isComposing: boolean` を持つため型変更不要
- **対象ファイル**: `widget/src/components/InputArea.tsx` L41
- **前提/依存**: なし
- **完了条件**: IME on で Enter 押下時に `handleSend` が呼ばれないこと

### サブタスク2: IME シナリオのユニットテストを追加

- **目的**: 修正の正しさを検証し、リグレッションを防ぐ
- **やること**: 以下3ケースのテストを作成
  1. `isComposing: true` の KeyboardEvent で `onSend` が呼ばれないこと
  2. `isComposing: false` の通常 Enter で `onSend` が呼ばれること
  3. Shift+Enter で `onSend` が呼ばれないこと（既存挙動の確認）
- **技術的ポイント**: テスト環境で `CompositionEvent` / `KeyboardEvent` の `isComposing` プロパティをシミュレートする方法を確認すること
- **対象ファイル**: `widget/src/__tests__/` 配下に新規テストファイル、または既存テストに追加
- **前提/依存**: サブタスク1の修正が完了していること
- **完了条件**: 全テストが pass すること

## 前提条件・依存関係

- React v17 以降であること（`nativeEvent.isComposing` の一貫した動作に必要）
- サブタスク1 → サブタスク2 の順序依存

## 補足

- Safari での `compositionend` → `keydown` 発火順序の差異は、Safari ではそもそも問題が発生しにくいことを意味する。修正は Chrome/Firefox での体験改善が主目的。
- MultiAgentOrchestrator / SingleReactOrchestrator のどちらを使用していても影響するフロントエンドのみの問題。

## PM 判断ログ

最初にアイデアを読んで感じたのは、2つのバグは独立性が高く、影響範囲・修正コストともに非対称だということだ。バグ1（IME Enter問題）は `InputArea.tsx` の `handleKeyDown` に数行加えるだけで完結する、フロントエンド単独の問題で、ユーザーが日本語を使う環境では毎回踏む致命的な操作性バグだ。

コードを実際に読んで確認したところ、ユーザーの分析通り。`compositionstart/compositionend` のハンドリングが一切ない。ただし注目すべきは、React には `e.nativeEvent.isComposing` という標準プロパティがあり、`event.nativeEvent.isComposing` を見る方式が最もシンプルで確実な修正策になる。`useRef` でフラグを持つ方式も動くが、`isComposing` で1行で済む。

優先度については、日本語ユーザー全員が毎回踏む問題なので high。修正コストが極めて低い（1行の条件追加）にもかかわらず、放置するとチャットの基本機能が日本語環境で機能しているとみなせない。

## アーキテクト技術調査メモ

`InputArea.tsx` L39-47 は `e.key === "Enter" && !e.shiftKey` のみ。`nativeEvent.isComposing` や composition イベントの参照なし。

IME を使う入力フローでは、ブラウザが `compositionstart` → `keydown(Enter)` → `compositionend` という順序でイベントを発火させる。現状コードは `keydown` 時点で `e.nativeEvent.isComposing` を確認しないため、IME の確定操作（Enter）と送信操作（Enter）を区別できない。

重要な仕様差異: Chrome は `isComposing: true` のまま `keydown` を発火するが、Safari は `compositionend` の後に `keydown` を発火する実装差がある。ただし React 合成イベントの `nativeEvent.isComposing` は Chrome/Firefox/Safari ともに一貫して動作する（React v17以降で改善済み）。

`textarea` の `onChange` (`handleInput`) は `compositionstart/end` を意識せずに正しく動作している（value の更新自体は問題ない）。問題は `onKeyDown` ハンドラのみに局所化されている。

比較検討:
- 案A（採用）: `nativeEvent.isComposing` のインライン確認。1行変更、React の標準的なIME対応パターン。依存追加なし。
- 案B（却下）: `compositionstart/compositionend` イベントで `isComposing` state を管理する。`useRef<boolean>` を追加してフラグ管理する。効果は案Aと同じだが、コードが複雑になり冗長。
- 案C（却下）: ライブラリ導入。バンドルサイズコストが変更箇所の規模に対して過剰。

## Critic 議論ログ

バグ1について、PM とアーキテクトの見解は完全に一致している。原因（`handleKeyDown` に IME ガードなし）、修正方針（`nativeEvent.isComposing` チェック追加）、優先度（high）、却下案（`useRef` 方式、ライブラリ導入）のすべてで合意が取れた。

PMのサブタスク案に含まれていた「JSDocコメント更新」は独立サブタスクにするほどの粒度ではなく、コード変更時に併せて行えばよいと判断して削除した。YAGNI の観点からサブタスク数を最小に絞った。

品質チェック: スコープは1ファイル1行の変更 + テストであり、1タスクファイルに収まる適切なサイズ。サブタスクは2つで、大きすぎず小さすぎない。過剰な分解にはなっていない。
