#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${EUID}" -eq 0 ]]; then
  echo 'Запусти установку от обычного пользователя, без sudo перед ./main.sh.' >&2
  exit 1
fi
if [[ ! -f /etc/os-release ]]; then
  echo 'Не удалось определить Linux-дистрибутив.' >&2
  exit 1
fi
# shellcheck source=/dev/null
source /etc/os-release
if [[ "${ID:-}" != ubuntu ]]; then
  echo 'Внимание: инструкция проверяется для Ubuntu / Xubuntu 24.04 LTS.' >&2
fi
if [[ "${VERSION_ID:-}" != 24.04 ]]; then
  echo "Внимание: у тебя ${PRETTY_NAME:-Linux}; задание рассчитано на Ubuntu 24.04." >&2
fi
for program in sudo apt-get; do
  if ! command -v "$program" >/dev/null 2>&1; then
    echo "Не найдена необходимая команда: $program" >&2
    exit 1
  fi
done

echo '[1/5] Устанавливаю Prometheus, Node Exporter и stress...'
sudo apt-get update
sudo apt-get install -y prometheus prometheus-node-exporter stress wget curl ca-certificates gnupg

echo '[2/5] Добавляю официальный репозиторий Grafana...'
sudo install -d -m 755 /etc/apt/keyrings
sudo wget -q -O /etc/apt/keyrings/grafana.asc https://apt.grafana.com/gpg-full.key
sudo chmod 644 /etc/apt/keyrings/grafana.asc
printf '%s\n' 'deb [signed-by=/etc/apt/keyrings/grafana.asc] https://apt.grafana.com stable main' \
  | sudo tee /etc/apt/sources.list.d/school21-grafana.list >/dev/null
sudo apt-get update
sudo apt-get install -y grafana

echo '[3/5] Добавляю сбор метрик Linux в Prometheus...'
config=/etc/prometheus/prometheus.yml
if [[ ! -f "$config" ]]; then
  echo "Ошибка: не найден конфиг Prometheus: $config" >&2
  exit 1
fi
tmp_config="$(mktemp)"
trap 'rm -f "$tmp_config"' EXIT
sudo cat "$config" > "$tmp_config"
if ! grep -Eq "job_name:[[:space:]]*['\"]?school21-node['\"]?" "$tmp_config"; then
  if ! grep -Eq '^scrape_configs:[[:space:]]*$' "$tmp_config"; then
    printf '\nscrape_configs:\n' >> "$tmp_config"
  fi
  cat >> "$tmp_config" <<'YAML'

  - job_name: 'school21-node'
    scrape_interval: 5s
    static_configs:
      - targets: ['127.0.0.1:9100']
YAML
fi
if command -v promtool >/dev/null 2>&1; then
  promtool check config "$tmp_config"
fi
sudo cp -a "$config" "${config}.school21-backup"
sudo install -m 644 "$tmp_config" "$config"

echo '[4/5] Настраиваю источник данных и дашборд Grafana...'
sudo install -d -m 755 /etc/grafana/provisioning/datasources /etc/grafana/provisioning/dashboards
sudo install -d -m 755 /var/lib/grafana/dashboards/school21
sudo tee /etc/grafana/provisioning/datasources/school21-prometheus.yml >/dev/null <<'YAML'
apiVersion: 1
datasources:
  - name: School21 Prometheus
    uid: school21-prometheus
    type: prometheus
    access: proxy
    url: http://127.0.0.1:9090
    editable: true
YAML
sudo tee /etc/grafana/provisioning/dashboards/school21.yml >/dev/null <<'YAML'
apiVersion: 1
providers:
  - name: school21-linux
    orgId: 1
    folder: School21
    type: file
    disableDeletion: false
    editable: true
    options:
      path: /var/lib/grafana/dashboards/school21
YAML
sudo install -m 644 "$SCRIPT_DIR/dashboard.json" /var/lib/grafana/dashboards/school21/dashboard.json

echo '[5/5] Запускаю системные службы...'
sudo systemctl enable --now prometheus-node-exporter
sudo systemctl enable --now prometheus
sudo systemctl restart prometheus
sudo systemctl enable --now grafana-server
sudo systemctl restart grafana-server

cat <<'HELP'

Готово! Открой с Windows (после проброса NAT-портов в VirtualBox):
  Prometheus: http://127.0.0.1:9090/targets
  Grafana:    http://127.0.0.1:3000/

Первый вход Grafana обычно: admin / admin (сразу поменяй пароль).
Дашборд: Dashboards -> School21 -> Linux Monitoring.
Проверка: ./main.sh check
Нагрузка: ./main.sh stress
HELP
