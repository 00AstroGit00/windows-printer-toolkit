# API Stability Guide — PrinterToolkit v8.3 LTS

> **Status:** Frozen  
> **Last updated:** 2026-07-15  
> **Scope:** All exported functions in `PrinterToolkit.psd1` `FunctionsToExport`

## Stability Levels

| Level | Meaning | Change policy |
|-------|---------|---------------|
| **Stable** | Public contract — safe to depend on | Breaking changes require 2-major-version deprecation cycle and explicit justification |
| **Internal** | Not listed in `FunctionsToExport` | May change at any time |
| **Deprecated** | Scheduled for removal | Emit warning; remove after 2 major versions |

## Conventions

- All functions return `[PSCustomObject]` unless noted.
- All functions support `-ErrorAction SilentlyContinue` for non-terminating errors.
- Parameter validation uses `[ValidateNotNullOrEmpty()]`, `[ValidateSet()]`, `[ValidateRange()]` where applicable.
- Verb-Noun naming follows PowerShell Best Practices.

## Exported Functions by Module

### Core (`PrinterToolkit.Core.psm1`)

| Function | Output Type | Side Effects | Deprecated | Stability |
|----------|-------------|-------------|------------|-----------|
| `Get-PrinterStatus` | `[PSCustomObject]` | None (read-only) | No | Stable |
| `Get-Printers` | `[array]` | None (read-only) | No | Stable |
| `Set-DefaultPrinter` | `[PSCustomObject]` | Changes default printer | No | Stable |
| `Clear-PrintQueue` | `[int]` | Deletes spool files | No | Stable |
| `Restart-Spooler` | `[PSCustomObject]` | Stops/starts Spooler service | No | Stable |
| `Stop-Spooler` | `[bool]` | Stops Spooler service | No | Stable |
| `Start-Spooler` | `[bool]` | Starts Spooler service | No | Stable |
| `Get-SharedPrinters` | `[array]` | None (read-only) | No | Stable |
| `Enable-PrintSharing` | `[PSCustomObject]` | Enables Windows print sharing | No | Stable |
| `Get-PrinterQueueHealth` | `[PSCustomObject]` | None (read-only) | No | Stable |

### Detection (`PrinterToolkit.Detection.psm1`)

| Function | Output Type | Side Effects | Deprecated | Stability |
|----------|-------------|-------------|------------|-----------|
| `Get-UsbPrinterInfo` | `[array]` | None (read-only) | No | Stable |
| `Get-HardwareIdInfo` | `[PSCustomObject]` | None (read-only) | No | Stable |
| `Get-PrinterConnectionType` | `[string]` | None (read-only) | No | Stable |

### Configuration (`PrinterToolkit.Configuration.psm1`)

| Function | Output Type | Side Effects | Deprecated | Stability |
|----------|-------------|-------------|------------|-----------|
| `Get-WindowsFeatureStatus` | `[array]` | None (read-only) | No | Stable |
| `Set-WindowsFeature` | `[PSCustomObject]` | Installs/uninstalls Windows features | No | Stable |
| `Get-ServiceStatus` | `[array]` | None (read-only) | No | Stable |
| `Set-ServiceConfiguration` | `[PSCustomObject]` | Changes service start type/state | No | Stable |
| `Get-RegistryExpected` | `[array]` | None (read-only) | No | Stable |
| `Compare-RegistryState` | `[PSCustomObject]` | None (read-only) | No | Stable |

### Drivers (`PrinterToolkit.Drivers.psm1`)

| Function | Output Type | Side Effects | Deprecated | Stability |
|----------|-------------|-------------|------------|-----------|
| `Get-PrinterDriverDetails` | `[array]` | None (read-only) | No | Stable |
| `Export-PrinterDrivers` | `[array]` | Exports driver files to disk | No | Stable |
| `Restore-PrinterDrivers` | `[PSCustomObject]` | Installs drivers from backup | No | Stable |
| `Install-PrinterDriverFromInf` | `[PSCustomObject]` | Installs a printer driver | No | Stable |
| `Remove-PrinterDriverByName` | `[PSCustomObject]` | Removes a printer driver | No | Stable |
| `Get-DriverUpgradeRecommendations` | `[array]` | None (read-only) | No | Stable |
| `Get-DriverIntelligence` | `[PSCustomObject]` | None (read-only) | No | Stable |

