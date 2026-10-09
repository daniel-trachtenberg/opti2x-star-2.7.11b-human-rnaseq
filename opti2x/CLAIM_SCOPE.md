# Claim scope — STAR 2.7.11b human RNA-seq Wave 2 (QUALIFIED)

Contract: `star-2.7.11b-serial-align-human-rnaseq-v1`

PRIMARY: serial PE align of Homo sapiens SRR393763 first 20k reads vs hg38 chr21+chr22 STAR index.
Serial envelope: `--runThreadN 1`, OMP=1, `taskset -c 0`, `--genomeLoad NoSharedMemory`, warm cache.

QUALIFIED: N=30 paired median 2.1824×; exp(mean log) 2.1792×; lower_95 2.1624×.

Stack: public fixture-era H1/H2/H8/H10/H13 + HH1 (fork pool / closed-form) + **HH4** (junction-locus scan early-stop + geometric prefilter + static finalize).

NOT claimed: multi-thread, STARsolo, genomeGenerate-only, full GRCh38, package-wide, mouse GSE26248 as primary gate.
GSE26248 is mouse retina (Zhang citation continuity only).
