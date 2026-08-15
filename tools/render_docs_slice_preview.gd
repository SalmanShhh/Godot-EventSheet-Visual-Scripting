# EventForge - render harness (dev tool) for the documentation FIGURE slice. Produces two PNGs:
#
#   docs/images/doc-figure.png            a bare EventSheetDocFigure - caption, live rows, buttons
#   docs/images/ace-picker-figure.png     the ACE picker's info panel (description + guide link; no figure)
#   docs/images/doc-explain-panel.png     the generated "what does this row do?" page
#   docs/images/doc-guide-page.png        a shipped guide, rendered natively, at a NARROW width
#   docs/images/doc-guide-anchor.png      the same page after an in-page anchor jump
#   docs/images/doc-guide-figure.png      a guide whose worked examples are LIVE, insertable rows
#   docs/images/doc-dock-beside-sheet.png the reading surface in a dock-width column beside a sheet
#
# The last two are the Phase 3 proof, and the width is the point of them: a stack of autowrapping
# fit_content RichTextLabels inside a scrolling column is exactly the configuration that either
# collapses to zero-height rows or balloons its host, and neither failure is reachable headlessly.
# The anchor jump is the other unreachable one - Control positions are all zero until layout has
# run, so the suite can pin the slug and the registration but never the scroll.
#
# It also prints the one PERFORMANCE number no headless run can reach: the per-frame cost of a page
# with N live figures on screen, beside the same measurement on a page of pure prose. Construction
# cost was measured headlessly and is linear; DRAW cost needs a laid-out, painting tree.
#
# The second image is the one that settles the picker's panel-height question: the description
# panel keeps its 110 px minimum and the figure lives in its own row below it, so a long
# description is never squeezed into a scrollbox to make room for an illustration.
#
# Run NON-headless (headless cannot render):
#   godot --path . --script tools/render_docs_slice_preview.gd
@tool
extends SceneTree

## The guide the Phase 3 images are taken of: short enough to read in one screenshot, and carrying
## every block kind the parser produces (headings, prose, lists, a table, code cards).
const GUIDE_PAGE_ID := "GUIDE-BLOCK-STYLES"

## The Phase 5 images: a search term that hits several guides in several ways, and a pack guide
## whose ACE reference is drawn from the vocabulary rather than from its Markdown.
const SEARCH_QUERY := "variable"
const PACK_DOC_ID := "addon:quest"

## The Phase 6 image: what a DOCK_SLOT_RIGHT_UL column is, before the reader drags it wider.
const DOCK_WIDTH := 360.0

## How many frames a timing sample runs for. Long enough that one slow frame cannot decide the
## answer, short enough that the harness still finishes in seconds.
const SAMPLE_FRAMES := 40

var _frames: int = 0
var _editor: EventSheetEditor = null
var _stage: int = 0
var _browser: EventSheetDocBrowser = null
var _sampling: String = ""
var _samples: Array[float] = []
var _process_samples: Array[float] = []
var _last_frame_usec: int = 0


func _make_event(trigger_id: String, message: String) -> EventRow:
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = trigger_id
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "Print"
	action.codegen_template = "print({message})"
	action.params = {"message": message}
	row.actions.append(action)
	return row


func _demo_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.events.append(_make_event("OnReady", "\"game started\""))
	sheet.events.append(_make_event("OnProcess", "\"score ticks\""))
	return sheet


