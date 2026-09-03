# Drunken Walkers - Seeded Grid Generation From Event Rows

Walkers stagger across a grid of integers, carving caves, corridors, rivers and ore veins;
tagged **marks** land on the result with real placement and spacing rules. The whole run
comes out of **one seeded stream in a fixed order**, so a seed string reproduces a map cell
for cell - floors, ore, coins and enemies alike - on every machine your game ships to.

The pack owns the grid and nothing visible. It never draws a tile, spawns a node or sets a
position: you read the results back through triggers and expressions and drive your own
TileMapLayer or scenes, which is exactly why it fits any art pipeline. Ported from a popular
event-sheet engine's addon, with its determinism contract kept intact.

## Where this pack shines

- **Organic, non-rectangular levels.** When rooms-and-corridors feels too rigid, a drunkard's
  walk is the classic answer: caves, burrows, mines, ant nests, coral and root systems all fall
  out of a few walkers with the right heading count and turn limit.
- **Daily seeds and shareable level codes.** Every cell and every placement derives from one
  seed string, so "today's dungeon" or an eight-character code reproduces the whole experience.
- **Layered generation at scale.** Dozens of walkers and mark passes on a 256 x 256 grid run in
  one synchronous call, so terrain, ore, loot and three decoration layers land inside a frame.
- **Anything path-shaped, not just dungeons.** A walker with two or three headings and a small
  max turn is a river, a road, a lightning bolt, a crack in glass or a brush stroke.
- **Watch-it-build generation.** Step Walker advances a few cells per tick, so a title screen
  that draws its own map uses the same engine and the same seed as an instant generation.
- **Placement rules you would otherwise hand-roll.** Minimum spacing, "only in open areas",
  "only against walls" and "roughly every N steps along this path" are parameters here, not
  nested rows full of distance checks.

## Setup

1. Attach **DrunkenWalkers** as a child of any node - it is invisible and draws nothing, so it
   does not matter where it sits.
2. Decide what your cell values mean and stick to it. A common convention is 0 empty rock,
   1 floor, 2 water, 3 wall.
3. Set **Cell Size** to your tile size and leave **Empty Value** at 0. Tick **Debug Mode**
   while you build so the pack says what it is doing.
4. A grid already exists at **Grid Width** x **Grid Height** from the moment the node does, so
   if those are the size you want you never need Create Grid at all. Seed, register, run.

```
On Ready -> Map | Drunken Walkers: Set Seed  "hello-world"
         -> Map | Drunken Walkers: Add Walker  "cave", 20, 15, 400, 8, 180, "", 1
         -> Map | Drunken Walkers: Run All Walkers
```

Before you have a tilemap at all, put `Map.As Text(".#")` in a Label: one character per cell,
one line per row, and the whole map is on screen in one row of event sheet.

## ACE reference

On the canvas these rows read as styled sentences - parameter values in **bold**, node
references in *italic*, exactly as the rows draw them:

- start a new **width** x **height** grid
- add walker **id** at (**start_x**, **start_y**) - **steps** steps, **directions** headings, turning up to **max_turn**, tagged **tag**, carving **carve_value**
- scatter **count** **tag** marks on **value** cells, **placement**, spacing **min_spacing**

Every verb is scoped to a node, so a row names which generator it is talking to - which is how
two independent generators live in one scene.

### Actions

