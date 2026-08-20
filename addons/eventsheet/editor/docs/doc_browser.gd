# EventSheet - EventSheetDocBrowser: the whole documentation surface, host-agnostic.
#
# A tree of every shipped guide on the left, and on the right EITHER a rendered guide page or the
# generated "what does this row do?" panel - because both answer the same question and a reader
# should not have to know which one they are about to get. EventSheets.open_docs hands this
# control a doc id and the browser picks the surface:
#
#   "guide:<id>"                a shipped guide, rendered natively    -> the page view
#   "addon:<pack>"              a pack's guide - the SAME native page when the bundle carries it,
#                               and the version-pinned browser tab when it does not
#   "module:<name>"             a vocabulary module's guide, native when it ships
#   "ace:…" / "section:…" / ""  the live registry                     -> the explain panel
#
# It is a plain Control on purpose: the Manual window parents it, the Manual DOCK parents the
# same control in a column a third as wide, and neither host is named here. It owns no window, no
# shortcut and no menu.
#
# COMPACT mode is what makes the dock viable: a side-by-side tree and page need about 560 px, and a
# dock slot is nowhere near that. Compact keeps the same two halves and simply stops showing them at
# once - the tree becomes a "Contents" toggle that folds away again the moment the reader picks a
# page, so the whole width belongs to the prose while reading. A host that says so (set_auto_compact)
# gets that decision made for it from its own width, so a docked reader who drags the dock wide - or
# floats it onto a second monitor - gets the tree back without touching a setting.
#
# THE SIDEBAR is grouped, dense and quiet: small-caps group labels, a tiny kind icon per row, and
# the page on screen filled with the editor's accent so the reader's place is never in doubt. Under
# it sits a row of small icon buttons - the way out to the online page and to the repository - and
# under a long page a sticky mini-nav of its chapters, which is the other half of the folding the
# page view does.
@tool
class_name EventSheetDocBrowser
extends VBoxContainer

## The guide ids that open when the reader picks nothing in particular. The index page first, and
## the recipes guide when a bundle without an index somehow ships.
const HOME_IDS := ["README", "GUIDE-RECIPES"]

## The width the tree and the page need SIDE BY SIDE: a narrow column for the guide names and a
## readable measure for the prose beside it. A host narrower than this asks for compact mode.
const WIDE_MIN_WIDTH := 560.0

## The floor in compact mode. Only one half is ever on screen, so this is what a readable line of
## prose needs, not what a tree plus a page needs.
const COMPACT_MIN_WIDTH := 260.0

## Where a self-sizing host (a dock) drops its sidebar to a collapsible strip. Below this a tree
## beside a page leaves neither of them readable, so the tree folds behind its toggle instead.
const AUTO_COMPACT_WIDTH := 420.0

## The kind icons a sidebar row wears, best first per kind: the editor carries different icon sets
## across builds, so each kind names alternatives and the first one this editor has wins.
##
## Every kind's FIRST choice is a different icon from every other kind's, which is the whole reason
## the marks are here: a mark that two kinds share tells the reader nothing they could not already
## see. (Later alternatives may repeat - by the time a build is missing three icons in a row, a
## recognisable glyph beats a unique one.)
const KIND_ICONS := {
	"guide": ["TextFile", "File", "Help"],
	"addon": ["PluginScript", "EditorPlugin", "Object"],
	"module": ["Object", "Node", "TextFile"],
	"pack": ["Script", "GDScript", "Object"],
	"project": ["Folder", "File", "TextFile"],
}

## The widest a line of prose is allowed to get, before display scaling: about eighty characters
## at the editor's documentation font. A page that fills a floated Manual edge to edge is a page
## whose lines the eye loses its place in, so the column stops growing and the room goes to the
## margins instead.
const READING_MAX_WIDTH := 720.0

## The action an untranslated page's note carries: open the folder a translated page would go in.
## Named here because this is the one place that name means something.
const ACTION_TRANSLATIONS := "open_translations"

## The one doc-id scheme this surface does not draw itself: the engine's own class reference,
## which the editor already has a renderer for.
const ENGINE_SCHEME := "engine:"

## The guide list's width, and the wider one a list of RESULTS gets: a guide row is a name, a
## result row is a sentence.
const SIDEBAR_MIN_WIDTH := 210.0
const RESULTS_MIN_WIDTH := 330.0

## Emitted when the browser opened something in the reader's browser instead of drawing it, so a
## host can say so in its status line.
signal link_activated(target: String)

## Emitted after a figure's Insert lands rows in the sheet.
signal snippet_inserted()

## Emitted when an example asks to be opened in a scratch sheet of its own. The Manual does not own
## the tab strip, so it names what it wants and its host opens it.
signal scratch_requested(example_name: String, sheet: EventSheetResource)

## Emitted when a tutorial step names a control the reader should use, so the host can make the real
## one pulse. The label is the control's own text, which is how it is resolved - there is no map of
## keys to buttons for anybody to keep up to date.
signal control_highlight_requested(control_label: String)

## Emitted when the reader presses Esc, which means "give the sheet back its focus". The Manual has
## no idea where the sheet is; its host does.
signal focus_returned()

## Emitted when a reference entry asks to be taken to one of the rows of the open sheet that
## already use its verb. The host owns the sheet, so the host does the revealing.
signal row_requested(provider_id: String, ace_id: String, index: int)

var _tree: Tree = null
var _search: LineEdit = null
var _scroll: ScrollContainer = null
var _split: HSplitContainer = null
var _side: VBoxContainer = null
var _contents_button: Button = null
var _compact: bool = false
var _page: EventSheetDocPageView = null
var _panel: EventSheetDocPanel = null
var _items_by_id: Dictionary = {}
var _current_id: String = ""
## The chapter strip above the page, and the buttons in it keyed by slug so the current one can be
## filled without rebuilding the strip on every scroll tick.
var _mini_nav: HBoxContainer = null
var _mini_nav_strip: ScrollContainer = null
var _nav_buttons: Dictionary = {}
var _nav_current: String = ""
## The tree row wearing the accent pill, so it can be given back its normal colours when the reader
## moves on. Held rather than searched: a tree of a few hundred rows is walked otherwise, per click.
var _active_item: TreeItem = null
## Whether this host sizes the browser itself (a dock) rather than declaring a mode (a window).
var _auto_compact: bool = false
## The live search term. It drives BOTH halves of a search - which pages the tree offers, and
## whether the page on screen is drawn with its hits wrapped - so navigating from a result keeps
## the highlight the reader searched for.
var _query: String = ""
## The chrome above the page: where the reader is, and the four things they reach for without
## thinking.
var _breadcrumb: Label = null
var _back_button: Button = null
var _forward_button: Button = null
var _recent_button: MenuButton = null
var _bookmark_button: Button = null
## The page column's margins - how the prose is held to a readable measure in a host far wider
## than one (a floated Manual, a second monitor).
var _reading_margin: MarginContainer = null
## The verb a search result named, keyed by the tree row, so Ctrl+Enter adds THAT verb without
## asking the vocabulary again.
var _result_definitions: Dictionary = {}
## The foot of the page: the reader answering it back, and the two text-size buttons.
var _helpful_prompt: Label = null
var _helpful_yes: Button = null
var _helpful_no: Button = null
var _report_button: Button = null
var _text_size_label: Label = null


