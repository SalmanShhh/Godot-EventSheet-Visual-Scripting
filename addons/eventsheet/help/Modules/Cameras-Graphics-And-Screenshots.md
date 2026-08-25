# Cameras, Graphics and Screenshots

Everything here is about what the player actually sees: which camera is looking, how wide its view
is, how the frame is rendered, what the shaders are told, and how to save the result as a PNG.

Four groups of rows share that job.

- **The 2D camera** - **Make Current**, **Set Zoom**, **Set Offset**,
  **Set Scroll Limits**. Plain `Camera2D` members, node-scoped, so any of them can act on another
  camera through the optional **On node** parameter.
- **The 3D field of view** - **Tween Camera FOV** eases the ACTIVE camera, **Adjust Camera FOV**
  nudges one camera relatively, **Camera FOV** reads it back.
- **The renderer** - clear color, antialiasing, 3D resolution scale, debug draw modes, occlusion
  culling, debanding, plus the frame statistics a performance HUD reads.
- **Shaders and materials** - one uniform on one node, a global uniform every material sees, and
  assigning or clearing a material outright.

All of it compiles to plain `RenderingServer`, `Camera2D`, `Camera3D` and `CanvasItem` calls with no
plugin runtime. The window and fullscreen switches an options menu also needs live in the
Game Options and the Window guide.

## Table of Contents

