# Godot EventSheets - learning Godot from a juice card (editor-only, UI-light).
#
# A card is a shortcut, not a wall. This file is what lets a card teach what it stands for:
#
#   - the Godot name of what a field sets ("Light2D.energy"), written in small print under the field, with
#     a "?" that opens Godot's own help page for it;
#   - "Show as rows": the card as the line that adds it from an event sheet;
#   - "Show as GDScript": the same effect written by hand in plain GDScript, with no plugin in it.
#
# The GDScript is the PLAIN version, and says so: the card also handles its strength, the accessibility
# setting, its timing and the way back that Stop and Restore use, none of which a pasted copy has. Every
# snippet is written to be pasted into the script of the object the Juice Player is under, so the object
# itself is `self` and a node the card points at is written the way that script would reach it.
#
# Loaded by path from the card list, so the first open of the editor does not compile it.
@tool
extends RefCounted

## What the window and the clipboard say next to the code: it is the same effect, written by hand.
const AS_GDSCRIPT_NOTE: String = "This is the same effect written by hand, in plain GDScript, with no plugin in it. The card also handles its strength, the accessibility setting, its timing and the way back that Stop and Restore use; this version does not."

## The note under the card as a row.
const AS_ROW_NOTE: String = "This is the line that adds this card from an event sheet or from code. Run it on a Juice Player."

## The Godot member each field of each card sets, by the card's word and the field's key. "Class.member" always
## names the class that DECLARES the member, so the help page it opens is the one Godot has for it.
const GODOT_NAMES: Dictionary = {
	"shake": {"amount": "Camera2D.offset"},
	"hitstop": {"amount": "Engine.time_scale"},
	"slowmo": {"amount": "Engine.time_scale"},
	"punch": {"amount": "Node2D.scale"},
	"zoom": {"amount": "Camera2D.zoom"},
	"sound": {"stream": "AudioStreamPlayer.stream", "volume_db": "AudioStreamPlayer.volume_db", "pitch": "AudioStreamPlayer.pitch_scale",
		"bus": "AudioStreamPlayer.bus"},
	"fade_bus": {"amount": "AudioServer.set_bus_volume_db"},
	"vibrate": {"weak": "Input.start_joy_vibration"},
	"tween_property": {"to": "Tween.tween_property"},
	"emit_signal": {"signal": "Object.emit_signal"},
	"particles": {"do": "GPUParticles2D.emitting"},
	"spawn_scene": {"scene": "PackedScene.instantiate"},
	"animation": {"animation": "AnimationPlayer.play"},
	"sprite_animation": {"animation": "AnimatedSprite2D.play"},
	"show_hide": {"do": "CanvasItem.visible"},
	"squash_stretch": {"amount": "Node2D.scale"},
	"punch_position": {"x": "Node2D.position"},
	"punch_rotation": {"amount": "Node2D.rotation"},
	"shader_value": {"parameter": "ShaderMaterial.set_shader_parameter"},
	"push": {"speed": "RigidBody2D.apply_central_impulse"},
	"force_for_a_time": {"x": "RigidBody2D.apply_central_force"},
	"gravity_for_a_time": {"amount": "RigidBody2D.gravity_scale"},
	"freeze_body": {"body": "RigidBody2D.freeze"},
	"pop": {"amount": "Node2D.scale"},
	"fade": {"amount": "CanvasItem.modulate"},
	"grab_focus": {"node": "Control.grab_focus"},
	"count_to": {"to": "Label.text"},
	"reveal_text": {"speed": "Label.visible_ratio"},
	"fill_bar": {"to": "Range.value"},
	"call_method": {"method": "Object.call"},
	"collision_for": {"node": "CollisionShape2D.disabled"},
	"collision_layer_for": {"part": "CollisionObject2D.collision_mask", "layer": "CollisionObject2D.set_collision_mask_value"},
	"remove_node": {"node": "Node.queue_free"},
	"draw_order": {"z_index": "CanvasItem.z_index"},
	"switch_node": {"visible": "CanvasItem.visible", "process": "Node.process_mode", "collision": "CollisionShape2D.disabled"},
	"look_at": {"target": "Node2D.look_at"},
	"rotate_by": {"degrees": "Node2D.rotation"},
	"rotate_to": {"degrees": "Node2D.rotation"},
	"rotation_shake": {"degrees": "Node2D.rotation"},
	"light": {"energy_from": "Light2D.energy", "energy_to": "Light2D.energy", "colour_from": "Light2D.color", "colour_to": "Light2D.color"},
	"scene_look": {"node": "WorldEnvironment.environment"},
	"bus_effect": {"bus": "AudioServer.get_bus_index"},
	"slow_object": {"speed": "AnimationPlayer.speed_scale"},
	"animation_parameter": {"parameter": "Object.set"}
}


