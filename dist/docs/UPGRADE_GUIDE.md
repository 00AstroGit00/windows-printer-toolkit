# PrinterToolkit — Upgrade Guide

**Version:** 5.0.1
**Date:** 2026-07-14
**Audience:** Existing users upgrading from previous versions

---

## 1. Version Compatibility Matrix

| From | To | Method | Breaking Changes | Effort |
|------|----|--------|-----------------|--------|
| 4.0.x | 5.0.1 | Full replacement | Function renames (see §4) | Medium |
| 4.1.x | 5.0.1 | Full replacement | None | Low |
| 5.0.x | 5.0.1 | Module update or ZIP replace | None | Low |
| 5.1.x | 5.0.1 | Module update | None | Low |
| 5.2.x | 5.0.1 | Module update | None | Minimal |

## 2. Upgrade Methods by Installation Type

### PowerShell Gallery
```powershell
Update-Module -Name PrinterToolkit -Force
```

### winget
```powershell
winget upgrade PrinterToolkit.PrinterToolkit
```

### Chocolatey
```powershell
choco upgrade printertoolkit
```

### Scoop
```powershell
scoop update printertoolkit
```

### Manual (GitHub Release)
1. Download the new release ZIP
2. Stop any PowerShell sessions using PrinterToolkit
3. Replace the entire `PrinterToolkit` directory with the new version
4. Open a new PowerShell session
5. `Import-Module PrinterToolkit -Force`

### Bootstrap Installer
The one-liner always downloads the latest version. Re-run the installer for an upgrade.

## 3. Post-Upgrade Verification

```powershell
# Step 1: Confirm version
(Get-Module -ListAvailable PrinterToolkit).Version
# Expected: 5.0.1

# Step 2: Load the module
Import-Module PrinterToolkit -Force

# Step 3: Check all modules loaded
Get-ToolkitStatus

# Step 4: Verify exports
Get-Command -Module PrinterToolkit | Measure-Object | Select-Object Count
# Expected: 55

# Step 5: Run tests
Invoke-Pester (Join-Path (Split-Path (Get-Module PrinterToolkit).Path) 'Tests\PrinterToolkit.Tests.ps1')
```

## 4. Breaking Changes from v4.0.x

If upgrading from v4.0, the following functions were renamed. Update any scripts that use the old names:

| Old Name (v4.0) | New Name (v5.0+) |
|-----------------|------------------|
| `Get-PrinterInventory` | `Get-Printers` |
| `Get-PrinterExtendedDetails` | `Get-PrinterStatus` |
| `Restart-PrintSpooler` | `Restart-Spooler` |
| `Get-IPPPrinterAttributes` | `Get-IPPStatus` |
| `Test-IPPConnection` | `Test-IPPEndpoint` |
| `Get-IPPClassDrivers` | `Test-IPPClientInstalled` |
| `Write-ToolkitLog` | `Write-Log` |
| `Get-ToolkitLog` | `Get-LogContent` |
| `Test-MopriaCompatibility` | `Show-AndroidWizard` |
| `Get-AndroidPrintServices` | `Get-AndroidCompatibility` |
| `Get-EventLogAnalysis` | Use `New-DiagnosticBundle` instead |
| `Test-SpoolerIntegrity` | `Get-PrinterQueueHealth` |
| `Get-WSDPrinters` | Use `Get-NetworkValidation` instead |
| `Test-SmbConfiguration` | Use `Export-ServiceSnapshot` instead |

## 5. Breaking Changes from v5.0.0

The following changes were introduced in v5.0.1 and carried forward:

- `Clear-PrintQueue` now requires `-Force` to skip the confirmation prompt
- `Restart-Spooler` now returns `[PSCustomObject]` instead of `[bool]`
- 9 destructive operations now call `Assert-Elevated` before executing
- Bootstrap installer verifies SHA-256 checksums

## 6. Configuration Preservation

PrinterToolkit stores no persistent configuration files. All settings are ephemeral per session. After upgrade:

- **Log files** — preserved in `$env:USERPROFILE\Desktop\PrinterToolkit\Logs\`
- **Diagnostic bundles** — preserved at their output location (Desktop or specified path)
- **Exported reports** — preserved at their output location
- **Driver backups** — preserved at specified export paths

## 7. Rollback

If the upgrade causes issues:

### From PowerShell Gallery
```powershell
# Install the previous version
Install-Module -Name PrinterToolkit -RequiredVersion <previous> -Force
```

### From ZIP release
1. Delete the new version directory
2. Restore the old version directory from backup
3. Re-import: `Import-Module PrinterToolkit -Force`

### From winget/Chocolatey/Scoop
```powershell
# Uninstall the new version
<package-manager> uninstall printertoolkit

# Install the previous version
<package-manager> install printertoolkit --version <previous>
```

## 8. Known Issues After Upgrade

| Issue | Cause | Workaround |
|-------|-------|------------|
| `Script:ToolkitVersion` shows old version | Module cached in session | Close all PowerShell sessions and reopen |
| Menu options behave differently | Submenu restructuring in v5.3 | Review MEN-002 test case for navigation mapping |
| Tests fail with "command not found" | Old Pester version | `Install-Module Pester -Force -SkipPublisherCheck` |
