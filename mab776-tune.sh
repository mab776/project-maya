#!/bin/sh
# mab776: one tuning arm = restart Maya (GPU 0) with engine env KEY=VAL ... then strata_bench at 27k + 125k.
#   [MAYA_GPUS=0,1] [MAYA_ARGS='--flag val'] [MAYA_PACK=<dir under models/maya, default GSQ-RCO-3.5bit>] ./mab776-tune.sh LABEL [KEY=VAL ...]      results appended to tune-results.jsonl
# The env goes into maya-trial.json "env" (the server passes it to the engine); the last arm's env stays there.
cd "$(dirname "$0")" || exit 1
LABEL=$1; shift
python3 - "$@" <<'EOF' || exit 1
import json, sys
c = json.load(open('maya-trial.json'))
import os
c['env'] = dict(a.split('=', 1) for a in sys.argv[1:])
c['gpu'] = [int(x) for x in os.environ.get('MAYA_GPUS', '0').split(',')]
pk = os.environ.get('MAYA_PACK', 'GSQ-RCO-3.5bit')
c['args'] = ['--glm-pack', f'/models/{pk}/pack', '--max-context', '262144'] + os.environ.get('MAYA_ARGS', '').split()
c['tokenizer'] = f'/models/{pk}/pack/tokenizer'
if not c['env']: c.pop('env')
json.dump(c, open('maya-trial.json', 'w'), indent=1)
EOF
docker stop -t 30 maya-trial >/dev/null 2>&1
mv -f maya-trial.log "maya-trial-$LABEL-prev.log" 2>/dev/null
./mab776-run.sh >/dev/null || exit 1
for i in $(seq 1 60); do
  sleep 5
  docker logs maya-trial 2>&1 | grep -q "^ready" && break
  docker ps --format '{{.Names}}' | grep -qx maya-trial || { echo "maya-trial died at start"; exit 1; }
done
grep -E "RAM tier|expert pool|prefill: CUDA. chunks|glm split|glm mtp" maya-trial.log | cut -c1-160
echo "RAM available after load: $(free -g | awk '/^Mem/{print $7}') GB"
for d in 30000 127000; do
  timeout 900 python3 ../strata-coder/bench/strata_bench.py $d --label "maya-$LABEL" --url http://127.0.0.1:8325 2>&1 | tail -1 | tee -a tune-results.jsonl
done
grep -E "glm stat|glm spec" maya-trial.log | tail -3 | sed 's/.*decode/decode/' | cut -c1-200
