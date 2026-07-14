<#
.SYNOPSIS
    Android device printing compatibility for PrinterToolkit v6.0.

.DESCRIPTION
    Detects Windows host capabilities for Android printing via Mopria/IPP,
    generates setup instructions, connection information, and QR codes
    for easy mobile device configuration.

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
            RecommendedMethod = 'Share a printer first via Print Server Wizard'
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

function Get-ConnectionInfo {
    [CmdletBinding()]
    [OutputType([array])]
    param()

    $hostname = $env:COMPUTERNAME
    $ipv4 = @()
    try {
        $ipv4 = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object { $_.InterfaceAlias -notmatch 'Loopback|Teredo|isatap' } |
            Select-Object -ExpandProperty IPAddress
    } catch {}

    $sharedPrinters = @(Get-Printer -ErrorAction SilentlyContinue | Where-Object { $_.Shared })
    $results = [System.Collections.ArrayList]::new()

    foreach ($p in $sharedPrinters) {
        $shareName = if ($p.ShareName) { $p.ShareName } else { $p.Name -replace '[^a-zA-Z0-9_-]', '_' }

        $null = $results.Add([PSCustomObject]@{
            PrinterName  = $p.Name
            ShareName    = $shareName
            WindowsPath  = "\\$hostname\$shareName"
            SMBPath      = "\\$hostname\$shareName"
            IPPUrl       = "ipp://$hostname/printers/$shareName"
            HTTPUrl      = "http://$hostname`:631/printers/$shareName"
            Hostname     = $hostname
            IPv4         = ($ipv4 -join ', ')
            Port         = $p.PortName
            DriverName   = $p.DriverName
        })
    }

    if ($results.Count -eq 0) {
        $null = $results.Add([PSCustomObject]@{
            PrinterName = '(none)'
            ShareName   = ''
            WindowsPath = ''
            SMBPath     = ''
            IPPUrl      = ''
            HTTPUrl     = ''
            Hostname    = $hostname
            IPv4        = ($ipv4 -join ', ')
            Port        = ''
            DriverName  = ''
        })
    }

    return ,@($results)
}

function New-ConnectionQRCode {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('IPP', 'SetupGuide', 'TroubleshootingGuide')]
        [string]$Type = 'IPP',
        [Parameter(Mandatory = $false)]
        [string]$PrinterName,
        [Parameter(Mandatory = $false)]
        [string]$OutputPath
    )

    $result = [PSCustomObject]@{
        Type        = $Type
        PrinterName = $PrinterName
        Content     = ''
        OutputPath  = ''
        Success     = $false
        Detail      = ''
    }

    $hostname = $env:COMPUTERNAME
    $ipv4 = @()
    try {
        $ipv4 = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object { $_.InterfaceAlias -notmatch 'Loopback|Teredo|isatap' } |
            Select-Object -ExpandProperty IPAddress
    } catch {}

    $targetPrinter = $null
    if ($PrinterName) {
        $targetPrinter = Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue
    } else {
        $targetPrinter = Get-Printer -ErrorAction SilentlyContinue | Where-Object { $_.Shared } | Select-Object -First 1
    }

    $shareName = if ($targetPrinter -and $targetPrinter.ShareName) {
        $targetPrinter.ShareName
    } elseif ($targetPrinter) {
        $targetPrinter.Name -replace '[^a-zA-Z0-9_-]', '_'
    } else {
        'Unknown'
    }

    $printerLabel = if ($targetPrinter) { $targetPrinter.Name } else { 'Unknown Printer' }

    switch ($Type) {
        'IPP' {
            $result.Content = "ipp://$hostname/printers/$shareName"
            $result.Detail = 'IPP connection URL'
        }
        'SetupGuide' {
            $result.Content = @"
PRINTERTOOLKIT SETUP GUIDE
===========================
Printer: $printerLabel
Host: $hostname
IP: $($ipv4 -join ', ')
Windows: \\$hostname\$shareName
SMB: \\$hostname\$shareName
IPP: ipp://$hostname/printers/$shareName
HTTP: http://$hostname:631/printers/$shareName

ANDROID SETUP:
1. Install Mopria Print Service from Google Play
2. Connect to same Wi-Fi network
3. Open document, select Print, choose discovered printer
4. Or manually add: ipp://$hostname/printers/$shareName

WINDOWS CLIENT SETUP:
1. Open Settings > Bluetooth & Devices > Printers & Scanners
2. Click Add Device
3. Select the printer from the list
4. Or add manually: \\$hostname\$shareName
"@
            $result.Detail = 'Complete setup guide'
        }
        'TroubleshootingGuide' {
            $result.Content = @"
PRINTERTOOLKIT TROUBLESHOOTING
==============================
Printer: $printerLabel
Host: $hostname

COMMON ISSUES:
1. Printer not found: Ensure both devices are on same network
2. Firewall blocking: Check port 631 (IPP) and 445 (SMB) are open
3. Network profile: Must be Private (not Public)
4. Spooler: Run `Get-Service Spooler` to verify it's running
5. Sharing: Verify printer is shared in Windows Settings
6. Driver: Check printer driver is installed and working
7. Test page: Print a test page from Windows to verify local printing

QUICK FIXES:
- Run PrinterToolkit Print Server Wizard (Option W)
- Run End-to-End Validation (Option V)
- Run Automatic Share Repair (Option 18)
"@
            $result.Detail = 'Troubleshooting guide'
        }
    }

    if (-not $OutputPath) {
        $desktop = [Environment]::GetFolderPath('Desktop')
        $OutputPath = Join-Path -Path $desktop -ChildPath "PrinterToolkit_QR_$Type.txt"
    }

    try {
        $result.Content | Out-File -FilePath $OutputPath -Encoding UTF8
        $result.OutputPath = $OutputPath
        $result.Success = $true

        Write-Host ''
        Write-Host "  [OK] QR content saved to: $OutputPath" -ForegroundColor Green
        Write-Host ''
        Write-Host '  QR Code Content:' -ForegroundColor Yellow
        Write-Host '  ---' -ForegroundColor DarkGray
        $result.Content -split "`n" | ForEach-Object {
            Write-Host "  $_" -ForegroundColor Cyan
        }
        Write-Host '  ---' -ForegroundColor DarkGray
        Write-Host ''
        Write-Host '  Scan the QR code with your Android device to auto-configure.' -ForegroundColor Gray
        Write-Host '  (Use any QR code generator app to convert the content above)' -ForegroundColor Gray
    } catch {
        $result.Detail = $_.Exception.Message
        Write-Log -Message "New-ConnectionQRCode failed: $_" -Level 'ERROR'
    }

    return $result
}

Export-ModuleMember -Function Get-AndroidCompatibility, Show-AndroidWizard, Get-AndroidSetupContent, Get-ConnectionInfo, New-ConnectionQRCode
