#!/usr/bin/env bash

MIN_FREE_KB=1048576

check_disk_space() {
    local needed_kb="${1:-0}" available_kb
    available_kb="$(LC_ALL=C df -Pk / | awk 'NR == 2 {print $4}')"
    [[ $available_kb =~ ^[0-9]+$ ]] || fail 'Не удалось определить свободное место в разделе /.'

    if ((available_kb <= MIN_FREE_KB + needed_kb + 16)); then
        printf 'Остановка: в разделе / осталось недостаточно места для безопасного продолжения (свободно %s KiB; лимит 1048576 KiB).\n' "$available_kb" >&2
        exit 0
    fi
}

log_created() {
    local type="$1" path="$2" log_file="$3" size='-'
    if [[ $type == FILE ]]; then
        size="$(stat -c '%s' -- "$path")"
    fi
    printf '%s\t%s\t%s\t%s\n' "$type" "$path" "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$size" >> "$log_file"
}

create_base_directory() {
    local base_dir="$1" log_file="$2" current="$1" index
    local -a missing=()

    while [[ ! -d $current ]]; do
        [[ ! -e $current && ! -L $current ]] || fail "Невозможно создать каталог: $current"
        missing+=("$current")
        current="$(dirname -- "$current")"
    done

    for ((index=${#missing[@]}-1; index >= 0; index--)); do
        check_disk_space 0
        mkdir -- "${missing[index]}" || fail "Не удалось создать каталог: ${missing[index]}"
        log_created DIR "${missing[index]}" "$log_file"
    done
}

generate_tree() {
    local current_dir="$1" date_tag="$2" log_file="$3"
    local folder_index file_index folder_path file_path

    for ((folder_index=0; folder_index < FOLDER_COUNT; folder_index++)); do
        check_disk_space 0
        folder_path="$(free_path "$current_dir" "$FOLDER_LETTERS" "$date_tag" '' "$folder_index")"
        mkdir -- "$folder_path" || fail "Не удалось создать каталог: $folder_path"
        log_created DIR "$folder_path" "$log_file"
        current_dir="$folder_path"

        for ((file_index=0; file_index < FILE_COUNT; file_index++)); do
            check_disk_space "$FILE_SIZE_KB"
            file_path="$(free_path "$current_dir" "$FILE_LETTERS" "$date_tag" ".$FILE_EXTENSION" "$file_index")"
            if ! dd if=/dev/zero of="$file_path" bs=1024 count="$FILE_SIZE_KB" status=none conv=excl; then
                fail "Не удалось записать файл: $file_path"
            fi
            log_created FILE "$file_path" "$log_file"
        done
    done
}
