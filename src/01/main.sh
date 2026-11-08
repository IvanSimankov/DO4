#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/validate.sh"
source "$SCRIPT_DIR/names.sh"
source "$SCRIPT_DIR/filesystem.sh"

main() {
    validate_parameters "$@"

    local base_dir run_date log_file
    base_dir="$(realpath -m -- "$1")"
    run_date="$(date '+%d%m%y')"
    log_file="$SCRIPT_DIR/creation_$(date '+%Y%m%d_%H%M%S')_$$.log"

    printf 'TYPE\tFULL_PATH\tCREATED_AT\tSIZE_BYTES\n' > "$log_file"
    printf 'Лог: %s\n' "$log_file"

    create_base_directory "$base_dir" "$log_file"
    generate_tree "$base_dir" "$run_date" "$log_file"
    printf 'Готово. Данные о созданных объектах: %s\n' "$log_file"
}

main "$@"
