<#
.SYNOPSIS
    Network profile and firewall management for PrinterToolkit v6.0.

.DESCRIPTION
    Manages Windows network profiles, firewall rules for printing,
    network discovery, and connectivity validation. Provides structured
    detection, configuration, and validation of all network-related
    components required for print server operation.

.NOTES
    Module: PrinterToolkit.Networking
    Author: PrinterToolkit Contributors
#>

function Get-NetworkProfileStatus {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $result = [PSCustomObject]@{
        NetworkProfiles = @()
        IsPrivate       = $false
        DefaultProfile  = $null
        IPv4Addresses   = @()
        IPv6Addresses   = @()
        DNSServers      = @()
        DefaultGateway  = $null
        Detail          = ''
    }

    try {
        $profiles = Get-NetConnectionProfile -ErrorAction SilentlyContinue
        $result.NetworkProfiles = @($profiles)
        $result.IsPrivate = ($profiles | Where-Object { $_.NetworkCategory -eq 'Private' }).Count -gt 0
        $result.DefaultProfile = $profiles | Select-Object -First 1
    } catch {
        $result.Detail = $_.Exception.Message
    }

    try {
        $ipv4 = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object { $_.InterfaceAlias -notmatch 'Loopback|Teredo|isatap' }
        $result.IPv4Addresses = @($ipv4 | Select-Object -ExpandProperty IPAddress)

        $ipv6 = Get-NetIPAddress -AddressFamily IPv6 -ErrorAction SilentlyContinue |
            Where-Object { $_.InterfaceAlias -notmatch 'Loopback|Teredo|isatap' -and $_.AddressState -eq 'Preferred' }
        $result.IPv6Addresses = @($ipv6 | Select-Object -ExpandProperty IPAddress)
    } catch {}

    try {
        $routes = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue
        if ($routes) {
            $result.DefaultGateway = $routes | Select-Object -First 1 -ExpandProperty NextHop
        }
    } catch {}

    try {
        $dns = Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object { $_.InterfaceAlias -notmatch 'Loopback' }
        $result.DNSServers = @($dns | Select-Object -ExpandProperty ServerAddresses)
    } catch {}

    return $result
}

function Set-NetworkProfilePrivate {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [int]$InterfaceIndex
    )

    Assert-Elevated

    $result = [PSCustomObject]@{
        Success        = $false
        InterfaceName  = ''
        PreviousCategory = ''
        Detail         = ''
    }

    try {
        if ($InterfaceIndex -gt 0) {
            $profile = Get-NetConnectionProfile -InterfaceIndex $InterfaceIndex -ErrorAction SilentlyContinue
        } else {
            $profile = Get-NetConnectionProfile -ErrorAction SilentlyContinue | Select-Object -First 1
        }

        if (-not $profile) {
            $result.Detail = 'No network profile found'
            return $result
        }

        $result.InterfaceName = $profile.InterfaceAlias
        $result.PreviousCategory = $profile.NetworkCategory.ToString()

        if ($profile.NetworkCategory -ne 'Private') {
            Set-NetConnectionProfile -InterfaceIndex $profile.InterfaceIndex -NetworkCategory Private -ErrorAction Stop
            $result.Success = $true
            $result.Detail = "Changed from $($result.PreviousCategory) to Private"
        } else {
            $result.Success = $true
            $result.Detail = 'Already Private'
        }
    } catch {
        $result.Detail = $_.Exception.Message
        Write-Log -Message "Set-NetworkProfilePrivate failed: $_" -Level 'ERROR'
    }

    return $result
}

