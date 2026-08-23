# Godot EventSheets - the sheet HEAD as a band stack.
#
# The head used to be one crumb trail (`▣ Node ▸ CharacterBody2D ▸ Player`), folded away by default,
# with the rest of the facts behind a label/value dropdown. It is now one band per line of the file.
# This test pins the model behind it, per sheet kind, plus the three gestures that write those lines:
#
#   1. THE BANDS PER KIND. A node script, an autoload, a behaviour, a data type, an editor tool and a
#      file with no class_name each get exactly the bands their lines justify - and each band's echo
#      is a line that is really there (an autoload's name is its project.godot entry, never a
#      `class_name` it does not have).
#   2. WHAT "+ add" OFFERS. Only the lines this sheet could have and does not - never autoload or
#      host, which come from choosing a kind.
#   3. THE PRELUDE REWRITE. One band, one line: added where GDScript wants it, replaced where it is
#      already there, removed when the band is switched off. VALUES are pinned, not counts.
#   4. THE RENAME COUNT. The sentence the name band says before it writes anything.
#   5. THE DIALOG ORDER. The Sheet type dialog's KIND list reads common-six, divider, editor kinds -
#      while every type still carries its FROZEN index as its item id, because that index is what a
#      saved sheet round-trips through.
@tool
class_name SheetHeadBandsTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true
	ok = _test_bands_per_kind() and ok
	ok = _test_add_offers() and ok
	ok = _test_prelude_rewrite() and ok
	ok = _test_a_doc_comment_block_keeps_its_other_lines() and ok
	ok = _test_rename_count() and ok
	ok = _test_dialog_order() and ok
	return ok


