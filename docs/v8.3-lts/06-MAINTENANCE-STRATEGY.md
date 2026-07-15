# Maintenance Strategy — PrinterToolkit v8.3 LTS

> **Status:** Recommended branching model for LTS maintenance  
> **Last updated:** 2026-07-15

---

## 1. Branching Model

### Recommended Structure

```
main                    # Stable releases only (v8.3.x tags)
├── maintenance/v8      # LTS branch — receives only bug/security fixes
│   ├── hotfix/*        # Emergency fixes for LTS (merged to both maintenance/v8 and main)
├── feature/*           # New development (v9+ only)
├── docs/*              # Documentation-only changes
```

### Branch Rules

| Branch | Created From | Merged To | Deleted After | Protection |
|--------|-------------|-----------|---------------|------------|
| `main` | N/A (root) | N/A | N/A | Protected — requires PR review |
| `maintenance/v8` | `main` (at v8.3.0 tag) | `main` (for LTS fixes) | Never | Protected — requires PR review |
| `hotfix/*` | `maintenance/v8` | `maintenance/v8` + `main` | Merged | Standard |
| `feature/*` | `main` | `main` | Merged | Standard |
| `docs/*` | `main` | `main` | Merged | Standard |

### Key Differences from Current Model

| Current (v8.2) | Recommended (v8.3 LTS) |
|----------------|------------------------|
| `feature/v8-orchestration-engine` only active branch | `maintenance/v8` as LTS branch |
| No `develop` branch | No `develop` branch — feature branches merge directly to `main` |
| `main` receives everything | `main` receives feature + LTS fixes |
| No hotfix procedure | `hotfix/*` from `maintenance/v8` |
| CI triggers on `develop` push | Update CI to trigger on `maintenance/v8` push |

### Create the LTS Branch

```powershell
# From current main (after v8.3.0 stable tag):
git checkout main
git tag v8.3.0
git push origin v8.3.0
git checkout -b maintenance/v8
git push origin maintenance/v8
```

---

## 2. Merge Rules

### LTS Fix → `maintenance/v8`

- Must be a bug fix or security patch only (no new features, no refactoring)
- Must include a regression test
- Must pass CI (syntax check + Pester tests)
- Must be reviewed by at least one maintainer
- Changelog entry required

### LTS Fix → `main` (Cherry-Pick)

- After merging to `maintenance/v8`, cherry-pick the same fix to `main`
- This keeps `main` ahead of `maintenance/v8` in terms of fixes
- If conflicts arise, resolve on `main` separately

### Feature → `main`

- Must be for v9+ only (no feature work goes into `maintenance/v8`)
- Must include full test coverage
- Must pass CI

### Hotfix → `maintenance/v8` + `main`

- Emergency security fix
- Fast-track review (24-hour SLA)
- Must still pass CI
- Must include CVE reference in commit message

---

## 3. Release Criteria

### Patch Release (v8.3.1, v8.3.2, ...)

```
Trigger: Bug fix merged to maintenance/v8
Steps:
  1. Ensure all CI passes on maintenance/v8
  2. git checkout maintenance/v8
  3. Update version to x.y.z+1 in psd1, psm1, install.ps1, launcher.ps1
  4. Update CHANGELOG.md
  5. git commit -m "chore: bump version to v8.3.1"
  6. git tag v8.3.1
  7. git push origin v8.3.1
  8. CI creates GitHub Release automatically
  9. Update dist/ manifests (WinGet, Chocolatey, Scoop)
  10. Publish to PowerShell Gallery (manual)
  11. Cherry-pick version bump to main
```

### Security Release (v8.3.1, emergency)

```
Trigger: CVE reported or verified vulnerability
Steps:
  1. Create hotfix/security-* branch from maintenance/v8
  2. Apply fix
  3. Create PR to maintenance/v8
  4. Fast-track review
  5. After merge, tag immediately
  6. Publish advisory on GitHub Security tab
  7. Update SECURITY.md
  8. Cherry-pick to main
```

### Minor Release (v9.0.0)

```
Trigger: New features ready on main
Steps:
  1. Feature freeze on main (2 weeks)
  2. Run full certification harness
  3. Version bump
  4. Tag
  5. Create new maintenance/v9 branch
  6. Update CI to target maintenance/v9
```

---

## 4. LTS Support Commitment

| Version | Status | Security Fixes | Bug Fixes | End of Life |
|---------|--------|----------------|-----------|-------------|
| v8.3.x | **Active LTS** | ✅ | ✅ (critical only) | 2029-07-15 (3 years) |
| v8.2.x | Pre-release (RC) | ❌ | ❌ | Superseded by v8.3 |
| v8.x (earlier) | End of life | ❌ | ❌ | — |

### LTS Support Policy

- **Security fixes:** Backported to `maintenance/v8` for 3 years from first stable release
- **Critical bug fixes:** Backported to `maintenance/v8` for 2 years
- **Non-critical bugs:** Fixed on `main` only (next major version)
- **No new features:** LTS branch receives only fixes

---

## 5. CI Updates Required

Update `.github/workflows/ci.yml` to:

```yaml
on:
  push:
    branches: [main, maintenance/v8]    # ← add maintenance/v8
  pull_request:
    branches: [main, maintenance/v8]    # ← add maintenance/v8
```

Also consider adding a scheduled CI run (weekly) on `maintenance/v8` to detect upstream Windows API changes:

```yaml
on:
  schedule:
    - cron: '0 6 * * 1'  # Every Monday at 06:00 UTC
```

---

## 6. Communication

- All LTS fixes must reference the issue number in the commit message
- Release notes for patch releases should be concise ("Bug fixes and security updates")
- Breaking changes must not be introduced in patch releases
- Deprecation notices must be announced 2 major versions in advance