| Action | Parameters | Description |
|---|---|---|
| Create Grid | `width` (int), `height` (int) | Allocates a fresh grid filled with the Empty Value, clamped to Max Grid Size. Only needed for a size other than the Grid Width / Grid Height properties, because that grid already exists from the start. A width or height of 0 or less falls back to its property. Destroys the previous grid, every registered walker and every mark: it is "start a new level". The seed is not touched. |
| Clear Grid | `value` (int) | Refills every cell with a value you choose. Walkers, marks and the random stream are left alone, and it does not fire On Cell Carved. Use it to re-run the same walkers over a blank slate without re-registering them. |
| Set Cell | `x` (int), `y` (int), `value` (int) | Writes one cell directly. Deliberately silent: it does not fire On Cell Carved, which makes it the right tool for pre-placing anchors like a guaranteed entrance or a boss room before the walkers run. |
| Set Origin | `x` (float), `y` (float), `new_cell_size` (int) | Moves the grid in world space and optionally changes the cell size, for the four coordinate expressions. Pass 0 for the cell size to keep the current one. |
| Draw Cells To Tilemap | `layer` (TileMapLayer), `value` (int), `source_id` (int), `atlas_x` (int), `atlas_y` (int) | Paints one tile into a TileMapLayer for every cell holding a value, replacing the whole paint loop. Cell coordinates map straight onto tile coordinates. Call it once per value; a source id of -1 erases those tiles instead. |
| Set Seed | `seed_text` (String) | Resets the generator from a seed string. Call it BEFORE generating: the same seed with the same action order reproduces identical output, and calling it afterwards changes nothing about the map you just built. It does not clear the grid. |
| Set Random Source | `source` (`internal` / `shared` / `injected`) | Switches where every decision draws from: this pack's own seeded generator, the shared Advanced Random autoload, or the injected queue Inject Random fills. You may switch mid-run, so one pass can audit through a single stream while the rest does not. |
| Inject Random | `value` (float) | Queues one value between 0 and 1 for the injected source, generation consuming them in order. Budget roughly two per walker step plus one per mark candidate. A queue that runs dry falls back to the internal generator rather than failing, and says so in Debug Mode. |
| Add Walker | `id` (String), `start_x` (int), `start_y` (int), `steps` (int), `directions` (int), `max_turn` (float), `tag` (String), `carve_value` (int) | Registers a walker with the eight settings you change most: where it starts, how many steps it has, how many headings it may face (1 to 8), how far it may turn in one step, its tag and the value it carves. Everything else takes its default. Re-using an id replaces that walker without moving it in the run order. |
| Add Walker From Preset | `preset` (`cave` / `corridors` / `river` / `ore_vein` / `lightning` / `blob`), `id` (String), `start_x` (int), `start_y` (int), `tag` (String), `carve_value` (int) | Registers a walker from a named shape recipe, so you only need a position, a tag and a carve value. Tune it afterwards with the Set Walker actions. The exact numbers are in the recipe table below. |
| Define Walker | `definition` (String) | Registers a walker from a whole JSON definition in one string, which suits definitions that live in a data file or a level editor. Anything you leave out takes its default. Both spellings of every field are accepted, so `startX` and `start_x` both work. |
| Set Walker Carve Value | `id` (String), `value` (int) | Changes the integer an existing walker writes into the cells it visits. It applies from that walker's next step, so anything already carved keeps its old value - which is how one walker lays down two materials along one path. |
| Set Walker Steps | `id` (String), `steps` (int) | Sets a walker's REMAINING step budget, and un-finishes a finished walker, so topping one up and running it again extends the path it already drew. |
| Set Walker Turn Chance | `id` (String), `chance` (float) | Sets the 0 to 1 probability that a walker even considers turning on a given step. At 1 the heading performs its own random walk and the path curls; around 0.15 to 0.3 is what actually reads as a road or a river. |
| Set Walker Brush Size | `id` (String), `size` (int) | Sets the square block a walker stamps each step. 1 is a single cell, 3 is a centred 3x3. It never rotates, so it is right for blobby caves and wrong for corridors. Ignored while a dig size is set. |
| Set Walker Start Angle | `id` (String), `degrees` (float) | Rotates the walker's whole direction set to a new anchor angle, 0 being right and 90 down. The direction weights rotate with it, because weight entry 0 always weighs the start angle. |
| Set Walker Dig Size | `id` (String), `width` (int), `depth` (int) | Swaps the square brush for a rectangle that TURNS WITH THE WALKER. Width is measured across the heading and is always centred, so a corridor keeps its width around every corner. Depth is measured along the heading and is signed: positive digs ahead of the walker, negative digs behind it. 0 on an axis falls back to the brush size, and 0 on both restores the square brush. |
| Set Walker Direction Weights | `id` (String), `weights` (String) | Biases which heading a walker turns toward, as a comma separated list of relative weights in direction order starting at the start angle. A 0 rules that heading out, a missing entry counts as 1, extra entries are ignored, and an empty string restores equal weights. |
| Remove Walker | `id` (String) | Unregisters a walker. Everything it already carved stays exactly as it is, because carving writes into the grid as it happens rather than being replayed at the end. |
| Run All Walkers | (none) | Runs every registered walker to the end of its budget, in registration order, then fires On Generation Complete. This is the whole generation in one row. |
| Run Walkers By Tag | `tag` (String) | Runs only the walkers carrying a tag, in registration order, then fires On Walkers By Tag Complete. Staging generation in tagged passes is how a later pass reacts to what an earlier one carved. An empty tag is not a wildcard here: it runs the walkers that genuinely have no tag. |
| Run Walker | `id` (String) | Runs one walker by id to the end of its budget. It fires On Cell Carved and On Walker Finished but deliberately NOT On Generation Complete, because it is one pass of a bigger generation rather than the end of it. |
| Step Walker | `id` (String), `steps` (int) | Advances one walker by up to this many steps instead of running it out, firing On Walker Stepped per step - the row that makes the map draw itself in front of the player. The walk is identical to an instant run, just spread over time. The first call carves the start cell, so nothing has to place the walker first. |
| Drop Marks Along Walk | `walker_id` (String), `tag` (String), `every_steps` (int), `chance` (float), `min_spacing` (float) | Replays a walker's recorded path and considers a candidate every N steps, keeping each with the given chance and rejecting it if it lands too close to an existing mark of the same tag. The walker must have run already, because the path is recorded as it walks. Candidates start at step N, not at the start cell. |
| Scatter Marks | `count` (int), `tag` (String), `value` (int), `placement` (`any` / `interior` / `edge`), `min_spacing` (float) | Places up to this many tagged marks on cells holding a value, filtered by the placement rule and thinned by minimum spacing. The count is a maximum, not a promise: tight spacing or a rule that matches almost nothing places fewer, and Debug Mode says how many it managed. |
| Clear Marks | `tag` (String) | Removes every mark carrying a tag, an empty tag removing all of them. The grid is untouched, so clearing marks and re-scattering only re-rolls the placement. |
| Dilate Cells | `value` (int), `iterations` (int) | Grows every region of a value outward by one ring per iteration, which is how one-cell corridors become chambers. It converts ANY neighbouring cell, including ones holding other values, so dilate before you carve terrain you want to keep. Each iteration works from a snapshot, so one pass grows exactly one ring. |
| Outline Cells | `value` (int), `outline_value` (int) | Writes an outline value into every Empty Value cell touching a cell of the target value - the classic walls-around-the-floor pass. Unlike dilation it only ever overwrites the Empty Value, so water and ore survive it, which makes it safe to run last. |
| Load State From Text | `state` (String) | Restores a whole generator from the text Save State As Text produced: the grid, the origin and cell size, the seed, the random stream's own position, every walker with its progress and recorded path, and every mark. Restoring is SILENT - no On Cell Carved and no On Mark Placed - so repaint from Count Cells and the index expressions afterwards. |

