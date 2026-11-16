# Godot EventSheets - the API does what its words say, and every shape added to it is pinned.
#
# Each block below is one promise of the extension API that had no test:
#   block kinds   a kind can say "nothing to write for this row" and the compile still succeeds
#   the compiler  a sheet with no file and no output path writes no stray script
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "api_keeps_its_word_test"
const STRAY := "res://event_sheet_generated.gd"


class QuietKind extends EventSheetBlockKind:
	func _init() -> void:
		kind_id = "keeps_its_word.quiet"
		title = "Quiet"

	func fields() -> Array[Dictionary]:
		return [{"id": "on", "label": "On", "type": TYPE_BOOL, "default": false}]

	func emit(block: CustomBlockRow) -> PackedStringArray:
		return PackedStringArray(["# quiet"]) if bool(block.fields.get("on", false)) else PackedStringArray()

	func writes_nothing(block: CustomBlockRow) -> bool:
		return not bool(block.fields.get("on", false))


class MutedKind extends EventSheetBlockKind:
	func _init() -> void:
		kind_id = "keeps_its_word.muted"
		title = "Muted"

	func fields() -> Array[Dictionary]:
		return [{"id": "on", "label": "On", "type": TYPE_BOOL, "default": false}]


static func run() -> bool:
	var ok: bool = true
	ok = _writes_nothing() and ok
	ok = _stray_file() and ok
	return ok


static func _compile_block(kind_id: String, fields: Dictionary) -> Dictionary:
	var sheet: EventSheetResource = EventSheets.new_sheet()
	var row: CustomBlockRow = CustomBlockRow.new()
	row.kind_id = kind_id
	row.fields = fields
	sheet.events.append(row)
	return EventSheets.echo(sheet)


static func _writes_nothing() -> bool:
	EventSheets.register_block_kind(QuietKind.new())
	EventSheets.register_block_kind(MutedKind.new())
	var quiet_off: Dictionary = _compile_block("keeps_its_word.quiet", {"on": false})
	var quiet_on: Dictionary = _compile_block("keeps_its_word.quiet", {"on": true})
	# A kind that does not say so still fails the compile when its row with fields writes nothing.
	var silent: Dictionary = _compile_block("keeps_its_word.muted", {"on": true})
	return SUPPORT.pins(P, [
		["a kind that says it writes nothing for this row compiles", quiet_off.get("success"), true],
		["and the same kind switched on writes its line", (quiet_on.get("output", "") as String).contains("# quiet"), true],
		["a kind that does not say so still fails when it writes nothing", silent.get("success"), false],
		["the kind base class has the hook, default false", EventSheetBlockKind.new().writes_nothing(CustomBlockRow.new()), false],
	])


static func _stray_file() -> bool:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(STRAY))
	var result: Dictionary = EventSheetCompiler.compile(EventSheets.new_sheet())
	var wrote: bool = FileAccess.file_exists(STRAY)
	var helper: String = SUPPORT.compile_output(EventSheets.new_sheet())
	var helper_wrote: bool = FileAccess.file_exists(STRAY)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(STRAY))
	return SUPPORT.pins(P, [
		["the compiler writes no stray script for a sheet with no file", wrote, false],
		["and says why it wrote nothing", (result.get("warnings", []) as Array).size() > 0, true],
		["the text is still in the result", str(result.get("output", "")).is_empty(), false],
		["the test helper's compile_output writes none either", helper_wrote, false],
		["and still returns the text", helper.is_empty(), false],
	])
