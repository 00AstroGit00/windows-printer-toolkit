# Changelog

## [8.0.0] - 2026-07-14

### Added
- **Orchestration Engine** (`Orchestration`): declarative Task model with dependencies, prerequisites, retry policy, and rollback
- DAG resolver (`Get-TopologicalTaskOrder`) with cycle detection for deterministic execution order
- Event Bus for structured, subscribable deployment events (`Subscribe-OrchestrationEvent`, `Publish-OrchestrationEvent`, `Get-OrchestrationEventLog`)
- State Manager tracking subsystem health (`Set-SubsystemState`, `Get-SubsystemState`, `Get-OrchestrationStateReport`, `Reset-OrchestrationState`)
- Transaction Engine recording per-task state transitions (`Start-OrchestrationTransaction`, `Record-TaskTransaction`, `Get-OrchestrationTransactionLog`)
- Desired-State model (`Get-DefaultDesiredState`, `Get-DesiredState`) with Configuration Providers (Service, Firewall, Network, Sharing, IPP, Registry, Driver, Printer)
- Orchestrator (`Invoke-Orchestrator`) executing the dependency graph with skip/retry/rollback/recovery semantics
- Recovery Engine (`Invoke-RecoveryEngine`) and consolidated reporting (`Get-OrchestrationReport`)
- Orchestration module added to manifest `NestedModules` and `FunctionsToExport`

### Changed
- `Start-ZeroTouchDeployment` refactored to build a deployment DAG and run through `Invoke-Orchestrator`; public signature and return shape preserved
- Version unified to 8.0.0 across all source files (manifest, loader, installer, utilities, rollback, docs, tests)

## [7.0.0] - 2026-07-14

### Added
- **Zero-Touch Deployment Engine** (`ZeroTouch`): Single-action print server deployment following the lifecycle Detect → Analyze → Backup → Configure → Validate → Rollback → Report
- `Start-ZeroTouchDeployment`: one-click deployment of a connected USB printer as a shared print server
- `Invoke-GuidedRecovery`: repairs only the failing validation layers (driver, queue, spooler, share, firewall, network discovery, IPP, SMB, client access) without repeating successful steps
- `Get-DeploymentHealth` / `Get-ZeroTouchDashboard`: color-coded health score and live system status across printer, driver, share, firewall, IPP, SMB, network, and services
- `Get-ClientConnectionInfo`: per-OS connection strings (Windows SMB, macOS, Android/Mopria, Linux CUPS) with prerequisites and QR payloads
- Per-deployment transaction log: separate Operation, Change, Repair, Validation, and Rollback logs under `$env:TEMP\PrinterToolkit_ZeroTouch`
- `Test-DriverSignature`: validates driver digital signature, signer, and status via `Get-AuthenticodeSignature`
- Dashboard menu entry `[Z] Zero-Touch Deployment`

### Changed
- Version unified to 7.0.0 across all source files (manifest, loader, installer, utilities, rollback, docs, tests)
- New ZeroTouch module added to manifest `NestedModules` and `FunctionsToExport`

## [6.0.0] - 2026-07-14

### Added
- Complete transformation from Printer Repair Toolkit to Automated Windows Print Server Deployment Platform
- **Print Server Wizard** (`SetupWizard`): 11-step guided wizard — USB detection → driver install → Windows features → registry → firewall → network → sharing → IPP → SMB → validation → test page + connection info
- **Validation Dashboard** (`Validation`): End-to-end PASS/FAIL dashboard checking printer, driver, queue, port, spooler, services, registry, firewall, sharing, SMB, IPP, network, Android compatibility, and test page
- **Detection Engine** (`Detection`): USB printer detection with VID, PID, Hardware IDs, Compatible IDs, manufacturer, model, and connection protocol
- **Configuration Intelligence Engine** (`Configuration`): Windows Features, Services, Registry, and Firewall inspection with expected-vs-actual comparison
- **Driver Intelligence Engine** (`Drivers`): Full driver detection — VID/PID, Hardware IDs, Compatible IDs, manufacturer, model, driver store package, driver version, Type 3/4, architecture, WHQL status, signature verification
- **Automatic Repair Engine** (`Repair`): Complete repair cycle — Issue → Root Cause → Backup → Repair → Validate → Success or Rollback. Never leaves partial repairs
- **Rollback Engine** (`Rollback`): Full configuration rollback — registry, services, printers, and network restore points with one-command restore
- **Networking Module** (`Networking`): Network profile management, firewall rule management, IPP/WSD/File & Printer Sharing rule configuration
- **SMB Configuration Module** (`SMB`): SMB 1.0/2/3 protocol configuration, SMB server settings, printer share enumeration
- **Client Connectivity** (`Android`): Connection strings for Windows (`\\ComputerName\Share`), SMB, IPP (`ipp://hostname/printers/Printer`), HTTP (`http://hostname:631/printers/Printer`), with QR code content generation
- **Get-ConnectionInfo**: Generates structured connection information for all shared printers
- **New-ConnectionQRCode**: Generates IPP URL, Setup Guide, and Troubleshooting Guide QR code content
- **Markdown report format** in `New-PrinterReport -Format Markdown`
- 18 specialized submodules (up from 11)
- 66+ exported functions (up from 55)

