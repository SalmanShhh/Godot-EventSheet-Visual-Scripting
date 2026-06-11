# Pack builder — state_machine (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")

## Minimal state machine: Set State action, On State Changed trigger, and an Is In State
## CONDITION authored as an annotated class-level GDScript block — the example of mixing
## expose-as-ACE functions with hand-annotated block ACEs in one behavior.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node"
	sheet.custom_class_name = "StateMachineBehavior"
	sheet.variables = {"state": {"type": "String", "default": "idle", "exported": true}}
	var about: CommentRow = CommentRow.new()
	about.text = "State machine behavior: Set State / Is In State from any sheet; On State Changed fires with (previous, next)."
	sheet.events.append(about)
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"## @ace_trigger",
		"## @ace_name(\"On State Changed\")",
		"## @ace_category(\"State Machine\")",
		"signal state_changed(previous: String, next: String)",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is In State\")",
		"## @ace_category(\"State Machine\")",
		"## @ace_codegen_template(\"$StateMachineBehavior.state == {state_name}\")",
		"func is_in_state(state_name: String) -> bool:",
		"\treturn state == state_name"
	]))
	sheet.events.append(block)

	var set_state: EventFunction = EventFunction.new()
	set_state.function_name = "set_state"
	set_state.expose_as_ace = true
	set_state.ace_display_name = "Set State"
	set_state.ace_category = "State Machine"
	set_state.description = "Switches to the given state and fires On State Changed."
	var next_param: ACEParam = ACEParam.new()
	next_param.id = "next"
	next_param.type_name = "String"
	set_state.params.append(next_param)
	var set_body: RawCodeRow = RawCodeRow.new()
	set_body.code = "\n".join(PackedStringArray([
		"if state == next:",
		"\treturn",
		"var previous: String = state",
		"state = next",
		"state_changed.emit(previous, next)"
	]))
	set_state.events.append(set_body)
	sheet.functions.append(set_state)
	return Lib.save_pack(sheet, "res://eventsheet_addons/state_machine/state_machine_behavior")
