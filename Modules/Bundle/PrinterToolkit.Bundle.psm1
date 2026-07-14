<#
.SYNOPSIS
    Diagnostic bundle generation for PrinterToolkit.

.DESCRIPTION
    Collects system information, printers, drivers, ports, registry,
    firewall, network, SMB, event logs, and compresses into a ZIP archive.

.NOTES
    Module: PrinterToolkit.Bundle
    Author: PrinterToolkit Contributors
#>

function New-DiagnosticBundle {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath
    )

    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    if (-not $OutputPath) {
        $OutputPath = Join-Path -Path ([Environment]::GetFolderPath('Desktop')) -ChildPath "PrinterToolkit_Diagnostics_$stamp"
    }

    $null = New-Item -ItemType Directory -Force -Path $OutputPath
    Write-Host 'Collecting diagnostic data...' -ForegroundColor Cyan

    # 1. System info
    Write-Host '  [1/12] System information...' -NoNewline
    try {
        Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue |
            Format-List * | Out-String -Width 400 |
            Out-File -FilePath (Join-Path -Path $OutputPath -ChildPath 'system_info.txt') -Encoding UTF8
        Write-Host ' OK' -ForegroundColor Green
    } catch { Write-Host ' FAILED' -ForegroundColor Red }

    # 2. Windows version
    Write-Host '  [2/12] Windows version...' -NoNewline
    try {
        Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue |
            Format-List * | Out-String -Width 400 |
            Out-File -FilePath (Join-Path -Path $OutputPath -ChildPath 'windows_version.txt') -Encoding UTF8
        Write-Host ' OK' -ForegroundColor Green
    } catch { Write-Host ' FAILED' -ForegroundColor Red }

    # 3. Printers
    Write-Host '  [3/12] Printers...' -NoNewline
    try {
        Get-Printer -ErrorAction SilentlyContinue |
            Format-List * | Out-String -Width 400 |
            Out-File -FilePath (Join-Path -Path $OutputPath -ChildPath 'printers.txt') -Encoding UTF8
        Write-Host ' OK' -ForegroundColor Green
    } catch { Write-Host ' FAILED' -ForegroundColor Red }

    # 4. Drivers
    Write-Host '  [4/12] Drivers...' -NoNewline
    try {
        Get-PrinterDriver -ErrorAction SilentlyContinue |
            Format-List * | Out-String -Width 400 |
            Out-File -FilePath (Join-Path -Path $OutputPath -ChildPath 'drivers.txt') -Encoding UTF8
        Write-Host ' OK' -ForegroundColor Green
    } catch { Write-Host ' FAILED' -ForegroundColor Red }

    # 5. Ports
    Write-Host '  [5/12] Ports...' -NoNewline
    try {
        Get-PrinterPort -ErrorAction SilentlyContinue |
            Format-List * | Out-String -Width 400 |
            Out-File -FilePath (Join-Path -Path $OutputPath -ChildPath 'ports.txt') -Encoding UTF8
        Write-Host ' OK' -ForegroundColor Green
    } catch { Write-Host ' FAILED' -ForegroundColor Red }

    # 6. Registry
    Write-Host '  [6/12] Registry...' -NoNewline
    try {
        $regKeys = @(
            'HKLM\SYSTEM\CurrentControlSet\Control\Print',
            'HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Printers'
        )
        foreach ($key in $regKeys) {
            $outFile = Join-Path -Path $OutputPath -ChildPath "reg_$(($key -replace '\\', '_') -replace ':', '').txt"
            try {
                Start-Process -FilePath 'reg.exe' -ArgumentList "query `"$key`" /s" -NoNewWindow -Wait -RedirectStandardOutput $outFile -ErrorAction SilentlyContinue
            } catch {}
        }
        Write-Host ' OK' -ForegroundColor Green
    } catch { Write-Host ' FAILED' -ForegroundColor Red }

    # 7. Firewall
    Write-Host '  [7/12] Firewall...' -NoNewline
    try {
        $rules = Get-NetFirewallRule -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayGroup -match 'Print|Discovery|File and Printer' -or $_.DisplayName -match 'IPP|mDNS|Print' } |
            Select-Object DisplayName, DisplayGroup, Enabled, Direction, Action, Profile
        ($rules | Format-Table -AutoSize | Out-String -Width 400) |
            Out-File -FilePath (Join-Path -Path $OutputPath -ChildPath 'firewall.txt') -Encoding UTF8
        Write-Host ' OK' -ForegroundColor Green
    } catch { Write-Host ' FAILED' -ForegroundColor Red }

    # 8. Network
    Write-Host '  [8/12] Network...' -NoNewline
    try {
        Get-NetConnectionProfile -ErrorAction SilentlyContinue |
            Format-List * | Out-String -Width 400 |
            Out-File -FilePath (Join-Path -Path $OutputPath -ChildPath 'network.txt') -Encoding UTF8
        Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object { $_.InterfaceAlias -notmatch 'Loopback|Teredo|isatap' } |
            Format-Table -AutoSize | Out-String -Width 400 |
            Out-File -FilePath (Join-Path -Path $OutputPath -ChildPath 'ipconfig.txt') -Encoding UTF8
        Write-Host ' OK' -ForegroundColor Green
    } catch { Write-Host ' FAILED' -ForegroundColor Red }

    # 9. SMB
    Write-Host '  [9/12] SMB...' -NoNewline
    try {
        Get-SmbServerConfiguration -ErrorAction SilentlyContinue |
            Format-List * | Out-String -Width 400 |
            Out-File -FilePath (Join-Path -Path $OutputPath -ChildPath 'smb.txt') -Encoding UTF8
        Get-SmbShare -ErrorAction SilentlyContinue |
            Format-Table -AutoSize | Out-String -Width 400 |
            Out-File -FilePath (Join-Path -Path $OutputPath -ChildPath 'smb_shares.txt') -Encoding UTF8
        Write-Host ' OK' -ForegroundColor Green
    } catch { Write-Host ' FAILED' -ForegroundColor Red }

    # 10. Services
    Write-Host '  [10/12] Services...' -NoNewline
    try {
        $svcNames = @('Spooler','LanmanServer','LanmanWorkstation','FDResPub','FDPhost','RpcSs','DcomLaunch')
        foreach ($s in $svcNames) {
            $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
            if ($svc) {
                $svc | Select-Object Name, DisplayName, Status, StartType |
                    Format-List | Out-String |
                    Out-File -FilePath (Join-Path -Path $OutputPath -ChildPath 'services.txt') -Append -Encoding UTF8
            }
        }
        Write-Host ' OK' -ForegroundColor Green
    } catch { Write-Host ' FAILED' -ForegroundColor Red }

    # 11. Event logs
    Write-Host '  [11/12] Event logs...' -NoNewline
    try {
        $logDir = Join-Path -Path $OutputPath -ChildPath 'eventlogs'
        $null = New-Item -ItemType Directory -Force -Path $logDir -ErrorAction SilentlyContinue
        wevtutil epl Microsoft-Windows-PrintService/Operational "$logDir\PrintService_Operational.evtx" 2>$null
        wevtutil epl System "$logDir\System.evtx" 2>$null
        wevtutil epl Application "$logDir\Application.evtx" 2>$null

        try {
            $events = Get-WinEvent -LogName 'Microsoft-Windows-PrintService/Operational' -MaxEvents 100 -ErrorAction SilentlyContinue
            if ($events) {
                $events | Format-Table TimeCreated, Id, LevelDisplayName, Message -AutoSize -Wrap |
                    Out-String -Width 400 |
                    Out-File -FilePath (Join-Path -Path $OutputPath -ChildPath 'spooler_events.txt') -Encoding UTF8
            }
        } catch {}
        Write-Host ' OK' -ForegroundColor Green
    } catch { Write-Host ' FAILED' -ForegroundColor Red }

    # 12. Manifest
    Write-Host '  [12/12] Creating manifest...' -NoNewline
    try {
        $allFiles = Get-ChildItem -Path $OutputPath -Recurse -File -ErrorAction SilentlyContinue
        $manifest = [PSCustomObject]@{
            GeneratedAt    = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            ComputerName   = $env:COMPUTERNAME
            ToolkitVersion = '5.0'
            FileCount      = $allFiles.Count
            TotalSizeKB    = [math]::Round(($allFiles | Measure-Object -Property Length -Sum).Sum / 1KB, 1)
        }
        $manifest | ConvertTo-Json -Compress |
            Out-File -FilePath (Join-Path -Path $OutputPath -ChildPath 'manifest.json') -Encoding UTF8
        Write-Host ' OK' -ForegroundColor Green
    } catch { Write-Host ' FAILED' -ForegroundColor Red }

    # ZIP
    Write-Host '  Creating ZIP archive...' -NoNewline
    $zipPath = "$OutputPath.zip"
    try {
        Compress-Archive -Path "$OutputPath\*" -DestinationPath $zipPath -Force -ErrorAction Stop
        Remove-Item -Path $OutputPath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host ' OK' -ForegroundColor Green
        Write-Host "Diagnostic bundle: $zipPath" -ForegroundColor Cyan
        return $zipPath
    } catch {
        Write-Host ' FALLBACK (folder kept)' -ForegroundColor Yellow
        Write-Host "Diagnostic folder: $OutputPath" -ForegroundColor Cyan
        return $OutputPath
    }
}

Export-ModuleMember -Function New-DiagnosticBundle
