# Collisions: what touches what

Every collision question in a game is really two questions asked in two different files. The sheet
says *what should happen when the player touches the door*; the `.tscn` says *whether the door can
see the player at all*. Nothing in Godot's editor puts those two halves in front of the same reader,
which is why a collision row that is perfectly correct is the commonest row in any project to sit
there and never run.

This guide is the whole of it, in the order a game needs it: picking the node, naming the layers,
writing the filtered sentence, catching the step something changed, and finding the four silent
failures before the game runs. There is no collision system here to learn - every row is one plain
Godot call, and a collision script you already wrote opens on these same rows and saves back byte
for byte.

## Contents

- [Area or body: the one decision everything else follows from](#area-or-body-the-one-decision-everything-else-follows-from)
- [Layers, and who sees whom](#layers-and-who-sees-whom)
- [The touch, with a filter on it](#the-touch-with-a-filter-on-it)
- [The edges: the step something changed](#the-edges-the-step-something-changed)
- [The deep verbs, and when to reach for them](#the-deep-verbs-and-when-to-reach-for-them)
- [Opening a project that already collides](#opening-a-project-that-already-collides)
- [What the Doctor checks](#what-the-doctor-checks)
- [The traps](#the-traps)

## Area or body: the one decision everything else follows from

Godot has four collision node families and they mean four different things. Which one you drop into
the scene decides what you may ask of it, and it is the fact a beginner is missing while they fill
in their first collision row. So the picker files rows by node class: a sheet is only ever offered
the rows its own node can really answer, and the row's dialog says which family this is while you
are filling it in.

Two words carry the whole table. **Detect** means the node notices something and lets it through.
**Block** means the thing stops.

| What you want | The node | What comes alive with it |
|---|---|---|
| Detect only. A pickup, a checkpoint, a damage field, a pressure plate, a trigger volume. Nothing is stopped. | **Area2D** / **Area3D** | **On overlap with `<Group>`** and **On overlap ended with `<Group>`**, the standing question **is touching `<Group>`**, the two edge triggers **On first overlap** / **On last overlap ended** with **is the first one in** / **was the last one out**, and the overlap list verbs (**Is Overlapping Body**, **Has Overlapping Bodies**, **Overlapping Bodies**). An Area is also the only family with a monitoring switch, and it is off in more scenes than anybody expects. |
| Block, and your rows drive it. The player, an enemy that walks, anything moved one step at a time by the sheet. | **CharacterBody2D** / **CharacterBody3D** | **On landed** and **On left the ground** with **just landed** / **just left the ground**, the floor family (**Is By Wall**, **Is Touching Ceiling**, **Is Jumping**, **Is Falling**, **Is Moving**, **Wall Normal**, **Floor Normal**), the slide results (**Slide Collision Count**, **Last Slide Collider**, **Last Slide Normal**) and the never-made move **Is Overlapping At Offset**. What it hit comes back from its own move rather than from a signal. |
| Block, and physics throws it. A crate, a barrel, a ragdoll, a ball. | **RigidBody2D** / **RigidBody3D** | **On collision with `<Group>`** and **On stopped colliding with `<Group>`**. Godot reports the hit only while **Contact Monitor** is on and **Max Contacts Reported** is above zero, which is a scene setting and not a row. |
| Block, and it stands still. Ground, walls, platforms, the level. | **StaticBody2D** / **StaticBody3D** | The layer verbs, and nothing else worth writing here: a static body never moves, so the news of a touch nearly always belongs on whatever ran into it. Write the row on the mover. |

All four inherit the layer verbs, because all four are `CollisionObject2D` / `CollisionObject3D`
underneath, which is the class Godot keeps layers and masks on.

The dialog says this for you. Open any filtered touch row and put the cursor in its **With** field
and the help strip reads the line for the class the row is filed under - "This node is an area: it
notices what arrives and lets it through. Blocking is a body's job, so pair this with a body if the
thing should also be stopped", or the character body's "your own rows drive it, one move at a time".
It is read off the node class, so it is about the node in front of you rather than about collisions
in general.

**A scene with nothing physical in it says so.** Pick a touch row while the scene holds nothing that
can collide and the entry stays listed and greys, with its reason spelled as the fix rather than as
a class name: *"Nothing in this scene can touch anything yet - this row needs an Area2D"*, and the
Add button reads **Add an Area2D to the scene**. Pressing it adds the node through the editor's own
undo and carries straight on to the row you wanted.

## Layers, and who sees whom

This is the one asymmetry in the whole subject, and it is worth reading twice because everything
else here rests on it.

**A layer is where an object SITS. A mask is what an object WATCHES.** They are two separate
thirty-two-bit numbers on every collision object, and the pair is not symmetric: A notices B when
**A's mask covers a layer B sits on**. B does not have to be watching anything at all. That is why a
bullet with a perfect mask still sails through an enemy that was never put on a layer, and why
turning one tick box on in the wrong of the two grids does nothing.

The sheet says both halves in the project's own words. Five rows, each taking a **Layer** name
picked from the list this project declared in **Project Settings ▸ Layer Names ▸ 2D Physics**:

| Row | What it changes | Ships as |
|---|---|---|
| **Collide with `<Layer>`** | this object's mask: start noticing that layer | `set_collision_mask_value(2, true)` |
| **Stop colliding with `<Layer>`** | this object's mask: stop noticing it - the drop-through-a-platform move, the dash that turns intangible | `set_collision_mask_value(2, false)` |
| **Be on layer `<Layer>`** | this object's layer: everything watching that layer starts noticing it | `set_collision_layer_value(3, true)` |
| **Leave layer `<Layer>`** | this object's layer: everything watching stops noticing it - the invulnerable frames after a hit, said as the layer it leaves | `set_collision_layer_value(3, false)` |
| **is set to collide with `<Layer>`** | asks the mask. It is about the SETTING, not about a touch happening now | `get_collision_mask_value(2)` |

**The number is what is stored; the name is resolved when the row is drawn.** The emitted line is
Godot's own call with the number in it - no comment residue, no name baked into your file - and the
names live in `project.godot`, where Godot already keeps them. Rename a layer and every row about it
renames itself and no file moves. A layer the project never named shows as its number, with a field
beside it to name it: type a word, press **Name it…**, and the setting is written through the
editor's own undo with the receipt on the strip - `Layer 4: 4 ▸ "Hazards". Undo puts the number
back.`

The pair ships for both dimensions, because Godot keeps two separate lists of layer names and the
picker files rows by node class. A 2D row can only mean a 2D layer.

The frozen number-first verbs are untouched and stand beside these for when a number is what you
mean: **Set Collision Layer Bit**, **Set Collision Mask Bit** and **Is On Collision Layer**.

```gdscript
extends CharacterBody2D


func _ready() -> void:
	set_collision_mask_value(2, true)
	set_collision_layer_value(3, true)
```

### The band that says it without you asking

A sheet whose node collides grows a **collisions** band at the top of it:

> collisions · sees Enemies, Walls · seen by Player · monitoring on

Three facts, all read out of the `.tscn` the script is attached to and none of them visible from the
row that depends on them. *Sees* is the layer names this object's mask covers. *Seen by* is the layer
names of everything else in the project whose own mask covers one of this object's layers - the
other end of the asymmetry, worked out for you. *Monitoring* is said only for an Area, because it is
the Area's own switch. The band lists what fits and counts the rest, its code echo is the lines of
the scene file it came from and nothing else, and its control selects the node in the scene. A sheet
whose node does not collide grows no band at all.

![The collisions band at the top of a sheet, reading sees Doors, seen by Doors, monitoring on](images/collisions-head-band.png)

## The touch, with a filter on it

The bare triggers say THAT something arrived. A game nearly always wants to know that the *player*
arrived, or a bullet, or a pickup - and written by hand that is an early return at the top of the
handler, which is the single most-typed line in any collision script.

Here the group is the row's own **With** field: a parameter, picked from the project's node groups,
never a clause and never a second row.

| Row | Filed under | The moment |
|---|---|---|
| **On collision with `<Group>`** | RigidBody2D / RigidBody3D | something from that group hit this body |
| **On stopped colliding with `<Group>`** | RigidBody2D / RigidBody3D | it stopped touching - ending a push, a grind, a stand-on |
| **On overlap with `<Group>`** | Area2D / Area3D | something from that group moved into this area |
| **On overlap ended with `<Group>`** | Area2D / Area3D | it left - walking out of a safe zone, the last enemy clearing a trap |
| **is touching `<Group>`** | Area2D / Area3D | the standing question beside them, for when the state now matters rather than the moment it changed |

Both wordings are the same engine signal. Godot files `body_entered` under two families that mean
different things by it, so the rows ship twice and a sheet is offered only the one its node can
really raise.

**The guard is visible code.** The emitted handler's FIRST statement is the early return, and what
did arrive rides into the rows underneath as the trigger's payload:

```gdscript
extends Area2D


func _ready() -> void:
	body_entered.connect(_on_body_entered_enemies)


func _on_body_entered_enemies(body: Node) -> void:
	if not body.is_in_group("enemies"):
		return
	print(body.name)
```

Two groups on one signal become two handlers, each opening with its own guard, because one function
cannot hold two different early returns.

![An overlap trigger filtered to the enemies group, with the arriving body used by the two rows underneath](images/collision-filter-event.png)

**is touching `<Group>`** is a plain condition, which is what lets the sheet's own **NOT** read it
the other way round without a second row existing anywhere:

```gdscript
extends Area2D


func _physics_process(delta: float) -> void:
	if get_overlapping_bodies().any(func(body: Node) -> bool: return body.is_in_group("enemies")):
		print("contact")
```

Every trigger row shows its payload as chips read off the signature the compiler is going to emit,
so you can see what the event hands you without opening the code.

## The edges: the step something changed

Half the moments a game is built out of are not signals at all. Godot answers "am I on the floor?"
as a standing question, so *the step it changed* is this step's answer compared against last step's.

**On landed** and **On left the ground** carry that comparison as an ordinary condition row you can
read, edit, disable and delete. The memory, the comparison and the update are the three parts every
platformer already writes by hand, in the hand-written order, and all three are in the row's echo:

```gdscript
extends CharacterBody2D

var was_on_floor: bool = false


func _physics_process(delta: float) -> void:
	if is_on_floor() and not was_on_floor:
		print("landed")
	was_on_floor = is_on_floor()
```

**The ordering is the whole of it.** A memory brought up to date *before* the question is asked
always agrees with the present, and the row could never be true. That is why the update comes after.

A landing event and a plain physics event share one `_physics_process`, because an edge is a moment
of a callback rather than a callback of its own.

**On first overlap** and **On last overlap ended** are the same idea where the engine already does
the remembering. An area's arrivals and departures ARE signals, and the overlap list is already up
to date when one is raised - so *is the first one in* is a list of exactly one
(`get_overlapping_bodies().size() == 1`), and *was the last one out* is an empty list. The pressure
plate going down, the room waking up, the room going quiet.

Picking any of the eight puts the ordinary condition underneath. Nothing is wrapped, and nothing is
added by the compiler that is not a row you can see.

### What the floor edges do at the edges

Four things follow from *the floor answer is a memory of last step*, and they are true of the
hand-written pattern exactly as they are of the row. None of them is a bug to be fixed; each one is
worth knowing before you build a jump on it.

- **The first physics step is a landing.** `is_on_floor()` is false until the body has moved once,
  so a character standing on the ground when the level opens is "not on the floor" on step one and
  "on the floor" on step two. That is a landing by the only definition there is. If the landing
  spends a sound or a puff of dust, gate it on something that says the game has started.
- **A body that starts in the air is right, and says nothing.** It was not on the floor and is not
  on the floor, so no edge happened. The landing arrives on the step it really touches down.
- **A paused node misses the edge.** `_physics_process` does not run while the node is paused, so
  the memory stops where it was. Whatever happened to the feet during the pause is compared against
  the footing from before it, on the first step after - which reports a landing if the body was in
  the air when it paused and on the ground when it woke.
- **A slope or a step can flicker.** `is_on_floor()` can go false for a single step as a character
  crosses a seam or clips a corner, and every one of those is a real leave-and-land pair to this
  row. If a landing is expensive, count the steps off the floor before you believe them, or use
  Godot's **Floor Snap Length** on the body so the feet do not leave in the first place.

**And the gate stays the row's first question.** It is put there when the trigger is applied. A
sheet's conditions compile to the terms of one `and` chain, and GDScript stops reading that chain at
the first false term - so a floor gate moved down behind another question is not asked on the steps
that question is false, the memory falls behind, and the next step it goes true reports a landing
that never happened.

## The deep verbs, and when to reach for them

The rows above are the sentences. Underneath them sits the vocabulary that was always here, and it
is the answer whenever you need the *result* of a move rather than the news of one. The full tables
live in the [Collisions, Joints and World Physics](Modules/Collisions-Joints-And-World-Physics.md)
module guide; what matters here is when each one is the right reach.

- **The floor family, after Move And Slide.** **Is By Wall**, **Is Touching Ceiling**, **Wall
  Normal** and **Floor Normal** read what the engine recorded during the character body's most
  recent move. Ask them AFTER the move, in the same physics step. A wall jump is **Is By Wall** plus
  **Wall Normal** and nothing else, because the normal already faces out of the wall.
- **The slide results.** **Slide Collision Count**, **Last Slide Collider** and **Last Slide Normal**
  name what the body ran into on its last move. This is the damage-on-contact answer for a character
  body, which has no `body_entered` of its own to filter.
- **The overlap questions.** **Is Overlapping Body**, **Has Overlapping Bodies** and **Overlapping
  Bodies** are about right now, so they are conditions you can ask any frame - and the list form
  hands you every target inside a blast at once, to loop with a pick filter.
- **The ground check that never moves anything.** **Is Overlapping At Offset** asks where the body
  *would* end up one pixel down (`test_move(transform, Vector2(0, 1))`) and nothing moves either way.
- **Turning a shape off.** **Enable Collision Shape** / **Disable Collision Shape** are deferred, so
  they are safe from inside a collision callback - and that deferral means the change lands at the
  end of the frame rather than on the next line.

One row that belongs beside all of these: **Spawn A Copy Safely** writes `call_deferred("add_child",
…)`, because Godot refuses to add a child while the physics server is flushing, which is most of
what a collision handler is.

## Opening a project that already collides

Every sentence in this guide is also a *reading*. A collision script you already wrote opens on
these rows and saves back byte for byte, in your own spelling:

| What you wrote | What it opens as |
|---|---|
| a `body_entered` handler whose first statement is a group early return | **On collision with `<Group>`** (or **On overlap with `<Group>`** when the node is an Area), filter and all, on one line or two |
| `get_overlapping_bodies().any(func(b): return b.is_in_group("enemies"))` | **is touching `<Group>`**, keeping your own lambda argument's name |
| `if is_on_floor() and not was_on_floor:` | **On landed** with *just landed* under it, in either order of the two halves, and in the two-variable form |
| `set_collision_mask_value(2, true)` | **Collide with Enemies**, with the number resolved to the project's word at read time |

The names your project gave its own memories and lambda arguments are your spelling, not values the
rows show, which is exactly what makes them ride back out untouched. A guard that asks for MORE than
the group, or a landing check with something else and-ed onto it, is deliberately left alone: a row
that dropped the rest of the question would not write the file back.

The full table, spelling by spelling, is in
[Using EventSheets with existing code](GUIDE-USING-WITH-EXISTING-CODE.md), under *What an opened
file reads like*.

## What the Doctor checks

Two sections of the triage inbox, and every finding in them describes a row that is correct and
never runs.

![The Doctor's Collisions section listing a trigger nothing can reach, a node with no shape and an Area with monitoring off, with the three doors underneath](images/collisions-doctor-report.png)

**Doctor ▸ Collisions** is the four silent failures:

| Finding | What it means | Its door |
|---|---|---|
| nothing can reach it | the trigger waits on a touch and the node's mask does not cover the layer the bodies it is waiting for actually sit on. For a group-filtered trigger those are the layers that group's members really sit on; for a bare trigger it is every layer anything sits on, which is weaker, and the sentence says so | **Watch the layer they are on**, which writes the one mask bit through the editor's own undo |
| monitoring is off | the Area's own switch is off in the scene, so Godot never emits the signal at all | **Switch monitoring on**, same undo, same receipt |
| it has no shape | a collision object with no CollisionShape child has no extent. Godot says so in the Scene dock and nothing said it to the sheet that depends on it | **Show me the node in the scene** |
| the one-way faces down | a one-way collider turned over lets bodies through from above and stops them from below, beside rows waiting for the landing it blocks | **Show me the node in the scene** |

Both writing doors leave a receipt of the two lines either side of the change - `collision_mask = 4
-> collision_mask = 6`, `monitoring = false -> monitoring = true` - and both are one Ctrl+Z. The
third and fourth only take you to the node, because adding a shape or turning a platform over is a
decision about the game's geometry that no tool should make on anybody's behalf.

**Doctor ▸ Collision Layers** is about a number the project cannot name: a row about a layer this
project does not name (renamed away, renumbered, or never named) is a note, and a number outside
1 to 32 is a warning, because Godot has thirty-two layers and that call silently does nothing. Both
say nothing at all in a project that names no layers - numbers are a perfectly good way to work, and
the note exists only because the project already speaks in names and one row cannot.

**None of this renders in the sheet.** A row a finding is about wears a quiet amber stripe and
nothing else: no note row, no icon, no inline sentence, and nothing at all on a sheet with nothing
wrong. The words and the doors live in the two places a reader goes on purpose - the Doctor's triage
inbox, and the help strip under the row once the row is selected.

## The traps

- **A perfect mask is half the answer.** A notices B when A's mask covers a layer B *sits on*. If B
  was never put on a layer, nothing notices it however many boxes you tick on A. The head band's
  *seen by* half is that question already answered.
- **An Area with monitoring off is silent, not broken.** Every layer right, every mask right, no
  signal. It is one tick box in the Inspector and the commonest cause of "my pickup does nothing".
- **A rigid body reports nothing until Contact Monitor is on.** And **Max Contacts Reported** above
  zero. The row is correct before either is set; the game is quiet.
- **Slide results are about the LAST move.** Ask them after Move And Slide in the same physics step,
  not from a per-frame event that never moves anything.
- **Do not update the memory before the question.** If you hand-write the landing check, the update
  goes after the `if`. Before it, the comparison always agrees with the present and can never fire.
- **And do not move the floor gate behind another question.** The chain short-circuits, so the
  memory is not updated on the steps the question in front of it is false. See *What the floor edges
  do at the edges* above, which also covers the first physics step, a pause, and a flickering slope.
- **Adding a child inside a collision handler needs the deferred spelling.** Godot refuses while the
  physics server is flushing. **Spawn A Copy Safely** is the row that admits the deferral in its own
  sentence.
- **A layer renamed in Project Settings renames every row about it, and moves no file.** That is the
  right way round, and its one consequence is that a layer which stops being named stops being
  readable: the sentence quietly goes back to saying a number. Doctor ▸ Collision Layers is what
  tells you.
- **`is set to collide with <Layer>` is about the setting, not about a touch.** The question about a
  touch happening now is **is touching `<Group>`** or one of the overlap questions.