## Writes the Godot name onto every field that has one. Called once, on the kinds the schema has built.
static func name_fields(kinds: Array) -> void:
	for kind: Variant in kinds:
		var named: Dictionary = GODOT_NAMES.get(str((kind as Dictionary).get("kind", "")), {})
		if named.is_empty():
			continue
		for field: Variant in (kind as Dictionary).get("fields", []):
			var key: String = str((field as Dictionary).get("key", ""))
			if named.has(key):
				(field as Dictionary)["godot"] = named[key]


## The small print under a field: its Godot name, and a "?" that opens Godot's own help page for it. Null for a
## field with no Godot name.
static func small_print(field: Dictionary, label_width: float, open_help: Callable) -> Control:
	var godot: String = str(field.get("godot", ""))
	if godot.is_empty():
		return null
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override("separation", 4)
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(label_width + 5.0, 0.0)
	line.add_child(gap)
	var name_label: Label = Label.new()
	name_label.text = godot
	# The size and the fade of the card's own description, so it reads as comfortably in both themes.
	name_label.add_theme_font_size_override("font_size", EventSheetPalette.scaled(10))
	name_label.modulate = Color(1.0, 1.0, 1.0, 0.6)
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	name_label.tooltip_text = EventSheetL10n.translate("Godot's name for this. The ? opens its page in Godot's help.")
	var mono: Font = EventSheetPopupUI.editor_font("doc_source")
	if mono != null:
		name_label.add_theme_font_override("font", mono)
	line.add_child(name_label)
	var help: Button = Button.new()
	help.text = "?"
	help.flat = true
	help.focus_mode = Control.FOCUS_NONE
	help.add_theme_font_size_override("font_size", EventSheetPalette.scaled(10))
	help.modulate = Color(1.0, 1.0, 1.0, 0.6)
	help.tooltip_text = EventSheetL10n.translate("Open this in Godot's help.")
	help.pressed.connect(func() -> void: open_help.call(godot))
	line.add_child(help)
	return line


## The topic Godot's help window opens for "Class.member": a property, a method, or the class itself.
static func help_topic(godot: String) -> String:
	var owner_class: String = godot.get_slice(".", 0)
	var member: String = godot.get_slice(".", 1)
	if member.is_empty():
		return "class_name:" + owner_class
	for entry: Dictionary in ClassDB.class_get_property_list(owner_class, true):
		if str(entry.get("name", "")) == member:
			return "class_property:%s:%s" % [owner_class, member]
	return "class_method:%s:%s" % [owner_class, member]


## Opens Godot's own help page for "Class.member". Nothing happens outside the editor.
static func open_help(godot: String) -> void:
	if godot.is_empty() or not ClassDB.class_exists("EditorInterface"):
		return
	var script_editor: Object = EditorInterface.get_script_editor()
	if script_editor != null:
		script_editor.call("goto_help", help_topic(godot))


## The first Godot name a kind of card has, which is the page its "Open in Godot help" entry opens.
static func first_name(entry: Dictionary) -> String:
	for field: Variant in entry.get("fields", []):
		var godot: String = str((field as Dictionary).get("godot", ""))
		if not godot.is_empty():
			return godot
	return ""


## The card as the line that adds it: what the Add Juice Card row writes.
static func as_row(card: Dictionary, player: String = "$JuicePlayer") -> String:
	var field: Script = load("res://addons/eventsheet/editor/inspector/feedback_step_field.gd") as Script
	return "%s.add_feedback(%s, \"\")" % [player, field.call("step_literal", card)]


