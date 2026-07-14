# v8.2 Runtime Validation Report (Phases 1, 3, 4, 5, 6)

**Status: PENDING — cannot execute in this environment.** This host is Termux/Linux
with PowerShell 7.6.3 and no Windows, no printers, no Pester, and no networking to a
Windows client. Runtime certification must be performed on a real Windows host using
the harness scripts delivered in `Tests/`.

This document defines WHAT must be collected, HOW (the harness), and the PASS/FAIL
criteria, so the evidence can be attached when the Windows host is available.

---

## Harness delivered
| Script | Phase(s) | Collects |
|---|---|---|
| `Tests/v8.2.RuntimeValidation.ps1` | 1,3,4,6 | Transcript + `summary.json`: import, provider loading, orchestrator startup, diagnostics, validation, reporting, rollback init, Android connectivity, connection info |
| `Tests/v8.2.FailureInjection.ps1` | 5 | `failure_injection.json`: 5 injected failure scenarios + repair + verify |
| `Tests/v8.2.Benchmark.ps1` | 6 | `benchmark.json`: avg/min/max ms for 6 benchmarks × N iterations |
| `Tests/v8.2.ProviderCert.Tests.ps1` | 2 | Pester static/unit checks (skips on non-Windows) |

## How to run (per target OS × PowerShell)
```
# Run as Administrator from a PowerShell 5.1 and a 7.x prompt on each OS:
pwsh .\Tests\v8.2.RuntimeValidation.ps1 -OutDir C:\v82\Win11_23H2\PS7\run
pwsh .\Tests\v8.2.FailureInjection.ps1 -OutDir C:\v82\Win11_23H2\PS7\fail
pwsh .\Tests\v8.2.Benchmark.ps1 -Iterations 5 -OutDir C:\v82\Win11_23H2\PS7\perf
```
Targets: Win10 22H2, Win11 23H2, Win11 24H2 × {PS5.1, PS7.x}.

## Phase 1 — Native Windows Integration (re-validation)
**Criteria:** all providers import on Windows; zero `netsh`/`rundll32`/`pnputil`-parse calls.
**Evidence:** `summary.json` `ModuleImport` + `ProviderLoading` steps; manual grep on the
imported module (must show no blocked APIs).
**Expected:** PASS (already proven statically; runtime confirms import succeeds on real OS).

## Phase 3 — Real Printer & Driver Integration
**Criteria:** enumerate a real USB/network printer; install a signed driver package via
`Install-PrinterDrivers`; `Get-DriverIntelligence` returns populated fields; `Test-DriverSignature` PASS.
**Evidence:** `report/` output from RuntimeValidation `Reporting` step; manual screenshot of
`Get-Printer`/`Get-PrinterDriver`.
**Expected:** PASS (dependent on a physical/VM printer available on the host).

## Phase 4 — Client Connectivity / Sharing / IPP
**Criteria:** a second Windows client can connect to the shared/ IPP printer; firewall rules
allow; SMB share permission resolves.
**Evidence:** `Get-ConnectionInfo` + client-side `Connect-NetworkPrinter` success; `Get-NetFirewallRule`
shows rules Enabled (Private).
**Expected:** PASS (requires two hosts or a VM client).

## Phase 5 — Failure Injection & Recovery
**Criteria (from harness scenarios):**
1. Stopped Spooler → orchestrator/recovery restarts it (verify `Status -eq Running`).
2. Firewall disabled → `Enable-PrinterFirewallRules` re-enables (verify rule Enabled count > 0).
3. Network Profile on Public → set Private (verify category).
4. Missing IPP feature → reported, no crash.
5. Missing driver → `Get-DriverIntelligence` reports DriverFound=$false, no crash.
**Evidence:** `failure_injection.json`.
**Expected:** scenarios 1–3 recover (the harness remediates directly where the provider stub
does not); 4–5 graceful degradation. NOTE: because orchestrator `Rollback` is a stub (L1),
scenario recovery is currently provided by the `Repair`/`RecoveryEngine` modules, not the
provider contract. Document this in the failure-injection report.

## Phase 6 — Performance Benchmark
**Criteria:** module import < 3s; orchestrator startup < 1s; validation < 5s; full diagnostics < 10s
on a typical host. Thresholds are indicative; capture real numbers.
**Evidence:** `benchmark.json`.
**Expected:** PASS with captured numbers; flag if any benchmark exceeds 2× the stated threshold.

---

## Evidence checklist (attach when complete)
- [ ] `summary.json` × 6 (3 OS × 2 PS)
- [ ] `report/` folder × 6
- [ ] `failure_injection.json` × 6
- [ ] `benchmark.json` × 6
- [ ] Manual `Get-Printer`/`Get-PrinterDriver` capture for Phase 3
- [ ] Client connectivity confirmation for Phase 4

**Do NOT mark v8.2 GA until all six `summary.json` files show zero import errors and the
failure-injection + benchmark JSON are attached.**
