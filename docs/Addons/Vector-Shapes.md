# Vector Shapes - Crisp Lines, Discs And Dashes You Place

Seven 2D nodes that draw themselves: a **Line**, a **Disc**, a **Rect**, a **Polygon**, a
**Polyline**, a **Triangle** and a **Regular Polygon**. Each is one quad wearing one
distance-field canvas shader, so the outline is solved per pixel: a ring is round at 4x zoom,
a hairline is one crisp pixel, and there is no texture to author and nothing tessellated on
the CPU.

Ten more nodes do the same in 3D: **Line 3D**, **Disc 3D**, **Rect 3D**, **Polygon 3D**,
**Polyline 3D** and **Regular Polygon 3D**, plus a **Sphere**, a **Cuboid**, a **Cone** and a
**Torus**. They read the same drawing - one shader include, shared by both halves - so a dash
tuned on a 2D line and the same dash on its 3D twin cannot drift apart.

You add them from Godot's own Create Node dialog, tune them in the Inspector, and drive them
from rows.

## Where this pack shines

- **A cooldown ring that is one node.** A Disc with an inner radius and two angles is a disc,
  a ring, a pie and an arc. `Set Arc` from 0 to 360, then tween `end_angle` down.
- **An aim line that stays one pixel wide.** Thickness in screen units keeps its weight
  however far the camera zooms, and on every phone.
- **Marching ants on a placement footprint.** Tick **Dashed**, pick a count, `Scroll Dashes`
  at 1 per second. `Scroll Dashes` at 0 stops them and parks the tick with them.
- **A red-to-green health arc with no gradient texture.** Colour mode `angular`, two
  swatches.

## Setup

1. **Create Node** ▸ search for `Line`, `Disc`, `Rect`, `Polygon`, `Polyline`, `Triangle` or
   `Regular Polygon` (they sit under Node2D).
2. Drag its handles in the viewport, or type its numbers in the Inspector. The shape draws in
   the editor as well as in the game.
3. Drop rows on it from the picker. Every row here works on any of the seven, so the sheet
   reads the same whichever you picked.

```
On cooldown started -> CooldownRing | Set Arc: 0, 360
                    -> CooldownRing | Tween Property: end_angle, 0, Ability.cooldown
Is placing          -> Footprint    | Scroll Dashes: 1
```

## The seven shapes

| Node | What it is | Its own fields |
|---|---|---|
| **Line** | A straight line from the node's origin to a point you drag. | End point |
| **Disc** | A disc, and by an inner radius and two angles also a ring, a pie and an arc. | Radius, inner radius, start angle, end angle |
| **Rect** | A rectangle with rounded corners (one number, or four). | Size, corner radius |
| **Polygon** | A closed outline through points you drag in the viewport. | Points |
| **Polyline** | A path through points, open or closed, with caps. | Points, closed |
| **Triangle** | Three corners, the first of them the node's own origin. | Corner B, corner C |
| **Regular Polygon** | N equal sides at a radius: a triangle, a hexagon, a near-circle. | Sides, radius, angle |

All seven share the stroke, colour, fill, border, dash and drawing fields below.

## The ten shapes in 3D

The 3D half is the same drawing in a world with a camera in it. Each node is a
`MeshInstance3D`, so its Visibility, Cast Shadow and Cull Margin are Godot's own; there is no
hidden child holding a mesh and no second transform to keep in step.

| Node | What it is | Its own fields |
|---|---|---|
| **Line 3D** | A line between two points anywhere in space, drawn as a strip - the grapple rope, the laser sight, the tether. | Start point, end point |
| **Disc 3D** | A disc, and by an inner radius and two angles also a ring, a pie and an arc. | Radius, inner radius, start angle, end angle |
| **Rect 3D** | A rectangle with rounded corners (one number, or four). | Size, corner radius |
| **Polygon 3D** | A closed outline through points you drag in the 3D viewport. | Points |
| **Polyline 3D** | A path through points, open or closed, with caps. | Points, closed |
| **Regular Polygon 3D** | N equal sides at a radius: the hex tile marker, the summoning ring. | Sides, radius, angle |
| **Sphere** | The engine's own sphere, wearing the family's colour, blend and depth fields. | Radius |
| **Cuboid** | The engine's own box, same fields. | Size |
| **Cone** | A cone with an optional cap - the spotlight volume, the arrow head. | Radius, height, capped |
| **Torus** | The engine's own torus - the portal ring, the halo, the hoop. | Radius, inner radius |

