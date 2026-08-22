# Skateboard 3D - Surface-Aligned Rolling, Lip Launches and Path3D Grinds

Attach `Skateboard3DMovement` under a CharacterBody3D and you get the 2D pack's words on a
surface instead of a floor. **Push** nudges you toward the top speed along the way the board
faces. **Roll With The Slope** projects gravity onto the surface normal, so bowls and
quarterpipes work without a curve anywhere in your sheet. **Align The Board To The Surface**
keeps it flat on ramps. And leaving a near-vertical transition is announced as its own moment -
**On Launched Off The Lip** - so a halfpipe lip is a thing a sheet can answer rather than a
number nobody can name.

Landings are judged in 3D by the board's own up-vector against the surface normal: within the
tolerance and you get **On Landed Clean**, outside it and you get **On Bailed**.

![The Skate Park 3D showcase seen from a low angle: a tilted blue-grey slab on the left with a small orange board resting on it, a flat run in the middle crossed by a pale blue rail line, a steep dark bank standing up at the right end, and a score line reading "Score 0 chain 0 x1" across the top](../images/skate-park-3d.png)

The bundled **Skate Park 3D** showcase (`demo/showcase/skate_park_3d/`) is the reference setup.

## What this pack deliberately does not own

This is the item in the batch where the earlier work pays off together, so the pack is small on
purpose and composes with what already ships:

- **The trick inputs** are combos. Register `"kickflip"` on a Combo Box behaviour and the trick
  is an **On Combo Matched** event guarded by **Is Airborne** - no input state machine here.
- **The animation** is an animation tree. **Travel To State** on the AnimationTree takes the
  trick name straight from the combo, so adding a trick is adding a combo and a state.
- **The wipeout** is the physics rows. **On Bailed** is where a ragdoll, an impulse, or a stumble
  animation hangs. This pack fires the moment and stops.
- **The camera** is an orbit. Put an Orbit 3D behaviour on a camera rig parented behind the
  skater and it follows without a line of code here.
- **The respawn** is a checkpoint. **On Bailed** into **Respawn At Checkpoint** is the whole
  recovery loop.

## Momentum movement and grinding in three dimensions

A board still has no target speed - see the 2D guide for the long version of why that matters.
What changes in 3D is the *direction* of everything:

- **Push** goes the way the board faces, flattened onto the horizontal plane, rather than along a
  single axis. Turn the board and the next push goes somewhere else.
- **Roll With The Slope** takes the floor normal and removes the part of gravity that points into
  the surface, leaving the part that runs along it. On a flat floor that is nothing; on a bowl
  wall it is most of gravity; and the transition between them is what makes a bowl carve.
- **Align The Board To The Surface** swings the board's up onto the surface normal at
  `align_speed`, keeping the way it was facing. Off the ground it settles back level, so a drop
  lands on its wheels rather than wearing the shape of the last ramp.
- **The lip.** Leaving a surface steeper than `lip_angle_degrees` is a launch, not a fall off a
  kerb: the board keeps the velocity the transition built, squares itself to the lip it left,
  resets the spin count, and fires **On Launched Off The Lip**. `lip_boost` adds a little extra
  upward speed on top if you want the arcade version; leave it at 0 for honest physics.

Grinding is the same three questions as in 2D, on a `Curve3D`: where on this curve am I closest
to (**Is Near Rail**), lock me to it (**Start Grinding**), walk me along it (**Grind Along Rail**).
The direction is chosen from which way along the curve your velocity was already pointing, so
approaching a rail from either end works. **Keep Momentum** rides at the speed you arrived with,
and **Ride Zipline** lets the line's own slope drive it.

## Where this pack shines

- **Skate parks in 3D.** Bowls, quarterpipes, a rail through the middle, and a line the player
  invents themselves.
- **Anything that rides a surface.** Snowboarding, hoverboards, a wingsuit landing run - the
  surface-aligned model is the same.
