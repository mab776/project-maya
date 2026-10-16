#!/bin/sh
# mab776 (10-16 pm): v1.1.14 test on GSQ-RCO 3.5 with the served config (maya-glm.json args + env), bench 8k/30k/127k +
# smoke + the 4 sampled coding prompts twice, per arm:
#   base = served only (v1.1.14 = Pascal + Q8_0 experts; NVIDIA cc>=7.0 gives v1.1.13 tokens -> no new knob to arm)
cd "$(dirname "$0")" || exit 1
T="/media/mab776/nvme 2To/models/maya/slots/trial"; mkdir -p "$T"
ARGS=$(python3 -c "import json;a=json.load(open('maya-glm.json'))['args'];print(' '.join(a[4:]))")
ENV=$(python3 -c "import json;e=json.load(open('maya-glm.json'))['env'];e['STRATA_GLM_SLOT_DIR']='/slots/trial';e.pop('STRATA_GLM_SLOT_KEEP',None);print(' '.join(k+'='+v for k,v in e.items()))")
arm() {  # LABEL ENV...
  L=$1; shift; echo "=== $L"; rm -f "$T"/slot-*
  MAYA_DEPTHS="8000 30000 127000" MAYA_GPUS=0,1 MAYA_ARGS="$ARGS" ./mab776-tune.sh "$L" $ENV "$@" || return
  grep -E "glm-pack" -A1 maya-trial.json | tail -1
  grep -iE "glm split:|RAM tier|evict|CPU lane:|template" maya-trial.log | head -8 | cut -c1-170
  [ "$L" = v1114-base ] && python3 mab776-smoke.py http://127.0.0.1:8325
  python3 mab776-dflash-sweep.py http://127.0.0.1:8325 "$L-warm" base | tail -1
  python3 mab776-dflash-sweep.py http://127.0.0.1:8325 "$L" base | tail -1
  grep "glm stat" maya-trial.log | tail -1 | sed 's/.*decode/decode/' | cut -c1-220
}
arm v1114-base
docker stop -t 60 maya-trial >/dev/null 2>&1; rm -rf "$T"; echo done
