@tool
class_name MultiplayerMessagesTest
extends RefCounted
# M2 - a message is a function that says who may call it, where it runs, and how it travels.
#
# Godot spells all four answers as strings inside `@rpc(...)`. The sheet reads them as words and
# writes them back from words, so the one thing that must never slip is that the table runs BOTH
# directions and that a message opened and confirmed unchanged leaves the `.gd` byte for byte as it
# was. Everything here is pinned by VALUE:
#   the words table, option -> word and word -> option, every one of Godot's seven options;
#   what an annotation SAYS, including the channel and an option Godot does not take;
#   the byte-exact rule - `rewrite` hands the original line back for an unchanged answer, and the
#   whole file re-emits identically through the dialog's own write path;
#   the Send half - the three ids the To dropdown maps to, the lines they write (built by the
#   compiler's own codegen off the frozen templates), and the fact that the list a Send row picks
#   from holds only functions that are actually marked.

const GDScriptImporter := preload("res://addons/eventforge/importer/gdscript_importer.gd")

## A hand-written source with one message and one plain helper - the shape a project that already
## uses `@rpc` opens as.
const SOURCE := """extends Node


@rpc("any_peer", "call_local", "reliable")
func take_damage(amount: int) -> void:
	print(amount)


func heal(amount: int) -> void:
	print(amount)
"""


static func run() -> bool:
	var ok: bool = true
	ok = _test_the_words_table_runs_both_ways() and ok
	ok = _test_what_an_annotation_says() and ok
	ok = _test_an_option_godot_does_not_take() and ok
	ok = _test_the_dialog_writes_the_annotation() and ok
	ok = _test_an_unchanged_answer_changes_no_bytes() and ok
	ok = _test_a_changed_answer_writes_the_new_line() and ok
	ok = _test_only_marked_functions_are_messages() and ok
	ok = _test_the_send_dialog_maps_to_the_three_ids() and ok
	ok = _test_what_the_two_dialogs_read_as() and ok
	return ok


# ── the words ───────────────────────────────────────────────────────────────────────────────────


static func _test_the_words_table_runs_both_ways() -> bool:
	var ok: bool = true
	for pinned: Array in [
		["any_peer", "from anyone", EventSheetMessageFacts.FIELD_SENDER],
		["authority", "from the owner", EventSheetMessageFacts.FIELD_SENDER],
		["call_remote", "on the others", EventSheetMessageFacts.FIELD_WHERE],
		["call_local", "also here", EventSheetMessageFacts.FIELD_WHERE],
		["reliable", "reliable", EventSheetMessageFacts.FIELD_DELIVERY],
		["unreliable", "fast, may drop", EventSheetMessageFacts.FIELD_DELIVERY],
		["unreliable_ordered", "fast, in order", EventSheetMessageFacts.FIELD_DELIVERY]
	]:
		ok = _check("%s reads as its word" % str(pinned[0]),
			EventSheetMessageFacts.word_for_option(str(pinned[0])), str(pinned[1])) and ok
		ok = _check("...and \"%s\" writes it back" % str(pinned[1]),
			EventSheetMessageFacts.option_for_word(str(pinned[1])), str(pinned[0])) and ok
		ok = _check("...and %s answers \"%s\"" % [str(pinned[0]), str(pinned[2])],
			EventSheetMessageFacts.field_of_option(str(pinned[0])), str(pinned[2])) and ok
	ok = _check("a string that is not an option has no word",
		EventSheetMessageFacts.word_for_option("whenever"), "") and ok
	ok = _check("a word that is not one of ours writes no option",
		EventSheetMessageFacts.option_for_word("quickly"), "") and ok
	# The dropdown's index and the value it stands for, both directions - a field the annotation left
	# out selects Godot's own default rather than falling off the list.
	ok = _check("the delivery list selects what it was given",
		EventSheetMessageFacts.choice_index(EventSheetMessageFacts.FIELD_DELIVERY, "unreliable_ordered"), 2) and ok
	ok = _check("...and an unnamed field selects Godot's default",
		EventSheetMessageFacts.choice_value(EventSheetMessageFacts.FIELD_DELIVERY,
			EventSheetMessageFacts.choice_index(EventSheetMessageFacts.FIELD_DELIVERY, "")), "unreliable") and ok
	# Every choice carries the line the dialog shows under it - a dropdown that describes nothing is
	# the dropdown this design replaced.
	for field: String in [EventSheetMessageFacts.FIELD_SENDER, EventSheetMessageFacts.FIELD_WHERE,
			EventSheetMessageFacts.FIELD_DELIVERY]:
		for choice: Dictionary in EventSheetMessageFacts.choices(field):
			ok = _check("%s / %s describes itself" % [field, str(choice.get("label", ""))],
				str(choice.get("description", "")).length() > 60, true) and ok
	ok = _check("the channel field explains itself",
		EventSheetMessageFacts.field_help(EventSheetMessageFacts.FIELD_CHANNEL).length() > 60, true) and ok
	return ok


