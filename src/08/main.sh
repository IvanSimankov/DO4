#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/network.sh"

usage() {
  cat <<'USAGE'
School 21 — Part 8: Node Exporter dashboard + iperf3

Usage:
  ./main.sh check
  ./main.sh install-tools
  ./main.sh stress
  ./main.sh ip
  ./main.sh set-ip INTERFACE ADDRESS/CIDR
  ./main.sh server SERVER_IP
  ./main.sh client SERVER_IP
  ./main.sh client-reverse SERVER_IP

Dashboard Grafana Labs: 13978

Network scenario:
  VirtualBox adapter 1: NAT (keep as it is)
  VirtualBox adapter 2: Internal Network, name school21net (same on both VMs)

  VM1 (monitored): ./main.sh set-ip enp0s8 192.168.77.10/24
  VM2 (client):    ./main.sh set-ip enp0s8 192.168.77.11/24
  VM1:             ./main.sh server 192.168.77.10
  VM2:             ./main.sh client 192.168.77.10
  VM2:             ./main.sh client-reverse 192.168.77.10

The example interface name enp0s8 may differ; check with ./main.sh ip.
USAGE
}

check_system() {
  local service
  echo 'Service status:'
  for service in prometheus prometheus-node-exporter grafana-server; do
    if systemctl is-active --quiet "$service"; then
      printf '  %-27s active\n' "$service"
    else
      printf '  %-27s inactive/unknown\n' "$service"
    fi
  done
  echo
  for tool in iperf3 stress; do
    if command -v "$tool" >/dev/null 2>&1; then
      printf '  %-27s installed\n' "$tool"
    else
      printf '  %-27s missing\n' "$tool"
    fi
  done
  echo
  echo 'Grafana:    http://127.0.0.1:3000'
  echo 'Prometheus: http://127.0.0.1:9090/targets'
  echo 'Dashboard ID: 13978 (import using Grafana web interface)'
}

install_tools() {
  command -v apt-get >/dev/null 2>&1 || { echo 'This command requires Ubuntu (apt-get).' >&2; exit 1; }
  sudo apt-get update
  sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y iperf3 stress
}

run_stress() {
  require_program stress
  stress -c 2 -i 1 -m 1 --vm-bytes 32M -t 10s
}

main() {
  if (( $# < 1 )); then usage; exit 1; fi
  local cmd="$1"
  shift
  case "$cmd" in
    check)           (( $# == 0 )) || { usage; exit 2; }; check_system ;;
    install-tools)   (( $# == 0 )) || { usage; exit 2; }; install_tools ;;
    stress)          (( $# == 0 )) || { usage; exit 2; }; run_stress ;;
    ip)              (( $# == 0 )) || { usage; exit 2; }; print_interfaces ;;
    set-ip)          (( $# == 2 )) || { usage; exit 2; }; configure_ip "$1" "$2" ;;
    server)          (( $# == 1 )) || { usage; exit 2; }; start_iperf_server "$1" ;;
    client)          (( $# == 1 )) || { usage; exit 2; }; start_iperf_client "$1" forward ;;
    client-reverse)  (( $# == 1 )) || { usage; exit 2; }; start_iperf_client "$1" reverse ;;
    -h|--help|help) (( $# == 0 )) || { usage; exit 2; }; usage ;;
    *) echo "Unknown command: $cmd" >&2; usage >&2; exit 2 ;;
  esac
}

main "$@"