func _init() -> void:
	# The whole surface asks for room for a tree AND a readable column. The page itself only has a
	# floor, so a host narrower than this scrolls its own way rather than clipping the prose.
	custom_minimum_size = Vector2(EventSheetPalette.scaled_f(WIDE_MIN_WIDTH), 0.0)
	add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(6.0)))
	# The search box spans the whole surface rather than sitting over the tree: it searches the
	# corpus, not the tree, and in compact mode the tree is not on screen to sit over.
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(6.0)))
	_contents_button = Button.new()
	_contents_button.text = "Contents"
	_contents_button.tooltip_text = "Show the Manual's contents."
	_contents_button.toggle_mode = true
	_contents_button.visible = false
	_contents_button.toggled.connect(_on_contents_toggled)
	header.add_child(_contents_button)
	_search = LineEdit.new()
	_search.placeholder_text = "Search the Manual…"
	_search.clear_button_enabled = true
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(_on_search_changed)
	_search.gui_input.connect(_on_search_gui_input)
	header.add_child(_search)
	add_child(header)
	add_child(_build_chrome())

	_split = HSplitContainer.new()
	_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_split)
	_side = VBoxContainer.new()
	_side.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(4.0)))
	_side.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(SIDEBAR_MIN_WIDTH), 0.0)
	_tree = Tree.new()
	_tree.hide_root = true
	_tree.allow_reselect = true
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Dense rows: this is a list of names in a narrow column, not a form. The tighter separation and
	# the smaller indent are what fit a whole corpus into a dock without a scroll on the tree too.
	_tree.add_theme_constant_override("v_separation", int(EventSheetPalette.scaled_f(2.0)))
	_tree.add_theme_constant_override("item_margin", int(EventSheetPalette.scaled_f(6.0)))
	_tree.item_selected.connect(_on_tree_selected)
	_side.add_child(_tree)
	_side.add_child(_build_side_footer())
	_split.add_child(_side)

	_page = EventSheetDocPageView.new()
	_page.doc_requested.connect(func(doc_id: String, anchor: String) -> void: show_doc(doc_id, anchor))
	_page.link_activated.connect(func(target: String) -> void: link_activated.emit(target))
	_page.snippet_inserted.connect(func() -> void: snippet_inserted.emit())
	_page.scratch_requested.connect(func(example_name: String, example: EventSheetResource) -> void:
		scratch_requested.emit(example_name, example))
	_page.action_requested.connect(_on_page_action)
	# A page is BUILT before it is laid out, so the bearing taken while building it has no positions
	# to read. Its own layout is what says there are some, and a fold opening or closing re-fires it.
	_page.resized.connect(_refresh_nav_highlight)
	_panel = EventSheetDocPanel.new()
	_panel.link_activated.connect(func(target: String) -> void: link_activated.emit(target))
	_panel.snippet_inserted.connect(func() -> void: snippet_inserted.emit())
	_panel.scratch_requested.connect(func(example_name: String, example: EventSheetResource) -> void:
		scratch_requested.emit(example_name, example))
	_panel.doc_requested.connect(func(doc_id: String) -> void: show_doc(doc_id))
	_panel.row_requested.connect(func(provider_id: String, ace_id: String, index: int) -> void:
		row_requested.emit(provider_id, ace_id, index))
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(8.0)))
	column.add_child(_panel)
	column.add_child(_page)
	# The page scrolls; it never grows sideways. Horizontal scrolling is DISABLED so every
	# wrapping label inside is width-driven by this container rather than by its own content,
	# which is the difference between a readable column and a host that balloons.
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# The prose is held to a readable measure by MARGINS rather than by a fixed column width: a
	# fixed column clips the moment the host is narrower than it, while margins simply go to zero.
	_reading_margin = MarginContainer.new()
	_reading_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reading_margin.add_child(column)
	_scroll.add_child(_reading_margin)
	_page.set_scroll_container(_scroll)
	# The page host: the mini-nav pinned above the scroll rather than inside it, which is the whole
	# point of it - a chapter list that scrolled away with the page would be a table of contents.
	var host: VBoxContainer = VBoxContainer.new()
	host.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(4.0)))
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_mini_nav = HBoxContainer.new()
	_mini_nav.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(2.0)))
	# ONE line, always. A wrapping strip of chapter names is four lines of a dock column on a long
	# guide - a table of contents where a bearing was wanted - so it scrolls sideways instead.
	_mini_nav_strip = ScrollContainer.new()
	_mini_nav_strip.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_mini_nav_strip.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_mini_nav_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mini_nav_strip.visible = false
	_mini_nav_strip.add_child(_mini_nav)
	host.add_child(_mini_nav_strip)
	host.add_child(_scroll)
	host.add_child(_build_page_foot())
	_split.add_child(host)
	_scroll.get_v_scroll_bar().value_changed.connect(_on_page_scrolled)
	_build_tree()
	# Reading the whole corpus into a search index is the one thing here that costs a tenth of a
	# second or so, and the moment it would otherwise happen is the worst one available: mid
	# keystroke, in the search box, the first time anyone types. So it is warmed on an idle frame
	# after this surface exists - the reader is reading the page it landed on while it happens.
	_warm_search_index.call_deferred()


## Builds the search index if nothing has yet. Idempotent by construction - the index is built once
## per session and cached - so calling it early only moves WHEN the reader pays for it.
func _warm_search_index() -> void:
	EventSheetDocSearch.index()


## The chrome above the page: where the reader is, and the four things every reader reaches for
## without thinking - back, forward, what they read recently, and what they kept.
func _build_chrome() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(4.0)))
	_breadcrumb = Label.new()
	_breadcrumb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_breadcrumb.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_breadcrumb.add_theme_font_size_override("font_size", EventSheetPalette.scaled(11))
	_breadcrumb.add_theme_color_override("font_color", EventSheetActiveTheme.manual().resolve_muted(EventSheetPalette.TEXT_MUTED))
	_breadcrumb.text = EventSheetDocReference.MANUAL_TITLE
	row.add_child(_breadcrumb)
	_back_button = _icon_button(["Back", "ArrowLeft"], "◀", "Back (Alt+Left).", go_back_pressed)
	row.add_child(_back_button)
	_forward_button = _icon_button(["Forward", "ArrowRight"], "▶", "Forward (Alt+Right).",
		go_forward_pressed)
	row.add_child(_forward_button)
	_recent_button = MenuButton.new()
	_recent_button.flat = true
	_recent_button.text = "Recent"
	_recent_button.tooltip_text = "The pages you have read this session."
	_recent_button.add_theme_font_size_override("font_size", EventSheetPalette.scaled(10))
	_recent_button.about_to_popup.connect(_fill_recent_menu)
	_recent_button.get_popup().id_pressed.connect(_on_recent_chosen)
	row.add_child(_recent_button)
	_bookmark_button = Button.new()
	_bookmark_button.flat = true
	_bookmark_button.toggle_mode = true
	_bookmark_button.text = "☆"
	_bookmark_button.tooltip_text = "Bookmark this page."
	_bookmark_button.focus_mode = Control.FOCUS_NONE
	_bookmark_button.pressed.connect(_on_bookmark_pressed)
	row.add_child(_bookmark_button)
	_refresh_chrome()
	return row


