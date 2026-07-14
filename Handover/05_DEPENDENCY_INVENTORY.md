# PrinterToolkit — Dependency Inventory

**Version:** 5.2
**Date:** 2026-07-14

---

## 1. PowerShell Dependencies

| Dependency | Version | Type | Required | Notes |
|------------|---------|------|----------|-------|
| PowerShell | 5.1+ | Runtime | Yes | Minimum: 5.1. Recommended: 7.4. Both tested in CI. |
| Pester | 5.x | Test | Yes (dev/CI) | Test suite requires Pester 5.x. Pre-installed on GitHub Actions windows-latest. |
| PSScriptAnalyzer | 1.21+ | Lint | Optional (dev) | Recommended for CI but not required for runtime. |

## 2. Windows Feature Dependencies

| Feature | PowerShell Cmdlet Used | Required? | Default Status |
|---------|----------------------|-----------|----------------|
| Print Services (Spooler) | `Get-Service Spooler`, `Stop-Service`, `Start-Service` | Yes | Installed by default on all Windows editions |
| Print Management Console | `Get-Printer`, `Get-PrinterDriver`, `Get-PrintJob`, etc. | Yes | Installed by default |
| Windows Management Instrumentation (WMI) | `Get-CimInstance Win32_Printer` | Yes | Installed by default |
| Internet Printing Client | `Get-WindowsFeature Print-Internet` | No (optional) | Not installed by default on most editions |
| SMB 1.0/CIFS | `Get-SmbShare`, `Get-SmbSession` | No (optional) | SMB 2.0+ by default; SMB 1.0 for some legacy printers |
| .NET Framework 4.7.2+ | Required by PowerShell 5.1 itself | Yes (PS 5.1) | Installed by default on Windows 10 21H2+ |

## 3. External Executable Dependencies

| Executable | Path | Used By | Purpose |
|------------|------|---------|---------|
| `pnputil.exe` | `C:\Windows\System32\pnputil.exe` | Drivers module | Enumerate and install driver packages |
| `reg.exe` | `C:\Windows\System32\reg.exe` | Diagnostics module | Export registry snapshots |
| `netsh.exe` | `C:\Windows\System32\netsh.exe` | Diagnostics module | Export firewall rules |
| `ipconfig.exe` | `C:\Windows\System32\ipconfig.exe` | Diagnostics module | Network configuration |
| `PrintBrm.exe` | `C:\Windows\System32\spool\tools\PrintBrm.exe` | Repair module | Backup/restore print configuration |
| `rundll32.exe` | `C:\Windows\System32\rundll32.exe` | Drivers module | Install printer drivers from INF |

**License:** All executables are part of Windows OS. No third-party redistribution required.

## 4. Network Dependencies

| Protocol | Port | Used By | Purpose |
|----------|------|---------|---------|
| SMB | TCP 445 | Sharing module | Printer sharing, share permissions |
| IPP | TCP 631 | IPP module | Internet Printing Protocol detection and validation |
| WSD | TCP 5357 | Diagnostics module | Web Services for Devices discovery |
| HTTP/HTTPS | 80/443 | Diagnostics module | IPP endpoint tests |
| ICMP | N/A | Diagnostics module | Network connectivity checks |

## 5. GitHub Actions Dependencies (CI/CD)

| Action | Version | Purpose |
|--------|---------|---------|
| `actions/checkout` | v4 | Check out repository |
| `actions/upload-artifact` | v4 | Upload build artifacts |
| `actions/download-artifact` | v4 | Download artifacts for release |
| `softprops/action-gh-release` | v2 | Create GitHub releases |

**License:** All GitHub Actions are MIT or equivalent permissive license.

## 6. PowerShell Gallery Requirements (Future Publishing)

### Current Status
PrinterToolkit is not published to the PowerShell Gallery. All dependencies below are for development/CI only.

| Module | Version | Purpose | Install Command |
|--------|---------|---------|-----------------|
| Pester | 5.x | Test framework | `Install-Module Pester -Force -SkipPublisherCheck -Scope CurrentUser` |
| PSScriptAnalyzer | 1.21+ | Code analysis | `Install-Module PSScriptAnalyzer -Force -Scope CurrentUser` |

