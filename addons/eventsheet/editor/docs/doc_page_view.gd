# EventSheet - EventSheetDocPageView: one guide, drawn as native Godot Controls.
#
# There is no HTML renderer, no WebView and no Markdown control available to a plugin, and the
# editor's own class-Help renderer is internal C++. So a page is rebuilt from Controls: prose and
# tables are RichTextLabels, headings and cards are the plugin's own popup chrome, and code is a
# monospace card. The reward for rebuilding it is that the page is themed by the reader's editor
# and can host things a browser cannot.
#
# FOUR MEASURED TRAPS THIS FILE IS SHAPED BY:
#   1. RichTextLabel ships with bbcode_enabled, fit_content, selection_enabled and
#      context_menu_enabled ALL false. A page that forgets them renders its tags literally, in
#      zero-height labels nobody can copy from.
#   2. Table styling is a PUSH-STACK operation. set_table_column_expand and friends called after
#      the text is parsed error out and silently do nothing, so a table is built imperatively with
#      push_table / push_cell, styled while the table is still on the stack.
#   3. An autowrapping fit_content label inside a container that hugs its content reports a
#      one-glyph-per-line minimum height and balloons its host. Every label here is width-BOUNDED
#      by the page column, and the host scrolls vertically only.
#   4. There are no anchors in RichTextLabel, and scroll_to_paragraph drives a label's OWN
#      scrollbar - which a fit_content label does not have. An in-page jump therefore resolves a
#      heading CONTROL and scrolls the host, one frame after layout has run.
#
# THE CHROME AROUND THE PROSE is the "compact developer" look the whole reading surface shares:
# small-caps accent labels name a card, code sits in a monospace card with a copy button in its
# corner, and a table is a compact grid under a hairline header row. A LONG page also folds: every
# chapter past the one the reader lands in collapses behind its own H2, with a chevron, and the
# fold state is remembered per page for the session so scrolling back does not re-open everything.
@tool
class_name EventSheetDocPageView
extends VBoxContainer

## The narrowest the page column is allowed to get, before display scaling. It is a FLOOR, never a
## fixed width: the page takes the width its host gives it and wraps into it, so a narrow window
## reflows instead of clipping its right-hand side (which is what a fixed column does the moment
## the host is narrower than the column).
const PAGE_MIN_WIDTH := 320.0

## Where "long enough to fold" is drawn, in ESTIMATED lines of rendered text (see estimated_lines).
## Roughly two screens of a docked column, which is the point the spec puts it at: a page a reader
## can see the end of should never be folded, and a page they cannot should offer its chapters as a
## list rather than as a scroll.
const LONG_PAGE_LINES := 80

## The chevrons a foldable chapter wears. Plain glyphs rather than icons: they sit inline with a
## heading whose size follows the reader's help-font setting, and an icon would not scale with it.
const CHEVRON_OPEN := "▾"
const CHEVRON_CLOSED := "▸"

## Emitted when a link points at another shipped page. The host decides what to do with it (the
## browser navigates; a dock might open a second page), so this view never navigates itself.
signal doc_requested(doc_id: String, anchor: String)

## Emitted after a link was opened in the reader's browser, for a host that reports it.
signal link_activated(target: String)

## Emitted after a figure's Insert landed its rows in the reader's sheet, so a host can say so.
signal snippet_inserted()

## Emitted when a figure on this page asks for its example in a scratch sheet. A page cannot open a
## tab any more than it can run a button's action - it names what it wants and the host does it.
signal scratch_requested(example_name: String, sheet: EventSheetResource)

## Emitted when the reader presses a button a derived page carries ("Write this guide"). The page
## names the action and its argument; running it is the host's business.
signal action_requested(action: String, argument: String)

