# Construct 3 → Godot EventSheets Migration Guide

A working map from C3 concepts and vocabulary to their Godot EventSheets equivalents: what each C3 term becomes here, which behaviors have bundled twins, and the one habit worth relearning (reacting instead of polling). The golden rule underneath every table: **everything compiles to plain GDScript** - when a table doesn't cover something, the GDScript way *is* the EventSheets way (drop a GDScript block in the event flow, or write the expression directly - **ƒx** fields are plain GDScript).

![The ACE picker with live search that understands C3 phrases like "every tick", favorites and recents rails, and a plain-language description of the selected action with the GDScript it ships as](previews/editor-ace-picker.png)

## Table of Contents

1. [Scenarios Where This Guide Helps](#1-scenarios-where-this-guide-helps)
2. [The Concept Map](#2-the-concept-map)
3. [Common System Vocabulary](#3-common-system-vocabulary)
4. [Polling vs Reacting - The Biggest Shift from C3](#4-polling-vs-reacting---the-biggest-shift-from-c3)
5. [When Does My Code Run? - Top-to-Bottom, and Where That Stops](#5-when-does-my-code-run---top-to-bottom-and-where-that-stops)
6. [Data Plugins (Dictionary, Array, JSON, XML)](#6-data-plugins-dictionary-array-json-xml)
7. [Behaviors and Plugins - The Three Lanes](#7-behaviors-and-plugins---the-three-lanes)
8. [Habits That Transfer Directly](#8-habits-that-transfer-directly)
9. [Habits to Relearn (the Godot Way Is Better Here)](#9-habits-to-relearn-the-godot-way-is-better-here)
10. [Importing a C3 Event Sheet](#10-importing-a-c3-event-sheet)
11. [Use Cases](#11-use-cases)
12. [Tips and Common Mistakes](#12-tips-and-common-mistakes)

---

## 1. Scenarios Where This Guide Helps

- **You're porting a C3 game by hand.** Migration is a sheet-by-sheet rebuild (faster than it sounds, because the grammar is the same), and every table here is a lookup for "what is X called now?"
- **You keep typing C3 words into the picker.** Good - keep doing that. The picker's search understands C3 phrasing ("every tick", "on created", "spawn") via synonym aliases, so type what you know and the Godot equivalent surfaces.
- **You leaned on a C3 behavior and want its twin.** 76 packs are bundled, including faithful ports of custom C3 addons (Drag & Drop, Virtual Cursor, Health, Platform Info, the UHTN planner and more) - see [the three lanes](#7-behaviors-and-plugins---the-three-lanes).
- **Your events all start with "Every tick".** The single biggest mental shift from C3 is reacting to signals instead of polling; [section 4](#4-polling-vs-reacting---the-biggest-shift-from-c3) gives you the rule of thumb.
- **You expect events to run top to bottom, and includes to run where the include line sits.** Inside a sheet you get exactly that; between triggers, between nodes, and for includes the answer changes - [section 5](#5-when-does-my-code-run---top-to-bottom-and-where-that-stops) draws the three boundaries.
- **You relied on the Dictionary / Array / JSON data plugins.** They're first-class variable types here, with their own picker groups - no addon needed.
- **You have a `.c3p` and want the events, not a rebuild.** [Section 10](#10-importing-a-c3-event-sheet) is the importer: what it reads, what becomes which row, and what it says about the rows it cannot spell.

---

## 2. The Concept Map

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
| Functions (event sheets) | Sheet functions - callable as actions, optionally **exposed as ACEs** project-wide. Turn a selection of actions into one via **Extract-to-Function** (calls render as a first-class **ƒ** action) |
| Timer behavior | **TimerBehavior pack** (Start/Stop Timer, On Timer) - or a Timer node + `On Timeout` |
| Flash / Tween behaviors | **FlashBehavior pack** (Flash, On Flash Finished); tweens via a GDScript block (`create_tween()…`) |

---

## 3. Common System Vocabulary

| Construct 3 | Godot EventSheets / generated GDScript |
|---|---|
| Every tick | **Every Frame** trigger (`_process(delta)`) - but if you're checking for an *event* (a collision, a timer ending, a key press), prefer the matching **signal** trigger instead; see [Polling vs reacting](#4-polling-vs-reacting---the-biggest-shift-from-c3) |
| On start of layout | `On Ready` trigger (`_ready()`) - and when you OPEN a .gd file as a sheet it reads back under exactly this name: a `_ready` on the script the scene itself carries is **On start of layout**, a `_ready` on a script sitting on an object in the scene is that object's **On created**, and `_exit_tree` is **On end of layout** or **On destroyed** the same way round |
| Compare variable | **Compare Variable** condition - variable, a labeled operator dropdown (`= (equal to)`, `>= (at least)`…), value; **Compare Values** for two arbitrary expressions. Or just type the condition: `health < 50` (plain GDScript) |
| Set variable / Add to | `Set Variable` / `Add To Variable` actions, or `health += 10` in ƒx |
| On collision / overlap | `On Body Entered` / `On Area Entered` (Area2D) - connections are generated |
| Destroy | `Queue Free` |
| Set position / angle | `Set Position` / `Set Rotation` (Node2D) |
| Simulate control (Platform) | PlatformerMovement behavior ACEs (`Jump`, `Set Move Speed`, `Set Gravity Angle`) |
| Wait | An `await`-flagged action, or `await get_tree().create_timer(1.0).timeout` in a block. An opened .gd reads the one-shot timer the same way: `get_tree().create_timer(2.0).timeout.connect(func(): explode())` reads **Wait 2 seconds then Call Explode** |
| Pick by comparison / For each | **Pick filters**: right-click an event → "Add Pick Filter (For Each)…" - loops a node group/children/any iterable with a GDScript `where` predicate and first-N; compiles to a plain `for` loop |
| Repeat / While | The same pick-filter dialog: the Collection dropdown has **Repeat N times** and **While (condition)** |
| loopindex / loopindex("name") | Name the loop's **Loop index** field (convention: `loop_index`), then read the **Loop Index** expression; nested loops take distinct names and **Loop Index Of** reads an outer one - 0-based like C3, even over offset ranges |
| random(a, b) | `randf_range(a, b)` / `randi_range(a, b)` |
| dt | `delta` |
| lerp(a, b, x) | `lerp(a, b, x)` |
| clamp / min / max / abs | Same names in GDScript |

The picker's search understands C3 phrasing ("every tick", "on created", "spawn"…) via
synonym aliases, so type what you know and the Godot equivalent surfaces.

---

## 4. Polling vs Reacting - The Biggest Shift from C3

In Construct 3 the bread-and-butter pattern is **"every tick, check if X"** - one big event sheet
asking questions 60 times a second. Godot can do exactly that (**Every Frame** + a condition), but its
*native* habit is the opposite: **react to a signal** - the engine tells you the moment something
happens, so you don't have to keep asking. For a migrating C3 user this is the single biggest mental
adjustment, and it's the one that makes a Godot project feel clean instead of like a polling soup.

**The rule of thumb:** is the thing you're checking an **event** (it *happens at a moment*) or a
**continuous value** (it's *true/changing over time*)?

- **Event → use a signal trigger.** Collisions, a timer finishing, a button press, an animation
  ending, a node entering the tree - Godot emits a signal for these, so react to it once instead of
  re-checking every frame.

  ```text
  C3 reflex (polling):    Every Frame  →  if Player overlaps Coin  →  collect    (runs 60×/sec)
  Godot idiom (reacting):  On Body Entered (Coin's Area2D)        →  collect    (fires once, on contact)
  ```

  Both compile to valid GDScript; the second is cheaper, clearer, and the way Godot is built to work.
  The picker increasingly nudges you here - when you reach for a polling condition that has a signal
  twin, it surfaces the reactive trigger first.

- **Continuous value → polling in **Every Frame** is correct - don't contort it into a signal.** Camera
  follow, smoothing a position toward a target, reading the movement axis each frame, or
  `is_on_floor()` (Godot deliberately has *no* "landed" signal) are all genuinely per-frame work.
  **Every Frame** is the right, idiomatic home for them. Per-frame is not a smell; *re-checking for an
  event that already has a signal* is.

****Every Frame** vs `On Physics Process` (`_process` vs `_physics_process`):** if the logic moves a body
or touches physics (velocity, `move_and_slide`, raycasts), put it in **On Physics Process** - it runs
on a fixed timestep so physics stays stable. Visual-only, UI, and non-physics logic belong in **On
Process** (every rendered frame). When in doubt for *movement*, choose Physics Process.

---

## 5. When Does My Code Run? - Top-to-Bottom, and Where That Stops

In Construct 3 you always know the order: an event sheet runs top to bottom every tick, and
an included sheet is spliced in right where the include line sits. Keep that expectation
INSIDE a sheet - it is guaranteed here, by the compiler rather than by convention - and adjust
it at exactly three boundaries.

**Inside one sheet: top to bottom, exactly as in C3.** Your rows compile to plain GDScript in
the order you wrote them, into the handler their trigger names. Every **Every Frame** row lands
in `_process` in row order, every **Every Physics Tick** row in `_physics_process`, every
**On Ready** row in `_ready`; nested rows are nested blocks; a row's conditions run before its
actions. This is the "structure mirrors code" contract and the lossless round-trip depends on
it, so it cannot drift. Read the GDScript panel beside any sheet and the order you see is the
order that runs.

**Boundary 1 - between triggers, the clock decides, not the row position.** An Every Frame row
and an Every Physics Tick row in the same sheet are not "above" and "below" each other at run
time: one runs when the frame ticks, the other when the fixed physics clock ticks, and Godot
never interleaves them by your row order. Put movement under **Every Physics Tick** and
presentation under **Every Frame**; do not sequence between them.

**Boundary 2 - between sheets on different nodes, the scene tree decides.** Godot calls
`_process` on nodes in scene-tree order (depth first, parent before child), so two behavior
sheets on two nodes run in that order every frame. It is deterministic, but it is decided by
where the node sits in the tree, not by anything on either sheet - and someone reordering the
tree changes it silently. If sheet A must run before sheet B, do not rely on the tree: have B
react to a **trigger** A emits. That is the same rule as section 4, and it is the version of
"A then B" that survives a reordered scene.

**Boundary 3 - signals run NOW, at the emit site.** A signal handler runs immediately and
synchronously where the signal is emitted: **On Health Changed** in sheet B interrupts the row
in sheet A that emitted it, B's rows finish, and only then does A's next row run. Once you know
this it is MORE predictable than a C3 trigger, but "top to bottom" is now about the emit site,
not about the handler's position on its sheet.

**Includes are the real difference.** There is no textual include here. The two things that
play the role both run at a definite, visible point:

| C3 habit | Here | When it runs |
|---|---|---|
| Include a sheet so its events run *at this point* | **Teach a Verb** - publish the shared logic and CALL it from a row | Exactly when the calling row runs - more explicit than an include, because the call is a row you can see |
| Include a behaviour sheet for a whole family of objects | A **behavior pack** on the node | In scene-tree order each tick, as a separate node - NOT where any include line sits |
| Include a sheet so *its whole set of events* runs in this script | **Sheet ▸ New shared sheet…**, then **Add ▸ Include sheet…** | Wherever those events' own triggers run - a shared sheet is included as a base class or as a helper, and both are ordinary Godot |

So when you reach for an include meaning "run this shared logic here, now", the honest mapping
is a called function. When you reach for it meaning "give these objects this behavior", it is a
pack, and its ordering is the tree's. When you reach for it meaning "these events belong to every
script like this one", that is a **shared sheet**.

### Shared sheets: the closest thing to an include

`Sheet ▸ New shared sheet…` makes a script whose whole job is to be included, and asks the one
question that belongs to the shared sheet rather than to each script that includes it:

- **as a base class** - the including script `extends` it, so the shared sheet's events simply *are*
  that script's events. The Include bar at the top of the reading names it, and clicking it goes
  there. Use this when the including scripts have no base class of their own.
- **as a helper** - the including script keeps one of it, calls it each tick and forwards its
  triggers to it. The sheet writes those forwarding rows for you. Use this when the script already
  extends something (a `CharacterBody2D`, a pack's class) and cannot extend anything else.

`Add ▸ Include sheet…` then wires any script to it with nothing left to ask, because the wiring was
decided once. Included events read in the includer greyed and foldable; they are editable only in
their own sheet, and changing that sheet changes every script that includes it.

The Project Doctor reports one thing about includes: **two included sheets that both handle the same
trigger**. Both run, in include order, and the last one's answer is the one that lasts - which is
the single confusion you cannot see by reading the includer, because neither handler is written
there.

Rules of thumb, in the sheet's own terms:

- Order **within** a sheet: trust it completely.
- Order **between** two sheets each frame: do not depend on it - make the second react to a
  trigger the first emits.
- Order that must span the whole game (spawn before physics, physics before camera): use the
  tick that owns it, rather than trying to sequence inside one tick.
- Reading the GDScript panel settles any doubt in one look: the emitted handler IS the order.

---

## 6. Data Plugins (Dictionary, Array, JSON, XML)

| Construct 3 | Godot EventSheets |
| --- | --- |
| **Dictionary** addon (Add key, Delete key, Has key, For each key…) | First-class: declare a `Dictionary` variable, then use the **Variables: Dictionary** picker group (Set Key, Delete Key, Has Key, Get/Keys/Values/Size). "For each key" = a pick filter over `your_dict.keys()`. |
| **Array** addon (Push, Pop, Insert, Sort, Contains…) | First-class: declare an `Array` (or typed `Array[int]`) variable, then the **Variables: Array** group (Push Back, Insert At, Delete At, Delete Value, Sort, Shuffle, Contains, Value At, Pick Random). |
| **JSON** plugin (Parse, Stringify, Load/Save) | The **JSON** group: To/From JSON Text, JSON Is Valid, Save/Load JSON File (`user://` paths survive exports). |
| **XML** plugin | Intentionally unsupported - Godot has no XML writer/XPath. Use JSON. |

Everything in these groups compiles to a single direct GDScript line (the tooltip shows
it), and anything not covered is one ƒx expression away.

---

## 7. Behaviors and Plugins - The Three Lanes

Every C3 behavior or plugin lands in one of three lanes: Godot already owns it, a portable pack ships it, or you use the Godot feature directly.

**Look a behavior up by its name.** The Manual ships a page called **Behaviors, by the name you
know** (Manual ▸ the first pages, or just type the behavior's name into the Manual's search box).
One row per behavior you arrive holding - 8 Direction, Bullet, Turret, Move To, Pin, Wrap, Bound to
layout, Rotate, Fade, Flash, Sine, Line of sight, Drag & Drop, Anchor, Solid, Jump-thru, Platform,
Pathfinding, Tween, Timer, Persist, Scroll To, Physics, Car, Orbit, Tile movement, Custom movement,
No save, Shadow caster, Shadow light - and each row answers twice: what the thing **is** here (the
shipped pack, with a link to its reference page, or the Godot node that already does the job and
needs no pack at all), and what a **hand-written** version of it reads like on a sheet. That second
half matters more than it sounds: a `move_and_slide` tick with gravity and a jump test opens as the
Platformer rows, so the code you already have arrives as the behavior it always was, and the sheet
offers to adopt the pack rather than making you rewrite anything.

### Lane 1 - Godot already owns it

The picker wraps the native feature:

| Construct 3 | Godot EventSheets |
| --- | --- |
| Tween behavior | **Tween Property** action (Godot's `create_tween`; all the ease names map to `Tween.TRANS_*` + `EASE_*`) |
| Go to layout / restart layout | **Go To Layout / Restart Layout** (Scene group; also Quit, Pause, Spawn Scene Instance) |
| Audio | **AudioStreamPlayer** group (Play/Stop Sound, Set Volume dB, Is Playing) - Play Sound remembers the LAST SOUND, so Set Last Sound Playback Rate right after gives per-shot pitch variation, C3-style (the default is randf_range(0.9, 1.1)) |
| Sprite animations | **AnimatedSprite2D** group (Play/Stop Animation, Set Animation Frame, Set Mirrored) |
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

### Lane 2 - portable behaviors ship as event-sheet packs

**76 are bundled**:
Platformer, 8-Direction, Timer, Flash, State Machine, **Sine, Orbit, Bullet, Move To,
Follow, Car, Tile Movement, Line of Sight (2D & 3D), Rotate, Fade, Bound To, Wrap** (Follow now
emits On Reached Target, Car On Drift Started / Recovered; Bound To is C3's "Bound to layout",
Wrap adds circular arenas), the motion packs (**Spring**, **Tween**, and **Juice** for
camera/game-feel - trauma screenshake, smooth zoom, squash & stretch), the **Save System**
singleton, a 3D quartet (Sine/Orbit/Bullet/Move To 3D), and faithful ports of custom C3 addons:

| Construct 3 addon | Godot EventSheets pack |
| --- | --- |
| Drag & Drop | **Drag & Drop** (event-driven: Start Drag / Set Drag Point / Drop, follow-speed lag, direction lock, break-distance auto-drop, measured throw velocity, snap/magnet targets - input-agnostic, so a controller or the Virtual Cursor can drive it) |
| Virtual Cursor | **Virtual Cursor** (axis/mouse-driven cursor with homing, solids, bounce, constraints - drives the Drag & Drop pack for gamepad/touch) |
| (Simple) Health | **Health** (current/max HP, damage-absorption resistance, named **Health Pools** = decaying shields that intercept damage in priority order, death/revive/invulnerability, On Damaged/Death/Healed/Revived triggers) |
| Weapon (custom addon) | **Weapon Kit** (ammo + reserve, fire-rate cooldown, single/auto/burst fire modes, timed + instant reload - Fire triggers; you spawn the bullet) |
| HTN planner (custom addon) | **HTN Agent** (utility-driven Hierarchical Task Network - world-state blackboard + primitive/compound tasks whose methods carry preconditions, subtasks, and a utility score) |
| (Simple) Abilities (custom addon) | **Simple Abilities** (grant abilities by id, cooldowns, stack charges with auto-regen, temporary auto-expiring abilities, custom data + tags for bulk ops) |
| Drawing Canvas | **Drawing Canvas** (draw lines/circles/rings/rects/cones/stamps/textured ribbons and raycast line-of-sight fans onto a live texture - persistent paint or per-frame auto-clear; reusable DrawingPrefabResource formations; the **Decal Painter** pack projects the texture onto 3D surfaces) |

Attach as a child node; properties live in the Inspector; their ACEs appear in the picker
automatically.

**Families** → declare a sheet as a **Family** (Sheet Type → Family) and its events iterate over a
whole family of nodes (family-scoped) - see the **Family Arena** showcase. Underneath it's Godot's own
machinery: put nodes in a group (`add_to_group`), pick them with the group pick filter, and attach
shared behavior packs for shared ACEs - so you can also drop to that lower level directly.

### Lane 3 - use the Godot feature directly

Multiplayer (high-level multiplayer API),
3D plugins (Godot 3D), Binary Data (`PackedByteArray`),
i18n (Godot translations).

---

## 8. Habits That Transfer Directly

- **The Project bar is where you left it, under Godot's names or yours.** Turn it on with **View ▸
  Project bar** (it is already on if you are in Simple mode or started from a template) and the
  Object bar gains a *Project* tab listing the whole project by kind: Scenes, Scripts, Classes, Base
  classes, Behaviors, Sounds, Files. With **View ▸ Familiar Words** on it reads *Layouts (scenes)*,
  *Event sheets (scripts)*, *Object types (classes)*, *Families (base classes)* - both words always
  on screen. It is read only: right-click *New scene / New script / New class / Extract base class /
  Import sound* opens Godot's own dialogs, and double-clicking routes a layout to the 2D/3D editor, a
  script to its sheet, an object type to Object properties, a behavior to its reference page. Drag a
  class onto the canvas to start an event on it, a sound for a *Play sound* action, a scene for a *Go
  to layout* action. The ✕ hides it again.
- **Preview is on the sheet.** `▶ Preview layout`, `▶▶ Preview project` and `🐞 Debug layout` sit on
  the toolbar; the keys underneath are Godot's F6 and F5, and while the game runs the first two say
  `■ Stop` and `↻ Restart`. **Sheet ▸ Start page** is the start page you expect - templates by genre,
  what you had open last, and the tutorials.
- **Your keys, in one pick.** **Tools ▸ Keyboard Shortcuts ▸ Preset ▾ ▸ Another event-sheet editor**
  rebinds only the handful that differ - X inverts, Ctrl+E collapses and expands, F4 previews - and
  leaves E / S / C / A / G / Q / V / B exactly where your fingers already put them. Everything stays
  rebindable, and *Reset all to defaults* comes back.

- **Typing `Self.` still answers "what does my object know about itself"**: type `self` in any
  ƒx field (or open the ƒx Expressions dictionary) and a pinned **Self** section lists your
  variables, your host's common properties under their C3 names, your value-returning functions,
  and your attached behaviours. Every entry shows both spellings and inserts plain GDScript -
  `Self.X` is the label, `position.x` is what lands in the field, so the section teaches the
  real language while your muscle memory still works. The mapping in short: `Self.X` is
  `position.x`, `Self.Angle` is `rotation`, `Self.Opacity` is `modulate.a`, `Self.MyVariable` is
  the bare `my_variable`, and `Self.Platform.VectorX` is `$PlatformerMovement.velocity.x` - a
  child node, because behaviours here ARE child nodes. Select your node in the Scene dock and
  the Behaviours group grounds to its actual children under their real names; while Live Values
  streams from a running game it reads the RUNNING instance, behaviours attached at runtime
  included.
- **Double-click empty space and you get C3's two-step add**: page one is *object cards* -
  System first, then every behavior pack, autoload, and addon with its icon - and picking
  one scopes the picker to that object's own vocabulary, exactly like choosing an object then a
  condition in C3. Typing at any point drops into full search, so the fast path stays fast.
  The important difference to notice: what C3 calls an *object type* is here a **node with
  a behavior attached, or an autoload** - the dialog is quietly teaching you Godot's own API.

  ![The picker's object-cards front page: System first, then every pack and autoload as its own card with its icon](images/object-first-add.png)
- **Event numbers live in the margin**, flat and sequential through groups and sub-events,
  computed from the sheet - collapsing or filtering never renumbers, so "check event 34" in a
  forum reply stays meaningful. Jump to one with the command palette's *Go to Event Number*.

  ![The margin counting 1 to 5 straight through a sub-event, so nesting never renumbers anything](images/event-numbers.png)
- **The bookmarks bar is C3's**: Ctrl+M marks a row, F4 / Shift+F4 cycle, and Tools >
  Bookmarks… opens the Previous / Next / Clear All panel whose entries lead with their
  margin event number.

  ![The Bookmarks panel: Previous, Next and Clear All above the marked events, each entry leading with its margin event number](images/bookmarks-panel.png)
- **Ctrl+F has a Filter toggle** (the C3 live-filter reflex): the sheet collapses to only
  the events matching the search, the status line counts what's hidden, Esc restores.

  ![Ctrl+F with Filter on: a five-event sheet collapsed to only the events that match "health"](images/filter-lens.png)
- **Ctrl+Shift+C copies events as text.** The selection copies as the plain listing every
  event-sheet community posts - `+ ` in front of a condition, `-> ` in front of an action, one
  extra indent per sub-event, in exactly the words the canvas is showing under your reading
  lenses. **Sheet > Save as Text…** writes the whole sheet the same way as Markdown, with the
  margin event numbers in a gutter so the file and the sheet agree about what "event 12" is. It
  is read-only output: the round trip already lives in the `.gd`, so nothing pastes back in.
- **Right-click a name > Find all references** opens the **Find results** bar under the sheet:
  every place that variable, function, object, signal or behavior is used, grouped by sheet with
  each hit's event number. Clicking a result jumps to it (opening the sheet when it is not the
  one on screen, and landing on the exact row once it has), F3 and Shift+F3 step forward and back,
  and the bar stays until you close it with ✕. Matching is whole-symbol, so `hp` never finds
  `hp_max`, and the search reaches the `.gd` sheets you have never opened as well as the ones you
  have - a project-wide answer really is project-wide.

  ![The Replace Object References dialog, its From dropdown carrying only the references the selection really uses](images/replace-object.png)

  ![The same dialog with the To field's suggestions open, offering the objects the sheet already names](images/replace-autocomplete.png)
- **The Properties bar is where you edit without leaving the row.** It sits to the right of the
  canvas, splitter-resizable like the Inspector, and shows whatever is selected: a condition or
  action's parameters, an object's properties, a group's name and enabled state. Each parameter
  gets the same field the Edit Parameter dialog would give it - a colour is a swatch you click, a
  fixed choice is a dropdown, a node reference has its picker, an input action has the live Input
  Map list, a number has a spinner - so nothing has to be typed as GDScript by hand. Setting a
  value is one undo step and exactly the edit the dialog would have made, so an opened `.gd` stays
  byte-exact for every line you did not touch. Simple Mode starts it hidden; **View > Properties
  Bar** brings it back. The dialog stays for anyone who prefers it.

  ![One parameters dialog editing every matching action at once, with the "applies to all N matching actions" line under the field](images/batch-param-edit.png)

  ![The Properties bar's fields: a colour swatch, an easing dropdown, an input-action list, a number spinner, a tick and a translatable text field](images/properties-bar-fields.png)
- **The sheet zooms like a code editor**: Ctrl + mouse wheel, Ctrl + + / Ctrl + -, Ctrl + 0 for
  100%, or the pill in the status bar - 50% to 200% in six steps, with text, chips, icons and
  guide lines scaling together. The zoom is remembered for the layout, not for one file, so the
  next sheet opens at the size you were reading at. Row density (Comfortable / Compact) stays a
  separate choice: density trades whitespace for rows, zoom changes how big everything is drawn.
![The Find results bar under the sheet, the Properties bar beside it, and the zoom pill in the status bar](images/sheet-bars.png)

- **Right-click a cell > Select All Events Using This**, then retarget or retune the lot:
  *Replace object…* rewrites every `$Node` / `%Unique` / `self` token-safely - offering the
  objects that have the same conditions and actions first, and flagging in the Doctor any
  parameter that named an instance variable the new object does not have - and
  *Edit Values Across Selection* opens one params dialog whose per-field "all" checkboxes
  decide what overwrites every instance and what stays per-instance - each as one undo step.

  ![Select All Events Using This: the three events of five that share a Print action, selected together](images/select-all-matching.png)
- **Arrows walk cells**: with a row selected, Left / Right step through its trigger,
  condition, and action cells, Enter edits the focused cell, Esc returns to the row.

  ![Right-stepping the cell focus onto an event's second action, with the focused cell highlighted](images/cell-navigation.png)
- **Drag a parameter's NAME sideways to scrub its number.** Speeds, damage, durations and
  angles are found by feel, and retyping them one guess at a time is the slowest loop in
  event-sheet authoring. Hold Shift for a fine pass or Ctrl for a coarse one. The step
  follows the value's own size, so a bullet speed of 3000 and an alpha of 0.5 both move
  usefully under the same gesture. The drag only arms while the field holds a plain number,
  so `health + 10` is never at risk - and it is the property name you drag, not the field,
  which leaves click-to-place-caret and drag-to-select alone (the same gesture as Godot's
  own Inspector).

  ![The same parameters dialog before and after dragging the Speed label 200 pixels to the right: the value moved without a keystroke](images/number-scrubbing.png)
- **View > Outline** is the sheet's method list - groups, `#region` fences, and published
  functions as a click-to-jump tree.

  ![View then Outline: regions, nested groups and published functions as one click-to-jump tree](images/outline-panel.png)
- **View > Arrange by** reads the same sheet four ways: **File order** (the untouched one),
  **Object**, **Trigger** or **Group**. The events are re-grouped under one header each - `Player`
  / `Enemy` / `HUD`, or `On created` / `Every tick (physics)` / `On hit` - and they stay editable
  in place and keep their numbers, because arranging is a way of READING: the file is never
  reordered, the generated GDScript cannot move, and the byte round-trip is untouched. The
  breadcrumb names the header you are scrolled inside and the Outline becomes the same
  arrangement. **View > Saved Views** keeps an arrangement, the filter and the reading lenses under
  one name and puts all three back in a click.

  ![The same sheet arranged by Object: one folder per object with its event count, the events still numbered and editable inside](images/arrange-by-object.png)
- **Right-click an object in the Object bar > Add common events…** gives you the four events you
  were about to type: a `CharacterBody2D` starts with `On created`, `Every tick (physics)`, `On
  hit` and `On died`, a `Button` with `On clicked`, a `Timer` with `On timer`, an `Area2D` with `On
  collision with`, and an attached behaviour pack adds its own triggers. Each event arrives with an
  empty action lane - the sheet's own `+ Add action` waiting for you. A starter naming a signal the
  class does not have makes the sheet declare that signal too, so the trigger you read is one the
  file really has. **Duplicate events for…** on the same menu copies every event that names one
  object, once per object you list, with the reference swapped on each copy.
- **View > Show Events in the Scene** marks every node whose script is a sheet with a small `⌗` and
  its event count, in the Scene dock and beside the node in the 2D editor, with its triggers on
  hover. Nodes with no events are unmarked, and it is off until you ask for it.

  <img src="images/events-overlay-badge.png" alt="A scene tree with a hash badge and an event count beside Player, Enemy and HUD, and nothing beside Background." width="400">
- **A scene opens as one workspace.** Right-click a scene in the FileSystem > **Open its sheets**
  opens the whole layout and every script in it, in tree order, as one tab group named after the
  scene. **Sheet > Workspaces** opens a remembered one again. The unit of work is the scene, so it
  opens as one thing rather than as five openings.
- **Sheet > Export** writes the whole sheet as an **Image (PNG)**, a **PDF** (that image split into
  pages), or **Markdown with figures** (the plain listing plus a figure per group) - in the current
  theme, density and lenses, with the event numbers on. For a forum post, a design doc, or a
  lesson.
- **Sheet > Health…** is one card: how much of the sheet reads as events, its patterns and how many
  of them a shipped behavior could take over, what the Doctor says about this sheet, its Test
  Sheets and how they last went, and how much of it nothing uses. Every line opens the panel it
  came from.

  <img src="images/sheet-health-card.png" alt="The health card for player.gd: reads as events 100% with 4 patterns and 2 adoptable, Doctor 0 errors and 2 notes, 3 Test Sheets with the last run green, and 1 unused thing." width="450">
- **Your open tabs come back**: the session (tabs + active sheet) restores on editor
  restart, like C3 reopening your workspace.
- Double-click empty space to add an event; right-click for context actions.
- Drag conditions/actions to reorder; drag events onto events to nest sub-events.
- Copy/paste works across projects (snippet text on the system clipboard) - and **pasting
  plain GDScript converts to events automatically** when it contains trigger functions.
- Behaviors are added to objects (here: child nodes via the Create Node dialog) and
  configured per-instance in the Inspector.
- **The add keys meet you before you type.** `E` / `C` / `A` open the Ghost Row - a small
  type-a-sentence popup at the selected row - and it greets you with **suggestion chips**
  of your most-used conditions and actions for that key (the picker's featured ones until
  you have habits). One chip click adds the row and hops straight into its first parameter,
  so a familiar add is zero typing. Once you do type, the ranked list **learns**: at equal
  match quality the one you actually use wins the tie, the summoning key leans toward its own kind
  (`A` prefers actions), and every suggestion names the next parameter your sentence has
  not filled yet ("⚡ Heal · amount…") so you always know what the next word will do.

  <img src="images/ghost-row-chips.png" alt="The Ghost Row popup twice: freshly opened with suggestion chips (Play Sound, Set Variable, Make Shuffle Bag, Set Seed) under the query field, and after typing 'heal' with the ranked list showing each Heal candidate naming its next unfilled parameter - amount, target." width="640">
- **Repeated values are one pick, not a retype.** Parameter fields remember the last five
  values you committed for that exact row-and-parameter across the whole project, offered
  from a small dropdown on the field's row - the third time an action needs `"jump"` or
  `res://sfx/hit.ogg`, it is a pick instead of a retype.
- **You always know which group you are in.** On long sheets a slim breadcrumb strip
  ("Gameplay ▸ Combat") stays pinned under the column header while you scroll inside a
  group; click it to jump back to the group's own bar.

  <img src="images/group-breadcrumb.png" alt="Scrolled deep inside a sheet: the slim Gameplay - Combat breadcrumb strip pinned above the rows, with events 8 and 9 visible beneath it." width="560">
- **View > Compact Rows** tightens row padding for jam-speed scanning - text stays the same
  size, only the air shrinks - and toggling it off restores the roomier default. The choice
  is remembered per project.
- **Rows read like C3's.** Every substituted parameter value draws **bold** inside its
  sentence, node/object references draw *italic* in the rows that take one ("add
  *$Enemy* to **"enemies"**"), and numbers, strings and booleans keep their tints -
  automatic for every built-in row and behavior pack, no authoring required.
- **Your C3 keyboard grammar works verbatim** (rebindable via Tools > Keyboard Shortcuts):

  | Key | Action |
  |---|---|
  | `E` | Add event |
  | `C` / `A` | Add condition / action (the type-a-sentence Ghost Row) |
  | `S` | Add sub-event (picker) |
  | `B` | Add blank sub-event |
  | `Q` | Add comment |
  | `G` | Add group |
  | `V` | Add variable |
  | `D` | Toggle disabled |
  | `I` | Invert the selected condition |
  | `R` | Replace the selected trigger / condition / action |

---

## 9. Habits to Relearn (the Godot Way Is Better Here)

![The Set Property rows an Inspector property drag builds, with the value the property has right now already filled in](images/property-drop.png)

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
  node from the Scene dock straight onto a parameter value to reference it - or drag a PROPERTY
  out of the Inspector onto the sheet for a pre-filled Set Property action (its current value baked in).
- **Scenes replace layouts** and instancing replaces "create object by name" - spawn via
  `preload("res://enemy.tscn").instantiate()` in a block or action.

### The Hierarchy pane (the panel you are missing, in Godot's terms)

Click an object's name in any row and the Object properties popup now has a **Hierarchy** section:
the object's parent, its children, and what each child carries.

![The Hierarchy section of the Object properties popup: the parent, four children, and the follow-flags each carries](images/hierarchy-pane.png)

The gestures are the ones you already know. Drag an object in from the Object bar to make it a
child; the four flags open on the drop. Drag a child out onto the canvas to unparent it. Right-click
a child for **flags…**, **Remove from parent** and **Select in scene**.

The flags are the honest part. Godot has no single property for "follow everything except size", so
each tick maps onto something real:

| tick | what it writes |
| --- | --- |
| all four on | a plain Godot child - one `reparent` line, and the chips stay quiet |
| **keeping its place** off | the child snaps to where its new parent stands |
| one or two transforms off | the child is detached, and a `RemoteTransform2D`/`3D` on the parent puts back exactly the parts that stayed on |
| all three transforms off | **ignore parent's movement** - still a child, still freed with the parent, but it stops following |
| **destroy with parent** off | the parent hands the child back to the layout as it leaves the tree |

Two things this pane will not do. It never edits a `.tscn`: children the scene file owns show muted
with **in the scene file** and offer **edit the scene**, which hands the node to Godot's own Scene
dock. And it writes nothing special - every gesture writes ordinary rows through the undo funnel, in
the same spelling a hand-typed file uses, so the pane and the canvas always describe one tree and
Ctrl+Z takes a parenting back like any other edit.

The Project Doctor covers the three ways this goes wrong at run time: a walk over a node's children
that **moves** one of them while it walks (the list is live, so the loop skips the next child), a
reparent of **self** at start of layout (the old parent is still adding its children, and Godot
refuses), and a variable **keeping hold of a child whose parent gets freed**. Each is a note with a
one-click chip naming the single edit to make.

`demo/showcase/hierarchy_playground/` is all of it in one playable room: Space mounts the rider onto
the horse's saddle and dismounts again, the hat follows its wearer's angle but not its size, the
green bar stays upright while the rider leans, one walk over the squad leader's children heals every
soldier among them, and the crates park themselves on the ray they cast down.

![The Hierarchy Playground showcase: a rider mounted on a horse wearing a hat and an upright health bar, a squad of four, and crates settled on the ground](images/hierarchy-playground.png)

---

## 10. Importing a C3 Event Sheet

**Sheet ▸ Import event sheet…** reads a sheet straight out of a C3 project and turns it into
an ordinary EventSheets `.gd`. It is honest rather than magic: every condition, action and
expression whose word this vocabulary already has becomes the row that says the same thing, and
everything else arrives **switched off with its own words beside it** and counted. You see the
result and the exact count before a single byte is written.

![The Import event sheet wizard: the file, the sheet inside it, the object table, the imported sheet in its own words, and the report saying how many rows came across](images/import-event-sheet-wizard.png)

### What it reads

C3 saves a project as a zip (`.c3p`) of JSON: a `.c3proj` naming the project, then
`eventSheets/<name>.json`, `layouts/<name>.json`, `objectTypes/<name>.json` and
`families/<name>.json`. An event sheet file is `{"name": …, "events": [...]}` and every entry is
tagged by its `eventType`: `block` (with `conditions`, `actions` and nested `children`), `group`,
`comment`, `variable`, `include`, `function-block` and `script`. Each condition or action carries
`objectClass`, `id`, `parameters`, and sometimes `behavior-type`, `isInverted`, `isOr` or
`disabled`. Point the wizard at the whole `.c3p`, or at a single exported sheet `.json`.

The archive is only ever **read**. Nothing is written back into it, ever.

### The four questions

1. **Which file.** A project archive lists every sheet inside it; a single `.json` is just itself.
2. **Which sheet.** One at a time, so you can review each one.
3. **Which node is which object.** A table with one line per object the sheet talks to. The kind is
   pre-filled - from the project's own object types when you imported an archive, otherwise guessed
   from the rows the object is used with (an object told to *set animation* is a sprite). The node
   text is written into the rows as-is, so `$Player` means the child called Player. Leave it empty
   and the rows act on the sheet's own node.
4. **What it reads like.** The imported sheet in its own words, plus the report.

Then **Save as…** writes a new `.gd` through the ordinary compiler. It re-opens byte-identically,
like every other sheet.

### What comes across

| In C3 | Here |
| --- | --- |
| Event block | An event: conditions on the left, actions on the right |
| Sub-events (`children`) | Sub-events under their parent |
| `isElse` | An **Else** row |
| `isOr` on a condition | The event's conditions become an **Or** block |
| `isInverted` | The condition is inverted |
| A top-level event with no trigger | **Every frame** - which is what a top-level event means in C3 |
| Group | A group, with its title and description |
| Comment | A comment row |
| Global / local variable | A variable row, typed from the value it started with |
| Function block | A function: its name in the condition lane, its parameters as chips |
| Include | A note in the report, and a note row - import that sheet too, then add it under Manage Includes |
| Keyboard / Mouse / Touch events | The matching input condition on the input trigger |
| System, Sprite, Text, Audio, Array, Dictionary, JSON, Functions rows | The row that says the same thing |
| Instance variables (compare / set / add / subtract / toggle) | The variable rows of the same names |

Expressions are translated by name, and the table is the exact inverse of the one the reading layer
uses to *show* you C3 words: `random(1, 6)` becomes `randf_range(1, 6)`, `choose(a, b)` becomes
`[a, b].pick_random()`, `len(x)` becomes `x.length()`, `distance(a, b)` and `angle(a, b)` become the
calls behind them, `zeropad`, `left`, `mid`, `tokenat` and `tickcount` likewise. `lerp`, `clamp`,
`abs`, `floor`, `ceil`, `round`, `sqrt`, `min` and `max` are spelled the same in both, so they are
left alone. `Sprite.X` becomes the mapped node's `position.x`, and key names like `Space` or
`Left arrow` become `KEY_SPACE` and `KEY_LEFT`.

### What does not, and what it says instead

Nothing is silently approximated. A row that cannot be spelled arrives switched off, its original
words are written into the file, and the report names it with a reason:

- **A behaviour a shipped pack covers.** Bullet, Platform, 8-Direction, Timer, Tween, Sine, Fade,
  Flash, Line of Sight, Drag & Drop, Pin-style movement, Bound to Layout, Local Storage and the rest
  are behaviour *packs* here, not free actions. The report names the pack: "The shipped Platformer
  Movement behaviour covers this - attach it and add the row from its own words."
- **A row with no word here yet** ("No row here spells this yet").
- **A JavaScript block.** It is not GDScript; the report says so and the code is kept as a comment.
- **AJAX and multiplayer.** No pack ships these yet.

A row that *did* map but whose parameter could not be translated is kept as written and **flagged**
in the report, so you know exactly which values still need a human. Every value the wizard could not
translate is listed; nothing that translated cleanly is listed.

At the end of the generated file there is one tally listing every row that did not come across,
including the ones that sat under a switched-off event and therefore wrote nothing of their own. The
project health check (Tools ▸ Project Doctor) counts that tally and reminds you they are still there.

### Known limits

- The report counts **rows**, meaning every condition, action, comment, variable, include and
  function. A group is scaffolding, not a row, so it is not counted.
- A layout name, an object-to-create name and an audio file name are kept as written: point them at
  the scene or the imported sound they became.
- C3's picking (an event narrowing which instances the actions apply to) has no direct twin. Rows
  arrive scoped to the node you mapped; where a C3 event picked a *set* of instances, use a group
  and the picking rows.
- The format is C3's own and moves with its releases. When a row id changes, the importer stops
  recognising that row and says so in the report - it never guesses.

## 11. Use Cases

### 1. Porting a weekend platformer

Movement becomes the Platformer pack, "every tick" phrases match in the picker's live search, and the whole port is re-typing events you already know by heart.

### 2. C3 functions become typed functions

Your `Juice_Screenshake(cMagnitude, cDuration)` recreates as a sheet function with typed params and a condition row gating the body - same shape, now real GDScript underneath.

### 3. Wait-based cutscenes

C3's "Wait 2 seconds" chains port directly: the Wait action compiles to `await`, and handlers are coroutines, so the timing style you know just works. Awaiting actions wear an hourglass in the sheet, objects freed during a wait are skipped when the loop resumes, and the **Once At A Time** condition stops a re-firing event from stacking overlapping runs - C3's async-actions semantics, enforced by the compiler.

### 4. Families, approximately

C3 families map to the family marker plus group iteration here - pick-by-family loops port with the arena showcase as the template.

### 5. The plugins with no equivalent

Multiplayer and XML route to Godot's native features - the migration table names each destination so nothing dead-ends.

### 6. Killing the "every tick" polling soup

An old top-down shooter had one giant sheet asking "is the player overlapping any pickup?" 60 times a second. On the rebuild you swap that block for On Area Entered on each pickup's Area2D, and the migrated logic runs once on contact instead of re-checking every frame - the port comes out cleaner than the C3 original.

### 7. Retiring the Dictionary and Array addons at once

A save-game blob that leaned on the C3 Dictionary and Array plugins ports with no addon at all: declare a `Dictionary` and an `Array` variable, drive them from the Variables: Dictionary and Variables: Array picker groups, then persist with Save JSON File to a `user://` path that survives exports.

### 8. Gamepad drag-and-drop for a jam build

You ported a mouse-only C3 Drag & Drop mechanic on Friday, then a teammate asks for controller support before submission. Because the Drag & Drop pack is input-agnostic, you attach the Virtual Cursor pack to drive it and the same drop, snap, and throw-velocity events now work on a gamepad without touching the drag logic.

### 9. Auto-targeting without the pick loop

A C3 tower that "picked nearest enemy" each tick becomes a single Nearest Node In Group call - no `for` loop to rebuild. When line-of-sight matters, Nearest Visible In Group swaps in so the tower only fires at an enemy it can actually see past cover.

### 10. Handing events to a teammate over chat

Mid-port you need a coworker to reuse the reload sequence you just rebuilt from the C3 Weapon addon. You copy the events, paste the snippet text into chat, and they paste it straight into their sheet - and because plain GDScript with trigger functions converts to events on paste, a raw script from a tutorial drops in the same way.

## 12. Tips and Common Mistakes

- **The polling reflex is the #1 imported habit.** Reaching for **Every Frame** to check for something that *happens at a moment* (a collision, a timer ending, a key press) re-checks 60 times a second for an event Godot already signals. Use the signal trigger; the picker surfaces it first when a polling condition has a signal twin.
- **But don't contort continuous values into signals.** Camera follow, per-frame smoothing, reading the movement axis, `is_on_floor()` (Godot deliberately has no "landed" signal) are genuinely per-frame work - **Every Frame** is their correct, idiomatic home.
- **Movement goes in On Physics Process, not Every Frame.** Anything touching velocity, `move_and_slide`, or raycasts belongs on the fixed timestep so physics stays stable. When in doubt for movement, choose Physics Process.
- **There is no separate expression language.** Every ƒx field is plain GDScript - don't hunt for a C3-style expression dictionary; if you can write it in GDScript, it works in the field.
- **Solid / Jump-thru are scene setup, not events.** They map to Godot collision layers and one-way collision shapes configured on the scene, so don't look for them in the picker.
- **XML is intentionally unsupported.** Godot has no XML writer/XPath; migrate that data to JSON (the **JSON** group covers parse, stringify, and file save/load).
- **Don't wait for a `.c3p` importer.** It's a permanent non-goal (proprietary, unversioned C3 internals); the supported path is the vocabulary map, the parity behavior packs, and text snippets.
- **Most "pick" logic becomes explicit addressing** (paths, groups, signals) - but check **Nearest Node In Group** / **Furthest Node In Group** / **Nearest Visible In Group** before writing a loop; the common auto-targeting case needs none.
- **Paste GDScript, get events.** Pasting plain GDScript that contains trigger functions converts to events automatically - handy when moving logic from tutorials or existing scripts.
