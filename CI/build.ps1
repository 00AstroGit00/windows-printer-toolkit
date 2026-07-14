<#
.SYNOPSIS
    CI build script for PrinterToolkit.

.DESCRIPTION
    Runs linting, Pester tests, module analysis, and packaging.
    Designed for both local development and CI pipeline execution.

.PARAMETER SkipTests
    Skip Pester test execution.

.PARAMETER OutputDir
    Override output directory for build artifacts.

.PARAMETER Configuration
    Build configuration: Debug or Release.

.EXAMPLE
    .\CI\build.ps1
    .\CI\build.ps1 -Configuration Release
    .\CI\build.ps1 -SkipTests -OutputDir .\artifacts
#>

[CmdletBinding()]
param(
    [switch]$SkipTests,
    [string]$OutputDir,
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release'
)

$ModuleRoot = Split-Path -Parent $PSScriptRoot
$Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'

$buildFailed = $false
$toolkitVersion = '8.0.0'
$manifestPath = Join-Path -Path $ModuleRoot -ChildPath 'PrinterToolkit.psd1'
if (Test-Path -Path $manifestPath) {
    $manifestData = Import-PowerShellDataFile -Path $manifestPath -ErrorAction SilentlyContinue
    if ($manifestData -and $manifestData.ModuleVersion) {
        $toolkitVersion = $manifestData.ModuleVersion.ToString()
    }
}

function Write-Step {
    param([string]$Message, [string]$Status = 'INFO')
    $color = switch ($Status) {
        'OK' { 'Green' }; 'FAIL' { 'Red' }; 'WARN' { 'Yellow' }
        default { 'White' }
    }
    Write-Host "[$Status] $Message" -ForegroundColor $color
}

Write-Host '========================================' -ForegroundColor Cyan
Write-Host "  PrinterToolkit v$toolkitVersion Build Script" -ForegroundColor White
Write-Host '  Configuration: ' -NoNewline; Write-Host $Configuration -ForegroundColor Yellow
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''

# Step 1: Validate module structure
Write-Step 'Validating module structure...'
$expectedDirs = @(
    'Modules\Core', 'Modules\Detection', 'Modules\Configuration', 'Modules\Drivers',
    'Modules\Networking', 'Modules\IPP', 'Modules\SMB', 'Modules\Sharing',
    'Modules\Android', 'Modules\Diagnostics', 'Modules\Repair', 'Modules\Rollback',
    'Modules\Validation', 'Modules\SetupWizard', 'Modules\Reporting', 'Modules\Logging',
    'Modules\Utilities', 'Modules\Bundle'
)
$missingDirs = @()
foreach ($dir in $expectedDirs) {
    $fullPath = Join-Path -Path $ModuleRoot -ChildPath $dir
    if (-not (Test-Path $fullPath)) { $missingDirs += $dir }
}
if ($missingDirs.Count -gt 0) {
    Write-Step "Missing directories: $($missingDirs -join ', ')" 'FAIL'
    $buildFailed = $true
} else {
    Write-Step 'All module directories present' 'OK'
}

# Step 2: Validate module files
Write-Step 'Validating module files...'
$expectedFiles = @(Join-Path $ModuleRoot 'PrinterToolkit.psd1'; Join-Path $ModuleRoot 'PrinterToolkit.psm1')
$missingFiles = @()
foreach ($f in $expectedFiles) {
    if (-not (Test-Path $f)) { $missingFiles += $f }
}
if ($missingFiles.Count -gt 0) {
    Write-Step "Missing files: $($missingFiles -join ', ')" 'FAIL'
    $buildFailed = $true
} else {
    Write-Step 'Core module files present' 'OK'
}

# Step 3: Syntax check (if available)
Write-Step 'Checking PowerShell syntax...'
$psm1Files = Get-ChildItem -Path $ModuleRoot -Recurse -Filter '*.psm1' -ErrorAction SilentlyContinue
$ps1Files = Get-ChildItem -Path $ModuleRoot -Recurse -Filter '*.ps1' -ErrorAction SilentlyContinue
$allScripts = $psm1Files + $ps1Files
$syntaxErrors = @()
foreach ($script in $allScripts) {
    try {
        $null = [System.Management.Automation.Language.Parser]::ParseFile($script.FullName, [ref]$null, [ref]$null)
    } catch {
        $syntaxErrors += $script.Name
    }
}
if ($syntaxErrors.Count -gt 0) {
    Write-Step "Syntax errors in: $($syntaxErrors -join ', ')" 'FAIL'
    $buildFailed = $true
} else {
    Write-Step "All $($allScripts.Count) scripts pass syntax check" 'OK'
}

