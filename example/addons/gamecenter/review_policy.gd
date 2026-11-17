extends RefCounted
class_name GameCenterReviewPolicy

## Pure decision whether the game may hand a review request to StoreKit now.
## No platform access: callers pass plain dictionaries, tests call it directly.
## StoreKit still decides on its own whether a dialog appears (at most three
## times in 365 days, never in TestFlight); this policy only picks the moment.
##
## state:  {"asked_versions": Array[String], "wins": int, "runs": int, "play_seconds": float}
## moment: {"version": String, "in_menu": bool, "last_outcome": String, "ad_just_shown": bool}
##         last_outcome is one of OUTCOME_* ("" before the first run of a session).
## rules:  overrides for DEFAULT_RULES.

const ASK := "ask"
const NO_VERSION := "no_version"
const ALREADY_ASKED := "already_asked_this_version"
const NOT_IN_MENU := "not_in_menu"
const AFTER_DEATH := "after_death"
const AFTER_AD := "after_ad"
const NOT_ENOUGH_PLAY := "not_enough_play"

const OUTCOME_WIN := "win"
const OUTCOME_DEATH := "death"
const OUTCOME_QUIT := "quit"

const DEFAULT_RULES := {
	"min_wins": 1,
	"min_runs": 3,
	"min_play_seconds": 600.0,
}


## Returns ASK or the first reason that blocks the request. Every reason is
## checked independently of the others' order of discovery in tests.
static func decide(state: Dictionary, moment: Dictionary, rules: Dictionary = {}) -> String:
	var version := String(moment.get("version", "")).strip_edges()
	if version.is_empty():
		return NO_VERSION
	if version in _asked_versions(state):
		return ALREADY_ASKED
	if not bool(moment.get("in_menu", false)):
		return NOT_IN_MENU
	if String(moment.get("last_outcome", "")) == OUTCOME_DEATH:
		return AFTER_DEATH
	if bool(moment.get("ad_just_shown", false)):
		return AFTER_AD
	if not _has_enough_play(state, _merged_rules(rules)):
		return NOT_ENOUGH_PLAY
	return ASK


static func should_ask(state: Dictionary, moment: Dictionary, rules: Dictionary = {}) -> bool:
	return decide(state, moment, rules) == ASK


## Returns a copy of state that records the request for this version. Call it
## when the request was handed to StoreKit, whatever StoreKit then shows.
static func record_asked(state: Dictionary, version: String) -> Dictionary:
	var result := state.duplicate(true)
	var asked := _asked_versions(state)
	var clean := version.strip_edges()
	if not clean.is_empty() and clean not in asked:
		asked.append(clean)
	result["asked_versions"] = asked
	return result


static func _asked_versions(state: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var raw: Variant = state.get("asked_versions", [])
	if raw is Array:
		for entry: Variant in raw:
			result.append(String(entry))
	return result


static func _merged_rules(rules: Dictionary) -> Dictionary:
	var result := DEFAULT_RULES.duplicate()
	result.merge(rules, true)
	return result


static func _has_enough_play(state: Dictionary, rules: Dictionary) -> bool:
	if int(state.get("wins", 0)) >= int(rules.min_wins):
		return true
	return (
		int(state.get("runs", 0)) >= int(rules.min_runs)
		and float(state.get("play_seconds", 0.0)) >= float(rules.min_play_seconds)
	)
