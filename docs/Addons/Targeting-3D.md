# Targeting 3D - Lock On, Cycle, And Aim Help In 3D

Targeting 3D is a Godot EventSheets behavior pack that gives a 3D node one held enemy and a steadier aim. You attach a `Targeting3DBehavior` behavior to a `Node3D` - a player, a turret, a drone, a homing rocket - and that node becomes the thing that aims. It is the Targeting pack's twin, word for word, with the two things only 3D has: the cone is measured around the CAMERA's forward rather than the host's own rotation, because a third-person game locks on to what is on screen, and Snap On Aim Down Sights turns the host onto the nearest target the instant the sights come up. Alongside the lock there is aim help that needs no lock at all: an expression that bends a stick direction toward whatever the player is nearly pointing at, and one that drags the turn rate while the aim crosses a target. All three read the aim-assist radius the accessibility rows already declare, so the options screen you have controls them, and a radius of zero turns them off.

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

- **Third-person action games.** Hold the nearest hostile on screen, orbit around it, and let go by itself when it dies.
- **Shooters with sights.** Snap On Aim Down Sights gives a controller player the settle they expect the moment the sights come up, without yanking the view.
- **Controller aim help.** A stick is coarse. Assisted Aim bends the shot toward what the player is nearly pointing at, by an amount an options slider sets.
- **Reticles and nameplates.** Locked Target On Screen projects the held enemy through the camera, so a CanvasLayer reticle needs no maths of its own.
- **Cycling through a crowd.** A shoulder button that steps left to right through everything in view, and wraps, is one row.
- **Homing rockets and beams.** Locked Target is a node you can hand straight to a projectile, a tween, a Look At, or a nameplate's anchor.
- **Turrets and drones.** With no camera in the scene the cone falls back to the host's own forward, which is exactly what a fixed gun wants.
- **Boss and cutscene focus.** Lock On To names one node outright, whatever the cone says, so a scripted moment can force the camera's attention.
- **Cover-aware combat.** Turn the line-of-sight option on and a lock breaks the instant geometry comes between the two, with the reason word to prove it.
- **Accessibility settings that finally do something.** The aim-assist radius stops being a number nobody reads and becomes the strength of the help.
- **Melee and parry target selection.** A short range and a wide cone pick the enemy a swing should land on, instead of the one the animation happens to face.
- **Flight and space combat.** A wide cone around the camera's forward with a long reach is the lock a dogfight needs, and Distance To Target drives the lead indicator.

---

## Core concepts

The pack is small, and six ideas carry all of it.

**The node is the one that aims.** You add a `Targeting3DBehavior` as a child of a `Node3D`, and that parent is the host. Every search starts from the host's world position, and every row acts on the behavior of the node it sits on. There is no targeting id to thread through calls, and one node holds one target.

**The cone is around the CAMERA's forward.** This is the difference from the 2D twin, and it is deliberate: in a third-person game the player locks on to what is on screen, not to what the character model happens to be turned toward. The pack asks the viewport for its current `Camera3D` and centres the cone on that camera's forward. With no camera in the scene to ask, it falls back to the host's own forward axis, which is what a turret or a headless test has. `lock_cone_degrees` is the FULL width: 60 reaches 30 degrees to each side. Write 360 for no cone at all.

**One target is held, and the ring remembers the rest.** Lock On To Nearest searches the cone and keeps the whole list of what it found, ordered left to right by angle about the world's up axis. That list is the ring. Cycle Target steps along it and wraps round from the rightmost back to the leftmost, so a shoulder button walks the crowd in the order the player sees them, not in whatever order the tree happens to hold them.

**A lock ends in exactly four ways, and says which.** On Target Lost carries one word: `died` when the target was freed, `out_of_range` when it walked past the reach the lock was taken at, `blocked` when geometry came between the two (only with the line-of-sight option on), and `released` when a row let go on purpose. One trigger row therefore cleans the reticle up after all four, and the word tells them apart when you want them to differ. A dead target is released the frame it dies, before anything reads a position off it.

**Aim help is separate from the lock, and the options screen owns it.** Assisted Aim, Magnetism and Snap On Aim Down Sights never touch the held target. They ask a different question - what is the aim ray nearly pointing at right now - and "nearly" is the aim-assist radius the accessibility rows declare, measured ACROSS the ray. A radius of zero means nothing is ever near enough, so the two expressions hand back exactly what they were given, the snap does nothing, and the whole feature is off. That is the honest off switch, and it is already on the options screen.

**Snapping refuses a turn that is too big.** Snap On Aim Down Sights takes the widest turn you will allow, in degrees. A target further off than that is left alone entirely, which is what keeps the settle from becoming a yank: the sights come up and the view tightens onto what the player was already nearly on, never onto something behind them.

