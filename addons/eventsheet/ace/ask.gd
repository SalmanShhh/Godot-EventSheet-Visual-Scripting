# Godot EventSheets - Ask: plain words in, proposed rows out.
#
# OFF by default, and off means OFF: nothing leaves this machine until the reader has turned Ask on
# in Project Settings, typed a sentence, and pressed Ask. There is no background call, no telemetry
# and no "helpful" pre-warming - `ask()` on a project that never opted in returns
# {"sent": false} without touching the network.
#
# What goes out, when the reader does press Ask, is exactly three things and nothing else:
#   1. the sentence they typed,
#   2. the sheet's object census (which objects this sheet talks about, and their types),
#   3. the vocabulary this sheet can WRITE - the display name, kind and parameters of every
#      condition and action in the registry, the same list the picker shows.
# No file contents, no project path, no scene, no source code. The Manual page says the same thing
# in the same order, and `build_request` is pinned by the suite so the promise is a test, not prose.
#
# What comes back is not code. The reply is asked for as a JSON list of ROWS in one fixed shape -
# {object, ace_id, params} - and every row is checked against the registry before a reader ever
# sees it: an ace_id the project does not have is DROPPED and named in the report, and a parameter
# the definition does not declare is dropped too. So the worst a bad answer can do is propose
# fewer rows than it meant to. It can never propose something the sheet cannot say.
#
# And nothing is applied by arriving. The proposal is a preview; it becomes rows only when the
# reader presses "Add these events" or "Try in a scratch sheet".
#
# The HTTP call is injected (`transport`), so the whole pipeline - request, schema, validation,
# rejection, proposal - is testable headless against a fake endpoint with no network at all.
@tool
class_name EventSheetAsk
extends RefCounted

## Ask is off. No request is ever built and none is ever sent.
const MODE_OFF := "off"
## Your own key against an HTTP endpoint that speaks the common chat format.
const MODE_KEY := "your own key"
## A model running on this machine, at an endpoint that speaks the same format.
const MODE_LOCAL := "a local model"

const SETTING_MODE := "eventsheets/ask/mode"
const SETTING_ENDPOINT := "eventsheets/ask/endpoint"
const SETTING_MODEL := "eventsheets/ask/model"
const SETTING_KEY := "eventsheets/ask/api_key"

## How many vocabulary entries the request carries. The registry can hold thousands; a request
## that carried all of them would be mostly words this sheet will never use. Deterministic:
## the list is sorted before it is cut, so the same sheet always sends the same words.
const VOCABULARY_LIMIT := 400

## The shape the answer must arrive in. One list, one row per line of the sheet, nothing else.
const REPLY_SCHEMA := "{\"rows\": [{\"object\": \"<object name>\", \"ace_id\": \"<Provider::Id>\", \"params\": {\"<param id>\": \"<value>\"}}]}"

## Test/offline seam: a Callable taking the request Dictionary and returning the reply text.
## When set it REPLACES the live HTTP call, so the suite drives the whole pipeline with no network.
static var transport: Callable = Callable()


## Which of the three Ask settings the project is on. Anything unrecognised reads as off, so a
## typo in project.godot can never turn Ask on by accident.
static func mode() -> String:
	var value: String = str(ProjectSettings.get_setting(SETTING_MODE, MODE_OFF)).strip_edges()
	if value == MODE_KEY or value == MODE_LOCAL:
		return value
	return MODE_OFF


## True when Ask has been turned on AND has somewhere to ask. An endpoint-less "on" is still off:
## there is nothing to send to, and pretending otherwise would fail at the worst moment.
static func is_on() -> bool:
	if mode() == MODE_OFF:
		return false
	return not endpoint().is_empty()


static func endpoint() -> String:
	return str(ProjectSettings.get_setting(SETTING_ENDPOINT, "")).strip_edges()


static func model() -> String:
	return str(ProjectSettings.get_setting(SETTING_MODEL, "")).strip_edges()


static func api_key() -> String:
	return str(ProjectSettings.get_setting(SETTING_KEY, "")).strip_edges()


# ── What the request carries ─────────────────────────────────────────────────────────────────
## The sheet's objects, one per line: the name a row would say, and what it is. Sorted, so the
## same sheet always describes itself the same way.
static func object_census(sheet: EventSheetResource) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	if sheet == null:
		return lines
	var facts: Dictionary = EventSheetObjectFacts.sheet_object_facts(sheet)
	var names: Array = facts.keys()
	names.sort()
	for object_name: Variant in names:
		var entry: Variant = facts[object_name]
		var kind: String = ""
		if entry is Dictionary:
			kind = str((entry as Dictionary).get("type", (entry as Dictionary).get("class_name", "")))
		lines.append("%s (%s)" % [str(object_name), kind] if not kind.is_empty() else str(object_name))
	return lines


