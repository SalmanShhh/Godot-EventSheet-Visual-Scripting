# Godot EventSheets - what the Inspector's play buttons show for the cards that reach other nodes
# (editor-only, loaded by path).
#
# A Particles, Animation, Show or Hide, Pop, Fade, Count To, Reveal Text, Fill Bar, Shader Value or
# Tween Property card changes a node that is not the one the player sits under, and a Squash And
# Stretch, Punch Position or Punch Rotation card changes the object itself. The strip that previews a
# list asks this file three questions, once per card:
#
#   `watched`   what may this card move? Every property and object it names, so the strip writes the
#               values down BEFORE the first frame and puts exactly those back on Stop, on Restore, at
#               the end of a pass and before the editor saves the scene.
#   `step`      what does the card do `through` of the way into its length (0 to 1, or more once it is
#               over)? It writes the properties itself, so the shape of each is the shape the running
#               game plays: the same tween words, the same springs, the same peak.
#   `finish`    anything a step set up beyond a property value (an animation's position, a material
#               copy), taken away again.
#
# Nothing here adds a node to a scene, and nothing writes a file: a shader copy is a duplicate held in
# memory for the pass, and the node's own material is the thing put back.
#
# No class_name on purpose: Create Node lists every named class, and an editor-only helper has no
# business there.
@tool
extends RefCounted

## The words of the cards this file previews, besides a Tween Property card.
const WORDS: PackedStringArray = [
	"particles", "animation", "sprite_animation", "show_hide", "squash_stretch", "punch_position",
	"punch_rotation", "pop", "fade", "count_to", "reveal_text", "fill_bar", "shader_value",
	"look_at", "rotate_by", "rotate_to", "rotation_shake", "draw_order", "light", "position_shake", "grayscale"
]

## The cards that act on the object the player is under, whatever else they hold.
const ON_HOST: PackedStringArray = ["squash_stretch", "punch_position", "punch_rotation", "grayscale"]

## The cards whose node, left empty, is the object the player is under.
const HOST_WHEN_EMPTY: PackedStringArray = ["show_hide", "pop", "fade", "shader_value", "tween_property", "look_at", "rotate_by",
	"rotate_to", "rotation_shake", "draw_order", "light", "position_shake"]

## The keys that make a Tween Property card the whole card, as the running player counts them.
const TWEEN_KEYS: PackedStringArray = ["node", "to", "from", "trans", "ease", "relative", "back"]


## Whether this file previews the card.
static func handles(card: Dictionary) -> bool:
	if card.has("card_script"):
		return is_tool_card(card)
	var word: String = str(card.get("verb", ""))
	if word == "tween_property":
		return is_whole_tween(card)
	return WORDS.has(word)


## Whether a card of your own is made of a tool script, which is the only kind the editor runs.
static func is_tool_card(card: Dictionary) -> bool:
	var pack: Script = load("res://addons/eventsheet/editor/inspector/juice_preview.gd").call("pack_script")
	var script: Script = pack.call("own_script_of", card) as Script if pack != null else null
	return script != null and script.is_tool()


## Whether a Tween Property card holds any of the keys that make it the whole card. A card without them
## is the one-number tween on this object, which the pack's own sample draws.
static func is_whole_tween(card: Dictionary) -> bool:
	for key: String in TWEEN_KEYS:
		if card.has(key):
			return true
	return false


## The node a card acts on, or null: the object itself for the cards that act on it, the node the card
## points at, and the object itself again when a card that may leave its node empty does.
static func node_of(player: Node, card: Dictionary, host: Node) -> Node:
	var word: String = str(card.get("verb", ""))
	if card.has("card_script") or ON_HOST.has(word):
		return host
	var stored: Variant = card.get("node", NodePath())
	var path: NodePath = stored if stored is NodePath else NodePath(str(stored))
	if path.is_empty():
		return host if HOST_WHEN_EMPTY.has(word) else null
	return player.get_node_or_null(path) if player != null else null


