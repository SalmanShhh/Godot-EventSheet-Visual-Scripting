# Testing a networked game as two players, and the four mistakes the Doctor knows.
#
# Pinned by VALUE, in the order the failures would matter:
#   the SETTING - exactly what "Play as host + client" writes into the editor's own Run Instances
#   metadata, what it leaves alone, and what it reads back out of a state somebody else set;
#   the CHIPS - what one variable's row says while one copy of the game streams, and while two do;
#   the FOUR RULES - each finding earned by a sheet that makes that mistake, and NOT earned by the
#   same sheet with the mistake fixed (a rule that only ever says yes is not a rule);
#   the GATE - a sheet that says nothing about the network earns nothing at all, which is what
#   keeps a single-player project exactly as it was;
#   the SECTION - the Doctor's summary line over a real corpus, the lines it could only show as
#   code, and the fact that it is registered through the public seam rather than built in.
@tool
class_name MultiplayerTestingTest
extends RefCounted

## The scene half of the fixture: a Player whose synchronizer keeps position, hp, stamina and
## nickname in step. The findings that ask "does anybody else ever see this?" are answered from it.
const PLAYER_SCRIPT: String = "res://tests/fixtures/multiplayer_scene_player.gd"
const AUTOLOAD_FIXTURE: String = "res://tests/fixtures/multiplayer_network_autoload.gd"


static func run() -> bool:
	EventSheetSceneReplication.clear_cache()
	var ok: bool = true
	ok = _test_what_the_button_writes() and ok
	ok = _test_what_each_instance_is_called() and ok
	ok = _test_the_live_value_chips() and ok
	ok = _test_sent_but_not_a_message() and ok
	ok = _test_changed_on_the_host() and ok
	ok = _test_moved_by_everyone() and ok
	ok = _test_trusting_the_sender() and ok
	ok = _test_a_single_player_sheet_earns_nothing() and ok
	ok = _test_the_doctor_section() and ok
	EventSheetSceneReplication.clear_cache()
	return ok


# -- The setting the button writes ----------------------------------------------------------


static func _test_what_the_button_writes() -> bool:
	var ok: bool = true
	var written: Array = EventSheetRunInstances.config_with_tags([], EventSheetRunInstances.TEST_TAGS)
	ok = _check("two tags become two instances", written.size(), 2) and ok
	ok = _check("the first is the host",
		_entry(written, 0), "override_features=true features=host") and ok
	ok = _check("the second is the client",
		_entry(written, 1), "override_features=true features=client") and ok
	# Only the tags are ours to say: an instance somebody gave launch arguments keeps them.
	var kept: Array = EventSheetRunInstances.config_with_tags(
		[{"override_args": true, "arguments": "--verbose"}], PackedStringArray(["host"]))
	ok = _check("whatever else an instance was given is carried over",
		_entry(kept, 0),
		"override_args=true arguments=--verbose override_features=true features=host") and ok
	# An editor already set up this way is not changed by pressing the button again.
	var already: Dictionary = {
		EventSheetRunInstances.KEY_ENABLED: true,
		EventSheetRunInstances.KEY_COUNT: 2,
		EventSheetRunInstances.KEY_CONFIG: EventSheetRunInstances.config_with_tags(
			[], EventSheetRunInstances.TEST_TAGS)
	}
	ok = _check("a state the button already wrote reads back as on",
		EventSheetRunInstances.says_tags(already, EventSheetRunInstances.TEST_TAGS), true) and ok
	ok = _check("one instance is not the host-and-client state",
		EventSheetRunInstances.says_tags({
			EventSheetRunInstances.KEY_ENABLED: true,
			EventSheetRunInstances.KEY_COUNT: 1,
			EventSheetRunInstances.KEY_CONFIG: []
		}, EventSheetRunInstances.TEST_TAGS), false) and ok
	ok = _check("two instances with the setting switched off is not it either",
		EventSheetRunInstances.says_tags({
			EventSheetRunInstances.KEY_ENABLED: false,
			EventSheetRunInstances.KEY_COUNT: 2,
			EventSheetRunInstances.KEY_CONFIG: already[EventSheetRunInstances.KEY_CONFIG]
		}, EventSheetRunInstances.TEST_TAGS), false) and ok
	# The tooltip is the only place a reader is told this is Godot's own setting and how to undo it.
	ok = _check("the tooltip names the menu that turns it off",
		EventSheetRunInstances.tooltip().contains("Run Multiple Instances"), true) and ok
	ok = _check("outside the editor there is nothing to write to",
		EventSheetRunInstances.apply_tags(EventSheetRunInstances.TEST_TAGS).get("ok"), false) and ok
	return ok


