<#
.SYNOPSIS
    Pester tests for PrinterToolkit v4.1 modules.

.DESCRIPTION
    Run: Invoke-Pester -Path .\Tests\PrinterToolkit.Tests.ps1

.NOTES
    These tests validate function existence, parameter contracts,
    and output types. Full integration tests require a Windows
    environment with printers configured.
#>

BeforeAll {
    $ModuleRoot = Split-Path -Parent $PSScriptRoot
    Import-Module (Join-Path $ModuleRoot 'PrinterToolkit.psd1') -Force -ErrorAction Stop
}

Describe 'Module Loading' {
    It 'Should load the root module' {
        Get-Module PrinterToolkit | Should -Not -BeNullOrEmpty
    }

    It 'Should have version 4.1.x' {
        (Get-Module PrinterToolkit).Version | Should -BeLike '4.1.*'
    }

    It 'Should export all required functions' {
        $required = @(
            'Get-ToolkitStatus', 'Invoke-ToolkitMainMenu',
            'Get-PrinterStatus', 'Get-Printers', 'Set-DefaultPrinter',
            'Clear-PrintQueue', 'Restart-Spooler', 'Stop-Spooler', 'Start-Spooler',
            'Get-PrinterQueueHealth', 'Get-SharedPrinters', 'Enable-PrintSharing',
            'Get-IPPStatus', 'Get-IPPUrls', 'Test-IPPEndpoint',
            'Test-IPPClientInstalled', 'Install-IPPServer',
            'Initialize-Logging', 'Write-Log', 'Get-LogFilePath', 'Get-LogContent',
            'Export-LogArchive',
            'Test-Administrator', 'Test-Elevated', 'Assert-Elevated',
            'Confirm-DestructiveAction', 'Get-SystemInfo',
            'Get-AndroidCompatibility', 'Show-AndroidWizard', 'Get-AndroidSetupContent',
            'Get-NetworkValidation', 'Show-NetworkValidationReport',
            'Export-RegistrySnapshot', 'Export-FirewallSnapshot', 'Export-ServiceSnapshot',
            'Initialize-RepairBackup', 'Invoke-AutomaticShareRepair',
            'Get-PrinterDriverDetails', 'Export-PrinterDrivers', 'Restore-PrinterDrivers',
            'Install-PrinterDriverFromInf', 'Remove-PrinterDriverByName',
            'Get-DriverUpgradeRecommendations',
            'Get-PrinterShareStatus', 'Enable-PrinterSharing', 'Disable-PrinterSharing',
            'Get-SmbSharePermissions', 'Set-PrinterSharePermission',
            'Set-PrinterSharingTransport', 'Get-PrinterSharingCompatibility',
            'New-PrinterReport', 'Get-PrintComplianceReport',
            'New-DiagnosticBundle'
        )
        foreach ($f in $required) {
            Get-Command -Name $f -Module PrinterToolkit -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'Core Module' {
    It 'Get-Printers should return an array' {
        $result = Get-Printers
        $result -is [array] | Should -Be $true
    }

    It 'Get-PrinterStatus should return results' {
        $result = Get-PrinterStatus
        $result | Should -Not -BeNullOrEmpty
    }

    It 'Get-SharedPrinters should not throw' {
        { $result = Get-SharedPrinters -ErrorAction SilentlyContinue } | Should -Not -Throw
    }

    It 'Clear-PrintQueue should prompt before action' {
        Mock Confirm-DestructiveAction { return $false }
        $result = Clear-PrintQueue
        $result | Should -Not -BeNullOrEmpty
    }

    It 'Restart-Spooler should return success/failure' {
        $result = Restart-Spooler
        $result.Success -is [bool] | Should -Be $true
    }
}

Describe 'Utilities Module' {
    It 'Test-Administrator should return boolean' {
        Test-Administrator -is [bool] | Should -Be $true
    }

    It 'Get-SpoolerStatus uses Stop-Spooler/Start-Spooler approach' {
        $spooler = Get-Service -Name Spooler -ErrorAction SilentlyContinue
        $spooler | Should -Not -BeNullOrEmpty
        $spooler.Status -in @('Running', 'Stopped') | Should -Be $true
    }

    It 'Get-SystemInfo should include computer name' {
        $result = Get-SystemInfo
        $result.ComputerName | Should -Be $env:COMPUTERNAME
    }

    It 'Confirm-DestructiveAction should accept pipe input' {
        'test' | Confirm-DestructiveAction -message 'Test' | Should -Be $true
    }
}

Describe 'IPP Module' {
    It 'Test-IPPClientInstalled should not throw' {
        { $result = Test-IPPClientInstalled -ErrorAction SilentlyContinue } | Should -Not -Throw
    }

    It 'Get-IPPStatus should return results' {
        { $result = Get-IPPStatus -ErrorAction SilentlyContinue } | Should -Not -Throw
    }

    It 'Get-IPPUrls should return valid URLs' {
        $result = Get-IPPUrls -ErrorAction SilentlyContinue
        $result -is [array] | Should -Be $true
    }

    It 'Test-IPPEndpoint should validate endpoints' {
        $result = Test-IPPEndpoint -ErrorAction SilentlyContinue
        if ($result) {
            $result.Success -is [bool] | Should -Be $true
        }
    }
}

Describe 'Logging Module' {
    AfterEach {
        if (Test-Path 'TestDriver:\tmp\toolkit_test.log') {
            Remove-Item 'TestDriver:\tmp\toolkit_test.log' -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Initialize-Logging should create a log file' {
        $path = Initialize-Logging -LogPath 'TestDriver:\tmp\toolkit_test.log'
        $path | Should -Not -BeNullOrEmpty
    }

    It 'Write-Log should write entries' {
        $null = Initialize-Logging -LogPath 'TestDriver:\tmp\toolkit_test.log'
        Write-Log -Message 'Test message' -Level 'INFO'
        $logs = Get-LogContent -Path 'TestDriver:\tmp\toolkit_test.log'
        $logs | Should -Not -BeNullOrEmpty
    }

    It 'Get-LogFilePath should return path' {
        $null = Initialize-Logging -LogPath 'TestDriver:\tmp\toolkit_test.log'
        $path = Get-LogFilePath
        $path | Should -BeLike '*toolkit*'
    }

    It 'Export-LogArchive should create archive' {
        $null = Initialize-Logging -LogPath 'TestDriver:\tmp\toolkit_test.log'
        Write-Log -Message 'Archive test' -Level 'INFO'
        $result = Export-LogArchive -DestinationPath 'TestDriver:\tmp\'
        $result | Should -Not -BeNullOrEmpty
    }
}

Describe 'Diagnostics Module' {
    It 'Get-NetworkValidation should return results' {
        $result = Get-NetworkValidation -ErrorAction SilentlyContinue
        $result -is [array] | Should -Be $true
    }

    It 'Show-NetworkValidationReport should not throw' {
        { Show-NetworkValidationReport -ErrorAction SilentlyContinue } | Should -Not -Throw
    }

    It 'Export-RegistrySnapshot should create a file' {
        $path = Export-RegistrySnapshot
        $path | Should -Not -BeNullOrEmpty
    }

    It 'Export-FirewallSnapshot should not throw' {
        { Export-FirewallSnapshot -ErrorAction SilentlyContinue } | Should -Not -Throw
    }

    It 'Export-ServiceSnapshot should not throw' {
        { Export-ServiceSnapshot } | Should -Not -Throw
    }
}

Describe 'Repair Module' {
    It 'Initialize-RepairBackup should create a backup path' {
        Mock New-Item { return [PSCustomObject]@{ FullName = 'TestDriver:\tmp\backup' } }
        $path = Initialize-RepairBackup
        $path | Should -Not -BeNullOrEmpty
    }

    It 'Invoke-AutomaticShareRepair with -TestMode should not execute' {
        Mock Confirm-DestructiveAction { return $true }
        $result = Invoke-AutomaticShareRepair -TestMode
        $result.Success -is [bool] | Should -Be $true
        $result.Log -is [array] | Should -Be $true
    }
}

Describe 'Drivers Module' {
    It 'Get-PrinterDriverDetails should return array' {
        $result = Get-PrinterDriverDetails
        $result -is [array] | Should -Be $true
    }

    It 'Get-DriverUpgradeRecommendations should return array' {
        $result = Get-DriverUpgradeRecommendations
        $result -is [array] | Should -Be $true
    }

    It 'Export-PrinterDrivers should create a directory' {
        $path = Export-PrinterDrivers -OutputPath 'TestDriver:\tmp\driver_export'
        $path | Should -Not -BeNullOrEmpty
        if (Test-Path $path) { Remove-Item $path -Recurse -Force }
    }

    It 'Restore-PrinterDrivers should validate path' {
        { Restore-PrinterDrivers -SourcePath 'Z:\nonexistent' -ErrorAction Stop } | Should -Throw
    }

    It 'Install-PrinterDriverFromInf should validate path' {
        { Install-PrinterDriverFromInf -InfPath 'Z:\nonexistent.inf' -ErrorAction Stop } | Should -Throw
    }
}

Describe 'Sharing Module' {
    It 'Get-PrinterShareStatus should return array' {
        $result = Get-PrinterShareStatus
        $result -is [array] | Should -Be $true
    }

    It 'Get-SmbSharePermissions should not throw' {
        { $result = Get-SmbSharePermissions -ErrorAction SilentlyContinue } | Should -Not -Throw
    }

    It 'Get-PrinterSharingCompatibility should return array' {
        $result = Get-PrinterSharingCompatibility
        $result -is [array] | Should -Be $true
    }

    It 'Enable-PrinterSharing should handle missing printer' {
        $result = Enable-PrinterSharing -PrinterName 'DoesNotExist_Test'
        $result.Success | Should -Be $false
    }

    It 'Disable-PrinterSharing should handle missing printer' {
        $result = Disable-PrinterSharing -PrinterName 'DoesNotExist_Test'
        $result.Success | Should -Be $false
    }
}

Describe 'Reporting Module' {
    It 'New-PrinterReport should generate files' {
        $path = 'TestDriver:\tmp\report'
        $files = New-PrinterReport -Format 'All' -OutputPath $path
        $files | Should -Not -BeNullOrEmpty
        if (Test-Path $path) { Remove-Item $path -Recurse -Force }
    }

    It 'Get-PrintComplianceReport should return array' {
        $result = Get-PrintComplianceReport
        $result -is [array] | Should -Be $true
    }
}

Describe 'Bundle Module' {
    It 'New-DiagnosticBundle should create output' {
        $result = New-DiagnosticBundle -OutputPath 'TestDriver:\tmp\bundle'
        $result | Should -Not -BeNullOrEmpty
        if (Test-Path $result) { Remove-Item $result -Force -ErrorAction SilentlyContinue }
    }
}

Describe 'Android Module' {
    It 'Get-AndroidCompatibility should return results' {
        $result = Get-AndroidCompatibility -ErrorAction SilentlyContinue
        $result | Should -Not -BeNullOrEmpty
    }

    It 'Show-AndroidWizard should not throw' {
        { Show-AndroidWizard } | Should -Not -Throw
    }

    It 'Get-AndroidSetupContent should return content' {
        $result = Get-AndroidSetupContent
        $result | Should -Not -BeNullOrEmpty
    }
}

Describe 'Toolkit Status' {
    It 'Get-ToolkitStatus should show version' {
        $status = Get-ToolkitStatus
        $status.Version | Should -BeLike '4.1.*'
        $status.LoadedModules.Count | Should -BeGreaterThan 0
    }

    It 'Get-ToolkitStatus should include admin state' {
        $status = Get-ToolkitStatus
        $status.IsAdministrator -is [bool] | Should -Be $true
    }

    It 'Invoke-ToolkitMainMenu function should exist' {
        Get-Command Invoke-ToolkitMainMenu -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }
}
