# Godot EventSheets - the public API's shape, pinned.
#
# THE CONTRACT: every public method of `EventSheets` and of the Custom Block API (the block kind base
# class, the block registry, the simple-kind builder) is a compatibility promise. A behaviour test only
# notices a moved shape when it happens to call that method, so this test reflects over the classes
# themselves and compares each method's signature - name, argument names, argument types, defaults,
# return type, static or not - with the table below. A method that was added, removed, renamed or
# reshaped fails with the method NAMED, and the table is changed on purpose in the same commit as the
# shape, which is the only way a public shape should ever move. Private names (a leading underscore)
# are not part of the promise and are not listed.
#
# To print the table the code has today, in the form pasted below, run this file's `dump_table()` from
# a throwaway script: `print(preload("res://tests/api_surface_test.gd").dump_table())`.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "api_surface_test"

## The classes whose public methods are pinned, in the order the table lists them.
const CLASS_NAMES: Array = ["EventSheets", "EventSheetBlockKind", "EventSheetBlockRegistry", "EventSheetSimpleBlockKind"]

## The block kind base class's public variables, which an author sets in `_init`.
const KIND_VARIABLES: Array = [
	"kind_id: String",
	"title: String",
	"category: String",
]

## One line per method: `[static ]name(arg: Type[ = default], ...) -> Return`, sorted by name.
const TABLE: Dictionary = {
	"EventSheets": [
		"static add_behaviour_from_library(pack_dir: String) -> bool",
		"static add_field_cell(row: EventRowData, label: String, text: String, metadata: Dictionary = {}) -> EventRowData",
		"static add_save_support(script_path: String) -> String",
		"static add_trigger_for_signal(signal_name: String, args_signature: String = \"\") -> bool",
		"static addon_guide_for_pack(pack_dir: String) -> String",
		"static addon_guide_for_provider(provider_id: String) -> String",
		"static addon_guide_name(pack_dir: String) -> String",
		"static addon_guide_skeleton(script_path: String) -> String",
		"static addon_guide_target(pack_dir: String, help_url: String = \"\") -> String",
		"static addon_pack_directory(provider_id: String) -> String",
		"static all_verbs() -> Array[ACEDefinition]",
		"static asset_drop_builder_for(extension: String) -> Callable",
		"static attach_completions(field: LineEdit, field_kind: String) -> EventSheetCompletionPopup",
		"static attach_validator(sheet: EventSheetResource, variable_name: String) -> String",
		"static available_languages() -> PackedStringArray",
		"static bake_overrides(script_path: String, class_id: String) -> Dictionary",
		"static build_caption_row(text: String, indent: int = 0, row_uid: String = \"\", accent: Color = Color(0, 0, 0, 0)) -> EventRowData",
		"static build_condition_action_row(condition_text: String, action_lines: PackedStringArray, indent: int = 0, source: Resource = null) -> EventRowData",
		"static build_inspector_preview(variable_name: String, type_name: String, default_text: String, attributes: Dictionary, exported: bool = true, constant: bool = false) -> Control",
		"static build_signal_trigger_event(signal_name: String, args_signature: String = \"\") -> EventRow",
		"static builtin_action(ace_id: String, params: Dictionary) -> ACEAction",
		"static card_schema(schema_name: String) -> Dictionary",
		"static card_schema_from_aces(aces: Array, fallback_category: String = \"\") -> Dictionary",
		"static class_vocabulary(target_class: String) -> Array[ACEDefinition]",
		"static collection_decl(variable_name: String, entries: Array, dictionary: bool = true) -> CollectionDeclRow",
		"static combo_options(source: Variant) -> Array",
		"static comparison_glyph(operator: String) -> String",
		"static comparison_options(equal_token: String = \"==\") -> Array",
		"static compile(sheet: EventSheetResource, output_path: String = \"\") -> Dictionary",
		"static completions_for(sheet: EventSheetResource, field_kind: String, prefix: String = \"\") -> Array[Dictionary]",
		"static curate_provider(script_path: String, edits: Array) -> Dictionary",
		"static current_sheet() -> EventSheetResource",
		"static describe_inspector(type_name: String, attributes: Dictionary, exported: bool = true, constant: bool = false) -> String",
		"static distinct_values_for_hint(sheet: EventSheetResource, hint: String) -> PackedStringArray",
		"static doc_url(relative_path: String, anchor: String = \"\") -> String",
		"static docs_version() -> String",
		"static doctor() -> Dictionary",
		"static echo(sheet: EventSheetResource) -> Dictionary",
		"static edit(label: String, mutation: Callable) -> bool",
		"static editor_gizmo_drawer_for(script_path: String) -> Callable",
		"static editor_preview_sampler_for(_script_path: String) -> Callable",
		"static exclude_class(class_id: String, excluded: bool = true) -> void",
		"static find_ace(provider_id: String, ace_id: String) -> ACEDefinition",
		"static focus_sheet() -> bool",
		"static group_declaration_lines(sheet: EventSheetResource) -> Dictionary",
		"static handled_asset_extensions() -> PackedStringArray",
		"static has_save_support(target: Variant) -> bool",
		"static insert_snippet(text: String, label: String = \"Insert Snippet\", as_example: bool = false) -> bool",
		"static inspector_preview_renderer_for(script_path: String) -> Callable",
		"static install_pack_effect(shipped_shader: String, into_folder: String = \"res://effects\") -> Dictionary",
		"static keep_old_verb_working(script_path: String, old_member: String, new_member: String, message: String = \"\") -> Dictionary",
		"static mark_language_block(row: EventRowData) -> EventRowData",
		"static message_annotation(original: String, answers: Dictionary) -> String",
		"static migration_report(read_every_script: bool = false) -> Array[Dictionary]",
		"static module_guide_name(module_or_category: String) -> String",
		"static module_guide_target(module_or_category: String) -> String",
		"static module_guide_unit(module_or_category: String) -> String",
		"static module_guide_units() -> PackedStringArray",
		"static moment_block(moment_name: String, steps: Array = []) -> MomentBlockRow",
		"static networking_coverage(sheet: EventSheetResource) -> Dictionary",
		"static networking_coverage_text(sheet: EventSheetResource) -> String",
		"static new_sheet(config: Dictionary = {}) -> EventSheetResource",
		"static on_sheet_compiled(callback: Callable) -> void",
		"static on_sheet_opened(callback: Callable) -> void",
		"static on_sheet_saved(callback: Callable) -> void",
		"static open_addon_guide(provider_id: String) -> bool",
		"static open_docs(doc_id: String = \"\", anchor: String = \"\") -> bool",
		"static open_gd_as_sheet(source: String) -> EventSheetResource",
		"static open_online_doc(relative_path: String, anchor: String = \"\") -> bool",
		"static open_sheet(path: String) -> bool",
		"static opposite_operator(operator: String) -> String",
		"static override_verb(provider_id: String, ace_id: String, edits: Dictionary) -> void",
		"static pack_providers(pack_dir: String) -> PackedStringArray",
		"static pack_shipped_assets(pack_script_path: String) -> Dictionary",
		"static palette_commands() -> Array[Dictionary]",
		"static param_commit_validator_for(hint: String) -> Callable",
		"static param_editor_for(tag: String) -> Callable",
		"static param_help_for(hint: String) -> String",
		"static param_spec(config: Dictionary) -> Dictionary",
		"static persistable_fields(script_path: String) -> Array[Dictionary]",
		"static preference_builders() -> Array[Callable]",
		"static preload_block_for(asset_path: String) -> CustomBlockRow",
		"static preview_behaviors() -> bool",
		"static preview_save(data: Dictionary, format: String, key: String = \"state\") -> String",
		"static project_classes() -> Array",
		"static project_scripts() -> PackedStringArray",
		"static project_uses_of(definition: ACEDefinition) -> Array[Dictionary]",
		"static provider_verbs(provider_id: String) -> Array[ACEDefinition]",
		"static publish_pack(sheet: EventSheetResource, base_path: String, icon_path: String = \"\") -> Dictionary",
		"static publish_pack_version(script_path: String, bump: String, note: String) -> Dictionary",
		"static pulse_control(control_label: String) -> bool",
		"static refresh() -> void",
		"static register_asset_drop_handler(extensions: PackedStringArray, build: Callable, description: String = \"\") -> void",
		"static register_block_kind(kind: EventSheetBlockKind) -> void",
		"static register_card_schema(schema_name: String, provider: Callable) -> void",
		"static register_completion_source(field_kind: String, source: Callable) -> void",
		"static register_doctor_check(check_id: String, check: Callable) -> void",
		"static register_editor_gizmo(script_path: String, drawer: Callable) -> void",
		"static register_editor_preview(_script_path: String, _sampler: Callable) -> void",
		"static register_inspector_look(path: String) -> bool",
		"static register_inspector_preview(script_path: String, renderer: Callable) -> void",
		"static register_palette_command(title: String, action: Callable, category: String = \"\") -> void",
		"static register_param_commit_validator(hint: String, validator: Callable) -> void",
		"static register_param_editor(tag: String, factory: Callable) -> void",
		"static register_param_help(hint: String, paragraph: String) -> void",
		"static register_preference(builder: Callable) -> void",
		"static register_provider_script(script_path: String) -> bool",
		"static use_script_in_sheets(script_path: String) -> bool",
		"static register_quick_add_synonyms(synonyms: Dictionary) -> void",
		"static register_row_menu_item(label: String, filter: Callable, action: Callable) -> void",
		"static register_section_description(section_name: String, blurb: String) -> void",
		"static register_simple_ace(config: Dictionary) -> ACEDefinition",
		"static register_starter(config: Dictionary) -> void",
		"static register_toggle_icon_provider(provider_name: String, renderer: Callable) -> void",
		"static register_tour(tour_name: String, steps: Array[Dictionary]) -> void",
		"static register_translation_file(path: String) -> bool",
		"static registered_starters() -> Array[Dictionary]",
		"static report_runtime_error(message: String, script_path: String, line: int = 0) -> Dictionary",
		"static resource_grid(columns: Array, options: Dictionary = {}) -> Dictionary",
		"static reveal_project_row(sheet_path: String, line: int) -> bool",
		"static reveal_verb_row(provider_id: String, ace_id: String, index: int = 0) -> bool",
		"static round_trip_failure(source: String) -> String",
		"static round_trips(source: String) -> bool",
		"static row_code_line(row: Resource, sheet: EventSheetResource = null) -> String",
		"static row_menu_items_for(resource: Resource) -> Array[Dictionary]",
		"static save_capable_scripts() -> PackedStringArray",
		"static save_keys_used(source: String) -> Dictionary",
		"static save_state_code(fields: Array) -> String",
		"static scene_lights(sheet: EventSheetResource) -> Array[Dictionary]",
		"static scenes_using_resource(resource_path: String, own_scene: String = \"\") -> PackedStringArray",
		"static scripts_calling(function_name: String, own_script: String = \"\") -> PackedStringArray",
		"static search_docs(query: String, limit: int = 25) -> Array[Dictionary]",
		"static set_editor_language(locale: String) -> void",
		"static set_status(text: String, is_error: bool = false) -> void",
		"static sheet_messages(sheet: EventSheetResource) -> Array[Dictionary]",
		"static sheet_variables(sheet: EventSheetResource) -> Array[Dictionary]",
		"static sheet_visibility_filters(sheet: EventSheetResource) -> Array[Dictionary]",
		"static signals_of(node: Object) -> Array[Dictionary]",
		"static simple_ace(config: Dictionary) -> ACEDefinition",
		"static simple_aces() -> Array[ACEDefinition]",
		"static simple_block_kind(config: Dictionary) -> EventSheetBlockKind",
		"static spawners_of(sheet: EventSheetResource) -> Array[Dictionary]",
		"static stabilize_row_uids(sheet: EventSheetResource) -> void",
		"static start_tour(steps: Array[Dictionary]) -> bool",
		"static synced_properties(sheet: EventSheetResource) -> Array[Dictionary]",
		"static table_from_file(path: String, separator: String = \",\") -> Array",
		"static table_from_text(text: String, separator: String = \",\") -> Array",
		"static timeline(steps: Array = []) -> TimelineRow",
		"static toggle_icon_provider_for(provider_name: String) -> Callable",
		"static translate(text: String) -> String",
		"static unregister_card_schema(schema_name: String) -> void",
		"static unregister_completion_source(field_kind: String) -> void",
		"static unregister_doctor_check(check_id: String) -> void",
		"static unregister_inspector_preview(script_path: String) -> void",
		"static unregister_palette_command(title: String, category: String = \"\") -> void",
		"static unregister_row_menu_item(label: String) -> void",
		"static unregister_toggle_icon_provider(provider_name: String) -> void",
		"static user_docs_dir() -> String",
		"static values_for_hint(sheet: EventSheetResource, hint: String) -> Array[Dictionary]",
		"static variable_code(variable: LocalVariable) -> String",
		"static variable_owner(variables: Array[Dictionary], variable_name: String) -> String",
		"static variable_sentence(entry: Dictionary) -> String",
		"static verify_pack(pack_gd_path: String) -> Dictionary",
		"static off_sheet_compiled(callback: Callable) -> void",
		"static off_sheet_opened(callback: Callable) -> void",
		"static off_sheet_saved(callback: Callable) -> void",
		"static unregister_asset_drop_handler(extensions: PackedStringArray) -> void",
		"static unregister_editor_gizmo(script_path: String) -> void",
		"static unregister_preference(builder: Callable) -> void",
		"static unregister_quick_add_synonyms(keys: PackedStringArray) -> void",
		"static unregister_section_description(section_name: String) -> void",
		"static unregister_simple_ace(id: String, provider_id: String = \"Extension\") -> void",
		"static unregister_starter(label: String) -> void",
		"static add_provider_to_sheet(script_path: String) -> bool",
		"static try_register_block_kind(kind: EventSheetBlockKind) -> String",
		"static unregister_block_kind(kind_id: String) -> bool",
	],
	"EventSheetBlockKind": [
		"addable() -> bool",
		"display_spans(_entry: Resource) -> Array[Dictionary]",
		"edit(_dock: Control, _block: Resource) -> bool",
		"emit(_block: CustomBlockRow) -> PackedStringArray",
		"emit_lines(entry: Resource) -> PackedStringArray",
		"fields() -> Array[Dictionary]",
		"handles(_entry: Resource) -> bool",
		"hover_text(_entry: Resource) -> String",
		"lift(_lines: PackedStringArray, _i: int) -> Dictionary",
		"row_style(_entry: Resource) -> String",
		"source_map_kind() -> String",
		"style(_block: CustomBlockRow) -> Dictionary",
		"summary(_block: CustomBlockRow) -> String",
		"summary_for(entry: Resource) -> String",
		"validate(_block: CustomBlockRow) -> String",
		"verified_claim(recovered_fields: Dictionary, source_lines: PackedStringArray, i: int, consumed: int) -> Dictionary",
		"writes_nothing(_block: CustomBlockRow) -> bool",
	],
	"EventSheetBlockRegistry": [
		"static addable_kinds() -> Array[EventSheetBlockKind]",
		"static all_kinds() -> Array[EventSheetBlockKind]",
		"static get_kind(kind_id: String) -> EventSheetBlockKind",
		"static kind_for(entry: Resource) -> EventSheetBlockKind",
		"static register_kind(kind: EventSheetBlockKind) -> void",
		"static rescan_pack_kinds() -> void",
		"static split_params_top_level(params_text: String) -> PackedStringArray",
		"static unregister_kind(kind_id: String) -> bool",
	],
	"EventSheetSimpleBlockKind": [
		"addable() -> bool",
		"display_spans(_entry: Resource) -> Array[Dictionary]",
		"edit(_dock: Control, _block: Resource) -> bool",
		"emit(_block: CustomBlockRow) -> PackedStringArray",
		"emit(block: CustomBlockRow) -> PackedStringArray",
		"emit_lines(entry: Resource) -> PackedStringArray",
		"fields() -> Array[Dictionary]",
		"fields() -> Array[Dictionary]",
		"handles(_entry: Resource) -> bool",
		"hover_text(_entry: Resource) -> String",
		"lift(_lines: PackedStringArray, _i: int) -> Dictionary",
		"lift(lines: PackedStringArray, i: int) -> Dictionary",
		"row_style(_entry: Resource) -> String",
		"source_map_kind() -> String",
		"style(_block: CustomBlockRow) -> Dictionary",
		"summary(_block: CustomBlockRow) -> String",
		"summary(block: CustomBlockRow) -> String",
		"summary_for(entry: Resource) -> String",
		"validate(_block: CustomBlockRow) -> String",
		"verified_claim(recovered_fields: Dictionary, source_lines: PackedStringArray, i: int, consumed: int) -> Dictionary",
		"writes_nothing(_block: CustomBlockRow) -> bool",
	],
}


