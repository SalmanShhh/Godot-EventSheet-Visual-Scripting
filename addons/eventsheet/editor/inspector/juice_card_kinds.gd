# Godot EventSheets - the juice cards that reach other nodes and the world (editor-only, UI-free).
#
# The kinds a Juice Player can play beyond a feeling and a wait: particles, an animation, showing or
# hiding, spawning a scene, a shove or a force on a body, the cards for a score label or a bar, a value of
# a shader, and the two cards that tell a node to do something. Each kind here is plain data - the fields
# it has, the words that name them, and the one sentence that says what it does - and the card-list drawer
# draws it. What each card DOES when it plays is the pack's, written in the Juice Player itself.
#
# EVERY NODE IS PICKED, never typed. A kind that acts on a node has a node field (Godot's own node
# picker); a kind that sets a property asks Godot's property picker; a kind that needs a name from the
# node it picked (an animation, a shader value, a signal) offers the names that node really has. The
# quiet amber lines under a card are computed from the edited player and the node a card points at, and
# are never stored.
#
# Loaded by path from the card schema, so the first open of the editor does not compile it.
@tool
extends RefCounted

const FIELDS_PATH: String = "res://addons/eventsheet/editor/inspector/juice_card_fields.gd"

## The node types a particles card can point at.
const PARTICLE_TYPES: Array = ["GPUParticles2D", "GPUParticles3D", "CPUParticles2D", "CPUParticles3D"]

## The node types a card that changes how something looks can point at.
const SEEN_TYPES: Array = ["CanvasItem", "Node3D"]

## The node types a card that moves a body can point at.
const BODY_TYPES: Array = ["RigidBody2D", "RigidBody3D", "CharacterBody2D", "CharacterBody3D"]

## The node types a card that needs a force or a gravity can point at.
const RIGID_TYPES: Array = ["RigidBody2D", "RigidBody3D"]


static func fields() -> Script:
	return load(FIELDS_PATH) as Script


## Every kind this file adds, in the order the Add box lists them inside a family.
static func kinds(family_of: Dictionary) -> Array:
	var all: Array = []
	all.append_array(_scene_kinds(family_of))
	all.append_array(_object_kinds(family_of))
	all.append_array(_body_kinds(family_of))
	all.append_array(_ui_kinds(family_of))
	all.append_array(_flow_kinds(family_of))
	return all


static func _kind(word: String, label: String, help: String, family_of: Dictionary, fields_list: Array, defaults: Dictionary, search: Array = []) -> Dictionary:
	return {
		"kind": word,
		"category": str(family_of.get(word, "")),
		"label": label,
		"help": help,
		"fields": fields_list,
		"live": [],
		"defaults": defaults,
		"search": PackedStringArray(search),
		"badge": EventSheetFeedbackCardSchema.seconds_badge
	}


static func _node(key: String, label: String, types: Array, empty: String = "", show_if: String = "", also: Callable = Callable()) -> Dictionary:
	var made: Dictionary = {"key": key, "label": label, "drawer": "node", "types": types, "empty": empty}
	if not show_if.is_empty():
		made["show_if"] = show_if
	if also.is_valid():
		made["also"] = also
	return made


static func _over(label: String, default_seconds: float) -> Dictionary:
	return {"key": "seconds", "label": label, "drawer": "unit:time", "default": default_seconds}


static func _scene_kinds(family_of: Dictionary) -> Array:
	return [
		_kind("particles", "Particles", "Restarts, starts or stops a particles node you pick. Its length is the node's lifetime when it is one shot.", family_of, [
			_node("node", "Node", PARTICLE_TYPES, "", "", particles_length),
			{"key": "do", "label": "Do", "drawer": "options:restart=Restart,start=Start,stop=Stop", "default": "restart"},
			_over("Length", 0.4)
		], {"do": "restart", "seconds": 0.4}, ["burst", "sparks", "emitter"]),
		_kind("spawn_scene", "Spawn Scene", "Adds a copy of a scene to the running game, at this object or at a node: a damage number, a decal, a dust puff. It takes the copy from the object pool when that scene has one.", family_of, [
			{"key": "scene", "label": "Scene", "drawer": "resource:PackedScene", "default": ""},
			{"key": "spawn_note", "label": "", "drawer": "note", "text": spawn_note, "visible_when": spawn_needs_care, "warn_when": spawn_needs_care},
			{"key": "at", "label": "Drop it at", "drawer": "options:here=This object,node=A node", "default": "here"},
			_node("node", "Node", ["Node"], "", "at==node")
		], {"scene": "", "at": "here"}, ["instance", "add scene", "damage number", "decal", "puff"])
	]


