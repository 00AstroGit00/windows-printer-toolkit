# PrinterToolkit v8.2.0-rc1 — Environment Requirements

## Minimum Requirements

| Component | Requirement |
|-----------|-------------|
| **Operating System** | Windows 10 22H2 or later (x64) |
| **Windows Edition** | Pro, Enterprise, or Education |
| **PowerShell** | 5.1 (built-in) or 7.x |
| **.NET** | .NET Framework 4.8+ (PS 5.1) / .NET 8+ (PS 7.x) |
| **RAM** | 4 GB (8 GB recommended) |
| **Disk** | 500 MB free for toolkit + logs |
| **Network** | Local LAN (for sharing tests) |
| **Privilege** | Local Administrator |

## Recommended for Full Validation

| Component | Recommendation |
|-----------|---------------|
| **USB Printer** | Any PCL/PostScript USB printer |
| **Network Printer** | Any IPP/SMB network printer |
| **Second Client** | Any LAN device (Windows/macOS/Android/Linux) |
| **Pester** | Latest (`Install-Module Pester -Force -Scope CurrentUser`) |
| **PowerShell 7** | Download from https://github.com/PowerShell/PowerShell/releases |

## Software That Must NOT Be Present

| Software | Reason |
|----------|--------|
| Third-party firewall (Norton, McAfee, etc.) | May interfere with Windows Firewall rule tests |
| Print management software (PaperCut, PrinterLogic) | May conflict with printer sharing tests |

## PowerShell Module Prerequisites

The following PowerShell modules are required (all ship with Windows):

| Module | Used By |
|--------|---------|
| `PrintManagement` | Printer cmdlets (Get-Printer, etc.) |
| `NetSecurity` | Firewall cmdlets (Get-NetFirewallRule) |
| `NetConnection` | Network profile cmdlets (Get-NetConnectionProfile) |
| `DISM` | Windows feature management |
| `CimCmdlets` | WMI/CIM access for native printer operations |

## Network Configuration

- Firewall must allow inbound ICMP (for connectivity checks)
- Network profile should be **Private** for full sharing tests
- DNS resolution for local hostname required

## Test Matrix Coverage

| Config | Required? | Notes |
|--------|-----------|-------|
| C1: Win10 22H2, PS 5.1 | Recommended | Baseline |
| C2: Win10 22H2, PS 7.x | Recommended | |
| C3: Win11 23H2, PS 5.1 | Recommended | |
| C4: Win11 23H2, PS 7.x | Recommended | |
| C5: Win11 24H2, PS 5.1 | Recommended | Latest build |
| C6: Win11 24H2, PS 7.x | Recommended | Latest build |
| C7: Physical USB printer | Optional | End-to-end |
| C8: Network printer | Optional | End-to-end |

At minimum, **C6** (Win11 24H2, PS 7.x) should be tested.