### Conditions

| Condition | Parameters | Description |
|---|---|---|
| Is Cell Value | `x` (int), `y` (int), `value` (int) | True when the cell holds exactly that value. Stricter than the Cell Value expression: an out-of-bounds cell matches nothing, not even the Empty Value, which is what lets you test the border honestly. |
| Is Inside Grid | `x` (int), `y` (int) | True when the X and Y fall inside the current grid. Guard anything built from World To Cell X / Y with it, because a point on screen may simply not be over the grid. |
| Has Mark At | `x` (int), `y` (int), `tag` (String) | True when a mark with the tag sits on that cell. An empty tag matches any mark, which is the quick way to ask whether anything is already here. |
| Has Walker | `id` (String) | True when a walker with that id is currently registered. |

### Expressions

| Expression | Parameters | Returns | Description |
|---|---|---|---|
| Cell Value | `x` (int), `y` (int) | int | The value at a cell. Asking outside the grid reads the Empty Value rather than erroring, so it is always safe to call. |
| Current Grid Width | (none) | int | The current grid width in cells, which is what Create Grid last built rather than the property. |
| Current Grid Height | (none) | int | The current grid height in cells, which is what Create Grid last built rather than the property. |
| As Text | `characters` (String) | String | The whole grid as text, one character per cell and one line per row. Character N of what you pass stands for value N, and an unmapped value shows as a question mark. Put it in a Label to see the map instantly, before you have a tilemap at all. |
| Neighbour Count | `x` (int), `y` (int), `value` (int) | int | How many of the eight surrounding cells hold a value. Off-grid neighbours never match, which is what makes border detection and autotiling work without special-casing the edge. |
| Cell To World X | `x` (int) | float | The world X of that cell's CENTRE, from Origin X and Cell Size - so a sprite placed on it lands centred in its tile whatever the origin is. |
| Cell To World Y | `y` (int) | float | The world Y of that cell's centre, from Origin Y and Cell Size. |
| World To Cell X | `layout_x` (float) | int | The cell X containing that world X. It may fall outside the grid, so guard it with Is Inside Grid. |
| World To Cell Y | `layout_y` (float) | int | The cell Y containing that world Y. It may fall outside the grid, so guard it with Is Inside Grid. |
| Count Cells | `value` (int) | int | How many cells currently hold the value. Pairs with the two index expressions to walk the whole set, which is the fast way to paint a generated map. |
| Cell X By Index | `value` (int), `index` (int) | int | The X of the index-th cell holding the value, counted from 0 in a stable left-to-right, top-to-bottom order. Out of range reads -1 rather than erroring. |
| Cell Y By Index | `value` (int), `index` (int) | int | The Y of the index-th cell holding the value, in the same stable order. Out of range reads -1. |
| Count Marks | `tag` (String) | int | How many marks carry the tag. An empty tag counts every mark, whatever its tag. |
| Mark X By Index | `tag` (String), `index` (int) | int | The X of the index-th mark with the tag, counted from 0 in placement order. Out of range reads -1. |
| Mark Y By Index | `tag` (String), `index` (int) | int | The Y of the index-th mark with the tag, in placement order. Out of range reads -1. |
| Current Seed | (none) | String | The seed the generator was last set with, including one derived from the clock - so a player can always be shown the code that reproduces the run they are in. |
| Injected Remaining | (none) | int | How many injected values are still queued. Read it after a generation to see how much headroom the queue actually had. |
| Save State As Text | (none) | String | The whole generator as one JSON string: the grid, the origin and cell size, the seed, the random stream's own position, every walker with its progress and recorded path, and every mark. Because the stream position round-trips, a half-finished Step Walker animation resumes and produces the identical remaining path. Save it with any save pack and hand it back to Load State From Text. |
| Walker X | (none) | int | The current X of the triggering walker. Reads 0 outside the walker triggers, never a stale cell. |
| Walker Y | (none) | int | The current Y of the triggering walker. Reads 0 outside the walker triggers. |
| Walker Angle | (none) | float | The current heading of the triggering walker in degrees, 0 being right and 90 down - point a digger sprite at it and it faces where it is going. |
| Walker Steps Left | (none) | int | The remaining step budget of the triggering walker, which is the natural driver for a generation progress bar. |
| Walker ID | (none) | String | The id of the triggering walker. It is empty inside the post-processing passes and outside the triggers, which is how On Cell Carved tells a dilated cell from a carved one. |
| Walker Tag | (none) | String | The tag of the triggering walker, or the batch tag inside On Walkers By Tag Complete. |
| Carved X | (none) | int | The X of the cell just written, inside On Cell Carved. |
| Carved Y | (none) | int | The Y of the cell just written, inside On Cell Carved. |
| Carved Value | (none) | int | The value just written into the cell, inside On Cell Carved. |
| Mark X | (none) | int | The X of the mark just placed, inside On Mark Placed. |
| Mark Y | (none) | int | The Y of the mark just placed, inside On Mark Placed. |
| Mark Tag | (none) | String | The tag of the mark just placed, inside On Mark Placed. |

