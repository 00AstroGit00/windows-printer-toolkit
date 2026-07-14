# PrinterToolkit v5.1 — Performance Benchmark Template

## Instructions

1. Run each benchmark **exactly 5 times** on the same machine without rebooting between runs.
2. Record all 5 measurements in the table.
3. Calculate and record the average.
4. Compare against the baseline and record pass/fail.
5. Include the PowerShell transcript as evidence.

## Reference Baseline

Baseline values established on: **Windows 11 23H2 | Intel i7-12700 | 32 GB RAM | SSD**

| Metric | Baseline (ms) |
|--------|---------------|
| Module Import | 1,200 |
| Get-Printers (10 printers) | 400 |
| Queue Cleanup (5 jobs) | 800 |
| Network Validation | 4,500 |
| Repair Workflow | 12,000 |
| Bundle Generation | 6,000 |
| HTML Report | 2,000 |
| Memory Footprint | 28 MB |

**Threshold:** Pass if average is within 2× baseline OR absolute < 5 seconds over baseline.

---

## Benchmark 1: Module Import Time

**Test Environment:** ________________ **Date:** ________________

**Command:** `Measure-Command { Import-Module .\PrinterToolkit\PrinterToolkit.psd1 -Force }`

| Iteration | Time (ms) |
|-----------|-----------|
| 1 | |
| 2 | |
| 3 | |
| 4 | |
| 5 | |
| **Average** | |

**Result:** ☐ Pass (avg ≤ 2,400 ms) ☐ Fail (avg > 2,400 ms)

**Baseline comparison:** ______ × baseline

---

## Benchmark 2: Get-Printers Execution Time

**Test Environment:** ________________ **Date:** ________________
**Printer count at time of test:** ______

**Command:** `Measure-Command { Get-Printers }`

| Iteration | Time (ms) |
|-----------|-----------|
| 1 | |
| 2 | |
| 3 | |
| 4 | |
| 5 | |
| **Average** | |

**Result:** ☐ Pass (avg ≤ 800 ms) ☐ Fail (avg > 800 ms)

**Baseline comparison:** ______ × baseline

---

## Benchmark 3: Queue Cleanup Time

**Test Environment:** ________________ **Date:** ________________
**Pending job count:** ______
**Printer used:** ________________

**Command:** `Measure-Command { Clear-PrintQueue -PrinterName "<printer>" -Force }`
*(Re-send 5+ test jobs between each iteration)*

| Iteration | Time (ms) |
|-----------|-----------|
| 1 | |
| 2 | |
| 3 | |
| 4 | |
| 5 | |
| **Average** | |

**Result:** ☐ Pass (avg ≤ 1,600 ms) ☐ Fail (avg > 1,600 ms)

**Baseline comparison:** ______ × baseline

---

## Benchmark 4: Network Validation Time

**Test Environment:** ________________ **Date:** ________________

**Command:** `Measure-Command { Get-NetworkValidation }`

| Iteration | Time (ms) |
|-----------|-----------|
| 1 | |
| 2 | |
| 3 | |
| 4 | |
| 5 | |
| **Average** | |

**Result:** ☐ Pass (avg ≤ 9,000 ms) ☐ Fail (avg > 9,000 ms)

**Baseline comparison:** ______ × baseline

---

## Benchmark 5: Repair Workflow Time

**Test Environment:** ________________ **Date:** ________________

**Command:** `Measure-Command { Invoke-AutomaticShareRepair }`

| Iteration | Time (ms) |
|-----------|-----------|
| 1 | |
| 2 | |
| 3 | |
| 4 | |
| 5 | |
| **Average** | |

**Result:** ☐ Pass (avg ≤ 24,000 ms) ☐ Fail (avg > 24,000 ms)

**Baseline comparison:** ______ × baseline

---

## Benchmark 6: Bundle Generation Time

**Test Environment:** ________________ **Date:** ________________

**Command:** `Measure-Command { New-DiagnosticBundle }`

| Iteration | Time (ms) |
|-----------|-----------|
| 1 | |
| 2 | |
| 3 | |
| 4 | |
| 5 | |
| **Average** | |

**Result:** ☐ Pass (avg ≤ 12,000 ms) ☐ Fail (avg > 12,000 ms)

**Baseline comparison:** ______ × baseline

---

## Benchmark 7: Report Generation Time

**Test Environment:** ________________ **Date:** ________________
**Printer count:** ______

**Command:** `Measure-Command { New-PrinterReport -Format HTML }`

| Iteration | Time (ms) |
|-----------|-----------|
| 1 | |
| 2 | |
| 3 | |
| 4 | |
| 5 | |
| **Average** | |

**Result:** ☐ Pass (avg ≤ 4,000 ms) ☐ Fail (avg > 4,000 ms)

**Baseline comparison:** ______ × baseline

---

## Benchmark 8: Memory Footprint

**Test Environment:** ________________ **Date:** ________________

**Commands:**
```powershell
$before = (Get-Process -Id $PID).WorkingSet64
Import-Module .\PrinterToolkit\PrinterToolkit.psd1 -Force
$after = (Get-Process -Id $PID).WorkingSet64
$delta = [math]::Round(($after - $before) / 1MB, 1)
```

| Iteration | Before (MB) | After (MB) | Delta (MB) |
|-----------|-------------|------------|------------|
| 1 | | | |
| 2 | | | |
| 3 | | | |
| 4 | | | |
| 5 | | | |
| **Average Delta** | | | |

**Result:** ☐ Pass (avg delta ≤ 50 MB) ☐ Fail (avg delta > 50 MB)

**Baseline comparison:** ______ × baseline

---

## Benchmark 9: Peak CPU During Bundle Generation

**Test Environment:** ________________ **Date:** ________________
**CPU Model:** ________________ **Cores:** ______

**Procedure:**
1. Open Performance Monitor or Task Manager.
2. Start recording CPU usage.
3. Run `New-DiagnosticBundle` 3 times in sequence.
4. Stop recording and capture peak CPU %.

| Run | Peak CPU % |
|-----|-----------|
| 1 | |
| 2 | |
| 3 | |
| **Peak (any)** | |

**Result:** ☐ Pass (peak ≤ 50% on 4+ cores) ☐ Fail (peak > 50%)

---

## Summary

| Benchmark | Average (ms) | Baseline (ms) | × Baseline | Pass/Fail |
|-----------|-------------|---------------|------------|-----------|
| 1. Module Import | | 1,200 | | |
| 2. Get-Printers | | 400 | | |
| 3. Queue Cleanup | | 800 | | |
| 4. Network Validation | | 4,500 | | |
| 5. Repair Workflow | | 12,000 | | |
| 6. Bundle Generation | | 6,000 | | |
| 7. HTML Report | | 2,000 | | |
| 8. Memory Delta (MB) | | 28 | | |
| 9. Peak CPU (%) | | 25% | | |

**Overall Performance Verdict:** ☐ Pass ☐ Fail (any benchmark fails)

**Notes:** ______________________________________________________________________

**QA Engineer Signature:** ________________ **Date:** ________________
