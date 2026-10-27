@tool
extends PanelContainer
# EventSheet - the hover card behind a word of the sheet's head bar.
#
# The head bar says only a name, a kind and three counts; everything else a reader may want about the
# file lives one hover away, on a card: the name's card says where the file lives, what it says about
# itself and that it stays plain GDScript, with the doors out to the script editor and the FileSystem;
# each count's card says what it counts, and the behaviours count's card lists them and offers Add
# behaviour…. A card is a Control floated over the canvas, never a widget inside a row: the row only
# carries the card's words in its span metadata (`head_card`), and this draws them while the pointer is
# on the word or on the card itself, so a door on it can be reached.
#
# The words arrive as one Dictionary, built by the row builder:
#   {"id", "title", "subtitle", "mono", "lines": [paragraph], "links": [[label, action]],
#    "notes": [muted paragraph], "doors": [[label, action]], "width": design px, "anchor": "left"|"right",
#    "code_last": bool}
# `code_last` puts the "mono" line under the paragraphs instead of under the title: a variable mark's
# card reads title, sentence, then the code that earns the mark.
# Every key but "id" and "title" may be missing. `links` lead the first paragraph as words joined by
# " · ", each a door when it has an action. An action comes back through `door_pressed`, which the
# viewport hands on as a head action.
#
# Loaded by path on the first hover of such a word, so opening a sheet compiles none of it.

signal door_pressed(action: String)

## How long the pointer rests on a word before its card opens, and how long the card waits once the
## pointer has left both the word and the card - long enough to cross the gap between them.
const SHOW_DELAY_MSEC: int = 300
const HIDE_DELAY_MSEC: int = 250
## The air inside the card and between its parts, at 1x.
const CARD_MARGIN: float = 10.0
const CARD_GAP: float = 6.0
## How far below the word the card's top edge sits, at 1x.
const CARD_DROP: float = 4.0
## The text size the design draws its cards for; a card's width grows with the editor's own text.
const DESIGN_TEXT_SIZE: float = 12.0
## The path line's size against the card's text: a little smaller, as code beside prose is.
const MONO_TEXT_RATIO: float = 0.88

var _box: VBoxContainer = null
## The word the open card belongs to ("" when closed), and the one waiting out the delay.
var _open_key: String = ""
var _pending_key: String = ""
var _pending_card: Dictionary = {}
var _pending_anchor: Rect2 = Rect2()
var _pending_since: int = 0
## True while the pointer is on the word the card belongs to.
var _over_word: bool = false
## When the pointer left both the word and the card, -1 while it is on either.
var _left_at: int = -1


func _init() -> void:
	name = "SheetHeadCard"
	visible = false
	top_level = true
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_STOP
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", int(round(EventSheetPalette.scaled_f(CARD_GAP))))
	add_child(_box)
	set_process(false)


## The pointer is on a word that has a card: `card` is the word's card, `anchor` the word's rect in the
## canvas's global coordinates. The card opens once the pointer has rested there, or at once.
func hover_word(card: Dictionary, anchor: Rect2, at_once: bool = false) -> void:
	_over_word = true
	_left_at = -1
	var key: String = "%s@%d,%d" % [str(card.get("id", "")), int(anchor.position.x), int(anchor.position.y)]
	if visible and key == _open_key:
		return
	if key != _pending_key:
		_pending_key = key
		_pending_since = Time.get_ticks_msec()
	_pending_card = card
	_pending_anchor = anchor
	if at_once:
		_open_pending()
		return
	set_process(true)


## The pointer is no longer on the word. The card stays while the pointer is on it.
func leave_word() -> void:
	_over_word = false
	_pending_key = ""
	if visible:
		set_process(true)


## Closes the card now.
func close() -> void:
	visible = false
	_open_key = ""
	_pending_key = ""
	_over_word = false
	_left_at = -1
	set_process(false)


## The words the open card is showing, joined - "" when it is closed. For the tests and harnesses.
func shown_text() -> String:
	if not visible:
		return ""
	var said: PackedStringArray = PackedStringArray()
	_collect_text(_box, said)
	return "\n".join(said)


