# Godot EventSheets - EVERY CALL ON A KNOWN CLASS IS A ROW, pinned as values.
#
# Six things are pinned here, and each of them is a claim the derived reading makes out loud:
#
#   1. WHO THE RECEIVER IS. A table of spellings and the class each one resolves to, with the
#      source it was answered from - and, just as important, the ones that resolve to NOTHING. A
#      receiver nothing can answer for must never be guessed at, so the refusals are pinned as
#      hard as the answers.
#   2. WHAT THE ROW SAYS. The words, the object column, and the argument chips named by the
#      method's own parameter names - which is the whole point of knowing the class.
#   3. THE TWO LAYERS LOOK DIFFERENT. The derived verb wears the derived tone and a curated
#      sentence's verb wears the bold `name`, on the same statement, so a reader can tell which
#      layer they are looking at without being told.
#   4. CURATED OUTRANKS, AND UPGRADES IN PLACE. One fixture line, read twice: once where a
#      curated recogniser claims it (the sentence layer answers and the derived layer is never
#      asked) and once where nothing does (the derived layer answers). Same line, same bytes,
#      two layers - which is what "landing a curated table later upgrades derived rows" means.
#   5. THE DOCS RIDE. An engine member's page id, a project method's `##` line as its hover, and
#      the credit riding with the engine's own prose because its licence says so.
#   6. THE PICKER'S DERIVED SECTION. One entry per declared method per object, with the target,
#      the method and the arguments already answered off the declaration.
#
# And the contract underneath all of it: a derived row IS the line it read, so a staged file full
# of them saves back byte-identical.
#
# SERIAL-CI HYGIENE. This warms the derived reader's per-file caches and the shared script reader's,
# and CI runs the suite serially in one process, so both are dropped on the way out and the staged
# script lives in user:// and is deleted - nothing is left in the repository.
@tool
class_name DerivedCallRowsTest
extends RefCounted

## A sheet that is really placed in a scene, for the shelf half: the room's script, whose scene
## holds a Hero wearing a script of its own.
const ROOM: String = "res://tests/fixtures/interop_corpus/room.gd"

## Where the staged script lives. user://, so a run leaves nothing under res://.
const STAGED_DIR: String = "user://derived_call_rows_staged"
const STAGED_SCRIPT: String = STAGED_DIR + "/beacon.gd"

## A project script with `##` lines above its own declarations - the words a derived row shows for a
## method the engine never heard of.
const STAGED_SOURCE: String = """extends Node2D


## Lights the beacon and holds it for a while.
func light(seconds: float = 2.0) -> void:
	visible = true


## Puts it out again.
func douse() -> void:
	visible = false


func _hidden_helper() -> void:
	pass
"""

## The sheet the readings are asked against: a body with a declared timer, an @onready bar and its
## own host class. Every fact a real sheet's context carries, spelled here so the table is readable.
const CONTEXT: Dictionary = {
	"self_object": "Player",
	"self_class": "CharacterBody2D",
	"self_script_path": "",
	"variable_types": {"beat": "Timer", "hp": "int", "crew": "Array[Node]", "bar": "ProgressBar"},
	"engine_properties": {"position": true, "visible": true},
	"signals": {},
	"signal_params": {},
}

## The object-label to class map the row builder hoists once per rebuild.
const CLASS_MAP: Dictionary = {"HpBar": "ProgressBar", "$HpBar": "ProgressBar",
	"Player": "CharacterBody2D"}


static func run() -> bool:
	var ok: bool = _test_who_the_receiver_is()
	ok = _test_what_the_row_says() and ok
	ok = _test_the_two_layers_look_different() and ok
	ok = _test_curated_outranks_and_upgrades_in_place() and ok
	ok = _test_the_docs_ride() and ok
	ok = _test_the_pickers_derived_section() and ok
	ok = _test_the_row_is_the_line() and ok
	_tidy_up()
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] derived_call_rows_test: %s" % label)
		return true
	print("[FAIL] derived_call_rows_test: %s - expected %s, got %s" % [label, expected, actual])
	return false


