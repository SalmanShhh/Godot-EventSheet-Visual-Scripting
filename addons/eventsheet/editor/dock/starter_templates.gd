@tool
class_name EventSheetStarterTemplates
extends RefCounted

# "New from template" starter sheets (the New-Sheet ▾ menu / shortcut / command palette / Welcome).
#
# Owns the template PopupMenu and builds a fresh EventSheetResource for each built-in starter
# (platformer, top-down, 3D controllers, autoload singletons, a signal-driven behavior component)
# plus any project template dropped in res://eventsheet_templates/. Extracted from event_sheet_dock.gd
# so the dock stays focused; the dock keeps a thin _open_template_menu() delegate (so the menu item,
# the shortcut, the palette entry, and the Welcome button all keep calling the dock unchanged) and
# this class reaches back through the dock reference to adopt the new sheet (setup) + reset its
# title strip / undo history / dirty state and write the status bar.

var _dock: Control = null


func init(dock: Control) -> void:
	_dock = dock

var _template_menu: PopupMenu = null


func open_menu() -> void:
	_build_template_menu_items()
	_template_menu.popup(Rect2i(Vector2i(_dock.get_global_mouse_position()), Vector2i(0, 0)))

## Rebuilt on every open so project templates (res://eventsheet_templates/, ids 100+)
## appear the moment a .tres lands in the folder - same zero-config convention as
## eventsheet_addons/.
var _project_template_paths: PackedStringArray = PackedStringArray()


func _build_template_menu_items() -> void:
	if _template_menu == null:
		_template_menu = PopupMenu.new()
		_template_menu.id_pressed.connect(_new_sheet_from_template)
		_dock.add_child(_template_menu)
	_template_menu.clear()
	# The creation-time ASK: what kind of Godot script is this sheet for? Sections mirror
	# EventSheetScriptIntent so a newcomer discovers custom resources and editor tools at the
	# same moment they discover behaviours - without a wizard slowing every creation down.
	_template_menu.add_separator("Scripts on a node")
	_template_menu.add_item("Blank Sheet", 0)
	_template_menu.add_item("Platformer Starter", 1)
	_template_menu.add_item("Top-down Starter", 2)
	_template_menu.add_item("First-Person Controller (3D)", 6)
	_template_menu.add_item("Third-Person Mover (3D)", 7)
	_template_menu.add_item("Boomer Arsenal (3D)", 15)
	_template_menu.add_item("Game Options", 16)
	_template_menu.add_separator("Behaviours - attach under a node")
	_template_menu.add_item("Behavior Component (signal-driven)", 8)
	_template_menu.add_separator("Autoloads - project-wide singletons")
	_template_menu.add_item("Game State (Autoload)", 3)
	_template_menu.add_item("Event Bus (Autoload)", 4)
	_template_menu.add_item("Save System (Autoload)", 5)
	_template_menu.add_separator("Systems - run over a group of entities")
	_template_menu.add_item("Entity System (Autoload)", 11)
	_template_menu.add_separator("Custom Resources - data assets (.tres)")
	_template_menu.add_item("Custom Resource (data + logic)", 9)
	_template_menu.add_separator("Editor Tools - run inside the editor")
	_template_menu.add_item("Editor Tool (one-click chore)", 10)
	_template_menu.add_item("Editor Plugin (dock, menu item, object type)", 12)
	_template_menu.add_item("Import Tool (runs on import)", 13)
	_template_menu.add_item("Export Hook (runs on export)", 14)
	_project_template_paths = EventSheetTemplates.list_templates()
	if not _project_template_paths.is_empty():
		_template_menu.add_separator("Project templates")
		for index in _project_template_paths.size():
			_template_menu.add_item(_project_template_paths[index].get_file().get_basename().capitalize(), 100 + index)


## A signal-driven BEHAVIOR COMPONENT starter - the Godot composition idiom modelled by example, so a
## newcomer's first copy is NOT a monolithic god-sheet. It compiles to an attachable Node with a typed
## `host` accessor (its parent), reacts to the host's body_entered SIGNAL (no per-frame polling), and
## emits its own (On Collected) so other sheets stay decoupled. `value` is an exported designer knob.
static func _build_behavior_component_starter() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Area2D"
	sheet.custom_class_name = "PickupBehavior"
	sheet.variables = {"value": {"type": "int", "default": 1, "exported": true}}
	var about: CommentRow = CommentRow.new()
	about.text = "[b]Behavior Component[/b] - Godot's answer to a node-attached behavior. Instead of one big sheet on the root, this is a small reusable piece you ATTACH as a child of the node it controls (here, an Area2D pickup); it compiles to a Node, and [code]host[/code] is the node it is attached to.\nIt REACTS to a signal (the host's body_entered) instead of checking every frame, and EMITS its own (On Collected) so other sheets stay decoupled. [code]value[/code] is a designer knob in the Inspector."
	sheet.events.append(about)
	var declared_signal: RawCodeRow = RawCodeRow.new()
	declared_signal.code = "## @ace_trigger\n## @ace_name(\"On Collected\")\n## @ace_category(\"Pickup\")\nsignal collected(by: Node, amount: int)"
	sheet.events.append(declared_signal)
	var on_ready: EventRow = EventRow.new()
	on_ready.trigger_provider_id = "Core"
	on_ready.trigger_id = "OnReady"
	var connect_signal: RawCodeRow = RawCodeRow.new()
	connect_signal.code = "if host != null:\n\thost.body_entered.connect(func(body: Node) -> void:\n\t\tcollected.emit(body, value)\n\t\thost.queue_free()\n\t)"
	on_ready.actions.append(connect_signal)
	sheet.events.append(on_ready)
	return sheet


