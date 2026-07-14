<#
.SYNOPSIS
    SMB configuration and management for PrinterToolkit v6.0.

.DESCRIPTION
    Detects and configures SMB server settings for printer sharing.
    Manages SMB 1.0/CIFS, SMB 2/3 protocol versions, and SMB share
    optimization for printing workloads.

.NOTES
    Module: PrinterToolkit.SMB
    Author: PrinterToolkit Contributors
#>

function Get-SmbConfiguration {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $result = [PSCustomObject]@{
        Smb1Enabled           = $false
        Smb2Enabled           = $false
        ServerEnabled         = $false
        KeepAlive             = 0
        MaxSessions           = 0
        SmbShares             = @()
        Detail                = ''
    }

    try {
        $config = Get-SmbServerConfiguration -ErrorAction SilentlyContinue
        if ($config) {
            $result.ServerEnabled = $config.ServerEnabled
            $result.KeepAlive = $config.KeepAlive
            $result.MaxSessions = $config.MaxSessionsPerSmbConnection
        }
    } catch {
        $result.Detail = "Get-SmbServerConfiguration: $($_.Exception.Message)"
    }

    try {
        $smb1 = Get-WindowsOptionalFeature -Online -FeatureName 'SMB1Protocol' -ErrorAction SilentlyContinue
        if ($smb1) {
            $result.Smb1Enabled = ($smb1.State -eq 'Enabled')
        }
    } catch {}

    try {
        $smb2Reg = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters' -Name 'Smb2' -ErrorAction SilentlyContinue
        if ($smb2Reg) {
            $result.Smb2Enabled = ($smb2Reg.Smb2 -ne 0)
        }
    } catch {
        $result.Smb2Enabled = $true
    }

    try {
        $shares = Get-SmbShare -ErrorAction SilentlyContinue
        $result.SmbShares = @($shares | Select-Object Name, Path, Description, ShareType, CurrentUsers)
    } catch {}

    return $result
}

function Set-SmbConfiguration {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$Smb1Enabled,
        [Parameter(Mandatory = $false)]
        [switch]$Smb2Enabled
    )

    Assert-Elevated

    $result = [PSCustomObject]@{
        Smb1Changed = $false
        Smb2Changed = $false
        Success     = $false
        Detail      = ''
    }

    if ($PSBoundParameters.ContainsKey('Smb1Enabled')) {
        try {
            $current = Get-WindowsOptionalFeature -Online -FeatureName 'SMB1Protocol' -ErrorAction SilentlyContinue
            if ($current -and $current.State -ne $(if ($Smb1Enabled) { 'Enabled' } else { 'Disabled' })) {
                if ($Smb1Enabled) {
                    $null = Enable-WindowsOptionalFeature -Online -FeatureName 'SMB1Protocol' -All -LimitAccess -ErrorAction Stop
                } else {
                    $null = Disable-WindowsOptionalFeature -Online -FeatureName 'SMB1Protocol' -ErrorAction Stop
                }
                $result.Smb1Changed = $true
            }
        } catch {
            $result.Detail = "SMB1: $($_.Exception.Message)"
        }
    }

    if ($PSBoundParameters.ContainsKey('Smb2Enabled')) {
        try {
            $regPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'
            $current = Get-ItemProperty -Path $regPath -Name 'Smb2' -ErrorAction SilentlyContinue
            $currentVal = if ($current) { $current.Smb2 } else { 1 }

            $desired = if ($Smb2Enabled) { 1 } else { 0 }
            if ($currentVal -ne $desired) {
                Set-ItemProperty -Path $regPath -Name 'Smb2' -Value $desired -ErrorAction Stop
                $result.Smb2Changed = $true
            }
        } catch {
            $result.Detail += " SMB2: $($_.Exception.Message)"
        }
    }

    if ($result.Smb1Changed -or $result.Smb2Changed) {
        try {
            Restart-Service -Name LanmanServer -Force -ErrorAction SilentlyContinue
        } catch {}
    }

    $result.Success = (-not $result.Detail)
    return $result
}

function Get-SmbPrinterShares {
    [CmdletBinding()]
    [OutputType([array])]
    param()

    $results = [System.Collections.ArrayList]::new()
    $printers = @(Get-Printer -ErrorAction SilentlyContinue | Where-Object { $_.Shared })

    foreach ($p in $printers) {
        $shareName = if ($p.ShareName) { $p.ShareName } else { $p.Name -replace '[^a-zA-Z0-9_-]', '_' }

        try {
            $smbShare = Get-SmbShare -Name $shareName -ErrorAction SilentlyContinue
            $permissions = if ($smbShare) {
                Get-SmbShareAccess -Name $shareName -ErrorAction SilentlyContinue
            } else { @() }

            $null = $results.Add([PSCustomObject]@{
                PrinterName  = $p.Name
                ShareName    = $shareName
                SmbShareFound = ($null -ne $smbShare)
                SmbPath      = "\\$($env:COMPUTERNAME)\$shareName"
                Permissions  = @($permissions)
            })
        } catch {}
    }

    return ,@($results)
}

Export-ModuleMember -Function Get-SmbConfiguration, Set-SmbConfiguration, Get-SmbPrinterShares
