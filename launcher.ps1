<#
.SYNOPSIS
    PrinterToolkit v5.0.1 - Standalone launcher script for direct execution.

.DESCRIPTION
    Entry point that imports the PrinterToolkit module and launches the
    interactive menu. Supports -Menu and -CommandLine parameters.

.PARAMETER Menu
    Launch interactive menu (default).

.PARAMETER CommandLine
    Run a single command and exit.

.PARAMETER Command
    The command to run when using -CommandLine.

.PARAMETER Quiet
    Suppress banner output.

.EXAMPLE
    .\launcher.ps1

.EXAMPLE
    .\launcher.ps1 -CommandLine -Command "Get-Printers | Export-Csv inventory.csv"
#>

[CmdletBinding()]
param(
    [switch]$Menu,
    [switch]$CommandLine,
    [string]$Command = '',
    [switch]$Quiet
)

$ModuleRoot = Split-Path -Parent $PSCommandPath
$ModulePath = Join-Path -Path $ModuleRoot -ChildPath 'PrinterToolkit.psd1'

try {
    Import-Module -Name $ModulePath -Force -ErrorAction Stop
} catch {
    Write-Host "FATAL: Could not load PrinterToolkit module: $_" -ForegroundColor Red
    Write-Host "Module path: $ModulePath" -ForegroundColor Yellow
    exit 1
}

if (-not $Quiet) {
    $host.UI.RawUI.WindowTitle = "PrinterToolkit v8.0.0 - Print Server Deployment Platform"
Write-Host 'PrinterToolkit v8.0.0' -ForegroundColor Cyan
Write-Host 'Print Server Deployment Platform' -ForegroundColor Gray
    $status = Get-ToolkitStatus
    Write-Host "Loaded $($status.LoadedModules.Count) module(s)" -ForegroundColor Gray
}

if ($CommandLine -and $Command) {
    try {
        $safeCommands = @('Get-Printers', 'Get-PrinterStatus', 'Get-ToolkitStatus', 'Get-SystemInfo', 'Get-PrinterDriverDetails')
        $matched = $safeCommands | Where-Object { $Command -match "^$_(\s|$|\|)" }
        if (-not $matched) {
            Write-Host "Command not in allowlist. Safe commands: $($safeCommands -join ', ')" -ForegroundColor Yellow
            exit 3
        }
        Invoke-Expression $Command
    } catch {
        Write-Host "Command failed: $_" -ForegroundColor Red
        exit 2
    }
    exit 0
}

Invoke-ToolkitMainMenu
