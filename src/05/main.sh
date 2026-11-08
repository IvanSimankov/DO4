#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $# -ne 1 || ! "$1" =~ ^[1-4]$ ]]; then
    echo "Ошибка: ./main.sh {1|2|3|4}"
    exit 1
fi

shopt -s nullglob
logs=("$DIR"/../04/logs/nginx_*.log)

if (( ${#logs[@]} == 0 )); then
    echo "Ошибка: логи nginx не найдены"
    exit 1
fi

if [[ "$1" == 1 ]]; then
    awk -v mode="$1" -f "$DIR/analyze.awk" "${logs[@]}" |
        sort -s -t $'\t' -k1,1n | cut -f2-
else
    awk -v mode="$1" -f "$DIR/analyze.awk" "${logs[@]}"
fi
