# EventForge - render harness (dev tool) for the second pattern wave: a sheet using the new
# verbs (Timeline block, Every X To Y Seconds, Move Toward (smooth), Turn Toward, Wrap, Bob,
# Is Within Distance, Toggle). Run NON-headless:
#   godot --path . --script tools/render_pattern_verbs_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _viewport: EventSheetViewport = null


func _init() -> void:
	root.title = "Pattern Verbs"
	root.size = Vector2i(1100, 560)
	var modern_base := Color("#252525")
	var background: ColorRect = ColorRect.new()
	background.color = modern_base.darkened(0.25)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.position = Vector2(8, 8)
	scroll.size = Vector2(1084, 544)
	root.add_child(scroll)
	_viewport = EventSheetViewport.new()
	_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport.set_ace_registry(EventSheetACERegistry.new())
	scroll.add_child(_viewport)

	var sheet: EventSheetResource = EventSheetResource.new()

	var intro: EventRow = EventRow.new()
	intro.trigger_id = "OnReady"
	intro.trigger_provider_id = "Core"
	intro.actions.append(EventSheets.timeline([
		[0.0, "show_message(\"Ready...\")"],
		[1.0, "show_message(\"GO!\")"],
		[1.2, "start_round()"],
	]))
	sheet.events.append(intro)

	var spawner: EventRow = EventRow.new()
	spawner.trigger_id = "OnProcess"
	spawner.trigger_provider_id = "Core"
	spawner.conditions.append(_cond("EveryRandomSeconds", {"min_seconds": "2.0", "max_seconds": "5.0"}))
	spawner.actions.append(_act("ToggleVar", {"var_name": "spotlight_on"}))
	sheet.events.append(spawner)

	var motion: EventRow = EventRow.new()
	motion.trigger_id = "OnProcess"
	motion.trigger_provider_id = "Core"
	motion.actions.append(_act("SmoothMoveToward", {"var_name": "zoom", "target": "target_zoom", "speed": "8.0"}))
	motion.actions.append(_act("TurnToward", {"target": "get_parent()", "degrees_per_second": "180.0"}))
	motion.actions.append(_act("WrapInsideScreen", {}))
	motion.actions.append(_act("BobUpAndDown", {"height": "6.0", "period": "2.0"}))
	sheet.events.append(motion)

	var near: EventRow = EventRow.new()
	near.trigger_id = "OnProcess"
	near.trigger_provider_id = "Core"
	near.conditions.append(_cond("IsNodeWithinDistance", {"other": "get_parent()", "distance": "64.0", "target": ""}))
	near.actions.append(_act("SetVar", {"var_name": "prompt_text", "value": "\"E - open\""}))
	sheet.events.append(near)

	var modern_style := EventSheetEditorStyle.new()
	modern_style.ensure_defaults()
	EventSheetGodotTheme.apply(modern_style, modern_base, modern_base.darkened(0.15), modern_base.darkened(0.25), Color("#569eff"), Color("#ced0d2"))
	sheet.editor_style = modern_style
	_viewport.set_sheet(sheet)
	process_frame.connect(_on_frame)


static func _cond(ace_id: String, params: Dictionary) -> ACECondition:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = ace_id
	condition.params = params
	return condition


static func _act(ace_id: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	return action


func _on_frame() -> void:
	_frames += 1
	if _frames < 8:
		return
	root.get_texture().get_image().save_png("res://docs/images/pattern-verbs.png")
	print("[preview] pattern verbs saved")
	quit(0)
