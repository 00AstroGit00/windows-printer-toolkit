# Migration Guide: v4.0 → v5.0

## Overview

v5.0 is a certification and hardening release. All public function signatures remain backward-compatible with v4.1.

If you are upgrading from **v4.0**, note the following function renames that occurred during the v4.1 production hardening (which v5.0 inherits):

## Renamed Functions (v4.0 → v4.1/v5.0)

| Old Name (v4.0) | New Name (v5.0) |
|----------------|-----------------|
| `Get-PrinterInventory` | `Get-Printers` |
| `Get-PrinterExtendedDetails` | `Get-PrinterStatus` |
| `Restart-PrintSpooler` | `Restart-Spooler` |
| `Get-IPPPrinterAttributes` | `Get-IPPStatus` |
| `Test-IPPConnection` | `Test-IPPEndpoint` |
| `Get-IPPClassDrivers` | `Test-IPPClientInstalled` |
| `Write-ToolkitLog` | `Write-Log` |
| `Get-ToolkitLog` | `Get-LogContent` |
| `Test-MopriaCompatibility` | `Show-AndroidWizard` |
| `Get-AndroidPrintServices` | `Get-AndroidCompatibility` |
| `Get-EventLogAnalysis` | Use `New-DiagnosticBundle` instead |
| `Test-SpoolerIntegrity` | `Get-PrinterQueueHealth` |
| `Get-WSDPrinters` | Use `Get-NetworkValidation` instead |
| `Test-SmbConfiguration` | Use `Export-ServiceSnapshot` instead |

## Breaking Changes

None. v5.0 adds files (README, LICENSE, templates, CERTIFICATION) and fixes security issues in existing code paths. All 55 exported functions retain their v4.1 signatures.

## Security Fixes

- `launcher.ps1`: `Invoke-Expression` replaced with allowlist-based command execution
- `Set-DefaultPrinter`: Printer name now validated with `[ValidatePattern]`
- `Remove-PrinterDriverByName`: Driver name now validated with `[ValidatePattern]`
- `Install-PrinterDriverFromInf`: INF path validated, resolved, and restricted to `.inf` extension
- `Restore-PrinterDrivers`: Source path validated and resolved before traversal
- `Export-RegistrySnapshot`: Temp directory uses random name (prevents TOCTOU race)
- All `Read-Host` inputs in interactive menu validated at point of entry

## New Files

- `README.md` — Professional project documentation
- `LICENSE` — MIT License
- `SECURITY.md` — Security policy and vulnerability reporting
- `CERTIFICATION.md` — Full production certification report
- `MIGRATION.md` — This guide
- `.github/ISSUE_TEMPLATE/bug_report.md`
- `.github/ISSUE_TEMPLATE/feature_request.md`
- `.github/pull_request_template.md`
- `.gitattributes`
- `.gitignore`

## Upgrade Steps

1. Replace the entire `PrinterToolkit/` directory with v5.0
2. Run `.\launcher.ps1` to verify the menu loads
3. Run `Invoke-Pester .\Tests\PrinterToolkit.Tests.ps1` to verify all 46 tests pass
4. Review `CERTIFICATION.md` for full audit details