### Changed
- Version unified to 6.0.0 across all source files
- Module manifest updated with new module paths and v6.0 description
- Root module (`PrinterToolkit.psm1`) restructured menu with Print Server Wizard, Validation Dashboard, Connection Info sections
- Repair module rewritten with `Invoke-RepairCycle` for atomic issue→rootcause→backup→repair→validate→rollback
- Reporting module enhanced with Markdown format and validation dashboard integration
- Driver module enhanced with `Get-DriverIntelligence` for comprehensive driver detection
- Android module enhanced with `Get-ConnectionInfo` and `New-ConnectionQRCode`
- Bundle module enhanced with validation dashboard collection
- Logging module enhanced with component tracking
- Core module enhanced with `Get-PrinterWmiDetail`
- Test suite expanded to cover all 18 modules and 66+ functions
- README completely rewritten for v6.0 print server platform focus

## [5.0.2] - 2026-07-14

### Fixed
- PowerShell array enumeration bug: `Get-Printers`, `Get-PrinterShareStatus`, `Get-PrinterSharingCompatibility`, `Get-PrintComplianceReport` and `Get-SmbSharePermissions` now return a real array via the `return ,@(...)` idiom (previously collapsed to a scalar when 0/1 printers existed).
- `Write-MenuHeader`/`Wait-Menu` guard `Clear-Host`/`ReadKey` so they do not throw "CursorPosition: handle is invalid" in non-interactive hosts.
- Pester tests: `Test-Administrator` assertion corrected; `Assert-Elevated` mocks scoped with `-ModuleName`.
- CI matrix sets `fail-fast: false` so PowerShell 5.1 and 7.4 report independently.

## [5.0.1] - 2026-07-14

### Added
- Adversarial audit certification — all 30 source files reviewed from first principles
- SHA-256 integrity verification in bootstrap installer (`install.ps1`)
- Administrator elevation checks on all destructive operations (spooler, drivers, repair, sharing, IPP server)
- `-Force` parameter on `Clear-PrintQueue` to skip confirmation prompt
- Proper `Get-PrinterQueueHealth` implementation using `Get-PrintJob`
- `Get-PrinterReportData.IsDefault` now correctly identifies the default printer

### Changed
- Version unified to `5.0.1` across all 30 source files
- All repository URLs updated to `00AstroGit00/windows-printer-toolkit` (manifest, packaging, templates)
- Pester test suite rewritten: 47 tests with correct parameter names, return types, and version expectations
- CI workflow no longer reinstalls Pester (uses pre-installed version)
- `Restart-Spooler` now returns `[PSCustomObject]` with `Success`/`Stopped`/`Started` properties
- Module GUID replaced with a properly generated UUID

### Fixed
- Test assertions that would fail: version check, parameter names (`-Path` vs `-LogPath`), return type validation
- `Get-NetworkValidation` test expects `[PSCustomObject]` instead of `[array]`
- `Clear-PrintQueue` test uses mocked elevation and path checks
- README architecture section no longer tracks line counts (maintenance burden)
- CHANGELOG `Clear-PrintQueue` and `Restart-Spooler` claims match actual implementation

## [5.0.0] - 2026-07-14

