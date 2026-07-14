# EventForge - Phase 2 slice 2b: per-function "Make Body Editable" opt-in on an OPENED behaviour pack.
# An opened .gd's verb bodies are read-only by default (2a covenant: editing one could change its bytes),
# so a user opts a SINGLE verb into editing. The opt-in is pure editor state (name-keyed on the viewport,
# never the .gd), so flipping it alone changes no bytes; only a subsequent edit re-emits that ONE verb, and
# every un-opted sibling stays inert and byte-identical - the sibling guarantee this test pins.
@tool
class_name FunctionBodyOptInTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# An OPENED pack (external_source_path set) with two lifted verbs, each a one-line body.
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	# user:// (not res://) so compiling with this path never writes a stray file into the repo.
	sheet.external_source_path = "user://_opt_in_pack_test.gd"
	sheet.functions.append(_lifted_verb("alpha", "return 1"))
	sheet.functions.append(_lifted_verb("beta", "return 2"))

	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	var view: EventSheetViewport = dock._active_view()
	var path: String = sheet.external_source_path
	var output_baseline: String = str(SheetCompiler.compile(dock.get_current_sheet(), path).get("output", ""))

	# ── Default: BOTH verb bodies are inert (read-only) on an opened pack ──
	ok = _check("alpha body is inert by default (opened pack)", _body_live(view, "alpha"), false) and ok
	ok = _check("beta body is inert by default (opened pack)", _body_live(view, "beta"), false) and ok
	ok = _check("no verb is opted in yet", view.is_function_body_editable_opt_in("alpha"), false) and ok

	# ── Opt ALPHA in: only alpha's body goes live; beta stays inert (the per-function gate) ──
	view.toggle_function_body_editable("alpha")
	ok = _check("alpha is now opted in", view.is_function_body_editable_opt_in("alpha"), true) and ok
	ok = _check("alpha body is now LIVE (editable)", _body_live(view, "alpha"), true) and ok
	ok = _check("beta body stays inert (sibling not opted in)", _body_live(view, "beta"), false) and ok

	# ── Opt-in is editor state only: flipping it changed NO bytes (the sheet re-emits identically) ──
	var output_opted: String = str(SheetCompiler.compile(dock.get_current_sheet(), path).get("output", ""))
	ok = _check("opting a verb in does NOT change the emitted bytes", output_opted == output_baseline, true) and ok

	# ── Edit alpha's now-live body (delete its row through the undo funnel) - the per-function byte-break ──
	var alpha_body: Resource = _first_body_resource(view, "alpha")
	ok = _check("alpha's live body row is reachable", alpha_body != null, true) and ok
	var edited: bool = dock._perform_undoable_sheet_edit("Edit Alpha Body", func() -> bool:
		var loc: Dictionary = dock._find_resource_location(alpha_body)
		if loc.is_empty():
			return false
		(loc.get("container") as Array).remove_at(int(loc.get("index")))
		return true
	)
	ok = _check("the funnel edited alpha's opted-in body", edited, true) and ok
	var output_after: String = str(SheetCompiler.compile(dock.get_current_sheet(), path).get("output", ""))
	ok = _check("alpha's body changed (its line is gone)", output_after.contains("return 1"), false) and ok

	# ── THE SIBLING GUARANTEE (full-file, not a substring): editing alpha changes ONLY alpha's body line -
	# beta and EVERY class-level line are byte-identical. Deleting alpha's one body row leaves an empty int
	# function stubbed `return 0`, so the whole file equals the baseline with alpha's `return 1` -> `return 0`
	# ("return 1" is unique to alpha here). A regression that reordered/dropped a sibling's line would fail this.
	ok = _check("editing alpha changes ONLY its own body; the entire rest of the file is byte-identical",
		output_after == output_baseline.replace("\treturn 1", "\treturn 0"), true) and ok
	ok = _check("beta's function block survives verbatim (sibling guarantee)",
		output_after.contains("func beta() -> int:\n\treturn 2"), true) and ok
	dock.free()

	# ── A published-verb HEADER row deletes nothing (its resource is the EventFunction, not in sheet.events
	# or a body), so a delete/cut targeting only it must NEVER unlock a read-only preview or false-dirty -
	# 2b's new Define-row context menu puts users on that row, so this stays byte-safe. ──
	var preview: EventSheetResource = EventSheetResource.new()
	preview.host_class = "Node2D"
	preview.external_source_path = "user://_preview_pack_test.gd"
	preview.read_only = true
	preview.functions.append(_lifted_verb("gamma", "return 3"))
	var pdock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	pdock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	pdock.setup(preview)
	var pview: EventSheetViewport = pdock._active_view()
	var header_index: int = -1
	var pflat: Array = pview.get_flat_rows()
	for i in range(pflat.size()):
		var rd: EventRowData = pflat[i].get("row")
		if rd != null and rd.row_uid == "define_fn_gamma":
			header_index = i
	ok = _check("the gamma Define header row is present", header_index >= 0, true) and ok
	if header_index >= 0:
		pview._select_row(header_index)
	pdock._delete_selected_rows()
	ok = _check("deleting a Define header leaves the verb intact (nothing removed)",
		_find_function_named(pdock, "gamma") != null, true) and ok
	ok = _check("deleting a Define header does NOT unlock a read-only preview",
		pdock.get_current_sheet().read_only, true) and ok
	pdock.free()

	return ok


static func _find_function_named(dock: EventSheetDock, fn_name: String) -> EventFunction:
	for entry: Variant in dock.get_current_sheet().functions:
		if entry is EventFunction and (entry as EventFunction).function_name == fn_name:
			return entry as EventFunction
	return null


## A reverse-lifted verb (no @ace annotations) with a one-line raw body, as the importer produces one.
static func _lifted_verb(fn_name: String, body_code: String) -> EventFunction:
	var event_function: EventFunction = EventFunction.new()
	event_function.function_name = fn_name
	event_function.return_type = TYPE_INT
	event_function.expose_as_ace = false
	event_function.lifted_unannotated = true
	var block: RawCodeRow = RawCodeRow.new()
	block.code = body_code
	event_function.events.append(block)
	return event_function


## True when the named verb's first body row is LIVE (source_resource kept - editable), false when inert.
static func _body_live(view: EventSheetViewport, fn_name: String) -> bool:
	var header: EventRowData = _define_row(view, fn_name)
	if header == null or header.children.is_empty():
		return false
	return header.children[0].source_resource != null


## The first body row's source_resource for a live (opted-in) verb, or null.
static func _first_body_resource(view: EventSheetViewport, fn_name: String) -> Resource:
	var header: EventRowData = _define_row(view, fn_name)
	if header == null or header.children.is_empty():
		return null
	return header.children[0].source_resource


static func _define_row(view: EventSheetViewport, fn_name: String) -> EventRowData:
	for entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.row_uid == "define_fn_%s" % fn_name:
			return row_data
	return null


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] function_body_opt_in_test: %s" % label)
		return true
	print("[FAIL] function_body_opt_in_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
