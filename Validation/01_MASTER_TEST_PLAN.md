# PrinterToolkit v5.1 — Master Test Plan

**Campaign:** Hardware Validation
**Version:** 5.1
**Date:** 2026-07-14
**Status:** Draft

---

## 1. Objective

Validate PrinterToolkit v5.1 on real Windows hardware across all supported OS versions, printer types, and user privilege levels. Confirm that every exported function, menu path, repair workflow, and diagnostic output behaves correctly under normal and failure conditions.

## 2. Scope

### In Scope
- All 55 exported functions across 11 submodules
- Interactive menu and all submenus (Driver, Android, Firewall, Share)
- Bootstrap installer (`install.ps1`)
- Standalone launcher (`launcher.ps1`)
- Build and packaging scripts (`CI/build.ps1`, `CI/package.ps1`)
- Pester test suite (`Tests/PrinterToolkit.Tests.ps1`)
- 10 printer types (USB, SMB, IPP, WSD, PDF, XPS, Type 3, Type 4, offline, pending jobs)
- 6 Windows versions (10 21H2, 10 22H2, 11 22H2, 11 23H2, 11 24H2)
- 2 PowerShell versions (5.1, 7.x)
- 2 privilege levels (Administrator, Standard User)
- 2 machine types (physical, virtual)
- 2 network configurations (workgroup, domain-joined — optional)
- Failure injection (12 scenarios)
- Android printing (7 client apps)
- Performance benchmarks (9 measurements, 5 iterations each)

### Out of Scope
- Source code changes (unless a test uncovers a verified defect)
- New feature development
- Cross-platform support (Linux/macOS)
- Printer hardware compatibility beyond the 10 types listed

## 3. Test Environment Matrix

### Required Configurations

| ID | OS Version | PowerShell | Privilege | Machine Type | Network |
|----|-----------|-----------|-----------|-------------|---------|
| E1 | Windows 10 21H2 | 5.1 | Admin | Physical | Workgroup |
| E2 | Windows 10 21H2 | 7.x | Standard | Virtual | Workgroup |
| E3 | Windows 10 22H2 | 5.1 | Admin | Physical | Workgroup |
| E4 | Windows 10 22H2 | 7.x | Standard | Virtual | Workgroup |
| E5 | Windows 11 22H2 | 5.1 | Admin | Physical | Domain |
| E6 | Windows 11 22H2 | 7.x | Standard | Physical | Workgroup |
| E7 | Windows 11 23H2 | 5.1 | Admin | Virtual | Domain |
| E8 | Windows 11 23H2 | 7.x | Admin | Physical | Workgroup |
| E9 | Windows 11 24H2 | 5.1 | Standard | Physical | Workgroup |
| E10 | Windows 11 24H2 | 7.x | Admin | Virtual | Domain |

### Minimum Coverage Requirements
- Every OS version: at least one Admin run + one Standard User run
- Every PowerShell version: at least one run per major OS version
- Physical hardware: at least 4 distinct machines
- Domain-joined: at least 2 unique domain environments

## 4. Printer Matrix

| ID | Printer Type | Connection | Driver Type | Notes |
|----|-------------|-----------|-------------|-------|
| P1 | USB | USB 2.0/3.0 | Type 3 | Direct-attached physical printer |
| P2 | USB | USB 2.0/3.0 | Type 4 | Direct-attached physical printer |
| P3 | SMB Shared | Network share | Type 3 | Shared from another Windows machine |
| P4 | SMB Shared | Network share | Type 4 | Shared from another Windows machine |
| P5 | IPP | TCP 631 | Type 4 | Network IPP printer or IPP-enabled device |
| P6 | WSD | WS-Discovery | Type 4 | Network WSD printer |
| P7 | Microsoft Print to PDF | Software | Type 3 | Built-in Windows feature |
| P8 | XPS Document Writer | Software | Type 3 | Built-in Windows feature |
| P9 | Offline | Any | Any | Physically disconnected or paused |
| P10 | Pending Jobs | Any | Any | Queue with held/paused documents |

### Printer Setup Requirements
- At least 3 physical printers (USB + network)
- At least 2 network-shared printers (SMB)
- All software printers must be present on every test machine
- Offline printer: disconnect cable OR use `Remove-PrintConnectionPolicy` for simulation
- Pending jobs: send documents and pause the queue before test

## 5. Test Case Inventory