static func _test_what_each_instance_is_called() -> bool:
	var ok: bool = true
	var stored: Dictionary = {
		EventSheetRunInstances.KEY_ENABLED: true,
		EventSheetRunInstances.KEY_COUNT: 2,
		EventSheetRunInstances.KEY_CONFIG: EventSheetRunInstances.config_with_tags(
			[], EventSheetRunInstances.TEST_TAGS)
	}
	ok = _check("each instance is called by its tag",
		EventSheetRunInstances.labels(stored), PackedStringArray(["host", "client"])) and ok
	ok = _check("an instance with no tag of its own is called by its number",
		EventSheetRunInstances.labels({
			EventSheetRunInstances.KEY_ENABLED: true,
			EventSheetRunInstances.KEY_COUNT: 2,
			EventSheetRunInstances.KEY_CONFIG: []
		}), PackedStringArray(["instance 1", "instance 2"])) and ok
	# Two windows sharing a tag would otherwise wear the same chip, which answers nothing.
	ok = _check("two instances carrying one tag get their numbers",
		EventSheetRunInstances.labels({
			EventSheetRunInstances.KEY_ENABLED: true,
			EventSheetRunInstances.KEY_COUNT: 2,
			EventSheetRunInstances.KEY_CONFIG: EventSheetRunInstances.config_with_tags(
				[], PackedStringArray(["client", "client"]))
		}), PackedStringArray(["client 1", "client 2"])) and ok
	ok = _check("a lone run is not labelled at all",
		EventSheetRunInstances.labels(stored.merged({EventSheetRunInstances.KEY_COUNT: 1}, true)),
		PackedStringArray()) and ok
	# Closing one of the two windows is not the end of the run. The survivor is still the game being
	# debugged, and its chips have to go on saying which window they are describing.
	ok = _check("closing one window leaves the other's label alone",
		EventSheetLiveValuesDebugger.labels_after_stop({0: "host", 1: "client"}, 1), {0: "host"}) and ok
	ok = _check("and closing the last one leaves nothing behind",
		EventSheetLiveValuesDebugger.labels_after_stop({0: "host"}, 0), {}) and ok
	return ok


static func _test_the_live_value_chips() -> bool:
	var ok: bool = true
	ok = _check("one running game says the value and nothing else",
		ViewportLiveValuesHelper.chip_text({"": {"hp": 42}}, "hp"), "now 42") and ok
	ok = _check("two running games each get a chip headed by their tag",
		ViewportLiveValuesHelper.chip_text({"host": {"hp": 100}, "client": {"hp": 90}}, "hp"),
		"host · now 100   client · now 90") and ok
	ok = _check("an instance whose frame does not carry the name says nothing",
		ViewportLiveValuesHelper.chip_text({"host": {"hp": 100}, "client": {"score": 3}}, "hp"),
		"host · now 100") and ok
	ok = _check("a name nothing streams has no chip",
		ViewportLiveValuesHelper.chip_text({"": {"hp": 42}}, "armour"), "") and ok
	return ok


# -- The four rules -------------------------------------------------------------------------


static func _test_sent_but_not_a_message() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = _player_sheet()
	sheet.functions.append(_function("heal", PackedStringArray()))
	sheet.events.append(_event([_send("heal", "5")]))
	var found: Array[Dictionary] = EventSheetMultiplayerFindings.findings(sheet)
	ok = _check("a Send row naming an unmarked function is the finding",
		_kinds(found), PackedStringArray([EventSheetMultiplayerFindings.KIND_NOT_A_MESSAGE])) and ok
	ok = _check("the note names the function and what will happen",
		_message_of(found, EventSheetMultiplayerFindings.KIND_NOT_A_MESSAGE),
		"heal is not a message: nothing will arrive. Mark the function as a message first.") and ok
	ok = _check("its fix opens the Message dialog on that function",
		_fix_of(found, EventSheetMultiplayerFindings.KIND_NOT_A_MESSAGE),
		EventSheetMultiplayerFindings.FIX_MAKE_MESSAGE) and ok
	ok = _check("the note hangs under the event that sends it",
		EventSheetMultiplayerFindings.for_event(found, sheet.events[0] as EventRow).size(), 1) and ok
	# The same sheet with the annotation on it says nothing.
	(sheet.functions[0] as EventFunction).annotation_lines = PackedStringArray(["@rpc(\"authority\", \"call_local\", \"reliable\")"])
	ok = _check("once it is a message the finding is gone",
		_kinds(EventSheetMultiplayerFindings.findings(sheet)), PackedStringArray()) and ok
	# A message on some other object is not this sheet's to judge: it cannot see that annotation.
	var elsewhere: EventSheetResource = _player_sheet()
	elsewhere.events.append(_event([_send("say", "\"hi\"")]))
	ok = _check("a message this sheet does not declare is left alone",
		_kinds(EventSheetMultiplayerFindings.findings(elsewhere)), PackedStringArray()) and ok
	return ok