### Networking (`PrinterToolkit.Networking.psm1`)

| Function | Output Type | Side Effects | Deprecated | Stability |
|----------|-------------|-------------|------------|-----------|
| `Get-NetworkProfileStatus` | `[PSCustomObject]` | None (read-only) | No | Stable |
| `Set-NetworkProfilePrivate` | `[PSCustomObject]` | Changes network profile category | No | Stable |
| `Get-FirewallRuleStatus` | `[array]` | None (read-only) | No | Stable |
| `Set-FirewallRule` | `[PSCustomObject]` | Enables/disables firewall rules | No | Stable |

### IPP (`PrinterToolkit.IPP.psm1`)

| Function | Output Type | Side Effects | Deprecated | Stability |
|----------|-------------|-------------|------------|-----------|
| `Get-IPPStatus` | `[PSCustomObject]` | None (read-only) | No | Stable |
| `Get-IPPUrls` | `[array]` | None (read-only) | No | Stable |
| `Test-IPPEndpoint` | `[PSCustomObject]` | Network request to IPP endpoint | No | Stable |
| `Install-IPPServer` | `[PSCustomObject]` | Installs IPP Print Server Windows feature | No | Stable |
| `Test-IPPClientInstalled` | `[PSCustomObject]` | None (read-only) | No | Stable |

### SMB (`PrinterToolkit.SMB.psm1`)

| Function | Output Type | Side Effects | Deprecated | Stability |
|----------|-------------|-------------|------------|-----------|
| `Get-SmbConfiguration` | `[PSCustomObject]` | None (read-only) | No | Stable |
| `Set-SmbConfiguration` | `[PSCustomObject]` | Enables/disables SMB 1.0/CIFS | No | Stable |

### Sharing (`PrinterToolkit.Sharing.psm1`)

| Function | Output Type | Side Effects | Deprecated | Stability |
|----------|-------------|-------------|------------|-----------|
| `Get-PrinterShareStatus` | `[array]` | None (read-only) | No | Stable |
| `Enable-PrinterSharing` | `[PSCustomObject]` | Shares a printer | No | Stable |
| `Disable-PrinterSharing` | `[PSCustomObject]` | Unshares a printer | No | Stable |
| `Get-SmbSharePermissions` | `[array]` | None (read-only) | No | Stable |
| `Set-PrinterSharePermission` | `[PSCustomObject]` | Changes share ACL | No | Stable |
| `Set-PrinterSharingTransport` | `[PSCustomObject]` | Configures sharing transport | No | Stable |
| `Get-PrinterSharingCompatibility` | `[array]` | None (read-only) | No | Stable |

### Android (`PrinterToolkit.Android.psm1`)

| Function | Output Type | Side Effects | Deprecated | Stability |
|----------|-------------|-------------|------------|-----------|
| `Get-AndroidCompatibility` | `[PSCustomObject]` | None (read-only) | No | Stable |
| `Show-AndroidWizard` | `[void]` | Writes to console | No | Stable |
| `Get-AndroidSetupContent` | `[string]` | None (read-only) | No | Stable |
| `Get-ConnectionInfo` | `[array]` | None (read-only) | No | Stable |
| `New-ConnectionQRCode` | `[PSCustomObject]` | Writes QR image to disk | No | Stable |

### Diagnostics (`PrinterToolkit.Diagnostics.psm1`)

| Function | Output Type | Side Effects | Deprecated | Stability |
|----------|-------------|-------------|------------|-----------|
| `Get-NetworkValidation` | `[PSCustomObject]` | None (read-only) | No | Stable |
| `Show-NetworkValidationReport` | `[void]` | Writes to console | No | Stable |
| `Export-RegistrySnapshot` | `[string]` | Writes registry export to disk | No | Stable |
| `Export-FirewallSnapshot` | `[string]` | Writes firewall export to disk | No | Stable |
| `Export-ServiceSnapshot` | `[string]` | Writes service export to disk | No | Stable |

### Repair (`PrinterToolkit.Repair.psm1`)

| Function | Output Type | Side Effects | Deprecated | Stability |
|----------|-------------|-------------|------------|-----------|
| `Initialize-RepairBackup` | `[string]` | Creates backup directory | No | Stable |
| `Invoke-AutomaticShareRepair` | `[PSCustomObject]` | Modifies sharing configuration | No | Stable |

