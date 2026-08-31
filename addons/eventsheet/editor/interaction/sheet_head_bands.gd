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
const BAND_SYNC: String = "sync"
const BAND_SPAWNED: String = "spawned"
const BAND_SPAWNS: String = "spawns"
const BAND_LIT_BY: String = "lit_by"
const BAND_SHADOWS: String = "shadows"
const BAND_ENVIRONMENT: String = "environment"
const BAND_EFFECT: String = "effect"
const BAND_ANIMATIONS: String = "animations"
const BAND_TRANSFORM: String = "transform"
const BAND_COLLISIONS: String = "collisions"
const BAND_FILES: String = "files"
const BAND_MODES: String = "modes"
## The states of ONE OBJECT - the same fact as the modes band, one level down: the game has a mode
## and each object has a state, and both are an enum plus a variable this file declares.
const BAND_STATES: String = "states"
const BAND_REMEMBER: String = "remember"
const BAND_INCLUDE: String = "include"
const BAND_ATTACH: String = "attach"

## The row that plays one animation with another queued behind it, and the parameter holding the one
## that plays FIRST. Named here because the head asks whether that first animation loops - a queue
## behind a looping animation is never reached.
const CHAIN_ACE: String = "PlayThenQueue"
const CHAIN_LEAD_PARAM: String = "animation"

## Reading order: the name leads, then what it extends, then the annotations, then the prose, then
## the facts that live outside the file. This is the file's own order with the name promoted, which
## is the order a reader recites the head in.
const ORDER: PackedStringArray = [
	BAND_NAME, BAND_EXTENDS, BAND_ICON, BAND_TOOL, BAND_DESCRIPTION,
	BAND_AUTOLOAD, BAND_HOST, BAND_SYNC, BAND_SPAWNED, BAND_SPAWNS,
	BAND_LIT_BY, BAND_SHADOWS, BAND_ENVIRONMENT, BAND_EFFECT, BAND_ANIMATIONS, BAND_TRANSFORM,
	BAND_COLLISIONS, BAND_FILES,
	BAND_MODES, BAND_STATES, BAND_REMEMBER, BAND_INCLUDE, BAND_ATTACH,
]

## The bands that come from the SCENE rather than from the file, and the key each
## reads its entries from. These are the kinds a sheet can wear SEVERAL of (a scene may hold two
## synchronizers, and a lit room holds a light per band), so they are built as a list instead of as
## one band per kind. Every one of them is read on open and stored nowhere.
const SCENE_BANDS: Dictionary = {
	BAND_SYNC: "synchronizers",
	BAND_SPAWNED: "spawned_by",
	BAND_SPAWNS: "spawns",
	BAND_LIT_BY: "lit_by",
	BAND_SHADOWS: "shadow_facts",
	BAND_ENVIRONMENT: "environment",
	BAND_EFFECT: "effect",
	BAND_ANIMATIONS: "animations",
	BAND_TRANSFORM: "transform",
	BAND_COLLISIONS: "collisions",
	BAND_FILES: "files",
}

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
	BAND_SYNC: "keeps in step",
	BAND_SPAWNED: "spawned by",
	BAND_SPAWNS: "spawns",
	BAND_LIT_BY: "lit by",
	BAND_SHADOWS: "shadows",
	BAND_ENVIRONMENT: "environment",
	BAND_EFFECT: "effect",
	BAND_ANIMATIONS: "animations",
	BAND_TRANSFORM: "transform",
	BAND_COLLISIONS: "collisions",
	BAND_FILES: "files",
	BAND_MODES: "modes",
	BAND_STATES: "states",
	BAND_REMEMBER: "remember",
	BAND_INCLUDE: "include",
	BAND_ATTACH: "attach",
}

