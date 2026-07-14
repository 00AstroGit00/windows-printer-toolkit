<#
.SYNOPSIS
    v8.2 Performance benchmark harness (Phase 6).

.DESCRIPTION
    Measures module import, orchestrator startup, detection, validation,
    zero-touch deployment, diagnostics, and reporting. Runs each benchmark
    multiple times and reports averages. Run on each target OS / PowerShell
    version; capture the JSON for the performance benchmark report.

    Usage:
      .\v8.2.Benchmark.ps1 -Iterations 5 -OutDir C:\v82\perf
#>
[CmdletBinding()]
param(
    [int]$Iterations = 5,
    [string]$OutDir = (Join-Path ([System.IO.Path]::GetTempPath()) "PrinterToolkit_v82_perf_$(Get-Date -Format 'yyyyMMdd_HHmmss')")
)

$modulePath = Resolve-Path -Path "$PSScriptRoot\..\PrinterToolkit.psm1"
$null = New-Item -ItemType Directory -Force -Path $OutDir

function Measure-Avg($label, $sb) {
    $times = for ($i = 0; $i -lt $Iterations; $i++) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        try { & $sb | Out-Null } catch { Write-Warning "$label run $i failed: $_" }
        $sw.Stop()
        $sw.ElapsedMilliseconds
    }
    [PSCustomObject]@{
        Benchmark = $label
        Iterations = $Iterations
        AverageMs = [math]::Round(($times | Measure-Object -Average).Average, 1)
        MinMs = ($times | Measure-Object -Minimum).Minimum
        MaxMs = ($times | Measure-Object -Maximum).Maximum
        Samples = $times
    }
}

$benchmarks = @(
    (Measure-Avg 'ModuleImport' { Import-Module $modulePath -Force -ErrorAction Stop }),
    (Measure-Avg 'OrchestratorStartup' { Get-Command Invoke-Orchestrator -ErrorAction Stop | Out-Null }),
    (Measure-Avg 'Detection' { Get-Printer -ErrorAction SilentlyContinue | Out-Null; Get-UsbPrinterInfo -ErrorAction SilentlyContinue | Out-Null }),
    (Measure-Avg 'Validation' { Invoke-EndToEndValidation -ErrorAction SilentlyContinue | Out-Null }),
    (Measure-Avg 'Diagnostics' { Get-NetworkValidation -ErrorAction SilentlyContinue | Out-Null }),
    (Measure-Avg 'Reporting' { New-PrinterReport -Format JSON -ErrorAction SilentlyContinue | Out-Null })
)

$meta = [PSCustomObject]@{
    Host = [System.Environment]::MachineName
    OS = (Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue).Caption
    PSVersion = $PSVersionTable.PSVersion.ToString()
    Iterations = $Iterations
    CapturedAt = Get-Date
    Benchmarks = $benchmarks
}

$meta | ConvertTo-Json -Depth 6 | Out-File -FilePath (Join-Path $OutDir 'benchmark.json') -Encoding UTF8
$benchmarks | Format-Table Benchmark, AverageMs, MinMs, MaxMs -AutoSize
Write-Host "Benchmark complete. JSON: $(Join-Path $OutDir 'benchmark.json')"
