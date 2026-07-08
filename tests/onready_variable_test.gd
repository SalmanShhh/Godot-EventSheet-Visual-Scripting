# Godot EventSheets - @onready tree-variable support (create in the dialog, lift on open, round-trip).
# Covers the model/compiler emission, the importer lift that keeps an `@onready var` an editable row
# (not a stranded verbatim block), and the raw-GDScript-block node-drop converter reuse.
@tool
class_name OnreadyVariableTest
extends RefCounted


static func run() -> bool:
	var passed: bool = true
	passed = _test_compiler_emits_onready() and passed
	passed = _test_importer_lifts_onready_roundtrip() and passed
	passed = _test_plain_var_still_lifts_not_onready() and passed
	passed = _test_dialog_onready_type_safety() and passed
	passed = _test_dialog_onready_typed_freetext() and passed
	passed = _test_copy_as_text_preserves_onready() and passed
	passed = _test_raw_block_drop_converter() and passed
	return passed


## Gap B: typing a node class in the @onready type field emits THAT type (not Variant), so a typed node
## reference like `@onready var hp: ProgressBar = $HP` is authorable from the dialog - not just Variant.
static func _test_dialog_onready_typed_freetext() -> bool:
	var captured: Dictionary = {}
	var dlg: VariableDialog = VariableDialog.new()
	var parent: Node = Node.new()
	dlg.init_dialog(parent)
	dlg.set_sheet_provider(func() -> Variant: return null)
	dlg.variable_confirmed.connect(func(_n: String, type_name: String, _d: Variant, _s: String, _c: Dictionary, _ic: bool, _ex: bool, _o: PackedStringArray, _a: Dictionary, _r: bool) -> void:
		captured["type"] = type_name
	)
	dlg.open_for_edit("tree", {}, "hp", "int", "", false, "Add Variable")
	dlg._onready_check.set_pressed_no_signal(true)
	dlg._on_onready_toggled_interactive(true)
	dlg._onready_type_edit.text = "ProgressBar"
	dlg._default_edit.text = "$HP"
	dlg._on_confirmed()
	parent.free()
	return _check("a typed @onready node class is authorable (ProgressBar, not Variant)", str(captured.get("type", "")), "ProgressBar")


## Gap A: Copy as Text of a tree variable emits its canonical declaration (const / @onready var), not a
## plain `var` - so copy-as-text is real pasteable GDScript that re-imports losslessly (paste-as-GDScript
## lifts it back). Before, an onready var pasted as a plain `var x = $Player`, resolving null at construction.
static func _test_copy_as_text_preserves_onready() -> bool:
	var clip: EventSheetClipboard = EventSheetClipboard.new()
	var onready_var: LocalVariable = LocalVariable.new()
	onready_var.name = "player"
	onready_var.type_name = "Node2D"
	onready_var.onready = true
	onready_var.default_value = "$Player"
	var lines_a: PackedStringArray = PackedStringArray()
	clip._append_resource_text(onready_var, lines_a, 0)
	var ok: bool = _check("copy-as-text of an onready var emits @onready var",
		"\n".join(lines_a), "@onready var player: Node2D = $Player")
	var const_var: LocalVariable = LocalVariable.new()
	const_var.name = "MAX_HP"
	const_var.type_name = "int"
	const_var.is_constant = true
	const_var.default_value = 99
	var lines_b: PackedStringArray = PackedStringArray()
	clip._append_resource_text(const_var, lines_b, 0)
	ok = _check("copy-as-text of a const var emits const", "\n".join(lines_b), "const MAX_HP: int = 99") and ok
	return ok