var _doc_id: String = ""
var _doc_title: String = ""
var _anchors: Dictionary = {}
var _page_width: float = 0.0
var _scroll: ScrollContainer = null
## Whether this page draws its chapters as folds at all. Short pages never do: a fold is a cost
## (one more click) that only pays for itself when the alternative is a scrollbar the size of a hair.
var _folding: bool = false
## slug -> {body, chevron}: the collapsible half of each H2 chapter and the glyph that reports it.
var _sections: Dictionary = {}
## The H2 chapters in page order, as {text, slug} - what the host's mini-nav is built from.
var _outline: Array[Dictionary] = []
## Where blocks are being added right now: the open chapter's body, or the page itself before the
## first H2 (the title and the lead paragraph are never folded away).
var _current_body: VBoxContainer = null
## The chapter being filled, so a deeper heading inside it can be expanded to when an anchor jump
## names it.
var _section_slug: String = ""
## slug -> the chapter slug that owns it, for exactly that jump.
var _owner_section: Dictionary = {}
## page id -> {slug: expanded}. Static, so a reader who folded a chapter, wandered off and came
## back finds it as they left it - for the session, never on disk: this is a reading position, not
## a preference.
static var _fold_state: Dictionary = {}
## The reader's own text size for the Manual, as a multiplier on whatever body size the page would
## otherwise use. Independent of the editor's help font size on purpose: a reader who wants big
## documentation text does not necessarily want a big Script editor.
var _text_scale: float = 1.0


