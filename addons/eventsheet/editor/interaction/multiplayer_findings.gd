# Godot EventSheets - the four networking mistakes, found by reading the sheet.
#
# Networking bugs are silent: the game runs, nobody sees an error, and the other player sees
# nothing. These four are the ones that cost a beginner an evening, and every one of them is a
# question the sheet can already answer about itself:
#
#   sent but not a message   - a Send row names a function of this sheet that carries no `@rpc`.
#   changed on the host      - a variable written inside a group that runs on the host, which no
#                              synchronizer keeps in step and no message carries.
#   moved by everyone        - a row that moves a synced object, outside an owner group and with
#                              no authority check on the event.
#   trusting the sender      - a message anyone may send that writes a synced variable without ever
#                              asking who sent it.
#
# NOTHING is stored: each finding is derived from the rows, the group attributes, the function
# annotations and the scene's replication config, so a fixed sheet stops reporting it with nothing
# to clean up. A sheet that says nothing about the network gets NO findings at all - the coverage
# census is the gate, so a single-player project grows no notes it did not have before.
#
# The same list feeds both surfaces: the note rows under the offending row, and the Doctor's
# Multiplayer section. One wording, one rule, two places to read it.
#
# PURE + STATIC: no viewport, no dialog, no display server, so every word is pinned headless.
@tool
class_name EventSheetMultiplayerFindings
extends RefCounted

## The four findings, by id. Frozen: the note rows, the Doctor and the tests address one by these.
const KIND_NOT_A_MESSAGE := "sent-not-a-message"
const KIND_HOST_ONLY := "changed-on-the-host"
const KIND_EVERYONE_MOVES := "moved-by-everyone"
const KIND_TRUSTS_SENDER := "trusting-the-sender"

## The one-click repairs a note offers. "" on a finding whose repair is a decision rather than a
## step - trusting the sender is a rule about the game, not a line to rewrite.
const FIX_MAKE_MESSAGE := "make_message"
const FIX_KEEP_IN_STEP := "keep_in_step"
const FIX_OWNER_GROUP := "owner_group"

## Where a finding's note hangs: under the event, under the variable's declaration, or under the
## function it is about.
const ANCHOR_EVENT := "event"
const ANCHOR_VARIABLE := "variable"
const ANCHOR_FUNCTION := "function"

## What a row writes when it MOVES the thing it runs on. Read off the row's own compiled line rather
## than kept as a list of ace_ids, so a pack's own movement verb is caught by the same rule and no
## table has to learn about it.
const MOVEMENT_MEMBERS: PackedStringArray = [
	"position", "global_position", "velocity", "rotation", "global_rotation", "transform"
]

## The calls that move a body without assigning to one of those.
const MOVEMENT_CALLS: PackedStringArray = ["move_and_slide", "move_and_collide", "move_local_x", "move_local_y"]

## How a template addresses the object the row runs on: nothing at all, the node-scoped prefix the
## factory writes, or the author's own `self.`. A line starting with anything else is about
## something that line made, not about this object.
const SELF_LEADS: PackedStringArray = ["", "{target.}", "{target}.", "self."]

## The one thing a message cannot lie about, as it is spelled in the line a row compiles to. A
## function that names it has asked who sent the message, however it asked.
const SENDER_CALL := "get_remote_sender_id"

## The conditions that already say "only the peer that should do this", so an event carrying one is
## guarded whether or not a group says so.
const AUTHORITY_CONDITIONS: PackedStringArray = ["OwnsThisObject", "IsHost"]


## Every finding this sheet earns, in the order the rules run. Empty for a sheet that says nothing
## about the network at all, which is what keeps a single-player project exactly as it was.
static func findings(sheet: EventSheetResource) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if sheet == null or int(EventSheetReadingCoverage.networking(sheet).get("total", 0)) <= 0:
		return found
	var rows: Array[Dictionary] = row_contexts(sheet)
	var synced: PackedStringArray = synced_names(sheet)
	_sent_but_not_a_message(sheet, rows, found)
	_changed_on_the_host(sheet, rows, synced, found)
	_moved_by_everyone(rows, synced, found)
	_trusting_the_sender(sheet, synced, found)
	return found


## The findings anchored at one event row - what the canvas hangs under it. Matched by IDENTITY, so
## the caller never has to name a row that has no name.
static func for_event(found: Array[Dictionary], event_row: EventRow) -> Array[Dictionary]:
	var mine: Array[Dictionary] = []
	if event_row == null:
		return mine
	for entry: Dictionary in found:
		if str(entry.get("anchor", "")) == ANCHOR_EVENT and is_same(entry.get("event"), event_row):
			mine.append(entry)
	return mine


