# Author: Stein-N
# Description: 
#   Simple way to have a dev instance for retail WoW without copying all files.
# License: MIT

# Definition der Dateinamen
$files = @("Wow.exe", "wow_loader.dll")
$sourcePath = "F:\World of Warcraft\_retail_"
$targetPath = "F:\World of Warcraft\_retail_dev_"

# 1. Löschen der vorhandenen Dateien im aktuellen Verzeichnis
foreach ($file in $files) {
    if (Test-Path $file) {
        Remove-Item -Path $file -Force
        Write-Host "Gelöscht: $file" -ForegroundColor Yellow
    }
}

# 2. Erstellen der Hardlinks
# Hinweis: Die Pfade sind fest auf deine Vorgabe gesetzt
try {
    foreach ($file in $files) {
        New-Item -Path "$targetPath\$file" -ItemType HardLink -Value "$sourcePath\$file"
    }
    
    Write-Host "Hardlinks erfolgreich erstellt." -ForegroundColor Green
}
catch {
    Write-Error "Fehler beim Erstellen der Hardlinks: $_"
}