func _init() -> void:
	_text_scale = EventSheetDocFeedback.text_scale()
	_page_width = EventSheetPalette.scaled_f(PAGE_MIN_WIDTH)
	add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(8.0)))
	custom_minimum_size = Vector2(_page_width, 0.0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


## The scrolling host an in-page anchor jump moves. Without one, a jump resolves the heading and
## reports false rather than pretending it scrolled.
func set_scroll_container(scroll: ScrollContainer) -> void:
	_scroll = scroll


## The doc id on screen, "" when the page is empty.
func current_doc_id() -> String:
	return _doc_id


## The page's own H1, for a host that titles itself after its content.
func current_title() -> String:
	return _doc_title


## slug -> the heading Control it names. The registration an anchor jump resolves against; a test
## pins this map even though it cannot pin the scroll.
func anchors() -> Dictionary:
	return _anchors


## Draws a parsed page. Returns false for an empty block list, so a caller reports "nothing there"
## instead of showing a blank page.
func show_blocks(blocks: Array[Dictionary], doc_id: String) -> bool:
	_clear()
	if blocks.is_empty():
		return false
	_doc_id = doc_id
	_folding = is_long_page(blocks)
	var chapters: int = 0
	for block: Dictionary in blocks:
		if str(block.get("kind", "")) == "heading" and int(block.get("level", 0)) == 1 and _doc_title.is_empty():
			_doc_title = str(block.get("text", ""))
		if str(block.get("kind", "")) == "heading" and int(block.get("level", 0)) == 2:
			# The chapter the reader lands in is open; the ones below the fold start closed, which
			# is what turns a fifteen-screen guide into a page whose shape can be seen at a glance.
			_begin_section(block, chapters == 0)
			chapters += 1
			continue
		var control: Control = _control_for(block)
		if control != null:
			_add_block(control)
	if _doc_title.is_empty():
		_doc_title = EventSheetDocLibrary.page_title(doc_id)
	return true


## The H2 chapters of the page on screen, in order, as {text, slug}. The host builds its mini-nav
## from this rather than walking the children, so the nav can never disagree with the page.
func outline() -> Array[Dictionary]:
	return _outline.duplicate(true)


## True while the page draws its chapters as folds (and therefore while a mini-nav is worth
## showing). A short page reports false and is drawn exactly as it always was.
func is_folding() -> bool:
	return _folding


## Opens every folded chapter. The host calls it while a search term is live: a hit inside a
## collapsed chapter is a hit the reader cannot see, which reads as the search having missed.
func expand_all() -> void:
	for slug: Variant in _sections:
		set_section_expanded(str(slug), true)


## Folds or unfolds one chapter, and remembers it for the session. Public because the fold is a
## behaviour a test can pin without pixels, and because the mini-nav opens a chapter before it
## scrolls to it.
func set_section_expanded(slug: String, expanded: bool) -> void:
	var section: Dictionary = _sections.get(slug, {}) as Dictionary
	if section.is_empty():
		return
	var body: Control = section.get("body", null) as Control
	if body != null:
		body.visible = expanded
	var chevron: Label = section.get("chevron", null) as Label
	if chevron != null:
		chevron.text = CHEVRON_OPEN if expanded else CHEVRON_CLOSED
	var remembered: Dictionary = _fold_state.get(_doc_id, {}) as Dictionary
	remembered[slug] = expanded
	_fold_state[_doc_id] = remembered


## True when the named chapter is open. False for a slug this page does not carry a chapter for.
func is_section_expanded(slug: String) -> bool:
	var section: Dictionary = _sections.get(slug, {}) as Dictionary
	var body: Control = section.get("body", null) as Control
	return body != null and body.visible


## The chapter whose heading is at or above `offset` - what the mini-nav highlights as the reader
## scrolls.
##
## Empty until this page has been LAID OUT, and that guard is the whole point of the function: before
## layout every Control reports position zero, so a naive "is this heading at or above the offset?"
## is true for every heading at once and the last one in the page wins. A freshly opened guide then
## highlights its final chapter, which is worse than highlighting nothing. Height is the cheapest
## honest proof that a layout pass has run - a built page always has one, an unlaid one never does.
func section_at(offset: float) -> String:
	if size.y <= 0.0:
		return ""
	var tops: Array = []
	for entry: Dictionary in _outline:
		var heading: Control = _anchors.get(str(entry.get("slug", "")), null) as Control
		if heading == null or not is_instance_valid(heading):
			continue
		tops.append({"slug": str(entry.get("slug", "")), "top": heading.global_position.y - global_position.y})
	return section_for_offset(tops, offset)


## Which chapter an offset falls in, given `tops` as {slug, top} in page order. Pure and static, so
## the bearing itself is pinned by the suite while the positions it is fed stay the layout's job.
##
## A reader ABOVE the first heading (in the page's title and lead paragraph) is given the first
## chapter rather than nothing: they are reading their way into it, and a strip with no item lit is
## a strip that looks broken.
static func section_for_offset(tops: Array, offset: float) -> String:
	if tops.is_empty():
		return ""
	var found: String = str((tops[0] as Dictionary).get("slug", ""))
	for entry: Variant in tops:
		var item: Dictionary = entry as Dictionary
		if float(item.get("top", 0.0)) <= offset + 1.0:
			found = str(item.get("slug", ""))
	return found


## Whether a page is long enough to be worth folding, measured in ESTIMATED lines rather than in
## pixels: a page is built before it is laid out, so its real height does not exist at the moment
## this decision has to be made. Pure over the blocks, so the suite pins the decision itself.
static func is_long_page(blocks: Array[Dictionary]) -> bool:
	return estimated_lines(blocks) > LONG_PAGE_LINES


## A page's height in rendered lines, near enough to decide "longer than about two screens". Prose
## is counted by its own length against a typical measure; a table, a list and a code fence are
## counted by their rows; a figure is counted as the block of rows it draws.
static func estimated_lines(blocks: Array[Dictionary]) -> int:
	var lines: int = 0
	for block: Dictionary in blocks:
		match str(block.get("kind", "")):
			"heading":
				lines += 3 if int(block.get("level", 2)) <= 2 else 2
			"paragraph", "quote":
				lines += 1 + int(str(block.get("bbcode", "")).length() / 90)
			"list":
				lines += (block.get("items", []) as Array).size()
			"table":
				lines += 2 + (block.get("rows", []) as Array).size()
			"code":
				lines += 2 + (block.get("lines", []) as Array).size()
			"image":
				lines += 4
			"rule":
				lines += 1
	return lines


## Adds a block where the page is currently filling: inside the open chapter, or straight onto the
## page before the first H2.
func _add_block(control: Control) -> void:
	if _current_body != null:
		_current_body.add_child(control)
		return
	add_child(control)


## Opens a chapter: the H2 bar becomes a clickable header with a chevron, and everything until the
## next H2 goes into a body that the header shows and hides. A page that is not folding still comes
## through here, so there is ONE code path that draws an H2 - it simply builds no fold.
func _begin_section(block: Dictionary, first: bool) -> void:
	var slug: String = str(block.get("slug", ""))
	_section_slug = slug
	var bar: Control = _heading(block)
	if not _folding or slug.is_empty():
		_current_body = null
		add_child(bar)
		_outline.append({"text": str(block.get("text", "")), "slug": slug})
		return
	var chevron: Label = Label.new()
	chevron.text = CHEVRON_OPEN
	chevron.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chevron.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(16.0), 0.0)
	chevron.add_theme_color_override("font_color", EventSheetPopupUI.accent_color())
	var header: HBoxContainer = HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.tooltip_text = "Show or hide this section."
	header.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(4.0)))
	header.add_child(chevron)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(bar)
	var body: VBoxContainer = VBoxContainer.new()
	body.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(8.0)))
	var section: VBoxContainer = VBoxContainer.new()
	section.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(6.0)))
	section.add_child(header)
	section.add_child(body)
	add_child(section)
	_sections[slug] = {"body": body, "chevron": chevron}
	_outline.append({"text": str(block.get("text", "")), "slug": slug})
	_current_body = body
	header.gui_input.connect(func(event: InputEvent) -> void:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			set_section_expanded(slug, not is_section_expanded(slug)))
	set_section_expanded(slug, _remembered_fold(slug, first))


