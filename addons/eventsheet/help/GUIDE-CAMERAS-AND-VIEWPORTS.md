# Cameras, Views and How The Game Fills The Screen

Four questions live in this corner of the vocabulary, and they are usually answered in four
different places by four different people:

- **Where is the camera looking, and how does it get there?** The Camera shelf, in both dimensions.
- **What is under the pointer?** A ray from a camera into the world.
- **Is there a second picture of the game anywhere?** A view - Godot's `SubViewport` - which is the
  minimap, the rear-view mirror, the security monitor and the character portrait.
- **How does the game meet a screen it was not drawn for?** The scaling words, and the one
  antialiasing switch a graphics menu actually needs.

Everything on this page compiles to plain Godot: `Camera2D` and `Camera3D` members,
`RenderingServer` calls, `Window` content-scale settings, `SubViewport` properties and
`CanvasLayer` / `Parallax2D` fields. There is no camera manager, no view registry and no screen
singleton. A project that already wrote these lines by hand opens as these rows, and the last
section is the table of exactly which lines those are.

## Table of Contents

1. [The 2D camera, and the four things a platformer asks of it](#the-2d-camera-and-the-four-things-a-platformer-asks-of-it)
2. [Where the level ends](#where-the-level-ends)
3. [What the camera is showing, asked from both ends](#what-the-camera-is-showing-asked-from-both-ends)
4. [The 3D camera: the shot, the lens and the clip range](#the-3d-camera-the-shot-the-lens-and-the-clip-range)
5. [What is under the cursor](#what-is-under-the-cursor)
6. [A shot list for a camera](#a-shot-list-for-a-camera)
7. [A second picture of the same world](#a-second-picture-of-the-same-world)
8. [Keeping a still](#keeping-a-still)
9. [How the game fills a window it was not drawn for](#how-the-game-fills-a-window-it-was-not-drawn-for)
10. [Rendering 3D smaller than the window, and smoothing the edges](#rendering-3d-smaller-than-the-window-and-smoothing-the-edges)
11. [Layers: fixed on the screen, or moving with the world](#layers-fixed-on-the-screen-or-moving-with-the-world)
12. [Parallax, on both of Godot's parallax nodes](#parallax-on-both-of-godots-parallax-nodes)
13. [What a project you already wrote opens as](#what-a-project-you-already-wrote-opens-as)
14. [Tips and common mistakes](#tips-and-common-mistakes)

## The 2D camera, and the four things a platformer asks of it

Six rows cover pointing a camera somewhere, and they have been there from the start: **Make
Current**, **Set Zoom**, **Set Offset**, **Set Scroll Limits**, **Set Smoothing** and **Scroll
Toward**. They are enough to open a game with.

What they leave out is everything the day after, and it is always the same four things.

| Name | What it does | Ships as |
|------|--------------|----------|
| Let The Target Drift | A dead zone: the followed thing may wander this far from the middle before the camera moves at all | six lines - two enable flags and the four margins |
| Follow Tightly | The other half of the switch: no dead zone, target dead centre | `drag_horizontal_enabled = false` and its vertical twin |
| Snap To Target Now | Puts the camera where it is heading, this frame, instead of easing there | `reset_smoothing()` |
| Smooth Turns | Eases the camera's rotation the way Set Smoothing eases its position | `rotation_smoothing_enabled` and `rotation_smoothing_speed` |

**Why the drift is two numbers and not four.** Godot spells a dead zone as four independent margins
plus two enable flags: six fields to fill in to say one thing. Almost nobody wants a lopsided one.
The dead zone people mean is "this much slack sideways, this much slack up and down", so the row
asks for those two fractions and writes all six lines - as six plain assignments, so a game that
really does want an asymmetric box edits the line rather than fighting the row. The numbers the
field opens on are Godot's own defaults, asked of ClassDB rather than guessed, so a dropped row
starts exactly where the Inspector starts.

<!-- caption: A dead zone while the player runs, and no dead zone once the boss is up -->
```gdscript
# A camera that lets the player wander a fifth of the screen sideways and a tenth up and down
# before it moves at all - and glues itself to them the moment the fight starts.
extends Camera2D

var boss_fight: bool = false


func _ready() -> void:
	drag_horizontal_enabled = true
	drag_vertical_enabled = true
	drag_left_margin = 0.2
	drag_right_margin = 0.2
	drag_top_margin = 0.1
	drag_bottom_margin = 0.1


func _process(_delta: float) -> void:
	if boss_fight:
		drag_horizontal_enabled = false
		drag_vertical_enabled = false
```

**Snap To Target Now is one word for the trap nobody can name.** `reset_smoothing()` does not turn
smoothing off; it teleports the smoothed position to where it is already heading. That is the fix
for the shot that pans grandly across the whole level on the first frame after a respawn or a scene
change, and it is impossible to guess from a property list. It is a row so that nobody has to.

```
On Player Respawned  ->  Camera | Snap to the target now
                      ->  Camera | Fit limits to <the tiled area of Ground>
```

## Where the level ends

A camera stops at the edges of the level, and the edges are known one of two ways: the tiles
somebody painted, or a rectangle somebody chose. That difference is a **value**, not a branch inside
a verb, which is why it is two rows.

| Name | Kind | What it answers |
|------|------|-----------------|
| Fit Limits To | Action | Sets the four scroll limits from a rectangle, in whole pixels, which is what Godot stores them as |
| Tiled Area | Expression | The rectangle the painted tiles cover, in world units |

<!-- caption: The camera fits itself to the level somebody painted -->
```gdscript
# The limits are measured, not typed in, so they keep being right while the level grows.
extends Camera2D

@onready var ground: TileMapLayer = $"../Ground"


func _ready() -> void:
	var area: Rect2 = Rect2(ground.to_global(ground.map_to_local(ground.get_used_rect().position) - Vector2(ground.tile_set.tile_size) * 0.5), ground.to_global(ground.map_to_local(ground.get_used_rect().end - Vector2i.ONE) + Vector2(ground.tile_set.tile_size) * 0.5) - ground.to_global(ground.map_to_local(ground.get_used_rect().position) - Vector2(ground.tile_set.tile_size) * 0.5))
	limit_left = int(area.position.x)
	limit_top = int(area.position.y)
	limit_right = int(area.end.x)
	limit_bottom = int(area.end.y)
```

Tiled Area is an expression rather than a hidden step inside the limits row because the same
rectangle answers three other questions: where a minimap's box goes, whether a spawn point is
outside the view, and whether something is far enough away to stop updating. An unpainted layer
measures nothing, so the answer is an empty rectangle rather than a wrong one. Camera limits are
axis-aligned numbers, so a **rotated** tile layer has no answer to give here and the row does not
pretend otherwise; a moved or scaled one does, which is why both corners go out through `to_global`.

## What the camera is showing, asked from both ends

**View Rectangle** is what this camera is showing right now, in world units, zoom included. It is
the frame every off-screen cull, minimap box and spawn-just-outside-the-view is measured against,
and it is a value you can print while you work out why something is not where you expected.

**Is Inside Camera View** is the same rectangle asked from the other end: a node, a camera, and a
margin. It lives on `Node2D`, so a sheet on an enemy can ask the question without being a camera at
all, and it reads false when there is no camera, so a scene change cannot fault it.

> **It is not Is On Screen, and both are honest.** The shipped **Is On Screen** row asks Godot's own
> visibility notifier about the node's whole drawn shape, which is the better question for a large
> sprite whose centre is off screen while half of it is still visible. Is Inside Camera View is a
> point test against a rectangle you can also read, print and grow by a margin. They answer
> different questions and neither replaces the other.

**Current Camera** hands back the `Camera2D` the player is looking through right now, or nothing
when there is none. It takes no host, because any sheet may ask it - a row scoped to `Camera2D`
could only be asked by the camera, which already knows. **Current Camera (3D)** is the twin, for the
dimension where the live camera changes on every cutscene and every vehicle you climb into.

```
Every Frame + Enemy is inside the view of the current camera, margin 200   ->  Enemy | Show
Every Frame + [not] Enemy is inside the view of the current camera, margin 200  ->  Enemy | Hide
```

## The 3D camera: the shot, the lens and the clip range

The field-of-view rows shipped first - **Tween Camera FOV**, **Adjust Camera FOV** and the **Camera
FOV** expression - and they are still the rows for a zoom, a sprint punch or an aim-down-sights.
Beside them:

| Name | Kind | What it does |
|------|------|--------------|
| Look At Over Seconds | Action | Turns the camera to face a node over time instead of snapping |
| Switch To Perspective | Action | The ordinary shot, plus how wide it sees in degrees |
| Switch To Orthogonal | Action | The flat shot, plus how many world units tall the view is |
| Set Clip Range | Action | How close and how far the camera draws |
| Current Camera (3D) | Expression | The `Camera3D` the player is looking through |

**Look At Over Seconds is a shot; Look At is a cut.** The shipped **Look At** row (and its
`LookAtSafeUp` / `Look At Flat` neighbours) point a node at something this frame, which is what a
turret wants. Look At Over Seconds walks the *shortest rotation* between where the camera is looking
and where it should look, over a number of seconds, so the shot never rolls sideways on the way and
never tips over when the target is nearly overhead. A camera and a target standing in the same spot
have no direction between them, so the row does nothing at all rather than erroring.

<!-- caption: A camera that turns to the boss over three quarters of a second -->
```gdscript
# The guard is the row's, not yours: a zero-length aim is skipped rather than passed to a Basis
# that cannot be built from it.
extends Camera3D


func face(target: Node3D) -> void:
	var __aim_a1: Vector3 = target.global_position - global_position
	if __aim_a1.length_squared() > 0.000001:
		var __from_a1: Basis = global_basis
		var __to_a1: Basis = Basis.looking_at(__aim_a1, Vector3.UP)
		create_tween().tween_method(func(__weight_a1: float) -> void: global_basis = __from_a1.slerp(__to_a1, __weight_a1), 0.0, 1.0, maxf(0.75, 0.001))
```

The three locals carry the row's own stable id so that two timed look-ats in one function cannot
collide. Written by hand, the whole run reads back as the row and re-emits byte for byte, with your
own names for the locals kept.

**Why the projection is two rows and not one with a mode.** A perspective camera is described by an
**angle** and a flat one by a **width**. A single row would have to show both fields and mean one of
them, so there are two rows, each with the field its own answer needs.

**Set Clip Range** is the row to reach for when distant surfaces flicker against each other. Keep
the near value as large as the game allows: a very small near value is the usual cause, and it is
almost never the far value's fault.

## What is under the cursor

There are two ways to ask, and they are not the same question.

**The active camera asks it for you.** `raycast_aces` already ships the whole family, and these are
the rows most games want:

| Name | Kind | What it answers |
|------|------|-----------------|
| Cast Ray From Mouse Into (3D) | Action | Casts once and stores several facts about the hit |
| Mouse Ray Hits Something (3D) | Condition | Whether the cursor is over anything solid |
| Mouse Ray Collider (3D) | Expression | The object it hit |
| Mouse Ray Point (3D) | Expression | Where in the world it hit |
| Cursor Is Over Object (3D) | Condition | Whether the cursor is over *this* object |

**A named camera asks it of its own viewport.** Two rows on `Camera3D` - **Something Is Under The
Cursor** and **Point Under The Cursor** - ask the same ray, but from the camera the row is on, in
that camera's own viewport, with the collision layers named on the row. That is the question a
split-screen game or a picture-in-picture view has to ask, because the active camera is not
necessarily the camera the pointer is inside.

> **There is no "the hit is offered to the rows below" mechanism, and there deliberately is not
> one.** A condition asks and an expression answers. Point Under The Cursor answers with the surface
> it landed on, or with the far end of the ray when it landed on nothing - somewhere the player is
> genuinely pointing, rather than the origin of the world. A build ghost that teleports to zero
> looks like a physics bug and is not one.

```
Every Frame + something is under the cursor within 1000  ->  Ghost | Set Position (3D) to <the point under the cursor within 1000>
```

## A shot list for a camera

A camera that has to travel, hold, blend and cut is a **shot list**, and that is a behaviour rather
than a shelf of rows. The **Camera Rail** pack attaches under the camera you want directed:

- **Fly Along** walks that camera down a drawn `Path2D` over a number of seconds.
- **Hold** parks it on a beat.
- **Blend To** travels it onto another camera - transform with the zoom in 2D, with the field of
  view in 3D - and hands the view over.
- **Cut To** switches outright.
- **On Shot Finished** and **On Blend Finished** end every shot, so a cutscene is a chain of rows
  rather than a coroutine, and **Is Flying** and **Rail Progress** drive the letterbox and the bar.

**Camera Rail 3D** is the twin, on `Camera3D` and `Path3D`, and it adds the two things only three
dimensions have: a node the camera keeps in frame for the whole flight, and a lens that travels with
the blend. One guide covers both: [Camera Rail](Addons/Camera-Rail.md).

Shake and the zoom or FOV punch from the **Juice** packs ride on whichever camera is current - the
rail's own included - so a shot can be flying and shaking at once without either pack knowing about
the other.

## A second picture of the same world

A `SubViewport` is how a Godot project draws a second picture: the minimap, the rear-view mirror,
the security monitor, the screen standing in a 3D room, the portrait that renders a real model
rather than a painted sprite. The node itself is plumbing, and everything a game does with one is a
property nobody remembers the spelling of. Five rows are the five questions actually asked.

| Name | Kind | What it answers |
|------|------|-----------------|
| Set View Size | Action | How many pixels the view renders |
| Share The World (2D) | Action | Which 2D world it shows |
| Share The World (3D) | Action | Which 3D world it shows |
| Mouse Position In View | Expression | Where the pointer is inside that view |
| Save A Still Of A View | Action | A PNG of what it is drawing |

**Sharing the world is the line between a minimap and a black rectangle.** A `SubViewport` gets a
world of its own unless something says otherwise, and a world of its own is an empty stage: the
camera inside it renders nothing, forever, with no error anywhere. Share The World points it at the
world another viewport is already drawing.

<!-- caption: A minimap: a small view, the running world, one camera -->
```gdscript
# 200 by 120 is the cost of this minimap. Rendering the whole window and squeezing the result into
# the corner costs the whole window.
extends SubViewport


func _ready() -> void:
	size = Vector2i(200, 120)
	world_2d = get_viewport().world_2d
```

**Set View Size is the cost of the view.** A minimap drawn into a 200 by 120 panel should render 200
by 120. Whole pixels only, which is what a view is measured in.

**Where the pointer is inside a view is not where it is on the window.** A view has a coordinate
space of its own, so an in-world screen, a magnifier or a rear-view mirror asks Mouse Position In
View. Handing a click *to* the UI a view is painting onto a surface is the shipped **Send Input To
Surface** row.

Two neighbours the Views shelf deliberately does not duplicate:

- **How often a view redraws** is **Set Surface Redraw**, which writes `render_target_update_mode`.
  It offers four answers now: only when seen (the cheap one and the right default), always, **once
  now** - a single frame and then stop, which is what a thumbnail or a still wants - and never,
  which parks the view without freeing it.
- **The live picture** is **Rendered As An Image**, which is already `get_texture()` and reads the
  same way pointed at a `SubViewport`.

## Keeping a still

Four rows write a picture to disk, and they are not interchangeable.

| Name | What it photographs | Waits for the frame? |
|------|---------------------|----------------------|
| Take Screenshot | The window's own viewport | No |
| Screenshot | The window, as a value | No |
| Save Image As | An image value you already have | Not applicable |
| Save A Still Of A View | **Any** viewport, named on the row | **Yes** |

**The waiting is the whole row.** Reading a viewport's texture before the frame has finished drawing
hands back whatever happened to be in the buffer: usually black, sometimes the frame before. So Save
A Still Of A View opens with `await RenderingServer.frame_post_draw`. That is not an optimisation,
it is the difference between a picture and a bug report.

<!-- caption: A save-slot thumbnail, taken from the minimap view -->
```gdscript
# The await is what makes this a coroutine, so keep the event that holds it off a per-frame trigger.
extends Node


func snapshot() -> void:
	await RenderingServer.frame_post_draw
	$Minimap.get_texture().get_image().save_png("user://slot_1.png")
```

Because it awaits, the event holding it suspends. The Doctor knows: a coroutine action under a
per-frame trigger is flagged, because the next tick fires while the first one is still waiting.
`user://` is the writable folder on every platform, and it is what the field opens on - a `res://`
path works in the editor and is read-only in an exported game.

## How the game fills a window it was not drawn for

A game is drawn for one size. Players have every other size. Four rows say what happens in between,
and each is one question rather than one Godot setting.

| Name | The question | Choices |
|------|--------------|---------|
| Scale The Game | What gets stretched | Fit the layout (text stays crisp) / Stretch the whole picture / Free |
| Fit The Shape | What the extra space becomes when the window is a different **shape** | Keep the shape with bars / Fill and distort / Keep the width / Keep the height / Expand |
| Keep Pixels Sharp | Whether the scale may be a fraction | Whole numbers only / any fraction |
| Pixel Size | How big one drawn pixel is, on top of everything else | a number |

**Fit and Stretch are the two real answers.** *Fit* scales the layout and leaves text and interface
rendering at the window's own resolution, so a menu stays crisp on a big monitor. *Stretch* blows the
whole rendered frame up, which is exactly what a pixel-art game wants and exactly what a text-heavy
game does not. *Free* scales nothing and simply shows more or less of the world.

<!-- caption: A pixel-art game, set up in four lines -->
```gdscript
# 320 by 180 art, whole-number scaling only, and no distortion on a shape it was not drawn for.
extends Node


func _ready() -> void:
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	get_window().content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER
	get_window().content_scale_factor = 2.0
```

**Keep Pixels Sharp is the row nobody knows they need.** A pixel-art game scaled by 2.5 draws some
source pixels twice and some three times. That is the uneven, shimmering look everybody sees and
nobody can name, and whole-numbers-only trades it for bars at the edges. Anything that is not pixel
art wants the fraction.

> **The Doctor says it when the two disagree.** A file that keeps pixels sharp and then asks for a
> pixel size of `2.5` gets `2`, because whole pixels only rounds the scale down. That is an **info**
> note in the Ship It section, not a warning: both halves are deliberate settings and the fix is a
> decision rather than a defect. It is silent unless the number is really a literal fraction, since
> a factor worked out at run time is nobody's business to guess at.

## Rendering 3D smaller than the window, and smoothing the edges

Two rows, two questions a player would actually ask.

**Render 3D At** renders the 3D scene at a percentage of the window and upscales it back, and it
asks *how* on the same row. Seventy per cent with a sharpening upscaler often looks better than
seventy per cent plain and costs the same, which is the entire reason a resolution slider is worth
shipping. 2D drawing and the interface are untouched: they stay at full resolution, which is why the
menu over a 70% scene is still sharp. **Upscale With** is the upscaler alone, for a menu that offers
the two switches separately.

**Smooth Edges With** is the one antialiasing switch a graphics menu needs. Godot spreads
antialiasing over a screen-space mode, a temporal flag and a sample count; a player asks one
question. Pick a word and every other technique is turned off, so nobody ends up paying for two at
once:

| Word | What it costs |
|------|---------------|
| Nothing | hard edges, cheapest |
| FXAA | cheap, a little soft |
| Temporal | sharp, can shimmer while the camera moves |
| 2 / 4 / 8 samples | the clean, expensive answer on a 3D scene |

The emitted code names the decision once, in a local of its own, and then applies it to each switch
in turn - which is what makes it readable rather than four repeated ternaries. **Set Temporal AA**
and the frozen per-technique rows (Set MSAA 2D / 3D, Set Screen-Space AA, Set 3D Resolution Scale)
are all still there and still the right rows for a menu that offers them separately.

**Renderer Is** answers *which* renderer, beside the shipped **Uses Modern Renderer**, which can only
tell two of the three apart. Screen-space reflections, indirect light, global illumination and
volumetric fog are Forward+ only, and Mobile answers yes to "modern" while drawing none of them - so
a graphics menu asks Renderer Is before it offers them.

```
On Ready + [not] renderer is forward_plus  ->  ReflectionsRow | Hide
```

## Layers: fixed on the screen, or moving with the world

A `CanvasLayer` either follows the camera or it does not, and that one flag is the whole difference
between a HUD and a layer of world that happens to have its own drawing order.

| Name | What it does | Ships as |
|------|--------------|----------|
| Stay Fixed On Screen | Pins the layer to the screen: HUD, pause menu, letterbox | `follow_viewport_enabled = false` |
| Move With The World | Lets the camera move it: scenery behind, effects over | `follow_viewport_enabled = true` |
| Draw Above | One step in front of another layer, whatever number that one is on | `layer = $Other.layer + 1` |
| Draw Below | One step behind it | `layer = $Other.layer - 1` |
| Offset Layer | Nudges the whole layer without touching anything on it | `offset = ...` |

**Draw Above and Draw Below are relative on purpose.** Two hand-typed layer numbers stop meaning
what they meant the day somebody inserts a third layer between them. A layer that takes its
neighbour's number plus one keeps its order through every insertion.

These sit on the same **Layers** shelf as the object-side rows that already shipped - **Z Order**,
**Move To Layer** and **Set Layer Order** - because a reader looking for "layers" should find all of
it in one place rather than half of it under a second heading. Those three say where an *object*
sits; these say what the *layer* does.

**Offset Layer is a HUD sliding in from the edge**, a background pushed a little to one side, or a
shake that leaves the world completely alone.

## Parallax, on both of Godot's parallax nodes

A parallax layer scrolls at a fraction of the camera. Godot has two nodes for this and a real
project meets both: **Parallax2D** is the modern one, and **ParallaxLayer** inside a
**ParallaxBackground** is the older pair that every project older than Godot 4.3 is built on. The
same words are mapped onto both, so a project of either age reads as sentences.

| Name | Node | Ships as |
|------|------|----------|
| Scroll At | Parallax2D | `scroll_scale = ...` |
| Repeat Every | Parallax2D | `repeat_size = ...` |
| Drift | Parallax2D | `autoscroll = ...` |
| Scroll Offset | Parallax2D (expression) | `scroll_offset` |
| Scroll At (Background Layer) | ParallaxLayer | `motion_scale = ...` |
| Repeat Every (Background Layer) | ParallaxLayer | `motion_mirroring = ...` |

**The words are the same because the idea is the same.** `scroll_scale` and `motion_scale` are one
fraction under two spellings; `repeat_size` and `motion_mirroring` are one tiling distance. A reader
who has learned either pair has learned the other.

**Drift is the exception, and it says so by being absent.** Parallax2D has an `autoscroll` of its
own and the older node has none, so the older half ships two rows rather than three. Nothing pretends
the third one exists.

<!-- caption: A sky that drifts on its own and a hill layer at half speed -->
```gdscript
# Below 1 is behind the action and reads as distance. Above 1 is in front of it.
extends Parallax2D


func _ready() -> void:
	scroll_scale = Vector2(0.5, 1)
	repeat_size = Vector2(1920, 0)
	autoscroll = Vector2(-20, 0)
```

Set the repeat distance to the artwork's own width and the seam is invisible; a zero on an axis means
no repeating along it. Drift moves a layer whether the camera moves or not, which is how a starfield
lives behind a menu that has no camera at all.

## What a project you already wrote opens as

None of this needs a sheet to have been used. Open a `.gd` file you wrote by hand and these are the
lines that come back as rows rather than as verbatim code.

| What you wrote | What it opens as |
|----------------|------------------|
| `reset_smoothing()` | Snap To Target Now |
| the two drag flags and four margins, adjacent | Let The Target Drift |
| `drag_horizontal_enabled = false` + the vertical twin | Follow Tightly |
| `rotation_smoothing_enabled` + `rotation_smoothing_speed` | Smooth Turns |
| four `limit_*` assignments off one rectangle | Fit Limits To |
| `projection = Camera3D.PROJECTION_PERSPECTIVE` + `fov = ...` | Switch To Perspective |
| `projection = Camera3D.PROJECTION_ORTHOGONAL` + `size = ...` | Switch To Orthogonal |
| `near = ...` + `far = ...`, adjacent, in that order | Set Clip Range |
| the aim, the guard and the Basis slerp tween | Look At Over Seconds |
| `world_2d = ....world_2d` | Share The World (2D) |
| `follow_viewport_enabled = false` | Stay Fixed On Screen |
| `scroll_scale = ...` / `motion_scale = ...` | Scroll At / Scroll At (Background Layer) |
| `content_scale_mode` / `_aspect` / `_stretch` / `_factor` | Scale The Game / Fit The Shape / Keep Pixels Sharp / Pixel Size |

**A run of statements is claimed narrowly, on purpose.** `near` and `far` are ordinary words, and a
project could have two adjacent lines setting two variables by those names. What makes the pair a
Set Clip Range is that they are adjacent, at the same indentation, in that order, and that either
both carry a receiver or neither does. Anything looser is claimed by nothing and keeps the reading it
already had. The bytes are unaffected either way: a run is spliced back exactly as it came in.

**Two rows are authoring words only, and that is deliberate.** **Set View Size** writes `size = ...`,
which is also a Control's size, a box shape's size and a dozen more; **Offset Layer** writes
`offset = ...`, which is the line the shipped Set Offset row already speaks for. Admitted to the
reading, the first would relabel every `size = ...` line in every project as a view being resized.
Both stay perfectly good rows to *write* with - a view really is sized that way - and the emitted
bytes are identical either way, so the reading is left to the sentence that already covers those
lines.

## Tips and common mistakes

- **A second view showing nothing is almost always the world.** A `SubViewport` with no shared world
  renders an empty stage in silence. Share The World (2D) or (3D) is the one line.
- **Render the view at the size you show it at.** A 200 by 120 minimap that renders 1920 by 1080 and
  then squeezes costs the whole window, every frame, for a panel in the corner.
- **A still taken without waiting is black.** Save A Still Of A View awaits the frame; Take
  Screenshot does not. If you write the two lines yourself, keep the `await` in front.
- **A coroutine row under a per-frame trigger is a bug the Doctor already knows.** Save A Still Of A
  View suspends the event holding it. Put it under a key press or a signal, not under Every Tick.
- **`user://` is the only place an exported game may write.** `res://` is read-only outside the
  editor, and a still saved there works perfectly right up until you ship.
- **Whole pixels and a fractional pixel size cancel each other out.** Ask for 2.5 while keeping
  pixels sharp and the window gives you 2. Pick one.
- **Smooth Edges With turns the others off.** That is its job. If a graphics menu needs to leave two
  techniques on at once, use the frozen per-technique rows instead.
- **Zoom is part of the view rectangle.** View Rectangle already divides by `zoom`, so a culling
  check written against it keeps working when the camera zooms out. A rectangle built from the
  window size alone does not.
- **Layer numbers typed by hand drift.** Draw Above and Draw Below keep a pair in order through every
  layer somebody inserts between them later.
- **A rotated tile layer has no axis-aligned area.** Tiled Area answers for a moved or scaled layer;
  a rotated one has no rectangle to give, and camera limits are rectangles.
