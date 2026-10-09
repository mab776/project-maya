#!/bin/bash
# mab776: v1.0.16 A/B - default vs STRATA_GLM_RAM_RESIDENT=1 vs + PROMOTE_MIN=6 (Maya-S, split40+MTP, 262k, slots on).
# Speed 26k + 118k and the engine's SSD reads per token. Log -> ../project-maya/results-v1016-resident.txt. Maya left running (last arm).
cd "$(dirname "$0")" || exit 1
OUT=../project-maya/results-v1016-resident.txt; B=../strata-coder/bench
log() { echo "$*" | tee -a "$OUT"; }
arm() {
  local L=$1; shift
  log ""; log "=== $L ($(date +%H:%M))"
  python3 - "$@" <<'PY'
import json, sys
p = 'maya-trial.json'; c = json.load(open(p))
c['args'] = ['--glm-pack', '/models/Maya-S-v2-IQ2_XXS/pack', '--max-context', '262144']
c['tokenizer'] = '/models/Maya-S-v2-IQ2_XXS/pack/tokenizer'; c['gpu'] = [0, 1]
c['env'] = {'STRATA_GLM_SPLIT': '40', 'STRATA_GLM_SLOT_DIR': '/slots', 'STRATA_GLM_USAGE': '/slots/usage-maya-s.txt'}
c['env'].update(dict(a.split('=', 1) for a in sys.argv[1:]))
json.dump(c, open(p, 'w'), indent=1)
PY
  docker stop -t 30 maya-trial >/dev/null 2>&1; mv -f maya-trial.log "maya-trial-$L-prev.log" 2>/dev/null
  MAYA_GPUS=0,1 ./mab776-run.sh >/dev/null || { log "start failed"; return; }
  for i in $(seq 1 90); do sleep 5; docker logs maya-trial 2>&1 | grep -q "^ready" && break
    docker ps --format '{{.Names}}' | grep -qx maya-trial || { log "died at start"; tail -4 maya-trial.log >> "$OUT"; return; }; done
  grep -E "RAM tier|expert pool|resident|refus" maya-trial.log | cut -c1-150 >> "$OUT"
  log "RAM avail $(free -g | awk '/^Mem/{print $7}') GB"
  for d in 30000 127000; do
    timeout 1200 python3 $B/strata_bench.py $d --label "v1016-$L" --url http://127.0.0.1:8325 2>&1 | tail -1 | tee -a "$OUT"
    grep "glm stat" maya-trial.log | tail -1 | grep -oE "decode [0-9.]+ ms/tok \([0-9.]+ tok/s\)|vram hit [0-9.]+%|disk [0-9.]+ reads/tok[^|]*" | tr '\n' ' ' >> "$OUT"; echo >> "$OUT"
  done
  grep "glm spec" maya-trial.log | tail -1 >> "$OUT"
}
log "##### v1.0.16 RAM-resident A/B started $(date '+%F %H:%M')"
: arm default
: arm resident
arm resident-pmin6-hr4 STRATA_GLM_RAM_RESIDENT=1 STRATA_GLM_PROMOTE_MIN=6 STRATA_GLM_RAM_HEADROOM_GB=4
log ""; log "##### done $(date +%H:%M) — last arm left running on :8325"
