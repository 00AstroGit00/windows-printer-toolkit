# Release Lifecycle Guide — PrinterToolkit v8.3 LTS

> **Audience:** Maintainers performing releases  
> **Prerequisites:** Write access to GitHub repo, PowerShell Gallery API key (for PSGallery publish)

---

## 1. Patch Release Workflow (v8.3.x → v8.3.x+1)

**When:** Bug fix or security patch merged to `maintenance/v8`

### Steps

```powershell
# 1. Ensure maintenance/v8 is up to date and CI is green
git checkout maintenance/v8
git pull origin maintenance/v8

# 2. Update version strings across the repository
#    Files to update:
#      - PrinterToolkit.psd1 (ModuleVersion)
#      - PrinterToolkit.psm1 ($Script:ModuleVersion)
#      - install.ps1 ($script:ModuleVersion)
#      - launcher.ps1 (window title version)
#
#    Convention: bump PATCH (e.g., 8.3.0 → 8.3.1)

# 3. Update CHANGELOG.md
#    Add entry under "## [8.3.1] - 2026-07-20"
#    Categorize: Added / Fixed / Security / Changed

# 4. Commit and tag
git add .
git commit -m "chore: bump version to 8.3.1"
git tag v8.3.1
git push origin v8.3.1

# 5. CI will auto-create GitHub Release
#    Verify at: https://github.com/00AstroGit00/windows-printer-toolkit/releases

# 6. Update distribution manifests (manual)
#    - dist/winget/ - update version + SHA256
#    - dist/chocolatey/ - update version + SHA256
#    - dist/scoop/ - update version + SHA256

# 7. Publish to PowerShell Gallery (manual)
cd dist/psgallery
./Publish-PrtkToGallery.ps1 -ApiKey <your-api-key>

# 8. Cherry-pick version bump to main
git checkout main
git cherry-pick maintenance/v8 <commit-hash>
git push origin main
```

### Artifacts Produced

| Artifact | Location | Format |
|----------|----------|--------|
| Source ZIP | GitHub Release | `PrinterToolkit_v8.3.1.zip` |
| Release Notes | GitHub Release + repo | `RELEASE_NOTES_v8.3.1.md` |
| SHA256 Checksum | GitHub Release | `SHA256SUMS` |
| Build Manifest | Build output | `build_manifest.json` |
| Build Log | CI run | GitHub Actions log |

### Validation Gates (Pre-Release)

```
□ CI syntax check passes
□ CI Pester tests pass (PS 5.1 + PS 7.4)
□ CI build completes successfully
□ CI package creates valid ZIP
□ Manual: Import module from ZIP in PowerShell 5.1
□ Manual: Import module from ZIP in PowerShell 7.x
□ Manual: Get-ToolkitStatus returns correct version
□ Manual: Verify all 21 submodules load
```

---

## 2. Minor Release Workflow (v8.3.x → v8.4.0)

**When:** New backward-compatible features merged to `main`

### Additional Steps vs. Patch

```
□ Feature freeze period: 2 weeks
□ Full certification harness execution (Start-Certification.ps1)
□ Update compatibility matrix
□ Update known-issues document
□ Update release-gate-review document
□ Create maintenance/v8.4 branch from new tag
□ Update CI to test both maintenance/v8.3 and maintenance/v8.4
```

### Version Bump Convention

```
PATCH: Bug fixes, security patches (8.3.0 → 8.3.1)
MINOR: New features, backward-compatible (8.3.0 → 8.4.0)
MAJOR: Breaking changes (8.x → 9.0.0)
```

---

## 3. Security Release Workflow (Emergency)

**When:** CVE reported or verified vulnerability in LTS branch

### Steps

```powershell
# 1. Create hotfix branch
git checkout maintenance/v8
git checkout -b hotfix/security-CVE-2026-XXXX

# 2. Apply fix
#    - Code change
#    - Regression test
#    - SECURITY.md update
#    - CHANGELOG.md update (security section)

# 3. Create PR to maintenance/v8
#    Label: security
#    Reviewer: assigned immediately

# 4. After merge, tag and release immediately
git checkout maintenance/v8
git pull origin maintenance/v8
git tag v8.3.1
git push origin v8.3.1

# 5. Publish security advisory on GitHub
#    https://github.com/00AstroGit00/windows-printer-toolkit/security/advisories

# 6. Cherry-pick to main
git checkout main
git cherry-pick maintenance/v8 <commit-hash>
git push origin main

# 7. Notify users via GitHub Discussions / Release notes
```

### SLA Targets