### Geometry: flat, billboard, volumetric

The first six carry a **Geometry** row of three buttons at the top of the Inspector, and it is
the choice the rest of the Inspector hangs off:

- **flat** - the shape lives on the node's own XY plane. A range ring on the ground, a panel on
  a wall, a zone marker on the floor.
- **billboard** - the same shape, turned to face the camera every frame. That turn happens in
  the **vertex** stage: four vertices of work per shape, no redraw and no CPU pass over
  anything. A Line 3D reads it differently and rightly: a line always faces you *along its own
  axis*, so its billboard is a strip built between its two points rather than a card that spins.
- **volumetric** - real geometry the depth buffer treats like anything else, drawn unshaded, so
  the colour you pick is the colour on screen and no light has an opinion about it. A Line 3D,
  a Polyline 3D, a Polygon 3D and a Regular Polygon 3D become a **tube** along their own
  outline at the detail level you set; a Disc 3D becomes a cylinder (or a torus once it has an
  inner radius) and a Rect 3D a slab as deep as its stroke is wide. The four wrappers are always
  this.

A volumetric shape is a surface rather than a distance field, so it wears its own colour and
its blend word and nothing else: **the dashes, the caps and the colour modes are what the flat
and billboard forms are for.** The Inspector says so by hiding those fields when the shape is
volumetric, rather than leaving them there meaning nothing.

### The 3D numbers are the node's own units

A stroke five centimetres wide is `0.05`, and a disc half a metre across has a radius of `0.5`.
That is the one thing to know coming from the 2D twins, and it is why **Thickness** is followed
by a **unit** row of two buttons rather than by the 2D half's converting dropdown:

- **world** - the number is the node's own units.
- **screen** - the number is PIXELS, and the shape keeps that weight however far away the camera
  gets. A pixel is not a length in 3D until something says how far away the shape is, so this is
  a run-time mode rather than a view of one stored number: the shader reads how much of the
  shape one pixel covers where it lands, which is exact for a shape seen at an angle, for an
  orthographic camera, and for any scale on the node. **Point Is Inside Shape** uses the same
  reading, so a hairline that looks four pixels wide is four pixels wide to click.

Angles keep the converting dropdown, because degrees, turns and radians convert exactly and
without a camera: the Disc 3D's start and end angle and the Regular Polygon 3D's angle all show
one. The number stored is always degrees, so nothing an emitted script reads ever moves.

### Depth: sorted, or drawn through walls

**Depth** is two buttons on every 3D shape. `test` sorts the shape against the world the
ordinary way. `through walls` draws it over everything in front of it - the gizmo line, the
range ring you have to see from anywhere. It is honest about its cost: a depth test is a
`render_mode`, decided when a shader compiles, so `through walls` is a second shader rather
than a flag on the same one, which is why the pack ships ten spatial files and not five.

### Handles and previews in 3D

Each 3D shape shows the same **live preview card** at the top of its Inspector, and drags its
geometry by **handles in the 3D viewport**: the Line 3D's two ends, the Disc 3D's radius, the
Polygon 3D's and Polyline 3D's points, the Regular Polygon 3D's radius, and the Sphere's, the
Cone's and the Torus's radius. A handle drags on the plane facing the camera, so looking down
the node's own Z gives an exact reading on the shape's own plane.

### The rows are the same rows

Every row the 2D half ships, the 3D half ships too, with one addition: **Set Geometry**
(`flat`, `billboard`, `volumetric`). `Set Thickness` takes `world` or `screen` here rather than
the 2D half's three units, and `Point Is Inside Shape` takes a `Vector3`.

```
Player | Is grappling  -> Rope      | Set Property: start, Player.hand.global_position
                       -> Rope      | Set Property: end, Player.grapple_point
Turret | On ready      -> RangeRing | Set Shape Radius: Turret.range
```

## ACE reference

Every row is **node-scoped**: you pick which shape it acts on, exactly like a built-in row on
a Sprite2D. The rows live on the shared base, so one **Set Thickness** in the picker works on
all seven rather than seven identical entries.

### Actions

