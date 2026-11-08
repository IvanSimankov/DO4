#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'HELP'
Использование: ./main.sh <команда>
  install  - установить Prometheus, Node Exporter, Grafana и готовый дашборд
  check    - проверить службы и HTTP-интерфейсы
  stress   - выполнить тест нагрузки из Part 7 (10 секунд)
HELP
}

if [[ $# -ne 1 ]]; then
  usage >&2
  exit 1
fi

case "$1" in
  install)
    bash "$SCRIPT_DIR/setup.sh"
    ;;
  check)
    for service in prometheus prometheus-node-exporter grafana-server; do
      if systemctl is-active --quiet "$service"; then
        printf 'OK: %s запущен\n' "$service"
      else
        printf 'ОШИБКА: %s не запущен\n' "$service" >&2
        exit 1
      fi
    done
    for entry in 'http://127.0.0.1:9090/-/ready Prometheus' 'http://127.0.0.1:9100/metrics Node-Exporter' 'http://127.0.0.1:3000/login Grafana'; do
      read -r url title <<<"$entry"
      if curl -fsS --max-time 5 -o /dev/null "$url"; then
        printf 'OK: %s отвечает: %s\n' "$title" "$url"
      else
        printf 'ОШИБКА: %s недоступен: %s\n' "$title" "$url" >&2
        exit 1
      fi
    done
    printf '\nПроверка сбора метрик (значение должно стать 1):\n'
    curl -fsSG --max-time 5 --data-urlencode 'query=up{job="school21-node"}' \
      'http://127.0.0.1:9090/api/v1/query'
    printf '\n'
    ;;
  stress)
    if ! command -v stress >/dev/null 2>&1; then
      echo 'Ошибка: stress не установлен. Сначала запусти ./main.sh install' >&2
      exit 1
    fi
    stress -c 2 -i 1 -m 1 --vm-bytes 32M -t 10s
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac
