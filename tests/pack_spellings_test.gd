# Godot EventSheets - the spellings a PACK teaches the reader, and the gate they ship through.
#
# A pack ships verbs, and somebody who used it before the sheet existed wrote those verbs by hand. A
# `## @ace_lift_example` beside the verb says which lines those are, so an opened file reads as the
# pack's own sentence instead of as the generic "call a method" row it lands on otherwise. The
# promise attached to that is the same one every built-in spelling makes: the words change and the
# BYTES do not.
#
# So this pins, in order: the shipped tables are sound (an entry generates its own fixture line, is
# claimed by itself, and re-emits byte for byte); the id a spelling names is the one the generator
# really publishes, asked of a real pack rather than assumed; five hand-written lines lift to the
# pack's verbs and the file still round-trips; and every way a spelling can be wrong is refused OUT
# LOUD - a shadowed built-in, a near-collision between two packs, an example above no verb, an
# example on a verb that is not an action, an example that cannot be built at all.
@tool
class_name PackSpellingsTest
extends RefCounted

## The pack that teaches the first shipped spellings, and the verb they are written on.
const FLICKER_PACK: String = "res://eventsheet_addons/light_flicker/light_flicker_behavior.gd"
const FLICKER_VERB: String = "start_flickering"

## A path that is not a pack, for the tables the suite invents. Nothing is read from it - it only
## names the table in the sentences the gate produces.
const IMAGINED_PACK: String = "res://eventsheet_addons/imagined/imagined_behavior.gd"
const OTHER_IMAGINED_PACK: String = "res://eventsheet_addons/other/other_behavior.gd"


static func run() -> bool:
	# The tables are read off disk once per session, so a suite that pins them starts from cold.
	EventForgePackSpellings.reset_cache_for_tests()
	var ok: bool = true
	ok = _test_the_shipped_tables() and ok
	ok = _test_the_id_is_the_published_one() and ok
	ok = _test_a_hand_written_file() and ok
	ok = _test_the_refusals() and ok
	ok = _test_shadowing_and_collisions() and ok
	EventForgePackSpellings.reset_cache_for_tests()
	return ok


## The shipped spellings, held to the same promise the built-in tables are. `problems()` is the whole
## gate in one call (it is what tools/audit_addons.gd fails on), so an empty list here is the pack
## covenant: sound tables, own fixture lines, byte-exact re-emission, nothing shadowing a built-in.
static func _test_the_shipped_tables() -> bool:
	var ok: bool = _check("the shipped pack spellings are sound",
		EventForgePackSpellings.problems(), PackedStringArray())
	ok = _check("and none of them collides with another pack",
		EventForgePackSpellings.advisories(), PackedStringArray()) and ok
	ok = _check("the light flicker pack is found by scanning",
		EventForgePackSpellings.tables().has(FLICKER_PACK), true) and ok
	var ids: PackedStringArray = PackedStringArray()
	for entry: Dictionary in EventForgePackSpellings.tables().get(FLICKER_PACK, []):
		ids.append(str(entry.get("id", "")))
	# Pinned as VALUES: the two spellings of each verb, in the order the pack writes them.
	ok = _check("and teaches both spellings of both its verbs", ids, PackedStringArray([
		"LightFlickerBehavior.start_flickering#1", "LightFlickerBehavior.start_flickering#2",
		"LightFlickerBehavior.stop_flickering#1", "LightFlickerBehavior.stop_flickering#2"])) and ok
	return ok


