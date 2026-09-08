@echo off
REM ============================================================
REM  RADIO TV AN'NY TANTSAHA — Script de diffusion (Windows)
REM  Envoie le son (via VB-Audio Virtual Cable) vers NOTRE
REM  serveur maison (server/server.js), en HTTP simple.
REM ============================================================

set SERVER_HOST=localhost
set SERVER_PORT=8000
set SOURCE_PASSWORD=tantsaha_source_2026
set INPUT_DEVICE=CABLE Output (VB-Audio Virtual Cable)

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
echo   Vers         : http://%SERVER_HOST%:%SERVER_PORT%/source
echo   (Assure-toi que "node server/server.js" tourne deja)
echo   (Ctrl+C pour arreter la diffusion)
echo ============================================

ffmpeg -f dshow -i audio="%INPUT_DEVICE%" ^
  -acodec libmp3lame -b:a 128k -ar 44100 -ac 2 ^
  -content_type audio/mpeg ^
  -f mp3 -method PUT "http://%SERVER_HOST%:%SERVER_PORT%/source?key=%SOURCE_PASSWORD%"

pause
