# Phase A notes — Zhang GSE26248 repro

## Organism correction
GSE26248 (RUM 2011 paper) is **Mus musculus neural retina**, not Homo sapiens.
- Samples: GSM663550–GSM663553 (retina_2 months lanes 1–4)
- Experiments: SRX088978–SRX088981
- Runs: SRR327045, SRR342457, SRR342458, SRR327047
- Layout: PAIRED, ~25–26M × 120bp PE per lane (~96M PE total across 4 lanes)
- Study genome: mm9 (NCBI37); we use **mm10/GRCm38** or chrom-subset for practicality (document in CLAIM_SCOPE)
- BioProject: PRJNA135077

## Representative run selected
**SRR327045** (GSM663550 / SRX088978) — first lane, 26.55M PE reads.

## Subset policy
Full lane FASTQ ~5 GB compressed. For Phase A we stream a timed subset (≥5–30s serial wall) that still stresses splice-aware align.
