# Test Coverage Matrix — PrinterToolkit v8.3 LTS

> **Source:** `Tests/PrinterToolkit.Tests.ps1` (692 lines, 49+ tests)  
> **Generated:** 2026-07-15  
> **Legend:** ✅ = Covered, 🔶 = Partial, ❌ = None

---

## Coverage by Function

### Core Module (10 exported)

| Function | Unit | Integration | Negative | Regression | Status |
|----------|------|-------------|----------|------------|--------|
| `Get-PrinterStatus` | ❌ | ✅ (type shape) | ❌ | ❌ | 🔶 |
| `Get-Printers` | ❌ | ✅ (type shape) | ❌ | ❌ | 🔶 |
| `Set-DefaultPrinter` | ❌ | ❌ | ❌ | ❌ | ❌ |
| `Clear-PrintQueue` | ✅ (mock) | ❌ | ❌ | ❌ | 🔶 |
| `Restart-Spooler` | ✅ (mock) | ❌ | ❌ | ❌ | 🔶 |
| `Stop-Spooler` | ❌ | ❌ | ❌ | ❌ | ❌ |
| `Start-Spooler` | ❌ | ❌ | ❌ | ❌ | ❌ |
| `Get-SharedPrinters` | ❌ | ✅ (no-throw) | ❌ | ❌ | 🔶 |
| `Enable-PrintSharing` | ❌ | ❌ | ❌ | ❌ | ❌ |
| `Get-PrinterQueueHealth` | ❌ | ❌ | ❌ | ❌ | ❌ |

### Detection Module (3 exported)

| Function | Unit | Integration | Negative | Regression | Status |
|----------|------|-------------|----------|------------|--------|
| `Get-UsbPrinterInfo` | ❌ | ✅ (type shape) | ❌ | ❌ | 🔶 |
| `Get-HardwareIdInfo` | ❌ | ✅ (type shape) | ❌ | ❌ | 🔶 |
| `Get-PrinterConnectionType` | ❌ | ✅ (type shape) | ❌ | ❌ | 🔶 |

### Configuration Module (6 exported)

| Function | Unit | Integration | Negative | Regression | Status |
|----------|------|-------------|----------|------------|--------|
| `Get-WindowsFeatureStatus` | ❌ | ✅ (type shape) | ❌ | ❌ | 🔶 |
| `Set-WindowsFeature` | ❌ | ❌ | ✅ (switch check) | ❌ | 🔶 |
| `Get-ServiceStatus` | ❌ | ✅ (type shape) | ❌ | ❌ | 🔶 |
| `Set-ServiceConfiguration` | ❌ | ❌ | ❌ | ❌ | ❌ |
| `Get-RegistryExpected` | ❌ | ✅ (type shape) | ❌ | ❌ | 🔶 |
| `Compare-RegistryState` | ❌ | ✅ (type shape) | ❌ | ❌ | 🔶 |

### Drivers Module (7 exported)

| Function | Unit | Integration | Negative | Regression | Status |
|----------|------|-------------|----------|------------|--------|
| `Get-PrinterDriverDetails` | ❌ | ✅ (type shape) | ❌ | ❌ | 🔶 |
| `Export-PrinterDrivers` | ❌ | ❌ | ❌ | ❌ | ❌ |
| `Restore-PrinterDrivers` | ❌ | ❌ | ✅ (bad path) | ❌ | 🔶 |
| `Install-PrinterDriverFromInf` | ❌ | ❌ | ✅ (bad path) | ❌ | 🔶 |
| `Remove-PrinterDriverByName` | ❌ | ❌ | ✅ (bad name) | ❌ | 🔶 |
| `Get-DriverUpgradeRecommendations` | ❌ | ✅ (type shape) | ❌ | ❌ | 🔶 |
| `Get-DriverIntelligence` | ❌ | ✅ (type shape) | ❌ | ❌ | 🔶 |

### Networking Module (4 exported)

