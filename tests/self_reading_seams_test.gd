# EventForge - the shapes the plugin's own source is written in, opened as rows rather than code.
#
# Each fixture is one seam measured on the editor's own files, where a whole file (or one verb of
# it) came back as code blocks for a reason that had nothing to do with the code:
#
#   - a doc block with a bare `##` paragraph line was cut off the run as a prelude row, so the
#     function under it lifted with the doc riding on it as well - written twice, and the whole-file
#     check reverted every function in the file (563 of them in the row builder);
#   - two blank lines after a closing `]` arrive as a row of their own, and their count was dropped
#     before the documented function under them, so the gap came back as one line;
#   - a constructor or `_validate_property` stranded mid-file was skipped as engine structure,
#     though nothing regenerates either and the trailing run lifts both;
#   - a wired function that RETURNS a value cannot read as its trigger, and was left as code rather
#     than anchored as the function it also is;
#   - a pack source marks each verb with its own `@ace_icon`, loops with `@ace_looping`, and leaves
#     the call line to its builder - three lines the function could not carry back;
#   - and when one function still re-emits differently, only it stays code, not the whole file.
#
# Every fixture must also come back byte for byte: a reading that moved a byte is not a reading.
@tool
class_name SelfReadingSeamsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")

const DOC_AFTER_LITERAL: String = "extends RefCounted\n\nconst WORDS: Array[String] = [\n\t\"if \", \"for \",\n\t\"pass\"\n]\n\n\n## The first paragraph of the doc.\n##\n## And the second one.\nstatic func first_word(text: String) -> String:\n\treturn text.get_slice(\" \", 0)\n\n\n## Another documented helper.\nstatic func last_word(text: String) -> String:\n\treturn text.get_slice(\" \", 1)\n"

const DOC_AFTER_DICTIONARY: String = "extends RefCounted\n\nconst EDGES: Dictionary = {\n\t\"a\": 1,\n\t\"b\": 2\n}\n\n\n## True when the key is one of the edges.\nstatic func is_edge(key: String) -> bool:\n\treturn EDGES.has(key)\n"

const STRANDED_INIT: String = "extends SceneTree\n\nconst LIMIT: int = 3\n\n\nfunc _init() -> void:\n\tprint(LIMIT)\n\tquit(0)\n\n\nvar after: int = 0\n"

const STRANDED_VALIDATE: String = "@tool\nextends Resource\n\n@export var mode: int = 0\n\n\nfunc _validate_property(property: Dictionary) -> void:\n\tif property.name == \"mode\":\n\t\tproperty.usage = PROPERTY_USAGE_NO_EDITOR\n\n\nvar after: int = 0\n"

const WIRED_VALUE_RETURNER: String = "extends Node\n\nvar button: Button = null\n\n\nfunc _ready() -> void:\n\tbutton.pressed.connect(apply)\n\n\nfunc apply() -> bool:\n\treturn true\n\n\nvar after: int = 0\n"

const PACK_SOURCE_VERBS: String = "extends Node\n\nvar host: Node = null\n\n## Runs once per entry, in name order.\n## @ace_looping(entry)\n## @ace_name(\"For Each Entry\")\n## @ace_category(\"Codex\")\nfunc each_entry() -> Array:\n\treturn []\n\n## @ace_condition\n## @ace_name(\"Is Full\")\nfunc is_full() -> bool:\n\treturn false\n\n## Adds one effect.\n## @ace_action\n## @ace_icon(\"res://icon.svg\")\n## @ace_codegen_template(\"$Kit.add_one()\")\nfunc add_one() -> void:\n\tpass\n\nvar after: int = 0\n"

const ONE_BAD_SEAM: String = "extends Node\n\nsignal died\n\n@export var health: int = 100\n\n\n## @ace_category Combat\nfunc heal(amount: int) -> void:\n\thealth += amount\n\n\nfunc is_dead() -> bool:\n\treturn health <= 0\n\n\nfunc get_health() -> int:\n\treturn health\n"


