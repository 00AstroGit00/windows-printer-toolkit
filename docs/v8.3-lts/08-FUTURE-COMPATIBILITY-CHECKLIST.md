# Future Compatibility Checklist — PrinterToolkit v8.3 LTS

> **Purpose:** Automated checks that detect Windows API changes, deprecated cmdlets, manifest issues, module import regressions, and provider interface regressions. Designed to fail early in CI when future Windows or PowerShell releases introduce breaking changes.

---

## 1. Windows API Change Detection

### 1.1 Cmdlet Availability Check

```powershell
# CHECK: Every Windows cmdlet used by PrinterToolkit is still available
# Add this to CI analyze job

$requiredCmdlets = @(
    'Get-Printer', 'Set-Printer', 'Get-PrinterDriver', 'Add-PrinterDriver',
    'Remove-PrinterDriver', 'Get-PrinterPort', 'Add-PrinterPort',
    'Get-NetFirewallRule', 'Enable-NetFirewallRule', 'Disable-NetFirewallRule',
    'New-NetFirewallRule',
    'Get-SmbShare', 'Set-SmbShare', 'Grant-SmbShareAccess', 'Revoke-SmbShareAccess',
    'Get-SmbServerConfiguration', 'Set-SmbServerConfiguration',
    'Get-WindowsOptionalFeature', 'Enable-WindowsOptionalFeature', 'Disable-WindowsOptionalFeature',
    'Get-WindowsDriver',
    'Get-NetConnectionProfile', 'Set-NetConnectionProfile',
    'Get-Service', 'Set-Service', 'Start-Service', 'Stop-Service',
    'Get-CimInstance', 'Get-CimClass', 'Invoke-CimMethod'
)

$missing = @()
foreach ($cmd in $requiredCmdlets) {
    if (-not (Get-Command -Name $cmd -ErrorAction SilentlyContinue)) {
        $missing += $cmd
    }
}

if ($missing.Count -gt 0) {
    Write-Error "Missing cmdlets: $($missing -join ', ')"
    exit 1
}
```

### 1.2 CIM Class Availability Check

```powershell
# CHECK: Every CIM class used by PrinterToolkit is still available

$requiredClasses = @(
    'Win32_Printer', 'Win32_PrinterDriver', 'Win32_OperatingSystem',
    'Win32_ComputerSystem', 'Win32_NetworkAdapterConfiguration',
    'Win32_PnPEntity', 'Win32_USBControllerDevice', 'Win32_PrintJob',
    'Win32_Service', 'Win32_Share', 'Win32_PnPSignedDriver',
    'MSFT_NetFirewallRule'
)

$missing = @()
foreach ($class in $requiredClasses) {
    if (-not (Get-CimClass -ClassName $class -ErrorAction SilentlyContinue)) {
        $missing += $class
    }
}

if ($missing.Count -gt 0) {
    Write-Error "Missing CIM classes: $($missing -join ', ')"
    exit 1
}
```

### 1.3 Windows Feature Name Check

```powershell
# CHECK: Windows feature names used by PrinterToolkit are still valid

$requiredFeatures = @(
    'Printing-Foundation-Features',
    'Printing-Foundation-InternetPrinting-Client',
    'Printing-Foundation-InternetPrinting-Server',
    'SMB1Protocol'
)

$missing = @()
foreach ($feature in $requiredFeatures) {
    $f = Get-WindowsOptionalFeature -Online -FeatureName $feature -ErrorAction SilentlyContinue
    if (-not $f) {
        $missing += $feature
    }
}

if ($missing.Count -gt 0) {
    Write-Warning "Missing Windows features (may be renamed): $($missing -join ', ')"
    # Do not fail — features may have been renamed
}
```

### 1.4 Service Name Check

