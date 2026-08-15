# Godot EventSheets - project vocabulary doc generator
#
# Renders ONE always-current markdown reference of everything a project can say: per-sheet
# classes, properties, triggers/conditions/actions/expressions (via
# EventSheetAuthorLoop.collect_publish_surface - straight from the model, no compile), the
# hand-written script packs (parsed from their @ace_* annotations), and the BUILT-IN
# vocabulary - the ~1,090 verbs the picker offers before a single pack is enabled, grouped by
# the module file that authors them. For teams and AI assistants alike: "what can I say in
# this project?" answered by a committed file instead of clicking through pickers.
#
# The built-in section is DERIVED, never typed: each module file is asked for its descriptors
# (the module contract in ace_factory.gd), and each descriptor is then re-fetched from the LIVE
# registry so the doc shows the shipped shape - including the optional "On node" target that
# EventForgeBuiltinACEs adds to node-scoped verbs at registration time. Rename a verb and the
# doc renames with it on the next run.
#
# Determinism is part of the contract (the doc is meant to be committed and diffed):
# sheet paths are sorted, scanner order is sorted, module files are sorted, no timestamps.
# The Project Doctor keeps a generated doc honest with an advisory staleness note (opt-in:
# no doc, no note).
@tool
class_name EventSheetVocabularyDoc
extends RefCounted

const DEFAULT_PATH := "res://EVENTSHEETS-VOCABULARY.md"

## Where the built-in vocabulary modules live. One file per vocabulary; each exposes
## `static func get_descriptors() -> Array[ACEDescriptor]`.
const MODULES_DIR := "res://addons/eventforge/registration/modules"


## Where the doc lives - override with the eventsheets/project/vocabulary_doc_path
## project setting.
static func doc_path() -> String:
	return str(ProjectSettings.get_setting("eventsheets/project/vocabulary_doc_path", DEFAULT_PATH))


## The full document. Sheets first (every EventSheetResource in the project, packs
## included), then hand-written script packs (compiler-generated pack scripts are
## excluded - their sheet section already covers them).
static func generate() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("# Project vocabulary - Godot EventSheets")
	lines.append("")
	lines.append("> Generated - do not edit. Regenerate via the dock (Tools → Vocabulary Doc…) or")
	lines.append("> `godot --headless --path . --script tools/vocabulary_doc.gd`.")
	# Templates are blueprints, not live vocabulary - they don't publish anything yet.
	var sheet_paths: PackedStringArray = EventSheetTemplates.non_template_sheets(EventSheetProjectFind.list_project_sheets())
	var sorted_paths: Array = []
	for sheet_path: String in sheet_paths:
		sorted_paths.append(sheet_path)
	sorted_paths.sort()
	if not sorted_paths.is_empty():
		lines.append("")
		lines.append("## Sheets")
	for sheet_path: String in sorted_paths:
		var sheet: EventSheetResource = load(sheet_path) as EventSheetResource
		if sheet == null:
			continue
		lines.append_array(sheet_section(sheet, sheet_path))
	var pack_lines: PackedStringArray = PackedStringArray()
	for script_path: String in EventSheetAddonScanner.list_addon_scripts():
		pack_lines.append_array(script_pack_section(script_path))
	if not pack_lines.is_empty():
		lines.append("")
		lines.append("## Script packs")
		lines.append_array(pack_lines)
	var builtin_lines: PackedStringArray = builtin_module_sections()
	if not builtin_lines.is_empty():
		lines.append("")
		lines.append("## Built-in vocabulary")
		lines.append("")
		lines.append("Every verb the picker offers with no pack enabled, grouped by the module that")
		lines.append("authors it. Deprecated verbs are marked - they still compile, but the picker hides them.")
		lines.append_array(builtin_lines)
	lines.append("")
	return "\n".join(lines)


## Generates and writes the doc to doc_path(). Returns the path, or "" on failure.
static func write() -> String:
	var path: String = doc_path()
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(generate())
	file.close()
	return path


## One sheet's entry: identity line (what it is and where it runs) + its publish surface.
static func sheet_section(sheet: EventSheetResource, sheet_path: String) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var title: String = sheet.custom_class_name if not sheet.custom_class_name.is_empty() else sheet_path.get_file().get_basename()
	lines.append("")
	lines.append("### %s (`%s`)" % [title, sheet_path])
	if sheet.behavior_mode:
		lines.append("Behavior - attach under any `%s` node." % sheet.host_class)
	elif sheet.autoload_mode:
		lines.append("Autoload singleton `%s` - its ACEs are project-wide." % sheet.autoload_name)
	else:
		lines.append("Node script extending `%s`." % sheet.host_class)
	var surface: Dictionary = EventSheetAuthorLoop.collect_publish_surface(sheet)
	var rendered: PackedStringArray = EventSheetAuthorLoop.surface_markdown(surface, "####")
	if rendered.is_empty():
		lines.append("(publishes nothing yet)")
	else:
		lines.append_array(rendered)
	return lines


