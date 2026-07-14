# PrinterToolkit v5.1 — Detailed Test Cases

**Campaign:** Hardware Validation
**Total Test Cases:** 92
**Format:**
- Test ID
- Objective
- Prerequisites
- Test Environment
- Exact Execution Steps
- Expected Result
- Pass Criteria
- Failure Criteria
- Evidence to Collect
- Severity if the test fails

---

## Module Import (IMP)

---

### IMP-001: Import Module from Manifest
- **Objective:** Verify that `Import-Module` against `PrinterToolkit.psd1` loads all 11 submodules without errors.
- **Prerequisites:** Repository cloned/extracted to local disk. PowerShell session started.
- **Test Environment:** E1–E10
- **Execution Steps:**
  1. Open PowerShell (5.1 or 7.x) as the user privilege level under test.
  2. Run: `$m = Import-Module .\PrinterToolkit\PrinterToolkit.psd1 -Force -PassThru`
  3. Run: `$m.ExportedFunctions.Count`
  4. Run: `Get-ToolkitStatus`
  5. Run: `Get-Module PrinterToolkit`
- **Expected Result:** Module imports silently. `$m.ExportedFunctions.Count` returns 55. `Get-ToolkitStatus` returns version 5.0.1+, 11 loaded modules, 0 failed modules. `Get-Module` shows the module with correct version.
- **Pass Criteria:** All 5 steps succeed. No warnings or errors in output. 55 functions exported. 11 modules loaded.
- **Failure Criteria:** Any import error. Fewer than 11 modules loaded. Version mismatch.
- **Evidence:** PowerShell transcript, console screenshot, `Get-ToolkitStatus` output.
- **Severity:** Critical

---

### IMP-002: Import Module from Root PSM1
- **Objective:** Verify that `Import-Module` against `PrinterToolkit.psm1` loads correctly.
- **Prerequisites:** Same as IMP-001. Manifest file present alongside PSM1.
- **Test Environment:** E1, E3, E5, E7, E9 (Admin)
- **Execution Steps:**
  1. Run: `Import-Module .\PrinterToolkit\PrinterToolkit.psm1 -Force`
  2. Run: `Get-ToolkitStatus`
  3. Run: `Get-Command -Module PrinterToolkit | Measure-Object`
- **Expected Result:** Module loads. Status shows 11 modules.
- **Pass Criteria:** 55 commands available. No errors.
- **Failure Criteria:** Partial load. Missing functions.
- **Evidence:** Transcript, command count.
- **Severity:** Critical

---

### IMP-003: Import as Non-Administrator
- **Objective:** Verify that the module loads under a Standard User account without errors (even if some functions will later fail on elevation checks).
- **Prerequisites:** Standard User account on test machine. Module accessible.
- **Test Environment:** E2, E4, E6, E9
- **Execution Steps:**
  1. Log in as Standard User.
  2. Open PowerShell.
  3. Run: `Import-Module .\PrinterToolkit\PrinterToolkit.psd1 -Force`
  4. Run: `Get-ToolkitStatus`
  5. Run: `Get-Printers`
  6. Run: `Assert-Elevated` (should fail gracefully)
- **Expected Result:** Module imports. 11 modules loaded. `Get-Printers` returns printer list (read-only). `Assert-Elevated` returns non-terminating error or `$false`.
- **Pass Criteria:** No import errors. Non-destructive functions work. Elevation check does not crash.
- **Failure Criteria:** Module fails to load. Console error on import.
- **Evidence:** Transcript, status output.
- **Severity:** High

---

### IMP-004: Import with Missing Submodule
- **Objective:** Verify graceful degradation when a submodule file is missing.
- **Prerequisites:** Admin access. Backup of module directory.
- **Test Environment:** E1, E3, E5
- **Execution Steps:**
  1. Copy `Modules\Bundle\PrinterToolkit.Bundle.psm1` to a backup location.
  2. Delete `Modules\Bundle\PrinterToolkit.Bundle.psm1`.
  3. Run: `Import-Module .\PrinterToolkit\PrinterToolkit.psd1 -Force`
  4. Run: `Get-ToolkitStatus`
  5. Restore the deleted file.
  6. Repeat steps 1–5 with `Modules\Core\PrinterToolkit.Core.psm1`.
- **Expected Result:** First deletion: module loads, 10 modules reported, 1 failed in `FailedModules`. `New-DiagnosticBundle` produces an error message. Second deletion: module loads, 10 modules, core function `Get-Printers` unavailable but no crash.
- **Pass Criteria:** Module always loads. Missing module gracefully reported. No crash on calling missing function.
- **Failure Criteria:** Module fails to load entirely. Terminating error from missing module.
- **Evidence:** Before/after screenshots, transcript, status output.
- **Severity:** High

---

## Bootstrap Installer (BSI)

---

### BSI-001: Run One-Liner Installer
- **Objective:** Verify the one-liner from README downloads and runs the toolkit.
- **Prerequisites:** Internet access. No existing `PrinterToolkit` directory in TEMP.
- **Test Environment:** E1, E3, E5, E7 (Admin)
- **Execution Steps:**
  1. Open PowerShell as Administrator.
  2. Run the one-liner from README:
     ```powershell
     powershell -ExecutionPolicy Bypass -Command "iwr -Uri https://github.com/00AstroGit00/windows-printer-toolkit/raw/main/install.ps1 -OutFile \"$env:TEMP\ptk.ps1\"; & \"$env:TEMP\ptk.ps1\""
     ```
  3. Wait for the dashboard to appear.
  4. Press `0` to exit.
- **Expected Result:** Script downloads, extracts, imports module, opens interactive dashboard. Clean exit removes temp files.
- **Pass Criteria:** Dashboard appears. Exit is clean. Temp directory is removed.
- **Failure Criteria:** Download fails. Extract fails. Dashboard does not appear. Temp files remain after exit.
- **Evidence:** Full console screenshot showing download → dashboard → exit. Check TEMP folder after exit.
- **Severity:** Critical

---

### BSI-002: Run Installer with -Keep
- **Objective:** Verify the `-Keep` flag preserves extracted files.
- **Prerequisites:** Internet access.
- **Test Environment:** E1, E3, E5 (Admin)
- **Execution Steps:**
  1. Run: `& "$env:TEMP\ptk.ps1" -Keep` (after downloading install.ps1).
  2. Exit the dashboard with `0`.
  3. Check: `Test-Path "$env:TEMP\PrinterToolkit"`
- **Expected Result:** Files remain after exit. Module root path exists.
- **Pass Criteria:** Dashboard works. Files persist after exit.
- **Failure Criteria:** Files removed despite `-Keep`. Dashboard errors.
- **Evidence:** Screenshot, directory listing after exit.
- **Severity:** High

---

### BSI-003: SHA-256 Verification
- **Objective:** Verify the installer validates the release ZIP checksum.
- **Prerequisites:** Internet access. A release with SHA256SUMS asset.
- **Test Environment:** E1, E3, E5 (Admin)
- **Execution Steps:**
  1. Run install.ps1 with verbose output: `$VerbosePreference = 'Continue'; & "$env:TEMP\ptk.ps1"`
  2. Observe the SHA-256 line in output.
  3. Exit.
- **Expected Result:** Output includes a SHA-256 verification line showing the first 16 hex chars followed by "... verified".
- **Pass Criteria:** Verification message appears.
- **Failure Criteria:** No verification message. Hash mismatch error.
- **Evidence:** Screenshot showing verification line.
- **Severity:** High

---

### BSI-004: Installer Fallback When No Release
- **Objective:** Verify fallback to `main.zip` when no release asset exists.
- **Prerequisites:** Internet access.
- **Test Environment:** E1, E3 (Admin)
- **Execution Steps:**
  1. Modify install.ps1 temporarily to use a non-existent release tag.
  2. Run: `& "$env:TEMP\ptk.ps1"`
- **Expected Result:** Installer falls back to main branch ZIP. Warning shown: "Integrity cannot be verified on fallback path".
- **Pass Criteria:** Fallback succeeds. Module loads. Warning displayed.
- **Failure Criteria:** Script crashes on fallback. No warning.
- **Evidence:** Transcript, warning screenshot.
- **Severity:** Medium

---

## Menu Navigation (MEN)

---

### MEN-001: Main Menu All Options
- **Objective:** Verify every main menu option invokes the correct function without errors.
- **Prerequisites:** Module imported. Admin privileges.
- **Test Environment:** E1, E3, E5, E8, E10
- **Execution Steps:**
  1. Run: `Invoke-ToolkitMainMenu`
  2. For each option 1–19, select the option, observe the output, press any key, return to menu.
  3. Record any errors or unexpected behavior per option.
