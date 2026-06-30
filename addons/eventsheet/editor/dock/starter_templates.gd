@tool
extends RefCounted
class_name EventSheetStarterTemplates

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
## appear the moment a .tres lands in the folder — same zero-config convention as
## eventsheet_addons/.
var _project_template_paths: PackedStringArray = PackedStringArray()

func _build_template_menu_items() -> void:
    if _template_menu == null:
        _template_menu = PopupMenu.new()
        _template_menu.id_pressed.connect(_new_sheet_from_template)
        _dock.add_child(_template_menu)
    _template_menu.clear()
    _template_menu.add_item("Blank Sheet", 0)
    _template_menu.add_item("Platformer Starter", 1)
    _template_menu.add_item("Top-down Starter", 2)
    _template_menu.add_item("Behavior Component (signal-driven)", 8)
    _template_menu.add_item("First-Person Controller (3D)", 6)
    _template_menu.add_item("Third-Person Mover (3D)", 7)
    _template_menu.add_item("Game State (Autoload)", 3)
    _template_menu.add_item("Event Bus (Autoload)", 4)
    _template_menu.add_item("Save System (Autoload)", 5)
    _project_template_paths = EventSheetTemplates.list_templates()
    if not _project_template_paths.is_empty():
        _template_menu.add_separator("Project templates")
        for index in _project_template_paths.size():
            _template_menu.add_item(_project_template_paths[index].get_file().get_basename().capitalize(), 100 + index)

## A signal-driven BEHAVIOR COMPONENT starter — the Godot composition idiom modelled by example, so a
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
    about.text = "[b]Behavior Component[/b] — Godot's answer to a node-attached behavior. Instead of one big sheet on the root, this is a small reusable piece you ATTACH as a child of the node it controls (here, an Area2D pickup); it compiles to a Node, and [code]host[/code] is the node it is attached to.\nIt REACTS to a signal (the host's body_entered) instead of checking every frame, and EMITS its own (On Collected) so other sheets stay decoupled. [code]value[/code] is a designer knob in the Inspector."
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

## Builds a fresh sheet from a starter template and adopts it (unsaved; Save As to keep).
func _new_sheet_from_template(template_id: int) -> void:
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
        _dock._set_status("New sheet from project template — Save As… to keep it.")
        return
    var sheet: EventSheetResource = EventSheetResource.new()
    match template_id:
        1:
            sheet.host_class = "CharacterBody2D"
            var note: CommentRow = CommentRow.new()
            note.text = "[b]Platformer Starter[/b] — move with ui_left/ui_right, jump with ui_accept.\nTune the numbers, then Compile and attach the script."
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
        2:
            sheet.host_class = "CharacterBody2D"
            var note2: CommentRow = CommentRow.new()
            note2.text = "[b]Top-down Starter[/b] — 8-way movement with the arrow keys."
            sheet.events.append(note2)
            var tick2: EventRow = EventRow.new()
            tick2.trigger_provider_id = "Core"
            tick2.trigger_id = "OnPhysicsProcess"
            var move2: RawCodeRow = RawCodeRow.new()
            move2.code = "velocity = Input.get_vector(&\"ui_left\", &\"ui_right\", &\"ui_up\", &\"ui_down\") * 200.0\nmove_and_slide()"
            tick2.actions.append(move2)
            sheet.events.append(tick2)
        8:
            sheet = _build_behavior_component_starter()
        6:
            sheet.host_class = "CharacterBody3D"
            var note6: CommentRow = CommentRow.new()
            note6.text = "[b]First-Person Controller (3D)[/b] — WASD/arrows to move (relative to a child Camera3D's facing), Space to jump.\nAdd a Camera3D child named \"Camera3D\", then Compile and attach the script."
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
            note7.text = "[b]Third-Person Mover (3D)[/b] — WASD/arrows move on the ground plane and the body turns to face its motion. Space jumps."
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
            bus_note.text = "[b]Event Bus[/b] — declare project-wide signals here; emit them from any sheet via EventBus.<signal>.emit(...)."
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
    _dock._set_status("New sheet from template — Save As… to keep it.")
