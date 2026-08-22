# Traversal Kit

**Traversal Kit** is a per-node `TraversalKit` behavior you attach under a CharacterBody2D. It is the
whole moveset a side-on character needs once plain running and jumping stop being enough: ledge grabs
with a real two-probe test, mantles, wall slides, wall jumps that always kick away from the wall, timed
wall runs, ladders, vaults over knee-high obstacles, crouching that shrinks the collider, and swimming
with a water line the sheet can test against. It does not move the body itself - it writes velocity and
leaves the moving to whatever mover you already have, so it stacks on top of the Platformer behavior or
your own movement rows instead of fighting them. Every verb is a row you call from the sheet, so a
character grabs a ledge only when your events say it should.

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [ACE reference](#ace-reference)
5. [Reading it from expressions - the Self section](#reading-it-from-expressions---the-self-section)
6. [Use cases](#use-cases)
7. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this pack shines

- **Metroidvania traversal** - the ledge grab, the wall jump and the vault are the three moves that turn
  a map into a playground.
- **Ninja and parkour platformers** where wall running and chaining wall jumps is the whole game.
- **Cave and ruin exploration** with ladders down shafts and water at the bottom.
- **Puzzle platformers** where a crouch fits you through a gap and a mantle gets you back out.
- **Stealth side-scrollers** - hang from a lip until the guard walks past, then climb.
- **Swimming levels** with a breath meter that only refills at the surface.
- **Boss arenas with climbable walls** where repositioning is a wall jump, not a run.
- **Speedrun-friendly movement** - vaults and wall runs give skilled players a faster line.
- **Cinematic set pieces** where a timed mantle is the animation, not a tween you hand-write.
- **Character-ability unlocks** - ship the kit attached and gate each verb behind a sheet variable.

## Core concepts

- **The kit never moves the body on its own.** Almost every action writes `velocity` and stops. Your
  mover (the Platformer behavior, or your own rows) is what turns that velocity into motion, so the kit's
  rows belong under an **Every tick** event or a trigger, alongside the movement you already run.
- **The two exceptions are the moves the kit owns.** A hang, a timed climb and a vault place the body
  directly for as long as they last and zero its velocity, because they are scripted moves with a start
  and an end. While one runs, nothing else can move the character.
- **A ledge is two probes, not one.** A forward ray at Wall Probe Height must HIT, and a second forward
  ray at Grab Height must find NOTHING. That gap over the lip is what separates a ledge you can hang from
  a wall that goes on forever. A vault is the same test at knee and chest height.
- **Probes see a physics layer.** Probe Mask decides what the ledge, wall and vault rays can hit, so a
  decorative foreground layer never reads as a lip.
- **Ladders and water are groups, not references.** Mark a ladder Area2D with the group named by
  Ladder Group (`ladder` by default) and a water Area2D with the group named by Water Group (`water`).
  The kit looks for the first area in that group the host is actually standing inside, so you can have
  a hundred ladders and never wire one of them up.
- **The water line is measured, not guessed.** On the way in, the kit reads the top edge of the water
  area's first collision shape. That is what Is Above The Surface compares against and what Water Depth
  counts down from.
- **Facing comes from movement.** The kit remembers which way the body was last moving horizontally, and
  climbs, vaults and probes all point that way.
- **Wall slide and wall run report per frame.** Is Wall Sliding and Is Wall Running are true on the frame
  the action actually did something (and the one after), so the test reads correctly whether your test
  row sits above or below the row that calls it.
- **A drop has a cooldown.** After Drop, the kit refuses to see a ledge for Regrab Delay seconds -
  without it you would snap straight back onto the lip you just released.

## Setup

The bundled **Traversal Course** showcase (`demo/showcase/traversal_course/`) is one station per move,
and four of its actors run the rows below with no input at all - open its `.gd` as a sheet to read the
whole course as events.

<img src="../images/traversal-course.png" alt="The Traversal Course showcase: a wide side-on level with a ground strip, a purple tower on the left with a yellow climber hanging from its lip, a low brown block, two tall grey shaft walls with a red jumper above them, a tall yellow ladder volume beside a grey platform, and a blue pool on the right holding a light-blue diver with a grey stone resting on the ground beside it. A readout along the bottom reads climber hanging: true, jumper wall sliding: false, diver in water: true, depth: 186." width="640">

Attach a **TraversalKit** behavior under a CharacterBody2D that already has a mover and a
CollisionShape2D. Set Probe Mask to the layer your solid level geometry uses. For ladders, add an Area2D
covering the ladder and put it in the `ladder` group; for water, an Area2D covering the pool in the
`water` group.

A ledge grab and a mantle, on top of Platformer movement:

```
Player | Platformer  (your usual run and jump)
Player | TraversalKit  (Probe Mask = your solid layer)

Every tick
  Condition: Player | TraversalKit  Is At A Ledge
  Condition: Player | Platformer  Is Falling
    -> Player | TraversalKit: Grab Ledge

On up pressed
  Condition: Player | TraversalKit  Is Hanging
    -> Player | TraversalKit: Climb Up  0.35
```

## ACE reference

On the canvas these rows read as styled sentences - parameter values in **bold**, node references in *italic*, exactly as the rows draw them:

- **Grab** the ledge
- **Climb up** over **0.35** s
- **Wall jump** away (push **300**, up **500**)
- **Swim** (gravity **20**%, drag **10**%)

### Actions

| Action | Parameters | Description |
|--------|-----------|-------------|
| Grab Ledge | (none) | Grabs the ledge in front: the host stops dead, holds the lip (a little below it, by Hang Offset) and fires On Ledge Grabbed. Ignored if it is already hanging. |
| Climb Up | duration (0.0) | Leaves the ledge upward. With no duration it lets go and jumps at Climb Jump Velocity - the quick platformer exit. With a duration it is a mantle: the host is carried up and over the lip in that many seconds with nothing else able to move it, and On Climbed fires when it lands on top. |
| Drop | (none) | Lets go of the ledge and falls. The kit ignores the same lip for Regrab Delay seconds afterwards. |
| Slide Down Wall | speed (60.0) | Caps the fall while the host is pressed against a wall, so it slides instead of dropping. Does nothing when it is not on a wall or is still moving upward. |
| Wall Jump | push (300.0), rise (500.0) | Jumps AWAY from the wall: the push goes along the wall's own normal, so the host always leaves the wall it was on, whichever side that was. |
| Wall Run | gravity_percent (20.0), min_speed (120.0) | Runs along the wall: gravity is replaced by the percentage you give, so the host barely sinks while it keeps up speed. It needs to be on a wall, off the floor, and moving at least min_speed - and it gives out after Wall Run Max Time. |
| Climb Ladder | speed (120.0) | Drives the host up or down the ladder at this speed, from the up/down controls (or the AI axis). It writes the vertical speed outright, so gravity is off for as long as you keep calling it. |
| Vault Over | duration (0.4) | Carries the host forward over the obstacle in this many seconds. Nothing else moves it while the vault runs, and On Vaulted fires on the far side. |
| Crouch | (none) | Crouches: the host's first collision shape is swapped for a copy scaled to Crouch Scale, kept standing on the same feet. The original is put back by Stand, so the shape in your scene is never edited. |
| Stand | (none) | Stands back up and puts the original collision shape back exactly as it was. |
| Swim | gravity_percent (20.0), drag (10.0) | Swimming instead of falling: only this percentage of the kit's gravity still pulls, and the host sheds this percentage of its speed every physics frame (10 is the classic 0.9 damping). Call it every tick while in water. |

### Conditions

| Condition | Parameters | Description |
|-----------|-----------|-------------|
| Is At A Ledge | (none) | True when the forward probe finds a wall at chest height and the higher probe finds nothing - a lip you could hang from. False while already hanging, and for a moment after a Drop. |
| Is Hanging | (none) | True while the host is hanging from a ledge it grabbed. The kit holds it exactly where it grabbed - gravity cannot pull it off. |
| Is Wall Sliding | (none) | True on the frames a Slide Down Wall actually slowed a fall. |
| Is Wall Running | (none) | True on the frames a Wall Run is carrying the host along a wall (it stops on its own after Wall Run Max Time). |
| Is On Ladder | (none) | True while the host is standing inside an Area2D marked with the ladder group. |
| Is At A Vaultable Obstacle | (none) | True when the forward probe finds something at knee height and nothing at chest height - a low obstacle you could throw yourself over. |
| Is Crouching | (none) | True while the host is crouched (its collider is the short one). |
| Is In Water | (none) | True while the host is inside an Area2D marked with the water group. |
| Is Above The Surface | (none) | True when the host's own point is above the water line of the area it is in - the test that lets a swimmer breathe, jump out, or hold a boat at the top. Always true out of water. |

### Expressions

| Expression | Returns | Description |
|-----------|---------|-------------|
| Water Depth | float | How far below the water line the host is, in pixels (0 out of water or at the surface). |

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
| Probe Distance | 20.0 | How far ahead the kit looks for a wall, in pixels. |
| Wall Probe Height | 18.0 | Height above the feet where the forward probe must FIND a wall, in pixels. |
| Grab Height | 34.0 | Height above the feet where the second probe must find NOTHING - the gap over the lip that makes a wall a ledge. |
| Hang Offset | 6.0 | How far below the lip the hands hold once grabbed, in pixels. |
| Climb Jump Velocity | -420.0 | Upward velocity when Climb Up is called with no duration - the let-go-and-jump exit (negative is up). |
| Climb Forward | 26.0 | How far forward a timed climb (a mantle) carries the body, in pixels. |
| Climb Rise | 40.0 | How far up a timed climb carries the body, in pixels. |
| Regrab Delay | 0.3 | How long after a Drop the kit refuses to see a ledge again, in seconds. |
| Probe Mask | layer 1 | Which physics layers the ledge, wall and vault probes can see. |
| Wall Run Max Time | 1.2 | Longest a single wall run may last, in seconds. |
| Gravity | 980.0 | Downward pull the kit uses for its own vertical moves (wall running, swimming), in pixels per second squared. |
| Ladder Group | `ladder` | Objects in this group count as ladders - mark a ladder Area2D with it. |
| Vault Probe Height | 6.0 | Height above the feet where the vault probe must FIND the obstacle (knee height), in pixels. |
| Vault Clear Height | 34.0 | Height above the feet that must be CLEAR for the obstacle to be vaultable (chest height), in pixels. |
| Vault Distance | 52.0 | How far forward Vault Over carries the body, in pixels. |
| Crouch Scale | 0.5 | How much of its height the collider keeps while crouched (0.1 to 1.0). |
| Water Group | `water` | Objects in this group count as water - mark a water Area2D with it. |
| AI Controlled | off | AI drive: the kit reads the held `ai_climb_axis` intent instead of the up/down controls, so a sheet or an AI driver steers the climb exactly the way a player's keys would. |

### Inspector properties are ACEs too

Every property this pack exposes in the Inspector is also reachable from the picker, generated for you:
an expression named after the property reads it, a **Set ...** action writes it, and for number properties
**Add To ...** and **Subtract From ...** adjust it by an amount. They sit in the pack's own category
alongside the vocabulary above, so any knob you can set in the Inspector is also something a sheet can read and
change while the game runs - a wall-run upgrade is a **Set Wall Run Max Time** row, not a new behavior.

## Reading it from expressions - the Self section

Type `self` in any ƒx field, or open the ƒx **Expressions dictionary**, and **Self ▸ Behaviours**
lists this pack's knobs and value expressions as ready-to-insert chains once the behaviour is attached:

- `$TraversalKit.water_depth()` inserts the **Water Depth** entry straight into any expression
- `$TraversalKit.vault_distance` inserts the **Vault Distance** knob straight into any expression

The `$TraversalKit` token stays selected after insert, so retargeting to your child's actual name is one
keystroke, or a node drag. Attaching this behaviour at runtime instead? Tick **Robust behaviour
lookups** in the dictionary and the same entries insert as `get_node_or_null("TraversalKit")` chains,
which survive auto-named children.

## Use cases

**1. Grab a ledge automatically while falling.** The classic assist: reach for any lip you fall past.

```
Every tick
  Condition: Player | TraversalKit  Is At A Ledge
  Condition: Player | Platformer  Is Falling
    -> Player | TraversalKit: Grab Ledge
```

**2. Mantle up with a real animation window.** A duration turns the climb into a scripted move nothing
else can interrupt, which is exactly as long as your climb animation.

```
On up pressed
  Condition: Player | TraversalKit  Is Hanging
    -> Player: play "mantle" animation
    -> Player | TraversalKit: Climb Up  0.35
```

**3. Let go with down, without re-grabbing.** Regrab Delay is what stops the lip catching you again.

```
On down pressed
  Condition: Player | TraversalKit  Is Hanging
    -> Player | TraversalKit: Drop
```

**4. Hang idle animation.** Is Hanging is a plain state you can drive art from.

```
Every tick
  Condition: Player | TraversalKit  Is Hanging
    -> Player: play "hang" animation
```

**5. Wall slide to slow a fall.** Call it every tick and it only bites when the body is actually on a
wall and falling.

```
Every tick
  -> Player | TraversalKit: Slide Down Wall  60
Every tick
  Condition: Player | TraversalKit  Is Wall Sliding
    -> spawn dust at the Player's feet
```

**6. Wall jump that always leaves the wall.** The push follows the wall's own normal, so one row covers
both sides of a shaft.

```
On jump pressed
  Condition: Player | TraversalKit  Is Wall Sliding
    -> Player | TraversalKit: Wall Jump  300, 500
    -> play a kick-off sound
```

**7. Wall run while sprinting.** It needs speed, a wall and air, and it gives out on its own.

```
Every tick
  Condition: sprint is held
    -> Player | TraversalKit: Wall Run  20, 120
```

**8. Ladders that need no wiring.** Put every ladder Area2D in the `ladder` group and this one event
covers the whole level.

```
Every tick
  Condition: Player | TraversalKit  Is On Ladder
    -> Player | TraversalKit: Climb Ladder  120
    -> Player: play "climb" animation
```

**9. Vault over a crate.** The kit tells you when a vault is even possible.

```
On jump pressed
  Condition: Player | TraversalKit  Is At A Vaultable Obstacle
    -> Player | TraversalKit: Vault Over  0.4
```

**10. Crouch to fit through a gap.** The collider shrinks to Crouch Scale and Stand puts the original
back untouched.

```
On crouch pressed
  -> Player | TraversalKit: Crouch
On crouch released
  -> Player | TraversalKit: Stand
```

**11. Refuse to stand under a low ceiling.** Gate Stand on your own headroom check so the player is not
pushed into the ceiling.

```
On crouch released
  Condition: no ceiling above the Player
    -> Player | TraversalKit: Stand
```

**12. Swim instead of sink.** Swim replaces the fall with a slow drift plus drag, every tick while in
water.

```
Every tick
  Condition: Player | TraversalKit  Is In Water
    -> Player | TraversalKit: Swim  20, 10
```

**13. A breath meter that only refills at the surface.** Compose the shipped **Drain Meter** and
**Fill Meter** system actions - the kit supplies the two tests, the meters supply the arithmetic.

```
Every tick
  Condition: Player | TraversalKit  Is In Water
  Condition: Player | TraversalKit  Is Above The Surface  (inverted)
    -> Drain Meter  breath  by 12 per second, floor 0
Every tick
  Condition: Player | TraversalKit  Is Above The Surface
    -> Fill Meter  breath  by 30 per second, cap 100
```

**14. Depth effects that scale with how deep you are.** Water Depth is a number, so darkening and muffling
are one expression each.

```
Every tick
  Condition: Player | TraversalKit  Is In Water
    -> set WaterTint alpha to Player | TraversalKit.Water Depth() / 400
    -> set the underwater bus wet level from the same value
```

**15. A splash on the way in and out.** Both edges are triggers, so no polling.

```
Player On Entered Water
  -> spawn a splash at the Player
  -> play a splash sound
Player On Left Water
  -> spawn a smaller splash
```

**16. Chain a mantle into the next move.** On Climbed fires when the body lands on top, which is the
moment to hand control back to your mover.

```
Player On Climbed
  -> Player: play "land" animation
  -> allow input again
```

### Other use cases

**Ledge-hang stealth.** Hold a hang while a patrol walks over the lip, then Climb Up once the guard's cone has passed - Is Hanging is a state your alert system can read directly.

**Ability gating.** Ship the kit attached and put a sheet variable in front of each verb, so a wall jump or a vault only becomes possible after the upgrade that grants it.

**Traversal tutorials.** Light up an on-screen prompt only when Is At A Ledge or Is At A Vaultable Obstacle is true, teaching the move at exactly the spot where it works.

**Enemy climbers.** Give a pursuer the same behavior with AI Controlled on and drive `ai_climb_axis` from its logic, so it follows the player up ladders under the same rules.

**Underwater puzzle rooms.** Combine Water Depth with a pressure meter so deep rooms cost breath faster, and make Is Above The Surface the only place a checkpoint refills it.

## Tips and common mistakes

- **Nothing here moves the body by itself.** The kit writes velocity; your mover applies it. If a wall
  jump seems to do nothing, check that a Platformer behavior (or your own movement) is still running on
  the same node.
- **Call the every-tick verbs every tick.** Swim, Wall Run, Slide Down Wall and Climb Ladder each affect
  exactly the frame you call them on. One-shot calls do nothing visible.
- **Set Probe Mask to your solid layer.** With the wrong layer the ledge probes never hit and
  Is At A Ledge is permanently false - which looks identical to a broken behavior.
- **Grab Height must clear the lip.** If Grab Height is too low, the second probe hits the same wall and
  no ledge is ever detected; if it is far too high, ordinary walls read as ledges.
- **The speeds live on the rows, not in the Inspector.** Slide Down Wall, Wall Jump, Wall Run and
  Climb Ladder each carry their own numbers, so two objects can share one kit and still feel different -
  and a row you can read beats a knob you have to go and look up.
- **Ladders and water are groups.** An Area2D that is not in the `ladder` / `water` group is invisible to
  the kit, and so is one with monitoring turned off.
- **Water needs a collision shape to have a surface.** The water line is read off the area's first
  CollisionShape2D; without one, Is Above The Surface and Water Depth fall back to the area's origin.
- **Crouch touches the first CollisionShape2D it finds.** If your host has several, put the body's own
  shape first, and never edit that shape while crouched - Stand puts the original back verbatim.
- **A timed climb or vault owns the body.** While one runs, velocity is zeroed and your mover cannot
  steer; keep the durations short (0.3 to 0.5 s) unless the animation really is that long.
- **Negative is up in 2D.** Climb Jump Velocity is negative for that reason, while Wall Jump's rise is
  given as a positive number the kit turns into the rise for you.
