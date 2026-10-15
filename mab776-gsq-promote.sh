#!/bin/sh
# mab776 (10-15): GSQ-RCO 3.5 PROMOTE_MIN sweep with RAM_RESIDENT=1 (PM6 = 37.0 tok/s coding);, lossless, live args/env + borrowed Maya-M draft (the 33.5 tok/s baseline):
#   base | RAM_RESIDENT=1 + PROMOTE_MIN=6 (Maya's 4090D+128GB recipe) | + PREFETCH_N=1 | + VRAM_EVICT=lru
# Each arm: bench 30k/127k + the 4 sampled coding prompts twice; smoke on base (= v1.1.11's quick test).
cd "$(dirname "$0")" || exit 1
T="/media/mab776/nvme 2To/models/maya/slots/trial"; mkdir -p "$T"
ARGS=$(python3 -c "import json;a=json.load(open('maya-glm.json'))['args'];print(' '.join(a[4:]))")
ENV=$(python3 -c "import json;e=json.load(open('maya-glm.json'))['env'];e['STRATA_GLM_SLOT_DIR']='/slots/trial';e.pop('STRATA_GLM_SLOT_KEEP',None);print(' '.join(k+'='+v for k,v in e.items()))")
D=STRATA_GLM_MTP_GGUF=/models/mtp-drafts/Maya-M-nextn-blk45.gguf
arm() {  # LABEL ENV...
  L=$1; shift; echo "=== $L"; rm -f "$T"/slot-*
  MAYA_PACK=GSQ-RCO-3.5bit MAYA_GPUS=0,1 MAYA_ARGS="$ARGS" ./mab776-tune.sh "$L" $ENV $D "$@" || return
  grep -E "glm-pack" -A1 maya-trial.json | tail -1
  grep -iE "glm split:|RAM tier|expert pool|resident|prefetch|promote|evict" maya-trial.log | grep -v "^glm kv" | head -10 | cut -c1-170
  [ "$L" = G35d-base ] && python3 mab776-smoke.py http://127.0.0.1:8325
  python3 mab776-dflash-sweep.py http://127.0.0.1:8325 "$L-warm" base | tail -1
  python3 mab776-dflash-sweep.py http://127.0.0.1:8325 "$L" base | tail -1
  grep "glm stat\|decode .* ms/tok" maya-trial.log | tail -1 | sed 's/.*decode/decode/' | cut -c1-220
}
for pm in 4 8 12; do arm G35p-res-pm$pm STRATA_GLM_RAM_RESIDENT=1 STRATA_GLM_PROMOTE_MIN=$pm; done
docker stop -t 60 maya-trial >/dev/null 2>&1; rm -rf "$T"; echo done
