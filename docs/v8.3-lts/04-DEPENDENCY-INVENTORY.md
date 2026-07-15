# Dependency Inventory — PrinterToolkit v8.3 LTS

> **Purpose:** Catalog every external dependency across all modules. For each dependency, document the purpose, minimum supported version, and replacement strategy if deprecated.

---

## 1. PowerShell Cmdlets — Built-in Modules

### PrintManagement Module

| Cmdlet | File | Purpose | Min Version | Replacement |
|--------|------|---------|-------------|-------------|
| `Get-Printer` | Core, Drivers, IPP, Sharing, Android, Diagnostics | List installed printers | Windows 8/2012 | `Get-CimInstance Win32_Printer` |
| `Get-PrinterDriver` | Core, Drivers | List installed printer drivers | Windows 8/2012 | `Get-CimInstance Win32_PrinterDriver` |
| `Add-PrinterDriver` | Drivers | Install printer driver | Windows 8/2012 | PnPUtil |
| `Remove-PrinterDriver` | Drivers | Remove printer driver | Windows 8/2012 | PnPUtil |
| `Set-Printer` | Core, IPP, Sharing | Configure printer properties | Windows 8/2012 | `Invoke-CimMethod Win32_Printer` |
| `Get-PrinterPort` | Core, IPP | List printer ports | Windows 8/2012 | `Get-CimInstance Win32_TCPIPPrinterPort` |
| `Add-PrinterPort` | IPP | Create printer port | Windows 8/2012 | `Invoke-CimMethod Win32_TCPIPPrinterPort` |

### NetSecurity Module

| Cmdlet | File | Purpose | Min Version | Replacement |
|--------|------|---------|-------------|-------------|
| `Get-NetFirewallRule` | Networking, Providers, Orchestration | Query firewall rules | Windows 8/2012 | CIM: `MSFT_NetFirewallRule` |
| `Enable-NetFirewallRule` | Networking, Providers | Enable firewall rule | Windows 8/2012 | CIM |
| `Disable-NetFirewallRule` | Networking, Providers | Disable firewall rule | Windows 8/2012 | CIM |
| `New-NetFirewallRule` | Providers | Create firewall rule | Windows 8/2012 | CIM + `netsh advfirewall` |

### SmbShare Module

| Cmdlet | File | Purpose | Min Version | Replacement |
|--------|------|---------|-------------|-------------|
| `Get-SmbShare` | SMB, Sharing | List SMB shares | Windows 8/2012 | `Get-CimInstance Win32_Share` |
| `Set-SmbShare` | SMB | Configure share properties | Windows 8/2012 | CIM |
| `Grant-SmbShareAccess` | Sharing | Grant share permission | Windows 8/2012 | CIM |
| `Revoke-SmbShareAccess` | Sharing | Revoke share permission | Windows 8/2012 | CIM |
| `Block-SmbShareAccess` | Sharing | Block share access | Windows 8/2012 | CIM |
| `Get-SmbServerConfiguration` | SMB | Query SMB server config | Windows 8/2012 | Registry: `HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters` |
| `Set-SmbServerConfiguration` | SMB | Configure SMB server | Windows 8/2012 | Registry |
| `Unblock-SmbShareAccess` | SMB | Unblock share access | Windows 8/2012 | CIM |

### Dism Module

| Cmdlet | File | Purpose | Min Version | Replacement |
|--------|------|---------|-------------|-------------|
| `Get-WindowsOptionalFeature` | Configuration | List Windows features | Windows 8/2012 | `dism.exe /online /get-features` |
| `Enable-WindowsOptionalFeature` | Configuration, IPP | Enable Windows feature | Windows 8/2012 | `dism.exe /online /enable-feature` |
| `Disable-WindowsOptionalFeature` | Configuration | Disable Windows feature | Windows 8/2012 | `dism.exe /online /disable-feature` |
| `Get-WindowsDriver` | Providers | Query driver store | Windows 8/2012 | `dism.exe /online /get-drivers` |

### NetConnection Module