static func _test_what_an_annotation_says() -> bool:
	var ok: bool = true
	var said: Dictionary = EventSheetMessageFacts.parse("@rpc(\"any_peer\", \"call_local\", \"reliable\", 2)")
	ok = _check("who may send", str(said.get(EventSheetMessageFacts.FIELD_SENDER, "")), "any_peer") and ok
	ok = _check("where it runs", str(said.get(EventSheetMessageFacts.FIELD_WHERE, "")), "call_local") and ok
	ok = _check("how it travels", str(said.get(EventSheetMessageFacts.FIELD_DELIVERY, "")), "reliable") and ok
	ok = _check("which channel", int(said.get("channel", 0)), 2) and ok
	ok = _check("the row reads it in order",
		EventSheetMessageFacts.words("@rpc(\"any_peer\", \"call_local\", \"reliable\")"),
		"from anyone · also here · reliable") and ok
	# A field the annotation leaves out is Godot's default, and a row says what the FILE says: it
	# never invents the two words the author did not write.
	ok = _check("a partial annotation says only what it says",
		EventSheetMessageFacts.words("@rpc(\"any_peer\")"), "from anyone") and ok
	ok = _check("...and leaves the rest absent rather than defaulted",
		EventSheetMessageFacts.parse("@rpc(\"any_peer\")").has(EventSheetMessageFacts.FIELD_DELIVERY), false) and ok
	ok = _check("an @rpc naming no option says nothing",
		EventSheetMessageFacts.words("@rpc()"), "") and ok
	ok = _check("a bare @rpc says nothing either",
		EventSheetMessageFacts.words("@rpc"), "") and ok
	ok = _check("and a line that is not an @rpc is not a message",
		EventSheetMessageFacts.words("@export var hp := 100"), "") and ok
	return ok


static func _test_an_option_godot_does_not_take() -> bool:
	var ok: bool = true
	var strange: String = "@rpc(\"any_peer\", \"whenever\")"
	ok = _check("the strange option is collected",
		(EventSheetMessageFacts.parse(strange).get("unknown", PackedStringArray()) as PackedStringArray),
		PackedStringArray(["\"whenever\""])) and ok
	ok = _check("the note names it",
		EventSheetMessageFacts.unknown_note(strange).contains("\"whenever\""), true) and ok
	ok = _check("a readable annotation earns no note",
		EventSheetMessageFacts.unknown_note("@rpc(\"any_peer\")"), "") and ok
	# The row shows the annotation itself rather than a half-reading, so the words must not stand as
	# a claim about a line the sheet could not read.
	ok = _check("an unreadable annotation never MEANS an answer",
		EventSheetMessageFacts.means(strange, EventSheetMessageFacts.NEW_MESSAGE), false) and ok
	return ok


# ── what the dialog writes ──────────────────────────────────────────────────────────────────────


static func _test_the_dialog_writes_the_annotation() -> bool:
	var ok: bool = true
	ok = _check("a new message writes the safe answer",
		EventSheetMessageFacts.annotation_line(EventSheetMessageFacts.NEW_MESSAGE),
		"@rpc(\"authority\", \"call_local\", \"reliable\")") and ok
	var channelled: Dictionary = EventSheetMessageFacts.NEW_MESSAGE.duplicate()
	channelled["channel"] = 3
	ok = _check("a channel that is not 0 is written",
		EventSheetMessageFacts.annotation_line(channelled),
		"@rpc(\"authority\", \"call_local\", \"reliable\", 3)") and ok
	ok = _check("channel 0 is what an annotation without one means, so it is not written",
		EventSheetMessageFacts.annotation_line(EventSheetMessageFacts.NEW_MESSAGE).contains(", 0"), false) and ok
	# The byte-exact rule, at the line level: an answer that still MEANS what the file said hands the
	# original spelling back, however that file spelled it.
	ok = _check("a partial annotation the answers agree with comes back verbatim",
		EventSheetMessageFacts.rewrite("@rpc(\"any_peer\")", {
			EventSheetMessageFacts.FIELD_SENDER: "any_peer",
			EventSheetMessageFacts.FIELD_WHERE: "call_remote",
			EventSheetMessageFacts.FIELD_DELIVERY: "unreliable",
			"channel": 0
		}), "@rpc(\"any_peer\")") and ok
	ok = _check("...and a real change writes the canonical form",
		EventSheetMessageFacts.rewrite("@rpc(\"any_peer\")", EventSheetMessageFacts.NEW_MESSAGE),
		"@rpc(\"authority\", \"call_local\", \"reliable\")") and ok
	# The other annotations a function carries are the author's, and stay where they were.
	var stacked: EventFunction = EventFunction.new()
	stacked.function_name = "take_damage"
	stacked.annotation_lines = PackedStringArray(["@warning_ignore(\"unused_parameter\")", "@rpc(\"any_peer\")"])
	ok = _check("marking a message leaves the other annotations alone",
		EventSheetMessageFacts.annotation_lines_with(stacked, EventSheetMessageFacts.NEW_MESSAGE),
		PackedStringArray(["@warning_ignore(\"unused_parameter\")",
			"@rpc(\"authority\", \"call_local\", \"reliable\")"])) and ok
	var plain: EventFunction = EventFunction.new()
	plain.function_name = "heal"
	ok = _check("a function that was not a message gains the line",
		EventSheetMessageFacts.annotation_lines_with(plain, EventSheetMessageFacts.NEW_MESSAGE),
		PackedStringArray(["@rpc(\"authority\", \"call_local\", \"reliable\")"])) and ok
	return ok


