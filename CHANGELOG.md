# Changelog

The work not yet released is listed first, under `[Unreleased]`. Each released version keeps its full notes in its own file under `docs/changelog/`, and the index at the bottom of this file lists them newest first. A release moves its section out of `[Unreleased]` into `docs/changelog/vX.Y.Z.md` when it is cut.

## [Unreleased]

### Changed: a `#` note among a function's statements is the note of the action below it

- A `#` line written directly above a statement inside a function is now that action's quiet note (it reads after the action, muted) instead of a separate comment row in the action lane. Moving the action moves its note, copying it copies it, and the file saves back to the same lines. A TODO or FIXME note, a note kept apart from the statement by an empty line, a commented-out statement and a `##` documentation line stay comment rows.

### Changed: an untyped variable reads `any`

- `var score` with no type reads `any score` on every row look (the Inspector-style row used to read `Variant score`), with the quiet note "no starting value" where its value would be. A variable that spells `: Variant` keeps the word it wrote.

### Fixed: the Godot-call draw rows start with a capital

- Draw Line, Draw Rectangle, Draw Circle, Draw Arc, Draw Texture and the rest of the Godot-call draw rows read "draw line from a to b" in lower case beside rows that start with a capital. They now read "Draw line from a to b in red", "Set draw transform to ..." and "Redraw" like every other action. Reading only: ids, templates and the code they write are unchanged.

### Changed: the two sets of Draw rows have names that say which is which

- Searching "draw" under an On Draw event listed two Draw Line, two Draw Circle, two Draw Arc and so on: Godot's own `draw_*` calls (picker group "Drawing: Godot calls") and the older rows that paint onto ANOTHER node's canvas. The older rows now read Draw Line On Node, Draw Circle On Node, Draw Rect On Node, Draw Arc On Node, Draw Polygon On Node, Draw Polyline On Node, Draw Text On Node and Draw Texture On Node. Their ids and the code they write are unchanged.

### Fixed: a restored session reads every tab as events, not just the last

- Reopening the editor with several scripts open used to bring back only the last tab as events; the others stayed as raw `function` blocks, because opening each tab dropped the background read of the one before it. The restore now lets each script finish reading before it opens the next, so a restored tab reads exactly like a freshly opened one.

### Fixed: the parameters window no longer writes a call with a gap in the middle

- Setting a later optional argument of a Godot-call row (`draw_line`'s Antialiased, `draw_rect`'s Width) while an earlier optional one was blank used to write `draw_rect(r, c, , 2.0)`. The window now fills every blank optional argument before the last given one with its own default (`draw_rect(r, c, true, 2.0)`), so the call is always valid GDScript; a call with nothing given after a blank still writes the short call, and a lifted short call re-emits byte for byte.

### Changed: a statement written over several lines opens as one row

