<#
.SYNOPSIS
    Publishes PrinterToolkit to the PowerShell Gallery.
.DESCRIPTION
    Validates the manifest, runs tests, then publishes.
    Requires a PowerShell Gallery API key.
.PARAMETER ApiKey
    PowerShell Gallery API key from https://www.powershellgallery.com/account
.PARAMETER WhatIf
    Validate only — do not publish.
.PARAMETER Version
    Module version to publish. Must match PrinterToolkit.psd1.
.EXAMPLE
    .\dist\psgallery\Publish-PrtkToGallery.ps1 -ApiKey "your-api-key"
.EXAMPLE
    .\dist\psgallery\Publish-PrtkToGallery.ps1 -WhatIf
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ApiKey,

    [Parameter(Mandatory = $false)]
    [switch]$WhatIf,

    [Parameter(Mandatory = $false)]
    [string]$Version = '5.0.1'
)

$ErrorActionPreference = 'Stop'
$ModuleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$ManifestPath = Join-Path -Path $ModuleRoot -ChildPath 'PrinterToolkit.psd1'

Write-Host 'PrinterToolkit — PowerShell Gallery Publisher' -ForegroundColor Cyan
Write-Host "Module root: $ModuleRoot" -ForegroundColor Gray
Write-Host "Manifest:    $ManifestPath" -ForegroundColor Gray
Write-Host "Version:     $Version" -ForegroundColor Gray
Write-Host ''

# Step 1: Verify PowerShellGet
Write-Host '[1/6] Checking PowerShellGet...' -ForegroundColor White
$pg = Get-Module -ListAvailable -Name PowerShellGet | Select-Object -First 1
if (-not $pg) {
    Write-Host '  Installing PowerShellGet...' -ForegroundColor Yellow
    Install-Module PowerShellGet -Force -Scope CurrentUser -SkipPublisherCheck
}
Write-Host '  [OK]' -ForegroundColor Green

# Step 2: Validate manifest
Write-Host '[2/6] Validating module manifest...' -ForegroundColor White
$testResult = Test-ModuleManifest -Path $ManifestPath -ErrorAction Stop
if (-not $testResult) {
    Write-Host '  [FAIL] Manifest validation failed' -ForegroundColor Red
    exit 1
}
$manifestVersion = $testResult.Version.ToString()
if ($manifestVersion -ne $Version) {
    Write-Host "  [FAIL] Manifest version ($manifestVersion) does not match expected ($Version)" -ForegroundColor Red
    exit 1
}
Write-Host "  [OK] Version $manifestVersion" -ForegroundColor Green

# Step 3: Run PSScriptAnalyzer
Write-Host '[3/6] Running PSScriptAnalyzer...' -ForegroundColor White
$sa = Get-Module -ListAvailable -Name PSScriptAnalyzer | Select-Object -First 1
if ($sa) {
    $results = Invoke-ScriptAnalyzer -Path $ModuleRoot -Recurse -Severity Error -ExcludeRule @('PSAvoidUsingWriteHost')
    if ($results.Count -gt 0) {
        Write-Host "  [FAIL] $($results.Count) error(s) found" -ForegroundColor Red
        $results | Format-Table
        exit 1
    }
    Write-Host '  [OK] No errors' -ForegroundColor Green
} else {
    Write-Host '  [SKIP] PSScriptAnalyzer not installed' -ForegroundColor Yellow
}

# Step 4: Run Pester tests
Write-Host '[4/6] Running Pester tests...' -ForegroundColor White
$testFile = Join-Path -Path $ModuleRoot -ChildPath 'Tests\PrinterToolkit.Tests.ps1'
if (Test-Path $testFile) {
    $testResults = Invoke-Pester -Path $testFile -PassThru -ErrorAction SilentlyContinue
    if ($testResults.FailedCount -gt 0) {
        Write-Host "  [FAIL] $($testResults.FailedCount) test(s) failed" -ForegroundColor Red
        exit 1
    }
    Write-Host "  [OK] $($testResults.PassedCount)/$($testResults.TotalCount) passed" -ForegroundColor Green
} else {
    Write-Host '  [SKIP] Test file not found' -ForegroundColor Yellow
}

# Step 5: Publish
if ($WhatIf) {
    Write-Host '[5/6] WHATIF mode — skipping publish' -ForegroundColor Yellow
} else {
    Write-Host '[5/6] Publishing to PowerShell Gallery...' -ForegroundColor White
    if (-not $ApiKey) {
        Write-Host '  [FAIL] -ApiKey is required for publish' -ForegroundColor Red
        exit 1
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    $params = @{
        Path        = $ModuleRoot
        NuGetApiKey = $ApiKey
        Verbose     = $true
    }
    Publish-Module @params
    Write-Host '  [OK] Published to PowerShell Gallery' -ForegroundColor Green
}

# Step 6: Verify
Write-Host '[6/6] Verification...' -ForegroundColor White
if (-not $WhatIf) {
    Start-Sleep -Seconds 10
    $find = Find-Module -Name PrinterToolkit -ErrorAction SilentlyContinue
    if ($find) {
        Write-Host "  [OK] Found on Gallery: $($find.Version)" -ForegroundColor Green
    } else {
        Write-Host '  [WARN] Module not yet visible on Gallery (may take a few minutes)' -ForegroundColor Yellow
    }
} else {
    Write-Host '  [SKIP] Verification skipped in WhatIf mode' -ForegroundColor Yellow
}

Write-Host ''
Write-Host 'Done.' -ForegroundColor Cyan
