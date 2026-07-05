# Godot EventSheets - Project Doctor (one audit for the drift no single check sees)
#
# Unions the project-health checks into a single report, runnable four ways: the
# dock's Tools menu, the headless CLI (tools/project_doctor.gd), CI and the MCP
# server's run_doctor tool. Severities:
#   error   - a broken contract: a committed generated script drifted from what its
#             sheet compiles to today, or a sheet no longer compiles. CI fails on these.
#   warning - a wiring gap with a one-step fix: sheet never compiled, autoload sheet
#             not registered (or registered to a different script).
#   info    - advisory vocabulary hygiene: private variable never referenced, pack
#             published but unused, compiled sheet attached to no scene. Never fails CI.
# The doctor NEVER writes inside res:// - verification recompiles go to a user://
# scratch file and are compared as text (contrast tools/audit_addons.gd, which repairs
# pack outputs in place while reporting drift).
@tool
class_name EventSheetProjectDoctor
extends RefCounted

const SCRATCH_PATH := "user://eventsheets_doctor_scratch.gd"

## Extension checks registered through EventSheets.register_doctor_check: Array of
## {"id": String, "run": Callable}. They run after the built-ins in every runner
## (dock panel, CLI, CI, MCP) with the same contract as a built-in check.
static var _extension_checks: Array[Dictionary] = []


## Registers a project-health check. `check` receives (sheet_paths: PackedStringArray,
## findings: Array[Dictionary]) and appends findings shaped
## {"severity": "error"|"warning"|"info", "check": <id>, "path": ..., "message": ...}.
## Same contract as the built-ins: never write inside res://. Re-registering an id
## replaces the previous check, so plugin reloads never duplicate.
static func register_check(check_id: String, check: Callable) -> void:
	unregister_check(check_id)
	_extension_checks.append({"id": check_id, "run": check})


static func unregister_check(check_id: String) -> void:
	for index in range(_extension_checks.size() - 1, -1, -1):
		if str(_extension_checks[index].get("id", "")) == check_id:
			_extension_checks.remove_at(index)


## Full audit over every sheet in the project. Returns
## {findings: Array[Dictionary{severity, check, path, message}], errors, warnings, infos}.
static func run() -> Dictionary:
	var findings: Array[Dictionary] = []
	# Templates are blueprints: no generated output, no scene, no live vocabulary -
	# auditing them would only manufacture noise.
	var sheet_paths: PackedStringArray = EventSheetTemplates.non_template_sheets(EventSheetProjectFind.list_project_sheets())
	check_generated_outputs(sheet_paths, findings)
	check_debug_residue(sheet_paths, findings)
	check_autoload_registration(sheet_paths, findings)
	check_scene_attachment(sheet_paths, findings)
	check_unused_variables(sheet_paths, findings)
	check_duplicated_globals(sheet_paths, findings)
	check_fanout_god_sheets(sheet_paths, findings)
	check_unbounded_loops(sheet_paths, findings)
	check_coroutine_in_per_frame_trigger(sheet_paths, findings)
	check_unused_packs(sheet_paths, findings)
	check_shadowed_variables(sheet_paths, findings)
	check_untranslated_project(sheet_paths, findings)
	check_required_fields(sheet_paths, findings)
	check_vocabulary_doc(findings)
	# Extension checks (packs and plugins, via EventSheets.register_doctor_check) run
	# after the built-ins so their findings never reorder the established report.
	for entry: Dictionary in _extension_checks:
		var extension_check: Callable = entry.get("run") as Callable
		if extension_check.is_valid():
			extension_check.call(sheet_paths, findings)
	var counts: Dictionary = {"error": 0, "warning": 0, "info": 0}
	for finding: Dictionary in findings:
		var severity: String = str(finding.get("severity"))
		counts[severity] = int(counts.get(severity, 0)) + 1
	return {
		"findings": findings,
		"errors": int(counts["error"]),
		"warnings": int(counts["warning"]),
		"infos": int(counts["info"]),
	}


## The script a sheet is expected to pair with - the compiler's own resolution
## (existing <name>_generated.gd, else the pack builder's header-verified sibling
## <name>.gd, else the <name>_generated.gd a save WOULD create), so the doctor,
## compile-on-save and the export-integrity pass can never disagree about pairing.
static func output_path_for(sheet_path: String) -> String:
	# A code-backed (.gd) sheet IS its own output - editing + saving recompiles it in place, no companion.
	if sheet_path.get_extension().to_lower() == "gd":
		return sheet_path
	var sheet: EventSheetResource = load(sheet_path) as EventSheetResource
	if sheet == null:
		return sheet_path.get_basename() + "_generated.gd"
	return SheetCompiler._resolve_output_path(sheet, "")


