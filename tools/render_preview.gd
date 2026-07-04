# EventForge - visual render harness (dev tool, not shipped logic).
# Renders the event sheet viewport with a representative sheet and saves a PNG so the
# rendering can be inspected. Run NON-headless (needs a real renderer):
#   godot --path . --script tools/render_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _viewport: EventSheetViewport = null


func _init() -> void:
	root.title = "EventForge Render Preview"
	root.size = Vector2i(1320, 760)

	# Simulate Godot 4.7's neutral grayscale "Modern" editor theme (base #252525, accent
	# #569eff) so this out-of-editor render matches the in-editor adapted look instead of the
	# raw palette fallback. Set EVENTFORGE_PREVIEW_RAW=1 to see the un-adapted fallback.
	var preview_modern: bool = OS.get_environment("EVENTFORGE_PREVIEW_RAW") != "1"
	var modern_base := Color("#252525")
	var modern_dark_1 := modern_base.darkened(0.15)
	var modern_dark_2 := modern_base.darkened(0.25)
	var modern_accent := Color("#569eff")
	var modern_font := Color("#ced0d2")

	var background: ColorRect = ColorRect.new()
	background.color = modern_dark_2 if preview_modern else Color("#1e1f24")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "EventSheetScroll"
	scroll.position = Vector2(8, 8)
	scroll.size = Vector2(1300, 740)
	root.add_child(scroll)

	_viewport = EventSheetViewport.new()
	_viewport.name = "EventSheetViewport"
	_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport.set_ace_registry(EventSheetACERegistry.new())
	scroll.add_child(_viewport)
	var sheet: EventSheetResource = _build_sheet()
	if preview_modern:
		var modern_style := EventSheetEditorStyle.new()
		modern_style.ensure_defaults()
		EventSheetGodotTheme.apply(modern_style, modern_base, modern_dark_1, modern_dark_2, modern_accent, modern_font)
		sheet.editor_style = modern_style
	_viewport.set_sheet(sheet)

	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames < 4:
		return
	var image: Image = root.get_texture().get_image()
	image.save_png("res://_preview.png")
	print("[render_preview] saved res://_preview.png (%dx%d)" % [image.get_width(), image.get_height()])
	quit(0)


func _build_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "CharacterBody2D"
	sheet.variables = {
		"hp": {"type": "int", "default": 100, "exported": true},
		"speed": {"type": "float", "default": 200.0}
	}
	# A colored region wrapping the group: shows the Discord-style bubble outline + the
	# pill-free fence rows.
	var region_open: CustomBlockRow = CustomBlockRow.new()
	region_open.kind_id = "region"
	region_open.fields = {"label": "Combat", "is_end": false, "color": "#e06666", "description": "damage in and out"}
	sheet.events.append(region_open)
	var group: EventGroup = EventGroup.new()
	group.group_name = "Gameplay"
	var hurt_event: EventRow = EventRow.new()
	hurt_event.trigger_provider_id = "Core"
	hurt_event.trigger_id = "OnBodyEntered"
	var cond: ACECondition = ACECondition.new()
	cond.provider_id = "Core"
	cond.ace_id = "HasGroupMember"
	cond.params = {"group": "enemy"}
	hurt_event.conditions.append(cond)
	var act: ACEAction = ACEAction.new()
	act.provider_id = "Core"
	act.ace_id = "AddVar"
	act.params = {"var_name": "hp", "amount": "-10"}
	hurt_event.actions.append(act)
	# The REAL multi-line registry ACE (param ids must match its descriptor) so the row
	# reads properly AND carries the muted "→N" compression cue after the text.
	var flash_action: ACEAction = ACEAction.new()
	flash_action.provider_id = "Core"
	flash_action.ace_id = "PlayAnimationInObject"
	flash_action.codegen_template = "var __ap_1 := {target}.find_children(\"*\", \"AnimationPlayer\", true, false).pop_front() as AnimationPlayer\nif __ap_1:\n\t__ap_1.play(&{anim})"
	flash_action.params = {"target": "self", "anim": "\"hurt_flash\""}
	hurt_event.actions.append(flash_action)
	group.events.append(hurt_event)
	sheet.events.append(group)
	var region_close: CustomBlockRow = CustomBlockRow.new()
	region_close.kind_id = "region"
	region_close.fields = {"label": "", "is_end": true}
	sheet.events.append(region_close)

	var move_event: EventRow = EventRow.new()
	move_event.trigger_provider_id = "Core"
	move_event.trigger_id = "OnProcess"
	var is_floor: ACECondition = ACECondition.new()
	is_floor.provider_id = "Core"
	is_floor.ace_id = "IsOnFloor"
	is_floor.negated = true
	move_event.conditions.append(is_floor)
	var move_action: ACEAction = ACEAction.new()
	move_action.provider_id = "Core"
	move_action.ace_id = "MoveAndSlide"
	move_event.actions.append(move_action)
	var inline_block: RawCodeRow = RawCodeRow.new()
	inline_block.code = "velocity.x = lerp(velocity.x, 0.0, 0.2)"
	move_event.actions.append(inline_block)
	var move_note: CommentRow = CommentRow.new()
	move_note.text = "Keeps the body moving along the [b]floor[/b]"
	move_event.sub_events.append(move_note)
	sheet.events.append(move_event)

	var jump_event: EventRow = EventRow.new()
	jump_event.trigger_provider_id = "Core"
	jump_event.trigger_id = "OnProcess"
	var jump_pressed: ACECondition = ACECondition.new()
	jump_pressed.provider_id = "Core"
	jump_pressed.ace_id = "IsActionJustPressed"
	jump_pressed.params = {"action": "\"jump\""}
	jump_event.conditions.append(jump_pressed)
	var play_jump: ACEAction = ACEAction.new()
	play_jump.provider_id = "Core"
	play_jump.ace_id = "PlaySound"
	play_jump.params = {"path": "\"res://sfx/jump.ogg\""}
	jump_event.actions.append(play_jump)
	sheet.events.append(jump_event)

	var comment: CommentRow = CommentRow.new()
	# A wrapping comment: flows onto several lines and grows the row vertically. Kept
	# short enough to wrap cleanly inside the preview width.
	comment.text = "Player rules: attach under a CharacterBody2D - movement runs every physics tick, damage lives in the Combat region above."
	sheet.events.append(comment)

	var tree_var: LocalVariable = LocalVariable.new()
	tree_var.name = "combo"
	tree_var.type_name = "int"
	tree_var.default_value = 0
	sheet.events.append(tree_var)

	# An exported, Inspector-grouped variable: shows the @export badge + the "Group › Subgroup" chip.
	var grouped_var: LocalVariable = LocalVariable.new()
	grouped_var.name = "max_health"
	grouped_var.type_name = "int"
	grouped_var.default_value = 100
	grouped_var.exported = true
	grouped_var.attributes = {"group": "Combat", "subgroup": "Defense"}
	sheet.events.append(grouped_var)

	# A sheet-built heal() function (a class-level block row - the viewport renders in-sheet rows; full
	# function sections live in the dock, which would add toolbar chrome and spoil this clean hero shot).
	var raw_block: RawCodeRow = RawCodeRow.new()
	raw_block.code = "func heal(amount: int) -> void:\n\thp += amount"
	sheet.events.append(raw_block)
	return sheet