## A CUSTOM RESOURCE starter - Godot's data-asset idiom modelled by example, so a newcomer's
## first resource sheet steers toward its full potential: exported variables ARE the asset's
## designer-editable fields, logic lives in functions (resources have no _process), and a signal
## lets live data notify listeners. Each .tres created from the compiled class is its own asset.
## An ENTITY SYSTEM starter (composition / ECS-lite): a system runs its step over every entity in a
## GROUP each frame, instead of copying logic onto every node. Compiles to an autoload singleton with an
## OnProcess that loops get_nodes_in_group - the Godot-native "systems over groups" pattern. Tag entities
## with add_to_group, rename the group + autoload for your own, and add more systems as more autoloads.
static func _build_system_starter() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.autoload_mode = true
	sheet.autoload_name = "EnemySystem"
	sheet.host_class = "Node"
	sheet.custom_class_name = "EnemySystem"
	sheet.class_description = "A SYSTEM (composition / ECS-lite): it runs over every entity in a group each frame, instead of putting logic on each node. Tag entities into the \"enemy\" group with add_to_group, rename the group + autoload for your own, and register this sheet as an autoload."
	var note: CommentRow = CommentRow.new()
	note.text = "[b]Entity System (Autoload)[/b] - composition / ECS-lite. Tag entities into a group and this runs once per frame for every one of them. Add more systems as more autoload sheets. Prefer signals over polling for big sets, and the Time Slicer pack to spread heavy sweeps."
	sheet.events.append(note)
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var body: RawCodeRow = RawCodeRow.new()
	body.code = "\n".join(PackedStringArray([
		"# A system runs its step over every entity in the group. Tag nodes with add_to_group(\"enemy\").",
		"for entity: Node in get_tree().get_nodes_in_group(\"enemy\"):",
		"\tif entity is Node2D:",
		"\t\t# Example: drift every enemy slowly to the right - replace with your system's logic.",
		"\t\t(entity as Node2D).position += Vector2(20.0, 0.0) * delta"
	]))
	tick.actions.append(body)
	sheet.events.append(tick)
	return sheet


static func _build_custom_resource_starter() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Resource"
	sheet.custom_class_name = "LootTable"
	sheet.variables = {
		"entries": {"type": "Array", "default": [], "exported": true, "attributes": {"tooltip": "One item name per entry - duplicates raise the odds."}},
		"fallback": {"type": "String", "default": "coin", "exported": true},
		# Two real inspector options as living documentation: a bounded slider with an open top,
		# and a file picker - the exact annotations show in the variable dialog's "Ships as:" strip.
		"rolls": {"type": "int", "default": 1, "exported": true, "attributes": {"range": {"min": "1", "max": "10", "step": "1", "or_greater": true}, "tooltip": "How many items one roll yields."}},
		"pickup_sound": {"type": "String", "default": "", "exported": true, "attributes": {"file": {"mode": "file", "filters": ["*.ogg", "*.wav"]}, "tooltip": "Played when the loot is picked up."}},
	}
	var about: CommentRow = CommentRow.new()
	about.text = "[b]Custom Resource[/b] - a data asset with logic. The exported variables become fields designers edit per-.tres file (right-click the FileSystem dock > New Resource > LootTable once this compiles). Resources have no _process or _ready: give them [b]functions[/b] instead of events, and call those from the sheets that load the asset."
	sheet.events.append(about)
	var roll: EventFunction = EventFunction.new()
	roll.function_name = "roll"
	roll.return_type = TYPE_STRING
	roll.expose_as_ace = true
	roll.ace_display_name = "Roll Loot"
	roll.ace_category = "Loot"
	var roll_body: RawCodeRow = RawCodeRow.new()
	roll_body.code = "if entries.is_empty():\n\treturn fallback\nreturn str(entries.pick_random())"
	roll.events.append(roll_body)
	sheet.functions.append(roll)
	return sheet


