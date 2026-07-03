# Pack-builder shared library (no class_name: tool scripts stay out of the global namespace). save_pack
# compiles the in-memory sheet straight to a banner-less .gd - the .gd IS the pack (the editable event
# sheet AND the runtime script), with no .tres companion. audit_addons enforces no-drift: every shipped
# .gd must re-import and recompile to itself byte-for-byte.
@tool

# Lives WITH the shipped packs (eventsheet_addons/), not the editor addon (addons/eventsheet/), so a
# generated pack stays self-contained - removing the editor never dangles its @icon (clean_removal_test).
const BEHAVIOR_ICON := "res://eventsheet_addons/behavior.svg"

static func save_pack(sheet: EventSheetResource, base_path: String, icon_path: String = BEHAVIOR_ICON) -> bool:
	# Behaviour icon: every pack shows a recognizable EventForge behaviour icon in Godot's Create New
	# Node dialog (emitted as `@icon` before class_name) and the sheet banner. A builder can pass its
	# own icon, or set sheet.custom_class_icon before calling - an already-set icon is never overwritten.
	if not icon_path.strip_edges().is_empty() and sheet.custom_class_icon.strip_edges().is_empty():
		sheet.custom_class_icon = icon_path
	# Code-free by default: reverse-lift each function's RawCode body into ACE rows where it recompiles
	# byte-identically (per-function gated). The pack ships the SAME GDScript, but the .gd reads as
	# events - algorithmic kernels (spring/sine/physics) become Set/Add/Set-Property rows, not code
	# blocks. Bodies that can't round-trip (inner classes, exotic flow) keep their RawCode. Deterministic.
	EventSheetACELifter.lift_function_bodies(sheet)
	# Same de-coding for EVENT bodies (a behaviour's OnProcess/OnPhysicsProcess tick): a single
	# verbatim RawCode block becomes if/else/elseif condition rows + action rows (folded into the
	# event's sub_events), kept only where the sheet still recompiles byte-identically (per-event
	# gated). This is what makes a behaviour read like an event sheet, not hand-written code.
	EventSheetACELifter.lift_event_bodies(sheet)
	# Trigger signals authored as `## @ace_trigger … signal X` code blocks become SignalRow rows
	# (keyword-badged Trigger rows that feed the On Signal / Emit Signal pickers). The declarations
	# relocate to the compiler's signal prelude - behaviour-identical, so the regenerated .gd stays
	# self-consistent (drift=0); only the cosmetic position of the signal lines changes.
	EventSheetACELifter.lift_signal_declarations(sheet, false)
	# Helper functions authored as a class-level code block (`## @ace_condition … func is_moving()`,
	# private `func _perform_jump()`) become EventFunction rows - exposed ones publish as ACEs, private
	# ones stay un-exposed. Exposed functions gain the sheet's `@ace_icon` (the published condition/
	# expression shows the behaviour icon in the picker), a deliberate cosmetic change to the generated
	# .gd; drift stays 0 because the .gd regenerates deterministically (re-import + recompile is identity).
	EventSheetACELifter.lift_function_declarations(sheet, false)
	# Stamp DETERMINISTIC row UIDs before saving. EventRow/EventGroup otherwise mint a random
	# uid in _init(), so every regeneration churns the .gd of EVERY pack - exploding git
	# diffs even for packs that did not change. Deriving the uid from the row's structural
	# path makes an unchanged pack rebuild byte-for-byte identical (version-control friendly),
	# and gives each row a stable identity for diff/blame. Scoped to pack builds only - hand-
	# authored sheets keep the persistent uid assigned the first time the row was created.
	_assign_stable_uids(sheet)
	DirAccess.make_dir_recursive_absolute(base_path.get_base_dir())
	# The .gd IS the pack - no .tres companion. Compile the in-memory sheet straight to a banner-less .gd
	# (omit_generated_banner=true) that doubles as the editable event sheet AND the runtime script;
	# opening it re-derives the rows losslessly. Do NOT set external_source_path here - this build uses
	# the normal synthesizing compile (it emits class_name/extends/signals/functions from the sheet);
	# the order-preserving _compile_external path is only for a sheet opened FROM an existing .gd.
	var compile_result: Dictionary = SheetCompiler.compile(sheet, base_path + ".gd", true)
	if not bool(compile_result.get("success", false)):
		push_error("Failed to compile %s.gd: %s" % [base_path, compile_result.get("errors")])
		return false
	print("[build_sample_behaviors] built %s (.gd), warnings: %s" % [base_path.get_file(), compile_result.get("warnings")])
	return true

## Walks the sheet and assigns each EventRow/EventGroup a uid derived from its structural
## path, so the same builder always produces the same uids (byte-stable regeneration).
static func _assign_stable_uids(sheet: EventSheetResource) -> void:
	var class_seed: String = sheet.custom_class_name if not sheet.custom_class_name.is_empty() else "sheet"
	_assign_uids_in_list(sheet.events, class_seed + "/events")
	for function_resource: Variant in sheet.functions:
		if function_resource is EventFunction:
			_assign_uids_in_list((function_resource as EventFunction).events, class_seed + "/fn/" + (function_resource as EventFunction).function_name)

static func _assign_uids_in_list(rows: Array, path_prefix: String) -> void:
	var index: int = 0
	for row: Variant in rows:
		var row_path: String = "%s/%d" % [path_prefix, index]
		if row is EventRow:
			(row as EventRow).event_uid = _stable_uid(row_path)
			_assign_uids_in_list((row as EventRow).sub_events, row_path)
		elif row is EventGroup:
			(row as EventGroup).group_uid = _stable_uid(row_path)
			_assign_uids_in_list((row as EventGroup).events, row_path)
		index += 1

## A short, stable, hex uid (matches the 6-hex-char format EventRow mints) from a seed.
static func _stable_uid(seed_text: String) -> String:
	return seed_text.sha256_text().substr(0, 6)

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
