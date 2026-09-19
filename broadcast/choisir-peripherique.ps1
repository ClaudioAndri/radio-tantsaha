# ============================================================
#  RADIO TV AN'NY TANTSAHA — Choix du périphérique audio
#  Détecte automatiquement les périphériques disponibles via
#  ffmpeg, les affiche dans une liste numérotée, et enregistre
#  ton choix pour que diffuser-windows.bat l'utilise ensuite.
# ============================================================

$ErrorActionPreference = 'SilentlyContinue'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$deviceFile = Join-Path $scriptDir 'device.txt'

Write-Host ""
Write-Host "=== Recherche des périphériques audio disponibles ===" -ForegroundColor Cyan
Write-Host ""

# ffmpeg écrit la liste des périphériques sur stderr, pas stdout
$output = & ffmpeg -list_devices true -f dshow -i dummy 2>&1 | Out-String

if (-not $output -or $output -notmatch 'audio') {
    Write-Host "[ERREUR] Impossible de lister les périphériques. Verifie que ffmpeg est installe et dans le PATH." -ForegroundColor Red
    Write-Host "Telecharge-le sur https://www.gyan.dev/ffmpeg/builds/"
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
