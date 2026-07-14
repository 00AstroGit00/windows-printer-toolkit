<#
.SYNOPSIS
    Network validation and diagnostic engine for PrinterToolkit.

.DESCRIPTION
    Performs comprehensive network, service, firewall, and printer checks.
    Exports registry, firewall, and service snapshots.

.NOTES
    Module: PrinterToolkit.Diagnostics
    Author: PrinterToolkit Contributors
#>

$Script:RegPrintRoot = 'HKLM:\SYSTEM\CurrentControlSet\Control\Print'

function Get-NetworkValidation {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()
    $checks = [System.Collections.ArrayList]::new()

    $addCheck = {
        param($Name, $Category, $Pass, $Message, $Remediation, $Detail)
        $null = $checks.Add([PSCustomObject]@{
            Check       = $Name
            Category    = $Category
            Status      = $(if ($Pass) { 'PASS' } else { 'FAIL' })
            Message     = $Message
            Remediation = $Remediation
            Detail      = $Detail
        })
    }

    # --- Network ---
    try {
        $profile = Get-NetConnectionProfile -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($profile -and $profile.NetworkCategory -eq 'Private') {
            &$addCheck 'Network Profile' 'Network' $true "Profile is Private" '' "$($profile.NetworkCategory)"
        } else {
            $cat = if ($profile) { $profile.NetworkCategory } else { 'Unknown' }
            &$addCheck 'Network Profile' 'Network' $false "Profile is '$cat'" 'Set network to Private in Settings > Network & Internet' $cat
        }
    } catch {
        &$addCheck 'Network Profile' 'Network' $false 'Could not check network profile' 'Ensure network adapter is active' $_
    }

    # --- Services ---
    $serviceChecks = @{
        'FDResPub'      = 'Function Discovery Publication'
        'FDPhost'       = 'Function Discovery Provider'
        'DNSCache'      = 'DNS Client'
        'SSDPSRV'       = 'SSDP Discovery'
        'upnphost'      = 'UPnP Device Host'
        'LanmanServer'  = 'Server'
        'LanmanWorkstation' = 'Workstation'
        'Spooler'       = 'Print Spooler'
        'RpcSs'         = 'RPC'
        'DcomLaunch'    = 'DCOM Server'
    }

    foreach ($svcName in $serviceChecks.Keys) {
        try {
            $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
            if ($svc) {
                if ($svc.Status -eq 'Running') {
                    &$addCheck "$($serviceChecks[$svcName]) ($svcName)" 'Services' $true 'Running' '' "Status=$($svc.Status)"
                } else {
                    &$addCheck "$($serviceChecks[$svcName]) ($svcName)" 'Services' $false "Not running ($($svc.Status))" "Start-Service -Name $svcName" "Status=$($svc.Status)"
                }
            } else {
                &$addCheck "$($serviceChecks[$svcName]) ($svcName)" 'Services' $false 'Service not found' 'Check Windows features' ''
            }
        } catch {
            &$addCheck "$($serviceChecks[$svcName]) ($svcName)" 'Services' $false 'Check failed' 'Run services.msc' $_
        }
    }

    # --- Firewall ---
    $fwGroups = @('File and Printer Sharing', 'Network Discovery')
    foreach ($group in $fwGroups) {
        try {
            $rules = Get-NetFirewallRule -DisplayGroup $group -ErrorAction SilentlyContinue
            $enabled = @($rules | Where-Object { $_.Enabled }).Count -gt 0
            if ($enabled) {
                &$addCheck "Firewall: $group" 'Firewall' $true 'Enabled' '' "$(@($rules).Count) rules"
            } else {
                &$addCheck "Firewall: $group" 'Firewall' $false 'Disabled' "Enable the '$group' firewall rule group (e.g. Enable-NetFirewallRule -DisplayGroup '$group' or use Firewall Setup)" ''
            }
        } catch {
            &$addCheck "Firewall: $group" 'Firewall' $false 'Check failed' 'Run wf.msc' $_
        }
    }

    try {
        $ippRule = Get-NetFirewallRule -DisplayName 'IPP Printer Port 631' -ErrorAction SilentlyContinue
        if ($ippRule -and $ippRule.Enabled) {
            &$addCheck 'Firewall: IPP Port 631' 'Firewall' $true 'Enabled' '' 'TCP/631 inbound'
        } else {
            &$addCheck 'Firewall: IPP Port 631' 'Firewall' $false 'Not configured' 'Run Firewall Setup (Option F)' ''
        }
    } catch {
        &$addCheck 'Firewall: IPP Port 631' 'Firewall' $false 'Check failed' '' $_
    }

    # --- Printers ---
    $printers = @(Get-Printer -ErrorAction SilentlyContinue)
    $shared   = @($printers | Where-Object { $_.Shared })
    $count = $printers.Count
    $sharedCount = $shared.Count

    if ($count -gt 0) {
        &$addCheck 'Printers Installed' 'Printers' $true "$count printer(s), $sharedCount shared" '' ''
    } else {
        &$addCheck 'Printers Installed' 'Printers' $false 'No printers installed' 'Connect a printer and install drivers' ''
    }

    if ($sharedCount -gt 0) {
        $names = ($shared | ForEach-Object { "$($_.Name) ($($_.ShareName))" }) -join '; '
        &$addCheck 'Printer Sharing' 'Printers' $true "$sharedCount printer(s) shared" '' $names
    } else {
        &$addCheck 'Printer Sharing' 'Printers' $false 'No shared printers' 'Use Share a Local Printer (Option S)' ''
    }

    # --- Queue ---
    $spoolPath = "$env:windir\System32\spool\PRINTERS"
    if (Test-Path -Path $spoolPath -ErrorAction SilentlyContinue) {
        $queueCount = @(Get-ChildItem -Path $spoolPath -File -ErrorAction SilentlyContinue).Count
        if ($queueCount -eq 0) {
            &$addCheck 'Print Queue' 'Printers' $true 'Empty' '' '0 jobs pending'
        } else {
            &$addCheck 'Print Queue' 'Printers' $false "$queueCount job(s) pending" 'Clear queue with Clear Print Queue (Option 2)' ''
        }
    } else {
        &$addCheck 'Print Queue' 'Printers' $false 'Folder not found' 'Check spooler installation' $spoolPath
    }

    # --- Registry ---
    try {
        $regVal = Get-ItemProperty -Path $Script:RegPrintRoot -Name 'RpcAuthnLevelPrivacyEnabled' -ErrorAction SilentlyContinue
        if ($regVal) {
            &$addCheck 'Registry: RpcAuthnLevelPrivacyEnabled' 'Registry' $true "Set to $($regVal.RpcAuthnLevelPrivacyEnabled)" '' "Value=$($regVal.RpcAuthnLevelPrivacyEnabled)"
        } else {
            &$addCheck 'Registry: RpcAuthnLevelPrivacyEnabled' 'Registry' $true 'Not set (default)' '' ''
        }
    } catch {
        &$addCheck 'Registry: RpcAuthnLevelPrivacyEnabled' 'Registry' $true 'Not set (default)' '' ''
    }

    $passCount = @($checks | Where-Object { $_.Status -eq 'PASS' }).Count
    $failCount = @($checks | Where-Object { $_.Status -eq 'FAIL' }).Count
    $total = $checks.Count
    $score = if ($total -gt 0) { [math]::Round(($passCount / $total) * 100, 1) } else { 100 }

    [PSCustomObject]@{
        OverallScore = $score
        PassCount    = $passCount
        FailCount    = $failCount
        TotalChecks  = $total
        Checks       = @($checks)
        Timestamp    = Get-Date
    }
}

