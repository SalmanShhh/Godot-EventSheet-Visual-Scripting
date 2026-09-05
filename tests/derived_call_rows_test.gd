# Godot EventSheets - EVERY CALL ON A KNOWN CLASS IS A ROW, pinned as values.
#
# Seven things are pinned here, and each of them is a claim the derived reading makes out loud:
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
#   7. WHAT IT COSTS. The layer runs once per statement at row-build time, so the thing worth
#      pinning is how often an answer is worked out AT ALL: once per distinct class and method,
#      refusals included, and never for a receiver nothing can name.
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
	ok = _test_a_shadowed_member_is_nobodys() and ok
	ok = _test_two_paths_ending_in_one_name() and ok
	ok = _test_what_it_costs() and ok
	_tidy_up()
	return ok


## The one thing the declared-type map cannot see: SCOPE. Its entries are the file's script-level
## declarations, and `func _on_body_entered(body):` against a member called `body` is the commonest
## handler shape in Godot - so without this the parameter would be read as the member's class and
## every row inside the handler would be named against a class the parameter is not. There is no
## scope in the map to tell them apart, so a name the file uses BOTH ways is answered for by nobody
## and the rows keep the plainer view they already had.
##
## ASKED OF THE MAPS THE CANVAS ASKS. The refusal is only worth anything if it holds against the real
## object-class map and the real sentence context: that map registers every @onready name with no
## shadow filter of its own, so a test that handed the reading an empty map would prove the guarded
## map and never touch the one the reading asks first.
##
## AND A BODY LOCAL SHADOWS JUST AS HARD AS A PARAMETER. `var sprite := $Other as AnimatedSprite2D`
## inside a function, beside an `@onready var sprite: Sprite2D`, is a warning in GDScript rather than
## an error - it compiles, and the rows under it are about the local.
static func _test_a_shadowed_member_is_nobodys() -> bool:
	var source: String = "\n".join(PackedStringArray([
		"extends Node2D",
		"",
		"@onready var body: CharacterBody2D = $Body",
		"@onready var beat: Timer = $Beat",
		"@onready var sprite: Sprite2D = $Sprite",
		"",
		"",
		"func _on_area_entered(body: Node2D) -> void:",
		"\tbody.rotate(0.5)",
		"",
		"",
		"func flash() -> void:",
		"\tvar sprite := $Other as AnimatedSprite2D",
		"\tsprite.play(\"hit\")",
		""
	]))
	var sheet: EventSheetResource = EventSheets.open_gd_as_sheet(source)
	var declared: Dictionary = EventSheetViewportReadingRows.declared_type_map(sheet)
	var shadowed: Dictionary = EventSheetViewportReadingRows.shadowed_name_set(sheet)
	var ok: bool = _check("a handler's own parameter names are known to the map",
		EventSheetViewportReadingRows.parameter_names_in(sheet).has("body"), true)
	ok = _check("and a var declared inside a body is known to it too", shadowed.has("sprite"),
		true) and ok
	ok = _check("so a member a parameter shadows is answered for by nobody",
		(declared.get("types", {}) as Dictionary).has("body"), false) and ok
	ok = _check("and a member a body local shadows either",
		(declared.get("types", {}) as Dictionary).has("sprite"), false) and ok
	ok = _check("while the member nothing shadows still answers",
		str((declared.get("types", {}) as Dictionary).get("beat", "")), "Timer") and ok
	# The maps the CANVAS asks, in the order it asks them: the object-class map carries every
	# @onready name whether or not something shadows it, so the refusal has to hold against it.
	var class_map: Dictionary = EventSheetViewportReadingRows.object_class_map(sheet)
	var context: Dictionary = EventSheetViewportReadingRows.sentence_context_extras(sheet)
	ok = _check("the object-class map still carries the member under its own name",
		str(class_map.get("body", "")), "CharacterBody2D") and ok
	ok = _check("and the derived reading declines the shadowed receiver all the same",
		EventSheetDerivedCalls.receiver_facts("body", context, class_map, {}), {}) and ok
	ok = _check("so the call inside the handler is claimed by nobody",
		EventSheetDerivedCalls.derived_pieces("body.rotate(0.5)", context, class_map, {}), {}) and ok
	ok = _check("and the call under the body local is claimed by nobody either",
		EventSheetDerivedCalls.derived_pieces("sprite.play(\"hit\")", context, class_map, {}),
		{}) and ok
	ok = _check("while the receiver nothing shadows still reads",
		str(EventSheetDerivedCalls.receiver_facts("beat", context, class_map, {}).get("class", "")),
		"Timer") and ok
	ok = _check("with the bytes untouched either way", EventSheets.round_trips(source), true) and ok
	return ok


