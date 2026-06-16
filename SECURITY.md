# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in Velix, please report it responsibly.

**Do NOT open a public GitHub issue for security vulnerabilities.**

### How to Report

Email: security@velix.app (or open a private advisory on this repository)

### What to Include

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

### Response Timeline

- **24 hours**: Acknowledgment of receipt
- **72 hours**: Initial assessment
- **7 days**: Fix developed and tested
- **14 days**: Patch released

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.x     | Yes       |
| < 1.0   | Alpha — best effort |

## Security Measures

Velix implements:
- End-to-end encryption (libsignal protocol)
- HMAC-SHA256 authentication
- Serializable database transactions
- PII-filtered structured logging
- Bearer token auth with per-method posture enforcement
- Sealed-sender routing (server never learns sender from metadata)
