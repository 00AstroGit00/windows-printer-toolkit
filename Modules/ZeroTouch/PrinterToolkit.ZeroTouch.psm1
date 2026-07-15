<#
.SYNOPSIS
    Zero-Touch Print Server Deployment Engine for PrinterToolkit v7.0.

.DESCRIPTION
    Implements the v7.0 zero-touch lifecycle: detect -> analyze -> backup ->
    configure -> validate -> rollback -> report. Orchestrates the existing
    detection, driver, configuration, sharing, IPP, SMB, validation, repair and
    rollback engines so a USB printer can be deployed as a print server with a
    single "Start Setup" action. Maintains a transaction log per deployment.

.NOTES
    Module: PrinterToolkit.ZeroTouch
    Author: PrinterToolkit Contributors
#>

$Script:TransactionDir = $null
$Script:TransactionId = $null
$Script:ZTMajorServices = @(
    'Spooler', 'LanmanServer', 'LanmanWorkstation', 'FDResPub',
    'FDPhost', 'RpcSs', 'DcomLaunch', 'DNSCache', 'SSDPSRV', 'upnphost'
)
$Script:ZTServerFeatures = @('Printing-PrintManagement-Console', 'Printing-InternetPrinting-Server', 'Print-Server')
$Script:ZTClientFeatures = @('Printing-PrintManagement-Console', 'Printing-InternetPrinting-Client')

# ---------------------------------------------------------------------------
# Transaction logging (Operation / Change / Repair / Validation / Rollback)
# ---------------------------------------------------------------------------

function Start-DeploymentTransaction {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $Script:TransactionId = "ZT_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    $Script:TransactionDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "PrinterToolkit_ZeroTouch\$Script:TransactionId"
    $null = New-Item -ItemType Directory -Force -Path $Script:TransactionDir

    $meta = [PSCustomObject]@{
        TransactionId   = $Script:TransactionId
        StartedAt       = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        ToolkitVersion  = '8.2.0'
    }
    $meta | ConvertTo-Json | Out-File -FilePath (Join-Path $Script:TransactionDir 'transaction.json') -Encoding UTF8
    Write-TransactionLog -Category Operation -Message 'Transaction started' -Data $meta
    return $Script:TransactionId
}

function Write-TransactionLog {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Operation', 'Change', 'Repair', 'Validation', 'Rollback')]
        [string]$Category,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [PSObject]$Data
    )

    if (-not $Script:TransactionDir) { $null = Start-DeploymentTransaction }

    $entry = [PSCustomObject]@{
        Timestamp = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff')
        Category  = $Category
        Message   = $Message
        Data      = $Data
    }
    $file = Join-Path -Path $Script:TransactionDir -ChildPath "$Category.log"
    try {
        $entry | ConvertTo-Json -Compress | Out-File -FilePath $file -Append -Encoding UTF8
    } catch {}

    $level = if ($Category -eq 'Rollback' -or $Category -eq 'Repair') { 'WARN' } else { 'INFO' }
    Write-Log -Message "[$Category] $Message" -Level $level
}

function Complete-DeploymentTransaction {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $false)]
        [bool]$Success = $true
    )

    if (-not $Script:TransactionDir) { return }

    $meta = [PSCustomObject]@{
        TransactionId = $Script:TransactionId
        CompletedAt   = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        Success       = $Success
    }
    $meta | ConvertTo-Json | Out-File -FilePath (Join-Path $Script:TransactionDir 'complete.json') -Encoding UTF8
    Write-TransactionLog -Category Operation -Message 'Transaction completed' -Data $meta
}

function Get-TransactionLogPath {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    [PSCustomObject]@{
        TransactionId = $Script:TransactionId
        Path          = $Script:TransactionDir
        Exists        = if ($Script:TransactionDir) { Test-Path -Path $Script:TransactionDir } else { $false }
    }
}

# ---------------------------------------------------------------------------
# Phase helpers (script-scoped, reused by configure + guided recovery)
# ---------------------------------------------------------------------------

