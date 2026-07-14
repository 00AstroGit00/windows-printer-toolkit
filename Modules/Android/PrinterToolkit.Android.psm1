<#
.SYNOPSIS
    Android device printing compatibility for PrinterToolkit.

.DESCRIPTION
    Detects Windows host capabilities for Android printing via Mopria/IPP,
    generates setup instructions, and recommends best printing method.

.NOTES
    Module: PrinterToolkit.Android
    Author: PrinterToolkit Contributors
#>

function Get-AndroidCompatibility {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()
    $hostname = $env:COMPUTERNAME

    $ipv4 = @()
    try {
        $ipv4 = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object { $_.InterfaceAlias -notmatch 'Loopback|Teredo|isatap' } |
            Select-Object -ExpandProperty IPAddress
    } catch {}

    $sharedPrinters = @(Get-Printer -ErrorAction SilentlyContinue | Where-Object { $_.Shared })
    $allPrinters = @(Get-Printer -ErrorAction SilentlyContinue)
    $defaultPrinter = $allPrinters | Select-Object -First 1

    $printMethods = @(
        [PSCustomObject]@{ Method='Mopria Print Service';  Supported=$true;  Priority=1; Protocol='IPP/mDNS'; Note='Built into Android 8+. Auto-discovers printers.' }
        [PSCustomObject]@{ Method='Mopria (Manual)';        Supported=$true;  Priority=2; Protocol='IPP';      Note='Add by IP if auto-discovery fails.' }
        [PSCustomObject]@{ Method='PrintHand / PrinterShare'; Supported=$true;  Priority=3; Protocol='SMB/IPP';  Note='Third-party apps for Windows shares.' }
        [PSCustomObject]@{ Method='Manufacturer App';       Supported=$false; Priority=4; Protocol='Vendor';   Note='Only for network-capable printers.' }
    )

    $printers = foreach ($p in $sharedPrinters) {
        $shareName = if ($p.ShareName) { $p.ShareName } else { $p.Name -replace '[^a-zA-Z0-9_-]', '_' }
        $isDefault = ($defaultPrinter -and $defaultPrinter.Name -eq $p.Name)
        $isOnline  = ($p.PrinterStatus -eq 'Normal')

        [PSCustomObject]@{
            PrinterName      = $p.Name
            ShareName        = $shareName
            DriverName       = $p.DriverName
            PrinterStatus    = $p.PrinterStatus.ToString()
            IsDefault        = $isDefault
            IsOnline         = $isOnline
            IPPUrl           = "ipp://$hostname/printers/$shareName"
            SMBPath          = "\\$hostname\$shareName"
            HTTPUrl          = "http://$hostname`:631/printers/$shareName"
            IPv4Addresses    = @($ipv4)
            Hostname         = $hostname
            RecommendedMethod = 'Mopria Print Service'
            RecommendedUrl   = "ipp://$hostname/printers/$shareName"
        }
    }

    if ($printers.Count -eq 0) {
        $printers = @([PSCustomObject]@{
            PrinterName = '(none shared)'; ShareName = ''; DriverName = ''
            PrinterStatus = 'N/A'; IsDefault = $false; IsOnline = $false
            IPPUrl = ''; SMBPath = ''; HTTPUrl = ''
            IPv4Addresses = @($ipv4); Hostname = $hostname
            RecommendedMethod = 'Share a printer first (Option S)'
            RecommendedUrl = ''
        })
    }

    $firewallOk = $false
    try {
        $rules = Get-NetFirewallRule -DisplayName 'IPP Printer Port 631' -ErrorAction SilentlyContinue
        $firewallOk = ($rules.Count -gt 0 -and $rules[0].Enabled)
    } catch {}

    $networkProfile = 'Unknown'
    try {
        $profile = Get-NetConnectionProfile -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($profile) { $networkProfile = $profile.NetworkCategory.ToString() }
    } catch {}

    $ippInstalled = $false
    try {
        if (Get-Command -Name Test-IPPClientInstalled -ErrorAction SilentlyContinue) {
            $ippInstalled = Test-IPPClientInstalled
        }
    } catch {}

    [PSCustomObject]@{
        Hostname             = $hostname
        IPv4Addresses        = @($ipv4)
        SharedPrinters       = @($printers)
        PrintMethods         = @($printMethods)
        IPPUrl_Recommended   = if ($printers.Count -gt 0) { $printers[0].IPPUrl } else { '' }
        SMBPath_Recommended  = if ($printers.Count -gt 0) { $printers[0].SMBPath } else { '' }
        FirewallConfigured   = $firewallOk
        NetworkProfile       = $networkProfile
        IPPInstalled         = $ippInstalled
        Timestamp            = Get-Date
    }
}

