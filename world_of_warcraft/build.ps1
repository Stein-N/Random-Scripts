# Author: Stein-N
# Description: 
#     Simple script to build a .zip file for my addons to streamline the upload process to curseforge.
#     It collects any .lua file inside the project even if it is not used by trhe addon
# License: MIT

# --- Configuration ---
$sourceFiles = Get-ChildItem -Path . -Recurse -Include *.lua, *.toc -File
$destinationFolder = "./.build"

# --- Find .toc file ---
$tocFile = Get-ChildItem -Path . -Filter *.toc | Select-Object -First 1
if (-not $tocFile) {
    Write-Error "No .toc file found in the current directory. Task will be terminated."
    return
}
Write-Host "Found TOC file: $($tocFile.Name)"

# --- Read addon metadata from .toc file ---
Write-Host "Reading metadata from '$($tocFile.Name)'..."
$addonName = ""
$version = ""
try {
    $tocContent = Get-Content $tocFile.FullName

    # Read Title (Addon Name)
    $titleLine = $tocContent | Where-Object { $_ -match "^\s*##\s*Title:" }
    if ($titleLine) {
        $addonName = ($titleLine -split ":", 2)[1].Trim()
        Write-Host "Addon name found: $addonName"
    } else {
        Write-Error "No '## Title:' found in .toc file. Cannot determine addon name. Task will be terminated."
        return
    }

    # Read Version
    $versionLine = $tocContent | Where-Object { $_ -match "^\s*##\s*Version:" }
    if ($versionLine) {
        $version = ($versionLine -split ":", 2)[1].Trim()
        Write-Host "Version found: $version"
    } else {
        $version = "0.0.0-dev"
        Write-Warning "No '## Version:' found in .toc file. Using '$version' as fallback."
    }
} catch {
    Write-Error "Error while reading '$($tocFile.Name)'. Task will be terminated."
    return
}

$zipFile = "./.build/$($addonName)-$($version).zip"
Write-Host "ZIP archive name: '$zipFile'"

# --- Prepare build directory ---
if (Test-Path $destinationFolder) {
    Remove-Item -Recurse -Force $destinationFolder
}
New-Item -ItemType Directory -Force -Path $destinationFolder | Out-Null

# --- Copy files (preserving directory structure) ---
$basePath = (Get-Location).Path
$targetRoot = Join-Path $destinationFolder $addonName

Write-Host "Copying files and preserving directory structure..."
foreach ($item in $sourceFiles) {
    # Determine the relative path of the file to the root directory
    $relativePath = $item.FullName.Substring($basePath.Length).TrimStart("\")

    # Create the full destination path, which preserves the subdirectory structure
    $destinationPath = Join-Path $targetRoot $relativePath

    # Extract the target subdirectory
    $destinationDir = Split-Path -Path $destinationPath -Parent

    # Ensure the target directory exists
    if (-not (Test-Path $destinationDir)) {
        New-Item -ItemType Directory -Force -Path $destinationDir | Out-Null
    }

    # Copy the file to the correct location
    Copy-Item -Path $item.FullName -Destination $destinationPath
    Write-Host "Copied '$relativePath'"
}

# --- Create ZIP archive ---
if (Test-Path $zipFile) {
    Remove-Item $zipFile
}

Compress-Archive -Path "$destinationFolder/$addonName" -DestinationPath $zipFile

# --- Cleanup ---
Write-Host "Delete temporary data..."
Remove-Item -Recurse -Force "$destinationFolder/$addonName"

Write-Host "ZIP archive created: $zipFile"