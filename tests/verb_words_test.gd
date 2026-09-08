@tool
class_name VerbWordsTest
extends RefCounted

# EventForge - the VERB half of the words seam (Menu > Tools > Words, the preset row).
#
# The nouns table has been a per-user choice for a while; this is the same reversible idea over a
# handful of VERBS, so a reader arriving from another event-sheet editor meets their own sentences
# on the first row rather than only in the picker's search.
#
# Six promises, in the order they matter:
#   1. every alias key names something that actually ships - a verb in the registry, or a reading
#      the editor composes - so an alias can never point at a verb that has been retired;
#   2. the "off" side of every alias is the SHIPPED wording, character for character, so switching
#      the second vocabulary off is a return rather than a second rewording;
#   3. a real row rendered through the real viewport reads the alias with the vocabulary on and the
#      shipped words with it off, and nothing but the opening words moves;
#   4. the picker answers to EITHER name;
#   5. the preset row reads the switches rather than remembering a choice of its own;
#   6. the sheet's own bytes are identical either way - an alias is display text and nothing else.
#
# The switch is a session-wide static, so it is put back after every block below - not once at
# the end, where a block that died half way through would have stepped over it.

const SUPPORT := preload("res://tests/support.gd")

const SOURCE_PATH := "user://eventforge_verb_words.gd"

## A hand-written file whose lines the reading layer claims - the every-tick switch is the one the
## alias table renames. Written here rather than kept as a fixture for the reason its sibling
## reading tests give: the byte gate compares against what the COMPILER would emit, and the
## compiler puts one blank line between functions.
const SOURCE: String = """extends Node2D

func _ready() -> void:
	set_process(false)

func _process(_delta: float) -> void:
	set_physics_process(true)
"""


static func run() -> bool:
	var all_passed: bool = true
	for block: Callable in [
			_keys_name_shipped_things,
			_off_side_is_the_shipped_wording,
			_a_row_reads_both_ways,
			_a_lifted_row_reads_both_ways,
			_the_picker_answers_to_either_name,
			_the_preset_reads_the_switches,
			_the_bytes_are_the_same_either_way,
	]:
		all_passed = bool(block.call()) and all_passed
		# The switch lives in a static for the SESSION, so it is put back after every block
		# rather than once at the end. A block that dies half way through - the silent shape a
		# runtime error takes here - used to leave the second vocabulary on, and every reading
		# every later test in the process took was re-worded by it. Off is the default and the
		# default is what the rest of the suite expects.
		EventSheetWords.set_verb_words_enabled(false)
	return all_passed


## 1. No alias points at a stranger. A verb key is looked up in the registry; a reading key is held
## against the reading tables themselves, so neither list is written down twice.
static func _keys_name_shipped_things() -> bool:
	var known_readings: Array[String] = _reading_keys()
	var strangers: Array[String] = []
	for key: String in EventSheetWords.verb_alias_keys():
		if key.begins_with("reading:"):
			if not known_readings.has(key):
				strangers.append(key)
			continue
		var parts: PackedStringArray = key.split("::")
		if parts.size() != 2 or ACERegistry.find_descriptor(parts[0], parts[1]) == null:
			strangers.append(key)
	var none: Array[String] = []
	return _check("every alias key names a shipped verb or a reading the editor composes",
		strangers, none)


## Every reading key the editor could honestly carry an alias for, derived from the reading layer's
## own tables rather than listed again here: the process switches the grammar words, and the
## collection kinds a pick filter loops over.
static func _reading_keys() -> Array[String]:
	var out: Array[String] = []
	for method: String in EventSheetSentence.PROCESS_SWITCH_WORDS:
		out.append("reading:%s:on" % method)
		out.append("reading:%s:off" % method)
	for kind: String in PickFilter.CollectionKind.keys():
		out.append("reading:pick_filter:%s" % kind)
	out.sort()
	return out