| Row | Parameters | What it does |
|---|---|---|
| **Set Thickness** | value (float), unit (`px` / `world` / `screen`) | Sets how wide the stroke is, in the unit you typed it in. Pixels and world units are the same in Godot's 2D; a screen unit is a whole viewport width, so a line set in screen units keeps its weight on every phone. The field itself always stores pixels. |
| **Set Shape Colour** | colour (Color) | The whole of the shape in single mode, and the first end of the blend in every other mode. |
| **Set Colours** | from_colour (Color), to_colour (Color) | Both ends at once, and switches a single-colour shape to two-colour mode. |
| **Set Gradient** | gradient_resource (Gradient) | Hands the shape a Gradient resource and switches it to gradient mode. |
| **Set Fill** | filled (bool) | Fills the shape, or leaves it an outline. A filled shape draws its **border** rather than its stroke, so the two can never sit a pixel apart. |
| **Set Dashes** | count (int), spacing (float), style (`plain` / `angled` / `rounded`) | The whole dash pattern in one row. |
| **Set Dash Offset** | offset (float) | Moves the pattern along the shape without changing it. Whole numbers land where they started. |
| **Scroll Dashes** | patterns_per_second (float) | Marches the dashes. **0 stops them and parks the tick**, so a stopped shape costs nothing per frame. |
| **Fade Shape Over** | to_alpha (float), seconds (float) | Fades the shape's colour to an alpha. |
| **Set Shape Points** | new_points (Array) | Replaces a Polygon's or Polyline's points, in the shape's own coordinates. |
| **Set Shape Radius** | new_radius (float) | The radius of a Disc or a Regular Polygon. |
| **Set Shape Sides** | count (int) | How many sides a Regular Polygon has. |
| **Set Arc** | from_degrees (float), to_degrees (float) | A Disc's sweep. 0 to 360 is the whole disc; less is the pie or arc a cooldown, a vision cone or a health ring is drawn as. |
| **Apply Shape Style** | style_file (ShapeStyle) | Puts a style file into the shape's Style slot: its thickness, caps, colours, dashes and blend are read from that file from now on. An empty slot hands the shape its own fields back. |
| **Apply Shape Style To Group** | group_name (String), style_file (ShapeStyle) | The same, for every shape in a group at once - the whole HUD re-skinned from one file. |
| **Tether Between** | first (Node2D), second (Node2D) | Runs the shape between two nodes and keeps it there: its start follows the first, its end follows the second. It redraws only on the frames one of them actually moved, so a leash that is standing still costs nothing. |
| **Untether** | none | Lets go of both. The shape stays exactly where the last frame left it, and its tick parks. |
| **Fill Ring To** | fraction (float) | Sweeps a Disc's arc to a fraction of the way round - 0 empty, 1 whole. The cooldown, the stamina wheel, the loading circle, in one row per frame. |
| **Follow Cursor** | snap_to (float) | Puts the shape under the pointer every frame, snapped to a grid of that many pixels (0 for no snap). The placement footprint, the brush outline, the target marker. |
| **Stop Following** | none | Stops it following the pointer. The shape stays where it was left, and the tick parks. |
| **Fit Around** | node (Node2D), margin (float) | Sizes the shape to what a node covers, plus a margin, and centres it on it. A node with nothing to measure is left alone rather than collapsing the shape to a point. |
| **Show For** | seconds (float) | Shows the shape and hides it again when the seconds are up - the hit marker, the ping, the flash that says "placed". |

Each shape also publishes the one or two fields that are its own sentence, as ordinary
property rows: **End Point** (Line), **Inner Radius** (Disc), **Size** (Rect), **Closed**
(Polyline), **Corner B** and **Corner C** (Triangle), **Angle** (Regular Polygon), and
**Colour Mode** on all seven.

### Conditions

| Row | Parameters | True when |
|---|---|---|
| **Shape Is Visible** | none | The shape is drawn at all: visible in the tree, and not fully transparent. |
| **Point Is Inside Shape** | point (Vector2) | A world point lands inside the shape: inside the outline for a filled one, within half a thickness of the line otherwise. The pick test for a shape you can click, with no collision body under it. |
| **Shape Style Is** | style_file (ShapeStyle) | The shape is wearing that exact style file. The test a row makes before re-skinning, and the one an exception is written against. |
| **Shape Is Tethered** | none | The shape is running between two nodes that both still exist. |
| **Ring Is Full** | none | A Disc's arc goes the whole way round - the cooldown that has finished, the wheel that is charged. |

### Expressions

