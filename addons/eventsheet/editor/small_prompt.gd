# Godot EventSheets - the ONE shape every quick question takes.
#
# A quick question is a normal Godot ConfirmationDialog laid out by six rules:
#   1. The title IS the question ("Keep this event?"), never "Confirm" or "Warning".
#   2. One plain sentence says what will happen.
#   3. What it touches is shown as a short list before anyone agrees.
#   4. The safe choice is the blue OK button, so Enter does it; Esc and the close box always cancel.
#   5. The risky choice (delete, discard, overwrite) is its own red-outlined button on the LEFT. It is
#      never OK and never Cancel, so neither Enter nor Esc can take it.
#   6. The note says out loud whether Ctrl+Z undoes it.
#
# DELIBERATELY NO `class_name`: callers reach it with `load()` of its path at the moment they ask,
# so nothing about it compiles until a question is actually asked.
@tool
extends RefCounted

## The custom action the risky button sends. Only it runs `on_danger`.
const DANGER_ACTION: StringName = &"small_prompt_danger"
## The width the sentence and the note wrap at before the display scale, so a content-sized dialog
## never balloons. Read through wrap_width(), which scales it the way the rest of the dialog is.
const WRAP_WIDTH := 400.0
## The lines a code card shows before it scrolls, and the height it scrolls in before the display
## scale, so a preview of many lines never pushes the buttons off the screen.
const CODE_LINES := 12
const CODE_HEIGHT := 260.0
## The glyph -> its badge colours: background and foreground on a dark editor theme, then the same
## pair on a light one. A question, a notice, a finished thing.
const GLYPH_TONES := {
	"?": [Color("#4A3E22"), Color("#FFD27A"), Color("#F5E2B8"), Color("#7A4E00")],
	"!": [Color("#4A3E22"), Color("#FFD27A"), Color("#F5E2B8"), Color("#7A4E00")],
	"i": [Color("#23384D"), Color("#7CC4FF"), Color("#C4DCF5"), Color("#0B4F96")],
	"{ }": [Color("#23384D"), Color("#7CC4FF"), Color("#C4DCF5"), Color("#0B4F96")],
	"✓": [Color("#25402A"), Color("#8EE09A"), Color("#C7EBCB"), Color("#1D6A2A")],
}
## The risky button's colour outside the editor, where the theme has no error colour to read.
const DANGER_FALLBACK := Color("#F07A7A")


