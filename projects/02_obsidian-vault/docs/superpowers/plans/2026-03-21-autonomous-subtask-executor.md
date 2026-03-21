# Autonomous Subtask Executor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a system that autonomously executes Obsidian vault tasks tagged with `#autorun` through a brainstorming → planning → execution → verification → notification pipeline.

**Architecture:** A main orchestrator skill (`01-tasks-execute`) coordinates Discord notifications, 3-agent brainstorming, and three wrapper skills (`auto-writing-plans`, `auto-executing-plans`, `auto-verification`) that automate superpowers workflows. All components are Claude Code skills (SKILL.md files) except the notification helper (shell script).

**Tech Stack:** Claude Code skills (markdown), Bash (discord-notify.sh), Discord Webhook API

**Spec:** `docs/superpowers/specs/2026-03-21-autonomous-subtask-executor-design.md`

---

## File Structure

| File | Responsibility | Create/Modify |
|------|---------------|---------------|
| `~/naoki/02_obsidian-vault/scripts/discord-notify.sh` | Discord Webhook notification | Create |
| `~/.claude/skills/auto-writing-plans/SKILL.md` | Wrapper: auto-invoke writing-plans without interaction | Create |
| `~/.claude/skills/auto-executing-plans/SKILL.md` | Wrapper: auto-invoke executing-plans without interaction | Create |
| `~/.claude/skills/auto-verification/SKILL.md` | Wrapper: auto-invoke verification-before-completion | Create |
| `~/.claude/skills/01-tasks-execute/SKILL.md` | Main orchestrator: 12-step execution flow | Create |
| `~/.claude/skills/01-tasks/SKILL.md` | Router: add execute route | Modify |

---

### Task 1: Discord Notification Helper Script

**Files:**
- Create: `/Users/naoki/naoki/02_obsidian-vault/scripts/discord-notify.sh`

- [ ] **Step 1: Create the script**

```bash
#!/bin/bash
set -euo pipefail

if [ -z "${DISCORD_WEBHOOK_URL:-}" ]; then
    echo "Error: DISCORD_WEBHOOK_URL is not set" >&2
    exit 1
fi

if [ -z "${1:-}" ]; then
    echo "Usage: discord-notify.sh <message>" >&2
    exit 1
fi

MESSAGE="$1"

# Escape special JSON characters
MESSAGE=$(echo "$MESSAGE" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\n/\\n/g')

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Content-Type: application/json" \
    -d "{\"content\": \"${MESSAGE}\"}" \
    "$DISCORD_WEBHOOK_URL")

if [ "$HTTP_CODE" -lt 200 ] || [ "$HTTP_CODE" -ge 300 ]; then
    echo "Error: Discord webhook returned HTTP $HTTP_CODE" >&2
    exit 1
fi
```

- [ ] **Step 2: Make executable**

Run: `chmod +x /Users/naoki/naoki/02_obsidian-vault/scripts/discord-notify.sh`

- [ ] **Step 3: Test without webhook (verify error handling)**

Run: `unset DISCORD_WEBHOOK_URL && /Users/naoki/naoki/02_obsidian-vault/scripts/discord-notify.sh "test" 2>&1`
Expected: `Error: DISCORD_WEBHOOK_URL is not set` and exit code 1

Run: `DISCORD_WEBHOOK_URL=http://example.com /Users/naoki/naoki/02_obsidian-vault/scripts/discord-notify.sh 2>&1`
Expected: `Usage: discord-notify.sh <message>` and exit code 1

- [ ] **Step 4: Commit**

```bash
cd /Users/naoki/naoki/02_obsidian-vault
git add scripts/discord-notify.sh
git commit -m "feat(_global): add discord-notify.sh webhook helper"
```

---

### Task 2: auto-writing-plans Wrapper Skill

**Files:**
- Create: `/Users/naoki/.claude/skills/auto-writing-plans/SKILL.md`

- [ ] **Step 1: Create skill directory**

Run: `mkdir -p /Users/naoki/.claude/skills/auto-writing-plans`

- [ ] **Step 2: Write SKILL.md**

