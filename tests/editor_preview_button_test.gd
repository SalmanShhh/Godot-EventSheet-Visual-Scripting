# Godot EventSheets - a behaviour that can be watched in the editor, and the promise behind it.
#
# A builder that declares `previews` gets `@tool`, a Preview button and one guarded line at the top
# of each per-frame callback; every other behaviour stays a plain script with no `@tool`. The
# scene-safety half (the host's stored properties written down when Preview starts and put back on
# Stop, on leaving the tree and before every save) is exercised here on the emitted helpers a pack
# carries: a test run is not an editor, so the editor-gated entry points are pinned as text and the
# put-back machinery is driven directly on a real node.
@tool
class_name EditorPreviewButtonTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NAME: String = "editor_preview_button_test"
## Every pack that carries a Preview button, by the folder it ships in.
const PREVIEWING: PackedStringArray = [
	"fade", "flash", "follow_path", "hit_flash", "juice", "juice_3d", "light_flicker", "light_pulse",
	"move_to", "move_to_3d", "orbit", "orbit_3d", "rotate", "sine", "sine_3d", "spring", "tween", "wave",
]


static func run() -> bool:
	var passed: bool = true
	passed = _emitted_lines() and passed
	passed = _only_declared_packs_are_tools() and passed
	passed = _shipped_sine() and passed
	passed = _put_back_machinery() and passed
	passed = _scene_dock_shortcut() and passed
	passed = _shared_material_is_never_written() and passed
	passed = _retired_sampler_door() and passed
	return passed


## A tiny behaviour sheet with a frame callback and a physics callback.
static func _sheet(previews: bool, begin_code: String, nudge_code: String, repeat_seconds: String) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "ProbeBehavior"
	sheet.previews = previews
	sheet.preview_begin_code = begin_code
	sheet.preview_nudge_code = nudge_code
	sheet.preview_repeat_seconds = repeat_seconds
	for trigger_id: String in ["OnProcess", "OnPhysicsProcess"]:
		var tick: EventRow = EventRow.new()
		tick.trigger_provider_id = "Core"
		tick.trigger_id = trigger_id
		var body: RawCodeRow = RawCodeRow.new()
		body.code = "host.position.x += 1.0"
		tick.actions.append(body)
		sheet.events.append(tick)
	return sheet