- **Ziplines in a game with no skating in it.** The Grind 3D rows work on any CharacterBody3D.

## Setup

1. Attach `Skateboard3DMovement` as a child of your CharacterBody3D.
2. Call **Roll With The Slope** and **Align The Board To The Surface** every physics tick.
3. Bind a key to **Push** and one to **Ollie**.
4. Draw your rails as ordinary Path3D nodes. The pickers list them.

```
Every tick (physics)
  Condition: Skater | Platform: Is on floor
    -> Skater | Skateboard 3D: Roll with the slope
    -> Skater | Skateboard 3D: Align the board to the surface
On push pressed -> Skater | Skateboard 3D: Push toward max speed by 2
On jump pressed -> Skater | Skateboard 3D: Ollie at 6
```

## ACE reference

On the canvas these rows read as styled sentences - parameter values in **bold**, node references
in *italic*, exactly as the rows draw them:

- Push toward **max speed** by **2**
- Roll with the slope *gravity along the surface*
- Align the board to the **surface**
- Is near rail *Rail* within **0.6**

| Kind | Name | Parameters | Description |
|---|---|---|---|
| Action | Push | `amount` (float) | One kick toward the top speed, along the way the board faces. |
| Action | Roll With The Slope | - | Projects gravity onto the surface normal. Call it every physics tick on the ground. |
| Action | Align The Board To The Surface | - | Swings the board flat onto what it is standing on, at the align speed. |
| Action | Ollie | `strength` (float) | Pops off the ground, resets the spin count, fires On Ollie. |
| Action | Manual | - | Rides the back wheels and starts the balance meter. |
| Action | Stop The Manual | - | Back on all four wheels, balance meter off. |
| Action | Brake | `amount` (float) | Drags ground speed toward a standstill. |
| Action | Reverse | - | Turns the board around and rolls back at the same speed. |
| Action | Spin Trick | `turns` (float) | Turns the board about its own up - the shove-it half. |
| Action | Flip Trick | `turns` (float) | Rolls the board about its own length - the kickflip half. |
| Action | Land The Trick | - | Judges the landing now: clean if within the tolerance, otherwise a bail. |
| Action | Bail | - | Stops everything, drops the chain, fires On Bailed. |
| Action | Add To Chain | `trick` (String), `points` (float) | Scores a trick at the current multiplier, then raises the multiplier. |
| Action | Bank Chain | - | Moves the chain into the banked total, multiplier back to one. |
| Action | Drop Chain | - | Throws the chain away, multiplier back to one. |
| Action | Start Balancing | `drift` (float) | Balance to dead centre, drifting at that speed per second. |
| Action | Steer The Balance | `amount` (float) | Pushes balance back toward the middle. |
| Condition | Is Rolling | - | On the ground and moving. |
| Condition | Is Airborne | - | Off the ground and not on a rail - the window every trick lives in. |
| Condition | Is In A Manual | - | Riding the back wheels. |
| Condition | Is Losing Balance | - | Balance is past the warning mark. |
| Expression | Balance | - | -1 to 1, with 0 dead centre. |
| Expression | Chain Score | - | What the running chain is worth. |
| Expression | Multiplier | - | What the next trick will be multiplied by. |
| Expression | Banked Score | - | Everything banked this run. |
| Expression | Spin Turns | - | Whole turns since leaving the ground. |
| Expression | Surface Normal | - | The way the surface under the board faces, or the last one while airborne. |
| Trigger | On Ollie | - | The ollie left the ground. |
| Trigger | On Launched Off The Lip | - | Left a surface steeper than the lip angle, carrying the transition's speed. |
| Trigger | On Landed Clean | - | Touched down with the board's up within the tolerance of the surface normal. |
| Trigger | On Bailed | - | Crooked landing, lost balance, or Bail was called. |
| Trigger | On Trick Done | `trick`, `points` | A trick was added to the chain, with what it scored. |

