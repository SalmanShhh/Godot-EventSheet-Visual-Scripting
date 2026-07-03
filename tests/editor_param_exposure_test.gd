# EventSheet — Editor parameter exposure tests
# Covers EditorParamStore, ACEDefinition exposure fields, ParamDefaultResolver,
# and ACEGenerator exposure inference.
@tool
class_name EditorParamExposureTest
extends RefCounted

const SAMPLE_SCRIPT := preload("res://tests/fixtures/auto_ace_sample.gd")


class FakeEditorUndoRedoManager:
	extends RefCounted

	var _pending_do: Array[Callable] = []
	var _pending_undo: Array[Callable] = []
	var _undo_stack: Array[Dictionary] = []
	var _redo_stack: Array[Dictionary] = []

	func create_action(_name: String) -> void:
		_pending_do.clear()
		_pending_undo.clear()

	func add_do_method(
		target: Object,
		method_name: String,
		arg1: Variant = null,
		arg2: Variant = null,
		arg3: Variant = null,
		arg4: Variant = null
	) -> void:
		var args: Array = [arg1, arg2, arg3, arg4]
		_pending_do.append(func() -> void: target.callv(method_name, _trim_null_args(args)))

	func add_undo_method(
		target: Object,
		method_name: String,
		arg1: Variant = null,
		arg2: Variant = null,
		arg3: Variant = null,
		arg4: Variant = null
	) -> void:
		var args: Array = [arg1, arg2, arg3, arg4]
		_pending_undo.append(func() -> void: target.callv(method_name, _trim_null_args(args)))

	func commit_action() -> void:
		for action in _pending_do:
			action.call()
		_undo_stack.append({"do": _pending_do.duplicate(), "undo": _pending_undo.duplicate()})
		_pending_do.clear()
		_pending_undo.clear()
		_redo_stack.clear()

	func has_undo() -> bool:
		return not _undo_stack.is_empty()

	func has_redo() -> bool:
		return not _redo_stack.is_empty()

	func undo() -> void:
		if _undo_stack.is_empty():
			return
		var action: Dictionary = _undo_stack.pop_back()
		for undo_action in action.get("undo", []):
			(undo_action as Callable).call()
		_redo_stack.append(action)

	func redo() -> void:
		if _redo_stack.is_empty():
			return
		var action: Dictionary = _redo_stack.pop_back()
		for do_action in action.get("do", []):
			(do_action as Callable).call()
		_undo_stack.append(action)

	static func _trim_null_args(args: Array) -> Array:
		var output: Array = args.duplicate()
		while not output.is_empty() and output[output.size() - 1] == null:
			output.pop_back()
		return output


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _test_editor_param_store() and all_passed
	all_passed = _test_editor_param_store_round_trip() and all_passed
	all_passed = _test_ace_definition_exposure_fields() and all_passed
	all_passed = _test_param_default_resolver() and all_passed
	all_passed = _test_ace_generator_exposure_inference() and all_passed
	all_passed = _test_c3_metadata_contract() and all_passed
	all_passed = _test_exposed_node_scope_and_undo() and all_passed
	return all_passed

# ── EditorParamStore ──────────────────────────────────────────────────────────


static func _test_editor_param_store() -> bool:
	var passed: bool = true
	var store := EditorParamStore.new()

	passed = _check("store is empty initially", store.override_count(), 0) and passed
	passed = _check("has_param returns false for unknown", store.has_param("P", "A", "x"), false) and passed

	store.set_param("P", "A", "x", 42)
	passed = _check("has_param true after set", store.has_param("P", "A", "x"), true) and passed
	passed = _check("get_param returns stored value", store.get_param("P", "A", "x"), 42) and passed
	passed = _check("override count incremented", store.override_count(), 1) and passed

	store.set_param("P", "A", "x", 99)
	passed = _check("set_param overwrites existing", store.get_param("P", "A", "x"), 99) and passed

	store.set_param("P", "B", "y", "hello")
	passed = _check("second param stored", store.get_param("P", "B", "y"), "hello") and passed
	passed = _check("override count is 2", store.override_count(), 2) and passed

	store.clear_param("P", "A", "x")
	passed = _check("clear_param removes entry", store.has_param("P", "A", "x"), false) and passed
	passed = _check("override count decremented", store.override_count(), 1) and passed

	store.clear_all()
	passed = _check("clear_all empties store", store.override_count(), 0) and passed

	passed = _check("get_param returns default when missing", store.get_param("P", "A", "z", -1), -1) and passed

	return passed


