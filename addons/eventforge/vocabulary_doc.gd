# Godot EventSheets — project vocabulary doc generator
#
# Renders ONE always-current markdown reference of everything this project's sheets
# and packs publish: per-sheet classes, properties, triggers/conditions/actions/
# expressions (via EventSheetAuthorLoop.collect_publish_surface — straight from the
# model, no compile) plus hand-written script packs (parsed from their @ace_*
# annotations). For teams and AI assistants alike: "what can I say in this project?"
# answered by a committed file instead of clicking through pickers.
#
# Determinism is part of the contract (the doc is meant to be committed and diffed):
# sheet paths are sorted, scanner order is sorted, no timestamps. The Project Doctor
# keeps a generated doc honest with an advisory staleness note (opt-in: no doc, no note).
@tool
extends RefCounted
class_name EventSheetVocabularyDoc

const DEFAULT_PATH := "res://EVENTSHEETS-VOCABULARY.md"

## Where the doc lives — override with the eventsheets/project/vocabulary_doc_path
## project setting.
static func doc_path() -> String:
	return str(ProjectSettings.get_setting("eventsheets/project/vocabulary_doc_path", DEFAULT_PATH))

## The full document. Sheets first (every EventSheetResource in the project, packs
## included), then hand-written script packs (compiler-generated pack scripts are
## excluded — their sheet section already covers them).
static func generate() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("# Project vocabulary — Godot EventSheets")
	lines.append("")
	lines.append("> Generated — do not edit. Regenerate via the dock (Tools → Vocabulary Doc…) or")
	lines.append("> `godot --headless --path . --script tools/vocabulary_doc.gd`.")
	# Templates are blueprints, not live vocabulary — they don't publish anything yet.
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
		lines.append("Behavior — attach under any `%s` node." % sheet.host_class)
	elif sheet.autoload_mode:
		lines.append("Autoload singleton `%s` — its ACEs are project-wide." % sheet.autoload_name)
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
## (a "# Source:" header — its sheet section covers it) or publishes nothing.
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

## Parses a script's @ace_* annotated members into the same surface shape
## collect_publish_surface returns, so one renderer serves both.
static func script_pack_surface(source: String) -> Dictionary:
	var surface: Dictionary = {"actions": [], "triggers": [], "conditions": [], "expressions": [], "properties": []}
	var kind_regex: RegEx = RegEx.create_from_string("## @ace_(trigger|condition|action|expression)\\b")
	var name_regex: RegEx = RegEx.create_from_string("## @ace_name\\(\"([^\"]+)\"\\)")
	var category_regex: RegEx = RegEx.create_from_string("## @ace_category\\(\"([^\"]+)\"\\)")
	var description_regex: RegEx = RegEx.create_from_string("(?s)## @ace_description\\(\"(.*?)\"\\)")
	var symbol_regex: RegEx = RegEx.create_from_string("(?m)^(?:signal|func)\\s+([A-Za-z_][A-Za-z0-9_]*)\\s*(?:\\(([^)]*)\\))?")
	for chunk: String in source.split("\n\n"):
		var kind_match: RegExMatch = kind_regex.search(chunk)
		var symbol_match: RegExMatch = symbol_regex.search(chunk)
		if kind_match == null or symbol_match == null:
			continue
		var shown_match: RegExMatch = name_regex.search(chunk)
		var category_match: RegExMatch = category_regex.search(chunk)
		var description_match: RegExMatch = description_regex.search(chunk)
		(surface[kind_match.get_string(1) + "s"] as Array).append({
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
