<#
.SYNOPSIS
    Reporting engine for PrinterToolkit v6.0.

.DESCRIPTION
    Generates HTML, JSON, CSV, and Markdown reports from diagnostic data.
    Supports summary views, detailed printer inventory, compliance checks,
    validation dashboards, and QR code connectivity reports.

.NOTES
    Module: PrinterToolkit.Reporting
    Author: PrinterToolkit Contributors
#>

$Script:ReportTimestamp = { Get-Date -Format 'yyyy-MM-dd HH:mm:ss' }

function New-PrinterReport {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('HTML', 'JSON', 'CSV', 'Markdown', 'All')]
        [string]$Format = 'HTML',
        [Parameter(Mandatory = $false)]
        [string]$OutputPath,
        [Parameter(Mandatory = $false)]
        [switch]$IncludeValidation
    )

    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    if (-not $OutputPath) {
        $OutputPath = Join-Path -Path ([Environment]::GetFolderPath('Desktop')) -ChildPath "PrinterToolkit_Report_$stamp"
    }
    $null = New-Item -ItemType Directory -Force -Path $OutputPath

    $data = Get-PrinterReportData
    if ($IncludeValidation) {
        $data | Add-Member -MemberType NoteProperty -Name 'Validation' -Value (Invoke-EndToEndValidation)
    }

    $files = @()

    switch ($Format) {
        'HTML' {
            $f = New-PrinterReportHtml -Data $data -OutputPath $OutputPath
            $files += $f
        }
        'JSON' {
            $f = New-PrinterReportJson -Data $data -OutputPath $OutputPath
            $files += $f
        }
        'CSV' {
            $f = New-PrinterReportCsv -Data $data -OutputPath $OutputPath
            $files += $f
        }
        'Markdown' {
            $f = New-PrinterReportMarkdown -Data $data -OutputPath $OutputPath
            $files += $f
        }
        'All' {
            $files += New-PrinterReportHtml -Data $data -OutputPath $OutputPath
            $files += New-PrinterReportJson -Data $data -OutputPath $OutputPath
            $files += New-PrinterReportCsv -Data $data -OutputPath $OutputPath
            $files += New-PrinterReportMarkdown -Data $data -OutputPath $OutputPath
        }
    }

    return $files -join ', '
}

function Get-PrinterReportData {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()
    $printers = @(Get-Printer -ErrorAction SilentlyContinue)
    $drivers = @(Get-PrinterDriver -ErrorAction SilentlyContinue)
    $ports = @(Get-PrinterPort -ErrorAction SilentlyContinue)
    $defaultPrinter = Get-CimInstance -ClassName Win32_Printer -Filter "Default='True'" -ErrorAction SilentlyContinue
    $defaultPrinterName = if ($defaultPrinter) { $defaultPrinter.Name } else { $null }

    $driverMap = @{}
    foreach ($d in $drivers) {
        $driverMap[$d.Name] = if ($d.MajorVersion -ge 4) { 'Type 4' } else { 'Type 3' }
    }

    $printerDetail = foreach ($p in $printers) {
        $status = $p.PrinterStatus
        $statusLabel = switch ($status) {
            0 { 'Idle' }; 1 { 'Paused' }; 2 { 'Error' }; 3 { 'Pending Deletion' }
            4 { 'Paper Jam' }; 5 { 'Paper Out' }; 6 { 'Manual Feed' }
            7 { 'Paper Problem' }; 8 { 'Offline' }; 9 { 'IO Active' }
            10 { 'Busy' }; 11 { 'Printing' }; 12 { 'Output Bin Full' }
            13 { 'Not Available' }; 14 { 'Waiting' }; 15 { 'Processing' }
            16 { 'Initialization' }; 17 { 'Warming Up' }; 18 { 'Toner Low' }
            19 { 'No Toner' }; 20 { 'Page Punt' }; 21 { 'User Intervention' }
            22 { 'Out of Memory' }; 23 { 'Door Open' }; 24 { 'Server Unknown' }
            25 { 'Power Save' }; default { "Unknown ($status)" }
        }

        [PSCustomObject]@{
            Name            = $p.Name
            Shared          = $p.Shared
            ShareName       = $p.ShareName
            PortName        = $p.PortName
            DriverName      = $p.DriverName
            DriverType      = $driverMap[$p.DriverName]
            PrinterStatus   = $statusLabel
            Location        = $p.Location
            Comment         = $p.Comment
            IsDefault       = [string]$p.Name -eq [string]$defaultPrinterName
            Published       = $p.Published
        }
    }

    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
    $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue

    [PSCustomObject]@{
        ReportTitle      = 'PrinterToolkit Print Server Report'
        GeneratedAt      = &$Script:ReportTimestamp
        ComputerName     = $env:COMPUTERNAME
        OS               = if ($os) { "$($os.Caption) $($os.Version)" } else { 'Unknown' }
        Manufacturer     = if ($cs) { $cs.Manufacturer } else { 'Unknown' }
        Model            = if ($cs) { $cs.Model } else { 'Unknown' }
        TotalPrinters    = $printers.Count
        SharedPrinters   = @($printers | Where-Object { $_.Shared }).Count
        TotalDrivers     = $drivers.Count
        Type4Drivers     = @($drivers | Where-Object { $_.MajorVersion -ge 4 }).Count
        Type3Drivers     = @($drivers | Where-Object { $_.MajorVersion -lt 4 }).Count
        TotalPorts       = $ports.Count
        PrinterDetails   = @($printerDetail)
        ToolkitVersion   = '6.0.0'
    }
}

