#!/usr/bin/env bash

validate_args() {
  if (( $# != 3 )); then
    printf 'Ошибка: нужно ровно 3 параметра.\n' >&2
    printf 'Использование: %s az az.az 3Mb\n' "$0" >&2
    return 1
  fi

  if [[ ! "$1" =~ ^[A-Za-z]{1,7}$ ]]; then
    printf 'Ошибка: параметр 1 — от 1 до 7 английских букв.\n' >&2
    return 1
  fi
  DIR_LETTERS=$1

  if [[ ! "$2" =~ ^([A-Za-z]{1,7})\.([A-Za-z]{1,3})$ ]]; then
    printf 'Ошибка: параметр 2 должен иметь вид name.ext (1–7 и 1–3 английских букв).\n' >&2
    return 1
  fi
  FILE_LETTERS=${BASH_REMATCH[1]}
  FILE_EXTENSION=${BASH_REMATCH[2]}

  if [[ ! "$3" =~ ^([1-9][0-9]?|100)Mb$ ]]; then
    printf 'Ошибка: параметр 3 — размер от 1Mb до 100Mb, например 3Mb.\n' >&2
    return 1
  fi
  SIZE_MB=${BASH_REMATCH[1]}
  SIZE_BYTES=$(( SIZE_MB * 1024 * 1024 ))

  if [[ -n "${S21_TEST_LIMIT:-}" ]]; then
    if [[ ! "$S21_TEST_LIMIT" =~ ^[1-9][0-9]{0,5}$ ]]; then
      printf 'Ошибка: S21_TEST_LIMIT должен быть положительным числом (1–999999).\n' >&2
      return 1
    fi
  fi

  if [[ -n "${S21_TEST_BASE_DIR:-}" && "$S21_TEST_BASE_DIR" != /* ]]; then
    printf 'Ошибка: S21_TEST_BASE_DIR должен быть абсолютным путём.\n' >&2
    return 1
  fi

  local example
  example=$(make_stem "$DIR_LETTERS" 5 0)
  if [[ "$example" == *bin* || "$example" == *sbin* ]]; then
    printf 'Ошибка: выбранные буквы формируют каталог с запрещённым фрагментом bin/sbin.\n' >&2
    return 1
  fi
}