## The foot of every page: the reader answering it back. Pinned BELOW the scroll rather than added
## to the page's own blocks, so it is reachable from a long guide without scrolling to the end of it
## - and so a derived page (a reference table, the glossary) gets it for free.
##
## Nothing here sends anything. The two answers are written on this machine and read by nobody; the
## report button OPENS the tracker in the reader's browser with the page named in the title, and the
## reader types and submits it themselves.
func _build_page_foot() -> HBoxContainer:
	var foot: HBoxContainer = HBoxContainer.new()
	foot.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(4.0)))
	_helpful_prompt = Label.new()
	_helpful_prompt.text = EventSheetDocFeedback.PROMPT
	_helpful_prompt.add_theme_font_size_override("font_size", EventSheetPalette.scaled(10))
	_helpful_prompt.add_theme_color_override("font_color", EventSheetActiveTheme.manual().resolve_muted(EventSheetPalette.TEXT_MUTED))
	foot.add_child(_helpful_prompt)
	_helpful_yes = _foot_button(EventSheetDocFeedback.YES_LABEL,
		"Kept on this machine. Nothing is sent anywhere.",
		func() -> void: _answer_helpful(EventSheetDocFeedback.YES))
	foot.add_child(_helpful_yes)
	_helpful_no = _foot_button(EventSheetDocFeedback.NO_LABEL,
		"Kept on this machine. Nothing is sent anywhere.",
		func() -> void: _answer_helpful(EventSheetDocFeedback.NO))
	foot.add_child(_helpful_no)
	_report_button = _foot_button(EventSheetDocFeedback.REPORT_LABEL,
		"Opens the project's issue tracker in your browser, with this page's name already in the title. It opens a page - it never sends one.",
		_on_report_pressed)
	foot.add_child(_report_button)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(spacer)
	foot.add_child(_foot_button(EventSheetDocFeedback.SMALLER_LABEL, "Smaller text in the Manual.",
		func() -> void: _step_text_size(-1)))
	_text_size_label = Label.new()
	_text_size_label.add_theme_font_size_override("font_size", EventSheetPalette.scaled(10))
	_text_size_label.add_theme_color_override("font_color", EventSheetActiveTheme.manual().resolve_muted(EventSheetPalette.TEXT_MUTED))
	foot.add_child(_text_size_label)
	foot.add_child(_foot_button(EventSheetDocFeedback.LARGER_LABEL, "Larger text in the Manual.",
		func() -> void: _step_text_size(1)))
	return foot


