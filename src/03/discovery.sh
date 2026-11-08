#!/usr/bin/env bash

declare -a FILES=() DIRS=()
declare -A SEEN_FILES=() SEEN_DIRS=() EXPECTED_SIZES=()

within_scope() {
  [[ "$SCAN_ROOT" == / || "$1" == "$SCAN_ROOT"/* ]]
}

add_file() {
  local path=$1
  [[ -n ${SEEN_FILES["$path"]+x} ]] && return 0
  SEEN_FILES["$path"]=1
  FILES+=("$path")
}

add_dir() {
  local path=$1
  [[ -n ${SEEN_DIRS["$path"]+x} ]] && return 0
  SEEN_DIRS["$path"]=1
  DIRS+=("$path")
}

stem_matches_part2() {
  local stem=$1 letters=$2 prefix
  (( ${#stem} >= 5 )) || return 1
  [[ "$stem" == *"$letters" ]] || return 1
  prefix=${stem%"$letters"}
  local first=${letters:0:1}
  [[ -z "${prefix//"$first"/}" ]]
}

mask_dir_matches() {
  local leaf=$1 stem
  [[ "$leaf" == *"_$MASK_DATE" ]] || return 1
  stem=${leaf%"_$MASK_DATE"}
  stem_matches_part2 "$stem" "$MASK_DIR_LETTERS"
}

mask_file_matches() {
  local leaf=$1 stem
  [[ "$leaf" == *"_$MASK_DATE.$MASK_EXT" ]] || return 1
  stem=${leaf%"_$MASK_DATE.$MASK_EXT"}
  stem_matches_part2 "$stem" "$MASK_FILE_LETTERS"
}

creation_epoch() {
  local e
  e=$(stat -c %W -- "$1" 2>/dev/null) || return 1
  if [[ ! "$e" =~ ^[0-9]+$ ]] || (( e == 0 )); then
    e=$(stat -c %Y -- "$1") || return 1
  fi
  printf '%s\n' "$e"
}

in_selected_time() {
  local epoch
  epoch=$(creation_epoch "$1") || return 1
  (( epoch >= FROM_EPOCH && epoch < TO_EPOCH ))
}

discover_from_log() {
  local log_path kind path timestamp size extra
  local header_a header_b header_c header_d
  printf 'Путь к creation_*.log из src/02: '
  IFS= read -r log_path || { error 'не указан лог.'; return 1; }
  [[ -f "$log_path" && ! -L "$log_path" && $(basename -- "$log_path") == creation_*.log ]] || {
    error 'не найден обычный файл журнала Part 2 с именем creation_*.log.'; return 1;
  }
  IFS=$'\t' read -r header_a header_b header_c header_d < "$log_path"
  [[ "$header_a" == TYPE && "$header_b" == FULL_PATH && "$header_c" == CREATED_AT && "$header_d" == SIZE_BYTES ]] || {
    error 'заголовок лога не соответствует формату Part 2.'; return 1;
  }

  declare -a pending_paths=() pending_sizes=()
  while IFS=$'\t' read -r kind path timestamp size extra || [[ -n "$kind" ]]; do
    [[ "$kind" == DIR || "$kind" == FILE ]] || continue
    is_safe_path "$path" && within_scope "$path" || continue
    if [[ "$kind" == DIR ]]; then
      is_generated_dir_name "${path##*/}" && [[ -d "$path" ]] && path_on_root_fs "$path" && add_dir "$path"
    elif [[ "$size" =~ ^[0-9]+$ ]] && is_generated_file_name "${path##*/}"; then
      pending_paths+=("$path")
      pending_sizes+=("$size")
    fi
  done < <(tail -n +2 -- "$log_path")

  local i f parent expected actual
  for ((i=0; i<${#pending_paths[@]}; i++)); do
    f=${pending_paths[i]}
    expected=${pending_sizes[i]}
    parent=${f%/*}
    [[ -n ${SEEN_DIRS["$parent"]+x} ]] || continue
    [[ -f "$f" ]] && path_on_root_fs "$f" || continue
    actual=$(stat -c %s -- "$f") || continue
    [[ "$actual" == "$expected" ]] || {
      printf 'Пропуск изменённого файла (размер не как в логе): %s\n' "$f" >&2
      continue
    }
    add_file "$f"
    EXPECTED_SIZES["$f"]=$expected
  done
}

discover_by_scan() {
  local path leaf parent epoch
  printf 'Поиск в %s (без перехода на другие разделы)...\n' "$SCAN_ROOT"
  while IFS= read -r -d '' path; do
    is_safe_path "$path" && within_scope "$path" || continue
    leaf=${path##*/}
    if [[ -f "$path" && ! -L "$path" ]]; then
      is_generated_file_name "$leaf" || continue
      parent=${path%/*}
      is_generated_dir_name "${parent##*/}" || continue
      if [[ "$MODE" == 2 ]]; then
        in_selected_time "$path" || continue
      else
        mask_file_matches "$leaf" && mask_dir_matches "${parent##*/}" || continue
      fi
      add_file "$path"
    elif [[ -d "$path" && ! -L "$path" ]]; then
      is_generated_dir_name "$leaf" || continue
      if [[ "$MODE" == 2 ]]; then
        in_selected_time "$path" || continue
      else
        mask_dir_matches "$leaf" || continue
      fi
      add_dir "$path"
    fi
  done < <(
    find "$SCAN_ROOT" -xdev \
      \( -type d \( -name '*bin*' -o -name '*sbin*' -o -path /proc -o -path /sys -o -path /dev -o -path /run \) -prune \) -o \
      \( \( -type f -name '*_??????.*' \) -o \( -type d -name '*_??????' \) \) -print0 2>/dev/null
  )
}