### Rollback (`PrinterToolkit.Rollback.psm1`)

| Function | Output Type | Side Effects | Deprecated | Stability |
|----------|-------------|-------------|------------|-----------|
| `Initialize-RepairRollback` | `[string]` | Creates rollback checkpoint | No | Stable |
| `Invoke-Rollback` | `[PSCustomObject]` | Restores configuration from checkpoint | No | Stable |

### Validation (`PrinterToolkit.Validation.psm1`)

| Function | Output Type | Side Effects | Deprecated | Stability |
|----------|-------------|-------------|------------|-----------|
| `Invoke-EndToEndValidation` | `[PSCustomObject]` | None (read-only) | No | Stable |
| `Get-ValidationDashboard` | `[PSCustomObject]` | None (read-only) | No | Stable |

### SetupWizard (`PrinterToolkit.SetupWizard.psm1`)

| Function | Output Type | Side Effects | Deprecated | Stability |
|----------|-------------|-------------|------------|-----------|
| `Invoke-PrintServerWizard` | `[PSCustomObject]` | Full system modification | No | Stable |
| `Get-WizardStatus` | `[PSCustomObject]` | None (read-only) | No | Stable |

### Reporting (`PrinterToolkit.Reporting.psm1`)

| Function | Output Type | Side Effects | Deprecated | Stability |
|----------|-------------|-------------|------------|-----------|
| `New-PrinterReport` | `[array]` | Writes report files to disk | No | Stable |
| `Get-PrintComplianceReport` | `[array]` | None (read-only) | No | Stable |

### Logging (`PrinterToolkit.Logging.psm1`)

| Function | Output Type | Side Effects | Deprecated | Stability |
|----------|-------------|-------------|------------|-----------|
| `Initialize-Logging` | `[void]` | Creates log directory/file | No | Stable |
| `Write-Log` | `[void]` | Appends to log file + console | No | Stable |
| `Get-LogFilePath` | `[PSCustomObject]` | None (read-only) | No | Stable |
| `Get-LogContent` | `[array]` | None (read-only) | No | Stable |
| `Export-LogArchive` | `[string]` | Creates ZIP archive | No | Stable |

### Utilities (`PrinterToolkit.Utilities.psm1`)

| Function | Output Type | Side Effects | Deprecated | Stability |
|----------|-------------|-------------|------------|-----------|
| `Test-Administrator` | `[bool]` | None (read-only) | No | Stable |
| `Test-Elevated` | `[bool]` | None (read-only) | No | Stable |
| `Assert-Elevated` | `[void]` | Terminates if not admin | No | Stable |
| `Confirm-DestructiveAction` | `[bool]` | Prompts user | No | Stable |
| `Get-SystemInfo` | `[PSCustomObject]` | None (read-only) | No | Stable |
| `Write-MenuHeader` | `[void]` | Writes to console | No | Stable |
| `Wait-Menu` | `[string]` | Reads user input | No | Stable |
| `Get-ToolkitStatus` | `[PSCustomObject]` | None (read-only) | No | Stable |
| `Invoke-ToolkitMainMenu` | `[void]` | Interactive console menu | No | Stable |

### Bundle (`PrinterToolkit.Bundle.psm1`)

| Function | Output Type | Side Effects | Deprecated | Stability |
|----------|-------------|-------------|------------|-----------|
| `New-DiagnosticBundle` | `[string]` | Creates diagnostic ZIP on disk | No | Stable |

### ZeroTouch (`PrinterToolkit.ZeroTouch.psm1`)

| Function | Output Type | Side Effects | Deprecated | Stability |
|----------|-------------|-------------|------------|-----------|
| `Start-ZeroTouchDeployment` | `[PSCustomObject]` | Full system modification | No | Stable |
| `Invoke-GuidedRecovery` | `[PSCustomObject]` | Repairs deployment | No | Stable |
| `Get-DeploymentHealth` | `[PSCustomObject]` | None (read-only) | No | Stable |
| `Get-ClientConnectionInfo` | `[array]` | None (read-only) | No | Stable |
| `Get-ZeroTouchDashboard` | `[PSCustomObject]` | None (read-only) | No | Stable |
| `Start-DeploymentTransaction` | `[string]` | Creates transaction log | No | Stable |
| `Write-TransactionLog` | `[void]` | Writes to transaction log | No | Stable |
| `Complete-DeploymentTransaction` | `[void]` | Finalizes transaction | No | Stable |
| `Get-TransactionLogPath` | `[PSCustomObject]` | None (read-only) | No | Stable |
| `Test-DriverSignature` | `[PSCustomObject]` | None (read-only) | No | Stable |

