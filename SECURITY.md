# Security Policy

## Supported versions

Only the latest commit on `main` is currently supported. No stable release series has been published yet.

## Reporting a vulnerability

Do not open a public issue for a vulnerability that could expose local data, allow an untrusted local process to impersonate the Collector, modify game files unexpectedly, or compromise the update/download path.

Use GitHub's private vulnerability reporting for this repository. Include the affected commit, reproduction steps, impact, and any suggested mitigation. If private reporting is temporarily unavailable, open a minimal issue asking the maintainer to enable a private contact channel without including exploit details.

You should receive acknowledgement within seven days. We aim to provide an initial assessment within fourteen days. Timelines may vary because this is a volunteer project.

## Security boundaries

- The macOS client connects only to the loopback Collector endpoint.
- The Collector installer requires an explicit game directory, validates known hashes, and refuses to replace files while the game is running.
- Game-data downloads are limited to recorded HTTPS origins and bounded response sizes.
- Do not report game anti-cheat bypasses, cheating techniques, or vulnerabilities in the game itself here. Report those to the relevant vendor.
