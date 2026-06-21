# EventForge — Built-in ACE registry
# AUTO-DISCOVERS the per-vocabulary modules in registration/modules/: any script there that exposes
# `static func get_descriptors() -> Array[ACEDescriptor]` is loaded and concatenated automatically, so
# adding a module is just dropping a file (no edit here). See ace_factory.gd for the module contract;
# ace_ids/templates are API (compatibility covenant: hide with @ace_hidden, never rename).
@tool
extends RefCounted
class_name EventForgeBuiltinACEs

const COMPARISON_OPERATORS: Array[String] = EventForgeACEFactory.COMPARISON_OPERATORS
const MODULES_DIR := "res://addons/eventforge/registration/modules/"

## Every built-in descriptor, auto-discovered from registration/modules/. Drop a module file there
## (a script with `static func get_descriptors() -> Array[ACEDescriptor]`) and its ACEs register on
## the next load — no wiring here. Files load in a stable sorted order with the generic helper_aces
## module forced LAST, so its catch-all templates never shadow a specific ACE in the reverse-lifter.
## (Order otherwise does not affect compiled output: each ACE compiles independently, the picker
## groups by category, and the lifter sorts entries by specificity.)
static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	for module_file: String in _module_files():
		var script: GDScript = load(MODULES_DIR + module_file)
		if script == null or not _has_get_descriptors(script):
			continue
		var module_descriptors: Variant = script.call("get_descriptors")
		if module_descriptors is Array:
			for entry: Variant in module_descriptors:
				if entry is ACEDescriptor:
					descriptors.append(entry)
	return descriptors

## The module .gd files in a stable order: sorted alphabetically, with helper_aces.gd appended last.
static func _module_files() -> PackedStringArray:
	var files: PackedStringArray = PackedStringArray()
	var helpers: PackedStringArray = PackedStringArray()
	for file: String in DirAccess.get_files_at(MODULES_DIR):
		if not file.ends_with(".gd"):
			continue  # skips the .gd.uid sidecars too
		if file == "helper_aces.gd":
			helpers.append(file)
		else:
			files.append(file)
	files.sort()
	files.append_array(helpers)
	return files

## True when the loaded script declares a get_descriptors method (the module contract).
static func _has_get_descriptors(script: GDScript) -> bool:
	for method_info: Dictionary in script.get_script_method_list():
		if str(method_info.get("name", "")) == "get_descriptors":
			return true
	return false

# ── Legacy helper API (kept for external callers; the modules use the factory) ──

static func _input_action_options() -> Array[String]:
	return EventForgeACEFactory.input_action_options()

static func _default_input_action() -> String:
	return EventForgeACEFactory.default_input_action()

static func _make_descriptor(provider_id: String, ace_id: String, display_name: String, ace_type: int, codegen_template: String, signal_name: String = "", params: Array[ACEParam] = [], category: String = "", display_text: String = "", node_type: String = "") -> ACEDescriptor:
	return EventForgeACEFactory.make_descriptor(provider_id, ace_id, display_name, ace_type, codegen_template, signal_name, params, category, display_text, node_type)

static func _make_param(param_id: String, type_name: String, default_value: Variant = "", display_name: String = "", description: String = "", hint: String = "", options: Array[String] = []) -> ACEParam:
	return EventForgeACEFactory.make_param(param_id, type_name, default_value, display_name, description, hint, options)