| Function | Unit | Integration | Negative | Regression | Status |
|----------|------|-------------|----------|------------|--------|
| `Get-NetworkProfileStatus` | ❌ | ✅ (type shape) | ❌ | ❌ | 🔶 |
| `Set-NetworkProfilePrivate` | ❌ | ❌ | ❌ | ❌ | ❌ |
| `Get-FirewallRuleStatus` | ❌ | ✅ (type shape) | ❌ | ❌ | 🔶 |
| `Set-FirewallRule` | ❌ | ❌ | ✅ (ValidateSet) | ❌ | 🔶 |

### IPP Module (5 exported)

| Function | Unit | Integration | Negative | Regression | Status |
|----------|------|-------------|----------|------------|--------|
| `Get-IPPStatus` | ❌ | ✅ (type shape) | ❌ | ❌ | 🔶 |
| `Get-IPPUrls` | ❌ | ✅ (type shape) | ❌ | ❌ | 🔶 |
| `Test-IPPEndpoint` | ❌ | ❌ | ✅ (mandatory param) | ❌ | 🔶 |
| `Install-IPPServer` | ❌ | ❌ | ❌ | ❌ | ❌ |
| `Test-IPPClientInstalled` | ❌ | ✅ (no-throw) | ❌ | ❌ | 🔶 |

### SMB Module (2 exported)

| Function | Unit | Integration | Negative | Regression | Status |
|----------|------|-------------|----------|------------|--------|
| `Get-SmbConfiguration` | ❌ | ✅ (type shape) | ❌ | ❌ | 🔶 |
| `Set-SmbConfiguration` | ❌ | ❌ | ✅ (switch check) | ❌ | 🔶 |

### Sharing Module (7 exported)

| Function | Unit | Integration | Negative | Regression | Status |
|----------|------|-------------|----------|------------|--------|
| `Get-PrinterShareStatus` | ❌ | ✅ (type shape) | ❌ | ❌ | 🔶 |
| `Enable-PrinterSharing` | ✅ (mock) | ❌ | ✅ (missing printer) | ❌ | 🔶 |
| `Disable-PrinterSharing` | ✅ (mock) | ❌ | ✅ (missing printer) | ❌ | 🔶 |
| `Get-SmbSharePermissions` | ❌ | ✅ (no-throw) | ❌ | ❌ | 🔶 |
| `Set-PrinterSharePermission` | ❌ | ❌ | ❌ | ❌ | ❌ |
| `Set-PrinterSharingTransport` | ❌ | ❌ | ❌ | ❌ | ❌ |
| `Get-PrinterSharingCompatibility` | ❌ | ✅ (type shape) | ❌ | ❌ | 🔶 |

### Android Module (5 exported)

| Function | Unit | Integration | Negative | Regression | Status |
|----------|------|-------------|----------|------------|--------|
| `Get-AndroidCompatibility` | ❌ | ✅ (type shape) | ❌ | ❌ | 🔶 |
| `Show-AndroidWizard` | ❌ | ✅ (no-throw) | ❌ | ❌ | 🔶 |
| `Get-AndroidSetupContent` | ❌ | ✅ (type shape) | ❌ | ❌ | 🔶 |
| `Get-ConnectionInfo` | ❌ | ✅ (type shape) | ❌ | ❌ | 🔶 |
| `New-ConnectionQRCode` | ❌ | ✅ (type shape) | ❌ | ❌ | 🔶 |

### Diagnostics Module (5 exported)

| Function | Unit | Integration | Negative | Regression | Status |
|----------|------|-------------|----------|------------|--------|
| `Get-NetworkValidation` | ❌ | ✅ (type shape) | ❌ | ❌ | 🔶 |
| `Show-NetworkValidationReport` | ❌ | ✅ (no-throw) | ❌ | ❌ | 🔶 |
| `Export-RegistrySnapshot` | ❌ | ❌ | ❌ | ❌ | ❌ |
| `Export-FirewallSnapshot` | ❌ | ✅ (no-throw) | ❌ | ❌ | 🔶 |
| `Export-ServiceSnapshot` | ❌ | ✅ (no-throw) | ❌ | ❌ | 🔶 |

