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
- **You leaned on a C3 behavior and want its twin.** 112 packs are bundled, including faithful ports of custom C3 addons (Drag & Drop, Virtual Cursor, Health, Platform Info, the UHTN planner and more) - see [the three lanes](#7-behaviors-and-plugins---the-three-lanes).
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
| Instance variables | Sheet variables, each row reading as one sentence - `Instance number speed = 200` - with the declaration the compiler writes echoed at its right edge. `@export` ones appear in the Inspector per instance and wear a **sliders mark** on the row (hover: "Editable in the Inspector"); the Inspector carries **Instance variables · N** beside *Edit Event Sheet* to open the whole table. Group with `@export_group`/`@export_subgroup` (a labelled folder strip over the rows); typed vars (Vector2/Color/Texture2D/Curve…) get live Inspector **drawers** - a direction dial, colour swatch, texture preview, progress bar, or curve (see the **Inspector Playground** showcase) |
| Local/temp variables | Variables placed inside the event flow → function locals. They read as `Local <type> <name> = <value>` rows at the top of the event they belong to, and their object column says **System**, because a local belongs to the event and to nothing you can select |
| Global variables | Sheet variables on an autoload, or any autoload - plain GDScript rules. The row reads `Global number Score = 0`, the object column names the autoload (`Game`), and the name is bare on the row and qualified in an expression - **Copy as Expression** on the row's menu hands you the `Game.Score` spelling that runs |
| Groups | Groups: one-line head (folder mark, title, description muted beside it, what it holds and its on/off switch at the right edge), a 2px bracket down the left edge of the body in the group's colour, collapsible, nestable, with local variables. One **Edit Group…** dialog holds name, description, Active on start, Can be switched at runtime and Colour. A `#region` fence of the file is the same idea with a dashed bracket, and the two convert into each other |
| Comments (colored) | Comments - multiline, per-comment colors, attachable into an event's actions |
| Sub-events | Sub-events (compile nested under the parent's conditions) |
| Else | Else / Else-If events (compile to `elif` / `else`) |
| Families | **Families** - declare a sheet as a Family (Sheet Type → Family) for family-scoped iteration; see the **Family Arena** showcase. Godot node groups / a behavior shared across nodes remain the lower-level path |
| Layouts | Scenes. The word splits in two here, on purpose: a place the player TRAVELS to keeps the word **Layout** (Go To Layout, Restart Layout, Add Layout On Top), and a file holding a branch of nodes keeps the word **Scene** (Spawn Scene Instance, Save Node As Scene, Scene File Is Data-Only) |
| A pause menu, an inventory or a dialogue box over the layout | **Add Layout On Top**, **Remove Layout On Top** and **Layout Is On Top** - three lines that load the layout, name the copy, and add it under the TREE ROOT rather than under this node, which is what lets it outlive a change of layout beneath it. The name is the node's own name under the root, not a second registry, so all three rows have to say the same one and a close row is safe to run twice. **Set Game Paused** is the row they pair with, and the menu layout's own root node needs Process Mode **Always** or **When Paused** or it is frozen along with the game underneath it |
| Referring to one instance from anywhere, without a path that breaks when you move it | **Godot's own `%name` mark**, spoken both ways. Tick *Access as Unique Name* on a node and the Add picker's object step lists it in a **%names** section with the class the `.tscn` says it is, so the picker scopes to that class's vocabulary; a line somebody already wrote on a `%Name` reads back as a row on that object. Nothing is registered - the mark lives in the scene file, and a field holding `$UI/Bars/HealthBar` offers **Make %HealthBar unique** on its help strip, which is a scene edit through the editor's own undo. Naming a whole SCENE by a short word is the Named Scenes pack's job instead |
| Saving the level a player built in your in-game editor | **Save Branch As Scene File**, and the walk IS the row: `PackedScene.pack` writes out the root plus every node that root OWNS, and a node added while the game runs is owned by nothing, so a plain pack saves a scene holding one node, returns OK twice and loads back empty. The row gives every ownerless node the branch root as its owner first, in lines emitted where you can read them. Coming back in, **Scene File Is Data-Only** is the question to ask first - a `.tscn` is a table of resources and a resource may be a SCRIPT - and it reads that table as text and builds nothing, so it is safe on a file from anywhere |
| A minimap, or a second Layout shown on a layer | The **Second View** pack: a SubViewport SHARING the running world plus a camera of its own following a node you name. **Make A View**, **Show View In**, **Set View Zoom**, **Stop View**, and **View Texture Of** for a material or a shader parameter. The node you follow decides the kind - a Node2D gets a Camera2D, a Node3D a Camera3D looking down - and the frame you show it in sizes the render, so there is no size row |
| Layers | CanvasLayers / scene tree order |
| Collision layers, and "is this Solid?" | **Godot collision layers, said in the project's own words.** A layer is where an object SITS, a mask is what it WATCHES, and the pair is not symmetric: A notices B when A's mask covers a layer B sits on. Five rows take the NAME the project declared in Project Settings ▸ Layer Names - **Collide with `<Layer>`**, **Stop colliding with `<Layer>`**, **Be on layer `<Layer>`**, **Leave layer `<Layer>`** and the question **is set to collide with `<Layer>`** - and what is emitted is still `set_collision_mask_value(2, true)`, the number, with the name resolved when the row is drawn. Rename a layer and every row about it renames itself and no file moves |
| Object type: Solid, Jump-thru, or a trigger volume | **The node family, and it decides what you may ask.** An **Area** detects and lets things through; a **CharacterBody** blocks and is driven by your rows; a **RigidBody** blocks and is thrown by physics; a **StaticBody** blocks and stands still. The picker files rows by node class, so a sheet is only ever offered what its node can really answer, and the row's dialog says which family this is while you fill it in. A touch row on a scene holding nothing physical greys with the fix as its reason - *this row needs an Area2D*, with the button that adds one |
| Effects on an object | A `ShaderMaterial` on the node, and **the shader file names its own dials**: every `uniform` a `.gdshader` declares becomes a picker entry on the nodes wearing it, so the row reads **Boss ▸ Set `effect.dissolve` to 0.7** and a dial the shader does not have cannot be typed. Six packs ship the commonest ones ready-made (Hit Flash, Dissolve, Outline, Grayscale, Wave), each installing its shader into your project as a file you can edit |
| Effects on a layer | The **Screen FX** pack: one `CanvasLayer` holding a `ColorRect` whose shader reads the frame so far. Shockwave, an awaited Fade you build a scene transition out of, Blur and Chromatic pulse - and the rectangle hides itself whenever every effect is idle, so an unused layer draws nothing |
| Z elevation, and a layer's visibility | **Draw in front of** (`z_index = other.z_index + 1`, the one drawing-order line whose meaning is a sentence rather than a number), **Show only to**, whose list is the project's own visibility-layer names, and **Is on screen** as a question |
| Effects quality / a graphics settings screen | **Quality is a folder.** One preset is a `.tres` file in `res://settings/quality/`, so adding a quality word is adding a file and nothing has to be registered. The word stands for values over settings you already declared, so a save file carries the values rather than the word, deleting a preset cannot break anybody's save, and a setting declared later grows a field in every preset. Nudge one value afterwards and the label reads **Custom**, worked out by comparison rather than stored |
| Layout state, and the "escape key closes the wrong thing" bug | **Game modes.** A game's modes are four ordinary declarations, not a new kind of thing: **Go to mode**, **In mode**, **On entering** / **On leaving**, and a group that says which mode it runs in - so a whole group of rules starts and stops running by itself. **Push mode** remembers the one underneath (a menu over a pause over playing) and **Go back** returns to it, which is that bug solved in the vocabulary rather than in a variable. On leaving always fires before On entering |
| An object's own state: a `state` instance variable, and a group per state you switch on and off | **The states band, and four rows.** An object's states are declared once on the sheet head - **Declare states…** writes an `enum State`, the `state` variable whose own setter announces the change, `previous_state`, `state_entered_msec` and a `state_changed` signal, all as ordinary rows. Then **Is in `<state>`**, **Is in `<state>` for over `<seconds>`s**, **Was in `<state>`** and **Go to `<state>`**, plus **On entering** / **On leaving** for the moment itself (for one change, leaving first). Every state is offered from that object's own declarations as you type, so a state is picked rather than remembered, and a row naming one this object does not declare is a Doctor finding rather than something the field forbids. A group named after a state is a CONVENTION and carries no semantics - the rows inside it each ask **Is in** for themselves, which is the one visible reason any of them run. And the machine every Godot tutorial writes by hand - an `enum`, a `var state`, and a `match state:` - opens as exactly these rows and saves back byte for byte |
| The settings dialog, and a controls screen | The **Game Settings** pack, built on one declaration per setting. **Bind To Setting** is one row in both directions - the control writes the setting and the setting moves the control, so a quality preset or a second menu still open moves it back too. **Menu Rows From Declarations** fills a container with one labelled, bound control per declaration, so adding an option later is one Declare row and no scene edit. **Controls Page From The Input Map** does the same for rebinding, and a key something else already answers to fires **On Binding Conflict** with three answers as three rows - swap, take it anyway, or pick another key - instead of quietly stacking two actions on one key. **Apply With A Way Back** starts a countdown before a screen mode you might not be able to see your way out of |
| The expression language | **GDScript** - there is no separate language to learn |
| Scripting (JS blocks) | GDScript blocks: class-level or in-flow inside events, with lint + completion |
| Functions (event sheets) | Sheet functions - callable as actions, optionally **exposed as ACEs** project-wide. Turn a selection of actions into one via **Extract-to-Function** (calls render as a first-class **ƒ** action) |
| Multiplayer plugin | **Multiplayer object** - Host a game / Join a game / Leave the game, the seven events the connection fires, `@rpc` messages answered as four questions in words, a group that says who runs it (everyone / the host / the owner), and the scene's `MultiplayerSpawner` and `MultiplayerSynchronizer` as verbs. Not a row-for-row twin of the plugin you know: every row is Godot's own high-level multiplayer call, which is also why a networked project you already wrote opens on these same rows |
| Timer behavior | **TimerBehavior pack** (Start/Stop Timer, On Timer) - or a Timer node + `On Timeout` |
| Flash / Tween behaviors | **FlashBehavior pack** (Flash, On Flash Finished); tweens via a GDScript block (`create_tween()…`) |
| An object's actions and conditions you did not find above | **Any call on a class the sheet can name is already a row.** Wherever the receiver's class is knowable - `self` is what the script extends, an `@onready` node carries its declared type, `var beat: Timer` says so, an autoload is a script at a known path, a bare class name is a class - an ordinary call reads as *object ▸ verb ▸ values* and an ordinary property write reads as *object, property, value*, with the method's or property's own name, its parameter names and its description. Nothing is registered and nothing is curated: the API is the vocabulary. Such a row is drawn in a plainer call style with the class it was read off muted beside the object, so a curated sentence and a derived one are never confused, and a curated table landing later upgrades the row in place with the file untouched |
| Instance variable with a setter | **The variable row, with the accessor as a sub-row.** `var health: int = 100:` followed by `set = _set_health` reads as the variable it is, with *On health set ▸ `_set_health`* under it saying which function runs and when (and a getter reads as an expression row, not an event) - and that function goes on reading as the function it is, where it was written, rather than being copied under the declaration |
| Keyboard / gamepad events *inside* an input handler | Two families, filed apart so they cannot be mistaken for each other. The **Input Event** section asks the ONE event a handler was handed - *this event is "jump" going down*, *going down, or repeating*, *coming up*, *this event is "jump"*, *how hard "jump" is held in this event*. The **Input** section asks the keyboard how things stand right now, which is what an every-tick event wants. Action names come from the project's own Input Map in both |
| Project files, and the two places to put them | **Files, Files: Directories, Files: Tables and Files: Archives** - every row compiles to the `FileAccess`, `DirAccess`, `JSON`, `ZIPPacker` or `ZIPReader` call it names, with no virtual filesystem and no import step between the sheet and the disk. Godot's two places are `res://` (the game's own files, read-only once exported) and `user://` (the player's folder, writable), and every path field says which one its path is in under the box, so the export trap is visible where it is made rather than in a doc. Reads are forgiving by default - a missing file is empty text - and **Read Text File (or a fallback)** puts the answer you would rather have in a second slot, with the guard written into the emitted line |
| File chooser, and drag-and-drop from the desktop | **The drop and the ask**, two doors that hand back a path and nothing else. **On Files Dropped** is the window's own `files_dropped` signal as an event (desktop only, said on the row). **Ask For A File To Open** and **Ask Where To Save** open the platform's own chooser through `DisplayServer.file_dialog_show`, with the `FileDialog` fallback emitted as a visible `else`. A chooser answers minutes after the row ran, so the answer is an event - **On A File Chosen** or **On The Ask Cancelled** - never a return value, and a sheet that asks needs both. **Image From File** and **Sound From File** turn such a path into a texture or an audio stream, each with its fallback in the familiar second slot |
| A `.csv` of game data | Two readers, on purpose. **Table From File** parses the file itself in one expression, so it fits anywhere an expression fits; **Table Of File** hands the job to `FileAccess.get_csv_line`, the engine's own reader, so quoting is exactly Godot's and its **First line** slot says whether the first line names the columns or is a row like any other. **Write Table To File** is its inverse through `store_csv_line`, and **For Each Line In File** walks a plain text file as a looping condition |
| Watching a folder for changes | **The Folder Watcher pack**, which calls itself a poll because that is what it is: Godot raises no file-change notification at run time on any platform it ships for, so the pack reads the folder on the interval you name and compares the reading with the one before it. **On A File Appeared / Changed / Removed** are what a difference between two looks means, the first look is the baseline and raises nothing, and **Stop Watching** parks the per-frame tick so a stopped watcher costs nothing at all |
| One `.zip` of content, packed or unpacked | **Pack Folder Into Zip** and **Unpack Zip Into Folder**, over the engine's own `ZIPPacker` / `ZIPReader`, with both loops emitted into your script where they can be read. An archive entry names its own path, so every entry's resolved path is compared against the target folder before a byte is written and one that climbs out of it stops the whole unpack at **On Unpack Refused**. **On Unpack Progress** is where a progress bar moves and **On Unpack Finished** ends a clean run |
| Mod support | A mod format is **data your game interprets**, and every door above is data-shaped so it stays that way: a picture arrives as a texture, text as text, a table as rows and columns. The Doctor warns when a path that came in through one of those doors is handed to `load()`, because a scene or a resource can name a script and loading one runs its author's code - a warning rather than an error, since a game whose mods are code is a decision somebody may mean to make |
| On pause / on resume / the window's X | **Notifications** - **On paused**, **On unpaused**, **On close** and **On object freed**, four pickable triggers that compile into the one `match what:` block Godot's single-callback design asks for. On close is the room a "save first?" prompt lives in; On object freed is the object's very last moment, which is not On destroyed (a node can leave the tree more than once) |
| An action or condition the editor replaced with a newer one | **The forwarding address, carried by the old verb itself.** Nothing is ever renamed or deleted here: a superseded verb keeps its id, its generated line and its place in the picker permanently, and gains the ADDRESS of the newer spelling beside it - the successor's id, what this row's parameters are called over there, and a value for each parameter the old row never had. That is all a map may say, so it can never become a program. Chains resolve to the end and a cycle is a build error. In the sheet it shows as **nothing**: the row is not wrong, so it grows no mark, and selecting it puts one muted line - *newer spelling: Go To State* - on the help strip. The sheet's head grows one counting line, *3 rows have a newer spelling, since 0.14.0*, whose **Migrate…** door opens a receipt showing every row twice (the sentence it reads now beside the sentence it would read, the line it writes now beside the line it would write) before a single byte moves |
| "Do not update, it broke my project last time" | **A pack update is a proposal, and the tri-list comes first.** Attaching a pack records the content hash of every file it landed, so a year later the project can still say which files you edited. **Update…** then shows **Untouched** (they take the new version, and they are listed rather than swept), **Yours** (one answer each: *Keep mine* by default, *Take new*, or *See the diff*), and what the new version retires and adds - derived by diffing the two versions' registry dumps, never read off a release note. A retired verb still compiles exactly as before. The files being replaced go to the backup ring before the first new byte lands, and asking writes nothing at all |
| An event using a plugin you removed | **The quiet amber row, and two honest doors.** The row is not broken: its generated line and its reading were both baked onto it when it was added, so it compiles to the same line and says the same sentence. What it lost is the ability to be edited or explained. It wears the quiet amber state and nothing else - no block, no icon, no inline sentence - and the words live in the selected row's help strip and the Doctor. **See what replaced it** opens the picker at the forwarding address; **Keep as code** writes the line the compiler would have written, as a verbatim block that re-lifts by itself if the vocabulary ever has the verb again |
| Renaming a function, and finding every event that used it | **The list comes before the text field.** A function's head row offers **Rename…**, and the dialog draws every row of this sheet that says the name - the words it says now beside the words it would say - plus every other file that calls it, named, counted, and left exactly as it is under a heading saying why (the callers index answers BY NAME, so it cannot tell a same-spelled function apart, and being plainly approximate beats being quietly wrong). It is one undo step. The other direction is covered too: a name renamed out from under a row makes that row quiet-amber, and a "did you mean" is only offered when the file's own last save shows the old name vanishing and exactly one near name arriving - evidence, never a guess |
| "Is this project OK?" before you hand it to somebody | **`tools/verify_sheets.gd` - four contracts, one read-only command.** Every file parses as valid GDScript; every file round-trips byte for byte; no scope declares one baked local twice (which is what a merge of two branches that minted the same token leaves behind); and the migration report holds no row waiting on a human. It writes nothing anywhere and exits 0 or 1, so it is a pre-commit hook, a branch gate and a CI job without being any of them itself. Hand it paths and it reads exactly those; hand it nothing and it reads the project. A failure prints `res://player.gd:41 [duplicate-local-token] …` - the shape a terminal turns into a link - and ends by naming the door in the editor that fixes it, because the gate deliberately fixes nothing |

---

## 3. Common System Vocabulary

| Construct 3 | Godot EventSheets / generated GDScript |
|---|---|
| Every tick | **Every Frame** trigger (`_process(delta)`) - but if you're checking for an *event* (a collision, a timer ending, a key press), prefer the matching **signal** trigger instead; see [Polling vs reacting](#4-polling-vs-reacting---the-biggest-shift-from-c3) |
| On start of layout | `On Ready` trigger (`_ready()`) - and when you OPEN a .gd file as a sheet it reads back under exactly this name: a `_ready` on the script the scene itself carries is **On start of layout**, a `_ready` on a script sitting on an object in the scene is that object's **On created**, and `_exit_tree` is **On end of layout** or **On destroyed** the same way round |
| Compare variable | One **Compare** dialog with the same three boxes: *Compare* (this sheet's variables, each with its type word and starting value, or any expression you type), *Is* (the operator list - `≤ at most`, `≥ at least`…, plus a **ranges** group for between / not between / within ±), *To* (one value, two for a range, or a value and a give-or-take). The operator decides which condition the row becomes - Compare Variable, Compare Values, Is Between Values, Is Outside Range or Values Are Near - and an **Invert** tick turns the question around. Or just type the condition: `health < 50` (plain GDScript) |
| Compare two strings | The same **Compare** dialog: pick a text variable and the operator list becomes is / is not / begins with / ends with / contains / is one of / matches / is empty, with an **Ignore case** tick that writes `to_lower()` on both sides |
| Set variable / Add to | The **Variables** group of the picker, in the order you reach for them: `Set value`, `Add to`, `Subtract from`, `Set boolean` (true / false already in the list), `Toggle boolean`, then the two questions `Compare variable` and `Is boolean set`. Each verb names the variables it can take. Or `health += 10` in ƒx |
| On collision / overlap | `On Body Entered` / `On Area Entered` (Area2D) - connections are generated |
| On collision with `<object type>` | **On collision with `<Group>`** and **On overlap with `<Group>`** (and their *stopped* / *ended* halves), where the group is the row's own **With** field - a parameter, never a clause. What is emitted is the handler a person would write: its FIRST statement is a visible `is_in_group` early return, and what did arrive rides on into the rows underneath as the trigger's payload. Two groups on one signal become two handlers, each with its own guard. The standing question beside them is **is touching `<Group>`**, and the sheet's own NOT reads it the other way without a second row existing |
| Is on floor / on ceiling, and the moment of landing | The floor family reads the last move (**Is By Wall**, **Is Touching Ceiling**, **Floor Normal**…), and the MOMENT it changed is **On landed** / **On left the ground** with *just landed* / *just left the ground* under them. Not a signal: Godot answers footing as a standing question, so the row carries the memory every platformer writes by hand - the variable, the comparison, and the update after it, in that order and visible in the row's echo. **On first overlap** / **On last overlap ended** are the same idea where the engine already remembers, so they ask the overlap list instead |
| Create object | **Spawn A Copy** - one row for the three lines Godot wants (`instantiate`, `add_child`, place it), with the copy's NAME on the row: that name is a real local variable, so every following row in the same event just says it and expression fields offer it while you type. **Spawn A Copy Safely** is the same spawn deferred, for a collision handler, and **Make A Copy** is the naming statement alone when the copy needs setting up before it joins the tree. There is no spawning system behind any of them - no registry, no manager node, no autoload |
| Create object at a place | The **At** field is an expression, and four placement words fill it: **Place Of** (a marker's own place), **Random Place Along Path** (a Path2D, sampled by distance travelled), **Random Place Inside Shape** (a CollisionShape2D you drew, scattered evenly), **Random Place Off Screen Edge**. Each is one expression, so it also works in a Move To, a camera target or any other field that takes a position |
| Create object at a place in 3D | The same **At** field with a Vector3 in it, and four words to fill it: **Place Of (3D)** (a Marker3D's own place), **Random Place Inside Box** (a CollisionShape3D holding a BoxShape3D, or a CSGBox3D somebody blocked the room out with), **Random Place Inside Sphere** (evenly spread through the ball, pulled back by the CUBE root of the roll, because the volume inside a radius grows as its cube) and **Random Place Around (3D)** (a ring on the ground plane, not a disc). **Spawn A Copy (3D)** and **Spawn A Copy Safely (3D)** are the 2D pair with a Node3D host - the same three statements in the same order. There is deliberately no 3D Random Place Off Screen Edge: off screen in 3D is a camera-frustum question with no honest one-liner, so a wave that must arrive from off camera is spawned at a Marker3D or inside a box the level designer drew |
| Destroy | **Destroy Now** (`queue_free()`), with the timing said on the row: the deletion lands at the END of the frame, so the rows after it still run and the node is still there while they do. `Queue Free` is the same line under its Godot name, and both are unchanged |
| Wait / fade, then destroy | **Destroy After Seconds** (`get_tree().create_timer(2.0).timeout.connect(queue_free)` - never blocks, and safe if something else got there first) and **Fade Out Then Destroy** (a tween down `modulate:a`, an `await`, then the destroy - the event waits, so the row asks again before it destroys). **Is Still Here** is the question on its own, beside the shipped Object Still Exists |
| Object count / pick nth instance | A crowd is a plain Godot **group**, and nothing else: **Spawn A Copy Into The Crowd** joins it (`add_to_group(name, true)` - the persistent flag matters), **How Many Alive** is the group's size as an expression, and the cap lives on the row with its policy in the sentence - **The First Makes Room** or **Unless The Crowd Is Full**. Nothing keeps a list, so nothing can go stale |
| On destroyed | **On Exit Tree** for a node hearing about its own destruction, and **On The Last One Destroyed** for a crowd emptying - the scene tree's own `node_removed` signal, with the question that narrows it to one crowd added underneath as an ordinary, editable condition row |
| On created, for anything that joins a family | **On Node Joins Group** and **On Node Leaves Group** - the scene tree's own `node_added` and `node_removed` signals, with the shipped **Is In Group** condition put in the sheet under the trigger with the group already filled in, so the filter is a row you can see, edit and delete and a plain `if` on disk. They are the future tense of **Connect Group Signal**, which wires only the members a group has right now: hear the join, wire the one node that just arrived, and a group that grows all game long stays wired. The check runs for every node entering or leaving the world, which is nothing at the scale a game spawns things at and the wrong tool inside a particle storm; and a group a script adds AFTER `add_child` is not there yet when the join is announced |
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
| clamp / lerp / wrap / remap as *rows* | **Keep Between**, **Move Toward (each tick)**, **Wrap Around** and **Rescale** - the same four calls said as what they are for (health that cannot pass its maximum, a bar catching up, a heading that passes 360 and comes back at 0, points into a bar's 0 to 1). Each row IS the call in its echo, so `value = clampf(value, 0.0, max_hp)` you wrote by hand opens as the row and saves back as your own bytes |
| Move at angle / Move forward | **Move Forward** goes the way the node is FACING (`position += transform.x * speed * delta`) and **Move (the world's way)** goes the way the screen means whatever the node is turned to (`global_position += direction * speed * delta`). Turning the node turns the first and not the second, which is the whole distinction |
| Rotate toward / Rotate around | **Face** turns toward a place at a top speed and never overshoots; **Turn Around** carries a node round a point at a steady rate keeping its distance; **Swing** turns by an amount over a time about the node's own origin, so where you put that origin is the hinge |
| Angles in degrees | **The unit rides the value.** A plain number in an angle field is degrees and is written through `deg_to_rad`; type `1.2 rad` or `PI/4` and it stays radians and is emitted raw, with nothing wrapped round your `PI`. The row says which it ended up meaning. There is no unit picker to get wrong |

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
| Shadow light behavior | Godot's own `PointLight2D` / `DirectionalLight2D`, addressed as the OBJECT: pick it off the picker's *Lights in this scene* shelf and the row reads **Torch ▸ Set brightness to 1.2**. One word each for brightness, colour, reach, on/off and shadows, in both dimensions - the code echo shows the property that light really has (`energy` vs `light_energy`, `enabled` vs `visible`) |
| Shadow caster behavior | Godot's `LightOccluder2D` (scene setup, not events). The sheet head's **shadows** band says whether any occluder's mask really matches the shadows your lights cast, which is the "I turned shadows on and nothing happened" case, answered before you press play |
| Layer effect: darkness / night tint | A `CanvasModulate` in the scene, on the *Darkness in this scene* shelf: **Level ▸ Set darkness to 81%, tinted #26304d**. The row holds the colour (all Godot stores); the percentage is how it reads. **Fade Darkness** walks it over time |
| Layout lighting / 3D fog and glow | The **World** object (a `WorldEnvironment`): Turn Fog On/Off, Set Fog Thickness, Turn Glow On/Off, Fade The Glow, Set Ambient Light - plus **Make The Environment This Scene's Own**, which is the row to write before any of them, since an environment `.tres` is shared between scenes |
| Set effect parameter (object effect) | **Set Effect Dial**, whose dial list is read out of the `.gdshader` the node's material runs: **Boss ▸ Set `effect.dissolve` to 0.7**, with **Fade Effect Dial** for walking it over time and the dial readable back as an expression or a condition. A name the shader stops declaring grows an amber note with the right name as a one-click fix, where a typed string would just stop working. **Make The Effect This Node's Own** is the row to write first, since a material `.tres` is shared exactly the way an environment is |
| Set layer effect parameter | The **Screen FX** pack's four rows on the one full-screen rectangle. **Fade To** carries `await`, so the rows under it are what happens after the fade has landed - which is a scene transition written as two rows in one event |
| Set effect parameter, everywhere at once | **Set Global Shader Parameter**, Godot's own project-wide uniform (Project Settings ▸ Shader Globals) - one number every shader in the game reads, for wind, wetness or the time of day. The Doctor says when a name was never declared, which is the case where every shader quietly reads zero |
| System: `random()`, `choose()`, `clamp()`, `lerp()`, `distance()`, `angle()` | **Math & Random** expressions (Choose is literally `[…].pick_random()`) |
| Solid / Jump-thru behaviors | Godot collision layers + one-way collision shapes (scene setup, not events) - and the sheet head's **collisions** band reads the result back out of the `.tscn`: *sees Enemies, Walls · seen by Player · monitoring on*. A one-way collider turned over is an advisory in Doctor ▸ Collisions rather than an afternoon of guessing |
| "My collision event never fires" | **Doctor ▸ Collisions**, four checks over the two halves nothing else puts together: a mask that does not cover the layer the bodies it waits for really sit on, an Area whose monitoring switch is off, a collision object with no shape, and a one-way collider facing the wrong way. Two of them offer a door that writes the one property through the editor's own undo with the before and after said back. **Doctor ▸ Collision Layers** is the other half: a row about a layer number this project does not name |
| Physics behavior | RigidBody2D + the existing impulse/velocity ACEs |
| Particles plugin | **GPUParticles2D / CPUParticles2D** group (control emission + one-shot bursts) |
| Tilemap / Tiled Background | **TileMapLayer** group (read / write / erase cells from events) |
| Timeline (keyframe animation) | **AnimationPlayer** + **AnimationTree** vocabulary (play, travel to state, set blend params, is playing) |
| Multiplayer plugin | **Multiplayer** object (Host a game, Join a game, the connection's own events, `@rpc` messages, spawn on every peer, keep a value in step, who may see it) - Godot's high-level multiplayer, one row per call |
| Persist behavior | the **Save System** pack (save / load game state), or Godot's `ConfigFile` / `ResourceSaver` directly |

### Lane 2 - portable behaviors ship as event-sheet packs

**112 are bundled** (93 with a guide of their own, the other 19 companion data assets and loaders
documented inside their partner's guide):
Platformer, 8-Direction, Timer, Flash, State Machine, **Sine, Orbit, Bullet, Move To,
Follow, Car, Tile Movement, Line of Sight (2D & 3D), Rotate, Fade, Bound To, Wrap** (Follow now
emits On Reached Target, Car On Drift Started / Recovered; Bound To is C3's "Bound to layout",
Wrap adds circular arenas), the motion packs (**Spring**, **Tween**, and **Juice** for
camera/game-feel - trauma screenshake, smooth zoom, squash & stretch), the shader effects
(**Hit Flash, Dissolve, Outline, Grayscale, Wave** and the full-screen **Screen FX**), the
**Save System** singleton, a 3D quartet (Sine/Orbit/Bullet/Move To 3D), and faithful ports of
custom C3 addons:

| Construct 3 addon | Godot EventSheets pack |
| --- | --- |
| Drag & Drop | **Drag & Drop** (event-driven: Start Drag / Set Drag Point / Drop, follow-speed lag, direction lock, break-distance auto-drop, measured throw velocity, snap/magnet targets - input-agnostic, so a controller or the Virtual Cursor can drive it) |
| Virtual Cursor | **Virtual Cursor** (axis/mouse-driven cursor with homing, solids, bounce, constraints - drives the Drag & Drop pack for gamepad/touch) |
| (Simple) Health | **Health** (current/max HP, damage-absorption resistance, named **Health Pools** = decaying shields that intercept damage in priority order, death/revive/invulnerability, On Damaged/Death/Healed/Revived triggers) |
| Weapon (custom addon) | **Weapon Kit** (ammo + reserve, fire-rate cooldown, single/auto/burst fire modes, timed + instant reload - Fire triggers; you spawn the bullet) |
| HTN planner (custom addon) | **HTN Agent** (utility-driven Hierarchical Task Network - world-state blackboard + primitive/compound tasks whose methods carry preconditions, subtasks, and a utility score) |
| (Simple) Abilities (custom addon) | **Simple Abilities** (grant abilities by id, cooldowns, stack charges with auto-regen, temporary auto-expiring abilities, custom data + tags for bulk ops) |
| Drawing Canvas | **Drawing Canvas** (draw lines/circles/rings/rects/cones/stamps/textured ribbons and raycast line-of-sight fans onto a live texture - persistent paint or per-frame auto-clear; reusable DrawingPrefabResource formations; the **Decal Painter** pack projects the texture onto 3D surfaces) |
| Flickering torch / pulsing beacon (hand-built with Sine + a lighting behavior) | **Light Flicker** (a flame on a noise field, optionally breathing its reach too) and **Light Pulse** (a smooth wave on a clock). Attach either under any light node, 2D or 3D - each asks its host which property it spells brightness with |
| Day/night cycle (hand-built) | **Day/Night Cycle** (one clock, three Inspector curves, a sun light and either a `WorldEnvironment` or a `CanvasModulate` as targets; triggers On Sunrise / On Sunset / On Midnight / On The Hour, and Set The Time / Run The Clock N Times Faster / Pause / Resume) |
| Effects on an object (the built-in effect list) | **Hit Flash**, **Dissolve**, **Outline**, **Grayscale** and **Wave** - five shader packs with one-word verbs (Flash white for 0.15 s, Dissolve over 0.8 s, Outline yellow at 2 px, Grayscale to 1 over 0.25 s, Wave at 0.03 over 0.4 s). Adding one copies its `.gdshader` and a `.tres` into `res://effects/` and dresses the node in it through the editor's own undo, so the look is a file you own from the first add. Each takes its own copy of the material before turning a dial, unless you turn `own_material` off because sharing IS the effect |
| Effects on a layer (the full-screen effect list) | **Screen FX** - the pack ships the whole `CanvasLayer` scene, and adding it drops that in rather than a bare node |

Attach as a child node; properties live in the Inspector; their ACEs appear in the picker
automatically.

**Families** → declare a sheet as a **Family** (Sheet Type → Family) and its events iterate over a
whole family of nodes (family-scoped) - see the **Family Arena** showcase. Underneath it's Godot's own
machinery: put nodes in a group (`add_to_group`), pick them with the group pick filter, and attach
shared behavior packs for shared ACEs - so you can also drop to that lower level directly.

### Lane 3 - use the Godot feature directly

3D plugins (Godot 3D), Binary Data (`PackedByteArray`),
i18n (Godot translations).

---

## 8. Habits That Transfer Directly

- **The strip across the top is the shape you already know.** At rest it is one **☰ Menu**, then
  Save, Undo and Redo as icons, then the play button, the Quick add field, and a chevron. Sheet,
  Edit, View and Tools are inside the Menu as cascading submenus - the same menus with the same
  entries, one hop in - and the Manual and What's new sit at its foot.

  ![The editor strip at rest - Menu, Save, Undo, Redo, the play button, Quick add and the chevron - with the Menu open on its Sheet, Edit, View and Tools submenus](images/resting-toolbar-menu.png)

  Press the chevron (or tick **View ▸ Full toolbar**) and every button the strip has comes back, in
  the order it always had them: Run Scene, the preview buttons, Add Event / Condition / Action /
  Code, the Add menu, the GDScript toggle and the theme picker. The choice is remembered for the
  project, and nothing was taken away - a button you cannot see still answers to its key.

  ![The same strip expanded, every button on show](images/resting-toolbar-expanded.png)
- **Adding happens in the sheet, not on the strip.** The canvas carries the two links you already
  reach for: a muted **Add event** in its top-left corner and a **+ Add…** in its top-right, on
  every sheet, pinned to the corners so scrolling never takes them away. "Add event" is the E key;
  "+ Add…" is the same menu a right-click on empty space opens. The trailing "+ Add event…" rows,
  the Ghost Row, double-click on empty space and the Quick add field all still add too.

  ![A sheet with the Add event link in its top-left corner and the + Add… link in its top-right](images/sheet-corner-links.png)

  The whole Add menu lives inside the **☰ Menu** beside Sheet, Edit, View and Tools, and it teaches
  the keys: Event (E), Condition (C), Action (A), Group (G), Comment (Q), Global Variable (V) and
  Function (F) each print their key beside them, read from your own bindings - rebind one in
  *Tools ▸ Keyboard Shortcuts* and the menu says the new key.

  ![The Menu open on Add, with E, C, A, G, Q, V and F printed beside their items](images/add-cascade-keys.png)
- **One play button, and it holds every way to run.** The face runs the way you chose; the arrow
  beside it opens all six. The four the sheet owns come first - Run Scene (the scene this sheet's
  script is on), Debug layout, Run with profiler, Play as host + client - and under *Godot's own*
  sit Preview layout and Preview project, which are Godot's F6 and F5 under the names you already
  use. *Main button* at the foot says which one the face does, ticked, and the choice is remembered
  for the project.

  ![The play button's dropdown open on all six ways to play, with Godot's own F6 and F5 under their own heading and Main button at the foot](images/play-button-dropdown.png)

  While a game is running the face reads **Stop** (Preview project reads *Restart*), so the button
  never claims it will do something it will not. Every run is still a plain button on the expanded
  strip, relabelled the same way.

  ![The same play button while a game runs, its face reading Stop](images/play-button-stop.png)
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
- **You always know which group you are in.** On long sheets, scrolling inside a group pins
  **that group's own head** under the column header - its title, description, what it holds and
  its switch - so it can be folded, switched off or edited without scrolling back up. The parent
  chain shortens to the last two names ("Gameplay ▸ Combat") and the whole chain is the hover.
  Clicking one of those parent names scrolls to that group's own head, so getting back out is the
  same gesture as reading where you are.

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
  | `G` | Group the selected rows (or add an empty group when nothing is selected) |
  | `Ctrl+Shift+G` | Open all / close all groups |
  | `V` | Add variable (a local of the group when a group head is selected) |
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
- **AJAX.** Nothing here speaks HTTP yet - the report says so and the request stays a script block.
- **The multiplayer plugin.** Multiplayer here is Godot's own, not a row-for-row twin, and the report
  says exactly that. The rebuilt version goes on the sheet's own **Multiplayer** object - hosting,
  joining, the connection's events, messages and who runs what.

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

XML routes to JSON, and the multiplayer plugin routes to the sheet's own **Multiplayer** object - Godot's high-level multiplayer, rebuilt row by row rather than translated - so the migration table names a destination for every plugin and nothing dead-ends.

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
