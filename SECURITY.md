# Security Policy

## Supported versions

nCompHunt is maintained by one developer. Only the latest released version gets
security fixes. If you are on an older build, update first and check whether the
issue still reproduces.

| Version | Supported |
|---|---|
| Latest release | Yes |
| Anything older | No, update first |

## Reporting a vulnerability

Report privately. Do not open a public issue for a security problem.

Use GitHub's private vulnerability reporting on this repository:
https://github.com/nhannht/ncomphunt/security/advisories/new

That channel is private between you and the maintainer until a fix ships.

Please include:

- What the problem is, and what an attacker gets out of it
- Steps to reproduce, or a proof of concept
- The nCompHunt version and your macOS version
- Whether it needs a specific data source enabled

## What to expect

This is a free, single-maintainer project, so these are honest targets rather
than a service agreement:

- Acknowledgement within about 7 days
- An assessment, and a fix or a decision not to fix, within about 30 days
- Credit in the release notes if you want it

If you get no reply within 14 days, open a public issue saying only that you
have sent a private report and had no response. Do not include the details.

## Scope

In scope:

- The nCompHunt app: the indexer, the parsers that read third-party listings,
  Keychain handling of API keys you enter, calendar and notification
  integration, and anything that could execute code or leak data from your Mac.
- The release and update path, including the signed and notarized builds.

Out of scope:

- Vulnerabilities in the third-party sites nCompHunt reads. Report those to the
  site. This project only fetches and parses their public listings.
- The absence of a feature you would like for hardening. Open a normal issue.
- Reports produced by an automated scanner with no working reproduction.

## What the app does with your data

nCompHunt has no accounts and no back end. It runs on your Mac, keeps its index
locally, and stores any API keys you enter in the macOS Keychain. Those keys go
only to the service they belong to. Full detail is in the privacy policy:
https://ncomphunt.nhannht.io.vn/privacy
