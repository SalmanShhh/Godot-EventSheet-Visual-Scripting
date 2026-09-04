# Working With Tilemaps

Thirty builtin actions, conditions and expressions let event rows read and write a **TileMapLayer**: paint
a tile, erase one, wipe the layer, ask what is in a cell, count what is placed, and convert between
pixel positions and grid coordinates - and then ask the harder questions a level gets asked, paint a
terrain that joins its own edges up, and move a layer's own bytes to and from a file. Six more say the
same things on a **GridMap**, which is that grid with one more axis. No pack to enable, no behavior to
attach - drop a row on a TileMapLayer sheet (or point any
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
- **Local space, not global.** Position To Tile and Tile To Position convert against the layer's OWN coordinate
  space. If you are holding a global position (a mouse position, another node's `global_position`),
  convert it to the layer's local space first.
- **Tile To Position gives you a cell's centre**, not its corner, which is exactly what you want for placing
  a sprite or a marker on a tile.
- **Everything is node-scoped, so everything carries On node.** Left blank, a row acts on the host
  TileMapLayer and compiles to the bare call in the Ships-as column. Filled in, the same call is prefixed
  with the node you picked, so one sheet can paint several layers.

## Reference tables

The **Ships as** column is the emitted GDScript with **On node** left blank.

### Actions - writing cells

| Name | What it does | Ships as |
|------|--------------|----------|
| Set Tile | Paints a tile at a grid cell using a tile source and atlas position. | `set_cell({coords}, {source_id}, {atlas_coords})` |
| Erase Tile | Clears the tile at a single grid cell, leaving it empty. | `erase_cell({coords})` |
| Clear Tilemap | Wipes every tile from the tilemap layer, leaving it blank. | `clear()` |

### Conditions - asking about a cell

| Name | What it does | Ships as |
|------|--------------|----------|
| Cell Is Empty | True when the chosen tilemap cell has no tile in it. | `get_cell_source_id({coords}) == -1` |
| Cell Has Tile | True when the chosen tilemap cell actually has a tile placed. | `get_cell_source_id({coords}) != -1` |
| Tile Has Custom Data | True when the tile at a cell carries the named custom data - how a tileset marks walls, water or ladders. | `get_cell_tile_data({coords}) != null and get_cell_tile_data({coords}).get_custom_data({name})` |

These are the words an opened `.gd` file reads in too. A hand-written `tilemap.set_cell(0, cell, 1,
Vector2i(2, 0))` reads as **Set tile at cell to 2, 0** with `layer 0 · tileset 1` said quietly after
it, `local_to_map(p)` reads as `tilemap.PositionToTile(p)`, and the two lines a script spells a
custom-data check over - the `get_cell_tile_data` local and the `if data and
data.get_custom_data("solid")` that follows it - read as the one **tile at cell has solid set**
condition above. Both node generations answer alike: the older `TileMap` node names its layer in
front of the cell, and the reading says which layer behind the sentence rather than inside it.

### Expressions - reading the grid

| Name | What it does | Ships as |
|------|--------------|----------|
| Tile At | Returns the tile source ID at a cell, or -1 when empty. | `get_cell_source_id({coords})` |
| Cell Atlas Coords | Returns which tile in the atlas sits at the given cell. | `get_cell_atlas_coords({coords})` |
| Used Cells Count | Returns how many cells in the tilemap currently hold a tile. | `get_used_cells().size()` |
| Position To Tile | Converts a pixel position into the cell coordinates that contain it. | `local_to_map({pos})` |
| Tile To Position | Converts cell coordinates into the pixel position at that cell's center. | `map_to_local({coords})` |

### The questions a level is asked

Each of these is three or four engine calls written by hand. The ones that need more than one call
compile to a shared helper the compiler writes into your file the first time any row asks for it, and
appends after everything else, so nothing above it moves.

| Name | What it does | Ships as |
|------|--------------|----------|
| Tile Data At | What the tile at a place carries under one of the tileset's custom data layers. Answers null where there is no tile. | `__eventsheets_tile_data_at(self, {where}, {key})` |
| Tile Data At Is | True when the tile at a place carries this value under the named custom data layer. | `__eventsheets_tile_data_at(self, {where}, {key}) == {value}` |
| Cell Is Solid | True when the tile at a cell carries a collision shape on the tileset physics layer you name. | `__eventsheets_cell_is_solid(self, {cell}, {layer})` |
| First Solid Cell Along | Walks the cells along a line and answers the first solid one, with no physics query at all. `Vector2i.MAX` when the line met nothing. | `__eventsheets_first_solid_cell(self, {from}, {to}, {layer})` |
| Surrounding Cells Of | The cells that touch a cell, asked of the LAYER - so a hex map answers with six. | `get_surrounding_cells({cell})` |
| Cells With Data | Every cell whose tile carries this value under the named custom data layer, as a list. | `__eventsheets_cells_with_data(self, {key}, {value})` |
| Used Rect | The rectangle of cells the layer actually holds tiles in, as a Rect2i. | `get_used_rect()` |
| Cell Count Of | How many cells hold one particular tile. | `get_used_cells_by_id({source_id}, {atlas_coords}).size()` |
| Tile Under | Which cell a node stands on, through the layer's own transform. | `self.local_to_map(self.to_local({node}.global_position))` |

### The words that change it

| Name | What it does | Ships as |
|------|--------------|----------|
| Paint Terrain | Paints a list of cells with one terrain and lets the tileset choose each tile, so edges and joins draw themselves. | `set_cells_terrain_connect({cells}, {terrain_set}, {terrain})` |
| Repaint Terrain Around | Runs the terrain join again over the cells around a place, so a crater's rim heals itself. | `self.set_cells_terrain_connect(__eventsheets_cells_around(self, {where}, {radius}), {terrain_set}, {terrain})` |
| Fill Rect With Tile | Paints every cell of a rectangle with one tile. | `__eventsheets_fill_tile_rect(self, {rect}, {source_id}, {atlas_coords})` |
| Erase Tiles In Circle | Clears every cell within so many cells of a place. | `__eventsheets_erase_tiles_in_circle(self, {where}, {radius})` |
| Flood Fill | The paint bucket, stopped by the row's own cell limit so a fill on open ground cannot run away. | `__eventsheets_flood_fill_tiles(self, {cell}, {source_id}, {atlas_coords}, {limit})` |
| Set Navigation On Layer | Turns the layer's navigation regions on or off - what a door opening has to do before agents route through it. | `navigation_enabled = {on}` |
| Set Collision On Layer | Turns the layer's collision on or off. | `collision_enabled = {on}` |

### The level as a file

| Name | What it does | Ships as |
|------|--------------|----------|
| Save Layer To File | Writes the layer's tiles to a file, exactly as the engine stores them. | `__eventsheets_save_tile_layer(self, {path})` |
| Load Layer From File | Puts the tiles from a file back onto the layer. A file that is not there leaves the layer alone. | `__eventsheets_load_tile_layer(self, {path})` |
| Copy Layer | Copies every tile of one layer onto another in one go. A level editor's undo is two of these. | `self.tile_map_data = {from}.tile_map_data` |

### The 3D twin - GridMap

A GridMap is a MeshLibrary laid out on a 3D grid, and the six words here are the words their 2D twins
use, so a reader who learned one knows the other. Cells are `Vector3i`.

**What has no twin, said rather than faked:** a GridMap has no tileset, so it has no custom data layers
and no terrains. Tile Data At, Cells With Data, Paint Terrain and Repaint Terrain Around are 2D words
and stay 2D words - a 3D game that wants "which cells are lava" keeps that in a collection or a group,
the way it would for any other 3D scenery.

| Name | What it does | Ships as |
|------|--------------|----------|
| Set Cell Item | Puts one item of the mesh library into a grid cell, turned the way you say. The twin of Set Tile. | `set_cell_item({cell}, {item}, {orientation})` |
| Item At | Which item sits in a cell, by its index, or -1 when the cell is empty. The twin of Tile At. | `get_cell_item({cell})` |
| Cell Is Filled | True when the grid cell holds an item. The twin of Cell Has Tile. | `get_cell_item({cell}) != GridMap.INVALID_CELL_ITEM` |
| Used Cells | Every cell of the grid that holds an item, as a list of Vector3i. | `get_used_cells()` |
| Fill Box | Puts one item into every cell of a box of grid cells. The two corners may be given in any order. | `__eventsheets_gridmap_fill_box(self, {from}, {to}, {item})` |
| Erase Box | Clears every cell of a box, which is the same call with the invalid item. | `__eventsheets_gridmap_fill_box(self, {from}, {to}, GridMap.INVALID_CELL_ITEM)` |

## Use cases

**1. Paint one tile.** Source 0, the first tile of its atlas, at the origin.

```gdscript
extends TileMapLayer


func _ready() -> void:
	set_cell(Vector2i(0, 0), 0, Vector2i(0, 0))
```

**2. Dig a tile out.** Erase Tile leaves the cell genuinely empty, so Cell Is Empty is true afterwards.

```gdscript
extends TileMapLayer


func _ready() -> void:
	erase_cell(Vector2i(3, 2))
```

**3. Turn the mouse into a cell.** The mouse position is global, so bring it into the layer's space
first, then convert.

```
Every Frame
  -> Set value  hovered_cell = Position To Tile( to_local(get_global_mouse_position()) )
```

**4. Snap a placement preview to the grid.** Tile To Position hands back the centre of the cell, which is
where the ghost sprite belongs.

```
Every Frame
  -> Set Property  Ghost.position = Tile To Position(hovered_cell)
```

**5. Only build on empty ground.** Cell Is Empty is the guard that stops the player stacking towers.

```
On build pressed
  Condition: Cell Is Empty  hovered_cell
    -> Set Tile  hovered_cell, source 0, atlas Vector2i(2, 0)
  Else
    -> Print  "Something is already there"
```

**6. Only mine where there is something to mine.**

```
On dig pressed
  Condition: Cell Has Tile  hovered_cell
    -> Erase Tile  hovered_cell
    -> Add to  ore += 1
```

**7. Swap one tile for another.** A closed door becomes an open door: same cell, different atlas
coordinate.

```
On switch pressed
  -> Set Tile  Vector2i(8, 4), source 0, atlas Vector2i(5, 1)
```

**8. Tell tile types apart.** Cell Atlas Coords is the identity of what is in a cell, so branching on it
is how "is this water?" is answered without a second data structure.

```
On player entered cell
  Condition: Cell Atlas Coords(player_cell) = Vector2i(0, 3)
    -> Set value  in_water = true
```

**9. Tell layers apart with Tile At.** With two tile sources in one TileSet (terrain and props,
say), the source id says which family a placed tile belongs to.

```
On inspect pressed
  Condition: Tile At(hovered_cell) = 1
    -> Print  "That is a prop, not terrain"
```

**10. Blow a hole in the wall.** Explosions read as a loop of Erase Tile rows over the cells inside the
radius.

```
On bomb exploded
  For Each  cell in blast_cells
    -> Erase Tile  cell
```

**11. Reset the level in one row.**

```
On restart pressed
  -> Clear Tilemap
```

**12. Paint a procedural floor.** A nested loop of Set Tile rows is a complete level generator.

```
On Ready
  Repeat 20 times  (as x)
    Repeat 12 times  (as y)
      -> Set Tile  Vector2i(x, y), source 0, atlas Vector2i(1, 0)
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
  -> Erase Tile  Position To Tile( FogLayer.to_local(global_position) )   On node: FogLayer
```

**16. Grow a crop through its stages.** Each growth tick moves the atlas coordinate one step along the
row.

```
On growth tick
  -> Set Tile  crop_cell, source 0, atlas Vector2i(stage, 4)
```

**17. Paint on one layer and read from another.** Two rows, two On node targets, one sheet - a collision
layer that is written from what the decoration layer contains.

```
On Ready
  Condition: Cell Has Tile  Vector2i(4, 4)   On node: DecorLayer
    -> Set Tile  Vector2i(4, 4), source 0, atlas Vector2i(0, 0)   On node: CollisionLayer
```

**18. Place a node exactly on a tile.** Tile To Position plus the layer's own transform is how a spawned
enemy lands centred in its cell.

```
On spawn enemy
  -> Set Property  Enemy.position = Tile To Position(spawn_cell)
```

### Other use cases

**Minesweeper board.** Store the mine positions as cells, use Set Tile to reveal a number tile on click, and let Cell Has Tile answer "already revealed" with no parallel array to keep in sync.

**Auto-tiling by hand.** Read the four neighbouring cells with Cell Has Tile and pick the atlas coordinate that matches the pattern, which gives you a corner-aware wall set without a terrain set.

**Save a level as cells.** Walk the grid with Tile At and Cell Atlas Coords into a dictionary, and rebuild it later with Set Tile rows - a level editor whose save format you fully control.

**Conveyor belts and pipes.** The atlas coordinate encodes direction, so reading Cell Atlas Coords under the moving object tells it which way to travel next.

**Damage stages on terrain.** One tile per damage level in the same atlas row; each hit moves the cell one step along, and the last hit erases it entirely.

## Tips and common mistakes

- **Position To Tile wants LOCAL space.** Handing it a global position (mouse or `global_position`) works
  perfectly until the layer is moved or the camera scrolls, and then everything is silently off by the
  layer's offset. Convert with `to_local(...)` first, every time.
- **Source and atlas are two different numbers and both matter.** Source is which tile sheet, atlas is
  which tile in it. A wrong source id paints nothing and reports no error.
- **An out-of-bounds cell reads as empty, not as an error.** Tile At returns -1 for anything not
  placed, so Cell Is Empty cannot tell "outside the level" from "inside but blank". Bound-check with
  your own variables when that distinction matters.
- **Coordinates are integers.** A Vector2 with fractional parts is not a cell. Position To Tile does the
  rounding for you; typing coordinates by hand does not.
- **Tile To Position returns the cell's CENTRE.** If a placed sprite looks half a tile off, you probably
  wanted the centre and are compensating for a corner, or the sprite's own origin is at its top-left.
- **Clear Tilemap wipes the whole layer.** There is no undo at runtime and no partial form; to clear a
  region, loop Erase Tile over it.
- **Used Cells Count builds an array every call.** It emits `get_used_cells().size()`, which allocates
  the full list of used cells each time. That is fine on an event, and wasteful inside a per-frame row
  on a large map - cache it in a variable and update it when you actually change a cell.
- **These are TileMapLayer rows.** On a project still using the legacy TileMap node they will not
  appear in the picker, because the picker scopes by node type.
- **Erase Tile is not Set Tile with source -1.** Use Erase Tile; it is the action that exists and the one
  the emitted code reads clearest as.
- **On node lets one sheet drive several layers**, and a blank On node compiles byte-for-byte to the bare
  host call - so adding a target later never disturbs the rows around it.
