<#
.SYNOPSIS
    PrinterToolkit v8.2.0-rc1 — External QA Certification Entry Point.

.DESCRIPTION
    Single-entry certification harness for independent Windows validation.
    Executes all test phases in sequence, collects evidence, generates
    HTML/MD/JSON summaries, and packages everything into a ZIP archive.

    Must be run from the repository root in an elevated PowerShell session.

.PARAMETER OutputDir
    Override the default output directory (Certification\Results\TIMESTAMP).

.PARAMETER SkipBenchmarks
    Skip Phase 5 performance benchmarks (saves time on slow machines).

.PARAMETER SkipFailureInjection
    Skip Phase 4 failure injection tests.

.EXAMPLE
    .\Start-Certification.ps1
    .\Start-Certification.ps1 -SkipBenchmarks
    .\Start-Certification.ps1 -OutputDir C:\QA\results
#>

[CmdletBinding()]
param(
    [string]$OutputDir,
    [switch]$SkipBenchmarks,
    [switch]$SkipFailureInjection
)

$ErrorActionPreference = 'Continue'
$InformationPreference = 'Continue'

# ---------------------------------------------------------------------------
# Bootstrap
# ---------------------------------------------------------------------------

$ModuleRoot = $PSScriptRoot
$Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$Script:ResultsDir = if ($OutputDir) { $OutputDir } else { Join-Path $ModuleRoot "Certification\Results\$Timestamp" }
$Script:ToolkitVersion = '8.2.0-rc1'
$Script:Phases = @()
$Script:OverallSuccess = $true
$Script:TranscriptPath = $null

# Create output directory
$null = New-Item -ItemType Directory -Force -Path $Script:ResultsDir

function Write-CertStep {
    param([string]$Message, [string]$Status = 'INFO')
    $color = switch ($Status) {
        'PASS' { 'Green' }; 'FAIL' { 'Red' }; 'WARN' { 'Yellow' }
        'SKIP' { 'DarkYellow' }; 'INFO' { 'White' }
        default { 'White' }
    }
    Write-Host "[$($Status.PadRight(4))] $Message" -ForegroundColor $color
}

function Add-PhaseResult {
    param(
        [string]$Phase,
        [string]$Status,
        [int]$Passed = 0,
        [int]$Failed = 0,
        [int]$Skipped = 0,
        [string]$Detail = ''
    )
    $Script:Phases += [PSCustomObject]@{
        Phase   = $Phase
        Status  = $Status
        Passed  = $Passed
        Failed  = $Failed
        Skipped = $Skipped
        Detail  = $Detail
    }
    if ($Status -ne 'PASS' -and $Status -ne 'SKIP') { $Script:OverallSuccess = $false }
}

# ---------------------------------------------------------------------------
# Phase 0 — Environment Verification
# ---------------------------------------------------------------------------

