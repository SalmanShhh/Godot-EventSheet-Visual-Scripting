@tool
class_name MultiplayerVocabularyTest
extends RefCounted
# The rest of Godot's high-level multiplayer as rows, and the one word that says who
# runs a group.
#
# Two halves, pinned by VALUE rather than by count so a wording change is visible here rather than
# silently green:
#   the VOCABULARY - the lobby actions, the handshake, what a script asks about the connection, and
#   the two triggers the handshake fires - each pinned to the exact Godot call it compiles to, plus
#   the help-strip paragraphs and the option lines that explain the networking fields;
#   RUNS_ON - a group answering "who runs this" once instead of an Is host condition on every event.
#   Its whole contract is that a sheet WITHOUT it compiles to exactly what it compiled to before,
#   and a sheet with it round-trips through the .gd byte for byte, guard and all.

const SUPPORT := preload("res://tests/support.gd")
const GDScriptImporter := preload("res://addons/eventforge/importer/gdscript_importer.gd")
const FieldFactory := preload("res://addons/eventsheet/editor/ace_dialog/param_field_factory.gd")


static func run() -> bool:
	var ok: bool = true
	ok = _test_the_lobby_and_the_handshake() and ok
	ok = _test_what_a_script_asks() and ok
	ok = _test_the_two_new_triggers() and ok
	ok = _test_the_lines_that_already_have_a_row() and ok
	ok = _test_the_help_strip_explains_the_network_fields() and ok
	ok = _test_the_picker_shelves() and ok
	ok = _test_runs_on_is_one_table() and ok
	ok = _test_runs_on_compiles_to_the_guard() and ok
	ok = _test_runs_on_round_trips() and ok
	ok = _test_runs_on_folds_the_conditions_it_replaces() and ok
	return ok


# ── the vocabulary ──────────────────────────────────────────────────────────────────────────────


static func _test_the_lobby_and_the_handshake() -> bool:
	var ok: bool = true
	for pinned: Array in [
		["KickPlayer", "multiplayer.multiplayer_peer.disconnect_peer({id})", "Kick player {id}"],
		["StopAcceptingPlayers", "multiplayer.multiplayer_peer.refuse_new_connections = true", "Stop accepting players"],
		["SetRelay", "multiplayer.server_relay = {on}", "Relay messages between players {on}"],
		["AcceptPlayer", "multiplayer.complete_auth({id})", "Accept player {id}"],
		["RejectPlayer", "multiplayer.multiplayer_peer.disconnect_peer({id})", "Reject player {id}"],
		["SendAuth", "multiplayer.send_auth({id}, {data})", "Send auth {data} to player {id}"],
		["GiveAuthority", "{target}.set_multiplayer_authority({id})", "Give {target} to player {id}"]
	]:
		var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", str(pinned[0]))
		if descriptor == null:
			ok = _check("%s is registered" % str(pinned[0]), false, true)
			continue
		ok = _check("%s writes its Godot call" % str(pinned[0]), descriptor.codegen_template, str(pinned[1])) and ok
		ok = _check("%s reads as a sentence" % str(pinned[0]), descriptor.display_text, str(pinned[2])) and ok
		ok = _check("%s is an action" % str(pinned[0]), int(descriptor.ace_type), int(ACEDescriptor.ACEType.ACTION)) and ok
		ok = _check("%s is filed under Multiplayer" % str(pinned[0]), descriptor.category, EventForgeMultiplayerACEs.CATEGORY) and ok
		ok = _check("%s says what it is for" % str(pinned[0]), descriptor.description.length() > 40, true) and ok
		for parameter: ACEParam in descriptor.params:
			ok = _check("%s.%s describes itself" % [str(pinned[0]), parameter.id],
				parameter.description.length() > 20, true) and ok
	# The relay dropdown says the words, and the line still assigns the boolean.
	var relay: ACEDescriptor = ACERegistry.find_descriptor("Core", "SetRelay")
	ok = _check("the relay dropdown reads in words on the row",
		relay != null and relay.params[0].display_option_labels, true) and ok
	ok = _check("...while the value it writes is the boolean",
		FieldFactory.option_notes({"options": relay.params[0].options}).has("false"), true) and ok
	return ok


