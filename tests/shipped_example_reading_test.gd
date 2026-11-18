# EventSheets - the two shipped example sheets that teach controls and saving open clean and read as
# the packs they use.
#
# Pinned:
#   1. A control a sheet makes itself (a direct Input Map add, a Project Settings write, or a call of
#      a function of the same code that does one of those) is not an unknown control: no finding on the
#      row, no Doctor warning on the script.
#   2. A question that is one call on a pack's node reads as that pack's row, and an optional empty text
#      argument at the end of a call is not drawn as a run of empty quotes.
#   3. The options example keeps the Settings and SaveSystem nodes out of the saved object, its play
#      area is held in the middle of the window, and its options panel is opaque.
#   4. The Controls page the Game Settings pack builds gives every row the same column widths.
#   5. A path in the Save Studio's running text stays whole on one line.
#   6. The object column makes room for a trigger's name AND the arrow in front of it, so a long name such as
#      SaveSystem is shown whole.
@tool
class_name ShippedExampleReadingTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const LINES := preload("res://tools/reading_lines.gd")
const REBIND := "res://demo/showcase/input_rebind/input_rebind.gd"
const OPTIONS := "res://demo/showcase/options_and_quick_save/options_and_quick_save.gd"
const SETTINGS_PACK := "res://eventsheet_addons/game_settings/game_settings_addon.gd"


static func run() -> bool:
	var ok: bool = true
	ok = _test_declared_controls() and ok
	ok = _test_examples_open_clean() and ok
	ok = _test_pack_questions_read_as_the_pack() and ok
	ok = _test_rows_the_way_the_examples_are_drawn() and ok
	ok = _test_options_scene() and ok
	ok = _test_controls_page_columns() and ok
	ok = _test_paths_stay_whole() and ok
	ok = _test_trigger_names_keep_their_room() and ok
	return ok


## Asked by path and by name, so a tree without the function answers with a failing line instead of a crash.
static func _declared(code: String) -> PackedStringArray:
	var ask: Callable = Callable(load("res://addons/eventsheet/editor/interaction/input_map_facts.gd"), "declared_names_in")
	return ask.call(code) if ask.is_valid() else PackedStringArray(["(no such function)"])


static func _kept(text: String) -> String:
	var ask: Callable = Callable(load("res://addons/eventsheet/editor/dock/save_studio.gd"), "keep_paths_whole")
	return str(ask.call(text)) if ask.is_valid() else "(no such function)"


static func _sheet_of(path: String) -> EventSheetResource:
	return EventSheetGDScriptImporter.new().import_external_source(FileAccess.get_file_as_string(path), true, path)


static func _test_declared_controls() -> bool:
	var helper_code: String = "func define_control(action_name: String, key_code: int) -> void:\n\tProjectSettings.set_setting(\"input/\" + action_name, {})\n\nfunc _ready() -> void:\n\tdefine_control(\"jump\", KEY_SPACE)\n\tdefine_control(\"dash\", KEY_C)"
	var by_param: String = "func add(name: String) -> void:\n\tInputMap.add_action(name)\n\nfunc _ready() -> void:\n\tadd(\"fire\")"
	return SUPPORT.pins("shipped example reading", [
		["a call of a function that writes input/<name> declares its literal", _declared(helper_code), PackedStringArray(["jump", "dash"])],
		["a call of a function that adds the control it is handed declares its literal", _declared(by_param), PackedStringArray(["fire"])],
		["a direct add declares its name", _declared("InputMap.add_action(\"slide\")"), PackedStringArray(["slide"])],
		["a Project Settings write declares its name", _declared("ProjectSettings.set_setting(\"input/crouch\", {})"), PackedStringArray(["crouch"])],
		["a function that does not make controls declares nothing", _declared("func note(text: String) -> void:\n\tprint(text)\n\nfunc _ready() -> void:\n\tnote(\"jump\")"), PackedStringArray()],
	])


static func _test_examples_open_clean() -> bool:
	var ok: bool = true
	for path: String in [REBIND, OPTIONS]:
		var sheet: EventSheetResource = _sheet_of(path)
		var missing: PackedStringArray = PackedStringArray()
		for finding: Dictionary in EventSheetMistakeFindings.findings(sheet, path):
			if str(finding.get("kind", "")) == "input-action-not-in-map":
				missing.append(str(finding.get("subject", "")))
		ok = SUPPORT.check("shipped example reading", "%s has no control the Input Map lacks" % path.get_file(), missing, PackedStringArray()) and ok
	var findings: Array[Dictionary] = []
	EventSheetProjectDoctor.check_unknown_input_actions(PackedStringArray(), findings)
	var named: PackedStringArray = PackedStringArray()
	for finding: Dictionary in findings:
		if str(finding.get("path", finding.get("file", ""))).begins_with("res://demo/showcase/"):
			named.append(str(finding.get("path", finding.get("file", ""))))
	ok = SUPPORT.check("shipped example reading", "the Doctor has no unknown-control warning for a showcase", named, PackedStringArray()) and ok
	return ok


