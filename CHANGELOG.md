# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2026-08-18

### Removed

- **Breaking:** `StreamingLZMA` no longer re-exports `Foundation`. Code that relied on
  `import StreamingLZMA` to bring `Data`, `URL`, or `FileHandle` into scope must now
  `import Foundation` itself.

### Fixed

- Documentation builds no longer hang. The `@_exported import Foundation` placed the whole
  of Foundation into `StreamingLZMA`'s own symbol graph — 10,056 symbols across 26 MB,
  against 71 symbols for the module's actual API — which `docc convert` could not curate in
  bounded time. Any consumer running `xcodebuild docbuild` over a dependency graph including
  this package would spin indefinitely. The symbol graph is now 167 KB, and Foundation is
  correctly recorded as an extended module rather than part of this one.

## [1.3.1] - 2026-07-06

### Fixed

- `StreamingLZMAXZ`'s `FileHandle` streaming extensions now build on Linux. The POSIX
  `read`/`write` calls were qualified as `Darwin.*`, which does not exist off Apple
  platforms; they are now dispatched through small platform-guarded wrappers
  (`Darwin`/`Glibc`/`Musl`), so the XZ module compiles and runs on Linux.

## [1.3.0] - 2026-06-26

### Changed

- Adopted Swift's Approachable Concurrency upcoming-feature flags
  (`NonisolatedNonsendingByDefault`, `InferIsolatedConformances`). This is a
  source-compatible concurrency modernization: the public API is unchanged and
  the package's actor-based, async/await streaming surface
  (`LZMACompressor`/`LZMADecompressor`/`XZCompressor`/`XZDecompressor` and the
  `AsyncThrowingStream`-returning extensions) behaves as before.

## [1.2.0] - 2026-05-17

### Added

- `LZMAError.ioFailure(operation:code:)` and `XZError.ioFailure(operation:code:)`, carrying the raw POSIX `errno` from a failed read/write syscall
- `CustomNSError` conformance on `LZMAError` and `XZError`: an `ioFailure` now bridges to an `NSError` whose `NSUnderlyingErrorKey` is an `NSPOSIXErrorDomain` error, so callers can detect conditions such as `ENOSPC` (disk full) by type instead of parsing error strings

### Changed

- FileHandle streaming read/write syscall failures now throw `ioFailure(operation:code:)` instead of `internalError(_:)` with a preformatted string. The human-readable `description`/`failureReason` text is unchanged, but code that exhaustively switches over `LZMAError`/`XZError` will need to handle the new case

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