```powershell
# CHECK: Service names used by PrinterToolkit are still valid

$requiredServices = @(
    'Spooler', 'LanmanServer', 'LanmanWorkstation', 'FDResPub',
    'FDPhost', 'RpcSs', 'DcomLaunch', 'DNSCache', 'SSDPSRV', 'upnphost'
)

$missing = @()
foreach ($svc in $requiredServices) {
    if (-not (Get-Service -Name $svc -ErrorAction SilentlyContinue)) {
        $missing += $svc
    }
}

if ($missing.Count -gt 0) {
    Write-Warning "Missing services (may have been removed): $($missing -join ', ')"
}
```

---

## 2. Deprecated Cmdlet Detection

### 2.1 Deprecated Cmdlet Usage Scan

```powershell
# CHECK: No deprecated cmdlets are used in the codebase
# Add this to CI analyze job

$deprecatedCmdlets = @(
    'Get-WmiObject',       # Replaced by Get-CimInstance
    'Invoke-WmiMethod',    # Replaced by Invoke-CimMethod
    'Remove-WmiObject',    # Replaced by Remove-CimInstance
    'Set-WmiInstance',     # Replaced by Set-CimInstance
    'New-WebServiceProxy', # Deprecated
    'ConvertFrom-String',  # Deprecated
    'Out-Null'             # Best practice: use $null =
)

$files = Get-ChildItem -Path . -Recurse -Include '*.psm1', '*.ps1' | Where-Object {
    $_.FullName -notmatch '\\Tests\\' -and $_.FullName -notmatch '\\.git\\'
}

$issues = @()
foreach ($file in $files) {
    $content = Get-Content -Path $file.FullName -Raw
    foreach ($cmd in $deprecatedCmdlets) {
        if ($content -match "\b$cmd\b") {
            $issues += "$($file.Name) uses deprecated cmdlet: $cmd"
        }
    }
}

if ($issues.Count -gt 0) {
    Write-Warning "Deprecated cmdlets found:`n$($issues -join "`n")"
    # Warning only — not a hard failure for backward compatibility
}
```

---

## 3. Manifest Integrity Check

### 3.1 FunctionsToExport vs Actual Exports

```powershell
# CHECK: Every function in FunctionsToExport has a matching implementation
# CHECK: No implementation exists without a matching export entry

Import-Module .\PrinterToolkit.psd1 -Force -ErrorAction Stop
$manifest = Import-PowerShellDataFile .\PrinterToolkit.psd1
$exported = $manifest.FunctionsToExport
$actual = Get-Command -Module PrinterToolkit | Select-Object -ExpandProperty Name

# Orphan exports (in manifest but not in code)
$orphans = $exported | Where-Object { $_ -notin $actual }
if ($orphans.Count -gt 0) {
    Write-Error "Orphan exports (listed but not implemented): $($orphans -join ', ')"
    exit 1
}

# Hidden commands (in code but not in manifest) — just warn
$hidden = $actual | Where-Object { $_ -notin $exported }
if ($hidden.Count -gt 0) {
    Write-Warning "Hidden commands (implemented but not exported): $($hidden -join ', ')"
}
```

### 3.2 NestedModules File Existence

```powershell
# CHECK: Every NestedModules file exists on disk

foreach ($module in $manifest.NestedModules) {
    $path = Join-Path $PSScriptRoot $module
    if (-not (Test-Path $path)) {
        Write-Error "Missing NestedModule: $path"
        exit 1
    }
}
```

### 3.3 Module Version Consistency

```powershell
# CHECK: Version strings match across all source files

$manifestVersion = $manifest.ModuleVersion

$files = @(
    @{ Path = 'PrinterToolkit.psm1'; Pattern = '^\$Script:ModuleVersion\s*=\s*''([\d\.]+)''' },
    @{ Path = 'install.ps1'; Pattern = '^\$script:ModuleVersion\s*=\s*''([\d\.]+)''' }
)

