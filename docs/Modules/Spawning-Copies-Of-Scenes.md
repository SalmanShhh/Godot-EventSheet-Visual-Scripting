# Spawning Copies Of Scenes

Spawning is three lines of Godot: make a copy of a scene, add it under a parent, put it somewhere.
There is no spawning system in this plugin, and there is not going to be one. No registry, no
manager node, no autoload. A spawn row writes those three lines and nothing else, which is why the
result reads like a script somebody wrote by hand.

```
var new_enemy = Enemy.instantiate()
$Enemies.add_child(new_enemy)
new_enemy.global_position = $SpawnPoint.global_position
```

**The name in the middle is the whole point.** The row asks what to call the new copy, and that name
is a real local variable in the emitted code. Every following row in the same event can simply say
it, because by the time those rows run the code already declared it. Nothing looks anything up, and
nothing is remembered anywhere.

Three rows make the sentence, and four expressions answer "where":

- **Spawn A Copy** - the whole thing: instance, parent, place.
- **Spawn A Copy Safely** - the same spawn added on the next idle moment, for a collision handler.
- **Make A Copy** - the name-minting statement on its own, for a copy that needs setting up first.
- **Place Of**, **Random Place Along Path**, **Random Place Inside Shape**, **Random Place Off Screen
  Edge** - one expression each, usable in any field that takes a position.

The older **Spawn Scene**, **Spawn Scene At** and **Spawn Scene (Full)** rows take a scene PATH as
text and are unchanged. They are still the answer when the path is built at runtime; these rows are
for the scene the sheet already declares.

Four more rows take a copy back out of the world again, because the other half of spawning is
destroying, and the mistakes live there:

- **Destroy Now** - `queue_free()`, said plainly, with the end-of-frame timing on the row.
- **Destroy After Seconds** - a scene-tree timer with the free hung off it.
- **Fade Out Then Destroy** - a tween, a wait, and the destroy after it.
- **Is Still Here** - the question, for a name the sheet held on to.

A node that wants to hear about its OWN destruction uses the shipped **On Exit Tree** trigger, which
fires as it leaves the tree. That is a lifecycle handler rather than a destroy verb, so it stays
where it is.

Six more say the copies in the plural, because a game that spawns one thing soon spawns twenty:

- **Spawn A Copy Into The Crowd** - the same spawn, with the copy joined to a group named after the
  scene.
- **Spawn A Copy, The First Makes Room** and **Spawn A Copy Unless The Crowd Is Full** - the cap,
  with what happens at the cap written into the row's own sentence.
- **How Many Alive** - the group's size, in any field that takes a number.
- **On The Last One Destroyed** and **Crowd Is Down To This One** - the trigger for a crowd emptying,
  and the question it puts in the sheet underneath itself.

Sixteen more say the wave, the aim and the way back out, and they have a chapter of their own below:

- **Spawn In A Formation** and its 3D twin - several copies at once, in a ring, an arc, a line, a
  grid, or scattered inside a shape you drew.
- **Spawn A Copy, Facing And Moving** and its 3D twin - one copy turned to face something and given
  a speed along that facing.
- **Spawn A Copy Of Myself** and its 3D twin - one more copy of the scene this node came from, with
  nothing in the row naming the file.
- **Free Spot In** and its 3D twin - the placement expression that only ever answers with somewhere
  nothing is standing. **Spawn A Copy In A Free Spot** and its 3D twin spend it, and **On Spawn
  Skipped** is what a full arena raises.
- **Retire**, **Retire After Seconds**, **Fade Out Then Retire** and its 3D twin, and **On
  Retired** - the removal that hands a pooled copy back to its pool and destroys everything else.

## Table of Contents

