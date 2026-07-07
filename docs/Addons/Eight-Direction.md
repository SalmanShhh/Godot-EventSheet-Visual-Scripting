# Eight Direction - Top-Down Movement You Attach and Forget

Eight Direction is a Godot EventSheets behavior pack that gives a character top-down, eight-way movement with nothing to wire. It is a per-node `EightDirectionMovement` behavior you attach as a child of a `CharacterBody2D`. Once it is attached, the behavior reads the built-in `ui_left`, `ui_right`, `ui_up`, `ui_down` input actions every physics frame, turns them into a velocity, and calls move-and-slide on the host - so arrow-key movement works the moment you press play, with zero event rows. The only thing you drive from your event sheet is the speed: set it live with **Set Move Speed**, nudge it with **Add To Move Speed** or **Subtract From Move Speed**, and read the current value back with the **Move Speed** expression. Pick a starting speed once in the Inspector and the rest is gameplay.

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

- **Top-down RPG and adventure players.** Drop it on the hero and the overworld is walkable in seconds, no movement script to write.
- **Roguelike and dungeon crawlers.** Free eight-way movement through rooms and corridors, with wall collisions handled for you by the host body.
- **Arena and bullet-hell characters.** Precise diagonal movement that reads straight from the input actions, so dodging feels crisp.
- **Life-sim and farming games.** A character that strolls a farm or town, with speed you can drop when carrying a heavy load.
- **Overworld map exploration.** A pawn that roams a world map between encounters, sped up or slowed for terrain.
- **Twin-roamer prototypes.** Stand up a playable body in a fresh scene to test level layout before any systems exist.
- **Hub and menu avatars.** A walkable character in a lobby or shop hub that does not need a full controller.
- **Stealth movers.** A sneak state is just a lower speed - hold a key, call Set Move Speed, release to restore.
- **Power-up driven action games.** Haste pickups, slow traps, and wind zones all become simple speed changes on the fly.
- **Debug and test characters.** A quick "walk around and look at things" body you attach while building a level.

---

## Core concepts

The mental model is tiny. Learn these five ideas and you have the whole pack.

**The node is the mover.** You attach one `EightDirectionMovement` behavior as a child of a `CharacterBody2D`, and that body becomes the thing that moves. There is no "move" action to call and no target id to pass around - the behavior drives the velocity of the body it lives under. Attach it, give the body a collision shape, and it moves.

**Movement is automatic and continuous.** Every physics frame the behavior reads the input, sets the host's velocity, and slides. You never poll input yourself and you never write a "move up" row. Your event sheet only ever changes how fast that automatic movement is.

**Input comes from the four ui actions.** The behavior reads Godot's built-in `ui_left`, `ui_right`, `ui_up`, `ui_down` input actions. Out of the box those are bound to the arrow keys, so arrow-key movement works immediately. If you want WASD, add those keys to the same four actions in Project Settings > Input Map - the behavior picks them up with no code change.

**Move speed is the one knob.** `move_speed` is a value in pixels per second: how far the body travels each second at full stick or full key press. It is an exported Inspector property, so you set a per-node starting value in the editor, and it is the single thing your event sheet tunes at runtime.

**Speed is your state lever.** Because the only thing you change is the speed, every movement state is a speed change. Sprint is a higher speed while a key is held. Slow is a lower speed in mud. Freeze is a speed of 0. You never remove or disable the behavior for these - you set the number.

---

## Setup

**1. Attach the behavior.** Add an `EightDirectionMovement` behavior as a child node of your `CharacterBody2D` (open the pack sheet and use Tools > Attach to Selected Node, or drop the pack node in). The host must be a `CharacterBody2D` and needs a `CollisionShape2D` so it can collide with walls.

**2. Set the Inspector knob.** Select the behavior node and pick a starting speed:

| Property | Default | What it does |
|---|---|---|
| `move_speed` | `200.0` | Speed in pixels per second the host moves at. Exported, so you set the starting value per node in the Inspector. |

**3. Press play.** The arrow keys move the body right away. To also support WASD, open Project Settings > Input Map and add the W, A, S, D keys to `ui_up`, `ui_left`, `ui_down`, `ui_right`. Nothing in the behavior changes.

