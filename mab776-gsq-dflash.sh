#!/bin/sh
# mab776 (10-14): GSQ-RCO 3.5 with the DFlash2 drafter instead of the borrowed MTP block (MTP = 33.5 tok/s coding).
# Theory: since v1.1.5 a verify window's CPU experts are decoded once for all its tokens (STRATA_GLM_CPU_MT), and GSQ is
# CPU-lane bound (28 of 30 ms a token) -> wider windows may pay here although DFlash2 lost 25 % on Maya-S.
# Live args/env, auto split; bench 30k/127k, then the coding prompts: default + draft-length sweep (spec 3/5/8).
cd "$(dirname "$0")" || exit 1
T="/media/mab776/nvme 2To/models/maya/slots/trial"; mkdir -p "$T"; rm -f "$T"/slot-*
ARGS=$(python3 -c "import json;a=json.load(open('maya-glm.json'))['args'];print(' '.join(a[4:]))")
ENV=$(python3 -c "import json;e=json.load(open('maya-glm.json'))['env'];e['STRATA_GLM_SLOT_DIR']='/slots/trial';e.pop('STRATA_GLM_SLOT_KEEP',None);print(' '.join(k+'='+v for k,v in e.items()))")
echo "=== G35-dflash2"
MAYA_PACK=GSQ-RCO-3.5bit MAYA_GPUS=0,1 MAYA_ARGS="$ARGS" ./mab776-tune.sh G35-dflash2 $ENV \
  STRATA_GLM_DFLASH=/models/dflash2/GLM-5.3-Flash-DFlash2-Q4_K_M.gguf STRATA_GLM_NO_MTP=1 || exit 1
grep -E "glm-pack" -A1 maya-trial.json | tail -1; grep -iE "dflash|glm split:|RAM tier|expert pool" maya-trial.log | head -8 | cut -c1-170
echo "RAM available: $(free -g | awk '/^Mem/{print $7}') GB"
python3 mab776-dflash-sweep.py http://127.0.0.1:8325 G35-df-warm base | tail -1
python3 mab776-dflash-sweep.py http://127.0.0.1:8325 G35-df base spec3:spec=3 spec5:spec=5 spec8:spec=8
docker stop -t 60 maya-trial >/dev/null 2>&1; rm -rf "$T"; echo done
