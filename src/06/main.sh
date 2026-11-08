#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/report.sh"

PORT=8000

for program in goaccess python3; do
    if ! command -v "$program" >/dev/null 2>&1; then
        echo "Ошибка: $program не установлен."
        exit 1
    fi
done

generate_report

echo "Отчёт готов!"
echo "Открой в браузере: http://127.0.0.1:$PORT/report.html"
echo "Для остановки сервера нажми Ctrl+C"

python3 -m http.server "$PORT" \
    --bind 0.0.0.0 \
    --directory "$SCRIPT_DIR"