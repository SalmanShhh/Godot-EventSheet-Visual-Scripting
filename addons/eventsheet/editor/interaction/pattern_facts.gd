# Godot EventSheets - THE PATTERN REGISTRY: which events of a sheet read as a known code pattern.
#
# A pattern is a shape several lines make together - a cooldown counted down by dt, an object pool,
# a state machine, a wait sequence, a save file. The readings that recognise one (the sentence
# grammar, the row builder's pre-passes) CLAIM it here, once per rebuild, naming the pattern, the
# row that owns it, the source lines that are its evidence and, when one ships, the behavior that
# could replace the hand-written shape. Everything that talks ABOUT patterns - the ⟡ chip on the
# owning event, the hover evidence, Adopt behavior, the Doctor's pattern smells, the coverage
# chip's counts, the Manual's "Patterns using this" - reads the claims; nothing re-derives them.
#
# Claims are per sheet and live exactly as long as one row build: the builder clears them at the
# start of a rebuild and the readings fill them as they go. Nothing here is persisted, nothing is
# written back to the file, and a claim is a plain Dictionary so a test can pin it by value.
@tool
class_name EventSheetPatternFacts
extends RefCounted

## The pattern ids the readings may claim. Frozen once shipped (a Manual page, a Doctor check and the
## chips all key on them); add, never rename.
const PATTERN_IDS: PackedStringArray = [
	"state_machine", "object_pool", "wait_sequence", "countdown", "local_storage", "existence",
	"background_loading", "movement", "multiplayer", "sprite_animation", "ui", "sound", "juice",
	"navigation", "effects", "tilemap", "camera", "blank_event",
	"bullet", "turret", "move_to", "rotate", "wrap", "bound", "pin", "fade", "line_of_sight", "drag_drop",
	"anchor", "solid", "jumpthru", "picking", "family", "layers", "text", "platform", "create_object",
	"overlap", "advanced_random", "date",
	"ajax", "lighting", "fps_look", "background",
	"physics", "path", "data_asset", "window", "text_format",
	"test_sheet", "command_tool", "pack_recipe"
]

## sheet instance id -> Array[Dictionary] of claims. A claim is
## {pattern: String, row_uid: String, event_uid: String, evidence: PackedStringArray (source lines),
##  words: String (the one line the chip says), adoptable: String ("" or the pack id that could
##  replace the shape), ace_ids: PackedStringArray (the sheet ACEs the pattern is made of)}.
static var _claims: Dictionary = {}

## The sheets whose FILE-LEVEL readings have already had their say since the last clear. A claim is
## made by two different passes - the one walk over the file's lines, and the row builder's own span
## pass - and they do not run in a fixed order relative to every clear. Recording that the first has
## run lets anything reading the registry ask for it on demand instead of trusting an ordering, so a
## marker can never go missing because a clear landed between the two.
static var _stated: Dictionary = {}


## Forget every claim for a sheet. The row builder calls this at the start of a rebuild.
static func clear(sheet: EventSheetResource) -> void:
	if sheet == null:
		return
	_claims.erase(sheet.get_instance_id())
	_stated.erase(sheet.get_instance_id())


## Record that a reading recognised a pattern. Unknown pattern ids are refused loudly in the editor
## (a typo here would silently hide a chip) and ignored at runtime.
static func claim(sheet: EventSheetResource, pattern: String, row_uid: String, event_uid: String,
		evidence: PackedStringArray = PackedStringArray(), words: String = "", adoptable: String = "",
		ace_ids: PackedStringArray = PackedStringArray()) -> void:
	if sheet == null:
		return
	if not PATTERN_IDS.has(pattern):
		push_warning("EventSheetPatternFacts: unknown pattern id '%s'" % pattern)
		return
	var key: int = sheet.get_instance_id()
	if not _claims.has(key):
		_claims[key] = []
	var list: Array = _claims[key]
	for existing: Variant in list:
		if (existing as Dictionary).get("pattern", "") == pattern and (existing as Dictionary).get("row_uid", "") == row_uid:
			return
	list.append({
		"pattern": pattern, "row_uid": row_uid, "event_uid": event_uid, "evidence": evidence,
		"words": words, "adoptable": adoptable, "ace_ids": ace_ids
	})


## Whether the file-level readings have stated this sheet's patterns since the last clear.
static func has_stated(sheet: EventSheetResource) -> bool:
	return sheet != null and _stated.has(sheet.get_instance_id())


## Record that they have. Called by the walk itself, never by a consumer.
static func mark_stated(sheet: EventSheetResource) -> void:
	if sheet != null:
		_stated[sheet.get_instance_id()] = true


## Every claim for a sheet, in the order they were made. Empty when nothing claimed.
static func claims(sheet: EventSheetResource) -> Array:
	if sheet == null:
		return []
	return (_claims.get(sheet.get_instance_id(), []) as Array).duplicate()


## The claims that own a given row, "" pattern when none.
static func claims_for_row(sheet: EventSheetResource, row_uid: String) -> Array:
	var out: Array = []
	for entry: Variant in claims(sheet):
		if (entry as Dictionary).get("row_uid", "") == row_uid:
			out.append(entry)
	return out


## The distinct pattern ids a sheet uses, and how many of them have a shipped behavior to adopt -
## what the coverage chip prints as "N patterns · M adoptable".
static func summary(sheet: EventSheetResource) -> Dictionary:
	var patterns: Dictionary = {}
	var adoptable: Dictionary = {}
	for entry: Variant in claims(sheet):
		var pattern: String = str((entry as Dictionary).get("pattern", ""))
		patterns[pattern] = true
		if not str((entry as Dictionary).get("adoptable", "")).is_empty():
			adoptable[pattern] = true
	return {"patterns": patterns.size(), "adoptable": adoptable.size()}
