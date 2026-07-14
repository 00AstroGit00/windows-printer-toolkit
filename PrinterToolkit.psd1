@{
    RootModule           = 'PrinterToolkit.psm1'
    ModuleVersion        = '8.0.0'
    GUID                 = 'e8c4a1d7-2b9f-4e3c-9a0d-6f8b1c5d7e3a'
    Author               = 'PrinterToolkit Contributors'
    CompanyName          = 'PrinterToolkit'
    Copyright            = '(c) 2024-2026 PrinterToolkit Contributors. MIT License.'
    Description          = 'Automated Windows USB Printer Sharing & Print Server Deployment Platform. Detects USB printers, installs drivers, configures Windows features/services/firewall/registry, enables IPP/SMB sharing, validates end-to-end, and generates client connectivity information with QR codes.'

    PowerShellHostName   = 'ConsoleHost'
    PowerShellHostVersion = '5.1'

    RequiredModules      = @()

    NestedModules        = @(
        'Modules/Core/PrinterToolkit.Core.psm1',
        'Modules/Detection/PrinterToolkit.Detection.psm1',
        'Modules/Configuration/PrinterToolkit.Configuration.psm1',
        'Modules/Drivers/PrinterToolkit.Drivers.psm1',
        'Modules/Networking/PrinterToolkit.Networking.psm1',
        'Modules/IPP/PrinterToolkit.IPP.psm1',
        'Modules/SMB/PrinterToolkit.SMB.psm1',
        'Modules/Sharing/PrinterToolkit.Sharing.psm1',
        'Modules/Android/PrinterToolkit.Android.psm1',
        'Modules/Diagnostics/PrinterToolkit.Diagnostics.psm1',
        'Modules/Repair/PrinterToolkit.Repair.psm1',
        'Modules/Rollback/PrinterToolkit.Rollback.psm1',
        'Modules/Validation/PrinterToolkit.Validation.psm1',
        'Modules/SetupWizard/PrinterToolkit.SetupWizard.psm1',
        'Modules/Reporting/PrinterToolkit.Reporting.psm1',
        'Modules/Logging/PrinterToolkit.Logging.psm1',
        'Modules/Utilities/PrinterToolkit.Utilities.psm1',
        'Modules/Bundle/PrinterToolkit.Bundle.psm1',
        'Modules/ZeroTouch/PrinterToolkit.ZeroTouch.psm1'
        'Modules/Orchestration/PrinterToolkit.Orchestration.psm1'
    )

    FunctionsToExport    = @(
        'Get-ToolkitStatus', 'Invoke-ToolkitMainMenu',
        'Get-PrinterStatus', 'Stop-Spooler', 'Start-Spooler', 'Clear-PrintQueue',
        'Restart-Spooler', 'Get-Printers', 'Set-DefaultPrinter',
        'Get-PrinterQueueHealth', 'Get-SharedPrinters', 'Enable-PrintSharing',
        'Get-IPPStatus', 'Get-IPPUrls', 'Test-IPPEndpoint', 'Install-IPPServer',
        'Test-IPPClientInstalled',
        'Initialize-Logging', 'Write-Log', 'Get-LogFilePath', 'Get-LogContent',
        'Export-LogArchive',
        'Test-Administrator', 'Test-Elevated', 'Assert-Elevated',
        'Confirm-DestructiveAction', 'Get-SystemInfo', 'Write-MenuHeader', 'Wait-Menu',
        'Get-AndroidCompatibility', 'Show-AndroidWizard', 'Get-AndroidSetupContent',
        'Get-NetworkValidation', 'Show-NetworkValidationReport',
        'Export-RegistrySnapshot', 'Export-FirewallSnapshot', 'Export-ServiceSnapshot',
        'Initialize-RepairBackup', 'Invoke-AutomaticShareRepair',
        'Get-PrinterDriverDetails', 'Export-PrinterDrivers', 'Restore-PrinterDrivers',
        'Install-PrinterDriverFromInf', 'Remove-PrinterDriverByName',
        'Get-DriverUpgradeRecommendations', 'Get-DriverIntelligence',
        'Get-PrinterShareStatus', 'Enable-PrinterSharing', 'Disable-PrinterSharing',
        'Get-SmbSharePermissions', 'Set-PrinterSharePermission',
        'Set-PrinterSharingTransport', 'Get-PrinterSharingCompatibility',
        'New-PrinterReport', 'Get-PrintComplianceReport',
        'New-DiagnosticBundle',
        'Invoke-PrintServerWizard', 'Get-WizardStatus', 'Get-ValidationDashboard',
        'Get-SmbConfiguration', 'Set-SmbConfiguration',
        'Get-NetworkProfileStatus', 'Set-NetworkProfilePrivate',
        'Get-FirewallRuleStatus', 'Set-FirewallRule',
        'Get-WindowsFeatureStatus', 'Set-WindowsFeature',
        'Get-ServiceStatus', 'Set-ServiceConfiguration',
        'New-ConnectionQRCode', 'Get-ConnectionInfo',
        'Invoke-Rollback', 'Initialize-RepairRollback',
        'Get-HardwareIdInfo', 'Get-UsbPrinterInfo',
        'Get-RegistryExpected', 'Compare-RegistryState',
        'Invoke-EndToEndValidation',
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

    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()

    PrivateData = @{
        PSData = @{
            Tags         = @('Printer', 'Print', 'Printing', 'PrintServer', 'IPP', 'SMB', 'Mopria', 'Android', 'USB', 'Driver', 'Windows')
            LicenseUri   = 'https://github.com/00AstroGit00/windows-printer-toolkit/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/00AstroGit00/windows-printer-toolkit'
            IconUri      = 'https://raw.githubusercontent.com/00AstroGit00/windows-printer-toolkit/main/.github/images/icon.png'
            ReleaseNotes = @'
## 8.0.0 - Dependency-Aware Orchestration Engine
- Introduced v8 orchestration platform: all operations modeled as declarative Tasks with dependencies, prerequisites, retry, and rollback
- New DAG resolver (Get-TopologicalTaskOrder) with cycle detection for deterministic execution order
- New Event Bus for structured, subscribable deployment events
- New State Manager tracking subsystem health (Healthy/Warning/Failed/Unknown/Pending)
- New Transaction Engine recording per-task state transitions for audit and rollback
- New Desired-State model (Get-DefaultDesiredState/Get-DesiredState) with Configuration Providers (Service, Firewall, Network, Sharing, IPP, Registry, Driver, Printer)
- New Orchestrator (Invoke-Orchestrator) executing the dependency graph with skip/retry/rollback/recovery semantics
- New Recovery Engine (Invoke-RecoveryEngine) and consolidated reporting (Get-OrchestrationReport)
- Start-ZeroTouchDeployment refactored to build a deployment DAG and run through the orchestrator; public signature and return shape preserved

## 6.0.0 - Print Server Platform
- Complete transformation from Printer Repair Toolkit to Automated Windows Print Server Deployment Platform
- New Detection Engine: USB printer, VID/PID, Hardware IDs, Compatible IDs
- New Configuration Intelligence Engine: Windows Features, Services, Registry, Firewall, Network
- New Driver Intelligence Engine: Full driver detection with Windows Update/Driver Store/manufacturer fallback
- New Automatic Repair Engine: Issue → Root Cause → Backup → Repair → Validate → Rollback cycle
- New Print Server Wizard: 11-step guided setup (printer detection through validation)
- New Validation Dashboard: End-to-end PASS/FAIL with per-component status
- New Rollback Engine: Full configuration rollback on repair failure
- New QR Code generation for IPP URLs, setup guide, troubleshooting guide
- New Client Connectivity module: Windows SMB, IPP, HTTP connection strings
- SMB configuration management module
- Networking module with profile/firewall/feature management
- Enhanced module architecture with public/private separation
- 95%+ functional test coverage target
- Static analysis and Pester validation pipeline
- HTML/JSON/Markdown report generation
'@
        }
    }
}