static func _object_kinds(family_of: Dictionary) -> Array:
	return [
		_kind("animation", "Animation", "Plays a clip of an animation player you pick, stretched to this card's length.", family_of, [
			_node("node", "Player", ["AnimationPlayer"]),
			{"key": "animation", "label": "Animation", "drawer": "choices", "choices": animation_names, "also": animation_length, "empty": "Pick an animation"},
			_over("Length", 0.4)
		], {"seconds": 0.4}, ["clip", "animate"]),
		_kind("sprite_animation", "Sprite Animation", "Plays an animation of an animated sprite you pick, stretched to this card's length.", family_of, [
			_node("node", "Sprite", ["AnimatedSprite2D", "AnimatedSprite3D"]),
			{"key": "animation", "label": "Animation", "drawer": "choices", "choices": sprite_animation_names, "also": sprite_animation_length, "empty": "Pick an animation"},
			_over("Length", 0.4)
		], {"seconds": 0.4}, ["frames", "animated sprite"]),
		_kind("show_hide", "Show or Hide", "Shows a node, hides it, or shows it for a time and hides it again: a hit spark, a muzzle flash, a warning icon. A card that picks no node acts on the object this player is under.", family_of, [
			_node("node", "Node", SEEN_TYPES, "This object"),
			{"key": "do", "label": "Do", "drawer": "options:show=Show,hide=Hide,flash=Show for a time", "default": "flash"},
			{"key": "seconds", "label": "For", "drawer": "unit:time", "default": 0.2, "show_if": "do==flash"}
		], {"do": "flash", "seconds": 0.2}, ["visible", "flash", "icon"]),
		_kind("squash_stretch", "Squash And Stretch", "Squashes and stretches the object this player is under, through the Juice node beside it. Put it on the sprite or mesh under a body, never on the body.", family_of, [
			{"key": "amount", "label": "Stretch", "drawer": "num", "default": 0.3},
			_over("Over", 0.2),
			{"key": "body_note", "label": "", "drawer": "note", "text": scaled_body_note, "hide_empty": true, "warn_when": scaled_body_care}
		], {"amount": 0.3, "seconds": 0.2}, ["squash", "stretch", "bounce"]),
		_kind("punch_position", "Punch Position", "Kicks the position of the object this player is under and springs it back, through the Juice node beside it.", family_of, [
			{"key": "x", "label": "Across", "drawer": "num", "default": 0.0, "suffix": "px"},
			{"key": "y", "label": "Down", "drawer": "num", "default": -10.0, "suffix": "px"},
			_over("Over", 0.2)
		], {"x": 0.0, "y": -10.0, "seconds": 0.2}, ["nudge", "knockback"]),
		_kind("punch_rotation", "Punch Rotation", "Kicks the rotation of the object this player is under and springs it back, through the Juice node beside it.", family_of, [
			{"key": "amount", "label": "Degrees", "drawer": "num", "default": 10.0},
			_over("Over", 0.2)
		], {"amount": 10.0, "seconds": 0.2}, ["wobble", "tilt"]),
		_kind("shader_value", "Shader Value", "Moves one value of the shader on a node to a number, a colour or a vector, over a time, and back again. Restore puts it back.", family_of, [
			_node("node", "Node", ["CanvasItem", "GeometryInstance3D"], "This object"),
			{"key": "parameter", "label": "Value", "drawer": "choices", "choices": shader_values, "empty": "Pick a value"},
			{"key": "to", "label": "To", "drawer": "typed", "sample": shader_sample},
			_over("Over", 0.12),
			{"key": "trans", "label": "Transition", "drawer": "options:linear=Linear,sine=Sine,quad=Quad,cubic=Cubic,expo=Expo,back=Back,elastic=Elastic,bounce=Bounce", "default": "quad"},
			{"key": "back", "label": "Then come back", "drawer": "bool", "default": true},
			{"key": "only_this", "label": "Only this object", "drawer": "bool", "default": true},
			{"key": "shader_note", "label": "", "drawer": "note", "text": shared_material_note, "visible_when": shared_material_care, "warn_when": shared_material_care}
		], {"trans": "quad", "back": true, "only_this": true, "seconds": 0.12}, ["material", "uniform", "flash"])
	]