## The findings anchored at one variable declaration, and at one function head.
static func for_subject(found: Array[Dictionary], anchor: String, subject: String) -> Array[Dictionary]:
	var mine: Array[Dictionary] = []
	var wanted: String = subject.strip_edges()
	if wanted.is_empty():
		return mine
	for entry: Dictionary in found:
		if str(entry.get("anchor", "")) == anchor and str(entry.get("subject", "")) == wanted:
			mine.append(entry)
	return mine


## Every picked row in the sheet with the two facts a rule needs about WHERE it sits: who runs the
## group it is in, and whether anything above it has already said "only the peer that owns this".
## One walk, four rules - a second walk would be a second answer to the same question.
static func row_contexts(sheet: EventSheetResource) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if sheet == null:
		return rows
	_walk(sheet.events, "", false, "", rows)
	for entry: Variant in sheet.functions:
		var event_function: EventFunction = entry as EventFunction
		if event_function != null:
			_walk(event_function.events, "", false, event_function.function_name.strip_edges(), rows)
	return rows


## The bare names a MultiplayerSynchronizer in this sheet's scene keeps in step.
static func synced_names(sheet: EventSheetResource) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for entry: Dictionary in EventSheets.synced_properties(sheet):
		var name_text: String = str(entry.get("name", "")).strip_edges()
		if not name_text.is_empty() and not names.has(name_text):
			names.append(name_text)
	return names


static func _walk(items: Array, runs_on: String, owned: bool, function_name: String,
		into: Array[Dictionary]) -> void:
	for item: Variant in items:
		if item is EventGroup:
			var group: EventGroup = item as EventGroup
			var inner: String = group.runs_on.strip_edges()
			_walk(EventSheetGroupFacts.children(group), inner if not inner.is_empty() else runs_on,
				owned or inner == EventGroup.RUNS_ON_OWNER, function_name, into)
			continue
		var event_row: EventRow = item as EventRow
		if event_row == null:
			continue
		var guarded: bool = owned or runs_on == EventGroup.RUNS_ON_OWNER or _checks_authority(event_row)
		for is_action: bool in [false, true]:
			for ace: Variant in (event_row.actions if is_action else event_row.conditions):
				if ace is Resource:
					into.append({
						"event": event_row, "ace": ace as Resource, "action": is_action,
						"runs_on": runs_on, "owned": guarded, "function": function_name
					})
		_walk(event_row.sub_events, runs_on, guarded, function_name, into)


## True when the event already asks whether this peer is the one allowed to act.
static func _checks_authority(event_row: EventRow) -> bool:
	for condition: Variant in event_row.conditions:
		if condition is Resource and AUTHORITY_CONDITIONS.has(str((condition as Resource).get("ace_id"))):
			return true
	return false


# -- The four rules ------------------------------------------------------------------------------


## A Send row naming a function this sheet declares that carries no `@rpc`. The row compiles, and
## then nothing travels - the quietest failure of the four. Only fires for a function the sheet
## DECLARES: a message may belong to another object, and this sheet cannot see that one's annotation.
static func _sent_but_not_a_message(sheet: EventSheetResource, rows: Array[Dictionary],
		found: Array[Dictionary]) -> void:
	var messages: Dictionary = {}
	for entry: Dictionary in EventSheetMessageFacts.messages_in(sheet):
		messages[str(entry.get("name", ""))] = true
	var declared: Dictionary = {}
	for entry: Variant in sheet.functions:
		var event_function: EventFunction = entry as EventFunction
		if event_function != null:
			declared[event_function.function_name.strip_edges()] = true
	var seen: Dictionary = {}
	for context: Dictionary in rows:
		var ace: Resource = context.get("ace") as Resource
		if not EventSheetMessageFacts.SEND_ACE_IDS.has(str(ace.get("ace_id"))):
			continue
		var message: String = _param(ace, "message")
		if message.is_empty() or messages.has(message) or not declared.has(message) or seen.has(message):
			continue
		seen[message] = true
		found.append({
			"kind": KIND_NOT_A_MESSAGE, "severity": "warning",
			"anchor": ANCHOR_EVENT, "event": context.get("event"), "subject": message,
			"message": EventSheetL10n.translate("%s is not a message: nothing will arrive. Mark the function as a message first.") % message,
			"fix": FIX_MAKE_MESSAGE,
			"fix_label": EventSheetL10n.translate("Make %s a message…") % message
		})