| Cmdlet | File | Purpose | Min Version | Replacement |
|--------|------|---------|-------------|-------------|
| `Get-NetConnectionProfile` | Networking, Orchestration | Get network profile | Windows 8/2012 | Registry: `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\NetworkList\Profiles\...` |
| `Set-NetConnectionProfile` | Networking, Orchestration | Set network profile | Windows 8/2012 | Registry + `netsh` |

### Microsoft.PowerShell.Management

| Cmdlet | File | Purpose | Min Version | Replacement |
|--------|------|---------|-------------|-------------|
| `Get-Service` | Core, Orchestration, Diagnostics | Query service status | PS 2.0+ | CIM: `Get-CimInstance Win32_Service` |
| `Start-Service` | Core, Orchestration | Start service | PS 2.0+ | CIM: `Invoke-CimMethod -MethodName StartService` |
| `Stop-Service` | Core, Orchestration | Stop service | PS 2.0+ | CIM |
| `Set-Service` | Configuration, Orchestration | Configure service | PS 2.0+ | CIM |
| `Restart-Service` | Core | Restart service | PS 2.0+ | CIM |

### Microsoft.PowerShell.Utility

| Cmdlet | File | Purpose | Min Version | Replacement |
|--------|------|---------|-------------|-------------|
| `ConvertTo-Json` | Reporting, Orchestration, Start-Certification | Serialize to JSON | PS 3.0+ | `Newtonsoft.Json` |
| `ConvertFrom-Json` | Orchestration | Deserialize JSON | PS 3.0+ | `Newtonsoft.Json` |
| `ConvertTo-Html` | Reporting, Start-Certification | Generate HTML | PS 3.0+ | StringBuilder |
| `Out-File` | Logging, Bundle, Reporting | Write to file | PS 2.0+ | `[System.IO.File]::WriteAllText` |
| `ConvertTo-Csv` | Reporting | Generate CSV | PS 3.0+ | StringBuilder |

### Microsoft.PowerShell.Archive

| Cmdlet | File | Purpose | Min Version | Replacement |
|--------|------|---------|-------------|-------------|
| `Compress-Archive` | Bundle, Reporting, Start-Certification | Create ZIP | PS 5.0+ | `System.IO.Compression.ZipArchive` |
| `Expand-Archive` | install.ps1 | Extract ZIP | PS 5.0+ | `System.IO.Compression.ZipArchive` |

---

## 2. CIM/WMI Classes

| Class | Namespace | Used In | Purpose | Min OS | Replacement |
|-------|-----------|---------|---------|--------|-------------|
| `Win32_Printer` | `root\cimv2` | Core, Drivers, Detection | Printer enumeration | Windows XP | PrintManagement module |
| `Win32_PrinterDriver` | `root\cimv2` | Core, Drivers | Driver enumeration | Windows XP | PrintManagement module |
| `Win32_OperatingSystem` | `root\cimv2` | Diagnostics, Start-Certification | OS version info | Windows XP | `[Environment]::OSVersion` |
| `Win32_ComputerSystem` | `root\cimv2` | Diagnostics, Start-Certification | System info | Windows XP | `Get-ComputerInfo` |
| `Win32_NetworkAdapterConfiguration` | `root\cimv2` | Detection, Diagnostics | Network config | Windows XP | `Get-NetIPAddress` |
| `Win32_PnPEntity` | `root\cimv2` | Detection | PnP device enumeration | Windows XP | `Get-PnpDevice` |
| `Win32_USBControllerDevice` | `root\cimv2` | Detection | USB device enumeration | Windows XP | `Get-PnpDevice` |
| `Win32_PrintJob` | `root\cimv2` | Core | Print queue enumeration | Windows XP | `Get-PrintJob` |
| `Win32_Service` | `root\cimv2` | Diagnostics | Service enumeration | Windows XP | `Get-Service` |
| `Win32_Share` | `root\cimv2` | SMB, Sharing | Share enumeration | Windows XP | `Get-SmbShare` |
| `Win32_PnPSignedDriver` | `root\cimv2` | Drivers | Signed driver info | Windows 7 | `Get-WindowsDriver` |
| `MSFT_NetFirewallRule` | `root\StandardCimv2` | Networking, Providers | Firewall rule query | Windows 8 | `Get-NetFirewallRule` |

