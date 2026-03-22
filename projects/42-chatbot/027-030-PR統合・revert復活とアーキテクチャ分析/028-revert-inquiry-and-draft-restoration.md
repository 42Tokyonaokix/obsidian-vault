---
title: "問い合わせフォーム・Zendesk draft機能のrevert復活"
date: 2026-03-22
project: 42-chatbot
tags: [zendesk, inquiry, draft, revert, bugfix]
---

## 概要

スコープ外として差し戻されていた問い合わせフォームのカテゴリ選択UI・LLMドラフト生成・Zendesk draftエンドポイントを復活させた。

## 作業内容

### 問題

- カテゴリ選択画面がフロントエンドに表示されない
- Zendesk会話サマリの要約機能が動作しない

### 原因

以下の2つのrevertコミットで、計5コミット分（636行）の機能が差し戻されていた:

| revertコミット | 元コミット | 内容 |
|---------------|-----------|------|
| `b550eb6` | `9699702` | `dicts_to_messages` ヘルパー + summary パーサーテスト |
| | `eedb42d` | `generate_structured_summary` に category パラメータ追加 |
| | `ea71404` | `POST /api/v1/zendesk/draft` エンドポイント + テスト217行 |
| `7fffe8d` | `defdd20` | widget → inquiry URL に `thread_id` を渡す |
| | `b75cfb8` | inquiry ページにカテゴリ選択 + LLM ドラフト生成 UI |

revertの理由は「Task 013 / Task 4 のスコープ外」とされていた。

### 対応

2つのrevertコミットをさらにrevertして機能を復活:

```
652e0f4 Revert "revert: スコープ外の zendesk/summary 変更を差し戻し"  (+479行)
4d40868 Revert "revert: スコープ外の inquiry page 変更を差し戻し"    (+157行)
```

### 復活した機能

**バックエンド:**
- `POST /api/v1/zendesk/draft` エンドポイント
- `generate_structured_summary()` の category パラメータ対応
- `dicts_to_messages` ヘルパー関数
- `DraftRequest` / `DraftResponse` モデル
- テスト: `test_zendesk_draft.py` (217行), `test_summary_structured.py` (113行)

**フロントエンド:**
- inquiry ページのカテゴリ選択ドロップダウン
- LLM ドラフト生成ボタンと「生成中」状態管理
- widget から inquiry URL への `thread_id` パラメータ受け渡し

## 学び

- revertは「一時的にスコープ外」として行われたが、復活タイミングの記録がなかった
- 機能を差し戻す場合、復活条件を明記すべき
