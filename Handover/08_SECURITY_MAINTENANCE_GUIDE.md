# PrinterToolkit — Security Maintenance Guide

**Version:** 5.2
**Date:** 2026-07-14
**Audience:** Maintainers handling security issues

---

## 1. Threat Model

### Assets Protected
- User's printer configuration and print data
- User's file system (registry, drivers, diagnostic data)
- Network credentials (via printer shares)

### Trust Boundaries
- **Admin vs Standard User:** Toolkit enforces elevation gates on all 9 destructive operations
- **Local machine vs Network:** Toolkit does not expose network services; all network operations are outbound
- **Signed vs Unsigned Code:** Installer verifies SHA-256 checksum; no Authenticode signing yet

### Assumptions
- The user controls their own machine
- An already-elevated attacker has full control (out of scope)
- The network between GitHub and the user is trusted for TLS downloads

## 2. Security Architecture

### Defenses in Depth
```
Layer 1: Input Validation
├── [ValidatePattern()] on all user-facing string parameters
├── [ValidateSet()] on enum parameters
├── Menu input validated at point of entry (Read-Host regex checks)
└── Path validation with Resolve-Path + extension restriction

Layer 2: Authorization
├── Assert-Elevated on all 9 destructive operations
├── Non-admin functions blocked from:
│   ├── Stop/Start/Restart-Spooler
│   ├── Clear-PrintQueue
│   ├── Set-DefaultPrinter
│   ├── Install-IPPServer
│   ├── Export/Restore/Install/Remove-PrinterDrivers
│   ├── Initialize-RepairBackup / Invoke-AutomaticShareRepair
│   ├── Enable/Disable-PrinterSharing
│   ├── Set-PrinterSharePermission
│   └── Set-PrinterSharingTransport

Layer 3: Secure Execution
├── No Invoke-Expression without allowlist
├── No direct string-to-shell conversion
├── No credential or token storage
└── All temp files use random names (GetRandomFileName)

Layer 4: Integrity
├── SHA-256 verification in installer
├── Release ZIP checksums published
└── Git tag + signed commits (when configured)
```

## 3. Vulnerability Response Playbook

### Receiving a Report

**If reported via GitHub Security Advisory:**
1. You'll receive an email notification
2. Go to `https://github.com/00AstroGit00/windows-printer-toolkit/security/advisories`
3. Acknowledge within 24 hours
4. Start a private discussion with the reporter

**If reported via email:**
1. Acknowledge receipt within 24 hours
2. Ask for details: reproduction steps, version, environment
3. Create a GitHub Security Advisory if confirmed
4. Move all communication to the advisory

**If reported publicly (GitHub Issue):**
1. Thank the reporter
2. Quickly assess: if confirmed security issue, convert to private advisory
3. Edit the issue to remove sensitive details, link to the advisory
4. If not a security issue, label appropriately

### Assessment

```powershell
# Use CVSS 3.1 calculator
# Common scenarios for PrinterToolkit:

# Scenario A: Command injection via printer name
#   Attacker controls printer name → could execute arbitrary PowerShell
#   CVSS: 8.8 (High) — AV:N/AC:L/PR:L/UI:N/S:U/C:H/I:H/A:H
#   Mitigation: [ValidatePattern] restricts to safe chars

# Scenario B: Path traversal in driver export/restore
#   Attacker provides crafted path → writes outside target directory
#   CVSS: 6.5 (Medium) — AV:L/AC:L/PR:L/UI:N/S:U/C:H/I:H/A:N
#   Mitigation: Resolve-Path + -InfPath validation

# Scenario C: Log file information disclosure
#   Exception messages contain user paths in Desktop-accessible log
#   CVSS: 3.3 (Low) — AV:L/AC:L/PR:L/UI:N/S:U/C:L/I:N/A:N
#   Mitigation: Documented as known limitation
```

### Fix and Release

1. Develop fix on private branch
2. Write regression tests
3. Review with at least one other maintainer
4. Coordinate release date with reporter
5. Push fix to `main`
6. Tag new patch version
7. Publish security advisory on GitHub
8. Credit reporter (opt-in)

## 4. Secure Coding Guidelines

### DO
```powershell
# Validate all user input
[ValidatePattern('^[a-zA-Z0-9 _\-\.\(\)]+$')]
[string]$PrinterName

# Use Resolve-Path for file paths
$resolved = Resolve-Path -Path $userPath -ErrorAction Stop

# Restrict file extensions
if ($infPath -notmatch '\.inf$') { throw "Must be .inf file" }

# Use allowlist for command execution
$safeCommands = @('Get-Printers', 'Get-PrinterStatus', ...)
if ($Command -notin $safeCommands) { throw "Command not allowed" }

# Use random temp names
$tmpName = [System.IO.Path]::GetRandomFileName()

# Wrap external commands in try/catch
try { Get-Printer } catch { Write-Log "..." }
```

