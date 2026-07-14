<#
.SYNOPSIS
    Print driver intelligence and management for PrinterToolkit.

.DESCRIPTION
    Detects driver version, type (Type 3 vs Type 4), architecture, INF location.
    Supports export, restore, INF installation, and removal operations.

.NOTES
    Module: PrinterToolkit.Drivers
    Author: PrinterToolkit Contributors
#>

function Get-PrinterDriverDetails {
    [CmdletBinding()]
    [OutputType([array])]

    $drivers = @(Get-PrinterDriver -ErrorAction SilentlyContinue)
    $results = foreach ($d in $drivers) {
        $infPath = ''
        try {
            $enumOutput = pnputil /enum-drivers 2>$null
            $matched = $enumOutput | Select-String -Pattern $d.Name -Context 0, 10
            if ($matched) {
                $infLine = $matched.Context.PostContext | Where-Object { $_ -match 'Published Name' }
                if ($infLine) {
                    $oemId = ($infLine -replace '.*:\s+', '').Trim()
                    $infPath = "C:\Windows\System32\DriverStore\FileRepository\$oemId"
                }
            }
        } catch {
            Write-Debug "Could not resolve INF for $($d.Name): $_"
        }

        [PSCustomObject]@{
            Name              = $d.Name
            Manufacturer      = $d.Manufacturer
            MajorVersion      = $d.MajorVersion
            DriverType        = if ($d.MajorVersion -ge 4) { 'Type 4' } else { 'Type 3' }
            Architecture      = if ($d.IsArm64) { 'ARM64' } else { 'x64' }
            PrinterCount      = @($d.Printers).Count
            INFPath           = $infPath
            IsPackageAware    = $d.IsPackageAware
        }
    }

    return ,$results
}

function Export-PrinterDrivers {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath
    )

    if (-not $OutputPath) {
        $OutputPath = Join-Path -Path ([Environment]::GetFolderPath('Desktop')) -ChildPath "PrinterToolkit_Drivers_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    }
    $null = New-Item -ItemType Directory -Force -Path $OutputPath

    $drivers = Get-PrinterDriverDetails
    $drivers | Export-Csv -Path (Join-Path -Path $OutputPath -ChildPath 'driver_manifest.csv') -NoTypeInformation -Encoding UTF8
    $drivers | ConvertTo-Json | Out-File -FilePath (Join-Path -Path $OutputPath -ChildPath 'driver_manifest.json') -Encoding UTF8

    foreach ($d in $drivers) {
        if ($d.INFPath -and (Test-Path -Path $d.INFPath)) {
            $destDir = Join-Path -Path $OutputPath -ChildPath 'inf'
            $null = New-Item -ItemType Directory -Force -Path $destDir -ErrorAction SilentlyContinue
            try {
                Copy-Item -Path "$($d.INFPath)\*" -Destination $destDir -Recurse -Force -ErrorAction SilentlyContinue
            } catch {
                Write-Debug "Could not copy INF for $($d.Name): $_"
            }
        }
    }

    return $OutputPath
}

function Restore-PrinterDrivers {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({
            if (-not (Test-Path $_)) { throw 'Source path not found' }
            if ($_ -match '[";|&$`]') { throw 'Invalid characters in path' }
            $resolved = Resolve-Path $_ -ErrorAction SilentlyContinue
            if (-not $resolved) { throw 'Could not resolve path' }
            $true
        })]
        [string]$SourcePath
    )

    $result = [PSCustomObject]@{
        Success = $false
        Restored = @()
        Errors = @()
    }

    $resolvedPath = (Resolve-Path $SourcePath -ErrorAction Stop).ProviderPath
    $infDir = Join-Path -Path $resolvedPath -ChildPath 'inf'
    if (-not (Test-Path -Path $infDir)) {
        $infDir = $resolvedPath
    }

    $infFiles = Get-ChildItem -Path $infDir -Recurse -Filter '*.inf' -ErrorAction SilentlyContinue
    foreach ($inf in $infFiles) {
        try {
            $proc = Start-Process -FilePath 'pnputil.exe' -ArgumentList "/add-driver `"$($inf.FullName)`" /install" -NoNewWindow -Wait -PassThru
            if ($proc.ExitCode -eq 0) {
                $result.Restored += $inf.FullName
            } else {
                $result.Errors += "Failed to install $($inf.Name) (exit: $($proc.ExitCode))"
            }
        } catch {
            $result.Errors += "$($inf.Name): $_"
        }
    }

    if ($result.Restored.Count -gt 0) {
        $result.Success = ($result.Errors.Count -eq 0)
    }

    return $result
}

function Install-PrinterDriverFromInf {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({
            if (-not (Test-Path $_)) { throw 'File not found' }
            if ($_ -match '[";|&$`]') { throw 'Invalid characters in path' }
            if ($_ -notmatch '\.inf$') { throw 'Must be a .inf file' }
            $resolved = Resolve-Path $_ -ErrorAction SilentlyContinue
            if (-not $resolved) { throw 'Could not resolve path' }
            $true
        })]
        [string]$InfPath
    )

    $result = [PSCustomObject]@{
        Success  = $false
        ExitCode = -1
        Output   = ''
        Error    = ''
    }

    try {
        $resolvedPath = (Resolve-Path $InfPath -ErrorAction Stop).ProviderPath
        $proc = Start-Process -FilePath 'pnputil.exe' -ArgumentList @('/add-driver', $resolvedPath, '/install') -NoNewWindow -Wait -PassThru
        $result.ExitCode = $proc.ExitCode
        $result.Success = ($proc.ExitCode -eq 0)
        if (-not $result.Success) {
            $result.Error = "pnputil exited with code $($proc.ExitCode)"
        }
    } catch {
        $result.Error = $_.ToString()
    }

    return $result
}

function Remove-PrinterDriverByName {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^[a-zA-Z0-9 _\-.()]+$')]
        [string]$DriverName
    )

    $result = [PSCustomObject]@{
        Success  = $false
        ExitCode = -1
        Error    = ''
    }

    try {
        $null = Start-Process -FilePath 'rundll32.exe' -ArgumentList @('PRINTUI.DLL,PrintUIEntry', '/dd', '/m', "`"$DriverName`"", '/q') -NoNewWindow -Wait -PassThru
        $result.ExitCode = $LASTEXITCODE
        $result.Success = ($LASTEXITCODE -eq 0)
    } catch {
        $result.Error = $_.ToString()
    }

    return $result
}

function Get-DriverUpgradeRecommendations {
    [CmdletBinding()]
    [OutputType([array])]

    $drivers = Get-PrinterDriverDetails
    $recommendations = foreach ($d in $drivers) {
        $notes = @()
        if ($d.DriverType -eq 'Type 3') {
            $notes += 'Type 3 drivers are being phased out. Consider migrating to Type 4 or IPP Class Driver.'
        }
        if ($notes.Count -gt 0) {
            [PSCustomObject]@{
                DriverName      = $d.Name
                CurrentType     = $d.DriverType
                Recommendations = $notes -join '; '
            }
        }
    }

    return ,$recommendations
}

Export-ModuleMember -Function Get-PrinterDriverDetails, Export-PrinterDrivers, Restore-PrinterDrivers, Install-PrinterDriverFromInf, Remove-PrinterDriverByName, Get-DriverUpgradeRecommendations
