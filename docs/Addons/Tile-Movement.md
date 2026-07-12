# Tile Movement - Grid-Locked Stepping, One Tile at a Time

Tile Movement is a Godot EventSheets behavior pack for grid-locked movement. It is a per-node `TileMovementBehavior` you attach as a child of the `Node2D` you want to move (a player, an enemy, a pushable block), and that parent becomes the host it drives. There is no autoload and no "mover id" to pass around: every Action, Expression, and Trigger targets the behavior living on the node you drop it on. Each move steps the host exactly one tile - `Tile Size` pixels - and slides smoothly into place over `Move Time` seconds instead of snapping. Arrow keys drive it out of the box, or you feed it directions yourself with `Simulate Step` (touch buttons, custom keys, or AI). Every time the host finishes sliding into a new cell it fires `On Step Finished`, a single clean hook for footsteps, step counters, and per-tile terrain checks. `Teleport To Tile` snaps to a grid coordinate instantly when you need to place or respawn.

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

- **Roguelikes and dungeon crawlers.** The hero steps cell by cell through a grid map, one tile per press, with a smooth slide between cells.
- **Sokoban and block-pushing puzzles.** Everything lives on the grid, so player and boxes always land dead-center on a cell.
- **Top-down RPG overworlds.** Classic four-direction town and field movement that stays snapped to the tilemap.
- **Turn-based tactics.** Units advance one tile at a time, and `On Step Finished` marks the end of each move for turn logic.
- **Bomberman-style arenas.** Grid movement with no diagonals is exactly the feel these games want.
- **Snake-like and grid-crawler prototypes.** Feed directions with `Simulate Step` and let the behavior handle the stepping.
- **Retro four-direction adventures.** Horizontal-beats-vertical stepping gives that deliberate, no-diagonal old-school movement.
- **Mobile touch games.** Wire an on-screen D-pad to `Simulate Step` and step one tile per tap.
- **Grid AI.** Give enemies the same behavior and step them on a timer or toward the player, sharing the player's grid.
- **Farming and life sims.** The character walks tile to tile across plots and rooms without ever standing between cells.
- **Board and cursor navigation.** Move a selector across a grid of cells with clean, snapped stops.
- **Placement and respawn.** `Teleport To Tile` drops or resets any host onto an exact grid cell with no pixel math.

---

## Core concepts

The model is small. Learn these ideas and the rest is just wiring.

**One tile per step.** Each move shifts the host by exactly one grid cell, which is `Tile Size` pixels wide. There are no half-steps and no free-roam pixels - the host always ends on a cell.

**Steps slide, they do not snap.** A step is not instant. The host glides from its current cell to the next over `Move Time` seconds. When it arrives, `On Step Finished` fires. Lower `Move Time` feels crisp and arcadey; higher feels floaty.

**One axis at a time - no diagonals.** If a horizontal and a vertical move are requested together, horizontal wins and the vertical is dropped. This is deliberate, and it gives clean four-direction movement.

**Locked while moving.** You cannot start a new step while one is still sliding. A direction requested mid-slide is held and taken on the next free frame, so a held key produces a steady stream of single-tile steps rather than a blur.

**Arrow keys by default.** With `Default Controls` on (the default), the behavior reads `ui_left`, `ui_right`, `ui_up`, and `ui_down` for you - attach it and the host moves with no event rows at all. Turn `Default Controls` off when you want to drive movement yourself.

**Simulate Step is your control hook.** Feed it `"left"`, `"right"`, `"up"`, or `"down"` from buttons, touch, swipes, or AI. It queues that step, consumed on the next frame the host is not already mid-step. This is how you build a custom controller once the built-in keys are off.

**Tiles versus pixels.** `Tile Size` is the cell size in pixels, and the host's position is in pixels. `Teleport To Tile` takes grid coordinates (cell 3, cell 5) and multiplies them by `Tile Size` to get the pixel spot, so you never do that math yourself.

**The behavior moves its parent.** It writes the host's position directly, and the host must be a `Node2D` (a `Sprite2D`, `CharacterBody2D`, or any Node2D-derived node). Attach one behavior per moving object.

---

## Setup

