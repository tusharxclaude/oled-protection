# Security Policy

OLED Guard requests **Input Monitoring** permission (via a `CGEventTap`) to detect real keyboard/mouse input. This is a privacy-sensitive permission, so we take security reports about how it's requested, used, or scoped seriously.

## Reporting a vulnerability

Please **do not** open a public GitHub issue for a security concern.

Instead, use GitHub's private reporting for this repository: go to the [Security tab](https://github.com/tusharxclaude/oled-protection/security) → **Report a vulnerability**. This opens a private advisory visible only to the maintainer until it's resolved.

Please include:
- A description of the issue and its impact
- Steps to reproduce (macOS version, build/release used)
- Any relevant logs or crash output

## Scope

In scope: the OLED Guard app itself (event tap usage, permission handling, data it reads/stores) and its build/release pipeline (`.github/workflows/`).

Out of scope: third-party apps mentioned in the docs for compatibility reasons (e.g. Amphetamine), and macOS itself.

## Response

This is a small, independently maintained project — there's no fixed SLA, but reports will be acknowledged and triaged as soon as possible.