## Presses the door labelled `label` on the open card, as a click would. False when there is none.
func press_door(label: String) -> bool:
	for node: Node in _box.find_children("", "BaseButton", true, false):
		if node is Button and (node as Button).text == label:
			(node as Button).pressed.emit()
			return true
	return false


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	if not _pending_key.is_empty() and _pending_key != _open_key and now - _pending_since >= SHOW_DELAY_MSEC:
		_open_pending()
	if visible:
		var on_card: bool = get_global_rect().has_point(get_global_mouse_position())
		if _over_word or on_card:
			_left_at = -1
		elif _left_at < 0:
			_left_at = now
		elif now - _left_at >= HIDE_DELAY_MSEC:
			close()
			return
	if not visible and _pending_key.is_empty():
		set_process(false)


func _open_pending() -> void:
	_build(_pending_card)
	_open_key = _pending_key
	visible = true
	# Built off screen (a test, a harness), the card has no window to sit in: its words are all there is.
	if not is_inside_tree():
		return
	reset_size()
	var width: float = size.x
	var position_x: float = _pending_anchor.position.x
	if str(_pending_card.get("anchor", "left")) == "right":
		position_x = _pending_anchor.end.x - width
	var top: float = _pending_anchor.end.y + EventSheetPalette.scaled_f(CARD_DROP)
	# Kept on the window: a card hanging off the edge would hide its own doors.
	var room: Rect2 = get_viewport_rect()
	position_x = clampf(position_x, room.position.x, maxf(room.end.x - width, room.position.x))
	global_position = Vector2(position_x, top)
	set_process(true)


func _build(card: Dictionary) -> void:
	for child: Node in _box.get_children():
		_box.remove_child(child)
		child.queue_free()
	add_theme_stylebox_override("panel", _card_style())
	# A card's width is the design's, drawn for a 12 px text: it grows with the editor's own font, so
	# a card wraps its words where the design does whatever size the editor reads at.
	var text_size: int = get_theme_font_size("font_size", "Label")
	var grow: float = maxf(float(text_size) / DESIGN_TEXT_SIZE, 0.5)
	var width: float = float(card.get("width", 300.0)) * grow
	var inner: float = width - EventSheetPalette.scaled_f(CARD_MARGIN) * 2.0
	custom_minimum_size = Vector2(width, 0.0)
	# The title: the bold name, and the muted kind beside it, as one line of text.
	var head: RichTextLabel = _paragraph(inner, text_size)
	var bold: Font = EventSheetPopupUI.editor_font("bold")
	if bold != null:
		head.add_theme_font_override("bold_font", bold)
	head.push_bold()
	head.add_text(str(card.get("title", "")))
	head.pop()
	var subtitle_text: String = str(card.get("subtitle", ""))
	if not subtitle_text.is_empty():
		head.push_color(EventSheetPopupUI.muted_text_color())
		head.add_text(" " + subtitle_text)
		head.pop()
	_box.add_child(head)
	var code_last: bool = bool(card.get("code_last", false))
	if not code_last:
		_add_mono(str(card.get("mono", "")), inner, text_size)
	# The behaviours lead the card's paragraph, "Spring 10 · Tween 10 · ...", each kind a door to its
	# own sheet where the scene names one; the card's first line follows them in the same paragraph.
	var lines: Array = Array(card.get("lines", PackedStringArray()))
	var links: Array = card.get("links", []) as Array
	if not links.is_empty():
		var said: PackedStringArray = PackedStringArray()
		for entry: Variant in links:
			var link: Array = entry as Array
			var words: String = str(link[0]).replace("[", "[lb]")
			var action: String = str(link[1]) if link.size() > 1 else ""
			said.append(words if action.is_empty() else "[url=%s]%s[/url]" % [action, words])
		var paragraph: RichTextLabel = _paragraph(inner, text_size)
		var follow: String = (" " + str(lines.pop_front()).replace("[", "[lb]")) if not lines.is_empty() else ""
		paragraph.text = "%s.%s" % [" · ".join(said), follow]
		paragraph.meta_clicked.connect(func(meta: Variant) -> void: _on_door(str(meta)))
		_box.add_child(paragraph)
	for line: Variant in lines:
		_box.add_child(_label(str(line), EventSheetPopupUI.text_color(), inner))
	for note: Variant in card.get("notes", PackedStringArray()):
		_box.add_child(_label(str(note), EventSheetPopupUI.muted_text_color(), inner))
	if code_last:
		_add_mono(str(card.get("mono", "")), inner, text_size)
	var doors: Array = card.get("doors", []) as Array
	if not doors.is_empty():
		# A file's options read as a short menu under a rule (a behaviour's or a global's card); any
		# other card's doors sit side by side as buttons.
		var as_list: bool = str(card.get("doors_layout", "")) == "list"
		var row: Container = VBoxContainer.new() if as_list else HFlowContainer.new()
		if as_list:
			row.add_theme_constant_override("separation", 0)
			_box.add_child(HSeparator.new())
		else:
			row.add_theme_constant_override("h_separation", int(round(EventSheetPalette.scaled_f(6.0))))
		for entry: Variant in doors:
			var door_entry: Array = entry as Array
			var button: Button = Button.new()
			button.text = str(door_entry[0])
			button.focus_mode = Control.FOCUS_NONE
			if as_list:
				button.flat = true
				button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.pressed.connect(_on_door.bind(str(door_entry[1])))
			row.add_child(button)
		_box.add_child(row)