func _init() -> void:
	root.title = "Docs figure slice"
	root.size = Vector2i(1100, 1000)
	root.gui_embed_subwindows = true
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#2b2b2b")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	_sample_frame()
	if _stage == 0 and _frames == 2:
		var margin: MarginContainer = EventSheetPopupUI.margined(_build_bare_figure())
		# An explicit width: a figure is content-sized, so a host that hugs its child's minimum
		# in BOTH axes gives it nothing to fit inside and the rows wrap to a sliver.
		margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
		margin.position = Vector2.ZERO
		margin.size = Vector2(900.0, 400.0)
		root.add_child(margin)
		_stage = 1
		return
	if _stage == 1 and _frames == 10:
		var image: Image = root.get_texture().get_image()
		image.save_png("res://docs/images/doc-figure.png")
		print("[preview] bare figure %dx%d" % [image.get_width(), image.get_height()])
		for child in root.get_children():
			if child is MarginContainer:
				child.queue_free()
		_stage = 2
		return
	if _stage == 2 and _frames == 14:
		# The picker is a tall dialog; give it room before it opens, or the info panel and its
		# figure - the whole point of this image - sit below the window's bottom edge.
		root.size = Vector2i(1010, 1010)
		_editor = EventSheetEditor.new()
		root.add_child(_editor)
		_editor.setup(_demo_sheet())
		_stage = 3
		return
	if _stage == 3 and _frames == 20:
		var picker: ACEPickerDialog = _editor._ace_picker
		picker.open("new_event", false, null)
		_shrink_dialog_body(picker)
		_stage = 4
		return
	if _stage == 4 and _frames == 26:
		_search_and_select(_editor._ace_picker, "Print")
		_stage = 5
		return
	if _stage == 5 and _frames == 34:
		# Resized LAST: the dialog re-runs its own layout after the popup and after the tree is
		# refilled, and either pass undoes an earlier resize.
		_editor._ace_picker._window.size = Vector2i(940, 700)
		_editor._ace_picker._window.position = Vector2i(20, 12)
		_stage = 6
		return
	if _stage == 6 and _frames == 44:
		var image: Image = root.get_texture().get_image()
		image.save_png("res://docs/images/ace-picker-figure.png")
		print("[preview] picker figure %dx%d" % [image.get_width(), image.get_height()])
		_report_geometry()
		_editor.queue_free()
		_editor = null
		_stage = 7
		return
	if _stage == 7 and _frames == 50:
		root.size = Vector2i(760, 900)
		root.add_child(_build_explain_page())
		_stage = 8
		return
	if _stage == 8 and _frames == 60:
		var image: Image = root.get_texture().get_image()
		image.save_png("res://docs/images/doc-explain-panel.png")
		print("[preview] explain panel %dx%d" % [image.get_width(), image.get_height()])
		for child in root.get_children():
			if child is MarginContainer:
				child.queue_free()
		_stage = 9
		return
	if _stage == 9 and _frames == 66:
		# NARROW on purpose: the sizing trap only shows at a width where the prose has to wrap.
		root.size = Vector2i(720, 900)
		root.add_child(_build_guide_page())
		_stage = 10
		return
	if _stage == 10 and _frames == 78:
		var image: Image = root.get_texture().get_image()
		image.save_png("res://docs/images/doc-guide-page.png")
		print("[preview] guide page %dx%d" % [image.get_width(), image.get_height()])
		_report_page_geometry()
		_stage = 11
		return
	if _stage == 11 and _frames == 82:
		_jump_to_first_anchor()
		_stage = 12
		return
	if _stage == 12 and _frames == 90:
		# Read AFTER the jump's deferred frame: positions are only valid once layout has run, so
		# the scroll it sets lands one frame after the call, never inside it.
		print("[preview] scroll after the jump settled: %d" % _browser._scroll.scroll_vertical)
		var image: Image = root.get_texture().get_image()
		image.save_png("res://docs/images/doc-guide-anchor.png")
		print("[preview] guide page after the anchor jump %dx%d" % [image.get_width(), image.get_height()])
		_stage = 13
		return
	if _stage == 13 and _frames == 94:
		# Phase 5, half one: the same browser, searched. The tree becomes ranked results grouped by
		# page, and the page redraws with every hit wrapped - neither of which the suite can see.
		# Wider than the Phase 3 shots, because what these images have to show is the page BESIDE
		# the results rather than how narrow prose wraps.
		_widen(1000, 900)
		_browser.search(SEARCH_QUERY)
		_open_first_result()
		_stage = 14
		return
	if _stage == 14 and _frames == 104:
		var image: Image = root.get_texture().get_image()
		image.save_png("res://docs/images/doc-search-results.png")
		print("[preview] search results %dx%d" % [image.get_width(), image.get_height()])
		_report_search()
		_stage = 15
		return
	if _stage == 15 and _frames == 108:
		# Phase 5, half two: a pack guide, whose "ACE reference" section is drawn from the live
		# vocabulary instead of from the Markdown - so the tables can never name a verb the picker
		# does not offer.
		_browser.search("")
		_browser.show_doc(PACK_DOC_ID)
		_browser.page().jump_to_anchor(EventSheetDocAceReference.SECTION_SLUG)
		_stage = 16
		return
	if _stage == 16 and _frames == 120:
		var image: Image = root.get_texture().get_image()
		image.save_png("res://docs/images/doc-ace-reference.png")
		print("[preview] live ACE reference %dx%d" % [image.get_width(), image.get_height()])
		_stage = 17
		return
	if _stage == 17 and _frames == 124:
		# Phase 4: a real guide page whose worked examples are drawn as LIVE ROWS. Wider than the
		# prose shots on purpose - a figure is the real renderer, and rows that have to wrap into a
		# 700 px column say nothing about how they look beside the reader's sheet.
		root.size = Vector2i(1180, 900)
		_browser.show_doc("guide:%s" % _first_page_with_a_figure())
		_stage = 18
		return
	if _stage == 18 and _frames == 132:
		_jump_to_first_figure()
		_stage = 19
		return
	if _stage == 19 and _frames == 142:
		var image: Image = root.get_texture().get_image()
		image.save_png("res://docs/images/doc-guide-figure.png")
		print("[preview] guide page with live figures %dx%d" % [image.get_width(), image.get_height()])
		_report_figures()
		_stage = 20
		return
	if _stage == 20 and _frames == 146:
		# The open question the spec left for this phase: what N VISIBLE FIGURES cost per frame.
		# Construction was measured headlessly and is linear; DRAW is not reachable there at all.
		_begin_sampling(_page_with_most_figures())
		_stage = 21
		return
	if _stage == 21 and _frames == 146 + SAMPLE_FRAMES + 4:
		_report_sampling()
		# The same measurement on a page of pure prose, as the control: a figure page is only
		# expensive if it is expensive COMPARED to the page it replaced.
		_begin_sampling(GUIDE_PAGE_ID)
		_stage = 22
		return
	if _stage == 22 and _frames == 146 + 2 * SAMPLE_FRAMES + 8:
		_report_sampling()
		_build_dock_beside_sheet()
		_stage = 23
		return
	if _stage == 23 and _frames == 146 + 2 * SAMPLE_FRAMES + 20:
		_jump_to_first_figure()
		_stage = 24
		return
	if _stage == 24 and _frames == 146 + 2 * SAMPLE_FRAMES + 30:
		var image: Image = root.get_texture().get_image()
		image.save_png("res://docs/images/doc-dock-beside-sheet.png")
		print("[preview] docked documentation beside a sheet %dx%d" % [image.get_width(), image.get_height()])
		_report_dock()
		quit(0)


