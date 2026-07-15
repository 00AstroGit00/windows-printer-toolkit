<#
.SYNOPSIS
    Workflow Orchestration Engine for PrinterToolkit v8.0.

.DESCRIPTION
    Replaces the procedural execution model with a dependency-aware
    orchestration framework. Every operation is expressed as a Task object;
    the orchestrator resolves a DAG, executes only what is required, skips
    unaffected work, retries transient failures, and rolls back on critical
    failure. Supports a declarative desired-state model, a state manager,
    an event bus, a transaction log, a recovery engine, configuration
    providers, and rich reporting. Existing public commands are preserved
    and now delegate to this engine.

.NOTES
    Module: PrinterToolkit.Orchestration
    Author: PrinterToolkit Contributors
#>

# ---------------------------------------------------------------------------
# Strongly-typed models
# ---------------------------------------------------------------------------

class RetryPolicy {
    [int]$MaxAttempts = 1
    [int]$DelayMs = 0
    [double]$BackoffMultiplier = 1.0

    RetryPolicy() { }
    RetryPolicy([int]$maxAttempts, [int]$delayMs) {
        $this.MaxAttempts = $maxAttempts
        $this.DelayMs = $delayMs
    }
}

class OrchestrationTask {
    [string]$Name = ''
    [string]$Description = ''
    [string]$Category = 'General'
    [string]$Subsystem = ''
    [string[]]$Dependencies = @()
    [string[]]$Prerequisites = @()
    [scriptblock]$Execute = $null
    [scriptblock]$Validate = $null
    [scriptblock]$Rollback = $null
    [RetryPolicy]$RetryPolicy = ([RetryPolicy]::new())
    [int]$TimeoutMs = 0
    [bool]$IsCritical = $true
    [bool]$CanSkip = $false
    [int]$EstimatedDuration = 0
    [bool]$RequiredElevation = $false
    [string[]]$RequiredWindowsFeatures = @()
    [string[]]$RequiredServices = @()
    [hashtable]$Outputs = @{}
    # runtime state
    [string]$Status = 'Pending'
    [int]$Attempts = 0
    [int]$DurationMs = 0
    [string]$Error = ''

    OrchestrationTask() { }
}

# ---------------------------------------------------------------------------
# Module state
# ---------------------------------------------------------------------------

$Script:EventSubscribers = [System.Collections.ArrayList]::new()
$Script:SubsystemStates = @{}
$Script:ActiveTransaction = $null
$Script:TransactionLog = [System.Collections.ArrayList]::new()
$Script:OrchestrationEvents = [System.Collections.ArrayList]::new()
$Script:ProviderPreState = @{}

# ---------------------------------------------------------------------------
# Event Bus
# ---------------------------------------------------------------------------

function Subscribe-OrchestrationEvent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$EventName,
        [Parameter(Mandatory = $true)][scriptblock]$Handler
    )
    $null = $Script:EventSubscribers.Add([PSCustomObject]@{ EventName = $EventName; Handler = $Handler })
}

function Publish-OrchestrationEvent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$EventName,
        [Parameter()]$Data
    )
    $evt = [PSCustomObject]@{
        EventName = $EventName
        Timestamp = Get-Date
        Data      = $Data
    }
    $null = $Script:OrchestrationEvents.Add($evt)
    foreach ($sub in $Script:EventSubscribers) {
        if ($sub.EventName -eq $EventName -or $sub.EventName -eq '*') {
            try { & $sub.Handler $evt } catch {}
        }
    }
}

function Get-OrchestrationEventLog {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)][string]$EventName,
        [Parameter(Mandatory = $false)][int]$Tail = 0
    )
    $events = $Script:OrchestrationEvents
    if ($EventName) {
        $events = $events | Where-Object { $_.EventName -eq $EventName }
    }
    if ($Tail -gt 0) {
        $events = $events | Select-Object -Last $Tail
    }
    [PSCustomObject]@{
        EventCount = @($events).Count
        Events     = @($events)
    }
}

function Reset-OrchestrationState {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $false)][switch]$KeepTransactionLog
    )
    $Script:SubsystemStates = @{}
    $Script:OrchestrationEvents = [System.Collections.ArrayList]::new()
    $Script:ActiveTransaction = $null
    $Script:EventSubscribers = [System.Collections.ArrayList]::new()
    $Script:ProviderPreState = @{}
    if (-not $KeepTransactionLog) {
        $Script:TransactionLog = [System.Collections.ArrayList]::new()
    }
}

function Get-OrchestrationStateReport {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()
    $states = $Script:SubsystemStates.Clone()
    $all = @($states.Values)
    $healthy = @($all | Where-Object { $_.State -eq 'Healthy' }).Count
    $warning = @($all | Where-Object { $_.State -eq 'Warning' }).Count
    $failed = @($all | Where-Object { $_.State -eq 'Failed' }).Count
    $pending = @($all | Where-Object { $_.State -eq 'Pending' }).Count
    $unknown = @($all | Where-Object { $_.State -eq 'Unknown' }).Count
    $total = $all.Count
    [PSCustomObject]@{
        GeneratedAt   = Get-Date
        TotalSubsystems = $total
        Healthy       = $healthy
        Warning       = $warning
        Failed        = $failed
        Pending       = $pending
        Unknown       = $unknown
        OverallHealth = if ($total -eq 0) { 'Unknown' } elseif ($failed -gt 0) { 'Failed' } elseif ($warning -gt 0) { 'Warning' } elseif ($pending -gt 0) { 'Pending' } else { 'Healthy' }
        HealthScore   = if ($total -gt 0) { [math]::Round(($healthy / $total) * 100, 1) } else { 0 }
        SubsystemStates = @($all | Sort-Object Subsystem)
    }
}

# ---------------------------------------------------------------------------
# State Manager
# ---------------------------------------------------------------------------