## Every [object, property] a preview of this card may move, so the strip can write each down first.
static func watched(card: Dictionary, node: Node) -> Array:
	var made: Array = []
	if node == null or card.has("card_script"):
		return made
	match str(card.get("verb", "")):
		"particles":
			made.append([node, "emitting"])
		"animation":
			made.append_array(_animation_tracks(card, node))
		"sprite_animation":
			for property: String in ["animation", "frame", "frame_progress"]:
				made.append([node, property])
		"show_hide":
			made.append([node, "visible"])
		"squash_stretch":
			made.append([node, "scale"])
			if node is Control:
				made.append([node, "pivot_offset"])
		"punch_position":
			made.append([node, "position"])
		"punch_rotation":
			made.append([node, "rotation"])
			if node is Control:
				made.append([node, "pivot_offset"])
		"pop":
			made.append([node, "scale"])
			if node is Control:
				made.append([node, "pivot_offset"])
		"fade":
			made.append([node, "modulate"])
		"count_to":
			made.append([node, "text"])
		"reveal_text":
			made.append([node, "visible_ratio"])
		"fill_bar":
			made.append([node, "value"])
		"shader_value":
			made.append([node, "material" if node is CanvasItem else "material_override"])
			var shared: ShaderMaterial = _material_of(node)
			if shared != null and not bool(card.get("only_this", true)):
				made.append([shared, "shader_parameter/" + str(card.get("parameter", ""))])
		"tween_property":
			var property: String = str(card.get("effect", "")).strip_edges()
			if not property.is_empty():
				made.append([node, property])
		"look_at", "rotate_by", "rotate_to", "rotation_shake":
			made.append([node, "rotation"])
			if node is Control:
				made.append([node, "pivot_offset"])
		"draw_order":
			made.append([node, "z_index"])
		"position_shake":
			made.append([node, "position"])
		"grayscale":
			made.append([node, "modulate"])
		"light":
			var names: Dictionary = light_names(node)
			for key: String in ["energy", "colour", "on"]:
				if names.has(key):
					made.append([node, str(names[key])])
	return made


## Puts one card `through` of the way into its length on its node. `through` runs from 0 and may pass 1
## once the card is over; `at` is the strength of the play; `state` is the pass's own memory, so a card
## that starts something (a burst, a clip, a material copy) does it once. `slot` is the card's place in
## the pass, so two cards that look alike are not mistaken for each other.
static func step(card: Dictionary, node: Node, through: float, at: float, state: Dictionary, slot: int = 0) -> void:
	if node == null or not is_instance_valid(node):
		return
	var word: String = str(card.get("verb", ""))
	var seconds: float = maxf(float(card.get("seconds", 0.0)), 0.05)
	var held: float = clampf(through, 0.0, 1.0)
	if card.has("card_script"):
		_own(card, node, at, state, slot)
		return
	match word:
		"particles":
			_particles(card, node, state, slot)
		"animation":
			_animation(card, node, held, state)
		"sprite_animation":
			_sprite_animation(card, node, held, state)
		"show_hide":
			var mode: String = str(card.get("do", "flash"))
			node.set("visible", mode != "hide" and (mode != "flash" or through < 1.0))
		"squash_stretch":
			_squash(card, node, held, at, seconds, state)
		"punch_position":
			if node is Node2D or node is Control:
				var kick: Vector2 = Vector2(float(card.get("x", 0.0)), float(card.get("y", -10.0))) * at
				var rest_position: Vector2 = _rest(state, node, "position") as Vector2
				node.set("position", rest_position + _spring(kick, held, seconds))
		"punch_rotation":
			if node is CanvasItem:
				_centre(node, state)
				var rest_rotation: float = float(_rest(state, node, "rotation"))
				node.set("rotation", rest_rotation + _spring(deg_to_rad(float(card.get("amount", 10.0)) * at), held, seconds))
		"pop":
			_pop(card, node, held, seconds, state)
		"fade":
			var rest_colour: Color = _rest(state, node, "modulate") as Color
			var faded: Color = rest_colour
			faded.a = lerpf(rest_colour.a, float(card.get("amount", 0.0)), held)
			node.set("modulate", faded)
		"count_to":
			_count_to(card, node, held, state)
		"reveal_text":
			node.set("visible_ratio", held)
		"fill_bar":
			var goal: Variant = plain_number(str(card.get("to", "")))
			if goal != null:
				node.set("value", lerpf(float(_rest(state, node, "value")), float(goal), held))
		"shader_value":
			_shader_value(card, node, held, state)
		"tween_property":
			_tween(card, node, held, at, state)
		"rotate_by":
			_turn(card, node, held, seconds, state, true)
		"rotate_to":
			_turn(card, node, held, seconds, state, false)
		"rotation_shake":
			_rotation_shake(card, node, held, at, seconds, state)
		"look_at":
			_look_at(card, node, held, state)
		"position_shake":
			_position_shake(card, node, held, at, seconds, state)
		"grayscale":
			_grayscale(card, node, through, at, seconds, state)
		"draw_order":
			node.set("z_index", clampi(int(card.get("z_index", 10)), -4096, 4096) if through < 1.0 else _rest(state, node, "z_index"))
		"light":
			_light(card, node, through, at, state)