## What a chapter's fold should be: whatever the reader last left it as this session, and otherwise
## open for the chapter they land in and closed for the rest.
func _remembered_fold(slug: String, first: bool) -> bool:
	var remembered: Dictionary = _fold_state.get(_doc_id, {}) as Dictionary
	if remembered.has(slug):
		return bool(remembered[slug])
	return first


## Scrolls the host so `slug`'s heading is at the top of the view. The RESOLUTION is answered here
## and now - true when the slug names a heading this page drew, false when it names nothing, which
## is what a caller can act on - while the scroll itself happens a frame later, because Control
## positions are all zero until layout has run and an immediate jump silently lands at the top.
##
## The two halves are split on purpose: a function that awaited would be a coroutine, and its
## return value would be unreadable at every call site that does not await it (which is all of
## them - an anchor jump is fire-and-forget by nature).
func jump_to_anchor(slug: String) -> bool:
	var wanted: String = slug.strip_edges().trim_prefix("#")
	if wanted.is_empty() or not _anchors.has(wanted):
		return false
	var heading: Control = _anchors[wanted] as Control
	if heading == null or not is_instance_valid(heading):
		return false
	# A jump into a folded chapter opens it first, and it does so BEFORE the host is checked: the
	# fold is what the reader would otherwise land on - a title with nothing under it - and that is
	# true whether or not there is anything to scroll.
	set_section_expanded(wanted, true)
	set_section_expanded(str(_owner_section.get(wanted, "")), true)
	if _scroll == null:
		return false
	_scroll_to_heading(heading)
	return true


func _scroll_to_heading(heading: Control) -> void:
	if is_inside_tree():
		await get_tree().process_frame
	if _scroll == null or heading == null or not is_instance_valid(heading):
		return
	_scroll.scroll_vertical = int(heading.global_position.y - global_position.y)


func _clear() -> void:
	_doc_id = ""
	_doc_title = ""
	_anchors = {}
	_sections = {}
	_outline = []
	_owner_section = {}
	_current_body = null
	_section_slug = ""
	_folding = false
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()


func _control_for(block: Dictionary) -> Control:
	match str(block.get("kind", "")):
		"heading":
			return _heading(block)
		"paragraph":
			return _prose(str(block.get("bbcode", "")))
		"list":
			return _prose(_list_bbcode(block.get("items", []) as Array, bool(block.get("ordered", false))))
		"quote":
			return EventSheetPopupUI.panel_section(_prose(str(block.get("bbcode", ""))))
		"table":
			return _table(block)
		"code":
			return _code_or_figure(block)
		"image":
			return _image_card(str(block.get("path", "")), str(block.get("alt", "")))
		"button":
			return _button_block(block)
		"next":
			return _next_block(block)
		"rule":
			return HSeparator.new()
	return null


## A one-click offer a DERIVED page carries (the stub's "Write this guide"). A page cannot run
## anything itself: it reports the action by NAME and the host decides what that name means, which
## is what keeps this view host-agnostic.
func _button_block(block: Dictionary) -> Control:
	var button: Button = Button.new()
	button.text = EventSheetL10n.translate(str(block.get("label", "")))
	button.tooltip_text = EventSheetL10n.translate(str(block.get("tooltip", "")))
	var action: String = str(block.get("action", ""))
	var argument: String = str(block.get("argument", ""))
	button.pressed.connect(func() -> void: action_requested.emit(action, argument))
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_child(button)
	return row


## "Next: ..." at the foot of a guide. The one piece of chrome that belongs INSIDE the page rather
## than around it: it is where the reading continues, and a reader who has reached the bottom is
## already looking at the bottom.
func _next_block(block: Dictionary) -> Control:
	var button: Button = Button.new()
	button.flat = true
	button.text = "Next: %s" % str(block.get("title", ""))
	button.tooltip_text = "Opens the next page in this part of the Manual."
	var doc_id: String = str(block.get("doc_id", ""))
	button.pressed.connect(func() -> void: doc_requested.emit(doc_id, ""))
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	box.add_child(button)
	return EventSheetPopupUI.panel_section(box)


