# Godot EventSheets - Ask, pinned against a fake endpoint
#
# Ask is opt-in, external and preview-first, so the promises worth pinning are the ones a reader
# has to take on trust: that OFF sends nothing, that the request carries the three things the
# Manual says it carries and no fourth, that a reply naming vocabulary this project does not have
# is DROPPED rather than applied, and that what survives becomes ordinary rows.
#
# No network anywhere: the transport seam is a Callable, so the whole pipeline runs headless.
@tool
class_name AskTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true
	var previous_mode: Variant = ProjectSettings.get_setting(EventSheetAsk.SETTING_MODE, null)
	var previous_endpoint: Variant = ProjectSettings.get_setting(EventSheetAsk.SETTING_ENDPOINT, null)
	var previous_model: Variant = ProjectSettings.get_setting(EventSheetAsk.SETTING_MODEL, null)
	ok = _test_off_sends_nothing() and ok
	ok = _test_request_contents() and ok
	ok = _test_validation() and ok
	ok = _test_proposal() and ok
	EventSheetAsk.transport = Callable()
	ProjectSettings.set_setting(EventSheetAsk.SETTING_MODE, previous_mode)
	ProjectSettings.set_setting(EventSheetAsk.SETTING_ENDPOINT, previous_endpoint)
	ProjectSettings.set_setting(EventSheetAsk.SETTING_MODEL, previous_model)
	return ok


static func _test_off_sends_nothing() -> bool:
	var ok: bool = true
	ProjectSettings.set_setting(EventSheetAsk.SETTING_MODE, EventSheetAsk.MODE_OFF)
	ProjectSettings.set_setting(EventSheetAsk.SETTING_ENDPOINT, "https://example.invalid/v1/chat/completions")
	var reached: Array = []
	EventSheetAsk.transport = func(_request: Dictionary) -> String:
		reached.append(true)
		return "{}"
	ok = _check("off is off", EventSheetAsk.is_on(), false) and ok
	var answer: Dictionary = EventSheetAsk.ask("make the player jump", _sheet(), _definitions())
	ok = _check("nothing is sent while Ask is off", bool(answer.get("sent")), false) and ok
	ok = _check("the transport was never reached", reached.size(), 0) and ok
	ok = _check("and it says why", str(answer.get("error")).begins_with("Ask is off."), true) and ok
	ok = _check("no request was even built while off", answer.has("request"), false) and ok
	# On, but with nowhere to ask, is still off - there is nothing to send to.
	ProjectSettings.set_setting(EventSheetAsk.SETTING_MODE, EventSheetAsk.MODE_LOCAL)
	ProjectSettings.set_setting(EventSheetAsk.SETTING_ENDPOINT, "")
	ok = _check("on with no endpoint is still off", EventSheetAsk.is_on(), false) and ok
	ProjectSettings.set_setting(EventSheetAsk.SETTING_MODE, "sure why not")
	ok = _check("a word nobody recognises reads as off",
		EventSheetAsk.mode(), EventSheetAsk.MODE_OFF) and ok
	return ok


static func _test_request_contents() -> bool:
	var ok: bool = true
	ProjectSettings.set_setting(EventSheetAsk.SETTING_MODE, EventSheetAsk.MODE_LOCAL)
	ProjectSettings.set_setting(EventSheetAsk.SETTING_ENDPOINT, "http://localhost:1234/v1/chat/completions")
	ProjectSettings.set_setting(EventSheetAsk.SETTING_MODEL, "a-model")
	var request: Dictionary = EventSheetAsk.build_request("make the player jump", _sheet(), _definitions())
	ok = _check("the request names the model the reader configured", str(request.get("model")), "a-model") and ok
	ok = _check("exactly two messages go out", (request.get("messages") as Array).size(), 2) and ok
	var system: String = str(((request.get("messages") as Array)[0] as Dictionary).get("content"))
	var user: String = str(((request.get("messages") as Array)[1] as Dictionary).get("content"))
	ok = _check("the reader's own sentence is the second message", user, "make the player jump") and ok
	ok = _check("the answer shape is spelled out",
		system.contains(EventSheetAsk.REPLY_SCHEMA), true) and ok
	ok = _check("the vocabulary this sheet can write goes with it",
		system.contains("Core::Jump | action | Jump | height"), true) and ok
	ok = _check("expressions are not offered as rows",
		system.contains("Core::Score"), false) and ok
	# Nothing else. The Manual promises the sentence, the objects and the vocabulary; a request
	# that also carried the sheet's own rows would make that page a lie.
	ok = _check("no row of the sheet's own code is sent",
		system.contains("velocity") or user.contains("velocity"), false) and ok
	var mode_word: String = EventSheetAsk.mode()
	ok = _check("the mode is one of the three words", mode_word, EventSheetAsk.MODE_LOCAL) and ok
	return ok


