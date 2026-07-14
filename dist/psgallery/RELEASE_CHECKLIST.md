# PowerShell Gallery — Release Checklist

## Pre-Publish

- [ ] `ModuleVersion` bumped in `PrinterToolkit.psd1` (current: 5.0.1)
- [ ] Module version also updated in:
  - `PrinterToolkit.psm1` — `$Script:ToolkitVersion`
  - `CI/build.ps1` — artifact path header
  - `CI/package.ps1` — default `$Version`
  - `install.ps1`, `launcher.ps1` — console output headers
  - `README.md` — badges, architecture diagram, download links
  - `CHANGELOG.md` — new version entry
- [ ] `FunctionsToExport` matches actual `Export-ModuleMember` across all modules
- [ ] No wildcards in `FunctionsToExport`
- [ ] `GUID` is stable (same across all versions)
- [ ] `LicenseUri` and `ProjectUri` point to the correct repository
- [ ] `Tags` include: `Printer`, `Print`, `Printing`, `Diagnostics`, `Windows`, `Troubleshooting`, `IPP`, `Mopria`, `Android`
- [ ] `ReleaseNotes` updated with current version changelog
- [ ] `IconUri` points to a valid image URL
- [ ] `Description` is accurate and up to date

## Validation

- [ ] `Test-ModuleManifest -Path .\PrinterToolkit.psd1` passes
- [ ] `Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error` has zero errors
- [ ] `Invoke-Pester .\Tests\PrinterToolkit.Tests.ps1` — all 49 pass
- [ ] Module imports cleanly: `Import-Module .\PrinterToolkit.psd1 -Force`
- [ ] All 55 functions are available: `Get-Command -Module PrinterToolkit | Measure-Object`

## Publish

```powershell
# Set TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Publish
Publish-Module -Path .\PrinterToolkit -NuGetApiKey (Get-Content .\api_key.txt)

# Or use the automation script
.\dist\psgallery\Publish-PrtkToGallery.ps1 -ApiKey (Get-Content .\api_key.txt)
```

## Post-Publish

- [ ] Verify on `https://www.powershellgallery.com/packages/PrinterToolkit`
- [ ] `Find-Module PrinterToolkit` returns the new version
- [ ] `Install-Module PrinterToolkit` works in a clean environment
- [ ] `Update-Module PrinterToolkit` upgrades from previous version
- [ ] GitHub Release created with ZIP + SHA256SUMS
- [ ] Announcement posted (if applicable)

## Rollback

If the published module has a critical bug:

```powershell
# Unpublishing is not supported by the Gallery.
# Instead, publish a new patch version with the fix.
# Update ModuleVersion to 5.3.1 and repeat the process.
```
