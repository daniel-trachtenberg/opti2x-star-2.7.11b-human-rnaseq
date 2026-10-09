#!/usr/bin/env bash
set -euo pipefail
# Usage: time_pair.sh <star_bin> <size> <label> <outdir>
BIN=$1; SIZE=$2; LABEL=$3; OUTDIR=$4
RUN=/workspace/opti2x/runs/star-2.7.11b-human-rnaseq
GDIR=$RUN/indexes/human/hg38_chr21_22
R1=$RUN/reads/human/SRR393763_sub${SIZE}_1.fastq
R2=$RUN/reads/human/SRR393763_sub${SIZE}_2.fastq
mkdir -p "$OUTDIR"
OUTP=$OUTDIR/${LABEL}_
rm -rf "${OUTP}tmp" ${OUTP}*
export OMP_NUM_THREADS=1 OMP_THREAD_LIMIT=1
start=$(date +%s.%N)
taskset -c 0 env OMP_NUM_THREADS=1 OMP_THREAD_LIMIT=1 "$BIN" \
  --runMode alignReads --runThreadN 1 \
  --genomeDir "$GDIR" --genomeLoad NoSharedMemory \
  --readFilesIn "$R1" "$R2" \
  --outFileNamePrefix "$OUTP" \
  --outSAMtype BAM Unsorted --outSAMunmapped Within \
  --outTmpDir "${OUTP}tmp" > "${OUTP}stdout.txt" 2> "${OUTP}stderr.txt"
ec=$?
end=$(date +%s.%N)
python3 -c "print(f'$LABEL wall_s={float('$end')-float('$start'):.6f} exit=$ec')"
exit $ec
