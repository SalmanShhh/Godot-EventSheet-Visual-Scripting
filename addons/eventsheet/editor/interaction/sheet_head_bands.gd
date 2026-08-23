# Godot EventSheets - the HEAD of a sheet, one band per line of the file.
#
# A script opens with the lines it cannot do without: `class_name`, `extends`, `@icon`, `@tool`, the
# `##` description, a behaviour's host binding, an autoload's project entry. The head used to fold
# all of them into one crumb trail (`▣ Node ▸ CharacterBody2D ▸ Player`) that was hidden by default,
# so the icon, the autoload name and `@tool` were only found by opening a dropdown.
#
# This is the model behind the band stack that replaced it: ONE band per line, in reading order,
# each doing exactly one thing - one fact, one control, one code echo. Nothing is combined and
# nothing is inferred: a band exists only when the line it stands for exists, so a reader who knows
# the file knows the head, and the other way round. A line the sheet COULD have and does not is
# offered by `addable()` instead, under the stack.
#
# PURE + STATIC. `facts()` reads a sheet plus its prelude text into a plain dictionary and `bands()`
# turns that dictionary into the band list - no viewport, no dock, no rows - which is what makes the
# whole head unit-testable, per sheet kind, without a canvas.
@tool
class_name EventSheetHeadBands
extends RefCounted

## The band ids, frozen: the row builder, the click dispatch and the tests all address a band by
## these. A band id is also the id `addable()` offers and the "+ add" row writes.
const BAND_NAME: String = "name"
const BAND_EXTENDS: String = "extends"
const BAND_ICON: String = "icon"
const BAND_TOOL: String = "tool"
const BAND_DESCRIPTION: String = "description"
const BAND_AUTOLOAD: String = "autoload"
const BAND_HOST: String = "host"
const BAND_REMEMBER: String = "remember"
const BAND_INCLUDE: String = "include"
const BAND_ATTACH: String = "attach"

## Reading order: the name leads, then what it extends, then the annotations, then the prose, then
## the facts that live outside the file. This is the file's own order with the name promoted, which
## is the order a reader recites the head in.
const ORDER: PackedStringArray = [
	BAND_NAME, BAND_EXTENDS, BAND_ICON, BAND_TOOL, BAND_DESCRIPTION,
	BAND_AUTOLOAD, BAND_HOST, BAND_REMEMBER, BAND_INCLUDE, BAND_ATTACH,
]

## The leader word each band opens with - the keyword of the line it stands for. The name band has
## none: its value IS the name.
const LEADERS: Dictionary = {
	BAND_NAME: "",
	BAND_EXTENDS: "extends",
	BAND_ICON: "@icon",
	BAND_TOOL: "@tool",
	BAND_DESCRIPTION: "##",
	BAND_AUTOLOAD: "autoload",
	BAND_HOST: "host",
	BAND_REMEMBER: "remember",
	BAND_INCLUDE: "include",
	BAND_ATTACH: "attach",
}

## The word on each band's control, "" where the band's own gesture is the control (the name band
## renames on F2 / double-click, the description edits in place, the `@tool` switch is the switch).
const CONTROL_LABELS: Dictionary = {
	BAND_EXTENDS: "change…",
	BAND_ICON: "change…",
	BAND_AUTOLOAD: "Project Settings…",
	BAND_INCLUDE: "open",
}

## What the "+ add" row calls each line it can offer. Only these four are ever offered: autoload and
## host come from choosing a KIND, never from adding a line.
const ADD_LABELS: Dictionary = {
	BAND_ICON: "icon",
	BAND_TOOL: "@tool",
	BAND_DESCRIPTION: "description",
}

## The base classes whose sheets usually carry `@tool`, so an absent one shows as a switch in the
## off position (with its echo ghosted) rather than hiding under "+ add" - an editor script that
## does not run in the editor is a bug the head should make findable.
const TOOL_IS_EXPECTED_ON: PackedStringArray = [
	"EditorScript", "EditorPlugin", "EditorInspectorPlugin", "EditorImportPlugin",
	"EditorExportPlugin", "EditorScenePostImport", "EditorResourcePreviewGenerator",
	"EditorNode3DGizmoPlugin", "EditorTranslationParserPlugin", "EditorContextMenuPlugin",
]


