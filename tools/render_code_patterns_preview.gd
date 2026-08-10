# EventForge - render harness (dev tool) for the common-code-patterns guide: screenshots a demo
# sheet built from the timing/cooldown/juice vocabulary (Has Changed, Every X Seconds, named
# cooldowns, Wait, Tween Property), then the State Machine pack opened as a sheet. Run NON-headless:
#   godot --path . --script tools/render_code_patterns_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _stage: int = 0
var _viewport: EventSheetViewport = null


func _init() -> void:
	root.title = "Code Patterns"
	root.size = Vector2i(1100, 620)
	var modern_base := Color("#252525")
	var background: ColorRect = ColorRect.new()
	background.color = modern_base.darkened(0.25)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.position = Vector2(8, 8)
	scroll.size = Vector2(1084, 604)
	root.add_child(scroll)
	_viewport = EventSheetViewport.new()
	_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport.set_ace_registry(EventSheetACERegistry.new())
	scroll.add_child(_viewport)
	_apply_sheet(_build_patterns_sheet())
	process_frame.connect(_on_frame)


func _apply_sheet(sheet: EventSheetResource) -> void:
	var modern_base := Color("#252525")
	var modern_style := EventSheetEditorStyle.new()
	modern_style.ensure_defaults()
	EventSheetGodotTheme.apply(modern_style, modern_base, modern_base.darkened(0.15), modern_base.darkened(0.25), Color("#569eff"), Color("#ced0d2"))
	sheet.editor_style = modern_style
	_viewport.set_sheet(sheet)


## The guide's hero sheet: every event is one of the code patterns the guide names, written the
## way a beginner would actually author it.
func _build_patterns_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.variables = {"score": {"type": "int", "default": 0, "exported": true, "attributes": {"remember": true}}}

	var count_up: EventRow = EventRow.new()
	count_up.trigger_id = "OnProcess"
	count_up.conditions.append(_cond("EveryXSeconds", {"seconds": "0.5"}))
	count_up.actions.append(_act("SetVar", {"var_name": "score", "value": "score + 1"}))
	sheet.events.append(count_up)

	var juice: EventRow = EventRow.new()
	juice.trigger_id = "OnProcess"
	juice.conditions.append(_cond("HasChanged", {"value": "score"}))
	juice.actions.append(_act("TweenProperty", {"target": "self", "property": "\"scale\"", "value": "Vector2(1.15, 1.15)", "duration": "0.1", "transition": "Tween.TRANS_BACK", "ease": "Tween.EASE_OUT"}))
	sheet.events.append(juice)

	var dash: EventRow = EventRow.new()
	dash.trigger_id = "OnProcess"
	dash.conditions.append(_cond("CooldownReady", {"name": "\"dash\""}))
	dash.actions.append(_act("StartCooldown", {"name": "\"dash\"", "seconds": "1.5"}))
	dash.actions.append(_act("TweenProperty", {"target": "self", "property": "\"position\"", "value": "position + Vector2(160, 0)", "duration": "0.2", "transition": "Tween.TRANS_SINE", "ease": "Tween.EASE_OUT"}))
	sheet.events.append(dash)

	var intro: EventRow = EventRow.new()
	intro.trigger_id = "OnReady"
	intro.actions.append(_act("Wait", {"seconds": "1.0"}))
	intro.actions.append(_act("SetVar", {"var_name": "score", "value": "0"}))
	sheet.events.append(intro)
	return sheet


## The guide's state-machine sheet, as a CONSUMER writes it: a named group holding one event per
## state (the Is In State condition renders as the "◆ State:" header), transitions guarded by
## their own conditions, and the pack's On State Changed trigger closing the loop.
func _build_state_machine_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	var machine: EventGroup = EventGroup.new()
	machine.name = "State Machine · Enemy ( patrol · chase · flee )"

	# ONE "Every Physics Tick" parent - the sheet's mirror of the single _physics_process a
	# hand-written machine lives in - with each STATE as a sub-event under it (its condition
	# renders as the "◆ State:" header) and each transition nested one level deeper.
	var tick: EventRow = EventRow.new()
	tick.trigger_id = "OnPhysicsProcess"
	tick.trigger_provider_id = "Core"

	var patrol: EventRow = EventRow.new()
	patrol.conditions.append(_sm_cond("patrol"))
	patrol.actions.append(_pack_act("method:patrol_step", {"delta": "delta"}))
	var spot: EventRow = EventRow.new()
	spot.conditions.append(_cond("ExpressionIsTrue", {"expr": "can_see_player()"}))
	spot.actions.append(_pack_act("method:set_state", {"next": "\"chase\""}))
	patrol.sub_events.append(spot)
	tick.sub_events.append(patrol)

	var chase: EventRow = EventRow.new()
	chase.conditions.append(_sm_cond("chase"))
	chase.actions.append(_pack_act("method:chase_step", {"delta": "delta"}))
	var flee: EventRow = EventRow.new()
	flee.conditions.append(_cond("ExpressionIsTrue", {"expr": "hp < 20"}))
	flee.actions.append(_pack_act("method:set_state", {"next": "\"flee\""}))
	chase.sub_events.append(flee)
	tick.sub_events.append(chase)

	var fleeing: EventRow = EventRow.new()
	fleeing.conditions.append(_sm_cond("flee"))
	var calm_down: EventRow = EventRow.new()
	calm_down.conditions.append(_cond("ExpressionIsTrue", {"expr": "time_in_state() > 2.0"}))
	calm_down.actions.append(_pack_act("method:set_state", {"next": "previous_state"}))
	fleeing.sub_events.append(calm_down)
	tick.sub_events.append(fleeing)

	machine.events.append(tick)

	var yelp: EventRow = EventRow.new()
	yelp.trigger_id = "signal:state_changed"
	yelp.actions.append(_act("Wait", {"seconds": "0.2"}))
	machine.events.append(yelp)

	sheet.events.append(machine)
	return sheet


static func _sm_cond(state_name: String) -> ACECondition:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "StateMachineBehavior"
	condition.ace_id = "method:is_in_state"
	condition.params = {"state_name": "\"%s\"" % state_name}
	return condition


static func _pack_act(ace_id: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "StateMachineBehavior"
	action.ace_id = ace_id
	action.params = params
	return action


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
	var img: Image = root.get_texture().get_image()
	if _stage == 0:
		img.save_png("res://docs/images/code-patterns-rows.png")
		print("[preview] patterns sheet %dx%d" % [img.get_width(), img.get_height()])
		_stage = 1
		_frames = 0
		_apply_sheet(_build_state_machine_sheet())
		return
	img.save_png("res://docs/images/code-patterns-state-machine.png")
	print("[preview] state machine sheet %dx%d" % [img.get_width(), img.get_height()])
	quit(0)
