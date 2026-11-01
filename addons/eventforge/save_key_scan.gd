# Godot EventSheets - what a script's SOURCE says about Save System keys
#
# The one reading of save keys that both the Project Doctor's save-key checks and the editor's
# "saved" badge make, so a badge and a finding can never disagree about what a save is. It lives in a
# file of its own, with no class_name and no dependency, because the badge is drawn on the first row
# build of any sheet that mentions `save_` and must not pay to compile the whole Doctor (several
# seconds of GDScript) just to read a few regular expressions. Reach it by path or preload.
@tool
extends RefCounted


## The save backend's OWN bookkeeping, never a value the author is responsible for saving. The
## Save System reserves every "__" name for exactly that reason ("__persist" for the scene-tree
## snapshot, "__version" for which build wrote the file, "__addons" for the autoload snapshot),
## and it writes them from inside its own backends where no Save Value row exists to be found. A
## game key is not spelled this way, so skipping them costs no coverage. Reported by
## save_key_usage all the same - a tool asking what a script touches wants the truth; it is the
## BLAME that is wrong here, not the fact.
##
## The "seen:" namespace is reserved for the same reason and a second one. First Time In This Save,
## Has Seen, Mark Seen and Forget Seen keep their memory under it, and they WRITE it through
## `call(&"save_value", ...)` on a store they look up at run time - a shape no reader of source text
## can recognise as a save. Left out, every project using those rows would be told nothing ever
## saves a key its own rows save on the line above.
const RESERVED_SAVE_KEY_PREFIXES: PackedStringArray = ["__", "seen:"]


static func _is_reserved_save_key(key: String) -> bool:
	for prefix: String in RESERVED_SAVE_KEY_PREFIXES:
		if key.begins_with(prefix):
			return true
	return false



## Whether a source is doing save work at all - the gate on counting a subscript assignment as a
## save write. Deliberately a marker list rather than "mentions save": a file that writes a save
## payload calls one of these. `use_upgraded_save` is in the list because a MIGRATION written the
## documented way - rewrite the record the On Save Needs Upgrade trigger handed you, then hand it
## back - ends there and nowhere else, and without it the migrated key reads as never saved.
const _SAVE_WORK_MARKERS: PackedStringArray = ["save_value", "save_number", "save_text", "save_game",
	"save_state", "read_all", "save_node_state", "save_group_state", "save_singleton_state",
	"use_upgraded_save"]


static func _does_save_work(source: String) -> bool:
	for marker: String in _SAVE_WORK_MARKERS:
		if source.contains(marker):
			return true
	return false


## Save System verbs whose FIRST argument is the save key.
const _SAVE_KEY_WRITERS: PackedStringArray = ["save_value", "save_number", "save_text"]
const _SAVE_KEY_READERS: PackedStringArray = ["load_value", "load_number", "load_text", "has_save_key", "load_group_state"]
## Verbs whose key follows one plain argument - save_node_state($Player, "player").
const _SAVE_SLOT_WRITERS: PackedStringArray = ["save_node_state", "save_group_state", "save_singleton_state"]
const _SAVE_SLOT_READERS: PackedStringArray = ["load_node_state", "load_singleton_state"]


## What one script's SOURCE says about save keys, as {"saved", "slot_keys", "loaded", "remembered"}
## sorted PackedStringArrays. Pure (text in, keys out) so the rule is pinned without planting a
## deliberately asymmetric fixture in the project - which would make the Doctor report a warning
## on this repo forever, the exact noise the check exists to avoid. Also the API's save_keys_used.
##
## "saved" is every write of any kind; "slot_keys" is the subset that are TOP-LEVEL keys in the save
## file (a verb call or a subscript write), leaving out `save_state()` members - those live inside
## their own node's dictionary and share nothing with a slot key but a spelling.
static func save_key_usage(source: String) -> Dictionary:
	# Comments are prose, not code: a call written out in a `# reads it with load_number("coins")`
	# note is documentation, and counting it as a real read is how a text scanner accuses a working
	# game. Whole-line comments come off before anything is matched.
	var scanned: String = _without_comment_lines(source)
	var slot_keys: Dictionary = {}
	var snapshot: Dictionary = {}
	var loaded: Dictionary = {}
	var remembered: Dictionary = {}
	# Most scripts in a project touch no save at all; skipping them costs one substring scan.
	if scanned.contains("save_") or scanned.contains("load_"):
		_note_save_keys(scanned, _save_call_pattern(_SAVE_KEY_WRITERS, 1, false), slot_keys)
		_note_save_keys(scanned, _save_call_pattern(_SAVE_SLOT_WRITERS, 2, false), slot_keys)
		_note_save_keys(scanned, _save_call_pattern(_SAVE_KEY_READERS, 1, true), loaded)
		_note_save_keys(scanned, _save_call_pattern(_SAVE_SLOT_READERS, 2, true), loaded)
		_note_snapshot_keys(scanned, snapshot)
		# A save payload is often written by SUBSCRIPT rather than by a verb: a migration handed the
		# raw Dictionary rewrites it in place (`save_data["health"] = save_data["hp"]`), and the Save
		# System's own format backends do the same. Counted as a write, but only inside a file that is
		# demonstrably doing save work, so an unrelated dictionary elsewhere in the game cannot
		# silence a real finding.
		if _does_save_work(scanned):
			_note_save_keys(scanned, _cached_regex("\\[\\s*\"([^\"]+)\"\\s*\\]\\s*=(?!=)"), slot_keys)
	if scanned.contains("__remember_cfg.set_value("):
		_note_save_keys(scanned, _cached_regex("__remember_cfg\\.set_value\\(\"[^\"]*\",\\s*\"([^\"]+)\""), remembered)
	var saved: Dictionary = slot_keys.duplicate()
	for key: String in snapshot.keys():
		saved[key] = true
	return {
		"saved": _sorted_keys(saved),
		"slot_keys": _sorted_keys(slot_keys),
		"loaded": _sorted_keys(loaded),
		"remembered": _sorted_keys(remembered)
	}


