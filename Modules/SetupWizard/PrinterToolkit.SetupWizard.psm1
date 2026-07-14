<#
.SYNOPSIS
    Print Server Configuration Wizard for PrinterToolkit v6.0.

.DESCRIPTION
    Interactive 11-step guided wizard that automates the complete
    process of transforming a USB-connected printer into a fully
    configured, validated, and network-accessible shared printer.

    Steps:
    1. Detect USB Printer
    2. Install Driver
    3. Configure Windows Features & Services
    4. Configure Registry
    5. Configure Firewall
    6. Configure Network
    7. Share Printer
    8. Enable IPP
    9. Enable SMB
    10. Validate Everything
    11. Print Test Page & Generate Connection Info

.NOTES
    Module: PrinterToolkit.SetupWizard
    Author: PrinterToolkit Contributors
#>

$Script:WizardLog = [System.Collections.ArrayList]::new()
$Script:WizardRollbackPath = $null

function Invoke-PrintServerWizard {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$PrinterName,
        [Parameter(Mandatory = $false)]
        [switch]$Unattended
    )

    Assert-Elevated

    $Script:WizardLog = [System.Collections.ArrayList]::new()
    $errors = [System.Collections.ArrayList]::new()
    $wizardSteps = 11
    $currentStep = 0

    $logStep = { param($Step, $Action, $Status, $Detail)
        $null = $Script:WizardLog.Add([PSCustomObject]@{
            Step    = $Step
            Action  = $Action
            Status  = $Status
            Detail  = $Detail
            Time    = Get-Date -Format 'HH:mm:ss'
        })
    }

    function Write-WizardStep {
        param($Step, $Total, $Title)
        Write-Host ""
        Write-Host "  [$Step/$Total] $Title" -ForegroundColor White
        Write-Host "  $(('=' * 60))" -ForegroundColor DarkGray
    }

    function Write-WizardResult {
        param($Success, $Message)
        $icon = if ($Success) { '[OK]' } else { '[FAIL]' }
        $color = if ($Success) { 'Green' } else { 'Red' }
        Write-Host "  $icon $Message" -ForegroundColor $color
    }

    Write-Host ''
    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host '    PRINTERTOOLKIT PRINT SERVER WIZARD' -ForegroundColor White
    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host ''

    if (-not $Unattended) {
        $confirm = Read-Host 'This wizard will configure your system as a print server. Continue? (Y/N)'
        if ($confirm -ne 'Y' -and $confirm -ne 'y') {
            Write-Host 'Wizard cancelled.' -ForegroundColor Yellow
            return [PSCustomObject]@{ Success = $false; Cancelled = $true; Log = @($Script:WizardLog) }
        }
    }

    $rollbackPath = Initialize-RepairRollback
    $Script:WizardRollbackPath = $rollbackPath
    &$logStep 0 'Initialize' 'OK' "Rollback point: $rollbackPath"

    # Step 1: Detect USB Printer
    $currentStep++
    Write-WizardStep $currentStep $wizardSteps 'Detecting USB Printer'
    try {
        $usbPrinters = Get-UsbPrinterInfo
        if ($PrinterName) {
            $detectedPrinter = $usbPrinters | Where-Object { $_.PrinterName -eq $PrinterName } | Select-Object -First 1
        } else {
            $detectedPrinter = $usbPrinters | Select-Object -First 1
        }

        if ($detectedPrinter) {
            Write-WizardResult $true "Found: $($detectedPrinter.PrinterName) (VID=$($detectedPrinter.VID), PID=$($detectedPrinter.PID))"
            &$logStep $currentStep 'Detect Printer' 'OK' "$($detectedPrinter.PrinterName) VID=$($detectedPrinter.VID) PID=$($detectedPrinter.PID)"
        } else {
            Write-WizardResult $false 'No USB printer detected.'
            try {
                $allPrinters = Get-Printer -ErrorAction SilentlyContinue
                if ($allPrinters.Count -gt 0) {
                    $detectedPrinter = $allPrinters | Select-Object -First 1
                    Write-Host "         Using first available printer: $($detectedPrinter.Name)" -ForegroundColor Yellow
                    &$logStep $currentStep 'Detect Printer' 'WARN' "Using fallback: $($detectedPrinter.Name)"
                } else {
                    throw 'No printers detected at all.'
                }
            } catch {
                &$logStep $currentStep 'Detect Printer' 'FAIL' $_
                $null = $errors.Add("Step 1: $_")
                Write-WizardResult $false $_
                if (-not $Unattended) {
                    $continue = Read-Host 'Continue without printer? (y/N)'
                    if ($continue -ne 'y') { throw 'Wizard cancelled by user' }
                    $detectedPrinter = $null
                }
            }
        }
    } catch {
        &$logStep $currentStep 'Detect Printer' 'FAIL' $_
        $null = $errors.Add("Step 1: $_")
    }

    # Step 2: Install Driver
    $currentStep++
    Write-WizardStep $currentStep $wizardSteps 'Installing Printer Driver'
    try {
        if ($detectedPrinter) {
            $driverInfo = Get-DriverIntelligence -PrinterName $detectedPrinter.PrinterName
            if ($driverInfo.DriverFound) {
                Write-WizardResult $true "Driver found: $($driverInfo.DriverName) (Type $($driverInfo.DriverType))"
                &$logStep $currentStep 'Install Driver' 'OK' "$($driverInfo.DriverName) Type=$($driverInfo.DriverType)"
            } else {
                Write-WizardResult $false "No suitable driver found. Attempting Windows Update..."
                &$logStep $currentStep 'Install Driver' 'FAIL' 'No driver found'
                $null = $errors.Add('Step 2: No driver found')
            }
        } else {
            Write-WizardResult $true 'Skipped (no printer)'
            &$logStep $currentStep 'Install Driver' 'SKIP' 'No printer selected'
        }
    } catch {
        &$logStep $currentStep 'Install Driver' 'FAIL' $_
        $null = $errors.Add("Step 2: $_")
    }

    # Step 3: Configure Windows Features & Services
    $currentStep++
    Write-WizardStep $currentStep $wizardSteps 'Configuring Windows Features & Services'
    try {
        $features = @('Printing-PrintManagement-Console', 'Printing-InternetPrinting-Client')
        foreach ($feature in $features) {
            try {
                Set-WindowsFeature -FeatureName $feature -Enable
                &$logStep $currentStep "Feature: $feature" 'OK' 'Enabled'
            } catch {
                &$logStep $currentStep "Feature: $feature" 'WARN' $_
            }
        }

        $requiredSvcs = @('Spooler', 'LanmanServer', 'LanmanWorkstation', 'FDResPub', 'FDPhost')
        foreach ($svcName in $requiredSvcs) {
            try {
                Set-ServiceConfiguration -ServiceName $svcName -StartType Automatic -EnsureRunning
                &$logStep $currentStep "Service: $svcName" 'OK' 'Configured'
            } catch {
                &$logStep $currentStep "Service: $svcName" 'WARN' $_
            }
        }

        Write-WizardResult $true 'Features and services configured'
    } catch {
        &$logStep $currentStep 'Configure Features' 'FAIL' $_
        $null = $errors.Add("Step 3: $_")
        Write-WizardResult $false $_
    }

    # Step 4: Configure Registry
    $currentStep++
    Write-WizardStep $currentStep $wizardSteps 'Configuring Registry'
    try {
        $regPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Print'
        if (-not (Test-Path -Path $regPath)) {
            $null = New-Item -Path $regPath -Force -ErrorAction SilentlyContinue
        }

        $regSettings = @{
            'RpcAuthnLevelPrivacyEnabled' = 0
            'DisableHTTPPrinting'         = 0
        }

        foreach ($name in $regSettings.Keys) {
            $current = Get-ItemProperty -Path $regPath -Name $name -ErrorAction SilentlyContinue
            if (-not $current -or $current.$name -ne $regSettings[$name]) {
                Set-ItemProperty -Path $regPath -Name $name -Value $regSettings[$name] -Type DWord -ErrorAction SilentlyContinue
                &$logStep $currentStep "Registry: $name" 'OK' "Set to $($regSettings[$name])"
            } else {
                &$logStep $currentStep "Registry: $name" 'OK' 'Already correct'
            }
        }

        Write-WizardResult $true 'Registry configured'
    } catch {
        &$logStep $currentStep 'Configure Registry' 'FAIL' $_
        $null = $errors.Add("Step 4: $_")
        Write-WizardResult $false $_
    }

    # Step 5: Configure Firewall
    $currentStep++
    Write-WizardStep $currentStep $wizardSteps 'Configuring Firewall'
    try {
        $fwResult = Enable-RequiredFirewallRules
        if ($fwResult.AllSuccess) {
            Write-WizardResult $true 'Firewall rules enabled'
        } else {
            Write-WizardResult $false 'Some rules could not be enabled'
        }
        &$logStep $currentStep 'Firewall' 'OK' $fwResult.AllSuccess
    } catch {
        &$logStep $currentStep 'Configure Firewall' 'FAIL' $_
        $null = $errors.Add("Step 5: $_")
        Write-WizardResult $false $_
    }

    # Step 6: Configure Network
    $currentStep++
    Write-WizardStep $currentStep $wizardSteps 'Configuring Network'
    try {
        $netResult = Set-NetworkProfilePrivate
        if ($netResult.Success) {
            Write-WizardResult $true "Network profile: $($netResult.Detail)"
        } else {
            Write-WizardResult $false $netResult.Detail
        }
        &$logStep $currentStep 'Network' 'OK' "$($netResult.InterfaceName) -> $($netResult.Detail)"
    } catch {
        &$logStep $currentStep 'Configure Network' 'FAIL' $_
        $null = $errors.Add("Step 6: $_")
        Write-WizardResult $false $_
    }

    # Step 7: Share Printer
    $currentStep++
    Write-WizardStep $currentStep $wizardSteps 'Sharing Printer'
    try {
        if ($detectedPrinter) {
            $shareResult = Enable-PrinterSharing -PrinterName $detectedPrinter.PrinterName -ErrorAction SilentlyContinue
            if ($shareResult.Success) {
                $shareName = $detectedPrinter.PrinterName -replace '[^a-zA-Z0-9_-]', '_'
                Set-Printer -Name $detectedPrinter.PrinterName -Shared $true -ShareName $shareName -ErrorAction SilentlyContinue
                Write-WizardResult $true "Shared as: $shareName"
                &$logStep $currentStep 'Share Printer' 'OK' "ShareName=$shareName"
            } else {
                Write-WizardResult $false $shareResult.Error
                &$logStep $currentStep 'Share Printer' 'FAIL' $shareResult.Error
            }
        } else {
            Write-WizardResult $true 'Skipped (no printer)'
            &$logStep $currentStep 'Share Printer' 'SKIP' 'No printer'
        }
    } catch {
        &$logStep $currentStep 'Share Printer' 'FAIL' $_
        $null = $errors.Add("Step 7: $_")
        Write-WizardResult $false $_
    }

    # Step 8: Enable IPP
    $currentStep++
    Write-WizardStep $currentStep $wizardSteps 'Enabling IPP'
    try {
        $ippResult = Install-IPPServer
        if ($ippResult.Success) {
            Write-WizardResult $true 'IPP configured'
        } else {
            Write-WizardResult $false "IPP errors: $($ippResult.Errors -join '; ')"
        }
        &$logStep $currentStep 'IPP' 'OK' $ippResult.Success
    } catch {
        &$logStep $currentStep 'Enable IPP' 'FAIL' $_
        $null = $errors.Add("Step 8: $_")
        Write-WizardResult $false $_
    }

    # Step 9: Enable SMB
    $currentStep++
    Write-WizardStep $currentStep $wizardSteps 'Enabling SMB'
    try {
        $smbResult = Set-SmbConfiguration -Smb1Enabled -Smb2Enabled
        if ($smbResult.Success -or ($smbResult.Smb1Changed -or $smbResult.Smb2Changed)) {
            Write-WizardResult $true 'SMB configured'
        } else {
            Write-WizardResult $false 'SMB configuration had issues'
        }
        &$logStep $currentStep 'SMB' 'OK' "SMB1=$($smbResult.Smb1Changed) SMB2=$($smbResult.Smb2Changed)"
    } catch {
        &$logStep $currentStep 'Enable SMB' 'FAIL' $_
        $null = $errors.Add("Step 9: $_")
        Write-WizardResult $false $_
    }

    # Step 10: Validate Everything
    $currentStep++
    Write-WizardStep $currentStep $wizardSteps 'Validating Configuration'
    try {
        $validation = Invoke-EndToEndValidation -PrinterName $(if ($detectedPrinter) { $detectedPrinter.PrinterName })
        &$logStep $currentStep 'Validate' 'OK' "Score=$($validation.OverallScore)% Pass=$($validation.PassCount)/$($validation.TotalChecks)"
        Write-WizardResult $true "Score: $($validation.OverallScore)%"
    } catch {
        &$logStep $currentStep 'Validate' 'FAIL' $_
        $null = $errors.Add("Step 10: $_")
        Write-WizardResult $false $_
    }

    # Step 11: Print Test Page & Generate Connection Info
    $currentStep++
    Write-WizardStep $currentStep $wizardSteps 'Printing Test Page & Generating Connection Info'
    try {
        if ($detectedPrinter) {
            try {
                $tp = Get-CimInstance -ClassName Win32_Printer -Filter "Name = '$($detectedPrinter.PrinterName -replace "'", "''")'" -ErrorAction Stop
                $null = Invoke-CimMethod -InputObject $tp -MethodName PrintTestPage -ErrorAction Stop
                Write-WizardResult $true "Test page sent to $($detectedPrinter.PrinterName)"
                &$logStep $currentStep 'Test Page' 'OK' "Sent to $($detectedPrinter.PrinterName)"
            } catch {
                Write-WizardResult $false "Test page failed: $_"
                &$logStep $currentStep 'Test Page' 'FAIL' $_
                $null = $errors.Add("Step $currentStep : $_")
            }
        } else {
            Write-WizardResult $true 'No printer to test'
            &$logStep $currentStep 'Test Page' 'SKIP' ''
        }

        $connectionInfo = Get-ConnectionInfo
        Write-Host ''
        Write-Host '  Connection Information:' -ForegroundColor Yellow
        foreach ($info in $connectionInfo) {
            Write-Host "    Windows: $($info.WindowsPath)" -ForegroundColor Cyan
            Write-Host "    SMB:     $($info.SMBPath)" -ForegroundColor Gray
            Write-Host "    IPP:     $($info.IPPUrl)" -ForegroundColor Cyan
            Write-Host "    HTTP:    $($info.HTTPUrl)" -ForegroundColor Gray
        }

        &$logStep $currentStep 'Connection Info' 'OK' 'Generated'
    } catch {
        &$logStep $currentStep 'Test Page' 'FAIL' $_
        $null = $errors.Add("Step 11: $_")
        Write-WizardResult $false $_
    }

    $wizardSuccess = ($errors.Count -eq 0)

    Write-Host ''
    Write-Host '========================================' -ForegroundColor $(if ($wizardSuccess) { 'Green' } else { 'Yellow' })
    if ($wizardSuccess) {
        Write-Host '    PRINT SERVER WIZARD COMPLETED' -ForegroundColor Green
    } else {
        Write-Host "    WIZARD COMPLETED WITH $($errors.Count) ERROR(S)" -ForegroundColor Yellow
    }
    Write-Host '========================================' -ForegroundColor $(if ($wizardSuccess) { 'Green' } else { 'Yellow' })
    Write-Host ''

    if (-not $wizardSuccess -and -not $Unattended) {
        $rollbackChoice = Read-Host 'Rollback changes? (Y/N)'
        if ($rollbackChoice -eq 'Y' -or $rollbackChoice -eq 'y') {
            Invoke-Rollback -RollbackPath $rollbackPath
        }
    }

    [PSCustomObject]@{
        Success       = $wizardSuccess
        PrinterName   = if ($detectedPrinter) { $detectedPrinter.PrinterName } else { $null }
        ErrorCount    = $errors.Count
        Errors        = @($errors)
        Log           = @($Script:WizardLog)
        RollbackPath  = $rollbackPath
        Timestamp     = Get-Date
    }
}

function Get-WizardStatus {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    [PSCustomObject]@{
        WizardAvailable  = $true
        StepsTotal       = 11
        LastRunLog       = @($Script:WizardLog)
        HasRollbackPoint = ($null -ne $Script:WizardRollbackPath -and (Test-Path -Path $Script:WizardRollbackPath))
        RollbackPath     = $Script:WizardRollbackPath
    }
}

Export-ModuleMember -Function Invoke-PrintServerWizard, Get-WizardStatus
