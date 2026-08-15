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
@tool
class_name EventSheetDocPageView
extends VBoxContainer

## The narrowest the page column is allowed to get, before display scaling. It is a FLOOR, never a
## fixed width: the page takes the width its host gives it and wraps into it, so a narrow window
## reflows instead of clipping its right-hand side (which is what a fixed column does the moment
## the host is narrower than the column).
const PAGE_MIN_WIDTH := 320.0

## Emitted when a link points at another shipped page. The host decides what to do with it (the
## browser navigates; a dock might open a second page), so this view never navigates itself.
signal doc_requested(doc_id: String, anchor: String)

## Emitted after a link was opened in the reader's browser, for a host that reports it.
signal link_activated(target: String)

## Emitted after a figure's Insert landed its rows in the reader's sheet, so a host can say so.
signal snippet_inserted()

var _doc_id: String = ""
var _doc_title: String = ""
var _anchors: Dictionary = {}
var _page_width: float = 0.0
var _scroll: ScrollContainer = null


func _init() -> void:
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
	for block: Dictionary in blocks:
		if str(block.get("kind", "")) == "heading" and int(block.get("level", 0)) == 1 and _doc_title.is_empty():
			_doc_title = str(block.get("text", ""))
		var control: Control = _control_for(block)
		if control != null:
			add_child(control)
	if _doc_title.is_empty():
		_doc_title = EventSheetDocLibrary.page_title(doc_id)
	return true


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
	if wanted.is_empty() or not _anchors.has(wanted) or _scroll == null:
		return false
	var heading: Control = _anchors[wanted] as Control
	if heading == null or not is_instance_valid(heading):
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
		"rule":
			return HSeparator.new()
	return null


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


## The body font size the whole page's scale hangs off: the editor's help font size setting when
## it exists (the reader's own choice), else the "doc" font's default size, else 16.
func _body_font_size() -> int:
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
## The header row is bold and the body cells carry padding, so a table reads as a table without a
## grid of Controls behind it.
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
	label.push_table(columns)
	for column: int in range(columns):
		label.set_table_column_expand(column, true, 1)
	for column: int in range(columns):
		label.push_cell()
		label.push_bold()
		label.append_text(str(headers[column]) if column < headers.size() else "")
		label.pop()
		label.pop()
	for entry: Variant in rows:
		var cells: Array = entry as Array
		for column: int in range(columns):
			label.push_cell()
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
	if not figure.show_sheet(sheet):
		figure.queue_free()
		return null
	return figure


## An authored fence that cannot be drawn. It is shown - with its own code underneath - because
## the author asked for an illustration: a silent code card is how a broken figure ships unnoticed.
## The suite fails on the same verdict, so this card is the reader's copy of a build error.
func _figure_error(block: Dictionary, message: String) -> Control:
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	box.add_child(EventSheetPopupUI.hint_label(message, _page_width))
	box.add_child(_code_card(block.get("lines", []) as Array, ""))
	return EventSheetPopupUI.titled_card("This figure could not be drawn", box)


## A fenced block. BBCode is OFF here on purpose: code is full of brackets and tags, and a code
## card that parsed them would rewrite the very thing the reader came to copy.
func _code_card(lines: Array, language: String) -> Control:
	var body: PackedStringArray = PackedStringArray()
	for line: Variant in lines:
		body.append(str(line))
	var label: RichTextLabel = RichTextLabel.new()
	label.bbcode_enabled = false
	label.fit_content = true
	label.selection_enabled = true
	label.context_menu_enabled = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text = "\n".join(body)
	label.custom_minimum_size = Vector2(_page_width - EventSheetPopupUI.PANEL_SECTION_PAD * 2.0, 0.0)
	var mono_font: Font = _editor_font("doc_source")
	if mono_font != null:
		label.add_theme_font_override("normal_font", mono_font)
	var body_control: Control = _wide_content_scroll(label)
	if language.strip_edges().is_empty():
		return EventSheetPopupUI.panel_section(body_control)
	return EventSheetPopupUI.titled_card(language.strip_edges(), body_control)


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
	box.add_child(EventSheetPopupUI.hint_label(caption, _page_width))
	var repo_path: String = EventSheetDocLibrary.repo_path_for_link(path, _doc_id)
	if not repo_path.is_empty():
		var button: Button = Button.new()
		button.text = "See this picture online"
		button.tooltip_text = "Opens the image in your browser, pinned to the version you installed."
		button.pressed.connect(func() -> void:
			EventSheets.open_online_doc(repo_path)
			link_activated.emit(repo_path))
		var row: HBoxContainer = HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_END
		row.add_child(button)
		box.add_child(row)
	return EventSheetPopupUI.titled_card("Picture", box)


## Every link click in the page lands here. A link to another shipped guide stays inside the
## editor; a link to a repo file the bundle deliberately excludes opens the version-pinned page in
## the browser rather than dying quietly; an absolute URL opens as itself.
func _on_meta_clicked(meta: Variant) -> void:
	var target: String = str(meta)
	var link: Dictionary = EventSheetDocMarkdown.classify_link(target)
	match str(link.get("kind", "")):
		"anchor":
			jump_to_anchor(str(link.get("anchor", "")))
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
