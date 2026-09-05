# Godot EventSheets - EVERY PROPERTY TOO, pinned as values.
#
# Seven things are pinned here, and each of them is a claim the derived property reading makes out
# loud:
#
#   1. THE THREE SHAPES. A write, a question and a read - the Inspector's own object / property /
#      value, in the three places an event sheet puts them: the right lane, the left lane, and the
#      value slot an expression answers in.
#   2. WHAT IS NOT CLAIMED. A receiver nothing can name, a property the class does not have, and a
#      bare name with no receiver written down at all. The refusals are pinned as hard as the
#      answers, because a guess dressed as a reading is the one failure this layer cannot have.
#   3. THE TWO LAYERS LOOK DIFFERENT. The derived property wears the derived tone; the generic
#      reading it replaces wears the bold `name`; a curated sentence has neither, because it says
#      something else entirely. Same statement, three answers, told apart by weight alone.
#   4. CURATED OUTRANKS, AND UPGRADES IN PLACE. One property with a word map (`energy` on a light)
#      and one without (`shadow_filter_smooth` on the same light), read off the same object. The
#      first is never marked generic and therefore never reaches the derived layer at all; the
#      second is. That is the upgrade path, and it needs no bytes to change.
#   5. THE WORDS RIDE. The `##` lines above a project script's own `var` as the row's hover, an
#      engine property's page id for F1, and the credit riding with the engine's own prose because
#      its licence says so.
#   6. THE ROW IS THE LINE. A file full of derived property rows saves back byte-identical, because
#      the reading repaints segments over an unchanged row and translates nothing.
#   7. WHAT THE LAYER COSTS, as answers rather than as milliseconds. One walk per class and one
#      answer per property, refusals held exactly like answers, and the class's property set handed
#      back by reference - the claims that make a long file cost its PROPERTIES rather than its
#      length.
#
# SERIAL-CI HYGIENE. This warms the derived readers' per-class and per-file caches, and CI runs the
# suite serially in one process, so all of them are dropped on the way out and the staged script
# lives in user:// and is deleted - nothing is left in the repository.
@tool
class_name DerivedPropertyRowsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")

## Where the staged script lives. user://, so a run leaves nothing under res://.
const STAGED_DIR: String = "user://derived_property_rows_staged"
const STAGED_SCRIPT: String = STAGED_DIR + "/lantern.gd"

## A project script with `##` lines above its own declarations, including one that an `@export`
## annotation sits between - the ordinary way an exported, documented property is written.
const STAGED_SOURCE: String = """extends Node2D


## How bright the lantern burns, from out to full.
@export var glow: float = 1.0

## What it costs to keep lit for a second.
var upkeep: int = 2

var _private_tally: int = 0


func light() -> void:
	visible = true
"""

## The sheet the readings are asked against: a torch and a bar in the scene, a declared timer, and
## the script's own host class. Every fact a real sheet's context carries.
const CONTEXT: Dictionary = {
	"self_object": "Player",
	"self_class": "CharacterBody2D",
	"self_script_path": "",
	"variable_types": {"beat": "Timer", "hp": "int", "crew": "Array[Node]"},
	"engine_properties": {"position": true, "visible": true},
	"object_classes": {"Torch": "Light2D", "$Torch": "Light2D", "HpBar": "ProgressBar",
		"$HpBar": "ProgressBar", "Player": "CharacterBody2D"},
	"signals": {},
	"signal_params": {},
}

## The object-label to class map the row builder hoists once per rebuild.
const CLASS_MAP: Dictionary = {"Torch": "Light2D", "$Torch": "Light2D",
	"HpBar": "ProgressBar", "$HpBar": "ProgressBar", "Player": "CharacterBody2D"}

## A property every Light2D really has and no word map renames, so it is the derived layer's
## territory by construction - and its twin `energy`, which a word map owns.
const UNCLAIMED_PROPERTY: String = "shadow_filter_smooth"