| Expression | Returns | What it answers |
|---|---|---|
| **Shape Length** | float | How long the outline is, in pixels. The length a dash pattern is fitted into. |
| **Shape Area** | float | How much area the shape covers, in square pixels. A shape that is only a line covers none. |
| **Point Along Shape At** | Vector2 | The point a fraction of the way along the outline, in the shape's own coordinates - 0 the start, 0.5 the middle, 1 the end. Where to put a marker on a route, a spark on a wire, a label on a border. |

### Inspector properties

The Inspector is where a shape is designed. The fields are grouped, and a group that has
nothing to say in the mode the shape is in hides itself rather than sitting there meaning
nothing.

| Group | Field | Notes |
|---|---|---|
| (top) | Style | A **Shape Style** file this shape wears instead of its own look, with a **Save As Style** button above it. Empty is the usual case. See "Styles you own" below. |
| Stroke | Thickness | A number with a **unit dropdown** at its right edge: pixels, world units or screen units. Switching the dropdown converts the number in front of you; the stored value is always pixels, so nothing an emitted script reads ever moves. |
| Stroke | Thickness scale | With the node, or fixed on screen (what a HUD line wants). |
| Stroke | Caps | None, square or round, as three icon buttons. |
| Colour | Colour mode | `single`, `two`, `radial`, `angular`, `gradient` or `per corner`, depending on the shape. The mode decides which swatches are shown below it. |
| Colour | Colour, Colour B, Colour C, Colour D | Only the swatches the mode needs. |
| Colour | Gradient | Godot's own Gradient resource, edited in Godot's own gradient editor. Shown in gradient mode. |
| Fill | Fill | Fills the shape rather than drawing only its outline. |
| Border | Border, Border colour, Border thickness | A line on the fill's own edge. The colour and thickness appear with the toggle. |
| Dashed | Dashed | Unfolds the whole section below it. |
| Dashed | Dash space | `world` (pixels), `relative` (multiples of the stroke's thickness) or `count` (a fixed number of dashes, however long the shape is). |
| Dashed | Snap | `off`, `tiling` (a whole number of periods), or `end to end` (also centres a dash on each end, which puts one on every corner of a rect and every vertex of a polygon). |
| Dashed | Size / Count | Size in world and relative space; count in count space. Only the one the space uses is shown. |
| Dashed | Spacing | Linked to Count by the **equals button**: change one and the other follows the ratio. A share of the period in count mode, a length otherwise. |
| Dashed | Offset | Moves the pattern along. Whole numbers tile, so scrolling never jumps. |
| Dashed | Style | `plain`, `angled` or `rounded`, as three icon buttons **drawn by the shape's own shader**, so the picture of a rounded dash is a rounded dash. |
| Drawing | Blend | `normal`, `add`, `subtract`, `multiply` or `premultiplied`. |
| Drawing | Anti-alias width | How wide the fade at an edge is, in pixels. 1 is a crisp edge at any zoom; wider is a deliberate glow; 0 is a hard, aliased edge. |

Each shape shows a **live preview card** at the top of its Inspector, and drags its geometry
by **handles in the 2D viewport**: the Line's end point, the Disc's radius and start angle,
the Polygon's and Polyline's points, the Triangle's two free corners, the Regular Polygon's
radius.

## Colour modes

| Mode | What the two colours mean | Which shapes offer it |
|---|---|---|
| `single` | One colour, the whole shape. | All seven |
| `two` | Start to end along the shape: a line's length, a ring's inner to outer edge. | All seven |
| `radial` | Out from the middle. | Disc, Rect, Polygon, Triangle, Regular Polygon |
| `angular` | Round the sweep: red at the start of an arc, green at its end. | Disc, Regular Polygon |
| `gradient` | A whole Gradient resource, re-used by every shape that points at it. | All seven |
| `per corner` | A colour per corner. | Rect, Triangle |

The border has its own colour and thickness, and the fill respects the blend.

## Styles you own

Twenty aim lines in one game want one thickness, one cap and one dash pattern. A **Shape Style**
is that answer as a file: a resource holding the LOOK half of a shape's fields, which any 2D shape
can wear.

**The pack ships no styles.** There is no house list to pick from, because a look is the game's,
not the plugin's. The first style in a project is one you save out of a shape you tuned: set the
thickness, the caps, the colours and the dashes on one Line until it looks right, then press
**Save As Style** at the top of its Inspector. That writes a `.tres` beside the scene, named after
the node, and the shape wears the file it just wrote - so nothing on screen moves.

**Wearing one.** Drop the file into another shape's **Style** slot (a drag from the FileSystem dock
does it). Every field the style speaks for now reads from the file, and those fields go **grey** in
the Inspector rather than disappearing: you can still read what the shape would look like on its
own, and emptying the slot hands it straight back. Nothing is copied into the shape, so editing the
style file changes every shape wearing it at once, in the editor as well as in the game.

