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

## Table of Contents

1. [Where this shines](#where-this-shines)
2. [Core concepts](#core-concepts)
3. [Reference tables](#reference-tables)
4. [Use cases](#use-cases)
5. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this shines

- **A wave of enemies** arriving from off screen, each one tagged as it lands.
- **A bullet** that has to be set up (damage, direction, shooter) the instant it exists.
- **Loot scattered inside a zone** you drew as an Area2D, rather than at a hand-typed point.
- **Pickups placed along a patrol path**, spread evenly by distance rather than by curve segment.
- **A spawn point you can move in the editor** without opening the sheet.
- **A spawn from a collision handler**, where Godot refuses an immediate `add_child`.
- **Keeping spawns under one layer node** so the scene tree stays readable at runtime.
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
- **Free what you spawn.** Nothing here tracks copies. A wave that never ends is a wave nobody freed;
  a Free Node row on the copy's own death trigger is usually the whole answer.
