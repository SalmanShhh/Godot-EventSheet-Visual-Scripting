# Godot EventSheets - the file-safety half of the public extension API.
#
# THE CONTRACT: a third-party block kind, a removed pack or a misbehaving callback can never
# corrupt, silently drop or overwrite a user's file. Each group below is one promise, in the order
# the fixes landed: resource-kind lifts go through the byte gate, a built-in kind id cannot be
# taken, a block the compiler cannot emit is reported, a block whose pack is gone still draws,
# compile() says what it writes, and edit() is atomic.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "api_file_safety_test"


## A resource-kind claim that does NOT reproduce the line it consumed: it swaps `## KEEP ME` for a
## different raw block. The importer must refuse it.
class UngatedResourceKind extends EventSheetBlockKind:
	func _init() -> void:
		kind_id = "audit.ungated"
		title = "Ungated"

	func addable() -> bool:
		return false

	func handles(entry: Resource) -> bool:
		return entry is RawCodeRow and (entry as RawCodeRow).code == "## CHANGED"

	func emit_lines(entry: Resource) -> PackedStringArray:
		return PackedStringArray([(entry as RawCodeRow).code])

	func lift(lines: PackedStringArray, i: int) -> Dictionary:
		if lines[i] == "## KEEP ME":
			var row: RawCodeRow = RawCodeRow.new()
			row.code = "## CHANGED"
			return {"resource": row, "consumed": 1}
		return {}


## A resource-kind claim that DOES reproduce its line, so the gate has to let it through.
class FaithfulResourceKind extends EventSheetBlockKind:
	func _init() -> void:
		kind_id = "audit.faithful"
		title = "Faithful"

	func addable() -> bool:
		return false

	func handles(entry: Resource) -> bool:
		return entry is RawCodeRow and (entry as RawCodeRow).code == "## FAITHFUL"

	func emit_lines(entry: Resource) -> PackedStringArray:
		return PackedStringArray([(entry as RawCodeRow).code])

	func lift(lines: PackedStringArray, i: int) -> Dictionary:
		if lines[i] == "## FAITHFUL":
			var row: RawCodeRow = RawCodeRow.new()
			row.code = "## FAITHFUL"
			return {"resource": row, "consumed": 1}
		return {}


static func run() -> bool:
	var ok: bool = true
	ok = _resource_claims_are_gated() and ok
	ok = _built_in_ids_cannot_be_taken() and ok
	ok = _a_block_that_cannot_be_written_is_reported() and ok
	ok = _a_block_without_its_pack_still_draws() and ok
	ok = _compile_says_what_it_writes() and ok
	ok = _edit_is_atomic() and ok
	return ok


static func _forget(kind_ids: Array) -> void:
	for kind_id: Variant in kind_ids:
		EventSheetBlockRegistry._kinds.erase(kind_id)


static func _row_kinds(sheet: EventSheetResource) -> Array:
	var out: Array = []
	for entry: Variant in sheet.events:
		out.append((entry as Object).get_class() if entry is Object else typeof(entry))
		if entry is RawCodeRow:
			out[out.size() - 1] = "raw:" + (entry as RawCodeRow).code.strip_edges()
	return out


static func _resource_claims_are_gated() -> bool:
	var ok: bool = true
	EventSheetBlockRegistry.rescan_pack_kinds()
	EventSheetBlockRegistry._kinds["audit.ungated"] = UngatedResourceKind.new()
	EventSheetBlockRegistry._kinds["audit.faithful"] = FaithfulResourceKind.new()
	var source: String = "extends Node\n\n## KEEP ME\n"
	var reemitted: String = SUPPORT.reemit(source, "user://api_file_safety.gd")
	ok = SUPPORT.check(P, "a resource claim that cannot reproduce its line leaves the file byte-identical",
		reemitted, source) and ok
	ok = SUPPORT.check(P, "the refused claim leaves the round trip holding", EventSheets.round_trips(source), true) and ok
	var faithful_source: String = "extends Node\n\n## FAITHFUL\n"
	ok = SUPPORT.check(P, "a resource claim that reproduces its line still lifts",
		SUPPORT.reemit(faithful_source, "user://api_file_safety.gd"), faithful_source) and ok
	_forget(["audit.ungated", "audit.faithful"])
	return ok


