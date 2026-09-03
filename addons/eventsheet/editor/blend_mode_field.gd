# Godot EventSheets - the field a blend mode is CHOSEN in, by looking at it.
#
# A blend mode is the one parameter in the vocabulary whose words do not tell a reader what they
# will get. "Overlay", "hard light", "luminosity" are names from a trade, and a person who has never
# used them is being asked to guess. A dropdown of twenty such words is not a choice, it is a list to
# try one at a time.
#
# So this field SHOWS them: a small picture - one shape over one backdrop - drawn through every mode
# there is, in five groups (the ones the renderer draws by itself, the light-and-dark family, the two
# that compare, the four that take a colour apart, and the plain copy). The reader picks the picture
# that looks like the thing they wanted.
#
# IT IS A LineEdit, because the parameters dialog's editor seam
# (EventSheets.register_param_editor) hands the value back by reading `.text` - so the field stays a
# field. Typing a mode word, or a whole expression that works one out at run time, goes on working
# exactly as it would in any other parameter box; the button on the right is the shortcut, not the
# only door.
#
# THE PICTURES ARE DRAWN HERE, ON THE PROCESSOR, and they mirror the arithmetic the pack's shaders
# do on the graphics card. They have to agree, so they are written the same way (one expression per
# mode, in the same order), and the suite pins a handful of them against values worked out by hand.
# A picture drawn by the real shader would need a viewport, a frame and the pack installed; this one
# needs none of the three, which is why the strip is there the first time anybody opens the field.
@tool
class_name EventSheetBlendModeField
extends LineEdit

## The parameter hint this field answers to. A pack (or a project's own vocabulary) asks for the
## strip by naming this hint on its parameter, and nothing else has to know about it.
const HINT := "blend_mode"

## How big one picture in the strip is. Small enough that twenty of them fit without scrolling,
## large enough that a soft edge and a colour shift are both visible.
const THUMBNAIL_WIDTH := 44
const THUMBNAIL_HEIGHT := 28

## The five shelves the twenty modes are shown on, in the order a reader meets them: what the
## renderer does by itself first, then the family everyone actually reaches for.
const GROUPS: Array = [
	{"title": "Native", "modes": ["normal", "add", "subtract", "multiply", "premultiplied"]},
	{"title": "Light and dark", "modes": ["screen", "overlay", "darken", "lighten", "colour dodge",
		"colour burn", "hard light", "soft light"]},
	{"title": "Compare", "modes": ["difference", "exclusion"]},
	{"title": "Colour", "modes": ["hue", "saturation", "colour", "luminosity"]},
	{"title": "Copy", "modes": ["copy"]}
]

## The five native modes, named here as well as in the pack because THIS file has to say which
## pictures are drawn without a shader - the strip marks them, so a reader can tell the free ones
## from the ones that read the screen before they choose.
const NATIVE_MODES: PackedStringArray = ["normal", "add", "subtract", "multiply", "premultiplied"]

## The pictures drawn so far, by mode word. Twenty small images, drawn once per editor session.
static var _thumbnails: Dictionary = {}

# The popup this field opens, built the first time it is asked for and kept after that.
var _strip: PopupPanel = null

# The button that opens it, which also WEARS the current mode's picture - so the field shows what it
# is set to without a second widget.
var _open_button: Button = null


## Registers the strip as the editor for the `blend_mode` hint, and the paragraph the parameters
## dialog's help strip says under such a field. Idempotent: a second call (a plugin reload, a test)
## leaves exactly one registration.
static func ensure_registered() -> void:
	EventSheets.register_param_editor(HINT, Callable(EventSheetBlendModeField, "make_field"))
	EventSheets.register_param_help(HINT, EventSheetL10n.translate("Pick the look by looking at it: the button shows one shape over one backdrop drawn through every mode. The five under Native are the ones the renderer draws by itself and cost nothing; the rest read the screen back, which costs one screen read per pixel the item covers. You can also type a mode word, or an expression that works one out while the game runs."))


## The factory the seam calls: one field, opened on whatever the row already holds.
static func make_field(param: Dictionary, initial_text: String) -> LineEdit:
	var field: EventSheetBlendModeField = EventSheetBlendModeField.new()
	field.text = initial_text
	field.build(param)
	return field


## Every mode the strip offers, in the order it shows them - the list the tests walk and the one a
## caller asks rather than restating.
static func mode_words() -> PackedStringArray:
	var words: PackedStringArray = PackedStringArray()
	for group: Dictionary in GROUPS:
		for mode: String in (group["modes"] as Array):
			words.append(mode)
	return words


