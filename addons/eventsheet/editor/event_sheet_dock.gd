@tool
class_name EventSheetDock
extends Control

var _scroll: ScrollContainer = null
var _viewport: EventSheetViewport = null
var _current_sheet: EventSheetResource = null

func _init() -> void:
    _build_ui()

func _ready() -> void:
    _build_ui()
    if _viewport != null and _current_sheet == null:
        _viewport.set_sheet(_build_demo_sheet())
        _viewport.set_debug_overlay_states({
            "demo_overlap": "hit",
            "demo_attack": "step"
        })

func setup(sheet: EventSheetResource = null) -> void:
    _current_sheet = sheet
    _build_ui()
    if _viewport == null:
        return
    if _current_sheet == null:
        _viewport.set_debug_overlay_states({
            "demo_overlap": "hit",
            "demo_attack": "step"
        })
        _viewport.set_sheet(_build_demo_sheet())
    else:
        _viewport.set_debug_overlay_states({})
        _viewport.set_sheet(_current_sheet)

func get_viewport_control() -> EventSheetViewport:
    return _viewport

func _build_ui() -> void:
    if _scroll != null:
        return
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    size_flags_vertical = Control.SIZE_EXPAND_FILL
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _scroll = ScrollContainer.new()
    _scroll.name = "EventSheetScroll"
    _scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    _scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    add_child(_scroll)
    _viewport = EventSheetViewport.new()
    _viewport.name = "EventSheetViewport"
    _viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _scroll.add_child(_viewport)

func _build_demo_sheet() -> EventSheetResource:
    var sheet := EventSheetResource.new()
    sheet.host_class = "CharacterBody2D"
    sheet.variables["health"] = {"type": "int", "default": 100}
    sheet.variables["score"] = {"type": "int", "default": 0}

    var intro_comment := CommentRow.new()
    intro_comment.text = "Gameplay rules read top-to-bottom like code."
    sheet.events.append(intro_comment)

    var encounter_group := EventGroup.new()
    encounter_group.name = "Enemy encounters"
    encounter_group.group_name = encounter_group.name

    var overlap_event := EventRow.new()
    overlap_event.event_uid = "demo_overlap"
    overlap_event.trigger = _make_condition("Core", "OnBodyEntered", {"body": "Enemy"})
    overlap_event.conditions = [
        _make_condition("Core", "CompareVar", {"var_name": "health", "op": ">", "value": "0"})
    ]
    overlap_event.actions = [
        _make_action("Core", "SetVar", {"var_name": "health", "value": "health - 1"}),
        _make_action("Core", "PrintLog", {"message": '"Ouch"'})
    ]
    overlap_event.comment = "Damage feedback"

    var child_event := EventRow.new()
    child_event.event_uid = "demo_attack"
    child_event.conditions = [_make_condition("Core", "Always", {})]
    child_event.actions = [_make_action("Core", "AddVar", {"var_name": "score", "amount": "10"})]
    overlap_event.sub_events.append(child_event)

    encounter_group.events.append(overlap_event)
    sheet.events.append(encounter_group)

    var movement_event := EventRow.new()
    movement_event.event_uid = "demo_movement"
    movement_event.trigger = _make_condition("Core", "OnProcess", {})
    movement_event.actions = [
        _make_action("Core", "SetVelocity2D", {"vel": "Vector2(240, velocity.y)"}),
        _make_action("Core", "MoveAndSlide", {})
    ]
    sheet.events.append(movement_event)

    return sheet

func _make_condition(provider_id: String, ace_id: String, params: Dictionary) -> ACECondition:
    var condition := ACECondition.new()
    condition.provider_id = provider_id
    condition.ace_id = ace_id
    condition.params = params.duplicate(true)
    return condition

func _make_action(provider_id: String, ace_id: String, params: Dictionary) -> ACEAction:
    var action := ACEAction.new()
    action.provider_id = provider_id
    action.ace_id = ace_id
    action.params = params.duplicate(true)
    return action
