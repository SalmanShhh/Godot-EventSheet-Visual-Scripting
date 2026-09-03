# EventForge - ACE picker presentation logic
#
# Verifies the event-sheet-style grouping/colour/mode logic of ACEPickerDialog without opening the
# popup window (which needs a display server). Exercises the pure helpers directly.
@tool
class_name ACEPickerLogicTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")


## A dock stand-in that counts how often the picker asks it for the open sheet. The sheet is real
## but empty: what is being pinned is the number of asks, not what the walk finds.
class CountingSheetHost:
	extends Node

	var asks: int = 0
	var sheet: EventSheetResource = EventSheetResource.new()

	func get_current_sheet() -> EventSheetResource:
		asks += 1
		return sheet


static func run() -> bool:
	var all_passed: bool = true
	var picker: ACEPickerDialog = ACEPickerDialog.new()

	# Mode-specific titles.
	all_passed = _check("title: new event", picker._title_for_mode("new_condition_event", false), "Add Event") and all_passed
	all_passed = _check("title: sub-event", picker._title_for_mode("new_sub_condition_event", false), "Add Sub-Event") and all_passed
	all_passed = _check("title: add condition", picker._title_for_mode("append_condition", false), "Add Condition") and all_passed
	all_passed = _check("title: add action", picker._title_for_mode("append_action", false), "Add Action") and all_passed
	all_passed = _check("title: replace condition", picker._title_for_mode("replace_condition", false), "Replace Condition") and all_passed
	all_passed = _check("title: replace action", picker._title_for_mode("replace_action", false), "Replace Action") and all_passed
	all_passed = _check("title: replace trigger", picker._title_for_mode("replace_trigger", false), "Replace Trigger") and all_passed

	# The variable catalog is derived ONCE per open even when it comes back EMPTY. A sheet with no
	# variables in scope used to read "empty" as "not derived yet" and ask the provider again for
	# every row the tree built - 1,878 reads of the autoloads' scripts off disk per open, which is
	# what froze the Add picker for seconds on a fresh sheet.
	var provider_calls: Array[int] = [0]
	picker.set_variable_catalog_provider(func() -> Array:
		provider_calls[0] += 1
		return [])
	picker._variables_in_scope()
	picker._variables_in_scope()
	picker._variables_in_scope()
	all_passed = _check("an empty variable catalog is derived once, not once per row", provider_calls[0], 1) and all_passed
	picker._variable_catalog.clear()
	picker._variable_catalog_derived = false
	picker._variables_in_scope()
	all_passed = _check("the next open derives it again", provider_calls[0], 2) and all_passed

	# And the same shape for the "Used 3x in this sheet" line every tooltip carries: the count comes
	# from ONE walk of the open sheet per open. It used to be a whole-sheet walk per row of the
	# tree - free on the empty sheet the picker is usually measured on, and a project-sized job on
	# any sheet with events in it, paid again on every keystroke.
	var counting_host: CountingSheetHost = CountingSheetHost.new()
	picker._host_node = counting_host
	for repeat in 200:
		picker._usage_in_sheet()
	all_passed = _check("two hundred tooltips walk the sheet once", counting_host.asks, 1) and all_passed
	picker._usage_counts.clear()
	picker._usage_counts_derived = false
	picker._usage_in_sheet()
	all_passed = _check("and the next open walks it again", counting_host.asks, 2) and all_passed
	counting_host.free()
	picker._host_node = null

	all_passed = _test_the_deferred_fill() and all_passed
	all_passed = _test_the_warm() and all_passed

	# Per-item type labels (the type tint was removed - Favorites/Recent now render plain like the
	# main tree and the native Create-New-Node dialog; the per-row icon carries the type).
	all_passed = _check("type label trigger", picker._ace_type_label(ACEDefinition.ACEType.TRIGGER), "Trigger") and all_passed
	all_passed = _check("type label condition", picker._ace_type_label(ACEDefinition.ACEType.CONDITION), "Condition") and all_passed
	all_passed = _check("type label action", picker._ace_type_label(ACEDefinition.ACEType.ACTION), "Action") and all_passed
	all_passed = _check("type label expression", picker._ace_type_label(ACEDefinition.ACEType.EXPRESSION), "Expression") and all_passed

	# Category headers are now a single muted "quiet divider" colour for every kind - the node-type
	# distinction is carried by the section's class icon, not a bright per-kind amber/teal/blue/purple.
	var muted: Color = picker._muted_header_color()
	all_passed = _check("category header muted: node-type", picker._group_color_for("CharacterBody2D", true), muted) and all_passed
	all_passed = _check("category header muted: run context", picker._group_color_for("Run Context", false), muted) and all_passed
	all_passed = _check("category header muted: signals", picker._group_color_for("Signals / Scene / Input", false), muted) and all_passed
	all_passed = _check("category header muted: variables", picker._group_color_for("Variables", false), muted) and all_passed
	all_passed = _check("category header muted: custom", picker._group_color_for("Custom ACEs", false), muted) and all_passed
	all_passed = _check("category header muted: other", picker._group_color_for("General Conditions", false), muted) and all_passed

	# Featured verbs (event-sheet-style highlight) are recognized for bolding + floating to the top of their group.
	var feat_def: ACEDefinition = ACEDefinition.new()
	feat_def.provider_id = "Core"; feat_def.id = "SetVar"
	all_passed = _check("featured: Core/SetVar is featured", picker._is_featured(feat_def), true) and all_passed
	var plain_def: ACEDefinition = ACEDefinition.new()
	plain_def.provider_id = "Core"; plain_def.id = "ZzNotAFeaturedAce"
	all_passed = _check("featured: an unlisted ace is not featured", picker._is_featured(plain_def), false) and all_passed

	# Kind dots: every ACE type resolves to a role-colour dot texture (the fallback row icon),
	# distinct per type, and cached (same instance on repeat calls). Works headless - the dot is
	# Image-built, unlike the old editor-theme member glyphs.
	var trigger_dot: Texture2D = ACEPickerDialog.kind_dot(ACEDefinition.ACEType.TRIGGER)
	var condition_dot: Texture2D = ACEPickerDialog.kind_dot(ACEDefinition.ACEType.CONDITION)
	all_passed = _check("kind dot exists for triggers", trigger_dot != null, true) and all_passed
	all_passed = _check("kind dots differ per type", trigger_dot == condition_dot, false) and all_passed
	all_passed = _check("kind dots are cached", ACEPickerDialog.kind_dot(ACEDefinition.ACEType.TRIGGER) == trigger_dot, true) and all_passed
	var undotted: ACEDefinition = _make_def(ACEDefinition.ACEType.ACTION)
	all_passed = _check("icon fallback is the kind dot", ACEPickerDialog.resolve_definition_icon(undotted) == ACEPickerDialog.kind_dot(ACEDefinition.ACEType.ACTION), true) and all_passed

	# Sub-category nesting: a "Parent: Sub" category splits into a parent + child folder so
	# related ACEs (Array/Dictionary/… helpers) cluster under one section instead of a flat list.
	all_passed = _check("subcategory splits Variables: Array",
		Array(ACEPickerDialog.split_subcategory("Variables: Array")), ["Variables", "Array"]) and all_passed
	all_passed = _check("subcategory splits Variables: Dictionary",
		Array(ACEPickerDialog.split_subcategory("Variables: Dictionary")), ["Variables", "Dictionary"]) and all_passed
	all_passed = _check("flat category does not split", ACEPickerDialog.split_subcategory("General Actions").is_empty(), true) and all_passed
	all_passed = _check("node-type-style name does not split", ACEPickerDialog.split_subcategory("CharacterBody2D").is_empty(), true) and all_passed
	all_passed = _check("trailing separator does not split", ACEPickerDialog.split_subcategory("Variables: ").is_empty(), true) and all_passed

	# Mode filtering.
	var trigger_def: ACEDefinition = _make_def(ACEDefinition.ACEType.TRIGGER)
	var condition_def: ACEDefinition = _make_def(ACEDefinition.ACEType.CONDITION)
	var action_def: ACEDefinition = _make_def(ACEDefinition.ACEType.ACTION)
	all_passed = _check("append_condition allows condition", picker._is_allowed_for_mode(condition_def, "append_condition", false), true) and all_passed
	all_passed = _check("append_condition allows trigger", picker._is_allowed_for_mode(trigger_def, "append_condition", false), true) and all_passed
	all_passed = _check("append_condition rejects action", picker._is_allowed_for_mode(action_def, "append_condition", false), false) and all_passed
	all_passed = _check("append_action allows action", picker._is_allowed_for_mode(action_def, "append_action", false), true) and all_passed
	all_passed = _check("append_action rejects condition", picker._is_allowed_for_mode(condition_def, "append_action", false), false) and all_passed
	all_passed = _check("replace_trigger allows only trigger", picker._is_allowed_for_mode(trigger_def, "replace_trigger", false) and not picker._is_allowed_for_mode(action_def, "replace_trigger", false), true) and all_passed

	# Simple Mode hides the advanced / code-drop ACEs (Run GDScript, Evaluate, Breakpoint, …) while
	# keeping everyday ACEs. The picker reads a provider the dock wires to its simple-mode flag.
	var run_gd: ACEDefinition = _make_def(ACEDefinition.ACEType.ACTION)
	run_gd.id = "RunGDScript"
	var everyday: ACEDefinition = _make_def(ACEDefinition.ACEType.ACTION)
	everyday.id = "SetVar"
	all_passed = _check("simple mode off: Run GDScript is allowed", picker._is_allowed_for_mode(run_gd, "append_action", false), true) and all_passed
	picker.set_simple_mode_provider(func() -> bool: return true)
	all_passed = _check("simple mode on: Run GDScript is hidden", picker._is_allowed_for_mode(run_gd, "append_action", false), false) and all_passed
	all_passed = _check("simple mode on: an everyday action is still shown", picker._is_allowed_for_mode(everyday, "append_action", false), true) and all_passed
	picker.set_simple_mode_provider(Callable())

	# Grouping key prefers node_type over category.
	var node_typed: ACEDefinition = _make_def(ACEDefinition.ACEType.CONDITION)
	node_typed.category = "General Conditions"
	node_typed.metadata = {"node_type": "CharacterBody2D"}
	all_passed = _check("node_type wins over category", str(node_typed.metadata.get("node_type", "")), "CharacterBody2D") and all_passed

	# Item label + tooltip.
	var labelled: ACEDefinition = _make_def(ACEDefinition.ACEType.CONDITION)
	labelled.display_name = "Is on floor"
	labelled.description = "Whether the body is on the floor."
	all_passed = _check("item label hides Core provider", picker._item_label(labelled), "Is on floor") and all_passed
	all_passed = _check("item tooltip carries type prefix", picker._item_tooltip(labelled), "[Condition]  Whether the body is on the floor.") and all_passed
	var custom: ACEDefinition = _make_def(ACEDefinition.ACEType.ACTION)
	custom.provider_id = "Player"
	custom.display_name = "Dash"
	all_passed = _check("item label shows custom provider", picker._item_label(custom), "Dash  ·  Player") and all_passed

	# Create-Node-parity side panes: single-column, root-hidden Favorites/Recent trees.
	var side_tree: Tree = picker._make_side_tree()
	all_passed = _check("side pane tree is single column", side_tree.columns, 1) and all_passed
	all_passed = _check("side pane tree hides its root", side_tree.hide_root, true) and all_passed
	side_tree.free()
	# Favorite detection reads the persisted per-project favorites list.
	var fav_def: ACEDefinition = _make_def(ACEDefinition.ACEType.ACTION)
	fav_def.id = "FavProbe"
	ProjectSettings.set_setting("eventsheets/picker/favorites", PackedStringArray(["Core/FavProbe"]))
	all_passed = _check("favorited ace is detected", picker._is_favorite(fav_def), true) and all_passed
	var other_def: ACEDefinition = _make_def(ACEDefinition.ACEType.ACTION)
	other_def.id = "NotFav"
	all_passed = _check("non-favorited ace is not detected", picker._is_favorite(other_def), false) and all_passed
	ProjectSettings.set_setting("eventsheets/picker/favorites", null)

	# De-jargoned hints: the user-facing picker hint must not surface the insider acronym "ACE"
	# (event sheets / GDevelop never show it - newcomers read "condition / action / trigger").
	for hint_mode: String in ["new_condition_event", "append_condition", "append_action", "replace_trigger", "other"]:
		all_passed = _check("picker hint for %s drops the ACE jargon" % hint_mode,
			picker._build_hint_text(hint_mode, false).contains("ACE"), false) and all_passed
	all_passed = _check("signal-only picker hint drops the ACE jargon",
		picker._build_hint_text("new_condition_event", true).contains("ACE"), false) and all_passed

	# Relevance scoring - type-and-Enter must target the BEST match, not first-in-tree order. Tiers:
	# exact name > name prefix > word-start in name > substring in name > substring elsewhere.
	var s_exact: ACEDefinition = _make_def(ACEDefinition.ACEType.ACTION); s_exact.display_name = "Hide"
	var s_prefix: ACEDefinition = _make_def(ACEDefinition.ACEType.ACTION); s_prefix.display_name = "Hide Player"
	var s_word: ACEDefinition = _make_def(ACEDefinition.ACEType.ACTION); s_word.display_name = "Quick Hide"
	var s_sub: ACEDefinition = _make_def(ACEDefinition.ACEType.ACTION); s_sub.display_name = "Unhide All"
	all_passed = _check("score: exact name beats prefix",
		ACEPickerDialog._score_match("hide", s_exact) > ACEPickerDialog._score_match("hide", s_prefix), true) and all_passed
	all_passed = _check("score: prefix beats word-start",
		ACEPickerDialog._score_match("hide", s_prefix) > ACEPickerDialog._score_match("hide", s_word), true) and all_passed
	all_passed = _check("score: word-start beats mid-word substring",
		ACEPickerDialog._score_match("hide", s_word) > ACEPickerDialog._score_match("hide", s_sub), true) and all_passed
	all_passed = _check("score: any textual match outscores none, empty query scores 0",
		ACEPickerDialog._score_match("hide", s_sub) > 0 and ACEPickerDialog._score_match("", s_exact) == 0, true) and all_passed

	# Reactivity steering: a polling condition with a signal twin pre-selects the reactive TRIGGER on a
	# concept query, but keeps the condition when the user typed its exact name; an ACE with no twin is
	# never swapped. (The surfacing + tree pre-selection are exercised by the editor import.)
	var overlap_cond: ACEDefinition = _make_def(ACEDefinition.ACEType.CONDITION)
	overlap_cond.id = "OverlapsBody"
	overlap_cond.display_name = "Overlaps Body"
	all_passed = _check("reactive twin id resolves for a polling condition",
		ACEPickerDialog._reactive_twin_id(overlap_cond), "OnBodyEntered") and all_passed
	all_passed = _check("a concept query prefers the reactive twin",
		ACEPickerDialog._prefer_reactive_twin("overlap", overlap_cond), true) and all_passed
	all_passed = _check("the exact condition name keeps the condition",
		ACEPickerDialog._prefer_reactive_twin("Overlaps Body", overlap_cond), false) and all_passed
	var no_twin: ACEDefinition = _make_def(ACEDefinition.ACEType.ACTION)
	no_twin.id = "Print"
	no_twin.display_name = "Print"
	all_passed = _check("an ACE with no twin is never swapped",
		ACEPickerDialog._prefer_reactive_twin("print", no_twin), false) and all_passed
	all_passed = _check("no twin id for a non-mapped ACE",
		ACEPickerDialog._reactive_twin_id(no_twin).is_empty(), true) and all_passed

	# A SCENE SHELF entry answers a search word by word, the way the registry's own search does.
	# "boss dissolve" is object then verb - the shape the scene shelves exist for - and no one
	# entry's text holds that whole string, so testing the query as one substring dropped every
	# shelf the moment a second word was typed and left the reader the general vocabulary.
	var shelved: ACEDefinition = ACEDefinition.new()
	shelved.provider_id = "Core"
	shelved.id = "EffectSetDial"
	shelved.display_name = "effect.dissolve  ·  Set Effect Dial"
	shelved.metadata = {ACEPickerDialog.SCENE_TARGET_META: "$Boss"}
	for query: String in ["dissolve", "boss", "boss dissolve", "dissolve boss", "  boss   set  ", ""]:
		all_passed = _check("a shelf entry answers \"%s\"" % query,
			ACEPickerDialog.shelf_matches_query(shelved, query), true) and all_passed
	all_passed = _check("and answers no when one of the words is not its own",
		ACEPickerDialog.shelf_matches_query(shelved, "boss glow"), false) and all_passed
	all_passed = _check("nothing at all answers nothing",
		ACEPickerDialog.shelf_matches_query(null, "boss"), false) and all_passed

	return all_passed


