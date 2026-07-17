# Pack builder - hud_kit (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## HUD Kit behavior: menus and HUDs by NAME, no node wiring. Drop it under your UI root
## (a CanvasLayer or Control) and drive named descendants: set label text, fill bars,
## switch menu screens, pop toasts - and every descendant Button reports its presses
## through one trigger, so a whole menu needs zero connected signals.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node"
	sheet.custom_class_name = "HudKitBehavior"
	sheet.class_description = "Drives a whole menu or HUD by node name with zero signal wiring. Attach it to your UI root and set labels, fill bars, show panels, flip screens, and pop toasts by passing the name string, while every descendant Button auto-wires into one On Button Pressed trigger."
	sheet.addon_category = "UI"
	sheet.ace_expose_all_mode = "node"
	sheet.variables = {
		"auto_connect_buttons": {"type": "bool", "default": true, "exported": true, "attributes": {"tooltip": "On Ready, wire every descendant Button's pressed signal into On Button Pressed. Re-run with Connect Buttons after spawning UI."}},
		"toast_seconds": {"type": "float", "default": 2.0, "exported": true, "attributes": {"tooltip": "How long a toast stays before fading (seconds).", "range": {"min": "0.2", "max": "10", "step": "0.1"}}},
		"last_button_name": {"type": "String", "default": "", "exported": false},
		"ui_cache": {"type": "Dictionary", "default": {}, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "HUD Kit behavior: drive a menu or HUD by NODE NAME - set label text, fill bars, switch menu screens (show one panel, hide its siblings), pop auto-fading toasts - and every descendant Button reports through one On Button Pressed trigger, so a whole menu needs zero connected signals. Drop it under your UI root (CanvasLayer or Control)."
	sheet.events.append(about)

	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"## @ace_trigger",
		"## @ace_name(\"On Button Pressed\")",
		"signal on_button_pressed",
		"",
		"## @ace_condition",
		"## @ace_name(\"Button Is\")",
		"func button_is(button_name: String) -> bool:",
		"\treturn last_button_name == button_name",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Panel Visible\")",
		"func is_panel_visible(panel_name: String) -> bool:",
		"\tvar target: Node = _ui(panel_name)",
		"\treturn target is CanvasItem and (target as CanvasItem).visible",
		"",
		"## @ace_expression",
		"## @ace_name(\"Last Button Name\")",
		"func last_button_name_value() -> String:",
		"\treturn last_button_name",
		"",
		"## @ace_expression",
		"## @ace_name(\"Bar Value\")",
		"func bar_value(bar_name: String) -> float:",
		"\tvar target: Node = _ui(bar_name)",
		"\treturn (target as Range).value if target is Range else 0.0",
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
		"func _collect_buttons(node: Node, out: Array) -> void:",
		"\tif node is BaseButton:",
		"\t\tout.append(node)",
		"\tfor child: Node in node.get_children():",
		"\t\t_collect_buttons(child, out)",
		"",
		"func _on_hud_button_pressed(button_name: String) -> void:",
		"\tlast_button_name = button_name",
		"\ton_button_pressed.emit()"
	]))
	sheet.events.append(block)

	# Wire the whole menu once at startup (opt-out via the exported toggle).
	var on_ready: EventRow = EventRow.new()
	on_ready.trigger_provider_id = "Core"
	on_ready.trigger_id = "OnReady"
	var on_ready_body: RawCodeRow = RawCodeRow.new()
	on_ready_body.code = "\n".join(PackedStringArray([
		"if auto_connect_buttons:",
		"\tconnect_buttons()"
	]))
	on_ready.actions.append(on_ready_body)
	sheet.events.append(on_ready)

	Lib.append_function(sheet, "connect_buttons", "Connect Buttons", "UI",
		"Wires every descendant Button's pressed signal into On Button Pressed (idempotent; re-run after spawning UI).",
		[], "\n".join(PackedStringArray([
		"if host == null:",
		"\treturn",
		"var buttons: Array = []",
		"_collect_buttons(host, buttons)",
		"for button: BaseButton in buttons:",
		"\tvar handler: Callable = _on_hud_button_pressed.bind(str(button.name))",
		"\tif not button.pressed.is_connected(handler):",
		"\t\tbutton.pressed.connect(handler)"
	])))

	Lib.append_function(sheet, "set_text", "Set Text", "UI",
		"Sets the text of a named Label, RichTextLabel, Button or LineEdit.",
		[["control_name", "String"], ["text", "String"]], "\n".join(PackedStringArray([
		"var target: Node = _ui(control_name)",
		"if target != null:",
		"\ttarget.set(\"text\", text)"
	])))

	Lib.append_function(sheet, "set_bar", "Set Bar", "UI",
		"Sets a named ProgressBar/TextureProgressBar's value (max_value too when > 0).",
		[["bar_name", "String"], ["value", "float"], ["max_value", "float"]], "\n".join(PackedStringArray([
		"var target: Node = _ui(bar_name)",
		"if target is Range:",
		"\tif max_value > 0.0:",
		"\t\t(target as Range).max_value = max_value",
		"\t(target as Range).value = value"
	])))

	Lib.append_function(sheet, "show_panel", "Show Panel", "UI",
		"Makes a named panel (any CanvasItem) visible.",
		[["panel_name", "String"]], "\n".join(PackedStringArray([
		"var target: Node = _ui(panel_name)",
		"if target is CanvasItem:",
		"\t(target as CanvasItem).visible = true"
	])))

	Lib.append_function(sheet, "hide_panel", "Hide Panel", "UI",
		"Hides a named panel (any CanvasItem).",
		[["panel_name", "String"]], "\n".join(PackedStringArray([
		"var target: Node = _ui(panel_name)",
		"if target is CanvasItem:",
		"\t(target as CanvasItem).visible = false"
	])))

	Lib.append_function(sheet, "toggle_panel", "Toggle Panel", "UI",
		"Flips a named panel's visibility.",
		[["panel_name", "String"]], "\n".join(PackedStringArray([
		"var target: Node = _ui(panel_name)",
		"if target is CanvasItem:",
		"\t(target as CanvasItem).visible = not (target as CanvasItem).visible"
	])))

	Lib.append_function(sheet, "switch_screen", "Switch Screen", "UI",
		"Shows the named panel and hides its sibling panels - one call flips a whole menu screen.",
		[["panel_name", "String"]], "\n".join(PackedStringArray([
		"var target: Node = _ui(panel_name)",
		"if not (target is CanvasItem) or target.get_parent() == null:",
		"\treturn",
		"for sibling: Node in target.get_parent().get_children():",
		"\tif sibling is CanvasItem:",
		"\t\t(sibling as CanvasItem).visible = (sibling == target)"
	])))

	Lib.append_function(sheet, "show_toast", "Show Toast", "UI",
		"Pops a bottom-centre message that fades out after toast_seconds.",
		[["text", "String"]], "\n".join(PackedStringArray([
		"var toast: Label = Label.new()",
		"toast.text = text",
		"toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER",
		"toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)",
		"toast.offset_top = -64.0",
		"toast.offset_bottom = -40.0",
		"toast.offset_left = -200.0",
		"toast.offset_right = 200.0",
		"if host != null:",
		"\thost.add_child(toast)",
		"else:",
		"\tadd_child(toast)",
		"var fade: Tween = toast.create_tween()",
		"fade.tween_interval(maxf(0.2, toast_seconds))",
		"fade.tween_property(toast, \"modulate:a\", 0.0, 0.35)",
		"fade.tween_callback(toast.queue_free)"
	])))

	return Lib.save_pack(sheet, "res://eventsheet_addons/hud_kit/hud_kit_behavior")