## A small flat word button, the shape the whole foot is made of.
func _foot_button(label: String, tooltip: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.flat = true
	button.text = label
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", EventSheetPalette.scaled(10))
	button.pressed.connect(action)
	return button


## Records the reader's answer and shows it. Pressing the same button again clears it, which is the
## only way to take back a "No" pressed by accident.
func _answer_helpful(answer: int) -> void:
	_refresh_page_foot(EventSheetDocFeedback.set_helpful(_current_id, answer))


## The foot, re-read off the page on screen: which answer this page carries, and the text size.
func _refresh_page_foot(answer: int = -2) -> void:
	if _helpful_prompt == null:
		return
	var now: int = EventSheetDocFeedback.helpful(_current_id) if answer == -2 else answer
	var line: String = EventSheetDocFeedback.answer_line(now)
	_helpful_prompt.text = EventSheetDocFeedback.PROMPT if line.is_empty() else line
	_helpful_prompt.tooltip_text = _helpful_prompt.text
	var accent: Color = EventSheetPopupUI.accent_color()
	var muted: Color = EventSheetActiveTheme.manual().resolve_muted(EventSheetPalette.TEXT_MUTED)
	_helpful_yes.add_theme_color_override("font_color",
		accent if now == EventSheetDocFeedback.YES else muted)
	_helpful_no.add_theme_color_override("font_color",
		accent if now == EventSheetDocFeedback.NO else muted)
	_text_size_label.text = EventSheetDocFeedback.scale_label(EventSheetDocFeedback.text_scale())


## A- / A+: remembers the size and redraws the page, because every font size on a built page was
## baked into a theme override while it was being built.
func _step_text_size(steps: int) -> void:
	var next: float = EventSheetDocFeedback.stepped_scale(EventSheetDocFeedback.text_scale(), steps)
	EventSheetDocFeedback.set_text_scale(next)
	_page.set_text_scale(next)
	_refresh_page_foot()
	if not _current_id.is_empty():
		_open(_current_id, "", false)


## "Report a problem": the tracker, in the reader's browser, with the page already named. It opens;
## it never submits.
func _on_report_pressed() -> void:
	var url: String = EventSheetDocFeedback.report_url(EventSheets.DOCS_REPO_URL, current_title(),
		_current_id)
	if url.is_empty():
		return
	OS.shell_open(url)
	link_activated.emit(url)


## One step back through the pages read this session. The HISTORY moves first and the navigation
## follows, so a page that no longer ships leaves the reader where they were rather than nowhere.
func go_back() -> bool:
	var target: String = EventSheetDocHistory.go_back()
	return false if target.is_empty() else _open(target, "", false)


func go_forward() -> bool:
	var target: String = EventSheetDocHistory.go_forward()
	return false if target.is_empty() else _open(target, "", false)


## The button halves, which take no argument and answer nothing - a Button.pressed Callable cannot
## carry either.
func go_back_pressed() -> void:
	go_back()


func go_forward_pressed() -> void:
	go_forward()


func _fill_recent_menu() -> void:
	var popup: PopupMenu = _recent_button.get_popup()
	popup.clear()
	var recent: Array[String] = EventSheetDocHistory.recent()
	var bookmarks: Array[String] = EventSheetDocHistory.bookmarks()
	for index: int in range(recent.size()):
		popup.add_item(title_for_doc(recent[index]), index)
	if not bookmarks.is_empty():
		popup.add_separator("Bookmarks")
		for index: int in range(bookmarks.size()):
			popup.add_item(title_for_doc(bookmarks[index]), recent.size() + index)
	if popup.item_count == 0:
		popup.add_item("Nothing read yet", -1)
		popup.set_item_disabled(0, true)


func _on_recent_chosen(id: int) -> void:
	if id < 0:
		return
	var recent: Array[String] = EventSheetDocHistory.recent()
	if id < recent.size():
		show_doc(recent[id])
		return
	var bookmarks: Array[String] = EventSheetDocHistory.bookmarks()
	var bookmark_index: int = id - recent.size()
	if bookmark_index < bookmarks.size():
		show_doc(bookmarks[bookmark_index])


func _on_bookmark_pressed() -> void:
	if _current_id.is_empty():
		_bookmark_button.set_pressed_no_signal(false)
		return
	var kept: bool = EventSheetDocHistory.toggle_bookmark(_current_id)
	_bookmark_button.set_pressed_no_signal(kept)
	_bookmark_button.text = "★" if kept else "☆"


## The name a doc id reads under, for a menu row and a crumb. Falls back to the id itself, so a
## menu is never a list of blanks.
func title_for_doc(doc_id: String) -> String:
	var route: Dictionary = EventSheetDocExplain.resolve(doc_id)
	if str(route.get("scheme", "")) == "reference":
		return EventSheetDocReference.title_for(str(route.get("reference_kind", "")),
			str(route.get("reference_name", "")))
	var page_id: String = str(route.get("page_id", ""))
	if not page_id.is_empty() and EventSheetDocLibrary.has_page(page_id):
		return EventSheetDocLibrary.page_title(page_id)
	if str(route.get("scheme", "")) == "ace":
		var definition: ACEDefinition = EventSheets.find_ace(str(route.get("provider_id", "")),
			str(route.get("ace_id", "")))
		if definition != null:
			return EventSheetL10n.translate(definition.display_name)
	return doc_id


## The chrome, re-read off the page on screen. One place, called after every navigation, so the
## trail, the two arrows and the star can never describe a page the reader has left.
func _refresh_chrome() -> void:
	# The chrome is built BEFORE the two halves it describes (it sits above them), so the first
	# call - the one that draws an empty trail - runs while there is no page to ask.
	if _breadcrumb == null or _page == null:
		return
	_breadcrumb.text = " ▸ ".join(Array(EventSheetDocReference.breadcrumb(_current_id, current_title())))
	_breadcrumb.tooltip_text = _breadcrumb.text
	_back_button.disabled = not EventSheetDocHistory.can_go_back()
	_forward_button.disabled = not EventSheetDocHistory.can_go_forward()
	var kept: bool = EventSheetDocHistory.is_bookmarked(_current_id)
	_bookmark_button.set_pressed_no_signal(kept)
	_bookmark_button.text = "★" if kept else "☆"
	_refresh_page_foot()


## The keys a reader reaches for inside a manual: Alt+Left / Alt+Right for the trail, "/" for the
## search box, and Esc to hand the focus back to the sheet.
##
## Taken as UNHANDLED input, which is what makes "/" safe: a reader TYPING a slash into the search
## box (or any other field) has already consumed the key by the time it would reach here, so the
## shortcut can be a bare character without eating anybody's punctuation.
func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed:
		return
	if key.alt_pressed:
		if key.keycode == KEY_LEFT and go_back():
			accept_event()
		elif key.keycode == KEY_RIGHT and go_forward():
			accept_event()
		return
	if key.ctrl_pressed or key.shift_pressed or key.meta_pressed:
		return
	if key.keycode == KEY_SLASH:
		focus_search()
		accept_event()
	elif key.keycode == KEY_ESCAPE:
		focus_returned.emit()
		accept_event()


## Puts the caret in the search box and selects whatever is in it, so the next keystroke replaces
## the last search rather than extending it.
func focus_search() -> void:
	if _search == null:
		return
	_search.grab_focus()
	_search.select_all()


## Holds the prose to a readable measure. The margin is the room the host has BEYOND a comfortable
## line, split evenly, and it is zero for a host that has none.
func _apply_reading_width() -> void:
	if _reading_margin == null or _scroll == null:
		return
	var slack: float = _scroll.size.x - EventSheetPalette.scaled_f(READING_MAX_WIDTH)
	var margin: int = 0 if slack <= 0.0 else int(slack * 0.5)
	_reading_margin.add_theme_constant_override("margin_left", margin)
	_reading_margin.add_theme_constant_override("margin_right", margin)


## The one-click offers a derived page carries. The page names the action; this is the one place
## that name means something.
func _on_page_action(action: String, argument: String) -> void:
	match action:
		EventSheetDocTutorials.ACTION_START, EventSheetDocTutorials.ACTION_BACK, \
		EventSheetDocTutorials.ACTION_SKIP, EventSheetDocTutorials.ACTION_NEXT:
			_on_tutorial_action(action, argument)
			return
		ACTION_TRANSLATIONS:
			# The FOLDER, in the reader's own file manager. There is no web form here and no upload:
			# a translated page is a Markdown file beside the English one, and this shows them where.
			var folder: String = EventSheetDocLocale.translations_dir()
			if not folder.is_empty():
				OS.shell_open(ProjectSettings.globalize_path(folder))
				link_activated.emit(folder)
			return
	if action != "write_guide" or argument.strip_edges().is_empty():
		return
	var written: String = EventSheetAddonGuideScaffold.write_guide_for_pack(argument)
	if written.is_empty():
		return
	# The corpus just gained a page, so both caches that would otherwise still say it is missing
	# are dropped before the page is drawn again - the stub becomes the guide in one click.
	EventSheetDocLibrary.reload()
	EventSheetDocSearch.reload()
	link_activated.emit(written)
	show_doc(_current_id)


## Walking a tutorial: Start opens a scratch sheet and the first card, Back and Next move a step,
## Skip goes back to the list. Every one of them REMEMBERS where the reader got to before it draws,
## so closing the editor mid-tutorial and coming back lands on the same card.
##
## Next is never gated on the step's own check - a reader who did the thing their own way, or who
## simply wants to read ahead, must not be trapped by a check that has not noticed.
func _on_tutorial_action(action: String, tutorial_id: String) -> void:
	var id: String = tutorial_id.strip_edges()
	if id.is_empty():
		return
	if action == EventSheetDocTutorials.ACTION_SKIP:
		show_doc(EventSheetDocTutorials.LIST_DOC_ID)
		return
	var at: int = EventSheetDocTutorials.step_reached(id)
	match action:
		EventSheetDocTutorials.ACTION_START:
			# A tutorial runs on a sheet nobody minds losing. The host opens it; a Manual that could
			# not reach a tab strip still walks the steps on whatever sheet is already open.
			scratch_requested.emit(str(EventSheetDocTutorials.tutorial(id).get("title", "")), null)
		EventSheetDocTutorials.ACTION_BACK:
			at = EventSheetDocTutorials.moved_step(id, at, -1)
		EventSheetDocTutorials.ACTION_NEXT:
			if EventSheetDocTutorials.is_last_step(id, at):
				EventSheetDocTutorials.remember_step(id, at)
				show_doc(EventSheetDocTutorials.LIST_DOC_ID)
				return
			at = EventSheetDocTutorials.moved_step(id, at, 1)
	EventSheetDocTutorials.remember_step(id, at)
	show_doc(EventSheetDocTutorials.doc_id(id))
	_pulse_step_control(id, at)


## Asks the host to make the step's named control pulse. Silent for a step that names none - a step
## the reader only has to read has nothing to point at.
func _pulse_step_control(tutorial_id: String, index: int) -> void:
	var control: String = str(EventSheetDocTutorials.step(tutorial_id, index).get("control", "")).strip_edges()
	if not control.is_empty():
		control_highlight_requested.emit(control)


## The strip under the guide list: the two ways OUT of this surface, as small flat icon buttons -
## the page in a browser at full fidelity, and the repository itself. Icons rather than words
## because the sidebar is a narrow column and its width belongs to the guide names.
func _build_side_footer() -> HBoxContainer:
	var footer: HBoxContainer = HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(2.0)))
	footer.add_child(_icon_button(["ExternalLink", "Link", "Load"], "Open online",
		"Opens the page you are reading in your browser, pinned to the version you installed.",
		_open_current_online))
	footer.add_child(_icon_button(["VcsBranches", "Script", "Object"], "Source",
		"Opens the project's source repository in your browser.",
		func() -> void:
			OS.shell_open(EventSheets.DOCS_REPO_URL)
			link_activated.emit(EventSheets.DOCS_REPO_URL)))
	return footer