- **Expected Result:** Each option executes its function, displays output, and returns to menu on keypress.
- **Pass Criteria:** All 19 options execute without terminating errors. Output is meaningful (not empty or "command not found").
- **Failure Criteria:** Any option produces a red error. Any option exits the menu unexpectedly. Any option produces no output.
- **Evidence:** Screenshot per option (or video), transcript.
- **Severity:** Critical

---

### MEN-002: Submenu Navigation
- **Objective:** Verify all 4 submenus (Driver, Android, Firewall, Share) navigate correctly.
- **Prerequisites:** Module imported. Admin.
- **Test Environment:** E1, E3, E5
- **Execution Steps:**
  1. From main menu, select 8 (Driver Management).
  2. Execute each sub-option 1–5.
  3. Select 0 to return to main menu.
  4. Repeat for options 10 (Android), 13 (Firewall), 16 (Share).
- **Expected Result:** Each submenu displays correctly. Options execute. `0` returns to main menu.
- **Pass Criteria:** All submenus navigable. All sub-options work. Back navigation works.
- **Failure Criteria:** Submenu doesn't display. Option crashes. Back returns to submenu instead of main.
- **Evidence:** Screenshots of each submenu, transcript.
- **Severity:** High

---

### MEN-003: Invalid Menu Input
- **Objective:** Verify invalid menu input is handled gracefully.
- **Prerequisites:** Module imported.
- **Test Environment:** E1, E2, E3
- **Execution Steps:**
  1. Open menu.
  2. Enter: `99`, `abc`, `-1`, `(empty)`, `!@#$`
- **Expected Result:** Each invalid input prints "Invalid option." in red and returns to menu.
- **Pass Criteria:** No crash. Clear error message. Menu redisplays.
- **Failure Criteria:** Terminating error. PowerShell exception. Menu exits.
- **Evidence:** Screenshot of each invalid input attempt.
- **Severity:** Medium

---

### MEN-004: Exit from Menu
- **Objective:** Verify `0` exits the menu cleanly.
- **Prerequisites:** Module imported.
- **Test Environment:** E1–E10
- **Execution Steps:**
  1. Open menu.
  2. Select `0`.
- **Expected Result:** Menu exits. PowerShell prompt returns. No errors.
- **Pass Criteria:** Exit is clean.
- **Failure Criteria:** Menu does not exit. Error on exit.
- **Evidence:** Transcript showing prompt return.
- **Severity:** Critical

---

## Printer Discovery (PDV)

---

### PDV-001: Get-Printers Returns All Installed Printers
- **Objective:** Verify `Get-Printers` enumerates all installed printers.
- **Prerequisites:** At least 3 printers installed (mix of USB, network, software). Module imported.
- **Test Environment:** E1, E3, E5, E7, E8
- **Execution Steps:**
  1. Run: `$printers = Get-Printers`
  2. Run: `$printers | Format-Table Name, Shared, PortName, DriverName`
  3. Run: `$printers.Count`
  4. Compare count with `Get-Printer | Measure-Object`.
- **Expected Result:** `Get-Printers` returns all printers. Output is `[PSCustomObject[]]` with Name, Shared, PortName, DriverName, Status, IsDefault properties.
- **Pass Criteria:** Count matches `Get-Printer`. All software printers (PDF, XPS) present. No errors.
- **Failure Criteria:** Missing printers. Wrong output type. Empty result when printers exist.
- **Evidence:** Console output, transcript, comparison with `Get-Printer`.
- **Severity:** Critical

---

### PDV-002: Get-PrinterStatus Returns Detailed Status
- **Objective:** Verify detailed status for each printer.
- **Prerequisites:** At least 2 printers installed. Module imported.
- **Test Environment:** E1, E3, E5
- **Execution Steps:**
  1. Run: `$status = Get-PrinterStatus`
  2. Run: `$status | Format-List`
  3. Verify fields: Name, PrinterStatus, JobCount, DriverName, PortName, IsDefault, LastError, Timestamp
- **Expected Result:** `Get-PrinterStatus` returns detailed status objects.
- **Pass Criteria:** All fields populated. No errors. PrinterStatus is a meaningful value (not empty).
- **Failure Criteria:** Missing fields. Empty fields. Error.
- **Evidence:** Transcript, status output.
- **Severity:** High

---

### PDV-003: Get-SharedPrinters Returns Only Shared Printers
- **Objective:** Verify `Get-SharedPrinters` filters to shared printers only.
- **Prerequisites:** At least 1 shared printer + 1 non-shared printer. Module imported.
- **Test Environment:** E1, E3, E5, E8
- **Execution Steps:**
  1. Run: `$shared = Get-SharedPrinters`
  2. Run: `$shared | Format-Table Name, Shared, ShareName`
  3. Verify: `$shared | Where-Object { -not $_.Shared }` is empty.
- **Expected Result:** Only printers where `Shared = $true` are returned.
- **Pass Criteria:** No non-shared printers in output. ShareName populated for shared printers.
- **Failure Criteria:** Non-shared printers included. Empty when shared printers exist.
- **Evidence:** Transcript, comparison with `Get-Printer`.
- **Severity:** High

---

### PDV-004: Set-DefaultPrinter
- **Objective:** Verify default printer assignment.
- **Prerequisites:** At least 2 printers. Admin privileges (elevation gated).
- **Test Environment:** E1, E3, E5 (Admin only)
- **Execution Steps:**
  1. Run: `$currentDefault = (Get-Printer | Where-Object Default).Name`
  2. Run: `Set-DefaultPrinter -PrinterName "Microsoft Print to PDF"`
  3. Run: `Get-Printer | Where-Object Default`
  4. Restore original default.
- **Expected Result:** Default printer changes to specified printer. Function returns success.
- **Pass Criteria:** Default changes. No error.
- **Failure Criteria:** Default does not change. Error. Function reports success without change.
- **Evidence:** Before/after screenshots, transcript.
- **Severity:** High

---

## Queue Management (QMG)

---

### QMG-001: Clear-PrintQueue with Confirmation
- **Objective:** Verify queue clearing with confirmation prompt.
- **Prerequisites:** At least 1 printer with pending jobs (send a test document via `Notepad /pt`). Module imported.
- **Test Environment:** E1, E3, E5, E8 (Admin)
- **Execution Steps:**
  1. Send a test print job: `notepad /pt "C:\Windows\System32\license.rtf" "Microsoft Print to PDF"`
  2. Run: `Clear-PrintQueue -PrinterName "Microsoft Print to PDF"` (without `-Force`)
  3. When prompted, enter `y`.
  4. Verify queue is empty: `Get-PrintJob -PrinterName "Microsoft Print to PDF"`.
- **Expected Result:** Prompt appears. After confirmation, queue clears. Jobs removed.
- **Pass Criteria:** Prompt displayed. Queue empty. No error.
- **Failure Criteria:** No prompt. Queue not cleared. Error.
- **Evidence:** Screenshot of prompt, before/after job count.
- **Severity:** High

---

### QMG-002: Clear-PrintQueue with -Force
- **Objective:** Verify `-Force` skips confirmation.
- **Prerequisites:** Same as QMG-001.
- **Test Environment:** E1, E3, E5 (Admin)
- **Execution Steps:**
  1. Send a test print job.
  2. Run: `Clear-PrintQueue -PrinterName "Microsoft Print to PDF" -Force`
  3. Verify queue empty.
- **Expected Result:** No prompt. Queue clears immediately.
- **Pass Criteria:** No prompt. Queue empty.
- **Failure Criteria:** Prompt displayed anyway. Queue not cleared.
- **Evidence:** Transcript.
- **Severity:** High

---

### QMG-003: Clear-PrintQueue Non-Admin
- **Objective:** Verify elevation check blocks queue clear for non-admin.
- **Prerequisites:** Standard User. Module imported.
- **Test Environment:** E2, E4, E6
- **Execution Steps:**
  1. Run as Standard User: `Clear-PrintQueue -PrinterName "Microsoft Print to PDF" -Force`
- **Expected Result:** Function returns error or warning about Administrator privileges. Queue not cleared.
- **Pass Criteria:** Clear error/warning. Queue untouched.
- **Failure Criteria:** Queue clears. No error. Wrong error message.
- **Evidence:** Transcript, error message, queue state.
- **Severity:** High

---

### QMG-004: Clear-PrintQueue Invalid Printer Name
- **Objective:** Verify graceful handling of invalid printer name.
- **Prerequisites:** Module imported. Admin.
- **Test Environment:** E1, E3
- **Execution Steps:**
  1. Run: `Clear-PrintQueue -PrinterName "NonExistentPrinter_XYZ" -Force`
- **Expected Result:** Error message indicating printer not found. No crash.
- **Pass Criteria:** Clear error. No crash. PowerShell session continues.
- **Failure Criteria:** Terminating exception. Crash.
- **Evidence:** Transcript.
- **Severity:** Medium