static func run() -> bool:
	var ok: bool = true
	for class_name_text: String in CLASS_NAMES:
		ok = _same_surface(class_name_text) and ok
	ok = _same_variables() and ok
	ok = _built_in_kind_ids_are_frozen() and ok
	ok = _result_keys_are_frozen() and ok
	return ok


## The class's script, found by name through the project's global class list.
static func _script_of(class_name_text: String) -> Script:
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if str(entry.get("class", "")) == class_name_text:
			return load(str(entry.get("path", ""))) as Script
	return null


## Every public method of the class as its signature line, sorted by name.
static func signatures_of(class_name_text: String) -> PackedStringArray:
	var script: Script = _script_of(class_name_text)
	var lines: Array = []
	if script == null:
		return PackedStringArray()
	for method: Dictionary in script.get_script_method_list():
		var method_name: String = str(method.get("name", ""))
		if method_name.begins_with("_") or method_name.begins_with("@"):
			continue
		lines.append(_signature(method, script.source_code))
	lines.sort()
	return PackedStringArray(lines)


## `source` is the script's own text: Godot's method list reports a `{}` or `[]` default as null, so a
## null default is read back from the `static func name(` line the author wrote.
static func _signature(method: Dictionary, source: String = "") -> String:
	var arguments: Array = method.get("args", [])
	var defaults: Array = method.get("default_args", [])
	var first_default: int = arguments.size() - defaults.size()
	var parts: PackedStringArray = PackedStringArray()
	for index: int in range(arguments.size()):
		var argument: Dictionary = arguments[index]
		var text: String = "%s: %s" % [str(argument.get("name", "")), _type_text(argument)]
		if index >= first_default:
			var default_text: String = var_to_str(defaults[index - first_default]).replace("\n", " ")
			if default_text == "null":
				default_text = _default_in_source(source, str(method.get("name", "")), str(argument.get("name", "")), default_text)
			text += " = " + default_text
		parts.append(text)
	var returned: Dictionary = method.get("return", {})
	var return_text: String = _type_text(returned)
	if int(returned.get("type", TYPE_NIL)) == TYPE_NIL and (int(returned.get("usage", 0)) & PROPERTY_USAGE_NIL_IS_VARIANT) == 0:
		return_text = "void"
	var is_static: bool = (int(method.get("flags", 0)) & METHOD_FLAG_STATIC) != 0
	return "%s%s(%s) -> %s" % ["static " if is_static else "", str(method.get("name", "")), ", ".join(parts), return_text]


