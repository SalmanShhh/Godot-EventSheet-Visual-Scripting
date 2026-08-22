# Mirroring And Flipping

Which way something faces. A character who walks left has to look left, and the row that says so is
the same two words on every host that can do it: a sprite, a whole body with its hitbox and its ray,
a 3D model, a UI panel, the camera's view, one tile in a tilemap, or a drawn path. Each host emits
the honest line for THAT host rather than a sprite line pointed at something that cannot use it.

These are **builtin** rows - no pack to enable, no behavior to attach, no autoload. The picker files
every one of them on a single page, **Facing**, because the question a reader arrives with is "how do
I make this thing face the other way", and the answer differs only by which node they picked first.

| The node you picked | What mirroring means on it |
|---|---|
| Sprite2D, AnimatedSprite2D, Sprite3D, TextureRect | the node's own flip flag - the picture turns, nothing else does |
| any Node2D | the object's X scale - the whole object turns, children included |
| Node3D, Label3D | the object's X scale, which also flips the mesh's winding |
| Node3D, again | half a turn about the up axis, which flips nothing inside out |
| Control, SubViewportContainer | the pivot moved to the middle, then the X scale |
| Camera2D | the camera's zoom, negated - everything it sees turns |
| TileMapLayer | one cell's flip bit, keeping its tileset and its tile |
| Path2D | every point of the curve, mirrored about x = 0 |

## Table of Contents

