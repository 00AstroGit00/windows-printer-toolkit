$ErrorActionPreference = 'Continue'

$moduleName = 'PrinterToolkit'

Write-Host "Uninstalling $moduleName..." -ForegroundColor Cyan

# Find all installations
$searchPaths = @(
    Join-Path -Path ([Environment]::GetFolderPath('MyDocuments')) -ChildPath 'WindowsPowerShell\Modules\PrinterToolkit'
    Join-Path -Path ([Environment]::GetFolderPath('MyDocuments')) -ChildPath 'PowerShell\Modules\PrinterToolkit'
    Join-Path -Path $env:ProgramFiles -ChildPath 'WindowsPowerShell\Modules\PrinterToolkit'
    Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath 'WindowsPowerShell\Modules\PrinterToolkit'
)

foreach ($path in $searchPaths) {
    if (Test-Path $path) {
        Write-Host "  Removing: $path" -ForegroundColor Yellow
        try {
            Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
            Write-Host "  [OK] Removed" -ForegroundColor Green
        } catch {
            Write-Host "  [WARN] Could not remove: $_" -ForegroundColor Yellow
        }
    }
}

# Check if module is currently loaded and remove it
if (Get-Module -Name $moduleName -ErrorAction SilentlyContinue) {
    Remove-Module -Name $moduleName -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host 'PrinterToolkit has been uninstalled.' -ForegroundColor Cyan