## A kind that names a built-in id, as an editor plugin's `_enter_tree` might before anything has asked
## the registry for anything.
class ImpostorKind extends EventSheetBlockKind:
	var wording: String = ""

	func _init(id: String = "preload") -> void:
		kind_id = id
		title = "Impostor"

	func emit(_block: CustomBlockRow) -> PackedStringArray:
		return PackedStringArray(["# hijacked"])


static func _built_in_ids_cannot_be_taken() -> bool:
	var ok: bool = true
	var built_ins: Array = ["preload", "region", "enum", "signal", "moment"]
	# A cold registry: nothing has asked it for anything yet, which is when an editor plugin registers.
	EventSheetBlockRegistry._built_ins_registered = false
	EventSheetBlockRegistry._kinds.clear()
	EventSheets.register_block_kind(ImpostorKind.new("preload"))
	ok = SUPPORT.check(P, "a kind registered first cannot replace the built-in preload kind",
		EventSheetBlockRegistry.get_kind("preload") is EventSheetBlockRegistry.PreloadBlockKind, true) and ok
	var block: CustomBlockRow = EventSheets.preload_block_for("res://icon.svg")
	var emitted: PackedStringArray = EventSheetBlockRegistry.get_kind("preload").emit(block)
	ok = SUPPORT.check(P, "the user's preload row still emits a preload line", emitted[0].begins_with("const "), true) and ok
	for built_in: String in built_ins:
		EventSheetBlockRegistry._built_ins_registered = false
		EventSheetBlockRegistry._kinds.clear()
		EventSheetBlockRegistry.register_kind(ImpostorKind.new(built_in))
		var holder: EventSheetBlockKind = EventSheetBlockRegistry.get_kind(built_in)
		ok = SUPPORT.check(P, "the %s id stays the built-in kind" % built_in, holder != null and not (holder is ImpostorKind), true) and ok
	var reason: String = _rules().refusal("region", EventSheetBlockRegistry._kinds, EventSheetBlockRegistry._built_in_ids)
	ok = SUPPORT.check(P, "the refusal names the id", reason.contains("'region'"), true) and ok
	ok = SUPPORT.check(P, "the refusal says it is built in", reason.contains("built-in"), true) and ok
	ok = SUPPORT.check(P, "an ordinary id is not refused", _rules().refusal("my_pack.note", EventSheetBlockRegistry._kinds, EventSheetBlockRegistry._built_in_ids), "") and ok
	# Registering a pack-style kind first still works and leaves every built-in alone.
	EventSheetBlockRegistry._built_ins_registered = false
	EventSheetBlockRegistry._kinds.clear()
	EventSheetBlockRegistry.register_kind(ImpostorKind.new("my_pack.note"))
	var all_there: bool = EventSheetBlockRegistry.get_kind("my_pack.note") != null
	for built_in: String in built_ins:
		all_there = all_there and EventSheetBlockRegistry.get_kind(built_in) != null
	ok = SUPPORT.check(P, "a first registration of an ordinary id leaves the built-ins in place", all_there, true) and ok
	# Put the registry back the way the rest of the suite expects it.
	EventSheetBlockRegistry._kinds.erase("my_pack.note")
	return ok


## The refusal rule, loaded by path the way the registry loads it.
static func _rules() -> GDScript:
	return load("res://addons/eventforge/registration/block_kind_rules.gd")


## A kind whose emit() hits a script error, as a pack with a bug does: the call returns nothing.
class ThrowingEmitKind extends EventSheetBlockKind:
	func _init() -> void:
		kind_id = "audit.throw_emit"
		title = "ThrowEmit"

	func emit(_block: CustomBlockRow) -> PackedStringArray:
		var nothing: Object = null
		return PackedStringArray([str(nothing.get_name())])


