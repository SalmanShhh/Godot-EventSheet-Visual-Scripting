# Godot EventSheets - the light side of the Theme Editor window.
#
# Every colour of a theme has a dark swatch (the colour the theme has always held) and a light swatch beside
# it. The light swatch is the theme's own light colour when it has one, and otherwise it is worked out: a
# dashed "auto" swatch where the editor's greys give a different colour, a linked chain where the light side
# is simply the dark colour. A swatch whose words would read badly on their ground carries a small amber
# mark, and the strip says how badly. The window's Preview as switch changes only what the sample sheet is
# drawn as; the sheet itself always wears the side that matches Godot's editor theme.
#
# DELIBERATELY NO `class_name`: the window builds it by path when a theme is opened, so nothing else
# compiles it. Everything it changes goes through the window's own undo list.
@tool
extends RefCounted


const LIGHT_PATH := "res://addons/eventsheet/theme/light_colors.gd"
const PAIRS_PATH := "res://addons/eventsheet/theme/theme_contrast_pairs.gd"
const SWATCH_PATH := "res://addons/eventsheet/editor/theme_light_swatch.gd"
const MARK_GLYPH := "!"
## The width of the name column on a row that has a light side, wide enough for the longest token name, so the
## dark swatches, the chains and the light swatches stand in columns down the form.
const NAME_COLUMN_WIDTH := 230.0
## Words the sheet draws that the shared list does not hold to a bar (the native look keeps them quiet), which a
## generated theme still moves until they can be read: the scope word of a variable row.
const GENERATED_PAIRS: Array = [
	["variable scope word on a row", "reading", "variable_row_rule_color", "event:row_background_color", 3.0],
	["variable scope word on its wash", "reading", "variable_row_rule_color", "reading:variable_row_wash_color", 4.5],
	["muted words on a variable wash", "reading", "muted_text_color", "reading:variable_row_wash_color", 4.5],
	["secondary words on a variable wash", "reading", "secondary_text_color", "reading:variable_row_wash_color", 4.5],
	["inspector words on a variable wash", "reading", "inspector_chip_foreground_color", "reading:variable_row_wash_color", 4.5],
	["inspector chip words on their chip", "reading", "inspector_chip_foreground_color", "reading:inspector_chip_background_color", 4.5],
	["inspector chip words on a row", "reading", "inspector_chip_foreground_color", "event:row_background_color", 4.5],
]

## True while the sample sheet is previewed as a light editor would draw it.
var preview_light: bool = false

var _window: EventSheetThemeEditor = null
var _cache: Dictionary = {}
## One entry per colour row that has a light side: block, section, token, link, light, mark, dark.
var _rows: Array[Dictionary] = []
var _dark_button: Button = null
var _light_button: Button = null


func _init(window: EventSheetThemeEditor) -> void:
	_window = window
	preview_light = editor_is_light()


static func _light() -> GDScript:
	return load(LIGHT_PATH)


static func _pairs() -> GDScript:
	return load(PAIRS_PATH)


## Whether the running editor is a light one (never, outside the editor).
static func editor_is_light() -> bool:
	var base: Color = EventSheetEditorThemeDeriver.running_editor_base()
	return base.a > 0.0 and EventSheetEditorThemeDeriver.is_light_base(base)


# ── Preview as ────────────────────────────────────────────────────────────────────────────────────


## The row above the sample sheet: Preview as, Dark, Light. It opens on the editor's own mode.
func build_preview_header() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", EventSheetPopupUI.ROW_SEPARATION)
	var label: Label = Label.new()
	label.text = EventSheetL10n.translate("Preview as")
	row.add_child(label)
	var group: ButtonGroup = ButtonGroup.new()
	_dark_button = _mode_button(EventSheetL10n.translate("Dark"), group, false)
	_light_button = _mode_button(EventSheetL10n.translate("Light"), group, true)
	row.add_child(_dark_button)
	row.add_child(_light_button)
	(_light_button if preview_light else _dark_button).set_pressed_no_signal(true)
	return row