function Show-NetworkValidationReport {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $false)]
        [PSCustomObject]$Validation
    )

    if (-not $Validation) {
        $Validation = Get-NetworkValidation
    }

    $scoreColor = if ($Validation.OverallScore -ge 80) { 'Green' } elseif ($Validation.OverallScore -ge 50) { 'Yellow' } else { 'Red' }

    Write-Host ''
    Write-Host '  NETWORK VALIDATION REPORT' -ForegroundColor Cyan
    Write-Host "  Score: $($Validation.OverallScore)% ($($Validation.PassCount)/$($Validation.TotalChecks) passed)" -ForegroundColor $scoreColor
    Write-Host ''

    $categories = $Validation.Checks | Select-Object -ExpandProperty Category -Unique
    foreach ($cat in $categories) {
        $catChecks = $Validation.Checks | Where-Object { $_.Category -eq $cat }
        $catPass = @($catChecks | Where-Object { $_.Status -eq 'PASS' }).Count
        $catTotal = $catChecks.Count
        Write-Host "  [$cat] $catPass/$catTotal" -ForegroundColor Yellow

        foreach ($c in $catChecks) {
            $icon = if ($c.Status -eq 'PASS') { '[PASS]' } else { '[FAIL]' }
            $color = if ($c.Status -eq 'PASS') { 'Green' } else { 'Red' }
            Write-Host "    $icon $($c.Check)" -ForegroundColor $color
            if ($c.Status -eq 'FAIL' -and $c.Remediation) {
                Write-Host "          Fix: $($c.Remediation)" -ForegroundColor DarkYellow
            }
        }
        Write-Host ''
    }
}

