# Skateboard - Momentum, Ramps, Tricks and Grinds in 2D

Attach `SkateboardMovement` under a CharacterBody2D and the host stops behaving like a runner and
starts behaving like a board. **Push** nudges you toward the top speed and you *keep* it. **Roll
With The Slope** projects gravity along the floor you are standing on, which is the single line
that makes ramps, bowls and halfpipes work. **Ollie** leaves the ground, **Spin Trick** and **Flip
Trick** turn in the air, and touching down is judged: square enough with the floor and you get
**On Landed Clean**, crooked and you get **On Bailed**.

The rail words live here too, under their own **Grind** section: **Is Near Rail**, **Start
Grinding**, **Grind Along Rail**, **Has Reached The End**, **Hop Off** and **Ride Zipline**. They
are a general snap-to-a-curve-and-ride shape - a rail, a zipline, a monorail - so a traversal pack
adopts these rows rather than spelling them a second time.

## Momentum movement, and why a board is not a runner

This is the part worth reading before the row list, because everything else follows from it.

A platformer controller accelerates toward a top speed every tick while you hold a direction, and
decelerates the moment you let go. That is the right model for legs: a runner has a speed they
want to be at, and they spend energy staying there. It is the wrong model for a board, and the
reason a skating game built on a run-and-jump controller always feels like it is fighting you.

A board has no target speed. It has *whatever it has*, and four things change it:

- **A push** adds a fixed amount, once. Pushing twice is twice the gain. Holding the button is
  worth nothing, which is why **Push** is a trigger row, not a held one.
- **The slope** adds or removes speed continuously, and it is the only continuous source. **Roll
  With The Slope** takes the floor normal under you and projects gravity along the surface, so a
  down-ramp is free speed and an up-ramp is a tax. Called every physics tick on the floor, that
  one row gives you pumping, bowl carving, and a halfpipe that actually returns you to the coping
  without anyone writing a curve.
- **Friction** removes a little, slowly. The default is low on purpose - a board coasts.
- **A brake** removes a lot, on demand.

Nothing else touches your speed, and in particular *the air does not*. Leaving the ground keeps
your horizontal speed exactly as it was, which is what makes a gap either clear or not clear at
the moment you left the lip rather than something you can save by steering.

### Grinding, which is a different verb from riding

A grind is not movement, it is an **attachment**. The board stops being a body that falls and
becomes a point on a curve.

The whole of it is three questions. Where on this curve am I closest to? That is
`get_closest_offset` on the rail's `Curve2D`, and **Is Near Rail** is that answer compared against
a distance. Am I locked to it? **Start Grinding** remembers the rail and the offset. How far along
am I now? **Grind Along Rail** walks the offset forward by a speed times delta and puts the board
on the point the curve bakes there, facing the way the rail runs.

Two knobs make it feel different. **Keep Momentum** rides at whatever speed you arrived with
instead of the grind speed, so a fast approach is a fast grind and a scared one is a slow one.
And **Ride Zipline** is the same lock-on with the line's own slope driving the speed, so a steep
run accelerates and a level one coasts.

While a grind is running, the pack's own tick stands down: gravity, friction and the touchdown
test are all suspended, because the rail owns the position outright. **Hop Off** hands the board
back with an upward kick and whatever speed the grind had built along the line, which is why a
rail is a launcher as much as a scoring line.

![The Skate Park showcase: a dark blue slope descending from the top left onto a flat, a pale blue rail line across the middle of it, a quarterpipe curving up at the right edge, an orange board part-way down the slope, a score line reading "Score 0 chain 0 x1" across the top, and under it the balance meter as a dark bar with a pale blue needle near its centre](../images/skate-park.png)

The bundled **Skate Park** showcase (`demo/showcase/skate_park/`) is the reference setup: every row
in its sheet is one of the rows below, and there is no skating math in it anywhere.

## Where this pack shines

- **Skate parks.** Ramps, quarterpipes, a rail across the middle and a bowl at the end - four
  rows and the level is the design.