## A variable written inside a group that runs on the host, which nothing carries to anybody else.
## The host's copy changes and every other peer goes on showing the old value.
static func _changed_on_the_host(sheet: EventSheetResource, rows: Array[Dictionary],
		synced: PackedStringArray, found: Array[Dictionary]) -> void:
	var carried: Dictionary = _names_messages_carry(sheet, rows)
	var seen: Dictionary = {}
	for context: Dictionary in rows:
		if not bool(context.get("action", false)) or str(context.get("runs_on", "")) != EventGroup.RUNS_ON_HOST:
			continue
		for name_text: String in written_variables(context.get("ace") as Resource):
			if seen.has(name_text) or synced.has(name_text) or carried.has(name_text):
				continue
			if not sheet.variables.has(name_text):
				continue
			seen[name_text] = true
			found.append({
				"kind": KIND_HOST_ONLY, "severity": "warning",
				"anchor": ANCHOR_VARIABLE, "event": context.get("event"), "subject": name_text,
				"message": EventSheetL10n.translate("%s is changed in a group that runs on the host, but only the host will see the new value. Keep it in step, or send it.") % name_text,
				"fix": FIX_KEEP_IN_STEP,
				"fix_label": EventSheetL10n.translate("Keep in step")
			})


## A row that moves an object every peer keeps in step, with nothing saying only its owner may. Each
## peer then moves its own copy and the owner's corrections fight them.
static func _moved_by_everyone(rows: Array[Dictionary], synced: PackedStringArray,
		found: Array[Dictionary]) -> void:
	if synced.is_empty():
		return
	var seen: Dictionary = {}
	for context: Dictionary in rows:
		if not bool(context.get("action", false)) or bool(context.get("owned", false)):
			continue
		var ace: Resource = context.get("ace") as Resource
		if not moves_the_body(_template_of(ace)):
			continue
		var event_row: EventRow = context.get("event") as EventRow
		if seen.has(event_row):
			continue
		seen[event_row] = true
		var verb: String = _display_name(ace)
		found.append({
			"kind": KIND_EVERYONE_MOVES, "severity": "warning",
			"anchor": ANCHOR_EVENT, "event": event_row, "subject": verb,
			"message": EventSheetL10n.translate("%s runs on every peer, and only the owner of this object should move it. Put the event in a group that runs on the owner.") % verb,
			"fix": FIX_OWNER_GROUP,
			"fix_label": EventSheetL10n.translate("Wrap in an owner group")
		})


## A message anyone may send that writes a value every peer keeps in step, without ever asking who
## sent it. A player can send that message themselves, so the value is theirs to choose.
static func _trusting_the_sender(sheet: EventSheetResource, synced: PackedStringArray,
		found: Array[Dictionary]) -> void:
	if synced.is_empty():
		return
	for entry: Variant in sheet.functions:
		var event_function: EventFunction = entry as EventFunction
		if event_function == null:
			continue
		var said: Dictionary = EventSheetMessageFacts.parse(
			EventSheetMessageFacts.annotation_of(event_function))
		if str(said.get(EventSheetMessageFacts.FIELD_SENDER, "")) != "any_peer":
			continue
		var body: Array[Dictionary] = []
		_walk(event_function.events, "", false, event_function.function_name.strip_edges(), body)
		if _asks_who_sent_it(body):
			continue
		# One note per message, naming the first value it writes: the rule is about the message, and
		# a note per line would say the same thing three times.
		var written: String = _first_synced_write(body, synced)
		if written.is_empty():
			continue
		var message_name: String = event_function.function_name.strip_edges()
		found.append({
			"kind": KIND_TRUSTS_SENDER, "severity": "warning",
			"anchor": ANCHOR_FUNCTION, "event": null, "subject": message_name,
			"message": EventSheetL10n.translate("%s may be sent by anyone, and it writes %s without asking who sent it. Any player could send it themselves.") % [
				message_name, written],
			"fix": "", "fix_label": ""
		})


## The first value one message writes that every peer keeps in step, or "".
static func _first_synced_write(rows: Array[Dictionary], synced: PackedStringArray) -> String:
	for context: Dictionary in rows:
		if not bool(context.get("action", false)):
			continue
		for name_text: String in written_variables(context.get("ace") as Resource):
			if synced.has(name_text):
				return name_text
	return ""