static func _emitted_lines() -> bool:
	var plain: String = SUPPORT.compile_output(_sheet(false, "", "", ""))
	var previewing: String = SUPPORT.compile_output(_sheet(true, "wiggle()", "", ""))
	var nudging: String = SUPPORT.compile_output(_sheet(true, "wiggle()", "poke(2.0)", "1.5"))
	var guard_line: String = "\tif Engine.is_editor_hint() and not _previewing:\n\t\treturn\n"
	return SUPPORT.pins(NAME, [
		["a plain behaviour has no @tool", plain.contains("@tool"), false],
		["a plain behaviour has no preview members", plain.contains("_preview"), false],
		["a plain behaviour has no guard", plain.contains("_previewing"), false],
		["a previewing behaviour is @tool", previewing.contains("\n@tool\n"), true],
		["@tool comes before class_name", previewing.find("@tool") < previewing.find("class_name"), true],
		["@tool sits below the ace header lines", previewing.begins_with("@tool"), false],
		["the Preview button line", previewing.contains("@export_tool_button(\"Preview\", \"Play\") var _preview_start_button: Callable = _preview_start\n"), true],
		["the Stop preview button line", previewing.contains("@export_tool_button(\"Stop preview\", \"Stop\") var _preview_stop_button: Callable = _preview_stop\n"), true],
		["the buttons are hidden from the picker", previewing.count("## @ace_hidden\n## Plays in the editor. Your scene is not changed.\n@export_tool_button("), 2],
		["no Nudge button without nudge code", previewing.contains("_preview_nudge"), false],
		["the frame callback is guarded first", previewing.contains("func _process(_delta: float) -> void:\n" + guard_line), true],
		["the physics callback is guarded first", previewing.contains("func _physics_process(_delta: float) -> void:\n" + guard_line), true],
		["exactly the two callbacks are guarded", previewing.count("if Engine.is_editor_hint() and not _previewing:"), 2],
		["the kick runs the declared code", previewing.contains("func _preview_kick() -> void:\n\twiggle()\n"), true],
		["no repeat loop without a repeat", previewing.contains("_preview_repeat"), false],
		["the Nudge button line", nudging.contains("@export_tool_button(\"Nudge\", \"ToolMove\") var _preview_nudge_button: Callable = _preview_nudge\n"), true],
		["Nudge presses Preview first, then runs its code", nudging.contains("func _preview_nudge() -> void:\n\t_preview_start()\n\tif not _previewing:\n\t\treturn\n\tpoke(2.0)\n"), true],
		["the repeat loop waits the declared expression", nudging.contains("create_timer(maxf(1.5, 0.1)).timeout"), true],
		["a repeat loop stops when the preview does", nudging.contains("if not _previewing or run != _preview_run:\n\t\t\treturn\n"), true],
		["a save puts the host back", previewing.contains("elif what == NOTIFICATION_EDITOR_PRE_SAVE:\n\t\t_preview_put_back(host, _preview_rest_of(host))\n"), true],
		["leaving the tree stops the preview", previewing.contains("if what == NOTIFICATION_EXIT_TREE:\n\t\t_preview_stop()\n"), true],
		["nothing starts outside the editor", previewing.contains("func _preview_start() -> void:\n\tif not Engine.is_editor_hint() or _previewing or host == null or not is_inside_tree():\n\t\treturn\n"), true],
		["running tweens are killed on stop", previewing.contains("\t_previewing = false\n\t_preview_kill_tweens()\n"), true],
		["the rest values live in an Engine meta table", previewing.contains("Engine.set_meta(\"_eventsheets_previews\", {})"), true],
		["a previewing behaviour is not a sheet-wide tool sheet", _sheet(true, "", "", "").tool_mode, false],
	])


## The previewing packs are exactly the declared ones: a behaviour not on the list is `@tool`-free.
static func _only_declared_packs_are_tools() -> bool:
	var passed: bool = true
	var folders: PackedStringArray = DirAccess.get_directories_at("res://eventsheet_addons")
	var seen_previewing: int = 0
	for folder: String in folders:
		for file_name: String in DirAccess.get_files_at("res://eventsheet_addons/%s" % folder):
			if not file_name.ends_with("_behavior.gd"):
				continue
			var source: String = FileAccess.get_file_as_string("res://eventsheet_addons/%s/%s" % [folder, file_name])
			var is_tool: bool = source.contains("\n@tool\n")
			var declared: bool = PREVIEWING.has(folder)
			if declared:
				seen_previewing += 1
			passed = SUPPORT.pin_value(NAME, "%s is @tool only if it previews" % folder, is_tool, declared) and passed
			passed = SUPPORT.pin_value(NAME, "%s carries the Preview button only if it previews" % folder,
				source.contains("_preview_start_button"), declared) and passed
	return SUPPORT.pin_value(NAME, "every previewing pack was found", seen_previewing, PREVIEWING.size()) and passed


static func _shipped_sine() -> bool:
	var source: String = FileAccess.get_file_as_string("res://eventsheet_addons/sine/sine_behavior.gd")
	var spring: String = FileAccess.get_file_as_string("res://eventsheet_addons/spring/spring_behavior.gd")
	var juice: String = FileAccess.get_file_as_string("res://eventsheet_addons/juice/juice_behavior.gd")
	var rotate: String = FileAccess.get_file_as_string("res://eventsheet_addons/rotate/rotate_behavior.gd")
	return SUPPORT.pins(NAME, [
		["Sine keeps its header lines first and carries @tool under them", source.begins_with("## @ace_category(\"Sine\")\n## @ace_expose_all(node)\n## @ace_version(1.0.0)\n@tool\n@icon("), true],
		["Sine's per-frame callback is guarded", source.contains("func _process(delta: float) -> void:\n\tif Engine.is_editor_hint() and not _previewing:\n\t\treturn\n\tif not active or host == null:"), true],
		["Sine has no Nudge", source.contains("_preview_nudge"), false],
		["Spring has a Nudge that sets the host scale spring going", spring.contains("func _preview_nudge() -> void:\n\t_preview_start()\n\tif not _previewing:\n\t\treturn\n\tspring_host_scale(host.scale.x)\n\tadd_impulse(\"__scale\", 6.0)\n"), true],
		["Juice has a Nudge that punches the host", juice.contains("\tpunch_scale(0.4, 0.6)\n"), true],
		["Rotate's physics callback is guarded", rotate.contains("func _physics_process(delta: float) -> void:\n\tif Engine.is_editor_hint() and not _previewing:\n\t\treturn\n"), true],
	])


