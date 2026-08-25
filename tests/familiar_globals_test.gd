# Godot EventSheets - Under Familiar Words a global drops its autoload's name.
#
# In the sheet a global is simply a value the whole project shares, and System is the object the
# sheet already files shared things under; WHICH autoload holds it is a Godot fact, not a reading.
# With Familiar Words off it stays `Game ▸ Set Score to 10`, because that is the honest spelling of
# what the line actually says - so both readings are pinned, not just the new one.
@tool
class_name FamiliarGlobalsTest
extends RefCounted

const PROBE_AUTOLOAD := "autoload/EventSheetsProbeGame"


static func run() -> bool:
	var all_passed: bool = true
	# The probe autoload only has to LOOK registered - the reading asks ProjectSettings, nothing else.
	var had_setting: bool = ProjectSettings.has_setting(PROBE_AUTOLOAD)
	ProjectSettings.set_setting(PROBE_AUTOLOAD, "*res://eventsheets_probe_game.gd")
	EventSheetSentence.clear_autoload_cache()

	all_passed = _check("with Familiar Words on a global drops the autoload's name",
		_object_of("EventSheetsProbeGame.Score = 10", true), "System") and all_passed
	all_passed = _check("and with it off the autoload is named",
		_object_of("EventSheetsProbeGame.Score = 10", false), "EventSheetsProbeGame") and all_passed
	# The value is untouched either way - only the object column changes.
	all_passed = _check("the sentence itself is the same either way",
		_text_of("EventSheetsProbeGame.Score = 10", true), _text_of("EventSheetsProbeGame.Score = 10", false)) and all_passed
	# An object that is NOT an autoload keeps its name under Familiar Words - the rule is about
	# globals, not about dropping prefixes.
	all_passed = _check("an ordinary object keeps its name",
		_object_of("hud.Score = 10", true), "hud") and all_passed
	# And the direct question, so a failure names the rule rather than a sentence.
	all_passed = _check("the rule fires only for a registered autoload",
		EventSheetSentence.familiar_global_object("EventSheetsProbeGame", {"familiar_words": true}), "System") and all_passed
	all_passed = _check("the rule never fires with Familiar Words off",
		EventSheetSentence.familiar_global_object("EventSheetsProbeGame", {"familiar_words": false}), "") and all_passed
	all_passed = _check("the rule never fires for a name nobody registered",
		EventSheetSentence.familiar_global_object("NotAnAutoload", {"familiar_words": true}), "") and all_passed

	if not had_setting:
		ProjectSettings.set_setting(PROBE_AUTOLOAD, null)
	EventSheetSentence.clear_autoload_cache()
	return all_passed


## The object column of a statement's reading.
static func _object_of(statement: String, familiar_words: bool) -> String:
	var sentence: Dictionary = EventSheetSentence.statement(statement, {"familiar_words": familiar_words, "self_object": "Player"})
	return str(sentence.get("object", ""))


## The words of a statement's reading, with the object column dropped.
static func _text_of(statement: String, familiar_words: bool) -> String:
	var sentence: Dictionary = EventSheetSentence.statement(statement, {"familiar_words": familiar_words, "self_object": "Player"})
	var words: PackedStringArray = PackedStringArray()
	for segment: Variant in (sentence.get("segments", []) as Array):
		words.append(str((segment as Array)[0]) if segment is Array else str(segment))
	return " ".join(words)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual != expected:
		print("  [FAIL] %s (got %s, expected %s)" % [label, actual, expected])
		return false
	print("[PASS] familiar_globals_test: %s" % label)
	return true
