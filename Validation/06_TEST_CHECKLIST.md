# PrinterToolkit v5.1 — Test Execution Checklist

## Daily Setup

- [ ] Verify test environment matches matrix (OS version, PS version, privilege level)
- [ ] Verify all required printers are installed and reachable
- [ ] Enable PowerShell transcription: `Start-Transcript -Path "$env:USERPROFILE\Desktop\PtkTranscript_<date>.txt"`
- [ ] Initialize Toolkit logging: `Initialize-Logging`
- [ ] Record baseline system state (printer count, spooler status, firewall status)
- [ ] Open defect log for new entries
- [ ] Snapshot VM (if applicable)

## Module Import (IMP)

- [ ] IMP-001: Import from manifest (all environments)
- [ ] IMP-002: Import from PSM1 (Admin environments)
- [ ] IMP-003: Import as Standard User
- [ ] IMP-004: Import with missing submodule

## Bootstrap Installer (BSI)

- [ ] BSI-001: One-liner installer
- [ ] BSI-002: Install with -Keep
- [ ] BSI-003: SHA-256 verification message
- [ ] BSI-004: Fallback to main branch

## Menu Navigation (MEN)

- [ ] MEN-001: All 19 main menu options
- [ ] MEN-002: All 4 submenus
- [ ] MEN-003: Invalid input handling
- [ ] MEN-004: Exit via 0

## Printer Discovery (PDV)

- [ ] PDV-001: Get-Printers returns all printers
- [ ] PDV-002: Get-PrinterStatus detailed output
- [ ] PDV-003: Get-SharedPrinters filters correctly
- [ ] PDV-004: Set-DefaultPrinter

## Queue Management (QMG)

- [ ] QMG-001: Clear-PrintQueue with confirmation
- [ ] QMG-002: Clear-PrintQueue with -Force
- [ ] QMG-003: Clear-PrintQueue non-admin
- [ ] QMG-004: Clear-PrintQueue invalid name

## Spooler Operations (SPL)

- [ ] SPL-001: Stop-Spooler
- [ ] SPL-002: Start-Spooler
- [ ] SPL-003: Restart-Spooler returns status object
- [ ] SPL-004: Spooler ops as non-admin

## Driver Export (DRV)

- [ ] DRV-001: Get-PrinterDriverDetails detects types
- [ ] DRV-002: Get-DriverUpgradeRecommendations
- [ ] DRV-003: Export-PrinterDrivers (CSV + JSON + INF)
- [ ] DRV-004: Export invalid path

## Driver Restore (DRV)

- [ ] DRV-005: Restore-PrinterDrivers
- [ ] DRV-006: Restore invalid path
- [ ] DRV-007: Install-PrinterDriverFromInf
- [ ] DRV-008: Remove-PrinterDriverByName

## Printer Sharing (SHR)

- [ ] SHR-001: Get-PrinterShareStatus
- [ ] SHR-002: Enable-PrinterSharing
- [ ] SHR-003: Get-SmbSharePermissions
- [ ] SHR-004: Get-PrinterSharingCompatibility

## IPP Configuration (IPP)

- [ ] IPP-001: Get-IPPStatus
- [ ] IPP-002: Get-IPPUrls
- [ ] IPP-003: Test-IPPEndpoint
- [ ] IPP-004: Install-IPPServer

## Android Wizard (AND)

- [ ] AND-001: Get-AndroidCompatibility
- [ ] AND-002: Show-AndroidWizard
- [ ] AND-003: Get-AndroidSetupContent
- [ ] AND-004: IPP printers in Android output

## Diagnostics Bundle (DBG)

- [ ] DBG-001: New-DiagnosticBundle creates ZIP
- [ ] DBG-002: Bundle contains 12 sections
- [ ] DBG-003: Bundle creation non-admin
- [ ] DBG-004: Bundle invalid output path

## Reporting (RPT)

- [ ] RPT-001: HTML report renders
- [ ] RPT-002: JSON report valid
- [ ] RPT-003: Compliance report
- [ ] RPT-004: All formats output