## #1 dialog behavior: ticking @onready on a NEW variable emits type Variant (safe for any node ref - a
## numeric type would crash at runtime assigning a Node) with const/@export off; EDITING a typed onready var
## preserves its declared type (round-trips a hand-authored `@onready var s: Sprite2D`).
static func _test_dialog_onready_type_safety() -> bool:
	var ok: bool = true
	var new_captured: Dictionary = {}
	var dlg_new: VariableDialog = VariableDialog.new()
	var parent_new: Node = Node.new()
	dlg_new.init_dialog(parent_new)
	dlg_new.set_sheet_provider(func() -> Variant: return null)
	dlg_new.variable_confirmed.connect(func(_n: String, type_name: String, default_value: Variant, _s: String, _c: Dictionary, is_constant: bool, exported: bool, _o: PackedStringArray, _a: Dictionary, onready: bool) -> void:
		new_captured["type"] = type_name
		new_captured["default"] = default_value
		new_captured["const"] = is_constant
		new_captured["exported"] = exported
		new_captured["onready"] = onready
	)
	dlg_new.open_for_edit("tree", {}, "player", "int", "", false, "Add Variable")
	dlg_new._onready_check.set_pressed_no_signal(true)
	dlg_new._on_onready_toggled_interactive(true)
	dlg_new._default_edit.text = "$Player"
	dlg_new._on_confirmed()
	parent_new.free()
	ok = _check("new onready var emits Variant type (no numeric crash)", str(new_captured.get("type", "")), "Variant") and ok
	ok = _check("new onready var carries the verbatim expression", str(new_captured.get("default", "")), "$Player") and ok
	ok = _check("new onready var flags onready true, const/exported false",
		[new_captured.get("onready"), new_captured.get("const"), new_captured.get("exported")], [true, false, false]) and ok

	var edit_captured: Dictionary = {}
	var existing: LocalVariable = LocalVariable.new()
	existing.name = "sprite"
	existing.type_name = "Sprite2D"
	existing.onready = true
	existing.default_value = "$Sprite2D"
	var dlg_edit: VariableDialog = VariableDialog.new()
	var parent_edit: Node = Node.new()
	dlg_edit.init_dialog(parent_edit)
	dlg_edit.set_sheet_provider(func() -> Variant: return null)
	dlg_edit.variable_confirmed.connect(func(_n: String, type_name: String, _d: Variant, _s: String, _c: Dictionary, _ic: bool, _ex: bool, _o: PackedStringArray, _a: Dictionary, _onready: bool) -> void:
		edit_captured["type"] = type_name
	)
	dlg_edit.open_for_edit("tree", {"editing": true, "variable_resource": existing}, "sprite", "Sprite2D", "$Sprite2D", false, "Edit Variable", false, false, true)
	dlg_edit._on_confirmed()
	parent_edit.free()
	ok = _check("editing a typed onready var preserves its declared type", str(edit_captured.get("type", "")), "Sprite2D") and ok

	# Guard: ticking @onready with a BLANK expression must NOT commit (it would emit `@onready var x = `,
	# a syntax error). The confirm should refuse and the signal never fires.
	var blank_committed: Array = [false]
	var dlg_blank: VariableDialog = VariableDialog.new()
	var parent_blank: Node = Node.new()
	dlg_blank.init_dialog(parent_blank)
	dlg_blank.set_sheet_provider(func() -> Variant: return null)
	dlg_blank.variable_confirmed.connect(func(_n: String, _t: String, _d: Variant, _s: String, _c: Dictionary, _ic: bool, _ex: bool, _o: PackedStringArray, _a: Dictionary, _r: bool) -> void:
		blank_committed[0] = true
	)
	dlg_blank.open_for_edit("tree", {}, "thing", "int", "", false, "Add Variable")
	dlg_blank._onready_check.set_pressed_no_signal(true)
	dlg_blank._on_onready_toggled_interactive(true)
	dlg_blank._default_edit.text = ""
	dlg_blank._on_confirmed()
	parent_blank.free()
	ok = _check("a blank @onready expression is rejected (no broken commit)", blank_committed[0], false) and ok
	return ok


## #1 model -> output: an onready tree variable compiles to `@onready var name: Type = <expr verbatim>`
## (the default is a raw GDScript expression, not a quoted literal).
static func _test_compiler_emits_onready() -> bool:
	var variable: LocalVariable = LocalVariable.new()
	variable.name = "player"
	variable.type_name = "Node2D"
	variable.onready = true
	variable.default_value = "$Player"
	return _check("compiler emits @onready var with a verbatim expression default",
		SheetCompiler._emit_tree_variable_line(variable), "@onready var player: Node2D = $Player")


