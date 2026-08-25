@tool
extends Control

# A hand-written tool file of exactly the two shapes the tool reading claims: a dialog built in code, and a
# canvas painted by hand and answering its own input. Opened read-only by
# canvas_dialog_reading_test.gd and by the render harness that makes the guide figure - so the words
# in the test, the words in the picture and the words on this page can never drift apart.

var font: Font = null
var size_hint: Vector2 = Vector2(320, 180)


func _draw() -> void:
	var style := _get_reading_style()
	draw_rect(Rect2(Vector2.ZERO, size), style.background_color)
	draw_rect(size_hint, style.row_color, false)
	draw_line(Vector2.ZERO, size, style.guide_color, 1.0)
	draw_string(font, Vector2(8, 18), "Rows", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, style.text_color)
	draw_texture(style.badge, Vector2(4, 4))
	draw_polyline(style.spark, style.guide_color, 2.0)
	draw_arc(Vector2(40, 40), 8.0, 0.0, TAU, 32, style.text_color, 2.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_at(event.position)
		queue_redraw()
		accept_event()
	elif event is InputEventMouseMotion:
		_hover_at(event.position)


func _ask_keep_every_tick(uid: String, label: String) -> void:
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = "Keep as every tick?"
	dialog.ok_button_text = "Keep As Every Tick"
	EventSheetPopupUI.titled_card(dialog, "Last condition removed")
	EventSheetPopupUI.form_row(dialog, "Event", label)
	add_child(dialog)
	dialog.popup_centered()


func _close_panel(panel: Window) -> void:
	panel.hide()


func _restyle(box: StyleBox) -> void:
	add_theme_stylebox_override("normal", box)
	modulate = get_theme_color("row_color", "EventSheet")
