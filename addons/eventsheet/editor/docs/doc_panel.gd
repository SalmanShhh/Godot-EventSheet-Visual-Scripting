# EventSheet - EventSheetDocPanel: the reference surface, drawn from EventSheetDocExplain blocks.
#
# The reader's half of "what does this row do?": a title, the plain-language description, the
# GDScript it ships as, its values, a LIVE figure of the verb with an Insert button, the blurb
# for its whole category, and a read-more button aimed at its pack's guide.
#
# Deliberately HOST-AGNOSTIC. It is a plain VBoxContainer, so the same panel is parented by the
# Phase 2 window today and could be parented by a side dock later without touching this file.
# It knows nothing about tabs, menus or shortcuts - a host calls show_doc() and gets a page.
#
# TWO CHOICES WORTH KNOWING:
#   - Prose is drawn with plain Labels, never BBCode. A verb's description and its codegen line
#     are authored text that routinely contains square brackets (`arr[0]`, `[Deprecated]`), and a
#     BBCode parser eats them silently. Emphasis here is carried by the card chrome instead.
#   - Every wrapping label is width-BOUNDED. An unbounded autowrap label inside a container that
#     hugs its content reports a one-glyph-per-line minimum height during the first layout pass
#     and balloons its host. The page column sets the bound once, and every label inherits it.
@tool
class_name EventSheetDocPanel
extends VBoxContainer

## The page column's authored width, before display scaling. Wide enough for a sentence of prose
## and for a one-row figure to read as a row rather than as a wrapped fragment.
const PAGE_WIDTH := 460.0

## Emitted when the reader activates a read-more link. The panel opens it as well (that is the
## whole point of a link); the signal is for a host that wants to say so in its status line.
signal link_activated(target: String)

## Emitted after a figure's Insert lands rows in the sheet, so a host can close or report.
signal snippet_inserted()

var _doc_id: String = ""
var _doc_title: String = ""
var _empty_label: Label = null
var _page: VBoxContainer = null


func _init() -> void:
	add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(8.0)))
	custom_minimum_size = Vector2(EventSheetPalette.scaled_f(PAGE_WIDTH), 0.0)
	_empty_label = EventSheetPopupUI.hint_label("", EventSheetPalette.scaled_f(PAGE_WIDTH))
	_empty_label.visible = false
	add_child(_empty_label)
	_page = VBoxContainer.new()
	_page.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(8.0)))
	add_child(_page)


## The doc id currently on screen ("" when the panel is showing its empty state).
func current_doc_id() -> String:
	return _doc_id


## The human name of the page on screen (the verb's or category's own display name), for a host
## that titles itself after its content. "" when the panel is showing its empty state.
func current_title() -> String:
	return _doc_title


## Draws the page for a doc id. Returns false - and leaves the panel unchanged - when the id
## names nothing: an unknown verb must fail loudly at the caller rather than paint a blank page.
##
## The "addon:" scheme never reaches here: a pack guide opens in the browser (its images and
## tables render there today, and the corpus does not ship inside the plugin), so
## EventSheets.open_docs routes it before a panel is involved.
func show_doc(doc_id: String) -> bool:
	var route: Dictionary = EventSheetDocExplain.resolve(doc_id)
	if not bool(route.get("valid", false)):
		return false
	match str(route.get("scheme", "")):
		"index":
			show_message("Right-click a row and choose \"What does this do?\", or press F1 with a row selected, to read about the verb it uses.")
			_doc_id = ""
			return true
		"section":
			return _show_blocks(doc_id, EventSheetDocExplain.blocks_for_section(str(route.get("section", ""))))
		"ace":
			var definition: ACEDefinition = EventSheets.find_ace(str(route.get("provider_id", "")), str(route.get("ace_id", "")))
			if definition == null:
				return false
			return _show_blocks(doc_id, EventSheetDocExplain.blocks_for_definition(definition))
	return false


## Draws a verb's page directly, for a caller that already holds the definition (the picker's
## seam hands one over without a round trip through the registry).
func show_definition(definition: ACEDefinition) -> bool:
	if definition == null:
		return false
	return _show_blocks(EventSheetDocExplain.doc_id_for_definition(definition),
		EventSheetDocExplain.blocks_for_definition(definition))


## Replaces the page with a single line of guidance (no row selected, nothing to explain).
func show_message(text: String) -> void:
	_clear_page()
	_doc_id = ""
	_doc_title = ""
	_empty_label.text = EventSheetL10n.translate(text)
	_empty_label.visible = not text.strip_edges().is_empty()


func _show_blocks(doc_id: String, blocks: Array[Dictionary]) -> bool:
	if blocks.is_empty():
		return false
	_clear_page()
	_empty_label.visible = false
	_doc_id = doc_id
	_doc_title = ""
	for block: Dictionary in blocks:
		if str(block.get("kind", "")) == "title":
			_doc_title = str(block.get("text", ""))
		var control: Control = _control_for(block)
		if control != null:
			_page.add_child(control)
	return true


