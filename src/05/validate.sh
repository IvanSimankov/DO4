#!/usr/bin/env bash
validate_arguments() {
    if [[ $# -ne 1 || ! "$1" =~ ^[1-4]$ ]]; then
        printf 'Ошибка: запуск: ./main.sh {1|2|3|4}\n' >&2
        return 1
    fi
}
