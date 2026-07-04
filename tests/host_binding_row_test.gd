# EventForge - the generated host-binding `_enter_tree` block renders as ONE muted "Host binding"
# line instead of a 4-line GDScript block. It carries no authored logic (regenerated from the
# sheet's host), so a behaviour pack opens reading as vocabulary, not boilerplate. Pins: the strict
# exact-shape classifier (a hand-modified _enter_tree stays a real block), the collapsed rendering
# over a real pack, and - covenant-critical - the byte round-trip is untouched (pure view).
@tool
class_name HostBindingRowTest
extends RefCounted

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
	var pack_path: String = "res://eventsheet_addons/health/health_behavior.gd"
	var source: String = (FileAccess.open(pack_path, FileAccess.READ)).get_as_text()
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(EventSheetResource.new())
	dock._load_sheet_from_path(pack_path)
	var view: EventSheetViewport = dock._active_view()
	var host_row: EventRowData = null
	for entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and not row_data.spans.is_empty() and str(row_data.spans[0].text) == "Host binding":
			host_row = row_data
	ok = _check("the pack shows a Host binding row", host_row != null, true) and ok
	ok = _check("it collapses to one line", host_row.line_count if host_row != null else -1, 1) and ok
	ok = _check("it names the host class", host_row != null and str(host_row.spans[1].text).contains("Node2D"), true) and ok
	ok = _check("no bare `func _enter_tree` GDScript block remains",
		_has_enter_tree_block(view), false) and ok
	ok = _check("the row keeps its RawCodeRow (still edits/round-trips)",
		host_row != null and host_row.source_resource is RawCodeRow, true) and ok

	# ── Covenant: pure view - the pack still round-trips byte-identically ──
	var reemitted: String = str(SheetCompiler.compile(dock.get_current_sheet(), pack_path).get("output", ""))
	ok = _check("drift stays 0 with the host binding collapsed", reemitted == source, true) and ok

	dock.free()
	return ok


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
	if actual == expected:
		print("[PASS] host_binding_row_test: %s" % label)
		return true
	print("[FAIL] host_binding_row_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
