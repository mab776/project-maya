#!/bin/sh
# mab776 (10-16): v1.1.13 test on GSQ-RCO 3.5 with the served config (maya-glm.json args + env), bench 8k/30k/127k +
# smoke + the 4 sampled coding prompts twice, per arm:
#   base = served (v1.1.13 evicts the spares by recency with one conversation = new default)
#   least = STRATA_GLM_VRAM_EVICT=least (v1.1.12's aged counts) | cpush0 = STRATA_GLM_CPU_SHARED=0 (a CPU pool per GPU)
cd "$(dirname "$0")" || exit 1
T="/media/mab776/nvme 2To/models/maya/slots/trial"; mkdir -p "$T"
ARGS=$(python3 -c "import json;a=json.load(open('maya-glm.json'))['args'];print(' '.join(a[4:]))")
ENV=$(python3 -c "import json;e=json.load(open('maya-glm.json'))['env'];e['STRATA_GLM_SLOT_DIR']='/slots/trial';e.pop('STRATA_GLM_SLOT_KEEP',None);print(' '.join(k+'='+v for k,v in e.items()))")
arm() {  # LABEL ENV...
  L=$1; shift; echo "=== $L"; rm -f "$T"/slot-*
  MAYA_DEPTHS="8000 30000 127000" MAYA_GPUS=0,1 MAYA_ARGS="$ARGS" ./mab776-tune.sh "$L" $ENV "$@" || return
  grep -E "glm-pack" -A1 maya-trial.json | tail -1
  grep -iE "glm split:|RAM tier|evict|CPU lane:|template" maya-trial.log | head -8 | cut -c1-170
  [ "$L" = v1113-base ] && python3 mab776-smoke.py http://127.0.0.1:8325
  python3 mab776-dflash-sweep.py http://127.0.0.1:8325 "$L-warm" base | tail -1
  python3 mab776-dflash-sweep.py http://127.0.0.1:8325 "$L" base | tail -1
  grep "glm stat" maya-trial.log | tail -1 | sed 's/.*decode/decode/' | cut -c1-220
}
arm v1113-base
arm v1113-least STRATA_GLM_VRAM_EVICT=least
arm v1113-cpush0 STRATA_GLM_CPU_SHARED=0
docker stop -t 60 maya-trial >/dev/null 2>&1; rm -rf "$T"; echo done