## Builds the question under `host`, shows it when `host` is in the tree, and returns it. A dialog
## shown this way frees itself once it closes. `ask` holds the copy, already translated:
##   title   the question                       say     one plain sentence
##   list    [[what, where], ...] (optional)
##   body    a Control under the list, for the one field a question may need (optional)
##   code    the code it adds or shows, under the field (optional)
##   code_width  the code card's width before the display scale, for a preview of long lines (optional)
##   note    the muted last line, saying whether Ctrl+Z undoes it (optional)
##   glyph   "?" (default), "!", "i", "{ }" or "✓"
##   main    the safe choice's label; runs `on_main`
##   cancel  the way out's label ("" hides the button); Esc and the close box always run `on_cancel`
##   danger  the risky choice's label (optional); runs `on_danger`
static func open(host: Node, ask: Dictionary) -> ConfirmationDialog:
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = str(ask.get("title", ""))
	dialog.ok_button_text = str(ask.get("main", EventSheetL10n.translate("OK")))
	var cancel_text: String = str(ask.get("cancel", EventSheetL10n.translate("Cancel")))
	dialog.cancel_button_text = cancel_text
	dialog.get_cancel_button().visible = not cancel_text.is_empty()
	var blue: Color = EventSheetPopupUI.accent_color().darkened(0.3)
	_paint(dialog.get_ok_button(), blue, Color.WHITE, true)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", EventSheetPopupUI.CONTENT_MARGIN)
	row.add_child(_badge(str(ask.get("glyph", "?"))))
	var column: VBoxContainer = EventSheetPopupUI.form_box()
	row.add_child(column)
	dialog.add_child(EventSheetPopupUI.margined(row))
	var say: Label = EventSheetPopupUI.hint_label(str(ask.get("say", "")), wrap_width())
	say.name = "Say"
	say.modulate = Color.WHITE
	column.add_child(say)
	var places: Tree = Tree.new()
	places.name = "Places"
	places.columns = 2
	places.hide_root = true
	places.focus_mode = Control.FOCUS_NONE
	# The where-column is a short count; the what-column gets the rest of the width.
	places.set_column_expand(1, false)
	places.set_column_custom_minimum_width(1, roundi(EventSheetPalette.scaled_f(96.0)))
	column.add_child(places)
	set_list(dialog, ask.get("list", []))
	if ask.get("body") is Control:
		column.add_child(ask["body"] as Control)
		# Enter in a field the question asks for is the blue button, as rule 4 says it is everywhere.
		for field: Node in [ask["body"]] + (ask["body"] as Control).find_children("*", "LineEdit", true, false):
			if field is LineEdit:
				dialog.register_text_enter(field as LineEdit)
	var code: Control = Control.new()
	code.name = "Code"
	dialog.set_meta(&"code_width", float(ask.get("code_width", WRAP_WIDTH)))
	column.add_child(code)
	set_code(dialog, str(ask.get("code", "")))
	if not str(ask.get("note", "")).is_empty():
		var note: Label = EventSheetPopupUI.hint_label(str(ask["note"]), wrap_width())
		note.name = "Note"
		column.add_child(note)
	_wire(dialog, ask)
	host.add_child(dialog)
	if dialog.is_inside_tree():
		dialog.popup_centered()
	return dialog


## The width the sentence, the note and the list wrap at on this display.
static func wrap_width() -> float:
	return EventSheetPalette.scaled_f(WRAP_WIDTH)


## Redraws the list under the sentence - for a question whose answer is still being typed. An empty
## list hides it: a frame around nothing reads as "it touches nothing", which is a claim.
static func set_list(dialog: ConfirmationDialog, rows: Array) -> void:
	var places: Tree = dialog.find_child("Places", true, false) as Tree
	places.clear()
	var root: TreeItem = places.create_item()
	for pair: Variant in rows:
		var cells: Array = pair as Array
		var item: TreeItem = places.create_item(root)
		item.set_text(0, str(cells[0]))
		item.set_tooltip_text(0, str(cells[0]))
		item.set_text(1, str(cells[1]) if cells.size() > 1 else "")
		item.set_custom_color(1, EventSheetPopupUI.muted_text_color())
	places.visible = not rows.is_empty()
	# Tall enough for five places before it scrolls, so a long list still fits on the screen.
	places.custom_minimum_size = Vector2(wrap_width(),
		EventSheetPalette.scaled_f(34.0) * clampi(rows.size(), 1, 5) + EventSheetPalette.scaled_f(6.0))
	places.scroll_vertical_enabled = rows.size() > 5


## Redraws the code card - for a question whose code depends on what is being typed. Empty hides it.
static func set_code(dialog: ConfirmationDialog, text: String) -> void:
	var old: Control = dialog.find_child("Code", true, false) as Control
	# The card's copy button copies what it was built with, so a new text is a new card.
	var width: float = EventSheetPalette.scaled_f(float(dialog.get_meta(&"code_width", WRAP_WIDTH)) - 40.0)
	var card: Control = EventSheetPopupUI.code_card(text, width)
	if text.count("\n") >= CODE_LINES:
		var scroll: ScrollContainer = ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.custom_minimum_size = Vector2(0.0, EventSheetPalette.scaled_f(CODE_HEIGHT))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(card)
		card = scroll
	card.visible = not text.is_empty()
	old.add_sibling(card)
	old.get_parent().remove_child(old)
	old.free()
	card.name = "Code"


