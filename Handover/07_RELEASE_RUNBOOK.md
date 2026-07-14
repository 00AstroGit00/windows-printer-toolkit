# PrinterToolkit — Release Runbook

**Version:** 5.2
**Date:** 2026-07-14

---

## 1. Release Types

| Type | Version Bump | Branch Source | Target | Timeline |
|------|-------------|---------------|--------|----------|
| Patch | 5.2.0 → 5.2.1 | `develop` | `main` | As needed (bug fixes) |
| Minor | 5.2 → 5.3 | `develop` | `main` | Quarterly (new features) |
| Major | 5.3 → 6.0 | `develop` | `main` | Annual (breaking changes) |
| Hotfix | 5.2.0 → 5.2.1 | `main` | `main` | Emergency (critical bugs) |

## 2. Standard Release Process

### Prerequisites
- [ ] All target PRs merged to `develop`
- [ ] CI green on `develop` (last commit)
- [ ] All 49 Pester tests pass: `Invoke-Pester .\Tests\PrinterToolkit.Tests.ps1`
- [ ] No open Critical or High defects targeted for this release
- [ ] Validation campaign results reviewed (if applicable)

### Step-by-Step

```
Step 1: Create Release Branch
└── git checkout develop
└── git pull
└── git checkout -b release/v<version>
└── git push origin release/v<version>
```

```
Step 2: Update Version Strings
└── Update ModuleVersion in PrinterToolkit.psd1
└── Update version in PrinterToolkit.psm1 ($Script:ToolkitVersion)
└── Update version in CI/build.ps1 (artifact path, header)
└── Update version in CI/package.ps1 (default version, header)
└── Update version in install.ps1 (console output)
└── Update version in launcher.ps1 (header, window title)
└── Update version in README.md (badge, architecture diagram)
└── git add -A && git commit -m "chore: bump version to v<version>"
```

```
Step 3: Update CHANGELOG.md
└── Add new version section at top:
    ## [<version>] - <date>
    
    ### Added
    - ...
    
    ### Changed
    - ...
    
    ### Fixed
    - ...
└── git add CHANGELOG.md && git commit -m "docs: update CHANGELOG for v<version>"
```

```
Step 4: Run Final Build
└── .\CI\build.ps1 -Configuration Release
└── Verify output: all steps OK
```

```
Step 5: Package Release
└── # Find latest artifact directory
└── $artifacts = Get-ChildItem .\artifacts | Sort-Object LastWriteTime -Descending | Select-Object -First 1
└── .\CI\package.ps1 -ArtifactPath $artifacts.FullName -Version <version>
└── Verify ZIP and release notes exist in .\releases\
```

```
Step 6: Generate Checksums
└── Get-FileHash .\releases\PrinterToolkit_v<version>.zip -Algorithm SHA256 | Format-List
└── # Save output for GitHub release
└── Get-FileHash .\releases\PrinterToolkit_v<version>.zip -Algorithm SHA256 | `
    Select-Object @{N='Filename';E={Split-Path $_.Path -Leaf}}, Hash | `
    Export-Csv .\releases\SHA256SUMS -NoTypeInformation -Delimiter ' '
```

```
Step 7: Merge to Main
└── # Create PR from release/v<version> to main
└── # Title: "Release v<version>"
└── # CI must pass on the release branch
└── # Merge via PR (no direct push)
```

```
Step 8: Tag Release
└── git checkout main
└── git pull
└── git tag -a v<version> -m "PrinterToolkit v<version>"
└── git push origin v<version>
```

```
Step 9: Create GitHub Release
└── # GitHub Actions automatically creates release on tag push
└── # Verify at: https://github.com/00AstroGit00/windows-printer-toolkit/releases
└── # If auto-creation fails, create manually:
└── # 1. Go to Releases → Draft a new release
└── # 2. Choose tag v<version>
└── # 3. Title: "PrinterToolkit v<version>"
└── # 4. Paste CHANGELOG entry as description
└── # 5. Attach PrinterToolkit_v<version>.zip and SHA256SUMS
```

```
Step 10: Merge Back to Develop
└── git checkout develop
└── git merge main
└── git push origin develop
```