---

## Spooler Operations (SPL)

---

### SPL-001: Stop-Spooler
- **Objective:** Verify spooler service stops.
- **Prerequisites:** Admin privileges. Module imported.
- **Test Environment:** E1, E3, E5, E8 (Admin)
- **Execution Steps:**
  1. Run: `Stop-Spooler`
  2. Run: `Get-Service Spooler`
- **Expected Result:** Spooler service status is Stopped. Function returns `[PSCustomObject]` with Success = `$true`.
- **Pass Criteria:** Service stopped. Success returned.
- **Failure Criteria:** Service not stopped. Error. No success confirmation.
- **Evidence:** Before/after service status, transcript.
- **Severity:** Critical

---

### SPL-002: Start-Spooler
- **Objective:** Verify spooler service starts.
- **Prerequisites:** Admin privileges. Spooler stopped (from SPL-001 or manually). Module imported.
- **Test Environment:** E1, E3, E5 (Admin)
- **Execution Steps:**
  1. Run: `Start-Spooler`
  2. Run: `Get-Service Spooler`
- **Expected Result:** Spooler service status is Running. Function returns success.
- **Pass Criteria:** Service running. Success returned.
- **Failure Criteria:** Service not running. Error.
- **Evidence:** Service status, transcript.
- **Severity:** Critical

---

### SPL-003: Restart-Spooler
- **Objective:** Verify spooler restart returns status object.
- **Prerequisites:** Admin privileges. Module imported.
- **Test Environment:** E1, E3, E5 (Admin)
- **Execution Steps:**
  1. Run: `$result = Restart-Spooler`
  2. Run: `$result`
  3. Verify properties: Success, Stopped, Started, Timestamp.
- **Expected Result:** `$result.Success` is `$true`. `$result.Stopped` and `$result.Started` are `[datetime]` values. `$result.Timestamp` is set.
- **Pass Criteria:** All properties present and correct.
- **Failure Criteria:** Missing properties. Wrong types. `Success` is `$false`.
- **Evidence:** Transcript, `$result` detailed output.
- **Severity:** Critical

---

### SPL-004: Spooler Operations as Non-Admin
- **Objective:** Verify elevation check blocks spooler operations.
- **Prerequisites:** Standard User. Module imported.
- **Test Environment:** E2, E4, E6
- **Execution Steps:**
  1. Run: `Stop-Spooler`
  2. Run: `Start-Spooler`
  3. Run: `Restart-Spooler`
- **Expected Result:** Each function returns an error or warning about Administrator privileges. Spooler state unchanged.
- **Pass Criteria:** Clear elevation error. Spooler unchanged.
- **Failure Criteria:** Any operation succeeds. No error.
- **Evidence:** Transcript, error messages, service status before/after.
- **Severity:** High

---

## Driver Export (DRV)

---

### DRV-001: Get-PrinterDriverDetails
- **Objective:** Verify driver details for all installed printers.
- **Prerequisites:** At least 1 Type 3 and 1 Type 4 driver installed. Module imported.
- **Test Environment:** E1, E3, E5, E7, E8
- **Execution Steps:**
  1. Run: `$details = Get-PrinterDriverDetails`
  2. Run: `$details | Format-Table Name, DriverType, Manufacturer, Version, IsType4`
- **Expected Result:** Returns driver details for each printer. DriverType is "Type 3" or "Type 4". Version is populated.
- **Pass Criteria:** Both driver types detected. No errors.
- **Failure Criteria:** All drivers show same type. Missing fields. Error.
- **Evidence:** Transcript, driver details output.
- **Severity:** High

---

### DRV-002: Get-DriverUpgradeRecommendations
- **Objective:** Verify upgrade recommendations for Type 3 drivers.
- **Prerequisites:** At least 1 Type 3 driver installed. Module imported.
- **Test Environment:** E1, E3, E5
- **Execution Steps:**
  1. Run: `$recs = Get-DriverUpgradeRecommendations`
  2. Run: `$recs | Format-Table PrinterName, DriverName, CurrentType, RecommendedType`
- **Expected Result:** If Type 3 drivers exist, recommendations suggest Type 4 equivalent. If all Type 4, output is empty or indicates no upgrades needed.
- **Pass Criteria:** No errors. Output format correct. Type 3 drivers have recommendations.
- **Failure Criteria:** Error. Empty output when Type 3 drivers exist.
- **Evidence:** Transcript.
- **Severity:** Medium

---

### DRV-003: Export-PrinterDrivers
- **Objective:** Verify driver export creates CSV, JSON, and INF files.
- **Prerequisites:** At least 1 printer driver. Admin privileges. Module imported.
- **Test Environment:** E1, E3, E5 (Admin)
- **Execution Steps:**
  1. Create an export directory: `$exportDir = "$env:TEMP\DrvExport_$(Get-Date -Format yyyyMMddHHmmss)"`
  2. Run: `Export-PrinterDrivers -ExportPath $exportDir`
  3. Run: `Get-ChildItem $exportDir -Recurse`
- **Expected Result:** Directory contains `driver_export.csv`, `driver_export.json`, and a `Drivers/` subfolder with `.inf` files.
- **Pass Criteria:** All 3 output types present. No errors. INF files are valid.
- **Failure Criteria:** Missing file types. Empty exports. Error.
- **Evidence:** Directory listing, sample CSV/JSON content.
- **Severity:** High

---

### DRV-004: Export-PrinterDrivers Invalid Path
- **Objective:** Verify graceful handling of invalid export path.
- **Prerequisites:** Admin. Module imported.
- **Test Environment:** E1, E3
- **Execution Steps:**
  1. Run: `Export-PrinterDrivers -ExportPath "Z:\InvalidDrive\Export"`
- **Expected Result:** Error message. No crash. Function returns failure result.
- **Pass Criteria:** Clear error. PowerShell continues.
- **Failure Criteria:** Crash. Terminating exception.
- **Evidence:** Transcript.
- **Severity:** Medium

---

## Driver Restore (DRV)

---

### DRV-005: Restore-PrinterDrivers
- **Objective:** Verify driver restore from previously exported archive.
- **Prerequisites:** A valid export directory from DRV-003. Admin privileges. Module imported.
- **Test Environment:** E1, E3, E5 (Admin)
- **Execution Steps:**
  1. Use the export directory from DRV-003.
  2. Run: `Restore-PrinterDrivers -SourcePath $exportDir`
  3. Verify drivers are registered: `Get-PrinterDriver | Where-Object Name -match "Restored"`
- **Expected Result:** Drivers from export are restored. Function returns success.
- **Pass Criteria:** Drivers appear in `Get-PrinterDriver`. No errors.
- **Failure Criteria:** No drivers restored. Error. Wrong drivers.
- **Evidence:** Before/after driver list, transcript.
- **Severity:** High

---

### DRV-006: Restore-PrinterDrivers Invalid Path
- **Objective:** Verify path validation on restore.
- **Prerequisites:** Admin. Module imported.
- **Test Environment:** E1, E3
- **Execution Steps:**
  1. Run: `Restore-PrinterDrivers -SourcePath "C:\NonExistent\Path"`
  2. Run: `Restore-PrinterDrivers -SourcePath "C:\Windows\System32\calc.exe"` (not a directory)
- **Expected Result:** Both return errors about invalid path. No changes to drivers.
- **Pass Criteria:** Clear error messages. No crash.
- **Failure Criteria:** Function proceeds with invalid path. Crash.
- **Evidence:** Transcript.
- **Severity:** Medium

---

### DRV-007: Install-PrinterDriverFromInf
- **Objective:** Verify driver installation from INF file.
- **Prerequisites:** A valid `.inf` file (from export or Windows driver store). Admin privileges. Module imported.
- **Test Environment:** E1, E3, E5 (Admin)
- **Execution Steps:**
  1. Locate an INF: `$infPath = (Get-ChildItem "$env:SystemRoot\System32\DriverStore\FileRepository\*.inf" | Select-Object -First 1).FullName`
  2. Run: `Install-PrinterDriverFromInf -InfPath $infPath`
- **Expected Result:** Driver installed. Function returns success.
- **Pass Criteria:** Driver registered. No error.
- **Failure Criteria:** Driver not installed. Error.
- **Evidence:** Before/after driver list, transcript.
- **Severity:** High

---

### DRV-008: Remove-PrinterDriverByName
- **Objective:** Verify driver removal by name.
- **Prerequisites:** A removable driver (preferably a test driver). Admin. Module imported.
- **Test Environment:** E1, E3, E5 (Admin)
- **Execution Steps:**
  1. Identify a removable driver (one not in use by any printer).
  2. Run: `Remove-PrinterDriverByName -DriverName "<driver name>"`
  3. Verify removal: `Get-PrinterDriver -Name "<driver name>"`