## The default written after `argument_name` in the declaration line of `function_name`, or `fallback`.
static func _default_in_source(source: String, function_name: String, argument_name: String, fallback: String) -> String:
	for line: String in source.split("\n"):
		var declaration: String = line.strip_edges()
		if not (declaration.begins_with("static func %s(" % function_name) or declaration.begins_with("func %s(" % function_name)):
			continue
		var expression: RegEx = RegEx.create_from_string("[(,]\\s*%s\\s*:[^=,)]*=\\s*(\\{\\}|\\[\\]|null)" % argument_name)
		var found: RegExMatch = expression.search(declaration)
		return found.get_string(1) if found != null else fallback
	return fallback


static func _type_text(info: Dictionary) -> String:
	var kind: int = int(info.get("type", TYPE_NIL))
	if kind == TYPE_NIL:
		return "Variant"
	if kind == TYPE_OBJECT:
		var named: String = str(info.get("class_name", ""))
		return named if not named.is_empty() else "Object"
	if kind == TYPE_ARRAY and int(info.get("hint", 0)) == PROPERTY_HINT_ARRAY_TYPE:
		return "Array[%s]" % str(info.get("hint_string", ""))
	return type_string(kind)


static func _same_surface(class_name_text: String) -> bool:
	var ok: bool = true
	var actual: PackedStringArray = signatures_of(class_name_text)
	var expected: PackedStringArray = PackedStringArray(TABLE.get(class_name_text, []))
	var expected_by_name: Dictionary = {}
	for line: String in expected:
		expected_by_name[_name_of(line)] = line
	var actual_by_name: Dictionary = {}
	for line: String in actual:
		actual_by_name[_name_of(line)] = line
	ok = SUPPORT.check(P, "%s is found and reflects" % class_name_text, actual.is_empty(), false) and ok
	for method_name: Variant in expected_by_name:
		if not actual_by_name.has(method_name):
			ok = SUPPORT.check(P, "%s.%s is still there" % [class_name_text, method_name], "missing", expected_by_name[method_name]) and ok
		elif actual_by_name[method_name] != expected_by_name[method_name]:
			ok = SUPPORT.check(P, "%s.%s keeps its shape" % [class_name_text, method_name], actual_by_name[method_name], expected_by_name[method_name]) and ok
	for method_name: Variant in actual_by_name:
		if not expected_by_name.has(method_name):
			ok = SUPPORT.check(P, "%s.%s is in the table (a new public method must be added on purpose)" % [class_name_text, method_name], actual_by_name[method_name], "not in the table") and ok
	if ok:
		print("[PASS] %s: %s keeps all %d public signatures" % [P, class_name_text, expected.size()])
	return ok


