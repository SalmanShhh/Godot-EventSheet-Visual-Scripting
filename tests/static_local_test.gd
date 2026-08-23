# Godot EventSheets - V4 "Static local": a local by scope, a member in code.
#
# The row sits under its event and reads "Static local whole number hits_taken = 0", but GDScript has
# no function-scope `static`, so the value can only survive between runs of that event as a class
# member. This pins the whole path: the hoisted declaration and its marker, the rewrite of the
# event's uses onto the member (and the string literal it must leave alone), the byte-exact round
# trip when the emitted file is opened again, the drag that re-scopes a local to another event, and
# the Add variable dialog offering the tick for the one scope it means anything in.
@tool
class_name StaticLocalTest
extends RefCounted


static func run() -> bool:
	var passed: bool = true
	passed = _test_emission() and passed
	passed = _test_roundtrip_is_byte_exact() and passed
	passed = _test_duplicate_names_warn_once() and passed
	passed = _test_a_function_bodys_static_local_is_declared() and passed
	passed = _test_a_null_default_spells_its_type() and passed
	passed = _test_row_reads_and_echoes_the_member() and passed
	passed = _test_dialog_offers_the_tick_for_locals_only() and passed
	passed = _test_drag_rescopes_the_local() and passed
	passed = _test_drag_to_the_head_promotes_the_local() and passed
	return passed


## The declaration hoists to the class beside the group locals, wearing the marker that says which
## row it belongs to, and every use inside the event becomes a use of the member - except the one
## inside a printed sentence, which is displayed text and not a reference at all.
static func _test_emission() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = _sheet_with_static_local()
	var output: String = _compiled(sheet)
	ok = _check("the marker names the row the member belongs to",
		output.contains("# @static_local:hits_taken"), true) and ok
	ok = _check("the declaration hoists to the class as a private member",
		output.contains("\nvar _hits_taken := 0\n"), true) and ok
	ok = _check("the event's use reads the member", output.contains("\t_hits_taken += 1"), true) and ok
	ok = _check("a printed sentence is left as it was written",
		output.contains("print(\"hits_taken is \", _hits_taken)"), true) and ok
	ok = _check("nothing is declared inside the event body", output.contains("\tvar hits_taken"), false) and ok
	ok = _check("a plain local is still not hoisted", output.contains("_dealt"), false) and ok
	return ok


## Opening the emitted file gives the row back - name, flag and all - and saving it untouched
## reproduces the source byte for byte, which is the whole contract a lift lives under.
static func _test_roundtrip_is_byte_exact() -> bool:
	var ok: bool = true
	var source: String = _compiled(_sheet_with_static_local())
	var opened: EventSheetResource = GDScriptImporter.new().import_external_source(source)
	opened.external_source_path = "user://eventforge_static_local_open.gd"
	var lifted: LocalVariable = null
	for row: Variant in opened.events:
		if row is LocalVariable and (row as LocalVariable).static_local:
			lifted = row as LocalVariable
	ok = _check("the member opens as a Static local row again", lifted != null, true) and ok
	if lifted != null:
		ok = _check("…under the row's own name, not the member's", lifted.name, "hits_taken") and ok
	ok = _check("re-saving the opened file reproduces it byte for byte",
		str(SheetCompiler.compile(opened, "user://eventforge_static_local_save.gd").get("output", "")), source) and ok
	return ok


## Two events cannot each own a `hits_taken`: both hoist to `var _hits_taken`, so the second shares
## the first one's member and the reader is told so rather than left with a file that will not parse.
static func _test_duplicate_names_warn_once() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = _sheet_with_static_local()
	var second: EventRow = EventRow.new()
	second.event_uid = "ev2"
	second.local_variables.append(_static_local("hits_taken", "int", 0))
	sheet.events.append(second)
	var result: Dictionary = SheetCompiler.compile(sheet, "user://eventforge_static_local_dup.gd")
	var output: String = str(result.get("output", ""))
	ok = _check("the member is declared exactly once", output.count("var _hits_taken := 0"), 1) and ok
	var warnings: Array = result.get("warnings", [])
	ok = _check("and the clash is one warning", warnings.size(), 1) and ok
	if warnings.size() == 1:
		ok = _check("…naming the variable and the member it shares", str(warnings[0]),
			"Static local 'hits_taken' is declared on more than one event - they share the one _hits_taken member.") and ok
	return ok