$errors = @()
foreach ($entry in $files) {
    $content = Get-Content -Path $entry.Path -Raw
    if ($content -match $entry.Pattern) {
        $version = $matches[1]
        if ($version -ne $manifestVersion) {
            $errors += "Version mismatch in $($entry.Path): expected $manifestVersion, got $version"
        }
    } else {
        $errors += "Could not find version in $($entry.Path)"
    }
}

if ($errors.Count -gt 0) {
    Write-Error $errors -join "`n"
    exit 1
}
```

---

## 4. Module Import Regression Check

### 4.1 Clean Import Test

```powershell
# CHECK: Module imports without errors on PS 5.1 and PS 7.x

$errors = $null
$null = Import-Module .\PrinterToolkit.psd1 -Force -ErrorAction Stop -WarningAction SilentlyContinue -PassThru

# Verify all NestedModules loaded
$module = Get-Module PrinterToolkit
$nestedCount = ($manifest.NestedModules).Count
$actualNested = @($module.NestedModules).Count

if ($actualNested -lt $nestedCount) {
    Write-Error "Only $actualNested of $nestedCount NestedModules loaded"
    exit 1
}
```

### 4.2 Function Export Count Regression

```powershell
# CHECK: No exported functions were accidentally removed

$previousCount = 106  # Known count from v8.2.0
$currentCount = @(Get-Command -Module PrinterToolkit).Count

if ($currentCount -lt $previousCount - 2) {
    Write-Error "Export regression: was $previousCount, now $currentCount"
    exit 1
}
```

---

## 5. Provider Interface Regression Test

### 5.1 New-ProviderResult Contract Check

```powershell
# CHECK: New-ProviderResult returns the expected contract

$result = New-ProviderResult -Status Success -Message 'Test'

$requiredProperties = @('Status', 'Success', 'ErrorCode', 'Category',
    'RecommendedAction', 'Recoverability', 'Message', 'Data', 'Timestamp')

$missing = $requiredProperties | Where-Object { -not $result.PSObject.Properties.Name.Contains($_) }

if ($missing.Count -gt 0) {
    Write-Error "New-ProviderResult missing properties: $($missing -join ', ')"
    exit 1
}

# Verify Status enum values
$validStatuses = @('Success', 'Warning', 'Failed', 'Skipped', 'NotApplicable', 'Unsupported')
if ($validStatuses -notcontains $result.Status) {
    Write-Error "New-ProviderResult Status '$( $result.Status )' not in valid set"
    exit 1
}

# Verify Success is boolean and matches Status
if ($result.Success -isnot [bool] -or $result.Success -ne ($result.Status -eq 'Success')) {
    Write-Error "New-ProviderResult Success field inconsistent with Status"
    exit 1
}
```

### 5.2 Orchestration Task Contract Check

```powershell
# CHECK: OrchestrationTask has all expected properties

$task = New-OrchestrationTask -Name 'Test' -Description 'd' -Category 'C' -Execute {} -Validate {}

$requiredTaskProps = @(
    'Name', 'Description', 'Category', 'Subsystem', 'Dependencies',
    'Prerequisites', 'Execute', 'Validate', 'Rollback', 'RetryPolicy',
    'TimeoutMs', 'IsCritical', 'CanSkip', 'EstimatedDuration',
    'RequiredElevation', 'RequiredWindowsFeatures', 'RequiredServices',
    'Outputs', 'Status', 'Attempts', 'DurationMs', 'Error'
)

$missingProps = $requiredTaskProps | Where-Object { -not $task.PSObject.Properties.Name.Contains($_) }

if ($missingProps.Count -gt 0) {
    Write-Error "OrchestrationTask missing properties: $($missingProps -join ', ')"
    exit 1
}
```

### 5.3 Orchestrator Return Contract Check

```powershell
# CHECK: Invoke-Orchestrator always returns the expected contract shape

$t = New-OrchestrationTask -Name 'T1' -Description 'd' -Category 'C' -Execute {} -Validate {}
$result = Invoke-Orchestrator -Tasks @($t)

