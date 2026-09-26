# Tutorial video

`./render.sh` → `tutorial/out/UTUVO-Explain-教學-16x9.mp4` (then copy to `docs/assets/explain-tutorial.mp4`).

- `script.json` — scenes and narration. `tts.py` synthesizes narration with Bailian Qwen TTS (key from
  `~/.config/ai-pipeline/.env`, never stored here; audio is cached and not committed).
- `timeline.py` — scene lengths follow the narration; subtitles are split into one-line pieces.
- `tutorial/` — Remotion project. Explain windows are real screenshots (`public/*-loading.png`, `*-done.png`);
  the text selection, keycaps and framing crosshair are animated on top. The video frame is a demo image.
- Music: Suno bed at `music/bed.wav` (not committed), ducked under the narration.
- Loudness is normalized to −14 LUFS / −1.5 dBTP.
