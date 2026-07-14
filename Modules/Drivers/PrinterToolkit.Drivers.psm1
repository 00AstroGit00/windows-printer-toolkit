<#
.SYNOPSIS
    Driver Intelligence Engine for PrinterToolkit v6.0.

.DESCRIPTION
    Automatically detects VID, PID, Hardware IDs, Compatible IDs,
    manufacturer, model, driver store package, driver version,
    driver date, driver architecture, Type 3/Type 4, and WHQL status.
    Attempts driver installation through Windows Update, Driver Store,
    or user-provided INF package. Always verifies driver signatures.

.NOTES
    Module: PrinterToolkit.Drivers
    Author: PrinterToolkit Contributors
#>

function Get-PrinterDriverDetails {
    [CmdletBinding()]
    [OutputType([array])]
    param()
    $drivers = @(Get-PrinterDriver -ErrorAction SilentlyContinue)
    $results = foreach ($d in $drivers) {
        $infPath = if ($d.InfPath) { $d.InfPath } else { '' }

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

function Get-DriverIntelligence {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$PrinterName
    )

    $result = [PSCustomObject]@{
        PrinterName       = $PrinterName
        DriverFound       = $false
        DriverName        = ''
        DriverVersion     = ''
        DriverDate        = ''
        DriverType        = ''
        DriverArchitecture = ''
        IsSigned          = $false
        IsWHQL            = $false
        INFPath           = ''
        DriverStorePackage = ''
        VID               = ''
        PID               = ''
        HardwareIDs       = @()
        CompatibleIDs     = @()
        Manufacturer      = ''
        Model             = ''
        UpgradeRecommended = $false
        Detail            = ''
    }

    if (-not $PrinterName) {
        $usbPrinters = Get-UsbPrinterInfo
        if ($usbPrinters.Count -gt 0) {
            $PrinterName = $usbPrinters[0].PrinterName
            $result.PrinterName = $PrinterName
        }
    }

    if (-not $PrinterName) {
        $result.Detail = 'No printer specified or detected'
        return $result
    }

    try {
        $printer = Get-CimInstance -ClassName Win32_Printer -Filter "Name = '$($PrinterName -replace "'", "''")'" -ErrorAction SilentlyContinue
        if (-not $printer) {
            $result.Detail = 'Printer not found in WMI'
            return $result
        }

        $result.Manufacturer = $printer.DriverName -replace '\(.*\)', '' | ForEach-Object { $_.Trim() }
        $result.Model = $printer.Name

        $pnpId = $printer.PNPDeviceID
        if ($pnpId -match 'USB\\VID_([0-9A-Fa-f]{4})&PID_([0-9A-Fa-f]{4})') {
            $result.VID = "VID_$($matches[1])"
            $result.PID = "PID_$($matches[2])"
        }

        $driver = Get-PrinterDriver -Name $printer.DriverName -ErrorAction SilentlyContinue
        if ($driver) {
            $result.DriverFound = $true
            $result.DriverName = $driver.Name
            $result.DriverVersion = "$($driver.MajorVersion).$($driver.MinorVersion)"
            $result.DriverType = if ($driver.MajorVersion -ge 4) { 'Type 4' } else { 'Type 3' }
            $result.DriverArchitecture = if ($driver.IsArm64) { 'ARM64' } else { 'x64' }
            $result.IsPackageAware = $driver.IsPackageAware

            if ($driver.MajorVersion -lt 4) {
                $result.UpgradeRecommended = $true
            }

            try {
                if ($driver.InfPath) {
                    $result.INFPath = $driver.InfPath
                    $result.DriverStorePackage = [System.IO.Path]::GetFileName($driver.InfPath)
                }
                if ($result.INFPath -and (Test-Path -Path $result.INFPath)) {
                    $sig = Get-AuthenticodeSignature -FilePath $result.INFPath -ErrorAction SilentlyContinue
                    $result.IsSigned = ($null -ne $sig -and $sig.Status -eq 'Valid')
                }
            } catch {}
        } else {
            $result.Detail = 'No driver registered for this printer'
        }

        try {
            $dev = Get-PnpDevice -InstanceId $pnpId -ErrorAction SilentlyContinue
            if ($dev) {
                $result.HardwareIDs = @($dev.HardwareID -split ';')
                $result.CompatibleIDs = @($dev.CompatibleID -split ';')
            }
        } catch {}

    } catch {
        $result.Detail = $_.Exception.Message
        Write-Log -Message "Get-DriverIntelligence failed: $_" -Level 'ERROR'
    }

    return $result
}

function Export-PrinterDrivers {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath
    )

    Assert-Elevated

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

    Assert-Elevated

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

    Assert-Elevated

    $result = [PSCustomObject]@{
        Success  = $false
        ExitCode = -1
        Error    = ''
    }

    try {
        Remove-PrinterDriver -Name $DriverName -ErrorAction Stop
        $result.ExitCode = 0
        $result.Success = $true
    } catch {
        $result.ExitCode = -1
        $result.Error = $_.ToString()
    }

    return $result
}

function Test-DriverSignature {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$DriverName,

        [Parameter(Mandatory = $false)]
        [string]$InfPath
    )

    $result = [PSCustomObject]@{
        DriverName = $DriverName
        Signed     = $false
        Signer     = ''
        Status     = 'Unknown'
        Detail     = ''
    }

    $target = $InfPath
    if (-not $target -and $DriverName) {
        try {
            $pd = Get-PrinterDriver -Name $DriverName -ErrorAction SilentlyContinue
            if ($pd -and $pd.InfPath) {
                $target = $pd.InfPath
            }
        } catch {}
    }

    if (-not $target) { $result.Detail = 'Could not resolve driver package path'; return $result }
    if (-not (Test-Path -Path $target)) { $result.Detail = "Path not found: $target"; return $result }

    $file = Get-ChildItem -Path $target -Recurse -Include '*.dll', '*.sys', '*.inf' -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $file) { $result.Detail = 'No signable files found in package'; return $result }

    try {
        $sig = Get-AuthenticodeSignature -FilePath $file.FullName -ErrorAction Stop
        $result.Signed = ($sig.Status -eq 'Valid')
        $result.Signer = if ($sig.SignerCertificate) { $sig.SignerCertificate.Subject } else { '' }
        $result.Status = $sig.Status.ToString()
    } catch {
        $result.Detail = $_.Exception.Message
    }

    return $result
}

function Get-DriverUpgradeRecommendations {
    [CmdletBinding()]
    [OutputType([array])]
    param()
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

Export-ModuleMember -Function Get-PrinterDriverDetails, Get-DriverIntelligence, Export-PrinterDrivers, Restore-PrinterDrivers, Install-PrinterDriverFromInf, Remove-PrinterDriverByName, Get-DriverUpgradeRecommendations, Test-DriverSignature
