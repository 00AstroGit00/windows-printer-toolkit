# PrinterToolkit — API Reference

**Version:** 5.2
**Date:** 2026-07-14
**Total Exported Functions:** 55

---

## Stability Classification

| Label | Meaning | Versioning Impact |
|-------|---------|-------------------|
| **Stable** | Backward-compatible. Used in production. | Breaking changes only in major versions |
| **Experimental** | New in recent release. May change. | May change in minor versions |
| **Internal** | Exported for module loading only. Not for direct use. | No stability guarantees |
| **Deprecated** | Replaced. Scheduled for removal in next major. | Removed in v6.0 |

---

## Root Module

### Get-ToolkitStatus
- **Stability:** Stable
- **Purpose:** Return module health: version, loaded/failed modules, admin state, timestamp
- **Returns:** `[PSCustomObject]` with Version, LoadedModules, FailedModules, IsAdministrator, Timestamp
- **Side effects:** None
- **Breaking-change risk:** Low (core diagnostic function)

### Invoke-ToolkitMainMenu
- **Stability:** Stable
- **Purpose:** Launch interactive dashboard with 19 options + 4 submenus
- **Returns:** Nothing (exits when user selects 0)
- **Side effects:** Clears console, modifies window title, reads keyboard input
- **Breaking-change risk:** Medium (menu option renumbering would break muscle memory)

---

## Core Module (10 functions)

### Get-Printers
- **Stability:** Stable
- **Purpose:** Enumerate all installed printers with status
- **Parameters:** None
- **Returns:** `[PSCustomObject[]]` — Name, Shared, PortName, DriverName, Status, IsDefault
- **Side effects:** None
- **Breaking-change risk:** Low

### Get-PrinterStatus
- **Stability:** Stable
- **Purpose:** Detailed printer status including job count and error info
- **Parameters:** None
- **Returns:** `[PSCustomObject[]]` — Name, PrinterStatus, JobCount, DriverName, PortName, IsDefault, LastError, Timestamp
- **Side effects:** None
- **Breaking-change risk:** Low

### Stop-Spooler
- **Stability:** Stable
- **Purpose:** Stop the print spooler service
- **Parameters:** None
- **Returns:** `[PSCustomObject]` — Success, Message
- **Side effects:** Stops Windows service. Requires admin.
- **Breaking-change risk:** Low

### Start-Spooler
- **Stability:** Stable
- **Purpose:** Start the print spooler service
- **Parameters:** None
- **Returns:** `[PSCustomObject]` — Success, Message
- **Side effects:** Starts Windows service. Requires admin.
- **Breaking-change risk:** Low

### Restart-Spooler
- **Stability:** Stable
- **Purpose:** Restart the print spooler, returning stop/start timestamps
- **Parameters:** None
- **Returns:** `[PSCustomObject]` — Success, Stopped (datetime), Started (datetime), Timestamp
- **Side effects:** Restarts Windows service. Requires admin.
- **Breaking-change risk:** Low (return type changed to PSCustomObject in v5.0.1 — was bool)

### Clear-PrintQueue
- **Stability:** Stable
- **Purpose:** Remove all pending jobs from a printer's queue
- **Parameters:**
  - `-PrinterName` (mandatory) — printer name
  - `-Force` (switch) — skip confirmation prompt
- **Returns:** `[PSCustomObject]` — Success, ClearedCount, Message, Error
- **Side effects:** Deletes print jobs. Requires admin.
- **Breaking-change risk:** Low

### Set-DefaultPrinter
- **Stability:** Stable
- **Purpose:** Set the system default printer
- **Parameters:**
  - `-PrinterName` (mandatory, ValidatePattern) — printer name
- **Returns:** `[PSCustomObject]` — Success, Message
- **Side effects:** Changes user default printer. Requires admin.
- **Breaking-change risk:** Low

### Get-PrinterQueueHealth
- **Stability:** Stable
- **Purpose:** Check spooler service, registry keys, and spool directory health
- **Parameters:** None
- **Returns:** `[PSCustomObject]` — ServiceRunning, SpoolDirectoryExists, RegistryKeysOk, PrintJobsCount, OverallHealth
- **Side effects:** None
- **Breaking-change risk:** Low

