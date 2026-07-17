# EventForge - "Inspector button" on a sheet function (the approved editor-tools spec, slice 3's
# editor_button - delivered on the FUNCTION seam, not a new block kind: the button IS a function,
# its behavior stays real event rows). Pins the whole thread: the function dialog carries the
# label in its data payload, the dock apply writes it onto the EventFunction (and a label-only
# edit is NOT a fingerprint no-op), the compiler emits @export_tool_button wired to the function,
# and the emitted script round-trips byte-exactly.
@tool
class_name InspectorButtonFunctionTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# ---- the dialog payload carries the label ----
	var dialog: EventSheetFunctionDialog = EventSheetFunctionDialog.new()
	dialog.init_dialog(Node.new())
	dialog._name_edit.text = "rebake"
	dialog._tool_button_edit.text = "Re-bake"
	var data: Dictionary = dialog.build_function_data()
	ok = _check(ok, str(data.get("tool_button_label", "")) == "Re-bake", "dialog payload carries the button label (got %s)" % str(data.get("tool_button_label")))

	# ---- a label-only edit is a real edit (fingerprint catches it) ----
	var fingerprint_without: String = EventSheetFunctionDialogGlue._function_fingerprint("rebake", TYPE_NIL, "", "", false, "", "", [], "", "")
	var fingerprint_with: String = EventSheetFunctionDialogGlue._function_fingerprint("rebake", TYPE_NIL, "", "", false, "", "", [], "", "Re-bake")
	ok = _check(ok, fingerprint_without != fingerprint_with, "a label-only change fingerprints as an edit")

	# ---- compile + round-trip covenant ----
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.tool_mode = true
	var button_function: EventFunction = EventFunction.new()
	button_function.function_name = "rebake"
	button_function.tool_button_label = "Re-bake"
	var body: RawCodeRow = RawCodeRow.new()
	body.code = "print(\"baked\")"
	button_function.events.append(body)
	sheet.functions.append(button_function)
	var compiled: Dictionary = SheetCompiler.compile(sheet, "user://btn_fn_test.gd")
	ok = _check(ok, bool(compiled.get("success", false)), "the button sheet compiles")
	var source: String = str(compiled.get("output", ""))
	ok = _check(ok, source.contains("@export_tool_button(\"Re-bake\") var _btn_rebake: Callable = rebake"), "output wires the Inspector button to the function")
	ok = _check(ok, EventSheets.round_trips(source), "the button script round-trips byte-exactly")
	if FileAccess.file_exists("user://btn_fn_test.gd"):
		DirAccess.remove_absolute("user://btn_fn_test.gd")

	return ok


static func _check(ok: bool, condition: bool, label: String) -> bool:
	if not condition:
		print("  [FAIL] ", label)
	return ok and condition
