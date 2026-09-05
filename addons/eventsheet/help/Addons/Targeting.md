# Targeting - Lock On, Cycle, And Aim Help In 2D

Targeting is a Godot EventSheets behavior pack that gives a 2D node one held enemy and a steadier aim. You attach a `TargetingBehavior` behavior to a `Node2D` - a player, a turret, a companion, a homing missile - and that node becomes the thing that aims. One row locks on to the nearest member of a group inside a cone and a range, another cycles to the next one along, and a trigger fires the moment the held target dies, walks out of reach, ducks behind a wall or is let go. Alongside the lock there is aim help that needs no lock at all: an expression that bends a stick direction toward whatever the player is nearly pointing at, and one that drags the turn rate while the aim crosses a target. Both read the aim-assist radius the accessibility rows already declare, so the options screen you have controls them, and a radius of zero turns them off.

---

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [ACE reference](#ace-reference)
5. [Reading it from expressions - the Self section](#reading-it-from-expressions---the-self-section)
6. [Use cases](#use-cases)
7. [Tips and common mistakes](#tips-and-common-mistakes)

---

## Where this pack shines

- **Twin-stick and top-down shooters.** Hold the nearest hostile in front of you, fire along the lock, and let go by itself when it dies.
- **Controller aim help.** A stick is coarse. Assisted Aim bends the shot toward what the player is nearly pointing at, by an amount an options slider sets.
- **Reticles and nameplates.** Locked Target On Screen hands a CanvasLayer reticle the right pixel every frame, camera zoom and scroll included.
- **Cycling through a crowd.** A shoulder button that steps left to right through everything in the cone, and wraps, is one row.
- **Homing shots and beams.** Locked Target is a node you can hand straight to a bullet, a tween, a Look At, or a damage number's parent.
- **Auto-attack companions and turrets.** Poll Lock On To Nearest on a timer and the pet always holds the closest thing it can genuinely reach.
- **Boss and cutscene focus.** Lock On To names one node outright, whatever the cone says, so a scripted moment can force the camera's attention.
- **Cover-aware combat.** Turn the line-of-sight option on and a lock breaks the instant a wall comes between the two, with the reason word to prove it.
- **Accessibility settings that finally do something.** The aim-assist radius stops being a number nobody reads and becomes the strength of the help.
- **Strafe and lock-on cameras.** Is Locked On is the gate that swaps a free camera for one that keeps the held enemy framed.
- **Melee target selection.** A short range and a wide cone pick the enemy a swing should land on, instead of the one the animation happens to face.
- **Tutorials and soft aim for young players.** Raise the radius and the strength for an easy mode without touching a line of combat code.

---

## Core concepts

The pack is small, and five ideas carry all of it.

**The node is the one that aims.** You add a `TargetingBehavior` as a child of a `Node2D`, and that parent is the host. Every search starts from the host's world position, every cone is centred on the host's facing, and every row acts on the behavior of the node it sits on. There is no targeting id to thread through calls, and one node holds one target.

**The cone is around the facing.** In 2D the cone points where the host is rotated to - the same facing the Line Of Sight behavior measures its view fan around, so a guard and its lock agree about what "in front" means. `lock_cone_degrees` is the FULL width: 60 reaches 30 degrees to each side. Write 360 for no cone at all, which is what a turret with eyes all round has.

**One target is held, and the ring remembers the rest.** Lock On To Nearest searches the cone and keeps the whole list of what it found, ordered left to right by angle. That list is the ring. Cycle Target steps along it and wraps round from the rightmost back to the leftmost, so a shoulder button walks the crowd in the order the player sees them, not in whatever order the tree happens to hold them.

**A lock ends in exactly four ways, and says which.** On Target Lost carries one word: `died` when the target was freed, `out_of_range` when it walked past the reach the lock was taken at, `blocked` when a wall came between the two (only with the line-of-sight option on), and `released` when a row let go on purpose. One trigger row therefore cleans the reticle up after all four, and the word tells them apart when you want them to differ. A dead target is released the frame it dies, before anything reads a position off it.

**Aim help is separate from the lock, and the options screen owns it.** Assisted Aim and Magnetism never touch the held target. They ask a different question - what is the aim ray nearly pointing at right now - and "nearly" is the aim-assist radius the accessibility rows declare, measured ACROSS the ray. A radius of zero means nothing is ever near enough, so both rows hand back exactly what they were given and the whole feature is off. That is the honest off switch, and it is already on the options screen.

---

## Setup

**1. Attach the behavior.** Add a `TargetingBehavior` behavior as a child node of the `Node2D` that aims (open the pack sheet and use Tools > Attach to Selected Node, or drop the pack node in as a child). The behavior grabs its parent as the host on ready.

**2. Put your hostiles in a group.** The pack searches groups, so add the enemies to one (`enemies` by default) in the Scene dock's Node > Groups tab, or with an Add To Group action when they spawn.

**3. Set the Inspector knobs.** Select the behavior node and tune it:

| Property | Default | What it does |
|---|---|---|
| `target_group` | `&"enemies"` | The group the rows search when a row names none. |
| `lock_cone_degrees` | `60.0` | The full cone width in degrees around the host's facing, used when a row leaves its own cone at 0. |
| `lock_range` | `400.0` | The reach in pixels a search covers, and the distance a held lock is lost past, when a row leaves its own range at 0. |
| `require_line_of_sight` | `false` | Whether a wall hides a target and breaks a lock. Off by default, because a ray per frame is a cost an open arena should not pay. |
| `blocker_mask` | `1` | The physics layers a wall lives on, for the sight ray this pack casts when no Line Of Sight behavior is attached to the same host. |
| `magnetism_slowdown` | `0.5` | How much Magnetism slows a turn while the aim crosses a target. 1 is no slowing, 0 stops the turn dead. |

**4. Lock, read, release.** Here is a complete first setup: a button locks on, a reticle follows, and it hides itself when the lock ends.

```
On Input Action Just Pressed  "lock_on"
  -> Player | Targeting: Lock On To Nearest  "enemies", 60, 400

Every tick
  Condition: Player | Targeting  Is Locked On
    -> Reticle: Set Position to  Player | Targeting: Locked Target On Screen
    -> Reticle: Show

On Player | Targeting: On Target Lost
  -> Reticle: Hide
```

Nothing else is registered and nothing is polled that does not need to be: the per-frame loss check starts with the first lock and parks itself with the last, so an unlocked node costs nothing.

---

## ACE reference

All ACEs live in the **Targeting** category and act on the `TargetingBehavior` attached to the node they are placed on. There is no targeting id parameter anywhere.

### Actions

| Action | Parameters | Description |
|---|---|---|
| Lock On To Nearest | `group` (StringName), `cone_degrees` (float), `max_range` (float) | Searches a cone around the host's facing for the closest member of a group inside a range, and holds it. Leave the group empty for the behavior's own Target Group, and write 0 for the cone or the range to use its own defaults. A search that finds nothing leaves the current lock alone. |
| Lock On To | `node` (Node2D) | Holds one node you name, whatever the cone and the range say - a named lock has no reach at all, so the boss a cutscene points at is held however far off it is. It becomes the only entry in the ring, so a Cycle Target after it stays on it until the next search. Losing sight of it, and its dying, still end it. |
| Cycle Target | (none) | Steps to the next candidate the last Lock On To Nearest found, left to right by angle, wrapping from the rightmost back to the leftmost. Candidates that died since the search are dropped first. With nothing held it takes the leftmost. |
| Release Lock | (none) | Lets the held target go on purpose. On Target Lost fires with the reason `released`. |

These next actions write to the exported knobs at runtime and are reflected from the `@export` properties.

| Action | Parameters | Description |
|---|---|---|
| Set Target Group | `value` (StringName) | Sets the group the rows search when a row names none. |
| Set Lock Cone Degrees | `value` (float) | Sets the default cone width in degrees. |
| Add To Lock Cone Degrees | `amount` (float) | Widens the default cone by `amount` degrees. |
| Subtract From Lock Cone Degrees | `amount` (float) | Narrows the default cone by `amount` degrees. |
| Set Lock Range | `value` (float) | Sets the default reach in pixels. |
| Add To Lock Range | `amount` (float) | Increases the default reach by `amount`. |
| Subtract From Lock Range | `amount` (float) | Decreases the default reach by `amount`. |
| Set Require Line Of Sight | `value` (bool) | Turns the wall check on or off. |
| Set Blocker Mask | `value` (int) | Sets the physics layers a wall lives on (the bitmask value). |
| Add To Blocker Mask | `amount` (int) | Adds to the blocker mask value. |
| Subtract From Blocker Mask | `amount` (int) | Subtracts from the blocker mask value. |
| Set Magnetism Slowdown | `value` (float) | Sets how much Magnetism slows a turn across a target. |
| Add To Magnetism Slowdown | `amount` (float) | Increases the slowdown factor by `amount`. |
| Subtract From Magnetism Slowdown | `amount` (float) | Decreases the slowdown factor by `amount`. |

### Conditions

| Condition | Parameters | Description |
|---|---|---|
| Is Locked On | (none) | True while this behavior is holding a target that is still alive. The gate for a reticle, a homing shot or a strafe camera. |

### Expressions

| Expression | Parameters | Returns | Description |
|---|---|---|---|
| Locked Target | (none) | Node2D | The node being held, or null when nothing is. Hand it to any row that takes a node. |
| Locked Target On Screen | (none) | Vector2 | Where the held target sits on screen right now, camera zoom and scroll included. Vector2.ZERO when nothing is held. |
| Distance To Target | (none) | float | How far the held target is, in pixels. INF when nothing is held, so "is the target closer than 200" is plainly false rather than accidentally true. |
| Assisted Aim | `direction` (Vector2), `strength` (float) | Vector2 | The direction you hand it, bent toward the nearest target the ray is nearly pointing at, by a strength from 0 (no help) to 1 (dead on). The length you passed in is kept. |
| Magnetism | `turn_rate` (float) | float | The turn rate you hand it, slowed by Magnetism Slowdown while the aim is crossing a target. Unchanged otherwise. |
| Target Group | (none) | StringName | The group the rows search when a row names none. |
| Lock Cone Degrees | (none) | float | The current default cone width, in degrees. |
| Lock Range | (none) | float | The current default reach, in pixels. |
| Require Line Of Sight | (none) | bool | Whether the wall check is on. |
| Blocker Mask | (none) | int | The current blocker mask value. |
| Magnetism Slowdown | (none) | float | The current magnetism slowdown factor. |

### Triggers

| Trigger | Carries | Fires when |
|---|---|---|
| On Target Locked | `target` (Node2D) | The held target CHANGES. Locking on to what is already held is not a new lock, so a row polled every frame fires this once, not every frame. |
| On Target Lost | `why` (StringName) | A lock ends, for any of the four reasons: `died`, `out_of_range`, `blocked`, `released`. |

### Inspector properties

| Property | Type | Default | What it controls |
|---|---|---|---|
| `target_group` | StringName | `&"enemies"` | The group searched when a row names none. |
| `lock_cone_degrees` | float | `60.0` | The default full cone width in degrees around the host's facing. |
| `lock_range` | float | `400.0` | The default reach in pixels, and the distance a lock taken at that reach is lost past. |
| `require_line_of_sight` | bool | `false` | Whether a wall hides a target and breaks a lock. |
| `blocker_mask` | int | `1` | The physics layers a wall lives on, for this pack's own sight ray. |
| `magnetism_slowdown` | float | `0.5` | The factor Magnetism multiplies a turn rate by while the aim crosses a target. |

---

## Reading it from expressions - the Self section

Type `self` in any ƒx field, or open the ƒx **Expressions dictionary**, and **Self ▸ Behaviours**
lists this pack's knobs and value expressions as ready-to-insert chains once the behaviour is attached:

- `$TargetingBehavior.lock_range` inserts the **Lock Range** entry straight into any expression
- `$TargetingBehavior.lock_cone_degrees` inserts the **Lock Cone Degrees** entry straight into any expression

The `$TargetingBehavior` token stays selected after insert, so retargeting to your child's actual name is one
keystroke, or a node drag. Attaching this behaviour at runtime instead? Tick **Robust behaviour
lookups** in the dictionary and the same entries insert as `get_node_or_null("TargetingBehavior")` chains,
which survive auto-named children. While **Live Values** streams from a running game, the group
upgrades to *Behaviours (live - on your node)* and reads the RUNNING instance - behaviours
attached at runtime included, under their real names. And with your node selected in the Scene
dock, the section grounds to that node's actual children before you even press Run.

## Use cases

Each example acts on the `TargetingBehavior` attached to the named node.

### 1. Lock on with a button, and let go by itself

The whole loop in four rows. The lock ends on its own when the enemy dies, so nothing has to remember to clear it.

```
On Input Action Just Pressed  "lock_on"
  -> Player | Targeting: Lock On To Nearest  "enemies", 60, 400

On Player | Targeting: On Target Lost
  -> Reticle: Hide
  -> Player: Set aiming_at_locked = false

On Player | Targeting: On Target Locked
  -> Reticle: Show
  -> Player: Set aiming_at_locked = true
```

### 2. A reticle that sits on the held enemy

Locked Target On Screen already accounts for camera zoom and scroll, so a reticle living on a CanvasLayer needs no conversion of its own.

```
Every tick
  Condition: Player | Targeting  Is Locked On
    -> Reticle: Set Position to  Player | Targeting: Locked Target On Screen
```

### 3. Cycle through the crowd with a shoulder button

The ring is ordered left to right by angle, so the button walks the enemies in the order the player sees them, and wraps.

```
On Input Action Just Pressed  "next_target"
  -> Player | Targeting: Cycle Target
```

### 4. Fire along an assisted stick

A controller stick is coarse. Bend it toward whatever it is nearly pointing at, by a strength you pick, and spawn the bullet along the bent direction.

```
On Input Action Just Pressed  "fire"
  -> Player: Spawn "res://bullet.tscn" facing  Player | Targeting: Assisted Aim  Player.aim_stick, 0.4
```

### 5. Turn the assist off from the options screen

Nothing here knows what an options screen is. The assist reads the aim-assist radius the accessibility rows declare, and zero means no target is ever near enough.

```
On Slider "aim_assist" Changed
  -> Accessibility: Set Aim Assist Radius  Slider.value
```

### 6. Stickier turning across an enemy

Magnetism drags the turn rate while the aim crosses something, so the stick settles on an enemy instead of sliding past it.

```
Every tick
  -> Player: Set turn_rate to  Player | Targeting: Magnetism  Player.base_turn_rate
  -> Player: Rotate by  Player.aim_stick.x * Player.turn_rate * dt
```

### 7. A homing bullet that follows the held node

Locked Target is a node, not a position, so anything that takes a node takes it. The bullet keeps chasing even as the enemy moves.

```
On Input Action Just Pressed  "fire"
  Condition: Player | Targeting  Is Locked On
    -> Bullet: Set homing_target to  Player | Targeting: Locked Target
```

### 8. A strafe camera while a lock is held

Is Locked On is the whole gate. Free camera when nothing is held, framed camera when something is.

```
Every tick
  Condition: Player | Targeting  Is Locked On
    -> Camera | Look At: Look At  Player | Targeting: Locked Target  over 0.2 s
  Else
    -> Camera | Look At: Look At  Player  over 0.4 s
```

### 9. Break the lock behind cover

Turn `require_line_of_sight` on and a wall ends the lock with the reason `blocked`. If a Line Of Sight behavior is attached to the same host, this pack asks it rather than casting its own ray, so the two agree about what a wall is.

```
On Difficulty Set To "realistic"
  -> Player | Targeting: Set Require Line Of Sight  true

On Player | Targeting: On Target Lost
  Condition: why  =  "blocked"
    -> HUD: Flash "Lost sight"
```

### 10. React differently to each of the four endings

One trigger row carries the reason, so the four cases branch off one place.

```
On Player | Targeting: On Target Lost
  Condition: why  =  "died"
    -> HUD: Add Score  100
  Condition: why  =  "out_of_range"
    -> HUD: Show "Target escaped"
  Condition: why  =  "released"
    -> Reticle: Fade Out  0.15
```

### 11. A boss the cutscene forces you to look at

Lock On To names its node outright, so a scripted beat can override whatever the player was holding.

```
On Boss Door Opened
  -> Player | Targeting: Lock On To  Boss
  -> Camera | Look At: Look At  Boss  over 1.0 s
```

### 12. A turret with eyes all round

A 360 cone is no cone, which is what a swivel gun has. Poll it on a timer so a still turret stays cheap.

```
Every 0.25 seconds
  -> Turret | Targeting: Lock On To Nearest  "enemies", 360, 900
  Condition: Turret | Targeting  Is Locked On
    -> Turret | Look At: Look At  Turret | Targeting: Locked Target  over 0.1 s
    -> Turret: Fire
```

### 13. Only swing when the enemy is close enough

Distance To Target answers INF when nothing is held, so the check is simply false on an idle frame rather than accidentally true.

```
On Input Action Just Pressed  "attack"
  Condition: Player | Targeting: Distance To Target  <  90
    -> Player: Play Animation  "melee_swing"
  Else
    -> Player: Play Animation  "whiff"
```

### 14. A melee lock that uses a wide, short cone

Melee wants the enemy the swing should land on, not the one across the arena. Pass the cone and the range on the row and leave the Inspector for the shooting case.

```
On Input Action Just Pressed  "attack"
  -> Player | Targeting: Lock On To Nearest  "enemies", 140, 110
  Condition: Player | Targeting  Is Locked On
    -> Player | Look At: Look At  Player | Targeting: Locked Target  over 0.05 s
```

### 15. An easy mode that widens the help rather than the code

Difficulty is two numbers here: how far off dead centre still counts, and how hard the aim bends.

```
On Difficulty Set To "assisted"
  -> Accessibility: Set Aim Assist Radius  120
  -> Player: Set assist_strength = 0.7

On Difficulty Set To "standard"
  -> Accessibility: Set Aim Assist Radius  40
  -> Player: Set assist_strength = 0.25
```

### 16. A companion that holds the nearest thing it can reach

Poll it on a slow timer. A search that finds nothing leaves the current lock alone, so the pet does not drop its target on the one frame the enemy steps behind a crate.

```
Every 0.3 seconds
  -> Pet | Targeting: Lock On To Nearest  "enemies", 200, 350
  Condition: Pet | Targeting  Is Locked On
    -> Pet: Move Toward  Pet | Targeting: Locked Target
```

### Other use cases

**Photography and scanning modes.** A camera mode wants exactly what a lock-on wants: the nearest interesting thing inside a cone, held steady while the player frames it. Put the subjects in a group, use a narrow cone and Lock On To Nearest, and read Locked Target On Screen to draw the focus brackets. Cycle Target then becomes the "next subject" button of a photo mode without a line of new logic, and On Target Lost hides the brackets the moment the animal wanders off.

**Conversation and interaction prompts.** Villagers, doors and pickups in one group, a short range and a wide cone, and the held target is whatever the player is facing near enough to talk to. Locked Target On Screen positions the floating prompt, Distance To Target fades it as the player walks away, and Release Lock closes it when the dialogue opens, so the prompt never lingers over something behind the player.

**Tower placement previews.** While a tower is being dragged, attach the behaviour to the ghost and poll Lock On To Nearest against the creep group with the tower's real range. Is Locked On then tells the player, before they spend anything, whether the spot they are hovering can actually reach the lane, and Distance To Target can colour the range circle by how much reach is being wasted.

**Racing rubber-band and slipstream.** Put the cars in a group and lock on with a narrow cone straight ahead. Distance To Target drives the slipstream boost, On Target Lost with `out_of_range` ends it honestly when the car ahead pulls away, and the same lock feeds a "rival" nameplate through Locked Target On Screen without a second search of the field.

**Accessibility profiles saved per player.** Because every assist row reads one number from one place, a saved profile is one number. Write the player's aim-assist radius on load and the whole game - bullets, melee lock, magnetised turning - moves with it, and a radius of zero restores the unhelped game exactly, which is the promise an accessibility setting has to keep.

---

## Tips and common mistakes

- **The node is the one that aims - there is no targeting id.** Every row acts on the `TargetingBehavior` of the node it sits on, and one behavior holds one target. Give each aimer its own.
- **The cone width is the FULL angle, not the half-angle.** `60` reaches 30 degrees to each side of the facing. If a lock "will not find anything obviously in front", the cone is probably half the size you meant.
- **Write 0 for the cone or the range to mean "use the Inspector's".** That is the whole reason those parameters take 0 rather than requiring a number on every row, and it keeps a tuning pass in one place.
- **A search that finds nothing keeps the lock it had.** This is deliberate: polling Lock On To Nearest every frame must not drop the target on the first frame it steps behind a crate. If you want a search to be able to clear the lock, call Release Lock first.
- **Locked Target can be null - guard it.** With nothing held it hands back null. Check Is Locked On before you read a position off it, or hand it to a row that tolerates null.
- **Distance To Target is INF when nothing is held, on purpose.** It makes "closer than X" false on an idle frame. Do not compare it to 0 expecting "no target".
- **The aim-assist radius is measured ACROSS the ray, not along it.** It is how far from dead centre a target still counts, which is what the accessibility setting's own words mean. A big radius helps with wide misses, not distant ones.
- **A radius of zero turns the help off, and that is the off switch.** Assisted Aim hands the direction straight back and Magnetism leaves the turn rate alone. Do not add a second "assist enabled" flag beside it.
- **Turn on the wall check only when you have walls.** `require_line_of_sight` costs a ray per frame per lock. An open arena should leave it off; a corridor shooter should turn it on and put its walls on `blocker_mask`.
- **Keep the things you want to LOCK ON TO off the blocker mask.** The pack's own ray stops at the first body on a masked layer. If an enemy's collider is on that layer it can block the view of itself and never be lockable.
- **Cycling never lands on a corpse.** Candidates freed since the search are dropped before the step, so a shoulder button held down through a firefight stays on living enemies.
- **On Target Locked fires on a CHANGE, not on every search.** A row polled every frame therefore announces one lock, not sixty. If you want a per-frame signal, poll Is Locked On instead.