static func _block_sheet(kind_id: String, fields: Dictionary) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheets.new_sheet()
	var row: CustomBlockRow = CustomBlockRow.new()
	row.kind_id = kind_id
	row.fields = fields
	sheet.events.append(row)
	return sheet


static func _a_block_that_cannot_be_written_is_reported() -> bool:
	var ok: bool = true
	# A .tres sheet whose pack was removed: the row keeps its kind id and fields, nothing registers the kind.
	var gone: Dictionary = EventSheetCompiler.echo(_block_sheet("gone.pack", {"text": "fix the jump arc"}), true)
	ok = SUPPORT.check(P, "a block whose pack is gone makes the compile fail", gone.get("success"), false) and ok
	var gone_words: String = " ".join(PackedStringArray(gone.get("errors", [])))
	ok = SUPPORT.check(P, "the error names the kind", gone_words.contains("'gone.pack'"), true) and ok
	ok = SUPPORT.check(P, "the error names what the row holds", gone_words.contains("fix the jump arc"), true) and ok
	ok = SUPPORT.check(P, "the same words ride in the warnings", " ".join(PackedStringArray(gone.get("warnings", []))).contains("'gone.pack'"), true) and ok
	# A failed compile leaves the file on disk as it was, rather than writing a script that lacks the row.
	var path: String = "user://api_file_safety_gone.gd"
	var held: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	held.store_string("# the last good script
")
	held.close()
	var written: Dictionary = EventSheetCompiler.compile(_block_sheet("gone.pack", {"text": "x"}), path)
	ok = SUPPORT.check(P, "compile reports the failure when it was to write a file", written.get("success"), false) and ok
	ok = SUPPORT.check(P, "the file the compile would have overwritten is untouched",
		FileAccess.get_file_as_string(path), "# the last good script
") and ok
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	# A kind that is there but whose emit() errors.
	EventSheetBlockRegistry._kinds["audit.throw_emit"] = ThrowingEmitKind.new()
	var thrown: Dictionary = EventSheetCompiler.echo(_block_sheet("audit.throw_emit", {"text": "x"}), true)
	ok = SUPPORT.check(P, "a block whose emit() errors makes the compile fail", thrown.get("success"), false) and ok
	ok = SUPPORT.check(P, "the failure names the kind",
		" ".join(PackedStringArray(thrown.get("warnings", []))).contains("'audit.throw_emit'"), true) and ok
	EventSheetBlockRegistry._kinds.erase("audit.throw_emit")
	# The ordinary cases do not change: a registered kind compiles, and a row with no fields may write nothing.
	var fine: Dictionary = EventSheetCompiler.echo(_block_sheet("preload", {"name": "Icon", "path": "res://icon.svg"}), true)
	ok = SUPPORT.check(P, "a registered kind still compiles", fine.get("success"), true) and ok
	return ok


static func _a_block_without_its_pack_still_draws() -> bool:
	var ok: bool = true
	var viewport: EventSheetViewport = EventSheetViewport.new()
	var builder: EventSheetViewportRowBuilder = viewport._row_builder
	var orphan: CustomBlockRow = CustomBlockRow.new()
	orphan.kind_id = "gone.pack"
	orphan.fields = {"text": "ship it"}
	var row: EventRowData = builder._build_custom_block_row(orphan, 0)
	ok = SUPPORT.check(P, "a block whose pack is gone still builds a row", row != null, true) and ok
	if row != null:
		var muted: Color = viewport._get_reading_style().muted_text_color
		ok = SUPPORT.check(P, "the row has a badge and a summary", row.spans.size(), 2) and ok
		if row.spans.size() == 2:
			ok = SUPPORT.check(P, "the summary names the kind that is missing", str(row.spans[1].text), "gone.pack") and ok
			ok = SUPPORT.check(P, "the badge is the quiet chip", row.spans[0].metadata.get("badge_style"), "scope") and ok
			ok = SUPPORT.check(P, "the summary wears the muted ink", row.spans[1].metadata.get("text_color") == muted, true) and ok
	viewport.free()
	return ok


static func _compile_says_what_it_writes() -> bool:
	var ok: bool = true
	var stray: String = "res://event_sheet_generated.gd"
	if FileAccess.file_exists(stray):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(stray))
	# A sheet with no file: compile() writes nothing, hands the text back and says so.
	var fresh: EventSheetResource = EventSheets.open_gd_as_sheet("extends Node

var hp: int = 3
")
	var fresh_result: Dictionary = EventSheets.compile(fresh)
	ok = SUPPORT.check(P, "compile with no path on a sheet with no file writes no stray file", FileAccess.file_exists(stray), false) and ok
	ok = SUPPORT.check(P, "that compile still hands the text back", str(fresh_result.get("output", "")).contains("var hp: int = 3"), true) and ok
	ok = SUPPORT.check(P, "that compile succeeds", fresh_result.get("success"), true) and ok
	ok = SUPPORT.check(P, "that compile says it wrote nothing",
		" ".join(PackedStringArray(fresh_result.get("warnings", []))).contains("wrote nothing"), true) and ok
	ok = SUPPORT.check(P, "the result keeps its keys",
		fresh_result.keys().has("output") and fresh_result.keys().has("source_map") and fresh_result.keys().has("errors"), true) and ok
	# echo(): the same text, no file, no warning.
	var echoed: Dictionary = EventSheets.echo(fresh)
	ok = SUPPORT.check(P, "echo returns the compiled text", echoed.get("output"), fresh_result.get("output")) and ok
	ok = SUPPORT.check(P, "echo writes no stray file", FileAccess.file_exists(stray), false) and ok
	ok = SUPPORT.check(P, "echo carries no unwritten warning", " ".join(PackedStringArray(echoed.get("warnings", []))).contains("wrote nothing"), false) and ok
	ok = SUPPORT.check(P, "echo of nothing is a failure, not a crash", EventSheets.echo(null).get("success"), false) and ok
	# A sheet that has a file: compile() takes the Save's backup before it overwrites.
	var own: String = "user://api_file_safety_own.gd"
	var original: String = "extends Node

# hand written, keep
var hp: int = 3
"
	var handle: FileAccess = FileAccess.open(own, FileAccess.WRITE)
	handle.store_string(original)
	handle.close()
	_clear_backups(own)
	var backed: EventSheetResource = EventSheets.open_gd_as_sheet(original)
	backed.external_source_path = own
	var extra: LocalVariable = LocalVariable.new()
	extra.name = "speed"
	extra.type_name = "int"
	extra.default_value = "5"
	backed.events.append(extra)
	var written: Dictionary = EventSheets.compile(backed)
	ok = SUPPORT.check(P, "compile with no path on a sheet with a file writes that file", written.get("success"), true) and ok
	ok = SUPPORT.check(P, "the file now holds the new variable", FileAccess.get_file_as_string(own).contains("speed"), true) and ok
	var ring: PackedStringArray = EventSheetBackups.list_backups(own)
	ok = SUPPORT.check(P, "a backup was taken first", ring.size(), 1) and ok
	if ring.size() == 1:
		ok = SUPPORT.check(P, "the backup holds the bytes the compile overwrote", FileAccess.get_file_as_string(ring[0]), original) and ok
	# An explicit path keeps writing exactly that file and takes no backup of anything else.
	var explicit: String = "user://api_file_safety_explicit.gd"
	var explicit_result: Dictionary = EventSheets.compile(fresh, explicit)
	ok = SUPPORT.check(P, "compile with a path still writes that path", FileAccess.get_file_as_string(explicit), str(explicit_result.get("output", "")) + "") and ok
	_clear_backups(own)
	for leftover: String in [own, explicit]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(leftover))
	if FileAccess.file_exists(stray):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(stray))
	return ok