---

## Setup

**1. Attach the behavior.** Add a `Targeting3DBehavior` behavior as a child node of the `Node3D` that aims (open the pack sheet and use Tools > Attach to Selected Node, or drop the pack node in as a child). The behavior grabs its parent as the host on ready.

**2. Put your hostiles in a group.** The pack searches groups, so add the enemies to one (`enemies` by default) in the Scene dock's Node > Groups tab, or with an Add To Group action when they spawn.

**3. Set the Inspector knobs.** Select the behavior node and tune it:

| Property | Default | What it does |
|---|---|---|
| `target_group` | `&"enemies"` | The group the rows search when a row names none. |
| `lock_cone_degrees` | `60.0` | The full cone width in degrees around the camera's forward, used when a row leaves its own cone at 0. |
| `lock_range` | `40.0` | The reach in metres a search covers, and the distance a held lock is lost past, when a row leaves its own range at 0. |
| `require_line_of_sight` | `false` | Whether geometry hides a target and breaks a lock. Off by default, because a ray per frame is a cost an open arena should not pay. |
| `blocker_mask` | `1` | The physics layers a wall lives on, for the sight ray this pack casts when no Line Of Sight 3D behavior is attached to the same host. |
| `magnetism_slowdown` | `0.5` | How much Magnetism slows a turn while the aim crosses a target. 1 is no slowing, 0 stops the turn dead. |

**4. Lock, read, release.** Here is a complete first setup: a button locks on, a reticle follows, and it hides itself when the lock ends.

```
On Input Action Just Pressed  "lock_on"
  -> Player | Targeting 3D: Lock On To Nearest  "enemies", 60, 40

Every tick
  Condition: Player | Targeting 3D  Is Locked On
    -> Reticle: Set Position to  Player | Targeting 3D: Locked Target On Screen
    -> Reticle: Show

On Player | Targeting 3D: On Target Lost
  -> Reticle: Hide
```

Nothing else is registered and nothing is polled that does not need to be: the per-frame loss check starts with the first lock and parks itself with the last, so an unlocked node costs nothing.

---

## ACE reference

All ACEs live in the **Targeting 3D** category and act on the `Targeting3DBehavior` attached to the node they are placed on. There is no targeting id parameter anywhere.

### Actions

| Action | Parameters | Description |
|---|---|---|
| Lock On To Nearest | `group` (StringName), `cone_degrees` (float), `max_range` (float) | Searches a cone around the camera's forward for the closest member of a group inside a range, and holds it. Leave the group empty for the behavior's own Target Group, and write 0 for the cone or the range to use its own defaults. A search that finds nothing leaves the current lock alone. With no camera in the scene the cone falls back to the host's own forward axis. |
| Lock On To | `node` (Node3D) | Holds one node you name, whatever the cone and the range say - a named lock has no reach at all, so the boss a cutscene points at is held however far off it is. It becomes the only entry in the ring, so a Cycle Target after it stays on it until the next search. Losing sight of it, and its dying, still end it. |
| Cycle Target | (none) | Steps to the next candidate the last Lock On To Nearest found, left to right by angle about the world's up axis, wrapping from the rightmost back to the leftmost. Candidates that died since the search are dropped first. With nothing held it takes the leftmost. |
| Release Lock | (none) | Lets the held target go on purpose. On Target Lost fires with the reason `released`. |
| Snap On Aim Down Sights | `max_degrees` (float) | Turns the host to face the nearest target the aim is already nearly on. Refuses a turn wider than `max_degrees`, and does nothing at all while the aim-assist radius is zero. |

These next actions write to the exported knobs at runtime and are reflected from the `@export` properties.