| A style speaks for | It never speaks for |
|---|---|
| Thickness, thickness scale, caps | An end point, a radius, a size, a list of points, an angle |
| Colour mode, colour, second colour, gradient | Fill and border toggles, which are the shape's own |
| Dashed, dash space, snap, size, count, spacing, style | The dash **offset**, which is what Scroll Dashes animates |
| Blend | Anti-alias width |

A shape that **has not got** a field the style carries is untouched by it: a Triangle has no dashes,
so a dashed style leaves it a plain triangle rather than inventing fields for it.

**From rows.** `Apply Shape Style` on one shape, `Apply Shape Style To Group` for a whole HUD, and
`Shape Style Is` for the exception:

```
On setting changed "high_contrast"
  -> Shapes | Apply Shape Style To Group  "hud_lines", preload("res://ui/hud_thick.tres")
```

**2D only.** The 3D shapes measure their thickness in world units with a unit of their own, so a
style holding pixels would be a lie there rather than a shortcut; a 3D shape has no Style slot.

## Use cases

### 1. The simplest possible shape

Create Node ▸ **Line**. Drag the handle. That is a crisp line, no rows at all.

### 2. An aim line that follows the cursor

```
Is aiming     -> AimLine | Follow Cursor: 0
Is not aiming -> AimLine | Stop Following
```

**Tip:** a snap of 0 follows the pointer exactly; a snap of 32 lands it on a 32-pixel grid, which
is what a placement footprint wants. Following stops the moment Stop Following runs, and the tick
stops with it. To move only the FAR end instead of the whole shape, write the end point yourself -
it is in the node's own coordinates, so subtract the node's position from a world point.

### 3. A cooldown ring

Disc, inner radius 20, radius 28, colour mode `angular`.

```
On cooldown started -> CooldownRing | Set Arc: 0, 360
                    -> CooldownRing | Tween Property: end_angle, 0, Ability.cooldown
```

### 4. A vision cone that opens when an enemy is alerted

Disc, start angle -30, end angle 30, fill on.

```
Enemy Is alerted -> VisionCone | Set Colours: red, transparent
                 -> VisionCone | Set Arc: -45, 45
Else             -> VisionCone | Set Arc: -20, 20
```

### 5. A placement footprint with marching ants

Rect, fill off, Dashed on, snap `end to end` so a dash sits on every corner.

```
Builder Is placing        -> Footprint | Scroll Dashes: 1
Builder Cannot place here -> Footprint | Set Dashes: 12, 0.5, angled
                          -> Footprint | Set Shape Colour: red
```

### 6. Stopping the ants without paying for them

```
Builder Is placing (inverted) -> Footprint | Scroll Dashes: 0
```

**Tip:** 0 does not merely set the speed to nothing, it parks the node's `_process`. A screen
full of stopped footprints costs no per-frame work at all.

### 7. A health arc that goes red to green

Disc, colour mode `angular`, inner radius set.

```
On health changed -> HealthArc | Set Arc: -90, -90 + 180 * Player.health_fraction
                  -> HealthArc | Set Colours: Palette.colour("danger"), Palette.colour("healthy")
```

The **Color Palette** pack's roles feed the swatches, so a whole HUD reskins from one
resource.

### 8. A selection box you can click

Rect, fill off, border on.

```
On mouse pressed
  + SelectionBox Point Is Inside Shape: mouse_world -> Selection | Begin drag
```

**Tip:** no collision body, no Area2D, no input pickable. The shape answers the pick test
itself.

### 9. A route preview as a polyline

Polyline, dashed, closed off.

```
On path found -> RoutePreview | Set Shape Points: Nav.path_points
              -> RoutePreview | Scroll Dashes: 2
```

### 10. A tether between two things

Line, thickness in screen units so it holds up at any zoom.

```
On ready -> Leash | Tether Between: Player, Pet
```

One row, once - not a row every tick. The shape follows both nodes from then on and skips the
frames neither of them moved, which is most of them. **Untether** lets go and parks the tick, and
the line stays exactly where the last frame left it.

