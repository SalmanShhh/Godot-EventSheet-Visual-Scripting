# Drawing Canvas - Draw Shapes, Trails, and Line of Sight from the Sheet

A texture your event sheet draws onto with verbs: lines, circles, rings, rects, cones,
texture stamps, textured ribbons, and a raycast **line-of-sight fan** that hugs your walls.
Two personalities in one behavior: **persistent** (strokes stay until you clear - paint,
blood splats, skid marks) and **auto-clear** (redrawn every frame - attack telegraphs,
vision cones). The canvas's live texture is an expression, so the same drawing can feed a
`TextureRect`, a shader, a particle, or a 3D `Decal` (the Decal Painter pack accepts it
directly).

## Where this pack shines

- **Circle shadows with zero assets.** One `Draw Circle` in soft black under each character.
- **Attack telegraphs.** Auto Clear on + `Draw Cone` each tick = the classic red warning
  wedge that tracks the attacker's facing.
- **Line of sight you can SEE.** `Draw Line Of Sight` casts a fan of rays against your wall
  collision mask (picked from a checkbox list of your named layers) and fills the exact
  visible area - guard vision cones, stealth lighting, fog reveals.
- **Textured ribbons.** `Start Ribbon` trails any node with a round-capped, texturable
  stroke - sword swooshes, skid marks, comet tails.
- **Paint that stays.** Persistent mode bakes strokes onto the texture: splatter, footprints,
  spray-paint mechanics, damage decals - without a growing draw list (strokes render once and
  the render target keeps them).

## Setup

1. Attach `DrawingCanvas` as a child of any Node2D (the canvas centers on it and follows).
2. Pick a canvas size in the Inspector (512 x 512 default) and a mode: `auto_clear` off for
   paint, on for per-frame drawings.
3. Add draw rows. In `world` coordinates (default) you pass scene positions - draw at the
   player's x/y and it lands under the player.

```
On Ready       -> Player | Drawing Canvas: Set Auto Clear  true
Every tick     -> Player | Drawing Canvas: Draw Line Of Sight
                  Player.X, Player.Y, facing_deg, 90, 300, [Walls], Color(1, 0.9, 0.4, 0.35)
```

## ACE reference

### Actions

| Action | Parameters | Description |
|---|---|---|
| Clear Canvas | (none) | Wipes the canvas (persistent mode wipes next frame, then keeps strokes again). |
| Set Auto Clear | `enabled` (bool) | On: self-wiping every frame (re-issue draws each tick). Off: strokes accumulate. |
| Set Canvas Visible | `visible_now` (bool) | Shows/hides the on-host display sprite. |
| Draw Line | `from_x`, `from_y`, `to_x`, `to_y`, `width`, `color` | A line segment - aim guides, lasers. |
| Draw Circle | `x`, `y`, `radius`, `color` | Filled circle - the classic blob shadow. |
| Draw Ring | `x`, `y`, `radius`, `width`, `color` | Circle outline - selection rings, blast previews. |
| Draw Rect | `x`, `y`, `width`, `height`, `color` | Filled rectangle (x/y = top-left). |
| Draw Dashed Line | `from_x`, `from_y`, `to_x`, `to_y`, `dash_length`, `gap_length`, `width`, `color` | A dashed line segment - aim guides, tethers, boundary previews. |
| Draw Dashed Ring | `x`, `y`, `radius`, `dash_length`, `gap_length`, `width`, `color` | A dashed circle outline - range rings, dashed selection markers. |
| Draw Dashed Rect | `x`, `y`, `width`, `height`, `dash_length`, `gap_length`, `line_width`, `color` | A dashed rectangle outline - selection boxes, zone markers, build-placement previews. |
| Draw Cone | `x`, `y`, `facing_deg`, `fov_deg`, `radius`, `color` | Filled wedge - the attack telegraph. |
| Draw Stamp | `texture`, `x`, `y`, `scale_factor`, `rotation_deg` | Stamps a texture - bullet holes, footprints. |
| Draw Line Of Sight | `origin_x`, `origin_y`, `facing_deg`, `fov_deg`, `max_range`, `collision_mask`, `color` | Raycast fan against the mask, filled - vision cones that hug the level. The mask param opens the layer PICKER (named project layers as checkboxes). |
| Draw Prefab | `prefab` (Resource), `x`, `y`, `scale_factor`, `rotation_deg` | Replays a DrawingPrefabResource's steps IN ORDER at a position, scaled and rotated - reusable formations from a .tres. |
| Paste Node | `node` (Node) | Bakes a node's CURRENT visual onto the canvas at its own world transform - rotation, scale, flip, frame and tint preserved. Non-destructive (the node stays). Sprites, animated sprites and texture rects; a textureless node is skipped. |
| Paste Node At | `node` (Node), `x`, `y`, `scale_factor`, `rotation_deg` | Bakes a node's visual at an EXPLICIT spot (like the other draw coordinates) - stamp an off-screen template sprite anywhere, any number of times. |
| Paste Layer On Screen | `layer` (Node) | Bakes every visible texture-bearing node under `layer` that is currently ON SCREEN - flatten a layer of decor into one texture. `layer` is any parent (a CanvasLayer, a container, or the scene root). |
| Paste Layer In Box | `layer` (Node), `x`, `y`, `width`, `height` | Bakes every visible texture-bearing node under `layer` whose world rect falls inside the box (world coordinates) - flatten a region regardless of the camera. |
| Start Ribbon | `follow` (Node), `point_count`, `width`, `color` | A trail following a node (last N frames of history). |
| Set Ribbon Texture | `follow`, `texture` | Skins a running ribbon, stretched along its length. |
| Stop Ribbon | `follow` | Ends that node's ribbon. |