static func _test_bands_per_kind() -> bool:
	var ok: bool = true

	# A node script: name, what it extends, its icon, its sentence.
	var player: EventSheetResource = _sheet("res://player.gd")
	var player_facts: Dictionary = EventSheetHeadBands.facts(player,
		"class_name Player\nextends CharacterBody2D\n@icon(\"res://icons/player.svg\")\n## The player avatar: movement, health and the hit reaction.")
	ok = _check("a node script reads name, extends, icon, description",
		_kinds(player_facts), "name | extends | icon | description") and ok
	ok = _check("the name band echoes the class_name line",
		_echo(player_facts, "name"), "class_name Player") and ok
	ok = _check("the icon band echoes the annotation with its path",
		_echo(player_facts, "icon"), "@icon(\"res://icons/player.svg\")") and ok
	ok = _check("the description band echoes the ## line",
		_echo(player_facts, "description"), "## The player avatar: movement, health and the hit reaction.") and ok
	ok = _check("the extends band offers the host picker",
		_band(player_facts, "extends").get("control", ""), "change…") and ok

	# An autoload: no class_name at all - its name is the project.godot entry, and the band says so.
	var game: EventSheetResource = _sheet("res://game.gd")
	game.autoload_mode = true
	game.autoload_name = "Game"
	game.host_class = "Node"
	var game_facts: Dictionary = EventSheetHeadBands.facts(game,
		"extends Node\n## Score, lives and the run state.")
	ok = _check("an autoload reads name, extends, description, autoload",
		_kinds(game_facts), "name | extends | description | autoload") and ok
	ok = _check("its name band is the file, and says why",
		_band(game_facts, "name").get("value", ""), "game.gd") and ok
	ok = _check("with the echo saying where the name lives",
		_echo(game_facts, "name"), "# no class_name - the name is the autoload entry") and ok
	ok = _check("the name band is muted, because a file name is not a class name",
		_band(game_facts, "name").get("value_muted", false), true) and ok
	ok = _check("the autoload band echoes the project.godot entry",
		_echo(game_facts, "autoload"), "project.godot: autoload/Game = \"*res://game.gd\"") and ok
	ok = _check("and its control is a link to Project Settings, the only place it can change",
		_band(game_facts, "autoload").get("control", ""), "Project Settings…") and ok

	# A behaviour: two lines of host binding, one fact, one band.
	var movement: EventSheetResource = _sheet("res://platformer_movement.gd")
	movement.behavior_mode = true
	movement.host_class = "Node"
	var movement_facts: Dictionary = EventSheetHeadBands.facts(movement,
		"class_name PlatformerMovement\nextends Node\nfunc _enter_tree() -> void:\n\thost = get_parent()")
	ok = _check("a behaviour reads name, extends, host",
		_kinds(movement_facts), "name | extends | host") and ok
	ok = _check("the host binding is one band saying one thing",
		_band(movement_facts, "host").get("value", ""), "acts on its parent") and ok

	# A data type: two lines, two bands, nothing invented.
	var stats: EventSheetResource = _sheet("res://weapon_stats.gd")
	stats.host_class = "Resource"
	ok = _check("a data type reads name and extends only",
		_kinds(EventSheetHeadBands.facts(stats, "class_name WeaponStats\nextends Resource")),
		"name | extends") and ok

	# An editor tool: @tool is a line of the file, so it is a band with its switch on.
	var brush: EventSheetResource = _sheet("res://tile_brush.gd")
	var brush_facts: Dictionary = EventSheetHeadBands.facts(brush,
		"@tool\nclass_name TileBrush\nextends EditorScript")
	ok = _check("an editor tool reads name, extends, @tool",
		_kinds(brush_facts), "name | extends | tool") and ok
	ok = _check("its switch is on", _band(brush_facts, "tool").get("switch_on", false), true) and ok
	ok = _check("and its echo is full strength, because the line is there",
		_band(brush_facts, "tool").get("echo_ghosted", true), false) and ok
	# The same kind WITHOUT the line keeps the band, switched off and ghosted - the control has to be
	# findable exactly where it is most often missing.
	var untooled: Dictionary = EventSheetHeadBands.facts(_sheet("res://tile_brush.gd"),
		"class_name TileBrush\nextends EditorScript")
	ok = _check("an editor tool that does NOT run in the editor still shows the switch",
		_kinds(untooled), "name | extends | tool") and ok
	ok = _check("with the switch off and the echo ghosted",
		[_band(untooled, "tool").get("switch_on", true), _band(untooled, "tool").get("echo_ghosted", false)],
		[false, true]) and ok

	# A file with no class_name: named by its file, and the echo says exactly that.
	var plain: EventSheetResource = _sheet("res://opened_script_coverage.gd")
	plain.host_class = "Node2D"
	var plain_facts: Dictionary = EventSheetHeadBands.facts(plain,
		"extends Node2D\n## A script that does not entirely read as events.")
	ok = _check("a file with no class_name reads name, extends, description",
		_kinds(plain_facts), "name | extends | description") and ok
	ok = _check("its name band is the file name",
		_band(plain_facts, "name").get("value", ""), "opened_script_coverage.gd") and ok
	ok = _check("and the echo says why", _echo(plain_facts, "name"), "# no class_name - named by its file") and ok

	# A brand-new sheet: the two bands ask their questions, and the attach prompt is a row.
	var fresh: Dictionary = EventSheetHeadBands.facts(null, "", false)
	ok = _check("a brand-new sheet asks to be named and to be told what it extends",
		_kinds(fresh), "name | extends | attach") and ok
	ok = _check("the name band prompts", _band(fresh, "name").get("prompt", ""), "name it") and ok
	ok = _check("the extends band prompts",
		_band(fresh, "extends").get("prompt", ""), "choose what it extends") and ok
	ok = _check("and the attach prompt is its own row",
		_band(fresh, "attach").get("prompt", ""), "attach to a node") and ok
	# Each prompt disappears when it is answered.
	var named: Dictionary = EventSheetHeadBands.facts(_sheet(""), "class_name Player\nextends CharacterBody2D")
	ok = _check("a named sheet stops asking", _band(named, "name").get("prompt", ""), "") and ok
	return ok


static func _test_add_offers() -> bool:
	var ok: bool = true
	var bare: Dictionary = EventSheetHeadBands.facts(_sheet("res://player.gd"),
		"class_name Player\nextends CharacterBody2D")
	ok = _check("+ add offers only the lines this sheet could have and does not",
		EventSheetHeadBands.add_row_text(bare), "+ add: icon · @tool · description") and ok
	var full: Dictionary = EventSheetHeadBands.facts(_sheet("res://player.gd"),
		"@tool\nclass_name Player\nextends CharacterBody2D\n@icon(\"res://i.svg\")\n## Says it all.")
	ok = _check("a sheet with every line has nothing to add",
		EventSheetHeadBands.add_row_text(full), "") and ok
	var autoload_sheet: EventSheetResource = _sheet("res://game.gd")
	autoload_sheet.autoload_mode = true
	autoload_sheet.autoload_name = "Game"
	var autoload_facts: Dictionary = EventSheetHeadBands.facts(autoload_sheet, "extends Node")
	ok = _check("+ add never offers autoload or host - those come from choosing a kind",
		Array(EventSheetHeadBands.addable(autoload_facts)).has("autoload"), false) and ok
	return ok


