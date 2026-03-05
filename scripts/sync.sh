#!/bin/sh
# Usage: sync.sh <source> <repo_dir> <branch>

SOURCE="${1:-/data/sync}"
REPO_DIR="${2:-/repo}"
BRANCH="${3:-main}"

if [ ! -d "$SOURCE" ]; then
    echo "[WARN] Source directory ${SOURCE} does not exist, skipping."
    exit 0
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Syncing ${SOURCE} -> ${REPO_DIR}..."

rsync -a --delete --exclude='.git' "${SOURCE}/" "${REPO_DIR}/"

cd "$REPO_DIR"
git add -A

if git diff --cached --quiet; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] No changes, skip commit."
    exit 0
fi

CHANGED=$(git diff --cached --name-only | wc -l | tr -d ' ')
git commit -m "auto sync: $(date '+%Y-%m-%d %H:%M:%S') (${CHANGED} file(s) changed)"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Pushing to ${BRANCH}..."
if git push --force-with-lease origin "${BRANCH}" 2>&1; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Push succeeded."
else
    echo "[WARN] force-with-lease failed, retrying with --force..."
    if git push --force origin "${BRANCH}" 2>&1; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Push succeeded (forced)."
    else
        echo "[ERROR] Push failed. Will retry next cycle."
        exit 1
    fi
fi
