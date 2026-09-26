#!/usr/bin/env python3
"""Usage: video/tts.py → video/tutorial/public/vo/<id>.wav + <id>.json + manifest.json

Narration for the tutorial video, same voice as the Headroom tutorial: Bailian `qwen-audio-3.0-tts-plus`,
voice `longanlufeng`. The API key is read from ~/.config/ai-pipeline/.env (never stored in this repo).
Cached: a scene is only re-synthesized when its text changes. Qwen returns no timestamps, so subtitle timing is
spread over each sentence by character count.
"""
import json, os, re, subprocess, urllib.request
from pathlib import Path

root = Path(__file__).resolve().parent
out = root / "tutorial/public/vo"
out.mkdir(parents=True, exist_ok=True)


def key():
    env = open(os.path.expanduser("~/.config/ai-pipeline/.env")).read()
    return re.search(r'^(?:export )?BAILIAN_API_KEY=["\']?([^"\'\n]+)', env, re.M).group(1).strip()


def wav_ms(wav):
    return round(1000 * float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                                              "-of", "csv=p=0", str(wav)], capture_output=True, text=True).stdout))


def synthesize(text, wav):
    body = {"model": "qwen-audio-3.0-tts-plus", "input": {"text": text, "voice": "longanlufeng"}}
    req = urllib.request.Request(
        "https://token-plan.cn-beijing.maas.aliyuncs.com/api/v1/services/audio/tts/SpeechSynthesizer",
        data=json.dumps(body).encode(), method="POST",
        headers={"Authorization": f"Bearer {key()}", "Content-Type": "application/json"})
    r = json.load(urllib.request.urlopen(req, timeout=180))
    raw = wav.with_suffix(".raw.wav")
    raw.write_bytes(urllib.request.urlopen(r["output"]["audio"]["url"], timeout=180).read())
    # The streamed WAV header carries a placeholder length; rewrite it and resample to 48 kHz.
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(raw), "-ar", "48000", "-c:a", "pcm_s16le",
                    str(wav)], check=True)
    raw.unlink()
    ms = wav_ms(wav)
    sentences = [x for x in re.split(r"(?<=[。？！])", text) if x.strip()]
    total, acc, subs = sum(len(x) for x in sentences), 0, []
    for x in sentences:
        a = ms * acc / total
        acc += len(x)
        subs.append({"text": x, "start": round(a), "end": round(ms * acc / total)})
    return {"vo": text, "ms": ms, "chars": r.get("usage", {}).get("characters", 0), "subs": subs}


manifest = {}
for scene in json.loads((root / "script.json").read_text()):
    wav, meta = out / f"{scene['id']}.wav", out / f"{scene['id']}.json"
    if wav.exists() and meta.exists() and json.loads(meta.read_text())["vo"] == scene["vo"]:
        manifest[scene["id"]] = json.loads(meta.read_text())
        continue
    m = synthesize(scene["vo"], wav)
    meta.write_text(json.dumps(m, ensure_ascii=False, indent=1))
    manifest[scene["id"]] = m
    print(f"{scene['id']:10} {m['ms'] / 1000:5.1f}s  {m['chars']} chars", flush=True)
(out / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=1))
print(f"total {sum(m['ms'] for m in manifest.values()) / 1000:.1f}s")
