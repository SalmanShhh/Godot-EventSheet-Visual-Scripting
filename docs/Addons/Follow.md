# Follow - One Node Trails Another, Smooth or Delayed

Follow is a Godot EventSheets behavior pack. You attach a `FollowBehavior` to a Node2D and that node becomes a follower: every frame it moves toward another node you name, either easing smoothly toward it or replaying where that node was a moment ago. There is no "follower id" to pass around - every Action, Condition, Expression, and Trigger targets the `FollowBehavior` living on the node you drop it on. Point it at a target with **Start Following**, choose the feel with the `mode` and `follow_speed` knobs, and the behavior does the chasing in its `_process` tick. It is built for the small, everyday "make this thing trail that thing" jobs - pets, homing shots, camera dummies, snake tails - without hand-writing lerp code on every object.

---

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [ACE reference](#ace-reference)
5. [Use cases](#use-cases)
6. [Tips and common mistakes](#tips-and-common-mistakes)

---

## Where this pack shines

- **Companion pets and familiars.** A pet that trails the player at a soft, springy lag instead of teleporting onto their head.
- **Homing projectiles.** A missile or magic bolt that eases onto its target and fires On Reached Target the moment it lands.
- **Enemies that close to attack range.** A chaser that runs at the player and stops at Min Distance, giving you a clean cue to start a melee swing.
- **Snake and conga-line bodies.** In delayed mode each segment replays the position of the one ahead, so a chain of segments flows like a real tail.
- **Ghosts and time echoes.** A phantom that walks your exact recent path a full second behind you.
- **Escort and bodyguard NPCs.** A guard that keeps a set standoff distance from the escortee while matching their movement.
- **Floating HUD bits in the world.** A nameplate, health bar, or damage number that drifts to keep up with a moving unit rather than snapping.
- **Trailing lights and lanterns.** A lantern or wisp that lags a quarter second behind the hero for a hand-carried feel.
- **Camera target dummies.** A hidden Node2D that eases toward the player so your camera tracks something smooth instead of the jittery player body.
- **Reticles and cursors.** An aim reticle that smooths toward the raw pointer position for a weighty, assisted feel.
- **Boss tail and tentacle segments.** A head node the segments chase, tightening the chase when the boss enrages.
- **Formation wingmen.** Escort ships or drones that trail the leader at a delay you shrink as the squad closes ranks.

---

## Core concepts

The model is tiny. Learn these five ideas and the whole pack is just knobs.

**The node is the follower.** You attach one `FollowBehavior` as a child of a Node2D. That parent Node2D is the **host** - the thing that actually moves. The behavior reads and writes the host's `position` every frame, so anything you can put a Node2D on (a sprite, a body, an area, a plain Node2D) can follow.

**You point it at a target by node path.** The target is named by a path string in `target_path`, resolved **relative to the host** (not relative to the behavior node). If the follower and its target are siblings under the same parent, the path is `"../Target"`. If the target is a child of the host, it is just `"Target"`. Set the path in the Inspector, or at runtime with **Start Following** or **Set Target Path**. An empty path means "follow nothing" and the behavior sits still.

**Two follow styles: smooth and delayed.** The `mode` knob picks the feel:

- `smooth` - each frame the host eases toward the target's current position with a lerp. `follow_speed` sets how fast it closes the gap. This is a chase: the host is always heading for where the target is *now*.
- `delayed` - the behavior records the target's position over time and replays it after a lag of `delay` seconds. The host walks the target's *past* path exactly, so it never cuts corners. This is the trailing-tail feel (a snake body, a ghost echo, a lagging lantern).

**Min Distance is the stop-and-arrive line (smooth mode).** In smooth mode, once the host gets within `min_distance` pixels of the target it stops moving and fires **On Reached Target** once. That is how you say "chase the player, then stop at attack range" without any distance math in your sheet. With the default `min_distance` of 0 the host only "arrives" when it is exactly on top of the target, so set a real range if you want a useful arrival cue. Delayed mode ignores Min Distance and never fires On Reached Target - it is a replay, not a chase.

**Following can be paused.** **Stop Following** freezes the host where it is without detaching the behavior; **Start Following** resumes (and re-points and clears the recorded history). It is a light on/off switch, not a teardown.

---

## Setup

**1. Attach the behavior.** Add a `FollowBehavior` as a child node of the Node2D you want to move (open the pack sheet and use Tools > Attach to Selected Node, or drop the pack node in as a child). The host is the parent - if the parent is not a Node2D the behavior warns and does nothing.

**2. Set the Inspector knobs.** Select the `FollowBehavior` node and tune the feel:

| Property | Default | What it does |
|---|---|---|
| `target_path` | `""` | Node path (relative to the host Node2D) of the node to follow. Empty = follow nothing. |
| `mode` | `smooth` | `smooth` eases toward the target's current position each frame; `delayed` replays the target's position from `delay` seconds ago. |
| `follow_speed` | `5.0` | Smooth mode only: how fast the host closes the gap (used as a per-frame lerp factor). Higher = snappier. |
| `delay` | `0.4` | Delayed mode: how many seconds behind the target the host trails (also sets how much position history is kept). |
| `min_distance` | `0.0` | Smooth mode: the host stops and fires On Reached Target once it is within this many pixels (0 = only when overlapping). |

**3. Point it at a target and go.** You can set `target_path` in the Inspector and be done, or drive it from the sheet. Here is a complete first follower - a pet that eases after the player:

```
On Ready
  -> Pet | Follow: Set Mode  "smooth"
  -> Pet | Follow: Set Follow Speed  6
  -> Pet | Follow: Start Following  "../Player"
```

Every ACE in a row acts on the `FollowBehavior` of the node named on the left (`Pet` here). The `"../Player"` path is read from the host, so it points at a sibling of Pet called Player. That is the whole loop - the behavior chases in its own tick, and you only touch it again when you want to retarget, change speed, or stop.

---

## ACE reference

All ACEs live in the **Follow** category and target the `FollowBehavior` on the node the row is placed on. The five Inspector properties are exposed as get/set ACEs (and add/subtract for the numeric ones), plus the two authored verbs and the arrival trigger.

### Actions

| Action | Parameters | Description |
|---|---|---|
| Start Following | `path` (String) | Points the follower at the node at `path` (relative to the host) and begins trailing it. Clears the recorded position history, so a delayed trail starts fresh. |
| Stop Following | (none) | Stops trailing; the host holds its current position. Start Following resumes. |
| Set Target Path | `value` (String) | Sets the target node path directly (relative to the host) without clearing history - swap targets while keeping the existing trail. |
| Set Mode | `value` (String) | Sets the follow style: `"smooth"` (eased chase) or `"delayed"` (replay past positions). |
| Set Follow Speed | `value` (float) | Sets how fast the host eases toward the target in smooth mode. |
| Add To Follow Speed | `amount` (float) | Adds to the current follow speed. |
| Subtract From Follow Speed | `amount` (float) | Subtracts from the current follow speed. |
| Set Delay | `value` (float) | Sets the trailing delay in seconds used by delayed mode. |
| Add To Delay | `amount` (float) | Adds to the delay. |
| Subtract From Delay | `amount` (float) | Subtracts from the delay. |
| Set Min Distance | `value` (float) | Sets the stop-and-arrive distance: in smooth mode the host stops and fires On Reached Target once within this many pixels. |
| Add To Min Distance | `amount` (float) | Adds to the min distance. |
| Subtract From Min Distance | `amount` (float) | Subtracts from the min distance. |

### Conditions

| Condition | Parameters | Description |
|---|---|---|
| (none) | - | Follow ships no dedicated conditions. To branch on its state, drop one of the expressions below into a condition slot and compare it - for example `Follow Speed < 8` or `Mode == "delayed"`. React to arrival with the On Reached Target trigger. |

### Expressions

| Expression | Parameters | Returns | Description |
|---|---|---|---|
| Target Path | (none) | String | The node path currently being followed (relative to the host); "" if none. |
| Mode | (none) | String | The current follow style, `"smooth"` or `"delayed"`. |
| Follow Speed | (none) | float | The current smooth-mode ease factor. |
| Delay | (none) | float | The current trailing delay in seconds. |
| Min Distance | (none) | float | The current stop-and-arrive distance in pixels. |

### Triggers

| Trigger | Fires when |
|---|---|
| On Reached Target | The host arrives in smooth mode - its distance to the target drops to Min Distance or less. Fires once per arrival (it re-arms after the host moves back out of range). Delayed mode never fires this. |

---

## Use cases

Each example targets the `FollowBehavior` on the named node. Paths are relative to that node's host (its Node2D parent), so a sibling is `"../Name"`.

### 1. Pet that trails the player

A companion eases after the player at a soft lag.

```
On Ready
  -> Pet | Follow: Set Mode  "smooth"
  -> Pet | Follow: Set Follow Speed  6
  -> Pet | Follow: Start Following  "../Player"
```

### 2. Homing missile that eases onto a target

The missile closes on the enemy and detonates the instant it arrives.

```
On Missile Spawned
  -> Missile | Follow: Set Follow Speed  4
  -> Missile | Follow: Set Min Distance  8
  -> Missile | Follow: Start Following  "../Enemy"

On Reached Target
  -> Missile: explode
```

Min Distance 8 gives the missile a small "hit" radius so it fires On Reached Target just before overlapping.

### 3. Enemy that stops at attack range

The chaser runs at the player, then stops and swings once it is close.

```
On Ready
  -> Enemy | Follow: Set Min Distance  60
  -> Enemy | Follow: Set Follow Speed  8
  -> Enemy | Follow: Start Following  "../Player"

On Reached Target
  -> Enemy: start melee swing
```

Because it stops at 60 pixels, the enemy never jitters on top of the player, and On Reached Target is your clean "in range" cue.

### 4. Snake or conga tail with delayed mode

Each body segment replays the segment ahead of it, so the chain flows.

```
On Ready
  -> Tail1 | Follow: Set Mode  "delayed"
  -> Tail1 | Follow: Set Delay  0.15
  -> Tail1 | Follow: Start Following  "../Head"
```

Give each following segment its own Follow behavior pointing at the one in front, with a slightly larger delay per segment for a longer body.

### 5. Ghost echo replaying your path

A phantom walks your exact route a full second behind you.

```
On Ready
  -> Ghost | Follow: Set Mode  "delayed"
  -> Ghost | Follow: Set Delay  1.0
  -> Ghost | Follow: Start Following  "../Player"
```

Delayed mode never cuts corners, so the ghost retraces your turns faithfully.

### 6. Sprinting companion keeps up

When the player sprints, tighten the chase; restore it when they slow.

```
On Sprint Started
  -> Companion | Follow: Set Follow Speed  11

On Sprint Stopped
  -> Companion | Follow: Set Follow Speed  5
```

### 7. Escort NPC holding a standoff distance

The guard matches the player's movement but stops a fixed gap away.

```
On Escort Begin
  -> Guard | Follow: Set Min Distance  90
  -> Guard | Follow: Set Follow Speed  7
  -> Guard | Follow: Start Following  "../Player"
```

### 8. Camera target dummy

A hidden Node2D eases toward the player so the camera tracks something smooth.

```
On Ready
  -> CamTarget | Follow: Set Mode  "smooth"
  -> CamTarget | Follow: Set Follow Speed  10
  -> CamTarget | Follow: Start Following  "../Player"
```

Point your Camera2D at `CamTarget` instead of the player, and the shake of the raw player body never reaches the camera.

### 9. Re-lock onto a new target mid-flight

A drone swaps targets without losing its current momentum.

```
On New Target Acquired
  -> Drone | Follow: Set Target Path  "../NewEnemy"
```

Set Target Path keeps the recorded trail; use Start Following instead if you want a clean, history-cleared re-lock.

### 10. Pause and resume following

A companion freezes while the player is hidden, then resumes.

```
On Player Hidden
  -> Companion | Follow: Stop Following

On Player Revealed
  -> Companion | Follow: Start Following  "../Player"
```

Stop Following just parks the host in place; nothing is detached, so resuming is instant.

### 11. Gradually tighten the chase

A seeker starts loose and ramps its follow speed up over time, using the Follow Speed expression as a ceiling.

```
On Ready
  -> Seeker | Follow: Set Follow Speed  1
  -> Seeker | Follow: Start Following  "../Prey"

Every 0.5 seconds
  Condition: Seeker | Follow  Follow Speed  <  8
    -> Seeker | Follow: Add To Follow Speed  0.5
```

### 12. Trailing lantern light

A lantern lags a quarter second behind the hero for a hand-carried feel.

```
On Ready
  -> Lantern | Follow: Set Mode  "delayed"
  -> Lantern | Follow: Set Delay  0.25
  -> Lantern | Follow: Start Following  "../Hero"
```

### 13. Formation wingman that closes ranks

Each cleared wave shrinks the trailing delay, tightening the formation, guarded by the Delay expression so it never drops below a floor.

```
On Wave Cleared
  Condition: Wingman | Follow  Delay  >  0.1
    -> Wingman | Follow: Subtract From Delay  0.05
```

### 14. Reticle that smooths toward the aim point

An aim reticle eases toward the raw pointer for a weighty, assisted feel.

```
On Ready
  -> Reticle | Follow: Set Follow Speed  15
  -> Reticle | Follow: Start Following  "../AimPoint"
```

Keep an invisible `AimPoint` Node2D on the mouse or stick position and let the reticle chase it.

### 15. A fetch loop that retargets on arrival

A dog chases the thrown ball, and the moment it arrives it turns around and brings it back - the Target Path expression tells the arrival handler which leg just finished.

```
On Ball Thrown
  -> Dog | Follow: Set Min Distance  12
  -> Dog | Follow: Start Following  "../Ball"

On Reached Target
  Condition: Dog | Follow  Target Path  ==  "../Ball"
    -> Dog: pick up the ball
    -> Dog | Follow: Start Following  "../Player"
```

Start Following on the return leg clears the history, so the trip back begins fresh instead of replaying the chase.

### Other use cases

**Fishing lure minigame.** The fish smooth-follows the bobbing lure at a low follow speed, and On Reached Target is the bite that starts the reel-in.

**Parade caravan.** Wagons in delayed mode each replay the one ahead, so the whole procession snakes through town corners without cutting them.

**Boss tentacle chain.** Segments follow the head with growing delays, and shrinking those delays on enrage snaps the tentacle taut.

**Haunting pursuer.** A spirit in delayed mode walks the victim's exact route a few seconds behind, so doubling back means meeting your own past.

**Magnet loot.** Dropped coins ease toward the hero once they are close, with a small Min Distance so On Reached Target marks the collect moment.

---

## Tips and common mistakes

- **The host must be a Node2D.** The behavior moves its parent's `position`, so attach it under a Node2D (a Sprite2D, a body, a plain Node2D). If the parent is not a Node2D it prints a warning and does nothing.
- **Paths are relative to the host, not the behavior node.** A sibling of the host is `"../Player"`; a child of the host is just `"Child"`. If nothing follows, an unresolved path is almost always the cause - check it against the host's position in the tree.
- **On Reached Target only fires in smooth mode.** Delayed mode is a replay and never "arrives", so do not wait on On Reached Target there. If you need an arrival cue, use smooth mode with a real Min Distance.
- **The default Min Distance of 0 means "only when overlapping".** For a useful arrival and to stop the follower from jittering on top of the target, set Min Distance to your actual stop or attack range.
- **Follow Speed is a per-frame ease factor, not pixels per second.** It is clamped internally between 0 and 1 each frame, so values around 3 to 10 give a visible ease and anything much higher just means "basically snap to the target".
- **Start Following clears the trail; Set Target Path keeps it.** Use Start Following for a clean re-lock (and a fresh delayed trail on the new target); use Set Target Path when you want to swap targets without losing the current path history.
- **Set Mode takes exactly `"smooth"` or `"delayed"` (lowercase).** Any other string leaves the behavior in whatever mode it was already in, which reads as "the mode change did nothing".
- **Delay drives the trail length and its memory.** A larger delay stores more recorded positions; keep it modest (a fraction of a second up to a couple of seconds) rather than very large.
- **Stop Following parks, it does not detach.** The host holds its spot and the behavior stays attached, so Start Following resumes immediately without re-adding anything.
- **One target per behavior.** A Follow behavior chases a single node path. For a chain like a snake, give every segment its own Follow behavior pointing at the segment ahead of it.
