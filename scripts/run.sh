#!/bin/bash

set -e

APP_DIR="/opt/agent"
VENV="$APP_DIR/venv"

source $VENV/bin/activate

exec uvicorn agent.main:app \
  --host 127.0.0.1 \
  --port 9000 \
  --workers 1 \
  --log-level info \
  --access-log