## Capture and put back, driven on a real node: what a preview writes down is what the scene stores
## and nothing the pack's own variables need, a changed value is set back, an unchanged one is not
## touched, and the behaviour's own unsaved state is written down apart from its Inspector values.
static func _put_back_machinery() -> bool:
	var script: GDScript = load("res://eventsheet_addons/sine/sine_behavior.gd") as GDScript
	var host: Node2D = Node2D.new()
	host.position = Vector2(320, 180)
	host.rotation = 0.5
	host.scale = Vector2(2, 3)
	host.modulate = Color(1, 0.5, 0.25, 1)
	var rest: Dictionary = script.call("_preview_values", host, false)
	host.position = Vector2(400, 90)
	host.rotation = 2.0
	host.scale = Vector2(5, 5)
	host.modulate.a = 0.1
	script.call("_preview_put_back", host, rest)
	var behaviour: Node = script.new() as Node
	behaviour.period = 3.0
	behaviour.time = 7.0
	behaviour.base_captured = true
	var own: Dictionary = script.call("_preview_values", behaviour, true)
	behaviour.period = 9.0
	behaviour.time = 11.0
	behaviour.base_captured = false
	script.call("_preview_put_back", behaviour, own)
	var passed: bool = SUPPORT.pins(NAME, [
		["position is put back", host.position, Vector2(320, 180)],
		["rotation is put back", host.rotation, 0.5],
		["scale is put back", host.scale, Vector2(2, 3)],
		["modulate is put back", host.modulate, Color(1, 0.5, 0.25, 1)],
		["the stored values include position", rest.has("position"), true],
		["the stored values leave the script out", rest.has("script"), false],
		["unsaved script state is written down", own.has("time"), true],
		["unsaved script state is put back", behaviour.time, 7.0],
		["the capture flag is put back", behaviour.base_captured, true],
		["an Inspector value is not part of the unsaved state", own.has("period"), false],
		["an Inspector value changed during a preview stays changed", behaviour.period, 9.0],
		["the host reference is not part of the state", own.has("host"), false],
		["the buttons are not part of the state", own.has("_preview_start_button"), false],
	])
	behaviour.free()
	host.free()
	return passed


## The Scene dock's right-click offers Preview/Stop for the behaviours under a node that carry the button,
## and only those.
static func _scene_dock_shortcut() -> bool:
	var host: Node2D = Node2D.new()
	var sine: Node = (load("res://eventsheet_addons/sine/sine_behavior.gd") as GDScript).new() as Node
	var spring: Node = (load("res://eventsheet_addons/spring/spring_behavior.gd") as GDScript).new() as Node
	var plain: Node = Node.new()
	var bullet_script: GDScript = load("res://eventsheet_addons/bullet/bullet_behavior.gd") as GDScript
	var bullet: Node = bullet_script.new() as Node
	for child: Node in [sine, plain, spring, bullet]:
		host.add_child(child)
	var found: Array[Node] = EventSheetContextMenu.previewing_behaviours_under(host)
	var passed: bool = SUPPORT.pins(NAME, [
		["the behaviours with a Preview button are found", found, [sine, spring]],
		["a node with none finds none", EventSheetContextMenu.previewing_behaviours_under(plain), []],
		["no node finds none", EventSheetContextMenu.previewing_behaviours_under(null), []],
	])
	host.free()
	return passed


