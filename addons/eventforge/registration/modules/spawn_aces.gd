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
# THE SAME SENTENCE IN THREE DIMENSIONS. A 3D game spawns for exactly the same reasons and in
# exactly the same order, so the twins below are the 2D pair with a Node3D host and Vector3 answers
# to "where" - not a second spawning idea. Where the emitted line is identical in both dimensions
# (`{node}.global_position` is a Vector2 on a Node2D and a Vector3 on a Node3D) the twin exists so
# that the picker offers it on a 3D host at all, and it is kept OUT of the reverse index so the two
# rows never split one spelling between them; the 2D row shipped first and keeps the reading, and
# the bytes are the same sentence either way.
#
# AND ONE THING IS DELIBERATELY MISSING: there is no 3D Random Place Off Screen Edge. In 2D a screen
# edge is a rectangle in the same plane the game is played in, which is why that row can be one
# honest expression. In 3D "just off screen" is a question about a camera's frustum - which camera,
# how far along its forward axis, and at what depth the answer is even meant to sit - and every
# one-line answer to it is a guess that looks right until the camera moves. Nothing is proposed in
# its place: a wave that must arrive from off-camera is spawned at a Marker3D or inside a box the
# level designer drew, which is what Place Of and Random Place Inside Box already say.
#
# AND EVERY ONE OF THEM ANSWERS IN THE WORLD'S FRAME. A curve is drawn in its Path2D's own space and
# a shape is measured in its CollisionShape2D's, so the two that sample a local point hand it back
# through `to_global` rather than adding it to `global_position`. Adding is right only while nothing
# above the node is rotated or scaled: under a parent turned a quarter turn, a point fifty pixels
# along a curve came out fifty pixels to the RIGHT of the path instead of below it, and a rotated
# collision shape scattered inside an upright box of the same size rather than inside the one drawn.
# `to_global` is the one-token spelling of the transform that was missing.
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
## The last entry is longer than the three above it on purpose: a free spot is a QUESTION rather
## than a place, so the starter has to carry the four things the question is about - what to roll
## inside, what is being put there, what it has to keep away from, and how far. It is a starting
## point like the others and is edited in the field, and Spawn A Copy In A Free Spot is the row that
## also knows what to do when the answer is nothing.
const PLACEMENT_STARTERS: Array[String] = [
	"global_position",
	"$SpawnPoint.global_position",
	"Vector2(0, 0)",
	"FreeSpot.in_2d($SpawnZone, load(\"res://enemy.tscn\"), [\"walls\"], 32.0, 24)",
]

## The same list for a Node3D host. Kept beside its 2D twin rather than derived from it, because the
## third entry is the only one that differs and a derived list would have to know that.
const PLACEMENT_STARTERS_3D: Array[String] = [
	"global_position",
	"$SpawnPoint.global_position",
	"Vector3(0, 0, 0)",
	"FreeSpot.in_3d($SpawnBox, load(\"res://enemy.tscn\"), [\"walls\"], 1.0, 24)",
]

## The runtime file the free-spot word calls, by the name emitted code says. One spelling, named
## here, because two rows and a starter all write it.
const FREE_SPOT_CALL: String = "FreeSpot"

## The signal a spawn row raises when the arena had no room in it. A PLAIN signal the sheet declares
## for itself, which is why it is a name here and not a mechanism: the row emits it and On Spawn
## Skipped connects to it, exactly as any other signal a sheet declares.
const SKIPPED_SIGNAL: String = "spawn_skipped"

## The five shapes a formation puts its copies in, as the WORD the dropdown inserts. The word is the
## choice: the row's template carries one branch per shape and keeps the branch whose word the row
## holds, so these strings are frozen exactly as the ace_id is - a renamed word would silently emit
## nothing where the branch used to be.
const FORMATION_RING: String = "ring"
const FORMATION_ARC: String = "arc"
const FORMATION_LINE: String = "line"
const FORMATION_GRID: String = "grid"
const FORMATION_SHAPE: String = "shape"
const FORMATION_BOX: String = "box"

## The order the branches are written in, and the order the dropdown lists them. The 2D row's fifth
## shape scatters inside a collision shape and the 3D row's inside a box, which is the one place the
## twins hold different words - everything else about them is the same sentence.
const FORMATION_ORDER: Array[String] = [FORMATION_RING, FORMATION_ARC, FORMATION_LINE, FORMATION_GRID,
	FORMATION_SHAPE]
const FORMATION_ORDER_3D: Array[String] = [FORMATION_RING, FORMATION_ARC, FORMATION_LINE,
	FORMATION_GRID, FORMATION_BOX]

## The dropdown as a reader meets it: the word that is inserted, and the sentence that says what it
## puts where. One list per dimension, because the last entry names a different kind of node.
const FORMATION_CHOICES: Array = [
	{"key": FORMATION_RING, "label": "ring - evenly all the way around a point"},
	{"key": FORMATION_ARC, "label": "arc - part of a ring, from an angle"},
	{"key": FORMATION_LINE, "label": "line - evenly from one point to another"},
	{"key": FORMATION_GRID, "label": "grid - rows and columns out from a corner"},
	{"key": FORMATION_SHAPE, "label": "inside a shape - scattered in a collision shape"},
]
const FORMATION_CHOICES_3D: Array = [
	{"key": FORMATION_RING, "label": "ring - evenly all the way around a point"},
	{"key": FORMATION_ARC, "label": "arc - part of a ring, from an angle"},
	{"key": FORMATION_LINE, "label": "line - evenly from one point to another"},
	{"key": FORMATION_GRID, "label": "grid - rows and columns out from a corner"},
	{"key": FORMATION_BOX, "label": "inside a box - scattered in a box you drew"},
]

## When the copies join the tree, as the word that picks the branch. The same two answers the shipped
## Spawn A Copy pair spells as two rows - said here as one field, because a formation is already one
## row with a shape in it and a second row per timing would be ten rows for one sentence.
const WHEN_NOW: String = "now"
const WHEN_LATER: String = "later"
const WHEN_CHOICES: Array = [
	{"key": WHEN_NOW, "label": "now"},
	{"key": WHEN_LATER, "label": "on the next idle moment"},
]

## Which way a spawned copy is pointed, as the word that picks the branch. `mouse` is 2D only: a
## screen point is a point in the plane the game is played in, and in three dimensions the same
## question is about a camera's ray, which is a different sentence and not this row's.
const FACE_SPAWNER: String = "spawner"
const FACE_NODE: String = "node"
const FACE_MOUSE: String = "mouse"
const FACE_ANGLE: String = "angle"

const FACING_ORDER: Array[String] = [FACE_SPAWNER, FACE_NODE, FACE_MOUSE, FACE_ANGLE]
const FACING_ORDER_3D: Array[String] = [FACE_SPAWNER, FACE_NODE, FACE_ANGLE]

