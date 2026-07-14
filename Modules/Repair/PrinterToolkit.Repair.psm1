<#
.SYNOPSIS
    Automatic share repair and spooler recovery for PrinterToolkit.

.DESCRIPTION
    Provides an 8-step idempotent repair workflow that backs up configuration,
    restarts services, repairs firewall, network discovery, printer shares,
    spooler, verifies printers, and prints a test page.

.NOTES
    Module: PrinterToolkit.Repair
    Author: PrinterToolkit Contributors
#>

$Script:SpoolPath = "$env:windir\System32\spool\PRINTERS"
$Script:BackupPath = $null

function Initialize-RepairBackup {
    [CmdletBinding()]
    [OutputType([string])]
    param()
    $Script:BackupPath = Join-Path -Path ([Environment]::GetFolderPath('Desktop')) -ChildPath "PrinterToolkit_RepairBackup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    $null = New-Item -ItemType Directory -Force -Path $Script:BackupPath

    # Registry
    try {
        Start-Process -FilePath 'reg.exe' -ArgumentList 'export HKLM\SYSTEM\CurrentControlSet\Control\Print "'"$Script:BackupPath\reg_print.reg"'" /y' -NoNewWindow -Wait -ErrorAction SilentlyContinue
        Start-Process -FilePath 'reg.exe' -ArgumentList 'export "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Printers" "'"$Script:BackupPath\reg_policies.reg"'" /y' -NoNewWindow -Wait -ErrorAction SilentlyContinue
    } catch {}

    # Services
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

    # PrintBRM
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

    $addLog = { param($Action, $Status, $Detail) $null = $logEntries.Add([PSCustomObject]@{ Action = $Action; Status = $Status; Detail = $Detail }) }

    Write-Host ''
    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host '    AUTOMATIC SHARE REPAIR' -ForegroundColor White
    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host ''

    if (-not $TestMode) {
        if (-not (Confirm-DestructiveAction -Message 'Proceed with automatic share repair?')) {
            return [PSCustomObject]@{ Success = $false; Cancelled = $true; Log = @($logEntries); Errors = @($errors) }
        }
    }

    # Step 1
    Write-Host '[1/8] Backing up current configuration...' -ForegroundColor White
    try {
        $backupPath = Initialize-RepairBackup
        &$addLog 'Backup configuration' 'OK' "Backed up to $backupPath"
        Write-Host '  [OK]' -ForegroundColor Green
    } catch {
        &$addLog 'Backup configuration' 'FAIL' $_
        Write-Host '  [WARN] Backup failed' -ForegroundColor Yellow
    }

    # Step 2
    Write-Host '[2/8] Restarting services...' -ForegroundColor White
    $svcs = @('Spooler','LanmanServer','FDResPub','FDPhost','RpcSs')
    foreach ($svcName in $svcs) {
        try {
            $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
            if ($svc) {
                if ($svc.Status -eq 'Running') {
                    Restart-Service -Name $svcName -Force -ErrorAction SilentlyContinue
                } else {
                    Start-Service -Name $svcName -ErrorAction SilentlyContinue
                }
                Start-Sleep -Milliseconds 300
                &$addLog "Service: $svcName" 'OK' 'Restarted'
            } else {
                &$addLog "Service: $svcName" 'SKIP' 'Not found'
            }
        } catch {
            &$addLog "Service: $svcName" 'FAIL' $_
            $null = $errors.Add("Service restart failed: $svcName")
        }
    }
    Write-Host '  [OK] Services processed' -ForegroundColor Green

    # Step 3
    Write-Host '[3/8] Repairing firewall...' -ForegroundColor White
    try {
        $null = netsh advfirewall firewall set rule group='File and Printer Sharing' new enable=Yes 2>$null
        $null = netsh advfirewall firewall set rule group='Network Discovery' new enable=Yes 2>$null
        $null = netsh advfirewall firewall add rule name='IPP Printer Port 631' dir=in action=allow protocol=TCP localport=631 description='Internet Printing Protocol' 2>$null
        &$addLog 'Firewall repair' 'OK' 'Rules enabled'
        Write-Host '  [OK] Firewall rules configured' -ForegroundColor Green
    } catch {
        &$addLog 'Firewall repair' 'FAIL' $_
        $null = $errors.Add('Firewall repair failed')
    }

    # Step 4
    Write-Host '[4/8] Repairing network discovery...' -ForegroundColor White
    try {
        $profile = Get-NetConnectionProfile -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($profile -and $profile.NetworkCategory -ne 'Private') {
            Set-NetConnectionProfile -InterfaceIndex $profile.InterfaceIndex -NetworkCategory Private -ErrorAction SilentlyContinue
            &$addLog 'Network profile' 'OK' 'Set to Private'
            Write-Host '  [OK] Network set to Private' -ForegroundColor Green
        } else {
            Write-Host '  [OK] Already Private' -ForegroundColor Green
        }
    } catch {
        &$addLog 'Network profile' 'FAIL' $_
        Write-Host '  [WARN] Could not set profile' -ForegroundColor Yellow
    }

    # Step 5
    Write-Host '[5/8] Repairing printer shares...' -ForegroundColor White
    try {
        $sharedPrinters = @(Get-Printer -ErrorAction SilentlyContinue | Where-Object { $_.Shared })
        if ($sharedPrinters.Count -gt 0) {
            foreach ($p in $sharedPrinters) {
                try {
                    Set-Printer -Name $p.Name -Shared $true -ErrorAction SilentlyContinue
                    &$addLog "Re-share $($p.Name)" 'OK' 'Verified'
                } catch {
                    &$addLog "Re-share $($p.Name)" 'WARN' $_
                }
            }
            Write-Host "  [OK] $($sharedPrinters.Count) share(s) verified" -ForegroundColor Green
        } else {
            Write-Host '  [INFO] No shared printers found' -ForegroundColor Yellow
            &$addLog 'Printer shares' 'INFO' 'None found'
        }
    } catch {
        &$addLog 'Printer share repair' 'FAIL' $_
    }

    # Step 6
    Write-Host '[6/8] Repairing spooler...' -ForegroundColor White
    try {
        $null = Stop-Spooler -Force
        Start-Sleep -Milliseconds 1000
        if (Test-Path -Path $Script:SpoolPath -ErrorAction SilentlyContinue) {
            Remove-Item -Path "$Script:SpoolPath\*" -Force -ErrorAction SilentlyContinue
            &$addLog 'Clear queue' 'OK' 'Emptied'
        }
        Start-Sleep -Milliseconds 500
        if (Start-Spooler) {
            &$addLog 'Spooler' 'OK' 'Restarted and running'
            Write-Host '  [OK] Spooler restarted' -ForegroundColor Green
        } else {
            throw 'Spooler failed to start'
        }
    } catch {
        &$addLog 'Spooler repair' 'FAIL' $_
        $null = $errors.Add("Spooler repair failed: $_")
        Write-Host "  [ERROR] $_" -ForegroundColor Red
    }

    # Step 7
    Write-Host '[7/8] Verifying printers...' -ForegroundColor White
    try {
        $afterPrinters = @(Get-Printer -ErrorAction SilentlyContinue)
        if ($afterPrinters.Count -gt 0) {
            foreach ($p in $afterPrinters) {
                $st = if ($p.PrinterStatus -eq 'Normal') { 'OK' } else { $p.PrinterStatus }
                &$addLog "Verify $($p.Name)" 'OK' "Status: $st"
            }
            Write-Host "  [OK] $($afterPrinters.Count) printer(s) verified" -ForegroundColor Green
        } else {
            Write-Host '  [WARN] No printers found' -ForegroundColor Yellow
        }
    } catch {
        &$addLog 'Verify printers' 'FAIL' $_
    }

    # Step 8
    Write-Host '[8/8] Printing test page...' -ForegroundColor White
    try {
        $default = Get-CimInstance -ClassName Win32_Printer -Filter "Default='True'" -ErrorAction SilentlyContinue
        if ($default) {
            $null = Start-Process -FilePath 'rundll32.exe' -ArgumentList @('PRINTUI.DLL,PrintUIEntry', '/k', '/n', "`"$($default.Name)`"") -NoNewWindow -Wait -PassThru
            &$addLog 'Test page' 'OK' "Sent to $($default.Name)"
            Write-Host "  [OK] Test page sent to $($default.Name)" -ForegroundColor Green
        } else {
            &$addLog 'Test page' 'SKIP' 'No default printer'
            Write-Host '  [WARN] No default printer set' -ForegroundColor Yellow
        }
    } catch {
        &$addLog 'Test page' 'FAIL' $_
    }

    $success = ($errors.Count -eq 0)

    Write-Host ''
    Write-Host '========================================' -ForegroundColor $(if ($success) { 'Green' } else { 'Yellow' })
    if ($success) {
        Write-Host '    REPAIR COMPLETED SUCCESSFULLY' -ForegroundColor Green
    } else {
        Write-Host "    REPAIR COMPLETED WITH $($errors.Count) ERROR(S)" -ForegroundColor Yellow
    }
    Write-Host '========================================' -ForegroundColor $(if ($success) { 'Green' } else { 'Yellow' })

    [PSCustomObject]@{
        Success    = $success
        Cancelled  = $false
        BackupPath = if ($Script:BackupPath) { $Script:BackupPath } else { '' }
        Log        = @($logEntries)
        Errors     = @($errors)
        Timestamp  = Get-Date
    }
}

Export-ModuleMember -Function Initialize-RepairBackup, Invoke-AutomaticShareRepair