static func _body_kinds(family_of: Dictionary) -> Array:
	return [
		_kind("push", "Push", "Gives a body a shove when the list reaches this card. A RigidBody takes it as an impulse; a CharacterBody has it added to its velocity once and carries on moving itself, so a script that sets its velocity every frame will overwrite it.", family_of, [
			_node("body", "Body", BODY_TYPES, "This object"),
			{"key": "direction", "label": "Direction", "drawer": "options:away=Away from a node,along=The way it is moving,fixed=A fixed direction", "default": "away"},
			_node("from", "Away from", ["Node2D", "Node3D"], "", "direction==away"),
			{"key": "x", "label": "Across", "drawer": "num", "default": 0.0, "show_if": "direction==fixed"},
			{"key": "y", "label": "Down", "drawer": "num", "default": -1.0, "show_if": "direction==fixed"},
			{"key": "z", "label": "Depth", "drawer": "num", "default": 0.0, "show_if": "direction==fixed"},
			{"key": "speed", "label": "Speed", "drawer": "num", "default": 300.0, "suffix": "px/s"},
			{"key": "scaled", "label": "Scaled by strength", "drawer": "bool", "default": true}
		], {"direction": "away", "speed": 300.0, "scaled": true}, ["knockback", "impulse", "shove"]),
		_kind("force_for_a_time", "Force For A Time", "A steady force on a RigidBody for a time: wind, a tractor beam, a rocket kick. It is taken away again when the time is up or on Restore.", family_of, [
			_node("body", "Body", RIGID_TYPES, "This object"),
			{"key": "x", "label": "Force x", "drawer": "num", "default": 0.0},
			{"key": "y", "label": "Force y", "drawer": "num", "default": -400.0},
			{"key": "z", "label": "Force z", "drawer": "num", "default": 0.0},
			_over("Over", 0.5)
		], {"x": 0.0, "y": -400.0, "z": 0.0, "seconds": 0.5}, ["wind", "constant force"]),
		_kind("gravity_for_a_time", "Gravity For A Time", "Changes the gravity scale of a RigidBody for a time, then puts it back: a floaty moment at the top of a hit.", family_of, [
			_node("body", "Body", RIGID_TYPES, "This object"),
			{"key": "amount", "label": "Gravity scale", "drawer": "num", "default": 0.2},
			_over("For", 0.5)
		], {"amount": 0.2, "seconds": 0.5}, ["float", "weightless"]),
		_kind("freeze_body", "Freeze Body", "Holds one RigidBody still for a time: hitstop for a single object while the rest of the game runs.", family_of, [
			_node("body", "Body", RIGID_TYPES, "This object"),
			_over("For", 0.1)
		], {"seconds": 0.1}, ["hitstop", "hold still"])
	]


static func _ui_kinds(family_of: Dictionary) -> Array:
	return [
		_kind("pop", "Pop", "Scales a node up from its middle and lets it settle back. The pivot is set for you.", family_of, [
			_node("node", "Node", SEEN_TYPES, "This object"),
			{"key": "amount", "label": "Scale to", "drawer": "num", "default": 1.3},
			_over("Over", 0.15),
			{"key": "body_note", "label": "", "drawer": "note", "text": popped_body_note, "hide_empty": true, "warn_when": popped_body_care}
		], {"amount": 1.3, "seconds": 0.15}, ["bounce", "punch scale"]),
		_kind("fade", "Fade", "Fades a node in or out through its modulate.", family_of, [
			_node("node", "Node", ["CanvasItem"], "This object"),
			{"key": "amount", "label": "Fade to", "drawer": "num", "default": 0.0},
			_over("Over", 0.3)
		], {"amount": 0.0, "seconds": 0.3}, ["alpha", "opacity", "modulate"]),
		_kind("grab_focus", "Grab Focus", "Moves keyboard and gamepad focus to a control: the first button of a menu that just popped in.", family_of, [
			_node("node", "Control", ["Control"])
		], {}, ["focus", "button"]),
		_kind("count_to", "Count To", "A label counts from the number it shows to a number. The number is a plain number or a name from your game, such as GameState.score.", family_of, [
			_node("node", "Label node", ["Label", "RichTextLabel"]),
			{"key": "to", "label": "To", "drawer": "text", "default": ""},
			_over("Over", 0.6)
		], {"to": "", "seconds": 0.6}, ["score", "number", "counter"]),
		_kind("reveal_text", "Reveal Text", "The letters of a label appear one after another at a speed. The card's length is the label's text divided by the speed.", family_of, [
			_node("node", "Label node", ["Label", "RichTextLabel"], "", "", reveal_length),
			{"key": "speed", "label": "Speed", "drawer": "num", "default": 40.0, "suffix": "letters/s", "on_change": reveal_length_for_speed}
		], {"speed": 40.0, "seconds": 0.8}, ["typewriter", "letters", "banner"]),
		_kind("fill_bar", "Fill Bar", "A progress bar or slider glides to a value. The value is a plain number or a name from your game, such as Player.health.", family_of, [
			_node("node", "Bar", ["Range"]),
			{"key": "to", "label": "To", "drawer": "text", "default": ""},
			_over("Over", 0.3)
		], {"to": "", "seconds": 0.3}, ["health", "progress", "slider"])
	]


