# Author: Claude, Stein-N
# Description:
#   Locks the freshly installed windows 11 to the currentz feature version, any security patch will be installed normaly.
# License: MIT

# 1. Read current Windows version (f.e. 25H2)
$currentVersion = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").DisplayVersion

# 2. define registry path
$registryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"

# 3. create registry path if not exists
if (!(Test-Path $registryPath)) {
    New-Item -Path $registryPath -Force | Out-Null
}

# 4. lock feature version
Set-ItemProperty -Path $registryPath -Name "TargetReleaseVersion" -Value 1 -Type DWord
Set-ItemProperty -Path $registryPath -Name "TargetReleaseVersionInfo" -Value $currentVersion -Type String
Set-ItemProperty -Path $registryPath -Name "ProductVersion" -Value "Windows 11" -Type String

Write-Host "Success: Windows is now locked to feature version $currentVersion." -ForegroundColor Green
Write-Host "Windows will no longer receive any feature update, security patches will be installed normaly." -ForegroundColor Cyan