### Conditions and expressions

| Kind | Name | Description |
|---|---|---|
| Condition | Is Auto Clear | The canvas is in per-frame redraw mode. |
| Expression | Canvas Texture | The LIVE texture - assign to materials, UI, particles, or a 3D Decal. |

### Inspector properties

| Property | Default | What it does |
|---|---|---|
| `canvas_width` / `canvas_height` | `512` | Texture size in pixels. |
| `auto_clear` | `false` | Per-frame wipe (telegraphs) vs accumulate (paint). |
| `coordinates` | `world` | `world`: draw at scene positions (canvas follows the host). `canvas`: raw texture pixels. |
| `display_on_host` | `true` | Show the canvas on the host via a centered Sprite2D child. |

### Inspector properties are ACEs too

Every property this pack exposes in the Inspector is also reachable from the picker, generated for you:
an expression named after the property reads it, a **Set ...** action writes it, and for number properties
**Add To ...** and **Subtract From ...** adjust it by an amount. They sit in the pack's own category
alongside the verbs above, so any knob you can set in the Inspector is also something a sheet can read and
change while the game runs.

## Use cases

### 1. A guard's vision cone (stealth)

```
On Ready    -> Guard | Drawing Canvas: Set Auto Clear  true
Every tick  -> Guard | Drawing Canvas: Draw Line Of Sight
               Guard.X, Guard.Y, guard_facing, 70, 340, [Walls], Color(1, 1, 0.5, 0.25)
```

Walls carve the fan exactly - the player can read safe shadows at a glance. Pair with the
Line of Sight pack's `Has Line Of Sight` condition for the actual detection logic.

### 2. Blob shadows for a whole platoon

One persistent canvas on the level root (coordinates `canvas`), redrawn on a timer:

```
Every 0.05s -> Level | Drawing Canvas: Clear Canvas
            -> For each Soldier: Level | Drawing Canvas: Draw Circle
               Soldier.X, Soldier.Y + 14, 12, Color(0, 0, 0, 0.4)
```

### 3. Boss attack telegraph

```
On Windup Started -> Boss | Drawing Canvas: Set Auto Clear  true
Every tick (while winding up)
  -> Boss | Drawing Canvas: Draw Cone  Boss.X, Boss.Y, Boss.facing, 45, 220, Color(1, 0.2, 0.2, 0.35)
```

### 4. Skid marks that stay

Persistent canvas + a ribbon per wheel while drifting (`Start Ribbon` on On Drift Started,
`Stop Ribbon` on On Drift Recovered - the Car pack provides both triggers). In persistent
mode the ribbon smears onto the texture as it moves: instant tire marks.

### 5. Drawing prefabs - author once, stamp everywhere

Create a **DrawingPrefabResource** (.tres), fill its ordered steps grid in the Inspector -
kind (circle / ring / rect / line / cone / stamp), an x/y offset, per-kind p1/p2/p3 numbers,
and a color - and replay it anywhere:

```
On Ready       -> Level | Drawing Canvas: Draw Prefab  preload("res://fx/target_marker.tres"), 400, 300, 1.0, 0
On Spell Cast  -> Level | Drawing Canvas: Draw Prefab  preload("res://fx/target_marker.tres"), cast_x, cast_y, 0.8, cast_angle
```

The Inspector shows a **live preview** of the composed drawing at the top of the resource (it redraws
as you edit the steps), and the saved `.tres` gets a matching **thumbnail** in the FileSystem dock and
the Draw Prefab prefab picker - so you choose a formation by its picture, not its filename.

Steps draw top to bottom (the formation is ordered), and the whole prefab translates,
scales, and rotates as one - rings-and-crosshair markers, explosion scorches, magic circles,
minimap icons. The Draw Lab showcase stamps one .tres at three scales plus wherever you
press Space.