static func _flow_kinds(family_of: Dictionary) -> Array:
	return [
		_kind("call_method", "Call Method", "Tells a node to act: calls a function of its script with the values below. For whatever no card covers: pop a score label, open a door, start your own effect.", family_of, [
			_node("node", "On", ["Node"]),
			{"key": "method", "label": "Method", "drawer": "choices", "choices": script_methods, "empty": "Pick a method"},
			{"key": "args", "label": "", "drawer": "arguments", "arguments": method_arguments}
		], {}, ["function", "call"]),
		_kind("pause_player", "Pause Or Resume A Juice Player", "Pauses, resumes or flips another Juice Player, or this one: a looping alarm that holds while a door is open. A paused list holds at the card it is on until it is resumed.", family_of, [
			_node("player", "Player", ["JuicePlayer"], "This player"),
			{"key": "mode", "label": "Do", "drawer": "options:pause=Pause,resume=Resume,toggle=Flip", "default": "pause"}
		], {"mode": "pause"}, ["pause", "resume", "toggle", "hold", "alarm"])
	]


## The most steps one play may take before it gives up on a loop, as the Juice Player counts them.
const MOST_PLAY_STEPS: int = 4096


## Where a Loop Back card sends the head: the position of the card under the Hold or Loop Start it lands on,
## or -1 when there is none above it (so the card loops nowhere).
static func loop_lands_at(card: Dictionary, cards: Array, index: int) -> int:
	var to_hold: bool = bool(card.get("to_hold", true))
	var to_start: bool = bool(card.get("to_loop_start", true))
	var walk: int = index - 1
	while walk >= 0:
		var word: String = str((cards[walk] as Dictionary).get("verb", "")).strip_edges().to_lower()
		if (to_hold and word == "hold_until") or (to_start and word == "loop_start"):
			return walk + 1
		walk -= 1
	return -1


## Whether a Loop Back card loops over cards that take no time at all and asks for so many passes that
## the play would run into its step limit and be given up.
static func loop_has_no_time(card: Dictionary, cards: Array, index: int, _edited: Object = null) -> bool:
	var loops: int = int(card.get("loops", 1))
	var lands: int = loop_lands_at(card, cards, index)
	if loops < 1 or lands < 0 or float(card.get("seconds", 0.0)) > 0.0:
		return false
	var steps: int = 1
	for walk: int in range(lands, index):
		var inside: Dictionary = cards[walk] as Dictionary
		if bool(inside.get("active", true)) and EventSheetFeedbackCardSchema.card_seconds(inside) > 0.0:
			return false
		steps += 1
	return loops * steps >= MOST_PLAY_STEPS


## The amber line under such a Loop Back card, empty when the loop has room to breathe.
static func loop_note(card: Dictionary, cards: Array, index: int, edited: Object) -> String:
	if not loop_has_no_time(card, cards, index, edited):
		return ""
	return EventSheetL10n.translate("Nothing in this loop takes time, so the play gives up after %d steps. Give a card in it a length, or the Loop Back a Pause.") % MOST_PLAY_STEPS


# ── What a card reads off the node it picked ───────────────────────────────────────────────────


## A Reveal Text card's length once its label is picked: the label's letters at the card's speed.
static func reveal_length(card: Dictionary, picked: Node) -> Dictionary:
	var letters: int = str(picked.get("text")).length() if picked != null and picked.get("text") != null else 0
	var speed: float = maxf(float(card.get("speed", 40.0)), 0.001)
	return {"seconds": snappedf(float(letters) / speed, 0.01)} if letters > 0 else {}


