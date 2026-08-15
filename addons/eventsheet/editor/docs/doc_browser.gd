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
# It is a plain Control on purpose: the Documentation window parents it, the Help DOCK parents the
# same control in a column a third as wide, and neither host is named here. It owns no window, no
# shortcut and no menu.
#
# COMPACT mode is what makes the dock viable: a side-by-side tree and page need about 560 px, and a
# dock slot is nowhere near that. Compact keeps the same two halves and simply stops showing them at
# once - the tree becomes a "Contents" toggle that folds away again the moment the reader picks a
# page, so the whole width belongs to the prose while reading.
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

## Emitted when the browser opened something in the reader's browser instead of drawing it, so a
## host can say so in its status line.
signal link_activated(target: String)

## Emitted after a figure's Insert lands rows in the sheet.
signal snippet_inserted()

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
## The live search term. It drives BOTH halves of a search - which pages the tree offers, and
## whether the page on screen is drawn with its hits wrapped - so navigating from a result keeps
## the highlight the reader searched for.
var _query: String = ""


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
	_contents_button.tooltip_text = "Show the list of guides."
	_contents_button.toggle_mode = true
	_contents_button.visible = false
	_contents_button.toggled.connect(_on_contents_toggled)
	header.add_child(_contents_button)
	_search = LineEdit.new()
	_search.placeholder_text = "Search the guides…"
	_search.clear_button_enabled = true
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(_on_search_changed)
	header.add_child(_search)
	add_child(header)

	_split = HSplitContainer.new()
	_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_split)
	_side = VBoxContainer.new()
	_side.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(210.0), 0.0)
	_tree = Tree.new()
	_tree.hide_root = true
	_tree.allow_reselect = true
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.item_selected.connect(_on_tree_selected)
	_side.add_child(_tree)
	_split.add_child(_side)

	_page = EventSheetDocPageView.new()
	_page.doc_requested.connect(func(doc_id: String, anchor: String) -> void: show_doc(doc_id, anchor))
	_page.link_activated.connect(func(target: String) -> void: link_activated.emit(target))
	_page.snippet_inserted.connect(func() -> void: snippet_inserted.emit())
	_panel = EventSheetDocPanel.new()
	_panel.link_activated.connect(func(target: String) -> void: link_activated.emit(target))
	_panel.snippet_inserted.connect(func() -> void: snippet_inserted.emit())
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
	_scroll.add_child(column)
	_page.set_scroll_container(_scroll)
	_split.add_child(_scroll)
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
	var route: Dictionary = EventSheetDocExplain.resolve(doc_id)
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
	_select_tree_item(page_id)
	if not anchor.strip_edges().is_empty():
		_page.jump_to_anchor(anchor)
	elif _scroll != null:
		_scroll.scroll_vertical = 0
	return true


func _show_generated(doc_id: String) -> bool:
	if not _panel.show_doc(doc_id):
		return false
	_current_id = doc_id
	_page.visible = false
	_panel.visible = true
	return true


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
	var blocks: Array[Dictionary] = EventSheetDocAceReference.replace_section(
		EventSheetDocLibrary.page_blocks(page_id), page_id)
	if not _query.is_empty():
		blocks = EventSheetDocSearch.highlight_blocks(blocks, _query)
	return blocks


## Typing in the search box swaps the tree for ranked results, and clearing it puts the guide tree
## back. The page on screen is left alone: a reader mid-sentence should not have the page they are
## reading yanked away by a keystroke in a box beside it.
func _on_search_changed(text: String) -> void:
	_query = text.strip_edges()
	if _query.is_empty():
		_build_tree()
		_select_tree_item(str(EventSheetDocExplain.resolve(_current_id).get("page_id", "")))
		_fold_contents()
		return
	_build_results(_query)
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


## The ranked results, grouped by page: one branch per page, one row per heading that matched.
## Activating a row opens that page AT that heading, with the term still highlighted.
func _build_results(query: String) -> void:
	_items_by_id.clear()
	_tree.clear()
	var root: TreeItem = _tree.create_item()
	var branches: Dictionary = {}
	var results: Array[Dictionary] = EventSheetDocSearch.search(query)
	for result: Dictionary in results:
		var page_id: String = str(result.get("page_id", ""))
		var branch: TreeItem = branches.get(page_id, null) as TreeItem
		if branch == null:
			branch = _tree.create_item(root)
			branch.set_text(0, str(result.get("title", page_id)))
			branch.set_tooltip_text(0, str(result.get("title", page_id)))
			branch.set_metadata(0, {"doc_id": str(result.get("doc_id", "")), "anchor": ""})
			branches[page_id] = branch
			_items_by_id[page_id] = branch
		var heading: String = str(result.get("heading", ""))
		if heading.is_empty():
			continue
		var item: TreeItem = _tree.create_item(branch)
		item.set_text(0, heading)
		item.set_tooltip_text(0, heading)
		item.set_metadata(0, {"doc_id": str(result.get("doc_id", "")), "anchor": str(result.get("anchor", ""))})
	if results.is_empty():
		var empty: TreeItem = _tree.create_item(root)
		empty.set_text(0, "No guide mentions that")
		empty.set_selectable(0, false)


## The tree, derived from the bundle's own grouping (which is itself derived from the docs index).
## An empty bundle leaves the tree empty rather than inventing rows for pages that do not ship.
func _build_tree() -> void:
	_items_by_id.clear()
	_tree.clear()
	var root: TreeItem = _tree.create_item()
	for group: Dictionary in EventSheetDocLibrary.groups():
		var section: TreeItem = _tree.create_item(root)
		section.set_text(0, str(group.get("title", "")))
		section.set_selectable(0, false)
		var ids: PackedStringArray = group.get("ids", PackedStringArray())
		for id: String in ids:
			var item: TreeItem = _tree.create_item(section)
			var title: String = EventSheetDocLibrary.page_title(id)
			item.set_text(0, title)
			# The tree is narrow and these titles are sentences, so the full title lives on hover -
			# otherwise half the corpus reads as "Working with Value...".
			item.set_tooltip_text(0, title)
			item.set_metadata(0, id)
			_items_by_id[id] = item
		section.collapsed = _items_by_id.size() > 12


func _select_tree_item(page_id: String) -> void:
	var item: TreeItem = _items_by_id.get(page_id, null) as TreeItem
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


## In compact mode the reader picked a page, so the list has done its job: fold it away and give
## the whole column back to the prose. A wide host never folds - both halves fit at once there.
func _fold_contents() -> void:
	if not _compact:
		return
	_contents_button.set_pressed_no_signal(false)
	_side.visible = false