function Set-SubsystemState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Subsystem,
        [Parameter(Mandatory = $true)][ValidateSet('Healthy', 'Warning', 'Failed', 'Unknown', 'Pending')][string]$State,
        [Parameter()][string]$Detail = ''
    )
    $previous = if ($Script:SubsystemStates.ContainsKey($Subsystem)) { $Script:SubsystemStates[$Subsystem].State } else { 'Unknown' }
    $Script:SubsystemStates[$Subsystem] = [PSCustomObject]@{
        Subsystem = $Subsystem
        State     = $State
        Detail    = $Detail
        UpdatedAt = Get-Date
        Previous  = $previous
    }
    Write-Log -Message "[STATE] $Subsystem : $previous -> $State" -Level $(if ($State -eq 'Failed') { 'ERROR' } elseif ($State -eq 'Warning') { 'WARN' } else { 'INFO' })
}

function Get-SubsystemState {
    [CmdletBinding()]
    param([Parameter()][string]$Subsystem)
    if ($Subsystem) {
        if ($Script:SubsystemStates.ContainsKey($Subsystem)) { return $Script:SubsystemStates[$Subsystem] }
        return [PSCustomObject]@{ Subsystem = $Subsystem; State = 'Unknown'; Detail = ''; UpdatedAt = $null; Previous = 'Unknown' }
    }
    return [PSCustomObject]@{ States = $Script:SubsystemStates.Clone() }
}

# ---------------------------------------------------------------------------
# Task framework
# ---------------------------------------------------------------------------

function New-OrchestrationTask {
    [CmdletBinding()]
    [OutputType([OrchestrationTask])]
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $false)][string]$Description = '',
        [Parameter(Mandatory = $false)][string]$Category = 'General',
        [Parameter(Mandatory = $false)][string]$Subsystem = '',
        [Parameter(Mandatory = $false)][string[]]$Dependencies = @(),
        [Parameter(Mandatory = $true)][scriptblock]$Execute,
        [Parameter(Mandatory = $true)][scriptblock]$Validate,
        [Parameter(Mandatory = $false)][scriptblock]$Rollback,
        [Parameter(Mandatory = $false)][hashtable]$RetryPolicy,
        [Parameter(Mandatory = $false)][int]$TimeoutMs = 0,
        [Parameter(Mandatory = $false)][bool]$IsCritical = $true,
        [Parameter(Mandatory = $false)][bool]$CanSkip = $false,
        [Parameter(Mandatory = $false)][int]$EstimatedDuration = 0,
        [Parameter(Mandatory = $false)][bool]$RequiredElevation = $false,
        [Parameter(Mandatory = $false)][string[]]$RequiredWindowsFeatures = @(),
        [Parameter(Mandatory = $false)][string[]]$RequiredServices = @()
    )

    $task = [OrchestrationTask]::new()
    $task.Name = $Name
    $task.Description = $Description
    $task.Category = $Category
    $task.Subsystem = $Subsystem
    $task.Dependencies = $Dependencies
    $task.Execute = $Execute
    $task.Validate = $Validate
    $task.Rollback = $Rollback
    $task.TimeoutMs = $TimeoutMs
    $task.IsCritical = $IsCritical
    $task.CanSkip = $CanSkip
    $task.EstimatedDuration = $EstimatedDuration
    $task.RequiredElevation = $RequiredElevation
    $task.RequiredWindowsFeatures = $RequiredWindowsFeatures
    $task.RequiredServices = $RequiredServices

    if ($RetryPolicy) {
        $rp = [RetryPolicy]::new()
        if ($RetryPolicy.ContainsKey('MaxAttempts')) { $rp.MaxAttempts = $RetryPolicy.MaxAttempts }
        if ($RetryPolicy.ContainsKey('DelayMs')) { $rp.DelayMs = $RetryPolicy.DelayMs }
        if ($RetryPolicy.ContainsKey('BackoffMultiplier')) { $rp.BackoffMultiplier = $RetryPolicy.BackoffMultiplier }
        $task.RetryPolicy = $rp
    }
    return $task
}

# ---------------------------------------------------------------------------
# DAG dependency resolver (topological order + cycle detection)
# ---------------------------------------------------------------------------

function Get-TopologicalTaskOrder {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)][OrchestrationTask[]]$Tasks
    )

    $byName = @{}
    foreach ($t in $Tasks) { $byName[$t.Name] = $t }

    $visited = @{}
    $inProgress = @{}
    $order = [System.Collections.ArrayList]::new()
    $state = [PSCustomObject]@{ HasCycle = $false }

    $visit = {
        param($task)
        if ($visited[$task.Name]) { return }
        if ($inProgress[$task.Name]) { $state.HasCycle = $true; return }
        $inProgress[$task.Name] = $true
        foreach ($dep in $task.Dependencies) {
            if ($byName.ContainsKey($dep)) { & $visit $byName[$dep] }
        }
        $inProgress[$task.Name] = $false
        $visited[$task.Name] = $true
        $null = $order.Add($task)
    }

    foreach ($t in $Tasks) { & $visit $t }

    [PSCustomObject]@{
        Ordered  = if ($state.HasCycle) { @() } else { @($order) }
        HasCycle = $state.HasCycle
    }
}

# ---------------------------------------------------------------------------
# Transaction Engine
# ---------------------------------------------------------------------------

function Start-OrchestrationTransaction {
    [CmdletBinding()]
    param()
    $Script:ActiveTransaction = [PSCustomObject]@{
        Id       = "TX_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Operator = if ($env:USERNAME) { $env:USERNAME } else { 'SYSTEM' }
        Started  = Get-Date
        Entries  = [System.Collections.ArrayList]::new()
    }
    $Script:TransactionLog = [System.Collections.ArrayList]::new()
    Write-TransactionLog -Category Operation -Message "Orchestration transaction $($Script:ActiveTransaction.Id) started" -Data $Script:ActiveTransaction
}