## A function body is ordinary selectable rows, so a Static local can be written on one. The member
## it hoists to has to be declared for that: the rewrite of the body's uses runs either way, so a
## sheet whose members were gathered from its events alone emitted a file naming `_hits_taken` with
## nothing anywhere declaring it - a compile that reports success and a script that will not load.
static func _test_a_function_bodys_static_local_is_declared() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = "Player"
	sheet.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.event_uid = "fn_ev1"
	event.local_variables.append(_static_local("hits_taken", "int", 0))
	event.actions.append(_raw_action("hits_taken += 1"))
	var take_hit: EventFunction = EventFunction.new()
	take_hit.function_name = "take_hit"
	take_hit.events.append(event)
	sheet.functions.append(take_hit)
	var output: String = _compiled(sheet)
	ok = _check("the marker names the row the member belongs to",
		output.contains("# @static_local:hits_taken"), true) and ok
	ok = _check("the member the function body uses is declared",
		output.contains("\nvar _hits_taken := 0\n"), true) and ok
	ok = _check("…exactly once", output.count("var _hits_taken := 0"), 1) and ok
	ok = _check("and the body inside the function reads that member",
		output.contains("\t_hits_taken += 1"), true) and ok
	return ok


## A Static local whose value is nothing: `:=` has nothing to infer from `null`, and Godot refuses
## such a script outright ("Cannot infer the type of 'variable'"). The types whose empty default
## parses to null - Texture2D, Curve, Gradient - are all offered beside the tick, so the declaration
## spells the type out for them instead.
static func _test_a_null_default_spells_its_type() -> bool:
	var ok: bool = true
	ok = _check("a null default declares its type rather than inferring it",
		SheetCompiler.static_local_declaration(_static_local("ramp", "Curve", null)),
		"var _ramp: Curve = null") and ok
	ok = _check("…and one with no type to name falls back to Variant",
		SheetCompiler.static_local_declaration(_static_local("thing", "", null)),
		"var _thing: Variant = null") and ok
	ok = _check("a value that can be inferred is still written the short way",
		SheetCompiler.static_local_declaration(_static_local("hits", "int", 0)), "var _hits := 0") and ok
	return ok


## The sentence and the V13 echo: the row says Static local where a plain local says Local, and the
## code beside it is the member line the compiler writes, never the marker above it.
static func _test_row_reads_and_echoes_the_member() -> bool:
	var ok: bool = true
	var static_local: LocalVariable = _static_local("hits_taken", "int", 0)
	ok = _check("the scope word says both facts at once",
		EventSheetVariableSentence.scope_word(EventSheetVariableSentence.local_scope(true)), "Static local") and ok
	ok = _check("a plain local still says Local",
		EventSheetVariableSentence.scope_word(EventSheetVariableSentence.local_scope(false)), "Local") and ok
	ok = _check("the row reads as one sentence",
		"%s %s = %s" % [
			EventSheetVariableSentence.chip_text(EventSheetVariableSentence.SCOPE_STATIC_LOCAL, "whole number"),
			static_local.name, "0"],
		"Static local whole number hits_taken = 0") and ok
	ok = _check("the echo is the member the declaration became",
		EventSheetCodeEcho.line_for(static_local), "var _hits_taken := 0") and ok
	ok = _check("a float default keeps its fraction, or := would infer int",
		SheetCompiler.static_local_declaration(_static_local("cooldown", "float", 0.0)), "var _cooldown := 0.0") and ok
	return ok