## Writes down the value a property has now, as the pass's rest value. The strip calls it for everything
## `watched` named, before the first frame, so a step always springs back to what the scene really holds.
static func remember(state: Dictionary, object: Object, property: String) -> Variant:
	return _rest(state, object, property)


## Takes away what a step set up beyond a value: an animation player stops where it is, and the pass's own
## memory goes. The strip puts the recorded values back after this.
static func finish(state: Dictionary) -> void:
	for made: Variant in state.get("own", []):
		var own_card: Resource = made as Resource
		if own_card != null and is_instance_valid(own_card):
			for door: String in ["stop", "restore"]:
				if own_card.has_method(door):
					own_card.call(door)
	for entry: Variant in state.get("clips", []):
		var animation_player: AnimationPlayer = entry as AnimationPlayer
		if animation_player != null and is_instance_valid(animation_player):
			animation_player.stop()
	state.clear()


## A plain number, or null when the text names something only a running game can read.
static func plain_number(text: String) -> Variant:
	var said: String = text.strip_edges()
	return said.to_float() if said.is_valid_float() else null


## The value of a property as it was before the pass touched it. The strip wrote it down; a step reads it
## here by asking the pass's memory, and the first ask is the property as it is, which is the rest value
## because nothing has moved it yet.
static func _rest(state: Dictionary, node: Object, property: String) -> Variant:
	var key: String = "%d|%s" % [node.get_instance_id(), property]
	var held: Dictionary = state.get("rest", {})
	if not held.has(key):
		held[key] = node.get_indexed(NodePath(property))
		state["rest"] = held
	return held[key]


## A Control scales and turns about its middle, set the way the running player sets it.
static func _centre(node: Object, state: Dictionary) -> void:
	if node is Control:
		_rest(state, node, "pivot_offset")
		(node as Control).pivot_offset = (node as Control).size / 2.0


## A kick that springs back the way the Juice node springs it: elastic out, from the kick to nothing.
static func _spring(kick: Variant, through: float, seconds: float) -> Variant:
	return Tween.interpolate_value(kick, -kick, through * seconds, seconds, Tween.TRANS_ELASTIC, Tween.EASE_OUT)


static func _squash(card: Dictionary, node: Node, held: float, at: float, seconds: float, state: Dictionary) -> void:
	if not (node is Node2D or node is Control):
		return
	var rest: Vector2 = _rest(state, node, "scale") as Vector2
	var s: float = clampf(float(card.get("amount", 0.3)) * at, -0.9, 5.0)
	var stretched: Vector2 = Vector2(rest.x / (1.0 + s), rest.y * (1.0 + s))
	if node is Control:
		(node as Control).pivot_offset = (node as Control).size / 2.0
	node.set("scale", Tween.interpolate_value(stretched, rest - stretched, held * seconds, seconds, Tween.TRANS_ELASTIC, Tween.EASE_OUT))


