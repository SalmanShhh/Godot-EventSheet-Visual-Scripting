# Godot EventSheets - the shapes an EDITOR is written in, read as events.
#
# A tool project is written in four shapes no game script has, and until now the sheet read all four
# as "a RefCounted with some functions". This pins what replaced them, over four real fixtures:
#
#   A helper with a back-reference reads as a behavior OF the object it was made with: the
#       Include bar says whose helper it is and which file that object lives in, the constructor
#       that only stores the reference is folded into the bar, a read through the reference reads as
#       the object's own property, and a call through it reads under the object's name.
#   An edit handed to the undo funnel reads as ONE undoable step - a Local boolean catching the
#       answer, the step's own name, and the edit hanging under it as sub-events, where a `return`
#       is the Answer the funnel asked for.
#   A class that is all static reads as a shared store: the bar says nothing of it is ever made,
#       each shared value says it is one for the whole editor, a frozen constant says so, and the
#       three report levels stop pretending to be one.
#   A vocabulary module's publishes read as the Define rows a pack author already knows, and a
#       function that hands over to itself says so on the call row.
#
# VALUES are pinned, not counts, and the covenant closes every gate: all four fixtures still
# re-emit byte-identically, because every word here is a lens.
@tool
class_name OpenedScriptEditorShapesTest
extends RefCounted

const HELPER_PATH := "res://tests/fixtures/opened_script_batch12_helper.gd"
const UNDO_PATH := "res://tests/fixtures/opened_script_batch12_undo.gd"
const SHARED_PATH := "res://tests/fixtures/opened_script_batch12_shared.gd"
const MODULE_PATH := "res://tests/fixtures/opened_script_batch12_module.gd"


static func run() -> bool:
	var ok: bool = true
	ok = _test_helper_of() and ok
	ok = _test_undo_step() and ok
	ok = _test_shared_store() and ok
	ok = _test_vocabulary_module() and ok
	ok = _test_facts_are_shape_bound() and ok
	ok = _test_the_funnel_check() and ok
	ok = _test_round_trip() and ok
	return ok


# ────────


static func _test_helper_of() -> bool:
	var ok: bool = true
	var view: EventSheetViewport = _open(HELPER_PATH)
	var readings: PackedStringArray = _readings(view)
	# The class name is the name band's and `@tool` is the tool band's, so the bar is left with
	# the shape this file plays in the editor it belongs to.
	ok = _check("the Include bar says whose helper this is",
		_texts(_row_with_uid(view.get_flat_rows(), "pack_include_bar_")),
		"⇥ | helper of | Dock | (event_sheet_dock.gd) · made with the dock | · opened_script_batch12_helper.gd | reads as events · 1 pattern ▸") and ok
	ok = _check("the constructor that only stores the reference is folded into the bar",
		_has_reading(readings, "On Init"), false) and ok
	ok = _check("a read through the reference is the object's own property",
		_has_reading(readings, "Local EventSheetResource | sheet | = Dock.CurrentSheet"), true) and ok
	ok = _check("a call through the reference is something the OBJECT does",
		_has_reading(readings, "Dock ▸ Select row"), true) and ok
	ok = _check("and the member that holds it is never the object",
		_has_reading(readings, "_dock ▸"), false) and ok
	ok = _check("the shape is claimed once, on the bar that says it",
		_claim_patterns(view), "helper_of") and ok
	view.free()
	return ok


# ────────


