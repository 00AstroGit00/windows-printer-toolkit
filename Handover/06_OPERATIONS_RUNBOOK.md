# PrinterToolkit — Operations Runbook

**Version:** 5.2
**Date:** 2026-07-14
**Audience:** On-call maintainers

---

## 1. Bug Triage

### Triage Process
```
Bug reported (GitHub Issue)
  │
  ▼
Step 1: Acknowledge
├── Apply label: `bug`
├── Thank the reporter
└── Set severity based on assessment
  │
  ▼
Step 2: Reproduce
├── Identify environment (OS, PS version, admin/standard)
├── Run the exact steps from the report
├── If can't reproduce:
│   ├── Ask for more details (transcript, screenshots)
│   └── Add label `needs-reproduction`
└── If reproduced:
    ├── Add label `confirmed`
    └── Assign severity
  │
  ▼
Step 3: Diagnose
├── Review code path
├── Check recent commits (git log --oneline -20)
├── Run relevant tests
└── Document root cause in issue
  │
  ▼
Step 4: Fix (if P1/P2)
├── Create fix branch
├── Write/update tests
├── PR → develop
└── Reference issue in PR description
```

### Severity Guidelines

| Severity | Definition | SLA |
|----------|-----------|-----|
| Critical | Toolkit crash, data loss, core function (import/discovery/spooler) completely broken | 24 hours |
| High | Major feature broken (repair, export, sharing, drivers); no workaround | 72 hours |
| Medium | Feature partially impaired; workaround exists | 2 weeks |
| Low | Cosmetic, minor UI glitch, documentation typo | Next release |

### Triage Template
```markdown
## Triage
- **Severity:** [C/H/M/L]
- **Reproduced:** [Yes/No]
- **Environment:** [OS, PS, Admin]
- **Root cause:** [one-line summary]
- **Fix branch:** [branch name if started]
- **Target version:** [v5.x.x]
```

## 2. Security Vulnerability Handling

### Process (Coordinated Disclosure)

```
Vulnerability reported (email or private channel)
  │
  ▼
Step 1: Acknowledge
├── Respond within 24 hours
├── Thank reporter, confirm receipt
└── Provide PGP key for secure communication (if needed)
  │
  ▼
Step 2: Assess
├── Determine severity (CVSS 3.1):
│   ├── CVSS 9.0-10.0 → Critical
│   ├── CVSS 7.0-8.9 → High
│   ├── CVSS 4.0-6.9 → Medium
│   └── CVSS 0.1-3.9 → Low
├── Determine affected versions
└── Check if fix exists or needs development
  │
  ▼
Step 3: Fix (private)
├── Create private fix branch
├── Develop patch
├── Write tests
├── Review within team
└── Prepare advisory
  │
  ▼
Step 4: Release
├── Coordinate release date with reporter
├── Push fix to main
├── Publish security advisory on GitHub
├── Tag new patch release
└── Credit reporter (if they consent)
```

### Security Contacts
- **Primary:** GitHub Issues (private vulnerability report via GitHub Security Advisories)
- **Secondary:** Repository profile contact email

### What to Do
- Keep the issue confidential until a fix is released
- Use GitHub's private Security Advisory feature (`https://github.com/00AstroGit00/windows-printer-toolkit/security/advisories`)
- Always credit the reporter unless they request anonymity

## 3. Regression Investigation

### When a Previously Working Feature Breaks

```
Regression detected (test failure or user report)
  │
  ▼
Step 1: Isolate
├── Identify the last known-good commit: `git log --oneline -30`
├── Use `git bisect` to find the breaking commit:
│   ```
│   git bisect start
│   git bisect bad HEAD
│   git bisect good <last-known-good-tag>
│   # Test each bisect point
│   git bisect reset
│   ```
└── Note the breaking commit hash and message
  │
  ▼
Step 2: Understand
├── Read the breaking commit's diff: `git show <hash>`
├── Understand what the change intended to fix
├── Identify why it broke the regression
└── Document: "Commit <hash> broke <feature> because <reason>"
  │
  ▼
Step 3: Fix
├── If the fix is obvious:
│   ├── Create fix branch
│   ├── Fix the regression while preserving the original fix
│   ├── Add regression test
│   └── PR → develop
├── If the fix is complex:
│   ├── Revert the breaking commit temporarily: `git revert <hash>`
│   ├── File an issue to re-apply with correct fix
│   └── PR revert → develop → main
```

## 4. CI Failures

### Common Failures and Resolutions