**License:** Pester — Apache 2.0. PSScriptAnalyzer — MIT.

### Prerequisites for Gallery Publishing
Per Microsoft's publishing guidelines, the module manifest must include:

| Field | Current Status | Required for Gallery |
|-------|---------------|---------------------|
| `ModuleVersion` | ✅ 5.0.1 | Yes — must follow SemVer |
| `GUID` | ✅ e8c4a1d7-... | Yes — must be unique and stable across versions |
| `Author` | ✅ PrinterToolkit Contributors | Yes |
| `Description` | ✅ Present | Yes |
| `FunctionsToExport` | ✅ 55 functions | Yes — avoid wildcards |
| `ProjectUri` | ✅ github.com/... | Strongly recommended |
| `LicenseUri` | ✅ github.com/.../LICENSE | Strongly recommended |
| `Tags` | ✅ Present | Strongly recommended |
| `ReleaseNotes` | ✅ Present | Recommended |
| `IconUri` | ❌ Empty | Recommended but optional |
| `PrivateData` | ✅ Present | Yes |

### Pre-Publish Validation Checklist
- [ ] `Test-ModuleManifest -Path .\PrinterToolkit.psd1` passes
- [ ] `Invoke-ScriptAnalyzer -Path . -Recurse` has zero errors
- [ ] All 49 Pester tests pass
- [ ] Module version incremented (Gallery rejects duplicate versions)
- [ ] Module folder name matches the module name (`PrinterToolkit`)
- [ ] No private data, secrets, or local paths in the manifest

## 7. Runtime Dependencies Not Required

| Component | Why Not Needed |
|-----------|---------------|
| PowerShell Gallery | Module is loaded locally, not installed from gallery |
| NuGet | Not required for any operation |
| Windows ADK | Not required; all functionality uses built-in Windows tools |
| .NET SDK | Not required; PowerShell 5.1 uses built-in .NET Framework |
| Visual Studio | Not required; all development is PowerShell |
| Git | Not required for end users; only for contributors |
| Wireshark | Not required; optional for debugging IPP/WSD |

## 8. Dependency Verification

### Pre-Flight Check Script
```powershell
# Run this on any target machine to verify dependencies
$checks = @(
    @{ Name = "PowerShell 5.1+"; Test = { $PSVersionTable.PSVersion.Major -ge 5 } },
    @{ Name = "Print Spooler"; Test = { Get-Service Spooler -ErrorAction SilentlyContinue } },
    @{ Name = "Print Management Cmdlets"; Test = { Get-Command Get-Printer -ErrorAction SilentlyContinue } },
    @{ Name = "pnputil.exe"; Test = { Get-Command pnputil.exe -ErrorAction SilentlyContinue } },
    @{ Name = "reg.exe"; Test = { Get-Command reg.exe -ErrorAction SilentlyContinue } },
    @{ Name = "netsh.exe"; Test = { Get-Command netsh.exe -ErrorAction SilentlyContinue } },
    @{ Name = "PrintBrm.exe"; Test = { Test-Path "$env:SystemRoot\System32\spool\tools\PrintBrm.exe" } }
)

$results = foreach ($check in $checks) {
    $pass = & $check.Test
    [PSCustomObject]@{ Dependency = $check.Name; Status = if ($pass) { "OK" } else { "MISSING" } }
}
$results | Format-Table -AutoSize
```

## 9. Licensing Summary

| Component | License | Compatible with MIT? |
|-----------|---------|---------------------|
| PrinterToolkit | MIT | — |
| PowerShell | MIT | Yes |
| Pester | Apache 2.0 | Yes |
| PSScriptAnalyzer | MIT | Yes |
| GitHub Actions | MIT | Yes |
| Windows built-in tools | Windows EULA | Yes (runtime dependency) |

**Verification:** All third-party components have permissive licenses compatible with MIT. No GPL or copyleft dependencies exist.
