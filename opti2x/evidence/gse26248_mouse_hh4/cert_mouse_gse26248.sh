#!/usr/bin/env bash
# Paired interleaved certification on GSE26248/SRR327045 (mouse, 200k PE, mm10 chr1+2+19):
# BIN_A (stock STAR 2.7.11b) vs BIN_B (Opti2x HH1+HH4). Serial envelope, warm cache, frozen-seed
# randomized order. Resumable: rounds already present in results.tsv are skipped.
# Oracle (sorted samtools view body + Log.final.out mapping stats) on round 1 and round N.
# Usage: cert_mouse_gse26248.sh BIN_A LAB_A BIN_B LAB_B OUTDIR [N=30] [SEED=20261008]
set -uo pipefail
BIN_A=$1; LAB_A=$2; BIN_B=$3; LAB_B=$4; OUTDIR=$5
N=${6:-30}; SEED=${7:-20261008}
RUN=/workspace/opti2x/runs/star-2.7.11b-human-rnaseq
GDIR=$RUN/indexes/mouse/mm10_chr1_2_19
R1=$RUN/reads/mouse/SRR327045_sub200000_1.fastq
R2=$RUN/reads/mouse/SRR327045_sub200000_2.fastq
mkdir -p "$OUTDIR/runs"
cat "$GDIR/Genome" "$GDIR/SA" "$GDIR/SAindex" "$R1" "$R2" >/dev/null

time_one() {
  local bin=$1 out=$2
  rm -rf "${out}tmp" "${out}"Aligned.out.bam "${out}"Log.* "${out}"SJ.out.tab "${out}"stdout.txt "${out}"stderr.txt
  local start end ec
  start=$(date +%s.%N)
  taskset -c 0 env OMP_NUM_THREADS=1 OMP_THREAD_LIMIT=1 "$bin" \
    --runMode alignReads --runThreadN 1 --genomeDir "$GDIR" --genomeLoad NoSharedMemory \
    --readFilesIn "$R1" "$R2" --outFileNamePrefix "$out" \
    --outSAMtype BAM Unsorted --outSAMunmapped Within --outTmpDir "${out}tmp" \
    > "${out}stdout.txt" 2> "${out}stderr.txt"
  ec=$?
  end=$(date +%s.%N)
  if [[ $ec -ne 0 ]]; then echo "RUN_FAIL $bin exit=$ec out=$out" >&2; exit 3; fi
  python3 -c "print(f'{float(\"$end\")-float(\"$start\"):.6f}')"
}

oracle() { # outA outB tag -> prints OK/FAIL, writes detail file
  local a=$1 b=$2 tag=$3 det="$OUTDIR/equivalence_${tag}.txt"
  samtools view "${a}Aligned.out.bam" | LC_ALL=C sort > "$OUTDIR/${tag}_${LAB_A}.body.sam"
  samtools view "${b}Aligned.out.bam" | LC_ALL=C sort > "$OUTDIR/${tag}_${LAB_B}.body.sam"
  local bodyA bodyB bam=FAIL stats=FAIL
  bodyA=$(sha256sum < "$OUTDIR/${tag}_${LAB_A}.body.sam" | cut -d' ' -f1)
  bodyB=$(sha256sum < "$OUTDIR/${tag}_${LAB_B}.body.sam" | cut -d' ' -f1)
  cmp -s "$OUTDIR/${tag}_${LAB_A}.body.sam" "$OUTDIR/${tag}_${LAB_B}.body.sam" && bam=OK
  # mapping stats: drop timing/speed lines
  local filt='Started job on|Started mapping on|Finished on|Mapping speed'
  grep -Ev "$filt" "${a}Log.final.out" > "$OUTDIR/${tag}_${LAB_A}.Log.final.stats"
  grep -Ev "$filt" "${b}Log.final.out" > "$OUTDIR/${tag}_${LAB_B}.Log.final.stats"
  diff "$OUTDIR/${tag}_${LAB_A}.Log.final.stats" "$OUTDIR/${tag}_${LAB_B}.Log.final.stats" > "$OUTDIR/${tag}_logfinal.diff" && stats=OK
  local sj=FAIL; cmp -s "${a}SJ.out.tab" "${b}SJ.out.tab" && sj=OK
  {
    echo "tag=$tag"
    echo "bam_records_${LAB_A}=$(wc -l < "$OUTDIR/${tag}_${LAB_A}.body.sam")"
    echo "bam_records_${LAB_B}=$(wc -l < "$OUTDIR/${tag}_${LAB_B}.body.sam")"
    echo "sorted_body_sha256_${LAB_A}=$bodyA"
    echo "sorted_body_sha256_${LAB_B}=$bodyB"
    echo "sorted_bam_body_identical=$bam"
    echo "log_final_mapping_stats_identical=$stats"
    echo "sj_out_tab_identical=$sj"
    echo "--- ${LAB_A} Log.final.out (stats) ---"; cat "$OUTDIR/${tag}_${LAB_A}.Log.final.stats"
  } > "$det"
  rm -f "$OUTDIR/${tag}_${LAB_A}.body.sam" "$OUTDIR/${tag}_${LAB_B}.body.sam"
  if [[ $bam == OK && $stats == OK && $sj == OK ]]; then echo OK; else echo FAIL; fi
}