| Action | Parameters | Description |
|---|---|---|
| Set Target Group | `value` (StringName) | Sets the group the rows search when a row names none. |
| Set Lock Cone Degrees | `value` (float) | Sets the default cone width in degrees. |
| Add To Lock Cone Degrees | `amount` (float) | Widens the default cone by `amount` degrees. |
| Subtract From Lock Cone Degrees | `amount` (float) | Narrows the default cone by `amount` degrees. |
| Set Lock Range | `value` (float) | Sets the default reach in metres. |
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
| Locked Target | (none) | Node3D | The node being held, or null when nothing is. Hand it to any row that takes a node. |
| Locked Target On Screen | (none) | Vector2 | Where the held target lands on screen right now, through the camera's own projection. Vector2.ZERO when nothing is held or there is no camera to ask. |
| Distance To Target | (none) | float | How far the held target is, in metres. INF when nothing is held, so "is the target closer than 5" is plainly false rather than accidentally true. |
| Assisted Aim | `direction` (Vector3), `strength` (float) | Vector3 | The direction you hand it, bent toward the nearest target the ray is nearly pointing at, by a strength from 0 (no help) to 1 (dead on). The length you passed in is kept. |
| Magnetism | `turn_rate` (float) | float | The turn rate you hand it, slowed by Magnetism Slowdown while the aim is crossing a target. Unchanged otherwise. |
| Target Group | (none) | StringName | The group the rows search when a row names none. |
| Lock Cone Degrees | (none) | float | The current default cone width, in degrees. |
| Lock Range | (none) | float | The current default reach, in metres. |
| Require Line Of Sight | (none) | bool | Whether the wall check is on. |
| Blocker Mask | (none) | int | The current blocker mask value. |
| Magnetism Slowdown | (none) | float | The current magnetism slowdown factor. |

### Triggers

| Trigger | Carries | Fires when |
|---|---|---|
| On Target Locked | `target` (Node3D) | The held target CHANGES. Locking on to what is already held is not a new lock, so a row polled every frame fires this once, not every frame. |
| On Target Lost | `why` (StringName) | A lock ends, for any of the four reasons: `died`, `out_of_range`, `blocked`, `released`. |

### Inspector properties

| Property | Type | Default | What it controls |
|---|---|---|---|
| `target_group` | StringName | `&"enemies"` | The group searched when a row names none. |
| `lock_cone_degrees` | float | `60.0` | The default full cone width in degrees around the camera's forward. |
| `lock_range` | float | `40.0` | The default reach in metres, and the distance a lock taken at that reach is lost past. |
| `require_line_of_sight` | bool | `false` | Whether geometry hides a target and breaks a lock. |
| `blocker_mask` | int | `1` | The physics layers a wall lives on, for this pack's own sight ray. |
| `magnetism_slowdown` | float | `0.5` | The factor Magnetism multiplies a turn rate by while the aim crosses a target. |

---

## Reading it from expressions - the Self section

Type `self` in any ƒx field, or open the ƒx **Expressions dictionary**, and **Self ▸ Behaviours**
lists this pack's knobs and value expressions as ready-to-insert chains once the behaviour is attached:

- `$Targeting3DBehavior.lock_range` inserts the **Lock Range** entry straight into any expression
- `$Targeting3DBehavior.lock_cone_degrees` inserts the **Lock Cone Degrees** entry straight into any expression

The `$Targeting3DBehavior` token stays selected after insert, so retargeting to your child's actual name is one
keystroke, or a node drag. Attaching this behaviour at runtime instead? Tick **Robust behaviour
lookups** in the dictionary and the same entries insert as `get_node_or_null("Targeting3DBehavior")` chains,
which survive auto-named children. While **Live Values** streams from a running game, the group
upgrades to *Behaviours (live - on your node)* and reads the RUNNING instance - behaviours
attached at runtime included, under their real names. And with your node selected in the Scene
dock, the section grounds to that node's actual children before you even press Run.

## Use cases

Each example acts on the `Targeting3DBehavior` attached to the named node.

### 1. Lock on with a button, and let go by itself

The whole loop in three rows. The lock ends on its own when the enemy dies, so nothing has to remember to clear it.

```
On Input Action Just Pressed  "lock_on"
  -> Player | Targeting 3D: Lock On To Nearest  "enemies", 60, 40

On Player | Targeting 3D: On Target Locked
  -> Reticle: Show

On Player | Targeting 3D: On Target Lost
  -> Reticle: Hide
```

### 2. A reticle that sits on the held enemy

Locked Target On Screen projects through the camera the player is actually looking through, so a reticle living on a CanvasLayer needs no conversion of its own.

```
Every tick
  Condition: Player | Targeting 3D  Is Locked On
    -> Reticle: Set Position to  Player | Targeting 3D: Locked Target On Screen
```

### 3. Cycle through the crowd with a shoulder button

The ring is ordered left to right by angle about the world's up axis, so the button walks the enemies in the order the player sees them, and wraps.

```
On Input Action Just Pressed  "next_target"
  -> Player | Targeting 3D: Cycle Target
```

### 4. Settle the view when the sights come up

The snap refuses a turn wider than the degrees you allow, so raising the sights tightens onto what the player was already nearly on and never yanks the camera somewhere else.

```
On Input Action Just Pressed  "aim_down_sights"
  -> Player | Targeting 3D: Snap On Aim Down Sights  8
  -> Camera: Set FOV to  55
```

### 5. Fire along an assisted stick