- **Anything on a board or a bike.** Snowboarding, downhill, a shopping trolley: momentum plus
  timing is the same model whatever is under the player.
- **The grind words on their own.** Ziplines and monorails in a game with no skating in it are
  the same six rows.

## Setup

1. Attach `SkateboardMovement` as a child of your CharacterBody2D.
2. In the sheet, call **Roll With The Slope** every physics tick while on the floor.
3. Bind a key to **Push** and one to **Ollie**. That is a playable skater.
4. Draw your rails as ordinary Path2D nodes in the layout. The pickers list them.

```
Every tick (physics)
  Condition: Player | Platform: Is on floor
    -> Player | Skateboard: Roll with the slope
On push pressed  -> Player | Skateboard: Push toward max speed by 40
On jump pressed  -> Player | Skateboard: Ollie at 420
```

## ACE reference

On the canvas these rows read as styled sentences - parameter values in **bold**, node references
in *italic*, exactly as the rows draw them:

- Push toward **max speed** by **40**
- Roll with the slope *gravity along the floor*
- **Ollie** at **420**
- Is near rail *Rail* within **12** px
- **Grind** along the rail at **320**

| Kind | Name | Parameters | Description |
|---|---|---|---|
| Action | Push | `amount` (float) | One kick toward the top speed, in the direction you are already going. The board keeps it. |
| Action | Roll With The Slope | - | Projects gravity along the floor normal. Call it every physics tick on the ground. |
| Action | Ollie | `strength` (float) | Pops off the ground, resets the spin count, fires On Ollie. |
| Action | Manual | - | Rides the back wheels and starts the balance meter. |
| Action | Stop The Manual | - | Back on all four wheels, balance meter off. |
| Action | Brake | `amount` (float) | Drags speed toward a standstill. |
| Action | Reverse | - | Turns around and rolls back at the same speed. |
| Action | Spin Trick | `turns` (float) | Turns the board in the air at turns per second and counts the turns. |
| Action | Flip Trick | `turns` (float) | The same turn the other way, so the chain can tell them apart. |
| Action | Land The Trick | - | Judges the landing now: clean if within the tolerance, otherwise a bail. |
| Action | Bail | - | Stops everything, drops the chain, fires On Bailed. |
| Action | Add To Chain | `trick` (String), `points` (float) | Scores a trick at the current multiplier, then raises the multiplier. |
| Action | Bank Chain | - | Moves the chain into the banked total, multiplier back to one. |
| Action | Drop Chain | - | Throws the chain away, multiplier back to one. The banked total is safe. |
| Action | Start Balancing | `drift` (float) | Balance to dead centre, drifting at that speed per second. |
| Action | Steer The Balance | `amount` (float) | Pushes balance back toward the middle. Feed it the left/right axis. |
| Condition | Is Rolling | - | On the ground and moving. |
| Condition | Is Airborne | - | Off the ground and not on a rail. |
| Condition | Is In A Manual | - | Riding the back wheels. |
| Condition | Is Losing Balance | - | Balance is past the warning mark. |
| Expression | Balance | - | -1 to 1, with 0 dead centre. A needle reads this straight. |
| Expression | Chain Score | - | What the running chain is worth. |
| Expression | Multiplier | - | What the next trick will be multiplied by. |
| Expression | Banked Score | - | Everything banked this run. |
| Expression | Spin Turns | - | Whole turns since leaving the ground. |
| Trigger | On Ollie | - | The ollie left the ground. |
| Trigger | On Landed Clean | - | Touched down square with the floor. |
| Trigger | On Bailed | - | Crooked landing, lost balance, or Bail was called. |
| Trigger | On Trick Done | `trick`, `points` | A trick was added to the chain, with what it scored. |

### The Grind rows

