#!/usr/bin/env bash

set -euo pipefail

subcommand="${1:-}"

case "${subcommand}" in
  api)
    shift || true
    exec uvicorn api.main:app \
      --host "${API_HOST:-0.0.0.0}" \
      --port "${API_PORT:-8000}" \
      "$@"
    ;;
  job)
    shift || true
    exec python process_audio.py "$@"
    ;;
  "")
    exec allin1 --help
    ;;
  *)
    exec allin1 "$@"
    ;;
esac

