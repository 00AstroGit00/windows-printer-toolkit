<#
.SYNOPSIS
    Configuration intelligence engine for PrinterToolkit v6.0.

.DESCRIPTION
    Inspects Windows Features, Services, Registry, Firewall, and Network
    configuration. Compares expected vs actual states, detects mismatches,
    and provides structured results for the Repair Engine.

.NOTES
    Module: PrinterToolkit.Configuration
    Author: PrinterToolkit Contributors
#>

$Script:RegPrintRoot = 'HKLM:\SYSTEM\CurrentControlSet\Control\Print'
$Script:ExpectedFeatures = @{
    'Printing-PrintManagement-Console' = 'Print Management Console'
    'Printing-InternetPrinting-Client' = 'Internet Printing Client'
    'Printing-LPD-LPR-Server'          = 'LPD Print Server'
    'Printing-LPD-LPR-Client'          = 'LPD Print Client'
}

$Script:ExpectedServices = @{
    'Spooler'          = @{ Display = 'Print Spooler'; StartType = 'Automatic' }
    'LanmanServer'     = @{ Display = 'Server'; StartType = 'Automatic' }
    'LanmanWorkstation' = @{ Display = 'Workstation'; StartType = 'Automatic' }
    'FDResPub'         = @{ Display = 'Function Discovery Publication'; StartType = 'Automatic' }
    'FDPhost'          = @{ Display = 'Function Discovery Provider'; StartType = 'Automatic' }
    'RpcSs'            = @{ Display = 'Remote Procedure Call (RPC)'; StartType = 'Automatic' }
    'DcomLaunch'       = @{ Display = 'DCOM Server Process Launcher'; StartType = 'Automatic' }
    'DNSCache'         = @{ Display = 'DNS Client'; StartType = 'Automatic' }
    'SSDPSRV'          = @{ Display = 'SSDP Discovery'; StartType = 'Automatic' }
    'upnphost'         = @{ Display = 'UPnP Device Host'; StartType = 'Automatic' }
}

$Script:ExpectedRegistry = @{
    'HKLM:\SYSTEM\CurrentControlSet\Control\Print\RpcAuthnLevelPrivacyEnabled' = @{ Type = 'DWord'; Expected = 0 }
    'HKLM:\SYSTEM\CurrentControlSet\Control\Print\DisableHTTPPrinting'         = @{ Type = 'DWord'; Expected = 0 }
}

function Get-WindowsFeatureStatus {
    [CmdletBinding()]
    [OutputType([array])]
    param()

    $results = [System.Collections.ArrayList]::new()

    foreach ($feature in $Script:ExpectedFeatures.Keys) {
        $status = 'NotInstalled'
        $detail = ''

        try {
            $f = Get-WindowsOptionalFeature -Online -FeatureName $feature -ErrorAction SilentlyContinue
            if ($f) {
                $status = $f.State.ToString()
                $detail = "State=$($f.State)"
            } else {
                $psf = Get-WindowsFeature -Name $feature -ErrorAction SilentlyContinue
                if ($psf) {
                    $status = if ($psf.Installed) { 'Enabled' } else { 'Available' }
                    $detail = "Installed=$($psf.Installed)"
                }
            }
        } catch {
            $detail = $_.Exception.Message
        }

        $null = $results.Add([PSCustomObject]@{
            FeatureName     = $feature
            DisplayName     = $Script:ExpectedFeatures[$feature]
            Status          = $status
            Expected        = 'Enabled'
            Pass            = ($status -eq 'Enabled')
            Detail          = $detail
        })
    }

    return ,@($results)
}

function Set-WindowsFeature {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FeatureName,
        [Parameter(Mandatory = $true)]
        [switch]$Enable
    )

    Assert-Elevated

    $result = [PSCustomObject]@{
        FeatureName = $FeatureName
        Success     = $false
        Action      = if ($Enable) { 'Enable' } else { 'Disable' }
        Detail      = ''
    }

    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
        $isServer = ($os -and $os.ProductType -gt 1)

        if ($isServer) {
            $inst = if ($Enable) {
                Install-WindowsFeature -Name $FeatureName -IncludeManagementTools -ErrorAction Stop
            } else {
                Uninstall-WindowsFeature -Name $FeatureName -ErrorAction Stop
            }
            $result.Success = $inst.Success
            $result.Detail = "Success=$($inst.Success)"
        } else {
            if ($Enable) {
                $null = Enable-WindowsOptionalFeature -Online -FeatureName $FeatureName -All -LimitAccess -ErrorAction Stop
            } else {
                $null = Disable-WindowsOptionalFeature -Online -FeatureName $FeatureName -ErrorAction Stop
            }
            $result.Success = $true
            $result.Detail = "Feature $FeatureName $($Enable ? 'enabled' : 'disabled')"
        }
    } catch {
        $result.Detail = $_.Exception.Message
        Write-Log -Message "Set-WindowsFeature failed: $_" -Level 'ERROR'
    }

    return $result
}