## 2. The "off" side is the shipped wording, taken from the registry and from the reading tables.
static func _off_side_is_the_shipped_wording() -> bool:
	var rows: Array = []
	for key: String in EventSheetWords.verb_alias_keys():
		if key.begins_with("reading:"):
			continue
		var parts: PackedStringArray = key.split("::")
		var descriptor: ACEDescriptor = ACERegistry.find_descriptor(parts[0], parts[1])
		if descriptor == null:
			continue
		var shipped_name: String = EventSheetWords.verb_shipped_name(key)
		if not shipped_name.is_empty():
			rows.append(["%s keeps the verb's shipped name on the off side" % key,
				descriptor.display_name, shipped_name])
		var head: String = EventSheetWords.verb_shipped_row(key)
		if not head.is_empty():
			rows.append(["%s opens on the row's own shipped words" % key,
				descriptor.get_display_text().substr(0, head.length()), head])
	var switch_word: String = str(EventSheetSentence.PROCESS_SWITCH_WORDS["set_process"])
	rows.append(["the every-tick switch turned on is the sentence the grammar writes",
		EventSheetWords.verb_shipped_row("reading:set_process:on"),
		"Set %s activated" % switch_word])
	rows.append(["and turned off is the other one",
		EventSheetWords.verb_shipped_row("reading:set_process:off"),
		"Set %s deactivated" % switch_word])
	rows.append(["a family loop's shipped word is the one the row builder writes",
		EventSheetWords.verb_shipped_row("reading:pick_filter:GROUP"), "group"])
	return SUPPORT.pins("verb_words_test", rows)


## 3. One picked row, rendered through the real viewport twice: the shipped words with the second
## vocabulary off, the alias with it on, and everything after the opening words untouched.
static func _a_row_reads_both_ways() -> bool:
	EventSheetWords.set_verb_words_enabled(false)
	var shipped: String = _spawn_row_reading()
	EventSheetWords.set_verb_words_enabled(true)
	var aliased: String = _spawn_row_reading()
	EventSheetWords.set_verb_words_enabled(false)
	var shipped_head: String = "Spawn a copy of"
	var alias_head: String = "Create object"
	var all_passed: bool = true
	all_passed = _check("the row opens on the shipped words with the second vocabulary off",
		shipped.substr(0, shipped_head.length()), shipped_head) and all_passed
	all_passed = _check("and on the second vocabulary's with it on",
		aliased.substr(0, alias_head.length()), alias_head) and all_passed
	all_passed = _check("nothing but the opening words changes",
		aliased.substr(alias_head.length()), shipped.substr(shipped_head.length())) and all_passed
	return all_passed


## 4. A LIFTED row - a line somebody wrote by hand, read back by the grammar - says the two words
## the other editor uses for the same switch, and the shipped sentence with the vocabulary off.
static func _a_lifted_row_reads_both_ways() -> bool:
	EventSheetWords.set_verb_words_enabled(false)
	var shipped: PackedStringArray = _lifted_readings()
	EventSheetWords.set_verb_words_enabled(true)
	var aliased: PackedStringArray = _lifted_readings()
	EventSheetWords.set_verb_words_enabled(false)
	var switch_word: String = str(EventSheetSentence.PROCESS_SWITCH_WORDS["set_process"])
	var all_passed: bool = true
	all_passed = _check("the every-tick switch reads as the sheet's own sentence with it off",
		_holding(shipped, "Set %s" % switch_word), "Set %s deactivated" % switch_word) and all_passed
	all_passed = _check("and as the two words the other editor uses with it on",
		_holding(aliased, "Set disabled"), "Set disabled") and all_passed
	all_passed = _check("a switch the table does not name is untouched either way",
		_holding(aliased, "Set Every tick (physics)"), "Set Every tick (physics) activated") and all_passed
	return all_passed


## 5. The picker's search finds a verb by its alias, whichever vocabulary is switched on - and does
## not start guessing before there is a word to guess from.
static func _the_picker_answers_to_either_name() -> bool:
	var one: Array[String] = ["Core::SpawnNewCopy"]
	var touching: Array[String] = ["Core::IsTouchingGroup"]
	var none: Array[String] = []
	var all_passed: bool = true
	all_passed = _check("the other editor's word for a new instance finds the verb that makes one",
		ACEPickerDialog.alias_query_keys("create object"), one) and all_passed
	all_passed = _check("and its word for touching finds the touching condition",
		ACEPickerDialog.alias_query_keys("overlapping"), touching) and all_passed
	all_passed = _check("two letters is somebody still typing, not a search",
		ACEPickerDialog.alias_query_keys("cr"), none) and all_passed
	return all_passed


