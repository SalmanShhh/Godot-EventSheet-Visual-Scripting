# Godot EventSheets — Inspector attributes, Tier 1 (docs/INSPECTOR-ATTRIBUTES-SPEC.md):
# tooltip / group / range / multiline on exported globals; canonical emission order;
# lossless raw fallback for external files.
@tool
extends RefCounted
class_name InspectorAttributesTest

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

	# Emission: tooltip doc-comment, then group, then the annotated export line.
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.variables = {
		"max_health": {"type": "int", "default": 100, "exported": true,
			"attributes": {"tooltip": "Max health", "group": "Combat", "range": {"min": "0", "max": "200", "step": "1"}}},
		"bio": {"type": "String", "default": "", "exported": true, "attributes": {"multiline": true}},
		"secret": {"type": "int", "default": 7, "exported": false, "attributes": {"tooltip": "never shown"}},
		"difficulty": {"type": "String", "default": "easy", "exported": true, "options": ["easy", "hard"],
			"attributes": {"tooltip": "Pick one"}}
	}
	var output: String = str(SheetCompiler.compile(sheet, "user://eventsheets_attrs.gd").get("output", ""))
	all_passed = _check("range merges into the export annotation",
		output.contains("@export_range(0, 200, 1) var max_health: int = 100"), true) and all_passed
	var tooltip_at: int = output.find("## Max health")
	var group_at: int = output.find("@export_group(\"Combat\")")
	var var_at: int = output.find("var max_health")
	all_passed = _check("canonical order: tooltip, group, export line",
		tooltip_at >= 0 and tooltip_at < group_at and group_at < var_at, true) and all_passed
	all_passed = _check("multiline strings annotate",
		output.contains("@export_multiline var bio: String = \"\""), true) and all_passed
	all_passed = _check("non-exported variables ignore attributes",
		output.contains("never shown"), false) and all_passed
	all_passed = _check("combos keep their enum prefix alongside a tooltip",
		output.contains("## Pick one") and output.contains("@export_enum(\"easy\", \"hard\") var difficulty"), true) and all_passed
	var generated: GDScript = GDScript.new()
	generated.source_code = output
	all_passed = _check("attributed output parses", generated.reload(true) == OK, true) and all_passed

	# Dialog plumbing: fields -> attributes payload -> dock storage.
	var editor: EventSheetEditor = EventSheetEditor.new()
	var dock_sheet: EventSheetResource = EventSheetResource.new()
	editor.setup(dock_sheet)
	editor.set_undo_redo_manager(NoopUndoManager.new())
	editor._on_variable_dialog_confirmed("speed", "float", 5.0, "global", {}, false, true,
		PackedStringArray(), {"tooltip": "Units/sec", "range": {"min": "0", "max": "10", "step": "0.5"}})
	var stored: Dictionary = dock_sheet.variables.get("speed", {})
	all_passed = _check("dock stores the attributes",
		(stored.get("attributes", {}) as Dictionary).get("tooltip", ""), "Units/sec") and all_passed
	var stored_output: String = str(SheetCompiler.compile(dock_sheet, "user://eventsheets_attrs2.gd").get("output", ""))
	all_passed = _check("stored attributes compile",
		stored_output.contains("@export_range(0, 10, 0.5) var speed: float = 5.0"), true) and all_passed
	editor.free()

	# Lossless rule: an external .gd with attribute lines round-trips byte-identically
	# (the prefix lines ride as raw rows; nothing rewrites them).
	var ext: String = "extends Node\n\n## Max health\n@export_group(\"Combat\")\n@export_range(0, 200, 1) var max_health: int = 100\n"
	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(ext)
	imported.external_source_path = "user://eventsheets_attrs_ext.gd"
	all_passed = _check("external attribute lines round-trip byte-identically",
		str(SheetCompiler.compile(imported, "user://eventsheets_attrs_ext.gd").get("output", "")) == ext, true) and all_passed

	# Edit prefill: reopening a variable restores its attribute fields (incl. range).
	var prefill_dialog: VariableDialog = VariableDialog.new()
	var prefill_host: Node = Node.new()
	prefill_dialog.init_dialog(prefill_host)
	prefill_dialog.open_for_edit("global", {"attributes": {"tooltip": "Hi", "group": "Combat", "range": {"min": "0", "max": "9", "step": "1"}, "multiline": false}}, "hp", "int", 5)
	all_passed = _check("edit prefills tooltip", prefill_dialog._attr_tooltip_edit.text, "Hi") and all_passed
	all_passed = _check("edit prefills range as min, max, step", prefill_dialog._attr_range_edit.text, "0, 9, 1") and all_passed
	prefill_host.free()

	# ── Tier 2: setters, conditions, read-only ──
	var t2: EventSheetResource = EventSheetResource.new()
	var notify_fn: EventFunction = EventFunction.new()
	notify_fn.function_name = "_on_hp_changed"
	t2.functions.append(notify_fn)
	t2.variables = {
		"hp": {"type": "int", "default": 100, "exported": true,
			"attributes": {"range": {"min": "0", "max": "200", "step": "1"}, "clamp": true, "on_changed": "_on_hp_changed"}},
		"speed": {"type": "float", "default": 5.0, "exported": true,
			"attributes": {"range": {"min": "0", "max": "10", "step": "0.5"}, "clamp": true}},
		"use_gravity": {"type": "bool", "default": true, "exported": true, "attributes": {}},
		"gravity_scale": {"type": "float", "default": 1.0, "exported": true, "attributes": {"show_if": "use_gravity"}},
		"drag": {"type": "float", "default": 0.1, "exported": true, "attributes": {"lock_unless": "use_gravity"}},
		"version_label": {"type": "String", "default": "1.0", "exported": true, "attributes": {"read_only": true}}
	}
	var t2_output: String = str(SheetCompiler.compile(t2, "user://eventsheets_t2.gd").get("output", ""))
	all_passed = _check("clamp + on_changed emit the canonical setter",
		t2_output.contains("@export_range(0, 200, 1) var hp: int = 100:")
		and t2_output.contains("		hp = clampi(value, 0, 200)")
		and t2_output.contains("		_on_hp_changed()"), true) and all_passed
	all_passed = _check("float clamps use clampf", t2_output.contains("		speed = clampf(value, 0, 10)"), true) and all_passed
	all_passed = _check("show_if joins the aggregated _validate_property",
		t2_output.contains("func _validate_property(property: Dictionary) -> void:")
		and t2_output.contains("if str(property.name) == \"gravity_scale\" and not bool(use_gravity):")
		and t2_output.contains("property.usage &= ~PROPERTY_USAGE_EDITOR"), true) and all_passed
	all_passed = _check("lock_unless flips read-only usage",
		t2_output.contains("if str(property.name) == \"drag\" and not bool(use_gravity):")
		and t2_output.contains("property.usage |= PROPERTY_USAGE_READ_ONLY"), true) and all_passed
	all_passed = _check("static read-only uses @export_custom",
		t2_output.contains("@export_custom(PROPERTY_HINT_NONE, \"\", PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_READ_ONLY) var version_label"), true) and all_passed
	all_passed = _check("only one _validate_property emits", t2_output.count("func _validate_property") == 1, true) and all_passed
	var t2_script: GDScript = GDScript.new()
	t2_script.source_code = t2_output
	all_passed = _check("Tier 2 output parses", t2_script.reload(true) == OK, true) and all_passed

	# Unknown on_changed target warns (typo guard).
	var typo: EventSheetResource = EventSheetResource.new()
	typo.variables = {"hp": {"type": "int", "default": 1, "exported": true, "attributes": {"on_changed": "_no_such_fn"}}}
	typo.functions.append(notify_fn)
	all_passed = _check("unknown on_changed target warns",
		str(SheetCompiler.compile(typo, "user://eventsheets_t2typo.gd").get("warnings")).contains("_no_such_fn"), true) and all_passed

	# Hook-collision guard: a raw block also defining _validate_property warns.
	var collide: EventSheetResource = EventSheetResource.new()
	collide.variables = {"a": {"type": "float", "default": 0.0, "exported": true, "attributes": {"show_if": "a"}}}
	var hook_block: RawCodeRow = RawCodeRow.new()
	hook_block.code = "func _validate_property(property: Dictionary) -> void:
	pass"
	collide.events.append(hook_block)
	all_passed = _check("duplicate _validate_property raw block warns",
		str(SheetCompiler.compile(collide, "user://eventsheets_t2dup.gd").get("warnings")).contains("_validate_property"), true) and all_passed

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] inspector_attributes_test: %s" % label)
		return true
	print("[FAIL] inspector_attributes_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
