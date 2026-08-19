# Working With Tilemaps

Ten builtin actions, conditions and expressions let event rows read and write a **TileMapLayer**: paint
a tile, erase one, wipe the layer, ask what is in a cell, count what is placed, and convert between
pixel positions and grid coordinates. No pack to enable, no behavior to attach - drop a row on a TileMapLayer sheet (or point any
row at one with **On node**) and it compiles to the exact native call you would have written by hand.

This is the vocabulary behind destructible terrain, dig-and-build games, roguelike level generation,
grid-snapped placement, fog of war, tile-based puzzle boards, and anything else where the world is a
grid rather than a pile of nodes.

## Table of Contents

1. [Where this shines](#where-this-shines)
2. [Core concepts](#core-concepts)
3. [Reference tables](#reference-tables)
4. [Use cases](#use-cases)
5. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this shines

- **Destructible terrain** - an explosion erases the cells inside its radius.
- **Dig and build** - the player mines a tile out and places one back.
- **Procedural levels** painted cell by cell from a generation loop.
- **Grid-snapped placement** - the cursor's pixel position becomes a cell, and the preview snaps.
- **Tile-based puzzles** where the board state IS the tilemap.
- **Fog of war** on a second layer that gets erased as the player explores.
- **Farming and growth** - a crop tile swapped for the next stage of its atlas.
- **Doors and switches** that swap one tile for another.
- **Level resets** with a single Clear Tilemap row.
- **Progress readouts** driven by how many cells still hold a tile.

## Core concepts

- **The host is a TileMapLayer.** These rows target Godot's `TileMapLayer` node (Godot 4.3 and later),
  where each layer is its own node. The legacy `TileMap` node took a layer index argument that these
  rows deliberately omit. A tilemap with three layers is three TileMapLayer nodes, and you point a row
  at whichever one you mean.
- **A cell is a Vector2i.** Every coordinate parameter is a grid coordinate written as a Vector2i
  expression, e.g. `Vector2i(3, -2)`. They are integers and they can be negative; the grid extends in
  every direction from the origin.
- **A tile is a source plus an atlas coordinate.** **Source** is the id of a tile source inside the
  layer's TileSet (usually `0` when there is a single source), and **Atlas Coords** is which tile inside
  that source's image you want, again as a Vector2i. Both are visible in the TileSet editor.
- **Empty is source id -1.** That single convention drives Cell Is Empty, Cell Has Tile and Cell Source
  Id: a cell with nothing in it reads back -1, which is also what an out-of-bounds cell reads.
- **Local space, not global.** Local To Map and Map To Local convert against the layer's OWN coordinate
  space. If you are holding a global position (a mouse position, another node's `global_position`),
  convert it to the layer's local space first.
- **Map To Local gives you a cell's centre**, not its corner, which is exactly what you want for placing
  a sprite or a marker on a tile.
- **Everything is node-scoped, so everything carries On node.** Left blank, a row acts on the host
  TileMapLayer and compiles to the bare call in the Ships-as column. Filled in, the same call is prefixed
  with the node you picked, so one sheet can paint several layers.

## Reference tables

The **Ships as** column is the emitted GDScript with **On node** left blank.

### Actions - writing cells

| Name | What it does | Ships as |
|------|--------------|----------|
| Set Cell | Paints a tile at a grid cell using a tile source and atlas position. | `set_cell({coords}, {source_id}, {atlas_coords})` |
| Erase Cell | Clears the tile at a single grid cell, leaving it empty. | `erase_cell({coords})` |
| Clear Tilemap | Wipes every tile from the tilemap layer, leaving it blank. | `clear()` |

### Conditions - asking about a cell

| Name | What it does | Ships as |
|------|--------------|----------|
| Cell Is Empty | True when the chosen tilemap cell has no tile in it. | `get_cell_source_id({coords}) == -1` |
| Cell Has Tile | True when the chosen tilemap cell actually has a tile placed. | `get_cell_source_id({coords}) != -1` |

### Expressions - reading the grid

| Name | What it does | Ships as |
|------|--------------|----------|
| Cell Source Id | Returns the tile source ID at a cell, or -1 when empty. | `get_cell_source_id({coords})` |
| Cell Atlas Coords | Returns which tile in the atlas sits at the given cell. | `get_cell_atlas_coords({coords})` |
| Used Cells Count | Returns how many cells in the tilemap currently hold a tile. | `get_used_cells().size()` |
| Local To Map | Converts a pixel position into the cell coordinates that contain it. | `local_to_map({pos})` |
| Map To Local | Converts cell coordinates into the pixel position at that cell's center. | `map_to_local({coords})` |

## Use cases

**1. Paint one tile.** Source 0, the first tile of its atlas, at the origin.

```gdscript
extends TileMapLayer


func _ready() -> void:
	set_cell(Vector2i(0, 0), 0, Vector2i(0, 0))
```

**2. Dig a tile out.** Erase Cell leaves the cell genuinely empty, so Cell Is Empty is true afterwards.

```gdscript
extends TileMapLayer


func _ready() -> void:
	erase_cell(Vector2i(3, 2))
```

**3. Turn the mouse into a cell.** The mouse position is global, so bring it into the layer's space
first, then convert.

```
Every Frame
  -> Set value  hovered_cell = Local To Map( to_local(get_global_mouse_position()) )
```

**4. Snap a placement preview to the grid.** Map To Local hands back the centre of the cell, which is
where the ghost sprite belongs.

```
Every Frame
  -> Set Property  Ghost.position = Map To Local(hovered_cell)
```

**5. Only build on empty ground.** Cell Is Empty is the guard that stops the player stacking towers.

```
On build pressed
  Condition: Cell Is Empty  hovered_cell
    -> Set Cell  hovered_cell, source 0, atlas Vector2i(2, 0)
  Else
    -> Print  "Something is already there"
```

**6. Only mine where there is something to mine.**

```
On dig pressed
  Condition: Cell Has Tile  hovered_cell
    -> Erase Cell  hovered_cell
    -> Add to  ore += 1
```

**7. Swap one tile for another.** A closed door becomes an open door: same cell, different atlas
coordinate.

```
On switch pressed
  -> Set Cell  Vector2i(8, 4), source 0, atlas Vector2i(5, 1)
```

**8. Tell tile types apart.** Cell Atlas Coords is the identity of what is in a cell, so branching on it
is how "is this water?" is answered without a second data structure.

```
On player entered cell
  Condition: Cell Atlas Coords(player_cell) = Vector2i(0, 3)
    -> Set value  in_water = true
```

**9. Tell layers apart with Cell Source Id.** With two tile sources in one TileSet (terrain and props,
say), the source id says which family a placed tile belongs to.

```
On inspect pressed
  Condition: Cell Source Id(hovered_cell) = 1
    -> Print  "That is a prop, not terrain"
```

**10. Blow a hole in the wall.** Explosions read as a loop of Erase Cell rows over the cells inside the
radius.

```
On bomb exploded
  For Each  cell in blast_cells
    -> Erase Cell  cell
```

**11. Reset the level in one row.**

```
On restart pressed
  -> Clear Tilemap
```

**12. Paint a procedural floor.** A nested loop of Set Cell rows is a complete level generator.

```
On Ready
  Repeat 20 times  (as x)
    Repeat 12 times  (as y)
      -> Set Cell  Vector2i(x, y), source 0, atlas Vector2i(1, 0)
```

**13. A progress bar for a mining game.** Used Cells Count falls as the player digs, so the fraction is
free.

```
Every Frame
  -> Set Property  DigBar.value = 100.0 - Used Cells Count * 100.0 / starting_cells
```

**14. Detect that a layer is empty.** Used Cells Count reaching 0 is the win condition for a clear-the-
board puzzle.

```
On cell erased
  Condition: Used Cells Count = 0
    -> Print  "Board cleared"
```

**15. Erase fog as the player walks.** Fog is its own TileMapLayer, so the erase row points at it with
On node while the sheet lives on the player.

```
Every Frame
  -> Erase Cell  Local To Map( FogLayer.to_local(global_position) )   On node: FogLayer
```

**16. Grow a crop through its stages.** Each growth tick moves the atlas coordinate one step along the
row.

```
On growth tick
  -> Set Cell  crop_cell, source 0, atlas Vector2i(stage, 4)
```

**17. Paint on one layer and read from another.** Two rows, two On node targets, one sheet - a collision
layer that is written from what the decoration layer contains.

```
On Ready
  Condition: Cell Has Tile  Vector2i(4, 4)   On node: DecorLayer
    -> Set Cell  Vector2i(4, 4), source 0, atlas Vector2i(0, 0)   On node: CollisionLayer
```

**18. Place a node exactly on a tile.** Map To Local plus the layer's own transform is how a spawned
enemy lands centred in its cell.

```
On spawn enemy
  -> Set Property  Enemy.position = Map To Local(spawn_cell)
```

### Other use cases

**Minesweeper board.** Store the mine positions as cells, use Set Cell to reveal a number tile on click, and let Cell Has Tile answer "already revealed" with no parallel array to keep in sync.

**Auto-tiling by hand.** Read the four neighbouring cells with Cell Has Tile and pick the atlas coordinate that matches the pattern, which gives you a corner-aware wall set without a terrain set.

**Save a level as cells.** Walk the grid with Cell Source Id and Cell Atlas Coords into a dictionary, and rebuild it later with Set Cell rows - a level editor whose save format you fully control.

**Conveyor belts and pipes.** The atlas coordinate encodes direction, so reading Cell Atlas Coords under the moving object tells it which way to travel next.

**Damage stages on terrain.** One tile per damage level in the same atlas row; each hit moves the cell one step along, and the last hit erases it entirely.

## Tips and common mistakes

- **Local To Map wants LOCAL space.** Handing it a global position (mouse or `global_position`) works
  perfectly until the layer is moved or the camera scrolls, and then everything is silently off by the
  layer's offset. Convert with `to_local(...)` first, every time.
- **Source and atlas are two different numbers and both matter.** Source is which tile sheet, atlas is
  which tile in it. A wrong source id paints nothing and reports no error.
- **An out-of-bounds cell reads as empty, not as an error.** Cell Source Id returns -1 for anything not
  placed, so Cell Is Empty cannot tell "outside the level" from "inside but blank". Bound-check with
  your own variables when that distinction matters.
- **Coordinates are integers.** A Vector2 with fractional parts is not a cell. Local To Map does the
  rounding for you; typing coordinates by hand does not.
- **Map To Local returns the cell's CENTRE.** If a placed sprite looks half a tile off, you probably
  wanted the centre and are compensating for a corner, or the sprite's own origin is at its top-left.
- **Clear Tilemap wipes the whole layer.** There is no undo at runtime and no partial form; to clear a
  region, loop Erase Cell over it.
- **Used Cells Count builds an array every call.** It emits `get_used_cells().size()`, which allocates
  the full list of used cells each time. That is fine on an event, and wasteful inside a per-frame row
  on a large map - cache it in a variable and update it when you actually change a cell.
- **These are TileMapLayer rows.** On a project still using the legacy TileMap node they will not
  appear in the picker, because the picker scopes by node type.
- **Erase Cell is not Set Cell with source -1.** Use Erase Cell; it is the action that exists and the one
  the emitted code reads clearest as.
- **On node lets one sheet drive several layers**, and a blank On node compiles byte-for-byte to the bare
  host call - so adding a target later never disturbs the rows around it.
