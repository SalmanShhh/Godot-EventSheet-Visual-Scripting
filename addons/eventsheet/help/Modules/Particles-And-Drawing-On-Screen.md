# Particles And Drawing On Screen

Two builtin vocabularies for the things a player actually sees: **Drawing**, which paints lines,
circles, cones, stamps and ribbons onto any node's own 2D canvas, and **Particles**, which drives
GPUParticles2D and CPUParticles2D emitters from rows. Neither needs a pack enabled.

The Drawing rows are the interesting half. Every one of them starts with `CanvasSurface.for_node(...)`,
which lazily builds one offscreen render target for that node and caches it there. So you do not attach
anything, configure anything, or write a `_draw()` function: you pick **Draw Circle**, point it at a
node, and that node has a canvas. Turn auto-clear on and the canvas is a per-frame telegraph (attack
cones, aim guides, vision fans). Turn it off and the strokes pile up like paint (bullet holes,
footprints, splatter, a drawing game).

## Table of Contents

1. [Where this shines](#where-this-shines)
2. [Core concepts](#core-concepts)
3. [Reference tables](#reference-tables)
4. [Use cases](#use-cases)
5. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this shines

- **Attack telegraphs** - the wedge that shows where a boss is about to swing.
- **Vision cones** that hug the level geometry instead of shining through walls.
- **Aim guides and tethers** drawn as dashed lines while a shot is being lined up.
- **Selection rings and range markers** for a strategy or tower-defense layer.
- **Build placement previews** - a dashed rectangle that follows the cursor.
- **Blob shadows** under characters, one circle per frame, no shadow assets.
- **Decals that accumulate** - bullet holes, scorch marks, footprints, blood.
- **Sword swooshes and skid marks** as textured ribbons that trail a moving node.
- **Painting and drawing toys** where the canvas is the game.
- **Effect bursts** - dust on landing, sparks on a hit, a one-shot puff from any object.
- **Weather and ambience** - looping emitters switched on and off by area rows.

## Core concepts

- **A canvas belongs to a node and is created on first use.** Every Drawing row takes an **On**
  parameter naming the canvas host (any Node2D, defaulting to `self`). The first row that runs against
  that node builds its surface; there is nothing to attach beforehand.
- **Auto Clear picks the whole personality of the canvas.** On: the surface is wiped every frame, so
  what you draw is only visible if you redraw it every tick. That is what a telegraph or a vision cone
  wants. Off: strokes stay until Clear Canvas, so what you draw accumulates. That is what paint,
  decals and splatter want.
- **Two coordinate modes.** `world` means the numbers you pass are scene positions, with the canvas
  centred on its host node. `canvas` means raw texture pixels. Configure Canvas is where you choose.
- **The canvas can show itself.** Configure Canvas's **Show On Node** puts the surface on the host as a
  centred Sprite2D, which is the usual "I just want to see it" answer. Turn it off and use **Canvas
  Texture** to route the live image somewhere else - a TextureRect, a shader parameter, a particle
  texture, a 3D Decal.
- **Ribbons are keyed by the node they follow.** Start Ribbon, Set Ribbon Texture and Stop Ribbon all
  take the same **Follow** node, and that node is the ribbon's identity. One canvas can carry several
  ribbons at once as long as each follows a different node.
- **GPU and CPU particles are different classes.** GPUParticles2D and CPUParticles2D share property
  names but are unrelated types, so the picker scopes by node type and the CPU side has its own actions
  where one was needed: **Set Emitting (CPU)**, **Restart / Burst (CPU)** and **Set Speed Scale (CPU)**.
- **The particle rows are node-scoped, so they carry On node.** Left blank they compile to the bare
  member call on the host; filled in, the same call is prefixed with the node you picked.
- **Emit Particles (in object)** is the object-level form: give it the object and it finds the first
  GPUParticles2D anywhere beneath, so no path is needed.

## Reference tables

### Drawing - setup and control

Every row here takes **On** (the canvas host node).

| Name | What it does | Ships as |
|------|--------------|----------|
| Configure Canvas | Sets up (or retunes) the drawing surface on a node - size, auto-clear mode, coordinate mode, and whether it shows on the node. | `CanvasSurface.for_node({node}).configure({width}, {height}, {auto_clear}, {coordinates}, {display_on_host})` |
| Clear Canvas | Wipes the node's canvas. In persistent mode the wipe happens next frame, then strokes keep again. | `CanvasSurface.for_node({node}).clear()` |
| Set Auto Clear | Switches a node's canvas between per-frame wipe and persistent strokes. | `CanvasSurface.for_node({node}).set_auto_clear({enabled})` |
| Is Auto Clear | True when a node's canvas wipes itself every frame. | `CanvasSurface.for_node({node}).auto_clear` |
| Canvas Texture | A node's LIVE canvas texture - assign it to a TextureRect, a material, a particle, or a 3D Decal. | `CanvasSurface.for_node({node}).texture()` |

### Drawing - shapes

| Name | What it does | Ships as |
|------|--------------|----------|
| Draw Line | Draws a line segment onto a node's canvas - attack direction indicators, lasers, aim guides. | `CanvasSurface.for_node({node}).line({from_x}, {from_y}, {to_x}, {to_y}, {width}, {color})` |
| Draw Circle | Draws a filled circle onto a node's canvas - the classic soft blob shadow under a character. | `CanvasSurface.for_node({node}).circle({x}, {y}, {radius}, {color})` |
| Draw Ring | Draws a circle outline onto a node's canvas - selection rings, blast-radius previews. | `CanvasSurface.for_node({node}).ring({x}, {y}, {radius}, {width}, {color})` |
| Draw Rect | Draws a filled rectangle onto a node's canvas (x/y = top-left corner). | `CanvasSurface.for_node({node}).rect({x}, {y}, {width}, {height}, {color})` |
| Draw Dashed Line | Draws a dashed line segment - aim guides, tethers, boundary previews. Dash and gap set the on/off rhythm. | `CanvasSurface.for_node({node}).dashed_line({from_x}, {from_y}, {to_x}, {to_y}, {dash_length}, {gap_length}, {width}, {color})` |
| Draw Dashed Ring | Draws a dashed circle outline - range rings, dashed selection markers. | `CanvasSurface.for_node({node}).dashed_ring({x}, {y}, {radius}, {dash_length}, {gap_length}, {width}, {color})` |
| Draw Dashed Rect | Draws a dashed rectangle outline - selection boxes, build-placement previews, zone markers. The dash rhythm carries continuously around all four sides. | `CanvasSurface.for_node({node}).dashed_rect({x}, {y}, {width}, {height}, {dash_length}, {gap_length}, {line_width}, {color})` |
| Draw Cone | Draws a filled wedge - the attack-telegraph cone (pair with Auto Clear so it follows each frame). | `CanvasSurface.for_node({node}).cone({x}, {y}, {facing_deg}, {fov_deg}, {radius}, {color})` |
| Draw Stamp | Stamps a texture onto a node's canvas - bullet holes, footprints, splats. In persistent mode they pile up like decals. | `CanvasSurface.for_node({node}).stamp({texture}, {x}, {y}, {scale_factor}, {rotation_deg})` |
| Draw Line Of Sight | Draws a character's line of sight as a filled fan: rays stop at walls so the shape hugs the level. | `CanvasSurface.for_node({node}).line_of_sight({origin_x}, {origin_y}, {facing_deg}, {fov_deg}, {max_range}, {collision_mask}, {color})` |
| Draw Prefab | Replays a DrawingPrefabResource's steps onto a node's canvas at a position, scale, and rotation. | `CanvasSurface.for_node({node}).prefab({prefab}, {x}, {y}, {scale_factor}, {rotation_deg})` |

### Drawing - ribbons

| Name | What it does | Ships as |
|------|--------------|----------|
| Start Ribbon | Starts a textured ribbon trailing another node - sword swooshes, skid marks, comet tails. Its update runs automatically. | `CanvasSurface.for_node({node}).start_ribbon({follow}, {point_count}, {width}, {color})` |
| Set Ribbon Texture | Skins a running ribbon with a texture, stretched along its length. | `CanvasSurface.for_node({node}).set_ribbon_texture({follow}, {texture})` |
| Stop Ribbon | Ends the ribbon trailing a node. | `CanvasSurface.for_node({node}).stop_ribbon({follow})` |

### Particles - GPUParticles2D

| Name | What it does | Ships as |
|------|--------------|----------|
| On Particles Finished | Fires once when this particle emitter's one-shot burst finishes playing. | the `finished` signal |
| Set Emitting | Starts or stops the particle emitter, e.g. switching an effect on. | `emitting = {emitting}` |
| Restart / Burst | Restarts the particle system from the beginning, e.g. firing a fresh burst. | `restart()` |
| Set One-Shot | Sets the emitter to fire a single burst then stop, rather than looping. | `one_shot = {one_shot}` |
| Set Amount | Sets how many particles the emitter spawns, controlling effect density. | `amount = {amount}` |
| Set Speed Scale | Speeds up or slows down the particle effect, e.g. 0 freezes it, 2 doubles it. | `speed_scale = {scale}` |
| Is Emitting | True when the particle emitter is currently emitting particles. | `emitting` |
| Amount | Returns how many particles the emitter is set to spawn. | `amount` |

### Particles - CPUParticles2D and object-level

| Name | What it does | Ships as |
|------|--------------|----------|
| Set Emitting (CPU) | Starts or stops a CPU particle emitter, e.g. switching an effect on. | `emitting = {emitting}` |
| Restart / Burst (CPU) | Restarts a CPU particle system from the beginning, e.g. firing a fresh burst. | `restart()` |
| Set Speed Scale (CPU) | Speeds up or slows down a CPU particle effect. | `speed_scale = {scale}` |
| Emit Particles (in object) | Turns the object's particle emitter on or off, found automatically. | a `GPUParticles2D` lookup under `{target}`, then `.emitting = {emitting}` |

### What an effect looks like, said in words (picker sections: Particles)

The rows above start, stop and restart an emitter. These say what its particles DO, in seven words
that ship on both `GPUParticles2D` and `GPUParticles3D` - 44 rows in all, because every word is a
Set, a read-it-back expression and (for the six that can be walked) a Fade, in each dimension.

A particle effect is TWO objects, and that is the difficulty these words exist to hide. How many
particles there are and how long each one lasts belong to the emitter NODE; how fast they set off,
how wide they fan out, which way they fall, how big they are and what colour they are belong to a
`ParticleProcessMaterial` hanging off it. A reader saying "make the sparks fall faster" should not
have to know which of the two the word is on.

| Name | What it does | Ships as |
|------|--------------|----------|
| Set Particle Gravity | Which way the particles fall and how hard, as a direction with a length. | `process_material.gravity = {value}` (after the own-it lines and the guard) |
| Set Particle Spread | How wide they fan out from the way the emitter points, in degrees. | `process_material.spread = {value}` |
| Set Particle Speed | How fast a new particle sets off. BOTH ends of the range are on this row. | `process_material.initial_velocity_min = {value}` and `initial_velocity_max = {most}` |
| Set Particle Size | How big a new particle is. Both ends of the range are on this row too. | `process_material.scale_min = {value}` and `scale_max = {most}` |
| Set Particle Colour | The colour every particle is tinted, multiplied with the picture it draws with. | `process_material.color = {value}` |
| Set Particle Lifetime | How many seconds one particle lasts before it goes out. | `{target.}lifetime = {value}` |
| Set Particle Amount | How many the emitter keeps in the air at once. | `{target.}amount = {value}` |
| Particle Gravity | Reads the gravity back. | `process_material.gravity` |
| Particle Spread | Reads the spread back. | `process_material.spread` |
| Particle Colour | Reads the tint back. | `process_material.color` |
| Particle Lifetime | Reads the lifetime back. | `{target.}lifetime` |
| Particle Amount | Reads the amount back. | `{target.}amount` |
| Slowest Particle Speed | The near end of the speed range. | `process_material.initial_velocity_min` |
| Fastest Particle Speed | The far end of it. | `process_material.initial_velocity_max` |
| Smallest Particle Size | The near end of the size range. | `process_material.scale_min` |
| Biggest Particle Size | The far end of it. | `process_material.scale_max` |
| Fade Particle Gravity | Walks the gravity to a new value over Seconds. | one `create_tween().tween_property(...)` line |
| Fade Particle Spread | Walks the spread the same way. | one tween line |
| Fade Particle Speed | Walks both ends of the speed range. | two tween lines |
| Fade Particle Size | Walks both ends of the size range. | two tween lines |
| Fade Particle Colour | Walks the tint. | one tween line |
| Fade Particle Lifetime | Walks the lifetime. | one tween line |

The 3D twins of every row above are the same words on a `GPUParticles3D`, and they say so on the
row rather than in their names.

**Two words are really two numbers.** A speed is `initial_velocity_min` and `initial_velocity_max`; a
size is `scale_min` and `scale_max`. A row offering one half of either would leave the other one
wherever it happened to be, which is exactly how an effect ends up with every particle at one
identical speed - so both ends are fields on the same row, walked by the same fade, and read back by
expressions of their own.

**Every material write takes this emitter's own copy first**, then asks whether the material really
is a `ParticleProcessMaterial`. A `.tres` worn by every torch in the level never changes under the
other torches, and an emitter driven by somebody's particle SHADER is left completely alone, because
gravity and spread live inside that shader and there is no property here to set. The two node words,
lifetime and amount, need neither line: they are the emitter's own.

**There is no Fade Particle Amount, on purpose.** Writing `amount` makes the engine throw the whole
particle buffer away and build a new one, so walking it over half a second would do that thirty times
and the effect would stutter every one of them. The row says so instead of offering a fade that would
quietly cost frames.

## Use cases

**1. A blob shadow under a character.** Auto-clear on, one circle per frame, no shadow sprite anywhere in
the project.

```gdscript
extends Node2D


func _ready() -> void:
	CanvasSurface.for_node(self).configure(512, 512, true, "world", true)


func _process(delta: float) -> void:
	CanvasSurface.for_node(self).circle(0.0, 8.0, 16.0, Color.WHITE)
```

**2. An attack telegraph cone.** The wedge is redrawn every frame while the wind-up runs, so it follows
the boss and disappears on its own when the rows stop firing.

```gdscript
extends Node2D


func _process(delta: float) -> void:
	CanvasSurface.for_node(self).cone(0.0, 0.0, 0.0, 60.0, 64.0, Color.WHITE)
```

**3. A vision cone that respects walls.** Draw Line Of Sight casts rays and stops them on the physics
layers you name, so the fan hugs the level instead of shining through it.

```gdscript
extends Node2D


func _process(delta: float) -> void:
	CanvasSurface.for_node(self).line_of_sight(0.0, 0.0, 0.0, 90.0, 300.0, 1, Color.WHITE)
```

**4. A dashed aim guide.** Dash and gap set the rhythm; the line is redrawn each frame while the button
is held.

```
Every Frame
  Condition: fire is pressed
    -> Draw Dashed Line  On: self, from 0,0 to aim_x, aim_y, dash 12, gap 8, width 2
```

**5. A build-placement preview.** A dashed rectangle at the cursor, wiped every frame - the classic
"can I put it here" outline.

```gdscript
extends Node2D


func _process(delta: float) -> void:
	CanvasSurface.for_node(self).dashed_rect(0.0, 0.0, 32.0, 32.0, 12.0, 8.0, 2.0, Color.WHITE)
```

**6. A selection ring on the unit you clicked.**

```
On unit selected
  -> Set Auto Clear  On: Unit, true
Every Frame
  -> Draw Ring  On: Unit, x 0, y 0, radius 20, width 2
```

**7. A blast-radius preview before the throw.** Draw Dashed Ring at the grenade's landing point,
redrawn while the aim is held.

```
Every Frame
  Condition: aiming
    -> Draw Dashed Ring  On: self, x land_x, y land_y, radius 96, dash 12, gap 8, width 2
```

**8. Bullet holes that stay.** Turn auto-clear off once, then stamp a texture wherever a shot lands; the
holes accumulate because nothing wipes the surface.

```gdscript
extends Node2D


func _ready() -> void:
	CanvasSurface.for_node(self).configure(1024, 1024, false, "world", true)
```

**9. Stamp the decal at the hit point.**

```
On bullet hit wall
  -> Draw Stamp  On: Level, texture hole.png, x hit_x, y hit_y, scale 1, rotation 0
```

**10. Wipe the accumulated paint.** Clear Canvas is the one row that resets a persistent surface. In
persistent mode the wipe lands next frame and strokes keep accumulating after it.

```
On new round
  -> Clear Canvas  On: Level
```

**11. A sword swoosh.** The ribbon follows the blade node and updates itself; you only start and stop it.

```
On swing starts
  -> Start Ribbon  On: self, Follow: BladeTip, points 20, width 8
On swing ends
  -> Stop Ribbon  On: self, Follow: BladeTip
```

**12. Skin the ribbon.** Set Ribbon Texture stretches an image along the ribbon's length while it is
running.

```
On swing starts
  -> Start Ribbon  On: self, Follow: BladeTip, points 20, width 8
  -> Set Ribbon Texture  On: self, Follow: BladeTip, texture swoosh.png
```

**13. Reuse a drawn marker.** A DrawingPrefabResource is a list of drawing steps saved as a `.tres`;
Draw Prefab replays it anywhere, at any scale and rotation.

```
On target designated
  -> Draw Prefab  On: self, prefab crosshair.tres, x target_x, y target_y, scale 1.5, rotation 0
```

**14. Put the canvas somewhere else.** Turn Show On Node off in Configure Canvas, then feed the live
texture to a UI node - a minimap drawn with the same shape actions.

```
On Ready
  -> Configure Canvas  On: MapDrawer, 256 x 256, auto clear true, canvas coords, show on node false
  -> Set Property  MinimapRect.texture = Canvas Texture(MapDrawer)
```

**15. Ask what mode a canvas is in.** Is Auto Clear is the condition behind a "toggle paint mode" button.

```
On mode button pressed
  Condition: Is Auto Clear  On: Level
    -> Set Auto Clear  On: Level, false
  Else
    -> Set Auto Clear  On: Level, true
```

**16. A one-shot dust burst.** One-shot plus Restart is the "fire it again" pair - Set Emitting alone
will not replay a burst that has already finished.

```gdscript
extends GPUParticles2D


func _ready() -> void:
	one_shot = true
	restart()
```

**17. Switch a looping effect on and off.** Rain, a torch, an engine plume - all the same two rows.

```gdscript
extends GPUParticles2D


func _ready() -> void:
	emitting = true
```

**18. Scale the effect to the machine.** Set Amount is the density dial; drop it on a low graphics
setting and nothing else changes.

```
On graphics setting changed
  Condition: quality = "low"
    -> Set Amount  32
  Else
    -> Set Amount  128
```

**19. Freeze the particles for a photo mode.** Speed scale 0 stops the simulation in place, 1 resumes.

```gdscript
extends GPUParticles2D


func _ready() -> void:
	speed_scale = 0.0
```

**20. Clean up after the burst.** On Particles Finished fires once when a one-shot run ends, which is
where a spawned effect frees itself.

```
On Particles Finished
  -> Queue Free
```

**21. Only restart an emitter that is idle.** Is Emitting is the guard that stops a rapid-fire trigger
from cutting its own burst short.

```
On hit landed
  Condition: Is Emitting   (inverted)
    -> Restart / Burst
```

**22. Puff of dust on any object.** Emit Particles (in object) finds the emitter beneath the object, so
one row works for every character scene regardless of where the emitter sits.

```
On landed
  -> Emit Particles (in object)  Target: Player, true
```

**23. Rain that turns into a gale.** Gravity is a direction with a length, so turning it sideways is
the whole of "wind". The five material words write through a guard, so they carry no On node and the
sheet is the emitter's own:

```gdscript
if process_material == null:
	process_material = ParticleProcessMaterial.new()
elif process_material is ParticleProcessMaterial and not process_material.resource_path.is_empty():
	process_material = process_material.duplicate()
if process_material is ParticleProcessMaterial:
	process_material.gravity = Vector2(300, 900)
```

**24. Sparks that answer a hit.** Spread and speed on two rows, with both ends of the speed range on
the one that sets it. The own-it lines open both templates; the writes they end with are these:

```gdscript
if process_material is ParticleProcessMaterial:
	process_material.spread = 60.0
if process_material is ParticleProcessMaterial:
	process_material.initial_velocity_min = 180.0
	process_material.initial_velocity_max = 420.0
```

**25. A torch guttering out.** **Fade Particle Colour** walks the tint rather than cutting it, which
is what a light dying looks like:

```gdscript
if process_material is ParticleProcessMaterial:
	create_tween().tween_property(process_material, "color", Color(0.2, 0.1, 0.05, 0.0), 1.5)
```

**26. Density as a graphics setting.** **Set Particle Amount** is the row a low setting turns down,
and it is a row to use at a moment rather than every frame. Amount is the emitter's own member, so
this one DOES take an On node and can be aimed from anywhere:

```gdscript
$Rain.amount = 400
```

**27. Read an effect back before changing it.** The expressions answer in any value field, so a row
can double what is already there rather than replacing it with a number somebody typed:

```gdscript
if process_material is ParticleProcessMaterial:
	process_material.spread = process_material.spread * 2.0
```

### Other use cases

**Painting toy.** Persistent canvas plus Draw Circle at the cursor every frame gives you a brush, and Clear Canvas gives you the eraser - a complete drawing game in three rows.

**Tether between two units.** A dashed line redrawn every frame from one unit to the other reads instantly as a leash, a beam, or a repair link, and costs nothing when the rows stop firing.

**Heat map of player deaths.** Stamp a soft blob at each death position onto a persistent canvas and route Canvas Texture into a full-screen TextureRect at the end of the run.

**Footprint trail.** A stamp on each footfall on a persistent canvas leaves a trail that survives the character walking away, with no pooled sprites to manage.

**Boss phase telegraph library.** Save each attack's shape as a DrawingPrefabResource and let one Draw Prefab row, fed the phase's resource, draw whichever telegraph the fight is currently in.

## Tips and common mistakes

- **Auto-clear is the number one source of "my drawing does not show up".** With auto-clear ON, a shape
  drawn once from a one-time trigger is wiped the same frame. Either redraw it every frame, or turn
  auto-clear off.
- **The opposite mistake is drawing every frame onto a persistent canvas.** That is thousands of stacked
  strokes and a surface that only ever gets more opaque. Persistent canvases want event-driven strokes.
- **Clear Canvas on a persistent canvas lands next frame.** The wipe is scheduled, not immediate, and
  strokes resume accumulating right after it, so you do not need to re-enable anything.
- **Configure Canvas is optional but decides the defaults.** The first drawing row builds the surface
  with the standard setup; Configure Canvas is how you change size, coordinates, auto-clear or whether
  it is shown. Run it before you draw, not after.
- **World coordinates are centred on the host node**, not on the world origin. A shape drawn at 0,0 lands
  on the node. If your drawing appears offset by the node's position, that is the mode talking.
- **The canvas has a fixed pixel size.** Anything drawn beyond Width x Height is simply outside the
  texture. A level-wide decal surface needs a big canvas, or several hosts with their own.
- **Draw Line Of Sight is a physics query, not a shader.** Its Collision Mask decides which layers stop
  the rays. Leave it at 1 and rays only stop on layer 1, which is usually why a cone shines through
  walls that live on another layer.
- **Ribbons are identified by the node they follow.** Stop Ribbon with a different Follow node does not
  stop the ribbon you started. Keep the same node in all three ribbon rows.
- **The Drawing rows use the shared CanvasSurface runtime**, which ships with `eventsheet_addons/` as
  plain GDScript. It travels with your exported game like any other pack runtime, but it does mean these
  particular rows are not the zero-file plain-Godot output the rest of the vocabulary emits.
- **Set Emitting true does not replay a finished one-shot.** Once a one-shot emitter has finished,
  `emitting` is already false and setting it true may do nothing useful. Use Restart / Burst.
- **CPU and GPU emitters do not share rows.** Set One-Shot, Set Amount, Is Emitting and Amount are
  scoped to GPUParticles2D. For a CPUParticles2D you have Set Emitting (CPU), Restart / Burst (CPU) and
  Set Speed Scale (CPU); reach anything else with the generic Set Property action.
- **On Particles Finished is a one-shot trigger.** A looping emitter never emits `finished`, so a
  cleanup row hung off it will never run.
- **Emit Particles (in object) takes the first GPUParticles2D in tree order** and is guarded, so an
  object with no emitter silently does nothing. Target the emitter directly with On node when an object
  carries several.
- **The seven particle words are two objects.** Gravity, spread, speed, size and colour are the
  process material's; lifetime and amount are the emitter node's. The rows hide that, and the code
  echo on each row shows which one it wrote.
- **A Set Particle row that writes the material has no On node parameter.** Its template opens with
  the own-it `if`, and a guard cannot be written around a node named in the middle of it, so it acts
  on the emitter the sheet is attached to. The five material words read the same way. Only the two
  NODE words carry the field: **Set Particle Lifetime**, **Set Particle Amount**, **Fade Particle
  Lifetime**, **Particle Lifetime** and **Particle Amount** can be aimed at another emitter.
- **Setting the amount rebuilds the whole buffer.** Use it at a moment, never every frame, and never
  in a loop. There is deliberately no fade for it.
- **An emitter wearing a particle shader ignores these rows entirely.** The properties live inside
  the shader there, so the rows write nothing rather than failing.
- **Speed and size are ranges.** Setting only one end is how every particle in an effect ends up
  moving at exactly the same speed; both ends are on the one row so that cannot happen.