### The Grind 3D rows

| Kind | Name | Parameters | Description |
|---|---|---|---|
| Condition | Is Near Rail | `rail` (Node3D), `distance` (float) | Within that distance of the nearest point on the rail's curve. |
| Condition | Is Grinding | - | Locked to a rail and riding it. |
| Condition | Has Reached The End | - | The ride ran off either end of the curve. |
| Action | Start Grinding | `rail` (Node3D) | Locks onto the rail at the nearest point, in whichever direction you were going. |
| Action | Grind Along Rail | `speed` (float), `keep_momentum` (bool) | Rides one tick further along the curve. |
| Action | Hop Off | `hop` (float) | Lets the rail go with an upward kick, keeping the grind's speed. |
| Action | Ride Zipline | `rail` (Node3D) | The same lock-on, with the line's slope driving the speed. |

### Inspector properties

| Property | Default | What it does |
|---|---|---|
| `push_speed` | `2.0` | How much one push adds toward the top speed (m/s). |
| `max_speed` | `18.0` | The fastest a push will take you. A slope can carry you past it. |
| `ollie_speed` | `6.0` | Upward speed an ollie gives you. |
| `gravity` | `24.0` | Downward acceleration. Roll With The Slope projects this onto the surface. |
| `max_fall_speed` | `40.0` | Terminal velocity. |
| `friction` | `1.4` | Rolling friction on the ground. |
| `slope_grip` | `1.0` | How much of gravity the surface hands you. |
| `align_speed` | `12.0` | How quickly the board swings flat onto the surface. Lower reads as suspension. |
| `lip_angle_degrees` | `55.0` | How steep a surface must be for leaving it to count as a lip launch. |
| `lip_boost` | `0.0` | Extra upward speed a lip launch adds. 0 is honest physics. |
| `trick_spin_rate` | `1.0` | Default turns per second for a spin or a flip. |
| `landing_tolerance_degrees` | `25.0` | How far the board's up may be off the surface normal and still land. |
| `grind_speed` | `10.0` | Default speed along a rail. |
| `rail_snap_distance` | `0.6` | How close to the rail counts as near it. |
| `hop_off_speed` | `4.5` | Upward speed a hop off a rail gives you. |
| `balance_drift` | `0.8` | How fast balance slides toward the edge per second. |
| `balance_steer` | `1.6` | How hard a full steer pushes it back. |
| `balance_warn` | `0.6` | How far out before Is Losing Balance says yes. |

### Inspector properties are ACEs too

Every property this pack exposes in the Inspector is also reachable from the picker, generated for
you: an expression named after the property reads it, a **Set ...** action writes it, and for
number properties **Add To ...** and **Subtract From ...** adjust it by an amount. They sit in the
pack's own category alongside the vocabulary above.

## Reading it from expressions - the Self section

Type `self` in any ƒx field, or open the ƒx **Expressions dictionary**, and **Self ▸ Behaviours**
lists this pack's knobs and value expressions as ready-to-insert chains once the behaviour is
attached:

- `$Skateboard3DMovement.surface_normal()` inserts the **Surface Normal** entry, which is what an
  align-to-the-ground row wants
- `$Skateboard3DMovement.chain_score()` inserts the **Chain Score** entry
- `$Skateboard3DMovement.lip_angle_degrees` inserts the **Lip Angle Degrees** knob

## Use cases

### 1. A skater you can drive around a park

Two rows in a tick and two keys. Everything else in this guide is decoration on top of this.

```
Every tick (physics)
  Condition: Skater | Platform: Is on floor
    -> Skater | Skateboard 3D: Roll with the slope
    -> Skater | Skateboard 3D: Align the board to the surface
On push pressed -> Skater | Skateboard 3D: Push toward max speed by 2
```

### 2. The bowl that carves itself

There is no bowl code. Build the mesh, give it a collision shape, and the surface normal does the
rest - the deeper the wall, the more of gravity is along it.