## #2 lift + round-trip: compile two onready vars to canonical GDScript, reopen it, and confirm BOTH come
## back as editable onready rows (not verbatim blocks) AND the reopened sheet recompiles byte-identically.
static func _test_importer_lifts_onready_roundtrip() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var sprite_ref: LocalVariable = LocalVariable.new()
	sprite_ref.name = "sprite"
	sprite_ref.type_name = "Sprite2D"
	sprite_ref.onready = true
	sprite_ref.default_value = "$Sprite2D"
	var hp_ref: LocalVariable = LocalVariable.new()
	hp_ref.name = "hp_bar"
	hp_ref.type_name = "Node"
	hp_ref.onready = true
	hp_ref.default_value = "get_node(\"UI/HP\")"
	sheet.events.append(sprite_ref)
	sheet.events.append(hp_ref)
	var canonical: String = str(SheetCompiler.compile(sheet, "user://onready_first.gd").get("output", ""))
	ok = _check("compiled .gd carries both @onready lines",
		canonical.contains("@onready var sprite: Sprite2D = $Sprite2D") and canonical.contains("@onready var hp_bar: Node = get_node(\"UI/HP\")"), true) and ok
	# Reopen the canonical .gd as a sheet.
	var path: String = "user://onready_roundtrip.gd"
	var writer: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	writer.store_string(canonical)
	writer.close()
	var reimported: EventSheetResource = GDScriptImporter.new().import_external(path)
	var onready_names: Array = []
	for row: Variant in reimported.events:
		if row is LocalVariable and (row as LocalVariable).onready:
			onready_names.append(str((row as LocalVariable).name))
	# If the lift ever fails, the vars fall back to a verbatim RawCodeRow and this array is empty.
	ok = _check("both @onready vars reopen as editable onready rows", onready_names, ["sprite", "hp_bar"]) and ok
	var recompiled: String = str(SheetCompiler.compile(reimported, "user://onready_second.gd").get("output", ""))
	ok = _check("onready .gd round-trips byte-identically", recompiled, canonical) and ok
	return ok


## Regression: a plain (non-onready) tree variable still lifts to an editable row and is NOT flagged onready.
static func _test_plain_var_still_lifts_not_onready() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var score: LocalVariable = LocalVariable.new()
	score.name = "score"
	score.type_name = "int"
	score.default_value = 0
	sheet.events.append(score)
	var canonical: String = str(SheetCompiler.compile(sheet, "user://plain_var_first.gd").get("output", ""))
	var path: String = "user://plain_var_roundtrip.gd"
	var writer: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	writer.store_string(canonical)
	writer.close()
	var reimported: EventSheetResource = GDScriptImporter.new().import_external(path)
	var found: LocalVariable = null
	for row: Variant in reimported.events:
		if row is LocalVariable and str((row as LocalVariable).name) == "score":
			found = row as LocalVariable
	var ok: bool = _check("plain var still lifts to an editable row", found != null, true)
	if found != null:
		ok = _check("plain var is NOT flagged onready", found.onready, false) and ok
	return ok


## #3: the raw-GDScript-block editor (EventSheetRawCodeEdit) accepts a Scene-dock node / FileSystem asset
## drop and inserts the reference at the caret, via the shared converter - while its `super` delegation keeps
## the CodeEdit's native text drag-and-drop intact (that path isn't exercisable headlessly).
static func _test_raw_block_drop_converter() -> bool:
	var editor: EventSheetRawCodeEdit = EventSheetRawCodeEdit.new()
	var node_payload: Dictionary = {"type": "nodes", "nodes": ["/root/Main/Player"]}
	var ok: bool = _check("raw block accepts a Scene-node drag", editor._can_drop_data(Vector2.ZERO, node_payload), true)
	editor._drop_data(Vector2.ZERO, node_payload)
	ok = _check("dropping a node inserts its $Path reference", editor.text, "$Player") and ok
	var file_editor: EventSheetRawCodeEdit = EventSheetRawCodeEdit.new()
	file_editor._drop_data(Vector2.ZERO, {"type": "files", "files": ["res://icon.svg"]})
	ok = _check("dropping a file inserts a quoted res:// path", file_editor.text, "\"res://icon.svg\"") and ok
	# Native text drag-drop is preserved (a String payload still inserts, not silently rejected).
	var text_editor: EventSheetRawCodeEdit = EventSheetRawCodeEdit.new()
	ok = _check("raw block still accepts a text drag", text_editor._can_drop_data(Vector2.ZERO, "dropped text"), true) and ok
	text_editor._drop_data(Vector2.ZERO, "dropped text")
	ok = _check("a text drop still inserts (native drag-drop preserved)", text_editor.text, "dropped text") and ok
	editor.free()
	file_editor.free()
	text_editor.free()
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] onready_variable_test: %s" % label)
		return true
	print("[FAIL] onready_variable_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
