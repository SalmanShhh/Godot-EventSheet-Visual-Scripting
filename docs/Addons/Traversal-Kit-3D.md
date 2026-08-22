# Traversal Kit 3D

**Traversal Kit 3D** is a per-node `TraversalKit3D` behavior you attach under a CharacterBody3D. It is
the movement tech a first- or third-person character reaches for once walking and jumping are not
enough: ledge grabs with a real two-probe test, mantles, wall slides, wall jumps that always kick away
from the wall, timed wall runs, ladders, vaults over knee-high obstacles, crouching that shrinks the
capsule, swimming, and buoyancy that floats you back up to the water line. It does not move the body
itself - it writes velocity and leaves the moving to whatever mover you already have, so it stacks on
top of the FPS Controller or your own movement rows instead of fighting them. Every verb is a row you
call from the sheet, so a character grabs a ledge only when your events say it should.

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [ACE reference](#ace-reference)
5. [Reading it from expressions - the Self section](#reading-it-from-expressions---the-self-section)
6. [Use cases](#use-cases)
7. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this pack shines

- **First-person parkour** - mantling a crate, running a corridor wall, kicking off to the next ledge.
- **Third-person adventure climbing** where hanging from a lip is a state, not a cutscene.
- **Shooter movement tech** layered on top of an existing controller: vaults over cover, wall runs
  across a gap.
- **Underwater levels** with a real surface line, buoyancy, and a breath meter that only refills up top.
- **Vertical maps** - shafts with ladders, ledges every few metres, water at the bottom.
- **Stealth games** where a hang under a walkway is the hiding place.
- **Obstacle-course and speedrun maps** built around chaining wall runs and mantles.
- **Puzzle rooms** where crouching fits you through a vent and a mantle gets you out.
- **Boat and swimming toys** - Float alone gives you something that bobs at the water line.
- **Ability-unlock progression** - ship the kit attached and gate each verb behind a sheet variable.

## Core concepts

- **The kit never moves the body on its own.** Almost every action writes `velocity` and stops. Your
  mover (the FPS Controller, or your own rows) is what turns that velocity into motion, so the kit's rows
  belong under an **Every tick** event or a trigger, alongside the movement you already run.
- **The two exceptions are the moves the kit owns.** A hang, a timed climb and a vault place the body
  directly for as long as they last and zero its velocity, because they are scripted moves with a start
  and an end. While one runs, nothing else can move the character.
- **Everything is in metres, and +Y is up.** Probe distances, climb rises and speeds are 3D world units,
  so the defaults are small numbers: a 0.6 m reach, a 1.6 m grab height, 9.8 for gravity. Climb Jump
  Velocity is positive because up is positive here.
- **Forward is where you are going, or where you are turned.** The kit takes the body's horizontal
  velocity as its facing direction; when the body is standing still it falls back to the way the body is
  turned. Probes, climbs and vaults all point that way, flattened to the floor plane.
- **A ledge is two probes, not one.** A forward ray at Wall Probe Height must HIT, and a second forward
  ray at Grab Height must find NOTHING. That gap over the lip is what separates a ledge you can hang from
  a wall that goes on forever. A vault is the same test at knee and chest height.
- **Probes see a physics layer.** Probe Mask decides what the ledge, wall and vault rays can hit, so
  decorative geometry on another layer never reads as a lip.
- **Ladders and water are groups, not references.** Mark a ladder Area3D with the group named by
  Ladder Group (`ladder` by default) and a water Area3D with the group named by Water Group (`water`).
  The kit looks for the first area in that group the host is actually standing inside, so you can have
  a hundred ladders and never wire one of them up.
- **The water line is measured, not guessed.** On the way in, the kit reads the top face of the water
  area's first collision shape. That is what Is Above The Surface compares against, what Water Depth
  counts down from, and what Float pushes you back towards.
- **Wall slide and wall run report per frame.** Is Wall Sliding and Is Wall Running are true on the frame
  the action actually did something (and the one after), so the test reads correctly whether your test
  row sits above or below the row that calls it.
- **A drop has a cooldown.** After Drop, the kit refuses to see a ledge for Regrab Delay seconds -
  without it you would snap straight back onto the lip you just released.

## Setup

The bundled **Traversal Course 3D** showcase (`demo/showcase/traversal_course_3d/`) runs every move
below on six self-driving actors, with no controller pack anywhere - the sheet writes gravity and the
move, this kit writes the rest.

<img src="../images/traversal-course-3d.png" alt="The Traversal Course 3D showcase: a grey floor holding five stations - a purple block on the left with a yellow capsule hanging from its edge, a grey shaft with a red capsule on top, a yellow ladder volume against a wall with a green capsule climbing it, a brown block with a purple capsule walking at it, and a blue water box on the right holding a light-blue capsule near the surface while a grey capsule lies on the ground beside it. A readout along the bottom reads climber hanging: true, jumper wall sliding: false, bot on ladder: true, diver depth: 0.88." width="640">

Attach a **TraversalKit3D** behavior under a CharacterBody3D that already has a mover and a
CollisionShape3D. Set Probe Mask to the layer your level geometry uses. For ladders, add an Area3D
covering the ladder and put it in the `ladder` group; for water, an Area3D filling the pool in the
`water` group - give it a BoxShape3D so the kit can read the surface off its top face.

A mantle and a wall jump on top of FPS Controller movement:

```
Player | FPSController  (your usual look, move and jump)
Player | TraversalKit3D  (Probe Mask = your level layer)

On jump pressed
  Condition: Player | TraversalKit3D  Is At A Ledge
    -> Player | TraversalKit3D: Grab Ledge
On jump pressed
  Condition: Player | TraversalKit3D  Is Hanging
    -> Player | TraversalKit3D: Climb Up  0.4
```

## ACE reference

On the canvas these rows read as styled sentences - parameter values in **bold**, node references in *italic*, exactly as the rows draw them:

- **Grab** the ledge
- **Climb up** over **0.4** s
- **Wall jump** away (push **6**, up **4.5**)
- **Float** with buoyancy **12**

### Actions

| Action | Parameters | Description |
|--------|-----------|-------------|
| Grab Ledge | (none) | Grabs the ledge in front: the host stops dead, holds the lip (a little below it, by Hang Offset) and fires On Ledge Grabbed. Ignored if it is already hanging. |
| Climb Up | duration (0.0) | Leaves the ledge upward. With no duration it lets go and jumps at Climb Jump Velocity - the quick exit. With a duration it is a mantle: the host is carried up and over the lip in that many seconds with nothing else able to move it, and On Climbed fires when it lands on top. |
| Drop | (none) | Lets go of the ledge and falls. The kit ignores the same lip for Regrab Delay seconds afterwards. |
| Slide Down Wall | speed (1.5) | Caps the fall while the host is pressed against a wall, so it slides instead of dropping. Does nothing when it is not on a wall or is still moving upward. |
| Wall Jump | push (6.0), rise (4.5) | Jumps AWAY from the wall: the push goes along the wall's own normal, flattened to the floor plane, so the host always leaves the wall it was on, whichever side that was. |
| Wall Run | gravity_percent (20.0), min_speed (3.0) | Runs along the wall: gravity is replaced by the percentage you give, so the host barely sinks while it keeps up speed. It needs to be on a wall, off the floor, and moving at least min_speed horizontally - and it gives out after Wall Run Max Time. |
| Climb Ladder | speed (2.5) | Drives the host up or down the ladder at this speed, from the up/down controls (or the AI axis). It writes the vertical speed outright, so gravity is off for as long as you keep calling it. |
| Vault Over | duration (0.4) | Carries the host forward over the obstacle in this many seconds. Nothing else moves it while the vault runs, and On Vaulted fires on the far side. |
| Crouch | (none) | Crouches: the host's first collision shape is swapped for a copy scaled to Crouch Scale, kept standing on the same feet. The original is put back by Stand, so the shape in your scene is never edited. |
| Stand | (none) | Stands back up and puts the original collision shape back exactly as it was. |
| Swim | gravity_percent (20.0), drag (10.0) | Swimming instead of falling: only this percentage of the kit's gravity still pulls, and the host sheds this percentage of its speed every physics frame (10 is the classic 0.9 damping). Call it every tick while in water. |
| Float | buoyancy (12.0) | Buoyancy: pushes the host upward in proportion to how deep under the surface it is, so it bobs up and settles at the water line instead of sinking. Call it every tick together with Swim. |

### Conditions

| Condition | Parameters | Description |
|-----------|-----------|-------------|
| Is At A Ledge | (none) | True when the forward probe finds a wall at chest height and the higher probe finds nothing - a lip you could hang from. False while already hanging, and for a moment after a Drop. |
| Is Hanging | (none) | True while the host is hanging from a ledge it grabbed. The kit holds it exactly where it grabbed - gravity cannot pull it off. |
| Is Wall Sliding | (none) | True on the frames a Slide Down Wall actually slowed a fall. |
| Is Wall Running | (none) | True on the frames a Wall Run is carrying the host along a wall (it stops on its own after Wall Run Max Time). |
| Is On Ladder | (none) | True while the host is standing inside an Area3D marked with the ladder group. |
| Is At A Vaultable Obstacle | (none) | True when the forward probe finds something at knee height and nothing at chest height - a low obstacle you could throw yourself over. |
| Is Crouching | (none) | True while the host is crouched (its collider is the short one). |
| Is In Water | (none) | True while the host is inside an Area3D marked with the water group. |
| Is Above The Surface | (none) | True when the host's own point is above the water line of the area it is in - the test that lets a swimmer breathe, climb out, or hold at the top. Always true out of water. |

### Expressions

| Expression | Returns | Description |
|-----------|---------|-------------|
| Water Depth | float | How far below the water line the host is, in metres (0 out of water or at the surface). |

### Triggers

| Trigger | Description |
|---------|-------------|
| On Ledge Grabbed | Fires the moment Grab Ledge takes hold of a lip. |
| On Climbed | Fires when a Climb Up finishes - immediately for the jump exit, on arrival for a timed mantle. |
| On Vaulted | Fires when a Vault Over lands on the far side of the obstacle. |
| On Entered Water | Fires the frame the host enters an area in the water group. |
| On Left Water | Fires the frame the host leaves it. |

### Inspector properties

| Property | Default | Description |
|----------|---------|-------------|
| Probe Distance | 0.6 | How far ahead the kit looks for a wall, in metres. |
| Wall Probe Height | 1.0 | Height above the feet where the forward probe must FIND a wall, in metres. |
| Grab Height | 1.9 | Height above the feet where the second probe must find NOTHING - the gap over the lip that makes a wall a ledge. |
| Hang Offset | 0.3 | How far below the lip the hands hold once grabbed, in metres. |
| Climb Jump Velocity | 4.5 | Upward velocity when Climb Up is called with no duration - the let-go-and-jump exit. |
| Climb Forward | 0.8 | How far forward a timed climb (a mantle) carries the body, in metres. |
| Climb Rise | 1.6 | How far up a timed climb carries the body, in metres. |
| Regrab Delay | 0.3 | How long after a Drop the kit refuses to see a ledge again, in seconds. |
| Probe Mask | layer 1 | Which physics layers the ledge, wall and vault probes can see. |
| Wall Run Max Time | 1.2 | Longest a single wall run may last, in seconds. |
| Gravity | 9.8 | Downward pull the kit uses for its own vertical moves (wall running, swimming), in metres per second squared. |
| Ladder Group | `ladder` | Objects in this group count as ladders - mark a ladder Area3D with it. |
| Vault Probe Height | 0.3 | Height above the feet where the vault probe must FIND the obstacle (knee height), in metres. |
| Vault Clear Height | 1.0 | Height above the feet that must be CLEAR for the obstacle to be vaultable (chest height), in metres. |
| Vault Distance | 1.6 | How far forward Vault Over carries the body, in metres. |
| Crouch Scale | 0.5 | How much of its height the collider keeps while crouched (0.1 to 1.0). |
| Water Group | `water` | Objects in this group count as water - mark a water Area3D with it. |
| AI Controlled | off | AI drive: the kit reads the held `ai_climb_axis` intent instead of the up/down controls, so a sheet or an AI driver steers the climb exactly the way a player's keys would. |

### Inspector properties are ACEs too

Every property this pack exposes in the Inspector is also reachable from the picker, generated for you:
an expression named after the property reads it, a **Set ...** action writes it, and for number properties
**Add To ...** and **Subtract From ...** adjust it by an amount. They sit in the pack's own category
alongside the vocabulary above, so any knob you can set in the Inspector is also something a sheet can read and
change while the game runs - a longer wall run is a **Set Wall Run Max Time** row, not a new behavior.

## Reading it from expressions - the Self section

Type `self` in any ƒx field, or open the ƒx **Expressions dictionary**, and **Self ▸ Behaviours**
lists this pack's knobs and value expressions as ready-to-insert chains once the behaviour is attached:

- `$TraversalKit3D.water_depth()` inserts the **Water Depth** entry straight into any expression
- `$TraversalKit3D.vault_distance` inserts the **Vault Distance** knob straight into any expression

The `$TraversalKit3D` token stays selected after insert, so retargeting to your child's actual name is
one keystroke, or a node drag. Attaching this behaviour at runtime instead? Tick **Robust behaviour
lookups** in the dictionary and the same entries insert as `get_node_or_null("TraversalKit3D")` chains,
which survive auto-named children.

## Use cases

**1. Mantle onto a crate with one button.** The same key grabs and then climbs, because the two
conditions never overlap.

```
On jump pressed
  Condition: Player | TraversalKit3D  Is At A Ledge
    -> Player | TraversalKit3D: Grab Ledge
On jump pressed
  Condition: Player | TraversalKit3D  Is Hanging
    -> Player | TraversalKit3D: Climb Up  0.4
```

**2. Hang, then drop back down.** Regrab Delay is what stops the lip catching you again.

```
On crouch pressed
  Condition: Player | TraversalKit3D  Is Hanging
    -> Player | TraversalKit3D: Drop
```

**3. Grab automatically while falling.** A generous assist for a platforming section.

```
Every tick
  Condition: Player | TraversalKit3D  Is At A Ledge
  Condition: Player is off the floor and falling
    -> Player | TraversalKit3D: Grab Ledge
```

**4. Camera and hands while hanging.** Is Hanging is a plain state you can drive the rig from.

```
Player On Ledge Grabbed
  -> play "grab" on the arms rig
  -> Camera: small downward tilt
```

**5. Wall slide down a shaft.** Call it every tick; it only bites when the body is on a wall and falling.

```
Every tick
  -> Player | TraversalKit3D: Slide Down Wall  1.5
Every tick
  Condition: Player | TraversalKit3D  Is Wall Sliding
    -> spawn scrape particles at the Player
```

**6. Wall jump that always leaves the wall.** The push follows the wall's flattened normal, so one row
covers every wall in the level.

```
On jump pressed
  Condition: Player | TraversalKit3D  Is Wall Sliding
    -> Player | TraversalKit3D: Wall Jump  6, 4.5
    -> play a kick-off sound
```

**7. Wall run across a gap while sprinting.** It needs speed, a wall and air, and it gives out on its own
after Wall Run Max Time.

```
Every tick
  Condition: sprint is held
    -> Player | TraversalKit3D: Wall Run  20, 3
Every tick
  Condition: Player | TraversalKit3D  Is Wall Running
    -> Camera: lean toward the wall
```

**8. Ladders that need no wiring.** Put every ladder Area3D in the `ladder` group and this one event
covers the whole map.

```
Every tick
  Condition: Player | TraversalKit3D  Is On Ladder
    -> Player | TraversalKit3D: Climb Ladder  2.5
```

**9. Vault over cover.** The kit tells you when a vault is even possible, so the prompt is never a lie.

```
On jump pressed
  Condition: Player | TraversalKit3D  Is At A Vaultable Obstacle
    -> Player | TraversalKit3D: Vault Over  0.4
Player On Vaulted
  -> play a landing thud
```

**10. Crouch through a vent.** The capsule shrinks to Crouch Scale and Stand puts the original back
untouched.

```
On crouch pressed
  -> Player | TraversalKit3D: Crouch
On crouch released
  Condition: there is headroom above the Player
    -> Player | TraversalKit3D: Stand
```

**11. A crouch slide that reuses the controller's own slide.** The FPS Controller already has a crouch
slide with On Slide Started / On Slide Ended and a Stop Sliding action - let it own the slide and use
the kit for what comes after it.

```
Player On Slide Started
  -> Camera: tilt into the slide
Player On Slide Ended
  Condition: Player | TraversalKit3D  Is At A Vaultable Obstacle
    -> Player | TraversalKit3D: Vault Over  0.35
```

**12. Swim instead of sink.** Swim replaces the fall with a slow drift plus drag, every tick while in
water.

```
Every tick
  Condition: Player | TraversalKit3D  Is In Water
    -> Player | TraversalKit3D: Swim  20, 10
```

**13. Bob at the surface with buoyancy.** Float pushes up in proportion to depth, so the deeper you are
the harder the water pushes back - pair it with Swim.

```
Every tick
  Condition: Player | TraversalKit3D  Is In Water
    -> Player | TraversalKit3D: Swim  20, 10
    -> Player | TraversalKit3D: Float  12
```

**14. A breath meter that only refills at the surface.** Compose the shipped **Drain Meter** and
**Fill Meter** system actions - the kit supplies the two tests, the meters supply the arithmetic.

```
Every tick
  Condition: Player | TraversalKit3D  Is In Water
  Condition: Player | TraversalKit3D  Is Above The Surface  (inverted)
    -> Drain Meter  breath  by 12 per second, floor 0
Every tick
  Condition: Player | TraversalKit3D  Is Above The Surface
    -> Fill Meter  breath  by 30 per second, cap 100
```

**15. Depth effects that scale with how deep you are.** Water Depth is a number in metres, so the fog and
the muffle are one expression each.

```
Every tick
  Condition: Player | TraversalKit3D  Is In Water
    -> set the underwater fog density from Player | TraversalKit3D.Water Depth() / 20
    -> set the underwater bus wet level from the same value
```

**16. Splashes on both edges of the water.** Both are triggers, so no polling.

```
Player On Entered Water
  -> spawn a splash at the Player
  -> play a splash sound
Player On Left Water
  -> spawn a smaller splash
```

### Other use cases

**Ledge-hang stealth.** Hold a hang under a walkway while a patrol passes overhead, then Climb Up once the guard has gone - Is Hanging is a state your alert system can read directly.

**Ability gating.** Ship the kit attached and put a sheet variable in front of each verb, so a wall run or a vault only becomes possible after the upgrade that grants it.

**Traversal prompts.** Show an on-screen hint only when Is At A Ledge or Is At A Vaultable Obstacle is true, teaching the move at exactly the spot where it works.

**AI climbers.** Give a pursuer the same behavior with AI Controlled on and drive `ai_climb_axis` from its logic, so it follows the player up ladders under the same rules.

**Floating props.** Attach the kit to a barrel-shaped CharacterBody3D, call Float every tick and nothing else, and you get a crate that bobs at the water line for free.

## Tips and common mistakes

- **Nothing here moves the body by itself.** The kit writes velocity; your mover applies it. If a wall
  jump seems to do nothing, check that the FPS Controller (or your own movement) is still running on the
  same node.
- **Call the every-tick verbs every tick.** Swim, Float, Wall Run, Slide Down Wall and Climb Ladder each
  affect exactly the frame you call them on. One-shot calls do nothing visible.
- **Everything is metres.** A probe distance of 20 would reach across the whole room; the defaults are
  0.4 to 1.6 for a reason, and the speeds are single digits rather than hundreds.
- **Set Probe Mask to your level layer.** With the wrong layer the ledge probes never hit and
  Is At A Ledge is permanently false - which looks identical to a broken behavior.
- **Forward comes from the body, not the camera.** The kit uses the body's horizontal velocity, falling
  back to the way the body is turned. If your rig only rotates the camera and never the body, turn the
  body too, or the probes will point somewhere you are not looking.
- **Grab Height must clear the lip.** If Grab Height is too low, the second probe hits the same wall and
  no ledge is ever detected; if it is far too high, ordinary walls read as ledges.
- **The speeds live on the rows, not in the Inspector.** Slide Down Wall, Wall Jump, Wall Run and
  Climb Ladder each carry their own numbers, so two objects can share one kit and still feel different -
  and a row you can read beats a knob you have to go and look up.
- **Ladders and water are groups.** An Area3D that is not in the `ladder` / `water` group is invisible to
  the kit, and so is one with monitoring turned off.
- **Water needs a collision shape to have a surface.** The water line is read off the area's first
  CollisionShape3D; without one, Is Above The Surface, Water Depth and Float fall back to the area's
  origin.
- **Crouch touches the first CollisionShape3D it finds.** If your host has several, put the body's own
  capsule first. If your mover already crouches (the FPS Controller does), pick one of the two rather
  than crouching twice.
- **A timed climb or vault owns the body.** While one runs, velocity is zeroed and your mover cannot
  steer; keep the durations short (0.3 to 0.5 s) unless the animation really is that long.
