# EventSheet - shared popup UI helpers.
#
# A single, consistent look for the plugin's dialogs (aligned "Label  [field]" rows, standard
# content margins, a standard form box) so every popup matches the Godot 4.7 editor styling
# instead of each one inventing its own margins + label placement. Pure factory helpers - they
# return controls the caller parents; they apply no logic of their own, so they are unit-testable.
@tool
class_name EventSheetPopupUI
extends RefCounted

const CONTENT_MARGIN := 12
const ROW_SEPARATION := 8
const LABEL_MIN_WIDTH := 120.0
## Default wrap width (px) for hint/wrapping labels. A ConfirmationDialog/AcceptDialog sizes to its
## content's MINIMUM, and an UNBOUNDED autowrap label reports a runaway one-glyph-per-line min height
## during the initial zero-width pass - which balloons the whole dialog. Giving the label a minimum
## width makes that pass wrap at a sane width while the label still wraps wider at runtime.
const HINT_WRAP_WIDTH := 360.0
## The label drag that tunes a number, read by path when a form row is built: naming it would
## compile it into every first open that paints with this kit.
const NUMBER_SCRUB_PATH := "res://addons/eventsheet/editor/number_scrub.gd"


## Hardens a CodeEdit against the most common user syntax errors: auto-CLOSES brackets and quotes (typing
## "(" inserts "()" with the caret inside, '"' inserts ""), so an unbalanced pair is hard to leave behind,
## and matching brackets highlight. Applied to every EDITABLE code field - the ƒx expression boxes and the
## GDScript-block dialog - so users (especially non-coders) rarely produce a bracket/quote syntax error in
## the first place. Pure setter on the passed control → unit-testable, safe headless.
static func configure_code_editor(edit: CodeEdit) -> void:
	if edit == null:
		return
	edit.auto_brace_completion_enabled = true
	edit.auto_brace_completion_highlight_matching = true
	edit.auto_brace_completion_pairs = {"(": ")", "[": "]", "{": "}", "\"": "\"", "'": "'"}