const FACING_CHOICES: Array = [
	{"key": FACE_SPAWNER, "label": "the same way this node faces"},
	{"key": FACE_NODE, "label": "toward a node"},
	{"key": FACE_MOUSE, "label": "toward the mouse"},
	{"key": FACE_ANGLE, "label": "at an angle you say"},
]
const FACING_CHOICES_3D: Array = [
	{"key": FACE_SPAWNER, "label": "the same way this node faces"},
	{"key": FACE_NODE, "label": "toward a node"},
	{"key": FACE_ANGLE, "label": "at an angle you say"},
]

## WHERE A SPAWNED COPY'S SPEED IS WRITTEN, which is a fact about the scene rather than about the
## row: a character body is driven by `velocity`, a rigid body is thrown with `linear_velocity`, and
## a scene wearing the Bullet behaviour flies along its own facing at that behaviour's `speed`. The
## field is a dropdown of those three and the dialog reads the scene file to say which one it is
## (EventSheetSceneVerbs.launch_note), because the answer is written in the `.tscn` and guessing it
## would put a line in somebody's game that silently does nothing.
const MOVE_VELOCITY: String = "velocity"
const MOVE_LINEAR: String = "linear_velocity"
const MOVE_BULLET: String = "bullet"

const MOVE_ORDER: Array[String] = [MOVE_VELOCITY, MOVE_LINEAR, MOVE_BULLET]

const MOVE_CHOICES: Array = [
	{"key": MOVE_VELOCITY, "label": "velocity - a CharacterBody"},
	{"key": MOVE_LINEAR, "label": "linear_velocity - a RigidBody"},
	{"key": MOVE_BULLET, "label": "the Bullet behaviour's own speed"},
]