static func _test_validation() -> bool:
	var ok: bool = true
	var checked: Dictionary = EventSheetAsk.validate(
		"{\"rows\": [{\"object\": \"Player\", \"ace_id\": \"Core::Jump\", \"params\": {\"height\": \"400\", \"colour\": \"red\"}},"
		+ " {\"object\": \"Player\", \"ace_id\": \"Core::Teleport\", \"params\": {}}]}",
		_definitions())
	ok = _check("only the row this project has words for survives",
		(checked.get("rows") as Array).size(), 1) and ok
	ok = _check("the surviving row keeps the parameter the entry declares",
		str(((checked.get("rows") as Array)[0] as Dictionary).get("params")), "{ \"height\": \"400\" }") and ok
	ok = _check("an unknown entry is named as dropped",
		str(checked.get("dropped")),
		"[\"colour on Core::Jump - not a parameter it takes\", \"Core::Teleport - this project has no such entry\"]") and ok
	# The reply text is dug out of the common chat wrapper, and an endpoint that simply answers with
	# the JSON is taken at its word. Neither is trusted - both go through validate next.
	ok = _check("the answer is unwrapped from the common chat shape",
		EventSheetAsk.reply_text_from_body(
			"{\"choices\": [{\"message\": {\"role\": \"assistant\", \"content\": \"{\\\"rows\\\": []}\"}}]}"),
		"{\"rows\": []}") and ok
	ok = _check("a bare answer is taken as it stands",
		EventSheetAsk.reply_text_from_body("{\"rows\": []}"), "{\"rows\": []}") and ok
	var broken: Dictionary = EventSheetAsk.validate("sorry, I cannot do that", _definitions())
	ok = _check("an answer that is not rows proposes nothing",
		(broken.get("rows") as Array).size(), 0) and ok
	ok = _check("and says so plainly", str(broken.get("error")),
		"The answer was not a list of rows - nothing to propose.") and ok
	return ok


static func _test_proposal() -> bool:
	var ok: bool = true
	ProjectSettings.set_setting(EventSheetAsk.SETTING_MODE, EventSheetAsk.MODE_LOCAL)
	ProjectSettings.set_setting(EventSheetAsk.SETTING_ENDPOINT, "http://localhost:1234/v1/chat/completions")
	EventSheetAsk.transport = func(_request: Dictionary) -> String:
		return "{\"rows\": [{\"object\": \"Player\", \"ace_id\": \"Core::OnFloor\", \"params\": {}}," \
			+ " {\"object\": \"Player\", \"ace_id\": \"Core::Jump\", \"params\": {\"height\": \"400\"}}]}"
	var answer: Dictionary = EventSheetAsk.ask("jump when on the floor", _sheet(), _definitions())
	ok = _check("pressing Ask does send", bool(answer.get("sent")), true) and ok
	var rows: Array = (EventSheetAsk.validate(str(answer.get("reply")), _definitions()).get("rows") as Array)
	ok = _check("the preview reads the way the sheet reads",
		str(EventSheetAsk.proposal_lines(rows)),
		"[\"+ Player: Is on floor\", \"-> Player: Jump (400)\"]") and ok
	var events: Array = EventSheetAsk.proposal_events(rows, _definitions())
	ok = _check("one idea is one event", events.size(), 1) and ok
	ok = _check("the condition lands in the condition lane",
		((events[0] as EventRow).conditions[0] as ACECondition).ace_id, "OnFloor") and ok
	ok = _check("the action lands in the action lane",
		((events[0] as EventRow).actions[0] as ACEAction).ace_id, "Jump") and ok
	ok = _check("and nothing is applied by arriving - the sheet is untouched",
		_sheet().events.size(), 0) and ok
	return ok


static func _sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "CharacterBody2D"
	return sheet


static func _definitions() -> Array:
	return [
		_definition("Core", "Jump", "Jump", ACEDefinition.ACEType.ACTION, ["height"]),
		_definition("Core", "OnFloor", "Is on floor", ACEDefinition.ACEType.CONDITION, []),
		_definition("Core", "Score", "Score", ACEDefinition.ACEType.EXPRESSION, []),
	]


static func _definition(provider: String, id: String, words: String, ace_type: int,
		parameter_ids: Array) -> ACEDefinition:
	var definition: ACEDefinition = ACEDefinition.new()
	definition.provider_id = provider
	definition.id = id
	definition.display_name = words
	definition.ace_type = ace_type
	for parameter_id: String in parameter_ids:
		var parameter: ACEParam = ACEParam.new()
		parameter.id = parameter_id
		definition.parameters.append(parameter)
	return definition


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] ask_test: %s" % label)
		return true
	print("[FAIL] ask_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