static func _test_changed_on_the_host() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = _player_sheet()
	sheet.variables["score"] = {"type": "int", "default": 0}
	sheet.functions.append(_function("take_damage", PackedStringArray(
		["@rpc(\"authority\", \"call_local\", \"reliable\")"])))
	var group: EventGroup = EventGroup.new()
	group.group_name = "Scoring"
	group.runs_on = EventGroup.RUNS_ON_HOST
	group.events.append(_event([_set_variable("score", "score + 1")]))
	sheet.events.append(group)
	var found: Array[Dictionary] = EventSheetMultiplayerFindings.findings(sheet)
	ok = _check("a value only the host changes is the finding",
		_kinds(found), PackedStringArray([EventSheetMultiplayerFindings.KIND_HOST_ONLY])) and ok
	ok = _check("the note names the value and both ways out",
		_message_of(found, EventSheetMultiplayerFindings.KIND_HOST_ONLY),
		"score is changed in a group that runs on the host, but only the host will see the new value. Keep it in step, or send it.") and ok
	ok = _check("its fix hands the value to a synchronizer",
		_fix_of(found, EventSheetMultiplayerFindings.KIND_HOST_ONLY),
		EventSheetMultiplayerFindings.FIX_KEEP_IN_STEP) and ok
	ok = _check("the note hangs under the value's own declaration",
		EventSheetMultiplayerFindings.for_subject(found,
			EventSheetMultiplayerFindings.ANCHOR_VARIABLE, "score").size(), 1) and ok
	# `hp` IS kept in step by the scene's synchronizer, so changing it on the host is fine.
	group.events.append(_event([_set_variable("hp", "hp - 1")]))
	ok = _check("a value the scene keeps in step earns nothing",
		_kinds(EventSheetMultiplayerFindings.findings(sheet)),
		PackedStringArray([EventSheetMultiplayerFindings.KIND_HOST_ONLY])) and ok
	return ok


static func _test_moved_by_everyone() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = _player_sheet()
	sheet.functions.append(_function("take_damage", PackedStringArray(
		["@rpc(\"authority\", \"call_local\", \"reliable\")"])))
	var moving: EventRow = _event([_moves()])
	sheet.events.append(moving)
	var found: Array[Dictionary] = EventSheetMultiplayerFindings.findings(sheet)
	ok = _check("moving a synced object on every peer is the finding",
		_kinds(found), PackedStringArray([EventSheetMultiplayerFindings.KIND_EVERYONE_MOVES])) and ok
	ok = _check("the note names the row and where the event belongs",
		_message_of(found, EventSheetMultiplayerFindings.KIND_EVERYONE_MOVES),
		"Set Position runs on every peer, and only the owner of this object should move it. Put the event in a group that runs on the owner.") and ok
	ok = _check("its fix wraps the event in an owner group",
		_fix_of(found, EventSheetMultiplayerFindings.KIND_EVERYONE_MOVES),
		EventSheetMultiplayerFindings.FIX_OWNER_GROUP) and ok
	# The same row inside an owner group, and the same row under an authority check, are both fine.
	var owned: EventGroup = EventGroup.new()
	owned.group_name = "Mine"
	owned.runs_on = EventGroup.RUNS_ON_OWNER
	owned.events.append(moving)
	sheet.events.clear()
	sheet.events.append(owned)
	ok = _check("inside a group that runs on the owner it earns nothing",
		_kinds(EventSheetMultiplayerFindings.findings(sheet)), PackedStringArray()) and ok
	var guarded: EventRow = _event([_moves()])
	var check: ACECondition = ACECondition.new()
	check.provider_id = "Core"
	check.ace_id = "OwnsThisObject"
	guarded.conditions.append(check)
	sheet.events.clear()
	sheet.events.append(guarded)
	ok = _check("an event that asks whether it owns the object earns nothing",
		_kinds(EventSheetMultiplayerFindings.findings(sheet)), PackedStringArray()) and ok
	# The rule reads the LINE, so a row that only compares a position is not a row that moves one.
	ok = _check("an assignment to position moves the body",
		EventSheetMultiplayerFindings.moves_the_body("{target}.position = {value}"), true) and ok
	ok = _check("move_and_slide moves the body",
		EventSheetMultiplayerFindings.moves_the_body("move_and_slide()"), true) and ok
	ok = _check("reading a position does not move it",
		EventSheetMultiplayerFindings.moves_the_body("if position.x == {value}:"), false) and ok
	ok = _check("a member that merely ends in the word does not count",
		EventSheetMultiplayerFindings.moves_the_body("start_position = {value}"), false) and ok
	return ok