## The behaviour child a bullet scene wears, by the name the Bullet pack gives it. Named here because
## the template writes it and the dialog's note reads the scene for it, and two spellings of one node
## name is how the note and the line stop agreeing.
const BULLET_CHILD: String = "BulletBehavior"
const BULLET_CHILD_3D: String = "Bullet3DBehavior"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── The sentence ───────────────────────────────────────────────────────────────────
	# Three statements, in the order Godot wants them: instance, parent, place. Placement comes
	# AFTER add_child deliberately - global_position only means anything once the node is in a tree,
	# and a row that set it first would quietly land the copy in the wrong place under a moved parent.
	descriptors.append(F.act("SpawnNewCopy", "Spawn A Copy", "var {name} = {scene}.instantiate()\n{parent}.add_child({name})\n{name}.global_position = {at}", CATEGORY, "Spawn a copy of [b]{scene}[/b] as [b]{name}[/b] at {at}, under [i]{parent}[/i]", "Makes one copy of a scene, adds it under a parent and puts it where you say. The copy gets the name you choose, and every following row in this event can say that name - it is a real variable in the emitted code, not a lookup. Leave At as global_position to spawn where this node is, and Under as self to keep the copy under this one.", "Node2D").param_built(_scene_param()).param_built(_name_param()).param_built(_at_param()).param_built(_parent_param()).featured())
	# The deferred spelling. Godot blocks add_child while the physics server is flushing, which is
	# every body/area callback - so this is the row a collision handler wants. Placement moves BEFORE
	# the parenting here, because the copy is not in a tree yet when the line runs and global_position
	# would have nothing to be global to.
	descriptors.append(F.act("SpawnNewCopyDeferred", "Spawn A Copy Safely", "var {name} = {scene}.instantiate()\n{name}.position = {at}\n{parent}.call_deferred(\"add_child\", {name})", CATEGORY, "Spawn a copy of [b]{scene}[/b] as [b]{name}[/b] at {at}, under [i]{parent}[/i], added on the next idle moment", "The same spawn, added on the next idle moment instead of right now. Use it inside a collision or body handler: Godot refuses to add a child while the physics server is busy, and this row waits for it to finish rather than erroring. The place is set before the copy is added, so it is a place relative to the parent rather than a world position.", "Node2D").param_built(_scene_param()).param_built(_name_param()).param_built(_at_param()).param_built(_parent_param()))
	# The chip on its own. This is the row a hand-written `var b = Bullet.instantiate()` opens as, so
	# the author's own name for the thing survives the round trip; it is also the row to pick when the
	# copy needs setting up before it joins the tree.
	descriptors.append(F.act("MakeNewCopy", "Make A Copy", "var {name} = {scene}.instantiate()", CATEGORY, "Make a copy of [b]{scene}[/b], called [b]{name}[/b]", "Makes one copy of a scene and gives it a name, without adding it to the scene tree yet. Following rows in this event can say the name to set the copy up, and an Add Child row puts it in the world when it is ready.").param_built(_scene_param()).param_built(_name_param()))

	# ── Where it lands ─────────────────────────────────────────────────────────────────
	# Four answers to "where", each one expression a reader can check on its own, and each usable in
	# any field that takes a position - not only in the spawn rows above.
	descriptors.append(F.expr("PlaceAtNode", "Place Of", "{node}.global_position", CATEGORY, "place of [i]{node}[/i]", "Gives a node's own place in the world. Drop a Marker2D where things should appear and this reads it, so moving the marker moves the spawn without touching the sheet.", "Node2D").param("node", "self", "Node", "The node to read the place of - a Marker2D you dropped in the scene, a spawn point, the player.", "scene_node"))
	descriptors.append(F.expr("PlaceAlongPath", "Random Place Along Path", "{path}.to_global({path}.curve.sample_baked(randf() * {path}.curve.get_baked_length()))", CATEGORY, "random place along [i]{path}[/i]", "Gives a random point somewhere along a Path2D's curve. The point is picked by distance travelled rather than by curve segment, so a long straight stretch is exactly as likely as a tight corner. A curve is drawn in the path's own space, so the point is handed back through to_global and comes out where the curve really is, even under a rotated or scaled parent.", "Path2D").param("path", "self", "Path", "The Path2D whose curve to pick a point on. Draw the curve first: an empty one has no length, and Godot prints an error every time the line is evaluated.", "scene_node"))
	# HOW THIS SAMPLES, said plainly rather than left to the reader: rectangles and circles are
	# sampled from their own measurements in one step - no rejection sampling, no retry loop, so the
	# line costs the same every time it runs. The circle takes the square root of the roll so points
	# do not bunch up in the middle, which is what an even scatter over a disc needs. Any other shape
	# gives the shape's own centre, because guessing at a polygon's inside from one expression would
	# be a loop pretending to be a value.
	descriptors.append(F.expr("PlaceInsideShape", "Random Place Inside Shape", inside_shape_expression("{shape}"), CATEGORY, "random place inside [i]{shape}[/i]", "Gives a random point inside a collision shape - the Area2D you drew around a spawn zone. Rectangles and circles are measured directly and scattered evenly in one step, with no rejection sampling and no retries; every other shape gives its own centre instead of a guess. The measurement is in the shape's own space and is handed back through to_global, so a rotated or scaled shape scatters inside the box you drew rather than inside an upright one of the same size.", "CollisionShape2D").param("shape", "self", "Shape", "The CollisionShape2D to scatter inside - the one on the Area2D marking the spawn zone.", "scene_node"))
	descriptors.append(F.expr("PlaceAtScreenEdge", "Random Place Off Screen Edge", "(get_viewport().get_canvas_transform().affine_inverse() * (Vector2(randf() * get_viewport_rect().size.x," + " -{margin} if randi() % 2 == 0 else get_viewport_rect().size.y + {margin})" + " if randi() % 2 == 0" + " else Vector2(-{margin} if randi() % 2 == 0 else get_viewport_rect().size.x + {margin}," + " randf() * get_viewport_rect().size.y)))", CATEGORY, "random place off a screen edge (+{margin})", "Gives a random point just outside one of the four screen edges, in world coordinates - where a wave arrives from. The edge is picked fresh each time the line runs, and the margin keeps the copy out of sight until it moves in.", "Node2D").param("margin", "32.0", "Margin", "How far outside the screen edge the point sits, in pixels.", "expression"))

	# ── The same sentence, in three dimensions ─────────────────────────────────────────
	# Same three statements, same order, same reasons: instance, parent, place - and the deferred
	# twin still places BEFORE it parents, because a copy that is not in a tree yet has nothing for a
	# global position to be global to. The only differences are the host the picker files them under
	# and the shape of the value the At field holds.
	descriptors.append(F.act("SpawnNewCopy3D", "Spawn A Copy (3D)", "var {name} = {scene}.instantiate()\n{parent}.add_child({name})\n{name}.global_position = {at}", CATEGORY, "Spawn a copy of [b]{scene}[/b] as [b]{name}[/b] at {at}, under [i]{parent}[/i]", "Makes one copy of a scene, adds it under a parent and puts it where you say, in three dimensions. The copy gets the name you choose, and every following row in this event can say that name - it is a real variable in the emitted code, not a lookup. Leave At as global_position to spawn where this node is, and Under as self to keep the copy under this one.", "Node3D").param_built(_scene_param()).param_built(_name_param()).param_built(_at_param_3d()).param_built(_parent_param()).featured())
	descriptors.append(F.act("SpawnNewCopyDeferred3D", "Spawn A Copy Safely (3D)", "var {name} = {scene}.instantiate()\n{name}.position = {at}\n{parent}.call_deferred(\"add_child\", {name})", CATEGORY, "Spawn a copy of [b]{scene}[/b] as [b]{name}[/b] at {at}, under [i]{parent}[/i], added on the next idle moment", "The same 3D spawn, added on the next idle moment instead of right now. Use it inside a collision or body handler: Godot refuses to add a child while the physics server is busy, and this row waits for it to finish rather than erroring. The place is set before the copy is added, so it is a place relative to the parent rather than a world position.", "Node3D").param_built(_scene_param()).param_built(_name_param()).param_built(_at_param_3d()).param_built(_parent_param()))

	# ── Where it lands, in three dimensions ────────────────────────────────────────────
	# The 3D answers to "where". Each is one expression a reader can check, each usable in any field
	# that takes a position, and none of them needs this module installed to keep working.
	descriptors.append(F.expr("PlaceAtNode3D", "Place Of (3D)", "{node}.global_position", CATEGORY, "place of [i]{node}[/i]", "Gives a node's own place in the world, as a Vector3. Drop a Marker3D where things should appear and this reads it, so moving the marker moves the spawn without touching the sheet. It writes the same line its 2D twin writes, because global_position is the node's own word in both dimensions - this row exists so the 3D page offers it, and the reading of that line stays the 2D row's.", "Node3D").param("node", "self", "Node", "The node to read the place of - a Marker3D you dropped in the scene, a spawn point, the player.", "scene_node"))
	# HOW THE BOX IS SAMPLED, said plainly: the box's own measurements in one step - no rejection
	# sampling and no retry loop, so the line costs the same every time it runs. A box is measured in
	# its own space and handed back through to_global, for the same reason its 2D twin is: adding a
	# local point to a global one is right only while nothing above the node is rotated or scaled.
	#
	# AND IT READS TWO KINDS OF BOX, because a level is drawn with both: the CollisionShape3D holding
	# a BoxShape3D that marks an Area3D spawn zone, and the CSGBox3D somebody blocked the room out
	# with. The casts are what let one expression ask which it is - a node reached by path is a plain
	# Node until something says otherwise, and GDScript will not read `size` off one that has not.
	descriptors.append(F.expr("PlaceInsideBox3D", "Random Place Inside Box", inside_box_expression("{box}"), CATEGORY, "random place inside [i]{box}[/i]", "Gives a random point inside a box - the Area3D you drew around a spawn zone, or a CSG box you blocked the space out with. The box is measured directly and scattered through evenly in one step, with no rejection sampling and no retries. The measurement is in the box's own space and is handed back through to_global, so a rotated or scaled box scatters inside the box you drew rather than inside an upright one of the same size.", "Node3D").param("box", "$SpawnBox", "Box", "The box to scatter inside - a CollisionShape3D holding a BoxShape3D (the one on the Area3D marking the spawn zone), or a CSGBox3D you blocked the space out with.", "scene_node"))
	# THE CORRECTION, one dimension up. The 2D disc takes the SQUARE root of the roll so points do
	# not bunch up in the middle; a solid ball needs the CUBE root for the same reason and by the same
	# argument - the volume inside a radius grows as its cube, so the radius has to be pulled back by
	# the cube root for the scatter to be even. The direction is three normal draws normalised, which
	# is the one spelling that is evenly spread over a sphere without an angle-by-angle construction
	# (picking two angles at random bunches points at the poles).
	descriptors.append(F.expr("PlaceInsideSphere3D", "Random Place Inside Sphere", "({ball} as Node3D).to_global(Vector3(randfn(0.0, 1.0), randfn(0.0, 1.0), randfn(0.0, 1.0)).normalized()" + " * (({ball} as CollisionShape3D).shape as SphereShape3D).radius * pow(randf(), 1.0 / 3.0))", CATEGORY, "random place inside [i]{ball}[/i]", "Gives a random point inside a sphere, spread evenly through it rather than bunched in the middle: the radius is pulled back by the cube root of the roll, which is what an even scatter through a volume needs - the same correction the 2D disc makes with a square root, one dimension up. The point is measured in the sphere's own space and handed back through to_global.", "Node3D").param("ball", "$SpawnBall", "Sphere", "The sphere to scatter inside - a CollisionShape3D holding a SphereShape3D.", "scene_node"))
	descriptors.append(F.expr("PlaceAroundNode3D", "Random Place Around (3D)", "{node}.global_position + Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * {radius}", CATEGORY, "random place [b]{radius}[/b] around [i]{node}[/i]", "Gives a random point on a ring around a node, at the height that node is standing at - an enemy arriving from any direction, a pickup dropped nearby. The ring lies on the ground plane, so the point is level with the node rather than above or below it; add to its Y yourself when you want it dropped in from above.", "Node3D").param("node", "self", "Around", "The node to spawn around - the player, a totem, a spawner. Its own place is the centre of the ring.", "scene_node").param("radius", "5.0", "Radius", "How far out from that node the point sits, in metres. Every point is exactly this far out - it is a ring, not a filled circle.", "expression"))

	# ── Many copies at once, in a shape ────────────────────────────────────────────────
	# A wave, a ring of orbiters, a firing pattern, a row of crates: all of them are the same three
	# statements the plain spawn row writes, said N times with a different place each time. So this is
	# that row inside a `for`, and the only thing the formation word changes is the ONE expression
	# that answers "where does copy number i land" - which is why five shapes are one row rather than
	# five, and why each shape is still a place a reader can check on its own.
	#
	# EVERY COPY JOINS THE GROUP, with no way to turn it off, because a formation nobody can address
	# afterwards is a formation nobody can do anything with: the row underneath says For Each In Group
	# and has the whole wave. It is joined with Godot's persistent flag for the reason the crowd rows
	# state - a group added without it vanishes the moment the branch is packed into a scene.
	#
	# THE SCENE IS READ ONCE, above the loop. `load()` in the field would otherwise be a lookup per
	# copy, and the local is also what lets the run be recognised again when it is read back.
	descriptors.append(F.act("SpawnFormation", "Spawn In A Formation", formation_template(formation_places(), FORMATION_ORDER), CATEGORY, "Spawn [b]{count}[/b] copies of [b]{scene}[/b] in a [b]{formation}[/b]", "Spawns several copies at once and puts each one somewhere in a shape you pick - a ring, an arc, a line, a grid, or scattered inside a collision shape. Every copy joins the crowd you name, so the row underneath can address the whole formation with For Each In Group. The fields a shape does not use are left out of the code it writes: a ring reads Around and Size, an arc adds Start Angle and Sweep, a line reads Around and To, a grid reads Around, Size and Across, and scattering reads Inside.", "Node2D").param_built(_scene_param()).param_built(_name_param()).param_choice("formation", FORMATION_RING, "Formation", "The shape the copies land in. Each one reads a different handful of the fields below, and writes only the ones it reads.", FORMATION_CHOICES).param_built(_count_param()).param_built(_around_param(PLACEMENT_STARTERS)).param_built(_inside_param("$SpawnZone", "CollisionShape2D holding a RectangleShape2D or a CircleShape2D - the one on the Area2D marking the spawn zone")).param_built(_size_param()).param_built(_to_param("global_position + Vector2(200, 0)")).param_built(_start_param()).param_built(_sweep_param()).param_built(_across_param()).param_built(_crowd_param()).param_built(_parent_param()).param_choice("when", WHEN_NOW, "Added", "When the copies join the tree. Pick the next idle moment inside a collision or body handler: Godot refuses to add a child while the physics server is busy.", WHEN_CHOICES))

	# ── A copy that is pointed somewhere and already moving ────────────────────────────
	# The frozen Spawn A Copy says where a copy lands and stops there, which is the whole answer for a
	# crate and half of it for a bullet. This is the other half, beside it rather than inside it: the
	# same three statements, then the copy is turned to face something and given a speed along that
	# facing.
	#
	# THE VELOCITY IS WRITTEN WHERE THE SCENE KEEPS IT, and the scene decides that, not this row: a
	# character body is driven by `velocity`, a rigid body is thrown with `linear_velocity`, and a
	# scene wearing the Bullet behaviour flies along its own facing at that behaviour's `speed`. The
	# field is a dropdown of the three, and the dialog reads the scene file to say which one it found.
	descriptors.append(F.act("SpawnFacingAndMoving", "Spawn A Copy, Facing And Moving", launched_template(facing_lines(), "Vector2.from_angle({name}.rotation)", move_lines(BULLET_CHILD), FACING_ORDER), CATEGORY, "Spawn a copy of [b]{scene}[/b] as [b]{name}[/b], facing [b]{facing}[/b], moving at [b]{speed}[/b]", "Spawns one copy the way Spawn A Copy does, then turns it to face something and gives it a speed along that facing - a bullet leaving a barrel, a spark thrown off a wheel, an enemy charging in. Where the speed is written depends on what the scene is: velocity for a character body, linear_velocity for a rigid body, or the Bullet behaviour's own speed for a scene wearing it. The dialog reads the scene file and says which one it found.", "Node2D").param_built(_scene_param()).param_built(_name_param("new_bullet")).param_built(_at_param()).param_choice("facing", FACE_SPAWNER, "Facing", "Which way the copy is turned before it is launched. Toward A Node reads the Toward field; At An Angle reads the Angle field.", FACING_CHOICES).param_built(_toward_param()).param_built(_angle_param()).param_built(_speed_param("400.0", "How fast the copy travels along its facing, in pixels per second.")).param_built(_carry_param("velocity")).param_choice("moves", MOVE_VELOCITY, "Moves By", "Where the copy's speed is written. It is a fact about the scene, not about this row - the dialog reads the scene file and says which of the three it is.", MOVE_CHOICES).param_built(_parent_param()))

	# ── The same two, in three dimensions ──────────────────────────────────────────────
	# Same shapes, same order, same reasons. The two differences are the ones the dimension really
	# makes: the fifth formation scatters inside a box rather than inside a 2D collision shape, and
	# there is no "toward the mouse" - a screen point is a ray in three dimensions, which is a
	# different question and not this row's to answer with one expression.
	descriptors.append(F.act("SpawnFormation3D", "Spawn In A Formation (3D)", formation_template(formation_places_3d(), FORMATION_ORDER_3D), CATEGORY, "Spawn [b]{count}[/b] copies of [b]{scene}[/b] in a [b]{formation}[/b]", "Spawns several copies at once and puts each one somewhere in a shape you pick, in three dimensions - a ring, an arc, a line, a grid on the ground, or scattered inside a box. Every copy joins the crowd you name, so the row underneath can address the whole formation with For Each In Group. The ring, the arc and the grid all lie on the ground plane, level with the point you spawn around, and scattering reads Inside rather than Around.", "Node3D").param_built(_scene_param()).param_built(_name_param()).param_choice("formation", FORMATION_RING, "Formation", "The shape the copies land in. Each one reads a different handful of the fields below, and writes only the ones it reads.", FORMATION_CHOICES_3D).param_built(_count_param()).param_built(_around_param(PLACEMENT_STARTERS_3D)).param_built(_inside_param("$SpawnBox", "CollisionShape3D holding a BoxShape3D, or a CSGBox3D you blocked the space out with")).param_built(_size_param("5.0")).param_built(_to_param("global_position + Vector3(10, 0, 0)")).param_built(_start_param()).param_built(_sweep_param()).param_built(_across_param()).param_built(_crowd_param()).param_built(_parent_param()).param_choice("when", WHEN_NOW, "Added", "When the copies join the tree. Pick the next idle moment inside a collision or body handler: Godot refuses to add a child while the physics server is busy.", WHEN_CHOICES))
	descriptors.append(F.act("SpawnFacingAndMoving3D", "Spawn A Copy, Facing And Moving (3D)", launched_template(facing_lines_3d(), "-{name}.global_transform.basis.z", move_lines(BULLET_CHILD_3D), FACING_ORDER_3D), CATEGORY, "Spawn a copy of [b]{scene}[/b] as [b]{name}[/b], facing [b]{facing}[/b], moving at [b]{speed}[/b]", "Spawns one copy the way Spawn A Copy (3D) does, then turns it to face something and gives it a speed along that facing. Forward in three dimensions is the copy's own -Z, which is what Godot means by forward everywhere else, so Toward A Node is a plain look_at. Where the speed is written depends on what the scene is: velocity for a character body, linear_velocity for a rigid body, or the Bullet behaviour's own speed for a scene wearing it.", "Node3D").param_built(_scene_param()).param_built(_name_param("new_bullet")).param_built(_at_param_3d()).param_choice("facing", FACE_SPAWNER, "Facing", "Which way the copy is turned before it is launched. Toward A Node reads the Toward field and is a look_at, so the node has to be somewhere other than where the copy landed; At An Angle turns it around the up axis.", FACING_CHOICES_3D).param_built(_toward_param()).param_built(_angle_param()).param_built(_speed_param("12.0", "How fast the copy travels along its facing, in metres per second.")).param_built(_carry_param("velocity")).param_choice("moves", MOVE_VELOCITY, "Moves By", "Where the copy's speed is written. It is a fact about the scene, not about this row - the dialog reads the scene file and says which of the three it is.", MOVE_CHOICES).param_built(_parent_param()))

	# ── A copy of this very scene ──────────────────────────────────────────────────────
	# The safe spawn with the scene slot answered by the node's OWN scene file. `scene_file_path` is
	# a property Godot fills in for anything that came out of a `.tscn`, so there is nothing to pick
	# and nothing to keep in step: a boss that splits, a blob that divides, a firework that throws
	# smaller fireworks. Deferred by default because the moment a thing copies itself is nearly
	# always a hit, and a hit is a physics callback.
	descriptors.append(F.act("SpawnCopyOfSelf", "Spawn A Copy Of Myself", self_copy_template(), CATEGORY, "Spawn a copy of [b]myself[/b] as [b]{name}[/b] at {at}, under [i]{parent}[/i], added on the next idle moment", "Makes one more copy of the scene THIS node came from, and puts it where you say. Nothing has to name the scene: the node knows which file it was built from, so a scene renamed or moved keeps working. The copy is added on the next idle moment, which is what makes the row safe inside the collision handler a splitting boss usually lives in. A node that was built in code rather than from a scene file has no file to copy, and the Doctor says so on the row.", "Node2D").param_built(_name_param("new_copy")).param_built(_at_param()).param_built(_parent_param()).featured())
	descriptors.append(F.act("SpawnCopyOfSelf3D", "Spawn A Copy Of Myself (3D)", self_copy_template(), CATEGORY, "Spawn a copy of [b]myself[/b] as [b]{name}[/b] at {at}, under [i]{parent}[/i], added on the next idle moment", "The same row on a 3D node: one more copy of the scene this node came from, added on the next idle moment. The line it writes is the same line its 2D twin writes, because scene_file_path and position are the node's own words in both dimensions - the twin exists so the picker offers the row on a 3D host at all.", "Node3D").param_built(_name_param("new_copy")).param_built(_at_param_3d()).param_built(_parent_param()))

	# ── Somewhere nothing is standing ──────────────────────────────────────────────────
	# "Where" with a question in it. The other placement words measure something and answer; this one
	# rolls a point, asks whether the copy would fit there, and rolls again - so it is a call rather
	# than a line, and it can answer NOTHING, which no other placement word can. It carries no host
	# class for a reason worth writing down: the cross-node prefix is added to any template whose
	# lines are all member operations, and this one opens on the runtime file's own name, so a host
	# would have the picker rewrite it into somebody else's node.
	descriptors.append(F.expr("PlaceInFreeSpot", "Free Spot In", "%s.in_2d({inside}, {scene}, {clear_of}, {gap}, {tries})" % FREE_SPOT_CALL, CATEGORY, "a free spot in [i]{inside}[/i], clear of {clear_of}, {gap} px apart", "Gives a point inside a shape you drew that nothing in the named groups is standing in and no other copy of the same scene is within the gap of - where to put the next crate, the next mine, the next enemy in a room that is filling up. Clear is asked as a real physics test, with the spawned scene's OWN collision shape put at the point, so a wall is a wall whatever drew it; a group whose members carry no shape at all is answered by distance instead. A full arena answers NOTHING, and Spawn A Copy In A Free Spot is the row that knows what to do about that.").param_built(_free_inside_param("$SpawnZone", "CollisionShape2D holding a RectangleShape2D or a CircleShape2D, the Area2D around it, or a Control's own rectangle")).param_built(_scene_param()).param_built(_clear_of_param()).param_built(_gap_param("32.0", "pixels")).param_built(_tries_param()))
	descriptors.append(F.expr("PlaceInFreeSpot3D", "Free Spot In (3D)", "%s.in_3d({inside}, {scene}, {clear_of}, {gap}, {tries})" % FREE_SPOT_CALL, CATEGORY, "a free spot in [i]{inside}[/i], clear of {clear_of}, {gap} m apart", "The same question in three dimensions, with the gap measured in metres: a point inside a box or a sphere you drew that nothing in the named groups is standing in and no other copy of the same scene is within the gap of. A full space answers nothing.").param_built(_free_inside_param("$SpawnBox", "CollisionShape3D holding a BoxShape3D or a SphereShape3D, or the Area3D around it")).param_built(_scene_param()).param_built(_clear_of_param()).param_built(_gap_param("1.0", "metres")).param_built(_tries_param()))
	# And the row that spends the answer. It is a spawn with an `if` in it, because "nothing" is a
	# real answer to "where" and a row that wrote it into a position would put the copy at the origin.
	descriptors.append(F.act("SpawnInFreeSpot", "Spawn A Copy In A Free Spot", free_spot_spawn_template("in_2d"), CATEGORY, "Spawn a copy of [b]{scene}[/b] as [b]{name}[/b] in a free spot in [i]{inside}[/i], under [i]{parent}[/i]", "Spawns one copy somewhere inside a shape you drew that nothing is already standing in - and spawns NOTHING when there is nowhere left, rather than stacking copies on top of each other. When it finds no room it raises this node's spawn_skipped signal with the scene it could not place, which On Spawn Skipped listens to: add a signal block saying spawn_skipped(scene) and the row underneath can end the wave, play a full-up sound, or make more room. The copy is added on the next idle moment, so the row is safe inside a collision handler.", "Node2D").param_built(_scene_param()).param_built(_name_param()).param_built(_free_inside_param("$SpawnZone", "CollisionShape2D holding a RectangleShape2D or a CircleShape2D, the Area2D around it, or a Control's own rectangle")).param_built(_clear_of_param()).param_built(_gap_param("32.0", "pixels")).param_built(_tries_param()).param_built(_parent_param()).featured())
	descriptors.append(F.act("SpawnInFreeSpot3D", "Spawn A Copy In A Free Spot (3D)", free_spot_spawn_template("in_3d"), CATEGORY, "Spawn a copy of [b]{scene}[/b] as [b]{name}[/b] in a free spot in [i]{inside}[/i], under [i]{parent}[/i]", "The same row in three dimensions, with the gap measured in metres: one copy somewhere inside a box or a sphere you drew that nothing is already standing in, and nothing at all when there is nowhere left. A skipped spawn raises this node's spawn_skipped signal with the scene it could not place.", "Node3D").param_built(_scene_param()).param_built(_name_param()).param_built(_free_inside_param("$SpawnBox", "CollisionShape3D holding a BoxShape3D or a SphereShape3D, or the Area3D around it")).param_built(_clear_of_param()).param_built(_gap_param("1.0", "metres")).param_built(_tries_param()).param_built(_parent_param()))
	# The other half of the skip, and a plain signal on purpose: the sheet declares it, the spawn row
	# raises it, and this connects to it. Nothing here is special machinery.
	descriptors.append(F.trig("OnSpawnSkipped", "On Spawn Skipped", SKIPPED_SIGNAL, CATEGORY, "On a spawn skipped", "Runs when a Spawn A Copy In A Free Spot row found nowhere to put the copy, and hands over the scene it could not place. The signal is one this sheet declares for itself - add a signal block saying spawn_skipped(scene) and both halves are ordinary Godot - so a full arena becomes something the game can answer: stop the wave, say the room is packed, or make more room.", "Node"))

	return descriptors