# Step 4: Run Pester tests
if (-not $SkipTests) {
    Write-Step 'Running Pester tests...'
    $available = Get-Module -ListAvailable -Name Pester | Select-Object -First 1
    if (-not $available) {
        Write-Step 'Pester not installed. Install with: Install-Module Pester -Force -Scope CurrentUser' 'WARN'
    } else {
        $testFile = Join-Path $ModuleRoot 'Tests\PrinterToolkit.Tests.ps1'
        if (Test-Path $testFile) {
            $testResults = Invoke-Pester -Path $testFile -PassThru -ErrorAction SilentlyContinue
            if ($testResults.FailedCount -gt 0) {
                Write-Step "$($testResults.FailedCount) test(s) FAILED" 'FAIL'
                $buildFailed = $true
            } else {
                Write-Step "All $($testResults.TotalCount) test(s) PASSED" 'OK'
            }
        } else {
            Write-Step "Test file not found: $testFile" 'WARN'
        }
    }
} else {
    Write-Step 'Tests skipped' 'WARN'
}

# Step 5: Analyze exports vs manifest
Write-Step 'Analyzing module exports...'
try {
    $null = Import-Module (Join-Path $ModuleRoot 'PrinterToolkit.psd1') -Force -ErrorAction Stop
    $manifest = Import-PowerShellDataFile (Join-Path $ModuleRoot 'PrinterToolkit.psd1')
    $declaredExports = $manifest.FunctionsToExport
    $actualExports = Get-Command -Module PrinterToolkit | Select-Object -ExpandProperty Name

    $missingFromManifest = $actualExports | Where-Object { $_ -notin $declaredExports }
    if ($missingFromManifest.Count -gt 0) {
        Write-Step "Functions exported but not declared in manifest: $($missingFromManifest -join ', ')" 'WARN'
    }

    $declaredButMissing = $declaredExports | Where-Object { $_ -notin $actualExports }
    if ($declaredButMissing.Count -gt 0) {
        Write-Step "Functions declared in manifest but not exported: $($declaredButMissing -join ', ')" 'FAIL'
        $buildFailed = $true
    }

    if ($missingFromManifest.Count -eq 0 -and $declaredButMissing.Count -eq 0) {
        Write-Step 'All exports match manifest declarations' 'OK'
    }
} catch {
    Write-Step "Module analysis failed: $_" 'WARN'
} finally {
    Remove-Module PrinterToolkit -Force -ErrorAction SilentlyContinue
}

# Step 6: Package
if (-not $OutputDir) {
    $OutputDir = Join-Path -Path $ModuleRoot -ChildPath "artifacts\PrinterToolkit_v$toolkitVersion_$Timestamp"
}
$null = New-Item -ItemType Directory -Force -Path $OutputDir

Write-Step "Packaging to: $OutputDir..."
try {
    $exclusions = @('artifacts', '.git', '.github', 'CI\build.ps1', 'Tests')
    $items = Get-ChildItem -Path $ModuleRoot -Exclude $exclusions

    foreach ($item in $items) {
        $dest = Join-Path -Path $OutputDir -ChildPath $item.Name
        if ($item.PSIsContainer) {
            Copy-Item -Path $item.FullName -Destination $dest -Recurse -Force
        } else {
            Copy-Item -Path $item.FullName -Destination $dest -Force
        }
    }

    # Generate manifest
    $buildManifest = @{
        Version       = $toolkitVersion
        BuildDate     = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        Configuration = $Configuration
        TotalScripts  = $allScripts.Count
        TestsPassed   = if ($testResults) { $testResults.PassedCount } else { 0 }
        TestsFailed   = if ($testResults) { $testResults.FailedCount } else { 0 }
    }
    $buildManifest | ConvertTo-Json | Out-File (Join-Path $OutputDir 'build_manifest.json') -Encoding UTF8

    Write-Step "Package created at: $OutputDir" 'OK'
} catch {
    Write-Step "Packaging failed: $_" 'FAIL'
    $buildFailed = $true
}

Write-Host ''
if ($buildFailed) {
    Write-Host 'BUILD COMPLETED WITH ERRORS' -ForegroundColor Yellow
    exit 1
} else {
    Write-Host 'BUILD COMPLETED SUCCESSFULLY' -ForegroundColor Green
    exit 0
}
