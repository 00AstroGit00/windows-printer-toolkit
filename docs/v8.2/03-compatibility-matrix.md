# v8.2 Compatibility Matrix (Phase 8)

**Status legend:** ✅ Supported & implemented · ⚠️ Implemented, partial/limitation · ❌ Not supported · ⏳ Pending runtime verification.

---

## Operating system

| Windows version | PowerShell | Native modules present | Toolkit status |
|---|---|---|---|
| Windows 10 22H2 | 5.1 | ✅ | ⏳ Pending runtime (harness) |
| Windows 11 23H2 | 5.1 | ✅ | ⏳ Pending runtime |
| Windows 11 24H2 | 5.1 | ✅ | ⏳ Pending runtime |
| Windows 10 22H2 | 7.x | ✅ | ⏳ Pending runtime |
| Windows 11 23H2 | 7.x | ✅ | ⏳ Pending runtime |
| Windows 11 24H2 | 7.x | ✅ | ⏳ Pending runtime |
| Windows Server 2019/2022 | 5.1/7.x | ⚠️ printer roles may differ | ⏳ Pending runtime |
| Non-Windows (Termux/Linux/macOS) | 7.x | ❌ (no PrintManagement/NetSecurity) | ❌ Not supported — parse-check only |

> The toolkit is Windows-only by design. On this Termux host only **static parse**
> and **static analysis** are possible; all native modules fail to import (expected).

## PowerShell native module availability

| Module | Used for | Win10/11 client | Notes |
|---|---|---|---|
| PrintManagement | printers, drivers, ports | ✅ | core |
| NetSecurity | firewall rules | ✅ | |
| NetConnection | network profiles | ✅ | |
| DnsClient | DNS checks | ✅ | |
| PnpDevice | driver/device status | ✅ | |
| SmbShare / SmbServerConfiguration | sharing | ✅ | |
| WindowsOptionalFeature / WindowsFeature | IPP/IIS | ✅ | |
| CimInstance (Win32_Printer, Win32_PrinterDriver) | default printer, test page | ✅ | |
| Microsoft.PowerShell.Management (registry, services) | registry, services | ✅ | |

## Provider × API compatibility

| Provider | Primary API | Fallback | Works PS5.1 | Works PS7 |
|---|---|---|---|---|
| Registry | registry provider | reg.exe (backup) | ✅ | ✅ |
| Firewall | NetSecurity | — | ✅ | ✅ |
| Services | *-Service | — | ✅ | ✅ |
| Network | NetConnectionProfile | — | ✅ | ✅ |
| Printer | CIM Win32_Printer / PrintManagement | — | ✅ | ✅ |
| Driver | PrintManagement / Authenticode / pnputil | — | ✅ | ✅ |
| Sharing | Set-Printer / SMB cmdlets | — | ✅ | ✅ |
| IPP | WindowsOptionalFeature / .NET HttpWebRequest | — | ✅ | ✅ |

## Printer / driver ecosystem

| Category | Support | Notes |
|---|---|---|
| USB printers (Plug & Play) | ✅ | `Get-UsbPrinterInfo` |
| Network printers (IPP/IoT) | ✅ | `Connect-NetworkPrinter`, IPP module |
| Shared/SMB printers | ✅ | Sharing module |
| WSD printers | ⚠️ | detection best-effort |
| 3rd-party driver packages | ✅ | `Install-PrinterDrivers` (pnputil) |
| Driver signature (Authenticode) | ✅ | `Test-DriverSignature` |

## Known limitations (carry-over)

- **KL1:** Orchestrator `Rollback` phase per provider is a stub (L1). Real rollback via `Repair`/`Rollback` modules only.
- **KL2:** Unified error model not yet on all legacy providers (L2).
- **KL3:** `Get-DriverIntelligence.IsWHQL`/`DriverDate` not populated (L3).
- **KL4:** WSD printer detection is heuristic.
- **KL5:** Android ADB requires a device + ADB; not testable here.

## Cross-version risk points to verify at runtime
1. `Set-NetConnectionProfile -NetworkCategory Private` behavior on Win11 24H2 (profile changes gated by policy in some builds).
2. `Get-PrinterDriver.InfPath` property availability across PS5.1/7 on all three OS builds.
3. `Enable-NetFirewallRule` rule names stable across 22H2/23H2/24H2 (group "File and Printer Sharing").
4. `pnputil /add-driver /install` exit semantics identical across builds.
