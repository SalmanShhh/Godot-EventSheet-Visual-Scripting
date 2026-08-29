# EventForge module - Spawn (the spawn sentence, the name it leaves behind, and where it lands)
#
# There is no spawning system here and there is not going to be one. A spawn is three plain lines of
# Godot - instance the scene, add it under a parent, put it somewhere - and this module is those
# three lines said as one sentence, plus the small expressions that answer "where".
#
# THE NAME IS THE POINT. The row asks what to call the new copy, and that name is a real local
# variable in the emitted code:
#
#     var new_enemy = Enemy.instantiate()
#     self.add_child(new_enemy)
#     new_enemy.global_position = $SpawnPoint.global_position
#
# Every following row in the same event can say `new_enemy`, because that is simply what the code
# says. It is also why hand-written spawn code opens as these rows: `var b = X.instantiate()` is a
# row (Make A New Copy Of, below), the add_child beside it is the shipped Add Child row, and the
# placement line is the shipped property row - so an opened file keeps the author's own name for the
# thing, down to the byte.
#
# WHY TWO SPAWN ROWS. Godot refuses add_child while the physics server is flushing queries, which is
# most of what a collision handler is. The second row is the deferred spelling, and it SAYS so in its
# sentence rather than deferring quietly behind the first one's back - a row that changes when a line
# runs has to admit it on the row.
#
# WHY THE PLACEMENT WORDS ARE EXPRESSIONS. "Where" is a value, so each choice is one expression a
# reader can check: a node's own place, a point along a path, a point inside a shape, a point off a
# screen edge. They compose - any of them can go in any field that takes a position - and none of
# them needs this module to be installed to keep working, because each is plain GDScript.
#
# Module contract: see ace_factory.gd - ace_ids/templates are API (compatibility covenant); this file
# only changes where the descriptors are AUTHORED.
@tool
class_name EventForgeSpawnACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

## The one category these rows group under in the picker.
const CATEGORY: String = "Spawn"