## The same length, once the speed is changed: the text of the label the card has picked.
static func reveal_length_for_speed(card: Dictionary, edited: Object, value: Variant) -> Dictionary:
	var label: Node = fields().call("resolve", edited, card.get("node")) as Node
	if label == null or label.get("text") == null:
		return {}
	var letters: int = str(label.get("text")).length()
	return {"seconds": snappedf(float(letters) / maxf(float(value), 0.001), 0.01)} if letters > 0 else {}


## The length of a particles card once its node is picked: the node's lifetime when it plays once.
static func particles_length(_card: Dictionary, picked: Node) -> Dictionary:
	if picked != null and bool(picked.get("one_shot")) and picked.get("lifetime") != null:
		return {"seconds": float(picked.get("lifetime"))}
	return {}


## The names of the clips of the animation player a card picked.
static func animation_names(card: Dictionary, edited: Object) -> Array:
	var player: AnimationPlayer = fields().call("resolve", edited, card.get("node")) as AnimationPlayer
	return Array(player.get_animation_list()) if player != null else []


## A card's length once a clip is chosen: the clip's own length.
static func animation_length(card: Dictionary, edited: Object, chosen: String) -> Dictionary:
	var player: AnimationPlayer = fields().call("resolve", edited, card.get("node")) as AnimationPlayer
	if player != null and player.has_animation(chosen):
		return {"seconds": snappedf(player.get_animation(chosen).length, 0.01)}
	return {}


static func _frames_of(card: Dictionary, edited: Object) -> SpriteFrames:
	var sprite: Node = fields().call("resolve", edited, card.get("node")) as Node
	return sprite.get("sprite_frames") as SpriteFrames if sprite != null else null


## The animations of the animated sprite a card picked.
static func sprite_animation_names(card: Dictionary, edited: Object) -> Array:
	var frames: SpriteFrames = _frames_of(card, edited)
	return Array(frames.get_animation_names()) if frames != null else []


## A card's length once a sprite animation is chosen: its frames at its own speed.
static func sprite_animation_length(card: Dictionary, edited: Object, chosen: String) -> Dictionary:
	var frames: SpriteFrames = _frames_of(card, edited)
	if frames != null and frames.has_animation(chosen):
		return {"seconds": snappedf(float(frames.get_frame_count(chosen)) / maxf(frames.get_animation_speed(chosen), 0.001), 0.01)}
	return {}


static func _shader_of(card: Dictionary, edited: Object) -> Shader:
	var target: Node = fields().call("target_of", edited, card, "node") as Node
	var material: Material = null
	if target is CanvasItem:
		material = (target as CanvasItem).material
	elif target is GeometryInstance3D:
		material = (target as GeometryInstance3D).material_override
	return (material as ShaderMaterial).shader if material is ShaderMaterial else null


## The values the shader on a card's node declares. A texture is left out: a card moves numbers, colours
## and vectors.
static func shader_values(card: Dictionary, edited: Object) -> Array:
	var shader: Shader = _shader_of(card, edited)
	var found: Array = []
	if shader == null:
		return found
	for entry: Variant in shader.get_shader_uniform_list():
		var uniform: Dictionary = entry as Dictionary
		if int(uniform.get("type", TYPE_NIL)) != TYPE_OBJECT:
			found.append(str(uniform.get("name", "")))
	return found


## A value of the right shape for the shader value a card picked, so the To box is a number, a colour or
## a set of numbers to match.
static func shader_sample(card: Dictionary, edited: Object) -> Variant:
	var shader: Shader = _shader_of(card, edited)
	var wanted: String = str(card.get("parameter", ""))
	if shader == null or wanted.is_empty():
		return null
	for entry: Variant in shader.get_shader_uniform_list():
		var uniform: Dictionary = entry as Dictionary
		if str(uniform.get("name", "")) == wanted:
			var shape: int = int(uniform.get("type", TYPE_FLOAT))
			if shape == TYPE_COLOR:
				return Color.WHITE
			return type_convert(0, shape)
	return null


static func _script_of(card: Dictionary, edited: Object) -> Script:
	var target: Node = fields().call("resolve", edited, card.get("node")) as Node
	return target.get_script() as Script if target != null else null