## Everything the head needs to know about one sheet, read once: the prelude lines say what the file
## says, and the sheet's own fields answer for a sheet whose prelude is not text yet (a `.tres` the
## compiler will write those lines for). `scaffold_code` is the leading run of scaffolding the
## viewport already gathered, joined with newlines. `attached` is the one fact no line of the file
## carries - whether a scene already runs this script - so the caller that can answer it passes it
## in, and the default is "yes" so nothing is asked of a sheet nobody asked about.
static func facts(sheet: EventSheetResource, scaffold_code: String, attached: bool = true) -> Dictionary:
	var declared_class: String = ""
	var extends_target: String = ""
	var icon_path: String = ""
	var has_tool: bool = false
	var host_bound: bool = false
	var description_lines: PackedStringArray = PackedStringArray()
	for raw_line: String in scaffold_code.split("\n"):
		var line: String = raw_line.strip_edges()
		if line.begins_with("class_name ") and declared_class.is_empty():
			declared_class = line.trim_prefix("class_name ").strip_edges()
		elif line.begins_with("extends ") and extends_target.is_empty():
			extends_target = line.trim_prefix("extends ").strip_edges()
		elif line.begins_with("@icon") and icon_path.is_empty():
			icon_path = _quoted_argument(line)
		elif line == "@tool":
			has_tool = true
		elif line.begins_with("func _enter_tree") or line.begins_with("host = get_parent"):
			host_bound = true
		elif line.begins_with("## ") and not line.begins_with("## @"):
			description_lines.append(line.trim_prefix("## ").strip_edges())
	var described: String = " ".join(description_lines).strip_edges()
	if sheet == null:
		return _facts_dictionary(declared_class, "", extends_target, icon_path, has_tool,
			described, "", "", "", PackedStringArray(), PackedStringArray(), attached)
	if declared_class.is_empty():
		declared_class = sheet.custom_class_name.strip_edges()
	if extends_target.is_empty():
		extends_target = sheet.host_class.strip_edges()
	if icon_path.is_empty():
		icon_path = sheet.custom_class_icon.strip_edges()
	has_tool = has_tool or sheet.tool_mode
	if described.is_empty():
		described = sheet.class_description.strip_edges()
	var source_path: String = str(sheet.external_source_path).strip_edges()
	var host_class: String = sheet.host_class.strip_edges() if host_bound or sheet.behavior_mode else ""
	return _facts_dictionary(
		declared_class,
		source_path.get_file(),
		extends_target,
		icon_path,
		has_tool,
		described,
		sheet.autoload_name.strip_edges() if sheet.autoload_mode else "",
		source_path,
		host_class,
		remembered_variables(sheet),
		PackedStringArray(sheet.includes),
		attached
	)


## The variables this sheet keeps between runs, in declaration order - the fact the compiler's
## persistence trio is written for, said once on its own band.
static func remembered_variables(sheet: EventSheetResource) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	if sheet == null:
		return names
	for var_key: Variant in sheet.variables.keys():
		var descriptor: Variant = sheet.variables.get(var_key)
		if not (descriptor is Dictionary):
			continue
		var attributes: Variant = (descriptor as Dictionary).get("attributes")
		if attributes is Dictionary and bool((attributes as Dictionary).get("remember", false)):
			names.append(str(var_key))
	return names


## The band list for these facts, in reading order. Every band matches exactly one line the file
## has (or, for the two prompts of a brand-new sheet, one line it is about to have).
static func bands(head_facts: Dictionary) -> Array[Dictionary]:
	var built: Array[Dictionary] = []
	for kind: String in ORDER:
		var band: Dictionary = _band(kind, head_facts)
		if not band.is_empty():
			built.append(band)
	return built


