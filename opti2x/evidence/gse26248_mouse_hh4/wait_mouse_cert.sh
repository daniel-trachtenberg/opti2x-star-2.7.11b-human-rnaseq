#!/usr/bin/env bash
# Durable waiter: waits for cert driver; if it died before DONE, resumes (resumable script); writes DONE.json.
RUN=/workspace/opti2x/runs/star-2.7.11b-human-rnaseq
O=$RUN/measurements/gse26248_mouse_hh4
for attempt in 1 2 3; do
  while pgrep -f 'cert_mouse_gse26248.sh' >/dev/null; do sleep 30; done
  if grep -q '^DONE' $O/driver.log; then break; fi
  echo "waiter: driver not running and no DONE; resuming attempt $attempt $(date -Is)" >> $O/waiter.log
  bash $RUN/scripts/cert_mouse_gse26248.sh $RUN/baseline/STAR baseline $RUN/deliverable-QUALIFIED/STAR.hh4 hh4 $O 30 >> $O/driver.log 2>&1
done
python3 - <<PY
import json; from pathlib import Path
o=Path("$O"); s=json.loads((o/"summary.json").read_text()) if (o/"summary.json").exists() else None
(o/"DONE.json").write_text(json.dumps({"done": s is not None, "summary": s}, indent=2)+"\n")
PY
echo "waiter finished $(date -Is)" >> $O/waiter.log
