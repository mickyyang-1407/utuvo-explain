#!/bin/zsh
# Usage: video/render.sh → video/tutorial/out/UTUVO-Explain-教學-{16x9,9x16}.mp4 + cover
# Narration (cached) → timeline → Remotion render → two-pass loudness to −14 LUFS / −1.5 dBTP, 48 kHz.
set -eu
cd "${0:A:h}"
python3 tts.py | tail -1
python3 timeline.py | tail -1
cd tutorial
npx remotion still Cover out/UTUVO-Explain-教學-封面-9x16.png --log=error
for comp name in Tutorial UTUVO-Explain-教學-16x9.mp4 TutorialVertical UTUVO-Explain-教學-9x16.mp4; do
  npx remotion render $comp out/raw-$comp.mp4 --codec=h264 --crf=18 --audio-codec=aac --audio-bitrate=256k --log=error
  m=$(ffmpeg -i out/raw-$comp.mp4 -af loudnorm=I=-14:TP=-1.5:LRA=11:print_format=json -f null - 2>&1 | sed -n '/{/,/}/p')
  a=(${=$(echo "$m" | python3 -c "import json,sys;d=json.load(sys.stdin);print(d['input_i'],d['input_tp'],d['input_lra'],d['input_thresh'],d['target_offset'])")})
  ffmpeg -y -loglevel error -i out/raw-$comp.mp4 -c:v copy -movflags +faststart \
    -af "loudnorm=I=-14:TP=-1.5:LRA=11:measured_I=${a[1]}:measured_TP=${a[2]}:measured_LRA=${a[3]}:measured_thresh=${a[4]}:offset=${a[5]}:linear=true,aresample=48000" \
    -c:a aac -b:a 256k -ar 48000 out/$name
  echo "$name: $(ffmpeg -i out/$name -af ebur128=peak=true -f null - 2>&1 | grep -E '^\s+(I:|Peak:)' | tail -2 | tr -s ' ' | tr '\n' ' ') $(ffprobe -v error -show_entries format=duration -of csv=p=0 out/$name)s"
done
