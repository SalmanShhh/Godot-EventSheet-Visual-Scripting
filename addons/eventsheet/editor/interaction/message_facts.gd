# Godot EventSheets - the ONE place that answers questions about a MESSAGE.
#
# A message is a function marked `@rpc`. Godot's annotation takes three choices and a channel,
# spelled as strings most people copy without reading: `@rpc("any_peer", "call_local", "reliable")`.
# Everything a reader sees about a message - the words on its row, the choices the Message dialog
# lists, the line that dialog writes back, which functions a Send row may name - is derived here, so
# the row, the dialog and the tests can never answer the same question two ways.
#
# The words table runs BOTH directions: `word_for_option` reads an annotation the file already had,
# `option_for_word` writes one back. That is what makes "reads it in words" and "writes it in words"
# the same table rather than two lists that drift apart.
#
# BYTE-EXACTNESS: `rewrite` hands back the ORIGINAL line whenever the answers still mean what it
# already said, so opening a message and pressing OK cannot rewrite the file. Only a real change
# writes a new annotation - the same rule the importer follows when it stores the spelling it
# matched.
#
# PURE + STATIC on purpose: no viewport, no dialog, no display server, so every word here is
# testable headless.
@tool
class_name EventSheetMessageFacts
extends RefCounted

## The three questions an `@rpc` annotation answers, plus the channel it travels on. Frozen: the
## dialog's rows, the help strip and the tests address a field by these.
const FIELD_SENDER := "Who may send"
const FIELD_WHERE := "Where it runs"
const FIELD_DELIVERY := "Delivery"
const FIELD_CHANNEL := "Channel"

## The fields in the order the dialog asks for them.
const FIELDS: PackedStringArray = [FIELD_SENDER, FIELD_WHERE, FIELD_DELIVERY, FIELD_CHANNEL]

## The three questions SENDING a message asks, beside the ones the annotation answers. They live
## here rather than in the dialog so every field word and its paragraph are in one table.
const FIELD_MESSAGE := "Message"
const FIELD_TO := "To"
const FIELD_PLAYER := "Player"
const FIELD_VALUES := "Values"

## What Godot does for a field the annotation does not name. Used to fill the dialog for a partial
## annotation, and to decide whether an edit changed anything - NOT to invent words on a row: a row
## says what the file says.
const ENGINE_DEFAULTS: Dictionary = {
	FIELD_SENDER: "authority",
	FIELD_WHERE: "call_remote",
	FIELD_DELIVERY: "unreliable"
}

## What a message the sheet is marking for the FIRST time says. The safe answer to each question:
## only the owner may send it, the sender runs it too so one row is the whole effect, and it is
## resent until it arrives.
const NEW_MESSAGE: Dictionary = {
	FIELD_SENDER: "authority",
	FIELD_WHERE: "call_local",
	FIELD_DELIVERY: "reliable",
	"channel": 0
}

## Whose vocabulary the three Send actions belong to, and the three `ace_id`s a Send row can be.
## Frozen alongside the descriptors themselves.
const PROVIDER := "Core"
const SEND_TO_EVERYONE := "SendMessageToEveryone"
const SEND_TO_HOST := "SendMessageToHost"
const SEND_TO_PEER := "SendMessageToPeer"

## Those three as a list - what the dock matches a picked or edited row against to decide that it
## opens in the Send dialog rather than in the generic parameters one.
const SEND_ACE_IDS: PackedStringArray = [SEND_TO_EVERYONE, SEND_TO_HOST, SEND_TO_PEER]

## The annotation an unreadable one is shown as - the marker the row swaps its words for. Empty
## means "the words read fine".
const UNKNOWN_OPTION_KEY := "unknown"