### Get-SharedPrinters
- **Stability:** Stable
- **Purpose:** Return only printers with sharing enabled
- **Parameters:** None
- **Returns:** `[PSCustomObject[]]` — same as Get-Printers but filtered
- **Side effects:** None
- **Breaking-change risk:** Low

### Enable-PrintSharing
- **Stability:** Stable
- **Purpose:** Enable sharing on a printer
- **Parameters:**
  - `-PrinterName` (mandatory) — printer name
  - `-ShareName` (optional) — share name
- **Returns:** `[PSCustomObject]` — Success, Message
- **Side effects:** Enables network sharing on the printer. Requires admin.
- **Breaking-change risk:** Low

---

## IPP Module (5 functions)

### Get-IPPStatus
- **Stability:** Stable
- **Purpose:** Detect IPP support for each printer
- **Parameters:** None
- **Returns:** `[PSCustomObject[]]` — Name, IPPEnabled, IPPUrl
- **Side effects:** None
- **Breaking-change risk:** Low

### Get-IPPUrls
- **Stability:** Stable
- **Purpose:** Generate IPP connection URLs for each printer
- **Parameters:** None
- **Returns:** `[PSCustomObject[]]` — Name, IPPUrl
- **Side effects:** None
- **Breaking-change risk:** Low

### Test-IPPEndpoint
- **Stability:** Stable
- **Purpose:** Validate IPP endpoint connectivity
- **Parameters:** Accepts printer name or IPP URL
- **Returns:** `[PSCustomObject]` — Success, Reachable, ResponseTime
- **Side effects:** Network I/O
- **Breaking-change risk:** Low

### Install-IPPServer
- **Stability:** Stable
- **Purpose:** Install Internet Printing Windows feature
- **Parameters:** None
- **Returns:** `[PSCustomObject]` — Success, Message
- **Side effects:** Installs Windows feature. Requires admin. Requires reboot on some systems.
- **Breaking-change risk:** Low

### Test-IPPClientInstalled
- **Stability:** Stable
- **Purpose:** Check if IPP client components are installed
- **Parameters:** None
- **Returns:** `[PSCustomObject]` — Installed, FeatureName, Message
- **Side effects:** None
- **Breaking-change risk:** Low

---

## Logging Module (5 functions)

### Initialize-Logging
- **Stability:** Stable
- **Purpose:** Initialize log file and directory on Desktop
- **Parameters:**
  - `-LogPath` (optional) — override log directory
- **Returns:** `[PSCustomObject]` — Success, LogFilePath
- **Side effects:** Creates directory and file on Desktop
- **Breaking-change risk:** Low

### Write-Log
- **Stability:** Stable
- **Purpose:** Write a timestamped entry to the log
- **Parameters:**
  - `-Message` (mandatory) — log text
  - `-Level` (optional, default INFO) — INFO, WARN, ERROR
  - `-Module` (optional) — module name for categorization
- **Returns:** `[PSCustomObject]` — Success
- **Side effects:** Appends to log file
- **Breaking-change risk:** Low

### Get-LogFilePath
- **Stability:** Stable
- **Purpose:** Return the current log file path
- **Parameters:** None
- **Returns:** `[string]` — full path to log file
- **Side effects:** None
- **Breaking-change risk:** Low

### Get-LogContent
- **Stability:** Stable
- **Purpose:** Read log entries with optional filtering
- **Parameters:**
  - `-Level` (optional) — filter by level
  - `-Tail` (optional) — return only last N entries
- **Returns:** `[string[]]` — log lines
- **Side effects:** None
- **Breaking-change risk:** Low

### Export-LogArchive
- **Stability:** Stable
- **Purpose:** Copy log file to a specified destination
- **Parameters:**
  - `-DestinationPath` (mandatory) — target directory or file
- **Returns:** `[PSCustomObject]` — Success, ArchivePath
- **Side effects:** Copies file
- **Breaking-change risk:** Low

---

## Utilities Module (7 functions)

### Test-Administrator
- **Stability:** Deprecated (use Assert-Elevated or Test-Elevated)
- **Purpose:** Check if running as Administrator
- **Returns:** `[bool]`
- **Side effects:** None
- **Breaking-change risk:** Removed in v6.0

