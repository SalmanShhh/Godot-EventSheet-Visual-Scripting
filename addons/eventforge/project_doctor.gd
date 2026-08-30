# Godot EventSheets - Project Doctor (one audit for the drift no single check sees)
#
# Unions the project-health checks into a single report, runnable four ways: the
# dock's Tools menu, the headless CLI (tools/project_doctor.gd), CI and the MCP
# server's run_doctor tool. Severities:
#   error   - a broken contract: a committed generated script drifted from what its
#             sheet compiles to today, or a sheet no longer compiles. CI fails on these.
#   warning - a wiring gap with a one-step fix: sheet never compiled, autoload sheet
#             not registered (or registered to a different script), a save key read back
#             that nothing ever writes.
#   info    - advisory vocabulary hygiene: private variable never referenced, pack
#             published but unused, compiled sheet attached to no scene, a stateful
#             behavior missing the save-state seam, one name kept both by Remember
#             Between Runs and by the Save System. Never fails CI.
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

## The project's own GDScript files, listed once and handed to every check that asks. Dropped at the
## start of a run and on the editor's filesystem ping - see `_project_scripts`.
static var _project_scripts_cache: PackedStringArray = PackedStringArray()
static var _project_scripts_walked: bool = false

## path -> that file's text, for the length of one audit - see `source_of`.
static var _source_cache: Dictionary = {}

## True only while `run()` is between its first check and its last. The sharing below is scoped to
## that window rather than to the session: a check called on its own (which is how every check is
## tested) may be handed a fixture that was just rewritten under it, and a read held from before the
## write would answer with the file that is no longer there.
static var _run_in_progress: bool = false


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
	# One listing of the project's scripts serves the whole audit; dropping it here is what makes an
	# audit see files that appeared since the last one.
	clear_project_scripts()
	_run_in_progress = true
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
	check_fragile_node_paths(sheet_paths, findings)
	check_unbounded_loops(sheet_paths, findings)
	check_every_tick_setup(sheet_paths, findings)
	check_coroutine_in_per_frame_trigger(sheet_paths, findings)
	check_unused_packs(sheet_paths, findings)
	check_pack_dependencies(sheet_paths, findings)
	check_rotated_gravity_pathfinding(findings)
	check_param_type_mismatches(sheet_paths, findings)
	check_shadowed_variables(sheet_paths, findings)
	check_variable_notes(sheet_paths, findings)
	check_region_fences(sheet_paths, findings)
	check_untranslated_project(sheet_paths, findings)
	check_unmarked_player_text(sheet_paths, findings)
	check_stale_translated_labels(sheet_paths, findings)
	check_required_fields(sheet_paths, findings)
	check_missing_save_support(sheet_paths, findings)
	check_save_key_symmetry(sheet_paths, findings)
	check_editor_tool_undo(sheet_paths, findings)
	check_sheet_edit_funnel(findings)
	check_editor_tool_safety(sheet_paths, findings)
	check_background_thread_safety(sheet_paths, findings)
	check_unknown_input_actions(sheet_paths, findings)
	check_unsaved_rebindings(sheet_paths, findings)
	check_caption_less_sounds(sheet_paths, findings)
	check_orphaned_provider_calls(sheet_paths, findings)
	check_sheet_signal_declarations(sheet_paths, findings)
	check_pattern_smells(sheet_paths, findings)
	check_unresolved_conflicts(findings)
	check_shared_sheet_includes(findings)
	check_blocking_waits(sheet_paths, findings)
	check_hierarchy_footguns(sheet_paths, findings)
	check_vocabulary_doc(findings)
	check_pack_reading(findings)
	check_disabled_pack_usage(sheet_paths, findings)
	check_family_group_agreement(findings)
	check_imported_rows(sheet_paths, findings)
	check_task_notes(findings)
	check_menu_ids(findings)
	check_game_modes(findings)
	check_animation_method_tracks(findings)
	check_plugin_reading_health(findings)
	check_facing_follows(sheet_paths, findings)
	check_skill_trees(findings)
	check_raw_error_notes(sheet_paths, findings)
	# The tidiness sweep: what is declared but dead, said twice, or typed three times. Advisory
	# notes only, and last of the built-ins so the established report never reorders.
	EventSheetDoctorTidiness.check_tidiness(sheet_paths, findings)
	# Declarations nobody reaches (dead enum values, signals nothing hears) - driven by the
	# project's generated scripts, not by sheet_paths. After the tidiness sweep for the same
	# reason the sweep runs last: new notes append, the established report never reorders.
	EventSheetDoctorTidiness.check_declaration_reach(findings)
	# The Multiplayer and Lighting sections ship as EXTENSION checks, registered through the
	# same public seam a pack uses, so "a pack adds its own networking scripts to that section" is the
	# shipped path rather than a special case. Registering here is what puts them in all four runners.
	EventSheetMultiplayerDoctor.ensure_registered()
	EventSheetLightingDoctor.ensure_registered()
	EventSheetEffectsDoctor.ensure_registered()
	EventSheetInteropDoctor.ensure_registered()
	EventSheetPerformanceDoctor.ensure_registered()
	EventSheetOptionsDoctor.ensure_registered()
	EventSheetSelfDocDoctor.ensure_registered()
	# The Spawning section: the four ways putting a node into the world and taking it out again go
	# wrong at run time while the editor says nothing. Same seam, same reason.
	EventSheetSpawningDoctor.ensure_registered()
	# The Collision Layers section: a row about a layer number the project no longer names. Same
	# seam, same reason - a pack shipping collision verbs of its own lands in this section too.
	EventSheetCollisionLayerDoctor.ensure_registered()
	# The Docs section: whether the guides still describe the packs they are about. It rides the same
	# seam for the same reason - a studio's own pack guide is audited exactly like a shipped one - and
	# it asks EventSheetDocCoverage, which is also what the help-bundle builder asks, so the page and
	# the build output can never say different things about the same guide.
	EventSheetDocsDoctor.ensure_registered()
	# Ship It rides the same seam: whether the game can leave the building is a question about the
	# PROJECT rather than about any one sheet, so it is registered rather than wired in beside the
	# sheet checks, and a studio's own release rule joins it the same way.
	EventSheetShipItDoctor.ensure_registered()
	# Extension checks (packs and plugins, via EventSheets.register_doctor_check) run
	# after the built-ins so their findings never reorder the established report.
	for entry: Dictionary in _extension_checks:
		var extension_check: Callable = entry.get("run") as Callable
		if extension_check.is_valid():
			extension_check.call(sheet_paths, findings)
	# The report is complete, so the texts the checks shared are dead weight - a dock that ran the
	# audit once should not carry the project's source for the rest of the session.
	_run_in_progress = false
	_source_cache.clear()
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
		if str(result.get("output", "")) != source_of(output_path):
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
		if sheet.emit_input_recording:
			flags.append("replay recording")
		if not flags.is_empty():
			_add(findings, "warning", "debug-residue", sheet_path,
				"Debug instrumentation (%s) is compiled into the committed script - turn it off (Debug menu) and re-save before shipping." % ", ".join(flags))


## Clears every debug-emit toggle on a sheet - the data half of the Doctor panel's "strip + resave" fix
## (the caller re-saves, which recompiles the residue out). Returns true only if something was on, so the
## caller re-saves only when needed.
static func strip_debug_flags(sheet: EventSheetResource) -> bool:
	if sheet == null:
		return false
	var was_on: bool = sheet.emit_breakpoints or sheet.emit_live_values or sheet.emit_event_trace \
		or sheet.emit_input_recording
	sheet.emit_breakpoints = false
	sheet.emit_live_values = false
	sheet.emit_event_trace = false
	sheet.emit_input_recording = false
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
		scene_texts.append(source_of(scene_path))
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
		var empty_required: PackedStringArray = required_empty_defaults(source_of(output_path))
		if not empty_required.is_empty():
			watched[output_path] = empty_required
	if watched.is_empty():
		return
	for container_ext: String in ["tscn", "tres"]:
		for container_path: String in _list_files_with_extension(container_ext):
			if container_path.begins_with("res://demo/") or container_path.begins_with("res://eventsheet_addons/") or container_path.begins_with("res://addons/"):
				continue
			for missing: Dictionary in required_gaps_in_container(source_of(container_path), watched):
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


