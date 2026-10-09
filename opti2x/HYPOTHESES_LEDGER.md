# Hypotheses — STAR 2.7.11b human RNA-seq (serial)

Contract: `star-2.7.11b-serial-align-human-rnaseq-v1`
Public candidate already carries fixture-era H1/H2/H8/H10/H13 (stitch/copy/extend).
Primary target: paths that dominate **real** PE RNA-seq under chrom-subset hg38 chr21+22
(seed/MMP, splice junctions, sorting, BAM write, genome load) — not only fixture stitch wins.

## Prior art (public candidate @ e81942da)
| ID | Status | Notes |
|----|--------|-------|
| H1 Transcript by-ref stitchWindowAligns | accepted (public) | fixture ~1.41× alone |
| H2 partial Transcript copy | accepted (public) | |
| H8 skip-empty assign + memcpy slots | accepted (public) | |
| H10 extendAlign mmBreak hoist | accepted (public) | |
| H13 copyStitchCore include forks | accepted (public) | |
| H15–H25 Wave3 | rejected | <1.03× or regress on fixture |

## Human-track plan (original IDs; experiments reused HH1–HH3 names — see outcomes)
| ID | Target | Status |
|----|--------|--------|
| Profile human 20k | exclusive % stitch/extend/SA | **done** (stitchAlign 53%) |
| SA / compareSeq block | seed search | deferred (only ~1% exclusive on this workload) |
| seed early-exit | map-rate risk | not pursued (oracle gate; low Amdahl) |
| BAM/BGZF | I/O | deferred (not top exclusive) |
| Genome load | fixed cost | deferred |
| SJ motif specialize | mapped-enriched | tried as HH2/HH3 → **REJECT** regress |
| Integrate + oracle | HH1 stack | **done** (KEEP HH1; NOT_YET overall) |
| HH8 fairness | no native/threads/shm claim | **locked** / met |

## Measurement notes
- Random 200k PE hung ~9+ min at read ~64050 (pathological multimapper). Phase A uses **20k** first-N subset (completes ~195s baseline, unique map ~5%).
- Mapped-enriched set built separately for profiling stitch/SJ density.
- Index has **no sjdb** (sjdbGTFfile=-); annotated SJ path dead on this primary.

## Experiment outcomes (human track Wave 1)

| ID | Change | vs parent | vs baseline (20k N=3) | Oracle | Decision |
|----|--------|----------:|----------------------:|--------|----------|
| HH1 | H20 fork pool + closed-form Score+= + equal-gap ptr walk + static trExtend + first-align closed-form | ~1.02–1.04× on 5k vs public | **1.874×** median (1.858–1.906); map 5.05% identical | PASS BAM body vs baseline | **KEEP** |
| HH2 | HH1 + packed SJ motif + H16 extend ±1 specialize | **0.927×** median vs HH1 (regress) | n/a (slower than HH1) | PASS vs HH1/pub | **REJECT** |
| HH3 | HH1 + junction Score1 ptr-walk + packed motif (NO extend specialize) | **0.973×** median vs HH1 on 5k (regress) | n/a | PASS | **REJECT** |

Public candidate alone: **1.847×** median on human 20k (Phase A). HH1 median **1.874×** vs clean baseline → ~1.015× incremental vs public. Gap to 2× from HH1 ≈1.067×.
HH1 20k walls: baseline [191.48, 188.80, 189.61]; hh1 [102.16, 99.04, 102.02].

### Stacked 20k N=3 (pub/HH1/HH2) @ 2026-10-06 ~11:01 PT
- pub: [103.54, 104.62, 103.81]
- hh1: [100.97, 101.64, 101.48] → vs pub median **1.025×** (confirms KEEP)
- hh2: [110.50, 109.68, 109.29] → vs HH1 median **0.927×** REJECT
- Oracles: HH1/HH2 vs pub PASS

## Wave 2 slate (structural stitchAlign — start 2026-10-06 ~17:31 PT)