function Invoke-ZTDetect {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$PrinterName
    )

    $result = [PSCustomObject]@{ Printer = $null; UsbPrinters = @(); HardwareIds = $null }

    if ($PrinterName) {
        $printer = Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue
        if ($printer) { $result.Printer = $printer }
    } else {
        $usb = Get-UsbPrinterInfo -ErrorAction SilentlyContinue
        if ($usb -and $usb.Count -gt 0) {
            $result.Printer = $usb[0]
            $result.UsbPrinters = @($usb)
        }
    }

    try { $result.HardwareIds = Get-HardwareIdInfo -ErrorAction SilentlyContinue } catch {}
    return $result
}

function Invoke-ZTAnalyze {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PrinterName
    )

    $driver = Get-DriverIntelligence -PrinterName $PrinterName -ErrorAction SilentlyContinue
    $signature = $null
    if ($driver -and (Get-Command -Name Test-DriverSignature -ErrorAction SilentlyContinue)) {
        try { $signature = Test-DriverSignature -DriverName $PrinterName } catch {}
    }

    [PSCustomObject]@{
        PrinterName    = $PrinterName
        Driver         = $driver
        Signature      = $signature
        UpgradeAdvised = if ($driver) { $driver.UpgradeRecommended } else { $false }
    }
}

function Invoke-ZTBackup {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PrinterName
    )

    $rollbackPath = Initialize-RepairRollback
    try { Export-RegistrySnapshot -ErrorAction SilentlyContinue } catch {}
    try { Export-ServiceSnapshot -ErrorAction SilentlyContinue } catch {}
    try { Backup-PrinterConfiguration -PrinterName $PrinterName -RollbackPath $rollbackPath -ErrorAction SilentlyContinue } catch {}

    [PSCustomObject]@{ RollbackPath = $rollbackPath; Created = (Test-Path -Path $rollbackPath) }
}

