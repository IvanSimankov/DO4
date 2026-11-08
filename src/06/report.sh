#!/bin/bash

generate_report() {
    local logs_dir="$SCRIPT_DIR/../04/logs"
    local report="$SCRIPT_DIR/report.html"

    # Проверяем наличие файлов логов
    local logs=("$logs_dir"/nginx_*.log)

    if [[ ! -f "${logs[0]}" ]]; then
        echo "Ошибка: логи nginx не найдены."
        exit 1
    fi

    echo "Генерация отчёта GoAccess..."

    goaccess "${logs[@]}" \
        --log-format=COMBINED \
        --output="$report"
}