| Kind | Name | Parameters | Description |
|---|---|---|---|
| Condition | Is Near Rail | `rail` (Node2D), `distance` (float) | Within that distance of the nearest point on the rail's curve. |
| Condition | Is Grinding | - | Locked to a rail and riding it. |
| Condition | Has Reached The End | - | The ride ran off either end of the curve. |
| Action | Start Grinding | `rail` (Node2D) | Locks onto the rail at the nearest point and starts the balance meter. |
| Action | Grind Along Rail | `speed` (float), `keep_momentum` (bool) | Rides one tick further along the curve. |
| Action | Hop Off | `hop` (float) | Lets the rail go with an upward kick, keeping the grind's speed. |
| Action | Ride Zipline | `rail` (Node2D) | The same lock-on, with the line's slope driving the speed. |

### Inspector properties

| Property | Default | What it does |
|---|---|---|
| `push_speed` | `40.0` | How much one push adds toward the top speed. |
| `max_speed` | `600.0` | The fastest a push will take you. A slope can carry you past it. |
| `ollie_speed` | `420.0` | Upward speed an ollie gives you. |
| `gravity` | `980.0` | Downward acceleration. Roll With The Slope projects this along the floor. |
| `max_fall_speed` | `1200.0` | Terminal velocity. |
| `friction` | `60.0` | Rolling friction on the ground. Low, because a board coasts. |
| `slope_grip` | `1.0` | How much of gravity the slope hands you. Above 1 exaggerates hills. |
| `align_speed` | `12.0` | How quickly the board settles flat onto the slope it is rolling on, in radians per second. Never while a trick is turning. |
| `trick_spin_rate` | `1.0` | Default turns per second for a spin or a flip. |
| `landing_tolerance_degrees` | `25.0` | How far off square the board may land and still count. |
| `grind_speed` | `320.0` | Default speed along a rail. |
| `rail_snap_distance` | `12.0` | How close to the rail counts as near it. |
| `hop_off_speed` | `260.0` | Upward speed a hop off a rail gives you. |
| `balance_drift` | `0.8` | How fast balance slides toward the edge per second. |
| `balance_steer` | `1.6` | How hard a full steer pushes it back. |
| `balance_warn` | `0.6` | How far out before Is Losing Balance says yes. |

### Inspector properties are ACEs too

Every property this pack exposes in the Inspector is also reachable from the picker, generated for
you: an expression named after the property reads it, a **Set ...** action writes it, and for
number properties **Add To ...** and **Subtract From ...** adjust it by an amount. They sit in the
pack's own category alongside the vocabulary above, so any knob you can set in the Inspector is
also something a sheet can read and change while the game runs.

## Reading it from expressions - the Self section

Type `self` in any ƒx field, or open the ƒx **Expressions dictionary**, and **Self ▸ Behaviours**
lists this pack's knobs and value expressions as ready-to-insert chains once the behaviour is
attached:

- `$SkateboardMovement.chain_score()` inserts the **Chain Score** entry into any expression
- `$SkateboardMovement.balance()` inserts the **Balance** entry, which is what a needle wants
- `$SkateboardMovement.max_speed` inserts the **Max Speed** knob

The `$SkateboardMovement` token stays selected after insert, so retargeting to your child's actual
name is one keystroke, or a node drag.

## Use cases

### 1. A skater you can play in three rows

Roll with the slope on the floor, push on a key, ollie on another. Nothing else is needed to have
something worth pushing around a ramp.

```
Every tick (physics)
  Condition: Player | Platform: Is on floor
    -> Player | Skateboard: Roll with the slope
On push pressed -> Player | Skateboard: Push toward max speed by 40
On jump pressed -> Player | Skateboard: Ollie at 420
```

### 2. The halfpipe that gives the speed back

There is no halfpipe code. Draw the U, call Roll With The Slope every tick, and the transition
returns what the drop gave you. Raise `slope_grip` above 1 if you want a friendlier pipe.

```
Every tick (physics)
  Condition: Player | Platform: Is on floor
    -> Player | Skateboard: Roll with the slope
```

### 3. Pumping for height