### Triggers

| Trigger | Parameters | Description |
|---|---|---|
| On Cell Carved | `x` (int), `y` (int), `value` (int), `walker_id` (String) | Fires once per cell whose value actually CHANGES, during walker runs, dilation and outlining. Read Carved X, Carved Y, Carved Value and Walker ID inside it. A walker re-crossing ground it already carved does not fire it again, because nothing changed. |
| On Walker Stepped | `walker_id` (String) | Fires after each step of Step Walker, and only from Step Walker - batch runs skip it on purpose so bulk generation stays fast. Walker X, Walker Y, Walker Angle and Walker Steps Left are all live inside it. |
| On Walker Finished | `walker_id` (String) | Fires when a walker exhausts its budget or runs out of legal moves. Walker X and Walker Y are its final cell, which is how one walker starts where another stopped. |
| On Mark Placed | `tag` (String) | Fires once per mark from Drop Marks Along Walk and Scatter Marks. Mark X, Mark Y and Mark Tag describe it. |
| On Walkers By Tag Complete | `tag` (String) | Fires after a Run Walkers By Tag batch has finished every walker carrying that tag. Walker Tag holds the batch tag inside it. |
| On Generation Complete | (none) | Fires after Run All Walkers has run every registered walker. The idiomatic place to scatter marks, outline the walls and paint the tilemap. |

Every filtered trigger carries its filter as the row's own captured value, so an empty
comparison matches everything. Add the comparison you want on the event:

```
On Walker Finished  walker_id
  Condition: walker_id = "trunk"  -> ... (leave the comparison off and every walker matches)
```

### Shape recipes

