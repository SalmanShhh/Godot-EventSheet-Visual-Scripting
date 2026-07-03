# Construct 3 → Godot EventSheets Migration Guide

A working map from C3 concepts and vocabulary to their Godot EventSheets equivalents.
The golden rule: **everything compiles to plain GDScript** - when this table doesn't
cover something, the GDScript way *is* the EventSheets way (drop a GDScript block in the
event flow, or write the expression directly - `ƒx` fields are plain GDScript).

## Concepts

| Construct 3 | Godot EventSheets |
|---|---|
| Event sheet | **A `.gd` file** bound to a host node class - the sheet *is* GDScript (lossless, editable round-trip). `.tres` still works but isn't required or the default |
| Object type | Godot node class (CharacterBody2D, Area2D, Timer…) - ACEs group under it |
| Behavior (Platform, 8Direction…) | **Behavior sheet** → attachable Node component with a typed `host` accessor (samples: PlatformerMovement, EightDirectionMovement) |
| Plugin / addon (JSON manifests) | **Zero-config addon**: a script in `res://eventsheet_addons/` with `@ace_*` annotations - no manifests |
| Instance variables | Sheet variables (typed; `@export` ones appear in the Inspector per instance). Group with `@export_group`/`@export_subgroup`; typed vars (Vector2/Color/Texture2D/Curve…) get live Inspector **drawers** - a direction dial, colour swatch, texture preview, progress bar, or curve (see the **Inspector Playground** showcase) |
| Local/temp variables | Variables placed inside the event flow → function locals |
| Global variables | Sheet variables on a shared/autoload sheet, or any autoload - plain GDScript rules |
| Groups | Groups (collapsible, nestable, with local variables) |
| Comments (colored) | Comments - multiline, per-comment colors, attachable into an event's actions |
| Sub-events | Sub-events (compile nested under the parent's conditions) |
| Else | Else / Else-If events (compile to `elif` / `else`) |
| Families | **Families** - declare a sheet as a Family (Sheet Type → Family) for family-scoped iteration; see the **Family Arena** showcase. Godot node groups / a behavior shared across nodes remain the lower-level path |
| Layouts | Scenes |
| Layers | CanvasLayers / scene tree order |
| The expression language | **GDScript** - there is no separate language to learn |
| Scripting (JS blocks) | GDScript blocks: class-level or in-flow inside events, with lint + completion |
| Functions (event sheets) | Sheet functions - callable as actions, optionally **exposed as ACEs** project-wide. Turn a selection of actions into one via **Extract-to-Function** (calls render as a first-class **ƒ** verb) |
| Timer behavior | **TimerBehavior pack** (Start/Stop Timer, On Timer) - or a Timer node + `On Timeout` |
| Flash / Tween behaviors | **FlashBehavior pack** (Flash, On Flash Finished); tweens via a GDScript block (`create_tween()…`) |

## Common System vocabulary

| Construct 3 | Godot EventSheets / generated GDScript |
|---|---|
| Every tick | `On Process` trigger (`_process(delta)`) - but if you're checking for an *event* (a collision, a timer ending, a key press), prefer the matching **signal** trigger instead; see [Polling vs reacting](#polling-vs-reacting--the-biggest-shift-from-c3) |
| On start of layout | `On Ready` trigger (`_ready()`) |
| Compare variable | Expression condition, e.g. `health < 50` (plain GDScript) |
| Set variable / Add to | `Set Variable` / `Add To Variable` actions, or `health += 10` in ƒx |
| On collision / overlap | `On Body Entered` / `On Area Entered` (Area2D) - connections are generated |
| Destroy | `Queue Free` |
| Set position / angle | `Set Position` / `Set Rotation` (Node2D) |
| Simulate control (Platform) | PlatformerMovement behavior ACEs (`Jump`, `Set Move Speed`) |
| Wait | An `await`-flagged action, or `await get_tree().create_timer(1.0).timeout` in a block |
| Pick by comparison / For each | **Pick filters**: right-click an event → "Add Pick Filter (For Each)…" - loops a node group/children/any iterable with a GDScript `where` predicate and first-N; compiles to a plain `for` loop |
| random(a, b) | `randf_range(a, b)` / `randi_range(a, b)` |
| dt | `delta` |
| lerp(a, b, x) | `lerp(a, b, x)` |
| clamp / min / max / abs | Same names in GDScript |

The picker's search understands C3 phrasing ("every tick", "on created", "spawn"…) via
synonym aliases, so type what you know and the Godot equivalent surfaces.

## Polling vs reacting - the biggest shift from C3

In Construct 3 the bread-and-butter pattern is **"every tick, check if X"** - one big event sheet
asking questions 60 times a second. Godot can do exactly that (`On Process` + a condition), but its
*native* habit is the opposite: **react to a signal** - the engine tells you the moment something
happens, so you don't have to keep asking. For a migrating C3 user this is the single biggest mental
adjustment, and it's the one that makes a Godot project feel clean instead of like a polling soup.

**The rule of thumb:** is the thing you're checking an **event** (it *happens at a moment*) or a
**continuous value** (it's *true/changing over time*)?

- **Event → use a signal trigger.** Collisions, a timer finishing, a button press, an animation
  ending, a node entering the tree - Godot emits a signal for these, so react to it once instead of
  re-checking every frame.

  ```text
  C3 reflex (polling):    On Process  →  if Player overlaps Coin  →  collect    (runs 60×/sec)
  Godot idiom (reacting):  On Body Entered (Coin's Area2D)        →  collect    (fires once, on contact)
  ```

  Both compile to valid GDScript; the second is cheaper, clearer, and the way Godot is built to work.
  The picker increasingly nudges you here - when you reach for a polling condition that has a signal
  twin, it surfaces the reactive trigger first.

- **Continuous value → polling in `On Process` is correct - don't contort it into a signal.** Camera
  follow, smoothing a position toward a target, reading the movement axis each frame, or
  `is_on_floor()` (Godot deliberately has *no* "landed" signal) are all genuinely per-frame work.
  `On Process` is the right, idiomatic home for them. Per-frame is not a smell; *re-checking for an
  event that already has a signal* is.

**`On Process` vs `On Physics Process` (`_process` vs `_physics_process`):** if the logic moves a body
or touches physics (velocity, `move_and_slide`, raycasts), put it in **On Physics Process** - it runs
on a fixed timestep so physics stays stable. Visual-only, UI, and non-physics logic belong in **On
Process** (every rendered frame). When in doubt for *movement*, choose Physics Process.

## Data plugins (Dictionary / Array / JSON / XML)

| Construct 3 | Godot EventSheets |
| --- | --- |
| **Dictionary** addon (Add key, Delete key, Has key, For each key…) | First-class: declare a `Dictionary` variable, then use the **Variables: Dictionary** picker group (Set Key, Delete Key, Has Key, Get/Keys/Values/Size). "For each key" = a pick filter over `your_dict.keys()`. |
| **Array** addon (Push, Pop, Insert, Sort, Contains…) | First-class: declare an `Array` (or typed `Array[int]`) variable, then the **Variables: Array** group (Append, Insert At, Remove At, Erase, Sort, Shuffle, Contains, Value At, Pick Random). |
| **JSON** plugin (Parse, Stringify, Load/Save) | The **Variables: JSON** group: To/From JSON Text, JSON Is Valid, Save/Load JSON File (`user://` paths survive exports). |
| **XML** plugin | Intentionally unsupported - Godot has no XML writer/XPath. Use JSON. |

Everything in these groups compiles to a single direct GDScript line (the tooltip shows
it), and anything not covered is one ƒx expression away.

## Behaviors & plugins → the three lanes

**Lane 1 - Godot already owns it** (the picker wraps the native feature):

| Construct 3 | Godot EventSheets |
| --- | --- |
| Tween behavior | **Tween Property** action (Godot's `create_tween`; all the ease names map to `Tween.TRANS_*` + `EASE_*`) |
| Go to layout / restart layout | **Go To Scene / Restart Scene** (Scene group; also Quit, Pause, Spawn Scene Instance) |
| Audio | **AudioStreamPlayer** group (Play/Stop Sound, Set Volume dB, Is Playing) |
| Sprite animations | **AnimatedSprite2D** group (Play/Stop Animation, Set Frame, Set Mirrored) |
| Pathfinding behavior | **NavigationAgent2D** group (Find Path To, Has Arrived, Next Path Position) |
| Text object | **Label** group (Set/Append/Get Text) |
| Scroll To behavior (incl. camera shaking) | **Camera2D** group (Make Current, Set Zoom/Offset) + the **Juice** pack (trauma screenshake, smooth zoom, squash & stretch - auto-finds the camera) |
| Set visible/invisible, opacity | **CanvasItem** group (Show, Hide, Set Color Tint, Is Visible) |
| System: `random()`, `choose()`, `clamp()`, `lerp()`, `distance()`, `angle()` | **Math & Random** expressions (Choose is literally `[…].pick_random()`) |
| Solid / Jump-thru behaviors | Godot collision layers + one-way collision shapes (scene setup, not events) |
| Physics behavior | RigidBody2D + the existing impulse/velocity ACEs |
| Particles plugin | **GPUParticles2D / CPUParticles2D** group (control emission + one-shot bursts) |
| Tilemap / Tiled Background | **TileMapLayer** group (read / write / erase cells from events) |
| Timeline (keyframe animation) | **AnimationPlayer** + **AnimationTree** vocabulary (play, travel to state, set blend params, is playing) |
| Persist behavior | the **Save System** pack (save / load game state), or Godot's `ConfigFile` / `ResourceSaver` directly |

**Lane 2 - portable behaviors** ship as event-sheet packs - **31 are bundled**:
Platformer, 8-Direction, Timer, Flash, State Machine, **Sine, Orbit, Bullet, Move To,
Follow, Car, Tile Movement, Line of Sight (2D & 3D)** (Follow now emits On Reached Target, Car On
Drift Started / Recovered), the motion packs (**Spring**, **Tween**, and **Juice** for camera/game-feel -
trauma screenshake, smooth zoom, squash & stretch), the **Save System** singleton, a 3D quartet
(Sine/Orbit/Bullet/Move To 3D), and faithful ports of custom C3 addons:

| Construct 3 addon | Godot EventSheets pack |
| --- | --- |
| Drag & Drop | **Drag & Drop** (event-driven: Start Drag / Set Drag Point / Drop, follow-speed lag, direction lock, break-distance auto-drop, measured throw velocity, snap/magnet targets - input-agnostic, so a controller or the Virtual Cursor can drive it) |
| Virtual Cursor | **Virtual Cursor** (axis/mouse-driven cursor with homing, solids, bounce, constraints - drives the Drag & Drop pack for gamepad/touch) |
| (Simple) Health | **Health** (current/max HP, damage-absorption resistance, named **Health Pools** = decaying shields that intercept damage in priority order, death/revive/invulnerability, On Damaged/Death/Healed/Revived triggers) |
| Weapon (custom addon) | **Weapon Kit** (ammo + reserve, fire-rate cooldown, single/auto/burst fire modes, timed + instant reload - Fire triggers; you spawn the bullet) |
| HTN planner (custom addon) | **HTN Agent** (utility-driven Hierarchical Task Network - world-state blackboard + primitive/compound tasks whose methods carry preconditions, subtasks, and a utility score) |
| (Simple) Abilities (custom addon) | **Simple Abilities** (grant abilities by id, cooldowns, stack charges with auto-regen, temporary auto-expiring abilities, custom data + tags for bulk ops) |

Attach as a child node; properties live in the Inspector; their ACEs appear in the picker
automatically.

**Families** → declare a sheet as a **Family** (Sheet Type → Family) and its events iterate over a
whole family of nodes (family-scoped) - see the **Family Arena** showcase. Underneath it's Godot's own
machinery: put nodes in a group (`add_to_group`), pick them with the group pick filter, and attach
shared behavior packs for shared ACEs - so you can also drop to that lower level directly.

**Lane 3 - use the Godot feature directly**: Multiplayer (high-level multiplayer API),
Drawing Canvas (`_draw`), 3D plugins (Godot 3D), Binary Data (`PackedByteArray`),
i18n (Godot translations).

## Habits that transfer directly

- Double-click empty space to add an event; right-click for context actions.
- Drag conditions/actions to reorder; drag events onto events to nest sub-events.
- Copy/paste works across projects (snippet text on the system clipboard) - and **pasting
  plain GDScript converts to events automatically** when it contains trigger functions.
- Behaviors are added to objects (here: child nodes via the Create Node dialog) and
  configured per-instance in the Inspector.

## Habits to relearn (the Godot way is better here)

- **There is no runtime**: your sheet *is* GDScript after compiling. Read the generated
  script in the GDScript panel - selection highlights both ways. Performance equals
  hand-written code (a tested contract).
- **No object picking** (mostly): Godot addresses nodes explicitly (paths, groups, signals), so most
  C3 "pick" logic becomes a `for` loop block or a signal connection. *But* the common auto-targeting
  case needs no loop - **Nearest Node In Group** / **Furthest Node In Group** pick the closest/farthest
  group member by distance, and the Line of Sight packs add **Nearest Visible In Group** for
  occlusion-correct "attack the nearest enemy I can actually see."
- **Node-picking relief for Godot's deep trees:** pick child nodes **by type** (no path-hunting),
  one-click **"Make %unique"** to collapse a deep `$A/B/C` path to a reparent-proof `%Name`, or drag a
  node from the Scene dock straight onto a parameter value to reference it.
- **Scenes replace layouts** and instancing replaces "create object by name" - spawn via
  `preload("res://enemy.tscn").instantiate()` in a block or action.

## Importing C3 projects directly - a permanent non-goal

There is deliberately **no `.c3p` / C3-clipboard importer**, and there won't be one:
Construct's internal event JSON is proprietary and unversioned - it churns with C3
releases, so an importer would silently rot between updates and break exactly when
users trust it most. Maintaining that treadmill is not sustainable.

The supported migration path is the one this guide documents: the **vocabulary map**
(C3 phrases work in the picker), **behaviors with C3-parity capabilities**, and
**text snippets** for moving events between EventSheets projects. Porting a project is
a sheet-by-sheet rebuild - faster than it sounds, because the grammar is the same.