## The id a spelling hands back has to be the id the pack really publishes, or a lifted row names a
## verb the picker has never heard of. Asked of the generator itself rather than taken on trust:
## `method:<name>` is the generator's shape, and this is where the two are held together.
static func _test_the_id_is_the_published_one() -> bool:
	var published: PackedStringArray = PackedStringArray()
	for entry: Dictionary in EventSheetProviderPreview.scan(FLICKER_PACK).get("entries", []):
		published.append(str(entry.get("ace_id", "")))
	var derived: String = EventForgePackSpellings.METHOD_ACE_PREFIX + FLICKER_VERB
	var ok: bool = _check("the id a spelling names is one the pack publishes",
		published.has(derived), true)
	var spelled: PackedStringArray = PackedStringArray()
	for entry: Dictionary in EventForgePackSpellings.tables().get(FLICKER_PACK, []):
		if not spelled.has(str(entry.get("ace_id", ""))):
			spelled.append(str(entry.get("ace_id", "")))
	ok = _check("and every id the pack's spellings name is published too",
		[published.has(spelled[0]), published.has(spelled[1])], [true, true]) and ok
	ok = _check("under the pack's own provider", str(EventSheetProviderPreview.scan(FLICKER_PACK)\
		.get("provider_id", "")), "LightFlickerBehavior") and ok
	return ok


## The point of the whole mechanism, on a file nobody generated: five ways of writing the same two
## verbs, all five read as the pack's verbs, and the file still saves as itself.
static func _test_a_hand_written_file() -> bool:
	var source: String = "\n".join(PackedStringArray([
		"extends Node",
		"",
		"@onready var flicker: Node = $Torch/LightFlickerBehavior",
		"",
		"func _ready() -> void:",
		"\t$LightFlickerBehavior.start_flickering(0.5)",
		"\tflicker.start_flickering()",
		"\tflicker.stop_flickering(1.0)",
		"\tflicker.stop_flickering()",
		"\tget_node(\"LightFlickerBehavior\").start_flickering(0.25)",
		""
	]))
	# The covenant first: a reading that changed a byte would be a bug however well it read.
	var ok: bool = _check("a hand-written file round-trips byte for byte",
		EventSheets.round_trips(source), true)
	var sheet: EventSheetResource = EventSheets.open_gd_as_sheet(source)
	var read_as: Array = []
	for action: Variant in _actions_of(sheet):
		read_as.append("%s::%s" % [(action as ACEAction).provider_id, (action as ACEAction).ace_id])
	ok = _check("and every spelling in it reads as the pack's own verb", read_as, [
		"LightFlickerBehavior::method:start_flickering",
		"LightFlickerBehavior::method:start_flickering",
		"LightFlickerBehavior::method:stop_flickering",
		"LightFlickerBehavior::method:stop_flickering",
		"LightFlickerBehavior::method:start_flickering"]) and ok
	# The values the row shows, and the author's own line baked on it - which is what makes the
	# round trip above structural rather than lucky.
	var lifted: Array = _actions_of(sheet)
	var first: ACEAction = lifted[0] as ACEAction
	ok = _check("with the values its line says",
		first.params, {"target": "$LightFlickerBehavior", "after_seconds": "0.5"}) and ok
	ok = _check("and the author's spelling stored on it",
		first.codegen_template, "{target.}start_flickering({after_seconds})") and ok
	ok = _check("a call with the delay left out keeps the shape it was written in",
		(lifted[1] as ACEAction).codegen_template, "{target.}start_flickering()") and ok
	# The other half of the claim, and the one worth pinning: the SAME bytes with no table installed
	# still read - as the plain generic call every unclaimed method lands on. A table landing later
	# upgrades those rows in place; it never decides whether a file can be opened at all.
	EventForgePackSpellings.override_tables_for_tests({})
	var without: Array = []
	for action: Variant in _actions_of(EventSheets.open_gd_as_sheet(source)):
		without.append("%s::%s" % [(action as ACEAction).provider_id, (action as ACEAction).ace_id])
	EventForgePackSpellings.reset_cache_for_tests()
	ok = _check("and with no table installed the same file reads as the generic call", without, [
		"Core::CallMethod", "Core::CallMethod", "Core::CallMethod", "Core::CallMethod",
		"Core::CallMethod"]) and ok
	ok = _check("which is byte-identical either way", EventSheets.round_trips(source), true) and ok
	return ok