## The lines this sheet could have and does not - what the "+ add" row under the stack offers, in
## the same reading order. Never autoload or host: those come from choosing a kind, not from adding
## a line.
static func addable(head_facts: Dictionary) -> PackedStringArray:
	var offers: PackedStringArray = PackedStringArray()
	for kind: String in [BAND_ICON, BAND_TOOL, BAND_DESCRIPTION]:
		if _band(kind, head_facts).is_empty():
			offers.append(kind)
	return offers


## The word the "+ add" row uses for one offer.
static func add_label(kind: String) -> String:
	return str(ADD_LABELS.get(kind, kind))


## The whole "+ add" row's text, "" when this sheet already has every line it could have.
static func add_row_text(head_facts: Dictionary) -> String:
	var offers: PackedStringArray = addable(head_facts)
	if offers.is_empty():
		return ""
	var words: PackedStringArray = PackedStringArray()
	for kind: String in offers:
		words.append(add_label(kind))
	return "+ add: %s" % " · ".join(words)


## One band, or {} when this sheet has no such line.
static func _band(kind: String, head_facts: Dictionary) -> Dictionary:
	match kind:
		BAND_NAME:
			return _name_band(head_facts)
		BAND_EXTENDS:
			return _extends_band(head_facts)
		BAND_ICON:
			var icon_path: String = str(head_facts.get("icon", "")).strip_edges()
			if icon_path.is_empty():
				return {}
			return _make(kind, icon_path, "@icon(\"%s\")" % icon_path)
		BAND_TOOL:
			return _tool_band(head_facts)
		BAND_DESCRIPTION:
			var described: String = str(head_facts.get("description", "")).strip_edges()
			if described.is_empty():
				return {}
			var band: Dictionary = _make(kind, described, "## %s" % described)
			band["editable"] = true
			return band
		BAND_AUTOLOAD:
			return _autoload_band(head_facts)
		BAND_HOST:
			var host_class: String = str(head_facts.get("host", "")).strip_edges()
			if host_class.is_empty():
				return {}
			return _make(kind, "acts on its parent",
				"var host: %s · _enter_tree: host = get_parent()" % host_class)
		BAND_REMEMBER:
			var remembered: PackedStringArray = head_facts.get("remembered", PackedStringArray())
			if remembered.is_empty():
				return {}
			return _make(kind, "%s kept between runs" % ", ".join(remembered),
				"@onready var __ef_remember_boot: bool = _ef_recall_remembered()")
		BAND_INCLUDE:
			var includes: PackedStringArray = head_facts.get("includes", PackedStringArray())
			if includes.is_empty():
				return {}
			var names: PackedStringArray = PackedStringArray()
			for include_path: String in includes:
				names.append(include_path.get_file())
			# No echo: an include is merged into this sheet at compile time rather than written as a
			# line of it, and a band never invents a line the file does not have.
			return _make(kind, ", ".join(names), "")
		BAND_ATTACH:
			if bool(head_facts.get("attached", true)):
				return {}
			var attach: Dictionary = _make(kind, "", "")
			attach["prompt"] = "attach to a node"
			return attach
	return {}


## The name band. A file with `class_name` wears it bold beside its class icon; a file without one
## is named by something else, and the band says which: the autoload entry for a global, the file
## itself for everything else. A sheet that has neither yet asks to be named.
static func _name_band(head_facts: Dictionary) -> Dictionary:
	var declared_class: String = str(head_facts.get("class_name", "")).strip_edges()
	if not declared_class.is_empty():
		return _make(BAND_NAME, declared_class, "class_name %s" % declared_class)
	var file_name: String = str(head_facts.get("file_name", "")).strip_edges()
	if file_name.is_empty():
		var asking: Dictionary = _make(BAND_NAME, "Untitled", "# no class_name yet")
		asking["value_muted"] = true
		asking["echo_ghosted"] = true
		asking["prompt"] = "name it"
		return asking
	var named_by_file: Dictionary = _make(BAND_NAME, file_name,
		"# no class_name - the name is the autoload entry" \
			if not str(head_facts.get("autoload", "")).strip_edges().is_empty() \
			else "# no class_name - named by its file")
	named_by_file["value_muted"] = true
	return named_by_file


