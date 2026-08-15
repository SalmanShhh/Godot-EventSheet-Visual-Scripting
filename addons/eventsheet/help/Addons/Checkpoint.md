# Checkpoint - One Point to Send Anything Back To

The save-point behavior: attach `CheckpointBehavior` to any Node2D and it remembers one place
in the world. **Set Checkpoint Here** marks the spot the host is standing on, **Set Checkpoint
At** marks any point without moving it, and **Respawn At Checkpoint** teleports the host back
and fires **On Respawned**. The host's starting position is captured on ready, so a respawn
works from the first frame - before the player has touched a single flag.

If the host defines a `reset()` method, respawning calls it. That is the same duck-typed seam
the Object Pool uses when it wakes a pooled node, so hp, velocity, and timers clear on every
respawn without this pack knowing what any of them are.

## Where this pack shines

- **Death and retry.** The lava kills you, the player reappears at the last flag, one row.
- **Anything that must go back.** Pushed blocks, escorted NPCs, dropped keys - a checkpoint is
  not only for the player.
- **Room re-entry.** Mark the doorway on the way in, send the player back to it when a puzzle
  is failed instead of restarting the level.

## Setup

1. Attach `CheckpointBehavior` as a child of the node that should be able to respawn.
2. Leave **Capture On Ready** on so the node's starting spot is its first checkpoint.
3. Mark new checkpoints from your sheet, and respawn whenever you need to.

```
On Body Entered (Flag)  -> Player | Checkpoint: Set the checkpoint here
On Died                 -> Player | Checkpoint: Respawn at the checkpoint
```

## ACE reference

On the canvas these verbs read as styled sentences - parameter values in **bold**, node
references in *italic*, exactly as the rows draw them:

- Set the checkpoint **here**
- Set the checkpoint at **(320, 96)**
- **Respawn** at the checkpoint

| Kind | Name | Parameters | Description |
|---|---|---|---|
| Action | Set Checkpoint Here | - | Marks the spot the host is standing on right now. |
| Action | Set Checkpoint At | `point` (Vector2) | Marks any point in the world, without moving the host. |
| Action | Respawn At Checkpoint | - | Teleports the host to the checkpoint, calls the host's `reset()` if it has one, and fires On Respawned. |
| Expression | Checkpoint Position | - | The point the host respawns at, as a Vector2. |
| Trigger | On Respawned | - | Fires after each respawn, once the host has already been moved. |

### Inspector properties

| Property | Default | What it does |
|---|---|---|
| `capture_on_ready` | `true` | Remembers where the host starts as its first checkpoint, so Respawn works before any flag is touched. Turn it off if the checkpoint should come only from a save file. |

### Inspector properties are ACEs too

Every property this pack exposes in the Inspector is also reachable from the picker, generated
for you: an expression named after the property reads it, a **Set ...** action writes it, and for
number properties **Add To ...** and **Subtract From ...** adjust it by an amount. They sit in the
pack's own category alongside the verbs above, so any knob you can set in the Inspector is also
something a sheet can read and change while the game runs.

## Reading it from expressions - the Self section

Type `self` in any ƒx field, or open the ƒx **Expressions dictionary**, and **Self ▸ Behaviours**
lists this pack's knobs and value verbs as ready-to-insert chains once the behaviour is attached:

- `$CheckpointBehavior.checkpoint_position()` inserts the **Checkpoint Position** entry straight
  into any expression
- `$CheckpointBehavior.capture_on_ready` inserts the **Capture On Ready** entry straight into any
  expression

The `$CheckpointBehavior` token stays selected after insert, so retargeting to your child's actual
name is one keystroke, or a node drag. Attaching this behaviour at runtime instead? Tick **Robust
behaviour lookups** in the dictionary and the same entries insert as
`get_node_or_null("CheckpointBehavior")` chains, which survive auto-named children.

## Use cases

### 1. The flag on the pole

The classic. Touch a flag, the flag becomes the checkpoint.

```
On Area Entered (Checkpoint flag) -> Player | Checkpoint: Set the checkpoint here
```

### 2. Death by lava

Falling in the lava sends the player back and clears their momentum, because the player scene
defines `reset()`.

```
On Area Entered (Lava) -> Player | Checkpoint: Respawn at the checkpoint
                       -> Player | Health: Take Damage  1
```

### 3. The fall-out-of-the-world floor

One invisible Area2D under the whole level catches every fall, no matter which pit caused it.

```
On Area Entered (KillFloor) -> Player | Checkpoint: Respawn at the checkpoint
```

### 4. Respawn with a fade

On Respawned fires after the host has moved, which is exactly when you want the screen to come
back.

```
On Died      -> Fade: Fade Out  0.2
On Respawned -> Fade: Fade In   0.3
```

