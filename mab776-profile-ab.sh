#!/bin/sh
# mab776: v1.1.3 quick test + expert-profile A/B (served config = arm "usage").
#   arms: usage = our STRATA_GLM_USAGE file (as served); profile = the shipped data/expert-profile-glm.bin, no usage file
# Each arm: mab776-tune.sh (prose bench 30k/127k) + the 4 sampled coding prompts (2 passes, the 1st is warm-up).
cd "$(dirname "$0")" || exit 1
COMMON="STRATA_GLM_SLOT_DIR=/slots/trial STRATA_GLM_KV_INT8=1 STRATA_GLM_CPU_SHARED=1"
rm -f "/media/mab776/nvme 2To/models/maya/slots/trial/"slot-*
arm() {  # LABEL ARGS ENV...
  L=$1; A=$2; shift 2
  echo "=== $L"; rm -f "/media/mab776/nvme 2To/models/maya/slots/trial/"slot-*
  MAYA_GPUS=0,1 MAYA_ARGS="$A" ./mab776-tune.sh "$L" $COMMON "$@"
  python3 mab776-dflash-sweep.py http://127.0.0.1:8325 "$L-warm" base | tail -1
  python3 mab776-dflash-sweep.py http://127.0.0.1:8325 "$L" base | tail -1
}
arm v113-usage "" STRATA_GLM_USAGE=/slots/usage-maya-s.txt
arm v113-profile "--expert-profile /maya/data/expert-profile-glm.bin"
docker stop -t 60 maya-trial >/dev/null 2>&1
echo done