## Save support: a behavior or autoload that declares State (non-exported) variables but
## whose compiled script has no save_state/load_state seam won't survive Save Game - that
## runtime state lives only in the node and is unreachable by the Save System's verbs. The
## fix is one click (Tools > Save Studio > Add Save Support, which generates the pair, or
## the seam by hand). Info-tier and honest: plenty of State is transient and rightly
## unsaved, so this nudges, never fails CI. Statefulness reads the sheet's own Properties/
## State split (a declared State variable is the author saying "this is runtime state");
## the seam is detected in the compiled OUTPUT, so a hand-written save_state counts too.
static func check_missing_save_support(sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	for sheet_path: String in sheet_paths:
		var sheet: EventSheetResource = load(sheet_path) as EventSheetResource
		if sheet == null or not (sheet.behavior_mode or sheet.autoload_mode):
			continue
		var state_vars: int = 0
		for descriptor: Variant in sheet.variables.values():
			if descriptor is Dictionary and not bool((descriptor as Dictionary).get("exported", true)):
				state_vars += 1
		if state_vars == 0:
			continue
		var output_path: String = output_path_for(sheet_path)
		if not FileAccess.file_exists(output_path):
			continue  # the stale-output check owns the "not compiled yet" case
		if source_of(output_path).contains("func save_state("):
			continue
		var kind: String = "autoload" if sheet.autoload_mode else "behavior"
		_add(findings, "info", "save-support", sheet_path,
			"This %s holds %d State variable(s) but has no save_state/load_state seam, so its runtime state won't survive Save Game - Tools > Save Studio > Add Save Support generates the pair (ignore if the state is transient)." % [kind, state_vars])


## Save-key symmetry: the commonest save bug is not a crash, it is a SILENCE. A sheet loads
## "coins" on ready, nothing in the project ever saves "coins", and the game reads the default
## forever while looking like it works - no error, no warning, no clue. The save-support check
## above is adjacent but answers a different question (does this sheet have a save_state seam at
## all); this one is about the KEYS, and it is decidable: collect every save key the project
## WRITES, every key it READS BACK, and diff the two sets.
##
## It reads the EMITTED SCRIPTS, not the sheet resources, for the reason the orphaned-verb check
## documents: `.gd` is the default sheet format but list_project_sheets() finds only `.tres`, so a
## check driven by sheet_paths would skip most real projects while looking like it works. The save
## call is in the emitted code either way, so that is where this is true - and a hand-written
## script reading a key nobody writes is the same bug whoever typed it.
##
## NOT CRYING WOLF IS THE WHOLE FEATURE - a Doctor check that accuses a working game is worse than
## no check, so the two sides are deliberately asymmetric. A WRITE is counted from every route a
## key can really reach the file: a save verb with any receiver or none (a hand-rolled
## `_saves.save_value("coins", …)` wrapper counts), a `save_state()` snapshot key, a Remember
## Between Runs variable, and a subscript assignment into a save payload (`data["coins"] = …`,
## which is how a migration rewrites a slot). A READ is matched strictly (a real
## `something.load_number("coins")` call with a literal key): missing a write would produce a
## false accusation, while missing a read only costs silence. Anything computed - a key built from
## a variable, a concatenation, a loop over save_keys() - is never judged, because there is nothing
## to compare, and the save backend's own "__" reserved keys are never blamed on anyone.
##
## Two findings come out. A key read with no writer anywhere is a `warning` (a wiring gap with a
## one-step fix, named on the script that reads it). A name that is BOTH a Remember Between Runs
## variable and a top-level Save System key is an `info`: one value, two files, two lifetimes, and
## after a slot load the two copies can disagree - nobody spots that by eye. That second one is
## deliberately narrower than the first: it needs a PROJECT script (never a pack) using the name as
## a real slot key, because `save_state()` members live inside their own node's dictionary and a
## pack returning `{"level": …}` from its snapshot has nothing to do with an author's `level`.
##
## The deliberate omission is the mirror case, "a key written and never read back". Its false
## positives are everywhere a save is read in bulk (a `read_all()` loop, a slot browser listing
## keys, a version stamp shown on the load screen, a migration that will read it next version),
## and every one of those would be a wrong accusation about working code. The asymmetry is
## honest: reading a key nobody writes is always a bug, writing a key nobody reads often is not.
##
## THE KNOWN LIMITATIONS, stated rather than implied. This reads TEXT, so: whole-line comments are
## stripped first, but a call quoted inside a string literal can still read as a real one; a key
## built at runtime is invisible by design; `_project_scripts()` skips every `addons` directory, so
## a save written from a plugin under res://addons/ is not seen; and a `.tres` sheet that has never
## been compiled contributes no emitted code to scan. Each of those costs silence, never a false
## accusation, except the string-literal case - which is why the message ends by naming the way out.
static func check_save_key_symmetry(_sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	var usage_by_path: Dictionary = {}
	for script_path: String in _project_scripts():
		var source: String = source_of(script_path)
		if source.is_empty():
			continue
		var usage: Dictionary = save_key_usage(source)
		if (usage["saved"] as PackedStringArray).is_empty() and (usage["loaded"] as PackedStringArray).is_empty() \
				and (usage["remembered"] as PackedStringArray).is_empty():
			continue
		usage_by_path[script_path] = usage
	findings.append_array(save_key_findings(usage_by_path))


## The whole diff as a pure function: {script_path: save_key_usage(source)} in, findings out. The
## corpus is PROJECT-WIDE on purpose - a key saved by one sheet and read by another is symmetric,
## and judging a script alone would report every one of those as broken.
static func save_key_findings(usage_by_path: Dictionary) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	var saved: Dictionary = {}
	# Top-level SLOT keys written by a project script - the only writes the double-storage advisory
	# may compare against. A `save_state()` member is not one: it lives inside its own node's
	# dictionary, so a pack snapshotting `{"level": …}` shares nothing but a common word.
	var slot_saved: Dictionary = {}
	# key -> the script to BLAME, or "" when only a pack uses it: a pack is shipped vocabulary the
	# project author cannot edit, so its keys join the corpus but never get reported.
	var loaded: Dictionary = {}
	var remembered: Dictionary = {}
	var paths: Array = usage_by_path.keys()
	paths.sort()
	for script_path: String in paths:
		var usage: Dictionary = usage_by_path[script_path]
		var blamable: bool = not script_path.begins_with("res://eventsheet_addons/")
		for key: String in usage.get("saved", PackedStringArray()):
			saved[key] = true
		if blamable:
			for key: String in usage.get("slot_keys", PackedStringArray()):
				slot_saved[key] = true
		for key: String in usage.get("loaded", PackedStringArray()):
			_note_key_owner(loaded, key, script_path, blamable)
		for key: String in usage.get("remembered", PackedStringArray()):
			_note_key_owner(remembered, key, script_path, blamable)
	var loaded_keys: Array = loaded.keys()
	loaded_keys.sort()
	for key: String in loaded_keys:
		var reader_path: String = str(loaded[key])
		if reader_path.is_empty() or saved.has(key) or remembered.has(key) or _is_reserved_save_key(key):
			continue
		_add(findings, "warning", "save-key-symmetry", reader_path,
			"\"%s\" is read back here, but nothing in this project ever saves it - so it reads its default on every run and the game looks fine while quietly forgetting. Add the matching save action wherever the game saves (Save System > Save Number / Save Value / Save Node State), or tick Remember Between Runs on the variable instead (ignore this if something outside the project writes that file)." % key)
	var remembered_keys: Array = remembered.keys()
	remembered_keys.sort()
	for key: String in remembered_keys:
		var owner_path: String = str(remembered[key])
		# A PROJECT script has to be treating the same name as a slot key - written or read back.
		# Anything less is a word two unrelated values happen to share.
		var read_by_project: bool = loaded.has(key) and not str(loaded[key]).is_empty()
		if owner_path.is_empty() or _is_reserved_save_key(key) or not (slot_saved.has(key) or read_by_project):
			continue
		_add(findings, "info", "save-key-symmetry", owner_path,
			"\"%s\" is kept in two places at once: Remember Between Runs stores it in user://remembered.cfg, and the Save System stores a \"%s\" key in the save slot. The two have different lifetimes, so after loading a slot the copies can disagree. Pick one home - untick Remember Between Runs on the variable, or drop the save/load rows for that key." % [key, key])
	return findings


## The save backend's OWN bookkeeping, never a value the author is responsible for saving. The
## Save System reserves every "__" name for exactly that reason ("__persist" for the scene-tree
## snapshot, "__version" for which build wrote the file, "__addons" for the autoload snapshot),
## and it writes them from inside its own backends where no Save Value row exists to be found. A
## game key is not spelled this way, so skipping them costs no coverage. Reported by
## save_key_usage all the same - a tool asking what a script touches wants the truth; it is the
## BLAME that is wrong here, not the fact.
static func _is_reserved_save_key(key: String) -> bool:
	return key.begins_with("__")


## First writer wins, but a pack's placeholder is upgraded the moment a project script uses the
## same key, so the finding always names a file the author can actually open and fix.
static func _note_key_owner(owners: Dictionary, key: String, script_path: String, blamable: bool) -> void:
	if not owners.has(key) or (blamable and str(owners[key]).is_empty()):
		owners[key] = script_path if blamable else ""


## Whether a source is doing save work at all - the gate on counting a subscript assignment as a
## save write. Deliberately a marker list rather than "mentions save": a file that writes a save
## payload calls one of these. `use_upgraded_save` is in the list because a MIGRATION written the
## documented way - rewrite the record the On Save Needs Upgrade trigger handed you, then hand it
## back - ends there and nowhere else, and without it the migrated key reads as never saved.
const _SAVE_WORK_MARKERS: PackedStringArray = ["save_value", "save_number", "save_text", "save_game",
	"save_state", "read_all", "save_node_state", "save_group_state", "save_singleton_state",
	"use_upgraded_save"]


static func _does_save_work(source: String) -> bool:
	for marker: String in _SAVE_WORK_MARKERS:
		if source.contains(marker):
			return true
	return false


## Save System verbs whose FIRST argument is the save key.
const _SAVE_KEY_WRITERS: PackedStringArray = ["save_value", "save_number", "save_text"]
const _SAVE_KEY_READERS: PackedStringArray = ["load_value", "load_number", "load_text", "has_save_key", "load_group_state"]
## Verbs whose key follows one plain argument - save_node_state($Player, "player").
const _SAVE_SLOT_WRITERS: PackedStringArray = ["save_node_state", "save_group_state", "save_singleton_state"]
const _SAVE_SLOT_READERS: PackedStringArray = ["load_node_state", "load_singleton_state"]


## What one script's SOURCE says about save keys, as {"saved", "slot_keys", "loaded", "remembered"}
## sorted PackedStringArrays. Pure (text in, keys out) so the rule is pinned without planting a
## deliberately asymmetric fixture in the project - which would make the Doctor report a warning
## on this repo forever, the exact noise the check exists to avoid. Also the API's save_keys_used.
##
## "saved" is every write of any kind; "slot_keys" is the subset that are TOP-LEVEL keys in the save
## file (a verb call or a subscript write), leaving out `save_state()` members - those live inside
## their own node's dictionary and share nothing with a slot key but a spelling.
static func save_key_usage(source: String) -> Dictionary:
	# Comments are prose, not code: a call written out in a `# reads it with load_number("coins")`
	# note is documentation, and counting it as a real read is how a text scanner accuses a working
	# game. Whole-line comments come off before anything is matched.
	var scanned: String = _without_comment_lines(source)
	var slot_keys: Dictionary = {}
	var snapshot: Dictionary = {}
	var loaded: Dictionary = {}
	var remembered: Dictionary = {}
	# Most scripts in a project touch no save at all; skipping them costs one substring scan.
	if scanned.contains("save_") or scanned.contains("load_"):
		_note_save_keys(scanned, _save_call_pattern(_SAVE_KEY_WRITERS, 1, false), slot_keys)
		_note_save_keys(scanned, _save_call_pattern(_SAVE_SLOT_WRITERS, 2, false), slot_keys)
		_note_save_keys(scanned, _save_call_pattern(_SAVE_KEY_READERS, 1, true), loaded)
		_note_save_keys(scanned, _save_call_pattern(_SAVE_SLOT_READERS, 2, true), loaded)
		_note_snapshot_keys(scanned, snapshot)
		# A save payload is often written by SUBSCRIPT rather than by a verb: a migration handed the
		# raw Dictionary rewrites it in place (`save_data["health"] = save_data["hp"]`), and the Save
		# System's own format backends do the same. Counted as a write, but only inside a file that is
		# demonstrably doing save work, so an unrelated dictionary elsewhere in the game cannot
		# silence a real finding.
		if _does_save_work(scanned):
			_note_save_keys(scanned, _cached_regex("\\[\\s*\"([^\"]+)\"\\s*\\]\\s*=(?!=)"), slot_keys)
	if scanned.contains("__remember_cfg.set_value("):
		_note_save_keys(scanned, _cached_regex("__remember_cfg\\.set_value\\(\"[^\"]*\",\\s*\"([^\"]+)\""), remembered)
	var saved: Dictionary = slot_keys.duplicate()
	for key: String in snapshot.keys():
		saved[key] = true
	return {
		"saved": _sorted_keys(saved),
		"slot_keys": _sorted_keys(slot_keys),
		"loaded": _sorted_keys(loaded),
		"remembered": _sorted_keys(remembered)
	}


## The source with every whole-line comment removed (the line itself stays, so nothing shifts that
## the caller might count on). A `#` mid-line is left alone: telling a real `#` from one inside a
## string needs a parser, and dropping the rest of such a line could hide a genuine call.
static func _without_comment_lines(source: String) -> String:
	if not source.contains("#"):
		return source
	var kept: PackedStringArray = PackedStringArray()
	for line: String in source.split("\n"):
		kept.append("" if line.strip_edges().begins_with("#") else line)
	return "\n".join(kept)


## The regex that finds one family of Save System calls and captures its KEY literal.
## `key_position` is 1 when the key is the first argument and 2 when it follows one plain argument.
## `require_receiver` demands a `something.` in front (a real call, never a `func load_value(`
## declaration); writes drop that demand so a wrapper of any shape still registers as a write.
## An argument list containing a call of its own stops the match dead, which is intended: a
## computed key is not decidable, and silence is the correct answer to what we cannot read.
##
## The leading argument may itself be a STRING - `save_group_state("enemies", "enemy_state")` is the
## documented way to snapshot a group - so the alternation admits a quoted literal as well as a
## plain token. Leaving it out made every documented Save Group State row invisible as a write while
## its Load Group State partner still matched as a read: a false accusation about working code.
static func _save_call_pattern(methods: PackedStringArray, key_position: int, require_receiver: bool) -> RegEx:
	var lead: String = "\\." if require_receiver else "(?:^|[^A-Za-z0-9_])"
	var before_key: String = "" if key_position <= 1 else "(?:\"[^\"]*\"|[^\"(),\\n]+),\\s*"
	return _cached_regex("%s(?:%s)\\(\\s*%s\"([^\"]+)\"" % [lead, "|".join(methods), before_key])


static func _note_save_keys(source: String, pattern: RegEx, into: Dictionary) -> void:
	for found: RegExMatch in pattern.search_all(source):
		into[found.get_string(1)] = true


## The keys a `save_state()` returns. A value persisted through the save_state/load_state seam IS
## written - counting it is what keeps the check quiet about a pack (or a hand-written node) that
## saves through the seam rather than through a Save Value row.
##
## The seam is found at ANY indentation, because an inner `class Inner:` carrying its own save_state
## is exactly the shape a pack author reaches for when several sub-objects each snapshot themselves;
## the body then ends where the indentation returns to the declaration's own level or shallower.
static func _note_snapshot_keys(source: String, into: Dictionary) -> void:
	if not source.contains("func save_state("):
		return
	var key_pattern: RegEx = _cached_regex("\"([^\"]+)\"\\s*:")
	var inside: bool = false
	var declared_indent: int = 0
	for line: String in source.split("\n"):
		var stripped: String = line.strip_edges()
		if stripped.begins_with("func save_state(") or stripped.begins_with("static func save_state("):
			inside = true
			declared_indent = line.length() - line.lstrip("\t ").length()
			continue
		if not inside:
			continue
		if not stripped.is_empty() and (line.length() - line.lstrip("\t ").length()) <= declared_indent:
			inside = false
			continue
		_note_save_keys(line, key_pattern, into)


static func _sorted_keys(keys: Dictionary) -> PackedStringArray:
	var sorted: Array = keys.keys()
	sorted.sort()
	return PackedStringArray(sorted)


## Compiled regexes reused across every scanned script - this check compiles five patterns and
## would otherwise rebuild them once per file in the project.
static var _regex_cache: Dictionary = {}


static func _cached_regex(pattern: String) -> RegEx:
	if not _regex_cache.has(pattern):
		_regex_cache[pattern] = RegEx.create_from_string(pattern)
	return _regex_cache[pattern]


## Scene-mutating verbs an editor tool typically reaches for. If a tool sheet's output edits
## the open scene through these WITHOUT registering undo, the user's Ctrl+Z can't take the
## change back - the classic first-editor-tool mistake.
const _SCENE_MUTATORS := ["add_child(", "queue_free(", "remove_child(", "reparent(", "set_owner(", ".owner = "]


static func check_editor_tool_undo(sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	for sheet_path: String in sheet_paths:
		var sheet: EventSheetResource = load(sheet_path) as EventSheetResource
		if sheet == null or not sheet.tool_mode:
			continue
		var output_path: String = output_path_for(sheet_path)
		if not FileAccess.file_exists(output_path):
			continue  # the stale-output check owns the "not compiled yet" case
		var output: String = source_of(output_path)
		if not output.contains("get_edited_scene_root("):
			continue  # not touching the open scene - nothing to undo
		var mutates: bool = false
		for mutator: String in _SCENE_MUTATORS:
			if output.contains(mutator):
				mutates = true
				break
		if not mutates:
			continue
		if output.contains("EditorUndoRedoManager") or output.contains("create_action("):
			continue
		_add(findings, "info", "editor-tool-undo", sheet_path,
			"This editor tool changes the open scene (add/remove/reparent nodes) without registering undo, so Ctrl+Z can't take the change back. Wrap the edits in EditorInterface.get_editor_undo_redo() create_action/commit_action (ignore for one-off scripts you re-run freely).")


## Where an editor's own helpers live - the folders swept for edits made around the funnel rather
## than through it. Only ever read in the editor's OWN repo (see the gate in the check below).
const _HELPER_FOLDERS: PackedStringArray = [
	"res://addons/eventsheet/editor/dock", "res://addons/eventsheet/editor/interaction"
]

## The spellings that change the sheet the user has open. Each one is a write through the LIVE
## sheet, which is what makes it an edit rather than a row being assembled before it is applied.
const _LIVE_SHEET_WRITES: PackedStringArray = [
	"_current_sheet.events.append(", "_current_sheet.events.remove_at(", "_current_sheet.events.insert(",
	"_current_sheet.events.clear(", "_current_sheet.functions.append(", "_current_sheet.functions.remove_at(",
	"_current_sheet.variables["
]


## The undo funnel is ONE door: every edit to the open sheet goes through it, and one that does
## not is a change the user's Ctrl+Z cannot take back - the same fault the editor-tool check above
## names, one level in. Advisory, never an error: a helper may legitimately write to a sheet it made
## itself, and the note says which line to look at.
##
## Only ever runs in the editor's own repo. An ordinary game project has no helpers of this kind and
## must see nothing.
static func check_sheet_edit_funnel(findings: Array[Dictionary]) -> void:
	if not EventSheetEditorSourceFacts.is_editor_project():
		return
	for folder: String in _HELPER_FOLDERS:
		for file_name: String in DirAccess.get_files_at(folder):
			if file_name.get_extension() != "gd":
				continue
			var path: String = folder.path_join(file_name)
			var source: String = source_of(path)
			if source.is_empty():
				continue
			var write: String = sheet_edit_outside_funnel(source)
			if write.is_empty():
				continue
			_add(findings, "info", "sheet-edit-outside-funnel", path,
				"This helper changes the open sheet directly (%s) instead of going through the one undoable-edit funnel, so the change is not one step the user can undo. Wrap it in the sheet-edit funnel." % write)


## The write that goes around the funnel in one file's source, "" when there is none. Pure, so the
## gate can pin the judgement without a folder full of files to judge.
static func sheet_edit_outside_funnel(source: String) -> String:
	for method: String in EventSheetEditorSourceFacts.FUNNEL_METHODS:
		if source.contains("%s(" % method):
			return ""
	if source.contains("%s" % EventSheetEditorSourceFacts.FUNNEL_WORD):
		return ""
	for write: String in _LIVE_SHEET_WRITES:
		if source.contains(write):
			return write.trim_suffix("(")
	return ""


## The three mistakes every FIRST editor tool makes, beside the undo one above. Each is a
## note, never an error: all three are legal Godot, and each is occasionally exactly what the author
## meant - a tool that really does want to walk the whole project, a generator that really does want
## to throw away what it made, a preview that really is supposed to animate while you edit.
##
## The reading is off the COMPILED output rather than the sheet, because that is where the shape
## actually is: a sheet can reach the same lines through a Script block, a raw row or a picked verb,
## and the check should say the same thing about all three.
static func check_editor_tool_safety(sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	for sheet_path: String in sheet_paths:
		var sheet: EventSheetResource = load(sheet_path) as EventSheetResource
		if sheet == null or not sheet.tool_mode:
			continue
		var output_path: String = output_path_for(sheet_path)
		if not FileAccess.file_exists(output_path):
			continue  # the stale-output check owns the "not compiled yet" case
		var output: String = source_of(output_path)
		# 1. Reaching outside the layout the user has open. `get_tree()` in the editor process walks
		# the EDITOR's own tree, not the scene being edited, which is almost never what was meant.
		if output.contains("get_tree().get_nodes_in_group(") or output.contains("get_tree().call_group("):
			_add(findings, "info", "editor-tool-scope", sheet_path,
				"This editor tool reaches for nodes through get_tree(), which in the editor is the editor's own tree and not the layout you have open. Walk Editor.OpenLayout (the edited scene root) instead, or the tool will find nothing - or the wrong thing.")
		# 1b. The same mistake one step subtler, and the one every first tool makes. A tool that
		# CHANGES the scene while addressing nodes by path is addressing them against itself: an
		# EditorScript or an EditorPlugin is not in the scene you have open, so `get_node("Player")`
		# resolves in the editor's own tree (or nowhere at all) and the edit lands outside the layout.
		# Reaching the edited scene root anywhere in the file is the opt-out, because that IS the fix.
		if _touches_nodes_outside_open_layout(output):
			_add(findings, "info", "editor-tool-outside-layout", sheet_path,
				"This editor tool changes nodes it looked up by path, but never starts from the layout you have open - so in the editor those paths resolve against the editor itself and the change lands outside your scene (or nowhere). Start from Editor.OpenLayout (the edited scene root) and walk down from there.")
		# 2. Destroying things while editing. A queue_free in the editor deletes from the OPEN scene,
		# and without an undo step the only way back is to close the scene without saving.
		if output.contains("queue_free()") and not output.contains("create_action("):
			_add(findings, "info", "editor-tool-destroy", sheet_path,
				"This editor tool calls Destroy while running in the editor, so it deletes from the layout you have open. Register an undo step around it, or the only way back is closing the scene without saving.")
		# 3. Ticking in the editor with no way to switch it off - the guard.
		if _ticks_without_editor_guard(output):
			_add(findings, "info", "editor-tool-tick", sheet_path,
				"This tool runs every tick in the editor, so it is running right now while you edit. Add a Preview in editor toggle - an exported true/false plus a Stop event when the sheet is in the editor and the toggle is off - so you can switch it off.")


## The spellings that hand a function to a thread, and the group of them the reading calls
## "Run in the background".
const _BACKGROUND_HANDOFFS: PackedStringArray = [
	".start(", "WorkerThreadPool.add_task(", "WorkerThreadPool.add_group_task("
]

## The steps that reach the scene tree. None of them is safe off the main thread, and every one
## of them is a step a reader would think nothing of - which is exactly why the note is worth making.
const _SCENE_TOUCHES: PackedStringArray = [
	"add_child(", "remove_child(", "queue_free()", "get_node(", "get_node_or_null(", "get_tree()",
	"instantiate()", "emit_signal(", "get_parent()"
]


## Work that has left the main thread must not touch the scene tree - Godot's nodes are not
## thread-safe, and the failure is a crash that happens one run in twenty rather than an error.
##
## The check is deliberately narrow: a file that hands a NAMED function to a thread, and that
## function's own body reaching the tree. A thread handed a lambda, or a function this walk cannot
## find, says nothing at all, because a warning that fires on shapes it cannot see would be noise.
static func check_background_thread_safety(sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	for sheet_path: String in sheet_paths:
		var output_path: String = output_path_for(sheet_path)
		if not FileAccess.file_exists(output_path):
			continue  # the stale-output check owns the "not compiled yet" case
		var output: String = source_of(output_path)
		for function_name: String in _backgrounded_function_names(output):
			if not _function_body_touches_tree(output, function_name):
				continue
			_add(findings, "warning", "background-thread-touches-tree", sheet_path,
				"%s runs in the background, and its rows reach the scene tree. Nodes are not thread-safe: a crash from this happens one run in twenty rather than every time. Work out the answer in the background and let the main thread do the node steps - a signal fired when the work is done is the usual shape." % function_name)


## Every function name this file hands to a thread, from the `f.bind(...)` and bare-name
## spellings both. Empty when the file starts no background work at all, which is the common case
## and costs one substring search.
static func _backgrounded_function_names(output: String) -> PackedStringArray:
	var handed: PackedStringArray = PackedStringArray()
	var starts_work: bool = false
	for handoff: String in _BACKGROUND_HANDOFFS:
		if output.contains(handoff):
			starts_work = true
			break
	if not starts_work:
		return handed
	var found: Array[RegExMatch] = _cached_regex(
		"(?:\\.start\\(|WorkerThreadPool\\.add_task\\(|WorkerThreadPool\\.add_group_task\\()(?:self\\.)?([A-Za-z_][A-Za-z0-9_]*)").search_all(output)
	for entry: RegExMatch in found:
		var name_text: String = entry.get_string(1)
		if not handed.has(name_text):
			handed.append(name_text)
	return handed


## True when the named function's own body reaches the scene tree. The body is the lines from its
## `func` header to the next top-level `func`, which is all a text walk can honestly claim.
static func _function_body_touches_tree(output: String, function_name: String) -> bool:
	var lines: PackedStringArray = output.split("\n")
	var inside: bool = false
	for line: String in lines:
		var stripped: String = line.strip_edges()
		if stripped.begins_with("func ") or stripped.begins_with("static func "):
			inside = stripped.contains("func %s(" % function_name)
			continue
		if not inside or stripped.begins_with("#"):
			continue
		for touch: String in _SCENE_TOUCHES:
			if stripped.contains(touch):
				return true
	return false


## True when a compiled @tool script MUTATES the scene and reaches its nodes by path without
## ever anchoring on the edited scene root. Both halves are required: looking things up by path is
## perfectly fine in a tool that only reads, and mutating is fine once the walk starts from the open
## layout - it is the combination that silently edits the wrong tree.
static func _touches_nodes_outside_open_layout(output: String) -> bool:
	if output.contains("get_edited_scene_root("):
		return false
	var mutates: bool = false
	for mutator: String in _SCENE_MUTATORS:
		if output.contains(mutator):
			mutates = true
			break
	if not mutates:
		return false
	return output.contains("get_node(") or output.contains("get_node_or_null(")


## True when a compiled @tool script has a per-frame handler and NO editor guard in it. The guard
## is the shipped pattern - `Engine.is_editor_hint()` reached in the same file - so a tool that already
## checks where it is running is left alone whatever it does with the answer.
static func _ticks_without_editor_guard(output: String) -> bool:
	if not (output.contains("func _process(") or output.contains("func _physics_process(")):
		return false
	return not output.contains("Engine.is_editor_hint()") and not output.contains("OS.has_feature(\"editor\")")


## The sheet a generated script belongs to - the inverse of output_path_for.
## Trusts the script's "# Source:" header first (exact), then sibling naming
## verified through the pairing rule. "" when the script isn't sheet-generated.
static func sheet_for_script(script_path: String) -> String:
	if script_path.is_empty() or not FileAccess.file_exists(script_path):
		return ""
	var header: String = source_of(script_path).left(400)
	var found: RegExMatch = RegEx.create_from_string("(?m)^# Source: (.+\\.tres)$").search(header)
	if found != null and FileAccess.file_exists(found.get_string(1)):
		return found.get_string(1)
	var sibling: String = script_path.get_basename().trim_suffix("_generated") + ".tres"
	if FileAccess.file_exists(sibling) and ResourceLoader.load(sibling, "", ResourceLoader.CACHE_MODE_REUSE) is EventSheetResource and output_path_for(sibling) == script_path:
		return sibling
	# A behaviour/addon pack .gd IS its own sheet (no .tres companion) - it pairs to itself. EventForge
	# sheets carry `## @ace_*` annotations (exposed ACEs / tags / triggers); hand-written scripts do not.
	if script_path.get_extension().to_lower() == "gd" and RegEx.create_from_string("(?m)^## @ace_").search(source_of(script_path)) != null:
		return script_path
	return ""


## Every scene that references a script path - the reverse lookup the attachment
## check and the dock's Run Scene share (sorted for stable pick menus).
static func scenes_attaching(script_path: String) -> PackedStringArray:
	var matches: PackedStringArray = PackedStringArray()
	for scene_path: String in _list_files_with_extension("tscn"):
		if source_of(scene_path).contains(script_path):
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
		var numbers: Dictionary = EventSheetResource.event_numbers(sheet.events)
		for entry: Variant in sheet.events:
			if entry is EventRow and _is_per_frame_trigger((entry as EventRow).trigger_id):
				_scan_unbounded_loops(entry as EventRow, sheet_path, threshold, findings, numbers)


static func _is_per_frame_trigger(trigger_id: String) -> bool:
	return trigger_id == "OnProcess" or trigger_id == "OnPhysicsProcess"


## A BLANK top-level event runs every tick - that is what blank means in an event sheet. When
## such an event does nothing but set values (no conditions, no sub-events, every action a Set), it
## is almost always meant to run ONCE, at the start, and the every-tick repeat is a surprise. Note
## tier, because a per-tick set is legal and sometimes deliberate.
static func check_every_tick_setup(sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	for sheet_path: String in sheet_paths:
		if sheet_path.begins_with("res://eventsheet_addons/"):
			continue
		var sheet: EventSheetResource = load(sheet_path) as EventSheetResource
		if sheet == null:
			continue
		var numbers: Dictionary = EventSheetResource.event_numbers(sheet.events)
		for entry: Variant in sheet.events:
			if not (entry is EventRow):
				continue
			var event: EventRow = entry as EventRow
			if not _is_setup_only_blank_event(event):
				continue
			_add(findings, "info", "every-tick-setup", sheet_path,
				"This blank event runs every tick and only sets values - did you mean On start of layout?",
				int(numbers.get(event.get_instance_id(), 0)))


## True for a blank top-level event whose whole body is setting things: no trigger picked, no
## conditions, no sub-events, no picking, and every action a Set.
static func _is_setup_only_blank_event(event: EventRow) -> bool:
	if event == null or not event.enabled or not event.trigger_id.is_empty():
		return false
	if not event.conditions.is_empty() or not event.sub_events.is_empty():
		return false
	if not event.pick_filters.is_empty() or event.actions.is_empty():
		return false
	if not event.with_node_target.strip_edges().is_empty():
		return false
	for action_entry: Variant in event.actions:
		if not (action_entry is ACEAction):
			return false
		if not str((action_entry as ACEAction).ace_id).begins_with("Set"):
			return false
	return true


## Walks an event + its sub-events for unbounded, unbudgeted For Each loops with >= threshold actions.
static func _scan_unbounded_loops(event: EventRow, sheet_path: String, threshold: int, findings: Array[Dictionary], numbers: Dictionary = {}) -> void:
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
				"A per-frame For Each here loops over '%s' with %d actions, uncapped and unbudgeted - if it's slow, spread it across frames with the Time Slicer pack or a Budgeted For Each." % [pick.iterator_name, event.actions.size()],
					int(numbers.get(event.get_instance_id(), 0)))
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
		var numbers: Dictionary = EventSheetResource.event_numbers(sheet.events)
		for entry: Variant in sheet.events:
			if entry is EventRow and _is_per_frame_trigger((entry as EventRow).trigger_id):
				_scan_coroutine_misuse(entry as EventRow, sheet_path, findings, numbers)


static func _scan_coroutine_misuse(event: EventRow, sheet_path: String, findings: Array[Dictionary], numbers: Dictionary = {}) -> void:
	# A Once At A Time gate makes the overlap impossible (the event skips itself while a
	# previous run is still suspended), so the warning would be crying wolf - stay silent.
	for condition: Variant in event.conditions:
		if condition is ACECondition and (condition as ACECondition).enabled and (condition as ACECondition).ace_id == "SingleFlight":
			return
	for action: Variant in event.actions:
		var flagged: String = ""
		if action is ACEAction and COROUTINE_ACE_IDS.has((action as ACEAction).ace_id):
			flagged = (action as ACEAction).ace_id
		elif action is RawCodeRow and (action as RawCodeRow).code.contains("await "):
			flagged = "await"
		if not flagged.is_empty():
			_add(findings, "warning", "coroutine-in-per-frame", sheet_path,
				"A coroutine action ('%s') runs under a per-frame trigger (On Process / On Physics Process). The next tick fires while the previous run may still be suspended, so the handler overlaps itself and double-processes. Move it to a one-shot trigger (On Ready / On Signal / a custom function), or use the Time Slicer pack." % flagged,
					int(numbers.get(event.get_instance_id(), 0)))
			break
	for sub: Variant in event.sub_events:
		if sub is EventRow:
			_scan_coroutine_misuse(sub as EventRow, sheet_path, findings, numbers)


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
		# Absolute reaches count too: a god-sheet built entirely on /root/... paths is the WORST breadth,
		# and excluding them let exactly that case report clean. Keyed bare so it reads as absolute.
		targets[reference if reference.begins_with("/") else "$" + reference] = true
	for unique_name: String in ACEParamsDialog.unique_names_in_expression(text):
		targets["%" + unique_name] = true


## A node path that reaches the SCENE ROOT (absolute /root/...) or climbs TWO OR MORE parents (../../..)
## is fragile: it assumes exactly where a node lives, so it breaks silently the moment a node is moved or
## renamed - the "your nodes are too connected" smell. Advisory (info): a single ../Sibling is fine and is
## NOT flagged; this only catches absolute and deep parent reaches, and points at a group / scene-unique
## node / Connect Group Signal so the sheet reacts without depending on the tree shape.
static func check_fragile_node_paths(sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	for sheet_path: String in sheet_paths:
		if sheet_path.begins_with("res://eventsheet_addons/"):
			continue
		var sheet: EventSheetResource = load(sheet_path) as EventSheetResource
		if sheet == null:
			continue
		var fragile: Dictionary = {}
		_collect_fragile_paths(sheet.events, fragile)
		for function_entry: Variant in sheet.functions:
			if function_entry is EventFunction:
				var event_function: EventFunction = function_entry
				_collect_fragile_paths(event_function.events if not event_function.events.is_empty() else event_function.rows, fragile)
		if not fragile.is_empty():
			var paths: Array = fragile.keys()
			paths.sort()
			_add(findings, "info", "fragile-node-path", sheet_path,
				"This sheet reaches across the tree with %d fragile node path(s) (%s) - an absolute or multi-level parent path breaks silently when a node moves or is renamed. Prefer a group (get_first_node_in_group), a scene-unique node, or Connect Group Signal to react without depending on where a node lives." % [fragile.size(), ", ".join(PackedStringArray(paths))])


## Same walk as _collect_external_targets, collecting only the FRAGILE references (absolute / deep parent).
static func _collect_fragile_paths(rows: Array, fragile: Dictionary) -> void:
	for row: Variant in rows:
		if row is RawCodeRow:
			_note_fragile_paths((row as RawCodeRow).code, fragile)
		elif row is EventGroup:
			var group: EventGroup = row
			_collect_fragile_paths(group.events if not group.events.is_empty() else group.rows, fragile)
		elif row is EventRow:
			var event: EventRow = row
			_note_fragile_paths(event.with_node_target, fragile)
			for ace: Variant in event.conditions + event.actions:
				if ace is RawCodeRow:
					_note_fragile_paths((ace as RawCodeRow).code, fragile)
				elif ace is Resource and ace.get("params") is Dictionary:
					for value: Variant in (ace.get("params") as Dictionary).values():
						_note_fragile_paths(str(value), fragile)
			_collect_fragile_paths(event.sub_events, fragile)


## Records a node reference only when it is absolute (leading /) or climbs two-or-more parents (../../..).
static func _note_fragile_paths(text: String, fragile: Dictionary) -> void:
	if text.strip_edges().is_empty():
		return
	for reference: String in ACEParamsDialog.node_references_in_expression(text):
		if reference.begins_with("/") or reference.count("../") >= 2:
			fragile[reference] = true


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
		corpus_parts.append(source_of(scene_path))
	for property: Dictionary in ProjectSettings.get_property_list():
		if str(property.get("name", "")).begins_with("autoload/"):
			corpus_parts.append(str(ProjectSettings.get_setting(str(property.get("name")))))
	var corpus: String = "\n".join(corpus_parts)
	var class_regex: RegEx = RegEx.create_from_string("(?m)^class_name\\s+([A-Za-z_][A-Za-z0-9_]*)")
	for script_path: String in pack_scripts:
		var found: RegExMatch = class_regex.search(source_of(script_path))
		if found == null:
			continue
		var pack_class: String = found.get_string(1)
		if corpus.contains(script_path) or RegEx.create_from_string("\\b%s\\b" % pack_class).search(corpus) != null:
			continue
		_add(findings, "info", "unused-pack", script_path,
			"Pack class %s is referenced by no sheet, scene or autoload - fine if you call it from hand-written GDScript." % pack_class)


## Packs declare what they need with `## @ace_requires(a, b)` - class names,
## "autoload:Name", or "pack:folder" entries. An IN-USE pack whose requirement is missing
## gets a warning (an unused pack's unmet dependency is noise, so those stay silent).
static func check_pack_dependencies(sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	var pack_scripts: Array[String] = EventSheetAddonScanner.list_addon_scripts()
	if pack_scripts.is_empty():
		return
	# The same in-use corpus check_unused_packs builds: sheets (minus packs referencing
	# themselves), scenes, and autoload targets.
	var corpus_parts: PackedStringArray = PackedStringArray()
	for sheet_path: String in sheet_paths:
		if sheet_path.begins_with("res://eventsheet_addons/"):
			continue
		var sheet: EventSheetResource = load(sheet_path) as EventSheetResource
		if sheet == null:
			continue
		corpus_parts.append(_sheet_usage_text(sheet))
		corpus_parts.append(" ".join(sheet.uses_addons) + " " + " ".join(sheet.requires_behaviors)
			+ " " + " ".join(sheet.ace_provider_scripts) + " " + " ".join(sheet.includes))
	for scene_path: String in _list_files_with_extension("tscn"):
		corpus_parts.append(source_of(scene_path))
	for property: Dictionary in ProjectSettings.get_property_list():
		if str(property.get("name", "")).begins_with("autoload/"):
			corpus_parts.append(str(ProjectSettings.get_setting(str(property.get("name")))))
	var corpus: String = "\n".join(corpus_parts)
	var class_regex: RegEx = RegEx.create_from_string("(?m)^class_name\\s+([A-Za-z_][A-Za-z0-9_]*)")
	var requires_regex: RegEx = RegEx.create_from_string("(?m)^## @ace_requires\\(([^)]*)\\)")
	for script_path: String in pack_scripts:
		var pack_source: String = source_of(script_path)
		var requires_match: RegExMatch = requires_regex.search(pack_source)
		if requires_match == null:
			continue
		var class_match: RegExMatch = class_regex.search(pack_source)
		var pack_class: String = class_match.get_string(1) if class_match != null else script_path.get_file()
		var in_use: bool = corpus.contains(script_path)
		if not in_use and class_match != null:
			in_use = RegEx.create_from_string("\\b%s\\b" % pack_class).search(corpus) != null
		if not in_use:
			continue
		var missing: Array[String] = []
		for requires_token: String in requires_match.get_string(1).split(","):
			var requirement: String = requires_token.strip_edges()
			if not requirement.is_empty() and not _requirement_present(requirement):
				missing.append(requirement)
		if missing.is_empty():
			continue
		missing.sort()
		_add(findings, "warning", "pack-dependency", script_path,
			"Pack class %s requires %s, which isn't present - install the pack it names (or register the autoload)." % [pack_class, ", ".join(missing)])


## Obvious param type mismatches, and ONLY obvious ones: a param declared float/int/bool
## holding a plain literal of the wrong kind (a quoted string in a number slot, a number in
## a bool slot). Expressions, identifiers, and String-typed params are NEVER judged -
## expressions are opaque by design, and a String param legitimately holds anything. The
## conservatism is the feature: this check must never cry wolf.
static func check_param_type_mismatches(sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	for sheet_path: String in sheet_paths:
		var sheet: EventSheetResource = load(sheet_path) as EventSheetResource
		if sheet == null:
			continue
		for entry: Variant in sheet.events:
			if entry is EventRow:
				_scan_param_types(entry as EventRow, sheet_path, findings)


## The two notes a variable row grows on the canvas, said again where a whole project is
## audited: a `variable_reference` naming something this sheet does not declare (an error, because
## the emitted line names an identifier that is not there) and a variable handed to a verb that wants
## another kind (a warning, because it compiles and only misbehaves).
##
## The sentences are the ROWS' own, word for word - unknown_note and variable_mismatch_note are the
## same two calls the canvas makes - so somebody who met one on a row meets the same wording in the
## report rather than two descriptions of one problem.
static func check_variable_notes(sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	for sheet_path: String in sheet_paths:
		var sheet: EventSheetResource = load(sheet_path) as EventSheetResource
		if sheet == null:
			continue
		var entries: Array[Dictionary] = EventSheetVariableOwners.own_entries(sheet)
		if entries.is_empty():
			continue
		_scan_variable_notes(sheet.events, sheet_path, entries,
			EventSheetVariableOwners.owner_of_sheet(sheet), findings)


static func _scan_variable_notes(rows: Array, sheet_path: String, entries: Array[Dictionary],
		owner: String, findings: Array[Dictionary]) -> void:
	for entry: Variant in rows:
		if entry is EventGroup:
			_scan_variable_notes(EventSheetGroupFacts.children(entry as EventGroup), sheet_path,
				entries, owner, findings)
			continue
		if not (entry is EventRow):
			continue
		var event: EventRow = entry as EventRow
		for ace: Variant in (event.conditions + event.actions):
			if not (ace is ACECondition or ace is ACEAction):
				continue
			var ace_id: String = str(ace.get("ace_id"))
			var descriptor: ACEDescriptor = ACERegistry.find_descriptor(str(ace.get("provider_id")), ace_id)
			if descriptor == null:
				continue
			var params: Dictionary = ace.get("params") if ace.get("params") is Dictionary else {}
			for name_text: String in EventSheetVariableOwners.variable_reference_values(descriptor.params, params):
				# A qualified spelling (`Game.Score`) is somebody else's declaration, and this sheet's
				# own list is the wrong place to look for it - the same guard the row makes.
				if not EventSheetIdentifierRules.is_valid(name_text):
					continue
				var unknown: Dictionary = EventSheetVariableOwners.unknown_note(entries, name_text, owner)
				if not unknown.is_empty():
					_add(findings, "error", "unknown-variable", sheet_path, str(unknown.get("note", "")))
					continue
				var mismatch: Dictionary = ViewportRowBuilder.variable_mismatch_note(
					EventSheetVariableOwners.find(entries, name_text), ace_id)
				if not mismatch.is_empty():
					_add(findings, "warning", "variable-type-mismatch", sheet_path, str(mismatch.get("note", "")))
		_scan_variable_notes(event.sub_events, sheet_path, entries, owner, findings)


## A note row carrying Godot's own error text, pasted raw. The runtime-error strip already re-says
## every failure in the sheet's words, so a note that still speaks engine ("Invalid call.
## Nonexistent function…") is a wall someone hit and then stored - the finding points at it so it
## can be re-said as the row would say it, or fixed and deleted. A note, never an error: the sheet
## compiles fine, it just talks to its reader in the wrong language.
static func check_raw_error_notes(sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	for sheet_path: String in sheet_paths:
		var sheet: EventSheetResource = load(sheet_path) as EventSheetResource
		if sheet != null:
			_scan_raw_error_notes(sheet.events, sheet_path, findings)


static func _scan_raw_error_notes(rows: Array, sheet_path: String, findings: Array[Dictionary]) -> void:
	for entry: Variant in rows:
		if entry is EventGroup:
			var group: EventGroup = entry as EventGroup
			_scan_raw_error_notes(group.events if not group.events.is_empty() else group.rows,
				sheet_path, findings)
			continue
		if entry is EventRow:
			_scan_raw_error_notes((entry as EventRow).sub_events, sheet_path, findings)
			continue
		if not (entry is CommentRow):
			continue
		var comment: CommentRow = entry as CommentRow
		if EventSheetRuntimeErrorWords.looks_like_engine_error(comment.text):
			_add(findings, "info", "raw-error-note", sheet_path,
				"A note here is Godot's own error text (\"%s…\") - re-say it in the sheet's words, or fix the cause and delete it." % comment.text.strip_edges().left(60))


## A `#region` fence with no partner, in the same words the row shows under the orphan itself.
## A warning, never an error: the file still compiles, and the fence only fails to fold.
static func check_region_fences(sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	for sheet_path: String in sheet_paths:
		var sheet: EventSheetResource = load(sheet_path) as EventSheetResource
		if sheet != null:
			_scan_region_fences(sheet.events, sheet_path, findings)


## Fences pair WITHIN one container, which is why every group body is walked as its own list - the
## same walk the canvas folds by, so the Doctor and the row can never disagree about what is orphaned.
static func _scan_region_fences(container: Array, sheet_path: String, findings: Array[Dictionary]) -> void:
	var pairing: Dictionary = EventSheetRegionFacts.pairing(container)
	for opener_index: int in (pairing.get("orphan_openers", []) as Array):
		_add(findings, "warning", "region-fence", sheet_path,
			EventSheetRegionFacts.unclosed_note(container[opener_index]))
	for _closer_index: int in (pairing.get("orphan_closers", []) as Array):
		_add(findings, "warning", "region-fence", sheet_path, EventSheetRegionFacts.unopened_note())
	for entry: Variant in container:
		if entry is EventGroup:
			_scan_region_fences(EventSheetGroupFacts.children(entry as EventGroup), sheet_path, findings)


static func _scan_param_types(event: EventRow, sheet_path: String, findings: Array[Dictionary]) -> void:
	var aces: Array = []
	aces.append_array(event.conditions)
	aces.append_array(event.actions)
	if event.trigger != null:
		aces.append(event.trigger)
	for ace: Variant in aces:
		if not (ace is ACECondition or ace is ACEAction):
			continue
		var descriptor: ACEDescriptor = ACERegistry.find_descriptor(str(ace.get("provider_id")), str(ace.get("ace_id")))
		if descriptor == null:
			continue
		var params: Dictionary = ace.get("params") if ace.get("params") is Dictionary else {}
		for param: ACEParam in descriptor.params:
			var mismatch: String = literal_type_mismatch(str(param.type_name), str(params.get(param.id, "")))
			if not mismatch.is_empty():
				_add(findings, "info", "param-type", sheet_path,
					"%s's \"%s\" expects %s but holds %s - double-check the value." % [descriptor.get_list_name(), param.id, str(param.type_name), mismatch])
	for sub: Variant in event.sub_events:
		if sub is EventRow:
			_scan_param_types(sub as EventRow, sheet_path, findings)


## "" when fine; otherwise a short description of the wrong literal. Judges ONLY
## unambiguous whole-value literals against float/int/bool declarations.
static func literal_type_mismatch(declared_type: String, value: String) -> String:
	var trimmed: String = value.strip_edges()
	if trimmed.is_empty():
		return ""
	var is_quoted: bool = trimmed.length() >= 2 and trimmed.begins_with("\"") and trimmed.ends_with("\"") and not trimmed.trim_prefix("\"").trim_suffix("\"").contains("\"")
	var is_bool: bool = trimmed == "true" or trimmed == "false"
	var is_number: bool = trimmed.is_valid_float()
	match declared_type:
		"float", "int":
			if is_quoted:
				return "a quoted string (%s)" % trimmed
			if is_bool:
				return "a bool (%s)" % trimmed
		"bool":
			if is_quoted:
				return "a quoted string (%s)" % trimmed
			if is_number:
				return "a number (%s)" % trimmed
	return ""


## The movement packs' gravity_angle rotates the whole movement frame, but Platformer
## Pathfinding plans in a straight-down frame (the graph, jump arcs, and steering are all
## screen x/y) - rotated-gravity paths come out wrong. Advisory: the angle in the scene
## might belong to a Bullet arc instead, so this only asks the author to check.
static func check_rotated_gravity_pathfinding(findings: Array[Dictionary]) -> void:
	for scene_path: String in _list_files_with_extension("tscn"):
		var scene_text: String = source_of(scene_path)
		if scene_text.contains("gravity_angle") and scene_text.contains("platformer_pathfinding"):
			_add(findings, "info", "rotated-gravity-pathfinding", scene_path,
				"This scene sets a gravity_angle and uses Platformer Pathfinding, which plans with straight-down gravity - if the angle is on the movement pack, planned paths will be wrong.")


## Whether one @ace_requires entry is satisfied: "autoload:Name" checks Project Settings,
## "pack:folder" checks the installed pack folders, and a bare name checks engine AND
## project global classes (ClassDB alone doesn't know user class_names).
static func _requirement_present(requirement: String) -> bool:
	if requirement.begins_with("autoload:"):
		return ProjectSettings.has_setting("autoload/%s" % requirement.trim_prefix("autoload:").strip_edges())
	if requirement.begins_with("pack:"):
		var folder: String = requirement.trim_prefix("pack:").strip_edges()
		for script_path: String in EventSheetAddonScanner.list_addon_scripts():
			if script_path.begins_with("res://eventsheet_addons/%s/" % folder):
				return true
		return false
	if ClassDB.class_exists(requirement):
		return true
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if str(entry.get("class", "")) == requirement:
			return true
	return false


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
		var output_text: String = source_of(output_path)
		if output_text.contains("tr(\"") or output_text.contains("tr_n(\"") or output_text.contains("TranslationServer.set_locale"):
			_add(findings, "info", "l10n", sheet_path,
				"This sheet translates text (tr / Set Language) but the project has no translations registered - generate a POT (Project Settings > Localization > POT Generation, add the compiled .gd), translate it, and add the catalog under Localization > Translations.")
			return


## THE LOCALISATION GATE the two checks below share, and the reason they can never argue with the
## check above. check_untranslated_project fires only while the project has NO catalog registered
## ("you translate but nothing is installed"); these two fire only once one IS registered ("you have
## begun localising, so here is what is still English"). The two halves are mutually exclusive, and a
## project that never localises at all gets neither - which is the point, because most Godot games
## ship in one language on purpose and every finding they would get is noise.
static func _project_has_translation_catalogs() -> bool:
	return not (ProjectSettings.get_setting("internationalization/locale/translations", PackedStringArray()) as PackedStringArray).is_empty()


## Player-facing text that was never marked translatable. The globe on a string parameter defaults to
## OFF, which is correct - most params are node paths, group names, animation names and amounts - and
## the cost of that default is that "we will localise later" fails SILENTLY: the string ships as a
## bare literal, Godot's POT generation (which reads tr() calls out of the compiled .gd) never sees
## it, and the bug surfaces months later as one English line in an otherwise translated menu.
##
## NOT CRYING WOLF IS THE WHOLE FEATURE, so the accusation is narrow on every axis at once:
##   - it fires ONLY once the project has a translation catalog registered (the gate above);
##   - it reads the EMITTED SCRIPTS, for the reason check_save_key_symmetry documents - `.gd` is the
##     default sheet format while list_project_sheets() finds only `.tres`, and the literal is in the
##     emitted code either way;
##   - a literal is judged ONLY where it reaches a TEXT SINK (an assignment into text / tooltip_text
##     / placeholder_text / bbcode_text, a set_text-family call, a Dialogue Kit queued line). A node
##     path, a group name, an animation name, an input action or a print / push_error message never
##     reaches one, so translating an identifier - which breaks lookups, as the guide says - can
##     never be suggested here;
##   - a sink line that already mentions tr() or tr_n() is skipped whole, so a partly-marked line is
##     never nagged about its remaining fragment;
##   - a value that is not TEXT is skipped: empty, a number, anything holding a "/" (a path or a node
##     path), and anything without two consecutive letters ("%d", ":", "00:00", "[b][/b]");
##   - a receiver-less `text = "..."` in a script that declares its own `text` variable is an ordinary
##     string being built, not a property write, and is never accused;
##   - and a string the project ALREADY marks somewhere - it appears inside a tr() call in any script,
##     or it is a key in a real translation catalog .csv (columns that name languages, checked against
##     the engine's own locale table, never just any spreadsheet) - is never accused, because a Control
##     auto-translates its own text at display time, so that string genuinely does translate.
## Info tier: advisory, never fails CI. One finding per script, naming the strings, because a menu
## script would otherwise produce twenty.
static func check_unmarked_player_text(_sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	if not _project_has_translation_catalogs():
		return
	var known: Dictionary = _catalog_keys()
	var candidates: Dictionary = {}
	for script_path: String in _project_scripts():
		# A pack is shipped vocabulary the project author did not write and cannot usefully edit.
		if script_path.begins_with("res://eventsheet_addons/"):
			continue
		var source: String = source_of(script_path)
		if source.is_empty():
			continue
		for marked: String in marked_translation_literals(source):
			known[marked] = true
		var unmarked: PackedStringArray = unmarked_player_text(source)
		if not unmarked.is_empty():
			candidates[script_path] = unmarked
	var paths: Array = candidates.keys()
	paths.sort()
	for script_path: String in paths:
		var reportable: PackedStringArray = PackedStringArray()
		for literal: String in candidates[script_path] as PackedStringArray:
			if not known.has(literal):
				reportable.append(literal)
		if reportable.is_empty():
			continue
		_add(findings, "info", "l10n-unmarked", script_path,
			"%s shown to the player %s not marked translatable (%s). Godot's POT generation only sees text inside tr(), so these never reach the translator and ship in one language. In a sheet, right-click the action > Edit Action and click the globe beside the field (it ships the value as tr(\"...\")); in hand-written code wrap the string in tr(). Ignore a string that is never read as words." % [
				("%d strings" % reportable.size()) if reportable.size() > 1 else "1 string",
				"are" if reportable.size() > 1 else "is",
				_quoted_sample(reportable)])


## Text that stays in the OLD language after Set Language - the most-reported localisation bug in any
## engine, and a silent one. Godot re-translates an auto-translated Control for free, so a title typed
## into the SCENE follows the switch; a label an EVENT filled from tr() holds the string tr() returned
## at the time, and keeps the old language until the scene is loaded again. (Verified on 4.7: a
## Label's text assigned from a tr() result does not change when the locale changes, while the same
## Label's measured size DOES follow the locale when its text is a bare source string.)
##
## It is decidable from emitted code, which is what makes it worth shipping: a script assigns text
## from a tr() value and the script has no translation-changed handler ANYWHERE. The clean patterns it
## must never accuse, each one silenced deliberately:
##   - a script that already reacts (it mentions NOTIFICATION_TRANSLATION_CHANGED, or a custom
##     language_changed / locale_changed signal) - which includes the exact shape this finding
##     recommends, so the check can never accuse its own fix;
##   - an assignment inside _process / _physics_process / _draw / _notification, which re-runs on its
##     own and therefore cannot go stale;
##   - a script that never assigns text from tr() at all - a bare literal is the other check's
##     business, because a Control auto-translates that one at display time.
## Info tier, one finding per script, naming the functions that fill the text.
static func check_stale_translated_labels(_sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	if not _project_has_translation_catalogs():
		return
	for script_path: String in _project_scripts():
		if script_path.begins_with("res://eventsheet_addons/"):
			continue
		var source: String = source_of(script_path)
		if source.is_empty():
			continue
		var stale: PackedStringArray = stale_translated_text_functions(source)
		if stale.is_empty():
			continue
		_add(findings, "info", "l10n-stale-label", script_path,
			"This script fills text from tr() in %s, but nothing here runs again when the language changes - so those labels keep the OLD language until the scene is loaded again (text typed into the scene follows a switch by itself; text an event filled does not). Add an On Language Changed event that re-runs them: right-click the actions > Extract All Actions to Function…, then Add Event > Translation > On Language Changed > Call Function. Ignore this if the whole screen is rebuilt after a language switch." % _function_list(stale))


## The property names an assignment must land on to count as player-facing TEXT. Deliberately short:
## every one of them is a Control property the engine itself auto-translates, so a string arriving
## here is being SHOWN, not used as an identifier. Longest first, so the alternation cannot match
## `text` inside `bbcode_text`.
const _TEXT_SINK_PROPERTIES: PackedStringArray = ["placeholder_text", "tooltip_text", "bbcode_text", "text"]

## Setter calls that are the same sink written as a method.
const _TEXT_SINK_METHODS: PackedStringArray = ["set_placeholder_text", "set_tooltip_text", "set_text", "append_text", "add_text"]

## Functions that re-run on their own, so text they fill can never be stale.
const _SELF_REFRESHING_FUNCTIONS: PackedStringArray = ["_process", "_physics_process", "_draw", "_notification"]

## Evidence that a script already reacts to a language switch. The engine has no locale-changed
## SIGNAL (which is why On Language Changed compiles to the _notification virtual), so a project that
## routes its own signal instead is recognised by name rather than being accused of the bug it solved.
const _REFRESH_MARKERS: PackedStringArray = ["NOTIFICATION_TRANSLATION_CHANGED", "language_changed", "locale_changed"]


## The player-facing string literals one script SOURCE shows without marking translatable. Pure (text
## in, strings out) so the whole rule is pinned without planting an unmarked fixture in this project -
## which would make the Doctor report on this repo forever, the exact noise the check exists to avoid.
static func unmarked_player_text(source: String) -> PackedStringArray:
	var unmarked: PackedStringArray = PackedStringArray()
	# Comments are stripped BEFORE the cheap substring gate too, so a script whose only "text" is the
	# word inside a comment is not treated as a text sink at all.
	var scanned: String = _without_comment_lines(source)
	if not _has_text_sink(scanned):
		return unmarked
	var declared: Dictionary = _declared_text_locals(scanned)
	var seen: Dictionary = {}
	for line: String in scanned.split("\n"):
		var stripped: String = line.strip_edges()
		if stripped.is_empty():
			continue
		for literal: String in _sink_literals(stripped, declared):
			if seen.has(literal) or not _is_player_text(literal):
				continue
			seen[literal] = true
			unmarked.append(literal)
	return unmarked


## Every string one source ALREADY marks translatable - the literal inside a tr() / tr_n() call. This
## is the corpus that keeps the check quiet about a key another sheet (or another line) translates:
## the Control auto-translates its own text at display time, so a literal the catalog knows really
## does reach the player in their language.
static func marked_translation_literals(source: String) -> PackedStringArray:
	var marked: PackedStringArray = PackedStringArray()
	if not source.contains("tr("):
		return marked
	var scanned: String = _without_comment_lines(source)
	for found: RegExMatch in _cached_regex("\\btr(?:_n)?\\(\\s*\"").search_all(scanned):
		var literals: PackedStringArray = _string_literals_in(scanned.substr(found.get_end() - 1))
		if not literals.is_empty():
			marked.append(literals[0])
	return marked


## The functions in one source that fill text from tr() while nothing in the script reacts to a
## language switch. Pure, and empty for every clean shape (see check_stale_translated_labels).
static func stale_translated_text_functions(source: String) -> PackedStringArray:
	var stale: PackedStringArray = PackedStringArray()
	# EVERY rule here reads the comment-stripped source, the markers included. Testing the raw text
	# for them let one comment ("handle language_changed one day") switch the whole check off for the
	# script - and a project mid-localisation is exactly where that TODO gets written.
	var scanned: String = _without_comment_lines(source)
	if not scanned.contains("tr(") or not _has_text_sink(scanned):
		return stale
	for marker: String in _REFRESH_MARKERS:
		if scanned.contains(marker):
			return stale
	var declared: Dictionary = _declared_text_locals(scanned)
	var declaration: RegEx = _cached_regex("^(?:static\\s+)?func\\s+([A-Za-z_][A-Za-z0-9_]*)")
	var current_function: String = ""
	var seen: Dictionary = {}
	for line: String in scanned.split("\n"):
		var stripped: String = line.strip_edges()
		if stripped.is_empty():
			continue
		var declaring: RegExMatch = declaration.search(stripped)
		if declaring != null:
			current_function = declaring.get_string(1)
			continue
		if current_function.is_empty() or _SELF_REFRESHING_FUNCTIONS.has(current_function):
			continue
		if seen.has(current_function) or not _translates_into_text_sink(stripped, declared):
			continue
		seen[current_function] = true
		stale.append(current_function)
	return stale


## Whether a source touches a text sink at all - one substring scan that skips the great majority of
## scripts before any regex runs.
static func _has_text_sink(source: String) -> bool:
	for property_name: String in _TEXT_SINK_PROPERTIES:
		if source.contains(property_name):
			return true
	return source.contains("queue_line(")


## The string literals ONE line hands to a text sink, or none. A line that already mentions tr() is
## skipped whole: the author is translating there, and nagging about the remaining fragment of a
## partly-marked line is exactly the alert fatigue that gets a check switched off.
static func _sink_literals(stripped_line: String, declared: Dictionary = {}) -> PackedStringArray:
	if _mentions_translation_call(stripped_line):
		return PackedStringArray()
	var assigned: String = _text_sink_assignment(stripped_line, declared)
	if not assigned.is_empty():
		return _string_literals_in(assigned)
	var called: RegExMatch = _cached_regex("\\.(?:%s)\\(" % "|".join(_TEXT_SINK_METHODS)).search(stripped_line)
	if called != null:
		return _judged_arguments(_call_arguments(stripped_line.substr(called.get_end())))
	# Dialogue Kit queues a SPEAKER and a LINE. The speaker is an id the game matches on, so the
	# first argument is never judged - and the split is on real arguments, so a comma inside the
	# speaker's own name cannot shift which one is which.
	var queued: RegExMatch = _cached_regex("\\.queue_line\\(").search(stripped_line)
	if queued == null:
		return PackedStringArray()
	var queued_arguments: PackedStringArray = _call_arguments(stripped_line.substr(queued.get_end()))
	return _literals_in_all(queued_arguments.slice(1)) if queued_arguments.size() > 1 else PackedStringArray()


## The literals a sink CALL is judged on. Control.set_text takes exactly ONE argument, so a call handed
## two is somebody else's set_text - HUD Kit's set_text(label_name, text) is the shipped example - and
## its leading argument is an identifier a translator must never be offered. Splitting real arguments
## rather than quotes is what makes that safe: set_text("Score: %s" % [name]) is ONE argument, so the
## format string is still judged, while set_text("StatusLabel", "Ready") is two and only "Ready" is.
static func _judged_arguments(arguments: PackedStringArray) -> PackedStringArray:
	return _literals_in_all(arguments.slice(1) if arguments.size() > 1 else arguments)


static func _literals_in_all(arguments: PackedStringArray) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for argument: String in arguments:
		found.append_array(_string_literals_in(argument))
	return found


## One call's argument list, split on the commas that are actually at the TOP level of it: a comma
## inside a string, a nested call, an array or a dictionary does not separate arguments. Reading stops
## at the call's own closing bracket, so a second call later on the same line cannot leak in.
static func _call_arguments(after_open_bracket: String) -> PackedStringArray:
	var arguments: PackedStringArray = PackedStringArray()
	var current: String = ""
	var depth: int = 0
	var index: int = 0
	while index < after_open_bracket.length():
		var character: String = after_open_bracket[index]
		if character == "\"":
			var literal_end: int = _end_of_literal(after_open_bracket, index)
			current += after_open_bracket.substr(index, literal_end - index)
			index = literal_end
			continue
		if character == "(" or character == "[" or character == "{":
			depth += 1
		elif character == ")" and depth == 0:
			break
		elif character == ")" or character == "]" or character == "}":
			depth -= 1
		elif character == "," and depth == 0:
			arguments.append(current)
			current = ""
			index += 1
			continue
		current += character
		index += 1
	if not current.strip_edges().is_empty():
		arguments.append(current)
	return arguments


## The index one past the double-quoted literal starting at `start`, or the end of the text when the
## quote is never closed (a multi-line literal), so the scan always makes progress.
static func _end_of_literal(text: String, start: int) -> int:
	var index: int = start + 1
	while index < text.length():
		if text[index] == "\\":
			index += 2
			continue
		if text[index] == "\"":
			return index + 1
		index += 1
	return text.length()


## Whether one line assigns a tr() value into a text sink - the stale-label shape.
static func _translates_into_text_sink(stripped_line: String, declared: Dictionary = {}) -> bool:
	if not _mentions_translation_call(stripped_line):
		return false
	var assigned: String = _text_sink_assignment(stripped_line, declared)
	if not assigned.is_empty():
		return _mentions_translation_call(assigned)
	return _cached_regex("\\.(?:%s)\\(" % "|".join(_TEXT_SINK_METHODS)).search(stripped_line) != null


## Whether a fragment really calls tr() or tr_n(). It has to be a WORD boundary and not a substring
## scan, because `str(` ends in `tr(` - and the plugin's own Set Text emits `text = str({value})`, so
## a plain `contains("tr(")` reads EVERY Set Text row as already translated and silently switches both
## checks off on exactly the sink they were built for. `.tr(` (String.tr on a variable) counts too.
static func _mentions_translation_call(text: String) -> bool:
	if not (text.contains("tr(") or text.contains("tr_n(")):
		return false
	return _cached_regex("(?:^|[^A-Za-z0-9_])tr(?:_n)?\\(").search(text) != null


## The right-hand side of a `<node>.text = ...` assignment, or "" when the line is not one.
##
## The optional `<receiver>.` prefix is what tells a real property write from a DECLARATION:
## `$Title.text = "x"` and a host-scoped `text = "x"` both match, while `var text = "x"` and
## `var label_text = "x"` cannot, because with no dot in front the property name would have to start
## the line. `+=` counts (appending to a label is still filling it); `==`, `!=`, `<=` and `>=` cannot,
## so a comparison is never read as a write.
##
## THE RECEIVER MUST LOOK LIKE A NODE, and that narrowing is the difference between a check people
## keep switched on and one they mute. `text` is an extremely common field name on ordinary data
## objects - this plugin's own comment rows have one - and `row.text = "short note"` is not player
## text at all. Nothing in a source file says which class `row` is, so only receivers that are
## SYNTACTICALLY a node are judged: `$Path`, `%Unique`, a get_node()/find_child() call, `self`, or no
## receiver at all (the host, which for a Set Text row is the Control the sheet is attached to). A
## label reached through a plain variable is missed on purpose: missing one costs silence, accusing a
## working game costs the whole check.
static func _text_sink_assignment(stripped_line: String, declared: Dictionary = {}) -> String:
	var found: RegExMatch = _cached_regex("^(?:([^=\\n]*)\\.)?(%s)\\s*\\+?=(?!=)\\s*(.+)$" % "|".join(_TEXT_SINK_PROPERTIES)).search(stripped_line)
	if found == null or not _is_node_receiver(found.get_string(1)):
		return ""
	if found.get_string(1).strip_edges().is_empty() and declared.has(found.get_string(2)):
		# A receiver-less `text = ...` is the HOST's property - unless this script declares its own
		# `text` variable or parameter, in which case the very same line is an ordinary string being
		# built (`var text := ""` further up, then `text = "Report for the day"`). The declaration is
		# the only thing that tells the two apart, and accusing a working script is what gets a check
		# muted for good.
		return ""
	return found.get_string(3)


## The sink property names this source declares as ORDINARY variables - `var text`, `const text`, or
## a parameter called `text`. Narrow on purpose: it only ever silences the receiver-less form above,
## so `$Label.text = "..."` in the same script is judged exactly as it was.
static func _declared_text_locals(source: String) -> Dictionary:
	var declared: Dictionary = {}
	for property_name: String in _TEXT_SINK_PROPERTIES:
		if not source.contains(property_name):
			continue
		var pattern: String = "(?:^|[^A-Za-z0-9_])(?:var|const)\\s+%s(?![A-Za-z0-9_])|[(,]\\s*%s\\s*[:=]" % [property_name, property_name]
		if _cached_regex(pattern).search(source) != null:
			declared[property_name] = true
	return declared


## Whether what stands in front of `.text` is a node rather than some other object holding a field of
## that name. Empty means the host itself.
static func _is_node_receiver(receiver: String) -> bool:
	var trimmed: String = receiver.strip_edges()
	if trimmed.is_empty() or trimmed == "self":
		return true
	if trimmed.begins_with("$") or trimmed.begins_with("%"):
		return true
	return _cached_regex("(?:^|[^A-Za-z0-9_])(?:get_node|get_node_or_null|get_child|find_child|get_parent)\\(").search(trimmed) != null


## Whether a literal reads as TEXT a player is meant to understand. Everything rejected here is
## rejected because translating it would be WRONG, not merely unnecessary: a number, a path or node
## path (a "/" anywhere), and anything without two consecutive letters - "%d", ":", "00:00",
## "[b][/b]" - are scaffolding, and a translator handed them would break the game.
##
## BBCode tags are stripped BEFORE those rules run, so "[b]Boss defeated[/b]" is judged on the words
## a player reads. Without that, the closing tag's own "/" makes every styled RichTextLabel line look
## like a file path - and styled lines are the ones most likely to be real prose. Stripping cannot
## rescue a path, because "res://save/slot1.tres" carries no brackets to strip.
static func _is_player_text(literal: String) -> bool:
	var trimmed: String = _cached_regex("\\[/?[^\\[\\]]*\\]").sub(literal.strip_edges(), "", true).strip_edges()
	if trimmed.is_empty() or trimmed.is_valid_float() or trimmed.contains("/"):
		return false
	return _cached_regex("[A-Za-z]{2}").search(trimmed) != null


## The double-quoted literals in a fragment of GDScript, unescaped only as far as the backslash pairs
## (a `\"` stops the scan from closing early; `\n` stays spelled the way the author typed it, so the
## finding quotes back what is really in the file). An UNTERMINATED quote yields nothing, which is how
## a multi-line string literal is skipped rather than half-read.
static func _string_literals_in(text: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var index: int = 0
	while index < text.length():
		if text[index] != "\"":
			index += 1
			continue
		index += 1
		var literal: String = ""
		var closed: bool = false
		while index < text.length():
			if text[index] == "\\" and index + 1 < text.length():
				literal += text.substr(index, 2)
				index += 2
				continue
			if text[index] == "\"":
				closed = true
				index += 1
				break
			literal += text[index]
			index += 1
		if closed:
			found.append(literal)
	return found


## Every source string a catalog .csv in the project already keys - its FIRST column, which is what
## Godot's CSV translation format keys by. A key the translator already holds is not missing text,
## whichever way it reached the label.
## A CATALOG, not merely a .csv. Godot's translation CSV names a language in every column after the
## first, and a language is checkable rather than guessable: get_locale_name hands back the code
## itself for something that is not one (checked on 4.7 - "de" reads "German", "price" reads
## "price"). Without this gate the FIRST COLUMN OF EVERY SPREADSHEET IN THE PROJECT became an
## allowlist: a designer's loot table keyed by item name, or a grid exported by this plugin's own
## "Export Grid to CSV…", would silence a real unmarked-text finding for every title it holds.
static func _is_catalog_header(header: PackedStringArray) -> bool:
	if header.size() < 2:
		return false
	for index: int in range(1, header.size()):
		var column: String = header[index].strip_edges()
		if column.is_empty():
			continue
		if column == "qps" or TranslationServer.get_locale_name(column) != column:
			return true
	return false


static func _catalog_keys() -> Dictionary:
	var keys: Dictionary = {}
	for csv_path: String in _list_files_with_extension("csv"):
		# A shipped pack carries its own UI vocabulary in a translations.csv beside it. Those are the
		# plugin's words, not the game's, and folding them in silences a genuine finding for every
		# word the two happen to share ("Play", "Settings", "Back").
		if csv_path.begins_with("res://eventsheet_addons/"):
			continue
		var file: FileAccess = FileAccess.open(csv_path, FileAccess.READ)
		if file == null:
			continue
		var header: PackedStringArray = file.get_csv_line()
		if not _is_catalog_header(header):
			file.close()
			continue
		while not file.eof_reached():
			var row: PackedStringArray = file.get_csv_line()
			if not row.is_empty() and not row[0].strip_edges().is_empty():
				keys[row[0]] = true
		file.close()
	return keys


## Up to four strings quoted for a finding, with the rest counted rather than listed - a menu script
## would otherwise produce a message nobody reads to the end. Long strings are cut so one paragraph
## of dialogue cannot swallow the message.
static func _quoted_sample(literals: PackedStringArray) -> String:
	var shown: PackedStringArray = PackedStringArray()
	for index: int in mini(literals.size(), 4):
		var literal: String = literals[index]
		shown.append("\"%s\"" % ((literal.left(40) + "...") if literal.length() > 40 else literal))
	if literals.size() > shown.size():
		shown.append("and %d more" % (literals.size() - shown.size()))
	return ", ".join(shown)


## Function names read as prose: "_ready()", "_ready() and refresh()", "a(), b() and c()".
static func _function_list(names: PackedStringArray) -> String:
	var called: PackedStringArray = PackedStringArray()
	for function_name: String in names:
		called.append("%s()" % function_name)
	if called.size() == 1:
		return called[0]
	return "%s and %s" % [", ".join(called.slice(0, called.size() - 1)), called[called.size() - 1]]


## Rows an import from another event-sheet editor could not spell. The importer switches each one
## off and writes its original words into the file, so the words are still there for a reader - but
## nobody reads a file top to bottom looking for them. This finds them and says how many.
##
## Info tier: an imported project is a work in progress, not a broken one.
static func check_imported_rows(_sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	for script_path: String in _project_scripts():
		var source: String = source_of(script_path)
		if not source.contains(EventSheetForeignImporter.TALLY_PREFIX):
			continue
		var pending: int = 0
		for line: String in source.split("
"):
			if line.begins_with(EventSheetForeignImporter.TALLY_PREFIX):
				pending += 1
		_add(findings, "info", "imported-row", script_path,
			"%s from an imported event sheet still switched off, with the original words beside %s. Each one needs the row that says the same thing here, or the shipped behaviour the note names. Delete the note once the row is back." % [
				("%d rows" % pending) if pending > 1 else "1 row",
				"them" if pending > 1 else "it"])


static func check_vocabulary_doc(findings: Array[Dictionary]) -> void:
	var path: String = EventSheetVocabularyDoc.doc_path()
	if not FileAccess.file_exists(path):
		return
	if source_of(path) != EventSheetVocabularyDoc.generate():
		_add(findings, "info", "vocabulary-doc", path,
			"Vocabulary doc is stale - regenerate via Tools → Vocabulary Doc… or tools/vocabulary_doc.gd.")


## A Godot group and the inheritance set of the same name are the two halves of one idea, and
## they drift: a script joins the "enemy" group without extending Enemy, and the first row that
## calls an Enemy function on it fails at runtime with "Invalid call". The check says which script,
## which group and which base class, once per stray.
##
## Read entirely from what the project already declares - its global class list, and the literal
## `add_to_group("x")` lines of the scripts on it - so nothing is instantiated and nothing is loaded.
## A group whose name matches no declared class is not a disagreement, it is just a group.
static func check_family_group_agreement(findings: Array[Dictionary]) -> void:
	var families: Dictionary = EventSheetFamilyFacts.project_families()
	if families.is_empty():
		return
	# The base a group name stands for, matched the way a reader matches them: by name, ignoring case.
	var base_by_group: Dictionary = {}
	for base: String in families:
		base_by_group[base.to_lower()] = base
	for entry: Variant in ProjectSettings.get_global_class_list():
		var record: Dictionary = entry
		var class_text: String = str(record.get("class", "")).strip_edges()
		var path: String = str(record.get("path", ""))
		if class_text.is_empty() or path.is_empty():
			continue
		var facts: Dictionary = EventSheetObjectFacts.script_facts(path)
		for group: Variant in (facts.get("families", PackedStringArray()) as PackedStringArray):
			var group_name: String = str(group).strip_edges()
			var base_name: String = str(base_by_group.get(group_name.to_lower(), ""))
			if base_name.is_empty() or base_name == class_text:
				continue
			var members: PackedStringArray = (families[base_name] as Dictionary).get(
				"members", PackedStringArray())
			if members.has(class_text):
				continue
			_add(findings, "warning", "family-group-drift", path,
				EventSheetFamilyFacts.stray_message(base_name, group_name, class_text, false))


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


## A control the project's scripts ask for that the Input Map does not have. `is_action_pressed("dash")`
## when there is no `dash` is the typo every beginner makes: it compiles, it prints nothing, and the
## key simply never works. The fix is one line in Project Settings, which is why the finding names it.
##
## This reads the project's `.gd` files as TEXT rather than the sheet model, because `.gd` is the
## default sheet format while list_project_sheets() only finds `.tres` - a model-based check would
## skip most real projects while looking like it works - and because a hand-written script that names
## a missing control is exactly as broken as a generated one.
static func check_unknown_input_actions(_sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	for script_path: String in _list_files_with_extension("gd"):
		var file: FileAccess = FileAccess.open(script_path, FileAccess.READ)
		if file == null:
			continue
		var source: String = file.get_as_text()
		file.close()
		var missing: PackedStringArray = PackedStringArray()
		for action_name: String in EventSheetInputMapFacts.action_names_in(source):
			if not EventSheetInputMapFacts.has_action(action_name) \
					and not ProjectSettings.has_setting("input/%s" % action_name) \
					and not missing.has(action_name):
				missing.append(action_name)
		if missing.is_empty():
			continue
		_add(findings, "warning", "unknown-input-action", script_path,
			"This script names %d control(s) the Input Map does not have (%s) - the key will never fire and nothing will say so. Add it in Project ▸ Input Map, or fix the spelling." % [
				missing.size(), ", ".join(missing)])
		# The control's own name, so the quick fix on the row can add it without reading the
		# message back out of English.
		findings[findings.size() - 1]["subject"] = missing[0]


## Bindings changed at runtime but never saved. A rebind screen that calls
## `InputMap.action_add_event` without ever writing the result anywhere loses every remap the moment
## the game closes, and the player has to do it again on every launch. The one thing every first
## rebind screen forgets.
static func check_unsaved_rebindings(_sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	for script_path: String in _list_files_with_extension("gd"):
		var file: FileAccess = FileAccess.open(script_path, FileAccess.READ)
		if file == null:
			continue
		var source: String = file.get_as_text()
		file.close()
		if not (source.contains("InputMap.action_add_event") or source.contains("InputMap.action_erase_events")):
			continue
		# Anything that persists them counts: the sheet's own Save bindings, a ConfigFile, a save
		# file, or the project's settings written back.
		if source.contains("ConfigFile") or source.contains("save_settings") \
				or source.contains("ProjectSettings.save") or source.contains("store_var"):
			continue
		_add(findings, "info", "unsaved-rebindings", script_path,
			"This script changes control bindings at runtime but never saves them - every remap is lost when the game closes. Add Save bindings after the rebind and Load bindings on start-up.")


## Sounds played with nothing for a player who cannot hear them to read. OPT IN: a project
## that has not decided to caption its audio would get one note per script for a decision it has not
## made, which is how a Doctor stops being read. Turn it on with `eventsheets/doctor/caption_sounds`
## and it names, per script, how many one-shot sounds are played beyond the captions it shows.
##
## Counted from the EMITTED code rather than from the sheets: `.gd` is the default sheet format, so a
## check built on the `.tres` sheet list would quietly skip most real projects while looking like it
## worked. `set_meta("__last_sfx"` is the one-shot Play Sound's own mark, which nothing else writes.
const CAPTION_SOUND_MARK := "set_meta(\"__last_sfx\""
const CAPTION_SHOW_MARK := "\"show_caption\""


static func _captions_wanted() -> bool:
	return bool(ProjectSettings.get_setting("eventsheets/doctor/caption_sounds", false))


static func check_caption_less_sounds(_sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	if not _captions_wanted():
		return
	for script_path: String in _list_files_with_extension("gd"):
		if script_path.begins_with("res://addons/") or script_path.begins_with("res://eventsheet_addons/"):
			continue
		var file: FileAccess = FileAccess.open(script_path, FileAccess.READ)
		if file == null:
			continue
		var source: String = file.get_as_text()
		file.close()
		var played: int = source.count(CAPTION_SOUND_MARK)
		if played == 0:
			continue
		var captioned: int = source.count(CAPTION_SHOW_MARK)
		if captioned >= played:
			continue
		_add(findings, "info", "caption-less-sound", script_path,
			"This script plays %d sound(s) with no caption - a player who cannot hear them is told nothing. Use Play Sound With Caption for the ones that carry information (a door, a reload, a warning), and leave the rest blank on purpose." % [played - captioned])


## The reading check, as a Doctor check on this project's own packs. Same rule as the Publish
## dialog and the shipped-pack gate, because it is the same function: a pack whose published
## conditions, actions or expressions do not read as sentences is named here with the fix, and
## carries its score until it passes. A note, never an error - a pack that does not read still
## works, it just does not keep the promise the sheet makes about itself.
static func check_pack_reading(findings: Array[Dictionary]) -> void:
	for pack: Dictionary in EventSheetPackCatalog.packs():
		var script_path: String = str(pack.get("path", ""))
		if script_path.is_empty():
			continue
		var result: Dictionary = EventSheetPackReadingCheck.check_script(script_path)
		if bool(result.get("reads", false)):
			continue
		var failures: Array = result.get("failures", [])
		var first: String = "" if failures.is_empty() else EventSheetPackReadingCheck.failure_line(failures[0])
		_add(findings, "info", "pack-reading", script_path,
			"%s reads %d%% - %d thing(s) do not read as sentences. First: %s" % [
				str(pack.get("name", "")), int(result.get("percent", 0)), failures.size(), first])
		findings[findings.size() - 1]["subject"] = str(pack.get("dir", ""))


## A sheet still using a pack that was switched off in the Addon manager. Its actions have left
## the picker, so the row can no longer be edited in the sheet's own words - which is worth
## saying out loud rather than leaving as a row that quietly stopped offering anything.
static func check_disabled_pack_usage(_sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	var disabled: PackedStringArray = EventSheetPackCatalog.disabled_packs()
	if disabled.is_empty():
		return
	for pack_dir: String in disabled:
		var pack: Dictionary = EventSheetPackCatalog.describe(pack_dir)
		if pack.is_empty():
			continue
		var identifier: String = str(pack.get("path", "")).get_file().get_basename()
		var users: PackedStringArray = PackedStringArray()
		for script_path: String in _list_files_with_extension("gd"):
			if script_path.begins_with("res://eventsheet_addons/"):
				continue
			var file: FileAccess = FileAccess.open(script_path, FileAccess.READ)
			if file == null:
				continue
			var source: String = file.get_as_text()
			file.close()
			if source.contains(identifier) and not users.has(script_path):
				users.append(script_path)
		if users.is_empty():
			continue
		_add(findings, "warning", "disabled-pack-in-use", users[0],
			"%s is switched off in the Addon manager, but %d sheet(s) still use it - its actions have left the picker, so those rows can no longer be edited in the sheet's own words. Switch it back on, or replace the rows." % [
				str(pack.get("name", pack_dir)), users.size()])
		findings[findings.size() - 1]["subject"] = pack_dir


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
	# Path order, always - the directory walk hands files back in filesystem order (near-alphabetical
	# on NTFS, hash order on ext4), and this order is the order findings appear in the report.
	found.sort()
	return found


## Calls to a behaviour verb that no longer exists - the ONE failure in this plugin that compiles
## green and breaks at game runtime.
##
## Renaming a provider's function changes the verb's identity, so every row that used it is orphaned.
## Nothing catches that today: ActionCodegen prefers the template BAKED onto the row at apply time
## over any registry lookup, so the sheet still emits `$Player/WeaponKit.fire(...)` with zero errors
## and zero warnings, and Godot only complains when the player pulls the trigger.
##
## This reads the EMITTED CALLS rather than the sheet model, for two reasons. The failure lives in
## the emitted code, so that is where it is true. And `.gd` is the default sheet format but
## list_project_sheets() only finds `.tres`, so a model-based check would miss most projects
## outright - while a generated sheet is deliberately indistinguishable from hand-written GDScript
## (the parity covenant), so there is no marker to filter on and no need for one: a script calling a
## member that its provider does not have is wrong whoever wrote it.
##
## CONSERVATISM IS THE FEATURE - a lint that cries wolf gets switched off, and a false positive here
## would accuse someone's working game of being broken. It reports ONLY when every one of these is
## true: the class name resolves to a provider script we actually found, that script parses, and the
## member is absent from its own API, its whole script-inheritance chain, AND its engine base class.
## Anything unresolved is silence.
##
## THE ONE KNOWN LIMITATION: this reads raw source, so a provider call written inside a STRING
## literal (a doc string, a code generator, a test fixture) looks exactly like a real one and is
## flagged. Telling them apart needs a real GDScript parse, which is a far larger machine than the
## problem justifies. Two smaller guards keep it honest instead - a node whose last path segment is
## not a known provider class is ignored outright, and the report names the file so a false hit is
## obvious at a glance rather than mysterious.
static func check_orphaned_provider_calls(sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	var providers: Dictionary = _provider_member_index(sheet_paths)
	if providers.is_empty():
		return
	for script_path: String in _project_scripts():
		var source: String = source_of(script_path)
		if source.is_empty():
			continue
		for orphan: Dictionary in orphaned_calls_in_source(source, providers):
			# Refactor-following: when one current member is CLEARLY the renamed one, name it.
			# Silence when nothing is close or two candidates tie - a confident wrong guess
			# sends someone to fix a call that was never the problem.
			var hint: String = EventSheetRefactorFollow.rename_hint(str(orphan["member"]),
				EventSheetRefactorFollow.member_names(providers.get(str(orphan["provider"]), {})))
			if hint.is_empty():
				hint = " If the function was renamed, open Sheet > Custom ACE Providers, select it under its new name and use \"Keep Old Name\" to add a stand-in."
			_add(findings, "error", "orphaned-verb", script_path,
				"%s.%s() does not exist on %s - the call still compiles but will fail at runtime.%s"
					% [str(orphan["provider"]), str(orphan["member"]), str(orphan["path"]).get_file(), hint])


## The four builtin triggers that bind to a signal the SHEET has to declare - On Failure Of, On
## Success Of, On Scene Spawned, On Data File Changed. The compiler is careful here: a sheet that
## never declared the signal still emits the handler, but emits no connection for it, so the script
## compiles perfectly and the event simply NEVER RUNS. That silence is the whole problem - the row
## sits on the canvas looking finished, the recovery branch under it never fires, and nothing
## anywhere says why. This check is the thing that says why.
##
## Emitted OUTPUT is the corpus on purpose, twice over: the failure lives in emitted code, and
## `sheet_paths` lists only `.tres` sheets while `.gd` is the default sheet format. Only generated
## scripts are judged, so a hand-written `_on_verb_failed` connected from somewhere else is never
## accused - the header is what tells the two apart.
const SHEET_DECLARED_TRIGGER_SIGNALS: Array[String] = [
	"verb_failed", "verb_succeeded", "scene_spawned", "data_file_changed",
]


static func check_sheet_signal_declarations(_sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	for script_path: String in _project_scripts():
		var source: String = source_of(script_path)
		if source.is_empty():
			continue
		for signal_name: String in unconnected_trigger_signals(source):
			_add(findings, "warning", "undeclared-trigger-signal", script_path,
				"an event is headed by the %s trigger, but the sheet declares no %s signal - nothing connects the event, so it never runs. Add a Signal row for %s."
					% [signal_name, signal_name, signal_name])


## The pure half: the trigger handlers this generated source carries that nothing can ever call,
## because the signal they belong to was never declared. Kept separate so the rule can be pinned
## without planting a deliberately dead sheet in the project, which would make the Doctor report a
## finding on this repo forever - the very noise the check exists to avoid.
static func unconnected_trigger_signals(source: String) -> PackedStringArray:
	var missing: PackedStringArray = PackedStringArray()
	# begins_with, never contains: the generated header is always line one, and a file that merely
	# TALKS about the convention (this check's own test, for one) must not be read as code.
	if not source.begins_with("# AUTO-GENERATED by EventForge"):
		return missing
	for signal_name: String in SHEET_DECLARED_TRIGGER_SIGNALS:
		if not source.contains("func _on_%s(" % signal_name):
			continue
		if source.contains("signal %s(" % signal_name) or source.contains("signal %s
" % signal_name):
			continue
		if source.contains(".connect(_on_%s)" % signal_name):
			continue
		missing.append(signal_name)
	return missing


## The orphaned calls in one script's SOURCE, as {provider, member, path}. Pure, so the rule can be
## pinned without planting a deliberately broken fixture in the project - which would make the
## Doctor report an error on this repo forever, the very noise the check exists to avoid.
static func orphaned_calls_in_source(source: String, providers: Dictionary) -> Array[Dictionary]:
	var orphans: Array[Dictionary] = []
	# `$Player/WeaponKit.fire(` - a behaviour child node is named for its class, which is the
	# convention the compiler emits against. Also `__eventsheet_provider_Score.add(` for the
	# non-Node providers, where the prefix makes the class unambiguous.
	var node_call: RegEx = RegEx.new()
	node_call.compile("\\$([A-Za-z_][A-Za-z0-9_/]*)\\.([a-z_][A-Za-z0-9_]*)\\(")
	var provider_call: RegEx = RegEx.new()
	provider_call.compile("__eventsheet_provider_([A-Za-z_][A-Za-z0-9_]*)\\.([a-z_][A-Za-z0-9_]*)\\(")
	var reported: Dictionary = {}
	for regex: RegEx in [node_call, provider_call]:
		for found: RegExMatch in regex.search_all(source):
			var reference: String = found.get_string(1)
			# For a node path the LAST segment is the behaviour node, and therefore the class.
			var class_candidate: String = reference.get_slice("/", reference.get_slice_count("/") - 1)
			var member: String = found.get_string(2)
			# An unresolved class is silence: not knowing a thing is not evidence against it.
			if not providers.has(class_candidate):
				continue
			var entry: Dictionary = providers[class_candidate]
			if (entry["members"] as Dictionary).has(member):
				continue
			var key: String = "%s.%s" % [class_candidate, member]
			if reported.has(key):
				continue
			reported[key] = true
			orphans.append({"provider": class_candidate, "member": member, "path": str(entry["path"])})
	return orphans


## class name -> {members: Dictionary, path: String} for every provider script we can find and read.
## A class that does not resolve is simply absent, which is what keeps the check silent about code it
## does not understand.
static func _provider_member_index(sheet_paths: PackedStringArray) -> Dictionary:
	var candidate_paths: Dictionary = {}
	for pack_script: String in EventSheetAddonScanner.list_addon_scripts():
		candidate_paths[pack_script] = true
	for taught: Variant in ProjectSettings.get_setting("eventsheets/vocabulary/taught_provider_scripts", PackedStringArray()):
		candidate_paths[str(taught)] = true
	for sheet_path: String in sheet_paths:
		var sheet: EventSheetResource = load(sheet_path) as EventSheetResource
		if sheet == null:
			continue
		for provider: Variant in sheet.ace_provider_scripts:
			candidate_paths[str(provider)] = true

	var index: Dictionary = {}
	for path: Variant in candidate_paths:
		var script_path: String = str(path)
		if not ResourceLoader.exists(script_path):
			continue
		var script: GDScript = load(script_path) as GDScript
		if script == null:
			continue
		# Matches how a provider id is derived (class_name, else the pascal-cased file name), so the
		# key here is the same string the compiler emitted into the call.
		var class_key: String = str(script.get_global_name())
		if class_key.is_empty():
			class_key = script_path.get_file().get_basename().to_pascal_case()
		if class_key.is_empty() or index.has(class_key):
			continue
		index[class_key] = {"members": _script_member_names(script), "path": script_path}
	return index


## Every name a call on this script could legitimately reach: its own methods, properties and
## signals, the same for every script it extends, and its engine base class through ClassDB. Missing
## any of those lanes would turn an ordinary `$Behaviour.queue_free()` into a false accusation.
static func _script_member_names(script: GDScript) -> Dictionary:
	var names: Dictionary = {}
	var current: GDScript = script
	while current != null:
		for method: Dictionary in current.get_script_method_list():
			names[str(method.get("name", ""))] = true
		for property: Dictionary in current.get_script_property_list():
			names[str(property.get("name", ""))] = true
		for signal_info: Dictionary in current.get_script_signal_list():
			names[str(signal_info.get("name", ""))] = true
		current = current.get_base_script() as GDScript
	var base_type: String = script.get_instance_base_type()
	if not base_type.is_empty() and ClassDB.class_exists(base_type):
		for method: Dictionary in ClassDB.class_get_method_list(base_type, false):
			names[str(method.get("name", ""))] = true
		for property: Dictionary in ClassDB.class_get_property_list(base_type, false):
			names[str(property.get("name", ""))] = true
		for signal_info: Dictionary in ClassDB.class_get_signal_list(base_type, false):
			names[str(signal_info.get("name", ""))] = true
	return names


## A file a merge left unresolved is an ERROR: it does not run, it does not compile, and the one
## thing worse than finding it here is finding it when the game will not start. Read off the raw
## source (a conflicted file has no model to load) and worded exactly as the conflict view offers
## the choice, so the finding and the window that fixes it say the same thing.
static func check_unresolved_conflicts(findings: Array[Dictionary]) -> void:
	for script_path: String in _project_scripts():
		var source: String = source_of(script_path)
		if not EventSheetConflictRegions.has_conflicts(source):
			continue
		_add(findings, "error", "merge-conflict", script_path,
			EventSheetConflictRegions.doctor_message(EventSheetConflictRegions.find(source), script_path.get_file()))


## PLUGIN READING HEALTH, and only in the editor's own repo. One note per role group of the
## editor's own source: how many of its files were read, what share of their rows say nothing of
## their own, and which file in the group reads worst - so the note is clickable straight into it.
##
## Notes, never warnings: this is the project's own dogfood measurement, not a fault in anybody's
## game, and a Doctor that accuses a working project of something gets switched off. Silent in every
## project but this one, which is the same rule the This-editor folder follows.
static func check_plugin_reading_health(findings: Array[Dictionary]) -> void:
	if not EventSheetThisEditor.folder_is_on():
		return
	for entry: Dictionary in EventSheetGenericRows.health_by_role(EventSheetThisEditor.entries()):
		_add(findings, "info", "plugin-reading-health", str(entry.get("worst_path", "")),
			EventSheetGenericRows.health_message(entry))


## Two shared sheets included into one script that both handle the SAME trigger. Both run, in
## include order, and the last one's answer is the one that lasts - which is invisible in the
## includer, because neither handler is written there. Info, not a warning: it is occasionally what
## someone meant, and a lint that accuses a working game gets switched off.
static func check_shared_sheet_includes(findings: Array[Dictionary]) -> void:
	var scripts: PackedStringArray = _project_scripts()
	var shared_by_class: Dictionary = {}
	var sources: Dictionary = {}
	for script_path: String in scripts:
		var source: String = source_of(script_path)
		sources[script_path] = source
		if not EventSheetSharedSheets.is_shared_sheet(source):
			continue
		var shared_class: String = EventSheetSharedSheets.class_name_of(source)
		if not shared_class.is_empty():
			shared_by_class[shared_class] = source
	if shared_by_class.is_empty():
		return
	for script_path: String in scripts:
		var source: String = str(sources[script_path])
		if EventSheetSharedSheets.is_shared_sheet(source):
			continue
		for message: String in EventSheetSharedSheets.duplicate_trigger_messages(source, shared_by_class):
			_add(findings, "info", "shared-sheet-includes", script_path, message)


## THE SKILL TREE ASSETS: the two ways a tree is wrong before it is ever played, and the
## one way it is pointless.
##
## A skill tree is a graph written as text, and text cannot check itself. A `requires` cell naming
## an id the tree does not hold makes a node permanently unreachable, and a cycle - a needs b, b
## needs a - makes a whole branch unreachable, with no error at run time either way: the unlock
## simply refuses forever, which reads as a balance decision rather than a typo. Both are errors,
## because neither has an innocent reading.
##
## The third is advisory: a node that grants nothing and whose id no script anywhere asks about
## costs points and changes the game in no way. That IS sometimes deliberate (a placeholder while a
## tree is being laid out), so it is a warning that names the node rather than a refusal.
##
## Assets are found by SHAPE rather than by class, so a tree still reports when the pack that reads
## it is not installed: a resource with a `skills` list, a `tree_name` and a `starting_points`.
static func check_skill_trees(findings: Array[Dictionary]) -> void:
	var sources: String = ""
	for asset_path: String in _skill_tree_assets():
		var asset: Resource = ResourceLoader.load(asset_path, "", ResourceLoader.CACHE_MODE_REUSE)
		if asset == null:
			continue
		if sources.is_empty():
			sources = _skill_tree_sources()
		check_skill_tree_rows(asset_path, asset.get("skills") as Array, sources, findings)


## The three checks, run against one tree's ROWS - the shape a test can hand in directly
## rather than through a saved asset, and the shape a project's own `.tres` arrives in.
static func check_skill_tree_rows(asset_path: String, rows: Array, sources: String,
		findings: Array[Dictionary]) -> void:
	var requires: Dictionary = {}
	var known: Dictionary = {}
	for entry: Variant in rows:
		if not (entry is Dictionary):
			continue
		var id: String = str((entry as Dictionary).get("id", "")).strip_edges()
		if id.is_empty():
			continue
		if known.has(id):
			_add(findings, "error", "skill-tree", asset_path,
				"Two skills share the id \"%s\". Every action, condition and expression addresses a skill by its id, so the second row can never be reached - rename one of them." % id)
			continue
		known[id] = true
		requires[id] = skill_tree_requires(entry as Dictionary)
	for id: String in requires:
		for required: String in (requires[id] as PackedStringArray):
			if not known.has(required):
				_add(findings, "error", "skill-tree", asset_path,
					"\"%s\" requires \"%s\", which is not a skill in this tree. Nothing can ever unlock it - fix the spelling, or add the skill it is waiting for." % [id, required])
		if skill_tree_cycle(id, requires):
			_add(findings, "error", "skill-tree", asset_path,
				"\"%s\" requires itself, through its own prerequisites. A cycle makes every skill on it permanently locked and never says so at run time - break the loop." % id)
	for id: String in known:
		if not _skill_tree_grants(rows, id).is_empty():
			continue
		if sources.contains("\"%s\"" % id) or sources.contains("'%s'" % id):
			continue
		_add(findings, "warning", "skill-tree", asset_path,
			"\"%s\" grants nothing and no script asks whether it is unlocked, so buying it costs points and changes nothing. Fill in its Grants cell, or read it somewhere with Upgrades > Is Unlocked." % id)


## The prerequisite ids one skill row names, as the asset's comma-separated cell spells them.
static func skill_tree_requires(row: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for part: String in str(row.get("requires", "")).split(","):
		var required: String = part.strip_edges()
		if not required.is_empty() and not out.has(required):
			out.append(required)
	return out


## What a skill grants, or "" when its cell is blank.
static func _skill_tree_grants(rows: Array, id: String) -> String:
	for entry: Variant in rows:
		if entry is Dictionary and str((entry as Dictionary).get("id", "")).strip_edges() == id:
			return str((entry as Dictionary).get("grants", "")).strip_edges()
	return ""


## Whether following a skill's prerequisites ever comes back to the skill itself. Breadth
## first with a visited set, so a tree that is merely wide is walked once and a cycle is caught the
## moment it closes rather than by a depth limit.
static func skill_tree_cycle(start: String, requires: Dictionary) -> bool:
	var seen: Dictionary = {}
	var frontier: PackedStringArray = requires.get(start, PackedStringArray())
	while not frontier.is_empty():
		var next: PackedStringArray = PackedStringArray()
		for id: String in frontier:
			if id == start:
				return true
			if seen.has(id):
				continue
			seen[id] = true
			for deeper: String in (requires.get(id, PackedStringArray()) as PackedStringArray):
				if not next.has(deeper):
					next.append(deeper)
		frontier = next
	return false


## Every project script's text as one string - what the "grants nothing" check asks whether a
## skill id appears in. Read once per doctor run, and only when a candidate is found.
static func _skill_tree_sources() -> String:
	var joined: PackedStringArray = PackedStringArray()
	for script_path: String in _project_scripts():
		joined.append(source_of(script_path))
	return "\n".join(joined)


## Whether a `.tres` is a skill tree, decided from its TEXT. A saved resource stores its
## property names, so the three a tree has are readable without loading anything - which matters,
## because loading every `.tres` in a project to find out would be slow and would report a stale
## reference in an unrelated asset as though the Doctor had gone looking for trouble.
static func _is_skill_tree_text(path: String) -> bool:
	var text: String = source_of(path)
	return text.contains("\nskills = ") and text.contains("\ntree_name = ") \
		and text.contains("\nstarting_points = ")


## Every `.tres` in the project whose shape is a skill tree - a `skills` list beside a
## `tree_name` and a `starting_points`. Found by shape rather than by class so a tree still reports
## when the pack that reads it has been removed from the project.
static func _skill_tree_assets() -> PackedStringArray:
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
			elif entry.ends_with(".tres") and _is_skill_tree_text(full_path):
				var asset: Resource = ResourceLoader.load(full_path, "", ResourceLoader.CACHE_MODE_REUSE)
				if asset != null and asset.get("skills") is Array:
					found.append(full_path)
			entry = directory.get_next()
		directory.list_dir_end()
	# Path order, always - the directory walk hands files back in filesystem order (near-alphabetical
	# on NTFS, hash order on ext4), and this order is the order findings appear in the report.
	found.sort()
	return found


## Every project GDScript, excluding addons/ (the plugin's own code is not a user's game).
##
## HELD between asks. Around forty checks want this list and the walk costs about sixty milliseconds
## on a thousand-file project, so asking it once per check spent over two seconds of every audit
## re-listing directories that had not moved. A run drops it first (below), and so does the editor's
## filesystem ping, which is the same contract every other project-wide read here has.
static func _project_scripts() -> PackedStringArray:
	if _project_scripts_walked:
		return _project_scripts_cache
	var scripts: PackedStringArray = _walk_project_scripts()
	_project_scripts_cache = scripts
	_project_scripts_walked = true
	return scripts


## Forgets the walk above, so the next ask lists the directories again. Called at the top of a run
## and from the editor's filesystem hook. The texts those files hold go with it, for the same reason
## and under the same contract.
static func clear_project_scripts() -> void:
	_project_scripts_cache = PackedStringArray()
	_project_scripts_walked = false
	_source_cache.clear()


## One file's text, read once per audit and handed to every check that asks for it.
##
## Around thirty checks and eight sections walk the project's scripts, and most of them begin by
## asking the same question of the same file - "does this source say anything about my subject" -
## so the same megabytes were being read off disk thirty times for one report. This is the same rule
## the script listing above follows and the same rule the scene parse follows: one read, many
## readers. A run drops it first (below), so an audit still sees a file edited since the last one,
## and drops it again when the report is finished so the texts are not held between runs.
##
## Missing files answer "" exactly as a direct read does, so a caller's own emptiness test is
## unchanged.
##
## Two things are never held. A read taken OUTSIDE a run is not shared at all, because a check asked
## on its own is usually being asked about a fixture that is rewritten between the asks. And a
## `user://` path is a scratch file - a fixture, the verification recompile's own output - written
## and re-read inside one process, where a held read would answer with the file that is no longer
## there. The corpus every check walks is res:// throughout, so nothing the sharing is for is left
## out of it.
static func source_of(path: String) -> String:
	if _source_cache.has(path):
		return _source_cache[path]
	var text: String = FileAccess.get_file_as_string(path)
	if _run_in_progress and path.begins_with("res://"):
		_source_cache[path] = text
	return text


static func _walk_project_scripts() -> PackedStringArray:
	var scripts: PackedStringArray = PackedStringArray()
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
			elif entry.ends_with(".gd"):
				scripts.append(full_path)
			entry = directory.get_next()
		directory.list_dir_end()
	# Path order, always - the directory walk hands files back in filesystem order (near-alphabetical
	# on NTFS, hash order on ext4), and forty-odd checks derive finding order and "first user" picks
	# from this list.
	scripts.sort()
	return scripts


## `event_number` is the sheet's own margin number for the row the finding is about (0 when the
## finding is about a file rather than a row). It is what lets a finding be quoted the way the
## editor, the bookmarks and the Find results quote a row: "event 4".
## The one wait a beginner reaches for that does not do what its name promises. `OS.delay_msec`
## and `OS.delay_usec` STOP the whole process while they count - no drawing, no input, no physics -
## so a script that "waits half a second" this way freezes the game for half a second and then jumps.
## The sheet's own Wait row is a coroutine and lets the frame finish, which is what everybody means.
##
## Decidable from the emitted code and never a false accusation: these two calls have exactly one
## behaviour, and there is no honest reason for one inside a running game. A warning rather than an
## error, because a headless tool script may legitimately block; one finding per script, naming the
## row to reach for instead.
static func check_blocking_waits(_sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	for script_path: String in _project_scripts():
		var source: String = source_of(script_path)
		if source.is_empty():
			continue
		var blocking: PackedStringArray = blocking_wait_calls(source)
		if blocking.is_empty():
			continue
		_add(findings, "warning", "blocking-wait", script_path,
			"%s here %s the whole game while it counts - nothing draws, nothing takes input and physics does not step, so the game freezes and then jumps. Use the sheet's own Wait action instead (System > Wait), which lets the frame finish. Ignore this only in a tool or headless script that has no frame to hold up." % [
				_quoted_sample(blocking), "stops" if blocking.size() == 1 else "stop"])


## Every blocking delay a source holds, as the call text, once each. Comment lines are set aside
## the way every other source sweep here sets them aside.
static func blocking_wait_calls(source: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for line: String in _without_comment_lines(source).split("\n"):
		for head: String in ["OS.delay_msec(", "OS.delay_usec("]:
			var at: int = line.find(head)
			if at < 0:
				continue
			var close_at: int = line.find(")", at)
			if close_at < 0:
				continue
			var call_text: String = line.substr(at, close_at - at + 1)
			if not found.has(call_text):
				found.append(call_text)
	return found


## THE SILENT-NOTHING BUG: an animation's method track calls a function by name, and nothing in
## the project defines it.
##
## A method track is a real contract between an animation and a script, and it is the only contract in
## Godot that both sides can honour without either side saying so: the animation names a function, the
## script has no idea it is named, and a rename on either side leaves a game that plays the animation,
## calls nothing, and reports nothing. The hit never lands, the footstep never sounds, and there is no
## error to search for.
##
## Advisory, because a function can arrive from a base class, a `class_name` in another file, or a
## script attached at run time - so this names what it could not find rather than accusing.
static func check_animation_method_tracks(findings: Array[Dictionary]) -> void:
	var defined: Dictionary = {}
	for script_path: String in _list_files_with_extension("gd"):
		for line: String in source_of(script_path).split("\n"):
			var stripped: String = line.strip_edges()
			if not (stripped.begins_with("func ") or stripped.begins_with("static func ")):
				continue
			var head: String = stripped.trim_prefix("static ").trim_prefix("func ")
			var opening: int = head.find("(")
			if opening > 0:
				defined[head.substr(0, opening).strip_edges()] = true
	for source_path: String in _animation_bearing_files():
		var text: String = source_of(source_path)
		var reported: Dictionary = {}
		for track: Dictionary in EventSheetAnimationTrackFacts.tracks_in(text):
			var method: String = str(track.get("method", ""))
			if method.is_empty() or defined.has(method) or reported.has(method):
				continue
			reported[method] = true
			var clip: String = str(track.get("animation", "")).strip_edges()
			var named: String = "\"%s\"" % clip if not clip.is_empty() else "an animation"
			_add(findings, "warning", "animation-track", source_path,
				"A method track in %s calls %s(), which no script in this project defines - the key will play and do nothing." % [named, method])


## Every file an Animation could live in: a scene, or a resource of its own. The plugin's own folders
## are skipped for the same reason every other sweep skips them - they are the editor, not the game.
static func _animation_bearing_files() -> PackedStringArray:
	var found: PackedStringArray = _list_files_with_extension("tscn")
	found.append_array(_list_files_with_extension("tres"))
	return found


static func _add(findings: Array[Dictionary], severity: String, check: String, path: String, message: String, event_number: int = 0) -> void:
	findings.append({"severity": severity, "check": check, "path": path, "message": message, "event": event_number})


## THE PATTERN SMELLS: a pattern the readings recognised, missing its other half.
##
## Once a reading knows a shape it knows the shape's parts, and a missing part is the classic
## beginner bug - the countdown that never restarts, the pooled object that is never returned, the
## state nothing ever asks about, the timer started on the way in and never stopped on the way out.
## None of them is a compile error, so today they ship green and misbehave at play time.
##
## Every check here reads the CLAIM REGISTRY rather than re-deriving a pattern, which is the whole
## point of the registry: the Doctor accuses exactly the shapes the sheet already marks, so a reader
## can always see the thing being complained about. The claims are made here rather than taken from
## a view, because the Doctor runs headlessly over paths and has no viewport.
static func check_pattern_smells(sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	for sheet_path: String in sheet_paths:
		if sheet_path.begins_with("res://eventsheet_addons/"):
			continue
		var sheet: EventSheetResource = load(sheet_path) as EventSheetResource
		if sheet == null:
			continue
		scan_pattern_smells(sheet, sheet_path, findings)


## The walk itself, over ONE sheet already in hand - the entry point the suite drives, because a
## check that can only be reached through a project scan can only be tested by staging a project.
static func scan_pattern_smells(sheet: EventSheetResource, sheet_path: String,
		findings: Array[Dictionary]) -> void:
	if sheet == null:
		return
	EventSheetPatternFacts.clear(sheet)
	EventSheetViewportReadingRows.claim_patterns(sheet)
	# The three notes that accuse a MISSING half, which is exactly what a claim
	# cannot describe. Run before the early return below: a sheet whose shapes are all incomplete
	# claims nothing, and that is precisely the sheet these notes are for.
	scan_game_shape_smells(sheet, sheet_path, findings)
	var claims: Array = EventSheetPatternFacts.claims(sheet)
	if claims.is_empty():
		return
	var numbers: Dictionary = EventSheetResource.event_numbers(sheet.events)
	var events: Dictionary = _events_by_uid(sheet)
	for entry: Variant in claims:
		var claim: Dictionary = entry as Dictionary
		var owner: EventRow = events.get(str(claim.get("row_uid", ""))) as EventRow
		var number: int = int(numbers.get(owner.get_instance_id(), 0)) if owner != null else 0
		match str(claim.get("pattern", "")):
			"countdown":
				_pattern_smell_countdown(sheet, owner, sheet_path, number, findings)
			"object_pool":
				_pattern_smell_pool(sheet, sheet_path, number, findings)
			"state_machine":
				_pattern_smell_state(sheet, sheet_path, number, findings)
			"wait_sequence":
				_pattern_smell_timer(sheet, owner, sheet_path, number, findings)
		# "this block is a behavior" - the note that is how Adopt behavior gets discovered at all.
		# Only when this build can actually do it, because a note offering a rewrite that cannot run
		# is worse than no note.
		if EventSheetPatternAdopt.is_adoptable(claim) \
				and bool(EventSheetPatternAdopt.plan(sheet, claim).get("ok", false)):
			_add(findings, "info", "pattern-is-a-behavior", sheet_path,
				"This block is the %s behavior - Adopt behavior?" % EventSheetPatternVocabulary.pack_label(
					EventSheetPatternAdopt.adoptable_of(claim)), number)


## A countdown that counts but never restarts: it reaches zero once and stays there, so whatever it
## was gating happens forever afterwards.
static func _pattern_smell_countdown(sheet: EventSheetResource, owner: EventRow,
		sheet_path: String, number: int, findings: Array[Dictionary]) -> void:
	var counted: String = _countdown_name(owner)
	if counted.is_empty():
		return
	for event_row: EventRow in _pattern_events(sheet):
		for action: Variant in event_row.actions:
			if action is ACEAction and (action as ACEAction).ace_id == "SetVar" \
					and str((action as ACEAction).params.get("var_name", "")) == counted:
				return
	_add(findings, "warning", "pattern-countdown-never-restarts", sheet_path,
		"%s counts down but never restarts - this event subtracts from it and nothing sets it above zero." % counted,
		number)


## A pooled object that is taken out and never put back: the pool drains and the reuse the pattern
## exists for stops happening.
static func _pattern_smell_pool(sheet: EventSheetResource, sheet_path: String, number: int,
		findings: Array[Dictionary]) -> void:
	if _sheet_uses_ace(sheet, "ReturnToPool") or _sheet_uses_ace(sheet, "PoolRelease"):
		return
	_add(findings, "warning", "pattern-pool-never-returned", sheet_path,
		"A pooled object is created here and nothing anywhere returns one to the pool.", number)


## A state that is SET and never ASKED about: the value is written every time and no event ever
## branches on it, so the state machine has states nothing reacts to.
static func _pattern_smell_state(sheet: EventSheetResource, sheet_path: String, number: int,
		findings: Array[Dictionary]) -> void:
	var written: Dictionary = {}
	var asked: Dictionary = {}
	for event_row: EventRow in _pattern_events(sheet):
		for condition: ACECondition in event_row.conditions:
			if condition != null and condition.ace_id == "CompareVar":
				asked[str(condition.params.get("var_name", ""))] = true
		for action: Variant in event_row.actions:
			if action is ACEAction and (action as ACEAction).ace_id == "SetVar":
				written[str((action as ACEAction).params.get("var_name", ""))] = true
	for name_entry: Variant in written.keys():
		if not asked.has(name_entry):
			_add(findings, "warning", "pattern-state-never-asked", sheet_path,
				"%s is set here but no event asks for it." % str(name_entry), number)
			return


## A timer started on the way into a state and never stopped on the way out: it keeps ticking after
## the state it belonged to has ended, and fires into a state that has moved on.
static func _pattern_smell_timer(sheet: EventSheetResource, owner: EventRow, sheet_path: String,
		number: int, findings: Array[Dictionary]) -> void:
	if owner == null or owner.trigger_id != "OnEnterState":
		return
	if _sheet_uses_ace(sheet, "StopTimer") or _sheet_uses_ace(sheet, "CancelDelay"):
		return
	_add(findings, "warning", "pattern-timer-never-stopped", sheet_path,
		"A timer is started on entering this state and nothing stops it on leaving.", number)


## The variable an event counts down every tick, or "" when it counts nothing down.
static func _countdown_name(owner: EventRow) -> String:
	if owner == null:
		return ""
	for action: Variant in owner.actions:
		if action is ACEAction and (action as ACEAction).ace_id == "SubtractVar":
			return str((action as ACEAction).params.get("var_name", ""))
	return ""


## Whether any row of the sheet uses a given ACE id, whatever provider it came from - the "is the
## other half of this pattern anywhere at all" question every check above asks.
static func _sheet_uses_ace(sheet: EventSheetResource, ace_id: String) -> bool:
	for event_row: EventRow in _pattern_events(sheet):
		for condition: ACECondition in event_row.conditions:
			if condition != null and condition.ace_id == ace_id:
				return true
		for action: Variant in event_row.actions:
			if action is ACEAction and (action as ACEAction).ace_id == ace_id:
				return true
	return false


## THREE ADVISORY NOTES on the game shapes, each one a HALF that is missing.
##
## Unlike the pattern smells above these cannot read the claim registry, because a claim requires
## the whole shape and what is being accused here is exactly a shape that is NOT whole: a pity
## counter with no reset, a meter that only fills, a mission clock nothing shows. All three are
## advisory (info): each is occasionally deliberate, and none of them is a compile error.
static func scan_game_shape_smells(sheet: EventSheetResource, sheet_path: String,
		findings: Array[Dictionary]) -> void:
	if sheet == null:
		return
	var lines: PackedStringArray = EventSheetViewportReadingRows.ordered_code_lines(sheet)
	# The pity counter that never resets - the guarantee then fires on EVERY roll after the
	# first cap hit, which is the single most common bug in a hand-written pity system.
	for counter: String in (EventSheetPatternReadings.pity_facts(lines).get("unreset", {}) as Dictionary):
		_add(findings, "info", "pity-counter-never-resets", sheet_path,
			"%s grows the odds and is guaranteed at a cap, but nothing puts it back to zero on the win - after the first guarantee it fires every roll." % counter)
	# The meter that only fills. Read from the file's lines first (a hand-written pair) and
	# from the sheet's own rows second (a Fill Meter row with no Drain Meter row anywhere).
	for filled: String in _filled_without_drain(lines):
		_add(findings, "info", "meter-never-drains", sheet_path,
			"%s is filled at a rate and nothing drains it - once it reaches its cap it stays there." % filled)
	if _sheet_uses_ace(sheet, "FillMeter") and not _sheet_uses_ace(sheet, "DrainMeter"):
		_add(findings, "info", "meter-never-drains", sheet_path,
			"This sheet fills a meter and never drains one - a meter that only goes up reaches its cap and stays there.")
	# The mission clock the player cannot see. Pressure nobody can read is not pressure.
	if _sheet_uses_ace(sheet, "StartMissionTimer") and not _sheet_uses_ace(sheet, "MissionTimeLeft"):
		_add(findings, "info", "mission-timer-not-shown", sheet_path,
			"A mission timer starts here and no row shows the time left - drop Mission Time Left into a HUD label so the player can feel the deadline.")


## The meters a FILE fills without ever draining, as the names it fills. The reading answers
## which pairs are complete; anything filled at a per-frame rate and missing from that answer is a
## one-way meter.
static func _filled_without_drain(lines: PackedStringArray) -> PackedStringArray:
	var paired: Dictionary = EventSheetPatternReadings.meter_variables(lines)
	var lonely: PackedStringArray = PackedStringArray()
	for line: String in lines:
		var step: Dictionary = EventSheetPatternReadings.meter_step(line.strip_edges())
		if step.is_empty() or str(step.get("kind", "")) != "fill":
			continue
		var name_text: String = str(step.get("name", ""))
		if paired.has(name_text) or lonely.has(name_text):
			continue
		lonely.append(name_text)
	return lonely


## Every EventRow of a sheet, its functions included.
static func _pattern_events(sheet: EventSheetResource) -> Array[EventRow]:
	var found: Array[EventRow] = []
	_collect_pattern_events(sheet.events, found)
	for function_entry: Variant in sheet.functions:
		if function_entry is EventFunction:
			_collect_pattern_events((function_entry as EventFunction).events, found)
	return found


static func _collect_pattern_events(source: Array, into: Array[EventRow]) -> void:
	for entry: Variant in source:
		if not (entry is EventRow):
			continue
		into.append(entry as EventRow)
		_collect_pattern_events((entry as EventRow).sub_events, into)


## The sheet's events keyed by their uid - how a claim (which carries a uid, never a resource) finds
## the row it is about.
static func _events_by_uid(sheet: EventSheetResource) -> Dictionary:
	var found: Dictionary = {}
	for event_row: EventRow in _pattern_events(sheet):
		if not event_row.event_uid.is_empty():
			found[event_row.event_uid] = event_row
	return found


# ── the three hierarchy footguns ─────────────────────────────────────────────────
#
# Reparenting is where a beginner meets the scene tree's sharp edges, and all three of these fail at
# RUN time with an engine message that names a line inside Godot rather than the row that caused it.
# They are decidable from the emitted code, so they are decidable at authoring time - and each has
# exactly one accepted fix, which is what makes them worth a note rather than a lecture.
#
# All three are NOTES, never warnings: each is occasionally what somebody meant (a one-child list is
# safe to walk while moving it; a deferred reparent may already be deferred by hand), and a lint that
# accuses working code is a lint people switch off.


## Footgun one of three. The loop variable of a `for c in x.get_children():` walk whose body moves THAT child.
## Godot's child list is live: taking a child out mid-walk shifts every child after it down one, so
## the loop skips the next one - the classic "it only reparented half of them" bug. Iterating a
## `.duplicate()` (or the sheet's For Each Child row, which always snapshots) is the whole fix, so a
## loop that already walks a copy is never flagged.
static func reparenting_children_loops(source: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var loop_variable: String = ""
	var loop_indent: int = 0
	for line: String in _without_comment_lines(source).split("\n"):
		var stripped: String = line.strip_edges()
		if stripped.is_empty():
			continue
		var indent: int = line.length() - line.strip_edges(true, false).length()
		if not loop_variable.is_empty() and indent <= loop_indent:
			loop_variable = ""
		if stripped.begins_with("for ") and stripped.contains(".get_children()") \
				and not stripped.contains(".duplicate()"):
			loop_variable = stripped.substr(4).get_slice(" in ", 0).get_slice(":", 0).strip_edges()
			loop_indent = indent
			continue
		if loop_variable.is_empty() or found.has(loop_variable):
			continue
		if _moves_child(stripped, loop_variable):
			found.append(loop_variable)
	return found


## True when one line takes `child_name` out of, or into, somebody's child list.
static func _moves_child(stripped: String, child_name: String) -> bool:
	if stripped.begins_with("%s.reparent(" % child_name):
		return true
	for verb: String in [".add_child(", ".remove_child("]:
		var at: int = stripped.find(verb)
		if at >= 0 and stripped.substr(at + verb.length()).get_slice(",", 0).get_slice(")", 0).strip_edges() == child_name:
			return true
	return false


## Footgun two of three. A reparent of SELF inside `_ready`. The node's own parent is still adding its children at
## that moment, so Godot refuses the move outright ("parent node is busy setting up children") and
## the game dies on the first frame. Deferring it to after the tree settles is the accepted fix.
static func self_reparent_in_ready(source: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var in_ready: bool = false
	for line: String in _without_comment_lines(source).split("\n"):
		var stripped: String = line.strip_edges()
		if stripped.begins_with("func "):
			in_ready = stripped.begins_with("func _ready(")
			continue
		if not in_ready:
			continue
		if not (stripped.begins_with("reparent(") or stripped.begins_with("self.reparent(")):
			continue
		# Already deferred by hand is already the fix - `call_deferred("reparent", ...)` never begins
		# with the call itself, so only the direct spelling can reach here.
		if not found.has(stripped):
			found.append(stripped)
	return found


## Footgun three of three. A variable that keeps hold of a node while the file also frees that node's PARENT. A
## child is destroyed with its parent (that is Godot's default, and the hierarchy's "destroy with
## parent" tick), so the variable is left pointing at nothing and the next line that touches it is a
## "previously freed instance" crash. An `is_instance_valid` check before the use is the fix, so a
## file that already asks that question anywhere is never flagged.
static func freed_parent_references(source: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var text: String = _without_comment_lines(source)
	if text.contains("is_instance_valid("):
		return found
	var held: PackedStringArray = _held_node_variables(text)
	if held.is_empty():
		return found
	var parent_of: Dictionary = _parented_children(text)
	var aliases: Dictionary = _held_variable_aliases(text, held)
	for line: String in text.split("\n"):
		var stripped: String = line.strip_edges()
		var at: int = stripped.find(".queue_free()")
		if at < 0:
			continue
		var freed: String = _node_name_of(stripped.substr(0, at))
		if freed.is_empty():
			continue
		for variable_name: String in held:
			var child: String = str(aliases.get(variable_name, variable_name))
			if str(parent_of.get(child, "")) == freed and not found.has(variable_name):
				found.append(variable_name)
	return found


## `carried = item` - the member and the local naming ONE node. Picking a thing up is written that
## way in every project, so without this the note would only ever see the half-written version.
static func _held_variable_aliases(text: String, held: PackedStringArray) -> Dictionary:
	var aliases: Dictionary = {}
	for line: String in text.split("\n"):
		var stripped: String = line.strip_edges()
		var at: int = stripped.find(" = ")
		if at < 0:
			continue
		var target: String = stripped.substr(0, at).strip_edges()
		if not held.has(target):
			continue
		var source_name: String = _node_name_of(stripped.substr(at + 3))
		if not source_name.is_empty() and source_name != target:
			aliases[target] = source_name
	return aliases


## The file's own members that hold a node - what "keeping a reference" means in a script. Only
## file-scope declarations count: a local dies with its function and cannot dangle across frames.
static func _held_node_variables(text: String) -> PackedStringArray:
	var held: PackedStringArray = PackedStringArray()
	for line: String in text.split("\n"):
		if line.begins_with("\t") or line.begins_with(" "):
			continue
		var stripped: String = line.strip_edges().trim_prefix("@onready ").trim_prefix("@export ")
		if not stripped.begins_with("var "):
			continue
		var declared: String = stripped.substr(4).get_slice(":", 0).get_slice("=", 0).strip_edges()
		if not declared.is_empty() and not held.has(declared):
			held.append(declared)
	return held


## Which node each child is parented ONTO, from the two spellings that say so: `child.reparent(p)`
## and `p.add_child(child)`. The last line to speak wins, exactly as it does at run time.
static func _parented_children(text: String) -> Dictionary:
	var parent_of: Dictionary = {}
	for line: String in text.split("\n"):
		var stripped: String = line.strip_edges()
		var reparent_at: int = stripped.find(".reparent(")
		if reparent_at >= 0:
			var child: String = _node_name_of(stripped.substr(0, reparent_at))
			var owner_text: String = stripped.substr(reparent_at + ".reparent(".length()).get_slice(",", 0).get_slice(")", 0)
			if not child.is_empty():
				parent_of[child] = _node_name_of(owner_text)
			continue
		var add_at: int = stripped.find(".add_child(")
		if add_at < 0:
			continue
		var added: String = _node_name_of(stripped.substr(add_at + ".add_child(".length()).get_slice(",", 0).get_slice(")", 0))
		if not added.is_empty():
			parent_of[added] = _node_name_of(stripped.substr(0, add_at))
	return parent_of


## The one name two spellings of the same node share: `$Hand`, `%Hat`, `$Arm/Hand` and a plain local
## all key on their last segment. "" for anything that is not a plain node reference.
static func _node_name_of(text: String) -> String:
	var clean: String = text.strip_edges().trim_prefix("$").trim_prefix("%").strip_edges()
	if clean.contains("/"):
		clean = clean.get_file()
	if clean.contains(" ") or clean.contains("(") or clean.contains(".") or clean.contains("\""):
		return ""
	return clean


## The three notes, over every script the project owns. Advisory, each naming what to reach for.
## The two ways a menu built in code goes quietly wrong, both of them invisible to any test of
## the handlers themselves - every handler works, and the ROUTING is what is broken:
##
##   an arm on an id nothing adds   a branch of real code the menu can never reach
##   two items sharing one id       the engine sends one number, the handler answers it once, and
##                                  the second item is dead however clearly it was written
##
## Notes, never warnings: a menu is a working menu, and these are things the author cannot see rather
## than contracts they broke. The project's own scripts only - this plugin's menus have their own
## gate, and a note about somebody else's shipped addon is not the reader's to act on.
static func check_menu_ids(findings: Array[Dictionary]) -> void:
	for script_path: String in _project_scripts():
		var source: String = source_of(script_path)
		if not source.contains("add_item("):
			continue
		for note: Dictionary in menu_id_notes(source.split("\n")):
			_add(findings, "info", str(note.get("check", "")), script_path, str(note.get("message", "")))
			(findings[findings.size() - 1] as Dictionary)["subject"] = str(note.get("subject", ""))


## The two things that go wrong with a game's modes: one nothing can get out of, and one nothing
## uses. Asked only of the AUTOLOAD scripts, because that is where a game's own state belongs (the
## engine's own guide says so) and it is where the modes band offers to declare them - so this costs
## one open per autoload rather than a walk of the project.
static func check_game_modes(findings: Array[Dictionary]) -> void:
	var importer := GDScriptImporter.new()
	for script_path: String in EventSheetModeFacts.autoload_scripts():
		if not source_of(script_path).contains("enum %s" % EventSheetModeFacts.ENUM_NAME):
			continue
		var sheet: EventSheetResource = importer.import_external(script_path)
		if sheet == null:
			continue
		for finding: Dictionary in EventSheetModeFacts.findings(sheet):
			_add(findings, str(finding.get("severity", "info")), str(finding.get("kind", "")),
				script_path, str(finding.get("message", "")))
			(findings[findings.size() - 1] as Dictionary)["subject"] = str(finding.get("subject", ""))


## The menu notes one file's lines are worth, as {check, message, subject} in file order. Pure and
## static so a test can pin the words without a project to walk: the walk above is only the loop that
## finds the files.
static func menu_id_notes(lines: PackedStringArray) -> Array[Dictionary]:
	var notes: Array[Dictionary] = []
	var context: Dictionary = EventSheetMenuFacts.facts(lines)
	if context.is_empty():
		return notes
	for arm: Dictionary in EventSheetMenuFacts.unknown_arms(context, lines):
		notes.append({
			"check": "menu-unknown-item",
			"message": "The %s menu answers item %s, and nothing ever adds an item with that id. The branch is real code the menu can never reach - either add the item, or move the branch to the id the item it means already has."
				% [str(arm.get("name", "")), str(arm.get("id", ""))],
			"subject": str(arm.get("id", ""))
		})
	for item: Dictionary in EventSheetMenuFacts.duplicate_items(context):
		notes.append({
			"check": "menu-duplicate-id",
			"message": "The %s menu adds \"%s\" with id %s, which \"%s\" already took. Godot sends that one number for both items and the handler answers it once, so \"%s\" is dead however clearly it is written. Give it an id of its own."
				% [str(item.get("name", "")), str(item.get("label", "")), str(item.get("id", "")),
					str(item.get("first", "")), str(item.get("label", ""))],
			"subject": str(item.get("id", ""))
		})
	return notes


## The words a file has to say SOMEWHERE before any pin spelling can be in it. Every arithmetic pin
## is an assignment whose left side is the object's own place, angle or size - `position`,
## `global_position`, `transform.origin`, `rotation`, `rotation_degrees`, `scale` and the single-axis
## forms of those - and every pack pin is one of the `.pin_…(` verbs below. So a file holding none of
## these five fragments has no pin in it, whatever else it says.
##
## A whole-file substring test, and the walk it stands in front of is a two-pass grammar read of every
## line: on this repository two thirds of the project's scripts never mention any of them, and each
## was paying for the full read to be told it had nothing. Deliberately LOOSE - a file that merely
## mentions "position" still gets the real walk - because the cheap test may only ever say "certainly
## nothing here", never "certainly something".
const _PIN_WORD_MARKS: PackedStringArray = ["position", "origin", "rotation", "scale", ".pin_"]


static func _could_hold_a_pin(source: String) -> bool:
	for mark: String in _PIN_WORD_MARKS:
		if source.contains(mark):
			return true
	return false


## The verbs the Pin behavior packs are started with - the pack half of "this object rides that
## one". The arithmetic half is the shape reader's answer, so the two together are every spelling a
## pin has.
const _PIN_VERBS: PackedStringArray = [
	".pin_to(", ".pin_to_at(", ".pin_rope(", ".pin_bar(", ".pin_soft(", ".pin_spring(",
	".pin_x_to(", ".pin_y_to(", ".pin_z_to(", ".pin_size_to(", ".pin_to_point(", ".pin_to_path("
]


## Every object this file pins itself to, however the pin is written - the arithmetic (a place or
## an angle copied off another object) and the Pin pack's own verbs. Sorted, so a note reads the same
## on every machine. Pure and static, so a test pins the answer without a project to walk.
static func pinned_anchors(source: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if not _could_hold_a_pin(source):
		return found
	var text: String = _without_comment_lines(source)
	# The shape reader already owns the grammar of a hand-written pin, and its summary already
	# applies every gate the ROWS apply - so asking it is what keeps the Doctor, the head bar and
	# the canvas agreeing about what a pin is, instead of three copies of the same grammar drifting.
	for summary: Variant in EventSheetBehaviorShapes.pin_summaries(text.split("\n")):
		var anchor: String = str((summary as Dictionary).get("anchor", ""))
		if not anchor.is_empty() and not found.has(anchor):
			found.append(anchor)
	for line: String in text.split("\n"):
		var stripped: String = line.strip_edges()
		for verb: String in _PIN_VERBS:
			var at: int = stripped.find(verb)
			if at < 0:
				continue
			var argument: String = stripped.substr(at + verb.length()) \
				.get_slice(",", 0).get_slice(")", 0).strip_edges()
			if _is_plain_name(argument) and not found.has(argument):
				found.append(argument)
	found.sort()
	return found


## The objects this file BOTH parents itself to AND pins itself to. Being a child already carries
## the object; the pin then writes its place a second time from the same source, and the two fight
## every frame - which is what "it drifts twice as fast" is.
## `known_pins` is `pinned_anchors(source)` where the caller already has it - the walk behind it is a
## full pass of the shape grammar, and the check below asks for it twice.
static func double_follow_anchors(source: String,
		known_pins: PackedStringArray = PackedStringArray()) -> PackedStringArray:
	var pinned: PackedStringArray = known_pins if not known_pins.is_empty() \
		else pinned_anchors(source)
	if pinned.is_empty():
		return PackedStringArray()
	var parents: Dictionary = _self_parent_names(_without_comment_lines(source))
	var found: PackedStringArray = PackedStringArray()
	for anchor: String in pinned:
		if parents.has(anchor) and not found.has(anchor):
			found.append(anchor)
	return found


## A pin whose anchor this file frees, with no Unpin and no validity question anywhere. The pin
## goes on reading a place off a node that is gone.
##
## The bail-outs are deliberately WHOLE-FILE and deliberately generous: a file that unpins anything,
## asks `is_instance_valid` about anything, or drops this anchor is left alone. A note that fires on
## a file whose author is plainly already thinking about lifetimes is worth less than no note, and
## this is advisory - a missed one costs nothing, a wrong one costs trust.
static func freed_pin_anchors(source: String,
		known_pins: PackedStringArray = PackedStringArray()) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var text: String = _without_comment_lines(source)
	if text.contains("is_instance_valid(") or text.contains(".unpin()"):
		return found
	var pinned: PackedStringArray = known_pins if not known_pins.is_empty() \
		else pinned_anchors(source)
	if pinned.is_empty():
		return found
	for line: String in text.split("\n"):
		var stripped: String = line.strip_edges()
		var at: int = stripped.find(".queue_free()")
		if at < 0:
			continue
		var freed: String = _node_name_of(stripped.substr(0, at))
		if freed.is_empty() or not pinned.has(freed) or found.has(freed):
			continue
		# Letting go of the anchor by hand is the fix written out, so a file that does it is done.
		if text.contains("%s = null" % freed):
			continue
		found.append(freed)
	return found


## The names this file calls its own PARENT: a variable filled from `get_parent()`, an object it
## hands itself to with `add_child(self)`, and the target of a `reparent`.
static func _self_parent_names(text: String) -> Dictionary:
	var parents: Dictionary = {}
	for line: String in text.split("\n"):
		var stripped: String = line.strip_edges().trim_prefix("@onready ")
		if stripped.begins_with("var ") and stripped.contains("get_parent()"):
			# The VALUE has to be the parent itself. `get_parent().get_node("Player")` is a sibling
			# and `get_parent().get_parent()` is a grandparent, and pinning to a sibling is the most
			# ordinary thing in the world - naming either of those a double follow would be a note
			# about nothing, on the most common shape there is.
			var assign_at: int = stripped.find("=")
			if assign_at < 0:
				continue
			var value_text: String = stripped.substr(assign_at + 1).strip_edges()
			if not value_text in ["get_parent()", "self.get_parent()"] \
					and not value_text.begins_with("get_parent() as "):
				continue
			var declared: String = stripped.substr(4, assign_at - 4).strip_edges()
			var name_text: String = declared.get_slice(":", 0).strip_edges()
			if _is_plain_name(name_text):
				parents[name_text] = true
			continue
		const ADD_CHILD := ".add_child("
		var add_at: int = stripped.find(ADD_CHILD)
		if add_at > 0 and stripped.substr(add_at + ADD_CHILD.length()) \
				.get_slice(",", 0).get_slice(")", 0).strip_edges() == "self":
			var owner_name: String = _node_name_of(stripped.substr(0, add_at))
			if not owner_name.is_empty():
				parents[owner_name] = true
			continue
		for verb: String in ["reparent(", "self.reparent("]:
			if not stripped.begins_with(verb):
				continue
			var target: String = stripped.substr(verb.length()) \
				.get_slice(",", 0).get_slice(")", 0).strip_edges()
			if _is_plain_name(target):
				parents[target] = true
	return parents


## A bare identifier - the only thing these notes will name out loud, because half an expression in
## a message is worse than no message.
static func _is_plain_name(text: String) -> bool:
	return text.is_valid_identifier() and text != "self"


static func check_hierarchy_footguns(_sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	for script_path: String in _project_scripts():
		var source: String = source_of(script_path)
		if source.is_empty():
			continue
		for loop_variable: String in reparenting_children_loops(source):
			_add(findings, "info", "reparent-while-iterating", script_path,
				"This walk over a node's children moves %s while it is walking them. Godot's child list is live, so every child after the moved one shifts down and the loop skips it - half the children quietly never get their turn. Walk a copy instead (add .duplicate() to the children), or use the sheet's For Each Child row, which always takes the snapshot for you."
					% loop_variable)
			(findings[findings.size() - 1] as Dictionary)["subject"] = loop_variable
		for call_text: String in self_reparent_in_ready(source):
			_add(findings, "info", "reparent-in-ready", script_path,
				"\"%s\" moves this object to a new parent while the old parent is still adding its children, and Godot refuses that outright. Do it after the tree has settled instead."
					% call_text)
			(findings[findings.size() - 1] as Dictionary)["subject"] = call_text
		for held: String in freed_parent_references(source):
			_add(findings, "info", "freed-parent-reference", script_path,
				"%s keeps hold of an object whose parent this file frees. A child is destroyed with its parent, so %s is left pointing at nothing and the next line that uses it crashes. Ask whether it is still there before touching it."
					% [held, held])
			(findings[findings.size() - 1] as Dictionary)["subject"] = held
		# The two ways the pin words and the child words get crossed. Notes, never warnings:
		# both mechanisms are honest and both files run - they just do a thing the author did not
		# mean, and there is nowhere else a person would be told.
		# One grammar walk for both notes: each of them would otherwise ask for the same answer.
		var pins: PackedStringArray = pinned_anchors(source)
		# A file that pins nothing has neither note to give, and both readers below answer nothing
		# for it. Asking them anyway was not free: each takes the pins it was HANDED only when that
		# list is non-empty, and reads the file again from scratch when it is - so every one of the
		# thousand files with no pin in it paid for the pin grammar three times over.
		if pins.is_empty():
			continue
		for anchor: String in double_follow_anchors(source, pins):
			_add(findings, "info", "double-follow", script_path,
				"This object is BOTH a child of %s and pinned to it. Being a child already carries it, so the pin writes its place a second time from the same source and the two fight every frame - the classic \"it drifts twice as fast\" bug. Keep one: Unpin, or take it out of %s and let the pin do the carrying."
					% [anchor, anchor])
			(findings[findings.size() - 1] as Dictionary)["subject"] = anchor
		for anchor: String in freed_pin_anchors(source, pins):
			_add(findings, "info", "pin-to-freed-object", script_path,
				"This object is pinned to %s and this file frees %s without ever unpinning. The pin keeps reading a place off a node that is gone, and the first frame after the free is a \"previously freed instance\" crash. Unpin before the free, or ask whether %s is still there."
					% [anchor, anchor, anchor])
			(findings[findings.size() - 1] as Dictionary)["subject"] = anchor


# ── what mirroring has to drag along ─────────────────────────────────────────────
#
# Mirroring a BODY mirrors its children; mirroring a SPRITE mirrors the picture and nothing else.
# That one sentence is behind two of the most common "why does this only work facing right" bug
# reports there are, and neither one announces itself: the game runs, the character turns, and the
# attack simply misses on one side. Both notes below are advisory - the code is not wrong, it is
# incomplete - and both name the one edit that completes it.


## The spellings that mirror a WHOLE object (its children come along), as a plain text test. The
## same shapes the reading claims, kept here so a hand-written line and a picked row are one check.
static func mirrors_whole_object(source: String) -> bool:
	for line: String in source.split("\n"):
		var text: String = line.strip_edges()
		if not text.contains("scale.x = "):
			continue
		var value: String = text.substr(text.find("scale.x = ") + 10).strip_edges()
		if value in ["-1", "-1.0"] or value.begins_with("-1.0 if ") or value.begins_with("-1 if ") \
				or value.begins_with("sign(") or value.begins_with("signf(") or value.begins_with("-"):
			return true
	return false


## True when the only mirroring in this file is a sprite's own flag - the case where the picture
## turns and the hitbox, the muzzle and the ray all stay exactly where they were.
static func mirrors_only_a_sprite(source: String) -> bool:
	return source.contains("flip_h = ") and not mirrors_whole_object(source)


## The casts this file declares whose reach is never signed by the facing. A ray is the classic
## one: `target_position` is a fixed offset, so a character that mirrors only its sprite attacks to
## the right forever. Returns the names in declaration order, "" none.
static func rays_not_following_facing(source: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if not mirrors_only_a_sprite(source):
		return out
	if source.contains("target_position") and source.contains("scale.x"):
		return out  # the reach IS signed by the facing somewhere in this file
	for line: String in source.split("\n"):
		var text: String = line.strip_edges()
		if not text.begins_with("@onready var ") and not text.begins_with("var "):
			continue
		var declared: String = _declared_name_of_class(text, ["RayCast2D", "ShapeCast2D"])
		if not declared.is_empty() and not out.has(declared):
			out.append(declared)
	return out


## The text children this file holds that sit under something it mirrors WHOLE, with nothing
## putting them back upright. A mirrored parent writes its children's text backwards, which is the
## other half of the same sentence.
static func labels_under_a_mirrored_body(source: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if not mirrors_whole_object(source):
		return out
	if source.contains("signf(scale.x)") or source.contains("sign(scale.x)"):
		return out  # something already keeps a child upright
	for line: String in source.split("\n"):
		var text: String = line.strip_edges()
		if not text.begins_with("@onready var ") and not text.begins_with("var "):
			continue
		var declared: String = _declared_name_of_class(text, ["Label", "RichTextLabel", "Label3D"])
		if not declared.is_empty() and not out.has(declared):
			out.append(declared)
	return out


## The name a declaration line binds when its TYPE is one of `classes`, "" otherwise. Reads the type
## hint and the cast alike, because both spellings say the same thing about what the name holds.
static func _declared_name_of_class(line: String, classes: Array) -> String:
	var head: String = line.trim_prefix("@onready ").trim_prefix("var ").strip_edges()
	var name_text: String = head.split(":")[0].split(" ")[0].strip_edges()
	if name_text.is_empty():
		return ""
	for class_text: String in classes:
		if line.contains(": %s " % class_text) or line.contains(": %s=" % class_text) \
				or line.contains(" as %s" % class_text) or line.rstrip(" ").ends_with(": %s" % class_text):
			return name_text
	return ""


## The two facing notes, over the project's own scripts.
static func check_facing_follows(_sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	for script_path: String in _project_scripts():
		var source: String = source_of(script_path)
		if source.is_empty():
			continue
		for ray_name: String in rays_not_following_facing(source):
			_add(findings, "info", "ray-not-following-facing", script_path,
				"This file mirrors a sprite, which turns the picture and nothing else - so %s keeps pointing the same way whichever way the character faces. That is the \"attacks only work facing right\" bug. Put %s under a node you mirror with Set Mirrored (whole object) and it turns with the character."
					% [ray_name, ray_name])
			(findings[findings.size() - 1] as Dictionary)["subject"] = ray_name
		for label_name: String in labels_under_a_mirrored_body(source):
			_add(findings, "info", "label-under-a-mirrored-body", script_path,
				"This file mirrors a whole object, so everything under it mirrors too - including %s, whose text comes out backwards every time the character faces left. A Keep Upright row on %s re-negates its scale and the text stays readable."
					% [label_name, label_name])
			(findings[findings.size() - 1] as Dictionary)["subject"] = label_name


# ── the notes a project leaves itself ────────────────────────────────────────────
#
# A TODO or a FIXME is how a project tracks itself, and until now it was invisible outside the code.
# Each one is a NOTE - never a warning: an unfinished thought is not a fault, it is a thing somebody
# meant to come back to, and the Doctor is where a person looks for the list of those.


## The directories a project's OWN scripts are never in. `eventsheet_addons/` and the plugin itself
## are shipped code (and `eventsheet_addons/` is compiler output besides), so their notes are not the
## reader's to do; `.godot` is a cache.
const _TASK_NOTE_SKIPPED_DIRS: PackedStringArray = ["addons", "eventsheet_addons"]


## Every TODO / FIXME / HACK / NOTE comment in the project's own scripts, one finding per line,
## with the file and the line number so the report can jump straight to it.
static func check_task_notes(findings: Array[Dictionary]) -> void:
	for script_path: String in _project_script_paths():
		var handle: FileAccess = FileAccess.open(script_path, FileAccess.READ)
		if handle == null:
			continue
		var lines: PackedStringArray = handle.get_as_text().split("\n")
		handle.close()
		for line_index: int in range(lines.size()):
			var note: Dictionary = task_note_in(lines[line_index])
			if note.is_empty():
				continue
			_add(findings, "info", "task-note", script_path,
				"%s at line %d: %s" % [str(note.get("marker", "")), line_index + 1,
					str(note.get("text", ""))], line_index + 1)


## The task note one line carries, as {"marker", "text"}, or {} when the line is not one.
##
## The `#` must open the comment part of the line, which is what a note IS - a `# TODO` written
## inside a string literal is content somebody wrote, not a note about the code. Kept here rather
## than in the reading grammar because the Doctor runs headless, with no editor around it.
static func task_note_in(line: String) -> Dictionary:
	var hash_at: int = line.find("#")
	if hash_at < 0:
		return {}
	var before: String = line.substr(0, hash_at)
	if before.count("\"") % 2 == 1 or before.count("'") % 2 == 1:
		return {}
	var comment: String = line.substr(hash_at + 1).strip_edges()
	# `##` is a doc comment - what a thing IS, not a note about finishing it.
	if comment.begins_with("#"):
		comment = comment.substr(1).strip_edges()
	for marker: String in ["TODO", "FIXME", "HACK", "NOTE"]:
		if comment == marker or comment.begins_with("%s " % marker) or comment.begins_with("%s:" % marker):
			return {"marker": marker, "text": comment}
	return {}


## Every .gd under res:// that belongs to the PROJECT rather than to a plugin or to generated output.
static func _project_script_paths() -> PackedStringArray:
	var script_paths: PackedStringArray = PackedStringArray()
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
				if not entry.begins_with(".") and not _TASK_NOTE_SKIPPED_DIRS.has(entry):
					pending.append(full_path)
			elif entry.ends_with(".gd"):
				script_paths.append(full_path)
			entry = directory.get_next()
	script_paths.sort()  # deterministic, so the report never reorders between runs
	return script_paths