## True when anything in these rows names the sender - however it was written, because the question
## is asked of the LINE each row compiles to rather than of an ace_id.
static func _asks_who_sent_it(rows: Array[Dictionary]) -> bool:
	for context: Dictionary in rows:
		var ace: Resource = context.get("ace") as Resource
		if _template_of(ace).contains(SENDER_CALL):
			return true
		for value: Variant in _params_of(ace).values():
			if str(value).contains(SENDER_CALL):
				return true
	return false


## The names a message carries away from this peer: a variable handed to a Send row, and a variable
## written inside a function that IS a message. Either way somebody else learns the new value.
static func _names_messages_carry(sheet: EventSheetResource, rows: Array[Dictionary]) -> Dictionary:
	var carried: Dictionary = {}
	var message_names: Dictionary = {}
	for entry: Dictionary in EventSheetMessageFacts.messages_in(sheet):
		message_names[str(entry.get("name", ""))] = true
	for context: Dictionary in rows:
		var ace: Resource = context.get("ace") as Resource
		if message_names.has(str(context.get("function", ""))):
			for name_text: String in written_variables(ace):
				carried[name_text] = true
		if not EventSheetMessageFacts.SEND_ACE_IDS.has(str(ace.get("ace_id"))):
			continue
		for value: Variant in _params_of(ace).values():
			for token: String in str(value).split(","):
				carried[token.strip_edges()] = true
	return carried


# -- What one row says --------------------------------------------------------------------------


## The variables one ACTION row writes: the values of its `variable_reference` parameters, read off
## the shipped descriptor rather than a list of ids, so a pack's own setter counts too.
static func written_variables(ace: Resource) -> PackedStringArray:
	if ace == null or not (ace is ACEAction):
		return PackedStringArray()
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor(
		str(ace.get("provider_id")), str(ace.get("ace_id")))
	if descriptor == null:
		return PackedStringArray()
	return EventSheetVariableOwners.variable_reference_values(descriptor.params, _params_of(ace))


## True when the line a row compiles to moves the object it RUNS ON: it assigns one of the members a
## body's place is kept in, or calls one of the engine's own move functions, on this object rather
## than on something the line made itself. Anchored at the start of the line for exactly that
## reason - `__query.position = point` sets up a physics query and moves nothing.
static func moves_the_body(template: String) -> bool:
	for line: String in template.split("\n"):
		var text: String = line.strip_edges()
		for lead: String in SELF_LEADS:
			for call_name: String in MOVEMENT_CALLS:
				if text.begins_with("%s%s(" % [lead, call_name]):
					return true
			for member: String in MOVEMENT_MEMBERS:
				var head: String = lead + member
				if text.begins_with(head) and _assigns_after(text, head.length()):
					return true
	return false


## Whether what follows a member name is an assignment TO it. One member step is walked past first,
## because `position.x = 0` and `velocity.y += 1` move the object exactly as much as the whole
## member would; `==` is a comparison, which only reads it.
static func _assigns_after(text: String, from: int) -> bool:
	var rest: String = text.substr(from)
	if rest.begins_with("."):
		var cut: int = 1
		while cut < rest.length() and (rest[cut] == "_" or rest[cut].is_valid_identifier()
				or rest[cut].is_valid_int()):
			cut += 1
		rest = rest.substr(cut)
	rest = rest.strip_edges()
	for operator: String in ["+=", "-=", "*=", "/="]:
		if rest.begins_with(operator):
			return true
	return rest.begins_with("=") and not rest.begins_with("==")


static func _template_of(ace: Resource) -> String:
	if ace == null:
		return ""
	var baked: String = str(ace.get("codegen_template"))
	if not baked.strip_edges().is_empty():
		return baked
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor(
		str(ace.get("provider_id")), str(ace.get("ace_id")))
	return descriptor.codegen_template if descriptor != null else ""


static func _display_name(ace: Resource) -> String:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor(
		str(ace.get("provider_id")), str(ace.get("ace_id")))
	return descriptor.display_name if descriptor != null else str(ace.get("ace_id"))


static func _params_of(ace: Resource) -> Dictionary:
	if ace == null:
		return {}
	var params: Variant = ace.get("params")
	return params as Dictionary if params is Dictionary else {}


static func _param(ace: Resource, key: String) -> String:
	return str(_params_of(ace).get(key, "")).strip_edges()
