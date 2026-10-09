# Adversarial review — HH4 stitch scan early-stop + geometric prefilter

**Subject:** `experiments/HH4_stitch_scan_earlystop_prefilter` on HH1 parent  
**Binary sha256:** `e6d576dccaed247aeca539b7d20f862b9db1d505f4b146624b72bc23589fde3f`  
**Files touched vs HH1:** `stitchAlignToTranscript.cpp`, `stitchWindowAligns.cpp`  
**Fairness lock:** `--runThreadN 1`, OMP=1, `taskset -c 0`, `NoSharedMemory` (NLWP=1 — static locals OK)

## Changes

1. **Junction-locus scan early-stop** (`stitchAlignToTranscript.cpp`): after each candidate locus in the rightward scan, break if an optimistic upper bound on remaining Score2 cannot strictly beat `maxScore2`.
2. **Geometric prefilter** (`stitchWindowAligns.cpp`): before `copyStitchCore`, detect include-impossible cases that `stitchAlignToTranscript` would return as `dScore ≤ -1000001` and skip the copy.
3. **Static finalize `trAstep1`:** NLWP=1 reuse of finalize Transcript (same pattern as HH1 `trExtend`).

## Proof sketch — early-stop is score-equivalent

Loop invariant (scan phase, after processing locus `jR1`):
- `Score1` is the cumulative match/MM delta vs the two genome paths (donor vs acceptor).
- Per step the two updates are mutually exclusive: `Score1` changes by at most `+scoreMatch` (or `−scoreMatch`, or 0).
- `Score2 = Score1 + jPen1` when `Del ≥ alignIntronMin`, else `Score2 = Score1`.
- Motif penalties under defaults: `scoreGapGCAG=-4`, `scoreGapATAC=-8`, `scoreGapNoncan=-8`; GTAG/CTAC use `jPen1=0`. So `jPen1 ≤ 0` and `Score2 ≤ Score1`.
- `maxPenUB = max(0, scoreGapGCAG, scoreGapATAC, scoreGapNoncan)` when intron-sized (else 0). Captures the best possible motif contribution (including GTAG/CTAC = 0). If a user raises a motif penalty above 0, UB still holds.

Bound after locus `jR1` with `rem = (rBend−rAend−1) − jR1` remaining steps:
```
∀ future loci: Score2_future ≤ Score1 + scoreMatch·rem + maxPenUB
```
Update rule uses **strict** `maxScore2 < Score2`. Therefore if
`Score1 + scoreMatch·rem + maxPenUB ≤ maxScore2`, no future locus can update `maxScore2` / `jR` / `jCan` / `jPen`. Breaking yields the identical chosen junction as a full scan.

Post-scan flush / repeat-length / scoring uses only the chosen `(jR,jCan,jPen)` — unchanged.

**Residual risk:** if `scoreMatch` were negative (it is not under STAR defaults / Parameters), the per-step UB would be wrong. Contract uses stock scoring.

## Proof sketch — geometric prefilter is outcome-equivalent

Prefilter only fires when `nExons > 0` and the sjdb simple-stitch predicate is false (that path must still call `stitchAlign` — never prefiltered). Cases mirrored from `stitchAlignToTranscript` early returns:

| Prefilter | stitchAlign return | Condition |
|-----------|-------------------|-----------|
| `-1000010` | line 12–13 | `nExons ≥ MAX_N_EXONS` |
| `-1000001` | `rBend ≤ rAend` | same-frag |
| `-1000002` | `gBend ≤ gAend` | same-frag |
| `-1000003` | `Del > alignIntronMax` | after identical r-overlap shift; `Del = gGap−rGap` when `gGap>rGap` |
| `-1000004` | mates gap | `alignMatesGapMax` |
| `-1000008` | mates protrusion else | negation of protrusion predicate |

When prefilter rejects: `dScore ≤ -1000001` → include branch skipped; `trAi` never mutated (no `copyStitchCore`); exclude recursion still sees parent `trA`. Same control-flow outcome as calling stitchAlign and getting the reject code after a wasted copy.

**Not prefiltered (must call):** sjdb simple stitch; first exon (`nExons==0`); all paths that can return a live score / mutate exons. Conservative: false-negative on prefilter only costs a copy; false-positive would break oracle — oracle BAM body PASS is the empirical seal.

## Static `trAstep1`

Under contract NLWP=1 there is no concurrent finalize. Same rationale as HH1 `static Transcript trExtend`. Not a correctness change for serial envelope; do not claim under multi-thread.

## Empirical seal

- Prior `timing20k_vs_hh1` and `timing20k_vs_base`: **ORACLE_OK** (sorted BAM body).
- Map rates identical: unique 5.05%, too-short 94.59%.
- Clean warm N=3 / N=30 remeasure is the certification gate for ≥2×.

## Verdict

Early-stop and geometric prefilter are **score-/outcome-equivalent** under stock Parameters and the serial envelope. Safe to KEEP if timing certifies; do not stack HH5.