Everything a walker draws comes out of four numbers pulling against each other:
`directions` decides how many headings exist at all, `max_turn` decides how many of them are
reachable from where the walker is already pointing, `turn_chance` decides how often it even
considers turning, and the brush or dig size decides thickness independently of the path.

The first six rows are the built-in presets, registered with exactly these numbers:

| Shape | Preset | `directions` | `max_turn` | `turn_chance` | Brush | Weights |
|---|---|---|---|---|---|---|
| Jittery cave, the classic | `cave` | 8 | 180 | 1 | 1 | none |
| Dungeon corridors, right angles | `corridors` | 4 | 90 | 0.15 | 1 | none |
| Zigzag ribbon, river or road | `river` | 3 | 45 | 0.35 | 2 | none |
| Ore vein, always descending | `ore_vein` | 8 | 90 | 1 | 1 | `2,6,9,6,2,0,0,0` |
| Lightning bolt or crack | `lightning` | 8 | 45 | 1 | 1 | `1,5,9,5,1,0,0,0` |
| Blob chamber, short and fat | `blob` | 8 | 180 | 1 | 4 | none |
| Smooth winding cavern | (tune it) | 8 | 45 | 1 | 1 | none |
| Wide corridors | (tune it) | 4 | 90 | 0.15 | dig size 5 by 1 | none |
| Straight shaft or lift well | (tune it) | 1 | any | any | 1 | none |

The Blob recipe is written elsewhere as a band of 30 to 50 steps; the preset takes it at its
midpoint of 40 so that a preset is one concrete walker. Every other preset carries 400 steps.

For an eight-heading walker with a start angle of 0, weight entry 0 is 0 degrees (right), 1 is
45 (down-right), 2 is 90 (straight down), 3 is 135, 4 is 180 (left), 5 is 225, 6 is 270 (up)
and 7 is 315. Change the start angle and the whole table rotates, because entry 0 is always the
start angle. That is why `1,5,9,5,1,0,0,0` peaks straight down and can never climb.

### Which trigger fires when

| You called | Per cell | Per walker | At the end |
|---|---|---|---|
| **Run All Walkers** | On Cell Carved | On Walker Finished | On Generation Complete |
| **Run Walkers By Tag** | On Cell Carved | On Walker Finished | On Walkers By Tag Complete |
| **Run Walker** | On Cell Carved | On Walker Finished | nothing |
| **Step Walker** | On Cell Carved | On Walker Finished | On Walker Stepped, per step |
| **Dilate Cells** / **Outline Cells** | On Cell Carved, with an empty Walker ID | nothing | nothing |
| **Set Cell** / **Clear Grid** | nothing | nothing | nothing |
| **Load State From Text** | nothing | nothing | nothing |

### Inspector properties

| Property | Default | What it does |
|---|---|---|
| `grid_width` / `grid_height` | `64` | The grid built at start-up, and the fallback Create Grid uses for a dimension of 0 or less. |
| `max_grid_size` | `2048` | Hard cap on both axes, so a bad expression fails loudly instead of reserving gigabytes. |
| `cell_size` | `32` | Pixel size of one cell, used only by the four coordinate expressions. |
| `origin_x` / `origin_y` | `0` | World position of the grid's top-left corner, for those same expressions. |
| `empty_value` | `0` | What a fresh grid is filled with, what an out-of-bounds read returns, and the only value Outline Cells may overwrite. |
| `start_seed` | *(empty)* | The seed the generator starts on. Empty derives one from the clock and remembers it. |
| `random_source` | `internal` | `internal`, `shared` (the Advanced Random autoload) or `injected`. |
| `debug_mode` | `false` | Warns about walker lifecycles, clamped grids, scatters that could not fit, a dry injected queue, and the four common reasons a map comes out empty. |

## Reading it from expressions - the Self section

Type `self` in any ƒx field, or open the ƒx **Expressions dictionary**, and **Self ▸ Behaviours**
lists this pack's knobs and value expressions as ready-to-insert chains once the behaviour is
attached:

- `$DrunkenWalkers.empty_value` inserts the **Empty Value** entry straight into any expression
- `$DrunkenWalkers.cell_size` inserts the **Cell Size** entry straight into any expression

The `$DrunkenWalkers` token stays selected after insert, so retargeting to your child's actual
name is one keystroke, or a node drag. Attaching this pack at runtime instead? Tick **Robust
behaviour lookups** in the dictionary and the same entries insert as
`get_node_or_null("DrunkenWalkers")` chains, which survive auto-named children. While **Live
Values** streams from a running game, the group upgrades to *Behaviours (live - on your node)*
and reads the RUNNING instance, so you can watch `Count Cells` climb while a walker digs.

