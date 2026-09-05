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
		"last_button_name": {"type": "String", "default": "", "exported": false},
		"needle_colour": {"type": "Color", "default": Color(0.66, 0.80, 1.0, 1.0), "exported": true, "attributes": {"tooltip": "The colour a Set Needle needle is drawn in while the value is inside its warning mark."}},
		"needle_warning_colour": {"type": "Color", "default": Color(1.0, 0.45, 0.38, 1.0), "exported": true, "attributes": {"tooltip": "The colour a Set Needle needle turns once the value has drifted past its warning mark."}},
		"toast_seconds": {"type": "float", "default": 2.0, "exported": true, "attributes": {"tooltip": "How long a toast stays before fading (seconds).", "range": {"min": "0.2", "max": "10", "step": "0.1"}}},
		"ui_cache": {"type": "Dictionary", "default": {}, "exported": false},
		"bar_lags": {"type": "Dictionary", "default": {}, "exported": false},
		"damage_types": {"type": "Resource", "default": null, "exported": true, "attributes": {"tooltip": "The DamageTypeSet this game uses, if it has one. Pop Floating Text As takes a number's colour from it, so a fire number is orange without a colour being typed into the row. Leave it empty and those numbers are drawn white."}},
		"crit_text_scale": {"type": "float", "default": 1.6, "exported": true, "attributes": {"tooltip": "How much bigger a number popped with the style \"crit\" is drawn, when no styles file names that style. The whole language of a critical hit in one number.", "range": {"min": "1", "max": "4", "step": "0.1"}}},
		"text_styles": {"type": "Resource", "default": null, "exported": true, "attributes": {"tooltip": "The FloatingTextStyles file this game uses, if it has one. Pop Floating Text As takes a number's size, colour, rise, shake and lifetime from it, so the manners a number is drawn in are one file you edit rather than five numbers repeated through the sheets. Leave it empty and the numbers are drawn the way they always were."}}
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
		"\ton_button_pressed.emit()",
		"",
		"## @ace_expression",
		"## @ace_name(\"Bar Lag Value\")",
		"func bar_lag_value(bar_name: String) -> float:",
		"\tvar record: Variant = bar_lags.get(bar_name)",
		"\treturn float((record as Dictionary)[\"ghost\"]) if record is Dictionary else bar_value(bar_name)",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Bar Lagging\")",
		"func is_bar_lagging(bar_name: String) -> bool:",
		"\tvar record: Variant = bar_lags.get(bar_name)",
		"\tif not record is Dictionary:",
		"\t\treturn false",
		"\treturn not is_equal_approx(float((record as Dictionary)[\"ghost\"]), bar_value(bar_name))",
		"",
		"# The underlay's own tick, and the whole of its cost. It PARKS itself the first frame it finds",
		"# nothing to follow, so a HUD with no lagging bar on it runs no code at all - and a Set Bar Lag",
		"# row turns it back on. Nothing is allocated here per frame: the record is the one made when the",
		"# lag was armed, and the underlay is one ColorRect made once and moved.",
		"func _process(delta: float) -> void:",
		"\tif bar_lags.is_empty():",
		"\t\tset_process(false)",
		"\t\treturn",
		"\tfor bar_name: String in bar_lags.keys():",
		"\t\t_follow_bar(bar_name, delta)",
		"",
		"# One bar's underlay, moved one frame. A LOSS is what an underlay is for, so a drop restarts the",
		"# wait and the underlay is left where it was until the wait is spent; after that it slides down to",
		"# the value, taking the lag seconds to cross the whole bar. A GAIN has nothing to show, so the",
		"# underlay lands with the bar rather than trailing a good thing.",
		"func _follow_bar(bar_name: String, delta: float) -> void:",
		"\tvar record: Dictionary = bar_lags[bar_name]",
		"\tvar target: Node = _ui(bar_name)",
		"\tif not target is Range:",
		"\t\tbar_lags.erase(bar_name)",
		"\t\treturn",
		"\tvar bar: Range = target as Range",
		"\tvar span: float = maxf(bar.max_value - bar.min_value, 0.001)",
		"\tvar seconds: float = maxf(float(record[\"seconds\"]), 0.001)",
		"\tvar ghost: float = float(record[\"ghost\"])",
		"\tif bar.value < float(record[\"last\"]):",
		"\t\trecord[\"wait\"] = seconds",
		"\trecord[\"last\"] = bar.value",
		"\tif bar.value >= ghost:",
		"\t\tghost = bar.value",
		"\telif float(record[\"wait\"]) > 0.0:",
		"\t\trecord[\"wait\"] = maxf(float(record[\"wait\"]) - delta, 0.0)",
		"\telse:",
		"\t\tghost = move_toward(ghost, bar.value, span * delta / seconds)",
		"\trecord[\"ghost\"] = ghost",
		"\t_draw_bar_lag(bar, bar.value, ghost, record[\"colour\"])",
		"",
		"# The underlay itself: one ColorRect inside the bar, covering the stretch between where the bar",
		"# is now and where it was - which is the empty part of the bar, so nothing the bar draws is",
		"# covered up. Built the first time and moved every frame after, and hidden the moment the two",
		"# values agree, which is what makes a bar that has not been hit look untouched.",
		"func _draw_bar_lag(bar: Range, value: float, ghost: float, colour: Color) -> void:",
		"\tvar underlay: ColorRect = bar.get_node_or_null(\"__bar_lag\") as ColorRect",
		"\tif underlay == null:",
		"\t\tunderlay = ColorRect.new()",
		"\t\tunderlay.name = \"__bar_lag\"",
		"\t\tunderlay.mouse_filter = Control.MOUSE_FILTER_IGNORE",
		"\t\tbar.add_child(underlay)",
		"\tunderlay.color = colour",
		"\tvar span: float = maxf(bar.max_value - bar.min_value, 0.001)",
		"\tvar left: float = clampf((value - bar.min_value) / span, 0.0, 1.0) * bar.size.x",
		"\tvar right: float = clampf((ghost - bar.min_value) / span, 0.0, 1.0) * bar.size.x",
		"\tunderlay.position = Vector2(left, 0.0)",
		"\tunderlay.size = Vector2(maxf(right - left, 0.0), bar.size.y)",
		"\tunderlay.visible = right - left > 0.5"
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

	# THE ONE HUD ELEMENT EVERY GAME HAS: the bar whose underlay trails the real value down after a
	# hit, so a player can see how much they just lost rather than only how much they have left.
	#
	# It sits BESIDE Set Bar rather than growing it. Set Bar's three arguments are a shipped promise,
	# and the underlay does not need to be told anything when a value changes: it WATCHES the bar. So
	# a bar filled by Set Bar, by a sheet writing the Range directly, or by an animation all trail the
	# same way - and arming the lag is a row somebody runs once at startup rather than a fourth
	# argument on every hit.
	Lib.append_function(sheet, "set_bar_lag", "Set Bar Lag", "UI",
		"Gives a named bar an underlay that follows it DOWN after a delay, so a hit shows how much was just lost. The underlay waits the seconds you name and then slides to the new value, taking those same seconds to cross the whole bar; a bar going UP has nothing to trail, so the underlay lands with it. It watches the bar rather than being told, so any way the value is set - Set Bar, a sheet writing the Range, an animation - trails the same. Seconds of 0 takes the underlay away again. Nothing is added to the scene but one rectangle inside the bar, built the first time and hidden whenever the two values agree.",
		[["bar_name", "String"], ["seconds", "float"], ["lag_colour", "Color"]],
		"\n".join(PackedStringArray([
		"var target: Node = _ui(bar_name)",
		"if not target is Range:",
		"\treturn",
		"var bar: Range = target as Range",
		"if seconds <= 0.0:",
		"\tbar_lags.erase(bar_name)",
		"\tvar gone: Node = bar.get_node_or_null(\"__bar_lag\")",
		"\tif gone != null:",
		"\t\tgone.queue_free()",
		"\treturn",
		"bar_lags[bar_name] = {\"seconds\": seconds, \"colour\": lag_colour, \"ghost\": bar.value, \"last\": bar.value, \"wait\": 0.0}",
		"set_process(true)"
	])))
	_default(sheet, "seconds", "0.6")
	_default(sheet, "lag_colour", "Color(0.85, 0.25, 0.25, 0.8)")

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

	# A spawned label has no name to look up, so this one skips _ui() and parents the new
	# Label onto the host (the UI root) itself, at the position it was asked for.
	Lib.append_function(sheet, "pop_floating_text", "Pop Floating Text", "UI",
		"Pops a damage number or score popup at a position: it drifts up, fades out and frees itself. No label to place, no tween to write, no cleanup to remember.",
		[["text", "String"], ["at", "Vector2"], ["color", "Color"]], "\n".join(PackedStringArray([
		"var label: Label = Label.new()",
		"label.text = text",
		"label.modulate = color",
		"label.position = at",
		"if host != null:",
		"\thost.add_child(label)",
		"else:",
		"\tadd_child(label)",
		"var pop: Tween = label.create_tween()",
		"pop.set_parallel(true)",
		"pop.tween_property(label, \"position:y\", at.y - 24.0, 0.7)",
		"pop.tween_property(label, \"modulate:a\", 0.0, 0.7)",
		"pop.set_parallel(false)",
		"pop.tween_callback(label.queue_free)"
	])))
	_default(sheet, "color", "Color.WHITE")

	# THE SAME POP, IN THE COLOUR OF THE THING THAT CAUSED IT. Pop Floating Text takes a Color, which
	# means every damage row in the game has to know what colour fire is - the same list of colours
	# retyped in front of every hit. This row takes the WORD instead and looks the colour up in the
	# DamageTypeSet the game already owns, so renaming a colour is editing one file.
	#
	# It sits BESIDE Pop Floating Text rather than growing it: that row's three arguments are a
	# shipped promise, and a fourth would rewrite every sheet already using it.
	#
	# "crit" is the one style that is not a damage type, because a critical is not a kind of damage -
	# it is the same damage, louder. It reads from the set if the set names it, and is drawn bigger
	# either way.
	Lib.append_function(sheet, "pop_floating_text_as", "Pop Floating Text As", "UI",
		"Pops a damage number in the colour its kind is drawn in - fire orange, ice blue - taken from the DamageTypeSet in this behaviour's Inspector rather than typed into the row. The style \"crit\" draws the number bigger, which is the whole language of a critical hit. Point Text Styles at a FloatingTextStyles file and the style also says how big, how far it rises, how hard it shakes and how long it stays. A style nothing names is drawn white and plain, so a game with neither file still gets its numbers.",
		[["text", "String"], ["style", "String"], ["at", "Vector2"]], "\n".join(PackedStringArray([
		"var tint: Color = Color.WHITE",
		"# Duck-typed rather than cast: the DamageTypeSet class ships in a pack a game need not have",
		"# installed, and a HUD that refused to draw a number because of that would be worse than one",
		"# drawing it white.",
		"if damage_types != null and damage_types.has_method(\"colour_of\"):",
		"\ttint = damage_types.call(\"colour_of\", style)",
		"# The manners, out of the styles file when this game has one. A style the file does not name keeps",
		"# the numbers this row was always drawn with, so a half-filled file is not a broken HUD - and the",
		"# colour is handed IN, because a style may say it takes the colour of the damage that caused it.",
		"var size: float = crit_text_scale if style == \"crit\" else 1.0",
		"var rise: float = 24.0",
		"var shake: float = 0.0",
		"var life: float = 0.7",
		"if text_styles != null and text_styles.has_method(\"has_style\") and text_styles.call(\"has_style\", style):",
		"\ttint = text_styles.call(\"colour_of\", style, tint)",
		"\tsize = text_styles.call(\"size_of\", style)",
		"\trise = text_styles.call(\"rise_of\", style)",
		"\tshake = text_styles.call(\"shake_of\", style)",
		"\tlife = text_styles.call(\"lifetime_of\", style)",
		"var label: Label = Label.new()",
		"label.text = text",
		"label.modulate = tint",
		"label.position = at",
		"label.scale = Vector2(size, size)",
		"if host != null:",
		"\thost.add_child(label)",
		"else:",
		"\tadd_child(label)",
		"var pop: Tween = label.create_tween()",
		"pop.set_parallel(true)",
		"pop.tween_property(label, \"position:y\", at.y - rise, life)",
		"pop.tween_property(label, \"modulate:a\", 0.0, life)",
		"# The shake is a wander in x that dies away as the number fades rather than a lean, because a",
		"# critical that rattles on its way up reads as a critical from across the screen.",
		"if shake > 0.0:",
		"\tvar wander: Callable = func(phase: float) -> void:",
		"\t\tlabel.position.x = at.x + sin(phase * TAU * 5.0) * shake * (1.0 - phase)",
		"\tpop.tween_method(wander, 0.0, 1.0, life)",
		"pop.set_parallel(false)",
		"pop.tween_callback(label.queue_free)"
	])))
	_hint(sheet, "style", "damage_type")

	# A meter with a CENTRE rather than a floor: balance on a rail or in a manual, a tug-of-war
	# bar, a lean, a tuning dial. A bar cannot show it - what matters is how far from the middle the
	# needle has drifted and which side it is on - so this builds the needle itself the first time it
	# is asked, inside whatever named Control the sheet points it at.
	Lib.append_function(sheet, "set_needle", "Set Needle", "UI",
		"Shows a value from -1 to 1 as a needle in a named Control, with a mark at dead centre. The needle is built inside that Control the first time this runs, so the only thing the scene needs is an empty box of the right size. Past the warning mark the needle turns the warning colour, which is the whole of a balance meter's language.",
		[["needle_name", "String"], ["value", "float"], ["warn_at", "float"]],
		"\n".join(PackedStringArray([
		"var frame: Node = _ui(needle_name)",
		"if not frame is Control:",
		"\treturn",
		"var box: Control = frame as Control",
		"var centre_mark: ColorRect = box.get_node_or_null(\"__needle_centre\") as ColorRect",
		"if centre_mark == null:",
		"\tcentre_mark = ColorRect.new()",
		"\tcentre_mark.name = \"__needle_centre\"",
		"\tcentre_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE",
		"\tcentre_mark.color = Color(1.0, 1.0, 1.0, 0.25)",
		"\tbox.add_child(centre_mark)",
		"var needle: ColorRect = box.get_node_or_null(\"__needle\") as ColorRect",
		"if needle == null:",
		"\tneedle = ColorRect.new()",
		"\tneedle.name = \"__needle\"",
		"\tneedle.mouse_filter = Control.MOUSE_FILTER_IGNORE",
		"\tbox.add_child(needle)",
		"var width: float = maxf(box.size.x, 1.0)",
		"var height: float = maxf(box.size.y, 1.0)",
		"centre_mark.size = Vector2(2.0, height)",
		"centre_mark.position = Vector2(width * 0.5 - 1.0, 0.0)",
		"needle.size = Vector2(4.0, height)",
		"needle.position = Vector2((clampf(value, -1.0, 1.0) * 0.5 + 0.5) * width - 2.0, 0.0)",
		"needle.color = needle_warning_colour if absf(value) >= warn_at else needle_colour"
	])))
	_default(sheet, "warn_at", "0.6")

	# The pack's hero verbs: starred + bold at the top of their picker section.
	Lib.verb_sentences(sheet, {
		"set_needle": "Set needle [b]{needle_name}[/b] to [b]{value}[/b], warning past [b]{warn_at}[/b]",
		"set_bar": "Set bar [b]{bar_name}[/b] to [b]{value}[/b] of [b]{max_value}[/b]",
		"set_bar_lag": "Set bar [b]{bar_name}[/b] lag to [b]{seconds}[/b] s in [b]{lag_colour}[/b]",
		"set_text": "Set text of [b]{control_name}[/b] to [b]{text}[/b]",
		"show_toast": "Show toast [b]{text}[/b]",
		"pop_floating_text": "Pop floating text [b]{text}[/b] at [b]{at}[/b]",
		"pop_floating_text_as": "Pop floating text [b]{text}[/b] as [b]{style}[/b] at [b]{at}[/b]",
	})
	Lib.feature_verbs(sheet, ["set_text", "set_bar", "show_toast"])
	return Lib.save_pack(sheet, "res://eventsheet_addons/hud_kit/hud_kit_behavior")


## Pre-fills the last-appended ACE's parameter default (authoring-time metadata only).
static func _default(sheet: EventSheetResource, param_id: String, value: String) -> void:
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.default_value = value


## Sets the parameter HINT on the last-appended row parameter - the key the params dialog and the
## completion list read to decide what a field offers. "damage_type" offers the names in the
## project's own DamageTypeSet files, so a style field suggests this game's kinds of damage rather than
## a vocabulary of guesses. A project with no set gets a plain field, never a wrong list.
static func _hint(sheet: EventSheetResource, param_id: String, hint: String) -> void:
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.hint = hint
