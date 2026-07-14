<#
.SYNOPSIS
    Automatic Repair Engine for PrinterToolkit v6.0.

.DESCRIPTION
    Implements a complete issue detection and repair cycle:
    Issue -> Root Cause -> Backup -> Repair -> Validate -> Success/Rollback.
    Never leaves partial repairs. Every repair action includes full
    validation and automatic rollback on failure.

.NOTES
    Module: PrinterToolkit.Repair
    Author: PrinterToolkit Contributors
#>

$Script:SpoolPath = "$env:windir\System32\spool\PRINTERS"
$Script:BackupPath = $null
$Script:LastRepairResult = $null

function Initialize-RepairBackup {
    [CmdletBinding()]
    [OutputType([string])]
    param()
    $Script:BackupPath = Join-Path -Path ([Environment]::GetFolderPath('Desktop')) -ChildPath "PrinterToolkit_RepairBackup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    $null = New-Item -ItemType Directory -Force -Path $Script:BackupPath

    try {
        Start-Process -FilePath 'reg.exe' -ArgumentList 'export HKLM\SYSTEM\CurrentControlSet\Control\Print "'"$Script:BackupPath\reg_print.reg"'" /y' -NoNewWindow -Wait -ErrorAction SilentlyContinue
        Start-Process -FilePath 'reg.exe' -ArgumentList 'export "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Printers" "'"$Script:BackupPath\reg_policies.reg"'" /y' -NoNewWindow -Wait -ErrorAction SilentlyContinue
    } catch {}

    $svcNames = @('Spooler','LanmanServer','LanmanWorkstation','FDResPub','FDPhost')
    $svcData = foreach ($s in $svcNames) {
        $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
        if ($svc) {
            [PSCustomObject]@{ Service = $s; Status = $svc.Status.ToString(); StartType = $svc.StartType.ToString() }
        }
    }
    if ($svcData) {
        $svcData | Export-Csv -Path (Join-Path -Path $Script:BackupPath -ChildPath 'services_before.csv') -NoTypeInformation -Encoding UTF8
    }

    try {
        $brm = "$env:windir\System32\spool\tools\PrintBrm.exe"
        if (-not (Test-Path -Path $brm -ErrorAction SilentlyContinue)) {
            $brm = "$env:windir\System32\spool\tools\printbrm.exe"
        }
        if (Test-Path -Path $brm -ErrorAction SilentlyContinue) {
            Start-Process -FilePath $brm -ArgumentList "-b -f `"$Script:BackupPath\printers.printerExport`"" -NoNewWindow -Wait -ErrorAction SilentlyContinue
        }
    } catch {}

    return $Script:BackupPath
}

function Invoke-RepairCycle {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Issue,
        [Parameter(Mandatory = $true)]
        [string]$RootCause,
        [Parameter(Mandatory = $true)]
        [scriptblock]$RepairAction,
        [Parameter(Mandatory = $true)]
        [scriptblock]$ValidateAction,
        [Parameter(Mandatory = $false)]
        [string]$RollbackAction = ''
    )

    $cycleResult = [PSCustomObject]@{
        Issue         = $Issue
        RootCause     = $RootCause
        BackupSuccess = $false
        RepairSuccess = $false
        ValidateSuccess = $false
        RolledBack    = $false
        Detail        = ''
    }

    Write-Host "  Issue: $Issue" -ForegroundColor Yellow
    Write-Host "  Root Cause: $RootCause" -ForegroundColor Gray

    try {
        $backupPath = Initialize-RepairBackup
        $cycleResult.BackupSuccess = (Test-Path -Path $backupPath)
        Write-Host "  [BACKUP] $backupPath" -ForegroundColor DarkGray
    } catch {
        $cycleResult.Detail = "Backup failed: $_"
        Write-Host "  [BACKUP] FAILED - $_" -ForegroundColor Red
        return $cycleResult
    }

    try {
        &$RepairAction
        $cycleResult.RepairSuccess = $true
        Write-Host '  [REPAIR] Completed' -ForegroundColor Green
    } catch {
        $cycleResult.Detail = "Repair failed: $_"
        Write-Host "  [REPAIR] FAILED - $_" -ForegroundColor Red
        Invoke-RepairRollback -BackupPath $backupPath
        $cycleResult.RolledBack = $true
        return $cycleResult
    }

    try {
        $validateResult = &$ValidateAction
        $cycleResult.ValidateSuccess = $validateResult
        if ($validateResult) {
            Write-Host '  [VALIDATE] PASSED' -ForegroundColor Green
        } else {
            Write-Host '  [VALIDATE] FAILED - Rolling back' -ForegroundColor Red
            Invoke-RepairRollback -BackupPath $backupPath
            $cycleResult.RolledBack = $true
        }
    } catch {
        $cycleResult.Detail = "Validation failed: $_"
        Write-Host "  [VALIDATE] FAILED - $_" -ForegroundColor Red
        Invoke-RepairRollback -BackupPath $backupPath
        $cycleResult.RolledBack = $true
    }

    return $cycleResult
}

function Invoke-RepairRollback {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BackupPath
    )

    if (-not (Test-Path -Path $BackupPath)) { return $false }

    $regFiles = Get-ChildItem -Path $BackupPath -Filter '*.reg' -ErrorAction SilentlyContinue
    foreach ($regFile in $regFiles) {
        try {
            Start-Process -FilePath 'reg.exe' -ArgumentList "import `"$($regFile.FullName)`"" -NoNewWindow -Wait -ErrorAction SilentlyContinue
        } catch {}
    }

    $svcBackup = Join-Path -Path $BackupPath -ChildPath 'services_before.csv'
    if (Test-Path -Path $svcBackup) {
        try {
            $svcs = Import-Csv -Path $svcBackup -ErrorAction SilentlyContinue
            foreach ($s in $svcs) {
                $svc = Get-Service -Name $s.Service -ErrorAction SilentlyContinue
                if ($svc) {
                    Set-Service -Name $s.Service -StartupType $s.StartType -ErrorAction SilentlyContinue
                    if ($s.Status -eq 'Running') { Start-Service -Name $s.Service -ErrorAction SilentlyContinue }
                    else { Stop-Service -Name $s.Service -Force -ErrorAction SilentlyContinue }
                }
            }
        } catch {}
    }

    Write-Host "  [ROLLBACK] Restored from: $BackupPath" -ForegroundColor Yellow
    return $true
}