static func _test_undo_step() -> bool:
	var ok: bool = true
	var view: EventSheetViewport = _open(UNDO_PATH)
	var readings: PackedStringArray = _readings(view)
	ok = _check("the edit reads as one undoable step, named by the label",
		_first_containing(readings, "Edit sheet undoably"),
		"Local boolean | changed | = Dock ▸ Edit sheet undoably \"Apply Cell Edit\" | ↓ the steps below are the edit | ⟡ one undoable step, the edit under it") and ok
	ok = _check("the edit's own lines hang under it as sub-events",
		_first_containing(readings, "Append Condition Entry"),
		"System ▸ mode = \"new_condition_event\" | ƒ ▸ Call Append Condition Entry | System ▸ Answer true") and ok
	ok = _check("and the answer the funnel asked for reads as an answer",
		_has_reading(readings, "System ▸ Answer false"), true) and ok
	ok = _check("nothing of the edit is left as a code card",
		_has_reading(readings, "_perform_undoable_sheet_edit"), false) and ok
	ok = _check("the step is claimed", _claim_patterns(view).contains("undo_step"), true) and ok
	# The grammar's own value for the single-line spelling of the same call.
	ok = _check("a funnel call written on one line reads the same way",
		_joined(EventSheetSentence.statement("_dock._perform_undoable_sheet_edit(\"Apply Cell Edit\", edit)",
			{"helper_of": {"member": "_dock", "object": "Dock"}})),
		"Dock ▸ Edit sheet undoably \"Apply Cell Edit\"") and ok
	# A `return` is only an Answer inside an edit. Everywhere else it still stops the event.
	ok = _check("a return outside an edit is unchanged",
		_joined(EventSheetSentence.statement("return true", {})), "System ▸ Return true") and ok
	ok = _check("and inside one it answers",
		_joined(EventSheetSentence.statement("return true", {"answer_return": true})),
		"System ▸ Answer true") and ok
	view.free()
	return ok


# ────────


static func _test_shared_store() -> bool:
	var ok: bool = true
	var view: EventSheetViewport = _open(SHARED_PATH)
	var readings: PackedStringArray = _readings(view)
	ok = _check("the Include bar says nothing of this class is ever made",
		_texts(_row_with_uid(view.get_flat_rows(), "pack_include_bar_")),
		"⇥ | shared store | · nothing of its own is ever made | · opened_script_batch12_shared.gd | reads as events · 1 pattern ▸") and ok
	ok = _check("a shared value says it is one for the whole editor",
		_first_containing(readings, "_claims"),
		"x | Shared | table | _claims | = | empty | one for the whole editor | static var _claims: Dictionary = {}") and ok
	ok = _check("a constant the file froze says so",
		_first_containing(readings, "PATTERN_IDS"),
		"x | Constant | list of text | PATTERN_IDS | = | [\"state_machine\", \"object_pool\", \"countdown\"] | frozen | const PATTERN_IDS: PackedStringArray = [\"state_machine\", \"object_pool\", \"countdown\"]") and ok
	ok = _check("the store is claimed", _claim_patterns(view), "shared_store") and ok
	view.free()
	# The three report levels, each its own act - and `printerr` stays the log line it always was.
	ok = _check("a warning warns",
		_joined(EventSheetSentence.statement("push_warning(\"careful\")", {})),
		"System ▸ Warn \"careful\"") and ok
	ok = _check("an error is reported",
		_joined(EventSheetSentence.statement("push_error(\"broken\")", {})),
		"System ▸ Report error \"broken\"") and ok
	ok = _check("and printing an error is still a log line",
		_joined(EventSheetSentence.statement("printerr(\"broken\")", {})),
		"System ▸ Log error \"broken\"") and ok
	# The scope word itself, at the seam every variable row spells its chip through.
	ok = _check("the shared scope has its own word",
		EventSheetVariableSentence.scope_word(EventSheetVariableSentence.SCOPE_SHARED), "Shared") and ok
	return ok


# ─────────