static func _plain_of(sheet: EventSheetResource) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for reading: Variant in LINES.readings_of_sheet(sheet, "shipped_example"):
		out.append("%s|%s|%s" % [reading.lane, reading.object_label, "".join(reading.plain)])
	return out


static func _test_pack_questions_read_as_the_pack() -> bool:
	var ok: bool = true
	var options: PackedStringArray = _plain_of(_sheet_of(OPTIONS))
	var question: String = ""
	var declare: String = ""
	for line: String in options:
		if line.to_lower().contains("changed setting is") and question.is_empty():
			question = line
		if line.contains("Declare setting") and declare.is_empty():
			declare = line
	ok = SUPPORT.check("shipped example reading", "the Settings question reads as the pack's own words, not as code", question.contains("$Services/Settings"), false) and ok
	ok = SUPPORT.check("shipped example reading", "the Settings question is found", question.is_empty(), false) and ok
	ok = SUPPORT.check("shipped example reading", "a declared setting does not end in empty quotes", declare.contains("\"\""), false) and ok
	var panel_question: String = ""
	for line: String in options:
		if line.to_lower().contains("is panel visible") and panel_question.is_empty():
			panel_question = line
	ok = SUPPORT.check("shipped example reading", "the HudKit question reads as the pack's own words, not as code", panel_question.contains("is_panel_visible("), false) and ok
	ok = SUPPORT.check("shipped example reading", "the HudKit question is found", panel_question.is_empty(), false) and ok
	return ok


## What each example's events read as: a button is its own trigger, the packs' verbs are the packs' own rows (the
## object column names the pack, the words are the verb's, no "call" of a method), the coin pickup is rows, and
## the readings of the packs' rows never show the node path they were written on.
static func _test_rows_the_way_the_examples_are_drawn() -> bool:
	var rebind: PackedStringArray = _plain_of(_sheet_of(REBIND))
	var options: PackedStringArray = _plain_of(_sheet_of(OPTIONS))
	var rebind_triggers: PackedStringArray = _lines_with(rebind, "condition|", "On Pressed")
	var pack_rows: PackedStringArray = PackedStringArray()
	for line: String in options:
		if line.begins_with("action|GameSettingsAddon|") or line.begins_with("action|SaveSystemAddon|") or line.begins_with("action|HudKitBehavior|"):
			pack_rows.append(line.get_slice("|", 1))
	return SUPPORT.pins("shipped example reading", [
		["each button of the rebind example is its own trigger", rebind_triggers, PackedStringArray([
			"condition|SwapButton|On Pressed", "condition|TakeButton|On Pressed", "condition|PickAnotherButton|On Pressed",
			"condition|ResetAllButton|On Pressed", "condition|VibrateButton|On Pressed"])],
		["no row asks the Hud which button was pressed", _lines_with(rebind, "", "Button Is").size(), 0],
		["the options example's back button is its own trigger", _lines_with(options, "condition|", "BackButton|On Pressed").size(), 1],
		["the packs' verbs read as the packs' own rows", pack_rows.has("GameSettingsAddon") and pack_rows.has("SaveSystemAddon") and pack_rows.has("HudKitBehavior"), true],
		["no row of a pack shows the call it is written as", _lines_with(options, "action|GameSettingsAddon|", "$Services/Settings.").size() 			+ _lines_with(rebind, "action|GameSettingsAddon|", "$Settings.").size(), 0],
		["the coin pickup is rows: the overlap, the count and the hide", [
			_lines_with(options, "condition|Player|", "Overlaps").size(), _lines_with(options, "action|", "Add 1 to coins").size(),
			_lines_with(options, "action|", "Set invisible").size()], [1, 1, 1]],
		["the options example saves its bindings after each rebind", _lines_with(options, "condition|Settings|", "On Binding Changed").size(), 1],
		["the saved variables carry their descriptions in the file", FileAccess.get_file_as_string(OPTIONS).contains("## Coins picked up in this run.\nvar coins: int = 0\n## Where the player stands, kept for a quick save.\nvar player_spot"), true],
	])


