#!/bin/sh
# mab776: the post-v1.1.0-build plan (Marc 10-12) - run ONLY on Marc's go, with the GPUs free (mode page All off):
#   1. MTP baseline (= today's maya-glm.json config): strata_bench 26k/118k + mab776-dflash-sweep.py "base"
#   2. DFlash2 drafter instead of MTP: same bench + the draft-length sweep (spec 2..8, then cum 0.8/0.95 at spec 5)
# --parallel is NOT tested: it turns the drafter off (Marc). Results: tune-results.jsonl + dflash-sweep.jsonl.
# The maya-trial container (mab776-tune.sh) refuses to start while maya-glm or strata-coder runs.
cd "$(dirname "$0")" || exit 1
E="STRATA_GLM_SLOT_DIR=/slots STRATA_GLM_USAGE=/slots/usage-maya-s.txt STRATA_GLM_KV_INT8=1 STRATA_GLM_CPU_SHARED=1"
DF="STRATA_GLM_DFLASH=/models/dflash2/GLM-5.3-Flash-DFlash2-Q4_K_M.gguf STRATA_GLM_NO_MTP=1"
cp maya-glm.json maya-trial.json && python3 -c "
import json;c=json.load(open('maya-trial.json'));c['log']='/maya/maya-trial.log';json.dump(c,open('maya-trial.json','w'),indent=1)"
echo "== 1. MTP baseline"
MAYA_GPUS=0,1 ./mab776-tune.sh v110-mtp $E || exit 1
python3 mab776-dflash-sweep.py http://127.0.0.1:8325 v110-mtp base
echo "== 2. DFlash2"
MAYA_GPUS=0,1 ./mab776-tune.sh v110-dflash2 $E $DF || exit 1
grep -E "glm dflash" maya-trial.log | head -5 | cut -c1-160
python3 mab776-dflash-sweep.py http://127.0.0.1:8325 v110-dflash2
docker stop -t 90 maya-trial >/dev/null
echo "done - GPUs left free (the stack is NOT restarted; Marc presses the mode page)"
