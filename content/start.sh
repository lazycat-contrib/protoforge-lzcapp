#!/bin/sh
# ProtoForge 容器启动脚本（替代镜像默认的 `alembic upgrade head && python -m protoforge.cli run`）
#
# 为什么要单独写脚本：lzc-manifest.yml 的 command 只接受字符串，无法直接表达 `&&`，
# 所以把 shell 逻辑放进这里，manifest 里用 `command: sh /lzcapp/pkg/content/start.sh`。
#
# 与 docker-compose.simple.yml 的差异：把 run 改成 demo，
# demo 模式会自动创建示例设备/场景，并启动全部协议服务（否则协议端口不会监听）。

set -e
cd /app

# 迁移失败时终止启动，避免静默忽略导致数据不一致（与上游 Dockerfile 行为一致）
alembic upgrade head

exec python -m protoforge.cli demo
