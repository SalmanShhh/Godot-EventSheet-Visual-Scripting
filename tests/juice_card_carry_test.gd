# Godot EventSheets - four small things a juice card owed: the Godot name under a field reads as
# comfortably as the card's own description, the window of "Show as GDScript" does not say its title
# twice and writes the names of the nodes a scene really has, a Spring card draws the bounce it will
# make, and a Light card whose player is freed mid-flare puts the light back.
#
# THE ONE THING THIS FILE IS ABOUT: what a card shows a newcomer is what the game will do. A snippet
# that says `$SpringBehavior` for a node named `Spring` fails the moment it is pasted; a picture of a
# bounce that is not the bounce the Spring node makes teaches the wrong thing; a light left half lit
# after its player went away is a scene that is wrong until it is reopened.
#
# The suite has no scene tree, so the flare is checked through the player's own put-back list; the
# frames were measured on a running tree outside the suite.
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")

const TEST_NAME: String = "juice_card_carry"

const LEARNING: String = "res://addons/eventsheet/editor/inspector/juice_card_learning.gd"
const SCHEMA: String = "res://addons/eventsheet/editor/inspector/feedback_card_schema.gd"
const PICTURE: String = "res://addons/eventsheet/editor/inspector/juice_spring_picture.gd"
const PACK: String = "res://eventsheet_addons/juice/juice_player.gd"
const SPRING: String = "res://eventsheet_addons/spring/spring_behavior.gd"


static func run() -> bool:
	var ok: bool = true
	ok = _small_print_pins() and ok
	ok = _window_pins() and ok
	ok = _node_name_pins() and ok
	ok = _spring_picture_pins() and ok
	ok = _flare_pins() and ok
	return ok


static func _learning() -> GDScript:
	return load(LEARNING) as GDScript


## The Godot name under a field is as large as the card's description and fades the same way.
static func _small_print_pins() -> bool:
	var schema: Dictionary = (load(SCHEMA) as GDScript).call("schema")
	var drawer: EventSheetCardListDrawer = EventSheetCardListDrawer.new({"kind_key": "verb", "schema_dict": schema})
	drawer.set_value([{"verb": "light", "energy_to": 3.0, "seconds": 0.08}])
	drawer._unfolded[0] = true
	drawer._rebuild()
	var labels: Array[Label] = []
	_collect_labels(drawer._list, labels)
	var description: Label = null
	var name_label: Label = null
	for label: Label in labels:
		if label.text.begins_with("Flares a light to a brightness"):
			description = label
		if label.text == "Light2D.energy":
			name_label = label
	var rows: Array = [["the open card shows the Godot name and a description", [name_label != null, description != null], [true, true]]]
	if name_label != null and description != null:
		rows.append(["the small print is the size of the description", name_label.get_theme_font_size("font_size"), description.get_theme_font_size("font_size")])
		rows.append(["and fades the same way", name_label.modulate, description.modulate])
		rows.append(["its colour is not overridden to a pale grey that a light theme cannot read", name_label.has_theme_color_override("font_color"), false])
	drawer.free()
	return SUPPORT.pins(TEST_NAME, rows)


## The window opened by Show as GDScript carries its title once, on the window, never again as a heading.
static func _window_pins() -> bool:
	var host: Node = Node.new()
	var window: Window = _learning().call("show_text", host, "Show as GDScript", "A note.", "var x := 1") as Window
	var labels: Array[Label] = []
	_collect_labels(window, labels)
	var headings: int = 0
	var code_shown: bool = false
	for label: Label in labels:
		if label.text == "Show as GDScript":
			headings += 1
		if label.text == "var x := 1":
			code_shown = true
	var rows: Array = [
		["the window is titled", window.title, "Show as GDScript"],
		["the title is not written again inside it", headings, 0],
		["the code and its note are still there", [code_shown, _has_text(labels, "A note.")], [true, true]],
	]
	host.free()
	return SUPPORT.pins(TEST_NAME, rows)


## A snippet that names a node writes the name that node has in the scene.
static func _node_name_pins() -> bool:
	var learning: GDScript = _learning()
	var hero: Node2D = Node2D.new()
	hero.name = "Hero"
	var player: Node = (load(PACK) as GDScript).new()
	player.name = "JuicePlayer"
	hero.add_child(player)
	var spring: Node = (load(SPRING) as GDScript).new()
	spring.name = "Spring"
	hero.add_child(spring)
	var sprite: Node2D = Node2D.new()
	sprite.name = "Sprite"
	hero.add_child(sprite)
	var bounce: Node = (load(SPRING) as GDScript).new()
	bounce.name = "Bounce"
	sprite.add_child(bounce)
	var alarm: Node = (load(PACK) as GDScript).new()
	alarm.name = "Alarm"
	hero.add_child(alarm)
	var sky: Node = WorldEnvironment.new()
	sky.name = "Sky"
	hero.add_child(sky)
	var rows: Array = [
		["a Spring card on this object names the Spring node that is there",
			learning.call("as_gdscript", {"verb": "spring", "property": "scale", "kick": Vector2(3.0, 3.0)}, player),
			"# Needs a Spring node under this node; it settles the value back to rest.\n$Spring.bump_property(\"scale\", Vector2(3.0, 3.0))"],
		["and one on a child names the Spring node under that child",
			learning.call("as_gdscript", {"verb": "spring", "node": NodePath("../Sprite"), "property": "scale", "kick": Vector2(3.0, 3.0)}, player),
			"# Needs a Spring node under this node; it settles the value back to rest.\n$Sprite/Bounce.bump_property(\"scale\", Vector2(3.0, 3.0))"],
		["a Pause card names the player it pauses",
			learning.call("as_gdscript", {"verb": "pause_player", "player": NodePath("../Alarm"), "mode": "pause"}, player),
			"# Pauses another Juice Player: its walk holds still until it is resumed.\n$Alarm.pause_feedbacks()"],
		["and says resume when it resumes",
			learning.call("as_gdscript", {"verb": "pause_player", "player": NodePath("../Alarm"), "mode": "resume"}, player),
			"# Resumes another Juice Player where it held.\n$Alarm.resume_feedbacks()"],
		["a Play Player card names the player it plays",
			learning.call("as_gdscript", {"verb": "play_player", "player": NodePath("../Alarm"), "amount": 1.0}, player),
			"$Alarm.play(1.0)"],
		["a Scene Look card names the WorldEnvironment the scene has",
			str(learning.call("as_gdscript", {"verb": "scene_look", "property": "glow_intensity", "to": 2.0, "seconds": 0.5, "back_seconds": 0.3}, player)).get_slice("\n", 0),
			"var world: WorldEnvironment = $Sky"],
		["a card with no player to look at keeps the plain name it always wrote",
			learning.call("as_gdscript", {"verb": "play_player", "amount": 1.0}),
			"$OtherPlayer.play(1.0)"],
	]
	hero.free()
	return SUPPORT.pins(TEST_NAME, rows)


