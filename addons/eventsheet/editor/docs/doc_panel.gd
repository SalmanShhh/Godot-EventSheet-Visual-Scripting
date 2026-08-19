# EventSheet - EventSheetDocPanel: the reference surface, drawn from EventSheetDocExplain blocks.
#
# The reader's half of "what does this row do?": a title, the plain-language description, the
# GDScript it ships as, its values, a LIVE figure of the verb with an Insert button, the blurb
# for its whole category, and a read-more button aimed at its pack's guide.
#
# THE LOOK is a compact developer reference, not a docs website: a large title with two metadata
# badges, small-caps accent section labels as the page's only accent-coloured text, syntax and
# parameters as a side-by-side band (stacked in a narrow column), and the parameters as a table
# rather than as prose. The one thing it does NOT restyle is the figure - see _figure_block.
#
# The reading order is FIXED (see SECTION_ORDER) and taken from the sections a page HAS rather than
# from the order the assembler emitted them, so every reference page in the plugin reads the same.
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

## The page column in a COMPACT host, before display scaling. A docked column is narrower than this
## panel's comfortable width, and a minimum it cannot satisfy is not a comfort - it either shoves the
## dock wider than the dock's own floor or gets clipped inside a host whose horizontal scrolling is
## switched off, which leaves the clipped edge unreachable. The same number the browser's compact
## floor uses, so the two halves of the reading surface ask for the same room.
const COMPACT_PAGE_WIDTH := 260.0

## The page title's size, before display scaling. Large enough that the eye lands on it first, in
## the editor's own documentation-title font when it is available.
const TITLE_FONT_SIZE := 20

## The wrap bound (before display scaling) for a control that lives in ONE COLUMN of the syntax /
## parameters band. Half the page, minus the band's gap - a column that claimed the full page width
## as its minimum would force the band to stack at every width.
const COLUMN_WRAP_WIDTH := 200.0

## The glyph that marks the about card, and the one on the read-more button. Text, not icons: this
## panel is drawn outside the editor by the render harness and in headless tests, where an editor
## icon is null.
const INFO_GLYPH := "ⓘ"
const EXTERNAL_LINK_GLYPH := "↗"

## The section every block kind belongs to. The block vocabulary is the assembler's (it names what
## the content IS); the sections are this panel's (they name what the reader READS), and the two
## are mapped in one place so a new block kind lands in a deliberate slot instead of at the end.
const SECTION_FOR_BLOCK := {
	"title": "title", "note": "note", "prose": "description", "ships_as": "syntax",
	"params": "parameters", "figure": "preview", "usage": "usage", "see_also": "see_also",
	"entry_actions": "actions", "about": "about", "link": "link",
}

## THE READING ORDER, fixed for every reference page: what it is, what it does, what you type, what
## you fill in, what it looks like on the sheet, and where it comes from.
const SECTION_ORDER: Array[String] = [
	"title", "note", "description", "syntax", "parameters", "preview", "usage", "see_also",
	"actions", "about", "link",
]

## Emitted when the reader activates a read-more link. The panel opens it as well (that is the
## whole point of a link); the signal is for a host that wants to say so in its status line.
signal link_activated(target: String)

## Emitted after a figure's Insert lands rows in the sheet, so a host can close or report.
signal snippet_inserted()

## Emitted when the reader asks to be taken to one of the rows of THIS sheet that already use the
## verb on screen. `index` walks the list, so "go to first" is 0 and "next" is the one after the
## one they were shown. The panel never touches the sheet itself - a host reveals the row.
signal row_requested(provider_id: String, ace_id: String, index: int)

## Emitted when the reader follows a "See also" chip, so a host navigates the way it does for any
## other link.
signal doc_requested(doc_id: String)

var _doc_id: String = ""
var _doc_title: String = ""
var _empty_label: Label = null
var _page: VBoxContainer = null
## The width every wrapping control on this page is bounded by, before display scaling. A VARIABLE
## rather than the constant, because the same panel is hosted by a window and by a dock column.
var _page_width: float = PAGE_WIDTH
var _compact: bool = false
## Which of the sheet's uses of this verb the reader was last taken to, so "next" walks the list
## instead of showing them the same row twice.
var _usage_index: int = -1
## The Show GDScript card, hidden until it is asked for.
var _gdscript_card: Label = null