## An EDITOR TOOL starter - an EditorScript with @tool, run from the script editor (File > Run).
## Modelled small: one On Editor Run event doing a visible, safe chore, so the shape ("events
## that run IN the editor, not in the game") lands immediately.
static func _build_editor_tool_starter() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "EditorScript"
	sheet.tool_mode = true
	sheet.custom_class_name = ""
	var about: CommentRow = CommentRow.new()
	about.text = "[b]Editor Tool[/b] - these events run inside the EDITOR when you run the compiled script (script editor > File > Run), never in the game. Great for batch renames, scene checks, and one-click project chores."
	sheet.events.append(about)
	var run_event: EventRow = EventRow.new()
	run_event.trigger_provider_id = "Core"
	run_event.trigger_id = "OnEditorRun"
	var chore: RawCodeRow = RawCodeRow.new()
	chore.code = "var scene_root: Node = EditorInterface.get_edited_scene_root()\nif scene_root == null:\n\tprint(\"Open a scene first.\")\nelse:\n\tprint(\"%s has %d nodes.\" % [scene_root.name, scene_root.get_child_count()])"
	run_event.actions.append(chore)
	sheet.events.append(run_event)
	return sheet


## R33 - an EDITOR PLUGIN starter. Where the Editor Tool starter above is a chore you press Run on,
## a plugin is something the editor SWITCHES ON: it arrives with the pair of events that shape says
## (add the Tools menu item when the plugin is enabled, take it away again when it is disabled) plus
## the function the menu item calls, so the very first compile is a plugin that already works.
static func _build_editor_plugin_starter() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "EditorPlugin"
	sheet.tool_mode = true
	var about: CommentRow = CommentRow.new()
	about.text = "[b]Editor Plugin[/b] - the editor switches this on and off, and while it is on it adds things to the editor itself: a Tools menu item, a dock, an object type, an Inspector button. Everything On plugin enabled adds, On plugin disabled must take away again.\nSheet Type… ▸ Editor Plugin has a tick for each of those, and the Include bar has Enable plugin."
	sheet.events.append(about)
	var enabled: EventRow = EventRow.new()
	enabled.trigger_provider_id = "Core"
	enabled.trigger_id = "OnPluginEnabled"
	var add_item: ACEAction = ACEAction.new()
	add_item.provider_id = "Core"
	add_item.ace_id = "AddToolsMenuItem"
	add_item.codegen_template = "add_tool_menu_item({title}, {handler})"
	add_item.params = {"title": "\"Snap Selection\"", "handler": "_run_tool"}
	enabled.actions.append(add_item)
	sheet.events.append(enabled)
	var disabled: EventRow = EventRow.new()
	disabled.trigger_provider_id = "Core"
	disabled.trigger_id = "OnPluginDisabled"
	var remove_item: ACEAction = ACEAction.new()
	remove_item.provider_id = "Core"
	remove_item.ace_id = "RemoveToolsMenuItem"
	remove_item.codegen_template = "remove_tool_menu_item({title})"
	remove_item.params = {"title": "\"Snap Selection\""}
	disabled.actions.append(remove_item)
	sheet.events.append(disabled)
	var run_tool: EventFunction = EventFunction.new()
	run_tool.function_name = "_run_tool"
	var run_body: RawCodeRow = RawCodeRow.new()
	run_body.code = "for node: Node in EditorInterface.get_selection().get_selected_nodes():\n\tif node is Node2D:\n\t\t(node as Node2D).position = (node as Node2D).position.snapped(Vector2(16.0, 16.0))"
	run_tool.events.append(run_body)
	sheet.functions.append(run_tool)
	return sheet


## R33 - an IMPORT TOOL starter. One On File Imported event: the paths Godot just brought in arrive
## as `paths`, and the body only reports what landed - a first tool should never silently rewrite a
## designer's files, so the shape is "look at what arrived" and the editing is left to the reader.
static func _build_import_tool_starter() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "EditorScript"
	sheet.tool_mode = true
	var about: CommentRow = CommentRow.new()
	about.text = "[b]Import Tool[/b] - these events run just after Godot finishes importing files, with the paths that landed in [code]paths[/code]. Great for checking a texture's import settings, renaming what was dropped in, or keeping a manifest up to date.\nIt never runs in the game: the editor calls it, and an exported build simply never does."
	sheet.events.append(about)
	var imported: EventRow = EventRow.new()
	imported.trigger_provider_id = "Core"
	imported.trigger_id = "OnFileImported"
	var body: RawCodeRow = RawCodeRow.new()
	body.code = "for path: String in paths:\n\tif path.get_extension() == \"png\":\n\t\tprint(\"Imported image: %s\" % path)"
	imported.actions.append(body)
	sheet.events.append(imported)
	return sheet