function Get-ServiceStatus {
    [CmdletBinding()]
    [OutputType([array])]
    param()

    $results = [System.Collections.ArrayList]::new()

    foreach ($svcName in $Script:ExpectedServices.Keys) {
        $expected = $Script:ExpectedServices[$svcName]
        $status = 'NotFound'
        $startType = 'Unknown'
        $pass = $false

        try {
            $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
            if ($svc) {
                $status = $svc.Status.ToString()
                $startType = $svc.StartType.ToString()
                $pass = ($status -eq 'Running' -and $startType -eq 'Automatic')
            }
        } catch {}

        $null = $results.Add([PSCustomObject]@{
            ServiceName     = $svcName
            DisplayName     = $expected.Display
            Status          = $status
            StartType       = $startType
            ExpectedStartup = $expected.StartType
            ExpectedRunning = $true
            Pass            = $pass
        })
    }

    return ,@($results)
}

function Set-ServiceConfiguration {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ServiceName,
        [Parameter(Mandatory = $false)]
        [ValidateSet('Automatic', 'Manual', 'Disabled')]
        [string]$StartType,
        [Parameter(Mandatory = $false)]
        [switch]$EnsureRunning
    )

    Assert-Elevated

    $result = [PSCustomObject]@{
        ServiceName = $ServiceName
        StartType   = $StartType
        Running     = $false
        Success     = $false
        Detail      = ''
    }

    try {
        $svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if (-not $svc) {
            $result.Detail = 'Service not found'
            return $result
        }

        if ($StartType -and $svc.StartType.ToString() -ne $StartType) {
            Set-Service -Name $ServiceName -StartupType $StartType -ErrorAction Stop
        }

        if ($EnsureRunning -and $svc.Status -ne 'Running') {
            Start-Service -Name $ServiceName -ErrorAction Stop
            Start-Sleep -Milliseconds 500
            $svc.Refresh()
        }

        $result.Running = ($svc.Status -eq 'Running')
        $result.Success = $true
        $result.Detail = "StartType=$($svc.StartType), Status=$($svc.Status)"
    } catch {
        $result.Detail = $_.Exception.Message
        Write-Log -Message "Set-ServiceConfiguration failed: $_" -Level 'ERROR'
    }

    return $result
}

function Get-RegistryExpected {
    [CmdletBinding()]
    [OutputType([array])]
    param()

    $results = [System.Collections.ArrayList]::new()

    foreach ($regPath in $Script:ExpectedRegistry.Keys) {
        $config = $Script:ExpectedRegistry[$regPath]
        $actual = $null
        $exists = $false
        $pass = $false
        $detail = ''

        try {
            $pathSplit = $regPath -split '\\'
            $valueName = $pathSplit[-1]
            $keyPath = $pathSplit[0..($pathSplit.Count - 2)] -join '\'

            if (Test-Path -Path $keyPath -ErrorAction SilentlyContinue) {
                $val = Get-ItemProperty -Path $keyPath -Name $valueName -ErrorAction SilentlyContinue
                if ($null -ne $val) {
                    $exists = $true
                    $actual = $val.$valueName
                    $pass = ($actual -eq $config.Expected)
                    $detail = "Value=$actual, Expected=$($config.Expected)"
                } else {
                    $detail = 'Not set (default behavior)'
                    $pass = $true
                }
            } else {
                $detail = 'Key not found'
                $pass = $false
            }
        } catch {
            $detail = $_.Exception.Message
        }

        $null = $results.Add([PSCustomObject]@{
            RegistryPath = $regPath
            ValueName    = if ($regPath -match '\\([^\\]+)$') { $matches[1] } else { '(Default)' }
            Exists       = $exists
            ActualValue  = $actual
            ExpectedValue = $config.Expected
            Pass         = $pass
            Detail       = $detail
        })
    }

    return ,@($results)
}

function Compare-RegistryState {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $registryState = Get-RegistryExpected
    $passCount = @($registryState | Where-Object { $_.Pass }).Count
    $totalCount = $registryState.Count

    [PSCustomObject]@{
        RegistryChecks = $registryState
        PassCount      = $passCount
        TotalCount     = $totalCount
        AllPass        = ($passCount -eq $totalCount)
        Score          = if ($totalCount -gt 0) { [math]::Round(($passCount / $totalCount) * 100, 1) } else { 100 }
    }
}

Export-ModuleMember -Function Get-WindowsFeatureStatus, Set-WindowsFeature, Get-ServiceStatus, Set-ServiceConfiguration, Get-RegistryExpected, Compare-RegistryState
