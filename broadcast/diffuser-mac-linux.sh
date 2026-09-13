#!/bin/bash
# ============================================================
#  RADIO TV AN'NY TANTSAHA — Script de diffusion (macOS / Linux)
#  Envoie le son vers NOTRE serveur, avec des connexions qui SE
#  CHEVAUCHENT : une nouvelle demarre avant que l'ancienne ne se
#  termine, donc plus aucun vide audio perceptible.
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
echo "  Connexions chevauchantes : aucun vide audio"
echo "  (Ctrl+C pour tout arreter proprement)"
echo "============================================"

TARGET="${SERVER_URL}/source?key=${SOURCE_PASSWORD}"

# Arrete proprement TOUS les ffmpeg lances par ce script quand on
# appuie sur Ctrl+C (important car plusieurs tournent en parallele
# pendant les chevauchements).
trap 'echo ""; echo "[i] Arret de la diffusion..."; pkill -P $$ ffmpeg 2>/dev/null; exit 0' SIGINT SIGTERM

launch_ffmpeg() {
    if [ "$OS" = "Darwin" ]; then
        INPUT_DEVICE=":BlackHole 2ch"
        ffmpeg -f avfoundation -i "$INPUT_DEVICE" \
          -acodec libmp3lame -b:a 320k -ar 48000 -ac 2 \
          -write_xing 0 -id3v2_version 0 -flush_packets 1 \
          -t 300 \
          -content_type audio/mpeg \
          -f mp3 -method PUT "$TARGET" &
    else
        # Trouve le nom exact avec : pactl list sources short
        INPUT_DEVICE="virtual-cable.monitor"
        ffmpeg -f pulse -i "$INPUT_DEVICE" \
          -acodec libmp3lame -b:a 320k -ar 48000 -ac 2 \
          -write_xing 0 -id3v2_version 0 -flush_packets 1 \
          -t 300 \
          -content_type audio/mpeg \
          -f mp3 -method PUT "$TARGET" &
    fi
}

while true; do
    launch_ffmpeg
    echo "[i] $(date '+%H:%M:%S') - Nouvelle connexion lancee en arriere-plan"
    # 260s avant la prochaine connexion = 40s de chevauchement avant
    # que la precedente (limitee a 300s par -t) ne se termine.
    sleep 260
done
