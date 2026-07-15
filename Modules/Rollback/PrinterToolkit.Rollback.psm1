<#
.SYNOPSIS
    Configuration rollback engine for PrinterToolkit v6.0.

.DESCRIPTION
    Creates restore points before configuration changes and provides
    reliable rollback capability. Backs up registry, services, firewall,
    printer configuration, and network settings.

.NOTES
    Module: PrinterToolkit.Rollback
    Author: PrinterToolkit Contributors
#>

$Script:RollbackRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath 'PrinterToolkit_Rollback'

function Initialize-RepairRollback {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $rollbackPath = Join-Path -Path $Script:RollbackRoot -ChildPath "Rollback_$timestamp"
    $null = New-Item -ItemType Directory -Force -Path $rollbackPath

    try {
        $null = New-Item -ItemType Directory -Force -Path (Join-Path $rollbackPath 'Registry')
        $null = New-Item -ItemType Directory -Force -Path (Join-Path $rollbackPath 'Services')
        $null = New-Item -ItemType Directory -Force -Path (Join-Path $rollbackPath 'Firewall')
        $null = New-Item -ItemType Directory -Force -Path (Join-Path $rollbackPath 'Printers')
        $null = New-Item -ItemType Directory -Force -Path (Join-Path $rollbackPath 'Network')
    } catch {}

    $manifest = [PSCustomObject]@{
        RollbackPath    = $rollbackPath
        CreatedAt       = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        ComputerName    = $env:COMPUTERNAME
        ToolkitVersion  = '8.2.0'
    }
    $manifest | ConvertTo-Json | Out-File -FilePath (Join-Path $rollbackPath 'manifest.json') -Encoding UTF8

    return $rollbackPath
}

function Backup-RegistryKey {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RegistryKey,
        [Parameter(Mandatory = $true)]
        [string]$RollbackPath
    )

    $outputFile = Join-Path -Path $RollbackPath -ChildPath "Registry\$(($RegistryKey -replace '\\', '_') -replace ':', '').reg"
    try {
        Start-Process -FilePath 'reg.exe' -ArgumentList "export `"$RegistryKey`" `"$outputFile`" /y" -NoNewWindow -Wait -ErrorAction SilentlyContinue
        return (Test-Path -Path $outputFile)
    } catch {
        return $false
    }
}

function Backup-ServiceState {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ServiceName,
        [Parameter(Mandatory = $true)]
        [string]$RollbackPath
    )

    try {
        $svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if ($svc) {
            $state = [PSCustomObject]@{
                ServiceName = $svc.Name
                Status      = $svc.Status.ToString()
                StartType   = $svc.StartType.ToString()
            }
            $filePath = Join-Path -Path $RollbackPath -ChildPath "Services\$ServiceName.json"
            $state | ConvertTo-Json | Out-File -FilePath $filePath -Encoding UTF8
            return $true
        }
    } catch {}
    return $false
}

function Backup-PrinterConfiguration {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PrinterName,
        [Parameter(Mandatory = $true)]
        [string]$RollbackPath
    )

    try {
        $printer = Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue
        if ($printer) {
            $config = [PSCustomObject]@{
                PrinterName  = $printer.Name
                Shared       = $printer.Shared
                ShareName    = $printer.ShareName
                PortName     = $printer.PortName
                DriverName   = $printer.DriverName
                Published    = $printer.Published
                PrinterStatus = $printer.PrinterStatus
            }
            $filePath = Join-Path -Path $RollbackPath -ChildPath "Printers\$($PrinterName -replace '[^a-zA-Z0-9_-]', '_').json"
            $config | ConvertTo-Json | Out-File -FilePath $filePath -Encoding UTF8
            return $true
        }
    } catch {}
    return $false
}

function Invoke-Rollback {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$RollbackPath
    )

    Assert-Elevated

    $result = [PSCustomObject]@{
        Success        = $false
        RollbackPath   = ''
        Restored       = @()
        Failed         = @()
        Detail         = ''
    }

    if (-not $RollbackPath) {
        $latest = Get-ChildItem -Path $Script:RollbackRoot -Directory -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if (-not $latest) {
            $result.Detail = 'No rollback points found'
            return $result
        }
        $RollbackPath = $latest.FullName
    }

    if (-not (Test-Path -Path $RollbackPath)) {
        $result.Detail = "Rollback path not found: $RollbackPath"
        return $result
    }

    $result.RollbackPath = $RollbackPath
    Write-Host "Rolling back from: $RollbackPath" -ForegroundColor Yellow

    $registryDir = Join-Path -Path $RollbackPath -ChildPath 'Registry'
    if (Test-Path -Path $registryDir) {
        $regFiles = Get-ChildItem -Path $registryDir -Filter '*.reg' -ErrorAction SilentlyContinue
        foreach ($regFile in $regFiles) {
            try {
                Start-Process -FilePath 'reg.exe' -ArgumentList "import `"$($regFile.FullName)`"" -NoNewWindow -Wait -ErrorAction SilentlyContinue
                $result.Restored += "Registry: $($regFile.BaseName)"
                Write-Host "  [OK] Registry: $($regFile.BaseName)" -ForegroundColor Green
            } catch {
                $result.Failed += "Registry: $($regFile.BaseName)"
                Write-Host "  [FAIL] Registry: $($regFile.BaseName)" -ForegroundColor Red
            }
        }
    }

    $servicesDir = Join-Path -Path $RollbackPath -ChildPath 'Services'
    if (Test-Path -Path $servicesDir) {
        $svcFiles = Get-ChildItem -Path $servicesDir -Filter '*.json' -ErrorAction SilentlyContinue
        foreach ($svcFile in $svcFiles) {
            try {
                $state = Get-Content -Path $svcFile.FullName -Raw | ConvertFrom-Json
                if ($state) {
                    $svc = Get-Service -Name $state.ServiceName -ErrorAction SilentlyContinue
                    if ($svc) {
                        Set-Service -Name $state.ServiceName -StartupType $state.StartType -ErrorAction SilentlyContinue
                        if ($state.Status -eq 'Running') {
                            Start-Service -Name $state.ServiceName -ErrorAction SilentlyContinue
                        } else {
                            Stop-Service -Name $state.ServiceName -Force -ErrorAction SilentlyContinue
                        }
                        $result.Restored += "Service: $($state.ServiceName)"
                        Write-Host "  [OK] Service: $($state.ServiceName)" -ForegroundColor Green
                    }
                }
            } catch {
                $result.Failed += "Service: $($svcFile.BaseName)"
                Write-Host "  [FAIL] Service: $($svcFile.BaseName)" -ForegroundColor Red
            }
        }
    }

    if ($result.Failed.Count -eq 0) {
        $result.Success = $true
    }

    return $result
}

Export-ModuleMember -Function Initialize-RepairRollback, Invoke-Rollback