## Every ACE action a lifted sheet holds, in file order.
static func _actions_of(sheet: EventSheetResource) -> Array:
	var actions: Array = []
	for row: Variant in sheet.events:
		if not (row is EventRow):
			continue
		for action: Variant in (row as EventRow).actions:
			if action is ACEAction:
				actions.append(action)
	return actions


## Every way an example can be wrong, seeded once. A parser nobody has watched refuse is a parser
## that accepts everything.
static func _test_the_refusals() -> bool:
	var source: String = "\n".join(PackedStringArray([
		"class_name ImaginedBehavior",
		"extends Node",
		"",
		"## @ace_condition",
		"## @ace_lift_example(\"[[target|receiver: $ImaginedBehavior]].is_lit()\")",
		"func is_lit() -> bool:",
		"\treturn true",
		"",
		"## @ace_action",
		"## @ace_lift_example(\"[[target|receiver: $ImaginedBehavior]] blink\")",
		"func light() -> void:",
		"\tpass",
		"",
		"## @ace_lift_example(\"[[target|receiver: $ImaginedBehavior]].nothing()\")",
		"var not_a_verb: int = 0"
	]))
	var refusals: PackedStringArray = PackedStringArray()
	for entry: Dictionary in EventForgePackSpellings.entries_in_source(source, IMAGINED_PACK):
		refusals.append(str(entry.get(EventForgeLiftTable.REFUSAL_KEY, "")))
	return _check("every example that cannot work says why", refusals, PackedStringArray([
		"a lift example teaches the spelling of an action, and this verb is @ace_condition",
		"the receiver span target is not followed by a dot",
		"an example sits above no function:"\
			+ " [[target|receiver: $ImaginedBehavior]].nothing()"]))


## The two rules about one line and two claimants: a built-in wins outright (and the pack is refused
## at the gate), and two packs are told which of them the reader will actually see.
static func _test_shadowing_and_collisions() -> bool:
	# A spelling aimed straight at a built-in family's own line. `play("walk")` on a node is the
	# animation family's, and a pack re-labelling it would quietly rename a row the engine already
	# reads better than it does.
	var shadowing: Array = [EventForgeLiftExample.entry("imagined.play#1", "method:play",
		"[[target|receiver: $Imagined]].play([[anim_name|argument: \"walk\"]])",
		{"provider": "ImaginedBehavior"})]
	var problems: PackedStringArray = EventForgePackSpellings.problems_for(IMAGINED_PACK, shadowing)
	var ok: bool = _check("a spelling that shadows a built-in is refused, naming both",
		problems, PackedStringArray(["imagined_behavior.gd: imagined.play#1 spells a line"\
			+ " animation_lift.gd already claims - a pack may not shadow a built-in spelling"]))
	# And two packs that both know one line. Neither is wrong; the reader is told which one wins.
	var mine: Array = [EventForgeLiftExample.entry("imagined.blink#1", "method:blink",
		"[[target|receiver: $Imagined]].blink([[seconds|argument: 0.5]])",
		{"provider": "ImaginedBehavior"})]
	var theirs: Array = [EventForgeLiftExample.entry("other.blink#1", "method:blink",
		"[[target|receiver: $Other]].blink([[seconds|argument: 0.5]])", {"provider": "OtherBehavior"})]
	ok = _check("two packs spelling one line are told who claims it",
		EventForgePackSpellings.advisories_for({IMAGINED_PACK: mine, OTHER_IMAGINED_PACK: theirs}),
		PackedStringArray(["other_behavior.gd: other.blink#1 reads as imagined_behavior.gd's"\
			+ " imagined.blink#1 - where two packs spell one line, the first pack in folder order"\
			+ " claims it"])) and ok
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] pack_spellings_test: %s" % label)
		return true
	print("[FAIL] pack_spellings_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
