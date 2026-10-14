#!/bin/sh
# mab776 (10-14, 128 GB): GSQ-RCO 3.5-bit SPEED vs live Maya-S - same args/env as maya-glm.json, only the pack differs
# (+ a borrowed NextN draft: GSQ has no blk.45). Auto split. Bench 30k/127k + the 4 sampled coding prompts twice.
cd "$(dirname "$0")" || exit 1
T="/media/mab776/nvme 2To/models/maya/slots/trial"; mkdir -p "$T"
ARGS=$(python3 -c "import json;a=json.load(open('maya-glm.json'))['args'];print(' '.join(a[4:]))")
ENV=$(python3 -c "import json;e=json.load(open('maya-glm.json'))['env'];e['STRATA_GLM_SLOT_DIR']='/slots/trial';e.pop('STRATA_GLM_SLOT_KEEP',None);print(' '.join(k+'='+v for k,v in e.items()))")
arm() {  # LABEL ENV...
  L=$1; shift; echo "=== $L"; rm -f "$T"/slot-*
  MAYA_PACK=GSQ-RCO-3.5bit MAYA_GPUS=0,1 MAYA_ARGS="$ARGS" ./mab776-tune.sh "$L" $ENV "$@" || return
  grep -E "glm mtp|RAM tier|expert pool" maya-trial.log | cut -c1-170
  python3 mab776-dflash-sweep.py http://127.0.0.1:8325 "$L-warm" base | tail -1
  python3 mab776-dflash-sweep.py http://127.0.0.1:8325 "$L" base | tail -1
}
arm G35-mtpM STRATA_GLM_MTP_GGUF=/models/mtp-drafts/Maya-M-nextn-blk45.gguf
arm G35-mtpL STRATA_GLM_MTP_GGUF=/models/mtp-drafts/Maya-L-nextn-blk45.gguf
docker stop -t 60 maya-trial >/dev/null 2>&1; rm -rf "$T"; echo done
