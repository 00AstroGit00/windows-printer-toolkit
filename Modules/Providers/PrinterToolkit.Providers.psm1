<#
.SYNOPSIS
    Native Windows Integration Layer (v8.1) - shared provider framework.

.DESCRIPTION
    Provides the standardized provider result / error model and native-API
    helpers that replace fragile shell-executable and string-parsing
    implementations across the toolkit. Every helper uses a supported
    Windows API surface (NetSecurity, PrintManagement, CIM/WMI, DISM) instead
    of netsh, rundll32, or pnputil text parsing.

    Provider result contract (used by all v8.1 providers):
      Status            : Success | Warning | Failed | Skipped | NotApplicable | Unsupported
      Success           : bool (true only when Status -eq 'Success')
      ErrorCode         : stable machine-readable code for diagnostics
      Category          : subsystem that produced the result (Firewall, Printer, Drivers, ...)
      RecommendedAction : operator guidance when Status -ne 'Success'
      Recoverability    : Auto | Manual | None
      Message           : human-readable detail
      Data              : provider-specific payload
      Timestamp         : when the result was produced

.NOTES
    Module: PrinterToolkit.Providers
    Version: 8.2.0
    Author: PrinterToolkit Contributors
#>

# ---------------------------------------------------------------------------
# Standardized provider result / error model
# ---------------------------------------------------------------------------

function New-ProviderResult {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('Success', 'Warning', 'Failed', 'Skipped', 'NotApplicable', 'Unsupported')]
        [string]$Status = 'Success',

        [Parameter(Mandatory = $false)]
        [string]$ErrorCode = '',

        [Parameter(Mandatory = $false)]
        [string]$Category = '',

        [Parameter(Mandatory = $false)]
        [string]$RecommendedAction = '',

        [Parameter(Mandatory = $false)]
        [ValidateSet('', 'Auto', 'Manual', 'None')]
        [string]$Recoverability = '',

        [Parameter(Mandatory = $false)]
        [string]$Message = '',

        [Parameter(Mandatory = $false)]
        $Data = $null
    )

    [PSCustomObject]@{
        Status             = $Status
        Success            = ($Status -eq 'Success')
        ErrorCode          = $ErrorCode
        Category           = $Category
        RecommendedAction  = $RecommendedAction
        Recoverability     = $Recoverability
        Message            = $Message
        Data               = $Data
        Timestamp          = Get-Date
    }
}

# ---------------------------------------------------------------------------
# Firewall: enable printing rule groups via NetSecurity (replaces netsh)
# ---------------------------------------------------------------------------

function Enable-PrinterFirewallRules {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$IncludeIpp
    )

    Assert-Elevated

    $groups = @('File and Printer Sharing', 'Network Discovery')
    $enabledGroups = [System.Collections.ArrayList]::new()

    try {
        foreach ($group in $groups) {
            $rules = Get-NetFirewallRule -DisplayGroup $group -ErrorAction SilentlyContinue
            if ($rules) {
                $rules | Enable-NetFirewallRule -ErrorAction SilentlyContinue
                $null = $enabledGroups.Add($group)
            }
        }

        if ($IncludeIpp) {
            $ipp = Get-NetFirewallRule -DisplayName 'IPP Printer Port 631' -ErrorAction SilentlyContinue
            if (-not $ipp) {
                $null = New-NetFirewallRule -DisplayName 'IPP Printer Port 631' -Direction Inbound -Protocol TCP -LocalPort 631 -Action Allow -Profile Any -ErrorAction Stop
            } elseif (-not $ipp.Enabled) {
                $ipp | Enable-NetFirewallRule -ErrorAction Stop
            }
        }

        return New-ProviderResult -Status Success -Category 'Firewall' -Message 'Printer firewall rules enabled.' -Data ([PSCustomObject]@{ EnabledGroups = @($enabledGroups); Ipp = [bool]$IncludeIpp })
    } catch {
        return New-ProviderResult -Status Failed -ErrorCode 'FW_ENABLE_FAILED' -Category 'Firewall' -RecommendedAction 'Verify the Windows Defender Firewall service is running and re-run as Administrator.' -Recoverability 'Manual' -Message $_.Exception.Message
    }
}

# ---------------------------------------------------------------------------
# Default printer: CIM Win32_Printer.SetDefaultPrinter (replaces rundll32)
# ---------------------------------------------------------------------------

function Set-DefaultPrinterNative {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    Assert-Elevated

    try {
        $printer = Get-CimInstance -ClassName Win32_Printer -Filter "Name = '$($Name -replace "'", "''")'" -ErrorAction Stop
        if (-not $printer) {
            return New-ProviderResult -Status Failed -ErrorCode 'PRINTER_NOT_FOUND' -Category 'Printer' -RecommendedAction "Verify the printer name '$Name' is installed." -Recoverability 'Manual' -Message "Printer '$Name' not found."
        }

        $null = Invoke-CimMethod -InputObject $printer -MethodName SetDefaultPrinter -ErrorAction Stop
        return New-ProviderResult -Status Success -Category 'Printer' -Message "Default printer set to '$Name'."
    } catch {
        return New-ProviderResult -Status Failed -ErrorCode 'DEFAULT_PRINTER_FAILED' -Category 'Printer' -RecommendedAction 'Confirm the printer is installed and the Print Spooler service is running.' -Recoverability 'Auto' -Message $_.Exception.Message
    }
}

# ---------------------------------------------------------------------------
# Driver store details: DISM Get-WindowsDriver (replaces pnputil parsing)
# ---------------------------------------------------------------------------

function Get-PrinterDriverStoreDetails {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Name = ''
    )

    try {
        $storeDrivers = @(Get-WindowsDriver -Online -ErrorAction Stop |
            Where-Object { $_.ClassName -eq 'Printer' })

        if ($Name) {
            $storeDrivers = @($storeDrivers | Where-Object { $_.Driver -eq $Name -or $_.OriginalFileName -like "*$Name*" })
        }

        $mapped = foreach ($d in $storeDrivers) {
            [PSCustomObject]@{
                DriverName   = $d.Driver
                InfPath      = $d.OriginalFileName
                ProviderName = $d.ProviderName
                Version      = $d.Version
                Date         = $d.Date
            }
        }

        return New-ProviderResult -Status Success -Category 'Drivers' -Message "Resolved $($mapped.Count) driver package(s)." -Data @($mapped)
    } catch {
        return New-ProviderResult -Status Failed -ErrorCode 'DRIVER_STORE_QUERY_FAILED' -Category 'Drivers' -RecommendedAction 'Ensure the DISM PowerShell module is available and run as Administrator.' -Recoverability 'Auto' -Message $_.Exception.Message
    }
}

Export-ModuleMember -Function New-ProviderResult, Enable-PrinterFirewallRules, Set-DefaultPrinterNative, Get-PrinterDriverStoreDetails