## One hand-written script pack's entry. Empty when the script is compiler-generated
## (a "# Source:" header - its sheet section covers it) or publishes nothing.
static func script_pack_section(script_path: String) -> PackedStringArray:
	var source: String = FileAccess.get_file_as_string(script_path)
	if source.left(400).contains("# Source: "):
		return PackedStringArray()
	var surface: Dictionary = script_pack_surface(source)
	var rendered: PackedStringArray = EventSheetAuthorLoop.surface_markdown(surface, "####")
	if rendered.is_empty():
		return PackedStringArray()
	var lines: PackedStringArray = PackedStringArray()
	var class_match: RegExMatch = RegEx.create_from_string("(?m)^class_name\\s+([A-Za-z_][A-Za-z0-9_]*)").search(source)
	lines.append("")
	lines.append("### %s (`%s`)" % [class_match.get_string(1) if class_match != null else script_path.get_file(), script_path])
	var doc_match: RegExMatch = RegEx.create_from_string("\\A((?:##[^\\n]*\\n)+)").search(source)
	if doc_match != null:
		lines.append(_flatten_doc_comment(doc_match.get_string(1)))
	lines.append_array(rendered)
	return lines


## Every built-in module's entry, in sorted file order. Empty when the modules directory is
## missing (a stripped install), which is what keeps the section itself optional.
static func builtin_module_sections() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for module_file: String in builtin_module_files():
		lines.append_array(builtin_module_section(module_file))
	return lines


## The module .gd file names, sorted. Sorted rather than registration order on purpose: the doc
## is committed and diffed, so a reader looks a module up alphabetically and a new module lands
## in one place instead of shifting the tail.
static func builtin_module_files() -> PackedStringArray:
	var files: PackedStringArray = PackedStringArray()
	for file_name: String in DirAccess.get_files_at(MODULES_DIR):
		if file_name.ends_with(".gd"):  # skips the .gd.uid sidecars
			files.append(file_name)
	files.sort()
	return files


## One built-in module's entry: title line, the module's own one-line summary, and its verbs
## rendered by the same surface renderer the sheets and script packs use.
static func builtin_module_section(module_file: String) -> PackedStringArray:
	var module_path: String = MODULES_DIR.path_join(module_file)
	var surface: Dictionary = builtin_module_surface(module_file)
	var rendered: PackedStringArray = EventSheetAuthorLoop.surface_markdown(surface, "####")
	if rendered.is_empty():
		return PackedStringArray()
	var lines: PackedStringArray = PackedStringArray()
	lines.append("")
	lines.append("### %s (`%s`)" % [module_file.get_basename().trim_suffix("_aces").capitalize(), module_path])
	var summary: String = _module_summary(module_path)
	if not summary.is_empty():
		lines.append(summary)
	lines.append_array(rendered)
	return lines


## One module's verbs in the shared surface shape, so one renderer serves sheets, script packs
## and built-ins alike. Each descriptor the module authors is re-fetched from the registry by
## identity (provider + ace_id), so the doc shows the SHIPPED verb - registration adds the "On
## node" target to node-scoped verbs, and a doc built from the raw module output would miss it.
static func builtin_module_surface(module_file: String) -> Dictionary:
	var surface: Dictionary = {"actions": [], "triggers": [], "conditions": [], "expressions": [], "properties": []}
	var script: GDScript = load(MODULES_DIR.path_join(module_file)) as GDScript
	if script == null or not _declares_get_descriptors(script):
		return surface
	var authored: Variant = script.call("get_descriptors")
	if not (authored is Array):
		return surface
	for entry: Variant in (authored as Array):
		if not (entry is ACEDescriptor):
			continue
		var descriptor: ACEDescriptor = entry as ACEDescriptor
		var shipped: ACEDescriptor = ACERegistry.find_descriptor(descriptor.provider_id, descriptor.ace_id)
		if shipped != null:
			descriptor = shipped
		var bucket: String = _descriptor_bucket(descriptor)
		var description: String = str(descriptor.description).strip_edges()
		if descriptor.is_deprecated:
			description = ("Deprecated. " + description).strip_edges()
		(surface[bucket] as Array).append({
			"name": descriptor.display_name,
			"params": _descriptor_params(descriptor),
			"category": descriptor.category,
			"description": _flatten_doc_comment(description),
		})
	return surface


## The surface bucket a descriptor belongs in. A LOOPING verb IS a condition in the picker
## (adding it to an event repeats the actions), which is how it is typed, so no special case.
static func _descriptor_bucket(descriptor: ACEDescriptor) -> String:
	match descriptor.ace_type:
		ACEDescriptor.ACEType.TRIGGER:
			return "triggers"
		ACEDescriptor.ACEType.CONDITION:
			return "conditions"
		ACEDescriptor.ACEType.EXPRESSION:
			return "expressions"
		_:
			return "actions"