## Use cases

### 1. The simplest possible cave

Four rows and a Label, before any art exists.

```
On Ready -> Map | Drunken Walkers: Set Seed  "first-cave"
         -> Map | Drunken Walkers: Add Walker From Preset  "cave", "main", 32, 32, "", 1
         -> Map | Drunken Walkers: Run All Walkers
         -> Preview | set text to Map.As Text(".#")
```

### 2. Painting it into a TileMapLayer

One row per value, no loop at all.

```
On Generation Complete -> Map | Drunken Walkers: Draw Cells To Tilemap  Ground, 1, 0, 0, 0
                       -> Map | Drunken Walkers: Draw Cells To Tilemap  Ground, 3, 0, 1, 0
```

### 3. Walls around the floor

Outline last, because it only ever overwrites empty cells and so cannot eat your water or ore.

```
On Generation Complete -> Map | Drunken Walkers: Outline Cells  1, 3
                       -> Map | Drunken Walkers: Outline Cells  3, 4   (a shadow ring outside the wall)
```

### 4. Widening a cave that came out spindly

```
On Function "WidenCaves" -> Map | Drunken Walkers: Run Walkers By Tag  "cave"
                         -> Map | Drunken Walkers: Dilate Cells  1, 1
                         -> Map | Drunken Walkers: Run Walkers By Tag  "water"
```

The rivers run after the dilation, so they survive it intact. Two iterations turn a one-cell
corridor into a five-cell hall, so raise that number carefully.

### 5. Enemies in the open, torches on the walls

The placement rule is the whole feature: no distance checks, no nested rows.

```
On Generation Complete -> Map | Drunken Walkers: Scatter Marks  12, "enemy", 1, interior, 6
                       -> Map | Drunken Walkers: Scatter Marks  30, "torch", 1, edge, 2
                       -> Map | Drunken Walkers: Scatter Marks  1, "exit", 1, interior, 0
```

### 6. Spawning what the marks stand for

```
On Mark Placed  tag
  Condition: tag = "enemy" -> spawn Grunt at (Map.Cell To World X(Map.Mark X), Map.Cell To World Y(Map.Mark Y))
```

Cell centres, so the sprite lands centred in its tile whatever the origin is.

### 7. Ammo along the path, never two clumped together

```
On Generation Complete -> Map | Drunken Walkers: Drop Marks Along Walk  "main", "ammo", 10, 0.5, 4
```

A candidate every ten steps, half of them kept, and never two within four cells.

### 8. A river that cuts through finished rock

Tags let you stage generation in passes, and a later pass sees what an earlier one carved.

```
On Function "Generate" -> Map | Drunken Walkers: Add Walker  "cave1", 20, 20, 500, 8, 180, "cave", 1
                       -> Map | Drunken Walkers: Add Walker  "cave2", 40, 30, 500, 8, 180, "cave", 1
                       -> Map | Drunken Walkers: Add Walker  "river", 0, 5, 200, 3, 45, "water", 2
                       -> Map | Drunken Walkers: Run Walkers By Tag  "cave"
                       -> Map | Drunken Walkers: Outline Cells  1, 3
                       -> Map | Drunken Walkers: Run Walkers By Tag  "water"
```

### 9. A tunnel that keeps its width around every corner

The square brush pinches at corners; the dig size turns with the walker and does not.

```
On Function "DigTunnel" -> Map | Drunken Walkers: Add Walker  "tunnel", 4, 20, 300, 4, 90, "", 1
                        -> Map | Drunken Walkers: Set Walker Dig Size  "tunnel", 5, 1
                        -> Map | Drunken Walkers: Run Walker  "tunnel"
```

### 10. A shaft that starts wide and tapers to a crawlspace

Dig size is live state, so change it partway through the walk.

```
On Function "NarrowingShaft" -> Map | Drunken Walkers: Add Walker  "shaft", 30, 2, 180, 8, 90, "", 1
                             -> Map | Drunken Walkers: Set Walker Dig Size  "shaft", 7, 1
                             -> Map | Drunken Walkers: Step Walker  "shaft", 40
                             -> Map | Drunken Walkers: Set Walker Dig Size  "shaft", 3, 1
                             -> Map | Drunken Walkers: Step Walker  "shaft", 40
                             -> Map | Drunken Walkers: Set Walker Dig Size  "shaft", 1, 1
                             -> Map | Drunken Walkers: Run Walker  "shaft"
```