```markdown
---
name: auto-writing-plans
description: Autonomously generate implementation plans from a brainstorming output without user interaction. Used by 01-tasks-execute for automated task processing.
---

# Auto Writing Plans

superpowers:writing-plans を自律的に実行するラッパースキル。ユーザー対話なしで実装計画を生成する。

## Trigger

01-tasks-execute から呼び出される。直接ユーザーが使うことは想定しない。

## Input

このスキルは以下のコンテキストが提供された状態で呼び出される:

- **brainstorming_log**: PM の要件定義 + アーキテクトの技術設計 + 批評家のレビュー（承認済み）
- **task_file_path**: タスクファイルのパス
- **repo_path**: 対象リポジトリのパス

## Steps

1. brainstorming_log をスペックとして解釈する（PM の要件定義 = 要件、アーキテクトの技術設計 = 設計、批評家のレビュー = 制約・注意点）

2. Skill tool で `superpowers:writing-plans` を呼び出す:
   - スペックとして brainstorming_log の内容を渡す
   - 対話的な質問が発生した場合は、brainstorming_log の内容から回答を推論する
   - 推論できない場合は BLOCKED を返す

3. 計画ファイルが `docs/superpowers/plans/YYYY-MM-DD-<feature-name>.md` に生成されたことを確認

4. 生成された計画ファイルのパスを返す

## Output

- **成功**: 計画ファイルのパス（例: `docs/superpowers/plans/2026-03-21-feature-x.md`）
- **失敗**: BLOCKED + 理由

## Notes

- writing-plans の「Execution Handoff」ステップはスキップする（01-tasks-execute が制御する）
- Plan review loop は通常通り実行する（品質を担保）
```

- [ ] **Step 3: Verify skill file exists and is well-formed**

Run: `cat /Users/naoki/.claude/skills/auto-writing-plans/SKILL.md | head -5`
Expected: frontmatter with `name: auto-writing-plans`

- [ ] **Step 4: Commit**

```bash
cd /Users/naoki/naoki/02_obsidian-vault
# Skills are outside vault repo, no git commit needed here
```

Note: スキルファイルは `~/.claude/skills/` にあり vault リポジトリ外。コミット不要。

---

### Task 3: auto-executing-plans Wrapper Skill

**Files:**
- Create: `/Users/naoki/.claude/skills/auto-executing-plans/SKILL.md`

- [ ] **Step 1: Create skill directory**

Run: `mkdir -p /Users/naoki/.claude/skills/auto-executing-plans`

- [ ] **Step 2: Write SKILL.md**

```markdown
---
name: auto-executing-plans
description: Autonomously execute an implementation plan without user interaction. Used by 01-tasks-execute for automated task processing.
---

# Auto Executing Plans

superpowers:executing-plans を自律的に実行するラッパースキル。ユーザー対話なしで計画を逐次実行する。

## Trigger

01-tasks-execute から呼び出される。直接ユーザーが使うことは想定しない。

## Input

このスキルは以下のコンテキストが提供された状態で呼び出される:

- **plan_file_path**: 実装計画ファイルのパス
- **repo_path**: 対象リポジトリのパス（ブランチ作成済み）
- **subtask_description**: 現在実行中のサブタスクの説明

## Steps

1. 計画ファイルを読み込み、現在のサブタスクに該当するステップを特定する

2. Skill tool で `superpowers:executing-plans` を呼び出す:
   - 計画ファイルパスを渡す
   - 該当するサブタスクのステップのみを実行する
   - 対話的な確認が必要な場面ではスキップして続行する（ブロッカーでない場合）
   - ブロッカーに遭遇した場合は BLOCKED を返す

3. 各ステップ完了後、git commit する（計画のコミットメッセージに従う）

## Timeout

- 30分のウォールクロックタイムアウト
- 超過時: 現在の作業を中断し、TIMEOUT を返す
- 中断時もそれまでのコミットは保持する

## Output

- **成功**: DONE + 変更サマリ（ファイル一覧、コミットハッシュ）
- **失敗**: BLOCKED + 理由 / TIMEOUT + 最後に完了したステップ

## Notes

- executing-plans の「finishing-a-development-branch」はスキップする（01-tasks-execute が全サブタスク完了後に制御）
- main ブランチへの直接コミットは禁止。常にブランチ上で作業する
```

- [ ] **Step 3: Verify skill file exists**

Run: `cat /Users/naoki/.claude/skills/auto-executing-plans/SKILL.md | head -5`
Expected: frontmatter with `name: auto-executing-plans`

---