function Invoke-ZTLayerRepair {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Layer,

        [Parameter(Mandatory = $false)]
        [string]$PrinterName,

        [Parameter(Mandatory = $false)]
        [string]$ShareName
    )

    $layerResult = [PSCustomObject]@{ Layer = $Layer; Success = $false; Detail = '' }

    switch ($Layer) {
        'Services' {
            foreach ($svc in $Script:ZTMajorServices) {
                $r = Invoke-RepairCycle -Issue "Service $svc not running" -RootCause 'Service stopped or disabled' `
                    -RepairAction { Set-ServiceConfiguration -ServiceName $svc -StartType Automatic -EnsureRunning } `
                    -ValidateAction { $s = Get-Service -Name $svc -ErrorAction SilentlyContinue; return ($s -and $s.Status -eq 'Running') }
                if (-not ($r.RepairSuccess -and $r.ValidateSuccess)) {
                    $layerResult.Detail = "Service $svc failed: $($r.Detail)"
                    return $layerResult
                }
            }
            $layerResult.Success = $true
        }
        'Firewall' {
            $r = Invoke-RepairCycle -Issue 'Firewall blocking print sharing' -RootCause 'Print/firewall rules disabled' `
                -RepairAction {
                    $null = Enable-PrinterFirewallRules -IncludeIpp
                } `
                -ValidateAction {
                    $fp = Get-NetFirewallRule -DisplayGroup 'File and Printer Sharing' -ErrorAction SilentlyContinue
                    $fpOk = @($fp | Where-Object { $_.Enabled }).Count -gt 0
                    $ipp = Get-NetFirewallRule -DisplayName 'IPP Printer Port 631' -ErrorAction SilentlyContinue
                    return ($fpOk -and $ipp -and $ipp.Enabled)
                }
            $layerResult.Success = ($r.RepairSuccess -and $r.ValidateSuccess)
            $layerResult.Detail = $r.Detail
        }
        'Network' {
            $r = Invoke-RepairCycle -Issue 'Network profile is not Private' -RootCause 'Public profile blocks discovery' `
                -RepairAction {
                    $profile = Get-NetConnectionProfile -ErrorAction SilentlyContinue | Select-Object -First 1
                    if ($profile -and $profile.NetworkCategory -ne 'Private') {
                        Set-NetConnectionProfile -InterfaceIndex $profile.InterfaceIndex -NetworkCategory Private -ErrorAction SilentlyContinue
                    }
                } `
                -ValidateAction {
                    $p = Get-NetConnectionProfile -ErrorAction SilentlyContinue | Select-Object -First 1
                    return ($p -and $p.NetworkCategory -eq 'Private')
                }
            $layerResult.Success = ($r.RepairSuccess -and $r.ValidateSuccess)
            $layerResult.Detail = $r.Detail
        }
        'SMB' {
            $r = Invoke-RepairCycle -Issue 'SMB server not enabled' -RootCause 'SMB features disabled' `
                -RepairAction { Set-SmbConfiguration -Smb1Enabled -Smb2Enabled } `
                -ValidateAction { $c = Get-SmbServerConfiguration -ErrorAction SilentlyContinue; return ($c -and $c.ServerEnabled) }
            $layerResult.Success = ($r.RepairSuccess -and $r.ValidateSuccess)
            $layerResult.Detail = $r.Detail
        }
        'IPP' {
            $r = Invoke-RepairCycle -Issue 'IPP printing not available' -RootCause 'IPP features not installed' `
                -RepairAction { Install-IPPServer -Force } `
                -ValidateAction { $s = Get-IPPStatus -ErrorAction SilentlyContinue; return ($s -and $s.IPPUrls.Count -gt 0) }
            $layerResult.Success = ($r.RepairSuccess -and $r.ValidateSuccess)
            $layerResult.Detail = $r.Detail
        }
        'Share' {
            $target = if ($PrinterName) { $PrinterName } else {
                $p = Get-Printer -ErrorAction SilentlyContinue | Where-Object { $_.Shared } | Select-Object -First 1
                if (-not $p) { $p = Get-Printer -ErrorAction SilentlyContinue | Select-Object -First 1 }
                if ($p) { $p.Name } else { '' }
            }
            if (-not $target) { $layerResult.Detail = 'No printer available to share'; return $layerResult }
            $r = Invoke-RepairCycle -Issue "Printer $target not shared" -RootCause 'Sharing not enabled' `
                -RepairAction {
                    $sn = if ($ShareName) { $ShareName } else { $target -replace '[^a-zA-Z0-9_-]', '_' }
                    Enable-PrinterSharing -PrinterName $target -ShareName $sn
                } `
                -ValidateAction {
                    $p = Get-Printer -Name $target -ErrorAction SilentlyContinue
                    return ($p -and $p.Shared)
                }
            $layerResult.Success = ($r.RepairSuccess -and $r.ValidateSuccess)
            $layerResult.Detail = $r.Detail
        }
        'Registry' {
            $r = Invoke-RepairCycle -Issue 'Print registry not optimized' -RootCause 'Registry values incorrect' `
                -RepairAction {
                    $path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Print'
                    if (-not (Test-Path -Path $path)) { $null = New-Item -Path $path -Force -ErrorAction SilentlyContinue }
                    Set-ItemProperty -Path $path -Name 'RpcAuthnLevelPrivacyEnabled' -Value 0 -Type DWord -ErrorAction SilentlyContinue
                    Set-ItemProperty -Path $path -Name 'DisableHTTPPrinting' -Value 0 -Type DWord -ErrorAction SilentlyContinue
                } `
                -ValidateAction {
                    $v = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Print' -Name 'RpcAuthnLevelPrivacyEnabled' -ErrorAction SilentlyContinue
                    return ($null -eq $v -or $v.RpcAuthnLevelPrivacyEnabled -eq 0)
                }
            $layerResult.Success = ($r.RepairSuccess -and $r.ValidateSuccess)
            $layerResult.Detail = $r.Detail
        }
        'Spooler' {
            $r = Invoke-RepairCycle -Issue 'Print spooler unhealthy' -RootCause 'Spooler stopped or queue stuck' `
                -RepairAction {
                    Stop-Service -Name Spooler -Force -ErrorAction SilentlyContinue
                    Start-Sleep -Milliseconds 1000
                    if (Test-Path -Path "$env:windir\System32\spool\PRINTERS") {
                        Remove-Item -Path "$env:windir\System32\spool\PRINTERS\*" -Force -ErrorAction SilentlyContinue
                    }
                    Start-Sleep -Milliseconds 500
                    Start-Service -Name Spooler -ErrorAction SilentlyContinue
                    Start-Sleep -Milliseconds 1500
                } `
                -ValidateAction { $s = Get-Service -Name Spooler -ErrorAction SilentlyContinue; return ($s -and $s.Status -eq 'Running') }
            $layerResult.Success = ($r.RepairSuccess -and $r.ValidateSuccess)
            $layerResult.Detail = $r.Detail
        }
        'TestPage' {
            $target = if ($PrinterName) { $PrinterName } else {
                $p = Get-Printer -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($p) { $p.Name } else { '' }
            }
            if (-not $target) { $layerResult.Detail = 'No printer to set as default'; return $layerResult }
            try {
                $null = Set-DefaultPrinter -PrinterName $target -ErrorAction Stop
                $layerResult.Success = $true
            } catch {
                $layerResult.Detail = $_.Exception.Message
            }
        }
        default {
            $layerResult.Detail = "Layer '$Layer' is not auto-repairable (requires user action)"
        }
    }

    Write-TransactionLog -Category Repair -Message "Layer '$Layer' -> $(if ($layerResult.Success) { 'OK' } else { 'FAIL' })" -Data $layerResult
    return $layerResult
}