static func _test_prelude_rewrite() -> bool:
	var ok: bool = true
	const PRELUDE := "class_name Player\nextends CharacterBody2D"
	ok = _check("switching @tool on opens the file with it",
		EventSheetHeadActions.rewrite_prelude(PRELUDE, EventSheetHeadBands.BAND_TOOL, "true"),
		"@tool\nclass_name Player\nextends CharacterBody2D") and ok
	ok = _check("switching @tool off takes the line out",
		EventSheetHeadActions.rewrite_prelude("@tool\n" + PRELUDE, EventSheetHeadBands.BAND_TOOL, "false"),
		PRELUDE) and ok
	ok = _check("@tool goes UNDER a file-header comment, never above it",
		EventSheetHeadActions.rewrite_prelude("# Patrol - walks a path.\n" + PRELUDE,
			EventSheetHeadBands.BAND_TOOL, "true"),
		"# Patrol - walks a path.\n@tool\nclass_name Player\nextends CharacterBody2D") and ok
	ok = _check("the name band rewrites the class_name line",
		EventSheetHeadActions.rewrite_prelude(PRELUDE, EventSheetHeadBands.BAND_NAME, "Hero"),
		"class_name Hero\nextends CharacterBody2D") and ok
	ok = _check("a class_name the file lacks is written above extends",
		EventSheetHeadActions.rewrite_prelude("extends Node", EventSheetHeadBands.BAND_NAME, "Hero"),
		"class_name Hero\nextends Node") and ok
	ok = _check("the extends band rewrites the extends line",
		EventSheetHeadActions.rewrite_prelude(PRELUDE, EventSheetHeadBands.BAND_EXTENDS, "Node2D"),
		"class_name Player\nextends Node2D") and ok
	ok = _check("an icon is written above class_name",
		EventSheetHeadActions.rewrite_prelude(PRELUDE, EventSheetHeadBands.BAND_ICON, "res://i.svg"),
		"@icon(\"res://i.svg\")\nclass_name Player\nextends CharacterBody2D") and ok
	ok = _check("an icon that is already there is replaced, not doubled",
		EventSheetHeadActions.rewrite_prelude("@icon(\"res://old.svg\")\n" + PRELUDE,
			EventSheetHeadBands.BAND_ICON, "res://new.svg"),
		"@icon(\"res://new.svg\")\nclass_name Player\nextends CharacterBody2D") and ok
	ok = _check("a description is written as the ## block above class_name",
		EventSheetHeadActions.rewrite_prelude(PRELUDE, EventSheetHeadBands.BAND_DESCRIPTION, "The player avatar."),
		"## The player avatar.\nclass_name Player\nextends CharacterBody2D") and ok
	ok = _check("an emptied description takes its line away",
		EventSheetHeadActions.rewrite_prelude("## The player avatar.\n" + PRELUDE,
			EventSheetHeadBands.BAND_DESCRIPTION, ""),
		PRELUDE) and ok
	ok = _check("an @ace_ annotation is never mistaken for the description",
		EventSheetHeadActions.rewrite_prelude("## @ace_tags(movement)\n" + PRELUDE,
			EventSheetHeadBands.BAND_DESCRIPTION, "Walks a path."),
		"## @ace_tags(movement)
## Walks a path.
class_name Player
extends CharacterBody2D") and ok
	ok = _check("writing what is already there changes nothing",
		EventSheetHeadActions.rewrite_prelude(PRELUDE, EventSheetHeadBands.BAND_NAME, "Player"),
		PRELUDE) and ok
	return ok


static func _test_rename_count() -> bool:
	var ok: bool = true
	ok = _check("the rename says its reach before it writes",
		EventSheetHeadActions.rename_reach_text({"uses": 9, "sheets": 4}),
		"renames 9 uses in 4 sheets") and ok
	ok = _check("one use of one sheet reads as one",
		EventSheetHeadActions.rename_reach_text({"uses": 1, "sheets": 1}),
		"renames 1 use in 1 sheet") and ok
	ok = _check("a name nothing else uses says so",
		EventSheetHeadActions.rename_reach_text({"uses": 0, "sheets": 0}),
		"renames nothing else - this name is used nowhere yet") and ok
	ok = _check("a class nobody named has nothing to rename",
		EventSheetHeadActions.rename_reach(""), {"uses": 0, "sheets": 0}) and ok
	return ok


static func _test_dialog_order() -> bool:
	var ok: bool = true
	ok = _check("the KIND list reads common-six, divider, editor kinds",
		Array(EventSheetSheetTypeDialog.TYPE_ORDER), [0, 1, 2, 4, 5, 6, -1, 3, 7, 8, 9, 10, 11]) and ok
	ok = _check("every type is in the list exactly once",
		_ordered_types().size(), EventSheetSheetTypeDialog.TYPE_HINTS.size()) and ok
	ok = _check("a type is named once, in one table",
		EventSheetSheetTypeDialog.TYPE_LABELS.size(), EventSheetSheetTypeDialog.TYPE_HINTS.size()) and ok
	ok = _check("the first kind is the plain sheet",
		EventSheetSheetTypeDialog.TYPE_LABELS[EventSheetSheetTypeDialog.TYPE_ORDER[0]], "Event Sheet") and ok
	ok = _check("the kind after the divider is the first editor kind",
		EventSheetSheetTypeDialog.TYPE_LABELS[EventSheetSheetTypeDialog.TYPE_ORDER[7]], "Editor Tool") and ok
	return ok


## Every type index the KIND list offers, dividers dropped and deduplicated.
static func _ordered_types() -> Dictionary:
	var seen: Dictionary = {}
	for type_index: int in EventSheetSheetTypeDialog.TYPE_ORDER:
		if type_index >= 0:
			seen[type_index] = true
	return seen


## A `##` block of several lines is several LINES of the file, and a band is one line. The band is
## the first of them - so its echo is a line the file really has, rather than the block joined into
## one sentence - and writing it leaves every other line of the block exactly where its author put it.
static func _test_a_doc_comment_block_keeps_its_other_lines() -> bool:
	var ok: bool = true
	const BLOCK := "## Player controller.\n## Handles input and movement.\nclass_name Player"
	var facts: Dictionary = EventSheetHeadBands.facts(_sheet("res://player.gd"),
		"%s\nextends CharacterBody2D" % BLOCK)
	ok = _check("the band stands for the first ## line, not the block joined into one",
		_band(facts, "description").get("value", ""), "Player controller.") and ok
	ok = _check("…so its echo is a line the file actually has",
		_echo(facts, "description"), "## Player controller.") and ok
	ok = _check("rewriting the band leaves the rest of the block alone",
		EventSheetHeadActions.rewrite_prelude(BLOCK, EventSheetHeadBands.BAND_DESCRIPTION,
			"The player avatar."),
		"## The player avatar.\n## Handles input and movement.\nclass_name Player") and ok
	ok = _check("and clearing it takes away one line, not the block",
		EventSheetHeadActions.rewrite_prelude(BLOCK, EventSheetHeadBands.BAND_DESCRIPTION, ""),
		"## Handles input and movement.\nclass_name Player") and ok
	ok = _check("the sheet field the band mirrors keeps its other lines too",
		EventSheetHeadBands.replace_description_line(
			"Player controller.\nHandles input and movement.", "The player avatar."),
		"The player avatar.\nHandles input and movement.") and ok
	return ok


static func _sheet(source_path: String) -> EventSheetResource:
	var sheet := EventSheetResource.new()
	sheet.external_source_path = source_path
	return sheet


## The band kinds these facts produce, in order.
static func _kinds(head_facts: Dictionary) -> String:
	var kinds: PackedStringArray = PackedStringArray()
	for band: Dictionary in EventSheetHeadBands.bands(head_facts):
		kinds.append(str(band["kind"]))
	return " | ".join(kinds)


static func _band(head_facts: Dictionary, band_kind: String) -> Dictionary:
	for band: Dictionary in EventSheetHeadBands.bands(head_facts):
		if str(band["kind"]) == band_kind:
			return band
	return {}


static func _echo(head_facts: Dictionary, band_kind: String) -> String:
	return str(_band(head_facts, band_kind).get("echo", ""))


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] sheet_head_bands_test: %s" % label)
		return true
	print("[FAIL] sheet_head_bands_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
