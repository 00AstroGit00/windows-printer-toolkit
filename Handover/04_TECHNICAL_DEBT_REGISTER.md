# PrinterToolkit — Technical Debt Register

**Version:** 5.2
**Date:** 2026-07-14

---

## Prioritization

| Priority | Impact | Effort | Risk | Action Window |
|----------|--------|--------|------|---------------|
| P1 | High | Low | High | Next patch |
| P2 | High | Medium | Medium | Next minor |
| P3 | Medium | Medium | Low | Next minor or major |
| P4 | Low | High | Low | Major version |

---

## Register

### TDR-001: Redundant Administrator Checks
- **Item:** `Test-Administrator` and `Test-Elevated` are identical in behavior
- **Location:** `Modules/Utilities/PrinterToolkit.Utilities.psm1`
- **Impact:** Confusing API. Callers don't know which to use.
- **Effort:** 1 hour (deprecate one, redirect to the other)
- **Risk:** Low — both return bool, no consumers depend on the function name
- **Priority:** P2
- **Recommendation:** Deprecate `Test-Administrator` in v5.3, remove in v6.0

### TDR-002: Custom Pause Shadows Built-In
- **Item:** Custom `Pause` function shadows PowerShell's built-in `Pause` alias for `Start-Sleep -s`
- **Location:** `PrinterToolkit.psm1`
- **Impact:** Confusing for developers. If someone writes `Pause` expecting sleep, they get keypress wait.
- **Effort:** 1 hour (rename to `Wait-ForKeypress` or keep with comment)
- **Risk:** Low — intentional behavior documented in CERTIFICATION.md
- **Priority:** P3
- **Recommendation:** Rename to `Invoke-Pause` or `Wait-ForKeypress` in v6.0

### TDR-003: Unsanitized Exception Messages in Logs
- **Item:** Exception messages may contain file paths and usernames
- **Location:** Every `catch` block that calls `Write-Log -Message "...failed: $_"`
- **Impact:** Paths/usernames could leak into Desktop log files
- **Effort:** 2 hours (add sanitization helper function)
- **Risk:** Low — log files are on user's Desktop (user-controlled)
- **Priority:** P3
- **Recommendation:** Add `ConvertTo-SanitizedString` helper that strips `C:\Users\*` patterns before logging

