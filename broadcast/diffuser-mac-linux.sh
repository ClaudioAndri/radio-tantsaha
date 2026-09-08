#!/bin/bash
# ============================================================
#  RADIO TV AN'NY TANTSAHA — Script de diffusion (macOS / Linux)
#  Envoie le son (via BlackHole / peripherique virtuel) vers
#  NOTRE serveur maison (server/server.js), en HTTP simple.
# ============================================================

SERVER_HOST="localhost"
SERVER_PORT="8000"
SOURCE_PASSWORD="tantsaha_source_2026"

OS="$(uname -s)"

if ! command -v ffmpeg &> /dev/null; then
    echo "[ERREUR] ffmpeg n'est pas installe."
    echo "  macOS  : brew install ffmpeg"
    echo "  Linux  : sudo apt install ffmpeg"
    exit 1
fi

echo "============================================"
echo "  RADIO TV AN'NY TANTSAHA - EN DIRECT"
echo "  Vers : http://$SERVER_HOST:$SERVER_PORT/source"
echo "  (Assure-toi que 'node server/server.js' tourne deja)"
echo "  (Ctrl+C pour arreter la diffusion)"
echo "============================================"

TARGET="http://${SERVER_HOST}:${SERVER_PORT}/source?key=${SOURCE_PASSWORD}"

if [ "$OS" = "Darwin" ]; then
    INPUT_DEVICE=":BlackHole 2ch"
    ffmpeg -f avfoundation -i "$INPUT_DEVICE" \
      -acodec libmp3lame -b:a 128k -ar 44100 -ac 2 \
      -content_type audio/mpeg \
      -f mp3 -method PUT "$TARGET"
else
    # Trouve le nom exact avec : pactl list sources short
    INPUT_DEVICE="virtual-cable.monitor"
    ffmpeg -f pulse -i "$INPUT_DEVICE" \
      -acodec libmp3lame -b:a 128k -ar 44100 -ac 2 \
      -content_type audio/mpeg \
      -f mp3 -method PUT "$TARGET"
fi
