extends SceneTree

## Unit tests for the platform-free GDScript modules of the add-on. Runs on any
## OS: godot --headless --path example --script res://tests/pure_modules.gd
## Exit 0 only with zero failures AND the expected number of checks.

const ReviewPolicy := preload("res://addons/gamecenter/review_policy.gd")
const ScoreQueue := preload("res://addons/gamecenter/score_queue.gd")
const Bridge := preload("res://addons/gamecenter/game_center_bridge.gd")
const EXPECTED_CHECKS := 46

var checks := 0
var failures: Array[String] = []


class FakeKit:
	extends Object
	signal authenticated(ok: bool, error: String)
	signal score_submitted(ok: bool, leaderboard_id: String, error: String)
	signal review_requested(ok: bool, error: String)
	signal panel_closed(panel: String)
	signal panel_failed(panel: String, error: String)
	var calls: Array[String] = []

	func authenticate() -> void:
		calls.append("authenticate")

	func is_authenticated() -> bool:
		return true

	func player_display_name() -> String:
		return "Probe"

	func submit_score(board: String, score: int) -> void:
		calls.append("submit:%s:%d" % [board, score])
		score_submitted.emit(true, board, "")

	func show_leaderboard(board: String) -> void:
		calls.append("show:" + board)

	func request_review() -> void:
		calls.append("review")
		review_requested.emit(true, "")


