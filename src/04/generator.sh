#!/usr/bin/env bash

generate_day_log() {
    local iso_date="$1" index="$2" output_dir="$3"
    local log_day offset count second clock
    local -a sorted_seconds=()

    log_day="$(LC_TIME=C date -d "$iso_date 12:00:00" +%d/%b/%Y)"
    offset="$(date -d "$iso_date 12:00:00" +%z)"

    random_int 100 1000
    count="$REPLY"

    mapfile -t sorted_seconds < <(shuf -i 0-86399 -n "$count" | sort -n)
    if (( ${#sorted_seconds[@]} != count )); then
        printf 'Ошибка: не удалось сгенерировать временные метки.\n' >&2
        return 1
    fi

    CURRENT_TMP="$(mktemp "$output_dir/.nginx_${index}_XXXXXXXX")"

    {
        for second in "${sorted_seconds[@]}"; do
            printf -v clock '%02d:%02d:%02d' \
                "$((second / 3600))" \
                "$(((second % 3600) / 60))" \
                "$((second % 60))"
            print_log_entry "$log_day" "$clock" "$offset"
        done
    } > "$CURRENT_TMP"

    mv -f -- "$CURRENT_TMP" "$output_dir/nginx_${index}.log"
    CURRENT_TMP=""
    printf 'nginx_%d.log: %s, %d записей\n' "$index" "$iso_date" "$count"
}
