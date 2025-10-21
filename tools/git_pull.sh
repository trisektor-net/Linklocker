#!/bin/bash
# =============================================================================
# LinkLocker Git Auto Pull Script
# Author: Leo
# Description:
#   Keeps your local project synced with GitHub.
#   Safely fetches, checks out main, and rebases to avoid conflicts.
# Usage:
#   bash tools/git_pull.sh
# =============================================================================

set -e

# Move to project root (one level up from tools/)
cd "$(dirname "$0")/.."

echo "🔄 Fetching latest changes from GitHub..."
git fetch origin

echo "🌿 Switching to main branch..."
git checkout main

echo "⬇️ Pulling latest commits and rebasing local changes..."
git pull --rebase origin main

echo "✅ Your local branch is up to date with GitHub."