static func _make_def(ace_type: int) -> ACEDefinition:
	var definition: ACEDefinition = ACEDefinition.new()
	definition.ace_type = ace_type
	definition.provider_id = "Core"
	return definition


## THE WINDOW COMES UP BEFORE THE LIST DOES. open() shows the shell and posts the fill for the next
## idle frame, so a cold session paints a dialog within a frame instead of after the whole
## vocabulary has been built into tree items. There are no frames in a headless run, which is what
## makes this pinnable: the fill is still pending when open() returns, and calling it by hand is
## the frame arriving.
static func _test_the_deferred_fill() -> bool:
	var all_passed: bool = true
	var host: Node = Node.new()
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	registry.refresh_from_sources([], true)
	var picker: ACEPickerDialog = ACEPickerDialog.new()
	picker.init_dialog(host, registry)
	picker.open("append_action", false, null, {})
	# Whether the window PAINTED is a display-server question and there is no display here. What is
	# pinnable headless is what open() left behind: a shell with its search field ready, one line
	# saying what is happening, and no tree yet.
	all_passed = _check("with the search field ready for the first keystroke",
		picker._search.text, "") and all_passed
	all_passed = _check("and one line saying what is happening",
		picker._hint.text, "Loading the vocabulary...") and all_passed
	all_passed = _check("the tree is not built yet - that is the point",
		picker._tree.get_root() == null, true) and all_passed
	var token: int = picker._fill_token
	picker._fill_after_popup(token)
	all_passed = _check("the frame arrives and the tree is built",
		picker._tree.get_root() != null and picker._tree.get_root().get_child_count() > 0, true) and all_passed
	all_passed = _check("and the hint is the mode's own words again",
		picker._hint.text, picker._build_hint_text("append_action", false)) and all_passed

	# A fill posted for a dialog that has since been closed, or reopened, must do nothing at all.
	picker.open("append_action", false, null, {})
	var stale_token: int = picker._fill_token
	picker.close()
	picker._fill_after_popup(stale_token)
	all_passed = _check("a fill for a closed dialog does not fill it",
		picker._tree.get_root() == null, true) and all_passed
	picker.open("append_action", false, null, {})
	picker.open("append_action", false, null, {})
	picker._fill_after_popup(stale_token)
	all_passed = _check("and neither does one from the open before this one",
		picker._tree.get_root() == null, true) and all_passed
	picker._fill_after_popup(picker._fill_token)
	all_passed = _check("while this open\'s own fill still works",
		picker._tree.get_root() != null, true) and all_passed
	picker.close()
	host.free()
	return all_passed


## THE IDLE WARM. It asks the questions the first click would otherwise pay for, and it asks NONE
## of them outside the editor - a suite whose answers depend on whether an idle frame arrived is a
## suite that passes differently on a slower machine.
static func _test_the_warm() -> bool:
	var all_passed: bool = true
	EventSheetPickerWarmup.reset_for_tests()
	EventSheetPickerWarmup.request()
	all_passed = _check("a headless run schedules no warm at all",
		EventSheetPickerWarmup.is_warm(), false) and all_passed
	EventSheetPickerWarmup.reset_for_tests()
	EventSheetPickerWarmup.warm_now()
	all_passed = _check("asked by hand, it finishes", EventSheetPickerWarmup.is_warm(), true) and all_passed
	all_passed = _check("and it covers every installed pack",
		EventSheetPickerWarmup._steps.size(),
		EventSheetEditorToolCensus.pack_directories().size() + 2 + EventSheetPickerWarmup.ICON_SLICES) and all_passed
	EventSheetPickerWarmup.reset_for_tests()
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("ace_picker_logic_test", label, actual, expected)