## R33 - an EXPORT HOOK starter. The shipped On Project Export trigger with the smallest honest bake
## step: write the version stamp, and only outside a debug build, so the two facts the exporter hands
## a hook (`is_debug`, `features`) are both modelled the first time a reader sees the event.
static func _build_export_hook_starter() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "EditorScript"
	sheet.tool_mode = true
	var about: CommentRow = CommentRow.new()
	about.text = "[b]Export Hook[/b] - these events run as a project export begins, before the files are written. The place to stamp a build number, bake a data file, or strip debug content.\nKeep it synchronous: an export does not wait, so anything after an [code]await[/code] may miss the build."
	sheet.events.append(about)
	var exporting: EventRow = EventRow.new()
	exporting.trigger_provider_id = "Core"
	exporting.trigger_id = "OnProjectExport"
	var not_debug: ACECondition = ACECondition.new()
	not_debug.provider_id = "Core"
	not_debug.ace_id = "ExportIsDebug"
	not_debug.codegen_template = "is_debug"
	not_debug.negated = true
	exporting.conditions.append(not_debug)
	var stamp: RawCodeRow = RawCodeRow.new()
	stamp.code = "var config: ConfigFile = ConfigFile.new()\nconfig.set_value(\"build\", \"version\", ProjectSettings.get_setting(\"application/config/version\", \"0.0.0\"))\nconfig.save(\"res://build_stamp.cfg\")"
	exporting.actions.append(stamp)
	sheet.events.append(exporting)
	return sheet


## A PLATFORMER starter: ui_left/ui_right run, ui_accept jumps. The classic first sheet.
static func _build_platformer_starter() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "CharacterBody2D"
	var note: CommentRow = CommentRow.new()
	note.text = "[b]Platformer Starter[/b] - move with ui_left/ui_right, jump with ui_accept.\nTune the numbers, then Compile and attach the script."
	sheet.events.append(note)
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnPhysicsProcess"
	var move: RawCodeRow = RawCodeRow.new()
	move.code = "velocity.x = Input.get_axis(&\"ui_left\", &\"ui_right\") * 220.0\nif not is_on_floor():\n\tvelocity.y += 980.0 * delta\nmove_and_slide()"
	tick.actions.append(move)
	sheet.events.append(tick)
	var jump: EventRow = EventRow.new()
	jump.trigger_provider_id = "Core"
	jump.trigger_id = "OnPhysicsProcess"
	var grounded: ACECondition = ACECondition.new()
	grounded.provider_id = "Core"
	grounded.ace_id = "IsOnFloor"
	grounded.codegen_template = "is_on_floor()"
	jump.conditions.append(grounded)
	var pressed: ACECondition = ACECondition.new()
	pressed.provider_id = "Core"
	pressed.ace_id = "IsActionJustPressed"
	pressed.codegen_template = "Input.is_action_just_pressed(&{action})"
	pressed.params = {"action": "\"ui_accept\""}
	jump.conditions.append(pressed)
	var leap: ACEAction = ACEAction.new()
	leap.provider_id = "Core"
	leap.ace_id = "SetVelocity2D"
	leap.codegen_template = "velocity.y = {vel}"
	leap.params = {"vel": "-420.0"}
	jump.actions.append(leap)
	sheet.events.append(jump)
	return sheet


## A TOP-DOWN starter: 8-way movement on the arrow keys.
static func _build_topdown_starter() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "CharacterBody2D"
	var note2: CommentRow = CommentRow.new()
	note2.text = "[b]Top-down Starter[/b] - 8-way movement with the arrow keys."
	sheet.events.append(note2)
	var tick2: EventRow = EventRow.new()
	tick2.trigger_provider_id = "Core"
	tick2.trigger_id = "OnPhysicsProcess"
	var move2: RawCodeRow = RawCodeRow.new()
	move2.code = "velocity = Input.get_vector(&\"ui_left\", &\"ui_right\", &\"ui_up\", &\"ui_down\") * 200.0\nmove_and_slide()"
	tick2.actions.append(move2)
	sheet.events.append(tick2)
	return sheet


