# Changelog — Printer Toolkit v8.2 (in progress)

> Status: **Release Candidate candidate — runtime evidence pending.** Static certification
> complete; runtime phases 1/3/4/5/6 require a Windows host (see `docs/v8.2/`).

## v8.1.0 (delivered earlier this session)
- **Native Windows Integration Layer.** Replaced all fragile shell-executable and
  string-parsing call sites with supported Windows APIs:
  - `netsh` (×5) → `Enable-PrinterFirewallRules` (NetSecurity cmdlets).
  - `rundll32 printui.dll /y` → CIM `Win32_Printer.SetDefaultPrinter`.
  - `rundll32 printui.dll /k` → CIM `Win32_Printer.PrintTestPage`.
  - `rundll32 printui.dll /dd` → `Remove-PrinterDriver`.
  - `pnputil` text parsing (×3) → `Get-PrinterDriver.InfPath` + `Get-AuthenticodeSignature`.
- New `Modules/Providers/PrinterToolkit.Providers.psm1` with unified
  `New-ProviderResult` error model and native helpers
  (`Enable-PrinterFirewallRules`, `Set-DefaultPrinterNative`,
  `Get-PrinterDriverStoreDetails`).
- Orchestrator (`Invoke-ConfigurationProvider` 6-phase model) unchanged and stable.
- `docs/v8.1-provider-matrix.md` written.

## v8.2.0 (this session — static portion)
- **Provider Certification (Phase 2):** static review of all 8 providers + Validation.
  All use supported APIs; structured returns; native recovery; idempotent. Two tracked
  limitations: L1 (orchestrator Rollback stub) and L2 (error-model partial coverage).
- **Security Review (Phase 7):** no Critical/High findings. Removed `rundll32`/`netsh`
  reduced attack surface; driver signature check present; bounded external-tool use.
- **Compatibility Matrix (Phase 8):** Windows 10 22H2 / 11 23H2 / 24H2 × PS 5.1/7.x;
  native module availability; printer/driver ecosystem; known limitations.
- **Defect fixes (verified, no public API change):**
  - `Drivers`: `CompatibleIDs` typo (`CompatibileIDs`) corrected.
  - `Rollback`/`ZeroTouch`: `$env:TEMP` → `[System.IO.Path]::GetTempPath()` (module-load robustness).
- **Harness delivered (Tests/):** `v8.2.ProviderCert.Tests.ps1`, `v8.2.RuntimeValidation.ps1`,
  `v8.2.FailureInjection.ps1`, `v8.2.Benchmark.ps1`.
- **Deliverables (docs/v8.2/):** provider certification, security review, compatibility
  matrix, runtime-validation plan, performance-benchmark plan, failure-injection plan,
  release checklist, production-readiness assessment, documentation plan, known issues.

## Pending (blocked on Windows host)
- Runtime evidence for Phases 1, 3, 4, 5, 6.
- Version bump to 8.2.0 (root + Rollback manifest) at sign-off.
- User-facing doc updates (Phase 9).
- Commit of branch `feature/v8-orchestration-engine`.