### Test-Elevated
- **Stability:** Stable
- **Purpose:** Check if running as Administrator
- **Returns:** `[bool]`
- **Side effects:** None
- **Breaking-change risk:** Low

### Assert-Elevated
- **Stability:** Stable
- **Purpose:** Terminate function with error if not Administrator
- **Returns:** `[void]` (throws if not admin)
- **Side effects:** None
- **Breaking-change risk:** Low

### Confirm-DestructiveAction
- **Stability:** Stable
- **Purpose:** Prompt user to confirm a destructive operation
- **Parameters:**
  - `-Message` (mandatory) — action description
  - `-Force` (switch) — skip prompt
- **Returns:** `[bool]`
- **Side effects:** Reads keyboard input
- **Breaking-change risk:** Low

### Get-SystemInfo
- **Stability:** Stable
- **Purpose:** Return OS, hardware, and PowerShell environment details
- **Parameters:** None
- **Returns:** `[PSCustomObject]` — OSVersion, PowerShellVersion, Architecture, Memory, Processors, ExecutionPolicy, etc.
- **Side effects:** None
- **Breaking-change risk:** Low

### Write-MenuHeader
- **Stability:** Internal
- **Purpose:** Write a formatted menu header to the console
- **Returns:** `[void]`
- **Side effects:** Console output
- **Breaking-change risk:** Internal — may change without notice

### Wait-Menu
- **Stability:** Internal
- **Purpose:** Pause and wait for keypress (legacy, prefer Pause from root)
- **Returns:** `[void]`
- **Side effects:** Reads keyboard
- **Breaking-change risk:** Internal — may change without notice

---

## Android Module (3 functions)

### Get-AndroidCompatibility
- **Stability:** Stable
- **Purpose:** Analyze environment for Android/Mopria printing compatibility
- **Parameters:** None
- **Returns:** `[PSCustomObject]` — FirewallOk, NetworkProfileOk, PrinterSharingOk, ConnectionStrings, Issues
- **Side effects:** None
- **Breaking-change risk:** Low

### Show-AndroidWizard
- **Stability:** Stable
- **Purpose:** Display interactive Mopria/Android setup instructions
- **Parameters:** None
- **Returns:** `[void]`
- **Side effects:** Console output
- **Breaking-change risk:** Low

### Get-AndroidSetupContent
- **Stability:** Stable
- **Purpose:** Return Android setup instructions as structured content
- **Parameters:** None
- **Returns:** `[PSCustomObject]` — Steps, Requirements, ConnectionInfo
- **Side effects:** None
- **Breaking-change risk:** Low

---

## Diagnostics Module (5 functions)

### Get-NetworkValidation
- **Stability:** Stable
- **Purpose:** Run 17 network and printer checks, return results with score
- **Parameters:** None
- **Returns:** `[PSCustomObject]` — Results (array of check results), Score, PassPercentage, Timestamp
- **Side effects:** Network I/O
- **Breaking-change risk:** Low

### Show-NetworkValidationReport
- **Stability:** Stable
- **Purpose:** Display formatted network validation report
- **Parameters:** None
- **Returns:** `[void]`
- **Side effects:** Console output
- **Breaking-change risk:** Low

### Export-RegistrySnapshot
- **Stability:** Stable
- **Purpose:** Export HKLM\...\Print registry keys to a .reg file
- **Parameters:**
  - `-OutputPath` (optional) — override output location
- **Returns:** `[PSCustomObject]` — Success, Path
- **Side effects:** Writes file. Uses reg.exe export.
- **Breaking-change risk:** Low

### Export-FirewallSnapshot
- **Stability:** Stable
- **Purpose:** Export Windows Firewall rules to CSV
- **Parameters:**
  - `-OutputPath` (optional) — override output location
- **Returns:** `[PSCustomObject]` — Success, Path, RuleCount
- **Side effects:** Writes file
- **Breaking-change risk:** Low

### Export-ServiceSnapshot
- **Stability:** Stable
- **Purpose:** Export all service states to CSV
- **Parameters:**
  - `-OutputPath` (optional) — override output location