### Repair Module (2 exported)

| Function | Unit | Integration | Negative | Regression | Status |
|----------|------|-------------|----------|------------|--------|
| `Initialize-RepairBackup` | ❌ | ✅ (exists) | ❌ | ❌ | 🔶 |
| `Invoke-AutomaticShareRepair` | ❌ | ❌ | ✅ (switch check) | ❌ | 🔶 |

### Rollback Module (2 exported)

| Function | Unit | Integration | Negative | Regression | Status |
|----------|------|-------------|----------|------------|--------|
| `Initialize-RepairRollback` | ❌ | ✅ (type shape) | ❌ | ❌ | 🔶 |
| `Invoke-Rollback` | ❌ | ✅ (exists) | ❌ | ❌ | 🔶 |

### Validation Module (2 exported)

| Function | Unit | Integration | Negative | Regression | Status |
|----------|------|-------------|----------|------------|--------|
| `Invoke-EndToEndValidation` | ❌ | ✅ (type+score) | ❌ | ❌ | 🔶 |
| `Get-ValidationDashboard` | ❌ | ✅ (type+status) | ❌ | ❌ | 🔶 |

### SetupWizard Module (2 exported)

| Function | Unit | Integration | Negative | Regression | Status |
|----------|------|-------------|----------|------------|--------|
| `Invoke-PrintServerWizard` | ❌ | ✅ (exists) | ❌ | ❌ | 🔶 |
| `Get-WizardStatus` | ❌ | ✅ (type+steps) | ❌ | ❌ | 🔶 |

### Reporting Module (2 exported)

| Function | Unit | Integration | Negative | Regression | Status |
|----------|------|-------------|----------|------------|--------|
| `New-PrinterReport` | ❌ | ✅ (file generation) | ❌ | ❌ | 🔶 |
| `Get-PrintComplianceReport` | ❌ | ✅ (type shape) | ❌ | ❌ | 🔶 |

### Logging Module (5 exported)

| Function | Unit | Integration | Negative | Regression | Status |
|----------|------|-------------|----------|------------|--------|
| `Initialize-Logging` | ❌ | ✅ (path created) | ❌ | ❌ | ✅ |
| `Write-Log` | ❌ | ✅ (file written) | ❌ | ❌ | ✅ |
| `Get-LogFilePath` | ❌ | ✅ (object shape) | ❌ | ❌ | ✅ |
| `Get-LogContent` | ❌ | ✅ (level filter) | ❌ | ❌ | ✅ |
| `Export-LogArchive` | ❌ | ✅ (zip created) | ❌ | ❌ | ✅ |

### Bundle Module (1 exported)

| Function | Unit | Integration | Negative | Regression | Status |
|----------|------|-------------|----------|------------|--------|
| `New-DiagnosticBundle` | ❌ | ✅ (exists) | ❌ | ❌ | 🔶 |

### Utilities Module (9 exported)

| Function | Unit | Integration | Negative | Regression | Status |
|----------|------|-------------|----------|------------|--------|
| `Test-Administrator` | ❌ | ✅ (bool check) | ❌ | ❌ | 🔶 |
| `Test-Elevated` | ❌ | ✅ (equivalence) | ❌ | ❌ | 🔶 |
| `Assert-Elevated` | ✅ (mock) | ❌ | ✅ (throws) | ❌ | ✅ |
| `Confirm-DestructiveAction` | ❌ | ❌ | ❌ | ❌ | ❌ |
| `Get-SystemInfo` | ❌ | ✅ (shape+version) | ❌ | ❌ | 🔶 |
| `Write-MenuHeader` | ❌ | ❌ | ❌ | ❌ | ❌ |
| `Wait-Menu` | ❌ | ❌ | ❌ | ❌ | ❌ |
| `Get-ToolkitStatus` | ❌ | ✅ (version+count) | ❌ | ❌ | 🔶 |
| `Invoke-ToolkitMainMenu` | ❌ | ✅ (exists) | ❌ | ❌ | 🔶 |

