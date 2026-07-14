# v8.2 Security Review (Phase 7)

**Method:** Static security review of all modules and the orchestrator. No runtime
execution was possible in this environment (Termux/Linux, no Windows). Findings are
from source reading. Severity: Critical / High / Medium / Low / Info.

---

## Scope
- `PrinterToolkit.psm1` (root loader, version 8.1.0)
- `Modules/Providers/PrinterToolkit.Providers.psm1` (v8.1 error model + helpers)
- All `Modules/**/*.psm1` (22 modules)
- `Tests/v8.2.*.ps1` (harness, added this pass)

## Review areas
1. Credential / secret handling
2. Code injection (Invoke-Expression, dynamic script construction)
3. Input validation / trust boundaries
4. Privilege model (admin requirements, least privilege)
5. Network exposure (firewall, sharing, IPP, SMB)
6. Logging / data handling (PII, transcripts)
7. Supply-chain (driver signing)

---

## Findings

### S1 — No secrets or credentials stored in code (PASS)
- No plaintext passwords, API keys, or tokens found in any module.
- Android ADB pairing uses a user-supplied PIN at runtime; not persisted in source (`Android` module).
- Reporting/Logging do not write credentials. ✅

### S2 — No `Invoke-Expression` on untrusted input (PASS)
- No `Invoke-Expression` / `iex` on external or user-supplied strings found in execution paths.
- Dynamic CIM method calls use `Invoke-CimMethod` with parameters — not string-eval. ✅

### S3 — External process use is bounded to supported tools (PASS / INFO)
- `reg.exe` used only for firewall/registry export-import backup/restore (supported).
- `pnputil /add-driver /install` used for driver store install (supported store API).
- `wevtutil` used for event-log backup (supported).
- No shell redirection of untrusted input into these binaries. Args are literal/computed, not user-concatenated strings. ✅

### S4 — Driver supply-chain: signature check present (PASS)
- `Test-DriverSignature` uses `Get-AuthenticodeSignature` (`Drivers` 283) and `Get-PrinterDriverDetails` exposes `IsPackageAware`. ✅
- Remaining gap: `Get-DriverIntelligence.IsWHQL` is not populated (L3) — informational only; the signature check itself works.

### S5 — Privilege model documented but not enforced at import (MEDIUM)
- Several providers (Firewall, Services, Sharing, Driver, Registry) require Administrator.
- No `Requires -RunAsAdministrator` at module scope; `Initialize-Printers` warns only.
- **Recommendation:** add `#Requires -RunAsAdministrator` to the root module or a `-Force` gated admin check, or at minimum document clearly. Low effort; can be added without breaking public API.

### S6 — Network exposure: firewall rules broad (INFO)
- `Enable-PrinterFirewallRules` enables File and Printer Sharing (SMB, RPC, Discovery) + optional IPP. These open inbound ports. This is by-design for printer sharing.
- Rules are scoped to the Private profile where possible; verify during runtime validation (Phase 5) that no rule is opened on Public unintentionally. (Harness captures this.)

### S7 — Logging / transcript PII (INFO)
- Reporting and logging capture host/printer/share names and IPs — consider PII in enterprise environments. No secrets. Recommend a redaction note in the reporting module for production (out of v8.2 scope unless required).

### S8 — Path handling hardening (LOW, fixed this pass)
- `Rollback` and `ZeroTouch` used `$env:TEMP` directly, which would throw at module load if `TEMP` is unset. Replaced with `[System.IO.Path]::GetTempPath()`. ✅
- Root module display path of rollback menu still uses `$env:TEMP` (display-only) — wrapped in `-ErrorAction SilentlyContinue`.

### S9 — `rundll32` / `netsh` removal reduces attack surface (PASS)
- All `rundll32 printui.dll` and `netsh` calls eliminated in v8.1; now use CIM/WMI/NetSecurity cmdlets. Fewer external binaries invoked = smaller attack surface. ✅

---

## Severity summary
| ID | Severity | Status |
|---|---|---|
| S1 | Info | Pass |
| S2 | Info | Pass |
| S3 | Info | Pass |
| S4 | Info | Pass |
| S5 | Medium | Open (recommend fix) |
| S6 | Info | Verify at runtime |
| S7 | Info | Out of scope v8.2 |
| S8 | Low | Fixed |
| S9 | Info | Pass |

**No Critical/High security findings.** Only S5 (privilege enforcement) is actionable; recommend adding a guarded admin check before v8.2 sign-off. Everything else is informational or already passing.