## Every answer one field takes, each as the word a reader picks it by, the muted word the ROW then
## reads, the line under it in the dialog, and the option string Godot's annotation spells it with.
## ONE list: the dropdowns, the row, the help strip and the tests all read it, so a wording change
## lands everywhere at once.
static func choices(field: String) -> Array[Dictionary]:
	match field:
		FIELD_SENDER:
			return [
				{"value": "any_peer", "label": EventSheetL10n.translate("Anyone"),
					"word": EventSheetL10n.translate("from anyone"),
					"description": EventSheetL10n.translate("Any peer may send this message, so a client can ask the host for something. The host has to decide whether to believe it: check Sender before acting on anything a player could have made up.")},
				{"value": "authority", "label": EventSheetL10n.translate("Only the owner"),
					"word": EventSheetL10n.translate("from the owner"),
					"description": EventSheetL10n.translate("Only the peer that owns this node may send it - the host, unless the node was given away. A call from anybody else is dropped and logged, which is what makes this the safe answer.")}
			]
		FIELD_WHERE:
			return [
				{"value": "call_remote", "label": EventSheetL10n.translate("On the others"),
					"word": EventSheetL10n.translate("on the others"),
					"description": EventSheetL10n.translate("Every peer that receives it runs the function; the peer that sent it does not. Right when the sender has already done the thing itself and is only telling the others.")},
				{"value": "call_local", "label": EventSheetL10n.translate("On the others, and here too"),
					"word": EventSheetL10n.translate("also here"),
					"description": EventSheetL10n.translate("The sender runs the function as well, so one row is the whole effect. This is why the shot you fired lands for you at the same moment as for everybody else.")}
			]
		FIELD_DELIVERY:
			return [
				{"value": "reliable", "label": EventSheetL10n.translate("Reliable"),
					"word": EventSheetL10n.translate("reliable"),
					"description": EventSheetL10n.translate("Sent again until it arrives, and it arrives in the order it was sent. Right for anything that happens once - a hit, a pickup, a round starting.")},
				{"value": "unreliable", "label": EventSheetL10n.translate("Fast, may drop"),
					"word": EventSheetL10n.translate("fast, may drop"),
					"description": EventSheetL10n.translate("Sent once and never chased. Right for a value replaced a few times a second anyway, where one that goes missing costs nothing because the next is already on its way.")},
				{"value": "unreliable_ordered", "label": EventSheetL10n.translate("Fast, in order"),
					"word": EventSheetL10n.translate("fast, in order"),
					"description": EventSheetL10n.translate("Sent once, and one that arrives after a newer one is thrown away. Right for a stream where only the latest matters - a position, an aim direction.")}
			]
	return []


## What each field of the Message dialog is, in one line - the strip's paragraph for the field
## itself, where the field is not a list of described choices.
static func field_help(field: String) -> String:
	match field:
		FIELD_CHANNEL:
			return EventSheetL10n.translate("Messages on different channels do not queue behind each other. Leave it at 0 unless one big reliable message - a level, a long list - is holding up something small and frequent.")
		FIELD_MESSAGE:
			return EventSheetL10n.translate("The function the other peers run. Only a function marked as a message travels, and the list holds the ones this sheet marks.")
		FIELD_PLAYER:
			return EventSheetL10n.translate("The id of the peer that runs it - the event's own id, or Sender to answer whoever just sent you a message.")
		FIELD_VALUES:
			return EventSheetL10n.translate("A value to send along. It arrives as this parameter on every peer that runs the message.")
	return ""


## The muted word the ROW reads an option string as ("call_local" -> "also here"), or "" for a
## string that is not one of Godot's options.
static func word_for_option(option: String) -> String:
	for field: String in FIELDS:
		for choice: Dictionary in choices(field):
			if str(choice.get("value", "")) == option:
				return str(choice.get("word", ""))
	return ""


## The other direction: the option string a row's word stands for ("also here" -> "call_local"), or
## "" for a word that is not one of them. The pair is what makes reading and writing one table.
static func option_for_word(word: String) -> String:
	var wanted: String = word.strip_edges()
	for field: String in FIELDS:
		for choice: Dictionary in choices(field):
			if str(choice.get("word", "")) == wanted:
				return str(choice.get("value", ""))
	return ""


## Which of the three questions an option string answers, or "" when it answers none. Derived from
## the tables rather than listed again, so a choice added above is filed without a second edit.
static func field_of_option(option: String) -> String:
	for field: String in FIELDS:
		for choice: Dictionary in choices(field):
			if str(choice.get("value", "")) == option:
				return field
	return ""


## The index of an answer in its field's list - what a dropdown selects. Never -1: a field the
## annotation left out reads as Godot's own default, which is what it does.
static func choice_index(field: String, value: String) -> int:
	var listed: Array[Dictionary] = choices(field)
	var wanted: String = value if not value.is_empty() else str(ENGINE_DEFAULTS.get(field, ""))
	for index: int in range(listed.size()):
		if str(listed[index].get("value", "")) == wanted:
			return index
	return 0


## The value at an index of a field's list, or Godot's default when the index names nothing.
static func choice_value(field: String, index: int) -> String:
	var listed: Array[Dictionary] = choices(field)
	if index < 0 or index >= listed.size():
		return str(ENGINE_DEFAULTS.get(field, ""))
	return str(listed[index].get("value", ""))