### Orchestration (`PrinterToolkit.Orchestration.psm1`)

| Function | Output Type | Side Effects | Deprecated | Stability |
|----------|-------------|-------------|------------|-----------|
| `New-OrchestrationTask` | `[OrchestrationTask]` | None (in-memory) | No | Stable |
| `Get-TopologicalTaskOrder` | `[PSCustomObject]` | None (in-memory) | No | Stable |
| `Subscribe-OrchestrationEvent` | `[void]` | Modifies subscriber list | No | Stable |
| `Publish-OrchestrationEvent` | `[void]` | Invokes subscriber handlers | No | Stable |
| `Get-OrchestrationEventLog` | `[PSCustomObject]` | None (read-only) | No | Stable |
| `Set-SubsystemState` | `[void]` | Modifies in-memory state | No | Stable |
| `Get-SubsystemState` | `[PSCustomObject]` | None (read-only) | No | Stable |
| `Get-OrchestrationStateReport` | `[PSCustomObject]` | None (read-only) | No | Stable |
| `Reset-OrchestrationState` | `[void]` | Clears in-memory state | No | Stable |
| `Start-OrchestrationTransaction` | `[void]` | Creates in-memory transaction | No | Stable |
| `Record-TaskTransaction` | `[void]` | Appends to transaction log | No | Stable |
| `Get-OrchestrationTransactionLog` | `[PSCustomObject]` | None (read-only) | No | Stable |
| `Get-DefaultDesiredState` | `[PSCustomObject]` | None (read-only) | No | Stable |
| `Get-DesiredState` | `[PSCustomObject]` | None (read-only) | No | Stable |
| `Invoke-ConfigurationProvider` | `[PSObject]` | Modifies system configuration | No | Stable |
| `Invoke-Orchestrator` | `[PSCustomObject]` | Full system modification | No | Stable |
| `Invoke-RecoveryEngine` | `[PSCustomObject]` | Repairs failed subsystems | No | Stable |
| `Get-OrchestrationReport` | `[PSCustomObject]` | None (read-only) | No | Stable |

### Providers (`PrinterToolkit.Providers.psm1`)

| Function | Output Type | Side Effects | Deprecated | Stability |
|----------|-------------|-------------|------------|-----------|
| `New-ProviderResult` | `[PSCustomObject]` | None (in-memory) | No | Stable |
| `Enable-PrinterFirewallRules` | `[PSCustomObject]` | Enables firewall rules | No | Stable |
| `Set-DefaultPrinterNative` | `[PSCustomObject]` | Sets default printer via CIM | No | Stable |
| `Get-PrinterDriverStoreDetails` | `[PSCustomObject]` | None (read-only) | No | Stable |

## Return Type Contract Issues

| Issue | Affected Functions | Risk |
|-------|-------------------|------|
| `$false` returned on failure instead of typed result | `Invoke-ConfigurationProvider`, `Invoke-Orchestrator` (legacy paths) | Callers must check both `-eq $false` and `.Success` |
| Ad-hoc `[PSCustomObject]@{Success=$true}` without `New-ProviderResult` | All pre-v8.1 functions (12 modules) | No standard error code, no recoverability hint |
| `[array]` vs `[PSCustomObject]` ambiguity | `Get-Printers`, `Get-SharedPrinters`, `Get-SmbSharePermissions` | Callers must handle both |

## Deprecation Policy

1. Mark function with `[Obsolete("Use X instead")]` attribute + `-WarningAction` support.
2. Keep for 2 major versions (e.g., deprecated in v9, removed in v11).
3. Document migration path in release notes.
4. Never remove a function without a replacement unless it has zero known consumers.

All exported functions are now implemented. The three previously orphan functions (`Get-OrchestrationEventLog`, `Get-OrchestrationStateReport`, `Reset-OrchestrationState`) were implemented in the Orchestration module as part of the v8.2 Critical Debt Remediation.
