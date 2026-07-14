<#
.SYNOPSIS
    Core spooler and printer management for PrinterToolkit.

.DESCRIPTION
    Provides spooler start/stop, queue management, printer enumeration,
    default printer control, and sharing service management.

.NOTES
    Module: PrinterToolkit.Core
    Author: PrinterToolkit Contributors
#>

$Script:SpoolPath = "$env:windir\System32\spool\PRINTERS"
$Script:RegPrintRoot = 'HKLM:\SYSTEM\CurrentControlSet\Control\Print'

function Get-PrinterStatus {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()
    $svc = Get-Service -Name Spooler -ErrorAction SilentlyContinue
    $printers = @(Get-Printer -ErrorAction SilentlyContinue)

    $queueCount = 0
    if (Test-Path -Path $Script:SpoolPath -ErrorAction SilentlyContinue) {
        $queueCount = @(Get-ChildItem -Path $Script:SpoolPath -File -ErrorAction SilentlyContinue).Count
    }

    [PSCustomObject]@{
        SpoolerStatus    = if ($svc) { $svc.Status.ToString() } else { 'NotFound' }
        SpoolerStartType = if ($svc) { $svc.StartType.ToString() } else { 'Unknown' }
        PrinterCount     = $printers.Count
        QueueCount       = $queueCount
        Printers         = $printers
        Timestamp        = Get-Date
    }
}

function Stop-Spooler {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    Assert-Elevated

    try {
        $svc = Get-Service -Name Spooler -ErrorAction Stop
        if ($svc.Status -eq 'Stopped') {
            return $true
        }

        Stop-Service -Name Spooler -Force:$Force -ErrorAction Stop
        $svc.Refresh()

        if ($svc.Status -eq 'Stopped') {
            return $true
        }

        Start-Sleep -Milliseconds 1500
        $svc.Refresh()
        return ($svc.Status -eq 'Stopped')
    } catch {
        Write-Log -Message "Failed to stop spooler: $_" -Level 'ERROR'
        return $false
    }
}

function Start-Spooler {
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    Assert-Elevated

    try {
        $svc = Get-Service -Name Spooler -ErrorAction Stop
        if ($svc.Status -eq 'Running') {
            return $true
        }

        Start-Service -Name Spooler -ErrorAction Stop
        Start-Sleep -Milliseconds 1500
        $svc.Refresh()

        if ($svc.Status -eq 'Running') {
            return $true
        }

        Start-Sleep -Milliseconds 3000
        $svc.Refresh()
        return ($svc.Status -eq 'Running')
    } catch {
        Write-Log -Message "Failed to start spooler: $_" -Level 'ERROR'
        return $false
    }
}

function Clear-PrintQueue {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    Assert-Elevated

    if (-not (Test-Path -Path $Script:SpoolPath -ErrorAction SilentlyContinue)) {
        return 0
    }

    if (-not $Force -and -not (Confirm-DestructiveAction -Message 'Clear all pending print jobs?' -Prompt 'Clear print queue')) {
        return -1
    }

    $before = @(Get-ChildItem -Path $Script:SpoolPath -File -ErrorAction SilentlyContinue).Count
    Remove-Item -Path "$Script:SpoolPath\*" -Force -ErrorAction SilentlyContinue
    $after = @(Get-ChildItem -Path $Script:SpoolPath -File -ErrorAction SilentlyContinue).Count

    return ($before - $after)
}

function Restart-Spooler {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()
    Assert-Elevated

    $stopped = Stop-Spooler -Force
    Start-Sleep -Milliseconds 1000
    $started = Start-Spooler

    [PSCustomObject]@{
        Success      = ($stopped -and $started)
        Stopped      = $stopped
        Started      = $started
        Timestamp    = Get-Date
    }
}

function Get-Printers {
    [CmdletBinding()]
    [OutputType([array])]
    param()
    try {
        return ,@(Get-Printer -ErrorAction SilentlyContinue)
    } catch {
        return ,@()
    }
}

