@tool
class_name TypeCheckStatefulProbeTest
extends RefCounted

# A verb that keeps a clock or a flag calls a helper function its row declares beside it. The kind-of-value
# check compiles the verb's template in a stand-in script; that script must carry the same helper, or Godot
# prints a parse error to the Output every time a field of the row is looked at.

const SUPPORT := preload("res://tests/support.gd")
const NAME := "type_check_stateful_probe_test"


static func run() -> bool:
	var ok: bool = true
	ok = _no_stateful_verb_makes_the_engine_complain() and ok
	ok = _a_wrong_value_in_a_stateful_verb_is_still_refused() and ok
	return ok


static func _sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	return sheet


## Every field of every verb that declares a member, judged at its default, under a Logger that hears what
## the engine prints while a stand-in script is loaded.
static func _no_stateful_verb_makes_the_engine_complain() -> bool:
	var heard: Array = []
	var verbs: int = 0
	for descriptor: ACEDescriptor in ACERegistry.get_builtin_descriptors():
		if descriptor.member_template.strip_edges().is_empty() or descriptor.params.is_empty():
			continue
		verbs += 1
		var values: Dictionary = {}
		for param: ACEParam in descriptor.params:
			values[param.id] = str(param.default_value)
		for param: ACEParam in descriptor.params:
			var ear: EventSheetTypeCheck.Ear = EventSheetTypeCheck.Ear.new()
			OS.add_logger(ear)
			EventSheetTypeCheck.check_field(descriptor.codegen_template, param.id, str(param.default_value), values,
				_sheet(), PackedStringArray(), null, descriptor.member_template)
			OS.remove_logger(ear)
			# A verb written for another kind of node (an animation player) is judged on a plain Node here and may
			# say so of the host; what must never be said is that the verb's own helper is missing.
			for message: Dictionary in ear.messages:
				if str(message.get("text", "")).contains("Function \"__"):
					heard.append("%s.%s: %s" % [descriptor.ace_id, param.id, str(message.get("text", ""))])
	var ok: bool = SUPPORT.check(NAME, "stateful verbs with fields were walked", verbs >= 20, true)
	ok = SUPPORT.check(NAME, "no stand-in script printed that a verb helper is missing", heard, []) and ok
	return ok


static func _a_wrong_value_in_a_stateful_verb_is_still_refused() -> bool:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", "EveryRandomSeconds")
	var values: Dictionary = {"min_seconds": "\"soon\"", "max_seconds": "5.0"}
	var finding: Dictionary = EventSheetTypeCheck.check_field(descriptor.codegen_template, "min_seconds", "\"soon\"", values,
		_sheet(), PackedStringArray(), null, descriptor.member_template)
	var ok: bool = SUPPORT.check(NAME, "text where seconds belong is refused", str(finding.get("level", "")), "error")
	var fine: Dictionary = EventSheetTypeCheck.check_field(descriptor.codegen_template, "min_seconds", "1.5",
		{"min_seconds": "1.5", "max_seconds": "5.0"}, _sheet(), PackedStringArray(), null, descriptor.member_template)
	ok = SUPPORT.check(NAME, "a number is accepted", fine, {}) and ok
	return ok