## A descriptor's parameters as one "id: Type" list, matching the signature a script pack shows.
static func _descriptor_params(descriptor: ACEDescriptor) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for param: ACEParam in descriptor.params:
		parts.append("%s: %s" % [str(param.id), str(param.type_name)])
	return ", ".join(parts)


## A module's own one-line summary: the first line of its header comment, with the shared
## "EventForge module - " lead-in dropped. "" when the file opens with no comment.
static func _module_summary(module_path: String) -> String:
	for line: String in FileAccess.get_file_as_string(module_path).split("\n"):
		var stripped: String = line.strip_edges()
		if stripped.is_empty():
			continue
		if not stripped.begins_with("#"):
			return ""
		return stripped.trim_prefix("#").strip_edges().trim_prefix("EventForge module - ").strip_edges()
	return ""


## True when the loaded script declares get_descriptors - the module contract. Checked rather
## than assumed so a non-module helper dropped into the directory is skipped, not crashed on.
static func _declares_get_descriptors(script: GDScript) -> bool:
	for method_info: Dictionary in script.get_script_method_list():
		if str(method_info.get("name", "")) == "get_descriptors":
			return true
	return false


## Parses a script's @ace_* annotated members into the same surface shape
## collect_publish_surface returns, so one renderer serves both.
static func script_pack_surface(source: String) -> Dictionary:
	var surface: Dictionary = {"actions": [], "triggers": [], "conditions": [], "expressions": [], "properties": []}
	# A LOOPING condition carries `@ace_looping(item)` instead of `@ace_condition` - the annotation
	# is what names the loop variable, so it replaces the plain one rather than joining it. Scanning
	# for the four plain kinds therefore missed every looping verb ever shipped, leaving a whole
	# family absent from the reference while looking complete.
	var kind_regex: RegEx = RegEx.create_from_string("## @ace_(trigger|condition|action|expression|looping)\\b")
	var name_regex: RegEx = RegEx.create_from_string("## @ace_name\\(\"([^\"]+)\"\\)")
	var category_regex: RegEx = RegEx.create_from_string("## @ace_category\\(\"([^\"]+)\"\\)")
	# The close is anchored to the end of its line so a description containing its own quoted example -
	# ... (for example "down,forward,punch") - is not cut short at that inner quote.
	var description_regex: RegEx = RegEx.create_from_string("(?sm)## @ace_description\\(\"(.*?)\"\\)\\s*$")
	var symbol_regex: RegEx = RegEx.create_from_string("^(?:signal|func)\\s+([A-Za-z_][A-Za-z0-9_]*)\\s*(?:\\(([^)]*)\\))?")
	# A member is a run of `##` annotation lines closed by its signal/func declaration. Walking LINE BY
	# LINE (rather than splitting the file on blank lines) is what keeps CONSECUTIVE members apart:
	# compiler output separates them with a single newline, so a blank-line split swept a whole run of
	# triggers into one chunk and recorded only the first of them.
	var pending: PackedStringArray = PackedStringArray()
	for line: String in source.split("\n"):
		var stripped: String = line.strip_edges()
		if stripped.begins_with("##"):
			pending.append(stripped)
			continue
		if pending.is_empty():
			continue
		var chunk: String = "\n".join(pending)
		pending = PackedStringArray()
		var symbol_match: RegExMatch = symbol_regex.search(stripped)
		if symbol_match == null:
			continue
		var kind_match: RegExMatch = kind_regex.search(chunk)
		if kind_match == null:
			continue
		var shown_match: RegExMatch = name_regex.search(chunk)
		var category_match: RegExMatch = category_regex.search(chunk)
		var description_match: RegExMatch = description_regex.search(chunk)
		# A looping verb IS a condition in the picker (adding it to an event repeats the actions), so
		# it is listed among them; each one's own description opens by saying that it repeats.
		var bucket: String = "conditions" if kind_match.get_string(1) == "looping" else kind_match.get_string(1) + "s"
		(surface[bucket] as Array).append({
			"name": shown_match.get_string(1) if shown_match != null else symbol_match.get_string(1).capitalize(),
			"params": symbol_match.get_string(2).strip_edges(),
			"category": category_match.get_string(1) if category_match != null else "",
			"description": _flatten_doc_comment(description_match.get_string(1)) if description_match != null else "",
		})
	return surface


## Doc comments continue across lines as "## …"; flatten to one readable line.
static func _flatten_doc_comment(comment: String) -> String:
	var flattened: String = comment.strip_edges()
	flattened = flattened.replace("\n## ", " ").replace("\n##", " ").replace("## ", "")
	return flattened.replace("\n", " ").strip_edges()
