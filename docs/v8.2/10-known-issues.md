# v8.2 Known Issues

Compiled from certification (L*), compatibility (KL*), and security (S*) reviews.
Severity in parentheses.

| ID | Severity | Area | Description | Workaround / Status |
|---|---|---|---|---|
| L1 | Medium | Orchestrator | Per-provider `Rollback` phase is a stub (`return $true`); true rollback handled by `Repair`/`Rollback` modules, not the provider contract. | Use `Invoke-RepairRollback` / `Initialize-RepairBackup`. Decide: implement or document out-of-scope. |
| L2 | Low | Error model | `New-ProviderResult` adopted by v8.1 helpers only; legacy providers (`Configuration`, `Sharing`, `Networking`, `Core`, `IPP`, orchestrator providers) still return ad-hoc `Success`/`Detail`. | Wrap in later release; no public API change needed. |
| L3 | Low | Drivers | `Get-DriverIntelligence.IsWHQL` and `DriverDate` are never populated. | Informational only; signature check via `Test-DriverSignature` works. |
| KL4 | Low | Detection | WSD printer detection is heuristic/best-effort. | Manual confirmation recommended. |
| KL5 | Low | Android | Android ADB connectivity requires a device + ADB; not testable in CI. | Manual device test. |
| S5 | Medium | Privilege | No `#Requires -RunAsAdministrator`; admin requirement only warned. | Run elevated; recommend adding guarded admin check before GA. |
| Cosmetic | Info | Rollback module | `PrinterToolkit.Rollback.psm1` module version string reads `8.0.0`. | Update to 8.2.0 at sign-off. |

## Resolved this pass
- **Defect:** `CompatibleIDs` written to misspelled `CompatibileIDs` in `Drivers` — fixed.
- **Hardening:** `$env:TEMP` in `Rollback`/`ZeroTouch` replaced with `[System.IO.Path]::GetTempPath()` to avoid module-load failure when `TEMP` unset.