## The card's line of code, muted and in the editor's code face; nothing for no code.
func _add_mono(mono_text: String, inner: float, text_size: int) -> void:
	if mono_text.is_empty():
		return
	var mono: Label = _label(mono_text, EventSheetPopupUI.muted_text_color(), inner)
	var source_font: Font = EventSheetPopupUI.editor_font("source")
	if source_font != null:
		mono.add_theme_font_override("font", source_font)
	mono.add_theme_font_size_override("font_size", maxi(int(round(text_size * MONO_TEXT_RATIO)), 8))
	_box.add_child(mono)


func _on_door(action: String) -> void:
	close()
	door_pressed.emit(action)


## A paragraph of styled text on the card: no panel of its own, the card's text size and colour,
## wrapped to `width`, as tall as its words.
func _paragraph(width: float, text_size: int) -> RichTextLabel:
	var paragraph: RichTextLabel = RichTextLabel.new()
	paragraph.bbcode_enabled = true
	paragraph.fit_content = true
	paragraph.scroll_active = false
	paragraph.meta_underlined = false
	paragraph.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	paragraph.custom_minimum_size = Vector2(width, 0.0)
	paragraph.add_theme_color_override("default_color", EventSheetPopupUI.text_color())
	# No panel of its own, and the same inset a Label of the card has, so every line starts in one place.
	var inset: StyleBoxEmpty = StyleBoxEmpty.new()
	var label_box: StyleBox = get_theme_stylebox("normal", "Label")
	if label_box != null:
		for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			inset.set_content_margin(side, label_box.get_margin(side))
	paragraph.add_theme_stylebox_override("normal", inset)
	paragraph.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	paragraph.add_theme_font_size_override("normal_font_size", text_size)
	paragraph.add_theme_font_size_override("bold_font_size", text_size)
	paragraph.add_theme_constant_override("line_separation", get_theme_constant("line_spacing", "Label"))
	return paragraph


## A wrapped paragraph of the card (`wrap_width` > 0) or a word that keeps its own width (0).
func _label(text: String, color: Color, wrap_width: float) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	if wrap_width > 0.0:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(wrap_width, 0.0)
	return label


## The editor's own tooltip panel, with the card's air and corners; a plain panel outside the editor.
func _card_style() -> StyleBox:
	var style: StyleBoxFlat = null
	var theme: Theme = EventSheetPopupUI.editor_theme()
	if theme != null and theme.has_stylebox("panel", "TooltipPanel"):
		style = theme.get_stylebox("panel", "TooltipPanel").duplicate() as StyleBoxFlat
	if style == null:
		style = StyleBoxFlat.new()
		style.bg_color = EventSheetPopupUI.panel_fill()
		style.border_color = EventSheetPopupUI.muted_text_color()
		style.set_border_width_all(1)
	style.set_corner_radius_all(int(round(EventSheetPalette.scaled_f(5.0))))
	style.set_content_margin_all(EventSheetPalette.scaled_f(CARD_MARGIN))
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.38)
	style.shadow_size = int(round(EventSheetPalette.scaled_f(8.0)))
	style.shadow_offset = Vector2(0.0, EventSheetPalette.scaled_f(4.0))
	return style


func _collect_text(node: Node, said: PackedStringArray) -> void:
	for child: Node in node.get_children():
		if child is Label:
			said.append((child as Label).text)
		elif child is Button:
			said.append("[%s]" % (child as Button).text)
		elif child is RichTextLabel:
			said.append((child as RichTextLabel).get_parsed_text())
		_collect_text(child, said)