## Opens a small window with a piece of text a person can read and copy, a note on what it is, and puts the text on
## the clipboard too, so "Show" and "Copy" are one gesture.
static func show_text(host: Node, title: String, note: String, text: String) -> Window:
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		DisplayServer.clipboard_set(text)
	# The window's own title bar says what it is, so nothing inside repeats it as a heading.
	var window: Window = Window.new()
	window.title = title
	window.size = Vector2i(620, 280)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card: Control = EventSheetPopupUI.panel_section(box)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	window.add_child(EventSheetPopupUI.window_body(card))
	host.add_child(window)
	box.add_child(EventSheetPopupUI.hint_label(EventSheetL10n.translate(note), 560.0))
	box.add_child(EventSheetPopupUI.code_card(text, 540.0))
	window.close_requested.connect(window.queue_free)
	EventSheetPopupUI.popup_fitted(window, Vector2i(620, 0))
	return window


## What a number is written as in a snippet: a float keeps one place, and no more than four are written.
static func _n(value: Variant) -> String:
	var spelled: String = String.num(str(value).to_float() if value is String else float(value), 4)
	if spelled.contains("."):
		spelled = spelled.rstrip("0")
		if spelled.ends_with("."):
			spelled += "0"
	else:
		spelled += ".0"
	return spelled


## A colour as GDScript writes it.
static func _colour(value: Variant) -> String:
	var shown: Color = value as Color if value is Color else Color(str(value))
	return "Color(%s, %s, %s, %s)" % [_n(shown.r), _n(shown.g), _n(shown.b), _n(shown.a)]


## A value of the kind a spring or a parameter holds, as GDScript writes it.
static func _value(value: Variant) -> String:
	if value is Vector2:
		return "Vector2(%s, %s)" % [_n((value as Vector2).x), _n((value as Vector2).y)]
	if value is Vector3:
		return "Vector3(%s, %s, %s)" % [_n((value as Vector3).x), _n((value as Vector3).y), _n((value as Vector3).z)]
	if value is Color:
		return _colour(value)
	if value is bool:
		return "true" if value else "false"
	return _n(value)


## The code that reaches the node a card points at, as the script the player's object wears would write it: `self`
## for the object itself, `$Name` for a node under it. `player` is the Juice Player being edited, when there is one.
static func _node(card: Dictionary, key: String, player: Node) -> String:
	var stored: Variant = card.get(key, NodePath())
	var path: NodePath = stored if stored is NodePath else NodePath(str(stored))
	if path.is_empty():
		return "self"
	var reached: String = str(path)
	if player != null and player.get_parent() != null:
		var picked: Node = player.get_node_or_null(path)
		if picked != null:
			reached = str(player.get_parent().get_path_to(picked))
	return _written(reached)


## How GDScript writes a path to a node: `self` for the object itself, `$Name` for a name that needs no quotes.
static func _written(reached: String) -> String:
	if reached == "." or reached.is_empty():
		return "self"
	var simple: bool = true
	for index: int in range(reached.length()):
		var letter: String = reached.substr(index, 1)
		var digit: bool = letter >= "0" and letter <= "9"
		if not (letter == "_" or (letter >= "a" and letter <= "z") or (letter >= "A" and letter <= "Z") or (index > 0 and (digit or letter == "/"))):
			simple = false
	return "$%s" % reached if simple else "$\"%s\"" % reached


## The code that reaches a node that really exists in the scene, from the object the player is under. Empty when the
## player is not in a scene or the node is not under that object, so the caller keeps the plain name it always wrote.
static func _reaching(player: Node, found: Node) -> String:
	if player == null or found == null or player.get_parent() == null:
		return ""
	var host: Node = player.get_parent()
	if found != host and not host.is_ancestor_of(found):
		return ""
	return _written(str(host.get_path_to(found)))


## The node a card's key names, or null when it names none or there is no player to look from.
static func _picked(card: Dictionary, key: String, player: Node) -> Node:
	var stored: Variant = card.get(key, NodePath())
	var path: NodePath = stored if stored is NodePath else NodePath(str(stored))
	if player == null or path.is_empty():
		return null
	return player.get_node_or_null(path)


## The Spring node a Spring card moves its value with, written as the object's script would reach it.
static func _spring_name(card: Dictionary, player: Node) -> String:
	if player == null or player.get_parent() == null:
		return "$SpringBehavior"
	var target: Node = _picked(card, "node", player)
	if target == null:
		target = player.get_parent()
	var pack: GDScript = load(str(load("res://addons/eventsheet/editor/inspector/juice_player_names.gd").call("pack_path"))) as GDScript
	var spring: Node = pack.call("spring_of", target) as Node if pack != null else null
	var reached: String = _reaching(player, spring)
	return reached if not reached.is_empty() else "$SpringBehavior"


