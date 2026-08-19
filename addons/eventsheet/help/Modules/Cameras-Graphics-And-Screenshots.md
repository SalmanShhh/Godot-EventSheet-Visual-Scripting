# Cameras, Graphics and Screenshots

Everything here is about what the player actually sees: which camera is looking, how wide its view
is, how the frame is rendered, what the shaders are told, and how to save the result as a PNG.

Four groups of rows share that job.

- **The 2D camera** - **Make Camera Current**, **Set Camera Zoom**, **Set Camera Offset**,
  **Set Camera Limits**. Plain `Camera2D` members, node-scoped, so any of them can act on another
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

- **The current camera is a property of the camera, not the world.** **Make Camera Current** promotes
  the camera it runs on (or the one named in **On node**) to be the view. There is no "camera off"
  action; you make a different one current instead.
- **Zoom is a Vector2, and bigger means closer.** `Vector2(2, 2)` is a 2x zoom in. Non-uniform values
  stretch the view, which is occasionally a deliberate effect and usually a mistake.
- **Camera limits are four numbers, written in one row.** **Set Camera Limits** emits four
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
- **A per-node shader parameter needs a material.** **Set Shader Parameter** and **Shader Parameter**
  call straight through `material`, so the node needs a `ShaderMaterial` assigned - use
  **Set Material** if the sheet is the thing that assigns it.
- **A screenshot is the viewport's texture.** **Take Screenshot** grabs the current viewport image and
  writes a PNG, so it captures exactly what is on screen, HUD included.

## Reference tables

Multi-line templates are shown by their first line; the full emitted block appears in the matching
use case below.

### The 2D camera (picker section: General Actions, node type Camera2D)

| Name | What it does | Ships as |
|------|--------------|----------|
| Make Camera Current | Makes this camera the one the player views the game through. | `{target.}make_current()` |
| Set Camera Zoom | Sets how zoomed in or out the camera is (a Vector2). | `{target.}zoom = {zoom}` |
| Set Camera Offset | Shifts the view away from the position the camera follows. | `{target.}offset = {offset}` |
| Set Camera Limits | Sets the bounds the camera will not scroll past (Left, Top, Right, Bottom). | `{target.}limit_left = {left}` … (multi-line, use case 4) |

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

### The perf HUD numbers (picker section: Rendering)

| Name | What it does | Ships as |
|------|--------------|----------|
| Draw Calls (frame) | How many draw calls the last frame issued. | `RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)` |
| Objects Drawn (frame) | How many objects the last frame rendered after culling. | `RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)` |
| Primitives Drawn (frame) | How many triangles, points and lines the last frame rendered. | `RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)` |
| Video Memory Used | Video memory in use, in bytes. | `RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)` |

### Shaders and materials (picker sections: Rendering and General Actions)

| Name | What it does | Ships as |
|------|--------------|----------|
| Set Global Shader Parameter | Drives a uniform declared in Project Settings > Shader Globals; every material reading it updates. | `RenderingServer.global_shader_parameter_set({name}, {value})` |
| Global Shader Parameter | Reads that global uniform's current value. | `RenderingServer.global_shader_parameter_get({name})` |
| Set Shader Parameter | Feeds a value into one uniform on this node's material. | `{target.}material.set_shader_parameter(&{param}, {value})` |
| Shader Parameter | The current value of a named uniform on this node's material. | `{target.}material.get_shader_parameter(&{param})` |
| Set Material | Assigns a shader or canvas material to this node. | `{target.}material = {material}` |
| Clear Material | Removes any material, returning the node to default drawing. | `{target.}material = null` |

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

**3. Zoom in for a boss reveal.** **Set Camera Zoom** with a Vector2:

```gdscript
$Camera2D.zoom = Vector2(1.6, 1.6)
```

Zoom back out with `Vector2(1, 1)`.

**4. Keep the camera inside the level.** One **Set Camera Limits** row emits all four bounds:

```gdscript
limit_left = 0
limit_top = 0
limit_right = 3840
limit_bottom = 1080
```

**5. Lead the camera in the direction the player is moving**, with **Set Camera Offset** under a
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

**19. A hit flash on one sprite.** **Set Shader Parameter** writes one uniform on the node's own
material:

```gdscript
material.set_shader_parameter(&"flash", 1.0)
```

Follow it with a **Wait** and the same row at `0.0`.

**20. Swap a material in and out.** **Set Material** assigns, **Clear Material** removes:

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

- **Make Camera Current has no opposite.** To leave a cutscene view, make the player's camera current
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
- **The FOV rows are 3D only.** A 2D game's "zoom" is **Set Camera Zoom**.
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
- **Set Shader Parameter needs a ShaderMaterial on the node.** With no material assigned, the emitted
  `material.set_shader_parameter(...)` has nothing to call. Assign one in the editor, or with
  **Set Material** first.
- **Clear Color is not a camera background.** It is the whole-game default background, so changing it
  affects every scene until it is changed back.
- **Screenshots go to `user://`.** `res://` is read-only in an exported game. Also remember the shot
  includes the HUD, so hide anything you do not want in the picture and let a frame pass first.
- **Video Memory Used is in bytes.** Divide by 1048576 before showing it as megabytes.
