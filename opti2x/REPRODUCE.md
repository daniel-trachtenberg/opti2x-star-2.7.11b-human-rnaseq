# REPRODUCE

1. Build clean STAR 2.7.11b and apply `best_patch/optimized.patch` (or use `STAR.hh4`).
2. Index: hg38 chr21+chr22 under `indexes/human/hg38_chr21_22`.
3. Reads: first 20k PE of SRR393763.
4. Envelope: `taskset -c 0 env OMP_NUM_THREADS=1 OMP_THREAD_LIMIT=1 STAR --runThreadN 1 --genomeLoad NoSharedMemory ...`
5. Cert script: `scripts/cert_n30_pair.sh` seed 20261006.
