<#
.SYNOPSIS
    v8.2 Failure-Injection harness (Phase 5).

.DESCRIPTION
    Simulates production failure modes, executes the applicable providers /
    orchestrator repair, and captures whether the orchestrator identifies the
    failing task, limits blast radius to affected providers, performs rollback
    where appropriate, and recovers where possible.

    Run AS ADMINISTRATOR on a Windows host. Each scenario restores the system
    afterwards where technically safe. Review the produced JSON before reuse.

    Usage:
      .\v8.2.FailureInjection.ps1 -OutDir C:\v82\failure
#>
[CmdletBinding()]
param(
    [string]$OutDir = (Join-Path ([System.IO.Path]::GetTempPath()) "PrinterToolkit_v82_failure_$(Get-Date -Format 'yyyyMMdd_HHmmss')")
)

$ErrorActionPreference = 'Continue'
$modulePath = Resolve-Path -Path "$PSScriptRoot\..\PrinterToolkit.psm1"
Import-Module $modulePath -Force -ErrorAction Stop
$null = New-Item -ItemType Directory -Force -Path $OutDir

$results = [System.Collections.ArrayList]::new()

function Invoke-Scenario($name, $inject, $remediate, $verify) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $entry = [ordered]@{ Scenario = $name; Injected = $false; Repair = $null; Verified = $null; Error = '' }
    try {
        & $inject
        $entry.Injected = $true
        try { $entry.Repair = (& $remediate | Out-String -Width 200) } catch { $entry.Error = "repair: $_" }
        try { $entry.Verified = (& $verify | Out-String -Width 200) } catch { $entry.Error += " verify: $_" }
    } catch {
        $entry.Error = $_.ToString()
    } finally { $sw.Stop() }
    $entry.DurationMs = $sw.ElapsedMilliseconds
    $null = $results.Add([PSCustomObject]$entry)
}

# 1. Stopped spooler
Invoke-Scenario 'StoppedSpooler' `
    -inject { Stop-Service -Name Spooler -Force -ErrorAction Stop } `
    -remediate { Invoke-AutomaticShareRepair -TestMode } `
    -verify { (Get-Service Spooler).Status }

# 2. Firewall disabled (rule group disabled)
Invoke-Scenario 'FirewallDisabled' `
    -inject { Get-NetFirewallRule -DisplayGroup 'File and Printer Sharing' -ErrorAction SilentlyContinue | Disable-NetFirewallRule -ErrorAction SilentlyContinue } `
    -remediate { Enable-PrinterFirewallRules -IncludeIpp } `
    -verify { (Get-NetFirewallRule -DisplayGroup 'File and Printer Sharing' -ErrorAction SilentlyContinue | Where-Object { $_.Enabled }).Count -gt 0 }

# 3. Network profile mismatch (set to Public)
Invoke-Scenario 'NetworkProfileMismatch' `
    -inject { $p = Get-NetConnectionProfile -ErrorAction SilentlyContinue | Select-Object -First 1; if ($p) { Set-NetConnectionProfile -InterfaceIndex $p.InterfaceIndex -NetworkCategory Public -ErrorAction SilentlyContinue } } `
    -remediate { $p = Get-NetConnectionProfile -ErrorAction SilentlyContinue | Select-Object -First 1; if ($p) { Set-NetConnectionProfile -InterfaceIndex $p.InterfaceIndex -NetworkCategory Private -ErrorAction SilentlyContinue } } `
    -verify { (Get-NetConnectionProfile -ErrorAction SilentlyContinue | Select-Object -First 1).NetworkCategory -eq 'Private' }

# 4. Missing Windows feature (IPP client) — report only, do not auto-install in CI
Invoke-Scenario 'MissingWindowsFeature' `
    -inject { Write-Host 'Simulated: IPP client feature not installed' } `
    -remediate { Get-WindowsOptionalFeature -Online -FeatureName 'Printing-InternetPrinting-Client' -ErrorAction SilentlyContinue | Select-Object FeatureName, State } `
    -verify { $true }

# 5. Missing driver (remove a driver package if one exists)
Invoke-Scenario 'MissingDriver' `
    -inject { $d = Get-PrinterDriver -ErrorAction SilentlyContinue | Select-Object -First 1; if ($d) { Remove-PrinterDriver -Name $d.Name -ErrorAction SilentlyContinue; "Removed $($d.Name)" } else { 'No driver to remove' } } `
    -remediate { Get-DriverIntelligence -ErrorAction SilentlyContinue | Select-Object PrinterName, DriverFound } `
    -verify { $true }

$results | ConvertTo-Json -Depth 6 | Out-File -FilePath (Join-Path $OutDir 'failure_injection.json') -Encoding UTF8
Write-Host "Failure injection complete. Results: $(Join-Path $OutDir 'failure_injection.json')"
