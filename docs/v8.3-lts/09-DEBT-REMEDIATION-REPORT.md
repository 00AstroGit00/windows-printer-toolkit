# Debt Remediation Report — v8.2.0 Critical Technical Debt

> **Author:** Lead Maintainer  
> **Date:** 2026-07-15  
> **Status:** All 3 Critical items remediated

---

## Remediation Summary

| Debt ID | Title | Status | Impact |
|---------|-------|--------|--------|
| TD-C1 | Orphan Functions in Production Export List | ✅ Remediated | No more `CommandNotFoundException` at runtime |
| TD-C2 | Inconsistent Return Types on Failure | ✅ Remediated | Error context now captured in logs |
| TD-C3 | No Rollback for Driver/Printer Providers | ✅ Remediated | Pre-state captured; recovery path handles all 8 providers |

---

## TD-C1 — Orphan Functions

### Before

Three functions (`Get-OrchestrationEventLog`, `Get-OrchestrationStateReport`, `Reset-OrchestrationState`) were listed in `FunctionsToExport` in the module manifest and in the Pester test required-function list, but had **no implementation** in any `.psm1` file. Calling any of these at runtime after module import would produce `CommandNotFoundException`.

### After

All three functions are implemented in `PrinterToolkit.Orchestration.psm1`:

| Function | Implementation | Output Type |
|----------|---------------|-------------|
| `Get-OrchestrationEventLog` | Returns `$Script:OrchestrationEvents` with optional `-EventName` filter and `-Tail` limit | `[PSCustomObject]` with `EventCount` + `Events` |
| `Get-OrchestrationStateReport` | Aggregates `$Script:SubsystemStates` into a health summary with scores per state category | `[PSCustomObject]` with `TotalSubsystems`, `Healthy`, `Warning`, `Failed`, `Pending`, `Unknown`, `OverallHealth`, `HealthScore`, `SubsystemStates` |
| `Reset-OrchestrationState` | Clears all in-memory state: `$Script:SubsystemStates`, `$Script:OrchestrationEvents`, `$Script:ActiveTransaction`, `$Script:EventSubscribers`, `$Script:ProviderPreState`. Optional `-KeepTransactionLog` switch. | `[void]` |

All three are added to `Export-ModuleMember` in the Orchestration module and the Pester test required-function list. Six new test cases cover them.

**Files changed:**
- `Modules/Orchestration/PrinterToolkit.Orchestration.psm1` — added 3 functions + Export-ModuleMember update
- `Tests/PrinterToolkit.Tests.ps1` — added 6 test cases
- `docs/v8.3-lts/01-API-STABILITY-GUIDE.md` — updated from "Orphan" to "Stable"
- `docs/v8.3-lts/02-TECHNICAL-DEBT-REGISTER.md` — marked Remediated
- `docs/v8.3-lts/05-TEST-COVERAGE-MATRIX.md` — updated coverage

---

## TD-C2 — Return Contract Consistency

### Before

`Invoke-ConfigurationProvider`'s Sharing provider `ApplyChanges` phase returned bare `$false` when no printer was found, with no error detail captured. Callers received a boolean with no context about *why* the operation failed.

### After

All `return $false` paths in `Invoke-ConfigurationProvider` now include a `Write-Log` call before the return, capturing error context. The boolean return type for `ApplyChanges`/`Validate`/`Rollback` phases is the established contract (consistent across all 8 providers — Service, Firewall, Network, Sharing, IPP, Registry, Driver, Printer). Error detail is now persisted in the log instead of silently lost.

**Specific changes:**
- Sharing `ApplyChanges`: `Write-Log -Message 'Sharing.ApplyChanges: no printer found' -Level 'WARN'` before `return $false`
- Sharing `ApplyChanges`: `Write-Log` on `Enable-PrinterSharing` failure before returning boolean result

**Return type contract documented:**
| Phase | Return Type | Semantics |
|-------|-------------|-----------|
| `GetCurrentState` | `[PSCustomObject]` | Current state snapshot |
| `GetDesiredState` | `[PSCustomObject]` | Requested state |
| `PlanChanges` | `[array]` | List of planned changes (may be empty) |
| `ApplyChanges` | `[bool]` | $true = changes applied, $false = failed |
| `Validate` | `[bool]` | $true = compliant, $false = not compliant |
| `Rollback` | `[bool]` | $true = rollback succeeded / not needed, $false = rollback failed |

---

## TD-C3 — Provider Rollback Completion

### Before

- Driver provider `ApplyChanges`: no-op, returned `$true`. Rollback: no-op, returned `$true`. No pre-state captured.
- Printer provider `ApplyChanges`: no-op, returned `$true`. Rollback: no-op, returned `$true`. No pre-state captured.
- Recovery Engine: no `Driver` or `Printer` cases in `switch` statements — these subsystems were silently skipped during recovery.

### After

**Driver provider:**
- `ApplyChanges`: Captures pre-state (`Found`, `PrinterName`) in `$Script:ProviderPreState['Driver']`. Logs that driver acquisition is handled by Windows PnP.
- `Rollback`: Reads pre-state and logs confirmation that no driver was installed by this provider, so no rollback is needed.

**Printer provider:**
- `ApplyChanges`: Captures pre-state (`Detected`, `Name`) in `$Script:ProviderPreState['Printer']`. Logs that printer detection is read-only.
- `Rollback`: Reads pre-state and logs confirmation.

**Recovery Engine:**
- `Driver` case added: logs warning that driver re-acquisition requires user intervention (Windows PnP).
- `Printer` case added: logs warning that printer re-detection requires user intervention (connect USB).
- Validation for both: checks `Get-DriverIntelligence` / `Get-UsbPrinterInfo` respectively.

### Provider Rollback Matrix (Updated)

| Provider | Pre-State Captured | Rollback Action | Automation Level |
|----------|-------------------|----------------|-----------------|
| Service | StartType + Status per service | Restore StartType, start/stop as needed | Auto |
| Firewall | Group enablement state + IPP rule state | Disable groups/rules that were originally off | Auto |
| Network | InterfaceIndex + current Category | Restore original Category | Auto |
| Sharing | PrinterName, WasShared, ShareName | Disable sharing if WasShared=$false | Auto |
| IPP | WasInstalled | Disable PrintNotify if was not installed | Auto |
| Registry | RpcAuthnLevelPrivacyEnabled, DisableHTTPPrinting | Restore original DWord values | Auto |
| **Driver** | **Found, PrinterName** | **No-op (read-only provider — no driver installed)** | **N/A (manual)** |
| **Printer** | **Detected, Name** | **No-op (read-only provider — no config changed)** | **N/A (manual)** |

---

## Verification Checklist

| Check | Status |
|-------|--------|
| Module manifests remain valid | ✅ psd1 unchanged (functions already listed) |
| Exported function list matches implementation | ✅ All 3 new functions added to Export-ModuleMember |
| Provider contracts compatible with orchestration engine | ✅ ApplyChanges/Validate/Rollback signatures unchanged |
| Tests updated | ✅ 6 new test cases added |
| Documentation updated | ✅ API guide, debt register, test matrix updated |
| No breaking changes | ✅ All changes are additive (new functions) or logging-only |