**Scales to thousands.** A prefab parses its steps (colors, kinds, stamp textures) once and caches the
result, so Draw Prefab and the DrawingPrefabStamp node stay cheap when a thousand-plus stamps share one
prefab - each draw reuses the compiled steps instead of re-parsing. The cache refreshes when the resource
changes; if game code edits a prefab's `steps` at runtime, call `emit_changed()` on it afterwards (the
Inspector does this for you when you edit in the grid).

**Place it in the editor.** Set a Drawing Canvas's **Editor Preview** knobs (`preview_prefab`,
`preview_scale`, `preview_rotation`) and select the node: the formation draws right in the 2D viewport
at the host, so you can line up a target marker or scorch before wiring Draw Prefab. The preview shows
while the node is selected and disappears when you deselect - it is a design aid only, never saved into
the scene and never drawn in the running game. (For a standalone, always-visible gizmo, drop a
`DrawingPrefabStamp` node instead.)

**Preview any node that references a prefab.** You do not need a Drawing Canvas: give any node an
`@export var marker: DrawingPrefabResource` (however you name it) and select it. A **2D node** draws
the formation at its origin in the 2D viewport; a **3D node** shows it as a camera-facing billboard at
its origin in the 3D viewport - so a target ring, a scorch mark, or a cone reads in the scene the same
way the Decal Painter stamps these formations onto 3D surfaces. Both are selection-driven design aids:
transient, never serialized into the scene, gone the instant you deselect.

### 6. Draw onto the 3D world

Draw a target ring on the canvas, then `Spawn Canvas Decal` from the **Decal Painter** pack
projects the live texture onto your 3D floor - the 2D verbs become 3D ground markings.

### 7. The one-row shadow (simplest start)

The smallest useful canvas: auto-clear on, one circle a frame.

```
On Ready   -> Player | Drawing Canvas: Set Auto Clear  true
Every tick -> Player | Drawing Canvas: Draw Circle  Player.X, Player.Y + 14, 10, Color(0, 0, 0, 0.35)
```

The canvas follows the host, so in world coordinates the shadow just tracks the player.

### 8. A laser aim line

One live line from the muzzle to the cursor, redrawn every tick in auto-clear mode.

```
Every tick -> Player | Drawing Canvas: Draw Line
              Player.X, Player.Y, Mouse.X, Mouse.Y, 2, Color(1, 0, 0, 0.6)
```

Drop the alpha to taste - a faint line reads as a sight, a solid one reads as a beam.

### 9. Grenade blast preview

While the throw button is held, ring the landing spot so the player can read the blast before
committing.

```
Every tick (while aiming)
  -> Player | Drawing Canvas: Draw Ring  throw_x, throw_y, 96, 3, Color(1, 0.5, 0, 0.8)
```

Match the ring radius to the grenade's real damage radius - a lying telegraph is worse than none.

### 10. Bullet holes that stay

Persistent canvas on the level root + Draw Stamp: each hit renders once onto the texture, so a
thousand holes cost the same as one.

```
On Bullet Hit
  -> Level | Drawing Canvas: Draw Stamp
     preload("res://fx/bullet_hole.png"), hit_x, hit_y, 1.0, randf_range(0, 360)
```

The random rotation is what stops the wall from looking rubber-stamped.

### 11. A sword swoosh

```
On Swing Started -> Hero | Drawing Canvas: Start Ribbon  $Hero/SwordTip, 14, 18, Color(1, 1, 1, 0.9)
                 -> Hero | Drawing Canvas: Set Ribbon Texture  $Hero/SwordTip, preload("res://fx/swoosh.png")
On Swing Ended   -> Hero | Drawing Canvas: Stop Ribbon  $Hero/SwordTip
```

Keep the canvas in auto-clear mode for a clean arc - a persistent ribbon smears.

### 12. Spray paint with a wash

Persistent painting plus the cleanup verb: Clear Canvas is the bucket of water that wipes the
wall and then keeps accumulating again.

```
Every tick
  Condition: MOUSE_BUTTON_LEFT is down
    -> Wall | Drawing Canvas: Draw Circle  Mouse.X, Mouse.Y, 8, spray_color
On "c" pressed
  -> Wall | Drawing Canvas: Clear Canvas
```

### 13. A minimap in the corner

Canvas Texture makes the drawing portable: hide the world copy, hand the live texture to a HUD
TextureRect, and redraw blips on a timer (coordinates `canvas`, so you plot scaled pixels).

```
On Ready    -> Level | Drawing Canvas: Set Canvas Visible  false
            -> (assign Level | Drawing Canvas: Canvas Texture to $HUD/Minimap.texture)
Every 0.1s  -> Level | Drawing Canvas: Clear Canvas
            -> For each Enemy: Level | Drawing Canvas: Draw Rect  Enemy.X / 8, Enemy.Y / 8, 4, 4, Color(1, 0, 0, 1)
```

### 14. Fog of war

