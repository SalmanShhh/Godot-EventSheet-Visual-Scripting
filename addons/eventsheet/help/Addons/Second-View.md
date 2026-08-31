# Second View

**Second View** ships as the `SecondView` autoload - a second picture of the world you are already
in. A view is a **SubViewport sharing the running world** plus a camera of its own that follows a
node you name. Point it at the player and show it in a small corner panel and you have a minimap;
point it at a corridor and show it on a wall screen and you have a security monitor; point it at a
face and you have a portrait. Same four rows, different frames.

Four rows and one expression is the whole vocabulary: **Make A View**, **Show View In**, **Set View
Zoom**, **Stop View**, and **View Texture Of** for the places a frame cannot reach.

![One event on the canvas: On created, then Make a view named "minimap" following $Player at zoom 0.25, then Show view "minimap" in $HUD/MinimapFrame](../images/second-view-rows.png)

Those two sentences, running: the corner panel is a `TextureRect` holding the SubViewport the pack
built, drawing the same world the big picture is drawing, from further back.

![A 2D level of coloured blocks seen close up, with a small yellow player square in the middle, and in the top right corner a bordered panel showing the same level from much further back with the yellow marker in it](../images/second-view-running.png)

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [What this pack refuses to do](#what-this-pack-refuses-to-do)
4. [Setup](#setup)
5. [ACE reference](#ace-reference)
6. [Use cases](#use-cases)
7. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this pack shines

- **Minimaps**, where a pulled-back camera on the player is the whole feature.
- **Security monitors and camera banks**, where several views watch several places at once.
- **Character portraits**, where a tight view of a face belongs in a dialogue box or a party panel.
- **Rear-view mirrors**, where the frame is a strip along the top of the screen.
- **Magnifiers and sniper scopes**, where zoom above 1 is the point.
- **In-world screens**, where the frame is a Sprite3D standing in the level rather than on the HUD.
- **Picture-in-picture cutaways**, where a distant event is worth showing without leaving the player.
- **Split screen**, which is two views in two frames and needs no row of its own.

## Core concepts

- **A view shares the world, it does not copy it.** The SubViewport is given the running game's
  `World2D` or `World3D`, so it draws the same objects the main camera is drawing. Nothing is
  duplicated and nothing is simulated twice.
- **The followed node decides which kind of view you get.** A `Node2D` gets a `Camera2D` on the 2D
  world; a `Node3D` gets a `Camera3D` looking straight down at it on the 3D world. You never say
  which - the node you point at already said it. A node that is neither warns and builds nothing.
- **Zoom means "how much of the world is in frame", in both dimensions.** Below 1 pulls back and
  shows more (`0.25` is a typical minimap), above 1 pushes in and shows less (a magnifier). In 3D it
  divides the camera's height above the followed node, so the direction is the same either way.
- **The frame sizes the render.** A view shown in a 200x120 `TextureRect` renders 200x120 pixels
  rather than being stretched out of a square, and follows that panel when the window resizes.
- **A view whose node was destroyed parks itself.** It stops being redrawn and stops costing a frame,
  and its last picture stays on screen instead of going black on its own. **Stop View** is what
  actually removes it.
- **The nodes are ordinary Godot, and you can go and look at them.** Each view is a `SubViewport`
  named `View_<the name>` parented to the `SecondView` autoload, with an ordinary `Camera2D` or
  `Camera3D` inside it. Nothing about them is special, so anything Godot lets you do to a camera you
  can still do to these.

## What this pack refuses to do

Three things are deliberately absent, because saying them here is more use than a row would be.

- **No split-screen verbs.** Two views in two frames IS split screen. Make a view following player
  one and a view following player two, show each in one half of an `HBoxContainer`, and you are done
  in two sentences - which is why there is no third one.
- **No per-view culling masks in v1.** The camera a view builds is an ordinary `Camera2D` /
  `Camera3D`, so the visibility-layer vocabulary already decides what a view is allowed to draw: tick
  a marker's **Show Only To** layer for the minimap layer and the minimap camera draws it and nothing
  else does. A row of this pack's own would be a second way to say the same thing.
- **No drawing.** Painting shapes, ribbons and telegraphs onto a texture is the
  [Drawing Canvas](Drawing-Canvas.md) pack's job, and the shared runtime under it owns that
  SubViewport. This pack owns world views. Both are built out of the same engine part and neither
  builds the other's.

Two neighbours are worth naming while you are here. [Named Scenes](Named-Scenes.md) addresses *which*
scene the player travels to; a view never changes scene, it is a second look at the one they are in.
And the Editor Tools row **Render Scene To Image** is the one-shot cousin: it photographs a scene
*file* to a `.png` from the editor, where a view is live and belongs to the running game.

## Setup

1. Open **Sheet > New Behaviour Addon…** and pick Second View, or use **Tools > Register Autoload**
   on `res://eventsheet_addons/second_view/second_view_addon.gd`. It registers as `SecondView`.
2. Put a `TextureRect` on your HUD where you want the view to appear.
3. Two rows: **Make A View** naming the view and the node it follows, then **Show View In** naming
   that view and that `TextureRect`.

## ACE reference

On the canvas these rows read as styled sentences - parameter values in **bold**, the nodes in
*italic*, exactly as the rows draw them:

- Make a view named **"minimap"** following *$Player* at zoom **0.25**
- Show view **"minimap"** in *$HUD/MinimapFrame*
- Set view **"minimap"** zoom to **0.4**
- Stop view **"minimap"**

### Actions

| Action | Parameters | Description |
|--------|-----------|-------------|
| Make A View | view_name, followed, zoom | Builds a view under a name. `view_name` is what every later row addresses it by; `followed` is the node its camera tracks and decides whether the view is 2D or 3D; `zoom` is how much of the world is in frame (below 1 shows more, above 1 shows less). Making a name twice replaces it. |
| Show View In | view_name, frame | Hands the view's live picture to `frame` - a `TextureRect`, or anything else with a texture. One view may be shown in as many frames as you like, and a Control frame also sizes the render. |
| Set View Zoom | view_name, zoom | Changes how much of the world `view_name` has in frame, without rebuilding it. A zoom of zero is floored rather than obeyed. |
| Stop View | view_name | Frees the view and its camera, taking the picture back off every frame it was shown in first. Stopping a view that is not there does nothing. |

### Expressions

| Expression | Returns | Description |
|-----------|---------|-------------|
| View Texture Of | Texture2D | The view's live picture as a texture, for the places Show View In cannot reach - a material's albedo, a shader parameter, a theme icon. Nothing for a name no view answers to. |

## Use cases

**1. A minimap in two rows.** The whole feature, at boot.

```gdscript
extends Node


func _ready() -> void:
	SecondView.make_a_view("minimap", $Player, 0.25)
	SecondView.show_view_in("minimap", $HUD/MinimapFrame)
```

**2. Zoom the minimap out as the level opens up.** One row, no rebuild.

```gdscript
extends Node


func _on_area_unlocked() -> void:
	SecondView.set_view_zoom("minimap", 0.12)
```

**3. A security monitor watching a corridor.** The view follows a marker rather than the player.

```gdscript
extends Node


func _ready() -> void:
	SecondView.make_a_view("east_hall", $Cameras/EastHall, 0.6)
	SecondView.show_view_in("east_hall", $Security/Screen1)
```

**4. A bank of monitors, one row per screen.** Names keep them apart.

```gdscript
extends Node


func _ready() -> void:
	for index: int in $Cameras.get_child_count():
		var post: Node2D = $Cameras.get_child(index)
		SecondView.make_a_view(post.name, post, 0.6)
		SecondView.show_view_in(post.name, $Security.get_child(index))
```

**5. A character portrait in the dialogue box.** Zoom above 1 tightens onto the face.

```gdscript
extends Node


func _on_speaker_changed(speaker: Node2D) -> void:
	SecondView.make_a_view("portrait", speaker, 2.5)
	SecondView.show_view_in("portrait", $Dialogue/Portrait)
```

**6. A rear-view mirror strip.** The frame is a wide, short `TextureRect`, and it sizes the render.

```gdscript
extends Node


func _ready() -> void:
	SecondView.make_a_view("behind", $Car/RearPoint, 0.5)
	SecondView.show_view_in("behind", $HUD/MirrorStrip)
```

**7. A magnifier that follows the cursor.** Zoom above 1 is the whole idea.

```gdscript
extends Node


func _ready() -> void:
	SecondView.make_a_view("glass", $Cursor, 3.0)
	SecondView.show_view_in("glass", $HUD/Loupe)
```

**8. A sniper scope that opens and closes.** Stop View is the closing half.

```gdscript
extends Node


func _on_aim_pressed() -> void:
	SecondView.make_a_view("scope", $Player/MuzzlePoint, 4.0)
	SecondView.show_view_in("scope", $HUD/Scope)


func _on_aim_released() -> void:
	SecondView.stop_view("scope")
```

**9. Split screen, in two sentences.** No row for it, because it does not need one.

```gdscript
extends Node


func _ready() -> void:
	SecondView.make_a_view("p1", $PlayerOne, 1.0)
	SecondView.make_a_view("p2", $PlayerTwo, 1.0)
	SecondView.show_view_in("p1", $Split/Left)
	SecondView.show_view_in("p2", $Split/Right)
```

**10. A picture-in-picture cutaway when something happens elsewhere.** Show the door opening across
the level without taking the player's camera away.

```gdscript
extends Node


func _on_far_door_opened(door: Node2D) -> void:
	SecondView.make_a_view("cutaway", door, 1.0)
	SecondView.show_view_in("cutaway", $HUD/Cutaway)
	await get_tree().create_timer(2.0).timeout
	SecondView.stop_view("cutaway")
```

**11. The same view in two frames at once.** A minimap in the corner and the same view large on the
pause screen.

```gdscript
extends Node


func _ready() -> void:
	SecondView.show_view_in("minimap", $HUD/MinimapFrame)
	SecondView.show_view_in("minimap", $PauseMenu/BigMap)
```

**12. A screen standing in the 3D world.** The frame is a `Sprite3D`, not a `TextureRect`.

```gdscript
extends Node


func _ready() -> void:
	SecondView.make_a_view("lobby", $Cameras/Lobby, 1.0)
	SecondView.show_view_in("lobby", $Security/WallScreen)
```

**13. A view on a material, through the expression.** For the places a frame cannot reach.

```gdscript
extends Node


func _ready() -> void:
	SecondView.make_a_view("lobby", $Cameras/Lobby, 1.0)
	$Monitor.material_override.albedo_texture = SecondView.view_texture_of("lobby")
```

**14. Follow whoever is being spectated.** Re-making the name swaps who the view watches.

```gdscript
extends Node


func _on_spectate_next() -> void:
	SecondView.make_a_view("spectate", next_player(), 0.8)
```

**15. Zoom a portrait as the speaker gets angry.** The view is already there; only the zoom moves.

```gdscript
extends Node


func _on_mood_changed(intensity: float) -> void:
	SecondView.set_view_zoom("portrait", lerpf(2.0, 4.0, intensity))
```

**16. Take the minimap down for a cutscene, and put it back after.** Stop View clears the frame, so
the panel is genuinely blank rather than frozen.

```gdscript
extends Node


func _on_cutscene_started() -> void:
	SecondView.stop_view("minimap")


func _on_cutscene_finished() -> void:
	SecondView.make_a_view("minimap", $Player, 0.25)
	SecondView.show_view_in("minimap", $HUD/MinimapFrame)
```

**17. A drone view the player can send out.** The followed node is the drone, and destroying the
drone parks the view rather than breaking it.

```gdscript
extends Node


func _on_drone_launched(drone: Node2D) -> void:
	SecondView.make_a_view("drone", drone, 0.7)
	SecondView.show_view_in("drone", $HUD/DroneFeed)
```

### Other use cases

**Level-editor overview.** A pulled-back view on the level root, shown in a docked panel, gives a builder the whole map beside the piece they are placing without a second window.

**Boss telegraph.** A view following the boss, shown for two seconds when it starts a big attack, tells the player what is coming while they keep control of their own camera.

**Photo mode framing.** A view following a free-flying marker, shown full-screen, is the viewfinder; the expression hands the same picture to whatever writes the file.

**Replay corner.** A view following a ghost node replaying a recorded run sits beside the live player, so a time-trial shows both at once with no second scene.

**Accessibility zoom.** A view following the player at a zoom the options menu owns, shown over the whole screen, is a magnifier for players who need one, built out of the same two rows.

## Tips and common mistakes

- **The followed node decides 2D or 3D, so point at the right thing.** Following a `Control` or a
  plain `Node` warns and builds nothing, because there would be nowhere to put a camera.
- **A view is not free.** It is a second render of the world every frame. Two or three are ordinary;
  a dozen is a budget decision, and the frame each one costs is real.
- **Make A View twice under one name replaces it.** That is what makes a spectate button one row -
  and it also means a Make A View on a per-frame trigger rebuilds the view every frame. Make it once.
- **Stop View, not just hiding the frame.** Hiding the `TextureRect` leaves the view rendering. Stop
  View is what stops paying for it.
- **A view whose node was destroyed keeps its last picture.** That is deliberate - a frame going
  black on its own reads as a bug. Call Stop View when you mean it gone.
- **The HUD is not in the view.** A `CanvasLayer` belongs to the viewport it is in rather than to the
  world, so your HUD is not drawn into the minimap. This is almost always what you want.
- **In 3D the camera looks straight down.** That is the minimap and security-monitor read. If you
  want it aimed some other way, the `Camera3D` inside `View_<name>` under the `SecondView` autoload
  is an ordinary node - move it yourself, or attach the Follow pack to it.
- **Zoom is not the frame size.** Zoom is how much world is in frame; the frame's own size is what
  the view renders at. Resize the panel to change the second, not the first.