**4. Tune speed from the sheet.** The only thing you author is a speed change when the game needs one. Here is a complete first behavior - a sprint that speeds the player up while a key is held and restores the walk speed on release:

```
On "sprint" pressed
  -> Player | EightDirectionMovement: Set Move Speed  400

On "sprint" released
  -> Player | EightDirectionMovement: Set Move Speed  200
```

Movement itself needs no rows. Registering nothing and pressing an arrow key already walks the body; these two rows just make it run while a key is down.

---

## ACE reference

The pack's ACEs live under the **Eight Direction** group in the picker and target the `EightDirectionMovement` behavior on the node they are placed on. There is no target id parameter anywhere - the row acts on the body it sits under.

### Actions

| Action | Parameters | Description |
|---|---|---|
| Set Move Speed | `speed` (float) | Sets the movement speed in pixels per second - the value the behavior uses every physics frame from now on. |
| Add To Move Speed | `amount` (float) | Adds to the current move speed (temporary boosts, gradual ramp-ups). |
| Subtract From Move Speed | `amount` (float) | Subtracts from the current move speed (slows, drains, friction). |

### Conditions

Eight Direction defines no conditions of its own. To branch on movement, compare the **Move Speed** expression in a normal condition row (for example, `Move Speed > 0` to test whether the character can move), or use the engine's built-in input and physics conditions.

### Expressions

| Expression | Parameters | Returns | Description |
|---|---|---|---|
| Move Speed | (none) | float | The current movement speed in pixels per second (the last value set or nudged). |

### Triggers

Eight Direction defines no triggers of its own. React to movement with the built-in sheet events instead - `On Ready` to set a starting speed, key-pressed and key-released events for sprint or sneak, area-entered and area-exited events for zones that change speed, and `Every N seconds` for ramps and drains.

### Inspector properties

| Property | Type | Default | What it does |
|---|---|---|---|
| `move_speed` | float | `200.0` | Speed in pixels per second the host moves at. Exported, so each node can start at its own speed from the Inspector, and the sheet retunes it at runtime. |

---

## Use cases

Each example targets the `EightDirectionMovement` behavior on the named node. Movement is automatic - these rows only change the speed in response to gameplay.

### 1. Sprint while a key is held

Speed up when the sprint key is down and drop back to the walk speed when it is released.

```
On "sprint" pressed
  -> Player | EightDirectionMovement: Set Move Speed  400

On "sprint" released
  -> Player | EightDirectionMovement: Set Move Speed  200
```

### 2. Slow to a crawl in water

Enter a water area and the character wades; leave it and normal speed returns.

```
On Player enters Area "Water"
  -> Player | EightDirectionMovement: Set Move Speed  80

On Player exits Area "Water"
  -> Player | EightDirectionMovement: Set Move Speed  200
```

### 3. Speed pickup

Grabbing a boots pickup adds a flat amount to the current speed instead of overwriting it, so it stacks with whatever state the player is in.

```
On Player enters Area "SpeedBoots"
  -> Player | EightDirectionMovement: Add To Move Speed  100
  -> SpeedBoots: queue_free
```

### 4. Injury slows you down

Taking a leg wound subtracts from the speed, and it stays reduced until you heal.

```
On "leg_wounded" (signal)
  -> Player | EightDirectionMovement: Subtract From Move Speed  60
```

### 5. Freeze during a cutscene

Set the speed to 0 to lock the character in place while a scene plays, then restore it when control returns. The body still exists and still collides - it just stops responding to input.

```
On Cutscene Start
  -> Player | EightDirectionMovement: Set Move Speed  0

On Cutscene End
  -> Player | EightDirectionMovement: Set Move Speed  200
```

### 6. Haste potion with a timer

Drink the potion for a burst of speed, and a wait restores the normal walk speed a few seconds later.

```
On "drink_haste" (signal)
  -> Player | EightDirectionMovement: Set Move Speed  450
  -> Wait 5 seconds
  -> Player | EightDirectionMovement: Set Move Speed  200
```

### 7. Difficulty or upgrade scaling at spawn

Set the base speed once on ready from a stat, so a fast-build character or an easy difficulty starts quicker without touching the Inspector.

```
On Ready
  -> Player | EightDirectionMovement: Set Move Speed  180 + PlayerStats.agility * 8
```

