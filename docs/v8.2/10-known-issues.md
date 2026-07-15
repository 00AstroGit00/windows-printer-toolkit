# v8.2 Known Issues

Compiled from certification (L*), compatibility (KL*), and security (S*) reviews.
Severity in parentheses.

| ID | Severity | Area | Description | Workaround / Status |
|---|---|---|---|---|---|
| L2 | Low | Error model | `New-ProviderResult` adopted by v8.1 helpers only; legacy providers (`Configuration`, `Sharing`, `Networking`, `Core`, `IPP`, orchestrator providers) still return ad-hoc `Success`/`Detail`. | Wrap in later release; no public API change needed. |
| L3 | Low | Drivers | `Get-DriverIntelligence.IsWHQL` and `DriverDate` are never populated. | Informational only; signature check via `Test-DriverSignature` works. |
| KL4 | Low | Detection | WSD printer detection is heuristic/best-effort. | Manual confirmation recommended. |
| KL5 | Low | Android | Android ADB connectivity requires a device + ADB; not testable in CI. | Manual device test. |

## Resolved this pass
- **L1 (Medium):** Per-provider `Rollback` phase now captures pre-state and restores original configuration for Service, Firewall, Network, Sharing, IPP, and Registry providers. Driver and Printer providers remain no-ops (no state changes).
- **S5 (Medium):** Admin elevation check added to root module load (warns if not elevated), plus confirmation in UI.
- **Cosmetic:** All version strings harmonized to `8.2.0` across root psd1, psm1, Utilities, ZeroTouch, Rollback, and Providers modules.
- **Defect:** `CompatibleIDs` written to misspelled `CompatibileIDs` in `Drivers` — fixed.
- **Hardening:** `$env:TEMP` in `Rollback`/`ZeroTouch` replaced with `[System.IO.Path]::GetTempPath()` to avoid module-load failure when `TEMP` unset.