static func run() -> bool:
	var passed: bool = true
	passed = SUPPORT.pins("self_reading_seams_test", [
		["a doc with a bare ## line under a list literal lifts both functions",
			_summary(DOC_AFTER_LITERAL), {"functions": ["first_word", "last_word"], "raw": [], "round_trips": true}],
		["two blanks after a closing } stay two before a documented function",
			_summary(DOC_AFTER_DICTIONARY), {"functions": ["is_edge"], "raw": [], "round_trips": true}],
		["a command tool's _init stranded mid-file anchors as its function",
			_summary(STRANDED_INIT), {"functions": ["_init"], "raw": [], "round_trips": true}],
		["a _validate_property stranded mid-file anchors as its function",
			_summary(STRANDED_VALIDATE), {"functions": ["_validate_property"], "raw": [], "round_trips": true}],
		["a wired function returning a value anchors as a function",
			_summary(WIRED_VALUE_RETURNER), {"functions": ["apply"], "raw": ["func _ready() -> void:"], "round_trips": true}],
		["a pack source's own verb lines all come back",
			_summary(PACK_SOURCE_VERBS), {"functions": ["add_one", "each_entry", "is_full"], "raw": [], "round_trips": true}],
		# The doc line above heal (`## @ace_category Combat`, no brackets) stays text, and its gap is
		# its own: heal no longer re-emits a second blank under it, so all three functions open.
		["a doc line left as text above a function keeps its gap, and every function opens",
			_summary(ONE_BAD_SEAM), {"functions": ["get_health", "heal", "is_dead"], "raw": [], "round_trips": true}],
	])
	var verbs: Dictionary = _functions_by_name(SUPPORT.reopen(PACK_SOURCE_VERBS))
	var looping: EventFunction = verbs.get("each_entry") as EventFunction
	var full: EventFunction = verbs.get("is_full") as EventFunction
	var added: EventFunction = verbs.get("add_one") as EventFunction
	passed = SUPPORT.pins("self_reading_seams_test", [
		["the looping verb keeps its iterator", looping.looping_iterator if looping != null else "", "entry"],
		["and reads as the condition it is picked as", ViewportRowBuilder.define_role_for(looping) if looping != null else "", "condition"],
		["a verb with no call line writes none back", full.no_codegen_annotation if full != null else false, true],
		["a verb with a call line still writes it", added.no_codegen_annotation if added != null else true, false],
		["a verb's own icon is kept when the class has none", added.ace_icon if added != null else "", "res://icon.svg"],
	]) and passed
	# A sheet authored in the editor never set the three, so its verbs emit exactly what they did.
	var authored: EventFunction = EventFunction.new()
	authored.function_name = "go"
	authored.expose_as_ace = true
	var sheet: EventSheetResource = EventSheetResource.new()
	passed = SUPPORT.check("self_reading_seams_test", "an authored verb still writes its action line and call line",
		SheetCompiler.emit_function_block_text(authored, sheet).split("\n").slice(0, 2),
		PackedStringArray(["## @ace_action", "## @ace_codegen_template(\"go()\")"])) and passed
	# And the wordless-row share counts a function as one row whichever pass lifted it: lifting the
	# same function at the file's end instead of anchoring it in place must not move the number.
	var trailing: EventSheetResource = EventSheetResource.new()
	trailing.functions.append(authored)
	var anchored: EventSheetResource = EventSheetResource.new()
	anchored.functions.append(authored)
	var anchor: FunctionAnchorRow = FunctionAnchorRow.new()
	anchor.function_name = "go"
	anchored.events.append(anchor)
	passed = SUPPORT.pins("self_reading_seams_test", [
		["a function lifted at the file's end is one row", int(EventSheetGenericRows.measure(trailing).get("rows", 0)), 1],
		["the same function anchored in place is one row", int(EventSheetGenericRows.measure(anchored).get("rows", 0)), 1],
	]) and passed
	return passed


## What one source opens as: the functions it lifted (sorted), the function headers left as code,
## and whether it re-emits byte for byte.
static func _summary(source: String) -> Dictionary:
	var sheet: EventSheetResource = SUPPORT.reopen(source)
	var names: Array = _functions_by_name(sheet).keys()
	names.sort()
	var raw: Array = []
	for row: Variant in sheet.events:
		if row is RawCodeRow:
			var code: String = (row as RawCodeRow).code
			if code.begins_with("func ") or code.begins_with("static func "):
				raw.append(code.split("\n")[0])
	sheet.external_source_path = "user://_self_reading_seams.gd"
	var emitted: String = SUPPORT.compile_output(sheet, "user://_self_reading_seams.gd")
	return {"functions": names, "raw": raw, "round_trips": emitted == source}


static func _functions_by_name(sheet: EventSheetResource) -> Dictionary:
	var found: Dictionary = {}
	if sheet == null:
		return found
	for entry: Variant in sheet.functions:
		if entry is EventFunction:
			found[(entry as EventFunction).function_name] = entry
	return found