### 11. A hex grid cell that highlights

Regular Polygon, sides 6, fill on, colour mode `radial`.

```
On cell hovered -> Cell | Set Shape Colour: highlight
                -> Cell | Set Thickness: 3, px
On cell left    -> Cell | Set Shape Colour: idle
                -> Cell | Set Thickness: 1, px
```

### 12. A damage number's backing wedge

Triangle, colour mode `per corner`, three colours.

```
On damage taken -> Wedge | Fade Shape Over: 0, 0.4
```

### 13. A dashed range ring that grows with an upgrade

Disc, inner radius just under the radius, dashed, dash space `count`.

```
On range upgraded -> RangeRing | Set Shape Radius: Turret.range
                  -> RangeRing | Set Dashes: 24, 0.4, rounded
```

**Tip:** in `count` space the dashes stay 24 however big the ring gets, so the pattern reads
the same at every range.

### 14. A minimap border that is one node

Rect, corner radius 8, border on, fill off. Nothing but Inspector fields.

### 15. Measuring the outline before you walk it

```
On patrol started -> Guard | Set Variable: patrol_length = PatrolPath.Shape Length
                  -> Guard | Set Variable: step = 1 / PatrolPath.Shape Length
```

### 16. A shape that fades out and cleans up

```
On collected -> Ring | Fade Shape Over: 0, 0.3
             -> Ring | Wait: 0.3
             -> Ring | Destroy
```

### 17. Re-enabling a shape that was faded to nothing

```
On respawn -> Ring | Set Shape Colour: Color(1, 1, 1, 1)
           -> Ring | Scroll Dashes: 1
```

**Tip:** `Shape Is Visible` is false while the alpha is 0 even though the node is visible in
the tree, which is what you want a "should I bother updating it" condition to say.

### 18. One gradient shared by a whole HUD

```
On start of layout -> HealthArc  | Set Gradient: hud_ramp
                   -> ShieldArc  | Set Gradient: hud_ramp
                   -> StaminaArc | Set Gradient: hud_ramp
```

One Gradient resource, three shapes, one place to change the look.

### 19. A stamina wheel that empties as you sprint

Disc, inner radius 18, radius 24, colour mode `angular`.

```
Is sprinting -> StaminaRing | Fill Ring To: Player.stamina_fraction
Ring Is Full -> StaminaRing | Set Shape Colour: ready_green
```

**Fill Ring To** sweeps from the disc's own start angle, so a wheel that starts at the top stays
starting at the top however far it empties.

### 20. A selection box that fits whatever you picked

Rect, fill off, border on, dashed.

```
On unit picked -> Selection | Fit Around: picked_unit, 6
               -> Selection | Show For: 0
On unit dropped -> Selection | Show For: 0.4
```

**Fit Around** measures the node's own drawn rectangle when it has one, and otherwise the collision
shapes under it. **Show For** with a number of seconds shows the shape and hides it again when they
are up; a zero hides it now.

### 21. A marker that walks along a route

```
Every tick -> Runner | Set Position: RoutePreview.Point Along Shape At(Runner.progress)
```

**Point Along Shape At** walks the outline by LENGTH, so a marker at 0.5 is halfway along the path
rather than halfway through its points - which are not the same thing on a path with a long leg
and three short ones.

### Other use cases

**Debug reach circles.** A Disc with fill off and a thin stroke, parented to anything with a
radius, says at a glance how far it reaches. Turn the whole layer off for a build.

**A radar sweep.** A Disc in `angular` colour mode with a narrow arc, its start and end angles
tweened together, is the sweeping wedge without a single texture.

**Tutorial callouts.** A dashed Regular Polygon around the button a tutorial step is pointing
at, scrolling slowly, reads as "look here" in every art style.

**A stylised sky band.** A Rect in `two` colour mode, stretched across the top of the screen
behind everything, is a two-tone sky that costs one quad.

**Wire diagrams in an editor tool.** Because the nodes are tool scripts, a Polyline built from
rows draws in the editor viewport as well as in the game, which is what an in-editor level
tool wants.

## Tips and common mistakes

- **A filled shape draws its border, not its stroke.** Turn **Fill** on and the Stroke group's
  thickness stops mattering; the Border group's does. This is deliberate: a fill and an
  outline that were two separate widths could always be made to sit a pixel apart.