function New-PrinterReportHtml {
    param($Data, $OutputPath)

    $filePath = Join-Path -Path $OutputPath -ChildPath "PrinterReport_$($Data.ComputerName)_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"

    $printerRows = foreach ($p in $Data.PrinterDetails) {
        $statusColor = switch ($p.PrinterStatus) {
            'Idle' { 'green' }; 'Printing' { 'blue' }; 'Offline' { 'red' }; 'Error' { 'red' }
            default { 'orange' }
        }
        $shareIcon = if ($p.Shared) { 'Yes' } else { 'No' }
        @"
        <tr>
            <td>$($p.Name)</td>
            <td>$shareIcon</td>
            <td>$($p.ShareName)</td>
            <td>$($p.PortName)</td>
            <td>$($p.DriverName)</td>
            <td>$($p.DriverType)</td>
            <td style="color:$statusColor;font-weight:bold">$($p.PrinterStatus)</td>
        </tr>
"@
    }

    $validationSection = ''
    if ($Data.Validation) {
        $v = $Data.Validation
        $scoreColor = if ($v.OverallScore -ge 80) { 'green' } elseif ($v.OverallScore -ge 50) { 'orange' } else { 'red' }
        $validationSection = @"
    <h2>Validation Dashboard</h2>
    <div style="text-align:center;margin:20px 0;padding:20px;background:linear-gradient(135deg,#667eea,#764ba2);color:#fff;border-radius:8px;">
        <div style="font-size:48px;font-weight:bold;">$($v.OverallScore)%</div>
        <div style="font-size:18px;">$($v.PassCount)/$($v.TotalChecks) Checks Passed</div>
        <div style="font-size:14px;margin-top:5px;color:$(if($v.AllPassed){'#a5d6a7'}else{'#ef9a9a'})">$(if($v.AllPassed){'ALL CHECKS PASSED'}else{'SOME CHECKS FAILED'})</div>
    </div>
    <table>
        <thead><tr><th>Component</th><th>Check</th><th>Status</th><th>Detail</th></tr></thead>
        <tbody>
"@
        foreach ($c in $v.Checks) {
            $statusStyle = if ($c.Status -eq 'PASS') { 'color:green;' } else { 'color:red;' }
            $validationSection += @"
        <tr>
            <td>$($c.Component)</td>
            <td>$($c.Check)</td>
            <td style="$statusStyle font-weight:bold">$($c.Status)</td>
            <td>$($c.Detail)</td>
        </tr>
"@
        }
        $validationSection += '</tbody></table>'
    }

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>PrinterToolkit Report - $($Data.ComputerName)</title>
<style>
    body { font-family: 'Segoe UI',Arial,sans-serif; margin: 20px; background: #f5f5f5; }
    .container { max-width: 1200px; margin: 0 auto; background: #fff; padding: 20px; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); }
    h1 { color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }
    h2 { color: #34495e; margin-top: 30px; }
    table { width: 100%; border-collapse: collapse; margin-top: 15px; }
    th, td { padding: 10px 12px; text-align: left; border-bottom: 1px solid #ddd; font-size: 13px; }
    th { background-color: #3498db; color: white; font-weight: 600; }
    tr:hover { background-color: #f0f8ff; }
    .summary-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin: 20px 0; }
    .stat-card { background: linear-gradient(135deg,#667eea,#764ba2); color: #fff; padding: 20px; border-radius: 8px; text-align: center; }
    .stat-card .number { font-size: 32px; font-weight: bold; }
    .stat-card .label { font-size: 14px; opacity: 0.9; margin-top: 5px; }
    .footer { margin-top: 30px; color: #7f8c8d; font-size: 12px; text-align: center; }
    .badge { display:inline-block; padding:2px 8px; border-radius:4px; font-size:11px; font-weight:600; }
    .badge-pass { background:#c8e6c9; color:#2e7d32; }
    .badge-fail { background:#ffcdd2; color:#c62828; }
</style>
</head>
<body>
<div class="container">
    <h1>$($Data.ReportTitle)</h1>
    <p>Computer: <strong>$($Data.ComputerName)</strong> | Generated: <strong>$($Data.GeneratedAt)</strong> | Toolkit: <strong>v$($Data.ToolkitVersion)</strong></p>
    <p>OS: $($Data.OS) | Model: $($Data.Manufacturer) $($Data.Model)</p>

    <div class="summary-grid">
        <div class="stat-card"><div class="number">$($Data.TotalPrinters)</div><div class="label">Printers</div></div>
        <div class="stat-card"><div class="number">$($Data.SharedPrinters)</div><div class="label">Shared</div></div>
        <div class="stat-card"><div class="number">$($Data.TotalDrivers)</div><div class="label">Drivers</div></div>
        <div class="stat-card"><div class="number">$($Data.Type4Drivers)</div><div class="label">Type 4</div></div>
    </div>

    <h2>Printer Inventory</h2>
    <table>
        <thead><tr><th>Name</th><th>Shared</th><th>Share Name</th><th>Port</th><th>Driver</th><th>Type</th><th>Status</th></tr></thead>
        <tbody>$printerRows</tbody>
    </table>

    $validationSection

    <div class="footer">Generated by PrinterToolkit v$($Data.ToolkitVersion) | Print Server Deployment Platform</div>
</div>
</body>
</html>
"@

    $html | Out-File -FilePath $filePath -Encoding UTF8
    return $filePath
}

function New-PrinterReportJson {
    param($Data, $OutputPath)

    $filePath = Join-Path -Path $OutputPath -ChildPath "PrinterReport_$($Data.ComputerName)_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    $Data | ConvertTo-Json -Depth 6 | Out-File -FilePath $filePath -Encoding UTF8
    return $filePath
}

function New-PrinterReportCsv {
    param($Data, $OutputPath)

    $filePath = Join-Path -Path $OutputPath -ChildPath "PrinterReport_$($Data.ComputerName)_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    $Data.PrinterDetails | Export-Csv -Path $filePath -NoTypeInformation -Encoding UTF8
    return $filePath
}

function New-PrinterReportMarkdown {
    param($Data, $OutputPath)

    $filePath = Join-Path -Path $OutputPath -ChildPath "PrinterReport_$($Data.ComputerName)_$(Get-Date -Format 'yyyyMMdd_HHmmss').md"

    $md = @"
# PrinterToolkit Print Server Report

**Computer:** $($Data.ComputerName)
**Generated:** $($Data.GeneratedAt)
**Toolkit:** v$($Data.ToolkitVersion)
**OS:** $($Data.OS)

## Summary

| Metric | Value |
|--------|-------|
| Total Printers | $($Data.TotalPrinters) |
| Shared Printers | $($Data.SharedPrinters) |
| Total Drivers | $($Data.TotalDrivers) |
| Type 4 Drivers | $($Data.Type4Drivers) |
| Type 3 Drivers | $($Data.Type3Drivers) |

## Printer Inventory

| Name | Shared | Share Name | Port | Driver | Type | Status |
|------|--------|------------|------|--------|------|--------|
"@

    foreach ($p in $Data.PrinterDetails) {
        $md += "| $($p.Name) | $($p.Shared) | $($p.ShareName) | $($p.PortName) | $($p.DriverName) | $($p.DriverType) | $($p.PrinterStatus) |`n"
    }

    if ($Data.Validation) {
        $v = $Data.Validation
        $md += @"

## Validation Dashboard

**Overall Score:** $($v.OverallScore)% ($($v.PassCount)/$($v.TotalChecks) passed)

| Component | Check | Status | Detail |
|-----------|-------|--------|--------|
"@
        foreach ($c in $v.Checks) {
            $md += "| $($c.Component) | $($c.Check) | $($c.Status) | $($c.Detail) |`n"
        }
    }

    $md | Out-File -FilePath $filePath -Encoding UTF8
    return $filePath
}

function Get-PrintComplianceReport {
    [CmdletBinding()]
    [OutputType([array])]
    param()
    try {
        $printers = @(Get-Printer -ErrorAction SilentlyContinue)
    } catch {
        $printers = @()
    }
    $drivers = @(Get-PrinterDriver -ErrorAction SilentlyContinue)

    $results = foreach ($p in $printers) {
        $driver = $drivers | Where-Object { $_.Name -eq $p.DriverName }
        $issues = @()

        if (-not $driver) {
            $issues += 'Driver not found'
        } elseif ($driver.MajorVersion -lt 4) {
            $issues += 'Legacy Type 3 driver (migrate to Type 4)'
        }

        if ($p.Shared -and -not $p.ShareName) {
            $issues += 'Shared but missing ShareName'
        }

        $port = Get-PrinterPort -Name $p.PortName -ErrorAction SilentlyContinue
        if (-not $port) {
            $issues += "Port '$($p.PortName)' not found"
        }

        [PSCustomObject]@{
            PrinterName = $p.Name
            Compliant   = ($issues.Count -eq 0)
            Issues      = if ($issues.Count -gt 0) { $issues -join '; ' } else { 'No issues' }
            DriverType  = if ($driver -and $driver.MajorVersion -ge 4) { 'Type 4' } else { 'Type 3 or Unknown' }
            Shared      = $p.Shared
        }
    }

    return ,@($results)
}

Export-ModuleMember -Function New-PrinterReport, Get-PrintComplianceReport
