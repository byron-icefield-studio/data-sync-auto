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
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] No new changes."
else
    ADDED=$(git diff --cached --name-status | awk '$1=="A"{print $2}' | tr '\n' ' ' | sed 's/ $//')
    DELETED=$(git diff --cached --name-status | awk '$1=="D"{print $2}' | tr '\n' ' ' | sed 's/ $//')
    MODIFIED=$(git diff --cached --name-status | awk '$1=="M"{print $2}' | tr '\n' ' ' | sed 's/ $//')

    MSG="auto sync: $(date '+%Y-%m-%d %H:%M:%S')"
    [ -n "$ADDED" ]    && MSG="${MSG}$(printf '\n+ %s' "$ADDED")"
    [ -n "$DELETED" ]  && MSG="${MSG}$(printf '\n- %s' "$DELETED")"
    [ -n "$MODIFIED" ] && MSG="${MSG}$(printf '\n~ %s' "$MODIFIED")"

    git commit -m "$MSG"
fi

# 无论是否有新 commit，都尝试 push（补推上次失败遗留的 commit）
if git rev-parse "origin/${BRANCH}" >/dev/null 2>&1; then
    UNPUSHED=$(git log "origin/${BRANCH}..HEAD" --oneline | wc -l | tr -d ' ')
else
    # 远程跟踪引用不存在，检查本地是否有 commit 需要推送
    UNPUSHED=$(git log HEAD --oneline 2>/dev/null | wc -l | tr -d ' ')
fi

if [ "$UNPUSHED" -eq 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Already up to date."
    exit 0
fi

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
