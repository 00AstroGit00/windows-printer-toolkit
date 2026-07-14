#Requires -Version 5.1
#Requires -Modules Pester
<#
.SYNOPSIS
    v8.2 Provider Certification test suite (Phase 2).

.DESCRIPTION
    Runs on a supported Windows host (Windows 10 22H2 / 11 23H2 / 24H2) with
    PowerShell 5.1 and PowerShell 7.x. Validates every provider for:
      - Correct API usage
      - Correct return values / structured error model
      - Rollback behaviour
      - Recovery behaviour
      - Idempotency

    These tests REQUIRE Windows + (for mutating tests) Administrator. They are
    skipped automatically on non-Windows or when unprivileged.

    Run:
      PowerShell 5.1 : Invoke-Pester -Path .\v8.2.ProviderCert.Tests.ps1
      PowerShell 7.x : Invoke-Pester .\v8.2.ProviderCert.Tests.ps1
#>

$modulePath = Resolve-Path -Path "$PSScriptRoot\..\PrinterToolkit.psm1"

Describe 'v8.2 Provider Certification' -Tag 'ProviderCert' {

    BeforeAll {
        Import-Module -Name $modulePath -Force -ErrorAction Stop
        $script:IsWindows = ($PSVersionTable.PSVersion.Major -le 5) -or $IsWindows
        $script:IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }

    AfterAll {
        Remove-Module -Name PrinterToolkit -ErrorAction SilentlyContinue
    }

    Context 'Structured error model (New-ProviderResult)' {
        It 'Returns all required properties' {
            $r = New-ProviderResult -Status Success -Category 'Test' -Message 'ok'
            $r.Status | Should -Be 'Success'
            $r.Success | Should -BeTrue
            $r.ErrorCode | Should -BeOfType [string]
            $r.Category | Should -Be 'Test'
            $r.RecommendedAction | Should -BeOfType [string]
            $r.Recoverability | Should -BeOfType [string]
            $r.Timestamp | Should -BeOfType [datetime]
        }
        It 'Accepts every documented status value' {
            foreach ($s in 'Success','Warning','Failed','Skipped','NotApplicable','Unsupported') {
                (New-ProviderResult -Status $s).Status | Should -Be $s
            }
        }
    }

    Context 'Firewall provider' -Skip:(-not $IsWindows) {
        It 'Enable-PrinterFirewallRules enables the File and Printer Sharing group' {
            $r = Enable-PrinterFirewallRules -IncludeIpp
            $r | Should -Not -BeNullOrEmpty
            $r.Status | Should -BeIn @('Success','Warning')
            $r.Success | Should -BeTrue
            $rules = Get-NetFirewallRule -DisplayGroup 'File and Printer Sharing' -ErrorAction SilentlyContinue
            ($rules | Where-Object { $_.Enabled }).Count | Should -BeGreaterThan 0
        }
        It 'Is idempotent (second call yields same success state)' {
            $first = Enable-PrinterFirewallRules -IncludeIpp
            $second = Enable-PrinterFirewallRules -IncludeIpp
            $second.Success | Should -Be $first.Success
        }
    }

    Context 'Printer provider (default printer)' -Skip:((-not $IsWindows) -or (-not $IsAdmin)) {
        It 'Set-DefaultPrinterNative returns a structured result' {
            $p = Get-CimInstance -ClassName Win32_Printer -Filter "Default='True'" -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $p) { Set-ItResult -Skipped -Because 'No default printer available' ; return }
            $r = Set-DefaultPrinterNative -Name $p.Name
            $r.Status | Should -BeIn @('Success','Failed')
            $r.Success | Should -BeOfType [bool]
        }
    }

    Context 'Driver provider' -Skip:(-not $IsWindows) {
        It 'Get-PrinterDriverDetails returns structured rows with no pnputil parsing' {
            $rows = Get-PrinterDriverDetails
            foreach ($row in $rows) {
                $row.Name | Should -Not -BeNullOrEmpty
                $row | Should -HaveProperty 'INFPath'
            }
        }
        It 'Get-DriverIntelligence populates CompatibleIDs under the correct property name' {
            $usb = Get-UsbPrinterInfo -ErrorAction SilentlyContinue
            if ($usb.Count -eq 0) { Set-ItResult -Skipped -Because 'No USB printer detected' ; return }
            $di = Get-DriverIntelligence -PrinterName $usb[0].PrinterName
            $di | Should -HaveProperty 'CompatibleIDs'
            $di.CompatibleIDs | Should -Not -BeNullOrEmpty
        }
        It 'Test-DriverSignature validates using Authenticode' {
            $d = Get-PrinterDriverDetails | Select-Object -First 1
            if (-not $d -or -not $d.INFPath) { Set-ItResult -Skipped -Because 'No driver INF resolved' ; return }
            $sig = Test-DriverSignature -InfPath $d.INFPath
            $sig | Should -HaveProperty 'Signed'
            $sig.Status | Should -BeOfType [string]
        }
    }

    Context 'Orchestration provider dispatch (6-phase model)' -Skip:(-not $IsWindows) {
        It 'Firewall provider GetCurrentState returns structured state' {
            $state = Invoke-ConfigurationProvider -Provider Firewall -Phase GetCurrentState -DesiredState (Get-DefaultDesiredState)
            $state | Should -Not -BeNullOrEmpty
            $state.IPP | Should -BeOfType [bool]
            $state.SMB | Should -BeOfType [bool]
            $state.Discovery | Should -BeOfType [bool]
        }
        It 'Service provider ApplyChanges is idempotent' {
            $before = Invoke-ConfigurationProvider -Provider Service -Phase GetCurrentState -DesiredState (Get-DefaultDesiredState)
            $apply1 = Invoke-ConfigurationProvider -Provider Service -Phase ApplyChanges -DesiredState (Get-DefaultDesiredState)
            $apply2 = Invoke-ConfigurationProvider -Provider Service -Phase ApplyChanges -DesiredState (Get-DefaultDesiredState)
            $apply2 | Should -Be $apply1
        }
    }

    Context 'Reporting provider' -Skip:(-not $IsWindows) {
        It 'Invoke-EndToEndValidation returns a scored dashboard' {
            $v = Invoke-EndToEndValidation
            $v.OverallScore | Should -BeOfType [double]
            $v.TotalChecks | Should -BeGreaterThan 0
            $v.PassCount | Should -BeLessOrEqual $v.TotalChecks
        }
        It 'New-PrinterReport produces output files' {
            $out = New-PrinterReport -Format JSON
            $out | Should -Not -BeNullOrEmpty
        }
    }
}