static func _test_what_a_script_asks() -> bool:
	var ok: bool = true
	var connected: ACEDescriptor = ACERegistry.find_descriptor("Core", "IsConnected")
	if connected == null:
		return _check("Is connected is registered", false, true)
	ok = _check("Is connected asks Godot's own two questions", connected.codegen_template,
		"(multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED)") and ok
	# The brackets are the point: without them the row's own `and` would rebind the moment it sits
	# beside another condition in an Or block.
	ok = _check("...as ONE bracketed term", connected.codegen_template.begins_with("(") and connected.codegen_template.ends_with(")"), true) and ok
	ok = _check("Is connected is a condition", int(connected.ace_type), int(ACEDescriptor.ACEType.CONDITION)) and ok
	for pinned: Array in [
		["StartedAs", "OS.has_feature({tag})", "Started as {tag}", ACEDescriptor.ACEType.CONDITION],
		["Players", "multiplayer.get_peers()", "Players", ACEDescriptor.ACEType.EXPRESSION],
		["PlayerCount", "multiplayer.get_peers().size()", "Player count", ACEDescriptor.ACEType.EXPRESSION],
		["Sender", "multiplayer.get_remote_sender_id()", "Sender", ACEDescriptor.ACEType.EXPRESSION],
		["OwnerOf", "{target}.get_multiplayer_authority()", "Owner of {target}", ACEDescriptor.ACEType.EXPRESSION]
	]:
		var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", str(pinned[0]))
		if descriptor == null:
			ok = _check("%s is registered" % str(pinned[0]), false, true)
			continue
		ok = _check("%s writes its Godot call" % str(pinned[0]), descriptor.codegen_template, str(pinned[1])) and ok
		ok = _check("%s reads as a sentence" % str(pinned[0]), descriptor.display_text, str(pinned[2])) and ok
		ok = _check("%s is the kind it says" % str(pinned[0]), int(descriptor.ace_type), int(pinned[3])) and ok
	var started: ACEDescriptor = ACERegistry.find_descriptor("Core", "StartedAs")
	ok = _check("Started as offers the three roles first",
		",".join(started.params[0].autocomplete), "\"host\",\"client\",\"dedicated_server\"") and ok
	ok = _check("...through the live export-preset picker", started.params[0].hint, "feature_tag") and ok
	return ok


static func _test_the_two_new_triggers() -> bool:
	var ok: bool = true
	for pinned: Array in [
		["OnPlayerAuthenticating", "peer_authenticating", "On player authenticating {id}"],
		["OnAuthenticationFailed", "peer_authentication_failed", "On authentication failed {id}"]
	]:
		var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", str(pinned[0]))
		if descriptor == null:
			ok = _check("%s is registered" % str(pinned[0]), false, true)
			continue
		ok = _check("%s is a trigger" % str(pinned[0]), int(descriptor.ace_type), int(ACEDescriptor.ACEType.TRIGGER)) and ok
		ok = _check("%s is Godot's own signal" % str(pinned[0]), descriptor.signal_name, str(pinned[1])) and ok
		ok = _check("%s reads as a sentence" % str(pinned[0]), descriptor.display_text, str(pinned[2])) and ok
		# The signal carries the peer id and NOTHING else: a second argument here would be a
		# connection Godot refuses at runtime, because the auth bytes reach the callback, not this.
		var probe: EventRow = EventRow.new()
		probe.trigger_provider_id = "Core"
		probe.trigger_id = str(pinned[0])
		var signature: Dictionary = TriggerResolver.resolve_trigger(probe)
		ok = _check("%s connects on the multiplayer object" % str(pinned[0]),
			str(signature.get("source_path", "")), TriggerResolver.MULTIPLAYER_SOURCE) and ok
		ok = _check("%s takes the peer id alone" % str(pinned[0]), str(signature.get("args", "")), "id: int") and ok
	# A hand-written connect to either signal opens as that trigger.
	ok = _check("a hand-written authenticating connect reads as the trigger",
		str(EventForgeMultiplayerLift.SIGNAL_TRIGGERS.get("peer_authenticating", "")), "OnPlayerAuthenticating") and ok
	ok = _check("...and so does the failure",
		str(EventForgeMultiplayerLift.SIGNAL_TRIGGERS.get("peer_authentication_failed", "")), "OnAuthenticationFailed") and ok
	return ok


static func _test_the_lines_that_already_have_a_row() -> bool:
	# Two of the new rows write a line another row already writes. Admitted to the reverse index they
	# would take turns claiming it, so they author only - which is the codebase's standing answer to a
	# template that is not the clearest reading of its own line.
	var ok: bool = _check("Reject player leaves the bare disconnect line to Kick player",
		EventSheetACELifter.REVERSE_LIFT_EXCLUDED_ACE_IDS.has("RejectPlayer"), true)
	ok = _check("Started as leaves OS.has_feature to Platform Has Feature",
		EventSheetACELifter.REVERSE_LIFT_EXCLUDED_ACE_IDS.has("StartedAs"), true) and ok
	ok = _check("...while Kick player itself still reads back",
		EventSheetACELifter.REVERSE_LIFT_EXCLUDED_ACE_IDS.has("KickPlayer"), false) and ok
	return ok