static func run() -> bool:
	var ok: bool = _test_the_three_shapes()
	ok = _test_what_is_not_claimed() and ok
	ok = _test_the_two_layers_look_different() and ok
	ok = _test_curated_outranks_and_upgrades_in_place() and ok
	ok = _test_the_words_ride() and ok
	ok = _test_the_row_is_the_line() and ok
	ok = _test_what_it_costs() and ok
	_tidy_up()
	return ok


## Every pin here, through the suite's ONE assertion vocabulary. A local spelling only because every
## pin in this file says the same prefix - the printing, and the `expected:` / `actual:` pair the
## report tool parses, are `tests/support.gd`'s.
static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("derived_property_rows_test", label, actual, expected)


## 1. The three shapes, each as the object column and the words after it. The Inspector's own order,
## with the property drawn back from the generic reading it replaces.
static func _test_the_three_shapes() -> bool:
	var ok: bool = true
	# A WRITE, in the right lane.
	ok = _check("a property write reads as object, property, value",
		_derived_statement("$Torch.%s = 1.5" % UNCLAIMED_PROPERTY),
		"Torch ▸ Set <%s> to 1.5" % UNCLAIMED_PROPERTY) and ok
	ok = _check("and on a typed local, off the declaration's own type",
		_derived_statement("beat.wait_time = 2.0"), "beat ▸ Set <wait_time> to 2") and ok
	# A QUESTION, in the left lane - the compared-variable rendering on an object's own property.
	ok = _check("a comparison reads as the object's property, measured",
		_derived_condition("$Torch.%s > 1.0" % UNCLAIMED_PROPERTY),
		"Torch ▸ <%s> > 1" % UNCLAIMED_PROPERTY) and ok
	ok = _check("every operator the sheet asks with, in the sheet's own symbols",
		_derived_condition("$HpBar.value >= 5"), "HpBar ▸ <value> ≥ 5") and ok
	# A READ, answering in the value slot it sits in - which is where the grammar says an
	# expression answers, and it wears the same derived tone the property on the left does.
	ok = _check("a read of a property answers in the value slot",
		_derived_statement("$HpBar.value = $HpBar.max_value"),
		"HpBar ▸ Set <value> to <$HpBar.max_value>") and ok
	# And a value that is NOT a property read is left exactly as the grammar spelled it.
	ok = _check("a value that is not a property read is untouched",
		_derived_statement("$HpBar.value = 40"), "HpBar ▸ Set <value> to 40") and ok
	return ok


## 2. The refusals. Each of these is a line the sheet could have dressed up as a property row, and
## each one keeps the plainer view it already had instead.
static func _test_what_is_not_claimed() -> bool:
	var ok: bool = true
	for pair: Array in [
		# A receiver whose class nothing in the sheet can answer for.
		["whatever.thing = 1", ""],
		# A property the class does not have is somebody else's, reached through a name this
		# cannot see. Dressing it up as the class's own would be the guess this layer must not make.
		["$HpBar.definitely_not_a_property = 1", ""],
		# A bare name with no receiver written down: the sheet's own variable rows own that reading.
		["hp = 5", ""],
		# A property OF a property is a receiver this cannot name, whatever the head resolves to.
		["$HpBar.theme_override_colors.font_color = 1", ""],
	]:
		ok = _check("\"%s\" is not claimed" % str(pair[0]),
			_derived_statement(str(pair[0])), str(pair[1])) and ok
	ok = _check("and a question about a property nothing has is not claimed either",
		_derived_condition("$HpBar.definitely_not_a_property > 1"), "") and ok
	# The refusal is what the reading REST on, so the receiver layer's own refusals are pinned here
	# too rather than trusted: a value type is not a receiver, and neither is a typed collection.
	for receiver: String in ["hp", "crew", "whatever"]:
		ok = _check("receiver \"%s\" answers for nothing" % receiver,
			EventSheetDerivedCalls.receiver_facts(receiver, CONTEXT, CLASS_MAP, {}).is_empty(),
			true) and ok
	return ok