static func _clear_backups(path: String) -> void:
	for backup: String in EventSheetBackups.list_backups(path):
		DirAccess.remove_absolute(backup)


static func _edit_is_atomic() -> bool:
	var ok: bool = true
	var undo: EventSheetEditorTest.FakeEditorUndoRedoManager = EventSheetEditorTest.FakeEditorUndoRedoManager.new()
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(undo)
	var start: EventSheetResource = EventSheets.new_sheet()
	start.events.append(CommentRow.new())
	start.events.append(CommentRow.new())
	dock.setup(start)
	var steps_before: int = undo._undo_stack.size()
	# A mutation that appends, then hits a script error.
	var half: bool = EventSheets.edit("Half an edit", func(sheet: EventSheetResource) -> bool:
		sheet.events.append(CommentRow.new())
		var nothing: Object = null
		nothing.call("boom")
		return true)
	ok = SUPPORT.check(P, "a mutation that errors makes edit() return false", half, false) and ok
	ok = SUPPORT.check(P, "the sheet is exactly as it was", EventSheets.current_sheet().events.size(), 2) and ok
	ok = SUPPORT.check(P, "no undo step was added", undo._undo_stack.size(), steps_before) and ok
	# The same, from a mutation with no declared return (which edit() reads as "changed").
	var untyped: bool = EventSheets.edit("Untyped half", func(sheet: EventSheetResource) -> void:
		sheet.events.append(CommentRow.new())
		var nothing: Object = null
		nothing.call("boom"))
	ok = SUPPORT.check(P, "an erroring mutation with no return is refused too", untyped, false) and ok
	ok = SUPPORT.check(P, "that sheet is exactly as it was", EventSheets.current_sheet().events.size(), 2) and ok
	ok = SUPPORT.check(P, "that added no undo step", undo._undo_stack.size(), steps_before) and ok
	# A clean edit still lands as one step.
	var clean: bool = EventSheets.edit("Add one", func(sheet: EventSheetResource) -> bool:
		sheet.events.append(CommentRow.new())
		return true)
	ok = SUPPORT.check(P, "a clean mutation lands", clean, true) and ok
	ok = SUPPORT.check(P, "a clean mutation is one undo step", undo._undo_stack.size(), steps_before + 1) and ok
	ok = SUPPORT.check(P, "a clean mutation reached the sheet", EventSheets.current_sheet().events.size(), 3) and ok
	# A mutation that says "nothing changed" adds nothing.
	var nothing_changed: bool = EventSheets.edit("Nothing", func(_sheet: EventSheetResource) -> bool: return false)
	ok = SUPPORT.check(P, "a mutation returning false adds no step", nothing_changed, false) and ok
	ok = SUPPORT.check(P, "and no step is recorded for it", undo._undo_stack.size(), steps_before + 1) and ok
	# A nested edit is refused with a plain message and applies nothing of its own.
	var inner_result: Array = []
	var outer: bool = EventSheets.edit("Outer", func(_sheet: EventSheetResource) -> bool:
		inner_result.append(EventSheets.edit("Inner", func(inner_sheet: EventSheetResource) -> bool:
			inner_sheet.events.append(CommentRow.new())
			return true))
		EventSheets.current_sheet().events.append(CommentRow.new())
		return true)
	ok = SUPPORT.check(P, "a nested edit is refused", inner_result, [false]) and ok
	ok = SUPPORT.check(P, "the outer edit still lands", outer, true) and ok
	ok = SUPPORT.check(P, "only the outer write is in the sheet", EventSheets.current_sheet().events.size(), 4) and ok
	ok = SUPPORT.check(P, "the outer edit is one undo step", undo._undo_stack.size(), steps_before + 2) and ok
	var after_nested: bool = EventSheets.edit("After", func(sheet: EventSheetResource) -> bool:
		sheet.events.append(CommentRow.new())
		return true)
	ok = SUPPORT.check(P, "an edit after a refused nested one works", after_nested, true) and ok
	dock.free()
	return ok