## An aligned "Label   [field]" row - the consistent form layout for the plugin's dialogs. The
## label takes a fixed leading width so stacked rows align; the field expands to fill the rest.
##
## Pass `tooltip` and the row explains itself on hover. It lands on the LABEL as well as the field,
## because the label is the part a puzzled user actually points at - a field name like "Inspector
## button" is exactly the kind of term that means nothing until someone says what it does. Note the
## mouse_filter: Godot Labels ignore the mouse by default, so a tooltip set on one never fires. Any
## caller passing a tooltip would silently get nothing without this line.
static func form_row(label_text: String, field: Control, label_min_width: float = LABEL_MIN_WIDTH,
		tooltip: String = "") -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", ROW_SEPARATION)
	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(label_min_width, 0.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	if not tooltip.strip_edges().is_empty():
		label.tooltip_text = tooltip
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		# The field carries the same words, so hovering anywhere on the row answers the question - and
		# a field that already explains itself in its own terms keeps that more specific text.
		if field.tooltip_text.strip_edges().is_empty():
			field.tooltip_text = tooltip
	row.add_child(label)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(field)
	# Every form row in the plugin gets number scrubbing for free: drag the label sideways to
	# tune a numeric field. A no-op for controls that hold no number, so callers need no test.
	var scrub: Script = load(NUMBER_SCRUB_PATH)
	scrub.attach(label, field)
	if scrub.is_scrubbable(scrub.read_value(field)):
		var scrub_hint: String = "Drag this label sideways to scrub the value (Shift = fine, Ctrl = coarse)."
		label.tooltip_text = scrub_hint if label.tooltip_text.strip_edges().is_empty() else "%s\n\n%s" % [label.tooltip_text, scrub_hint]
		label.mouse_filter = Control.MOUSE_FILTER_STOP
	return row


## A standard form VBox (consistent row separation) to hold form_row()s + helper labels.
static func form_box() -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", ROW_SEPARATION)
	return box


## Wraps content in a standard-margin container for a dialog/window body, so every popup has the
## same breathing room as the editor's own dialogs.
static func margined(content: Control, margin: int = CONTENT_MARGIN) -> MarginContainer:
	var box: MarginContainer = MarginContainer.new()
	box.add_theme_constant_override("margin_left", margin)
	box.add_theme_constant_override("margin_right", margin)
	box.add_theme_constant_override("margin_top", margin)
	box.add_theme_constant_override("margin_bottom", margin)
	box.add_child(content)
	return box


## A side window the dock keeps (History, Outline, Bookmarks, the sheet map): `title` on the window
## and on the one card that fills it, closing hides it, and it lives under `host`. Returns {window,
## box} - `box` is the card's column to fill.
##
## Give it `ok_text` and it is a FORM window instead: a ConfirmationDialog whose OK calls `on_ok` and
## leaves the window open, because what stops OK is said on the window itself (a StateNote under the
## field) - `on_ok` hides it once the work is done. `hide_on_ok` is for a form OK cannot refuse: OK
## closes it, the way a plain ConfirmationDialog does. A non-zero `size` is the form's least size. The
## title is on the window, so the form fills it with no card heading repeating it.
static func panel_window(title: String, size: Vector2i, host: Node, ok_text: String = "",
		on_ok: Callable = Callable(), hide_on_ok: bool = false) -> Dictionary:
	if not ok_text.is_empty():
		var dialog: ConfirmationDialog = ConfirmationDialog.new()
		dialog.title = title
		dialog.visible = false
		dialog.ok_button_text = ok_text
		dialog.dialog_hide_on_ok = hide_on_ok
		if size != Vector2i.ZERO:
			dialog.min_size = size
		if on_ok.is_valid():
			dialog.confirmed.connect(on_ok)
		var form: VBoxContainer = form_box()
		dialog.add_child(margined(form))
		host.add_child(dialog)
		return {"window": dialog, "box": form}
	var window: Window = Window.new()
	window.title = title
	window.size = size
	window.close_requested.connect(func() -> void: window.hide())
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card: Control = titled_card(title, box)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	window.add_child(window_body(card))
	host.add_child(window)
	return {"window": window, "box": box}


## A plain Window's whole body: `content` with the kit's margins on a backdrop painted in the editor's
## own base colour. A Window paints nothing of its own, so without it the margins around the cards
## showed the renderer's clear colour - a mid grey that reads as a hole in a light editor theme.
## Added to its window, the backdrop also gives it what a kit dialog already has (WindowBackdrop).
static func window_body(content: Control) -> Control:
	var backdrop: PanelContainer = WindowBackdrop.new()
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	var theme: Theme = editor_theme()
	fill.bg_color = theme.get_color("base_color", "Editor") if theme != null and theme.has_color("base_color", "Editor") \
		else Color(0.13, 0.14, 0.17, 1.0)
	backdrop.add_theme_stylebox_override("panel", fill)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(margined(content))
	return backdrop


## Opens a window centred at the size of what it holds NOW - or `least` where that is bigger, a zero
## side meaning "the content's". For a window built once and opened again: popup_centered() with no
## size reopens a window at the size it had last time, and a window only ever grows on its own, so a
## form once opened on a long text stayed that big - empty space and all - for the rest of the session.
## Measured again once its labels have wrapped at their real width (WindowBackdrop.SETTLE_SECONDS):
## the first layout reads a wrapping label narrower, so taller, than it ends up, and the window grows to
## that guess. The second measure takes the guess back, about the window's centre.
static func popup_fitted(window: Window, least: Vector2i = Vector2i.ZERO) -> void:
	if window == null or not window.is_inside_tree():
		return
	window.popup_centered(fitted_size(window, least))
	window.get_tree().create_timer(WindowBackdrop.SETTLE_SECONDS).timeout.connect(func() -> void:
		if not is_instance_valid(window) or not window.visible:
			return
		var fitted: Vector2i = fitted_size(window, least)
		if fitted.x < window.size.x or fitted.y < window.size.y:
			var centre: Vector2i = window.position + window.size / 2
			window.size = fitted.min(window.size)
			window.position = centre - window.size / 2
	)


## The size popup_fitted opens `window` at: its content's minimum, raised to `least` and to the
## window's own min_size. Never zero, which popup_centered would read as "keep the old size".
static func fitted_size(window: Window, least: Vector2i = Vector2i.ZERO) -> Vector2i:
	var content: Vector2i = Vector2i(window.get_contents_minimum_size().ceil())
	return content.max(least).max(window.min_size).max(Vector2i.ONE)


## The backdrop window_body puts under a plain Window, and the two things a dialog does that a bare
## Window does not. It GROWS TO FIT what it holds once it is shown: a Window keeps the size it was
## given, so a fixed size smaller than the content cut its foot off (the Bookmarks card, the Replay
## Recorder's checkpoint button), and words in a longer language cut more. Measured a moment after the
## window shows, once its labels have wrapped at their real width - following the content all along
## (wrap_controls), or measuring at the end of the frame that showed it, grew the Debugger three
## screens tall from the first layout's one-word-a-line guess, and a window never shrinks back. And
## ESC CLOSES IT, when nothing inside used the key first, through the window's own close_requested,
## so a window that does something on close (the Doctor writes down what was read) still does it.
class WindowBackdrop extends PanelContainer:

	## How long after showing the window is measured: long enough for its labels to have wrapped
	## at the width they were given, so a label is never read at the one-word-a-line first guess.
	const SETTLE_SECONDS := 0.1


	## Each time the window shows: when it is shown, and when it enters the tree already showing (a
	## Window is visible from birth, so one added and popped in the same breath never changes).
	func _notification(what: int) -> void:
		if what == NOTIFICATION_PARENTED and get_parent() is Window:
			(get_parent() as Window).visibility_changed.connect(_fit_once_settled)
		elif what == NOTIFICATION_ENTER_TREE:
			_fit_once_settled()


	func _fit_once_settled() -> void:
		if is_inside_tree() and get_parent() is Window and (get_parent() as Window).visible:
			get_tree().create_timer(SETTLE_SECONDS).timeout.connect(fit_window)


	## Makes the window at least as big as what it holds, and no smaller than it already is.
	func fit_window() -> void:
		var window: Window = get_parent() as Window
		if window != null:
			window.size = window.size.max(Vector2i(window.get_contents_minimum_size().ceil()))


	func _unhandled_key_input(event: InputEvent) -> void:
		if not event.is_action_pressed("ui_cancel") or not get_parent() is Window:
			return
		if get_viewport() != null:
			get_viewport().set_input_as_handled()
		(get_parent() as Window).close_requested.emit()


## A ONE-SHOT FILE PICKER over `host` on `filters` (each like "*.gd ; Sheet" or "*.svg, *.png"): calls
## `picked` with the chosen path, and frees itself whether a file was picked or not. `options` may
## carry "title", "save" (a Save dialog), "disk" (anywhere on disk, not only res://), "path" (the file
## it starts on), "dir" (the folder it starts in) and "size" (else 60% of the screen). It is the
## editor's own EditorFileDialog, which exists only in the editor - outside it nothing opens and a path
## is typed into the field instead - unless "plain" asks for Godot's FileDialog. Returns the picker.
static func browse_file(host: Node, filters: PackedStringArray, picked: Callable,
		options: Dictionary = {}) -> ConfirmationDialog:
	var plain: bool = bool(options.get("plain", false))
	if not plain and (not Engine.is_editor_hint() or host == null or not host.is_inside_tree()):
		return null
	var browser: ConfirmationDialog = FileDialog.new() if plain else EditorFileDialog.new()
	browser.set("file_mode", FileDialog.FILE_MODE_SAVE_FILE if bool(options.get("save", false)) else FileDialog.FILE_MODE_OPEN_FILE)
	browser.set("access", FileDialog.ACCESS_FILESYSTEM if bool(options.get("disk", false)) else FileDialog.ACCESS_RESOURCES)
	browser.set("filters", filters)
	for key: String in ["dir", "path"]:
		if options.has(key):
			browser.set("current_" + key, str(options[key]))
	# Last, because a file dialog retitles itself whenever its mode is set.
	if options.has("title"):
		browser.title = str(options["title"])
	browser.connect("file_selected", func(path: String) -> void:
		picked.call(path)
		browser.queue_free())
	browser.canceled.connect(browser.queue_free)
	host.add_child(browser)
	if options.has("size"):
		browser.popup_centered(options["size"])
	else:
		browser.popup_centered_ratio(0.6)
	return browser


## A muted helper/hint label (the small explanatory text under a field). The autowrap is WIDTH-BOUNDED
## (wrap_width) so it never balloons a content-sized dialog - see HINT_WRAP_WIDTH. Pass a smaller
## wrap_width in a narrower dialog if the default would widen it.
static func hint_label(text: String, wrap_width: float = HINT_WRAP_WIDTH) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(wrap_width, 0.0)
	label.modulate = Color(1.0, 1.0, 1.0, 0.74)
	return label

## Inner padding (px) baked into a panel_section()'s background, so its contents don't touch the edges.
const PANEL_SECTION_PAD := 6.0


## Wraps `content` in a filled "inset card" - a PanelContainer whose background sits a touch darker than
## the dialog, with a hairline border + rounded corners (Godot's Create-New-Node side-pane look), so a
## section reads as a distinct sunken panel instead of floating on the dialog background. Use it to give
## the picker's Favorites/Recent/description areas real visual separation. The caller still sets the
## panel's size flags if it should expand.
static func panel_section(content: Control, pad: float = PANEL_SECTION_PAD) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = inset_panel_stylebox()
	style.set_content_margin_all(pad)
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(content)
	return panel


## A section-title label for grouping a dialog into legible blocks - full opacity, a touch larger,
## tinted with the editor's accent so a section reads as a heading rather than just another form row.
## Falls back to a neutral blue outside the editor (headless tests / non-editor runtime).
static func section_header(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", EventSheetPalette.scaled(13))
	label.add_theme_color_override("font_color", accent_color())
	return label


## A titled inset card - a section_header above panel_section(content). The standard "labelled section"
## block, so every dialog groups its content into the same legible, themed panels instead of a flat
## wall of rows. The caller still sets the returned panel's size flags if it should expand.
static func titled_card(title: String, content: Control, pad: float = PANEL_SECTION_PAD) -> PanelContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", ROW_SEPARATION)
	box.add_child(section_header(title))
	box.add_child(content)
	return panel_section(box, pad)


## The StyleBoxFlat behind panel_section() (and any card that wants the matching look): a filled inset
## with a subtle border + 4px corners. Editor-theme-aware - the fill comes from the editor's `dark_color_2`
## (the same tone Godot's own inset panels use) and the border from `contrast_color_1`; both fall back to
## neutral dark values outside the editor (headless tests / non-editor runtime) so it never errors.
static func inset_panel_stylebox() -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	var border: Color = Color(1.0, 1.0, 1.0, 0.07)
	var theme: Theme = editor_theme()
	if theme != null and theme.has_color("contrast_color_1", "Editor"):
		var contrast: Color = theme.get_color("contrast_color_1", "Editor")
		border = Color(contrast.r, contrast.g, contrast.b, 0.22)
	box.bg_color = panel_fill()
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	return box


# ── The "Compact Developer" reference primitives ──────────────────────────────────────────────
#
# The documentation surfaces (the Explain panel, the guide pages, the browser chrome) all draw
# from this handful of factories rather than hand-rolling their own controls, so the style is ONE
# thing: small-caps accent section labels, metadata badges, a code card, a dense table, and a band
# that stacks when it is narrow. Every one of them is a pure factory - it returns a Control the
# caller parents, applies no logic and reads no global state beyond the editor theme.
#
# THE COLOUR RULE this set encodes: accent is for SECTION LABELS and the active nav item, and for
# nothing else. Badges carry their own tone, table headers are neutral-muted, body prose is left
# at the theme's own colour. Anything that shouts twice stops meaning anything.

## The tone a "kind" badge wears (Action / Condition / Trigger) when the editor accent is not
## available. The accent itself is preferred - see metadata_badge's default.
const BADGE_NEUTRAL := Color(0.58, 0.74, 1.0)
## The tone a pack/category badge wears. Deliberately the only purple on the page.
const BADGE_PACK := Color(0.72, 0.55, 1.0)
## Small-caps label size, before display scaling.
const SMALL_CAPS_FONT_SIZE := 11
## Glyph spacing (px, before scaling) that turns a plain uppercase label into a letter-spaced one.
const SMALL_CAPS_TRACKING := 1
## Cell padding inside a compact_table cell, before display scaling.
const TABLE_CELL_PAD_H := 6.0
const TABLE_CELL_PAD_V := 3.0
## The rule under a table's header row. Neutral on purpose: accent belongs to the small-caps section
## labels and to the active navigation row, and a table that spent it on its column names would put
## three accents on one screen. Shared so the guide pages' BBCode tables (which cannot use
## compact_table - their cells carry links) can be kept looking like the ones that can.
const TABLE_HAIRLINE := Color(1.0, 1.0, 1.0, 0.16)
## The width (px, before display scaling) at or above which a responsive_band draws its two
## children side by side. Below it they stack. One number, so every band in the plugin agrees.
const TWO_COLUMN_MIN_WIDTH := 560.0


## The editor's accent colour, or a neutral blue outside the editor (headless tests, a non-editor
## run). The one place the accent is read, so every surface tints from the same source.
static func accent_color() -> Color:
	var theme: Theme = editor_theme()
	if theme != null and theme.has_color("accent_color", "Editor"):
		return theme.get_color("accent_color", "Editor")
	return BADGE_NEUTRAL


## The editor's theme, or null outside the editor (headless tests, a non-editor run). The one
## place it is fetched, so every colour and font below reads the same source.
static func editor_theme() -> Theme:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return null
	var editor_interface: Object = Engine.get_singleton("EditorInterface")
	if editor_interface == null or not editor_interface.has_method("get_editor_theme"):
		return null
	return editor_interface.get_editor_theme()


## The fill of an inset dialog panel: the editor's `dark_color_2`, the tone Godot's own inset
## panels use - light in a light editor theme, dark in a dark one.
static func panel_fill() -> Color:
	var theme: Theme = editor_theme()
	if theme != null and theme.has_color("dark_color_2", "Editor"):
		return theme.get_color("dark_color_2", "Editor")
	return Color(0.12, 0.13, 0.16, 1.0)


## TEXT ON A DIALOG PANEL. The panels take their fill from the editor theme, so their text has to
## as well: a fixed light grey reads on the dark theme and all but vanishes on the light one. The
## primary voice is the theme's own Label colour; the secondary and muted voices are that colour
## moved part of the way toward the panel fill, so they stay quieter in both themes without ever
## fading into the panel. Outside the editor the palette's dark-theme values stand.
static func text_color() -> Color:
	var theme: Theme = editor_theme()
	if theme != null and theme.has_color("font_color", "Label"):
		return theme.get_color("font_color", "Label")
	return EventSheetPalette.TEXT_PRIMARY


static func secondary_text_color() -> Color:
	return _quieter_text(0.18, EventSheetPalette.TEXT_SECONDARY)


static func muted_text_color() -> Color:
	return _quieter_text(0.3, EventSheetPalette.TEXT_MUTED)


static func _quieter_text(amount: float, fallback: Color) -> Color:
	if editor_theme() == null:
		return fallback
	return text_color().lerp(panel_fill(), amount)


## A coloured voice (ok green, warning amber, error red, a badge tone) made readable on the panel:
## those tones are picked for the dark theme, so on a light panel they are darkened until they
## read as text instead of as a pale wash.
static func readable_on_panel(color: Color) -> Color:
	if panel_fill().get_luminance() < 0.5:
		return color
	return color.darkened(0.45)


## One of the editor's own documentation fonts by name ("doc", "doc_bold", "doc_source"), or null
## outside the editor where the default font is the only one there is. Callers fall back rather
## than fail: a missing font must degrade to plain text, never to an error.
static func editor_font(font_name: String) -> Font:
	var theme: Theme = editor_theme()
	if theme == null or not theme.has_font(font_name, "EditorFonts"):
		return null
	return theme.get_font(font_name, "EditorFonts")


## A SMALL-CAPS SECTION LABEL - uppercase, letter-spaced, small, accent-tinted. The only
## accent-coloured text a reference page carries, which is what makes the eye read these as the
## page's skeleton instead of as decoration. Pass `color` to override the accent (a card that is
## already tinted, a warning section).
##
## Letter spacing is a FontVariation over the label's own font: Godot's Label has no tracking
## property, and faking it by interleaving spaces would break every translation.
static func small_caps_label(text: String, color: Color = Color(0.0, 0.0, 0.0, 0.0)) -> Label:
	var label: Label = Label.new()
	label.text = text.to_upper()
	label.add_theme_font_size_override("font_size", EventSheetPalette.scaled(SMALL_CAPS_FONT_SIZE))
	label.add_theme_color_override("font_color", accent_color() if color.a <= 0.0 else color)
	var tracked: FontVariation = small_caps_font(label.get_theme_font("font"))
	if tracked != null:
		label.add_theme_font_override("font", tracked)
	return label


## The letter-spaced font a small-caps label wears, over `fallback` when the editor's own bold
## documentation font is not available. Split out of small_caps_label because not every small-caps
## row in the plugin IS a Label - a Tree group heading is a TreeItem, which can be given a font but
## cannot host a control - and two spellings of "small caps" side by side read as a mistake.
## Returns null when there is no font to vary at all, which callers treat as "leave it alone".
static func small_caps_font(fallback: Font = null) -> FontVariation:
	var base: Font = editor_font("doc_bold")
	if base == null:
		base = fallback
	if base == null:
		return null
	var tracked: FontVariation = FontVariation.new()
	tracked.base_font = base
	tracked.set_spacing(TextServer.SPACING_GLYPH, EventSheetPalette.scaled(SMALL_CAPS_TRACKING))
	return tracked


## A METADATA BADGE - the small filled pill that sits beside a page title ("Action", "Quest").
## Badges are metadata, never decoration: one for what the verb IS, one for where it comes from,
## and nothing else, or the row of pills stops carrying information.
static func metadata_badge(text: String, tone: Color = Color(0.0, 0.0, 0.0, 0.0)) -> PanelContainer:
	var color: Color = accent_color() if tone.a <= 0.0 else tone
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.18)
	style.border_color = Color(color.r, color.g, color.b, 0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(int(EventSheetPalette.scaled_f(3.0)))
	style.content_margin_left = EventSheetPalette.scaled_f(6.0)
	style.content_margin_right = EventSheetPalette.scaled_f(6.0)
	style.content_margin_top = EventSheetPalette.scaled_f(1.0)
	style.content_margin_bottom = EventSheetPalette.scaled_f(1.0)
	panel.add_theme_stylebox_override("panel", style)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", EventSheetPalette.scaled(10))
	label.add_theme_color_override("font_color", badge_text_color(color, panel_fill().get_luminance() >= 0.5))
	panel.add_child(label)
	return panel


## A badge's words over its own tint: lifted off a dark panel, pressed darker into a light one, where
## a lifted amber on an amber wash all but vanished.
static func badge_text_color(tone: Color, light_panel: bool) -> Color:
	return tone.darkened(0.25) if light_panel else tone.lightened(0.25)


## A CODE CARD - monospace text in an inset panel with a copy button in its top-right corner.
## The copy button is the card's whole reason to be a widget rather than a label: a reader who
## wants the line wants it in their clipboard, and a hand-selected label loses the wrapping.
## `wrap_width` bounds the autowrap (see hint_label for why an unbounded one balloons its host).
static func code_card(code: String, wrap_width: float = HINT_WRAP_WIDTH) -> PanelContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(4.0)))
	var label: Label = Label.new()
	label.text = code
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(wrap_width, 0.0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var mono: Font = editor_font("doc_source")
	if mono != null:
		label.add_theme_font_override("font", mono)
	row.add_child(label)
	row.add_child(copy_button(code))
	return panel_section(row)


## The copy affordance a code card wears: an icon button that puts `text` on the clipboard. Split
## out so any surface wanting "copy this exact string" gets the same button. Headless-safe - a
## platform with no clipboard simply does nothing rather than erroring.
static func copy_button(text: String) -> Button:
	var button: Button = Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = "Copy to the clipboard"
	button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var icon: Texture2D = _editor_icon("ActionCopy")
	if icon != null:
		button.icon = icon
	else:
		button.text = "⧉"
	button.pressed.connect(func() -> void:
		if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
			DisplayServer.clipboard_set(text))
	return button


## A COMPACT TABLE - a dense grid under a hairline header row (the parameters table's shape:
## Name | Type | Default | Description). Facts belong in a table; a reference page that writes
## them as prose makes the reader parse a sentence to find a default.
##
## `headers` names the columns, `rows` is an Array of PackedStringArray (one per row, short rows
## padded with blanks), and `expand_column` is the index of the column that takes the slack and
## wraps - the description, normally. Pass -1 for a table where every column hugs its text.
static func compact_table(headers: PackedStringArray, rows: Array, expand_column: int = -1) -> GridContainer:
	var grid: GridContainer = GridContainer.new()
	grid.columns = maxi(headers.size(), 1)
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	for column: int in range(headers.size()):
		grid.add_child(_table_cell(headers[column], true, column == expand_column))
	for entry: Variant in rows:
		var cells: PackedStringArray = PackedStringArray(entry)
		for column: int in range(headers.size()):
			var text: String = cells[column] if column < cells.size() else ""
			grid.add_child(_table_cell(text, false, column == expand_column))
	return grid


## One cell. A header cell carries the hairline: a bottom border on every header cell reads as one
## continuous rule across the row, which is why the grid runs at zero separation.
static func _table_cell(text: String, is_header: bool, expands: bool) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.content_margin_left = EventSheetPalette.scaled_f(TABLE_CELL_PAD_H)
	style.content_margin_right = EventSheetPalette.scaled_f(TABLE_CELL_PAD_H)
	style.content_margin_top = EventSheetPalette.scaled_f(TABLE_CELL_PAD_V)
	style.content_margin_bottom = EventSheetPalette.scaled_f(TABLE_CELL_PAD_V)
	if is_header:
		style.border_color = TABLE_HAIRLINE
		style.border_width_bottom = 1
	panel.add_theme_stylebox_override("panel", style)
	if expands:
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label: Label = Label.new()
	label.text = text.to_upper() if is_header else text
	label.add_theme_font_size_override("font_size", EventSheetPalette.scaled(10 if is_header else 11))
	label.add_theme_color_override("font_color",
		EventSheetPopupUI.muted_text_color() if is_header else EventSheetPopupUI.text_color())
	if expands:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(120.0), 0.0)
	panel.add_child(label)
	return panel