static func _test_the_help_strip_explains_the_network_fields() -> bool:
	var ok: bool = true
	for pinned: Array in [
		["net_port", "65535"],
		["net_address", "127.0.0.1"],
		["peer_kind", "browser"],
		["max_players", "bandwidth"],
		["feature_tag", "dedicated_server"]
	]:
		var paragraph: String = FieldFactory.hint_paragraph(str(pinned[0]), "Player")
		ok = _check("the %s strip says the thing people look up" % str(pinned[0]),
			paragraph.contains(str(pinned[1])), true) and ok
	# The host and join rows point their fields AT those paragraphs, which is the only reason the
	# strip has anything to say while they are being filled in.
	var host: ACEDescriptor = ACERegistry.find_descriptor("Core", "HostGame")
	ok = _check("Host a game asks for a port", host.params[0].hint, "net_port") and ok
	ok = _check("...a number of players", host.params[1].hint, "max_players") and ok
	ok = _check("...and a peer kind", host.params[2].hint, "peer_kind") and ok
	ok = _check("Join a game asks for an address",
		ACERegistry.find_descriptor("Core", "JoinGame").params[0].hint, "net_address") and ok
	# Each peer kind carries the line under it that says when to pick it.
	var notes: Dictionary = FieldFactory.option_notes({"options": EventForgeMultiplayerACEs.PEER_KINDS})
	ok = _check("ENet says it is the default", str(notes.get("ENetMultiplayerPeer", "")).contains("default"), true) and ok
	ok = _check("WebSocket says it is the browser one",
		str(notes.get("WebSocketMultiplayerPeer", "")).contains("browser"), true) and ok
	ok = _check("WebRTC says what it costs you",
		str(notes.get("WebRTCMultiplayerPeer", "")).contains("signalling server"), true) and ok
	return ok


static func _test_the_picker_shelves() -> bool:
	var ok: bool = true
	for pinned: Array in [
		["OnPlayerJoined", EventForgeMultiplayerACEs.SECTION_PLAYERS],
		["OnPlayerLeft", EventForgeMultiplayerACEs.SECTION_PLAYERS],
		["OnPlayerAuthenticating", EventForgeMultiplayerACEs.SECTION_PLAYERS],
		["OnAuthenticationFailed", EventForgeMultiplayerACEs.SECTION_PLAYERS],
		["OnJoinedTheHost", EventForgeMultiplayerACEs.SECTION_CONNECTION],
		["OnJoinFailed", EventForgeMultiplayerACEs.SECTION_CONNECTION],
		["OnTheHostLeft", EventForgeMultiplayerACEs.SECTION_CONNECTION],
		# Not a trigger: every action, condition and expression stays in the one flat section.
		["HostGame", ""],
		["IsHost", ""],
		["Players", ""]
	]:
		ok = _check("%s is offered on its own shelf" % str(pinned[0]),
			ACEPickerDialog.multiplayer_group_key(_definition(str(pinned[0]))), str(pinned[1])) and ok
	# A trigger of another object is never filed here.
	ok = _check("another object's trigger is left where it was",
		ACEPickerDialog.multiplayer_group_key(_definition("OnTimeout")), "") and ok
	# Each shelf says what it holds, which is what the picker shows when the header is selected.
	for section: String in [EventForgeMultiplayerACEs.SECTION_PLAYERS,
			EventForgeMultiplayerACEs.SECTION_CONNECTION, EventForgeMultiplayerACEs.SECTION_SCENES]:
		ok = _check("%s describes itself" % section,
			EventSheetSectionInfo.description_for(section).length() > 40, true) and ok
	return ok


# ── who runs it ─────────────────────────────────────────────────────────────────────────────────