static func _test_trusting_the_sender() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = _player_sheet()
	var message: EventFunction = _function("take_damage", PackedStringArray(
		["@rpc(\"any_peer\", \"call_local\", \"reliable\")"]))
	message.events.append(_event([_set_variable("hp", "hp - 10")]))
	sheet.functions.append(message)
	var found: Array[Dictionary] = EventSheetMultiplayerFindings.findings(sheet)
	ok = _check("a message anyone may send that writes a synced value is the finding",
		_kinds(found), PackedStringArray([EventSheetMultiplayerFindings.KIND_TRUSTS_SENDER])) and ok
	ok = _check("the note names the message and the value it writes",
		_message_of(found, EventSheetMultiplayerFindings.KIND_TRUSTS_SENDER),
		"take_damage may be sent by anyone, and it writes hp without asking who sent it. Any player could send it themselves.") and ok
	ok = _check("this one has no one-click answer",
		_fix_of(found, EventSheetMultiplayerFindings.KIND_TRUSTS_SENDER), "") and ok
	ok = _check("the note hangs under the message's own head",
		EventSheetMultiplayerFindings.for_subject(found,
			EventSheetMultiplayerFindings.ANCHOR_FUNCTION, "take_damage").size(), 1) and ok
	# Asking who sent it is the whole point, however the question is written.
	var asking: ACECondition = ACECondition.new()
	asking.provider_id = "Core"
	asking.ace_id = "CompareVar"
	asking.params = {"var_name": "multiplayer.get_remote_sender_id()", "value": "1"}
	(message.events[0] as EventRow).conditions.append(asking)
	ok = _check("a message that checks the sender earns nothing",
		_kinds(EventSheetMultiplayerFindings.findings(sheet)), PackedStringArray()) and ok
	return ok


static func _test_a_single_player_sheet_earns_nothing() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = _player_sheet()
	sheet.variables["score"] = {"type": "int", "default": 0}
	var group: EventGroup = EventGroup.new()
	group.group_name = "Scoring"
	group.runs_on = EventGroup.RUNS_ON_HOST
	group.events.append(_event([_set_variable("score", "score + 1")]))
	sheet.events.append(group)
	# The group alone says nothing about the network in the census's terms, and neither does the
	# row: no message, no multiplayer vocabulary, so a project that never hosts grows no notes.
	ok = _check("a sheet with no networking line in it is never judged",
		_kinds(EventSheetMultiplayerFindings.findings(_player_sheet())), PackedStringArray()) and ok
	ok = _check("a synced variable alone is not a reason to start",
		int(EventSheetReadingCoverage.networking(_player_sheet()).get("total", 0)), 0) and ok
	return ok


# -- The Doctor's section -------------------------------------------------------------------