Parent stack: **HH1 KEEP**. Skip motif/extend micros (HH2/HH3). Need ~1.067× more e2e ≈ ~15% of stitchAlign exclusive removed.

| ID | Hypothesis | Status |
|----|------------|--------|
| HH4 | Score-equivalent junction-locus scan early-stop (TODO bound) + geometric prefilter before copyStitchCore + static finalize `trAstep1` | **in progress** |
| HH5 | Transactional stitch: mutate-in-place + compact undo / exclude-first where safe; avoid copy on failed stitch | planned |
| HH6 | Optimistic score-bound prune of include/exclude recursion (prove vs wTr/maxScoreMate; no chimeric) | planned |
| HH7 | Compact POD stitch delta / reduce stitchWindowAligns redundant walks feeding stitchAlign | planned if HH4–6 saturate |
| — | packed SJ motif / extend ±1 / junction motif micros | **SKIP** (HH2/HH3 REJECT) |

## Terminal status (Wave 1)

**NOT_YET** — best human 20k median **1.874×** (HH1). Gap ≈1.067×. Deliverable: `deliverable-NOT_YET/`. Suggested repo `opti2x-star-2.7.11b-human-rnaseq` (no push). Wave 2 in progress.

## Wave 2 outcomes (in progress — resume 2026-10-06 ~18:22 PT)

| ID | Change | vs parent | vs clean baseline (20k) | Oracle | Decision |
|----|--------|----------:|------------------------:|--------|----------|
| HH4 | HH1 + junction-locus scan score-equivalent early-stop + geometric prefilter before copyStitchCore + static finalize `trAstep1` | **≈1.11×** median vs HH1 (N=3; walls HH1 [110.629,111.099,110.629] / HH4 [99.757,99.098,99.842]) | prior `timing20k_vs_base` median **≈2.16×** (base [210.350,208.715,211.588] / HH4 [101.159,96.744,97.200]; cold warmup 348s ignored). **Clean warm N=3 remeasure in flight** (`timing20k_vs_base_clean`) | ORACLE_OK vs HH1 and vs baseline (prior) | **tentative KEEP** pending clean certify |
| HH5 | HH4 + score-bound prune | **≈0.977×** median vs HH4 on 5k N=2 (hh4 [51.414,52.944] / hh5 [53.577,53.202]); ORACLE_OK | n/a (slower than HH4) | PASS vs HH4 | **REJECT** (do not stack) |

HH4 binary sha256: `e6d576dccaed247aeca539b7d20f862b9db1d505f4b146624b72bc23589fde3f`
HH1 parent sha256: `0047526883b20aff80431a4f6a3a568af0f39d636c205c40a200b5f60489e4b0`
Clean baseline sha256: `0f7b41f13bcaaea4168512f4fc57e7b1eab955e83aa6ace399198d2b3f3fcb08`

### Wave 2 slate update
| ID | Status |
|----|--------|
| HH4 | **tentative KEEP** — finish clean N≥3 then N=30 if median≥2.0 |
| HH5 | **REJECT** (~0.98× vs HH4) |
| HH6/HH7 | only if N=30 lower_95 fails narrowly |

### Clean warm N=3 confirm @ 2026-10-06 ~18:41 PT (`timing20k_vs_base_clean`)
- warmup base_w1=216.914s (warm; ignore for ×)
- base: [213.081, 213.363, 212.567]
- HH4: [98.728, 98.328, 96.210]
- paired_x: [2.158, 2.170, 2.209]; **median 2.170×**; mean 2.179×
- ORACLE_OK (sorted BAM body); map% unique 5.05% / too-short 94.59% identical
- **HH4 KEEP** — gate median ≥2.0 cleared → launch formal N=30


## Wave 2 terminal (QUALIFIED) — auto-packaged

N=30 median 2.182398×; exp(mean log) 2.179177×; lower_95 2.162436×.
Deliverable: `deliverable-QUALIFIED/`