## X25. A BOOMER ARSENAL starter: fire, switch, ammo and secrets wired in one go, on the movement the
## FPS Controller behaviour already does. Deliberately no aiming-down-sights: it is a boomer shooter.
static func _build_boomer_arsenal_starter() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "CharacterBody3D"
	sheet.variables = {
		"weapons": {"type": "Array", "default": ["shotgun", "rifle", "launcher"], "exported": true,
			"attributes": {"tooltip": "The arsenal, in the order the wheel runs. Ammo is looked up by these names."}},
		"weapon_index": {"type": "int", "default": 0, "exported": false,
			"attributes": {"tooltip": "Which weapon is out, counting from 0."}},
		"ammo": {"type": "Dictionary", "default": {"shotgun": 30, "rifle": 90, "launcher": 8}, "exported": true,
			"attributes": {"tooltip": "How many rounds each weapon has left, keyed by weapon name."}},
		"secrets_found": {"type": "Array", "default": [], "exported": false,
			"attributes": {"tooltip": "Every secret counted so far. Each one goes in once."}}
	}
	var note: CommentRow = CommentRow.new()
	note.text = "[b]Boomer arsenal[/b] - fire, switch weapons, spend ammo and count secrets.\nAdd the FPS Controller behaviour for the movement, then Compile and attach the script."
	sheet.events.append(note)
	var fire: EventRow = EventRow.new()
	fire.trigger_provider_id = "Core"
	fire.trigger_id = "OnPhysicsProcess"
	var pressed: ACECondition = ACECondition.new()
	pressed.provider_id = "Core"
	pressed.ace_id = "IsActionJustPressed"
	pressed.codegen_template = "Input.is_action_just_pressed(&{action})"
	pressed.params = {"action": "\"ui_accept\""}
	fire.conditions.append(pressed)
	var has_ammo: RawCodeRow = RawCodeRow.new()
	has_ammo.code = "if int(ammo.get(weapons[weapon_index], 0)) > 0:\n\tammo[weapons[weapon_index]] = int(ammo[weapons[weapon_index]]) - 1"
	fire.actions.append(has_ammo)
	var shot: ACEAction = ACEAction.new()
	shot.provider_id = "Core"
	shot.ace_id = "FireHitscan"
	shot.codegen_template = _shipped_template("FireHitscan", "arsenal_shot")
	shot.params = {"spread": "1.5", "damage": "25", "reach": "200.0", "mask": "1"}
	fire.actions.append(shot)
	sheet.events.append(fire)
	var switching: EventRow = EventRow.new()
	switching.trigger_provider_id = "Core"
	switching.trigger_id = "OnPhysicsProcess"
	var wheeled: ACECondition = ACECondition.new()
	wheeled.provider_id = "Core"
	wheeled.ace_id = "IsActionJustPressed"
	wheeled.codegen_template = "Input.is_action_just_pressed(&{action})"
	wheeled.params = {"action": "\"ui_right\""}
	switching.conditions.append(wheeled)
	var next_weapon: ACEAction = ACEAction.new()
	next_weapon.provider_id = "Core"
	next_weapon.ace_id = "SwitchToNextWeapon"
	next_weapon.codegen_template = _shipped_template("SwitchToNextWeapon")
	next_weapon.params = {"index": "weapon_index", "weapons": "weapons"}
	switching.actions.append(next_weapon)
	sheet.events.append(switching)
	var secret: EventRow = EventRow.new()
	secret.trigger_provider_id = "Core"
	secret.trigger_id = "OnPhysicsProcess"
	var count_it: ACEAction = ACEAction.new()
	count_it.provider_id = "Core"
	count_it.ace_id = "MarkSecretFound"
	count_it.codegen_template = _shipped_template("MarkSecretFound")
	count_it.params = {"name": "\"secret\"", "found": "secrets_found"}
	secret.actions.append(count_it)
	sheet.events.append(secret)
	return sheet