## The vocabulary the sheet can WRITE: one line per condition or action, giving the id a reply
## must quote, the words the picker shows, and the parameters it takes. Expressions are left out -
## a proposal is rows, and an expression is never a row.
static func vocabulary(definitions: Array) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for entry: Variant in definitions:
		if not (entry is ACEDefinition):
			continue
		var definition: ACEDefinition = entry
		if definition.ace_type == ACEDefinition.ACEType.EXPRESSION:
			continue
		lines.append("%s | %s | %s | %s" % [definition.get_identifier(), kind_word(definition.ace_type),
			definition.display_name, ", ".join(param_ids(definition))])
	lines.sort()
	if lines.size() > VOCABULARY_LIMIT:
		lines.resize(VOCABULARY_LIMIT)
	return lines


## The word the sheet uses for what an entry IS - the same three words the lanes use.
static func kind_word(ace_type: int) -> String:
	if ace_type == ACEDefinition.ACEType.TRIGGER:
		return "trigger"
	if ace_type == ACEDefinition.ACEType.CONDITION:
		return "condition"
	return "action"


## The parameter ids a definition declares, in order. These are the only keys a reply may set.
static func param_ids(definition: ACEDefinition) -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for parameter: Variant in definition.parameters:
		if parameter is Object and parameter.get("id") != null:
			ids.append(str(parameter.get("id")))
		elif parameter is Dictionary:
			ids.append(str((parameter as Dictionary).get("id", "")))
	return ids


## Everything that would be sent, assembled and inspectable BEFORE anything is sent. The suite
## pins this whole Dictionary, which is how "exactly what the Manual says is sent" stays true.
static func build_request(sentence: String, sheet: EventSheetResource, definitions: Array) -> Dictionary:
	var instructions: PackedStringArray = PackedStringArray([
		"You are filling in rows of an event sheet. Answer with JSON and nothing else.",
		"Answer shape: %s" % REPLY_SCHEMA,
		"Use ONLY ace_id values from the vocabulary below. Never invent one, never answer with code.",
		"Use ONLY parameter ids the entry declares. Leave a parameter out rather than guessing it.",
		"Objects in this sheet:",
		"\n".join(object_census(sheet)),
		"Vocabulary this sheet can write (id | kind | words | parameters):",
		"\n".join(vocabulary(definitions)),
	])
	return {
		"model": model(),
		"temperature": 0,
		"messages": [
			{"role": "system", "content": "\n".join(instructions)},
			{"role": "user", "content": sentence.strip_edges()},
		],
	}


# ── Asking ───────────────────────────────────────────────────────────────────────────────────
## The one place a request can leave. Returns {sent, reply, error}: `sent` is false and `reply`
## empty whenever Ask is off, the sentence is blank, or no transport answered - so a caller can
## always say truthfully whether anything went out.
static func ask(sentence: String, sheet: EventSheetResource, definitions: Array) -> Dictionary:
	if sentence.strip_edges().is_empty():
		return {"sent": false, "reply": "", "error": "Type what you want to happen first."}
	if not is_on():
		return {"sent": false, "reply": "", "error":
			"Ask is off. Turn it on in Project Settings ▸ EventSheets ▸ Ask and give it an endpoint."}
	var request: Dictionary = build_request(sentence, sheet, definitions)
	if not transport.is_valid():
		return {"sent": false, "reply": "", "error":
			"Ask has no way to reach %s from the editor yet - nothing was sent." % endpoint()}
	return {"sent": true, "reply": str(transport.call(request)), "error": ""}


# ── Checking the answer ──────────────────────────────────────────────────────────────────────
## Every row the reply proposed, checked against the registry. Returns
## {rows, dropped, error}: `rows` are the ones the project can actually say, `dropped` names each
## one it could not and why. A reply that is not JSON, or that has no rows list, is one error and
## no rows - never a half-applied guess.
static func validate(reply: String, definitions: Array) -> Dictionary:
	var parsed: Variant = JSON.parse_string(_strip_fences(reply))
	if not (parsed is Dictionary) or not ((parsed as Dictionary).get("rows") is Array):
		return {"rows": [], "dropped": PackedStringArray(),
			"error": "The answer was not a list of rows - nothing to propose."}
	var by_id: Dictionary = {}
	for entry: Variant in definitions:
		if entry is ACEDefinition:
			by_id[(entry as ACEDefinition).get_identifier()] = entry
	var rows: Array = []
	var dropped: PackedStringArray = PackedStringArray()
	for entry: Variant in ((parsed as Dictionary)["rows"] as Array):
		if not (entry is Dictionary):
			dropped.append("a row that was not a row")
			continue
		var row: Dictionary = entry
		var ace_id: String = str(row.get("ace_id", "")).strip_edges()
		if not by_id.has(ace_id):
			dropped.append("%s - this project has no such entry" % (ace_id if not ace_id.is_empty() else "a row with no ace_id"))
			continue
		var definition: ACEDefinition = by_id[ace_id]
		var declared: PackedStringArray = param_ids(definition)
		var params: Dictionary = {}
		var supplied: Variant = row.get("params", {})
		if supplied is Dictionary:
			var keys: Array = (supplied as Dictionary).keys()
			keys.sort()
			for key: Variant in keys:
				if declared.has(str(key)):
					params[str(key)] = str((supplied as Dictionary)[key])
				else:
					dropped.append("%s on %s - not a parameter it takes" % [str(key), ace_id])
		rows.append({
			"object": str(row.get("object", "")).strip_edges(),
			"ace_id": ace_id,
			"params": params,
			"kind": kind_word(definition.ace_type),
			"words": definition.display_name,
		})
	return {"rows": rows, "dropped": dropped, "error": ""}


