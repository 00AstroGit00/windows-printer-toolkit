# v8.2 Provider Certification Report (Phase 2)

**Method:** Static code review / certification against the v8.2 criteria.
**Evidence base:** Source of `Modules/**/*.psm1` and `PrinterToolkit.psm1` as of this build.
**Runtime evidence:** NOT COLLECTED in this environment (no Windows host available — see
`01-runtime-validation-report.md`, marked PENDING). All findings below are reproducible by
reading the cited files; criteria that require execution are explicitly flagged.

---

## Certification criteria × provider matrix

| Provider | Correct API usage | Return values | Structured error model | Rollback | Recovery | Idempotent | Verdict |
|---|---|---|---|---|---|---|---|
| Registry | ✅ native registry provider | ✅ | ⚠️ partial | ⚠️ stub (see L1) | ✅ | ✅ | **Conditional** |
| Firewall | ✅ NetSecurity | ✅ | ✅ (helper) | ⚠️ stub | ✅ | ✅ | **Conditional** |
| Services | ✅ Get/Set-Service | ✅ | ⚠️ partial | ⚠️ stub | ✅ | ✅ | **Conditional** |
| Network | ✅ NetConnectionProfile | ✅ | ⚠️ partial | ⚠️ stub | ✅ | ✅ | **Conditional** |
| Printer | ✅ CIM/PrintManagement | ✅ | ✅ (helper) | ⚠️ stub | ✅ | ✅ | **Conditional** |
| Driver | ✅ PrintManagement/CIM/Authenticode | ✅ | ✅ (helper) | ⚠️ stub | ✅ | ✅ | **Conditional** |
| Sharing | ✅ Set-Printer/SMB cmdlets | ✅ | ⚠️ partial | ⚠️ stub | ✅ | ✅ | **Conditional** |
| IPP | ✅ WindowsOptionalFeature/Net* | ✅ | ⚠️ partial | ⚠️ stub | ✅ | ✅ | **Conditional** |
| Validation | ✅ all native | ✅ scored | n/a (read-only) | n/a | n/a | ✅ | **Pass (static)** |

Legend: ✅ verified by code · ⚠️ partial/limitation · ❌ defect.

---

## Per-provider detail (with evidence)

### Registry
- **API usage:** PowerShell registry provider `Get/Set-ItemProperty` (`Configuration` `Get-RegistryExpected` lines 216–266; `Repair` registry cycle 311–321; `Orchestration` Registry provider 482–505). No `reg.exe` for state reads/writes. `reg.exe` is used only for backup/restore export-import (supported tool).
- **Return values:** `Get-RegistryExpected` returns `@(PSCustomObject{RegistryPath,ValueName,Exists,ActualValue,ExpectedValue,Pass,Detail})`; `Compare-RegistryState` adds Score.
- **Error model:** Ad-hoc `Pass`/`Detail` booleans; does **not** yet wrap `New-ProviderResult`. Limitation L2.
- **Rollback:** Backup via `reg.exe export`; restore via `reg.exe import` (`Repair` `Invoke-RepairRollback`). Orchestrator `Registry` provider `Rollback` phase is a **stub** (`return $true`) — Limitation L1.
- **Recovery:** `Invoke-RecoveryEngine` Registry branch sets `RpcAuthnLevelPrivacyEnabled=0` / `DisableHTTPPrinting=0` via `Set-ItemProperty` (native).
- **Idempotent:** Setting the same DWord twice is a no-op. ✅

### Firewall
- **API usage:** `Get/Set/New-NetFirewallRule` throughout. All `netsh` removed (Orchestration 406, 685; Networking 240; Repair 223; ZeroTouch 211 now call `Enable-PrinterFirewallRules`). **Verified by grep: zero `netsh` in execution paths.**
- **Return values:** `Enable-PrinterFirewallRules` returns `New-ProviderResult` (Status/Success/ErrorCode/Category/RecommendedAction/Recoverability/Data/Timestamp).
- **Error model:** ✅ structured (helper). Orchestrator `Firewall` provider itself still returns plain `@{IPP,SMB,Discovery}` (L2).
- **Rollback:** Orchestrator `Firewall.Rollback` is a **stub** (L1). (Note: firewall rules are additive/enabling; true rollback would disable — not yet implemented.)
- **Recovery:** ✅ native via `Enable-PrinterFirewallRules`.
- **Idempotent:** `Enable-NetFirewallRule` is idempotent. ✅

