#!/bin/bash
# Turns an audio file into the bundled startup chime.
#
#   Tools/prepare_clip.sh <archivo> [inicio_seg] [duración_seg]
#
# Sin inicio ni duración coge el archivo entero. Mono, con fundidos cortos y
# nivelado a -12 dBFS — el mismo trato que recibe cualquier audio importado desde
# la app, hecho aquí para que el clip pueda viajar dentro del bundle.
#
# El límite de 10 s del importador de la app no se aplica aquí: un clip que viaja
# en el bundle puede durar lo que haga falta.
set -euo pipefail

SOURCE="${1:?uso: prepare_clip.sh <archivo> [inicio] [duración]}"
START="${2:-0}"
LENGTH="${3:-0}"   # 0 = hasta el final
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/Carplayinit/Resources/startup-clip.m4a"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

afconvert -f WAVE -d LEI16@44100 -c 1 "$SOURCE" "$TMP/full.wav"

python3 - "$TMP/full.wav" "$TMP/cut.wav" "$START" "$LENGTH" <<'PY'
import sys, wave, struct, math

src, dst, start, length = sys.argv[1], sys.argv[2], float(sys.argv[3]), float(sys.argv[4])
with wave.open(src) as w:
    rate, frames = w.getframerate(), w.getnframes()
    samples = list(struct.unpack("<%dh" % frames, w.readframes(frames)))

begin = min(int(start * rate), frames - 1)
end = frames if length <= 0 else min(begin + int(length * rate), frames)
cut = samples[begin:end]
if not cut:
    raise SystemExit("el fragmento está fuera del archivo")

# Peak to -12 dBFS: car head units play chimes far louder than music.
peak = max(abs(s) for s in cut) or 1
gain = (10 ** (-12 / 20)) * 32767 / peak

fade_in, fade_out = int(0.02 * rate), int(0.12 * rate)
out = []
for i, s in enumerate(cut):
    g = gain
    if i < fade_in:
        g *= i / fade_in
    if i >= len(cut) - fade_out:
        g *= (len(cut) - i) / fade_out
    out.append(max(-32768, min(32767, int(s * g))))

with wave.open(dst, "w") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate)
    w.writeframes(struct.pack("<%dh" % len(out), *out))
print(f"{len(out)/rate:.2f}s desde {start:.2f}s")
PY

afconvert -f m4af -d aac -b 128000 "$TMP/cut.wav" "$OUT"
echo "→ ${OUT#$ROOT/}"