## 1. The receiver, and the refusals. `<class> via <source>` for a resolved one, "" for a receiver
## the sheet cannot honestly answer for.
static func _test_who_the_receiver_is() -> bool:
	var ok: bool = true
	for pair: Array in [
		["", "CharacterBody2D via self"],
		["self", "CharacterBody2D via self"],
		["$HpBar", "ProgressBar via node"],
		["HpBar", "ProgressBar via node"],
		["beat", "Timer via declared"],
		["bar", "ProgressBar via declared"],
		["Timer", "Timer via class"],
		# The refusals. An int is not a receiver; a typed array names what is INSIDE it, not what a
		# method would be called on; a name the file never declares is somebody else's object.
		["hp", ""],
		["crew", ""],
		["whatever", ""],
		["get_parent()", ""],
	]:
		var facts: Dictionary = EventSheetDerivedCalls.receiver_facts(
			str(pair[0]), CONTEXT, CLASS_MAP, {})
		var said: String = "" if facts.is_empty() \
			else "%s via %s" % [str(facts.get("class", "")), str(facts.get("source", ""))]
		ok = _check("receiver \"%s\" is %s" % [str(pair[0]),
			"nothing this can name" if str(pair[1]).is_empty() else str(pair[1])],
			said, str(pair[1])) and ok
	return ok


## 2. The words. Object, then the sentence, with the chips named by the method's own parameters -
## the fact the class was worth knowing for.
static func _test_what_the_row_says() -> bool:
	var ok: bool = true
	for pair: Array in [
		["beat.start(2.0)", "beat ▸ Start   time_sec = 2"],
		["$HpBar.set_value_no_signal(40.0)", "HpBar ▸ Set value no signal to 40"],
		["self.move_and_slide()", "Player ▸ Move and slide"],
		# A method the class does not have is not the class's method, whatever it is spelled like.
		["beat.definitely_not_a_method(1)", ""],
		# And a receiver nothing named claims nothing, however ordinary the call looks.
		["whatever.do_thing(1)", ""],
	]:
		ok = _check("\"%s\" reads \"%s\"" % [str(pair[0]), str(pair[1])],
			_derived_text(str(pair[0])), str(pair[1])) and ok
	return ok


## 3. The two layers, side by side on the same statement. A curated sentence's verb is bold `name`;
## a derived one is the plainer derived tone. Nothing else about the pieces differs, which is the
## point: the words are real either way, and only the WEIGHT says which layer wrote them.
static func _test_the_two_layers_look_different() -> bool:
	var ok: bool = true
	# The verb is the head of every one of these readings, so its tone is the whole comparison.
	var derived: Dictionary = EventSheetDerivedCalls.derived_pieces(
		"beat.start(2.0)", CONTEXT, CLASS_MAP, {})
	ok = _check("a derived verb wears the derived tone",
		_first_tone(derived.get("pieces", []) as Array),
		EventSheetDerivedCalls.TONE_DERIVED) and ok
	ok = _check("a curated sentence's verb wears the ordinary sentence tone",
		_first_tone(_as_pieces(EventSheetSentence.statement("$AnimatedSprite2D.play(\"run\")", CONTEXT))),
		"plain") and ok
	# An unclaimed call - nothing curated, and a receiver nothing can name - keeps the bold verb it
	# always had. So the derived layer is the only one of the three drawn back from full weight, and
	# no reading anywhere else in the editor can wear its tone by accident.
	ok = _check("an unclaimed call keeps its bold verb",
		_first_tone(_as_pieces(EventSheetSentence.call_reading(
			"whatever.do_thing(1)", CONTEXT))), "name") and ok
	ok = _check("and nothing else emits the derived tone",
		_tones(_as_pieces(EventSheetSentence.statement("score += 1", CONTEXT))).has(
			EventSheetDerivedCalls.TONE_DERIVED), false) and ok
	# How far back it is drawn, pinned as a value: far enough to tell apart at a glance, not so far
	# that a file of derived rows reads as greyed out.
	ok = _check("the derived tone sits back from a curated one",
		ViewportRowBuilder.DERIVED_TONE_BLEND, 0.4) and ok
	return ok