## The starting points the "At" field offers as a dropdown while staying a free expression field: the
## spawner's own place first (what the row opens on), then the shapes the placement expressions take.
## An editable suggest list rather than a fixed dropdown, because "where" is an expression and a fixed
## list would be a smaller language than the field really speaks.
const PLACEMENT_STARTERS: Array[String] = [
	"global_position",
	"$SpawnPoint.global_position",
	"Vector2(0, 0)",
]


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── The sentence ───────────────────────────────────────────────────────────────────
	# Three statements, in the order Godot wants them: instance, parent, place. Placement comes
	# AFTER add_child deliberately - global_position only means anything once the node is in a tree,
	# and a row that set it first would quietly land the copy in the wrong place under a moved parent.
	descriptors.append(F.make_descriptor("Core", "SpawnNewCopy", "Spawn A Copy", ACEDescriptor.ACEType.ACTION,
		"var {name} = {scene}.instantiate()\n{parent}.add_child({name})\n{name}.global_position = {at}", "",
		[_scene_param(), _name_param(), _at_param(), _parent_param()],
		CATEGORY, "Spawn a copy of [b]{scene}[/b] as [b]{name}[/b] at {at}, under [i]{parent}[/i]", "Node2D")
		.described("Makes one copy of a scene, adds it under a parent and puts it where you say. The copy gets the name you choose, and every following row in this event can say that name - it is a real variable in the emitted code, not a lookup. Leave At as global_position to spawn where this node is, and Under as self to keep the copy under this one.")
		.featured())
	# The deferred spelling. Godot blocks add_child while the physics server is flushing, which is
	# every body/area callback - so this is the row a collision handler wants. Placement moves BEFORE
	# the parenting here, because the copy is not in a tree yet when the line runs and global_position
	# would have nothing to be global to.
	descriptors.append(F.make_descriptor("Core", "SpawnNewCopyDeferred", "Spawn A Copy Safely", ACEDescriptor.ACEType.ACTION,
		"var {name} = {scene}.instantiate()\n{name}.position = {at}\n{parent}.call_deferred(\"add_child\", {name})", "",
		[_scene_param(), _name_param(), _at_param(), _parent_param()],
		CATEGORY, "Spawn a copy of [b]{scene}[/b] as [b]{name}[/b] at {at}, under [i]{parent}[/i], added on the next idle moment", "Node2D")
		.described("The same spawn, added on the next idle moment instead of right now. Use it inside a collision or body handler: Godot refuses to add a child while the physics server is busy, and this row waits for it to finish rather than erroring. The place is set before the copy is added, so it is a place relative to the parent rather than a world position."))
	# The chip on its own. This is the row a hand-written `var b = Bullet.instantiate()` opens as, so
	# the author's own name for the thing survives the round trip; it is also the row to pick when the
	# copy needs setting up before it joins the tree.
	descriptors.append(F.make_descriptor("Core", "MakeNewCopy", "Make A Copy", ACEDescriptor.ACEType.ACTION,
		"var {name} = {scene}.instantiate()", "",
		[_scene_param(), _name_param()],
		CATEGORY, "Make a copy of [b]{scene}[/b], called [b]{name}[/b]")
		.described("Makes one copy of a scene and gives it a name, without adding it to the scene tree yet. Following rows in this event can say the name to set the copy up, and an Add Child row puts it in the world when it is ready."))

	# ── Where it lands ─────────────────────────────────────────────────────────────────
	# Four answers to "where", each one expression a reader can check on its own, and each usable in
	# any field that takes a position - not only in the spawn rows above.
	descriptors.append(F.make_descriptor("Core", "PlaceAtNode", "Place Of", ACEDescriptor.ACEType.EXPRESSION,
		"{node}.global_position", "",
		[F.make_param("node", "String", "self", "Node", "The node to read the place of - a Marker2D you dropped in the scene, a spawn point, the player.", "scene_node")],
		CATEGORY, "place of [i]{node}[/i]", "Node2D")
		.described("Gives a node's own place in the world. Drop a Marker2D where things should appear and this reads it, so moving the marker moves the spawn without touching the sheet."))
	descriptors.append(F.make_descriptor("Core", "PlaceAlongPath", "Random Place Along Path", ACEDescriptor.ACEType.EXPRESSION,
		"({path}.global_position + {path}.curve.sample_baked(randf() * {path}.curve.get_baked_length()))", "",
		[F.make_param("path", "String", "self", "Path", "The Path2D whose curve to pick a point on.", "scene_node")],
		CATEGORY, "random place along [i]{path}[/i]", "Path2D")
		.described("Gives a random point somewhere along a Path2D's curve. The point is picked by distance travelled rather than by curve segment, so a long straight stretch is exactly as likely as a tight corner."))
	# HOW THIS SAMPLES, said plainly rather than left to the reader: rectangles and circles are
	# sampled from their own measurements in one step - no rejection sampling, no retry loop, so the
	# line costs the same every time it runs. The circle takes the square root of the roll so points
	# do not bunch up in the middle, which is what an even scatter over a disc needs. Any other shape
	# gives the shape's own centre, because guessing at a polygon's inside from one expression would
	# be a loop pretending to be a value.
	descriptors.append(F.make_descriptor("Core", "PlaceInsideShape", "Random Place Inside Shape", ACEDescriptor.ACEType.EXPRESSION,
		"({shape}.global_position + (({shape}.shape as RectangleShape2D).size * Vector2(randf() - 0.5, randf() - 0.5)"\
		+ " if {shape}.shape is RectangleShape2D"\
		+ " else (Vector2.RIGHT.rotated(randf() * TAU) * ({shape}.shape as CircleShape2D).radius * sqrt(randf())"\
		+ " if {shape}.shape is CircleShape2D else Vector2.ZERO)))", "",
		[F.make_param("shape", "String", "self", "Shape", "The CollisionShape2D to scatter inside - the one on the Area2D marking the spawn zone.", "scene_node")],
		CATEGORY, "random place inside [i]{shape}[/i]", "CollisionShape2D")
		.described("Gives a random point inside a collision shape - the Area2D you drew around a spawn zone. Rectangles and circles are measured directly and scattered evenly in one step, with no rejection sampling and no retries; every other shape gives its own centre instead of a guess."))
	descriptors.append(F.make_descriptor("Core", "PlaceAtScreenEdge", "Random Place Off Screen Edge", ACEDescriptor.ACEType.EXPRESSION,
		"(get_viewport().get_canvas_transform().affine_inverse() * (Vector2(randf() * get_viewport_rect().size.x,"\
		+ " -{margin} if randi() % 2 == 0 else get_viewport_rect().size.y + {margin})"\
		+ " if randi() % 2 == 0"\
		+ " else Vector2(-{margin} if randi() % 2 == 0 else get_viewport_rect().size.x + {margin},"\
		+ " randf() * get_viewport_rect().size.y)))", "",
		[F.make_param("margin", "String", "32.0", "Margin", "How far outside the screen edge the point sits, in pixels.", "expression")],
		CATEGORY, "random place off a screen edge (+{margin})", "Node2D")
		.described("Gives a random point just outside one of the four screen edges, in world coordinates - where a wave arrives from. The edge is picked fresh each time the line runs, and the margin keeps the copy out of sight until it moves in."))

	return descriptors


## The scene a spawn makes a copy of. Its value is an expression on purpose: a sheet that declares
## `const Enemy := preload("res://enemy.tscn")` says `Enemy` here and reads as a sentence, while a
## project that builds a path at runtime says `load(path)` in the same field. The default is the
## second spelling because it is the one that stands on its own in any script.
static func _scene_param() -> ACEParam:
	return F.make_param("scene", "String", "load(\"res://enemy.tscn\")", "Scene",
		"The scene to copy - one of this sheet's declared scenes by name, or a load() of a scene path.",
		"expression")


## The name the copy answers to. Plain text, because it becomes an identifier in the emitted code.
static func _name_param() -> ACEParam:
	return F.make_param("name", "String", "new_enemy", "Called",
		"What to call the new copy. Following rows in this event say this name, and it is the variable name the emitted code uses.",
		"")


## Where the copy lands. An expression field with the placement starters offered as suggestions, so
## the commonest answers are one click away without the field stopping being an expression.
static func _at_param() -> ACEParam:
	return F.make_param("at", "String", "global_position", "At",
		"Where the copy lands, as a position. Leave it as global_position to spawn where this node is.",
		"expression", [], PLACEMENT_STARTERS)


## The node the copy is added under. Stated on the row even when it is this one, because a copy that
## quietly ends up somewhere else is the hardest kind of spawn to find later.
static func _parent_param() -> ACEParam:
	return F.make_param("parent", "String", "self", "Under",
		"The node the copy is added under. Leave it as self to add it under this one, or name a layer to keep spawns together.",
		"expression")