function Set-DefaultPrinter {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^[a-zA-Z0-9 _\-.()]+$')]
        [string]$Name
    )

    Assert-Elevated

    $native = Set-DefaultPrinterNative -Name $Name
    if (-not $native.Success) {
        Write-Log -Message "Failed to set default printer: $Name - $($native.Message)" -Level 'WARN'
    }
    return $native.Success
}

function Get-PrinterQueueHealth {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$PrinterName = '*'
    )

    $jobs = @()
    $jobCount = 0
    $hasErrors = $false
    $errorMsg = ''

    try {
        if ($PrinterName -and $PrinterName -ne '*') {
            $jobs = @(Get-PrintJob -Name $PrinterName -ErrorAction SilentlyContinue)
        } else {
            $printers = Get-Printer -ErrorAction SilentlyContinue
            foreach ($p in $printers) {
                $jobs += @(Get-PrintJob -Name $p.Name -ErrorAction SilentlyContinue)
            }
        }
        $jobCount = $jobs.Count
        $hasErrors = ($jobs | Where-Object { $_.JobStatus -match 'Error|Offline' }).Count -gt 0
    } catch {
        $errorMsg = $_.Exception.Message
    }

    [PSCustomObject]@{
        PrinterName  = $PrinterName
        JobCount     = $jobCount
        HasErrors    = $hasErrors
        ErrorMessage = $errorMsg
    }
}

function Get-SharedPrinters {
    [CmdletBinding()]
    [OutputType([array])]
    param()
    return @(Get-Printer -ErrorAction SilentlyContinue | Where-Object { $_.Shared })
}

function Enable-PrintSharing {
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    Assert-Elevated

    try {
        $svc = Get-Service -Name LanmanServer -ErrorAction Stop
        if ($svc.Status -ne 'Running') {
            Start-Service -Name LanmanServer -ErrorAction Stop
        }
        Set-Service -Name LanmanServer -StartupType Automatic -ErrorAction SilentlyContinue
        Set-Service -Name FDResPub -StartupType Automatic -ErrorAction SilentlyContinue

        $fd = Get-Service -Name FDResPub -ErrorAction SilentlyContinue
        if ($fd -and $fd.Status -ne 'Running') {
            Start-Service -Name FDResPub -ErrorAction SilentlyContinue
        }
        return $true
    } catch {
        Write-Log -Message "Enable-PrintSharing failed: $_" -Level 'WARN'
        return $false
    }
}

function Get-PrinterWmiDetail {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$PrinterName
    )

    try {
        $filter = if ($PrinterName) { "Name = '$($PrinterName -replace "'", "''")'" } else { '' }
        $printer = Get-CimInstance -ClassName Win32_Printer -Filter $filter -ErrorAction SilentlyContinue |
            Select-Object -First 1

        if (-not $printer) { return $null }

        [PSCustomObject]@{
            Name            = $printer.Name
            PrinterStatus   = $printer.PrinterStatus
            Status          = $printer.Status
            IsDefault       = $printer.Default
            IsShared        = $printer.Shared
            ShareName       = $printer.ShareName
            PortName        = $printer.PortName
            DriverName      = $printer.DriverName
            Location        = $printer.Location
            Comment         = $printer.Comment
            PNPDeviceID     = $printer.PNPDeviceID
            PrintProcessor  = $printer.PrintProcessor
            Published       = $printer.Published
            RawStatus       = $printer.StatusInfo
        }
    } catch {
        return $null
    }
}

Export-ModuleMember -Function Get-PrinterStatus, Stop-Spooler, Start-Spooler, Clear-PrintQueue, Restart-Spooler, Get-Printers, Set-DefaultPrinter, Get-PrinterQueueHealth, Get-SharedPrinters, Enable-PrintSharing, Get-PrinterWmiDetail
