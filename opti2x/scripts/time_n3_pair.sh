#!/usr/bin/env bash
# Fair N>=3 paired timing: warmup A, then N rounds of (A then B) on taskset -c 0
set -euo pipefail
BIN_A=$1; LAB_A=$2; BIN_B=$3; LAB_B=$4; SIZE=$5; OUTDIR=$6; N=${7:-3}
RUN=/workspace/opti2x/runs/star-2.7.11b-human-rnaseq
GDIR=$RUN/indexes/human/hg38_chr21_22
R1=$RUN/reads/human/SRR393763_sub${SIZE}_1.fastq
R2=$RUN/reads/human/SRR393763_sub${SIZE}_2.fastq
mkdir -p "$OUTDIR"
# warm caches
cat "$GDIR/Genome" "$GDIR/SA" "$GDIR/SAindex" >/dev/null
cat "$R1" "$R2" >/dev/null
time_one() {
  local bin=$1 label=$2 out=$3
  rm -rf "${out}tmp" ${out}*
  local start end ec
  start=$(date +%s.%N)
  taskset -c 0 env OMP_NUM_THREADS=1 OMP_THREAD_LIMIT=1 "$bin" \
    --runMode alignReads --runThreadN 1 --genomeDir "$GDIR" --genomeLoad NoSharedMemory \
    --readFilesIn "$R1" "$R2" --outFileNamePrefix "$out" \
    --outSAMtype BAM Unsorted --outSAMunmapped Within --outTmpDir "${out}tmp" \
    > "${out}stdout.txt" 2> "${out}stderr.txt"
  ec=$?
  end=$(date +%s.%N)
  python3 -c "print(f'$label wall_s={float('$end')-float('$start'):.6f} exit=$ec')"
  return $ec
}
RES=$OUTDIR/results.txt
echo "=== ${LAB_A} vs ${LAB_B} human ${SIZE} N=${N} ===" | tee "$RES"
time_one "$BIN_A" "${LAB_A}_w1" "$OUTDIR/${LAB_A}_w1_" | tee -a "$RES"
for i in $(seq 1 "$N"); do
  time_one "$BIN_A" "${LAB_A}_r${i}" "$OUTDIR/${LAB_A}_r${i}_" | tee -a "$RES"
  time_one "$BIN_B" "${LAB_B}_r${i}" "$OUTDIR/${LAB_B}_r${i}_" | tee -a "$RES"
done
# Oracle BAM body: round 1
samtools view "$OUTDIR/${LAB_A}_r1_Aligned.out.bam" | sort > "$OUTDIR/${LAB_A}.body.sam"
samtools view "$OUTDIR/${LAB_B}_r1_Aligned.out.bam" | sort > "$OUTDIR/${LAB_B}.body.sam"
if cmp -s "$OUTDIR/${LAB_A}.body.sam" "$OUTDIR/${LAB_B}.body.sam"; then
  echo ORACLE_OK | tee -a "$RES"
else
  echo ORACLE_FAIL | tee -a "$RES"
  # show first diffs
  diff -u "$OUTDIR/${LAB_A}.body.sam" "$OUTDIR/${LAB_B}.body.sam" | head -40 | tee -a "$RES" || true
fi
# Map-rate check from Log.final
python3 - <<PY
import re, statistics
from pathlib import Path
text=Path("$RES").read_text()
a=[]; b=[]
la, lb = "$LAB_A", "$LAB_B"
for line in text.splitlines():
    m=re.search(r'(\S+) wall_s=([0-9.]+)', line)
    if not m: continue
    lab, w = m.group(1), float(m.group(2))
    if lab.startswith(la+'_r'): a.append(w)
    if lab.startswith(lb+'_r'): b.append(w)
pairs=[ai/bi for ai,bi in zip(a,b)]
print('A', a)
print('B', b)
print('paired_x', pairs)
print('median', statistics.median(pairs) if pairs else None)
print('mean', statistics.mean(pairs) if pairs else None)
if len(pairs)>=2:
    print('stdev', statistics.stdev(pairs))
PY
echo DONE