## A small flat icon button. `icon_names` are alternatives, best first - editor builds carry
## different icon sets - and a word is used wherever none of them exist (and headless, where there
## is no editor theme at all), so the button always says something.
func _icon_button(icon_names: Array, fallback_text: String, tooltip: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.flat = true
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_NONE
	var icon: Texture2D = _first_icon(icon_names)
	if icon != null:
		button.icon = icon
	else:
		button.text = fallback_text
		button.add_theme_font_size_override("font_size", EventSheetPalette.scaled(10))
	button.pressed.connect(action)
	return button


## The first of `icon_names` this editor carries, or null for none of them.
func _first_icon(icon_names: Array) -> Texture2D:
	for icon_name: Variant in icon_names:
		var icon: Texture2D = _editor_icon(str(icon_name))
		if icon != null:
			return icon
	return null


## The online escape hatch, following the reader: the page on screen when it came from a repo file,
## and the guide index when the surface is showing generated reference instead.
func _open_current_online() -> void:
	var route: Dictionary = EventSheetDocExplain.resolve(_current_id)
	var target: String = str(route.get("target", ""))
	if target.is_empty():
		target = EventSheetDocLibrary.repo_path_for_page(str(route.get("page_id", "")))
	if target.is_empty():
		target = "docs/README.md"
	EventSheets.open_online_doc(target)
	link_activated.emit(target)


## An editor theme icon by name, or null outside the editor and for a name this build lacks.
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


## The icon a page id's KIND wears in the sidebar, or null when this editor carries none of the
## alternatives (and headless, where a row is simply a name).
func _kind_icon(page_id: String) -> Texture2D:
	for icon_name: Variant in KIND_ICONS.get(kind_for_page(page_id), []) as Array:
		var icon: Texture2D = _editor_icon(str(icon_name))
		if icon != null:
			return icon
	return null


## What KIND of thing a page id names, from the id alone. Pure and static, so the suite pins the
## mapping the sidebar icons are derived from rather than the icons themselves (which differ
## between editor builds).
static func kind_for_page(page_id: String) -> String:
	var id: String = page_id.strip_edges()
	if id.begins_with("%s/" % EventSheetDocLibrary.ADDONS_DIR):
		return "addon"
	if id.begins_with("%s/" % EventSheetDocLibrary.MODULES_DIR):
		return "module"
	if id.begins_with("%s/" % EventSheetDocLibrary.PACKS_SET):
		return "pack"
	if id.begins_with("%s/" % EventSheetDocLibrary.PROJECT_SET):
		return "project"
	return "guide"


## Whether a host of this width should fold its sidebar away. Pure, so the breakpoint is pinned as
## a decision rather than inferred from a screenshot.
static func wants_compact(width: float) -> bool:
	return width > 0.0 and width < EventSheetPalette.scaled_f(AUTO_COMPACT_WIDTH)


## Lets the host stop declaring a mode and have it decided from the width it actually gets. The
## dock turns this on: a docked column is narrow by nature, but a floated or widened one is not,
## and a reader who drags the dock wide is asking for the tree back.
func set_auto_compact(enabled: bool) -> void:
	_auto_compact = enabled
	_apply_auto_compact()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_auto_compact()
		_apply_reading_width()


func _apply_auto_compact() -> void:
	if not _auto_compact or size.x <= 0.0:
		return
	set_compact(wants_compact(size.x))


## Compact mode: one half on screen at a time, for a host too narrow to show both (the Help dock).
## The tree folds behind the "Contents" toggle and the width floor drops to what prose needs.
func set_compact(enabled: bool) -> void:
	if _compact == enabled:
		return
	_compact = enabled
	custom_minimum_size = Vector2(
		EventSheetPalette.scaled_f(COMPACT_MIN_WIDTH if enabled else WIDE_MIN_WIDTH), 0.0)
	_contents_button.visible = enabled
	_contents_button.set_pressed_no_signal(false)
	_side.visible = not enabled
	# The generated half has its own comfortable column width, and it is wider than a dock slot. It
	# is invisible while a guide is on screen (so it costs the layout nothing), but the moment the
	# reader asks what a verb does it becomes the widest thing in a host that cannot scroll sideways.
	_panel.set_compact(enabled)


## True while the surface is folded to one half at a time.
func is_compact() -> bool:
	return _compact


func _on_contents_toggled(pressed: bool) -> void:
	_side.visible = pressed


## The guide tree, for a host that wants to focus it.
func tree() -> Tree:
	return _tree


## The generated-reference half, for a caller that already holds an ACEDefinition (the picker's
## seam) and for the preview harness.
func panel() -> EventSheetDocPanel:
	return _panel


## The rendered-guide half.
func page() -> EventSheetDocPageView:
	return _page


## The doc id on screen.
func current_doc_id() -> String:
	return _current_id


## The human name of what is on screen, for a host that titles itself after its content.
func current_title() -> String:
	if _page.visible:
		return _page.current_title()
	return _panel.current_title()


## Opens `doc_id`, choosing the surface that can answer it. Returns false - and changes nothing -
## when the id names nothing real, so a caller reports the miss instead of showing a blank page.
func show_doc(doc_id: String, anchor: String = "") -> bool:
	return _open(doc_id, anchor, true)


## The one navigation. `pushed` is false when the HISTORY drove it (a back, a forward), which is
## the difference between moving through the stacks and adding to them.
##
## Where the reader had got to on the page they are LEAVING is remembered first, before anything
## is drawn: after the navigation the old scroll offset belongs to a page that is no longer there.
func _open(doc_id: String, anchor: String, pushed: bool) -> bool:
	_remember_scroll()
	var opened: bool = _route(doc_id, anchor)
	if opened:
		if pushed:
			# The page that ENDED UP on screen, not the id that was asked for: the index resolves to
			# whichever guide the bundle actually leads with, and a history of "" is a history of
			# nothing anybody can go back to.
			EventSheetDocHistory.visit(_current_id)
		_refresh_chrome()
	return opened


func _route(doc_id: String, anchor: String) -> bool:
	# The engine's own class reference is not this surface's to draw - it is the editor's, and the
	# editor draws it better. A reader who asked for a Godot class gets the Script editor's help.
	if doc_id.strip_edges().begins_with(ENGINE_SCHEME):
		return _open_engine_help(doc_id.strip_edges().substr(ENGINE_SCHEME.length()))
	var route: Dictionary = EventSheetDocExplain.resolve(doc_id)
	if str(route.get("scheme", "")) == "reference":
		return _show_reference(doc_id, str(route.get("reference_kind", "")),
			str(route.get("reference_name", "")), anchor)
	return _show_routed(doc_id, anchor, route)


## A DERIVED page: the reference for a category, a behavior or an object, the glossary, the icon
## legend. Drawn by the page view like any guide, because it is a page - it simply was not written
## by anybody.
func _show_reference(doc_id: String, kind: String, name: String, anchor: String) -> bool:
	var blocks: Array[Dictionary] = EventSheetDocReference.blocks_for(kind, name)
	if blocks.is_empty():
		return false
	if not _query.is_empty():
		blocks = EventSheetDocSearch.highlight_blocks(blocks, _query)
	if not _page.show_blocks(blocks, doc_id):
		return false
	_current_id = doc_id
	_panel.visible = false
	_page.visible = true
	if not _query.is_empty():
		_page.expand_all()
	_build_mini_nav()
	# Opening What's new is what takes the dot off the Manual button. Recorded HERE rather than on
	# the click that opened it, because a reader who got here from a link, from Recent or from a
	# restored layout has read it just as much as one who pressed the tree row.
	if kind == EventSheetDocReference.KIND_WHATS_NEW:
		EventSheetDocWhatsNew.mark_seen(EventSheets.docs_version())
	if kind == EventSheetDocReference.KIND_TUTORIAL:
		_pulse_step_control(name, EventSheetDocTutorials.step_reached(name))
	_mark_active_item(_items_by_id.get(doc_id, null) as TreeItem)
	# A glossary term is a chapter of the glossary page, so "reference:glossary/pick" lands ON pick.
	var wanted: String = anchor.strip_edges()
	if wanted.is_empty() and kind in [EventSheetDocReference.KIND_GLOSSARY,
			EventSheetDocReference.KIND_BEHAVIOR_INDEX]:
		wanted = name.strip_edges()
	if not wanted.is_empty():
		_page.jump_to_anchor(wanted)
	else:
		_restore_scroll(doc_id)
	return true


## The editor's own class reference, one hop out of the Manual. Reported honestly: a build whose
## script editor cannot be asked answers false rather than pretending it opened something.
func _open_engine_help(class_id: String) -> bool:
	var wanted: String = class_id.strip_edges()
	if wanted.is_empty() or not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return false
	var editor_interface: Object = Engine.get_singleton("EditorInterface")
	if editor_interface == null or not editor_interface.has_method("get_script_editor"):
		return false
	var script_editor: Object = editor_interface.get_script_editor()
	if script_editor == null or not script_editor.has_method("goto_help"):
		return false
	script_editor.call("goto_help", "class_name:%s" % wanted)
	link_activated.emit(wanted)
	return true


func _show_routed(doc_id: String, anchor: String, route: Dictionary) -> bool:
	if not bool(route.get("valid", false)):
		return false
	var page_id: String = str(route.get("page_id", ""))
	if not page_id.is_empty() and EventSheetDocLibrary.has_page(page_id):
		return _show_page(page_id, anchor, doc_id)
	var target: String = str(route.get("target", ""))
	if not target.is_empty():
		# A guide that did not ship inside the plugin (a third-party pack hosting its docs
		# elsewhere) still answers - in the browser, at full fidelity.
		EventSheets.open_online_doc(target, anchor)
		link_activated.emit(target)
		return true
	if str(route.get("scheme", "")) == "index":
		return _show_home()
	return _show_generated(doc_id)


func _show_page(page_id: String, anchor: String, doc_id: String) -> bool:
	if not _page.show_blocks(_blocks_for(page_id), page_id):
		return false
	_current_id = doc_id
	_panel.visible = false
	_page.visible = true
	# A search term outranks the fold: a hit inside a chapter the reader cannot see reads as a
	# search that missed, so a live query opens the whole page.
	if not _query.is_empty():
		_page.expand_all()
	_build_mini_nav()
	_select_tree_item(page_id)
	if not anchor.strip_edges().is_empty():
		_page.jump_to_anchor(anchor)
	else:
		_restore_scroll(doc_id)
	return true


## Where the reader had got to on the page they are leaving. Called BEFORE every navigation, so
## coming back to a long guide lands in the paragraph they left rather than at its title.
func _remember_scroll() -> void:
	if _scroll == null or _current_id.is_empty() or not _page.visible:
		return
	EventSheetDocHistory.remember_scroll(_current_id, float(_scroll.scroll_vertical))


## Puts a page back where the reader left it. Deferred by a frame for the same reason an anchor
## jump is: a freshly built page has no layout yet, so its scroll range is still zero and an
## immediate offset silently lands at the top.
func _restore_scroll(doc_id: String) -> void:
	if _scroll == null:
		return
	_scroll.scroll_vertical = 0
	var offset: float = EventSheetDocHistory.scroll_for(doc_id)
	if offset <= 0.0:
		return
	_apply_scroll.call_deferred(int(offset))


func _apply_scroll(offset: int) -> void:
	if _scroll != null:
		_scroll.scroll_vertical = offset


func _show_generated(doc_id: String) -> bool:
	if not _panel.show_doc(doc_id):
		return false
	_current_id = doc_id
	_page.visible = false
	_panel.visible = true
	_clear_mini_nav()
	_mark_active_item(null)
	return true


## The sticky chapter strip: one small-caps button per H2, shown only for a page long enough to
## fold (a short page's own headings are already on screen, and a nav that repeated them would be
## chrome answering a question nobody asked).
func _build_mini_nav() -> void:
	_clear_mini_nav()
	if not _page.is_folding():
		return
	for entry: Dictionary in _page.outline():
		var slug: String = str(entry.get("slug", ""))
		if slug.is_empty():
			continue
		var button: Button = Button.new()
		button.flat = true
		button.text = str(entry.get("text", "")).to_upper()
		button.tooltip_text = "Jump to \"%s\"." % str(entry.get("text", ""))
		button.add_theme_font_size_override("font_size", EventSheetPalette.scaled(10))
		button.pressed.connect(func() -> void:
			_page.set_section_expanded(slug, true)
			_page.jump_to_anchor(slug))
		_mini_nav.add_child(button)
		_nav_buttons[slug] = button
	_mini_nav_strip.visible = _mini_nav.get_child_count() > 0
	_refresh_nav_highlight()


func _clear_mini_nav() -> void:
	_nav_buttons.clear()
	_nav_current = ""
	if _mini_nav == null:
		return
	_mini_nav_strip.visible = false
	for child: Node in _mini_nav.get_children():
		_mini_nav.remove_child(child)
		child.queue_free()


## The chapter the reader is in wears the accent; the rest stay muted. Driven by the scroll rather
## than by clicks, so scrolling past a heading updates it exactly as clicking one does.
func _on_page_scrolled(value: float) -> void:
	if _mini_nav_strip == null or not _mini_nav_strip.visible or not _page.visible:
		return
	_highlight_nav(_page.section_at(value))


## Re-takes the bearing from wherever the page currently is. Called on the page's own layout as
## well as on a scroll, because the strip is filled while the page is still positionless and the
## answer it gets then is "nothing to highlight yet" - true at that instant, and stale a frame later.
func _refresh_nav_highlight() -> void:
	if _mini_nav_strip == null or not _mini_nav_strip.visible or _page == null or not _page.visible:
		return
	var offset: float = float(_scroll.scroll_vertical) if _scroll != null else 0.0
	_highlight_nav(_page.section_at(offset))


func _highlight_nav(slug: String) -> void:
	_nav_current = slug
	var accent: Color = EventSheetPopupUI.accent_color()
	var muted: Color = EventSheetActiveTheme.manual().resolve_muted(Color(0.86, 0.88, 0.92, 0.62))
	for key: Variant in _nav_buttons:
		var button: Button = _nav_buttons[key] as Button
		if button == null:
			continue
		button.add_theme_color_override("font_color", accent if str(key) == slug else muted)
		button.add_theme_color_override("font_hover_color", accent)


## The landing page: the shipped documentation index when there is one, and the guidance line the
## generated panel already carries when no bundle is installed.
func _show_home() -> bool:
	for id: String in HOME_IDS:
		if EventSheetDocLibrary.has_page(id):
			return _show_page(id, "", "guide:%s" % id)
	return _show_generated("")


## A page, ready to draw: parsed, with a pack guide's ACE reference swapped for the live one, and
## with the search term wrapped where it appears. Both passes are pure functions over the block
## list, so the parser stays a parser and neither pass can leak into the next page.
func _blocks_for(page_id: String) -> Array[Dictionary]:
	# The reader's own language first, page by page: their locale's copy when it ships, and the
	# English page with a one-line note when it does not. The note goes just under the title, for
	# the same reason the missing-guide stub does - a reader deciding whether to trust what they are
	# reading is deciding it now, not after nine screens.
	var locale: String = EventSheetDocLocale.locale()
	var shown: String = EventSheetDocLocale.page_for(page_id, locale, EventSheetDocLibrary.page_ids())
	var blocks: Array[Dictionary] = EventSheetDocAceReference.replace_section(
		EventSheetDocLibrary.page_blocks(shown), page_id)
	var note: Dictionary = EventSheetDocLocale.note_block(shown, locale)
	if not note.is_empty():
		var at: int = mini(1, blocks.size())
		blocks.insert(at, note)
		blocks.insert(at + 1, {"kind": "button", "label": EventSheetDocLocale.note_text(),
			"tooltip": EventSheetDocLocale.note_tooltip(locale),
			"action": ACTION_TRANSLATIONS, "argument": locale})
	if not _query.is_empty():
		blocks = EventSheetDocSearch.highlight_blocks(blocks, _query)
	# Where the reading continues. Only inside a group that HAS a next page, so the last guide of a
	# part ends rather than pointing at nothing.
	var next_page: Dictionary = EventSheetDocReference.next_page_after(page_id)
	if not next_page.is_empty():
		blocks.append({"kind": "next", "title": str(next_page.get("title", "")),
			"doc_id": str(next_page.get("doc_id", ""))})
	return blocks


## Typing in the search box swaps the tree for ranked results, and clearing it puts the guide tree
## back. The page on screen is left alone: a reader mid-sentence should not have the page they are
## reading yanked away by a keystroke in a box beside it.
func _on_search_changed(text: String) -> void:
	_query = text.strip_edges()
	if _query.is_empty():
		_side.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(SIDEBAR_MIN_WIDTH), 0.0)
		_build_tree()
		_select_tree_item(str(EventSheetDocExplain.resolve(_current_id).get("page_id", "")))
		_fold_contents()
		return
	_build_results(_query)
	# A result row is a sentence - the kind, the name, and how much this sheet uses it - so the
	# column that holds it is widened while results are on screen and given back to the guide names
	# the moment the box is cleared.
	_side.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(RESULTS_MIN_WIDTH), 0.0)
	# Results the reader cannot see are not results: in compact mode a keystroke reveals the list
	# it just filled, and picking a hit folds it away again.
	if _compact:
		_contents_button.set_pressed_no_signal(true)
		_side.visible = true


