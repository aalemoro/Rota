#!/usr/bin/env bash
#
# push_to_github.sh — create the GitHub repo and push Rota in one go.
#
# Run this from the project root on your Mac (where you're signed in to GitHub).
# It uses the GitHub CLI `gh` if available; otherwise it prints the manual
# git commands to run.
#
#   chmod +x scripts/push_to_github.sh
#   ./scripts/push_to_github.sh            # public repo named "Rota"
#   ./scripts/push_to_github.sh my-name Rota private
#
set -euo pipefail

USER_OR_ORG="${1:-}"          # optional: your GitHub username/org
REPO_NAME="${2:-Rota}"
VISIBILITY="${3:-public}"     # public | private

cd "$(dirname "$0")/.."

# --- ensure a git repo with a commit ---------------------------------------
if [ ! -d .git ]; then
  git init -b main
fi
git add -A
git commit -m "Rota — Liquid Glass iPod player + widget for Apple Music" || echo "Nothing new to commit."

# --- create + push ---------------------------------------------------------
if command -v gh >/dev/null 2>&1; then
  echo "▶︎ Creating GitHub repo with gh…"
  TARGET="${REPO_NAME}"
  [ -n "$USER_OR_ORG" ] && TARGET="${USER_OR_ORG}/${REPO_NAME}"
  gh repo create "$TARGET" --source=. --remote=origin --push --"$VISIBILITY" \
    --description "A Liquid Glass iPod for your Mac — Apple Music player + widget."
  echo "✅ Done. Opening the repo…"
  gh repo view "$TARGET" --web || true
else
  echo "⚠️  GitHub CLI (gh) not found."
  echo "Install it with:  brew install gh  &&  gh auth login"
  echo
  echo "…or create an empty repo on github.com and run:"
  echo "    git remote add origin https://github.com/<you>/${REPO_NAME}.git"
  echo "    git push -u origin main"
fi
