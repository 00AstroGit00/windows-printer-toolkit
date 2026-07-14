<div align="center">

# PrinterToolkit — v8.2.0-rc1

**Enterprise Windows printer management & orchestration toolkit (PowerShell)**

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell&logoColor=white)](https://github.com/PowerShell/PowerShell)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11%20%7C%20Server%202022%2B-brightgreen?logo=windows&logoColor=white)](https://www.microsoft.com/windows)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)
[![Version](https://img.shields.io/badge/Version-8.2.0--rc1-yellow)](#)
[![PRs Welcome](https://img.shields.io/badge/PRs-Welcome-orange)](#)

**Connect USB Printer → Launch PrinterToolkit → Click "Setup Printer" → Everything Automated → Printer Available to Windows, Android & LAN Devices**

</div>

---

> [!IMPORTANT]
> **Release status: `v8.2.0-rc1` (Release Candidate).**
> Static certification (provider certification, security review, compatibility matrix) is **complete**. Runtime validation on Windows 10 / 11 (PowerShell 5.1 + 7.x) is **pending** — it requires a real Windows host with printers, which is not available in the build environment. Do **not** treat this as production-validated until the harness in `Tests/v8.2.*` has been executed on Windows and the evidence collected. See [`docs/v8.2/RELEASE-GATE-REVIEW.md`](docs/v8.2/RELEASE-GATE-REVIEW.md).

---

## One-Liner (Run Without Installing)

```powershell
powershell -ExecutionPolicy Bypass -Command "iwr -Uri https://github.com/00AstroGit00/windows-printer-toolkit/raw/main/install.ps1 -OutFile \"$env:TEMP\ptk.ps1\"; & \"$env:TEMP\ptk.ps1\""
```

Downloads the latest release, imports the module, and opens the interactive dashboard.

---

## What PrinterToolkit Does

Transforms a USB-connected printer into a fully configured, validated, and network-accessible shared printer for Windows, Android, and LAN devices with **one click**.

### User Experience

```
Connect USB Printer
     ↓
Launch PrinterToolkit
     ↓
Click 'W' — Print Server Wizard
     ↓
Step 1:  Detect USB Printer          ✓
Step 2:  Install Driver              ✓
Step 3:  Configure Windows Features  ✓
Step 4:  Configure Registry          ✓
Step 5:  Configure Firewall          ✓
Step 6:  Configure Network           ✓
Step 7:  Share Printer               ✓
Step 8:  Enable IPP                  ✓
Step 9:  Enable SMB                  ✓
Step 10: Validate Everything         ✓
Step 11: Print Test Page             ✓
     ↓
Printer is available to Windows  →  \\ComputerName\PrinterShare
Printer is available to Android  →  ipp://hostname/printers/Printer
Printer is available to LAN      →  SMB / IPP / HTTP
```

### Zero-Touch Deployment

For fully automated setup, launch the toolkit and press **[Z] — Zero-Touch Deployment**.
The engine runs the complete lifecycle with no manual steps:

```
Connect USB Printer
     ↓
Launch PrinterToolkit
     ↓
Click 'Z' — Zero-Touch Deployment
     ↓
Detect  →  Analyze  →  Backup  →  Configure  →  Validate  →  Rollback if needed  →  Report
     ↓
Printer shared automatically; reachable by Windows, macOS, Android & Linux clients
```

Every change is detected, backed up, validated, and rolled back automatically on
failure. A per-deployment transaction log records every operation, change, repair,
validation, and rollback. Use `Get-ZeroTouchDashboard` for a live health overview
and `Get-ClientConnectionInfo` for client-specific connection strings (Windows,
macOS, Android, Linux).

---

## What's New

### v8.1 — Native Windows Integration Layer
All fragile shell-executable and string-parsing call sites were replaced with **supported Windows APIs**:

| Before | After |
|---|---|
| `netsh` (×5 firewall ops) | `NetSecurity` cmdlets via `Enable-PrinterFirewallRules` |
| `rundll32 printui.dll /y` (default printer) | CIM `Win32_Printer.SetDefaultPrinter` |
| `rundll32 printui.dll /k` (test page) | CIM `Win32_Printer.PrintTestPage` |
| `rundll32 printui.dll /dd` (remove driver) | `Remove-PrinterDriver` |
| `pnputil` text parsing (×3) | `Get-PrinterDriver.InfPath` + `Get-AuthenticodeSignature` |

A new `Modules/Providers/PrinterToolkit.Providers.psm1` introduces the unified
`New-ProviderResult` structured error model and native helpers
(`Enable-PrinterFirewallRules`, `Set-DefaultPrinterNative`, `Get-PrinterDriverStoreDetails`).
The orchestration engine (6-phase provider model) is **frozen** and unchanged.

### v8.2 — Enterprise Validation, Certification & Production Hardening (static)
- **Provider Certification** — static review of all 8 providers + Validation: all use supported APIs, structured returns, native recovery, idempotent.
- **Security Review** — no Critical/High findings; reduced attack surface from removing `rundll32`/`netsh`.
- **Compatibility Matrix** — Windows 10 22H2 / 11 23H2 / 24H2 × PowerShell 5.1 / 7.x; native module availability; printer/driver ecosystem.
- **Defect fixes** (verified, no public API change): `Drivers` `CompatibleIDs` typo; `Rollback`/`ZeroTouch` `$env:TEMP` → `[System.IO.Path]::GetTempPath()` robustness.
- **Validation harness** delivered under `Tests/v8.2.*` (requires a Windows host + Pester to execute).

See [`docs/v8.2/`](docs/v8.2/) for the full certification, security, compatibility, and release-gate reports.

---

## Quick Start

### Interactive Dashboard

```powershell
git clone https://github.com/00AstroGit00/windows-printer-toolkit.git
cd windows-printer-toolkit
.\launcher.ps1
```

### Print Server Wizard (11 Steps)

```powershell
Import-Module .\PrinterToolkit.psd1 -Force
Invoke-PrintServerWizard
```

### Validation Dashboard

```powershell
Invoke-EndToEndValidation
```

### Client Connection Information

```powershell
Get-ConnectionInfo
```

---

## Interactive Dashboard

```
╔══════════════════════════════════════════════╗
║       PrinterToolkit v8.2.0-rc1               ║
║   Print Server Deployment Platform           ║
╚══════════════════════════════════════════════╝

  PRINT SERVER WIZARD
  [W]  Launch Print Server Wizard (11 steps)
  [Z]  Zero-Touch Deployment (Click Start Setup)
  [V]  Validation Dashboard

  DETECTION & DRIVERS
  [1]  Printer Inventory
  [2]  Printer Details & Status
  [3]  USB Printer Detection
  [4]  Hardware ID Information
  [5]  Driver Intelligence Engine
  [6]  Driver Management
  [7]  Driver Upgrade Recommendations

  CONFIGURATION
  [8]  Windows Features
  [9]  Windows Services
  [10] Firewall & Network
  [11] Registry & Service Snapshots

  SHARING & CONNECTIVITY
  [12] IPP Printer Attributes
  [13] Share Management
  [14] SMB Configuration
  [15] Android / Mopria
  [16] Connection Info & QR Codes

  DIAGNOSTICS & REPAIR
  [17] Network Validation Report
  [18] Automatic Share Repair
  [19] Rollback Last Repair
  [20] Spooler Queue Health

  REPORTS
  [21] Generate Report
  [22] Compliance Report
  [23] Diagnostic Bundle

  [0]  Exit
```

---

## Architecture

```
PrinterToolkit/
├── PrinterToolkit.psd1              # Module manifest (exported functions)
├── PrinterToolkit.psm1              # Root loader + interactive menu
├── launcher.ps1                     # Standalone entry point
├── install.ps1                      # Bootstrap downloader & runner
├── Modules/                         # 20+ specialized submodules
│   ├── Core/                        # Spooler, queue, printer enumeration, default printer (CIM)
│   ├── Detection/                   # USB printer, VID/PID, Hardware ID detection
│   ├── Configuration/               # Windows Features, Services, Registry inspection
│   ├── Drivers/                     # Driver Intelligence Engine (VID/PID/Type3/4/WHQL), signature check
│   ├── Networking/                  # Network profile, firewall rule management (NetSecurity)
│   ├── IPP/                         # Internet Printing Protocol
│   ├── SMB/                         # SMB protocol configuration
│   ├── Sharing/                     # SMB/IPP/WSD transport, permissions
│   ├── Android/                     # Mopria compatibility + QR codes + connection info
│   ├── Diagnostics/                 # Network validation + snapshots
│   ├── Repair/                      # Automatic Repair Engine (issue→root→backup→repair→validate→rollback)
│   ├── Rollback/                    # Configuration rollback engine
│   ├── Validation/                  # End-to-End Validation Dashboard
│   ├── SetupWizard/                 # 11-step Print Server Configuration Wizard
│   ├── Reporting/                   # HTML/JSON/CSV/Markdown reports
│   ├── Logging/                     # Structured logging framework
│   ├── Utilities/                   # Admin check, system info, UI helpers
│   ├── Bundle/                      # Diagnostic ZIP archive
│   ├── ZeroTouch/                   # One-click deployment lifecycle (Detect→Analyze→Backup→Configure→Validate→Rollback→Report)
│   ├── Orchestration/               # v8 DAG task engine, event bus, state/transaction/recovery managers, config providers
│   └── Providers/                   # v8.1 native helpers + New-ProviderResult error model
├── Tests/                           # Pester unit tests + v8.2 validation harness
├── CI/                              # Build & release scripts
├── Validation/                      # Validation documentation
├── Handover/                        # Maintainer documentation
├── docs/v8.2/                       # v8.2 certification, security, compatibility, release-gate reports
└── dist/                            # Distribution packages (Chocolatey, PSGallery, Scoop, WinGet)
```

---

## Key Modules

### Print Server Wizard (`SetupWizard`)
11-step guided wizard that automates everything: USB detection → driver install → Windows configuration → firewall → network → sharing → IPP → SMB → validation → test page → connection info.

### Validation Dashboard (`Validation`)
End-to-end PASS/FAIL dashboard checking: printer detection, driver, queue, port, spooler, services, registry, firewall, sharing, SMB, IPP, network, Android compatibility, and test page.

### Driver Intelligence Engine (`Drivers`)
Automatically detects VID, PID, Hardware IDs, Compatible IDs, manufacturer, model, driver version, driver type (Type 3/4), architecture, and WHQL status. Verifies driver signing via `Get-AuthenticodeSignature`. Attempts installation through Windows Update, Driver Store, or user-provided INF.

### Configuration Intelligence Engine (`Configuration`)
Inspects Windows Features (Print Services, IPP, SMB), Services (Spooler, RPC, DCOM, Server, Workstation, Discovery), Registry (RpcAuthn, HTTP printing), Firewall (File & Printer Sharing, Network Discovery, IPP), and Network (profile, IPv4/IPv6, DNS, gateway).

### Automatic Repair Engine (`Repair`)
Complete repair cycle: Issue → Root Cause → Backup → Repair → Validate → Success or Rollback. Never leaves partial repairs.

### Client Connectivity (`Android`)
Generates connection strings for Windows (`\\ComputerName\Share`), SMB, IPP (`ipp://hostname/printers/Printer`), HTTP (`http://hostname:631/printers/Printer`), and QR code content for IPP URLs, setup guide, and troubleshooting guide.

### Rollback Engine (`Rollback`)
Creates full restore points (registry, services, printers, network) before any changes. One-command rollback to previous state.

### Orchestration Engine (`Orchestration`)
The v8 execution core (frozen). Every operation is modeled as a declarative **Task** (`New-OrchestrationTask`) carrying `Name`, `Dependencies`, `Prerequisites`, `RetryPolicy`, `RequiredElevation`, `IsCritical`, `CanSkip`, plus `Execute`/`Validate`/`Rollback` script blocks. The orchestrator (`Invoke-Orchestrator`) resolves execution order via a topological DAG (`Get-TopologicalTaskOrder`, with cycle detection), then executes tasks honoring dependencies — skipping tasks whose prerequisites fail or whose dependencies did not complete, retrying per `RetryPolicy`, rolling back failed critical tasks, and invoking the recovery engine (`Invoke-RecoveryEngine`) when possible.

Supporting subsystems:
- **Event Bus** (`Subscribe-OrchestrationEvent` / `Publish-OrchestrationEvent`) — structured, subscribable events for UI/logging.
- **State Manager** (`Set-SubsystemState` / `Get-SubsystemState`) — tracks subsystem health (`Healthy` / `Warning` / `Failed` / `Unknown` / `Pending`).
- **Transaction Engine** (`Start-OrchestrationTransaction` / `Record-TaskTransaction` / `Get-OrchestrationTransactionLog`) — per-task state-transition audit log.
- **Desired-State Model** (`Get-DefaultDesiredState` / `Get-DesiredState`) consumed by **Configuration Providers** (`Invoke-ConfigurationProvider`) that centralize platform configuration for `Service`, `Firewall`, `Network`, `Sharing`, `IPP`, `Registry`, `Driver`, and `Printer`.

`Start-ZeroTouchDeployment` is built on this engine: it constructs a dependency graph (Detect → Driver → Services → Registry/Firewall/Network → Sharing → IPP → Validate → Report) and runs it through `Invoke-Orchestrator`.

---

## Requirements

- **OS:** Windows 10 (22H2+), Windows 11 (23H2 / 24H2), or Windows Server 2022+
- **PowerShell:** 5.1 or 7.x (7.4 recommended)
- **Administrator rights:** Required for all print server operations (not enforced at module load; run elevated)
- **Internet:** Only needed for the one-liner bootstrap installer

---

## Test Suite

Existing unit/integration suite (requires Windows + Pester):

```powershell
Invoke-Pester -Path .\Tests\PrinterToolkit.Tests.ps1
```

v8.2 runtime validation harness (requires a real Windows host with printers):

```powershell
# Run as Administrator from PowerShell 5.1 and 7.x on each target OS
pwsh .\Tests\v8.2.RuntimeValidation.ps1 -OutDir C:\v82\Win11_23H2\PS7\run
pwsh .\Tests\v8.2.ProviderCert.Tests.ps1
pwsh .\Tests\v8.2.FailureInjection.ps1 -OutDir C:\v82\Win11_23H2\PS7\fail
pwsh .\Tests\v8.2.Benchmark.ps1 -Iterations 5 -OutDir C:\v82\Win11_23H2\PS7\perf
```

> These harness scripts **parse cleanly** but have **not yet been executed** in the build environment (no Windows host). Runtime evidence is pending.

---

## Build & Package

```powershell
.\CI\build.ps1 -Configuration Release
.\CI\package.ps1 -ArtifactPath .\artifacts\PrinterToolkit_v8.2.0-rc1_<timestamp>
```

---

## Known Issues

- **Orchestrator `Rollback` phase is a stub.** True rollback is handled by the `Repair`/`Rollback` modules (`Invoke-RepairRollback`), not the provider contract. Tracked as L1 in [`docs/v8.2/10-known-issues.md`](docs/v8.2/10-known-issues.md).
- **Unified error model** (`New-ProviderResult`) is adopted by the v8.1 native helpers; legacy provider functions still return ad-hoc `Success`/`Detail` shapes (L2).
- **`Get-DriverIntelligence`** leaves `IsWHQL`/`DriverDate` unpopulated (informational only; signature check via `Test-DriverSignature` works) (L3).
- **WSD printer detection** is heuristic (KL4).

Full list: [`docs/v8.2/10-known-issues.md`](docs/v8.2/10-known-issues.md).

---

## License

MIT — see [LICENSE](LICENSE)

---

## Support

- [GitHub Issues](https://github.com/00AstroGit00/windows-printer-toolkit/issues) — Bug reports & feature requests
- [Security Policy](SECURITY.md) — Vulnerability reporting