## The three statements a copy of THIS node's own scene is: read the file the node came out of,
## place the copy relative to the parent it is about to join, and hand the parenting to the next
## idle moment. The same three the shipped safe spawn writes, with `scene_file_path` where its scene
## field goes - which is why an opened file holding this shape reads back as this row.
static func self_copy_template() -> String:
	return "var {name} = load(scene_file_path).instantiate()\n{name}.position = {at}\n" \
		+ "{parent}.call_deferred(\"add_child\", {name})"


## The spawn that may not happen, with `query` naming which of the two free-spot calls it asks. The
## copy's name is bound at the top rather than inside the branch so the rows underneath can still
## say it - it is simply nothing when the arena was full, which is what Is Still Here asks about.
static func free_spot_spawn_template(query: String) -> String:
	return "var {name}_spot = %s.%s({inside}, {scene}, {clear_of}, {gap}, {tries})\n" % [FREE_SPOT_CALL, query] \
		+ "var {name} = null\n" \
		+ "if {name}_spot == null:\n" \
		+ "\tif has_signal(&\"%s\"):\n" % SKIPPED_SIGNAL \
		+ "\t\temit_signal(&\"%s\", {scene})\n" % SKIPPED_SIGNAL \
		+ "else:\n" \
		+ "\t{name} = {scene}.instantiate()\n" \
		+ "\t{name}.position = {name}_spot\n" \
		+ "\t{parent}.call_deferred(\"add_child\", {name})"