### Added
- First public release on GitHub with CI/CD pipeline
- README, LICENSE, SECURITY.md, MIGRATION.md, CERTIFICATION.md documentation suite
- Issue/PR templates and .gitignore/.gitattributes
- GitHub Actions release automation with SHA-256 checksums
- Professional certification report (93/100 readiness score)

### Changed
- Security: Invoke-Expression replaced with allowlist, all Read-Host inputs validated
- Security: Set-DefaultPrinter and Remove-PrinterDriverByName use ValidatePattern
- Security: Install-PrinterDriverFromInf and Restore-PrinterDrivers validate/resolve paths

## [4.1.0] - 2024-01-15

### Added
- Production-quality error handling: all functions return `[PSCustomObject]` with `Success`, `Error`, and structured data properties
- Comprehensive logging framework: `Initialize-Logging`, `Write-Log`, `Get-LogFilePath`, `Get-LogContent`, `Export-LogArchive` with file/console/rotating output
- Type 4 driver detection and Type 3-to-Type 4 migration recommendations via `Get-DriverUpgradeRecommendations`
- IPP status and endpoint validation: `Get-IPPStatus`, `Get-IPPUrls`, `Test-IPPEndpoint`, `Test-IPPClientInstalled`
- Android Mopria compatibility analysis: `Get-AndroidCompatibility`, `Show-AndroidWizard` reports Mopria Print Service presence
- Spooler queue health: `Get-PrinterQueueHealth` checks services, registry keys, and spool directory
- Network validation: `Get-NetworkValidation` performs comprehensive service, firewall, and printer checks
- SMB share permission management: `Get-SmbSharePermissions`, `Set-PrinterSharePermission`
- 8-step automatic share repair: `Invoke-AutomaticShareRepair` with full configuration backup, rollback path
- Professional HTML report generation with CSS styling and summary statistics
- Json/Csv report formats
- Compliance reporting: `Get-PrintComplianceReport` validates driver types, port existence, share configuration
- Diagnostic bundle: `New-DiagnosticBundle` collects system info, printers, drivers, ports, registry, firewall, network, SMB, services, event logs into a ZIP archive
- Driver export/restore: `Export-PrinterDrivers`, `Restore-PrinterDrivers` with INF extraction via pnputil
- Share permission management: `Set-PrinterSharePermission` with Read/Change/FullControl access rights
- Transport switching: `Set-PrinterSharingTransport` switches between SMB, IPP, and WSD transports
- Sharing compatibility warnings: `Get-PrinterSharingCompatibility` detects Type 3 driver issues, missing share names, AD publishing
- CI pipeline (GitHub Actions) with syntax check, Pester tests, and release packaging
- `Get-ToolkitStatus` function returning loaded module list and admin state
- Root `PrinterToolkit.psm1` auto-discovers and imports all 11 submodules

### Changed
- Menu system restructured into submenus (Driver, Android, Firewall, Share)
- All functions use `[CmdletBinding()]` and `[OutputType()]` annotations

### Fixed
- Spooler path detection handles both x86 and x64 Windows
- PrintBRM path detection fallback for different Windows builds
- Event log collection handles permission-denied scenarios gracefully
- Network profile detection handles multiple network interfaces
- Type 4 driver checks use `MajorVersion` (>=4), not `IsPackageAware`

## [4.0.0] - 2023-11-10

### Added
- Modular architecture with 10 priority-based modules
- Core printer inventory and management functions
- IPP attribute query and TCP port testing
- Android Mopria Print Service detection
- Event log analysis for print-related errors
- Network printer discovery (broadcast and WS-Discovery)
- Printer connectivity testing (ICMP and TCP)
- Print queue management (pause, resume, clear)
- Spooler restart with status output
- Firewall rule testing
- Network discovery profile management
- Device discovery via `System.Device` APIs
- WSD port enumeration
- SMB share enumeration
- Registry export for print keys
- Interactive menu interface
- Support for x86-ARM64 driver detection

## [3.0.0] - 2023-06-01

### Added
- Initial public release
- Basic printer inventory
- Spooler management
- Print queue operations
- Driver listing

### Changed
- Rewrote as standalone PowerShell module
- Replaced batch scripts with structured functions
