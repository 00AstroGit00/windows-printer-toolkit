# PrinterToolkit v8.2.0-rc1 — External QA Validation Guide

## Purpose

This guide provides third-party testers with the instructions and context
needed to independently validate PrinterToolkit on a Windows host. The
release is a **Release Candidate** — runtime evidence has not been
collected on any Windows target. Static certification is complete.

## Scope

- **Target OS:** Windows 10 22H2, Windows 11 23H2, Windows 11 24H2
- **PowerShell:** 5.1 (built-in), 7.x (any 7.x)
- **Printer types:** USB (real), Network (real), None (validation-only)
- **Validation phases:** Module import, provider certification, runtime
  validation, failure injection, performance benchmarks

## Prerequisites

1. A Windows machine matching one of the target OS versions.
2. PowerShell 5.1+ (7.x recommended for richer output).
3. Administrator access.
4. Pester module installed (`Install-Module Pester -Force -Scope CurrentUser`).
5. (Optional) A USB printer and/or network printer for end-to-end tests.
6. (Optional) A second LAN client to verify connectivity.

## Getting Started

```powershell
# 1. Clone or extract the repository
cd PrinterToolkit

# 2. Run the certification harness (elevated)
.\Start-Certification.ps1
```

The harness will:
- Verify prerequisites
- Execute all validation scripts in sequence
- Collect evidence into a timestamped directory
- Generate HTML/MD/JSON summary reports
- Package everything into a ZIP archive

## What is Tested

| Phase | Script | What it validates |
|-------|--------|-------------------|
| 1 | `Tests\PrinterToolkit.Tests.ps1` | Module loading, exported functions, parameter contracts |
| 2 | `Tests\v8.2.ProviderCert.Tests.ps1` | All 8 configuration providers (Service, Firewall, Network, Sharing, IPP, Registry, Driver, Printer) |
| 3 | `Tests\v8.2.RuntimeValidation.ps1` | Module import, diagnostics, validation, reporting, sharing, IPP, SMB, client connectivity |
| 4 | `Tests\v8.2.FailureInjection.ps1` | Recovery from: missing printer, firewall blocked, spooler stopped, driver issues, network problems |
| 5 | `Tests\v8.2.Benchmark.ps1` | Import time, validation, diagnostics, reporting, orchestration, zero-touch (5 iterations) |

## What is NOT Tested (Out of Scope)

- Cross-platform (non-Windows) execution
- Android ADB connectivity (requires physical device)
- Print server clustering / load balancing
- Active Directory integration
- Direct TCP/IP port printing
- Third-party driver signing authorities
- ARM64 Windows

## Reporting Issues

Use the template in `Certification/06-ISSUE_REPORTING_TEMPLATE.md`.
