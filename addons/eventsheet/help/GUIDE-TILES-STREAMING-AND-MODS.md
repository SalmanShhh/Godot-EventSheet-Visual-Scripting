# Tiles, Streaming and Mods - The Ground, the World Past It, and the Folder Players Add To

Three jobs that look unrelated until you build a game big enough to need all three. The ground your
game stands on is a tilemap, and a game asks it questions all day: what is this tile made of, is it
solid, where does this line first meet a wall. A world larger than memory is a folder of scenes named
by cell, streamed in around the player and freed behind them. And a game people keep playing grows a
folder players put their own content in.

Every row on this page compiles to plain GDScript against Godot's own `TileMapLayer`, `GridMap`,
`ResourceLoader` and `ProjectSettings` calls. There is no level format here, no world container, no
mod runtime. A row that asks a tile for its data writes a `get_cell_tile_data(...)` lookup into your
script, and a hand-written one opens back as that row.

## Table of Contents

1. [The ground as a question](#the-ground-as-a-question)
2. [The line that meets a wall](#the-line-that-meets-a-wall)
3. [Changing the ground, and the edges healing themselves](#changing-the-ground-and-the-edges-healing-themselves)
4. [The level as a file, and the undo that makes](#the-level-as-a-file-and-the-undo-that-makes)
5. [The 3D twin, and what has no twin](#the-3d-twin-and-what-has-no-twin)
6. [What the Doctor says about a tilemap](#what-the-doctor-says-about-a-tilemap)
7. [A world bigger than memory](#a-world-bigger-than-memory)
8. [The file name is the address](#the-file-name-is-the-address)
9. [Splitting a scene you already built, and putting it back](#splitting-a-scene-you-already-built-and-putting-it-back)
10. [What the Doctor says about a chunk folder](#what-the-doctor-says-about-a-chunk-folder)
11. [The folder players add to](#the-folder-players-add-to)
12. [The two tiers, said plainly](#the-two-tiers-said-plainly)
13. [Tips and common mistakes](#tips-and-common-mistakes)

## The ground as a question

A tileset can carry **custom data layers**: named values you attach to a tile in the TileSet editor.
A `"surface"` layer that says `ice` or `mud`, a `"cost"` a path search adds up, a `"solid"` flag.
They are the level designer's own vocabulary, painted into the tiles themselves, and they are what
turns a picture of a level into a level.

Reading one by hand is a cell lookup, a null guard and a data read:

```gdscript
var data: TileData = ground.get_cell_tile_data(ground.local_to_map(ground.to_local(player.global_position)))
var surface: Variant = data.get_custom_data("surface") if data != null else null
```

**Tile Data At** is that question as one expression, and **Tile Data At Is** is the comparison as one
condition. Both take a cell **or** a global position: a `Vector2i` is already a cell, and anything
else is turned into the cell holding it through the layer's own transform, so a scrolled, rotated or
scaled map still answers correctly.

| Condition | Actions |
| --- | --- |
| **Ground** ▸ tile data **"surface"** at **Player.global_position** is **"ice"** | **Player** ▸ Set **friction** to **0.02** |
| **Ground** ▸ tile data **"surface"** at **Player.global_position** is **"mud"** | **Player** ▸ Set **friction** to **0.9** |

Two rows, two sentences, no null guard to remember. The **Data** field suggests the custom data layer
names your project's own tilesets declare, read out of the `.tres` files as text rather than loaded,
so you pick the name the tileset spells rather than retyping it.

```gdscript
extends Node2D


func _physics_process(_delta: float) -> void:
	if __eventsheets_tile_data_at($Ground, $Player.global_position, "surface") == "ice":
		$Player.friction = 0.02
	if __eventsheets_tile_data_at($Ground, $Player.global_position, "surface") == "mud":
		$Player.friction = 0.9


func __eventsheets_tile_data_at(map, where, key: String) -> Variant:
	if map == null:
		return null
	var cell: Vector2i = where if where is Vector2i else map.local_to_map(map.to_local(where))
	var data: TileData = map.get_cell_tile_data(cell)
	return data.get_custom_data(key) if data != null else null
```

**The helper is written into your file once**, the first time any row asks for it, and appended after
everything else so no line above it moves. A file that already defines it gains nothing on the next
save, which is what keeps reopening an emitted file and saving it again byte-identical. Eleven of
these exist across the tile vocabulary, and a file gains only the ones its rows actually call.

**The trap this removes.** `get_cell_tile_data` answers `null` for an empty cell, and `null` has no
`get_custom_data`. Written by hand the guard is the line everybody forgets, and the error it raises
arrives at run time, in a physics frame, on somebody else's machine.

### The rest of the questions

| Row | Kind | Answers |
|---|---|---|
| **Cell Is Solid** | Condition | Whether the tile at a cell carries a collision shape on the tileset physics layer you name |
| **Surrounding Cells Of** | Expression | The cells touching a cell, asked of the LAYER, so a hex map answers with six |
| **Cells With Data** | Expression | Every cell whose tile carries a value under a named data layer, as a list |
| **Used Rect** | Expression | The rectangle of cells the layer actually holds tiles in, as a `Rect2i` |
| **Cell Count Of** | Expression | How many cells hold one particular tile |
| **Tile Under** | Expression | Which cell a node stands on, through the layer's own transform |

**Cells With Data** is how a level draws its own spawn points. Paint a `"spawn"` value into the tiles
where enemies start, and the level's contents come out of the level rather than out of a list
somebody has to keep in step with it:

| Condition | Actions |
| --- | --- |
| **System** ▸ On start of layout | **Ground** ▸ For each in **cells with "kind" = "spawn"** |
| ↳ (loop body) | **System** ▸ Spawn **Enemy** at **Ground.TileToPosition(cell)** |

**Used Rect** is the number a camera's limits are set from, so a level knows how big it is without
anybody typing its size a second time.

**Surrounding Cells Of** asks the layer rather than doing the arithmetic, which matters the moment
the map is not square. A hand-written `cell + Vector2i(1, 0)` walk is correct on a square grid and
quietly wrong on a hex or isometric one; `get_surrounding_cells` is right on all three because the
layer knows its own shape.

## The line that meets a wall

**First Solid Cell Along** walks the cells of a line and answers the first one whose tile is solid.
Line of sight, a laser stopping at a wall, a jump arc meeting the ground - with no physics query, no
`RayCast2D` node, and no collision layer to configure.

| Condition | Actions |
| --- | --- |
| **Guard** ▸ On seeing **Player** | **Guard** ▸ Set **blocked** to **Ground.FirstSolidCellAlong(Guard.global_position, Player.global_position, 0)** |
| **Guard** ▸ **blocked** = **Vector2i.MAX** | **Guard** ▸ Fire at **Player** |

`Vector2i.MAX` is the answer when the line reached its end having met nothing, which is the
"nothing in the way" case said as a value rather than as a second boolean.

**The Physics layer field is the TILESET's, not the project's.** A tileset numbers its own physics
layers `0`, `1`, `2`; those numbers have nothing to do with the project's named collision layers.
The field says so under the box, because guessing wrong here is a test that always answers `false`
and never says why.

## Changing the ground, and the edges healing themselves

Painting a tile is easy. Painting a tile that **looks** like it was always there is what terrain is
for, and it is the reason hand-written tile editing looks wrong.

**Paint Terrain** hands a list of cells to `set_cells_terrain_connect`, and the tileset chooses each
tile so edges, corners and joins draw themselves. **Repaint Terrain Around** runs that join again
over the cells around a place, which is how a blown hole's rim closes up:

| Condition | Actions |
| --- | --- |
| **Bomb** ▸ On exploded | **Ground** ▸ Erase tiles within **3** of **Bomb.global_position** |
| | **Ground** ▸ Repaint terrain around **Bomb.global_position**, **3** cells, set **0**, terrain **-1** |
| | **System** ▸ Spawn **Dust** at **Bomb.global_position** |

Terrain **-1** means "these cells hold no terrain", which is exactly what the inside of a hole is.
Leaving the erase without the repaint is the crater with sharp square edges everybody has shipped
once.

The bulk shapes are **Fill Rect With Tile**, **Erase Tiles In Circle** and **Flood Fill**. The flood
fill is the paint bucket, and it is **bounded by the row's own Most cells field**: started on an
empty cell of an unbounded layer, an unbounded fill spreads for as long as the machine lets it. It
also refuses to start when the cell already holds what it would paint, which is the other way that
walk never ends.

```gdscript
func __eventsheets_flood_fill_tiles(map, from: Vector2i, source_id: int, atlas_coords: Vector2i, limit: int) -> void:
	if map == null:
		return
	var was_source: int = map.get_cell_source_id(from)
	var was_atlas: Vector2i = map.get_cell_atlas_coords(from)
	if was_source == source_id and was_atlas == atlas_coords:
		return
	...
```

**Set Navigation On Layer** and **Set Collision On Layer** are the two switches a door or a bridge
throws: turn the layer's navigation regions on and agents route through it, turn its collision off
and a ghost phases through the wall.

## The level as a file, and the undo that makes

A `TileMapLayer` keeps its tiles in one property, `tile_map_data`, as the bytes the engine itself
stores them in. Three rows use that fact.

**Save Layer To File** and **Load Layer From File** write and read those bytes, so a level the player
built is a file in their own folder:

| Condition | Actions |
| --- | --- |
| **SaveButton** ▸ On pressed | **Ground** ▸ Save layer to **"user://levels/mine.tiles"** |
| **LoadButton** ▸ On pressed | **Ground** ▸ Load layer from **"user://levels/mine.tiles"** |

A file that is not there leaves the layer alone rather than clearing it, so a first run with no saved
level is not an empty screen.

**Copy Layer** moves one layer's bytes onto another in one go, and **a level editor's undo is two of
those**: one onto a spare hidden layer before the edit, one back afterwards.

| Condition | Actions |
| --- | --- |
| **System** ▸ On **paint** pressed | **UndoBuffer** ▸ Copy layer from **Ground** |
| | **Ground** ▸ Flood fill from **Ground.TileUnder(Cursor)** with **Vector2i(2, 0)**, most **4096** cells |
| **System** ▸ On **undo** pressed | **Ground** ▸ Copy layer from **UndoBuffer** |

**The trap this removes.** Written by hand, "save the level" turns into a loop over `get_used_cells`
writing a source id and an atlas coordinate per cell into JSON, and reading it back is that loop
again. `tile_map_data` is the engine's own answer to the same question, it round-trips exactly, and
it is one line.

## The 3D twin, and what has no twin

A `GridMap` is a MeshLibrary laid out on a 3D grid, and the questions a game asks of it are the
questions it asks of a tilemap layer with one more axis. Six rows carry the same words their 2D twins
use, so a reader who learned one knows the other:

| 3D row | Its 2D twin |
|---|---|
| **Set Cell Item** | Set Tile |
| **Item At** | Tile At |
| **Cell Is Filled** | Cell Has Tile |
| **Used Cells** | (the list behind Used Cells Count) |
| **Fill Box** | Fill Rect With Tile |
| **Erase Box** | Erase Tiles In Circle |

Erasing **is** filling with the invalid item - that is how the engine itself empties a cell - so
those two rows are one emitted helper with a different last argument, and the code says so.

**What has no twin is said rather than faked.** A `GridMap` has no tileset, so it has no custom data
layers and no terrains. Tile Data At, Cells With Data, Paint Terrain and Repaint Terrain Around are
2D words and stay 2D words. A 3D game that wants "which cells are lava" keeps that in a collection or
a group, the way it would for any other 3D scenery, and the row's help strip says so instead of
offering a field that would always answer nothing.

## What the Doctor says about a tilemap

**Tools ▸ Project Doctor** carries a **Tilemap** section with two quiet checks, both read from your
project's own tilesets:

- **A data key no tileset declares.** A row asking tiles for `"surfce"` will answer nothing forever,
  and nothing is a perfectly valid answer, so the game never complains. The check names the row and
  the key.
- **A terrain set the tilesets do not reach.** Painting terrain set `2` in a project whose tilesets
  go up to `1` is a call that does nothing at all.

**It says nothing whatever in a project it found no readable tileset in.** A list that may be
incomplete must never become a finding: a check that cannot see your tilesets would otherwise accuse
every correct row in the project. And as everywhere else, the sheet itself stays quiet - the affected
row wears the amber state, the words live in the Doctor's inbox and in the row's help strip when it
is selected.

## A world bigger than memory

Past a certain size a level stops fitting - in memory, and in the editor. The **Streamer** and
**Streamer 3D** packs answer that with the plainest thing that works: **your world is a folder of
scenes named by cell**, and the pack keeps the ones near the player loaded.

`StreamerBehavior` attaches as a child of the node your chunks should live under, and chunks are
added as **its** children. One row starts it:

| Condition | Actions |
| --- | --- |
| **World** ▸ On ready | **Streamer** ▸ Stream chunks around **Player**, **2** cells, from **"res://world/chunks/"** |

```gdscript
extends Node2D


func _ready() -> void:
	$Streamer.stream_around($Player, 2, "res://world/chunks/")
```

That is the whole setup. Loading happens on a thread through `ResourceLoader.load_threaded_request`,
one request per frame; finished chunks join the world inside a millisecond budget, so an arriving
chunk cannot spend a frame; and a **keep radius** holds a chunk for a ring or two past the streaming
radius, so walking back and forth over a border reloads nothing.

The rows either pack ships:

| Kind | Name | What it does |
|---|---|---|
| Action | **Stream Chunks Around** | Follows a node, keeping the chunks within a radius loaded and freeing the rest |
| Action | **Stop Streaming** | Stops following. Loaded chunks stay exactly where they are |
| Action | **Keep Chunk** / **Release Chunk** | Pins one cell's chunk, or unpins and drops it now |
| Action | **Preload Chunks Around** | Asks for the chunks around a point before anything goes there |
| Condition | **Chunk Is Loaded At** | Whether the chunk covering a world point is in the world right now |
| Condition | **Is Loading Chunks** | Whether anything is still on its way in |
| Expression | **Loaded Chunk Count**, **Chunk Of** | How many are in, and which cell a point falls in |
| Trigger | **On Chunk Loaded** | Once per chunk, with the node, just after it joins the world |
| Trigger | **On Chunk Unloading** | **Before** the chunk is dropped, so a row can save what the player changed in it |
| Trigger | **On Streaming Idle** | Once when nothing is left to load, and not again until something is |

**On Chunk Unloading fires before the drop**, and that ordering is the whole point of it. A world the
player changes needs somewhere to put the change while the node still exists:

| Condition | Actions |
| --- | --- |
| **Streamer** ▸ On chunk unloading | **System** ▸ Set **saved[cell]** to **chunk.get_node("Ground").tile_map_data** |
| **Streamer** ▸ On chunk loaded | **System** ▸ Set **chunk.get_node("Ground").tile_map_data** to **saved[cell]** |

**Preload Chunks Around** is the teleport, the fast travel and the cutscene: ask for the destination
before anything goes there, then watch **Is Loading Chunks** turn false, and the arrival has nothing
to pop in.

### Flat or stacked, the one decision the 3D pack asks for

`Streamer3DBehavior` is the same nine words on a `Vector3i` grid, with one extra property. With
**Stream Height** off, the grid is flat: every cell's Y is `0` however high the player climbs, so a
mountain and the valley beside it are one chunk. That is what an open world wants, and it is why the
default is off.

With it on, height becomes a cell axis. **A radius of 1 goes from nine chunks to twenty-seven, and a
radius of 2 from twenty-five to a hundred and twenty-five.** Turn it on for a space station, a cave
system or a tower, where the world genuinely is stacked, and lower the radius when you do.

## The file name is the address

There is no manifest, no index and no database. `chunk_3_-2.tscn` **is** cell (3, -2). Three numbers
instead of two, `chunk_3_0_-2.tscn`, and it is cell (3, 0, -2) on a stacked grid.

That grammar is read in four places - both packs at run time, the Doctor, and the tools that write
such a folder - so it is written down once and the four ask it rather than each spelling it again.
The rules, in full:

- The **prefix** is whatever comes before the numbers, so a project may call its chunks `chunk`,
  `world` or `sector_a`.
- What decides a name is the run of whole numbers at the **end** of it. Two of them is a flat grid,
  three is a stacked one, and a name with fewer than two is not a chunk at all.
- Two scenes named like cells is a folder; one is a coincidence.

**The one ambiguity, stated rather than hidden:** a prefix that itself ends in a number, `level_2`,
is read as part of the address. That is why the tool that writes a folder never generates such a
prefix, and why the pack's `chunk_prefix` property says not to end it with a digit.

Because the format is file names, everything else about it is a file browser. Make chunks by hand,
rename them, delete one, copy a folder from another project, put the folder in version control and
read a diff of it. Nothing here has to be exported from anything.

## Splitting a scene you already built, and putting it back

Almost nobody starts with chunks. You build a level, it gets big, and then you want it streamed.
**Ctrl+P ▸ Split Scene Into Chunks** does that conversion:

1. Every **direct child** of the scene's root moves into the cell its own position falls in.
2. Each child is re-based to that cell's origin, so a chunk scene is authored around `(0, 0)` and the
   grid puts it back in the world.
3. Each cell is written as `chunk_X_Y.tscn` (or `chunk_X_Y_Z.tscn`) in the folder you name.

Two things it deliberately does not do. **A child with no place in the world** - a node with no
position at all - is **named in the receipt** rather than guessed at. And **a tilemap is left alone**,
because splitting one would mean rewriting its tile data, which is a different and much less
reversible operation than moving nodes.

**Ctrl+P ▸ Merge Chunks** is the way back: it reads a chunk folder and writes one scene with
everything put where the grid said it was. A split is never a one-way door onto somebody's level, and
the round trip is what the suite pins.

**The trap this removes.** The cell-size fields say their ceiling now. A `SpinBox` tops out at 100
unless it is told otherwise, so a 1024 default silently clamped to 100 would have written ten
thousand chunk scenes on a first split without a word about why.

## What the Doctor says about a chunk folder

The Doctor's **Streaming** section reports the two things that go wrong with a **folder** rather than
with a row, which is why neither of them is something a sheet could tell you:

- **A hole in the grid.** A folder that is a filled rectangle except for cells nobody made. A player
  who walks into one of those cells finds nothing there, and finds it on somebody else's machine
  rather than yours. A deliberately sparse world of distant islands is not a grid with holes and
  earns no finding.
- **A chunk carrying a camera.** Every `Camera2D` or `Camera3D` makes itself current as it enters the
  tree, so a chunk with one in it snaps the view to whichever piece of scenery arrived last. It is
  correct while that chunk is the scene being edited and wrong the moment it is one tile of a world,
  which is exactly why it survives being looked at.

Both are read from the scenes' **text**, never by loading them - auditing a streamed world by loading
all of it would be the one thing the pack exists to avoid.

## The folder players add to

**Mods** ships as the `Mods` autoload: the folder players put their own content in, and the rows that
read it. A mod is a folder with a manifest in it, or a `.pck` / `.zip` that Godot loads on top of the
game's own files.

| Condition | Actions |
| --- | --- |
| **System** ▸ On start of layout | **Mods** ▸ Set load order **"CoreFixes, BigSwords"** |
| | **Mods** ▸ Load mods from **"user://mods"**, data only **true** |
| **Mods** ▸ On mod loaded | **ModList** ▸ Add item **Mods.ModName + " " + Mods.ModVersion** |
| **Mods** ▸ On mod refused | **StatusLabel** ▸ Set text to **Mods.ModName + ": " + Mods.ModReason** |

```gdscript
extends Node


func _ready() -> void:
	Mods.mods_changed.connect(_on_mods_changed)
	Mods.mod_loaded.connect(_on_mod_loaded)
	Mods.mod_refused.connect(_on_mod_refused)
	Mods.set_load_order("CoreFixes, BigSwords")
	Mods.load_from("user://mods", true)
```

**`user://mods` is the default and the right answer.** A folder under `res://` is packed into the
export, and a player cannot put anything into it once you ship - the same export trap that catches a
save file, wearing a different hat.

**The manifest is the mod's own file**, in either spelling: `mod.json` for a modder working in a text
editor, `mod.tres` saved from a `ModManifest` for one working in Godot. Both are read into one
record, so nothing downstream knows which was used.

**Load order is a sentence, not a database.** Name the mods you care about, in order; everything else
follows in name order, and later mods replace what earlier ones brought. Note that name order is
asked with the engine's own natural, case-insensitive comparison - a plain sort is ASCII, and in
ASCII every capitalised name sorts ahead of every lowercase one, which is not what a player means by
alphabetical.

**Switched off is the player's word.** A mod is on unless it was switched off, so one nobody has seen
yet arrives enabled. The choice is remembered through the Game Settings autoload when the project has
one, and a project without one still honours it for the session.

**The doors onto a mod's content are the rows you already have.** `Mod Folder` and `Mod Folders` hand
a path to Resources In Folder, a SkinVault catalog or a loot table; `Mod Content Problems` asks the
Data Folder Problems questions over those folders, plus the one only a mods folder raises - a file
two mods both bring.

**Command palette ▸ Export Mod Template** writes the folder your modders copy: a filled-in
`mod.json`, an optional `mod.tres` beside it, an empty content folder, and a README saying what each
field means. Point it somewhere that is **not** your mods folder - it is the example, not a mod - and
it refuses a folder that already holds a manifest rather than writing over somebody's work.

## The two tiers, said plainly

Every loading row takes a **data only** parameter, and it is the most consequential checkbox in this
guide.

**Data only, on.** Before the mod is taken at all, its actual contents are read - a pack file's own
file table off the front of the file, a folder's own files - and a mod carrying any script, library
or native binary is refused, with the reason in words a player can read. The manifest's own `scripts`
flag is treated as a **declaration, not a guarantee**: the loader checks the real files as well.

**Data only, off.** Code in the mod loads and runs. **It runs with everything your game itself can
reach** - the player's files, their network, their machine. Godot has no sandbox to put it in, this
pack does not pretend otherwise, and nothing here will make an untrusted mod safe. That is not a
warning about this pack; it is a fact about the engine, and the honest thing is to say it in the row
rather than let a developer discover it after shipping.

Data only is the tier to ship unless you have a specific reason not to, and a game that does allow
code should say so to its players.

**A pack file cannot be unloaded.** Once Godot has loaded a `.pck` or `.zip`, its files are part of
the running game until it starts again. **Unload Mod** refuses one with that sentence rather than
appearing to work; switching the mod off and restarting is the way. Folder mods have no such limit.

## Tips and common mistakes

- **A tileset physics layer is not a project collision layer.** Cell Is Solid and First Solid Cell
  Along number the **tileset's** own physics layers. Wrong number, always false, no error.
- **Erase then repaint.** Erase Tiles In Circle on its own leaves the crater's rim with the wrong
  autotile edges. Repaint Terrain Around with terrain `-1` is the second half of that sentence.
- **Bound your flood fill.** The Most cells field is not decoration. A fill started on open ground
  with a huge limit is a frame you will not get back.
- **`user://` for anything the player owns.** Saved levels, mod folders, exported chunk folders you
  intend players to write to. `res://` is read-only in an exported game and fails silently.
- **Do not end a chunk prefix with a digit.** The numbers at the end of the file name are the
  address, and `level_2_3_4.tscn` cannot be told apart from a stacked cell.
- **Do not put a camera in a chunk.** It will make itself current the moment it streams in. The
  Doctor names them, but the habit is the fix.
- **A tilemap is not split by the split tool.** Convert a hand-built level to chunks by moving nodes;
  a tilemap that must be chunked is redrawn per chunk, or left as one layer the world sits on.
- **Ship data-only mods unless you have decided otherwise, and say what you decided.** The refusal
  reason is written to be read by a player, not by you - use it in your own UI rather than replacing
  it with "mod failed".
- **A mod name that two mods claim** is a real thing that happens the day two people publish. Turn
  the pack's debug mode on while you are building the modding side and it warns about that, about a
  missing folder, about a folder with no manifest and about a pack whose file list could not be read.
