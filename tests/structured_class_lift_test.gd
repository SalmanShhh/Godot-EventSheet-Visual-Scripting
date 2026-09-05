# EventForge - a class held by its MEMBERS reads as the structure it is. The field-only reading
# (data_class_name) and the method-bearing one (methods_class_name) both refuse a class the moment its
# body holds an enum, a signal, or another class nested inside it, so exactly the classes with the most
# structure in them read as a wall of GDScript. This third reading holds those: the class is a fold and
# each member reads as the row it would be at TOP LEVEL - a five-line enum collapsing to one row through
# the enum kind's own summary is the clearest case. Pins: the recognizer and its disjointness from the
# other two, the refusals that keep a class honest code, the byte-exact model round-trip, the rendered
# fold (including a class nested inside a class), and the covenant - a pure view, so the .gd still
# re-emits byte for byte.
@tool
class_name StructuredClassLiftTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")

## A class carrying all four member shapes at once: a multi-line enum, a signal, a field, a method.
const RADIO := "class Radio:\n\tenum Band {\n\t\tAM,\n\t\tFM = 4,\n\t}\n\tsignal tuned(to: float)\n\tvar band: int = 0\n\tfunc tune(to: float) -> void:\n\t\temit_signal(\"tuned\", to)"

## A class nested inside a class - the shape the deferred-work note called the largest remaining gap.
const NESTED := "class Outer:\n\tvar hp: int = 3\n\tclass Inner:\n\t\tvar x: int = 0"


## Where the two round-trip fixtures are written. user://, and deleted on the way out - a suite run
## leaves nothing behind it, in the repository or beside it.
const ROUND_TRIP_PATH: String = "user://structured_class_rt.gd"
const WHOLE_FILE_PATH: String = "user://structured_class_file.gd"