## Whether a band of `available_width` draws its two children SIDE BY SIDE. Pure, so the
## breakpoint is pinned by a test instead of by a screenshot.
static func prefers_two_columns(available_width: float, min_width: float = TWO_COLUMN_MIN_WIDTH) -> bool:
	return available_width >= min_width


## A RESPONSIVE BAND - `first` and `second` side by side when there is room, stacked when there is
## not. The decision is re-taken on every resize, so the same page reads correctly in a wide window
## and in a dock-width column without the caller knowing which it is in.
##
## It is a plain BoxContainer whose `vertical` flag is flipped, never a re-parenting of the
## children: re-parenting would drop focus and rebuild a live figure on every splitter drag.
static func responsive_band(first: Control, second: Control,
		min_width: float = TWO_COLUMN_MIN_WIDTH) -> BoxContainer:
	var band: BoxContainer = BoxContainer.new()
	band.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(ROW_SEPARATION)))
	first.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	second.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	band.add_child(first)
	band.add_child(second)
	band.vertical = true
	var limit: float = EventSheetPalette.scaled_f(min_width)
	band.resized.connect(func() -> void:
		var stacked: bool = not prefers_two_columns(band.size.x, limit)
		if band.vertical != stacked:
			band.vertical = stacked)
	return band


## A LABELLED CARD - the Compact Developer counterpart to titled_card(): the same inset panel, but
## headed by a small-caps section label instead of a sentence-case header. Use it for a reference
## section ("ABOUT QUEST"); titled_card stays the dialog form.
static func labelled_card(label_text: String, content: Control, pad: float = PANEL_SECTION_PAD) -> PanelContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", ROW_SEPARATION)
	box.add_child(small_caps_label(label_text))
	box.add_child(content)
	return panel_section(box, pad)