static func _test_an_unchanged_answer_changes_no_bytes() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = GDScriptImporter.new().import_external_source(SOURCE)
	var before: String = _compiled(sheet, "user://_message_rt_a.gd")
	var message: EventFunction = _function(sheet, "take_damage")
	if message == null:
		return _check("the message opens as a function", false, true)
	ok = _check("the annotation opens verbatim", EventSheetMessageFacts.annotation_of(message),
		"@rpc(\"any_peer\", \"call_local\", \"reliable\")") and ok
	ok = _check("...and the row reads it in words", EventSheetMessageFacts.words(
		EventSheetMessageFacts.annotation_of(message)), "from anyone · also here · reliable") and ok
	# Exactly what pressing OK on an untouched Message dialog does.
	var answers: Dictionary = EventSheetMessageFacts.parse(EventSheetMessageFacts.annotation_of(message))
	message.annotation_lines = EventSheetMessageFacts.annotation_lines_with(message, answers)
	ok = _check("confirming an unchanged message writes the same annotation",
		EventSheetMessageFacts.annotation_of(message),
		"@rpc(\"any_peer\", \"call_local\", \"reliable\")") and ok
	ok = _check("...and the file re-emits byte for byte",
		_compiled(sheet, "user://_message_rt_b.gd"), before) and ok
	return ok


static func _test_a_changed_answer_writes_the_new_line() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = GDScriptImporter.new().import_external_source(SOURCE)
	var message: EventFunction = _function(sheet, "take_damage")
	if message == null:
		return _check("the message opens as a function", false, true)
	message.annotation_lines = EventSheetMessageFacts.annotation_lines_with(
		message, EventSheetMessageFacts.NEW_MESSAGE)
	var written: String = _compiled(sheet, "user://_message_rt_c.gd")
	ok = _check("the new annotation reaches the file",
		written.contains("@rpc(\"authority\", \"call_local\", \"reliable\")"), true) and ok
	ok = _check("...and the old one is gone",
		written.contains("\"any_peer\""), false) and ok
	# And the changed file still opens as the same message, now reading the new words: the write and
	# the read are the same table, so a value that survives one has to survive the other.
	var reopened: EventFunction = _function(
		GDScriptImporter.new().import_external_source(written), "take_damage")
	ok = _check("the changed message opens again", reopened != null, true) and ok
	if reopened != null:
		ok = _check("...reading the answer that was picked", EventSheetMessageFacts.words(
			EventSheetMessageFacts.annotation_of(reopened)),
			"from the owner · also here · reliable") and ok
	return ok


# ── which functions are messages, and how one is sent ───────────────────────────────────────────


static func _test_only_marked_functions_are_messages() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = GDScriptImporter.new().import_external_source(SOURCE)
	var listed: Array[Dictionary] = EventSheetMessageFacts.messages_in(sheet)
	ok = _check("only the marked function is a message", listed.size(), 1) and ok
	if listed.is_empty():
		return ok
	ok = _check("...named as the file names it", str(listed[0].get("name", "")), "take_damage") and ok
	ok = _check("...with its parameters, in order",
		(listed[0].get("params", PackedStringArray()) as PackedStringArray),
		PackedStringArray(["amount"])) and ok
	ok = _check("...and the words its annotation reads as",
		str(listed[0].get("words", "")), "from anyone · also here · reliable") and ok
	ok = _check("the plain helper is not offered",
		EventSheetMessageFacts.is_message(_function(sheet, "heal")), false) and ok
	# The public list a pack building its own send surface reads is the very same one.
	ok = _check("the public API answers the same list",
		EventSheets.sheet_messages(sheet).size(), 1) and ok
	ok = _check("the public API writes the annotation through the same byte-exact rule",
		EventSheets.message_annotation("@rpc(\"any_peer\")", {
			EventSheetMessageFacts.FIELD_SENDER: "any_peer",
			EventSheetMessageFacts.FIELD_WHERE: "call_remote",
			EventSheetMessageFacts.FIELD_DELIVERY: "unreliable",
			"channel": 0
		}), "@rpc(\"any_peer\")") and ok
	# What the Send dialog asks for, and the warning it shows for a name that is not a message yet.
	ok = _check("a Send row asks for the message's own parameters",
		EventSheetMessageDialog.message_parameters(sheet, "take_damage"),
		PackedStringArray(["amount"])) and ok
	ok = _check("a marked message earns no warning",
		EventSheetMessageDialog.unmarked_message_note(sheet, "take_damage"), "") and ok
	ok = _check("an unmarked function does",
		EventSheetMessageDialog.unmarked_message_note(sheet, "heal").contains("heal"), true) and ok
	return ok