func _initialize() -> void:
	_review_policy_cases()
	_score_queue_cases()
	await _bridge_cases()
	if checks != EXPECTED_CHECKS:
		failures.append("expected %d checks, ran %d" % [EXPECTED_CHECKS, checks])
	for failure in failures:
		push_error(failure)
	print("pure_modules: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func expect(actual: Variant, expected: Variant, label: String) -> void:
	check(actual == expected, "%s: expected %s, got %s" % [label, expected, actual])


func _review_policy_cases() -> void:
	var winner := {"asked_versions": [], "wins": 1, "runs": 1, "play_seconds": 30.0}
	var good := {"version": "1.1.0", "in_menu": true, "last_outcome": "win", "ad_just_shown": false}
	expect(ReviewPolicy.decide(winner, good), ReviewPolicy.ASK, "first win in menu asks")
	# Each blocking rule gets a case that passes every other rule.
	expect(ReviewPolicy.decide(winner, _with(good, "version", " ")), ReviewPolicy.NO_VERSION, "blank version")
	expect(ReviewPolicy.decide(winner, _with(good, "in_menu", false)), ReviewPolicy.NOT_IN_MENU, "mid-run")
	expect(ReviewPolicy.decide(winner, _with(good, "last_outcome", "death")), ReviewPolicy.AFTER_DEATH, "after death")
	expect(ReviewPolicy.decide(winner, _with(good, "ad_just_shown", true)), ReviewPolicy.AFTER_AD, "after ad")
	expect(ReviewPolicy.decide(winner, _with(good, "last_outcome", "quit")), ReviewPolicy.ASK, "quit is not death")
	var asked := ReviewPolicy.record_asked(winner, "1.1.0")
	expect(ReviewPolicy.decide(asked, good), ReviewPolicy.ALREADY_ASKED, "once per version")
	expect(ReviewPolicy.decide(asked, _with(good, "version", "1.2.0")), ReviewPolicy.ASK, "new version asks again")
	expect(winner.asked_versions.size(), 0, "record_asked leaves input untouched")
	expect(ReviewPolicy.record_asked(asked, "1.1.0").asked_versions.size(), 1, "record_asked is idempotent")
	# Play threshold without a win: runs AND time are both required.
	var veteran := {"wins": 0, "runs": 3, "play_seconds": 600.0}
	expect(ReviewPolicy.decide(veteran, good), ReviewPolicy.ASK, "runs and time without win")
	expect(ReviewPolicy.decide(_with(veteran, "runs", 2), good), ReviewPolicy.NOT_ENOUGH_PLAY, "too few runs")
	expect(ReviewPolicy.decide(_with(veteran, "play_seconds", 599.0), good), ReviewPolicy.NOT_ENOUGH_PLAY, "too little time")
	expect(ReviewPolicy.decide({}, good), ReviewPolicy.NOT_ENOUGH_PLAY, "empty state")
	expect(ReviewPolicy.decide(veteran, good, {"min_runs": 5}), ReviewPolicy.NOT_ENOUGH_PLAY, "rule override")
	check(not ReviewPolicy.should_ask(winner, {}), "empty moment never asks")


func _score_queue_cases() -> void:
	var queue: Array = []
	var day_a := {"board": "daily", "score": 9000, "period": "day", "key": "10"}
	queue = ScoreQueue.enqueue(queue, day_a, true)
	queue = ScoreQueue.enqueue(queue, _with(day_a, "score", 9500), true)
	expect(queue.size(), 1, "same occurrence merges")
	expect(queue[0].score, 9000, "worse time does not replace")
	queue = ScoreQueue.enqueue(queue, _with(day_a, "score", 8000), true)
	expect(queue[0].score, 8000, "better time replaces")
	var points := {"board": "endless", "score": 50, "period": "all", "key": ""}
	queue = ScoreQueue.enqueue(queue, points, false)
	queue = ScoreQueue.enqueue(queue, _with(points, "score", 70), false)
	expect(queue.size(), 2, "all-time entry added once")
	expect(queue[1].score, 70, "higher points replace")
	queue = ScoreQueue.enqueue(queue, _with(day_a, "key", "11"), true)
	expect(queue.size(), 3, "next occurrence is its own entry")
	var pruned := ScoreQueue.prune(queue, {"day": "11"})
	expect(pruned.size(), 2, "expired day dropped")
	check(pruned.all(func(e: Dictionary) -> bool: return e.key != "10"), "only key 10 dropped")
	expect(ScoreQueue.prune(queue, {}).size(), 1, "unknown period counts as expired, all-time stays")
	expect(ScoreQueue.remove(queue, day_a).size(), 2, "remove matches board+period+key")
	expect(ScoreQueue.enqueue([], {"board": " ", "score": 1, "period": "all"}, true).size(), 0, "blank board rejected")
	expect(ScoreQueue.enqueue([], {"board": "x", "score": 1.5, "period": "all"}, true).size(), 0, "fractional score rejected")
	expect(ScoreQueue.enqueue([], {"board": "x", "score": 1, "period": "day", "key": ""}, true).size(), 0, "periodic entry needs key")
	expect(ScoreQueue.prune(["junk", {"board": "x"}, points], {}).size(), 1, "garbage from a save is dropped")
	var many: Array = []
	for index in ScoreQueue.MAX_ENTRIES + 5:
		many = ScoreQueue.enqueue(many, {"board": "b%d" % index, "score": index, "period": "all"}, false)
	expect(many.size(), ScoreQueue.MAX_ENTRIES, "queue is capped")
	expect(many[0].board, "b5", "cap drops the oldest")
	# Occurrence index mirrors App Store Connect recurrenceStartDate/Duration.
	var start := 1_700_000_000
	expect(ScoreQueue.occurrence_index(start - 1, start, 86400), -1, "before start")
	expect(ScoreQueue.occurrence_index(start, start, 86400), 0, "boundary belongs to new occurrence")
	expect(ScoreQueue.occurrence_index(start + 86399, start, 86400), 0, "last second of first day")
	expect(ScoreQueue.occurrence_index(start + 86400, start, 86400), 1, "second day")
	expect(ScoreQueue.period_key(start + 7 * 86400 * 3, start, 7 * 86400), "3", "week key")
	expect(ScoreQueue.occurrence_index(start, start, 0), -1, "zero duration rejected")


func _bridge_cases() -> void:
	var offline := Bridge.new(null, false)
	check(not offline.is_available(), "no backend means unavailable")
	check(not offline.is_authenticated(), "offline is never authenticated")
	var answers: Array = []
	offline.review_requested.connect(func(ok: bool, error: String) -> void: answers.append(["review", ok, error]))
	offline.score_submitted.connect(func(ok: bool, board: String, _e: String) -> void: answers.append(["score", ok, board]))
	offline.request_review()
	offline.submit_score("daily", 5)
	expect(answers.size(), 0, "offline failure is deferred, not synchronous")
	await process_frame
	expect(answers.size(), 2, "offline answers after one frame")
	check(answers.size() == 2 and answers[0][1] == false and answers[1] == ["score", false, "daily"],
		"offline answers are failures with the board id")

	var fake := FakeKit.new()
	var online := Bridge.new(fake, false)
	var relayed: Array = []
	online.review_requested.connect(func(ok: bool, _error: String) -> void: relayed.append(["review", ok]))
	online.score_submitted.connect(func(ok: bool, board: String, _e: String) -> void: relayed.append([board, ok]))
	online.request_review()
	online.submit_score("weekly", 42)
	expect(fake.calls, ["review", "submit:weekly:42"] as Array[String], "calls reach the backend")
	expect(relayed, [["review", true], ["weekly", true]], "backend signals are relayed")
	expect(online.player_display_name(), "Probe", "display name passes through")
	fake.free()


func _with(source: Dictionary, key: String, value: Variant) -> Dictionary:
	var copy := source.duplicate(true)
	copy[key] = value
	return copy
