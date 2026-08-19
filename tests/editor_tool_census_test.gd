# Godot EventSheets - R35. What a sheet or a pack ADDS TO THE EDITOR, and the three places that say
# so: the Anatomy rail's EDITOR TOOLS section, a pack's Include bar, and the picker's pack card.
#
# The census has two doors because its two callers hold two different things - an authored sheet's
# rows, and an installed pack's emitted GDScript - so both are pinned here against the same fixture,
# and the labels are pinned as VALUES because they are what a reader sees.
@tool
class_name EditorToolCensusTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _test_from_sheet() and all_passed
	all_passed = _test_from_source() and all_passed
	all_passed = _test_summary() and all_passed
	all_passed = _test_anatomy_section() and all_passed
	all_passed = _test_editor_reference_page() and all_passed
	return all_passed


## An authored plugin sheet answers from its rows, naming what each row actually adds.
static func _test_from_sheet() -> bool:
	var passed: bool = true
	var entries: Array[Dictionary] = EventSheetEditorToolCensus.from_sheet(_plugin_sheet())
	passed = _check("an authored plugin lists what it adds",
		"|".join(EventSheetEditorToolCensus.labels(entries)),
		"Tools menu ▸ Snap Selection|dock: Waypoints|object type: Waypoint") and passed
	passed = _check("a sheet that adds nothing lists nothing",
		EventSheetEditorToolCensus.from_sheet(EventSheetResource.new()).size(), 0) and passed
	passed = _check("a null sheet lists nothing",
		EventSheetEditorToolCensus.from_sheet(null).size(), 0) and passed
	return passed


## An installed pack answers from its emitted script, without being opened.
static func _test_from_source() -> bool:
	var passed: bool = true
	var source: String = "\n".join(PackedStringArray([
		"func _enter_tree() -> void:",
		"\tadd_tool_menu_item(\"Snap Selection\", _run_tool)",
		"\tadd_control_to_dock(EditorPlugin.DOCK_SLOT_LEFT_UL, _panel)",
		"\tadd_custom_type(\"Waypoint\", \"Node2D\", null, null)",
	]))
	passed = _check("a compiled plugin lists what it adds",
		"|".join(EventSheetEditorToolCensus.labels(EventSheetEditorToolCensus.from_source(source))),
		"Tools menu ▸ Snap Selection|dock|object type: Waypoint") and passed
	# A dock's control is an expression, not a name, so the entry stays the plain word rather than
	# inventing one. An ordinary game script adds nothing at all.
	passed = _check("an ordinary script lists nothing",
		EventSheetEditorToolCensus.from_source("func _ready() -> void:\n\tadd_child(Node2D.new())").size(), 0) and passed
	return passed


## The Include bar's line, counted per kind and pluralised.
static func _test_summary() -> bool:
	var passed: bool = true
	passed = _check("the Include bar counts what the pack adds",
		EventSheetEditorToolCensus.summary(EventSheetEditorToolCensus.from_sheet(_plugin_sheet())),
		"adds 1 Tools menu item, 1 dock, 1 object type") and passed
	passed = _check("two docks read as two docks",
		EventSheetEditorToolCensus.summary(EventSheetEditorToolCensus.from_source(
			"add_control_to_dock(a, b)\nadd_control_to_dock(c, d)")),
		"adds 2 docks") and passed
	passed = _check("a pack that adds nothing says nothing",
		EventSheetEditorToolCensus.summary([] as Array[Dictionary]), "") and passed
	return passed


## The rail gains an EDITOR TOOLS organ, and it only appears with something in it.
static func _test_anatomy_section() -> bool:
	var passed: bool = true
	var organs: Array = BehaviourAnatomyPanel.collect_anatomy(_plugin_sheet())
	var editor_tools: Dictionary = {}
	for organ: Variant in organs:
		if str((organ as Dictionary).get("id", "")) == "editor_tools":
			editor_tools = organ as Dictionary
	passed = _check("the rail has an EDITOR TOOLS organ", editor_tools.is_empty(), false) and passed
	passed = _check("its title is the mockup's words", str(editor_tools.get("title", "")), "Editor Tools") and passed
	var labels: PackedStringArray = PackedStringArray()
	for entry: Variant in (editor_tools.get("entries", []) as Array):
		labels.append(str((entry as Dictionary).get("label", "")))
	passed = _check("it lists what the plugin adds",
		"|".join(labels), "Tools menu ▸ Snap Selection|dock: Waypoints|object type: Waypoint") and passed
	var plain_organs: Array = BehaviourAnatomyPanel.collect_anatomy(EventSheetResource.new())
	var plain_entries: int = -1
	for organ: Variant in plain_organs:
		if str((organ as Dictionary).get("id", "")) == "editor_tools":
			plain_entries = ((organ as Dictionary).get("entries", []) as Array).size()
	passed = _check("a game sheet's EDITOR TOOLS organ is empty", plain_entries, 0) and passed
	return passed


## R20. The Editor object's own reference page, in the fixed shape. The vocabulary is filed as the
## "Editor Tools" section, so the page derives - what is pinned here is that it EXISTS and leads with
## a sentence, because a page that resolves to an empty table is the failure this checks for.
static func _test_editor_reference_page() -> bool:
	var passed: bool = true
	passed = _check("the Editor object has a reference page",
		EventSheetDocReference.has_page("reference:section/Editor Tools"), true) and passed
	passed = _check("its title is the object's own name",
		EventSheetDocReference.title_for(EventSheetDocReference.KIND_SECTION, "Editor Tools"), "Editor Tools") and passed
	passed = _check("the page leads with what the object is for",
		EventSheetSectionInfo.description_for("Editor Tools").begins_with("Automate the Godot editor"), true) and passed
	return passed


## A plugin sheet that adds one of each nameable capability, built the way the Sheet Type dialog's
## ticks build it.
static func _plugin_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "EditorPlugin"
	sheet.tool_mode = true
	var enabled: EventRow = EventRow.new()
	enabled.trigger_provider_id = "Core"
	enabled.trigger_id = "OnPluginEnabled"
	enabled.actions.append(_action("AddToolsMenuItem", {"title": "\"Snap Selection\"", "handler": "_run_tool"}))
	enabled.actions.append(_action("AddEditorDock", {"control": "Waypoints", "slot": "EditorPlugin.DOCK_SLOT_LEFT_UL"}))
	enabled.actions.append(_action("AddEditorObjectType", {"type_name": "\"Waypoint\"", "base": "\"Node2D\""}))
	sheet.events.append(enabled)
	return sheet


static func _action(ace_id: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	return action


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual != expected:
		print("  [FAIL] %s (got %s, expected %s)" % [label, actual, expected])
		return false
	print("[PASS] editor_tool_census_test: %s" % label)
	return true
