# PrinterToolkit — Architecture Guide

**Version:** 5.2
**Date:** 2026-07-14

---

## 1. High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    External Entry Points                      │
│  launcher.ps1    install.ps1    Import-Module    CI/build.ps1 │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────────┐
│                  PrinterToolkit.psd1 (Manifest)               │
│  ModuleVersion=5.0.1, 55 FunctionsToExport, CompatiblePSVer  │
└─────────────────────────┬────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────────┐
│               PrinterToolkit.psm1 (Root Loader)               │
│  - Loads 11 submodules in fixed order                        │
│  - Defines Invoke-ToolkitMainMenu (interactive shell)        │
│  - Defines 4 submenu functions (Show-DriverMenu, etc.)       │
│  - Defines Get-ToolkitStatus (health check)                  │
│  - Defines Pause helper                                      │
└─────┬─────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┬─┘
      │     │      │      │      │      │      │      │      │
      ▼     ▼      ▼      ▼      ▼      ▼      ▼      ▼      ▼
┌──────┐┌────┐┌──────┐┌────────┐┌───────┐┌───────────┐┌──────┐
│ Core ││ IPP││Log.  ││Utilities││Android││Diagnostics ││Repair│
└──────┘└────┘└──────┘└────────┘└───────┘└───────────┘└──────┘
  │              ┌───────┐┌────────┐┌────────┐
  │              │Drivers││Sharing ││Reporting│
  │              └───────┘└────────┘└────────┘
  │              ┌──────┐
  │              │Bundle│
  │              └──────┘
  │
  └── Each module exports functions independently
      No cross-module imports. All communication through root.
```

## 2. Module Dependency Graph

```
PrinterToolkit.psm1
├── Core          (spooler, printers, queue)
├── IPP           (IPP protocol)
├── Logging       (structured logging)
├── Utilities     (admin check, system info, UI)
├── Android       (Mopria compatibility)
├── Diagnostics   (network validation, snapshots)
├── Repair        (share repair, backup/rollback)
├── Drivers       (Type 3/4, export, restore, INF)
├── Sharing       (SMB/IPP/WSD, permissions)
├── Reporting     (HTML/JSON/CSV, compliance)
└── Bundle        (diagnostic ZIP)
```

**Key property:** No module depends on another module. They are all independent leaf modules loaded by the root. The only shared dependency is `Logging` — modules call `Write-Log` but Logging does not import them.

## 3. Call Graph: Public Commands

### Interactive Flow
```
Invoke-ToolkitMainMenu
├── Option 1 → Get-Printers
├── Option 2 → Get-PrinterStatus
├── Option 3 → Get-SharedPrinters
├── Option 4 → Test-IPPEndpoint
├── Option 5 → Clear-PrintQueue -Force
├── Option 6 → Get-IPPStatus
├── Option 7 → Test-IPPClientInstalled
├── Option 8 → Show-DriverMenu
│   ├── 1 → Get-PrinterDriverDetails
│   ├── 2 → Export-PrinterDrivers
│   ├── 3 → Install-PrinterDriverFromInf
│   ├── 4 → Remove-PrinterDriverByName
│   └── 5 → Get-DriverUpgradeRecommendations
├── Option 9 → Get-DriverUpgradeRecommendations
├── Option 10 → Show-AndroidMenu
│   ├── 1 → Get-AndroidCompatibility
│   ├── 2 → Show-AndroidWizard
│   └── 3 → Get-AndroidSetupContent
├── Option 11 → Show-NetworkValidationReport
├── Option 12 → Get-PrinterQueueHealth
├── Option 13 → Show-FirewallMenu
│   ├── 1 → Get-NetworkValidation
│   ├── 2 → Show-NetworkValidationReport
│   ├── 3 → Export-FirewallSnapshot
│   └── 4 → Export-ServiceSnapshot
├── Option 14 → Export-RegistrySnapshot; Export-ServiceSnapshot
├── Option 15 → Invoke-AutomaticShareRepair
├── Option 16 → Show-ShareMenu
│   ├── 1 → Get-PrinterShareStatus
│   ├── 2 → Enable-PrinterSharing
│   ├── 3 → Disable-PrinterSharing
│   ├── 4 → Get-SmbSharePermissions
│   ├── 5 → Set-PrinterSharePermission
│   └── 6 → Get-PrinterSharingCompatibility
├── Option 17 → New-PrinterReport -Format HTML
├── Option 18 → Get-PrintComplianceReport
├── Option 19 → New-DiagnosticBundle
└── Option 0 → exit
```

### CLI Flow
```
launcher.ps1
├── -Menu          → Invoke-ToolkitMainMenu (default)
├── -CommandLine
│   └── allowlist check → Invoke-Expression (restricted)
└── -Quiet         → suppress banner
```

### Bootstrap Flow
```
install.ps1
├── [1/3] Download release ZIP from GitHub
│   ├── SHA-256 verification (if SHA256SUMS asset exists)
│   └── Fallback to main.zip (no verification)
├── [2/3] Extract to temp directory
├── [3/3] Import module, show status, open dashboard
└── Cleanup (unless -Keep)
```

## 4. Data Flow Diagrams

### Printer Discovery
```
User → Get-Printers
  → WMI: Get-CimInstance Win32_Printer
  → Select properties: Name, Shared, PortName, DriverName, Status
  → Return [PSCustomObject[]] with typed fields
