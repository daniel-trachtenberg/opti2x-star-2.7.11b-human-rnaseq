# opti2x-star-2.7.11b-human-rnaseq

STAR 2.7.11b (alexdobin/STAR `b1edc1208d91a53bf40ebae8669f71d50b994851`, MIT) with Opti2x serial-alignment optimizations applied as commits on top:

1. `STAR 2.7.11b unmodified` — upstream pin.
2. Prior public patches H1/H2/H8/H10/H13 (from `daniel-trachtenberg/opti2x-star-2.7.11b` @ `e81942da`).
3. HH1 — stitch fork pool + closed-form score updates.
4. HH4 — junction-locus scan score-equivalent early-stop + geometric prefilter before `copyStitchCore`.

**Status: QUALIFIED** on contract `star-2.7.11b-serial-align-human-rnaseq-v1`:
N=30 paired rounds (seed 20261006), median **2.182×**, exp(mean log) 2.179×, one-sided lower 95% **2.162×** vs clean 2.7.11b; oracle BAM body identical.

**Scope (important):** serial envelope only (`--runThreadN 1`, OMP=1, `taskset -c 0`, `--genomeLoad NoSharedMemory`, warm cache);
human SRR393763 first 20k PE reads vs an hg38 chr21+chr22 index. Not claimed: multi-threaded runs, full GRCh38, STARsolo, genomeGenerate.
HH1/HH4 use static locals that assume a single mapping thread — do **not** use this build with `--runThreadN > 1`.

GSE26248 (cited by Prof. Zhang) is *Mus musculus* retina, not human; it is a secondary continuity track — see `opti2x/REPRO_ZHANG.md`.

Reports, patch, attestation, evidence and scripts: `opti2x/`. Build: `cd source && make STAR`.
The earlier fixture-era repo `opti2x-star-2.7.11b` (NOT_YET claim) is left unchanged.
