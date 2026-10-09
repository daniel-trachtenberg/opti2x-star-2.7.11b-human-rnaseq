# REPRO_ZHANG — Opti2x STAR 2.7.11b vs public candidate on GSE26248 + human RNA-seq

**Date:** 2026-10-06 (PT)  
**Run root:** `/workspace/opti2x/runs/star-2.7.11b-human-rnaseq/`  
**Public candidate:** https://github.com/daniel-trachtenberg/opti2x-star-2.7.11b @ `e81942dae047b0ac103f08edfbad37a54cf3f362`  
**Clean pin:** alexdobin/STAR `2.7.11b` / `b1edc1208d91a53bf40ebae8669f71d50b994851`

## Critical organism note

**GSE26248 is Mus musculus neural retina (RUM 2011 paper), not Homo sapiens.**  
Zhang’s citation of “human RNA-seq” for this accession is incorrect. We still reproduce the cited accession faithfully, and measure a separate **human** track.

| Track | Organism | Source | Role |
|-------|----------|--------|------|
| Zhang / GSE26248 | *Mus musculus* | SRR327045 (GSM663550 / SRX088978), 200k PE subset of ~26.5M | Continuity with Zhang citation |
| Human primary | *Homo sapiens* | SRR393763 (SRP010061 K562 polyA RNA-Seq), 200k PE subset | Primary Opti2x contract workload |

## Fair envelope (both binaries)

- `--runThreadN 1`
- `OMP_NUM_THREADS=1`, `OMP_THREAD_LIMIT=1`
- `taskset -c 0`
- `--genomeLoad NoSharedMemory`
- Timing: process start→exit; warm page cache
- Same `-O3 -std=c++11 -fopenmp` toolchain (g++ 14.2.0); no `-march=native` as claim win

## Genomes / indexes (claim-scoped)

| Index | Contents | Size on disk | Notes |
|-------|----------|-------------:|-------|
| Mouse | mm10 chr1+chr2+chr19 | ~4.1G | Chrom-subset of study genome (original paper used mm9 whole). Unique map ~17% on random 200k PE. |
| Human | hg38 chr21+chr22 | ~811M | Chrom-subset for RAM/disk. Full primary GRCh38 not loaded (would need ~25–35G index + ~30G RAM). |

## Binaries

| Role | sha256 | version |
|------|--------|---------|
| Baseline clean | `0f7b41f13bcaaea4168512f4fc57e7b1eab955e83aa6ace399198d2b3f3fcb08` | 2.7.11b |
| Candidate (public patched tree) | `7ae1f9f0f41e38a0372c1c4374a270ddbbc06aa2715d267f63390acd5ede6ca0` | 2.7.11b |

Candidate patches (from public `opti2x/best_patch/combined.patch`): H1, H2, H8, H10, H13 (fixture-era stitch/copy/extend wins).

## Mouse (GSE26248) results — N=3 paired after 1 warmup

Workload: 200000 PE reads from SRR327045; index mm10_chr1_2_19.

| Round | baseline wall_s | candidate wall_s | × |
|------:|----------------:|-----------------:|--:|
| 1 | 296.798 | 213.234 | 1.392 |
| 2 | 298.102 | 219.152 | 1.360 |
| 3 | 300.741 | 214.424 | 1.403 |

- **Median paired speedup: 1.392×** (≈ +39%, not ~8%)
- Unique map: 17.28% (36243 reads); 81% “too short” (chrom-subset limitation)
- Oracle spot-check: unique/multi counts identical baseline vs candidate

### Interpretation vs Zhang’s ~8%

Zhang’s ~1.08× likely used different genome breadth, read depth, threading, or binary/build. Under this serial fair envelope on a chrom-subset of the cited GEO accession, the published Opti2x candidate is **substantially faster than 8%** (~1.39×). That does **not** yet establish ≥2× on a human primary contract.

## Human results — N=3 paired after 1 warmup

Workload: **20000** PE reads (first-N of SRR393763); index hg38_chr21_22.

> **Note:** Random 200k PE hung with FASTQ position frozen near read `SRR393763.64050` for >9 min at 100% CPU (pathological multimapper under chrom-subset). Aborted; Phase A uses a completing 20k subset (≥5–30s requirement easily met: ~197s baseline). Unique map 5.05% (chr21+22 subset limitation); 94.59% “too short”.

| Round | baseline wall_s | candidate wall_s | × |
|------:|----------------:|-----------------:|--:|
| 1 | 198.863 | 107.665 | 1.847 |
| 2 | 196.947 | 107.710 | 1.828 |
| 3 | 198.164 | 107.235 | 1.848 |

- **Median paired speedup: 1.847×** (public candidate vs clean 2.7.11b)
- Unique map: 5.05% (1011 reads); oracle spot-check: unique counts identical
- Gap to 2×: ≈1.083× more required on this primary

### Interpretation

Under the serial fair envelope on hg38 chr21+22, the published Opti2x candidate is **~1.85×** on this human RNA-seq subset — stronger than the mouse Zhang continuity track (1.39×) and close to, but **not yet**, the 2× QUALIFIED gate. Chrom-subset and 20k-read limits are explicit claim scope.


## Artifacts

- `measurements/phase_a/MOUSE_SUMMARY.json
- `measurements/phase_a/HUMAN_SUMMARY.json``
- `measurements/phase_a/mouse/`, `measurements/phase_a/human/`
- `phase_a/NOTES.md`, `phase_a/prjna135077_runs.tsv`