## 3. The two layers, on one statement. The generic reading paints the property bold `name`; the
## derived one paints the same word in the plainer derived tone; and a curated sentence says
## something else altogether, so it has no property segment at all.
static func _test_the_two_layers_look_different() -> bool:
	var ok: bool = true
	var line: String = "$Torch.%s = 1.5" % UNCLAIMED_PROPERTY
	var generic: Dictionary = EventSheetSentence.statement(line, CONTEXT)
	ok = _check("the generic reading paints the property bold",
		_tone_of(generic.get("segments", []) as Array, UNCLAIMED_PROPERTY), "name") and ok
	var derived: Dictionary = EventSheetDerivedProperties.derived_reading(
		generic, CONTEXT, CLASS_MAP, {})
	ok = _check("and the derived reading paints the same word a shade back",
		_tone_of(derived.get("segments", []) as Array, UNCLAIMED_PROPERTY),
		EventSheetDerivedCalls.TONE_DERIVED) and ok
	# Nothing else about the segments changed: the words, the translations and the value spellings
	# are the grammar's own, and this layer only ever repaints.
	ok = _check("and changes not one word of what the grammar said",
		_words(derived.get("segments", []) as Array),
		_words(generic.get("segments", []) as Array)) and ok
	ok = _check("the derived property shares the derived verb's tone, so there is one plainer layer",
		EventSheetDerivedCalls.TONE_DERIVED, "derived") and ok
	return ok


## 4. Two properties of one object, read off one class: one a word map owns and one it does not.
## The first is never marked generic, so the derived layer is never even asked about it - which is
## exactly what "landing a curated table later upgrades derived rows in place" means, run backwards.
static func _test_curated_outranks_and_upgrades_in_place() -> bool:
	var ok: bool = true
	var curated: Dictionary = EventSheetSentence.statement("$Torch.energy = 1.2", CONTEXT)
	ok = _check("a property a word map owns is never marked generic",
		str(curated.get("generic", "")), "") and ok
	ok = _check("and says the polished thing instead",
		"%s ▸ %s" % [str(curated.get("object", "")), _words(curated.get("segments", []) as Array)],
		"Torch ▸ Set light energy to 120%") and ok
	ok = _check("so the derived layer declines it outright",
		EventSheetDerivedProperties.derived_reading(curated, CONTEXT, CLASS_MAP, {}).is_empty(),
		true) and ok
	# The very next property of the very same object, which no word map claims.
	var unclaimed: Dictionary = EventSheetSentence.statement(
		"$Torch.%s = 1.5" % UNCLAIMED_PROPERTY, CONTEXT)
	ok = _check("the property beside it is marked generic",
		str(unclaimed.get("generic", "")), EventSheetSentence.GENERIC_PROPERTY_SET) and ok
	ok = _check("and the derived layer answers for it",
		EventSheetDerivedProperties.derived_reading(
			unclaimed, CONTEXT, CLASS_MAP, {}).is_empty(), false) and ok
	# Both properties are real properties of the same class, so the difference between the two rows
	# is entirely which layer had words for it - not which line the file wrote.
	var receiver: Dictionary = {"class": "Light2D", "script_path": "", "source": "node"}
	for property: String in ["energy", UNCLAIMED_PROPERTY]:
		ok = _check("`%s` is a real property of Light2D either way" % property,
			EventSheetDerivedProperties.property_facts(receiver, property).is_empty(), false) and ok
	return ok