### ZeroTouch Module (10 exported)

| Function | Unit | Integration | Negative | Regression | Status |
|----------|------|-------------|----------|------------|--------|
| `Start-ZeroTouchDeployment` | ❌ | ✅ (param check) | ❌ | ❌ | 🔶 |
| `Invoke-GuidedRecovery` | ❌ | ✅ (exists) | ❌ | ❌ | 🔶 |
| `Get-DeploymentHealth` | ❌ | ✅ (exists) | ❌ | ❌ | 🔶 |
| `Get-ClientConnectionInfo` | ✅ (mock) | ❌ | ❌ | ❌ | 🔶 |
| `Get-ZeroTouchDashboard` | ❌ | ✅ (exists) | ❌ | ❌ | 🔶 |
| `Start-DeploymentTransaction` | ❌ | ✅ (file creation) | ❌ | ❌ | 🔶 |
| `Write-TransactionLog` | ❌ | ✅ (file creation) | ❌ | ❌ | 🔶 |
| `Complete-DeploymentTransaction` | ❌ | ✅ (exists) | ❌ | ❌ | 🔶 |
| `Get-TransactionLogPath` | ❌ | ✅ (file exists) | ❌ | ❌ | 🔶 |
| `Test-DriverSignature` | ❌ | ✅ (object shape) | ❌ | ❌ | 🔶 |

### Orchestration Module (15 exported, 3 orphan)

| Function | Unit | Integration | Negative | Regression | Status |
|----------|------|-------------|----------|------------|--------|
| `New-OrchestrationTask` | ✅ | ✅ (object shape) | ❌ | ❌ | ✅ |
| `Get-TopologicalTaskOrder` | ✅ | ✅ (ordering) | ✅ (cycle) | ❌ | ✅ |
| `Subscribe-OrchestrationEvent` | ❌ | ✅ (delivery) | ❌ | ❌ | 🔶 |
| `Publish-OrchestrationEvent` | ❌ | ✅ (delivery) | ❌ | ❌ | 🔶 |
| `Get-OrchestrationEventLog` | ❌ | ✅ (count, filter) | ❌ | ❌ | 🔶 |
| `Set-SubsystemState` | ❌ | ✅ (state tracking) | ❌ | ❌ | 🔶 |
| `Get-SubsystemState` | ❌ | ✅ (state tracking) | ❌ | ❌ | 🔶 |
| `Get-OrchestrationStateReport` | ❌ | ✅ (summary, health) | ❌ | ❌ | 🔶 |
| `Reset-OrchestrationState` | ❌ | ✅ (state cleared) | ❌ | ❌ | 🔶 |
| `Start-OrchestrationTransaction` | ❌ | ✅ (exists) | ❌ | ❌ | 🔶 |
| `Record-TaskTransaction` | ❌ | ✅ (exists) | ❌ | ❌ | 🔶 |
| `Get-OrchestrationTransactionLog` | ❌ | ✅ (exists) | ❌ | ❌ | 🔶 |
| `Get-DefaultDesiredState` | ❌ | ✅ (shape check) | ❌ | ❌ | 🔶 |
| `Get-DesiredState` | ❌ | ✅ (shape check) | ❌ | ❌ | 🔶 |
| `Invoke-ConfigurationProvider` | ❌ | ❌ | ❌ | ❌ | ❌ |
| `Invoke-Orchestrator` | ❌ | ❌ | ❌ | ❌ | ❌ |
| `Invoke-RecoveryEngine` | ❌ | ❌ | ❌ | ❌ | ❌ |
| `Get-OrchestrationReport` | ❌ | ❌ | ❌ | ❌ | ❌ |

### Providers Module (4 exported)

