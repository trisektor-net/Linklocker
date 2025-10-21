#!/bin/bash
# =============================================================================
# LinkLocker Git Auto Commit & Push Script
# Author: Leo
# Description:
#   Simplifies committing and pushing to GitHub from terminal or Android Studio.
# Usage:
#   bash tools/git_push.sh "commit message"
# =============================================================================

# Exit immediately if a command exits with a non-zero status
set -e

# Go to project root (one level up from tools/)
cd "$(dirname "$0")/.."

# Timestamp for logs
DATE=$(date +"%Y-%m-%d %H:%M:%S")

# Handle missing message
if [ -z "$1" ]; then
  MSG="Auto commit at $DATE"
else
  MSG="$1"
fi

# Git add, commit, and push sequence
echo "🔍 Checking Git status..."
git status

echo "🧩 Adding all changes..."
git add -A

echo "💬 Committing with message: \"$MSG\""
git commit -m "$MSG" || echo "⚠️ No changes to commit."

echo "🚀 Pushing to origin/main..."
git push origin main

echo "✅ Successfully pushed to GitHub at $DATE"