## 6. The preset row is a READING of the two switches, so it can never disagree with the sheet.
static func _the_preset_reads_the_switches() -> bool:
	EventSheetWords.set_verb_words_enabled(false)
	var all_passed: bool = true
	all_passed = _check("with neither switch on the page says Godot words",
		EventSheetWords.preset(), EventSheetWords.PRESET_GODOT) and all_passed
	EventSheetWords.set_verb_words_enabled(true)
	all_passed = _check("Godot's nouns wearing the other vocabulary's verbs is nobody's preset",
		EventSheetWords.preset(), EventSheetWords.PRESET_CUSTOM) and all_passed
	EventSheetWords.set_verb_words_enabled(false)
	var offered: Array[String] = ["godot", "familiar", "sheet", "custom"]
	all_passed = _check("the page offers three named vocabularies and the reading",
		EventSheetWords.PRESETS, offered) and all_passed
	all_passed = _check("the third is named for what it is",
		EventSheetWords.preset_label(EventSheetWords.PRESET_SHEET),
		"Event-sheet-editor words") and all_passed
	all_passed = _check("and the first for whose words they are",
		EventSheetWords.preset_label(EventSheetWords.PRESET_GODOT), "Godot words") and all_passed
	return all_passed


## 7. An alias is display text. The emitted GDScript, and the file a hand-written source round-trips
## back into, are identical whichever vocabulary is on.
static func _the_bytes_are_the_same_either_way() -> bool:
	EventSheetWords.set_verb_words_enabled(false)
	var shipped_words: String = SUPPORT.compile_output(_spawn_sheet())
	var shipped_trip: String = _round_trip_output()
	EventSheetWords.set_verb_words_enabled(true)
	var aliased_words: String = SUPPORT.compile_output(_spawn_sheet())
	var aliased_trip: String = _round_trip_output()
	EventSheetWords.set_verb_words_enabled(false)
	var all_passed: bool = true
	all_passed = _check("the emitted GDScript is the same in either vocabulary",
		aliased_words, shipped_words) and all_passed
	all_passed = _check("and a hand-written file still comes back byte for byte",
		aliased_trip, SOURCE) and all_passed
	all_passed = _check("as it did before the second vocabulary existed",
		shipped_trip, SOURCE) and all_passed
	return all_passed


## A one-row sheet holding the verb the alias table renames, filled with its own defaults.
static func _spawn_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = "VerbWordsProbe"
	sheet.host_class = "Node2D"
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", "SpawnNewCopy")
	var row: EventRow = EventRow.new()
	var action: ACEAction = ACEAction.new()
	action.provider_id = descriptor.provider_id
	action.ace_id = descriptor.ace_id
	action.params = descriptor.build_default_params()
	row.actions.append(action)
	sheet.events.append(row)
	return sheet


## That row's cell as the canvas draws it.
static func _spawn_row_reading() -> String:
	for text: String in _readings_of(_spawn_sheet()):
		if text.contains("Spawn a copy of") or text.contains("Create object"):
			return text
	return ""


## The hand-written source, opened as a sheet and read row by row.
static func _lifted_readings() -> PackedStringArray:
	_write_source()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SOURCE_PATH)
	sheet.read_only = true
	return _readings_of(sheet)


## The first reading holding this text, or "" - so a pin names the sentence rather than a position.
static func _holding(readings: PackedStringArray, wanted: String) -> String:
	for text: String in readings:
		if text.contains(wanted):
			return text
	return ""


## Every cell of every row, through a real viewport - the same walk the reading dump makes.
static func _readings_of(sheet: EventSheetResource) -> PackedStringArray:
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_ace_registry(EventSheetACERegistry.new())
	viewport.set_sheet(sheet)
	viewport.set_reading_mode(true)
	var out: PackedStringArray = PackedStringArray()
	for row_data: EventRowData in _walk(viewport._root_rows, viewport):
		for span: SemanticSpan in row_data.spans:
			var text: String = span.text.strip_edges()
			if not text.is_empty():
				out.append(text)
	viewport.free()
	return out


static func _walk(rows: Array, viewport: EventSheetViewport) -> Array:
	var found: Array = []
	for row_data: EventRowData in rows:
		viewport._row_builder._ensure_event_spans(row_data)
		found.append(row_data)
		found.append_array(_walk(row_data.children, viewport))
	return found


static func _round_trip_output() -> String:
	_write_source()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SOURCE_PATH)
	return SUPPORT.compile_output(sheet, SOURCE_PATH)


static func _write_source() -> void:
	var handle: FileAccess = FileAccess.open(SOURCE_PATH, FileAccess.WRITE)
	handle.store_string(SOURCE)
	handle.close()


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("verb_words_test", label, actual, expected)