function Test-CertificationEnvironment {
    Write-CertStep '=== Phase 0: Environment Verification ===' 'INFO'

    # 0a. Administrator check
    $isAdmin = (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-CertStep 'Not running as Administrator. Some tests will fail.' 'WARN'
    } else {
        Write-CertStep 'Administrator privilege confirmed' 'PASS'
    }

    # 0b. Windows version
    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
    if ($os) {
        $osVersion = "$($os.Caption) (build $($os.BuildNumber))"
        Write-CertStep "OS: $osVersion" 'PASS'
    } else {
        $osVersion = 'Unknown'
        Write-CertStep 'Could not detect OS version' 'WARN'
    }

    # 0c. PowerShell version
    $psVersion = $PSVersionTable.PSVersion.ToString()
    Write-CertStep "PowerShell: $psVersion" 'PASS'

    # 0d. Required modules
    $requiredMods = @('PrintManagement', 'NetSecurity', 'NetConnection', 'DISM', 'CimCmdlets')
    $missingMods = @()
    foreach ($m in $requiredMods) {
        if (-not (Get-Module -ListAvailable -Name $m -ErrorAction SilentlyContinue)) {
            $missingMods += $m
        }
    }
    if ($missingMods.Count -gt 0) {
        Write-CertStep "Missing Windows modules: $($missingMods -join ', ')" 'WARN'
    } else {
        Write-CertStep 'All required Windows modules available' 'PASS'
    }

    # 0e. Pester
    $pester = Get-Module -ListAvailable -Name Pester -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $pester) {
        Write-CertStep 'Pester not installed. Phase 2 will be skipped.' 'WARN'
    } else {
        Write-CertStep "Pester v$($pester.Version) available" 'PASS'
    }

    # 0f. Git commit
    $gitCommit = $null
    try { $gitCommit = (git rev-parse HEAD --short 2>$null) } catch {}
    if (-not $gitCommit) { $gitCommit = 'not-a-git-repo' }

    # 0g. Start transcript
    $Script:TranscriptPath = Join-Path $Script:ResultsDir 'certification_transcript.txt'
    try {
        Start-Transcript -Path $Script:TranscriptPath -Force -ErrorAction Stop | Out-Null
        Write-CertStep "Transcript started: $Script:TranscriptPath" 'PASS'
    } catch {
        Write-CertStep "Transcript failed: $_" 'WARN'
    }

    # Return environment info
    return [PSCustomObject]@{
        OS              = $osVersion
        PowerShell      = $psVersion
        IsAdministrator = $isAdmin
        PesterAvailable = ($null -ne $pester)
        MissingModules  = @($missingMods)
        GitCommit       = $gitCommit
        Timestamp       = $Timestamp
        ToolkitVersion  = $Script:ToolkitVersion
        WorkingDirectory = $ModuleRoot
    }
}

# ---------------------------------------------------------------------------
# Phase 1 — Module Import & Pester Tests
# ---------------------------------------------------------------------------

function Invoke-Phase1 {
    Write-CertStep '=== Phase 1: Module Import & Pester Tests ===' 'INFO'

    $phaseResult = [PSCustomObject]@{ Passed = 0; Failed = 0; Skipped = 0; Detail = '' }

    # 1a. Import module
    $manifest = Join-Path $ModuleRoot 'PrinterToolkit.psd1'
    try {
        Import-Module $manifest -Force -ErrorAction Stop
        $mod = Get-Module PrinterToolkit
        Write-CertStep "Module loaded: $($mod.Version) with $($mod.NestedModules.Count) submodules" 'PASS'
    } catch {
        Write-CertStep "Module import FAILED: $_" 'FAIL'
        $phaseResult.Detail = $_.Exception.Message
        $phaseResult.Failed = 1
        Add-PhaseResult -Phase '1-ModuleImport' -Status 'FAIL' -Failed 1 -Detail $_.Exception.Message
        return $phaseResult
    }

    # 1b. Run Pester tests
    $pester = Get-Module -ListAvailable -Name Pester -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $pester) {
        Write-CertStep 'Skipping Pester tests: Pester not installed' 'SKIP'
        Add-PhaseResult -Phase '1-PesterTests' -Status 'SKIP' -Skipped 1 -Detail 'Pester not installed'
        $phaseResult.Skipped = 1
        return $phaseResult
    }

    $testFile = Join-Path $ModuleRoot 'Tests\PrinterToolkit.Tests.ps1'
    if (-not (Test-Path $testFile)) {
        Write-CertStep "Test file not found: $testFile" 'FAIL'
        Add-PhaseResult -Phase '1-PesterTests' -Status 'FAIL' -Failed 1 -Detail 'Test file missing'
        $phaseResult.Failed = 1
        return $phaseResult
    }

    try {
        $results = Invoke-Pester -Path $testFile -PassThru -OutputFile (Join-Path $Script:ResultsDir 'pester_results.xml') -OutputFormat NUnitXml -ErrorAction SilentlyContinue
        $phaseResult.Passed = $results.PassedCount
        $phaseResult.Failed = $results.FailedCount
        $phaseResult.Skipped = $results.SkippedCount

        if ($results.FailedCount -gt 0) {
            Write-CertStep "Pester: $($results.PassedCount) passed, $($results.FailedCount) failed, $($results.SkippedCount) skipped" 'FAIL'
            Add-PhaseResult -Phase '1-PesterTests' -Status 'FAIL' -Passed $results.PassedCount -Failed $results.FailedCount -Skipped $results.SkippedCount
        } else {
            Write-CertStep "Pester: $($results.PassedCount) passed, $($results.FailedCount) failed, $($results.SkippedCount) skipped" 'PASS'
            Add-PhaseResult -Phase '1-PesterTests' -Status 'PASS' -Passed $results.PassedCount -Skipped $results.SkippedCount
        }
    } catch {
        Write-CertStep "Pester execution failed: $_" 'FAIL'
        Add-PhaseResult -Phase '1-PesterTests' -Status 'FAIL' -Failed 1 -Detail $_.Exception.Message
        $phaseResult.Failed = 1
    }

    return $phaseResult
}