Real pumping is crouching in the transition. Here it is a push timed to the bottom of the curve,
which reads the same way to a player: hit the button low and you go higher.

```
On push pressed
  Condition: Player | Platform: Is on floor
  Condition: Player.velocity.y > 100
    -> Player | Skateboard: Push toward max speed by 60
```

### 4. A spin worth scoring

Hold the trick key in the air to spin, and score it on the landing by how many turns you got.

```
Every tick (physics)
  Condition: Player | Skateboard: Is airborne
  Condition: Keyboard: trick is down
    -> Player | Skateboard: Spin 1 turn per second
On Landed Clean
  -> Player | Skateboard: Add trick "spin" to the chain for  Player.Spin Turns * 100
```

### 5. Landing clean or eating it

The pack judges every touchdown for you. All the sheet does is decide what each outcome looks
like.

```
On Landed Clean -> Player | Skateboard: Bank the chain
                -> Juice: Screen Shake  0.1
On Bailed       -> Player | Set animation "Wipeout" play from beginning
```

### 6. The rail across the park

The classic. Falling toward a rail while near it starts the grind; the end of the line or the jump
button ends it.

```
Every tick (physics)
  ✕ Player | Grind: Is grinding
  Condition: Player | Platform: Is falling
  Condition: Player | Grind: Is near rail  Rail, 12
    -> Player | Grind: Start grinding  Rail
Every tick (physics)
  Condition: Player | Grind: Is grinding
    -> Player | Grind: Grind along the rail at 320
Player | Grind: Has reached the end
OR On jump pressed
    -> Player | Grind: Hop off the rail at 260
```

### 7. A fast approach is a fast grind

Turn Keep Momentum on and the rail stops being a fixed-speed conveyor. Bombing the hill into it
now matters.

```
Every tick (physics)
  Condition: Player | Grind: Is grinding
    -> Player | Grind: Grind along the rail at 320   (keep momentum on)
```

### 8. The zipline across the gap

Same six rows, different feel: the line's slope drives the speed, so a steep run accelerates the
whole way.

```
On grab pressed
  Condition: Player | Grind: Is near rail  Zipline, 24
    -> Player | Grind: Ride the zipline  Zipline
```

### 9. The manual you have to hold

A manual starts the balance meter drifting. Steer it with the same left/right axis you steer
everything else with, and let it go and you eat it.

```
On manual pressed -> Player | Skateboard: Ride a manual
Every tick (physics)
  Condition: Player | Skateboard: Is in a manual
    -> Player | Skateboard: Steer the balance by  Keyboard.Axis("ui_left", "ui_right")
```

### 10. The needle that warns you

Balance has a middle, which a bar cannot show, so the HUD pack draws it as a needle: point **Set
Needle** at any empty Control and it builds the needle and the centre mark inside it, turning the
warning colour past the mark you name.

```
Every tick
  -> HUD | HUD Kit: Set needle  "BalanceMeter", Player.Balance, 0.6
Player | Skateboard: Is losing balance
  -> HUD Kit: Show Panel  "BalanceWarning"
```

### 11. A chain that is only worth something when you land it

The multiplier climbs per trick and nothing is safe until it is banked. That is the whole tension:
one more trick, or take the money.

```
On Trick Done -> HUD Kit: Set Label  "Chain", Player.Chain Score & " x" & Player.Multiplier
On Landed Clean -> Player | Skateboard: Bank the chain
On Bailed       -> Player | Skateboard: Drop the chain
```

### 12. Grinds count toward the chain too

A rail is a trick. Score it when you hop off, and the multiplier carries into whatever you do next
because you never touched down.

```
On jump pressed
  Condition: Player | Grind: Is grinding
    -> Player | Skateboard: Add trick "grind" to the chain for 250
    -> Player | Grind: Hop off the rail at 260
```

### 13. Bail sends you back to the last checkpoint

The pack owns the wipeout moment and nothing else, so the recovery is whatever your game already
does about dying.