func _mode_button(text: String, group: ButtonGroup, light: bool) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.toggle_mode = true
	button.button_group = group
	# The chosen side reads as pressed in every editor theme, the way Godot's own toggle buttons do.
	var chosen: StyleBoxFlat = StyleBoxFlat.new()
	var accent: Color = EventSheetPopupUI.accent_color()
	chosen.bg_color = accent.lightened(0.55) if editor_is_light() else accent.darkened(0.35)
	chosen.set_corner_radius_all(3)
	chosen.set_content_margin_all(EventSheetPalette.scaled_f(5.0))
	for state: String in ["pressed", "hover_pressed"]:
		button.add_theme_stylebox_override(state, chosen)
	for ink_state: String in ["font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(ink_state, Color.BLACK if editor_is_light() else Color.WHITE)
	button.tooltip_text = EventSheetL10n.translate("Only the sample sheet changes. Your sheet wears the side that matches Godot's editor theme.")
	button.pressed.connect(func() -> void: set_preview_light(light))
	return button


func set_preview_light(on: bool) -> void:
	preview_light = on
	if _dark_button != null:
		(_dark_button if on else _light_button).set_pressed_no_signal(false)
		(_light_button if on else _dark_button).set_pressed_no_signal(true)
	_window._repaint_preview()


## The editor base the sample sheet is drawn for: clear while the preview matches the running editor, so the
## viewport asks the running editor itself, and a reference base of the other mode otherwise.
func preview_base() -> Color:
	if editor_is_light() == preview_light and EventSheetEditorThemeDeriver.running_editor_base().a > 0.0:
		return Color(0.0, 0.0, 0.0, 0.0)
	return EventSheetEditorThemeDeriver.NATIVE_LIGHT_REFERENCE_BASE if preview_light \
		else EventSheetEditorThemeDeriver.NATIVE_DARK_REFERENCE_BASE


## The theme as the sample sheet draws it.
func preview_look() -> EventSheetEditorStyle:
	var base: Color = preview_base()
	if base.a <= 0.0:
		base = EventSheetEditorThemeDeriver.running_editor_base()
	return EventSheetEditorThemeDeriver.sheet_look(_window._working_style, base)


# ── What each side holds ──────────────────────────────────────────────────────────────────────────


## Forgets the two looks worked out so far: call after anything that changes the theme.
func invalidate() -> void:
	_cache.clear()


## The theme drawn by a light editor: its light colours on top, the editor's greys under them when it follows them.
func light_look() -> EventSheetEditorStyle:
	if not _cache.has("light"):
		_cache["light"] = EventSheetEditorThemeDeriver.sheet_look(_window._working_style,
			EventSheetEditorThemeDeriver.NATIVE_LIGHT_REFERENCE_BASE)
	return _cache["light"]


## The theme as a light editor would draw it with no light colour of its own: what an "auto" swatch shows.
func auto_look() -> EventSheetEditorStyle:
	if not _cache.has("auto"):
		_cache["auto"] = EventSheetEditorThemeDeriver.sheet_look(_light().without_entries(_window._working_style),
			EventSheetEditorThemeDeriver.NATIVE_LIGHT_REFERENCE_BASE)
	return _cache["auto"]


## The section name ("event", "condition", ...) of a block of the open theme, or "" for anything else.
func section_of(block: Resource) -> String:
	for pair: Array in _light().blocks_of(_window._working_style):
		if pair[1] == block:
			return str(pair[0])
	return ""


static func _block_in(style: EventSheetEditorStyle, section: String) -> Resource:
	for pair: Array in _light().blocks_of(style):
		if str(pair[0]) == section:
			return pair[1]
	return null


## How the light side of one token stands: {"value": the colour it draws, "own": a light colour was chosen,
## "linked": it is the dark colour and nothing more}.
func light_side(block: Resource, token: String) -> Dictionary:
	var dark: Color = block.get(token)
	var chosen: Variant = _light().entry_of(block, token)
	if chosen != null:
		return {"value": chosen, "own": true, "linked": false}
	var worked_out: Color = _block_in(auto_look(), section_of(block)).get(token)
	return {"value": worked_out, "own": false, "linked": worked_out == dark}


## Whether the theme draws any differently in a light editor than in a dark one.
func opted_in() -> bool:
	return _window._working_style.follow_editor_greys or _light().has_entries(_window._working_style)


## A token whose words would read under the bar on its ground, on one side: {} when it reads well, or
## {"ratio", "bar", "against", "side"}. The light side is judged on the colours a light editor draws.
func finding(block: Resource, token: String, light: bool) -> Dictionary:
	var section: String = section_of(block)
	if section.is_empty() or not _pairs().is_words(section, token):
		return {}
	if light and not opted_in():
		return {}
	var weak: Dictionary = _pairs().weak_pair(light_look() if light else _window._working_style, section, token)
	if weak.is_empty():
		return {}
	weak["side"] = EventSheetL10n.translate("Light") if light else EventSheetL10n.translate("Dark")
	return weak


## The sentence the strip adds for a swatch that reads badly, on the side being previewed first.
func contrast_sentence(block: Resource, token: String) -> String:
	var found: Dictionary = finding(block, token, preview_light)
	if found.is_empty():
		found = finding(block, token, not preview_light)
	if found.is_empty():
		return ""
	return EventSheetL10n.translate("Contrast %s : 1 on %s (%s); %s : 1 reads comfortably.") % [
		"%.1f" % float(found["ratio"]), found["against"], found["side"], "%.1f" % float(found["bar"])]


## The line the file holds for a token's light side, or the words that say it holds none.
func light_file_line(block: Resource, token: String) -> String:
	var side: Dictionary = light_side(block, token)
	if bool(side["own"]):
		return "light_colors[&\"%s\"] = %s" % [token, var_to_str(side["value"])]
	if bool(side["linked"]):
		return EventSheetL10n.translate("(no light line: one colour for both)")
	return EventSheetL10n.translate("(no light line: worked out from the editor)")


# ── The swatches ──────────────────────────────────────────────────────────────────────────────────


## A line above a section's rows that names its two columns.
func column_header() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", EventSheetPopupUI.ROW_SEPARATION)
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(NAME_COLUMN_WIDTH), 0.0)
	row.add_child(spacer)
	var dark: Label = _column_label(EventSheetL10n.translate("Dark"))
	var link_room: Control = Control.new()
	link_room.custom_minimum_size = _link_button(false).get_combined_minimum_size()
	var light: Label = _column_label(EventSheetL10n.translate("Light"))
	row.add_child(dark)
	row.add_child(link_room)
	row.add_child(light)
	return row


