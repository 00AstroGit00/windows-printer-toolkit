<div align="center">

# PrinterToolkit

**Enterprise Windows Printer Management Toolkit**

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell&logoColor=white)](https://github.com/PowerShell/PowerShell)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11%20%7C%20Server%202022%2B-brightgreen?logo=windows&logoColor=white)](https://www.microsoft.com/windows)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)
[![Version](https://img.shields.io/badge/Version-5.0.1-brightgreen)](#)
[![PRs Welcome](https://img.shields.io/badge/PRs-Welcome-orange)](#)
[![CI](https://img.shields.io/badge/CI-GitHub%20Actions-blue?logo=githubactions&logoColor=white)](.github/workflows/ci.yml)

**Modular PowerShell toolkit for printer inventory, IPP discovery, driver intelligence (Type 3/4), Android Mopria compatibility, automatic share repair, diagnostic bundles, and professional reporting — all through an interactive dashboard or direct command-line invocation.**

</div>

---

## One-Liner (Run Without Installing)

```powershell
powershell -ExecutionPolicy Bypass -Command "iwr -Uri https://github.com/00AstroGit00/windows-printer-toolkit/raw/main/install.ps1 -OutFile \"$env:TEMP\ptk.ps1\"; & \"$env:TEMP\ptk.ps1\""
```

This downloads the latest release, extracts it to a temporary folder, imports the module, opens the interactive dashboard, and cleans up on exit. No permanent installation required.

> **Note:** The dashboard requires PowerShell console access. Some operations (repair, drivers, sharing) need Administrator privileges.

---

## Quick Start

### Install Permanently

```powershell
# Clone or download the repository
git clone https://github.com/00AstroGit00/windows-printer-toolkit.git
cd windows-printer-toolkit/PrinterToolkit

# Launch interactive dashboard
.\launcher.ps1

# Or import as a module for scripting
Import-Module .\PrinterToolkit.psd1
Get-Printers | Format-Table Name, Shared, PortName, DriverName
Get-ToolkitStatus

# Run a single command
.\launcher.ps1 -CommandLine -Command "New-DiagnosticBundle"
```

### Run From Release ZIP

```powershell
# Download from releases
iwr -Uri https://github.com/00AstroGit00/windows-printer-toolkit/releases/latest/download/PrinterToolkit_v5.0.1.zip -OutFile "$env:TEMP\ptk.zip"
Expand-Archive "$env:TEMP\ptk.zip" -DestinationPath "$env:TEMP\ptk"
Import-Module "$env:TEMP\ptk\PrinterToolkit\PrinterToolkit.psd1" -Force
Invoke-ToolkitMainMenu
```

---

## What PrinterToolkit Does

PrinterToolkit is a **complete Windows printer management solution** for IT administrators, helpdesk technicians, and power users. It replaces the need to navigate through Control Panel, Services console, Firewall settings, Registry Editor, Device Manager, and Event Viewer individually — consolidating everything into a single interactive dashboard.

### Key Capabilities

| Area | What It Does |
|------|-------------|
| **Printer Management** | Inventory all installed printers, view detailed status, set defaults, manage print queues, restart spooler |
| **IPP Discovery** | Detect Internet Printing Protocol support, generate IPP URLs for network/Android clients, validate endpoints, install IPP server role |
| **Driver Intelligence** | Detect Type 3 vs Type 4 drivers, export driver manifests with INF files, restore from backup, install from INF, get migration recommendations |
| **Share Management** | Enable/disable sharing, set share permissions, switch transport protocols (SMB/IPP/WSD), check compatibility |
| **Android Printing** | Mopria Print Service compatibility wizard, generate IPP/SMB connection strings for Android devices, verify firewall and network configuration |
| **Automatic Repair** | 8-step repair workflow with full backup and rollback — backs up registry, services state, and printer configuration before making changes |
| **Diagnostics** | Comprehensive network validation (17 checks across services, firewall, registry, printers, queue), firewall/registry/service snapshots |
| **Reporting** | Professional HTML reports with CSS styling and summary statistics, JSON exports for programmatic use, CSV for spreadsheet analysis, compliance checks |
| **Diagnostic Bundle** | Collect everything — system info, printers, drivers, ports, registry keys, firewall rules, network config, SMB settings, services, event logs — into a single ZIP archive |

---

## Interactive Dashboard

```
╔══════════════════════════════════════════╗
║       PrinterToolkit v5.0.1             ║
║   Enterprise Printer Management          ║
╚══════════════════════════════════════════╝

  [1]  Printer Inventory
  [2]  Printer Details & Status
  [3]  Network Printer Discovery
  [4]  Printer Connectivity Test
  [5]  Manage Print Queue
  [6]  IPP Printer Attributes
  [7]  IPP Client Detection
  [8]  Driver Management            ──┐
  [9]  Driver Upgrade Recommends      ├─ Submenus
  [10] Android / Mopria               │
  [11] Network Validation Report      │
  [12] Spooler Queue Health           │
  [13] Firewall & Network             │
  [14] Registry & Service Snapshots   │
  [15] Automatic Share Repair         │
  [16] Share Management              ──┘
  [17] Generate Report
  [18] Compliance Report
  [19] Diagnostic Bundle
  [0]  Exit
```

---

## Architecture

```
PrinterToolkit/
├── PrinterToolkit.psd1          # Module manifest (55 exported functions)
├── PrinterToolkit.psm1          # Root loader + interactive menu
├── launcher.ps1                 # Standalone entry point
├── install.ps1                  # Bootstrap downloader & runner
├── Modules/                     # 11 specialized submodules
│   ├── Core/                    # Spooler, queue, printer enumeration
│   ├── IPP/                     # Internet Printing Protocol
│   ├── Logging/                 # Structured logging framework
│   ├── Utilities/               # Admin check, system info, UI helpers
│   ├── Android/                 # Mopria compatibility wizard
│   ├── Diagnostics/             # Network validation + snapshots
│   ├── Repair/                  # 8-step automatic share repair
│   ├── Drivers/                 # Type 3/4 detection, INF management
│   ├── Sharing/                 # SMB/IPP/WSD transport, permissions
│   ├── Reporting/               # HTML/JSON/CSV reports
│   └── Bundle/                  # Diagnostic ZIP archive
├── Tests/                       # Pester unit tests (49 tests)
├── CI/                          # Build & release scripts
└── .github/workflows/           # GitHub Actions CI/CD
```

---

## Requirements

- **OS:** Windows 10 (21H2+), Windows 11 (22H2+), or Windows Server 2022+
- **PowerShell:** 5.1 or 7.x (7.4 recommended)
- **Administrator rights:** Required for spooler operations, driver management, repair, sharing, and firewall changes
- **Internet:** Only needed for the one-liner bootstrap installer

---

## Test Suite

```powershell
Invoke-Pester -Path .\Tests\PrinterToolkit.Tests.ps1
```

49 tests covering all 11 modules, export validation, error handling, and return type contracts.

---

## Build & Package

```powershell
.\CI\build.ps1 -Configuration Release
.\CI\package.ps1 -ArtifactPath .\artifacts\PrinterToolkit_v5.0.1_<timestamp>
```

---

## Certification

PrinterToolkit v5.0.1 has undergone production certification:

- **Security review:** 12 findings identified and remediated (3 critical, 4 high)
- **Repository audit:** All 55 exports, 20 menu options, 11 module paths verified
- **Production readiness score:** 93/100

See [CERTIFICATION.md](CERTIFICATION.md) for the v5.0.1 audit report.

---

## License

MIT — see [LICENSE](LICENSE)

---

## Support

- [GitHub Issues](https://github.com/00AstroGit00/windows-printer-toolkit/issues) — Bug reports & feature requests
- [Security Policy](SECURITY.md) — Vulnerability reporting