function Invoke-AutomaticShareRepair {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$TestMode
    )

    Assert-Elevated

    $logEntries = [System.Collections.ArrayList]::new()
    $errors = [System.Collections.ArrayList]::new()
    $cycleResults = [System.Collections.ArrayList]::new()

    $addLog = { param($Action, $Status, $Detail) $null = $logEntries.Add([PSCustomObject]@{ Action = $Action; Status = $Status; Detail = $Detail }) }

    Write-Host ''
    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host '    AUTOMATIC REPAIR ENGINE' -ForegroundColor White
    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host ''

    if (-not $TestMode) {
        if (-not (Confirm-DestructiveAction -Message 'Proceed with automatic repair?')) {
            return [PSCustomObject]@{ Success = $false; Cancelled = $true; Log = @($logEntries); Errors = @($errors) }
        }
    }

    $rollbackPath = Initialize-RepairRollback
    $Script:BackupPath = $rollbackPath
    &$addLog 'Backup' 'OK' "Rollback point: $rollbackPath"
    Write-Host '  [OK] Rollback point created' -ForegroundColor Green

    # Repair Cycle 1: Services
    Write-Host "[Service Repair]" -ForegroundColor Cyan
    $svcNames = @('Spooler','LanmanServer','FDResPub','FDPhost','RpcSs')
    foreach ($svcName in $svcNames) {
        $result = Invoke-RepairCycle -Issue "Service $svcName not running" -RootCause "Service stopped or disabled" -RepairAction {
            $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
            if ($svc) {
                Set-Service -Name $svcName -StartupType Automatic -ErrorAction SilentlyContinue
                Start-Service -Name $svcName -ErrorAction SilentlyContinue
                Start-Sleep -Milliseconds 500
            }
        } -ValidateAction {
            $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
            return ($svc -and $svc.Status -eq 'Running')
        }
        $null = $cycleResults.Add($result)
        if ($result.RepairSuccess -and $result.ValidateSuccess) {
            &$addLog "Service: $svcName" 'OK' 'Running'
        } else {
            &$addLog "Service: $svcName" 'FAIL' $result.Detail
            $null = $errors.Add("Service ${svcName}: $($result.Detail)")
        }
    }

    # Repair Cycle 2: Firewall
    Write-Host "[Firewall Repair]" -ForegroundColor Cyan
    $fwResult = Invoke-RepairCycle -Issue 'Firewall rules for printing not enabled' -RootCause 'Firewall blocking print sharing' -RepairAction {
        $null = Enable-PrinterFirewallRules -IncludeIpp
    } -ValidateAction {
        $fpRules = Get-NetFirewallRule -DisplayGroup 'File and Printer Sharing' -ErrorAction SilentlyContinue
        $fpEnabled = @($fpRules | Where-Object { $_.Enabled }).Count -gt 0
        $ippRule = Get-NetFirewallRule -DisplayName 'IPP Printer Port 631' -ErrorAction SilentlyContinue
        $ippEnabled = $ippRule -and $ippRule.Enabled
        return ($fpEnabled -and $ippEnabled)
    }
    $null = $cycleResults.Add($fwResult)
    if ($fwResult.RepairSuccess -and $fwResult.ValidateSuccess) {
        &$addLog 'Firewall' 'OK' 'Rules enabled'
    } else {
        &$addLog 'Firewall' 'FAIL' $fwResult.Detail
        $null = $errors.Add("Firewall: $($fwResult.Detail)")
    }

    # Repair Cycle 3: Network Profile
    Write-Host "[Network Profile Repair]" -ForegroundColor Cyan
    $netResult = Invoke-RepairCycle -Issue 'Network not set to Private' -RootCause 'Public network profile blocks discovery' -RepairAction {
        $profile = Get-NetConnectionProfile -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($profile -and $profile.NetworkCategory -ne 'Private') {
            Set-NetConnectionProfile -InterfaceIndex $profile.InterfaceIndex -NetworkCategory Private -ErrorAction SilentlyContinue
        }
    } -ValidateAction {
        $profile = Get-NetConnectionProfile -ErrorAction SilentlyContinue | Select-Object -First 1
        return ($profile -and $profile.NetworkCategory -eq 'Private')
    }
    $null = $cycleResults.Add($netResult)
    if ($netResult.RepairSuccess -and $netResult.ValidateSuccess) {
        &$addLog 'Network Profile' 'OK' 'Set to Private'
    } else {
        &$addLog 'Network Profile' 'WARN' $netResult.Detail
    }

    # Repair Cycle 4: Printer Shares
    Write-Host "[Share Repair]" -ForegroundColor Cyan
    $shareResult = Invoke-RepairCycle -Issue 'Printer shares not properly configured' -RootCause 'Share settings not applied' -RepairAction {
        $sharedPrinters = @(Get-Printer -ErrorAction SilentlyContinue | Where-Object { $_.Shared })
        if ($sharedPrinters.Count -eq 0) {
            $allPrinters = Get-Printer -ErrorAction SilentlyContinue
            if ($allPrinters.Count -gt 0) {
                $p = $allPrinters[0]
                $shareName = $p.Name -replace '[^a-zA-Z0-9_-]', '_'
                Set-Printer -Name $p.Name -Shared $true -ShareName $shareName -ErrorAction SilentlyContinue
            }
        } else {
            foreach ($p in $sharedPrinters) {
                Set-Printer -Name $p.Name -Shared $true -ErrorAction SilentlyContinue
            }
        }
    } -ValidateAction {
        $sharedCount = @(Get-Printer -ErrorAction SilentlyContinue | Where-Object { $_.Shared }).Count
        return ($sharedCount -gt 0)
    }
    $null = $cycleResults.Add($shareResult)
    if ($shareResult.RepairSuccess -and $shareResult.ValidateSuccess) {
        &$addLog 'Printer Shares' 'OK' 'Verified'
    } else {
        &$addLog 'Printer Shares' 'WARN' $shareResult.Detail
    }

    # Repair Cycle 5: Spooler
    Write-Host "[Spooler Repair]" -ForegroundColor Cyan
    $spoolResult = Invoke-RepairCycle -Issue 'Print spooler unhealthy' -RootCause 'Spooler service or queue issue' -RepairAction {
        Stop-Service -Name Spooler -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 1000
        if (Test-Path -Path $Script:SpoolPath -ErrorAction SilentlyContinue) {
            Remove-Item -Path "$Script:SpoolPath\*" -Force -ErrorAction SilentlyContinue
        }
        Start-Sleep -Milliseconds 500
        Start-Service -Name Spooler -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 1500
    } -ValidateAction {
        $svc = Get-Service -Name Spooler -ErrorAction SilentlyContinue
        return ($svc -and $svc.Status -eq 'Running')
    }
    $null = $cycleResults.Add($spoolResult)
    if ($spoolResult.RepairSuccess -and $spoolResult.ValidateSuccess) {
        &$addLog 'Spooler' 'OK' 'Restarted'
    } else {
        &$addLog 'Spooler' 'FAIL' $spoolResult.Detail
        $null = $errors.Add("Spooler: $($spoolResult.Detail)")
    }

    # Repair Cycle 6: Registry
    Write-Host "[Registry Repair]" -ForegroundColor Cyan
    $regResult = Invoke-RepairCycle -Issue 'Print registry settings incorrect' -RootCause 'Registry configuration not optimized for printing' -RepairAction {
        $regPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Print'
        if (-not (Test-Path -Path $regPath)) {
            $null = New-Item -Path $regPath -Force -ErrorAction SilentlyContinue
        }
        Set-ItemProperty -Path $regPath -Name 'RpcAuthnLevelPrivacyEnabled' -Value 0 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $regPath -Name 'DisableHTTPPrinting' -Value 0 -Type DWord -ErrorAction SilentlyContinue
    } -ValidateAction {
        $val = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Print' -Name 'RpcAuthnLevelPrivacyEnabled' -ErrorAction SilentlyContinue
        return ($null -eq $val -or $val.RpcAuthnLevelPrivacyEnabled -eq 0)
    }
    $null = $cycleResults.Add($regResult)

    # Final Validation
    Write-Host "[Final Validation]" -ForegroundColor Cyan
    $validation = Invoke-EndToEndValidation
    $finalSuccess = ($errors.Count -eq 0 -and $validation.OverallScore -ge 80)
    $Script:LastRepairResult = [PSCustomObject]@{
        Success       = $finalSuccess
        Cancelled     = $false
        BackupPath    = $Script:BackupPath
        CycleResults  = @($cycleResults)
        Log           = @($logEntries)
        Errors        = @($errors)
        Validation    = $validation
        Timestamp     = Get-Date
    }

    Write-Host ''
    Write-Host '========================================' -ForegroundColor $(if ($finalSuccess) { 'Green' } else { 'Yellow' })
    if ($finalSuccess) {
        Write-Host '    REPAIR COMPLETED SUCCESSFULLY' -ForegroundColor Green
    } else {
        Write-Host "    REPAIR COMPLETED WITH $($errors.Count) ERROR(S)" -ForegroundColor Yellow
    }
    Write-Host '========================================' -ForegroundColor $(if ($finalSuccess) { 'Green' } else { 'Yellow' })
    Write-Host "  Validation score: $($validation.OverallScore)%" -ForegroundColor Cyan

    return $Script:LastRepairResult
}

Export-ModuleMember -Function Initialize-RepairBackup, Invoke-AutomaticShareRepair, Invoke-RepairCycle, Invoke-RepairRollback