- **Expected Result:** Driver removed. Function returns success.
- **Pass Criteria:** Driver no longer listed. No error.
- **Failure Criteria:** Driver still present. Error. Driver in use but silently removed.
- **Evidence:** Before/after driver list, transcript.
- **Severity:** High

---

## Printer Sharing (SHR)

---

### SHR-001: Get-PrinterShareStatus
- **Objective:** Verify share status for all printers.
- **Prerequisites:** At least 1 shared and 1 non-shared printer. Module imported.
- **Test Environment:** E1, E3, E5, E8
- **Execution Steps:**
  1. Run: `$shares = Get-PrinterShareStatus`
  2. Run: `$shares | Format-Table Name, Shared, ShareName, Transport`
- **Expected Result:** Each printer shows share status. Shared printers have ShareName populated.
- **Pass Criteria:** No errors. Shared vs non-shared correctly identified.
- **Failure Criteria:** Wrong share status. Missing fields.
- **Evidence:** Transcript.
- **Severity:** High

---

### SHR-002: Enable-PrinterSharing
- **Objective:** Verify sharing can be enabled on a printer.
- **Prerequisites:** A non-shared printer. Admin. Module imported.
- **Test Environment:** E1, E3, E5 (Admin)
- **Execution Steps:**
  1. Run: `Enable-PrinterSharing -PrinterName "Microsoft Print to PDF" -ShareName "PDFTestShare"`
  2. Verify: `Get-Printer -Name "Microsoft Print to PDF" | Select-Object Shared, ShareName`
  3. Clean up: `Disable-PrinterSharing -PrinterName "Microsoft Print to PDF"`
- **Expected Result:** Printer sharing enabled. ShareName set.
- **Pass Criteria:** Shared = true. ShareName matches. No error.
- **Failure Criteria:** Sharing not enabled. Error.
- **Evidence:** Before/after printer properties, transcript.
- **Severity:** High

---

### SHR-003: Get-SmbSharePermissions
- **Objective:** Verify SMB share permission enumeration.
- **Prerequisites:** At least 1 shared printer. Module imported.
- **Test Environment:** E1, E3, E5, E8
- **Execution Steps:**
  1. Run: `$perms = Get-SmbSharePermissions`
  2. Run: `$perms | Format-Table ShareName, AccountName, AccessRight`
- **Expected Result:** Lists SMB share permissions for print shares.
- **Pass Criteria:** Permissions returned. Format correct.
- **Failure Criteria:** Empty when shares exist. Error.
- **Evidence:** Transcript.
- **Severity:** Medium

---

### SHR-004: Get-PrinterSharingCompatibility
- **Objective:** Verify sharing compatibility analysis.
- **Prerequisites:** At least 2 printers with different driver types. Module imported.
- **Test Environment:** E1, E3, E5
- **Execution Steps:**
  1. Run: `$compat = Get-PrinterSharingCompatibility`
  2. Run: `$compat | Format-Table Name, DriverType, Compatibility, Warning`
- **Expected Result:** Each printer gets a compatibility assessment.
- **Pass Criteria:** No errors. Compatibility field populated.
- **Failure Criteria:** Error. Empty results.
- **Evidence:** Transcript.
- **Severity:** Medium

---

## IPP Configuration (IPP)

---

### IPP-001: Get-IPPStatus
- **Objective:** Verify IPP status detection for each printer.
- **Prerequisites:** At least 1 IPP-enabled printer (or software printer with IPP). Module imported.
- **Test Environment:** E1, E3, E5, E7
- **Execution Steps:**
  1. Run: `$ipp = Get-IPPStatus`
  2. Run: `$ipp | Format-Table Name, IPPEnabled, IPPUrl`
- **Expected Result:** Shows IPP capability per printer. IPPUrl populated for IPP printers.
- **Pass Criteria:** No errors. Output format correct.
- **Failure Criteria:** Error. All printers show IPP disabled when some support it.
- **Evidence:** Transcript.
- **Severity:** High

---

### IPP-002: Get-IPPUrls
- **Objective:** Verify IPP URL generation.
- **Prerequisites:** At least 1 printer. Module imported.
- **Test Environment:** E1, E3, E5
- **Execution Steps:**
  1. Run: `$urls = Get-IPPUrls`
  2. Run: `$urls | Format-Table Name, IPPUrl`
- **Expected Result:** IPP URLs generated in format `ipp://<hostname>:631/printers/<printername>`.
- **Pass Criteria:** URL format valid. No errors.
- **Failure Criteria:** Wrong URL format. Error.
- **Evidence:** Transcript.
- **Severity:** Medium

---

### IPP-003: Test-IPPEndpoint
- **Objective:** Verify IPP endpoint connectivity test.
- **Prerequisites:** At least 1 printer reachable via IPP. Module imported.
- **Test Environment:** E1, E3, E5, E8
- **Execution Steps:**
  1. Run: `Test-IPPEndpoint` (interactive or with parameters)
  2. Try with a valid IPP printer name.
  3. Try with a non-existent printer name.
- **Expected Result:** Valid printer returns connectivity success. Invalid returns failure.
- **Pass Criteria:** Correct result for each case. No crash.
- **Failure Criteria:** Both return same result. Error.
- **Evidence:** Transcript.
- **Severity:** Medium

---

### IPP-004: Install-IPPServer
- **Objective:** Verify IPP server role installation (if not already installed).
- **Prerequisites:** Admin privileges. Module imported. Server may already be installed.
- **Test Environment:** E1, E3, E5 (Admin)
- **Execution Steps:**
  1. Check current state: `Get-WindowsFeature -Name Print-Internet` (Server) or `dism /online /get-featureinfo /featurename:Printing-InternetPrinting-Client` (Client)
  2. If not installed, run: `Install-IPPServer`
  3. Verify installation.
- **Expected Result:** Function installs IPP feature or reports it's already present.
- **Pass Criteria:** No errors. Feature installed or correctly reported.
- **Failure Criteria:** Installation fails. Error without guidance.
- **Evidence:** Before/after feature state, transcript.
- **Severity:** High

---

## Android Wizard (AND)

---

### AND-001: Get-AndroidCompatibility
- **Objective:** Verify Android compatibility analysis.
- **Prerequisites:** At least 1 shared printer. Module imported.
- **Test Environment:** E1, E3, E5, E8
- **Execution Steps:**
  1. Run: `$compat = Get-AndroidCompatibility`
  2. Run: `$compat | Format-List`
- **Expected Result:** Returns compatibility assessment including firewall status, network profile, printer sharing, connection strings.
- **Pass Criteria:** All fields populated. No errors.
- **Failure Criteria:** Error. Missing fields.
- **Evidence:** Transcript.
- **Severity:** Medium

---

### AND-002: Show-AndroidWizard
- **Objective:** Verify Android wizard displays setup instructions.
- **Prerequisites:** Module imported.
- **Test Environment:** E1, E3, E5
- **Execution Steps:**
  1. Run: `Show-AndroidWizard`
  2. Observe displayed instructions.
- **Expected Result:** Wizard displays Mopria/Android setup steps.
- **Pass Criteria:** Text displayed. No errors.
- **Failure Criteria:** No output. Error.
- **Evidence:** Screenshot.
- **Severity:** Medium

---

### AND-003: Get-AndroidSetupContent
- **Objective:** Verify setup content export.
- **Prerequisites:** Module imported.
- **Test Environment:** E1, E3, E5
- **Execution Steps:**
  1. Run: `$content = Get-AndroidSetupContent`
  2. Run: `$content | Format-List`
- **Expected Result:** Returns setup instructions as structured content.
- **Pass Criteria:** Content returned. No errors.
- **Failure Criteria:** Error. Empty output.
- **Evidence:** Transcript.
- **Severity:** Low

---

### AND-004: Android Wizard Printer Selection
- **Objective:** Verify wizard correctly identifies IPP-capable printers for Android.
- **Prerequisites:** At least 1 shared, IPP-capable printer. Module imported.
- **Test Environment:** E1, E3, E5
- **Execution Steps:**
  1. Run IPP check: `$ippUrls = Get-IPPUrls`
  2. Run Android check: `$android = Get-AndroidCompatibility`
  3. Verify that printers with IPP URLs appear in Android compatibility output.
- **Expected Result:** IPP-capable printers listed with connection strings for Android.
- **Pass Criteria:** Consistent data between IPP and Android functions.
- **Failure Criteria:** Mismatch between IPP and Android output.
- **Evidence:** Transcript, comparison.
- **Severity:** Medium

---

## Diagnostics Bundle (DBG)

---

