#!/bin/bash
#
# Publishes the current tree to github.com/aalemoro/Rota (run on the Mac).
# Keeps the v1 history: the rewrite lands as one commit on top of it.
#
set -euo pipefail

REPO_DIR="${1:-$HOME/Developer/Rota}"
REMOTE="https://github.com/aalemoro/Rota.git"
MSG="${2:-Rota 2.0 — complete rewrite: floating desktop widget, Apple Events bridge, synced lyrics}"

cd "$REPO_DIR"

if [ ! -d .git ]; then
  git init -b main
  git remote add origin "$REMOTE" 2>/dev/null || git remote set-url origin "$REMOTE"
fi

# Local identity (only if not configured globally)
git config user.name  >/dev/null 2>&1 || git config user.name  "Alessandro Gaudio"
git config user.email >/dev/null 2>&1 || git config user.email "aalemoro@users.noreply.github.com"

git fetch origin main
git reset --soft origin/main

git add -A
git commit -m "$MSG" || echo "Nothing to commit."
git push origin main
echo "✅ pushed"