| Function | Unit | Integration | Negative | Regression | Status |
|----------|------|-------------|----------|------------|--------|
| `New-ProviderResult` | ❌ | ❌ | ❌ | ❌ | ❌ |
| `Enable-PrinterFirewallRules` | ❌ | ❌ | ❌ | ❌ | ❌ |
| `Set-DefaultPrinterNative` | ❌ | ❌ | ❌ | ❌ | ❌ |
| `Get-PrinterDriverStoreDetails` | ❌ | ❌ | ❌ | ❌ | ❌ |

---

## Functions with Zero Test Coverage (18)

These 18 exported functions have no test whatsoever:

1. `Set-DefaultPrinter`
2. `Stop-Spooler`
3. `Start-Spooler`
4. `Enable-PrintSharing` (Core)
5. `Get-PrinterQueueHealth`
6. `Set-ServiceConfiguration`
7. `Export-PrinterDrivers`
8. `Set-NetworkProfilePrivate`
9. `Install-IPPServer`
10. `Set-PrinterSharePermission`
11. `Set-PrinterSharingTransport`
12. `Export-RegistrySnapshot`
13. `Confirm-DestructiveAction`
14. `Write-MenuHeader`
15. `Wait-Menu`
16. `Invoke-ConfigurationProvider`
17. `Invoke-Orchestrator`
18. `Invoke-RecoveryEngine`
19. `Get-OrchestrationReport`
20. `New-ProviderResult`
21. `Enable-PrinterFirewallRules`
22. `Set-DefaultPrinterNative`
23. `Get-PrinterDriverStoreDetails`

**Note:** This count exceeds 18 because the Providers module (4 functions) is entirely untested.

---

## Test Quality Assessment

| Category | Count | Percentage |
|----------|-------|------------|
| **Existence/load check** (function exists) | ~30 | 28% |
| **Type shape check** (returns expected type) | ~25 | 24% |
| **Parameter validation** (ValidateSet, mandatory) | ~6 | 6% |
| **Mock-based unit test** | ~5 | 5% |
| **Negative/error path** | ~6 | 6% |
| **Regression test** | ~1 | 1% |
| **Zero coverage** | ~23 | 22% |
| **Total functions** | ~106 | 100% |

---

## Gaps by Risk Severity

### Critical Gaps (no test + high business impact)

| Function | Reason |
|----------|--------|
| `Invoke-Orchestrator` | Core orchestration engine — untested |
| `Invoke-ConfigurationProvider` | All 8 provider implementations — untested |
| `Invoke-RecoveryEngine` | Recovery path — untested |
| `Set-ServiceConfiguration` | Modifies service state — untested |

### High Gaps (no test + moderate impact)

| Function | Reason |
|----------|--------|
| `Set-DefaultPrinter` | Changes print behavior — untested |
| `Install-IPPServer` | Installs Windows feature — untested |
| `Set-NetworkProfilePrivate` | Changes network security posture — untested |
| `Export-PrinterDrivers` | Backup operation — untested |

### Low Gaps (no test + low impact)

| Function | Reason |
|----------|--------|
| `Write-MenuHeader` | Console formatting only |
| `Wait-Menu` | Input read only |
| `Confirm-DestructiveAction` | Interactive prompt — hard to test |

---

## Recommended Test Priorities for LTS

1. **P0 — Fix orphan functions** (remove from export or implement)
2. **P0 — Add `Invoke-Orchestrator` unit tests** (mock providers, test DAG execution)
3. **P0 — Add `Invoke-ConfigurationProvider` tests** (per-provider mock tests)
4. **P1 — Add `Set-ServiceConfiguration` tests** (mock `Get-Service`, `Set-Service`)
5. **P1 — Add `Set-DefaultPrinter` tests** (mock `Set-DefaultPrinter`)
6. **P1 — Add `Install-IPPServer` tests** (mock `Enable-WindowsOptionalFeature`)
7. **P2 — Add Providers module tests** (`New-ProviderResult`, `Enable-PrinterFirewallRules`)
8. **P2 — Add negative tests** for all state-changing functions (simulate errors)
9. **P2 — Add regression test** for each bug fix (L1 rollback, S5 admin check)