## Searches from a host (the window's own field, a palette hand-off). Runs the same path a
## keystroke does, so there is one search behaviour rather than two.
func search(query: String) -> void:
	if _search != null:
		_search.text = query
	_on_search_changed(query)


## The ranked results - ONE box over the whole Manual, not over the guides alone. A hit can be a
## condition, an action, an expression, a guide, a page of the System or behavior reference, a
## Godot class or a word from another editor's vocabulary, and each row is TAGGED with which,
## in the Manual's own words.
##
## A verb hit also says how many events of the open sheet already use it, because that is the
## question a reader is really asking when they search for one they half remember.
##
## Enter opens the row. Ctrl+Enter ADDS it - see _add_selected_result.
func _build_results(query: String) -> void:
	_items_by_id.clear()
	_result_definitions.clear()
	# Every row is about to be freed, so the remembered active one must go with them.
	_active_item = null
	_tree.clear()
	var root: TreeItem = _tree.create_item()
	var results: Array[Dictionary] = EventSheetDocSearch.search_all(query, EventSheets.current_sheet())
	# ABOVE everything, including an empty list. A reader who typed a word from another editor is
	# not looking for the rows that happen to mention it - they are asking what it is called here,
	# and that answer is worth more than every hit under it.
	_add_glossary_redirect(root, query)
	for result: Dictionary in results:
		var item: TreeItem = _tree.create_item(root)
		item.set_text(0, result_row_text(result))
		item.set_tooltip_text(0, result_tooltip(result))
		item.set_metadata(0, {"doc_id": str(result.get("doc_id", "")),
			"anchor": str(result.get("anchor", ""))})
		var definition: ACEDefinition = result.get("definition", null) as ACEDefinition
		if definition != null:
			_result_definitions[item] = definition
	if results.is_empty():
		var empty: TreeItem = _tree.create_item(root)
		empty.set_text(0, "Nothing in the Manual mentions that")
		empty.set_selectable(0, false)


