# A variable's Save choice (Never / Auto / Load only / Save only / Manual) compiles to one plain block
# at the end of the file - load at ready, store on leaving the tree, and the save_state()/load_state()
# pair Save Game and Load Game call - and an opened file carrying that block reads back into the same
# choices, byte for byte. A hand-written save_state()/load_state() is never claimed.
class_name SaveChoicesTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const PREFIX := "save_choices_test"
const SaveChoices := preload("res://addons/eventforge/compiler/save_choices.gd")

## What the six choices below compile to, whole: the shape is the contract, so it is pinned as text.
const EXPECTED_BLOCK: String = """
## Saved by each variable's Save choice (Save Studio > What gets saved) - change the choice, not these lines.
@onready var __ef_save_boot: bool = _ef_load_saved()

func _ef_load_saved() -> bool:
	add_to_group("persist")
	var __remember_cfg: ConfigFile = ConfigFile.new()
	if __remember_cfg.load("user://remembered.cfg") == OK:
		health = __remember_cfg.get_value("Player", "health", health)
		coins = __remember_cfg.get_value("Player", "coins", coins)
		volume = __remember_cfg.get_value("Player", "volume", volume)
	tree_exiting.connect(_ef_store_saved)
	return true

func _ef_store_saved(at_save_game: bool = false) -> void:
	var __remember_cfg: ConfigFile = ConfigFile.new()
	__remember_cfg.load("user://remembered.cfg")
	__remember_cfg.set_value("Player", "health", health)
	__remember_cfg.set_value("Player", "coins", coins)
	__remember_cfg.set_value("Player", "jumps", jumps)
	if at_save_game:
		__remember_cfg.set_value("Player", "volume", volume)
	__remember_cfg.save("user://remembered.cfg")

func save_state() -> Dictionary:
	_ef_store_saved(true)
	return {
		"health": health,
		"coins": coins,
		"spot": spot,
		"volume": volume,
		"jumps": jumps
	}

func load_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	health = int(state.get("health", health))
	coins = int(state.get("coins", coins))
	spot = state.get("spot", spot)
	volume = float(state.get("volume", volume))
"""

## A script somebody wrote, before any choice is made.
const HAND_WRITTEN: String = """class_name Player
extends Node2D

@export var health: int = 3
var coins: int = 0
var spot: Vector2 = Vector2.ZERO
var speed: float = 120.0
var volume: float = 1.0
var jumps: int = 0
"""


static func run() -> bool:
	var ok: bool = true
	ok = _compiles_each_choice() and ok
	ok = _reopens_as_the_choices() and ok
	ok = _leaves_hand_written_saves_alone() and ok
	ok = _refuses_what_it_cannot_write() and ok
	ok = _the_studio_row() and ok
	return ok


## The Save Studio's What gets saved tab: the choice it writes is the one the compiler reads, the
## object references are not offered, and the saving line says the whole story in words.
static func _the_studio_row() -> bool:
	var sheet: EventSheetResource = _sheet_with_choices()
	sheet.variables["sprite"] = {"type": "Sprite2D", "default": null, "exported": true}
	var first_pick: bool = EventSheetSaveStudio.set_save_choice(sheet, "speed", "load")
	var same_again: bool = EventSheetSaveStudio.set_save_choice(sheet, "speed", "load")
	var back_to_never: bool = EventSheetSaveStudio.set_save_choice(sheet, "coins", "")
	var opened: EventSheetResource = SUPPORT.reopen(HAND_WRITTEN, false)
	var on_a_script: bool = EventSheetSaveStudio.set_save_choice(opened, "jumps", "manual")
	var offered: Array = EventSheetSaveStudio.savable_variables(sheet).map(func(variable: Dictionary) -> String: return variable["name"])
	return SUPPORT.pins(PREFIX, [
		["a pick is an edit", first_pick, true],
		["the same pick again is not", same_again, false],
		["the pick is the compiler's choice", SaveChoices.choice_of(sheet.variables["speed"]["attributes"]), "load"],
		["Never takes the old remember spelling away too", [back_to_never, sheet.variables["coins"].has("attributes")], [true, false]],
		["a variable row of an opened script takes the pick", [on_a_script, SaveChoices.choice_of(_row(opened, "jumps").attributes)], [true, "manual"]],
		["object references and constants are not offered", offered, ["health", "coins", "spot", "speed", "volume", "jumps"]],
		["the sheet head's band names every saved variable", EventSheetHeadBands.remembered_variables(sheet),
			PackedStringArray(["health", "spot", "speed", "volume", "jumps"])],
		["the saving line", EventSheetSaveStudio.saving_line("Player", [{"name": "health", "choice": "auto"}, {"name": "coins", "choice": "auto"},
			{"name": "spot", "choice": "manual"}, {"name": "jumps", "choice": "save"}, {"name": "speed", "choice": ""}]),
			"Player: health, coins come back by themselves; spot only at your Save Game / Load Game; jumps is only written."],
		["nothing saved", EventSheetSaveStudio.saving_line("Player", [{"name": "speed", "choice": ""}]), "Nothing is saved: Player starts fresh every time."],
		["every choice says what it does", Array(EventSheetSaveStudio.SAVE_CHOICE_ORDER).map(func(choice: String) -> bool:
			return not EventSheetSaveStudio.save_choice_description(choice).is_empty() and not EventSheetSaveStudio.save_choice_use(choice).is_empty()),
			[true, true, true, true, true]],
	])


