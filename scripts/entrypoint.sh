#!/bin/sh
set -e

REPO_DIR="/repo"
REPO="${GITHUB_REPO}"
BRANCH="${GITHUB_BRANCH:-main}"
AUTHOR_NAME="${GIT_AUTHOR_NAME:-Auto Sync Bot}"
AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-sync-bot@local}"
INTERVAL="${SYNC_INTERVAL:-300}"
SOURCE="${SYNC_SOURCE:-/data/sync}"

if [ -z "$GITHUB_TOKEN" ]; then
    echo "[ERROR] GITHUB_TOKEN is required"
    exit 1
fi

if [ -z "$REPO" ]; then
    echo "[ERROR] GITHUB_REPO is required"
    exit 1
fi

REMOTE_URL="https://${GITHUB_TOKEN}@github.com/${REPO}.git"

echo "[INFO] Verifying access to ${REPO}..."
if ! git ls-remote "$REMOTE_URL" HEAD > /dev/null 2>&1; then
    echo "[ERROR] Cannot access ${REPO}. Check GITHUB_TOKEN and repo name."
    exit 1
fi
echo "[INFO] Access verified."

if [ ! -d "${REPO_DIR}/.git" ]; then
    echo "[INFO] Initializing git repo in ${REPO_DIR}..."
    git init "$REPO_DIR"
    git -C "$REPO_DIR" remote add origin "$REMOTE_URL"
else
    echo "[INFO] Reusing existing git repo."
    git -C "$REPO_DIR" remote set-url origin "$REMOTE_URL"
fi

git -C "$REPO_DIR" config user.name "$AUTHOR_NAME"
git -C "$REPO_DIR" config user.email "$AUTHOR_EMAIL"

echo "[INFO] Starting sync loop (interval: ${INTERVAL}s, source: ${SOURCE})..."
while true; do
    /app/scripts/sync.sh "$SOURCE" "$REPO_DIR" "$BRANCH" || true
    sleep "$INTERVAL"
done
