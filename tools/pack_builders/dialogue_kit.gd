# Pack builder - dialogue_kit (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Dialogue Kit behavior: queue lines, play them with a typewriter reveal, advance on one
## input action. Drop it under your UI root, name a panel and two labels, and a whole
## conversation is Queue Line calls plus the triggers - no dialogue system to write.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node"
	sheet.custom_class_name = "DialogueKitBehavior"
	sheet.addon_category = "UI"
	sheet.ace_expose_all_mode = "node"
	sheet.variables = {
		"panel_name": {"type": "String", "default": "DialoguePanel", "exported": true, "attributes": {"tooltip": "The named panel (any CanvasItem under the host) shown while dialogue runs."}},
		"speaker_label_name": {"type": "String", "default": "SpeakerLabel", "exported": true, "attributes": {"tooltip": "The named Label that shows who is talking."}},
		"text_label_name": {"type": "String", "default": "TextLabel", "exported": true, "attributes": {"tooltip": "The named Label the line types into."}},
		"chars_per_second": {"type": "float", "default": 40.0, "exported": true, "attributes": {"tooltip": "Typewriter speed; Advance mid-line completes it instantly.", "range": {"min": "1", "max": "400", "step": "1"}}},
		"advance_action": {"type": "String", "default": "ui_accept", "exported": true, "attributes": {"tooltip": "Input action that advances the dialogue (blank = no built-in input; call Advance yourself)."}},
		"line_queue": {"type": "Array", "default": [], "exported": false},
		"dialogue_active": {"type": "bool", "default": false, "exported": false},
		"typing": {"type": "bool", "default": false, "exported": false},
		"current_speaker": {"type": "String", "default": "", "exported": false},
		"current_text": {"type": "String", "default": "", "exported": false},
		"revealed_chars": {"type": "float", "default": 0.0, "exported": false},
		"ui_cache": {"type": "Dictionary", "default": {}, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Dialogue Kit behavior: queue lines (speaker + text), play them with a typewriter reveal into NAMED labels, advance on one input action (mid-line advance completes the line instantly). Triggers fire per line and per conversation, so portraits, sounds, and camera moves hang off the sheet - no dialogue system to write."
	sheet.events.append(about)

	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"## @ace_trigger",
		"## @ace_name(\"On Dialogue Started\")",
		"signal on_dialogue_started",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Dialogue Finished\")",
		"signal on_dialogue_finished",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Line Started\")",
		"signal on_line_started",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Line Finished\")",
		"signal on_line_finished",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Dialogue Active\")",
		"func is_dialogue_active() -> bool:",
		"\treturn dialogue_active",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Typing\")",
		"func is_typing() -> bool:",
		"\treturn typing",
		"",
		"## @ace_condition",
		"## @ace_name(\"Speaker Is\")",
		"func speaker_is(speaker: String) -> bool:",
		"\treturn current_speaker == speaker",
		"",
		"## @ace_expression",
		"## @ace_name(\"Current Speaker\")",
		"func current_speaker_value() -> String:",
		"\treturn current_speaker",
		"",
		"## @ace_expression",
		"## @ace_name(\"Current Text\")",
		"func current_text_value() -> String:",
		"\treturn current_text",
		"",
		"## @ace_expression",
		"## @ace_name(\"Lines Remaining\")",
		"func lines_remaining() -> float:",
		"\treturn float(line_queue.size())",
		"",
		"## Named-descendant lookup under the host, cached (freed nodes fall out on the next miss).",
		"func _ui(control_name: String) -> Node:",
		"\tvar cached: Variant = ui_cache.get(control_name)",
		"\tif cached is Node and is_instance_valid(cached):",
		"\t\treturn cached",
		"\tvar found: Node = host.find_child(control_name, true, false) if host != null else null",
		"\tif found != null:",
		"\t\tui_cache[control_name] = found",
		"\treturn found",
		"",
		"func _set_panel_visible(state: bool) -> void:",
		"\tvar panel: Node = _ui(panel_name)",
		"\tif panel is CanvasItem:",
		"\t\t(panel as CanvasItem).visible = state",
		"",
		"func _show_next_line() -> void:",
		"\tvar line: Dictionary = line_queue.pop_front()",
		"\tcurrent_speaker = str(line.get(\"speaker\", \"\"))",
		"\tcurrent_text = str(line.get(\"text\", \"\"))",
		"\trevealed_chars = 0.0",
		"\ttyping = true",
		"\tvar speaker_label: Node = _ui(speaker_label_name)",
		"\tif speaker_label != null:",
		"\t\tspeaker_label.set(\"text\", current_speaker)",
		"\tvar text_label: Node = _ui(text_label_name)",
		"\tif text_label != null:",
		"\t\ttext_label.set(\"text\", current_text)",
		"\t\ttext_label.set(\"visible_characters\", 0)",
		"\ton_line_started.emit()",
		"",
		"func _finish_line() -> void:",
		"\ttyping = false",
		"\tvar text_label: Node = _ui(text_label_name)",
		"\tif text_label != null:",
		"\t\ttext_label.set(\"visible_characters\", -1)",
		"\ton_line_finished.emit()"
	]))
	sheet.events.append(block)

	# The typewriter + the one-button advance, per frame while a conversation runs.
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"if not dialogue_active:",
		"\treturn",
		"if typing:",
		"\trevealed_chars += chars_per_second * delta",
		"\tvar text_label: Node = _ui(text_label_name)",
		"\tif text_label != null:",
		"\t\ttext_label.set(\"visible_characters\", int(revealed_chars))",
		"\tif int(revealed_chars) >= current_text.length():",
		"\t\t_finish_line()",
		"if not advance_action.is_empty() and InputMap.has_action(advance_action) and Input.is_action_just_pressed(advance_action):",
		"\tadvance_dialogue()"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	Lib.append_function(sheet, "queue_line", "Queue Line", "Dialogue",
		"Appends a line (speaker + text) to the conversation queue.",
		[["speaker", "String"], ["text", "String"]], "\n".join(PackedStringArray([
		"line_queue.append({\"speaker\": speaker, \"text\": text})"
	])))

	Lib.append_function(sheet, "start_dialogue", "Start Dialogue", "Dialogue",
		"Shows the panel and plays the queued lines from the top.",
		[], "\n".join(PackedStringArray([
		"if dialogue_active or line_queue.is_empty():",
		"\treturn",
		"dialogue_active = true",
		"_set_panel_visible(true)",
		"on_dialogue_started.emit()",
		"_show_next_line()"
	])))

	Lib.append_function(sheet, "advance_dialogue", "Advance", "Dialogue",
		"Mid-line: completes the line instantly. Otherwise: next line, or ends the conversation.",
		[], "\n".join(PackedStringArray([
		"if not dialogue_active:",
		"\treturn",
		"if typing:",
		"\t_finish_line()",
		"\treturn",
		"if line_queue.is_empty():",
		"\tend_dialogue()",
		"else:",
		"\t_show_next_line()"
	])))

	Lib.append_function(sheet, "end_dialogue", "End Dialogue", "Dialogue",
		"Hides the panel, clears any remaining lines, and fires On Dialogue Finished.",
		[], "\n".join(PackedStringArray([
		"if not dialogue_active:",
		"\treturn",
		"dialogue_active = false",
		"typing = false",
		"line_queue.clear()",
		"_set_panel_visible(false)",
		"on_dialogue_finished.emit()"
	])))

	return Lib.save_pack(sheet, "res://eventsheet_addons/dialogue_kit/dialogue_kit_behavior")
