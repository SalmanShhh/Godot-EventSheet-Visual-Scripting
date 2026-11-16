# Godot EventSheets - the API does what its words say, and every shape added to it is pinned.
#
# Each block below is one promise of the extension API that had no test:
#   block kinds   a kind can say "nothing to write for this row" and the compile still succeeds
#   the compiler  a sheet with no file and no output path writes no stray script
#   unregister    everything an extension can register can be taken back
#   language      an empty string goes back to following Godot's editor language
#   open_sheet    a file that is not there is refused; a file already open is brought forward, not opened twice
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "api_keeps_its_word_test"
const STRAY := "res://event_sheet_generated.gd"


class QuietKind extends EventSheetBlockKind:
	func _init() -> void:
		kind_id = "keeps_its_word.quiet"
		title = "Quiet"

	func fields() -> Array[Dictionary]:
		return [{"id": "on", "label": "On", "type": TYPE_BOOL, "default": false}]

	func emit(block: CustomBlockRow) -> PackedStringArray:
		return PackedStringArray(["# quiet"]) if bool(block.fields.get("on", false)) else PackedStringArray()

	func writes_nothing(block: CustomBlockRow) -> bool:
		return not bool(block.fields.get("on", false))


class MutedKind extends EventSheetBlockKind:
	func _init() -> void:
		kind_id = "keeps_its_word.muted"
		title = "Muted"

	func fields() -> Array[Dictionary]:
		return [{"id": "on", "label": "On", "type": TYPE_BOOL, "default": false}]


static func run() -> bool:
	var ok: bool = true
	ok = _writes_nothing() and ok
	ok = _stray_file() and ok
	ok = _open_sheet() and ok
	ok = _language() and ok
	ok = _unregister_set() and ok
	return ok


static func _compile_block(kind_id: String, fields: Dictionary) -> Dictionary:
	var sheet: EventSheetResource = EventSheets.new_sheet()
	var row: CustomBlockRow = CustomBlockRow.new()
	row.kind_id = kind_id
	row.fields = fields
	sheet.events.append(row)
	return EventSheets.echo(sheet)


static func _writes_nothing() -> bool:
	EventSheets.register_block_kind(QuietKind.new())
	EventSheets.register_block_kind(MutedKind.new())
	var quiet_off: Dictionary = _compile_block("keeps_its_word.quiet", {"on": false})
	var quiet_on: Dictionary = _compile_block("keeps_its_word.quiet", {"on": true})
	# A kind that does not say so still fails the compile when its row with fields writes nothing.
	var silent: Dictionary = _compile_block("keeps_its_word.muted", {"on": true})
	return SUPPORT.pins(P, [
		["a kind that says it writes nothing for this row compiles", quiet_off.get("success"), true],
		["and the same kind switched on writes its line", (quiet_on.get("output", "") as String).contains("# quiet"), true],
		["a kind that does not say so still fails when it writes nothing", silent.get("success"), false],
		["the kind base class has the hook, default false", EventSheetBlockKind.new().writes_nothing(CustomBlockRow.new()), false],
	])


static func _stray_file() -> bool:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(STRAY))
	var result: Dictionary = EventSheetCompiler.compile(EventSheets.new_sheet())
	var wrote: bool = FileAccess.file_exists(STRAY)
	var helper: String = SUPPORT.compile_output(EventSheets.new_sheet())
	var helper_wrote: bool = FileAccess.file_exists(STRAY)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(STRAY))
	return SUPPORT.pins(P, [
		["the compiler writes no stray script for a sheet with no file", wrote, false],
		["and says why it wrote nothing", (result.get("warnings", []) as Array).size() > 0, true],
		["the text is still in the result", str(result.get("output", "")).is_empty(), false],
		["the test helper's compile_output writes none either", helper_wrote, false],
		["and still returns the text", helper.is_empty(), false],
	])


static func _dock() -> EventSheetDock:
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(EventSheets.new_sheet())
	return dock