## "Looking for layout? Here it is called Scene" - the first row of the results, never instead of
## them.
##
## A search for a word from another editor has two bad endings, and this line prevents both: an
## empty list, which reads as "this editor cannot do that", and a list of rows that merely mention
## the word, which buries the one thing the reader was actually asking. The glossary already knows
## which words are renames, so it says so at the top. Two rows: the page for the word this editor
## uses, and the glossary itself.
func _add_glossary_redirect(root: TreeItem, query: String) -> void:
	var redirect: Dictionary = EventSheetDocGlossary.redirect_for(query)
	if redirect.is_empty():
		return
	var term_id: String = EventSheetDocReference.doc_id(EventSheetDocReference.KIND_GLOSSARY,
		str(redirect.get("key", "")))
	var hint: TreeItem = _tree.create_item(root)
	hint.set_text(0, str(redirect.get("line", "")))
	hint.set_tooltip_text(0, "Opens the page for the word this editor uses.")
	hint.set_custom_color(0, EventSheetPopupUI.accent_color())
	hint.set_metadata(0, {"doc_id": term_id, "anchor": str(redirect.get("key", ""))})
	var glossary: TreeItem = _tree.create_item(root)
	glossary.set_text(0, EventSheetDocGlossary.PAGE_TITLE)
	glossary.set_tooltip_text(0, "Every word that is spelled differently here.")
	glossary.set_metadata(0, {"doc_id": EventSheetDocReference.doc_id(
		EventSheetDocReference.KIND_GLOSSARY, ""), "anchor": ""})


## One result row, as the reader reads it: the kind it is, then what it is called, then where it
## lives and how much this sheet already uses it. Pure and static, so the suite pins the sentence
## rather than a screenshot of it.
static func result_row_text(result: Dictionary) -> String:
	var kind: String = EventSheetDocSearch.kind_label(str(result.get("kind", "")))
	var title: String = str(result.get("title", ""))
	var line: String = title if kind.is_empty() else "%s  ·  %s" % [kind, title]
	var used: int = int(result.get("used", 0))
	if used > 0:
		line += "  ·  used %d× in this sheet" % used
	return line


## The rest of the row, on hover: where it sits in the Manual.
static func result_tooltip(result: Dictionary) -> String:
	var subtitle: String = str(result.get("subtitle", "")).strip_edges()
	var title: String = str(result.get("title", ""))
	return title if subtitle.is_empty() else "%s\n%s" % [title, subtitle]


## The tree, derived from the bundle's own grouping (which is itself derived from the docs index).
## An empty bundle leaves the tree empty rather than inventing rows for pages that do not ship.
func _build_tree() -> void:
	_items_by_id.clear()
	# Every row is about to be freed, so the remembered active one must go with them.
	_active_item = null
	_tree.clear()
	var root: TreeItem = _tree.create_item()
	_build_manual_group(root)
	for group: Dictionary in EventSheetDocLibrary.groups():
		var section: TreeItem = _tree.create_item(root)
		_style_group_row(section, str(group.get("title", "")))
		var ids: PackedStringArray = group.get("ids", PackedStringArray())
		for id: String in ids:
			var item: TreeItem = _tree.create_item(section)
			var title: String = EventSheetDocLibrary.page_title(id)
			item.set_text(0, title)
			# The tree is narrow and these titles are sentences, so the full title lives on hover -
			# otherwise half the corpus reads as "Working with Value...".
			item.set_tooltip_text(0, title)
			item.set_metadata(0, id)
			_style_page_row(item, id)
			_items_by_id[id] = item
		section.collapsed = _items_by_id.size() > 12
	_build_reference_tree(root)


