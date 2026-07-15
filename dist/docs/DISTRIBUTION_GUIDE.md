# PrinterToolkit — Distribution Guide

> **⚠️ OUTDATED — describes v5.0.1 distribution.**
> The current release is **v8.2.0-rc1**. Version references, module counts, and release assets
> described here are stale. See `docs/v8.2/` for current release information.

**Version:** 5.0.1 (stale — v8.2.0-rc1 is current)
**Date:** 2026-07-14
**Audience:** End users, IT administrators, DevOps engineers

---

## 1. Overview

PrinterToolkit can be installed via four package managers plus direct download. Each method is documented below with clean install, upgrade, and uninstall instructions.

## 2. PowerShell Gallery

### Install
```powershell
Install-Module -Name PrinterToolkit -Scope CurrentUser -Force
Import-Module PrinterToolkit
```

### Upgrade
```powershell
Update-Module -Name PrinterToolkit -Force
```

### Uninstall
```powershell
Uninstall-Module -Name PrinterToolkit
```

### Verify
```powershell
Get-Module -ListAvailable -Name PrinterToolkit | Select-Object Version, ModuleBase
Get-Command -Module PrinterToolkit | Measure-Object | Select-Object Count
```

## 3. Windows Package Manager (winget)

### Install
```powershell
winget install PrinterToolkit.PrinterToolkit
```

### Upgrade
```powershell
winget upgrade PrinterToolkit.PrinterToolkit
```

### Uninstall
```powershell
winget uninstall PrinterToolkit.PrinterToolkit
```

### Notes
- winget installs the ZIP release and registers `launcher.ps1` as the `ptk` command
- Administrator privileges are required for the winget install
- After install, run `ptk` in a PowerShell terminal to launch the dashboard

## 4. Chocolatey

### Install
```powershell
choco install printertoolkit
```

### Upgrade
```powershell
choco upgrade printertoolkit
```

### Uninstall
```powershell
choco uninstall printertoolkit
```

### Notes
- Chocolatey installs the module to `$env:PSModulePath` for the current user
- Administrator privileges are required
- Chocolatey packages are community-maintained; verify the package source

## 5. Scoop

### Install
```powershell
scoop bucket add extras
scoop install printertoolkit
```
Or from a custom bucket:
```powershell
scoop bucket add printertoolkit https://github.com/00AstroGit00/scoop-printertoolkit
scoop install printertoolkit
```

### Upgrade
```powershell
scoop update printertoolkit
```

### Uninstall
```powershell
scoop uninstall printertoolkit
```

### Notes
- Scoop installs to `~/scoop/apps/printertoolkit/` (user-scoped, no admin needed)
- The `ptk` alias is registered for launching the dashboard
- Scoop auto-update checks GitHub releases for new versions

## 6. GitHub Releases (Direct Download)

### Install (Manual)
1. Download the latest ZIP from:
   `https://github.com/00AstroGit00/windows-printer-toolkit/releases/latest`
2. Extract to a folder of your choice
3. Import the module:
   ```powershell
   Import-Module .\PrinterToolkit\PrinterToolkit.psd1 -Force
   ```

### Install (One-Liner)
```powershell
powershell -ExecutionPolicy Bypass -Command "iwr -Uri https://github.com/00AstroGit00/windows-printer-toolkit/raw/main/install.ps1 -OutFile \"$env:TEMP\ptk.ps1\"; & \"$env:TEMP\ptk.ps1\""
```

### Upgrade
1. Download the new ZIP
2. Replace the existing `PrinterToolkit` directory
3. Re-import: `Import-Module PrinterToolkit -Force`

### Uninstall
Delete the `PrinterToolkit` directory from your chosen install location.
If installed via the one-liner, temp files are automatically cleaned up on exit.

## 7. Verify Installation

Run the following to confirm the module is installed correctly:

```powershell
# Check version
(Get-Module -ListAvailable PrinterToolkit).Version

# Check exports
(Get-Module -ListAvailable PrinterToolkit).ExportedFunctions.Count

# Run toolkit status
Import-Module PrinterToolkit -Force -PassThru
Get-ToolkitStatus

# Run tests
Invoke-Pester (Join-Path (Split-Path (Get-Module PrinterToolkit).Path) 'Tests\PrinterToolkit.Tests.ps1')
```

## 8. Installation Paths

| Method | Install Location | Scope |
|--------|-----------------|-------|
| PowerShell Gallery | `~\Documents\WindowsPowerShell\Modules\PrinterToolkit\` | User |
| PowerShell Gallery (AllUsers) | `$env:ProgramFiles\WindowsPowerShell\Modules\PrinterToolkit\` | Machine |
| winget | `%LOCALAPPDATA%\Microsoft\WinGet\Packages\PrinterToolkit.PrinterToolkit_*\` | User |
| Chocolatey | `$env:ChocolateyInstall\lib\PrinterToolkit\` | Machine |
| Scoop | `~\scoop\apps\printertoolkit\` | User |
| GitHub Release | User-defined | User |
| Bootstrap Installer | `%TEMP%\PrinterToolkit\<timestamp>\` | Session |

## 9. Requirements

- **OS:** Windows 10 21H2+ / Windows 11 22H2+ / Windows Server 2022+
- **PowerShell:** 5.1 or 7.x (7.4 recommended)
- **Administrator rights:** Required for spooler, driver, repair, sharing, and IPP server operations
- **Internet (install only):** Required for package manager downloads

## 10. Troubleshooting

### Module not found after install
```powershell
# Check PSModulePath
$env:PSModulePath -split ';'

# Manually add the module path
$env:PSModulePath = "$env:PSModulePath;$env:USERPROFILE\Documents\WindowsPowerShell\Modules"
```

### Execution Policy blocks the module
```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

### Old version still loads
```powershell
Remove-Module PrinterToolkit -Force -ErrorAction SilentlyContinue
Import-Module PrinterToolkit -Force
Get-Module PrinterToolkit | Select-Object Version
```