**1. Attach the behavior.** Add a `TileMovementBehavior` as a child node of the `Node2D` you want to move (open the pack sheet and use Tools > Attach to Selected Node, or drop the pack node in as a child). One behavior per moving object - each mover gets its own.

**2. Set the Inspector knobs.** Select the behavior node and match it to your game:

| Property | Default | What it does |
|---|---|---|
| `tile_size` | `64.0` | Grid cell size in pixels. One step moves the host this far. Match it to your TileMap cell size. |
| `move_time` | `0.15` | Seconds one tile step takes to slide. Lower is snappier, higher is floatier. Keep it above zero. |
| `default_controls` | `true` | When on, arrow keys (`ui_left` / `ui_right` / `ui_up` / `ui_down`) drive stepping automatically. Turn off to control movement yourself. |

**3. Move.** With `default_controls` on, that is the whole setup - the arrow keys already step the host one tile at a time. Here is a first sheet that matches the grid to a 32 px map and reacts to each landed tile:

```
On Ready
  -> Player | Tile Movement: Set Tile Size  32
  -> Player | Tile Movement: Set Move Time  0.12

On Step Finished
  -> Player: play "footstep" sound
```

Nothing wires the arrow keys because `default_controls` does it for you. When you want a custom controller instead (touch, WASD, AI), set `default_controls` off and feed directions with `Simulate Step`.

---

## ACE reference

All ACEs live in the **Tile Movement** category and act on the `TileMovementBehavior` attached to the node you place them on. In the snippets below, the `Player | Tile Movement:` prefix is how a row targets the behavior on the Player node - swap in whichever node carries the behavior.

### Actions

| Action | Parameters | Description |
|---|---|---|
| Simulate Step | `direction` (String: `left`, `right`, `up`, `down`) | Queues one tile step in a direction. It is consumed on the next frame the host is not already mid-step, so a step requested during a slide is taken when the current tile lands. |
| Teleport To Tile | `tile_x` (float), `tile_y` (float) | Snaps the host instantly to grid cell (`tile_x`, `tile_y`). The coordinates are multiplied by tile size to get the pixel position, and any step in progress is cancelled. |
| Set Tile Size | `value` (float) | Sets the grid cell size in pixels, which is how far one step moves. Takes effect on the next step. |
| Add To Tile Size | `amount` (float) | Increases the tile size by `amount`. |
| Subtract From Tile Size | `amount` (float) | Decreases the tile size by `amount`. |
| Set Move Time | `value` (float) | Sets how many seconds one tile step takes to slide. Lower is snappier, higher is floatier. |
| Add To Move Time | `amount` (float) | Increases the step duration by `amount` (a slower, floatier feel). |
| Subtract From Move Time | `amount` (float) | Decreases the step duration by `amount` (a snappier feel). |
| Set Default Controls | `value` (bool) | Turns the built-in arrow-key control on or off. Set it off before driving movement with Simulate Step. |

### Conditions

| Condition | Parameters | Description |
|---|---|---|
| (none) | - | This pack ships no dedicated condition ACEs. To branch on its state, drop one of the expressions below into a comparison condition (for example `Player | Tile Movement: Move Time` `>` `0.2`), or react to the `On Step Finished` trigger. |

### Expressions

| Expression | Parameters | Returns | Description |
|---|---|---|---|
| Tile Size | (none) | float | The current grid cell size in pixels. |
| Move Time | (none) | float | The current seconds-per-step. |
| Default Controls | (none) | bool | Whether built-in arrow-key control is currently on. |

### Triggers

| Trigger | Fires when |
|---|---|
| On Step Finished | The host finishes sliding into a new tile. Fires once per completed step (so a held key fires it repeatedly, one per landed tile). |

### Inspector properties

| Property | Type | Default | What it does |
|---|---|---|---|
| `tile_size` | float | `64.0` | Grid cell size in pixels; one step moves this far. Also readable as the `Tile Size` expression and settable with `Set Tile Size`. |
| `move_time` | float | `0.15` | Seconds a single tile step takes to slide. Also readable as the `Move Time` expression and settable with `Set Move Time`. |
| `default_controls` | bool | `true` | When on, arrow keys drive stepping automatically. Also readable as the `Default Controls` expression and settable with `Set Default Controls`. |
| `ai_controlled` | bool | `false` | AI drive: read the held `ai_move_x`/`ai_move_y` intents instead of the arrow keys - a sheet or AI driver steps the host with the player's exact feel (see docs/GUIDE-PLAYER-AND-AI-INPUT.md). |

