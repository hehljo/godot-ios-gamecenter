# Changelog

All notable changes to GameCenterKit are documented in this file.

## [1.1.0] - 2026-11-17 (fork hehljo/godot-ios-gamecenter)

### Added

- `request_review()` with signal `review_requested(ok, error)`: hands a review
  request to StoreKit (`SKStoreReviewController requestReviewInScene:`, iOS 14+)
  in the foreground-active window scene. Outside iOS it fails deterministically.
  The export plug-in now also links `StoreKit.framework`.
- Platform-free GDScript modules: `GameCenterBridge` (one code path for every
  platform, failure signals without the native singleton), `GameCenterReviewPolicy`
  (when to ask) and `GameCenterScoreQueue` (offline queue keyed by leaderboard
  occurrence, so expired daily/weekly scores are never submitted).
- `example/tests/pure_modules.gd` runs those modules headless on any OS.
- Empty Linux x86_64/arm64 and Windows x86_64 libraries (no singleton), so desktop
  editors and headless test runs load the extension without errors.
- Releases attach `SHA256SUMS` next to the ZIP.

## [1.0.1] - 2026-09-11

### Fixed

- Validate leaderboard and achievement metadata before presenting native panels.
- Report unavailable metadata and presentation timeouts through failure signals.
- Prevent overlapping native panel requests and safely own queued callback state.

### Distribution

- Publish the same provenance-verified 1.0.1 package submitted to the Godot Asset
  Store on 2026-09-05, including the maintainer-tested native binaries from
  source `e2e4798`. Public API and supported Apple platforms are unchanged.

## [1.0.0] - 2026-09-04

### Added

- Prebuilt iOS arm64 device and arm64/x86_64 simulator XCFramework.
- Universal macOS 11+ debug and release editor binaries.
- Authentication, player display name, leaderboard score submission, achievement
  progress, native iOS panels, and Game Center access point controls.
- `panel_closed` and `panel_failed` lifecycle signals.
- Installable `addons/gamecenter/` release archive with combined MIT notices.

### Changed

- Set deterministic iOS 14 and macOS 11 deployment targets.
- Present Game Center UI from the active scene's topmost view controller.
- Keep all asynchronous Godot signal delivery on the main loop.
- Enable the example export plug-in and Game Center entitlement preset.

### Fixed

- Reject empty leaderboard and achievement identifiers before calling GameKit.
- Reject non-finite and out-of-range achievement percentages.
- Prevent pending native callbacks from using the singleton after shutdown.
- Report unavailable or conflicting native panel presentation through `panel_failed`.
- Treat unguarded Apple API availability warnings as build errors.

### Validation

- Verified package paths, semantic version, exported entry symbol, architectures, and
  Apple deployment metadata.
- Passed native contract and repository/package tests.
- Passed editor/runtime smoke tests with official Godot 4.5.2 and 4.7.2.
- Generated debug and release iOS Xcode projects and completed an unsigned simulator
  link smoke test.