## What an `@rpc(...)` line SAYS, field by field: {FIELD_SENDER: "any_peer", …, "channel": 0,
## "options": the option strings in the order written, "unknown": the strings that are not options}.
## A field the annotation does not name is ABSENT from the answer rather than defaulted - the row
## says what the file says and never invents the rest.
static func parse(annotation: String) -> Dictionary:
	# The two lists are built as LOCALS and put in at the end: a PackedStringArray held in a
	# Dictionary is a value, so appending to what the lookup hands back appends to a copy.
	var written: PackedStringArray = PackedStringArray()
	var strange: PackedStringArray = PackedStringArray()
	var found: Dictionary = {}
	var text: String = annotation.strip_edges()
	var open_at: int = text.find("(")
	# A line that is not an `@rpc`, and a bare `@rpc` with no argument list (a message on every one
	# of Godot's defaults), both say nothing field by field.
	if text.begins_with("@rpc") and open_at >= 0 and text.ends_with(")"):
		for argument: String in EventSheetSentence.split_top_level(
				text.substr(open_at + 1, text.length() - open_at - 2), ","):
			var token: String = argument.strip_edges()
			if token.is_empty():
				continue
			if token.is_valid_int():
				found["channel"] = token.to_int()
				continue
			var option: String = EventSheetSentence.unquote(token)
			var field: String = field_of_option(option)
			if field.is_empty():
				strange.append(token)
				continue
			found[field] = option
			written.append(option)
	found["options"] = written
	found[UNKNOWN_OPTION_KEY] = strange
	return found


## The muted words a message row shows, in the order the annotation wrote them:
## "from anyone · also here · reliable". "" when the annotation names no option, which is Godot's
## own default and says nothing a reader could act on.
static func words(annotation: String) -> String:
	var said: PackedStringArray = PackedStringArray()
	for option: String in (parse(annotation).get("options", PackedStringArray()) as PackedStringArray):
		said.append(word_for_option(option))
	return " · ".join(said)


## The amber note an annotation the sheet cannot read earns, or "" when every option is one of
## Godot's. The row then shows the annotation ITSELF rather than words that would be a guess.
static func unknown_note(annotation: String) -> String:
	var strange: PackedStringArray = parse(annotation).get(UNKNOWN_OPTION_KEY, PackedStringArray())
	if strange.is_empty():
		return ""
	return EventSheetL10n.translate("%s is not one of Godot's @rpc options, so this row shows the annotation as it stands.") \
		% ", ".join(strange)


## The line the Message dialog writes for a set of answers - the exact `@rpc(...)` Godot takes. The
## channel is written only when it is not 0, because 0 is what an annotation without one means.
static func annotation_line(answers: Dictionary) -> String:
	var written: PackedStringArray = PackedStringArray()
	for field: String in [FIELD_SENDER, FIELD_WHERE, FIELD_DELIVERY]:
		written.append("\"%s\"" % str(answers.get(field, ENGINE_DEFAULTS.get(field, ""))))
	var channel: int = int(answers.get("channel", 0))
	if channel != 0:
		written.append(str(channel))
	return "@rpc(%s)" % ", ".join(written)


## True when a line already MEANS these answers - every field it names matches, every field it
## leaves out is at Godot's default, and the channel agrees. An annotation carrying an option the
## sheet cannot read never matches: it has to be rewritten to become readable.
static func means(annotation: String, answers: Dictionary) -> bool:
	var said: Dictionary = parse(annotation)
	if not (said.get(UNKNOWN_OPTION_KEY, PackedStringArray()) as PackedStringArray).is_empty():
		return false
	for field: String in [FIELD_SENDER, FIELD_WHERE, FIELD_DELIVERY]:
		var had: String = str(said.get(field, ENGINE_DEFAULTS.get(field, "")))
		if had != str(answers.get(field, ENGINE_DEFAULTS.get(field, ""))):
			return false
	return int(said.get("channel", 0)) == int(answers.get("channel", 0))


## The annotation to store for these answers, given whatever the file had. An unchanged answer hands
## the ORIGINAL line back verbatim, so opening a message and pressing OK leaves the `.gd` byte for
## byte as it was; only a real change writes the canonical form.
static func rewrite(original: String, answers: Dictionary) -> String:
	return original if means(original, answers) else annotation_line(answers)


## The `@rpc` line a function carries, or "" when it carries none. The annotation is what makes a
## function a message, so this doubles as the question "is this a message".
static func annotation_of(event_function: EventFunction) -> String:
	if event_function == null:
		return ""
	for annotation: String in event_function.annotation_lines:
		if annotation.strip_edges().begins_with("@rpc"):
			return annotation.strip_edges()
	return ""