## 4. One line, two layers. `$AnimatedSprite2D.play("run")` is claimed by a curated recogniser, so
## the sentence layer answers it and the derived layer is never reached - and the derived layer,
## asked directly, would have had words for it too. That is exactly the upgrade path: the day a
## curated table lands for a shape, its rows read the polished way with the file untouched.
static func _test_curated_outranks_and_upgrades_in_place() -> bool:
	var ok: bool = true
	var line: String = "$AnimatedSprite2D.play(\"run\")"
	var map: Dictionary = {"AnimatedSprite2D": "AnimatedSprite2D"}
	var curated: Dictionary = EventSheetSentence.statement(line, CONTEXT)
	ok = _check("the curated layer claims the fixture line", curated.is_empty(), false) and ok
	ok = _check("and says it the polished way",
		"%s ▸ %s" % [str(curated.get("object", "")), _joined(_as_pieces(curated))],
		"AnimatedSprite2D ▸ Set animation to \"run\" (play from beginning)") and ok
	var derived: Dictionary = EventSheetDerivedCalls.derived_pieces(line, CONTEXT, map, {})
	ok = _check("the derived layer has words for the same line too",
		"%s ▸ %s" % [str(derived.get("object", "")), _joined(derived.get("pieces", []) as Array)],
		"AnimatedSprite2D ▸ Play   name = \"run\"") and ok
	# The row builder asks the sentence layer FIRST and only reaches the derived layer when it came
	# back empty, so a line the curated layer claims can never be read the plainer way.
	ok = _check("the builder reaches the derived layer only where the curated one is silent",
		ViewportRowBuilder.statement_sentence(line, CONTEXT).is_empty(), false) and ok
	ok = _check("and it is silent on the line nothing curated claims",
		ViewportRowBuilder.statement_sentence("beat.start(2.0)", CONTEXT).is_empty(), true) and ok
	return ok


## 5. The words that ride with the row: the engine's page for a built-in member, the script's own
## `##` line for a method somebody wrote here, and the credit wherever the prose is the engine's.
static func _test_the_docs_ride() -> bool:
	var ok: bool = true
	ok = _check("an engine member's page is the engine reference's own id",
		EventSheetDerivedCalls.doc_id_for("Timer", "start"), "engine:Timer.start") and ok
	ok = _check("a class the engine does not have has no page",
		EventSheetDerivedCalls.doc_id_for("BeaconThatIsNotAClass", "light"), "") and ok
	_stage_script()
	var receiver: Dictionary = {"class": "", "script_path": STAGED_SCRIPT, "source": "declared"}
	var facts: Dictionary = EventSheetDerivedCalls.method_facts(receiver, "light")
	ok = _check("a project method's words are the `##` line above it",
		str(facts.get("doc", "")), "Lights the beacon and holds it for a while.") and ok
	ok = _check("its parameters are the declaration's own names",
		Array(facts.get("params", PackedStringArray())), ["seconds"]) and ok
	ok = _check("and nobody's prose is credited to the engine", str(facts.get("credit", "")), "") and ok
	# A private helper is not a method a row calls, so the file's own reader never offers it and the
	# derived layer therefore cannot claim a call to one.
	ok = _check("a private helper is not claimed",
		EventSheetDerivedCalls.method_facts(receiver, "_hidden_helper").is_empty(), true) and ok
	# What the script EXTENDS answers for everything it did not declare, so an ordinary engine verb
	# on a project script still reads - with the engine's credit on it when this machine has the
	# engine's words at all.
	var inherited: Dictionary = EventSheetDerivedCalls.method_facts(receiver, "queue_free")
	ok = _check("what the file extends answers for the rest",
		inherited.is_empty(), false) and ok
	ok = _check("and that member's page is the engine's",
		str(inherited.get("doc_id", "")), "engine:Node2D.queue_free") and ok
	ok = _check("a reading with no words said about it hovers as nothing extra",
		EventSheetDerivedCalls.hover_text({"doc": "", "credit": ""}), "") and ok
	ok = _check("and the engine's own words carry the credit its licence asks for",
		EventSheetDerivedCalls.hover_text({"doc": "Removes the node.",
			"credit": EventSheetDocEngineReference.CREDIT_LINE}),
		"Removes the node.\n%s" % EventSheetDocEngineReference.CREDIT_LINE) and ok
	return ok


