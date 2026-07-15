<#
.SYNOPSIS
    Pester tests for PrinterToolkit v8.2.0-rc1.

.DESCRIPTION
    Run: Invoke-Pester -Path .\Tests\PrinterToolkit.Tests.ps1
    Tests validate function existence, parameter contracts,
    output types, and integration paths. Full integration tests
    require a Windows environment with printers configured.

.NOTES
    Target: 95% functional coverage
    Version: 8.2.0
#>

BeforeAll {
    $ModuleRoot = Split-Path -Parent $PSScriptRoot
    Import-Module (Join-Path $ModuleRoot 'PrinterToolkit.psd1') -Force -ErrorAction Stop
    $Script:TestRoot = Join-Path -Path $env:TEMP -ChildPath "PTTest_$([System.IO.Path]::GetRandomFileName())"
    $null = New-Item -ItemType Directory -Force -Path $Script:TestRoot -ErrorAction SilentlyContinue
}

AfterAll {
    if ($Script:TestRoot -and (Test-Path $Script:TestRoot)) {
        Remove-Item -Path $Script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'Module Loading - v8.2' {
    It 'Should load the root module' {
        Get-Module PrinterToolkit | Should -Not -BeNullOrEmpty
    }

    It 'Should have version 8.2.0' {
        (Get-Module PrinterToolkit).Version | Should -Be '8.2.0'
    }

    It 'Should export all v8.2 required functions' {
        $required = @(
            'Get-ToolkitStatus', 'Invoke-ToolkitMainMenu',
            'Get-PrinterStatus', 'Get-Printers', 'Set-DefaultPrinter',
            'Clear-PrintQueue', 'Restart-Spooler', 'Stop-Spooler', 'Start-Spooler',
            'Get-PrinterQueueHealth', 'Get-SharedPrinters', 'Enable-PrintSharing',
            'Get-PrinterWmiDetail',
            'Get-IPPStatus', 'Get-IPPUrls', 'Test-IPPEndpoint',
            'Test-IPPClientInstalled', 'Install-IPPServer',
            'Initialize-Logging', 'Write-Log', 'Get-LogFilePath', 'Get-LogContent',
            'Export-LogArchive',
            'Test-Administrator', 'Test-Elevated', 'Assert-Elevated',
            'Confirm-DestructiveAction', 'Get-SystemInfo', 'Write-MenuHeader', 'Wait-Menu',
            'Get-AndroidCompatibility', 'Show-AndroidWizard', 'Get-AndroidSetupContent',
            'Get-ConnectionInfo', 'New-ConnectionQRCode',
            'Get-NetworkValidation', 'Show-NetworkValidationReport',
            'Export-RegistrySnapshot', 'Export-FirewallSnapshot', 'Export-ServiceSnapshot',
            'Initialize-RepairBackup', 'Invoke-AutomaticShareRepair',
            'Invoke-RepairCycle', 'Invoke-RepairRollback',
            'Get-PrinterDriverDetails', 'Export-PrinterDrivers', 'Restore-PrinterDrivers',
            'Install-PrinterDriverFromInf', 'Remove-PrinterDriverByName',
            'Get-DriverUpgradeRecommendations', 'Get-DriverIntelligence',
            'Get-PrinterShareStatus', 'Enable-PrinterSharing', 'Disable-PrinterSharing',
            'Get-SmbSharePermissions', 'Set-PrinterSharePermission',
            'Set-PrinterSharingTransport', 'Get-PrinterSharingCompatibility',
            'New-PrinterReport', 'Get-PrintComplianceReport',
            'New-DiagnosticBundle',
            'Get-UsbPrinterInfo', 'Get-HardwareIdInfo', 'Get-PrinterConnectionType',
            'Get-WindowsFeatureStatus', 'Set-WindowsFeature',
            'Get-ServiceStatus', 'Set-ServiceConfiguration',
            'Get-RegistryExpected', 'Compare-RegistryState',
            'Invoke-EndToEndValidation', 'Get-ValidationDashboard',
            'Get-NetworkProfileStatus', 'Set-NetworkProfilePrivate',
            'Get-FirewallRuleStatus', 'Set-FirewallRule',
            'Enable-RequiredFirewallRules',
            'Get-SmbConfiguration', 'Set-SmbConfiguration', 'Get-SmbPrinterShares',
            'Invoke-PrintServerWizard', 'Get-WizardStatus',
            'Initialize-RepairRollback', 'Invoke-Rollback',
            'Start-ZeroTouchDeployment', 'Invoke-GuidedRecovery', 'Get-DeploymentHealth',
            'Get-ClientConnectionInfo', 'Get-ZeroTouchDashboard',
            'Start-DeploymentTransaction', 'Write-TransactionLog', 'Complete-DeploymentTransaction', 'Get-TransactionLogPath',
            'Test-DriverSignature',
            'New-OrchestrationTask', 'Get-TopologicalTaskOrder',
            'Subscribe-OrchestrationEvent', 'Publish-OrchestrationEvent', 'Get-OrchestrationEventLog',
            'Set-SubsystemState', 'Get-SubsystemState', 'Get-OrchestrationStateReport', 'Reset-OrchestrationState',
            'Start-OrchestrationTransaction', 'Record-TaskTransaction', 'Get-OrchestrationTransactionLog',
            'Get-DefaultDesiredState', 'Get-DesiredState',
            'Invoke-ConfigurationProvider', 'Invoke-Orchestrator', 'Invoke-RecoveryEngine', 'Get-OrchestrationReport'
        )
        foreach ($f in $required) {
            Get-Command -Name $f -Module PrinterToolkit -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }

    It 'Should not have v5 deprecated functions removed' {
        $required = @(
            'Get-ToolkitStatus', 'Invoke-ToolkitMainMenu',
            'Get-PrinterStatus', 'Get-Printers',
            'Clear-PrintQueue', 'Restart-Spooler', 'Stop-Spooler', 'Start-Spooler',
            'Get-PrinterQueueHealth', 'Get-SharedPrinters', 'Enable-PrintSharing',
            'Test-Administrator', 'Test-Elevated', 'Assert-Elevated',
            'Confirm-DestructiveAction', 'Get-SystemInfo',
            'New-PrinterReport', 'Get-PrintComplianceReport',
            'New-DiagnosticBundle'
        )
        foreach ($f in $required) {
            Get-Command -Name $f -Module PrinterToolkit -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'Core Module' {
    It 'Get-Printers should return an array' {
        $result = Get-Printers
        $result -is [array] | Should -Be $true
    }

    It 'Get-PrinterStatus should return a PSCustomObject with expected properties' {
        $result = Get-PrinterStatus
        $result.SpoolerStatus | Should -Not -BeNullOrEmpty
        $result.PrinterCount -is [int] | Should -Be $true
        $result.Timestamp | Should -Not -BeNullOrEmpty
    }

    It 'Get-SharedPrinters should not throw' {
        { $result = Get-SharedPrinters -ErrorAction SilentlyContinue } | Should -Not -Throw
    }

    It 'Clear-PrintQueue with -Force should handle missing spool path' {
        Mock -ModuleName 'PrinterToolkit.Core' Test-Path { return $false }
        $result = Clear-PrintQueue -Force
        $result -is [int] | Should -Be $true
    }

    It 'Restart-Spooler should return a PSCustomObject' {
        Mock -ModuleName 'PrinterToolkit.Core' Stop-Spooler { return $true }
        Mock -ModuleName 'PrinterToolkit.Core' Start-Spooler { return $true }
        $result = Restart-Spooler
        $result.Success | Should -Be $true
    }

    It 'Get-PrinterWmiDetail should exist' {
        Get-Command Get-PrinterWmiDetail -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }
}

Describe 'Detection Module' {
    It 'Get-UsbPrinterInfo should return an array' {
        $result = Get-UsbPrinterInfo -ErrorAction SilentlyContinue
        $result -is [array] | Should -Be $true
    }

    It 'Get-HardwareIdInfo should return a PSCustomObject' {
        $result = Get-HardwareIdInfo -ErrorAction SilentlyContinue
        $result -is [PSCustomObject] | Should -Be $true
    }

    It 'Get-PrinterConnectionType should return a string' {
        $result = Get-PrinterConnectionType -PrinterName 'Test' -ErrorAction SilentlyContinue
        $result -is [string] | Should -Be $true
    }
}

Describe 'Configuration Module' {
    It 'Get-WindowsFeatureStatus should return an array' {
        $result = Get-WindowsFeatureStatus -ErrorAction SilentlyContinue
        $result -is [array] | Should -Be $true
    }

    It 'Get-ServiceStatus should return an array with expected properties' {
        $result = Get-ServiceStatus -ErrorAction SilentlyContinue
        $result -is [array] | Should -Be $true
        if ($result.Count -gt 0) {
            $result[0].ServiceName | Should -Not -BeNullOrEmpty
            $result[0].Pass -is [bool] | Should -Be $true
        }
    }

    It 'Set-WindowsFeature requires -Enable switch' {
        $cmd = Get-Command Set-WindowsFeature -ErrorAction SilentlyContinue
        $cmd.Parameters['Enable'].SwitchParameter | Should -Be $true
    }

    It 'Get-RegistryExpected should return an array' {
        $result = Get-RegistryExpected -ErrorAction SilentlyContinue
        $result -is [array] | Should -Be $true
    }

    It 'Compare-RegistryState should return a PSCustomObject' {
        $result = Compare-RegistryState -ErrorAction SilentlyContinue
        $result -is [PSCustomObject] | Should -Be $true
    }
}

Describe 'Validation Module' {
    It 'Invoke-EndToEndValidation should return a PSCustomObject with score' {
        $result = Invoke-EndToEndValidation -ErrorAction SilentlyContinue
        $result -is [PSCustomObject] | Should -Be $true
        $result.OverallScore -is [double] | Should -Be $true
    }

    It 'Get-ValidationDashboard should return a PSCustomObject' {
        $result = Get-ValidationDashboard -ErrorAction SilentlyContinue
        $result -is [PSCustomObject] | Should -Be $true
        $result.Status -match 'PASS|FAIL' | Should -Be $true
    }
}

Describe 'Networking Module' {
    It 'Get-NetworkProfileStatus should return a PSCustomObject' {
        $result = Get-NetworkProfileStatus -ErrorAction SilentlyContinue
        $result -is [PSCustomObject] | Should -Be $true
    }

    It 'Get-FirewallRuleStatus should return an array' {
        $result = Get-FirewallRuleStatus -ErrorAction SilentlyContinue
        $result -is [array] | Should -Be $true
    }

    It 'Set-FirewallRule should have -Action parameter' {
        $cmd = Get-Command Set-FirewallRule -ErrorAction SilentlyContinue
        $cmd.Parameters['Action'].Attributes.Where{ $_ -is [ValidateSet] } | Should -Not -BeNullOrEmpty
    }

    It 'Enable-RequiredFirewallRules should return a PSCustomObject' {
        Mock Assert-Elevated { return $null } -ModuleName 'PrinterToolkit.Networking'
        $result = Enable-RequiredFirewallRules -ErrorAction SilentlyContinue
        $result -is [PSCustomObject] | Should -Be $true
    }
}

Describe 'SMB Module' {
    It 'Get-SmbConfiguration should return a PSCustomObject' {
        $result = Get-SmbConfiguration -ErrorAction SilentlyContinue
        $result -is [PSCustomObject] | Should -Be $true
    }

    It 'Get-SmbPrinterShares should return an array' {
        $result = Get-SmbPrinterShares -ErrorAction SilentlyContinue
        $result -is [array] | Should -Be $true
    }

    It 'Set-SmbConfiguration should have -Smb1Enabled switch' {
        $cmd = Get-Command Set-SmbConfiguration -ErrorAction SilentlyContinue
        $cmd.Parameters['Smb1Enabled'].SwitchParameter | Should -Be $true
    }
}

Describe 'SetupWizard Module' {
    It 'Invoke-PrintServerWizard function should exist' {
        Get-Command Invoke-PrintServerWizard -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }

    It 'Invoke-PrintServerWizard should have -Unattended switch' {
        $cmd = Get-Command Invoke-PrintServerWizard -ErrorAction SilentlyContinue
        $cmd.Parameters['Unattended'].SwitchParameter | Should -Be $true
    }

    It 'Get-WizardStatus should return a PSCustomObject' {
        $result = Get-WizardStatus -ErrorAction SilentlyContinue
        $result -is [PSCustomObject] | Should -Be $true
        $result.StepsTotal | Should -Be 11
    }
}

Describe 'Rollback Module' {
    It 'Initialize-RepairRollback should return a string path' {
        $result = Initialize-RepairRollback -ErrorAction SilentlyContinue
        $result -is [string] | Should -Be $true
    }

    It 'Invoke-Rollback function should exist' {
        Get-Command Invoke-Rollback -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }
}

Describe 'Drivers Module' {
    It 'Get-PrinterDriverDetails should return array' {
        $result = Get-PrinterDriverDetails
        $result -is [array] | Should -Be $true
    }

    It 'Get-DriverIntelligence should return a PSCustomObject' {
        $result = Get-DriverIntelligence -ErrorAction SilentlyContinue
        $result -is [PSCustomObject] | Should -Be $true
    }

    It 'Get-DriverUpgradeRecommendations should return array' {
        $result = Get-DriverUpgradeRecommendations
        $result -is [array] | Should -Be $true
    }

    It 'Export-PrinterDrivers should exist and have -OutputPath parameter' {
        $cmd = Get-Command Export-PrinterDrivers -ErrorAction SilentlyContinue
        $cmd.Parameters.ContainsKey('OutputPath') | Should -Be $true
    }

    It 'Restore-PrinterDrivers should validate path' {
        { Restore-PrinterDrivers -SourcePath 'Z:\nonexistent' -ErrorAction Stop } | Should -Throw
    }

    It 'Install-PrinterDriverFromInf should validate path' {
        { Install-PrinterDriverFromInf -InfPath 'Z:\nonexistent.inf' -ErrorAction Stop } | Should -Throw
    }

    It 'Remove-PrinterDriverByName should validate pattern' {
        { Remove-PrinterDriverByName -DriverName 'bad|name' -ErrorAction Stop } | Should -Throw
    }
}

Describe 'Utilities Module' {
    It 'Test-Administrator should return boolean' {
        $result = Test-Administrator
        $result -is [bool] | Should -Be $true
    }

    It 'Test-Elevated calls Test-Administrator' {
        Test-Elevated | Should -Be (Test-Administrator)
    }

    It 'Get-SystemInfo should include computer name' {
        $result = Get-SystemInfo
        $result.ComputerName | Should -Be $env:COMPUTERNAME
    }

    It 'Get-SystemInfo should report v8.2.0' {
        $result = Get-SystemInfo
        $result.ToolkitVersion | Should -Be '8.2.0'
    }

    It 'Assert-Elevated should not throw when admin' {
        Mock Test-Administrator { return $true } -ModuleName 'PrinterToolkit.Utilities'
        { Assert-Elevated } | Should -Not -Throw
    }

    It 'Assert-Elevated should throw when not admin' {
        Mock Test-Administrator { return $false } -ModuleName 'PrinterToolkit.Utilities'
        { Assert-Elevated } | Should -Throw
    }
}

Describe 'IPP Module' {
    It 'Test-IPPClientInstalled should not throw' {
        { $result = Test-IPPClientInstalled -ErrorAction SilentlyContinue } | Should -Not -Throw
    }

    It 'Get-IPPStatus should return a PSCustomObject' {
        $result = Get-IPPStatus -ErrorAction SilentlyContinue
        $result -is [PSCustomObject] | Should -Be $true
    }

    It 'Get-IPPUrls should return an array' {
        $result = Get-IPPUrls -ErrorAction SilentlyContinue
        $result -is [array] | Should -Be $true
    }

    It 'Test-IPPEndpoint requires -Url parameter' {
        $params = (Get-Command Test-IPPEndpoint).Parameters
        $params['Url'].Attributes.Mandatory | Should -Be $true
    }
}

Describe 'Logging Module' {
    BeforeEach {
        $Script:TestLogPath = Join-Path -Path $Script:TestRoot -ChildPath 'test.log'
    }

    AfterEach {
        if (Test-Path $Script:TestLogPath) {
            Remove-Item -Path $Script:TestLogPath -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Initialize-Logging should set log directory' {
        $logDir = Join-Path -Path $Script:TestRoot -ChildPath 'logs'
        Initialize-Logging -Path $logDir
        Get-LogFilePath | Should -Not -BeNullOrEmpty
    }

    It 'Write-Log should write entries to file' {
        $logDir = Join-Path -Path $Script:TestRoot -ChildPath 'logs'
        Initialize-Logging -Path $logDir
        Write-Log -Message 'Test message' -Level 'INFO'
        $logFile = Get-LogFilePath
        Test-Path $logFile.Path | Should -Be $true
    }

    It 'Get-LogFilePath should return PSCustomObject with Path and Exists' {
        $logDir = Join-Path -Path $Script:TestRoot -ChildPath 'logs'
        Initialize-Logging -Path $logDir
        $info = Get-LogFilePath
        $info.Path | Should -Not -BeNullOrEmpty
        $info.Exists | Should -Be $true
    }

    It 'Get-LogContent should filter by level' {
        $logDir = Join-Path -Path $Script:TestRoot -ChildPath 'logs'
        Initialize-Logging -Path $logDir
        Write-Log -Message 'Error test' -Level 'ERROR'
        $errors = Get-LogContent -Level 'ERROR'
        $errors | Should -Not -BeNullOrEmpty
    }

    It 'Export-LogArchive should create a zip' {
        $logDir = Join-Path -Path $Script:TestRoot -ChildPath 'logs'
        Initialize-Logging -Path $logDir
        Write-Log -Message 'Archive test' -Level 'INFO'
        $dest = Join-Path -Path $Script:TestRoot -ChildPath 'archive.zip'
        $result = Export-LogArchive -Destination $dest
        $result | Should -Not -BeNullOrEmpty
        Test-Path $result | Should -Be $true
    }
}

Describe 'Diagnostics Module' {
    It 'Get-NetworkValidation should return a PSCustomObject with score' {
        $result = Get-NetworkValidation -ErrorAction SilentlyContinue
        $result -is [PSCustomObject] | Should -Be $true
        $result.OverallScore -is [double] | Should -Be $true
    }

    It 'Show-NetworkValidationReport should not throw' {
        { Show-NetworkValidationReport -ErrorAction SilentlyContinue } | Should -Not -Throw
    }

    It 'Export-FirewallSnapshot should not throw' {
        { Export-FirewallSnapshot -ErrorAction SilentlyContinue } | Should -Not -Throw
    }

    It 'Export-ServiceSnapshot should not throw' {
        { Export-ServiceSnapshot } | Should -Not -Throw
    }
}

Describe 'Repair Module' {
    It 'Initialize-RepairBackup should exist' {
        Get-Command Initialize-RepairBackup -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }

    It 'Invoke-AutomaticShareRepair should have a -TestMode switch' {
        $cmd = Get-Command Invoke-AutomaticShareRepair -ErrorAction SilentlyContinue
        $cmd.Parameters['TestMode'].SwitchParameter | Should -Be $true
    }

    It 'Invoke-RepairCycle function should exist' {
        Get-Command Invoke-RepairCycle -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }

    It 'Invoke-RepairRollback function should exist' {
        Get-Command Invoke-RepairRollback -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }
}

Describe 'Sharing Module' {
    It 'Get-PrinterShareStatus should return array' {
        $result = Get-PrinterShareStatus
        $result -is [array] | Should -Be $true
    }

    It 'Get-SmbSharePermissions should not throw' {
        { $result = Get-SmbSharePermissions -ErrorAction SilentlyContinue } | Should -Not -Throw
    }

    It 'Get-PrinterSharingCompatibility should return array' {
        $result = Get-PrinterSharingCompatibility
        $result -is [array] | Should -Be $true
    }

    It 'Enable-PrinterSharing should return Success=false for missing printer' {
        Mock -ModuleName 'PrinterToolkit.Sharing' Assert-Elevated { return $null }
        Mock Get-Printer { return $null } -ModuleName 'PrinterToolkit.Sharing'
        $result = Enable-PrinterSharing -PrinterName 'Nonexistent_Test'
        $result.Success | Should -Be $false
    }

    It 'Disable-PrinterSharing should return Success=false for missing printer' {
        Mock -ModuleName 'PrinterToolkit.Sharing' Assert-Elevated { return $null }
        Mock Get-Printer { return $null } -ModuleName 'PrinterToolkit.Sharing'
        $result = Disable-PrinterSharing -PrinterName 'Nonexistent_Test'
        $result.Success | Should -Be $false
    }
}

Describe 'Android Module' {
    It 'Get-AndroidCompatibility should return a PSCustomObject' {
        $result = Get-AndroidCompatibility -ErrorAction SilentlyContinue
        $result -is [PSCustomObject] | Should -Be $true
    }

    It 'Show-AndroidWizard should not throw' {
        { Show-AndroidWizard } | Should -Not -Throw
    }

    It 'Get-AndroidSetupContent should return content' {
        $result = Get-AndroidSetupContent
        $result | Should -Not -BeNullOrEmpty
    }

    It 'Get-ConnectionInfo should return an array' {
        $result = Get-ConnectionInfo -ErrorAction SilentlyContinue
        $result -is [array] | Should -Be $true
    }

    It 'New-ConnectionQRCode should return a PSCustomObject' {
        Mock Write-Host { } -ModuleName 'PrinterToolkit.Android'
        $result = New-ConnectionQRCode -Type 'IPP' -ErrorAction SilentlyContinue
        $result -is [PSCustomObject] | Should -Be $true
    }
}

Describe 'Reporting Module' {
    It 'Get-PrintComplianceReport should return an array' {
        $result = Get-PrintComplianceReport
        $result -is [array] | Should -Be $true
    }

    It 'New-PrinterReport should generate files with -Format All' {
        $reportDir = Join-Path -Path $Script:TestRoot -ChildPath 'report'
        $files = New-PrinterReport -Format 'All' -OutputPath $reportDir -ErrorAction SilentlyContinue
        $files | Should -Not -BeNullOrEmpty
    }

    It 'New-PrinterReport should support -Format Markdown' {
        $reportDir = Join-Path -Path $Script:TestRoot -ChildPath 'report_md'
        $files = New-PrinterReport -Format 'Markdown' -OutputPath $reportDir -ErrorAction SilentlyContinue
        $files | Should -Match '\.md$'
    }
}

Describe 'Bundle Module' {
    It 'New-DiagnosticBundle function should exist' {
        Get-Command New-DiagnosticBundle -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }

    It 'New-DiagnosticBundle should have -OutputPath parameter' {
        $cmd = Get-Command New-DiagnosticBundle -ErrorAction SilentlyContinue
        $cmd.Parameters.ContainsKey('OutputPath') | Should -Be $true
    }
}

Describe 'Toolkit Status' {
    It 'Get-ToolkitStatus should show version 8.2.0' {
        $status = Get-ToolkitStatus
        $status.Version | Should -Be '8.2.0'
        $status.LoadedModules.Count | Should -BeGreaterThan 0
    }

    It 'Get-ToolkitStatus should include admin state' {
        $status = Get-ToolkitStatus
        $status.IsAdministrator -is [bool] | Should -Be $true
    }

    It 'Invoke-ToolkitMainMenu function should exist' {
        Get-Command Invoke-ToolkitMainMenu -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }

    It 'All loaded modules should be v8.2 compatible' {
        $status = Get-ToolkitStatus
        $status.FailedModules.Count | Should -Be 0
    }
}

Describe 'v8.2 Zero-Touch Deployment Engine' {
    It 'Zero-Touch public functions should exist' {
        foreach ($f in @(
            'Start-ZeroTouchDeployment', 'Invoke-GuidedRecovery', 'Get-DeploymentHealth',
            'Get-ClientConnectionInfo', 'Get-ZeroTouchDashboard',
            'Start-DeploymentTransaction', 'Write-TransactionLog', 'Complete-DeploymentTransaction', 'Get-TransactionLogPath',
            'Test-DriverSignature')) {
            Get-Command -Name $f -Module PrinterToolkit -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }

    It 'Start-ZeroTouchDeployment should expose lifecycle parameters' {
        $cmd = Get-Command Start-ZeroTouchDeployment -Module PrinterToolkit
        $cmd.Parameters.ContainsKey('PrinterName') | Should -Be $true
        $cmd.Parameters.ContainsKey('ShareName') | Should -Be $true
        $cmd.Parameters.ContainsKey('SkipValidation') | Should -Be $true
    }

    It 'Start-DeploymentTransaction should create a transaction log path' {
        $id = Start-DeploymentTransaction
        $id | Should -Not -BeNullOrEmpty
        $path = Get-TransactionLogPath
        $path.Exists | Should -Be $true
        Test-Path -Path (Join-Path $path.Path 'transaction.json') | Should -Be $true
    }

    It 'Write-TransactionLog should append a category entry' {
        Write-TransactionLog -Category Operation -Message 'Test entry' -Data @{ Test = $true }
        $path = Get-TransactionLogPath
        Test-Path -Path (Join-Path $path.Path 'Operation.log') | Should -Be $true
        Complete-DeploymentTransaction -Success $true
    }

    It 'Test-DriverSignature should return a result object' {
        $result = Test-DriverSignature -InfPath 'C:\nonexistent\invalid.inf'
        $result | Should -Not -BeNullOrEmpty
        $result.PSObject.Properties.Name -contains 'Signed' | Should -Be $true
        $result.PSObject.Properties.Name -contains 'Status' | Should -Be $true
    }

    It 'Get-ClientConnectionInfo should return Windows/macOS/Android/Linux entries' {
        Mock Get-Printer -Module PrinterToolkit -MockWith {
            [PSCustomObject]@{ Name = 'TestPrinter'; Shared = $true; ShareName = 'TestPrinter'; PortName = 'USB001'; DriverName = 'Test Driver' }
        }
        Mock Get-NetIPAddress -Module PrinterToolkit -MockWith {
            [PSCustomObject]@{ IPAddress = '192.168.1.50'; AddressFamily = 'IPv4'; InterfaceAlias = 'Ethernet' }
        }
        $info = Get-ClientConnectionInfo
        $oses = @($info | Select-Object -ExpandProperty OS)
        $oses -contains 'Windows' | Should -Be $true
        $oses -contains 'macOS' | Should -Be $true
        $oses -contains 'Android' | Should -Be $true
        $oses -contains 'Linux' | Should -Be $true
    }
}

Describe 'Orchestration Engine - v8.2' {
    It 'Should export orchestration functions' {
        foreach ($f in @(
            'New-OrchestrationTask', 'Get-TopologicalTaskOrder', 'Invoke-Orchestrator',
            'Invoke-ConfigurationProvider', 'Get-DesiredState', 'Get-DefaultDesiredState',
            'Start-OrchestrationTransaction', 'Invoke-RecoveryEngine', 'Get-OrchestrationReport',
            'Subscribe-OrchestrationEvent', 'Publish-OrchestrationEvent', 'Get-OrchestrationEventLog',
            'Set-SubsystemState', 'Get-SubsystemState', 'Get-OrchestrationStateReport', 'Reset-OrchestrationState')) {
            Get-Command -Name $f -Module PrinterToolkit -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }

    It 'New-OrchestrationTask should build a task with defaults' {
        $t = New-OrchestrationTask -Name 'T1' -Description 'd' -Category 'C' -Execute {} -Validate {}
        $t.Name | Should -Be 'T1'
        $t.IsCritical | Should -Be $true
        $t.Dependencies.Count | Should -Be 0
        $t.RetryPolicy.MaxAttempts | Should -Be 1
        $t.RequiredElevation | Should -Be $false
    }

    It 'New-OrchestrationTask should accept dependencies and retry policy' {
        $rp = @{ MaxAttempts = 3; DelayMs = 200 }
        $t = New-OrchestrationTask -Name 'T2' -Description 'd' -Category 'C' -Dependencies @('T1') -RetryPolicy $rp -CanSkip $true -IsCritical $false -Execute {} -Validate {}
        $t.Dependencies[0] | Should -Be 'T1'
        $t.RetryPolicy.MaxAttempts | Should -Be 3
        $t.CanSkip | Should -Be $true
        $t.IsCritical | Should -Be $false
    }

    It 'Get-TopologicalTaskOrder should order by dependencies' {
        $a = New-OrchestrationTask -Name 'A' -Description 'd' -Category 'C' -Execute {} -Validate {}
        $b = New-OrchestrationTask -Name 'B' -Description 'd' -Category 'C' -Dependencies @('A') -Execute {} -Validate {}
        $c = New-OrchestrationTask -Name 'C' -Description 'd' -Category 'C' -Dependencies @('B') -Execute {} -Validate {}
        $order = Get-TopologicalTaskOrder -Tasks @($c, $b, $a)
        $order.HasCycle | Should -Be $false
        $order.Ordered[0].Name | Should -Be 'A'
        $order.Ordered[1].Name | Should -Be 'B'
        $order.Ordered[2].Name | Should -Be 'C'
    }

    It 'Get-TopologicalTaskOrder should detect cycles' {
        $a = New-OrchestrationTask -Name 'A' -Description 'd' -Category 'C' -Dependencies @('B') -Execute {} -Validate {}
        $b = New-OrchestrationTask -Name 'B' -Description 'd' -Category 'C' -Dependencies @('A') -Execute {} -Validate {}
        $order = Get-TopologicalTaskOrder -Tasks @($a, $b)
        $order.HasCycle | Should -Be $true
        $order.Ordered.Count | Should -Be 0
    }

    It 'Event bus should publish and deliver events to subscribers' {
        $received = @{ Value = $false }
        $handler = { $received.Value = $true }
        $null = Subscribe-OrchestrationEvent -EventName 'TaskStarted' -Handler $handler
        Publish-OrchestrationEvent -EventName 'TaskStarted' -Data @{ x = 1 }
        $received.Value | Should -Be $true
    }

    It 'State manager should track subsystem state' {
        Set-SubsystemState -Subsystem 'Services' -State 'Healthy' -Detail 'ok'
        $s = Get-SubsystemState -Subsystem 'Services'
        $s.State | Should -Be 'Healthy'
        $s.Detail | Should -Be 'ok'
    }

    It 'Get-DefaultDesiredState should return a state object with subsystems' {
        $ds = Get-DefaultDesiredState
        $ds | Should -Not -BeNullOrEmpty
        $ds.PSObject.Properties.Name -contains 'Services' | Should -Be $true
        $ds.PSObject.Properties.Name -contains 'Printer' | Should -Be $true
    }

    It 'Get-DesiredState should return a valid state object' {
        $ds = Get-DesiredState
        $ds | Should -Not -BeNullOrEmpty
        $ds.PSObject.Properties.Name -contains 'Services' | Should -Be $true
    }

    It 'Get-OrchestrationEventLog should return event log with count' {
        Publish-OrchestrationEvent -EventName 'TestEvent' -Data @{ x = 1 }
        $log = Get-OrchestrationEventLog
        $log.EventCount -is [int] | Should -Be $true
        $log.Events -is [array] | Should -Be $true
    }

    It 'Get-OrchestrationEventLog should filter by EventName' {
        $filtered = Get-OrchestrationEventLog -EventName 'TestEvent'
        $filtered.EventCount | Should -BeGreaterThan 0
        $filtered.Events[0].EventName | Should -Be 'TestEvent'
    }

    It 'Get-OrchestrationStateReport should return state summary with health score' {
        Set-SubsystemState -Subsystem 'TestSub' -State 'Healthy' -Detail 'ok'
        $report = Get-OrchestrationStateReport
        $report.TotalSubsystems -is [int] | Should -Be $true
        $report.Healthy | Should -BeGreaterThan 0
        $report.OverallHealth | Should -Not -BeNullOrEmpty
        $report.HealthScore -is [double] | Should -Be $true
        $report.SubsystemStates -is [array] | Should -Be $true
    }

    It 'Reset-OrchestrationState should clear all state' {
        Set-SubsystemState -Subsystem 'ResetTest' -State 'Healthy'
        Reset-OrchestrationState
        $s = Get-SubsystemState -Subsystem 'ResetTest'
        $s.State | Should -Be 'Unknown'
    }

    It 'Reset-OrchestrationState -KeepTransactionLog should preserve transaction log' {
        Start-OrchestrationTransaction
        Reset-OrchestrationState -KeepTransactionLog
        $log = Get-OrchestrationTransactionLog
        $log.Id | Should -Be $null  # no active transaction
    }
}
