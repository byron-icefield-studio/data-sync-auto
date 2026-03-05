# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目用途

将本地目录挂载进 Docker 容器，容器定时检测文件变更并自动 commit/push 到 GitHub 仓库根路径。单向同步（只 push，不 pull），纯环境变量配置，无需配置文件。

## 文件结构

- `Dockerfile` — 基于 alpine:3.19，安装 git + rsync
- `.env.example` — 环境变量模板
- `scripts/entrypoint.sh` — 容器启动：验证 token、初始化 git、启动同步循环
- `scripts/sync.sh` — 核心同步：rsync → git add → commit → push

## 环境变量

| 变量 | 必填 | 默认值 | 说明 |
|------|------|--------|------|
| `GITHUB_TOKEN` | 是 | — | Personal Access Token（需要 Contents: write 权限） |
| `GITHUB_REPO` | 是 | — | `username/repo-name` 格式 |
| `SYNC_SOURCE` | | `/data/sync` | 容器内挂载路径，该目录内容同步到仓库根路径 |
| `GITHUB_BRANCH` | | `main` | 目标分支 |
| `SYNC_INTERVAL` | | `300` | 轮询间隔（秒） |
| `GIT_AUTHOR_NAME` | | `Auto Sync Bot` | commit 作者名 |
| `GIT_AUTHOR_EMAIL` | | `sync-bot@local` | commit 作者邮箱 |

## 构建

```bash
docker build -t data-sync-auto .
```

## 集成到已有 compose 文件

```yaml
services:
  data-sync:
    build: ./data-sync-auto
    environment:
      - GITHUB_TOKEN=${GITHUB_TOKEN}
      - GITHUB_REPO=username/repo-name
      - SYNC_SOURCE=/data/sync
      - SYNC_INTERVAL=300
    volumes:
      - /host/my-files:/data/sync:ro
      - repo_data:/repo
    restart: unless-stopped

volumes:
  repo_data:
```

## 关键行为

- 源目录以 `:ro` 只读挂载，容器不修改本地文件
- `/repo` 用 named volume 持久化，容器重建后 git 历史不丢失，无需重新初始化
- 无变更时不产生空 commit
- 首次 push 自动降级为 `--force`，之后使用 `--force-with-lease`
- push 失败只打印错误，不退出容器，下次轮询继续重试