## The random point inside a 2D collision shape, with the node written wherever `slot` says - ONE
## spelling, offered to the row that is only that expression (Random Place Inside Shape) and to the
## formation row that scatters a whole wave with it. The expression itself is frozen: it is a shipped
## row's template, so the bytes below may never change, only where they are written down.
static func inside_shape_expression(slot: String) -> String:
	return ("%s.to_global((%s.shape as RectangleShape2D).size * Vector2(randf() - 0.5, randf() - 0.5)" \
		+ " if %s.shape is RectangleShape2D" \
		+ " else (Vector2.RIGHT.rotated(randf() * TAU) * (%s.shape as CircleShape2D).radius * sqrt(randf())" \
		+ " if %s.shape is CircleShape2D else Vector2.ZERO))") % [slot, slot, slot, slot, slot]


## The random point inside a 3D box, with the node written wherever `slot` says. Same reasoning and
## the same freeze as its 2D twin above: Random Place Inside Box is these bytes and so is the box
## formation, and one of them changing without the other is how two readings of one line begin.
static func inside_box_expression(slot: String) -> String:
	return ("(%s as Node3D).to_global(Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5)" \
		+ " * (((%s as CollisionShape3D).shape as BoxShape3D).size" \
		+ " if %s is CollisionShape3D else (%s as CSGBox3D).size))") % [slot, slot, slot, slot]


