# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in Cast, please report it responsibly.

**Do not open a public GitHub issue for security vulnerabilities.**

Instead, please use [GitHub's private vulnerability reporting](https://github.com/jaylann/Cast/security/advisories/new) to submit your report.

### What to Include

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

### Response Timeline

- **Acknowledgment**: Within 48 hours
- **Initial assessment**: Within 1 week
- **Fix timeline**: Depends on severity, typically within 2 weeks for critical issues

## Scope

Cast is a library that runs locally on Apple Silicon devices. Security concerns primarily involve:

- Malicious model outputs bypassing constrained decoding
- Memory safety issues in grammar compilation or sampling
- Denial of service through crafted schemas or inputs

## Supported Versions

Only the latest release receives security updates.
