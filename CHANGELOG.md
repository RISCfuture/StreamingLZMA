# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-05-01

### Added

- New `StreamingLZMAXZ` target providing XZ format support, split out from the core `StreamingLZMA` library
- New `xz-tool` command-line executable for XZ compression/decompression
- Direct Darwin syscalls for FileHandle streaming I/O for improved performance on Apple platforms

### CI

- Updated GitHub Actions to latest versions
- Simplified CI matrix
- Switched from `swift-format` to `swift format` in CI
- iOS test job stability fixes

## [1.0.0] - 2026-01-29

### Added

- Initial release
