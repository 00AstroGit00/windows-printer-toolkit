# PrinterToolkit — Long-Term Roadmap

**Version:** 5.2
**Date:** 2026-07-14

---

## Next Patch Releases (v5.2.x)

*Backward-compatible bug fixes and small improvements. No new exports.*

### v5.2.1 — Technical Debt Paydown
| Item | User Value | Technical Impact | Migration | Complexity |
|------|-----------|-----------------|-----------|------------|
| PSScriptAnalyzer in CI | Consistent code quality | Automates style enforcement | None | 2 hours |
| Fix $buildFailed scoping | None (cosmetic) | Cleaner build script | None | 30 min |
| Deprecate Test-Administrator | Clearer API | Removing duplicate function | Update scripts to use Test-Elevated | 1 hour |
| Add comment-based help to all 55 functions | Better `Get-Help` experience | Documentation parity | None | 4 hours |

### v5.2.2 — Testing Hardening
| Item | User Value | Technical Impact | Migration | Complexity |
|------|-----------|-----------------|-----------|------------|
| Deterministic tests (mock all external commands) | Fewer false positives in CI | Tests pass on any Windows machine | None | 4 hours |
| Integration tests for interactive menu | Catch menu regressions | Higher confidence in refactoring | None | 5 hours |
| Log rotation in Initialize-Logging | Log files don't grow unbounded | Backward-compatible parameter add | None | 3 hours |

### v5.2.3 — Installer and Packaging
| Item | User Value | Technical Impact | Migration | Complexity |
|------|-----------|-----------------|-----------|------------|
| Hardcode SHA-256 for fallback path | Integrity even without release | Secure fallback | Update installer checksums per release | 3 hours |
| SBOM generation in CI | Transparency | Additional release artifact | None | 2 hours |
| Release notes auto-generation | Less manual work | Pipeline improvement | None | 1 hour |

---

## Minor Releases (v5.3)

*Backward-compatible new features and improvements. New function exports allowed.*

### Candidate Features

| Item | User Value | Technical Impact | Migration | Complexity |
|------|-----------|-----------------|-----------|------------|
| **Pipeline Support** on key functions (`Get-Printers \| Clear-PrintQueue`) | PowerShell-native composability | Add ValueFromPipeline parameter to ~10 functions | None (new parameters) | 8 hours |
| **Write-Progress** for long operations (bundle, repair) | Visual feedback during 10-30s operations | Add Write-Progress calls | None | 2 hours |
| **Cross-architecture driver detection** for ARM64 | Support for Windows on ARM | Extend Get-PrinterDriverDetails | None | 3 hours |
| **Export report as PDF** (via PSWritePDF or similar) | Professional distribution | New output format | None | 5 hours |
| **Print job history report** | Trend analysis for helpdesk | New data source (event log parsing) | None | 6 hours |
| **Network printer auto-discovery** via mDNS/Bonjour | Find printers without manual IP entry | New module or extension to Diagnostics | None | 8 hours |
| **Configuration profiles** (save/load preferences) | Remember export paths, formats, etc. | New config module | None | 6 hours |
| **SMB multichannel detection** | Diagnose performance issues | Extension to Diagnostics | None | 4 hours |

### Selection Criteria for v5.3
- Prioritize items that improve helpdesk/IT-admin workflow
- Keep backward compatibility: no breaking changes to existing 55 exports
- Performance and memory should not regress

---

## Major Releases (v6.0)

*Breaking changes allowed. Planned removals, API redesign, and major new capabilities.*

### Planned Breaking Changes

| Item | Reason | Migration Path |
|------|--------|---------------|
| Remove `Test-Administrator` | Deprecated since v5.1, replaced by `Test-Elevated` | Search-and-replace |
| Rename `Pause` to `Wait-ForKeypress` | Avoids shadowing built-in | Search-and-replace |
| Restructure return types for consistency | Some functions return `[bool]`, most return `[PSCustomObject]` | Script updates needed |
| Standardize parameter names across modules | Inconsistencies like `-Name` vs `-PrinterName` vs `-DriverName` | Script updates needed |

### Major New Capabilities (v6.0 Candidates)

#### Cross-Platform Support (Phase 1: Linux/macOS)
- **User value:** Manage printers from any OS in heterogeneous environments
- **Technical impact:** Replace WMI/CIM with platform-agnostic queries; abstract service management
- **Migration:** New install path for non-Windows; Windows users unaffected
- **Complexity:** Very high (3-6 months)

#### REST API for Remote Administration
- **User value:** Integrate toolkit with automation systems (Ansible, SCCM, etc.)
- **Technical impact:** New HTTP listener module; authentication layer
- **Migration:** Optional feature; existing CLI/menu unchanged
- **Complexity:** High (2-3 months)

#### PowerShell Gallery Publishing
- **User value:** `Install-Module PrinterToolkit` instead of manual download
- **Technical impact:** Must pass `Test-ModuleManifest`, add `IconUri`, publish via `Publish-Module -NuGetApiKey`
- **Prerequisites:** PowerShell Gallery account, API key, NuGet provider 2.8.5+
- **Ongoing cost:** Version bumps required for every release (Gallery rejects duplicate versions)
- **Migration:** Additional install path; existing installers unchanged; `.psd1` needs `IconUri` added
- **Complexity:** Low (1 week)

#### GUI Front-End (WinUI 3)
- **User value:** Visual interface for non-PowerShell users
- **Technical impact:** Separate project; calls the same module under the hood
- **Migration:** Optional; CLI continues to work
- **Complexity:** High (3-4 months)

### v6.0 Timeline Estimate
- Planning: Q1 2027
- Development: Q2-Q3 2027
- Beta: Q4 2027
- Release: Q1 2028

---

## Deprecation Schedule

| Feature | Deprecated In | Removed In | Status |
|---------|---------------|------------|--------|
| `Test-Administrator` | v5.1 | v6.0 | Deprecated |
| Custom `Pause` | v5.3 | v6.0 | Will deprecate |
| PowerShell 5.1 support | v6.0 | v7.0 | Under discussion |

## Version Support Window

| Version | Released | Support End |
|---------|----------|-------------|
| 4.0.x | 2023-11 | 2024-06 (ended) |
| 4.1.x | 2024-01 | 2025-01 (ended) |
| 5.0.x | 2025-07 | 2026-07 (ended) |
| 5.1.x | 2025-07 | Active |
| 5.2.x | TBD | Future |
| 5.3.x | TBD | Future |
| 6.0.x | TBD | Future |

## Decision Record

### Why Not Publish to PowerShell Gallery Yet?
- Module uses relative paths and assumes local file structure
- No dependency manifest (no .nuspec or required modules)
- Would need to restructure for `$PSScriptRoot`-relative paths to work from `$PSModulePath`
- Postpone to v6.0

### Why Not Cross-Platform Yet?
- Heavy use of WMI (`Get-CimInstance`), Windows services, registry, and `pnputil.exe`
- PowerShell 7+ can use `Get-CimInstance` on Linux with OMI, but printer management APIs are Windows-specific
- Would need a different set of modules per platform
- Postpone to v6.0

### Why Keep PowerShell 5.1 Support?
- Still pre-installed on all supported Windows versions
- Many enterprise environments have locked-down PowerShell 5.1 without PS7
- Dropping 5.1 would exclude Windows 10 21H2/22H2 (still in support)
- Revisit for v6.0
