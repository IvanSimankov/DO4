#!/usr/bin/env bash
make_name() {
    local letters="$1" index="$2" name="$1" first="${1:0:1}" i

    while ((${#name} < 4)); do
        name="${first}${name}"
    done

    for ((i = 0; i < index; i++)); do
        name="${first}${name}"
    done
    printf '%s' "$name"
}

free_path() {
    local parent="$1" letters="$2" date_tag="$3" suffix="$4"
    local index="${5:-0}" candidate part

    while :; do
        part="$(make_name "$letters" "$index")"
        candidate="${parent}/${part}_${date_tag}${suffix}"

        if [[ ! -e $candidate && ! -L $candidate ]]; then
            printf '%s' "$candidate"
            return 0
        fi
        ((index += 1))
    done
}