static func _test_runs_on_is_one_table() -> bool:
	var ok: bool = _check("the host's guard", EventGroup.runs_on_guard(EventGroup.RUNS_ON_HOST), "multiplayer.is_server()")
	ok = _check("the owner's guard", EventGroup.runs_on_guard(EventGroup.RUNS_ON_OWNER), "is_multiplayer_authority()") and ok
	ok = _check("everyone writes nothing at all", EventGroup.runs_on_guard(EventGroup.RUNS_ON_EVERYONE), "") and ok
	ok = _check("and so does an unanswered group", EventGroup.runs_on_guard(""), "") and ok
	# The head carries the EXCEPTION and never the default.
	ok = _check("a host group wears one muted word",
		EventSheetGroupFacts.runs_on_word(_group("Scoring", EventGroup.RUNS_ON_HOST)), "host") and ok
	ok = _check("an owner group wears the other",
		EventSheetGroupFacts.runs_on_word(_group("Movement", EventGroup.RUNS_ON_OWNER)), "owner") and ok
	ok = _check("an ordinary group wears none", EventSheetGroupFacts.runs_on_word(_group("Juice", "")), "") and ok
	var choices: Array[Dictionary] = EventSheetGroupFacts.runs_on_choices()
	ok = _check("the dropdown offers three answers", choices.size(), 3) and ok
	ok = _check("...everyone first, storing nothing", str(choices[0].get("value", "")), "") and ok
	ok = _check("...then the host", str(choices[1].get("value", "")), EventGroup.RUNS_ON_HOST) and ok
	ok = _check("...then the owner", str(choices[2].get("value", "")), EventGroup.RUNS_ON_OWNER) and ok
	for index: int in range(choices.size()):
		ok = _check("choice %d says what it costs" % index,
			str(choices[index].get("description", "")).length() > 40, true) and ok
	ok = _check("a group's own answer is what the dropdown selects",
		EventSheetGroupFacts.runs_on_index(EventGroup.RUNS_ON_OWNER), 2) and ok
	ok = _check("a value nothing recognises reads as everyone",
		EventSheetGroupFacts.runs_on_index("nonsense"), 0) and ok
	return ok


static func _test_runs_on_compiles_to_the_guard() -> bool:
	var ok: bool = true
	# The whole contract, first half: a sheet that says nothing about who runs it compiles to
	# EXACTLY what it compiled to before this existed.
	var plain: EventSheetResource = _sheet(_group("Scoring", ""))
	var plain_output: String = str(SheetCompiler.compile(plain).get("output", ""))
	ok = _check("a single-player group emits no guard", plain_output.contains("multiplayer"), false) and ok
	ok = _check("...and no runs_on in its header", plain_output.contains("runs_on"), false) and ok

	var hosted: EventSheetResource = _sheet(_group("Scoring", EventGroup.RUNS_ON_HOST))
	var hosted_output: String = str(SheetCompiler.compile(hosted).get("output", ""))
	ok = _check("a host group says so in its header", hosted_output.contains("runs_on=\"host\""), true) and ok
	ok = _check("...and guards its event with the host test",
		hosted_output.contains("if multiplayer.is_server() and is_on_floor():"), true) and ok

	# Nested: the INNERMOST answer wins, because that is the one the reader put closest to the rows.
	var inner: EventGroup = _group("Movement", EventGroup.RUNS_ON_OWNER)
	var outer: EventGroup = _group("Scoring", EventGroup.RUNS_ON_HOST)
	outer.events.append(inner)
	var nested_output: String = str(SheetCompiler.compile(_sheet(outer)).get("output", ""))
	ok = _check("the inner group's rows ask the inner question",
		nested_output.contains("if is_multiplayer_authority() and is_on_floor():"), true) and ok
	ok = _check("...and the outer group's rows still ask the outer one",
		nested_output.contains("if multiplayer.is_server() and is_on_floor():"), true) and ok

	# Both guards on one group: the switch gates first, then who runs it.
	var switched: EventGroup = _group("Scoring", EventGroup.RUNS_ON_HOST)
	switched.runtime_toggleable = true
	var switched_output: String = str(SheetCompiler.compile(_sheet(switched)).get("output", ""))
	ok = _check("a switchable host group asks both, switch first",
		switched_output.contains("if __group_scoring_active and multiplayer.is_server() and is_on_floor():"), true) and ok
	return ok


static func _test_runs_on_round_trips() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = _sheet(_group("Scoring", EventGroup.RUNS_ON_HOST))
	var output: String = str(SheetCompiler.compile(sheet, "user://_runs_on_rt.gd").get("output", ""))
	var reopened: EventSheetResource = GDScriptImporter.new().import_external_source(output)
	var opened_group: EventGroup = null
	for row: Variant in reopened.events:
		if row is EventGroup:
			opened_group = row as EventGroup
	ok = _check("the group comes back", opened_group != null, true) and ok
	if opened_group != null:
		ok = _check("...still saying the host runs it", opened_group.runs_on, EventGroup.RUNS_ON_HOST) and ok
		# The guard is the GROUP's fact: it must not come back as a condition on the row as well, or
		# re-emission would ask the same question twice.
		var opened_row: EventRow = opened_group.child_rows()[0] as EventRow
		ok = _check("...and the guard is off the row it guarded", opened_row.conditions.size(), 1) and ok
		ok = _check("...leaving the row's own condition alone", opened_row.conditions[0].ace_id, "IsOnFloor") and ok
	reopened.external_source_path = "user://_runs_on_rt.gd"
	var resaved: String = str(SheetCompiler.compile(reopened, "user://_runs_on_rt.gd").get("output", ""))
	ok = _check("re-saving it reproduces the file byte for byte", resaved == output, true) and ok
	return ok