func _init() -> void:
	add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(8.0)))
	custom_minimum_size = Vector2(EventSheetPalette.scaled_f(_page_width), 0.0)
	_empty_label = EventSheetPopupUI.hint_label("", EventSheetPalette.scaled_f(_page_width))
	_empty_label.visible = false
	add_child(_empty_label)
	_page = VBoxContainer.new()
	_page.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(8.0)))
	add_child(_page)


## Narrows the page for a host that has no room for the comfortable column (the Help dock). The page
## on screen is REDRAWN, because every wrapping label was built with the old bound baked into its
## minimum size and a label already in the tree does not re-take it.
func set_compact(enabled: bool) -> void:
	if _compact == enabled:
		return
	_compact = enabled
	_page_width = COMPACT_PAGE_WIDTH if enabled else PAGE_WIDTH
	custom_minimum_size = Vector2(EventSheetPalette.scaled_f(_page_width), 0.0)
	_empty_label.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(_page_width), 0.0)
	if not _doc_id.is_empty():
		show_doc(_doc_id)


## True while the panel is drawn for a narrow host.
func is_compact() -> bool:
	return _compact


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


## Which sections a set of blocks draws, in the order they are drawn. PURE and static, so the
## reading order is pinned by a test rather than by a screenshot: a reader who learns the shape of
## one reference page has learned every one, and that only holds if the order never depends on the
## order the blocks happened to arrive in.
##
## "syntax" and "parameters" are two sections that share one BAND (side by side when there is room,
## stacked when there is not), and "link" is drawn INSIDE the about card when both are present -
## both still report as their own section, because both are still their own thing to read.
static func section_plan(blocks: Array[Dictionary]) -> PackedStringArray:
	var present: Dictionary = {}
	for block: Dictionary in blocks:
		present[SECTION_FOR_BLOCK.get(str(block.get("kind", "")), "")] = true
	var plan: PackedStringArray = PackedStringArray()
	for section: String in SECTION_ORDER:
		if present.has(section):
			plan.append(section)
	return plan


func _show_blocks(doc_id: String, blocks: Array[Dictionary]) -> bool:
	if blocks.is_empty():
		return false
	_clear_page()
	_empty_label.visible = false
	_doc_id = doc_id
	_doc_title = ""
	var by_section: Dictionary = {}
	for block: Dictionary in blocks:
		if str(block.get("kind", "")) == "title":
			_doc_title = str(block.get("text", ""))
		by_section[SECTION_FOR_BLOCK.get(str(block.get("kind", "")), "")] = block
	for section: String in section_plan(blocks):
		# The band is emitted once, at the SYNTAX slot, carrying both columns.
		if section == "parameters" and by_section.has("syntax"):
			continue
		# A link beside an about card rides inside it rather than trailing the page.
		if section == "link" and by_section.has("about"):
			continue
		var control: Control = _section_control(section, by_section)
		if control != null:
			_page.add_child(control)
	return true


func _clear_page() -> void:
	for child: Node in _page.get_children():
		_page.remove_child(child)
		child.queue_free()


func _section_control(section: String, by_section: Dictionary) -> Control:
	var block: Dictionary = by_section.get(section, {}) as Dictionary
	match section:
		"title":
			return _title_block(str(block.get("text", "")), block.get("badges", PackedStringArray()))
		"note":
			return _note_block(str(block.get("text", "")))
		"description":
			return _wrapped_label(str(block.get("text", "")))
		"syntax":
			return _syntax_and_parameters(block, by_section.get("parameters", {}) as Dictionary)
		"parameters":
			return _parameters_column(block)
		"preview":
			return _figure_block(block.get("definition", null) as ACEDefinition)
		"usage":
			return _usage_block(str(block.get("provider_id", "")), str(block.get("ace_id", "")))
		"see_also":
			return _see_also_block(block.get("items", []) as Array)
		"actions":
			return _entry_actions_block(block.get("definition", null) as ACEDefinition)
		"about":
			return _about_block(block, by_section.get("link", {}) as Dictionary)
		"link":
			return _link_block(str(block.get("label", "")), str(block.get("target", "")),
				str(block.get("doc_id", "")))
	return null