func _build_bare_figure() -> EventSheetDocFigure:
	var figure: EventSheetDocFigure = EventSheetDocFigure.new()
	figure.set_caption("Print a line when the scene is ready, and again every frame:")
	figure.set_guide_action("Open the Core guide")
	figure.show_sheet(_demo_sheet())
	return figure


## The Phase 2 page: the whole "what does this do?" panel for a real pack verb, drawn from the
## live vocabulary. Screenshotted as the bare panel rather than through the window, so the image
## shows the page itself (the window around it is an AcceptDialog and adds nothing to read).
func _build_explain_page() -> Control:
	var panel: EventSheetDocPanel = EventSheetDocPanel.new()
	panel.show_definition(_pack_definition("res://eventsheet_addons/quest/quest_addon.gd", "method:advance_objective"))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(panel)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin: MarginContainer = EventSheetPopupUI.margined(scroll)
	margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
	margin.position = Vector2.ZERO
	margin.size = Vector2(700.0, 860.0)
	return margin


## The Phase 3 page: the whole documentation browser - the derived guide tree beside a shipped
## guide rendered as native Controls. Screenshotted at a deliberately narrow width, because the
## failure this image exists to catch (labels that collapse, or a column that balloons its host)
## only appears where the prose has to wrap.
func _build_guide_page() -> Control:
	_browser = EventSheetDocBrowser.new()
	_browser.show_doc("guide:%s" % GUIDE_PAGE_ID)
	var margin: MarginContainer = EventSheetPopupUI.margined(_browser)
	margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
	margin.position = Vector2.ZERO
	margin.size = Vector2(700.0, 880.0)
	return margin