function Record-TaskTransaction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][OrchestrationTask]$Task,
        [Parameter()]$OriginalState,
        [Parameter()]$RequestedState,
        [Parameter()]$AppliedChanges,
        [Parameter()]$RollbackData,
        [Parameter()][bool]$ValidationResult
    )
    $entry = [PSCustomObject]@{
        TaskName         = $Task.Name
        Subsystem        = $Task.Subsystem
        OriginalState    = $OriginalState
        RequestedState   = $RequestedState
        AppliedChanges   = $AppliedChanges
        ValidationResult = $ValidationResult
        RollbackData     = $RollbackData
        ExecutionTimeMs  = $Task.DurationMs
        Operator         = if ($Script:ActiveTransaction) { $Script:ActiveTransaction.Operator } else { 'SYSTEM' }
        Timestamp        = Get-Date
    }
    if ($Script:ActiveTransaction) { $null = $Script:ActiveTransaction.Entries.Add($entry) }
    $null = $Script:TransactionLog.Add($entry)
    $txCmd = Get-Command -Name Get-TransactionLogPath -ErrorAction SilentlyContinue
    if ($txCmd) {
        $txPath = & $txCmd
        if ($txPath -and $txPath.Path -and (Test-Path -Path $txPath.Path)) {
            $entry | ConvertTo-Json -Compress | Out-File -FilePath (Join-Path $txPath.Path "transactions.log") -Append -Encoding UTF8 -ErrorAction SilentlyContinue
        }
    }
}

function Get-OrchestrationTransactionLog {
    [CmdletBinding()]
    param()
    if ($Script:ActiveTransaction) {
        [PSCustomObject]@{
            Id      = $Script:ActiveTransaction.Id
            Entries = @($Script:ActiveTransaction.Entries)
        }
    } else {
        [PSCustomObject]@{ Id = $null; Entries = @($Script:TransactionLog) }
    }
}

# ---------------------------------------------------------------------------
# Desired State Engine
# ---------------------------------------------------------------------------

function Get-DefaultDesiredState {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()
    [PSCustomObject]@{
        Printer  = [PSCustomObject]@{ Shared = $true; Default = $false }
        Services = [PSCustomObject]@{
            Spooler          = 'Running'
            LanmanServer     = 'Running'
            LanmanWorkstation = 'Running'
            FDResPub         = 'Running'
            FDPhost          = 'Running'
            RpcSs            = 'Running'
            DcomLaunch       = 'Running'
            DNSCache         = 'Running'
            SSDPSRV          = 'Running'
            upnphost         = 'Running'
        }
        Firewall = [PSCustomObject]@{ IPP = $true; SMB = $true; Discovery = $true }
        Network  = [PSCustomObject]@{ Profile = 'Private' }
        IPP      = [PSCustomObject]@{ Enabled = $true }
        Registry = [PSCustomObject]@{ RpcAuthnLevelPrivacyEnabled = 0; DisableHTTPPrinting = 0 }
    }
}

function Get-DesiredState {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)][string]$Path
    )
    if ($Path -and (Test-Path -Path $Path)) {
        return (Get-Content -Path $Path -Raw | ConvertFrom-Json)
    }
    return Get-DefaultDesiredState
}

# ---------------------------------------------------------------------------
# Configuration Providers
# Each provider supports phases: GetCurrentState, GetDesiredState,
# PlanChanges, ApplyChanges, Validate, Rollback.
# ---------------------------------------------------------------------------