static func _row(sheet: EventSheetResource, variable_name: String) -> LocalVariable:
	for entry: Variant in sheet.events:
		if entry is LocalVariable and (entry as LocalVariable).name == variable_name:
			return entry
	return null


static func _sheet_with_choices() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = "Player"
	sheet.host_class = "Node2D"
	sheet.variables = {
		"health": {"type": "int", "default": 3, "exported": true, "attributes": {"save": "auto"}},
		"coins": {"type": "int", "default": 0, "exported": true, "attributes": {"remember": true}},
		"spot": {"type": "Vector2", "default": Vector2.ZERO, "exported": false, "attributes": {"save": "manual"}},
		"speed": {"type": "float", "default": 120.0, "exported": true},
		"volume": {"type": "float", "default": 1.0, "exported": true, "attributes": {"save": "load"}},
		"jumps": {"type": "int", "default": 0, "exported": true, "attributes": {"save": "save"}},
		"MAX_LIVES": {"type": "int", "default": 9, "exported": false, "const": true, "attributes": {"save": "auto"}},
	}
	return sheet


## Each choice lands where it says: Auto both ways, Load only read at ready and written at Save Game,
## Save only written and never read back, Manual only in the pair. Never and constants stay out.
static func _compiles_each_choice() -> bool:
	var output: String = SUPPORT.compile_output(_sheet_with_choices(), "user://save_choices_out.gd")
	var ok: bool = SUPPORT.pins(PREFIX, [
		["the block is the whole tail", output.ends_with(EXPECTED_BLOCK), true],
		["the old remember spelling reads as Auto", SaveChoices.choice_of({"remember": true}), "auto"],
		["Never stores nothing", SaveChoices.choice_of({"tooltip": "x"}), ""],
		["a sheet with no choice gets no block", SUPPORT.compile_output(EventSheetResource.new(), "user://save_choices_none.gd").contains(SaveChoices.DOC), false],
	])
	var script: GDScript = GDScript.new()
	script.source_code = output
	ok = SUPPORT.check(PREFIX, "the emitted file parses", script.reload(), OK) and ok
	if not ok:
		return false
	# The pair does what the choices say on a live object, with no tree and no plugin.
	var player: Node2D = script.new()
	player.set("health", 1)
	player.set("jumps", 7)
	var snapshot: Dictionary = player.call("save_state")
	player.call("load_state", {"health": 5, "jumps": 99, "spot": Vector2(4, 2)})
	ok = SUPPORT.pins(PREFIX, [
		["Save Game holds every saved variable", snapshot.keys(), ["health", "coins", "spot", "volume", "jumps"]],
		["Load Game restores Auto", player.get("health"), 5],
		["Load Game restores Manual", player.get("spot"), Vector2(4, 2)],
		["Load Game never reads a Save only variable back", player.get("jumps"), 7],
	]) and ok
	player.free()
	return ok