### Task 4: auto-verification Wrapper Skill

**Files:**
- Create: `/Users/naoki/.claude/skills/auto-verification/SKILL.md`

- [ ] **Step 1: Create skill directory**

Run: `mkdir -p /Users/naoki/.claude/skills/auto-verification`

- [ ] **Step 2: Write SKILL.md**

```markdown
---
name: auto-verification
description: Autonomously verify implementation results by running tests and collecting evidence. Used by 01-tasks-execute for automated task processing.
---

# Auto Verification

superpowers:verification-before-completion を自律的に実行するラッパースキル。実装結果を検証し、証拠を収集する。

## Trigger

01-tasks-execute から呼び出される。直接ユーザーが使うことは想定しない。

## Input

このスキルは以下のコンテキストが提供された状態で呼び出される:

- **repo_path**: 対象リポジトリのパス
- **subtask_description**: 検証対象のサブタスクの説明
- **plan_step**: 計画ファイルの該当ステップ（期待される成果物・テスト）

## Steps

1. plan_step から検証すべき項目を特定:
   - テストコマンド（`pytest`, `npm test`, etc.）
   - ファイル存在確認
   - コマンド出力確認

2. 各検証項目を実行:
   - コマンドを実行し、stdout/stderr をキャプチャ
   - 末尾100行以内に切り詰める
   - pass/fail を判定

3. 結果を構造化して返す

## Output Schema

```yaml
status: pass | fail
evidence:
  - command: "実行したコマンド"
    output: "コマンド出力（末尾100行以内）"
    result: pass | fail
summary: "検証結果の要約（1-2文）"
```

## Verification Rules

- **Evidence before claims**: 全ての検証は実際にコマンドを実行して確認する。推測・仮定で pass にしない
- **Fresh execution**: キャッシュされた結果は使わない。毎回フレッシュに実行する
- **Full output reading**: コマンド出力を最後まで読む。途中で打ち切って pass にしない
- テストがない場合（SKILL.md のみの変更など）: ファイル存在確認 + frontmatter 形式確認を証拠とする

## Failure Handling

- 1つでも fail があれば全体を fail とする
- summary に失敗した検証項目を明記する
```

- [ ] **Step 3: Verify skill file exists**

Run: `cat /Users/naoki/.claude/skills/auto-verification/SKILL.md | head -5`
Expected: frontmatter with `name: auto-verification`

---

### Task 5: 01-tasks-execute Skill — Skeleton

**Files:**
- Create: `/Users/naoki/.claude/skills/01-tasks-execute/SKILL.md`

- [ ] **Step 1: Create skill directory**

Run: `mkdir -p /Users/naoki/.claude/skills/01-tasks-execute`

- [ ] **Step 2: Write SKILL.md skeleton (frontmatter + overview + task selection logic)**

```markdown
---
name: 01-tasks-execute
description: Autonomously execute vault tasks tagged with autorun. Triggers on "タスク実行", "自律実行", "autorun", "execute tasks", "タスクを実行して".
---

# Execute Task

Obsidian vault (`/Users/naoki/naoki/02_obsidian-vault`) の `#autorun` タグ付きタスクを自律的に実行する。

## Overview

12ステップの実行フロー:
1. タスクスキャン → 2. 選定 → 3. 開始通知 → 4. ステータス更新 →
5. brainstorming → 6. ユーザー承認 → 7. 計画作成 → 8. ブランチ作成 →
9. サブタスクループ(実装→検証→進捗更新) → 10. 完了更新 → 11. 完了通知 →
12. エラー時エスカレーション

## Step 1-2: Task Selection

1. 最新化:
   ```bash
   cd /Users/naoki/naoki/02_obsidian-vault && git pull
   ```

2. タスクファイルをスキャン:
   ```bash
   find /Users/naoki/naoki/02_obsidian-vault/tasks -name "*.md" -not -name ".gitkeep"
   ```

3. 各ファイルの frontmatter を読み、以下の条件でフィルタ:
   - `tags` に `autorun` を含む
   - `status: todo`（`in_progress` はスキップ）

4. フィルタ結果を並べ替え:
   - priority: high=3, medium=2, low=1（降順）
   - 同優先度: date 昇順（古いものから）

5. 該当タスクがなければ「autorun 対象タスクはありません」と報告して終了