static func _name_of(line: String) -> String:
	var head: String = line.get_slice("(", 0)
	return head.trim_prefix("static ")


## The text of the table the code holds today, ready to paste into TABLE.
static func dump_table() -> String:
	var out: PackedStringArray = PackedStringArray()
	for class_name_text: String in CLASS_NAMES:
		out.append("\t\"%s\": [" % class_name_text)
		for line: String in signatures_of(class_name_text):
			out.append("\t\t\"%s\"," % line.replace("\"", "\\\""))
		out.append("\t],")
	return "\n".join(out)


static func _same_variables() -> bool:
	var script: Script = _script_of("EventSheetBlockKind")
	var actual: Array = []
	for property: Dictionary in script.get_script_property_list():
		var property_name: String = str(property.get("name", ""))
		if property_name.begins_with("_") or (int(property.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		actual.append("%s: %s" % [property_name, _type_text(property)])
	return SUPPORT.check(P, "the block kind base class keeps its public variables", actual, KIND_VARIABLES)


## The five built-in kind ids are as frozen as ace_ids: nothing may rename one.
static func _built_in_kind_ids_are_frozen() -> bool:
	var ids: Array = []
	for kind: EventSheetBlockKind in EventSheetBlockRegistry.all_kinds():
		if EventSheetBlockRegistry._built_in_ids.has(kind.kind_id):
			ids.append(kind.kind_id)
	ids.sort()
	return SUPPORT.check(P, "the built-in block kind ids", ids, ["enum", "moment", "preload", "region", "signal"])


## The keys of the result Dictionaries a caller reads. Extra keys may be added; none may go.
static func _result_keys_are_frozen() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = EventSheets.new_sheet()
	var compiled: Dictionary = EventSheets.echo(sheet)
	for key: String in ["success", "errors", "warnings", "output", "source_map"]:
		ok = SUPPORT.check(P, "compile and echo results keep '%s'" % key, compiled.has(key), true) and ok
	return ok