static func _test_runs_on_folds_the_conditions_it_replaces() -> bool:
	# A project that repeated an Is host condition on every event is exactly who this is for: saying
	# it once on the group takes it off the rows, rather than compiling the test twice.
	var group: EventGroup = _group("Scoring", "")
	var extra: EventRow = _floor_event()
	var is_host: ACECondition = ACECondition.new()
	is_host.provider_id = "Core"
	is_host.ace_id = "IsHost"
	is_host.codegen_template = "multiplayer.is_server()"
	extra.conditions.insert(0, is_host)
	group.events.append(extra)
	EventSheetQuickPromptDialogs.set_group_fields(group, "Scoring", "", {"runs_on": EventGroup.RUNS_ON_HOST})
	var ok: bool = _check("the group now says who runs it", group.runs_on, EventGroup.RUNS_ON_HOST)
	ok = _check("the row's Is host condition is folded into that word",
		(group.child_rows()[1] as EventRow).conditions.size(), 1) and ok
	ok = _check("...and the condition it kept is its own",
		(group.child_rows()[1] as EventRow).conditions[0].ace_id, "IsOnFloor") and ok
	# The same sheet still compiles to one test, not two.
	var output: String = str(SheetCompiler.compile(_sheet(group)).get("output", ""))
	ok = _check("so the emitted line asks it once",
		output.count("multiplayer.is_server() and multiplayer.is_server()"), 0) and ok
	return _test_an_or_row_is_left_alone() and ok


## An OR row says the guard ONCE, as one of the answers it will take. Folding it out would leave the
## other answer alone under the group's guard - `is host or is on floor` becoming `is host and is on
## floor`, the opposite gate, written by a dropdown that never mentioned the row.
static func _test_an_or_row_is_left_alone() -> bool:
	var group: EventGroup = _group("Scoring", "")
	var either: EventRow = _floor_event()
	either.condition_mode = EventRow.ConditionMode.OR
	var is_host: ACECondition = ACECondition.new()
	is_host.provider_id = "Core"
	is_host.ace_id = "IsHost"
	is_host.codegen_template = "multiplayer.is_server()"
	either.conditions.insert(0, is_host)
	group.events = [either]
	EventSheetQuickPromptDialogs.set_group_fields(group, "Scoring", "", {"runs_on": EventGroup.RUNS_ON_HOST})
	var kept: Array[ACECondition] = (group.child_rows()[0] as EventRow).conditions
	var ok: bool = _check("both halves of an or row are still there", kept.size(), 2)
	ok = _check("...in the order they were asked in",
		PackedStringArray([kept[0].ace_id, kept[1].ace_id]), PackedStringArray(["IsHost", "IsOnFloor"])) and ok
	var output: String = str(SheetCompiler.compile(_sheet(group)).get("output", ""))
	ok = _check("so the row still asks for either of them",
		output.contains("multiplayer.is_server() or is_on_floor()"), true) and ok
	return ok


# ── the pieces ──────────────────────────────────────────────────────────────────────────────────


static func _definition(ace_id: String) -> ACEDefinition:
	return EventSheetACEAdapter.from_eventforge_descriptor(ACERegistry.find_descriptor("Core", ace_id))


static func _group(name: String, runs_on: String) -> EventGroup:
	var group: EventGroup = EventGroup.new()
	group.group_name = name
	group.name = name
	group.runs_on = runs_on
	group.events = [_floor_event()]
	return group


static func _floor_event() -> EventRow:
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = "IsOnFloor"
	condition.codegen_template = "is_on_floor()"
	event.conditions.append(condition)
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "MoveAndSlide"
	action.codegen_template = "move_and_slide()"
	event.actions.append(action)
	return event


static func _sheet(group: EventGroup) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "CharacterBody2D"
	sheet.events.append(group)
	return sheet


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("multiplayer_vocabulary_test", label, actual, expected)
