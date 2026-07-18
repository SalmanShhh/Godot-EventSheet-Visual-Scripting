# Pack-builder shared library (no class_name: tool scripts stay out of the global namespace). save_pack
# compiles the in-memory sheet straight to a banner-less .gd - the .gd IS the pack (the editable event
# sheet AND the runtime script), with no .tres companion. audit_addons enforces no-drift: every shipped
# .gd must re-import and recompile to itself byte-for-byte.
@tool

# Lives WITH the shipped packs (eventsheet_addons/), not the editor addon (addons/eventsheet/), so a
# generated pack stays self-contained - removing the editor never dangles its @icon (clean_removal_test).
const BEHAVIOR_ICON := "res://eventsheet_addons/behavior.svg"


static func save_pack(sheet: EventSheetResource, base_path: String, icon_path: String = BEHAVIOR_ICON) -> bool:
	# The whole pack pipeline (icon auto-detect, the four byte-gated de-coding lifts, stable
	# row uids, banner-less .gd-is-the-pack compile) lives on the PUBLIC API now -
	# EventSheets.publish_pack - so the bundled builders, the dock's Export Addon flow, and
	# third-party tooling all publish through one seam and can never drift apart. This wrapper
	# only adds the builder conveniences: the shared behaviour icon as the default fallback,
	# and the build-log line.
	# Every bundled pack ships versioned (builders may set their own; 1.0.0 is the floor) -
	# the Addon Pack banner chip shows it and future update tooling compares against it.
	if sheet.addon_version.strip_edges().is_empty():
		sheet.addon_version = "1.0.0"
	var compile_result: Dictionary = EventSheets.publish_pack(sheet, base_path, icon_path)
	if not bool(compile_result.get("success", false)):
		push_error("Failed to compile %s.gd: %s" % [base_path, compile_result.get("errors")])
		return false
	print("[build_sample_behaviors] built %s (.gd), warnings: %s" % [base_path.get_file(), compile_result.get("warnings")])
	return true


## Shared shape for the spring/tween builders: one exposed-as-ACE function.
static func append_function(sheet: EventSheetResource, function_name: String, display_name: String, category: String, description: String, params: Array, body: String) -> void:
	var event_function: EventFunction = EventFunction.new()
	event_function.function_name = function_name
	event_function.expose_as_ace = true
	event_function.ace_display_name = display_name
	event_function.ace_category = category
	event_function.description = description
	for param_pair: Array in params:
		var parameter: ACEParam = ACEParam.new()
		parameter.id = str(param_pair[0])
		parameter.type_name = str(param_pair[1])
		event_function.params.append(parameter)
	var body_row: RawCodeRow = RawCodeRow.new()
	body_row.code = body
	event_function.events.append(body_row)
	sheet.functions.append(event_function)


## Declares a REQUIRED resource slot on a behavior pack - the data-driven-config helper. Adds an
## exported var (a Resource slot the user drags a .tres onto) marked `required`, so the Inspector shows a
## "required" warning on the field while it is empty - the "you forgot to attach it" safety net a
## beginner needs, with no boilerplate. (This is the plugin's own required-field marker, the same one the
## EnemyStats Custom Resource showcase uses for its portrait; it is the intended way to flag a missing
## reference in the Inspector, and it stays warning-free because the compiler owns the config-warnings
## hook.) The slot is typed Resource (generic) on purpose: a pack cannot reference another pack's class
## name at build time, and any resource - including your Custom Resource .tres - is a Resource.
## `display_name` seeds the tooltip; call it once per resource.
static func require_resource(sheet: EventSheetResource, var_name: String, display_name: String, description: String) -> void:
	sheet.variables[var_name] = {"type": "Resource", "default": null, "exported": true,
		"attributes": {"required": true, "tooltip": "%s. %s" % [display_name, description]}}


## _append_function, but returning the function for return-type tweaks.
static func exposed_function(function_name: String, display_name: String, category: String, description: String, params: Array, body: String) -> EventFunction:
	var event_function: EventFunction = EventFunction.new()
	event_function.function_name = function_name
	event_function.expose_as_ace = true
	event_function.ace_display_name = display_name
	event_function.ace_category = category
	event_function.description = description
	for param_pair: Array in params:
		var parameter: ACEParam = ACEParam.new()
		parameter.id = str(param_pair[0])
		parameter.type_name = str(param_pair[1])
		event_function.params.append(parameter)
	var body_row: RawCodeRow = RawCodeRow.new()
	body_row.code = body
	event_function.events.append(body_row)
	return event_function


## Appends a bool-returning exposed function - a Condition in the picker. (Same helper the
## currency_ledger builder grew locally; hoisted here so every data pack shares one shape.)
static func condition(sheet: EventSheetResource, function_name: String, display_name: String, category: String, description: String, params: Array, body: String) -> void:
	var fn: EventFunction = exposed_function(function_name, display_name, category, description, params, body)
	fn.return_type = TYPE_BOOL
	sheet.functions.append(fn)


## Marks the named exposed functions FEATURED - the pack's hero verbs, starred + bold at the
## top of their picker section. Call once at the end of a builder with the 1-3 verbs a new
## user should meet first: Lib.feature_verbs(sheet, ["take_damage", "heal"]).
static func feature_verbs(sheet: EventSheetResource, function_names: Array) -> void:
	var missing: Array = function_names.duplicate()
	for function_resource: Resource in sheet.functions:
		if function_resource is EventFunction and function_names.has((function_resource as EventFunction).function_name):
			(function_resource as EventFunction).featured = true
			missing.erase((function_resource as EventFunction).function_name)
	if not missing.is_empty():
		push_warning("feature_verbs: no function named %s on this sheet (typo?)" % str(missing))


## Appends a value-returning exposed function - an Expression - with the given return type
## (TYPE_FLOAT / TYPE_INT / TYPE_STRING / TYPE_BOOL / TYPE_ARRAY / TYPE_VECTOR2 ...).
static func number(sheet: EventSheetResource, function_name: String, display_name: String, category: String, description: String, params: Array, body: String, ret: int) -> void:
	var fn: EventFunction = exposed_function(function_name, display_name, category, description, params, body)
	fn.return_type = ret
	sheet.functions.append(fn)
