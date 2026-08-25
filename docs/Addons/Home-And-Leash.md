# Home & Leash - Keep Anything Near Where It Belongs

The guard-post behavior: attach `HomeLeashBehavior` to any Node2D and it remembers a home point.
**Is Beyond Home** branches the moment the host has wandered too far, **Distance From Home**
reads how far in whichever way your game measures distance, and **Return Home** walks the host
back one step at a time, firing **On Arrived Home** on the step that lands. The guard who gives
up the chase, the shopkeeper who returns to the counter, the pet that never strays past the
fence.

The leash length is measured in the metric you pick, because a grid game and a side-scroller do
not agree on what "far" means:

| Metric | Value | Measures |
|---|---|---|
| Straight line | `0` | The real distance, as the crow flies. |
| Horizontal only | `1` | Sideways drift alone - the side-scroller's answer. |
| Vertical only | `2` | Up and down alone. |
| Grid steps | `3` | Across plus down (`abs(dx) + abs(dy)`) - how a rook or a four-way walker travels. |
| King moves | `4` | The larger of the two (`max(abs(dx), abs(dy))`) - how a chess king or an eight-way walker travels. |

## Where this pack shines

- **Enemies with a post.** Chase the player, but only so far, then walk back.
- **Wandering NPCs.** Let idle roaming be sloppy and the leash keep it honest.
- **Grid and tactics games.** Grid steps and king moves are the units the board actually uses,
  so a "3 tiles from post" rule is one row, not a distance formula.

## Setup

1. Attach `HomeLeashBehavior` as a child of the node that should stay near something.
2. Leave **Capture On Ready** on and the node's starting spot becomes home, or call **Set Home
   At** for a hand-picked post.
3. Ask **Is Beyond Home** while chasing, and run **Return Home** under a per-frame trigger with
   that trigger's delta.

```
Every tick
  Condition: Guard | Is Beyond Home  240, Straight line
    -> Guard | Home & Leash: Walk home at  90, delta
```

## ACE reference

On the canvas these rows read as styled sentences - parameter values in **bold**, node
references in *italic*, exactly as the rows draw them:

- Set home **here**
- Set home at **(640, 320)**
- Walk home at **90**

| Kind | Name | Parameters | Description |
|---|---|---|---|
| Action | Set Home Here | - | Plants home on the spot the host is standing on right now. |
| Action | Set Home At | `point` (Vector2) | Plants home on any point in the world, without moving the host. |
| Condition | Is Beyond Home | `distance`, `metric` | True while the host has wandered further than this from home, in the metric you pick. |
| Expression | Distance From Home | `metric` | How far the host is from home, in the metric you pick. |
| Action | Return Home | `speed`, `delta` | Walks one step back toward home. Run it under a per-frame trigger and pass that trigger's delta. |
| Trigger | On Arrived Home | - | Fires once, on the step that lands within a pixel of home. |

Both `metric` parameters are labeled dropdowns in the picker - you choose *Straight line* or
*Grid steps*, not a number to remember.

### Inspector properties

| Property | Default | What it does |
|---|---|---|
| `capture_on_ready` | `true` | Plants home where the host starts, so the leash works before you set one by hand. Turn it off if home always comes from a spawner or a save file. |

### Inspector properties are ACEs too

Every property this pack exposes in the Inspector is also reachable from the picker, generated
for you: an expression named after the property reads it, a **Set ...** action writes it, and for
number properties **Add To ...** and **Subtract From ...** adjust it by an amount. They sit in the
pack's own category alongside the vocabulary above, so any knob you can set in the Inspector is also
something a sheet can read and change while the game runs.

## Reading it from expressions - the Self section

Type `self` in any ƒx field, or open the ƒx **Expressions dictionary**, and **Self ▸ Behaviours**
lists this pack's knobs and value expressions as ready-to-insert chains once the behaviour is attached:

- `$HomeLeashBehavior.distance_from_home(0)` inserts the **Distance From Home** entry straight into
  any expression
- `$HomeLeashBehavior.capture_on_ready` inserts the **Capture On Ready** entry straight into any
  expression

The `$HomeLeashBehavior` token stays selected after insert, so retargeting to your child's actual
name is one keystroke, or a node drag. Attaching this behaviour at runtime instead? Tick **Robust
behaviour lookups** in the dictionary and the same entries insert as
`get_node_or_null("HomeLeashBehavior")` chains, which survive auto-named children.

## Use cases

### 1. The guard who gives up

The oldest enemy AI there is: chase until the leash snaps, then walk back to the post.

```
Every tick
  Condition: Guard | Is Beyond Home  300, Straight line
    -> Guard | State Machine: Go to state  "returning"
```

### 2. Walking back to the post

Return Home is one step per call, so it belongs under a per-frame trigger with that trigger's
delta.

```
Every tick
  Condition: Guard | State Machine: Current state is  "returning"
    -> Guard | Home & Leash: Walk home at  80, delta
On Arrived Home -> Guard | State Machine: Go to state  "idle"
```