static func _open_sheet() -> bool:
	var dock: EventSheetDock = _dock()
	var missing: bool = EventSheets.open_sheet("res://no_such_folder/no_such_sheet.gd")
	var missing_tres: bool = EventSheets.open_sheet("res://no_such_folder/no_such_sheet.tres")
	var tabs_after_missing: int = dock._open_tabs.size()
	# A file already open in a tab: the call brings that tab forward and opens no second one.
	var path: String = "res://tests/fixtures/auto_ace_sample.gd"
	var held: EventSheetResource = EventSheets.new_sheet()
	held.external_source_path = path
	dock._open_tabs.append({"sheet": held, "path": path})
	var tabs_before: int = dock._open_tabs.size()
	var opened: bool = EventSheets.open_sheet(path)
	var tabs_after: int = dock._open_tabs.size()
	dock.free()
	return SUPPORT.pins(P, [
		["open_sheet refuses a .gd that is not there", missing, false],
		["open_sheet refuses a .tres that is not there", missing_tres, false],
		["a refused path opens no tab", tabs_after_missing, 1],
		["open_sheet on an open file says it worked", opened, true],
		["and opens no second tab for it", tabs_after, tabs_before],
	])


static func _language() -> bool:
	var catalogs: PackedStringArray = PackedStringArray(EventSheetL10n._catalogs.keys())
	var wanted: String = "de" if catalogs.has("de") else ""
	EventSheets.set_editor_language("ja" if catalogs.has("ja") else "de")
	var pinned: String = EventSheetL10n.get_locale()
	# The editor's own language, handed in because a headless run has none of its own (always English).
	EventSheetL10n.follow_editor_language("de")
	var followed: String = EventSheetL10n.get_locale()
	EventSheets.set_editor_language("")
	var empty_means_editor: String = EventSheetL10n.get_locale()
	var english: String = EventSheetL10n.locale_for_editor_language(EventSheetL10n.editor_language(), catalogs)
	EventSheets.set_editor_language("en")
	return SUPPORT.pins(P, [
		["a language was chosen first", pinned != "en", true],
		["following an editor language of de speaks de", followed, wanted if not wanted.is_empty() else "en"],
		["an empty string goes back to the editor's language", empty_means_editor, english],
	])


static func _has_method(name: String) -> bool:
	return (load("res://addons/eventsheet/api/eventsheets.gd") as Script).get_script_method_list().any(func(m: Dictionary) -> bool: return m["name"] == name)