func _clear_page() -> void:
	for child: Node in _page.get_children():
		_page.remove_child(child)
		child.queue_free()


func _control_for(block: Dictionary) -> Control:
	match str(block.get("kind", "")):
		"title":
			return _title_block(str(block.get("text", "")), str(block.get("subtitle", "")))
		"note":
			return _note_block(str(block.get("text", "")))
		"prose":
			return _wrapped_label(str(block.get("text", "")))
		"ships_as":
			return EventSheetPopupUI.titled_card("Ships as", _code_label(str(block.get("code", ""))))
		"params":
			return _params_block(block.get("items", []) as Array)
		"about":
			return EventSheetPopupUI.titled_card(str(block.get("title", "About")),
				_wrapped_label(str(block.get("text", ""))))
		"figure":
			return _figure_block(block.get("definition", null) as ACEDefinition)
		"link":
			return _link_block(str(block.get("label", "")), str(block.get("target", "")),
				str(block.get("doc_id", "")))
	return null


func _title_block(text: String, subtitle: String) -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_child(EventSheetPopupUI.section_header(text))
	if not subtitle.strip_edges().is_empty():
		box.add_child(EventSheetPopupUI.hint_label(subtitle, EventSheetPalette.scaled_f(PAGE_WIDTH)))
	return box


## A deprecation steer, shown above the prose in the editor's warning colour so a verb that is on
## its way out says so before the reader learns how to use it.
func _note_block(text: String) -> Control:
	var label: Label = _wrapped_label(text)
	label.add_theme_color_override("font_color", Color(0.88, 0.7, 0.32))
	return EventSheetPopupUI.panel_section(label)


func _params_block(items: Array) -> Control:
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	for entry: Variant in items:
		var item: Dictionary = entry as Dictionary
		var detail: Label = _wrapped_label(str(item.get("detail", "")))
		detail.modulate = Color(1.0, 1.0, 1.0, 0.82)
		box.add_child(EventSheetPopupUI.form_row(str(item.get("name", "")), detail))
	return EventSheetPopupUI.titled_card("Values you fill in", box)


## The live illustration - the one thing a row hover and a static page cannot carry. Insert stays
## ENABLED here (unlike the picker's copy, where the dialog's own Add button is the insert route):
## reading about a verb and then putting it in the sheet is the whole gesture this surface exists
## for, and it runs the guarded, one-undo-step public insert path.
func _figure_block(definition: ACEDefinition) -> Control:
	var sheet: EventSheetResource = EventSheetDocFigure.sheet_for_definition(definition)
	if sheet == null:
		return null
	var figure: EventSheetDocFigure = EventSheetDocFigure.new()
	if not figure.show_sheet(sheet):
		figure.free()
		return null
	figure.set_caption("How this reads on the sheet:")
	figure.snippet_inserted.connect(func() -> void: snippet_inserted.emit())
	return figure


## Read more. The button prefers the DOC ID: once the guide corpus ships inside the plugin, the
## same click draws the pack's guide natively instead of opening a tab, and a pack whose guide
## lives elsewhere still opens in the browser. The signal reports whichever route ran, so a host's
## status line stays honest about where the reader was sent.
func _link_block(label: String, target: String, doc_id: String = "") -> Control:
	if label.strip_edges().is_empty() or target.strip_edges().is_empty():
		return null
	var button: Button = Button.new()
	button.text = label
	button.tooltip_text = "Opens the full guide - here in the editor when it ships with the plugin, in your browser otherwise."
	button.pressed.connect(func() -> void:
		if not doc_id.strip_edges().is_empty() and EventSheets.open_docs(doc_id):
			link_activated.emit(doc_id)
			return
		EventSheets.open_online_doc(target)
		link_activated.emit(target))
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(button)
	return row


## Plain text, wrapping at the page column's width. See the file header for why this is never a
## BBCode control.
func _wrapped_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(PAGE_WIDTH), 0.0)
	return label


## The emitted GDScript line, in the editor's source font so it reads as code rather than prose.
func _code_label(code: String) -> Label:
	var label: Label = _wrapped_label(code)
	var source_font: Font = _editor_source_font()
	if source_font != null:
		label.add_theme_font_override("font", source_font)
	return label


## The editor's own monospace documentation font, or null outside the editor (headless tests, a
## non-editor run) where the default font is the only one there is.
func _editor_source_font() -> Font:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return null
	var editor_interface: Object = Engine.get_singleton("EditorInterface")
	if editor_interface == null or not editor_interface.has_method("get_editor_theme"):
		return null
	var theme: Theme = editor_interface.get_editor_theme()
	if theme == null or not theme.has_font("doc_source", "EditorFonts"):
		return null
	return theme.get_font("doc_source", "EditorFonts")