- **Returns:** `[PSCustomObject]` — Success, Path, ServiceCount
- **Side effects:** Writes file
- **Breaking-change risk:** Low

---

## Repair Module (2 functions)

### Initialize-RepairBackup
- **Stability:** Stable
- **Purpose:** Create pre-repair backup of registry, services, and PrintBRM config
- **Parameters:** None
- **Returns:** `[PSCustomObject]` — Success, BackupPath, Files
- **Side effects:** Creates backup directory and files. Requires admin.
- **Breaking-change risk:** Low

### Invoke-AutomaticShareRepair
- **Stability:** Stable
- **Purpose:** Execute 8-step automatic share repair with backup and rollback
- **Parameters:** None
- **Returns:** `[PSCustomObject]` — Success, Steps (array of step results), BackupPath
- **Side effects:** Modifies services, firewall, registry. Requires admin.
- **Breaking-change risk:** Medium (8 steps could change order in minor versions)

---

## Drivers Module (6 functions)

### Get-PrinterDriverDetails
- **Stability:** Stable
- **Purpose:** List driver details with Type 3 vs Type 4 classification
- **Parameters:** None
- **Returns:** `[PSCustomObject[]]` — Name, DriverType, Manufacturer, Version, IsType4
- **Side effects:** Runs pnputil for driver enumeration
- **Breaking-change risk:** Low

### Export-PrinterDrivers
- **Stability:** Stable
- **Purpose:** Export driver manifest (CSV + JSON) and driver INF files
- **Parameters:**
  - `-ExportPath` (mandatory) — output directory
- **Returns:** `[PSCustomObject]` — Success, CSVPath, JSONPath, DriverCount
- **Side effects:** Creates files. Requires admin.
- **Breaking-change risk:** Low

### Restore-PrinterDrivers
- **Stability:** Stable
- **Purpose:** Restore drivers from previously exported archive
- **Parameters:**
  - `-SourcePath` (mandatory, validated) — export directory
- **Returns:** `[PSCustomObject]` — Success, RestoredCount, Errors
- **Side effects:** Installs drivers. Requires admin.
- **Breaking-change risk:** Low

### Install-PrinterDriverFromInf
- **Stability:** Stable
- **Purpose:** Install a printer driver from an INF file
- **Parameters:**
  - `-InfPath` (mandatory, validated for .inf extension + path safety)
- **Returns:** `[PSCustomObject]` — Success, DriverName, Message
- **Side effects:** Installs driver. Requires admin.
- **Breaking-change risk:** Low

### Remove-PrinterDriverByName
- **Stability:** Stable
- **Purpose:** Remove a printer driver by name
- **Parameters:**
  - `-DriverName` (mandatory, ValidatePattern)
- **Returns:** `[PSCustomObject]` — Success, Message
- **Side effects:** Removes driver. Requires admin.
- **Breaking-change risk:** Low

### Get-DriverUpgradeRecommendations
- **Stability:** Stable
- **Purpose:** Suggest Type 4 driver upgrades for Type 3 drivers
- **Parameters:** None
- **Returns:** `[PSCustomObject[]]` — PrinterName, DriverName, CurrentType, RecommendedType, Notes
- **Side effects:** None
- **Breaking-change risk:** Low

---

## Sharing Module (7 functions)

### Get-PrinterShareStatus
- **Stability:** Stable
- **Purpose:** List share status for all printers
- **Parameters:** None
- **Returns:** `[PSCustomObject[]]` — Name, Shared, ShareName, Transport
- **Side effects:** None
- **Breaking-change risk:** Low

### Enable-PrinterSharing
- **Stability:** Stable
- **Purpose:** Enable SMB sharing on a printer
- **Parameters:**
  - `-PrinterName` (mandatory)
  - `-ShareName` (optional)
- **Returns:** `[PSCustomObject]` — Success, Message
- **Side effects:** Enables sharing. Requires admin.
- **Breaking-change risk:** Low

### Disable-PrinterSharing
- **Stability:** Stable
- **Purpose:** Disable SMB sharing on a printer
- **Parameters:**
  - `-PrinterName` (mandatory)
