# Technical Debt Register — PrinterToolkit v8.3 LTS

> **Classification:** Critical / High / Medium / Low  
> **Status:** Open / Accepted / Remediated  
> **Last updated:** 2026-07-15

## Critical Items

### C1 — Orphan Functions in Production Export List

| Field | Value |
|-------|-------|
| **ID** | TD-C1 |
| **Area** | `PrinterToolkit.Orchestration.psm1` |
| **Description** | `Get-OrchestrationEventLog`, `Get-OrchestrationStateReport`, `Reset-OrchestrationState` were listed in `FunctionsToExport` but had zero implementation. |
| **Root cause** | v8.2 feature incomplete — orchestration state reporting was planned but never coded. |
| **Remediation** | All three functions implemented in `PrinterToolkit.Orchestration.psm1`. `Get-OrchestrationEventLog` returns `$Script:OrchestrationEvents` with filtering. `Get-OrchestrationStateReport` aggregates `$Script:SubsystemStates` with health scoring. `Reset-OrchestrationState` clears in-memory state (subsystem states, events, subscribers, pre-state, active transaction). Added to `Export-ModuleMember` and Pester tests. |
| **Effort** | 30 minutes |
| **Status** | **Remediated — v8.2.0** |

### C2 — Inconsistent Return Types on Failure