# ---------------------------------------------------------------------------
# Phase 2 — Provider Certification (Pester)
# ---------------------------------------------------------------------------

function Invoke-Phase2 {
    Write-CertStep '=== Phase 2: Provider Certification ===' 'INFO'

    $pester = Get-Module -ListAvailable -Name Pester -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $pester) {
        Write-CertStep 'Skipping: Pester not installed' 'SKIP'
        Add-PhaseResult -Phase '2-ProviderCert' -Status 'SKIP' -Skipped 1 -Detail 'Pester not installed'
        return [PSCustomObject]@{ Passed = 0; Failed = 0; Skipped = 1; Detail = 'Pester not installed' }
    }

    $testFile = Join-Path $ModuleRoot 'Tests\v8.2.ProviderCert.Tests.ps1'
    if (-not (Test-Path $testFile)) {
        Write-CertStep "Test file not found: $testFile" 'FAIL'
        Add-PhaseResult -Phase '2-ProviderCert' -Status 'FAIL' -Failed 1 -Detail 'Test file missing'
        return [PSCustomObject]@{ Passed = 0; Failed = 1; Skipped = 0; Detail = 'Test file missing' }
    }

    try {
        $results = Invoke-Pester -Path $testFile -PassThru -OutputFile (Join-Path $Script:ResultsDir 'provider_cert_results.xml') -OutputFormat NUnitXml -ErrorAction SilentlyContinue
        if ($results.FailedCount -gt 0) {
            Write-CertStep "Provider cert: $($results.PassedCount) passed, $($results.FailedCount) failed" 'FAIL'
            Add-PhaseResult -Phase '2-ProviderCert' -Status 'FAIL' -Passed $results.PassedCount -Failed $results.FailedCount -Skipped $results.SkippedCount
        } else {
            Write-CertStep "Provider cert: $($results.PassedCount) passed" 'PASS'
            Add-PhaseResult -Phase '2-ProviderCert' -Status 'PASS' -Passed $results.PassedCount -Skipped $results.SkippedCount
        }
        return [PSCustomObject]@{ Passed = $results.PassedCount; Failed = $results.FailedCount; Skipped = $results.SkippedCount; Detail = '' }
    } catch {
        Write-CertStep "Provider cert execution failed: $_" 'FAIL'
        Add-PhaseResult -Phase '2-ProviderCert' -Status 'FAIL' -Failed 1 -Detail $_.Exception.Message
        return [PSCustomObject]@{ Passed = 0; Failed = 1; Skipped = 0; Detail = $_.Exception.Message }
    }
}

# ---------------------------------------------------------------------------
# Phase 3 — Runtime Validation
# ---------------------------------------------------------------------------

function Invoke-Phase3 {
    Write-CertStep '=== Phase 3: Runtime Validation ===' 'INFO'

    $scriptPath = Join-Path $ModuleRoot 'Tests\v8.2.RuntimeValidation.ps1'
    $outPath = Join-Path $Script:ResultsDir 'runtime_validation.json'

    if (-not (Test-Path $scriptPath)) {
        Write-CertStep "Runtime validation script not found: $scriptPath" 'FAIL'
        Add-PhaseResult -Phase '3-RuntimeValidation' -Status 'FAIL' -Failed 1 -Detail 'Script not found'
        return $null
    }

    try {
        & $scriptPath -OutputPath $outPath -ErrorAction SilentlyContinue
        if (Test-Path $outPath) {
            $data = Get-Content $outPath -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
            Write-CertStep "Runtime validation completed. Output: $outPath" 'PASS'
            Add-PhaseResult -Phase '3-RuntimeValidation' -Status 'PASS' -Passed 1
            return $data
        } else {
            Write-CertStep 'Runtime validation completed but no output file generated' 'WARN'
            Add-PhaseResult -Phase '3-RuntimeValidation' -Status 'WARN' -Detail 'No output file'
            return $null
        }
    } catch {
        Write-CertStep "Runtime validation failed: $_" 'FAIL'
        Add-PhaseResult -Phase '3-RuntimeValidation' -Status 'FAIL' -Failed 1 -Detail $_.Exception.Message
        return $null
    }
}

