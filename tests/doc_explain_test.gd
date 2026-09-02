# EventSheets - "explain this row": id routing, assembled content, and the entry points (Phase 2)
#
# The reference surface is generated from the LIVE vocabulary, so almost all of it is pinnable
# headlessly. What this file pins:
#   - the doc id scheme, all three schemes, including the ids that must FAIL: an id that parses
#     but names nothing real returns false and warns, because a silently blank doc page is how a
#     renamed guide ships unnoticed;
#   - the page a REAL pack verb assembles (Quest's Advance Objective) - its title, its own
#     description, the GDScript line it ships as, its values, its figure, and its guide link,
#     with the pinned URL derived from the same version constant the release ritual bumps;
#   - which verb a clicked row explains: the clicked span wins over the row's trigger;
#   - that the three entry points (Tools ▸ Documentation…, F1, the row menu's "What does this
#     do?") all land on ONE dock method, and that the row item rides the public registration
#     seam rather than a hard-wired menu constant.
#
# Needs the windowed harness (not reachable here): that the window actually pops and draws (this
# suite must never open one), that F1 reaches the dock through Godot's real input routing, and
# that OS.shell_open opens a browser tab - the addon route is therefore pinned at the URL the
# caller would be handed, never by calling it.
@tool
class_name DocExplainTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const QUEST_ADDON_PATH: String = "res://eventsheet_addons/quest/quest_addon.gd"
const QUEST_PROVIDER: String = "QuestPackAddon"
const QUEST_ACE_ID: String = "method:advance_objective"
const DOCK_PATH: String = "res://addons/eventsheet/editor/event_sheet_dock.gd"
const MENU_BAR_PATH: String = "res://addons/eventsheet/editor/dock/menu_bar.gd"
const INPUT_DISPATCH_PATH: String = "res://addons/eventsheet/editor/dock/dock_input_dispatch.gd"


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _test_id_routing() and all_passed
	all_passed = _test_open_docs_refuses_unknown() and all_passed
	all_passed = _test_pack_verb_page() and all_passed
	all_passed = _test_row_to_doc_id() and all_passed
	all_passed = _test_entry_points() and all_passed
	all_passed = _test_page_shape() and all_passed
	return all_passed


## THE SHAPE OF A REFERENCE PAGE, which is what a reader learns once and then reuses on every verb:
## the two metadata badges beside the title, the parameters split into real table columns, and a
## section order that does not depend on the order the assembler happened to emit its blocks in.
## All three are pure, so they pin here; how they LOOK is the render harness's job.
static func _test_page_shape() -> bool:
	var all_passed: bool = true
	var definition: ACEDefinition = _quest_definition()
	if definition == null:
		return _check("Quest's Advance Objective is in the vocabulary", false, true)
	var blocks: Array[Dictionary] = EventSheetDocExplain.blocks_for_definition(definition)

	# Exactly two badges, in this order: what the verb IS, then where it comes from. A third badge
	# turns metadata into decoration, so the count is pinned as hard as the text.
	var badges: PackedStringArray = PackedStringArray(_block(blocks, "title").get("badges", []))
	all_passed = _check("the title carries its two metadata badges", ", ".join(badges), "Action, Quest") and all_passed
	all_passed = _check("a category page badges itself as one",
		", ".join(PackedStringArray(_block(EventSheetDocExplain.blocks_for_section("Debug"), "title").get("badges", []))),
		"Category") and all_passed

	# The parameters TABLE reads its columns as columns. The one-string `detail` stays for the form
	# row hosts that still use it, so both shapes are pinned off one real pack verb.
	var items: Array = _block(blocks, "params").get("items", []) as Array
	var first: Dictionary = items[0] as Dictionary
	all_passed = _check("a parameter names its own type", str(first.get("type", "")), "String") and all_passed
	all_passed = _check("a parameter with no declared default has an empty default cell",
		str(first.get("default", "")), "") and all_passed
	all_passed = _check("the one-string form still carries the type",
		str(first.get("detail", "")), "String") and all_passed
	all_passed = _check("the last parameter carries the default it declares",
		str((items[items.size() - 1] as Dictionary).get("default", "")), "0") and all_passed

	# A reflected pack method declares no blurbs, so the table drops the Description column rather
	# than drawing three blank cells. The rows are pinned as VALUES through the same pure seam.
	all_passed = _check("the table drops a column no parameter fills",
		", ".join(EventSheetDocPanel.parameter_columns(items)), "Name, Type, Default") and all_passed
	all_passed = _check("a parameter with a blurb keeps the Description column",
		", ".join(EventSheetDocPanel.parameter_columns([{"name": "Slot", "type": "int", "default": "0",
			"description": "Which save slot."}])), "Name, Type, Default, Description") and all_passed
	all_passed = _check("a row carries one cell per chosen column",
		", ".join(PackedStringArray(EventSheetDocPanel.parameter_rows(items)[0])), "Quest Id, String, ") and all_passed

	# The reading order. Pinned by VALUE, and then pinned again against a REVERSED block list,
	# because the whole point of the plan is that the page does not inherit the assembler's order.
	# This verb is REFLECTED, so it declares no field blurbs and no field kinds: the section that
	# repeats what the Parameters dialog says about each field has nothing to say and draws nothing,
	# which is why it is absent here and present on an authored verb. The "which guide teaches this"
	# section is absent for the same reason - nothing in the corpus TITLES or HEADS a section with
	# this verb's name, and a page that merely mentions it somewhere is not a section to land on.
	all_passed = _check("a pack verb's page reads in the fixed order",
		", ".join(EventSheetDocPanel.section_plan(blocks)),
		"title, description, syntax, parameters, preview, usage, project_usage, patterns, actions, about, link") and all_passed
	var shuffled: Array[Dictionary] = []
	for index: int in range(blocks.size()):
		shuffled.append(blocks[blocks.size() - 1 - index])
	all_passed = _check("the order does not follow the order the blocks arrived in",
		", ".join(EventSheetDocPanel.section_plan(shuffled)),
		", ".join(EventSheetDocPanel.section_plan(blocks))) and all_passed
	all_passed = _check("a category page reads as the sections it actually has",
		", ".join(EventSheetDocPanel.section_plan(EventSheetDocExplain.blocks_for_section("Debug"))),
		"title, description") and all_passed
	return all_passed


