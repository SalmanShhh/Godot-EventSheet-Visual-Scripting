@tool
class_name EventSheetOpenProgress
extends RefCounted
# The "Opening <file>" strip: the dock's face for an asynchronous .gd open.
#
# Opening a .gd used to block the editor for as long as the ACE lift took - 3.4 s for the FPS
# controller pack, 18 s for a 4,600-line dock helper - with no repaint at all, which reads as a
# crash rather than as work. Now the dock paints the RAW sheet immediately (rows and verbatim code
# blocks; that pass costs tens of milliseconds), shows this strip above it, and runs the lift on a
# worker thread (EventSheetOpenJob), polling once a frame.
#
# The strip is deliberately thin: a spinner, what file is opening, which pass is running and how far
# in, a bar, and one escape - "Show as code instead", which cancels the lift and keeps the raw sheet.
#
# WIDGETS LIVE HERE, not on the dock: nothing outside this helper reads them. The dock owns the
# poll timer wiring only, through `_dock` (the sibling dock/ helper pattern).

const SPINNER_FRAMES: Array[String] = ["◐", "◓", "◑", "◒"]

var _dock: Control = null
var _panel: PanelContainer = null
var _spinner_label: Label = null
var _title_label: Label = null
var _detail_label: Label = null
var _bar: ProgressBar = null
var _cancel_button: Button = null
var _spinner_step: int = 0
## Set by the dock when the user asks for the raw code; the strip only reports the request, the
## job owns the actual cancel.
var cancel_requested_callback: Callable = Callable()


func init(dock: Control) -> void:
	_dock = dock


## Builds the strip (hidden). Styled from the shared palette so it matches the preview banner
## above it, and every metric goes through EventSheetPalette.scaled so it holds up at 200%.
func build() -> PanelContainer:
	_panel = PanelContainer.new()
	_panel.name = "EventSheetOpenProgress"
	_panel.visible = false
	var style: StyleBoxFlat = EventSheetPopupUI.inset_panel_stylebox()
	style.bg_color = Color(0.18, 0.22, 0.30)
	style.border_color = EventSheetPalette.COLOR_OBJECT
	style.set_border_width(SIDE_LEFT, EventSheetPalette.scaled(4))
	style.set_content_margin_all(float(EventSheetPalette.scaled(6)))
	_panel.add_theme_stylebox_override("panel", style)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", EventSheetPalette.scaled(8))
	_panel.add_child(row)

	_spinner_label = Label.new()
	_spinner_label.text = SPINNER_FRAMES[0]
	_spinner_label.add_theme_color_override("font_color", EventSheetPalette.COLOR_OBJECT)
	_spinner_label.custom_minimum_size = Vector2(EventSheetPalette.scaled(18), 0)
	row.add_child(_spinner_label)

	var text_box: VBoxContainer = VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", EventSheetPalette.scaled(2))
	row.add_child(text_box)

	_title_label = Label.new()
	_title_label.text = "Opening…"
	_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_box.add_child(_title_label)

	_detail_label = Label.new()
	_detail_label.text = ""
	_detail_label.add_theme_color_override("font_color", EventSheetPalette.TEXT_SECONDARY)
	_detail_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_box.add_child(_detail_label)

	_bar = ProgressBar.new()
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.step = 0.001
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(EventSheetPalette.scaled(200), EventSheetPalette.scaled(10))
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_bar)

	_cancel_button = Button.new()
	_cancel_button.text = "Show as code instead"
	_cancel_button.tooltip_text = "Stop working out which events this code maps to and just show the file as code blocks. Nothing is changed on disk either way."
	_cancel_button.pressed.connect(_on_cancel_pressed)
	row.add_child(_cancel_button)
	return _panel


func _on_cancel_pressed() -> void:
	if is_instance_valid(_cancel_button):
		_cancel_button.disabled = true
		_cancel_button.text = "Showing as code…"
	if cancel_requested_callback.is_valid():
		cancel_requested_callback.call()


## Shows the strip for `path`, reset to its starting state.
func show_for(path: String) -> void:
	if not is_instance_valid(_panel):
		return
	_spinner_step = 0
	if is_instance_valid(_cancel_button):
		_cancel_button.disabled = false
		_cancel_button.text = "Show as code instead"
	if _title_label != null:
		_title_label.text = "Opening %s" % path.get_file()
	if _detail_label != null:
		_detail_label.text = "reading the file"
	if _bar != null:
		_bar.value = 0.0
	_panel.visible = true


## One poll tick: advances the spinner and republishes the job's counters.
func update(status: String, ratio: float) -> void:
	if not is_instance_valid(_panel) or not _panel.visible:
		return
	_spinner_step = (_spinner_step + 1) % SPINNER_FRAMES.size()
	if _spinner_label != null:
		_spinner_label.text = SPINNER_FRAMES[_spinner_step]
	if _detail_label != null:
		_detail_label.text = status
	if _bar != null:
		_bar.value = clampf(ratio, 0.0, 1.0)


func hide_strip() -> void:
	if is_instance_valid(_panel):
		_panel.visible = false


func is_visible() -> bool:
	return is_instance_valid(_panel) and _panel.visible