| Step | Target |
|------|--------|
| Triage confirmation | 24 hours |
| Fix developed | 48 hours |
| PR review | 24 hours |
| Release published | 24 hours after merge |
| **Total (max)** | **120 hours** |

---

## 4. Windows Compatibility Update Workflow

**When:** A new Windows version (e.g., Windows 12) is released and compatibility issues are found

### Triggers

- Cmdlet deprecation warnings in CI
- Feature name changes in new Windows build
- Service name changes
- Test failures on new Windows version

### Process

```powershell
# 1. Create compatibility branch from maintenance/v8
git checkout maintenance/v8
git checkout -b hotfix/compat-win12

# 2. Apply targeted fixes only
#    - Update feature names if changed
#    - Add version-specific code paths where needed
#    - Update compatibility matrix document
#    - Do NOT refactor or add features

# 3. PR and merge to maintenance/v8

# 4. Tag as patch release
```

### Version Detection Pattern

```powershell
# Use this pattern for version-specific behavior:
$osInfo = Get-CimInstance Win32_OperatingSystem
$buildNumber = [int]$osInfo.BuildNumber

if ($buildNumber -ge 26000) {
    # Windows 12+ code path
} else {
    # Legacy code path
}
```

---

## 5. Emergency Rollback Procedure

**When:** A released patch introduces a critical regression

### Steps

```powershell
# 1. Identify the release tag to roll back from
#    e.g., v8.3.1 is bad

# 2. Do NOT delete the tag or release (GitHub history is immutable)

# 3. Create a new patch release that reverts the bad changes
git checkout maintenance/v8
git revert <bad-commit-hash>
# If multiple commits, revert in reverse order

# 4. Tag as v8.3.2 with "REVERT" in release notes
git commit -m "chore: revert v8.3.1 changes (see advisory)"
git tag v8.3.2
git push origin v8.3.2

# 5. Mark v8.3.1 release as "Pre-release" on GitHub
#    Add warning to release notes: "DO NOT USE - see v8.3.2"

# 6. Notify users
```

### Rollback Notes

- PowerShell Gallery: You can deprecate a module version with `Unpublish-Module` (if within 24 hours) or update the module with a deprecation warning
- WinGet/Chocolatey/Scoop: Update manifests to point to the fixed version
- Never force-push to shared branches

---

## 6. Release Verification Checklist

### Pre-Release (all release types)

```
□ git status is clean
□ All 21 submodules present in Modules/
□ PrinterToolkit.psd1 parses without errors
□ PrinterToolkit.psm1 parses without errors
□ All submodule .psm1 files parse without errors
□ Module version matches across all source files
□ FunctionsToExport matches actual exports
□ CHANGELOG.md updated for new version
□ CI passes on target branch
□ Install.ps1 can bootstrap the release
□ Launcher.ps1 displays correct version
```

### Post-Release

```
□ GitHub Release created
□ ZIP artifact downloadable
□ SHA256SUMS file published
□ Release notes published
□ Distribution manifests updated (WinGet, Chocolatey, Scoop)
□ PowerShell Gallery updated (if applicable)
□ Tag visible on GitHub
```

---

## 7. Version Reference

When bumping version, update ALL of these files:

| File | Field to Update |
|------|-----------------|
| `PrinterToolkit.psd1` | `ModuleVersion = '8.3.0'` |
| `PrinterToolkit.psm1` | `$Script:ModuleVersion = '8.3.0'` |
| `install.ps1` | `$script:ModuleVersion = '8.3.0'` |
| `launcher.ps1` | Window title: `PrinterToolkit v8.3.0` |
| `CI/package.ps1` | Default `-Version` parameter (optional — reads from manifest) |
| `dist/winget/*.yaml` | `PackageVersion`, `InstallerUrl`, `InstallerSha256` |
| `dist/chocolatey/*.nuspec` | `<version>` |
| `dist/scoop/PrinterToolkit.json` | `version`, `url`, `hash` |
| `README.md` | Badge and feature description (if major features added) |
| `docs/v8.3/CHANGELOG-v8.3.md` | New entries |
| `Tests/PrinterToolkit.Tests.ps1` | Version assertions |

---

## 8. Key Contacts & Resources

- **Repository:** https://github.com/00AstroGit00/windows-printer-toolkit
- **CI Status:** https://github.com/00AstroGit00/windows-printer-toolkit/actions
- **PSGallery:** https://www.powershellgallery.com/packages/PrinterToolkit
- **Issue Tracker:** https://github.com/00AstroGit00/windows-printer-toolkit/issues
- **Security:** https://github.com/00AstroGit00/windows-printer-toolkit/security/advisories