static func _test_editor_param_store_round_trip() -> bool:
	var passed: bool = true
	var store := EditorParamStore.new()
	store.set_param("P", "A", "zero", 0)
	store.set_param("P", "A", "empty", "")
	store.set_param("P", "A", "flag", false)
	var path: String = "user://editor_param_store_roundtrip.tres"
	var save_err: Error = ResourceSaver.save(store, path)
	passed = _check("store round-trip save succeeds", save_err, OK) and passed
	var loaded: Resource = ResourceLoader.load(path)
	passed = _check("store round-trip loads resource", loaded is EditorParamStore, true) and passed
	if loaded is EditorParamStore:
		var loaded_store: EditorParamStore = loaded as EditorParamStore
		passed = _check("store round-trip keeps zero", loaded_store.get_param("P", "A", "zero"), 0) and passed
		passed = _check("store round-trip keeps empty string", loaded_store.get_param("P", "A", "empty"), "") and passed
		passed = _check("store round-trip keeps false", loaded_store.get_param("P", "A", "flag"), false) and passed
	return passed

# ── ACEDefinition exposure fields ─────────────────────────────────────────────


static func _test_ace_definition_exposure_fields() -> bool:
	var passed: bool = true
	var def := ACEDefinition.new()

	passed = _check("editor_exposed defaults to false", def.editor_exposed, false) and passed
	passed = _check("property_hint defaults to PROPERTY_HINT_NONE", def.property_hint, PROPERTY_HINT_NONE) and passed
	passed = _check("hint_string defaults empty", def.hint_string, "") and passed
	passed = _check("widget_hint defaults empty", def.widget_hint, "") and passed
	passed = _check("category_override defaults empty", def.category_override, "") and passed

	def.category = "Physics"
	def.category_override = ""
	passed = _check("get_inspector_category falls back to category", def.get_inspector_category(), "Physics") and passed

	def.category_override = "MyOverride"
	passed = _check("get_inspector_category uses override when set", def.get_inspector_category(), "MyOverride") and passed

	return passed

# ── ParamDefaultResolver ──────────────────────────────────────────────────────


static func _test_param_default_resolver() -> bool:
	var passed: bool = true
	var store := EditorParamStore.new()
	var resolver := ParamDefaultResolver.new()
	resolver.set_param_store(store)

	var param_meta := {
		"id": "amount",
		"type": TYPE_INT,
		"default_value": 10
	}

	# No overrides: should return ACE default
	var result: Variant = resolver.resolve("P", "A", "amount", param_meta, null)
	passed = _check("resolver returns ace default when no overrides", result, 10) and passed

	# Row override takes top priority
	result = resolver.resolve("P", "A", "amount", param_meta, 99)
	passed = _check("resolver returns row override first", result, 99) and passed

	# Editor store override
	store.set_param("P", "A", "amount", 55)
	result = resolver.resolve("P", "A", "amount", param_meta, null)
	passed = _check("resolver returns store override", result, 55) and passed

	# Row override still wins over store
	result = resolver.resolve("P", "A", "amount", param_meta, 77)
	passed = _check("row override still wins over store", result, 77) and passed

	# Zero-value fallback when no default in meta
	var no_default_meta := {"id": "flag", "type": TYPE_BOOL}
	result = resolver.resolve("P", "A", "flag", no_default_meta, null)
	passed = _check("resolver returns type zero-value as last resort", result, false) and passed

	# resolve_all
	var def := ACEDefinition.new()
	def.provider_id = "P"
	def.id = "A"
	def.parameters = [param_meta, no_default_meta]
	var resolved: Dictionary = resolver.resolve_all(def, {"amount": 3})
	passed = _check("resolve_all uses row params", resolved.get("amount"), 3) and passed

	return passed

# ── ACEGenerator exposure inference ───────────────────────────────────────────


static func _test_ace_generator_exposure_inference() -> bool:
	var passed: bool = true
	var sample: Node = SAMPLE_SCRIPT.new()
	var registry := EventSheetACERegistry.new()
	registry.refresh_from_sources([sample], false)  # no builtins needed

	var provider_id: String = "AutoACESample"

	# Exported property expression should be editor_exposed = true
	var health_expr: ACEDefinition = registry.find_definition(provider_id, "property:health")
	passed = _check("exported property expression is editor_exposed", health_expr.editor_exposed if health_expr != null else false, true) and passed

	# Signal trigger should NOT be editor_exposed
	var died_trig: ACEDefinition = registry.find_definition(provider_id, "signal:died")
	passed = _check("signal trigger is not editor_exposed", died_trig.editor_exposed if died_trig != null else true, false) and passed

	# Void method with primitive param should be editor_exposed
	var take_dmg: ACEDefinition = registry.find_definition(provider_id, "method:take_damage")
	passed = _check("void method with primitive param is editor_exposed", take_dmg.editor_exposed if take_dmg != null else false, true) and passed

	# String-returning expression should also be editor_exposed
	var status_text: ACEDefinition = registry.find_definition(provider_id, "method:get_status_label")
	passed = _check("string-returning expression is editor_exposed", status_text.editor_exposed if status_text != null else false, true) and passed

	# Falsy param default (0) must be preserved — not skipped — by the resolver
	var store2 := EditorParamStore.new()
	var resolver2 := ParamDefaultResolver.new()
	resolver2.set_param_store(store2)
	var zero_meta := {"id": "count", "type": TYPE_INT, "default_value": 0}
	var resolved_zero: Variant = resolver2.resolve("P", "A", "count", zero_meta, null)
	passed = _check("resolver preserves zero ACE default", resolved_zero, 0) and passed

	sample.free()
	return passed


