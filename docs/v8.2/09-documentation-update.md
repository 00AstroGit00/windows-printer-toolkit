# v8.2 Documentation Update Plan (Phase 9)

**Status: PLANNED — not yet executed.** User-facing documentation (README, module
comment-based help, the v8.2 changelog) must be updated to reflect v8.1/v8.2. This phase
is intentionally deferred until the runtime evidence is in, so docs do not overstate status.

## Items
1. **README.md**
   - Add "Requirements" section: Windows 10 22H2+ / 11, PowerShell 5.1 or 7.x, Administrator.
   - Note: native-API implementation (no netsh/rundll32); driver install via pnputil store API.
   - Link to `docs/v8.2/` certification + compatibility matrix.

2. **CHANGELOG / version**
   - Bump root `PrinterToolkit.psm1` from `8.1.0` to `8.2.0` at sign-off.
   - Add CHANGELOG entry: v8.1 (native integration) + v8.2 (certification, security, compat,
     defect fixes: CompatibleIDs typo, TEMP robustness).

3. **Rollback module manifest**
   - `Modules/Rollback/PrinterToolkit.Rollback.psm1` module version string still reads `8.0.0`
     (cosmetic). Update to 8.2.0 at sign-off.

4. **Comment-based help**
   - Add `.EXAMPLE` + "Requires Administrator" notes to: `Enable-PrinterFirewallRules`,
     `Set-DefaultPrinterNative`, `Get-PrinterDriverStoreDetails`, `Invoke-RecoveryEngine`,
     `Enable-PrinterSharing`, `Install-PrinterDrivers`, `Enable-IPPPrinting`.
   - Document the structured `New-ProviderResult` shape where used.

5. **Known Issues doc** (`docs/v8.2/10-known-issues.md`)
   - L1 orchestrator Rollback stub; L2 partial error-model coverage; L3 IsWHQL not populated;
     KL4 WSD heuristic; KL5 Android requires ADB device.

## Gate
Execute Phase 9 only after the runtime evidence is collected (or explicitly waived), to avoid
documenting behavior that runtime could contradict.
