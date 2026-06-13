# Godot EventSheets — Project Doctor (one audit for the drift no single check sees)
#
# Unions the project-health checks into a single report, runnable three ways: the
# dock's Tools menu, the headless CLI (tools/project_doctor.gd) and CI. Severities:
#   error   — a broken contract: a committed generated script drifted from what its
#             sheet compiles to today, or a sheet no longer compiles. CI fails on these.
#   warning — a wiring gap with a one-step fix: sheet never compiled, autoload sheet
#             not registered (or registered to a different script).
#   info    — advisory vocabulary hygiene: private variable never referenced, pack
#             published but unused, compiled sheet attached to no scene. Never fails CI.
# The doctor NEVER writes inside res:// — verification recompiles go to a user://
# scratch file and are compared as text (contrast tools/audit_addons.gd, which repairs
# pack outputs in place while reporting drift).
@tool
extends RefCounted
class_name EventSheetProjectDoctor

const SCRATCH_PATH := "user://eventsheets_doctor_scratch.gd"

## Full audit over every sheet in the project. Returns
## {findings: Array[Dictionary{severity, check, path, message}], errors, warnings, infos}.
static func run() -> Dictionary:
	var findings: Array[Dictionary] = []
	# Templates are blueprints: no generated output, no scene, no live vocabulary —
	# auditing them would only manufacture noise.
	var sheet_paths: PackedStringArray = EventSheetTemplates.non_template_sheets(EventSheetProjectFind.list_project_sheets())
	check_generated_outputs(sheet_paths, findings)
	check_autoload_registration(sheet_paths, findings)
	check_scene_attachment(sheet_paths, findings)
	check_unused_variables(sheet_paths, findings)
	check_unused_packs(sheet_paths, findings)
	check_shadowed_variables(sheet_paths, findings)
	check_vocabulary_doc(findings)
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

## The script a sheet is expected to pair with — the compiler's own resolution
## (existing <name>_generated.gd, else the pack builder's header-verified sibling
## <name>.gd, else the <name>_generated.gd a save WOULD create), so the doctor,
## compile-on-save and the export-integrity pass can never disagree about pairing.
static func output_path_for(sheet_path: String) -> String:
	var sheet: EventSheetResource = load(sheet_path) as EventSheetResource
	if sheet == null:
		return sheet_path.get_basename() + "_generated.gd"
	return SheetCompiler._resolve_output_path(sheet, "")

## Every committed output must be exactly what its sheet compiles to today — the same
## byte-identity contract pack goldens pin, generalized to every sheet in the project.
static func check_generated_outputs(sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	for sheet_path: String in sheet_paths:
		var sheet: EventSheetResource = load(sheet_path) as EventSheetResource
		if sheet == null:
			continue
		var output_path: String = output_path_for(sheet_path)
		if not FileAccess.file_exists(output_path):
			_add(findings, "warning", "stale-output", sheet_path,
				"No generated script yet — saving the sheet in the editor writes %s (compile-on-save)." % output_path.get_file())
			continue
		var result: Dictionary = SheetCompiler.compile(sheet, SCRATCH_PATH)
		if not bool(result.get("success", false)):
			_add(findings, "error", "compile", sheet_path,
				"Sheet no longer compiles: %s" % str(result.get("errors")))
			continue
		if str(result.get("output", "")) != FileAccess.get_file_as_string(output_path):
			_add(findings, "error", "stale-output", sheet_path,
				"%s is stale — re-save the sheet (or re-run the pack builder) to refresh it." % output_path.get_file())
	DirAccess.remove_absolute(SCRATCH_PATH)

## Autoload sheets only run when project.godot points their singleton name at the
## compiled script (the dock's Tools → Register Autoload does this in one click).
static func check_autoload_registration(sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	for sheet_path: String in sheet_paths:
		var sheet: EventSheetResource = load(sheet_path) as EventSheetResource
		if sheet == null or not sheet.autoload_mode:
			continue
		if sheet.autoload_name.is_empty():
			_add(findings, "warning", "autoload", sheet_path,
				"Autoload sheet has no singleton name — set one in the Sheet Type dialog.")
			continue
		var key: String = "autoload/%s" % sheet.autoload_name
		var expected: String = output_path_for(sheet_path)
		if not ProjectSettings.has_setting(key):
			_add(findings, "warning", "autoload", sheet_path,
				"Autoload sheet \"%s\" is not registered — Tools → Register Autoload." % sheet.autoload_name)
		elif str(ProjectSettings.get_setting(key)).trim_prefix("*") != expected:
			_add(findings, "warning", "autoload", sheet_path,
				"Autoload \"%s\" points at %s, but this sheet compiles to %s." % [sheet.autoload_name, str(ProjectSettings.get_setting(key)).trim_prefix("*"), expected])

## Reverse scene lookup: a compiled sheet nothing instances is usually a forgotten
## attach. Skips autoload sheets (registered, not attached) and published packs
## (vocabulary, not project wiring) — and stays advisory, since scripts can be
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
				"%s is attached to no scene — fine if it's instanced from code or used as a class." % output_path.get_file())

## The sheet a generated script belongs to — the inverse of output_path_for.
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
	return ""

## Every scene that references a script path — the reverse lookup the attachment
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
					"Private variable \"%s\" is never referenced — dead vocabulary?" % str(variable_name))

## Packs no sheet, scene or autoload references are removal candidates — advisory,
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
			"Pack class %s is referenced by no sheet, scene or autoload — fine if you call it from hand-written GDScript." % pack_class)

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
## unparseable AND blinds expression lint — the one rule shared by the doctor check
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
## member) — error tier: the game cannot run until the variable is renamed.
static func check_shadowed_variables(sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	for sheet_path: String in sheet_paths:
		var sheet: EventSheetResource = load(sheet_path) as EventSheetResource
		if sheet == null:
			continue
		for variable_name: Variant in sheet.variables:
			var owner_class: String = shadowed_member_class(sheet, str(variable_name))
			if not owner_class.is_empty():
				_add(findings, "error", "shadowed-variable", sheet_path,
					"Variable \"%s\" shadows a %s member — the generated script can't load. Rename Everywhere… fixes every reference." % [str(variable_name), owner_class])

## A generated vocabulary doc is a promise to the team — once one exists, the doctor
## notes when it no longer matches what the project actually publishes. Opt-in by
## design: no doc, no note.
static func check_vocabulary_doc(findings: Array[Dictionary]) -> void:
	var path: String = EventSheetVocabularyDoc.doc_path()
	if not FileAccess.file_exists(path):
		return
	if FileAccess.get_file_as_string(path) != EventSheetVocabularyDoc.generate():
		_add(findings, "info", "vocabulary-doc", path,
			"Vocabulary doc is stale — regenerate via Tools → Vocabulary Doc… or tools/vocabulary_doc.gd.")

## Everything in a sheet that can REFERENCE vocabulary: raw code, ACE param values and
## baked templates, pick filters, trigger args, local-variable defaults. Comments are
## deliberately excluded — mentioning a name in prose isn't usage.
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