static func _test_id_routing() -> bool:
	var all_passed: bool = true
	var index: Dictionary = EventSheetDocExplain.resolve("")
	all_passed = _check("an empty id is the index", str(index.get("scheme", "")), "index") and all_passed
	all_passed = _check("the index is valid", bool(index.get("valid", false)), true) and all_passed

	var verb: Dictionary = EventSheetDocExplain.resolve("ace:%s/%s" % [QUEST_PROVIDER, QUEST_ACE_ID])
	all_passed = _check("an ace id yields its provider", str(verb.get("provider_id", "")), QUEST_PROVIDER) and all_passed
	# The ace id carries its own colon ("method:advance_objective") and could carry a slash, so
	# everything after the FIRST separator is the id - splitting on every slash loses it.
	all_passed = _check("an ace id keeps its whole id", str(verb.get("ace_id", "")), QUEST_ACE_ID) and all_passed
	all_passed = _check("an ace id with no separator is refused",
		bool(EventSheetDocExplain.resolve("ace:QuestPackAddon").get("valid", false)), false) and all_passed
	all_passed = _check("an ace id with no id after the separator is refused",
		bool(EventSheetDocExplain.resolve("ace:QuestPackAddon/").get("valid", false)), false) and all_passed

	all_passed = _check("a registered section resolves",
		bool(EventSheetDocExplain.resolve("section:Debug").get("valid", false)), true) and all_passed
	all_passed = _check("an unregistered section is refused",
		bool(EventSheetDocExplain.resolve("section:Zz Not A Category").get("valid", false)), false) and all_passed

	var addon: Dictionary = EventSheetDocExplain.resolve("addon:quest")
	all_passed = _check("a pack id resolves to its guide path", str(addon.get("target", "")), "docs/Addons/Quest.md") and all_passed
	all_passed = _check("a pack id is valid", bool(addon.get("valid", false)), true) and all_passed
	all_passed = _check("a pack directory that does not exist is refused",
		bool(EventSheetDocExplain.resolve("addon:no_such_pack_here").get("valid", false)), false) and all_passed
	all_passed = _check("an unknown scheme is refused",
		bool(EventSheetDocExplain.resolve("guide:whatever").get("valid", false)), false) and all_passed
	return all_passed


