<#
.SYNOPSIS
    PrinterToolkit v5.0.1 — Bootstrap installer & launcher.

.DESCRIPTION
    Downloads the latest PrinterToolkit release from GitHub, extracts it,
    imports the module, and opens the interactive management dashboard.
    Optionally keeps the files on disk for persistent use.

.PARAMETER Keep
    Keep extracted files after closing (default: auto-clean).

.PARAMETER ReleaseTag
    GitHub release tag to use (default: latest).

.EXAMPLE
    # One-liner (auto-download + run + cleanup):
    iwr -Uri https://github.com/00AstroGit00/windows-printer-toolkit/raw/main/install.ps1 -OutFile "$env:TEMP\ptk.ps1"; & "$env:TEMP\ptk.ps1"

    # Keep files for later use:
    iwr -Uri https://github.com/00AstroGit00/windows-printer-toolkit/raw/main/install.ps1 -OutFile "$env:TEMP\ptk.ps1"; & "$env:TEMP\ptk.ps1" -Keep
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$Keep,

    [Parameter(Mandatory = $false)]
    [string]$ReleaseTag = 'latest'
)

$ErrorActionPreference = 'Stop'

$owner = '00AstroGit00'
$repo = 'windows-printer-toolkit'

Write-Host 'PrinterToolkit v8.0.0 — Print Server Bootstrap Installer' -ForegroundColor Cyan
Write-Host '======================================================' -ForegroundColor Cyan
Write-Host ''

$tmpBase = Join-Path -Path $env:TEMP -ChildPath "PrinterToolkit"
$null = New-Item -ItemType Directory -Force -Path $tmpBase -ErrorAction SilentlyContinue
$sessionId = Get-Date -Format 'yyyyMMddHHmmss'
$workDir = Join-Path -Path $tmpBase -ChildPath $sessionId
$null = New-Item -ItemType Directory -Force -Path $workDir
$zipPath = Join-Path -Path $workDir -ChildPath 'release.zip'

Write-Host "  [1/3] Downloading $repo release..." -ForegroundColor White

$apiUrl = "https://api.github.com/repos/$owner/$repo/releases/$ReleaseTag"
try {
    $releaseData = Invoke-RestMethod -Uri $apiUrl -ErrorAction Stop
    $asset = $releaseData.assets | Where-Object { $_.name -match '\.zip$' } | Select-Object -First 1
    if (-not $asset) { throw 'No ZIP asset found in release' }
    $downloadUrl = $asset.browser_download_url
    Write-Host "    Release: $($releaseData.tag_name)" -ForegroundColor Gray
    Write-Host "    Asset:   $($asset.name)" -ForegroundColor Gray
    Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -ErrorAction Stop

    $checksumAsset = $releaseData.assets | Where-Object { $_.name -match 'SHA256SUMS$' } | Select-Object -First 1
    if ($checksumAsset) {
        $checksumsTxt = Invoke-RestMethod -Uri $checksumAsset.browser_download_url -ErrorAction SilentlyContinue
        $zipName = $asset.name
        $expectedHash = ($checksumsTxt -split "`n" | Where-Object { $_ -match $zipName } | ForEach-Object { ($_ -split '\s+')[0] }).Trim()
        if ($expectedHash) {
            $actualHash = (Get-FileHash -Path $zipPath -Algorithm SHA256).Hash
            if ($actualHash -ne $expectedHash) {
                throw "SHA-256 mismatch for $zipName"
            }
            Write-Host "    SHA-256: $($actualHash.Substring(0, 16))... verified" -ForegroundColor Gray
        }
    }
} catch {
    Write-Host "    Release download failed, falling back to main branch archive..." -ForegroundColor Yellow
    $fallbackUrl = "https://github.com/$owner/$repo/archive/refs/heads/main.zip"
    Invoke-WebRequest -Uri $fallbackUrl -OutFile $zipPath -ErrorAction Stop
    Write-Host '    [WARN] Integrity cannot be verified on fallback path' -ForegroundColor Yellow
}
Write-Host '  [OK] Downloaded' -ForegroundColor Green

Write-Host '  [2/3] Extracting...' -ForegroundColor White
try {
    Expand-Archive -Path $zipPath -DestinationPath $workDir -Force -ErrorAction Stop
    $moduleRoot = Join-Path -Path $workDir -ChildPath 'PrinterToolkit'
    if (-not (Test-Path -Path $moduleRoot)) {
        $moduleRoot = $workDir
    }
    Write-Host '  [OK] Extracted' -ForegroundColor Green
} catch {
    Write-Host "  [FAIL] Extract failed: $_" -ForegroundColor Red
    exit 1
}

Write-Host '  [3/3] Loading module...' -ForegroundColor White
try {
    $manifest = Join-Path -Path $moduleRoot -ChildPath 'PrinterToolkit.psd1'
    if (-not (Test-Path -Path $manifest)) { throw 'Module manifest not found' }
    Import-Module -Name $manifest -Force -ErrorAction Stop
    $status = Get-ToolkitStatus
    Write-Host "  [OK] Loaded $($status.LoadedModules.Count) submodules" -ForegroundColor Green
    Write-Host ''
    Write-Host "PrinterToolkit v$($status.Version) ready on $($status.LoadedModules.Count) modules." -ForegroundColor Cyan
    Write-Host 'Opening dashboard...' -ForegroundColor Gray
    Start-Sleep -Milliseconds 500

    Invoke-ToolkitMainMenu
} catch {
    Write-Host "  [FAIL] Module load failed: $_" -ForegroundColor Red
    $null = Read-Host 'Press Enter to exit'
    exit 1
}

if (-not $Keep) {
    Write-Host 'Cleaning up...' -ForegroundColor Gray
    Remove-Item -Path $workDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host 'Goodbye.' -ForegroundColor Cyan