### 8. Conveyor or wind zone

A wind zone adds speed on the way in and subtracts the same amount on the way out, so the character leaves the zone exactly as it entered.

```
On Player enters Area "WindZone"
  -> Player | EightDirectionMovement: Add To Move Speed  120

On Player exits Area "WindZone"
  -> Player | EightDirectionMovement: Subtract From Move Speed  120
```

### 9. Stamina drain lowers your top speed

Map remaining stamina to the speed on a timer, so a tired character moves slower as the bar empties.

```
Every 0.25 seconds
  -> Player | EightDirectionMovement: Set Move Speed  120 + Player.stamina / Player.max_stamina * 160
```

### 10. Encumbrance from carried weight

Heavier inventory means a slower walk. Recompute the speed whenever the load changes.

```
On "inventory_changed" (signal)
  -> Player | EightDirectionMovement: Set Move Speed  clamp(220 - Inventory.total_weight * 4, 60, 220)
```

### 11. Show current speed on a debug label

Read the Move Speed expression into a HUD label so you can see the effect of every change while tuning.

```
Every 0.1 seconds
  -> DebugLabel: set text  "Speed: " + str(Player | EightDirectionMovement: Move Speed)
```

### 12. Footstep sound only when actually moving

Gate a repeating footstep sound on the speed being above zero, so a frozen character stays silent.

```
Every 0.4 seconds
  Condition: [Expression] Player | EightDirectionMovement  Move Speed  >  0
    -> Audio: play "footstep"
```

### 13. Gradual ramp-up from a standstill

Instead of snapping to full speed, add a little each tick up to a cap so the character eases into a sprint.

```
On "sprint" pressed
  -> Player | EightDirectionMovement: Set Move Speed  120

Every 0.1 seconds
  Condition: "sprint" is down
  Condition: [Expression] Player | EightDirectionMovement  Move Speed  <  400
    -> Player | EightDirectionMovement: Add To Move Speed  40
```

### 14. Slippery decel on ice

On leaving ice, bleed the extra speed back down over time by subtracting a small amount each tick until the walk speed returns.

```
On Player exits Area "Ice"
  Repeat until walk speed:
  Every 0.1 seconds
    Condition: [Expression] Player | EightDirectionMovement  Move Speed  >  200
      -> Player | EightDirectionMovement: Subtract From Move Speed  20
```

---

## Tips and common mistakes

- **The host must be a `CharacterBody2D`.** The behavior grabs its parent as a `CharacterBody2D` and warns if it is not one. Attach it under the body, and give that body a `CollisionShape2D` so wall collisions work - move-and-slide needs a shape to slide against.
- **There is no "Move" action - movement is automatic.** Do not go looking for an action to make the character walk. The behavior moves the body from input every physics frame on its own. The only thing you author is the speed.
- **Speed is in pixels per second.** Around 200 reads as a brisk walk; a few hundred is a run. Tune by feel in the Inspector first, then override from the sheet only where a state needs it.
- **Arrow keys work out of the box; WASD does not until you add it.** The behavior reads `ui_left`, `ui_right`, `ui_up`, `ui_down`. Those are arrow keys by default - add W, A, S, D to the same four actions in the Input Map if you want them.
- **Freeze by setting the speed to 0, do not remove the behavior.** For cutscenes, dialogue, or a pause, Set Move Speed to 0 and restore it afterward. Removing or re-adding the behavior is more work and loses your tuned speed.
- **Reverse temporary changes you make with Add or Subtract.** Add To Move Speed and Subtract From Move Speed stack on the current value, so a zone that adds 120 on enter must subtract 120 on exit. If you only ever add, the speed drifts upward forever.
- **One behavior per body.** The behavior owns the host's velocity every frame. Do not attach two - they would fight over the same body. One character, one Eight Direction.
- **It overwrites velocity every physics frame.** Because the behavior sets the host velocity from input each tick, writing to that same velocity elsewhere (a knockback, a manual dash) gets erased on the next frame. Do those effects by changing the move speed, or by briefly setting the speed to 0 and moving the body another way.
- **The Move Speed expression is the value you set, not the on-screen speed.** It reports the last Set, Add, or Subtract result. If the body is pressed against a wall it may be traveling slower than that number - Move Speed still reads the configured value.
