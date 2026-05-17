@tool
class_name EventSheetDock
extends Control

var _scroll: ScrollContainer = null
var _viewport: EventSheetViewport = null
var _current_sheet: EventSheetResource = null
var _ace_registry: EventSheetACERegistry = EventSheetACERegistry.new()
var _ace_sources: Array[Object] = []

func _init() -> void:
    _build_ui()

func _ready() -> void:
    _build_ui()
    _refresh_ace_registry()
    if _viewport != null and _current_sheet == null:
        _viewport.set_sheet(_build_demo_sheet())
        _viewport.set_debug_overlay_states({
            "demo_overlap": "hit",
            "demo_attack": "step"
        })

func setup(sheet: EventSheetResource = null) -> void:
    _current_sheet = sheet
    _build_ui()
    _refresh_ace_registry()
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

func get_ace_registry() -> EventSheetACERegistry:
    return _ace_registry

func set_auto_ace_sources(sources: Array[Object]) -> void:
    _release_ace_sources()
    _ace_sources = sources.duplicate()
    _refresh_ace_registry()
    if _current_sheet == null and _viewport != null:
        _viewport.set_sheet(_build_demo_sheet())

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
    _viewport.set_ace_registry(_ace_registry)

func _build_demo_sheet() -> EventSheetResource:
    var sheet := EventSheetResource.new()
    sheet.host_class = "CharacterBody2D"
    sheet.variables["health"] = {"type": "int", "default": 100}
    sheet.variables["score"] = {"type": "int", "default": 0}

    var intro_comment := CommentRow.new()
    intro_comment.text = "Gameplay vocabulary is reflected from scripts and rendered as semantic rows."
    sheet.events.append(intro_comment)

    var encounter_group := EventGroup.new()
    encounter_group.name = _get_demo_provider_id()
    encounter_group.group_name = encounter_group.name

    var overlap_event := EventRow.new()
    overlap_event.event_uid = "demo_overlap"
    overlap_event.trigger = _make_condition(_get_demo_provider_id(), "signal:died", {})
    overlap_event.conditions = [
        _make_condition(_get_demo_provider_id(), "method:is_dead", {})
    ]
    overlap_event.actions = [
        _make_action(_get_demo_provider_id(), "set:health", {"value": "100"}),
        _make_action(_get_demo_provider_id(), "method:heal", {"amount": "25"})
    ]
    overlap_event.comment = "Auto-generated gameplay vocabulary"

    var child_event := EventRow.new()
    child_event.event_uid = "demo_attack"
    child_event.conditions = [_make_condition("Core", "Always", {})]
    child_event.actions = [_make_action(_get_demo_provider_id(), "method:take_damage", {"amount": "10"})]
    overlap_event.sub_events.append(child_event)

    encounter_group.events.append(overlap_event)
    sheet.events.append(encounter_group)

    var movement_event := EventRow.new()
    movement_event.event_uid = "demo_movement"
    movement_event.trigger = _make_condition("Core", "OnProcess", {})
    movement_event.actions = [
        _make_action(_get_demo_provider_id(), "add:health", {"amount": "5"}),
        _make_action(_get_demo_provider_id(), "method:jump", {})
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

func _refresh_ace_registry() -> void:
    if _ace_registry == null:
        _ace_registry = EventSheetACERegistry.new()
    var sources: Array[Object] = _ace_sources.duplicate()
    if sources.is_empty():
        _release_ace_sources()
        sources = _build_default_ace_sources()
        _ace_sources = sources.duplicate()
    _ace_registry.refresh_from_sources(sources, true)
    if _viewport != null:
        _viewport.set_ace_registry(_ace_registry)

func _build_default_ace_sources() -> Array[Object]:
    var demo_script: Script = load("res://addons/eventsheet/runtime/demo_gameplay_actor.gd")
    if demo_script == null or not demo_script.can_instantiate():
        return []
    var demo_source: Variant = demo_script.new()
    if demo_source is Object:
        return [demo_source]
    return []

func _get_demo_provider_id() -> String:
    if _ace_registry != null:
        var reflected_providers: PackedStringArray = _ace_registry.get_reflected_provider_ids()
        if not reflected_providers.is_empty():
            return reflected_providers[0]
    return "Core"

func _notification(what: int) -> void:
    if what == NOTIFICATION_PREDELETE:
        _release_ace_sources()

func _release_ace_sources() -> void:
    for source_object in _ace_sources:
        if source_object is Node:
            (source_object as Node).free()
    _ace_sources.clear()
