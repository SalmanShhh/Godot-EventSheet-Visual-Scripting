# EventForge - render harness (dev tool) for the README's close-up canvas shot: the event sheet
# rows on their own, with no editor chrome, so the two-lane grammar is legible at a glance. The
# editor-wide shots live beside it; this one is deliberately just the rows.
#
# Rebuilds the same little player sheet the shipped image shows - exported variables with an
# Inspector-grouping chip, a colored region wrapping a group, a negated condition, an inline
# GDScript block, comments, and a sheet-built function - so a refresh picks up current row styling
# instead of freezing whatever the renderer looked like the day the file was first written.
#
# NOT YET A DROP-IN REPLACEMENT for docs/previews/editor-event-sheet.png, which is still the shipped
# image. Two things need solving first, and both are about size rather than content:
#   1. The canvas control comes out ~940x444 whatever this window is set to, so the lower rows (the
#      jump event, the second comment, combo, max_health and heal()) fall outside the capture.
#   2. At that width the aligned object column elides a long trigger name ("On Body...",
#      "CharacterBod..."). The shipped image predates aligned columns being the default, so it shows
#      the flow-mode look. Setting the column width to 0 needs the style the viewport actually reads;
#      it is NOT exposed as `event_style` on the viewport.
# The sheet construction below is verified correct (real ACE ids, real region field keys), so
# whoever picks this up is only fighting layout.
#
# Run NON-headless (headless cannot render):
#   godot --path . --script tools/render_event_sheet_canvas.gd
@tool
extends SceneTree

const SHOT_PATH: String = "res://docs/previews/editor-event-sheet.png"
const CANVAS_SIZE: Vector2i = Vector2i(1152, 648)
const WINDOW_SIZE: Vector2i = Vector2i(2000, 1240)

var _frames: int = 0
var _editor: EventSheetEditor = null


func _init() -> void:
	root.title = "Event Sheet Canvas"
	root.size = WINDOW_SIZE
	root.gui_embed_subwindows = true
	var background: ColorRect = ColorRect.new()
	background.color = Color("#1d2229")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	process_frame.connect(_on_frame)


func _variable(variable_name: String, type_name: String, value: Variant, exported: bool, group: String = "") -> LocalVariable:
	var variable: LocalVariable = LocalVariable.new()
	variable.name = variable_name
	variable.type_name = type_name
	variable.default_value = value
	variable.exported = exported
	if not group.is_empty():
		variable.attributes = {"group": group}
	return variable


func _action(ace_id: String, template: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.codegen_template = template
	action.params = params
	return action


func _condition(ace_id: String, template: String, params: Dictionary, negated: bool = false) -> ACECondition:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = ace_id
	condition.codegen_template = template
	condition.params = params
	condition.negated = negated
	return condition


func _comment(text: String) -> CommentRow:
	var comment: CommentRow = CommentRow.new()
	comment.text = text
	return comment


func _build_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "CharacterBody2D"
	sheet.events.append(_variable("hp", "int", 100, true))
	sheet.events.append(_variable("speed", "float", 200.0, true))

	# Damage: a group inside a colored region, so both wrappers are on show.
	var damage: EventRow = EventRow.new()
	damage.trigger_provider_id = "Core"
	damage.trigger_id = "OnBodyEntered"
	damage.conditions.append(_condition("HasGroupMember", "is_in_group(&{group})", {"group": "\"enemy\""}))
	damage.actions.append(_action("AddVar", "{var_name} += {amount}", {"var_name": "hp", "amount": "-10"}))
	damage.actions.append(_action("PlayAnimation", "play(&{anim_name})", {"anim_name": "\"hurt_flash\""}))
	var gameplay: EventGroup = EventGroup.new()
	gameplay.name = "Gameplay"
	gameplay.events.append(damage)
	var region: CustomBlockRow = CustomBlockRow.new()
	region.kind_id = "region"
	region.fields = {"label": "Combat", "description": "damage in and out", "color": "#c86464"}
	sheet.events.append(region)
	sheet.events.append(gameplay)
	var region_end: CustomBlockRow = CustomBlockRow.new()
	region_end.kind_id = "region"
	region_end.fields = {"label": "Combat", "is_end": true}
	sheet.events.append(region_end)

	# Movement: a NEGATED condition plus an inline GDScript action.
	var movement: EventRow = EventRow.new()
	movement.trigger_provider_id = "Core"
	movement.trigger_id = "OnPhysicsProcess"
	movement.conditions.append(_condition("IsOnFloor", "is_on_floor()", {}, true))
	movement.actions.append(_action("MoveAndSlide", "move_and_slide()", {}))
	var damping: RawCodeRow = RawCodeRow.new()
	damping.code = "velocity.x = lerp(velocity.x, 0.0, 0.2)"
	movement.actions.append(damping)
	sheet.events.append(movement)
	sheet.events.append(_comment("Keeps the body moving along the floor"))

	# Jump: the plainest possible read - one condition, one action.
	var jump: EventRow = EventRow.new()
	jump.trigger_provider_id = "Core"
	jump.trigger_id = "OnPhysicsProcess"
	jump.conditions.append(_condition("IsActionJustPressed", "Input.is_action_just_pressed({action})", {"action": "\"jump\""}))
	jump.actions.append(_action("PlaySound", "play_sound({path})", {"path": "\"res://sfx/jump.ogg\""}))
	sheet.events.append(jump)
	sheet.events.append(_comment("Player rules: attach under a CharacterBody2D - movement runs every physics tick, damage lives in the Combat region above."))

	# A plain variable, a grouped exported one, and a sheet-built function.
	sheet.events.append(_variable("combo", "int", 0, false))
	sheet.events.append(_variable("max_health", "int", 100, true, "Combat/Defense"))
	var heal: EventFunction = EventFunction.new()
	heal.function_name = "heal"
	heal.return_type = TYPE_NIL
	var amount: ACEParam = ACEParam.new()
	amount.id = "amount"
	amount.name = "amount"
	amount.type_name = "int"
	heal.params.append(amount)
	var heal_body: RawCodeRow = RawCodeRow.new()
	heal_body.code = "hp += amount"
	heal.rows.append(heal_body)
	sheet.functions.append(heal)
	return sheet


func _on_frame() -> void:
	_frames += 1
	if _frames == 2:
		_editor = EventSheetEditor.new()
		root.add_child(_editor)
		_editor.setup(_build_sheet())
		return
	if _frames < 14 or _editor == null:
		return
	var canvas_control: EventSheetViewport = _editor.get_viewport_control()
	var image: Image = canvas_control.get_viewport().get_texture().get_image()
	# Crop to the canvas control's own rect: everything else in this window is dock chrome.
	var rect: Rect2i = Rect2i(canvas_control.get_global_rect().position, canvas_control.get_global_rect().size)
	rect = rect.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	if rect.size.x > 0 and rect.size.y > 0:
		image = image.get_region(rect)
	if image.get_width() > CANVAS_SIZE.x:
		var scaled_height: int = int(round(float(image.get_height()) * float(CANVAS_SIZE.x) / float(image.get_width())))
		image.resize(CANVAS_SIZE.x, scaled_height, Image.INTERPOLATE_LANCZOS)
	image.save_png(SHOT_PATH)
	print("[preview] event sheet canvas %dx%d" % [image.get_width(), image.get_height()])
	quit(0)
