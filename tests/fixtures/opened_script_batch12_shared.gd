@tool
class_name Batch12SharedStoreFixture
extends RefCounted

## The pattern ids the readings may claim. Frozen once shipped; add, never rename.
const PATTERN_IDS: PackedStringArray = ["state_machine", "object_pool", "countdown"]

static var _claims: Dictionary = {}
static var _stated: Dictionary = {}


static func clear(sheet: EventSheetResource) -> void:
	if sheet == null:
		return
	_claims.erase(sheet.get_instance_id())


static func claim(sheet: EventSheetResource, pattern: String, row_uid: String) -> void:
	if not PATTERN_IDS.has(pattern):
		push_warning("Pattern facts: unknown pattern id")
		return
	var key: int = sheet.get_instance_id()
	if not _claims.has(key):
		_claims[key] = []
	_stated[key] = true
	push_error("Pattern facts: claimed twice")
