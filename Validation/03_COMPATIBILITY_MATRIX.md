# PrinterToolkit v5.1 — Compatibility Matrix

## Instructions

For each environment × printer combination, execute the core test suite (IMP-001, PDV-001, RPT-001, DBG-001). Record the result as:

- **✅ Pass** — all tests pass without errors
- **⚠️ Partial** — some tests pass, some fail (note which)
- **❌ Fail** — module fails to load or core functions crash
- **N/T** — not tested (record reason)

## Environment × Printer Matrix

### Reference Environments

| # | OS | PS Version | Privilege | Machine | Network |
|---|----|-----------|-----------|---------|---------|
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

### Core Functionality (All Environments)

| Function | E1 | E2 | E3 | E4 | E5 | E6 | E7 | E8 | E9 | E10 |
|----------|----|----|----|----|----|----|----|----|----|-----|
| Module Import | | | | | | | | | | |
| Get-Printers | | | | | | | | | | |
| Get-PrinterStatus | | | | | | | | | | |
| Set-DefaultPrinter | | | | | | | | | | |
| Get-Printers (non-admin) | N/A | | N/A | | N/A | | N/A | N/A | | N/A |
| Get-ToolkitStatus | | | | | | | | | | |
| New-DiagnosticBundle | | | | | | | | | | |
| New-PrinterReport HTML | | | | | | | | | | |
| Clear-PrintQueue | | N/A | | N/A | | N/A | | | N/A | |
| Restart-Spooler | | N/A | | N/A | | N/A | | | N/A | |

### Printer Type Support (E1, E3, E5, E8)

| Printer Type | E1 | E3 | E5 | E8 | Notes |
|-------------|----|----|----|----|-------|
| USB (Type 3) | | | | | Physical USB connection required |
| USB (Type 4) | | | | | Physical USB connection required |
| SMB Shared (Type 3) | | | | | Requires network share |
| SMB Shared (Type 4) | | | | | Requires network share |
| IPP (Type 4) | | | | | Requires IPP printer on network |
| WSD (Type 4) | | | | | Requires WSD printer on network |
| Microsoft Print to PDF | | | | | Software printer, always present |
| XPS Document Writer | | | | | Software printer, always present |
| Offline printer | | | | | Simulate by disconnecting/pausing |
| Pending jobs queue | | | | | Send test jobs before test |

### Feature Coverage (E1, E3, E5, E8)

| Feature | E1 | E3 | E5 | E8 | Notes |
|---------|----|----|----|----|-------|
| IPP Status | | | | | |
| IPP URLs | | | | | |
| IPP Endpoint Test | | | | | |
| IPP Client Detection | | | | | |
| IPP Server Install | | | | | Admin only |
| Android Compatibility | | | | | |
| Android Wizard | | | | | |
| Network Validation | | | | | |
| Registry Snapshot | | | | | Admin only |
| Firewall Snapshot | | | | | Admin only |
| Service Snapshot | | | | | |
| Share Status | | | | | |
| Enable/Disable Sharing | | | | | Admin only |
| SMB Permissions | | | | | |
| Transport Switching | | | | | Admin only |
| Share Compatibility | | | | | |
| Driver Details | | | | | |
| Driver Export | | | | | Admin only |
| Driver Restore | | | | | Admin only |
| INF Install | | | | | Admin only |
| Driver Remove | | | | | Admin only |
| Upgrade Recommendations | | | | | |
| Repair Backup | | | | | Admin only |
| Automatic Repair | | | | | Admin only |
| Compliance Report | | | | | |
| JSON Report | | | | | |
| CSV Report | | | | | |
| Logging Framework | | | | | |
| Log Archive | | | | | |
| Build Script | | | | | |
| Package Script | | | | | |

### Android Compatibility (E1, E3, E5 + Android Device)

| Android App | E1 | E3 | E5 | Notes |
|-------------|----|----|----|-------|
| Mopria Print Service | | | | |
| Samsung Print Service Plugin | | | | Samsung device recommended |
| HP Smart | | | | |
| Canon PRINT | | | | |
| Brother iPrint&Scan | | | | |
| Epson Smart Panel | | | | |

## Summary

| Metric | Count |
|--------|-------|
| Total cells | |
| ✅ Pass | |
| ⚠️ Partial | |
| ❌ Fail | |
| N/T | |

**Overall Compatibility Verdict:** ________________

**QA Engineer Signature:** ________________ **Date:** ________________