## The extends band. Always there - a script always extends something, and a sheet that has not
## been told what it extends is a Node being asked the question.
static func _extends_band(head_facts: Dictionary) -> Dictionary:
	var extends_target: String = str(head_facts.get("extends", "")).strip_edges()
	if extends_target.is_empty():
		var asking: Dictionary = _make(BAND_EXTENDS, "Node", "extends Node")
		asking["value_muted"] = true
		asking["prompt"] = "choose what it extends"
		return asking
	return _make(BAND_EXTENDS, extends_target, "extends %s" % extends_target)


## The `@tool` band: a switch. On, it is the line. Off, it is still shown - with the switch off and
## the echo ghosted - for the kinds that usually run in the editor, so the control is findable
## exactly where it is most often missing; every other sheet is offered it under "+ add".
static func _tool_band(head_facts: Dictionary) -> Dictionary:
	var switched_on: bool = bool(head_facts.get("tool", false))
	if not switched_on and not tool_is_expected(str(head_facts.get("extends", ""))):
		return {}
	var band: Dictionary = _make(BAND_TOOL, "runs in the editor too", "@tool")
	band["switch"] = true
	band["switch_on"] = switched_on
	band["echo_ghosted"] = not switched_on
	return band


## The autoload band. Its value is the singleton NAME - the word every other sheet writes to reach
## this file - and its echo is the `project.godot` entry, because that entry is where the name
## lives; nothing in this file says it.
static func _autoload_band(head_facts: Dictionary) -> Dictionary:
	var autoload_name: String = str(head_facts.get("autoload", "")).strip_edges()
	if autoload_name.is_empty():
		return {}
	var path: String = str(head_facts.get("source_path", "")).strip_edges()
	return _make(BAND_AUTOLOAD, autoload_name,
		"project.godot: autoload/%s = \"*%s\"" % [autoload_name, path] if not path.is_empty() \
			else "project.godot: autoload/%s" % autoload_name)


## True when a sheet extending this class usually carries `@tool`.
static func tool_is_expected(extends_target: String) -> bool:
	return TOOL_IS_EXPECTED_ON.has(extends_target.strip_edges())


## One band with its defaults filled in, so every reader of a band can address every key.
static func _make(kind: String, value: String, echo: String) -> Dictionary:
	return {
		"kind": kind,
		"leader": str(LEADERS.get(kind, "")),
		"value": value,
		"echo": echo,
		"echo_ghosted": false,
		"value_muted": false,
		"prompt": "",
		"editable": false,
		"switch": false,
		"switch_on": false,
		"control": str(CONTROL_LABELS.get(kind, "")),
	}


## The facts dictionary, built in one place so every caller answers the same keys.
static func _facts_dictionary(declared_class: String, file_name: String, extends_target: String,
		icon_path: String, has_tool: bool, described: String, autoload_name: String,
		source_path: String, host_class: String, remembered: PackedStringArray,
		includes: PackedStringArray, attached: bool) -> Dictionary:
	return {
		"class_name": declared_class,
		"file_name": file_name,
		"extends": extends_target,
		"icon": icon_path,
		"tool": has_tool,
		"description": described,
		"autoload": autoload_name,
		"source_path": source_path,
		"host": host_class,
		"remembered": remembered,
		"includes": includes,
		"attached": attached,
	}


## The text inside the first pair of quotes on a line - `@icon("res://x.svg")` -> `res://x.svg`.
static func _quoted_argument(line: String) -> String:
	var opening: int = line.find("\"")
	if opening < 0:
		return ""
	var closing: int = line.find("\"", opening + 1)
	if closing < 0:
		return ""
	return line.substr(opening + 1, closing - opening - 1)