func _column_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.modulate = Color(1.0, 1.0, 1.0, 0.74)
	return label


func _link_button(linked: bool) -> Button:
	var button: Button = EventSheetLookStyle.icon_button(&"Instance" if linked else &"Unlinked", "∞" if linked else "∘", "")
	button.flat = false
	return button


## Whether this block's colours can have a light side.
func supports(block: Resource) -> bool:
	return not section_of(block).is_empty()


## Adds the chain, the light swatch and the mark to a colour row whose dark swatch is already in it.
func add_controls(row: HBoxContainer, block: Resource, token: String, hover: Callable) -> void:
	(row.get_child(0) as Control).custom_minimum_size.x = EventSheetPalette.scaled_f(NAME_COLUMN_WIDTH)
	var link: Button = _link_button(false)
	var light: ColorPickerButton = load(SWATCH_PATH).new() as ColorPickerButton
	light.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var mark: Label = Label.new()
	mark.text = MARK_GLYPH
	mark.mouse_filter = Control.MOUSE_FILTER_STOP
	mark.add_theme_color_override("font_color", EventSheetPopupUI.tone_color(EventSheetPopupUI.TONE_WARNING))
	row.add_child(link)
	row.add_child(light)
	row.add_child(mark)
	var entry: Dictionary = {"block": block, "token": token, "link": link, "light": light, "mark": mark, "row": row}
	_rows.append(entry)
	link.pressed.connect(func() -> void: toggle_link(block, token))
	light.color_changed.connect(func(value: Color) -> void: edit_light(block, token, value))
	for part: Control in [link, light, mark]:
		part.mouse_entered.connect(hover)
	light.focus_entered.connect(hover)
	_show(entry)


## Forgets every row: the form is being rebuilt.
func forget_rows() -> void:
	_rows.clear()
	invalidate()


## Brings every light swatch, chain and mark in line with the theme.
func refresh_all() -> void:
	for entry: Dictionary in _rows:
		if is_instance_valid(entry["light"]):
			_show(entry)


func _show(entry: Dictionary) -> void:
	var block: Resource = entry["block"]
	var token: String = str(entry["token"])
	var side: Dictionary = light_side(block, token)
	var light: ColorPickerButton = entry["light"]
	var link: Button = entry["link"]
	light.color = side["value"]
	light.set("auto", not bool(side["own"]) and not bool(side["linked"]))
	var linked: bool = bool(side["linked"])
	var picture: Texture2D = EventSheetLookStyle.icon(&"Instance" if linked else &"Unlinked")
	if picture != null:
		link.icon = picture
	else:
		link.text = "∞" if linked else "∘"
	link.tooltip_text = EventSheetL10n.translate("Same colour in dark and light: click to give light its own") if linked \
		else EventSheetL10n.translate("Separate colours: click to use the dark colour in both")
	light.tooltip_text = EventSheetL10n.translate("Worked out from the editor. Pick a colour to give light its own.") \
		if bool(light.get("auto")) else ""
	var mark: Label = entry["mark"]
	var dark_weak: Dictionary = finding(block, token, false)
	var light_weak: Dictionary = finding(block, token, true)
	var weak: bool = not dark_weak.is_empty() or not light_weak.is_empty()
	# The mark keeps its room while it is not shown, so the swatches stand in the same columns on every row.
	mark.modulate.a = 1.0 if weak else 0.0
	mark.mouse_filter = Control.MOUSE_FILTER_STOP if weak else Control.MOUSE_FILTER_IGNORE
	mark.tooltip_text = contrast_sentence(block, token)


# ── Changes ───────────────────────────────────────────────────────────────────────────────────────


## A light colour picked for a token.
func edit_light(block: Resource, token: String, value: Color) -> void:
	_change(block, token, value)


