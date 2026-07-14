# PrinterToolkit — Maintainer Guide

**Version:** 5.2
**Date:** 2026-07-14
**Audience:** Incoming maintainers and core contributors

---

## 1. Repository Overview

| Property | Value |
|----------|-------|
| Repository | `github.com/00AstroGit00/windows-printer-toolkit` |
| License | MIT |
| Language | PowerShell 5.1+ |
| Module root | `PrinterToolkit/` |
| Current version | 5.0.1 |
| Exported functions | 55 |
| Submodules | 11 |
| Pester tests | 49 |

## 2. Directory Structure

```
PrinterToolkit/
├── PrinterToolkit.psd1          # Module manifest (55 exports, version, metadata)
├── PrinterToolkit.psm1          # Root module loader + interactive menu + 4 submenus
├── launcher.ps1                 # Standalone entry point (allowlist-based command exec)
├── install.ps1                  # Bootstrap installer (SHA-256 verified download)
├── Modules/
│   ├── Core/                    # Printer enumeration, spooler, queue, defaults
│   ├── IPP/                     # Internet Printing Protocol status, URLs, validation
│   ├── Logging/                 # Structured logging (file + console, rotate, archive)
│   ├── Utilities/               # Admin checks, system info, UI helpers
│   ├── Android/                 # Mopria compatibility wizard
│   ├── Diagnostics/             # Network validation, registry/service/firewall snapshots
│   ├── Repair/                  # 8-step automatic share repair with backup/rollback
│   ├── Drivers/                 # Type 3/4 detection, export, restore, INF install
│   ├── Sharing/                 # SMB/IPP/WSD transport, permissions, compatibility
│   ├── Reporting/               # HTML/JSON/CSV reports, compliance
│   └── Bundle/                  # Diagnostic ZIP archive (12 sections)
├── Tests/
│   └── PrinterToolkit.Tests.ps1 # 49 deterministic Pester tests
├── CI/
│   ├── build.ps1                # Syntax check, Pester, export validation, packaging
│   └── package.ps1              # Release ZIP + release notes generation
├── .github/
│   ├── workflows/ci.yml         # GitHub Actions: analyze → build → release
│   ├── ISSUE_TEMPLATE/          # Bug report + feature request templates
│   └── pull_request_template.md
├── Validation/                  # Hardware validation test campaign (v5.1)
├── Handover/                    # This maintainer handover package
├── README.md
├── CHANGELOG.md
├── CERTIFICATION.md
├── MIGRATION.md
├── SECURITY.md
├── LICENSE (MIT)
├── .gitignore
└── .gitattributes
```

### Key Structural Rules

- **One concern per module.** Each submodule in `Modules/` has a single responsibility. If a function spans concerns, it lives in the more specific module.
- **No circular dependencies.** Submodules do not import each other. They are independent and communicate only through the root loader.
- **Root loader owns orchestration.** `PrinterToolkit.psm1` imports all 11 modules in a fixed order and exposes `Invoke-ToolkitMainMenu` plus submenu helper functions.
- **Manifest is the source of truth** for what is public. `FunctionsToExport` in `PrinterToolkit.psd1` must match `Export-ModuleMember` across all modules.

## 3. Coding Standards

### Naming
- **Public functions:** `Verb-Noun` (e.g., `Get-Printers`, `Restart-Spooler`)
- **Internal/helper functions:** `Verb-Noun` with no export (e.g., helper functions used internally)
- **Menu helpers:** `Show-*Menu` (e.g., `Show-DriverMenu`)
- **Variables:** `$camelCase` for locals, `$Script:scope` for script-level
- **Files:** `PrinterToolkit.<ModuleName>.psm1`

### Function Structure
Every exported function MUST:
1. Have `[CmdletBinding()]` and `[OutputType()]`
2. Use `[Validate*()]` attributes on all parameters
3. Return `[PSCustomObject]` with `Success`, `Error`, and data properties
4. Wrap external commands in `try/catch` with structured error reporting
5. Call `Assert-Elevated` before destructive operations

### Error Handling Pattern
```powershell
function Invoke-Example {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )
    try {
        # operation
        [PSCustomObject]@{ Success = $true; Data = $result }
    } catch {
        Write-Log -Message "Invoke-Example failed: $_" -Level 'ERROR'
        [PSCustomObject]@{ Success = $false; Error = $_.Exception.Message }
    }
}
```

