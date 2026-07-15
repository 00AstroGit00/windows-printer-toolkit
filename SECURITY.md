# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 8.2.x   | Yes (RC — runtime pending) |
| 5.0.x   | Yes (end-of-life)          |
| 4.1.x   | No                         |
| < 4.1   | No                         |

## Reporting a Vulnerability

PrinterToolkit is a local administration tool that requires Administrator privileges for most operations. It does not expose network services, store credentials, or transmit data externally.

If you discover a security vulnerability:

1. **Do not** open a public GitHub Issue
2. Email the maintainers directly (see repository profile for contact)
3. Include a detailed description and reproduction steps

## Security Practices

- All user input is validated before passing to shell commands
- `Invoke-Expression` is only used with an allowlist
- No credentials, tokens, or secrets are stored
- Log files are written to user-controlled locations (Desktop)
- Module loading does not bypass execution policy
- No external dependencies or network calls during operation
- Destructive operations require `Assert-Elevated` check before execution
- Bootstrap installer verifies SHA-256 checksums against published release assets

## Scope

The following are NOT considered vulnerabilities:
- Need for Administrator privileges (by design)
- Local file access by an already-elevated attacker (the attacker already has full control)
- PowerShell execution policy checks (standard Windows security)