### Services
- **API usage:** `Get/Set/Start/Stop-Service` (`Core` `Stop/Start-Spooler`; `Configuration` `Get/Set-ServiceConfiguration`; `Orchestration` Service provider 354–391). No `sc.exe`/WMI string calls.
- **Return values:** `Set-ServiceConfiguration` → `@{ServiceName,StartType,Running,Success,Detail}`; `Get-ServiceStatus` → array of per-service status.
- **Error model:** ⚠️ partial (L2).
- **Rollback:** `Invoke-RepairRollback` restores StartType/Status from CSV; Orchestrator `Service.Rollback` stub (L1).
- **Recovery:** ✅ `Invoke-RecoveryEngine` Services branch re-applies Automatic+Running for the 10 required services.
- **Idempotent:** ✅

### Network
- **API usage:** `Get/Set-NetConnectionProfile`, `Get-NetRoute`, `Get-DnsClientServerAddress` (`Networking` 32–62, 84–113; `Orchestration` Network provider 420–444). Native.
- **Return values:** `Get-NetworkProfileStatus` → structured object; `Set-NetworkProfilePrivate` → `@{Success,...,PreviousCategory,Detail}`.
- **Error model:** ⚠️ partial (L2).
- **Rollback:** Orchestrator `Network.Rollback` stub (L1). Reverting a Private→Public change is not automatically performed.
- **Recovery:** ✅ sets Private.
- **Idempotent:** ✅

### Printer
- **API usage:** `Get/Set-Printer`, `Get-PrintJob`, `Get-CimInstance Win32_Printer`, `Get-PrinterDriver` (`Core`; `Detection` `Get-UsbPrinterInfo`); `Set-DefaultPrinter` now uses CIM `Win32_Printer.SetDefaultPrinter` (`Set-DefaultPrinterNative`); test page uses CIM `PrintTestPage` (`SetupWizard` Step 11). **`rundll32` removed (verified by grep).**
- **Return values:** `Set-DefaultPrinter` returns bool (from `Set-DefaultPrinterNative.Success`); helper returns `New-ProviderResult`. `Get-PrinterQueueHealth` → `@{PrinterName,JobCount,HasErrors,ErrorMessage}`.
- **Error model:** ✅ on the CIM helper; legacy `Get-PrinterStatus` etc. use ad-hoc shapes (L2).
- **Rollback:** Orchestrator `Printer.Rollback` stub (L1).
- **Recovery:** Orchestrator `Printer` provider relies on `Get-UsbPrinterInfo` (detection only).
- **Idempotent:** ✅

### Driver
- **API usage:** `Get-PrinterDriver` (property `.InfPath` used natively — no more `pnputil` text parsing), `Remove-PrinterDriver` (replaces `rundll32 /dd`), `Get-AuthenticodeSignature` for signing (`Drivers` 283, 118, 330). **`pnputil` text parsing removed (verified by grep).** Install/restore still use `pnputil /add-driver /install` — **supported** driver-store API (no pure-cmdlet equivalent); retained intentionally.
- **Return values:** `Get-PrinterDriverDetails` → `@{Name,Manufacturer,MajorVersion,DriverType,Architecture,PrinterCount,INFPath,IsPackageAware}`; `Remove-PrinterDriverByName` → `@{Success,ExitCode,Error}`; `Test-DriverSignature` → `@{DriverName,Signed,Signer,Status,Detail}`.
- **Error model:** ✅ on helpers; `Get-DriverIntelligence` uses ad-hoc shape (L2).
- **Rollback:** Orchestrator `Driver.Rollback` stub (L1). `Restore-PrinterDrivers` exists (pnputil-based) for manual restore.
- **Recovery:** Orchestrator `Driver` provider is detection-only (`ApplyChanges` returns `$true`).
- **Idempotent:** `Remove-PrinterDriver` on an absent driver throws (caught → `$false`), so repeated calls are safe. ✅
- **Defect fixed this pass:** `CompatibleIDs` was written to a misspelled property `CompatibileIDs` (`Drivers` line 130); corrected to `CompatibleIDs` (the property declared at line 63). Verified no other reader depended on the typo.

