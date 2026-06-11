# Release showcase builder (the release ritual, CONTRIBUTING §Release ritual):
# regenerates demo/showcase/ — a tiny playable scene exercising the release's headline
# features. v0.6.0: Spring + Tween juice, a runtime-toggleable group, Every X Seconds,
# Inspector attributes, and Live Values streaming (run it with the debugger attached
# and watch — then EDIT — `pulses` live).
@tool
extends SceneTree

func _init() -> void:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "ShowcaseV060"
	sheet.emit_live_values = true
	sheet.variables = {
		"pulses": {"type": "int", "default": 0, "exported": true,
			"attributes": {"tooltip": "How many juice pulses have fired (watch it in Live Values — and edit it!).", "range": {"min": "0", "max": "999", "step": "1"}}},
		"pulse_scale": {"type": "float", "default": 1.35, "exported": true,
			"attributes": {"tooltip": "How hard the spring kicks.", "range": {"min": "1", "max": "3", "step": "0.05"}, "clamp": true}}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "[b]v0.6.0 showcase[/b] — a runtime-toggleable [i]Juice[/i] group pulses the host every 2s through the Spring behavior while Tween spins it. Run with Live Values on: watch [b]pulses[/b] climb, double-click to rewrite it live, and flip the group off with Set Group Active."
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

	DirAccess.make_dir_recursive_absolute("res://demo/showcase")
	var sheet_error: Error = ResourceSaver.save(sheet, "res://demo/showcase/showcase_v060.tres")
	var saved: EventSheetResource = load("res://demo/showcase/showcase_v060.tres")
	saved.take_over_path("res://demo/showcase/showcase_v060.tres")
	var compile_result: Dictionary = SheetCompiler.compile(saved, "res://demo/showcase/showcase_v060.gd")
	print("[build_showcase] sheet save=%d compile=%s warnings=%s" % [sheet_error, str(compile_result.get("success")), str(compile_result.get("warnings"))])

	var host: Node2D = Node2D.new()
	host.name = "Showcase"
	host.set_script(load("res://demo/showcase/showcase_v060.gd"))
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
	var scene_error: Error = ResourceSaver.save(packed, "res://demo/showcase/showcase_v060.tscn")
	print("[build_showcase] scene save=%d" % scene_error)
	quit()
