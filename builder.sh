#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

case "${1:-help}" in
  build)
    docker compose build chromium-builder
    ;;
  start)
    docker compose up -d chromium-builder
    ;;
  shell)
    docker compose exec chromium-builder bash
    ;;
  exec)
    shift
    docker compose exec chromium-builder "$@"
    ;;
  stop)
    docker compose stop chromium-builder
    ;;
  status)
    docker compose ps
    docker system df
    df -h .
    ;;
  *)
    echo "Usage: $0 {build|start|shell|exec <command...>|stop|status}"
    ;;
esac
