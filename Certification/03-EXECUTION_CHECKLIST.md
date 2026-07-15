# PrinterToolkit v8.2.0-rc1 — Execution Checklist

## Pre-Flight

- [ ] Tester has a supported Windows machine
- [ ] Tester has Administrator access
- [ ] PowerShell 7.x is installed (if not using 5.1)
- [ ] `Install-Module Pester -Force -Scope CurrentUser` completed
- [ ] Git repo cloned or release ZIP extracted
- [ ] Antivirus excludes the working directory (speeds execution)

## Execution

### Step 1 — Run Certification Harness

```powershell
# Open PowerShell AS ADMINISTRATOR
cd C:\path\to\PrinterToolkit
.\Start-Certification.ps1
```

- [ ] Harness starts without errors
- [ ] All version checks pass
- [ ] Output directory created under `Certification\Results\`
- [ ] Evidence collected for all phases

### Step 2 — Review Summary Report

Open `Certification\Results\YYYYMMDD_HHmmss\summary.html` in a browser.

- [ ] All tests executed
- [ ] Pass/fail counts visible
- [ ] Known issues section populated

### Step 3 — Collect Evidence Archive

- [ ] ZIP archive generated at `Certification\Results\YYYYMMDD_HHmmss\certification_evidence.zip`
- [ ] Archive contains all logs, JSON, Pester XML, transcripts

### Step 4 — File Issues

For any failures, use `Certification\06-ISSUE_REPORTING_TEMPLATE.md`.

- [ ] All failures documented with reproduction steps
- [ ] Screenshots attached where relevant
- [ ] PowerShell version and OS noted

## Post-Execution

- [ ] Evidence ZIP uploaded to shared location
- [ ] Summary JSON sent to release engineering
- [ ] Issues filed in GitHub issue tracker