## THE HELP STRIP - the one explanatory foot every dialog wears.
##
## A dialog used to answer "what is this field?" with a hint label under each field, so ten fields
## meant ten paragraphs on screen at once and the reader had to find the one that mattered. This is
## the other way round: ONE strip at the foot, and it describes whatever is FOCUSED right now. It
## replaces the tooltip rather than joining it - a tooltip only appears if you already suspected the
## field needed explaining.
##
## Four parts, in reading order: a heading naming the focused thing ("Scope · Instance"), a
## paragraph, a READS AS line showing the row the choices will write, and an IN CODE line showing
## the line the compiler will emit. Either line hides when its text is empty - a dialog with no code
## behind it (the Sheet type dialog) simply never fills one.
##
## `follow()` wires a control to the strip: focusing it (or hovering it) swaps the heading and the
## paragraph. `follow_option()` does the same per ITEM of a dropdown, so arrowing down an option list
## describes each choice BEFORE it is picked. The reading lines are set by the dialog itself, live,
## because only the dialog knows what its fields currently add up to.
class HelpStrip extends PanelContainer:

	## The accent rule down the left edge, in px before display scaling.
	const ACCENT_RULE_WIDTH := 3
	## The most lines a reading line (READS AS, IN CODE, an added line) wraps to before it ends in "...".
	const READING_MAX_LINES := 4

	## The three tones the strip speaks in. "" is the ordinary describing voice; a warning is
	## something that compiles but will surprise; an error is something that cannot be meant. The
	## same two colours - and the same wording - the sheet's own row notes use, because the dialog
	## and the row are one check run at two times.
	const TONE_NORMAL := ""
	const TONE_WARNING := "warning"
	const TONE_ERROR := "error"

	var heading_label: Label = null
	var body_label: Label = null
	var reads_as_row: HBoxContainer = null
	var reads_as_value: Label = null
	var in_code_row: HBoxContainer = null
	var in_code_value: Label = null
	## The one-click answers to whatever the strip is complaining about. Empty (and hidden) while
	## the strip is merely describing something.
	var fixes_row: HBoxContainer = null
	## The way OUT of the dialog and into the guide section that teaches this row. Its own row rather
	## than a fix, because a fix answers a problem with the value in front of you and this answers
	## "I do not know what this row is for" - and because show_note() rebuilds the fixes on every
	## keystroke, while the row being written does not change while the dialog is open.
	var learn_more_row: HBoxContainer = null
	## Which voice the strip is speaking in right now - readable, so a test can pin the state
	## without sampling a colour.
	var tone: String = TONE_NORMAL
	## Every field this strip was told to follow, in wiring order. The strip is the one place a
	## dialog explains itself, so "is every field wired to it" is a question worth being able to ask
	## of a built dialog rather than of its source (see EventSheetPopupUI.probe_help_dialog).
	var followed: Array[Control] = []

	var _panel_style: StyleBoxFlat = null


	func _init(wrap_width: float = EventSheetPopupUI.HINT_WRAP_WIDTH) -> void:
		var style: StyleBoxFlat = EventSheetPopupUI.inset_panel_stylebox()
		style.set_content_margin_all(EventSheetPalette.scaled_f(8.0))
		style.content_margin_left = EventSheetPalette.scaled_f(12.0)
		style.border_width_left = EventSheetPalette.scaled(ACCENT_RULE_WIDTH)
		style.border_color = EventSheetPopupUI.accent_color()
		add_theme_stylebox_override("panel", style)
		_panel_style = style
		var box: VBoxContainer = VBoxContainer.new()
		box.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(6.0)))
		add_child(box)
		heading_label = EventSheetPopupUI.small_caps_label("")
		box.add_child(heading_label)
		body_label = Label.new()
		body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body_label.custom_minimum_size = Vector2(wrap_width, 0.0)
		box.add_child(body_label)
		fixes_row = HBoxContainer.new()
		fixes_row.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(6.0)))
		fixes_row.visible = false
		box.add_child(fixes_row)
		learn_more_row = HBoxContainer.new()
		learn_more_row.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(6.0)))
		learn_more_row.visible = false
		box.add_child(learn_more_row)
		reads_as_row = _reading_row(EventSheetL10n.translate("READS AS"))
		reads_as_value = reads_as_row.get_child(1) as Label
		box.add_child(reads_as_row)
		in_code_row = _reading_row(EventSheetL10n.translate("IN CODE"))
		in_code_value = in_code_row.get_child(1) as Label
		var mono: Font = EventSheetPopupUI.editor_font("doc_source")
		if mono != null:
			in_code_value.add_theme_font_override("font", mono)
		box.add_child(in_code_row)


	## One reading line: a muted small-caps caption and the value beside it. Hidden until filled.
	## The value WRAPS inside the strip's own width: a line that did not wrap was as wide as what it
	## said, so a long comment, group description or value opened its whole window thousands of
	## pixels wide. It has a width of its own too, or a wrapping label measures one glyph per line on
	## the window's first pass and stretches the window tall instead. And it stops at READING_MAX_LINES
	## with an ellipsis, the whole line in its hover: a long value is in the field above it already, and
	## twenty wrapped lines of it made the window taller than the screen.
	func _reading_row(caption: String) -> HBoxContainer:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(10.0)))
		row.visible = false
		var label: Label = EventSheetPopupUI.small_caps_label(caption, EventSheetPopupUI.muted_text_color())
		# The caption stays beside the line's first row, not halfway down a wrapped value.
		label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(label)
		var value: Label = Label.new()
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		value.custom_minimum_size = Vector2(body_label.custom_minimum_size.x * 0.75, 0.0)
		value.max_lines_visible = READING_MAX_LINES
		value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		value.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(value)
		return row


	## One more reading line under the two above, for a window with a third fact worth a caption of
	## its own ("ALSO CALLED", "INSERTS"), or above them with `first`. Returns its value label; fill it
	## with set_line().
	func add_line(caption: String, first: bool = false) -> Label:
		var row: HBoxContainer = _reading_row(caption)
		var value: Label = row.get_child(1) as Label
		in_code_row.get_parent().add_child(row)
		if first:
			row.get_parent().move_child(row, reads_as_row.get_index())
		return value


	## Fills a line add_line() made; an empty text hides it, like the two reading lines.
	func set_line(value: Label, text: String) -> void:
		value.text = text
		value.tooltip_text = text
		value.get_parent().visible = not text.strip_edges().is_empty()


	## Says what the focused thing is. The heading names it, the paragraph explains it. An empty one
	## hides, so a strip made only of captioned lines starts with its first line.
	func describe(heading: String, body: String) -> void:
		heading_label.text = heading.to_upper()
		heading_label.visible = not heading.is_empty()
		body_label.text = body
		body_label.visible = not body.is_empty()


	## The two reading lines, set by the dialog whenever its values change. An empty line hides,
	## so a dialog with no code behind it never shows an empty IN CODE caption.
	func set_reading(reads_as: String, in_code: String = "") -> void:
		reads_as_value.text = reads_as
		reads_as_value.tooltip_text = reads_as
		reads_as_row.visible = not reads_as.strip_edges().is_empty()
		# A label draws a tab as nothing, so a body line of a several-line row (`if ...:` then its
		# indented step) lost its indent and read as a sibling of the `if`. Four spaces per tab is the
		# editor's own width.
		in_code_value.text = in_code.replace("\t", "    ")
		in_code_value.tooltip_text = in_code_value.text
		in_code_row.visible = not in_code.strip_edges().is_empty()


	## The voice the strip speaks in: the ordinary accent, amber for a warning, red for an error.
	## Recolours the rule down the left edge and the heading together, so the tone is legible from
	## the corner of the eye without reading a word.
	func set_tone(level: String) -> void:
		tone = level
		var colour: Color = EventSheetPopupUI.tone_color(level)
		if _panel_style != null:
			_panel_style.border_color = colour
		heading_label.add_theme_color_override("font_color", colour)


	## The one-click answers offered under the paragraph. Each entry is {"text": String,
	## "pressed": Callable}; an empty list hides the row. Rebuilt rather than reused, because the
	## fixes on offer change with every keystroke and a stale button is a wrong answer.
	func offer_fixes(fixes: Array) -> void:
		for old_button: Node in fixes_row.get_children():
			fixes_row.remove_child(old_button)
			old_button.queue_free()
		for fix: Variant in fixes:
			if not (fix is Dictionary):
				continue
			var entry: Dictionary = fix
			var button: Button = Button.new()
			button.text = str(entry.get("text", ""))
			var action: Variant = entry.get("pressed", null)
			if action is Callable and (action as Callable).is_valid():
				button.pressed.connect(action as Callable)
			fixes_row.add_child(button)
		fixes_row.visible = fixes_row.get_child_count() > 0


	## The door out of the dialog and into the written guide: one flat link naming the section that
	## teaches this row, and where it lands. An empty label hides the row, which is what a verb the
	## guides do not cover gets - a dead "Learn more" is worse than none.
	##
	## Rebuilt rather than reused, so a second call replaces the landing instead of stacking a
	## second link beside a stale one.
	func offer_learn_more(label: String, action: Callable = Callable()) -> void:
		for old_link: Node in learn_more_row.get_children():
			learn_more_row.remove_child(old_link)
			old_link.queue_free()
		if label.strip_edges().is_empty() or not action.is_valid():
			learn_more_row.visible = false
			return
		var link: Button = Button.new()
		link.text = label
		link.flat = true
		link.tooltip_text = EventSheetL10n.translate("Opens the guide section that teaches this, at the heading itself.")
		link.pressed.connect(action)
		learn_more_row.add_child(link)
		learn_more_row.visible = true


	## Heading, paragraph, tone and fixes in one call - the shape every caller actually wants, and
	## the one that cannot leave last field's red rule standing over this field's description.
	func show_note(heading: String, body: String, level: String = TONE_NORMAL, fixes: Array = []) -> void:
		describe(heading, body)
		set_tone(level)
		offer_fixes(fixes)


	## Wires a control: focusing or hovering it makes the strip describe it. Note the mouse_filter -
	## a Label ignores the mouse by default, so a caption wired here would never fire without it.
	##
	## `body_provider` (a Callable returning String) overrides `body` at the moment the control is
	## reached, for the field whose explanation depends on the state the dialog is in - a tick that
	## is greyed out has to be able to say WHY, and a greyed tick is exactly what the reader asks
	## the strip about.
	func follow(control: Control, heading: String, body: String, body_provider: Callable = Callable()) -> void:
		if control == null:
			return
		if control.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			control.mouse_filter = Control.MOUSE_FILTER_PASS
		var describe_now: Callable = func() -> void:
			show_note(heading, str(body_provider.call()) if body_provider.is_valid() else body)
		control.focus_entered.connect(describe_now)
		control.mouse_entered.connect(describe_now)
		followed.append(control)


	## Wires every field of a built form the way follow() does - each field's own label and tooltip are
	## its heading and words, so there is one place a field's wording lives - and calls `reread` as one
	## is reached (and once now), so the reading lines say what is typed NOW rather than what the
	## window opened with.
	func follow_form(form: EventSheetFieldForm, reread: Callable) -> void:
		for field_id: String in form.field_ids():
			var spec: EventSheetFieldSpec = form.spec(field_id)
			var control: Control = form.control(field_id)
			if spec == null or control == null:
				continue
			follow(control, spec.label, spec.tooltip_text)
			control.focus_entered.connect(reread)
			control.mouse_entered.connect(reread)
		reread.call()


	## Wires a dropdown per ITEM: `describer.call(index)` returns {"heading": …, "body": …} for the
	## item at `index`. Arrowing or hovering the open list describes the choice before it is picked
	## (PopupMenu.id_focused), and picking one leaves that description standing.
	func follow_option(option: OptionButton, describer: Callable) -> void:
		if option == null or not describer.is_valid():
			return
		var apply: Callable = func(index: int) -> void:
			var told: Variant = describer.call(index)
			# An empty answer means "nothing to say about this one" (a separator): the strip keeps
			# whatever it was showing rather than blanking itself as the list is arrowed past one.
			if told is Dictionary and not (told as Dictionary).is_empty():
				show_note(str((told as Dictionary).get("heading", "")), str((told as Dictionary).get("body", "")))
		option.item_selected.connect(apply)
		option.focus_entered.connect(func() -> void: apply.call(option.selected))
		followed.append(option)
		var popup: PopupMenu = option.get_popup()
		if popup != null:
			popup.id_focused.connect(apply)


