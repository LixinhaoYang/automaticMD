#!/usr/bin/env bash
set -euo pipefail

if (( $# < 2 || $# > 3 )); then
  printf 'Usage: %s JOB_NAME TIME [DEPENDENCY_JOB_ID]\n' "$0" >&2
  exit 2
fi

job_name=$1
conffile="${job_name}.conf"
logfile="${job_name}.log"
time_limit=$2
dependency_job_id=${3:-}

ngpu=1
queue=embers
gpu_type=H200
ppn=6
nproc=$((ngpu * ppn))

if [[ ! -f "$conffile" ]]; then
  printf 'Error: configuration file not found: %s\n' "$conffile" >&2
  exit 1
fi

dependency_option=()
if [[ -n "$dependency_job_id" ]]; then
  if [[ ! "$dependency_job_id" =~ ^[0-9]+([_+][0-9]+)?$ ]]; then
    printf 'Error: invalid dependency job ID: %s\n' "$dependency_job_id" >&2
    exit 2
  fi
  dependency_option=("--dependency=afterany:${dependency_job_id}")
fi

sbatch \
  -A gts-jcgumbart-coda20 \
  -J "$job_name" \
  -q "$queue" \
  -t "$time_limit" \
  "${dependency_option[@]}" \
  -N 1 \
  --ntasks-per-node="$nproc" \
  --gres="gpu:${gpu_type}:${ngpu}" \
  --mail-user=yanglixinhao@gmail.com \
  <<EOF
#!/usr/bin/env bash
set -euo pipefail
cd "\${SLURM_SUBMIT_DIR}"
NAMDBIN=/storage/project/r-jcgumbart-0/jcgumbart/software/NAMD_3.0.2_Linux-x86_64-multicore-CUDA/namd3
"\${NAMDBIN}" +p${nproc} "$conffile" > "$logfile"
EOF
