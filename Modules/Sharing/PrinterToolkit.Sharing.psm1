<#
.SYNOPSIS
    Network printer sharing management for PrinterToolkit.

.DESCRIPTION
    Manages Windows printer sharing: enable/disable sharing, list shared
    printers, configure SMB settings, manage share permissions, and set
    transport protocols (SMB vs IPP).

.NOTES
    Module: PrinterToolkit.Sharing
    Author: PrinterToolkit Contributors
#>

function Get-PrinterShareStatus {
    [CmdletBinding()]
    [OutputType([array])]

    $printers = @(Get-Printer -ErrorAction SilentlyContinue)
    $results = foreach ($p in $printers) {
        $driver = Get-PrinterDriver -Name $p.DriverName -ErrorAction SilentlyContinue
        $isIPP = if ($p.PortName -match '^(http|ipp|wsd|wsdprint)') { $true } else { $false }

        [PSCustomObject]@{
            Name                    = $p.Name
            Shared                  = $p.Shared
            ShareName               = $p.ShareName
            PortName                = $p.PortName
            DriverName              = $p.DriverName
            DriverType              = if ($driver -and $driver.MajorVersion -ge 4) { 'Type 4' } else { 'Type 3' }
            Published               = $p.Published
            IsIPP                   = $isIPP
            PrinterStatus           = $p.PrinterStatus
            Location                = $p.Location
            Comment                 = $p.Comment
        }
    }

    return ,$results
}

function Enable-PrinterSharing {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$PrinterName,
        [Parameter(Mandatory = $false)]
        [string]$ShareName,
        [Parameter(Mandatory = $false)]
        [switch]$PublishInAD
    )

    begin { Assert-Elevated }

    process {
        $result = [PSCustomObject]@{ PrinterName = $PrinterName; Success = $false; Error = '' }

        try {
            if (-not (Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue)) {
                $result.Error = 'Printer not found'
                return $result
            }

            $params = @{ Name = $PrinterName; Shared = $true }
            if ($ShareName) { $params.ShareName = $ShareName }
            if ($PublishInAD) { $params.Published = $true }

            Set-Printer @params -ErrorAction Stop
            $result.Success = $true
        } catch {
            $result.Error = $_.ToString()
        }

        return $result
    }
}

function Disable-PrinterSharing {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$PrinterName
    )

    begin { Assert-Elevated }

    process {
        $result = [PSCustomObject]@{ PrinterName = $PrinterName; Success = $false; Error = '' }

        try {
            if (-not (Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue)) {
                $result.Error = 'Printer not found'
                return $result
            }

            Set-Printer -Name $PrinterName -Shared $false -ErrorAction Stop
            $result.Success = $true
        } catch {
            $result.Error = $_.ToString()
        }

        return $result
    }
}

function Get-SmbSharePermissions {
    [CmdletBinding()]
    [OutputType([array])]

    $shares = @(Get-SmbShare -ErrorAction SilentlyContinue | Where-Object { $_.ShareType -eq 0 })
    $results = foreach ($s in $shares) {
        $perms = @(Get-SmbShareAccess -Name $s.Name -ErrorAction SilentlyContinue)
        [PSCustomObject]@{
            ShareName      = $s.Name
            Path           = $s.Path
            Description    = $s.Description
            CurrentUsers   = $s.CurrentUsers
            Permissions    = $perms
        }
    }

    return ,$results
}

function Set-PrinterSharePermission {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ShareName,
        [Parameter(Mandatory = $true)]
        [string]$AccountName,
        [Parameter(Mandatory = $true)]
        [ValidateSet('Read', 'Change', 'FullControl')]
        [string]$AccessRight,
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    Assert-Elevated

    $result = [PSCustomObject]@{ ShareName = $ShareName; Account = $AccountName; Success = $false; Error = '' }

    try {
        $existing = Get-SmbShareAccess -Name $ShareName -ErrorAction SilentlyContinue | Where-Object { $_.AccountName -eq $AccountName }
        if ($existing -and -not $Force) {
            $result.Error = "Account already has permissions. Use -Force to overwrite."
            return $result
        }

        if ($existing -and $Force) {
            Revoke-SmbShareAccess -Name $ShareName -AccountName $AccountName -Force -ErrorAction Stop
        }

        Grant-SmbShareAccess -Name $ShareName -AccountName $AccountName -AccessRight $AccessRight -Force -ErrorAction Stop
        $result.Success = $true
    } catch {
        $result.Error = $_.ToString()
    }

    return $result
}

function Set-PrinterSharingTransport {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PrinterName,
        [Parameter(Mandatory = $true)]
        [ValidateSet('SMB', 'IPP', 'WSD')]
        [string]$Transport
    )

    Assert-Elevated

    $result = [PSCustomObject]@{ PrinterName = $PrinterName; Transport = $Transport; Success = $false; Error = '' }

    try {
        $printer = Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue
        if (-not $printer) {
            $result.Error = 'Printer not found'
            return $result
        }

        $newPort = switch ($Transport) {
            'IPP' { "ipp://$($env:COMPUTERNAME):631/printers/$($printer.ShareName)" }
            'WSD' { "wsdprint://$($env:COMPUTERNAME)/$($printer.ShareName)" }
            'SMB' { "\\$($env:COMPUTERNAME)\$($printer.ShareName)" }
        }

        $port = Get-PrinterPort -Name $newPort -ErrorAction SilentlyContinue
        if (-not $port) {
            Add-PrinterPort -Name $newPort -ErrorAction Stop
        }

        Set-Printer -Name $PrinterName -PortName $newPort -ErrorAction Stop
        $result.Success = $true
    } catch {
        $result.Error = $_.ToString()
    }

    return $result
}

function Get-PrinterSharingCompatibility {
    [CmdletBinding()]
    [OutputType([array])]

    $printers = Get-PrinterShareStatus
    $results = foreach ($p in $printers) {
        $warnings = @()

        if ($p.Shared -and $p.DriverType -eq 'Type 3') {
            $warnings += 'Type 3 driver may cause issues with newer Windows 10/11 clients.'
        }
        if ($p.Shared -and -not $p.ShareName) {
            $warnings += 'Share name is empty. Sharing may not function correctly.'
        }
        if ($p.Shared -and -not $p.Published) {
            $warnings += 'Not published in Active Directory. Clients must browse by computer name.'
        }

        [PSCustomObject]@{
            PrinterName = $p.Name
            Shared      = $p.Shared
            Warnings    = $warnings
        }
    }

    return ,$results
}

Export-ModuleMember -Function Get-PrinterShareStatus, Enable-PrinterSharing, Disable-PrinterSharing, Get-SmbSharePermissions, Set-PrinterSharePermission, Set-PrinterSharingTransport, Get-PrinterSharingCompatibility