## The other Juice Player a card names, or the plain stand-in name when there is no scene to read it from. A card that
## names none acts on this player when `own` says so.
static func _player_name(card: Dictionary, player: Node, own: bool) -> String:
	var named: Node = _picked(card, "player", player)
	if named == null and own and player != null:
		named = player
	var reached: String = _reaching(player, named)
	return reached if not reached.is_empty() else "$OtherPlayer"


## The WorldEnvironment a Scene Look card changes: the one it names, else the first the player's scene has.
static func _world_name(card: Dictionary, player: Node) -> String:
	var named: String = _node(card, "node", player)
	if named != "self":
		return named
	if player != null and player.get_parent() != null:
		var root: Node = player.owner if player.owner != null else player.get_parent()
		var found: Array[Node] = root.find_children("*", "WorldEnvironment", true, false)
		var reached: String = _reaching(player, found[0] if not found.is_empty() else null)
		if not reached.is_empty():
			return reached
	return "$WorldEnvironment"


## The same effect as a card, written by hand in plain GDScript, or an empty text for a card that has no short
## plain version (the screen effects draw over the whole screen with a shader, and the list words move the head of
## a list that a pasted line has no list for). Snippets are written to run inside a function.
static func as_gdscript(card: Dictionary, player: Node = null) -> String:
	var word: String = str(card.get("verb", "")).strip_edges().to_lower()
	var seconds: String = _n(card.get("seconds", 0.2))
	var amount: String = _value(card.get("amount", 1.0))
	var target: String = _node(card, "node", player)
	match word:
		"shake":
			# The camera goes back to the offset it had. A card of 0 seconds (a trauma shake the camera
			# fades out itself) writes the one kick instead of a loop that never runs.
			if float(card.get("seconds", 0.2)) <= 0.0:
				return "var camera := get_viewport().get_camera_2d()\nvar rest := camera.offset\ncamera.offset = rest + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * %s * 40.0\nawait get_tree().process_frame\ncamera.offset = rest" % amount
			return "var camera := get_viewport().get_camera_2d()\nvar rest := camera.offset\nvar elapsed := 0.0\nwhile elapsed < %s:\n\tvar left := 1.0 - elapsed / %s\n\tcamera.offset = rest + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * %s * 40.0 * left\n\tawait get_tree().process_frame\n\telapsed += get_process_delta_time()\ncamera.offset = rest" % [seconds, seconds, amount]
		"hitstop":
			return "var before := Engine.time_scale\nEngine.time_scale = %s\nawait get_tree().create_timer(%s, true, false, true).timeout\nEngine.time_scale = before" % [_n(card.get("amount", 0.0)), seconds]
		"slowmo":
			return "var before := Engine.time_scale\nEngine.time_scale = %s\nawait get_tree().create_timer(%s, true, false, true).timeout\nEngine.time_scale = before" % [amount, seconds]
		"pause":
			return "await get_tree().create_timer(%s).timeout" % seconds
		"flash":
			return "var rest := modulate\nmodulate = Color.WHITE\ncreate_tween().tween_property(self, \"modulate\", rest, %s)" % seconds
		"punch":
			return "var rest := scale\nvar tween := create_tween()\ntween.tween_property(self, \"scale\", rest * %s, %s).set_trans(Tween.TRANS_SINE)\ntween.tween_property(self, \"scale\", rest, %s)" % [_n(1.0 + float(card.get("amount", 0.3))), _n(float(card.get("seconds", 0.2)) * 0.5), _n(float(card.get("seconds", 0.2)) * 0.5)]
		"zoom":
			return "var camera := get_viewport().get_camera_2d()\ncreate_tween().tween_property(camera, \"zoom\", camera.zoom * %s, %s)" % [_n(float(card.get("amount", 110.0)) / 100.0), seconds]
		"sound":
			return "var player := AudioStreamPlayer.new()\nplayer.stream = load(\"%s\")\nplayer.volume_db = %s\nplayer.pitch_scale = %s\nplayer.bus = \"%s\"\nadd_child(player)\nplayer.play()\nplayer.finished.connect(player.queue_free)" % [str(card.get("stream", "res://your_sound.ogg")), _n(card.get("volume_db", 0.0)), _n(card.get("pitch", 1.0)), str(card.get("bus", "Master"))]
		"fade_bus":
			return "var bus := AudioServer.get_bus_index(\"%s\")\nvar volume := Callable(AudioServer, \"set_bus_volume_db\").bind(bus)\ncreate_tween().tween_method(volume, AudioServer.get_bus_volume_db(bus), %s, %s)" % [str(card.get("effect", "Master")), _n(card.get("amount", -80.0)), seconds]
		"vibrate":
			return "Input.start_joy_vibration(0, %s, %s, %s)" % [_n(card.get("weak", 0.5)), _n(card.get("strong", 0.5)), seconds]
		"pause_player":
			var who: String = _player_name(card, player, true)
			match str(card.get("mode", "pause")):
				"resume":
					return "# Resumes another Juice Player where it held.\n%s.resume_feedbacks()" % who
				"toggle":
					return "# Pauses another Juice Player, or resumes it if it was paused.\n%s.toggle_juice_paused()" % who
			return "# Pauses another Juice Player: its walk holds still until it is resumed.\n%s.pause_feedbacks()" % who
		"tween_property":
			var property: String = str(card.get("effect", "rotation"))
			return "var tween := create_tween()\ntween.tween_property(%s, \"%s\", %s, %s)" % [target, property, _value(card.get("to", card.get("amount", 1.0))), seconds]
		"emit_signal":
			return "# Fires a signal your own script declares, for anything connected to it.\n%s.emit_signal(\"%s\")" % [target, str(card.get("signal", card.get("effect", "my_signal")))]
		"call_method":
			return "%s.call(\"%s\")" % [target, str(card.get("method", "my_method"))]
		"play_player":
			return "%s.play(%s)" % [_player_name(card, player, false), _n(card.get("amount", 1.0))]
		"particles":
			var declared: String = "var particles: GPUParticles2D = %s\n" % target
			if str(card.get("do", "restart")) == "restart":
				return declared + "particles.restart()\nparticles.emitting = true"
			return declared + "particles.emitting = %s" % ("true" if str(card.get("do", "")) == "start" else "false")
		"spawn_scene":
			return "var copy: Node2D = load(\"%s\").instantiate()\nget_tree().current_scene.add_child(copy)\ncopy.global_position = global_position" % str(card.get("scene", "res://your_scene.tscn"))
		"animation":
			return "var player: AnimationPlayer = %s\nplayer.play(\"%s\")" % [target, str(card.get("animation", "idle"))]
		"sprite_animation":
			return "var sprite: AnimatedSprite2D = %s\nsprite.play(\"%s\")" % [target, str(card.get("animation", "default"))]
		"show_hide":
			var item: String = "var node: CanvasItem = %s\n" % target
			match str(card.get("do", "flash")):
				"show":
					return item + "node.show()"
				"hide":
					return item + "node.hide()"
			return item + "node.show()\nawait get_tree().create_timer(%s).timeout\nnode.hide()" % seconds
		"squash_stretch":
			return "var rest := scale\nvar tween := create_tween()\ntween.tween_property(self, \"scale\", Vector2(rest.x * %s, rest.y / %s), %s)\ntween.tween_property(self, \"scale\", rest, %s)" % [_n(1.0 + float(card.get("amount", 0.3))), _n(1.0 + float(card.get("amount", 0.3))), _n(float(card.get("seconds", 0.2)) * 0.5), _n(float(card.get("seconds", 0.2)) * 0.5)]
		"punch_position":
			return "var rest := position\nposition += Vector2(%s, %s)\ncreate_tween().tween_property(self, \"position\", rest, %s).set_trans(Tween.TRANS_ELASTIC)" % [_n(card.get("x", 0.0)), _n(card.get("y", -10.0)), seconds]
		"punch_rotation":
			return "var rest := rotation\nrotation += deg_to_rad(%s)\ncreate_tween().tween_property(self, \"rotation\", rest, %s).set_trans(Tween.TRANS_ELASTIC)" % [_n(card.get("amount", 10.0)), seconds]
		"shader_value":
			return "var node: CanvasItem = %s\nvar material: ShaderMaterial = node.material\ncreate_tween().tween_method(material.set_shader_parameter.bind(\"%s\"), 0.0, %s, %s)" % [target, str(card.get("parameter", "amount")), _value(card.get("to", 1.0)), seconds]
		"push":
			return "var body: RigidBody2D = %s\nbody.apply_central_impulse(Vector2(%s, %s))" % [_node(card, "body", player), _n(card.get("x", 0.0) if str(card.get("direction", "fixed")) == "fixed" else 0.0), _n(float(card.get("y", -1.0)) * float(card.get("speed", 300.0)))]
		"force_for_a_time":
			return "var body: RigidBody2D = %s\nvar left := %s\nwhile left > 0.0:\n\tbody.apply_central_force(Vector2(%s, %s))\n\tawait get_tree().physics_frame\n\tleft -= get_physics_process_delta_time()" % [_node(card, "body", player), seconds, _n(card.get("x", 0.0)), _n(card.get("y", -400.0))]
		"gravity_for_a_time":
			return "var body: RigidBody2D = %s\nvar before := body.gravity_scale\nbody.gravity_scale = %s\nawait get_tree().create_timer(%s).timeout\nbody.gravity_scale = before" % [_node(card, "body", player), amount, seconds]
		"freeze_body":
			return "var body: RigidBody2D = %s\nbody.freeze = true\nawait get_tree().create_timer(%s).timeout\nbody.freeze = false" % [_node(card, "body", player), seconds]
		"pop":
			return "var rest := scale\nvar tween := create_tween()\ntween.tween_property(self, \"scale\", rest * %s, %s)\ntween.tween_property(self, \"scale\", rest, %s)" % [amount, _n(float(card.get("seconds", 0.15)) * 0.4), _n(float(card.get("seconds", 0.15)) * 0.6)]
		"fade":
			return "var node: CanvasItem = %s\ncreate_tween().tween_property(node, \"modulate:a\", %s, %s)" % [target, _n(card.get("amount", 0.0)), seconds]
		"grab_focus":
			return "var control: Control = %s\ncontrol.grab_focus()" % target
		"count_to":
			return "var label: Label = %s\nvar tween := create_tween()\ntween.tween_method(func(value: float) -> void: label.text = str(int(value)), float(label.text), %s, %s)" % [target, _n(card.get("to", 0)), seconds]
		"reveal_text":
			return "var label: Label = %s\nlabel.visible_ratio = 0.0\nvar seconds := label.text.length() / %s\ncreate_tween().tween_property(label, \"visible_ratio\", 1.0, seconds)" % [target, _n(card.get("speed", 40.0))]
		"fill_bar":
			return "var bar: Range = %s\ncreate_tween().tween_property(bar, \"value\", %s, %s)" % [target, _n(card.get("to", 0)), seconds]
		"collision_for":
			return "var shape: CollisionShape2D = %s\nshape.set_deferred(\"disabled\", true)\nawait get_tree().create_timer(%s).timeout\nshape.set_deferred(\"disabled\", false)" % [target, seconds]
		"collision_layer_for":
			var part: String = "collision_layer" if str(card.get("part", "mask")) == "layer" else "collision_mask"
			var setter: String = "set_%s_value" % part
			var layer: int = clampi(int(card.get("layer", 1)), 1, 32)
			var on: bool = bool(card.get("on", false))
			return "var body: CollisionObject2D = %s\nbody.call_deferred(\"%s\", %d, %s)\nawait get_tree().create_timer(%s).timeout\nbody.call_deferred(\"%s\", %d, %s)" % [target, setter, layer, "true" if on else "false", seconds, setter, layer, "false" if on else "true"]
		"remove_node":
			return "%s.queue_free()" % target
		"draw_order":
			var order: int = clampi(int(card.get("z_index", 10)), -4096, 4096)
			return "var node: CanvasItem = %s\nvar before := node.z_index\nnode.z_index = %d\nawait get_tree().create_timer(%s).timeout\nnode.z_index = before" % [target, order, seconds]
		"switch_node":
			var lines: PackedStringArray = PackedStringArray(["var node: CanvasItem = %s" % target])
			if bool(card.get("visible", true)):
				lines.append("node.hide()")
			if bool(card.get("process", true)):
				lines.append("node.process_mode = Node.PROCESS_MODE_DISABLED")
			if bool(card.get("collision", false)):
				lines.append("node.get_node(\"CollisionShape2D\").set_deferred(\"disabled\", true)")
			if str(card.get("do", "for_a_time")) == "for_a_time":
				lines.append("await get_tree().create_timer(%s, true, false, true).timeout" % seconds)
				lines.append("node.show()")
				lines.append("node.process_mode = Node.PROCESS_MODE_INHERIT")
			return "\n".join(lines)
		"look_at":
			return "var node: Node2D = %s\nvar aim: Node2D = %s\nvar angle := (aim.global_position - node.global_position).angle()\ncreate_tween().tween_property(node, \"global_rotation\", angle, %s)" % [target, _node(card, "target", player), seconds]
		"rotate_by":
			return "var node: Node2D = %s\ncreate_tween().tween_property(node, \"rotation\", node.rotation + deg_to_rad(%s), %s)" % [target, _n(card.get("degrees", 45.0)), seconds]
		"rotate_to":
			return "var node: Node2D = %s\ncreate_tween().tween_property(node, \"rotation\", deg_to_rad(%s), %s)" % [target, _n(card.get("degrees", 90.0)), seconds]
		"rotation_shake":
			return "var node: Node2D = %s\nvar rest := node.rotation\nvar elapsed := 0.0\nwhile elapsed < %s:\n\tvar left := 1.0 - elapsed / %s\n\tnode.rotation = rest + deg_to_rad(%s) * left * sin(elapsed * TAU * 12.0)\n\tawait get_tree().process_frame\n\telapsed += get_process_delta_time()\nnode.rotation = rest" % [target, seconds, seconds, _n(card.get("degrees", 10.0))]
		"light":
			var start: String = ""
			if card.has("energy_from"):
				start += "light.energy = %s\n" % _n(card["energy_from"])
			if card.has("colour_from"):
				start += "light.color = %s\n" % _colour(card["colour_from"])
			var out: String = "var light: Light2D = %s\nvar rest_energy := light.energy\nvar rest_colour := light.color\n%svar tween := create_tween().set_parallel()\ntween.tween_property(light, \"energy\", %s, %s)\ntween.tween_property(light, \"color\", %s, %s)" % [target, start, _n(card.get("energy_to", 3.0)), seconds, _colour(card.get("colour_to", Color(1.0, 0.6, 0.2))), seconds]
			if bool(card.get("back", true)):
				out += "\ntween.chain().tween_property(light, \"energy\", rest_energy, %s)\ntween.tween_property(light, \"color\", rest_colour, %s)" % [_n(card.get("back_seconds", 0.2)), _n(card.get("back_seconds", 0.2))]
			return out
		"scene_look":
			var property: String = str(card.get("property", "glow_intensity"))
			return "var world: WorldEnvironment = %s\nvar environment: Environment = world.environment\nvar before = environment.%s\nvar tween := create_tween()\ntween.tween_property(environment, \"%s\", %s, %s)\ntween.tween_property(environment, \"%s\", before, %s)" % [_world_name(card, player), property, property, _n(card.get("to", 2.0)), seconds, property, _n(card.get("back_seconds", 0.3))]
		"bus_effect":
			var how: String = str(card.get("how", "muffle"))
			var bus: String = str(card.get("bus", "Master"))
			if how == "switch":
				return "var bus := AudioServer.get_bus_index(\"%s\")\nAudioServer.set_bus_effect_enabled(bus, %d, true)\nawait get_tree().create_timer(%s).timeout\nAudioServer.set_bus_effect_enabled(bus, %d, false)" % [bus, int(card.get("slot", 0)), seconds, int(card.get("slot", 0))]
			var effect_class: Dictionary = {"muffle": ["AudioEffectLowPassFilter", "cutoff_hz", "20500.0"], "dive": ["AudioEffectAmplify", "volume_db", "0.0"], "wash": ["AudioEffectReverb", "wet", "0.0"]}
			var entry: Array = effect_class.get(how, effect_class["muffle"])
			return EventSheetL10n.agree_article("# The bus must already carry a %s.\nvar bus := AudioServer.get_bus_index(\"%s\")\nvar effect: %s\nfor slot in AudioServer.get_bus_effect_count(bus):\n\tif AudioServer.get_bus_effect(bus, slot) is %s:\n\t\teffect = AudioServer.get_bus_effect(bus, slot)\neffect.%s = %s\nawait get_tree().create_timer(%s).timeout\neffect.%s = %s" % [entry[0], bus, entry[0], entry[0], entry[1], _n(card.get("to", 400.0)), seconds, entry[1], entry[2]], str(entry[0]))
		"chromatic_shake":
			return _chromatic_shake_by_hand(card, seconds)
		"spring":
			var property: String = str(card.get("property", "scale"))
			return "# Needs a Spring node under this node; it settles the value back to rest.\n%s.bump_property(\"%s\", %s)" % [_spring_name(card, player), property, _value(card.get("kick", 3.0))]
		"slow_object":
			return "for node in find_children(\"*\", \"AnimationPlayer\", true, false):\n\tnode.speed_scale = %s\nawait get_tree().create_timer(%s).timeout\nfor node in find_children(\"*\", \"AnimationPlayer\", true, false):\n\tnode.speed_scale = 1.0" % [_n(card.get("speed", 0.3)), seconds]
		"animation_parameter":
			var parameter: String = str(card.get("parameter", "parameters/blend/blend_amount"))
			var rest_line: String = "var tree: AnimationTree = %s\nvar before = tree.get(\"%s\")\n" % [target, parameter]
			var tween_line: String = "var tween := create_tween()\ntween.tween_method(func(value: float) -> void: tree.set(\"%s\", value), float(before), %s, %s)" % [parameter, _n(card.get("to", 1.0)), seconds]
			if bool(card.get("back", true)):
				tween_line += "\ntween.tween_method(func(value: float) -> void: tree.set(\"%s\", value), %s, float(before), %s)" % [parameter, _n(card.get("to", 1.0)), _n(card.get("back_seconds", 0.2))]
			return rest_line + tween_line
	return ""


