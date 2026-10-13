#!/bin/sh
# mab776: v1.1.5 quick test (smoke on the served config) + #145's opt-ins on our two-GPU MTP decode:
#   base | STRATA_GLM_SPEC_SAMPLE=1 (speculative sampling, same token distribution) | + STRATA_GLM_SPEC_CANCEL=1
# Each arm: mab776-tune.sh (bench 30k/127k) + the 4 sampled coding prompts twice (1st = warm-up). Trial slots only.
cd "$(dirname "$0")" || exit 1
T="/media/mab776/nvme 2To/models/maya/slots/trial"; mkdir -p "$T"
COMMON="STRATA_GLM_SLOT_DIR=/slots/trial STRATA_GLM_KV_INT8=1 STRATA_GLM_CPU_SHARED=1"
arm() {  # LABEL ENV...
  L=$1; shift; echo "=== $L"; rm -f "$T"/slot-*
  MAYA_GPUS=0,1 MAYA_ARGS="--expert-profile /maya/data/expert-profile-glm.bin" ./mab776-tune.sh "$L" $COMMON "$@"
  [ "$L" = v115-base ] && python3 mab776-smoke.py http://127.0.0.1:8325
  python3 mab776-dflash-sweep.py http://127.0.0.1:8325 "$L-warm" base | tail -1
  python3 mab776-dflash-sweep.py http://127.0.0.1:8325 "$L" base | tail -1
}
arm v115-base
arm v115-sample STRATA_GLM_SPEC_SAMPLE=1
arm v115-sample-cancel STRATA_GLM_SPEC_SAMPLE=1 STRATA_GLM_SPEC_CANCEL=1
docker stop -t 60 maya-trial >/dev/null 2>&1; rm -rf "$T"; echo done
