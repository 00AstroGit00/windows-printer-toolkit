<#
.SYNOPSIS
    PrinterToolkit v8.2.0 - Dependency-Aware Print Server Orchestration Platform.

.DESCRIPTION
    Transforms a USB-connected printer into a fully configured, validated,
    and network-accessible shared printer for Windows, Android, and LAN devices.
    Auto-detects printers, installs drivers, configures Windows, enables IPP/SMB,
    and validates end-to-end with zero required user intervention. Operations are
    expressed as declarative tasks resolved and executed by a DAG-based orchestrator.

.NOTES
    Version: 8.2.0
    Author: PrinterToolkit Contributors
#>

$ModuleRoot = $PSScriptRoot

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning 'PrinterToolkit requires Administrator privileges. Most operations will fail without elevation. Re-import the module from an elevated PowerShell session.'
}
$ModulePaths = @(
    "$ModuleRoot\Modules\Core\PrinterToolkit.Core.psm1"
    "$ModuleRoot\Modules\Detection\PrinterToolkit.Detection.psm1"
    "$ModuleRoot\Modules\Configuration\PrinterToolkit.Configuration.psm1"
    "$ModuleRoot\Modules\Drivers\PrinterToolkit.Drivers.psm1"
    "$ModuleRoot\Modules\Networking\PrinterToolkit.Networking.psm1"
    "$ModuleRoot\Modules\IPP\PrinterToolkit.IPP.psm1"
    "$ModuleRoot\Modules\SMB\PrinterToolkit.SMB.psm1"
    "$ModuleRoot\Modules\Sharing\PrinterToolkit.Sharing.psm1"
    "$ModuleRoot\Modules\Android\PrinterToolkit.Android.psm1"
    "$ModuleRoot\Modules\Diagnostics\PrinterToolkit.Diagnostics.psm1"
    "$ModuleRoot\Modules\Repair\PrinterToolkit.Repair.psm1"
    "$ModuleRoot\Modules\Rollback\PrinterToolkit.Rollback.psm1"
    "$ModuleRoot\Modules\Validation\PrinterToolkit.Validation.psm1"
    "$ModuleRoot\Modules\SetupWizard\PrinterToolkit.SetupWizard.psm1"
    "$ModuleRoot\Modules\Reporting\PrinterToolkit.Reporting.psm1"
    "$ModuleRoot\Modules\Logging\PrinterToolkit.Logging.psm1"
    "$ModuleRoot\Modules\Utilities\PrinterToolkit.Utilities.psm1"
    "$ModuleRoot\Modules\Bundle\PrinterToolkit.Bundle.psm1"
    "$ModuleRoot\Modules\ZeroTouch\PrinterToolkit.ZeroTouch.psm1"
    "$ModuleRoot\Modules\Orchestration\PrinterToolkit.Orchestration.psm1"
    "$ModuleRoot\Modules\Providers\PrinterToolkit.Providers.psm1"
)

$LoadedModules = @()
$FailedModules = @()

foreach ($modPath in $ModulePaths) {
    if (Test-Path -Path $modPath -PathType Leaf) {
        try {
            $null = Import-Module -Name $modPath -Force -ErrorAction Stop -Verbose:$false
            $LoadedModules += (Get-Item -Path $modPath).BaseName
            Write-Verbose "Loaded module: $modPath"
        } catch {
            $FailedModules += @{ Path = $modPath; Error = $_.Exception.Message }
            Write-Warning "Failed to load module: $modPath - $($_.Exception.Message)"
        }
    } else {
        Write-Verbose "Module not found: $modPath"
    }
}

$Script:ToolkitVersion = '8.2.0'
$Script:LoadedModules = $LoadedModules
$Script:FailedModules = $FailedModules

Write-Verbose "PrinterToolkit v$Script:ToolkitVersion loaded. $($LoadedModules.Count) submodules active."

