# EventForge - render harness (dev tool) for the second pattern wave: a sheet using the new
# verbs (Timeline block, Every X To Y Seconds, Move Toward (smooth), Turn Toward, Wrap, Bob,
# Is Within Distance, Toggle). Run NON-headless:
#   godot --path . --script tools/render_pattern_verbs_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _stage: int = 0
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
	if _stage == 0:
		root.get_texture().get_image().save_png("res://docs/images/pattern-verbs.png")
		print("[preview] pattern verbs saved")
		_stage = 1
		_frames = 0
		_apply_pool_sheet()
		return
	if _stage == 1:
		root.get_texture().get_image().save_png("res://docs/images/pattern-pool.png")
		print("[preview] pattern pool saved")
		_stage = 2
		_frames = 0
		_apply_wave3_sheet()
		return
	root.get_texture().get_image().save_png("res://docs/images/pattern-wave3.png")
	print("[preview] pattern wave3 saved")
	quit(0)


## Stage 3: the third wave - buffered coyote jumping, the wave director, knockback with
## i-frames and floating text, and the per-frame motion verbs.
func _apply_wave3_sheet() -> void:
	var sheet: EventSheetResource = EventSheetResource.new()

	var press: EventRow = EventRow.new()
	press.trigger_id = "signal:jump_pressed"
	press.actions.append(_act("BufferPress", {"name": "\"jump\"", "seconds": "0.12"}))
	sheet.events.append(press)

	var jump: EventRow = EventRow.new()
	jump.trigger_id = "OnProcess"
	jump.trigger_provider_id = "Core"
	jump.conditions.append(_cond("PressIsBuffered", {"name": "\"jump\""}))
	jump.conditions.append(_cond("WasRecentlyTrue", {"value": "is_on_floor()", "window": "0.1"}))
	var jump_call: RawCodeRow = RawCodeRow.new()
	jump_call.code = "jump()"
	jump.actions.append(jump_call)
	jump.actions.append(_act("ClearBuffer", {"name": "\"jump\""}))
	sheet.events.append(jump)

	var waves: EventRow = EventRow.new()
	waves.trigger_id = "OnProcess"
	waves.trigger_provider_id = "Core"
	waves.conditions.append(_cond("OnGroupEmptied", {"group": "\"enemies\""}))
	var bump: RawCodeRow = RawCodeRow.new()
	bump.code = "wave += 1"
	waves.actions.append(bump)
	var start_wave: RawCodeRow = RawCodeRow.new()
	start_wave.code = "start_wave(wave)"
	waves.actions.append(start_wave)
	sheet.events.append(waves)

	var hurt: EventRow = EventRow.new()
	hurt.trigger_id = "signal:hurt"
	hurt.actions.append(_act("PushAwayFrom", {"source": "player", "strength": "300.0", "target": ""}))
	var iframe: ACEAction = ACEAction.new()
	iframe.provider_id = "HealthBehavior"
	iframe.ace_id = "method:grant_invincibility"
	iframe.params = {"seconds": "1.0"}
	hurt.actions.append(iframe)
	var popup: ACEAction = ACEAction.new()
	popup.provider_id = "HudKitBehavior"
	popup.ace_id = "method:pop_floating_text"
	popup.params = {"text": "\"-10\"", "at": "global_position", "color": "Color.RED"}
	hurt.actions.append(popup)
	sheet.events.append(hurt)

	var motion: EventRow = EventRow.new()
	motion.trigger_id = "OnProcess"
	motion.trigger_provider_id = "Core"
	motion.actions.append(_act("ApplyPushes", {"friction": "8.0"}))
	motion.actions.append(_act("PullGroupToward", {"group": "\"coins\"", "radius": "96.0", "speed": "400.0"}))
	motion.actions.append(_act("OrbitAround", {"center": "player", "radius": "40.0", "degrees_per_second": "90.0"}))
	sheet.events.append(motion)

	var modern_base := Color("#252525")
	var modern_style := EventSheetEditorStyle.new()
	modern_style.ensure_defaults()
	EventSheetGodotTheme.apply(modern_style, modern_base, modern_base.darkened(0.15), modern_base.darkened(0.25), Color("#569eff"), Color("#ced0d2"))
	sheet.editor_style = modern_style
	_viewport.set_sheet(sheet)


## Stage 2: the Object Pool as a consumer uses it - create on ready, spawn on a cadence,
## despawn when done. Pack verbs are method: ACEs, humanized by the registry-free fallback.
func _apply_pool_sheet() -> void:
	var sheet: EventSheetResource = EventSheetResource.new()

	var setup: EventRow = EventRow.new()
	setup.trigger_id = "OnReady"
	setup.trigger_provider_id = "Core"
	setup.actions.append(_pool_act("method:create_pool", {"pool_name": "\"bullets\"", "scene_path": "\"res://bullet.tscn\"", "prewarm": "8"}))
	sheet.events.append(setup)

	var shoot: EventRow = EventRow.new()
	shoot.trigger_id = "OnProcess"
	shoot.trigger_provider_id = "Core"
	shoot.conditions.append(_cond("EveryRandomSeconds", {"min_seconds": "0.2", "max_seconds": "0.4"}))
	shoot.actions.append(_pool_act("method:spawn", {"pool_name": "\"bullets\""}))
	sheet.events.append(shoot)

	var done: EventRow = EventRow.new()
	done.trigger_id = "signal:screen_exited"
	done.actions.append(_pool_act("method:despawn", {"node": "bullet"}))
	sheet.events.append(done)

	var modern_base := Color("#252525")
	var modern_style := EventSheetEditorStyle.new()
	modern_style.ensure_defaults()
	EventSheetGodotTheme.apply(modern_style, modern_base, modern_base.darkened(0.15), modern_base.darkened(0.25), Color("#569eff"), Color("#ced0d2"))
	sheet.editor_style = modern_style
	_viewport.set_sheet(sheet)


static func _pool_act(ace_id: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "ObjectPoolAddon"
	action.ace_id = ace_id
	action.params = params
	return action