### Module Loading Pattern
```powershell
$ModuleRoot = $PSScriptRoot
$ModulePaths = @(
    "$ModuleRoot\Modules\Core\PrinterToolkit.Core.psm1"
    # ... all 11 paths
)
foreach ($modPath in $ModulePaths) {
    if (Test-Path $modPath) {
        try { Import-Module $modPath -Force -ErrorAction Stop }
        catch { Write-Warning "Failed: $modPath - $_" }
    }
}
```

## 4. Static Code Analysis

### PSScriptAnalyzer
All code must pass PSScriptAnalyzer with no errors before merging. The following ruleset is required:

```powershell
# .ps1xml rules file — save as .github/PSScriptAnalyzerSettings.psd1
@{
    ExcludeRules = @(
        'PSAvoidUsingWriteHost'  # intentional for menu/console output
    )
    Rules = @{
        PSAvoidUsingCmdletAliases = @{ Enable = $true }
        PSAvoidUsingEmptyCatchBlock = @{ Enable = $true }
        PSAvoidUsingWMICmdlet = @{ Enable = $true }
        PSAvoidUsingInvokeExpression = @{ Enable = $true }
        PSUseApprovedVerbs = @{ Enable = $true }
        PSUseSingularNouns = @{ Enable = $true }
        PSShouldProcess = @{ Enable = $true }
        PSMissingModuleManifestField = @{ Enable = $true }
        PSAvoidUsingPositionalParameters = @{ Enable = $true }
        PSUseShouldProcessForStateChangingFunctions = @{ Enable = $true }
        PSAvoidGlobalVars = @{ Enable = $true }
        PSAvoidUsingConvertToSecureStringWithPlainText = @{ Enable = $true }
    }
}
```

Run analysis:
```powershell
Invoke-ScriptAnalyzer -Path . -Recurse -Settings .github/PSScriptAnalyzerSettings.psd1
```

### CI Integration
PSScriptAnalyzer should run before Pester in CI. Add this step to `.github/workflows/ci.yml`:

```yaml
- name: Static Analysis
  shell: pwsh
  run: |
    Install-Module PSScriptAnalyzer -Force -Scope CurrentUser
    $results = Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error
    if ($results.Count -gt 0) { $results | Format-Table; exit 1 }
```

## 5. Testing Requirements

### Running Tests
```powershell
# Run all tests
Invoke-Pester .\Tests\PrinterToolkit.Tests.ps1

# Run a specific Describe block
Invoke-Pester .\Tests\PrinterToolkit.Tests.ps1 -Filter "Core"
```

### Test Coverage Requirements
- Every exported function must have at least one test
- Every elevation-gated function must test both admin and non-admin paths
- Parameter validation must be tested (invalid input → graceful error)
- Return type contracts must be verified (`[OutputType()]` matches actual return)
- New functions: 100% coverage for business logic, 80%+ for integration

### Test Writing Rules
- Use `Mock` for external commands (`Get-Printer`, `Get-Service`, etc.)
- Do NOT depend on specific printer hardware
- Use `-ErrorAction SilentlyContinue` only when testing error paths
- Name tests: `Describe <FunctionName>` → `It <scenario>`

## 5. Commit Message Conventions

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

### Types
- `fix:` — bug fix
- `feat:` — new function or capability
- `refactor:` — code change with no behavior change
- `docs:` — documentation only
- `test:` — adding/updating tests
- `chore:` — build, CI, tooling
- `security:` — vulnerability fix
- `perf:` — performance improvement

### Examples
```
fix(Core): validate printer name before Clear-PrintQueue

Add ValidatePattern check to prevent command injection
via crafted printer names passed to the menu.

Fixes #42
```

```
feat(Drivers): add Export-PrinterDrivers -Format XML

Closes #87
```

```
docs: update README architecture diagram for v5.0.1
```

## 6. Branching Strategy

```
main           Production-ready. Only merge via PR.
  ├─ develop   Integration branch for v5.2.x patches
  ├─ feature/* New functionality (merge to develop)
  ├─ fix/*     Bug fixes (merge to develop, cherry-pick to main for hotfix)
  └─ release/* Release candidates (merge to main + tag)
```

### Workflow
1. Branch from `develop` for feature/fix work
2. Open PR against `develop`
3. PR must pass CI + review + all tests
4. Maintainer merges to `develop`
5. For release: create `release/v5.2.x` branch from `develop`
6. After testing, merge `release/*` to `main` and tag