## A colour split by hand: a full-screen rectangle whose shader reads the screen three times the way the Juice node does,
## red a little one way, green a little the other and blue four times as far as red, and a tween that closes the split. A
## steady direction is the card's angle; a wandering one is picked once here, where the Juice node keeps turning it.
static func _chromatic_shake_by_hand(card: Dictionary, seconds: String) -> String:
	var lines: PackedStringArray = PackedStringArray([
		"var layer := CanvasLayer.new()",
		"var screen := ColorRect.new()",
		"screen.set_anchors_preset(Control.PRESET_FULL_RECT)",
		"screen.mouse_filter = Control.MOUSE_FILTER_IGNORE",
		"var shader := Shader.new()",
		"shader.code = \"\"\"",
		"shader_type canvas_item;",
		"uniform sampler2D screen_texture : hint_screen_texture, filter_linear;",
		"uniform vec2 split;",
		"void fragment() {",
		"\tvec2 shift = split * SCREEN_PIXEL_SIZE;",
		"\tvec3 split_colour = vec3(",
		"\t\ttexture(screen_texture, SCREEN_UV + shift).r,",
		"\t\ttexture(screen_texture, SCREEN_UV - shift).g,",
		"\t\ttexture(screen_texture, SCREEN_UV + shift * 4.0).b);",
		"\tCOLOR = vec4(mix(split_colour, texture(screen_texture, SCREEN_UV + shift * 1.25).rgb, 0.25), 1.0);",
		"}\"\"\"",
		"screen.material = ShaderMaterial.new()",
		"screen.material.shader = shader",
		"layer.add_child(screen)",
		"add_child(layer)"
	])
	var amount: String = _n(card.get("amount", 12.0))
	if str(card.get("direction", "wander")) == "angle":
		lines.append("screen.material.set_shader_parameter(\"split\", Vector2.from_angle(deg_to_rad(%s)) * %s)" % [_n(card.get("angle", 0.0)), amount])
	else:
		lines.append("screen.material.set_shader_parameter(\"split\", Vector2.from_angle(randf() * TAU) * %s)" % amount)
	if str(card.get("mode", "reducing")) == "constant":
		lines.append("await get_tree().create_timer(%s).timeout" % seconds)
		lines.append("screen.material.set_shader_parameter(\"split\", Vector2.ZERO)")
	else:
		lines.append("var tween := create_tween()")
		lines.append("tween.tween_property(screen.material, \"shader_parameter/split\", Vector2.ZERO, %s)" % seconds)
		lines.append("await tween.finished")
	lines.append("layer.queue_free()")
	return "\n".join(lines)