## What the page actually measured, so the sizing trap is settled against numbers as well as an
## image: a collapsed page reports a tiny height, a ballooning one reports a width past the host.
func _report_page_geometry() -> void:
	var page: EventSheetDocPageView = _browser.page()
	print("[preview] page \"%s\": %d blocks, %d anchors, %.1f x %.1f" % [
		page.current_title(), page.get_child_count(), page.anchors().size(), page.size.x, page.size.y])


## The jump the headless suite cannot pin: a real anchor, on a real laid-out page, moving a real
## scrollbar. Prints the scroll offset either side of the jump and the heading it landed on.
func _jump_to_first_anchor() -> void:
	var page: EventSheetDocPageView = _browser.page()
	var anchors: Dictionary = page.anchors()
	var slugs: Array = anchors.keys()
	if slugs.size() < 4:
		print("[preview] not enough anchors on this page to jump")
		return
	# Not the first: the first heading is the page title, and scrolling to the top proves nothing.
	var slug: String = str(slugs[3])
	var heading: Control = anchors[slug] as Control
	var before: int = _browser._scroll.scroll_vertical
	page.jump_to_anchor(slug)
	print("[preview] jumped to \"%s\" (\"%s\"): scroll %d -> %d, heading y = %.1f" % [
		slug, heading.text, before, _browser._scroll.scroll_vertical, heading.global_position.y])


## Grows the window AND the fixed-size margin the page was parked in - the margin was sized for
## the narrow Phase 3 shot, so resizing only the window would leave the page exactly as wide.
func _widen(width: int, height: int) -> void:
	root.size = Vector2i(width, height)
	for child: Node in root.get_children():
		if child is MarginContainer:
			(child as MarginContainer).size = Vector2(float(width) - 20.0, float(height) - 20.0)


## Opens the first ranked result, the way a reader clicks one - which is also what puts the
## highlighted page beside the results tree in the image.
func _open_first_result() -> void:
	var results: Array[Dictionary] = EventSheetDocSearch.search(SEARCH_QUERY, 5)
	if results.is_empty():
		print("[preview] nothing matched \"%s\"" % SEARCH_QUERY)
		return
	var first: Dictionary = results[0]
	_browser.show_doc(str(first.get("doc_id", "")), str(first.get("anchor", "")))


## What the search actually found, so the ranking is settled against names as well as an image.
func _report_search() -> void:
	for result: Dictionary in EventSheetDocSearch.search(SEARCH_QUERY, 5):
		print("[preview] hit: %s / %s (score %d)" % [
			str(result.get("title", "")), str(result.get("heading", "-")), int(result.get("score", -1))])


## PER-FRAME COST, which is the one performance question a headless suite cannot answer at all: it
## never enters a tree, never lays anything out and never draws. Construction was measured headless
## and scales linearly; what was left open is whether a page carrying a dozen live canvases stays
## cheap once they are all on screen. The sampler opens a page, lets it settle, and then times the
## frames themselves.
func _begin_sampling(page_id: String) -> void:
	_browser.show_doc("guide:%s" % page_id)
	_sampling = page_id
	_samples = []
	_process_samples = []
	_last_frame_usec = 0


## Two numbers per frame, because they answer different halves of the question. The wall delta is
## whatever this machine's whole frame costs (the renderer here is slow and CONSTANT, which is
## exactly why the prose page is measured too, as a control). TIME_PROCESS is the engine's own
## CPU-side figure, and it is the one that would move if a dozen live canvases were expensive.
func _sample_frame() -> void:
	var now: int = Time.get_ticks_usec()
	var previous: int = _last_frame_usec
	_last_frame_usec = now
	# The first frame after show_doc is the build itself, not a steady frame.
	if _sampling.is_empty() or previous == 0 or _samples.size() >= SAMPLE_FRAMES:
		return
	_samples.append(float(now - previous) / 1000.0)
	_process_samples.append(float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0)


func _report_sampling() -> void:
	if _samples.is_empty():
		print("[preview] no frames sampled for %s" % _sampling)
		return
	print("[preview] frame cost on \"%s\" (%d live figure(s), %d blocks): whole frame %s, engine process time %s" % [
		_sampling, _figure_count(_sampling), EventSheetDocLibrary.page_blocks(_sampling).size(),
		_summarise(_samples), _summarise(_process_samples)])
	_sampling = ""