function Invoke-ConfigurationProvider {
    [CmdletBinding()]
    [OutputType([PSObject])]
    param(
        [Parameter(Mandatory = $true)][string]$Provider,
        [Parameter(Mandatory = $true)][ValidateSet('GetCurrentState', 'GetDesiredState', 'PlanChanges', 'ApplyChanges', 'Validate', 'Rollback')][string]$Phase,
        [Parameter(Mandatory = $false)]$DesiredState,
        [Parameter(Mandatory = $false)]$RollbackData,
        [Parameter(Mandatory = $false)][string]$PrinterName,
        [Parameter(Mandatory = $false)][string]$ShareName
    )

    switch ($Provider) {
        'Service' {
            switch ($Phase) {
                'GetCurrentState' {
                    $svcs = if ($DesiredState -and $DesiredState.Services) { $DesiredState.Services.PSObject.Properties.Name } else { @() }
                    $out = @{}
                    foreach ($s in $svcs) { $sv = Get-Service -Name $s -ErrorAction SilentlyContinue; $out[$s] = if ($sv) { $sv.Status.ToString() } else { 'Missing' } }
                    return [PSCustomObject]@{ Services = $out }
                }
                'GetDesiredState' { return [PSCustomObject]@{ Services = $DesiredState.Services.PSObject.Properties.Name | ForEach-Object { $_ } }
                    # desired values captured below
                    $d = @{}; foreach ($p in $DesiredState.Services.PSObject.Properties) { $d[$p.Name] = $p.Value }; return [PSCustomObject]@{ Services = $d }
                }
                'PlanChanges' {
                    $plan = [System.Collections.ArrayList]::new()
                    foreach ($p in $DesiredState.Services.PSObject.Properties) {
                        $sv = Get-Service -Name $p.Name -ErrorAction SilentlyContinue
                        $wantRunning = ($p.Value -eq 'Running')
                        if (-not $sv -or $sv.Status -ne 'Running' -or $sv.StartType -ne 'Automatic') {
                            $null = $plan.Add([PSCustomObject]@{ Service = $p.Name; Action = 'Set Automatic + Running' })
                        }
                    }
                    return ,@($plan)
                }
                'ApplyChanges' {
                    $preState = @{}
                    foreach ($p in $DesiredState.Services.PSObject.Properties) {
                        $sv = Get-Service -Name $p.Name -ErrorAction SilentlyContinue
                        if ($sv) {
                            $preState[$p.Name] = @{ Status = $sv.Status.ToString(); StartType = $sv.StartType.ToString() }
                        }
                        Set-ServiceConfiguration -ServiceName $p.Name -StartType Automatic -EnsureRunning -ErrorAction SilentlyContinue
                    }
                    $Script:ProviderPreState['Service'] = $preState
                    return $true
                }
                'Validate' {
                    foreach ($p in $DesiredState.Services.PSObject.Properties) {
                        $sv = Get-Service -Name $p.Name -ErrorAction SilentlyContinue
                        if (-not ($sv -and $sv.Status -eq 'Running')) { return $false }
                    }
                    return $true
                }
                'Rollback' {
                    $pre = $Script:ProviderPreState['Service']
                    if (-not $pre) { return $true }
                    foreach ($entry in $pre.GetEnumerator()) {
                        $sv = Get-Service -Name $entry.Key -ErrorAction SilentlyContinue
                        if (-not $sv) { continue }
                        try {
                            Set-Service -Name $entry.Key -StartupType $entry.Value.StartType -ErrorAction SilentlyContinue
                            if ($entry.Value.Status -eq 'Running') {
                                Start-Service -Name $entry.Key -ErrorAction SilentlyContinue
                            } else {
                                Stop-Service -Name $entry.Key -Force -ErrorAction SilentlyContinue
                            }
                        } catch {}
                    }
                    return $true
                }
            }
        }
        'Firewall' {
            switch ($Phase) {
                'GetCurrentState' {
                    $fp = Get-NetFirewallRule -DisplayGroup 'File and Printer Sharing' -ErrorAction SilentlyContinue
                    $fpOk = @($fp | Where-Object { $_.Enabled }).Count -gt 0
                    $disc = Get-NetFirewallRule -DisplayGroup 'Network Discovery' -ErrorAction SilentlyContinue
                    $discOk = @($disc | Where-Object { $_.Enabled }).Count -gt 0
                    $ipp = Get-NetFirewallRule -DisplayName 'IPP Printer Port 631' -ErrorAction SilentlyContinue
                    return [PSCustomObject]@{ IPP = ($ipp -and $ipp.Enabled); SMB = $fpOk; Discovery = $discOk }
                }
                'GetDesiredState' { return [PSCustomObject]@{ IPP = $DesiredState.Firewall.IPP; SMB = $DesiredState.Firewall.SMB; Discovery = $DesiredState.Firewall.Discovery } }
                'PlanChanges' { return ,@([PSCustomObject]@{ Action = 'Enable File/Printer Sharing, Network Discovery, IPP 631' }) }
                'ApplyChanges' {
                    $preState = @{ Groups = @{}; Ipp = $false }
                    foreach ($g in @('File and Printer Sharing', 'Network Discovery')) {
                        $rules = Get-NetFirewallRule -DisplayGroup $g -ErrorAction SilentlyContinue
                        $preState.Groups[$g] = @($rules | Where-Object { $_.Enabled }).Count -gt 0
                    }
                    $ipp = Get-NetFirewallRule -DisplayName 'IPP Printer Port 631' -ErrorAction SilentlyContinue
                    $preState.Ipp = ($ipp -and $ipp.Enabled)
                    $Script:ProviderPreState['Firewall'] = $preState
                    $null = Enable-PrinterFirewallRules -IncludeIpp
                    return $true
                }
                'Validate' {
                    $fp = Get-NetFirewallRule -DisplayGroup 'File and Printer Sharing' -ErrorAction SilentlyContinue
                    $fpOk = @($fp | Where-Object { $_.Enabled }).Count -gt 0
                    $ipp = Get-NetFirewallRule -DisplayName 'IPP Printer Port 631' -ErrorAction SilentlyContinue
                    return ($fpOk -and $ipp -and $ipp.Enabled)
                }
                'Rollback' {
                    $pre = $Script:ProviderPreState['Firewall']
                    if (-not $pre) { return $true }
                    foreach ($g in $pre.Groups.GetEnumerator()) {
                        if (-not $g.Value) {
                            $rules = Get-NetFirewallRule -DisplayGroup $g.Key -ErrorAction SilentlyContinue
                            if ($rules) { $rules | Disable-NetFirewallRule -ErrorAction SilentlyContinue }
                        }
                    }
                    if (-not $pre.Ipp) {
                        $ipp = Get-NetFirewallRule -DisplayName 'IPP Printer Port 631' -ErrorAction SilentlyContinue
                        if ($ipp) { $ipp | Disable-NetFirewallRule -ErrorAction SilentlyContinue }
                    }
                    return $true
                }
            }
        }
        'Network' {
            switch ($Phase) {
                'GetCurrentState' {
                    $p = Get-NetConnectionProfile -ErrorAction SilentlyContinue | Select-Object -First 1
                    return [PSCustomObject]@{ Profile = if ($p) { $p.NetworkCategory.ToString() } else { 'Unknown' } }
                }
                'GetDesiredState' { return [PSCustomObject]@{ Profile = $DesiredState.Network.Profile } }
                'PlanChanges' {
                    $p = Get-NetConnectionProfile -ErrorAction SilentlyContinue | Select-Object -First 1
                    if ($p -and $p.NetworkCategory -ne $DesiredState.Network.Profile) { return ,@([PSCustomObject]@{ Action = 'Set Private profile' }) }
                    return @()
                }
                'ApplyChanges' {
                    $p = Get-NetConnectionProfile -ErrorAction SilentlyContinue | Select-Object -First 1
                    if ($p -and $p.NetworkCategory -ne $DesiredState.Network.Profile) {
                        $Script:ProviderPreState['Network'] = @{ InterfaceIndex = $p.InterfaceIndex; Category = $p.NetworkCategory.ToString() }
                        Set-NetConnectionProfile -InterfaceIndex $p.InterfaceIndex -NetworkCategory $DesiredState.Network.Profile -ErrorAction SilentlyContinue
                    }
                    return $true
                }
                'Validate' {
                    $p = Get-NetConnectionProfile -ErrorAction SilentlyContinue | Select-Object -First 1
                    return ($p -and $p.NetworkCategory -eq $DesiredState.Network.Profile)
                }
                'Rollback' {
                    $pre = $Script:ProviderPreState['Network']
                    if (-not $pre) { return $true }
                    try {
                        Set-NetConnectionProfile -InterfaceIndex $pre.InterfaceIndex -NetworkCategory $pre.Category -ErrorAction SilentlyContinue
                    } catch {}
                    return $true
                }
            }
        }
        'Sharing' {
            switch ($Phase) {
                'GetCurrentState' {
                    $p = if ($PrinterName) { Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue } else { Get-Printer -ErrorAction SilentlyContinue | Where-Object { $_.Shared } | Select-Object -First 1 }
                    return [PSCustomObject]@{ Shared = if ($p) { $p.Shared } else { $false }; ShareName = if ($p) { $p.ShareName } else { '' } }
                }
                'GetDesiredState' { return [PSCustomObject]@{ Shared = $DesiredState.Printer.Shared } }
                'PlanChanges' {
                    $p = if ($PrinterName) { Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue } else { Get-Printer -ErrorAction SilentlyContinue | Select-Object -First 1 }
                    if ($p -and -not $p.Shared) { return ,@([PSCustomObject]@{ Action = "Share $($p.Name)" }) }
                    return @()
                }
                'ApplyChanges' {
                    $p = if ($PrinterName) { Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue } else { Get-Printer -ErrorAction SilentlyContinue | Where-Object { $_.Shared } | Select-Object -First 1 }
                    if (-not $p) { Write-Log -Message 'Sharing.ApplyChanges: no printer found' -Level 'WARN'; return $false }
                    $sn = if ($ShareName) { $ShareName } else { $p.Name -replace '[^a-zA-Z0-9_-]', '_' }
                    $Script:ProviderPreState['Sharing'] = @{ PrinterName = $p.Name; WasShared = $p.Shared; ShareName = $p.ShareName }
                    $r = Enable-PrinterSharing -PrinterName $p.Name -ShareName $sn -ErrorAction SilentlyContinue
                    $ok = ($r -and $r.Success)
                    if (-not $ok) { Write-Log -Message "Sharing.ApplyChanges: Enable-PrinterSharing failed for $($p.Name)" -Level 'WARN' }
                    return $ok
                }
                'Validate' {
                    $p = if ($PrinterName) { Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue } else { Get-Printer -ErrorAction SilentlyContinue | Where-Object { $_.Shared } | Select-Object -First 1 }
                    return ($p -and $p.Shared)
                }
                'Rollback' {
                    $pre = $Script:ProviderPreState['Sharing']
                    if (-not $pre) { return $true }
                    if (-not $pre.WasShared) {
                        try { Disable-PrinterSharing -PrinterName $pre.PrinterName -ErrorAction SilentlyContinue } catch {}
                    }
                    return $true
                }
            }
        }
        'IPP' {
            switch ($Phase) {
                'GetCurrentState' { $s = Get-IPPStatus -ErrorAction SilentlyContinue; return [PSCustomObject]@{ Enabled = ($s -and $s.IPPUrls.Count -gt 0); Urls = if ($s) { $s.IPPUrls } else { @() } } }
                'GetDesiredState' { return [PSCustomObject]@{ Enabled = $DesiredState.IPP.Enabled } }
                'PlanChanges' { $s = Get-IPPStatus -ErrorAction SilentlyContinue; if (-not ($s -and $s.IPPUrls.Count -gt 0)) { return ,@([PSCustomObject]@{ Action = 'Install IPP' }) }; return @() }
                'ApplyChanges' {
                    $s = Get-IPPStatus -ErrorAction SilentlyContinue
                    $Script:ProviderPreState['IPP'] = @{ WasInstalled = ($s -and $s.IPPUrls.Count -gt 0) }
                    $r = Install-IPPServer -Force -ErrorAction SilentlyContinue
                    return ($r -and $r.Success)
                }
                'Validate' { $s = Get-IPPStatus -ErrorAction SilentlyContinue; return ($s -and $s.IPPUrls.Count -gt 0) }
                'Rollback' {
                    $pre = $Script:ProviderPreState['IPP']
                    if (-not $pre -or $pre.WasInstalled) { return $true }
                    try {
                        $svc = Get-Service -Name 'Spooler' -ErrorAction SilentlyContinue
                        if ($svc -and $svc.Status -eq 'Running') {
                            Set-ServiceConfiguration -ServiceName 'PrintNotify' -StartType Disabled -EnsureStopped -ErrorAction SilentlyContinue
                        }
                    } catch {}
                    return $true
                }
            }
        }
        'Registry' {
            switch ($Phase) {
                'GetCurrentState' {
                    $path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Print'
                    $v1 = Get-ItemProperty -Path $path -Name 'RpcAuthnLevelPrivacyEnabled' -ErrorAction SilentlyContinue
                    $v2 = Get-ItemProperty -Path $path -Name 'DisableHTTPPrinting' -ErrorAction SilentlyContinue
                    return [PSCustomObject]@{ RpcAuthnLevelPrivacyEnabled = if ($v1) { $v1.RpcAuthnLevelPrivacyEnabled } else { $null }; DisableHTTPPrinting = if ($v2) { $v2.DisableHTTPPrinting } else { $null } }
                }
                'GetDesiredState' { return [PSCustomObject]@{ RpcAuthnLevelPrivacyEnabled = $DesiredState.Registry.RpcAuthnLevelPrivacyEnabled; DisableHTTPPrinting = $DesiredState.Registry.DisableHTTPPrinting } }
                'PlanChanges' { return ,@([PSCustomObject]@{ Action = 'Set print registry values' }) }
                'ApplyChanges' {
                    $path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Print'
                    $preState = @{}
                    $v1 = Get-ItemProperty -Path $path -Name 'RpcAuthnLevelPrivacyEnabled' -ErrorAction SilentlyContinue
                    $preState.RpcAuthnLevelPrivacyEnabled = if ($v1) { $v1.RpcAuthnLevelPrivacyEnabled } else { $null }
                    $v2 = Get-ItemProperty -Path $path -Name 'DisableHTTPPrinting' -ErrorAction SilentlyContinue
                    $preState.DisableHTTPPrinting = if ($v2) { $v2.DisableHTTPPrinting } else { $null }
                    $Script:ProviderPreState['Registry'] = $preState
                    if (-not (Test-Path -Path $path)) { $null = New-Item -Path $path -Force -ErrorAction SilentlyContinue }
                    Set-ItemProperty -Path $path -Name 'RpcAuthnLevelPrivacyEnabled' -Value $DesiredState.Registry.RpcAuthnLevelPrivacyEnabled -Type DWord -ErrorAction SilentlyContinue
                    Set-ItemProperty -Path $path -Name 'DisableHTTPPrinting' -Value $DesiredState.Registry.DisableHTTPPrinting -Type DWord -ErrorAction SilentlyContinue
                    return $true
                }
                'Validate' {
                    $path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Print'
                    $v1 = Get-ItemProperty -Path $path -Name 'RpcAuthnLevelPrivacyEnabled' -ErrorAction SilentlyContinue
                    return ($null -eq $v1 -or $v1.RpcAuthnLevelPrivacyEnabled -eq $DesiredState.Registry.RpcAuthnLevelPrivacyEnabled)
                }
                'Rollback' {
                    $pre = $Script:ProviderPreState['Registry']
                    if (-not $pre) { return $true }
                    $path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Print'
                    try {
                        if ($null -ne $pre.RpcAuthnLevelPrivacyEnabled) {
                            Set-ItemProperty -Path $path -Name 'RpcAuthnLevelPrivacyEnabled' -Value $pre.RpcAuthnLevelPrivacyEnabled -Type DWord -ErrorAction SilentlyContinue
                        }
                        if ($null -ne $pre.DisableHTTPPrinting) {
                            Set-ItemProperty -Path $path -Name 'DisableHTTPPrinting' -Value $pre.DisableHTTPPrinting -Type DWord -ErrorAction SilentlyContinue
                        }
                    } catch {}
                    return $true
                }
            }
        }
        'Driver' {
            switch ($Phase) {
                'GetCurrentState' { $d = if ($PrinterName) { Get-DriverIntelligence -PrinterName $PrinterName -ErrorAction SilentlyContinue } else { $null }; return [PSCustomObject]@{ Found = if ($d) { $d.DriverFound } else { $false }; PrinterName = $PrinterName } }
                'GetDesiredState' { return [PSCustomObject]@{ Found = $true } }
                'PlanChanges' { $d = if ($PrinterName) { Get-DriverIntelligence -PrinterName $PrinterName -ErrorAction SilentlyContinue } else { $null }; if (-not ($d -and $d.DriverFound)) { return ,@([PSCustomObject]@{ Action = 'Ensure driver present' }) }; return @() }
                'ApplyChanges' {
                    $d = if ($PrinterName) { Get-DriverIntelligence -PrinterName $PrinterName -ErrorAction SilentlyContinue } else { $null }
                    $Script:ProviderPreState['Driver'] = @{ Found = if ($d) { $d.DriverFound } else { $false }; PrinterName = $PrinterName }
                    Write-Log -Message 'Driver.ApplyChanges: driver acquisition is handled by Windows PnP — no automated download performed' -Level 'INFO'
                    return $true
                }
                'Validate' { $d = if ($PrinterName) { Get-DriverIntelligence -PrinterName $PrinterName -ErrorAction SilentlyContinue } else { $null }; return ($d -and $d.DriverFound) }
                'Rollback' {
                    $pre = $Script:ProviderPreState['Driver']
                    if (-not $pre) { return $true }
                    Write-Log -Message "Driver.Rollback: driver state was Found=$($pre.Found) — no driver was installed by this provider, so no rollback needed" -Level 'INFO'
                    return $true
                }
            }
        }
        'Printer' {
            switch ($Phase) {
                'GetCurrentState' { $usb = Get-UsbPrinterInfo -ErrorAction SilentlyContinue; return [PSCustomObject]@{ Detected = ($usb -and $usb.Count -gt 0); Name = if ($usb -and $usb.Count -gt 0) { $usb[0].PrinterName } else { '' } } }
                'GetDesiredState' { return [PSCustomObject]@{ Detected = $true } }
                'PlanChanges' { $usb = Get-UsbPrinterInfo -ErrorAction SilentlyContinue; if (-not ($usb -and $usb.Count -gt 0)) { return ,@([PSCustomObject]@{ Action = 'Detect USB printer' }) }; return @() }
                'ApplyChanges' {
                    $usb = Get-UsbPrinterInfo -ErrorAction SilentlyContinue
                    $Script:ProviderPreState['Printer'] = @{ Detected = ($usb -and $usb.Count -gt 0); Name = if ($usb -and $usb.Count -gt 0) { $usb[0].PrinterName } else { '' } }
                    Write-Log -Message 'Printer.ApplyChanges: printer detection is read-only — no automated installation performed' -Level 'INFO'
                    return $true
                }
                'Validate' { $usb = Get-UsbPrinterInfo -ErrorAction SilentlyContinue; return ($usb -and $usb.Count -gt 0) }
                'Rollback' {
                    $pre = $Script:ProviderPreState['Printer']
                    if (-not $pre) { return $true }
                    Write-Log -Message "Printer.Rollback: pre-state was Detected=$($pre.Detected) — no printer configuration was changed by this provider" -Level 'INFO'
                    return $true
                }
            }
        }
        default { throw "Unknown provider: $Provider" }
    }
}

