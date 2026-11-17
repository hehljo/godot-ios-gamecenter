extends RefCounted
class_name GameCenterBridge

## Platform bridge in front of the GameCenterKit singleton. Games talk to this
## object only. Without the native singleton (Android, Web, desktop, editor
## tests) every call answers with the same failure signal a real failure would
## send, one frame later, so game code has exactly one path to handle.

signal authenticated(ok: bool, error: String)
signal score_submitted(ok: bool, leaderboard_id: String, error: String)
signal review_requested(ok: bool, error: String)
signal panel_closed(panel: String)
signal panel_failed(panel: String, error: String)

const SINGLETON_NAME := "GameCenterKit"
const UNAVAILABLE := "Game Center is not available on this platform"

var _backend: Object = null


## backend: an object with the GameCenterKit API (tests pass a fake). Without
## one, the engine singleton is used when use_engine is true and it exists.
func _init(backend: Object = null, use_engine: bool = true) -> void:
	_backend = backend
	if _backend == null and use_engine and Engine.has_singleton(SINGLETON_NAME):
		_backend = Engine.get_singleton(SINGLETON_NAME)
	if _backend != null:
		_relay("authenticated", func(ok: bool, error: String) -> void:
			authenticated.emit(ok, error))
		_relay("score_submitted", func(ok: bool, board: String, error: String) -> void:
			score_submitted.emit(ok, board, error))
		_relay("review_requested", func(ok: bool, error: String) -> void:
			review_requested.emit(ok, error))
		_relay("panel_closed", func(panel: String) -> void:
			panel_closed.emit(panel))
		_relay("panel_failed", func(panel: String, error: String) -> void:
			panel_failed.emit(panel, error))


func is_available() -> bool:
	return _backend != null


func authenticate() -> void:
	if _backend == null:
		_fail("authenticated", [false, UNAVAILABLE])
		return
	_backend.call("authenticate")


func is_authenticated() -> bool:
	return _backend != null and bool(_backend.call("is_authenticated"))


func player_display_name() -> String:
	return "" if _backend == null else String(_backend.call("player_display_name"))


func submit_score(leaderboard_id: String, score: int) -> void:
	if _backend == null:
		_fail("score_submitted", [false, leaderboard_id, UNAVAILABLE])
		return
	_backend.call("submit_score", leaderboard_id, score)


func show_leaderboard(leaderboard_id: String) -> void:
	if _backend == null:
		_fail("panel_failed", ["leaderboard", UNAVAILABLE])
		return
	_backend.call("show_leaderboard", leaderboard_id)


## ok=true means "handed to StoreKit", not "the player saw a dialog".
func request_review() -> void:
	if _backend == null:
		_fail("review_requested", [false, UNAVAILABLE])
		return
	_backend.call("request_review")


func _relay(signal_name: String, handler: Callable) -> void:
	if _backend.has_signal(signal_name):
		_backend.connect(signal_name, handler)


func _fail(signal_name: String, args: Array) -> void:
	callv("call_deferred", ["emit_signal", signal_name] + args)