static func _test_the_doctor_section() -> bool:
	var ok: bool = true
	EventSheetMultiplayerDoctor.ensure_registered()
	var registered: int = 0
	for entry: Dictionary in EventSheetProjectDoctor._extension_checks:
		if str(entry.get("id", "")) == EventSheetMultiplayerDoctor.CHECK_ID:
			registered += 1
	# Registering twice would run the section twice; the seam replaces by id, and this is what
	# proves it (ensure_registered has now been called at least once by the Doctor and once here).
	ok = _check("the section is registered through the public seam, exactly once",
		registered, 1) and ok
	var report: Array[Dictionary] = EventSheetMultiplayerDoctor.report(
		PackedStringArray([AUTOLOAD_FIXTURE]))
	ok = _check("the section leads with its summary",
		str(report[0].get("check", "")), EventSheetMultiplayerDoctor.CHECK_ID) and ok
	ok = _check("the summary counts the scripts that touch the network",
		str(report[0].get("message", "")).contains("1 script(s) touch the network"), true) and ok
	ok = _check("a corpus with nothing networked in it reports nothing at all",
		EventSheetMultiplayerDoctor.report(PackedStringArray()).size(), 0) and ok
	# A script block the sheet could not claim is what the Adopt offer is made over.
	var blocked: EventSheetResource = EventSheetResource.new()
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
multiplayer.multiplayer_peer = peer"
	blocked.events.append(block)
	# Only the NETWORKING lines of the block are listed: ENet's own compression is a line about a
	# library, and the sheet never claimed to have a row for it.
	ok = _check("the networking lines a sheet can only show as code are listed for adopting",
		EventSheetMultiplayerDoctor.unread_lines(blocked),
		PackedStringArray(["multiplayer.multiplayer_peer = peer"])) and ok
	var reading: Array[Dictionary] = EventSheetMultiplayerDoctor.script_findings(
		"res://lobby.gd", blocked)
	ok = _check("and that script gets its own line in the section",
		_checks(reading), PackedStringArray([EventSheetMultiplayerDoctor.CHECK_READING])) and ok
	ok = _check("the line says how much read and names the first that did not",
		str(reading[0].get("message", "")),
		"lobby.gd reads 0% of its networking as rows - 1 line(s) stay code. First: multiplayer.multiplayer_peer = peer") and ok
	# The offer on that line is the row's own Adopt, named where the reader can reach it.
	ok = _check("a reading line offers Adopt", EventSheetQuickFixes.fixes_for(
		{"check": EventSheetMultiplayerDoctor.CHECK_READING}).size(), 1) and ok
	ok = _check("an unmarked message offers the Message dialog", EventSheetQuickFixes.fixes_for(
		{"check": EventSheetMultiplayerDoctor.CHECK_MESSAGE, "subject": "heal"})[0].get("label"),
		"Make heal a message…") and ok
	return ok


# -- the fixture pieces -------------------------------------------------------------------------


## A sheet standing for `multiplayer_scene_player.gd`, whose scene keeps position, hp, stamina and
## nickname in step. Built in memory rather than lifted, so each rule is pinned by what it reads
## rather than by what the importer happened to make of a file.
static func _player_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.external_source_path = PLAYER_SCRIPT
	sheet.variables = {
		"hp": {"type": "int", "default": 100},
		"armour": {"type": "int", "default": 0}
	}
	return sheet


static func _event(actions: Array) -> EventRow:
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	for action: Variant in actions:
		event.actions.append(action as Resource)
	return event


static func _function(name_text: String, annotations: PackedStringArray) -> EventFunction:
	var event_function: EventFunction = EventFunction.new()
	event_function.function_name = name_text
	event_function.annotation_lines = annotations
	return event_function


static func _send(message: String, args: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = EventSheetMessageFacts.PROVIDER
	action.ace_id = EventSheetMessageFacts.SEND_TO_EVERYONE
	action.params = {"message": message, "args": args}
	return action


static func _set_variable(name_text: String, value: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "SetVar"
	action.params = {"var_name": name_text, "value": value}
	return action


static func _moves() -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "SetPosition2D"
	action.params = {"pos": "Vector2(10, 0)"}
	return action


## One instance's config written out flat, so the assertion pins the KEYS and the VALUES rather
## than a Dictionary's printed form.
static func _entry(config: Array, index: int) -> String:
	if index >= config.size() or not (config[index] is Dictionary):
		return "(no instance %d)" % index
	var parts: PackedStringArray = PackedStringArray()
	for key: Variant in (config[index] as Dictionary):
		parts.append("%s=%s" % [str(key), str((config[index] as Dictionary)[key])])
	return " ".join(parts)


static func _kinds(found: Array[Dictionary]) -> PackedStringArray:
	var kinds: PackedStringArray = PackedStringArray()
	for finding: Dictionary in found:
		kinds.append(str(finding.get("kind", "")))
	return kinds


static func _checks(findings: Array[Dictionary]) -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for finding: Dictionary in findings:
		ids.append(str(finding.get("check", "")))
	return ids


static func _message_of(found: Array[Dictionary], kind: String) -> String:
	for finding: Dictionary in found:
		if str(finding.get("kind", "")) == kind:
			return str(finding.get("message", ""))
	return "(no finding of that kind)"


static func _fix_of(found: Array[Dictionary], kind: String) -> String:
	for finding: Dictionary in found:
		if str(finding.get("kind", "")) == kind:
			return str(finding.get("fix", ""))
	return "(no finding of that kind)"


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] multiplayer_testing_test: %s" % label)
		return true
	print("[FAIL] multiplayer_testing_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
