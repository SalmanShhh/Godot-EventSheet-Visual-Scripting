# Godot EventSheets - the Sheet Type dialog's anti-fatigue contract.
#
# The dialog shows ONLY the fields the chosen type consumes (mirroring apply_sheet_type_settings:
# a plain sheet clears the named-type identity; Autoload / Editor Tool force their host), and a live
# identity line previews the compiled `class_name X extends Y` with real validation. Both are static
# and value-driven, so this pins them without building the dialog or the dock.
@tool
class_name SheetTypeDialogTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")


class NoopUndoManager:
	extends RefCounted
	func create_action(_a = null) -> void: pass
	func add_do_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func add_undo_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func commit_action() -> void: pass
	func has_undo() -> bool: return false
	func has_redo() -> bool: return false
	func undo() -> void: pass
	func redo() -> void: pass
	func clear_history() -> void: pass


## Remembers the name of every undo step the editor creates, so a test can count the steps one
## gesture produced.
class RecordingUndoManager:
	extends RefCounted
	var actions: PackedStringArray = PackedStringArray()
	func create_action(name = null, _b = null, _c = null, _d = null) -> void: actions.append(str(name))
	func add_do_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func add_undo_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func commit_action(_a = null) -> void: pass
	func has_undo() -> bool: return false
	func has_redo() -> bool: return false
	func undo() -> void: pass
	func redo() -> void: pass
	func clear_history() -> void: pass


static func run() -> bool:
	var passed: bool = true
	passed = _test_field_visibility() and passed
	passed = _test_identity_preview() and passed
	passed = _test_validation() and passed
	passed = _test_host_candidates() and passed
	passed = _test_ok_waits_for_a_valid_identity() and passed
	passed = _test_name_change_renames_uses() and passed
	return passed


## OK cannot apply what the identity line is warning about: it is disabled while the line shows a
## problem and enabled again once the problem is gone.
static func _test_ok_waits_for_a_valid_identity() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "ZzSheetTypeReachProbe"
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	editor.set_undo_redo_manager(NoopUndoManager.new())
	var dialog: EventSheetSheetTypeDialog = editor._sheet_type as EventSheetSheetTypeDialog
	dialog._ensure_sheet_type_dialog()
	dialog._select_type(1)
	dialog._refresh_type_ui()
	dialog._sheet_type_host_edit.text = "Node2D"
	dialog._sheet_type_name_edit.text = "My Class"
	dialog._refresh_identity_preview()
	ok = _check("OK is disabled while the class name is invalid",
		dialog._sheet_type_dialog.get_ok_button().disabled, true) and ok
	var bad_name: Array = [dialog._band.words_label.text, dialog._problem.text, dialog._foot_note.text]
	dialog._sheet_type_host_edit.text = "CharcterBody2D"
	dialog._sheet_type_name_edit.text = "Guard"
	dialog._refresh_identity_preview()
	var bad_host: Array = [dialog._band.words_label.text, dialog._problem.text, dialog._foot_note.text]
	dialog._sheet_type_host_edit.text = "Node2D"
	dialog._refresh_identity_preview()
	ok = SUPPORT.pins("sheet_type_band", [
		["the band puts a ? where the bad name goes, the note says why, the foot says what to fix",
			bad_name, ["class_name ? extends Node2D",
				"\"My Class\" can't be a class name (letters/digits/underscores, no keywords).", "Fix Name first"]],
		["an unknown host is the Extends field's problem", bad_host, ["class_name Guard extends ?",
			"Unknown class \"CharcterBody2D\" - did you mean CharacterBody2D?", "Fix Extends first"]],
		["a valid identity is the band's class line, and the strip's IN CODE",
			[dialog._band.words_label.text, dialog._problem.text, dialog._foot_note.text, dialog._help_strip.in_code_value.text],
			["class_name Guard extends Node2D", "", "", "extends Node2D"]],
		["the chosen kind's line stays in view", (dialog._sheet_type_option.get_meta("chosen_note") as Label).text,
			EventSheetSheetTypeDialog.TYPE_HINTS[1]],
	]) and ok
	ok = _check("OK comes back once the name is valid",
		dialog._sheet_type_dialog.get_ok_button().disabled, false) and ok
	# A new Name renames the class's uses, other files included, so the dialog says how far that
	# reaches before OK - the sentence the head's Rename class dialog shows.
	ok = _check("a new Name says what the rename reaches before OK",
		[dialog._rename_reach.visible, dialog._rename_reach.text],
		[true, "renames nothing else - this name is used nowhere yet"]) and ok
	dialog._sheet_type_name_edit.text = "ZzSheetTypeReachProbe"
	dialog._refresh_identity_preview()
	ok = _check("and says nothing while the Name is unchanged", dialog._rename_reach.visible, false) and ok
	dialog._sheet_type_name_edit.text = "My Class"
	dialog._on_sheet_type_confirmed()
	ok = _check("confirming with a problem showing leaves the class name alone",
		editor._current_sheet.custom_class_name, "ZzSheetTypeReachProbe") and ok
	editor.free()
	return ok


