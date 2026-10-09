#!/usr/bin/env bash
set -euo pipefail
RUN=/workspace/opti2x/runs/star-2.7.11b-human-rnaseq
OUT=$RUN/measurements/phase_a
GDIR=$RUN/indexes/human/hg38_chr21_22
# Default SIZE via env; 20k avoids pathological hang near read ~64050 in random 200k
SIZE=${SIZE:-20000}
R1=$RUN/reads/human/SRR393763_sub${SIZE}_1.fastq
R2=$RUN/reads/human/SRR393763_sub${SIZE}_2.fastq
mkdir -p $OUT/human
# warm
cat $GDIR/Genome $GDIR/SA $GDIR/SAindex >/dev/null
cat $R1 $R2 >/dev/null
run_one() {
  local bin="$1" label="$2" outp="$3"
  export OMP_NUM_THREADS=1 OMP_THREAD_LIMIT=1
  rm -rf "${outp}tmp" ${outp}*
  start=$(date +%s.%N)
  taskset -c 0 env OMP_NUM_THREADS=1 OMP_THREAD_LIMIT=1 "$bin" \
    --runMode alignReads --runThreadN 1 \
    --genomeDir "$GDIR" --genomeLoad NoSharedMemory \
    --readFilesIn "$R1" "$R2" \
    --outFileNamePrefix "$outp" \
    --outSAMtype BAM Unsorted --outSAMunmapped Within \
    --outTmpDir "${outp}tmp" > "${outp}stdout.txt" 2> "${outp}stderr.txt"
  ec=$?
  end=$(date +%s.%N)
  python3 -c "print(f'$label\twall_s={float('$end')-float('$start'):.6f}\texit=$ec')"
  grep -E 'Number of input reads|Uniquely mapped reads number|Uniquely mapped reads %|too short|Mapping speed' "${outp}Log.final.out" | sed "s/^/$label\t/" || true
}
echo "=== HUMAN ${SIZE} ==="
run_one $RUN/baseline/STAR baseline_h${SIZE}_w1 $OUT/human/pilot${SIZE}_baseline_w1_
run_one $RUN/baseline/STAR baseline_h${SIZE}_r1 $OUT/human/pilot${SIZE}_baseline_r1_
run_one $RUN/candidate/STAR candidate_h${SIZE}_r1 $OUT/human/pilot${SIZE}_candidate_r1_
run_one $RUN/baseline/STAR baseline_h${SIZE}_r2 $OUT/human/pilot${SIZE}_baseline_r2_
run_one $RUN/candidate/STAR candidate_h${SIZE}_r2 $OUT/human/pilot${SIZE}_candidate_r2_
run_one $RUN/baseline/STAR baseline_h${SIZE}_r3 $OUT/human/pilot${SIZE}_baseline_r3_
run_one $RUN/candidate/STAR candidate_h${SIZE}_r3 $OUT/human/pilot${SIZE}_candidate_r3_
echo PILOT_HUMAN_DONE size=$SIZE
