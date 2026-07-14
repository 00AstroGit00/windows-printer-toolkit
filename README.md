# PrinterToolkit

> Enterprise Windows Printer Troubleshooting & Management Toolkit

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell)
![Platform](https://img.shields.io/badge/Platform-Windows-brightgreen?logo=windows)
![License](https://img.shields.io/badge/License-MIT-green)
![Version](https://img.shields.io/badge/Version-5.0-brightgreen)
![PRs](https://img.shields.io/badge/PRs-Welcome-orange)

## Overview

PrinterToolkit is a modular PowerShell toolkit for enterprise Windows printer management. It provides printer inventory, diagnostics, IPP discovery, Android/Mopria compatibility, automatic share repair, driver intelligence, and professional reporting — all through an interactive menu or direct command-line invocation.

## Features

| Area | Capabilities |
|------|-------------|
| **Printer Management** | Inventory, status, default printer, queue management, spooler control |
| **IPP** | Client/server detection, URL generation, endpoint validation, IIS integration |
| **Diagnostics** | Network validation (services, firewall, printers), registry/event log analysis |
| **Repair** | 8-step automatic repair with backup/rollback, spooler recovery, share verification |
| **Drivers** | Type 3/4 detection, manifest export/restore, INF installation, migration recommendations |
| **Sharing** | SMB/IPP/WSD transport switching, share permissions, compatibility warnings |
| **Android** | Mopria compatibility wizard, IPP/SMB connection strings, firewall/network checks |
| **Reporting** | HTML/JSON/CSV reports, compliance checks, health scores |
| **Bundle** | Full diagnostic ZIP with system info, printers, drivers, registry, firewall, SMB, events |

## Quick Start

```powershell
# Interactive menu
.\launcher.ps1

# Import as module
Import-Module .\PrinterToolkit.psd1
Get-Printers | Format-Table Name, Shared, PortName, DriverName

# Single command
.\launcher.ps1 -CommandLine -Command "Get-PrinterDriverDetails | Format-Table Name, DriverType"
```

## Requirements

- **OS:** Windows 10/11 (21H2+) or Windows Server 2022+
- **PowerShell:** 5.1 or 7.x
- **Administrator:** Required for management operations (repair, drivers, sharing)

## Module Structure

```
PrinterToolkit/
├── PrinterToolkit.psd1          # Module manifest
├── PrinterToolkit.psm1          # Root loader + interactive menu
├── launcher.ps1                 # Standalone entry point
├── Modules/
│   ├── Core/                    # Spooler, queue, printer enumeration
│   ├── IPP/                     # Internet Printing Protocol
│   ├── Logging/                 # Structured logging framework
│   ├── Utilities/               # Admin check, system info, UI helpers
│   ├── Android/                 # Mopria compatibility
│   ├── Diagnostics/             # Network validation, registry/firewall snapshots
│   ├── Repair/                  # 8-step automatic share repair
│   ├── Drivers/                 # Type 3/4 detection, export/restore
│   ├── Sharing/                 # SMB/IPP/WSD transport, permissions
│   ├── Reporting/               # HTML/JSON/CSV reports
│   └── Bundle/                  # Diagnostic ZIP archive
├── Tests/                       # Pester tests
├── CI/                          # Build and package scripts
└── .github/workflows/           # GitHub Actions CI
```

## Menu Options

```
  [1]  Printer Inventory
  [2]  Printer Details & Status
  [3]  Network Printer Discovery
  [4]  Printer Connectivity Test
  [5]  Manage Print Queue
  [6]  IPP Printer Attributes
  [7]  IPP Client Detection
  [8]  Driver Management
  [9]  Driver Upgrade Recommendations
  [10] Android / Mopria
  [11] Network Validation Report
  [12] Spooler Queue Health
  [13] Firewall & Network
  [14] Registry & Service Snapshots
  [15] Automatic Share Repair
  [16] Share Management
  [17] Generate Report
  [18] Compliance Report
  [19] Diagnostic Bundle
  [0]  Exit
```

## Documentation

- **[CHANGELOG](CHANGELOG.md)** — Version history
- **[LICENSE](LICENSE)** — MIT License

## Build & Test

```powershell
# Run tests
Invoke-Pester -Path .\Tests\PrinterToolkit.Tests.ps1

# Build package
.\CI\build.ps1 -Configuration Release

# Package release
.\CI\package.ps1 -ArtifactPath .\artifacts\PrinterToolkit_v5.0_<timestamp>
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/new-thing`)
3. Commit changes (`git commit -am 'Add new thing'`)
4. Push (`git push origin feature/new-thing`)
5. Open a Pull Request

See the [GitHub Issues](https://github.com/PrinterToolkit/PrinterToolkit/issues) for planned features and known issues.

## License

MIT — see [LICENSE](LICENSE)