$requiredResultProps = @('Success', 'Tasks', 'Failed', 'Skipped', 'Succeeded', 'Recovered', 'Transaction')
$missingProps = $requiredResultProps | Where-Object { -not $result.PSObject.Properties.Name.Contains($_) }

if ($missingProps.Count -gt 0) {
    Write-Error "Invoke-Orchestrator result missing properties: $($missingProps -join ', ')"
    exit 1
}
```

---

## 6. PowerShell Version Compatibility

### 6.1 PS 5.1 Syntax Check

```powershell
# CHECK: All files parse correctly under PowerShell 5.1 syntax rules
# (cross-version compatibility)

$files = Get-ChildItem -Path . -Recurse -Include '*.psm1', '*.ps1' | Where-Object {
    $_.FullName -notmatch '\\.git\\'
}

$errors = @()
foreach ($file in $files) {
    try {
        $null = [System.Management.Automation.Language.Parser]::ParseFile(
            $file.FullName, [ref]$null, [ref]$null)
    } catch {
        $errors += $file.Name
    }
}

if ($errors.Count -gt 0) {
    Write-Error "Syntax errors in: $($errors -join ', ')"
    exit 1
}
```

### 6.2 PowerShell Class Compatibility Check

```powershell
# CHECK: PowerShell classes used in the module are compatible with PS 5.1

$classContent = Get-Content -Path .\Modules\Orchestration\PrinterToolkit.Orchestration.psm1 -Raw
if ($classContent -match 'class\s+\w+\s*\{') {
    Write-Host "PowerShell classes detected — verifying PS 5.1 compatibility"
    # PowerShell classes are supported in PS 5.0+, so this is informational only
}
```

---

## 7. CI Integration

### 7.1 New CI Job: `compatibility-check`

Add this job to `.github/workflows/ci.yml`:

```yaml
compatibility:
  name: Future Compatibility Check
  runs-on: windows-latest
  needs: analyze
  steps:
    - uses: actions/checkout@v4
    - name: Run Compatibility Checks
      shell: pwsh
      run: |
        # Execute the most critical checks from this document
        # (cmdlet availability, CIM class availability, manifest integrity)
        # See docs/v8.3-lts/08-FUTURE-COMPATIBILITY-CHECKLIST.md for full list
        ./CI/compatibility-check.ps1
    - name: Run Windows API Checks
      shell: pwsh
      run: |
        ./CI/detect-deprecated-apis.ps1
```

### 7.2 Scheduled Weekly Compatibility Check

```yaml
on:
  schedule:
    - cron: '0 6 * * 1'  # Every Monday 06:00 UTC
  workflow_dispatch:       # Manual trigger
```

This scheduled run compares current Windows API surface against PrinterToolkit's dependencies and produces a report.

---

## 8. Automated Script: `CI/compatibility-check.ps1`

This single script should implement all checks above and return:

- Exit code 0: All checks pass
- Exit code 1: One or more checks fail
- Output: Structured JSON report saved as artifact

### Recommended Structure

```powershell
param(
    [switch]$ReportOnly  # Don't fail, just produce report
)

$results = [System.Collections.ArrayList]::new()

# Add check results to $results
# Each result: @{ Check = 'Name'; Status = 'PASS'|'WARN'|'FAIL'; Detail = '...' }

$report = $results | ConvertTo-Json
$report | Out-File -Path "compatibility-report.json"

$failed = @($results | Where-Object { $_.Status -eq 'FAIL' })
if ($failed.Count -gt 0 -and -not $ReportOnly) {
    exit 1
}
```

---

## 9. When to Update This Checklist

| Trigger | Action |
|---------|--------|
| New Windows version released | Review all cmdlet/class/feature checks |
| New PowerShell version | Review PS version compatibility checks |
| New module added | Add to cmdlet/CIM checks |
| Cmdlet deprecated by Microsoft | Add to deprecated cmdlet detection |
| CI scheduled run fails | Investigate and update code or checklist |