## One mode's picture: the shape composited over the backdrop through that mode. Drawn once and kept
## for the session, because the arithmetic is the same every time it is asked for.
static func thumbnail(mode: String) -> Texture2D:
	if _thumbnails.has(mode):
		return _thumbnails[mode] as Texture2D
	var picture: Image = Image.create(THUMBNAIL_WIDTH, THUMBNAIL_HEIGHT, false, Image.FORMAT_RGBA8)
	for y: int in THUMBNAIL_HEIGHT:
		for x: int in THUMBNAIL_WIDTH:
			var under: Color = backdrop_at(x, y)
			var paint: Color = paint_at(x, y)
			picture.set_pixel(x, y, under.lerp(blended(mode, under, paint), paint.a))
	var drawn: Texture2D = ImageTexture.create_from_image(picture)
	_thumbnails[mode] = drawn
	return drawn


## The backdrop the shape is drawn over: a wash that runs from a deep blue to a warm light, so a mode
## that only shows on dark pixels and one that only shows on light ones both have somewhere to show.
static func backdrop_at(x: int, y: int) -> Color:
	var across: float = float(x) / float(THUMBNAIL_WIDTH - 1)
	var down: float = float(y) / float(THUMBNAIL_HEIGHT - 1)
	return Color(0.08 + 0.80 * across, 0.14 + 0.34 * down, 0.44 - 0.30 * across + 0.28 * down)


## The shape drawn over it: one soft-edged disc of a strong colour. Its alpha is how much of the
## blend lands, exactly as an item's own alpha is in the shader.
static func paint_at(x: int, y: int) -> Color:
	var across: float = float(x) / float(THUMBNAIL_WIDTH - 1) - 0.5
	var down: float = (float(y) / float(THUMBNAIL_HEIGHT - 1) - 0.5) * float(THUMBNAIL_HEIGHT) / float(THUMBNAIL_WIDTH)
	var out_from_centre: float = Vector2(across, down).length()
	return Color(0.93, 0.42, 0.62, clampf((0.30 - out_from_centre) / 0.07, 0.0, 1.0))


## One pixel, blended. `under` is what has already been drawn there and `paint` is the item's own
## colour; the answer is the two of them mixed the way the named mode mixes them.
##
## THE SAME ARITHMETIC AS THE SHADERS, written once per mode in the same order they are shipped in.
## A mode nothing here knows is drawn as a plain copy rather than as an error, because a strip is a
## preview: a project's own mode word must still be typeable in the box.
static func blended(mode: String, under: Color, paint: Color) -> Color:
	match mode:
		"hue":
			return with_lum(with_sat(paint, saturation_of(under)), lum_of(under))
		"saturation":
			return with_lum(with_sat(under, saturation_of(paint)), lum_of(under))
		"colour":
			return with_lum(paint, lum_of(under))
		"luminosity":
			return with_lum(under, lum_of(paint))
	return Color(channel(mode, under.r, paint.r), channel(mode, under.g, paint.g),
		channel(mode, under.b, paint.b))


## One channel of the modes that work channel by channel. `base` is the pixel underneath and `top`
## the item's own; both are 0 to 1.
static func channel(mode: String, base: float, top: float) -> float:
	match mode:
		"normal", "copy", "premultiplied":
			return top
		"add":
			return minf(1.0, base + top)
		"subtract":
			return maxf(0.0, base - top)
		"multiply":
			return base * top
		"screen":
			return 1.0 - (1.0 - base) * (1.0 - top)
		"overlay":
			return _hard_light(top, base)
		"hard light":
			return _hard_light(base, top)
		"darken":
			return minf(base, top)
		"lighten":
			return maxf(base, top)
		"colour dodge":
			return minf(1.0, base / maxf(1.0 - top, 0.0001))
		"colour burn":
			return 1.0 - minf(1.0, (1.0 - base) / maxf(top, 0.0001))
		"soft light":
			if top < 0.5:
				return 2.0 * base * top + base * base * (1.0 - 2.0 * top)
			return 2.0 * base * (1.0 - top) + sqrt(maxf(base, 0.0)) * (2.0 * top - 1.0)
		"difference":
			return absf(base - top)
		"exclusion":
			return base + top - 2.0 * base * top
	return top


## How bright a colour is, by the weights every compositing tool uses.
static func lum_of(colour: Color) -> float:
	return colour.r * 0.3 + colour.g * 0.59 + colour.b * 0.11


## How strong its colour is: the distance between its brightest and its dullest channel.
static func saturation_of(colour: Color) -> float:
	return maxf(colour.r, maxf(colour.g, colour.b)) - minf(colour.r, minf(colour.g, colour.b))


## The same colour at another brightness, pulled back inside the range if that took it outside.
static func with_lum(colour: Color, lum: float) -> Color:
	var shift: float = lum - lum_of(colour)
	return _clipped(Color(colour.r + shift, colour.g + shift, colour.b + shift))


