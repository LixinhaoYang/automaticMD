#!/usr/bin/env bash
set -euo pipefail

if (( $# < 1 || $# > 2 )); then
  printf 'Usage: %s TIME [DEPENDENCY_JOB_ID]\n' "$0" >&2
  printf 'Example: %s 24:00:00 12345678\n' "$0" >&2
  exit 2
fi

time_limit=$1
dependency_job_id=${2:-}
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
config_dir="${CONF_DIR:-$script_dir/conf}"
submitter="$script_dir/slurmsub.sh"

if [[ ! -f "$submitter" ]]; then
  printf 'Error: submitter not found: %s\n' "$submitter" >&2
  exit 1
fi
if [[ ! -d "$config_dir" ]]; then
  printf 'Error: config directory not found: %s\n' "$config_dir" >&2
  exit 1
fi

shopt -s nullglob
configs=("$config_dir"/*.conf)
if (( ${#configs[@]} == 0 )); then
  printf 'Error: no .conf files found in %s\n' "$config_dir" >&2
  exit 1
fi

printf 'Submitting %d configuration file(s) from %s\n' "${#configs[@]}" "$config_dir"
for config in "${configs[@]}"; do
  job_name="$(basename -- "$config" .conf)"
  printf 'Submitting %s...\n' "$job_name"
  if [[ -n "$dependency_job_id" ]]; then
    (cd "$config_dir" && bash "$submitter" "$job_name" "$time_limit" "$dependency_job_id")
  else
    (cd "$config_dir" && bash "$submitter" "$job_name" "$time_limit")
  fi
done