A controller stick is coarse. Bend it toward whatever it is nearly pointing at, by a strength you pick, and spawn the projectile along the bent direction.

```
On Input Action Just Pressed  "fire"
  -> Player: Spawn "res://rocket.tscn" facing  Player | Targeting 3D: Assisted Aim  Player.aim_direction, 0.35
```

### 6. Turn the assist off from the options screen

Nothing here knows what an options screen is. All three assist rows read the aim-assist radius the accessibility rows declare, and zero means no target is ever near enough.

```
On Slider "aim_assist" Changed
  -> Accessibility: Set Aim Assist Radius  Slider.value
```

### 7. Stickier turning across an enemy

Magnetism drags the turn rate while the aim crosses something, so the stick settles on an enemy instead of sliding past it.

```
Every tick
  -> Player: Set look_speed to  Player | Targeting 3D: Magnetism  Player.base_look_speed
  -> Camera: Rotate by  Player.look_stick * Player.look_speed * dt
```

### 8. A homing rocket that follows the held node

Locked Target is a node, not a position, so anything that takes a node takes it. The rocket keeps chasing even as the enemy moves.

```
On Input Action Just Pressed  "fire"
  Condition: Player | Targeting 3D  Is Locked On
    -> Rocket: Set homing_target to  Player | Targeting 3D: Locked Target
```

### 9. An orbit camera while a lock is held

Is Locked On is the whole gate. Free camera when nothing is held, framed camera when something is.

```
Every tick
  Condition: Player | Targeting 3D  Is Locked On
    -> Camera | Look At: Look At  Player | Targeting 3D: Locked Target  over 0.2 s
  Else
    -> Camera | Look At: Look At  Player  over 0.4 s
```

### 10. Break the lock behind cover

Turn `require_line_of_sight` on and geometry ends the lock with the reason `blocked`. If a Line Of Sight 3D behavior is attached to the same host, this pack asks it rather than casting its own ray, so the two agree about what a wall is.

```
On Difficulty Set To "realistic"
  -> Player | Targeting 3D: Set Require Line Of Sight  true

On Player | Targeting 3D: On Target Lost
  Condition: why  =  "blocked"
    -> HUD: Flash "Lost sight"
```

### 11. React differently to each of the four endings

One trigger row carries the reason, so the four cases branch off one place.

```
On Player | Targeting 3D: On Target Lost
  Condition: why  =  "died"
    -> HUD: Add Score  100
  Condition: why  =  "out_of_range"
    -> HUD: Show "Target escaped"
  Condition: why  =  "released"
    -> Reticle: Fade Out  0.15
```

### 12. A boss the cutscene forces you to look at

Lock On To names its node outright, so a scripted beat can override whatever the player was holding.

```
On Boss Door Opened
  -> Player | Targeting 3D: Lock On To  Boss
  -> Camera | Look At: Look At  Boss  over 1.0 s
```

### 13. A turret with no camera to ask

With no camera in the scene the cone falls back to the host's own forward axis, so a fixed gun aims from its own barrel. Poll it on a timer to keep an idle turret cheap.

```
Every 0.25 seconds
  -> Turret | Targeting 3D: Lock On To Nearest  "enemies", 120, 60
  Condition: Turret | Targeting 3D  Is Locked On
    -> Turret | Look At: Look At  Turret | Targeting 3D: Locked Target  over 0.1 s
    -> Turret: Fire
```

### 14. Only swing when the enemy is close enough

Distance To Target answers INF when nothing is held, so the check is simply false on an idle frame rather than accidentally true.

```
On Input Action Just Pressed  "attack"
  Condition: Player | Targeting 3D: Distance To Target  <  2.5
    -> Player: Play Animation  "melee_swing"
  Else
    -> Player: Play Animation  "whiff"
```

### 15. A melee lock that uses a wide, short cone

Melee wants the enemy the swing should land on, not the one across the arena. Pass the cone and the range on the row and leave the Inspector for the shooting case.

```
On Input Action Just Pressed  "attack"
  -> Player | Targeting 3D: Lock On To Nearest  "enemies", 160, 3
  Condition: Player | Targeting 3D  Is Locked On
    -> Player | Look At: Look At  Player | Targeting 3D: Locked Target  over 0.05 s
```

### 16. An easy mode that widens the help rather than the code

Difficulty is two numbers here: how far off dead centre still counts, and how hard the aim bends.

```
On Difficulty Set To "assisted"
  -> Accessibility: Set Aim Assist Radius  4
  -> Player: Set assist_strength = 0.7

On Difficulty Set To "standard"
  -> Accessibility: Set Aim Assist Radius  1.2
  -> Player: Set assist_strength = 0.25
```