1. [Where this shines](#where-this-shines)
2. [Core concepts](#core-concepts)
3. [Destroying what you spawned](#destroying-what-you-spawned)
4. [The same sentence in three dimensions](#the-same-sentence-in-three-dimensions)
5. [The crowd](#the-crowd)
6. [Many kinds from one row - the kinds table](#many-kinds-from-one-row---the-kinds-table)
7. [Reusing copies instead of making them - routing through a pool](#reusing-copies-instead-of-making-them---routing-through-a-pool)
8. [Waves, aim, free spots and retiring](#waves-aim-free-spots-and-retiring)
9. [The same sentences over the network](#the-same-sentences-over-the-network)
10. [What the sheet says it spawns](#what-the-sheet-says-it-spawns)
11. [The five things that go wrong](#the-five-things-that-go-wrong)
12. [Reference tables](#reference-tables)
13. [Use cases](#use-cases)
14. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this shines

- **A wave of enemies** arriving from off screen, each one tagged as it lands.
- **A bullet** that has to be set up (damage, direction, shooter) the instant it exists.
- **Loot scattered inside a zone** you drew as an Area2D, rather than at a hand-typed point.
- **Pickups placed along a patrol path**, spread evenly by distance rather than by curve segment.
- **A spawn point you can move in the editor** without opening the sheet.
- **A spawn from a collision handler**, where Godot refuses an immediate `add_child`.
- **Keeping spawns under one layer node** so the scene tree stays readable at runtime.
- **A trail, a swarm or a burst with a hard limit**, capped on the row with the policy said out loud.
- **A wave that announces its own end** when the last member leaves, with nothing counting down.
- **Reading somebody else's script** and seeing their own name for the copy kept in the row.
- **Several kinds of enemy from one row**, chosen by a name a wave table holds.
- **Bullets a profiler asked you to stop making**, routed through a pool without changing the rows
  between the two ends.
- **A copy every player has to agree exists**, said in the same sentences over the network.

## Core concepts

- **The Called field becomes a variable name.** Type `new_enemy` and the code says
  `var new_enemy = …`. Following rows in the same event say `new_enemy`, and expression fields offer
  it while you type, alongside the sheet's variables and the trigger's parameters. It is a local
  variable, so it lasts exactly as long as the event does - a later event cannot see it, and the
  compiler will say so rather than guessing.
- **The parent is on the row even when it is this node.** The default is `self`, and the sentence
  says `under self`. That is deliberate: a copy that quietly ends up somewhere else is the hardest
  kind of spawn to find later, so the row always states where it went.
- **Placement happens after parenting, and the row shows that.** `global_position` only means
  anything once a node is in a tree. Spawn A Copy therefore adds the copy first and places it second.
- **The safe row reverses that, and says why.** Spawn A Copy Safely sets `position` (relative to the
  parent) BEFORE handing the copy over, because the copy is not in a tree yet when that line runs.
- **Godot refuses `add_child` while the physics server is flushing.** That is most of what a body or
  area callback is. Inside one, use Spawn A Copy Safely - it writes
  `call_deferred("add_child", …)` and the row reads `added on the next idle moment`, so the deferral
  is visible rather than done behind your back.
- **The Scene field takes an expression, not a file picker.** A sheet that declares
  `const Enemy := preload("res://enemy.tscn")` says `Enemy` and reads as a sentence. A path built at
  runtime says `load(path)` in the same field. Both are ordinary GDScript.
- **The placement words are values, not rows.** Each one is a single expression, so it works in any
  field that takes a position - a Move To, a Set Property, a camera target - and not only in a spawn.
- **Random Place Inside Shape measures the shape.** A rectangle is scattered from its own size and a
  circle from its own radius, evenly, in one step. There is no rejection sampling and no retry loop,
  so the line costs the same every time it runs. Any other shape gives its own centre instead of a
  guess.
- **The two sampling words answer in the world's frame.** A curve is drawn in its Path2D's own space
  and a shape is measured in its CollisionShape2D's, so both hand the point back through `to_global`
  rather than adding it to `global_position`. Adding is only right while nothing above the node is
  rotated or scaled - and a spawn zone turned to face down a corridor is the commonest thing in a
  level there is.
- **Nothing here needs the plugin at runtime.** Every row compiles to `instantiate()`, `add_child`,
  `call_deferred`, `randf()` and arithmetic. Uninstall the editor and the game still builds.

### The whole spawn, in one event

One spawn row and the rows that say the name it minted. This is the compiled shape, which is also
the shape an already-written script opens in.

<!-- caption: A spawn and the name it leaves behind: the copy is made, added under this node, and placed at a marker -->
```gdscript
extends Node2D

const Enemy := preload("res://enemy.tscn")


func _ready() -> void:
	var new_enemy = Enemy.instantiate()
	self.add_child(new_enemy)
	new_enemy.global_position = $SpawnPoint.global_position
```

Inside a collision handler the same spawn is written the deferred way, and the row says so rather
than doing it quietly. The place is set before the copy is handed over, because the copy is not in a
tree yet on that line.

<!-- caption: The safe spawn: the place set first, and the copy added on the next idle moment -->
```gdscript
extends Area2D

const Spark := preload("res://spark.tscn")


func _on_body_entered(body: Node2D) -> void:
	var new_spark = Spark.instantiate()
	new_spark.position = global_position
	self.call_deferred("add_child", new_spark)
```

## Destroying what you spawned

Destroying a node in Godot is `queue_free()`. The three destroy rows are that call with the wait each
one does written out beside it, so the only thing you ever have to decide is WHEN.

```
enemy.queue_free()                                              # now, meaning end of frame
get_tree().create_timer(2.0).timeout.connect(enemy.queue_free)  # in two seconds
```

**"Now" means the end of this frame, not this line.** `queue_free()` marks the node and Godot
deletes it when the frame finishes. The rows after it in the same event still run, and the node is
still there while they do. That is not a quirk to work around - it is why a sheet can destroy a thing
and then read its position on the very next row without crashing.

**The timer row is safe if the thing is already gone.** Godot drops a signal connection along with
the object at the far end of it, so something else destroying the node first takes the pending free
with it and the timer fires at nothing.

**The fade row waits, so the event waits.** It walks `modulate:a` down to nothing with a tween,
awaits the tween, and then destroys. Because that wait is a real gap in game time, the row asks
whether the object is still there before it destroys it, and the line that asks is part of the row's
own code rather than something added quietly.

**The freed object is still there for the rest of the line's own frame.** That is the one lesson
worth reading twice, because it is the opposite of what "destroy now" sounds like. A row after the
destroy that reads the object still works. A row after it that expects the object to be gone does
not, and no error says so.

<!-- caption: A bullet that cleans itself up: the free is hung off a scene-tree timer, so nothing blocks and nothing counts down -->
```gdscript
extends Node2D


func _ready() -> void:
	get_tree().create_timer(2.0).timeout.connect(queue_free)
```

The fade spelling people write by hand is one statement too, and it opens as the Fade Out Then
Destroy row with the author's own object kept in it.

<!-- caption: The fade-then-destroy one-liner: the tween walks the alpha down and the free is hung off its finish -->
```gdscript
extends Node2D

var ghost: Node2D = null


func _on_died() -> void:
	ghost.create_tween().tween_property(ghost, "modulate:a", 0.0, 0.5).finished.connect(ghost.queue_free)
```

### The guard, and why you can see it

A name that outlives the line that set it can name nothing at all by the time a later row says it.
There is exactly one of those in a sheet: a **variable typed as a node**, which survives from frame
to frame with nothing about this event having put it there. When a destroy row's object is one, the
compiler writes the check Godot's own answer calls for:

```
if is_instance_valid(boss):
	boss.queue_free()
```

**And the row shows it.** The guard line is echoed at the end of the row, in the script editor's own
colours, exactly as a variable row echoes its declaration. It is never a hidden wrapper: the sheet
shows the line the file holds, so you can see which name asked for it and delete the reason if you
would rather not have it.

**It stands down when you already asked.** Put an Is Still Here (or the shipped Object Still Exists)
condition on the event and the compiler writes nothing extra - your question is the one that gets
written, once. That is also what makes a file guarded by hand open and save back byte for byte.

<!-- caption: A stored node destroyed from a later event: the guard is a line in the file, not a wrapper around the row -->
```gdscript
extends Node2D

var target: Node2D = null


func _on_timeout() -> void:
	if is_instance_valid(target):
		target.queue_free()
```

**A copy named in another event is not guarded either, and the reason is scope.** The name a spawn
row gives a copy is a local variable in the handler that row compiled into. A destroy row in a
different event saying that name does not compile at all - Godot answers `Identifier "boss" not
declared in the current scope` - and wrapping it in a question that cannot see the name either would
only add a second line that does not compile, echoed on the row as protection. Keep the destroy in
the event that made the copy, or hold the copy in a variable typed as a node, which is the case the
guard is for.

**Nothing else is guarded.** `self` cannot dangle, a `$Path` re-resolves every time it is read, and
every row outside these three is left exactly as it was. Emitted code does not change under your
feet.

## The same sentence in three dimensions

A 3D game spawns for exactly the same reasons and in exactly the same order, so the 3D rows are the
2D pair with a Node3D host and Vector3 answers to "where". They are not a second spawning idea, and
there is nothing new to learn about them:

- **Spawn A Copy (3D)** - instance, parent, place, in that order.
- **Spawn A Copy Safely (3D)** - the same spawn added on the next idle moment, placing before it
  parents for the same reason its 2D twin does.
- **Place Of (3D)**, **Random Place Inside Box**, **Random Place Inside Sphere**, **Random Place
  Around (3D)** - one expression each, usable in any field that takes a Vector3.

```
var new_enemy = Enemy.instantiate()
$Enemies.add_child(new_enemy)
new_enemy.global_position = ($SpawnBox as Node3D).to_global(Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * ((($SpawnBox as CollisionShape3D).shape as BoxShape3D).size if $SpawnBox is CollisionShape3D else ($SpawnBox as CSGBox3D).size))
```

- **The box reads two kinds of box.** A CollisionShape3D holding a BoxShape3D - the one on the Area3D
  you drew around a spawn zone - and a CSGBox3D you blocked the space out with. The casts in the
  emitted line are what let one expression ask which it is: a node reached by path is a plain Node
  until something says otherwise, and GDScript will not read `size` off one that has not.
- **The sphere corrects by the CUBE root, not the square root.** The 2D disc pulls its radius back by
  a square root so points do not bunch up in the middle. A solid ball needs the cube root for the
  same reason and by the same argument: the volume inside a radius grows as its cube. The direction
  is three normal draws normalised, which is the one spelling that is evenly spread over a sphere -
  picking two angles at random bunches points at the poles.
- **Random Place Around (3D) is a ring, not a disc.** Every point is exactly the radius out, on the
  ground plane, level with the node it is around. Add to the Y yourself when you want the copy
  dropped in from above.
- **Place Of (3D) writes the same line Place Of does.** `global_position` is the node's own word in
  both dimensions. The 3D row exists so the 3D page offers it; the reading of that line stays the 2D
  row's, so an opened file never has two rows arguing over one spelling.

![A wave spawned inside a box, and a flanker on a ring around the player](../images/scenes-spawn-3d.png)

**There is no 3D Random Place Off Screen Edge, on purpose.** In 2D a screen edge is a rectangle in
the same plane the game is played in, which is why that row can be one honest expression. In 3D
"just off screen" is a question about a camera's frustum - which camera, how far along its forward
axis, and at what depth the answer is even meant to sit - and every one-line answer to it is a guess
that looks right until the camera moves. Nothing is offered in its place: a wave that must arrive
from off camera is spawned at a Marker3D or inside a box the level designer drew, which is what
Place Of (3D) and Random Place Inside Box already say.

## The crowd

Once a sheet spawns more than one of a thing, the questions change: how many are there, how many are
allowed, and what happens when the last one goes. A crowd is the plugin's word for the answer, and
the answer is a **Godot group** - the tree's own index, which empties itself as members leave.

```
var new_enemy = Enemy.instantiate()
new_enemy.add_to_group("enemies", true)
$Enemies.add_child(new_enemy)
new_enemy.global_position = $SpawnPoint.global_position
```

**The second argument is not optional.** `add_to_group(name)` on its own is not persistent, and
`PackedScene.pack()` saves persistent groups only - so a group joined without the flag disappears
the moment its branch is packed back into a `.tscn`, after which every count quietly answers zero.
The crowd rows always pass `true`. It costs nothing at runtime and it is the difference between a
crowd that survives being saved into a scene and one that does not.

**Nothing keeps a list.** There is no registry and no manager node. The rows join a group and then
ask the tree, so there is no second place for the two to disagree, and a member that is freed leaves
the group as it leaves the tree.

### The cap, and the policy on the row

"At most twelve alive" is two different games depending on what happens at twelve, so there is a row
per answer and each says which it is in its own sentence.

**Spawn A Copy, The First Makes Room** destroys members to make room and then spawns, so the new copy
always appears:

```
var crowd_new_mark = get_tree().get_nodes_in_group("marks").filter(func(member: Variant) -> bool: return not member.is_queued_for_deletion())
while crowd_new_mark.size() >= maxi(20, 1):
	crowd_new_mark.pop_front().queue_free()
var new_mark = Mark.instantiate()
```

The crowd is read once into a local, because the row needs both the size and the members it is about
to destroy. `maxi(cap, 1)` is what makes `pop_front()` always safe: the loop cannot run on an empty
crowd, whatever number you typed.

**The read skips the members that are already leaving, and that is the whole of why the cap holds.**
`queue_free()` marks a node and leaves it in the tree - and therefore in its group - until the end of
the frame. A row that read the group straight would hand the same member to every spawn of that
frame: three spawns under a cap of twenty would free the same one three times and add three, leaving
twenty-two alive, and the next such frame twenty-four. Skipping the leavers means the count means
what the row says and a different member makes room each time. It is a `while` rather than an `if`
for the same reason: whatever the crowd was when the line was reached, it fits the cap when the line
has run.

The members destroyed are taken from the front of the crowd, which is the order Godot lists a group
in. Under a parent that spawns by adding children that is the earliest one still alive; after a
`move_child`, or with copies spread over two parents, it is the tree's order rather than the spawn's.
This is what a bullet, a footstep or a skid mark wants.

**Spawn A Copy Unless The Crowd Is Full** does nothing at all when the crowd is full:

```
var new_enemy: Node = null
if get_tree().get_node_count_in_group("enemies") < 12:
	new_enemy = Enemy.instantiate()
```

The name is declared **before** the branch on purpose, so the rows after it can still say it. What
it holds when the spawn was skipped is nothing - which an Is Still Here row can ask about, rather
than a silence you have to guess at. This is what an enemy wave wants, where a spawn that arrives by
pushing another one out is worse than no spawn.

<!-- caption: A skid-mark trail capped at twenty: the crowd is read once, the member Godot lists first goes, and the new mark joins the group as it arrives -->
```gdscript
extends Node2D

const Mark := preload("res://mark.tscn")


func _physics_process(delta: float) -> void:
	var crowd_new_mark = get_tree().get_nodes_in_group("marks")
	if crowd_new_mark.size() >= maxi(20, 1):
		crowd_new_mark[0].queue_free()
	var new_mark = Mark.instantiate()
	new_mark.add_to_group("marks", true)
	self.add_child(new_mark)
	new_mark.global_position = global_position
```

### Counting them, and missing them

**How Many Alive** is the group's own size, `get_tree().get_node_count_in_group("enemies")`. It is an
expression, so it goes in any field: a comparison, a HUD label, a difficulty curve.

**On The Last One Destroyed** runs the moment a crowd's last member leaves the world, once per
emptying. It is the scene tree's own node-removed signal, and the question that narrows it to this
crowd is a **condition row you can see**:

```
func _ready() -> void:
	get_tree().node_removed.connect(_on_node_removed)

func _on_node_removed(node: Node) -> void:
	if node.is_in_group("enemies") and node.is_queued_for_deletion() and get_tree().get_nodes_in_group("enemies") == [node]:
		...
```

Picking the trigger adds that condition underneath it, filled in with the crowd you typed. It is an
ordinary row: editable, deletable, and a plain `if` on disk. **A leaving node is still listed in its
groups at that moment**, which is why "the crowd is down to just the one that is going" is exactly
"this was the last one".

**The middle question is what tells leaving the world from changing parents.** `node_removed` fires
for any exit from the tree, and `Node.reparent()` is one: for the instant the signal is emitted the
moved node is out of the tree, still in its groups, and the only member the group lists. Without
`is_queued_for_deletion()` the event would open the door and pay the reward while the enemy was
alive under another parent. It is true for every destroy this language writes - all three destroy
rows are a `queue_free` - and false for a move. A member taken out of the world some other way, such
as its whole branch being freed at once, is not seen by this trigger; On Group Emptied below is the
row for that.

The shipped **On Group Emptied** condition asks the same question a different way - on a per-frame
trigger, by remembering last tick's count. It is unchanged and still the answer when you want the
check to ride an existing tick. This trigger needs neither the tick nor the memory.

<!-- caption: A wave that announces its own end: the tree's node-removed signal, and the visible gate that narrows it to one crowd -->
```gdscript
extends Node2D


func _ready() -> void:
	get_tree().node_removed.connect(_on_node_removed)


func _on_node_removed(node: Node) -> void:
	if node.is_in_group("enemies") and node.is_queued_for_deletion() and get_tree().get_nodes_in_group("enemies") == [node]:
		open_door()
```

## Many kinds from one row - the kinds table

A game that spawns grunts, archers and bombers does not want three spawn rows and a chain of
conditions choosing between them. It wants one row, and a table saying which scene each name means.
The Scene field is an expression, so the table can simply be indexed in it - and the shape that
comes out is the plain **factory** every hand-written spawner ends up with, written once at the top
of the sheet instead of buried in a branch.

<!-- caption: One spawn row for every kind: a table of scenes at the top of the sheet, indexed in the Scene field -->
```gdscript
extends Node2D

const KINDS := {
	"grunt": preload("res://grunt.tscn"),
	"archer": preload("res://archer.tscn"),
}


func spawn_kind(kind: String, at: Vector2) -> void:
	var new_enemy = KINDS[kind].instantiate()
	self.add_child(new_enemy)
	new_enemy.global_position = at
```

The table is an ordinary Declare row with a chip per entry, so adding a kind is adding a chip. The
spawn row underneath never changes, and neither does anything that calls it. Three things follow
from that, and they are the reason to reach for this rather than for a branch:

- **A wave is data.** `KINDS[wave_entry]` and `KINDS.keys().pick_random()` both go straight in the
  Scene field, so a wave table, a difficulty curve or a save file can decide the kind.
- **Nothing new is registered.** The table is a `const` in the sheet's own head. There is no
  registry, no manager node and no autoload, and deleting the plugin leaves the same dictionary and
  the same three lines behind.
- **The head says the row's own words.** The spawns band is read off the emitted line rather than
  off a row's name, so a table indexed in the Scene field reads there as `KINDS[kind]`, with no file
  behind it to click - which is the honest reading, because which scene it is is decided as the game
  runs. The scenes themselves are named on the Declare row that holds the table, which is where they
  were chosen.

Keep it a table only while the kinds really are interchangeable. A kind that needs its own extra
setup rows is a second event, not another entry, and a chain of `if kind == …` inside one event is
the thing this replaces rather than the thing it hides.

## Reusing copies instead of making them - routing through a pool

`instantiate()` is not free, and a bullet game makes thousands of them. The bundled **Object Pool**
pack is the answer, and taking it is a matter of routing the two ends of the spawn somewhere else -
not of learning a second way to spawn:

- The **Spawn** expression hands out a ready copy - reusing a free one, or making a new one when the
  pool has none - so it goes in the field a Make A Copy row would have filled.
- The **Despawn** action hands the copy back instead of freeing it, so it replaces the Destroy Now
  row. Everything between the two is unchanged: the same property rows, the same crowd row, the same
  placement expression.

```
ObjectPool.create_pool("shots", "res://bullet.tscn", 32)
var new_shot = ObjectPool.spawn("shots")
ObjectPool.despawn(new_shot)
```

**The head is where you see that the routing took.** The spawns band is read off the emitted line,
and a pooled spawn does not instantiate anything - so the band reads the pool's two calls instead.
The declaring call names the scene AND the pool, so the band says `bullet.tscn - pooled as shots`; a
sheet that only hands copies out says the pool's own name, which is all that line knows. A spawn row
you meant to route and did not still reads as a plain scene on the same band, which is the fastest
way to find the one you missed.

Two things do not change when you pool, and both are the point:

- **A pooled copy is still a node in a group.** How Many Alive, On The Last One Destroyed and every
  crowd row keep working, because they ask the tree rather than the pool.
- **A despawned copy is not a freed copy.** It is hidden with its processing off, so `_ready` does
  not run again and anything the copy remembered is still there. Reset what a fresh copy would have
  had - health, alpha, velocity - on the rows after the Spawn expression.

Pool only what a profiler asked you to. A pool is a second lifetime for an object, and the day it
goes wrong is the day something reappears wearing last life's state.

## Waves, aim, free spots and retiring

Everything above is one copy at a time, put where you say and destroyed when you are done with it.
Five more sentences answer the questions that arrive next, and every one of them ships in both
dimensions:

- **Spawn In A Formation** and **Spawn In A Formation (3D)** - several copies at once, arranged in a
  shape you pick, every one of them joined to a crowd on the way in.
- **Spawn A Copy, Facing And Moving** and **Spawn A Copy, Facing And Moving (3D)** - one copy turned
  to face something and given a speed along that facing.
- **Spawn A Copy Of Myself** and **Spawn A Copy Of Myself (3D)** - one more copy of the scene this
  node was built from, with nothing in the row naming the file.
- **Free Spot In** and **Free Spot In (3D)** - the placement expression that only ever answers with
  somewhere nothing is standing. **Spawn A Copy In A Free Spot** and its 3D twin are the rows that
  spend it, and **On Spawn Skipped** is the trigger a full arena raises.
- **Retire**, **Retire After Seconds**, **Fade Out Then Retire**, **Fade Out Then Retire (3D)** and
  **On Retired** - the destroy verbs' other answer: back to the pool it came out of, or destroyed
  when it came from anywhere else.

Two of them lean on a file the game carries rather than on a line in the row, and that is worth
saying before you meet them. A free spot is a roll asked over and over until the answer fits, and a
retirement is a decision read off the node, so neither is one expression. They compile to
`FreeSpot.in_2d(…)` and `PooledNodes.retire(…)`, two plain GDScript files under the plugin's runtime
folder that a built game carries the way it carries any other script. Nothing in them touches the
editor or the sheet format, so the parity promise holds: uninstall the plugin and the emitted code
still builds and still runs.

### A whole formation in one row

A wave arranged in a shape is a loop, an index and one piece of arithmetic, and the arithmetic is
where it goes wrong. Spawn In A Formation is that loop with the arithmetic picked from a dropdown:
a **ring**, an **arc**, a **line**, a **grid**, or **scattered inside a shape** you drew (a box, in
three dimensions). The shape word changes exactly one expression - where copy number `i` lands - and
everything else about the row is the same for all five.

```
On Timeout
    -> Spawner  Spawn 6 copies of Enemy in a ring
    -> Spawner  Set wave to wave + 1
```

<!-- caption: A ring of six, spawned in one row: the scene is read once above the loop, and every copy joins the crowd as it is made -->
```gdscript
extends Node2D

const Enemy := preload("res://enemy.tscn")

var wave: int = 0


func _on_timeout() -> void:
	var enemy_scene = Enemy
	for enemy_index in range(6):
		var enemy = enemy_scene.instantiate()
		enemy.add_to_group("enemies", true)
		var enemy_place = $Totem.global_position + Vector2.RIGHT.rotated(TAU * enemy_index / 6) * 80.0
		self.add_child(enemy)
		enemy.global_position = enemy_place
	wave += 1
```

**The fields a shape does not use are left out of the code it writes.** A ring reads Around and
Size, an arc adds Start Angle and Sweep, a line reads Around and To, a grid reads Around, Size and
Across, and the two scattering shapes read Inside and nothing else. The row shows every field in its
dialog and emits only the ones its shape needs, so a line formation's code has no radius in it to
wonder about.

**The trap this removes is the divisor.** A ring divides the whole turn by the count, so the last
copy stops one step short of the first and the spacing is even the whole way round. An arc divides
by one LESS than the count, so the first copy sits on the start angle and the last one on the far
end of the sweep. Get those two the wrong way round by hand - and nearly everybody does, once - and
a ring puts its first and last copy on top of each other while an arc never reaches its far end.
`maxf(count - 1.0, 1.0)` is what keeps a formation of one from dividing by zero: it lands at the
start, which is the only place a single copy can be.

**The second trap is the crowd flag**, and it is the same one the crowd rows answer. Every copy
joins the group with Godot's persistent flag passed, so the wave survives its branch being packed
back into a `.tscn`. That is what makes the row underneath able to say For Each In Group and address
the whole formation at once, rather than the formation row having to hand anything down.

**And the scene is read once, above the loop.** `var enemy_scene = Enemy` is a lookup saved per copy,
and it is also the line that lets the run be recognised as one sentence when the file is opened
again. Inside a collision or body handler, pick the next idle moment in the Added field: the last
two lines then place before they parent, exactly as Spawn A Copy Safely does and for the same
reason.

### A copy that leaves already facing and already moving

The frozen spawn sentence puts a copy somewhere. A bullet, a spark off a wheel or an enemy charging
in needs two more facts: which way it is turned, and how fast it is going that way. Spawn A Copy,
Facing And Moving is those two on the same row, because they are one decision - the launch is
computed from the facing the line above just set.

```
Every tick
    "shoot" was just pressed
    cooldown <= 0.0
    -> Turret  Spawn a copy of Bullet as new_bullet, facing toward the mouse, moving at 900.0
    -> Turret  Set cooldown to 0.15
```

<!-- caption: A shot that leaves the barrel already aimed: the facing is written to the copy's own rotation, and the launch is read back off it -->
```gdscript
extends Node2D

const Bullet := preload("res://bullet.tscn")

var cooldown: float = 0.0


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("shoot") and cooldown <= 0.0:
		var new_bullet = Bullet.instantiate()
		self.add_child(new_bullet)
		new_bullet.global_position = $Muzzle.global_position
		new_bullet.rotation = (get_global_mouse_position() - new_bullet.global_position).angle()
		var new_bullet_launch = Vector2.from_angle(new_bullet.rotation) * 900.0
		new_bullet.velocity = new_bullet_launch
		cooldown = 0.15
```

Facing reads four answers in 2D - **the same way this node faces**, **toward a node**, **toward the
mouse**, **at an angle you say** - and three in 3D, where the mouse is not a direction in the world.
Each writes one line, and each writes it to the copy's own rotation, which is why the launch on the
next line can simply read that rotation back. In three dimensions forward is the copy's own `-Z`,
which is what Godot means by forward everywhere else, so Toward A Node is a plain `look_at`.

**Where the speed is written is a fact about the SCENE, not about this row.** A CharacterBody keeps
it in `velocity`, a RigidBody in `linear_velocity`, and a scene wearing the Bullet behaviour keeps
it as that behaviour's own speed. The Moves By field says which, and the parameters dialog reads the
`.tscn` you named and tells you which of the three it found rather than making you remember.

**The trap this removes is the order.** Turning the copy toward something means measuring from where
the copy IS, and a copy that is not in a tree yet has no global position for that measurement to be
about. Written by hand, the facing line usually ends up above the `add_child` - where it silently
measures from the origin, and the shots all fly the same way. The row writes the three frozen lines
first, then the facing, then the launch, in that order, every time.

**Plus This Node's Speed is off to start with, and the reason is worth saying.** Ticking it adds one
line, `new_bullet_launch += velocity`, so a shot fired from a moving ship leaves it faster and one
fired backwards leaves it slower. That line reads THIS node's `velocity`, which is what a body that
moves calls its speed and what a plain Node2D does not have at all - so leave it off on a turret
bolted to the wall.

### A copy of the scene this node came from

A boss that splits into two smaller bosses, a slime that halves, a crystal that shatters into
crystals: all of them want one more copy of the very scene they are. Written by hand that means the
scene preloading its own file, which is a name to keep in step with a filename. Spawn A Copy Of
Myself names nothing at all - the node already knows which file it was built from.

```
On Body Entered
    size > 1
    -> Slime  Spawn a copy of myself as half at global_position + Vector2(24, 0), under get_parent()
    -> Slime  Set half's size to size - 1
```

<!-- caption: A slime that halves: the scene is the node's own scene_file_path, and the copy joins the tree on the next idle moment -->
```gdscript
extends Area2D

var size: int = 3


func _on_body_entered(body: Node2D) -> void:
	if size > 1:
		var half = load(scene_file_path).instantiate()
		get_parent().call_deferred("add_child", half)
		half.set_deferred("global_position", global_position + Vector2(24, 0))
		half.size = size - 1
```

**The copy is added on the next idle moment, and that default is not a preference.** A scene that
splits itself nearly always does it inside a collision handler, and Godot refuses to add a child
while the physics server is flushing. The place is booked with `set_deferred` on the same queue and
after the add, so the copy has a parent by the time its place is written and At is a place in the
WORLD - which is what the field opens on. The copy itself exists straight away, which is why the
row after it can set a property on the name.

**The trap this removes is the rename.** `preload("res://slime.tscn")` inside `slime.tscn` is a
promise that the file will keep that name and that path for ever, and the day somebody moves it into
a folder the boss stops splitting. `scene_file_path` is the node's own word for where it came from,
so it follows the file wherever it goes.

**And there are two ways for it to have no answer, both of which the Doctor says out loud.** A node
built in code rather than instanced from a `.tscn` has no scene file, so the row is a load of
nothing and the copy never appears - an amber note on the row says so, and the words say to save it
as a scene and instance that instead. The second is the older one: a copy of this scene made in
**On Ready** is a scene that spawns itself the instant it is created, which doubles every time and
is a hang rather than an error. Put the row under a condition - a hit, a timer, a size still above
one - which is what a splitting boss is anyway.

### A spot nothing is standing in

The other placement words are one measurement each: a node's own place, a point along a path, a
point inside a shape. "Somewhere free" is not a measurement - it is the same roll asked again until
the answer fits - so it is the one placement word that is a function.

**Free Spot In** is that function as an expression, usable in any field that takes a position. It
asks three questions in order: the point is inside a shape somebody drew; it is at least the Gap
from every other copy of the same scene already in the world; and the copy's OWN collision shape,
put at that point, overlaps nothing in the groups you named. That third one is a real physics query
in the space the game runs in, so a wall is a wall whatever drew it. A group whose members carry no
collision shape at all cannot be asked that question, so those members are answered the only way
they can be, by distance - which is what makes a bare Marker2D dropped to say "not here" work.

**And it answers nothing when there is nothing to answer.** After the last try it gives `null`,
which is a real answer rather than a failure: a full arena has no free spot in it. **Spawn A Copy In
A Free Spot** is the row that knows what to do about that, and what it does is spawn nothing and say
so.

```
On Timeout
    -> Filler  Spawn a copy of Crate as new_crate in a free spot in $Room, under $Props

On a spawn skipped
    -> Filler  Stop the fill timer
    -> Label   Set text to "No room left"
```

<!-- caption: A room filled until it is full: the spot is rolled first, and a roll that answers nothing raises the sheet's own spawn_skipped signal -->
```gdscript
extends Node2D

signal spawn_skipped(scene)

const Crate := preload("res://crate.tscn")


func _ready() -> void:
	spawn_skipped.connect(_on_spawn_skipped)


func _on_timeout() -> void:
	var new_crate_spot = FreeSpot.in_2d($Room, Crate, ["walls"], 32.0, 24)
	var new_crate = null
	if new_crate_spot == null:
		if has_signal(&"spawn_skipped"):
			emit_signal(&"spawn_skipped", Crate)
	else:
		new_crate = Crate.instantiate()
		$Props.call_deferred("add_child", new_crate)
		new_crate.set_deferred("global_position", new_crate_spot)


func _on_spawn_skipped(scene: PackedScene) -> void:
	$FillTimer.stop()
	$Label.text = "No room left"
```

**On Spawn Skipped is an ordinary Godot signal, and the sheet declares it.** Add a signal block
saying `spawn_skipped(scene)` at the head of the sheet and both halves are plain code: the spawn row
emits it with the scene it could not place, and the trigger connects a handler to it. The emitted
`has_signal` guard is what lets the same spawn row work in a sheet that never declared it - a game
that does not care about a full arena writes no signal block and the row simply spawns nothing.

**The name is bound above the branch on purpose.** `var new_crate = null` is declared before the
`if`, so rows after the spawn can still say the name whichever way the roll went. What it holds when
the arena was full is nothing, which an Is Still Here row can ask about - the same promise Spawn A
Copy Unless The Crowd Is Full makes.

**The trap this removes is the pile.** A minefield laid with Random Place Inside Shape puts two
mines on the same tile sooner than you would think, and a crate spawned inside a wall is a crate
nobody can reach. Written by hand the fix is a retry loop, and a retry loop written in a hurry has
no ceiling on it - which is a hang rather than a wrong answer. Tries is that ceiling, on the row,
with a default of 24.

**What one call costs, said plainly.** It builds the scene once to read its collision shape and
frees it again, and walks the running scene once to find the copies already placed. Both happen ONCE
per call and are reused across every try, so raising Tries costs only the extra rolls. A spawn per
frame is fine; a thousand spawns in one frame wants a pool.

### Retiring instead of destroying

Destroying is `queue_free()`, and it is the right answer for a copy that came from `instantiate()`.
It is the WRONG answer for a copy an object pool handed out: freeing a pooled node takes it out of
the pool's own accounting, and the pool then hands out a node that no longer exists. That is the one
mistake pooling adds to a project, and it is silent until it is a crash.

**Retire** is the removal that reads which of the two it is off the node itself:

```
On Body Entered
    -> Bullet  Retire self now

On retired
    -> Bullet  Set $Trail's emitting to false
```

<!-- caption: A shot that goes back where it came from: one line, and it means free in a project with no pools in it -->
```gdscript
extends Area2D


func _ready() -> void:
	tree_exiting.connect(_on_retired)


func _on_body_entered(body: Node2D) -> void:
	PooledNodes.retire(self)


func _on_retired() -> void:
	$Trail.emitting = false
```

**Nothing has to be configured and nothing has to be remembered.** A pool already stamps every copy
it hands out with the pool's own name, so the decision is read off the node at run time: a stamped
node whose pool is still in the tree goes back to it, and anything else is freed. A project with no
pools in it behaves exactly as Destroy Now does, which is what makes Retire safe to reach for before
you know whether you will pool.

**Four rows and a trigger, matching the destroy verbs one for one.** Retire is now, Retire After
Seconds hangs the decision off a scene-tree timer, and Fade Out Then Retire walks the object's
transparency down first and then retires it - in 2D by walking `modulate:a` to nothing, and in 3D by
walking `transparency` up to one, because a Node3D has no modulate. The fade rows make the event
wait, and ask whether the object is still there before touching it, exactly as their destroy twins
do.

**The handing back waits for the frame, and that is what makes the swap safe.** A pool takes a node
back by REPARENTING it, and a reparent inside a physics callback is the very thing Godot refuses -
which is the collision handler a bullet is retired in. So the pool half is booked on the message
queue and done at the next idle moment, exactly as `queue_free()` books a deletion for the end of
the frame. Both answers therefore leave the node in the world for the rest of the event, which is
the one fact to carry: the rows after a Retire can still read the thing it retired.

**A faded copy is put back solid before it is handed over.** A pool WAKES a node rather than
rebuilding it, so whatever the fade left on it is what the next spawn of it wears - a copy that went
back invisible comes out invisible. Both fade rows write the restore themselves, on the line above
the retire, where a reader can see it. And Fade Out Then Retire (3D) is offered on a
`GeometryInstance3D` rather than on a body, because `transparency` belongs to what is DRAWN: point
its Object field at the `MeshInstance3D`, not at the CharacterBody3D it hangs under.

**And one thing Retire After Seconds cannot know.** Godot drops a timer's connection when the
object at the far end of it is freed, which is what makes the destroy twin need no bookkeeping. A
POOLED object is never freed, so nothing is dropped: a copy that goes back to its pool early and is
handed out again inside the wait is retired by that timer in the middle of its NEXT life. Where a
copy can be retired early, use Retire on its own.

**On Retired is one trigger for both endings.** A pool takes a node back by removing it from the
tree, and a free takes it out of the tree as well, so the node's own `tree_exiting` is raised once
whichever of the two happened. The object is still valid inside that handler, which is what makes it
the place to let go of what it was holding, drop it from a list, or tell somebody else it is gone.

**Retire is safe to run twice.** Something already on its way out, or already parked back in its
pool, is left alone rather than handed over a second time - and that guard matters more here than it
does for a destroy, because a double `queue_free()` is silent while a free list holding one node
twice hands the same node to two callers at once.

## The same sentences over the network

There is no second spawning vocabulary for a networked game. Godot's own answer is a
`MultiplayerSpawner` node, and it already has rows: **Spawn A Scene** makes one copy on the host and
on every peer at once, **Despawn** takes a copy out everywhere, and **On Spawned** / **On Despawned**
are the triggers that say a copy arrived or left. They are the shipped multiplayer words, unchanged
by anything on this page.

Spawn A Scene writes four lines, and the order in them is the whole difference from a local spawn:
the copy is NAMED before it joins the tree, because the name is what travels to the other peers and
is how the peer that owns it is worked out on the far side.

```
var __spawn_1 = load("res://player.tscn").instantiate()
__spawn_1.name = str(id)
__spawn_1.position = Vector2.ZERO
self.get_node(self.spawn_path).add_child(__spawn_1, true)
```

Which one to reach for is decided by who has to see the copy, and nothing else:

- **Only this machine has to see it** - a muzzle flash, a shell casing, a hit spark, a floating
  damage number. Spawn A Copy. Sending it would be bandwidth spent on something nobody checks.
- **Everybody has to agree it exists** - a player, an enemy, a pickup, a projectile that can hit
  somebody. Spawn A Scene, run on the host, with the scene in that spawner's own list.

The rest of this page still applies to both. A networked copy is an ordinary node once it lands, so
it can join a crowd, be counted by How Many Alive, and be the last one whose destruction opens the
door. The one row not to mix in is Destroy Now on a copy the spawner owns: **Despawn** is the
removal that travels, and freeing the copy on one peer alone leaves the others holding it.

## What the sheet says it spawns

A sheet that spawns has its most important fact buried halfway down it: the scenes it makes copies
of are one parameter at a time, and the cap that keeps the count sane is buried beside them. The
head of the sheet says it instead, one **spawns** band per scene, above the first event:

```
spawns   enemy.tscn - at most 12 in enemies
spawns   bullet.tscn - pooled as shots
spawns   coin.tscn
spawns   and 3 more scene(s) spawned
```

Nothing on those bands was authored. Each one is read back out of the sheet's own rows - the scene a
spawn row names, the crowd and cap a crowd row puts on it, the pool an Object Pool row takes it from
- joined once when the sheet opens with what the attached scene says, which is any scene a
MultiplayerSpawner in it is allowed to make. A scene with neither a cap nor a pool reads as its own
name and nothing more, because "no cap" is what the absence of a cap means.

The last line is the band scale law: the head names what fits and counts the rest, so a sheet that
spawns twenty things still has a head you can read. Clicking a band shows that scene in the
FileSystem dock; the counting line has no file behind it, and says so.

Hand-written spawning is on the band too. An opened `.gd` whose lines read
`var b = Bullet.instantiate()` grows the same band as a picked row, because the band is read off the
line rather than off a row's name.

## The five things that go wrong

Five spawning mistakes are silent in the editor and loud at run time. The Doctor has a **Spawning**
section for them, and each one is also said in place - an amber note under the very row that has it,
with its one click at the right edge.

The notes under your rows are complete: they are worked out from the sheet you are looking at, every
time the canvas rebuilds. The Doctor's project-wide section is a SAMPLE, because reading a script's
rows means opening it as a sheet and that costs about half a second each. It pre-reads the text,
ranks the candidates by how much their own text says they could earn, and opens the strongest few -
and its summary line says how many candidates there were and how many were read, so a sampled run
never reads as a clean bill of health. **How many is a count, not a stopwatch**: the same project
audited on a laptop and on a build server reports the same findings, because a report that changes
without the project changing is not one you can act on.

**A node added while physics is busy.** Godot refuses to add a child while the physics server is
flushing its queries, which is most of what a collision callback is, and the error names a line
nobody was looking at. Any parenting inside `_physics_process`, a body callback or an area callback
earns the note. One click respells it: a verbatim line becomes `call_deferred("add_child", …)` in
place, and a Spawn A Copy row is swapped for Spawn A Copy Safely, which takes the same parameters.
The status line shows the line before and the line after, and the whole thing is one undo step.

**A reference that may already be gone.** A node kept in a variable outlives the frame that put it
there, and Godot's answer is `is_instance_valid`. The note appears on a stored node this sheet also
destroys somewhere - the sheet's own word that the reference can really be dangling - and only where
nothing above the row has already asked. "Guard it" adds an Is Still Here condition to the event: an
ordinary condition row you can see, edit and delete, and a plain `if` on disk. The three destroy
rows are never noted, because the compiler already writes the guard for them.

**A scene that spawns itself.** A scene whose own sheet spawns that same scene when a copy is
created, with nothing in the way, doubles every time the event is reached. That is a hang rather
than an error, so there is no line to point at afterwards. It is reported as an error and carries no
repair, because the answer is a decision about the game. A spawn of the same scene under a condition
- a boss that splits when it is hit - is a game, and is never reported.

**Freed, and still booked.** A row that destroys a node and a later row in the same event that hangs
a timer or a tween on it are in the wrong order: the destroy is marked at once, and the wait is then
booked against something on its way out. "Move the destroy last" puts it after everything that reads
it; destroying after a delay instead is the other way, and the note says so.

**A copy of a scene the node never came from.** Spawn A Copy Of Myself loads the file this node was
built from, and a node built in code rather than instanced from a `.tscn` was built from no file at
all. The row is then a load of nothing: no copy appears, and Godot says nothing about it, because
loading an empty path is not an error. It is reported as information rather than as a repair,
because the answer is a decision about the scene - save the branch as a scene file and instance
that, or spawn a scene the row names outright.

## Reference tables

| Name | What it does | Ships as |
|------|--------------|----------|
| Spawn A Copy | Makes a copy of a scene, adds it under a parent and places it. | `var {name} = {scene}.instantiate()`, `{parent}.add_child({name})`, `{name}.global_position = {at}` |
| Spawn A Copy Safely | The same spawn, added on the next idle moment. | `var {name} = {scene}.instantiate()`, `{name}.position = {at}`, `{parent}.call_deferred("add_child", {name})` |
| Make A Copy | Makes a copy and names it, without adding it to the tree. | `var {name} = {scene}.instantiate()` |
| Place Of | Gives a node's own place in the world. | `{node}.global_position` |
| Random Place Along Path | Gives a random point along a Path2D's curve. | `{path}.to_global({path}.curve.sample_baked(randf() * {path}.curve.get_baked_length()))` |
| Random Place Inside Shape | Gives a random point inside a collision shape. | `{shape}.to_global(…)` |
| Random Place Off Screen Edge | Gives a random point just outside a screen edge. | `(get_viewport().get_canvas_transform().affine_inverse() * …)` |
| Spawn A Copy (3D) | The same three statements, on a Node3D host. | `var {name} = {scene}.instantiate()`, `{parent}.add_child({name})`, `{name}.global_position = {at}` |
| Spawn A Copy Safely (3D) | The same 3D spawn, added on the next idle moment. | `var {name} = {scene}.instantiate()`, `{name}.position = {at}`, `{parent}.call_deferred("add_child", {name})` |
| Place Of (3D) | Gives a node's own place in the world, as a Vector3. | `{node}.global_position` |
| Random Place Inside Box | Gives a random point inside a BoxShape3D or a CSG box. | `({box} as Node3D).to_global(…)` |
| Random Place Inside Sphere | Gives a random point spread evenly through a sphere. | `({ball} as Node3D).to_global(… * pow(randf(), 1.0 / 3.0))` |
| Random Place Around (3D) | Gives a random point on a ring around a node. | `{node}.global_position + Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * {radius}` |
| Destroy Now | Destroys the object at the end of this frame. | `{object}.queue_free()` |
| Destroy After Seconds | Destroys the object after a wait, without blocking. | `get_tree().create_timer({seconds}).timeout.connect({object}.queue_free)` |
| Fade Out Then Destroy | Fades the object out, waits, then destroys it. | `await {object}.create_tween().tween_property({object}, "modulate:a", 0.0, {seconds}).finished`, `if is_instance_valid({object}):`, `{object}.queue_free()` |
| Is Still Here | True while the object has not been destroyed. | `is_instance_valid({object})` |
| Spawn A Copy Into The Crowd | The spawn, with the copy joined to a group named after the scene. | `var {name} = {scene}.instantiate()`, `{name}.add_to_group({crowd}, true)`, `{parent}.add_child({name})`, `{name}.global_position = {at}` |
| Spawn A Copy, The First Makes Room | Makes room by destroying members from the front, then spawns. | `var crowd_{name} = get_tree().get_nodes_in_group({crowd}).filter(…)`, `while crowd_{name}.size() >= maxi({cap}, 1):`, `crowd_{name}.pop_front().queue_free()`, … |
| Spawn A Copy Unless The Crowd Is Full | Spawns only while there is room, and skips otherwise. | `var crowd_{name} = get_tree().get_nodes_in_group({crowd}).filter(…)`, `var {name}: Node = null`, `if crowd_{name}.size() < {cap}:`, … |
| How Many Alive | How many of a crowd are alive right now. | `get_tree().get_node_count_in_group({crowd})` |
| On The Last One Destroyed | Runs when a crowd's last member leaves, once per emptying. | `get_tree().node_removed.connect(_on_node_removed)` |
| Crowd Is Down To This One | The gate under that trigger. | `{node}.is_in_group({crowd}) and {node}.is_queued_for_deletion() and get_tree().get_nodes_in_group({crowd}) == [{node}]` |
| On Node Joins Group | Runs as a node belonging to a group enters the world. | `get_tree().node_added.connect(_on_node_joined_group)` |
| On Node Leaves Group | Runs as a node belonging to a group leaves the world. | `get_tree().node_removed.connect(_on_node_left_group)` |
| Spawn In A Formation | Spawns several copies at once, arranged in the shape you pick. | `var {name}_scene = {scene}`, `for {name}_index in range({count}):`, `var {name} = {name}_scene.instantiate()`, `{name}.add_to_group({crowd}, true)`, `var {name}_place = …`, … |
| Spawn In A Formation (3D) | The same loop with the five shapes measured in three dimensions. | `var {name}_scene = {scene}`, `for {name}_index in range({count}):`, …, `var {name}_place = …`, … |
| Spawn A Copy, Facing And Moving | Spawns a copy, turns it to face something, launches it along that facing. | `var {name} = {scene}.instantiate()`, `{parent}.add_child({name})`, `{name}.global_position = {at}`, `{name}.rotation = …`, `var {name}_launch = Vector2.from_angle({name}.rotation) * {speed}`, … |
| Spawn A Copy, Facing And Moving (3D) | The same, with forward being the copy's own -Z. | `var {name} = {scene}.instantiate()`, …, `{name}.look_at({toward}.global_position)`, `var {name}_launch = -{name}.global_transform.basis.z * {speed}`, … |
| Spawn A Copy Of Myself | Makes one more copy of the scene this node was built from. | `var {name} = load(scene_file_path).instantiate()`, `{parent}.call_deferred("add_child", {name})`, `{name}.set_deferred("global_position", {at})` |
| Spawn A Copy Of Myself (3D) | The same row, offered on a 3D host. | `var {name} = load(scene_file_path).instantiate()`, `{parent}.call_deferred("add_child", {name})`, `{name}.set_deferred("global_position", {at})` |
| Free Spot In | Gives a point inside a shape that nothing is standing in, or nothing. | `FreeSpot.in_2d({inside}, {scene}, {clear_of}, {gap}, {tries})` |
| Free Spot In (3D) | The same question in three dimensions, in metres. | `FreeSpot.in_3d({inside}, {scene}, {clear_of}, {gap}, {tries})` |
| Spawn A Copy In A Free Spot | Spawns a copy where nothing is standing, or nothing at all. | `var {name}_spot = FreeSpot.in_2d(…)`, `var {name} = null`, `if {name}_spot == null:`, `emit_signal(&"spawn_skipped", {scene})`, `else:`, … |
| Spawn A Copy In A Free Spot (3D) | The same row in three dimensions. | `var {name}_spot = FreeSpot.in_3d(…)`, `var {name} = null`, `if {name}_spot == null:`, …, `else:`, … |
| On Spawn Skipped | Runs when a free-spot spawn found nowhere to put the copy. | `spawn_skipped.connect(_on_spawn_skipped)` |
| Retire | Hands the object back to its pool, or destroys it when it came from none. | `PooledNodes.retire({object})` |
| Retire After Seconds | The same decision, taken after a wait, without blocking. | `get_tree().create_timer({seconds}).timeout.connect(PooledNodes.retire.bind({object}))` |
| Fade Out Then Retire | Fades the object out, waits, puts its transparency back, then retires it. | `await {object}.create_tween().tween_property({object}, "modulate:a", 0.0, {seconds}).finished`, `if is_instance_valid({object}):`, `{object}.modulate.a = 1.0`, `PooledNodes.retire({object})` |
| Fade Out Then Retire (3D) | The same on a GeometryInstance3D, walking transparency up instead. | `await {object}.create_tween().tween_property({object}, "transparency", 1.0, {seconds}).finished`, `if is_instance_valid({object}):`, `{object}.transparency = 0.0`, `PooledNodes.retire({object})` |
| On Retired | Runs as the object is retired, whichever of the two happened. | `tree_exiting.connect(_on_retired)` |

## Use cases

**1. One enemy at a marker.** Drop a Marker2D called SpawnPoint, then one row. Moving the marker in
the editor moves the spawn, and the sheet never changes.

```
Every tick
    spawn timer <= 0
    -> System  Spawn a copy of Enemy as new_enemy at $SpawnPoint.global_position, under $Enemies
```

**2. Tagging the copy as it arrives.** Add an Add To Group row right after the spawn and put
`new_enemy` in its target. The name is already in scope, so there is nothing to look up.

**3. Setting the copy up in one event.** After the spawn, a Set Property row on `new_enemy` for
health, another for the tier, another for its tint. All of them read as sentences about the copy.

**4. A bullet that knows who fired it.** Spawn the shot, then set `new_shot.shooter` to `self` and
`new_shot.direction` to the facing. Two rows, no signal, no lookup.

**5. A spawn from a collision.** In an On Body Entered event, use Spawn A Copy Safely. The immediate
row would hit Godot's "parent node is busy" error; the safe row waits for the physics step to finish
and says so on the row.

**6. Keeping spawns off the spawner.** Put a plain Node2D called Enemies in the scene and name it in
the Under field. Freeing the spawner then does not take the wave with it.

**7. A wave arriving from off screen.** Use Random Place Off Screen Edge in the At field. Each copy
picks a fresh edge, so a wave surrounds the player instead of queueing at one side.

**8. Loot scattered in a zone.** Draw an Area2D over the room, then use Random Place Inside Shape
with its CollisionShape2D. Every drop lands somewhere inside the room you drew.

**9. Pickups along a patrol route.** Random Place Along Path over the Path2D the guards already
follow, inside a Repeat 8 times loop.

**10. A rotated spawn.** Spawn the copy, then a Set Property row for `new_enemy.rotation` on the next
line. The placement expression answers where, and an ordinary property row answers how it is turned.

**11. Setting a copy up before it joins the tree.** Use Make A Copy, then property rows on the name,
then an Add Child row. Nothing enters the scene half-configured, and no `_ready` runs early.

**12. Spawning under the mouse.** Put the cursor's world position in the At field. The placement
field is an expression, so anything that gives a position works.

**13. A spawn that is one of several scenes.** Put a pick from a list in the Scene field
(`enemy_scenes.pick_random()`), and the same row spawns a random kind.

**14. A boss with attached parts.** Spawn the boss, then spawn each part with the boss's name in the
Under field. The parts are children of the copy the same event just made.

**15. Reading a hand-written spawn.** Open a script that already says
`var b = Bullet.instantiate()` and an `add_child(b)` beside it. The sheet reads them as one sentence
with `b` kept as the name, and saving the file writes back the same bytes.

**16. Spawning without placing.** Leave At as `global_position` and the copy appears exactly where
the spawner is - a muzzle flash, a shield, a shadow that belongs on the spot.

**17. A trail of copies.** Spawn a fading mark every few frames at `global_position`, under a Marks
layer node so the trail is easy to clear later.

**18. A bullet that cleans itself up.** One Destroy After Seconds row on `self` in the bullet's own
On Ready event. No lifetime counter, no per-frame check, and nothing left behind if it hits first.

**19. A corpse that fades.** Fade Out Then Destroy on `self` in the death event, over half a second.
The event waits for the fade, so anything after it runs once the body is gone.

**20. Destroying a copy from a later event.** Spawn the boss in one event and store nothing; say its
name in a Destroy Now row in another and the guard appears on the row, because that name has had a
frame to stop meaning anything.

**21. Clearing a stored reference.** A sheet variable typed `Node2D` holding the current target: a
Destroy Now row on it compiles inside the guard, and a Set Variable row to `null` beside it keeps the
variable honest afterwards.

**22. A wave you can hear finish.** Spawn the wave with Spawn A Copy Into The Crowd, then one On The
Last One Destroyed event on the same crowd opens the door, pays the reward and starts the next wave.
Nothing counts the enemies down; the trigger is the last one leaving.

**23. A skid-mark trail that never grows.** Spawn A Copy, The First Makes Room with a cap of 20 into
a `marks` crowd. The twenty-first mark destroys the first, so the trail is always the last twenty and
the tree never fills - including on a frame that lays down several marks at once, because the row
skips the marks already on their way out rather than destroying one of them twice.

**24. A spawner that respects a limit.** Spawn A Copy Unless The Crowd Is Full with a cap of 12. A
timer that fires every second simply does nothing while twelve are alive, and starts again when one
dies - no counter to keep and no flag to clear.

**25. Enemies remaining, on the HUD.** Put How Many Alive in a Set Text row, on the same per-frame
event the rest of the HUD uses. It reads the group, so it can never disagree with what is on screen.

**26. Difficulty that follows the crowd.** Compare How Many Alive to a number in a condition, and
spawn a tougher kind while the crowd is thin.

**27. A crate you can clear.** Tag every breakable into a `crates` crowd as it spawns, and let On The
Last One Destroyed on that crowd drop the key.

**28. A ring of enemies around a totem.** Spawn In A Formation with the ring shape, a count of six
and the totem in Around. One row, and the row underneath addresses all six with For Each In Group.

**29. A firing arc.** The same row with the arc shape, a start angle and a sweep of 120. The first
copy sits on the start angle and the last on the far end, which is what "from here to there" means.

**30. An inventory grid that fills itself.** The grid shape with Across set to the number of columns
and Size set to the spacing. Adding a row of slots is changing one number.

**31. A shot that leaves the barrel aimed.** Spawn A Copy, Facing And Moving with the mouse facing
and the muzzle in At. The copy is turned and launched in the same row, in the right order.

**32. A shot from a moving ship.** The same row with Plus This Node's Speed ticked, so a shot fired
forwards leaves the ship faster and one fired backwards leaves it slower.

**33. A slime that halves.** Spawn A Copy Of Myself in the hit event, under a condition on the
slime's own size, with a property row after it setting the copy's size. No file is named anywhere.

**34. A room that fills until it is full.** Spawn A Copy In A Free Spot on a timer, with the room's
Area2D in Inside and the walls in Clear Of, and an On Spawn Skipped event that stops the timer.

**35. A minefield with no two mines on one tile.** The same row with a gap of 48, so every mine is
laid clear of the ones already down rather than on top of one.

**36. A pooled bullet that puts itself away.** Retire on the bullet's own hit event. In a project
with no pools it is a destroy; the day the bullets are pooled, nothing in the sheet changes.

**37. Letting go of what a copy was holding.** An On Retired event on the copy, which runs whichever
way it left, with rows that clear its target and drop it from a list.

### Other use cases

**A ghost replay.** Spawn a copy of the player scene as `ghost`, disable its input flag on the next row, and let a recorded path drive it.

**A shop that fills itself.** Repeat over the stock list, spawning one item card per entry with Random Place Along Path down the shelf.

**A weather system.** Spawn a raindrop at Random Place Off Screen Edge every tick with a small margin, so drops enter from the top and the sides.

**A minefield.** Repeat 20 times, spawning a mine at Random Place Inside Shape over the level's Area2D, then tagging each one.

**A fireworks burst.** Repeat 12 times inside one event, spawning a spark at `global_position` and setting each one's direction from the loop index.

## Tips and common mistakes

- **A name is only in scope inside its own event.** `new_enemy` is a local variable. A row in the
  next event that says it will not compile - which is the honest answer. Store what you need in a
  sheet variable, or put the follow-up rows in the same event.
- **Do not reuse one name twice in one event.** Two Spawn A Copy rows both called `new_enemy` declare
  the same variable twice and the file will not compile. Give the second one its own name.
- **`add_child` inside a physics callback fails.** If Godot logs "parent node is busy setting up
  children", the fix is Spawn A Copy Safely, not a retry.
- **The safe row's At is relative to the parent.** It sets `position`, not `global_position`, because
  the copy is not in a tree yet. Under a parent at the origin the two are the same; under a moved
  parent they are not.
- **A scene field wants a PackedScene, not a path.** `Enemy` (a declared preload) or
  `load("res://enemy.tscn")` both work; a bare `"res://enemy.tscn"` string does not, because a string
  has no `instantiate()`. The Spawn Scene rows are the ones that take a path.
- **`preload` needs a path that exists at build time.** A path assembled at runtime has to be
  `load()`, and a missing file gives null - guard it if the path can be wrong.
- **Random Place Inside Shape wants the CollisionShape2D, not the Area2D.** The shape is what has the
  size; the area is what owns the shape.
- **A shape that is not a rectangle or a circle gives its centre.** That is deliberate rather than a
  bug: scattering evenly inside an arbitrary polygon is a loop, not an expression. Use a rectangle or
  a circle for the zone, or write the loop yourself.
- **Random Place Along Path needs a baked curve.** A Path2D with an empty curve has no length, so
  the row gives the path's own position - and Godot prints `No points in Curve2D.` every single time
  the line is evaluated, which on a per-frame spawner is a flooded log rather than a quiet
  degradation. Draw the curve first.
- **A rotated spawn zone stays rotated.** Both sampling words go through `to_global`, so the point
  comes out inside the shape you actually drew and along the curve where it actually runs, whatever
  the node or its parents are turned or scaled to.
- **Spawning every tick fills the tree fast.** Put a cooldown, a counter or a Once At A Time condition
  above the row - a spawn is cheap, ten thousand of them are not.
- **Free what you spawn.** Nothing here tracks copies. A wave that never ends is a wave nobody
  freed; a Destroy Now row on the copy's own death trigger is usually the whole answer.
- **A destroyed node is still there for the rest of the frame.** `queue_free()` queues; it does not
  delete. A row after the destroy that reads the object still works, and a check that expects it to
  be gone in the same frame does not.
- **Freeing the same node twice is SILENT.** A second `queue_free()` on one node in one frame prints
  nothing at all - no error, no warning - and the node simply dies once. (That is `queue_free`; a
  second `free()` is the one that errors.) So a loop that picks a member, frees it and picks again
  from the same list will happily free the same one over and over with nothing in the log to say so,
  which is exactly how a cap stops capping. Ask Is Still Here before reaching in, skip the members
  that answer `is_queued_for_deletion()`, or let the guard do it by naming a stored reference rather
  than a path.
- **The fade row makes the event wait.** Everything after it in that event runs after the fade. If
  you want the event to carry straight on, use Destroy After Seconds instead.
- **The fade needs something with `modulate`.** It walks `modulate:a`, so the object has to be a
  CanvasItem. A plain Node has no transparency to walk. The 3D fade needs a `GeometryInstance3D` for
  the same reason: `transparency` belongs to what is drawn, not to the body it hangs under.
- **A crowd is a plain Godot group.** Anything else in the project that uses groups sees the same
  members, which is usually what you want and occasionally a surprise. Name crowds after the scene
  they hold and the two stay easy to tell apart.
- **The persistent flag is the one thing not to remove.** Emitted crowd rows pass `true` to
  `add_to_group`. Editing that out looks harmless and breaks every count the day the branch is packed
  into a scene file.
- **The cap rows are two rows, not one row with a setting.** If a spawn keeps vanishing, you picked
  the skip row; if an old one keeps vanishing, you picked the make-room row. The sentence on the row
  says which.
- **"The first in the crowd" means the member Godot lists first.** Under a parent that spawns by
  adding children that is the earliest one alive. Reparent members yourself, or spread them over two
  parents, and the order is the tree's, not the spawn's.
- **The cap rows ignore members already on their way out; How Many Alive does not.** A member is in
  its group until the end of the frame it was destroyed in, so the count can read one higher than the
  cap for the rest of that frame. That is queue_free, not a miscount - and it is exactly why the cap
  rows skip those members instead of counting or freeing them a second time.
- **The skipped spawn leaves the name holding nothing.** Rows after Spawn A Copy Unless The Crowd Is
  Full run either way, so ask Is Still Here before touching the name if the crowd can be full.
- **On The Last One Destroyed never fires for a crowd that was already empty.** It answers a member
  leaving, so a crowd nothing ever joined has no last member to destroy.
- **Moving the last member to another parent is not the crowd emptying.** `Node.reparent()` leaves
  the tree, so the signal fires, but the member is alive - the gate asks whether it is really being
  destroyed as well. The other side of that: a member taken out without a `queue_free` of its own,
  such as its whole branch being freed at once, is not seen by this trigger. Use On Group Emptied
  there.
- **Do not delete the gate condition under that trigger unless you mean it.** Without it the event
  runs for every node removed anywhere in the game.
- **A guard you did not ask for is telling you something.** It appears only on a name that can
  already be gone. If you would rather not see it, keep the destroy in the event that made the copy,
  or ask Is Still Here yourself.
- **A kinds table is one row's worth of choice, not a place to hide setup.** If a kind needs its own
  rows after the spawn, give it its own event. A dictionary that has grown a branch inside it has
  turned back into the chain it replaced.
- **A missing key in a kinds table is a crash, not a blank.** `KINDS["archr"]` errors. Spell the
  keys once, in the Declare row, and read them from there (`KINDS.keys()`) rather than typing the
  same word again in a spawn row.
- **A despawned copy remembers everything.** Pooling replaces the free, not the reset: health,
  alpha, velocity and any timer the copy was running are exactly as it left them. Set what a fresh
  copy would have had on the rows straight after the pool's Spawn, or give the scene a `reset()`
  method, which the pool calls on every spawn. The two fade-then-retire rows put back the one
  property THEY moved, and nothing else.
- **A wait booked against a pooled copy outlives the life it was booked in.** Godot drops a timer's
  connection when the object at the far end is freed, and a pooled object is never freed - so Retire
  After Seconds, and any delay booked against a copy that can go back to its pool early, can fire in
  the middle of that copy's next life.
- **Do not free a pooled copy.** Destroy Now on a node that came out of a pool takes it out of the
  pool's own accounting, and the pool then hands out a freed node. Despawn is its removal, and
  Retire is the row that picks between the two for you.
- **A formation of one lands on its start.** Every shape divides by the count, and the arc and the
  line divide by one less than it, so a count of one is protected rather than a division by zero.
- **An arc that sweeps 360 puts its first and last copy on top of each other.** That is what the
  ring shape is for instead: it divides the whole turn by the count, so the spacing is even.
- **Across has to be a whole number.** The line that lays a grid out divides by it, and integer
  division is what turns a running count into rows and columns.
- **Turning a copy needs it in the tree first.** The facing line measures from the copy's own global
  position, which means nothing until the copy has a parent - which is why the row writes the
  parenting first and the facing after it, and why writing it the other way by hand aims everything
  at the origin.
- **Plus This Node's Speed reads THIS node's velocity.** Only a body that moves has one. Leave it
  off on a turret bolted to a wall, or the emitted line names a property that is not there.
- **Spawn A Copy Of Myself in an On Ready event doubles for ever.** It is a scene that spawns itself
  the instant it is created, which is a hang rather than an error. Put it under a condition.
- **A node built in code has no scene file to copy.** `scene_file_path` is empty on anything that
  was never instanced from a `.tscn`, so the row loads nothing and no copy appears. Save the branch
  as a scene and instance that.
- **A free spot can answer nothing, and that is the point.** Rows after Spawn A Copy In A Free Spot
  run either way, so ask Is Still Here before touching the name, or answer On Spawn Skipped.
- **On Spawn Skipped needs the signal declared.** Add a signal block saying `spawn_skipped(scene)`
  at the head of the sheet. Without it the emitted guard simply finds no signal and the row spawns
  nothing quietly, which is the honest behaviour but not the one you wanted.
- **Free Spot In wants the shape, or the area, or the Control.** In 2D it reads a CollisionShape2D
  holding a rectangle or a circle, the Area2D around it, or a Control's own rectangle; in 3D a
  CollisionShape3D holding a box or a sphere, or the Area3D around it. Anything else measures
  nothing and the call answers nothing.
- **A gap of nothing asks nothing.** Set Gap to 0 and the only question left is whether the copy's
  own shape overlaps a member of the named groups. That is right for a scene with a shape, and
  leaves a shapeless scene with no test at all.
- **Retire and Destroy Now are the same thing in a project with no pools.** Reach for Retire early:
  it costs nothing, and it is what saves the sheet being rewritten the day a profiler asks for a
  pool.
- **On Retired fires for both endings.** It is the node's own `tree_exiting`, so it runs whether the
  node was freed or handed back - and it also runs when the whole branch is taken out of the tree,
  which is usually what you want and occasionally a surprise.
- **Do not Destroy Now a copy a MultiplayerSpawner made.** It goes on this peer and stays on every
  other one. Despawn is the removal that travels.