## A heading, registered under its slug so an in-page link can find it later. Headings follow a
## typographic SCALE anchored to the body font size, so a heading is always larger than the prose
## under it whatever the editor font setting - a document, not a dialog. (The dialog helpers'
## section_header is a 13 px accent label meant for a form section; used here it rendered every
## H2 SMALLER than the body text and inverted the page's hierarchy.) H1 doubles as the page title
## in the editor's own documentation title font; H2 is a chapter bar with a hairline under it; H3
## a bold run-in; H4+ a small caps-style lead. Colors stay near-white so a heading reads as
## structure, not as a link.
func _heading(block: Dictionary) -> Control:
	var text: String = str(block.get("text", ""))
	var level: int = int(block.get("level", 2))
	var body: int = _body_font_size()
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var heading_font: Font = _editor_font("doc_bold")
	if level <= 1:
		var title_font: Font = _editor_font("doc_title")
		if title_font != null:
			heading_font = title_font
		label.add_theme_font_size_override("font_size", int(round(body * 1.6)))
	elif level == 2:
		label.add_theme_font_size_override("font_size", int(round(body * 1.3)))
	elif level == 3:
		label.add_theme_font_size_override("font_size", int(round(body * 1.12)))
	else:
		label.add_theme_font_size_override("font_size", body)
	if heading_font != null:
		label.add_theme_font_override("font", heading_font)
	label.add_theme_color_override("font_color", _heading_color(level))
	var slug: String = str(block.get("slug", ""))
	if not slug.is_empty():
		_anchors[slug] = label
		if level > 2 and not _section_slug.is_empty():
			_owner_section[slug] = _section_slug
	if level == 2:
		# A chapter bar: breathing room above and a hairline beneath, so the eye finds sections
		# while scanning the way it does on the rendered web page.
		var bar: VBoxContainer = VBoxContainer.new()
		bar.add_theme_constant_override("separation", 4)
		var spacer: Control = Control.new()
		spacer.custom_minimum_size = Vector2(0.0, float(body) * 0.6)
		bar.add_child(spacer)
		bar.add_child(label)
		var rule: ColorRect = ColorRect.new()
		rule.custom_minimum_size = Vector2(0.0, 1.0)
		rule.color = _heading_color(2)
		rule.color.a = 0.28
		bar.add_child(rule)
		return bar
	return label


## The reader's text size for this page. The caller redraws the page afterwards - every font size on
## it was baked into a theme override while it was being built, and there is no way to re-ask a
## label for a size it has already been told.
func set_text_scale(scale: float) -> void:
	_text_scale = EventSheetDocFeedback.clamped_scale(scale)


## The body font size the whole page's scale hangs off: the editor's help font size setting when
## it exists (the reader's own choice), else the "doc" font's default size, else 16, and all of it
## multiplied by the reader's own A- / A+ choice for the Manual.
func _body_font_size() -> int:
	return maxi(int(round(float(_base_font_size()) * _text_scale)), 8)


## The size before the reader's own Manual text size is applied to it.
func _base_font_size() -> int:
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		var editor_interface: Object = Engine.get_singleton("EditorInterface")
		if editor_interface != null and editor_interface.has_method("get_editor_settings"):
			var settings: Object = editor_interface.get_editor_settings()
			if settings != null and settings.has_method("get_setting") and settings.has_setting("text_editor/help/help_font_size"):
				return maxi(int(settings.get_setting("text_editor/help/help_font_size")), 8)
	var body_font: Font = _editor_font("doc")
	if body_font != null:
		var theme_size: int = _editor_font_size("doc_size")
		if theme_size > 0:
			return theme_size
	return EventSheetPalette.scaled(16)


## Headings read as structure: near-white for the title and chapters, a touch softer down the
## scale. Not the accent color - accent is what LINKS wear on this page.
func _heading_color(level: int) -> Color:
	var base: Color = Color(0.93, 0.94, 0.96)
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		var editor_interface: Object = Engine.get_singleton("EditorInterface")
		if editor_interface != null and editor_interface.has_method("get_editor_theme"):
			var theme: Theme = editor_interface.get_editor_theme()
			if theme != null and theme.has_color("font_color", "Editor"):
				base = theme.get_color("font_color", "Editor").lightened(0.15)
	return base if level <= 2 else base.darkened(0.08)