## The proposal as the sheet would read it - the plain-text listing shape, "+ " in front of a
## condition and "-> " in front of an action, so the preview says exactly what the rows will say.
static func proposal_lines(rows: Array) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for entry: Variant in rows:
		if not (entry is Dictionary):
			continue
		var row: Dictionary = entry
		var subject: String = str(row.get("object", ""))
		var words: String = str(row.get("words", ""))
		var head: String = "%s: %s" % [subject, words] if not subject.is_empty() else words
		var params: Dictionary = row.get("params", {})
		if not params.is_empty():
			var pairs: PackedStringArray = PackedStringArray()
			var keys: Array = params.keys()
			keys.sort()
			for key: Variant in keys:
				pairs.append(str(params[key]))
			head += " (%s)" % ", ".join(pairs)
		lines.append(("-> " if str(row.get("kind")) == "action" else "+ ") + head)
	return lines


# ── Turning a checked proposal into rows ─────────────────────────────────────────────────────
## The proposal as real event rows. Conditions and triggers open an event; the actions that
## follow hang under it, so one idea is one event and one action is one row - the sheet's own
## rules, applied to a proposal exactly as they are applied to typing. `uid_source` mints the
## `{uid}` tokens a stateful template needs (the dock's own minter at apply time).
static func proposal_events(rows: Array, definitions: Array, uid_source: Callable = Callable()) -> Array:
	var by_id: Dictionary = {}
	for entry: Variant in definitions:
		if entry is ACEDefinition:
			by_id[(entry as ACEDefinition).get_identifier()] = entry
	var events: Array = []
	var current: EventRow = null
	for entry: Variant in rows:
		if not (entry is Dictionary):
			continue
		var row: Dictionary = entry
		var definition: ACEDefinition = by_id.get(str(row.get("ace_id", ""))) as ACEDefinition
		if definition == null:
			continue
		var is_action: bool = str(row.get("kind")) == "action"
		if current == null or (not is_action and not current.actions.is_empty()):
			current = EventRow.new()
			events.append(current)
		var params: Dictionary = _params_with_target(definition, row)
		if is_action:
			var action: ACEAction = ACEAction.new()
			action.provider_id = definition.provider_id
			action.ace_id = definition.id
			action.params = params
			action.codegen_template = _baked_template(definition, uid_source)
			current.actions.append(action)
		else:
			var condition: ACECondition = ACECondition.new()
			condition.provider_id = definition.provider_id
			condition.ace_id = definition.id
			condition.params = params
			condition.codegen_template = _baked_template(definition, uid_source)
			current.conditions.append(condition)
	return events


## A sheet holding nothing but the proposal - what "Try in a scratch sheet" opens. The host class
## is copied from the sheet the reader asked from, so the scratch rows compile in the same world.
static func proposal_sheet(rows: Array, definitions: Array, host: EventSheetResource,
		uid_source: Callable = Callable()) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	if host != null:
		sheet.host_class = host.host_class
		sheet.host_node_path = host.host_node_path
	for event: Variant in proposal_events(rows, definitions, uid_source):
		sheet.events.append(event)
	return sheet


static func _params_with_target(definition: ACEDefinition, row: Dictionary) -> Dictionary:
	var params: Dictionary = (row.get("params", {}) as Dictionary).duplicate()
	var subject: String = str(row.get("object", "")).strip_edges()
	# A node-scoped entry carries an optional "On node" target; naming the object there is how a
	# proposal says "do this to the enemy" without inventing a word the sheet does not have.
	if not subject.is_empty() and not params.has("target") and param_ids(definition).has("target"):
		params["target"] = subject
	return params


static func _baked_template(definition: ACEDefinition, uid_source: Callable) -> String:
	var template: String = str(definition.metadata.get("codegen_template", ""))
	if template.contains("{uid}"):
		template = template.replace("{uid}", str(uid_source.call()) if uid_source.is_valid() else "ask")
	return template


static func _strip_fences(text: String) -> String:
	var stripped: String = text.strip_edges()
	if stripped.begins_with("```"):
		var first_newline: int = stripped.find("\n")
		if first_newline != -1:
			stripped = stripped.substr(first_newline + 1)
		if stripped.ends_with("```"):
			stripped = stripped.substr(0, stripped.length() - 3)
	return stripped.strip_edges()
