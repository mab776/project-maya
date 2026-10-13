#!/bin/bash
# mab776: GSQ-RCO 3.5-bit vs Maya-S on 128 GB (RAM-resident) + Maya-M vs Maya-L MTP drafts - TEST ONLY - run on Marc's go (takes the GPUs): mode off -> GPU0-only + split40
# (speed 27k/125k + 32k needles) -> mode page back to Qwen Next. Log -> ../project-maya/results-gsq.txt
cd "$(dirname "$0")" || exit 1
OUT=../project-maya/results-gsq.txt; B=../strata-coder/bench
log() { echo "$*" | tee -a "$OUT"; }
source <(sed -n '/^arm() {/,/^}/p' mab776-night.sh)
log "##### GSQ-RCO tests started $(date +%H:%M) (Marc's go) — mode off"
curl -s -m 60 -X POST http://127.0.0.1:8500/api/mode/off >/dev/null; sleep 5
# 2026-10-12 rewrite for the 128 GB box: Maya-M is deleted; GSQ-RCO 3.5 has no NextN block, so its MTP draft comes from
# the two extracted blk.45 files (maya/mtp-drafts/, made with maya-glm/gguf_extract_block.py). Every arm = the stack's
# KV int8; RES = STRATA_GLM_RAM_RESIDENT=1 (all experts in RAM, needs the 128 GB). Maya-S first = the reference.
K=STRATA_GLM_KV_INT8=1; RES=STRATA_GLM_RAM_RESIDENT=1; DM=/models/mtp-drafts/Maya-M-nextn-blk45.gguf; DL=/models/mtp-drafts/Maya-L-nextn-blk45.gguf
arm S-ref-res      Maya-S-v2-IQ2_XXS 0,1 $K $RES
arm G-split40-res  GSQ-RCO-3.5bit 0,1 $K $RES STRATA_GLM_SPLIT=40
arm G-res-mtpM     GSQ-RCO-3.5bit 0,1 $K $RES STRATA_GLM_SPLIT=40 STRATA_GLM_MTP_GGUF=$DM
arm G-res-mtpL     GSQ-RCO-3.5bit 0,1 $K $RES STRATA_GLM_SPLIT=40 STRATA_GLM_MTP_GGUF=$DL
docker stop -t 30 maya-trial >/dev/null 2>&1
log ""; log "##### done $(date +%H:%M) — GPUs left to GLM (Strata stays off, Marc 10-08)"
