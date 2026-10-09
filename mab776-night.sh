#!/bin/bash
# mab776: v1.0.12 test matrix (Maya-S / Maya-M × split40+MTP / GPU0-only): speed 27k+125k, needles 32k.
# Detached (setsid nohup); results -> ../project-maya/results-v1012.txt. Leaves the GPUs empty at the end.
cd "$(dirname "$0")" || exit 1
OUT=../project-maya/results-v1012.txt
B=../strata-coder/bench
log() { echo "$*" | tee -a "$OUT"; }
arm() {   # LABEL MODELDIR GPUS ENV...
  local L=$1 M=$2 G=$3; shift 3
  log ""; log "=== $L ($(date +%H:%M))"
  python3 - "$M" "$G" "$@" <<'EOF'
import json, sys
p = 'maya-trial.json'; c = json.load(open(p)); m, g = sys.argv[1], sys.argv[2]
c['args'] = ['--glm-pack', f'/models/{m}/pack', '--max-context', '131072']
c['tokenizer'] = f'/models/{m}/pack/tokenizer'; c['gpu'] = [int(x) for x in g.split(',')]
c['env'] = dict(a.split('=', 1) for a in sys.argv[3:])
if not c['env']: c.pop('env')
json.dump(c, open(p, 'w'), indent=1)
EOF
  docker stop -t 30 maya-glm >/dev/null 2>&1; mv -f maya-trial.log "maya-trial-$L-prev.log" 2>/dev/null
  MAYA_GPUS=$G ./mab776-run.sh >/dev/null || { log "start failed"; return; }
  for i in $(seq 1 90); do sleep 5; docker logs maya-glm 2>&1 | grep -q "^ready" && break
    docker ps --format '{{.Names}}' | grep -qx maya-glm || { log "died at start"; tail -3 maya-trial.log >> "$OUT"; return; }; done
  grep -E "expert pool|RAM tier|chunks of|glm split" maya-trial.log | cut -c1-150 >> "$OUT"
  log "RAM avail $(free -g | awk '/^Mem/{print $7}') GB"
  for d in 30000 127000; do
    timeout 1200 python3 $B/strata_bench.py $d --label "v1012-$L" --url http://127.0.0.1:8325 2>&1 | tail -1 | tee -a "$OUT"
  done
  grep -E "glm spec" maya-trial.log | tail -1 >> "$OUT"
  (cd ../project-maya && timeout 1200 python3 tools/needle_bench.py --url http://127.0.0.1:8325 --lengths 32k \
     --depths 10,50,90 --out "needles-v1012-$L.json" >/dev/null 2>&1
   python3 -c "
import json
for r in json.load(open('needles-v1012-$L.json')):
    a = r.get('answer', r.get('error', ''))
    print('needle', r.get('depth'), r.get('word'), '->', a, 'EXACT' if a.strip().rstrip('.') == r.get('word') else 'WRONG')") | tee -a "$OUT"
}
curl -s -m 60 -X POST http://127.0.0.1:8500/api/mode/off >/dev/null; sleep 5
log "##### Maya v1.0.12 matrix started $(date '+%F %H:%M')"
arm S-split40-mtp Maya-S-v2-IQ2_XXS 0,1 STRATA_GLM_SPLIT=40
arm S-gpu0        Maya-S-v2-IQ2_XXS 0
arm M-split40-mtp Maya-M            0,1 STRATA_GLM_SPLIT=40
arm M-gpu0        Maya-M            0
docker stop -t 30 maya-glm >/dev/null 2>&1
