# EventForge - the generated host-binding `_enter_tree` block renders as ONE muted "Host binding"
# line instead of a 4-line GDScript block. It carries no authored logic (regenerated from the
# sheet's host), so a behaviour pack opens reading as vocabulary, not boilerplate. Pins: the strict
# exact-shape classifier (a hand-modified _enter_tree stays a real block), the collapsed rendering
# over a real pack, and - covenant-critical - the byte round-trip is untouched (pure view).
@tool
class_name HostBindingRowTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const CANONICAL := "func _enter_tree() -> void:\n\thost = get_parent() as Node2D\n\tif host == null:\n\t\tpush_warning(\"SimpleHealthBehavior behavior requires a Node2D parent.\")"


static func run() -> bool:
	var ok: bool = true

	# ── The strict classifier ──
	ok = _check("the canonical host binding is recognised", ViewportRowBuilder.host_binding_class(CANONICAL), "Node2D") and ok
	ok = _check("a trailing blank is tolerated", ViewportRowBuilder.host_binding_class(CANONICAL + "\n"), "Node2D") and ok
	ok = _check("the host class is extracted verbatim",
		ViewportRowBuilder.host_binding_class(CANONICAL.replace("Node2D", "CharacterBody2D")), "CharacterBody2D") and ok
	ok = _check("a hand-modified body is NOT a match (stays a real block)",
		ViewportRowBuilder.host_binding_class(CANONICAL.replace("push_warning", "printerr")), "") and ok
	ok = _check("an extra statement breaks the match",
		ViewportRowBuilder.host_binding_class(CANONICAL + "\n\tsetup()"), "") and ok
	ok = _check("a different function is not a host binding",
		ViewportRowBuilder.host_binding_class("func _ready() -> void:\n\tpass"), "") and ok

	# ── Rendering over a real opened pack ──
	# The Host binding BAR is now the editable-sheet reading. A read-only preview folds it (with the
	# class-setup strip and the `host` variable) into the one Include bar the pack head opens with, so
	# this half of the test drives the same pack with the preview flag cleared - the bar itself, its
	# chips and its byte round-trip are unchanged, and the preview's own reading is pinned below.
	var pack_path: String = "res://eventsheet_addons/health/health_behavior.gd"
	var source: String = (FileAccess.open(pack_path, FileAccess.READ)).get_as_text()
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(EventSheetResource.new())
	dock._load_sheet_from_path(pack_path)
	var view: EventSheetViewport = dock._active_view()
	var preview_bar: EventRowData = null
	for entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.row_uid.begins_with("pack_include_bar_"):
			preview_bar = row_data
	ok = _check("a read-only preview folds the binding into the Include bar", preview_bar != null, true) and ok
	ok = _check("the Include bar still names the host class",
		preview_bar != null and _span_texts(preview_bar).has("Node2D"), true) and ok
	ok = _check("no Host binding bar is drawn twice on a preview",
		_has_host_binding_row(view), false) and ok
	var opened_sheet: EventSheetResource = dock.get_current_sheet()
	opened_sheet.read_only = false
	view.set_sheet(opened_sheet)
	var host_row: EventRowData = null
	for entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		# The row now leads with the icon badge span; "Host binding" is the first TEXT span.
		if row_data != null and row_data.spans.size() >= 2 and str(row_data.spans[1].text) == "Host binding":
			host_row = row_data
	ok = _check("the pack shows a Host binding row", host_row != null, true) and ok
	ok = _check("it collapses to one line", host_row.line_count if host_row != null else -1, 1) and ok
	# First-class block: the host class is its OWN chip span (not buried in prose), followed by a cue that
	# points at the double-click-to-edit-in-code affordance (the RawCodeRow editor keeps the .gd round-trip).
	ok = _check("the host class is its own chip span", host_row != null and str(host_row.spans[2].text) == "Node2D", true) and ok
	ok = _check("a muted cue explains the class edits in code",
		host_row != null and host_row.spans.size() >= 4 and str(host_row.spans[3].text).contains("edit in code"), true) and ok
	ok = _check("the row reserves bar presence (1.5x height)", host_row != null and is_equal_approx(host_row.height_scale, 1.5), true) and ok
	ok = _check("no bare `func _enter_tree` GDScript block remains",
		_has_enter_tree_block(view), false) and ok
	ok = _check("the row keeps its RawCodeRow (still edits/round-trips)",
		host_row != null and host_row.source_resource is RawCodeRow, true) and ok

	# ── Covenant: pure view - the pack still round-trips byte-identically ──
	var reemitted: String = str(SheetCompiler.compile(dock.get_current_sheet(), pack_path).get("output", ""))
	ok = _check("drift stays 0 with the host binding collapsed", reemitted == source, true) and ok

	dock.free()
	return ok


## Every span text of a row, so a claim can ask what a bar SAYS without indexing into its spans.
static func _span_texts(row_data: EventRowData) -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for span: SemanticSpan in row_data.spans:
		texts.append(str(span.text))
	return texts


static func _has_host_binding_row(view: EventSheetViewport) -> bool:
	for entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.spans.size() >= 2 and str(row_data.spans[1].text) == "Host binding":
			return true
	return false


static func _has_enter_tree_block(view: EventSheetViewport) -> bool:
	for entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		# A raw block still rendered line-by-line would show its `func _enter_tree` text in a span.
		if row_data == null:
			continue
		for span: SemanticSpan in row_data.spans:
			if str(span.text).begins_with("func _enter_tree"):
				return true
	return false


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("host_binding_row_test", label, actual, expected)
