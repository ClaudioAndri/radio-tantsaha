@echo off
REM ============================================================
REM  RADIO TV AN'NY TANTSAHA — Arret complet de la diffusion
REM  A utiliser apres avoir ferme diffuser-windows.bat, pour
REM  s'assurer qu'aucun ffmpeg ne continue de tourner en arriere-
REM  plan (normal avec le systeme de connexions chevauchantes).
REM ============================================================
echo Arret de tous les processus ffmpeg...
taskkill /IM ffmpeg.exe /F >nul 2>nul
if %errorlevel% equ 0 (
    echo Diffusion arretee.
) else (
    echo Aucune diffusion en cours.
)
pause