### DBG-001: New-DiagnosticBundle Creates ZIP
- **Objective:** Verify diagnostic bundle produces a valid ZIP.
- **Prerequisites:** Module imported. Admin (preferred, not required).
- **Test Environment:** E1, E3, E5, E8
- **Execution Steps:**
  1. Run: `$bundle = New-DiagnosticBundle`
  2. Run: `$bundle | Format-List`
  3. Verify the ZIP file exists: `Test-Path $bundle.Path`
  4. Verify ZIP is valid: `Get-Item $bundle.Path | Select-Object Length`
- **Expected Result:** ZIP created. Function returns path and size. File non-empty.
- **Pass Criteria:** ZIP exists. Size > 0 KB. No errors.
- **Failure Criteria:** ZIP not created. Empty ZIP. Error.
- **Evidence:** File listing, function output, ZIP size.
- **Severity:** High

---

### DBG-002: Diagnostic Bundle Contains 12 Sections
- **Objective:** Verify all expected diagnostic sections are present.
- **Prerequisites:** ZIP from DBG-001.
- **Test Environment:** E1, E3
- **Execution Steps:**
  1. Extract the ZIP: `Expand-Archive $bundle.Path -DestinationPath "$env:TEMP\DiagBundle" -Force`
  2. List contents: `Get-ChildItem "$env:TEMP\DiagBundle" -Recurse`
  3. Verify key files present: system_info.json, printers.csv, drivers.csv, ports.csv, registry.reg, firewall_rules.csv, services.csv, network_config.txt, smb_config.txt, event_logs.csv, bundle_manifest.json.
- **Expected Result:** All 12 sections present. Files non-empty.
- **Pass Criteria:** All key files present and non-empty.
- **Failure Criteria:** Missing sections. Empty files.
- **Evidence:** Directory listing, sample file content.
- **Severity:** High

---

### DBG-003: Diagnostic Bundle Non-Admin
- **Objective:** Verify bundle creation works without admin (read-only sections may be partial).
- **Prerequisites:** Standard User. Module imported.
- **Test Environment:** E2, E4, E6
- **Execution Steps:**
  1. Run: `$bundle = New-DiagnosticBundle`
  2. Extract and inspect.
- **Expected Result:** ZIP created. Some sections (registry, services) may be empty or partial. No crash.
- **Pass Criteria:** ZIP created. No terminating error.
- **Failure Criteria:** Complete failure. Crash.
- **Evidence:** Transcript, bundle contents.
- **Severity:** Medium

---

### DBG-004: Diagnostic Bundle with Invalid Output Path
- **Objective:** Verify error handling on invalid output path.
- **Prerequisites:** Module imported.
- **Test Environment:** E1, E3
- **Execution Steps:**
  1. Run: `New-DiagnosticBundle -OutputPath "Z:\InvalidDir\bundle.zip"`
- **Expected Result:** Error message. No crash.
- **Pass Criteria:** Graceful error.
- **Failure Criteria:** Crash.
- **Evidence:** Transcript.
- **Severity:** Low

---

## Reporting (RPT)

---

### RPT-001: New-PrinterReport HTML
- **Objective:** Verify HTML report generation.
- **Prerequisites:** At least 2 printers. Module imported.
- **Test Environment:** E1, E3, E5, E8
- **Execution Steps:**
  1. Run: `New-PrinterReport -Format HTML | Out-File "$env:TEMP\report.html"`
  2. Open the HTML file in a browser.
- **Expected Result:** HTML file created with printer inventory, status, and styling.
- **Pass Criteria:** File non-empty. Browser renders correctly. Printer data visible.
- **Failure Criteria:** File empty. No data. CSS missing.
- **Evidence:** HTML file, browser screenshot.
- **Severity:** High

---

### RPT-002: New-PrinterReport JSON
- **Objective:** Verify JSON report generation.
- **Prerequisites:** Same as RPT-001.
- **Test Environment:** E1, E3, E5
- **Execution Steps:**
  1. Run: `$report = New-PrinterReport -Format JSON`
  2. Run: `$report | ConvertTo-Json | Out-File "$env:TEMP\report.json"`
  3. Parse with: `Get-Content "$env:TEMP\report.json" | ConvertFrom-Json`
- **Expected Result:** Valid JSON. Parseable. Contains printer data.
- **Pass Criteria:** Valid JSON. Data present.
- **Failure Criteria:** Invalid JSON. Empty.
- **Evidence:** JSON file, parsed output.
- **Severity:** Medium

---

### RPT-003: Get-PrintComplianceReport
- **Objective:** Verify compliance report generation.
- **Prerequisites:** At least 2 printers with different driver types. Module imported.
- **Test Environment:** E1, E3, E5
- **Execution Steps:**
  1. Run: `$compliance = Get-PrintComplianceReport`
  2. Run: `$compliance | Format-Table PrinterName, DriverType, Compliant, Issues`
- **Expected Result:** Each printer gets a compliance assessment.
- **Pass Criteria:** No errors. Output format correct.
- **Failure Criteria:** Error. Empty output.
- **Evidence:** Transcript.
- **Severity:** Medium

---

### RPT-004: New-PrinterReport All Formats
- **Objective:** Verify `-Format All` generates all 3 formats.
- **Prerequisites:** Same as RPT-001.
- **Test Environment:** E1, E3
- **Execution Steps:**
  1. Run: `New-PrinterReport -Format All | Out-File "$env:TEMP\report_all.txt"`
  2. Check that HTML, JSON, and CSV output are all present in the output.
- **Expected Result:** Output contains all 3 formats.
- **Pass Criteria:** Data for all formats present.
- **Failure Criteria:** Only one format in output.
- **Evidence:** Transcript, output file.
- **Severity:** Medium

---

## Repair Rollback (REP)

---

### REP-001: Initialize-RepairBackup
- **Objective:** Verify repair backup creates registry and service snapshots.
- **Prerequisites:** Admin privileges. Module imported.
- **Test Environment:** E1, E3, E5 (Admin)
- **Execution Steps:**
  1. Run: `$backup = Initialize-RepairBackup`
  2. Run: `$backup | Format-List`
  3. Verify backup path exists: `Test-Path $backup.BackupPath`
  4. List backup contents.
- **Expected Result:** Backup created with registry export, service state file, and print configuration.
- **Pass Criteria:** Backup directory exists. Files non-empty.
- **Failure Criteria:** No backup created. Error.
- **Evidence:** Transcript, directory listing.
- **Severity:** High

---

### REP-002: Invoke-AutomaticShareRepair
- **Objective:** Verify 8-step automatic repair workflow executes.
- **Prerequisites:** Admin privileges. A misconfigured share (or run on any system to verify completion). Module imported.
- **Test Environment:** E1, E3, E5 (Admin)
- **Execution Steps:**
  1. Run: `$repair = Invoke-AutomaticShareRepair`
  2. Observe each step.
  3. Run: `$repair | Format-List`
- **Expected Result:** 8 steps execute. Each step shows status. Final result shows success or details of what was fixed.
- **Pass Criteria:** All 8 steps reported. No terminating errors.
- **Failure Criteria:** Workflow stops mid-way. Error. Steps skipped.
- **Evidence:** Transcript.
- **Severity:** Critical

---

### REP-003: Repair Rollback Restores State
- **Objective:** Verify that rollback restores registry and services.
- **Prerequisites:** Backup from REP-001. Admin. Module imported.
- **Test Environment:** E1, E3 (Admin)
- **Execution Steps:**
  1. Introduce a controlled change: stop the Spooler service.
  2. Run repair: `Invoke-AutomaticShareRepair`
  3. Run rollback by restoring from backup: simulate by manually importing the registry backup.
  4. Verify spooler service state and registry keys match backup.
- **Expected Result:** Rollback restores service state and registry keys to pre-repair state.
- **Pass Criteria:** Service state restored. Registry keys match backup.
- **Failure Criteria:** State not restored. Errors during rollback.
- **Evidence:** Before/after comparison, transcript.
- **Severity:** High

---

### REP-004: Repair Non-Admin
- **Objective:** Verify elevation check blocks repair.
- **Prerequisites:** Standard User. Module imported.
- **Test Environment:** E2, E4, E6
- **Execution Steps:**
  1. Run: `Initialize-RepairBackup`
  2. Run: `Invoke-AutomaticShareRepair`
- **Expected Result:** Both return elevation errors.
- **Pass Criteria:** Clear error. No changes made.
- **Failure Criteria:** Workflow proceeds. Changes made.
- **Evidence:** Transcript.
- **Severity:** High

---

## Logging (LOG)

---

### LOG-001: Initialize-Logging
- **Objective:** Verify logging initialization.
- **Prerequisites:** Module imported.
- **Test Environment:** E1–E10
- **Execution Steps:**
  1. Run: `Initialize-Logging`
  2. Run: `Get-LogFilePath`