# ---------------------------------------------------------------------------
# Phase 4 — Failure Injection
# ---------------------------------------------------------------------------

function Invoke-Phase4 {
    if ($SkipFailureInjection) {
        Write-CertStep '=== Phase 4: Failure Injection (SKIPPED) ===' 'SKIP'
        Add-PhaseResult -Phase '4-FailureInjection' -Status 'SKIP' -Skipped 1 -Detail 'Skipped by flag'
        return $null
    }

    Write-CertStep '=== Phase 4: Failure Injection ===' 'INFO'

    $scriptPath = Join-Path $ModuleRoot 'Tests\v8.2.FailureInjection.ps1'
    $outPath = Join-Path $Script:ResultsDir 'failure_injection.json'

    if (-not (Test-Path $scriptPath)) {
        Write-CertStep "Failure injection script not found: $scriptPath" 'FAIL'
        Add-PhaseResult -Phase '4-FailureInjection' -Status 'FAIL' -Failed 1 -Detail 'Script not found'
        return $null
    }

    try {
        & $scriptPath -OutputPath $outPath -ErrorAction SilentlyContinue
        if (Test-Path $outPath) {
            $data = Get-Content $outPath -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
            Write-CertStep "Failure injection completed. Output: $outPath" 'PASS'
            Add-PhaseResult -Phase '4-FailureInjection' -Status 'PASS' -Passed 1
            return $data
        } else {
            Write-CertStep 'Failure injection completed but no output file' 'WARN'
            Add-PhaseResult -Phase '4-FailureInjection' -Status 'WARN' -Detail 'No output file'
            return $null
        }
    } catch {
        Write-CertStep "Failure injection failed: $_" 'FAIL'
        Add-PhaseResult -Phase '4-FailureInjection' -Status 'FAIL' -Failed 1 -Detail $_.Exception.Message
        return $null
    }
}

# ---------------------------------------------------------------------------
# Phase 5 — Performance Benchmarks
# ---------------------------------------------------------------------------

function Invoke-Phase5 {
    if ($SkipBenchmarks) {
        Write-CertStep '=== Phase 5: Benchmarks (SKIPPED) ===' 'SKIP'
        Add-PhaseResult -Phase '5-Benchmarks' -Status 'SKIP' -Skipped 1 -Detail 'Skipped by flag'
        return $null
    }

    Write-CertStep '=== Phase 5: Performance Benchmarks ===' 'INFO'

    $scriptPath = Join-Path $ModuleRoot 'Tests\v8.2.Benchmark.ps1'
    $outPath = Join-Path $Script:ResultsDir 'benchmark.json'

    if (-not (Test-Path $scriptPath)) {
        Write-CertStep "Benchmark script not found: $scriptPath" 'FAIL'
        Add-PhaseResult -Phase '5-Benchmarks' -Status 'FAIL' -Failed 1 -Detail 'Script not found'
        return $null
    }

    try {
        & $scriptPath -OutputPath $outPath -Iterations 5 -ErrorAction SilentlyContinue
        if (Test-Path $outPath) {
            $data = Get-Content $outPath -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
            Write-CertStep "Benchmarks completed. Output: $outPath" 'PASS'
            Add-PhaseResult -Phase '5-Benchmarks' -Status 'PASS' -Passed 1
            return $data
        } else {
            Write-CertStep 'Benchmarks completed but no output file' 'WARN'
            Add-PhaseResult -Phase '5-Benchmarks' -Status 'WARN' -Detail 'No output file'
            return $null
        }
    } catch {
        Write-CertStep "Benchmarks failed: $_" 'FAIL'
        Add-PhaseResult -Phase '5-Benchmarks' -Status 'FAIL' -Failed 1 -Detail $_.Exception.Message
        return $null
    }
}