# ---------------------------------------------------------------------------
# Orchestrator (DAG executor)
# ---------------------------------------------------------------------------

function Invoke-Orchestrator {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)][OrchestrationTask[]]$Tasks,
        [Parameter(Mandatory = $false)][switch]$NoRecovery
    )

    $ordered = Get-TopologicalTaskOrder -Tasks $Tasks
    $byName = @{}
    foreach ($t in $Tasks) { $byName[$t.Name] = $t }

    if ($ordered.HasCycle) {
        Write-Log -Message 'Orchestrator aborted: task dependency graph contains a cycle' -Level 'ERROR'
        return [PSCustomObject]@{
            Success        = $false
            Recovered      = $false
            HasCycle       = $true
            Tasks          = @($Tasks)
            FailedTasks    = @()
            RecoveredTasks = @()
            SkippedTasks   = @()
            Events         = @()
        }
    }

    if (-not $Script:ActiveTransaction) { Start-OrchestrationTransaction }
    Publish-OrchestrationEvent -EventName 'OrchestrationStarted' -Data @{ TaskCount = $ordered.Ordered.Count }

    foreach ($task in $ordered.Ordered) {
        # dependency gate
        $depFailed = $false
        foreach ($dep in $task.Dependencies) {
            if ($byName.ContainsKey($dep) -and $byName[$dep].Status -eq 'Failed') { $depFailed = $true }
        }
        if ($depFailed) {
            $task.Status = 'Skipped'
            Publish-OrchestrationEvent -EventName 'TaskSkipped' -Data @{ Task = $task.Name; Reason = 'Dependency failed' }
            continue
        }

        if ($task.RequiredElevation -and -not (Test-Elevated)) {
            $task.Status = 'Failed'
            $task.Error = 'Elevation required'
            Publish-OrchestrationEvent -EventName 'TaskFailed' -Data @{ Task = $task.Name; Error = $task.Error }
            Set-SubsystemState -Subsystem $task.Subsystem -State 'Failed' -Detail 'Elevation required'
            continue
        }

        Publish-OrchestrationEvent -EventName 'TaskStarted' -Data @{ Task = $task.Name }
        Set-SubsystemState -Subsystem $task.Subsystem -State 'Pending' -Detail "Running $($task.Name)"

        $attempt = 0
        $success = $false
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        do {
            $attempt++
            $task.Attempts = $attempt
            $execOk = $false
            try {
                if ($task.Execute) { & $task.Execute }
                $execOk = $true
            } catch {
                $task.Error = $_.Exception.Message
                Write-Log -Message "[TASK] $($task.Name) execute failed: $_" -Level 'ERROR'
            }
            $valOk = $false
            if ($execOk -and $task.Validate) {
                try {
                    $vres = & $task.Validate
                    $valOk = if ($null -eq $vres) { $true } else { [bool]$vres }
                } catch {
                    $valOk = $false
                    $task.Error = $_.Exception.Message
                }
            } elseif ($execOk) {
                $valOk = $true
            }
            if ($execOk -and $valOk) { $success = $true; break }
            if ($attempt -lt $task.RetryPolicy.MaxAttempts) {
                Start-Sleep -Milliseconds $task.RetryPolicy.DelayMs
            }
        } while ($attempt -lt $task.RetryPolicy.MaxAttempts)
        $sw.Stop()
        $task.DurationMs = $sw.ElapsedMilliseconds

        if ($success) {
            $task.Status = 'Succeeded'
            Set-SubsystemState -Subsystem $task.Subsystem -State 'Healthy' -Detail "Completed $($task.Name)"
            Publish-OrchestrationEvent -EventName 'TaskCompleted' -Data @{ Task = $task.Name; DurationMs = $task.DurationMs }
            Record-TaskTransaction -Task $task -ValidationResult $true
        } else {
            $task.Status = 'Failed'
            Set-SubsystemState -Subsystem $task.Subsystem -State 'Failed' -Detail $task.Error
            Publish-OrchestrationEvent -EventName 'TaskFailed' -Data @{ Task = $task.Name; Error = $task.Error }
            if ($task.Rollback) {
                try {
                    Publish-OrchestrationEvent -EventName 'RollbackStarted' -Data @{ Task = $task.Name }
                    & $task.Rollback
                    Publish-OrchestrationEvent -EventName 'RollbackCompleted' -Data @{ Task = $task.Name }
                    $task.Status = 'RolledBack'
                } catch {}
            }
            Record-TaskTransaction -Task $task -ValidationResult $false
        }
    }

    Publish-OrchestrationEvent -EventName 'OrchestrationCompleted' -Data $null

    $failed = @($ordered.Ordered | Where-Object { $_.Status -eq 'Failed' -or $_.Status -eq 'RolledBack' })
    $recovered = $false
    if ($failed.Count -gt 0 -and -not $NoRecovery) {
        $recovered = (Invoke-RecoveryEngine -FailedTasks $failed).Success
    }

    $finalFailed = @($ordered.Ordered | Where-Object { $_.Status -eq 'Failed' -or $_.Status -eq 'RolledBack' })

    [PSCustomObject]@{
        Success    = ($finalFailed.Count -eq 0)
        Tasks      = @($ordered.Ordered)
        Failed     = @($finalFailed | ForEach-Object { $_.Name })
        Skipped    = @($ordered.Ordered | Where-Object { $_.Status -eq 'Skipped' } | ForEach-Object { $_.Name })
        Succeeded  = @($ordered.Ordered | Where-Object { $_.Status -eq 'Succeeded' } | ForEach-Object { $_.Name })
        Recovered  = $recovered
        Transaction = Get-OrchestrationTransactionLog
    }
}

