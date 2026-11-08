#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
source "$SCRIPT_DIR/validate.sh"
source "$SCRIPT_DIR/discovery.sh"
source "$SCRIPT_DIR/cleanup.sh"

validate_main_args "$@" || exit 1
ROOT_DEVICE=$(stat -c %d /)
configure_scan_root || exit 1

case "$MODE" in
  1) discover_from_log || exit 1 ;;
  2) ask_time_range || exit 1; discover_by_scan ;;
  3) ask_mask || exit 1; discover_by_scan ;;
esac

perform_cleanup