| Field | Value |
|-------|-------|
| **ID** | TD-C2 |
| **Area** | Orchestration module — `Invoke-ConfigurationProvider` |
| **Description** | `Invoke-ConfigurationProvider` returned `[PSCustomObject]` on some paths but `$false` (boolean) on some failure paths (e.g., Sharing provider's ApplyChanges when no printer found). |
| **Remediation** | Added `Write-Log` calls to all silent-failure boolean returns, providing error context. The boolean return type for `ApplyChanges`/`Validate`/`Rollback` phases is the established contract (consistent across all 8 providers). Error detail is now captured in the log instead of lost. |
| **Effort** | 15 minutes |
| **Status** | **Remediated — v8.2.0** |

### C3 — No Rollback for Driver, Printer (Orchestration Provider)

| Field | Value |
|-------|-------|
| **ID** | TD-C3 |
| **Area** | `Invoke-ConfigurationProvider` — Driver, Printer providers |
| **Description** | The Driver and Printer providers returned `$true` for both `ApplyChanges` and `Rollback` with no captured pre-state. The Recovery Engine did not attempt to repair Driver or Printer subsystems. |
| **Remediation** | Driver and Printer providers now capture pre-state in `$Script:ProviderPreState` during `ApplyChanges`. Rollback phases log the pre-state and confirm no changes were made (both providers are read-only — they detect but do not install). Recovery Engine now handles `Driver` and `Printer` subsystems with explicit validation checks and logged warnings that these require user intervention. |
| **Effort** | 30 minutes |
| **Status** | **Remediated — v8.2.0** |

---

## High Items

### H1 — 12 Legacy Modules Without `New-ProviderResult`

| Field | Value |
|-------|-------|
| **ID** | TD-H1 |
| **Area** | Core, Detection, Configuration, Drivers, Networking, IPP, SMB, Sharing, Android, Diagnostics, Repair, Rollback |
| **Description** | These 12 modules predate the v8.1 `New-ProviderResult` contract. They return ad-hoc `[PSCustomObject]@{ Success = $true/false }` with no `ErrorCode`, `Category`, `RecommendedAction`, `Recoverability`, or `Timestamp`. |
| **Impact** | Inconsistent error handling. Orchestration provider wrappers must re-map return values. Automated diagnosis cannot determine root cause from error codes. |
| **Remediation** | (Speculative — not implementing now) Document the inconsistency. Future v9 migration could add wrapper functions. |
| **Effort** | 3–5 days per module; not recommended for LTS |
| **Status** | Accepted — deferred to v9+ |

### H2 — Missing Idempotency Checks

| Field | Value |
|-------|-------|
| **ID** | TD-H2 |
| **Area** | All state-changing functions |
| **Description** | No function checks "is this already applied?" before executing. `Set-ServiceConfiguration` does not check if service is already Running + Automatic before changing. `Set-NetworkProfilePrivate` does not check current profile. `Set-FirewallRule` does not check rule state. `Install-IPPServer` may reinstall an already-installed feature. |
| **Impact** | Repeated calls produce unnecessary system changes, event log noise, and may trigger unnecessary UAC prompts. Not idempotent. |
| **Remediation** | Add pre-condition checks at the top of each state-changing function. Return success immediately if desired state matches current state. |
| **Effort** | 4 hours across affected functions |
| **Status** | Open |

### H3 — Orchestration `$Script:ProviderPreState` Not Thread-Safe

| Field | Value |
|-------|-------|
| **ID** | TD-H3 |
| **Area** | `PrinterToolkit.Orchestration.psm1` — `$Script:ProviderPreState` |
| **Description** | `$Script:ProviderPreState` is a module-scoped hashtable shared across all provider invocations. If two orchestrations run concurrently (nested calls, parallel tasks), pre-state from one invocation overwrites another. Rollback would restore the wrong state. |
| **Impact** | Race condition on concurrent orchestration invocation. Rollback becomes incorrect. |
| **Remediation** | Scope pre-state to transaction ID (keyed by `$Script:ActiveTransaction.Id`). Or use a stack instead of a flat hashtable. |
| **Effort** | 1 hour |
| **Status** | Open |

### H4 — Test Coverage Gap: Orchestration Error Paths

| Field | Value |
|-------|-------|
| **ID** | TD-H4 |
| **Area** | Tests |
| **Description** | The orchestration tests (lines 616–692) cover only happy paths: task creation, DAG ordering, cycle detection, event publishing, state management. Zero tests for: provider failure, rollback execution, recovery engine, transaction recording, retry logic. |
| **Impact** | Error handling code paths are untested and likely to fail on Windows. The retry loop, recovery engine, and rollback have never been exercised. |
| **Remediation** | Add Pester tests with mocked `Get-Service`, `Get-Printer`, etc. to simulate provider failures and verify rollback/recovery. |
| **Effort** | 6 hours |
| **Status** | Open |

---

## Medium Items

### M1 — `Get-PrinterDriverDetails` WHQL/DriverDate Not Populated

| Field | Value |
|-------|-------|
| **ID** | TD-M1 |
| **Area** | `PrinterToolkit.Drivers.psm1` |
| **Description** | `Get-PrinterDriverDetails` returns `WHQL` and `DriverDate` fields as `$null` because the underlying CIM class `Win32_PrinterDriver` does not expose these. The function documents them but never populates them. |
| **Impact** | Compliance reports show null values for WHQL status and driver date. Users cannot filter by certified drivers. |
| **Remediation** | Query `Win32_PnPSignedDriver` or DISM driver store to populate WHQL and driver date. |
| **Effort** | 3 hours |
| **Status** | Open |

### M2 — WSD Printer Detection May Yield False Positives

| Field | Value |
|-------|-------|
| **ID** | TD-M2 |
| **Area** | Detection module — WSD heuristic |
| **Description** | The WSD printer detection heuristic (matching port name against WSD pattern) may match non-printer WSD devices (scanners, fax machines). |
| **Impact** | False positives in printer enumeration. Incorrect detection counts. |
| **Remediation** | Cross-reference `Win32_Printer` driver class or use `Get-PrintConfiguration` to verify printer capability. |
| **Effort** | 2 hours |
| **Status** | Accepted — low severity |

### M3 — `Get-PrinterConnectionType` Returns `'USB'`, `'Network'`, `'WSD'` Strings

| Field | Value |
|-------|-------|
| **ID** | TD-M3 |
| **Area** | Detection — function return |
| **Description** | Returns plain strings `'USB'`, `'Network'`, `'WSD'` with no validation. Unknown connection types return empty string. No consistency with provider result model. |
| **Impact** | Callers must handle empty string as unknown type. |
| **Remediation** | Use `New-ProviderResult` wrapper or at minimum return `'Unknown'` instead of `''`. |
| **Effort** | 30 minutes |
| **Status** | Open |

### M4 — SetupWizard Hardcodes 11 Steps

| Field | Value |
|-------|-------|
| **ID** | TD-M4 |
| **Area** | SetupWizard |
| **Description** | `Get-WizardStatus` asserts `StepsTotal -eq 11`. The wizard is hardcoded to 11 steps with no extensibility mechanism. Adding or removing steps breaks the test assertion. |
| **Impact** | Rigid design. Any wizard modification requires test update. |
| **Remediation** | Derive step count from step array. Remove hardcoded assertion. |
| **Effort** | 1 hour |
| **Status** | Open |

---

## Low Items

### L1 — Android ADB Detection Not Testable in CI

| Field | Value |
|-------|-------|
| **ID** | TD-L1 |
| **Area** | Android module |
| **Description** | ADB detection (`Get-AndroidCompatibility`) calls `adb version` which is not available on Windows CI runners without Android SDK. The function silently catches the error and reports `$false`. |
| **Impact** | Cannot be tested in automated CI. Any regression in ADB detection goes undetected. |
| **Remediation** | Mock the ADB call in tests. Document that ADB detection is best-effort only. |
| **Effort** | 1 hour |
| **Status** | Accepted |

### L2 — `New-ConnectionQRCode` Saves to Desktop by Default

| Field | Value |
|-------|-------|
| **ID** | TD-L2 |
| **Area** | Android module |
| **Description** | `New-ConnectionQRCode` defaults `-OutputPath` to `[Environment]::GetFolderPath('Desktop')`. On locked-down enterprise desktops ( redirected Desktop via Folder Redirection), this may fail or write to the wrong location. |
| **Impact** | QR code may not be saved where expected. |
| **Remediation** | Use `$env:TEMP` as default fallback, or make `-OutputPath` mandatory. |
| **Effort** | 30 minutes |
| **Status** | Open |

### L3 — Module Version Strings Hardcoded in Comments

| Field | Value |
|-------|-------|
| **ID** | TD-L3 |
| **Area** | All `.psm1` comment headers |
| **Description** | Module-level `.SYNOPSIS` comments contain version strings (e.g., `v6.0`, `v8.0`) that are not derived from the manifest. These drift over time and are already stale in some modules. |
| **Impact** | Cosmetic. Misleading version info in module help. |
| **Remediation** | Version the comment header at build time from manifest, or remove version from comments entirely. |
| **Effort** | 1 hour across all files |
| **Status** | Open |

### L4 — Distribution Manifests Point to Stale v5.3.0

| Field | Value |
|-------|-------|
| **ID** | TD-L4 |
| **Area** | `dist/winget/`, `dist/chocolatey/`, `dist/scoop/` |
| **Description** | All distribution manifests reference v5.3.0 ZIPs with placeholder SHA256 hashes. These are completely disconnected from the current v8.2.0-rc1 codebase. |
| **Impact** | Anyone installing via WinGet/Chocolatey/Scoop gets the 2-year-old v5.3.0 release. |
| **Remediation** | Update manifests after stable release. |
| **Effort** | 2 hours |
| **Status** | Accepted — blocked on stable release |

### L5 — No `CI/publish.ps1` Exists

| Field | Value |
|-------|-------|
| **ID** | TD-L5 |
| **Area** | CI |
| **Description** | There is no publish script. Distribution to PSGallery/WinGet/Chocolatey/Scoop is manual. |
| **Impact** | Release process is not fully automated. Risk of publishing inconsistency. |
| **Remediation** | Create `CI/publish.ps1` after stable release. |
| **Effort** | 4 hours |
| **Status** | Accepted — post-stable |

---

## Summary

| Severity | Original | Remediated | Remaining | Action |
|----------|----------|------------|-----------|--------|
| Critical | 3 | 3 | **0** | ✅ All remediated in v8.2.0 |
| High | 4 | 0 | **4** | Fix before LTS tag |
| Medium | 4 | 0 | **4** | Schedule after LTS |
| Low | 5 | 0 | **5** | Accept or schedule |
| **Total** | **16** | **3** | **13** | |
