@echo off
REM ============================================================
REM  RADIO TV AN'NY TANTSAHA — Script de diffusion (Windows)
REM  Envoie le son (via cable audio virtuel) vers NOTRE serveur.
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
echo   (Reconnexion automatique en cas de coupure)
echo   (Ctrl+C pour arreter definitivement)
echo ============================================

:loop
ffmpeg -f dshow -i audio="%INPUT_DEVICE%" ^
  -acodec libmp3lame -b:a 320k -ar 48000 -ac 2 ^
  -write_xing 0 -id3v2_version 0 -flush_packets 1 ^
  -content_type audio/mpeg ^
  -f mp3 -method PUT "%SERVER_URL%/source?key=%SOURCE_PASSWORD%"

echo.
echo [!] Connexion interrompue - nouvelle tentative dans 3 secondes...
echo     (Ferme cette fenetre pour arreter definitivement la diffusion)
timeout /t 3 /nobreak >nul
goto loop