A persistent canvas is a memory: draw a reveal circle wherever the player walks and feed
Canvas Texture into your fog shader as the mask - explored ground stays revealed.

```
On Ready   -> Level | Drawing Canvas: Set Canvas Visible  false
Every tick -> Level | Drawing Canvas: Draw Circle  Player.X, Player.Y, 80, Color(1, 1, 1, 1)
```

Persistent mode means the reveal never has to be re-issued - one pass over the ground is enough.

### 15. Freeze-frame debugging

Is Auto Clear plus the toggle makes a one-key pause for per-frame drawings: freeze the last
vision-cone frame to study it, unfreeze to go live again.

```
On "F3" pressed
  Condition: Level | Drawing Canvas: Is Auto Clear
    -> Level | Drawing Canvas: Set Auto Clear  false
  Else
    -> Level | Drawing Canvas: Set Auto Clear  true
```

Gate your Every tick draw rows on the same state, or new strokes pile onto the frozen frame.

### 16. Build-placement preview (dashed)

While the player drags a building over the grid, an auto-clear dashed rectangle marks the footprint
and a dashed ring shows its effect radius - dashed so it reads as "not placed yet" and never hides the
terrain under it.

```
Every tick
  On placing a building
    -> Player | Drawing Canvas: Set Auto Clear  true
    -> Player | Drawing Canvas: Draw Dashed Rect  ghost_x, ghost_y, tile_w, tile_h, 16, 10, 3, place_color
    -> Player | Drawing Canvas: Draw Dashed Ring  ghost_x, ghost_y, effect_radius, 14, 10, 2, place_color
```

Tint `place_color` red when the spot is blocked, green when it is clear. The dash length and gap are the
last numbers before the color (rect takes a line width, ring/line take a width). All three dashed verbs -
line, ring, rect - share one dash rhythm, so they read as a set.

### 17. Flatten a layer of decor (performance bake)

Hundreds of individual grass, rock, and prop sprites are cheap to author but cost draw calls. A level-wide
persistent canvas on a static root bakes the whole decor layer into ONE texture at load, then you free the
originals - the scene renders one sprite instead of hundreds.

```
On level ready
  -> World | Drawing Canvas: Paste Layer On Screen  DecorLayer
  -> World | System: Destroy  DecorLayer
```

`Paste Layer On Screen` walks every visible sprite under `DecorLayer` and stamps each at its exact
position, rotation, scale, flip and tint; `System: Destroy` then removes the now-redundant nodes. Use
`Paste Layer In Box` instead to bake only a region - a chunk you are about to stream out, say.

### 18. A corpse that stays after the enemy is gone

When an enemy dies, paste its current sprite onto a persistent battlefield canvas so the body lingers as a
decal, then free the actual node - the corpse then costs nothing to keep on screen.

```
On enemy died
  -> World | Drawing Canvas: Paste Node  the enemy
  -> World | System: Destroy  the enemy
```

`Paste Node` bakes the enemy's last frame - facing, flip and death tint included - at its world spot. Pair
it with a slow fade on the whole canvas texture for bodies that decay over time. `Paste Node At` does the
same from an off-screen template sprite when you want the decal somewhere other than the node's position.

### Other use cases

**Footprints in snow.** A persistent canvas under the winter level plus a small Draw Stamp on a step timer leaves tracks everywhere anyone walks, and Clear Canvas is the fresh snowfall.

**Tower range preview.** While the player hovers a build spot, an auto-clear Draw Ring shows the tower's exact reach, tinted red when the spot is invalid.

**Damage direction hints.** A brief auto-clear Draw Cone at the player aimed toward the latest attacker tells the player where the hit came from without any HUD art.

**Boss arena choreography.** Author each attack's floor markings once as a DrawingPrefabResource and Draw Prefab it at the strike point, rotated to the boss's facing, so every telegraph stays consistent.

**Mouse gesture spells.** In persistent mode the player literally draws a rune with Draw Line segments while the mouse button is held; Clear Canvas wipes the slate after the cast resolves.

## Tips and common mistakes

- **Auto Clear drawings must be re-issued every tick.** A one-shot `Draw Cone` in auto-clear
  mode shows for a single frame. Put live shapes under Every tick; put permanent marks in
  persistent mode.
- **Ribbons want auto-clear.** In persistent mode a moving ribbon smears onto the texture -
  great for paint trails, wrong for a clean swoosh.
- **The canvas is a fixed-size window centered on the host.** Drawing 600px away from the
  host on a 512-canvas lands outside the texture. Size the canvas to the effect, or put a
  level-wide canvas on a static root node.
- **The mask picker reads your Project Settings layer names.** Name your 2D physics layers
  (Project Settings > Layer Names) and Draw Line Of Sight's mask param becomes a checkbox
  list of "Walls", "Enemies"... instead of a mystery integer.
