# EventForge - a pure-data inner class (`class X:` of only typed fields) opened from a .gd pack renders as
# a first-class "Data class" block: a name chip plus its fields as foldable read-only rows, instead of a
# raw GDScript wall. Pins: the strict classifier (a method-bearing class, a second class, or trailing code
# all stay a real block), the byte-exact structured model round-trip (the covenant gate), the collapsed
# rendering over the real `abilities` pack, and - covenant-critical - the pack still round-trips byte for
# byte (this slice is a pure view).
@tool
class_name DataClassLiftTest
extends RefCounted

# The AbilityData holder exactly as the importer chunks it (leading blank + doc block + typed fields),
# captured from the real `abilities` pack. This is the ground truth the byte-gate must reproduce.
const ABILITY_DATA := "\n## One ability's runtime state - typed so the cooldown / stack / expiration hot paths read\n## fields directly instead of float()/int()/bool()-casting an untyped Dictionary every frame.\nclass AbilityData:\n\tvar cooldown: float = 0.0\n\tvar max_cooldown: float = 0.0\n\tvar stacks: int = 1\n\tvar max_stacks: int = 1\n\tvar enabled: bool = true\n\tvar active: bool = false\n\tvar data: Dictionary = {}\n\tvar tags: Array = []\n\tvar expiration: float = 0.0\n\tvar max_expiration: float = 0.0"


static func run() -> bool:
	var ok: bool = true

	# ── The strict classifier (data_class_name) ──
	ok = _check("the canonical AbilityData class is recognised", ViewportRowBuilder.data_class_name(ABILITY_DATA), "AbilityData") and ok
	ok = _check("a minimal one-field class is recognised",
		ViewportRowBuilder.data_class_name("class Foo:\n\tvar x: int = 0"), "Foo") and ok
	ok = _check("an `extends` base is tolerated",
		ViewportRowBuilder.data_class_name("class Bar extends RefCounted:\n\tvar y: int = 0"), "Bar") and ok
	ok = _check("a method-bearing class is NOT a data class (stays a real block)",
		ViewportRowBuilder.data_class_name("class Foo:\n\tvar x: int = 0\n\tfunc bar() -> void:\n\t\tpass"), "") and ok
	ok = _check("a second/nested class breaks the match",
		ViewportRowBuilder.data_class_name("class Foo:\n\tvar x: int = 0\nclass Bar:\n\tvar y: int = 0"), "") and ok
	ok = _check("trailing top-level code breaks the match",
		ViewportRowBuilder.data_class_name("class Foo:\n\tvar x: int = 0\nprint(1)"), "") and ok
	ok = _check("an empty class (no fields) is not lifted",
		ViewportRowBuilder.data_class_name("class Foo:\n\tpass"), "") and ok
	ok = _check("a plain function is not a data class",
		ViewportRowBuilder.data_class_name("func foo() -> void:\n\tpass"), "") and ok

	# ── The structured model + byte-exact re-emit (the covenant gate) ──
	var model: Dictionary = ViewportRowBuilder.parse_data_class(ABILITY_DATA)
	ok = _check("the model names the class", str(model.get("class_name")), "AbilityData") and ok
	ok = _check("the model has no extends base", str(model.get("extends")), "") and ok
	var fields: Array = []
	for entry: Dictionary in model.get("body", []):
		if str(entry.get("kind")) == "field":
			fields.append(entry)
	ok = _check("all 10 fields are parsed", fields.size(), 10) and ok
	ok = _check("the first field name is parsed", str((fields[0] as Dictionary).get("name")), "cooldown") and ok
	ok = _check("the first field type is parsed", str((fields[0] as Dictionary).get("type")), "float") and ok
	ok = _check("the first field default is parsed", str((fields[0] as Dictionary).get("default")), "0.0") and ok
	# The `{}`/`[]` defaults must survive the field split intact or the byte-gate fails.
	ok = _check("a Dictionary field keeps its `{}` default", str((fields[6] as Dictionary).get("default")), "{}") and ok
	ok = _check("an Array field keeps its `[]` default", str((fields[7] as Dictionary).get("default")), "[]") and ok
	ok = _check("emit_data_class reproduces the source byte-for-byte", ViewportRowBuilder.emit_data_class(model), ABILITY_DATA) and ok
	ok = _check("data_class_lifts gates AbilityData true", ViewportRowBuilder.data_class_lifts(ABILITY_DATA), true) and ok
	ok = _check("data_class_lifts rejects a method-bearing class",
		ViewportRowBuilder.data_class_lifts("class Foo:\n\tvar x: int = 0\n\tfunc bar() -> void:\n\t\tpass"), false) and ok

	# ── Rendering over the real opened `abilities` pack ──
	var pack_path: String = "res://eventsheet_addons/abilities/abilities_behavior.gd"
	var source: String = (FileAccess.open(pack_path, FileAccess.READ)).get_as_text()
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(EventSheetResource.new())
	dock._load_sheet_from_path(pack_path)
	var view: EventSheetViewport = dock._active_view()
	var class_row: EventRowData = null
	for entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and not row_data.spans.is_empty() and str(row_data.spans[0].text) == "Data class":
			class_row = row_data
	ok = _check("the pack shows a Data class row", class_row != null, true) and ok
	ok = _check("it collapses to one header line", class_row.line_count if class_row != null else -1, 1) and ok
	ok = _check("the class name is its own chip span",
		class_row != null and class_row.spans.size() >= 2 and str(class_row.spans[1].text) == "AbilityData", true) and ok
	ok = _check("the fields render as child rows", class_row.children.size() if class_row != null else -1, 10) and ok
	# A field child reads like a variable row: name : type = default.
	var first_field_row: EventRowData = class_row.children[0] if class_row != null and not class_row.children.is_empty() else null
	ok = _check("the first field row names the field",
		first_field_row != null and str(first_field_row.spans[0].text) == "cooldown", true) and ok
	ok = _check("a field row is inert (source_resource null, no mutation reaches it)",
		first_field_row != null and first_field_row.source_resource == null, true) and ok
	ok = _check("no bare `class AbilityData:` GDScript span remains", _has_class_span(view), false) and ok
	ok = _check("the header keeps its RawCodeRow (still edits/round-trips)",
		class_row != null and class_row.source_resource is RawCodeRow, true) and ok

	# ── Covenant: pure view - the pack still round-trips byte-identically ──
	var reemitted: String = str(SheetCompiler.compile(dock.get_current_sheet(), pack_path).get("output", ""))
	ok = _check("drift stays 0 with the data class collapsed", reemitted == source, true) and ok

	dock.free()
	return ok


static func _has_class_span(view: EventSheetViewport) -> bool:
	for entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data == null:
			continue
		for span: SemanticSpan in row_data.spans:
			if str(span.text).begins_with("class AbilityData"):
				return true
	return false


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] data_class_lift_test: %s" % label)
		return true
	print("[FAIL] data_class_lift_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