---

## Use cases

Each example acts on the `TileMovementBehavior` attached to the named node. With `default_controls` on you often need no rows at all; turn it off when you want a custom controller.

### 1. Zero-setup arrow-key hero

Attach the behavior to your player and it just works - arrow keys step one tile at a time. Match the grid and taste in one event.

```
On Ready
  -> Player | Tile Movement: Set Tile Size  32
  -> Player | Tile Movement: Set Move Time  0.12
```

With `default_controls` on (the default), there is no input wiring to write.

### 2. On-screen D-pad for touch

Turn off the built-in keys and drive stepping from your own buttons.

```
On Ready
  -> Player | Tile Movement: Set Default Controls  false

On "DpadLeft" Pressed
  -> Player | Tile Movement: Simulate Step  "left"
On "DpadRight" Pressed
  -> Player | Tile Movement: Simulate Step  "right"
On "DpadUp" Pressed
  -> Player | Tile Movement: Simulate Step  "up"
On "DpadDown" Pressed
  -> Player | Tile Movement: Simulate Step  "down"
```

### 3. Custom WASD keys

Same idea for a keyboard remap - disable the defaults, map your own keys to `Simulate Step`.

```
On Ready
  -> Player | Tile Movement: Set Default Controls  false

On "W" Pressed  -> Player | Tile Movement: Simulate Step  "up"
On "A" Pressed  -> Player | Tile Movement: Simulate Step  "left"
On "S" Pressed  -> Player | Tile Movement: Simulate Step  "down"
On "D" Pressed  -> Player | Tile Movement: Simulate Step  "right"
```

### 4. Drop the player on a spawn cell

Place the host on grid coordinates at load with no pixel math - the cell is multiplied by tile size for you.

```
On Ready
  -> Player | Tile Movement: Teleport To Tile  4, 7
```

Cell (4, 7) with a tile size of 64 lands the player at pixel (256, 448).

### 5. Footsteps and dust per tile

`On Step Finished` is one clean hook that fires exactly once per landed tile.

```
On Step Finished
  -> Player: play "footstep" sound
  -> spawn "dust" at Player.global_position
```

### 6. Step counter for a puzzle

Count moves for a turn-based puzzle or a "reach the exit in N steps" goal.

```
On Step Finished
  -> add 1 to Steps
  Condition: Steps  >=  30
    -> show "out of moves"
```

### 7. Snappy versus floaty feel

`move_time` is the whole feel dial. Lower is crisp and arcadey; higher glides.

```
On Ready
  -> Player | Tile Movement: Set Move Time  0.08
```

### 8. Haste powerup

Shorten the step time when a haste pickup is grabbed, then restore it when it wears off.

```
On "HastePickup" Collected
  -> Player | Tile Movement: Subtract From Move Time  0.05

On "HasteExpired"
  -> Player | Tile Movement: Add To Move Time  0.05
```

Adjusting by the same amount both ways keeps the feel exactly where it started.

### 9. Slow mud terrain

Read the tile the player just landed on and stretch the step time on slow ground.

```
On Step Finished
  Condition: TileMap ground at Player.global_position  ==  "mud"
    -> Player | Tile Movement: Set Move Time  0.3
  Condition: TileMap ground at Player.global_position  ==  "path"
    -> Player | Tile Movement: Set Move Time  0.15
```

### 10. Match the behavior to your TileMap cell size

If your map cells are 48 px, set the tile size once so a step lands dead-center on a cell.

```
On Ready
  -> Player | Tile Movement: Set Tile Size  48
```

### 11. Grid AI patrol

Give an enemy the same behavior and step it on a timer for a simple back-and-forth patrol.

```
On Ready
  -> Enemy | Tile Movement: Set Default Controls  false

Every 0.5 seconds
  Condition: PatrolDir  ==  "right"
    -> Enemy | Tile Movement: Simulate Step  "right"
  Condition: PatrolDir  ==  "left"
    -> Enemy | Tile Movement: Simulate Step  "left"
```

