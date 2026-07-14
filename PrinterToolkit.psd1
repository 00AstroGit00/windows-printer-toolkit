@{
    RootModule           = 'PrinterToolkit.psm1'
    ModuleVersion        = '5.0.1'
    GUID                 = 'e8c4a1d7-2b9f-4e3c-9a0d-6f8b1c5d7e3a'
    Author               = 'PrinterToolkit Contributors'
    CompanyName          = 'PrinterToolkit'
    Copyright            = '(c) 2024-2026 PrinterToolkit Contributors. MIT License.'
    Description          = 'Enterprise Windows printer troubleshooting, diagnostic, and management toolkit. Supports Type 3/4 drivers, IPP, SMB sharing, Android Mopria, WSD discovery, event log analysis, automatic repair, and multi-format reporting.'

    PowerShellHostName   = 'ConsoleHost'
    PowerShellHostVersion = '5.1'

    RequiredModules      = @()

    FunctionsToExport    = @(
        # Root
        'Get-ToolkitStatus', 'Invoke-ToolkitMainMenu',
        # Core
        'Get-PrinterStatus', 'Stop-Spooler', 'Start-Spooler', 'Clear-PrintQueue',
        'Restart-Spooler', 'Get-Printers', 'Set-DefaultPrinter',
        'Get-PrinterQueueHealth', 'Get-SharedPrinters', 'Enable-PrintSharing',
        # IPP
        'Get-IPPStatus', 'Get-IPPUrls', 'Test-IPPEndpoint', 'Install-IPPServer',
        'Test-IPPClientInstalled',
        # Logging
        'Initialize-Logging', 'Write-Log', 'Get-LogFilePath', 'Get-LogContent',
        'Export-LogArchive',
        # Utilities
        'Test-Administrator', 'Test-Elevated', 'Assert-Elevated',
        'Confirm-DestructiveAction', 'Get-SystemInfo', 'Write-MenuHeader', 'Wait-Menu',
        # Android
        'Get-AndroidCompatibility', 'Show-AndroidWizard', 'Get-AndroidSetupContent',
        # Diagnostics
        'Get-NetworkValidation', 'Show-NetworkValidationReport',
        'Export-RegistrySnapshot', 'Export-FirewallSnapshot', 'Export-ServiceSnapshot',
        # Repair
        'Initialize-RepairBackup', 'Invoke-AutomaticShareRepair',
        # Drivers
        'Get-PrinterDriverDetails', 'Export-PrinterDrivers', 'Restore-PrinterDrivers',
        'Install-PrinterDriverFromInf', 'Remove-PrinterDriverByName',
        'Get-DriverUpgradeRecommendations',
        # Sharing
        'Get-PrinterShareStatus', 'Enable-PrinterSharing', 'Disable-PrinterSharing',
        'Get-SmbSharePermissions', 'Set-PrinterSharePermission',
        'Set-PrinterSharingTransport', 'Get-PrinterSharingCompatibility',
        # Reporting
        'New-PrinterReport', 'Get-PrintComplianceReport',
        # Bundle
        'New-DiagnosticBundle'
    )

    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()

    PrivateData = @{
        PSData = @{
            Tags         = @('Printer', 'Print', 'Printing', 'Diagnostics', 'Windows', 'Troubleshooting', 'IPP', 'Mopria', 'Android')
            LicenseUri   = 'https://github.com/00AstroGit00/windows-printer-toolkit/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/00AstroGit00/windows-printer-toolkit'
            IconUri      = 'https://raw.githubusercontent.com/00AstroGit00/windows-printer-toolkit/main/.github/images/icon.png'
            ReleaseNotes = @'
## 5.0.1 - Adversarial Audit Remediation
- Independent adversarial audit: 21 findings identified, 17 remediated, 4 documented
- SHA-256 integrity verification in bootstrap installer
- Elevation gates on 9 destructive operations (spooler, repair, drivers, sharing, IPP)
- Pester test suite repaired: 47 deterministic tests with no false positives
- Version unified to 5.0.1 across all 30 source files
- Repository URLs corrected to 00AstroGit00/windows-printer-toolkit
- Documentation synchronized: README, CHANGELOG, CERTIFICATION, MIGRATION, SECURITY

## 5.0.0 - Enterprise Validation, Certification & Community Release
- Repository verification — full audit of all 55 exports, paths, references, and tests
- Security review — 12 findings remediated (3 critical, 4 high, 2 medium, 2 low)
- GitHub readiness — README, issue/PR templates, security policy, .gitignore/.gitattributes
- Release engineering — signed ZIP package with SHA-256 checksums
- Production certification — 93/100 readiness score (see CERTIFICATION.md)

## 4.1.0 - Production Hardening
- Production-quality error handling with structured results across all modules
- Comprehensive logging framework (file, console, rotating)
- Type 4 driver detection and migration recommendations with Get-DriverUpgradeRecommendations
- IPP status and endpoint validation with Get-IPPStatus, Test-IPPEndpoint
- Android Mopria compatibility analysis with Get-AndroidCompatibility
- Network validation with comprehensive service, firewall, and printer checks
- SMB share permission management
- 8-step automatic share repair with full backup/rollback
- HTML/JSON/CSV professional reporting with compliance checks
- Comprehensive diagnostic bundle (ZIP with all data)
- Driver export/restore with INF extraction
- Share permission management
- Transport switching (SMB vs IPP vs WSD)
'@
        }
    }
}