- **Expected Result:** Log file created. Path returned.
- **Pass Criteria:** Path exists. File created.
- **Failure Criteria:** No file. Error.
- **Evidence:** Transcript, file existence.
- **Severity:** Medium

---

### LOG-002: Write-Log and Get-LogContent
- **Objective:** Verify log writing and reading.
- **Prerequisites:** Logging initialized.
- **Test Environment:** E1–E10
- **Execution Steps:**
  1. Run: `Write-Log -Message "Test log entry v5.1" -Level INFO`
  2. Run: `$content = Get-LogContent`
  3. Verify message appears: `$content | Where-Object { $_ -match "Test log entry v5.1" }`
- **Expected Result:** Written message appears in log content.
- **Pass Criteria:** Message found. No errors.
- **Failure Criteria:** Message not in log. Error.
- **Evidence:** Transcript, log content.
- **Severity:** Medium

---

### LOG-003: Export-LogArchive
- **Objective:** Verify log archive export.
- **Prerequisites:** Logging initialized with some entries.
- **Test Environment:** E1, E3, E5
- **Execution Steps:**
  1. Run: `Export-LogArchive -DestinationPath "$env:TEMP\LogArchive"
  2. Verify archive file exists.
- **Expected Result:** Log archive exported.
- **Pass Criteria:** File created. Non-empty.
- **Failure Criteria:** No file. Error.
- **Evidence:** File listing.
- **Severity:** Low

---

### LOG-004: Log Level Filtering
- **Objective:** Verify `Get-LogContent` level filtering.
- **Prerequisites:** Logging initialized with entries at different levels (INFO, WARN, ERROR).
- **Test Environment:** E1, E3
- **Execution Steps:**
  1. Write entries at each level: `Write-Log -Message "Info test" -Level INFO`, `Write-Log -Message "Warn test" -Level WARN`, `Write-Log -Message "Error test" -Level ERROR`
  2. Run: `$warns = Get-LogContent -Level WARN`
  3. Verify only WARN entries returned.
- **Expected Result:** Only entries matching the requested level are returned.
- **Pass Criteria:** Correct filtering. No errors.
- **Failure Criteria:** Wrong levels returned. Error.
- **Evidence:** Transcript.
- **Severity:** Low

---

## Packaging (PKG)

---

### PKG-001: CI/build.ps1 Runs Without Errors
- **Objective:** Verify build script executes.
- **Prerequisites:** Repo root accessible. Pester installed. Admin (suggested).
- **Test Environment:** E1, E3, E5
- **Execution Steps:**
  1. Open PowerShell in repo root.
  2. Run: `.\CI\build.ps1 -SkipTests`
  3. Observe output.
- **Expected Result:** Build script completes. All validation steps pass. Exit code 0.
- **Pass Criteria:** Exit code 0. All steps "OK".
- **Failure Criteria:** Any step "FAIL". Exit code 1.
- **Evidence:** Transcript, exit code.
- **Severity:** High

---

### PKG-002: CI/build.ps1 with Tests
- **Objective:** Verify build + test execution.
- **Prerequisites:** Pester installed. All 49 tests pass.
- **Test Environment:** E1, E3, E5
- **Execution Steps:**
  1. Run: `.\CI\build.ps1`
  2. Observe test execution.
- **Expected Result:** Tests run. All pass. Build succeeds.
- **Pass Criteria:** All tests pass. Build OK.
- **Failure Criteria:** Any test fails. Build fails.
- **Evidence:** Transcript, test results.
- **Severity:** Critical

---

### PKG-003: CI/package.ps1 Creates Release ZIP
- **Objective:** Verify packaging produces release artifact.
- **Prerequisites:** A build artifact directory (from PKG-001 or manual). Module root accessible.
- **Test Environment:** E1, E3
- **Execution Steps:**
  1. Create a mock artifact directory: `$artifacts = "$env:TEMP\PtkBuild_$(Get-Date -Format yyyyMMddHHmmss)"; New-Item -ItemType Directory $artifacts`
  2. Copy module files: `Copy-Item .\PrinterToolkit.psd1, .\PrinterToolkit.psm1, .\launcher.ps1, .\install.ps1, .\LICENSE $artifacts`
  3. Copy Modules: `Copy-Item .\Modules $artifacts\Modules -Recurse`
  4. Run: `.\CI\package.ps1 -ArtifactPath $artifacts`
  5. Verify ZIP and release notes created.
- **Expected Result:** ZIP file and RELEASE_NOTES.md created in `releases/` directory.
- **Pass Criteria:** Both files exist. ZIP non-empty.
- **Failure Criteria:** Files missing. Error.
- **Evidence:** File listing, ZIP size.
- **Severity:** High

---

### PKG-004: Release ZIP Contains All Required Files
- **Objective:** Verify release ZIP structure.
- **Prerequisites:** ZIP from PKG-003.
- **Test Environment:** E1, E3
- **Execution Steps:**
  1. Extract ZIP: `Expand-Archive .\releases\PrinterToolkit_v5.0.1.zip -DestinationPath "$env:TEMP\PtkRelease" -Force`
  2. List contents: `Get-ChildItem "$env:TEMP\PtkRelease" -Recurse`
  3. Verify presence: PrinterToolkit.psd1, PrinterToolkit.psm1, launcher.ps1, install.ps1, LICENSE, Modules\ (11 subdirectories).
- **Expected Result:** Complete module structure preserved.
- **Pass Criteria:** All key files and 11 module directories present.
- **Failure Criteria:** Missing files or directories.
- **Evidence:** Directory listing.
- **Severity:** High

---

## Failure Injection Tests (FIJ)

---

### FIJ-001: Stopped Spooler
- **Objective:** Verify graceful handling when spooler is stopped.
- **Prerequisites:** Admin privileges. Module imported. VM snapshot taken.
- **Test Environment:** E1, E3 (Admin, VM)
- **Execution Steps:**
  1. Stop spooler: `Stop-Service Spooler`
  2. Run: `Get-Printers`
  3. Run: `Get-PrinterStatus`
  4. Run: `Restart-Spooler`
  5. Verify spooler restarts.
- **Expected Result:** `Get-Printers` may return partial/empty results. `Get-PrinterStatus` reports spooler error. `Restart-Spooler` starts spooler.
- **Pass Criteria:** No crash. Error messages are descriptive. Spooler restart succeeds.
- **Failure Criteria:** Crash. Terminating error. Restart fails.
- **Evidence:** Transcript, service state before/after.
- **Severity:** Critical

---

### FIJ-002: Missing Driver
- **Objective:** Verify graceful handling when a printer's driver is missing.
- **Prerequisites:** Admin. VM snapshot. Module imported.
- **Test Environment:** E1, E3 (Admin, VM)
- **Execution Steps:**
  1. Uninstall a printer driver (not in use by any printer): `Remove-PrinterDriver -Name "<driver>"`
  2. Run: `Get-PrinterDriverDetails`
  3. Check that driver reports gracefully.
- **Expected Result:** Missing driver reported in output without crash.
- **Pass Criteria:** No crash. Descriptive message.
- **Failure Criteria:** Crash. Unhandled exception.
- **Evidence:** Transcript, driver list before/after.
- **Severity:** High

---

### FIJ-003: Corrupted Queue
- **Objective:** Verify handling of corrupted print queue.
- **Prerequisites:** Admin. VM snapshot. Module imported.
- **Test Environment:** E1, E3 (Admin, VM)
- **Execution Steps:**
  1. Manually corrupt the spool directory: stop spooler, delete `C:\Windows\System32\spool\PRINTERS\*`, or add a malformed `.SHD` file.
  2. Start spooler.
  3. Run: `Clear-PrintQueue -PrinterName "Microsoft Print to PDF" -Force`
  4. Run: `Get-PrinterQueueHealth`
- **Expected Result:** Functions handle corrupted queue gracefully. Repair or clear resolves.
- **Pass Criteria:** No crash. Error messages descriptive.
- **Failure Criteria:** Crash. Unhandled exception.
- **Evidence:** Transcript, spool directory state.
- **Severity:** High

---

### FIJ-004: Printer Disconnected
- **Objective:** Verify handling when a physical printer is disconnected.
- **Prerequisites:** A USB printer. Module imported.
- **Test Environment:** E1, E3 (Physical, Admin)
- **Execution Steps:**
  1. Verify printer is connected and working.
  2. Physically disconnect the USB cable.
  3. Run: `Get-Printers`
  4. Run: `Get-PrinterStatus`
  5. Run: `Test-IPPEndpoint` for that printer.
- **Expected Result:** Printer appears in inventory with offline/error status. No crash.
- **Pass Criteria:** Printer listed. Status reflects disconnected state.
- **Failure Criteria:** Crash. Printer disappears from inventory.
- **Evidence:** Before/after screenshots, transcript.
- **Severity:** High

---

### FIJ-005: Firewall Disabled
- **Objective:** Verify behavior when Windows Firewall is disabled.
- **Prerequisites:** Admin. VM snapshot. Module imported.
- **Test Environment:** E1, E3 (Admin, VM)
- **Execution Steps:**
  1. Disable all firewall profiles: `Set-NetFirewallProfile -All -Enabled $false`
  2. Run: `Get-NetworkValidation`
  3. Run: `Export-FirewallSnapshot`
  4. Enable firewall: `Set-NetFirewallProfile -All -Enabled $true`
- **Expected Result:** Network validation reports firewall disabled. Firewall snapshot shows no rules or disabled state. No crash.
- **Pass Criteria:** Clear reporting. No crash.
- **Failure Criteria:** Crash. No indication of disabled firewall.
- **Evidence:** Transcript, validation results.
- **Severity:** Medium

---

### FIJ-006: Firewall Blocking IPP
- **Objective:** Verify IPP port blocking detection.
- **Prerequisites:** Admin. Module imported.
- **Test Environment:** E1, E3 (Admin)
- **Execution Steps:**
  1. Block port 631: `New-NetFirewallRule -DisplayName "Block IPP" -Direction Inbound -LocalPort 631 -Protocol TCP -Action Block`
  2. Run: `Get-IPPStatus`
  3. Run: `Test-IPPEndpoint`
  4. Remove the blocking rule.
- **Expected Result:** IPP functions detect or handle the blocked port gracefully.
- **Pass Criteria:** No crash. Port blocking is detectable.
- **Failure Criteria:** Crash. No indication of port blocking.
- **Evidence:** Transcript, rule creation/removal.
- **Severity:** Medium

---

### FIJ-007: Network Disconnected
- **Objective:** Verify behavior when network is disconnected.
- **Prerequisites:** Admin or ability to disconnect network. Module imported.
- **Test Environment:** E1, E3 (Physical or VM)
- **Execution Steps:**
  1. Disconnect network (unplug cable or disable adapter).
  2. Run: `Get-Printers`
  3. Run: `Get-NetworkValidation`
  4. Run: `New-DiagnosticBundle`
  5. Reconnect network.
- **Expected Result:** Functions handle network absence gracefully. Local printers still listed. Network-dependent checks report failures. Bundle still created (with local data only).
- **Pass Criteria:** No crash. Local operations work. Network failures are clearly reported.
- **Failure Criteria:** Crash. All operations fail.
- **Evidence:** Transcript, validation results.
- **Severity:** High

---

### FIJ-008: Permission Denied
- **Objective:** Verify behavior when registry/filesystem access is denied.
- **Prerequisites:** Standard User or deny ACE on registry key. Module imported.
- **Test Environment:** E2, E4, E6 (Standard User or modified ACL)
- **Execution Steps:**
  1. Run: `Export-RegistrySnapshot`
  2. Run: `Export-ServiceSnapshot`
  3. Run: `New-DiagnosticBundle`
- **Expected Result:** Permission-denied sections report errors but do not crash. Bundle created with available sections.
- **Pass Criteria:** No crash. Partial results.
- **Failure Criteria:** Crash. No error reporting.
- **Evidence:** Transcript.
- **Severity:** High

---

### FIJ-009: Registry Rollback Verification
- **Objective:** Verify registry rollback restores keys after repair.
- **Prerequisites:** Admin. VM snapshot. Module imported.
- **Test Environment:** E1, E3 (Admin, VM)
- **Execution Steps:**
  1. Export current print registry keys: `reg export "HKLM\SYSTEM\CurrentControlSet\Control\Print" "$env:TEMP\print_before.reg"`
  2. Run: `Invoke-AutomaticShareRepair`
  3. Modify a print registry key: `reg add "HKLM\SYSTEM\CurrentControlSet\Control\Print" /v TestKey /t REG_DWORD /d 1 /f`
  4. Run repair again.
  5. Export post-repair registry: `reg export "HKLM\SYSTEM\CurrentControlSet\Control\Print" "$env:TEMP\print_after.reg"`
  6. Compare before/after REG files.
- **Expected Result:** Registry state is preserved or restored by repair workflow.
- **Pass Criteria:** Critical print keys match before/after.
- **Failure Criteria:** Registry corrupted. Keys missing after repair.
- **Evidence:** Before/after REG files, comparison diff.
- **Severity:** High

---

### FIJ-010: Missing Windows Feature
- **Objective:** Verify handling when required Windows feature is missing.
- **Prerequisites:** Admin. VM snapshot. Module imported.
- **Test Environment:** E1, E3 (Admin, VM)
- **Execution Steps:**
  1. Disable Internet Printing Client: `dism /online /disable-feature /featurename:Printing-InternetPrinting-Client /quiet /norestart`
  2. Run: `Test-IPPClientInstalled`
  3. Run: `Install-IPPServer`
  4. Re-enable: `dism /online /enable-feature /featurename:Printing-InternetPrinting-Client /quiet`
- **Expected Result:** Functions detect missing feature and report clearly. Install attempt fails or reports feature missing.
- **Pass Criteria:** No crash. Clear error message.
- **Failure Criteria:** Crash. Silent failure.
- **Evidence:** Transcript.
- **Severity:** Medium

---

### FIJ-011: IPP Unavailable
- **Objective:** Verify behavior when IPP endpoint is unreachable.
- **Prerequisites:** A printer that was previously IPP-reachable, now unreachable (or simulate by blocking port 631). Module imported.
- **Test Environment:** E1, E3 (Admin)
- **Execution Steps:**
  1. If a real IPP printer exists, disconnect it from network. Otherwise, block port 631 (see FIJ-006).
  2. Run: `Get-IPPStatus`
  3. Run: `Test-IPPEndpoint`
- **Expected Result:** Functions report IPP endpoint as unreachable. No crash.
- **Pass Criteria:** Clear failure message.
- **Failure Criteria:** Crash. Hangs indefinitely.
- **Evidence:** Transcript.
- **Severity:** Medium

---

### FIJ-012: Unexpected Exception During Menu
- **Objective:** Verify menu handles an exception thrown by a function gracefully.
- **Prerequisites:** Module imported. Admin.
- **Test Environment:** E1, E3
- **Execution Steps:**
  1. Temporarily rename a module file (e.g., `Modules\Core\PrinterToolkit.Core.psm1` to `.bak`) while the menu is already running (in another session).
  2. In the first session, open the menu and select option 1 (Printer Inventory).
  3. Restore the file.
- **Expected Result:** Menu catches error, displays "Invalid option." or error, and returns to main menu. Does not crash.
- **Pass Criteria:** Menu continues. No crash.
- **Failure Criteria:** Menu crashes. PowerShell exits.
- **Evidence:** Transcript, console screenshot.
- **Severity:** High

---

## Android Validation (ANV)

---

### ANV-001: Mopria Print Service Discovery
- **Objective:** Verify Android device discovers the Windows printer via Mopria.
- **Prerequisites:** Android device with Mopria Print Service installed. Windows machine with shared IPP printer. Both on same network.
- **Test Environment:** E1, E3, E5 (Windows) + Android device
- **Execution Steps:**
  1. On Windows, ensure a printer is shared and IPP is enabled.
  2. On Android, open Mopria Print Service.
  3. Tap "Search for printers".
  4. Record discovered printers.
- **Expected Result:** Windows printer appears in Mopria discovery list.
- **Pass Criteria:** Printer discovered within 30 seconds.
- **Failure Criteria:** No printers discovered. Discovery times out.
- **Evidence:** Android screenshot, Windows printer config.
- **Severity:** High

---

### ANV-002: Mopria Print Success
- **Objective:** Verify successful print from Android via Mopria.
- **Prerequisites:** ANV-001 passed. Android device on same network. A test document (PDF or photo) on Android.
- **Test Environment:** E1, E3, E5 + Android
- **Execution Steps:**
  1. Open a document on Android.
  2. Select "Print" from the share menu.
  3. Choose the discovered printer.
  4. Configure settings (color, copies, orientation).
  5. Tap Print.
- **Expected Result:** Document prints successfully on the target printer.
- **Pass Criteria:** Print job completes. Document appears at printer.
- **Failure Criteria:** Print fails. Job stuck in queue. Wrong output.
- **Evidence:** Android "Print successful" message, Windows print queue status, printed document photo.
- **Severity:** Critical

---

### ANV-003: Samsung Print Service Plugin
- **Objective:** Verify printing from Samsung Print Service Plugin.
- **Prerequisites:** Samsung device (or any Android with Samsung Print Service Plugin). Printer shared. Module imported.
- **Test Environment:** E1, E3, E5 + Samsung/Android device
- **Execution Steps:**
  1. Install Samsung Print Service Plugin from Google Play.
  2. Open a document.
  3. Select Print → Samsung Print Service Plugin.
  4. Discover printer.
  5. Send a test print.
- **Expected Result:** Printer discovered. Print succeeds.
- **Pass Criteria:** Discovery and print success.
- **Failure Criteria:** Discovery fails. Print fails.
- **Evidence:** Android screenshots, print queue status.
- **Severity:** High

---

### ANV-004: HP Smart App
- **Objective:** Verify printing via HP Smart.
- **Prerequisites:** Android device with HP Smart app. Printer shared.
- **Test Environment:** E1, E3, E5 + Android
- **Execution Steps:**
  1. Open HP Smart.
  2. Tap + to add printer.
  3. Select "Network Printer" or "IP Printer".
  4. Enter the Windows machine's IP and printer name.
  5. Print a test page.
- **Expected Result:** Printer added. Test page prints.
- **Pass Criteria:** Add succeeds. Print succeeds.
- **Failure Criteria:** Add fails. Print fails.
- **Evidence:** Android screenshots, print queue.
- **Severity:** High

---

### ANV-005: Canon PRINT App
- **Objective:** Verify printing via Canon PRINT.
- **Prerequisites:** Android device with Canon PRINT. Printer shared. Module imported.
- **Test Environment:** E1, E3, E5 + Android
- **Execution Steps:**
  1. Open Canon PRINT.
  2. Search for printers.
  3. Connect to the Windows-shared printer.
  4. Print a test document.
- **Expected Result:** Printer discovered and prints.
- **Pass Criteria:** Print job completes.
- **Failure Criteria:** Discovery or print fails.
- **Evidence:** Screenshots, job status.
- **Severity:** High

---

### ANV-006: Brother iPrint&Scan
- **Objective:** Verify printing via Brother iPrint&Scan.
- **Prerequisites:** Android device with Brother iPrint&Scan. Printer shared.
- **Test Environment:** E1, E3, E5 + Android
- **Execution Steps:**
  1. Open Brother iPrint&Scan.
  2. Select printer → Search.
  3. Select the discovered Windows printer.
  4. Print a test page.
- **Expected Result:** Printer discovered. Print succeeds.
- **Pass Criteria:** Print completes.
- **Failure Criteria:** Print fails. Discovery fails.
- **Evidence:** Screenshots, job status.
- **Severity:** High

---

### ANV-007: Epson Smart Panel
- **Objective:** Verify printing via Epson Smart Panel.
- **Prerequisites:** Android device with Epson Smart Panel. Printer shared.
- **Test Environment:** E1, E3, E5 + Android
- **Execution Steps:**
  1. Open Epson Smart Panel.
  2. Search for printers.
  3. Select the Windows-shared printer.
  4. Print a test document.
- **Expected Result:** Printer discovered. Print succeeds.
- **Pass Criteria:** Print completes.
- **Failure Criteria:** Print fails. Discovery fails.
- **Evidence:** Screenshots, job status.
- **Severity:** High

---

## Performance Benchmarks (PERF)

*See `Validation/04_PERFORMANCE_BENCHMARKS.md` for detailed benchmark procedures. Summary test cases below.*

---

### PERF-001: Module Import Time
- **Objective:** Measure time to import the module.
- **Prerequisites:** First-time import (cold cache). Module not loaded.
- **Test Environment:** E1, E3, E8
- **Execution Steps:**
  1. Ensure module not loaded: `Remove-Module PrinterToolkit -Force -ErrorAction SilentlyContinue`
  2. Run: `Measure-Command { Import-Module .\PrinterToolkit\PrinterToolkit.psd1 -Force }`
  3. Repeat 5 times.
- **Expected Result:** Import completes in < 5 seconds per iteration.
- **Pass Criteria:** Average < 5 seconds.
- **Failure Criteria:** Average >= 10 seconds or any iteration > 30 seconds.
- **Evidence:** Timing output, transcript.
- **Severity:** Medium

---

### PERF-002: Get-Printers Execution Time
- **Objective:** Measure time for printer enumeration.
- **Prerequisites:** Module loaded. At least 3 printers.
- **Test Environment:** E1, E3, E5, E8
- **Execution Steps:**
  1. Run: `Measure-Command { Get-Printers }`
  2. Repeat 5 times.
- **Expected Result:** Average < 2 seconds.
- **Pass Criteria:** Average < 2 seconds.
- **Failure Criteria:** Average >= 5 seconds.
- **Evidence:** Timing output.
- **Severity:** Medium

---

### PERF-003: Queue Cleanup Time
- **Objective:** Measure time to clear a queue with pending jobs.
- **Prerequisites:** At least 5 pending jobs in a queue. Admin.
- **Test Environment:** E1, E3 (Admin)
- **Execution Steps:**
  1. Send 5+ test print jobs.
  2. Run: `Measure-Command { Clear-PrintQueue -PrinterName "Microsoft Print to PDF" -Force }`
  3. Repeat 5 times (re-sending jobs between runs).
- **Expected Result:** Average < 3 seconds.
- **Pass Criteria:** Average < 3 seconds.
- **Failure Criteria:** Average >= 10 seconds.
- **Evidence:** Timing output.
- **Severity:** Low

---

### PERF-004: Diagnostics Execution Time
- **Objective:** Measure time for full network validation.
- **Prerequisites:** Module loaded.
- **Test Environment:** E1, E3, E5
- **Execution Steps:**
  1. Run: `Measure-Command { Get-NetworkValidation }`
  2. Repeat 5 times.
- **Expected Result:** Average < 10 seconds.
- **Pass Criteria:** Average < 10 seconds.
- **Failure Criteria:** Average >= 30 seconds.
- **Evidence:** Timing output.
- **Severity:** Low

---

### PERF-005: Repair Workflow Time
- **Objective:** Measure time for automatic share repair.
- **Prerequisites:** Admin. Module loaded.
- **Test Environment:** E1, E3 (Admin)
- **Execution Steps:**
  1. Run: `Measure-Command { Invoke-AutomaticShareRepair }`
  2. Repeat 5 times.
- **Expected Result:** Average < 30 seconds.
- **Pass Criteria:** Average < 30 seconds.
- **Failure Criteria:** Average >= 60 seconds.
- **Evidence:** Timing output.
- **Severity:** Low

---

### PERF-006: Bundle Generation Time
- **Objective:** Measure time for diagnostic bundle creation.
- **Prerequisites:** Module loaded.
- **Test Environment:** E1, E3, E5
- **Execution Steps:**
  1. Run: `Measure-Command { New-DiagnosticBundle }`
  2. Repeat 5 times.
- **Expected Result:** Average < 15 seconds.
- **Pass Criteria:** Average < 15 seconds.
- **Failure Criteria:** Average >= 30 seconds.
- **Evidence:** Timing output.
- **Severity:** Low

---

### PERF-007: Report Generation Time
- **Objective:** Measure time for HTML report generation.
- **Prerequisites:** Module loaded. At least 3 printers.
- **Test Environment:** E1, E3, E5
- **Execution Steps:**
  1. Run: `Measure-Command { New-PrinterReport -Format HTML }`
  2. Repeat 5 times.
- **Expected Result:** Average < 5 seconds.
- **Pass Criteria:** Average < 5 seconds.
- **Failure Criteria:** Average >= 15 seconds.
- **Evidence:** Timing output.
- **Severity:** Low

---

### PERF-008: Memory Usage
- **Objective:** Measure memory footprint after import.
- **Prerequisites:** Module not loaded. Fresh PowerShell session.
- **Test Environment:** E1, E3, E8
- **Execution Steps:**
  1. Record baseline: `$before = (Get-Process -Id $PID).WorkingSet64`
  2. Import module.
  3. Record after: `$after = (Get-Process -Id $PID).WorkingSet64`
  4. Calculate: `$delta = $after - $before`
  5. Repeat 5 times.
- **Expected Result:** Memory increase < 50 MB per import.
- **Pass Criteria:** Average increase < 50 MB.
- **Failure Criteria:** Average increase >= 100 MB.
- **Evidence:** Memory measurements.
- **Severity:** Medium

---

### PERF-009: CPU Usage Under Load
- **Objective:** Measure CPU utilization during bundle generation.
- **Prerequisites:** Module loaded.
- **Test Environment:** E1, E3
- **Execution Steps:**
  1. Run bundle generation 3 times in parallel (3 PowerShell sessions or sequential).
  2. Record peak CPU from Task Manager or `Get-Counter`.
- **Expected Result:** Peak CPU < 50% on a 4-core machine.
- **Pass Criteria:** Peak < 50%.
- **Failure Criteria:** Peak >= 80% or sustained high usage.
- **Evidence:** Performance counter data.
- **Severity:** Low

---

## End of Test Cases