## The three ways out. Only the red button runs `on_danger`; OK runs `on_main`; Cancel, Esc and the
## close box all send `canceled` and run `on_cancel`. Whichever it was, the dialog is done with.
static func _wire(dialog: ConfirmationDialog, ask: Dictionary) -> void:
	if ask.get("on_main") is Callable:
		dialog.confirmed.connect(ask["on_main"] as Callable)
	if ask.get("on_cancel") is Callable:
		dialog.canceled.connect(ask["on_cancel"] as Callable)
	var danger_text: String = str(ask.get("danger", ""))
	if not danger_text.is_empty():
		var danger: Button = dialog.add_button(danger_text, false, DANGER_ACTION)
		danger.name = "Danger"
		var red: Color = _danger_color()
		_paint(danger, Color(red, 0.0), red, false)
		_stand_apart(danger)
		var on_danger: Callable = ask.get("on_danger", Callable()) as Callable
		dialog.custom_action.connect(func(action: StringName) -> void:
			if action != DANGER_ACTION:
				return
			dialog.hide()
			if on_danger.is_valid():
				on_danger.call())
	dialog.visibility_changed.connect(func() -> void:
		if not dialog.visible:
			dialog.queue_free())


## Moves the risky button to the far left with all the room in the row after it, so it reads as
## a different kind of choice from the ones on the right.
static func _stand_apart(danger: Button) -> void:
	var buttons: HBoxContainer = danger.get_parent() as HBoxContainer
	for child: Node in buttons.get_children():
		if not (child is Button):
			(child as Control).size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	buttons.move_child(danger, 0)
	var gap: Control = Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(gap)
	buttons.move_child(gap, 1)


## The round glyph beside the sentence, tinted by the kind of question it is.
static func _badge(glyph: String) -> Control:
	var tones: Array = badge_tones(glyph, _light_editor())
	var label: Label = Label.new()
	label.name = "Glyph"
	label.text = glyph
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", tones[1])
	var side: float = EventSheetPalette.scaled_f(26.0)
	label.custom_minimum_size = Vector2(side, side)
	var disc: StyleBoxFlat = StyleBoxFlat.new()
	disc.bg_color = tones[0]
	disc.set_corner_radius_all(int(side / 2.0))
	label.add_theme_stylebox_override("normal", disc)
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return label


## A glyph's badge colours [background, foreground] on a light or a dark editor theme.
static func badge_tones(glyph: String, light: bool) -> Array:
	var tones: Array = GLYPH_TONES.get(glyph, GLYPH_TONES["?"])
	return tones.slice(2, 4) if light else tones.slice(0, 2)


## True when the editor wears a light theme - Godot says so itself, as the "dark_theme" constant.
static func _light_editor() -> bool:
	var theme: Theme = _editor_theme()
	return theme != null and theme.has_constant("dark_theme", "Editor") and theme.get_constant("dark_theme", "Editor") == 0


static func _editor_theme() -> Theme:
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		return Engine.get_singleton("EditorInterface").get_editor_theme()
	return null


## Recolours one of the dialog's own buttons: filled for the safe choice, outlined for the risky one.
static func _paint(button: Button, fill: Color, text: Color, filled: bool) -> void:
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		var base: StyleBox = button.get_theme_stylebox(state)
		if base is StyleBoxFlat:
			style = (base as StyleBoxFlat).duplicate() as StyleBoxFlat
		style.draw_center = filled and state != "focus"
		style.bg_color = fill.lightened(0.12) if state == "hover" else fill
		style.border_color = fill if filled and state != "focus" else text
		style.set_border_width_all(1)
		style.set_corner_radius_all(3)
		button.add_theme_stylebox_override(state, style)
	for color_name: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(color_name, text)


## The editor's own error colour, so the risky button matches Godot's red in every theme.
static func _danger_color() -> Color:
	var theme: Theme = _editor_theme()
	if theme != null and theme.has_color("error_color", "Editor"):
		return theme.get_color("error_color", "Editor")
	return DANGER_FALLBACK
