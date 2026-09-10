#!/bin/bash
# ============================================================
#  RADIO TV AN'NY TANTSAHA — Script de diffusion (macOS / Linux)
#  Envoie le son vers NOTRE serveur (local ou Render), avec
#  reconnexion automatique en cas de coupure.
# ============================================================

# --- 1. A ADAPTER ---
#  Pour un TEST EN LOCAL (le serveur tourne sur ce meme PC) :
#    SERVER_URL="http://localhost:8000"
#  Pour diffuser vers Render (remplace par TON adresse, SANS port,
#  avec https:// au debut) :
#    SERVER_URL="https://tantsaha-radio-xxxx.onrender.com"
SERVER_URL="http://localhost:8000"

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
echo "  Vers : $SERVER_URL/source"
echo "  (Reconnexion automatique en cas de coupure)"
echo "  (Ctrl+C pour arreter definitivement)"
echo "============================================"

TARGET="${SERVER_URL}/source?key=${SOURCE_PASSWORD}"

while true; do
    if [ "$OS" = "Darwin" ]; then
        INPUT_DEVICE=":BlackHole 2ch"
        ffmpeg -f avfoundation -i "$INPUT_DEVICE" \
          -acodec libmp3lame -b:a 320k -ar 48000 -ac 2 \
          -write_xing 0 -id3v2_version 0 -flush_packets 1 \
          -content_type audio/mpeg \
          -f mp3 -method PUT "$TARGET"
    else
        # Trouve le nom exact avec : pactl list sources short
        INPUT_DEVICE="virtual-cable.monitor"
        ffmpeg -f pulse -i "$INPUT_DEVICE" \
          -acodec libmp3lame -b:a 320k -ar 48000 -ac 2 \
          -write_xing 0 -id3v2_version 0 -flush_packets 1 \
          -content_type audio/mpeg \
          -f mp3 -method PUT "$TARGET"
    fi
    echo ""
    echo "[!] Connexion interrompue - nouvelle tentative dans 3 secondes..."
    echo "    (Ctrl+C pour arreter definitivement la diffusion)"
    sleep 3
done