## X29. A GAME OPTIONS starter: the accessibility screen every project should be an afternoon from.
## The settings are remembered between runs, the remap flow is four rows of one action each, and the
## three dials are the ones the juice, text and aim rows ask before they fire.
static func _build_game_options_starter() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Control"
	sheet.variables = {
		"effect_strength_percent": {"type": "int", "default": 100, "exported": true,
			"attributes": {"remember": true, "tooltip": "How strong shakes, kicks and flashes are, 0 to 100. Bind a slider to it.",
				"header": "Accessibility", "header_color": "#7bc96f",
				"info": "Every setting here is remembered between runs, so a player sets it once."}},
		"no_flashing": {"type": "bool", "default": false, "exported": true,
			"attributes": {"remember": true, "tooltip": "On: every flash becomes a fade, for players with photosensitive epilepsy."}},
		"text_size_scale": {"type": "float", "default": 1.0, "exported": true,
			"attributes": {"remember": true, "tooltip": "1 is the size you designed. Every text size multiplies by it."}},
		"aim_assist_radius": {"type": "float", "default": 0.0, "exported": true,
			"attributes": {"remember": true, "tooltip": "How far from dead centre a target still counts. 0 is no help."}},
		"hold_is_toggle": {"type": "bool", "default": false, "exported": true,
			"attributes": {"remember": true, "tooltip": "On: a held control (aim, crouch, sprint) is pressed once on and once off instead."}},
		"listening_for": {"type": "String", "default": "", "exported": false,
			"attributes": {"tooltip": "Which control is being rebound right now, \"\" when none."}}
	}
	var note: CommentRow = CommentRow.new()
	note.text = "[b]Game Options[/b] - the accessibility screen: remapping, effect strength, no flashing, text size and aim help.\nBind each setting to a slider or a checkbox, then apply it with the row under Apply."
	sheet.events.append(note)
	var applying: EventRow = EventRow.new()
	applying.trigger_provider_id = "Core"
	applying.trigger_id = "OnReady"
	for row: Dictionary in [
		{"ace": "SetEffectStrength", "params": {"percent": "effect_strength_percent"}},
		{"ace": "SetNoFlashing", "params": {"on": "no_flashing"}},
		{"ace": "SetTextSizeScale", "params": {"scale": "text_size_scale"}},
		{"ace": "SetAimAssistRadius", "params": {"radius": "aim_assist_radius"}}
	]:
		var setting: ACEAction = ACEAction.new()
		setting.provider_id = "Core"
		setting.ace_id = str(row["ace"])
		setting.codegen_template = _shipped_template(str(row["ace"]), "options_%s" % str(row["ace"]).to_snake_case())
		setting.params = (row["params"] as Dictionary).duplicate()
		applying.actions.append(setting)
	var load_them: ACEAction = ACEAction.new()
	load_them.provider_id = "Core"
	load_them.ace_id = "InputLoadBindings"
	load_them.codegen_template = _shipped_template("InputLoadBindings", "options_load")
	load_them.params = {"path": "\"user://bindings.cfg\""}
	applying.actions.append(load_them)
	sheet.events.append(applying)
	var listening: EventRow = EventRow.new()
	listening.trigger_provider_id = "Core"
	listening.trigger_id = "OnUnhandledInput"
	var received: ACECondition = ACECondition.new()
	received.provider_id = "Core"
	received.ace_id = "AnyInputReceived"
	received.codegen_template = _shipped_template("AnyInputReceived")
	received.params = {"listening": "listening_for"}
	listening.conditions.append(received)
	var rebind: ACEAction = ACEAction.new()
	rebind.provider_id = "Core"
	rebind.ace_id = "RebindControlTo"
	rebind.codegen_template = _shipped_template("RebindControlTo")
	rebind.params = {"action": "listening_for", "event": "event"}
	listening.actions.append(rebind)
	var save_them: ACEAction = ACEAction.new()
	save_them.provider_id = "Core"
	save_them.ace_id = "InputSaveBindings"
	save_them.codegen_template = _shipped_template("InputSaveBindings", "options_save")
	save_them.params = {"path": "\"user://bindings.cfg\""}
	listening.actions.append(save_them)
	var stop: ACEAction = ACEAction.new()
	stop.provider_id = "Core"
	stop.ace_id = "StopListeningForControl"
	stop.codegen_template = _shipped_template("StopListeningForControl")
	stop.params = {"listening": "listening_for"}
	listening.actions.append(stop)
	sheet.events.append(listening)
	return sheet


## The template a shipped ACE writes, taken from the registry rather than re-typed here: a starter
## that spelled a template by hand would drift the moment the vocabulary gained an optional slot,
## and a starter is the first thing a newcomer compiles.
##
## `{uid}` is baked HERE, with a stable id per row. The dock bakes it when a reader drops a row and
## the compiler never does, so a starter that handed its rows over unbaked would ship `var __cam_{uid}`
## straight into the emitted GDScript - which does not parse.
static func _shipped_template(ace_id: String, row_uid: String = "") -> String:
	for descriptor: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		if str(descriptor.ace_id) == ace_id:
			return str(descriptor.codegen_template).replace("{uid}", row_uid)
	return ""


## Returns a fresh starter sheet for a template id - the ONE source of truth shared by the
## New-Sheet menu (below) and the FileSystem "Create New > Event Sheet" dialog. Only the
## dock-free starters live here (Blank + 2D movement + the three data-asset intents); the
## New-Sheet menu keeps the autoload/3D cases inline since it also adopts them into the dock.
static func build_starter(template_id: int) -> EventSheetResource:
	# Extension starters (EventSheets.register_starter) occupy ids 1000+ in registration order.
	if template_id >= 1000:
		var registered: Array[Dictionary] = EventSheets.registered_starters()
		var starter_index: int = template_id - 1000
		if starter_index < registered.size():
			var build: Callable = registered[starter_index].get("build", Callable())
			var built: Variant = build.call() if build.is_valid() else null
			if built is EventSheetResource:
				return built
		return EventSheetResource.new()
	match template_id:
		1: return _build_platformer_starter()
		2: return _build_topdown_starter()
		8: return _build_behavior_component_starter()
		9: return _build_custom_resource_starter()
		10: return _build_editor_tool_starter()
		11: return _build_system_starter()
		12: return _build_editor_plugin_starter()
		13: return _build_import_tool_starter()
		14: return _build_export_hook_starter()
		15: return _build_boomer_arsenal_starter()
		16: return _build_game_options_starter()
		_: return EventSheetResource.new()  # 0 Blank (and any other id) -> a minimal editable sheet