### 3. The shopkeeper behind the counter

Let the shopkeeper wander for flavour and snap back when a customer walks in.

```
On Customer Entered -> Keeper | Home & Leash: Walk home at  120, delta
```

### 4. A pet that stays in the yard

The pet follows the player freely, but only inside the fence.

```
Every tick
  Condition: Pet | Is Beyond Home  180, Straight line
    -> Pet | Follow: Stop Following
    -> Pet | Home & Leash: Walk home at  140, delta
```

### 5. Side-scroller patrol

In a platformer the guard's height is irrelevant - only the sideways drift should end a chase.

```
Every tick
  Condition: Guard | Is Beyond Home  200, Horizontal only
    -> Guard | give up the chase
```

### 6. Elevator that returns to its floor

Vertical only measures the shaft and nothing else, so a nudged elevator finds its rest floor.

```
Every tick
  Condition: Lift | Is Beyond Home  4, Vertical only
    -> Lift | Home & Leash: Walk home at  60, delta
```

### 7. Tactics range in tiles

With a 32px grid, a three-tile leash is `96` in grid steps - the same unit the board draws in.

```
Every tick
  Condition: Unit | Is Beyond Home  96, Grid steps
    -> Unit | mark "out of position"
```

### 8. Eight-way zone of control

King moves is the metric for an eight-way walker, so a diagonal step counts the same as a
straight one.

```
Every tick
  Condition: Knight | Is Beyond Home  64, King moves
    -> Knight | Home & Leash: Walk home at  100, delta
```

### 9. Turret that re-centres

A turret dragged off its mount by a physics push crawls back to it between waves.

```
On Wave Cleared -> Turret | Home & Leash: Walk home at  40, delta
```

### 10. Leash length by difficulty

The distance is a parameter, so the whole game's aggression is one variable.

```
Every tick
  Condition: Guard | Is Beyond Home  leash_length, Straight line
    -> Guard | give up the chase
```

### 11. Move the post, move the guard

Set Home At relocates the post without touching the guard - the guard walks to the new one.

```
On Shift Change -> Guard | Home & Leash: Set home at  (1024, 320)
```

### 12. Spawner-assigned posts

A spawner places each enemy and immediately plants its home, so a pack of guards fans out and
each one keeps its own beat.

```
On Enemy Spawned -> Enemy | Home & Leash: Set home here
```

### 13. A distance readout for debugging

Distance From Home is an expression, so it drops into a debug label or a Doctor-style HUD row.

```
Every tick -> HUD Kit: Set Label  "GuardDrift", Guard.Distance From Home(0)
```

### 14. Fade the chase music on the way back

On Arrived Home is the honest "the fight is over" moment - it fires once, on the step that lands.

```
On Arrived Home -> Audio: Fade Music To  "calm", 1.5
```

### 15. Tether two-player co-op

Plant home on player one and check player two against it, so the camera never has to choose
between them.

```
Every tick -> Player2 | Home & Leash: Set home at  Player1.global_position
  Condition: Player2 | Is Beyond Home  400, Straight line
    -> show the "stay together" nudge
```

### Other use cases

**Fishing bobber drift.** Plant home where the bobber lands and let the current push it, snapping it back with Return Home once it drifts past the castable range.

**Camera dolly rest position.** Give a cinematic camera dummy a home and walk it back between shots, so every conversation starts framed the same way whatever the last scene did to it.

**Herd animals.** Plant each animal's home on the herd's centre each morning so the flock grazes outward all day and gathers itself again without a shepherd script.

**Drone recall in a base-builder.** Worker drones that stray past their charging pad's radius are walked home by Return Home, which doubles as the low-battery behaviour.

**Boss arena tether.** Plant the boss's home at the arena centre and check King moves each frame, so a knockback that flings it into a corner is corrected before the next attack lands.

## Tips and common mistakes

- **Return Home is one step, not a journey.** It moves the host once per call, which is why it
  takes a `delta`. Run it under a per-frame trigger and pass that trigger's delta - a physics
  tick, a slowed-down tick, or a hand-stepped test all stay honest that way.
- **On Arrived Home is edge-triggered.** It fires on the step that lands within a pixel of home,
  and not again while the host sits there. Walk away and come back and it arms itself again.
- **Pick the metric your game measures in.** Straight line is the default answer, but a grid game
  reading straight-line distance will disagree with its own movement rules on every diagonal.
- **Is Beyond Home is exclusive.** Exactly at the leash length is not beyond it, so a host sitting
  precisely on the boundary reads `false`.
- **Home is in world space.** Re-parenting the host does not move its home point. Plant a new one
  with Set Home Here if it should.
- **It moves the host, not a body.** Return Home sets the position outright, the same way Move To
  does. A CharacterBody2D that needs collision on the way back should feed the direction into its
  own movement instead of calling Return Home.