## The tick belongs to the one scope it means anything in: a local cannot be a `static var`, and a
## member has the Static flag instead, so exactly one of the two is ever on screen.
static func _test_dialog_offers_the_tick_for_locals_only() -> bool:
	var ok: bool = true
	var captured: Dictionary = {}
	var dialog: VariableDialog = VariableDialog.new()
	var parent: Node = Node.new()
	dialog.init_dialog(parent)
	dialog.set_sheet_provider(func() -> Variant: return null)
	dialog.variable_confirmed.connect(func(_n: String, _t: String, _d: Variant, _s: String, context: Dictionary, _ic: bool, _ex: bool, _o: PackedStringArray, _a: Dictionary, _r: bool, _st: bool) -> void:
		captured["static_local"] = bool(context.get("static_local", false))
	)
	dialog.open_for_edit("tree", {}, "hp", "int", "0", false, "Add Variable")
	ok = _check("a member variable is not offered a static LOCAL", dialog._static_local_check.visible, false) and ok
	ok = _check("…it is offered Static", dialog._static_check.visible, true) and ok
	dialog.open_for_edit("local", {}, "hits_taken", "int", "0", false, "Add Variable")
	ok = _check("a local is offered the tick", dialog._static_local_check.visible, true) and ok
	ok = _check("…and not Static, which it cannot be", dialog._static_check.visible, false) and ok
	ok = _check("unticked, the row still reads Local", dialog.current_scope_word(),
		EventSheetVariableSentence.SCOPE_LOCAL) and ok
	dialog._static_local_check.button_pressed = true
	ok = _check("ticked, the row reads Static local", dialog.current_scope_word(),
		EventSheetVariableSentence.SCOPE_STATIC_LOCAL) and ok
	ok = _check("the preview says the sentence the row will read",
		dialog.row_preview_text(), "Static local whole number  hits_taken = 0") and ok
	ok = _check("and the strip's IN CODE line is the member it hoists to",
		dialog.code_line_text(), "var _hits_taken := 0") and ok
	dialog._on_confirmed()
	ok = _check("confirming carries the tick to the sheet", captured.get("static_local", false), true) and ok
	# Reopening the local brings the tick back, and moving to a member scope drops it.
	dialog.open_for_edit("local", {"static_local": true}, "hits_taken", "int", "0", false, "Edit Variable")
	ok = _check("reopening a Static local comes back ticked", dialog._static_local_check.button_pressed, true) and ok
	dialog._apply_scope_key(EventSheetVariableSentence.SCOPE_INSTANCE)
	ok = _check("moving it to a member scope clears the tick", dialog._static_local_check.button_pressed, false) and ok
	parent.free()
	return ok


## Dragging a Local row onto another event re-scopes it: the declaration moves, and the event it was
## dragged from is not the thing that moved.
static func _test_drag_rescopes_the_local() -> bool:
	var ok: bool = true
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	var sheet: EventSheetResource = _sheet_with_static_local()
	var second: EventRow = EventRow.new()
	second.event_uid = "ev2"
	sheet.events.append(second)
	dock.setup(sheet)
	var live: EventSheetResource = dock.get_current_sheet()
	var source_event: EventRow = live.events[0] as EventRow
	var target_event: EventRow = live.events[1] as EventRow
	dock._on_row_drop_requested(_local_row(source_event, 0), _event_row(target_event), "after", false)
	var moved: EventSheetResource = dock.get_current_sheet()
	ok = _check("the local left the event it was dragged from",
		(moved.events[0] as EventRow).local_variables.size(), 1) and ok
	ok = _check("…which is the plain local, not the static one",
		((moved.events[0] as EventRow).local_variables[0] as LocalVariable).name, "dealt") and ok
	ok = _check("and landed on the event it was dropped on",
		((moved.events[1] as EventRow).local_variables[0] as LocalVariable).name, "hits_taken") and ok
	ok = _check("both events are still where they were", moved.events.size(), 2) and ok
	ok = _check("the member follows the row to its new event",
		_compiled(moved).contains("# @static_local:hits_taken"), true) and ok
	dock.free()
	return ok