### Hotfix Workflow
1. Branch from `main`: `fix/hotfix-<description>`
2. Fix, test, PR against `main`
3. Merge to `main`, tag new patch version
4. Cherry-pick to `develop`

## 7. Versioning Policy

PrinterToolkit follows **Semantic Versioning 2.0** with the following caveats:

- **MAJOR (v6.0):** Breaking change to public API (renamed/removed functions, changed return types)
- **MINOR (v5.3):** New public functions, new modules, new menu options (backward-compatible)
- **PATCH (v5.2.1):** Bug fixes, performance improvements, documentation (backward-compatible)

Public API = all 55 functions in `FunctionsToExport`.
Internal API = all other functions and script-level variables (no stability guarantees).

### Breaking Changes Require Major Version
- Removing or renaming an exported function
- Changing a parameter from mandatory to optional (or vice versa)
- Changing return type of an exported function
- Removing a parameter
- Changing default behavior in a way that breaks existing scripts

## 8. Review Checklist

- [ ] Code follows naming conventions
- [ ] All parameters validated with `[Validate*()]`
- [ ] Function returns `[PSCustomObject]` with `Success`/`Error`
- [ ] Elevation check added if destructive
- [ ] Logging added for failures
- [ ] Tests added/updated and passing
- [ ] Manifest updated if exports changed
- [ ] CHANGELOG.md updated
- [ ] No hardcoded paths, versions, or credentials
- [ ] No `Invoke-Expression` without allowlist review
- [ ] PSScriptAnalyzer passes with zero errors
- [ ] CI passes on the PR branch before merge
- [ ] PR description references issue number

## 9. Community Management

### Issue Triage
- **Bug reports:** Apply `bug` label, assign severity (C/H/M/L), reproduce if possible
- **Feature requests:** Apply `enhancement` label, tag with milestone, request community feedback
- **Questions:** Apply `question` label, answer within 48 hours

### Labels
- `bug`, `enhancement`, `question`, `documentation`, `good first issue`, `help wanted`
- `critical`, `high`, `medium`, `low` (severity for bugs)
- `v5.2.x`, `v5.3`, `v6.0` (milestone labels)

### Milestones
- Current patch series: `v5.2.x`
- Next minor: `v5.3`
- Next major: `v6.0`

## 10. Release Process Summary

1. Ensure all PRs for the release are merged to `develop`
2. Create `release/v<version>` branch from `develop`
3. Run full test suite: `Invoke-Pester .\Tests\PrinterToolkit.Tests.ps1`
4. Update `ModuleVersion` in manifest
5. Update `CHANGELOG.md` with release date
6. Run `.\CI\build.ps1 -Configuration Release`
7. Run `.\CI\package.ps1 -ArtifactPath .\artifacts\<latest>`
8. Generate SHA-256: `Get-FileHash .\releases\*.zip -Algorithm SHA256 | Format-List`
9. Merge release branch to `main`
10. Tag: `git tag -a v<version> -m "PrinterToolkit v<version>"`
11. Push tag: `git push origin v<version>`
12. Create GitHub Release from tag, attach ZIP + SHA256SUMS
13. Verify release appears on GitHub with all assets attached
14. Update `develop` from `main`: `git checkout develop && git merge main && git push`

### CI Pipeline Best Practices (GitHub Actions)
- **Pin action versions** to major tags (`@v4`, `@v2`) not `@main`
- **Set job timeouts** to prevent hung runs: `timeout-minutes: 30`
- **Use concurrency groups** to cancel redundant runs on the same branch
- **Cache Pester module** across runs to speed CI
- **Matrix testing** across PS 5.1 and 7.4 (already configured in ci.yml)
- **Fail fast** on syntax or analysis errors before running tests

## 11. Onboarding Checklist for New Maintainers

- [ ] Read this Maintainer Guide
- [ ] Set up local repo with `git clone`
- [ ] Run `Invoke-Pester .\Tests\PrinterToolkit.Tests.ps1` — all 49 should pass
- [ ] Review API Reference (`Handover/03_API_REFERENCE.md`)
- [ ] Review Architecture Guide (`Handover/02_ARCHITECTURE_GUIDE.md`)
- [ ] Review Technical Debt Register (`Handover/04_TECHNICAL_DEBT_REGISTER.md`)
- [ ] Create a test PR in a fork to verify CI
- [ ] Familiarize with the interactive menu: `.\launcher.ps1`
- [ ] Review open issues and PRs
- [ ] Verify GitHub Actions permissions and secrets