function Invoke-ZTConfigure {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PrinterName,

        [Parameter(Mandatory = $false)]
        [string]$ShareName
    )

    $outcomes = [System.Collections.ArrayList]::new()

    foreach ($layer in @('Services', 'Firewall', 'Network', 'SMB', 'IPP', 'Share', 'Registry')) {
        $r = Invoke-ZTLayerRepair -Layer $layer -PrinterName $PrinterName -ShareName $ShareName
        $null = $outcomes.Add($r)
        if ($r.Success) {
            Write-TransactionLog -Category Change -Message "Configured layer: $layer" -Data $r
        } else {
            Write-TransactionLog -Category Change -Message "Layer $layer needs attention: $($r.Detail)" -Data $r
        }
    }

    [PSCustomObject]@{
        PrinterName = $PrinterName
        Outcomes    = @($outcomes)
        AllOk       = (@($outcomes | Where-Object { -not $_.Success }).Count -eq 0)
    }
}

function Invoke-ZTValidate {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$PrinterName
    )

    $validation = Invoke-EndToEndValidation -PrinterName $PrinterName
    Write-TransactionLog -Category Validation -Message "Score=$($validation.OverallScore)% Fail=$($validation.FailCount)" -Data $validation
    return $validation
}

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

function Start-ZeroTouchDeployment {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$PrinterName,

        [Parameter(Mandatory = $false)]
        [string]$ShareName,

        [Parameter(Mandatory = $false)]
        [switch]$SkipValidation
    )

    Assert-Elevated

    if (-not (Get-Command -Name Get-LogFilePath -ErrorAction SilentlyContinue) -or -not (Test-Path (Get-LogFilePath).Path)) {
        Initialize-Logging -ErrorAction SilentlyContinue
    }

    $txId = Start-DeploymentTransaction
    Start-OrchestrationTransaction
    $deployment = [PSCustomObject]@{
        Success            = $false
        TransactionId      = $txId
        PrinterName        = ''
        ShareName          = $ShareName
        Detected           = $null
        Analyzed           = $null
        Backup             = $null
        Configuration      = $null
        Validation         = $null
        Health             = $null
        RollbackPerformed  = $false
        Errors             = @()
    }
    $bag = [PSCustomObject]@{ Validation = $null }

    try {
        Write-Log -Message 'ZERO-TOUCH DEPLOYMENT STARTED (orchestrated)' -Level 'INFO'

        $deployment.Detected = Invoke-ZTDetect -PrinterName $PrinterName
        if (-not $deployment.Detected.Printer) {
            throw 'No USB printer detected. Connect a USB printer and retry.'
        }
        $deployment.PrinterName = $deployment.Detected.Printer.PrinterName
        if (-not $ShareName) { $deployment.ShareName = $deployment.PrinterName -replace '[^a-zA-Z0-9_-]', '_' }
        $printer = $deployment.PrinterName
        $share = $deployment.ShareName
        Write-TransactionLog -Category Operation -Message "Detected printer: $printer" -Data $deployment.Detected.Printer

        $deployment.Analyzed = Invoke-ZTAnalyze -PrinterName $printer
        $deployment.Backup = Invoke-ZTBackup -PrinterName $printer
        $desired = Get-DesiredState

        # Build the dependency graph (DAG) for the deployment.
        $tasks = [System.Collections.ArrayList]::new()

        $null = $tasks.Add((New-OrchestrationTask -Name 'DetectPrinter' -Description 'Detect connected USB printer' -Category 'Detection' -Subsystem 'Printer' -RequiredElevation $false `
            -Execute { } `
            -Validate { (Invoke-ConfigurationProvider -Provider 'Printer' -Phase Validate -PrinterName $printer).Detected }))

        $null = $tasks.Add((New-OrchestrationTask -Name 'DetectDriver' -Description 'Detect printer driver' -Category 'Detection' -Subsystem 'Driver' -RequiredElevation $false -Dependencies @('DetectPrinter') `
            -Execute { } `
            -Validate { (Invoke-ConfigurationProvider -Provider 'Driver' -Phase Validate -PrinterName $printer -DesiredState $desired).Found }))

        $null = $tasks.Add((New-OrchestrationTask -Name 'ConfigureServices' -Description 'Configure required Windows services' -Category 'Configuration' -Subsystem 'Services' -RequiredElevation $true -Dependencies @('DetectPrinter') -RetryPolicy @{ MaxAttempts = 2; DelayMs = 500 } `
            -Execute { Invoke-ConfigurationProvider -Provider 'Service' -Phase ApplyChanges -DesiredState $desired -PrinterName $printer -ShareName $share } `
            -Validate { Invoke-ConfigurationProvider -Provider 'Service' -Phase Validate -DesiredState $desired -PrinterName $printer -ShareName $share }))

        $null = $tasks.Add((New-OrchestrationTask -Name 'ConfigureRegistry' -Description 'Configure print registry values' -Category 'Configuration' -Subsystem 'Registry' -RequiredElevation $true -Dependencies @('ConfigureServices') -RetryPolicy @{ MaxAttempts = 2; DelayMs = 250 } `
            -Execute { Invoke-ConfigurationProvider -Provider 'Registry' -Phase ApplyChanges -DesiredState $desired -PrinterName $printer -ShareName $share } `
            -Validate { Invoke-ConfigurationProvider -Provider 'Registry' -Phase Validate -DesiredState $desired -PrinterName $printer -ShareName $share }))

        $null = $tasks.Add((New-OrchestrationTask -Name 'ConfigureFirewall' -Description 'Enable File/Printer Sharing and IPP firewall rules' -Category 'Configuration' -Subsystem 'Firewall' -RequiredElevation $true -Dependencies @('ConfigureServices') -RetryPolicy @{ MaxAttempts = 2; DelayMs = 250 } `
            -Execute { Invoke-ConfigurationProvider -Provider 'Firewall' -Phase ApplyChanges -DesiredState $desired -PrinterName $printer -ShareName $share } `
            -Validate { Invoke-ConfigurationProvider -Provider 'Firewall' -Phase Validate -DesiredState $desired -PrinterName $printer -ShareName $share }))

        $null = $tasks.Add((New-OrchestrationTask -Name 'ConfigureNetwork' -Description 'Set network profile to Private' -Category 'Configuration' -Subsystem 'Network' -RequiredElevation $true -Dependencies @('ConfigureServices') -RetryPolicy @{ MaxAttempts = 2; DelayMs = 250 } `
            -Execute { Invoke-ConfigurationProvider -Provider 'Network' -Phase ApplyChanges -DesiredState $desired -PrinterName $printer -ShareName $share } `
            -Validate { Invoke-ConfigurationProvider -Provider 'Network' -Phase Validate -DesiredState $desired -PrinterName $printer -ShareName $share }))

        $null = $tasks.Add((New-OrchestrationTask -Name 'SharePrinter' -Description 'Share the printer' -Category 'Sharing' -Subsystem 'Sharing' -RequiredElevation $true -Dependencies @('DetectPrinter', 'ConfigureServices') -RetryPolicy @{ MaxAttempts = 2; DelayMs = 250 } `
            -Execute { Invoke-ConfigurationProvider -Provider 'Sharing' -Phase ApplyChanges -DesiredState $desired -PrinterName $printer -ShareName $share } `
            -Validate { Invoke-ConfigurationProvider -Provider 'Sharing' -Phase Validate -DesiredState $desired -PrinterName $printer -ShareName $share }))

        $null = $tasks.Add((New-OrchestrationTask -Name 'EnableIPP' -Description 'Install and enable IPP' -Category 'Configuration' -Subsystem 'IPP' -RequiredElevation $true -Dependencies @('ConfigureFirewall', 'ConfigureNetwork') -RetryPolicy @{ MaxAttempts = 2; DelayMs = 250 } `
            -Execute { Invoke-ConfigurationProvider -Provider 'IPP' -Phase ApplyChanges -DesiredState $desired -PrinterName $printer -ShareName $share } `
            -Validate { Invoke-ConfigurationProvider -Provider 'IPP' -Phase Validate -DesiredState $desired -PrinterName $printer -ShareName $share }))

        $null = $tasks.Add((New-OrchestrationTask -Name         'ValidateConnectivity' -Description 'End-to-end validation' -Category 'Validation' -Subsystem 'Validation' -RequiredElevation $true -Dependencies @('SharePrinter', 'EnableIPP') `
            -Execute { $bag.Validation = Invoke-EndToEndValidation -PrinterName $printer } `
            -Validate { if ($SkipValidation) { return $true } return ($bag.Validation -and $bag.Validation.AllPassed) }))

        $null = $tasks.Add((New-OrchestrationTask -Name 'GenerateReport' -Description 'Generate diagnostic bundle' -Category 'Reporting' -Subsystem 'Reporting' -RequiredElevation $false -Dependencies @('ValidateConnectivity') -CanSkip $true -IsCritical $false `
            -Execute { New-DiagnosticBundle -ErrorAction SilentlyContinue } `
            -Validate { $true }))

        $orchestration = Invoke-Orchestrator -Tasks @($tasks)
        $deployment.Configuration = $orchestration

        if (-not $SkipValidation) {
            $deployment.Validation = $bag.Validation
            if (-not ($validation -and $validation.AllPassed)) {
                Write-Log -Message 'Validation failed - orchestrator recovery attempted' -Level 'WARN'
                if ($deployment.Backup.Created) {
                    $rb = Invoke-Rollback -RollbackPath $deployment.Backup.RollbackPath -ErrorAction SilentlyContinue
                    $deployment.RollbackPerformed = $rb.Success
                    Write-TransactionLog -Category Rollback -Message 'Rolled back deployment to pre-deployment state' -Data $rb
                }
            }
        }

        $deployment.Health = Get-DeploymentHealth -PrinterName $printer
        $rolledBack = @($orchestration.Tasks | Where-Object { $_.Status -eq 'RolledBack' }).Count -gt 0
        $deployment.RollbackPerformed = $deployment.RollbackPerformed -or $rolledBack
        $deployment.Success = ($SkipValidation -or ($validation -and $validation.AllPassed)) -and $deployment.Errors.Count -eq 0
    } catch {
        $deployment.Errors += $_.Exception.Message
        Write-TransactionLog -Category Operation -Message "Deployment error: $($_.Exception.Message)" -Data $_.Exception.Message
        if ($deployment.Backup -and $deployment.Backup.Created) {
            try {
                $rb = Invoke-Rollback -RollbackPath $deployment.Backup.RollbackPath
                $deployment.RollbackPerformed = $rb.Success
            } catch {}
        }
    }

    Complete-DeploymentTransaction -Success $deployment.Success
    Write-Log -Message "ZERO-TOUCH DEPLOYMENT FINISHED (Success=$($deployment.Success))" -Level 'INFO'
    return $deployment
}

