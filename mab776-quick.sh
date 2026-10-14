#!/bin/sh
# mab776: quick test of the built engine with the SERVED config's engine settings (maya-glm.json args + env) in maya-trial:
# bench 26k/118k, smoke, the 4 sampled coding prompts twice. Trial slots only.   ./mab776-quick.sh LABEL
cd "$(dirname "$0")" || exit 1
L=${1:-quick}; T="/media/mab776/nvme 2To/models/maya/slots/trial"; mkdir -p "$T"; rm -f "$T"/slot-*
ARGS=$(python3 -c "import json;a=json.load(open('maya-glm.json'))['args'];print(' '.join(a[4:]))")
ENV=$(python3 -c "import json;e=json.load(open('maya-glm.json'))['env'];e['STRATA_GLM_SLOT_DIR']='/slots/trial';e.pop('STRATA_GLM_SLOT_KEEP',None);print(' '.join(k+'='+v for k,v in e.items()))")
echo "args: $ARGS"; echo "env: $ENV"
MAYA_GPUS=0,1 MAYA_ARGS="$ARGS" ./mab776-tune.sh "$L" $ENV || exit 1
grep -E "RAM tier" maya-trial.log | cut -c1-160
python3 mab776-smoke.py http://127.0.0.1:8325
python3 mab776-dflash-sweep.py http://127.0.0.1:8325 "$L-warm" base | tail -1
python3 mab776-dflash-sweep.py http://127.0.0.1:8325 "$L" base | tail -1
docker stop -t 60 maya-trial >/dev/null 2>&1; rm -rf "$T"; echo done