## A named font SIZE from the editor theme's EditorFonts, or 0 when unknown.
func _editor_font_size(size_name: String) -> int:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return 0
	var editor_interface: Object = Engine.get_singleton("EditorInterface")
	if editor_interface == null or not editor_interface.has_method("get_editor_theme"):
		return 0
	var theme: Theme = editor_interface.get_editor_theme()
	if theme == null or not theme.has_font_size(size_name, "EditorFonts"):
		return 0
	return theme.get_font_size(size_name, "EditorFonts")


## One wrapping RichTextLabel per prose run, with every flag the control does NOT default to.
func _prose(bbcode: String) -> Control:
	var label: RichTextLabel = RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.selection_enabled = true
	label.context_menu_enabled = true
	label.scroll_active = false
	label.custom_minimum_size = Vector2(_page_width, 0.0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var body_font: Font = _editor_font("doc")
	if body_font != null:
		label.add_theme_font_override("normal_font", body_font)
	var bold_font: Font = _editor_font("doc_bold")
	if bold_font != null:
		label.add_theme_font_override("bold_font", bold_font)
	var mono_font: Font = _editor_font("doc_source")
	if mono_font != null:
		label.add_theme_font_override("mono_font", mono_font)
	# One size for the whole page: the same number the heading scale is anchored to, so a reader
	# who bumps the help font size in Editor Settings sees prose and headings grow together.
	var body: int = _body_font_size()
	label.add_theme_font_size_override("normal_font_size", body)
	label.add_theme_font_size_override("bold_font_size", body)
	label.add_theme_font_size_override("italics_font_size", body)
	label.add_theme_font_size_override("mono_font_size", maxi(body - 1, 8))
	label.meta_clicked.connect(_on_meta_clicked)
	label.append_text(bbcode)
	return label


## A list is one label, not one per item: a stack of labels loses the hanging indent and pays a
## control per bullet on pages that carry hundreds.
func _list_bbcode(items: Array, ordered: bool) -> String:
	var lines: PackedStringArray = PackedStringArray()
	var number: int = 0
	for entry: Variant in items:
		var item: Dictionary = entry as Dictionary
		var indent: int = maxi(0, int(item.get("indent", 0)))
		number += 1
		var marker: String = "%d." % number if ordered and indent == 0 else "•"
		lines.append("%s%s  %s" % ["    ".repeat(indent), marker, str(item.get("bbcode", ""))])
	return "\n".join(lines)


## A table, built imperatively because the styling API is a push-stack operation (see the header).
## It wears the compact look the reference pages use - muted uppercase headings over a hairline,
## dense padded cells - but it is NOT the shared compact_table helper: a guide's cells carry BBCode
## (links, code spans, and the search term wrapped in a highlight), and a plain-text grid would
## render every one of those tags literally and kill the links with them. The two therefore have to
## be kept looking alike BY HAND, and the header row is where they last drifted apart: accent text
## over an accent band here, muted text under a white hairline there. Accent on this surface belongs
## to the small-caps section labels and to the active sidebar row; a table heading is neither.
func _table(block: Dictionary) -> Control:
	var headers: Array = block.get("headers", []) as Array
	var rows: Array = block.get("rows", []) as Array
	var columns: int = maxi(1, headers.size())
	var label: RichTextLabel = RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.selection_enabled = true
	label.context_menu_enabled = true
	label.scroll_active = false
	label.custom_minimum_size = Vector2(_page_width - EventSheetPopupUI.PANEL_SECTION_PAD * 2.0, 0.0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.meta_clicked.connect(_on_meta_clicked)
	var pad: Rect2 = Rect2(EventSheetPalette.scaled_f(6.0), EventSheetPalette.scaled_f(3.0),
		EventSheetPalette.scaled_f(6.0), EventSheetPalette.scaled_f(3.0))
	label.push_table(columns)
	for column: int in range(columns):
		label.set_table_column_expand(column, true, 1)
	# The header row is a hairline UNDER muted uppercase text, exactly what the shared table cell
	# draws: the rule is what says where the headings stop, and it does it without spending the
	# page's one accent colour on a column name.
	for column: int in range(columns):
		label.push_cell()
		label.set_cell_border_color(EventSheetPopupUI.TABLE_HAIRLINE)
		label.set_cell_padding(pad)
		label.push_color(EventSheetPalette.TEXT_MUTED)
		label.push_bold()
		label.append_text(str(headers[column]).to_upper() if column < headers.size() else "")
		label.pop()
		label.pop()
		label.pop()
	for entry: Variant in rows:
		var cells: Array = entry as Array
		for column: int in range(columns):
			label.push_cell()
			label.set_cell_padding(pad)
			label.append_text(str(cells[column]) if column < cells.size() else "")
			label.pop()
	label.pop()
	return EventSheetPopupUI.panel_section(label)


## A fenced block, drawn as whatever the recognizer says it is: a live figure of the rows the code
## lifts to, a loud error when an AUTHORED figure cannot be drawn (silence there would ship a
## guide whose illustration quietly vanished), or the code card every fence has always had.
func _code_or_figure(block: Dictionary) -> Control:
	var verdict: Dictionary = EventSheetDocFigures.recognize(block)
	match str(verdict.get("mode", "")):
		EventSheetDocFigures.MODE_FIGURE:
			var figure: Control = _figure(str(verdict.get("body", "")), str(verdict.get("caption", "")))
			if figure != null:
				return figure
		EventSheetDocFigures.MODE_ERROR:
			return _figure_error(block, str(verdict.get("error", "")))
	return _code_card(block.get("lines", []) as Array, str(block.get("language", "")))


## The live illustration: the real renderer drawing the rows this fence's code lifts to, with the
## Insert button no static picture can carry. Returns null when the sheet refuses to draw, so the
## caller falls back to the code card rather than leaving a hole in the page.
func _figure(body: String, caption: String) -> Control:
	var sheet: EventSheetResource = EventSheetDocFigures.sheet_for_body(body)
	if sheet == null:
		return null
	var figure: EventSheetDocFigure = EventSheetDocFigure.new()
	figure.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	figure.set_caption(caption)
	figure.snippet_inserted.connect(func() -> void: snippet_inserted.emit())
	figure.scratch_requested.connect(func(example_name: String, example: EventSheetResource) -> void:
		# A figure's caption is the nearest heading above it, and an UNCAPTIONED one has nothing to
		# name its tab with - so the page it sits on names it instead.
		scratch_requested.emit(example_name if not example_name.is_empty() else _doc_title, example))
	if not figure.show_sheet(sheet):
		figure.queue_free()
		return null
	return figure


## An authored fence that cannot be drawn. It is shown - with its own code underneath - because
## the author asked for an illustration: a silent code card is how a broken figure ships unnoticed.
## The suite fails on the same verdict, so this card is the reader's copy of a build error.
func _figure_error(block: Dictionary, message: String) -> Control:
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	box.add_child(_card_label_row("This figure could not be drawn"))
	box.add_child(EventSheetPopupUI.hint_label(message, _page_width))
	box.add_child(_code_card(block.get("lines", []) as Array, ""))
	return EventSheetPopupUI.panel_section(box)


## A fenced block, as the surface's code card: a small-caps label naming the language, the shared
## copy button in its top-right corner, and the code itself in the editor's monospace font.
##
## It is built here rather than taken from the popup helpers because a GUIDE's fence must not
## re-wrap: the helper's card autowraps (right for a one-line syntax string, wrong for a listing
## whose indentation is the meaning), so the card shape is shared while the body scrolls sideways
## inside itself - see _wide_content_scroll.
##
## BBCode is OFF here on purpose: code is full of brackets and tags, and a code card that parsed
## them would rewrite the very thing the reader came to copy.
func _code_card(lines: Array, language: String) -> Control:
	var body: PackedStringArray = PackedStringArray()
	for line: Variant in lines:
		body.append(str(line))
	var source: String = "\n".join(body)
	var label: RichTextLabel = RichTextLabel.new()
	label.bbcode_enabled = false
	label.fit_content = true
	label.selection_enabled = true
	label.context_menu_enabled = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text = source
	label.custom_minimum_size = Vector2(_page_width - EventSheetPopupUI.PANEL_SECTION_PAD * 2.0, 0.0)
	var mono_font: Font = _editor_font("doc_source")
	if mono_font != null:
		label.add_theme_font_override("normal_font", mono_font)
	var card: VBoxContainer = VBoxContainer.new()
	card.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(4.0)))
	card.add_child(_card_label_row(language.strip_edges() if not language.strip_edges().is_empty() else "Code",
		EventSheetPopupUI.copy_button(source)))
	card.add_child(_wide_content_scroll(label))
	return EventSheetPopupUI.panel_section(card)


