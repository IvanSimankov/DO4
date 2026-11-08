#!/usr/bin/env bash

require_program() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'Error: %s is not installed. Run ./main.sh install-tools\n' "$1" >&2
    exit 1
  }
}

valid_ipv4() {
  local input="$1" byte
  local -a octets
  [[ "$input" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] || return 1
  IFS=. read -r -a octets <<< "$input"
  for byte in "${octets[@]}"; do
    (( 10#$byte <= 255 )) || return 1
  done
}

valid_ipv4_cidr() {
  local addr="${1%/*}" prefix="${1##*/}"
  [[ "$1" == */* ]] || return 1
  valid_ipv4 "$addr" || return 1
  [[ "$prefix" =~ ^[0-9]{1,2}$ ]] || return 1
  (( 10#$prefix <= 32 )) || return 1
}

print_interfaces() {
  require_program ip
  ip -br -4 addr show
  echo
  echo 'Default route (do NOT change this adapter):'
  ip -4 route show default || true
}

configure_ip() {
  require_program ip
  local iface="$1" cidr="$2" default_if
  if ! ip link show dev "$iface" >/dev/null 2>&1; then
    printf 'Error: interface %s does not exist. Check ./main.sh ip\n' "$iface" >&2
    return 1
  fi
  if ! valid_ipv4_cidr "$cidr"; then
    echo 'Error: invalid IPv4/CIDR, example 192.168.77.10/24' >&2
    return 1
  fi
  default_if="$(ip -4 route show default | awk 'NR==1 { for (i=1;i<=NF;i++) if ($i=="dev") { print $(i+1); exit } }')"
  if [[ -n "$default_if" && "$iface" == "$default_if" ]]; then
    echo "Error: $iface is the default Internet interface. Use the SECOND VirtualBox adapter." >&2
    return 1
  fi
  sudo ip link set dev "$iface" up
  if ip -4 -o addr show dev "$iface" | grep -Fq "inet $cidr "; then
    echo "Already configured: $iface $cidr"
  else
    sudo ip addr add "$cidr" dev "$iface"
    echo "Configured: $iface $cidr (temporary, until reboot)"
  fi
  ip -br -4 addr show dev "$iface"
}

start_iperf_server() {
  require_program iperf3
  valid_ipv4 "$1" || { echo 'Error: server IP is invalid.' >&2; return 2; }
  echo "iperf3 server listening on $1:5201. Stop with Ctrl+C."
  exec iperf3 -s -B "$1"
}

start_iperf_client() {
  require_program iperf3
  local ip="$1" mode="$2"
  valid_ipv4 "$ip" || { echo 'Error: server IP is invalid.' >&2; return 2; }
  if [[ "$mode" == reverse ]]; then
    exec iperf3 -c "$ip" -t 30 -P 4 -R
  fi
  exec iperf3 -c "$ip" -t 30 -P 4
}
