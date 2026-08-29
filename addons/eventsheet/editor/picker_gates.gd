# EventSheet - EventSheetPickerGates: no entry disappears from the picker for a fixable reason.
#
# The picker used to FILTER entries whose precondition the project did not meet yet: a behavior's
# host verbs off a plain sheet, the Editor object off a game sheet. An entry that vanishes teaches
# nothing - the reader cannot learn what a fix would even be, because the thing to fix is not on
# screen. So every fixable precondition became a GATE instead: the entry stays listed, greyed, and
# its one-line reason IS the fix - selecting the entry turns the Add button into the fix's own
# label, and pressing it performs the fix and then carries on to the row the reader wanted.
#
# The table below is the whole law. Each gate names:
#   id         the stable name of the precondition (addressed by tests and the dock's fix dispatch)
#   reason     the one-line why, in the reader's words, with %s for the node class where one applies
#   fix_label  what the Add button says while this entry is gated
#   fix_id     what the dock does when it is pressed
#
# A gate without a reason and a fix is not allowed to exist - the suite walks this table and the
# hiding decision below and fails on any entry that would be hidden or disabled without both.
#
# WHAT MAY STILL BE HIDDEN is a closed list, and `hidden_reason` is the whole of it, so the words
# here and the picker's behaviour cannot drift apart:
#   the reader's own choices   an entry they hid, and Simple Mode's advanced rows
#   deprecated rows            still compile where they are used; never offered for NEW work
#   a project-scoped template  a row whose choices come from the scene is offered as the COPIES
#                              built from it - one per node, both halves already answered - so the
#                              bare template is not browsable. The family is on screen either way,
#                              which is why this is not a wall: hiding the template hides nothing a
#                              reader could have picked.
# None of the three is a fixable project state, which is the property that matters: nothing
# disappears because of something a reader could put right and was never told about.
#
# Pure and static over its inputs: a definition and a context Dictionary in, a gate (or nothing)
# out, so the whole surface is pinned headlessly.
@tool
class_name EventSheetPickerGates
extends RefCounted

## The stable gate ids. Frozen the way check ids are: the dock's fix dispatch and the suite
## address them, so a gate is deprecated rather than renamed.
const GATE_BEHAVIOR_HOST := "behavior_host_only"
const GATE_EDITOR_TOOLS := "editor_tools_only"
const GATE_NEEDS_NODE := "needs_node_type"
const GATE_NEEDS_SCENE := "needs_scene"

## The two behavior-host verbs (they read the literal `host`, which only a behavior sheet's
## prelude declares) and the category whose rows only run inside the editor. Spelled here because
## this file must not reach back into the picker dialog - the picker's own statics delegate to
## these, so there is still exactly one answer.
const BEHAVIOR_HOST_PROVIDER := "Core"
const BEHAVIOR_HOST_ACE_IDS: Array[String] = ["BehaviorHost", "BehaviorHostValid"]
const EDITOR_TOOLS_CATEGORY := "Editor Tools"
const CATEGORY_PAGE_SEPARATOR := ": "

## Every gate the picker can put on an entry. Reasons and fix labels are English source strings -
## the translation keys of the editor's drop-in CSV catalogs - translated at display time by
## reason_text / fix_text below.
const GATES: Array[Dictionary] = [
	{
		"id": GATE_BEHAVIOR_HOST,
		"reason": "Runs only on a behavior sheet - it reads the behavior's host.",
		"fix_label": "Make this a behavior sheet…",
		"fix_id": "open_sheet_kind",
	},
	{
		"id": GATE_EDITOR_TOOLS,
		"reason": "Runs only inside the editor - this sheet needs Tool switched on.",
		"fix_label": "Switch Tool on for this sheet",
		"fix_id": "enable_tool",
	},
	{
		"id": GATE_NEEDS_NODE,
		"reason": "Needs a %s in the scene, and there is none yet.",
		"fix_label": "Add a %s to the scene",
		"fix_id": "add_node",
	},
	{
		"id": GATE_NEEDS_SCENE,
		"reason": "Listens to a %s, and this sheet is not attached to a scene yet.",
		"fix_label": "Attach this sheet to a scene…",
		"fix_id": "attach_scene",
	},
]


## The context a refresh computes ONCE and every gate question reads: what kind of sheet is open,
## and what the scene attached to it holds. `scene_known` is false when the sheet has no script
## file to ask about (an unsaved sheet, a .tres with no pairing) - and an unknown scene gates
## NOTHING, because a wall built on a guess is worse than no wall.
static func context_for(sheet: EventSheetResource, is_behavior_sheet: bool,
		tool_gate_wired: bool, is_tool_sheet: bool) -> Dictionary:
	var context: Dictionary = {
		"is_behavior_sheet": is_behavior_sheet,
		"tool_gate_wired": tool_gate_wired,
		"is_tool_sheet": is_tool_sheet,
		"scene_known": false,
		"has_scene": false,
		"scene_classes": PackedStringArray(),
	}
	if sheet == null:
		return context
	var script_path: String = str(sheet.external_source_path).strip_edges()
	if script_path.is_empty():
		return context
	var nodes: Array[Dictionary] = EventSheetSceneLights.nodes_for_script(script_path)
	context["scene_known"] = true
	context["has_scene"] = not nodes.is_empty()
	var classes: PackedStringArray = PackedStringArray()
	for node: Dictionary in nodes:
		var node_class: String = str(node.get("class", ""))
		if not node_class.is_empty() and not classes.has(node_class):
			classes.append(node_class)
	context["scene_classes"] = classes
	return context


