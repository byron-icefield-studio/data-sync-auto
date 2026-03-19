FROM alpine:3.19

RUN apk add --no-cache git rsync

ENV GITHUB_TOKEN="" \
    GITHUB_REPO="" \
    GITHUB_BRANCH="main" \
    SYNC_INTERVAL="300" \
    SYNC_SOURCE="/sync" \
    GIT_AUTHOR_NAME="Auto Sync Bot" \
    GIT_AUTHOR_EMAIL="sync-bot@local"

WORKDIR /app
COPY scripts/ /app/scripts/
RUN chmod +x /app/scripts/entrypoint.sh /app/scripts/sync.sh

VOLUME /repo

ENTRYPOINT ["/app/scripts/entrypoint.sh"]