static func run() -> bool:
	var ok: bool = true

	# ── The recognizer, and its disjointness from the two readings that came before it ──
	ok = _check("a class carrying an enum is recognised", ViewportRowBuilder.structured_class_name(RADIO), "Radio") and ok
	ok = _check("the same class is NOT a pure-data class", ViewportRowBuilder.data_class_name(RADIO), "") and ok
	ok = _check("the same class is NOT a methods class", ViewportRowBuilder.methods_class_name(RADIO), "") and ok
	ok = _check("a class nested inside a class is recognised", ViewportRowBuilder.structured_class_name(NESTED), "Outer") and ok
	ok = _check("a class carrying a signal is recognised",
		ViewportRowBuilder.structured_class_name("class Radio:\n\tsignal pinged\n\tvar band: int = 1"), "Radio") and ok
	# Disjointness the other way: what the older readings own, this one refuses, so a class routes to
	# exactly one of the three and the pins those two shipped with keep holding.
	ok = _check("a field-only class stays with the data reading",
		ViewportRowBuilder.structured_class_name("class Foo:\n\tvar x: int = 0"), "") and ok
	ok = _check("a field+method class stays with the methods reading",
		ViewportRowBuilder.structured_class_name("class Weapon:\n\tvar ammo: int = 6\n\tfunc fire() -> void:\n\t\tammo -= 1"), "") and ok

	# ── The refusals: what this reading cannot hold stays honest code ──
	ok = _check("a bare statement in the body refuses",
		ViewportRowBuilder.structured_class_name("class Bad:\n\tsignal ok\n\tx = 5"), "") and ok
	ok = _check("top-level code after the class refuses",
		ViewportRowBuilder.structured_class_name("class Bad:\n\tsignal ok\nprint(1)"), "") and ok
	ok = _check("a second top-level class refuses",
		ViewportRowBuilder.structured_class_name("class A:\n\tsignal ok\nclass B:\n\tvar x: int = 0"), "") and ok
	ok = _check("a multi-line enum the enum reading refuses keeps the class as code",
		ViewportRowBuilder.structured_class_name("class Bad:\n\tenum E {\n    SPACES,\n\t}"), "") and ok
	ok = _check("an empty nested class refuses",
		ViewportRowBuilder.structured_class_name("class Outer:\n\tclass Inner:\n\t\tpass"), "") and ok

	# ── The byte-gate: every member keeps its source lines, so the model re-emits exactly ──
	var model: Dictionary = ViewportRowBuilder.parse_structured_class(RADIO)
	ok = _check("the model names the class", str(model.get("class_name")), "Radio") and ok
	ok = _check("emit reproduces the source byte-for-byte", ViewportRowBuilder.emit_structured_class(model), RADIO) and ok
	ok = _check("the gate says so", ViewportRowBuilder.structured_class_lifts(RADIO), true) and ok
	ok = _check("a nested class re-emits byte-for-byte too",
		ViewportRowBuilder.emit_structured_class(ViewportRowBuilder.parse_structured_class(NESTED)), NESTED) and ok
	var doc_led: String = "\n## What the radio is tuned to.\nclass Radio:\n\tsignal tuned\n\n\tvar band: int = 0"
	ok = _check("a doc-comment prelude and a blank line inside round-trip",
		ViewportRowBuilder.emit_structured_class(ViewportRowBuilder.parse_structured_class(doc_led)), doc_led) and ok
	ok = _check("a class three deep round-trips",
		ViewportRowBuilder.structured_class_lifts("class A:\n\tclass B:\n\t\tclass C:\n\t\t\tenum E { X, Y }"), true) and ok

	# ── The members, each read as the row it would be at top level ──
	var members: Array = model.get("members", [])
	ok = _check("every member is walked", members.size(), 4) and ok
	ok = _check("the enum reads through the enum kind's own summary",
		str((members[0] as Dictionary).get("reading")), "Band { AM, FM = 4 }") and ok
	ok = _check("the five-line enum is ONE member", (members[0] as Dictionary).get("lines").size(), 4) and ok
	ok = _check("the signal reads through the signal kind's own summary",
		str((members[1] as Dictionary).get("reading")), "tuned(to: float)") and ok
	ok = _check("what the class holds, counted by kind",
		ViewportRowBuilder._class_member_cue(members), "1 field · 1 method · 1 enum · 1 signal") and ok

	# ── Rendering over a synthetic opened sheet ──
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var raw: RawCodeRow = RawCodeRow.new()
	raw.code = RADIO
	sheet.events.append(raw)
	var nested_raw: RawCodeRow = RawCodeRow.new()
	nested_raw.code = NESTED
	sheet.events.append(nested_raw)
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	var view: EventSheetViewport = dock._active_view()
	var radio_row: EventRowData = null
	var outer_row: EventRowData = null
	for entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data == null or not str(row_data.row_uid).begins_with("structured_class_"):
			continue
		if str(row_data.row_uid) == "structured_class_Radio":
			radio_row = row_data
		elif str(row_data.row_uid) == "structured_class_Outer":
			outer_row = row_data
	ok = _check("the sheet shows the class as a block", radio_row != null, true) and ok
	if radio_row != null:
		ok = _check("it collapses to one header line", radio_row.line_count, 1) and ok
		ok = _check("the header names the class in the condition cell",
			str(radio_row.spans[0].text), "class Radio") and ok
		ok = _check("the header says what it holds", str(radio_row.spans[1].text),
			"1 field · 1 method · 1 enum · 1 signal") and ok
		ok = _check("each member is a child row", radio_row.children.size(), 4) and ok
		var enum_child: EventRowData = radio_row.children[0]
		ok = _check("the enum child reads as the declaration it is",
			str(enum_child.spans[0].text), "enum Band { AM, FM = 4 }") and ok
		ok = _check("the enum child counts its values in the action lane",
			str(enum_child.spans[1].text), "2 values") and ok
		ok = _check("the enum child is inert (no source resource to drag or delete)",
			enum_child.source_resource == null, true) and ok
		ok = _check("the block keeps its RawCodeRow (double-click opens the code)",
			radio_row.source_resource is RawCodeRow, true) and ok
	ok = _check("the nested class renders as its own fold", outer_row != null
		and outer_row.children.size() == 2
		and str((outer_row.children[1] as EventRowData).spans[0].text) == "class Inner"
		and (outer_row.children[1] as EventRowData).children.size() == 1, true) and ok

	# ── The covenant: a pure view - the raw code is untouched, so the file re-emits verbatim ──
	var reemitted: String = SUPPORT.compile_output(sheet, ROUND_TRIP_PATH)
	ok = _check("the sheet re-emits both classes verbatim",
		reemitted.contains(RADIO) and reemitted.contains(NESTED), true) and ok
	var whole_file: String = "class_name RadioHost\nextends Node\n\n" + RADIO + "\n\nvar volume: int = 5\n"
	ok = _check("a whole file holding such a class round-trips byte-exactly",
		SUPPORT.reemit(whole_file, WHOLE_FILE_PATH), whole_file) and ok

	dock.free()
	# SERIAL-CI HYGIENE: the two round-trip fixtures were written under user:// by the compiler, and
	# CI runs the suite serially in one process - so they go out with the test rather than being left
	# for whatever asks that path next.
	for written: String in [ROUND_TRIP_PATH, WHOLE_FILE_PATH]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(written))
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("structured_class_lift_test", label, actual, expected)