function Export-RegistrySnapshot {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath
    )

    if (-not $OutputPath) {
        $OutputPath = Join-Path -Path ([Environment]::GetFolderPath('Desktop')) -ChildPath "PrinterToolkit_Registry_$(Get-Date -Format 'yyyyMMdd_HHmmss').reg"
    }

    $keys = @(
        'HKLM\SYSTEM\CurrentControlSet\Control\Print',
        'HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Printers'
    )

    $tempDir = Join-Path -Path ([IO.Path]::GetTempPath()) -ChildPath "PTReg_$([System.IO.Path]::GetRandomFileName())"
    $null = New-Item -ItemType Directory -Force -Path $tempDir -ErrorAction SilentlyContinue

    foreach ($key in $keys) {
        $partFile = Join-Path -Path $tempDir -ChildPath "$(($key -replace '\\', '_') -replace ':', '').reg"
        try {
            Start-Process -FilePath 'reg.exe' -ArgumentList "export `"$key`" `"$partFile`" /y" -NoNewWindow -Wait -ErrorAction SilentlyContinue
        } catch {}
    }

    # Merge all part files into one
    $merged = @()
    $partFiles = Get-ChildItem -Path $tempDir -Filter '*.reg' -ErrorAction SilentlyContinue
    foreach ($pf in $partFiles) {
        try {
            $content = Get-Content -Path $pf.FullName -ErrorAction SilentlyContinue
            $merged += $content
        } catch {}
    }

    if ($merged.Count -gt 0) {
        $merged -join "`r`n" | Out-File -FilePath $OutputPath -Encoding Unicode
    }

    # Cleanup
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue

    return $OutputPath
}

function Export-FirewallSnapshot {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath
    )

    if (-not $OutputPath) {
        $OutputPath = Join-Path -Path ([Environment]::GetFolderPath('Desktop')) -ChildPath "PrinterToolkit_Firewall_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    }

    try {
        $rules = Get-NetFirewallRule -ErrorAction SilentlyContinue |
            Where-Object {
                $_.DisplayGroup -match 'Print|Discovery|File and Printer' -or
                $_.DisplayName -match 'IPP|mDNS|Print'
            } |
            Select-Object DisplayName, DisplayGroup, Enabled, Direction, Action, Profile

        ($rules | Format-Table -AutoSize | Out-String -Width 400) | Out-File -FilePath $OutputPath -Encoding UTF8
    } catch {}

    return $OutputPath
}

function Export-ServiceSnapshot {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath
    )

    if (-not $OutputPath) {
        $OutputPath = Join-Path -Path ([Environment]::GetFolderPath('Desktop')) -ChildPath "PrinterToolkit_Services_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    }

    $serviceNames = @('Spooler', 'LanmanServer', 'LanmanWorkstation', 'FDResPub', 'FDPhost', 'RpcSs', 'DcomLaunch', 'DNSCache', 'SSDPSRV', 'upnphost')
    $data = foreach ($s in $serviceNames) {
        $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
        if ($svc) {
            [PSCustomObject]@{
                Service   = $s
                Display   = $svc.DisplayName
                Status    = $svc.Status.ToString()
                StartType = $svc.StartType.ToString()
            }
        }
    }

    if ($data) {
        $data | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
    }

    return $OutputPath
}

Export-ModuleMember -Function Get-NetworkValidation, Show-NetworkValidationReport, Export-RegistrySnapshot, Export-FirewallSnapshot, Export-ServiceSnapshot