```

### Queue Clear
```
User → Clear-PrintQueue -PrinterName <name> [-Force]
  → Assert-Elevated (admin check)
  → Get-PrintJob (enumerate jobs)
  → For each job: Remove-PrintJob
  → Return [PSCustomObject] with cleared count
```

### Network Validation
```
User → Get-NetworkValidation
  → 17 checks:
     1. Spooler service status
     2. Print spooler dependency services
     3. Firewall profiles (Domain/Private/Public)
     4. Firewall rules for printer ports (TCP 139, 445, 631, 5357)
     5. Printer status (each installed printer)
     6. Print queue health (each queue)
     7. Registry: spool directory exists
     8. Registry: print processor registered
     9. Network discovery profile
    10. SMB 1.0/2.0/3.0 protocol availability
    11. PrintBRM tool presence
    12. WSD port availability
    13. TCP port 631 (IPP) test
    14. TCP port 445 (SMB) test
    15. DNS resolution of local hostname
    16. IPP endpoint test
    17. Android firewall compatibility
  → Return [PSCustomObject] with check results + score
```

### Diagnostic Bundle
```
User → New-DiagnosticBundle
  → Create temp directory with random name
  → Collect 12 sections:
     1. System info (OS, RAM, CPU, PowerShell version)
     2. Printers (Get-Printer output)
     3. Drivers (Get-PrinterDriver output)
     4. Ports (Get-PrinterPort output)
     5. Registry export (HKLM\...\Print)
     6. Firewall rules (netsh advfirewall)
     7. Services state (Get-Service)
     8. Network config (ipconfig /all)
     9. SMB config (Get-SmbShare, etc.)
    10. Event logs (System + PrintService)
    11. Toolkit logs (Get-LogContent)
    12. Bundle manifest (metadata JSON)
  → Compress-Archive to ZIP
  → Return [PSCustomObject] with path and size
```

## 5. Logging Flow

```
Application code
  │
  ▼
Write-Log -Message <text> -Level <INFO|WARN|ERROR> [-Module <name>]
  │
  ▼
Initialize-Logging (called once at module load or explicitly)
  ├── Creates log directory: $env:USERPROFILE\Desktop\PrinterToolkit\Logs\
  ├── Creates log file: PrinterToolkit_<date>.log
  └── Sets $Script:LogFilePath
  │
  ▼
Get-LogContent [-Level <filter>] [-Tail <count>]
  └── Returns log entries as string[]
  │
  ▼
Export-LogArchive -DestinationPath <path>
  └── Copies log file to specified destination
```

**Log format:** `[2026-07-14 12:00:00] [INFO] [ModuleName] Message`

## 6. Error Handling Flow

```
Function entry
  │
  ▼