## The starters the FileSystem "Create New > Event Sheet" dialog offers, as {id, label} in menu
## order. A curated, dock-free subset of the New-Sheet menu (autoloads + 3D controllers are
## project-wide/niche and stay in the in-workspace New menu).
static func create_new_starters() -> Array[Dictionary]:
	var starters: Array[Dictionary] = [
		{"id": 0, "label": "Blank Sheet"},
		{"id": 1, "label": "Platformer Starter"},
		{"id": 2, "label": "Top-down Starter"},
		{"id": 8, "label": "Behavior Component"},
		{"id": 9, "label": "Custom Resource"},
		{"id": 10, "label": "Editor Tool"},
		{"id": 12, "label": "Editor Plugin"},
		{"id": 13, "label": "Import Tool"},
		{"id": 14, "label": "Export Hook"},
	]
	# Extension starters (EventSheets.register_starter) append after the built-ins, ids 1000+.
	var registered: Array[Dictionary] = EventSheets.registered_starters()
	for starter_index: int in range(registered.size()):
		starters.append({"id": 1000 + starter_index, "label": str(registered[starter_index].get("label", ""))})
	return starters


## Builds a fresh sheet from a starter template and adopts it (unsaved; Save As to keep).
func _new_sheet_from_template(template_id: int) -> void:
	# T13 - a project that started from a template is one of the two ways a reader says "give me the
	# familiar surfaces" without being asked, so the Project bar turns itself on for it.
	EventSheetProjectBarGlue.mark_started_from_template()
	if template_id >= 100:
		var template_index: int = template_id - 100
		if template_index >= _project_template_paths.size():
			return
		var template_copy: EventSheetResource = EventSheetTemplates.load_copy(_project_template_paths[template_index])
		if template_copy == null:
			_dock._set_status("Couldn't load that template.", true)
			return
		_dock.setup(template_copy)
		_dock._current_sheet_path = ""
		_dock._dirty = true
		_dock._refresh_title_strip()
		_dock._clear_undo_history()
		_dock._set_status("New sheet from project template - Save As… to keep it.")
		return
	var sheet: EventSheetResource = EventSheetResource.new()
	match template_id:
		1:
			sheet = _build_platformer_starter()
		2:
			sheet = _build_topdown_starter()
		8:
			sheet = _build_behavior_component_starter()
		9:
			sheet = _build_custom_resource_starter()
		10:
			sheet = _build_editor_tool_starter()
		11:
			sheet = _build_system_starter()
		12:
			sheet = _build_editor_plugin_starter()
		13:
			sheet = _build_import_tool_starter()
		14:
			sheet = _build_export_hook_starter()
		15:
			sheet = _build_boomer_arsenal_starter()
		16:
			sheet = _build_game_options_starter()
		6:
			sheet.host_class = "CharacterBody3D"
			var note6: CommentRow = CommentRow.new()
			note6.text = "[b]First-Person Controller (3D)[/b] - WASD/arrows to move (relative to a child Camera3D's facing), Space to jump.\nAdd a Camera3D child named \"Camera3D\", then Compile and attach the script."
			sheet.events.append(note6)
			var tick6: EventRow = EventRow.new()
			tick6.trigger_provider_id = "Core"
			tick6.trigger_id = "OnPhysicsProcess"
			var move6: RawCodeRow = RawCodeRow.new()
			move6.code = "\n".join(PackedStringArray([
				"var input_2d := Input.get_vector(&\"ui_left\", &\"ui_right\", &\"ui_up\", &\"ui_down\")",
				"var basis_node: Node3D = get_node_or_null(\"Camera3D\")",
				"var dir_basis := basis_node.global_transform.basis if basis_node != null else global_transform.basis",
				"var move_vec := dir_basis * Vector3(input_2d.x, 0.0, input_2d.y)",
				"move_vec.y = 0.0  # project onto the ground plane so look-pitch never changes speed",
				"var direction := move_vec.normalized()",
				"velocity.x = direction.x * 6.0",
				"velocity.z = direction.z * 6.0",
				"if not is_on_floor():",
				"\tvelocity.y -= 18.0 * delta",
				"elif Input.is_action_just_pressed(&\"ui_accept\"):",
				"\tvelocity.y = 7.0",
				"move_and_slide()"
			]))
			tick6.actions.append(move6)
			sheet.events.append(tick6)
		7:
			sheet.host_class = "CharacterBody3D"
			var note7: CommentRow = CommentRow.new()
			note7.text = "[b]Third-Person Mover (3D)[/b] - WASD/arrows move on the ground plane and the body turns to face its motion. Space jumps."
			sheet.events.append(note7)
			var tick7: EventRow = EventRow.new()
			tick7.trigger_provider_id = "Core"
			tick7.trigger_id = "OnPhysicsProcess"
			var move7: RawCodeRow = RawCodeRow.new()
			move7.code = "\n".join(PackedStringArray([
				"var input_2d := Input.get_vector(&\"ui_left\", &\"ui_right\", &\"ui_up\", &\"ui_down\")",
				"var direction := Vector3(input_2d.x, 0.0, input_2d.y)",
				"velocity.x = direction.x * 6.0",
				"velocity.z = direction.z * 6.0",
				"if direction.length() > 0.1:",
				"\trotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), delta * 10.0)",
				"if not is_on_floor():",
				"\tvelocity.y -= 18.0 * delta",
				"elif Input.is_action_just_pressed(&\"ui_accept\"):",
				"\tvelocity.y = 7.0",
				"move_and_slide()"
			]))
			tick7.actions.append(move7)
			sheet.events.append(tick7)
		3:
			sheet.autoload_mode = true
			sheet.autoload_name = "GameState"
			sheet.host_class = "Node"
			sheet.variables = {
				"score": {"type": "int", "default": 0, "exported": true, "attributes": {"tooltip": "Current score."}},
				"lives": {"type": "int", "default": 3, "exported": true, "attributes": {"range": {"min": "0", "max": "99", "step": "1"}}}
			}
			var score_signal: RawCodeRow = RawCodeRow.new()
			score_signal.code = "## @ace_trigger\n## @ace_name(\"On Score Changed\")\n## @ace_category(\"Game State\")\nsignal score_changed(new_score: int)"
			sheet.events.append(score_signal)
			var add_score: EventFunction = EventFunction.new()
			add_score.function_name = "add_score"
			add_score.expose_as_ace = true
			add_score.ace_display_name = "Add Score"
			add_score.ace_category = "Game State"
			var amount_param: ACEParam = ACEParam.new()
			amount_param.id = "amount"
			amount_param.type_name = "int"
			add_score.params.append(amount_param)
			var add_body: RawCodeRow = RawCodeRow.new()
			add_body.code = "score += amount\nscore_changed.emit(score)"
			add_score.events.append(add_body)
			sheet.functions.append(add_score)
		4:
			sheet.autoload_mode = true
			sheet.autoload_name = "EventBus"
			sheet.host_class = "Node"
			var bus_note: CommentRow = CommentRow.new()
			bus_note.text = "[b]Event Bus[/b] - declare project-wide signals here; emit them from any sheet via EventBus.<signal>.emit(...)."
			sheet.events.append(bus_note)
			var bus_signals: RawCodeRow = RawCodeRow.new()
			bus_signals.code = "## @ace_trigger\n## @ace_name(\"On Game Paused\")\n## @ace_category(\"Event Bus\")\nsignal game_paused\n\n## @ace_trigger\n## @ace_name(\"On Level Completed\")\n## @ace_category(\"Event Bus\")\nsignal level_completed(level: int)"
			sheet.events.append(bus_signals)
		5:
			sheet.autoload_mode = true
			sheet.autoload_name = "SaveSystem"
			sheet.host_class = "Node"
			sheet.variables = {"save_path": {"type": "String", "default": "user://save.cfg", "exported": true, "attributes": {"tooltip": "Where the save file lives."}}}
			var save_fn: EventFunction = EventFunction.new()
			save_fn.function_name = "save_number"
			save_fn.expose_as_ace = true
			save_fn.ace_display_name = "Save Number"
			save_fn.ace_category = "Save System"
			for save_param_pair in [["key", "String"], ["value", "float"]]:
				var save_param: ACEParam = ACEParam.new()
				save_param.id = str(save_param_pair[0])
				save_param.type_name = str(save_param_pair[1])
				save_fn.params.append(save_param)
			var save_body: RawCodeRow = RawCodeRow.new()
			save_body.code = "var config: ConfigFile = ConfigFile.new()\nconfig.load(save_path)\nconfig.set_value(\"save\", key, value)\nconfig.save(save_path)"
			save_fn.events.append(save_body)
			sheet.functions.append(save_fn)
			var load_fn: EventFunction = EventFunction.new()
			load_fn.function_name = "load_number"
			load_fn.expose_as_ace = true
			load_fn.ace_display_name = "Load Number"
			load_fn.ace_category = "Save System"
			load_fn.return_type = TYPE_FLOAT
			var load_param: ACEParam = ACEParam.new()
			load_param.id = "key"
			load_param.type_name = "String"
			load_fn.params.append(load_param)
			var load_body: RawCodeRow = RawCodeRow.new()
			load_body.code = "var config: ConfigFile = ConfigFile.new()\nconfig.load(save_path)\nreturn float(config.get_value(\"save\", key, 0.0))"
			load_fn.events.append(load_body)
			sheet.functions.append(load_fn)
	_dock.setup(sheet)
	_dock._current_sheet_path = ""
	_dock._dirty = true
	_dock._refresh_title_strip()
	_dock._clear_undo_history()
	_dock._set_status("New sheet from template - Save As… to keep it.")
