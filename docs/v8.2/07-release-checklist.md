# v8.2 Release Checklist

## Static (DONE in this environment)
- [x] All 22 modules parse (0 errors) — `v81_parse_check.ps1`
- [x] v8.1 Native Integration verified (no netsh/rundll32/pnputil-parse)
- [x] v8.2 Provider Certification — static review complete (`02-provider-certification-report.md`)
- [x] v8.2 Security Review complete (`05-security-review.md`) — no Critical/High
- [x] v8.2 Compatibility Matrix complete (`03-compatibility-matrix.md`)
- [x] Defect fixes: `CompatibleIDs` typo, `$env:TEMP` → `GetTempPath()` in Rollback/ZeroTouch
- [x] Harness delivered: RuntimeValidation, FailureInjection, Benchmark, ProviderCert.Tests

## Actionable before sign-off (recommended)
- [ ] **S5:** add guarded Administrator check (root module or `-Force`) — Low effort, Medium value
- [ ] **Decision L1:** implement per-provider Rollback OR document as out-of-scope
- [ ] **Decision L2:** wrap legacy providers in `New-ProviderResult` OR leave for later

## Runtime (PENDING — Windows host required)
- [ ] Phase 1: import succeeds on Win10 22H2 / Win11 23H2 / Win11 24H2 × {PS5.1, PS7}
- [ ] Phase 3: real printer + driver install + signature PASS
- [ ] Phase 4: client connectivity (shared/IPP) succeeds
- [ ] Phase 5: failure injection JSON collected, recovery verified
- [ ] Phase 6: benchmark JSON collected, within thresholds

## Release gate
- [ ] All 6 `summary.json` show zero import errors
- [ ] No Critical/High findings open
- [ ] Evidence package attached (reports + JSON)
- [ ] CHANGELOG v8.2 finalized
- [ ] Branch `feature/v8-orchestration-engine` committed
- [ ] Version bumped to 8.2.0 (currently 8.1.0 in root module)
- [ ] Known issues documented (`10-known-issues.md`)

## Sign-off
- [ ] Maintainer review
- [ ] RC produced if gate passes, else deferred