## TWO PATHS THAT END IN THE SAME NAME ARE TWO NODES. `$Enemy/Sprite` and `$Player/Sprite` is the
## commonest scene shape there is, and reading the second off the first's declaration is a wrong
## claim rather than a missing one - the row would take a class the node has not got, and a verb that
## class answers to would be printed over a node that does not.
##
## Two halves, and both are pinned: the map stops handing the bare leaf out where two declarations
## disagree about it, and a receiver written as a path with a parent in it only ever resolves on its
## whole spelling.
static func _test_two_paths_ending_in_one_name() -> bool:
	var source: String = "\n".join(PackedStringArray([
		"extends Node2D",
		"",
		"@onready var enemy_sprite: AnimatedSprite2D = $Enemy/Sprite",
		"@onready var hp_bar: ProgressBar = %HpBar",
		"",
		"",
		"func hide_player() -> void:",
		"\t$Player/Sprite.hide()",
		""
	]))
	var sheet: EventSheetResource = EventSheets.open_gd_as_sheet(source)
	var class_map: Dictionary = EventSheetViewportReadingRows.object_class_map(sheet)
	var context: Dictionary = EventSheetViewportReadingRows.sentence_context_extras(sheet)
	var ok: bool = _check("the whole path resolves",
		str(class_map.get("$Enemy/Sprite", "")), "AnimatedSprite2D")
	ok = _check("and so does the same path without its sigil",
		str(class_map.get("Enemy/Sprite", "")), "AnimatedSprite2D") and ok
	ok = _check("a single-segment reference still reads under its bare name",
		str(class_map.get("HpBar", "")), "ProgressBar") and ok
	# The receiver half: the leaf is in the map (one declaration, nothing disagrees), and the OTHER
	# path is refused anyway, because a path with a parent written into it resolves whole or not at all.
	ok = _check("but another parent's child of that name is nobody's",
		EventSheetDerivedCalls.receiver_facts("$Player/Sprite", context, class_map, {}), {}) and ok
	ok = _check("so the row under it is not claimed",
		EventSheetDerivedCalls.derived_pieces("$Player/Sprite.hide()", context, class_map, {}),
		{}) and ok
	# The map half: two declarations that disagree about a leaf hand it to nobody.
	var two: String = "\n".join(PackedStringArray([
		"extends Node2D",
		"",
		"@onready var enemy_sprite: AnimatedSprite2D = $Enemy/Sprite",
		"@onready var player_sprite: Sprite2D = $Player/Sprite",
		""
	]))
	var both: Dictionary = EventSheetViewportReadingRows.object_class_map(
		EventSheets.open_gd_as_sheet(two))
	ok = _check("two declarations that disagree about a leaf leave it unclaimed",
		both.has("Sprite"), false) and ok
	ok = _check("while each whole path still answers for itself", "%s/%s" % [
		str(both.get("$Enemy/Sprite", "")), str(both.get("$Player/Sprite", ""))],
		"AnimatedSprite2D/Sprite2D") and ok
	ok = _check("with the bytes untouched either way", EventSheets.round_trips(two), true) and ok
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
	# THE SECOND MARK, and the one a reader uses when the tone is not enough: the muted word beside
	# the object. On a derived row it is always a CLASS. The declaration lens would put a variable
	# NAME there for a class the project itself declared - which is what a curated row looks like -
	# so on a derived row the class wins outright, and is left off only where the object column is
	# already saying it.
	for pair: Array in [
		[{"class": "Timer"}, "beat", "Timer"],
		[{"class": "EventSheetACERegistry"}, "_registry", "EventSheetACERegistry"],
		# Already said: the object column is the class, in words or as written.
		[{"class": "EventSheetACERegistry"}, "ACE registry", ""],
		[{"class": "Timer"}, "Timer", ""],
		# Nothing was read off anything: no mark, and the row keeps the plainer view it had.
		[{}, "beat", ""],
	]:
		ok = _check("the muted word beside \"%s\" is %s" % [str(pair[1]),
			"nothing" if str(pair[2]).is_empty() else str(pair[2])],
			EventSheetDerivedCalls.muted_note(pair[0] as Dictionary, str(pair[1])),
			str(pair[2])) and ok
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
	# AND IT ANSWERS FOR A CLASS THE PROJECT DECLARED TOO, which is the bigger half of the API a real
	# game calls. A receiver resolved to a project class carries that class's NAME as well as its
	# script, and reading only the members somebody typed in that one file would decline every verb
	# it inherits - honestly, but for most of what the class can do.
	var declared_class: Dictionary = {"class": "EventSheetResource",
		"script_path": EventSheetDerivedCalls.script_of_class("EventSheetResource"),
		"source": EventSheetDerivedCalls.SOURCE_DECLARED}
	var project_inherited: Dictionary = EventSheetDerivedCalls.method_facts(declared_class, "duplicate")
	ok = _check("a project class answers for the verbs it inherits",
		project_inherited.is_empty(), false) and ok
	ok = _check("...off the engine class at the bottom of its chain",
		str(project_inherited.get("doc_id", "")), "engine:Resource.duplicate") and ok
	ok = _check("...and a verb no class in that chain has is still nobody's",
		EventSheetDerivedCalls.method_facts(declared_class, "move_and_slide").is_empty(),
		true) and ok
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