# ---------------------------------------------------------------------------
# Phase 6 — Evidence Collection & Packaging
# ---------------------------------------------------------------------------

function Invoke-Phase6 {
    Write-CertStep '=== Phase 6: Evidence Collection & Packaging ===' 'INFO'

    # Collect toolkit logs
    try {
        $logPathCmd = Get-Command -Name Get-LogFilePath -ErrorAction SilentlyContinue
        if ($logPathCmd) {
            $logInfo = Get-LogFilePath -ErrorAction SilentlyContinue
            if ($logInfo -and $logInfo.Path -and (Test-Path $logInfo.Path)) {
                Copy-Item -Path $logInfo.Path -Destination (Join-Path $Script:ResultsDir 'toolkit_logs.log') -Force -ErrorAction SilentlyContinue
                Write-CertStep 'Toolkit logs collected' 'PASS'
            }
        }
    } catch { Write-CertStep 'Toolkit logs not available' 'WARN' }

    # Collect diagnostic bundle
    try {
        $bundleCmd = Get-Command -Name New-DiagnosticBundle -ErrorAction SilentlyContinue
        if ($bundleCmd) {
            $bundlePath = Join-Path $Script:ResultsDir 'diagnostic_bundle.zip'
            New-DiagnosticBundle -OutputPath $bundlePath -ErrorAction SilentlyContinue
            if (Test-Path $bundlePath) {
                Write-CertStep 'Diagnostic bundle collected' 'PASS'
            }
        }
    } catch { Write-CertStep 'Diagnostic bundle not available' 'WARN' }

    # Collect environment snapshot
    try {
        $sysInfo = Get-SystemInfo -ErrorAction SilentlyContinue
        if ($sysInfo) {
            $sysInfo | ConvertTo-Json -Depth 5 | Out-File (Join-Path $Script:ResultsDir 'system_info.json') -Encoding UTF8
            Write-CertStep 'Environment snapshot collected' 'PASS'
        }
    } catch { Write-CertStep 'Environment snapshot not available' 'WARN' }

    # Collect git commit
    try {
        $commit = git rev-parse HEAD 2>$null
        if ($commit) {
            $commit | Out-File (Join-Path $Script:ResultsDir 'git_commit.txt') -Encoding UTF8
        }
    } catch {}

    Write-CertStep 'Evidence collection complete' 'PASS'
}

# ---------------------------------------------------------------------------
# Phase 7 — Summary & Reports
# ---------------------------------------------------------------------------

