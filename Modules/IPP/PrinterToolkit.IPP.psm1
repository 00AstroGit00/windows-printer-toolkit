<#
.SYNOPSIS
    Internet Printing Protocol (IPP) detection and management for PrinterToolkit.

.DESCRIPTION
    Detects IIS Internet Printing Server, IPP Client, Print Management Console,
    LPD/LPR features, generates IPP URLs, and validates endpoints.

.NOTES
    Module: PrinterToolkit.IPP
    Author: PrinterToolkit Contributors
#>

function Get-IPPStatus {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]

    $result = [PSCustomObject]@{
        IISInstalled               = $false
        PrintServerIIS             = $false
        IPPClientInstalled         = $false
        PrintManagementInstalled   = $false
        LPDServerInstalled         = $false
        LPDClientInstalled         = $false
        PrintServerRole            = $false
        IPPUrls                    = @()
    }

    # IIS check
    try {
        $iis = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\InetStp' -Name 'MajorVersion' -ErrorAction SilentlyContinue
        $result.IISInstalled = ($null -ne $iis)
    } catch {}

    # Windows features
    $featureMap = @{
        'Printing-InternetPrinting-Server'  = 'PrintServerIIS'
        'Printing-InternetPrinting-Client'  = 'IPPClientInstalled'
        'Printing-PrintManagement-Console'  = 'PrintManagementInstalled'
        'Printing-LPD-LPR-Server'           = 'LPDServerInstalled'
        'Printing-LPD-LPR-Client'           = 'LPDClientInstalled'
    }

    foreach ($featureName in $featureMap.Keys) {
        try {
            $feature = Get-WindowsOptionalFeature -Online -FeatureName $featureName -ErrorAction SilentlyContinue
            if ($feature) {
                $propName = $featureMap[$featureName]
                $result.$propName = ($feature.State -eq 'Enabled')
            }
        } catch {}
    }

    # Print Server role (Server OS)
    try {
        $psr = Get-WindowsFeature -Name 'Print-Server' -ErrorAction SilentlyContinue
        if ($psr) {
            $result.PrintServerRole = $psr.Installed
        }
    } catch {}

    $result.IPPUrls = Get-IPPUrls
    return $result
}

function Get-IPPUrls {
    [CmdletBinding()]
    [OutputType([array])]

    $hostname = $env:COMPUTERNAME

    $ipv4 = @()
    try {
        $ipv4 = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object { $_.InterfaceAlias -notmatch 'Loopback|Teredo|isatap' } |
            Select-Object -ExpandProperty IPAddress
    } catch {}

    $sharedPrinters = @(Get-Printer -ErrorAction SilentlyContinue | Where-Object { $_.Shared })

    $urls = foreach ($p in $sharedPrinters) {
        $shareName = if ($p.ShareName) { $p.ShareName } else { $p.Name -replace '[^a-zA-Z0-9_-]', '_' }

        $ippByIp = foreach ($ip in $ipv4) { "ipp://$ip/printers/$shareName" }
        $httpByIp = foreach ($ip in $ipv4) { "http://$ip`:$631/printers/$shareName" }

        [PSCustomObject]@{
            PrinterName     = $p.Name
            ShareName       = $shareName
            IPP_Hostname    = "ipp://$hostname/printers/$shareName"
            IPP_IPv4        = @($ippByIp)
            HTTP_Hostname   = "http://$hostname`:631/printers/$shareName"
            HTTP_IPv4       = @($httpByIp)
            HTTPS_Available = $false
            SMBPath         = "\\$hostname\$shareName"
        }
    }

    if ($urls.Count -eq 0) {
        $urls = @([PSCustomObject]@{
            PrinterName = '(no shared printers)'
            ShareName   = ''
            IPP_Hostname = ''
            IPP_IPv4    = @()
            HTTP_Hostname = ''
            HTTP_IPv4   = @()
            HTTPS_Available = $false
            SMBPath     = ''
        })
    }

    return ,$urls
}

function Test-IPPEndpoint {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Url,

        [Parameter(Mandatory = $false)]
        [ValidateRange(100, 30000)]
        [int]$TimeoutMs = 3000
    )

    $result = [PSCustomObject]@{
        Url            = $Url
        Reachable      = $false
        StatusCode     = 0
        ResponseTimeMs = 0
        Error          = ''
    }

    try {
        $uri = [System.Uri]::new($Url)
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $req = [System.Net.HttpWebRequest]::Create($uri)
        $req.Timeout = $TimeoutMs
        $req.Method = 'GET'

        $resp = $req.GetResponse()
        $sw.Stop()

        $result.StatusCode = [int]$resp.StatusCode
        $result.ResponseTimeMs = [math]::Round($sw.Elapsed.TotalMilliseconds, 0)
        $result.Reachable = $true
        $resp.Close()
    } catch {
        $result.Error = if ($_.Exception.Message) { $_.Exception.Message } else { $_.ToString() }
    }

    return $result
}

function Install-IPPServer {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    Assert-Elevated

    $result = [PSCustomObject]@{ Success = $false; Installed = @(); Errors = @() }

    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
        $isServer = ($os -and $os.ProductType -gt 1)

        $features = @('Printing-PrintManagement-Console')
        if ($isServer) {
            $features += 'Print-Server', 'Printing-InternetPrinting-Server'
        } else {
            $features += 'Printing-InternetPrinting-Client'
        }

        foreach ($feature in $features) {
            try {
                if ($isServer) {
                    $inst = Install-WindowsFeature -Name $feature -IncludeManagementTools -ErrorAction SilentlyContinue
                    if ($inst.Success) {
                        $result.Installed += $feature
                    } else {
                        $result.Errors += "Failed to install $feature"
                    }
                } else {
                    $null = Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -LimitAccess -ErrorAction SilentlyContinue
                    $result.Installed += $feature
                }
            } catch {
                $result.Errors += "$feature : $_"
            }
        }

        $result.Success = ($result.Errors.Count -eq 0)
    } catch {
        $result.Errors += $_.ToString()
    }

    return $result
}

function Test-IPPClientInstalled {
    [CmdletBinding()]
    [OutputType([bool])]
    try {
        $feature = Get-WindowsOptionalFeature -Online -FeatureName 'Printing-InternetPrinting-Client' -ErrorAction SilentlyContinue
        return ($feature -and $feature.State -eq 'Enabled')
    } catch {
        return $false
    }
}

Export-ModuleMember -Function Get-IPPStatus, Get-IPPUrls, Test-IPPEndpoint, Install-IPPServer, Test-IPPClientInstalled