## WHERE COPY NUMBER i LANDS, one expression per formation word - the whole of what the formation
## dropdown changes. Each is a place a reader can check on its own, in the same language the shipped
## placement expressions are written in, and each reads only the fields its own shape needs.
##
## THE DIVISORS ARE THE DIFFERENCE BETWEEN A RING AND AN ARC. A ring divides the turn by the count,
## so the last copy stops one step short of the first and the spacing is even all the way round. An
## arc divides by one less, so the first copy sits at the start angle and the last one at the far end
## of the sweep - which is what "from here to there" means and what a ring must not do, or its first
## and last copies would land on top of each other. `maxf(count - 1.0, 1.0)` is what keeps a formation
## of one from dividing by zero: it lands at the start, which is the only place a single copy can be.
##
## AND THE GRID DIVIDES WHOLE NUMBERS. `i % across` and `i / across` are the column and the row, and
## the second one is integer division on purpose - that is the arithmetic that turns a running count
## into rows, and it is why Across is a whole number rather than an expression with a decimal point.
static func formation_places() -> Dictionary:
	return {
		FORMATION_RING: "{around} + Vector2.RIGHT.rotated(TAU * {name}_index / {count}) * {size}",
		FORMATION_ARC: "{around} + Vector2.RIGHT.rotated(deg_to_rad({start} + {sweep} * {name}_index / maxf({count} - 1.0, 1.0))) * {size}",
		FORMATION_LINE: "{around}.lerp({to}, {name}_index / maxf({count} - 1.0, 1.0))",
		FORMATION_GRID: "{around} + Vector2({name}_index % {across}, {name}_index / {across}) * {size}",
		FORMATION_SHAPE: inside_shape_expression("({inside} as CollisionShape2D)"),
	}