- **Screen units are a whole viewport width, not one pixel of it.** A thickness of `0.5` in
  screen units is half the screen. A hairline is more like `0.002`.
- **The dash space decides which of Size and Count you get.** Count mode hides Size and shows
  Count; the other two do the opposite. A number typed into the hidden one is still stored, it
  simply does not draw.
- **Whole-number dash offsets tile.** An offset that has been scrolling for an hour is still in
  step, so a loop never jumps.
- **A Disc is the cheap circle; a Regular Polygon with 64 sides is the expensive one.** Reach
  for the Disc unless you actually want the flat sides.
- **These are not Godot's Line2D and Polygon2D, and do not replace them.** Ribbons with a
  texture, a width curve along the length, or thousands of points belong to the engine's own
  nodes. Crisp primitives, arcs, dashes and a thickness with a unit belong here. Both are
  ordinary Node2Ds and mix freely in one scene.

## What it costs

- **120 rows in the picker, for nineteen nodes.** 48 of them are the verbs on the two bases - one
  **Set Thickness** works on all seven 2D shapes, one **Set Geometry** on all ten 3D ones - and the
  other 72 are the handful of geometry fields each shape publishes on its own (a Line's end point,
  a Disc's inner radius). A shape carries thirty-odd exported fields and a row per field would have
  been close to four hundred entries; every field a verb already says is marked hidden and still
  reaches a sheet through Set Property and Tween Property. The **Shape Style** file publishes
  nothing at all: it is edited in the Inspector and put in force by the shape's own **Apply Shape
  Style**, so a row that wrote a style no shape wears would be a row that changes nothing.
- **One quad and one draw per shape.** The distance field is solved in the fragment shader
  over the shape's own bounding quad. A dashed ring of any radius costs exactly the same as a
  plain one: the dashes are arithmetic in the fragment, not extra geometry and not extra
  passes.
- **One shader family, five files.** The kind of shape is a **uniform** the fragment branches
  on rather than a shader per kind. The branch is uniform across a draw (every pixel of one
  quad takes the same arm), and what a phone or a browser actually pays for is shader
  **compiles** and pipeline switches: seven variants would be seven of each. The only reason
  there is more than one file is the blend mode, which is a `render_mode` fixed at compile
  time and impossible to make a uniform, so the five blends are five four-line files around
  one shared include.
- **The `canvas_item` path, so every renderer.** Nothing here needs Forward+. It draws the
  same on Compatibility, which is what a phone and a browser ship with.
- **Nothing is allocated per frame.** The uniforms are pushed when a field changes, not on a
  tick, and a shape with no dash scroll has no `_process` at all. A shape that IS scrolling its
  dashes writes the one uniform that moved, rather than redrawing the whole shape sixty times a
  second for a number that only ever slides along.
- **Precision is kept mediump-safe.** The distance arithmetic works in the shape's own local
  space rather than in world pixels, so a shape placed far from the origin does not go blocky
  on a mobile GPU.
- **Many of a kind still want a MultiMesh.** Seven hundred identical dashed rings are seven
  hundred draws here. That is fine for a HUD and wrong for a particle field; the drawing rows
  on the Drawing Canvas are the answer for a crowd.
- **The 3D half is one quad too.** A flat or billboard shape is the same four vertices, wearing
  the spatial version of the same body; the billboard turn is vertex work, not a rebuild. A
  volumetric shape is the only one that builds a mesh, and it builds it when its own geometry
  changes - never when a colour, a blend word or a dash offset does.
- **Ten spatial files, one drawing.** Five blends times two depth readings, because both are
  `render_mode` and neither can be a uniform. All ten are five lines around the same include
  the canvas half reads, so the arithmetic has exactly one copy.
- **Nothing in the 3D half is Forward+ only either.** An unshaded spatial shader with these
  blends runs on Mobile and on Compatibility, which is what a phone and a browser ship with.
- **A screen-unit stroke costs nothing extra.** It is read from the screen-space derivatives of
  the shape's own coordinates in the fragment - no camera lookup on the CPU, no per-frame
  uniform push, and no `_process`.

## Already written it by hand? It reads as this pack

A `@tool` script on a Node2D that keeps a `ShaderMaterial`, pushes uniforms in a setter and
calls `queue_redraw()` is the shape of every one of these nodes. Open one as a sheet and the
rows are there: the setters as actions, the pick test as a condition, the two measurements as
expressions. Nothing about the emitted code needs the plugin to run.
