FROM alpine:3.19

# 安装同步所需工具与时区数据库，确保容器内时间正确
# Install sync tools and timezone database so container time stays correct
RUN apk add --no-cache git rsync tzdata

ENV TZ="Asia/Shanghai" \
    GITHUB_TOKEN="" \
    GITHUB_REPO="" \
    GITHUB_BRANCH="main" \
    SYNC_INTERVAL="300" \
    SYNC_SOURCE="/sync" \
    GIT_AUTHOR_NAME="Auto Sync Bot" \
    GIT_AUTHOR_EMAIL="sync-bot@local"

# 固定容器本地时区，供 date/git 等命令使用
# Pin local timezone for commands like date and git
RUN ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime \
 && echo "${TZ}" > /etc/timezone

WORKDIR /app
COPY scripts/ /app/scripts/
RUN chmod +x /app/scripts/entrypoint.sh /app/scripts/sync.sh

VOLUME /repo

ENTRYPOINT ["/app/scripts/entrypoint.sh"]