| Module | Test Cases | ID Range |
|--------|-----------|----------|
| Module Import | 4 | IMP-001 to IMP-004 |
| Bootstrap Installer | 4 | BSI-001 to BSI-004 |
| Menu Navigation | 4 | MEN-001 to MEN-004 |
| Printer Discovery | 4 | PDV-001 to PDV-004 |
| Queue Management | 4 | QMG-001 to QMG-004 |
| Spooler Operations | 4 | SPL-001 to SPL-004 |
| Driver Export | 4 | DRV-001 to DRV-004 |
| Driver Restore | 4 | DRV-005 to DRV-008 |
| Printer Sharing | 4 | SHR-001 to SHR-004 |
| IPP Configuration | 4 | IPP-001 to IPP-004 |
| Android Wizard | 4 | AND-001 to AND-004 |
| Diagnostics Bundle | 4 | DBG-001 to DBG-004 |
| Reporting | 4 | RPT-001 to RPT-004 |
| Repair Rollback | 4 | REP-001 to REP-004 |
| Logging | 4 | LOG-001 to LOG-004 |
| Packaging | 4 | PKG-001 to PKG-004 |
| Failure Injection | 12 | FIJ-001 to FIJ-012 |
| Android Validation | 7 | ANV-001 to ANV-007 |
| Performance Benchmarks | 9 | PERF-001 to PERF-009 |
| **Total** | **92** | |

## 6. Schedule

| Phase | Duration | Activities |
|-------|----------|-----------|
| Environment Setup | 2 days | Provision VMs, install printers, configure domain |
| Functional Tests | 5 days | Execute IMP through PKG test cases |
| Failure Injection | 3 days | Execute FIJ-001 through FIJ-012 |
| Android Validation | 2 days | Execute ANV-001 through ANV-007 |
| Performance Benchmarks | 3 days | Execute PERF-001 through PERF-009 (5 iterations each) |
| Defect Triage & Retest | 3 days | Log defects, fix, regress |
| Report Generation | 2 days | Compile final validation report |
| **Total** | **20 days** | |

## 7. Entry Criteria

- [ ] All 49 Pester tests pass on at least one reference environment
- [ ] PrinterToolkit.psd1 ModuleVersion is 5.0.1 or 5.1
- [ ] Test environments provisioned per matrix (Section 3)
- [ ] Printer matrix populated per Section 4
- [ ] PowerShell transcripts enabled on all test machines
- [ ] Toolkit logging initialized before each test session

## 8. Exit Criteria

- [ ] All 92 test cases executed
- [ ] No Critical or High severity defects open
- [ ] All Medium severity defects have a documented workaround or fix scheduled
- [ ] Performance benchmarks within 20% of baseline on reference hardware
- [ ] Compatibility matrix complete (no gaps)
- [ ] Validation report signed off by QA lead and project owner

## 9. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Physical printers unavailable for all environments | High | Medium | Use software printers + offline simulation for coverage; test physical printers on at least 3 machines |
| Domain-joined machines unavailable | Medium | Low | Mark domain tests as optional; focus on workgroup coverage |
| Android device diversity low | Medium | Medium | Test with at least 2 different Android versions + 3 print apps |
| Failure injection causes persistent OS damage | Low | High | Run failure injection tests on VMs with snapshots; restore after each test |
| Time constraints limit iterations | Medium | Medium | Prioritize functional tests; run performance benchmarks on 1 reference environment |
| PowerCLI/WMI access blocked by policy | Low | Medium | Document policy requirement; use local accounts where possible |

## 10. Tools Required

- Pester 5.x (`Install-Module Pester -Force -SkipPublisherCheck`)
- PowerShell 5.1 and/or 7.x
- Windows Assessment and Deployment Kit (ADK) — for IPP/USB testing
- PrintBRM (`c:\windows\system32\spool\tools\PrintBrm.exe`)
- Android device or emulator (Android 11+) with Mopria Print Service
- Network monitoring (Wireshark or `netsh trace`) — optional for IPP/WSD debugging
- Stopwatch or `Measure-Command` for benchmarks
- Screen capture tool (Snipping Tool or `SnippingTool.exe`)

## 11. Document References

| Document | Location |
|----------|----------|
| Detailed Test Cases | `Validation/02_DETAILED_TEST_CASES.md` |
| Compatibility Matrix | `Validation/03_COMPATIBILITY_MATRIX.md` |
| Performance Benchmarks | `Validation/04_PERFORMANCE_BENCHMARKS.md` |
| Defect Log | `Validation/05_DEFECT_LOG.md` |
| Test Execution Checklist | `Validation/06_TEST_CHECKLIST.md` |
| Release Sign-Off Sheet | `Validation/07_RELEASE_SIGN_OFF.md` |
| Final Validation Report | `Validation/08_VALIDATION_REPORT.md` |
| Pester Test Suite | `Tests/PrinterToolkit.Tests.ps1` |
| Production Certification | `CERTIFICATION.md` |
