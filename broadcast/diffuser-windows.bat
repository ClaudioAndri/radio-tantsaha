@echo off
REM ============================================================
REM  RADIO TV AN'NY TANTSAHA — Script de diffusion (Windows)
REM  Envoie le son (cable virtuel choisi via choisir-peripherique.bat)
REM  vers NOTRE serveur, avec des connexions qui SE CHEVAUCHENT : une
REM  nouvelle demarre avant que l'ancienne ne se termine, donc plus
REM  AUCUN vide.
REM  -> Pas encore choisi de peripherique ? Lance d'abord
REM     choisir-peripherique.bat (detection automatique + liste).
REM ============================================================

REM --- 1. A ADAPTER ---
REM  Pour un TEST EN LOCAL (le serveur tourne sur ce meme PC) :
REM    set SERVER_URL=http://localhost:8000
REM  Pour diffuser vers Render (remplace par TON adresse, SANS port,
REM  et avec https:// au debut) :
REM    set SERVER_URL=https://tantsaha-radio-xxxx.onrender.com
set SERVER_URL=https://radio-tantsaha.onrender.com

set SOURCE_PASSWORD=tantsaha_source_2026

REM Le peripherique audio est choisi via choisir-peripherique.bat, qui
REM enregistre ton choix dans device.txt. S'il n'existe pas encore,
REM on te demande de le lancer d'abord.
set DEVICE_FILE=%~dp0device.txt
if not exist "%DEVICE_FILE%" (
    echo [!] Aucun peripherique audio choisi pour le moment.
    echo     Lance d'abord choisir-peripherique.bat pour en selectionner un
    echo     ^(par exemple le cable virtuel dans lequel RadioBOSS envoie son son^).
    pause
    exit /b 1
)
set /p INPUT_DEVICE=<"%DEVICE_FILE%"

where ffmpeg >nul 2>nul
if %errorlevel% equ 0 (
    set FFMPEG_CMD=ffmpeg
) else (
    REM PATH pas a jour : on reutilise le chemin trouve par
    REM choisir-peripherique.bat s'il existe.
    set FFMPEG_PATH_FILE=%~dp0ffmpeg-path.txt
    if exist "%FFMPEG_PATH_FILE%" (
        set /p FFMPEG_CMD=<"%FFMPEG_PATH_FILE%"
    ) else (
        echo [ERREUR] ffmpeg n'est pas trouve.
        echo Lance d'abord choisir-peripherique.bat : il detecte ffmpeg
        echo automatiquement, meme si le PATH n'est pas encore a jour.
        pause
        exit /b 1
    )
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
start "" /B "%FFMPEG_CMD%" -f dshow -i audio="%INPUT_DEVICE%" ^
  -acodec libmp3lame -b:a 320k -ar 48000 -ac 2 ^
  -write_xing 0 -id3v2_version 0 -flush_packets 1 ^
  -t 300 ^
  -content_type audio/mpeg ^
  -f mp3 -method PUT "%SERVER_URL%/source?key=%SOURCE_PASSWORD%"

echo [i] %date% %time% - Nouvelle connexion lancee en arriere-plan
timeout /t 260 /nobreak >nul
goto loop
