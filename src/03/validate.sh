#!/usr/bin/env bash

error() { printf 'Ошибка: %s\n' "$*" >&2; }

validate_main_args() {
  if (( $# != 1 )) || [[ ! "$1" =~ ^[123]$ ]]; then
    error 'нужен ровно один аргумент: 1, 2 или 3.'
    printf 'Пример: ./main.sh 1\n' >&2
    return 1
  fi
  MODE=$1
  if [[ "${S21_DRY_RUN:-0}" != 0 && "${S21_DRY_RUN:-0}" != 1 ]]; then
    error 'S21_DRY_RUN может быть только 0 или 1.'
    return 1
  fi
}

is_generated_dir_name() {
  [[ "$1" =~ ^[A-Za-z]{5,}_[0-9]{6}$ ]]
}
is_generated_file_name() {
  [[ "$1" =~ ^[A-Za-z]{5,}_[0-9]{6}\.[A-Za-z]{1,3}$ ]]
}

is_safe_path() {
  local path=$1
  [[ "$path" == /* && "$path" != / && "$path" != *bin* && "$path" != *sbin* ]] || return 1
  [[ "$path" != *$'\n'* && "$path" != *$'\t'* && "$path" != *$'\r'* ]] || return 1
  [[ "$path" != */../* && "$path" != */./* && "$path" != */../ && "$path" != */./ ]] || return 1
  [[ "$path" != *'//'* ]]
}

path_on_root_fs() {
  local path=$1 resolved device
  [[ ! -L "$path" ]] || return 1
  resolved=$(realpath -e -- "$path" 2>/dev/null) || return 1
  [[ "$resolved" == "$path" ]] || return 1
  device=$(stat -c %d -- "$path" 2>/dev/null) || return 1
  [[ "$device" == "$ROOT_DEVICE" ]]
}

configure_scan_root() {
  local requested=${S21_SCAN_ROOT:-/}
  [[ "$requested" == /* && -d "$requested" && ! -L "$requested" ]] || {
    error 'S21_SCAN_ROOT должен указывать на существующий абсолютный каталог.'; return 1;
  }
  SCAN_ROOT=$(realpath -e -- "$requested") || return 1
  if [[ "$SCAN_ROOT" != / ]] && ! is_safe_path "$SCAN_ROOT"; then
    error 'небезопасный путь сканирования (bin/sbin, управляющие символы или ..).'
    return 1
  fi
  [[ $(stat -c %d -- "$SCAN_ROOT") == "$ROOT_DEVICE" ]] || {
    error 'каталог сканирования расположен не на разделе /.'; return 1;
  }
}

ask_time_range() {
  local start end value
  printf 'Начало интервала (YYYY-MM-DD HH:MM): '
  IFS= read -r start || { error 'не введено время начала.'; return 1; }
  printf 'Конец интервала (YYYY-MM-DD HH:MM): '
  IFS= read -r end || { error 'не введено время окончания.'; return 1; }
  for value in "$start" "$end"; do
    [[ "$value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}$ ]] || {
      error 'время нужно вводить строго как 2026-10-13 19:45.'; return 1;
    }
    [[ $(date -d "$value" +'%Y-%m-%d %H:%M' 2>/dev/null) == "$value" ]] || {
      error "несуществующая дата или время: $value"; return 1;
    }
  done
  FROM_EPOCH=$(date -d "$start" +%s)
  TO_EPOCH=$(($(date -d "$end" +%s) + 60))
  (( FROM_EPOCH < TO_EPOCH )) || { error 'конец раньше начала.'; return 1; }
  printf 'Интервал: [%s, %s] (включая обе минуты)\n' "$start" "$end"
}

ask_mask() {
  local dir_letters file_spec date_str dd mm yy
  printf 'Буквы каталогов из Part 2 (например, az): '
  IFS= read -r dir_letters || return 1
  printf 'Имя.расширение из Part 2 (например, az.az): '
  IFS= read -r file_spec || return 1
  printf 'Дата имён DDMMYY (например, 131026): '
  IFS= read -r date_str || return 1
  [[ "$dir_letters" =~ ^[A-Za-z]{1,7}$ ]] || { error 'буквы папок: 1–7 латинских букв.'; return 1; }
  [[ "$file_spec" =~ ^([A-Za-z]{1,7})\.([A-Za-z]{1,3})$ ]] || {
    error 'ожидалось имя.расширение (1–7 и 1–3 латинских букв).'; return 1;
  }
  MASK_DIR_LETTERS=$dir_letters
  MASK_FILE_LETTERS=${BASH_REMATCH[1]}
  MASK_EXT=${BASH_REMATCH[2]}
  [[ "$date_str" =~ ^[0-9]{6}$ ]] || { error 'дата должна иметь формат DDMMYY.'; return 1; }
  dd=${date_str:0:2}; mm=${date_str:2:2}; yy=${date_str:4:2}
  [[ $(date -d "20${yy}-${mm}-${dd}" +%d%m%y 2>/dev/null) == "$date_str" ]] || {
    error 'несуществующая дата.'; return 1;
  }
  MASK_DATE=$date_str
}
