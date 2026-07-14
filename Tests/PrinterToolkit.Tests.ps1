<#
.SYNOPSIS
    Pester tests for PrinterToolkit v5.0.1 modules.

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
    $Script:TestRoot = Join-Path -Path $env:TEMP -ChildPath "PTTest_$([System.IO.Path]::GetRandomFileName())"
    $null = New-Item -ItemType Directory -Force -Path $Script:TestRoot -ErrorAction SilentlyContinue
}

AfterAll {
    if ($Script:TestRoot -and (Test-Path $Script:TestRoot)) {
        Remove-Item -Path $Script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'Module Loading' {
    It 'Should load the root module' {
        Get-Module PrinterToolkit | Should -Not -BeNullOrEmpty
    }

    It 'Should have version 5.0.x' {
        (Get-Module PrinterToolkit).Version | Should -BeLike '5.0.*'
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

    It 'Get-PrinterStatus should return a PSCustomObject with expected properties' {
        $result = Get-PrinterStatus
        $result.SpoolerStatus | Should -Not -BeNullOrEmpty
        $result.PrinterCount -is [int] | Should -Be $true
        $result.Timestamp | Should -Not -BeNullOrEmpty
    }

    It 'Get-SharedPrinters should not throw' {
        { $result = Get-SharedPrinters -ErrorAction SilentlyContinue } | Should -Not -Throw
    }

    It 'Clear-PrintQueue with -Force should handle missing spool path' {
        Mock -ModuleName 'PrinterToolkit.Core' Test-Path { return $false }
        $result = Clear-PrintQueue -Force
        $result -is [int] | Should -Be $true
    }

    It 'Restart-Spooler should return a PSCustomObject' {
        Mock -ModuleName 'PrinterToolkit.Core' Stop-Spooler { return $true }
        Mock -ModuleName 'PrinterToolkit.Core' Start-Spooler { return $true }
        $result = Restart-Spooler
        $result.Success | Should -Be $true
    }
}

Describe 'Utilities Module' {
    It 'Test-Administrator should return boolean' {
        Test-Administrator -is [bool] | Should -Be $true
    }

    It 'Test-Elevated calls Test-Administrator' {
        Test-Elevated | Should -Be (Test-Administrator)
    }

    It 'Get-SystemInfo should include computer name' {
        $result = Get-SystemInfo
        $result.ComputerName | Should -Be $env:COMPUTERNAME
    }

    It 'Assert-Elevated should not throw when admin' {
        Mock Test-Administrator { return $true }
        { Assert-Elevated } | Should -Not -Throw
    }

    It 'Assert-Elevated should throw when not admin' {
        Mock Test-Administrator { return $false }
        { Assert-Elevated } | Should -Throw
    }
}

Describe 'IPP Module' {
    It 'Test-IPPClientInstalled should not throw' {
        { $result = Test-IPPClientInstalled -ErrorAction SilentlyContinue } | Should -Not -Throw
    }

    It 'Get-IPPStatus should return a PSCustomObject' {
        $result = Get-IPPStatus -ErrorAction SilentlyContinue
        $result -is [PSCustomObject] | Should -Be $true
    }

    It 'Get-IPPUrls should return an array' {
        $result = Get-IPPUrls -ErrorAction SilentlyContinue
        $result -is [array] | Should -Be $true
    }

    It 'Test-IPPEndpoint requires -Url parameter' {
        $params = (Get-Command Test-IPPEndpoint).Parameters
        $params['Url'].Attributes.Mandatory | Should -Be $true
    }
}

Describe 'Logging Module' {
    BeforeEach {
        $Script:TestLogPath = Join-Path -Path $Script:TestRoot -ChildPath 'test.log'
    }

    AfterEach {
        if (Test-Path $Script:TestLogPath) {
            Remove-Item -Path $Script:TestLogPath -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Initialize-Logging should set log directory' {
        $logDir = Join-Path -Path $Script:TestRoot -ChildPath 'logs'
        Initialize-Logging -Path $logDir
        Get-LogFilePath | Should -Not -BeNullOrEmpty
    }

    It 'Write-Log should write entries to file' {
        $logDir = Join-Path -Path $Script:TestRoot -ChildPath 'logs'
        Initialize-Logging -Path $logDir
        Write-Log -Message 'Test message' -Level 'INFO'
        $logFile = Get-LogFilePath
        Test-Path $logFile.Path | Should -Be $true
    }

    It 'Get-LogFilePath should return PSCustomObject with Path and Exists' {
        $logDir = Join-Path -Path $Script:TestRoot -ChildPath 'logs'
        Initialize-Logging -Path $logDir
        $info = Get-LogFilePath
        $info.Path | Should -Not -BeNullOrEmpty
        $info.Exists | Should -Be $true
    }

    It 'Get-LogContent should filter by level' {
        $logDir = Join-Path -Path $Script:TestRoot -ChildPath 'logs'
        Initialize-Logging -Path $logDir
        Write-Log -Message 'Error test' -Level 'ERROR'
        $errors = Get-LogContent -Level 'ERROR'
        $errors | Should -Not -BeNullOrEmpty
    }

    It 'Export-LogArchive should create a zip' {
        $logDir = Join-Path -Path $Script:TestRoot -ChildPath 'logs'
        Initialize-Logging -Path $logDir
        Write-Log -Message 'Archive test' -Level 'INFO'
        $dest = Join-Path -Path $Script:TestRoot -ChildPath 'archive.zip'
        $result = Export-LogArchive -Destination $dest
        $result | Should -Not -BeNullOrEmpty
        Test-Path $result | Should -Be $true
    }
}

Describe 'Diagnostics Module' {
    It 'Get-NetworkValidation should return a PSCustomObject with score' {
        $result = Get-NetworkValidation -ErrorAction SilentlyContinue
        $result -is [PSCustomObject] | Should -Be $true
        $result.OverallScore -is [double] | Should -Be $true
    }

    It 'Show-NetworkValidationReport should not throw' {
        { Show-NetworkValidationReport -ErrorAction SilentlyContinue } | Should -Not -Throw
    }

    It 'Export-FirewallSnapshot should not throw' {
        { Export-FirewallSnapshot -ErrorAction SilentlyContinue } | Should -Not -Throw
    }

    It 'Export-ServiceSnapshot should not throw' {
        { Export-ServiceSnapshot } | Should -Not -Throw
    }
}

Describe 'Repair Module' {
    It 'Initialize-RepairBackup should exist and accept pipeline' {
        Get-Command Initialize-RepairBackup -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }

    It 'Invoke-AutomaticShareRepair should have a -TestMode switch' {
        $cmd = Get-Command Invoke-AutomaticShareRepair -ErrorAction SilentlyContinue
        $cmd.Parameters['TestMode'].SwitchParameter | Should -Be $true
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

    It 'Export-PrinterDrivers should exist and have -OutputPath parameter' {
        $cmd = Get-Command Export-PrinterDrivers -ErrorAction SilentlyContinue
        $cmd.Parameters.ContainsKey('OutputPath') | Should -Be $true
    }

    It 'Restore-PrinterDrivers should validate path' {
        { Restore-PrinterDrivers -SourcePath 'Z:\nonexistent' -ErrorAction Stop } | Should -Throw
    }

    It 'Install-PrinterDriverFromInf should validate path' {
        { Install-PrinterDriverFromInf -InfPath 'Z:\nonexistent.inf' -ErrorAction Stop } | Should -Throw
    }

    It 'Remove-PrinterDriverByName should validate pattern' {
        { Remove-PrinterDriverByName -DriverName 'bad|name' -ErrorAction Stop } | Should -Throw
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

    It 'Enable-PrinterSharing should return Success=false for missing printer' {
        Mock -ModuleName 'PrinterToolkit.Sharing' Assert-Elevated { return $null }
        Mock Get-Printer { return $null } -ModuleName 'PrinterToolkit.Sharing'
        $result = Enable-PrinterSharing -PrinterName 'Nonexistent_Test'
        $result.Success | Should -Be $false
    }

    It 'Disable-PrinterSharing should return Success=false for missing printer' {
        Mock -ModuleName 'PrinterToolkit.Sharing' Assert-Elevated { return $null }
        Mock Get-Printer { return $null } -ModuleName 'PrinterToolkit.Sharing'
        $result = Disable-PrinterSharing -PrinterName 'Nonexistent_Test'
        $result.Success | Should -Be $false
    }
}

Describe 'Reporting Module' {
    It 'Get-PrintComplianceReport should return an array' {
        $result = Get-PrintComplianceReport
        $result -is [array] | Should -Be $true
    }
}

Describe 'New-PrinterReport' {
    It 'should generate files with -Format All' {
        $reportDir = Join-Path -Path $Script:TestRoot -ChildPath 'report'
        $files = New-PrinterReport -Format 'All' -OutputPath $reportDir
        $files | Should -Not -BeNullOrEmpty
    }
}

Describe 'Bundle Module' {
    It 'New-DiagnosticBundle function should exist' {
        Get-Command New-DiagnosticBundle -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }

    It 'New-DiagnosticBundle should have -OutputPath parameter' {
        $cmd = Get-Command New-DiagnosticBundle -ErrorAction SilentlyContinue
        $cmd.Parameters.ContainsKey('OutputPath') | Should -Be $true
    }
}

Describe 'Android Module' {
    It 'Get-AndroidCompatibility should return a PSCustomObject' {
        $result = Get-AndroidCompatibility -ErrorAction SilentlyContinue
        $result -is [PSCustomObject] | Should -Be $true
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
    It 'Get-ToolkitStatus should show version 5.0.x' {
        $status = Get-ToolkitStatus
        $status.Version | Should -BeLike '5.0.*'
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
