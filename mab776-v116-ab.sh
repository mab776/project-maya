#!/bin/sh
# mab776: v1.1.6 quick test (served config + smoke) and KV streaming (--kv-streaming on, 32768 resident) on top.
cd "$(dirname "$0")" || exit 1
T="/media/mab776/nvme 2To/models/maya/slots/trial"; mkdir -p "$T"
ENV="STRATA_GLM_SLOT_DIR=/slots/trial STRATA_GLM_KV_INT8=1 STRATA_GLM_CPU_SHARED=1 STRATA_GLM_SPEC_SAMPLE=1 STRATA_GLM_SPEC_CANCEL=1 STRATA_GLM_CKPTS=0"
P="--expert-profile /maya/data/expert-profile-glm.bin"
arm() {  # LABEL ARGS
  L=$1; echo "=== $L"; rm -f "$T"/slot-*
  MAYA_GPUS=0,1 MAYA_ARGS="$P $2" ./mab776-tune.sh "$L" $ENV || return
  grep -iE "kv stream|kv-stream|latent cache" maya-trial.log | head -3 | cut -c1-200
  [ "$L" = v116-base ] && python3 mab776-smoke.py http://127.0.0.1:8325
  python3 mab776-dflash-sweep.py http://127.0.0.1:8325 "$L-warm" base | tail -1
  python3 mab776-dflash-sweep.py http://127.0.0.1:8325 "$L" base | tail -1
}
arm v116-base ""
arm v116-kvstream "--kv-streaming on"
docker stop -t 60 maya-trial >/dev/null 2>&1; rm -rf "$T"; echo done
