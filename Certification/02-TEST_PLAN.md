# PrinterToolkit v8.2.0-rc1 — Master Test Plan

## Configuration Matrix

| ID | OS | PowerShell | Printer | Environment |
|----|----|-----------|---------|-------------|
| C1 | Windows 10 22H2 | 5.1 | None | VM or bare metal |
| C2 | Windows 10 22H2 | 7.x | None | VM or bare metal |
| C3 | Windows 11 23H2 | 5.1 | None | VM or bare metal |
| C4 | Windows 11 23H2 | 7.x | None | VM or bare metal |
| C5 | Windows 11 24H2 | 5.1 | None | VM or bare metal |
| C6 | Windows 11 24H2 | 7.x | None | VM or bare metal |
| C7 | Windows 11 24H2 | 7.x | USB printer | Physical machine |
| C8 | Windows 11 24H2 | 7.x | Network printer | Physical machine |

## Test Phases

### Phase 1 — Module Import & Sanity

| Test | Expected | Evidence |
|------|----------|----------|
| Module imports without errors | `Get-Module` shows PrinterToolkit | Transcript |
| All 21 submodules load | `Get-ToolkitStatus` reports 21 modules | JSON |
| Version matches 8.2.0 | `(Get-Module PrinterToolkit).Version` = 8.2.0 | JSON |
| All exported functions present | 81+ functions available | Pester XML |

### Phase 2 — Provider Certification

| Test | Expected | Evidence |
|------|----------|----------|
| Service provider — all 6 phases | GetCurrent, GetDesired, Plan, Apply, Validate, Rollback all succeed | Pester XML |
| Firewall provider — all 6 phases | Same | Pester XML |
| Network provider — all 6 phases | Same | Pester XML |
| Sharing provider — all 6 phases | Same | Pester XML |
| IPP provider — all 6 phases | Same | Pester XML |
| Registry provider — all 6 phases | Same | Pester XML |
| Driver provider — all 6 phases | Same | Pester XML |
| Printer provider — all 6 phases | Same | Pester XML |

### Phase 3 — Runtime Validation

| Test | Expected | Evidence |
|------|----------|----------|
| Diagnostics run without errors | `Get-NetworkValidation` completes | JSON |
| Validation dashboard renders | `Invoke-EndToEndValidation` returns checks | JSON |
| Report generation (HTML/JSON/MD) | Files created | File listing |
| Connection info returns data | `Get-ConnectionInfo` has entries | JSON |
| SMB configuration queryable | `Get-SmbConfiguration` succeeds | JSON |

### Phase 4 — Failure Injection

| Scenario | Injection | Expected Recovery |
|----------|-----------|-------------------|
| Missing printer | Remove printer device | Graceful failure + report |
| Firewall blocked | Disable print sharing rules | Repair re-enables |
| Spooler stopped | Stop-Service Spooler | Recovery restarts |
| Driver issues | Remove printer driver | Detection reports missing |
| Network problems | Set profile to Public | Detection + recommendation |

### Phase 5 — Performance Benchmarks

| Metric | Target | Measurement |
|--------|--------|-------------|
| Module import time | < 5s | Average of 5 runs |
| Validation run | < 30s | Average of 5 runs |
| Diagnostics | < 15s | Average of 5 runs |
| Reporting | < 10s | Average of 5 runs |
| Orchestration | < 45s | Average of 5 runs |
| Zero-touch deployment | < 120s | Average of 5 runs |

## Exit Criteria

- [ ] All 6 OS×PS configurations pass Phase 1 (0 import errors)
- [ ] All 8 providers pass Phase 2 (0 Pester failures)
- [ ] Phase 3 completes on at least 2 configurations
- [ ] Phase 4 scenarios pass on at least 1 configuration
- [ ] Phase 5 benchmarks collected on at least 1 configuration
- [ ] No Critical or High severity defects remain open
