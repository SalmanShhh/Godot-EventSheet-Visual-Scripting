# Slide Movement

**Slide Movement** is a per-node `SlideMove` behavior you attach to a Node2D. It gives you grid movement
where a tap sends the character sliding until it slams into a wall - the feel of Tomb of the Mask. Give it
a grid size and tell it which physics layer counts as a wall, then press a direction (or let the arrow
keys drive it): it finds the farthest open tile in that direction, glides there at a constant speed, and
snaps to the grid when it stops. Walls are found with a physics ray, so it works with a TileMap collision
layer or plain StaticBody2D tiles. It is different from the step-per-press Tile Movement behavior, where
each press moves exactly one tile.

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [ACE reference](#ace-reference)
5. [Use cases](#use-cases)
6. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this pack shines

- **Ice-sliding puzzles** - the classic "slide until you hit something" floor.
- **Tomb of the Mask style arcade movers** - fast, snap-to-grid, wall-to-wall dashing.
- **Sokoban-adjacent puzzles** where the player slides rather than steps.
- **Marble or hockey-puck toys** on a tile grid.
- **Roguelike movement variants** with a slide mechanic on certain floors.
- **Maze runners** where momentum carries you to the next junction.
- **Snake-like or trail games** that move in fixed directions until blocked.
- **Grid-based boss arenas** where the player repositions in quick slides.
- **Board-game pieces** that glide to the edge of the board.
- **Mobile swipe games** - map a swipe to a Slide in that direction.

## Core concepts

- **The grid.** Everything snaps to `grid_size` pixels. The character always comes to rest on a tile
  centre.
- **Slide to a wall, not one tile.** A Slide scans ahead tile by tile and stops at the last open tile
  before a wall. If the very next tile is a wall, it does not move and fires On Hit Wall.
- **Walls are a physics layer.** Set Wall Mask to the collision layer your walls use. Detection is a
  ray, so any StaticBody2D or TileMap collision on that layer counts.
- **One slide at a time.** While it is sliding, new Slide calls are ignored; it accepts the next
  direction once it stops.
- **Arrow keys for free.** With Default Controls on, the ui_left / ui_right / ui_up / ui_down actions
  start a slide, so it plays out of the box.

## Setup

Attach a **SlideMove** behavior to a Node2D that has a CollisionShape2D if you want it to be blocked by
solids. Build your walls as a TileMap with collision (or StaticBody2D tiles) on a layer, and set Wall
Mask to that layer.

Arrow-key sliding with a wall-hit sound:

```
Character | SlideMove  (Default Controls = on, Grid Size 64, Wall Mask = your wall layer)
Character On Hit Wall
  -> play a "thud" sound
```

## ACE reference

### Actions

| Action | Parameters | Description |
|--------|-----------|-------------|
| Slide | direction (left/right/up/down) | Starts a slide: the character glides until the tile ahead is a wall, then stops snapped to the grid. Ignored while already sliding; fires On Hit Wall immediately if the next tile is a wall. |
| Stop Slide | (none) | Stops a slide immediately and snaps to the nearest tile. |
| Snap To Grid | (none) | Snaps the character to the nearest grid intersection right now. |
| Teleport To Tile | tile_x, tile_y | Jumps instantly to a tile coordinate (times the grid size), cancelling any slide. |
| Set Grid Size | pixels | Changes the tile size in pixels at runtime. |

### Conditions

| Condition | Parameters | Description |
|-----------|-----------|-------------|
| Is Sliding | (none) | Whether the character is mid-slide. |
| Can Slide | direction | Whether the tile next to the character in that direction is open (not a wall). |

### Expressions

| Expression | Returns | Description |
|-----------|---------|-------------|
| Slide Direction | String | The direction of the current or last slide ("left" / "right" / "up" / "down"). |
| Tile X | int | The character's current column on the grid. |
| Tile Y | int | The character's current row on the grid. |

### Triggers

| Trigger | Description |
|---------|-------------|
| On Slide Started | Fires when a slide begins. |
| On Slide Stopped | Fires when a slide reaches its stopping tile. |
| On Hit Wall | Fires when a slide stops against a wall (and immediately if the next tile was already a wall). |

### Inspector properties

| Property | Default | Description |
|----------|---------|-------------|
| Grid Size | 64.0 | Tile size in pixels; the character snaps to this grid. |
| Slide Speed | 400.0 | Slide speed in pixels per second. |
| Wall Mask | layer 1 | Which physics collision layer counts as a wall. |
| Default Controls | on | Let the arrow keys / ui_* actions start a slide automatically. |
| Max Slide Tiles | 64 | Safety cap on how many tiles a single slide may cross. |
| AI Controlled | off | AI drive: the held `ai_move_x`/`ai_move_y` intents start slides instead of the arrow keys - the dominant axis wins, same as the keys (see docs/GUIDE-PLAYER-AND-AI-INPUT.md). |

## Use cases

**1. Arrow-key sliding (default).** Leave Default Controls on and the player slides with the arrow keys
straight away.

**2. Swipe to slide (mobile).**

```
On swipe left
  -> Player | SlideMove: Slide  "left"
On swipe right
  -> Player | SlideMove: Slide  "right"
```

**3. Wall-hit feedback.**

```
Player On Hit Wall
  -> Camera: small shake
  -> play a thud
```

**4. Count moves for a puzzle par.**

```
Player On Slide Started
  -> add 1 to move_count
```

**5. Collect on arrival.**

```
Player On Slide Stopped
  Condition: a Gem is on tile (Player | SlideMove.Tile X(), Player | SlideMove.Tile Y())
    -> collect the gem
```

**6. Block a direction with a locked gate.**

```
On up pressed
  Condition: Player | SlideMove  Can Slide  "up"
    -> Player | SlideMove: Slide  "up"
  Else
    -> show "locked"
```

**7. Respawn at the start tile.**

```
On player died
  -> Player | SlideMove: Teleport To Tile  1, 1
```

**8. Turn-based feel (disable auto controls).** Turn Default Controls off and call Slide yourself only on
the player's turn.

**9. Speed-up power tile.**

```
Player On Slide Stopped
  Condition: standing on a boost tile
    -> Player | SlideMove: Set Grid Size  64   (or raise Slide Speed in the Inspector)
```

**10. Ice level, larger grid.** Set Grid Size to your ice-tile size so slides land on tile centres.

**11. Show which way you last went.**

```
Every tick
  -> set Arrow frame from Player | SlideMove.Slide Direction()
```

**12. Prevent input while sliding.**

```
On up pressed
  Condition: Player | SlideMove  Is Sliding  (inverted)
    -> Player | SlideMove: Slide  "up"
```

## Tips and common mistakes

- **Set Wall Mask to your walls' collision layer** - with no walls on that layer, a slide runs to the
  Max Slide Tiles cap.
- **Give the character a CollisionShape2D** if you want it to interact physically; the slide detection
  itself uses a ray on the wall layer.
- **This is slide-to-wall, not step-per-tile.** For one-tile-per-press movement, use the Tile Movement
  behavior instead.
- **A slide ignores new directions until it stops.** Check Is Sliding if you want to gate input.
- **The character always rests on a tile centre** - use Snap To Grid after a Teleport if you moved it by
  hand.
- **Max Slide Tiles is a safety cap** for open maps, so a slide never runs forever off the level.
- **Down is +Y** (screen axes), so "down" moves the character toward the bottom of the screen.