static func _test_vocabulary_module() -> bool:
	var ok: bool = true
	var view: EventSheetViewport = _open(MODULE_PATH)
	var readings: PackedStringArray = _readings(view)
	ok = _check("a published condition reads as the Define row it is",
		_has_reading(readings, "Core ▸ Define condition Is Pinned   Core/IsPinned · category Pin · input target: Node   Writes {target.}is_pinned()"), true) and ok
	ok = _check("and a published action does too",
		_has_reading(readings, "Core ▸ Define action Pin To   Core/PinTo · category Pin · input anchor: Node   Writes {target.}pin_to({anchor})"), true) and ok
	ok = _check("a function that hands over to itself says so on the call row",
		_has_reading(readings, "ƒ ▸ Call Walk   depth = depth + 1   ↻ itself"), true) and ok
	view.free()
	# The other spelling of the same publish - the one the editor's own modules are written in.
	var descriptor: String = "\tdescriptors.append(F.make_descriptor(\"Core\", \"InputAddAction\", \"Add Input Action\", ACEDescriptor.ACEType.ACTION, \"InputMap.add_action({action})\", \"\", [F.make_param(\"action\", \"String\", \"\\\"jump\\\"\")], \"Input\", \"add input action {action}\"))"
	ok = _check("a descriptor built in positions reads as the same Define row",
		_joined(EventSheetSentence.statement(descriptor, {})),
		"Core ▸ Define action Add Input Action   InputAddAction · category Input · input action: String   Writes InputMap.add_action({action})") and ok
	return ok


# ── The facts themselves ──


## Each shape is claimed by SHAPE, never by a list of file names - so it fires on the editor's own
## files, and a file that only half fits is not called one of them.
static func _test_facts_are_shape_bound() -> bool:
	var ok: bool = true
	var helper: Dictionary = EventSheetEditorSourceFacts.facts_for_source(
		FileAccess.get_file_as_string("res://addons/eventsheet/editor/dock/bookmarks_panel.gd"))
	ok = _check("a real dock helper is read as a helper of the dock",
		str((helper.get("helper_of", {}) as Dictionary).get("object", "")), "Dock") and ok
	ok = _check("and the file named is the one that declares what it reaches for",
		str((helper.get("helper_of", {}) as Dictionary).get("file", "")), "event_sheet_dock.gd") and ok
	var store: Dictionary = EventSheetEditorSourceFacts.facts_for_source(
		FileAccess.get_file_as_string("res://addons/eventsheet/editor/interaction/pattern_facts.gd"))
	ok = _check("a real registry is read as a shared store",
		bool(store.get("shared_store", false)), true) and ok
	ok = _check("and its frozen list is read as frozen",
		(store.get("frozen_constants", {}) as Dictionary).has("PATTERN_IDS"), true) and ok
	var module: Dictionary = EventSheetEditorSourceFacts.facts_for_source(
		FileAccess.get_file_as_string("res://addons/eventforge/registration/modules/node_aces.gd"))
	ok = _check("a real vocabulary module is read as one",
		bool(module.get("vocabulary_module", false)), true) and ok
	# A constructor that DOES something is a constructor: calling its class a behavior of its
	# argument would put a reader's eyes on the wrong object.
	var busy: Dictionary = EventSheetEditorSourceFacts.facts_for_source(
		"extends RefCounted\n\nvar _dock = null\n\nfunc _init(dock):\n\t_dock = dock\n\t_dock.build()\n\tprint(1)\n")
	ok = _check("a constructor that does more than remember is not folded",
		busy.has("helper_of"), false) and ok
	# A plain game script must see none of this.
	var game: Dictionary = EventSheetEditorSourceFacts.facts_for_source(
		"extends Node2D\n\nvar speed = 100\n\nfunc _process(delta):\n\tposition.x += speed * delta\n")
	ok = _check("an ordinary script has none of these shapes", game.is_empty(), true) and ok
	ok = _check("and the editor's own repo is recognised as one",
		EventSheetEditorSourceFacts.is_editor_project(), true) and ok
	return ok


## The health check: an edit made around the funnel rather than through it is a finding, and a
## helper that uses the funnel is not.
static func _test_the_funnel_check() -> bool:
	var ok: bool = true
	var around: String = "var sheet = _dock._current_sheet\nsheet.events.append(row)\n" \
		.replace("sheet.events.append(row)", "_dock._current_sheet.events.append(row)")
	ok = _check("an edit made around the funnel is named",
		EventSheetProjectDoctor.sheet_edit_outside_funnel(around), "_current_sheet.events.append") and ok
	ok = _check("an edit made through it is not",
		EventSheetProjectDoctor.sheet_edit_outside_funnel(
			"_dock._perform_undoable_sheet_edit(\"Add\", func(): _dock._current_sheet.events.append(row))"), "") and ok
	return ok


