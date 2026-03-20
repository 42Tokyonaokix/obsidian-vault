---
title: "dotfilesリポジトリの設計と初期セットアップ"
date: 2026-03-21
project: dotfiles
tags: [devenv, sync, claude-code]
---

## 概要

開発環境をデバイス間で同期するためのdotfilesリポジトリを設計・作成し、GitHubプライベートリポジトリとして公開した。

## 作業内容

### 背景・課題

- Claude Codeのカスタムスキル（`~/.claude/skills/`）やシェル設定を別デバイスでも使いたい
- `~/naoki/` にはHOMEディレクトリ全体が含まれるため丸ごとリポジトリ化は不適切
- スキルは `~/.claude/skills/`（真のHOME直下）、プロジェクトは `~/naoki/` 配下と2箇所に分散

### 設計判断

1. **dotfilesリポジトリ + セットアップスクリプト方式** を採用（丸ごと同期は断念）
2. **シンボリックリンク展開** — リポジトリ内のファイルを所定パスにリンク
3. **settings.json はテンプレート方式** — `__HOME__` プレースホルダを `sed` で置換してコピー（symlinkだとgitが汚れるため）
4. **repos.txt (TSV)** — YAMLパーサ不要なシンプル形式でプロジェクトクローン先を管理
5. **プライベートリポジトリ** — 機密情報の心配なく全設定を含められる

### 成果物

- リポジトリ: `https://github.com/42Tokyonaokix/dotfiles`（private）
- 含まれるもの:
  - Claude Code スキル6つ（タスク管理、Obsidian連携）
  - Claude Code settings.json テンプレート
  - ステータスラインスクリプト
  - `.zshrc`（Oh My Zsh + Powerlevel10k）
  - `.p10k.zsh`
  - `setup.sh`（冪等セットアップスクリプト）
  - `repos.txt`（クローン対象リポジトリ一覧）

### setup.sh の機能

1. Oh My Zsh / Powerlevel10k / zshプラグイン / fzf の自動インストール
2. シンボリックリンク展開（既存ファイルはバックアップ）
3. settings.json テンプレート → 実ファイル生成
4. repos.txt からプロジェクトリポジトリをクローン
5. Claude Code プラグインインストール

## 決定事項

- スキル内のハードコードパス（`/Users/naoki/naoki/02_obsidian-vault`等）は今回は変更しない。将来の環境変数化リファクタで対応する
- VSCode設定はSettings Sync機能に委ねる（リポジトリに含めない）
- `.gemini/`, `.antigravity/` はランタイムデータが多いため同期対象外

## 次にやること

- スキルの抽象化リファクタ（ハードコードパスを環境変数化し、公開可能な形にする）
- 必要に応じてBrewfile追加
- DG/42-chatbot のリモートリポジトリ作成後、repos.txt に追加
