# Godot EventSheets - every code example in the two API guides is RUN, so a guide cannot drift again.
#
# The Building-on-EventSheets guide and the Custom Blocks guide teach by example, and an example that
# stopped working reads exactly like one that works. This test takes every gdscript block of both
# guides, writes it out as a script, and has a second process (guide_examples_child.gd) run each:
#
#   * a statement block is wrapped in a function, must parse, and must run with no script error;
#   * a class block (it declares `extends`, `class_name`...) must parse;
#   * a block kind (a whole one, or the `fields` / `emit` / `lift` fragment a use case shows) must
#     build and write its default row, and a kind with a `lift` must reopen that line as its own row.
#
# A block that names something the READER writes (`my_panel`, `_my_helper()`) gets a stand-in from
# STAND_INS, keyed by the block's first line: the declarations the reader would bring, and for a
# path or a node that does not exist here, a swap. The guide never grows for the test's sake. An
# entry the guide no longer has fails too, so the table can only shrink. The second process also has
# to end with exit code 0, which holds only while examples that register lambdas end cleanly.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "guide_examples_test"
const PARALLEL_UNSAFE := true
const GUIDES: PackedStringArray = ["res://docs/GUIDE-BUILDING-ON-EVENTSHEETS.md", "res://docs/GUIDE-CUSTOM-BLOCKS.md"]
const CHILD := "res://tests/guide_examples_child.gd"
## Stands in for a folder the reader's project would hold; replaced by the test's own folder.
const OWN_FOLDER := "%OWN%"

