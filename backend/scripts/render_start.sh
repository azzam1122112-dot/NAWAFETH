#!/usr/bin/env bash
set -euo pipefail

python manage.py migrate --noinput

PORT_VALUE="${PORT:-8000}"
exec daphne -b 0.0.0.0 -p "$PORT_VALUE" config.asgi:application