1. [Where this shines](#where-this-shines)
2. [Core concepts](#core-concepts)
3. [Reference tables](#reference-tables)
4. [Use cases](#use-cases)
5. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this shines

- **Platformer facing** - one row that faces the way you move, instead of the same four lines in
  every character script.
- **Attacks that work both ways** - the hitbox, the muzzle and the ray turn with the body, so a
  sword swing lands on the left as well as the right.
- **Enemies that look at you** - a guard, a turret, a shopkeeper who turns toward whoever walked in.
- **Name plates and health bars** that stay readable while the character they sit on faces left.
- **3D characters** turned the honest way, without a negative scale turning the lighting inside out.
- **Mirrored UI** - a second player's HUD built from the same scene, laid out the other way round.
- **Rear-view mirrors and security monitors**, where what a sub-viewport shows must be reversed.
- **Mirror worlds** - a whole level played through a reversed camera.
- **One art asset covering both sides** of a corridor, a doorway or a cliff face.
- **Symmetric levels** - a patrol route or a platform path drawn once and reused facing the other way.

The `demo/showcase/mirror_and_flip/` showcase puts every one of them in one room:

![The Mirror and Flip showcase: the hero faces left, so its golden blade reaches left and its red
muzzle point has moved to the left hand, while the name plate above it still reads forwards. Behind
it, a panel whose text is mirrored, a tile row whose third tile is flipped, and a sub-viewport
showing a 3D twin that turns around rather than scaling itself negative.](../images/mirror-and-flip-showcase.png)

## Core concepts

### Mirror and flip

**Mirroring** turns something left-to-right, so what faced right now faces left. **Flipping** is the
same idea about the other axis: upside down, and back the right way up. The one thing worth learning
before anything else is **what** you mirrored. Mirroring a **sprite** sets that node's own flip flag,
so the picture turns and absolutely nothing else does: the hitbox stays where it was, the muzzle
point stays on the right, the ray keeps pointing the way it always pointed. Mirroring the **object**
negates the object's X scale, and every child comes along - picture, hitbox, muzzle, ray, all facing
the same way, because that is what a scale on a parent does. So: reach for **Set Mirrored** on a
Sprite2D, an AnimatedSprite2D, a Sprite3D or a TextureRect when the picture is genuinely all there is
(a background prop, a decoration, an icon); reach for **Set Mirrored (whole object)** on the Node2D
that owns the character when anything else has to turn too, which in a game with combat in it is
nearly always. On a Node3D the same question has a third answer, **Turn Around**, and it is usually
the right one.

### Which row lands on which node

The picker only offers a row where its host can actually do the thing, so most of the choosing is
done for you by clicking the right node first. Two names appear on more than one host and mean the
same thing said in that host's terms:

- **Set Mirrored** is the flag on a Sprite2D, a Sprite3D or a TextureRect, an X scale on a Node3D or
  a Label3D, and a pivot plus an X scale on a Control.
- **Is Mirrored** reads the flag on the four flag hosts, and reads `scale.x < 0.0` on a Node2D, a
  Node3D or a Control.

**Set Mirrored (whole object)** carries its qualifier in the name for exactly this reason: on the
sheet it should be impossible to confuse with the sprite row sitting next to it.

### The two idioms, and the child that must not come along

Two lines are what the whole-object row is nearly always written for, and each has a row so you write
it once instead of copying it into every character:

- **Face Direction Of Movement** faces the way the object is moving and leaves it facing that way
  when it stops, because the row only writes anything while the velocity is not zero.
- **Face Object** turns this object toward another one, comparing global X positions.

**Keep Upright** is the opposite job: a child that must NOT come along. A name plate, a health bar or
a damage number under a mirrored body has its text written backwards, and Keep Upright re-negates
that child's X scale so it stays readable while everything around it turns.

### Reading a hand-written facing line

An opened `.gd` file reads these words back, so a project that already writes facing by hand arrives
as rows rather than as a wall of verbatim code. `body.scale.x = -1.0` reads as
**Set mirrored (whole object)**, `body.scale.x = 1.0` as **Set not mirrored (whole object)**, and
`body.scale.x = -body.scale.x` as **Set mirrored (whole object)** too. The conditional forms keep
their reason: `body.scale.x = -1.0 if velocity.x < 0.0 else 1.0` reads as
**Set mirrored to moving left (whole object)** (and so does `body.scale.x = sign(velocity.x)`), while
`body.scale.x = -1.0 if target.global_position.x < global_position.x else 1.0` reads as
**Set mirrored to target is to the left (whole object)**.

Each other host reads in its own terms. `mesh.scale.x = -mesh.scale.x` reads as
**Set mirrored (flips the mesh's winding)** - the caveat is in the sentence, where it cannot be
missed. `panel.scale.x = -1.0` reads as **Set mirrored (UI)**. `mesh.rotate_y(PI)` reads as
**Turn around**, and so does `mesh.rotate_y(deg_to_rad(180))`. On a flag host, `sprite.flip_h = true`
reads as **Set mirrored**, `sprite.flip_h = dir < 0` as **Set mirrored when dir < 0**,
`sprite.flip_h = facing_left` as **Set mirrored to facing left**, and
`sprite.flip_v = is_upside_down` as **Set flipped to is upside down**. The questions read too:
`sprite.flip_h` is **Is mirrored**, `not sprite.flip_h` is **Is not mirrored**, and
`body.scale.x < 0.0` is **Is mirrored** as well.

The lines that make facing *work* are read as facing too, which is what makes a hand-written
character script legible at a glance:
`ray.target_position.x = absf(ray.target_position.x) * signf(scale.x)` reads as
**Ray follows facing**, the same shape on a Marker2D position reads as
**Spawn point follows facing**, `dust.local_coords = true` reads as **Particles follow facing**,
`plate.scale.x = signf(scale.x)` reads as **Keeps its text upright**, and an AnimationTree whose
`blend_position` is driven by the facing reads as **Animation - Faces the way it moves**.

The readings are deliberately narrow. A plain `body.scale.x = 2.0` still reads as
**Set scale.x to 2**, because an X scale is a SIZE far more often than it is a mirror, and a
confident sentence about facing on a line that was only resizing something would be worse than the
code it replaced.

## Reference tables

The **Ships as** column is the emitted GDScript with **On node** left blank. Filling On node in
prefixes that line with the node you picked, and changes nothing else.

### Sprites, 3D sprites and texture rects

The four hosts that own a real flip flag. They share no base class that has it, which is why each one
is its own row - and why the picker can offer it only where the host can do it.

| Name | What it does | Ships as |
|------|--------------|----------|
| Set Mirrored | Mirrors this node's picture left-to-right - the way a 2D character faces. On Sprite2D, Sprite3D and TextureRect. | `flip_h = {mirrored}` |
| Set Flipped | Turns this node's picture upside down, or puts it back the right way up. On Sprite3D, TextureRect and AnimatedSprite2D. | `flip_v = {flipped}` |
| Is Mirrored | True while this node's picture is mirrored - which way the character is facing. | `flip_h` |
| Is Flipped | True while this node's picture is upside down. | `flip_v` |

### A whole 2D object

No flag here: mirroring is the object's own X scale, and the whole object turns. That is the point -
its children, the hitbox, the muzzle and the ray turn with it.

| Name | What it does | Ships as |
|------|--------------|----------|
| Set Mirrored (whole object) | Mirrors this object AND everything under it - picture, hitbox, muzzle point and ray all face the same way. | `scale.x = -1.0 if {mirrored} else 1.0` |
| Is Mirrored | True while this object is mirrored, read off its own X scale. | `scale.x < 0.0` |
| Face Direction Of Movement | Faces the way this object is moving, and leaves it facing that way when it stops. On CharacterBody2D. | `if {velocity}.x != 0.0:` then `scale.x = -1.0 if {velocity}.x < 0.0 else 1.0` |
| Face Object | Turns this object to face another one - an enemy looking at the player, a shopkeeper looking at whoever walked in. | `scale.x = -1.0 if {object}.global_position.x < global_position.x else 1.0` |
| Keep Upright | Re-negates a child's X scale so it does NOT come along when this object mirrors. | `{target}.scale.x = signf(scale.x)` |

**Face Direction Of Movement** takes the value holding how fast the object is moving (**Velocity**,
defaulting to `velocity`) and an optional **On node**. **Keep Upright** takes the **Child** that must
stay readable, defaulting to `$Label`.

### 3D objects

| Name | What it does | Ships as |
|------|--------------|----------|
| Turn Around | Turns a 3D object to face the other way - half a turn about its up axis, and nothing is inside out afterwards. | `rotate_y(PI)` |
| Set Mirrored | Mirrors a 3D object along X. A negative scale flips the mesh's winding, so lighting and backface culling see it inside out. | `scale.x = -absf(scale.x) if {mirrored} else absf(scale.x)` |
| Is Mirrored | True while this 3D object is mirrored along X. | `scale.x < 0.0` |

**Set Mirrored** on a **Label3D** ships the same line, and there the winding is beside the point: a
mirrored 3D label reads backwards, which is exactly what you want from a decal or from a sign seen
from behind.

### User interface

| Name | What it does | Ships as |
|------|--------------|----------|
| Set Mirrored | Mirrors a UI element in place. The pivot is moved to its middle first, which is the half everyone forgets. | `pivot_offset.x = size.x * 0.5` then `scale.x = -1.0 if {mirrored} else 1.0` |
| Is Mirrored | True while this UI element is mirrored. | `scale.x < 0.0` |
| Mirror The View | Mirrors what a sub-viewport shows - the rear-view mirror, the security monitor, the reflection in the water. On SubViewportContainer. | `pivot_offset.x = size.x * 0.5` then `scale.x = -1.0 if {mirrored} else 1.0` |

### The view, a tile and a path

| Name | What it does | Ships as |
|------|--------------|----------|
| Mirror The View | Mirrors everything this camera sees - a mirror world, a reflection, a level played backwards. On Camera2D. | `zoom.x = -absf(zoom.x) if {mirrored} else absf(zoom.x)` |
| Set Tile Flipped | Mirrors the tile already sitting at a cell, keeping its tileset and its tile. | `set_cell({coords}, get_cell_source_id({coords}), get_cell_atlas_coords({coords}), TileSetAtlasSource.TRANSFORM_FLIP_H if {mirrored} else 0)` |
| Mirror Path | Mirrors every point of this path about x = 0 - the second half of a symmetric level, or a patrol route reused facing the other way. | `for __point_{uid}: int in curve.point_count:` then `curve.set_point_position(...)` with the point's X negated |

**Set Tile Flipped** takes the **Cell** as a `Vector2i`. It reads the cell's current source and atlas
coordinates back before writing them again with the flip bit, so the tile that is there stays the
tile that is there.

## Use cases

**1. A platformer character that faces the way it walks.** The one line every platformer writes by
hand, said once.

```
Every tick
  -> Face Direction Of Movement  velocity
```

```gdscript
if velocity.x != 0.0:
	scale.x = -1.0 if velocity.x < 0.0 else 1.0
```

It faces left while moving left, right while moving right, and keeps the last facing when the
velocity reaches zero - because the row writes nothing at all while the character is standing still.

**2. Mirror a background prop, where the picture really is all there is.** A crate, a bush, a cloud:
nothing under it needs to know.

```
On ready
  Condition: Compare Values  randi() % 2  =  0
    -> Set Mirrored  true      (on the Sprite2D)
```

```gdscript
if randi() % 2 == 0:
	flip_h = true
```

Two variants of every decoration from one image.

**3. Mirror the whole body so the hitbox comes with it.** The row a character with combat in it
wants.

```
On direction changed
  -> Set Mirrored (whole object)  true      (on the Body node)
```

```gdscript
scale.x = -1.0 if true else 1.0
```

Everything under the body node turns: the sprite, the Area2D that deals damage, the Marker2D the
bullets come out of. That is the difference between this row and use case 2, and it is the whole
reason the row spells out **(whole object)** in its name.

**4. An enemy that turns to look at the player.**

```
Every tick
  Condition: Is Within Distance  global_position, player.global_position, 400.0
    -> Face Object  player
```

```gdscript
if global_position.distance_to(player.global_position) <= 400.0:
	scale.x = -1.0 if player.global_position.x < global_position.x else 1.0
```

**5. Keep the name plate readable.** Mirroring the body wrote the label's text backwards; this puts
it back.

```
Every tick
  -> Face Direction Of Movement  velocity
  -> Keep Upright  $Body/NamePlate
```

```gdscript
if velocity.x != 0.0:
	scale.x = -1.0 if velocity.x < 0.0 else 1.0
$Body/NamePlate.scale.x = signf(scale.x)
```

The same row is what a health bar, a damage number and a floating interaction prompt want.

**6. The "attacks only work facing right" bug, fixed.** A sword ray that never turned because only
the sprite was ever mirrored.

```
Every tick
  -> Face Direction Of Movement  velocity      (on the Body node, with the ray under it)
```

Moving the RayCast2D under the node you mirror is the whole fix: a ray parented to the body inherits
the body's scale and points the way the character faces. Nothing about the ray itself changes.

**7. Fire out of the front of the gun, whichever way you face.**

```
On fire pressed
  Condition: Is Mirrored
    -> spawn a bullet at $Muzzle.global_position with direction Vector2.LEFT
  Else
    -> spawn a bullet at $Muzzle.global_position with direction Vector2.RIGHT
```

```gdscript
if scale.x < 0.0:
```

With the muzzle parented under the mirrored body its position already followed the facing, so only
the bullet's direction is left to decide - and **Is Mirrored** is the question that decides it.

**8. Turn a 3D character around.** The honest answer in 3D.

```
On patrol point reached
  -> Turn Around
```

```gdscript
rotate_y(PI)
```

Half a turn about the up axis. Nothing is inside out afterwards, which is not true of the alternative
in use case 9.

**9. Mirror a 3D sign so it reads from behind.** The one case where a negative scale is the point.

```
On ready
  -> Set Mirrored  true      (on the Label3D)
```

```gdscript
scale.x = -absf(scale.x) if true else absf(scale.x)
```

A mirrored Label3D reads backwards, which is exactly what a decal, an ambulance bonnet or a sign seen
through glass is supposed to do.

**10. Flip the sprite when gravity flips.**

```
On gravity reversed
  -> Set Flipped  true
```

```gdscript
flip_v = true
```

**11. Ask before you toggle.** Reading the flag back is a plain condition.

```
On turn pressed
  Condition: Is Mirrored
    -> Set Mirrored  false
  Else
    -> Set Mirrored  true
```

```gdscript
if flip_h:
	flip_h = false
else:
	flip_h = true
```

**12. A second player's HUD, laid out the other way round.**

```
On ready
  Condition: Compare variable  player_index  =  2
    -> Set Mirrored  true      (on the HUD panel)
```

```gdscript
if player_index == 2:
	pivot_offset.x = size.x * 0.5
	scale.x = -1.0 if true else 1.0
```

The pivot line is the half a hand-written version forgets, and without it the panel mirrors AND jumps
sideways by its own width.

**13. A rear-view mirror.**

```
On ready
  -> Mirror The View  true      (on the SubViewportContainer)
```

```gdscript
pivot_offset.x = size.x * 0.5
scale.x = -1.0 if true else 1.0
```

The sub-viewport renders the scene from a camera behind the car; mirroring the container is what
makes it read as a mirror rather than as a second window.

**14. A mirror world.** The entire level, reversed, for one level or for one power-up.

```
On mirror curse applied
  -> Mirror The View  true      (on the Camera2D)
```

```gdscript
zoom.x = -absf(zoom.x) if true else absf(zoom.x)
```

Everything the camera sees turns, including the player, which is the joke: left is now right.

**15. One wall asset covering both sides of a corridor.**

```
On corridor built
  For Each  cell in right_wall_cells
    -> Set Tile Flipped  cell, true
```

```gdscript
for cell in right_wall_cells:
	set_cell(cell, get_cell_source_id(cell), get_cell_atlas_coords(cell), TileSetAtlasSource.TRANSFORM_FLIP_H if true else 0)
```

The tile that is already at the cell keeps its tileset and its tile; only its flip bit changes, so no
second art asset and no second tile entry is needed.

**16. Reuse a patrol route facing the other way.**

```
On ready
  Condition: Compare variable  guard_side  =  "left"
    -> Mirror Path      (on the Path2D)
```

Every point of the curve is mirrored about x = 0, so the second guard walks the mirror image of the
first guard's beat and you drew the route once.

**17. Face the player who threw you.** A boomerang, a thrown weapon or a homing pickup that should
look at its owner while it travels.

```
Every tick
  -> Face Object  thrower
```

```gdscript
scale.x = -1.0 if thrower.global_position.x < global_position.x else 1.0
```

**18. Turn a companion to face what the player is facing.** One row, aimed at another node with
**On node**.

```
Every tick
  -> Face Direction Of Movement  velocity      On node: $Pet
```

```gdscript
if velocity.x != 0.0:
	$Pet.scale.x = -1.0 if velocity.x < 0.0 else 1.0
```

The pet reads the player's velocity and faces the same way, without a script of its own.

### Other use cases

**A dialogue portrait that turns toward the speaker.** Set Mirrored on the TextureRect of whichever
portrait is not speaking, so both faces point at the middle of the box rather than both looking left.

**A conveyor belt that runs the other way.** Mirror the AnimatedSprite2D with Set Mirrored and the
scrolling animation reads as reversed motion, with no second animation and no negative speed.

**A split-screen minimap for the second player.** Mirror The View on the sub-viewport container that
holds the minimap camera, so each half of the screen reads outward from its own edge.

**A boss whose second phase is left-handed.** Set Mirrored (whole object) once when the phase starts
and every attack spawn point, hitbox and telegraph mirrors with it, so the phase is genuinely a new
fight built from the same rows.

**A cutscene camera trick.** Mirror The View on the Camera2D for the length of a dream sequence and
put it back when it ends, and the whole scene reads as a reflection without touching a single node in
the level.

## Tips and common mistakes

- **Mirroring a sprite is not mirroring the object.** This is the mistake this whole page exists to
  close. The sprite row turns the picture; the hitbox, the muzzle point and the ray stay exactly
  where they were. If the thing you mirrored has children that matter, mirror the object with
  **Set Mirrored (whole object)** instead.
- **A negative scale in 3D flips the mesh's winding.** Set Mirrored on a Node3D reverses the facing
  of every triangle, so lighting and backface culling see the model inside out - a character lit from
  the wrong side, or one you can see straight through. **Turn Around** is almost always what you
  wanted: half a turn about the up axis, with nothing reversed. The exception is a Label3D, where
  backwards text is the whole point.
- **A Control mirrors about its own pivot, and the pivot starts at its top-left corner.** That is why
  the row writes `pivot_offset.x = size.x * 0.5` before it touches the scale: without it the panel
  mirrors AND jumps sideways by its own width, which reads as a positioning bug rather than a
  mirroring one. A hand-written version that forgets the pivot line is the single most common way UI
  mirroring goes wrong.
- **A ray that never turns is a facing bug, not a ray bug.** The Project Doctor raises
  **ray-not-following-facing** on a file that mirrors a sprite while holding a RayCast2D, and its
  quick fix chip names the ray it found: *Put sword under the mirrored body*. That is the whole fix:
  a ray parented
  under the node you mirror with Set Mirrored (whole object) inherits the scale and turns with the
  character. The alternative, signing the ray's reach yourself with
  `absf(...) * signf(scale.x)`, satisfies the note too and reads back on the sheet as
  **Ray follows facing**.
- **A label under a mirrored body writes its text backwards.** The Doctor raises
  **label-under-a-mirrored-body** on a file that mirrors a whole object while holding a Label under
  it, and its quick fix chip names the label it found: *Keep plate upright*. The row it names is
  **Keep Upright**,
  which re-negates that child's X scale so the text stays readable while everything around it turns.
  Both notes are informational: they are the two things mirroring has to drag along, and neither is a
  fault in the code that is there.
- **Set Mirrored (whole object) writes an absolute scale, not a toggle.** It sets `scale.x` to exactly
  1 or -1, so an object you deliberately scaled to 0.5 or to 2 loses that size the first time it
  faces. Put the sizing on a child, or on a parent, and keep the facing node at scale 1.
- **Face Direction Of Movement writes nothing while the velocity is zero.** That is deliberate - it is
  what makes a character keep facing the way it last walked instead of snapping back to the right the
  moment it stops. It also means the row cannot be used to "reset" the facing; say that with
  Set Mirrored (whole object) if you need it.
- **Face Object compares global X positions only.** An object directly above or below another gets
  whichever answer the tiniest horizontal difference produces, and can flicker between the two. Gate
  it on a horizontal distance when the two can stack vertically.
- **Keep Upright takes the child, not the parent.** Its **Child** parameter defaults to `$Label`, and
  it must name the node whose text has to stay readable. Pointing it at the body it is meant to
  counteract does nothing useful.
- **Two things named Mirror The View are two different hosts.** One is a Camera2D action that negates
  the camera's zoom; one is a SubViewportContainer action that moves the pivot and negates the scale.
  The picker offers you the one your node supports, so the confusion only bites when you retarget
  with On node.
- **Set Tile Flipped mirrors a tile that is already there.** It reads the cell's current source and
  atlas coordinates back before writing them again with the flip bit, so an empty cell stays empty -
  the row is not a way to paint one.
- **Mirror Path edits the curve, and the curve is a resource.** Mirroring the same path twice puts it
  back, and a curve shared between two Path2D nodes is mirrored for both. Duplicate the curve first if
  only one of them should turn.
- **A plain `scale.x` write is a size, not a mirror.** `body.scale.x = 2.0` reads back as
  **Set scale.x to 2** on purpose. The facing readings only claim a line whose shape really is a
  facing shape - a -1, a sign, or a conditional between the two - because a confident sentence about
  facing on a line that was resizing something would be worse than the code it replaced.