## Dragging a Local onto the sheet head promotes it: the Add variable dialog opens on the object's
## own scope with everything the local said already in it, and confirming writes the variable AND
## drops the declaration it came from - in one step, so the value is never declared twice.
static func _test_drag_to_the_head_promotes_the_local() -> bool:
	var ok: bool = true
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(_sheet_with_static_local())
	dock._variable_dlg.init_dialog(dock)
	dock._variable_dlg.set_sheet_provider(func() -> EventSheetResource: return dock._current_sheet)
	dock._variable_dlg.variable_confirmed.connect(dock._on_variable_dialog_confirmed)
	var source_event: EventRow = dock.get_current_sheet().events[0] as EventRow
	dock._on_row_drop_requested(_local_row(source_event, 0), _head_band_row(), "before", false)
	ok = _check("the head drop asks the object's own scope, not the local's",
		dock._variable_dlg.current_scope_word(), EventSheetVariableSentence.SCOPE_INSTANCE) and ok
	ok = _check("…with the local's own sentence to confirm",
		dock._variable_dlg.row_preview_text(), "Instance whole number  hits_taken = 0") and ok
	dock._variable_dlg._on_confirmed()
	var promoted: EventSheetResource = dock.get_current_sheet()
	ok = _check("confirming writes it as a variable of the object",
		promoted.variables.has("hits_taken"), true) and ok
	ok = _check("…and the declaration it came from is gone",
		(promoted.events[0] as EventRow).local_variables.size(), 1) and ok
	ok = _check("…leaving the event's other local alone",
		((promoted.events[0] as EventRow).local_variables[0] as LocalVariable).name, "dealt") and ok
	ok = _check("so nothing is hoisted for it any more",
		_compiled(promoted).contains("# @static_local:"), false) and ok
	dock.free()
	return ok


# ── helpers ───────────────────────────────────────────────────────────────────────────────────
static func _sheet_with_static_local() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = "Player"
	sheet.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.event_uid = "ev1"
	event.local_variables.append(_static_local("hits_taken", "int", 0))
	var plain: LocalVariable = _static_local("dealt", "int", 0)
	plain.static_local = false
	event.local_variables.append(plain)
	event.actions.append(_raw_action("hits_taken += 1"))
	event.actions.append(_raw_action("print(\"hits_taken is \", hits_taken)"))
	sheet.events.append(event)
	return sheet


static func _static_local(name: String, type_name: String, value: Variant) -> LocalVariable:
	var local: LocalVariable = LocalVariable.new()
	local.name = name
	local.type_name = type_name
	local.default_value = value
	local.static_local = true
	return local


static func _raw_action(template: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.codegen_template = template
	return action


## The row an event's Local draws as, in the shape the drop handler reads: the owning event as the
## row's resource, and the index of the local in the first span's metadata.
static func _local_row(event_row: EventRow, index: int) -> EventRowData:
	var row_data: EventRowData = EventRowData.new()
	row_data.source_resource = event_row
	row_data.variable_row = true
	row_data.row_uid = "variable_local_%s_%d" % [event_row.event_uid, index]
	var span: SemanticSpan = SemanticSpan.new()
	span.text = "x"
	span.metadata = {"kind": "variable", "variable_scope": "local", "variable_index": index}
	row_data.spans = [span]
	return row_data


## A row of the sheet head - the bands that stand for the file's class-setup lines. They carry no
## resource of their own, which is exactly why a drop on one has to be recognised by its uid.
static func _head_band_row() -> EventRowData:
	var row_data: EventRowData = EventRowData.new()
	row_data.row_uid = "%sname_1" % ViewportRowBuilder.HEAD_BAND_UID_PREFIX
	return row_data


static func _event_row(event_row: EventRow) -> EventRowData:
	var row_data: EventRowData = EventRowData.new()
	row_data.source_resource = event_row
	row_data.row_uid = "event_%s" % event_row.event_uid
	return row_data


static func _compiled(sheet: EventSheetResource) -> String:
	return str(SheetCompiler.compile(sheet, "user://eventforge_static_local_probe.gd").get("output", ""))


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] static_local_test: %s" % label)
		return true
	print("[FAIL] static_local_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
