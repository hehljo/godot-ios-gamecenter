# GameCenterKit for Godot

GameCenterKit is a focused Game Center GDExtension for Godot games on Apple
platforms. It exposes authentication, leaderboard scores, achievements, native Game
Center panels, and the Game Center access point through one `Engine` singleton.

## Fork additions (1.1.0)

This fork (`hehljo/godot-ios-gamecenter`) adds a StoreKit review request and
platform-free GDScript helpers; the native Game Center API is unchanged.

- `request_review()` calls `SKStoreReviewController requestReviewInScene:` in the
  foreground-active window scene. StoreKit alone decides whether a dialog appears
  (at most three times in 365 days, never in TestFlight). Outside iOS the call
  fails deterministically with `review_requested(false, reason)`.
- `GameCenterBridge` wraps the singleton. Without it (Android, Web, desktop,
  tests) every call answers one frame later with the failure signal a real
  failure would send, so game code has one path.
- `GameCenterReviewPolicy.decide(state, moment, rules)` picks the moment: only in
  the menu between runs, never after a death or an ad, once per app version,
  after a first win or enough runs and play time. Returns `ask` or the blocking
  reason.
- `GameCenterScoreQueue` keeps unsent scores as plain data for the save game, one
  per board and occurrence, and `prune()` drops expired daily/weekly occurrences
  (Apple: never submit to past occurrences). `occurrence_index()` uses the same
  start and duration that App Store Connect stores for recurring leaderboards.
- Empty Linux x86_64/arm64 and Windows x86_64 editor libraries: desktop editors
  and headless test runs load the extension without "No GDExtension library
  found" errors; the bridge then reports Game Center as unavailable.
  For Android and Web exports, exclude `addons/gamecenter/gamecenter.gdextension`
  and `addons/gamecenter/bin/*` in the preset (keep the GDScript helpers).
- `godot --headless --path example --script res://tests/pure_modules.gd` tests
  these modules on any OS.

## Compatibility

| Component | Supported versions |
| --- | --- |
| Godot | Official single-precision builds, 4.5 through 4.7 |
| iOS / iPadOS | 14.0 or newer; device and simulator binaries included |
| macOS | 11.0 or newer; editor and automated smoke-test binaries included |

Native leaderboard and achievement panels are available on iOS/iPadOS. On macOS,
panel methods emit `panel_failed` so editor-side code remains deterministic.

## Install

1. Extract the release ZIP into the root of a Godot project. The installed path must
   be `res://addons/gamecenter/`.
2. Open **Project > Project Settings > Plugins** and enable **Game Center Export**.
3. Create or edit the iOS export preset and enable **Game Center**. In the preset
   file this is `entitlements/game_center=true`.
4. In Apple Developer and App Store Connect, enable the Game Center capability for
   the app identifier and configure every leaderboard and achievement identifier used
   by the game.
5. Export with an Apple team and provisioning profile that include Game Center.

Guard platform-specific calls so projects can still run on unsupported platforms:

```gdscript
if Engine.has_singleton("GameCenterKit"):
	var game_center := Engine.get_singleton("GameCenterKit")
	game_center.authenticated.connect(_on_authenticated)
	game_center.authenticate()
```

## API

All methods should be called from the Godot main thread. Operations that contact
GameKit complete asynchronously and answer through a deferred signal on the main
loop; no method blocks while waiting for Apple services.

| Method | Result |
| --- | --- |
| `authenticate()` | Starts local-player authentication; emits `authenticated`. |
| `is_authenticated() -> bool` | Returns the current local-player authentication state. |
| `player_display_name() -> String` | Returns the authenticated player's display name or an empty string. |
| `submit_score(leaderboard_id, score)` | Submits an integer score; emits `score_submitted`. |
| `show_leaderboard(leaderboard_id)` | Presents the requested iOS leaderboard panel. |
| `report_achievement(achievement_id, percent)` | Reports finite progress from 0 through 100; emits `achievement_reported`. |
| `show_achievements()` | Presents the iOS achievements panel. |
| `set_access_point_visible(visible)` | Shows or hides the native Game Center access point. |
| `request_review()` | Hands a review request to StoreKit on iOS; emits `review_requested`. |

| Signal | Arguments |
| --- | --- |
| `authenticated` | `ok: bool, error: String` |
| `score_submitted` | `ok: bool, leaderboard_id: String, error: String` |
| `achievement_reported` | `ok: bool, achievement_id: String, error: String` |
| `panel_closed` | `panel: String` (`leaderboard` or `achievements`) |
| `panel_failed` | `panel: String, error: String` |
| `review_requested` | `ok: bool, error: String` (`ok` = handed to StoreKit, not "dialog shown") |

Panel calls load GameKit metadata before presenting. Missing App Store Connect
definitions, authentication loss, API errors, a pending panel request, or a
15-second metadata timeout emit `panel_failed`. Show that failure to the player
and allow retry. A late response after timeout does not open a panel.

Empty identifiers and invalid achievement percentages are rejected before GameKit is
called. A failed result always includes a stable operation identifier and a readable
error string.

## App Store Connect setup

- The bundle identifier in the Godot export preset must match the Game Center-enabled
  App Store Connect app.
- Leaderboard and achievement identifiers are case-sensitive and must already exist
  in App Store Connect.
- Test authentication and submissions with an Apple sandbox account on a physical
  device before shipping.
- Keep the iOS deployment target at 14.0 or newer.

## Troubleshooting

- **`GameCenterKit` is unavailable:** confirm the add-on path, matching Apple binary,
  and enabled editor plug-in. The singleton is intentionally absent on platforms with
  no declared library.
- **Authentication UI does not appear:** make sure the app has an active window scene,
  a Game Center entitlement, a signed provisioning profile, and network access.
- **A score or achievement fails:** compare the identifier exactly with App Store
  Connect and inspect the emitted error string.
- **The iOS export cannot link GameKit:** re-enable the editor plug-in; it adds the
  system `GameKit.framework` during export.

GameCenterKit Core 1.0 intentionally does not bind saved games, challenges,
multiplayer matchmaking, or turn-based matches.

## License

GameCenterKit is distributed under the MIT License. Release packages include a
combined `LICENSE` containing the GameCenterKit notice and the MIT notice for the
statically linked `godot-cpp` runtime.
