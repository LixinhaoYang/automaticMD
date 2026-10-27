#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
systems_file="${SYSTEMS_FILE:-$script_dir/systems.dat}"
base_config="${BASE_CONFIG:-$script_dir/base.conf}"
config_dir="${CONF_DIR:-$script_dir/conf}"
structure_dir="${STRUCTURE_DIR:-$script_dir/struc}"

for required_file in "$systems_file" "$base_config"; do
  if [[ ! -f "$required_file" ]]; then
    printf 'Error: required file not found: %s\n' "$required_file" >&2
    exit 1
  fi
done

paramdir="$(sed -n '1p' "$systems_file")"
if [[ -z "$paramdir" ]]; then
  printf 'Error: line 1 of %s must contain paramdir\n' "$systems_file" >&2
  exit 1
fi

mkdir -p "$config_dir"
count=0

# Line 1 is paramdir and line 2 is the column header. Remaining lines are:
# name box_x box_y box_z origin_x origin_y origin_z
while read -r name box_x box_y box_z origin_x origin_y origin_z extra; do
  [[ -z "${name:-}" ]] && continue

  if [[ -n "${extra:-}" || -z "${origin_z:-}" ]]; then
    printf 'Error: malformed systems.dat row for %s\n' "$name" >&2
    exit 1
  fi
  if [[ ! "$name" =~ ^[A-Za-z0-9._-]+$ ]]; then
    printf 'Error: unsafe system name in systems.dat: %s\n' "$name" >&2
    exit 1
  fi
  if [[ ! -s "$structure_dir/$name.psf" || ! -s "$structure_dir/$name.pdb" ]]; then
    printf 'Error: missing PSF/PDB pair for %s under %s\n' "$name" "$structure_dir" >&2
    exit 1
  fi

  output="$config_dir/$name.conf"
  temporary="$config_dir/.$name.conf.tmp"
  awk -v name="$name" -v a="$box_x" -v b="$box_y" -v c="$box_z" \
      -v ox="$origin_x" -v oy="$origin_y" -v oz="$origin_z" \
      -v paramdir="$paramdir" '
    /^[[:space:]]*set name[[:space:]]/ {
      printf "set name                %s\n", name; next
    }
    /^[[:space:]]*set a[[:space:]]/ {
      printf "set a                   %s                ;# xlength of water box\n", a; next
    }
    /^[[:space:]]*set b[[:space:]]/ {
      printf "set b                   %s                ;# ylength of water box\n", b; next
    }
    /^[[:space:]]*set c[[:space:]]/ {
      printf "set c                   %s                ;# zlength of water box\n", c; next
    }
    /^[[:space:]]*set paramdir[[:space:]]/ {
      printf "set paramdir            %s\n", paramdir; next
    }
    /^[[:space:]]*structure[[:space:]]/ {
      printf "structure               ../struc/%s.psf\n", name; next
    }
    /^[[:space:]]*coordinates[[:space:]]/ {
      printf "coordinates             ../struc/%s.pdb\n", name; next
    }
    /^[[:space:]]*cellOrigin[[:space:]]/ {
      printf "cellOrigin              %s %s %s\n", ox, oy, oz; next
    }
    { print }
  ' "$base_config" > "$temporary"
  mv "$temporary" "$output"
  count=$((count + 1))
done < <(tail -n +3 "$systems_file")

printf 'Generated %d configuration file(s) in %s\n' "$count" "$config_dir"