static func _summarise(samples: Array[float]) -> String:
	var total: float = 0.0
	var worst: float = 0.0
	for sample: float in samples:
		total += sample
		worst = maxf(worst, sample)
	return "avg %.2f ms / worst %.2f ms over %d frames" % [total / float(samples.size()), worst, samples.size()]


## The shipped page carrying the MOST figures - the worst case for the question above, and found
## rather than named so it follows the corpus as guides are written.
func _page_with_most_figures() -> String:
	var best_id: String = GUIDE_PAGE_ID
	var best: int = -1
	for id: String in EventSheetDocLibrary.page_ids():
		var count: int = _figure_count(id)
		if count > best:
			best = count
			best_id = id
	return best_id


## The first shipped page carrying a recognized figure. DISCOVERED, never named: which guides grow
## figures is the recognizer's answer and it changes as guides are written, so a hard-coded page id
## here would rot into "the preview shows a page with no figures on it".
func _first_page_with_a_figure() -> String:
	for id: String in EventSheetDocLibrary.page_ids():
		if _figure_count(id) > 0:
			return id
	print("[preview] no shipped page carries a figure")
	return "GUIDE-RECIPES"


func _figure_count(page_id: String) -> int:
	var count: int = 0
	for block: Dictionary in EventSheetDocLibrary.page_blocks(page_id):
		if str(EventSheetDocFigures.recognize(block).get("mode", "")) == EventSheetDocFigures.MODE_FIGURE:
			count += 1
	return count


## Scrolls to the first figure on the page, so the screenshot is of an illustration rather than of
## the prose above it.
##
## It is a COROUTINE, and that is the whole correctness of it: expanding a chapter only flips a
## container's `visible` flag, and Godot reflows on the next layout pass. Reading a figure's position
## in the same frame reads the positions of a page that has not grown yet, sets a scroll offset for a
## page that no longer exists, and photographs the header. Two frames of slack, then measure.
func _jump_to_first_figure() -> void:
	var page: EventSheetDocPageView = _browser.page()
	# A long page folds its chapters, and a figure inside a closed one is not on screen to
	# photograph. Opening them all is what the reader's own search does, and it is what these
	# images are of: the figures, not the fold.
	page.expand_all()
	await process_frame
	await process_frame
	var figures: Array[EventSheetDocFigure] = _figures_in(page)
	if figures.is_empty():
		print("[preview] the page drew no figure")
		return
	var offset: int = int(figures[0].global_position.y - page.global_position.y)
	_browser._scroll.scroll_vertical = offset
	print("[preview] scrolled to the first figure at y = %d" % offset)


## Every figure on the page, at any depth: a folded page nests its blocks inside per-chapter
## containers, so a walk over direct children finds nothing on exactly the pages that carry most.
func _figures_in(node: Node) -> Array[EventSheetDocFigure]:
	var found: Array[EventSheetDocFigure] = []
	for child: Node in node.get_children():
		if child is EventSheetDocFigure:
			found.append(child as EventSheetDocFigure)
			continue
		found.append_array(_figures_in(child))
	return found


## The numbers the suite cannot reach: how many figures a real page drew, and what one of their
## canvases actually measures once laid out (the 640 px floor removed, the rows their own size).
func _report_figures() -> void:
	var page: EventSheetDocPageView = _browser.page()
	var figures: Array[EventSheetDocFigure] = _figures_in(page)
	if not figures.is_empty():
		var viewport: EventSheetViewport = figures[0].figure_viewport()
		print("[preview] first figure canvas = %.1f x %.1f (content %.1f x %.1f), processing = %s" % [
			viewport.size.x, viewport.size.y, viewport.content_width(), viewport.content_height(),
			viewport.is_processing()])
	print("[preview] page \"%s\" drew %d live figure(s)" % [page.current_title(), figures.size()])


