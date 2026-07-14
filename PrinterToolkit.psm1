<#
.SYNOPSIS
    PrinterToolkit v4.1 - Root module that loads all submodules.

.DESCRIPTION
    Enterprise Windows printer troubleshooting toolkit.
    Auto-discovers and imports all modules from the Modules/ directory.

.NOTES
    Version: 5.0.0
    Author: PrinterToolkit Contributors
#>

$ModuleRoot = $PSScriptRoot
$ModulePaths = @(
    "$ModuleRoot\Modules\Core\PrinterToolkit.Core.psm1"
    "$ModuleRoot\Modules\IPP\PrinterToolkit.IPP.psm1"
    "$ModuleRoot\Modules\Logging\PrinterToolkit.Logging.psm1"
    "$ModuleRoot\Modules\Utilities\PrinterToolkit.Utilities.psm1"
    "$ModuleRoot\Modules\Android\PrinterToolkit.Android.psm1"
    "$ModuleRoot\Modules\Diagnostics\PrinterToolkit.Diagnostics.psm1"
    "$ModuleRoot\Modules\Repair\PrinterToolkit.Repair.psm1"
    "$ModuleRoot\Modules\Drivers\PrinterToolkit.Drivers.psm1"
    "$ModuleRoot\Modules\Sharing\PrinterToolkit.Sharing.psm1"
    "$ModuleRoot\Modules\Reporting\PrinterToolkit.Reporting.psm1"
    "$ModuleRoot\Modules\Bundle\PrinterToolkit.Bundle.psm1"
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

$Script:ToolkitVersion = '5.0.0'
$Script:LoadedModules = $LoadedModules
$Script:FailedModules = $FailedModules

Write-Verbose "PrinterToolkit v$Script:ToolkitVersion loaded. $($LoadedModules.Count) submodules active."

function Get-ToolkitStatus {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]

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

    if (-not (Test-Administrator)) {
        Write-Host 'PrinterToolkit v5.0' -ForegroundColor Cyan
        Write-Host '====================' -ForegroundColor Cyan
        Write-Host 'NOTE: Some operations require Administrator privileges.' -ForegroundColor Yellow
        Write-Host 'Run as Administrator for full functionality.' -ForegroundColor Yellow
        Write-Host ''
    }

    do {
        $exitRequested = $false
        Clear-Host
        Write-Host ''
        Write-Host '========================================' -ForegroundColor Cyan
        Write-Host '    PrinterToolkit v5.0' -ForegroundColor White
        Write-Host '    Enterprise Printer Management' -ForegroundColor Gray
        Write-Host '========================================' -ForegroundColor Cyan
        Write-Host ''
        Write-Host '  [1]  Printer Inventory' -ForegroundColor White
        Write-Host '  [2]  Printer Details & Status' -ForegroundColor White
        Write-Host '  [3]  Network Printer Discovery' -ForegroundColor White
        Write-Host '  [4]  Printer Connectivity Test' -ForegroundColor White
        Write-Host '  [5]  Manage Print Queue' -ForegroundColor White
        Write-Host '  [6]  IPP Printer Attributes' -ForegroundColor White
        Write-Host '  [7]  IPP Class Drivers' -ForegroundColor White
        Write-Host '  [8]  Driver Management' -ForegroundColor White
        Write-Host '  [9]  Driver Upgrade Recommendations' -ForegroundColor White
        Write-Host '  [10] Android / Mopria' -ForegroundColor White
        Write-Host '  [11] Network Validation Report' -ForegroundColor White
        Write-Host '  [12] Spooler Queue Health' -ForegroundColor White
        Write-Host '  [13] Firewall & Network' -ForegroundColor White
        Write-Host '  [14] Registry & Service Snapshots' -ForegroundColor White
        Write-Host '  [15] Automatic Share Repair' -ForegroundColor White
        Write-Host '  [16] Share Management' -ForegroundColor White
        Write-Host '  [17] Generate Report' -ForegroundColor White
        Write-Host '  [18] Compliance Report' -ForegroundColor White
        Write-Host '  [19] Diagnostic Bundle' -ForegroundColor White
        Write-Host '  [0]  Exit' -ForegroundColor Yellow
        Write-Host ''

        $choice = Read-Host 'Select option'

        Write-Host ''
        switch ($choice) {
            '1'  { Get-Printers | Format-Table -AutoSize }
            '2'  { Get-PrinterStatus | Format-List }
            '3'  { Get-SharedPrinters | Format-Table -AutoSize }
            '4'  { Test-IPPEndpoint }
            '5'  { Clear-PrintQueue }
            '6'  { Get-IPPStatus | Format-List }
            '7'  { Test-IPPClientInstalled }
            '8'  { Show-DriverMenu }
            '9'  { Get-DriverUpgradeRecommendations | Format-Table -AutoSize }
            '10' { Show-AndroidMenu }
            '11' { Show-NetworkValidationReport }
            '12' { Get-PrinterQueueHealth }
            '13' { Show-FirewallMenu }
            '14' { Export-RegistrySnapshot; Export-ServiceSnapshot }
            '15' { Invoke-AutomaticShareRepair }
            '16' { Show-ShareMenu }
            '17' { New-PrinterReport -Format 'HTML' }
            '18' { Get-PrintComplianceReport | Format-Table -AutoSize }
            '19' { New-DiagnosticBundle }
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
        Write-Host '`n--- DRIVER MANAGEMENT ---' -ForegroundColor Cyan
        Write-Host '  1. List Driver Details'
        Write-Host '  2. Export Drivers'
        Write-Host '  3. Install Driver from INF'
        Write-Host '  4. Remove Driver'
        Write-Host '  5. Driver Upgrade Recommendations'
        Write-Host '  0. Back to Main Menu'
        $dChoice = Read-Host 'Select'
        switch ($dChoice) {
            '1' { Get-PrinterDriverDetails | Format-Table -AutoSize }
            '2' { Export-PrinterDrivers }
            '3' {
                $infPath = Read-Host 'Enter INF path'
                if ($infPath -notmatch '\.inf$') { Write-Host 'Invalid: must end with .inf' -ForegroundColor Red; break }
                if ($infPath -match '[";|&$`]') { Write-Host 'Invalid characters in path' -ForegroundColor Red; break }
                Install-PrinterDriverFromInf -InfPath $infPath
            }
            '4' {
                $name = Read-Host 'Enter driver name to remove'
                if ($name -match '[^a-zA-Z0-9 _\-.()]') { Write-Host 'Invalid driver name' -ForegroundColor Red; break }
                Remove-PrinterDriverByName -DriverName $name
            }
            '5' { Get-DriverUpgradeRecommendations | Format-Table -AutoSize }
            '0' { $back = $true }
        }
        if (-not $back) { Pause }
    } while (-not $back)
}

function Show-AndroidMenu {
    do {
        $back = $false
        Write-Host '`n--- ANDROID / MOPRIA ---' -ForegroundColor Cyan
        Write-Host '  1. Check Android Compatibility'
        Write-Host '  2. Launch Mopria Setup Wizard'
        Write-Host '  3. View Android Setup Content'
        Write-Host '  0. Back to Main Menu'
        $aChoice = Read-Host 'Select'
        switch ($aChoice) {
            '1' { Get-AndroidCompatibility | Format-List }
            '2' { Show-AndroidWizard }
            '3' { Get-AndroidSetupContent | Format-List }
            '0' { $back = $true }
        }
        if (-not $back) { Pause }
    } while (-not $back)
}

function Show-FirewallMenu {
    do {
        $back = $false
        Write-Host '`n--- FIREWALL & NETWORK ---' -ForegroundColor Cyan
        Write-Host '  1. Run Full Network Validation'
        Write-Host '  2. Show Validation Report'
        Write-Host '  3. Export Firewall Rules Snapshot'
        Write-Host '  4. Export Service State Snapshot'
        Write-Host '  0. Back to Main Menu'
        $fChoice = Read-Host 'Select'
        switch ($fChoice) {
            '1' { Get-NetworkValidation }
            '2' { Show-NetworkValidationReport }
            '3' { Export-FirewallSnapshot }
            '4' { Export-ServiceSnapshot }
            '0' { $back = $true }
        }
        if (-not $back) { Pause }
    } while (-not $back)
}

function Show-ShareMenu {
    do {
        $back = $false
        Write-Host '`n--- SHARE MANAGEMENT ---' -ForegroundColor Cyan
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
                if ($acct -notmatch '^[a-zA-Z0-9_.-]+\\[a-zA-Z0-9_. -]+$') { Write-Host 'Invalid account format. Use DOMAIN\User' -ForegroundColor Red; break }
                Set-PrinterSharePermission -ShareName $share -AccountName $acct -AccessRight $right -Force
            }
            '6' { Get-PrinterSharingCompatibility | Format-Table -AutoSize }
            '0' { $back = $true }
        }
        if (-not $back) { Pause }
    } while (-not $back)
}

function Pause {
    Write-Host 'Press any key to continue...'
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}

Export-ModuleMember -Function Get-ToolkitStatus, Invoke-ToolkitMainMenu
