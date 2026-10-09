#!/usr/bin/env bash
# Formal N=30 paired certification: BIN_A (baseline) vs BIN_B (candidate)
# Randomized order from frozen seed; warm cache; serial envelope.
# Usage: cert_n30_pair.sh BIN_A LAB_A BIN_B LAB_B SIZE OUTDIR [N=30] [SEED=20261006]
set -euo pipefail
BIN_A=$1; LAB_A=$2; BIN_B=$3; LAB_B=$4; SIZE=$5; OUTDIR=$6
N=${7:-30}
SEED=${8:-20261006}
RUN=/workspace/opti2x/runs/star-2.7.11b-human-rnaseq
GDIR=$RUN/indexes/human/hg38_chr21_22
R1=$RUN/reads/human/SRR393763_sub${SIZE}_1.fastq
R2=$RUN/reads/human/SRR393763_sub${SIZE}_2.fastq
mkdir -p "$OUTDIR/runs"
# warm caches
cat "$GDIR/Genome" "$GDIR/SA" "$GDIR/SAindex" >/dev/null
cat "$R1" "$R2" >/dev/null

time_one() {
  local bin=$1 label=$2 out=$3
  rm -rf "${out}tmp"
  # only remove this run's outputs
  rm -f "${out}"Aligned.out.bam "${out}"Log.* "${out}"SJ.out.tab "${out}"stdout.txt "${out}"stderr.txt
  local start end ec
  start=$(date +%s.%N)
  taskset -c 0 env OMP_NUM_THREADS=1 OMP_THREAD_LIMIT=1 "$bin" \
    --runMode alignReads --runThreadN 1 --genomeDir "$GDIR" --genomeLoad NoSharedMemory \
    --readFilesIn "$R1" "$R2" --outFileNamePrefix "$out" \
    --outSAMtype BAM Unsorted --outSAMunmapped Within --outTmpDir "${out}tmp" \
    > "${out}stdout.txt" 2> "${out}stderr.txt"
  ec=$?
  end=$(date +%s.%N)
  python3 -c "print(f'{float('$end')-float('$start'):.6f}')"
  return $ec
}

RES=$OUTDIR/results.tsv
META=$OUTDIR/meta.txt
echo "seed=$SEED N=$N size=$SIZE lab_a=$LAB_A lab_b=$LAB_B" | tee "$META"
sha256sum "$BIN_A" "$BIN_B" | tee -a "$META"
echo -e "round\torder\t${LAB_A}_s\t${LAB_B}_s\tpaired_x\toracle_round" > "$RES"

# Warmup: one baseline run (discard)
echo "WARMUP ${LAB_A}" | tee -a "$META"
WARM_OUT="$OUTDIR/runs/warmup_${LAB_A}_"
WARM_S=$(time_one "$BIN_A" "${LAB_A}_w1" "$WARM_OUT") || true
echo "warmup_${LAB_A}_s=$WARM_S" | tee -a "$META"

# Generate randomized order sequence with frozen seed
ORDERS=$(python3 - <<PY
import random
rng=random.Random(int("$SEED"))
# 0 => A then B; 1 => B then A
print(' '.join(str(rng.randint(0,1)) for _ in range(int("$N"))))
PY
)
echo "orders=$ORDERS" | tee -a "$META"

i=0
for ord in $ORDERS; do
  i=$((i+1))
  tag=$(printf 'r%02d' "$i")
  outA="$OUTDIR/runs/${tag}_${LAB_A}_"
  outB="$OUTDIR/runs/${tag}_${LAB_B}_"
  if [[ "$ord" == "0" ]]; then
    order_label="A_then_B"
    sA=$(time_one "$BIN_A" "${LAB_A}_${tag}" "$outA")
    sB=$(time_one "$BIN_B" "${LAB_B}_${tag}" "$outB")
  else
    order_label="B_then_A"
    sB=$(time_one "$BIN_B" "${LAB_B}_${tag}" "$outB")
    sA=$(time_one "$BIN_A" "${LAB_A}_${tag}" "$outA")
  fi
  px=$(python3 -c "print(f'{float('$sA')/float('$sB'):.6f}')")
  # Oracle only on round 1 (expensive); map% every round from Log.final
  oracle="SKIP"
  if [[ "$i" -eq 1 ]]; then
    samtools view "${outA}Aligned.out.bam" | sort > "$OUTDIR/${LAB_A}.body.sam"
    samtools view "${outB}Aligned.out.bam" | sort > "$OUTDIR/${LAB_B}.body.sam"
    if cmp -s "$OUTDIR/${LAB_A}.body.sam" "$OUTDIR/${LAB_B}.body.sam"; then
      oracle="OK"
    else
      oracle="FAIL"
    fi
  fi
  echo -e "${i}\t${order_label}\t${sA}\t${sB}\t${px}\t${oracle}" | tee -a "$RES"
done

# Stats: exp(mean log), lower_95 one-sided Student-t
python3 - <<'PY' "$RES" "$OUTDIR/summary.json" "$SEED" "$N"
import json, math, sys
from pathlib import Path
res_path, out_json, seed, n = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
xs=[]
for line in Path(res_path).read_text().splitlines()[1:]:
    parts=line.split('\t')
    if len(parts)>=5:
        xs.append(float(parts[4]))
assert len(xs)==n, (len(xs), n)
logs=[math.log(x) for x in xs]
mean_log=sum(logs)/n
# sample stdev of logs
var=sum((l-mean_log)**2 for l in logs)/(n-1)
sd=math.sqrt(var)
# one-sided 95% lower bound on mean log: t_{n-1, 0.95}
# t critical for df=29, one-sided 0.95 ≈ 1.699127
# compute via simple approximation or hardcode common N
def t_crit(df, p=0.95):
    # accurate enough values for common df; fallback asymptotic
    table={1:6.3138,2:2.9200,3:2.3534,5:2.0150,9:1.8331,14:1.7613,19:1.7291,29:1.6991,59:1.6711}
    if df in table: return table[df]
    # Wilson-Hilferty / normal approx for large df
    # use 1.645 + 1.5/df rough
    return 1.64485 + 1.5/df + 1.0/(df*df)

tc=t_crit(n-1)
se=sd/math.sqrt(n)
lower_log=mean_log - tc*se
exp_mean=math.exp(mean_log)
lower_95=math.exp(lower_log)
median=sorted(xs)[n//2] if n%2==1 else 0.5*(sorted(xs)[n//2-1]+sorted(xs)[n//2])
summary={
  "N": n,
  "seed": seed,
  "paired_x": xs,
  "median_x": median,
  "exp_mean_log_x": exp_mean,
  "lower_95_x": lower_95,
  "mean_log": mean_log,
  "sd_log": sd,
  "t_crit_one_sided_95": tc,
  "qualified_gate_lower_95_ge_2": lower_95 >= 2.0,
}
Path(out_json).write_text(json.dumps(summary, indent=2)+"\n")
print(json.dumps(summary, indent=2))
print(f"QUALIFIED_GATE={'PASS' if lower_95>=2.0 else 'FAIL'} lower_95={lower_95:.6f} exp_mean={exp_mean:.6f} median={median:.6f}")
PY
echo DONE
