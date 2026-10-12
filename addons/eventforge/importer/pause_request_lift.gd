# EventForge - the two lines a pause REQUEST is, and the row each pair means.
#
# Ask To Pause and Stop Asking To Pause each write two statements: the change to the set of who is
# asking, then the pause switch set from it.
#
#     _pause_requests[&"inventory"] = true
#     get_tree().paused = true
#
#     _pause_requests.erase(&"inventory")
#     get_tree().paused = not _pause_requests.is_empty()
#
# WHY THE PAIR IS CLAIMED HERE. Each second line on its own is already somebody's row: the first is
# Pause The Game verbatim, so a request opened line by line would read as a plain pause and lose who
# asked - and saved back from that reading, the next change to it would be a Set Paused written OVER
# the requests rather than through them. A run claimed here is asked before either single line is
# looked at, so the pair opens as the request it is and saves back byte for byte.
#
# WHAT IS DELIBERATELY NOT CLAIMED. A lone `get_tree().paused = true` keeps the reading it has always
# had, and so does a lone write to the set: only the pair, adjacent and at the same indentation, is a
# request. The question, Pause Requested By, is one call and lifts through the general index.
@tool
class_name EventForgePauseRequestLift
extends RefCounted

## The cheap first refusals: the set's own name, spelled the way each run opens on it.
const ASK_MARK: String = "_pause_requests[&"
const STOP_MARK: String = "_pause_requests.erase(&"

## Built once for the life of the session, like every other family's table.
static var _entries: Array[Dictionary] = []


## The row a run of statements means, or {} when nothing here claims it.
static func match_run(lines: PackedStringArray, index: int, depth: int) -> Dictionary:
	return EventForgeLiftTable.match_run(lift_entries(), lines, index, depth)


## Every run this family claims.
static func lift_entries() -> Array[Dictionary]:
	if _entries.is_empty():
		_entries = [_ask_entry(), _stop_entry()]
	return _entries


## Ask To Pause: this reason joins the set, and the game pauses. The reason is the row's one field,
## the quoted name after the `&` that makes it a StringName - the same key spelling all three rows use,
## so a request is always taken back and asked about under the key it was made with.
static func _ask_entry() -> Dictionary:
	return {
		"id": "pause_request_ask",
		"ace_id": "AskToPause",
		"mark": ASK_MARK,
		"statements": [
			{"pattern": "^_pause_requests\\[&(?<reason>.+)\\] = true$"},
			{"pattern": "^get_tree\\(\\)\\.paused = true$"}
		],
		"params": ["reason"],
		"shape": "_pause_requests[&{reason}] = true\nget_tree().paused = true",
		"slots": {"reason": "\"inventory\""}
	}


## Stop Asking To Pause: this reason leaves the set, and the game runs only when nobody is left.
static func _stop_entry() -> Dictionary:
	return {
		"id": "pause_request_stop",
		"ace_id": "StopAskingToPause",
		"mark": STOP_MARK,
		"statements": [
			{"pattern": "^_pause_requests\\.erase\\(&(?<reason>.+)\\)$"},
			{"pattern": "^get_tree\\(\\)\\.paused = not _pause_requests\\.is_empty\\(\\)$"}
		],
		"params": ["reason"],
		"shape": "_pause_requests.erase(&{reason})\nget_tree().paused = not _pause_requests.is_empty()",
		"slots": {"reason": "\"dialogue\""}
	}