static func _test_c3_metadata_contract() -> bool:
	var passed: bool = true
	var sample: Node = SAMPLE_SCRIPT.new()
	var registry := EventSheetACERegistry.new()
	registry.refresh_from_sources([sample], false)
	var signal_def: ACEDefinition = registry.find_definition("AutoACESample", "signal:died")
	passed = _check("signal id uses stable serialized prefix", signal_def != null and signal_def.id.begins_with("signal:"), true) and passed
	var trigger_state_model: String = str(signal_def.metadata.get("trigger_state_model", "")) if signal_def != null else ""
	passed = _check("signal metadata carries trigger state model", trigger_state_model, "captured_context") and passed
	passed = _check("signal definitions include description", signal_def != null and not signal_def.description.is_empty(), true) and passed
	var method_def: ACEDefinition = registry.find_definition("AutoACESample", "method:take_damage")
	var first_param: Dictionary = method_def.parameters[0] if method_def != null and not method_def.parameters.is_empty() else {}
	passed = _check("method param keeps stable id field", str(first_param.get("id", "")), "amount") and passed
	passed = _check("method param carries options metadata array", first_param.has("options"), true) and passed
	sample.free()
	return passed


static func _test_exposed_node_scope_and_undo() -> bool:
	var passed: bool = true
	var sample: Node = SAMPLE_SCRIPT.new()
	var registry := EventSheetACERegistry.new()
	registry.refresh_from_sources([sample], false)
	var store := EditorParamStore.new()
	var resolver := ParamDefaultResolver.new()
	resolver.set_param_store(store)
	var sheet := EventSheetResource.new()
	var row := EventRow.new()
	row.actions = [ACEAction.new()]
	(row.actions[0] as ACEAction).provider_id = "AutoACESample"
	(row.actions[0] as ACEAction).ace_id = "method:take_damage"
	sheet.events = [row]
	var exposed := EventSheetExposedNode.new()
	exposed.setup(registry, store, sheet, resolver)
	var prop_list: Array[Dictionary] = exposed._get_property_list()
	passed = _check("exposed node emits scoped property list", prop_list.is_empty(), false) and passed
	var first_property: String = ""
	for property_entry in prop_list:
		if int(property_entry.get("usage", 0)) & PROPERTY_USAGE_CATEGORY != 0:
			continue
		first_property = str(property_entry.get("name", ""))
		break
	passed = _check("exposed node has at least one dynamic property", first_property.is_empty(), false) and passed
	if not first_property.is_empty():
		# The undo adapter speaks EditorUndoRedoManager's positional add_do_method(obj,
		# method, ...args) contract — which is what production always uses. A plain
		# UndoRedo takes a single Callable, so its add_do_method rejects the positional
		# call (Godot 4.7 errors instead of silently no-op'ing), and the store never
		# updates. Use the editor-shaped fake here to exercise the real code path.
		var undo_redo := FakeEditorUndoRedoManager.new()
		exposed.set_undo_redo(undo_redo)
		passed = _check("setting exposed property succeeds", exposed._set(first_property, 33), true) and passed
		passed = _check("store updated from exposed property", store.override_count() > 0, true) and passed
		undo_redo.undo()
		passed = _check("undo clears property override", store.override_count(), 0) and passed
		var editor_undo := FakeEditorUndoRedoManager.new()
		exposed.set_undo_redo_manager(editor_undo)
		passed = _check("setting exposed property succeeds with editor undo manager", exposed._set(first_property, 17), true) and passed
		passed = _check("store updated with editor undo manager", store.override_count() > 0, true) and passed
		editor_undo.undo()
		passed = _check("editor undo manager clears property override", store.override_count(), 0) and passed
	sample.free()
	return passed

# ── Helpers ───────────────────────────────────────────────────────────────────


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] editor_param_exposure_test: %s" % label)
		return true
	print("[FAIL] editor_param_exposure_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