function Get-FirewallRuleStatus {
    [CmdletBinding()]
    [OutputType([array])]
    param()

    $requiredRules = @{
        'File and Printer Sharing' = 'File and Printer Sharing (all profiles)'
        'Network Discovery'        = 'Network Discovery (all profiles)'
    }

    $results = [System.Collections.ArrayList]::new()

    foreach ($group in $requiredRules.Keys) {
        try {
            $rules = Get-NetFirewallRule -DisplayGroup $group -ErrorAction SilentlyContinue
            $enabled = @($rules | Where-Object { $_.Enabled }).Count -gt 0
            $null = $results.Add([PSCustomObject]@{
                RuleGroup    = $group
                Description  = $requiredRules[$group]
                RulesFound   = @($rules).Count
                RulesEnabled = @($rules | Where-Object { $_.Enabled }).Count
                IsEnabled    = $enabled
                Pass         = $enabled
            })
        } catch {
            $null = $results.Add([PSCustomObject]@{
                RuleGroup    = $group
                Description  = $requiredRules[$group]
                RulesFound   = 0
                RulesEnabled = 0
                IsEnabled    = $false
                Pass         = $false
            })
        }
    }

    try {
        $ippRule = Get-NetFirewallRule -DisplayName 'IPP Printer Port 631' -ErrorAction SilentlyContinue
        $ippEnabled = $ippRule -and $ippRule.Enabled
        $null = $results.Add([PSCustomObject]@{
            RuleGroup    = 'IPP Port 631'
            Description  = 'Internet Printing Protocol TCP/631'
            RulesFound   = if ($ippRule) { 1 } else { 0 }
            RulesEnabled = if ($ippEnabled) { 1 } else { 0 }
            IsEnabled    = $ippEnabled
            Pass         = $ippEnabled
        })
    } catch {
        $null = $results.Add([PSCustomObject]@{
            RuleGroup    = 'IPP Port 631'
            Description  = 'Internet Printing Protocol TCP/631'
            RulesFound   = 0
            RulesEnabled = 0
            IsEnabled    = $false
            Pass         = $false
        })
    }

    try {
        $wsdRule = Get-NetFirewallRule -DisplayGroup 'Function Discovery' -ErrorAction SilentlyContinue
        $wsdEnabled = @($wsdRule | Where-Object { $_.Enabled }).Count -gt 0
        $null = $results.Add([PSCustomObject]@{
            RuleGroup    = 'Function Discovery (WSD)'
            Description  = 'Web Services Discovery'
            RulesFound   = if ($wsdRule) { @($wsdRule).Count } else { 0 }
            RulesEnabled = if ($wsdEnabled) { @($wsdRule | Where-Object { $_.Enabled }).Count } else { 0 }
            IsEnabled    = $wsdEnabled
            Pass         = $wsdEnabled
        })
    } catch {}

    return ,@($results)
}

function Set-FirewallRule {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RuleName,
        [Parameter(Mandatory = $true)]
        [ValidateSet('Allow', 'Block')]
        [string]$Action,
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    Assert-Elevated

    $result = [PSCustomObject]@{
        RuleName = $RuleName
        Action   = $Action
        Success  = $false
        Detail   = ''
    }

    try {
        $existing = Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue
        if ($existing) {
            $existing | Where-Object { $_.Direction -eq 'Inbound' } | Set-NetFirewallRule -Action $Action -ErrorAction Stop
        } else {
            if ($RuleName -eq 'IPP Printer Port 631') {
                New-NetFirewallRule -DisplayName $RuleName -Direction Inbound -Protocol TCP -LocalPort 631 -Action $Action -Profile Any -ErrorAction Stop
            } else {
                $result.Detail = "Rule '$RuleName' not found. Use a standard rule name or create manually."
                return $result
            }
        }
        $result.Success = $true
        $result.Detail = "Rule '$RuleName' set to $Action"
    } catch {
        $result.Detail = $_.Exception.Message
        Write-Log -Message "Set-FirewallRule failed: $_" -Level 'ERROR'
    }

    return $result
}

function Enable-RequiredFirewallRules {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $results = [System.Collections.ArrayList]::new()

    $fwResult = Enable-PrinterFirewallRules -IncludeIpp
    $enabledGroups = if ($fwResult.Data -and $fwResult.Data.EnabledGroups) { $fwResult.Data.EnabledGroups } else { @() }

    if ('File and Printer Sharing' -in $enabledGroups) {
        $null = $results.Add([PSCustomObject]@{ Rule = 'File and Printer Sharing'; Success = $true })
    } else {
        $null = $results.Add([PSCustomObject]@{ Rule = 'File and Printer Sharing'; Success = $false })
    }

    if ('Network Discovery' -in $enabledGroups) {
        $null = $results.Add([PSCustomObject]@{ Rule = 'Network Discovery'; Success = $true })
    } else {
        $null = $results.Add([PSCustomObject]@{ Rule = 'Network Discovery'; Success = $false })
    }

    $ippRule = Get-NetFirewallRule -DisplayName 'IPP Printer Port 631' -ErrorAction SilentlyContinue
    $null = $results.Add([PSCustomObject]@{ Rule = 'IPP Port 631'; Success = [bool]($ippRule -and $ippRule.Enabled) })

    [PSCustomObject]@{
        AllSuccess = $fwResult.Success -and ($ippRule -and $ippRule.Enabled)
        Results    = @($results)
    }
}

Export-ModuleMember -Function Get-NetworkProfileStatus, Set-NetworkProfilePrivate, Get-FirewallRuleStatus, Set-FirewallRule, Enable-RequiredFirewallRules