## A card's header line: its small-caps label on the left, and whatever tool the card offers
## (a copy button, a link) pushed to the right-hand corner.
func _card_label_row(label_text: String, trailing: Control = null) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(6.0)))
	var label: Label = EventSheetPopupUI.small_caps_label(label_text)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	if trailing != null:
		row.add_child(trailing)
	return row


## An editor theme icon by name, or null outside the editor (and for a name this build does not
## carry, which is why every caller has a wordy fallback).
func _editor_icon(icon_name: String) -> Texture2D:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return null
	var editor_interface: Object = Engine.get_singleton("EditorInterface")
	if editor_interface == null or not editor_interface.has_method("get_editor_theme"):
		return null
	var theme: Theme = editor_interface.get_editor_theme()
	if theme == null or not theme.has_icon(icon_name, "EditorIcons"):
		return null
	return theme.get_icon(icon_name, "EditorIcons")


## Code is the one block that must neither re-wrap nor widen the page. A label with autowrap off
## reports its LONGEST LINE as its minimum width, and a page column takes the widest minimum on it -
## so one long line in a guide silently sets the width of the whole page, which is unreadable in a
## dock. The line scrolls inside its own card instead: the only horizontal scrollbar on the page,
## and it is on the one block a reader expects to scroll.
func _wide_content_scroll(content: Control) -> ScrollContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	return scroll


