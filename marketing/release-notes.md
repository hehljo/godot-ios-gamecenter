# GameCenterKit 1.1.0 (fork hehljo/godot-ios-gamecenter)

- New `request_review()` / `review_requested(ok, error)`: StoreKit review request
  in the foreground-active scene (iOS 14+); deterministic failure elsewhere.
  The export plug-in links `StoreKit.framework`.
- New platform-free GDScript helpers: `GameCenterBridge`, `GameCenterReviewPolicy`,
  `GameCenterScoreQueue` (occurrence-keyed offline queue for recurring leaderboards).
- Game Center API unchanged from upstream 1.0.1. Built and validated by this
  repository's GitHub Actions run; verify the ZIP against `SHA256SUMS`.

Supports official single-precision Godot 4.5–4.7, iOS/iPadOS 14+, and macOS 11+
editor use. Native Game Center panels and the review prompt are iOS-only.