```
Step 11: Post-Release Tasks
└── # Update CERTIFICATION.md with any new findings
└── # Update MIGRATION.md if breaking changes
└── # Close milestone on GitHub
└── # Announce release (if applicable)
```

## 3. Hotfix Release Process

### When to Use
- Critical security vulnerability
- Complete breakage of a core function on a supported OS version
- Data loss scenario

### Process
```
Step 1: Branch from main
└── git checkout main
└── git checkout -b fix/hotfix-<description>

Step 2: Apply fix
└── # Minimal change, no refactoring
└── # Update manifest patch version
└── git add -A && git commit -m "fix: <description>"
└── git push origin fix/hotfix-<description>

Step 3: PR to main (fast-track)
└── # Create PR, label as HOTFIX
└── # Single reviewer or self-merge if urgent
└── git checkout main && git pull

Step 4: Tag
└── git tag -a v<version> -m "PrinterToolkit v<version>"
└── git push origin v<version>

Step 5: Verify release on GitHub

Step 6: Cherry-pick to develop
└── git checkout develop
└── git cherry-pick <commit-hash>
└── git push origin develop
```

## 4. Release Artifacts Checklist

| Artifact | Location | Required |
|----------|----------|----------|
| Release ZIP | `releases/PrinterToolkit_v<version>.zip` | Yes |
| Release Notes | `releases/RELEASE_NOTES_v<version>.md` | Yes |
| SHA-256 Checksums | `releases/SHA256SUMS` | Yes |
| Build Manifest | `releases/build_manifest_v<version>.json` | Recommended |
| Build Log | CI pipeline log | Recommended |

## 5. Validation Gates

| Gate | Command/Script | Pass Criteria |
|------|---------------|---------------|
| Syntax check | `.\CI\build.ps1 -SkipTests` | All steps OK |
| Unit tests | `Invoke-Pester .\Tests\PrinterToolkit.Tests.ps1` | 49 passed, 0 failed |
| Export check | `.\CI\build.ps1 -SkipTests` (step 5) | 55 exports match |
| Module load | `Import-Module .\PrinterToolkit.psd1 -Force` | No errors |
| Menu launch | `.\launcher.ps1 -CommandLine -Command "Get-ToolkitStatus"` | Status returned |
| Bundle | `.\launcher.ps1 -CommandLine -Command "New-DiagnosticBundle"` | ZIP created |
| Package | `.\CI\package.ps1` | ZIP + release notes created |
| SHA-256 | `Get-FileHash` | Matches between build and release |

## 6. Version Number Reference

| Component | File | Location |
|-----------|------|----------|
| Module version | `PrinterToolkit.psd1` | `ModuleVersion = '5.x.x'` |
| Script version | `PrinterToolkit.psm1` | `$Script:ToolkitVersion = '5.x.x'` |
| Console output | `PrinterToolkit.psm1` | `'PrinterToolkit v5.x.x'` (3 places) |
| Console output | `install.ps1` | `'PrinterToolkit v5.x.x — Bootstrap Installer'` |
| Console output | `launcher.ps1` | `"PrinterToolkit v5.x.x"` (2 places) |
| Artifact path | `CI/build.ps1` | `artifacts\PrinterToolkit_v5.x.x_<timestamp>` |
| Default version | `CI/package.ps1` | `$Version = '5.x.x'` |
| Badge | `README.md` | `Version-5.x.x-brightgreen` |
| Download link | `README.md` | `PrinterToolkit_v5.x.x.zip` |

## 7. Troubleshooting

| Problem | Likely Cause | Solution |
|---------|-------------|----------|
| Release not created automatically | Tag not pushed, or release workflow has a condition failure | Check `if: startsWith(github.ref, 'refs/tags/v')` in ci.yml. Push tag again. |
| ZIP not attached to release | `softprops/action-gh-release` requires ZIP in working directory | Check artifact download path in workflow. |
| Test count mismatch | Tests added without updating README | Update README badge and architecture diagram. |
| Version string inconsistency | Some file missed during bump | Search codebase for old version: `rg '5\.[0-9]+\.[0-9]+'` |
| Checksum mismatch | User downloaded from different source | Re-verify with `Get-FileHash`. Re-upload if corrupted. |