### DON'T
```powershell
# Never use Invoke-Expression without allowlist
Invoke-Expression $userInput  # WRONG

# Never pass unsanitized input to shell commands
& "pnputil.exe" $userInput    # WRONG

# Never construct paths with string concatenation
$path = "$root\$userInput"     # WRONG — use Join-Path

# Never suppress errors without logging
Get-Printer -ErrorAction SilentlyContinue  # WRONG — log the error
```

## 5. Security Checklist for Code Reviews

- [ ] All string parameters have `[ValidatePattern()]` or `[ValidateSet()]`
- [ ] All paths use `Resolve-Path` before use
- [ ] No `Invoke-Expression` without allowlist
- [ ] No direct concatenation into shell commands
- [ ] `Assert-Elevated` called before destructive operations
- [ ] All exceptions logged via `Write-Log`
- [ ] No hardcoded secrets, tokens, or credentials
- [ ] Temp files use `GetRandomFileName` or similar
- [ ] Menu inputs validated (regex match) before use
- [ ] New external command invocations reviewed for injection vectors

## 6. Dependency Security

### Supply Chain Risks

| Dependency | Risk | Mitigation |
|------------|------|------------|
| PowerShell 5.1 | Low | Built into Windows; updated via Windows Update |
| Pester (CI) | Low | Installed per CI run; pinned via `Install-Module -RequiredVersion` |
| GitHub Actions | Low | Pinned to major version (v4, v2); reviewed on update |
| Windows executables (pnputil, reg, etc.) | Low | Signed by Microsoft; shipped with OS |
| GitHub API (installer) | Medium | Uses HTTPS; SHA-256 verification provides integrity |

### Maintaining Security
- Review GitHub Actions updates for supply-chain attacks
- Pin action versions to major version tags (not `@main` or `@latest`)
- Regularly audit dependencies with `.\CI\build.ps1`

## 7. Release Integrity

### Current State
- Release ZIPs are published as GitHub Release artifacts
- SHA-256 checksums are generated and should be published alongside each release
- Installer verifies checksums against release assets

### Improvements Needed (Roadmap)
- [ ] **Authenticode signing** — Sign `install.ps1` and `launcher.ps1` with a code-signing certificate
- [ ] **Signed ZIP** — Use `SignTool` to sign the release ZIP
- [ ] **SBOM** — Generate a Software Bill of Materials for each release
- [ ] **Reproducible builds** — Ensure the same source always produces the same binary/ZIP

## 8. Monitoring

### What to Monitor
- GitHub Issues for bug reports that may have security implications
- Dependabot alerts (when enabled for the repository)
- GitHub Security Advisories for related Windows/Printer vulnerabilities
- PowerShell Gallery for dependency updates (when published)

### No Telemetry (Privacy)
PrinterToolkit does not and will not collect telemetry. All diagnostics are stored locally.

## 9. Relevant CVEs

The following CVEs are relevant to PrinterToolkit's domain (PowerShell execution and printer management). None are directly exploitable through PrinterToolkit — the toolkit manages local printers and does not expose network services — but awareness helps prioritize defense layers.

| CVE | Date | Description | Relevance |
|-----|------|-------------|-----------|
| CVE-2025-25004 | 2025-10 | PowerShell elevation of privilege via improper access control | Defense-in-depth: PrinterToolkit enforces `Assert-Elevated` on all 9 destructive operations |
| CVE-2025-49734 | 2025-09 | PowerShell Direct elevation of privilege in Hyper-V | Low — only relevant if toolkit is used in Hyper-V sessions |
| CVE-2025-26506 | 2025-02 | HP LaserJet RCE via malicious PostScript print jobs | Informational — toolkit does not send print jobs; users should keep printer firmware updated |
| CVE-2026-1789 | 2026-04 | Printer management information disclosure via remote management interface | Low — toolkit manages local printers only; remote management is out of scope |
| CVE-2020-16886 | 2020 | PowerShellGet V2 WDAC bypass | Low — toolkit does not use PowerShellGet at runtime |

### Mitigation Summary
- PrinterToolkit's `Assert-Elevated` gates prevent exploitation of CVE-2025-25004-style elevation paths
- No remote management interface means CVE-2026-1789-style disclosure is not applicable
- Users are advised to keep Windows updated (all PowerShell CVEs are addressed via Windows Update)
- Printer firmware CVEs (CVE-2025-26506) are outside the toolkit's scope but documented for awareness

## 10. Audit Log

| Date | Action | Triage Lead |
|------|--------|-------------|
| 2026-07-14 | Security architecture documented in SECURITY.md | Initial |
| 2026-07-14 | Adversarial audit completed: 21 findings, 0 C/H open | Audit |