## First line of the block -> {"names": declarations the reader brings, "swap": [[from, to]]}.
const STAND_INS: Dictionary = {
	"var strip := EventSheetPopupUI.help_strip()": {"names": """var dialog_body: VBoxContainer = VBoxContainer.new()
var name_edit: LineEdit = LineEdit.new()
var scope_option: OptionButton = OptionButton.new()
var preview_variable: LocalVariable = LocalVariable.new()"""},
	"var probe := EventSheetPopupUI.probe_help_dialog(my_dialog_body)": {"names": """var my_dialog_body: Control = _my_dialog()
func _my_dialog() -> Control:
	var body: VBoxContainer = VBoxContainer.new()
	var field: LineEdit = LineEdit.new()
	var strip := EventSheetPopupUI.help_strip()
	strip.follow(field, "Name", "What it is called.")
	body.add_child(field)
	body.add_child(strip)
	return body"""},
	"# GDScript in, sheet out, the compiled text back - and nothing written anywhere.": {"names": "var source_text: String = \"extends Node\\n\""},
	"# The live Inspector mock (decor, group heading, widget miniature, plain sentence) as a Control.": {"names": """var my_panel: Control = Control.new()
var my_local_variable: LocalVariable = LocalVariable.new()
var my_block_row: CustomBlockRow = CustomBlockRow.new()
var my_group: EventGroup = EventGroup.new()
var sheet: EventSheetResource = EventSheets.open_gd_as_sheet("extends Node\\n\\n@export var hp: int = 100\\n")"""},
	"# Run the whole audit (dock-free; usable from CI scripts and tests).": {"names": "func _uses_my_pack_without_a_table(_path: String) -> bool:\n\treturn false"},
	"# Translate any display string (English default; falls back to the source text).": {"names": """class _Canvas:
	func draw_string(_font: Font, _at: Vector2, _text: String) -> void:
		pass
var canvas: _Canvas = _Canvas.new()
var font: Font = ThemeDB.fallback_font
var position: Vector2 = Vector2.ZERO""", "swap": [["res://addons/my_pack/translations/my_pack.csv", "res://addons/eventsheet/translations/de.csv"]]},
	"# Generate the seam pair for a set of fields (keys drop a leading underscore, collections": {"swap": [
		["res://addons/my_pack/hoard.gd", "res://eventsheet_addons/health/health_behavior.gd"], ["$Enemy", "Node.new()"]]},
	"# headless: godot --headless --path . --script ci_check.gd": {"names": "func quit(_code: int = 0) -> void:\n\tpass"},
	"EventSheets.register_doctor_check(\"dialogue.missing_files\", func(sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:": {"names": "func _references_missing_dialogue(_path: String) -> bool:\n\treturn false"},
	"ok = _check(\"my block round-trips\", EventSheets.round_trips(fixture_source), true) and ok": {"names": """var ok: bool = true
var fixture_source: String = "extends Node\n"
func _check(_label: String, got: Variant, wanted: Variant) -> bool:
	return got == wanted"""},
	"EventSheets.edit(\"Halve Sound Volumes\", func(sheet: EventSheetResource) -> bool:": {"names": "func _halve_volumes_in(_row: Resource) -> bool:\n\treturn false"},
	"for definition: ACEDefinition in EventSheets.class_vocabulary(\"CharacterBody2D\"):": {"names": "var list: ItemList = ItemList.new()"},
	"EventSheets.register_palette_command(\"Strip Debug Prints\", func() -> void:": {"names": "func _is_debug_print(_row: Resource) -> bool:\n\treturn false"},
	"var result: Dictionary = EventSheets.echo(_canonical_weapon_sheet())": {"names": """var ok: bool = true
var _golden_weapon_source: String = EventSheets.echo(_canonical_weapon_sheet())["output"]
func _canonical_weapon_sheet() -> EventSheetResource:
	return EventSheets.open_gd_as_sheet("extends Node\\n\\nvar ammo: int = 6\\n")
func _check(_label: String, got: Variant, wanted: Variant) -> bool:
	return got == wanted"""},
	"var attrs: Dictionary = {\"range\": {\"min\": \"0\", \"max\": \"1\"}, \"drawer\": \"progress_bar\", \"header\": \"Loot\"}": {"names": """class _Dialog extends Control:
	var hint_label: Label = Label.new()
var dialog: _Dialog = _Dialog.new()"""},
	"EventSheets.edit(\"Migrate Inventory Verbs\", func(sheet: EventSheetResource) -> bool:": {"names": "func _rewrite_legacy_inventory_ace(_row: Resource) -> bool:\n\treturn false"},
	"# headless: godot --headless --path . --script roundtrip_sweep.gd": {"names": """func quit(_code: int = 0) -> void:
	pass
func _all_sheet_scripts() -> PackedStringArray:
	return PackedStringArray(["res://tests/fixtures/auto_ace_sample.gd"])"""},
	"EventSheets.register_param_editor(\"wave_id\", func(param: Dictionary, initial_text: String) -> LineEdit:": {"names": "func _open_wave_picker(_field: LineEdit) -> void:\n\tpass"},
	"EventSheets.register_row_menu_item(\"Go to Target State\",": {"names": "func _focus_state(_state: String) -> void:\n\tpass"},
	"var shipped: Dictionary = EventSheets.pack_shipped_assets(": {"swap": [["install_pack_effect(str(shipped[\"shader\"]))", "install_pack_effect(str(shipped[\"shader\"]), \"%OWN%\")"]]},
	"# In the dialogue plugin's _enter_tree:": {"names": """class DialogueCueBlockKind extends EventSheetBlockKind:
	func _init() -> void:
		kind_id = "dialogue.cue\""""},
	"EventSheets.register_doctor_check(\"my_pack.requirements\", _check_scene_requirements)": {"names": "func _check_scene_requirements(_paths: PackedStringArray, _findings: Array[Dictionary]) -> void:\n\tpass"},
}