function Invoke-GuidedRecovery {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$PrinterName
    )

    $before = Invoke-EndToEndValidation -PrinterName $PrinterName
    $failedLayers = @($before.Checks | Where-Object { $_.Status -eq 'FAIL' } | Select-Object -ExpandProperty Component -Unique)

    $layerMap = @{
        'Printer' = @()
        'Driver'  = @()
        'Queue'   = @('Spooler')
        'Port'    = @('Spooler')
        'Spooler' = @('Spooler')
        'Services' = @('Services')
        'Registry' = @('Registry')
        'Firewall' = @('Firewall')
        'Network'  = @('Network')
        'Sharing'  = @('Share')
        'SMB'      = @('SMB')
        'IPP'      = @('IPP')
        'Android'  = @('Firewall', 'Network')
        'TestPage' = @('TestPage')
    }

    $attempted = [System.Collections.ArrayList]::new()
    $repairedLayers = [System.Collections.ArrayList]::new()
    foreach ($failed in $failedLayers) {
        $layers = if ($layerMap.ContainsKey($failed)) { $layerMap[$failed] } else { @($failed) }
        if ($layers.Count -eq 0) {
            $null = $attempted.Add([PSCustomObject]@{ Component = $failed; Layer = '(user action)'; Success = $false; Detail = 'Requires user-provided driver or printer' })
            continue
        }
        foreach ($layer in $layers) {
            if ($layer -in $repairedLayers) { continue }
            $r = Invoke-ZTLayerRepair -Layer $layer -PrinterName $PrinterName
            $null = $repairedLayers.Add($layer)
            $null = $attempted.Add([PSCustomObject]@{ Component = $failed; Layer = $layer; Success = $r.Success; Detail = $r.Detail })
        }
    }

    $after = Invoke-EndToEndValidation -PrinterName $PrinterName
    Write-TransactionLog -Category Repair -Message "Guided recovery attempted $($failedLayers.Count) layer(s)" -Data @{ Before = $before.OverallScore; After = $after.OverallScore }

    [PSCustomObject]@{
        Attempted       = @($attempted)
        FailedBefore    = @($failedLayers)
        ValidationBefore = $before
        ValidationAfter  = $after
        Success          = $after.AllPassed
    }
}

