# Writing Guide

このvaultにノートを書き込む・読み込む際のルール。

## ディレクトリ構造

- `projects/{project-name}/` — プロジェクト作業記録
- `projects/{project-name}/{sub-project}/` — サブプロジェクト（最大2階層）
- `knowledge/{category}/` — 汎用ナレッジ
- フォルダ名はケバブケース（例: `webapp-dev`, `python-tips`）
- 新しいフォルダは必要に応じて作成してよい

## ファイル命名

- `{NNN}-{slug}.md`（例: `001-initial-setup.md`）
- 対象フォルダ内の最大番号 + 1 で採番（3桁ゼロ埋め）
- 999件を超えたら4桁に移行（既存ファイルはリネームしない）

## テンプレート

### 作業記録（projects用）

````yaml
---
title: "タイトル"
date: YYYY-MM-DD
project: project-name
tags: []
---
````

セクション:
- `## 概要` — 必須。何をしたか1〜2行で。registry.mdに転記する
- `## 作業内容` — 具体的な作業の詳細
- `## 決定事項` — このセッションで決めたこと（あれば）
- `## 次にやること` — 引き継ぎ事項（あれば）

### 汎用ナレッジ（knowledge用）

````yaml
---
title: "タイトル"
date: YYYY-MM-DD
category: category-name
tags: []
---
````

セクション:
- `## 概要` — 必須。何についてのノートか1〜2行で。registry.mdに転記する
- `## 内容` — 本文

### 共通ルール

- frontmatterは必須（title, date, tags）
- tagsは空配列でもよいが、フィールド自体は省略しない
- 概要は必須（registry.mdに転記するため）

## 書き込み手順

1. このファイルを読む
2. `git pull` で最新化する
3. registry.md を読んで、対象フォルダの最新番号を確認する
4. ノートを作成する（テンプレートに従う）
5. registry.md に1行追加する
6. `scripts/write-and-push.sh "コミットメッセージ"` を実行する

## 読み込み手順

1. `git pull` で最新化する
2. registry.md を読んで対象ノートを特定する
3. 対象ノートを読む

## コミットメッセージ形式

- projects用: `docs({project-name}): {slug}`
  - 例: `docs(webapp-dev): auth-implementation`
- knowledge用: `docs(knowledge/{category}): {slug}`
  - 例: `docs(knowledge/python): asyncio-basics`

## registry.md の更新ルール

ノートを書いたら必ずregistry.mdにも1行追加する。

新しいフォルダを作った場合、registryにもセクションを追加する:

````markdown
### {folder-path}
| # | タイトル | 日付 | 概要 |
|---|---------|------|------|
| 001 | ノートタイトル | YYYY-MM-DD | 概要テキスト |
````