| Symptom | Likely Cause | Resolution |
|---------|-------------|------------|
| "Syntax errors in: ..." | PowerShell parsing error in recently committed .ps1/.psm1 | Check syntax, missing closing brace/quote in changed file |
| "42 test(s) FAILED" | Test environment mismatch or regression | Run `Invoke-Pester .\Tests\PrinterToolkit.Tests.ps1 -Passthru` locally |
| "Could not load module" | Path changed or file missing | Verify all 11 modules exist; check `.psd1` vs filesystem |
| "Action failed at step 'Run Tests'" | GitHub Actions runner issue | Re-run job. If persists, check windows-latest image status. |
| "No ZIP asset found" | Release not published yet | Tag must exist with attached ZIP. Check release creation step. |
| PowerShell 7.4 setup fails | GitHub Actions runner may already have it | The install step is conditional — check `if: matrix.psversion == '7.4'` |
| `softprops/action-gh-release` fails | Tag not pushed or permissions issue | Verify tag exists: `git ls-remote --tags origin`. Check GITHUB_TOKEN has `contents: write`. |

### CI Recovery Steps

```powershell
# Step 1: Check CI logs on GitHub
# Step 2: Reproduce locally
git pull
git checkout <branch>
Invoke-Pester .\Tests\PrinterToolkit.Tests.ps1

# Step 3: If tests fail locally, fix and push
# Step 4: If tests pass locally but CI fails:
#   - Check PowerShell version differences
#   - Check for environment-specific paths
#   - Check OS version differences in CI runner

# Step 5: If CI infrastructure issue:
#   - Re-run failed jobs via GitHub UI
#   - If persistent: update CI workflow
```

## 5. Hotfix Release

### Emergency Patch Process

```
Critical bug reported in production (main branch)
  │
  ▼
Step 1: Branch from main
└── git checkout main
└── git checkout -b fix/hotfix-<description>
  │
  ▼
Step 2: Fix
├── Apply minimal fix (no refactoring)
├── Update tests
├── Bump patch version in manifest
├── git add -A && git commit -m "fix: <description>"
└── git push origin fix/hotfix-<description>
  │
  ▼
Step 3: PR to main
├── Create PR against main
├── Title: `[HOTFIX] <description>`
├── CI must pass
├── Self-merge if critical (no review delay)
└── git checkout main && git pull
  │
  ▼
Step 4: Tag and release
├── git tag -a v5.x.x+1 -m "PrinterToolkit v5.x.x+1"
├── git push origin v5.x.x+1
├── GitHub Actions creates release automatically
└── Verify release appears on GitHub
  │
  ▼
Step 5: Cherry-pick to develop
├── git checkout develop
├── git cherry-pick <hotfix-commit-hash>
├── git push origin develop
└── Resolve conflicts if any
```

## 6. Rollback Procedures

### Rollback a Release

```powershell
# If a release tag points to a broken commit:
# Option A: Create a new patch release with the fix
git checkout main
git revert <broken-commit-hash> --no-edit
git push origin main
git tag -a v5.x.x+1 -m "PrinterToolkit v5.x.x+1"
git push origin v5.x.x+1

# Option B: Delete the release (only if no one has downloaded it)
git tag -d v5.x.x
git push --delete origin v5.x.x
# Delete release on GitHub manually
# Create new release from previous tag
```

### Rollback a PR Merged to Develop

```powershell
git checkout develop
git revert -m 1 <merge-commit-hash> --no-edit
git push origin develop
```

### Rollback a CI/CD Pipeline Change

```powershell
git checkout main
git revert <ci-change-commit-hash> --no-edit
git push origin main
# CI will re-run with old workflow
```

## 7. On-Call Rotation Checklist

### When Paged
- [ ] Acknowledge the alert
- [ ] Determine severity (C/H/M/L)
- [ ] If Critical: start hotfix process immediately
- [ ] If High: triage within 4 hours
- [ ] If Medium/Low: file issue, address during business hours

### Shift Handoff
- [ ] Document all open incidents
- [ ] Note any ongoing investigations
- [ ] Transfer ownership of open PRs/issues
- [ ] Update team calendar with next on-call

## 8. Environment Recovery

### After Failure Injection Tests
```powershell
# Restore spooler
Start-Service Spooler -ErrorAction SilentlyContinue

# Restore firewall
Set-NetFirewallProfile -All -Enabled $true -ErrorAction SilentlyContinue

# Restore registry (from backup)
reg import "$env:TEMP\print_before.reg" -ErrorAction SilentlyContinue

# Restore network
Enable-NetAdapter -Name "*" -Confirm:$false -ErrorAction SilentlyContinue
```

### VM Snapshot Recovery
- For VM testing: restore to pre-test snapshot between each failure injection test
- For physical machines: run the repair workflow (`Invoke-AutomaticShareRepair`) after destructive tests
