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
	check_fragile_node_paths(sheet_paths, findings)
	check_unbounded_loops(sheet_paths, findings)
	check_coroutine_in_per_frame_trigger(sheet_paths, findings)
	check_unused_packs(sheet_paths, findings)
	check_pack_dependencies(sheet_paths, findings)
	check_rotated_gravity_pathfinding(findings)
	check_param_type_mismatches(sheet_paths, findings)
	check_shadowed_variables(sheet_paths, findings)
	check_untranslated_project(sheet_paths, findings)
	check_unmarked_player_text(sheet_paths, findings)
	check_stale_translated_labels(sheet_paths, findings)
	check_required_fields(sheet_paths, findings)
	check_missing_save_support(sheet_paths, findings)
	check_save_key_symmetry(sheet_paths, findings)
	check_editor_tool_undo(sheet_paths, findings)
	check_editor_tool_safety(sheet_paths, findings)
	check_orphaned_provider_calls(sheet_paths, findings)
	check_sheet_signal_declarations(sheet_paths, findings)
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
		if FileAccess.get_file_as_string(output_path).contains("func save_state("):
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
		var source: String = FileAccess.get_file_as_string(script_path)
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
		var output: String = FileAccess.get_file_as_string(output_path)
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


## R32 / R33. The three mistakes every FIRST editor tool makes, beside the undo one above. Each is a
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
		var output: String = FileAccess.get_file_as_string(output_path)
		# 1. Reaching outside the layout the user has open. `get_tree()` in the editor process walks
		# the EDITOR's own tree, not the scene being edited, which is almost never what was meant.
		if output.contains("get_tree().get_nodes_in_group(") or output.contains("get_tree().call_group("):
			_add(findings, "info", "editor-tool-scope", sheet_path,
				"This editor tool reaches for nodes through get_tree(), which in the editor is the editor's own tree and not the layout you have open. Walk Editor.OpenLayout (the edited scene root) instead, or the tool will find nothing - or the wrong thing.")
		# 2. Destroying things while editing. A queue_free in the editor deletes from the OPEN scene,
		# and without an undo step the only way back is to close the scene without saving.
		if output.contains("queue_free()") and not output.contains("create_action("):
			_add(findings, "info", "editor-tool-destroy", sheet_path,
				"This editor tool calls Destroy while running in the editor, so it deletes from the layout you have open. Register an undo step around it, or the only way back is closing the scene without saving.")
		# 3. Ticking in the editor with no way to switch it off - the R32 guard.
		if _ticks_without_editor_guard(output):
			_add(findings, "info", "editor-tool-tick", sheet_path,
				"This tool runs every tick in the editor, so it is running right now while you edit. Add a Preview in editor toggle - an exported true/false plus a Stop event when the sheet is in the editor and the toggle is off - so you can switch it off.")


## R32. True when a compiled @tool script has a per-frame handler and NO editor guard in it. The guard
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
		var numbers: Dictionary = EventSheetResource.event_numbers(sheet.events)
		for entry: Variant in sheet.events:
			if entry is EventRow and _is_per_frame_trigger((entry as EventRow).trigger_id):
				_scan_unbounded_loops(entry as EventRow, sheet_path, threshold, findings, numbers)


static func _is_per_frame_trigger(trigger_id: String) -> bool:
	return trigger_id == "OnProcess" or trigger_id == "OnPhysicsProcess"


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
		corpus_parts.append(FileAccess.get_file_as_string(scene_path))
	for property: Dictionary in ProjectSettings.get_property_list():
		if str(property.get("name", "")).begins_with("autoload/"):
			corpus_parts.append(str(ProjectSettings.get_setting(str(property.get("name")))))
	var corpus: String = "\n".join(corpus_parts)
	var class_regex: RegEx = RegEx.create_from_string("(?m)^class_name\\s+([A-Za-z_][A-Za-z0-9_]*)")
	var requires_regex: RegEx = RegEx.create_from_string("(?m)^## @ace_requires\\(([^)]*)\\)")
	for script_path: String in pack_scripts:
		var pack_source: String = FileAccess.get_file_as_string(script_path)
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
		var scene_text: String = FileAccess.get_file_as_string(scene_path)
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
		var output_text: String = FileAccess.get_file_as_string(output_path)
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
		var source: String = FileAccess.get_file_as_string(script_path)
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
		var source: String = FileAccess.get_file_as_string(script_path)
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
		var source: String = FileAccess.get_file_as_string(script_path)
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
		var source: String = FileAccess.get_file_as_string(script_path)
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


## Every project GDScript, excluding addons/ (the plugin's own code is not a user's game).
static func _project_scripts() -> PackedStringArray:
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
	return scripts


## `event_number` is the sheet's own margin number for the row the finding is about (0 when the
## finding is about a file rather than a row). It is what lets a finding be quoted the way the
## editor, the bookmarks and the Find results quote a row: "event 4".
static func _add(findings: Array[Dictionary], severity: String, check: String, path: String, message: String, event_number: int = 0) -> void:
	findings.append({"severity": severity, "check": check, "path": path, "message": message, "event": event_number})
