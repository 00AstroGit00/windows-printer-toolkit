# PrinterToolkit — Governance Guide

**Version:** 1.0
**Date:** 2026-07-14

---

## 1. Project Structure

PrinterToolkit is an open-source project governed by its maintainers. The project does not have a formal foundation or corporate sponsor. Governance is designed to be lightweight while ensuring long-term sustainability.

## 2. Roles and Responsibilities

### Lead Maintainer (1-2 people)
- Overall project direction and roadmap
- Final decision authority on disputes
- Release management and versioning
- Security vulnerability response
- Community health and code of conduct enforcement
- PowerShell Gallery and package manager publishing

### Core Maintainers (2-4 people)
- Code review and merge approval
- Issue triage and bug fixing
- Documentation maintenance
- Test suite maintenance
- CI/CD pipeline maintenance
- Community support (issues, discussions)

### Contributors (anyone)
- Bug fixes and feature implementations via PR
- Documentation improvements
- Test case contributions
- Community support
- No merge rights

### Users
- Report bugs via GitHub Issues
- Request features via GitHub Issues
- Participate in discussions
- No commit or merge rights

## 3. Review Policy

### Code Review Requirements
- **Lead/Core Maintainer PRs:** At least 1 approval from another maintainer
- **Contributor PRs:** At least 1 approval from a Core or Lead maintainer
- **Security fixes:** At least 2 approvals (one must be Lead)
- **Documentation-only PRs:** May be merged by any maintainer after review
- **Emergency hotfixes:** May be self-merged by Lead, then reviewed post-merge

### Review Criteria
- Code follows the coding standards (see Maintainer Guide)
- Tests pass (CI must be green)
- No security regressions introduced
- Documentation updated if applicable
- CHANGELOG updated for user-facing changes

## 4. Decision-Making Process

### Consensus-Based
Most decisions are made by consensus among active maintainers. The process:

1. **Proposal** — Issue or discussion thread describing the change
2. **Discussion** — Minimum 72 hours for comments
3. **Consensus check** — Maintainers vote: +1 (approve), 0 (abstain), -1 (block with reason)
4. **Decision** — If no blocks and at least 2 +1s, the decision passes
5. **Escalation** — If consensus cannot be reached, the Lead Maintainer makes the final call

### Voting
- +1: I agree with this proposal
- 0: I have no strong opinion
- -1: I disagree and provide a reason (must be technical, not personal)

Blocks (-1) must include a technical justification. A block without justification is considered abstention.

## 5. Release Cadence

| Release Type | Cadence | Who Decides Content |
|-------------|---------|-------------------|
| Patch (5.3.x) | Monthly as needed | Lead Maintainer |
| Minor (5.y.0) | Quarterly | Maintainers via consensus |
| Major (x.0.0) | Annually | Maintainers via consensus |
| Hotfix | As needed (emergency) | Lead Maintainer |
| LTS | Annual | Maintainers via consensus |

## 6. Security Response Policy

See `SECURITY.md` for reporting. Internal process:

1. Report received → Lead Maintainer acknowledges within 24 hours
2. Triage → severity assessment within 48 hours
3. Fix → private branch, developed within 7 days (Critical) or 30 days (High)
4. Release → coordinated patch with reporter
5. Disclosure → public advisory published after fix is released

**No public discussion of unpatched vulnerabilities.**

## 7. Contributor Ladder

```
User
  │
  ▼ (10+ merged PRs or 6 months of active participation)
Contributor
  │
  ▼ (Invitation by Lead Maintainer, sustained contributions)
Core Maintainer
  │
  ▼ (Invitation by Lead Maintainer, demonstrated leadership)
Lead Maintainer
```

### Responsibilities at Each Level

| Level | Issues | PR Review | CI | Releases | Security | Roadmap |
|-------|--------|-----------|----|----------|----------|---------|
| User | Report | No | No | No | No | No |
| Contributor | Triage | No | No | No | No | No |
| Core Maintainer | Triage + Fix | Yes | Maintain | No | Triage | Input |
| Lead Maintainer | All | Final | Own | Own | Own | Own |

## 8. Code of Conduct

All participants in the PrinterToolkit project agree to:

- **Be respectful** — Disagreement is not a personal attack
- **Be constructive** — Criticism should be actionable
- **Be inclusive** — Welcome contributors of all backgrounds
- **Be patient** — Maintainers are volunteers with limited time

Violations should be reported to the Lead Maintainer privately. Consequences range from a warning to permanent ban.

## 9. Licensing

PrinterToolkit is licensed under the MIT License (see `LICENSE`). All contributions are made under the same license. Contributors do not need to sign a Contributor License Agreement (CLA); submitting a PR constitutes agreement to the MIT license.

## 10. Conflict Resolution

1. Discuss directly in the relevant issue/PR
2. Escalate to the Core Maintainer team for mediation
3. Final appeal to the Lead Maintainer
4. If unresolved, the Lead Maintainer's decision is final

For disputes that cannot be resolved internally, the project may seek mediation through the GitHub Community Forum or Software Freedom Conservancy. This has never been necessary.

## 11. Decision Log

| Date | Decision | Rationale | Decided By |
|------|----------|-----------|------------|
| 2026-07-14 | Adopted Semantic Versioning 2.0 | Clear API stability guarantees | Maintainers |
| 2026-07-14 | GitHub as primary distribution | Low friction, built-in CI/CD, community | Maintainers |
| 2026-07-14 | MIT license | Maximum adoption, minimal restrictions | Original Author |
| 2026-07-14 | No CLA required | Lowers barrier for contributions | Maintainers |
