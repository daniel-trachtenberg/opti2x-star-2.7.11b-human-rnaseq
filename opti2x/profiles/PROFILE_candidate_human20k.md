# Public candidate — human 20k PE vs hg38 chr21+22 (serial)

**Binary:** `candidate/STAR` sha256 `7ae1f9f0…` (public e81942da)  
**Tool:** `perf record -g --call-graph dwarf -F 499`  
**Envelope:** `--runThreadN 1`, OMP=1, `taskset -c 0`, NoSharedMemory, warm cache  
**Date:** 2026-10-06 PT

## Exclusive hotspots (flat)

| Rank | Symbol | Exclusive % |
|-----:|--------|------------:|
| 1 | `stitchAlignToTranscript` | **53.00** |
| 2 | `stitchWindowAligns` | 13.14 |
| 3 | `extendAlign` | 9.52 |
| 4 | `Transcript::copyStitchCore` | 6.70 |
| 5 | `assignAlignToWindow` | 3.05 |
| 6 | `Transcript::Transcript()` | 2.77 |
| 7 | `stitchPieces` | 1.42 |
| 8 | `compareSeqToGenome` | 1.18 |

## Notes vs fixture-era profile

On the frozen fixture, `stitchAlignToTranscript` was ~24% exclusive after Wave2. On this human chrom-subset RNA-seq workload (5% unique map / 95% too-short), stitchAlign dominates **~53%**. SA/`compareSeqToGenome` is only ~1% here — seed search is not the wall bottleneck after the public stitch/copy patches; residual cost is still **splice-aware stitch/extend**.

Amdahl: removing 15% of stitchAlign alone ⇒ ~1.086× on candidate ⇒ ~2.00× e2e vs baseline at the observed 1.847× public median. Achieving that without changing alignment semantics remains the open gap.