## The addon route is pinned at the URL, never by calling open_docs (that would open a browser
## tab on whoever runs the suite). Every id that names nothing must come back false.
static func _test_open_docs_refuses_unknown() -> bool:
	var all_passed: bool = true
	all_passed = _check("an unknown scheme fails loud", EventSheets.open_docs("guide:whatever"), false) and all_passed
	all_passed = _check("a malformed ace id fails loud", EventSheets.open_docs("ace:OnlyAProvider"), false) and all_passed
	all_passed = _check("an unknown section fails loud", EventSheets.open_docs("section:Zz Not A Category"), false) and all_passed
	all_passed = _check("an unknown pack fails loud", EventSheets.open_docs("addon:no_such_pack_here"), false) and all_passed
	all_passed = _check("the pack route would open the pinned guide URL",
		EventSheets.doc_url(str(EventSheetDocExplain.resolve("addon:quest").get("target", ""))),
		"%s/blob/v%s/docs/Addons/Quest.md" % [EventSheets.DOCS_REPO_URL, SheetCompiler.VERSION]) and all_passed

	# THE CASE A RENAMED PACK ACTUALLY PRODUCES: an id that is perfectly well FORMED and names a
	# verb the registry does not offer. resolve() cannot answer it (a verb's existence needs the
	# running registry), and both hosts used to turn the miss into a `true` - the window by
	# answering the shape-only question, the dock by reporting its index fallback as a hit. It
	# needs a live dock, so the contrast case rides along: a verb the registry really offers
	# still opens. Headless never pops the window, it only answers what it WOULD show.
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(EventSheetResource.new())
	all_passed = _check("a well-formed id naming a verb that does not exist fails loud",
		EventSheets.open_docs("ace:NoSuchProvider/NoSuchVerb"), false) and all_passed
	var offered: Array[ACEDefinition] = dock._ace_registry.get_all_definitions()
	all_passed = _check("the registry offers vocabulary to contrast against", offered.is_empty(), false) and all_passed
	if not offered.is_empty():
		all_passed = _check("a verb the registry DOES offer opens",
			EventSheets.open_docs(EventSheetDocExplain.doc_id_for_definition(offered[0])), true) and all_passed
	dock.free()
	return all_passed


