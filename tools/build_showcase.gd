# Release showcase builder (the release ritual, CONTRIBUTING §Release ritual):
# regenerates demo/showcase/ — a tiny playable scene exercising the release's headline
# features. v0.7.0: if/elif BRANCHING that round-trips the new reverse-lift (open
# showcase_v070.gd as a sheet and watch the chain lift back into rows — Tools → Lift
# Report explains the boundary), plus the v0.6.0 staples: Spring + Tween juice, a
# runtime-toggleable group, Every X Seconds, Inspector attributes, Live Values.
# Run it: every 2s the icon pulses; press ui_accept (Enter) for a manual pulse,
# ui_cancel (Esc) to tween the rotation home.
@tool
extends SceneTree

func _init() -> void:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "ShowcaseV070"
	sheet.emit_live_values = true
	sheet.variables = {
		"pulses": {"type": "int", "default": 0, "exported": true,
			"attributes": {"tooltip": "How many juice pulses have fired (watch it in Live Values — and edit it!).", "range": {"min": "0", "max": "999", "step": "1"}}},
		"pulse_scale": {"type": "float", "default": 1.35, "exported": true,
			"attributes": {"tooltip": "How hard the spring kicks.", "range": {"min": "1", "max": "3", "step": "0.05"}, "clamp": true}}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "[b]v0.7.0 showcase[/b] — the runtime-toggleable [i]Juice[/i] group pulses the host every 2s (Spring + Tween). Press [b]ui_accept[/b] for a manual pulse, [b]ui_cancel[/b] to tween home — an if/elif chain authored as Else rows. Open showcase_v070.gd as a sheet and run Tools → Lift Report: every block explains what lifted and why the rest stayed code."
	sheet.events.append(about)

	var juice: EventGroup = EventGroup.new()
	juice.group_name = "Juice"
	juice.runtime_toggleable = true
	juice.custom_color = Color(0.55, 0.4, 0.85, 1.0)
	var pulse: EventRow = EventRow.new()
	pulse.trigger_provider_id = "Core"
	pulse.trigger_id = "OnProcess"
	var every: ACECondition = ACECondition.new()
	every.provider_id = "Core"
	every.ace_id = "EveryXSeconds"
	every.member_declaration = "var __every_5c0wca5e: float = 0.0"
	every.codegen_template = "__every_5c0wca5e >= maxf(2.0, 0.001)"
	every.codegen_prelude = "__every_5c0wca5e += delta"
	every.codegen_on_true = "__every_5c0wca5e = fmod(__every_5c0wca5e, maxf(2.0, 0.001))"
	every.params = {"seconds": "2.0"}
	pulse.conditions.append(every)
	var count_pulse: RawCodeRow = RawCodeRow.new()
	count_pulse.code = "pulses += 1\n$SpringBehavior.set_spring(\"__scale\", 1.0)\n$SpringBehavior.spring_host_scale(1.0)\n$SpringBehavior.add_impulse(\"__scale\", pulse_scale * 4.0)\n$TweenBehavior.tween_rotation(rotation_degrees + 90.0, 0.6)"
	pulse.actions.append(count_pulse)
	juice.events.append(pulse)
	sheet.events.append(juice)

	# The v0.7.0 headliner: an if/elif chain (else_mode) the reverse-lift round-trips.
	var manual_pulse: EventRow = EventRow.new()
	manual_pulse.trigger_provider_id = "Core"
	manual_pulse.trigger_id = "OnProcess"
	var accept_pressed: ACECondition = ACECondition.new()
	accept_pressed.provider_id = "Core"
	accept_pressed.ace_id = "IsActionJustPressed"
	accept_pressed.codegen_template = "Input.is_action_just_pressed(&{action})"
	accept_pressed.params = {"action": "\"ui_accept\""}
	manual_pulse.conditions.append(accept_pressed)
	var manual_raw: RawCodeRow = RawCodeRow.new()
	manual_raw.code = "pulses += 1\n$SpringBehavior.add_impulse(\"__scale\", pulse_scale * 4.0)"
	manual_pulse.actions.append(manual_raw)
	sheet.events.append(manual_pulse)
	var tween_home: EventRow = EventRow.new()
	tween_home.trigger_provider_id = "Core"
	tween_home.trigger_id = "OnProcess"
	tween_home.else_mode = EventRow.ElseMode.ELSE
	var cancel_pressed: ACECondition = ACECondition.new()
	cancel_pressed.provider_id = "Core"
	cancel_pressed.ace_id = "IsActionJustPressed"
	cancel_pressed.codegen_template = "Input.is_action_just_pressed(&{action})"
	cancel_pressed.params = {"action": "\"ui_cancel\""}
	tween_home.conditions.append(cancel_pressed)
	var home_raw: RawCodeRow = RawCodeRow.new()
	home_raw.code = "$TweenBehavior.tween_rotation(0.0, 0.4)"
	tween_home.actions.append(home_raw)
	sheet.events.append(tween_home)

	DirAccess.make_dir_recursive_absolute("res://demo/showcase")
	var sheet_error: Error = ResourceSaver.save(sheet, "res://demo/showcase/showcase_v070.tres")
	var saved: EventSheetResource = load("res://demo/showcase/showcase_v070.tres")
	saved.take_over_path("res://demo/showcase/showcase_v070.tres")
	var compile_result: Dictionary = SheetCompiler.compile(saved, "res://demo/showcase/showcase_v070.gd")
	print("[build_showcase] sheet save=%d compile=%s warnings=%s" % [sheet_error, str(compile_result.get("success")), str(compile_result.get("warnings"))])

	var host: Node2D = Node2D.new()
	host.name = "Showcase"
	host.set_script(load("res://demo/showcase/showcase_v070.gd"))
	var icon: Sprite2D = Sprite2D.new()
	icon.name = "Icon"
	icon.texture = load("res://icon.svg") if ResourceLoader.exists("res://icon.svg") else null
	host.add_child(icon)
	icon.owner = host
	var spring: Node = (load("res://eventsheet_addons/spring/spring_behavior.gd") as GDScript).new()
	spring.name = "SpringBehavior"
	host.add_child(spring)
	spring.owner = host
	var tween: Node = (load("res://eventsheet_addons/tween/tween_behavior.gd") as GDScript).new()
	tween.name = "TweenBehavior"
	host.add_child(tween)
	tween.owner = host
	var packed: PackedScene = PackedScene.new()
	packed.pack(host)
	var scene_error: Error = ResourceSaver.save(packed, "res://demo/showcase/showcase_v070.tscn")
	print("[build_showcase] scene save=%d" % scene_error)
	quit()
