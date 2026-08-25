# EventForge - A whole tween chain written on ONE line reads as the step it takes, not as the
# chain call it happens to start with. `create_tween().set_loops(3).tween_property(self, "position",
# p, 0.5)` is `Tween position to p in 0.5 seconds  repeat 3 times` - the property step is the row,
# and `set_loops` is a muted note on it, exactly as the easing tail is a chip on it.
#
# The chain calls written on their OWN line are unchanged: `t.set_loops(3)` there is still a row of
# its own, because that is what a reader wrote. And every shape still round-trips byte-identically.
@tool
class_name TweenOneLineChainTest
extends RefCounted

const HEAD := "extends Node2D\n\n\nfunc _ready() -> void:\n"
const ONE_LINE_LOOPS := HEAD + "\tcreate_tween().set_loops(3).tween_property(self, \"position\", p, 0.5)\n"
const ONE_LINE_FOREVER := HEAD + "\tcreate_tween().set_loops().tween_property(self, \"modulate:a\", 0.0, 0.3)\n"
const ONE_LINE_PARALLEL := HEAD + "\tcreate_tween().set_parallel().tween_property(self, \"scale\", s, 0.2)\n"
const ONE_LINE_EASED := HEAD + "\tcreate_tween().set_loops(2).tween_property(self, \"position\", p, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)\n"
const NAMED_CHAIN := HEAD + "\tvar t = create_tween()\n\tt.set_loops(3)\n\tt.tween_property(self, \"position\", p, 0.5)\n\tt.tween_property(self, \"modulate:a\", 0.0, 0.3)\n\tt.kill()\n"


static func run() -> bool:
	var ok: bool = true
	ok = _check("a one-line chain reads its property step, with the repeat as a note",
		_actions(ONE_LINE_LOOPS), "Tween position to p in 0.5 seconds repeat 3 times") and ok
	ok = _check("set_loops with no count is forever",
		_actions(ONE_LINE_FOREVER), "Tween opacity to 0 in 0.3 seconds repeat forever") and ok
	ok = _check("set_parallel on the same line rides along as its own note",
		_actions(ONE_LINE_PARALLEL), "Tween size to s in 0.2 seconds (at the same time)") and ok
	ok = _check("the easing tail after the step is still the chip it was",
		_actions(ONE_LINE_EASED),
		"Tween position to p in 0.5 seconds ease = Sine out repeat 2 times") and ok
	# A chain that names its tween is untouched: those calls ARE rows, one per line, as before.
	ok = _check("a named chain still reads one row per line",
		_actions(NAMED_CHAIN),
		"Tween repeat 3 times | Tween position to p in 0.5 seconds | " \
		+ "Tween opacity to 0 in 0.3 seconds (after the previous) | Stop tween | " \
		+ "Local object | t | = a new tween") and ok
	for entry: Array in [
		["the one-line chain", ONE_LINE_LOOPS], ["the forever chain", ONE_LINE_FOREVER],
		["the parallel chain", ONE_LINE_PARALLEL], ["the eased one-line chain", ONE_LINE_EASED],
		["the named chain", NAMED_CHAIN]
	]:
		ok = _check("%s round-trips byte-identically" % str(entry[0]),
			_roundtrip(str(entry[1])), str(entry[1])) and ok
	return ok


## Every action-lane row of the sheet, joined with " | " - the "+ Add action" affordance dropped,
## since it is the canvas talking rather than the file.
static func _actions(source: String) -> String:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external_source(source)
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	var rows: PackedStringArray = PackedStringArray()
	for entry: Dictionary in dock._active_view().get_flat_rows():
		var row: EventRowData = entry.get("row")
		if row == null:
			continue
		var parts: PackedStringArray = PackedStringArray()
		for span: SemanticSpan in row.spans:
			if not (span.metadata is Dictionary):
				continue
			if str((span.metadata as Dictionary).get("lane", "")) != "action":
				continue
			if str((span.metadata as Dictionary).get("kind", "")) == "add_action":
				continue
			parts.append(str(span.text))
		if not parts.is_empty():
			rows.append(" | ".join(parts))
	dock.free()
	return " | ".join(rows)


static func _roundtrip(source: String) -> String:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external_source(source)
	sheet.external_source_path = "user://eventforge_tween_one_line_chain.gd"
	return str(SheetCompiler.compile(sheet, "user://eventforge_tween_one_line_chain.gd").get("output", ""))


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] tween_one_line_chain_test: %s" % label)
		return true
	print("[FAIL] tween_one_line_chain_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