## Images do not ship with the plugin (they are 5 MB of PNGs, and every one of them would cost the
## reader's project an import pass). The alt text this repo writes is unusually descriptive, so an
## image degrades to a caption card with a button that opens the real picture online.
func _image_card(path: String, alt: String) -> Control:
	var caption: String = alt.strip_edges()
	if caption.is_empty():
		caption = path.get_file()
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	var repo_path: String = EventSheetDocLibrary.repo_path_for_link(path, _doc_id)
	var button: Button = null
	if not repo_path.is_empty():
		button = Button.new()
		button.text = "See this picture online"
		button.tooltip_text = "Opens the image in your browser, pinned to the version you installed."
		var link_icon: Texture2D = _editor_icon("ExternalLink")
		if link_icon != null:
			button.icon = link_icon
		button.pressed.connect(func() -> void:
			EventSheets.open_online_doc(repo_path)
			link_activated.emit(repo_path))
	box.add_child(_card_label_row("Picture", button))
	box.add_child(EventSheetPopupUI.hint_label(caption, _page_width))
	return EventSheetPopupUI.panel_section(box)


## Every link click in the page lands here. A link to another shipped guide stays inside the
## editor; a link to a repo file the bundle deliberately excludes opens the version-pinned page in
## the browser rather than dying quietly; an absolute URL opens as itself.
func _on_meta_clicked(meta: Variant) -> void:
	var target: String = str(meta)
	var link: Dictionary = EventSheetDocMarkdown.classify_link(target)
	match str(link.get("kind", "")):
		"anchor":
			jump_to_anchor(str(link.get("anchor", "")))
		"docid":
			# A derived page (a reference table's verb, the glossary's related terms) links by id.
			# It goes out the same signal a guide link does, so the host navigates one way.
			doc_requested.emit(target, "")
		"url":
			OS.shell_open(target)
			link_activated.emit(target)
		"doc":
			var id: String = EventSheetDocLibrary.id_for_link(str(link.get("target", "")), _doc_id)
			if not id.is_empty():
				doc_requested.emit("guide:%s" % id, str(link.get("anchor", "")))
				return
			var repo_path: String = EventSheetDocLibrary.repo_path_for_link(str(link.get("target", "")), _doc_id)
			if not repo_path.is_empty():
				EventSheets.open_online_doc(repo_path, str(link.get("anchor", "")))
				link_activated.emit(repo_path)


## An editor documentation font by name ("doc", "doc_title", "doc_source"), or null outside the
## editor where the default font is the only one there is.
func _editor_font(font_name: String) -> Font:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return null
	var editor_interface: Object = Engine.get_singleton("EditorInterface")
	if editor_interface == null or not editor_interface.has_method("get_editor_theme"):
		return null
	var theme: Theme = editor_interface.get_editor_theme()
	if theme == null or not theme.has_font(font_name, "EditorFonts"):
		return null
	return theme.get_font(font_name, "EditorFonts")