## 5. The words that ride with the row: the `##` lines above a project script's own declaration, the
## engine's page for a built-in property, and the credit wherever the prose is the engine's.
static func _test_the_words_ride() -> bool:
	var ok: bool = true
	_stage_script()
	var receiver: Dictionary = {"class": "", "script_path": STAGED_SCRIPT, "source": "declared"}
	var glow: Dictionary = EventSheetDerivedProperties.property_facts(receiver, "glow")
	ok = _check("a project property's words are the `##` lines above it",
		str(glow.get("doc", "")), "How bright the lantern burns, from out to full.") and ok
	ok = _check("an annotation between the words and the declaration does not break the block",
		str(glow.get("type", "")), "float") and ok
	ok = _check("a plain `var` is read the same way",
		str(EventSheetDerivedProperties.property_facts(receiver, "upkeep").get("doc", "")),
		"What it costs to keep lit for a second.") and ok
	ok = _check("a private field is not a property a row writes",
		EventSheetDerivedProperties.property_facts(receiver, "_private_tally").is_empty(), true) and ok
	ok = _check("and nobody's prose is credited to the engine", str(glow.get("credit", "")), "") and ok
	# What the file EXTENDS answers for everything it did not declare itself, so an ordinary engine
	# property on a project script still reads - and its page is the engine's.
	var inherited: Dictionary = EventSheetDerivedProperties.property_facts(receiver, "modulate")
	ok = _check("what the file extends answers for the rest", inherited.is_empty(), false) and ok
	ok = _check("and that property's page is the engine's",
		str(inherited.get("doc_id", "")), "engine:Node2D.modulate") and ok
	# AND A CLASS THE PROJECT DECLARED ANSWERS FOR WHAT IT INHERITS TOO. A receiver resolved to a
	# project class carries that class's NAME as well as its script, and reading only the `var` lines
	# somebody typed in that one file would decline every property it inherits.
	var declared_class: Dictionary = {"class": "EventSheetResource",
		"script_path": EventSheetDerivedCalls.script_of_class("EventSheetResource"),
		"source": EventSheetDerivedCalls.SOURCE_DECLARED}
	var project_inherited: Dictionary = EventSheetDerivedProperties.property_facts(
		declared_class, "resource_name")
	ok = _check("a project class answers for the properties it inherits",
		project_inherited.is_empty(), false) and ok
	ok = _check("...off the engine class at the bottom of its chain",
		str(project_inherited.get("doc_id", "")), "engine:Resource.resource_name") and ok
	ok = _check("...and a property no class in that chain has is still nobody's",
		EventSheetDerivedProperties.property_facts(declared_class, "modulate").is_empty(),
		true) and ok
	ok = _check("a property the class does not have has no page",
		EventSheetDerivedProperties.doc_id_for("Light2D", "definitely_not_a_property"), "") and ok
	ok = _check("and one it does have opens the engine's own reference",
		EventSheetDerivedProperties.doc_id_for("Light2D", UNCLAIMED_PROPERTY),
		"engine:Light2D.%s" % UNCLAIMED_PROPERTY) and ok
	# And the keys the reading leaves on the span it painted, which are what the hover and F1 are
	# actually handed. Pinned as the whole dictionary rather than key by key, so a key quietly added
	# or renamed here has to be looked at rather than sailing through.
	ok = _check("what a derived property row hands the hover and F1",
		ViewportRowBuilder.derived_meta({"class": "Light2D", "property": UNCLAIMED_PROPERTY,
			"doc": "How soft the shadow edge is.", "credit": "",
			"doc_id": "engine:Light2D.%s" % UNCLAIMED_PROPERTY}),
		{"derived_call": true, "derived_class": "Light2D", "derived_method": "",
			"derived_property": UNCLAIMED_PROPERTY,
			"derived_doc": "How soft the shadow edge is.",
			"derived_doc_id": "engine:Light2D.%s" % UNCLAIMED_PROPERTY}) and ok
	# The Inspector's own spelling, which is what the hover leads a second property's words with.
	ok = _check("the Inspector's name for a property is the Inspector's",
		EventSheetDerivedProperties.inspector_name("shadow_filter_smooth"), "Shadow Filter Smooth") and ok
	# The credit is not a courtesy: the engine's prose is published under a licence that asks for it,
	# and the one hover builder is where that rule lives for this layer as for the calls.
	ok = _check("the engine's own words carry the credit its licence asks for",
		EventSheetDerivedCalls.hover_text({"doc": "How bright the light is.",
			"credit": EventSheetDocEngineReference.CREDIT_LINE}),
		"How bright the light is.\n%s" % EventSheetDocEngineReference.CREDIT_LINE) and ok
	return ok