# ---------------------------------------------------------------------------
# Recovery Engine
# ---------------------------------------------------------------------------

function Invoke-RecoveryEngine {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)][OrchestrationTask[]]$FailedTasks,
        [Parameter(Mandatory = $false)][string]$PrinterName
    )

    Publish-OrchestrationEvent -EventName 'RecoveryStarted' -Data @{ Tasks = @($FailedTasks | ForEach-Object { $_.Name }) }
    $recoveryTasks = [System.Collections.ArrayList]::new()

    foreach ($ft in $FailedTasks) {
        $sub = $ft.Subsystem
        if (-not $sub) { continue }
        $execSb = {
            switch ($sub) {
                'Spooler' { Stop-Service -Name Spooler -Force -ErrorAction SilentlyContinue; Start-Service -Name Spooler -ErrorAction SilentlyContinue }
                'Services' { foreach ($s in @('Spooler','LanmanServer','LanmanWorkstation','FDResPub','FDPhost','RpcSs','DcomLaunch','DNSCache','SSDPSRV','upnphost')) { Set-ServiceConfiguration -ServiceName $s -StartType Automatic -EnsureRunning -ErrorAction SilentlyContinue } }
                'Firewall' { $null = Enable-PrinterFirewallRules -IncludeIpp }
                'Network' { $p = Get-NetConnectionProfile -ErrorAction SilentlyContinue | Select-Object -First 1; if ($p) { Set-NetConnectionProfile -InterfaceIndex $p.InterfaceIndex -NetworkCategory Private -ErrorAction SilentlyContinue } }
                'Sharing' { $p = if ($PrinterName) { Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue } else { Get-Printer -ErrorAction SilentlyContinue | Select-Object -First 1 }; if ($p) { Enable-PrinterSharing -PrinterName $p.Name -ErrorAction SilentlyContinue } }
                'IPP' { Install-IPPServer -Force -ErrorAction SilentlyContinue }
                'Registry' { $path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Print'; Set-ItemProperty -Path $path -Name 'RpcAuthnLevelPrivacyEnabled' -Value 0 -Type DWord -ErrorAction SilentlyContinue; Set-ItemProperty -Path $path -Name 'DisableHTTPPrinting' -Value 0 -Type DWord -ErrorAction SilentlyContinue }
                'Driver' { Write-Log -Message 'Recovery.Driver: driver re-acquisition requires user intervention (Windows PnP)' -Level 'WARN' }
                'Printer' { Write-Log -Message 'Recovery.Printer: printer re-detection requires user intervention (connect USB)' -Level 'WARN' }
            }
        }.GetNewClosure()
        $valSb = {
            switch ($sub) {
                'Spooler' { $s = Get-Service -Name Spooler -ErrorAction SilentlyContinue; return ($s -and $s.Status -eq 'Running') }
                'Services' { foreach ($s in @('Spooler','LanmanServer','LanmanWorkstation','FDResPub','FDPhost','RpcSs','DcomLaunch','DNSCache','SSDPSRV','upnphost')) { $sv = Get-Service -Name $s -ErrorAction SilentlyContinue; if (-not ($sv -and $sv.Status -eq 'Running')) { return $false } }; return $true }
                'Firewall' { $fp = Get-NetFirewallRule -DisplayGroup 'File and Printer Sharing' -ErrorAction SilentlyContinue; $ipp = Get-NetFirewallRule -DisplayName 'IPP Printer Port 631' -ErrorAction SilentlyContinue; return (@($fp | Where-Object { $_.Enabled }).Count -gt 0 -and $ipp -and $ipp.Enabled) }
                'Network' { $p = Get-NetConnectionProfile -ErrorAction SilentlyContinue | Select-Object -First 1; return ($p -and $p.NetworkCategory -eq 'Private') }
                'Sharing' { $p = if ($PrinterName) { Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue } else { Get-Printer -ErrorAction SilentlyContinue | Where-Object { $_.Shared } | Select-Object -First 1 }; return ($p -and $p.Shared) }
                'IPP' { $s = Get-IPPStatus -ErrorAction SilentlyContinue; return ($s -and $s.IPPUrls.Count -gt 0) }
                'Registry' { $v = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Print' -Name 'RpcAuthnLevelPrivacyEnabled' -ErrorAction SilentlyContinue; return ($null -eq $v -or $v.RpcAuthnLevelPrivacyEnabled -eq 0) }
                'Driver' { $d = if ($PrinterName) { Get-DriverIntelligence -PrinterName $PrinterName -ErrorAction SilentlyContinue } else { $null }; return ($d -and $d.DriverFound) }
                'Printer' { $usb = Get-UsbPrinterInfo -ErrorAction SilentlyContinue; return ($usb -and $usb.Count -gt 0) }
                default { return $true }
            }
        }.GetNewClosure()
        $rt = New-OrchestrationTask -Name "Recover-$sub" -Category 'Recovery' -Subsystem $sub -IsCritical $false -CanSkip $true -Execute $execSb -Validate $valSb
        if ($ft.Rollback) { $rt.Rollback = $ft.Rollback }
        $null = $recoveryTasks.Add($rt)
    }

    if ($recoveryTasks.Count -eq 0) {
        return [PSCustomObject]@{ Success = $false; Attempted = 0; Reason = 'No recoverable subsystems' }
    }

    $result = Invoke-Orchestrator -Tasks @($recoveryTasks) -NoRecovery
    $success = (@($result.Tasks | Where-Object { $_.Status -eq 'Failed' }).Count -eq 0)
    Publish-OrchestrationEvent -EventName 'RecoveryCompleted' -Data @{ Success = $success }
    return [PSCustomObject]@{ Success = $success; Attempted = $recoveryTasks.Count; Result = $result }
}

# ---------------------------------------------------------------------------
# Reporting
# ---------------------------------------------------------------------------

function Get-OrchestrationReport {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)][OrchestrationTask[]]$Tasks,
        [Parameter(Mandatory = $false)]$DesiredState,
        [Parameter(Mandatory = $false)]$CurrentState
    )

    $graph = foreach ($t in $Tasks) {
        [PSCustomObject]@{
            Task         = $t.Name
            Subsystem    = $t.Subsystem
            Status       = $t.Status
            Attempts     = $t.Attempts
            DurationMs   = $t.DurationMs
            Dependencies = @($t.Dependencies)
        }
    }
    $timeline = foreach ($t in $Tasks) {
        [PSCustomObject]@{ Task = $t.Name; Status = $t.Status; DurationMs = $t.DurationMs }
    }
    $healthScore = if ($Tasks.Count -gt 0) {
        [math]::Round((@($Tasks | Where-Object { $_.Status -eq 'Succeeded' }).Count / $Tasks.Count) * 100, 1)
    } else { 100 }

    [PSCustomObject]@{
        GeneratedAt        = Get-Date
        ExecutionGraph     = @($graph)
        TaskTimeline       = @($timeline)
        ConfigurationDiff  = [PSCustomObject]@{ Desired = $DesiredState; Current = $CurrentState }
        RecoveryActions    = @($Script:OrchestrationEvents | Where-Object { $_.EventName -like 'Recovery*' })
        ValidationSummary  = [PSCustomObject]@{
            Total    = $Tasks.Count
            Succeeded = @($Tasks | Where-Object { $_.Status -eq 'Succeeded' }).Count
            Failed   = @($Tasks | Where-Object { $_.Status -eq 'Failed' }).Count
            Skipped  = @($Tasks | Where-Object { $_.Status -eq 'Skipped' }).Count
        }
        HealthScore        = $healthScore
        TransactionLog     = Get-OrchestrationTransactionLog
        PerformanceMetrics = @($Tasks | Select-Object Name, DurationMs, Attempts)
    }
}

Export-ModuleMember -Function Subscribe-OrchestrationEvent, Publish-OrchestrationEvent, Get-OrchestrationEventLog, Set-SubsystemState, Get-SubsystemState, Get-OrchestrationStateReport, Reset-OrchestrationState, New-OrchestrationTask, Get-TopologicalTaskOrder, Start-OrchestrationTransaction, Record-TaskTransaction, Get-OrchestrationTransactionLog, Get-DefaultDesiredState, Get-DesiredState, Invoke-ConfigurationProvider, Invoke-Orchestrator, Invoke-RecoveryEngine, Get-OrchestrationReport