## The whole page for a real pack verb. Every string here is the pack's OWN authored text, so a
## rename in the pack fails this test rather than leaving a stale page in front of a reader.
static func _test_pack_verb_page() -> bool:
	var all_passed: bool = true
	var definition: ACEDefinition = _quest_definition()
	if definition == null:
		return _check("Quest's Advance Objective is in the vocabulary", false, true)

	all_passed = _check("a definition knows its own doc id",
		EventSheetDocExplain.doc_id_for_definition(definition),
		"ace:%s/%s" % [QUEST_PROVIDER, QUEST_ACE_ID]) and all_passed
	all_passed = _check("the verb ships as its authored template",
		EventSheetDocExplain.ships_as(definition),
		"Quests.advance_objective({quest_id}, {objective}, {amount})") and all_passed
	all_passed = _check("the read-more label is derived from the pack",
		EventSheetDocExplain.guide_label(QUEST_PROVIDER), "Open the Quest guide") and all_passed
	all_passed = _check("a builtin verb has no read-more label",
		EventSheetDocExplain.guide_label("Core"), "") and all_passed

	var blocks: Array[Dictionary] = EventSheetDocExplain.blocks_for_definition(definition)
	all_passed = _check("the page titles itself with the verb's name",
		str(_block(blocks, "title").get("text", "")), "Advance Objective") and all_passed
	all_passed = _check("the subtitle names the type and category",
		str(_block(blocks, "title").get("subtitle", "")), "Action  ·  Quest") and all_passed
	all_passed = _check("the prose is the verb's own description",
		str(_block(blocks, "prose").get("text", "")).begins_with("Counts progress on one objective"), true) and all_passed
	all_passed = _check("the ships-as block carries the codegen template",
		str(_block(blocks, "ships_as").get("code", "")),
		"Quests.advance_objective({quest_id}, {objective}, {amount})") and all_passed
	all_passed = _check("the first value is the verb's first parameter",
		str((_block(blocks, "params").get("items", []) as Array)[0].get("name", "")), "Quest Id") and all_passed
	all_passed = _check("the page carries a figure of the verb",
		_block(blocks, "figure").get("definition", null) == definition, true) and all_passed

	# THE FIGURE OF A REAL PACK VERB, not a fixture. Reflection writes default_value = "" for
	# every argument the method does not default, so this verb's figure drew as
	# `Advance Objective ( , , 0 )` - a picture of a broken call, on the pack verbs this whole
	# surface exists to explain. Pinned by VALUE per argument, and swept, so neither check can
	# pass by looking at nothing.
	var figure_sheet: EventSheetResource = EventSheetDocFigure.sheet_for_definition(definition)
	var figure_params: Dictionary = ((figure_sheet.events[0] as EventRow).actions[0] as ACEAction).params
	all_passed = _check("the figure names the quest id slot", str(figure_params.get("quest_id", "")), "\"quest id\"") and all_passed
	all_passed = _check("the figure names the objective slot", str(figure_params.get("objective", "")), "\"objective\"") and all_passed
	all_passed = _check("the figure keeps the argument that DOES have a default", str(figure_params.get("amount", "")), "0") and all_passed
	var blank_slots: PackedStringArray = PackedStringArray()
	for slot: String in figure_params.keys():
		if str(figure_params[slot]).strip_edges().is_empty():
			blank_slots.append(slot)
	all_passed = _check("no argument in a real pack verb's figure draws blank", ", ".join(blank_slots), "") and all_passed
	all_passed = _check("the figure has arguments to check at all", figure_params.size(), 3) and all_passed
	all_passed = _check("the read-more link aims at the pack's guide",
		str(_block(blocks, "link").get("target", "")), "docs/Addons/Quest.md") and all_passed
	all_passed = _check("the read-more link is labelled for the pack",
		str(_block(blocks, "link").get("label", "")), "Open the Quest guide") and all_passed

	# A category page is the blurb verbatim - the one thing neither the picker nor a row tooltip
	# shows today, and the reason this is a surface rather than a bigger tooltip.
	var section_blocks: Array[Dictionary] = EventSheetDocExplain.blocks_for_section("Debug")
	all_passed = _check("a section page is the registered blurb, verbatim",
		str(_block(section_blocks, "prose").get("text", "")),
		EventSheetSectionInfo.description_for("Debug")) and all_passed

	# The panel draws those blocks. Built, never popped: the suite must not open a window.
	var panel: EventSheetDocPanel = EventSheetDocPanel.new()
	all_passed = _check("the panel draws a definition", panel.show_definition(definition), true) and all_passed
	all_passed = _check("the panel titles itself after the verb", panel.current_title(), "Advance Objective") and all_passed
	all_passed = _check("the panel refuses an id that names nothing",
		panel.show_doc("section:Zz Not A Category"), false) and all_passed
	panel.free()
	return all_passed


## Which verb a row explains. The clicked span decides - right-clicking the second condition
## explains THAT condition, not the row's trigger - and a row that names no verb explains nothing,
## which is what keeps the menu entry off a comment.
static func _test_row_to_doc_id() -> bool:
	var all_passed: bool = true
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnReady"
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = "IsVisible"
	row.conditions.append(condition)
	var action: ACEAction = ACEAction.new()
	action.provider_id = QUEST_PROVIDER
	action.ace_id = QUEST_ACE_ID
	row.actions.append(action)

	all_passed = _check("with no click, the row answers with its trigger",
		EventSheetDocExplain.doc_id_for_row(row), "ace:Core/OnReady") and all_passed
	all_passed = _check("a clicked condition explains that condition",
		EventSheetDocExplain.doc_id_for_row(row, {"kind": "condition", "ace_index": 0}), "ace:Core/IsVisible") and all_passed
	all_passed = _check("a clicked action explains that action",
		EventSheetDocExplain.doc_id_for_row(row, {"kind": "action", "ace_index": 0}),
		"ace:%s/%s" % [QUEST_PROVIDER, QUEST_ACE_ID]) and all_passed
	all_passed = _check("an out-of-range span falls back to the row's own verb",
		EventSheetDocExplain.doc_id_for_row(row, {"kind": "action", "ace_index": 9}), "ace:Core/OnReady") and all_passed
	all_passed = _check("an ACE resource explains itself",
		EventSheetDocExplain.doc_id_for_row(condition), "ace:Core/IsVisible") and all_passed
	all_passed = _check("a row with a verb can be explained", EventSheetDocExplain.can_explain(row), true) and all_passed
	all_passed = _check("a comment explains nothing", EventSheetDocExplain.can_explain(CommentRow.new()), false) and all_passed
	all_passed = _check("a trigger-less, empty event explains nothing",
		EventSheetDocExplain.can_explain(EventRow.new()), false) and all_passed
	return all_passed


