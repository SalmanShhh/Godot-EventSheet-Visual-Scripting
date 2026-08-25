# EventForge - the two readings of batch 5 that are about WIRING, pinned by VALUE on a real scene
# fixture rather than on hand-built resources:
#
#   A signal wired to ANOTHER object's function reads as the trigger calling it, the bound
#       values as ordinary parameter chips
#   A .tscn opens as ONE read-only sheet: the scene's own bar, then every script it uses under
#       its own object bar, with the wiring the scene file holds read as triggers
#
# Both are READINGS: the rows change, no file does. The byte round-trip of every script in the scene
# is asserted first, and the scene file is compared before and after opening, because a reading that
# costs a file its bytes is not a reading, it is a bug.
@tool
class_name OpenedScriptStructure6Test
extends RefCounted

const LEVEL_PATH: String = "res://tests/fixtures/opened_scene_level.gd"
const PLAYER_PATH: String = "res://tests/fixtures/opened_scene_player.gd"
const HUD_PATH: String = "res://tests/fixtures/opened_scene_hud.gd"
const SCENE_PATH: String = "res://tests/fixtures/opened_scene_level.tscn"


static func run() -> bool:
	var ok: bool = true
	ok = _round_trips() and ok
	ok = _callable_shapes() and ok
	ok = _wired_call_rows() and ok
	ok = _scene_sheet_rows() and ok
	ok = _scene_file_untouched() and ok
	return ok


## ── the contract that outranks every reading ─────────────────────────────────────────────────────
static func _round_trips() -> bool:
	var ok: bool = true
	for path: String in [LEVEL_PATH, PLAYER_PATH, HUD_PATH]:
		var source: String = FileAccess.get_file_as_string(path)
		var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
		var output: String = str(SheetCompiler.compile(sheet, path).get("output", ""))
		ok = _check("%s comes back byte-identical" % path.get_file(), output, source) and ok
	return ok


## ── the three spellings of a callable, and the one that is NOT this reading ──────────────────────
static func _callable_shapes() -> bool:
	var ok: bool = true
	var plain: Dictionary = ViewportRowBuilder.connect_call_parts("\t$StartButton.pressed.connect(player.reset)")
	ok = _check("the emitting object is named", str(plain.get("object", "")), "StartButton") and ok
	ok = _check("the signal reads as its trigger", str(plain.get("trigger", "")), "On Pressed") and ok
	ok = _check("the called object is named", str(plain.get("target", "")), "player") and ok
	ok = _check("the called function is named", str(plain.get("method", "")), "reset") and ok

	var bound: Dictionary = ViewportRowBuilder.connect_call_parts("\t$WaveTimer.timeout.connect(hud.show_wave.bind(3))")
	ok = _check("a bound value rides along", ", ".join(bound.get("args", PackedStringArray())), "3") and ok
	ok = _check("a bound call is not one shot", bool(bound.get("one_shot", true)), false) and ok

	var made: Dictionary = ViewportRowBuilder.connect_call_parts(
		"\t$WaveTimer.timeout.connect(Callable(hud, \"show_wave\").bind(9), CONNECT_ONE_SHOT)")
	ok = _check("the Callable spelling names the same function", str(made.get("method", "")), "show_wave") and ok
	ok = _check("its bound value rides along too", ", ".join(made.get("args", PackedStringArray())), "9") and ok
	ok = _check("the one-shot flag is read", bool(made.get("one_shot", false)), true) and ok

	# A connect handed a bare name is a handler declared in THIS file: it already reads as the
	# trigger event it is, where the function is written, and must not be claimed twice.
	ok = _check("a handler of this file is not claimed",
		ViewportRowBuilder.connect_call_parts("\t$WaveTimer.timeout.connect(_on_wave_timer_timeout)").is_empty(), true) and ok
	# A lambda is the other reading's business.
	ok = _check("a lambda is not claimed",
		ViewportRowBuilder.connect_call_parts("\t$WaveTimer.timeout.connect(func(): wave += 1)").is_empty(), true) and ok
	return ok


