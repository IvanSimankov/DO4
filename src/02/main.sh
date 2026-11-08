#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
source "$SCRIPT_DIR/names.sh"
source "$SCRIPT_DIR/validate.sh"
source "$SCRIPT_DIR/filesystem.sh"

validate_args "$@" || exit 1
collect_bases || exit 1

RUN_DATE=$(date +%d%m%y)
START_EPOCH=$(date +%s)
START_TIME=$(date '+%Y-%m-%d %H:%M:%S %z')
LOG_FILE="$SCRIPT_DIR/creation_$(date +%Y%m%d_%H%M%S)_$$_$(date +%N).log"
printf 'TYPE\tFULL_PATH\tCREATED_AT\tSIZE_BYTES\n' > "$LOG_FILE"

finish() {
  local exit_status=$? end_epoch end_time duration formatted
  trap - EXIT
  end_epoch=$(date +%s)
  end_time=$(date '+%Y-%m-%d %H:%M:%S %z')
  duration=$((end_epoch - START_EPOCH))
  printf -v formatted '%02d:%02d:%02d' \
    "$((duration / 3600))" "$(((duration % 3600) / 60))" "$((duration % 60))"

  printf '\nНачало: %s\nОкончание: %s\nДлительность: %s\n' \
    "$START_TIME" "$end_time" "$formatted"
  printf 'Каталогов: %d; файлов: %d\n' "$CREATED_DIRS" "$CREATED_FILES"
  [[ -z "$STOP_REASON" ]] || printf 'Причина остановки: %s\n' "$STOP_REASON"
  printf 'Лог: %s\n' "$LOG_FILE"
  {
    printf 'META\tSTART_TIME\t%s\t-\n' "$START_TIME"
    printf 'META\tEND_TIME\t%s\t-\n' "$end_time"
    printf 'META\tDURATION\t%s\tseconds\n' "$duration"
    printf 'META\tSTOP_REASON\t%s\t-\n' "${STOP_REASON:-finished_or_interrupted}"
    printf 'META\tEXIT_STATUS\t%s\t-\n' "$exit_status"
  } >> "$LOG_FILE" || true
  exit "$exit_status"
}
trap finish EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

printf 'Начало работы: %s\n' "$START_TIME"
printf 'Размер файлов: %s МБ; места: %s\n' "$SIZE_MB" "${BASE_DIRS[*]}"
printf 'ВНИМАНИЕ: обычный запуск заполняет раздел / почти до 1 ГБ свободного места.\n'
if [[ -n "${S21_TEST_LIMIT:-}" ]]; then
  printf 'ТЕСТ: остановка после %s файлов.\n' "$S21_TEST_LIMIT"
fi

generate_until_threshold
