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
    git init -b "$BRANCH" "$REPO_DIR"
    git -C "$REPO_DIR" remote add origin "$REMOTE_URL"
    git -C "$REPO_DIR" config user.name "$AUTHOR_NAME"
    git -C "$REPO_DIR" config user.email "$AUTHOR_EMAIL"
    # 限制 pack-objects 内存，防止容器 OOM Killer (SIGKILL) 杀死进程
    # Limit pack-objects memory to avoid OOM Killer sending SIGKILL
    git -C "$REPO_DIR" config pack.windowMemory "64m"
    git -C "$REPO_DIR" config pack.packSizeLimit "64m"
    git -C "$REPO_DIR" config pack.threads "1"

    # 若远程分支已有数据，fetch 并接管历史，避免强推覆盖远程内容
    if git -C "$REPO_DIR" fetch origin "$BRANCH" 2>/dev/null; then
        echo "[INFO] Remote has existing data, resetting to origin/${BRANCH}..."
        git -C "$REPO_DIR" reset --hard "origin/${BRANCH}"
    else
        echo "[INFO] Remote branch not found, starting fresh."
        git -C "$REPO_DIR" commit --allow-empty -m "init"
    fi

else
    echo "[INFO] Reusing existing git repo."
    git -C "$REPO_DIR" remote set-url origin "$REMOTE_URL"
    git -C "$REPO_DIR" config user.name "$AUTHOR_NAME"
    git -C "$REPO_DIR" config user.email "$AUTHOR_EMAIL"
    # 限制 pack-objects 内存，防止容器 OOM Killer (SIGKILL) 杀死进程
    # Limit pack-objects memory to avoid OOM Killer sending SIGKILL
    git -C "$REPO_DIR" config pack.windowMemory "64m"
    git -C "$REPO_DIR" config pack.packSizeLimit "64m"
    git -C "$REPO_DIR" config pack.threads "1"
    # 历史遗留：.git 存在但无 commit（分支不存在），补创初始 commit
    if ! git -C "$REPO_DIR" rev-parse HEAD >/dev/null 2>&1; then
        echo "[INFO] No commits found, creating initial commit..."
        git -C "$REPO_DIR" commit --allow-empty -m "init"
    fi
fi

# 无论初始化还是复用，确保 .gitignore 存在（防止垃圾文件被提交）
if [ ! -f "${REPO_DIR}/.gitignore" ]; then
    echo "[INFO] Writing default .gitignore..."
    cat > "${REPO_DIR}/.gitignore" << 'EOF'
# macOS
.DS_Store
.AppleDouble
.LSOverride
._*
.Spotlight-V100
.Trashes

# Windows
Thumbs.db
ehthumbs.db
Desktop.ini
$RECYCLE.BIN/

# Linux
*~
.fuse_hidden*
.nfs*

# Editor & IDE
.history/
.vscode/
.idea/
*.swp
*.swo
EOF
fi

echo "[INFO] Starting sync loop (interval: ${INTERVAL}s, source: ${SOURCE})..."
while true; do
    /app/scripts/sync.sh "$SOURCE" "$REPO_DIR" "$BRANCH" || true
    sleep "$INTERVAL"
done
