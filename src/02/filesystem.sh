#!/usr/bin/env bash

readonly GIB=$((1024 * 1024 * 1024))
readonly METADATA_RESERVE=$((4 * 1024 * 1024))
declare -a BASE_DIRS=()
CREATED_DIRS=0
CREATED_FILES=0
STOP_REASON=''
NEW_DIR=''

add_base_if_usable() {
  local requested=$1 path root_device path_device existing
  [[ -d "$requested" && -w "$requested" && -x "$requested" ]] || return 0
  path=$(realpath -e -- "$requested") || return 0

  [[ "$path" == *bin* || "$path" == *sbin* ]] && return 0
  [[ "$path" == / ]] && return 0

  root_device=$(df -P / | awk 'NR == 2 {print $1}')
  path_device=$(df -P -- "$path" | awk 'NR == 2 {print $1}')
  [[ -n "$root_device" && "$root_device" == "$path_device" ]] || return 0

  for existing in "${BASE_DIRS[@]}"; do
    [[ "$existing" == "$path" ]] && return 0
  done
  BASE_DIRS+=("$path")
}

collect_bases() {
  if [[ -n "${S21_TEST_BASE_DIR:-}" ]]; then
    add_base_if_usable "$S21_TEST_BASE_DIR"
  else
    add_base_if_usable "$HOME"
    add_base_if_usable /tmp
    add_base_if_usable /var/tmp
    add_base_if_usable "$HOME/Documents"
    add_base_if_usable "$HOME/Загрузки"
    add_base_if_usable /opt
    add_base_if_usable /mnt
    add_base_if_usable /srv
  fi

  if (( ${#BASE_DIRS[@]} == 0 )); then
    printf 'Ошибка: на разделе / не найдено подходящих каталогов для записи.\n' >&2
    return 1
  fi
}

available_root_bytes() {
  local human bytes
  human=$(df -h /) || return 1
  bytes=$(df -B1 --output=avail / | awk 'NR == 2 {print $1}') || return 1
  if [[ ! "$bytes" =~ ^[0-9]+$ ]]; then
    printf 'Ошибка: не удалось прочитать свободное место из df.\n' >&2
    return 1
  fi
  printf '%s\n' "$bytes"
}

can_create_file() {
  local available
  available=$(available_root_bytes) || return 2
  if (( available <= GIB + SIZE_BYTES + METADATA_RESERVE )); then
    STOP_REASON="Достигнут предел: осталось недостаточно места для следующего файла без нарушения резерва 1 ГБ."
    return 1
  fi
}

log_directory() {
  printf 'DIR\t%s\t%s\t-\n' "$1" "$(date +%Y-%m-%dT%H:%M:%S%z)" >> "$LOG_FILE"
  ((CREATED_DIRS += 1))
}

log_file() {
  local size
  size=$(stat -c %s -- "$1")
  printf 'FILE\t%s\t%s\t%s\n' "$1" "$(date +%Y-%m-%dT%H:%M:%S%z)" "$size" >> "$LOG_FILE"
  ((CREATED_FILES += 1))
}

create_unique_root() {
  local base=$1 extra=0 stem candidate
  while :; do
    stem=$(make_stem "$DIR_LETTERS" 5 "$extra")
    candidate="$base/${stem}_${RUN_DATE}"
    if [[ ! -e "$candidate" && ! -L "$candidate" ]]; then
      if mkdir -- "$candidate"; then
        log_directory "$candidate"
        NEW_DIR=$candidate
        return 0
      fi
      return 1
    fi
    ((extra += 1))
    if (( extra > 200 )); then
      printf 'Ошибка: слишком много совпадающих имён в %s.\n' "$base" >&2
      return 1
    fi
  done
}

create_nested_dir() {
  local parent=$1 stem candidate
  stem=$(make_stem "$DIR_LETTERS" 5 0)
  candidate="$parent/${stem}_${RUN_DATE}"
  if (( ${#candidate} > 3800 )); then
    printf 'Ошибка: путь к каталогу близок к системному пределу длины.\n' >&2
    return 1
  fi
  mkdir -- "$candidate" || return 1
  log_directory "$candidate"
  NEW_DIR=$candidate
}

create_files_in_dir() {
  local directory=$1 amount=$2 stem filename index
  for ((index = 0; index < amount; index++)); do
    if ! can_create_file; then
      return 1
    fi

    stem=$(make_stem "$FILE_LETTERS" 5 "$index")
    filename="$directory/${stem}_${RUN_DATE}.${FILE_EXTENSION}"
    # Do not overwrite an existing file, even when run repeatedly.
    if [[ -e "$filename" || -L "$filename" ]]; then
      printf 'Ошибка: файл уже существует: %s\n' "$filename" >&2
      return 2
    fi
    if ! dd if=/dev/zero of="$filename" bs=1M count="$SIZE_MB" \
      conv=excl status=none; then
      rm -f -- "$filename"
      printf 'Ошибка записи файла: %s\n' "$filename" >&2
      return 2
    fi
    log_file "$filename"

    if [[ -n "${S21_TEST_LIMIT:-}" ]] && (( CREATED_FILES >= 10#$S21_TEST_LIMIT )); then
      STOP_REASON="Тестовый предел: создано $CREATED_FILES файлов."
      return 1
    fi
  done
  return 0
}

generate_until_threshold() {
  local base current depth level count result

  while :; do
    if ! can_create_file; then
      break
    fi

    base=${BASE_DIRS[RANDOM % ${#BASE_DIRS[@]}]}
    depth=$((RANDOM % 100 + 1))
    create_unique_root "$base" || return 1
    current=$NEW_DIR
    count=$((RANDOM % 20 + 1))
    result=0
    create_files_in_dir "$current" "$count" || result=$?
    if (( result == 1 )); then break; fi
    if (( result != 0 )); then return "$result"; fi

    for ((level = 2; level <= depth; level++)); do
      if ! can_create_file; then
        return 0
      fi
      create_nested_dir "$current" || return 1
      current=$NEW_DIR
      count=$((RANDOM % 20 + 1))
      result=0
      create_files_in_dir "$current" "$count" || result=$?
      if (( result == 1 )); then return 0; fi
      if (( result != 0 )); then return "$result"; fi
    done

    if (( CREATED_DIRS % 50 == 0 )); then
      printf 'Создано каталогов: %d; файлов: %d\n' "$CREATED_DIRS" "$CREATED_FILES"
    fi
  done
}
