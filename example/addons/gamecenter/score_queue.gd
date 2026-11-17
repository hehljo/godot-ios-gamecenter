extends RefCounted
class_name GameCenterScoreQueue

## Pure offline queue for leaderboard submissions, stored as plain data so a
## save game can hold it. Apple: "Don't submit scores to past occurrences" of a
## recurring leaderboard. Every entry therefore carries the period it belongs
## to; prune() drops entries whose period is over. PERIOD_ALL never expires.
##
## Entry: {"board": String, "score": int, "period": String, "key": String}
##   period: PERIOD_ALL or a caller-defined name ("day", "week", …)
##   key:    the occurrence of that period, e.g. GameCenterScoreQueue.period_key(...)

const PERIOD_ALL := "all"
const MAX_ENTRIES := 64


## Adds an entry. One entry per board and occurrence; a second score for the
## same pair keeps only the better one. Invalid entries are ignored.
static func enqueue(queue: Array, entry: Dictionary, lower_is_better: bool) -> Array:
	var result := _valid_entries(queue)
	if not is_valid_entry(entry):
		return result
	var clean := _clean(entry)
	for index in result.size():
		var existing: Dictionary = result[index]
		if existing.board == clean.board and existing.period == clean.period and existing.key == clean.key:
			if _better(int(clean.score), int(existing.score), lower_is_better):
				result[index] = clean
			return result
	result.append(clean)
	while result.size() > MAX_ENTRIES:
		result.remove_at(0)
	return result


## Drops entries of expired occurrences. current_keys maps each period name to
## the key of its running occurrence; a period missing there counts as expired.
static func prune(queue: Array, current_keys: Dictionary) -> Array:
	var result: Array = []
	for entry: Dictionary in _valid_entries(queue):
		if entry.period == PERIOD_ALL or String(current_keys.get(entry.period, "")) == entry.key:
			result.append(entry)
	return result


## Removes one submitted entry (matched by board, period and key).
static func remove(queue: Array, entry: Dictionary) -> Array:
	var result: Array = []
	for existing: Dictionary in _valid_entries(queue):
		if not (
			existing.board == String(entry.get("board", ""))
			and existing.period == String(entry.get("period", ""))
			and existing.key == String(entry.get("key", ""))
		):
			result.append(existing)
	return result


## Index of the occurrence that contains unix_time for a recurrence starting at
## start_unix with duration_seconds — the same two values App Store Connect
## stores as recurrenceStartDate and recurrenceDuration. Before the start: -1.
static func occurrence_index(unix_time: int, start_unix: int, duration_seconds: int) -> int:
	if duration_seconds <= 0 or unix_time < start_unix:
		return -1
	return int((unix_time - start_unix) / duration_seconds)


static func period_key(unix_time: int, start_unix: int, duration_seconds: int) -> String:
	return str(occurrence_index(unix_time, start_unix, duration_seconds))


static func is_valid_entry(entry: Variant) -> bool:
	if not entry is Dictionary:
		return false
	var data: Dictionary = entry
	var score: Variant = data.get("score")
	return (
		not String(data.get("board", "")).strip_edges().is_empty()
		and (score is int or (score is float and is_finite(score) and score == floorf(score)))
		and not String(data.get("period", "")).strip_edges().is_empty()
		and (String(data.get("period", "")) == PERIOD_ALL or not String(data.get("key", "")).is_empty())
	)


static func _valid_entries(queue: Array) -> Array:
	var result: Array = []
	for entry: Variant in queue:
		if is_valid_entry(entry):
			result.append(_clean(entry))
	return result


static func _clean(entry: Dictionary) -> Dictionary:
	return {
		"board": String(entry.board).strip_edges(),
		"score": int(entry.score),
		"period": String(entry.period).strip_edges(),
		"key": String(entry.get("key", "")),
	}


static func _better(candidate: int, previous: int, lower_is_better: bool) -> bool:
	return candidate < previous if lower_is_better else candidate > previous