## The Manual's own first pages: the tutorials you do, what the marks on a sheet mean, the words
## another event-sheet editor spells differently, and what changed in this build. All four are
## generated, and they go FIRST - they are what a reader who has never opened this before needs
## before any guide.
func _build_manual_group(root: TreeItem) -> void:
	var manual: TreeItem = _tree.create_item(root)
	_style_group_row(manual, EventSheetDocReference.MANUAL_TITLE)
	# The tutorials lead, because doing one answers every question the pages below would be
	# answering in prose. Then the legend - what are those marks on my rows - then the words from
	# another editor, then the behaviors by the names they are known by, then what changed.
	for kind: String in [EventSheetDocReference.KIND_TUTORIALS, EventSheetDocReference.KIND_LEGEND,
			EventSheetDocReference.KIND_GLOSSARY, EventSheetDocReference.KIND_DICTIONARY,
			# W21 - the editor-building words, beside the other two word pages: it answers the same
			# question ("what do you call this?") for the reader who is building a tool.
			EventSheetDocReference.KIND_EDITOR_WORDS,
			# The patterns index sits beside the behaviors index because the two answer the same
			# question from opposite ends: what shape is this event, and what could take it over.
			# It had a Tools menu entry and no row here, which made it the one derived page a
			# reader browsing the Manual could not find.
			EventSheetDocReference.KIND_PATTERNS,
			EventSheetDocReference.KIND_BEHAVIOR_INDEX,
			EventSheetDocReference.KIND_WHATS_NEW]:
		_add_reference_row(manual, kind, "")


## The reference half of the tree, which sits at the FOOT of it: a reader opening the Manual is
## looking for a guide far more often than for the whole vocabulary laid out.
func _build_reference_tree(root: TreeItem) -> void:
	var sections: PackedStringArray = EventSheetDocReference.section_names()
	if not sections.is_empty():
		var branch: TreeItem = _tree.create_item(root)
		_style_group_row(branch, EventSheetDocReference.SECTION_TREE_TITLE)
		branch.collapsed = true
		for section: String in sections:
			_add_reference_row(branch, EventSheetDocReference.KIND_SECTION, section)
	var packs: PackedStringArray = EventSheetDocReference.pack_names()
	if not packs.is_empty():
		var branch: TreeItem = _tree.create_item(root)
		_style_group_row(branch, EventSheetDocReference.PACK_TREE_TITLE)
		branch.collapsed = true
		for pack_dir: String in packs:
			_add_reference_row(branch, EventSheetDocReference.KIND_PACK, pack_dir)


## One derived-page row. Its metadata is the same {doc_id, anchor} pair a search result carries, so
## the tree has one kind of row to activate rather than two.
func _add_reference_row(parent: TreeItem, kind: String, name: String) -> void:
	var doc_id: String = EventSheetDocReference.doc_id(kind, name)
	var title: String = EventSheetDocReference.title_for(kind, name)
	if doc_id.is_empty() or title.is_empty():
		return
	var item: TreeItem = _tree.create_item(parent)
	item.set_text(0, title)
	item.set_tooltip_text(0, title)
	item.set_metadata(0, {"doc_id": doc_id, "anchor": ""})
	_items_by_id[doc_id] = item


## A GROUP row: the small-caps label the whole surface names its sections with, and not selectable -
## a group is a heading, not a destination.
##
## MUTED, never accent. There is exactly one accent thing in this column - the filled pill on the
## page being read - and a heading in the same colour competes with it for the eye that is looking
## for "where am I". The letter spacing comes from the shared small-caps font rather than from a
## second recipe here, so a group row and a section label are the same typography.
func _style_group_row(item: TreeItem, title: String) -> void:
	item.set_text(0, group_label(title))
	item.set_selectable(0, false)
	item.set_custom_font_size(0, EventSheetPalette.scaled(EventSheetPopupUI.SMALL_CAPS_FONT_SIZE))
	item.set_custom_color(0, EventSheetActiveTheme.manual().resolve_muted(EventSheetPalette.TEXT_MUTED))
	var tracked: FontVariation = EventSheetPopupUI.small_caps_font(_tree.get_theme_font("font"))
	if tracked != null:
		item.set_custom_font(0, tracked)


## A PAGE row: its kind icon, kept small so a row stays a line of text with a mark in front of it
## rather than a button.
func _style_page_row(item: TreeItem, page_id: String) -> void:
	var icon: Texture2D = _kind_icon(page_id)
	if icon == null:
		return
	item.set_icon(0, icon)
	item.set_icon_max_width(0, int(EventSheetPalette.scaled_f(14.0)))


## A group title as the sidebar draws it. Pure, so the suite pins the label rather than the pixels.
static func group_label(title: String) -> String:
	return title.strip_edges().to_upper()


## The page on screen wears a filled accent pill, and the row that wore it last gives it back. The
## tree's own selection highlight is not enough on its own: a search, a link inside a page or a
## restored dock all change the page WITHOUT the reader clicking a row.
func _mark_active_item(item: TreeItem) -> void:
	if _active_item != null and is_instance_valid(_active_item) and _active_item != item:
		_active_item.clear_custom_bg_color(0)
		_active_item.clear_custom_color(0)
	_active_item = item
	if item == null:
		return
	var accent: Color = EventSheetPopupUI.accent_color()
	item.set_custom_bg_color(0, EventSheetActiveTheme.manual().resolve_contents_active_background(accent), false)
	# On a filled accent the row's own font colour can vanish. The editor's accent is a mid-to-light
	# blue in both themes, so near-black reads on it either way.
	item.set_custom_color(0, EventSheetActiveTheme.manual().resolve_contents_active_text(Color(0.08, 0.09, 0.11)))


func _select_tree_item(page_id: String) -> void:
	var item: TreeItem = _items_by_id.get(page_id, null) as TreeItem
	_mark_active_item(item)
	if item == null:
		return
	var parent: TreeItem = item.get_parent()
	if parent != null:
		parent.collapsed = false
	# Selecting fires item_selected, which would re-open the page we are already on. Harmless in
	# effect but it resets the scroll, so the tree is driven without the round trip.
	_tree.set_block_signals(true)
	item.select(0)
	_tree.scroll_to_item(item)
	_tree.set_block_signals(false)


## A tree row carries either a page id (the guide tree) or a {doc_id, anchor} pair (a search
## result). Both are metadata on the same tree, so the reader clicks one kind of row either way.
func _on_tree_selected() -> void:
	var item: TreeItem = _tree.get_selected()
	if item == null:
		return
	var metadata: Variant = item.get_metadata(0)
	if metadata == null:
		return
	if metadata is Dictionary:
		var result: Dictionary = metadata as Dictionary
		show_doc(str(result.get("doc_id", "")), str(result.get("anchor", "")))
		_fold_contents()
		return
	var id: String = str(metadata)
	if not id.is_empty():
		show_doc("guide:%s" % id)
		_fold_contents()


## Ctrl+Enter in the search box adds the highlighted verb to the open sheet instead of opening its
## page - the gesture that turns looking something up into using it. Plain Enter opens, which is
## what the list already does.
func _on_search_gui_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or not key.ctrl_pressed:
		return
	if key.keycode != KEY_ENTER and key.keycode != KEY_KP_ENTER:
		return
	if _add_selected_result():
		accept_event()


## Adds the verb the highlighted result names, at the caret, as one undo step. False when the row
## is not a verb (a guide has nothing to add) or there is no sheet open, so the caller can leave
## the key to whoever wants it next.
func _add_selected_result() -> bool:
	var item: TreeItem = _tree.get_selected()
	if item == null and _tree.get_root() != null:
		# Nothing highlighted yet: the reader typed and pressed the key, so the best hit is what
		# they meant - the same row Enter would have opened.
		item = _tree.get_root().get_first_child()
	var definition: ACEDefinition = _result_definitions.get(item, null) as ACEDefinition
	if definition == null:
		return false
	if not EventSheetDocFigure.insert_definition(definition, "Add From The Manual"):
		return false
	snippet_inserted.emit()
	return true


## In compact mode the reader picked a page, so the list has done its job: fold it away and give
## the whole column back to the prose. A wide host never folds - both halves fit at once there.
func _fold_contents() -> void:
	if not _compact:
		return
	_contents_button.set_pressed_no_signal(false)
	_side.visible = false
