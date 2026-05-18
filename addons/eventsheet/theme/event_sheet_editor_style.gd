@tool
class_name EventSheetEditorStyle
extends Resource

const DEFAULT_EVENT_VISUAL_SCENE: PackedScene = preload("res://addons/eventsheet/elements/event_visual_element.tscn")
const DEFAULT_CONDITION_VISUAL_SCENE: PackedScene = preload("res://addons/eventsheet/elements/condition_visual_element.tscn")
const DEFAULT_ACTION_VISUAL_SCENE: PackedScene = preload("res://addons/eventsheet/elements/action_visual_element.tscn")
const DEFAULT_THEME_LAYOUT_VISUAL_SCENE: PackedScene = preload("res://addons/eventsheet/elements/theme_layout_visual_editor.tscn")

@export var event_style: EventSheetEventStyle
@export var condition_style: EventSheetElementStyle
@export var action_style: EventSheetElementStyle
@export var use_visual_layout_scene: bool = false
@export var theme_layout_visual_scene: PackedScene = DEFAULT_THEME_LAYOUT_VISUAL_SCENE
@export var event_visual_scene: PackedScene = DEFAULT_EVENT_VISUAL_SCENE
@export var condition_visual_scene: PackedScene = DEFAULT_CONDITION_VISUAL_SCENE
@export var action_visual_scene: PackedScene = DEFAULT_ACTION_VISUAL_SCENE

var _visual_templates_seeded: bool = false
var _last_use_visual_layout_scene: bool = false
var _last_theme_layout_visual_scene: PackedScene = null
var _last_event_visual_scene: PackedScene = null
var _last_condition_visual_scene: PackedScene = null
var _last_action_visual_scene: PackedScene = null

func _init() -> void:
	ensure_defaults()

func ensure_defaults() -> void:
	if theme_layout_visual_scene == null:
		theme_layout_visual_scene = DEFAULT_THEME_LAYOUT_VISUAL_SCENE
	if event_visual_scene == null:
		event_visual_scene = DEFAULT_EVENT_VISUAL_SCENE
	if condition_visual_scene == null:
		condition_visual_scene = DEFAULT_CONDITION_VISUAL_SCENE
	if action_visual_scene == null:
		action_visual_scene = DEFAULT_ACTION_VISUAL_SCENE
	var layout_scene_changed: bool = _last_theme_layout_visual_scene != theme_layout_visual_scene or _last_use_visual_layout_scene != use_visual_layout_scene
	if not _visual_templates_seeded:
		_visual_templates_seeded = true
		if use_visual_layout_scene:
			_apply_style_parts_from_layout_scene(theme_layout_visual_scene)
		else:
			if event_style == null:
				event_style = _build_event_style_from_scene(event_visual_scene)
			if condition_style == null:
				condition_style = _build_element_style_from_scene(condition_visual_scene)
			if action_style == null:
				action_style = _build_element_style_from_scene(action_visual_scene)
		_last_use_visual_layout_scene = use_visual_layout_scene
		_last_theme_layout_visual_scene = theme_layout_visual_scene
		_last_event_visual_scene = event_visual_scene
		_last_condition_visual_scene = condition_visual_scene
		_last_action_visual_scene = action_visual_scene
	elif use_visual_layout_scene and layout_scene_changed:
		_apply_style_parts_from_layout_scene(theme_layout_visual_scene)
		_last_use_visual_layout_scene = use_visual_layout_scene
		_last_theme_layout_visual_scene = theme_layout_visual_scene
	if not use_visual_layout_scene:
		if _last_event_visual_scene != event_visual_scene:
			_last_event_visual_scene = event_visual_scene
			var rebuilt_event_style: EventSheetEventStyle = _build_event_style_from_scene(event_visual_scene)
			if rebuilt_event_style != null:
				event_style = rebuilt_event_style
		if _last_condition_visual_scene != condition_visual_scene:
			_last_condition_visual_scene = condition_visual_scene
			var rebuilt_condition_style: EventSheetElementStyle = _build_element_style_from_scene(condition_visual_scene)
			if rebuilt_condition_style != null:
				condition_style = rebuilt_condition_style
		if _last_action_visual_scene != action_visual_scene:
			_last_action_visual_scene = action_visual_scene
			var rebuilt_action_style: EventSheetElementStyle = _build_element_style_from_scene(action_visual_scene)
			if rebuilt_action_style != null:
				action_style = rebuilt_action_style
	if not use_visual_layout_scene:
		_last_use_visual_layout_scene = use_visual_layout_scene
		_last_theme_layout_visual_scene = theme_layout_visual_scene
	if event_style == null:
		event_style = EventSheetEventStyle.new()
	if condition_style == null:
		condition_style = EventSheetElementStyle.new()
		condition_style.text_color = Color(0.78, 0.88, 1.00, 1.0)
		condition_style.chip_background_color = Color(0.30, 0.56, 0.82, 0.14)
		condition_style.chip_border_color = Color(0.40, 0.67, 0.92, 0.38)
		condition_style.chip_hover_color = Color(0.36, 0.60, 0.92, 0.24)
		condition_style.badge_background_color = Color(0.26, 0.29, 0.36, 0.95)
		condition_style.badge_foreground_color = Color(0.82, 0.87, 0.95, 1.0)
		condition_style.gap_after = 8
		condition_style.corner_radius = 5
	if action_style == null:
		action_style = EventSheetElementStyle.new()
		action_style.text_color = Color(0.68, 0.92, 0.78, 1.0)
		action_style.chip_background_color = Color(0.25, 0.66, 0.56, 0.12)
		action_style.chip_border_color = Color(0.40, 0.78, 0.64, 0.34)
		action_style.chip_hover_color = Color(0.28, 0.72, 0.58, 0.20)
		action_style.badge_background_color = EventSheetPalette.COLOR_LANE_DIVIDER
		action_style.badge_foreground_color = EventSheetPalette.TEXT_PRIMARY
		action_style.gap_after = 8
		action_style.corner_radius = 5