## The page's masthead: a LARGE title with its metadata badges right beside it. The badges are the
## two facts a reader needs before reading a word - what this verb is, and where it comes from -
## and they flow onto a second line rather than squeezing the title when the panel is narrow.
func _title_block(text: String, badges: Variant) -> Control:
	var row: HFlowContainer = HFlowContainer.new()
	row.add_theme_constant_override("h_separation", int(EventSheetPalette.scaled_f(8.0)))
	row.add_theme_constant_override("v_separation", int(EventSheetPalette.scaled_f(4.0)))
	var title: Label = Label.new()
	title.text = text
	title.add_theme_font_size_override("font_size", EventSheetPalette.scaled(TITLE_FONT_SIZE))
	var title_font: Font = EventSheetPopupUI.editor_font("doc_title")
	if title_font != null:
		title.add_theme_font_override("font", title_font)
	row.add_child(title)
	var labels: PackedStringArray = PackedStringArray(badges if badges != null else [])
	for index: int in range(labels.size()):
		# The first badge says what the verb IS (accent); the rest say where it comes from (purple).
		var tone: Color = EventSheetPopupUI.accent_color() if index == 0 else EventSheetPopupUI.BADGE_PACK
		row.add_child(EventSheetPopupUI.metadata_badge(labels[index], tone))
	return row


## A deprecation steer, shown above the prose in the editor's warning colour so a verb that is on
## its way out says so before the reader learns how to use it.
func _note_block(text: String) -> Control:
	var label: Label = _wrapped_label(text)
	label.add_theme_color_override("font_color", Color(0.88, 0.7, 0.32))
	return EventSheetPopupUI.panel_section(label)


## The two reference sections that answer "what do I type" and "what do I fill in". They read as a
## pair, so they sit as a pair: side by side above the breakpoint, stacked below it, decided by the
## band itself on every resize (this panel is hosted in a window AND in a dock column).
func _syntax_and_parameters(syntax: Dictionary, parameters: Dictionary) -> Control:
	var syntax_column: Control = _syntax_column(syntax)
	if parameters.is_empty():
		return syntax_column
	return EventSheetPopupUI.responsive_band(syntax_column, _parameters_column(parameters))


func _syntax_column(block: Dictionary) -> Control:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(4.0)))
	column.add_child(EventSheetPopupUI.small_caps_label("Syntax"))
	column.add_child(EventSheetPopupUI.code_card(str(block.get("code", "")),
		EventSheetPalette.scaled_f(COLUMN_WRAP_WIDTH)))
	return column


## The columns a set of parameters actually fills. Name and Type always; Default and Description
## only when at least one parameter has one. A reflected pack method declares neither a default nor
## a blurb for most of its arguments, and a column of blank cells reads as a broken table rather
## than as an honest one. Pure, so which columns a real verb draws is pinned by a test.
static func parameter_columns(items: Array) -> PackedStringArray:
	var columns: PackedStringArray = PackedStringArray(["Name", "Type"])
	var has_default: bool = false
	var has_description: bool = false
	for entry: Variant in items:
		var item: Dictionary = entry as Dictionary
		has_default = has_default or not str(item.get("default", "")).strip_edges().is_empty()
		has_description = has_description or not str(item.get("description", "")).strip_edges().is_empty()
	if has_default:
		columns.append("Default")
	if has_description:
		columns.append("Description")
	return columns


## The parameter rows, in the columns parameter_columns() chose - the table's whole content, as
## plain strings, so the table is testable without a window.
static func parameter_rows(items: Array) -> Array:
	var columns: PackedStringArray = parameter_columns(items)
	var rows: Array = []
	for entry: Variant in items:
		var item: Dictionary = entry as Dictionary
		var cells: PackedStringArray = PackedStringArray()
		for column: String in columns:
			cells.append(str(item.get(column.to_lower(), "")))
		rows.append(cells)
	return rows