static func _pop(card: Dictionary, node: Node, held: float, seconds: float, state: Dictionary) -> void:
	if not (node.get("scale") is Vector2 or node.get("scale") is Vector3):
		return
	_centre(node, state)
	var rest: Variant = _rest(state, node, "scale")
	var peak: float = float(card.get("amount", 1.3))
	var elapsed: float = held * seconds
	var rise: float = seconds * 0.4
	if elapsed <= rise:
		node.set("scale", Tween.interpolate_value(rest, rest * peak - rest, elapsed, rise, Tween.TRANS_BACK, Tween.EASE_OUT))
	else:
		node.set("scale", Tween.interpolate_value(rest * peak, rest - rest * peak, elapsed - rise, seconds * 0.6, Tween.TRANS_SINE, Tween.EASE_IN_OUT))


## The pack that plays the cards, which says what a light is called and how fast a rotation shake swings.
static func _pack() -> Script:
	return load("res://addons/eventsheet/editor/inspector/juice_preview.gd").call("pack_script") as Script


## The three names a light answers to: brightness, colour, and what switches it on. Asked of the pack, so the
## picture and the game cannot disagree. Empty for a node that is no light.
static func light_names(node: Node) -> Dictionary:
	var pack: Script = _pack()
	return pack.call("light_properties", node) as Dictionary if pack != null and node != null else {}


## Rotate By and Rotate To: the angle walked from where it is to where it is going, by the curve the game uses.
static func _turn(card: Dictionary, node: Node, held: float, seconds: float, state: Dictionary, by: bool) -> void:
	if not (node is Node2D or node is Control or node is Node3D):
		return
	_centre(node, state)
	var rest: Variant = _rest(state, node, "rotation")
	var wanted: float = deg_to_rad(float(card.get("degrees", 45.0 if by else 90.0)))
	var now: float = (rest as Vector3).y if rest is Vector3 else float(rest)
	var goal_angle: float = now + wanted if by else now + angle_difference(now, wanted)
	var goal: Variant = Vector3((rest as Vector3).x, goal_angle, (rest as Vector3).z) if rest is Vector3 else goal_angle
	node.set("rotation", Tween.interpolate_value(rest, goal - rest, held * seconds, seconds, Tween.TRANS_SINE, Tween.EASE_IN_OUT))


## Rotation Shake: the angle at rest plus a swing the shape of the shake makes larger or smaller, ending at rest.
static func _rotation_shake(card: Dictionary, node: Node, held: float, at: float, seconds: float, state: Dictionary) -> void:
	if not (node is Node2D or node is Control or node is Node3D):
		return
	_centre(node, state)
	var rest: Variant = _rest(state, node, "rotation")
	var pack: Script = _pack()
	var hertz: float = float(pack.get_script_constant_map().get("SHAKE_HERTZ", 12.0)) if pack != null else 12.0
	var share: float = float(load("res://addons/eventsheet/editor/inspector/juice_shake_fields.gd").call("shape_at", card, held))
	var swing: float = 0.0
	if held < 1.0:
		swing = deg_to_rad(float(card.get("degrees", 10.0))) * at * share * sin(held * seconds * TAU * hertz)
	if rest is Vector3:
		node.set("rotation", Vector3((rest as Vector3).x, (rest as Vector3).y + swing, (rest as Vector3).z))
	else:
		node.set("rotation", float(rest) + swing)