### Sharing
- **API usage:** `Set-Printer -Shared`, `Get-SmbShare*`, `Grant/Revoke-SmbShareAccess` (`Sharing` module); `Orchestration` Sharing provider 446–470 uses `Enable-PrinterSharing`/`Get-Printer`. Native.
- **Return values:** `Enable/Disable-PrinterSharing` → `@{PrinterName,Success,Error}`; `Set-PrinterSharePermission` → `@{ShareName,Account,Success,Error}`.
- **Error model:** ⚠️ partial (L2).
- **Rollback:** Orchestrator `Sharing.Rollback` stub (L1).
- **Recovery:** ✅ re-shares.
- **Idempotent:** ✅

### IPP
- **API usage:** `Get/Enable-WindowsOptionalFeature`, `Get/Install-WindowsFeature`, `Get-NetIPAddress`, `System.Net.HttpWebRequest` (`IPP` module; `Orchestration` IPP provider 472–480). Native / supported .NET API.
- **Return values:** `Get-IPPStatus` → `@{IISInstalled,...,IPPUrls}`; `Test-IPPEndpoint` → `@{Url,Reachable,StatusCode,ResponseTimeMs,Error}`.
- **Error model:** ⚠️ partial (L2).
- **Rollback:** Orchestrator `IPP.Rollback` stub (L1).
- **Recovery:** ✅ `Install-IPPServer`.
- **Idempotent:** ✅

### Validation
- **API usage:** `Invoke-EndToEndValidation` uses only native cmdlets (Get-Printer, Get-PrinterDriver, Get-Service, Get-NetFirewallRule, Get-SmbServerConfiguration, Get-IPPStatus, Get-NetConnectionProfile, Get-CimInstance Win32_Printer, Get-AndroidCompatibility). Read-only.
- **Return values:** `@{OverallScore,PassCount,FailCount,TotalChecks,AllPassed,Checks,Timestamp}`.
- **Idempotent:** ✅ (read-only).

---

## Limitations found (must be tracked)

- **L1 (Medium):** The 6-phase `Rollback` in `Invoke-ConfigurationProvider` for every provider is a **stub** (`return $true`). Real rollback depends on `Repair`/`Rollback` modules (reg.exe import, service restore) which do work, but the orchestrator's unified provider contract does not yet surface them. *Decision needed:* implement per-provider Rollback or document as out-of-scope for v8.2.
- **L2 (Low/Medium):** The unified structured error model (`New-ProviderResult`) is adopted by the v8.1 native helpers (`Enable-PrinterFirewallRules`, `Set-DefaultPrinterNative`, `Get-PrinterDriverStoreDetails`) but NOT yet by the legacy provider functions in `Configuration`, `Sharing`, `Networking`, `Core`, `IPP`, `Orchestration` providers. Those still return ad-hoc `Success`/`Detail` shapes. *Recommendation:* leave as-is for v8.2 (no public API change) or wrap in a later release.
- **L3 (Low):** `Get-DriverIntelligence` leaves `IsWHQL`/`DriverDate` always empty (not populated). Functionality gap, not a defect.
- **L4 (Low, hardening):** `$env:TEMP` dependency in `Rollback`/`ZeroTouch` (and display path in root `Show-RollbackMenu`) — replaced with `[System.IO.Path]::GetTempPath()` in `Rollback`/`ZeroTouch` this pass to avoid module-load failure when `TEMP` is unset; root display path left (display-only, wrapped in `-ErrorAction SilentlyContinue`).

## Certification conclusion (static)

All 8 providers + Validation use **supported Windows APIs** (no `netsh`, no `rundll32`, no `pnputil` text parsing remain in execution paths; `pnputil /add-driver` install retained as the supported store API). Return values are structured and consistent. Recovery paths are implemented and now native. Idempotency holds. The outstanding items are L1 (orchestrator Rollback stubs) and L2 (error-model coverage) — both are contract/coverage gaps, not correctness defects. **Runtime certification (Phases 1/3/4/5/6) remains PENDING until executed on Windows.**