function Get-ToolkitStatus {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    [PSCustomObject]@{
        Version         = $Script:ToolkitVersion
        LoadedModules   = @($Script:LoadedModules)
        FailedModules   = @($Script:FailedModules)
        IsAdministrator = (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        Timestamp       = Get-Date
    }
}

function Invoke-ToolkitMainMenu {
    [CmdletBinding()]
    param()

    if (-not (Test-Administrator)) {
        Write-Host 'PrinterToolkit v8.2.0' -ForegroundColor Cyan
        Write-Host '====================' -ForegroundColor Cyan
        Write-Host 'NOTE: Print Server operations require Administrator privileges.' -ForegroundColor Yellow
        Write-Host 'Run as Administrator for full functionality.' -ForegroundColor Yellow
        Write-Host ''
    }

    do {
        $exitRequested = $false
        Clear-Host
        Write-Host ''
        Write-Host '========================================' -ForegroundColor Cyan
        Write-Host '    PrinterToolkit v8.2.0' -ForegroundColor White
        Write-Host '    Print Server Deployment Platform' -ForegroundColor Gray
        Write-Host '========================================' -ForegroundColor Cyan
        Write-Host ''
        Write-Host '  PRINT SERVER WIZARD' -ForegroundColor Magenta
        Write-Host '  [W]  Launch Print Server Wizard (11 steps)' -ForegroundColor White
        Write-Host '  [Z]  Zero-Touch Deployment (Click Start Setup)' -ForegroundColor White
        Write-Host '  [V]  Validation Dashboard' -ForegroundColor White
        Write-Host ''
        Write-Host '  DETECTION & DRIVERS' -ForegroundColor Yellow
        Write-Host '  [1]  Printer Inventory' -ForegroundColor White
        Write-Host '  [2]  Printer Details & Status' -ForegroundColor White
        Write-Host '  [3]  USB Printer Detection' -ForegroundColor White
        Write-Host '  [4]  Hardware ID Information' -ForegroundColor White
        Write-Host '  [5]  Driver Intelligence Engine' -ForegroundColor White
        Write-Host '  [6]  Driver Management' -ForegroundColor White
        Write-Host '  [7]  Driver Upgrade Recommendations' -ForegroundColor White
        Write-Host ''
        Write-Host '  CONFIGURATION' -ForegroundColor Green
        Write-Host '  [8]  Windows Features' -ForegroundColor White
        Write-Host '  [9]  Windows Services' -ForegroundColor White
        Write-Host '  [10] Firewall & Network' -ForegroundColor White
        Write-Host '  [11] Registry & Service Snapshots' -ForegroundColor White
        Write-Host ''
        Write-Host '  SHARING & CONNECTIVITY' -ForegroundColor Cyan
        Write-Host '  [12] IPP Printer Attributes' -ForegroundColor White
        Write-Host '  [13] Share Management' -ForegroundColor White
        Write-Host '  [14] SMB Configuration' -ForegroundColor White
        Write-Host '  [15] Android / Mopria' -ForegroundColor White
        Write-Host '  [16] Connection Info & QR Codes' -ForegroundColor White
        Write-Host ''
        Write-Host '  DIAGNOSTICS & REPAIR' -ForegroundColor Yellow
        Write-Host '  [17] Network Validation Report' -ForegroundColor White
        Write-Host '  [18] Automatic Share Repair' -ForegroundColor White
        Write-Host '  [19] Rollback Last Repair' -ForegroundColor White
        Write-Host '  [20] Spooler Queue Health' -ForegroundColor White
        Write-Host ''
        Write-Host '  REPORTS' -ForegroundColor Blue
        Write-Host '  [21] Generate Report' -ForegroundColor White
        Write-Host '  [22] Compliance Report' -ForegroundColor White
        Write-Host '  [23] Diagnostic Bundle' -ForegroundColor White
        Write-Host ''
        Write-Host '  [0]  Exit' -ForegroundColor Yellow
        Write-Host ''

        $choice = Read-Host 'Select option'

        Write-Host ''
        switch ($choice) {
            'W' { Invoke-PrintServerWizard }
            'w' { Invoke-PrintServerWizard }
            'Z' { Start-ZeroTouchDeployment }
            'z' { Start-ZeroTouchDeployment }
            'V' { Invoke-EndToEndValidation }
            'v' { Invoke-EndToEndValidation }
            '1'  { Get-Printers | Format-Table -AutoSize }
            '2'  { Get-PrinterStatus | Format-List }
            '3'  { Get-UsbPrinterInfo | Format-List }
            '4'  { Get-HardwareIdInfo | Format-List }
            '5'  { Get-DriverIntelligence | Format-List }
            '6'  { Show-DriverMenu }
            '7'  { Get-DriverUpgradeRecommendations | Format-Table -AutoSize }
            '8'  { Show-FeatureMenu }
            '9'  { Show-ServiceMenu }
            '10' { Show-FirewallMenu }
            '11' { Export-RegistrySnapshot; Export-ServiceSnapshot }
            '12' { Get-IPPStatus | Format-List }
            '13' { Show-ShareMenu }
            '14' { Show-SmbMenu }
            '15' { Show-AndroidMenu }
            '16' { Show-ConnectionMenu }
            '17' { Show-NetworkValidationReport }
            '18' { Invoke-AutomaticShareRepair }
            '19' { Show-RollbackMenu }
            '20' { Get-PrinterQueueHealth }
            '21' { New-PrinterReport -Format 'HTML' }
            '22' { Get-PrintComplianceReport | Format-Table -AutoSize }
            '23' { New-DiagnosticBundle }
            '0'  { $exitRequested = $true }
            default { Write-Host 'Invalid option.' -ForegroundColor Red }
        }

        if (-not $exitRequested -and $choice -ne '0') {
            Write-Host ''
            Pause
        }
    } while (-not $exitRequested)
}

function Show-DriverMenu {
    do {
        $back = $false
        Write-Host "`n--- DRIVER MANAGEMENT ---" -ForegroundColor Cyan
        Write-Host '  1. List Driver Details'
        Write-Host '  2. Driver Intelligence (Full Detection)'
        Write-Host '  3. Export Drivers'
        Write-Host '  4. Install Driver from INF'
        Write-Host '  5. Remove Driver'
        Write-Host '  6. Driver Upgrade Recommendations'
        Write-Host '  0. Back to Main Menu'
        $dChoice = Read-Host 'Select'
        switch ($dChoice) {
            '1' { Get-PrinterDriverDetails | Format-Table -AutoSize }
            '2' { Get-DriverIntelligence | Format-List }
            '3' { Export-PrinterDrivers }
            '4' {
                $infPath = Read-Host 'Enter INF path'
                if ($infPath -notmatch '\.inf$') { Write-Host 'Invalid: must end with .inf' -ForegroundColor Red; break }
                if ($infPath -match '[";|&$`]') { Write-Host 'Invalid characters in path' -ForegroundColor Red; break }
                Install-PrinterDriverFromInf -InfPath $infPath
            }
            '5' {
                $name = Read-Host 'Enter driver name to remove'
                if ($name -match '[^a-zA-Z0-9 _\-.()]') { Write-Host 'Invalid driver name' -ForegroundColor Red; break }
                Remove-PrinterDriverByName -DriverName $name
            }
            '6' { Get-DriverUpgradeRecommendations | Format-Table -AutoSize }
            '0' { $back = $true }
        }
        if (-not $back) { Pause }
    } while (-not $back)
}

function Show-AndroidMenu {
    do {
        $back = $false
        Write-Host "`n--- ANDROID / MOPRIA ---" -ForegroundColor Cyan
        Write-Host '  1. Check Android Compatibility'
        Write-Host '  2. Launch Mopria Setup Wizard'
        Write-Host '  3. View Android Setup Content'
        Write-Host '  4. Generate Connection QR Code'
        Write-Host '  0. Back to Main Menu'
        $aChoice = Read-Host 'Select'
        switch ($aChoice) {
            '1' { Get-AndroidCompatibility | Format-List }
            '2' { Show-AndroidWizard }
            '3' { Get-AndroidSetupContent | Format-List }
            '4' { New-ConnectionQRCode }
            '0' { $back = $true }
        }
        if (-not $back) { Pause }
    } while (-not $back)
}

function Show-FirewallMenu {
    do {
        $back = $false
        Write-Host "`n--- FIREWALL & NETWORK ---" -ForegroundColor Cyan
        Write-Host '  1. Run Full Network Validation'
        Write-Host '  2. Show Validation Report'
        Write-Host '  3. Check Firewall Rules'
        Write-Host '  4. Set Firewall Rule'
        Write-Host '  5. Check Network Profile'
        Write-Host '  6. Set Network to Private'
        Write-Host '  7. Check Windows Features'
        Write-Host '  8. Check Service Status'
        Write-Host '  9. Export Firewall Rules Snapshot'
        Write-Host ' 10. Export Service State Snapshot'
        Write-Host '  0. Back to Main Menu'
        $fChoice = Read-Host 'Select'
        switch ($fChoice) {
            '1' { Get-NetworkValidation }
            '2' { Show-NetworkValidationReport }
            '3' { Get-FirewallRuleStatus | Format-Table -AutoSize }
            '4' {
                $name = Read-Host 'Rule name'
                $action = Read-Host 'Action (Allow/Block)'
                if ($action -notin 'Allow','Block') { Write-Host 'Invalid action' -ForegroundColor Red; break }
                Set-FirewallRule -RuleName $name -Action $action
            }
            '5' { Get-NetworkProfileStatus | Format-List }
            '6' { Set-NetworkProfilePrivate }
            '7' { Get-WindowsFeatureStatus | Format-Table -AutoSize }
            '8' { Get-ServiceStatus | Format-Table -AutoSize }
            '9' { Export-FirewallSnapshot }
            '10' { Export-ServiceSnapshot }
            '0' { $back = $true }
        }
        if (-not $back) { Pause }
    } while (-not $back)
}

function Show-ShareMenu {
    do {
        $back = $false
        Write-Host "`n--- SHARE MANAGEMENT ---" -ForegroundColor Cyan
        Write-Host '  1. List Share Status'
        Write-Host '  2. Enable Sharing for Printer'
        Write-Host '  3. Disable Sharing for Printer'
        Write-Host '  4. SMB Share Permissions'
        Write-Host '  5. Set Share Permission'
        Write-Host '  6. Sharing Compatibility Check'
        Write-Host '  0. Back to Main Menu'
        $sChoice = Read-Host 'Select'
        switch ($sChoice) {
            '1' { Get-PrinterShareStatus | Format-Table -AutoSize }
            '2' {
                $name = Read-Host 'Enter printer name'
                $share = Read-Host 'Enter share name (optional)'
                if (-not (Get-Printer -Name $name -ErrorAction SilentlyContinue)) { Write-Host 'Printer not found' -ForegroundColor Red; break }
                if ($share -and $share -match '[^a-zA-Z0-9 _\-]') { Write-Host 'Invalid share name' -ForegroundColor Red; break }
                if ($share) { Enable-PrinterSharing -PrinterName $name -ShareName $share }
                else { Enable-PrinterSharing -PrinterName $name }
            }
            '3' {
                $name = Read-Host 'Enter printer name'
                if (-not (Get-Printer -Name $name -ErrorAction SilentlyContinue)) { Write-Host 'Printer not found' -ForegroundColor Red; break }
                Disable-PrinterSharing -PrinterName $name
            }
            '4' { Get-SmbSharePermissions | Format-Table -AutoSize }
            '5' {
                $share = Read-Host 'Share name'
                $acct = Read-Host 'Account (DOMAIN\User)'
                $right = Read-Host 'AccessRight (Read/Change/FullControl)'
                if ($share -match '[^a-zA-Z0-9 _\-]') { Write-Host 'Invalid share name' -ForegroundColor Red; break }
                if ($acct -notmatch '^[a-zA-Z0-9_. -]+\\[a-zA-Z0-9_. -]+$') { Write-Host 'Invalid account format. Use DOMAIN\User' -ForegroundColor Red; break }
                Set-PrinterSharePermission -ShareName $share -AccountName $acct -AccessRight $right -Force
            }
            '6' { Get-PrinterSharingCompatibility | Format-Table -AutoSize }
            '0' { $back = $true }
        }
        if (-not $back) { Pause }
    } while (-not $back)
}

function Show-FeatureMenu {
    do {
        $back = $false
        Write-Host "`n--- WINDOWS FEATURES ---" -ForegroundColor Cyan
        Write-Host '  1. List Windows Feature Status'
        Write-Host '  2. Enable Print Services Feature'
        Write-Host '  3. Enable IPP Feature'
        Write-Host '  4. Enable SMB Feature'
        Write-Host '  5. Enable All Printing Features'
        Write-Host '  0. Back to Main Menu'
        $fChoice = Read-Host 'Select'
        switch ($fChoice) {
            '1' { Get-WindowsFeatureStatus | Format-Table -AutoSize }
            '2' { Set-WindowsFeature -FeatureName 'Printing-PrintManagement-Console' -Enable }
            '3' { Set-WindowsFeature -FeatureName 'Printing-InternetPrinting-Client' -Enable }
            '4' { Set-WindowsFeature -FeatureName 'SMB1Protocol' -Enable }
            '5' {
                Set-WindowsFeature -FeatureName 'Printing-PrintManagement-Console' -Enable
                Set-WindowsFeature -FeatureName 'Printing-InternetPrinting-Client' -Enable
            }
            '0' { $back = $true }
        }
        if (-not $back) { Pause }
    } while (-not $back)
}

function Show-ServiceMenu {
    do {
        $back = $false
        Write-Host "`n--- WINDOWS SERVICES ---" -ForegroundColor Cyan
        Write-Host '  1. List Service Status'
        Write-Host '  2. Set Service Configuration'
        Write-Host '  3. Enable All Required Services'
        Write-Host '  0. Back to Main Menu'
        $sChoice = Read-Host 'Select'
        switch ($sChoice) {
            '1' { Get-ServiceStatus | Format-Table -AutoSize }
            '2' {
                $name = Read-Host 'Service name'
                $startType = Read-Host 'StartType (Automatic/Manual/Disabled)'
                if ($startType -notin 'Automatic','Manual','Disabled') { Write-Host 'Invalid start type' -ForegroundColor Red; break }
                Set-ServiceConfiguration -ServiceName $name -StartType $startType
            }
            '3' {
                $svcs = @('Spooler','LanmanServer','LanmanWorkstation','FDResPub','FDPhost','RpcSs','DcomLaunch','DNSCache','SSDPSRV','upnphost')
                foreach ($s in $svcs) {
                    Set-ServiceConfiguration -ServiceName $s -StartType Automatic -EnsureRunning
                }
            }
            '0' { $back = $true }
        }
        if (-not $back) { Pause }
    } while (-not $back)
}

function Show-SmbMenu {
    do {
        $back = $false
        Write-Host "`n--- SMB CONFIGURATION ---" -ForegroundColor Cyan
        Write-Host '  1. Get SMB Configuration'
        Write-Host '  2. Enable SMB 1.0/CIFS'
        Write-Host '  3. Enable SMB 2/3'
        Write-Host '  4. Optimize SMB for Printing'
        Write-Host '  0. Back to Main Menu'
        $sChoice = Read-Host 'Select'
        switch ($sChoice) {
            '1' { Get-SmbConfiguration | Format-List }
            '2' { Set-SmbConfiguration -Smb1Enabled $true }
            '3' { Set-SmbConfiguration -Smb2Enabled $true }
            '4' {
                Set-SmbConfiguration -Smb1Enabled $true -Smb2Enabled $true
                Get-SmbConfiguration | Format-List
            }
            '0' { $back = $true }
        }
        if (-not $back) { Pause }
    } while (-not $back)
}

function Show-ConnectionMenu {
    do {
        $back = $false
        Write-Host "`n--- CONNECTION INFORMATION ---" -ForegroundColor Cyan
        Write-Host '  1. Get Connection Info for All Printers'
        Write-Host '  2. Generate QR Code for IPP URL'
        Write-Host '  3. Generate QR Code for Setup Guide'
        Write-Host '  4. Generate QR Code for Troubleshooting'
        Write-Host '  0. Back to Main Menu'
        $cChoice = Read-Host 'Select'
        switch ($cChoice) {
            '1' { Get-ConnectionInfo | Format-List }
            '2' { New-ConnectionQRCode -Type 'IPP' }
            '3' { New-ConnectionQRCode -Type 'SetupGuide' }
            '4' { New-ConnectionQRCode -Type 'TroubleshootingGuide' }
            '0' { $back = $true }
        }
        if (-not $back) { Pause }
    } while (-not $back)
}

function Show-RollbackMenu {
    do {
        $back = $false
        Write-Host "`n--- ROLLBACK ---" -ForegroundColor Cyan
        Write-Host '  1. View Rollback Points'
        Write-Host '  2. Restore Last Rollback Point'
        Write-Host '  0. Back to Main Menu'
        $rChoice = Read-Host 'Select'
        switch ($rChoice) {
            '1' {
                $points = Get-ChildItem -Path "$env:TEMP\PrinterToolkit_Rollback_*" -Directory -ErrorAction SilentlyContinue
                if ($points) { $points | Select-Object Name, LastWriteTime | Format-Table -AutoSize }
                else { Write-Host 'No rollback points found.' -ForegroundColor Yellow }
            }
            '2' { Invoke-Rollback }
            '0' { $back = $true }
        }
        if (-not $back) { Pause }
    } while (-not $back)
}

function Pause {
    Write-Host 'Press any key to continue...'
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}
