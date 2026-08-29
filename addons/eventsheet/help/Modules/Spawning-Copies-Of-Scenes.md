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
removing, and the mistakes live there:

- **Remove Now** - `queue_free()`, said plainly, with the end-of-frame timing on the row.
- **Remove After Seconds** - a scene-tree timer with the free hung off it.
- **Fade Out Then Remove** - a tween, a wait, and the removal after it.
- **Is Still Here** - the question, for a name the sheet held on to.

A node that wants to hear about its OWN removal uses the shipped **On Exit Tree** trigger, which
fires as it leaves the tree. That is a lifecycle handler rather than a removal verb, so it stays
where it is.

Six more say the copies in the plural, because a game that spawns one thing soon spawns twenty:

- **Spawn A Copy Into The Crowd** - the same spawn, with the copy joined to a group named after the
  scene.
- **Spawn A Copy, Oldest Goes First** and **Spawn A Copy Unless The Crowd Is Full** - the cap, with
  what happens at the cap written into the row's own sentence.
- **How Many Alive** - the group's size, in any field that takes a number.
- **On The Last One Removed** and **Crowd Is Down To This One** - the trigger for a crowd emptying,
  and the question it puts in the sheet underneath itself.

## Table of Contents

1. [Where this shines](#where-this-shines)
2. [Core concepts](#core-concepts)
3. [Removing what you spawned](#removing-what-you-spawned)
4. [The crowd](#the-crowd)
5. [What the sheet says it spawns](#what-the-sheet-says-it-spawns)
6. [The four things that go wrong](#the-four-things-that-go-wrong)
7. [Reference tables](#reference-tables)
8. [Use cases](#use-cases)
9. [Tips and common mistakes](#tips-and-common-mistakes)

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
- **Nothing here needs the plugin at runtime.** Every row compiles to `instantiate()`, `add_child`,
  `call_deferred`, `randf()` and arithmetic. Uninstall the editor and the game still builds.

## Removing what you spawned

Removing a node in Godot is `queue_free()`. The three removal rows are that call with the wait each
one does written out beside it, so the only thing you ever have to decide is WHEN.

```
enemy.queue_free()                                              # now, meaning end of frame
get_tree().create_timer(2.0).timeout.connect(enemy.queue_free)  # in two seconds
```

**"Now" means the end of this frame, not this line.** `queue_free()` marks the node and Godot
deletes it when the frame finishes. The rows after it in the same event still run, and the node is
still there while they do. That is not a quirk to work around - it is why a sheet can remove a thing
and then read its position on the very next row without crashing.

**The timer row is safe if the thing is already gone.** Godot drops a signal connection along with
the object at the far end of it, so something else removing the node first takes the pending free
with it and the timer fires at nothing.

**The fade row waits, so the event waits.** It walks `modulate:a` down to nothing with a tween,
awaits the tween, and then removes. Because that wait is a real gap in game time, the row asks
whether the object is still there before it removes it, and the line that asks is part of the row's
own code rather than something added quietly.

### The guard, and why you can see it

A name that outlives the line that set it can name nothing at all by the time a later row says it.
There are exactly two of those in a sheet: a **variable typed as a node** (it survives from frame to
frame) and a **copy a spawn row minted in a different event**. When a removal row's object is one of
those, the compiler writes the check Godot's own answer calls for:

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

**Nothing else is guarded.** `self` cannot dangle, a `$Path` re-resolves every time it is read, and
every row outside these three is left exactly as it was. Emitted code does not change under your
feet.

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

**Spawn A Copy, Oldest Goes First** removes a member to make room and then spawns, so the new copy
always appears:

```
var crowd_new_mark = get_tree().get_nodes_in_group("marks")
if crowd_new_mark.size() >= maxi(20, 1):
	crowd_new_mark[0].queue_free()
var new_mark = Mark.instantiate()
```

The crowd is read once into a local, because the row needs both the size and the member it is about
to remove. `maxi(cap, 1)` is what makes `[0]` always safe: the branch cannot run on an empty crowd,
whatever number you typed. The one removed is the member Godot lists first, which under a parent
that spawns by adding children is the earliest one still alive. This is what a bullet, a footstep or
a skid mark wants.

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

### Counting them, and missing them

**How Many Alive** is the group's own size, `get_tree().get_node_count_in_group("enemies")`. It is an
expression, so it goes in any field: a comparison, a HUD label, a difficulty curve.

**On The Last One Removed** runs the moment a crowd's last member leaves the world, once per
emptying. It is the scene tree's own node-removed signal, and the question that narrows it to this
crowd is a **condition row you can see**:

```
func _ready() -> void:
	get_tree().node_removed.connect(_on_node_removed)

func _on_node_removed(node: Node) -> void:
	if node.is_in_group("enemies") and get_tree().get_nodes_in_group("enemies") == [node]:
		...
```

Picking the trigger adds that condition underneath it, filled in with the crowd you typed. It is an
ordinary row: editable, deletable, and a plain `if` on disk. **A leaving node is still listed in its
groups at that moment**, which is why "the crowd is down to just the one that is going" is exactly
"this was the last one".

The shipped **On Group Emptied** condition asks the same question a different way - on a per-frame
trigger, by remembering last tick's count. It is unchanged and still the answer when you want the
check to ride an existing tick. This trigger needs neither the tick nor the memory.

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

## The four things that go wrong

Four spawning mistakes are silent in the editor and loud at run time. The Doctor has a **Spawning**
section for them, and each one is also said in place - an amber note under the very row that has it,
with its one click at the right edge.

The notes under your rows are complete: they are worked out from the sheet you are looking at, every
time the canvas rebuilds. The Doctor's project-wide section is a SAMPLE, because reading a script's
rows means opening it as a sheet and that costs about half a second each. It pre-reads the text,
ranks the candidates by how much their own text says they could earn, and opens the strongest few -
and its summary line says how many candidates there were and how many were read, so a sampled run
never reads as a clean bill of health.

**A node added while physics is busy.** Godot refuses to add a child while the physics server is
flushing its queries, which is most of what a collision callback is, and the error names a line
nobody was looking at. Any parenting inside `_physics_process`, a body callback or an area callback
earns the note. One click respells it: a verbatim line becomes `call_deferred("add_child", …)` in
place, and a Spawn A Copy row is swapped for Spawn A Copy Safely, which takes the same parameters.
The status line shows the line before and the line after, and the whole thing is one undo step.

**A reference that may already be gone.** A node kept in a variable outlives the frame that put it
there, and Godot's answer is `is_instance_valid`. The note appears on a stored node this sheet also
removes somewhere - the sheet's own word that the reference can really be dangling - and only where
nothing above the row has already asked. "Guard it" adds an Is Still Here condition to the event: an
ordinary condition row you can see, edit and delete, and a plain `if` on disk. The three removal
rows are never noted, because the compiler already writes the guard for them.

**A scene that spawns itself.** A scene whose own sheet spawns that same scene when a copy is
created, with nothing in the way, doubles every time the event is reached. That is a hang rather
than an error, so there is no line to point at afterwards. It is reported as an error and carries no
repair, because the answer is a decision about the game. A spawn of the same scene under a condition
- a boss that splits when it is hit - is a game, and is never reported.

**Freed, and still booked.** A row that removes a node and a later row in the same event that hangs a
timer or a tween on it are in the wrong order: the removal is marked at once, and the wait is then
booked against something on its way out. "Move the removal last" puts it after everything that reads
it; removing after a delay instead is the other way, and the note says so.

## Reference tables

| Name | What it does | Ships as |
|------|--------------|----------|
| Spawn A Copy | Makes a copy of a scene, adds it under a parent and places it. | `var {name} = {scene}.instantiate()`, `{parent}.add_child({name})`, `{name}.global_position = {at}` |
| Spawn A Copy Safely | The same spawn, added on the next idle moment. | `var {name} = {scene}.instantiate()`, `{name}.position = {at}`, `{parent}.call_deferred("add_child", {name})` |
| Make A Copy | Makes a copy and names it, without adding it to the tree. | `var {name} = {scene}.instantiate()` |
| Place Of | Gives a node's own place in the world. | `{node}.global_position` |
| Random Place Along Path | Gives a random point along a Path2D's curve. | `({path}.global_position + {path}.curve.sample_baked(randf() * {path}.curve.get_baked_length()))` |
| Random Place Inside Shape | Gives a random point inside a collision shape. | `({shape}.global_position + …)` |
| Random Place Off Screen Edge | Gives a random point just outside a screen edge. | `(get_viewport().get_canvas_transform().affine_inverse() * …)` |
| Remove Now | Removes the object at the end of this frame. | `{object}.queue_free()` |
| Remove After Seconds | Removes the object after a wait, without blocking. | `get_tree().create_timer({seconds}).timeout.connect({object}.queue_free)` |
| Fade Out Then Remove | Fades the object out, waits, then removes it. | `await {object}.create_tween().tween_property({object}, "modulate:a", 0.0, {seconds}).finished`, `if is_instance_valid({object}):`, `{object}.queue_free()` |
| Is Still Here | True while the object has not been removed. | `is_instance_valid({object})` |
| Spawn A Copy Into The Crowd | The spawn, with the copy joined to a group named after the scene. | `var {name} = {scene}.instantiate()`, `{name}.add_to_group({crowd}, true)`, `{parent}.add_child({name})`, `{name}.global_position = {at}` |
| Spawn A Copy, Oldest Goes First | Makes room by removing the first member, then spawns. | `var crowd_{name} = get_tree().get_nodes_in_group({crowd})`, `if crowd_{name}.size() >= maxi({cap}, 1):`, `crowd_{name}[0].queue_free()`, … |
| Spawn A Copy Unless The Crowd Is Full | Spawns only while there is room, and skips otherwise. | `var {name}: Node = null`, `if get_tree().get_node_count_in_group({crowd}) < {cap}:`, … |
| How Many Alive | How many of a crowd are alive right now. | `get_tree().get_node_count_in_group({crowd})` |
| On The Last One Removed | Runs when a crowd's last member leaves, once per emptying. | `get_tree().node_removed.connect(_on_node_removed)` |
| Crowd Is Down To This One | The gate under that trigger. | `{node}.is_in_group({crowd}) and get_tree().get_nodes_in_group({crowd}) == [{node}]` |

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

**18. A bullet that cleans itself up.** One Remove After Seconds row on `self` in the bullet's own
On Ready event. No lifetime counter, no per-frame check, and nothing left behind if it hits first.

**19. A corpse that fades.** Fade Out Then Remove on `self` in the death event, over half a second.
The event waits for the fade, so anything after it runs once the body is gone.

**20. Removing a copy from a later event.** Spawn the boss in one event and store nothing; say its
name in a Remove Now row in another and the guard appears on the row, because that name has had a
frame to stop meaning anything.

**21. Clearing a stored reference.** A sheet variable typed `Node2D` holding the current target: a
Remove Now row on it compiles inside the guard, and a Set Variable row to `null` beside it keeps the
variable honest afterwards.

**22. A wave you can hear finish.** Spawn the wave with Spawn A Copy Into The Crowd, then one On The
Last One Removed event on the same crowd opens the door, pays the reward and starts the next wave.
Nothing counts the enemies down; the trigger is the last one leaving.

**23. A skid-mark trail that never grows.** Spawn A Copy, Oldest Goes First with a cap of 20 into a
`marks` crowd. The twenty-first mark removes the first, so the trail is always the last twenty and
the tree never fills.

**24. A spawner that respects a limit.** Spawn A Copy Unless The Crowd Is Full with a cap of 12. A
timer that fires every second simply does nothing while twelve are alive, and starts again when one
dies - no counter to keep and no flag to clear.

**25. Enemies remaining, on the HUD.** Put How Many Alive in a Set Text row, on the same per-frame
event the rest of the HUD uses. It reads the group, so it can never disagree with what is on screen.

**26. Difficulty that follows the crowd.** Compare How Many Alive to a number in a condition, and
spawn a tougher kind while the crowd is thin.

**27. A crate you can clear.** Tag every breakable into a `crates` crowd as it spawns, and let On The
Last One Removed on that crowd drop the key.

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
- **Random Place Along Path needs a baked curve.** A Path2D with an empty curve has no length, and
  the row gives the path's own position. Draw the curve first.
- **Spawning every tick fills the tree fast.** Put a cooldown, a counter or a Once At A Time condition
  above the row - a spawn is cheap, ten thousand of them are not.
- **Free what you spawn.** Nothing here tracks copies. A wave that never ends is a wave nobody
  freed; a Remove Now row on the copy's own death trigger is usually the whole answer.
- **A removed node is still there for the rest of the frame.** `queue_free()` queues; it does not
  delete. A row after the removal that reads the object still works, and a check that expects it to
  be gone in the same frame does not.
- **Do not free the same node twice.** The second call errors. Ask Is Still Here first, or let the
  guard do it by naming a stored reference rather than a path.
- **The fade row makes the event wait.** Everything after it in that event runs after the fade. If
  you want the event to carry straight on, use Remove After Seconds instead.
- **The fade needs something with `modulate`.** It walks `modulate:a`, so the object has to be a
  CanvasItem. A plain Node has no transparency to walk.
- **A crowd is a plain Godot group.** Anything else in the project that uses groups sees the same
  members, which is usually what you want and occasionally a surprise. Name crowds after the scene
  they hold and the two stay easy to tell apart.
- **The persistent flag is the one thing not to remove.** Emitted crowd rows pass `true` to
  `add_to_group`. Editing that out looks harmless and breaks every count the day the branch is packed
  into a scene file.
- **The cap rows are two rows, not one row with a setting.** If a spawn keeps vanishing, you picked
  the skip row; if an old one keeps vanishing, you picked the oldest-first row. The sentence on the
  row says which.
- **"Oldest" means the member Godot lists first.** Under a parent that spawns by adding children that
  is the earliest one alive. Reparent members yourself and the order is the tree's, not the spawn's.
- **The skipped spawn leaves the name holding nothing.** Rows after Spawn A Copy Unless The Crowd Is
  Full run either way, so ask Is Still Here before touching the name if the crowd can be full.
- **On The Last One Removed never fires for a crowd that was already empty.** It answers a member
  leaving, so a crowd nothing ever joined has no last member to remove.
- **Do not delete the gate condition under that trigger unless you mean it.** Without it the event
  runs for every node removed anywhere in the game.
- **A guard you did not ask for is telling you something.** It appears only on a name that can
  already be gone. If you would rather not see it, keep the removal in the event that made the copy,
  or ask Is Still Here yourself.