Flip `PatrolDir` when the enemy reaches the end of its lane, and it paces cleanly on the grid.

### 12. Grid chase

Step an enemy one tile toward the player after each of its own steps, so it hunts on the same grid. Because horizontal beats vertical, it closes the X gap first, then the Y gap.

```
On Ready
  -> Enemy | Tile Movement: Set Default Controls  false
  -> Enemy | Tile Movement: Simulate Step  "right"

On Step Finished   (Enemy's behavior)
  Condition: Player.global_position.x  >  Enemy.global_position.x
    -> Enemy | Tile Movement: Simulate Step  "right"
  Condition: Player.global_position.x  <  Enemy.global_position.x
    -> Enemy | Tile Movement: Simulate Step  "left"
  Condition: Player.global_position.y  >  Enemy.global_position.y
    -> Enemy | Tile Movement: Simulate Step  "down"
  Condition: Player.global_position.y  <  Enemy.global_position.y
    -> Enemy | Tile Movement: Simulate Step  "up"
```

The first `Simulate Step` kicks off the loop; each landed tile queues the next step toward the player.

### 13. Knockback one tile

Push the player a tile in the hit direction with a single `Simulate Step`.

```
On Player Hit By Enemy
  Condition: HitFromLeft
    -> Player | Tile Movement: Simulate Step  "right"
  Condition: HitFromRight
    -> Player | Tile Movement: Simulate Step  "left"
```

### 14. Respawn at a checkpoint cell

On death, snap instantly back to the last checkpoint's grid cell.

```
On Player Died
  -> Player | Tile Movement: Teleport To Tile  Checkpoint.tile_x, Checkpoint.tile_y
```

`Teleport To Tile` cancels any slide in progress, so the respawn is immediate and on-grid.

### 15. Freeze movement during dialogue

Cut the built-in controls while a conversation is open, then restore them.

```
On Dialogue Started
  -> Player | Tile Movement: Set Default Controls  false

On Dialogue Ended
  -> Player | Tile Movement: Set Default Controls  true
```

### 16. Line a highlight up with the grid

Use the `Tile Size` expression to scale a cell highlight to whatever grid the player is walking.

```
On Step Finished
  -> set Highlight.global_position = Player.global_position
  -> set Highlight.scale = Player | Tile Movement: Tile Size / 64.0
```

---

## Tips and common mistakes

- **The host must be a Node2D.** The behavior moves its parent by writing the host's position, so attach it as a child of a `Node2D` (a `Sprite2D`, `CharacterBody2D`, and so on). If the parent is not a Node2D it warns and does nothing.
- **No diagonals, by design.** If a horizontal and a vertical step are requested at the same instant, horizontal wins and the vertical is dropped. Plan four-direction movement, not eight.
- **One step at a time.** You cannot start a new step while one is sliding - a `Simulate Step` requested mid-slide is buffered until the current tile lands. Do not expect two calls in the same frame to move two tiles at once.
- **Teleport To Tile takes grid coordinates, not pixels.** Pass cell (3, 5), not (192, 320) - it multiplies by tile size for you. It also cancels any step in progress, so use it for placement and respawns, not for nudging a slide.
- **Match Tile Size to your map.** If the behavior's tile size does not equal your TileMap cell size, steps drift off the grid. Set it once at load to the exact cell size in pixels.
- **Turn Default Controls off before driving movement yourself.** Left on, the arrow keys and your own `Simulate Step` calls both fire and fight each other. Set `Default Controls` false first for touch, custom keys, or AI.
- **On Step Finished fires per landed tile, not per key press.** A held key produces a stream of steps and a matching stream of triggers, one each time a tile completes. Use it for footsteps, step counting, and per-tile terrain checks - not for detecting a single button tap.
- **Keep Move Time above zero.** A move time of 0 makes every step snap instantly (the slide divides by it), so use a small positive number like 0.08 for a near-instant but safe feel rather than 0.
- **Changing Tile Size mid-run affects the next step, not the current slide.** Set it while the host is idle so a resize never leaves the host landing on a half-tile.