## Position Shake: the position at rest plus a jump to a new place the shape of the shake makes larger or smaller, ending at
## rest. The places are worked out from the time alone, so a second play draws the same shake.
static func _position_shake(card: Dictionary, node: Node, held: float, at: float, seconds: float, state: Dictionary) -> void:
	if not (node is Node2D or node is Control or node is Node3D):
		return
	var rest: Variant = _rest(state, node, "position")
	var share: float = float(load("res://addons/eventsheet/editor/inspector/juice_shake_fields.gd").call("shape_at", card, held))
	var jump: int = int(floor(held * seconds * maxf(float(card.get("jumps", 30.0)), 0.1)))
	var level: float = float(card.get("amount", 8.0)) * at * share if held < 1.0 else 0.0
	var way: Vector3 = Vector3(_scatter(jump, 1.0) * float(card.get("weight_x", 1.0)), _scatter(jump, 2.0) * float(card.get("weight_y", 1.0)), _scatter(jump, 3.0) * float(card.get("weight_z", 1.0)))
	if rest is Vector3:
		node.set("position", (rest as Vector3) + way * level)
	else:
		node.set("position", (rest as Vector2) + Vector2(way.x, way.y) * level)


## A number from -1 to 1 that depends only on the jump and the axis, so the preview shakes the same way every time.
static func _scatter(jump: int, axis: float) -> float:
	return fposmod(sin(float(jump) * 12.9898 + axis * 78.233) * 43758.5453, 2.0) - 1.0


## Grayscale: the object stands in for the screen, so the editor shows the colour draining out of it and coming back.
static func _grayscale(card: Dictionary, node: Node, through: float, at: float, seconds: float, state: Dictionary) -> void:
	if not (node is CanvasItem):
		return
	var rest: Color = _rest(state, node, "modulate") as Color
	var total: float = maxf(seconds, 0.05)
	var elapsed: float = through * total
	var amount: float = clampf(float(card.get("amount", 1.0)) * at, 0.0, 1.0)
	var drain: float = 0.0 if str(card.get("shape", "screen")) != "screen" else maxf(float(card.get("fade_in", 0.2)), 0.001)
	var back: float = maxf(float(card.get("fade_out", 0.4)), 0.001)
	var share: float = clampf(elapsed / drain, 0.0, 1.0) if drain > 0.001 else 1.0
	if not bool(card.get("stay", false)) and elapsed > total - back:
		share = clampf((total - elapsed) / back, 0.0, 1.0) * share
	var luma: float = rest.r * 0.2126 + rest.g * 0.7152 + rest.b * 0.0722
	node.set("modulate", rest.lerp(Color(luma, luma, luma, rest.a), amount * share))


