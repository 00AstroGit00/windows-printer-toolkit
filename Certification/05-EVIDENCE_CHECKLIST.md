# PrinterToolkit v8.2.0-rc1 — Evidence Checklist

## Required Artifacts

| # | Artifact | Source | Format | Collected? |
|---|----------|--------|--------|------------|
| 1 | PowerShell transcript | `Start-Transcript` | `.txt` | |
| 2 | Pester test results | `Invoke-Pester -PassThru` | XML (NUnit) | |
| 3 | Console logs | `Start-Certification.ps1` output | `.log` | |
| 4 | Runtime validation JSON | `Tests\v8.2.RuntimeValidation.ps1` | `.json` | |
| 5 | Provider certification report | `Tests\v8.2.ProviderCert.Tests.ps1` | XML + JSON | |
| 6 | Failure injection JSON | `Tests\v8.2.FailureInjection.ps1` | `.json` | |
| 7 | Benchmark JSON | `Tests\v8.2.Benchmark.ps1` | `.json` | |
| 8 | Toolkit logs | `Get-LogFilePath` | `.log` | |
| 9 | Diagnostic bundle | `New-DiagnosticBundle` | `.zip` | |
| 10 | Environment snapshot | `Get-SystemInfo` | `.json` | |
| 11 | Git commit hash | `git rev-parse HEAD` | `.txt` | |
| 12 | Summary HTML | `Export-CertificationReport` | `.html` | |
| 13 | Summary MD | `Export-CertificationReport` | `.md` | |
| 14 | Summary JSON | `Export-CertificationReport` | `.json` | |

## Optional Artifacts (if printer present)

| # | Artifact | Source | Format | Collected? |
|---|----------|--------|--------|------------|
| 15 | USB printer detection | `Get-UsbPrinterInfo` | `.json` | |
| 16 | Driver intelligence | `Get-DriverIntelligence` | `.json` | |
| 17 | Driver signature | `Test-DriverSignature` | `.json` | |
| 18 | Print test page result | `Set-DefaultPrinter + test page` | screenshot/`.txt` | |
| 19 | Client connection info | `Get-ConnectionInfo` | `.json` | |
| 20 | QR code | `New-ConnectionQRCode` | `.png` | |
| 21 | Client connectivity proof | Screenshot of client printing | `.png` / `.jpg` | |

## Validation

- [ ] All 14 required artifacts collected
- [ ] JSON files are valid (parsable)
- [ ] Pester XML is well-formed
- [ ] ZIP archive contains all artifacts
- [ ] Artifact naming matches standard: `evidence_YYYYMMDD_HHmmss.zip`
