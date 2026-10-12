#!/usr/bin/env python3
"""mab776: DFlash2 draft-length sweep against a RUNNING Maya (v1.1.0+) - per-request "strata_tune", no restarts.
Real coding prompts, Marc's sampling (temperature 1.0, top_p 0.95, effort medium), so acceptance is the one he gets.
    python3 mab776-dflash-sweep.py URL LABEL [ARM ...]      ARM = name:key=val,key=val  (keys: spec, spec_cum,
                                                             spec_min_p, spec_n_min; "base" = no strata_tune)
Default arms (DFlash server): spec 2..8 at the 2-GPU default cut (cum 0.9), then cum 0.8 / 0.95 at spec 5.
On an MTP server run it with the single arm "base". Appends one JSON line per arm to dflash-sweep.jsonl:
decode tok/s (completion tokens / engine decode time), drafts offered/accepted, per-prompt numbers."""
import json
import sys
import time
import urllib.request
from pathlib import Path

URL = sys.argv[1].rstrip("/") + "/v1/chat/completions"
LABEL = sys.argv[2]
OUT = Path(__file__).with_name("dflash-sweep.jsonl")
PROMPTS = [
    "Write a Python function that returns the length of the longest substring without repeating characters. "
    "Include a short explanation and three test cases.",
    "Implement an LRU cache class in Python with get and put in O(1), using only the standard library. Add tests.",
    "Given a list of intervals, merge all overlapping intervals. Write the Python solution, then explain its complexity.",
    "Write a bash script that finds the 10 largest files under a directory, prints human-readable sizes, and skips "
    "symlinks. Explain each part briefly.",
]
DEFAULT_ARMS = [f"spec{t}:spec={t}" for t in (2, 3, 4, 5, 6, 8)] + ["spec5-cum0.8:spec=5,spec_cum=0.8",
                                                                       "spec5-cum0.95:spec=5,spec_cum=0.95"]


def parse(arm):
    name, _, kv = arm.partition(":")
    tune = {}
    for part in filter(None, kv.split(",")):
        k, v = part.split("=")
        tune[k] = int(v) if k in ("spec", "spec_n_min") else float(v)
    return name, tune


def ask(prompt, tune):
    body = {"model": "glm", "temperature": 1.0, "top_p": 0.95, "max_tokens": 2048, "reasoning_effort": "medium",
            "messages": [{"role": "user", "content": prompt}]}
    if tune:
        body["strata_tune"] = tune
    t0 = time.time()
    req = urllib.request.Request(URL, json.dumps(body).encode(), {"Content-Type": "application/json"})
    d = json.load(urllib.request.urlopen(req, timeout=1800))
    t = d.get("timings") or {}
    n = (d.get("usage") or {}).get("completion_tokens") or 0
    dec_s = (t.get("predicted_ms") or t.get("decode_ms") or 0) / 1000 or (time.time() - t0)
    return {"tokens": n, "decode_s": round(dec_s, 2), "tps": round(n / dec_s, 1) if dec_s else None,
            "offered": t.get("draft_n"), "accepted": t.get("draft_n_accepted")}


arms = sys.argv[3:] or DEFAULT_ARMS
for arm in arms:
    name, tune = parse(arm) if arm != "base" else ("base", {})
    runs = [ask(p, tune) for p in PROMPTS]
    tok = sum(r["tokens"] for r in runs)
    sec = sum(r["decode_s"] for r in runs)
    off = sum(r["offered"] or 0 for r in runs)
    acc = sum(r["accepted"] or 0 for r in runs)
    row = {"label": LABEL, "arm": name, "tune": tune, "tps": round(tok / sec, 1) if sec else None, "tokens": tok,
           "accept": round(acc / off, 3) if off else None, "runs": runs}
    print(json.dumps({k: row[k] for k in ("label", "arm", "tps", "tokens", "accept")}), flush=True)
    with open(OUT, "a") as f:
        f.write(json.dumps(row) + "\n")