# ── The covenant ──


static func _test_round_trip() -> bool:
	var ok: bool = true
	for path: String in [HELPER_PATH, UNDO_PATH, SHARED_PATH, MODULE_PATH]:
		var source: String = FileAccess.get_file_as_string(path)
		var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
		sheet.read_only = true
		var view := EventSheetViewport.new()
		view.set_ace_registry(EventSheetACERegistry.new())
		view.set_sheet(sheet)
		view.set_reading_mode(true)
		view.get_flat_rows()
		var reemitted: String = str(SheetCompiler.compile(sheet, path).get("output", ""))
		ok = _check("%s still re-emits byte-identically" % path.get_file(), reemitted == source, true) and ok
		view.free()
	return ok


# ── Harness ──


static func _open(path: String) -> EventSheetViewport:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
	sheet.read_only = true
	var style := EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	var view := EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.set_sheet(sheet)
	view.set_reading_mode(true)
	view.get_flat_rows()
	return view


## The first row whose uid opens with `prefix`, or null.
static func _row_with_uid(rows: Array, prefix: String) -> EventRowData:
	for entry: Variant in rows:
		var row_data: EventRowData = (entry as Dictionary).get("row")
		if row_data != null and row_data.row_uid.begins_with(prefix):
			return row_data
	return null


static func _row_at(rows: Array, index: int) -> EventRowData:
	return (rows[index] as Dictionary).get("row") if index < rows.size() else null


static func _texts(row_data: EventRowData) -> String:
	if row_data == null:
		return ""
	var parts: PackedStringArray = PackedStringArray()
	for span: SemanticSpan in row_data.spans:
		parts.append(str(span.text))
	return " | ".join(parts)


## Every row of the tree as "object ▸ text | …", parents before children.
static func _readings(view: EventSheetViewport) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	_sweep(view, view._root_rows, out)
	return out


static func _sweep(view: EventSheetViewport, rows: Array, out: PackedStringArray) -> void:
	for row_data: EventRowData in rows:
		view._ensure_event_spans(row_data)
		var parts: PackedStringArray = PackedStringArray()
		for span: SemanticSpan in row_data.spans:
			var object_label: String = str(span.metadata.get("object_label", "")) if span.metadata is Dictionary else ""
			parts.append("%s ▸ %s" % [object_label, span.text] if not object_label.is_empty() else str(span.text))
		out.append(" | ".join(parts))
		_sweep(view, row_data.children, out)


static func _has_reading(readings: PackedStringArray, wanted: String) -> bool:
	for reading: String in readings:
		if reading.contains(wanted):
			return true
	return false


static func _first_containing(readings: PackedStringArray, wanted: String) -> String:
	for reading: String in readings:
		if reading.contains(wanted):
			return reading
	return ""


## The pattern ids the sheet's readings claimed, joined - the registry everything that talks about
## these shapes reads.
static func _claim_patterns(view: EventSheetViewport) -> String:
	var ids: PackedStringArray = PackedStringArray()
	for claim: Variant in EventSheetPatternFacts.claims(view._sheet):
		var pattern: String = str((claim as Dictionary).get("pattern", ""))
		if not ids.has(pattern):
			ids.append(pattern)
	return " | ".join(ids)


## One statement reading as "object ▸ sentence".
static func _joined(reading: Dictionary) -> String:
	var text: String = ""
	for segment: Variant in (reading.get("segments", []) as Array):
		text += str((segment as Dictionary).get("text", ""))
	var object_label: String = str(reading.get("object", ""))
	return "%s ▸ %s" % [object_label, text.strip_edges()] if not object_label.is_empty() else text.strip_edges()


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] opened_script_editor_shapes_test: %s" % label)
		return true
	print("[FAIL] opened_script_editor_shapes_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
