#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
tcl_dir="$script_dir/tcllib"
vmd_default="/Applications/VMD2b1.app/Contents/vmd2b1/vmd_MACOSXARM64"
vmd_bin="${VMD_BIN:-$vmd_default}"
output_root="${OUTPUT_DIR:-$tcl_dir/output}"
runfile_dir="${RUNFILE_DIR:-$script_dir/runfile}"
structure_dir="$runfile_dir/struc"
config_dir="$runfile_dir/conf"

usage() {
  printf 'Usage: %s PDB_FILE [PDB_FILE ...]\n' "${0##*/}"
  printf 'Environment: VMD_BIN=/path/to/vmd OUTPUT_DIR=/path/to/output RUNFILE_DIR=/path/to/runfile\n'
}

if (( $# == 0 )); then
  usage >&2
  exit 2
fi

if [[ ! -x "$vmd_bin" ]]; then
  printf 'Error: VMD executable not found or not executable: %s\n' "$vmd_bin" >&2
  printf 'Set VMD_BIN to the VMD executable for this system.\n' >&2
  exit 1
fi

if [[ ! -d "$tcl_dir" ]]; then
  printf 'Error: Tcl library directory not found: %s\n' "$tcl_dir" >&2
  exit 1
fi

mkdir -p "$output_root" "$structure_dir" "$config_dir"
metadata_file="$runfile_dir/systems.dat"
if [[ ! -e "$metadata_file" ]]; then
  paramdir="${PARAMDIR:-/path/to/ParamFiles}"
  printf '%s\n' "$paramdir" > "$metadata_file"
  printf 'name\tbox_x\tbox_y\tbox_z\torigin_x\torigin_y\torigin_z\n' >> "$metadata_file"
fi
paramdir="$(sed -n '1p' "$metadata_file")"
if [[ -z "$paramdir" ]]; then
  printf 'Error: the first line of %s must contain paramdir\n' "$metadata_file" >&2
  exit 1
fi

generate_config() {
  local name="$1" box_x="$2" box_y="$3" box_z="$4"
  local origin_x="$5" origin_y="$6" origin_z="$7"
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
  ' "$runfile_dir/base.conf" > "$config_dir/$name.conf"
}

for pdb_arg in "$@"; do
  if [[ ! -f "$pdb_arg" ]]; then
    printf 'Error: PDB file not found: %s\n' "$pdb_arg" >&2
    exit 1
  fi

  pdb_path="$(cd -- "$(dirname -- "$pdb_arg")" && pwd)/$(basename -- "$pdb_arg")"
  pdb_name="$(basename -- "$pdb_path")"
  stem="${pdb_name%.*}"

  if [[ ! "$stem" =~ ^[A-Za-z0-9._-]+$ ]]; then
    printf 'Error: PDB basename contains unsupported characters: %s\n' "$pdb_name" >&2
    exit 1
  fi

  work_dir="$output_root/$stem"
  mkdir -p "$work_dir"
  cp "$pdb_path" "$work_dir/$stem.pdb"
  cp "$tcl_dir/top_all36_prot.rtf" "$work_dir/"
  cp "$tcl_dir/size.tcl" "$work_dir/"

  # The VMD plugins require real basenames, so replace the literal template
  # token "text" before either Tcl script is executed.
  sed "s/text/$stem/g" "$tcl_dir/gen.tcl" > "$work_dir/gen.$stem.tcl"
  sed "s/text/$stem/g" "$tcl_dir/solv.tcl" > "$work_dir/solv.$stem.tcl"

  printf '\nBuilding %s in %s\n' "$pdb_name" "$work_dir"
  (
    cd "$work_dir"
    "$vmd_bin" -dispdev text -e "gen.$stem.tcl"
    if [[ ! -s "${stem}_H.psf" || ! -s "${stem}_H.pdb" ]]; then
      printf 'Error: PSFGEN did not create the expected files for %s\n' "$stem" >&2
      exit 1
    fi
    "$vmd_bin" -dispdev text -e "solv.$stem.tcl"
    if [[ ! -s "${stem}_H_wi.psf" || ! -s "${stem}_H_wi.pdb" ]]; then
      printf 'Error: solvation/ionization did not create the expected files for %s\n' "$stem" >&2
      exit 1
    fi
    "$vmd_bin" -dispdev text -e "$tcl_dir/strucHMR_Gen.tcl" \
      -args "${stem}_H_wi.psf" "${stem}_H_wi.pdb"
    if [[ ! -s "${stem}_H_wi.hmr.psf" || ! -s "${stem}.dat" ]]; then
      printf 'Error: HMR or metadata generation failed for %s\n' "$stem" >&2
      exit 1
    fi
  )

  cp "$work_dir/${stem}_H_wi.hmr.psf" "$structure_dir/${stem}_H_wi.psf"
  cp "$work_dir/${stem}_H_wi.pdb" "$structure_dir/"

  metadata_tmp="$runfile_dir/.systems.$$.tmp"
  awk -v name="${stem}_H_wi" 'NR <= 2 || $1 != name' \
    "$metadata_file" > "$metadata_tmp"
  cat "$work_dir/${stem}.dat" >> "$metadata_tmp"
  mv "$metadata_tmp" "$metadata_file"

  read -r config_name box_x box_y box_z origin_x origin_y origin_z \
    < "$work_dir/${stem}.dat"
  generate_config "$config_name" "$box_x" "$box_y" "$box_z" \
    "$origin_x" "$origin_y" "$origin_z"

  printf 'Ready-to-run files: %s/%s_H_wi.{psf,pdb}; config: %s/%s_H_wi.conf\n' \
    "$structure_dir" "$stem" "$config_dir" "$stem"
done
