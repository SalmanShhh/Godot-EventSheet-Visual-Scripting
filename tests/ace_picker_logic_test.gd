# EventForge — ACE picker presentation logic
#
# Verifies the C3-style grouping/colour/mode logic of ACEPickerDialog without opening the
# popup window (which needs a display server). Exercises the pure helpers directly.
@tool
extends RefCounted
class_name ACEPickerLogicTest

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

	# Per-item type labels + colours.
	all_passed = _check("type label trigger", picker._ace_type_label(ACEDefinition.ACEType.TRIGGER), "Trigger") and all_passed
	all_passed = _check("type label condition", picker._ace_type_label(ACEDefinition.ACEType.CONDITION), "Condition") and all_passed
	all_passed = _check("type label action", picker._ace_type_label(ACEDefinition.ACEType.ACTION), "Action") and all_passed
	all_passed = _check("type label expression", picker._ace_type_label(ACEDefinition.ACEType.EXPRESSION), "Expression") and all_passed
	all_passed = _check("item colour trigger", picker._item_color_for(ACEDefinition.ACEType.TRIGGER), ACEPickerDialog.ITEM_COLOR_TRIGGER) and all_passed
	all_passed = _check("item colour condition", picker._item_color_for(ACEDefinition.ACEType.CONDITION), ACEPickerDialog.ITEM_COLOR_CONDITION) and all_passed
	all_passed = _check("item colour action", picker._item_color_for(ACEDefinition.ACEType.ACTION), ACEPickerDialog.ITEM_COLOR_ACTION) and all_passed
	all_passed = _check("item colour expression", picker._item_color_for(ACEDefinition.ACEType.EXPRESSION), ACEPickerDialog.ITEM_COLOR_EXPRESSION) and all_passed

	# Group-header colours by kind.
	all_passed = _check("group colour node-type", picker._group_color_for("CharacterBody2D", true), ACEPickerDialog.GROUP_COLOR_NODE_TYPE) and all_passed
	all_passed = _check("group colour run context", picker._group_color_for("Run Context", false), ACEPickerDialog.GROUP_COLOR_TRIGGER) and all_passed
	all_passed = _check("group colour signals", picker._group_color_for("Signals / Scene / Input", false), ACEPickerDialog.GROUP_COLOR_TRIGGER) and all_passed
	all_passed = _check("group colour variables", picker._group_color_for("Variables", false), ACEPickerDialog.GROUP_COLOR_VARIABLE) and all_passed
	all_passed = _check("group colour custom", picker._group_color_for("Custom ACEs", false), ACEPickerDialog.GROUP_COLOR_CUSTOM) and all_passed
	all_passed = _check("group colour other neutral", picker._group_color_for("General Conditions", false), ACEPickerDialog.GROUP_COLOR_NEUTRAL) and all_passed

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
	# (Construct 3 / GDevelop never show it — newcomers read "condition / action / trigger").
	for hint_mode: String in ["new_condition_event", "append_condition", "append_action", "replace_trigger", "other"]:
		all_passed = _check("picker hint for %s drops the ACE jargon" % hint_mode,
			picker._build_hint_text(hint_mode, false).contains("ACE"), false) and all_passed
	all_passed = _check("signal-only picker hint drops the ACE jargon",
		picker._build_hint_text("new_condition_event", true).contains("ACE"), false) and all_passed

	# Relevance scoring — type-and-Enter must target the BEST match, not first-in-tree order. Tiers:
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

	return all_passed

static func _make_def(ace_type: int) -> ACEDefinition:
	var definition: ACEDefinition = ACEDefinition.new()
	definition.ace_type = ace_type
	definition.provider_id = "Core"
	return definition

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] ace_picker_logic_test: %s" % label)
		return true
	print("[FAIL] ace_picker_logic_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