## 6. The writing half: what the picker prefills a call with, read off the declaration.
static func _test_the_pickers_derived_section() -> bool:
	var ok: bool = true
	for pair: Array in [
		["seconds: float = 2.0", "2.0"],
		["amount: int, hard: bool", "0, false"],
		["name: String", "\"\""],
		["thing", "null"],
		["", ""],
	]:
		ok = _check("`(%s)` prefills `%s`" % [str(pair[0]), str(pair[1])],
			EventSheetScriptMembers.call_arguments(str(pair[0])), str(pair[1])) and ok
	_stage_script()
	var declared: Array = EventSheetScriptMembers.of_script(STAGED_SCRIPT)["methods"]
	var names: PackedStringArray = PackedStringArray()
	for entry: Variant in declared:
		names.append(str((entry as Dictionary).get("name", "")))
	ok = _check("the shelf offers the file's own methods and not its helpers",
		Array(names), ["light", "douse"]) and ok
	ok = _check("and each entry says what its author said about it",
		EventSheetScriptMembers.detail_of(declared[0] as Dictionary),
		"seconds: float = 2.0 · Lights the beacon and holds it for a while.") and ok
	# And the shelf itself, off a real sheet placed in a real scene: one Call Method entry per
	# method the node's own script declares, with everything a reader would have had to type in by
	# hand already answered.
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(ROOM)
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	registry.refresh_from_sources([] as Array[Object], true)
	var offered: Array[ACEDefinition] = ACEPickerDialog.scene_method_definitions(sheet, registry)
	var take_damage: ACEDefinition = _definition_named(offered, "Take damage")
	ok = _check("a scripted node's own method is an entry waiting to be picked",
		take_damage != null, true) and ok
	if take_damage != null:
		var prefill: Dictionary = take_damage.metadata.get(ACEPickerDialog.SCENE_PREFILL_META, {})
		ok = _check("aimed at the node it belongs to", str(prefill.get("target", "")), "$Hero") and ok
		ok = _check("naming the method the file declares",
			str(prefill.get("method", "")), "take_damage") and ok
		ok = _check("with the declaration's own arguments answered",
			str(prefill.get("args", "")), "null") and ok
		ok = _check("described with the script's own line",
			take_damage.description.contains("Takes a hit"), true) and ok
		ok = _check("filed under the methods shelf",
			str(take_damage.metadata.get(ACEPickerDialog.SCENE_GROUP_META, "")),
			ACEPickerDialog.METHODS_GROUP) and ok
	return ok


## The contract underneath the whole layer: a derived row IS the line it read. Nothing translates,
## so this cannot fail for a reason a reader would find interesting - which is exactly why it is
## worth proving on a real buffer rather than trusting the shape of the mechanism.
static func _test_the_row_is_the_line() -> bool:
	_stage_script()
	var reading: Dictionary = EventSheetLiftReading.read(STAGED_SOURCE, STAGED_SCRIPT)
	return _check("a file of derived rows saves back byte-identical",
		bool(reading.get("identical", false)), true)


# ── the pieces ──────────────────────────────────────────────────────────────────


## One statement's derived reading as "object ▸ words", or "" when the layer declined it.
static func _derived_text(code: String) -> String:
	var reading: Dictionary = EventSheetDerivedCalls.derived_pieces(code, CONTEXT, CLASS_MAP, {})
	if reading.is_empty():
		return ""
	return "%s ▸ %s" % [str(reading.get("object", "")), _joined(reading.get("pieces", []) as Array)]


static func _joined(pieces: Array) -> String:
	var text: String = ""
	for piece: Variant in pieces:
		text += str((piece as Array)[0])
	return text


## A grammar reading's segments in the row builder's own [text, tone] shape, so the two layers can
## be held against each other without either of them being reshaped for the comparison.
static func _as_pieces(reading: Dictionary) -> Array:
	var pieces: Array = []
	for entry: Variant in (reading.get("segments", []) as Array):
		var segment: Dictionary = entry
		pieces.append([str(segment.get("text", "")), str(segment.get("tone", "plain"))])
	return pieces


## The offered entry with one display name, or null when the shelf never grew it.
static func _definition_named(offered: Array[ACEDefinition], display_name: String) -> ACEDefinition:
	for definition: ACEDefinition in offered:
		if definition.display_name == display_name:
			return definition
	return null


## The tone of a reading's HEAD, which in all three of these shapes is the verb.
static func _first_tone(pieces: Array) -> String:
	return "" if pieces.is_empty() else str((pieces[0] as Array)[1])


## Every tone one reading uses, for the claim that a tone appears nowhere it should not.
static func _tones(pieces: Array) -> Array:
	var found: Array = []
	for piece: Variant in pieces:
		var tone: String = str((piece as Array)[1])
		if not found.has(tone):
			found.append(tone)
	return found


static func _stage_script() -> void:
	DirAccess.make_dir_recursive_absolute(STAGED_DIR)
	var handle: FileAccess = FileAccess.open(STAGED_SCRIPT, FileAccess.WRITE)
	if handle != null:
		handle.store_string(STAGED_SOURCE)
		handle.close()


## Drops what this warmed and deletes what it wrote, so the next test in a serial run starts where
## it would have started had this one never happened.
static func _tidy_up() -> void:
	EventSheetDerivedCalls.clear_cache()
	EventSheetScriptMembers.clear_cache()
	EventSheetLiftReading.clear_cache()
	DirAccess.remove_absolute(STAGED_SCRIPT)
	DirAccess.remove_absolute(STAGED_DIR)