## 7. WHAT THE LAYER COSTS. It runs at ROW-BUILD time, once per statement, on files with thousands
## of statements in them - so the number that matters is not how fast one answer is but how many
## times an answer is worked out at all. The claim is that it is worked out ONCE PER DISTINCT CLASS
## AND METHOD and held after that, which makes what a file costs a function of the VERBS in it
## rather than of its length: a thousand calls to the same six methods cost six answers.
##
## PINNED STRUCTURALLY - as identity and as cache size - rather than as a clock. A wall-clock budget
## for this layer alone would be a number measured on one machine on one afternoon; these hold on
## every machine, and they are the reason the wall-clock budgets over a corpus hold at all. Those
## budgets exist and this layer is live inside them: the 2,000-line script's open and its rebuild in
## `huge_project_budget_test.gd` are built through this reader, so a regression here also lands
## there, in milliseconds, on the biggest file the suite owns.
##
## THE REFUSALS ARE CACHED TOO, and that is the half worth pinning hardest: a call this layer
## declines is asked again on every rebuild for as long as the file is open, so a decline that went
## back to the class each time would cost a long file more than its readings do.
static func _test_what_it_costs() -> bool:
	EventSheetDerivedCalls.clear_cache()
	var ok: bool = _check("a cleared reader holds no method at all",
		EventSheetDerivedCalls._method_cache.size(), 0)
	# THE ONE INDEX. The project's class-name to path map is built once and handed back BY
	# REFERENCE. Two equal dictionaries would still mean every statement in the file paid for a walk
	# of the global class list, which is the regression this is here to catch.
	var index: Dictionary = EventSheetDerivedCalls._class_path_map()
	ok = _check("the class index is held and handed back by reference",
		is_same(index, EventSheetDerivedCalls._class_path_map()), true) and ok
	ok = _check("and it is not the empty map (an empty one would pass vacuously)",
		index.is_empty(), false) and ok
	# Six statements over three distinct methods - the shape a real file has, where the same few
	# verbs are called over and over - cost three answers.
	var repeated: Array[String] = ["beat.start(1.0)", "beat.start(2.0)", "beat.stop()",
		"bar.set_value_no_signal(10.0)", "beat.start(3.0)", "bar.set_value_no_signal(20.0)"]
	for code: String in repeated:
		_derived_text(code)
	ok = _check("six statements over three distinct methods cost three answers",
		EventSheetDerivedCalls._method_cache.size(), 3) and ok
	for code: String in repeated:
		_derived_text(code)
	ok = _check("and the same six asked again cost none", EventSheetDerivedCalls._method_cache.size(),
		3) and ok
	# A refusal is an answer, and it is held like one.
	_derived_text("beat.definitely_not_a_method(1)")
	ok = _check("a method the class does not have is worked out once",
		EventSheetDerivedCalls._method_cache.size(), 4) and ok
	_derived_text("beat.definitely_not_a_method(2)")
	ok = _check("and asked again it is remembered rather than re-refused",
		EventSheetDerivedCalls._method_cache.size(), 4) and ok
	# A receiver nothing can name never reaches the cache at all: there is no class to ask about,
	# so the line falls through to whatever plainer view it already had for free.
	_derived_text("whatever.do_thing(1)")
	ok = _check("a receiver nothing can name asks no class and holds nothing",
		EventSheetDerivedCalls._method_cache.size(), 4) and ok
	# And dropping really drops - the same held index, emptied - or a method renamed in a file
	# nobody reopened would go on reading as the method it used to be.
	EventSheetDerivedCalls.clear_cache()
	ok = _check("clearing drops every held method",
		EventSheetDerivedCalls._method_cache.size(), 0) and ok
	ok = _check("and empties the one index in place rather than leaving a stale copy behind",
		index.is_empty(), true) and ok
	ok = _check("which the next reader fills again",
		EventSheetDerivedCalls._class_path_map().is_empty(), false) and ok
	return ok


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
