#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/validate.sh"
source "$SCRIPT_DIR/random.sh"
source "$SCRIPT_DIR/generator.sh"

CURRENT_TMP=""
trap 'if [[ -n "$CURRENT_TMP" ]]; then rm -f -- "$CURRENT_TMP"; fi' EXIT

main() {
    validate_arguments "$@"

    local output_dir="${S21_OUTPUT_DIR:-$SCRIPT_DIR/logs}"
    prepare_output_dir "$output_dir"

    local today day days_ago index
    today="$(date +%Y-%m-%d)"

    for ((index = 1; index <= 5; index++)); do
        days_ago=$((5 - index))
        day="$(date -d "$today - $days_ago days" +%Y-%m-%d)"
        generate_day_log "$day" "$index" "$output_dir"
    done

    printf 'Готово: 5 файлов формата nginx combined в %s\n' "$output_dir"
}

main "$@"
