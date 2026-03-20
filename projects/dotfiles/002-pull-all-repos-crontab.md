---
title: "pull-all-repos スクリプト修正とcrontab設定"
date: 2026-03-21
project: dotfiles
tags: [git, cron, automation]
---

## 概要

pull-all-repos.sh のリポジトリ対象を `~/naoki/` 配下の全gitリポジトリに変更し、5分ごとに自動実行するcrontabを設定した。

## 作業内容

### スクリプト修正 (`naoki/scripts/pull-all-repos.sh`)

- **変更前**: `$HOME` 直下の4リポジトリをハードコードしていた（42Tokyo_environment, dgm-backend, dgm-frontend, obsidian-vault）
- **変更後**: `$HOME/naoki/` 配下を `find` で再帰的に `.git` ディレクトリを探索し、全リポジトリを自動検出する方式に変更

```bash
BASE_DIR="$HOME/naoki"
REPOS=()
while IFS= read -r gitdir; do
    REPOS+=("$(dirname "$gitdir")")
done < <(find "$BASE_DIR" -name .git -type d 2>/dev/null | sort)
```

### crontab設定

```
*/5 * * * * /bin/bash /home/naoki/naoki/scripts/pull-all-repos.sh --quiet
```

- 5分ごとに `--quiet` モードで実行
- ログは `~/.local/log/pull-all-repos.log` に出力

### 既存の問題

- `42Tokyo_environment` のリモートURL（`kesaito09/42Tokyo_environment.git`）がGitHub上で見つからない → スクリプトの対象外になったため解消

## 決定事項

- pull対象は `~/naoki/` 配下の全リポジトリとする（番号付きディレクトリに限定しない）
- リポジトリの追加・削除時にスクリプト修正は不要（自動検出）
