#!/bin/bash
# mab776: TOKENIZER-FIX check (Maya-S) + GSQ-RCO 3.5-bit TEST ONLY - run on Marc's go (takes the GPUs): mode off -> GPU0-only + split40
# (speed 27k/125k + 32k needles) -> mode page back to Qwen Next. Log -> ../project-maya/results-gsq.txt
cd "$(dirname "$0")" || exit 1
OUT=../project-maya/results-gsq.txt; B=../strata-coder/bench
log() { echo "$*" | tee -a "$OUT"; }
source <(sed -n '/^arm() {/,/^}/p' mab776-night.sh)
log "##### GSQ-RCO tests started $(date +%H:%M) (Marc's go) — mode off"
curl -s -m 60 -X POST http://127.0.0.1:8500/api/mode/off >/dev/null; sleep 5
arm S-gpu0-tokfix Maya-S-v2-IQ2_XXS 0
arm G-gpu0    GSQ-RCO-3.5bit 0
arm G-split40 GSQ-RCO-3.5bit 0,1 STRATA_GLM_SPLIT=40
arm G-split40-mtpM GSQ-RCO-3.5bit 0,1 STRATA_GLM_SPLIT=40 STRATA_GLM_MTP_GGUF=/models/Maya-M/GLM-5.3-Flash-Maya-M-00003-of-00003.gguf
docker stop -t 30 maya-trial >/dev/null 2>&1
log ""; log "##### done $(date +%H:%M) — GPUs left to GLM (Strata stays off, Marc 10-08)"
