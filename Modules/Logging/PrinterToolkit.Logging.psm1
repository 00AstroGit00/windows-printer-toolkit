<#
.SYNOPSIS
    Structured logging for PrinterToolkit.

.DESCRIPTION
    Provides leveled logging (DEBUG, INFO, OK, WARN, ERROR, FATAL),
    log file management, and log archive export.

.NOTES
    Module: PrinterToolkit.Logging
    Author: PrinterToolkit Contributors
#>

$Script:LogPath = $null
$Script:CurrentLogFile = $null
$Script:LogLevelMap = @{DEBUG=0; INFO=1; OK=1; WARN=2; ERROR=3; FATAL=4}
$Script:LogLevelThreshold = 0
$Script:LogEntries = [System.Collections.ArrayList]::new()

function Initialize-Logging {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [ValidateSet('DEBUG', 'INFO', 'OK', 'WARN', 'ERROR', 'FATAL')]
        [string]$Level = 'INFO'
    )

    if (-not $Path) {
        $Path = Join-Path -Path ([Environment]::GetFolderPath('Desktop')) -ChildPath 'PrinterToolkit_Logs'
    }

    $Script:LogPath = $Path
    $null = New-Item -ItemType Directory -Force -Path $Script:LogPath
    $Script:CurrentLogFile = Join-Path -Path $Script:LogPath -ChildPath "PrinterToolkit_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    $Script:LogLevelThreshold = $Script:LogLevelMap[$Level]

    if (-not $Script:LogLevelThreshold) {
        $Script:LogLevelThreshold = 0
    }

    Write-Log -Message 'Logging initialized.' -Level 'DEBUG'
}

function Write-Log {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet('DEBUG', 'INFO', 'OK', 'WARN', 'ERROR', 'FATAL')]
        [string]$Level = 'INFO'
    )

    begin {
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
    }

    process {
        $numericLevel = $Script:LogLevelMap[$Level]
        if ($null -ne $numericLevel -and $numericLevel -lt $Script:LogLevelThreshold) {
            return
        }

        $line = "[$timestamp] [$Level] $Message"

        # Write to file
        if (-not $Script:CurrentLogFile) {
            Initialize-Logging
        }
        try {
            $line | Out-File -FilePath $Script:CurrentLogFile -Append -Encoding UTF8 -ErrorAction Stop
        } catch {
            Write-Host "[LOG ERROR] $line" -ForegroundColor DarkRed
            return
        }

        # Track in memory
        $null = $Script:LogEntries.Add(@{
            Timestamp = $timestamp
            Level     = $Level
            Message   = $Message
        })

        # Write to console (skip DEBUG)
        if ($Level -ne 'DEBUG') {
            $color = switch ($Level) {
                'ERROR' { 'Red' }
                'FATAL' { 'DarkRed' }
                'WARN'  { 'DarkYellow' }
                'OK'    { 'Green' }
                default { 'Gray' }
            }
            Write-Host $line -ForegroundColor $color
        }
    }
}

function Get-LogFilePath {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    $path = $Script:CurrentLogFile
    [PSCustomObject]@{
        Path   = $path
        Exists = if ($path) { Test-Path -Path $path -ErrorAction SilentlyContinue } else { $false }
    }
}

function Get-LogContent {
    [CmdletBinding()]
    [OutputType([array])]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 10000)]
        [int]$Tail = 0,

        [Parameter(Mandatory = $false)]
        [ValidateSet('DEBUG', 'INFO', 'OK', 'WARN', 'ERROR', 'FATAL', '')]
        [string]$Level = ''
    )

    if (-not $Script:CurrentLogFile -or -not (Test-Path -Path $Script:CurrentLogFile -ErrorAction SilentlyContinue)) {
        return @()
    }

    try {
        $content = Get-Content -Path $Script:CurrentLogFile -ErrorAction Stop
    } catch {
        return @()
    }

    if ($Level) {
        $content = $content | Where-Object { $_ -match "\[$Level\]" }
    }

    if ($Tail -gt 0) {
        $content = $content | Select-Object -Last $Tail
    }

    return ,$content
}

function Export-LogArchive {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Destination
    )

    if (-not $Destination) {
        $Destination = Join-Path -Path ([Environment]::GetFolderPath('Desktop')) -ChildPath "PrinterToolkit_Logs_Export_$(Get-Date -Format 'yyyyMMdd_HHmmss').zip"
    }

    if (Test-Path -Path $Script:LogPath -ErrorAction SilentlyContinue) {
        try {
            Compress-Archive -Path "$Script:LogPath\*" -DestinationPath $Destination -Force -ErrorAction Stop
        } catch {
            Write-Log -Message "Log archive failed: $_" -Level 'WARN'
            return $null
        }
    }

    return $Destination
}

Export-ModuleMember -Function Initialize-Logging, Write-Log, Get-LogFilePath, Get-LogContent, Export-LogArchive
