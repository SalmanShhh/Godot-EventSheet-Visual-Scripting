# EventForge — visual render harness (dev tool, not shipped logic).
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
	var group: EventGroup = EventGroup.new()
	group.group_name = "Gameplay"
	var hurt_event: EventRow = EventRow.new()
	hurt_event.trigger_id = "on_body_entered"
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
	group.events.append(hurt_event)
	sheet.events.append(group)

	var move_event: EventRow = EventRow.new()
	move_event.trigger_id = "on_process"
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

	var empty_condition_event: EventRow = EventRow.new()
	var empty_action: ACEAction = ACEAction.new()
	empty_action.provider_id = "Core"
	empty_action.ace_id = "MoveAndSlide"
	empty_condition_event.actions.append(empty_action)
	sheet.events.append(empty_condition_event)

	var comment: CommentRow = CommentRow.new()
	# A long, single-line comment exercises word-wrapping: it should flow onto several lines
	# and grow the row vertically instead of clipping off the right edge.
	comment.text = "Player gameplay rules: attach this sheet under a CharacterBody2D, run movement every physics tick, and keep the comment readable by wrapping it across as many lines as it needs instead of clipping off the right edge of the sheet."
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

	# A sheet-built heal() function (a class-level block row — the viewport renders in-sheet rows; full
	# function sections live in the dock, which would add toolbar chrome and spoil this clean hero shot).
	var raw_block: RawCodeRow = RawCodeRow.new()
	raw_block.code = "func heal(amount: int) -> void:\n\thp += amount"
	sheet.events.append(raw_block)
	return sheet