## The same five, one dimension up. The ring and the arc turn about the up axis and the grid lays its
## rows out on the ground plane, so a formation stays level with the point it is spawned around -
## add to the Y of that point yourself when the wave is meant to arrive from above.
static func formation_places_3d() -> Dictionary:
	return {
		FORMATION_RING: "{around} + Vector3.FORWARD.rotated(Vector3.UP, TAU * {name}_index / {count}) * {size}",
		FORMATION_ARC: "{around} + Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad({start} + {sweep} * {name}_index / maxf({count} - 1.0, 1.0))) * {size}",
		FORMATION_LINE: "{around}.lerp({to}, {name}_index / maxf({count} - 1.0, 1.0))",
		FORMATION_GRID: "{around} + Vector3({name}_index % {across}, 0, {name}_index / {across}) * {size}",
		FORMATION_BOX: inside_box_expression("{inside}"),
	}


## The whole formation sentence, as the run of statements it emits. The loop is the same for every
## shape and every timing; `places` is what changes with the shape, and the last two lines are what
## changes with the timing - the deferred spelling places BEFORE it parents, for the reason the
## shipped Spawn A Copy Safely states: a copy that is not in a tree yet has nothing for a global
## position to be global to.
static func formation_template(places: Dictionary, order: Array[String]) -> String:
	var branches: String = ""
	for word: String in order:
		branches += "{?formation=%s}%s{/formation}" % [word, str(places[word])]
	return "var {name}_scene = {scene}\n" \
		+ "for {name}_index in range({count}):\n" \
		+ "\tvar {name} = {name}_scene.instantiate()\n" \
		+ "\t{name}.add_to_group({crowd}, true)\n" \
		+ "\tvar {name}_place = " + branches + "\n" \
		+ "\t{?when=" + WHEN_NOW + "}{parent}.add_child({name})\n\t{name}.global_position = {name}_place{/when}" \
		+ "{?when=" + WHEN_LATER + "}{name}.position = {name}_place\n\t{parent}.call_deferred(\"add_child\", {name}){/when}"


## Which way a 2D copy is turned, one line per facing word. Every one of them is an assignment to the
## copy's own `rotation`, so the line after it can read that rotation back and turn it into a
## direction - which is what makes "facing" and "moving" one sentence instead of two fields that
## happen to agree.
static func facing_lines() -> Dictionary:
	return {
		FACE_SPAWNER: "{name}.rotation = rotation",
		FACE_NODE: "{name}.rotation = ({toward}.global_position - {name}.global_position).angle()",
		FACE_MOUSE: "{name}.rotation = (get_global_mouse_position() - {name}.global_position).angle()",
		FACE_ANGLE: "{name}.rotation = deg_to_rad({angle})",
	}


## The same, in three dimensions. Toward a node is Godot's own `look_at`, which is the honest
## spelling and carries Godot's own rule with it: a node standing exactly where the copy landed gives
## look_at nothing to point at and it says so at run time.
static func facing_lines_3d() -> Dictionary:
	return {
		FACE_SPAWNER: "{name}.global_rotation = global_rotation",
		FACE_NODE: "{name}.look_at({toward}.global_position)",
		FACE_ANGLE: "{name}.rotation.y = deg_to_rad({angle})",
	}


## Where the launch is written, one line per answer. The first two are the property the engine drives
## that kind of body by. The third is the Bullet behaviour's scalar speed, and it is a LENGTH because
## a bullet already flies along its own facing - the direction is the rotation set two lines above,
## so what is left for the behaviour to be told is how fast.
static func move_lines(behaviour_child: String) -> Dictionary:
	return {
		MOVE_VELOCITY: "{name}.velocity = {name}_launch",
		MOVE_LINEAR: "{name}.linear_velocity = {name}_launch",
		MOVE_BULLET: "{name}.get_node(\"%s\").speed = {name}_launch.length()" % behaviour_child,
	}


## The launched-copy sentence, as the run of statements it emits: the three lines the frozen Spawn A
## Copy writes, the facing, the launch, and the write that hands the launch to whatever the scene is.
##
## THE LAUNCH IS A LOCAL, and not only for readability: it is the one place the spawner's own speed
## can be added without writing it into three different properties, and it is what lets the row say
## "moving at 400" once rather than once per kind of body.
static func launched_template(facings: Dictionary, forward: String, moves: Dictionary,
		order: Array[String]) -> String:
	var facing_branches: String = ""
	for word: String in order:
		facing_branches += "{?facing=%s}%s{/facing}" % [word, str(facings[word])]
	var move_branches: String = ""
	for word: String in MOVE_ORDER:
		move_branches += "{?moves=%s}%s{/moves}" % [word, str(moves[word])]
	return "var {name} = {scene}.instantiate()\n" \
		+ "{parent}.add_child({name})\n" \
		+ "{name}.global_position = {at}\n" \
		+ facing_branches + "\n" \
		+ "var {name}_launch = " + forward + " * {speed}\n" \
		+ "{?carry=true}{name}_launch += velocity\n{/carry}" \
		+ move_branches


## The scene a spawn makes a copy of. Its value is an expression on purpose: a sheet that declares
## `const Enemy := preload("res://enemy.tscn")` says `Enemy` here and reads as a sentence, while a
## project that builds a path at runtime says `load(path)` in the same field. The default is the
## second spelling because it is the one that stands on its own in any script.
static func _scene_param() -> ACEParam:
	return F.make_param("scene", "String", "load(\"res://enemy.tscn\")", "Scene",
		"The scene to copy - one of this sheet's declared scenes by name, or a load() of a scene path.",
		"expression")


## The name the copy answers to. Plain text, because it becomes an identifier in the emitted code.
static func _name_param(default_name: String = "new_enemy") -> ACEParam:
	return F.make_param("name", "String", default_name, "Called",
		"What to call the new copy. Following rows in this event say this name, and it is the variable name the emitted code uses.",
		"")


## Where the copy lands. An expression field with the placement starters offered as suggestions, so
## the commonest answers are one click away without the field stopping being an expression.
static func _at_param() -> ACEParam:
	return F.make_param("at", "String", "global_position", "At",
		"Where the copy lands, as a position. Leave it as global_position to spawn where this node is.",
		"expression", [], PLACEMENT_STARTERS)


## Where a 3D copy lands. The same field with the same reasoning as its 2D twin, offering the 3D
## starters - the only thing about a spawn that changes with the dimension is the shape of "where".
static func _at_param_3d() -> ACEParam:
	return F.make_param("at", "String", "global_position", "At",
		"Where the copy lands, as a position in three dimensions. Leave it as global_position to spawn where this node is.",
		"expression", [], PLACEMENT_STARTERS_3D)