function Show-AndroidWizard {
    [CmdletBinding()]
    [OutputType([void])]
    param()
    $compat = Get-AndroidCompatibility

    Write-MenuHeader -Title 'Android Compatibility Wizard' -Subtitle 'Detecting Android printing capabilities'

    $profileColor = if ($compat.NetworkProfile -eq 'Private') { 'Green' } else { 'Yellow' }
    $fwColor = if ($compat.FirewallConfigured) { 'Green' } else { 'Yellow' }

    Write-Host "  Windows Host: $($compat.Hostname)" -ForegroundColor White
    Write-Host "  IPv4: $($compat.IPv4Addresses -join ', ')" -ForegroundColor Cyan
    Write-Host "  Network Profile: $($compat.NetworkProfile)" -ForegroundColor $profileColor
    Write-Host "  Firewall (IPP 631): $(if ($compat.FirewallConfigured) { '[OK] Configured' } else { '[WARN] Not configured' })" -ForegroundColor $fwColor
    Write-Host ''

    Write-Host '  Detected Shared Printers:' -ForegroundColor Yellow
    foreach ($p in $compat.SharedPrinters) {
        $statusIcon = if ($p.IsOnline) { '[ONLINE]' } else { '[OFFLINE]' }
        $defIcon = if ($p.IsDefault) { ' [DEFAULT]' } else { '' }
        Write-Host "    $statusIcon $($p.PrinterName)$defIcon" -ForegroundColor $(if ($p.IsOnline) { 'Green' } else { 'Red' })
        Write-Host "    Driver: $($p.DriverName)"
        Write-Host "    IPP: $($p.IPPUrl)" -ForegroundColor Cyan
        Write-Host "    SMB: $($p.SMBPath)" -ForegroundColor Gray
        Write-Host ''
    }

    Write-Host '  Recommended Printing Methods (Android):' -ForegroundColor Yellow
    $sortedMethods = $compat.PrintMethods | Sort-Object Priority
    foreach ($m in $sortedMethods) {
        $icon = if ($m.Supported) { '[OK]' } else { '[--]' }
        $color = if ($m.Supported) { 'Green' } else { 'DarkGray' }
        Write-Host "    $icon $($m.Method) (Priority $($m.Priority))" -ForegroundColor $color
        Write-Host "         $($m.Note)" -ForegroundColor Gray
    }

    Write-Host ''
    Write-Host '  Connection Strings:' -ForegroundColor Yellow
    Write-Host "    IPP:  $($compat.IPPUrl_Recommended)" -ForegroundColor Cyan
    Write-Host "    SMB:  $($compat.SMBPath_Recommended)" -ForegroundColor Gray
    Write-Host "    Host: $($compat.Hostname)  IP: $($compat.IPv4Addresses -join ', ')" -ForegroundColor White

    if (-not $compat.FirewallConfigured) {
        Write-Host ''
        Write-Host '  [WARNING] Firewall not configured for IPP (port 631). Enable it for Android discovery.' -ForegroundColor Yellow
    }
    if ($compat.NetworkProfile -ne 'Private') {
        Write-Host '  [WARNING] Network is not Private. Printer discovery may not work.' -ForegroundColor Yellow
    }
}

function Get-AndroidSetupContent {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$PrinterName = ''
    )

    $compat = Get-AndroidCompatibility
    if ($compat.SharedPrinters.Count -eq 0) { return 'No shared printers available.' }

    $printer = $compat.SharedPrinters | Where-Object { $_.PrinterName -eq $PrinterName } | Select-Object -First 1
    if (-not $printer) { $printer = $compat.SharedPrinters[0] }

    "Printer: $($printer.PrinterName)`r`nIPP: $($printer.IPPUrl)`r`nSMB: $($printer.SMBPath)`r`nHost: $($printer.Hostname)`r`nIP: $($compat.IPv4Addresses -join ', ')"
}

Export-ModuleMember -Function Get-AndroidCompatibility, Show-AndroidWizard, Get-AndroidSetupContent