```
On Bailed -> Fade: Fade Out  0.2
          -> Player | Checkpoint: Respawn at the checkpoint
          -> Fade: Fade In   0.3
```

### 14. Brake and reverse for the flat bits

A park has corners. Braking to a stop and rolling out fakie is two rows and no state.

```
On brake down    -> Player | Skateboard: Brake by 12
On reverse press -> Player | Skateboard: Reverse the roll
```

### 15. Only push when you are actually on the board

Guard the push with Is Rolling and a player who mashes the button in the air gets nothing, which
is exactly what a board does.

```
On push pressed
  Condition: Player | Skateboard: Is rolling
    -> Player | Skateboard: Push toward max speed by 40
```

### 16. A speed run that never lets you stop

Drop `friction` to 0 and raise `slope_grip`, and the park becomes a marble run where the only
thing you control is the line you take.

```
On Ready -> Player | Skateboard: Set Friction  0
         -> Player | Skateboard: Set Slope Grip  1.6
```

### 17. A trolley, a sled, a shopping cart

Nothing here says "skateboard" to the player except the sprite. Swap it and the same rows are a
sled run down a hill or a runaway trolley in a supermarket.

```
Every tick (physics)
  Condition: Trolley | Platform: Is on floor
    -> Trolley | Skateboard: Roll with the slope
```

### 18. A tutorial that waits for the trick

Every moment this pack has is a trigger, so a tutorial step is a trigger and a counter rather than
a poll.

```
On Ollie        -> add 1 to ollies_done
On Landed Clean
  Condition: ollies_done >= 3
    -> Dialogue Kit: Say  "Now try it off the ramp."
```

### Other use cases

**Downhill racing.** Turn the tricks off entirely and use only Push, Roll With The Slope and Brake, and the pack is a gravity racer where the whole skill is choosing when to brake into a corner.

**A ski jump.** A long slope into a short lip, with Spin Turns scored on the landing and the landing tolerance narrowed to ten degrees so a bad rotation actually costs the run.

**Cable cars and cargo lines.** Ride Zipline on a Path2D with a crate as the host, so freight moves along a drawn line under its own weight with no tween and no waypoints.

**A rhythm section on a rail.** Grind Along Rail with Keep Momentum, plus a beat check, so hitting the button in time each bar adds to the chain and missing it drops you off.

**Physics-free platforming for a jam.** Roll With The Slope plus Ollie gives you slope-aware movement on a CharacterBody2D in two rows, which is a faster start than tuning a full run-and-jump controller when the deadline is Sunday.

## Tips and common mistakes

- **Roll With The Slope belongs in a tick, not a trigger.** It is a continuous force. Called once
  it does almost nothing; called every physics frame on the floor it is the whole feel of the
  pack.
- **Push is not a held button.** It adds a fixed amount per call. If you wire it to a held key it
  becomes an acceleration model and you have quietly rebuilt a platformer.
- **The board keeps its speed in the air.** That is deliberate. If you want air control, add it
  yourself with a small velocity nudge - the pack will not do it behind your back.
- **A grind suspends gravity.** While Is Grinding is true the pack does not fall you, brake you,
  or judge a landing. Hop Off is what hands the board back.
- **Rails are ordinary Path2D nodes.** No script, no marker, no group. If it has a curve with two
  or more points, it is a rail.
- **Nothing in the chain is real until it is banked.** That is the point of the row being called
  Bank. A bail drops the chain and the banked total is untouched.
- **Balance drifts away from the middle, not toward it.** It leans further the way it is already
  going, so a manual is a held breath. Set `balance_drift` to 0 for a free ride while you are
  building the level.
- **You cannot bail a trick you never did.** A board that touches down without having turned in the
  air is simply rolling again, however steep the slope. The landing tolerance only judges landings
  that had a trick in them, which is what keeps a beginner rolling down a bank from wiping out on
  arrival. While rolling, the board settles flat onto the slope at `align_speed`, so leaving a ramp
  leaves you at the ramp's angle - which is exactly what the landing test then measures against.