## Look At: the node turns to face the node it names, over the card's length.
static func _look_at(card: Dictionary, node: Node, held: float, state: Dictionary) -> void:
	var player: Node = state.get("player") as Node
	var stored: Variant = card.get("target", NodePath())
	var aim: Node = player.get_node_or_null(stored if stored is NodePath else NodePath(str(stored))) if player != null else null
	if aim == null:
		return
	if node is Node2D and aim is Node2D:
		var from_angle: float = float(_rest(state, node, "global_rotation"))
		var offset: Vector2 = (aim as Node2D).global_position - (node as Node2D).global_position
		if offset.length() >= 0.001:
			var goal: float = from_angle + angle_difference(from_angle, offset.angle())
			(node as Node2D).global_rotation = Tween.interpolate_value(from_angle, goal - from_angle, held, 1.0, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	elif node is Node3D and aim is Node3D:
		var start: Vector3 = (node as Node3D).global_position
		var end: Vector3 = (aim as Node3D).global_position
		if start.distance_to(end) < 0.001:
			return
		var key: String = "look|%d" % node.get_instance_id()
		if not state.has(key):
			state[key] = (node as Node3D).global_transform.basis.get_rotation_quaternion()
		var up: Vector3 = Vector3.FORWARD if absf((end - start).normalized().dot(Vector3.UP)) > 0.999 else Vector3.UP
		var goal_turn: Quaternion = Transform3D(Basis(), start).looking_at(end, up).basis.get_rotation_quaternion()
		var now: Transform3D = (node as Node3D).global_transform
		(node as Node3D).global_transform = Transform3D(Basis((state[key] as Quaternion).slerp(goal_turn, held)).scaled(now.basis.get_scale()), now.origin)


## Light: brightness and colour walked to the flare and back, the way the game walks them.
static func _light(card: Dictionary, node: Node, through: float, at: float, state: Dictionary) -> void:
	var names: Dictionary = light_names(node)
	if names.is_empty():
		return
	var rest_energy: float = float(_rest(state, node, str(names["energy"])))
	var rest_colour: Color = _rest(state, node, str(names["colour"])) as Color
	# A card that names no start begins where the light is.
	var start_energy: float = float(card["energy_from"]) if card.has("energy_from") else rest_energy
	var from_value: Variant = card.get("colour_from", rest_colour)
	var start_colour: Color = from_value as Color if from_value is Color else Color(str(from_value))
	var switched: String = str(names["on"])
	var peak: float = rest_energy + (float(card.get("energy_to", 3.0)) - rest_energy) * at
	var raw: Variant = card.get("colour_to", Color(1.0, 0.6, 0.2))
	var tint: Color = rest_colour.lerp(raw as Color if raw is Color else Color(str(raw)), clampf(at, 0.0, 1.0))
	var seconds: float = maxf(float(card.get("seconds", 0.08)), 0.0)
	var back: bool = bool(card.get("back", true))
	var back_seconds: float = maxf(float(card.get("back_seconds", 0.2)), 0.0) if back else 0.0
	var elapsed: float = clampf(through, 0.0, 1.0) * (seconds + back_seconds)
	var word: String = str(card.get("ease", "out"))
	var easing: int = Tween.EASE_OUT
	if word == "in":
		easing = Tween.EASE_IN
	elif word == "in_out":
		easing = Tween.EASE_IN_OUT
	var curve: int = Tween.TRANS_LINEAR if word == "linear" else Tween.TRANS_SINE
	if not bool(_rest(state, node, switched)):
		node.set(switched, through < 1.0)
	if elapsed <= seconds and seconds > 0.0:
		node.set(str(names["energy"]), Tween.interpolate_value(start_energy, peak - start_energy, elapsed, seconds, curve, easing))
		node.set(str(names["colour"]), Tween.interpolate_value(start_colour, tint - start_colour, elapsed, seconds, curve, easing))
	elif back and back_seconds > 0.0 and elapsed < seconds + back_seconds:
		node.set(str(names["energy"]), Tween.interpolate_value(peak, rest_energy - peak, elapsed - seconds, back_seconds, curve, easing))
		node.set(str(names["colour"]), Tween.interpolate_value(tint, rest_colour - tint, elapsed - seconds, back_seconds, curve, easing))
	else:
		node.set(str(names["energy"]), rest_energy if back else peak)
		node.set(str(names["colour"]), rest_colour if back else tint)


## A card of your own that is a tool script: played once, when its turn comes, and told to stop and to put
## things back when the pass is over.
static func _own(card: Dictionary, host: Node, at: float, state: Dictionary, slot: int) -> void:
	var started: Dictionary = state.get("started", {})
	if started.has(slot):
		return
	started[slot] = true
	state["started"] = started
	var pack: Script = load("res://addons/eventsheet/editor/inspector/juice_preview.gd").call("pack_script")
	var made: Resource = pack.call("own_card_of", card) as Resource if pack != null else null
	if made == null:
		return
	if "player" in made:
		made.set("player", state.get("player"))
	var running: Array = state.get("own", [])
	running.append(made)
	state["own"] = running
	made.call("play", host, at)


static func _particles(card: Dictionary, node: Node, state: Dictionary, slot: int) -> void:
	if not ("emitting" in node):
		return
	var started: Dictionary = state.get("started", {})
	if started.has(slot):
		return
	started[slot] = true
	state["started"] = started
	match str(card.get("do", "restart")):
		"stop":
			node.set("emitting", false)
		"start":
			node.set("emitting", true)
		_:
			if node.has_method("restart"):
				node.call("restart")
			node.set("emitting", true)


## The tracks of a clip, as the [node, property] pairs they write, so a preview of the clip can put them back.
static func _animation_tracks(card: Dictionary, player: Node) -> Array:
	var made: Array = []
	var animation_player: AnimationPlayer = player as AnimationPlayer
	if animation_player == null:
		return made
	made.append([animation_player, "assigned_animation"])
	var clip_name: String = str(card.get("animation", ""))
	if not animation_player.has_animation(clip_name):
		return made
	var clip: Animation = animation_player.get_animation(clip_name)
	var root: Node = animation_player.get_node_or_null(animation_player.root_node)
	if root == null:
		return made
	for index: int in range(clip.get_track_count()):
		var path: NodePath = clip.track_get_path(index)
		var owner: Node = root.get_node_or_null(NodePath(str(path.get_concatenated_names())))
		if owner == null:
			continue
		match clip.track_get_type(index):
			Animation.TYPE_VALUE:
				made.append([owner, str(path.get_concatenated_subnames())])
			Animation.TYPE_POSITION_3D:
				made.append([owner, "position"])
			Animation.TYPE_ROTATION_3D:
				made.append([owner, "quaternion"])
			Animation.TYPE_SCALE_3D:
				made.append([owner, "scale"])
	return made


static func _animation(card: Dictionary, node: Node, held: float, state: Dictionary) -> void:
	var animation_player: AnimationPlayer = node as AnimationPlayer
	var clip_name: String = str(card.get("animation", ""))
	if animation_player == null or not animation_player.has_animation(clip_name):
		return
	var clips: Array = state.get("clips", [])
	if not clips.has(animation_player):
		clips.append(animation_player)
		state["clips"] = clips
	animation_player.assigned_animation = clip_name
	animation_player.seek(held * animation_player.get_animation(clip_name).length, true)


static func _sprite_animation(card: Dictionary, node: Node, held: float, _state: Dictionary) -> void:
	var frames: SpriteFrames = node.get("sprite_frames") as SpriteFrames
	var clip_name: String = str(card.get("animation", ""))
	if frames == null or not frames.has_animation(clip_name):
		return
	var count: int = frames.get_frame_count(clip_name)
	if str(node.get("animation")) != clip_name:
		node.set("animation", clip_name)
	node.set("frame", mini(int(held * float(count)), maxi(count - 1, 0)))


static func _count_to(card: Dictionary, node: Node, held: float, state: Dictionary) -> void:
	var goal: Variant = plain_number(str(card.get("to", "")))
	if goal == null or not ("text" in node):
		return
	var shown: String = str(_rest(state, node, "text")).strip_edges()
	var from: float = shown.to_float() if shown.is_valid_float() else 0.0
	node.set("text", str(int(round(lerpf(from, float(goal), held)))))


static func _material_of(node: Node) -> ShaderMaterial:
	if node is CanvasItem:
		return (node as CanvasItem).material as ShaderMaterial
	if node is GeometryInstance3D:
		return (node as GeometryInstance3D).material_override as ShaderMaterial
	return null


## One value of a node's shader, walked to a number, a colour or a vector and back. A card that says "only
## this object" works on a copy of the material that lives for the pass, so the shared file is never the
## thing written; the node's own material is what the strip puts back.
static func _shader_value(card: Dictionary, node: Node, held: float, state: Dictionary) -> void:
	var name: String = str(card.get("parameter", ""))
	var shared: ShaderMaterial = _material_of(node)
	if shared == null or shared.shader == null or name.is_empty():
		return
	var material: ShaderMaterial = shared
	if bool(card.get("only_this", true)):
		var copies: Dictionary = state.get("copies", {})
		var key: int = node.get_instance_id()
		if not copies.has(key):
			copies[key] = shared.duplicate()
			state["copies"] = copies
			node.set("material" if node is CanvasItem else "material_override", copies[key])
		material = copies[key] as ShaderMaterial
	var before: Variant = material.get_shader_parameter(name)
	var rest: Dictionary = state.get("shader_rest", {})
	var rest_key: String = "%d|%s" % [material.get_instance_id(), name]
	if rest.has(rest_key):
		before = rest[rest_key]
	else:
		if before == null:
			before = RenderingServer.shader_get_parameter_default(material.shader.get_rid(), name)
		rest[rest_key] = before
		state["shader_rest"] = rest
	var goal: Variant = card.get("to", before)
	if before == null or goal == null:
		return
	if (before is int or before is float) and (goal is int or goal is float):
		before = float(before)
		goal = float(goal)
	if typeof(before) != typeof(goal):
		return
	var transitions: Dictionary = _words("TRANSITIONS")
	var shape: int = int(transitions.get(str(card.get("trans", "sine")), Tween.TRANS_SINE))
	var seconds: float = maxf(float(card.get("seconds", 0.12)), 0.05)
	var value: Variant
	if bool(card.get("back", false)):
		if held < 0.5:
			value = Tween.interpolate_value(before, goal - before, held * seconds, seconds * 0.5, shape, Tween.EASE_IN_OUT)
		else:
			value = Tween.interpolate_value(goal, before - goal, held * seconds - seconds * 0.5, seconds * 0.5, shape, Tween.EASE_IN_OUT)
	else:
		value = Tween.interpolate_value(before, goal - before, held * seconds, seconds, shape, Tween.EASE_IN_OUT)
	material.set_shader_parameter(name, value)


## A Tween Property card that is the whole card: any node, a typed value, where it starts, its transition
## and ease, and whether it comes back.
static func _tween(card: Dictionary, node: Node, held: float, at: float, state: Dictionary) -> void:
	var property: String = str(card.get("effect", "")).strip_edges()
	if property.is_empty():
		return
	var before: Variant = _rest(state, node, property)
	if before == null:
		return
	var goal: Variant = card.get("to", float(card.get("amount", 1.0)))
	var relative: bool = bool(card.get("relative", false))
	if goal is float or goal is int or (relative and (goal is Vector2 or goal is Vector3)):
		goal = goal * at
	var start: Variant = card.get("from", before)
	if relative:
		goal = start + goal
	if (start is int or start is float) and (goal is int or goal is float):
		start = float(start)
		goal = float(goal)
	if typeof(start) != typeof(goal):
		return
	var seconds: float = maxf(float(card.get("seconds", 0.0)), 0.05)
	var shape: int = int(_words("TRANSITIONS").get(str(card.get("trans", "linear")), Tween.TRANS_LINEAR))
	var easing: int = int(_words("EASES").get(str(card.get("ease", "in_out")), Tween.EASE_IN_OUT))
	var value: Variant
	if bool(card.get("back", false)):
		if held < 0.5:
			value = Tween.interpolate_value(start, goal - start, held * seconds, seconds * 0.5, shape, easing)
		else:
			value = Tween.interpolate_value(goal, before - goal, held * seconds - seconds * 0.5, seconds * 0.5, shape, easing)
	else:
		value = Tween.interpolate_value(start, goal - start, held * seconds, seconds, shape, easing)
	node.set_indexed(NodePath(property), value)


## One of the pack's own word tables (the transitions and the eases), so a preview and a play use the
## same words. An empty table when the project holds no Juice Player.
static func _words(constant: String) -> Dictionary:
	var pack: Script = load("res://addons/eventsheet/editor/inspector/juice_preview.gd").call("pack_script")
	if pack == null:
		return {}
	var table: Variant = pack.get_script_constant_map().get(constant, {})
	return table as Dictionary if table is Dictionary else {}