### TDR-004: $buildFailed Variable Scoping in build.ps1
- **Item:** `$buildFailed` is reset inside the syntax-check block but referenced across the whole script
- **Location:** `CI/build.ps1:94`
- **Impact:** If multiple error sections ran (they don't in current flow), variable would not reset. Purely cosmetic.
- **Effort:** 30 minutes (move `$buildFailed = $false` to top of script)
- **Risk:** Low
- **Priority:** P3
- **Recommendation:** Move initialization to line 30

### TDR-005: No PSScriptAnalyzer Integration
- **Item:** Repository has no `.ps1xml` or `Invoke-ScriptAnalyzer` in CI
- **Location:** CI pipeline (`.github/workflows/ci.yml`)
- **Impact:** Coding standards violations not caught automatically. Style drifts over time.
- **Effort:** 2 hours (add `Install-Module PSScriptAnalyzer` + `Invoke-ScriptAnalyzer` step to CI)
- **Risk:** Low — may cause initial failures that need cleanup
- **Priority:** P2
- **Recommendation:** Add PSScriptAnalyzer to CI pipeline. Create `.ps1xml` rules file.

### TDR-006: No Help Comments on All Functions
- **Item:** Some functions lack `.SYNOPSIS`, `.PARAMETER`, or `.EXAMPLE` comment-based help
- **Location:** Various `.psm1` files
- **Impact:** `Get-Help <function>` returns incomplete or missing documentation
- **Effort:** 4 hours (add comment-based help to all 55 functions)
- **Risk:** Low
- **Priority:** P3
- **Recommendation:** Audit all functions for help comments, add where missing

### TDR-007: Installer Fallback Lacks Integrity Check
- **Item:** When GitHub release is unavailable, fallback to `main.zip` skips SHA-256 verification
- **Location:** `install.ps1:74-79`
- **Impact:** Fallback path cannot guarantee ZIP integrity
- **Effort:** 3 hours (compute and hardcode expected hash for main branch, or sign the installer)
- **Risk:** Medium — changing fallback URL or adding signing could break the bootstrap flow
- **Priority:** P2
- **Recommendation:** Investigate Authenticode signing for install.ps1, or hardcode a known-good hash for the fallback

### TDR-008: Tests Require Manual Printer Inspection
- **Item:** Tests that verify printer details (`PDV-001`, `PDV-002`) cannot fully validate output because printer names depend on the test machine
- **Location:** `Tests/PrinterToolkit.Tests.ps1`
- **Impact:** Tests pass on type/count checks but not on specific values. Regressions in printer data could be missed.
- **Effort:** 3 hours (add injection-point tests or snapshot comparison)
- **Risk:** Low
- **Priority:** P3
- **Recommendation:** Add tests that mock `Get-Printer` with known data and verify every output field

### TDR-009: No Integration Tests for Interactive Menu
- **Item:** `Invoke-ToolkitMainMenu` and all submenus have zero automated tests
- **Location:** `Tests/PrinterToolkit.Tests.ps1` (no menu tests)
- **Impact:** Menu refactoring risks breaking navigation — only manual testing catches it
- **Effort:** 5 hours (add Pester tests using `-CommandLine` mode to exercise menu paths)
- **Risk:** Low
- **Priority:** P2
- **Recommendation:** Add integration tests that launch launcher.ps1 with various `-Command` parameters

### TDR-010: No v5.1 Version Bump Yet
- **Item:** Repository still at v5.0.1 after certification work. Version should be bumped to start v5.2 patch cycle.
- **Location:** `PrinterToolkit.psd1`, `PrinterToolkit.psm1`, `CI/build.ps1`, `CI/package.ps1`, `README.md`
- **Impact:** Version skew between branches/changes
- **Effort:** 1 hour (update all version strings)
- **Risk:** Low — purely mechanical
- **Priority:** P1
- **Recommendation:** Bump to 5.0.2 or 5.2.0 before next release

### TDR-011: Module Paths Use Backslashes
- **Item:** All 11 module paths in `PrinterToolkit.psm1` use `\` instead of `Join-Path`
- **Location:** `PrinterToolkit.psm1:15-26`
- **Impact:** Works on Windows but would break on non-Windows PowerShell (not currently supported). Harder to maintain if paths change.
- **Effort:** 30 minutes (replace `\` with `Join-Path` calls)
- **Risk:** Low
- **Priority:** P3
- **Recommendation:** Use `Join-Path $ModuleRoot "Modules" "Core" "PrinterToolkit.Core.psm1"` pattern

### TDR-012: No Log Rotation
- **Item:** Log file grows indefinitely; no built-in rotation or max-size enforcement
- **Location:** `Modules/Logging/PrinterToolkit.Logging.psm1`
- **Impact:** On heavily used systems, log file could grow to hundreds of MB
- **Effort:** 3 hours (add max-size parameter, auto-rotation, archiving)
- **Risk:** Low — new feature, backward-compatible
- **Priority:** P3
- **Recommendation:** Add `-MaxSizeMB` parameter (default 10 MB) and auto-rotate to `Initialize-Logging`

### TDR-013: No Pipeline Support on Output Functions
- **Item:** Most functions that return collections don't support the PowerShell pipeline (`[Parameter(ValueFromPipeline)]`)
- **Location:** All modules
- **Impact:** Cannot compose functions: `Get-Printers | Clear-PrintQueue -PrinterName $_.Name` doesn't work
- **Effort:** 8 hours (add pipeline support to 10+ key functions)
- **Risk:** Medium — changing parameter sets could break existing callers
- **Priority:** P4
- **Recommendation:** Add pipeline support in v6.0 as a planned breaking change

### TDR-014: No Progress Reporting for Long Operations
- **Item:** `New-DiagnosticBundle` and `Invoke-AutomaticShareRepair` provide no `Write-Progress` output
- **Location:** `Modules/Bundle/`, `Modules/Repair/`
- **Impact:** User sees no feedback during 10–30 second operations; looks hung
- **Effort:** 2 hours (add `Write-Progress` calls)
- **Risk:** Low
- **Priority:** P3
- **Recommendation:** Add progress bar to bundle generation (step 1/12, 2/12, etc.) and repair workflow (step 1/8, 2/8, etc.)

### TDR-015: inistic Tests in Test Suite
- **Item:** Some tests may be non-deterministic if they depend on system state (printer availability)
- **Location:** `Tests/PrinterToolkit.Tests.ps1`
- **Impact:** Flaky tests reduce confidence in CI
- **Effort:** 4 hours (audit all 49 tests for environment dependencies, add mocking)
- **Risk:** Low
- **Priority:** P2
- **Recommendation:** Audit and mock all external commands in test suite. Every test should pass on a clean Windows VM with no printers.

---

## Summary

| Priority | Count | Total Effort |
|----------|-------|-------------|
| P1 | 1 | 1 hour |
| P2 | 5 | 16 hours |
| P3 | 7 | 18 hours |
| P4 | 1 | 8 hours |
| **Total** | **14** | **43 hours** |

## Future Modernization Opportunities (Not Debt)

These are intentional design decisions that could be revisited for a v6.0 rewrite:

1. **Cross-platform support** — rewrite WMI/CIM calls to be Linux-compatible (requires .NET Core PowerShell)
2. **REST API** — expose toolkit operations as a local HTTP API for remote administration
3. **GUI** — add WinUI 3 or WPF front-end for the interactive dashboard
4. **Module publishing** — publish to PowerShell Gallery for `Install-Module PrinterToolkit`
5. **Configuration profiles** — allow saving/loading user preferences (default export path, report format, etc.)
