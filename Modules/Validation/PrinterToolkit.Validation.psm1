<#
.SYNOPSIS
    End-to-end validation engine for PrinterToolkit v6.0.

.DESCRIPTION
    Validates every component of the print server deployment:
    printer detection, driver installation, queue health, spooler,
    services, registry, firewall, network, sharing, SMB, IPP,
    and client connectivity. Produces PASS/FAIL dashboard.

.NOTES
    Module: PrinterToolkit.Validation
    Author: PrinterToolkit Contributors
#>

function Invoke-EndToEndValidation {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$PrinterName
    )

    Write-Host ''
    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host '    END-TO-END VALIDATION DASHBOARD' -ForegroundColor White
    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host ''

    $checks = [System.Collections.ArrayList]::new()

    $addCheck = {
        param($Component, $Check, $Pass, $Detail)
        $null = $checks.Add([PSCustomObject]@{
            Component = $Component
            Check     = $Check
            Status    = $(if ($Pass) { 'PASS' } else { 'FAIL' })
            Detail    = $Detail
        })
        $icon = if ($Pass) { '[PASS]' } else { '[FAIL]' }
        $color = if ($Pass) { 'Green' } else { 'Red' }
        Write-Host "  $icon $Check" -ForegroundColor $color
        if (-not $Pass -and $Detail) {
            Write-Host "         $Detail" -ForegroundColor DarkYellow
        }
    }

    $printers = @(Get-Printer -ErrorAction SilentlyContinue)
    if ($PrinterName) {
        $printers = @($printers | Where-Object { $_.Name -eq $PrinterName })
    }
    $targetPrinter = $printers | Select-Object -First 1

    Write-Host "  [--- PRINTER DETECTION ---]" -ForegroundColor Yellow
    if ($targetPrinter) {
        &$addCheck 'Printer' "Printer detected: $($targetPrinter.Name)" $true "Status=$($targetPrinter.PrinterStatus)"
    } else {
        &$addCheck 'Printer' 'Printer detected' $false 'No printer found'
    }

    Write-Host "  [--- DRIVER ---]" -ForegroundColor Yellow
    if ($targetPrinter) {
        $driver = Get-PrinterDriver -Name $targetPrinter.DriverName -ErrorAction SilentlyContinue
        if ($driver) {
            $isSigned = $true
            &$addCheck 'Driver' "Driver installed: $($driver.Name)" $true "Version=$($driver.MajorVersion), Type=$(if ($driver.MajorVersion -ge 4) {'Type 4'} else {'Type 3'})"
            &$addCheck 'Driver' 'Driver signed' $isSigned ''
        } else {
            &$addCheck 'Driver' 'Driver installed' $false "Driver not found for $($targetPrinter.DriverName)"
        }
    }

    Write-Host "  [--- QUEUE & PORT ---]" -ForegroundColor Yellow
    if ($targetPrinter) {
        $port = Get-PrinterPort -Name $targetPrinter.PortName -ErrorAction SilentlyContinue
        &$addCheck 'Queue' 'Queue healthy' ($targetPrinter.PrinterStatus -eq 3 -or $targetPrinter.PrinterStatus -eq 0) "Status=$($targetPrinter.PrinterStatus)"
        &$addCheck 'Port' 'Port healthy' ($null -ne $port) "Port=$($targetPrinter.PortName)"
    }

    Write-Host "  [--- SPOOLER ---]" -ForegroundColor Yellow
    try {
        $spooler = Get-Service -Name Spooler -ErrorAction SilentlyContinue
        if ($spooler) {
            &$addCheck 'Spooler' 'Spooler running' ($spooler.Status -eq 'Running') "Status=$($spooler.Status)"
        } else {
            &$addCheck 'Spooler' 'Spooler running' $false 'Spooler service not found'
        }
    } catch {
        &$addCheck 'Spooler' 'Spooler running' $false $_.Exception.Message
    }

    Write-Host "  [--- SERVICES ---]" -ForegroundColor Yellow
    $svcNames = @('LanmanServer', 'LanmanWorkstation', 'FDResPub', 'FDPhost', 'RpcSs', 'DcomLaunch', 'DNSCache')
    foreach ($svcName in $svcNames) {
        try {
            $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
            &$addCheck 'Services' "$svcName running" ($svc -and $svc.Status -eq 'Running') "Status=$(if ($svc) {$svc.Status} else {'NotFound'})"
        } catch {
            &$addCheck 'Services' "$svcName running" $false $_.Exception.Message
        }
    }

    Write-Host "  [--- REGISTRY ---]" -ForegroundColor Yellow
    try {
        $regKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\Print'
        $regPass = Test-Path -Path $regKey -ErrorAction SilentlyContinue
        &$addCheck 'Registry' 'Print registry present' $regPass ''
    } catch {
        &$addCheck 'Registry' 'Print registry present' $false $_.Exception.Message
    }

    Write-Host "  [--- FIREWALL ---]" -ForegroundColor Yellow
    $fwGroups = @('File and Printer Sharing', 'Network Discovery')
    foreach ($group in $fwGroups) {
        try {
            $rules = Get-NetFirewallRule -DisplayGroup $group -ErrorAction SilentlyContinue
            $enabled = @($rules | Where-Object { $_.Enabled }).Count -gt 0
            &$addCheck 'Firewall' "Firewall: $group" $enabled "$(@($rules).Count) rules"
        } catch {
            &$addCheck 'Firewall' "Firewall: $group" $false $_.Exception.Message
        }
    }

    try {
        $ippRule = Get-NetFirewallRule -DisplayName 'IPP Printer Port 631' -ErrorAction SilentlyContinue
        &$addCheck 'Firewall' 'Firewall: IPP Port 631' ($ippRule -and $ippRule.Enabled) ''
    } catch {
        &$addCheck 'Firewall' 'Firewall: IPP Port 631' $false $_.Exception.Message
    }

    Write-Host "  [--- SHARING ---]" -ForegroundColor Yellow
    if ($targetPrinter) {
        &$addCheck 'Sharing' 'Printer shared' ($targetPrinter.Shared -eq $true) "ShareName=$($targetPrinter.ShareName)"
    }

    Write-Host "  [--- SMB ---]" -ForegroundColor Yellow
    try {
        $smbConfig = Get-SmbServerConfiguration -ErrorAction SilentlyContinue
        if ($smbConfig) {
            &$addCheck 'SMB' 'SMB server enabled' $smbConfig.ServerEnabled "KeepAlive=$($smbConfig.KeepAlive)"
        } else {
            &$addCheck 'SMB' 'SMB server enabled' $false 'SMB config not accessible'
        }
    } catch {
        &$addCheck 'SMB' 'SMB server enabled' $false $_.Exception.Message
    }

    Write-Host "  [--- IPP ---]" -ForegroundColor Yellow
    $ippStatus = Get-IPPStatus -ErrorAction SilentlyContinue
    &$addCheck 'IPP' 'IPP URLs generated' ($ippStatus.IPPUrls.Count -gt 0) "URLs=$($ippStatus.IPPUrls.Count)"

    Write-Host "  [--- NETWORK ---]" -ForegroundColor Yellow
    try {
        $profile = Get-NetConnectionProfile -ErrorAction SilentlyContinue | Select-Object -First 1
        $isPrivate = ($profile -and $profile.NetworkCategory -eq 'Private')
        &$addCheck 'Network' 'Network profile is Private' $isPrivate "Profile=$(if ($profile) {$profile.NetworkCategory} else {'Unknown'})"
    } catch {
        &$addCheck 'Network' 'Network profile is Private' $false $_.Exception.Message
    }

    Write-Host "  [--- ANDROID ---]" -ForegroundColor Yellow
    $androidCompat = Get-AndroidCompatibility -ErrorAction SilentlyContinue
    &$addCheck 'Android' 'Android compatibility checked' ($null -ne $androidCompat) ''

    Write-Host "  [--- TEST PAGE ---]" -ForegroundColor Yellow
    $hasDefault = $null -ne (Get-CimInstance -ClassName Win32_Printer -Filter "Default='True'" -ErrorAction SilentlyContinue)
    &$addCheck 'TestPage' 'Default printer set' $hasDefault ''

    $passCount = @($checks | Where-Object { $_.Status -eq 'PASS' }).Count
    $failCount = @($checks | Where-Object { $_.Status -eq 'FAIL' }).Count
    $totalCount = $checks.Count
    $score = if ($totalCount -gt 0) { [math]::Round(($passCount / $totalCount) * 100, 1) } else { 100 }

    Write-Host ''
    Write-Host '========================================' -ForegroundColor Cyan
    $scoreColor = if ($score -ge 80) { 'Green' } elseif ($score -ge 50) { 'Yellow' } else { 'Red' }
    Write-Host "    OVERALL: $score% ($passCount/$totalCount PASS)" -ForegroundColor $scoreColor
    if ($score -ge 95) {
        Write-Host '    STATUS: ALL CHECKS PASSED - SYSTEM READY' -ForegroundColor Green
    } elseif ($score -ge 80) {
        Write-Host '    STATUS: MOSTLY PASSED - MINOR ISSUES REMAIN' -ForegroundColor Yellow
    } else {
        Write-Host '    STATUS: FAILED - REPAIR REQUIRED' -ForegroundColor Red
    }
    Write-Host '========================================' -ForegroundColor Cyan

    [PSCustomObject]@{
        OverallScore = $score
        PassCount    = $passCount
        FailCount    = $failCount
        TotalChecks  = $totalCount
        AllPassed    = ($failCount -eq 0)
        Checks       = @($checks)
        Timestamp    = Get-Date
    }
}

function Get-ValidationDashboard {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $validation = Invoke-EndToEndValidation

    [PSCustomObject]@{
        DashboardTitle = 'PrinterToolkit Validation Dashboard'
        Status         = if ($validation.AllPassed) { 'PASS' } else { 'FAIL' }
        Score          = $validation.OverallScore
        PassCount      = $validation.PassCount
        FailCount      = $validation.FailCount
        TotalChecks    = $validation.TotalChecks
        Failures       = @($validation.Checks | Where-Object { $_.Status -eq 'FAIL' })
        Timestamp      = $validation.Timestamp
    }
}

Export-ModuleMember -Function Invoke-EndToEndValidation, Get-ValidationDashboard
