#!/usr/bin/env bash

validate_arguments() {
    if (( $# != 0 )); then
        printf 'Ошибка: Part 4 не принимает аргументов.\n' >&2
        printf 'Использование: ./main.sh\n' >&2
        return 1
    fi

    local command_name
    for command_name in date shuf sort mktemp mv mkdir; do
        if ! command -v "$command_name" >/dev/null 2>&1; then
            printf 'Ошибка: команда "%s" не найдена.\n' "$command_name" >&2
            return 1
        fi
    done
}

prepare_output_dir() {
    local output_dir="$1"
    if ! mkdir -p -- "$output_dir"; then
        printf 'Ошибка: не удалось создать каталог логов: %s\n' "$output_dir" >&2
        return 1
    fi
    if [[ ! -d "$output_dir" || ! -w "$output_dir" ]]; then
        printf 'Ошибка: нет доступа для записи в каталог: %s\n' "$output_dir" >&2
        return 1
    fi
}
