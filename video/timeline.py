#!/usr/bin/env python3
"""Usage: video/timeline.py → video/tutorial/src/timeline.json

Each scene lasts as long as its narration plus breathing room; subtitles are split into short one-line pieces
and timed by character count within each sentence (same approach as the Headroom tutorial).
"""
import json, re
from pathlib import Path

root = Path(__file__).resolve().parent
FPS = 30
LEAD, TAIL = 0.6, 1.0


def chunks(text, limit=17):
    parts = [p for p in re.split(r"(?<=[，。；？！、])", text) if p.strip()]
    out = []
    for p in parts:
        if out and len(out[-1]) + len(p) <= limit and not out[-1].endswith(("。", "？", "！")):
            out[-1] += p
        else:
            out.append(p)
    return [o.rstrip("，。；、") for o in out]


vo = json.loads((root / "tutorial/public/vo/manifest.json").read_text())
scenes, t = [], 0
for s in json.loads((root / "script.json").read_text()):
    speech = vo[s["id"]]["ms"] / 1000
    frames = round((LEAD + speech + TAIL) * FPS)
    subs = []
    for x in vo[s["id"]]["subs"]:
        pieces = chunks(x["text"])
        total = sum(len(p) for p in pieces) or 1
        acc = 0
        for p in pieces:
            a = x["start"] + (x["end"] - x["start"]) * acc / total
            acc += len(p)
            b = x["start"] + (x["end"] - x["start"]) * acc / total
            subs.append({"text": p, "from": round((LEAD + a / 1000) * FPS), "to": round((LEAD + b / 1000) * FPS)})
    scenes.append({**{k: v for k, v in s.items() if k != "vo"}, "start": t, "frames": frames,
                   "voFrom": round(LEAD * FPS), "vo": f"vo/{s['id']}.wav", "subs": subs})
    t += frames
(root / "tutorial/src/timeline.json").write_text(json.dumps({"fps": FPS, "frames": t, "scenes": scenes},
                                                            ensure_ascii=False, indent=1))
print(f"{len(scenes)} scenes, {t / FPS:.1f}s")