## The node the copy is added under. Stated on the row even when it is this one, because a copy that
## quietly ends up somewhere else is the hardest kind of spawn to find later.
static func _parent_param() -> ACEParam:
	return F.make_param("parent", "String", "self", "Under",
		"The node the copy is added under. Leave it as self to add it under this one, or name a layer to keep spawns together.",
		"expression")


## How many copies a formation makes. An expression rather than a spinner, because the number a wave
## grows by is nearly always a variable by the third level.
static func _count_param() -> ACEParam:
	return F.make_param("count", "String", "8", "How Many",
		"How many copies to make. The formation spreads exactly this many out across its shape.",
		"expression")


## The point a formation is measured from. The same suggestion list the At field offers, because it
## is the same kind of answer: a place.
static func _around_param(starters: Array[String]) -> ACEParam:
	return F.make_param("around", "String", "global_position", "Around",
		"The place the formation is measured from: the centre of a ring or an arc, the first end of a line, the near corner of a grid. The two scattering formations do not read it - what they scatter inside is a node, which is the field below.",
		"expression", [], starters)


## The node a scattering formation spreads its copies through. It is a NODE rather than a place,
## which is why it is a field of its own: the two scattering formations measure the thing you drew,
## and the other three measure out from a point.
static func _inside_param(default_node: String, kind: String) -> ACEParam:
	return F.make_param("inside", "String", default_node, "Inside",
		"The node a scattering formation spreads its copies through - a %s. Only the two scattering formations read it; the other three are measured from Around instead." % kind,
		"scene_node")


## The node a free spot is rolled inside. A field of its own rather than the formation's Inside,
## because the two ask for different things: a formation scatters through a shape and this one also
## needs the shape to be one a point can be tested against.
static func _free_inside_param(default_node: String, kind: String) -> ACEParam:
	return F.make_param("inside", "String", default_node, "Inside",
		"The node whose shape the point is rolled inside - a %s. Nothing outside it is ever offered." % kind,
		"scene_node")


## The groups a free spot has to keep out of. A list expression, because "clear of" is nearly always
## more than one thing by the second level - walls and water, walls and the player's own start.
static func _clear_of_param() -> ACEParam:
	return F.make_param("clear_of", "String", "[\"walls\"]", "Clear Of",
		"The groups the copy must not land in, as a list of group names. Members that carry a collision shape are tested against the copy's own shape; members that carry none are answered by distance, using the gap below.",
		"expression")


## How far apart copies of the same scene have to be, and how far from a shapeless group member.
static func _gap_param(default_gap: String, units: String) -> ACEParam:
	return F.make_param("gap", "String", default_gap, "Gap",
		"How far apart copies of the same scene have to be, in %s. It is also the distance kept from any member of the named groups that carries no collision shape - a marker, a waypoint, a bare node somebody dropped to say not here. Nought asks neither question and leaves only the overlap test." % units,
		"expression")


## How many points to roll before answering nothing. In the dialog and not in the sentence: it is a
## dial on how hard to look, and a reader of the row wants to know WHERE and WHAT, not how many
## times it asked.
static func _tries_param() -> ACEParam:
	return F.make_param("tries", "String", "24", "Tries",
		"How many points to roll before giving up and answering nothing. More tries find a spot in a crowded arena more often and cost more when there is genuinely no room left.",
		"expression")


## The one number a shape is sized by.
static func _size_param(default_size: String = "120.0") -> ACEParam:
	return F.make_param("size", "String", default_size, "Size",
		"How big the formation is: the radius of a ring or an arc, or the gap between neighbours in a grid. The line and the shape formations do not read it - a line is measured by its two ends and a shape by the shape you drew.",
		"expression")


## The far end of a line formation. Written as a point rather than as a direction and a length, so
## the two ends of the line are the two things the row says.
static func _to_param(default_point: String) -> ACEParam:
	return F.make_param("to", "String", default_point, "To",
		"The far end of a line formation - the first copy lands on Around and the last one lands here. Only the line formation reads it.",
		"expression")


## Where an arc begins, in degrees. Degrees rather than radians because it is a number a person types
## and reads back off the row; the emitted line converts it once.
static func _start_param() -> ACEParam:
	return F.make_param("start", "String", "0.0", "Start Angle",
		"Which angle an arc formation begins at, in degrees - 0 is to the right, 90 is down in 2D. Only the arc reads it.",
		"expression")


## How far an arc turns, in degrees.
static func _sweep_param() -> ACEParam:
	return F.make_param("sweep", "String", "180.0", "Sweep",
		"How far an arc formation turns from its start angle, in degrees. 360 makes a full turn with the first and last copy on top of each other, which is what the ring formation is for instead. Only the arc reads it.",
		"expression")


## How many copies stand in one row of a grid. A whole number, because the emitted line divides by it
## to work out which row a copy belongs in.
static func _across_param() -> ACEParam:
	return F.make_param("across", "String", "4", "Across",
		"How many copies stand side by side in one row of a grid, before the next row starts. It has to be a whole number - the line that lays the grid out divides by it. Only the grid reads it.",
		"expression")


## The group every copy of a formation joins. The same field, same words and same default as the
## crowd rows', so the two sentences read as one language and the group name means one thing.
static func _crowd_param() -> ACEParam:
	return F.make_param("crowd", "String", "\"enemies\"", "Into The Crowd",
		"The group every copy joins, named after the scene they are copies of. It is an ordinary Godot group, so the row underneath can address the whole formation with For Each In Group - and so can anything else in the project.",
		"group_reference")


## The node a launched copy is turned toward.
static func _toward_param() -> ACEParam:
	return F.make_param("toward", "String", "self", "Toward",
		"The node the copy is turned toward - the player, a target, a marker. Only the Toward A Node facing reads it.",
		"expression")


## The angle a launched copy is turned to, in degrees.
static func _angle_param() -> ACEParam:
	return F.make_param("angle", "String", "0.0", "Angle",
		"The angle the copy is turned to, in degrees - 0 is to the right in 2D, and a turn around the up axis in 3D. Only the At An Angle facing reads it.",
		"expression")


## How fast a launched copy travels along its own facing.
static func _speed_param(default_speed: String, words: String) -> ACEParam:
	return F.make_param("speed", "String", default_speed, "Moving At", words, "expression")


## Whether the spawner's own speed is added to the launch. A checkbox because it is one question with
## two answers, and it is OFF to start with for a reason worth saying: the line it writes reads the
## spawner's own `velocity`, which is what a body that moves calls its speed and what a node that
## does not move does not have at all.
static func _carry_param(velocity_word: String) -> ACEParam:
	return F.make_param("carry", "bool", false, "Plus This Node's Speed",
		"Adds this node's own speed to the launch, so a shot fired from a moving ship leaves it faster and one fired backwards leaves it slower. It reads this node's %s, which only a body that moves has - leave it off on a node that does not." % velocity_word,
		"")