## The help strip, ready to parent at the foot of a dialog. Exactly ONE per dialog: the strip's whole
## point is that there is one place the reader looks for an explanation.
static func help_strip(heading: String = "", body: String = "", reads_as: String = "",
		in_code: String = "", wrap_width: float = HINT_WRAP_WIDTH) -> HelpStrip:
	var strip: HelpStrip = HelpStrip.new(wrap_width)
	strip.describe(heading, body)
	strip.set_reading(reads_as, in_code)
	return strip


## THE DIALOG PROBE: what a built dialog says about itself, without a display server.
##
## Every dialog in this editor is the same shape - fields, and ONE help strip at the foot that
## describes whichever field is focused - and the shape is only kept if something checks it. This
## answers, for any built UI:
##   strips        how many help strips it holds (one, or the shape is broken)
##   fields        the focusable controls in it
##   wired         the ones the strip was told to follow
##   unwired       the ones it was not, BY NAME - the fields with nothing to say for themselves
##   follows_focus true when focusing each wired field in turn actually changes what the strip says
##   reads_as / in_code   the two reading lines, as the reader would see them
##
## Focus is delivered by emitting `focus_entered` rather than by grabbing it, which is what lets this
## run in the suite: a real grab needs a Viewport and a display server, and the signal is the whole
## of what the wiring listens to.
static func probe_help_dialog(node: Node) -> Dictionary:
	var strips: Array[HelpStrip] = []
	var fields: Array[Control] = []
	_gather_dialog_parts(node, strips, fields)
	var probe: Dictionary = {"strips": strips.size(), "fields": fields.size(), "wired": 0,
		"unwired": PackedStringArray(), "follows_focus": false, "reads_as": "", "in_code": ""}
	if strips.size() != 1:
		return probe
	var strip: HelpStrip = strips[0]
	var followed: Array[Control] = strip.followed
	var unwired: PackedStringArray = PackedStringArray()
	for field: Control in fields:
		if not followed.has(field):
			unwired.append(field.name)
	probe["wired"] = followed.size()
	probe["unwired"] = unwired
	probe["reads_as"] = strip.reads_as_value.text
	probe["in_code"] = strip.in_code_value.text
	probe["follows_focus"] = _strip_follows_focus(strip, followed)
	return probe


## True when focusing each followed field in turn leaves the strip saying something DIFFERENT from
## what the field before it left standing. One field is a trivial yes; a dialog whose fields all
## share one description is a no, and it should be.
static func _strip_follows_focus(strip: HelpStrip, followed: Array[Control]) -> bool:
	if followed.is_empty():
		return false
	var said: PackedStringArray = PackedStringArray()
	for field: Control in followed:
		field.focus_entered.emit()
		said.append("%s|%s" % [strip.heading_label.text, strip.body_label.text])
	for index: int in range(1, said.size()):
		if said[index] == said[index - 1]:
			return false
	return not said[0].strip_edges().is_empty()


## The strips and the focusable controls of one built dialog, gathered in one walk of its tree.
static func _gather_dialog_parts(node: Node, strips: Array[HelpStrip], fields: Array[Control]) -> void:
	if node is HelpStrip:
		strips.append(node)
		# A strip's own fix buttons are not fields of the dialog - they are part of what it says.
		return
	var control: Control = node as Control
	if control != null and control.focus_mode != Control.FOCUS_NONE:
		fields.append(control)
	for child: Node in node.get_children():
		_gather_dialog_parts(child, strips, fields)


## A dropdown that shows the GDScript form of its current choice, muted, beside it: the operator list
## reads "≤  at most" and the code form `<=` sits quietly at the right, so the friendly wording
## teaches the spelling instead of hiding it. Returns the dropdown UNCHANGED when every item already
## shows its own code form (an ordinary list of plain values gains nothing from a note that repeats
## it), so callers can wrap unconditionally.
##
## `code_for_index` overrides where the code text comes from (default: the item's metadata); pass one
## when the stored value is not the whole truth - a "Number" type that stores int or float depending
## on a tick beside it. The note is reachable as the dropdown's "code_note" meta.
static func code_noted_option(dropdown: OptionButton, code_for_index: Callable = Callable()) -> Control:
	if dropdown == null:
		return dropdown
	if not code_for_index.is_valid() and not _has_option_code_notes(dropdown):
		return dropdown
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(6.0)))
	dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(dropdown)
	var note: Label = Label.new()
	note.add_theme_color_override("font_color", EventSheetPopupUI.muted_text_color())
	note.add_theme_font_size_override("font_size", EventSheetPalette.scaled(11))
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var mono: Font = editor_font("doc_source")
	if mono != null:
		note.add_theme_font_override("font", mono)
	row.add_child(note)
	dropdown.set_meta("code_note", note)
	var refresh: Callable = func(_index: int = -1) -> void:
		note.text = option_code_text(dropdown, code_for_index)
	dropdown.item_selected.connect(refresh)
	refresh.call(dropdown.selected)
	return row


## The code form of the dropdown's current choice - the note's text, computed apart from the widget
## so a test can pin it without a tree.
static func option_code_text(dropdown: OptionButton, code_for_index: Callable = Callable()) -> String:
	if dropdown == null or dropdown.selected < 0:
		return ""
	if code_for_index.is_valid():
		return str(code_for_index.call(dropdown.selected))
	var meta: Variant = dropdown.get_item_metadata(dropdown.selected)
	var code: String = str(meta) if meta != null else ""
	return "" if code == dropdown.get_item_text(dropdown.selected) else code


## True when at least one item's stored value differs from the words it shows - the case where a
## muted code note tells the reader something the label does not.
static func _has_option_code_notes(dropdown: OptionButton) -> bool:
	for index: int in range(dropdown.item_count):
		var meta: Variant = dropdown.get_item_metadata(index)
		if meta == null:
			continue
		var code: String = str(meta)
		if not code.is_empty() and code != dropdown.get_item_text(index):
			return true
	return false


## An editor icon by name, or null outside the editor / when the theme has no such icon.
static func _editor_icon(icon_name: String) -> Texture2D:
	return EventSheetEditorIcons.icon(icon_name)


