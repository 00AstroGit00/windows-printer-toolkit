$ErrorActionPreference = 'Stop'

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$moduleName = 'PrinterToolkit'
$version = '5.0.1'
$repoUrl = 'https://github.com/00AstroGit00/windows-printer-toolkit'
$releaseUrl = "$repoUrl/releases/download/v$version/PrinterToolkit_v$version.zip"
$zipPath = Join-Path -Path $toolsDir -ChildPath "$moduleName.zip"
$moduleInstallDir = Join-Path -Path (Get-ToolsLocation) -ChildPath $moduleName

Write-Host "Installing PrinterToolkit v$version..." -ForegroundColor Cyan

# Download release ZIP
Write-Host '  Downloading...' -ForegroundColor White
try {
    Import-Module -Name BitsTransfer -ErrorAction SilentlyContinue
    Start-BitsTransfer -Source $releaseUrl -Destination $zipPath -ErrorAction Stop
} catch {
    # Fallback to WebClient if BITS fails
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($releaseUrl, $zipPath)
}
Write-Host '  [OK] Downloaded' -ForegroundColor Green

# Extract
Write-Host '  Extracting...' -ForegroundColor White
if (Test-Path $moduleInstallDir) {
    Remove-Item -Path $moduleInstallDir -Recurse -Force -ErrorAction SilentlyContinue
}
$null = New-Item -ItemType Directory -Force -Path $moduleInstallDir
try {
    Expand-Archive -Path $zipPath -DestinationPath (Split-Path $moduleInstallDir -Parent) -Force -ErrorAction Stop
} catch {
    # If archive extracts to nested folder, adjust
    Expand-Archive -Path $zipPath -DestinationPath $moduleInstallDir -Force -ErrorAction Stop
    $nested = Join-Path -Path $moduleInstallDir -ChildPath $moduleName
    if (Test-Path $nested) {
        Get-ChildItem -Path $nested -Recurse | Move-Item -Destination $moduleInstallDir -Force
        Remove-Item -Path $nested -Recurse -Force
    }
}
Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
Write-Host '  [OK] Extracted' -ForegroundColor Green

# Add to PSModulePath (user scope)
$modulePathTarget = Join-Path -Path $moduleInstallDir -ChildPath 'PrinterToolkit.psd1'
if (-not (Test-Path $modulePathTarget)) {
    # Try alternate structure
    $modulePathTarget = Join-Path -Path $moduleInstallDir -ChildPath "$moduleName\PrinterToolkit.psd1"
}

$userModulesPath = Join-Path -Path ([Environment]::GetFolderPath('MyDocuments')) -ChildPath 'WindowsPowerShell\Modules\PrinterToolkit'
if (-not (Test-Path $userModulesPath)) {
    $null = New-Item -ItemType Directory -Force -Path $userModulesPath
}
Copy-Item -Path "$moduleInstallDir\*" -Destination $userModulesPath -Recurse -Force

# Cleanup install dir
Remove-Item -Path $moduleInstallDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ''
Write-Host "PrinterToolkit v$version installed to:" -ForegroundColor Cyan
Write-Host "  $userModulesPath" -ForegroundColor Gray
Write-Host ''
Write-Host 'To use, run: Import-Module PrinterToolkit' -ForegroundColor White
Write-Host 'Or launch:   .\launcher.ps1' -ForegroundColor White