Parameter validation ([Validate*] attributes)
  │  Failure → PowerShell throws ParameterBindingException automatically
  │
  ▼
Assert-Elevated (if destructive)
  │  Failure → return [PSCustomObject]@{Success=$false; Error="Admin required"}
  │
  ▼
try {
    Main operation
    │
    ▼
    return [PSCustomObject]@{Success=$true; <data properties>}
}
catch {
    Write-Log -Message "<FunctionName> failed: $_" -Level ERROR
    │
    ▼
    return [PSCustomObject]@{Success=$false; Error=$_.Exception.Message}
}
```

**All 55 exported functions follow this pattern.** No exported function throws unhandled exceptions.

## 7. Repair Workflow (8 Steps)

```
Invoke-AutomaticShareRepair
  │
  ├── Step 1: Initialize-RepairBackup
  │   ├── Export registry: HKLM\...\Print
  │   ├── Export service states
  │   └── Export PrintBRM configuration
  │
  ├── Step 2: Restart Spooler
  │   └── Restart-Spooler
  │
  ├── Step 3: Verify Spooler Service
  │   └── Check service status, startup type
  │
  ├── Step 4: Verify Spool Directory
  │   └── Check C:\Windows\System32\spool\PRINTERS\ exists
  │
  ├── Step 5: Check Print Processor Registration
  │   └── Registry: HKLM\...\Print\Printers\<printer>\Print Processor
  │
  ├── Step 6: Verify Firewall Rules
  │   └── Check TCP 139, 445, 631, 5357 rules exist
  │
  ├── Step 7: Test Network Discovery
  │   └── Check network profile is not Public
  │
  └── Step 8: Verify Print Spooler Dependencies
      └── Check RPCSS, HTTP service dependencies
  │
  ▼
Return [PSCustomObject] with step results + overall success
```

## 8. Installer Workflow

```
install.ps1
  │
  ├── Resolve temp directory: $env:TEMP\PrinterToolkit\<timestamp>\
  │
  ├── [1/3] Download
  │   ├── GET /repos/00AstroGit00/windows-printer-toolkit/releases/latest
  │   ├── Find ZIP asset in release
  │   ├── Download ZIP to temp
  │   ├── Find SHA256SUMS asset
  │   ├── Download checksums
  │   ├── Compute Get-FileHash on ZIP
  │   ├── Compare hashes (fail on mismatch)
  │   └── If release unavailable:
  │       └── Download archive/refs/heads/main.zip (no hash verify)
  │
  ├── [2/3] Extract
  │   ├── Expand-Archive to temp
  │   └── Find PrinterToolkit root directory
  │
  ├── [3/3] Load
  │   ├── Import-Module PrinterToolkit.psd1
  │   ├── Get-ToolkitStatus (verify load)
  │   └── Invoke-ToolkitMainMenu
  │
  └── Cleanup
      └── Remove-Item temp directory (unless -Keep)
```

## 9. Release Workflow

```
Developer pushes tag v5.x.x
  │
  ▼
GitHub Actions (ci.yml)
  │
  ├── analyze job
  │   ├── windows-latest
  │   ├── Matrix: PS 5.1, 7.4
  │   ├── Syntax check (all .ps1/.psm1 files)
  │   └── Invoke-Pester (49 tests)
  │
  ├── build job (needs: analyze)
  │   ├── ./CI/build.ps1 -Configuration Release
  │   └── Upload artifact (.zip)
  │
  └── release job (needs: build, on tag)
      ├── softprops/action-gh-release
      ├── Attach PrinterToolkit*.zip
      └── generate_release_notes: true
```

## 10. Module Internal Structure

Each `.psm1` file follows this pattern:
```powershell
<#
.SYNOPSIS
    Module Name — brief description
.DESCRIPTION
    Longer description of the module's purpose.
.NOTES
    Version: 5.0.1
    Module: <Name>
#>

# Functions...
function Get-Example { ... }
function Set-Example { ... }

Export-ModuleMember -Function Get-Example, Set-Example
```

The module's `Export-ModuleMember` at the bottom is the authority for what that module exposes. The manifest aggregates all exports.