## The reasons an entry may be left out of the listing altogether, as the ids the suite addresses.
## Frozen the way the gate ids are.
const HIDDEN_DEPRECATED := "deprecated"
const HIDDEN_PROJECT_TEMPLATE := "project_scoped_template"
const HIDDEN_READERS_CHOICE := "readers_choice"

## The metadata a definition wears for each: the deprecation mark, the mark that says a row's choices
## come from the project, and the scene node a COPY of such a row was built for.
const DEPRECATED_META := "deprecated"
const PROJECT_SCOPED_META := "project_scoped"
const SCENE_TARGET_META := "eventsheet_light_target"


## Why this definition is not in the listing at all, "" when it is. THE WHOLE CLOSED LIST: the picker
## asks here rather than deciding for itself, so the law stated at the top of this file is the law
## the picker keeps, and the suite can walk every shipped definition through it.
##
## `readers_choice` is not answered here - it is a live editor switch, not a fact about the
## definition - but it is named in the list so the three reasons are countable in one place.
static func hidden_reason(definition: ACEDefinition) -> String:
	if definition == null:
		return ""
	if bool(definition.metadata.get(DEPRECATED_META, false)):
		return HIDDEN_DEPRECATED
	if bool(definition.metadata.get(PROJECT_SCOPED_META, false)) \
			and str(definition.metadata.get(SCENE_TARGET_META, "")).is_empty():
		return HIDDEN_PROJECT_TEMPLATE
	return ""


## The one question the picker asks per entry: the gate this definition is behind in this context,
## or an empty Dictionary when it is offered plainly. The returned gate is the table's entry plus
## `node_type` where the reason names one.
static func gate_for(definition: ACEDefinition, context: Dictionary) -> Dictionary:
	if definition == null:
		return {}
	if is_behavior_host_ace(str(definition.provider_id), str(definition.id)) \
			and not bool(context.get("is_behavior_sheet", false)):
		return _gate(GATE_BEHAVIOR_HOST, "")
	if bool(context.get("tool_gate_wired", false)) and not bool(context.get("is_tool_sheet", false)) \
			and is_editor_tools_category(str(definition.category)):
		return _gate(GATE_EDITOR_TOOLS, "")
	var node_type: String = str(definition.metadata.get("node_type", "")).strip_edges()
	if node_type.is_empty() or not bool(context.get("scene_known", false)):
		return {}
	# An entry the picker built FROM the scene already names its node - the scene has it by
	# construction, so no gate may second-guess it.
	if not str(definition.metadata.get("eventsheet_light_target", "")).is_empty():
		return {}
	if not bool(context.get("has_scene", false)):
		# The sheet drives no scene at all. Said on the triggers - a trigger without a source can
		# never fire, which is the "nothing will happen" a beginner meets first - and left quiet on
		# the rest, so an unattached sheet reads as a sheet, not as a wall of grey.
		if definition.ace_type == ACEDefinition.ACEType.TRIGGER:
			return _gate(GATE_NEEDS_SCENE, node_type)
		return {}
	if not _scene_has_class(context, node_type):
		return _gate(GATE_NEEDS_NODE, node_type)
	return {}


## True when a class of the scene IS the wanted class or a subclass of it. A scene class ClassDB
## does not know (a script class) never satisfies a gate, and never trips one either - the walk
## simply cannot say, and an unknown answers "offered".
static func _scene_has_class(context: Dictionary, node_type: String) -> bool:
	if not ClassDB.class_exists(node_type):
		return true
	var classes: PackedStringArray = context.get("scene_classes", PackedStringArray())
	for scene_class: String in classes:
		if not ClassDB.class_exists(scene_class):
			return true
		if ClassDB.is_parent_class(scene_class, node_type):
			return true
	return false


## The table's entry for one id, with the node class the reason speaks about carried beside it.
static func _gate(gate_id: String, node_type: String) -> Dictionary:
	for entry: Dictionary in GATES:
		if str(entry.get("id", "")) == gate_id:
			var gate: Dictionary = entry.duplicate()
			gate["node_type"] = node_type
			return gate
	return {}


## The reason, translated and with its node class filled in - the one line the greyed entry shows.
static func reason_text(gate: Dictionary) -> String:
	return _filled(str(gate.get("reason", "")), str(gate.get("node_type", "")))


## What the Add button says while the entry is gated - the fix, as a button.
static func fix_text(gate: Dictionary) -> String:
	return _filled(str(gate.get("fix_label", "")), str(gate.get("node_type", "")))


static func _filled(template: String, node_type: String) -> String:
	var translated: String = EventSheetL10n.translate(template)
	if translated.contains("%s"):
		return translated % node_type
	return translated


## True for the two verbs only a behavior sheet's prelude can host. The picker's own
## host_ace_hidden delegates here, so the frozen static and the gate cannot disagree.
static func is_behavior_host_ace(provider_id: String, ace_id: String) -> bool:
	return provider_id == BEHAVIOR_HOST_PROVIDER and BEHAVIOR_HOST_ACE_IDS.has(ace_id)


## True for the Editor object's category and its pages ("Editor Tools: Panels & menus").
static func is_editor_tools_category(category: String) -> bool:
	return category == EDITOR_TOOLS_CATEGORY \
		or category.begins_with(EDITOR_TOOLS_CATEGORY + CATEGORY_PAGE_SEPARATOR)
