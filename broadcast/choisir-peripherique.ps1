# ============================================================
#  RADIO TV AN'NY TANTSAHA — Choix du périphérique audio
#  Détecte automatiquement les périphériques disponibles via
#  ffmpeg, les affiche dans une liste numérotée, et enregistre
#  ton choix pour que diffuser-windows.bat l'utilise ensuite.
# ============================================================

$ErrorActionPreference = 'SilentlyContinue'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$deviceFile = Join-Path $scriptDir 'device.txt'
$ffmpegPathFile = Join-Path $scriptDir 'ffmpeg-path.txt'

Write-Host ""
Write-Host "=== Recherche de ffmpeg ===" -ForegroundColor Cyan

# 1) ffmpeg est-il directement accessible via le PATH ?
$ffmpegCmd = $null
$found = Get-Command ffmpeg.exe -ErrorAction SilentlyContinue
if ($found) { $ffmpegCmd = $found.Source }

# 2) Sinon, on cherche dans les emplacements d'installation les plus
#    courants — utile si le PATH n'a pas encore été rechargé par
#    Windows (ça arrive après l'avoir ajouté, tant qu'on n'a pas
#    redémarré l'explorateur ou l'ordinateur).
if (-not $ffmpegCmd) {
    Write-Host "Pas trouve dans le PATH, recherche dans les emplacements courants..." -ForegroundColor DarkGray
    $candidates = @(
        "C:\ffmpeg\bin\ffmpeg.exe",
        "C:\Program Files\ffmpeg\bin\ffmpeg.exe",
        "C:\Program Files (x86)\ffmpeg\bin\ffmpeg.exe",
        "$env:LOCALAPPDATA\Microsoft\WinGet\Links\ffmpeg.exe"
    )
    # Emplacement typique de winget (dossier versionne, nom variable)
    $wingetGlob = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Filter 'ffmpeg.exe' -Recurse -ErrorAction SilentlyContinue -Depth 4
    foreach ($f in $wingetGlob) { $candidates += $f.FullName }

    foreach ($path in $candidates) {
        if (Test-Path $path) { $ffmpegCmd = $path; break }
    }
}

if (-not $ffmpegCmd) {
    Write-Host "[ERREUR] ffmpeg introuvable, meme en cherchant dans les emplacements courants." -ForegroundColor Red
    Write-Host "Si tu es sur que ffmpeg est installe :" -ForegroundColor Yellow
    Write-Host "  1. Ouvre l'Explorateur de fichiers, cherche ffmpeg.exe" -ForegroundColor Yellow
    Write-Host "  2. Redemarre ton PC une fois (le PATH mettra a jour toutes les fenetres)" -ForegroundColor Yellow
    Write-Host "  3. Relance ce script" -ForegroundColor Yellow
    Write-Host "Sinon, telecharge-le sur https://www.gyan.dev/ffmpeg/builds/" -ForegroundColor Yellow
    Read-Host "Appuie sur Entree pour fermer"
    exit 1
}

Write-Host "ffmpeg trouve : $ffmpegCmd" -ForegroundColor Green
# Enregistre le chemin trouve pour que diffuser-windows.bat l'utilise
# aussi, sans dependre du PATH.
Set-Content -Path $ffmpegPathFile -Value $ffmpegCmd -Encoding UTF8 -NoNewline

Write-Host ""
Write-Host "=== Recherche des périphériques audio disponibles ===" -ForegroundColor Cyan
Write-Host ""

# ffmpeg écrit la liste des périphériques sur stderr, pas stdout
$output = & $ffmpegCmd -list_devices true -f dshow -i dummy 2>&1 | Out-String

if (-not $output -or $output -notmatch 'audio') {
    Write-Host "[ERREUR] ffmpeg a bien ete trouve mais n'a pas reussi a lister les peripheriques." -ForegroundColor Red
    Write-Host "Essaie de lancer cette commande toi-meme pour voir le message d'erreur exact :" -ForegroundColor Yellow
    Write-Host "  `"$ffmpegCmd`" -list_devices true -f dshow -i dummy" -ForegroundColor Yellow
    Read-Host "Appuie sur Entree pour fermer"
    exit 1
}

# Extrait les noms entre guillemets sur les lignes qui se terminent par "(audio)"
$matches = [regex]::Matches($output, '"([^"]+)"\s*\(audio\)')
$devices = @()
foreach ($m in $matches) { $devices += $m.Groups[1].Value }
$devices = $devices | Select-Object -Unique

if ($devices.Count -eq 0) {
    Write-Host "[ERREUR] Aucun périphérique audio detecte." -ForegroundColor Red
    Read-Host "Appuie sur Entree pour fermer"
    exit 1
}

# Mots-clés de périphériques virtuels couramment utilisés pour capter
# la sortie d'un logiciel comme RadioBOSS (plutôt qu'un micro physique)
$suggestedKeywords = 'cable', 'voicemeeter', 'virtual', 'stereo mix', 'mixage stereo', 'capturer'

Write-Host "Périphériques audio détectés :" -ForegroundColor Cyan
Write-Host ""
for ($i = 0; $i -lt $devices.Count; $i++) {
    $name = $devices[$i]
    $isSuggested = $false
    foreach ($kw in $suggestedKeywords) {
        if ($name.ToLower().Contains($kw)) { $isSuggested = $true }
    }
    $num = $i + 1
    if ($isSuggested) {
        Write-Host ("  {0,2}. {1}   " -f $num, $name) -NoNewline -ForegroundColor White
        Write-Host "★ suggéré (câble virtuel détecté)" -ForegroundColor Yellow
    } else {
        Write-Host ("  {0,2}. {1}" -f $num, $name)
    }
}
Write-Host ""
Write-Host "Astuce : choisis le câble virtuel (marqué ★) dans lequel RadioBOSS" -ForegroundColor DarkGray
Write-Host "envoie sa sortie audio — pas ton micro." -ForegroundColor DarkGray
Write-Host ""

$choice = Read-Host "Entre le numéro du périphérique à utiliser"
$choiceNum = 0
if (-not [int]::TryParse($choice, [ref]$choiceNum) -or $choiceNum -lt 1 -or $choiceNum -gt $devices.Count) {
    Write-Host "[ERREUR] Numéro invalide." -ForegroundColor Red
    Read-Host "Appuie sur Entree pour fermer"
    exit 1
}

$selected = $devices[$choiceNum - 1]
Set-Content -Path $deviceFile -Value $selected -Encoding UTF8 -NoNewline

Write-Host ""
Write-Host "✅ Périphérique enregistré : $selected" -ForegroundColor Green
Write-Host "Tu peux maintenant lancer diffuser-windows.bat — il utilisera ce choix automatiquement." -ForegroundColor Green
Write-Host ""
Read-Host "Appuie sur Entree pour fermer"
