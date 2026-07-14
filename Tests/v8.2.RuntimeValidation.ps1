<#
.SYNOPSIS
    v8.2 Windows Runtime Validation runner (Phases 1, 3, 4, 5, 6).

.DESCRIPTION
    Executes the toolkit on a real Windows host and captures transcripts/logs
    for evidence. Run AS ADMINISTRATOR from PowerShell 5.1 and PowerShell 7.x
    on each target OS (Win10 22H2, Win11 23H2, Win11 24H2).

    This runner does NOT fabricate results; it executes the real commands and
    writes a transcript + JSON summary per run so the evidence can be attached
    to the v8.2 runtime validation report.

    Usage:
      .\v8.2.RuntimeValidation.ps1 -OutDir C:\v82\evidence\Win11_23H2\PS7
#>
[CmdletBinding()]
param(
    [string]$OutDir = (Join-Path ([System.IO.Path]::GetTempPath()) "PrinterToolkit_v82_$(Get-Date -Format 'yyyyMMdd_HHmmss')")
)

$ErrorActionPreference = 'Continue'
$modulePath = Resolve-Path -Path "$PSScriptRoot\..\PrinterToolkit.psm1"
$null = New-Item -ItemType Directory -Force -Path $OutDir

$transcript = Join-Path $OutDir "transcript_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
Start-Transcript -Path $transcript -Force | Out-Null

$summary = [ordered]@{
    Host         = [System.Environment]::MachineName
    OS           = (Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue).Caption
    PSVersion    = $PSVersionTable.PSVersion.ToString()
    StartedAt    = Get-Date
    Steps        = [ordered]@{}
}

function Record-Step($name, $scriptblock) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $out = & $scriptblock 2>&1
        $summary.Steps[$name] = [ordered]@{
            Status = 'OK'
            DurationMs = $sw.ElapsedMilliseconds
            Output = ($out | Out-String -Width 200)
        }
    } catch {
        $summary.Steps[$name] = [ordered]@{
            Status = 'ERROR'
            DurationMs = $sw.ElapsedMilliseconds
            Error = $_.ToString()
        }
    } finally { $sw.Stop() }
}

Record-Step 'ModuleImport' { Import-Module $modulePath -Force -ErrorAction Stop ; Get-ToolkitStatus }
Record-Step 'ProviderLoading' { Get-Command -Module PrinterToolkit.* | Select-Object Name }
Record-Step 'OrchestratorStartup' { Get-Command Invoke-Orchestrator, Invoke-ConfigurationProvider, Invoke-RecoveryEngine -ErrorAction SilentlyContinue }
Record-Step 'Diagnostics' { Get-NetworkValidation }
Record-Step 'Validation' { Invoke-EndToEndValidation }
Record-Step 'Reporting' { New-PrinterReport -Format All -OutputPath (Join-Path $OutDir 'report') }
Record-Step 'RollbackPoints' { Initialize-RepairRollback }
Record-Step 'AndroidConnectivity' { Get-AndroidCompatibility }
Record-Step 'ConnectionInfo' { Get-ConnectionInfo }

$summary.FinishedAt = Get-Date
$summary | ConvertTo-Json -Depth 6 | Out-File -FilePath (Join-Path $OutDir 'summary.json') -Encoding UTF8

Stop-Transcript | Out-Null
Write-Host "Runtime validation complete. Evidence in: $OutDir"