static func _unregister_set() -> bool:
	var names: PackedStringArray = PackedStringArray(["unregister_starter", "unregister_preference", "off_sheet_opened", "off_sheet_saved", "off_sheet_compiled", "unregister_quick_add_synonyms", "unregister_section_description", "unregister_asset_drop_handler", "unregister_simple_ace", "unregister_editor_gizmo"])
	var missing: PackedStringArray = PackedStringArray()
	for method_name: String in names:
		if not _has_method(method_name):
			missing.append(method_name)
	var api: Script = load("res://addons/eventsheet/api/eventsheets.gd")
	var rows: Array = [["every unregister call exists", ", ".join(missing), ""]]
	if not missing.is_empty():
		return SUPPORT.pins(P, rows)
	# starters
	EventSheets.register_starter({"label": "Keeps Its Word Starter", "build": func() -> EventSheetResource: return null})
	var starter_in: bool = EventSheets.registered_starters().any(func(e: Dictionary) -> bool: return e.get("label") == "Keeps Its Word Starter")
	api.call("unregister_starter", "Keeps Its Word Starter")
	var starter_out: bool = EventSheets.registered_starters().any(func(e: Dictionary) -> bool: return e.get("label") == "Keeps Its Word Starter")
	rows.append(["a starter is registered", starter_in, true])
	rows.append(["and taken back by its label", starter_out, false])
	# preference builders
	var builder: Callable = func() -> Control: return null
	EventSheets.register_preference(builder)
	var pref_in: bool = EventSheets.preference_builders().has(builder)
	api.call("unregister_preference", builder)
	rows.append(["a preference is registered", pref_in, true])
	rows.append(["and taken back by its builder", EventSheets.preference_builders().has(builder), false])
	# lifecycle listeners
	var seen: Array = []
	var listener: Callable = func(payload: Dictionary) -> void: seen.append(payload)
	for pair: Array in [["on_sheet_opened", "off_sheet_opened", "opened"], ["on_sheet_saved", "off_sheet_saved", "saved"], ["on_sheet_compiled", "off_sheet_compiled", "compiled"]]:
		api.call(pair[0], listener)
		EventSheets._notify_lifecycle(pair[2], {"n": 1})
		api.call(pair[1], listener)
		EventSheets._notify_lifecycle(pair[2], {"n": 2})
	rows.append(["a listener hears each event while registered, and not after off_", seen.map(func(p: Dictionary) -> int: return int(p["n"])), [1, 1, 1]])
	# synonyms
	EventSheets.register_quick_add_synonyms({"keeps its word phrase": "dash"})
	var synonym_in: bool = ACEPickerDialog._extra_synonyms.has("keeps its word phrase")
	api.call("unregister_quick_add_synonyms", PackedStringArray(["Keeps Its Word Phrase"]))
	rows.append(["a synonym is registered", synonym_in, true])
	rows.append(["and taken back by its phrase, in any case", ACEPickerDialog._extra_synonyms.has("keeps its word phrase"), false])
	# section descriptions: a new one goes, an overridden built-in comes back
	var built_in: String = EventSheetSectionInfo.description_for("Debug")
	EventSheets.register_section_description("Keeps Its Word Section", "words")
	EventSheets.register_section_description("Debug", "replaced")
	api.call("unregister_section_description", "Keeps Its Word Section")
	api.call("unregister_section_description", "Debug")
	rows.append(["a section description is taken back", EventSheetSectionInfo.has("Keeps Its Word Section"), false])
	rows.append(["and a built-in one it replaced comes back", EventSheetSectionInfo.description_for("Debug"), built_in])
	# asset drop handlers: a new extension goes, an overridden built-in comes back
	var drop: Callable = func(_path: String, _target: Variant) -> Resource: return null
	EventSheets.register_asset_drop_handler(PackedStringArray(["keepsword", "json"]), drop)
	var drop_in: bool = EventSheets.asset_drop_builder_for("keepsword").is_valid()
	api.call("unregister_asset_drop_handler", PackedStringArray([".keepsword", "json"]))
	rows.append(["an asset drop handler is registered", drop_in, true])
	rows.append(["and taken back, a leading dot allowed", EventSheets.asset_drop_builder_for("keepsword").is_valid(), false])
	rows.append(["a built-in handler it replaced comes back", EventSheets.asset_drop_builder_for("json").is_valid() and EventSheets.asset_drop_builder_for("json") != drop, true])
	# simple aces
	EventSheets.register_simple_ace({"id": "KeepsItsWordAce", "display_name": "Keeps", "template": "pass", "kind": "action"})
	var ace_in: bool = EventSheets.simple_aces().any(func(a: ACEDefinition) -> bool: return a.id == "KeepsItsWordAce")
	api.call("unregister_simple_ace", "KeepsItsWordAce")
	rows.append(["a simple verb is registered", ace_in, true])
	rows.append(["and taken back by its id", EventSheets.simple_aces().any(func(a: ACEDefinition) -> bool: return a.id == "KeepsItsWordAce"), false])
	# editor gizmos
	EventSheets.register_editor_gizmo("res://keeps_its_word.gd", func(_p: Dictionary, _h: Node, _c: Control) -> void: pass)
	var gizmo_in: bool = EventSheets.editor_gizmo_drawer_for("res://keeps_its_word.gd").is_valid()
	api.call("unregister_editor_gizmo", "res://keeps_its_word.gd")
	rows.append(["a gizmo drawer is registered", gizmo_in, true])
	rows.append(["and taken back by its script path", EventSheets.editor_gizmo_drawer_for("res://keeps_its_word.gd").is_valid(), false])
	return SUPPORT.pins(P, rows)