## Repair Rollback (REP)

- [ ] REP-001: Initialize-RepairBackup
- [ ] REP-002: Invoke-AutomaticShareRepair 8 steps
- [ ] REP-003: Rollback restores state
- [ ] REP-004: Repair non-admin

## Logging (LOG)

- [ ] LOG-001: Initialize-Logging creates file
- [ ] LOG-002: Write-Log and Get-LogContent
- [ ] LOG-003: Export-LogArchive
- [ ] LOG-004: Level filtering

## Packaging (PKG)

- [ ] PKG-001: build.ps1 without tests
- [ ] PKG-002: build.ps1 with tests
- [ ] PKG-003: package.ps1 creates ZIP
- [ ] PKG-004: ZIP structure correct

## Failure Injection (FIJ)

- [ ] FIJ-001: Stopped spooler
- [ ] FIJ-002: Missing driver
- [ ] FIJ-003: Corrupted queue
- [ ] FIJ-004: Printer disconnected
- [ ] FIJ-005: Firewall disabled
- [ ] FIJ-006: Firewall blocking IPP
- [ ] FIJ-007: Network disconnected
- [ ] FIJ-008: Permission denied
- [ ] FIJ-009: Registry rollback
- [ ] FIJ-010: Missing Windows feature
- [ ] FIJ-011: IPP unavailable
- [ ] FIJ-012: Unexpected exception in menu

## Android Validation (ANV)

- [ ] ANV-001: Mopria printer discovery
- [ ] ANV-002: Mopria print success
- [ ] ANV-003: Samsung Print Service Plugin
- [ ] ANV-004: HP Smart
- [ ] ANV-005: Canon PRINT
- [ ] ANV-006: Brother iPrint&Scan
- [ ] ANV-007: Epson Smart Panel

## Performance Benchmarks (PERF) — 5 iterations each

- [ ] PERF-001: Module import time
- [ ] PERF-002: Printer enumeration
- [ ] PERF-003: Queue cleanup
- [ ] PERF-004: Network validation
- [ ] PERF-005: Repair workflow
- [ ] PERF-006: Bundle generation
- [ ] PERF-007: Report generation
- [ ] PERF-008: Memory footprint
- [ ] PERF-009: CPU utilization

## Environment-Specific Checks

### Per-Machine Setup
- [ ] PowerShell version recorded
- [ ] OS build number recorded
- [ ] Printer count and types recorded
- [ ] Network configuration recorded (domain/workgroup)
- [ ] Antivirus/firewall status recorded

### Per-Session Teardown
- [ ] Transcript stopped and saved
- [ ] Logs exported
- [ ] Defects logged for any failures
- [ ] VM snapshot restored (if failure injection used)
- [ ] Test results recorded in compatibility matrix

## Environment Coverage

| Environment | OS | PS | Privilege | Type | Status | Completed |
|-------------|----|----|-----------|------|--------|-----------|
| E1 | W10 21H2 | 5.1 | Admin | Physical | | |
| E2 | W10 21H2 | 7.x | Standard | Virtual | | |
| E3 | W10 22H2 | 5.1 | Admin | Physical | | |
| E4 | W10 22H2 | 7.x | Standard | Virtual | | |
| E5 | W11 22H2 | 5.1 | Admin | Physical | | |
| E6 | W11 22H2 | 7.x | Standard | Physical | | |
| E7 | W11 23H2 | 5.1 | Admin | Virtual | | |
| E8 | W11 23H2 | 7.x | Admin | Physical | | |
| E9 | W11 24H2 | 5.1 | Standard | Physical | | |
| E10 | W11 24H2 | 7.x | Admin | Virtual | | |

## Total Count

- **Total test cases:** 92
- **Passed:** ______
- **Failed:** ______
- **Blocked:** ______
- **Not tested:** ______
- **Defects found:** ______
- **Defects fixed:** ______
- **Defects remaining:** ______

**QA Engineer Signature:** ________________ **Date:** ________________