## Parameters as a TABLE, never as prose: a reader looking for a default is looking for a cell.
func _parameters_column(block: Dictionary) -> Control:
	var items: Array = block.get("items", []) as Array
	var columns: PackedStringArray = parameter_columns(items)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(4.0)))
	column.add_child(EventSheetPopupUI.small_caps_label("Parameters"))
	# The LAST column takes the slack and wraps - the description when there is one, the defaults
	# when there is not, so the table always fills its half of the band instead of hugging left.
	column.add_child(EventSheetPopupUI.compact_table(columns, parameter_rows(items), columns.size() - 1))
	return column


## The category/pack blurb, and - when the pack has a guide - the way in to it. One card, because
## "what is this family of verbs for" and "where do I read more about it" are one question.
func _about_block(block: Dictionary, link: Dictionary) -> Control:
	var body: VBoxContainer = VBoxContainer.new()
	body.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(6.0)))
	body.add_child(_wrapped_label(str(block.get("text", "")), COLUMN_WRAP_WIDTH * 2.0))
	if not link.is_empty():
		var row: Control = _link_block(str(link.get("label", "")), str(link.get("target", "")),
			str(link.get("doc_id", "")))
		if row != null:
			body.add_child(row)
	return EventSheetPopupUI.labelled_card("%s  %s" % [INFO_GLYPH, str(block.get("title", "About"))], body)


## The live illustration - the one thing a row hover and a static page cannot carry. Insert stays
## ENABLED here (unlike the picker's copy, where the dialog's own Add button is the insert route):
## reading about a verb and then putting it in the sheet is the whole gesture this surface exists
## for, and it runs the guarded, one-undo-step public insert path.
##
## The figure itself is NOT restyled here and never should be: it is the real renderer drawing real
## rows, and a page that "improved" their colours or spacing would be illustrating an editor that
## does not exist. Only the label above it is this panel's, and it replaces the widget's own
## sentence caption so the section reads like every other section on the page.
func _figure_block(definition: ACEDefinition) -> Control:
	var sheet: EventSheetResource = EventSheetDocFigure.sheet_for_definition(definition)
	if sheet == null:
		return null
	var figure: EventSheetDocFigure = EventSheetDocFigure.new()
	if not figure.show_sheet(sheet):
		figure.free()
		return null
	figure.snippet_inserted.connect(func() -> void: snippet_inserted.emit())
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(4.0)))
	column.add_child(EventSheetPopupUI.small_caps_label("How this reads on the sheet"))
	column.add_child(figure)
	return column


## "Used in this sheet: 2 events - go to first / next". The one thing a reference entry can say
## that a written page never can, and the reason the count is taken HERE rather than baked into
## the blocks: the blocks are assembled once per verb, and the sheet under them changes on every
## edit.
##
## Null when the verb is not used here at all: an entry that says "used 0 times" is noise, and the
## absence is already the answer.
func _usage_block(provider_id: String, ace_id: String) -> Control:
	var sheet: EventSheetResource = EventSheets.current_sheet()
	var used: int = EventSheetDocUsage.count(sheet, provider_id, ace_id)
	if used <= 0:
		return null
	_usage_index = -1
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(6.0)))
	var label: Label = Label.new()
	label.text = EventSheetDocUsage.usage_sentence(used)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(_small_button("Go to first", "Selects the first event of this sheet that uses it.",
		func() -> void:
			_usage_index = 0
			row_requested.emit(provider_id, ace_id, 0)))
	if used > 1:
		row.add_child(_small_button("Next", "Selects the next event that uses it.",
			func() -> void:
				_usage_index = (_usage_index + 1) % used
				row_requested.emit(provider_id, ace_id, _usage_index)))
	return EventSheetPopupUI.panel_section(row)


## The neighbours, as chips. A chip is a link, not a button: clicking one is navigating, and the
## host does the navigating so this panel keeps knowing nothing about where it is hosted.
func _see_also_block(items: Array) -> Control:
	if items.is_empty():
		return null
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(4.0)))
	column.add_child(EventSheetPopupUI.small_caps_label("See also"))
	var chips: HFlowContainer = HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", int(EventSheetPalette.scaled_f(4.0)))
	chips.add_theme_constant_override("v_separation", int(EventSheetPalette.scaled_f(4.0)))
	for entry: Variant in items:
		var item: Dictionary = entry as Dictionary
		var doc_id: String = str(item.get("doc_id", ""))
		chips.add_child(_small_button(str(item.get("title", "")), "Opens this entry.",
			func() -> void: doc_requested.emit(doc_id)))
	column.add_child(chips)
	return column