function Get-DeploymentHealth {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$PrinterName
    )

    $validation = Invoke-EndToEndValidation -PrinterName $PrinterName
    $score = $validation.OverallScore
    $status = if ($score -ge 95) { 'HEALTHY' } elseif ($score -ge 80) { 'DEGRADED' } else { 'CRITICAL' }
    $color = if ($score -ge 95) { 'Green' } elseif ($score -ge 80) { 'Yellow' } else { 'Red' }

    [PSCustomObject]@{
        Score            = $score
        Status           = $status
        HealthColor      = $color
        PassCount        = $validation.PassCount
        FailCount        = $validation.FailCount
        FailedComponents = @($validation.Checks | Where-Object { $_.Status -eq 'FAIL' } | ForEach-Object { $_.Component })
        Timestamp        = Get-Date
    }
}

function Get-ClientConnectionInfo {
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

    $shared = @(Get-Printer -ErrorAction SilentlyContinue | Where-Object { $_.Shared })
    if ($shared.Count -eq 0) { $shared = @(Get-Printer -ErrorAction SilentlyContinue | Select-Object -First 1) }

    $results = [System.Collections.ArrayList]::new()
    foreach ($p in $shared) {
        $shareName = if ($p.ShareName) { $p.ShareName } else { $p.Name -replace '[^a-zA-Z0-9_-]', '_' }
        $ipp = "ipp://$hostname/printers/$shareName"
        $smb = "\\$hostname\$shareName"
        $http = "http://$hostname`:631/printers/$shareName"

        $clients = @(
            [PSCustomObject]@{
                OS             = 'Windows'
                ConnectionString = $smb
                Hostname       = $hostname
                IPAddress      = ($ipv4 -join ', ')
                ShareName      = $shareName
                IPPUrl         = $ipp
                SMBPath        = $smb
                Prerequisites  = 'Windows 10/11. Add printer by browsing \\host\share or IPP URL.'
                QRContent      = $smb
            },
            [PSCustomObject]@{
                OS             = 'macOS'
                ConnectionString = $ipp
                Hostname       = $hostname
                IPAddress      = ($ipv4 -join ', ')
                ShareName      = $shareName
                IPPUrl         = $ipp
                SMBPath        = $smb
                Prerequisites  = 'System Settings > Printers & Scanners > Add > IPP/SMB. SMB requires enabled SMB client.'
                QRContent      = $ipp
            },
            [PSCustomObject]@{
                OS             = 'Android'
                ConnectionString = $ipp
                Hostname       = $hostname
                IPAddress      = ($ipv4 -join ', ')
                ShareName      = $shareName
                IPPUrl         = $ipp
                SMBPath        = $smb
                Prerequisites  = 'Mopria Print Service (built into Android 8+). Auto-discovers via mDNS or add IPP manually.'
                QRContent      = $ipp
            },
            [PSCustomObject]@{
                OS             = 'Linux'
                ConnectionString = $ipp
                Hostname       = $hostname
                IPAddress      = ($ipv4 -join ', ')
                ShareName      = $shareName
                IPPUrl         = $ipp
                SMBPath        = $smb
                Prerequisites  = 'CUPS. `lpadmin -p $shareName -E -v ipp://host/printers/$shareName` or add via CUPS web UI :631.'
                QRContent      = $ipp
            }
        )
        foreach ($c in $clients) { $null = $results.Add($c) }
    }

    if ($results.Count -eq 0) {
        $null = $results.Add([PSCustomObject]@{
            OS = '(none)'; ConnectionString = ''; Hostname = $hostname; IPAddress = ($ipv4 -join ', ')
            ShareName = ''; IPPUrl = ''; SMBPath = ''; Prerequisites = 'Share a printer first.'; QRContent = ''
        })
    }

    return ,@($results)
}