## ── what the rows actually say ───────────────────────────────────────────────────────────────────
static func _wired_call_rows() -> bool:
	var ok: bool = true
	var view: EventSheetViewport = _open(LEVEL_PATH)
	var texts: PackedStringArray = _row_texts(view)
	ok = _check("the plain callable reads as the trigger calling it",
		_first_containing(texts, "Call Reset"), "➜ | On Pressed | Call Reset") and ok
	ok = _check("a bound value reads as an ordinary parameter chip, named by the callee",
		_first_containing(texts, "count = 3"), "➜ | On Timeout | Call Show Wave   count = 3") and ok
	ok = _check("a one-shot connection wears the sheet's own Trigger once",
		_first_containing(texts, "count = 9"), "➜ | On Timeout | Trigger once | Call Show Wave   count = 9") and ok
	# The connect lines themselves keep their muted note - nothing is hidden.
	ok = _check("the connect line keeps its note",
		_first_containing(texts, "connects StartButton").contains("connects StartButton On Pressed"), true) and ok
	return ok


## ── the scene opens as one sheet, every script under its own object bar ──────────────────────────
static func _scene_sheet_rows() -> bool:
	var ok: bool = true
	var scene_sheet: EventSheetResource = EventSheetSceneSheet.build(SCENE_PATH)
	ok = _check("the sheet is the scene's own", EventSheetSceneSheet.scene_path_of(scene_sheet), SCENE_PATH) and ok
	ok = _check("a scene sheet is read only", scene_sheet.read_only, true) and ok
	ok = _check("the tab is named after the scene",
		EventSheetDock._format_sheet_title(scene_sheet, SCENE_PATH), "opened_scene_level.tscn") and ok
	var scripts: PackedStringArray = PackedStringArray()
	for member: Dictionary in EventSheetSceneSheet.members_of(scene_sheet):
		scripts.append("%s %s" % [str(member.get("node", "")), str(member.get("script_path", "")).get_file()])
	ok = _check("every script the scene uses is there, in tree order", ", ".join(scripts),
		"Level opened_scene_level.gd, Player opened_scene_player.gd, HUD opened_scene_hud.gd") and ok

	var view := EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.set_sheet(scene_sheet)
	view.set_reading_mode(true)
	var texts: PackedStringArray = _row_texts(view)
	ok = _check("the scene's own bar comes first", texts[0] if texts.size() > 0 else "",
		"⇥ | opened_scene_level.tscn | a | Node2D | 3 scripts") and ok
	# The bar is the script's own Include bar wearing the NODE's name, so it keeps everything that bar
	# already says about a file - the reading-coverage chip included.
	ok = _check("each script sits under its object bar, named by its NODE",
		_first_containing(texts, "| HUD |"), "⇥ | HUD | a | CanvasLayer | · opened_scene_hud.gd | reads as events") and ok
	# The wiring the SCENE file holds, on a script that is not the scene root: before this, a child
	# node's handler had no way of knowing what wired it.
	ok = _check("a child node's scene wiring reads as its trigger",
		_first_containing(texts, "Add 1 to wave"), "➜ | On Timeout | Add 1 to wave") and ok
	return ok


## ── opening a scene never writes to it ───────────────────────────────────────────────────────────
static func _scene_file_untouched() -> bool:
	var before: String = FileAccess.get_file_as_string(SCENE_PATH)
	var scene_sheet: EventSheetResource = EventSheetSceneSheet.build(SCENE_PATH)
	var ok: bool = _check("the scene sheet cannot be saved over its scene",
		EventSheetSceneSheet.is_scene_sheet(scene_sheet), true)
	return _check("the scene file is byte-identical after opening it",
		FileAccess.get_file_as_string(SCENE_PATH), before) and ok


## Opens a file the way the dock opens a .gd: a read-only preview, which is reading mode.
static func _open(path: String) -> EventSheetViewport:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
	sheet.read_only = true
	var view := EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.set_sheet(sheet)
	view.set_reading_mode(true)
	return view


## Every row's text, one string per row, spans joined - the same reading the render harness prints.
static func _row_texts(view: EventSheetViewport) -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data == null:
			continue
		view._row_builder._ensure_event_spans(row_data)
		var parts: PackedStringArray = PackedStringArray()
		for span: SemanticSpan in row_data.spans:
			parts.append(span.text)
		texts.append(" | ".join(parts))
	return texts


static func _first_containing(texts: PackedStringArray, needle: String) -> String:
	for text: String in texts:
		if text.contains(needle):
			return text
	return ""


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("[FAIL] %s: expected %s, got %s" % [label, str(expected), str(actual)])
	return false