## Fills `popup` with the suggestions whose text contains `filter_text` (case-insensitive;
## empty filter shows all). Each item's id is its index into the FULL list, so a pick maps
## back correctly even when filtered. The one shared filler behind every autocomplete
## combo (ACE params, Replace Object References, the match/switch case patterns).
static func fill_suggestion_popup(popup: PopupMenu, suggestions: PackedStringArray, filter_text: String,
		note_provider: Callable = Callable()) -> void:
	popup.clear()
	var needle: String = filter_text.strip_edges().to_lower()
	var any_added: bool = false
	for index: int in range(suggestions.size()):
		var suggestion: String = suggestions[index]
		if needle.is_empty() or suggestion.to_lower().contains(needle):
			# A choice may carry the line that explains it (an input action's keys, how many
			# nodes are in a group). The item's ID still indexes the POOL, so what a pick inserts is
			# the bare value however much the item shows.
			popup.add_item(suggestion_item_text(suggestion, note_provider), index)
			any_added = true
	if not any_added:
		popup.add_item("(no match - keep typing)", -1)
		popup.set_item_disabled(popup.item_count - 1, true)


## What one suggestion READS as in the list: the value alone, or the value and the line that
## explains it. Static and pure so a test can pin the composed line without opening a popup.
static func suggestion_item_text(suggestion: String, note_provider: Callable = Callable()) -> String:
	if not note_provider.is_valid():
		return suggestion
	var note: String = str(note_provider.call(suggestion)).strip_edges()
	return suggestion if note.is_empty() else "%s    %s" % [suggestion, note]


## The editable autocomplete combo's ▾ picker, fully wired to `edit` (event-sheet-style
## "Combo" with free text): opening rebuilds the (filtered) list from suggestions_provider
## - a Callable returning the CURRENT suggestions, so live lists (project feature tags,
## enum members) are never stale - picking inserts the suggestion and returns the caret,
## and Down-arrow in the field opens the popup (skipping a dead "(no match)"-only menu).
## The caller parents the returned MenuButton beside its LineEdit. One implementation for
## every combo in the plugin - the ACE params dialog, the Replace Object References To
## field, and the match/switch case patterns all attach through here.
##
## `note_provider` (optional) maps one suggestion to the line that explains it, shown beside the
## value in the list. The pick still inserts the bare value: item ids index the pool, never the text.
static func autocomplete_combo(edit: LineEdit, suggestions_provider: Callable,
		note_provider: Callable = Callable()) -> MenuButton:
	var picker: MenuButton = MenuButton.new()
	picker.text = "▾"
	picker.tooltip_text = "Suggestions (you can still type any value)"
	var popup: PopupMenu = picker.get_popup()
	# The pool shown last: item ids index into THIS array, so a pick resolves against
	# exactly the list the user saw even if the live provider changes between calls.
	var shown: Dictionary = {"pool": PackedStringArray()}
	popup.about_to_popup.connect(func() -> void:
		shown["pool"] = PackedStringArray(suggestions_provider.call())
		fill_suggestion_popup(popup, shown["pool"], edit.text, note_provider))
	# Whenever the popup closes (pick, Escape, click-away), return the caret to the field
	# so Enter still confirms the dialog and typing continues seamlessly.
	popup.popup_hide.connect(func() -> void: edit.grab_focus())
	popup.id_pressed.connect(func(picked_id: int) -> void:
		var pool: PackedStringArray = shown["pool"]
		if picked_id >= 0 and picked_id < pool.size():
			edit.text = pool[picked_id]
			edit.caret_column = edit.text.length()
			edit.grab_focus())
	# Down-arrow from the field opens the suggestions (keyboard-first authoring) - unless the field
	# already carries the completion popup, whose Down moves ITS highlight. One key, one meaning.
	edit.gui_input.connect(func(event: InputEvent) -> void:
		var key_event: InputEventKey = event as InputEventKey
		if EventSheetCompletionPopup.rides(edit):
			return
		if key_event != null and key_event.pressed and key_event.keycode == KEY_DOWN:
			shown["pool"] = PackedStringArray(suggestions_provider.call())
			fill_suggestion_popup(popup, shown["pool"], edit.text, note_provider)
			# Don't pop a dead, disabled-only "(no match)" menu - keep the caret in the field.
			if popup.item_count == 1 and popup.is_item_disabled(0):
				edit.accept_event()
				return
			popup.position = Vector2i(edit.get_screen_position() + Vector2(0.0, edit.size.y))
			popup.reset_size()
			popup.popup()
			edit.accept_event())
	return picker


## Selects the dropdown entry whose TEXT is `wanted`, falling back to the first entry when nothing
## matches. Dialogs re-show with a remembered choice whose word may since have been renamed or
## deleted; falling back rather than leaving the dropdown unselected keeps the field readable and
## keeps the caller from having to special-case an empty selection. No-op on an empty dropdown.
##
## The body is the one both dialogs carried, line for line, with nothing added: the merge that
## brought it here rests on being able to say that, and a guard neither of them had would have made
## the claim untrue for the sake of a case no caller reaches.
static func select_option(dropdown: OptionButton, wanted: String) -> void:
	for index: int in range(dropdown.item_count):
		if dropdown.get_item_text(index) == wanted:
			dropdown.select(index)
			return
	if dropdown.item_count > 0:
		dropdown.select(0)


## An ItemList sized to show roughly `rows_high` pixels of rows at the editor's own scale, filling
## the width it is given. Receipt and review dialogs stack several of these at DIFFERENT heights on
## purpose - the shorter list is the shorter story - so the height is the caller's to say.
static func sized_list(rows_high: float) -> ItemList:
	var list: ItemList = ItemList.new()
	list.custom_minimum_size = Vector2(0.0, EventSheetPalette.scaled_f(rows_high))
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return list


## A TABLE: a Tree with its root hidden and one titled column per title (no title row when there are
## none), taking the height its column gives it and never less than `min_height` at the editor's own
## scale. `fixed` keeps a narrow column narrow: {column: width}. The shape every result, watch and
## finding list in the plugin shares.
static func table(titles: PackedStringArray = PackedStringArray(), min_height: float = 0.0,
		fixed: Dictionary = {}) -> Tree:
	var tree: Tree = Tree.new()
	tree.hide_root = true
	# A table holds names as they are written: auto-translated, an object called Player read as the
	# editor's own word for "player" in another language. Its cells are never translated, so a fixed
	# sentence put in one is translated by whoever puts it there; its titles are translated here.
	tree.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	tree.columns = maxi(titles.size(), 1)
	for index: int in titles.size():
		tree.set_column_title(index, EventSheetL10n.translate(titles[index]))
	tree.column_titles_visible = not titles.is_empty()
	for column: int in fixed:
		tree.set_column_expand(column, false)
		tree.set_column_custom_minimum_width(column, roundi(EventSheetPalette.scaled_f(float(fixed[column]))))
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.custom_minimum_size.y = EventSheetPalette.scaled_f(min_height)
	return tree


## A window's list of results, added to the end of `box`: the table in a titled card that takes the
## window's spare height, then a strip that names the selected result on its THIS ROW line (hidden
## until something is selected). With `count`, a quiet line under the table says how many there are.
## Returns {card, count, strip, this_row}.
static func add_results(box: Container, title: String, results: Tree, count: bool = false) -> Dictionary:
	var parts: Dictionary = {}
	var content: Control = results
	if count:
		content = form_box()
		content.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.add_child(results)
		parts["count"] = hint_label("")
		content.add_child(parts["count"])
	var card: PanelContainer = titled_card(title, content)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(card)
	var strip: HelpStrip = help_strip()
	parts["this_row"] = strip.add_line(EventSheetL10n.translate("THIS ROW"), true)
	strip.visible = false
	box.add_child(strip)
	parts["card"] = card
	parts["strip"] = strip
	return parts


# ── The window kit's state parts ──────────────────────────────────────────────────────────────
#
# A window says how things stand in three tones and no more: ok (green), a warning (amber - it
# will work, but not the way you might expect) and a problem (red - it cannot be meant). The help
# strip, the state note and the result card all colour from tone_color(), so one tone is one colour
# wherever a window shows it.

const TONE_OK := "ok"
const TONE_WARNING := "warning"
const TONE_ERROR := "error"
## The mark a result line leads with, per tone. Plain glyphs in the tone's colour, so the line still
## reads in a theme, a headless build or a screen reader with no icons at all.
const TONE_MARKS := {TONE_OK: "✓", TONE_WARNING: "!", TONE_ERROR: "✕"}


## The colour of a tone; anything that is not one of the three is the editor's accent.
static func tone_color(tone: String) -> Color:
	match tone:
		TONE_OK:
			return readable_on_panel(EventSheetPalette.COLOR_HEALTH_OK)
		TONE_WARNING:
			return readable_on_panel(EventSheetPalette.COLOR_HEALTH_WARN)
		TONE_ERROR:
			return readable_on_panel(EventSheetPalette.COLOR_ERROR_TEXT)
	return accent_color()