## 6. The contract underneath the whole layer: a derived row IS the line it read. The reading
## repaints segments over an unchanged row and translates nothing, so byte-exactness is structural -
## which is exactly why it is worth proving on a real buffer rather than trusting the mechanism.
static func _test_the_row_is_the_line() -> bool:
	_stage_script()
	var reading: Dictionary = EventSheetLiftReading.read(STAGED_SOURCE, STAGED_SCRIPT)
	return _check("a file of derived property rows saves back byte-identical",
		bool(reading.get("identical", false)), true)


## 7. WHAT THE LAYER COSTS. It runs at ROW-BUILD time, once per generic property statement, on files
## with thousands of statements in them - so the number that matters is not how fast one answer is
## but how many times an answer is worked out at all. The claim is two-deep and the same shape the
## derived verbs make: ONE WALK PER CLASS for the question "does this class have that property", and
## ONE ANSWER PER PROPERTY for the words underneath it. Both held after the first ask, which makes
## what a file costs a function of the PROPERTIES in front of the reader rather than of its length -
## a hundred rows writing the same three properties cost three answers.
##
## PINNED STRUCTURALLY - as identity and as cache size - rather than as a clock, so the pins hold on
## a loaded runner and on every machine. The wall-clock budgets that do exist are over a corpus, and
## this layer is live inside them: the 2,000-line script's open and its rebuild in
## `huge_project_budget_test.gd` are built through this reader, so a regression here also lands
## there, in milliseconds, on the biggest file the suite owns.
##
## THE REFUSALS ARE CACHED TOO, and that is the half worth pinning hardest: a property this layer
## declines is asked again on every rebuild for as long as the file is open, so a decline that went
## back to the class each time would cost a long file more than its readings do.
static func _test_what_it_costs() -> bool:
	EventSheetDerivedProperties.clear_cache()
	var ok: bool = _check("a cleared reader holds no property answer at all",
		EventSheetDerivedProperties._property_cache.size(), 0)
	ok = _check("and no class walked either",
		EventSheetDerivedProperties._class_properties.size(), 0) and ok
	# THE ONE CLASS INDEX. A class's property set is walked once and handed back BY REFERENCE. Two
	# equal dictionaries would still mean every statement in the file paid for a walk of the class's
	# whole inherited property list, which is the regression this is here to catch.
	var index: Dictionary = EventSheetDerivedProperties._properties_of("Light2D")
	ok = _check("a class's property set is held and handed back by reference",
		is_same(index, EventSheetDerivedProperties._properties_of("Light2D")), true) and ok
	ok = _check("and it is not the empty set (an empty one would pass vacuously)",
		index.is_empty(), false) and ok
	ok = _check("one class asked about leaves one class walked",
		EventSheetDerivedProperties._class_properties.size(), 1) and ok
	# Six statements over three distinct properties of three objects - the shape a real file has,
	# where the same few properties are written over and over - cost three answers and three walks.
	var repeated: Array[String] = [
		"$Torch.%s = 0.5" % UNCLAIMED_PROPERTY,
		"$Torch.%s = 0.6" % UNCLAIMED_PROPERTY,
		"$HpBar.value = 10",
		"beat.wait_time = 1",
		"$HpBar.value = 20",
		"beat.wait_time = 2",
	]
	var answered: int = 0
	for code: String in repeated:
		if not _derived_statement(code).is_empty():
			answered += 1
	# Vacuity guard: a layer that declined all six would hold nothing and pass every count below.
	ok = _check("all six statements are readings the layer actually claimed", answered, 6) and ok
	ok = _check("six statements over three distinct properties cost three answers",
		EventSheetDerivedProperties._property_cache.size(), 3) and ok
	ok = _check("over three classes, each walked once",
		EventSheetDerivedProperties._class_properties.size(), 3) and ok
	for code: String in repeated:
		_derived_statement(code)
	ok = _check("and the same six asked again cost none",
		EventSheetDerivedProperties._property_cache.size(), 3) and ok
	# A refusal is an answer, and it is held like one.
	_derived_statement("$Torch.definitely_not_a_property = 1")
	ok = _check("a property the class does not have is worked out once",
		EventSheetDerivedProperties._property_cache.size(), 4) and ok
	_derived_statement("$Torch.definitely_not_a_property = 2")
	ok = _check("and asked again it is remembered rather than re-refused",
		EventSheetDerivedProperties._property_cache.size(), 4) and ok
	# A receiver nothing can name never reaches either cache: there is no class to ask about, so the
	# line falls through to whatever plainer view it already had for free.
	_derived_statement("whatever.thing = 1")
	ok = _check("a receiver nothing can name asks no class and holds nothing",
		"%d/%d" % [EventSheetDerivedProperties._property_cache.size(),
			EventSheetDerivedProperties._class_properties.size()], "4/3") and ok
	# And dropping really drops - or a property added to a script nobody reopened would go on being
	# the property it was not.
	EventSheetDerivedProperties.clear_cache()
	ok = _check("clearing drops every held answer and every walked class",
		"%d/%d" % [EventSheetDerivedProperties._property_cache.size(),
			EventSheetDerivedProperties._class_properties.size()], "0/0") and ok
	# The set handed out before the drop is a set nobody can mistake for the live one afterwards:
	# the next reader walks the class again and is handed a DIFFERENT dictionary, so a stale handout
	# cannot quietly go on answering. Nothing here holds one across a drop; this pins that.
	ok = _check("and the next reader is handed a walk of its own, not the dropped one",
		is_same(index, EventSheetDerivedProperties._properties_of("Light2D")), false) and ok
	ok = _check("which is filled again rather than left empty",
		EventSheetDerivedProperties._properties_of("Light2D").is_empty(), false) and ok
	return ok


