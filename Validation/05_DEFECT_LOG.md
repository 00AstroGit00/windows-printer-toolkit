# PrinterToolkit v5.1 — Defect Log

## Instructions

- Create one row per defect.
- Assign a unique **D-XXX** ID.
- Severity: **Critical** (prevents use), **High** (major feature broken), **Medium** (partial impairment), **Low** (cosmetic/minor).
- Status: **Open**, **Investigating**, **Fixed**, **Verified**, **Closed**, **Won't Fix**, **Deferred**.
- Link to the failing test case ID.
- Attach evidence (screenshot, transcript excerpt, log) to each defect.

---

## Defect List

| ID | Date | Test Case | Severity | Summary | Environment | Root Cause | Status | Resolution | Evidence |
|----|------|-----------|----------|---------|-------------|------------|--------|------------|----------|
| D-001 | | | | | | | | | |
| D-002 | | | | | | | | | |
| D-003 | | | | | | | | | |
| D-004 | | | | | | | | | |
| D-005 | | | | | | | | | |
| D-006 | | | | | | | | | |
| D-007 | | | | | | | | | |
| D-008 | | | | | | | | | |
| D-009 | | | | | | | | | |
| D-010 | | | | | | | | | |
| D-011 | | | | | | | | | |
| D-012 | | | | | | | | | |
| D-013 | | | | | | | | | |
| D-014 | | | | | | | | | |
| D-015 | | | | | | | | | |

*(Add rows as needed)*

---

## Defect Severity Definitions

| Severity | Definition | Exit Criteria |
|----------|-----------|---------------|
| Critical | Toolkit crashes, data loss, or core function (import, discovery, spooler) completely broken on a supported environment | Must be fixed before release |
| High | Major feature (repair, export, sharing, driver operations) broken or unusable; no workaround | Must be fixed before release |
| Medium | Feature partially impaired; workaround exists; or non-default configuration affected | Fix before release or document as known issue |
| Low | Cosmetic issue, minor UI glitch, documentation typo, edge case | Fix or defer to next release |

---

## Defect Status Flow

```
Open → Investigating → Fixed → Verified → Closed
                    ↘ Won't Fix
                    ↘ Deferred (with reason + target version)
```

## Triage Log

| Date | Defect ID | Action | Triage Team | Notes |
|------|-----------|--------|-------------|-------|
| | | | | |
| | | | | |
| | | | | |
