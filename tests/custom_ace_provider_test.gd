# EventForge — Custom ACE provider registration (end-to-end, editor side)
#
# Registers a user GDScript as a custom-ACE provider on a sheet and asserts its members
# surface in the ACE registry the picker reads (and disappear when removed). Headless-safe.
@tool
extends RefCounted
class_name CustomACEProviderTest

const FIXTURE_PATH := "res://tests/fixtures/auto_ace_sample.gd"

# No-op undo manager matching the dock's EditorUndoRedoManager call shape (see
# keyboard_actions_test) so undoable edits run cleanly headlessly.
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

static func run() -> bool:
	var all_passed: bool = true
	var editor: EventSheetEditor = EventSheetEditor.new()
	var sheet: EventSheetResource = EventSheetResource.new()
	editor.setup(sheet)
	editor.set_undo_redo_manager(NoopUndoManager.new())

	# Before registration the custom provider's ACEs are absent.
	all_passed = _check("custom ACE absent before registration",
		editor.get_ace_registry().find_definition("AutoACESample", "method:take_damage") == null, true) and all_passed

	# Register the provider script.
	var added: bool = editor.add_ace_provider_script(FIXTURE_PATH)
	all_passed = _check("add provider returns true", added, true) and all_passed
	all_passed = _check("provider persisted on sheet", sheet.ace_provider_scripts.has(FIXTURE_PATH), true) and all_passed

	# Its members now surface in the registry the picker reads.
	var registry: EventSheetACERegistry = editor.get_ace_registry()
	all_passed = _check("method action registered",
		registry.find_definition("AutoACESample", "method:take_damage") != null, true) and all_passed
	all_passed = _check("signal trigger registered",
		registry.find_definition("AutoACESample", "signal:died") != null, true) and all_passed
	all_passed = _check("exported var expression registered",
		registry.find_definition("AutoACESample", "property:health") != null, true) and all_passed
	var condition: ACEDefinition = registry.find_definition("AutoACESample", "method:is_dead")
	all_passed = _check("bool method registers as a condition",
		condition != null and condition.ace_type == ACEDefinition.ACEType.CONDITION, true) and all_passed

	# Duplicate registration is rejected.
	all_passed = _check("duplicate provider rejected", editor.add_ace_provider_script(FIXTURE_PATH), false) and all_passed

	# Removal drops the provider and its ACEs.
	all_passed = _check("remove provider returns true", editor.remove_ace_provider_script(FIXTURE_PATH), true) and all_passed
	all_passed = _check("provider removed from sheet", not sheet.ace_provider_scripts.has(FIXTURE_PATH), true) and all_passed
	all_passed = _check("custom ACE gone after removal",
		editor.get_ace_registry().find_definition("AutoACESample", "method:take_damage") == null, true) and all_passed

	editor.free()
	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] custom_ace_provider_test: %s" % label)
		return true
	print("[FAIL] custom_ace_provider_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