## True when a function is a message.
static func is_message(event_function: EventFunction) -> bool:
	return not annotation_of(event_function).is_empty()


## The annotation lines a function should carry once it says these answers: its own lines with the
## `@rpc` replaced (or appended when it had none), everything else untouched and in order. Returned
## rather than written, so the caller decides which undo step it belongs to.
static func annotation_lines_with(event_function: EventFunction, answers: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var replaced: bool = false
	if event_function != null:
		for annotation: String in event_function.annotation_lines:
			if annotation.strip_edges().begins_with("@rpc"):
				lines.append(rewrite(annotation.strip_edges(), answers))
				replaced = true
			else:
				lines.append(annotation)
	if not replaced:
		lines.append(annotation_line(answers))
	return lines


## A function's parameter names, in order - what a Send row has to fill in.
static func parameter_names(event_function: EventFunction) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	if event_function == null:
		return names
	for entry: Variant in event_function.params:
		if entry is ACEParam:
			var bare: String = str((entry as ACEParam).id).strip_edges()
			names.append(bare if not bare.is_empty() else str((entry as ACEParam).name).strip_edges())
	if names.is_empty():
		for legacy: String in event_function.parameters:
			names.append(str(legacy).strip_edges())
	return names


## Every function this sheet publishes as a MESSAGE, in declaration order. One entry each:
##   {"name", "params", "annotation", "words", "note"}
## `note` is the amber line an annotation the sheet cannot read earns, and "" for every other. This
## is the list a Send row picks from: a function that is not marked is not a message, and offering
## it would write a line that silently never travels.
static func messages_in(sheet: EventSheetResource) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if sheet == null:
		return found
	for entry: Variant in sheet.functions:
		var event_function: EventFunction = entry as EventFunction
		if event_function == null:
			continue
		var annotation: String = annotation_of(event_function)
		if annotation.is_empty():
			continue
		var name_text: String = event_function.function_name.strip_edges()
		if name_text.is_empty():
			continue
		found.append({
			"name": name_text,
			"params": parameter_names(event_function),
			"annotation": annotation,
			"words": words(annotation),
			"note": unknown_note(annotation)
		})
	return found


## The three answers to "who runs this message", each as the word a reader picks, the line under it,
## and the `ace_id` the row is then written with. ONE list: the Send dialog's To dropdown, the help
## strip and the tests read it, so the words and the ids can never disagree.
static func send_choices() -> Array[Dictionary]:
	return [
		{"value": SEND_TO_EVERYONE, "label": EventSheetL10n.translate("Everyone"),
			"description": EventSheetL10n.translate("Every connected peer runs the message, and this peer as well when the message says it also runs here.")},
		{"value": SEND_TO_HOST, "label": EventSheetL10n.translate("The host"),
			"description": EventSheetL10n.translate("Only peer 1 runs it - the one hosting the game. This is how a client asks for something it may not decide by itself.")},
		{"value": SEND_TO_PEER, "label": EventSheetL10n.translate("One player"),
			"description": EventSheetL10n.translate("Only the peer whose id you give runs it. The event's own id, or Sender to answer whoever just sent you a message.")}
	]


## The index of a Send row's answer in that list - what the To dropdown selects. Never -1.
static func send_index(ace_id: String) -> int:
	var listed: Array[Dictionary] = send_choices()
	for index: int in range(listed.size()):
		if str(listed[index].get("value", "")) == ace_id:
			return index
	return 0


## The `ace_id` at an index of that list.
static func send_ace_id(index: int) -> String:
	var listed: Array[Dictionary] = send_choices()
	return str(listed[clampi(index, 0, listed.size() - 1)].get("value", ""))


## The parameters a Send row of this kind carries, filled in. One shape for all three ids, so the
## dialog never has to know which of them takes a peer.
static func send_params(ace_id: String, message: String, args: String, peer: String) -> Dictionary:
	var params: Dictionary = {"message": message, "args": args}
	if ace_id == SEND_TO_PEER:
		params["peer"] = peer
	return params


## The line a Send row writes, built by the COMPILER's own action codegen off the shipped template -
## so the dialog's IN CODE line and the emitted file can never drift apart.
static func send_code_line(ace_id: String, message: String, args: String, peer: String) -> String:
	var action := ACEAction.new()
	action.provider_id = PROVIDER
	action.ace_id = ace_id
	action.params = send_params(ace_id, message, args, peer)
	return ActionCodegen.generate_action(action)
