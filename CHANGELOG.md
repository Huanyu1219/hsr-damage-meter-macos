# Changelog

All notable changes will be documented here. This project follows [Semantic Versioning](https://semver.org/) after its first tagged release.

## [Unreleased]

### Added

- Native SwiftUI combat dashboard, overlays, menu-bar state, enemy data, and SQLite battle history.
- Veritas Socket.IO integration and reproducible no-overlay Collector patches.
- Bounded data updater, JSON history export, mock transport, protocol fixtures, and automated tests.

### Fixed

- Preserve final settlement after transient database failures and make duplicate end events idempotent.
- Isolate history I/O from live event reduction and add bounded exponential retry.
- Validate persisted payloads and prevent failed package builds from replacing the installed app.
- Update the pinned Veritas transitive lockfile to patched releases for known advisories in OpenSSL, rustls-webpki, time, bytes, and rand.