## Band -> the LINE of the file it stands for: the `prefix` a line is recognised by, and the
## `format` it is written with. One table, so the reader that finds a line, the parser that lifts
## its value and the writer that replaces it can never disagree about which line a band is. `@tool`
## matches whole (`exact`); the `##` description excludes `## @`, because an annotation is markup
## and not the sheet's prose. A band with no row here has no line of its own - an autoload's name
## lives in project.godot, an include is merged at compile time - and is never written by hand.
const LINE_SHAPES: Dictionary = {
	BAND_NAME: {"prefix": "class_name ", "format": "class_name %s"},
	BAND_EXTENDS: {"prefix": "extends ", "format": "extends %s"},
	BAND_ICON: {"prefix": "@icon", "format": "@icon(\"%s\")"},
	BAND_TOOL: {"prefix": "@tool", "format": "@tool", "exact": true},
	BAND_DESCRIPTION: {"prefix": "## ", "format": "## %s"},
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
	var host_bound: bool = false
	var description_lines: PackedStringArray = PackedStringArray()
	# Every key answered, so a reader of the facts can address any of them whatever the sheet is.
	var head: Dictionary = {
		"class_name": "", "file_name": "", "extends": "", "icon": "", "tool": false,
		"description": "", "autoload": "", "source_path": "", "host": "",
		"remembered": PackedStringArray(), "includes": PackedStringArray(), "attached": attached,
	}
	for raw_line: String in scaffold_code.split("\n"):
		var line: String = raw_line.strip_edges()
		if line_is(line, BAND_NAME) and str(head["class_name"]).is_empty():
			head["class_name"] = line.trim_prefix("class_name ").strip_edges()
		elif line_is(line, BAND_EXTENDS) and str(head["extends"]).is_empty():
			head["extends"] = line.trim_prefix("extends ").strip_edges()
		elif line_is(line, BAND_ICON) and str(head["icon"]).is_empty():
			head["icon"] = _quoted_argument(line)
		elif line_is(line, BAND_TOOL):
			head["tool"] = true
		elif line.begins_with("func _enter_tree") or line.begins_with("host = get_parent"):
			host_bound = true
		elif line_is(line, BAND_DESCRIPTION):
			description_lines.append(line.trim_prefix("## ").strip_edges())
	# One entry per LINE, joined the way the sheet's own `class_description` field holds it. Joining
	# them into one sentence would make the band echo a line the file does not have.
	head["description"] = "\n".join(description_lines).strip_edges()
	if sheet == null:
		return head
	# The sheet's own fields answer for anything the prelude text did not say - a `.tres` sheet the
	# compiler will write those lines for has no text to read them from.
	if str(head["class_name"]).is_empty():
		head["class_name"] = sheet.custom_class_name.strip_edges()
	if str(head["extends"]).is_empty():
		head["extends"] = sheet.host_class.strip_edges()
	if str(head["icon"]).is_empty():
		head["icon"] = sheet.custom_class_icon.strip_edges()
	head["tool"] = bool(head["tool"]) or sheet.tool_mode
	if str(head["description"]).is_empty():
		head["description"] = sheet.class_description.strip_edges()
	var source_path: String = str(sheet.external_source_path).strip_edges()
	head["file_name"] = source_path.get_file()
	head["source_path"] = source_path
	head["autoload"] = sheet.autoload_singleton_name()
	head["host"] = sheet.host_class.strip_edges() if host_bound or sheet.behavior_mode else ""
	head["remembered"] = remembered_variables(sheet)
	head["includes"] = PackedStringArray(sheet.includes)
	# The game's own modes, when this sheet is the one that declares them. Read from the sheet's own
	# declarations - a sheet that never declared any grows no band, which is every sheet in a project
	# that does not think in modes.
	head["modes"] = EventSheetModeFacts.band_reading(sheet)
	head["modes_echo"] = EventSheetModeFacts.band_echo(sheet)
	# And this OBJECT's own states, when this sheet is the one that declares them - the same fact one
	# level down, read the same way, from the sheet's own declarations.
	head["states"] = EventSheetStateFacts.band_reading(sheet)
	head["states_echo"] = EventSheetStateFacts.band_echo(sheet)
	return head


## True when one line of a file IS the line a band stands for.
static func line_is(line: String, band_kind: String) -> bool:
	var shape: Dictionary = LINE_SHAPES.get(band_kind, {})
	if shape.is_empty():
		return false
	if bool(shape.get("exact", false)):
		return line == str(shape["prefix"])
	if band_kind == BAND_DESCRIPTION and line.begins_with("## @"):
		return false
	return line.begins_with(str(shape["prefix"]))


## The ONE line of a doc-comment block the `##` band stands for: its first. A doc comment is one
## `## ` line per line of prose, and a band is one line of the file - joining the block into a single
## sentence would echo a line nothing in the file says, so the band is the first line and the rest of
## the block is left where the reader wrote it.
static func description_line(description: String) -> String:
	return description.strip_edges().split("\n")[0].strip_edges()


## That same block with only the band's own line rewritten - "" for the whole block when it had one
## line and that line is being cleared. Every line after the first comes back untouched, because the
## band was never standing for them.
static func replace_description_line(description: String, new_line: String) -> String:
	var lines: PackedStringArray = description.strip_edges().split("\n")
	var rest: PackedStringArray = lines.slice(1) if lines.size() > 1 else PackedStringArray()
	var written: String = new_line.strip_edges()
	if written.is_empty():
		return "\n".join(rest)
	var kept: PackedStringArray = PackedStringArray([written])
	kept.append_array(rest)
	return "\n".join(kept)


## The exact line a band writes, "" when the band's value means "no such line" - an emptied field,
## or the `@tool` switch turned off.
static func line_text(band_kind: String, new_value: String) -> String:
	var shape: Dictionary = LINE_SHAPES.get(band_kind, {})
	if shape.is_empty():
		return ""
	var value: String = new_value.strip_edges()
	if bool(shape.get("exact", false)):
		return str(shape["format"]) if value == "true" else ""
	return "" if value.is_empty() else str(shape["format"]) % value


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
		if SCENE_BANDS.has(kind):
			built.append_array(_scene_bands(kind, head_facts))
			continue
		var band: Dictionary = _band(kind, head_facts)
		if not band.is_empty():
			built.append(band)
	return built


## The scene's bands: one per synchronizer that keeps this sheet's object in step, one per
## spawner elsewhere that can make its scene. The readings and the echoes are composed by the scene
## reader (a band never spells a fact itself), and each band carries the node it is about so its
## control can open the editor that owns it.
static func _scene_bands(kind: String, head_facts: Dictionary) -> Array[Dictionary]:
	var built: Array[Dictionary] = []
	var entries: Variant = head_facts.get(str(SCENE_BANDS[kind]))
	if not (entries is Array):
		return built
	for entry: Variant in entries as Array:
		var reading: Dictionary = entry
		var band: Dictionary = _make(kind, str(reading.get("value", "")), str(reading.get("echo", "")))
		band["reference"] = str(reading.get("reference", ""))
		# A fact that is a PROBLEM wears the problem's colour and the problem's words. The
		# reader composed both, so the band and the Doctor finding about the same scene agree.
		band["warning"] = bool(reading.get("warning", false))
		built.append(band)
	return built


## Everything the SCENE says about a sheet, in the shape `bands()` reads: one entry per
## synchronizer and one per spawner, each already written as the words the band shows and the lines
## of the file they came from. Empty for a sheet no scene runs, which is why nothing about
## replication appears in a project that has none.
static func scene_facts(sheet: EventSheetResource) -> Dictionary:
	var facts: Dictionary = {"synchronizers": [], "spawned_by": [], "spawns": [],
		"lit_by": [], "shadow_facts": [], "environment": [], "effect": [], "animations": [],
		"transform": [], "collisions": [], "files": []}
	if sheet == null:
		return facts
	var source_path: String = str(sheet.external_source_path)
	# And what it PUTS INTO the world: one band per scene this sheet spawns, with the cap and the pool
	# the sheet's own rows put on it, and a count of the rest. The rows are already in memory and the
	# scene side is the replication index the "spawned by" band above reads, so this is a join over
	# two answers somebody else already paid for rather than a scan of its own.
	facts["spawns"] = EventSheetSpawnFacts.bands(sheet)
	# The lighting the scene already has: one band per light, the occluders that can block
	# their shadows, and the environment resource the scene holds (and who else holds it).
	facts["lit_by"] = EventSheetSceneLightingFacts.lit_by(source_path)
	facts["shadow_facts"] = EventSheetSceneLightingFacts.shadow_bands(source_path)
	facts["environment"] = EventSheetSceneLightingFacts.environment_bands(source_path)
	# And what it WEARS: the material file behind each node's effect, the shader at the end of the
	# chain, and how many other nodes of the project wear the same file - the count that turns one
	# dial row into twelve. The sheet's own rows say which nodes have already been given a copy.
	facts["effect"] = EventSheetSceneEffectFacts.effect_bands(source_path,
		EventSheetEffectFindings.nodes_given_their_own_copy(sheet))
	# And what it can PLAY: the animations the rows name, with a count of the rest, per node. The
	# names the sheet uses are read once here and handed in, because the same list is what says
	# which of them the scene has never heard of.
	var animation_values: Array[Dictionary] = EventForgeSheetParamValues.of_hint(sheet,
		EventSheetCompletions.FIELD_ANIMATION)
	facts["animations"] = EventSheetSceneAnimations.bands(source_path,
		_values_of(animation_values), _chain_leads(animation_values))
	# And the transform facts that are about to bite: this node sitting inside something scaled, a
	# body mirrored by a negative scale, a node scaled unevenly and turned. A scene with nothing
	# scaled grows none of them.
	facts["transform"] = EventSheetSceneTransformFacts.bands(source_path)
	# And who it can TOUCH: the layers this object's mask covers, the layers of everything whose mask
	# covers one of its own, and - for an Area - whether the switch that reports touches is even on.
	# All three live in the `.tscn` and none of them is visible from the row that depends on them,
	# which is why a sheet whose node collides wears them at the top of it.
	facts["collisions"] = EventSheetSceneCollisionFacts.bands(source_path)
	# And what it touches ON DISK: the paths its own rows write, the paths they read, and whether it
	# stops to ask the player for one. Read off the rows already in memory - nothing here opens a
	# file to find out what a file row says.
	facts["files"] = EventSheetFileFacts.bands(sheet)
	var scene: Dictionary = EventSheetSceneReplication.for_script(str(sheet.external_source_path))
	for entries: Variant in EventSheetSceneReplication.by_synchronizer(scene.get("synced", [])).values():
		var group: Array = entries
		if group.is_empty():
			continue
		var lead: Dictionary = group[0]
		(facts["synchronizers"] as Array).append({
			"value": EventSheetSceneReplication.synchronizer_reading(group),
			"echo": EventSheetSceneReplication.synchronizer_echo(group),
			"reference": "%s|%s" % [str(lead.get("scene_path", "")), str(lead.get("synchronizer_path", ""))],
		})
	for entry: Variant in scene.get("spawners", []) as Array:
		var spawner: Dictionary = entry
		if str(spawner.get("relation", "")) != EventSheetSceneReplication.RELATION_SPAWNS_THIS:
			continue
		(facts["spawned_by"] as Array).append({
			"value": EventSheetSceneReplication.spawner_reading(spawner),
			"echo": EventSheetSceneReplication.spawner_echo(spawner),
			"reference": "%s|%s" % [str(spawner.get("scene_path", "")), str(spawner.get("node_path", ""))],
		})
	return facts


## The lines this sheet could have and does not - what the "+ add" row under the stack offers, in
## the same reading order. Never autoload or host: those come from choosing a kind, not from adding
## a line.
static func addable(head_facts: Dictionary) -> PackedStringArray:
	var offers: PackedStringArray = PackedStringArray()
	for kind: String in [BAND_ICON, BAND_TOOL, BAND_DESCRIPTION]:
		if _band(kind, head_facts).is_empty():
			offers.append(kind)
	# Modes are offered only on the sheet a whole game's state would live on - an Autoload, which is
	# what the engine's own guide says global state is for. Offering them on every enemy's sheet
	# would be inviting a hundred games to have a hundred modes.
	if str(head_facts.get("modes", "")).strip_edges().is_empty() \
			and not str(head_facts.get("autoload", "")).strip_edges().is_empty():
		offers.append(BAND_MODES)
	# States are the mirror offer, one level down: an OBJECT's own machine, so they are offered on
	# every sheet that is not the game's spine. A sheet that IS an autoload is the game, and what a
	# game has is modes.
	if str(head_facts.get("states", "")).strip_edges().is_empty() \
			and str(head_facts.get("autoload", "")).strip_edges().is_empty():
		offers.append(BAND_STATES)
	return offers


## The word the "+ add" row uses for one offer. `@tool` is the annotation itself - a line of
## GDScript rather than a word about one - so it is offered under its own spelling in every language.
static func add_label(kind: String) -> String:
	match kind:
		BAND_ICON:
			return EventSheetL10n.translate("icon")
		BAND_DESCRIPTION:
			return EventSheetL10n.translate("description")
		BAND_TOOL:
			return "@tool"
		BAND_MODES:
			return EventSheetL10n.translate("modes")
		BAND_STATES:
			return EventSheetL10n.translate("states")
	return kind


## The word on one band's control, "" where the band's own gesture IS the control (the name band
## renames on F2 / double-click, the description edits in place, the `@tool` switch is the switch).
static func control_label(kind: String) -> String:
	match kind:
		BAND_EXTENDS, BAND_ICON:
			return EventSheetL10n.translate("change…")
		BAND_AUTOLOAD:
			return EventSheetL10n.translate("Project Settings…")
		BAND_INCLUDE:
			return EventSheetL10n.translate("open")
		BAND_SYNC:
			return EventSheetL10n.translate("Replication panel…")
		BAND_SPAWNED:
			return EventSheetL10n.translate("select the spawner")
		BAND_SPAWNS:
			return EventSheetL10n.translate("browse the scene")
		BAND_LIT_BY, BAND_SHADOWS:
			return EventSheetL10n.translate("select the light")
		BAND_ENVIRONMENT, BAND_EFFECT, BAND_COLLISIONS:
			return EventSheetL10n.translate("select the node")
		BAND_MODES:
			return EventSheetL10n.translate("Edit modes…")
		BAND_STATES:
			return EventSheetL10n.translate("Declare states…")
	return ""


## The whole "+ add" row's text, "" when this sheet already has every line it could have.
static func add_row_text(head_facts: Dictionary) -> String:
	var offers: PackedStringArray = addable(head_facts)
	if offers.is_empty():
		return ""
	var words: PackedStringArray = PackedStringArray()
	for kind: String in offers:
		words.append(add_label(kind))
	return EventSheetL10n.translate("+ add: %s") % " · ".join(words)


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
			var described: String = description_line(str(head_facts.get("description", "")))
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
			return _make(kind, EventSheetL10n.translate("acts on its parent"),
				"var host: %s · _enter_tree: host = get_parent()" % host_class)
		BAND_MODES:
			# One fact, and it really is one: what the modes of this game ARE, which includes the one
			# it opens on. The line it stands for is the enum, in the emitter's own words.
			var listed: String = str(head_facts.get("modes", "")).strip_edges()
			if listed.is_empty():
				return {}
			return _make(kind, listed, str(head_facts.get("modes_echo", "")))
		BAND_STATES:
			# One fact again, one level down: what the states of this object ARE, including the one it
			# starts in. THIS BAND IS THE DIAGRAM - there is no graph, no wires and no canvas of boxes
			# anywhere in this feature, because a state is a variable and a variable reads as a line.
			var states: String = str(head_facts.get("states", "")).strip_edges()
			if states.is_empty():
				return {}
			return _make(kind, states, str(head_facts.get("states_echo", "")))
		BAND_REMEMBER:
			var remembered: PackedStringArray = head_facts.get("remembered", PackedStringArray())
			if remembered.is_empty():
				return {}
			return _make(kind, EventSheetL10n.translate("%s kept between runs") % ", ".join(remembered),
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
			attach["prompt"] = EventSheetL10n.translate("attach to a node")
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
		var asking: Dictionary = _make(BAND_NAME, EventSheetL10n.translate("Untitled"),
			EventSheetL10n.translate("# no class_name yet"))
		asking["value_muted"] = true
		asking["echo_ghosted"] = true
		asking["prompt"] = EventSheetL10n.translate("name it")
		return asking
	var named_by_file: Dictionary = _make(BAND_NAME, file_name,
		EventSheetL10n.translate("# no class_name - the name is the autoload entry") \
			if not str(head_facts.get("autoload", "")).strip_edges().is_empty() \
			else EventSheetL10n.translate("# no class_name - named by its file"))
	named_by_file["value_muted"] = true
	return named_by_file


## The extends band. Always there - a script always extends something, and a sheet that has not
## been told what it extends is a Node being asked the question.
static func _extends_band(head_facts: Dictionary) -> Dictionary:
	var extends_target: String = str(head_facts.get("extends", "")).strip_edges()
	if extends_target.is_empty():
		var asking: Dictionary = _make(BAND_EXTENDS, "Node", "extends Node")
		asking["value_muted"] = true
		asking["prompt"] = EventSheetL10n.translate("choose what it extends")
		return asking
	return _make(BAND_EXTENDS, extends_target, "extends %s" % extends_target)


## The `@tool` band: a switch. On, it is the line. Off, it is still shown - with the switch off and
## the echo ghosted - for the kinds that usually run in the editor, so the control is findable
## exactly where it is most often missing; every other sheet is offered it under "+ add".
static func _tool_band(head_facts: Dictionary) -> Dictionary:
	var switched_on: bool = bool(head_facts.get("tool", false))
	if not switched_on and not tool_is_expected(str(head_facts.get("extends", ""))):
		return {}
	var band: Dictionary = _make(BAND_TOOL, EventSheetL10n.translate("runs in the editor too"), "@tool")
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
		# The thing OUTSIDE this file a band is about ("scene|node"), so its control can open
		# the editor that owns the fact. "" for every band that stands for a line of the file.
		"reference": "",
		# Whether this band's fact is a PROBLEM, in which case its words are the warning the
		# Doctor raises about the same scene and the canvas draws them in the note colour.
		"warning": false,
		"control": control_label(kind),
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


## The distinct values of a walk's entries, first mention first - the names a band spells.
static func _values_of(entries: Array[Dictionary]) -> PackedStringArray:
	var values: PackedStringArray = PackedStringArray()
	for entry: Dictionary in entries:
		var value: String = str(entry.get("value", "")).strip_edges()
		if not value.is_empty() and not values.has(value):
			values.append(value)
	return values


## The animations of a walk that a row plays with something QUEUED behind them - the first half of a
## chain row. Read out of the same walk as the names above, because the chain question is about the
## same rows and paying for a second one would be paying twice for one answer.
static func _chain_leads(entries: Array[Dictionary]) -> PackedStringArray:
	var leads: PackedStringArray = PackedStringArray()
	for entry: Dictionary in entries:
		if str(entry.get("ace_id", "")) == CHAIN_ACE and str(entry.get("param", "")) == CHAIN_LEAD_PARAM:
			leads.append(str(entry.get("value", "")))
	return leads