---

## 3. Native Executables (Shell-Out)

| Executable | File | Purpose | Risk |
|------------|------|---------|------|
| `ipconfig.exe` (via `netsh interface ip show`) | Detection, Networking | IPv4 address detection | Low — present in all Windows versions |
| `adb.exe` (Android Debug Bridge) | Android | Android device detection (optional) | High — not present on most systems; silently handled |

All pre-v8.1 shell-out calls (`netsh.exe`, `rundll32.exe`, `pnputil.exe`) were replaced by native cmdlets in the v8.1 Providers module. No remaining production code shells out to executables.

---

## 4. .NET Framework Classes

| Class | Used In | Purpose | Min OS |
|-------|---------|---------|--------|
| `System.Management.Automation.Language.Parser` | CI/build.ps1 | PowerShell syntax validation | PS 3.0+ |
| `System.IO.Compression.ZipArchive` | install.ps1 alternate path | ZIP extraction | .NET 4.5+ |
| `System.Diagnostics.Stopwatch` | Orchestration | Task duration measurement | .NET 2.0+ |
| `System.Collections.ArrayList` | Orchestration, Logging | Mutable collections | .NET 2.0+ |
| `System.Environment` | Multiple | OS info, user info | .NET 2.0+ |
| `System.IO.Path` | Multiple | File path operations | .NET 2.0+ |

---

## 5. Windows Features (Optional Components)

| Feature Name | Used In | Purpose | Min OS | Risk |
|-------------|---------|---------|--------|------|
| `Printing-Foundation-Features` | Configuration | Core print functionality | Windows 8 | Low |
| `Printing-Foundation-InternetPrinting-Client` | IPP | IPP client support | Windows 8 | Low |
| `Printing-Foundation-InternetPrinting-Server` | IPP | IPP print server | Windows 8 | Medium |
| `Printing-PrintToPDFServices-Features` | Configuration | Microsoft Print to PDF | Windows 8 | Low |
| `Microsoft-Windows-Printing-Subsystem` | Configuration | Core print subsystem | Windows 8 | Low |
| `SMB1Protocol` | SMB | SMB 1.0/CIFS support | Windows 8/2012 | **High** — deprecated |

---

## 6. Registry Paths

| Path | Used In | Purpose |
|------|---------|---------|
| `HKLM:\SYSTEM\CurrentControlSet\Control\Print` | Core, Configuration, Orchestration | Print subsystem settings |
| `HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion` | Diagnostics, Start-Certification | OS version info |
| `HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters` | SMB (fallback) | SMB server configuration |
| `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\...` | Configuration (fallback) | Component servicing state |

---

## 7. PowerShell Environment Assumptions

| Assumption | Where Used | Risk |
|-----------|-----------|------|
| `$env:COMPUTERNAME` available | Detection, Android, Utilities | Low — always present on Windows |
| `$env:USERNAME` available | Orchestration | Low — always present on interactive sessions |
| `$env:TEMP` writable | Multiple | Low — always present |
| `$env:windir` resolves to `C:\Windows` | Core | Low — standard on Windows |
| `[Environment]::GetFolderPath('Desktop')` writable | Reporting, Bundle, Android | Medium — may fail on redirected/roaming desktops |
| ExecutionPolicy allows script execution | All | Medium — may be restricted |

---

## 8. Summary by Dependency Category

| Category | Count | Critical | High Risk |
|----------|-------|----------|-----------|
| PowerShell built-in modules | 8 modules | 0 | 0 |
| CIM/WMI classes | 12 classes | 0 | 0 |
| Native executables | 2 (1 optional) | 0 | 1 (adb) |
| .NET classes | 6 classes | 0 | 0 |
| Windows Features | 6 features | 0 | 1 (SMB1Protocol) |
| Registry paths | 4 paths | 0 | 0 |
| Environment assumptions | 6 assumptions | 0 | 1 (Desktop folder) |
| **Total** | **36+** | **0** | **3** |