## Step 3-4: Start Notification & Status Update

6. 選定タスクの開始通知:
   ```bash
   /Users/naoki/naoki/02_obsidian-vault/scripts/discord-notify.sh "🚀 タスク開始: [{title}] (project: {project})"
   ```
   - 通知失敗時: stderr にログを出すが、タスク実行は継続する

7. タスクの `status` を `in_progress` に更新:
   - Skill tool で `01-tasks-update` を呼び出す
   - 対象ファイルパスと更新内容を指示する

## Step 5: Brainstorming (3-Agent Team)

8. 3つの Agent tool を順次実行:

### PM Agent (model: sonnet)
```
prompt: |
  あなたはPM（プロダクトマネージャー）です。
  以下のタスクについて、ユーザーの立場から要件を整理してください。

  ## タスクファイル
  {タスクファイル全文}

  ## プロジェクト構造
  {対象リポジトリの ls -la 出力、主要ファイル一覧}

  ## 出力フォーマット
  - 目的: このタスクで何を達成するか
  - スコープ: 何を作るか / 何を作らないか
  - 成功基準: 完了の条件
  - 制約条件: 技術的制約、時間制約など
```

### Architect Agent (model: sonnet)
```
prompt: |
  あなたはソフトウェアアーキテクトです。
  PM の要件に基づいて技術設計を行ってください。

  ## タスクファイル
  {タスクファイル全文}

  ## PM の要件定義
  {PM Agent の出力}

  ## 対象リポジトリ
  {repo パス、コードベース概要}

  ## 出力フォーマット
  - アプローチ: 2-3案を比較し、推奨案を明示
  - コンポーネント構成: ファイル構造と責務
  - 依存関係: 既存コードとの接点
  - リスク: 技術的リスクと対策
```

### Critic Agent (model: opus)
```
prompt: |
  あなたは批評家です。
  PM の要件とアーキテクトの設計をレビューしてください。

  ## タスクファイル
  {タスクファイル全文}

  ## PM の要件定義
  {PM Agent の出力}

  ## アーキテクトの技術設計
  {Architect Agent の出力}

  ## レビュー観点
  - 見落としている要件はないか
  - エッジケースの考慮漏れはないか
  - 過剰設計になっていないか（YAGNI 違反）
  - PM とアーキテクトの間に不整合はないか
  - 改善提案があれば具体的に示す
```

## Step 6: User Approval Gate

9. brainstorming の結果をユーザーに提示:

```markdown
## Brainstorming: {タスクタイトル}

### PM: 要件定義
{PM Agent の出力}

### アーキテクト: 技術設計
{Architect Agent の出力}

### 批評家: レビュー
{Critic Agent の出力}

---
承認しますか？ (承認 / 却下 / 修正依頼)
```

10. ユーザーの応答に基づいて分岐:
    - **承認**: Step 7 へ進む
    - **却下**: `status` を `todo` に戻す、`tags` から `autorun` を除去、Discord 通知（却下）、終了
    - **修正依頼**: ユーザーのフィードバックを追加コンテキストとして Step 5 を再実行（最大2回。超過時は `autorun` 除去 + Discord エスカレーション）

## Step 7: Plan Generation

11. Skill tool で `auto-writing-plans` を呼び出す:
    - brainstorming の会話ログ（PM + Architect + Critic の出力全文）を渡す
    - タスクファイルパスと repo パスを渡す
    - 返り値として計画ファイルパスを受け取る

## Step 8: Branch Creation

12. 対象リポジトリでブランチを作成:
    - `repo` は frontmatter の `repo` フィールド。省略時は `/Users/naoki/naoki/02_obsidian-vault`
    ```bash
    cd {repo_path}
    BRANCH="task/{id}-{slug}"
    if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
        BRANCH="task/{id}-{slug}-$(date +%Y%m%d%H%M%S)"
    fi
    git checkout -b "$BRANCH"
    ```

## Step 9: Subtask Loop (Execute → Verify → Update)

13. タスクファイルからトップレベルのチェックボックス（`- [ ]`）を抽出