## A STATE NOTE: one sentence with a coloured edge, the way a window says what is wrong with the
## field above it. `say("")` hides it, so a caller sets it on every change and never toggles
## visibility by hand. `text` reads back what it says.
class StateNote extends PanelContainer:

	var text: String:
		get:
			return _label.text

	var tone: String = ""
	var _label: Label = null
	var _style: StyleBoxFlat = null


	func _init(wrap_width: float = EventSheetPopupUI.HINT_WRAP_WIDTH) -> void:
		_style = StyleBoxFlat.new()
		_style.content_margin_left = EventSheetPalette.scaled_f(8.0)
		_style.content_margin_right = EventSheetPalette.scaled_f(8.0)
		_style.content_margin_top = EventSheetPalette.scaled_f(4.0)
		_style.content_margin_bottom = EventSheetPalette.scaled_f(4.0)
		_style.border_width_left = EventSheetPalette.scaled(3)
		add_theme_stylebox_override("panel", _style)
		_label = Label.new()
		_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_label.custom_minimum_size = Vector2(wrap_width, 0.0)
		add_child(_label)
		visible = false


	func say(sentence: String, level: String = EventSheetPopupUI.TONE_ERROR) -> void:
		tone = level
		_label.text = sentence
		var colour: Color = EventSheetPopupUI.tone_color(level)
		_style.border_color = colour
		_style.bg_color = Color(colour.r, colour.g, colour.b, 0.12)
		visible = not sentence.strip_edges().is_empty()


## A window that DOES one thing to what it lists (find, replace, go to a row, make a function): the
## form window above, non-modal, with `close` as its Cancel and a state note in the button row, left
## of the buttons, where the window says why its main button is greyed out or what it cannot undo.
## Returns {window, box, note} - `box` is the column to fill.
static func action_window(title: String, main: String, close: String, size: Vector2i, host: Node) -> Dictionary:
	var parts: Dictionary = panel_window(title, size, host, main)
	var window: ConfirmationDialog = parts["window"]
	window.cancel_button_text = close
	window.exclusive = false
	window.min_size = Vector2i(EventSheetPalette.scaled(size.x), EventSheetPalette.scaled(size.y))
	var note: StateNote = StateNote.new(EventSheetPalette.scaled_f(300.0))
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# The row's own spacers expand too; the sentence takes most of what they leave, and the buttons
	# keep their own height beside a sentence that wraps.
	note.size_flags_stretch_ratio = 6.0
	window.get_ok_button().add_sibling(note)
	note.get_parent().move_child(note, 0)
	for button: Button in [window.get_ok_button(), window.get_cancel_button()]:
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parts["note"] = note
	return parts


## The icon a sheet line leads with, as the line draws it: the 18 px tile and, on it, either a class
## icon or one of the sheet's own glyphs (System's gear, the function, a parameter) in that glyph's ink.
## A window's band wears it so the band reads as the very line it is about.
class LineIcon extends Control:

	## The sheet's row marks, loaded the first time a band shows an icon: a window that never shows
	## one (and the editor's boot) never loads the row painter.
	const ROW_MARKS_PATH := "res://addons/eventsheet/editor/interaction/native_row_marks.gd"
	## The tile and the icon on it, the sizes the sheet's object column draws them at.
	const PLATE_SIZE := 18.0
	const ICON_SIZE := 14.0
	## The glyph ids of a function head's lines, spelled as the row marks spell them.
	const GLYPH_FUNCTION := "function"
	const GLYPH_PARAMETER := "parameter"

	var glyph: String = ""
	var texture: Texture2D = null


	func _init() -> void:
		var side: float = EventSheetPalette.scaled_f(PLATE_SIZE)
		custom_minimum_size = Vector2(side, side)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false


	## Shows `glyph` (a NativeRowMarks OBJECT_GLYPH_* id), else `icon`; neither hides the tile.
	func show_icon(glyph_id: String, icon: Texture2D = null) -> void:
		glyph = glyph_id
		texture = icon
		visible = not glyph.is_empty() or texture != null
		queue_redraw()


	func _draw() -> void:
		var ink: Color = EventSheetPopupUI.text_color()
		# The tile the sheet's object column draws: a neutral grey a step off the ground, lighter
		# under pale ink (a dark editor) and darker under dark ink (a light one).
		var plate := StyleBoxFlat.new()
		plate.bg_color = EventSheetPalette.COLOR_OBJECT_ICON_TILE_DARK if ink.get_luminance() > 0.5 \
			else EventSheetPalette.COLOR_OBJECT_ICON_TILE_LIGHT
		plate.set_corner_radius_all(3)
		draw_style_box(plate, Rect2(Vector2.ZERO, size))
		var inner: float = EventSheetPalette.scaled_f(ICON_SIZE)
		var icon_rect: Rect2 = Rect2((size - Vector2(inner, inner)) * 0.5, Vector2(inner, inner))
		if not glyph.is_empty():
			var marks: Script = load(ROW_MARKS_PATH)
			marks.call("draw_object_glyph", self, icon_rect, glyph, marks.call("glyph_ink", glyph, ink))
		elif texture != null:
			draw_texture_rect(texture, icon_rect, false)


## A ROW BAND: the line at the top of a window naming what it is about - the row a writing window
## will write, read the way the sheet will (its object in the quiet object column, then its words), or
## the event a pick lands on and the field a pick goes into - then an optional note at the far right.
## Redrawn live as the fields change, so nothing is written or picked blind. `code_words` sets the
## words in the code font (a picker's field shows what the field holds); an empty band hides.
class RowBand extends PanelContainer:

	var icon: LineIcon = null
	var object_label: Label = null
	var words_label: Label = null
	var note_label: Label = null


	func _init(code_words: bool = false) -> void:
		var style: StyleBoxFlat = EventSheetPopupUI.inset_panel_stylebox()
		style.content_margin_left = EventSheetPalette.scaled_f(8.0)
		style.content_margin_right = EventSheetPalette.scaled_f(8.0)
		style.content_margin_top = EventSheetPalette.scaled_f(5.0)
		style.content_margin_bottom = EventSheetPalette.scaled_f(5.0)
		add_theme_stylebox_override("panel", style)
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(10.0)))
		add_child(row)
		icon = LineIcon.new()
		row.add_child(icon)
		object_label = Label.new()
		object_label.add_theme_color_override("font_color", EventSheetPopupUI.secondary_text_color())
		row.add_child(object_label)
		words_label = Label.new()
		words_label.add_theme_color_override("font_color", EventSheetPopupUI.text_color())
		words_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words_label.clip_text = true
		words_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var mono: Font = EventSheetPopupUI.editor_font("doc_source") if code_words else null
		if mono != null:
			words_label.add_theme_font_override("font", mono)
		row.add_child(words_label)
		note_label = Label.new()
		note_label.add_theme_color_override("font_color", EventSheetPopupUI.muted_text_color())
		row.add_child(note_label)
		visible = false


	## The row as the sheet will read it. An empty object hides that column; nothing to name hides the band.
	func show_row(object_name: String, words: String, note: String = "") -> void:
		object_label.text = object_name
		object_label.visible = not object_name.is_empty()
		words_label.text = words
		words_label.tooltip_text = words
		note_label.text = note
		note_label.visible = not note.is_empty()
		visible = not (object_name + words).strip_edges().is_empty()


	## The icon the line leads with: a sheet glyph id (NativeRowMarks.OBJECT_GLYPH_*), else a class
	## icon. An object the sheet draws a glyph for (System, the input devices) gets that glyph from its
	## name alone. Empty and null hide the tile.
	func show_icon(glyph: String, texture: Texture2D = null) -> void:
		icon.show_icon(glyph, texture)


	## The icon for the object column's own name: its glyph when the sheet draws one, else `texture`.
	func show_object_icon(object_name: String, texture: Texture2D = null) -> void:
		icon.show_icon(str(load(LineIcon.ROW_MARKS_PATH).call("object_glyph_for", object_name)), texture)


## Gives a text field a red edge while `problem` is true, and its own look back when it is not - the
## mark that says WHICH field the state note under the form is talking about.
static func mark_field(field: Control, problem: bool) -> void:
	if field == null:
		return
	if not problem:
		field.remove_theme_stylebox_override("normal")
		return
	var base: StyleBox = field.get_theme_stylebox("normal")
	var style: StyleBoxFlat = (base as StyleBoxFlat).duplicate() if base is StyleBoxFlat else StyleBoxFlat.new()
	style.border_color = tone_color(TONE_ERROR)
	style.set_border_width_all(maxi(1, EventSheetPalette.scaled(1)))
	field.add_theme_stylebox_override("normal", style)


## Recolours one of a window's own buttons: filled for the main verb, outlined for a risky one.
static func paint_button(button: Button, fill: Color, text: Color, filled: bool) -> void:
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


## The window's main verb in the editor's blue, so the one button that does the work reads first.
static func main_button(button: Button) -> Button:
	paint_button(button, accent_color().darkened(0.3), Color.WHITE, true)
	return button


# ── The described dropdown ────────────────────────────────────────────────────────────────────
#
# Every choice in a dropdown carries the sentence that says what it means, as Godot's own item
# tooltip: the open list shows it as the pointer rests on a choice, and the closed dropdown's own
# tooltip is the chosen item's sentence. No popup of our own - the PopupMenu already does this.


## Wires `dropdown` (or a new one) so its tooltip follows the chosen item's description, and
## returns it. A tooltip it already had stays as the answer for a choice with no description.
static func described_option(dropdown: OptionButton = null) -> OptionButton:
	if dropdown == null:
		dropdown = OptionButton.new()
	dropdown.set_meta("described_fallback", dropdown.tooltip_text)
	dropdown.item_selected.connect(func(_index: int) -> void: follow_description(dropdown))
	# select() from code emits nothing, so the tooltip is also brought up to date as the pointer
	# arrives - the only moment it can show.
	dropdown.mouse_entered.connect(func() -> void: follow_description(dropdown))
	return dropdown