## The source with every whole-line comment removed (the line itself stays, so nothing shifts that
## the caller might count on). A `#` mid-line is left alone: telling a real `#` from one inside a
## string needs a parser, and dropping the rest of such a line could hide a genuine call.
static func _without_comment_lines(source: String) -> String:
	if not source.contains("#"):
		return source
	var kept: PackedStringArray = PackedStringArray()
	for line: String in source.split("\n"):
		kept.append("" if line.strip_edges().begins_with("#") else line)
	return "\n".join(kept)


## The regex that finds one family of Save System calls and captures its KEY literal.
## `key_position` is 1 when the key is the first argument and 2 when it follows one plain argument.
## `require_receiver` demands a `something.` in front (a real call, never a `func load_value(`
## declaration); writes drop that demand so a wrapper of any shape still registers as a write.
## An argument list containing a call of its own stops the match dead, which is intended: a
## computed key is not decidable, and silence is the correct answer to what we cannot read.
##
## The leading argument may itself be a STRING - `save_group_state("enemies", "enemy_state")` is the
## documented way to snapshot a group - so the alternation admits a quoted literal as well as a
## plain token. Leaving it out made every documented Save Group State row invisible as a write while
## its Load Group State partner still matched as a read: a false accusation about working code.
static func _save_call_pattern(methods: PackedStringArray, key_position: int, require_receiver: bool) -> RegEx:
	var lead: String = "\\." if require_receiver else "(?:^|[^A-Za-z0-9_])"
	var before_key: String = "" if key_position <= 1 else "(?:\"[^\"]*\"|[^\"(),\\n]+),\\s*"
	return _cached_regex("%s(?:%s)\\(\\s*%s\"([^\"]+)\"" % [lead, "|".join(methods), before_key])


static func _note_save_keys(source: String, pattern: RegEx, into: Dictionary) -> void:
	for found: RegExMatch in pattern.search_all(source):
		into[found.get_string(1)] = true


## The keys a `save_state()` returns. A value persisted through the save_state/load_state seam IS
## written - counting it is what keeps the check quiet about a pack (or a hand-written node) that
## saves through the seam rather than through a Save Value row.
##
## The seam is found at ANY indentation, because an inner `class Inner:` carrying its own save_state
## is exactly the shape a pack author reaches for when several sub-objects each snapshot themselves;
## the body then ends where the indentation returns to the declaration's own level or shallower.
static func _note_snapshot_keys(source: String, into: Dictionary) -> void:
	if not source.contains("func save_state("):
		return
	var key_pattern: RegEx = _cached_regex("\"([^\"]+)\"\\s*:")
	var inside: bool = false
	var declared_indent: int = 0
	for line: String in source.split("\n"):
		var stripped: String = line.strip_edges()
		if stripped.begins_with("func save_state(") or stripped.begins_with("static func save_state("):
			inside = true
			declared_indent = line.length() - line.lstrip("\t ").length()
			continue
		if not inside:
			continue
		if not stripped.is_empty() and (line.length() - line.lstrip("\t ").length()) <= declared_indent:
			inside = false
			continue
		_note_save_keys(line, key_pattern, into)


static func _sorted_keys(keys: Dictionary) -> PackedStringArray:
	var sorted: Array = keys.keys()
	sorted.sort()
	return PackedStringArray(sorted)


## Compiled regexes reused across every scanned script - this check compiles five patterns and
## would otherwise rebuild them once per file in the project.
static var _regex_cache: Dictionary = {}


static func _cached_regex(pattern: String) -> RegEx:
	if not _regex_cache.has(pattern):
		_regex_cache[pattern] = RegEx.create_from_string(pattern)
	return _regex_cache[pattern]