A negative depth digs behind the walker instead, which is how a tunnel mouth flares out.

### 11. An ore vein that can only descend

```
On Function "BuildVein" -> Map | Drunken Walkers: Add Walker  "vein", 30, 0, 400, 8, 180, "ore", 2
                        -> Map | Drunken Walkers: Set Walker Direction Weights  "vein", "1,4,9,4,1,0,0,0"
                        -> Map | Drunken Walkers: Run Walker  "vein"
```

Entry 2 is straight down and carries the heaviest weight; the three zeros rule out every
upward heading, so the vein can never climb back toward the surface.

### 12. The map draws itself on the title screen

```
On Ready -> Map | Drunken Walkers: Create Grid  60, 40
         -> Map | Drunken Walkers: Set Seed  "title-screen"
         -> Map | Drunken Walkers: Add Walker  "show", 30, 20, 900, 8, 180, "", 1

On Every Tick -> Map | Drunken Walkers: Step Walker  "show", 3

On Walker Stepped -> Digger | set position to (Map.Cell To World X(Map.Walker X), Map.Cell To World Y(Map.Walker Y))
                  -> Digger | set rotation to Map.Walker Angle
                  -> Progress | set value to 100 * (1 - Map.Walker Steps Left / 900.0)
```

### 13. A branch that starts where the trunk stopped

Walker X and Walker Y inside On Walker Finished are the walker's final cell, which is the
idiomatic way to grow branching structures.

```
On Walker Finished  walker_id
  Condition: walker_id = "trunk"
    -> Map | Drunken Walkers: Add Walker  "branch", Map.Walker X, Map.Walker Y, 120, 8, 180, "branch", 1
    -> Map | Drunken Walkers: Run Walker  "branch"
```

### 14. Autotiling from the neighbour count

Eight matching neighbours means a fully enclosed floor tile; fewer means an edge, and the
border needs no special case because off-grid neighbours never match.

```
On Generation Complete
  Repeat Map.Count Cells(1) times
    -> Ground | set cell (Map.Cell X By Index(1, index), Map.Cell Y By Index(1, index))
               to tile Map.Neighbour Count(Map.Cell X By Index(1, index), Map.Cell Y By Index(1, index), 1)
```

### 15. Clicking a cell to ask what is there

```
On Mouse Clicked
  Condition: Map | Is Inside Grid  Map.World To Cell X(mouse.x), Map.World To Cell Y(mouse.y)
  Condition: Map | Is Cell Value  Map.World To Cell X(mouse.x), Map.World To Cell Y(mouse.y), 1
    -> Selected | set text to "walkable floor"
```

### 16. Saving a half-built world, and resuming it exactly

The saved state carries the random stream's own position, so the remaining walk is the walk
that would have happened without the save.

```
On Function "QuickSave" -> SaveSystem | Save Value  "map", Map.Save State As Text

On After Load -> Map | Drunken Walkers: Load State From Text  SaveSystem.Load Value("map", "")
              -> Map | Drunken Walkers: Draw Cells To Tilemap  Ground, 1, 0, 0, 0
```

Repaint from the grid rather than waiting for triggers: loading is silent by design.

### 17. Regenerating instead of saving

For a game that can rebuild its world, two numbers are a smaller save than a grid, and only
determinism makes it possible.

```
On After Load -> Map | Drunken Walkers: Create Grid  64, 64
              -> Map | Drunken Walkers: Set Seed  RunSeed & "-floor-" & FloorNumber
              -> call function "RegisterWalkers"
              -> Map | Drunken Walkers: Run All Walkers
```

### 18. Two independent generators in one scene

Because every verb names its node, an overworld and a dungeon can generate side by side
without sharing a single value.

```
On Ready -> Overworld | Drunken Walkers: Set Seed  MasterSeed & "-world"
         -> Dungeon   | Drunken Walkers: Set Seed  MasterSeed & "-crypt"
         -> Overworld | Drunken Walkers: Run All Walkers
         -> Dungeon   | Drunken Walkers: Run All Walkers
```

### Other use cases

**Deterministic crack VFX in lockstep multiplayer.** Every client generates the same crack from
the same seed instead of streaming the geometry, so a shattering window costs one string on the
wire and looks identical on every machine.

**Ink and calligraphy puzzles.** A three-heading walker with a low turn chance and a dig size of
5 by 1 is a brush stroke; regenerating from a new seed gives a new glyph to trace.

**A garden that grew while you were away.** Save the state, and on the next launch top the
walkers up with Set Walker Steps by however many hours passed, so the roots and vines carry on
from exactly where they stopped.