## Every committed output must be exactly what its sheet compiles to today - the same
## byte-identity contract pack goldens pin, generalized to every sheet in the project.
static func check_generated_outputs(sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	for sheet_path: String in sheet_paths:
		var sheet: EventSheetResource = load(sheet_path) as EventSheetResource
		if sheet == null:
			continue
		var output_path: String = output_path_for(sheet_path)
		if not FileAccess.file_exists(output_path):
			_add(findings, "warning", "stale-output", sheet_path,
				"No generated script yet - saving the sheet in the editor writes %s (compile-on-save)." % output_path.get_file())
			continue
		var result: Dictionary = SheetCompiler.compile(sheet, SCRATCH_PATH)
		if not bool(result.get("success", false)):
			_add(findings, "error", "compile", sheet_path,
				"Sheet no longer compiles: %s" % str(result.get("errors")))
			continue
		if str(result.get("output", "")) != FileAccess.get_file_as_string(output_path):
			_add(findings, "error", "stale-output", sheet_path,
				"%s is stale - re-save the sheet (or re-run the pack builder) to refresh it." % output_path.get_file())
	DirAccess.remove_absolute(SCRATCH_PATH)


## Debug residue: a sheet saved with a debug-emit toggle ON compiles debug instrumentation INTO its
## committed script - `breakpoint` statements (which HALT the running game into the debugger), the
## live-values telemetry receiver (`__live_values_timer`, `sheet_compiler.gd:304`), or the per-event
## trace buffer (`__eventsheets_fired`, `:306/:1138`). The byte-identity check above PASSES on these
## because the residue is faithfully in sync with the sheet - so only THIS check catches "in sync, but
## shipping debug code." A warning (some teams keep live-values on during development); the one-click
## fix is strip_debug_flags() + re-save (the Doctor panel's "strip + resave"). Never fails CI on its own,
## but the documented CI recipe can escalate it for release branches.
static func check_debug_residue(sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	for sheet_path: String in sheet_paths:
		var sheet: EventSheetResource = load(sheet_path) as EventSheetResource
		if sheet == null:
			continue
		var flags: PackedStringArray = PackedStringArray()
		if sheet.emit_breakpoints:
			flags.append("breakpoints")
		if sheet.emit_live_values:
			flags.append("live-values telemetry")
		if sheet.emit_event_trace:
			flags.append("event trace")
		if not flags.is_empty():
			_add(findings, "warning", "debug-residue", sheet_path,
				"Debug instrumentation (%s) is compiled into the committed script - turn it off (Debug menu) and re-save before shipping." % ", ".join(flags))


## Clears every debug-emit toggle on a sheet - the data half of the Doctor panel's "strip + resave" fix
## (the caller re-saves, which recompiles the residue out). Returns true only if something was on, so the
## caller re-saves only when needed.
static func strip_debug_flags(sheet: EventSheetResource) -> bool:
	if sheet == null:
		return false
	var was_on: bool = sheet.emit_breakpoints or sheet.emit_live_values or sheet.emit_event_trace
	sheet.emit_breakpoints = false
	sheet.emit_live_values = false
	sheet.emit_event_trace = false
	return was_on


## Autoload sheets only run when project.godot points their singleton name at the
## compiled script (the dock's Tools → Register Autoload does this in one click).
static func check_autoload_registration(sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	for sheet_path: String in sheet_paths:
		var sheet: EventSheetResource = load(sheet_path) as EventSheetResource
		if sheet == null or not sheet.autoload_mode:
			continue
		if sheet.autoload_name.is_empty():
			_add(findings, "warning", "autoload", sheet_path,
				"Autoload sheet has no singleton name - set one in the Sheet Type dialog.")
			continue
		var key: String = "autoload/%s" % sheet.autoload_name
		var expected: String = output_path_for(sheet_path)
		if not ProjectSettings.has_setting(key):
			_add(findings, "warning", "autoload", sheet_path,
				"Autoload sheet \"%s\" is not registered - Tools → Register Autoload." % sheet.autoload_name)
		elif str(ProjectSettings.get_setting(key)).trim_prefix("*") != expected:
			_add(findings, "warning", "autoload", sheet_path,
				"Autoload \"%s\" points at %s, but this sheet compiles to %s." % [sheet.autoload_name, str(ProjectSettings.get_setting(key)).trim_prefix("*"), expected])


## Reverse scene lookup: a compiled sheet nothing instances is usually a forgotten
## attach. Skips autoload sheets (registered, not attached) and published packs
## (vocabulary, not project wiring) - and stays advisory, since scripts can be
## attached from code or used as a named class.
static func check_scene_attachment(sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	# Scene texts read ONCE for all sheets (review catch: per-sheet scenes_attaching
	# calls were O(sheets × scenes) file reads).
	var scene_texts: Array[String] = []
	for scene_path: String in _list_files_with_extension("tscn"):
		scene_texts.append(FileAccess.get_file_as_string(scene_path))
	for sheet_path: String in sheet_paths:
		if sheet_path.begins_with("res://eventsheet_addons/"):
			continue
		var sheet: EventSheetResource = load(sheet_path) as EventSheetResource
		if sheet == null or sheet.autoload_mode:
			continue
		var output_path: String = output_path_for(sheet_path)
		if not FileAccess.file_exists(output_path):
			continue  # Already reported by the stale-output check.
		var attached: bool = false
		for scene_text: String in scene_texts:
			if scene_text.contains(output_path):
				attached = true
				break
		if not attached:
			_add(findings, "info", "scene-attachment", sheet_path,
				"%s is attached to no scene - fine if it's instanced from code or used as a class." % output_path.get_file())


## Required-fields audit: a variable marked Required (# @inspector_required) whose script DEFAULT
## is empty is only satisfied when each scene node / saved resource using that script overrides
## it. Godot omits default-equal properties from .tscn/.tres, so "no override line" means the
## empty default ships. Warnings name the exact file + property. demo/showcase is exempt (its
## deliberately unset portrait IS the required-badge demo), as are the packs themselves.
static func check_required_fields(sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	var watched: Dictionary = {}
	for sheet_path: String in sheet_paths:
		var output_path: String = output_path_for(sheet_path)
		if not FileAccess.file_exists(output_path):
			continue
		var empty_required: PackedStringArray = required_empty_defaults(FileAccess.get_file_as_string(output_path))
		if not empty_required.is_empty():
			watched[output_path] = empty_required
	if watched.is_empty():
		return
	for container_ext: String in ["tscn", "tres"]:
		for container_path: String in _list_files_with_extension(container_ext):
			if container_path.begins_with("res://demo/") or container_path.begins_with("res://eventsheet_addons/") or container_path.begins_with("res://addons/"):
				continue
			for missing: Dictionary in required_gaps_in_container(FileAccess.get_file_as_string(container_path), watched):
				_add(findings, "warning", "required-field", container_path,
					"%s leaves the required \"%s\" (%s) unset - assign it in the Inspector." % [container_path.get_file(), str(missing.get("property")), str(missing.get("script")).get_file()])


## The script's Required variables whose declared default is empty (null / "") - the ones a
## scene or resource must override. Reads the same decor markers the Inspector renders.
static func required_empty_defaults(source: String) -> PackedStringArray:
	var empty_required: PackedStringArray = PackedStringArray()
	if source.find("# @inspector_required") == -1:
		return empty_required
	var decor_map: Dictionary = EventSheetAttributeDrawers.build_decor_map(source)
	for var_name: Variant in decor_map.keys():
		var required: bool = false
		for entry: Variant in decor_map[var_name]:
			if entry is Dictionary and str((entry as Dictionary).get("kind", "")) == "required":
				required = true
		if not required:
			continue
		var declaration: RegExMatch = RegEx.create_from_string("(?m)^.*var %s\\s*:[^=\\n]*=\\s*(.+)$" % var_name).search(source)
		var default_text: String = declaration.get_string(1).strip_edges() if declaration != null else "null"
		# A clamped var carries a setter suffix ("= null:") - strip it before judging emptiness.
		default_text = default_text.trim_suffix(":").strip_edges()
		if default_text == "null" or default_text == "\"\"":
			empty_required.append(str(var_name))
	return empty_required


## The required-field gaps inside ONE .tscn/.tres text, for the watched {script_path: [vars]}
## map: every node/resource block using a watched script that does NOT override a watched
## property. Pure (text in, gaps out) so the suite pins it without touching the filesystem.
static func required_gaps_in_container(text: String, watched: Dictionary) -> Array[Dictionary]:
	var gaps: Array[Dictionary] = []
	for script_path: Variant in watched.keys():
		if not text.contains(str(script_path)):
			continue
		var id_match: RegExMatch = RegEx.create_from_string("\\[ext_resource[^\\]]*path=\"%s\"[^\\]]*id=\"([^\"]+)\"" % str(script_path).replace("/", "\\/")).search(text)
		if id_match == null:
			continue
		var script_ref: String = "script = ExtResource(\"%s\")" % id_match.get_string(1)
		for block: String in text.split("\n["):
			if not block.contains(script_ref):
				continue
			for property_name: Variant in watched[script_path]:
				if not block.contains("\n%s = " % str(property_name)):
					gaps.append({"script": str(script_path), "property": str(property_name)})
	return gaps


## The sheet a generated script belongs to - the inverse of output_path_for.
## Trusts the script's "# Source:" header first (exact), then sibling naming
## verified through the pairing rule. "" when the script isn't sheet-generated.
static func sheet_for_script(script_path: String) -> String:
	if script_path.is_empty() or not FileAccess.file_exists(script_path):
		return ""
	var header: String = FileAccess.get_file_as_string(script_path).left(400)
	var found: RegExMatch = RegEx.create_from_string("(?m)^# Source: (.+\\.tres)$").search(header)
	if found != null and FileAccess.file_exists(found.get_string(1)):
		return found.get_string(1)
	var sibling: String = script_path.get_basename().trim_suffix("_generated") + ".tres"
	if FileAccess.file_exists(sibling) and ResourceLoader.load(sibling, "", ResourceLoader.CACHE_MODE_REUSE) is EventSheetResource and output_path_for(sibling) == script_path:
		return sibling
	# A behaviour/addon pack .gd IS its own sheet (no .tres companion) - it pairs to itself. EventForge
	# sheets carry `## @ace_*` annotations (exposed ACEs / tags / triggers); hand-written scripts do not.
	if script_path.get_extension().to_lower() == "gd" and RegEx.create_from_string("(?m)^## @ace_").search(FileAccess.get_file_as_string(script_path)) != null:
		return script_path
	return ""


## Every scene that references a script path - the reverse lookup the attachment
## check and the dock's Run Scene share (sorted for stable pick menus).
static func scenes_attaching(script_path: String) -> PackedStringArray:
	var matches: PackedStringArray = PackedStringArray()
	for scene_path: String in _list_files_with_extension("tscn"):
		if FileAccess.get_file_as_string(scene_path).contains(script_path):
			matches.append(scene_path)
	matches.sort()
	return matches


## Private (non-exported) variables nothing references are dead vocabulary. Exported
## variables are skipped (they're set per-instance in the Inspector); usage is searched
## in this sheet's rows, other variables' attributes (show_if etc.) and every sheet
## that includes this one.
static func check_unused_variables(sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	var usage_by_path: Dictionary = {}
	var includes_by_path: Dictionary = {}
	for sheet_path: String in sheet_paths:
		var sheet: EventSheetResource = load(sheet_path) as EventSheetResource
		if sheet == null:
			continue
		usage_by_path[sheet_path] = _sheet_usage_text(sheet)
		includes_by_path[sheet_path] = sheet.includes.duplicate()
	for sheet_path: String in sheet_paths:
		var sheet: EventSheetResource = load(sheet_path) as EventSheetResource
		if sheet == null or sheet.variables.is_empty():
			continue
		var names: Array = sheet.variables.keys()
		names.sort()
		for variable_name: Variant in names:
			var descriptor: Variant = sheet.variables[variable_name]
			if not (descriptor is Dictionary) or bool((descriptor as Dictionary).get("exported", true)):
				continue
			var corpus: String = str(usage_by_path.get(sheet_path, ""))
			for other_name: Variant in sheet.variables:
				if str(other_name) != str(variable_name):
					corpus += "\n" + str(sheet.variables[other_name])
			for other_path: String in sheet_paths:
				if other_path != sheet_path and (includes_by_path.get(other_path, []) as Array).has(sheet_path):
					corpus += "\n" + str(usage_by_path.get(other_path, ""))
			if RegEx.create_from_string("\\b%s\\b" % str(variable_name)).search(corpus) == null:
				_add(findings, "info", "unused-variable", sheet_path,
					"Private variable \"%s\" is never referenced - dead vocabulary?" % str(variable_name))


## The same global declared across several sheets is N copies of one truth; Godot's answer is a single
## autoload (a Game State singleton). Advisory: lists the sheets sharing a name and points at the
## autoload starter. Skips packs (vocabulary, not project state) and autoload sheets - an autoload IS
## the fix - and exempts a name a GameState autoload already publishes (the solved case).
static func check_duplicated_globals(sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	var name_to_sheets: Dictionary = {}
	var autoload_published: Dictionary = {}
	for sheet_path: String in sheet_paths:
		if sheet_path.begins_with("res://eventsheet_addons/"):
			continue
		var sheet: EventSheetResource = load(sheet_path) as EventSheetResource
		if sheet == null:
			continue
		if sheet.autoload_mode:
			for variable_name: Variant in sheet.variables:
				autoload_published[str(variable_name)] = true
			continue
		for variable_name: Variant in sheet.variables:
			var name_key: String = str(variable_name)
			var sheets_for_name: PackedStringArray = name_to_sheets.get(name_key, PackedStringArray())
			sheets_for_name.append(sheet_path)
			name_to_sheets[name_key] = sheets_for_name
	var ordered_names: Array = name_to_sheets.keys()
	ordered_names.sort()
	for name_key: String in ordered_names:
		var sheets_for_name: PackedStringArray = name_to_sheets[name_key]
		if sheets_for_name.size() < 2 or autoload_published.has(name_key):
			continue
		var file_names: PackedStringArray = PackedStringArray()
		for sheet_path: String in sheets_for_name:
			file_names.append(sheet_path.get_file())
		_add(findings, "info", "duplicated-global", sheets_for_name[0],
			"Global \"%s\" is declared in %d sheets (%s) - if it's shared state, promote it to an autoload (one source of truth): New Sheet -> Game State (Autoload)." % [name_key, sheets_for_name.size(), ", ".join(file_names)])

## A plain sheet that reaches into MANY distinct OTHER nodes is a god-sheet doing several nodes' jobs;
## the Godot answer is a behavior component per node, or a deliberately-named coordinator. Counts
## DISTINCT external node targets (the With-node scope, node-targeted ACEs, and $path / %unique refs
## in params and raw code) via the node-path parser - NOT row count (a long coherent state machine on
## one host is fine). Skips behavior + autoload sheets (a coordinator IS a valid choice). Info-tier.
const DEFAULT_FANOUT_THRESHOLD := 6


static func _fanout_threshold() -> int:
	return int(ProjectSettings.get_setting("eventsheets/doctor/fanout_threshold", DEFAULT_FANOUT_THRESHOLD))


static func check_fanout_god_sheets(sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	for sheet_path: String in sheet_paths:
		if sheet_path.begins_with("res://eventsheet_addons/"):
			continue
		var sheet: EventSheetResource = load(sheet_path) as EventSheetResource
		if sheet == null or sheet.behavior_mode or sheet.autoload_mode:
			continue
		var targets: Dictionary = {}
		_collect_external_targets(sheet.events, targets)
		for function_entry: Variant in sheet.functions:
			if function_entry is EventFunction:
				var event_function: EventFunction = function_entry
				_collect_external_targets(event_function.events if not event_function.events.is_empty() else event_function.rows, targets)
		if targets.size() >= _fanout_threshold():
			var names: Array = targets.keys()
			names.sort()
			_add(findings, "info", "fanout-god-sheet", sheet_path,
				"This sheet drives %d different nodes (%s) - consider a behavior component per node, or a deliberately-named coordinator, instead of one sheet reaching across the scene." % [targets.size(), ", ".join(PackedStringArray(names))])

## A heavy For Each that runs EVERY frame (under On Process / On Physics Process) and is neither capped
## (pick_first_n) nor budgeted (frame_spread) can hitch the game. Flags the PATTERN - a collection loop
## with >= N actions under a per-frame trigger - NOT a cost estimate (so it never alert-fatigues), and
## points at the Time Slicer pack / Budgeted For Each. Info-tier; skips bundled packs and the WHILE/
## REPEAT kinds; threshold via eventsheets/doctor/loop_cost_threshold (default 3).
const DEFAULT_LOOP_COST_THRESHOLD := 3


static func _loop_cost_threshold() -> int:
	return int(ProjectSettings.get_setting("eventsheets/doctor/loop_cost_threshold", DEFAULT_LOOP_COST_THRESHOLD))


static func check_unbounded_loops(sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	var threshold: int = _loop_cost_threshold()
	for sheet_path: String in sheet_paths:
		if sheet_path.begins_with("res://eventsheet_addons/"):
			continue
		var sheet: EventSheetResource = load(sheet_path) as EventSheetResource
		if sheet == null:
			continue
		for entry: Variant in sheet.events:
			if entry is EventRow and _is_per_frame_trigger((entry as EventRow).trigger_id):
				_scan_unbounded_loops(entry as EventRow, sheet_path, threshold, findings)


static func _is_per_frame_trigger(trigger_id: String) -> bool:
	return trigger_id == "OnProcess" or trigger_id == "OnPhysicsProcess"


## Walks an event + its sub-events for unbounded, unbudgeted For Each loops with >= threshold actions.
static func _scan_unbounded_loops(event: EventRow, sheet_path: String, threshold: int, findings: Array[Dictionary]) -> void:
	for filter_entry: Variant in event.pick_filters:
		if not (filter_entry is PickFilter):
			continue
		var pick: PickFilter = filter_entry
		if not pick.enabled:
			continue
		if pick.collection_kind == PickFilter.CollectionKind.WHILE or pick.collection_kind == PickFilter.CollectionKind.REPEAT:
			continue
		if pick.pick_first_n > 0 or pick.frame_spread_count > 0 or pick.frame_spread_budget_ms > 0.0:
			continue
		if event.actions.size() >= threshold:
			_add(findings, "info", "unbounded-loop", sheet_path,
				"A per-frame For Each here loops over '%s' with %d actions, uncapped and unbudgeted - if it's slow, spread it across frames with the Time Slicer pack or a Budgeted For Each." % [pick.iterator_name, event.actions.size()])
			break
	for sub: Variant in event.sub_events:
		if sub is EventRow:
			_scan_unbounded_loops(sub as EventRow, sheet_path, threshold, findings)

## ACE ids whose codegen `await`s - they suspend the handler into a coroutine (Begin Frame Budget alone
## does not await, so it is intentionally absent).
const COROUTINE_ACE_IDS: Array[String] = ["Wait", "AwaitSignal", "AwaitNextFrame", "AwaitIfOverBudget"]


## Flags a coroutine action (await / Wait / budget-yield) under a per-frame trigger: the next tick fires
## while the previous run may still be suspended, so the handler overlaps itself and double-processes.
static func check_coroutine_in_per_frame_trigger(sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	for sheet_path: String in sheet_paths:
		if sheet_path.begins_with("res://eventsheet_addons/"):
			continue
		var sheet: EventSheetResource = load(sheet_path) as EventSheetResource
		if sheet == null:
			continue
		for entry: Variant in sheet.events:
			if entry is EventRow and _is_per_frame_trigger((entry as EventRow).trigger_id):
				_scan_coroutine_misuse(entry as EventRow, sheet_path, findings)


static func _scan_coroutine_misuse(event: EventRow, sheet_path: String, findings: Array[Dictionary]) -> void:
	for action: Variant in event.actions:
		var flagged: String = ""
		if action is ACEAction and COROUTINE_ACE_IDS.has((action as ACEAction).ace_id):
			flagged = (action as ACEAction).ace_id
		elif action is RawCodeRow and (action as RawCodeRow).code.contains("await "):
			flagged = "await"
		if not flagged.is_empty():
			_add(findings, "warning", "coroutine-in-per-frame", sheet_path,
				"A coroutine action ('%s') runs under a per-frame trigger (On Process / On Physics Process). The next tick fires while the previous run may still be suspended, so the handler overlaps itself and double-processes. Move it to a one-shot trigger (On Ready / On Signal / a custom function), or use the Time Slicer pack." % flagged)
			break
	for sub: Variant in event.sub_events:
		if sub is EventRow:
			_scan_coroutine_misuse(sub as EventRow, sheet_path, findings)


## Walks a sheet's rows collecting DISTINCT external node references (normalised: $path / %unique,
## get_node folds into $path), from With-node scopes, ACE param values and raw GDScript. self/host,
## variables and absolute paths are not external targets.
static func _collect_external_targets(rows: Array, targets: Dictionary) -> void:
	for row: Variant in rows:
		if row is RawCodeRow:
			_note_node_refs((row as RawCodeRow).code, targets)
		elif row is EventGroup:
			var group: EventGroup = row
			_collect_external_targets(group.events if not group.events.is_empty() else group.rows, targets)
		elif row is EventRow:
			var event: EventRow = row
			_note_node_refs(event.with_node_target, targets)
			for ace: Variant in event.conditions + event.actions:
				if ace is RawCodeRow:
					_note_node_refs((ace as RawCodeRow).code, targets)
				elif ace is Resource and ace.get("params") is Dictionary:
					for value: Variant in (ace.get("params") as Dictionary).values():
						_note_node_refs(str(value), targets)
			_collect_external_targets(event.sub_events, targets)


static func _note_node_refs(text: String, targets: Dictionary) -> void:
	if text.strip_edges().is_empty():
		return
	for reference: String in ACEParamsDialog.node_references_in_expression(text):
		if not reference.begins_with("/"):
			targets["$" + reference] = true
	for unique_name: String in ACEParamsDialog.unique_names_in_expression(text):
		targets["%" + unique_name] = true


## Packs no sheet, scene or autoload references are removal candidates - advisory,
## because a pack is also legitimately used from hand-written GDScript only.
static func check_unused_packs(sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	var pack_scripts: Array[String] = EventSheetAddonScanner.list_addon_scripts()
	if pack_scripts.is_empty():
		return
	var corpus_parts: PackedStringArray = PackedStringArray()
	for sheet_path: String in sheet_paths:
		if sheet_path.begins_with("res://eventsheet_addons/"):
			continue  # A pack referencing itself isn't project usage.
		var sheet: EventSheetResource = load(sheet_path) as EventSheetResource
		if sheet == null:
			continue
		corpus_parts.append(_sheet_usage_text(sheet))
		corpus_parts.append(" ".join(sheet.uses_addons) + " " + " ".join(sheet.requires_behaviors)
			+ " " + " ".join(sheet.ace_provider_scripts) + " " + " ".join(sheet.includes))
	for scene_path: String in _list_files_with_extension("tscn"):
		corpus_parts.append(FileAccess.get_file_as_string(scene_path))
	for property: Dictionary in ProjectSettings.get_property_list():
		if str(property.get("name", "")).begins_with("autoload/"):
			corpus_parts.append(str(ProjectSettings.get_setting(str(property.get("name")))))
	var corpus: String = "\n".join(corpus_parts)
	var class_regex: RegEx = RegEx.create_from_string("(?m)^class_name\\s+([A-Za-z_][A-Za-z0-9_]*)")
	for script_path: String in pack_scripts:
		var found: RegExMatch = class_regex.search(FileAccess.get_file_as_string(script_path))
		if found == null:
			continue
		var pack_class: String = found.get_string(1)
		if corpus.contains(script_path) or RegEx.create_from_string("\\b%s\\b" % pack_class).search(corpus) != null:
			continue
		_add(findings, "info", "unused-pack", script_path,
			"Pack class %s is referenced by no sheet, scene or autoload - fine if you call it from hand-written GDScript." % pack_class)


## The class whose members a sheet's variables actually share a script with:
## behavior/autoload sheets compile to Node components (host members live behind
## `host.`), everything else extends the host class directly.
static func variable_scope_class(sheet: EventSheetResource) -> String:
	if sheet == null:
		return "Node"
	if sheet.behavior_mode or sheet.autoload_mode:
		return "Node"
	return sheet.host_class if ClassDB.class_exists(sheet.host_class) else "Node"


## "" when the name is free, else the class whose member it shadows. A shadowing
## variable (e.g. `velocity` on a CharacterBody2D sheet) makes the generated script
## unparseable AND blinds expression lint - the one rule shared by the doctor check
## and the variable dialog's refusal.
static func shadowed_member_class(sheet: EventSheetResource, variable_name: String) -> String:
	var scope_class: String = variable_scope_class(sheet)
	if ClassDB.class_has_method(scope_class, variable_name, false) \
			or ClassDB.class_has_signal(scope_class, variable_name) \
			or ClassDB.class_has_integer_constant(scope_class, variable_name):
		return scope_class
	for property: Dictionary in ClassDB.class_get_property_list(scope_class):
		if str(property.get("name")) == variable_name:
			return scope_class
	return ""


## Variables shadowing host members break the generated script at load (duplicate
## member) - error tier: the game cannot run until the variable is renamed.
static func check_shadowed_variables(sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	for sheet_path: String in sheet_paths:
		var sheet: EventSheetResource = load(sheet_path) as EventSheetResource
		if sheet == null:
			continue
		for variable_name: Variant in sheet.variables:
			var owner_class: String = shadowed_member_class(sheet, str(variable_name))
			if not owner_class.is_empty():
				_add(findings, "error", "shadowed-variable", sheet_path,
					"Variable \"%s\" shadows a %s member - the generated script can't load. Rename Everywhere… fixes every reference." % [str(variable_name), owner_class])


## A generated vocabulary doc is a promise to the team - once one exists, the doctor
## notes when it no longer matches what the project actually publishes. Opt-in by
## design: no doc, no note.
## Sheets emit tr() calls (globe-marked params / Translate ACEs) but the project has no
## translations configured - the calls will look up nothing at runtime. Advisory: point
## at Godot's own pipeline (POT generation reads the compiled .gd; catalogs register in
## Project Settings > Localization). Checked against the compiled OUTPUT text, so both
## .gd-backed and .tres-backed sheets are covered by the same scan.
static func check_untranslated_project(sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	if not (ProjectSettings.get_setting("internationalization/locale/translations", PackedStringArray()) as PackedStringArray).is_empty():
		return
	for sheet_path: String in sheet_paths:
		var output_path: String = output_path_for(sheet_path)
		if not FileAccess.file_exists(output_path):
			continue
		var output_text: String = FileAccess.get_file_as_string(output_path)
		if output_text.contains("tr(\"") or output_text.contains("tr_n(\"") or output_text.contains("TranslationServer.set_locale"):
			_add(findings, "info", "l10n", sheet_path,
				"This sheet translates text (tr / Set Language) but the project has no translations registered - generate a POT (Project Settings > Localization > POT Generation, add the compiled .gd), translate it, and add the catalog under Localization > Translations.")
			return


static func check_vocabulary_doc(findings: Array[Dictionary]) -> void:
	var path: String = EventSheetVocabularyDoc.doc_path()
	if not FileAccess.file_exists(path):
		return
	if FileAccess.get_file_as_string(path) != EventSheetVocabularyDoc.generate():
		_add(findings, "info", "vocabulary-doc", path,
			"Vocabulary doc is stale - regenerate via Tools → Vocabulary Doc… or tools/vocabulary_doc.gd.")


## Everything in a sheet that can REFERENCE vocabulary: raw code, ACE param values and
## baked templates, pick filters, trigger args, local-variable defaults. Comments are
## deliberately excluded - mentioning a name in prose isn't usage.
static func _sheet_usage_text(sheet: EventSheetResource) -> String:
	var chunks: PackedStringArray = PackedStringArray()
	_collect_usage_text(sheet.events, chunks)
	for function_entry: Variant in sheet.functions:
		if function_entry is EventFunction:
			var event_function: EventFunction = function_entry
			_collect_usage_text(event_function.events if not event_function.events.is_empty() else event_function.rows, chunks)
	return "\n".join(chunks)


static func _collect_usage_text(rows: Array, into: PackedStringArray) -> void:
	for row: Variant in rows:
		if row is RawCodeRow:
			into.append((row as RawCodeRow).code)
		elif row is EventGroup:
			var group: EventGroup = row
			_collect_usage_text(group.events if not group.events.is_empty() else group.rows, into)
		elif row is LocalVariable:
			into.append(str((row as LocalVariable).default_value))
		elif row is EventRow:
			var event: EventRow = row
			into.append(event.trigger_provider_id + " " + str(event.trigger_args))
			for ace: Variant in event.conditions + event.actions:
				if ace is RawCodeRow:
					into.append((ace as RawCodeRow).code)
				elif ace is Resource and ace.get("params") is Dictionary:
					into.append(str(ace.get("provider_id")) + " " + str(ace.get("codegen_template")))
					for value: Variant in (ace.get("params") as Dictionary).values():
						into.append(str(value))
			for pick: Variant in event.pick_filters:
				if pick is PickFilter:
					into.append((pick as PickFilter).collection_value + " " + (pick as PickFilter).predicate_expression)
			_collect_usage_text(event.sub_events, into)


static func _list_files_with_extension(extension: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var pending: PackedStringArray = PackedStringArray(["res://"])
	while not pending.is_empty():
		var directory_path: String = pending[pending.size() - 1]
		pending.remove_at(pending.size() - 1)
		var directory: DirAccess = DirAccess.open(directory_path)
		if directory == null:
			continue
		directory.list_dir_begin()
		var entry: String = directory.get_next()
		while not entry.is_empty():
			var full_path: String = directory_path.path_join(entry)
			if directory.current_is_dir():
				if not entry.begins_with(".") and entry != "addons":
					pending.append(full_path)
			elif entry.get_extension() == extension:
				found.append(full_path)
			entry = directory.get_next()
		directory.list_dir_end()
	return found


static func _add(findings: Array[Dictionary], severity: String, check: String, path: String, message: String) -> void:
	findings.append({"severity": severity, "check": check, "path": path, "message": message})