## The three entry points reach ONE code path. Their wiring is a source contract here: the menu
## item, the key and the row-menu registration all name `open_documentation` / `explain_row`, and
## the row item goes through the PUBLIC registration seam rather than a new menu constant. What
## cannot be pinned headlessly - that Godot actually routes F1 to the dock - is the harness's job.
static func _test_entry_points() -> bool:
	var all_passed: bool = true
	var menu_code: String = _read(MENU_BAR_PATH)
	all_passed = _check("Tools opens the Manual", menu_code.contains("\"Manual…\", 22"), true) and all_passed
	all_passed = _check("the Manual entry calls the one dock method",
		menu_code.contains("22: _dock.open_documentation()"), true) and all_passed
	var input_code: String = _read(INPUT_DISPATCH_PATH)
	all_passed = _check("F1 is handled", input_code.contains("KEY_F1"), true) and all_passed
	# Both F1s funnel into the ONE dock method - plain F1 for "explain what is selected", Ctrl+F1
	# for "take me back to the page I was reading".
	all_passed = _check("F1 calls the same dock method",
		input_code.contains("_dock.open_documentation()"), true) and all_passed
	all_passed = _check("and Ctrl+F1 calls it with the last page",
		input_code.contains("_dock.open_documentation(_dock.last_read_doc_id())"), true) and all_passed
	var dock_code: String = _read(DOCK_PATH)
	all_passed = _check("the row item registers through the public seam",
		dock_code.contains("EventSheets.register_row_menu_item(\"What does this do?\""), true) and all_passed
	all_passed = _check("the row item is filtered by can_explain",
		dock_code.contains("EventSheetDocExplain.can_explain(resource)"), true) and all_passed
	all_passed = _check("the row item lands on explain_row", dock_code.contains("explain_row(resource))"), true) and all_passed
	all_passed = _check("explain_row funnels into the one dock method",
		dock_code.contains("func explain_row(resource: Resource) -> void:\n\topen_documentation("), true) and all_passed
	# The picker's read-more affordance goes through the public doc id, not straight at a URL, so
	# the day "addon:" resolves to something other than a browser tab this caller needs no edit.
	all_passed = _check("the picker's guide button routes through the public doc id",
		dock_code.contains("EventSheets.open_docs(\"addon:%s\" % pack_dir)"), true) and all_passed

	# The seam itself, exercised live with the dock's own filter and label, so a registration of
	# this shape is proved to reach the menu (the dock's own call needs a running editor).
	EventSheets.register_row_menu_item("What does this do?",
		func(resource: Resource) -> bool: return EventSheetDocExplain.can_explain(resource),
		func(_resource: Resource) -> void: pass)
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnReady"
	all_passed = _check("the registered item offers itself on a verb row",
		_has_item(EventSheets.row_menu_items_for(row), "What does this do?"), true) and all_passed
	all_passed = _check("the registered item stays off a comment",
		_has_item(EventSheets.row_menu_items_for(CommentRow.new()), "What does this do?"), false) and all_passed
	EventSheets.unregister_row_menu_item("What does this do?")
	all_passed = _check("the seam unregisters cleanly",
		_has_item(EventSheets.row_menu_items_for(row), "What does this do?"), false) and all_passed
	return all_passed


## Quest's Advance Objective, reflected from the shipped pack the same way the editor builds its
## vocabulary. Annotations are read from DISK, so this must be the loaded script, never source
## text built in memory.
static func _quest_definition() -> ACEDefinition:
	var script: GDScript = load(QUEST_ADDON_PATH) as GDScript
	if script == null:
		return null
	var generator: EventSheetACEGenerator = EventSheetACEGenerator.new()
	for definition: ACEDefinition in generator.generate_from_object(script.new()):
		if definition.id == QUEST_ACE_ID:
			return definition
	return null


static func _block(blocks: Array[Dictionary], kind: String) -> Dictionary:
	for block: Dictionary in blocks:
		if str(block.get("kind", "")) == kind:
			return block
	return {}


static func _has_item(items: Array[Dictionary], label: String) -> bool:
	for item: Dictionary in items:
		if str(item.get("label", "")) == label:
			return true
	return false


static func _read(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("doc_explain_test", label, actual, expected)