**Difficulty variants from one layout.** Keep the terrain seed fixed and put the difficulty into
the seed you set before the mark passes only, so hard mode is the same cave with a different,
reproducible population.

**Fog of war as a second value layer.** Run a second walker set carving value 5 over the same
grid, and read Count Cells(5) plus the index expressions as the revealed region without touching
the terrain values at all.

## Tips and common mistakes

- **Set the seed before you generate, not after.** Set Seed resets the stream, so calling it
  after Run All Walkers changes nothing about the map you just built. It is the single most
  common reason a map is not reproducible.
- **Create Grid wipes walkers and marks, not just cells.** That is what makes it a clean level
  reset, and it also means registering walkers before calling it silently throws them away.
  Create the grid first.
- **Clear Grid does not reset walkers.** Used between levels it leaves the previous level's
  walkers registered with exhausted budgets, so Run All Walkers appears to do nothing.
- **Set Cell and Clear Grid do not fire On Cell Carved.** They are documented silent writes, so
  a tilemap painted from that trigger will be missing your hand-placed cells. Paint from Count
  Cells and the index expressions instead, which see every cell however it got there.
- **On Walker Stepped only fires from Step Walker.** Batch runs skip it deliberately for speed.
  Animating means Step Walker; running in bulk means On Cell Carved or a loop afterwards.
- **A low max turn alone does not make a smooth path.** At the default turn chance of 1 the
  heading performs its own random walk and the result still curls. Drop the turn chance to
  around 0.15 to 0.3 for roads and rivers.
- **Two headings cannot turn unless the max turn is 180.** They sit 180 degrees apart, so
  anything smaller draws a dead straight line; 180 gives the opposite problem, a walker that
  reverses on the spot and carves eight cells out of sixty steps.
- **Diagonal movement leaves holes.** A diagonal step moves on both axes at once and never
  touches the cell between. The fix is thickness, not direction: a brush size of 2 is solid.
- **Borders repel, they do not stop.** A walker that reaches an edge re-rolls inward and tends
  to run along it, leaving a suspiciously straight line down the side of the map. Give it fewer
  steps, start it further in, or generate on a grid slightly larger than the area you paint.
- **Dig depth is signed, dig width is not.** A negative depth digs behind the walker on
  purpose. A negative width is not an error, but its sign is ignored, because "across the
  heading" has no front and back. Use 0, never a negative, to fall back to the brush size.
- **Dilate converts other terrain, Outline does not.** Dilating floor eats water where they
  touch; outlining only ever overwrites the Empty Value. Dilate before you carve what you want
  to keep, and outline last.
- **The count in Scatter Marks is a maximum, not a promise.** Tight spacing, a small eligible
  region or a placement rule that matches almost nothing all quietly place fewer. Debug Mode
  says how many it managed.
- **Interior placement finds nothing on thin corridors.** Interior needs all eight neighbours to
  match, which a one-cell-wide walk never has. Dilate first, or use Any.
- **Empty filters mean "match everything", except on Run Walkers By Tag.** For the triggers an
  empty comparison matches all. For Run Walkers By Tag an empty tag runs only the walkers that
  genuinely have no tag. That asymmetry catches people out.
- **Do not mix an unseeded random into generation.** One `randf()` in a walker's start position
  is enough to make an otherwise perfect setup unreproducible. Put the variation in the seed
  string instead.
- **Reordering your generation rows changes the map, by design.** Two swapped Scatter Marks
  rows give a different but equally valid world from the same seed. Build generation as one
  function whose row order never varies, and vary the seed rather than the sequence.
- **Turn Debug Mode off for release.** The warnings are per-walker and per-pass, and they are
  for you, not for your players.

## Already written it by hand? It reads as this pack

A hand-rolled drunkard's walk is a `PackedInt32Array` grid, a heading float, a `randf()` per
step and a `for` loop that clamps to the bounds - and it opens on the sheet as exactly those
rows, because a sheet is the script. What it does not open as is a contract: the moment you add
a second walker, a turn-angle clamp, a minimum spacing rule or a save, you are writing the parts
of this pack one at a time, and the first `randf()` you leave unseeded costs you reproduction.

The pack is itself an event sheet. Open
`eventsheet_addons/drunken_walkers/drunken_walkers_behavior.gd` in the editor and every walker
step, every placement rule and every trigger is a row you can read and change - so adopting it
is not giving up the code you would have written, it is starting from a version of it that
already reproduces.
