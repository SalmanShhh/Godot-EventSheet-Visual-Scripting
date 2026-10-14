# EventForge - a behaviour shows its host ONCE: on the `host` variable row, where the file declares
# it. The generated host-binding `_enter_tree` block carries no authored logic (it is regenerated
# from the sheet's host), so it draws no row of its own - it used to be a second "Host binding" bar
# saying the same thing. Pins: the strict exact-shape classifier (a hand-modified _enter_tree stays
# a real block), the reading over a real pack, read-only and editable, and - covenant-critical -
# the byte round-trip is untouched (pure view).
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

	# ── Reading over a real opened pack: the host is said once, read-only and editable alike ──
	var pack_path: String = "res://eventsheet_addons/health/health_behavior.gd"
	var source: String = (FileAccess.open(pack_path, FileAccess.READ)).get_as_text()
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(EventSheetResource.new())
	dock._load_sheet_from_path(pack_path)
	var view: EventSheetViewport = dock._active_view()
	ok = _check("the binding block is still in the sheet", _binding_blocks(dock.get_current_sheet()), 1) and ok
	ok = _check("a read-only preview draws no row for the binding", _binding_rows(view), 0) and ok
	ok = _check("a read-only preview names the host on its variable row", _host_variable_rows(view), ["Node2D"]) and ok
	var opened_sheet: EventSheetResource = dock.get_current_sheet()
	opened_sheet.read_only = false
	view.set_sheet(opened_sheet)
	ok = _check("an editable sheet draws no row for the binding", _binding_rows(view), 0) and ok
	ok = _check("an editable sheet names the host on its variable row", _host_variable_rows(view), ["Node2D"]) and ok

	# ── A binding that fails to compile keeps its row, so the error has a place to show ──
	var binding: RawCodeRow = _binding_block(opened_sheet)
	view._row_diagnostics = {str(binding.get_instance_id()): "Parse error"}
	ok = _check("a binding carrying an error is drawn", view._build_row_from_resource(binding, 0) != null, true) and ok
	view._row_diagnostics = {}

	# ── Covenant: pure view - the pack still round-trips byte-identically ──
	var reemitted: String = str(SheetCompiler.compile(dock.get_current_sheet(), pack_path).get("output", ""))
	ok = _check("the pack re-emits byte for byte", reemitted == source, true) and ok

	dock.free()
	return ok


## How many rows in the view carry a host-binding block, at any depth.
static func _binding_rows(view: EventSheetViewport) -> int:
	var found: int = 0
	for entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.source_resource is RawCodeRow \
				and not ViewportRowBuilder.host_binding_class((row_data.source_resource as RawCodeRow).code).is_empty():
			found += 1
	return found


## The type each `host` variable row in the view declares, in order.
static func _host_variable_rows(view: EventSheetViewport) -> Array:
	var types: Array = []
	for entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.source_resource is LocalVariable \
				and (row_data.source_resource as LocalVariable).name == "host":
			types.append((row_data.source_resource as LocalVariable).type_name)
	return types


static func _binding_blocks(sheet: EventSheetResource) -> int:
	return 1 if _binding_block(sheet) != null else 0


static func _binding_block(sheet: EventSheetResource) -> RawCodeRow:
	for entry: Variant in sheet.events:
		if entry is RawCodeRow and not ViewportRowBuilder.host_binding_class((entry as RawCodeRow).code).is_empty():
			return entry as RawCodeRow
	return null


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("host_binding_row_test", label, actual, expected)