## The methods the script of the node a card picked declares, by name. Engine methods are left out.
static func script_methods(card: Dictionary, edited: Object) -> Array:
	var script: Script = _script_of(card, edited)
	var found: Array = []
	if script == null:
		return found
	for entry: Variant in script.get_script_method_list():
		var method: Dictionary = entry as Dictionary
		if not str(method.get("name", "")).begins_with("_"):
			found.append(str(method.get("name", "")))
	return found


## The signals the script of the node a card picked declares, by name. Engine signals are left out.
static func script_signals(card: Dictionary, edited: Object) -> Array:
	var script: Script = _script_of(card, edited)
	var found: Array = []
	if script == null:
		return found
	for entry: Variant in script.get_script_signal_list():
		found.append(str((entry as Dictionary).get("name", "")))
	return found


static func _listed_arguments(entries: Array, wanted: String) -> Array:
	for entry: Variant in entries:
		if str((entry as Dictionary).get("name", "")) == wanted:
			return (entry as Dictionary).get("args", [])
	return []


## The values the method a card picked takes, each with its name and kind.
static func method_arguments(card: Dictionary, edited: Object) -> Array:
	var script: Script = _script_of(card, edited)
	return _listed_arguments(script.get_script_method_list(), str(card.get("method", ""))) if script != null else []


## The values the signal a card picked carries, each with its name and kind.
static func signal_arguments(card: Dictionary, edited: Object) -> Array:
	var script: Script = _script_of(card, edited)
	return _listed_arguments(script.get_script_signal_list(), str(card.get("signal", ""))) if script != null else []


# ── The quiet lines under a card ───────────────────────────────────────────────────────────────


static func _is_body(node: Node) -> bool:
	return node is PhysicsBody2D or node is PhysicsBody3D


## The sentence under a Spawn Scene card that has no scene, or whose scene is gone.
static func spawn_note(card: Dictionary) -> String:
	var path: String = str(card.get("scene", ""))
	if path.is_empty():
		return EventSheetL10n.translate("Pick a scene. Until then this card drops nothing.")
	return EventSheetL10n.translate("That scene is not in the project any more, so this card drops nothing.")


static func spawn_needs_care(card: Dictionary) -> bool:
	var path: String = str(card.get("scene", ""))
	return path.is_empty() or not ResourceLoader.exists(path)


## The note under a Tween Property card on a physics body or a node a container places.
static func tween_note(card: Dictionary, _cards: Array, _index: int, edited: Object) -> String:
	var target: Node = fields().call("target_of", edited, card, "node") as Node
	var property: String = str(card.get("effect", ""))
	var places: bool = property.begins_with("position") or property.begins_with("global_position")
	if _is_body(target) and (places or property.begins_with("scale")):
		return EventSheetL10n.translate("This is a physics body, so moving or scaling it fights the physics. Use a Push card, or put the card on the sprite under the body.")
	if target is Control and target.get_parent() is Container and places:
		return EventSheetL10n.translate("A container places its children itself and puts a moved position back. Tween the scale, rotation or colour instead.")
	return ""


static func tween_needs_care(card: Dictionary, cards: Array, index: int, edited: Object) -> bool:
	return not tween_note(card, cards, index, edited).is_empty()


## The note under a squash or a punch whose object is a physics body.
static func scaled_body_note(card: Dictionary, _cards: Array, _index: int, edited: Object) -> String:
	if _is_body(fields().call("host_of", edited) as Node):
		return EventSheetL10n.translate("The object this player is under is a physics body, and scaling a body scales its collision shape. Put the player under the sprite instead.")
	return ""


static func scaled_body_care(card: Dictionary, cards: Array, index: int, edited: Object) -> bool:
	return not scaled_body_note(card, cards, index, edited).is_empty()


## The same note for a Pop, which names its own node.
static func popped_body_note(card: Dictionary, _cards: Array, _index: int, edited: Object) -> String:
	if _is_body(fields().call("target_of", edited, card, "node") as Node):
		return EventSheetL10n.translate("That node is a physics body, and scaling a body scales its collision shape. Pick the sprite under it instead.")
	return ""


static func popped_body_care(card: Dictionary, cards: Array, index: int, edited: Object) -> bool:
	return not popped_body_note(card, cards, index, edited).is_empty()


## The note under a Shader Value card that moves the shared material.
static func shared_material_note(_card: Dictionary) -> String:
	return EventSheetL10n.translate("This material is shared with other nodes. With \"Only this object\" off, they change too.")


static func shared_material_care(card: Dictionary) -> bool:
	return not bool(card.get("only_this", true))