## Adds one choice with the sentence that describes it, and returns its index. `metadata` is the
## stored value when the words shown are not the value written.
static func add_described_item(dropdown: OptionButton, text: String, description: String,
		metadata: Variant = null) -> int:
	dropdown.add_item(text)
	var index: int = dropdown.item_count - 1
	dropdown.set_item_tooltip(index, description)
	if metadata != null:
		dropdown.set_item_metadata(index, metadata)
	follow_description(dropdown)
	return index


## Sets the dropdown's tooltip to its chosen item's description (or the tooltip it started with), and
## the sentence a described_field() keeps under it.
static func follow_description(dropdown: OptionButton) -> void:
	var told: String = dropdown.get_item_tooltip(dropdown.selected) if dropdown.selected >= 0 else ""
	dropdown.tooltip_text = told if not told.is_empty() else str(dropdown.get_meta("described_fallback", ""))
	# get_meta with a null default still reports a missing key as an error, so ask first.
	var note: Label = dropdown.get_meta("chosen_note") as Label if dropdown.has_meta("chosen_note") else null
	if note != null:
		note.text = told


## A DESCRIBED FIELD: the described dropdown with its chosen choice's sentence kept in view under it,
## not only on hover - the field to hand form_row(). The sentence follows every pick, and a select()
## from code is brought up to date by the follow_description() call that follows it.
static func described_field(dropdown: OptionButton, wrap_width: float = HINT_WRAP_WIDTH) -> VBoxContainer:
	if not dropdown.has_meta("described_fallback"):
		described_option(dropdown)
	var box: VBoxContainer = VBoxContainer.new()
	dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(dropdown)
	var note: Label = hint_label("", wrap_width)
	box.add_child(note)
	dropdown.set_meta("chosen_note", note)
	follow_description(dropdown)
	return box


## A VIEW SWITCH: Sheet | Code | Side by side as one segmented row of toggle buttons in a ButtonGroup.
## `view_chosen` fires when the reader picks a different view; `choose()` sets one from code.
class ViewSwitch extends HBoxContainer:

	signal view_chosen(view: String)

	const SHEET := "sheet"
	const CODE := "code"
	const BOTH := "both"

	var view: String = ""
	var buttons: Dictionary = {}


	## `words` renames the three for a switch that is not about a file - {id: [label, tooltip]},
	## already translated - so a page of examples can say Events | Code | Both.
	func _init(start: String = SHEET, words: Dictionary = {}) -> void:
		add_theme_constant_override("separation", 0)
		var group: ButtonGroup = ButtonGroup.new()
		var labels: Dictionary = {
			SHEET: EventSheetL10n.translate("Sheet"),
			CODE: EventSheetL10n.translate("Code"),
			BOTH: EventSheetL10n.translate("Side by side"),
		}
		var tips: Dictionary = {
			SHEET: EventSheetL10n.translate("The file read as rows."),
			CODE: EventSheetL10n.translate("The file as code, byte for byte."),
			BOTH: EventSheetL10n.translate("Rows and code next to each other."),
		}
		for id: String in words:
			labels[id] = words[id][0]
			tips[id] = words[id][1]
		for id: String in labels:
			var button: Button = Button.new()
			button.text = str(labels[id])
			button.tooltip_text = str(tips[id])
			button.toggle_mode = true
			# The chosen view reads in the one accent, the way the editor marks its own choice.
			button.add_theme_color_override("font_pressed_color", EventSheetPopupUI.accent_color())
			button.add_theme_color_override("font_hover_pressed_color", EventSheetPopupUI.accent_color())
			button.button_group = group
			button.pressed.connect(choose.bind(id))
			add_child(button)
			buttons[id] = button
		choose(start, false)


	func choose(wanted: String, announce: bool = true) -> void:
		if not buttons.has(wanted) or wanted == view:
			return
		view = wanted
		for id: String in buttons:
			(buttons[id] as Button).set_pressed_no_signal(id == wanted)
		if announce:
			view_chosen.emit(wanted)


## A RESULT CARD: a titled panel that says what just happened. `report()` fills it - a short flow of
## figures read left to right, then one line per outcome, each led by its tone's mark and closed by
## the file it touched when there is one.
class ResultCard extends PanelContainer:

	var figures_label: Label = null
	var lines_box: VBoxContainer = null


	func _init(title: String) -> void:
		var style: StyleBoxFlat = EventSheetPopupUI.inset_panel_stylebox()
		style.set_content_margin_all(EventSheetPopupUI.PANEL_SECTION_PAD)
		add_theme_stylebox_override("panel", style)
		var box: VBoxContainer = EventSheetPopupUI.form_box()
		box.add_child(EventSheetPopupUI.section_header(title))
		figures_label = Label.new()
		figures_label.add_theme_color_override("font_color", EventSheetPopupUI.secondary_text_color())
		figures_label.visible = false
		box.add_child(figures_label)
		lines_box = VBoxContainer.new()
		box.add_child(lines_box)
		add_child(box)


	## `lines` are {"text", "tone" (ok / warning / error), "file" (optional)}; empty clears the card.
	func report(lines: Array, figures: PackedStringArray = PackedStringArray()) -> void:
		figures_label.text = "  →  ".join(figures)
		figures_label.visible = not figures.is_empty()
		for old: Node in lines_box.get_children():
			lines_box.remove_child(old)
			old.queue_free()
		for line: Variant in lines:
			if line is Dictionary:
				lines_box.add_child(_line(line))


	func _line(entry: Dictionary) -> HBoxContainer:
		var tone: String = str(entry.get("tone", EventSheetPopupUI.TONE_OK))
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", EventSheetPopupUI.ROW_SEPARATION)
		var mark: Label = Label.new()
		mark.name = "Mark"
		mark.text = str(EventSheetPopupUI.TONE_MARKS.get(tone, "·"))
		mark.add_theme_color_override("font_color", EventSheetPopupUI.tone_color(tone))
		# One width for every mark, so the words of each line start at the same edge.
		mark.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(30.0), 0.0)
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(mark)
		var words: Label = EventSheetPopupUI.hint_label(str(entry.get("text", "")))
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(words)
		var file: String = str(entry.get("file", ""))
		if not file.is_empty():
			var chip: PanelContainer = EventSheetPopupUI.metadata_badge(file.get_file())
			chip.name = "File"
			chip.tooltip_text = file
			row.add_child(chip)
		return row


# ── The typed field makers ────────────────────────────────────────────────────────────────────
#
# A dialog field used to be five gestures spread over four lines - make, configure, wire, wrap in
# a form_row, read back on accept - and the read-back lived in a different function from the
# build, which is how a field gets added to one and forgotten in the other. These say the field
# once, as a typed EventSheetFieldSpec, and form() builds a whole list of them THROUGH THE SAME
# HELPERS above, so a dialog that changes over does not move a pixel.
#
# The kind is a METHOD here, not a string argument: text() and check() are different functions, so
# a misspelled kind cannot compile. Modifiers chain off the returned spec, so they cannot be
# misspelled either, and the editor's own completion lists the vocabulary from the dot.
#
# The old raw path stays entirely legal. A field with live gating, a bespoke widget or a picker of
# its own is still built by hand beside the spec'd ones - a spec is for the fields that are only
# what they say they are.
#
# FIVE KINDS, AND THEY ALL HAVE A CALLER OR AN IMMEDIATE USE. A code box and a picker-backed choice
# field were declared here too and nothing in the tree asked for either; they cost more machinery
# than any other kind and answered a question no dialog had put. They are not here. Adding a kind
# back is one enum entry, one maker and its arms - which is cheap, and is meant to happen the day a
# dialog needs it rather than the day somebody imagines one might.


## A single line of text. `field_id` is what values() answers under; `label` is the words at the
## left of the row (empty for a field that fills the row on its own).
static func text_field(field_id: String, label: String = "") -> EventSheetFieldSpec:
	return _spec(field_id, label, EventSheetFieldSpec.Kind.TEXT)


## A number in a SpinBox, bounded with at_least() / at_most() and stepped with stepping().
static func number_field(field_id: String, label: String = "") -> EventSheetFieldSpec:
	return _spec(field_id, label, EventSheetFieldSpec.Kind.NUMBER)


## A dropdown of fixed choices. Fill it with options(labels) - or options(labels, stored) when the
## value a choice writes is not the words it shows.
static func options_field(field_id: String, label: String = "") -> EventSheetFieldSpec:
	return _spec(field_id, label, EventSheetFieldSpec.Kind.OPTIONS)


## A tick. Give it a label for a "Label  [x]" row, or leave the label empty and pass the words as
## default() for a tick that carries its own text.
static func check_field(field_id: String, label: String = "") -> EventSheetFieldSpec:
	return _spec(field_id, label, EventSheetFieldSpec.Kind.CHECK)


## A path typed into a line edit - a TEXT field by another name, kept distinct so a reader (and a
## later completion source) can tell a path field from a prose one.
static func path_field(field_id: String, label: String = "") -> EventSheetFieldSpec:
	return _spec(field_id, label, EventSheetFieldSpec.Kind.PATH)


## Builds `specs` into `host` in order and returns the form that reads them back. `owner_name` is
## what an error about an unknown or duplicated field id calls this form.
static func form(host: Control, specs: Array[EventSheetFieldSpec],
		owner_name: String = "form") -> EventSheetFieldForm:
	return EventSheetFieldForm.new().fill(host, specs, owner_name)


static func _spec(field_id: String, label: String, kind: EventSheetFieldSpec.Kind) -> EventSheetFieldSpec:
	var spec: EventSheetFieldSpec = EventSheetFieldSpec.new()
	spec.id = field_id
	spec.label = label
	spec.kind = kind
	return spec