static func _lines_with(lines: PackedStringArray, lead: String, text: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for line: String in lines:
		if line.begins_with(lead) and line.contains(text):
			found.append(line)
	return found


static func _test_options_scene() -> bool:
	var ok: bool = true
	var scene: PackedScene = load("res://demo/showcase/options_and_quick_save/options_and_quick_save.tscn")
	var state: SceneState = scene.get_state()
	var paths: PackedStringArray = PackedStringArray()
	for index: int in range(state.get_node_count()):
		paths.append(str(state.get_node_path(index)).trim_prefix("./"))
	ok = SUPPORT.check("shipped example reading", "Settings is not a child of the saved object", paths.has("Settings"), false) and ok
	ok = SUPPORT.check("shipped example reading", "Settings sits under the Services node", paths.has("Services/Settings"), true) and ok
	ok = SUPPORT.check("shipped example reading", "SaveSystem sits under the Services node", paths.has("Services/SaveSystem"), true) and ok
	var root: Control = scene.instantiate() as Control
	ok = SUPPORT.pins("shipped example reading", [
		["the scene fills its window (right anchor)", root.anchor_right, 1.0],
		["the scene fills its window (bottom anchor)", root.anchor_bottom, 1.0],
		["the play area is held in the middle (horizontal)", (root.get_node("GameScreen") as Control).anchor_left, 0.5],
		["the play area is held in the middle (vertical)", (root.get_node("GameScreen") as Control).anchor_top, 0.5],
		["the options panel is opaque", ((root.get_node("OptionsPanel") as Control).get_theme_stylebox("panel") as StyleBoxFlat).bg_color.a, 1.0],
	]) and ok
	root.free()
	var rebind_root: Control = (load("res://demo/showcase/input_rebind/input_rebind.tscn") as PackedScene).instantiate() as Control
	ok = SUPPORT.check("shipped example reading", "the rebind scene fills its window", [rebind_root.anchor_right, rebind_root.anchor_bottom], [1.0, 1.0]) and ok
	rebind_root.free()
	return ok


static func _test_controls_page_columns() -> bool:
	var pack: Node = (load(SETTINGS_PACK) as GDScript).new() as Node
	var names: PackedStringArray = PackedStringArray(["zz_short", "zz_a_much_longer_control_name"])
	for action_name: String in names:
		InputMap.add_action(action_name)
	var short_key: InputEventKey = InputEventKey.new()
	short_key.keycode = KEY_A
	InputMap.action_add_event("zz_short", short_key)
	var long_key: InputEventKey = InputEventKey.new()
	long_key.keycode = KEY_PAGEDOWN
	InputMap.action_add_event("zz_a_much_longer_control_name", long_key)
	var page: VBoxContainer = VBoxContainer.new()
	pack.call("build_controls_page", page)
	var widths: Array = []
	var clipped: bool = true
	for action_name: String in names:
		var row: Node = page.find_child("%s_row" % action_name, true, false)
		var label: Label = row.get_child(0) as Label
		var keyboard: Button = page.find_child("%s_keyboard" % action_name, true, false) as Button
		var pad: Button = page.find_child("%s_pad" % action_name, true, false) as Button
		widths.append([label.custom_minimum_size.x, keyboard.custom_minimum_size.x, pad.custom_minimum_size.x])
		clipped = clipped and label.clip_text and keyboard.clip_text and pad.clip_text
	var shared: bool = widths[0] == widths[1] and float(widths[0][0]) > 0.0 and float(widths[0][1]) > 0.0 and float(widths[0][2]) > 0.0
	for action_name: String in names:
		InputMap.erase_action(action_name)
	page.free()
	pack.free()
	return SUPPORT.pins("shipped example reading", [
		["every row holds its label, keyboard and pad columns at one set width", shared, true],
		["no text sets a column's width", clipped, true],
	])


static func _test_paths_stay_whole() -> bool:
	var plain: String = "Settings > Save Bindings keeps them in user://settings.cfg under [bindings], beside res://my-file.cfg."
	var kept: String = _kept(plain)
	var joiner: String = String.chr(0x2060)
	return SUPPORT.pins("shipped example reading", [
		["joiners are the only change", kept.replace(joiner, ""), plain],
		["a slash of a path is held to the next letter", kept.contains("user:/%s/%ssettings.cfg" % [joiner, joiner]), true],
		["words outside a path are left alone", kept.begins_with("Settings > Save Bindings keeps them in "), true],
	])


static func _test_trigger_names_keep_their_room() -> bool:
	var sheet: EventSheetResource = _sheet_of(OPTIONS)
	var viewport: EventSheetViewport = LINES.viewport_for(sheet)
	var floors_script: GDScript = load("res://addons/eventsheet/editor/interaction/object_label_floor.gd") as GDScript
	var font: Font = viewport._get_font()
	var size: int = viewport._get_font_size()
	var name_width: float = font.get_string_size("SaveSystem", HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
	var style: EventSheetEventStyle = viewport._get_event_style()
	style.sub_event_strips = true
	var with_arrow: float = float((floors_script.call("measure", viewport) as Dictionary).get("condition", 0.0))
	style.sub_event_strips = false
	var without_arrow: float = float((floors_script.call("measure", viewport) as Dictionary).get("condition", 0.0))
	viewport.free()
	return SUPPORT.pins("shipped example reading", [
		["a trigger's name is measured with the arrow that leads it", with_arrow >= name_width + EventSheetViewportRowMetrics.STRIP_MARK_ADVANCE, true],
		["a look that draws no such arrow never measures wider than one that does", without_arrow <= with_arrow, true],
	])