### Other use cases

**Space and flight combat.** A dogfight is a lock-on with a long reach and a wide cone around the camera's forward. Poll Lock On To Nearest against the enemy-ship group, read Distance To Target to drive a lead indicator and a missile-tone pitch, and let On Target Lost with `out_of_range` end the tone honestly when a ship breaks away. Cycle Target then becomes the "next contact" button a cockpit already has a place for.

**Photography, scanning and survey modes.** A scanner wants exactly what a lock-on wants: the nearest interesting thing inside a cone, held steady while the player frames it. Put the subjects in a group, use a narrow cone, and read Locked Target On Screen to draw the focus brackets through the real camera. Cycle Target is the "next subject" button, and On Target Lost hides the brackets the moment the creature wanders off.

**Interaction prompts in a first-person world.** Doors, levers and pickups in one group, a very short range and a narrow cone, and the held target is whatever the player is looking near enough at to use. Locked Target On Screen positions the floating prompt, Distance To Target fades it as they step back, and Release Lock closes it when a menu opens so the prompt never lingers behind the player.

**Photo-mode and replay camera framing.** Attach the behaviour to a free-flying replay camera's rig and lock on to the group of actors. The lock keeps the subject framed while the operator moves, Snap On Aim Down Sights becomes a "recentre on subject" button, and because the cone is the camera's own forward the tool follows the operator's eye rather than the rig's rotation.

**Accessibility profiles saved per player.** Because every assist row reads one number from one place, a saved profile is one number. Write the player's aim-assist radius on load and the whole game - projectiles, melee lock, magnetised turning, the sights snap - moves with it, and a radius of zero restores the unhelped game exactly, which is the promise an accessibility setting has to keep.

---

## Tips and common mistakes

- **The cone follows the CAMERA, not the host.** This is the one thing that differs from the 2D twin. Turning the character model does not move the cone; turning the camera does. If a lock "ignores where my character is facing", that is the design: a third-person game locks on to what is on screen.
- **No camera means the host's own forward.** A scene with no `Camera3D` (a turret prefab, a test) falls back to the host's -Z. That is deliberate, not a failure mode, but it does mean a lock can behave differently the moment a camera enters the scene.
- **The node is the one that aims - there is no targeting id.** Every row acts on the `Targeting3DBehavior` of the node it sits on, and one behavior holds one target. Give each aimer its own.
- **The cone width is the FULL angle, not the half-angle.** `60` reaches 30 degrees to each side of the forward. If a lock "will not find anything obviously on screen", the cone is probably half the size you meant.
- **Write 0 for the cone or the range to mean "use the Inspector's".** That is the whole reason those parameters take 0 rather than requiring a number on every row, and it keeps a tuning pass in one place.
- **The range is in metres, not pixels.** The default reach is 40, which is a room, not a level. A pixel-sized number copied from the 2D twin will lock on to the whole map.
- **A search that finds nothing keeps the lock it had.** This is deliberate: polling Lock On To Nearest every frame must not drop the target on the first frame it steps behind a pillar. If you want a search to be able to clear the lock, call Release Lock first.
- **Locked Target can be null - guard it.** With nothing held it hands back null. Check Is Locked On before you read a position off it, or hand it to a row that tolerates null.
- **Distance To Target is INF when nothing is held, on purpose.** It makes "closer than X" false on an idle frame. Do not compare it to 0 expecting "no target".
- **The aim-assist radius is measured ACROSS the ray, not along it.** It is how far from dead centre a target still counts, which is what the accessibility setting's own words mean. A big radius helps with wide misses, not distant ones. In 3D it is in metres, so the numbers are much smaller than a 2D game's.
- **A radius of zero turns the help off, and that is the off switch.** Assisted Aim hands the direction straight back, Magnetism leaves the turn rate alone, and the snap does nothing. Do not add a second "assist enabled" flag beside it.
- **Snap On Aim Down Sights turns the HOST, not the camera.** It is the character settling onto the target. If your camera is a child of the host it comes along; if it is on its own rig, follow the snap with your own camera row.
- **Turn on the wall check only when you have walls.** `require_line_of_sight` costs a ray per frame per lock. An open arena should leave it off; a cover shooter should turn it on and put its geometry on `blocker_mask`.
- **Keep the things you want to LOCK ON TO off the blocker mask.** The pack's own ray stops at the first body on a masked layer. If an enemy's collider is on that layer it can block the view of itself and never be lockable.
- **On Target Locked fires on a CHANGE, not on every search.** A row polled every frame therefore announces one lock, not sixty. If you want a per-frame signal, poll Is Locked On instead.