## Written into a script, the block reads back into the same choices and saves byte for byte.
static func _reopens_as_the_choices() -> bool:
	var opened: EventSheetResource = SUPPORT.reopen(HAND_WRITTEN, false)
	var wanted: Dictionary = {"health": "auto", "coins": "auto", "spot": "manual", "volume": "load", "jumps": "save"}
	for entry: Variant in opened.events:
		if entry is LocalVariable and wanted.has((entry as LocalVariable).name):
			var attributes: Dictionary = (entry as LocalVariable).attributes.duplicate()
			SaveChoices.set_choice(attributes, str(wanted[(entry as LocalVariable).name]))
			(entry as LocalVariable).attributes = attributes
	opened.external_source_path = "user://save_choices_player.gd"
	var written: String = SUPPORT.compile_output(opened, "user://save_choices_player.gd")
	var reopened: EventSheetResource = SUPPORT.reopen(written)
	var read_back: Dictionary = {}
	for entry: Variant in reopened.events:
		if entry is LocalVariable:
			read_back[(entry as LocalVariable).name] = SaveChoices.choice_of((entry as LocalVariable).attributes)
	return SUPPORT.pins(PREFIX, [
		["the script keeps its own lines", written.begins_with(HAND_WRITTEN), true],
		["the choices read back", read_back, {"health": "auto", "coins": "auto", "spot": "manual", "speed": "", "volume": "load", "jumps": "save"}],
		["the block is not shown as functions", str(reopened.functions.map(func(f: EventFunction) -> String: return f.function_name)).contains("save_state"), false],
		["reopen then save is byte-identical", SUPPORT.reemit(written, "user://save_choices_player.gd"), written],
	])


## A save_state()/load_state() somebody wrote, or a block somebody edited, stays exactly as it was.
static func _leaves_hand_written_saves_alone() -> bool:
	var own: String = HAND_WRITTEN + "\n\nfunc save_state() -> Dictionary:\n\treturn {\"health\": health}\n\n\nfunc load_state(state: Dictionary) -> void:\n\thealth = int(state.get(\"health\", health))\n"
	var edited: String = HAND_WRITTEN + "\n" + SaveChoices.DOC + "\n@onready var __ef_save_boot: bool = _ef_load_saved()\n\nfunc _ef_load_saved() -> bool:\n\tadd_to_group(\"persist\")\n\tprint(\"mine\")\n\treturn true\n\nfunc save_state() -> Dictionary:\n\treturn {\n\t\t\"health\": health\n\t}\n\nfunc load_state(state: Dictionary) -> void:\n\tif state.is_empty():\n\t\treturn\n\thealth = int(state.get(\"health\", health))\n"
	var edited_sheet: EventSheetResource = SUPPORT.reopen(edited)
	var edited_choice: String = ""
	for entry: Variant in edited_sheet.events:
		if entry is LocalVariable and (entry as LocalVariable).name == "health":
			edited_choice = SaveChoices.choice_of((entry as LocalVariable).attributes)
	return SUPPORT.pins(PREFIX, [
		["a hand-written pair reopens byte-identical", SUPPORT.reemit(own, "user://save_choices_own.gd"), own],
		["an edited block reopens byte-identical", SUPPORT.reemit(edited, "user://save_choices_edited.gd"), edited],
		["an edited block is not read as a choice", edited_choice, ""],
	])


static func _only_health() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.variables = {"health": {"type": "int", "default": 3, "exported": true, "attributes": {"save": "manual"}}}
	return sheet


## A Resource has no ready or exit to hang the loads on, and a sheet that already writes the pair keeps
## its own: both are said, and nothing broken is written.
static func _refuses_what_it_cannot_write() -> bool:
	var resource_host: EventSheetResource = _only_health()
	resource_host.host_class = "Resource"
	var resource_result: Dictionary = SheetCompiler.compile(resource_host, "user://save_choices_resource.gd")
	var owned: EventSheetResource = _only_health()
	var own_save: EventFunction = EventFunction.new()
	own_save.function_name = "save_state"
	owned.functions.append(own_save)
	var owned_result: Dictionary = SheetCompiler.compile(owned, "user://save_choices_owned.gd")
	return SUPPORT.pins(PREFIX, [
		["a Resource host gets no block", str(resource_result.get("output", "")).contains(SaveChoices.DOC), false],
		["a Resource host is told why", str(resource_result.get("warnings", [])).contains("needs a Node host"), true],
		["a sheet with its own save_state gets no block", str(owned_result.get("output", "")).contains(SaveChoices.DOC), false],
		["a sheet with its own save_state is told why", str(owned_result.get("warnings", [])).contains("already writes save_state()"), true],
	])