## The four things a reader does with an entry once they have read it, in the sheet's own words.
## Every one of them runs a path that already exists - the public insert, the public doc router -
## so an entry can never do something to a sheet that the editor itself cannot.
func _entry_actions_block(definition: ACEDefinition) -> Control:
	if definition == null:
		return null
	var row: HFlowContainer = HFlowContainer.new()
	row.add_theme_constant_override("h_separation", int(EventSheetPalette.scaled_f(4.0)))
	row.add_theme_constant_override("v_separation", int(EventSheetPalette.scaled_f(4.0)))
	var add_label: String = "Add condition" if definition.ace_type == ACEDefinition.ACEType.CONDITION \
		else "Add action"
	if definition.ace_type != ACEDefinition.ACEType.EXPRESSION:
		row.add_child(_small_button(add_label, "Puts this row into the open sheet at the caret, as one undo step.",
			func() -> void:
				if EventSheetDocFigure.insert_definition(definition, add_label):
					snippet_inserted.emit()))
		row.add_child(_small_button("Add example events",
			"Puts the illustrated rows into the open sheet at the caret, as one undo step.",
			func() -> void:
				if EventSheetDocFigure.insert_definition(definition, "Add Example Events"):
					snippet_inserted.emit()))
	row.add_child(_small_button("Show GDScript", "Shows the line this verb compiles to.",
		func() -> void: _toggle_gdscript(definition)))
	var guide_doc: String = EventSheetDocExplain.doc_id_for_pack(
		EventSheets.addon_pack_directory(definition.provider_id))
	if not guide_doc.is_empty():
		row.add_child(_small_button("Open guide", "Opens the guide this verb is documented in.",
			func() -> void: doc_requested.emit(guide_doc)))
	_gdscript_card = _wrapped_label("")
	_gdscript_card.visible = false
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(4.0)))
	column.add_child(row)
	column.add_child(_gdscript_card)
	return column


## Show GDScript: the exact line the verb ships as, plus the member it declares when it keeps state
## between frames - which is the part the Syntax section alone does not show.
func _toggle_gdscript(definition: ACEDefinition) -> void:
	if _gdscript_card == null:
		return
	if _gdscript_card.visible:
		_gdscript_card.visible = false
		return
	var lines: PackedStringArray = PackedStringArray()
	var member: String = str(definition.metadata.get("member_template", "")).strip_edges()
	if not member.is_empty():
		lines.append(member)
	lines.append(EventSheetDocExplain.ships_as(definition))
	_gdscript_card.text = "\n".join(lines)
	_gdscript_card.visible = true


## A small flat button - the chip this surface uses for anything that is a choice rather than a
## commitment.
func _small_button(label: String, tooltip: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = EventSheetL10n.translate(label)
	button.tooltip_text = EventSheetL10n.translate(tooltip)
	button.flat = true
	button.add_theme_font_size_override("font_size", EventSheetPalette.scaled(11))
	button.pressed.connect(action)
	return button


## Read more. The button prefers the DOC ID: once the guide corpus ships inside the plugin, the
## same click draws the pack's guide natively instead of opening a tab, and a pack whose guide
## lives elsewhere still opens in the browser. The signal reports whichever route ran, so a host's
## status line stays honest about where the reader was sent.
func _link_block(label: String, target: String, doc_id: String = "") -> Control:
	if label.strip_edges().is_empty() or target.strip_edges().is_empty():
		return null
	var button: Button = Button.new()
	button.text = "%s  %s" % [label, EXTERNAL_LINK_GLYPH]
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


## Plain text, wrapping at the given width - the page column's when none is named, and never wider
## than it: a bound taken from a constant would keep a narrow host's labels at the comfortable
## width and push the column past its own minimum. See the file header for why this is never a
## BBCode control.
func _wrapped_label(text: String, wrap_width: float = -1.0) -> Label:
	var bound: float = _page_width if wrap_width <= 0.0 else minf(wrap_width, _page_width)
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(bound), 0.0)
	return label
