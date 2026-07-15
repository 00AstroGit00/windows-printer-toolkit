# Compatibility Watchlist — PrinterToolkit v8.3 LTS

> **Purpose:** Identify Windows components that may change or be deprecated in future OS releases, potentially breaking PrinterToolkit functionality.
>
> **Risk categories:**
> - **Deprecation risk:** Component may be removed or replaced in a future Windows release.
> - **Behavior change risk:** Component may change behavior without being removed.
> - **Permission risk:** Component may require additional permissions or execution context.
> - **Availability risk:** Component may not be available in all Windows editions (e.g., Windows 10 Home vs Server).

---

## 1. PrintManagement PowerShell Module

| Field | Value |
|-------|-------|
| **Dependency** | `Get-Printer`, `Set-Printer`, `Remove-Printer`, `Get-PrinterDriver`, `Add-PrinterDriver`, `Get-PrinterPort`, `Add-PrinterPort`, `Get-PrintConfiguration` |
| **Module** | `PrintManagement` (built-in Windows module) |
| **Used in** | Core, Detection, Drivers, IPP, Sharing, Android modules |
| **Risk** | **Low** — This module is part of the Windows print stack (introduced in Windows 8/2012). Microsoft has shown no intent to deprecate it. However, new Windows print paradigms (Universal Print, Modern Print) may reduce reliance on local print management. |
| **Watch for** | Windows 12 or later: potential feature deprecation in favor of cloud print APIs. Behavior freeze expected through at least Windows 11 + 5 years. |
| **Fallback** | CIM/WMI: `Get-CimInstance Win32_Printer`, `Get-CimInstance Win32_PrinterDriver` |
| **Detection** | Test command availability: `Get-Command -Module PrintManagement -ErrorAction SilentlyContinue` |

## 2. NetSecurity PowerShell Module

| Field | Value |
|-------|-------|
| **Dependency** | `Get-NetFirewallRule`, `Enable-NetFirewallRule`, `Disable-NetFirewallRule`, `New-NetFirewallRule` |
| **Module** | `NetSecurity` (built-in Windows module) |
| **Used in** | Networking, Providers, Orchestration modules |
| **Risk** | **Low** — This module is deeply integrated into Windows Defender Firewall management. Microsoft has shown no deprecation intent. |
| **Watch for** | PowerShell 7 (`pwsh`) on Windows — confirm `NetSecurity` module is importable. It is a Windows-only module and not available on Linux/macOS, which is acceptable for a Windows-only tool. |
| **Fallback** | `netsh advfirewall` (deprecated but still present). CIM: `Get-CimInstance -ClassName MSFT_NetFirewallRule -Namespace Root/StandardCimv2` |
| **Detection** | `Get-Module -ListAvailable NetSecurity` |

## 3. CIM/WMI Classes

| Field | Value |
|-------|-------|
| **Dependencies** | `Win32_Printer`, `Win32_PrinterDriver`, `Win32_OperatingSystem`, `Win32_ComputerSystem`, `Win32_NetworkAdapterConfiguration`, `Win32_PnPEntity`, `Win32_USBControllerDevice`, `Win32_PrintJob`, `Win32_Service`, `Win32_NetworkProfile` (via NetConnection), `MSFT_NetFirewallRule` |
| **Namespace** | `Root\Cimv2`, `Root\StandardCimv2` |
| **Used in** | Core, Detection, Drivers, Diagnostics, Networking, Providers modules |
| **Risk** | **Low-Medium.** WMI has been present since Windows NT 4.0 and is unlikely to be removed. However, PowerShell 7 uses CIM cmdlets via WS-Management which may have different default settings: |
| | - `Get-CimInstance` replaces `Get-WmiObject` (deprecated in PowerShell 7) |
| | - CIM sessions require DCOM or WSMan configuration |
| | - Some classes (`Win32_NetworkProfile`) are not available on all editions |
| **Watch for** | Microsoft migrating management APIs to WinRT/Microsoft.Management.Infrastructure. WMI/CIM continues to be supported for backward compatibility. |
| **Fallback** | Registry: `HKLM\SYSTEM\CurrentControlSet\...` for some settings. Direct WinRT APIs. |
| **Detection** | `Get-CimClass -ClassName Win32_Printer -ErrorAction SilentlyContinue` |