## A new Name on an already named class renames its uses too, the way the head's Rename class does,
## instead of relabelling the class and leaving the rows naming a class that no longer exists.
static func _test_name_change_renames_uses() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "ZzSheetTypeRenameOld"
	var use_row: RawCodeRow = RawCodeRow.new()
	use_row.code = "var leader: ZzSheetTypeRenameOld = null"
	sheet.events.append(use_row)
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	editor.set_undo_redo_manager(NoopUndoManager.new())
	editor._apply_sheet_type_settings(1, "ZzSheetTypeRenameNew", "", "Node2D")
	ok = _check("the class takes the new name", editor._current_sheet.custom_class_name, "ZzSheetTypeRenameNew") and ok
	ok = _check("the row that used the old name follows it",
		(editor._current_sheet.events[0] as RawCodeRow).code, "var leader: ZzSheetTypeRenameNew = null") and ok
	editor.free()

	# One OK is one undo step: the rename and the rest of the type settings used to land as "Rename
	# Class" then "Set Sheet Type", so one Ctrl+Z took back the settings and left the rename behind.
	var second: EventSheetResource = EventSheetResource.new()
	second.host_class = "Node2D"
	second.custom_class_name = "ZzSheetTypeRenameOld"
	var recorded: EventSheetEditor = EventSheetEditor.new()
	recorded.setup(second)
	var recorder := RecordingUndoManager.new()
	recorded.set_undo_redo_manager(recorder)
	recorded._apply_sheet_type_settings(1, "ZzSheetTypeRenameNew", "", "Node2D", false,
		PackedStringArray(), PackedStringArray(), PackedStringArray(), PackedStringArray(), "",
		"Walks the guard route.")
	ok = _check("a new Name and other settings on one OK are one undo step that carries both",
		[recorder.actions, recorded._current_sheet.custom_class_name, recorded._current_sheet.class_description],
		[PackedStringArray(["Set Sheet Type"]), "ZzSheetTypeRenameNew", "Walks the guard route."]) and ok
	recorded.free()
	return ok


## The as-you-type host suggestions: curated shortlist when empty, prefix-then-substring ranking,
## host-sensible classes only (Node/Resource family, instantiable), project class_names included.
static func _test_host_candidates() -> bool:
	var ok: bool = true
	var empty_typed: PackedStringArray = EventSheetSheetTypeDialog.host_candidates("")
	ok = _check("empty text offers the curated shortlist first", empty_typed[0], "CharacterBody2D") and ok
	ok = _check("the curated shortlist is capped at 8", empty_typed.size() <= 8, true) and ok
	var char_typed: PackedStringArray = EventSheetSheetTypeDialog.host_candidates("Char")
	ok = _check("prefix matches rank first for \"Char\"", char_typed[0], "CharacterBody2D") and ok
	ok = _check("\"Char\" also offers the 3D sibling", char_typed.has("CharacterBody3D"), true) and ok
	var lower_typed: PackedStringArray = EventSheetSheetTypeDialog.host_candidates("sprite")
	ok = _check("matching is case-insensitive", lower_typed.has("Sprite2D"), true) and ok
	var substring_typed: PackedStringArray = EventSheetSheetTypeDialog.host_candidates("Body2D")
	ok = _check("substring matches surface too (Body2D -> CharacterBody2D)", substring_typed.has("CharacterBody2D"), true) and ok
	ok = _check("non-host classes are never suggested (TextServer is not a Node/Resource)",
		EventSheetSheetTypeDialog.host_candidates("TextServer").has("TextServer"), false) and ok
	ok = _check("project class_name scripts are suggested",
		EventSheetSheetTypeDialog.host_candidates("Enem", ["EnemyBase", "Loot"]).has("EnemyBase"), true) and ok
	ok = _check("an exactly-typed class is not suggested back",
		EventSheetSheetTypeDialog.host_candidates("Node2D").has("Node2D"), false) and ok
	ok = _check("results never exceed the cap", EventSheetSheetTypeDialog.host_candidates("a").size() <= 8, true) and ok
	return ok