static func _test_the_send_dialog_maps_to_the_three_ids() -> bool:
	var ok: bool = true
	var choices: Array[Dictionary] = EventSheetMessageFacts.send_choices()
	ok = _check("the To dropdown offers three answers", choices.size(), 3) and ok
	for index: int in choices.size():
		ok = _check("%s describes itself" % str(choices[index].get("label", "")),
			str(choices[index].get("description", "")).length() > 40, true) and ok
		ok = _check("...and index %d maps back to its id" % index,
			EventSheetMessageFacts.send_index(EventSheetMessageFacts.send_ace_id(index)), index) and ok
	ok = _check("Everyone is the shipped everyone action", str(choices[0].get("value", "")),
		EventSheetMessageFacts.SEND_TO_EVERYONE) and ok
	ok = _check("The host is the shipped host action", str(choices[1].get("value", "")),
		EventSheetMessageFacts.SEND_TO_HOST) and ok
	ok = _check("One player is the shipped peer action", str(choices[2].get("value", "")),
		EventSheetMessageFacts.SEND_TO_PEER) and ok
	# Only the peer row carries a peer - one params shape for all three, so the dialog never has to
	# know which of them takes one.
	ok = _check("only One player carries a player id",
		EventSheetMessageFacts.send_params(EventSheetMessageFacts.SEND_TO_HOST, "take_damage", "10", "3").has("peer"),
		false) and ok
	# The lines, built by the compiler's own action codegen off the frozen templates.
	for pinned: Array in [
		[EventSheetMessageFacts.SEND_TO_EVERYONE, "10", "1", "take_damage.rpc(10)"],
		[EventSheetMessageFacts.SEND_TO_HOST, "10", "1", "take_damage.rpc_id(1, 10)"],
		[EventSheetMessageFacts.SEND_TO_PEER, "10", "Multiplayer.Sender", "take_damage.rpc_id(Multiplayer.Sender, 10)"],
		[EventSheetMessageFacts.SEND_TO_HOST, "", "1", "take_damage.rpc_id(1)"]
	]:
		ok = _check("%s writes %s" % [str(pinned[0]), str(pinned[3])],
			EventSheetMessageFacts.send_code_line(str(pinned[0]), "take_damage", str(pinned[1]), str(pinned[2])),
			str(pinned[3])) and ok
	return ok


static func _test_what_the_two_dialogs_read_as() -> bool:
	var ok: bool = true
	ok = _check("the Message dialog reads as the row it writes",
		EventSheetMessageDialog.message_reading("take_damage", PackedStringArray(["amount"]),
			"@rpc(\"authority\", \"call_local\", \"reliable\")"),
		"message take_damage(amount)  from the owner · also here · reliable") and ok
	ok = _check("a message with no options named reads as itself alone",
		EventSheetMessageDialog.message_reading("ping", PackedStringArray(), "@rpc()"),
		"message ping()") and ok
	# The Send reading is filled from the very display text the ROW is drawn from, so the strip
	# cannot promise a sentence the canvas will not show.
	ok = _check("the Send dialog reads as its own row",
		EventSheetMessageDialog.send_reading(EventSheetMessageFacts.SEND_TO_HOST, "take_damage", "10", "1"),
		"Send take_damage to the host 10") and ok
	return ok


# ── helpers ─────────────────────────────────────────────────────────────────────────────────────


static func _compiled(sheet: EventSheetResource, path: String) -> String:
	return str(SheetCompiler.compile(sheet, path).get("output", ""))


static func _function(sheet: EventSheetResource, function_name: String) -> EventFunction:
	if sheet == null:
		return null
	for entry: Variant in sheet.functions:
		if entry is EventFunction and (entry as EventFunction).function_name == function_name:
			return entry as EventFunction
	return null


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] multiplayer_messages_test: %s" % label)
		return true
	print("[FAIL] multiplayer_messages_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
