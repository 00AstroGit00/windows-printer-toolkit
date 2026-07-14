<#
.SYNOPSIS
    Release packaging script for PrinterToolkit v5.0.1.

.DESCRIPTION
    Creates a clean release ZIP archive from the built artifacts,
    generates release notes, and optionally makes a release tag.

.PARAMETER ArtifactPath
    Path to the build output (from build.ps1).

.PARAMETER Version
    Version string for the release. Default: 5.0.1.

.PARAMETER OutputDir
    Where to place the final release ZIP.

.EXAMPLE
    .\CI\package.ps1 -ArtifactPath .\artifacts\PrinterToolkit_v5.0.1_20260714 -Version 5.0.1
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ })]
    [string]$ArtifactPath,
    [string]$Version = '5.0.1',
    [string]$OutputDir
)

$ModuleRoot = Split-Path -Parent $PSScriptRoot
$Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'

if (-not $PSBoundParameters.ContainsKey('Version')) {
    $manifestPath = Join-Path -Path $ModuleRoot -ChildPath 'PrinterToolkit.psd1'
    if (Test-Path -Path $manifestPath) {
        $manifest = Import-PowerShellDataFile -Path $manifestPath -ErrorAction SilentlyContinue
        if ($manifest -and $manifest.ModuleVersion) {
            $Version = $manifest.ModuleVersion.ToString()
        }
    }
}

if (-not $OutputDir) {
    $OutputDir = Join-Path -Path $ModuleRoot -ChildPath 'releases'
}
$null = New-Item -ItemType Directory -Force -Path $OutputDir

$zipName = "PrinterToolkit_v$Version.zip"
$zipPath = Join-Path -Path $OutputDir -ChildPath $zipName

Write-Host 'Packaging PrinterToolkit release...' -ForegroundColor Cyan
Write-Host "  Artifacts: $ArtifactPath"
Write-Host "  Version:   $Version"
Write-Host "  Output:    $zipPath"

# Create ZIP
try {
    Compress-Archive -Path "$ArtifactPath\*" -DestinationPath $zipPath -Force -ErrorAction Stop
    Write-Host "Package created: $zipPath" -ForegroundColor Green
} catch {
    Write-Host "Package failed: $_" -ForegroundColor Red
    exit 1
}

# Generate release notes
$releaseNotesPath = Join-Path -Path $OutputDir -ChildPath "RELEASE_NOTES_v$Version.md"
$releaseNotes = @"
# PrinterToolkit v$Version

## Overview
Enterprise Windows printer troubleshooting and management toolkit.

## What's New
- Production-quality error handling with structured result objects
- Comprehensive logging framework (file, console, rotating)
- Type 4 driver detection and migration recommendations
- IPP class driver detection
- Android Mopria compatibility analysis
- Spooler integrity validation (files, registry, services)
- WSD printer discovery
- SMB 1.0/2.0/3.0 protocol detection
- 8-step automatic share repair with backup/rollback
- Professional HTML/JSON/CSV reporting with compliance checks
- Diagnostic bundle (ZIP archive of all system data)
- Driver export/restore with INF extraction
- Share permission management
- Transport switching: SMB, IPP, WSD

## Files
| File | Description |
|------|-------------|
| PrinterToolkit.psd1 | Module manifest |
| PrinterToolkit.psm1 | Root module |
| launcher.ps1 | Standalone entry point |
| Modules/ | 11 submodules |

## Installation
Import the module or run launcher.ps1.

## Requirements
- Windows 10/11 or Windows Server 2016+
- PowerShell 5.1+
- Administrator rights for management operations

## Support
Report issues at https://github.com/00AstroGit00/windows-printer-toolkit
"@
$releaseNotes | Out-File -FilePath $releaseNotesPath -Encoding UTF8

Write-Host "Release notes: $releaseNotesPath" -ForegroundColor Gray
Write-Host "Done." -ForegroundColor Green