## The same colour at another strength of colour, keeping which hue it is.
static func with_sat(colour: Color, sat: float) -> Color:
	var low: float = minf(colour.r, minf(colour.g, colour.b))
	var high: float = maxf(colour.r, maxf(colour.g, colour.b))
	if high <= low:
		return Color(0.0, 0.0, 0.0)
	var span: float = high - low
	return Color((colour.r - low) * sat / span, (colour.g - low) * sat / span,
		(colour.b - low) * sat / span)


## Builds the field: the button that wears the current mode and opens the strip.
func build(param: Dictionary) -> void:
	tooltip_text = ""
	placeholder_text = str(param.get("default", ""))
	_open_button = Button.new()
	_open_button.flat = true
	_open_button.focus_mode = Control.FOCUS_NONE
	_open_button.tooltip_text = EventSheetL10n.translate("Pick a blend mode by looking at it")
	_open_button.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_open_button.offset_left = -float(THUMBNAIL_WIDTH) - 8.0
	_open_button.offset_right = -2.0
	_open_button.offset_top = 2.0
	_open_button.offset_bottom = -2.0
	_open_button.pressed.connect(_open_strip)
	add_child(_open_button)
	_show_current()
	text_changed.connect(func(_typed: String) -> void: _show_current())


## The button wears whatever the box currently says, so the field itself is the preview. A box
## holding an expression rather than a mode word wears no picture, because there is nothing honest
## to show for a value only the running game knows.
func _show_current() -> void:
	if _open_button == null:
		return
	var word: String = text.strip_edges().trim_prefix("\"").trim_suffix("\"")
	_open_button.icon = thumbnail(word) if mode_words().has(word) else null


## Opens the strip under the field.
func _open_strip() -> void:
	if _strip == null:
		_strip = _build_strip()
		add_child(_strip)
	_strip.popup_on_parent(Rect2i(Vector2i(0, int(size.y)), Vector2i(1, 1)))


## The strip itself: five shelves, each a title and a row of pictures.
func _build_strip() -> PopupPanel:
	var panel: PopupPanel = PopupPanel.new()
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	for group: Dictionary in GROUPS:
		var heading: Label = Label.new()
		heading.text = EventSheetL10n.translate(str(group["title"]))
		heading.add_theme_font_size_override("font_size", EventSheetPalette.scaled(11))
		heading.modulate = Color(1.0, 1.0, 1.0, 0.6)
		column.add_child(heading)
		var shelf: HFlowContainer = HFlowContainer.new()
		column.add_child(shelf)
		for mode: String in (group["modes"] as Array):
			shelf.add_child(_mode_button(mode))
	return panel


## One picture in the strip, with the mode's word under it and, for a native mode, the fact that it
## costs nothing - which is the one thing about a mode a reader cannot see in the picture.
func _mode_button(mode: String) -> Button:
	var choice: Button = Button.new()
	choice.icon = thumbnail(mode)
	choice.text = mode
	choice.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	choice.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	choice.expand_icon = false
	choice.tooltip_text = EventSheetL10n.translate("Drawn by the renderer itself - costs nothing") \
		if NATIVE_MODES.has(mode) else EventSheetL10n.translate("Reads the screen back through a shader - one screen read per pixel this item covers")
	choice.pressed.connect(func() -> void: _choose(mode))
	return choice


## A picture clicked: the word lands in the box exactly as if it had been typed, and the dialog's own
## watchers hear about it the same way.
func _choose(mode: String) -> void:
	text = mode
	_show_current()
	text_changed.emit(mode)
	if _strip != null:
		_strip.hide()


## Overlay's curve, which hard light is the same curve with the two sides swapped.
static func _hard_light(base: float, top: float) -> float:
	if top < 0.5:
		return 2.0 * base * top
	return 1.0 - 2.0 * (1.0 - base) * (1.0 - top)


## A colour pulled back inside 0 to 1 around its own brightness, so a brightness change never turns
## into a colour shift at the ends.
static func _clipped(colour: Color) -> Color:
	var lum: float = lum_of(colour)
	var low: float = minf(colour.r, minf(colour.g, colour.b))
	var high: float = maxf(colour.r, maxf(colour.g, colour.b))
	var pulled: Color = colour
	if low < 0.0:
		var towards_low: float = lum / maxf(lum - low, 0.0001)
		pulled = Color(lum + (pulled.r - lum) * towards_low, lum + (pulled.g - lum) * towards_low,
			lum + (pulled.b - lum) * towards_low)
	if high > 1.0:
		var towards_high: float = (1.0 - lum) / maxf(high - lum, 0.0001)
		pulled = Color(lum + (pulled.r - lum) * towards_high, lum + (pulled.g - lum) * towards_high,
			lum + (pulled.b - lum) * towards_high)
	return Color(clampf(pulled.r, 0.0, 1.0), clampf(pulled.g, 0.0, 1.0), clampf(pulled.b, 0.0, 1.0))
