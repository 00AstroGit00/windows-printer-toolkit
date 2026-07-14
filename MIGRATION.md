# Migration Guide: v4.0 → v5.0.1

## Overview

v5.0.1 is the certification release following an independent adversarial audit. All public function signatures remain backward-compatible with v4.1.

If you are upgrading from **v4.0**, note the following function renames that occurred during the v4.1 production hardening (which v5.0.1 inherits):

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

**v5.0.1 only:** `Clear-PrintQueue` now requires `-Force` to skip the confirmation prompt. `Restart-Spooler` now returns `[PSCustomObject]` instead of `[bool]`. If you piped `Restart-Spooler` to a boolean check, update to check `$result.Success`.

Otherwise: v5.0.1 adds files and fixes security/issues in existing code paths. All 55 exported functions retain their v4.1 signatures except as noted above.

## v5.0.1 Changes

- `Clear-PrintQueue`: Added `-Force` parameter and confirmation prompt; added elevation check
- `Restart-Spooler`: Now returns `[PSCustomObject]` with `Success`, `Stopped`, `Started`, `Timestamp`
- `Get-PrinterQueueHealth`: Now queries actual print jobs via `Get-PrintJob` instead of returning hardcoded values
- `Get-PrinterReportData.IsDefault`: Now correctly identifies the default printer
- 9 destructive operations now call `Assert-Elevated` before executing
- Bootstrap installer (`install.ps1`) now verifies SHA-256 checksums

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

1. Replace the entire `PrinterToolkit/` directory with v5.0.1
2. Run `.\launcher.ps1` to verify the menu loads
3. Run `Invoke-Pester .\Tests\PrinterToolkit.Tests.ps1` to verify all 49 tests pass
4. Review `CERTIFICATION.md` for full audit details