## The per-type field map - pinned VALUE by VALUE so a regression names the exact field and type.
static func _test_field_visibility() -> bool:
	var ok: bool = true
	ok = _check("plain Event Sheet shows ONLY the host row",
		EventSheetSheetTypeDialog.field_visibility(0),
		{"name": false, "icon": false, "description": false, "host": true, "family": false, "autoload": false, "plugin_capabilities": false}) and ok
	ok = _check("Custom Node shows identity + host + family",
		EventSheetSheetTypeDialog.field_visibility(1),
		{"name": true, "icon": true, "description": true, "host": true, "family": true, "autoload": false, "plugin_capabilities": false}) and ok
	ok = _check("Behavior shows identity + host + family",
		EventSheetSheetTypeDialog.field_visibility(2),
		{"name": true, "icon": true, "description": true, "host": true, "family": true, "autoload": false, "plugin_capabilities": false}) and ok
	ok = _check("Editor Tool hides host (forced to EditorScript) + family",
		EventSheetSheetTypeDialog.field_visibility(3),
		{"name": true, "icon": true, "description": true, "host": false, "family": false, "autoload": false, "plugin_capabilities": false}) and ok
	ok = _check("Autoload hides host (forced to Node), shows the autoload name",
		EventSheetSheetTypeDialog.field_visibility(4),
		{"name": true, "icon": true, "description": true, "host": false, "family": false, "autoload": true, "plugin_capabilities": false}) and ok
	ok = _check("Custom Resource shows identity + host, hides family",
		EventSheetSheetTypeDialog.field_visibility(5),
		{"name": true, "icon": true, "description": true, "host": true, "family": false, "autoload": false, "plugin_capabilities": false}) and ok
	# The rest of the tool family. All three force their own host like Editor Tool does; only
	# the Editor plugin has capabilities to tick, because only a plugin can add anything to the editor.
	ok = _check("Editor Plugin hides host (forced to EditorPlugin), shows the capability ticks",
		EventSheetSheetTypeDialog.field_visibility(7),
		{"name": true, "icon": true, "description": true, "host": false, "family": false, "autoload": false, "plugin_capabilities": true}) and ok
	ok = _check("Import Tool hides host (forced to EditorScript) and the ticks",
		EventSheetSheetTypeDialog.field_visibility(8),
		{"name": true, "icon": true, "description": true, "host": false, "family": false, "autoload": false, "plugin_capabilities": false}) and ok
	ok = _check("Export Hook hides host (forced to EditorScript) and the ticks",
		EventSheetSheetTypeDialog.field_visibility(9),
		{"name": true, "icon": true, "description": true, "host": false, "family": false, "autoload": false, "plugin_capabilities": false}) and ok
	return ok


## The live "Ships as" line mirrors what the compiler will emit, including the forced hosts.
static func _test_identity_preview() -> bool:
	var ok: bool = true
	ok = _check("plain sheet previews a bare extends",
		EventSheetSheetTypeDialog.identity_preview(0, "", "Node2D", ""),
		"Ships as:  extends Node2D") and ok
	ok = _check("custom node previews class_name + extends",
		EventSheetSheetTypeDialog.identity_preview(1, "Patrol", "CharacterBody2D", ""),
		"Ships as:  class_name Patrol extends CharacterBody2D") and ok
	ok = _check("editor tool forces EditorScript regardless of the host text",
		EventSheetSheetTypeDialog.identity_preview(3, "MyTool", "Node2D", ""),
		"Ships as:  class_name MyTool extends EditorScript") and ok
	ok = _check("autoload forces Node and shows the global name",
		EventSheetSheetTypeDialog.identity_preview(4, "GameState", "Node2D", "GameState"),
		"Ships as:  class_name GameState extends Node  -  autoload \"GameState\"") and ok
	ok = _check("custom resource falls back to Resource for a node-ish host",
		EventSheetSheetTypeDialog.identity_preview(5, "LootTable", "Node2D", ""),
		"Ships as:  class_name LootTable extends Resource") and ok
	ok = _check("custom resource keeps a real Resource subclass host",
		EventSheetSheetTypeDialog.identity_preview(5, "MyStream", "AudioStream", ""),
		"Ships as:  class_name MyStream extends AudioStream") and ok
	return ok


## Typos and collisions surface AS YOU TYPE instead of shipping a broken `extends` / duplicate class.
static func _test_validation() -> bool:
	var ok: bool = true
	var typo: String = EventSheetSheetTypeDialog.identity_preview(1, "Patrol", "CharcterBody2D", "")
	ok = _check("a host typo is flagged", typo.begins_with("x Unknown class \"CharcterBody2D\""), true) and ok
	ok = _check("the typo message suggests the real class", typo.contains("CharacterBody2D"), true) and ok
	ok = _check("an engine-class collision is flagged",
		EventSheetSheetTypeDialog.identity_preview(1, "Node", "Node2D", "").begins_with("x \"Node\" is already a class name"), true) and ok
	ok = _check("the sheet's OWN saved class name is not a collision",
		EventSheetSheetTypeDialog.identity_preview(1, "Patrol", "Node2D", "", "Patrol"),
		"Ships as:  class_name Patrol extends Node2D") and ok
	ok = _check("an invalid identifier is flagged",
		EventSheetSheetTypeDialog.identity_preview(1, "My Class", "Node2D", "").begins_with("x \"My Class\" can't be a class name"), true) and ok
	ok = _check("a hidden host row never blocks (Autoload ignores stale host text)",
		EventSheetSheetTypeDialog.identity_preview(4, "GameState", "CharcterBody2D", "GameState").begins_with("Ships as:"), true) and ok
	ok = _check("a lowercase exact-case-insensitive host suggests the engine spelling",
		EventSheetSheetTypeDialog.identity_preview(0, "", "node2d", "").contains("did you mean Node2D?"), true) and ok
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("sheet_type_dialog_test", label, actual, expected)
