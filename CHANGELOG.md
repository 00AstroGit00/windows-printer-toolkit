# Changelog

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
- `Clear-PrintQueue` now takes a `-Force` parameter to skip confirmation
- `Restart-Spooler` returns structured result with exit code
- `Test-IPPEndpoint` validates both TCP port and WSD port availability
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
