<#
.SYNOPSIS
    USB printer and hardware detection engine for PrinterToolkit v6.0.

.DESCRIPTION
    Detects USB-connected printers, extracts VID, PID, Hardware IDs,
    Compatible IDs, manufacturer, model, and connection details.
    Provides structured output for downstream driver and configuration modules.

.NOTES
    Module: PrinterToolkit.Detection
    Author: PrinterToolkit Contributors
#>

function Get-UsbPrinterInfo {
    [CmdletBinding()]
    [OutputType([array])]
    param()

    $results = [System.Collections.ArrayList]::new()

    try {
        $usbPrinters = Get-CimInstance -ClassName Win32_USBControllerDevice -ErrorAction SilentlyContinue |
            ForEach-Object { [wmi]$_.Dependent } |
            Where-Object { $_.PNPClass -eq 'Printer' -or $_.PNPClass -eq 'USB' }

        $printers = Get-CimInstance -ClassName Win32_Printer -ErrorAction SilentlyContinue

        foreach ($p in $printers) {
            $isUsb = $p.PortName -match 'USB' -or $p.PNPDeviceID -match 'USB'
            if (-not $isUsb) { continue }

            $pnpId = $p.PNPDeviceID
            $vid = ''
            $pid = ''
            $hwIds = @()

            if ($pnpId -match 'USB\\VID_([0-9A-Fa-f]{4})&PID_([0-9A-Fa-f]{4})') {
                $vid = "VID_$($matches[1])"
                $pid = "PID_$($matches[2])"
            }

            try {
                $dev = Get-PnpDevice -InstanceId $pnpId -ErrorAction SilentlyContinue
                if ($dev) {
                    $hwIds = @($dev.HardwareID -split ';')
                    $compatIds = @($dev.CompatibleID -split ';')
                }
            } catch {}

            $driver = Get-PrinterDriver -Name $p.DriverName -ErrorAction SilentlyContinue

            $usbPrinter = [PSCustomObject]@{
                PrinterName        = $p.Name
                PortName           = $p.PortName
                PNPDeviceID        = $pnpId
                VID                = $vid
                PID                = $pid
                HardwareIDs        = $hwIds
                Manufacturer       = $p.DriverName -replace '\(.*\)', '' -replace '\s+', ' ' | ForEach-Object { $_.Trim() }
                Model              = $p.Name
                DriverName         = $p.DriverName
                DriverVersion      = if ($driver) { $driver.MajorVersion } else { 0 }
                PrinterStatus      = $p.PrinterStatus.ToString()
                IsShared           = $p.Shared
                ShareName          = $p.ShareName
                Location           = $p.Location
                Comment            = $p.Comment
                IsDefault          = $p.Default
                ConnectionProtocol = if ($isUsb) { 'USB' } else { 'Network' }
            }
            $null = $results.Add($usbPrinter)
        }
    } catch {
        Write-Log -Message "USB printer detection failed: $_" -Level 'ERROR'
    }

    return ,@($results)
}

function Get-HardwareIdInfo {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$PrinterName
    )

    $hwinfo = [PSCustomObject]@{
        PrintersDetected = 0
        UsbPrinters      = @()
        HardwareIds      = @()
        CompatibleIds    = @()
        VIDList          = @()
        PIDList          = @()
        Timestamp        = Get-Date
    }

    $printers = Get-CimInstance -ClassName Win32_Printer -ErrorAction SilentlyContinue
    $usbPrinters = @()

    foreach ($p in $printers) {
        $isUsb = $p.PortName -match 'USB' -or $p.PNPDeviceID -match 'USB'
        if (-not $isUsb) { continue }
        $usbPrinters += $p
    }

    $hwinfo.PrintersDetected = $printers.Count
    $hwinfo.HardwareIds = $usbPrinters | ForEach-Object { $_.PNPDeviceID }

    foreach ($p in $usbPrinters) {
        $pnpId = $p.PNPDeviceID
        $vid = ''
        $pid = ''
        if ($pnpId -match 'USB\\VID_([0-9A-Fa-f]{4})&PID_([0-9A-Fa-f]{4})') {
            $vid = "VID_$($matches[1])"
            $pid = "PID_$($matches[2])"
        }
        if ($vid -and $vid -notin $hwinfo.VIDList) { $hwinfo.VIDList += $vid }
        if ($pid -and $pid -notin $hwinfo.PIDList) { $hwinfo.PIDList += $pid }
    }

    try {
        $allDevices = Get-PnpDevice -Class Printer -ErrorAction SilentlyContinue
        foreach ($d in $allDevices) {
            $ids = @($d.HardwareID -split ';')
            foreach ($id in $ids) {
                if ($id -and $id -notin $hwinfo.CompatibleIds) {
                    $hwinfo.CompatibleIds += $id
                }
            }
        }
    } catch {}

    $hwinfo.UsbPrinters = $usbPrinters | ForEach-Object {
        $pnpId = $_.PNPDeviceID
        $vid = ''; $pid = ''
        if ($pnpId -match 'USB\\VID_([0-9A-Fa-f]{4})&PID_([0-9A-Fa-f]{4})') {
            $vid = "VID_$($matches[1])"; $pid = "PID_$($matches[2])"
        }
        [PSCustomObject]@{
            PrinterName   = $_.Name
            PNPDeviceID   = $pnpId
            VID           = $vid
            PID           = $pid
            DriverName    = $_.DriverName
            Status        = $_.PrinterStatus.ToString()
        }
    }

    return $hwinfo
}

function Get-PrinterConnectionType {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PrinterName
    )

    try {
        $printer = Get-CimInstance -ClassName Win32_Printer -Filter "Name = '$($PrinterName -replace "'", "''")'" -ErrorAction SilentlyContinue
        if (-not $printer) { return 'Unknown' }

        $portName = $printer.PortName
        $pnpId = $printer.PNPDeviceID

        if ($portName -match '^USB' -or $pnpId -match 'USB') { return 'USB' }
        if ($portName -match '^http|^ipp|^https') { return 'IPP' }
        if ($portName -match '^wsd|^wsdprint') { return 'WSD' }
        if ($portName -match '^\\\\') { return 'SMB' }
        if ($portName -match '^lpt|^com|^FILE') { return 'Direct' }
        if ($portName -match '^192\.|^10\.|^172\.') { return 'TCP/IP' }

        return 'Unknown'
    } catch {
        return 'Unknown'
    }
}

Export-ModuleMember -Function Get-UsbPrinterInfo, Get-HardwareIdInfo, Get-PrinterConnectionType