function Get-ZeroTouchDashboard {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$PrinterName
    )

    $warnings = [System.Collections.ArrayList]::new()
    $recommended = [System.Collections.ArrayList]::new()

    $printerStatus = $null
    try { $printerStatus = Get-PrinterStatus -ErrorAction SilentlyContinue } catch {}
    $driver = $null
    try { $driver = Get-DriverIntelligence -PrinterName $PrinterName -ErrorAction SilentlyContinue } catch {}
    $share = $null
    try { $share = Get-PrinterShareStatus -ErrorAction SilentlyContinue } catch {}
    $ipp = $null
    try { $ipp = Get-IPPStatus -ErrorAction SilentlyContinue } catch {}
    $smb = $null
    try { $smb = Get-SmbConfiguration -ErrorAction SilentlyContinue } catch {}
    $services = $null
    try { $services = Get-ServiceStatus -ErrorAction SilentlyContinue } catch {}
    $validation = $null
    try { $validation = Get-ValidationDashboard -ErrorAction SilentlyContinue } catch {}

    $networkProfile = 'Unknown'
    try {
        $profile = Get-NetConnectionProfile -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($profile) { $networkProfile = $profile.NetworkCategory.ToString() }
    } catch {}
    if ($networkProfile -ne 'Private') { $null = $warnings.Add('Network profile is not Private'); $null = $recommended.Add('Set network profile to Private for discovery.') }

    $firewallOk = $false
    try {
        $rules = Get-NetFirewallRule -DisplayName 'IPP Printer Port 631' -ErrorAction SilentlyContinue
        $firewallOk = ($rules -and $rules.Enabled)
    } catch {}
    if (-not $firewallOk) { $null = $warnings.Add('IPP firewall rule (631) not enabled'); $null = $recommended.Add('Enable File and Printer Sharing + IPP firewall rules.') }

    if (-not $ipp -or $ipp.IPPUrls.Count -eq 0) { $null = $recommended.Add('Run Start-ZeroTouchDeployment or enable IPP.') }

    [PSCustomObject]@{
        Title           = 'PrinterToolkit v8.2.0 Zero-Touch Dashboard'
        Timestamp       = Get-Date
        PrinterStatus   = $printerStatus
        Driver          = if ($driver) { [PSCustomObject]@{ Found = $driver.DriverFound; Name = $driver.DriverName; Signed = $driver.IsSigned; Type = $driver.DriverType } } else { $null }
        ShareStatus     = $share
        Ipp             = if ($ipp) { [PSCustomObject]@{ Installed = $ipp.IPPClientInstalled; Urls = $ipp.IPPUrls } } else { $null }
        Smb             = if ($smb) { [PSCustomObject]@{ ServerEnabled = $smb.ServerEnabled; Smb1 = $smb.Smb1Enabled; Smb2 = $smb.Smb2Enabled } } else { $null }
        NetworkProfile  = $networkProfile
        FirewallOk      = $firewallOk
        Services        = $services
        Validation      = $validation
        Warnings        = @($warnings)
        RecommendedActions = @($recommended)
    }
}

Export-ModuleMember -Function Start-ZeroTouchDeployment, Invoke-GuidedRecovery, Get-DeploymentHealth, Get-ClientConnectionInfo, Get-ZeroTouchDashboard, Start-DeploymentTransaction, Write-TransactionLog, Complete-DeploymentTransaction, Get-TransactionLogPath