## The picture of the bounce a Spring card will make.
static func _spring_picture_pins() -> bool:
	var picture: Script = load(PICTURE) as Script if ResourceLoader.exists(PICTURE) else null
	if picture == null:
		return SUPPORT.pins(TEST_NAME, [["the spring picture is there", false, true]])
	var loose: PackedFloat32Array = picture.call("samples", 0.85, 2.075, 24)
	var tight: PackedFloat32Array = picture.call("samples", 0.999, 2.075, 24)
	var slow: int = _swings(picture.call("samples", 0.3, 1.0, 96))
	var quick: int = _swings(picture.call("samples", 0.3, 4.0, 96))
	var kind: Dictionary = {}
	for entry: Variant in (load(SCHEMA) as GDScript).call("schema").get("kinds", []):
		if str((entry as Dictionary).get("kind", "")) == "spring":
			kind = entry
	var drawn: bool = false
	for field: Variant in kind.get("fields", []):
		drawn = drawn or str((field as Dictionary).get("key", "")) == "spring_shape"
	var line: String = str(picture.call("says", {"damping": 0.85, "frequency": 2.075}))
	return SUPPORT.pins(TEST_NAME, [
		["the picture has as many bars as it was asked for", loose.size(), 24],
		["the kick takes the value away from rest first", loose[0] > 0.0, true],
		["a loose spring swings past rest", _lowest(loose) < 0.0, true],
		["and settles: the last bar is a sliver of the biggest", absf(loose[loose.size() - 1]) < 0.1 * _highest(loose), true],
		["a spring with nearly all its speed taken each second hardly moves", _highest(tight) < _highest(loose), true],
		["more swings a second draws more swings", quick > slow, true],
		["the Spring card carries the picture", drawn, true],
		["a sentence says what the picture shows", line.is_empty(), false],
	])


## A Light card whose player goes away mid-flare puts the light back; one that is only stopped leaves it.
static func _flare_pins() -> bool:
	var rows: Array = []
	var stopped_light: PointLight2D = PointLight2D.new()
	var freed_light: PointLight2D = PointLight2D.new()
	var freed: Node = (load(PACK) as GDScript).new()
	var stopped: Node = (load(PACK) as GDScript).new()
	var has_note: bool = freed.has_method("_note_flare")
	rows.append(["the player keeps a note of a flare that is running", has_note, true])
	if has_note:
		freed_light.energy = 1.0
		freed_light.color = Color.WHITE
		freed.call("_note_flare", freed_light, "energy", "color", 1.0, Color.WHITE)
		freed_light.energy = 2.6
		freed_light.color = Color(1.0, 0.5, 0.1)
		freed._exit_tree()
		rows.append(["a player freed mid-flare puts the brightness back", freed_light.energy, 1.0])
		rows.append(["and the colour", freed_light.color, Color.WHITE])
		stopped_light.energy = 1.0
		stopped.call("_note_flare", stopped_light, "energy", "color", 1.0, Color.WHITE)
		stopped_light.energy = 2.2
		stopped.call("_end_effects")
		stopped._exit_tree()
		rows.append(["a play that was stopped first leaves the light where it got to, as Stop always did", snappedf(stopped_light.energy, 0.001), 2.2])
	stopped_light.free()
	freed_light.free()
	freed.free()
	stopped.free()
	return SUPPORT.pins(TEST_NAME, rows)


static func _swings(samples: PackedFloat32Array) -> int:
	var count: int = 0
	for index: int in range(1, samples.size()):
		if samples[index - 1] * samples[index] < 0.0:
			count += 1
	return count


static func _highest(samples: PackedFloat32Array) -> float:
	var top: float = 0.0
	for value: float in samples:
		top = maxf(top, absf(value))
	return top


static func _lowest(samples: PackedFloat32Array) -> float:
	var low: float = 0.0
	for value: float in samples:
		low = minf(low, value)
	return low


static func _has_text(labels: Array[Label], text: String) -> bool:
	for label: Label in labels:
		if label.text == text:
			return true
	return false


static func _collect_labels(node: Node, into: Array[Label]) -> void:
	if node is Label:
		into.append(node as Label)
	for child: Node in node.get_children():
		_collect_labels(child, into)