```
Every tick (physics)
  Condition: Skater | Platform: Is on floor
    -> Skater | Skateboard 3D: Roll with the slope
```

### 3. The lip, announced

The moment a player has been waiting for is a trigger rather than a guess about velocity signs.

```
On Launched Off The Lip -> Juice 3D: Chromatic Kick  0.3, 0.2
                        -> Camera: Set FOV  78
On Landed Clean         -> Camera: Set FOV  70
```

### 4. Tricks as combos, not as an input state machine

Register the combos on a Combo Box behaviour once, then every trick is one event guarded by
Is Airborne. Adding a trick is adding a combo, not adding a branch.

```
On Ready -> Skater | ComboBox: Register Combo  "kickflip", "left,jump", 0.4
Skater | ComboBox: On Combo Matched
  Condition: Skater | Skateboard 3D: Is airborne
    -> AnimTree: Travel to animation state  "kickflip"
    -> Skater | Skateboard 3D: Flip 2 turn per second
```

### 5. The animation tree drives itself off the trick name

The combo id and the state name are the same string, so a table of tricks is a table of strings
and nothing else has to change.

```
Skater | ComboBox: On Combo Matched
  -> AnimTree: Travel to animation state  ComboBox.Last Combo
```

### 6. Landing decided by the board, not by the timer

The pack compares the board's up against the surface normal on touchdown. Narrow the tolerance
for a sim, widen it for an arcade game.

```
On Landed Clean -> Skater | Skateboard 3D: Bank the chain
On Bailed       -> AnimTree: Travel to animation state  "wipeout"
```

### 7. Bail into a ragdoll

The pack fires the moment and owns nothing else, so the wipeout is whatever the physics rows in
your project already do to a body.

```
On Bailed -> Ragdoll: Set Freeze  false
          -> Ragdoll: Apply Impulse  Skater.velocity * 0.5
```

### 8. Bail into a checkpoint respawn

The other half of the same trigger: the run is over, put them back at the last gate.

```
On Bailed -> Fade: Fade Out  0.25
          -> Skater | Checkpoint: Respawn at the checkpoint
          -> Fade: Fade In   0.35
```

### 9. The orbit camera behind the skater

An Orbit 3D behaviour on a camera rig parented to the skater is the whole camera. Retarget its
centre and the camera swings without a follow script.

```
On Ready -> CameraRig | Orbit 3D: Set Orbit 3D Center  Skater.position.x, Skater.position.y, Skater.position.z
```

### 10. Rails on a Path3D

Draw the rail as an ordinary Path3D. Falling near it starts the grind; the end of the curve or
the jump button ends it.

```
Every tick (physics)
  ✕ Skater | Grind 3D: Is grinding
  Condition: Skater | Platform: Is falling
  Condition: Skater | Grind 3D: Is near rail  Rail, 0.6
    -> Skater | Grind 3D: Start grinding  Rail
Every tick (physics)
  Condition: Skater | Grind 3D: Is grinding
    -> Skater | Grind 3D: Grind along the rail at 10
```

### 11. Balance on the rail

Start Grinding starts the balance meter for you, so a long rail already has tension. All the
sheet adds is the steer.

```
Every tick (physics)
  Condition: Skater | Grind 3D: Is grinding
    -> Skater | Skateboard 3D: Steer the balance by  Keyboard.Axis("ui_left", "ui_right")
```

### 12. Hop off at the end, into the next trick

Because the chain is not banked, hopping off a rail straight into a spin keeps the multiplier
climbing.

```
Skater | Grind 3D: Has reached the end
  -> Skater | Skateboard 3D: Add trick "rail" to the chain for 300
  -> Skater | Grind 3D: Hop off the rail at 4.5
```

### 13. A zipline across the map

Same rows, different feel: the line's slope drives the speed. Useful in a game with no board in
it at all.