RES=$OUTDIR/results.tsv; META=$OUTDIR/meta.txt
if [[ ! -s $RES ]]; then
  { echo "seed=$SEED N=$N reads=SRR327045_sub200000 PE genome=mm10_chr1_2_19 lab_a=$LAB_A lab_b=$LAB_B"
    echo "envelope: runThreadN=1 OMP_NUM_THREADS=1 OMP_THREAD_LIMIT=1 taskset -c 0 genomeLoad=NoSharedMemory warm-cache outSAMtype=BAM Unsorted outSAMunmapped=Within"
    echo "host: $(uname -srm) cpu=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs) nproc=$(nproc)"
    sha256sum "$BIN_A" "$BIN_B"; echo "start=$(date -Is)"; } | tee "$META"
  echo -e "round\torder\t${LAB_A}_s\t${LAB_B}_s\tpaired_x\toracle" > "$RES"
  echo "WARMUP ${LAB_A}" | tee -a "$META"
  W=$(time_one "$BIN_A" "$OUTDIR/runs/warmup_${LAB_A}_"); echo "warmup_${LAB_A}_s=$W" | tee -a "$META"
else
  echo "RESUME at $(date -Is) after $(($(wc -l < "$RES")-1)) rounds" | tee -a "$META"
fi
ORDERS=$(python3 -c "import random;r=random.Random($SEED);print(' '.join(str(r.randint(0,1)) for _ in range($N)))")
grep -q '^orders=' "$META" || echo "orders=$ORDERS" >> "$META"
i=0
for ord in $ORDERS; do
  i=$((i+1))
  if awk -F'\t' -v r=$i 'NR>1 && $1==r {f=1} END{exit !f}' "$RES"; then continue; fi
  tag=$(printf 'r%02d' "$i"); outA="$OUTDIR/runs/${tag}_${LAB_A}_"; outB="$OUTDIR/runs/${tag}_${LAB_B}_"
  if [[ $ord == 0 ]]; then ol=A_then_B; sA=$(time_one "$BIN_A" "$outA") || exit 3; sB=$(time_one "$BIN_B" "$outB") || exit 3
  else ol=B_then_A; sB=$(time_one "$BIN_B" "$outB") || exit 3; sA=$(time_one "$BIN_A" "$outA") || exit 3; fi
  px=$(python3 -c "print(f'{$sA/$sB:.6f}')")
  orc=SKIP
  if [[ $i -eq 1 || $i -eq $N ]]; then orc=$(oracle "$outA" "$outB" "$tag"); fi
  echo -e "${i}\t${ol}\t${sA}\t${sB}\t${px}\t${orc}" | tee -a "$RES"
  # keep disk small: drop BAMs for non-oracle rounds
  if [[ $orc == SKIP ]]; then rm -f "${outA}Aligned.out.bam" "${outB}Aligned.out.bam"; fi
  rm -rf "${outA}tmp" "${outB}tmp"
done
echo "end=$(date -Is)" >> "$META"
python3 "$RUN/scripts/summarize_mouse_cert.py" "$RES" "$OUTDIR/summary.json" "$SEED" "$N" "$LAB_A" "$LAB_B"
echo DONE