- **Returns:** `[PSCustomObject]` — Success, Message
- **Side effects:** Disables sharing. Requires admin.
- **Breaking-change risk:** Low

### Get-SmbSharePermissions
- **Stability:** Stable
- **Purpose:** List SMB share permissions for printer shares
- **Parameters:** None
- **Returns:** `[PSCustomObject[]]` — ShareName, AccountName, AccessRight
- **Side effects:** None
- **Breaking-change risk:** Low

### Set-PrinterSharePermission
- **Stability:** Stable
- **Purpose:** Set access rights on a printer share
- **Parameters:**
  - `-ShareName` (mandatory)
  - `-AccountName` (mandatory, DOMAIN\User format)
  - `-AccessRight` (mandatory, Read/Change/FullControl)
  - `-Force` (switch)
- **Returns:** `[PSCustomObject]` — Success, Message
- **Side effects:** Modifies share ACL. Requires admin.
- **Breaking-change risk:** Low

### Set-PrinterSharingTransport
- **Stability:** Stable
- **Purpose:** Switch printer transport between SMB, IPP, and WSD
- **Parameters:**
  - `-PrinterName` (mandatory)
  - `-Transport` (mandatory, SMB/IPP/WSD)
- **Returns:** `[PSCustomObject]` — Success, Message
- **Side effects:** Changes printer protocol. Requires admin.
- **Breaking-change risk:** Low

### Get-PrinterSharingCompatibility
- **Stability:** Stable
- **Purpose:** Assess sharing compatibility for each printer
- **Parameters:** None
- **Returns:** `[PSCustomObject[]]` — Name, DriverType, Compatibility, Warning
- **Side effects:** None
- **Breaking-change risk:** Low

---

## Reporting Module (2 functions)

### New-PrinterReport
- **Stability:** Stable
- **Purpose:** Generate printer report in HTML, JSON, CSV, or all formats
- **Parameters:**
  - `-Format` (mandatory, HTML/JSON/CSV/All)
- **Returns:** Depends on format — string for single, PSCustomObject for All
- **Side effects:** Console output for HTML
- **Breaking-change risk:** Low

### Get-PrintComplianceReport
- **Stability:** Stable
- **Purpose:** Validate printers against compliance rules (driver type, port, sharing)
- **Parameters:** None
- **Returns:** `[PSCustomObject[]]` — PrinterName, DriverType, Compliant, Issues
- **Side effects:** None
- **Breaking-change risk:** Low

---

## Bundle Module (1 function)

### New-DiagnosticBundle
- **Stability:** Stable
- **Purpose:** Collect 12 diagnostic sections into a single ZIP archive
- **Parameters:**
  - `-OutputPath` (optional) — override output ZIP path
- **Returns:** `[PSCustomObject]` — Success, Path, SizeKB, Sections (count of sections collected)
- **Side effects:** Collects system data, writes ZIP file
- **Breaking-change risk:** Low

---

## Internal Functions (Not Part of Public API)

### Show-DriverMenu
- **Stability:** Internal — interactive submenu, not for scripting
### Show-AndroidMenu
- **Stability:** Internal — interactive submenu, not for scripting
### Show-FirewallMenu
- **Stability:** Internal — interactive submenu, not for scripting
### Show-ShareMenu
- **Stability:** Internal — interactive submenu, not for scripting
### Pause
- **Stability:** Internal — custom keypress handler (shadows built-in Pause alias intentionally)

---

## API Summary

| Classification | Count | Functions |
|---------------|-------|-----------|
| Stable | 51 | All exported functions except those below |
| Experimental | 0 | |
| Internal | 5 | Show-DriverMenu, Show-AndroidMenu, Show-FirewallMenu, Show-ShareMenu, Pause |
| Deprecated | 1 | Test-Administrator (use Test-Elevated or Assert-Elevated) |
| **Total** | **57** | 55 exported + 5 internal − 1 deprecated = 51 stable exports |

## Versioning Commitments

- Stable functions will not break in v5.2.x or v5.3
- Deprecated functions will be removed in v6.0 (with v5.3 deprecation warnings)
- Internal functions have no compatibility guarantees
- New parameters may be added to stable functions in minor versions (backward-compatible)
- Return types will not change for stable functions