# ── the pieces ──────────────────────────────────────────────────────────────────


## One statement's derived reading as "object ▸ words", with the segments the derived tone claimed
## wrapped in angle brackets so the tone is readable in the pin. "" when the layer declined it.
static func _derived_statement(code: String) -> String:
	return _marked(EventSheetSentence.statement(code, CONTEXT))


## The same for a question, through the condition half of the grammar.
static func _derived_condition(code: String) -> String:
	return _marked(EventSheetSentence.condition(code, CONTEXT))


static func _marked(reading: Dictionary) -> String:
	var derived: Dictionary = EventSheetDerivedProperties.derived_reading(
		reading, CONTEXT, CLASS_MAP, {})
	if derived.is_empty():
		return ""
	var out: String = "%s ▸ " % str(reading.get("object", ""))
	for entry: Variant in (derived.get("segments", []) as Array):
		var segment: Dictionary = entry
		var text: String = str(segment.get("text", ""))
		out += "<%s>" % text if str(segment.get("tone", "")) == EventSheetDerivedCalls.TONE_DERIVED \
			else text
	return out


## Every word of a reading, with no tone at all - for the claim that repainting changed the paint
## and nothing else.
static func _words(segments: Array) -> String:
	var text: String = ""
	for entry: Variant in segments:
		text += str((entry as Dictionary).get("text", ""))
	return text


## The tone of the segment whose text is exactly `wanted`, or "" when no segment says it.
static func _tone_of(segments: Array, wanted: String) -> String:
	for entry: Variant in segments:
		var segment: Dictionary = entry
		if str(segment.get("text", "")) == wanted:
			return str(segment.get("tone", ""))
	return ""


static func _stage_script() -> void:
	DirAccess.make_dir_recursive_absolute(STAGED_DIR)
	var handle: FileAccess = FileAccess.open(STAGED_SCRIPT, FileAccess.WRITE)
	if handle != null:
		handle.store_string(STAGED_SOURCE)
		handle.close()


## Drops what this warmed and deletes what it wrote, so the next test in a serial run starts where
## it would have started had this one never happened.
static func _tidy_up() -> void:
	EventSheetDerivedProperties.clear_cache()
	EventSheetDerivedCalls.clear_cache()
	EventSheetScriptMembers.clear_cache()
	EventSheetLiftReading.clear_cache()
	DirAccess.remove_absolute(STAGED_SCRIPT)
	DirAccess.remove_absolute(STAGED_DIR)