### 5. Checkpoint the pushable block too

A block pushed into a pit softlocks the room. Give the block its own CheckpointBehavior and send
it home with the player.

```
On Died -> Player | Checkpoint: Respawn at the checkpoint
        -> Block  | Checkpoint: Respawn at the checkpoint
```

### 6. Room entrance memory

Mark the doorway as you walk in, so a failed puzzle costs the room, not the level.

```
On Area Entered (Room door) -> Player | Checkpoint: Set the checkpoint here
On Puzzle Failed            -> Player | Checkpoint: Respawn at the checkpoint
```

### 7. Boss arena reset

The boss fight starts at a fixed spot every attempt, whatever the player did on the way in.

```
On Boss Fight Start -> Player | Checkpoint: Set the checkpoint at  (512, 448)
```

### 8. Save and restore the checkpoint

Checkpoint Position reads the point, Set Checkpoint At writes it back, so it survives a save file.

```
On Save -> Save System: Set Value  "checkpoint", Player.Checkpoint Position
On Load -> Player | Checkpoint: Set the checkpoint at  Save System: Get Value "checkpoint"
```

### 9. Count the deaths

Every respawn is a trigger, so a death counter is one row with no bookkeeping.

```
On Respawned -> add 1 to deaths
             -> HUD Kit: Set Label  "DeathCount", deaths
```

### 10. Escort NPCs back with you

An escort that stayed behind in the dangerous room is a lost run. Respawn it beside the player.

```
On Respawned -> Companion | Checkpoint: Respawn at the checkpoint
```

### 11. Practice mode rewind

Bind a key to "put me back where I was" so a speedrunner can drill one jump for an hour.

```
On Key Pressed "R" -> Player | Checkpoint: Respawn at the checkpoint
On Key Pressed "T" -> Player | Checkpoint: Set the checkpoint here
```

### 12. Reset the whole puzzle room

Give each moving part a CheckpointBehavior and one row per part puts the room back to its
opening state.

```
On Reset Pressed -> Mirror  | Checkpoint: Respawn at the checkpoint
                 -> Crate   | Checkpoint: Respawn at the checkpoint
                 -> Pressure| Checkpoint: Respawn at the checkpoint
```

### 13. Checkpoints that cost something

Charge for the convenience: only mark the flag if the player can pay for it.

```
On Area Entered (Shrine)
  Condition: Currency: Can Afford  "gold", 25
    -> Currency: Spend  "gold", 25
    -> Player | Checkpoint: Set the checkpoint here
```

### 14. One-way checkpoints in a vertical climb

Only ever mark a flag that is higher than the last one, so a fall can never cost the player
their progress in a tower level.

```
On Area Entered (Flag)
  Condition: Flag.position.y < Player.Checkpoint Position.y
    -> Player | Checkpoint: Set the checkpoint here
```

### 15. Racing rewind button

Off-track cars come back to the last gate they passed, facing the right way, with a small time
penalty - the `reset()` on the car scene zeroes the speed.

```
On Gate Passed      -> Car | Checkpoint: Set the checkpoint here
On Rewind Requested -> Car | Checkpoint: Respawn at the checkpoint
                    -> add 3 to penalty_seconds
```

### Other use cases

**Photo mode return.** Mark the player's spot before the free camera takes over, then respawn them exactly there when the player closes photo mode, so the pause never nudges the run.

**Stealth alarm reset.** When a guard raises the alarm, respawn the player at the room entrance instead of a full reload, keeping the retry loop under a second.

**Fishing spot memory.** Mark the water's edge when a fishing minigame starts so the player is placed back at the same pier tile every time they cast, however the minigame moves the camera.

**Tutorial rollback.** Each tutorial step marks its own checkpoint, so a "let me try that again" button always drops the learner at the start of the step they are on, not the start of the lesson.

**Tower defense wave reset.** Give the creep spawner a checkpoint at its lane entrance so a restarted wave sends every leaked creep back to the gate rather than deleting and respawning scenes.

## Tips and common mistakes

- **It teleports, it does not tween.** Respawn At Checkpoint sets the position outright. Want a
  glide? Pair it with Move To, or fade the screen over the jump.
- **`reset()` is optional but powerful.** A host without one simply skips the call. A host with
  one is where velocity, health, animation state, and cooldowns belong - the pack calls it after
  the move, so `reset()` sees the host already at its checkpoint.
- **Checkpoint Position is global.** The point is stored in world space, so re-parenting the host
  does not move its checkpoint.
- **On Respawned fires after the move.** Anything that reads the host's position in that trigger
  gets the checkpoint, not the place the host died.
- **Capture On Ready is not a save file.** It remembers where the host started this run. Persisting
  a checkpoint across sessions is Save System's job - store Checkpoint Position, restore it with
  Set Checkpoint At.
