# Godot EventSheets - the FRAME FIELD, as the animation itself.
#
# "On frame 3 of walk" is one of the oldest rows there is, and the number in it is the one thing the
# sheet could never help with: which frame IS frame 3? Counting it means opening the sprite frames
# editor in another window, counting cells, and remembering that the first one is 0.
#
# The strip is the animation. One cell per frame, in order, from 0, each showing that frame's own
# picture, with the chosen cell lit. Click the cell where the foot lands. The number field never goes
# away - somebody who already knows it is 37 types 37 - and everything the strip does writes into
# that same field, so the row stores a number exactly as it always did.
#
# ONLY A FLIPBOOK GETS ONE. An AnimationPlayer clip has no frames at all, only time and tracks, so a
# frame field on one would be a lie however friendly it looked. `cells_for` answers with nothing for
# a clip that has no frames, and the field is then the plain number box.
#
# THE MODEL IS PURE. `cells_for` is a static list of what to draw, so the numbering, the scrolling
# threshold and the selection can be pinned by a test with no display server anywhere near them.
@tool
class_name EventSheetFrameStrip
extends RefCounted

## How wide and tall one cell is drawn. Big enough for a readable thumbnail of a character sprite,
## small enough that eight of them fit a dialog without scrolling.
const CELL_SIZE: int = 34

## How many cells are shown before the strip scrolls instead of growing. Eight frames fit whole,
## which is what most hand-drawn cycles are; a sixty-frame flipbook scrolls.
const CELLS_BEFORE_SCROLL: int = 8

## How big the hovered frame is drawn in the preview above the strip - the "hover shows it large"
## half, for when a 34-pixel cell is not enough to tell two frames of a run cycle apart.
const PREVIEW_SIZE: int = 96


## The cells of one animation, as [{"frame", "label", "selected"}] - frame numbers from 0, the way
## Godot numbers them, contiguous and in order. Empty when the animation has no frames, which is the
## whole of the rule that keeps this off a keyframed clip.
static func cells_for(animation: Dictionary, selected: int) -> Array[Dictionary]:
	var cells: Array[Dictionary] = []
	var count: int = int(animation.get("frames", -1))
	for index: int in maxi(count, 0):
		cells.append({"frame": index, "label": str(index), "selected": index == selected})
	return cells


## True when a strip of this many cells has to scroll rather than fit.
static func scrolls(count: int) -> bool:
	return count > CELLS_BEFORE_SCROLL


## The strip for one animation, writing into `edit` - or null when the animation has no frames to
## show. `frames` is the real SpriteFrames, which is where the pictures come from; a null one still
## builds the strip, with numbered cells and no thumbnails, because the numbering is most of the
## help and a project whose textures cannot be loaded should not lose it.
static func build(animation: Dictionary, frames: SpriteFrames, edit: LineEdit) -> Control:
	var cells: Array[Dictionary] = cells_for(animation, int(str(edit.text).to_int()))
	if cells.is_empty():
		return null
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	var preview: TextureRect = TextureRect.new()
	preview.custom_minimum_size = Vector2(PREVIEW_SIZE, PREVIEW_SIZE)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.visible = false
	column.add_child(preview)
	var strip: HBoxContainer = HBoxContainer.new()
	strip.add_theme_constant_override("separation", 3)
	var animation_name: String = str(animation.get("name", ""))
	var buttons: Array[Button] = []
	for cell: Dictionary in cells:
		var button: Button = _cell_button(cell, _texture_of(frames, animation_name, int(cell["frame"])),
			edit, preview, buttons)
		buttons.append(button)
		strip.add_child(button)
	column.add_child(_scrolled(strip) if scrolls(cells.size()) else strip)
	# The number field and the strip are one control in two shapes: typing a number lights its cell,
	# clicking a cell types its number, and the row only ever stores the number.
	edit.text_changed.connect(func(typed: String) -> void: _light(buttons, typed.to_int()))
	_light(buttons, str(edit.text).to_int())
	return column


## One cell: the frame's picture with its number under it, lit when it is the chosen one. Clicking
## writes the number into the field; the arrow keys step to the next cell, because a reader walking
## a run cycle is comparing neighbours rather than aiming at one.
static func _cell_button(cell: Dictionary, texture: Texture2D, edit: LineEdit, preview: TextureRect,
		buttons: Array[Button]) -> Button:
	var button: Button = Button.new()
	var frame: int = int(cell["frame"])
	button.text = str(cell["label"])
	button.icon = texture
	button.expand_icon = true
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	button.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
	button.toggle_mode = true
	button.button_pressed = bool(cell["selected"])
	button.tooltip_text = EventSheetL10n.translate("frame %d") % frame
	button.pressed.connect(func() -> void:
		edit.text = str(frame)
		edit.text_changed.emit(edit.text)
	)
	button.mouse_entered.connect(func() -> void:
		preview.texture = texture
		preview.visible = texture != null
	)
	button.mouse_exited.connect(func() -> void: preview.visible = false)
	button.gui_input.connect(func(input_event: InputEvent) -> void:
		var stepped: int = _step_for(input_event)
		if stepped == 0:
			return
		var next: int = clampi(frame + stepped, 0, buttons.size() - 1)
		edit.text = str(next)
		edit.text_changed.emit(edit.text)
		buttons[next].grab_focus()
		button.accept_event()
	)
	return button


## Which way an arrow key steps, 0 for anything else.
static func _step_for(input_event: InputEvent) -> int:
	var key: InputEventKey = input_event as InputEventKey
	if key == null or not key.pressed:
		return 0
	if key.keycode == KEY_RIGHT or key.keycode == KEY_DOWN:
		return 1
	return -1 if key.keycode == KEY_LEFT or key.keycode == KEY_UP else 0


## Lights the cell the field's number names and unlights the rest - one place, so typing and
## clicking cannot disagree about which frame is chosen.
static func _light(buttons: Array[Button], frame: int) -> void:
	for index: int in buttons.size():
		buttons[index].set_pressed_no_signal(index == frame)


## A long strip in a scroller, tall enough for one row of cells and no taller.
static func _scrolled(strip: Control) -> Control:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, CELL_SIZE + 12)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(strip)
	return scroll


## One frame's picture, or null when there is no SpriteFrames to ask (or the frame is past its end).
static func _texture_of(frames: SpriteFrames, animation_name: String, frame: int) -> Texture2D:
	if frames == null or not frames.has_animation(animation_name):
		return null
	return frames.get_frame_texture(animation_name, frame) if frame < frames.get_frame_count(animation_name) else null
