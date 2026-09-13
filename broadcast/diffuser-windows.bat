@echo off
REM ============================================================
REM  RADIO TV AN'NY TANTSAHA — Script de diffusion (Windows)
REM  Envoie le son (via cable audio virtuel) vers NOTRE serveur,
REM  avec des connexions qui SE CHEVAUCHENT : une nouvelle demarre
REM  avant que l'ancienne ne se termine, donc plus AUCUN vide.
REM ============================================================

REM --- 1. A ADAPTER ---
REM  Pour un TEST EN LOCAL (le serveur tourne sur ce meme PC) :
REM    set SERVER_URL=http://localhost:8000
REM  Pour diffuser vers Render (remplace par TON adresse, SANS port,
REM  et avec https:// au debut) :
REM    set SERVER_URL=https://tantsaha-radio-xxxx.onrender.com
set SERVER_URL=https://radio-tantsaha.onrender.com

set SOURCE_PASSWORD=tantsaha_source_2026
set INPUT_DEVICE=Voicemeeter Out B1 (VB-Audio Voicemeeter VAIO)

where ffmpeg >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERREUR] ffmpeg n'est pas installe ou pas dans le PATH.
    echo Telecharge-le sur https://www.gyan.dev/ffmpeg/builds/ et ajoute-le au PATH.
    pause
    exit /b 1
)

echo ============================================
echo   RADIO TV AN'NY TANTSAHA - EN DIRECT
echo   Entree audio : %INPUT_DEVICE%
echo   Vers         : %SERVER_URL%/source
echo   Connexions chevauchantes : AUCUN vide audio
echo   (Pour tout arreter : lance stop-diffusion.bat)
echo ============================================

:loop
REM Chaque connexion dure 300s (-t 300) et une NOUVELLE est lancee
REM en arriere-plan (start /B) 260s apres la precedente, donc 40s
REM AVANT qu'elle ne se termine : les deux tournent en meme temps
REM pendant ce chevauchement, le serveur bascule vers la nouvelle
REM des qu'elle arrive, et l'auditeur ne voit jamais de coupure.
start "" /B ffmpeg -f dshow -i audio="%INPUT_DEVICE%" ^
  -acodec libmp3lame -b:a 320k -ar 48000 -ac 2 ^
  -write_xing 0 -id3v2_version 0 -flush_packets 1 ^
  -t 300 ^
  -content_type audio/mpeg ^
  -f mp3 -method PUT "%SERVER_URL%/source?key=%SOURCE_PASSWORD%"

echo [i] %date% %time% - Nouvelle connexion lancee en arriere-plan
timeout /t 260 /nobreak >nul
goto loop