- A call, an assignment or a `\`-continued line that you wrote over several lines (a `draw_rect(` with its `)` on a line of its own, `bullet.position = Vector2(` with one argument per line) is now one action instead of a block of code. The row shows the statement on one line; double-click it and the parameters window shows the value as you wrote it, line breaks and indents included, and keeps whatever layout you give it. Saving writes the same lines back.

### Changed: constants, plain variables and annotated declarations open as variable rows

- `const SPEED = 160`, `const TAN30DEG = tan(deg_to_rad(30))` and `const BULLET_SCENE = preload("res://player/bullet.tscn")` are variable rows marked as constants, reading the type Godot infers for them (`float`, `PackedScene`) while the file keeps writing none.
- `var score` with no type and no value is a variable row that reads `any` and has no starting value. A type written with a space before its colon (`var tween : Tween`), a hinted export that infers its type (`@export_range(1, 1000) var row_size := 100`) and a `@warning_ignore(...)` line above a variable or a signal stay with their declaration and are written back as they were.

### Changed: the `#` notes of a script open as comment rows

- A note above a function, over a declaration or between two blocks is a comment row written back exactly where it sits, and the notes among a function's statements are comment rows between its actions. `##` documentation lines stay with the function they describe, and a `#region` fence stays a fence.

### Changed: a note at the end of a line stays with its line

- `hide() # why` is the action Hide with the comment "why", `const MOTION_SPEED = 160 # Pixels/second.` shows its note in the variable row's note column, and `if alive: # player only` is the condition Is alive with that note. The spacing before the `#` is kept exactly as you wrote it, and editing the row's values keeps its note.

### Changed: `signal name()` opens as a signal row

- A signal declared with empty brackets is a signal row that remembers the brackets and writes them back; a signal made in the sheet with no values is still written without them.

### Added: Godot's own drawing calls as actions under On Draw

- A new Drawing: Godot calls group holds Godot's `draw_*` calls by their plain names: Draw Line, Draw Rectangle, Draw Rectangle Outline, Draw Circle, Draw Circle Outline, Draw Arc, Draw Polyline, Draw Polygon, Draw Text, Draw Texture, Draw Texture Rect, Draw Texture Region and Set Draw Transform, plus Redraw for `queue_redraw()`. Every field carries Godot's own argument name, and the ones Godot lets you leave off can be left blank, so a hand-written `draw_line(a, b, Color.RED)` opens as the same row and saves back to the same bytes.
- The drawing rows are only offered under an On Draw event, because Godot refuses `draw_*` calls anywhere else. Redraw works anywhere: it asks the node to paint itself again, which runs On Draw.
- Rows that already existed for drawing on another node's canvas (Draw Line, Draw Circle, Draw Rect and the rest) are unchanged.
- A sentence can now carry a piece that shows only while its field has a value, so Draw Line reads "Draw line from a to b in red" and gains ", width 2" once a width is set.

### Fixed: the kind check no longer builds a broken test script from a match arm

- A `match` arm, an `elif` or an `else` that stayed in a code cell was handed to the kind check as if it were a statement of its own, which Godot cannot read, so a parse error was printed every time such a sheet opened and the lines judged after it in the same pass could go unchecked. Those cells are now left out of the check.
- A row whose code has an optional trailing argument (a width you may leave blank) no longer makes the same check print a parse error while you edit one of its fields.

### Changed: the two tick triggers read for what they are

- A `_process` event now reads **Every tick** and a `_physics_process` event reads **Every physics tick**. They used to read "Every tick (draw)" and "Every tick (physics)", and `_process` has nothing to do with drawing. Only the words changed: the trigger ids, the templates and the code a sheet compiles to are exactly what they were. The same words are used where a hand-written `set_process(false)` / `set_physics_process(false)` reads ("Set Every tick deactivated", "Set Every physics tick deactivated"), in the muted note on a conditionless physics tick, and in the Doctor's handler list.

### Fixed: `delta` reads as `delta`

- A row that says `Vector2(speed * delta, 0)` in the code used to read `Vector2(speed * dt, 0)` on the sheet. Rows now read your identifiers exactly as you wrote them, so `delta` stays `delta` everywhere (conditions, actions, expressions, a pack's rows). A bare `get_process_delta_time()` reads `delta` too, and a call on another object (`host.get_process_delta_time()`) keeps its own spelling.

### Changed: the README's player example is real Godot, and its four pictures show it

- The example in "What it compiles to" now takes its hits from an `Area2D` child named `Hitbox` whose `body_entered` signal is wired in the scene, because a `CharacterBody2D` has no `body_entered` signal of its own and the old `_on_body_entered` would never have run. The sheet reads that handler as a real **On collision with** trigger on the `Hitbox`, and the hit is `health -= 10`. The example and its `enemy` scene live in `demo/readme_example/`, the scene opens with "No problems", and the README's bullets use the words the editor shows.
- The workspace and Generated GDScript pictures (Default and Light themes) were retaken on that example at a comfortable editor zoom, so every word reads at the README's width.
- The mistake-check tests that pin the nearest group name to a typo now judge groups against their own fixtures only, so a group elsewhere in the project (the example's `enemy`) cannot change which name they offer.

## Releases

- **v0.20.0** (2026-11-07) - Feel Native
  This release makes the editor sit inside Godot like one of its own docks, and makes it sturdier after a heavy overhaul of how it looks and behaves. Nearly every window, row and menu was reworked to say plainly what it does, to work in Godot's light and dark themes, and to stay quick on big sheets. If your daily driver is Construct 3 or Godot, the picker, the sheet and the fields now answer to names you already know. [Full notes](https://github.com/SalmanShhh/Godot-EventSheet-Visual-Scripting/blob/main/docs/changelog/v0.20.0.md)

  **A look that belongs in Godot**

  - A new default look, Editor Native, that reads like Godot's own docks: variables listed the way the Inspector lists a property, blue condition lanes and green action lanes, and each event drawn as one panel with its nesting as lines in the margin.
  - Words, names and values sit in aligned columns, the parameter band hangs under a function's line, and sub-events pack tight under their parent.
  - It follows Godot's Light and Default editor themes from the moment the editor starts, keeps its toolbar words readable on any theme base, and switching the editor theme while a sheet is open re-colours the sheet with no restart.
  - A sheet opens on one thin head bar, the side panel rests as a rail, and every line leads with its icon instead of a word in front of it.

  **Familiar names, familiar flow**

  - Type a name from another engine or from Construct 3 and the picker finds the verb that already ships; expression fields read `Mathf.Lerp` and `Random.Range`.
  - The Welcome window asks how you usually make games and offers a first game you already know as a showcase with a ten-step tour.
  - Picking is offered in Godot's shape: write a condition on another object's sheet and the sheet offers the For each that goes with it.
  - Click a script in the FileSystem and its sheet opens, and the Manual opens on the page it names from nearly any row, window or menu.

  **Variables, functions and your own objects**

  - A variable's Inspector options each open as the variable they belong to, export groups read as boxes, and the variable window is four cards where every look is a described choice.
  - One Save choice per variable (Never, Auto, Load only, Save only, Manual), and values players already saved keep loading through a rename or an update.
  - Functions are drawn as events on every sheet and edited in Godot's own Inspector, with every choice described and a name that would break the script refused before it is written.
  - Shape a field in the Inspector Designer: groups as tabs, two fields side by side, a dropdown filled by a function, picking a table row by name, and search, sort and pages for big tables.
  - New behaviour and New global are forms you can reopen, Add behaviour is a shelf of tiles with your own first, New Data Table is filled in like a spreadsheet, and a script class is made like inserting an object.
  - An object's states work project-wide, with one state row that carries a default and a description for each state.
  - A project holds only the behaviours it asked for: the packs ship in a library folder Godot never imports, and adding one copies a folder.

  **Your own code opens as rows**

  - Functions written inside a call, classes inside a script, values over several lines and statements continued with `\` open as rows and save back byte-exact.
  - The plugin's own scripts open as rows too, with no block of code on screen.
  - Hand-written `.gd` scripts open as tidy, readable rows, and every way a `.gd` save used to drop something (disabled events, groups, regions, class descriptions) is closed.
  - Position rows say which space they mean: Set X / Y / Z read relative to the parent, and world twins sit beside them for setting, reading, spawning, wrapping, bounding and gliding.
  - New rows: Tell Children, First Parent Of Type, Next / Previous Sibling, Reset Variable(s), Pick First / Last Where, Has Been True For, and pause requests that keep the game paused until everyone who asked lets go.
  - New packs: Flock and Flock 3D (birds, fish and swarms that steer by their neighbours), and a Platformer Pathfinding that learns every way a character gets around.

  **Catching mistakes as you type**

  - Type checking in every field: Godot's own analyzer answers in a plain sentence plus its own words, underlines the exact span, and blocks OK on an error.
  - Autocomplete follows the code the way Godot's script editor does: dot completion through chains, argument hints, names inside quotes, and descriptions from the class reference.
  - Colour values show a square of the colour and read the way you typed them: click the square for Godot's own ColorPicker with no window in between, right-click it to Copy As hex, RGB, HSV or code, and pick how every colour reads with Read Colours As (your code never changes).
  - Nine mistakes Godot only reports when the game runs are caught on the row with a fix beside each, and a broken script marks its row with Godot's own words on save.
  - A run-time error in a `.gd` sheet or a hand-written script links to its row, in a game started from the editor, with nothing added to the game.

  **Studios and windows**

  - The Save studio gains file, slots, look-inside and player-settings tabs, and the Translation Studio reads as four steps, stays fast at a million lines, and never rewrites a catalog you wrote by hand.
  - Every dialog says what it will do before you press OK, opens at the size of what it holds, and reads in a light theme.
  - Renaming a variable shows everything it touches first, and project-wide find, replace and rename now see `.gd` sheets.
  - The MCP server edits `.gd` sheets, works through the open editor, and edits single rows.

  **Faster, and cleaner when it leaves**

  - The editor starts in about 11 seconds instead of 30, and the picker lists every pack verb (it showed 142 of 4,477).
  - Dropping a drag on an 803-row sheet takes about 0.75 s (it was 2.8 s), and a fold click on a large sheet is under 50 ms (it was about 0.5 s), and hover and drag repaint only the row they touch.
  - Disabling the plugin frees its whole workspace instead of leaving it in memory.

- **v0.18.0** (2026-09-06) - Refactor Anything, Render Anything & Feel Everything
  The refactor contract (moved verbs keep a forwarding address, Migrate proves every rewrite), states and scenes as rows, the render vocabulary and shape nodes, the Feedback Player, the gameplay systems, the resting toolbar and the Manual. [Full notes](https://github.com/SalmanShhh/Godot-EventSheet-Visual-Scripting/blob/main/docs/changelog/v0.18.0.md)
- **v0.17.0** (2026-08-17) - Adopt Anything, Read Anything & Ask Why
  Real `.gd` files open as rows byte-exact, your own classes become vocabulary, the pattern and developer-experience waves, and every guide readable inside the editor. [Full notes](https://github.com/SalmanShhh/Godot-EventSheet-Visual-Scripting/blob/main/docs/changelog/v0.17.0.md)
- **v0.16.0** (2026-07-28)
  Nine editor languages, the Custom Resource wizard, `publish_pack`, renamed verbs that keep working, parameters shaped by addon authors, and a full docs freshness sweep. [Full notes](https://github.com/SalmanShhh/Godot-EventSheet-Visual-Scripting/blob/main/docs/changelog/v0.16.0.md)
- **v0.15.0** (2026-07-13) - Save Anything, Control Anything & BBcode it
  The save-state seam on 18 packs, six save formats, the Save Studio and the ACE Studio, BBCode comments, and the player-or-AI input seam. [Full notes](https://github.com/SalmanShhh/Godot-EventSheet-Visual-Scripting/blob/main/docs/changelog/v0.15.0.md)
- **v0.14.0** (2026-07-12) - The Pathfinding & Game-Feel Update
  Platformer Pathfinding and Nav Agent 3D, the universal AI drive seam, FPS movement tech, Juice cameras, the Input Map picker and a much faster boot. [Full notes](https://github.com/SalmanShhh/Godot-EventSheet-Visual-Scripting/blob/main/docs/changelog/v0.14.0.md)
- **v0.13.0** (2026-07-08) - The Genre Toolkits Update
  The incremental / idle game suite, ECS-lite Systems, Loot Table and SkinVault, an object pool, Advanced Random behind one seed, and auto-registering pack builders. [Full notes](https://github.com/SalmanShhh/Godot-EventSheet-Visual-Scripting/blob/main/docs/changelog/v0.13.0.md)
- **v0.12.0** (2026-07-06) - The Inspector Designer Update
  The Inspector Designer with its drawers and custom resources, HUD Kit, Scene Flow and Dialogue Kit, sheets created from the FileSystem, and a lazily built editor. [Full notes](https://github.com/SalmanShhh/Godot-EventSheet-Visual-Scripting/blob/main/docs/changelog/v0.12.0.md)
- **v0.11.0** (2026-07-04) - The Structure & Vocabulary Update
  Regions, the Look Gallery, localisation vocabulary, Extract to Function, featured verbs, Teach a Verb and the public `EventSheets` API. [Full notes](https://github.com/SalmanShhh/Godot-EventSheet-Visual-Scripting/blob/main/docs/changelog/v0.11.0.md)
- **v0.10.0** (2026-07-04) - The In-Sheet Authoring Update
  In-sheet authoring: the ACE Studio, per-function shell-lift, Ghost Row, error-to-row, the complete Custom Block API, and a much faster editor open. [Full notes](https://github.com/SalmanShhh/Godot-EventSheet-Visual-Scripting/blob/main/docs/changelog/v0.10.0.md)
- **v0.9.5** (2026-06-29) - Code-Free Authoring & First-Class Variables
  Code-free authoring and first-class variables: `.gd` as the default sheet format, `@export` variables with Inspector drawers, drop a scene node onto a parameter, New Behaviour Addon. [Full notes](https://github.com/SalmanShhh/Godot-EventSheet-Visual-Scripting/blob/main/docs/changelog/v0.9.5.md)
- **v0.9.0** (2026-06-22) - Performance & Game Feel
  Frame-spreading performance, Juice game feel, and first-class UI, raycast, particle, tilemap and shader vocabulary, with a plain-language picker. [Full notes](https://github.com/SalmanShhh/Godot-EventSheet-Visual-Scripting/blob/main/docs/changelog/v0.9.0.md)
- **v0.8.0** (2026-06-20) - "The Team & Scale Update"
  Team and scale: a merge driver, Find References, an includes manager, HTN Agent, the Theme Editor's Quick Style, Godot 4.7 and byte-stable regeneration. [Full notes](https://github.com/SalmanShhh/Godot-EventSheet-Visual-Scripting/blob/main/docs/changelog/v0.8.0.md)
- **v0.7.0** (2026-06-12) - “The Native Workflow Update”
  Godot-native workflow: entry points, debug, docs and shortcuts like Godot, a first-run hook, and wider GDScript coverage for branching lifts. [Full notes](https://github.com/SalmanShhh/Godot-EventSheet-Visual-Scripting/blob/main/docs/changelog/v0.7.0.md)
- **v0.6.2** (2026-06-12)
  Project usability: compile-on-save, reviewable sheet diffs, the Project Doctor, the project vocabulary doc, sheet backups and one pack-builder file per pack. [Full notes](https://github.com/SalmanShhh/Godot-EventSheet-Visual-Scripting/blob/main/docs/changelog/v0.6.2.md)
- **v0.6.1** (2026-06-12)
  Hygiene after 0.6.0: a repo review sweep and the dock split into four extracted subsystems. [Full notes](https://github.com/SalmanShhh/Godot-EventSheet-Visual-Scripting/blob/main/docs/changelog/v0.6.1.md)
- **v0.6.0** (2026-06-12)
  Editable Live Values (the debugger, both directions), Save System v2, runtime groups, project-wide find, nested live values, a fuzzy picker and keyboard flow. [Full notes](https://github.com/SalmanShhh/Godot-EventSheet-Visual-Scripting/blob/main/docs/changelog/v0.6.0.md)
- **v0.5.0** (2026-06-12)
  Keyboard, Mouse, Gamepad and Touch vocabulary, the Audio module, a searchable scene-node picker, per-ACE comments and starter templates. [Full notes](https://github.com/SalmanShhh/Godot-EventSheet-Visual-Scripting/blob/main/docs/changelog/v0.5.0.md)
- **v0.4.0** (2026-06-10)
  Starter 3D vocabulary, find that reaches folded groups, five silent-bug fixes and CONTRIBUTING.md. [Full notes](https://github.com/SalmanShhh/Godot-EventSheet-Visual-Scripting/blob/main/docs/changelog/v0.4.0.md)
- **v0.3.0** (2026-06-10)
  Multi-view: split view, linked panes and detached windows, plus experimental tool sheets that build editor tooling from events. [Full notes](https://github.com/SalmanShhh/Godot-EventSheet-Visual-Scripting/blob/main/docs/changelog/v0.3.0.md)
- **v0.2.0** (2026-06-10)
  Native-node ACE providers, fourteen behavior packs, combo and color parameters, iconic theme presets and Export Addon Pack. [Full notes](https://github.com/SalmanShhh/Godot-EventSheet-Visual-Scripting/blob/main/docs/changelog/v0.2.0.md)
- **v0.1.0** (2026-05-15)
  The first public cut: the editor, the compiler and lossless pairing. [Full notes](https://github.com/SalmanShhh/Godot-EventSheet-Visual-Scripting/blob/main/docs/changelog/v0.1.0.md)
