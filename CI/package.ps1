<#
.SYNOPSIS
    Release packaging script for PrinterToolkit.

.DESCRIPTION
    Creates a clean release ZIP archive from the built artifacts,
    generates release notes, and optionally makes a release tag.

.PARAMETER ArtifactPath
    Path to the build output (from build.ps1).

.PARAMETER Version
    Version string for the release. Default: from manifest.

.PARAMETER OutputDir
    Where to place the final release ZIP.

.EXAMPLE
    .\CI\package.ps1 -ArtifactPath .\artifacts\PrinterToolkit_v8.2.0_20260714 -Version 8.2.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ })]
    [string]$ArtifactPath,
    [string]$Version = '8.2.0',
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
- v8.2.0-rc1: Dependency-aware DAG orchestration engine with event bus, state manager, transaction log, and recovery
- v8.1: Native Windows Integration Layer (NetSecurity, CIM, DISM — no netsh/rundll32/pnputil)
- v8.0: Declarative task model with retry/timeout/elevation; configuration providers (Service, Firewall, Network, Sharing, IPP, Registry, Driver, Printer)
- v7.0: Zero-Touch one-click deployment with transaction logging and guided recovery
- v6.0: Print Server Platform with USB detection, driver intelligence, sharing, IPP, SMB, validation, rollback, QR codes

## Files
| File | Description |
|------|-------------|
| PrinterToolkit.psd1 | Module manifest |
| PrinterToolkit.psm1 | Root module |
| launcher.ps1 | Standalone entry point |
| Modules/ | 21 submodules |

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
