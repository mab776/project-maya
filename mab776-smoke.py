#!/usr/bin/env python3
"""mab776: basic GLM smoke test against a running Maya server (default http://127.0.0.1:8325).
Chat sanity, tool calls (plain + streamed), vision (a generated red/blue image). Prints one PASS/FAIL line each."""
import base64
import io
import json
import struct
import sys
import urllib.request
import zlib

URL = (sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8325").rstrip("/") + "/v1/chat/completions"
TOOLS = [{"type": "function", "function": {
    "name": "get_weather", "description": "Current weather for a city",
    "parameters": {"type": "object", "properties": {"city": {"type": "string"}, "days": {"type": "integer"}},
                   "required": ["city"]}}}]


def post(body, stream=False):
    req = urllib.request.Request(URL, json.dumps(body).encode(), {"Content-Type": "application/json"})
    r = urllib.request.urlopen(req, timeout=900)
    if not stream:
        return json.load(r)
    calls, text = {}, ""
    for line in r:
        line = line.decode().strip()
        if not line.startswith("data:") or line == "data: [DONE]":
            continue
        d = json.loads(line[5:])["choices"][0]["delta"]
        text += d.get("content") or ""
        for tc in d.get("tool_calls") or []:
            c = calls.setdefault(tc.get("index", 0), {"name": "", "args": ""})
            f = tc.get("function") or {}
            c["name"] += f.get("name") or ""
            c["args"] += f.get("arguments") or ""
    return calls, text


def report(name, ok, detail):
    print(f"{'PASS' if ok else 'FAIL'}  {name}: {detail}")


# 1. chat
d = post({"model": "glm", "max_tokens": 1024, "reasoning_effort": "low",
          "messages": [{"role": "user", "content": "What is 17 * 23? Answer with the number only."}]})
a = (d["choices"][0]["message"].get("content") or "").strip()
report("chat", "391" in a, repr(a[:60]))

# 2a. tool call, plain
msgs = [{"role": "user", "content": "What's the weather in Montreal for the next 3 days? Use the tool."}]
d = post({"model": "glm", "max_tokens": 2048, "reasoning_effort": "low", "tools": TOOLS, "messages": msgs})
m = d["choices"][0]["message"]
tc = (m.get("tool_calls") or [{}])[0].get("function", {})
args = json.loads(tc.get("arguments") or "{}") if tc else {}
report("tool call (plain)", tc.get("name") == "get_weather" and "montr" in str(args.get("city", "")).lower(),
       f"{tc.get('name')} {args} finish={d['choices'][0].get('finish_reason')}")

# 2b. round trip: tool result back, final answer
if tc:
    msgs += [m, {"role": "tool", "tool_call_id": m["tool_calls"][0].get("id", "call_0"),
                 "content": json.dumps({"city": "Montreal", "forecast": ["sunny 18C", "rain 12C", "cloudy 15C"]})}]
    d = post({"model": "glm", "max_tokens": 2048, "reasoning_effort": "low", "tools": TOOLS, "messages": msgs})
    a = d["choices"][0]["message"].get("content") or ""
    report("tool round trip", "rain" in a.lower() or "12" in a, repr(a[:90]))

# 2c. tool call, streamed
calls, _ = post({"model": "glm", "max_tokens": 2048, "reasoning_effort": "low", "tools": TOOLS, "stream": True,
                 "messages": [{"role": "user", "content": "Weather in Quebec City, 2 days? Use the tool."}]}, stream=True)
c = calls.get(0, {})
try:
    sa = json.loads(c.get("args") or "{}")
except ValueError:
    sa = {"_raw": c.get("args")}
report("tool call (streamed)", c.get("name") == "get_weather" and "qu" in str(sa.get("city", "")).lower(), f"{c.get('name')} {sa}")


# 3. vision: a 64x32 PNG, left half red, right half blue
def png(w, h, px):
    raw = b"".join(b"\x00" + b"".join(bytes(px(x, y)) for x in range(w)) for y in range(h))
    chunk = lambda t, b: struct.pack(">I", len(b)) + t + b + struct.pack(">I", zlib.crc32(t + b) & 0xffffffff)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))


img = base64.b64encode(png(64, 32, lambda x, y: (220, 20, 20) if x < 32 else (20, 20, 220))).decode()
try:
    d = post({"model": "glm", "max_tokens": 1024, "reasoning_effort": "low", "messages": [{"role": "user", "content": [
        {"type": "text", "text": "What color is the LEFT half of this image, and the RIGHT half? Two words."},
        {"type": "image_url", "image_url": {"url": "data:image/png;base64," + img}}]}]})
    a = (d["choices"][0]["message"].get("content") or "").lower()
    report("vision", "red" in a and "blue" in a and a.find("red") < a.find("blue"), repr(a[:80]))
except Exception as e:  # noqa: BLE001
    report("vision", False, repr(e)[:120])