static func run() -> bool:
	var ok: bool = true
	var folder: String = SUPPORT.own_path("guide_examples")
	DirAccess.make_dir_recursive_absolute(folder)
	var manifest: PackedStringArray = PackedStringArray()
	var labels: Dictionary = {}
	var used: Dictionary = {}
	var count: int = 0
	for guide: String in GUIDES:
		for block: Dictionary in blocks_of(FileAccess.get_file_as_string(guide)):
			count += 1
			var label: String = "%s:%d" % [guide.get_file(), int(block["line"])]
			labels[str(count)] = label
			var stand_in: Dictionary = STAND_INS.get(str(block["first"]).strip_edges(), {})
			if not stand_in.is_empty():
				used[str(block["first"]).strip_edges()] = true
			var path: String = "%s/example_%d.gd" % [folder, count]
			var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
			file.store_string(script_of(block, stand_in, count).replace(OWN_FOLDER, folder))
			file.close()
			manifest.append("%d|%s|%s" % [count, kind_of(block), path])
	var manifest_path: String = "%s/manifest.txt" % folder
	var manifest_file: FileAccess = FileAccess.open(manifest_path, FileAccess.WRITE)
	manifest_file.store_string("\n".join(manifest))
	manifest_file.close()
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", ProjectSettings.globalize_path(CHILD), "--", ProjectSettings.globalize_path(manifest_path)], output, true)
	var verdicts: Dictionary = {}
	for line: String in str(output[0]).split("\n"):
		if line.begins_with("GUIDE|"):
			var parts: PackedStringArray = line.strip_edges().split("|")
			verdicts[parts[1]] = parts[2]
	for number: String in labels:
		ok = SUPPORT.check(P, "%s runs" % labels[number], str(verdicts.get(number, "was never run")), "ok") and ok
	ok = SUPPORT.check(P, "the second process ends with exit code 0", code, 0) and ok
	ok = SUPPORT.check(P, "the guides hold their examples", count > 60, true) and ok
	for first: String in STAND_INS:
		ok = SUPPORT.check(P, "the stand-in for \"%s\" is still wanted by a block" % first.left(50), used.has(first), true) and ok
	return ok


## Every gdscript block as {line, text, class_shaped, first}.
static func blocks_of(markdown: String) -> Array:
	var out: Array = []
	var lines: PackedStringArray = markdown.split("\n")
	var index: int = 0
	var shaped: RegEx = RegEx.create_from_string("^(@tool|extends |class_name |func |static func |signal |class )")
	while index < lines.size():
		if lines[index].strip_edges() != "```gdscript":
			index += 1
			continue
		var start: int = index + 1
		var end: int = start
		while end < lines.size() and not lines[end].begins_with("```"):
			end += 1
		var body: PackedStringArray = lines.slice(start, end)
		var class_shaped: bool = false
		for line: String in body:
			if shaped.search(line) != null:
				class_shaped = true
		out.append({"line": index + 1, "text": "\n".join(body), "class_shaped": class_shaped,
			"first": body[0] if not body.is_empty() else ""})
		index = end + 1
	return out


## "kind" for a block kind (or the fragment of one), "class" for any other whole script, else "statement".
static func kind_of(block: Dictionary) -> String:
	if not bool(block["class_shaped"]):
		return "statement"
	var text: String = str(block["text"])
	if text.contains("func emit(") and (text.contains("extends EventSheetBlockKind") or not text.contains("extends ")):
		return "kind"
	return "class"


## The script the block becomes.
static func script_of(block: Dictionary, stand_in: Dictionary, number: int) -> String:
	var text: String = str(block["text"])
	for swap: Array in stand_in.get("swap", []):
		text = text.replace(str(swap[0]), str(swap[1]))
	var names: String = str(stand_in.get("names", ""))
	match kind_of(block):
		"kind":
			if text.contains("extends "):
				return text
			var header: String = "@tool\nextends EventSheetBlockKind\n\n%s\n\n" % names
			if not text.contains("func _init("):
				header += "func _init() -> void:\n\tkind_id = \"guide.example_%d\"\n\ttitle = \"Guide example\"\n\n" % number
			return header + text + "\n"
		"class":
			return text if text.contains("extends ") else "extends RefCounted\n" + text + "\n"
	var indented: PackedStringArray = PackedStringArray()
	for line: String in text.split("\n"):
		indented.append(("\t" + line) if not line.strip_edges().is_empty() else "")
	return "extends RefCounted\n\n%s\n\nfunc run() -> void:\n%s\n\tpass\n" % [names, "\n".join(indented)]