## Phase 6: the documentation where the reader keeps it - a sheet on the left, the reading surface
## in a dock-width column on the right. The dock NODE cannot appear here (EditorDock "can only be
## instantiated by editor", verified), so this stages what the dock hosts, at the width a
## DOCK_SLOT_RIGHT_UL column actually gives it and in the same compact mode the dock sets. What the
## image has to answer is the spec's 640 px problem: whether a guide's LIVE FIGURES survive a column
## this narrow, or whether the page ends up scrolling sideways.
func _build_dock_beside_sheet() -> void:
	for child: Node in root.get_children():
		if not (child is ColorRect):
			child.queue_free()
	root.size = Vector2i(1320, 840)
	var row: HBoxContainer = HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(row)
	_editor = EventSheetEditor.new()
	_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_editor)
	_editor.setup(_demo_sheet())
	# A fresh surface rather than the one the earlier stages parked in a margin: the dock builds its
	# own on first reveal, and reusing a wide-mode instance would hide whatever compact mode has to
	# undo. DOCK_WIDTH is what a right-hand slot gives a dock before anyone drags it.
	_browser = EventSheetDocBrowser.new()
	_browser.set_compact(true)
	_browser.custom_minimum_size.x = DOCK_WIDTH
	_browser.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var column: PanelContainer = EventSheetPopupUI.panel_section(_browser)
	# The sheet takes the slack; the docked column keeps the width a dock slot gives it. Without
	# this the card expands with the window and the image quietly stops being a NARROW one.
	column.size_flags_horizontal = Control.SIZE_FILL
	column.custom_minimum_size.x = DOCK_WIDTH
	row.add_child(column)
	_browser.show_doc("guide:%s" % _first_page_with_a_figure())


## The numbers behind the image: the column the page actually got, and what a figure inside it
## measured.
##
## A figure is content-sized with the host width as a CEILING - but only down to the width at which
## rows stop being legible at all, below which the figure drops the ceiling and pans instead. At a
## default dock slot the page IS below that line, so a canvas wider than the column here is the
## shipped, deliberate behaviour rather than a fault. What the number is worth reading for is the
## consequence: at this width the reader sees the first cells of a row and a horizontal scrollbar,
## so the action lane needs a drag. Widening the dock is what makes a figure whole.
func _report_dock() -> void:
	var page: EventSheetDocPageView = _browser.page()
	print("[preview] dock column = %.1f, page width = %.1f, compact = %s" % [
		_browser.size.x, page.size.x, str(_browser.is_compact())])
	var figures: Array[EventSheetDocFigure] = _figures_in(page)
	if figures.is_empty():
		print("[preview] the docked page drew no figure")
		return
	var viewport: EventSheetViewport = figures[0].figure_viewport()
	print("[preview] figure in the dock = %.1f wide (content %.1f), rows %.1f tall" % [
		viewport.size.x, viewport.content_width(), viewport.content_height()])


## One verb, reflected from a shipped pack exactly as the editor builds its vocabulary.
func _pack_definition(script_path: String, ace_id: String) -> ACEDefinition:
	var script: GDScript = load(script_path) as GDScript
	if script == null:
		return null
	for definition: ACEDefinition in EventSheetACEGenerator.new().generate_from_object(script.new()):
		if definition.id == ace_id:
			return definition
	return null


## A ConfirmationDialog never shrinks below its content's minimum size, and the picker's browse
## area asks for a tall one - so on a modest screen the info panel and its figure fall off the
## bottom of the shot. Relaxing the browse area's minimum for the screenshot moves nothing about
## the panel below it, which is what the image is of.
func _shrink_dialog_body(picker: ACEPickerDialog) -> void:
	var node: Node = picker._tree
	while node != null and node != picker._info_panel.get_parent():
		if node is Control and (node as Control).custom_minimum_size.y > 200.0:
			(node as Control).custom_minimum_size.y = 200.0
		node = node.get_parent()


## Searches the picker and highlights the first hit, so the info panel and its guide link are
## populated when the screenshot is taken - the same flow a reader uses.
func _search_and_select(picker: ACEPickerDialog, query: String) -> void:
	picker._search.text = query
	picker._refresh_tree()
	picker._select_first_match()


## Prints the numbers the spec asks to be settled against a rendered image rather than in code
## review: what the figure actually measures, and what the picker's panels actually occupy.
func _report_geometry() -> void:
	var picker: ACEPickerDialog = _editor._ace_picker
	print("[preview] info panel min height = %.1f, actual height = %.1f" % [
		picker._info_panel.custom_minimum_size.y, picker._info_panel.size.y])
	if picker._guide_button != null and picker._guide_button.visible:
		print("[preview] guide link shown: %s" % picker._guide_button.text)
	else:
		print("[preview] guide link hidden (builtin verb, section, or nothing selected)")