14. 各サブタスクに対して以下を繰り返す:

    a. **実装**: Skill tool で `auto-executing-plans` を呼び出す
       - 計画ファイルパス、repo パス、サブタスク説明を渡す
       - BLOCKED / TIMEOUT が返った場合: Discord エスカレーション、`status` を `todo` に戻す、終了

    b. **検証**: Skill tool で `auto-verification` を呼び出す
       - repo パス、サブタスク説明、計画ステップを渡す
       - fail の場合: Discord エスカレーション、`status` を `todo` に戻す、ブランチ保持、終了

    c. **進捗更新**: Skill tool で `01-tasks-update` を呼び出す
       - 当該サブタスクのチェックボックスを `[x]` に更新

## Step 10-11: Completion

15. 全サブタスク完了後:
    - Skill tool で `01-tasks-update` を呼び出し、`status` を `done` に更新
    - Discord 完了通知:
      ```bash
      /Users/naoki/naoki/02_obsidian-vault/scripts/discord-notify.sh "✅ タスク完了: [{title}] branch: {branch_name}"
      ```

## Step 12: Error Handling (applies to any step)

任意のステップでエラーが発生した場合:
1. タスクの `status` を `todo` に戻す（Skill tool で `01-tasks-update`）
2. Discord エスカレーション通知:
   ```bash
   /Users/naoki/naoki/02_obsidian-vault/scripts/discord-notify.sh "❌ タスク失敗: [{title}] ステップ{N}でエラー: {error_summary}"
   ```
3. ブランチが作成済みの場合は保持する（デバッグ用）
4. 処理を終了する
```

- [ ] **Step 3: Verify skill file exists and frontmatter is correct**

Run: `cat /Users/naoki/.claude/skills/01-tasks-execute/SKILL.md | head -5`
Expected: frontmatter with `name: 01-tasks-execute`

---

### Task 6: 01-tasks Router Update

**Files:**
- Modify: `/Users/naoki/.claude/skills/01-tasks/SKILL.md`

- [ ] **Step 1: Add execute route to routing table**

In `/Users/naoki/.claude/skills/01-tasks/SKILL.md`, add to the routing table:

```markdown
| タスク実行・自律実行・autorun | 01-tasks-execute |
```

- [ ] **Step 2: Add to dot graph**

Add node and edge:
```
"01-tasks-execute" [shape=box];
"Determine intent" -> "01-tasks-execute" [label="実行・autorun"];
```

- [ ] **Step 3: Update description triggers**

Add to the frontmatter `description` field: `"タスク実行", "自律実行", "autorun", "execute"`

- [ ] **Step 4: Verify the updated file is well-formed**

Run: `cat /Users/naoki/.claude/skills/01-tasks/SKILL.md`
Expected: routing table has 7 rows (6 original + execute), dot graph has 7 destination nodes

---

### Task 7: Integration Verification

- [ ] **Step 1: Verify all skill directories exist**

Run: `ls -la /Users/naoki/.claude/skills/ | grep -E "(auto-|01-tasks-execute)"`
Expected: 4 directories: `auto-writing-plans`, `auto-executing-plans`, `auto-verification`, `01-tasks-execute`

- [ ] **Step 2: Verify all SKILL.md files have correct frontmatter**

Run for each:
```bash
for skill in auto-writing-plans auto-executing-plans auto-verification 01-tasks-execute; do
    echo "=== $skill ==="
    head -4 /Users/naoki/.claude/skills/$skill/SKILL.md
done
```
Expected: each shows `---` / `name:` / `description:` / `---`

- [ ] **Step 3: Verify discord-notify.sh is executable**

Run: `test -x /Users/naoki/naoki/02_obsidian-vault/scripts/discord-notify.sh && echo "OK"`
Expected: `OK`

- [ ] **Step 4: Verify router has all routes**

Run: `grep -c "01-tasks-" /Users/naoki/.claude/skills/01-tasks/SKILL.md`
Expected: at least 7 occurrences (6 original sub-skills + execute)

- [ ] **Step 5: Dry run — scan for autorun tasks (should find none currently)**

Run: `grep -rl "autorun" /Users/naoki/naoki/02_obsidian-vault/tasks/ 2>/dev/null || echo "No autorun tasks found"`
Expected: `No autorun tasks found` (no tasks are tagged yet)

- [ ] **Step 6: Commit discord-notify.sh and vault changes**

```bash
cd /Users/naoki/naoki/02_obsidian-vault
git add scripts/discord-notify.sh
git commit -m "feat(_global): add discord-notify.sh and autonomous executor integration"
```