## 4. DISM PowerShell Module

| Field | Value |
|-------|-------|
| **Dependency** | `Get-WindowsDriver`, `Enable-WindowsOptionalFeature`, `Disable-WindowsOptionalFeature` |
| **Module** | `Dism` (built-in) |
| **Used in** | Providers (`Get-PrinterDriverStoreDetails`), Configuration (`Set-WindowsFeature`) |
| **Risk** | **Low.** DISM is a core Windows servicing component. It is not going away. However: |
| | - The `Dism` PowerShell module must be imported explicitly on some Windows SKUs |
| | - `Get-WindowsDriver` requires Administrator elevation |
| | - The `Dism` module may not be available in Windows PE / Recovery Environment |
| **Watch for** | DISM API changes in future Windows releases. The PowerShell module wrapper may be replaced by newer servicing APIs. |
| **Fallback** | `dism.exe /image:` command-line. Also: `Get-CimInstance Win32_OptionalFeature` for feature state. |
| **Detection** | `Get-Module -ListAvailable Dism` |

## 5. Windows Features (Optional Features)

| Field | Value |
|-------|-------|
| **Dependencies** | `Printing-Foundation-Features` (includes Print Services), `Printing-Foundation-InternetPrinting-Client` (IPP Client), `Printing-Foundation-InternetPrinting-Server` (IPP Server), `Printing-PrintToPDFServices-Features`, `Microsoft-Windows-Printing-Subsystem`, `SMB1Protocol` |
| **Used in** | Configuration (IPP, SMB modules) |
| **Risk** | **Medium.** Feature names may change between Windows versions. For example: |
| | - Windows 10 1809 renamed some print features |
| | - IPP features may be reorganized in Windows 12 |
| | - SMB1Protocol is being phased out (disabled by default since Windows 10 1709, may be removed entirely) |
| **Watch for** | New Windows builds changing feature names. The `Get-WindowsOptionalFeature -Online` command should always be verified against target OS. |
| **Fallback** | Service-based detection (`Get-Service`) for features that start services. Registry: `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\...` |
| **Detection** | `Get-WindowsOptionalFeature -Online -FeatureName *Print*` |

## 6. Services

| Field | Value |
|-------|-------|
| **Dependencies** | `Spooler`, `LanmanServer`, `LanmanWorkstation`, `FDResPub` (Function Discovery Resource Publication), `FDPhost` (Function Discovery Provider Host), `RpcSs` (RPC Endpoint Mapper), `DcomLaunch`, `DNSCache`, `SSDPSRV`, `upnphost` (UPnP Device Host), `PrintNotify` |
| **Used in** | Every module |
| **Risk** | **Low-Medium.** Windows service names have been stable for decades. However: |
| | - Some services may be removed or merged (e.g., `upnphost` may be deprecated) |
| | - Service start types may become restricted in future Windows versions |
| | - `PrintNotify` is not present on all Windows editions |
| **Watch for** | Windows 12 service consolidation. `FDResPub` and `FDPhost` are candidates for deprecation in favor of mDNS/DNS-SD. |
| **Fallback** | CIM: `Get-CimInstance Win32_Service`. Direct API: `OpenSCManager` via P/Invoke. |
| **Detection** | `Get-Service -Name Spooler -ErrorAction SilentlyContinue` |

## 7. Network Profile Management