func get_event_style() -> EventSheetEventStyle:
	ensure_defaults()
	return event_style

func get_condition_style() -> EventSheetElementStyle:
	ensure_defaults()
	return condition_style

func get_action_style() -> EventSheetElementStyle:
	ensure_defaults()
	return action_style

func _build_event_style_from_scene(scene: PackedScene) -> EventSheetEventStyle:
	var template: Node = _instantiate_visual_template(scene)
	if template == null:
		return null
	var built_style: Variant = template.call("build_event_style") if template.has_method("build_event_style") else null
	template.free()
	if built_style is EventSheetEventStyle:
		return built_style as EventSheetEventStyle
	return null

func _build_element_style_from_scene(scene: PackedScene) -> EventSheetElementStyle:
	var template: Node = _instantiate_visual_template(scene)
	if template == null:
		return null
	var built_style: Variant = template.call("build_element_style") if template.has_method("build_element_style") else null
	template.free()
	if built_style is EventSheetElementStyle:
		return built_style as EventSheetElementStyle
	return null

func _apply_style_parts_from_layout_scene(scene: PackedScene) -> void:
	var template: Node = _instantiate_visual_template(scene)
	if template == null:
		return
	var built_parts: Variant = template.call("build_editor_style_parts") if template.has_method("build_editor_style_parts") else null
	if built_parts is Dictionary:
		var parts: Dictionary = built_parts as Dictionary
		var built_event_style: Variant = parts.get("event_style", null)
		var built_condition_style: Variant = parts.get("condition_style", null)
		var built_action_style: Variant = parts.get("action_style", null)
		if built_event_style is EventSheetEventStyle:
			event_style = built_event_style as EventSheetEventStyle
		if built_condition_style is EventSheetElementStyle:
			condition_style = built_condition_style as EventSheetElementStyle
		if built_action_style is EventSheetElementStyle:
			action_style = built_action_style as EventSheetElementStyle
	else:
		if template.has_method("build_event_style"):
			var built_event: Variant = template.call("build_event_style")
			if built_event is EventSheetEventStyle:
				event_style = built_event as EventSheetEventStyle
		if template.has_method("build_condition_style"):
			var built_condition: Variant = template.call("build_condition_style")
			if built_condition is EventSheetElementStyle:
				condition_style = built_condition as EventSheetElementStyle
		if template.has_method("build_action_style"):
			var built_action: Variant = template.call("build_action_style")
			if built_action is EventSheetElementStyle:
				action_style = built_action as EventSheetElementStyle
	template.free()

func _instantiate_visual_template(scene: PackedScene) -> Node:
	if scene == null:
		return null
	return scene.instantiate()