```
On grab pressed
  Condition: Player | Grind 3D: Is near rail  Zipline, 1.5
    -> Player | Grind 3D: Ride the zipline  Zipline
```

### 14. A HUD that reads the run

Chain, multiplier and balance are all plain expressions, so the HUD is three rows and no
bookkeeping.

```
Every tick
  -> HUD Kit: Set Label   "Chain", Skater.Chain Score & " x" & Skater.Multiplier
  -> HUD Kit: Set needle  "BalanceMeter", Skater.Balance, 0.6
  -> HUD Kit: Set Label   "Total", Skater.Banked Score
```

Balance has a middle, so it wants a needle rather than a bar: **Set Needle** builds one inside any
empty Control and turns it the warning colour past the mark you name.

### 15. A snowboard, a hoverboard, a surfboard

The surface-aligned model is not about wheels. Swap the mesh, raise `friction` for snow or lower
it for ice, and the same rows are a different sport.

```
On Ready -> Rider | Skateboard 3D: Set Friction  0.4
         -> Rider | Skateboard 3D: Set Slope Grip  1.3
```

### 16. A downhill course with no tricks at all

Turn the trick rows off entirely. Push, Roll With The Slope, Brake and the surface is a gravity
racer where the whole skill is the line you take.

```
On brake down -> Rider | Skateboard 3D: Brake by 6
```

### 17. Line scoring for a park challenge

Give the player a target and let the pack count. Nothing is banked until they touch down clean,
so a greedy line is a real risk.

```
On Landed Clean
  Condition: Skater.Chain Score >= 5000
    -> Milestones: Reach  "big_line"
```

### 18. Slow motion on the biggest air

Spin Turns counts whole turns since leaving the ground, so the game can notice a big one while it
is still happening.

```
Every tick (physics)
  Condition: Skater | Skateboard 3D: Is airborne
  Condition: Skater.Spin Turns >= 1.5
    -> System: Set Time Scale  0.45
On Landed Clean -> System: Set Time Scale  1
```

### Other use cases

**A snow park.** Lower the friction, raise the lip angle so only the true kickers count as launches, and the same pack is a snowboarding game with different art and one changed knob.

**Cargo on a cable.** Ride Zipline with a crate as the host moves freight along a drawn Path3D under its own weight, with no tween, no waypoints and no animation to keep in sync with the level.

**A parkour traversal layer.** Use only Is Near Rail, Start Grinding and Hop Off on a first-person character and rails become balance beams and wires in a game that never mentions skating.

**A physics-lite vehicle.** A hoverbike that rolls with the surface and launches off ridges gets its whole feel from Roll With The Slope and the lip trigger, without a RigidBody or a suspension model.

**A replay-worthy stunt mode.** On Launched Off The Lip and On Landed Clean bracket exactly the window a replay camera wants, so recording the good bit is two triggers rather than a heuristic on velocity.

## Tips and common mistakes

- **Call both tick rows.** Roll With The Slope gives you the speed; Align The Board To The
  Surface gives you the look. Skipping the second one leaves the board level on a vertical wall
  and every landing reads as crooked.
- **The lip angle is a design knob, not a constant.** At 55 degrees a steep bank counts as a lip.
  Raise it and only true transitions do; lower it and dropping off a kerb starts announcing
  itself.
- **`lip_boost` at 0 is the honest setting.** The transition already gave the board its speed. The
  boost is there for arcade feel, not for correctness.
- **A grind suspends gravity.** While Is Grinding is true the pack does not fall you, brake you,
  or judge a landing.
- **Rails are ordinary Path3D nodes.** A curve with two or more points is a rail. No script, no
  group, no marker.
- **The trick inputs are not in this pack.** That is on purpose - a combo pack already turns an
  input sequence into one named event, and duplicating it here would give you two places to change
  a control scheme.
- **Balance drifts away from the middle.** Set `balance_drift` to 0 while you are building the
  level, then turn it up when you want the tension back.