function Invoke-Phase7 {
    param($Environment, $Phase1, $Phase2, $Phase3, $Phase4, $Phase5)

    Write-CertStep '=== Phase 7: Generating Reports ===' 'INFO'

    $totalPassed = 0; $totalFailed = 0; $totalSkipped = 0
    foreach ($p in $Script:Phases) {
        $totalPassed += $p.Passed
        $totalFailed += $p.Failed
        $totalSkipped += $p.Skipped
    }

    # Load known issues
    $knownIssuesPath = Join-Path $ModuleRoot 'docs\v8.2\10-known-issues.md'
    $knownIssues = if (Test-Path $knownIssuesPath) { Get-Content $knownIssuesPath -Raw } else { 'Not available' }

    # Determine recommendation
    switch ($true) {
        ($totalFailed -gt 0) {
            $recommendation = 'NO-GO'
            $recommendationDetail = "$totalFailed test failure(s) detected. Issues must be resolved before re-certification."
        }
        ($totalSkipped -gt 2) {
            $recommendation = 'GO WITH LIMITATIONS'
            $recommendationDetail = "All executed tests passed but $totalSkipped test(s) were skipped (missing dependencies). Limited confidence."
        }
        ($Script:Phases.Count -lt 4) {
            $recommendation = 'GO WITH LIMITATIONS'
            $recommendationDetail = "Fewer phases executed than expected. Results are partial."
        }
        default {
            $recommendation = 'GO WITH LIMITATIONS'
            $recommendationDetail = 'All executed tests passed. However, runtime evidence on Windows is still limited. See RC notes.'
        }
    }

    # Build summary
    $summary = [PSCustomObject]@{
        Metadata = [PSCustomObject]@{
            Title              = 'PrinterToolkit Certification Report'
            ToolkitVersion     = $Script:ToolkitVersion
            GitCommit          = $Environment.GitCommit
            Timestamp          = $Timestamp
            GeneratedBy        = 'Start-Certification.ps1'
            WorkingDirectory   = $ModuleRoot
        }
        Environment = $Environment
        PhaseResults = @($Script:Phases)
        TestCounts = [PSCustomObject]@{
            Total  = ($totalPassed + $totalFailed + $totalSkipped)
            Passed = $totalPassed
            Failed = $totalFailed
            Skipped = $totalSkipped
        }
        OverallResult = if ($totalFailed -gt 0) { 'FAIL' } else { 'PASS' }
        Recommendation = $recommendation
        RecommendationDetail = $recommendationDetail
        KnownIssues = $knownIssues
    }

    # Export HTML
    $htmlPath = Join-Path $Script:ResultsDir 'summary.html'
    $html = @"
<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8"><title>PrinterToolkit Certification Report</title>
<style>
body{font-family:'Segoe UI',sans-serif;margin:20px;background:#f5f5f5;color:#333}
h1{color:#0066cc;border-bottom:2px solid #0066cc;padding-bottom:8px}
h2{color:#003366;margin-top:30px}
table{border-collapse:collapse;width:100%;margin:10px 0;background:#fff}
th,td{border:1px solid #ccc;padding:8px 12px;text-align:left}
th{background:#0066cc;color:#fff}
.PASS{background:#d4edda;color:#155724;font-weight:700}
.FAIL{background:#f8d7da;color:#721c24;font-weight:700}
.SKIP{background:#fff3cd;color:#856404;font-weight:700}
.WARN{background:#fff3cd;color:#856404}
pre{background:#eee;padding:10px;border-radius:4px;overflow-x:auto}
.summary-card{display:inline-block;padding:15px 25px;margin:10px;border-radius:8px;color:#fff;font-size:18px;font-weight:700}
.total{background:#0066cc}
.pass{background:#28a745}
.fail{background:#dc3545}
.skip{background:#ffc107;color:#333}
</style></head>
<body>
<h1>PrinterToolkit $Script:ToolkitVersion — Certification Report</h1>
<p>Generated: $(Get-Date) | Git: $($Environment.GitCommit)</p>

<div style="text-align:center;margin:20px 0">
<div class="summary-card total">Total: $($summary.TestCounts.Total)</div>
<div class="summary-card pass">Passed: $($summary.TestCounts.Passed)</div>
<div class="summary-card fail">Failed: $($summary.TestCounts.Failed)</div>
<div class="summary-card skip">Skipped: $($summary.TestCounts.Skipped)</div>
</div>

<h2>Environment</h2>
<table>
<tr><th>Property</th><th>Value</th></tr>
<tr><td>OS</td><td>$($Environment.OS)</td></tr>
<tr><td>PowerShell</td><td>$($Environment.PowerShell)</td></tr>
<tr><td>Administrator</td><td>$($Environment.IsAdministrator)</td></tr>
<tr><td>Pester</td><td>$($Environment.PesterAvailable)</td></tr>
<tr><td>Git Commit</td><td>$($Environment.GitCommit)</td></tr>
<tr><td>Working Directory</td><td>$($Environment.WorkingDirectory)</td></tr>
</table>

<h2>Phase Results</h2>
<table>
<tr><th>Phase</th><th>Status</th><th>Passed</th><th>Failed</th><th>Skipped</th><th>Detail</th></tr>
"@
    foreach ($p in $Script:Phases) {
        $html += "<tr><td>$($p.Phase)</td><td class='$($p.Status)'>$($p.Status)</td><td>$($p.Passed)</td><td>$($p.Failed)</td><td>$($p.Skipped)</td><td>$($p.Detail)</td></tr>"
    }
    $html += @"
</table>

<h2>Recommendation</h2>
<div class="summary-card $($recommendation)">$recommendation</div>
<p>$recommendationDetail</p>

<h2>Known Issues</h2>
<pre>$knownIssues</pre>

<h2>Artifacts</h2>
<ul>
<li><a href="certification_transcript.txt">Transcript</a></li>
<li><a href="pester_results.xml">Pester Results (Phase 1)</a></li>
<li><a href="provider_cert_results.xml">Provider Certification Results (Phase 2)</a></li>
<li><a href="runtime_validation.json">Runtime Validation (Phase 3)</a></li>
<li><a href="failure_injection.json">Failure Injection (Phase 4)</a></li>
<li><a href="benchmark.json">Benchmarks (Phase 5)</a></li>
<li><a href="system_info.json">Environment Snapshot</a></li>
<li><a href="toolkit_logs.log">Toolkit Logs</a></li>
<li><a href="diagnostic_bundle.zip">Diagnostic Bundle</a></li>
<li><a href="certification_evidence.zip">Full Evidence ZIP</a></li>
</ul>
</body></html>
"@
    $html | Out-File $htmlPath -Encoding UTF8
    Write-CertStep "HTML report: $htmlPath" 'PASS'

    # Export Markdown
    $mdPath = Join-Path $Script:ResultsDir 'summary.md'
    $md = @"
# PrinterToolkit $Script:ToolkitVersion — Certification Summary

**Generated:** $(Get-Date)
**Git Commit:** $($Environment.GitCommit)
**OS:** $($Environment.OS)
**PowerShell:** $($Environment.PowerShell)

## Test Counts

| Metric | Count |
|--------|-------|
| Total | $($summary.TestCounts.Total) |
| Passed | $($summary.TestCounts.Passed) |
| Failed | $($summary.TestCounts.Failed) |
| Skipped | $($summary.TestCounts.Skipped) |

## Phase Results

| Phase | Status | Passed | Failed | Skipped | Detail |
|-------|--------|--------|--------|---------|--------|
"@
    foreach ($p in $Script:Phases) {
        $md += "| $($p.Phase) | $($p.Status) | $($p.Passed) | $($p.Failed) | $($p.Skipped) | $($p.Detail) |`n"
    }
    $md += @"

## Recommendation

**$recommendation** — $recommendationDetail

## Known Issues

```
$knownIssues
```
"@
    $md | Out-File $mdPath -Encoding UTF8
    Write-CertStep "Markdown report: $mdPath" 'PASS'

    # Export JSON
    $jsonPath = Join-Path $Script:ResultsDir 'summary.json'
    $summary | ConvertTo-Json -Depth 10 | Out-File $jsonPath -Encoding UTF8
    Write-CertStep "JSON report: $jsonPath" 'PASS'

    # Create evidence ZIP
    $zipPath = Join-Path $Script:ResultsDir 'certification_evidence.zip'
    try {
        Compress-Archive -Path "$($Script:ResultsDir)\*" -DestinationPath $zipPath -Force -ErrorAction Stop
        Write-CertStep "Evidence ZIP: $zipPath" 'PASS'
    } catch {
        Write-CertStep "ZIP creation failed: $_" 'WARN'
    }

    Write-CertStep "Output directory: $Script:ResultsDir" 'PASS'

    return $summary
}

# ---------------------------------------------------------------------------
# Main Execution
# ---------------------------------------------------------------------------

Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host " PrinterToolkit $Script:ToolkitVersion — Certification Harness" -ForegroundColor White
Write-Host ' External QA Validation' -ForegroundColor Gray
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ''

$envInfo = Test-CertificationEnvironment
$r1 = Invoke-Phase1
$r2 = Invoke-Phase2
$r3 = Invoke-Phase3
$r4 = Invoke-Phase4
$r5 = Invoke-Phase5
Invoke-Phase6
$summary = Invoke-Phase7 -Environment $envInfo -Phase1 $r1 -Phase2 $r2 -Phase3 $r3 -Phase4 $r4 -Phase5 $r5

# Stop transcript
try { Stop-Transcript -ErrorAction SilentlyContinue } catch {}

# Final output
Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ' CERTIFICATION COMPLETE' -ForegroundColor White
Write-Host " Recommendation: $($summary.Recommendation)" -ForegroundColor $(if ($summary.Recommendation -eq 'NO-GO') { 'Red' } elseif ($summary.Recommendation -eq 'GO WITH LIMITATIONS') { 'Yellow' } else { 'Green' })
Write-Host " Output: $Script:ResultsDir" -ForegroundColor Gray
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ''

# Return summary
$summary