| Field | Value |
|-------|-------|
| **Dependency** | `Get-NetConnectionProfile`, `Set-NetConnectionProfile` |
| **Module** | `NetConnection` (built-in) |
| **Used in** | Networking, Orchestration |
| **Risk** | **Medium.** Network profile cmdlets require specific permissions: |
| | - `Set-NetConnectionProfile` requires Administrator elevation |
| | - Some network adapters may not support category change (e.g., domain-joined adapters) |
| | - The `NetConnection` module may not be available in Windows Server Core |
| **Watch for** | PowerShell 7 compatibility with `NetConnection` module. |
| **Fallback** | `netsh advfirewall set allprofiles` + registry: `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\NetworkList\Profiles\...` |
| **Detection** | `Get-Command Get-NetConnectionProfile -ErrorAction SilentlyContinue` |

## 8. SMB Protocol

| Field | Value |
|-------|-------|
| **Dependency** | SMB 1.0/CIFS File Sharing Support, `Get-SmbShare`, `Set-SmbShare`, `Grant-SmbShareAccess`, `Revoke-SmbShareAccess`, `Block-SmbShareAccess` |
| **Module** | `SmbShare` (built-in) |
| **Used in** | SMB, Sharing modules |
| **Risk** | **High.** SMB 1.0: |
| | - Already disabled by default since Windows 10 1709 |
| | - May be completely removed in a future Windows release |
| | - SMB 1.0 is a significant security risk (WannaCry, NotPetya) |
| |- SMB 2.0+ module cmdlets (`Get-SmbShare`, etc.) are stable |
| **Watch for** | SMB 1.0 removal. SMB 2/3 cmdlets are stable. |
| **Fallback** | SMB 2.0+ cmdlets (already used as primary). WMI: `Get-CimInstance Win32_Share`. |
| **Detection** | `Get-SmbServerConfiguration` for SMB 1.0 state. |

## 9. IPP (Internet Printing Protocol)

| Field | Value |
|-------|-------|
| **Dependency** | Windows IPP Print Server feature, `PrintNotify` service, IPP URL format |
| **Used in** | IPP module |
| **Risk** | **Medium.** IPP support: |
| | - Windows IPP feature (`Printing-Foundation-InternetPrinting-Server`) may change in future Windows versions |
| | - IPP Everywhere / Mopria is the industry direction and Microsoft is investing in it |
| | - However, the local Windows IPP Print Server feature may be de-emphasized in favor of cloud-based IPP |
| **Watch for** | Feature renames or consolidation. IPP URL format changes in future Windows. |
| **Fallback** | Mopria Print Service for Android. Third-party IPP servers. |
| **Detection** | `Get-WindowsOptionalFeature -Online -FeatureName *InternetPrinting*` |

## 10. PowerShell Module System Impact

| Field | Value |
|-------|-------|
| **Risk** | **Medium.** PrinterToolkit relies on module auto-loading via `NestedModules`. In PowerShell 7, module loading behavior has changed: |
| | - `NestedModules` works in both PS5.1 and PS7 |
| | - `RequiredModules` is not used (PrinterToolkit has no external module dependencies) |
| | - `ScriptsToProcess` is also not used |
| | - All Windows-specific cmdlets are resolved at runtime via the module's `.psm1` files |
| **Watch for** | PowerShell 7 cross-platform work: although PrinterToolkit is Windows-only by design, future PowerShell releases may change module resolution, execution policy handling, or security boundaries. |
| **Detection** | `$PSVersionTable.PSEdition` |

---

## Watch Items Summary

| Component | Risk Level | Timeline | Recommended Response |
|-----------|-----------|----------|---------------------|
| PrintManagement | Low | 5+ years | No action |
| NetSecurity | Low | 5+ years | No action |
| CIM/WMI | Low-Medium | 5+ years | Prefer `Get-CimInstance` over deprecated `Get-WmiObject` |
| DISM | Low | 5+ years | Import module explicitly |
| Windows Features | Medium | 2-5 years | Verify feature names per OS version |
| Services | Low-Medium | 5+ years | Watch for `upnphost` deprecation |
| Network Profile | Medium | 2-5 years | Test on Windows Server Core |
| SMB 1.0 | High | 1-3 years | Remove dependency in v9 |
| IPP | Medium | 3-5 years | Watch for feature consolidation |
| PowerShell 7 | Medium | Ongoing | Add pwsh CI test matrix |