1. [Where this shines](#where-this-shines)
2. [Core concepts](#core-concepts)
3. [Reference tables](#reference-tables)
4. [Use cases](#use-cases)
5. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this shines

- **Switching cameras** between the player, a cutscene view and a map view.
- **A zoom that follows the action** in a 2D game.
- **Camera limits** that stop the view sliding off the edge of a level.
- **Aim-down-sights** and speed-boost field-of-view moves in 3D.
- **A Graphics tab** with antialiasing, resolution scale and debanding switches.
- **A performance slider** that renders 3D at a fraction of the window resolution.
- **A debug hotkey** that flips the viewport to wireframe or overdraw and back.
- **World-wide shader effects** - wind, wetness, day-night tint - from a single global uniform.
- **A hit flash or dissolve** driven by one shader parameter on one sprite.
- **A screenshot key** and a photo mode.
- **A perf HUD** showing draw calls, objects, primitives and video memory.

## Core concepts

- **The current camera is a property of the camera, not the world.** **Make Current** promotes
  the camera it runs on (or the one named in **On node**) to be the view. There is no "camera off"
  action; you make a different one current instead.
- **Zoom is a Vector2, and bigger means closer.** `Vector2(2, 2)` is a 2x zoom in. Non-uniform values
  stretch the view, which is occasionally a deliberate effect and usually a mistake.
- **Camera limits are four numbers, written in one row.** **Set Scroll Limits** emits four
  assignments (`limit_left`, `limit_top`, `limit_right`, `limit_bottom`) as a single action.
- **The FOV rows split by who they target.** **Tween Camera FOV** resolves
  `get_viewport().get_camera_3d()` at runtime, so it always eases the camera the player is looking
  through, and it does nothing (safely) when there is no camera. **Adjust Camera FOV** and
  **Camera FOV** are scoped to a `Camera3D` node instead. Both FOV writers clamp to the legal 1-179
  degrees, so a repeated zoom can never turn the camera inside out.
- **Rendering switches are per-viewport.** Every MSAA / AA / scale / debug-draw / culling action targets
  `get_viewport().get_viewport_rid()`, which is the viewport the row's node lives in. Applied from a
  normal game sheet, that is the main one.
- **Global shader parameters must be declared first.** **Set Global Shader Parameter** writes a
  uniform declared in Project Settings > Shader Globals. Every material that reads it updates at
  once. A name that was never declared is simply not there.
- **A per-node shader parameter needs a material.** **Set Effect Parameter** and **Effect Parameter**
  call straight through `material`, so the node needs a `ShaderMaterial` assigned - use
  **Set Effect** if the sheet is the thing that assigns it.
- **A screenshot is the viewport's texture.** **Take Screenshot** grabs the current viewport image and
  writes a PNG, so it captures exactly what is on screen, HUD included.

## Reference tables

Multi-line templates are shown by their first line; the full emitted block appears in the matching
use case below.

### The 2D camera (picker section: Camera, node type Camera2D)

| Name | What it does | Ships as |
|------|--------------|----------|
| Make Current | Makes this camera the one the player views the game through. | `{target.}make_current()` |
| Set Zoom | Sets how zoomed in or out the camera is (a Vector2). | `{target.}zoom = {zoom}` |
| Set Offset | Shifts the view away from the position the camera follows. | `{target.}offset = {offset}` |
| Set Scroll Limits | Sets the bounds the camera will not scroll past (Left, Top, Right, Bottom). | `{target.}limit_left = {left}` … (multi-line, use case 4) |
| Set Smoothing | Turns the camera's smooth catch-up on or off. | `{target.}position_smoothing_enabled = {enabled}` |
| Scroll Toward | Eases the camera toward another node, closing the gap at the given rate every second. | `{target.}global_position = {target.}global_position.lerp({toward}.global_position, {rate} * get_process_delta_time())` |

An opened `.gd` file reads these same words back. `camera.make_current()` reads as **Make current**,
`camera.zoom = Vector2(2, 2)` as **Set zoom to 200%**, `position_smoothing_enabled = true` as
**Set smoothing on**, and the lerp-follow idiom
(`camera.global_position = camera.global_position.lerp(target.global_position, 5 * delta)`) as
**Scroll toward target at 5** with `(per second)` said quietly after it. A run of adjacent
`limit_left` / `limit_right` / `limit_top` / `limit_bottom` writes reads as ONE
**Set scroll limits 0 to 1920** row, with the edges it set named after the sentence and every line
it stands for on the hover - the file keeps all four lines exactly as they were.

### Field of view (picker section: Camera)

| Name | What it does | Ships as |
|------|--------------|----------|
| Tween Camera FOV | Smoothly eases the ACTIVE 3D camera's field of view to a target over Seconds. | `var __fovcam_{uid} := get_viewport().get_camera_3d()` … (multi-line, use case 6) |
| Adjust Camera FOV | Nudges a `Camera3D`'s field of view by a relative Change, clamped to 1-179. | `fov = clampf(fov + {delta}, 1.0, 179.0)` |
| Camera FOV | A `Camera3D`'s current field of view in degrees. | `{target.}fov` |

### Quality switches (picker section: Rendering)

| Name | What it does | Ships as |
|------|--------------|----------|
| Set MSAA (2D) | Multisample antialiasing for 2D on this viewport. | `RenderingServer.viewport_set_msaa_2d(get_viewport().get_viewport_rid(), {level})` |
| Set MSAA (3D) | Multisample antialiasing for 3D on this viewport. | `RenderingServer.viewport_set_msaa_3d(get_viewport().get_viewport_rid(), {level})` |
| Set Screen-Space AA | Turns FXAA on or off - cheaper than MSAA, softer. | `RenderingServer.viewport_set_screen_space_aa(get_viewport().get_viewport_rid(), {mode})` |
| Set 3D Resolution Scale | Renders 3D at a fraction of the window resolution and upscales. | `RenderingServer.viewport_set_scaling_3d_scale(get_viewport().get_viewport_rid(), {scale})` |
| Set Occlusion Culling | Skips objects hidden behind occluders. | `RenderingServer.viewport_set_use_occlusion_culling(get_viewport().get_viewport_rid(), {enabled})` |
| Set Debanding | Dithers away banding in smooth dark gradients. | `RenderingServer.viewport_set_use_debanding(get_viewport().get_viewport_rid(), {enabled})` |
| Set Debug Draw Mode | Switches the viewport to wireframe, overdraw or unshaded, and back. | `RenderingServer.viewport_set_debug_draw(get_viewport().get_viewport_rid(), {mode})` |
| Set Clear Color | Sets the background color where nothing else draws. | `RenderingServer.set_default_clear_color({color})` |
| Clear Color | The current default background color. | `RenderingServer.get_default_clear_color()` |
| Uses Modern Renderer | True on Forward+ / Mobile, false on Compatibility. | `RenderingServer.get_rendering_device() != null` |

The MSAA dropdowns offer `RenderingServer.VIEWPORT_MSAA_DISABLED`, `..._2X`, `..._4X` and `..._8X`
(2D defaults to disabled, 3D to 4X). Screen-Space AA offers
`RenderingServer.VIEWPORT_SCREEN_SPACE_AA_DISABLED` and `..._FXAA`. Debug Draw offers
`RenderingServer.VIEWPORT_DEBUG_DRAW_DISABLED`, `..._WIREFRAME`, `..._OVERDRAW` and `..._UNSHADED`.

A menu wants these as one word - Low, Medium, High - and that word is a FILE. See the Game Settings
pack for Apply Quality, which writes a preset's values as ordinary setting changes so the rows you
already wrote do the work.

### Drawing order (picker section: Rendering)

| Name | What it does | Ships as |
|------|--------------|----------|
| Draw In Front Of | Puts this node one step in front of another in the drawing order. | `{target.}z_index = {other}.z_index + 1` |
| Show Only To | Limits which cameras draw this node, by the project's own visibility layer names. | `{target.}visibility_layer = {layers}` |
| Is On Screen | True while a camera is showing the node. | a `VisibleOnScreenNotifier2D`, the node's own or one added on demand |

**Draw In Front Of is relative on purpose.** Two hand-set `z_index` numbers drift apart the moment
anyone moves a node or adds one between them; "one in front of the Player, whatever the Player is"
survives that. Set the number directly (Set Property, or the Inspector) when you want an absolute
layer rather than a relationship.

**Show Only To ticks names, never bits.** A camera draws what its own cull mask and a node's
visibility layer share, so a marker ticked for "minimap" alone is drawn by the minimap camera and by
nothing else. The names are the project's: Project Settings > Layer Names > 2D Render, the same place
the physics layer names live, read live so a layer renamed a minute ago reads by its new name.

**Is On Screen adds a node the first time it is asked.** Godot answers this question with a
`VisibleOnScreenNotifier2D` rather than a property. The row uses the node's own if it has one, and
otherwise adds a plain child called `VisibleOnScreenNotifier2D` - visible in the scene, yours to
move and resize (its rectangle is what counts as "on screen", not the sprite's bounds).

### The frame that ran long (picker section: Debug)

| Name | What it does | Ships as |
|------|--------------|----------|
| On The Frame Running Long | True on the ONE frame where the game has been over budget for the whole run you name. | a per-row run counter, checked each tick |
| On The Frame Recovered | True on the ONE frame where the game has run comfortably for the whole run you name, having been long first. | a per-row run counter and a latch |

Put either under a per-frame trigger. **Frame Took Longer Than** and **FPS Below For** answer "is it
slow right now", which is true sixty times a second; these two answer "it just went wrong" and "it
just came right", which is where a row that turns rain down and puts it back belongs.

Use two thresholds with a gap between them - over 16 ms for 30 frames, under 12 ms for 300 - and the
game cannot flick its own quality up and down on the boundary. Recovered stays silent until
something has actually been long, so a game that started well never hears it.

### The perf HUD numbers (picker section: Rendering)

| Name | What it does | Ships as |
|------|--------------|----------|
| Draw Calls (frame) | How many draw calls the last frame issued. | `RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)` |
| Objects Drawn (frame) | How many objects the last frame rendered after culling. | `RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)` |
| Primitives Drawn (frame) | How many triangles, points and lines the last frame rendered. | `RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)` |
| Video Memory Used | Video memory in use, in bytes. | `RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)` |

### Effects (picker sections: Effects and Rendering)

An effect is a material worn by an object, and a shader uniform is one of that effect's parameters -
so that is what these rows are called.

| Name | What it does | Ships as |
|------|--------------|----------|
| Set Global Shader Parameter | Drives a uniform declared in Project Settings > Shader Globals; every material reading it updates. | `RenderingServer.global_shader_parameter_set({name}, {value})` |
| Global Shader Parameter | Reads that global uniform's current value. | `RenderingServer.global_shader_parameter_get({name})` |
| Set Effect Parameter | Feeds a value into one of this object's effect parameters. | `{target.}material.set_shader_parameter(&{param}, {value})` |
| Effect Parameter | The current value of one of this object's effect parameters. | `{target.}material.get_shader_parameter(&{param})` |
| Tween Effect Parameter | Drives one of an effect's parameters from one value to another over time. | `create_tween().tween_method(func(v): {target.}material.set_shader_parameter(&{param}, v), {from}, {to}, {seconds})` |
| Set Effect | Puts an effect on this object, changing how it draws. | `{target.}material = {material}` |
| Remove Effect | Takes the effect off this object, returning it to how it normally draws. | `{target.}material = null` |

An opened `.gd` file reads the same words: `sprite.material.set_shader_parameter("flash", 1.0)` is
**Set effect parameter flash to 1**, `sprite.material = null` is **Remove effect**,
`sprite.material = preload("res://outline.tres")` is **Set effect to outline**, and the
tween-a-uniform idiom
(`tween.tween_method(func(v): mat.set_shader_parameter("dissolve", v), 0.0, 1.0, 0.5)`) is ONE
**Tween effect parameter dissolve from 0 to 1 in 0.5 seconds** row, on the material it drives.

#### The same five rows with the name picked instead of typed

The rows above take the parameter's name as text you write, which is right for a material that only
exists at run time and wrong everywhere else: `set_shader_parameter(&"disolve", 1.0)` is a call Godot
accepts, returns from, and acts on in no way at all. So a second set of rows takes the name from the
`.gdshader` the node's material really runs. They are offered per node of the attached scene, one
entry per dial the shader declares, described in the shader author's own words, and they read behind
a muted `effect.` lead - **Boss ▸ Set `effect.dissolve` to 0.7**.

| Name | What it does | Ships as |
|------|--------------|----------|
| Set Effect Dial | Turns one dial of the effect this node wears, by a name the shader really declares. | `{target.}material.set_shader_parameter(&"{dial}", {value})` |
| Fade Effect Dial | Walks one dial to a new value over time instead of jumping to it. | `create_tween().tween_method(func(v): {target.}material.set_shader_parameter(&"{dial}", v), {from}, {to}, {seconds})` |
| Effect Dial | Reads one dial back, for any value field. | `{target.}material.get_shader_parameter(&"{dial}")` |
| Effect Dial Is | True while one dial compares as the row says. | `{target.}material.get_shader_parameter(&"{dial}") {op} {value}` |
| Make The Effect This Node's Own | Gives this node a private copy of the material before anything turns a dial on it. | `{target.}material = {target.}material.duplicate()` |

Only a shader file can name a dial, so these five are never browsable on their own: the picker offers
the copies it builds from the open scene and nothing else. Where no shader can be asked - a node
wearing nothing, a name nothing declares - a line falls back to the free-string **Set Effect
Parameter** row above, which claims nothing about any shader. **Make The Effect This Node's Own** is
the row to write first whenever the material is a `.tres`, because a `.tres` is a file and every node
pointing at it shares every dial on it.

### Lights

The six knobs a running game actually touches. Godot spells brightness `energy` on a 2D light and
`light_energy` on a 3D one, which is why each of those is its own row rather than one row guessing
which kind of light it was handed. Brightness is a fraction and the row shows it as a percentage,
because that is how a reader sets it and how every other 0-to-1 setting on the sheet reads.

| Name | What it does | Ships as |
|------|--------------|----------|
| Set Light Energy (2D) | Sets how bright a 2D light is. | `{node}.energy = {value}` |
| Set Light Colour (2D) | Sets the colour a 2D light casts. | `{node}.color = {colour}` |
| Set Light On/Off | Switches a 2D light on or off without hiding the node. | `{node}.enabled = {on}` |
| Set Shadows On/Off | Turns a light's shadows on or off. | `{node}.shadow_enabled = {on}` |
| Set Light Energy (3D) | Sets how bright a 3D light is. | `{node}.light_energy = {value}` |
| Set Light Colour (3D) | Sets the colour a 3D light casts. | `{node}.light_color = {colour}` |
| Set Layer Tint | Tints a whole 2D layer at once - the one row that makes a level read as night. | `{node}.color = {colour}` |
| Set Ambient Light | Sets how much light a 3D scene has with no light shining on it. | `{node}.environment.ambient_light_energy = {value}` |

`$CanvasModulate.color = Color(0.2, 0.2, 0.4)` in an opened `.gd` reads **System ▸ Set layer
tint**, and a world environment's ambient energy is **System ▸ Set ambient light to 30%**.

### The lights of your scene (picker section: Lights in this scene)

The rows above take the light as a field. These take it as the OBJECT: pick the light off the
picker's *Lights in this scene* shelf and the row reads **Torch ▸ Set brightness to 1.2**, with the
light in the column where a reader looks for it.

One word covers both dimensions and the code echo shows the property your light really has, because
Godot spells every knob differently depending on which light you picked: brightness is `energy` on a
2D light and `light_energy` on a 3D one, reach is `texture_scale` (a 2D point light), `omni_range`
or `spot_range`, and on/off is `enabled` in 2D but `visible` in 3D, because a Light3D has no
`enabled` at all. Each row is hosted on the class that really answers to it, so a spot light is
offered a cone angle and a directional light is offered no reach.

| Name | What it does | Ships as |
|------|--------------|----------|
| Set Brightness | Sets how bright the light is, as a fraction. | `{target.}energy = {value}` (3D: `light_energy`) |
| Fade Brightness | Walks the brightness to a new value over time - one tween, no state to keep. | `create_tween().tween_property({target}, "energy", {value}, {seconds})` |
| Set Colour | Sets the colour the light casts. | `{target.}color = {value}` (3D: `light_color`) |
| Set Reach | Sets how far the light gets: a texture scale in 2D, metres in 3D. | `{target.}texture_scale = {value}` (3D: `omni_range` / `spot_range`) |
| Set Cone Angle | Sets how wide a spot's cone opens, in degrees. | `{target.}spot_angle = {value}` |
| Turn On | Lights the light. | `{target.}enabled = true` (3D: `visible`) |
| Turn Off | Puts it out. | `{target.}enabled = false` (3D: `visible`) |
| Turn Shadows On | Makes the light cast shadows. | `{target.}shadow_enabled = true` |
| Turn Shadows Off | Stops it casting them. | `{target.}shadow_enabled = false` |
| Is On | True while the light is lit. | `{target.}enabled` (3D: `visible`) |
| Is Casting Shadows | True while the light casts shadows. | `{target.}shadow_enabled` |
| Brightness | Reads the brightness back, for any value field. | `{target.}energy` (3D: `light_energy`) |
| Colour | Reads the colour back. | `{target.}color` (3D: `light_color`) |
| Reach | Reads the reach back. | `{target.}texture_scale` (3D: `omni_range` / `spot_range`) |

An opened `.gd` file reads these words too, and the row stores the spelling it lifted from, so
`$Torch`, the variable you held the light in, and `get_node("Torch")` each come back exactly as you
wrote them: `lamp.energy = 0.5` is **lamp ▸ Set brightness to 0.5**, `lamp.shadow_enabled = true`
is **lamp ▸ Turn shadows on**, and `create_tween().tween_property($Lantern, "energy", 1.0, 0.5)`
is **Lantern ▸ Fade to 1.0 over 0.5 s**. The gate is the SCENE: a line becomes a light row only
when the scene the sheet is attached to (or a typed declaration in the file itself) says the node it
names really is a light, so `$Door.visible = false` stays the script block it is rather than being
relabelled.

### The darkness of your scene (picker section: Darkness in this scene)

Darkening a 2D level in Godot is a `CanvasModulate`: one node that multiplies everything on the
layer by its colour. That is exactly right and says nothing - `Color(0.3, 0.3, 0.36)` does not tell
anyone how dark the cave feels. So the row keeps the colour, which is all Godot stores and all a
re-save writes back, and READS as the darkness it makes: **Level ▸ Set darkness to 70%, tinted
#4d4d5c**. The percentage is how much light the tint takes away, by the engine's own reckoning of
how bright a colour is, so a green-ish gloom reads darker than a blue one of the same numbers -
which is what your eye says too.

Pick the node off the picker's *Darkness in this scene* shelf and the row arrives aimed at it.

| Name | What it does | Ships as |
|------|--------------|----------|
| Set Darkness | Darkens a whole 2D layer at once - the one row that makes a level read as night. | `{target.}color = {value}` |
| Fade Darkness | Walks the layer's darkness to a new value over time instead of jumping to it. | `create_tween().tween_property({target}, "color", {value}, {seconds})` |

Set Layer Tint above is the same write with the node in a field instead of in the object column; it
is untouched, and a sheet saved with it opens with it.

### The world's atmosphere (picker section: Atmosphere in this scene)

A 3D scene's fog, glow and ambient light live on the `Environment` a `WorldEnvironment` node holds.
These rows take that node as the OBJECT, so the column reads **World** and the sentence reads the
word: **World ▸ Turn fog on**, **World ▸ Set fog thickness to 0.03**.

| Name | What it does | Ships as |
|------|--------------|----------|
| Turn Fog On | Switches the world's fog on - the one row that turns a clear day into a misty one. | `{target.}environment.fog_enabled = true` |
| Turn Fog Off | Switches it off again. | `{target.}environment.fog_enabled = false` |
| Set Fog Thickness | Sets how thick the fog is. Small numbers: 0.01 is a haze, 0.1 is a wall. | `{target.}environment.fog_density = {value}` |
| Turn Glow On | Switches the glow on - what makes neon, fire and magic read as bright. | `{target.}environment.glow_enabled = true` |
| Turn Glow Off | Switches it off again - and gives the frames back. | `{target.}environment.glow_enabled = false` |
| Fade The Glow | Walks the glow to a new strength over time. | `create_tween().tween_property({target}.environment, "glow_intensity", {value}, {seconds})` |
| Set Ambient Light | Sets how much light the scene has with no light shining on it. | `{target.}environment.ambient_light_energy = {value}` |
| Make The Environment This Scene's Own | Gives this scene its own copy of the environment before anything changes it. | `{target.}environment = {target.}environment.duplicate()` |

That last row is the one to know about. A `WorldEnvironment` usually points at a `.tres` FILE, and a
file is shared: writing fog at run time writes it for every other scene that loads the same file, so
the weather follows the player out of the room and is still there next time. `environment =
environment.duplicate()` at the top of the sheet is the engine's own answer, and this is the row
that says it.

### What the scene tells the head

Three of these facts are worth knowing before the game runs, and none of them is in the script - so
an attached sheet reads them off the scene every time it opens, shows them as bands on its head, and
stores none of them:

- **lit by** - one band per light: its name, the plain word for what kind it is, and *casts shadows*
  when it does.
- **shadows** - how many `LightOccluder2D`s can actually block those shadows. Godot draws a shadow
  only where an occluder's own mask shares a layer with the light's shadow mask, so when none does,
  this band says so instead of counting: *Candle casts shadows and no occluder's mask matches -
  shadows never appear*. That is the classic "I turned shadows on and nothing happened", visible
  before you press play.
- **environment** - which environment resource the scene loads, and how many OTHER scenes load the
  same one (*shared with 2 other scenes*), which is the quiet version of the warning above.

Clicking a band selects that node in the Scene dock, where the Inspector that owns the fact is.


### The screenshot (picker section: General Actions)

| Name | What it does | Ships as |
|------|--------------|----------|
| Take Screenshot | Saves what is on screen right now as a PNG. | `get_viewport().get_texture().get_image().save_png({path})` |

## Use cases

**1. Switch to the cutscene camera and back.** Two rows in two events, each on the camera that should
take over:

```gdscript
make_current()
```

**2. Do it from the level sheet instead**, by filling the **On node** parameter:

```gdscript
$CutsceneCamera.make_current()
```

**3. Zoom in for a boss reveal.** **Set Zoom** with a Vector2:

```gdscript
$Camera2D.zoom = Vector2(1.6, 1.6)
```

Zoom back out with `Vector2(1, 1)`.

**4. Keep the camera inside the level.** One **Set Scroll Limits** row emits all four bounds:

```gdscript
limit_left = 0
limit_top = 0
limit_right = 3840
limit_bottom = 1080
```

**5. Lead the camera in the direction the player is moving**, with **Set Offset** under a
per-frame trigger:

```gdscript
offset = Vector2(facing * 80.0, 0.0)
```

**6. Aim down sights.** **Tween Camera FOV** eases whichever 3D camera is active, so it works whether
the player is on foot or in a vehicle:

```gdscript
extends Node


var __fovcam_c1 := get_viewport().get_camera_3d()
if __fovcam_c1 != null:
	create_tween().tween_property(__fovcam_c1, "fov", clampf(50.0, 1.0, 179.0), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
```

Release fires the same row with the resting value (75) instead.

**7. A speed-boost widen.** The same action with a wider target and a longer duration:

```gdscript
extends Node


var __fovcam_c2 := get_viewport().get_camera_3d()
if __fovcam_c2 != null:
	create_tween().tween_property(__fovcam_c2, "fov", clampf(95.0, 1.0, 179.0), 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
```

**8. A scroll-wheel zoom on a specific camera.** **Adjust Camera FOV** is relative and clamps itself,
so holding the wheel down cannot break the view:

```gdscript
fov = clampf(fov + -5.0, 1.0, 179.0)
```

**9. A zoom readout in the HUD**, from the **Camera FOV** expression:

```gdscript
$ZoomLabel.text = str($PlayerCamera.fov)
```

**10. A Graphics tab: antialiasing.** One row per dropdown entry:

```gdscript
RenderingServer.viewport_set_msaa_3d(get_viewport().get_viewport_rid(), RenderingServer.VIEWPORT_MSAA_4X)
```

```gdscript
RenderingServer.viewport_set_screen_space_aa(get_viewport().get_viewport_rid(), RenderingServer.VIEWPORT_SCREEN_SPACE_AA_FXAA)
```

**11. A performance slider.** **Set 3D Resolution Scale** is the classic one - 0.5 renders 3D at half
resolution and upscales:

```gdscript
RenderingServer.viewport_set_scaling_3d_scale(get_viewport().get_viewport_rid(), 0.5)
```

**12. Fix banded skies and dark gradients** with **Set Debanding**:

```gdscript
RenderingServer.viewport_set_use_debanding(get_viewport().get_viewport_rid(), true)
```

**13. Turn on occlusion culling for a big interior level:**

```gdscript
RenderingServer.viewport_set_use_occlusion_culling(get_viewport().get_viewport_rid(), true)
```

**14. A wireframe debug hotkey.** One key sets the mode, another sets it back:

```gdscript
RenderingServer.viewport_set_debug_draw(get_viewport().get_viewport_rid(), RenderingServer.VIEWPORT_DEBUG_DRAW_WIREFRAME)
```

```gdscript
RenderingServer.viewport_set_debug_draw(get_viewport().get_viewport_rid(), RenderingServer.VIEWPORT_DEBUG_DRAW_DISABLED)
```

**15. Gate an expensive effect on the renderer.** **Uses Modern Renderer** is false on Compatibility
(old GPUs, most web exports):

```
On Ready
  Condition: Uses Modern Renderer
    -> Set Occlusion Culling  true
  Else
    -> Set 3D Resolution Scale  0.75
```

**16. Fade the whole world to a color at night** with **Set Clear Color**, reading the old one back
with **Clear Color** first if you plan to restore it:

```gdscript
RenderingServer.set_default_clear_color(Color(0.02, 0.03, 0.08, 1))
```

**17. One wind value, every material.** Declare `wind_strength` in Project Settings > Shader Globals,
then drive it from a single row per frame:

```gdscript
RenderingServer.global_shader_parameter_set("wind_strength", 0.3 + sin(deg_to_rad(game_time * 40.0)) * 0.2)
```

**18. Read a global back** where another system needs it, with **Global Shader Parameter**:

```gdscript
current_wind = RenderingServer.global_shader_parameter_get("wind_strength")
```

**19. A hit flash on one sprite.** **Set Effect Parameter** writes one uniform on the node's own
material:

```gdscript
material.set_shader_parameter(&"flash", 1.0)
```

Follow it with a **Wait** and the same row at `0.0`.

**20. Swap a material in and out.** **Set Effect** assigns, **Remove Effect** removes:

```gdscript
material = preload("res://materials/frozen.tres")
```

```gdscript
material = null
```

**21. A perf HUD.** Four expressions in one label, under a per-frame trigger:

```gdscript
$PerfLabel.text = str("draws " + str(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)) + "  objects " + str(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)))
```

**22. Warn when video memory climbs.** **Video Memory Used** is bytes, so divide before comparing:

```
Every 1.0 seconds
  Condition: Compare Values  Video Memory Used / 1048576.0 > 1500
    -> Print Log  "VRAM over 1.5 GB"
```

**23. A screenshot key.** **Take Screenshot** writes a PNG into the writable folder:

```gdscript
get_viewport().get_texture().get_image().save_png("user://screenshot.png")
```

**24. Photo mode.** Hide the HUD, wait a frame so the hidden HUD is actually off screen, then shoot:

```
On photo key pressed
  -> Hide  (On node $Hud)
  -> Await Next Frame
  -> Take Screenshot  "user://photo.png"
  -> Show  (On node $Hud)
```

### Other use cases

**A dynamic FOV rig.** Read Camera FOV every frame and Tween Camera FOV toward a value derived from speed, so the view widens as the player accelerates and settles when they stop.

**A colour-blindness preset.** One Set Global Shader Parameter row per mode, read by a screen-space shader that every material already shares.

**A benchmark screen.** Run a fixed camera path, sample Draw Calls (frame) and Primitives Drawn (frame) each second into an array, and recommend a 3D Resolution Scale from the result.

**A minimap camera.** A second Camera2D with its own zoom and limits, made current only while the map key is held, restored to the player camera on release.

**An overdraw audit hotkey for artists.** Set Debug Draw Mode to overdraw plus a screenshot in the same event, so a level pass produces a folder of heat maps.

## Tips and common mistakes

- **Make Current has no opposite.** To leave a cutscene view, make the player's camera current
  again. Hiding or freeing the cutscene camera without doing that leaves the game looking through
  nothing in particular.
- **Camera zoom is inverted from what people expect.** Larger numbers zoom IN. `Vector2(0.5, 0.5)`
  shows twice as much world, not half.
- **Camera limits are absolute world pixels**, not a size. Right and Bottom are the far edges, so a
  3840-wide level ends at `right = 3840`, not `right = 1920`.
- **Adjust Camera FOV has no On node parameter.** Its template reads `fov` back on the right-hand
  side, and the builtin retargeting pass refuses to prefix a line that reads the member it assigns -
  retargeting it would fold one camera's FOV into another. Put the row on the camera itself, or use
  **Tween Camera FOV**, which resolves the active camera at runtime.
- **Tween Camera FOV is not node-scoped either.** It always animates the camera the player is looking
  through. If two of these run at once they fight; guard the second one.
- **The FOV rows are 3D only.** A 2D game's "zoom" is **Set Zoom**.
- **Rendering switches are viewport-scoped.** A row that runs inside a `SubViewport` changes that
  sub-viewport, not the game window. That is occasionally exactly what you want and is a confusing
  surprise otherwise.
- **MSAA is not free, and it is not the same as FXAA.** MSAA costs performance and memory; FXAA is
  cheap and blurs. Offering both in the same options tab (and letting a player pick neither) is the
  usual answer.
- **Occlusion culling needs project setup.** The action toggles it on this viewport, but it only helps
  when occlusion culling is enabled in Project Settings and occluders exist in the scene.
- **A debug draw mode stays on** until something sets it back to
  `RenderingServer.VIEWPORT_DEBUG_DRAW_DISABLED`. Wire the hotkey as a toggle, or you will ship a
  wireframe build.
- **A global shader parameter must be declared before it can be set.** Project Settings > Shader
  Globals is where the name and its type live; setting an undeclared name does nothing visible.
- **Set Effect Parameter needs a ShaderMaterial on the node.** With no material assigned, the emitted
  `material.set_shader_parameter(...)` has nothing to call. Assign one in the editor, or with
  **Set Effect** first.
- **Clear Color is not a camera background.** It is the whole-game default background, so changing it
  affects every scene until it is changed back.
- **Screenshots go to `user://`.** `res://` is read-only in an exported game. Also remember the shot
  includes the HUD, so hide anything you do not want in the picture and let a frame pass first.
- **Video Memory Used is in bytes.** Divide by 1048576 before showing it as megabytes.
