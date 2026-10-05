#!/usr/bin/env bash
set -euo pipefail
[[ $# -eq 0 ]]

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
entry="$repo/scripts/infra-base-stage.py"
log_dir=/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs
[[ -f "$entry" && ! -L "$entry" ]]
[[ -d "$log_dir" && ! -L "$log_dir" ]]
unit="alpbahos-infra-base-$(date -u +%Y%m%dT%H%M%SZ)-$$"
log="$log_dir/$unit.log"
[[ ! -e "$log" && ! -L "$log" ]]
systemd-run --user --unit="$unit" --no-block \
  --property=Type=exec \
  --property=RuntimeMaxSec=infinity \
  --property=TimeoutStartSec=infinity \
  --property="WorkingDirectory=$repo" \
  --property="StandardOutput=append:$log" \
  --property="StandardError=append:$log" \
  /usr/bin/python3 -u "$entry"
printf 'unit=%s\nlog=%s\n' "$unit" "$log"
