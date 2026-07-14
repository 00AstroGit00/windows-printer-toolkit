# PrinterToolkit — Long-Term Support Policy

**Version:** 1.0
**Date:** 2026-07-14

---

## 1. Scope

This policy defines the support lifecycle for PrinterToolkit major, minor, and patch releases. It covers security patches, bug fixes, feature releases, deprecation, and end-of-life.

## 2. Release Channels

| Channel | Version Pattern | Frequency | Stability |
|---------|----------------|-----------|-----------|
| **Stable** | x.y.z (latest) | Every 3 months | Production-ready |
| **LTS** | x.y.z (designated) | Every 12 months | Extended support |
| **Preview** | x.y.z-previewN | Before stable | May contain bugs |

## 3. Supported Versions

| Release | Type | Release Date | Security Patches | Bug Fixes | End of Life |
|---------|------|-------------|-----------------|-----------|-------------|
| 5.3.x | Latest | 2026-07 | Until 6.0 release | Until 6.0 release | When 6.0 ships |
| 5.2.x | — | — | (not released) | — | — |
| 5.1.x | Previous | 2026-04 | Until 2027-01 | Until 2026-10 | 2027-01 |
| 5.0.x | LTS-1 | 2025-07 | Until 2027-07 | Until 2027-01 | 2027-07 |
| 4.1.x | EOL | 2024-01 | Ended | Ended | 2025-01 |

## 4. LTS Designation Criteria

A release qualifies for LTS if it:
1. Has been in stable circulation for at least 3 months
2. Has no open Critical or High severity defects
3. Has completed the hardware validation campaign
4. Has passed the adversarial audit
5. Is declared LTS by the project maintainers

**Current LTS release:** v5.0.1 (LTS-1) — support until 2027-07-14

## 5. Support Policies

### Security Patches
- **LTS releases:** Guaranteed for 24 months from release date
- **Latest stable:** Guaranteed until the next major version ships
- **Previous stable:** Guaranteed for 6 months after a new stable ships
- **Target response time:** Critical CVEs within 7 days; High CVEs within 30 days
- **Backport policy:** Security fixes are backported to all supported LTS releases

### Bug Fixes
- **LTS releases:** Critical and High bugs fixed for 12 months from release date
- **Latest stable:** All severities fixed for current version
- **Previous stable:** Only Critical and High bugs fixed for 6 months
- **Medium/Low bugs:** May be deferred to the next minor release

### Feature Releases
- **Minor versions (5.x):** Backward-compatible new features every 3-4 months
- **Major versions (6.x):** Breaking changes on an approximately annual schedule
- **Preview releases:** May contain incomplete or experimental features
- **LTS releases:** Feature-frozen after LTS designation (only patches)

### Deprecation Policy
1. Feature is marked `Deprecated` in the API Reference and source code
2. Deprecation notice appears for at least 2 minor versions before removal
3. Removal only occurs in a major version (x.0)
4. Migration guide is published at least one minor version before removal

### End-of-Life Policy
1. Announcement made 6 months before EOL date
2. Final patch release ships on the EOL date
3. Documentation tagged with EOL badge
4. Package managers may delist the version after EOL
5. No further patches, security or otherwise, after EOL

## 6. Supported Windows Versions

| Windows Version | Support Level | Notes |
|----------------|---------------|-------|
| Windows 10 21H2 | ✅ Full | Tested in validation campaign |
| Windows 10 22H2 | ✅ Full | Tested in validation campaign |
| Windows 11 22H2 | ✅ Full | Tested in validation campaign |
| Windows 11 23H2 | ✅ Full | Tested in validation campaign |
| Windows 11 24H2 | ✅ Full | Tested in validation campaign |
| Windows Server 2022 | ✅ Supported | CI runs on Server core |
| Windows Server 2025 | ✅ Supported | CI runs on Server core |
| Windows 10 < 21H2 | ❌ Unsupported | May work but not tested |
| Windows 11 < 22H2 | ❌ Unsupported | May work but not tested |

## 7. Supported PowerShell Versions

| Version | Support Level | Notes |
|---------|---------------|-------|
| PowerShell 5.1 | ✅ Full | Pre-installed on all supported Windows |
| PowerShell 7.0 | ✅ Supported | Tested in CI |
| PowerShell 7.1 | ✅ Supported | Tested in CI |
| PowerShell 7.2 | ✅ Supported | Tested in CI |
| PowerShell 7.3 | ✅ Supported | Tested in CI |
| PowerShell 7.4 | ✅ Full | Recommended — tested in CI |
| PowerShell < 5.1 | ❌ Unsupported | Missing required cmdlets |
| PowerShell 7.5+ | ⚠️ Preview | May work but not yet validated |

## 8. Release Cadence

| Version | Date | Type |
|---------|------|------|
| 5.0.1 | 2026-07 | Initial distribution release |
| 5.3.1 | 2026-08 (target) | Patch — technical debt paydown |
| 5.3.2 | 2026-10 (target) | Patch — bug fixes |
| 6.0.0 | 2027-Q1 (target) | Major — breaking changes |

## 9. Version Numbering

PrinterToolkit follows Semantic Versioning 2.0.0 with the following mapping to distribution channels:

- **Patch (5.3.1):** Bug fixes, security patches, performance improvements — no new function exports
- **Minor (5.4.0):** New functions, menu options, modules — backward-compatible
- **Major (6.0.0):** Breaking changes, removed deprecated features, architectural changes

Pre-release versions use the format `5.4.0-preview.1`.

## 10. Support Commitment

The PrinterToolkit project commits to:
- At least 12 months of security support for each LTS release
- At least 6 months of overlap between LTS releases
- Timely patching of reported security vulnerabilities
- Clear communication about deprecations and EOL dates
- Maintaining the ability for users to stay on LTS without pressure to upgrade