## The chain clicked: a linked token is given a light colour of its own to start from the dark one; any
## other token goes back to using the dark colour in both, with no light line where the editor's greys
## would give that colour anyway.
func toggle_link(block: Resource, token: String) -> void:
	var dark: Color = block.get(token)
	if bool(light_side(block, token)["linked"]):
		_change(block, token, dark)
		return
	var worked_out: Color = _block_in(auto_look(), section_of(block)).get(token)
	_change(block, token, null if worked_out == dark else dark)


## Sets (or, for null, takes away) a token's light colour as one step of the window's undo list.
func _change(block: Resource, token: String, after: Variant) -> void:
	var before: Variant = _light().entry_of(block, token)
	if before == after:
		return
	_put(block, token, after)
	_window._record_edit({"style": block, "token": token, "light": true, "from": before, "to": after})
	_changed(block, token)


func _put(block: Resource, token: String, value: Variant) -> void:
	if value == null:
		_light().clear_entry(block, token)
	else:
		_light().set_entry(block, token, value as Color)


func _changed(block: Resource, token: String) -> void:
	invalidate()
	refresh_all()
	_window._repaint_preview()
	_window._focus_token(block, token)


## One side of a light step of the window's undo list put back.
func step(entry: Dictionary, side: String) -> void:
	_put(entry["style"], str(entry["token"]), entry[side])
	_changed(entry["style"], str(entry["token"]))


# ── Quick Style, twice ────────────────────────────────────────────────────────────────────────────


## Fills the light column from the editor's own light hand: the look Godot's light editor gets (every fill,
## word and mark already read on their ground) with the light base, the accent and the light text laid on
## top. Every colour that differs from the dark column becomes the theme's light colour, and every other
## colour goes back to having none. Then any words in either column that still read under their bar are
## moved toward black or white until they clear it, so a generated theme carries no mark. Returns how many
## light colours the theme holds afterwards.
func generate(light_base: Color, accent: Color, light_text: Color) -> int:
	var style: EventSheetEditorStyle = _window._working_style
	var hand: EventSheetEditorStyle = EventSheetEditorThemeDeriver.native_style(light_base).duplicate(true) as EventSheetEditorStyle
	hand.ensure_defaults()
	var hand_event: EventSheetEventStyle = hand.get_event_style()
	hand_event.group_accent_color = accent
	hand_event.group_title_color = light_text
	hand_event.trigger_badge_background_color = accent
	hand_event.selection_fill_color = Color(accent.r, accent.g, accent.b, 0.16)
	hand.get_condition_style().text_color = light_text
	hand.get_action_style().text_color = light_text
	var held: int = 0
	for pair: Array in _light().blocks_of(style):
		var block: Resource = pair[1]
		var lit: Resource = _block_in(hand, str(pair[0]))
		for info: Dictionary in block.get_property_list():
			var usage: int = int(info.get("usage", 0))
			if not (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) or int(info.get("type", TYPE_NIL)) != TYPE_COLOR:
				continue
			var token: String = str(info["name"])
			if lit.get(token) != block.get(token):
				_light().set_entry(block, token, lit.get(token))
				held += 1
			else:
				_light().clear_entry(block, token)
	invalidate()
	make_legible()
	return held


## Moves every word colour that reads under its bar on its ground toward black or white until it clears the
## bar, first in the dark column and then in the light one, over the pairs the contrast test holds.
func make_legible() -> void:
	for light: bool in [false, true]:
		for pair: Array in _pairs().PAIRS + GENERATED_PAIRS:
			var look: EventSheetEditorStyle = light_look() if light else _window._working_style
			var measured: Dictionary = _pairs().measure(look, pair)
			if float(measured["ratio"]) >= float(measured["bar"]):
				continue
			var block: Resource = _block_in(_window._working_style, str(pair[1]))
			var token: String = str(pair[2])
			var moved: Color = _nudged(measured["ink"], measured["fill"], float(measured["bar"]))
			if not light:
				block.set(token, moved)
			elif moved == block.get(token):
				_light().clear_entry(block, token)
			else:
				_light().set_entry(block, token, moved)
			invalidate()


## `ink` moved toward whichever of black and white stands furthest from `fill`, in small steps, until it
## reads at `bar` or better on `fill`. The result is opaque.
static func _nudged(ink: Color, fill: Color, bar: float) -> Color:
	var target: Color = Color.WHITE if fill.get_luminance() < 0.5 else Color.BLACK
	var moved: Color = Color(ink.r, ink.g, ink.b, 1.0)
	for step_count: int in range(40):
		if EventSheetEditorThemeDeriver.contrast_ratio(moved, fill) >= bar + 0.05:
			break
		moved = moved.lerp(target, 0.1)
	return moved
