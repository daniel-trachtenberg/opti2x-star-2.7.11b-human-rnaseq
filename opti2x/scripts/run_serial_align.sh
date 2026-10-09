#!/usr/bin/env bash
# Fair serial envelope: CLI + env + optional taskset
set -euo pipefail
STAR_BIN="$1"
GENOME_DIR="$2"
R1="$3"
R2="$4"
OUT_PREFIX="$5"
THREADS_ENV=1
export OMP_NUM_THREADS=1
export OMP_THREAD_LIMIT=1
export MKL_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
mkdir -p "$(dirname "$OUT_PREFIX")"
# Prefer taskset if available
WRAP=(env OMP_NUM_THREADS=1 OMP_THREAD_LIMIT=1)
if command -v taskset >/dev/null; then
  WRAP=(taskset -c 0 env OMP_NUM_THREADS=1 OMP_THREAD_LIMIT=1)
fi
# Process start->exit wall via TIMEFORMAT / date
START=$(date +%s.%N)
"${WRAP[@]}" "$STAR_BIN" \
  --runMode alignReads \
  --runThreadN 1 \
  --genomeDir "$GENOME_DIR" \
  --genomeLoad NoSharedMemory \
  --readFilesIn "$R1" "$R2" \
  --outFileNamePrefix "$OUT_PREFIX" \
  --outSAMtype BAM Unsorted \
  --outSAMunmapped Within \
  --limitBAMsortRAM 0 \
  --outTmpDir "${OUT_PREFIX}tmp" \
  > "${OUT_PREFIX}stdout.txt" 2> "${OUT_PREFIX}stderr.txt"
EC=$?
END=$(date +%s.%N)
python3 - <<PY
start=float("$START"); end=float("$END")
print(f"wall_s={end-start:.6f}")
print(f"exit={$EC}")
PY
# NLWP spot-check from Log.final if present
if [ -f "${OUT_PREFIX}Log.final.out" ]; then
  grep -E 'Number of input reads|Uniquely mapped|CPU time|wall clock' "${OUT_PREFIX}Log.final.out" || true
fi
exit $EC
