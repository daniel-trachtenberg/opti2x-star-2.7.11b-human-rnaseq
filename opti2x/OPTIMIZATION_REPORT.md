# OPTIMIZATION_REPORT — STAR 2.7.11b human RNA-seq Wave 2

## Status: QUALIFIED

| Metric | Value |
|--------|------:|
| Clean N=3 median (pre-cert) | 2.170× |
| N=30 median paired × | 2.182398 |
| exp(mean log) × | 2.179177 |
| lower_95 × | 2.162436 |
| Oracle | BAM body PASS (round-1 cert + prior N=3) |

## Stack
- Baseline: alexdobin/STAR 2.7.11b `b1edc120…`
- Prior public opti2x-star-2.7.11b patches + **HH1 KEEP** + **HH4 KEEP**
- HH2/HH3/HH5 REJECT

## HH4
Score-equivalent junction-locus scan early-stop + geometric prefilter before copyStitchCore + static finalize trAstep1.
See evidence/ADVERSARIAL_HH4.md.

## Suggested repo
`opti2x-star-2.7.11b-human-rnaseq` — do not overwrite old fixture NOT_YET claim dishonestly.