## Two nodes wear ONE material. A preview on the first, with own_material off, must work on a copy: the
## second node's material (the very same resource) keeps every value, during the preview and after
## Stop puts the first node's original reference back.
static func _shared_material_is_never_written() -> bool:
	var passed: bool = true
	for folder: String in ["wave", "hit_flash"]:
		var shader: Shader = Shader.new()
		shader.code = "shader_type canvas_item;
uniform float strength = 0.25;
uniform float flash_amount = 0.25;
void fragment() {}
"
		var shared: ShaderMaterial = ShaderMaterial.new()
		shared.shader = shader
		shared.set_shader_parameter("strength", 0.25)
		shared.set_shader_parameter("flash_amount", 0.25)
		var first: Sprite2D = Sprite2D.new()
		var second: Sprite2D = Sprite2D.new()
		first.material = shared
		second.material = shared
		var behaviour: Node = (load("res://eventsheet_addons/%s/%s" % [folder, "wave_behavior.gd" if folder == "wave" else "hit_flash_behavior.gd"]) as GDScript).new() as Node
		first.add_child(behaviour)
		behaviour.set("host", first)
		behaviour.set("own_material", false)
		var before: Variant = shared.get_shader_parameter("strength" if folder == "wave" else "flash_amount")
		# The state the Preview button puts the pack in; the button itself needs an editor.
		behaviour.set("_previewing", true)
		var worn: ShaderMaterial = behaviour.call("_effect_material") as ShaderMaterial
		worn.set_shader_parameter("strength", 0.9)
		worn.set_shader_parameter("flash_amount", 0.9)
		var during: Variant = second.material.get_shader_parameter("strength" if folder == "wave" else "flash_amount")
		var shared_still_second: bool = second.material == shared
		# Stop: the pack's own put-back of the host's stored properties and its own unsaved state.
		var script: GDScript = behaviour.get_script() as GDScript
		var rest: Dictionary = {"material": shared}
		script.call("_preview_put_back", first, rest)
		behaviour.set("_previewing", false)
		passed = SUPPORT.pins(NAME, [
			["%s: the preview works on a copy, not the shared material" % folder, worn != shared, true],
			["%s: the other node's material value is unchanged during the preview" % folder, during, before],
			["%s: the other node still wears the shared material" % folder, shared_still_second, true],
			["%s: the shared material's values are unchanged" % folder, [shared.get_shader_parameter("strength"), shared.get_shader_parameter("flash_amount")], [0.25, 0.25]],
			["%s: Stop puts the original material back on the first node" % folder, first.material == shared, true],
		]) and passed
		passed = SUPPORT.pin_value(NAME, "%s: the other node's value is unchanged after Stop" % folder,
			second.material.get_shader_parameter("strength" if folder == "wave" else "flash_amount"), before) and passed
		first.free()
		second.free()
	return passed


## The older sampler and the Tools-menu preview are gone; the public calls stay callable and do nothing.
static func _retired_sampler_door() -> bool:
	var invoked: Array = []
	EventSheets.register_editor_preview("res://eventsheet_addons/sine/sine_behavior.gd", func(_p: Dictionary, _b: Dictionary, _t: float) -> Dictionary:
		invoked.append(true)
		return {})
	var sine: String = FileAccess.get_file_as_string("res://eventsheet_addons/sine/sine_behavior.gd")
	var rotate: String = FileAccess.get_file_as_string("res://eventsheet_addons/rotate/rotate_behavior.gd")
	var menu: String = FileAccess.get_file_as_string("res://addons/eventsheet/editor/dock/menu_bar.gd")
	return SUPPORT.pins(NAME, [
		["a registered sampler is accepted and never resolved", EventSheets.editor_preview_sampler_for("res://eventsheet_addons/sine/sine_behavior.gd").is_valid(), false],
		["a registered sampler is never called", invoked.size(), 0],
		["the old toggle returns false", EventSheets.preview_behaviors(), false],
		["Sine carries no sampler function", sine.contains("editor_preview_sample"), false],
		["Rotate carries no sampler function", rotate.contains("editor_preview_sample"), false],
		["the Tools menu has no Preview Behaviors item", menu.contains("Preview Behaviors on Selected Node"), false],
		["the sampler service file is gone", FileAccess.file_exists("res://addons/eventsheet/editor/behavior_preview.gd"), false],
	])
