# v8.2 Performance Benchmark Report (Phase 6)

**Status: PENDING — runtime capture required.** Harness delivered (`Tests/v8.2.Benchmark.ps1`).
Fill the table below from `benchmark.json` per target (3 OS × 2 PowerShell).

## Benchmarks measured
| Benchmark | What it exercises |
|---|---|
| ModuleImport | `Import-Module PrinterToolkit.psm1 -Force` |
| OrchestratorStartup | `Get-Command Invoke-Orchestrator` resolves |
| Detection | `Get-Printer` + `Get-UsbPrinterInfo` |
| Validation | `Invoke-EndToEndValidation` |
| Diagnostics | `Get-NetworkValidation` |
| Reporting | `New-PrinterReport -Format JSON` |

## Indicative thresholds (adjust after first capture)
| Benchmark | Suggested max (avg) |
|---|---|
| ModuleImport | 3000 ms |
| OrchestratorStartup | 1000 ms |
| Detection | 2000 ms |
| Validation | 5000 ms |
| Diagnostics | 5000 ms |
| Reporting | 3000 ms |

## Results template (paste from benchmark.json)
### Windows 10 22H2 — PS 5.1
| Benchmark | Avg (ms) | Min | Max | Verdict |
|---|---|---|---|---|
| ModuleImport | | | | |
| OrchestratorStartup | | | | |
| Detection | | | | |
| Validation | | | | |
| Diagnostics | | | | |
| Reporting | | | | |

### Windows 11 23H2 — PS 7.x
(…repeat…)

## Observations
_Pending runtime._

## Conclusion
_Pending runtime._
