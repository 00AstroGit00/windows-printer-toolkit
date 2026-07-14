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

    if (-not (Test-Path -Path $Script:SpoolPath -ErrorAction SilentlyContinue)) {
        return 0
    }

    $before = @(Get-ChildItem -Path $Script:SpoolPath -File -ErrorAction SilentlyContinue).Count
    Remove-Item -Path "$Script:SpoolPath\*" -Force -ErrorAction SilentlyContinue
    $after = @(Get-ChildItem -Path $Script:SpoolPath -File -ErrorAction SilentlyContinue).Count

    return ($before - $after)
}

function Restart-Spooler {
    [CmdletBinding()]
    [OutputType([bool])]
    $null = Stop-Spooler -Force
    Start-Sleep -Milliseconds 1000
    return (Start-Spooler)
}

function Get-Printers {
    [CmdletBinding()]
    [OutputType([array])]
    return @(Get-Printer -ErrorAction SilentlyContinue)
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

    try {
        $null = Start-Process -FilePath 'rundll32.exe' -ArgumentList 'PRINTUI.DLL,PrintUIEntry', '/y', '/n', "`"$Name`"" -NoNewWindow -Wait -PassThru
        $result = ($LASTEXITCODE -eq 0)
        if (-not $result) {
            Write-Log -Message "Failed to set default printer: $Name (exit: $LASTEXITCODE)" -Level 'WARN'
        }
        return $result
    } catch {
        Write-Log -Message "Exception setting default printer: $_" -Level 'ERROR'
        return $false
    }
}

function Get-PrinterQueueHealth {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$PrinterName = '*'
    )

    [PSCustomObject]@{
        PrinterName  = $PrinterName
        JobCount     = 0
        HasErrors    = $false
        ErrorMessage = ''
    }
}

function Get-SharedPrinters {
    [CmdletBinding()]
    [OutputType([array])]
    return @(Get-Printer -ErrorAction SilentlyContinue | Where-Object { $_.Shared })
}

function Enable-PrintSharing {
    [CmdletBinding()]
    [OutputType([bool])]
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

Export-ModuleMember -Function Get-PrinterStatus, Stop-Spooler, Start-Spooler, Clear-PrintQueue, Restart-Spooler, Get-Printers, Set-DefaultPrinter, Get-PrinterQueueHealth, Get-SharedPrinters, Enable-PrintSharing
