#!/usr/bin/env bash

show_preview() {
  local f shown=0
  printf '\nНайдено файлов: %d; каталогов: %d\n' "${#FILES[@]}" "${#DIRS[@]}"
  printf 'Пример объектов для очистки (до 15):\n'
  for f in "${FILES[@]}" "${DIRS[@]}"; do
    printf '  %s\n' "$f"
    ((shown += 1))
    ((shown >= 15)) && break
  done
  printf 'Файлы не из списка не будут удаляться; каталоги удаляются только если пустые.\n'
}

perform_cleanup() {
  local reply f d expected now okfiles=0 okdirs=0 skipped=0
  if (( ${#FILES[@]} == 0 && ${#DIRS[@]} == 0 )); then
    printf 'Подходящих объектов нет. Ничего не удалено.\n'
    return 0
  fi

  show_preview
  if [[ "${S21_DRY_RUN:-0}" == 1 ]]; then
    printf '\nS21_DRY_RUN=1: это только просмотр. Ничего не удалено.\n'
    return 0
  fi

  printf '\nДля удаления введите УДАЛИТЬ (любое другое значение отменяет): '
  IFS= read -r reply || { printf '\nОтмена.\n'; return 0; }
  if [[ "$reply" != УДАЛИТЬ ]]; then
    printf 'Отмена: файлы не удалены.\n'
    return 0
  fi

  local cleanup_log="$SCRIPT_DIR/cleanup_$(date +%Y%m%d_%H%M%S)_$$.log"
  printf 'ACTION\tPATH\tTIME\tDETAILS\n' > "$cleanup_log"
  for f in "${FILES[@]}"; do
    if ! is_safe_path "$f" || ! within_scope "$f" || [[ ! -f "$f" ]] || ! path_on_root_fs "$f"; then
      ((skipped += 1))
      printf 'SKIP\t%s\t%s\tmissing_or_unsafe\n' "$f" "$(date -Is)" >> "$cleanup_log"
      continue
    fi
    if [[ -n ${EXPECTED_SIZES["$f"]+x} ]]; then
      expected=${EXPECTED_SIZES["$f"]}
      now=$(stat -c %s -- "$f")
      if [[ "$now" != "$expected" ]]; then
        ((skipped += 1))
        printf 'SKIP\t%s\t%s\tsize_changed\n' "$f" "$(date -Is)" >> "$cleanup_log"
        continue
      fi
    fi
    if rm -- "$f"; then
      ((okfiles += 1))
      printf 'FILE\t%s\t%s\tdeleted\n' "$f" "$(date -Is)" >> "$cleanup_log"
    else
      ((skipped += 1))
      printf 'SKIP\t%s\t%s\trm_failed\n' "$f" "$(date -Is)" >> "$cleanup_log"
    fi
  done

  while IFS= read -r -d '' d; do
    if ! is_safe_path "$d" || ! within_scope "$d" || [[ ! -d "$d" ]] || ! path_on_root_fs "$d"; then
      ((skipped += 1))
      continue
    fi
    if rmdir -- "$d" 2>/dev/null; then
      ((okdirs += 1))
      printf 'DIR\t%s\t%s\tdeleted\n' "$d" "$(date -Is)" >> "$cleanup_log"
    else
      ((skipped += 1))
      printf 'SKIP\t%s\t%s\tnot_empty_or_no_permission\n' "$d" "$(date -Is)" >> "$cleanup_log"
    fi
  done < <(printf '%s\0' "${DIRS[@]}" | LC_ALL=C sort -zr)

  printf '\nУдалено файлов: %d; каталогов: %d; пропущено: %d\n' "$okfiles" "$okdirs" "$skipped"
  printf 'Лог очистки: %s\n' "$cleanup_log"
}
