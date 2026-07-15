# PrinterToolkit v8.2.0-rc1 — Release Candidate Notes

## Version

**8.2.0-rc1** (Release Candidate — not Stable)

## Status Summary

| Dimension | Status |
|-----------|--------|
| **Static certification** | Complete |
| **Code review** | Complete |
| **Security review** | Partial (static only, no dynamic testing) |
| **Provider certification** | Static complete, runtime pending |
| **Runtime validation** | **Not executed** — pending Windows host |
| **Performance benchmarks** | **Not executed** — pending Windows host |
| **Failure injection** | **Not executed** — pending Windows host |
| **End-to-end printer tests** | **Not executed** — requires physical printer |

## Known Issues

See `docs/v8.2/10-known-issues.md` for full details.

Resolved this release:
- **L1 (Medium):** Per-provider `Rollback` phase now captures pre-state and restores original configuration for all 6 state-changing providers.
- **S5 (Medium):** Admin elevation check added at module load time.
- **Cosmetic:** All version strings harmonized to 8.2.0.

Remaining:
- **L2 (Low):** `New-ProviderResult` only used by v8.1 helpers; legacy providers return ad-hoc shapes.
- **L3 (Low):** `Get-DriverIntelligence.IsWHQL` and `DriverDate` never populated.
- **KL4 (Low):** WSD printer detection is heuristic.
- **KL5 (Low):** Android ADB requires physical device; not CI-testable.

## Release-Blocking Risks (for Stable)

| ID | Severity | Description |
|----|----------|-------------|
| R1 | **High** | Zero runtime validation executed on any target OS/PS/printer |
| R2 | **High** | Cannot confirm firewall/sharing/IPP behavior in production |

These risks are acceptable for an RC with explicit limitations disclosed.
They **block** promotion to Stable.

## What This RC Is

A static-certified, code-reviewed, internally consistent release that is
ready for external QA to exercise on real Windows hardware. All validation
harnesses exist but have never been run. The RC tag is honest about this.

## What This RC Is NOT

Production-ready. Not validated. Not to be used on live print servers
without thorough independent testing.

## Recommendation for Testers

1. Run `Start-Certification.ps1` in an elevated PowerShell session.
2. Review `summary.html` for pass/fail counts.
3. File issues using the template in `Certification/06-ISSUE_REPORTING_TEMPLATE.md`.
4. Collect and return the evidence ZIP to release engineering.

## Post-RC Path

1. Collect runtime evidence from all 6 OS×PS configurations.
2. Execute end-to-end tests with real USB/network printers.
3. Resolve any High/Critical defects found.
4. Re-run release gate.
5. Promote RC to Stable (v8.2.0) when R1 and R2 are closed by evidence.
