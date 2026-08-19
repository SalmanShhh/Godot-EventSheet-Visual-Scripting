# EventSheet - addon guide scaffolder: emits a docs/Addons-style guide SKELETON for a pack,
# pre-filled with the pack's REAL tables (verbs, knobs, signals, the Self section) so the parts a
# human must write - the 15 use cases, the tips - are the only blanks left. Everything factual is
# derived from the script the same way the editor derives it (script-level: property list, method
# list, `## @ace_*` annotations from source - never instance reflection, which is editor-dead for
# non-@tool scripts), so a generated table can never name a verb the picker does not offer.
@tool
class_name EventSheetAddonGuideScaffold
extends RefCounted

const USE_CASE_COUNT: int = 15
const OTHER_USE_CASE_COUNT: int = 5


## Where packs live, and the file a pack ships its own guide as - the same name the reading
## surface discovers a pack guide under, so a guide written here IS the pack's page from the next
## moment on, with no registration anywhere.
const PACKS_ROOT := "res://eventsheet_addons"
const PACK_GUIDE_FILE := "guide.md"


## Writes a pack's guide skeleton beside the pack, and answers with the file it wrote ("" when the
## pack has no script to derive one from, or the file could not be written). The one-click behind
## the Manual's "Write this guide": a behavior with no written guide is a page that lists its
## vocabulary and offers this, rather than a dead link.
##
## An EXISTING guide is never overwritten - it is somebody's writing, and a scaffolder that could
## replace it is one misclick away from deleting a day's work. The path comes back either way, so
## the caller can open what is already there.
static func write_guide_for_pack(pack_dir: String) -> String:
	var directory: String = pack_dir.strip_edges().trim_suffix("/").get_file()
	if directory.is_empty():
		return ""
	var guide_path: String = "%s/%s/%s" % [PACKS_ROOT, directory, PACK_GUIDE_FILE]
	if FileAccess.file_exists(guide_path):
		return guide_path
	var markdown: String = ""
	var file_names: PackedStringArray = DirAccess.get_files_at("%s/%s" % [PACKS_ROOT, directory])
	file_names.sort()
	for file_name: String in file_names:
		if file_name.get_extension().to_lower() != "gd":
			continue
		markdown = generate("%s/%s/%s" % [PACKS_ROOT, directory, file_name])
		if not markdown.strip_edges().is_empty():
			break
	if markdown.strip_edges().is_empty():
		return ""
	var file: FileAccess = FileAccess.open(guide_path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(markdown)
	file.close()
	return guide_path


## The whole skeleton as markdown, "" when the script cannot be read (fail closed).
static func generate(script_path: String) -> String:
	var script: Script = load(script_path) as Script if ResourceLoader.exists(script_path) else null
	if script == null:
		return ""
	var source: String = FileAccess.get_file_as_string(script_path)
	var pack_class: String = str(script.get_global_name())
	if pack_class.is_empty():
		pack_class = script_path.get_file().get_basename().to_pascal_case()
	var category: String = _annotation_value(source, "@ace_category")
	var display: String = category if not category.is_empty() else pack_class.capitalize()
	var summary: String = _class_summary(source)
	var members: Dictionary = member_rows_from(script, script_path)
	var actions: Array = _markdown_rows(members.get("actions", []) as Array)
	var conditions: Array = _markdown_rows(members.get("conditions", []) as Array)
	var expressions: Array = _markdown_rows(members.get("expressions", []) as Array)
	var triggers: Array = _markdown_rows(members.get("triggers", []) as Array)

	var knobs: Array = []
	for property_info: Dictionary in script.get_script_property_list():
		var usage: int = int(property_info.get("usage", 0))
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE == 0 or usage & PROPERTY_USAGE_EDITOR == 0:
			continue
		var property_name: String = str(property_info.get("name", ""))
		if property_name.is_empty() or property_name.begins_with("_"):
			continue
		knobs.append("| `%s` | %s | `%s` | (what this knob controls) |" % [
			property_name, type_string(int(property_info.get("type", TYPE_NIL))),
			str(script.get_property_default_value(property_name))])

	var out: PackedStringArray = PackedStringArray()
	out.append("# %s - %s" % [display, summary if not summary.is_empty() else "(one line: what this pack does)"])
	out.append("")
	out.append("## Table of Contents")
	out.append("")
	var sections: Array = ["Where this pack shines", "Core concepts", "Setup", "ACE reference",
		"Reading it from expressions - the Self section", "Use cases", "Tips and common mistakes"]
	for i: int in range(sections.size()):
		var slug: String = str(sections[i]).to_lower().replace(" - ", "---").replace(" ", "-")
		out.append("%d. [%s](#%s)" % [i + 1, sections[i], slug])
	out.append("")
	out.append("---")
	out.append("")
	out.append("## Where this pack shines")
	out.append("")
	out.append("- (three or four bullets: the situations where reaching for %s beats hand-rolling it)" % display)
	out.append("")
	out.append("## Core concepts")
	out.append("")
	out.append("- (the two or three ideas a user must hold: what state it keeps, what it acts on, when it ticks)")
	out.append("")
	out.append("## Setup")
	out.append("")
	out.append("1. Attach **%s** as a child of the node it should drive." % pack_class)
	out.append("2. (any required scene wiring, groups, or project settings)")
	out.append("")
	out.append("## ACE reference")
	out.append("")
	var sentences: Array = styled_sentences(source)
	if not sentences.is_empty():
		out.append("On the canvas these verbs read as styled sentences - parameter values in **bold**, node references in *italic*, exactly as the rows draw them:")
		out.append("")
		for sentence: String in sentences:
			out.append("- %s" % sentence)
		out.append("")
	_table(out, "Actions", actions)
	_table(out, "Conditions", conditions)
	_table(out, "Expressions", expressions)
	_table(out, "Triggers", triggers)
	out.append("### Inspector properties")
	out.append("")
	if knobs.is_empty():
		out.append("(none - this pack keeps no designer knobs)")
	else:
		out.append("| Property | Type | Default | What it does |")
		out.append("|---|---|---|---|")
		for knob: String in knobs:
			out.append(knob)
	out.append("")
	_self_section(out, script, pack_class)
	out.append("## Use cases")
	out.append("")
	for i: int in range(1, USE_CASE_COUNT + 1):
		out.append("### %d. (Name this use case)" % i)
		out.append("")
		out.append("(the goal in one sentence, then the event rows that get there - Trigger, conditions, actions)")
		out.append("")
	out.append("Other use cases:")
	out.append("")
	for i: int in range(OTHER_USE_CASE_COUNT):
		out.append("- **(One-liner use case %d.)** (a sentence on how the verbs combine for it)" % (i + 1))
	out.append("")
	out.append("## Tips and common mistakes")
	out.append("")
	out.append("- (the mistake a first-time user actually makes, and the fix)")
	out.append("- (the interaction with other packs or engine features worth knowing)")
	out.append("")
	return "\n".join(out)


## Every verb a pack script publishes, grouped the way the guide's ACE reference groups them:
##   {"actions": [{name, params}], "conditions": [...], "expressions": [...], "triggers": [...]}
## SCRIPT-LEVEL, never instance reflection - the method list, plus the `## @ace_*` marks read from
## the source on disk - because instance reflection is dead in the editor for non-@tool scripts.
##
## Public because the documentation viewer renders the same table live, and two derivations of
## "what does this pack publish" would be two answers: this is the one.
static func member_rows(script_path: String) -> Dictionary:
	var script: Script = load(script_path) as Script if ResourceLoader.exists(script_path) else null
	if script == null:
		return {"actions": [], "conditions": [], "expressions": [], "triggers": []}
	return member_rows_from(script, script_path)


## The same derivation for a script already loaded, so the scaffolder does not read it twice.
static func member_rows_from(script: Script, script_path: String) -> Dictionary:
	var actions: Array = []
	var conditions: Array = []
	var expressions: Array = []
	var triggers: Array = []
	var annotations: Dictionary = EventSheetSelfExpressions.method_annotations(script_path)
	var expose_all: bool = bool(annotations.get("@expose_all", false))
	for method_info: Dictionary in script.get_script_method_list():
		var method_name: String = str(method_info.get("name", ""))
		if method_name.is_empty() or method_name.begins_with("_"):
			continue
		var marks: Array = annotations.get(method_name, [])
		if marks.has("hidden") or marks.has("internal"):
			continue
		var row: Dictionary = _member_row(method_name, method_info)
		if marks.has("trigger"):
			triggers.append(row)
		elif marks.has("action"):
			actions.append(row)
		elif marks.has("condition"):
			conditions.append(row)
		elif marks.has("expression"):
			expressions.append(row)
		elif expose_all:
			var return_type: int = int((method_info.get("return", {}) as Dictionary).get("type", TYPE_NIL))
			if return_type == TYPE_NIL:
				actions.append(row)
			elif return_type == TYPE_BOOL:
				conditions.append(row)
			else:
				expressions.append(row)
	for signal_info: Dictionary in script.get_script_signal_list():
		triggers.append(_member_row(str(signal_info.get("name", "")), signal_info))
	return {"actions": actions, "conditions": conditions, "expressions": expressions, "triggers": triggers}


static func _markdown_rows(rows: Array) -> Array:
	var out: Array = []
	for entry: Variant in rows:
		out.append(_method_row(str((entry as Dictionary).get("name", "")), str((entry as Dictionary).get("params", ""))))
	return out


static func _table(out: PackedStringArray, title: String, rows: Array) -> void:
	out.append("### %s" % title)
	out.append("")
	if rows.is_empty():
		out.append("(none)")
	else:
		out.append("| Verb | Parameters | Notes |")
		out.append("|---|---|---|")
		for row: String in rows:
			out.append(row)
	out.append("")


static func _self_section(out: PackedStringArray, script: Script, pack_class: String) -> void:
	out.append("## Reading it from expressions - the Self section")
	out.append("")
	out.append("Type `self` in any ƒx field and **Self ▸ Behaviours** lists this pack's knobs and value")
	out.append("verbs as ready-to-insert chains once the behaviour is attached:")
	out.append("")
	var entries: Array = EventSheetSelfExpressions.pack_entries_from_script(script, pack_class, false)
	if entries.is_empty():
		out.append("(this pack publishes no knobs or value verbs)")
	for entry: Dictionary in entries.slice(0, 2):
		out.append("- `%s` inserts the **%s** entry straight into any expression" % [
			str(entry.get("fragment")), str(entry.get("label")).split(" · ")[0]])
	out.append("")


## One member as {name, params}: the parameter list is "name: Type" per argument, joined - the
## same string the guide's table shows and the viewer's live table shows.
static func _member_row(member_name: String, info: Dictionary) -> Dictionary:
	var parameters: PackedStringArray = PackedStringArray()
	for argument: Variant in info.get("args", []):
		if argument is Dictionary:
			parameters.append("%s: %s" % [str((argument as Dictionary).get("name", "")),
				type_string(int((argument as Dictionary).get("type", TYPE_NIL)))])
	return {"name": member_name, "params": ", ".join(parameters)}


static func _method_row(member_name: String, parameters: String) -> String:
	return "| `%s` | %s | (when to reach for it) |" % [
		member_name, parameters if not parameters.is_empty() else "-"]


## The pack's MARKED display sentences as markdown bullets, in source order: every
## `## @ace_display_template("...")` carrying BBCode-lite becomes its row read with
## `[b]{x}[/b]` rendered **bold** and `[i]{x}[/i]` rendered *italic* (plain templates are
## skipped - the viewport already bolds their values automatically, so the guide has nothing
## extra to show). Static + pure over the source text, so the block can never disagree with
## the annotations the picker reads.
static func styled_sentences(source: String) -> Array:
	var sentences: Array = []
	for line: String in source.split("\n"):
		var stripped: String = line.strip_edges()
		if not stripped.begins_with("## @ace_display_template("):
			continue
		var open: int = stripped.find("(\"")
		var close: int = stripped.rfind("\")")
		if open < 0 or close <= open:
			continue
		var template: String = stripped.substr(open + 2, close - open - 2)
		if not template.contains("[b]") and not template.contains("[i]"):
			continue
		var rendered: String = template
		var bold: RegEx = RegEx.new()
		bold.compile("\\[b\\]\\{([^}]+)\\}\\[/b\\]")
		rendered = bold.sub(rendered, "**$1**", true)
		var italic: RegEx = RegEx.new()
		italic.compile("\\[i\\]\\{([^}]+)\\}\\[/i\\]")
		rendered = italic.sub(rendered, "*$1*", true)
		sentences.append(rendered)
	return sentences


## The value inside `## @ace_xxx(value)` at pack level, "" when absent.
static func _annotation_value(source: String, annotation: String) -> String:
	for line: String in source.split("\n"):
		var stripped: String = line.strip_edges()
		if stripped.begins_with("## " + annotation) or stripped.begins_with("# " + annotation):
			var open: int = stripped.find("(")
			var close: int = stripped.rfind(")")
			if open >= 0 and close > open:
				return stripped.substr(open + 1, close - open - 1).strip_edges().trim_prefix("\"").trim_suffix("\"")
			return stripped.get_slice(annotation, 1).strip_edges()
	return ""


## The class description: the first plain `##` doc line (not an @ace_* mark), wherever the
## author put it - above class_name or after extends, both styles ship in the bundled packs.
static func _class_summary(source: String) -> String:
	for line: String in source.split("\n"):
		var stripped: String = line.strip_edges()
		if stripped.begins_with("func ") or stripped.begins_with("static func "):
			break
		if stripped.begins_with("##") and not stripped.contains("@ace_"):
			var text: String = stripped.trim_prefix("##").strip_edges()
			if not text.is_empty():
				var period: int = text.find(". ")
				return text.substr(0, period + 1) if period > 0 else text
	return ""
