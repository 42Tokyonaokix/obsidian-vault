#!/bin/bash
set -e

if [ -z "$1" ]; then
  echo "Usage: $0 <commit-message>"
  exit 1
fi

VAULT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$VAULT_DIR"

git add projects/ knowledge/ registry.md WRITING_GUIDE.md
git diff --cached --quiet && echo "No changes to commit" && exit 0
git commit -m "$1"
git pull --rebase
git push
