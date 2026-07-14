<#
.SYNOPSIS
    Shared utility functions for PrinterToolkit.

.DESCRIPTION
    Provides administrator detection, system information, input helpers,
    and UI formatting for the PrinterToolkit suite.

.NOTES
    Module: PrinterToolkit.Utilities
    Author: PrinterToolkit Contributors
#>

function Test-Administrator {
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    try {
        $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        return $false
    }
}

function Test-Elevated {
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    return (Test-Administrator)
}

function Assert-Elevated {
    [CmdletBinding()]
    [OutputType([void])]
    param()
    if (-not (Test-Administrator)) {
        throw 'Administrator privileges required. Right-click and select "Run as Administrator".'
    }
}

function Confirm-DestructiveAction {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [string]$Prompt = 'Are you sure?',

        [Parameter(Mandatory = $false)]
        [switch]$RequireExact
    )

    Write-Host ''
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow

    if ($RequireExact) {
        $response = Read-Host 'Type YES to confirm'
        return ($response -eq 'YES')
    }

    $response = Read-Host "$Prompt (y/N)"
    return ($response -eq 'y' -or $response -eq 'Y')
}

function Get-SystemInfo {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()
    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
    $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue

    $ipAddresses = @()
    try {
        $ipAddresses = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object { $_.InterfaceAlias -notmatch 'Loopback|Teredo|isatap' } |
            Select-Object -ExpandProperty IPAddress
    } catch {
        $ipAddresses = @()
    }

    $sharedPrinters = @()
    try {
        $sharedPrinters = Get-Printer -ErrorAction SilentlyContinue |
            Where-Object { $_.Shared } |
            Select-Object Name, ShareName, DriverName, PortName
    } catch {
        $sharedPrinters = @()
    }

    [PSCustomObject]@{
        ComputerName       = $env:COMPUTERNAME
        OSName             = if ($os) { $os.Caption } else { 'Unknown' }
        OSVersion          = if ($os) { $os.Version } else { 'Unknown' }
        OSBuild            = if ($os) { $os.BuildNumber } else { 'Unknown' }
        OSArchitecture     = if ($os) { $os.OSArchitecture } else { 'Unknown' }
        Manufacturer       = if ($cs) { $cs.Manufacturer } else { 'Unknown' }
        Model              = if ($cs) { $cs.Model } else { 'Unknown' }
        TotalRAM           = if ($cs) { [math]::Round($cs.TotalPhysicalMemory / 1GB, 2) } else { 0 }
        PowerShellVersion  = $PSVersionTable.PSVersion.ToString()
        ExecutionPolicy    = (Get-ExecutionPolicy).ToString()
        IsAdmin            = Test-Administrator
        IPv4Addresses      = ($ipAddresses) -join ', '
        SharedPrinters     = @($sharedPrinters)
        Timestamp          = Get-Date
        ToolkitVersion     = '5.0.1'
    }
}

function Write-MenuHeader {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Title,

        [Parameter(Mandatory = $false)]
        [string]$Subtitle = ''
    )

    try { Clear-Host } catch { }
    $line = '=' * 74
    Write-Host $line -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor White
    if ($Subtitle) {
        Write-Host "  $Subtitle" -ForegroundColor DarkGray
    }
    Write-Host $line -ForegroundColor Cyan
    Write-Host ''
}

function Wait-Menu {
    [CmdletBinding()]
    [OutputType([void])]
    param()
    Write-Host ''
    Write-Host 'Press any key to continue...' -ForegroundColor DarkGray
    try { $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown') } catch { }
}

Export-ModuleMember -Function Test-Administrator, Test-Elevated, Assert-Elevated, Confirm-DestructiveAction, Get-SystemInfo, Write-MenuHeader, Wait-Menu
