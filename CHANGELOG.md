# Changelog

The work not yet released is listed first, under `[Unreleased]`. Each released version keeps its full notes in its own file under `docs/changelog/`, and the index at the bottom of this file lists them newest first. A release moves its section out of `[Unreleased]` into `docs/changelog/vX.Y.Z.md` when it is cut.

## [Unreleased]

### Added: a spawn row's Scene field offers the scenes the sheet already holds, the Variable window has a Scene door, and the Doctor notes an empty scene slot

The Instantiate rows take their scene as a value, so a sheet that declares `@export var enemy_scene: PackedScene` (or a typed constant that preloads one) can spawn it by name and the row writes `enemy_scene.instantiate()`, the line a Godot user would write. The Scene field now lists the sheet's own scene variables and constants first, above everything else it offers, so the name is one pick away. Nothing else changed in how a spawn is written: no new row, `load()` stays what a new row starts with, and the sheet never writes a `preload` on its own.

The Variable window has a Scene entry in its type list ("A scene", also found by Search types). Picking it types the variable as a PackedScene and puts it in the Inspector in the same step, so a new scene slot is `@export var enemy_scene: PackedScene` after one pick and a name.

The Doctor gets a quiet note for an exported scene slot that is still empty where it is spawned from: when a scene runs a script that declares such a slot, the script runs `.instantiate()` on it, and the scene never fills it, the note names the slot and the scene in two short sentences and says to pick a scene in the Inspector. It reads text only, never names a script the plugin ships, and is a note, not a warning.

### Fixed: a variable's look mark is back when a pack is opened

Since a member's annotation words moved above its description, a variable of a built pack that wears an Inspector look (the unit dropdown on a shape's thickness, the toggle row on its dash style, the progress bar) opened without its look mark, and the line above it opened as a separate comment row: 18 shape scripts opened with one to six more rows than before. The look is read through the words again, so those variables open as one row with their mark, the file still writes back byte for byte, and the description stays directly above the member, which is where Godot reads it. A file with the words below the description reads the same rows, and a block of comments that begins with an Inspector comment line shows its description before its words, as the other packs do.

### Added: Sheet > Tidy This Script writes an older script the way the editor writes it today, after showing every line

A script keeps the spelling it was written in, and opening and saving it untouched still changes nothing. Tidy This Script is the one door that does, and it only runs when you choose it. It plans the change on a copy of the sheet and opens a window that lists every line as `before => after` with a count, and nothing is written until Apply. Apply is one undo step and then the ordinary save, so the old file goes to the sheet backups first. A second Tidy says `Nothing to tidy.`

What it turns on is only what the rows already offer: a guard that wraps a plain number in a floor (`if t >= maxf(2.0, 0.001):` becomes `if t >= 2.0:`), the short loop-budget, filter and `$Name` connect lines for the rows that can carry them, a member that leaves out the icon and category its class already says, and, for a file with two-hash annotation lines, the words as one-hash comments above the description. A change is offered only when the result opens again as the same sheet, saves back byte for byte and parses; a line that cannot be read back is left as it is and the window says how many. The command line does the same for files nobody has open: `tools/tidy_scripts.gd -- <file or folder> [--write]`.

### Added: the Doctor notes a script that still writes older spellings

A note, never a warning, one per script: it counts the lines that are in an older spelling and points at Sheet > Tidy This Script. It reads text only, so it opens no file as a sheet, and it never names a script the plugin ships.

### Changed: the hand-written provider scripts and the new-script template write annotation words with one hash

The hand-written scripts under `eventsheet_addons/` (the bus mix, the haptics and sequencer scripts, the post-processing effects, the demo health and note-block add-ons and the loading screen, 15 files and the builders' own copies of 8 of them), and the provider template in `script_templates/`, write their `@ace_` words as one-hash comments, so Godot's Help page for them shows the description and nothing else. They were moved by Tidy's own engine, each proven to open and save back byte for byte and to publish the same verbs. A project that already holds a copy of one of them keeps it unchanged and working.

### Changed: a script with one-hash annotation words reads description first in the sheet

In a file whose `@ace_` words are one-hash comments, the words sit above the description so Godot keeps the description. A comment block that is only those words and then the description used to show the words first; it now shows the description and then the words, the way the same block read when the words were two-hash lines. A code block of such a file shows its annotation lines with the file's one hash instead of two. Only the text on screen changes: the file's bytes, the block's stored text and each line's place in it are untouched, and a file that keeps two hashes reads as before.

### Added: Set Shape Colour From Palette

A new row on every Vector Shape, 2D and 3D, sets the shape's colour to one role of a colour palette: `Set shape colour to "Danger" from palette ("Deuteranopia")` reads the Danger entry of the Deuteranopia colour set, so one row draws the right colour for every kind of colour vision. An empty set name reads the palette's first set, and role and set names match without regard to capitals. A palette, set or role that is not there leaves the colour as it was and says so once in the Output panel, naming the shape. The row reads the palette resource by the names its fields carry (`role_names`, `set_names`, `set_colors`), so the Vector Shapes pack still works without the Color Palette pack. The Game Settings guide had promised a row that asks a palette for its Danger colour; this is it. The row's id is `set_shape_colour_from_palette` and its call is `$VectorShape2D.set_shape_colour_from_palette(palette, colour_set, role)` (`$VectorShape3D` on a 3D shape).

### Changed: two tests stop writing into the shared user folder, and the Scene dock's preview entries wear Play and Stop

The lift checks that verify a lifted sheet ask the compiler for its text and no longer compile into a file in `user://`, and the saved-language test runs against a settings file in its own per-process folder, so no test run touches another's files. The two Scene dock entries Preview its behaviours and Stop previews wear the editor's own Play and Stop icons, like the entries around them.

### Added: a Drawing Prefab draws arcs, pies, rounded rectangles and regular polygons

The shape list of a Drawing Prefab has four more kinds: Arc, Pie, Rounded rectangle and Polygon (the stored words are `arc`, `pie`, `rounded_rect` and `regular_polygon`, and they stay). Each has its own icon on the card line, in the step's colour, a size in its own words ("radius 16, 270°", "32 x 20, corners 6", "6 sides, radius 16"), and named fields with their units on the open card: an arc and a pie take a radius and the angles they start and end at (the sweep runs from the start to the end, and an end below the start sweeps back), a rounded rectangle takes a width, a height and a corner size and is drawn right and down from the offset like a Rectangle, and a polygon takes a radius, a number of sides (3 to 32) and the angle of its first corner. An arc also has a Thickness, and the "Follows scale" tick a Line has under the same quiet "Line look" fold. A shape added by typing in "Add shape" draws something at once, a size that draws nothing (a radius of 0, a start equal to its end, no width) is said in a quiet amber line, and a corner larger than half the shorter side, or a polygon with fewer than 3 or more than 32 sides, is drawn at the nearest size that works and says so. Clicking a new shape in the picture selects its card, as for the other six.

The stamp node, Draw Prefab and the Inspector picture draw the four from the same rules (`DrawingPrefabResource.shape_outline`): the stamp node and Draw Prefab produced the same pixels for all four in every scale and spin that was tried. Nothing saved changes: a prefab that holds none of the four saves byte for byte as before, the eight stored keys mean what they did, and an arc's thickness is one new optional `thickness` key (absent means 2 px, so no file needs it).

An older copy of the Drawing Canvas, Drawing Prefab Stamp and Drawing Prefab Resource packs in a project does not know the new kinds and draws nothing for them, without an error. Add the three packs again from the behaviour library to draw the new shapes in a game.

### Changed: the plugin's annotation comments are written with one hash, so Godot's Help and tooltips show only what you wrote for people

Godot shows every `##` line as documentation, so a pack's Help page and its Inspector tooltips used to read `@ace_category("Sine") @ace_expose_all(node)` beside the sentence the author wrote. New annotation lines are `# @ace_name("Wave")` (one hash, an ordinary comment Godot keeps out of its documentation); the `##` lines that remain are the descriptions written for people. Every reader accepts both spellings in any file: the picker's reader, the importer, the annotation editor, the Doctor, the pack catalog and library, the vocabulary list, the test-sheet and shared-sheet markers. A file keeps the spelling it has: opening and saving a script untouched writes the same bytes, editing one verb does not respell the file's other lines, a verb added to a two-hash file is written with two hashes, and a file with no annotation yet gets one-hash lines from its first. A file that mixes both is read as it stands and written back unchanged.

A one-hash line counts as an annotation only when it cannot be anything else: a known word alone on the line, or followed by a bracket that closes at the end of the line. A comment such as `# @ace_hidden is what the old version used` stays a comment, and the older space form (`## @ace_category Score`) is read with two hashes only. Annotation words are unchanged; only the comment marker moved. The guides show the new spelling.

All behaviour packs and the library copies are regenerated with one hash, and the showcases that carry annotation lines follow. A pack already installed in a project is not touched and keeps working.

### Changed: a pack leaves out the member icon and category lines that only repeat the class's own

A pack that names its icon and category once on the class used to write the same two lines again above every verb (3,829 lines across 114 shipped pack files). The reader gives a verb the class's icon and category when it has none of its own, so a sheet built from rows now writes them only where they differ. A pack opened from a file keeps the lines it has, and a pack written without them opens with its verbs as function rows, exactly as before.

### Fixed: confirming the parameters of an Every X To Y Seconds row no longer prints a parse error in the Output

Looking at a field of a row that keeps a clock or a flag (Every X To Y Seconds and the 28 other stateful conditions) made Godot print `Parse Error: Function "__everyr_0()" not found in base self.` into the Output panel, sometimes a dozen times, because the stand-in script the kind-of-value check compiles had the verb's call but not the helper function the row declares beside it. The stand-in now carries the verb's own members, so the line is quiet; a wrong value in such a field is still refused in the same words.

### Fixed: a shape set to "fixed on screen" keeps its weight when the camera zooms

A 4 px line set to "fixed on screen" was drawn 8 px wide under a Camera2D at zoom 2, and 2 px wide at zoom 0.5, because the width followed the shape's own scale and ignored the camera. It now follows the scale the shape is actually shown at, so the line is 4 px at every zoom, in a running game and in the editor's 2D view when you zoom it. A fixed shape checks that scale once a frame to redraw when it changes; a shape set to "with the node" stays parked as before. Shapes in a project made before this fix pick it up when the Vector Shapes pack is added again from the library.

### Fixed: moving a node by hand while its behaviour previews keeps the move

Dragging a node in the 2D view while a behaviour was previewing it was lost: the preview wrote over the drag on the next frame, and Stop put the node back where it stood before Preview, while the undo history said it had moved. Now the preview stops the moment you move the node (a drag, a value typed into the Inspector, or an undo) and the node stays where you put it, including after Stop and after a save. When two behaviours preview the same node, a move by hand, or a plain Stop on one of them, stops both. While a preview plays the editor redraws every frame, as it does while a game runs, so a quiet moment in a preview never hides a move; it goes back to its usual idle mode when the last preview stops. Ctrl+Z after such a move goes back to where the node was when you grabbed it, which is a spot the preview had carried it to. This changes the Preview block that 18 behaviour packs carry, so a project made earlier keeps the old behaviour until the pack is added again from the library; nothing in the scene changes either way.

### Changed: the Scene dock's Preview and Stop menu words are translated

Right-clicking a node in the Scene dock offers "Preview its behaviours" and "Stop previews" for the behaviours that sit directly under it; both now read in the editor's language like the rest of the plugin's menus.
### Added: a Juice Player can loop its whole list, stop everything, and switch all juice off

The node has three new ticks: `loop`, `loop_times` (0 is until stopped) and `loop_wait`. The player waits at least one frame between passes, so a list with nothing in it that takes time cannot lock the game; the Inspector says so under the list when Loop is ticked on such a list, and a Loop Back card that loops over cards with no time at all says under itself that the play gives up after 4096 steps. New rows: Set Looping, Stop All Juice Players (with an `and_restore` option; it calls a method of the pack's own on a group every player joins by itself, never a bare `stop`), Set All Juice Players Enabled (one switch for the whole game while a cutscene or an options menu is up) and Toggle Juice Paused. A new card, Pause Or Resume A Juice Player, pauses, resumes or flips another player or this one. Juice 3D answers the two calls a player makes when its play ends, so a player beside it ends its shake.

### Fixed: the Shake card's drawing follows its curve, and says when the curve has changes its file does not

The little drawing of a Shake card that names a Custom curve used to keep the shape the curve had when the card was drawn: an edit made in Godot's curve editor changed the curve in memory and the bars stayed as they were until something else redrew the card. The drawing now listens to the curve and redraws at once, and one quiet amber sentence under it says "This curve has changes that are not saved to its file yet. The game plays the saved file." while the curve in memory and the curve in its file differ; it goes when the curve is saved.

### Fixed: the node box of Set Juice Card Field suggests paths the way a card stores them

A card keeps a node as a path measured from the Juice Player that plays it, but the box of the row that writes one value on a card suggested paths measured from the scene's root, which the card would then look up from the wrong place. The suggestions are now measured from the player the row names (and stay the scene's own paths only when that player cannot be found).

### Changed: the head bar's behaviours card reads a list of juice cards as a count

A Juice Player's saved list used to show on the behaviours card as the array's text, a line as long as the list. It now reads `steps = 6 cards` (`1 card` for one).

### Changed: Stop Juice ends what the cards started, Restore puts back the first value, and leaving the scene ends the play

Stop Juice used to return at once for a list of instant cards (the walk is over before Stop is asked) and so left the shake, the slowmo or the tween the cards had started running. Its id and its template are the same; what it does is now what its name says: the shake, the slowmo, the hold on the clock, the tweens, the sounds and the forces the cards started end, whether or not the list is still being walked. A value being walked stays where it had got to. Measured frame by frame on a running tree, before and after: a Shake card (0.6) with Stop asked at frame 3 left the camera 1.47, 0.89, 0.74 and 0.72 away from rest at frames 5, 7, 9 and 11 and trauma at 0.34, and now leaves it at 0.00 each time with trauma 0; a Slowmo card (0.3) with Stop at frame 12 held the time scale at 0.30 for the next 24 frames and now returns it to 1.00 at once; a Tween Property card (to 1.0 over 0.5 s) stopped at frame 6 was at 0.200 and went on to 1.000, and now stays at 0.200; a Flash card stopped at frame 6 was still red (1.00, 0.05, 0.05) and is now white. Restore Initial Values used to write the value a property had at its LAST touch, so two cards that moved one rotation (0, then 1, then 2) were put back to 1.000; it now writes 0.000. A player that leaves the scene now ends its play and what it started (On Juice Finished is said a moment later, so a pooled player says it and a freed one does not): a player taken out of the tree during a Hitstop used to leave the time scale at 0.00 for 16 frames or more, and now leaves it at 1.00. A fade on an audio bus is not undone by leaving the scene. An older scene and an older row keep working; a list that relied on a shake outliving a Stop adds a card of its own or no longer calls Stop.

### Changed (breaking): nine plugin classes have new names

Godot has one global class namespace, so a plugin class named like `SheetCompiler` could stop a project's own class of that name from loading. Nine classes now carry the EventSheet prefix: `SheetCompiler` is `EventSheetCompiler`, `GDScriptImporter` is `EventSheetGDScriptImporter`, `VariableParser` is `EventSheetVariableParser`, `TriggerResolver` is `EventSheetTriggerResolver`, `VariableDialog` is `EventSheetVariableDialog`, `FunctionParser` is `EventSheetFunctionParser`, `ParamDefaultResolver` is `EventSheetParamDefaultResolver`, `ActionCodegen` is `EventSheetActionCodegen`, `ConditionCodegen` is `EventSheetConditionCodegen`. A script of yours that names an old one stops parsing until the name is replaced, and the Project Doctor has a new Renamed Classes section that lists each such line with the replacement. The old names are not kept as aliases on purpose: an alias would bring the clash back. Nothing else about these classes changed, and the `EventSheets` API itself did not change.

### Changed: a call on a pack's node leads with the pack's icon

A line that calls a method of a behaviour node, `$Player/PlatformerMovement.jump()` in a script, reads as the pack's verb on the node it is mounted on (`Platformer: Jump`), and used to lead with the icon of that node's own class, the same circle as every other line of the sheet, so the one thing that says whose verb it is had no picture. It now leads with the icon its pack names with `@icon`; a pack that names none keeps the node's icon. Only the picture changed: the words, the object column, the code and the saved file are what they were.

### Fixed: the two API guides run, and the suite runs every example in them

The Building on EventSheets guide and the Custom Blocks guide taught a few things that did not work: an example with a literal `...` for an argument that does not parse, the section on testing a block kind named internal classes instead of `EventSheets.open_gd_as_sheet` and `EventSheets.round_trips` and asserted on a kind the guide never defined, use case 9 put a statement beside a function in one block, and the sketches for a flag, a checkbox and a checklist read a yes/no field with no default, which fails for a block saved before the field existed. All are fixed, and the use-case sketches now say plainly that a kind reopens as its row only when it also has a `lift` that claims its line. A new test, `guide_examples_test`, writes every code block of both guides out as a script and runs each in a second process (72 examples), so a guide cannot drift again; an example that needs a name the reader writes gets a stand-in defined in the test, never a longer guide.

### Changed: the Full Reference table of the Building guide names every public method

Forty-one public methods of `EventSheets` were missing from the table (the Manual's own doors, `timeline`, `moment_block`, `table_from_file`, `use_script_in_sheets`, `round_trip_failure` and others, described only in the sections above it). All are in the table now, the Manual-only ones marked as kept for compatibility, and `api_guide_names_every_function_test` fails when a method is added without a row.

### Changed: a row you place writes a plain number where it used to wrap it in a guard, and editing a timer row keeps its one clock

Some rows guarded a value with a floor so a typed name could never be zero: an Every X Seconds row set to `2.0` wrote `if __every_spawn >= maxf(2.0, 0.001):` and `__every_spawn = fmod(__every_spawn, maxf(2.0, 0.001))`. A row you place or edit now writes what you would type by hand when the value is a plain decimal at or above that floor: `if __every_spawn >= 2.0:` and `__every_spawn = fmod(__every_spawn, 2.0)`. A whole number (`2`), a name or anything below the floor keeps its guard, so no line ever means something different, and a value changed from `2.0` to a name gets its guard back. The 44 verbs that carry a guard all follow the same rule, and the importer reads both spellings back as the same row.

Existing files do not move. Opening a `.gd` or a `.tres` and saving it untouched writes the same bytes as before, and editing one row changes that row's lines only (an Every X Seconds row's own rebase line follows it) and never the rows beside it. The thirty showcases are regenerated and read this way now (34 lines in 12 files).

Also fixed: editing the seconds of an Every X Seconds row that came from an existing script used to add a second clock to the script (a second member, a second accumulating line and a rebase that still named the old seconds) and leave the first one running for nothing. The edited row now keeps the clock the script already had and its rebase line follows the new seconds.

### Fixed: editing any row that keeps state, from an existing script, no longer adds a second copy of that state

Every X Seconds already kept its one clock when its row was edited from an existing script. Every other verb that owns a member did not: editing Every X To Y Seconds, Trigger Once, Has Changed, Has Been True For, Only Once Ever, At Most Every, Just Landed and the other twenty or so of them added a second member and a second helper function beside the first (and a second accumulating line where there is one), and the row then called the new, empty copy while the old one stayed in the file unused. The edited row now keeps the member the script already had, so the script holds one of each and the new values are written into the call. Rows placed from the picker are unchanged, and no existing file moves when it is opened and saved untouched.

### Added: the Shake card fades in and out, follows a curve of your own, and lasts the seconds it says

A Shake card used to add trauma that always faded at the Juice node's Shake Decay, so its Seconds was only where it sat in the list. It now has two ticks, **Fade in** and **Fade out** (ticked on a new card), and a **Custom curve**: a Godot Curve file picked with Godot's own resource picker (the card keeps the file's uid as text; **New Curve** asks where to save it first and gives it a uid, and clicking the curve opens Godot's own curve editor in the Inspector). A card with a tick or a curve shakes for exactly its Seconds with that shape: Fade out goes down to nothing, Fade in rises from nothing, both swell and die away, neither holds the full amount and then stops, and a curve is any shape you draw. A drawing under the fields and the editor's Play preview show the same shape. Two new Juice rows do the same from a sheet, **Shake For** (amount, seconds, fade in, fade out) and **Shake With Curve** (amount, seconds, a Curve); the shipped Shake row, its template and its decay are untouched. A timed shake adds to the trauma and to other timed shakes up to the same top of 1, the play's strength and the accessibility dial scale the amount and never the time, and a Shake card saved before the ticks shakes exactly as before and says so in one quiet line until a tick is touched. A project with an older copy of the Juice pack is not offered ticks it would ignore.

### Changed: Stop Shake fires On Shake Stopped, and a Juice node freed in the middle of a shake leaves the camera at rest

Stop Shake used to put the camera back and say nothing, so a sheet waiting on On Shake Stopped never heard it; it now fires once, whichever kind of shake was running. A Juice node that left the tree in the middle of a shake used to leave the camera displaced for good; it now hands the camera back exactly as it found it. On Shake Stopped also fires when the last shake of either kind has ended, and Is Shaking is true for a timed shake too.

### Added: the value box of Set Juice Card Field is the box the chosen field needs

The row's value box now follows the field named in the box above it, as the card in the Inspector draws that field: a number box for an amount, a colour box for a colour, a file box for a sound or a curve, a list of nodes for a node, a tick for a tick, and the card's own words for a choice. It is the same row: its id, its template and a row saved before all stay as they were, and a value the typed box cannot show (a variable, a sum) leaves the plain box in place.

### Fixed: an open Timing foldout stays with its card, a dragged card stays inside the list, and Chance reads 100

The open state of a card's Timing foldout was remembered by position, so after a card above it was moved or removed a different card showed open. It now moves with its card. A card dragged in a card list hung to the lower right of the pointer and was cut off by the Inspector's edge; it now stays inside the width of the list. Chance in a card's Timing foldout showed 100.0 where it holds a whole number and now shows 100. Save Moment File's two warnings are one function and their sentences are pinned by a test.

### Changed: a loop, a filter and a handler you place now read the way you would type them

Four lines a placed row used to write the long way now read plainly. A Budgeted For Each with a count writes `if __done_x >= 90:` and no deadline local (a time alone writes only the time test, both write both; they used to write one long guard that tested both whichever was set). A For Each filter that is one comparison writes `if star.position.y <= 560.0:` where it wrote `if not (star.position.y > 560.0):`, and a single filter condition is no longer bracketed twice (`not ((a > b))`); anything that is not one plain comparison keeps its `not (...)`. A handler on a plain node path connects with `$RedCard.body_entered.connect(...)` where it wrote `get_node("RedCard").body_entered.connect(...)` (a path with a space, `..` or `%` keeps `get_node`). The flip reads a NaN the way an inverted comparison row already does.

Existing files do not move. Opening a `.gd` or a `.tres` and saving it untouched writes the same bytes, a loop, filter or handler saved before keeps what it wrote, and a script you wrote by hand keeps its own lines. The swarm, starfall, top_down_shooter and boomer_level showcases are regenerated this way.

### Changed: each showcase says what it is as its class description

The thirty showcases used to end on a bold-titled `#` note that only the sheet could read. The description now sits under `extends` as the class description, where Godot shows it as the class's own documentation (the Create Node tooltip and the script's Help page). Five scripts that already had a one-line description keep it as the first paragraph. The start page reads either spelling, so a script of your own that closes on a note still gets its card. The boomer_level clock reads `if not (level_over):` where it read `if level_over == false:`.

### Changed: a behaviour with no host says which node it is

The warning a behaviour writes when it has no node to act on ends `This one is at <path>.` now, so a scene with forty of one behaviour says which one is wrong. A behaviour you create writes it; a behaviour file written before opens and saves back byte for byte with the sentence it has. The 84 shipped packs that carry the warning are rebuilt with it, one line each.

### Added: every kind of Juice card has an icon, drawn in Godot's style

The 41 kinds of Juice card and the default for a card of your own each have a 16 x 16 drawing in Godot's neutral icon ink (`eventsheet_addons/juice/cards/<kind>.svg`, made by `tools/build_icons.gd` from a glyph source in `tools/pack_builders/icons/cards/`, so a project that has the pack has them). The card line draws it where the small family square was, tinted with the family colour (the same colours as before; every family still reads 3:1 or better against the card line on a dark and on a light editor, as the colour and as the tinted drawing, and a test pins that), on folded and open cards; a muted card's icon is quietened the way its name is and a selected card's takes the selected ink. Add card shows each kind's drawing beside its name and keeps the coloured square on the family headings. A card of your own wears the icon its script names with `@icon` (in its own colours) and a plain blank-card drawing in the Yours colour until it names one. The card lists share one drawer: a schema opts in with an `icons` callable, so the Drawing Prefab's list is unchanged. A card kind the pack has no drawing for keeps the square. No saved key changed; no emitted bytes changed.

### Changed: sheet rows that name a pack's behaviour lead with its icon, Manual module pages wear their section's icon, and library cards draw the icon at twice the size

An object a sheet row names resolves to the icon its script names with `@icon` when it is a script class (a pack's behaviour) and the editor theme has no icon for it, so those rows lead with the pack's icon beside Godot's own. Each Manual module page's sidebar row wears the icon of the picker section its modules list their rows under (a short override list covers the pages whose modules name no section), instead of one shared mark. A behaviour library card draws its pack's icon at 32 px from the drawing itself, and a card grows to hold its whole description instead of stopping at three rows.

### Added: Alt+Up and Alt+Down walk the selected cards, and the card menu gains Move to bottom

In every card list (a Drawing Prefab's shapes and the Juice Player's cards alike), **Alt+Up** and **Alt+Down** move the selected cards one place and keep them selected, so holding the key walks them, the way those keys walk lines in Godot's script editor. A card at the edge waits there while the others move; a press that would change nothing does nothing and makes no undo step. The card menu says the keys beside **Move up** and **Move down**, and gains **Move to bottom**. All four moves now act on every selected card when the clicked card is one of them (a card outside the selection moves alone), as Remove already did, and each is one change. Nothing saved changes except the order of the list.

### Added: a dragged card rides as itself, and a line shows where it will land

Dragging a card now carries the card's own line under the pointer instead of a bare word, leaves its old place faint, and draws a line in the editor's accent colour at the gap it will land in (in front of a card for its upper half, behind it for its lower half), as Godot's Scene dock does. Dragging a card that is part of a selection moves the whole selection, in order. A press on one of several selected cards no longer narrows the selection until the button comes up without a drag.

### Added: click a shape in the Drawing Prefab's picture to select its card

A click on a shape in the picture at the top of a Drawing Prefab's Inspector selects that shape's card in the list and scrolls it into view (a folded list opens). Shift+click and Ctrl+click select as they do in the list. Where shapes overlap, the one drawn last, on top, is the one taken; a stamp with no texture draws nothing and cannot be taken; a click on empty space clears the selection. While cards are selected the picture draws their shapes at full strength and every other shape quietened, with no ring or outline. Nothing is written: a selection is a view.

### Changed: the Drawing Prefab list's small words and icons

The Cone icon is a pie wedge, and the Stamp icon is two squares set corner to corner, so a pale one on the light theme no longer reads as a box inside a box. A finding in a folded card's summary is in the quiet amber the open card uses. The fold bar says **Shapes (8)**. The dash row of a line is **Dash offset**, so no two rows are called Offset, and the "=" that ties Dash to Gap sits between the number and its unit. The Add shape box shows its six lines whole with no scrollbar.

### Changed: behaviour icons and picker section icons are drawn the way Godot draws its own node icons

Every behaviour, global, resource and node-type pack (141 in all) now wears a flat 16 x 16 icon with no tile behind it, in one of Godot's own ink colours: red for what works on a 3D node, green for a Control, blue for a 2D node, purple for animation, Godot's grey for everything else, taken from what the pack's scripts say it works on. A pack that is a behaviour (it declares a host) also wears one small dot in the bottom-right corner, which is what tells it from a plain node. The icons are made by `tools/build_icons.gd` from a glyph source beside each pack builder and the pack build runs it, so a rebuild writes the same bytes; a 3D twin reuses its 2D drawing in red. `vector_shapes` has a 2D icon and a 3D one, and its 3D classes (and their picker rows) now name `icon_3d.svg`; every other `@icon` and `@ace_icon` path is unchanged. 57 picker sections (the three that borrowed the wrong picture, Camera, the 3D header and Performance, included) wear a drawn icon of their own, and a section that is one Godot class keeps Godot's icon. The resolver for a section's icon returns either a Godot icon name or the `res://` path of a drawn file.

Each icon's import asks Godot to draw it in the editor's own colours, so the same file reads on a light editor as Godot's icons do: in the Scene dock, the Create Node dialog, the picker and the sheet. The imports ship beside the repo's icons; a pack added from the behaviour library arrives without one, so the plugin turns the flag on and imports it again, and after a switch between a dark and a light editor it imports the pack and section icons again (once per switch). The behaviour library window, which draws files Godot never imports, swaps the same ink pairs itself. A new test pins every icon (16 x 16, no ground, one ink from Godot's map, the family ink, the dot rule, the import flag, no two the same).
### Added: the Drawing Prefab shape pictures also wear the Shape drop-down and the Add shape box

The picture of a shape is one drawing everywhere a shape is named. On a card line it wears the step's colour; in the six entries of the Shape drop-down and in the Add shape box, where there is no step yet, it wears the editor's own text colour.

### Added: Open as a table and Show as cards for a Drawing Prefab's list

A quiet **Open as a table** link under a Drawing Prefab's cards switches THIS Inspector to the table of the same list (kind, x, y, p1, p2, p3, colour, texture), and the table's own link, now **Show as cards**, switches back. The list is handed across as it is: switching writes nothing, nothing is kept in the file, and the view an object was left in comes back for the rest of the editor session. An edit in the table and an edit in a card each keep the keys the other view does not show, such as a line's ends and dashes.

### Added: a Drawing Prefab shape that draws nothing says so, and an edit no longer drops what the list holds that it does not understand

A shape that would draw nothing gets one quiet amber line of at most two short sentences under its fields, and its folded line says it too: a stamp with no texture or one that does not load ("no texture", "here.png (not found)"), a circle, ring or cone of radius 0, a cone with a field of view of 0, a rectangle with a width or height of 0 ("0 x 16"), a line whose start and end are the same point. A step whose shape is none of the six is shown as an Unknown shape card that names the word, keeps a Shape drop-down to repair it, and is kept exactly as it was.

Before this, opening a list that held an entry that is not a card at all (a number, a word, nothing) and editing any card wrote the list back WITHOUT that entry. Every card list now hands such entries back where they were; only Paste all, which replaces the whole list, drops them.

### Added: Add shape in a Drawing Prefab's list

The Add button of a Drawing Prefab's list now says **Add shape** and opens one flat list of the six shapes, each with its tile, instead of six headings of one entry each. Typing narrows it by the shape's plain name (Rectangle finds rect), the up and down keys move the highlight, and Enter adds the highlighted shape. The new card goes last, opens, and takes the keyboard on its Shape field, scrolled into view. A card list opts in with `flat_add`, `add_word`, `add_hint`, `kind_icon` and `open_new` in its schema; the Juice Player list is unchanged.

### Added: the Drawing Prefab list says which end is drawn first

Two quiet captions sit at the two ends of a Drawing Prefab's list: "Drawn first, underneath" above the first shape and "Drawn last, on top" under the last. They stay at the ends however the list is reordered, cut or pasted into, and an empty list shows neither. A card list opts in with an `order_captions` pair in its schema; the Juice Player list does not.

### Changed: an open Drawing Prefab card reads like Godot's own Inspector

An open shape card is one surface with no section headings. Shape comes first (a drop-down of plain names; changing it keeps p1, p2 and p3 under the new shape's names), then Offset as ONE row holding x and y like Godot's Vector2 field, then the shape's own named fields with their units as small plain text (px, a degree sign, x), then the colour as a colour button that opens Godot's colour picker. A Stamp's texture is picked with Godot's resource picker and kept as the file's uid text, so it survives a move; a path typed by an older version still loads and still saves as it was until you change it. A Line has a **Line look** fold (End caps, Follows scale as a tick over the stored words `uniform` and `fixed`, Dashed and the dash settings), which opens by itself when the line is not plain; ticking Dashed now shows the dash settings at once. A rectangle says it is drawn right and down from the offset, a stamp says its colour tints the texture. The paragraph that used to head every card is gone. Nothing saved changes.

### Added: each Drawing Prefab shape's line draws its shape and says its size

A shape in a Drawing Prefab's list now has a line of its own: a small tile that draws the shape (a disc, a ring, a rectangle, a line, a wedge, a stamp mark) in the step's colour, the shape's plain name (a `rect` step reads Rectangle; the stored word does not change), and a quiet summary in that shape's words: `radius 46, 5 px thick`, `24 x 16`, a line's true length as `120 px long`, `60° wide` for a cone, a stamp's file name or `no texture`. On the light editor theme a pale shape keeps a faint dark edge that follows the shape. The tile and the summary repaint as you type, without the list being rebuilt. Nothing saved changes.

### Changed: playing one card on its own, and the strip's preview, play a card's repeats

The mark that plays one card alone, the strip's Play, the lit marks on the cards and the sound of a Sound card in the editor now follow a card's Delay and Repeat as the game does: a shake with a delay of 0.05 s and three repeats 0.08 s apart is seen for 0.51 s, three times over, where it used to be seen once for 0.35 s (measured per frame in the editor).

### Changed: the example juice card of your own shows its unit

A field of a card of your own is drawn by Godot's own editor for the export, which draws the unit an export hint carries (`@export_range(0.0, 2.0, 0.01, "suffix:s")` shows `0.1 s`). The shipped Screen Flash example card had no unit on its Seconds, so it read as a bare number beside the built-in cards; it carries `suffix:s` now, and a test holds the hint all the way to the editor for any card of your own.

### Added: a Timing foldout on every juice card, and a clock mark on a card whose timing is not the default

Every kind of juice card, a card of your own included, ends with a **Timing** foldout, closed until you open it: **Delay** (seconds), **Repeat** (times), **Every** (seconds between repeats), **Clock** (Game time or Real time), **Chance** (percent) and **Only at strength** (from, to; the top empty means no limit). They write the keys the running game has always read on every card, the keys Set Juice Card Timing, Set Juice Card Chance and Set Juice Card Field write (a repeat is a whole number), and nothing is written until you change a number: a new card holds none of them, a card nobody opens stores nothing new, and every saved scene stays exactly as it is. A grey line under the fold says what the numbers do ("Waits 0.05 s, then is felt 3 times, 0.08 s apart."), and a card whose timing is not the default wears a small clock mark on its head. The time on a card's head and the length under the list count the repeats. The Sound card's own Delay box moved into the fold, where every card has it.

### Changed: Set Juice Card Field reaches the clock and the strength window, Save Moment File names every key it leaves off, and the rows' label boxes list the player's cards

Set Juice Card Field and Juice Card Field now take `clock`, `min_strength` and `max_strength` on any card (the Timing keys the runtime reads) as well as the eight they always took and any key the card already holds; the row's id, its line of code and every saved sheet are unchanged. Their field box offers those three after the eight, and every key it offers has the word the Inspector shows beside it, the word first (`label` and `active` have words now too). Replace Juice Card used to open on a card called `recoil`, which is not a card, so a row dropped with its defaults added a card Juice refused; it opens on a Punch card now. Save Moment File always named whole cards a file cannot hold; it now also names, before it writes, the keys of a card it keeps that a file has no place for (a delay, a repeat, a chance, a field of a card of your own), so nothing a card holds is dropped without being said. The label boxes of the rows that name a card (and the after / before boxes of Add and Insert) now list the labels of the Juice Player the row acts on, read from the saved scene, and still take a label typed, since a list built while the game runs is not in the scene.

### Changed: a card's Delay and Repeat hold up that card only, and the length of a list counts them

A felt juice card with a Delay above 0 or a Repeat above 1 used to hold up every card under it until its own wait and its last repeat were over, while the timeline in the Inspector, the time on the card's head and Juice Duration showed those cards starting on time. The game now agrees with what the timeline shows: such a card waits out its Delay and plays its repeats beside the list, and the cards under it start when they would have without it. A Hold still waits for the slowest card above it, repeats and delay included, so a list with a Hold under the timed card plays exactly as before. A Pause and a Hold keep their own Delay as part of their wait. Measured on a running tree, a list of three cards whose middle card has a delay of 0.3 s and three repeats now feels its last card at once where it used to feel it after 0.70 s, and a Pause under a card that repeats three times no longer waits for the repeats (the card under it is felt at 0.10 s, not 0.50 s). The play ends when the last card started this way has finished, Stop ends them where they stand, and Skip To End feels the ones still waiting out their Delay. Lists with no Delay and no Repeat, a Delay on the last card, and a Delay on a Pause play frame for frame as before. If you liked the old feel on a card, put a Pause card under the timed one. The same pass fixes the plan: a Hold under a Pause was planned too late (a card after `[shake 0.2 s, Pause 0.25 s, flash 0.1 s, Hold 0.1 s]` is planned at 0.45 s, which is when the game feels it, and it used to be planned at 0.55 s), a card's length and a list's length count the repeats, and Juice Card Duration reads the same.

### Changed: a line in a Drawing Prefab ends at the same point in every picture of it

A line step's End is a point in the prefab's own space, measured from the prefab's origin. That is what Draw Prefab has always drawn, and what the shipped target marker was made for (two lines that cross at the centre). The Inspector picture, the FileSystem thumbnail, the 3D billboard, the 2D gizmos of a Drawing Canvas's preview prefab and the **DrawingPrefabStamp** node used to end a line at its offset plus its End, which drew the marker as two half arms. They now end it where Draw Prefab does. **Whose picture changes:** the Inspector, the thumbnail, the billboard, the gizmos and the DrawingPrefabStamp node (in the editor and in a running game) for a line whose offset is not 0,0; a line that starts at 0,0 reads the same either way. Games that draw a prefab with Draw Prefab do not change. A DrawingPrefabStamp already in a project keeps its old drawing until its pack is updated from the library.

### Changed: Draw Prefab draws a line's end caps, dashes and scale rule

A line step may carry end caps, a dash pattern and the rule for whether its thickness follows the prefab's scale. The stamp node and the Inspector picture drew them, but Draw Prefab drew every line plain. It now draws a dressed line the way the stamp node does: dashes and gaps grow with the scale, and a fixed line keeps its own thickness at any scale. **Whose picture changes:** a game that draws a prefab with Draw Prefab, for a line step that carries one of those keys (the card writes them; no shipped prefab has any). A line that carries none of them queues the same line command as before and draws the same pixels.

### Changed: a stamp in a Drawing Prefab turns by its Spin, and the Inspector picture draws its texture

Draw Prefab has always turned a stamp step by its Spin; the **DrawingPrefabStamp** node ignored it, so one prefab showed a stamp upright in the viewport and turned in a game. The node now turns it about its centre (a stamp with no Spin draws as before). The Inspector picture, the FileSystem thumbnail and the 3D billboard drew every stamp as a small tinted square whatever its texture, even with none; they now draw the texture turned by its Spin and tinted by the colour, and a stamp with no texture that loads draws nothing. **Whose picture changes:** the DrawingPrefabStamp node for a stamp with a Spin, and the Inspector, thumbnail and billboard for any prefab that holds a stamp step. Draw Prefab does not change.

### Fixed: a Drawing Prefab's steps open as cards, a rectangle's help says where it is drawn, and a ring is not offered a scale rule

The shape cards the Inspector has for a prefab's steps were never shown: the generic table drawer claimed the property first because the prefab's own plugin was registered before it, and Godot asks the plugin added last first. The steps now open as cards. The cards and the shared card list also honour a read-only object now. A rectangle's help said it was centred on its offset, but it is drawn right and down from it, so the help says that. A ring was offered a scale rule that nothing reads; only a line is offered it now.

### Changed: the field box of Set Juice Card Field and Juice Card Field offers the keys the named card holds

When the scene the sheet runs in is saved, the field box reads the Juice Player the row is on and the card its label box names (a label, or a position counting from 1) from the scene's bytes, and offers that card's keys in the order the card holds them, each with the word the Inspector shows for it beside it (Stream, Volume, and a card of your own offers its exports). `verb` and `card_script` are never offered. Changing the label changes the list. When the scene, the player or the card cannot be found the box offers the eight names it always did, and a typed key is taken as before. A saved row keeps its bytes.

### Fixed: Show its cards is offered on a Play Juice row that was reopened from a line of code

A line written by hand (`$HitJuice.play(1.0)`) already reopens as the Juice Player's own row when the scene the script runs in says that node is a Juice Player, for every verb the pack has a row for (forty-three actions and conditions, each saved back byte for byte; a test now pins all of them against a fixture scene). Such a row carries the id `method:play` where one placed from the picker carries `play`, and the Show its cards entry only knew the second; it now offers the entry on both. The nine verbs that return a value (Juice Card Field, Feedbacks Duration and the like) are read inside other rows, so they have no row of their own to reopen as.

### Changed: a block kind's validate() is the quiet amber note, not red text in the row

What a kind's `validate()` says about one of its rows used to be painted into the row as red text. It now does what every other check on the canvas does: the row wears the quiet amber state and the sentence is said in full in the strip under the selected row. Nothing is drawn inside the row and the hook's shape does not change. A kind that wrote a long sentence should shorten it to a plain sentence or two.

### Changed: a block cannot be disabled

A block writes its line into the file whether or not its enabled flag says otherwise, and the compiler never read that flag for blocks, so switching one off only looked like it worked. Ctrl+/ and the row menu now leave a block as it is, make no edit and say so in one plain line. A sheet that already holds a block saved as disabled keeps compiling exactly the same bytes, and the row says in its amber note that it still runs.

### Fixed: the Add menu opens the block kind it names

The block items of the Add menu were numbered by their place in the registry's list at the moment the menu was built, and a click read the current list by that number, so a kind registered later moved every kind after it one place along and a click opened its neighbour. Each item now remembers its kind, and the menu brings the list up to date each time it opens, so a newly registered kind appears without a restart.

### Fixed: the migration band reaches scripts that hold only retired rows and sheets saved as .tres

A sheet whose only rows to migrate used a verb that was retired with nothing to replace it (so there was no newer spelling to count) showed no band, and a `.tres` sheet, which has no scaffold lines to build a head from, never showed one. Both now say "1 row asks you" or "1 row has a newer spelling" with the same Migrate door, so the window is reachable from the sheet and not only from the Doctor. The other head bands of a `.tres` sheet are left as they were.

### Fixed: the refusal of a nested `EventSheets.edit()` stays on the status bar

An `edit()` started inside another `edit()` was refused, but the outer edit's own "saved" line replaced the refusal a moment later, so nobody saw it. The refusal is now the line left on the bar.

### Changed: every warning a running Juice Player prints names the player, the card and the reason

A Tween Property card on a property the object does not have, a Fade Bus card on a bus the project does not have, Set Juice Card Field on a field no card holds (and on the word or script of a card, which it never changes), Copy Juice Cards From a node that is not a player, and the moment-file rows now all say which player and, where a card is the cause, the card's label and what is wrong, and say it once per card. Nothing about what the cards do changes.

### Added: the Doctor finds a juice card that points at a node or a file that is not there

A new check in the Juice Players section reads every saved scene, without instancing it, for a card whose node path finds no node in the scene (a node moved out or renamed away) and for a card that names a sound, a scene or a card script the project does not have. Each is a warning of two short sentences naming the card, the player and what it points at. A path that leads into a scene instanced inside this one, or out of this one, and any card of a scene that inherits another, is left alone, because the file cannot show it is wrong.

### Added: Show its cards on a row that plays a Juice Player, and Find what plays this on the strip

The right-click menu of a row that plays a Juice Player (Play Juice, Play Juice And Wait, Play Juice Backwards, or the line of code that does the same) gains **Show its cards**: it opens the scene the sheet runs in, selects that player and leaves the Inspector on its list. It is offered only when that scene holds a Juice Player of that name, and it is a menu entry, not anything drawn in the row. The strip under a player's list gains **Find what plays this**, which lists the sheets of the project that play it and opens the one you pick, or says in one quiet line that none does. Both read the project when they are used and keep nothing.

### Fixed: a sheet that extends a class of your own project that extends Resource is a Custom Resource sheet

The Sheet Type dialog and the Variable drawer knew only the engine's classes, so a sheet that extended a Resource class you wrote (a card base, a stat block) fell back to a plain Resource host and its members read as instance variables. The project's own list of classes is now followed down to Resource, so such a sheet is a data asset and its members are fields.

### Added: a juice card of your own, a script that extends JuiceCard

A script with a `class_name` that extends the new `JuiceCard` (`eventsheet_addons/juice/juice_card.gd`) is a card of your own. It appears in the Add card box under a **Yours** heading, named from the class (`ScreenFlashCard` reads Screen Flash) with the line written under the class as its help, and it goes when its file does. Its exports are its fields and are drawn with Godot's own editors for their types: a colour button, a range with its suffix, a file picker, a drop-down, a node picker for a `NodePath`; the `##` line above an export is its tooltip. `play(target, strength)` is the only function it must write; `length`, `stop` and `restore` are optional, and a card that exports `seconds` is that long without writing `length`. The card is saved as one more entry in the same list (its class name, the address of its script as a uid, a key for each export), so the list keeps its saved type, copy and paste carry it, a renamed class is still found by its script, and a class called Pause or Sound is never mistaken for the built-in word. Stop Juice and Restore Initial Values reach a card that is still going. Set Juice Card Field and Juice Card Field take any value the card holds (the box offers the eight shipped names and accepts any other; the word and the script of a card are refused), and Add Juice Card and Replace Juice Card add a card of yours as it is. The editor's Play runs a card of yours only when its script is a tool script, and Debug view says which. `eventsheet_addons/juice/screen_flash_card.gd` is the example, written as a Custom Resource sheet that extends `JuiceCard`; the same card written by hand as GDScript opens as a sheet and saves back byte for byte.

### Fixed: the Add card box is as wide as the Add card button and shows whole lines

The box was a narrow list about 220 pixels wide that cut its last line in half. It is now as wide as the Add card button above it and as tall as fourteen whole lines, and scrolls after that.

### Added: the Inspector's Play button shows the cards that move other nodes

Play, Play this card and Play from here now show Particles, Animation, Sprite Animation, Show or Hide, Squash And Stretch, Punch Position, Punch Rotation, Pop, Fade, Count To, Reveal Text, Fill Bar, Shader Value and a Tween Property card that points at another node, and Debug view calls each of them played. Before the first frame the preview writes down every property those cards may move on every node they point at (a label's text, a bar's value, a node's visible, modulate and scale, the tracks of the clip it plays, the shader value on a copy of the material that lives for the pass), and puts exactly those back on Stop, Restore, at the end of a pass and before the editor saves or runs the scene, so a scene saved in the middle of a preview holds the same text it held before. Spawn Scene, Push, Force, Gravity, Freeze Body, Grab Focus, Call Method, Emit Signal and Play Player still say why they are not shown.
### Fixed: smaller API answers

`stabilize_row_uids(null)` and `pack_shipped_assets` on a folder that is not there answer quietly instead of raising engine errors. A plain string a registered completion source returns is offered as `text` rather than `variable`, so it no longer wears a variable's badge in the popup. `asset_drop_builder_for()` ignores case and a leading dot.

### Fixed: an asset drop handler registered for ".DLG" is found for ".dlg"

`asset_drop_builder_for()` lower-cased the extension but kept its dot, so a handler registered as `.DLG` (stored as `dlg`) was missed when asked for `.dlg`. A leading dot and the case no longer matter on either side.

### Fixed: simple_aces(), registered_starters() and preference_builders() hand out copies

These three returned the plugin's own live list, so a caller that cleared or edited what it was given changed what the editor offered. Each now returns a copy; use `unregister_simple_ace`, `unregister_starter` or `unregister_preference` to take one back.

### Added: try_register_block_kind and unregister_block_kind

`EventSheets.try_register_block_kind(kind)` registers a Custom Block kind the way `register_block_kind` does and returns "" on success or the plain reason it was refused, instead of a warning in the Output panel. `EventSheets.unregister_block_kind(kind_id)` (and `EventSheetBlockRegistry.unregister_kind`) takes a pack's kind back; a built-in kind cannot be removed.

### Changed: register_provider_script no longer edits the open sheet

`EventSheets.register_provider_script(path)` used to add the script to the sheet that was open when there was one, which marked that sheet changed and added an undo step, and only joined the session when no sheet was open. It now always registers for the session and edits no sheet. The new `EventSheets.add_provider_to_sheet(path)` does the per-sheet edit (one undo step).

### Fixed: a palette command registered with a category can be taken back

`unregister_palette_command(title)` could not find a command registered with a category, because the palette lists it as "Category: Title". It now takes the category too (`unregister_palette_command(title, category)`); the old call with the combined title still works.

### Added: everything an extension can register can be taken back

New calls on `EventSheets` undo a registration: `unregister_starter(label)`, `unregister_preference(builder)`, `off_sheet_opened/saved/compiled(callback)`, `unregister_quick_add_synonyms(keys)`, `unregister_section_description(name)`, `unregister_asset_drop_handler(extensions)`, `unregister_simple_ace(id, provider_id)` and `unregister_editor_gizmo(script_path)`. A section description or asset drop handler that replaced one of the plugin's own comes back when you take yours away. A tool that reloads no longer has to restart the editor to drop its own registrations.

### Added: set_editor_language("") goes back to following Godot's language

Choosing a language through `EventSheets.set_editor_language()` was remembered with no way back: an empty string used to pin English. It now forgets the saved choice and follows Godot's own editor language again.

### Fixed: EventSheets.open_sheet() tells the truth about a file that is not there

`open_sheet()` returned true for a path with no file and printed engine errors. It now returns false and the status line says there is no file at that path. Asking for a file that is already open brings its tab forward instead of opening a second tab of it.

### Fixed: a script that registers a lambda and quits exits with its own code

A headless script that registered a Doctor check, palette command, row menu item or listener as a lambda and then quit used to end in a crash (exit code 139, whatever code it asked for), so CI read every such run as a failure. Everything registered through `EventSheets` is now let go as the scene tree leaves, so the process exits with the code the script gave.

### Fixed: compiling a sheet that has no file no longer leaves a stray script

Asking the compiler to write a sheet that has no file and no output path used to create `res://event_sheet_generated.gd`, a script declaring that sheet's class in your project. It now writes nothing and adds a warning to the result; the compiled text is still in `output`.

### Added: a block kind can say a row writes nothing

A Custom Block kind can define `writes_nothing(block)` and return true for a row that rightly has no line to write, such as a marker that is switched off. The compile no longer fails for that row. A kind that does not define it keeps today's check: a row with fields that writes nothing still fails the compile and names the kind.

### Added: the Theme Editor's legend, a light accent, and a Theme field that says what each theme is

One line of quiet words under the Theme Editor's scrolling form, always in view, explains the dashed box, the chain and the mark beside a swatch. Quick Style's Accent row has a Dark and a Light picker like Base and Text, and Generate uses each for its own column; the light accent moves with the dark one until it is picked on its own, so one accent still works. The Theme field lists each theme with a swatch of three stripes (its sheet colour, accent and text) and its folder, a tooltip with the file, group titles ("Follows the editor", "Starters (copy to edit)"), and one sentence under the field about the open theme. Godot's drop-down has a single text column, so the folder shares the name's line rather than standing in a column of its own.

### Fixed: closing a Theme Editor with changes asks over the window

The Save, Discard or Cancel question used to appear after the window had gone. It now appears over the window, which stays until you answer; Discard puts the file's colours back and closes it, so the window holds no changes afterwards. A sheet that carries its own copy of a theme still keeps that copy when the theme's file is saved, and the window says so, because nothing records which file a copy came from and refreshing it would overwrite changes made on the copy.

### Added: a theme can hold light colours, and the sheet wears the side that matches Godot

Every block of a theme (`event_style`, `condition_style`, `action_style`, `reading_style`, `chrome_style`, `manual_style`) can hold `light_colors`, a dictionary of token name to colour that names only the colours given a light value. The colours a theme has always held are its dark colours and keep their lines. A light editor draws a theme's light colours, a dark editor never does, and a switch of Godot's editor theme changes the sheet over. A theme opts in by holding a light colour or by following the editor's greys; a theme that does neither is drawn in a light editor exactly as it always was, so no theme saved before this looks any different. An older build opens a theme saved with light colours and keeps every other value, but drops the light ones the next time it saves.

### Added: every colour in the Theme Editor has a dark swatch and a light one

A light swatch sits beside each colour, with a chain between the two. A dashed "auto" swatch is a light colour that is worked out (the editor's greys when the theme follows the editor, otherwise the dark colour); picking a colour on it makes it the theme's own. The chain gives light a colour of its own or sends it back to the dark one, and a colour nobody gave a light value writes no light line. Every light edit is a step of the window's own undo list, and the strip's IN FILE line shows the light line a colour writes.

### Added: Preview as in the Theme Editor

Dark and Light above the sample sheet change only the preview, so a theme can be judged on both sides without switching Godot. The window opens on the editor's own mode.

### Added: a swatch whose words would read badly on their ground is marked

A small amber mark after a colour says its words read under the bar on the ground they are drawn on (4.5 to 1 for sentences, 3 to 1 for marks and badge letters), and the strip says the ratio, the ground and the side. Nothing blocks a save. The pairs come from the one list the Editor Native contrast test already holds.

### Changed: Quick Style fills the dark and the light column at once

Quick Style has a base and a text colour for dark and for light and one accent, and Generate Theme fills both columns as one undo step. The follow-the-editor tick reads "Follow the editor in light".

### Changed: Match Editor opens on a theme's own colours in a light editor

The window used to open Match Editor on colours a light editor had already moved onto its light greys, so the dark swatches held light values. It opens on the colours the theme holds, and the Light preview shows the rest.

### Fixed: the Reading font field says what goes in it, whole

The hint ended in "blank keeps the editor's ow". The words now have a line of their own above a short field.

### Fixed: the list in the Shared Sheets window is headed Shared Sheets

It still said "Included sheets".

### Fixed: one sheet can go back to the editor's own look while the project names a theme

While Use For Every Sheet names a theme, the first entry of the Sheet theme menu is that theme, so there was no way for one sheet to match the editor. The Editor Native entry now reads Match Editor then.

### Changed: saving a theme says so when the open sheet keeps its own copy

A sheet that carries a copy of a theme inside itself does not take up what is saved into the file. The foot now adds "The open sheet keeps its own copy of a theme; pick the theme again to update it."

### Changed: the editor closure has room again

Four files that are only needed once a menu or a right-click asks for them (the game catalog, the pattern adopt helper, the Moment file helpers and the scene events facts) are compiled at that moment instead of when the first sheet opens, 1,002 lines fewer in the first open.

### Added: the Theme Editor edits one theme file, and saves it

The Theme Editor's title now names the theme file it opened ("Theme Editor - nord_copy.tres") and gains "(changed)" the moment a swatch moves. Ctrl+Z and Ctrl+Shift+Z step the swatches back and forward inside the window, and Revert goes back to the file. A Theme field at the top of the form switches to another theme without closing the window, grouped as Match Editor, Your themes, In this project and Starters. Save (or Ctrl+S) writes the file the window opened, and every sheet wearing that theme repaints at once. Save As... makes a new file from what you see and the window then edits that file; it replaces the old Save As Preset button. A starter that comes with the plugin, or a theme in the demo folder, is never written: the window offers Save a Copy... instead, which starts in `res://eventsheet_themes/` with a free name such as `editor_native_copy.tres` and puts the open sheet on the copy. Match Editor has no file: change a swatch and it becomes an untitled theme that Save As... asks where to keep. Closing the window, or switching theme, with changes asks Save, Discard or Cancel the way Godot asks for a changed scene. Godot renumbers the blocks inside a `.tres` on every save, so two saves of the same values read the same only when those numbers are ignored; every value is the same. A theme file saved before this change opens, saves and reloads with every value kept. All eight languages are translated.

### Added: right-click a theme file in the FileSystem and choose Edit in Theme Editor

The entry is offered for exactly one theme file, decided by the file's own first line without loading it, and opens the Theme Editor on it whichever sheet is open. Double-clicking a theme is left to Godot on purpose: claiming it would pull the editor into the sheet workspace whenever a theme is inspected, a sheet's own theme shown in the Inspector included, so the Inspector keeps editing a theme as it always did.

### Added: Use For Every Sheet names a project theme in Project Settings

View, Sheet theme, Use For Every Sheet makes the theme the sheet wears the project's default look, kept in the registered setting `eventsheets/theme/default_theme` (a file, empty by default). A sheet that chose no theme of its own wears it, a sheet's own theme always wins, and a project that sets nothing looks exactly as before. Choosing the entry again, or clearing the setting in Project Settings, takes it off. While a project theme is set the first entry of the Sheet theme menu reads "Project theme: <name>" in place of Match Editor, and Theme Editor... opens on it for a sheet that wears it.

### Changed: Apply To Current Sheet on a script keeps a saved theme

For a script sheet the Theme Editor's opening note now says what Apply does: it keeps a theme from a saved file for the script in this project, and nothing is written into the script. A look that has no file yet is still worn until the script is closed, and the status line says so.

### Fixed: the Sheet theme menu keeps ticking the theme after a Density pick

A Density pick copies the sheet's theme, and the copy has no file, so the menu ticked nothing. It now ticks the theme the copy was made from (Match Editor when the sheet had none).

### Fixed: the Section right-click menu says Section in every entry, and the Shared sheet window is titled Shared Sheets

The fold entries read "Open / Close Section", "Open All / Close All Sections" and "Open Section" or "Close Section", and the multi-row entry reads "Put Selection into New Section" (Group under the Familiar words preset). The Shared sheet window's title read "Manage what probe.gd includes"; it now reads "Shared Sheets in probe.gd" (Includes in probe.gd under the Familiar words). All eight languages are translated.
### Added: juice cards that point at a node, an animation, a body, a Control or a shader

The Add box gains Particles, Spawn Scene, Animation, Sprite Animation, Show or Hide, Squash And Stretch, Punch Position, Punch Rotation, Push, Force For A Time, Gravity For A Time, Freeze Body, Pop, Fade, Grab Focus, Count To, Reveal Text, Fill Bar, Shader Value and Call Method. A node is picked with Godot's own node picker and kept as a path from the player, a property with Godot's property picker, and an animation, shader value, signal or method is chosen from what the picked node really has. When a picked node is gone the card says so in quiet amber; when the game runs, a card that finds nothing says so once in the Output panel and does nothing. Tween Property can now move any property of any node to a number, a colour or a vector with a transition, an ease, a way back and an "add to the value" tick (a card saved the old way plays exactly as before), Emit Signal can fire a signal of a node you pick, and Play Player picks the other player instead of asking for its name (a typed name still works, and a player will not play itself or one that is playing it). Quiet notes warn about moving a physics body by position, a container's child by position, scaling a body, and a shared shader material. The Add box's search now adds the first card it finds when you press Enter, a node field shows the node's name as the Scene dock does (its path is in the tooltip), and Reveal Text takes a speed in letters a second. Not yet: a curve of your own for a tween, and the node list of a sheet's Add Juice Card row.

### Fixed: a saved Sound card with no pitch shows the pitch the game will use

A Sound card saved without a Pitch, or without Heard from, now shows 1.0 and This object, which are what the game plays, instead of 0.0 and nothing. The words on cards (titles, help, field names, choices) are translated in all eight languages, and the card menu shows the keys beside Duplicate, Cut, Copy, Paste and Remove.

### Changed: the Tool sheet notes about undo and rebuilds are two short plain sentences

The two notes a Tool sheet's Building rows can earn are now two short plain sentences each, what is wrong and then what to do. "This row adds a node to your scene, but Ctrl+Z will not take it back. Use Add Node (Undoable) to make it one step you can undo." and "Each run adds another copy of these nodes. Add Remove What This Sheet Built at the top of this event." They no longer start with the file name (the strip is on that file's own sheet, and the Doctor's list names the file beside the note), no longer quote the line the row writes, and two notes on one event are shown on two lines instead of joined by a dot. All eight languages are translated.

### Changed: the Migrate window says 1 row or 2 rows

The Migrate window's first line now says "1 row would be rewritten in one step you can undo." or "2 rows would be rewritten ...", and "1 row is left exactly as it is." or "3 rows are left exactly as they are.", instead of "row(s)". All eight languages are translated.

### Fixed: a theme, lane split, column width or density picked for a script sheet stays picked

A sheet saved as a script (a `.gd` file) is plain code, so nothing about how it looks can be written into it, and the choices made for one were lost the moment it was closed. They are now kept in the project itself (the editor's project metadata, one small record per script) and put back when the script is opened again: the theme you picked in View, Sheet theme, how wide you dragged the conditions and actions lanes, how wide you dragged an object column, and the Density you picked. The script is no longer marked changed for any of them, since nothing about it changed, and the status line says where the choice is kept. Match Editor lets go of all of it. A sheet saved as a resource carries its look as before. The Sheet theme tooltip, which promised the choice travels with the file, now says what really happens.

### Changed: Apply To Current Sheet in the Theme Editor is not an undo step

Every other way of changing a sheet's theme already stayed out of the undo history, because undo is for what a sheet says and not how it looks. Apply To Current Sheet now does too, so Ctrl+Z no longer takes a theme off. On a script sheet, which has no file to keep a look in, it says the look lasts until the script is closed and that saving the theme to a file keeps it.

### Added: your project's own themes folder is listed in the theme menu

A theme saved into `res://eventsheet_themes/` now appears in View, Sheet theme beside the bundled ones, and the Theme Editor's save dialog starts in that folder. The folder is made when the dialog opens and taken away again if you cancel and nothing was put in it. A theme file you already keep there is listed with no step.

### Fixed: the Manual's quiet words read on the editor's own ground

The Manual's breadcrumbs, captions and prompts took a grey that was nearly invisible on a light editor and under the readable line on a dark one. They now use the same raised quiet-words colour as the sheet, in the Editor Native starter and in whatever the sheet follows onto a light or dark editor.

### Fixed: the light example theme's finding colour reads on its own rows

One of the example themes (the light one) stored a tan for every finding that read faintly on its cream rows. Its finding colour and the colours derived from it are now the darker tone the shared rule gives a light sheet. The tool that rebuilds the example themes also lost six stated colours and a run of layout switches each time it ran, and now writes them back, so rebuilding changes only what it should.

### Added: four more settings are in Project Settings

The angle unit a bare number means (`eventsheets/angles/default_unit`, degrees or radians), caption notes from the Project Doctor (`eventsheets/doctor/caption_sounds`), whether the Doctor suggests an error report (`eventsheets/doctor/suggest_error_report`) and the extra scripts and folders that join the vocabulary (`eventsheets/vocabulary/extra_paths`) were read by the editor and named in the Manual, but never registered, so a reader told to turn one on found nothing to turn on. Each is now listed with its hover text. The defaults are what the editor already assumed, so nothing is written to `project.godot` for a project that never heard of them.

### Fixed: the Words page lists only words that something in the editor says

Thirty-one of its rows changed a word that no row, menu or window ever printed, so typing a new word there did nothing. The page now lists the fifteen words the editor does say (the family, the process callback and the other callbacks, destroy, the angle, overlaps, the two collision words, and the Section, Shared sheet and System names). Nothing is deleted: a choice saved under one of the other words still reads back, and the Manual's list of the editor-building words is unchanged. The page's preview also reads the spawn verb the rows read.

### Fixed: the Section block's menu, the Shared sheet window and the Welcome sentence use today's words

A Section's right-click menu still said Edit Group, Group Color and Ungroup, and now reads the word the block is called (Section, or Group under the Familiar words). The Shared sheet window said "include", the shortcut list described the section command as grouping, the Welcome sentence and the glossary sent a reader to Settings, Words (it is under Tools), and two comments named a Profile tab that was removed. They now say what the editor says.

### Fixed: twenty-three menu labels had no translation

Declare and its entries, Docs Housekeeping, Familiar Words, Lift Workbench, Project View, Translation Studio, Preview In Language and a dozen more stayed English in every language. Each now has a row in all eight languages, and a test fails when a menu label is added without one.

### Changed: the building guide names every public function

Thirty-eight functions of the `EventSheets` API added since the guide was written are now in it, in a new section: opening and searching the Manual, finding a pack's or a module's guide, reading what a project uses, and building rows and tables.
### Added: select cards, and copy, cut, paste, duplicate and delete them with Godot's own keys

Click a juice card to select it, Shift+click for the run from the last click, Ctrl+click to add or take one out. A selected card is filled the way a selected row is in the Scene dock, with no outline, and the list holds the keyboard from then on: Ctrl+C copies the selected cards, Ctrl+X cuts them, Ctrl+V pastes them under the last selected card (or at the end when nothing is selected) and nothing is replaced, Ctrl+D duplicates them in place, Delete removes them. Each is one change, so one Ctrl+Z takes it back. A right click on a card now opens its menu (it never did: the panel round the card's line kept the click), which acts on everything selected when the card is part of the selection, and gains Cut and Paste. Paste over, Paste all and Copy all are unchanged. Select the other object's list, click in it and paste: that is the whole trip between objects. Cards that start together now sit on one faint band, so the groups show without unfolding anything. The list's Drawing Prefab twin has all of it too.

### Fixed: cards copied on Windows pasted nothing

The clipboard hands every line back ending in a carriage return, so the marker line of copied cards no longer matched and Paste over and Paste all did nothing across objects. They are read without it now.

### Changed: an open juice card is one surface

A card's head and its fields used to be a dark bar with the fields drawn below it on the plain Inspector ground, so nothing tied them together, with the card menu alone on a line between the two. An open card is now one panel: the head (grip, arrow, tick, family tile, name, length, menu, play mark, remove mark) and the fields share the same surface, with one faint hairline round the whole card and no gap. Field labels and values use the Inspector's own text size; only the one-line description and the closing notes stay small and quiet. The same drawer draws the Drawing Prefab's cards.

### Fixed: every pack's info paragraph spans the whole Inspector row

An info line under a property (for instance the Juice Player's "One juice card per effect...") was drawn only in the value column, wrapping into a tall box beside an empty label column. It spans the full row now, in the quiet text colour, and wraps again when the Inspector is resized.

### Fixed: the card menu and the list's own words are translated, and the list's paragraph takes the full width

Duplicate, Copy, Paste over, Move to top, Move up, Move down, Remove, the empty list's line, the Active and Label rows and a few tooltips were English in every language; they are in all eight now. The paragraph under a juice card list ("One juice card per effect...") sat in the right half of the Inspector and wrapped a dozen lines down a narrow strip; it spans the row now. A short badge such as 0.30 s is no longer broken one letter to a line when the card's title is long.

### Added: a Hold can wait for one card

A Hold card has a new Waits for choice: all the cards above (as before) or one of them, by name. With one chosen it waits for that card alone, so a slower card above carries on beside what comes next. A name that is no card above any more waits for the slowest card, as a Hold with no name always did, and the line under the Hold's fields says so in quiet amber. The head says how long the Hold will wait and for which card, and the Add box finds Hold and Pause when you type wait. The walk, the length and the plan the Inspector draws all read the same functions.

### Changed: Play Juice And Wait waits for the cards to finish

Play Juice And Wait used to return as soon as the head had walked past the last card, so a list of cards that take time (a 0.3 s shake, a tween) let the rows under it run at once. It now waits until the last card has ended, which is what its description always said. The row's id and what it compiles to do not change. To get the old behaviour back use Play Juice, which carries straight on, or put the rows under a Hold row.

### Added: Stop Sound, Fade Bus and Vibrate cards

Stop Sound ends a sound an earlier Sound card started, by that card's name, with a fade if you want one (no name stops every sound the player has going). Fade Bus moves a bus volume to a value over a time and Restore Initial Values puts it back; a bus the project does not have is said once and left alone. Vibrate rumbles every connected controller (weak and strong motor, scaled by the strength of the play) and buzzes a phone for a time; it does nothing on the web. None is felt in the editor, and Debug view names each as skipped. The Add box gains a Device heading.

### Added: Autoplay on the Juice Player

A new Autoplay tick on the node plays its list once, at full strength, when the node enters the scene: a spawn pop, a pickup shimmer. It starts off, and while it is off nothing is written into the scene, so a saved scene stays the bytes it was.
### Changed: a Tool sheet's Building rows are named as edits Ctrl+Z does not take back

A Tool sheet's Building rows (Add New Node and its siblings, and Remove What This Sheet Built) add and free nodes in the scene the editor has open, and Ctrl+Z does not take that back. The quiet finding about edits the editor cannot undo used to miss them, because those rows reach the open scene through the tree's own edited root instead of the editor interface. It now reads them: the event that builds wears the quiet amber state, and the Doctor's Tool edits section says the same sentence, naming the rows that do take a Ctrl+Z (Add Node (Undoable) and Remove Node (Undoable)). Nothing about the rows changed, there is no button on the note (their values do not map onto the undoable rows one for one), and a game sheet is never asked.

### Added: a Doctor note for groups used as states

The Doctor now notices groups used as states. If a script puts an object into one group and takes it out of another in two or more separate places (add to "jumping", remove from "running", and the reverse), so that exactly one of the groups is true at a time, the Doctor says so once for that script, quietly, naming the groups, and points at the States window, which keeps the same idea in one variable you can read, rename and react to. Groups that are only joined (an "enemies" group, a "pickups" group) are never named, and a single swap on its own is not enough. It reads every script in the project, hand-written or compiled.

### Changed: the States window shows everything it will write on a file with no states yet

Declaring states on a script that has none writes more than the enum and the state variable: the variable's setter, the `state_changed` signal, and two helper variables (the state it came from, and when the current one began). The code box in the States window showed only the enum and the variable, so a hand-written file gained lines nobody had been shown. It now shows the whole set, in the order the file will hold it. A script that already has states shows no extra lines, because renaming or removing a state writes none.

### Changed: Migrate lists the two retired on-screen rows, to be replaced by hand

Is On-Screen and Is Outside Screen were retired because they test the window rectangle, which is wrong as soon as a camera moves. Migrate used to skip them without a word, since neither has a newer row that means the same thing. They are now listed under the rows it leaves alone, with the reason: the row was retired and a replacement is picked by hand. Nothing is rewritten and nothing is forwarded on its own, so the point value the old row held is never dropped by accident.

### Added: play one card, or play from a card down, without running the game

Every juice card head now has a play mark. Press it and that one card plays alone, on the real object, in the editor (whether or not its box is ticked), and the mark turns into a stop mark while it sounds. The menu of a card gains Play from here, which plays that card and everything under it, so you can work on the end of a long list without sitting through the start. Play under the list still plays everything. A card that is sounding during any play lights its own mark, and Repeat and Try at strength apply to a part played this way as they do to the whole list.

### Changed: trying a Juice Player's list in the editor is honest about what it plays, and puts everything back

Play under the list now plays what Godot can play for real (a shake, a punch, a tweened property and, new, a Sound card, heard through the editor's own audio), shows the waits and the two time cards (Hitstop, Slowmo) as time, and names what it skips: a flash, a zoom and the screen effects are drawn by the running game, a signal runs your own code and another Juice Player runs its own list. Debug view gains one line under the timeline for each card saying which of those it is. Everything a preview moves is written down before it starts, and now includes every property a Tween Property card names (it used to put back only the object's position, rotation, scale and colour); it is put back on Stop, on Restore, at the end of each pass and when the editor saves or runs the scene, so a scene saved in the middle of a preview never keeps a half-played value. Two new lines under the buttons: Repeat plays the list again each time it ends and reads the list as it is then, so a number you change is the number the next pass uses; Try at strength plays at any strength, and is the same number the toolbar's "at" box sets. The toolbar box no longer writes the Juice Player's saved Strength.

### Changed: the Juice Player's play buttons sit under the list they play

The strip with the head line (how many cards and how long the beat is), Play, Stop, Skip, Restore, Debug view, Save as file and Load from file used to sit at the very top of the Inspector, above even the Acts On field. It now sits directly under the cards and the Add card button, and its head line counts the list as you edit it instead of only when the node is first selected. The buttons and what they do are the same.

### Added: a family tile on each juice card, and the Add box says Sound, Object, Camera, Screen, Time and Flow

Each card on a Juice Player's list now shows a small square in the colour of its family, the way a variable row shows its type, so a Sound card and a Camera card no longer look alike when eight cards are folded. A light editor gets a darker value of each colour so every tile reads against the card line. The Add box headings wear the same tile and read Sound, Scene, Object, Device, Camera, Screen, Time and Flow, in that order; Loop and Signal cards are both Flow, and Tween Property sits with the Object cards. These are words people read: a card is still saved and muted by the family word it always had (`audio`, `transform`, `camera`, `screen`, `pause`, `loop`, `signal`), and no saved scene changes. The Drawing Prefab list draws no tile.

### Added: a Sound card for the Juice Player

A hit is a sound as much as a shake, and until now the sound sat outside the list: the list could not mute it, retime it or play it when you pressed Play in the editor. The Add box now offers a Sound card. Pick the sound with Godot's own resource picker (the card keeps the file's uid, so it follows the file when you move it), then set the Volume and a Random volume, the Pitch and a Random pitch (each play lands somewhere between the two ends, and a grey line says where), the Bus (read from the project's audio buses), whether it is heard from this object or everywhere, whether it follows the play strength, and an optional Delay. The Listen row on the card plays that one card alone in the editor with a new random pitch each press, shows how long it lasts, and a second press stops it. In the game the card plays through four reusable voices on the Juice Player, so a fast run of hits does not make a node each, and it is muted with the Sound family. A card with no sound, or whose sound has gone from the project, says so in quiet amber and plays nothing. The card's length is the sound's length at its pitch, so the head line, the badge and Hold all count it. Save as file names a Sound card it leaves out, as it does for the other cards a moment file cannot hold.

### Fixed: a new Hitstop, Slowmo or Zoom card does something the moment it is added

A new juice card used to start at an amount of 1 and a length of 0 whatever its kind. For Hitstop the amount is the time scale it freezes to, so a new one froze nothing; a new Slowmo never slowed anything; and a new Zoom card zoomed the camera out to its floor, because its amount is a percentage. A new Hitstop card now freezes time completely for 0.08 s, a new Slowmo slows to 0.3 for 0.3 s and a new Zoom zooms in to 110 percent over 0.2 s. Cards already in a list keep the numbers they were saved with. The Amount help on the Moment Step row now reads the right way round (0 is a full stop).

### Changed: muting a family of juice cards no longer shortens the beat

Mute Juice Family used to take every card of the family out of the list, and Pause and Hold are in the Time family, so muting it removed the waits as well and the rest of the beat came early. A muted family now silences only what is felt: a Pause, a Hold and the two loop cards keep waiting, so a list is as long with the switch on as with it off. If you relied on the old shorter beat, delete the Pause card or shorten it. Tween Property now belongs to the Object family in the game (it already did in the Inspector), so muting "transform" mutes it too, and the card that plays another Juice Player is a Flow card in the Inspector as it is in the game. The words the Mute row takes are unchanged.

### Fixed: two editors open, or the Doctor and Migrate at once, can no longer make a good sheet look broken

Migrate's plan and the Doctor's stale-output check used to write a trial compile into a file with a fixed name in the project's user folder, and read the write's success as the answer. Every Godot editor, headless run or second copy of a project with the same name shares that one folder, so a second one writing the same name at the same moment made a good row ask a question it had no reason to ask (the file "refuses" it) and made the Doctor say "Sheet no longer compiles: Could not write ..." about a sheet that compiles. Both now ask the compiler for the text alone, which writes no file, so there is nothing left to collide on and nothing left behind in the user folder.

### Changed: Add Event keeps a door to the full list

Add Event on the toolbar still opens on the short object page. That page now starts with one plain entry, Browse every row, which opens the full list with Favourites and Recent beside it, exactly as the toolbar opened it before, with no typing. A regression test pins the other half of the same change: a row on the open sheet follows its sentence at once after the sentence is changed.

### Changed: a pack's lines reopen as its rows whatever the values are

A line a pack teaches (`$JuicePlayer.set_feedback_label("shake", "big shake")`) used to reopen as its row only when each value looked like the example it was taught from. The pack-spelling door now also takes a text with spaces or brackets in it, a variable where the example has a quoted word or a quoted literal (`enable_feedback(my_label)`, `load_moment_file(my_path)`), and an argument that holds commas and brackets of its own (`Vector2(1, 2)`, `[1, 2]`, `{"a": 1}`). The file still saves back byte for byte: the row keeps the line as written, and a spelling the byte gate cannot reproduce keeps its plain reading. The Juice Player test now reopens every action and condition from its real starting values, from a variable and from a comma value, on both node names.

### Fixed: a Building row in a tool sheet works in the running game

A Building row dropped into a tool sheet built under `get_tree().edited_scene_root`, which is null when the same script runs in the game, so Add New Node called `add_child` on null and Remove What This Sheet Built read `get_children()` on null. The tool row now starts under `get_tree().edited_scene_root if Engine.is_editor_hint() else get_tree().current_scene`, read once into a local (`var __scene_<id>: Node = ...`) that the lines below use, so the editor builds in the edited scene and the game builds in the running scene exactly as a plain sheet's row does. Remove What This Sheet Built is baked the same way when dropped in a tool sheet, and "Clear what it built first" writes it that way. A parent you chose is left as you wrote it. A tool sheet saved by an earlier unreleased build reopens and saves byte for byte, its old line unchanged.

### Fixed: a scene the editor saved is read for its scripts

The scene reader looked up an attribute by its key anywhere in the header, so `id="` matched inside `uid="` and every `ext_resource` of a scene the editor had saved was filed under its uid instead of its id. Every fact that asks which node wears which script (the lights, the materials, the connections and now the Juice Players) saw no script at all on such a scene. A key now has to start after a space.

### Fixed: a node wearing the old name gets its Edit Event Sheet button back

The Inspector's "Edit Event Sheet" button asked only the script a node wears, and the old FeedbackPlayer's script is now a thin stub that holds no sheet, so the button vanished on every old node. It now asks the script a node wears and then each script it extends, so an old node opens the Juice Player's own sheet, as a new one does.

### Changed: every Juice Player action and condition reopens as its own row

Opening a script that holds `$FeedbackPlayer.enable_feedback("hit")` or `$JuicePlayer.set_feedback_chance("kick", 25.0)` now reads each line as the Juice Player row it is (Enable Juice Card, Set Juice Card Chance, ... and the five questions such as Has Juice Card), with the pack's icon and sentence, instead of a plain method call. This covers every action and condition on both node names; only the file's reading changes and it is written back byte for byte. A label that is not a plain word (it holds a space), a value that is a variable and a call on any other node read as before. A scene that holds a Juice Player under another name (`HitJuice`) and runs the script also makes `$HitJuice.play(1.0)` read as Play Juice, so what Play Juice writes into a sheet reads as Play Juice again when the sheet is reopened; with no scene, or a node the scene does not hold, the line reads as it did. Expressions are values inside other rows, triggers are signals the file connects, and the For Each Juice Card loop is a `for` over a call, so those are not rows a line can name.

### Fixed: two inner members of the Juice Player are no longer rows in the picker

"Play Feedbacks From Channel" (what a channel broadcast calls) and the private resume signal showed up as rows to place. Both are hidden from the picker and search now. A sheet that already holds a row with one of them opens and compiles the same line.

### Fixed: a node that wears a script extending another still draws its base class's Inspector decoration

The header, info line and look a script gives a variable (`# @inspector_header`, `# @inspector_info`, `# @inspector_look`) were read from the script the node wears and from nowhere else, so a node wearing a thin subclass lost them: an old scene's FeedbackPlayer, which now only extends JuicePlayer, showed no "Juice Player" header over its list and drew its direction and while-playing choices as plain dropdowns instead of toggle rows. The Inspector now asks the script a node wears first and then each script it extends.

### Changed: the Inspector strip, the toolbar, the finding and the Doctor say Juice Player

Under a Juice Player's list the strip reads "3 juice cards - 1.20 s total" (and "1 juice card"), the toolbar's list segment is called "Juice" and its Open button selects "the Juice Player this row is about", the step window is titled "Juice card", the quiet finding on a row says "This row names a juice card called ..., and no Juice Player in ... has one", and the Doctor's section reads "Juice Players: N sheet(s) play a beat through a Juice Player ...". The warnings the node prints say "Juice Player:". Only words changed: the Doctor check and the finding keep the ids they always had.

### Changed: the Feedback Player is now the Juice Player, and its rows say "juice"

The node that holds a list of effects belongs to the Juice pack, so it now reads as part of it. The node is the **Juice Player**, the list is "juice" (Play Juice, Stop Juice, On Juice Started, Juice Duration) and one entry in it is a **juice card** (Add Juice Card, Enable Juice Card, On Juice Card Started, Juice Card Count). A few names say a little more than the rule gives so they cannot be mistaken for something else: Play Juice Backwards, Play Juice On Channel, Rename Juice Card, Clear Juice Cards, Copy Juice Cards From, Set Juice Player Strength, Set Juice Player Cooldown, Mute Juice Family, Scale Juice Timing, Pick One Juice Card Starting With and For Each Juice Card. The picker section is "Juice Player", the guide is Juice Player (a project that still holds the older copy of the pack opens the same page from its old "Feedback Player" section), and a Juice node does one effect when a row asks while a Juice Player plays a list of them. A placed row reads under JuicePlayer in the object column and "Juice Player" beside its name in the picker (the id the row was saved under, `FeedbackPlayer`, never changes). A new Play Juice On Channel row starts on the group `juice_players`. Searching "feedback" in the picker and in the manual still finds it.

Nothing you saved changes: every row keeps its id and writes the same code, a script written by the plugin reopens and saves byte for byte, and scenes and moment files load as before.

### Fixed: a Juice Player line you wrote reopens as its own row, not as Play Sound

Opening a script that holds `$FeedbackPlayer.play(0.6)` (or `$JuicePlayer.play(1.0)`, `.stop()`, `await ....play_and_wait(1.0)`) used to read the line as the built-in "Play Sound", "Stop Sound" or "Await Signal" rows: the file was always written back exactly, but the sentence was wrong. They now read as Play Juice, Stop Juice and Play Juice And Wait. The pack teaches these three lines to the reader (a node written by name, never any node: `$AudioStreamPlayer.play(0.5)` is still a sound), and saving writes your file back byte for byte. A Juice Player with any other name still reads as it did.

### Changed: a row from a behaviour pack starts on the node in your scene that wears it

Rows from a shipped pack (the Juice Player's Play Juice, a Health row, and the rest) used to start on a node named after the pack's class, so a node you had called something else got rows that failed at run time with "node not found" until you retargeted each one. Now "On node" starts on the one node of the open scene whose script is the pack's (or extends it), and stays on the class name when none or several do. Rows already placed are untouched.

### Changed: the Feedback Player's code now lives in a Juice Player file

The node that holds a list of effects is now the class `JuicePlayer` (`juice_player.gd`, in the Juice pack). The old class `FeedbackPlayer` is still there, at the same path with the same id, and only extends it, so a scene that already has a FeedbackPlayer node loads, plays and saves exactly as before, and a script of yours that names `FeedbackPlayer` (as a type, in `is`, or with `.new()`) still compiles, and still reaches its constants and statics. A node you add from now on is a JuicePlayer: it is not `is FeedbackPlayer`, so a variable typed `FeedbackPlayer` will not hold it. Change that type to `JuicePlayer`, which the old nodes also are. Create Node lists both, the old one nested under the new one and described as the old name. The rows keep their ids and the code they write; a new row's "On node" starts on `$JuicePlayer`, the name a new node gets. The Inspector strip, the toolbar's list buttons, the unknown-card finding and the Doctor recognise both names, and the strip class no longer shows in Create Node.

### Added: a script can keep the name its rows were saved under

A script can say `## @ace_provider_id(OldName)` above its `class_name`. Rows saved under the old class name keep finding the script's vocabulary when the class is renamed, the old name still opens the script from a row, and the line is written and read back byte for byte like the other header words. Leave it out and nothing changes: the class name is the provider, as before.

### Changed: the toolbar's Add Event opens on the objects first

Add Event on the toolbar now opens the picker on its object page, the same page a double click on empty canvas opened: "Your classes", the open script's Functions, System, and Objects and Behaviors. Before, it opened the full list of every object's conditions and triggers at once. Pick a card to see that object's verbs, or start typing: the search box looks across every object at once, exactly like the old full list narrowed to what you typed. The "All objects" button above a card's list brings the cards back. Add Condition and Add Action are unchanged. The E key opens the type-a-sentence box, whose Ctrl+Enter opens the same page, and the "+ Add event" link on the canvas opens the full list.

### Fixed: a row follows the sentence you just wrote

Changing how a function reads (the box, the scripts window) now drops the readings kept from the old file and reads the rows again, so a call row on the open sheet shows the new sentence at once instead of after a reopen. "Change how this reads…" also works on a call written in a script (a Call Method row) when exactly one project class declares that function. Use in event sheets on a script whose functions are static and which has no class_name says so in the status line instead of reporting zero rows added, and the scripts window opens taller so its list is not cut, says its hint once, and its notes carry no markdown.

### Changed: the guides match the code

The custom-actions guides now describe the Scripts in event sheets window, Use in event sheets, how a function reads, and "This sheet in other sheets"; the score example names (Add To Score, Winning), the "Your classes" heading and the "Other sheets can use this" tick are spelled as the editor spells them, and the stale provider-table picture is gone. The reading check no longer recommends a sentence inside the name word or a positional parameter label.

### Fixed: a row of your script reads the same in the picker, the parameters window and the canvas

A function whose script wrote a sentence and no name ("Take {amount} damage") now reads as that sentence in the picker row and the parameters window's title (each slot as a gap), not as the name made from the function; the window's head names your class instead of the open sheet's object ("System"); and the toolbar's Add Event opens on the objects first, like a double click on empty canvas, so "Your classes" is offered there too.

### Added: F2 on a function head says how the function reads in other sheets

With a function's head selected, F2 opens a box with the sentence the function reads as in other sheets, its description and "Other sheets can use this". Done writes all three onto the function as one undo step. The name stays where it was (double-click the head), because renaming changes what every call means.

### Changed: a named sheet's new function starts shared, and "Teach a Verb" is "This sheet in other sheets…"

The New Function window's tick now reads "Other sheets can use this" and starts ticked on a sheet that has a class name (another sheet can only reach a node it can name); an unnamed sheet's starts unticked as before. Only the starting state changed: old sheets, the resource default and every emitted byte are as they were. The Sheet menu entry that shared a sheet's published functions is now "This sheet in other sheets…", with plain status lines, and a sheet with no class name is told so with a door to Sheet Type.

### Added: "How should this read?" for a function of a script of yours

Right-click a placed row that comes from a script of yours and choose "Change how this reads…" (or press F2 on its row in the picker, or press Enter or F2 on a row in the scripts window): a small box shows the sentence, what it reads as with the row's starting values, and names a slot the function does not have. Done writes `## @ace_display_template` above the function after a backup, and every row that uses it follows. A row of a shipped behaviour never writes anything: the box says it belongs to the behaviour and offers to open it, and a script with changes not yet saved in Godot's script editor is refused until it is saved.

### Added: "Use in event sheets" on a script in the FileSystem

Right-click a script of yours in the FileSystem and one entry gives every sheet rows from it with no setup: it writes the path into the taught-scripts setting (which now holds scripts as well as compiled sheets) and the status line says how many rows it added. Once a script is in use, or when it lists itself (a Node or Resource script with a class_name, an autoload), the entry reads "Use in event sheets…" and opens its window. A shipped behaviour, the plugin's own files and scenes are never offered. Resource scripts with a class_name now list themselves in the picker's cards.

### Changed: one window for what a script of yours gives sheets

Sheet > Custom Actions now opens "Scripts in event sheets": the scripts a sheet reads, and for the one you pick, every row it gives as a plain sentence with a tick. Unticking writes `## @ace_hidden` above the member after a backup; a member the script already leaves out is listed as "left out" so it can be ticked back, and ticking it again keeps every other word the script wrote (hiding no longer drops them). Each row carries the sentence and the line of its function, and "Go to the line" opens Godot's script editor there. The old table with Kind, Name, Category and Parameters columns, Register This Script and Curate Script are gone; Keep Old Name stays for a renamed function.

### Fixed: curating a script never writes a file the plugin ships

The public curate call refuses a script under `addons/` or in a shipped behaviour folder, with a plain reason, and writes nothing (no backup either). A script of yours is written as before.

### Fixed: the Theme Editor does what its window says

A second open now edits the theme you opened (its swatches had stayed tied to the first one, so a change drew nothing and saved nothing), and its Quick Style colours start from the open theme instead of fixed dark ones. The Dyslexia-friendly tick and the Reading font no longer write the unsaved workbench theme into your open sheet. Applying the editor's copy no longer ticks Match Editor in the theme menu. The eleven swatches that drove nothing are no longer listed (a theme file that names them still loads and saves them). Each row reads in plain words, the way Godot's Inspector spells a property ("Follow Editor Greys"); the strip at the foot still gives the exact field name and the line a save writes. Descriptions say Section where the sheet does, the debugger accent names the Trail tab it tints, and the amber token says it colours every finding. The preview is wide enough for "On process" to read whole.

### Fixed: three windows no longer cut their words short

The Variable window wraps the annotation a look writes instead of trailing off, reads a long hint under its box instead of a cut-off placeholder, and starts "Add row" at the left of a wide table in the Inspector preview. The Class window wraps the reason a member would be lost ("Control does not have it"). Migrate wraps a long line of code, names a row with no stored sentence by its verb ("Set Sprite Size", not its id) and, when the old and the new row read the same, says which row it becomes.

### Fixed: a wide table in the Variable window's Inspector preview, and the status bar after a theme switch

The preview card now draws a table with many columns smaller to fit (down to a readable floor), so every column and Add row can be read without a sideways scroll; only a table wider than that scrolls. Switching theme repaints the status bar's counts at once (they kept the old theme's colours until the next edit), and a translucent word there is judged as it shows on the panel. Comments on the theme's own band and the margin numbers also read at 4.5 to 1 on every shipped theme.

### Fixed: the sheet reads in a dark and a light editor, and a light sheet in a dark editor (and the reverse)

Editor Native's quiet words, the gutter numbers and the amber of every finding now read at 4.5 to 1 on the sheet, a row and a head bar, in both hands. The code beside a variable row keeps the sheet theme's colours when the sheet and the editor are different brightness. The status bar's words and the finding sentence use a font colour moved until it reads on the editor's panel, instead of a modulate over the editor's own text. Run counts, the margin number after a run, live values and a coloured comment's words take the theme's own colours (no new theme fields) and read on their ground. The parameter hint's coloured outline is gone (the edited value is marked by a wash) and its chip takes the drag bubble's colours. The plugin now has one contrast formula, and the ink mover steps finely so amber stays amber.

### Fixed: Set Size, Set Width and Set Height size a sprite by the frame it draws

Set Sprite Size divided by the whole picture, so a sprite sheet or a region came out the wrong size (a 4 x 2 sheet asked for 64 x 64 measured 16 x 32; a region measured 8 x 4), a sprite with no picture stopped with an error, and "On node" divided by this node's picture instead of the other sprite's. Three new rows, Set Size, Set Width and Set Height, divide by the frame that is drawn, take "On node" on every member of the line, and leave a sprite with no picture as it is. Set Sprite Size keeps writing exactly the line it always did, so existing scripts compile and reopen byte for byte; it is retired from the picker, and Migrate moves a row of it onto Set Size without asking, keeping its size and node.

### Fixed: Attach to Node works on a behaviour sheet that is a script

The check asked for a resource path, which a script sheet (the default format) never has, so Attach saved the sheet and then said "Save the sheet first" - and attached nothing. It now attaches the sheet's own file. A script sheet whose Save only failed to write the file now says that alone, instead of "fix the error".

### Added: a run-time error from a sheet that is not open offers to open it

An error from the running game finds its row only in a sheet open in a tab; one from any other script got its sentence and no address. The strip's button now says "Open the sheet" for a project script no tab holds, opens it and then finds the row, as it would have if the tab had been there.

### Fixed: a sheet saved as a resource gets the "changed outside the editor" question too

A `.tres` sheet changed by a merge or another tool, with its tab open and unsaved, was written over by the next Save. It now asks, the way a script sheet always has: keep yours (the default) or use the file on disk, and taking the disk's version first puts your unsaved one into Sheet Backups. (What Changed is only offered for a script sheet.)

### Fixed: a refused autoload name leaves no script behind

Registering a sheet as an autoload compiled and wrote its script before checking whether the name was taken, so the refusal left a fresh file in the project. The name is checked first.

### Changed: the Save System keeps two earlier versions of a save by default

`backup_count` was 0, so a save that was written perfectly and was wrong (a bug that zeroed the wallet) had no earlier copy. It is now 2. Set it to 0 to turn backups off; a scene that already sets it keeps its value.

### Fixed: Save Studio's "Keep them in a scene" never writes over a file of that name

It wrote `res://save_system.tscn` without looking, replaced whatever was there and re-pointed the SaveSystem global with no undo. It now refuses by name when a file is there (unless the global already runs it), and says that Undo does not cover the change and how to go back.

### Changed: Write Text File says what happens when the file cannot be opened

The row does nothing, and says nothing, when its folder is not there or the place is read-only (`res://` in an exported game). Its template keeps its bytes; its help now says so, and points to Write Text File (in a folder) for a folder that may not exist yet.

### Fixed: a behaviour your own addon uses no longer shows as "unused"

"Used by" in the behaviour library and Tidy behaviours skipped every folder under `addons/`, so a pack that one of your own addons reached for read as unused and was ticked for removal. It now reads your addons and leaves out only this plugin's own folders.

### Fixed: a script sheet whose saved script Godot cannot compile takes you to the row

A sheet saved as a resource already jumped to the row that did not compile; a script sheet only said the row was marked. Both now select the row the first failing line came from, and a script sheet whose save could not write also marks the rows the check found.

### Fixed: "Failed to open output path" now says why and what to do

The message named a path and no cause. It now says the file may be read-only, open in another program or held by a cloud-sync tool, that nothing was overwritten (the old file is exactly as it was), and to close what has it open and save again.

### Fixed: a file Godot would not write is told in words, not as a number

About twenty messages used to end in "(error 31)": a failed Save (which did not name the file), Save Studio's scene and slot copies, Export, the Test Bench, the data tables, the Ask window, the Quality Presets pack and the MCP and API write doors. Each now says what failed, names the file, gives Godot's own words for the cause and says what to try next, in all eight languages.

### Fixed: EventSheets.edit() is all or nothing

- An edit whose callable hit a script error used to leave its half-change in the open sheet with no undo step to take it back, and an `edit()` started from inside another edit's callable silently lost one of the two writes. Now a callable that hits a script error leaves the sheet exactly as it was, adds no undo step, says so on the status line and `edit()` returns false; and an `edit()` called from inside another edit is refused with a plain line on the status line (nothing is applied, `false` comes back), because the outer step cannot honestly hold two. A clean edit is still one undo step.

### Changed: EventSheets.compile() says what it writes, and EventSheets.echo() reads without writing

- `EventSheets.compile(sheet)` with no path always wrote a file and nothing said so: on a sheet opened from a `.gd` it overwrote that script with no backup (unsaved edits and all), and on a sheet with no file it dropped `res://event_sheet_generated.gd` into the project. It keeps its shape and its result keys, and now: with a path it writes that path as before; with no path on a sheet that has a file it takes the same backup a Save takes before it overwrites (restore it from Tools > Sheet Backups); with no path on a sheet with no file it writes nothing and returns a warning in `"warnings"` (the text is still in `"output"`). The docstring and the guide say which call writes.
- New `EventSheets.echo(sheet)` returns the same result Dictionary and never writes a file, for showing code, counting lines or pinning an output string in a test. The Building on EventSheets guide's codegen snippet and its team-pin example now use it.

### Fixed: a block whose pack was removed draws as a quiet row instead of disappearing

- When a behaviour pack was removed, a sheet saved as a `.tres` file still holds that pack's block rows, and the editor raised a script error on every redraw and left the row out of the sheet. The row now draws as a plain "block" chip beside the kind id in the muted ink, in the dark and the light editor theme, and the rows around it are unaffected. No widget and no outline: it is the same quiet chip the preload row wears.

### Fixed: a block that cannot be written is no longer dropped without a word

- A block row whose kind is not registered (its behaviour pack was removed, which a sheet saved as a `.tres` file can still hold) or whose emit code hits an error used to vanish from the compiled script while the compile reported success, so a saved script quietly lacked a line the sheet still held. The compile now fails with a message naming the kind and what the row holds, adds the same words to its warnings, and leaves the file it would have overwritten as it was. A `.tres` row keeps only the kind id and its fields, never the emitted line, so there is nothing to keep verbatim: the message tells the author to put the pack back or delete the row. Sheets opened from a `.gd` file are not affected - their lines stay a verbatim block when a kind is missing.

### Fixed: a plugin can no longer take over a built-in block kind

- A block kind registered before the editor had asked for anything (an editor plugin does this when it loads) used to be filed first, so a kind named `preload`, `region`, `enum`, `signal` or `moment` replaced the built-in one and the built-in was the one ignored: the user's preload line then came out as the other kind's text. Registering a block kind now builds the built-in kinds first and refuses a built-in id with a plain warning that names the id and suggests a `<pack>.<name>` id. A repeated id still keeps the first registration, and a kind with an ordinary id registers as before.

### Fixed: a custom block kind can no longer corrupt a file it lifts

- A block kind that hands the importer a ready-made row instead of a field table used to skip the check every other lift passes: opening a `.gd` file asked the kind for a row and trusted it, so a kind whose row did not re-emit the line it had claimed changed the file on save (in one case writing `extends Node` twice). That claim now goes through the same byte check. The kind's own emitted lines must reproduce the lines it consumed exactly, or the claim is dropped and the lines stay a verbatim block, so opening and saving a file untouched still gives the same bytes whatever kinds are installed.

### Fixed: changing one object's feedback no longer changes every copy of its scene

- Objects made from one scene all started out sharing the same feedback cards, so a row that changed a card on one of them (Set Feedback Field, Set Feedback Timing, Set Feedback Chance, Set Feedback Label, Enable or Disable Feedback, Set Loop Count, Scale Feedback Amounts, Retime Feedbacks or Pick One Feedback Of) changed it on all of them, and on every one spawned afterwards for the rest of the run. One Scale Feedback Amounts row per spawned enemy kept halving them all. A Feedback Player now takes its own copy of its cards the first time a row changes one, so each object keeps its own beat. A player no row changes copies nothing, and nothing in a saved scene changes: the copy is made while the game runs, never when a scene loads or saves. Copy Feedbacks From, Load Moment File and Duplicate Feedback still do what their descriptions say.

### Fixed: movement packs under a rigid body now say what will go wrong

- A pack that moves its node by writing its position or scale every frame fights the physics engine when that node is a RigidBody2D or RigidBody3D: the body jitters, snaps back or passes through walls, and nothing said why. Each such pack now pushes one plain warning (Debugger, Errors tab) when it becomes ready under a rigid body, naming the node, what the pack changes and what to put it on instead. What the packs do is unchanged. Each pack's guide says the same in its tips.
- Gliding, following and orbiting: Move To, Move To 3D, Follow, Follow Path, Orbit, Orbit 3D and Tile Movement.
- Waves, springs and juice: Sine, Sine 3D, Spring and Juice.
- Holding a node in place: Bound To, Pin, Pin 3D, Home Leash and Checkpoint.
- Bullets, dragging, wrapping and flocking: Bullet, Bullet 3D, Drag Drop, Wrap, Flock and Flock 3D. That makes 22 packs in all; the camera rails, Targeting 3D (which only turns its node) and the character-body packs cannot meet the problem or do not move the node.

### Added: three classic Godot mistakes now show on the row that makes them

- Three things Godot's own manual warns about used to pass in silence: the sheet compiled and the game only misbehaved. A row that meets one now turns quiet amber (no outline, no widget in the row), and the help strip under the selected row says what is wrong and what to use instead. Each also appears in the Project Doctor under its own check name.
- A Control inside a Container: a row that sets the position of a Control whose parent is a VBoxContainer, HBoxContainer, GridContainer or another arranging Container. The Container puts its children back the next time it arranges them, so the row seems to do nothing. The strip suggests a plain Control as the parent, or the Container's own settings and the Control's size flags. It matches the line a row writes, so it holds for Set Control Position, Set Position and a hand-written `position = ...` alike.
- A Tween on a physics body: a Tween Property row (or a `tween_property` line) on the position, global position or scale of a RigidBody2D or RigidBody3D. The physics engine moves the body every frame and fights the Tween. The strip suggests tweening a child node, moving the body with Apply Central Impulse, or turning on Freeze first.
- A behaviour that fights a physics body: a behaviour sheet that writes its host's position or scale, placed in a scene under a RigidBody2D or RigidBody3D. The strip names the body and suggests a node that is not a physics body, or Apply Central Impulse.
- Only a real scene counts as evidence. A sheet no scene runs, a node held in a variable, a node inside an instanced scene, and the base Container class (which arranges nothing) earn nothing. A CharacterBody and an AnimatableBody, which code moves on purpose, earn nothing. A behaviour told to act on another node is not judged by what it sits under.

### Fixed: a pack action given a name that does not exist now says so, once

- Many packs keep things by name (abilities, pools, quests, rooms, buffs). An action given a name that did not exist returned without a word, so a mistyped `dash` for `Dash` looked exactly like a row that ran. Each such action now pushes one plain warning (Debugger, Errors tab) naming the node, the row as the sheet words it, the name that was not found, the names that do exist and what to do next. It is said once per missing name per node, never every frame, and the action still does nothing.
- Simple Abilities: Activate Ability, Set Ability Cooldown, Reset Cooldown, Set Max Stacks, Set Stacks, Add Stacks, Consume Ability Stack, Set Ability Enabled, Set Ability Active, Set Ability Data, Add Tag, Remove Tag, Clear All Tags, Remove Ability and Remove Ability After Duration.
- Object Pool (which had no warnings at all): Add To Pool, Prewarm, Despawn All, Clear Pool, Spawn and Spawn Safely given a pool that does not exist; Create Pool when the scene path does not load (the pool is still made, with no scene, and later Spawn rows return nothing); Prewarm of a pool made with Create Empty Pool.
- Quest: Advance Objective (a quest nobody registered, a quest registered but not started, or an objective the quest does not have) and Abandon Quest. A quest that already finished is still advanced or abandoned quietly.
- ProcRoom: Enter Room, Force Enter Room, Lock Room, Unlock Room and Reveal Room given a room that does not exist.
- Utility Brain: Add Consideration, Set Action Enabled and Force Action given an action that was never added.
- Milestones: Update Progress, Set Threshold and Force Reach on an id nobody defined now say that they made a new milestone with a target of 0 (a misspelled id used to latch at once, unseen).
- Stat Forge: Set Buff Active, Set Buff Value, Refresh Buff, Set Buff Timer Paused and Re-Arm Threshold Rule. Remove Buff stays quiet: removing a buff that is already gone is its documented normal case.
- Second View: Show View In and Set View Zoom already warned, on every call and without naming the node; they now say it once and name the node, the view and the views that exist.
- Combo Box: Set Combo Tags, Set Combo Priority, Set Combo Strict, Enable Combo and Disable Combo.
- Drunken Walkers: every row that names a walker (the Set Walker rows, Run Walker, Step Walker, Drop Marks Along Walk) and Add Walker From Preset with a recipe that does not exist. These warned only with Debug Mode ticked, which a newcomer does not know to do; they now say it once in every run.
- Advanced Random: Shuffle Bag Pick for a bag nobody made.

### Fixed: the Project Doctor reads your `.gd` sheets, not only the `.tres` ones

- `.gd` is the default sheet format, but about twenty of the Doctor's checks were handed `.tres` sheets only, so in a project of scripts they said nothing and gave no sign they had not looked. They now read the project's own scripts as well: debug code left in, a script no scene or other script uses, editor tools that reach the editor's own tree, work in a thread that touches nodes, private variables nothing reads, a script driving many nodes, fragile `../../` paths, a loop run every frame, a wait inside a per-frame event, notes that are pasted engine errors, an unpaired `#region`, a variable that shadows an engine member (an error: Godot cannot load it), and the pattern notes.
- One note now opens the report and says how many `.gd` and `.tres` sheets the checks read, and which checks do not apply to a script and why: generated outputs, autoload registration, duplicated globals, every-tick setup and the tidiness notes.
- Variables are read wherever the sheet keeps them. A `.gd` keeps each one as a row among its events, which the unused-variable, shadowed-variable and save-support checks did not look at.
- Two checks stop accusing lines that are fine. A loop in an event that has a condition of its own is no longer called an every-frame loop (the condition may be a key press or a once flag), and a line that slides a node to a stop (`$Lantern.position.y = minf(..., 620.0)`) is no longer called a meter that never drains. A name a line declares itself (a local, a parameter, a loop's item) is no longer called "not a variable". In a script, a constant is a public offer and is not called dead, and a name the parent class has as a method (`set_name` on a Resource) is not called a shadow: Godot loads such a script, so only a script the engine refuses to load is accused.

### Fixed: Run now, Reload, Enable plugin and Attach to node save the sheet the way Save does

- With edits not saved yet, these four wrote the sheet's script straight to disk: no backup of the version before and the tab still marked unsaved. They now make the same save as the Save button first, so the version before is in Tools > Sheet Backups and the tab is clean, as when Godot saves a scene before it runs. A sheet that was never saved opens Save As and the command waits.

### Fixed: while a file opens, the Code button no longer gets a coloured ring

- The button took a 1 px accent outline while a script opened. It now takes its own hover fill, with no outline, and goes back when the open ends.

### Fixed: typing a new "extends" in the Class window no longer writes your script

- The Class window reads the sheet's code to warn about members the new base does not have. It did that with a compile that also wrote the sheet's file, so typing in the Extends field put your unsaved row edits on disk with no save, no backup and no undo. It now only reads. Apply is still one undo step and the file changes when you save, with the usual backup.
- Opening a script that the engine reports a parse error in no longer rewrites its file while it marks the rows (same cause, same fix).

### Fixed: an object's name on the sheet is read whole when the row has room for it

- A long class name in a condition or an action ("ScriptRowsAnnotatedTwin") was cut to "ScriptRowsAnnotatedT..." in a lane with a thousand pixels to spare, because the object column was one fixed width. The column now grows to the widest object name of its lane, up to half the lane; only a lane that is truly short elides a name. A sheet with short names looks as before. Only the drawing changed: no row's words moved.
- The size the first open of the editor is allowed to compile (the closure budget in the test suite) is raised by 10 lines, for the one function that measures the names.

### Fixed: the Variable window keeps its width for a long hint, and its code line breaks at a comma

- A variable with a long hint (a table look with many columns) made the Variable window grow sideways, from about 1050 px to 1470 px and more, because the Inspector preview under the code line asked for the whole width of its table. The preview now scrolls sideways inside its card, so the window keeps the width it opened at.
- The IN CODE line split a long quoted hint in the middle of a word ("Stri" and "ng"). It now breaks after a comma or an opening bracket. The line the window reads, and the code the variable writes, are unchanged: only the way the line is drawn has break points.

### Fixed: the Rename window no longer lists the plugin's own behaviours as callers of your variable

- Renaming a variable such as `speed` listed 37 files of the behaviours that ship with the plugin, 272 rows, in "Named and left exactly as they are", only because each of them has a `speed` of its own. The name index finds a word in a row; it cannot tell whose `speed` it is. Files in a shipped behaviour folder are now listed only when their text refers to your script by its path or its class name. The sentence above the lists says how many were left out and why: "37 file(s) of the behaviours that ship with this plugin also say that name, and nothing in them refers to this script, so they are not listed." Your own files are listed as before, whatever folder they are in.

### Fixed: a number with a unit keeps its whole name in a narrow Inspector

- A property drawn as a number with a unit dropdown (a shape's Thickness) lost most of its name in a narrow Inspector, where it read "Thickn". When the Inspector is too narrow for the name and the field side by side, the field now goes under the name, so the name is read whole. A wide Inspector looks as before.

### Fixed: Add global variable says where the variable went, and Enter in the name adds it

- After Add > Global Variable made a new autoload, the line saying so ("Added global variable Score to Globals, a new autoload (see it in Project Settings > Globals > Autoload).") was replaced a moment later by "Opening globals.gd ..." and that stayed in the status bar until the next save. The variable is now added once the file has finished opening, so the line saying where to see it is the one that stays.
- Enter in the Name or Value field of the Add global variable window now presses Add, as it does in the other windows.

### Changed: the risky button of a small question is a plain button

- The risky choice of a small question (Delete anyway, Discard, Clear all, Delete the event, Use the file on disk, and Delete in the parameter window) was drawn with a red outline or red text. It is now a normal Godot button, still on the left and still never the one Enter or Esc reaches: the risk is in its words, and the plugin draws no colour or outline of its own on it.

### Fixed: a behaviour's description is read whole in the Behaviour library

- Each row of the Behaviour library cut its description off at the right edge with no sign it was cut. The lines on a row now wrap inside it and the row grows to hold them, so the whole description is read.

### Fixed: the Feedback Player's row of buttons wraps instead of widening the Inspector

- The seven buttons under the Feedback Player's list (Play, Stop, Skip, Restore, Debug view, Save as file, Load from file) sat in one row that asked for about 520 px, which pushed the Inspector to 543 px wide. They are in Godot's own wrapping row now, so the buttons drop to a second line when the Inspector is narrow and the Inspector keeps the width you gave it.

### Fixed: the Rename window no longer lists a text in quotes as if it were rewritten

- A row such as `print("speed=", speed)` was listed under "What will be rewritten" as `"speed=" -> "speed="`, a text that does not change. Only rows that really change are listed there now. A row that says the name only inside a text in quotes is listed under its own heading, "Text that mentions the name - left as it is".

### Fixed: the amber note in a window is amber in the light theme too

- A warning note in a window (the Behaviour library's "Nothing was copied" line, the parameter window's warnings) was tinted from a darkened amber that read as grey on the light theme. It now uses the same amber the sheet's quiet warning row uses, a little stronger on a light panel, with no outline. The dark theme looks as before.

### Fixed: the Toggle buttons preview shows the default choice chosen when the default is a bare word

- In the Variable window, a Toggle buttons look with a default typed as a bare word (`normal`) left every button in the Inspector preview unselected, while the code line showed the default correctly. The preview now reads that word the same way the code line does, so the default's button is shown chosen.

### Changed: the rename window no longer sends you to version control for the sheets it saved

- After a rename that also rewrote and saved other sheets that include this one, the window said "your version control can undo those", which means nothing to a project without version control. It now says what is true for everyone: each of those sheets was backed up first, and opening one and using Tools > Sheet Backups gets its old version back.

### Fixed: Save As a .tres from a .gd sheet says scenes still run the .gd, and a failed save leaves the link

- Saving a sheet that was opened from a `.gd` as a `.tres` leaves the `.gd` on disk and every scene still runs it, while the new `.tres` writes a script of its own that nothing uses yet. The status line now says so and names the script to attach: "Scenes still run mover.gd: attach mover_copy_generated.gd to use this sheet."
- The sheet's link to its `.gd` was cleared before the save was tried, so a save that failed left the tab unlinked. The link is now put back when the save fails, and the line names the file and Godot's own reason instead of a bare error number.

### Fixed: a save that Godot cannot compile now says where the version before it is

- Saving a sheet whose script Godot cannot compile still writes it (your edits are never dropped), and the status line already named the engine's words, the line and the file, and marked the row. It now ends with where the way back is: "The version before this save is in Tools > Sheet Backups."

### Fixed: renaming an exported variable keeps the values your scenes stored for it

- A scene stores the value you typed in the Inspector under the variable's name. Renaming the variable made Godot drop every such value without a word, and the next save of the scene removed it from the file. The Rename window now reads the project's scenes and resources as text (nothing is loaded) and lists the ones that store a value for an exported variable, then renames that one name on exactly those lines when you press the button. The value text is copied byte for byte, a different script's variable of the same name is never touched, a scene that only inherits the value is not rewritten, and the whole rename is still one undo step: Ctrl+Z puts the sheet and every scene back as they were. Each scene's old text is also kept in the editor's backup folder.
- Files it cannot rewrite with certainty are named in their own card with what to do: scenes saved in Godot's binary format, a scene open in the editor with unsaved changes, and a node that already stores a value under the new name. The inline name field opens the window instead of renaming straight away when scenes store a value for the variable.
- Deleting an exported variable now asks first when scenes store a value for it, names them, and writes nothing to them.
- The files a state rename or a variable rename writes in the project are now written through a temporary file and a rename, so a crash cannot leave one half-written.

### Fixed: quitting Godot, Save All and Run no longer lose a sheet's unsaved edits

- Quit Godot with an event sheet that had edits not saved yet and Godot's window said only "Save modified resources before closing?"; its Save & Quit then wrote nothing, so the edits were gone. Save All and the save Godot does before Run skipped sheets the same way. The plugin now answers Godot's own two questions, so Godot's window reads "Event sheets with changes that are not saved yet:" with each sheet named, Save & Close writes them exactly the way the Save button does (backup first, the same checks), Don't Save leaves the files as they are, and Cancel keeps the editor open. Save All and Run save them too.
- A sheet that cannot be written is named with the reason in Godot's window instead of being skipped: never saved so it has no file yet (use Save As), a file still holding merge markers, or open read-only. One that fails to save at that moment (it does not compile yet, for example) is named in the Output panel and on the sheet's status line, and it never holds the editor open: Don't Save and Cancel are always there.

### Changed: a call in an opened script reads as the sentence you wrote for the function

- When a `.gd` is opened as a sheet, each call reads through the function it goes to. If that function, in a script you wrote, carries a sentence of its own (`## @ace_display_template("Take {amount} damage")`), the row now says that sentence with the call's own values in its slots - "Take 5 damage" for `hero.take_damage(5)` - the same words the picker offered it under, kept after the file is closed and opened again. A function without a sentence, and every call to a behaviour the plugin ships, reads exactly as before.

### Fixed: a narrowed or %name card offers your script's rows on the node you picked

- The card the picker shows for a value an event narrowed (`body` after `body is an Enemy`) or a `%Name` node took the rows of your own class and aimed them at it, but only for the old optional-target call. Your class's rows now carry their own On node slot, so the card opens them on the name you picked, and the old property ids kept only for rows already placed are not offered.

### Changed: "Your classes" reads your script the way a registered script is read

- A class listed under "Your classes" was read by plain reflection while a script you registered was read by its `##` lines, so the same function came out as "Is Dead" in one place and "Dead" in the other, a variable's reader and writer had different ids, and a sentence or a name you wrote was ignored there. There is now one reading, the registered script's: its names, its kinds, the sentence you wrote with `@ace_display_template`, your categories and descriptions, a Set, Add and Subtract for each number, and the aimed calls (a Node script's functions call the node by its class, a Resource's act on the value the row names, a `static func` is called by its class).
- Nothing placed breaks. The two old property ids (`property:get:x`, `property:set:x`) stay as hidden, deprecated entries that carry the call they always carried and point at their successor, so a row you already placed keeps reading and compiles to the same bytes, and editing it keeps its call. A function you hide with `@ace_hidden` is kept for rows already placed and is not offered.
- The project's vocabulary side file still refines what the script left to inference: a rename or category written against an old id finds its verb under the new one, and anything your own `##` lines said is no longer overruled, facet by facet.

### Changed: a row from a script of yours acts on the real thing, not on a hidden copy

- A function of your own script that carries no call line used to bake to a call on a small copy of the class that the sheet kept for itself, so a row from a Node script changed an object no scene held and a row from a Resource changed a copy nobody could see. For a script you wrote (never a behaviour the plugin ships, whose rows read exactly as before):
  - a Node script's functions call the node by its class name, with an "On node" slot that starts as `$ClassName` and can be retargeted - and starts as the node itself when exactly one node of the open scene wears the script;
  - a Resource's functions and variables, and those of a plain class that holds variables, act on a value the sheet names: an "On resource" or "On object" slot that starts empty (`null`), and the row reads "Add 3 on item";
  - a `static func` is now offered, called by its class's name (it needs a `class_name`);
  - an authored call line or sentence is kept exactly as written.
- A row you already placed keeps the call it was baked with and compiles to the same bytes, and editing it keeps that call rather than swapping the hidden copy for another object. The preview's note for a Node script now says what is true.

### Fixed: confirming a row that has a number or a tick in it raised an engine error

- The parameters window let a reading lens rewrite typed text just before it was stored, and that step took only text. A spin box hands back a number and a tick a bool, so pressing Done on any row with a number or tick slot (a function with an `int` argument from your own script, say) stopped with "Cannot convert argument 2 from int to String" and the row was never added. Numbers and ticks are now stored as they are, and typed text is rewritten exactly as before.

### Fixed: saving a script you registered changes the picker at once, without a restart

- A script registered on a sheet, or a sheet shared with the project, was read into the picker when it was registered and again only when the list of such scripts changed, so a word edited on a `##` line (a new sentence, a new name) and saved in Godot's script editor left the picker on the old words until the editor was restarted. The vocabulary is now derived from each such script's saved time and length as well as its path, and the editor's filesystem ping rebuilds it when one of them moved. Writing annotations from the editor, or through `EventSheets.curate_provider`, tells Godot's filesystem about the file and rebuilds the picker straight away. A switch between two tabs whose scripts did not change still builds nothing.

### Added: lines of your script that read as nothing are named, with the line and the word you probably meant

- The `##` words above a function, signal or variable are read by exact spelling, so a word one letter off (`@ace_nmae`) is just a note, a parameter slot with a key nothing reads (`defualt:`) or no colon is dropped, and a plain `#` comment between the words and their function cuts them off, all without a sound. They are now named in a new Script Rows section of the Project Doctor, each with its line number and, where a close spelling exists, the word that was meant, and a "Go to the line" chip opens Godot's own script editor there. The same lines appear as amber notes when a script is previewed, and a function with no return type is named as reading as an action. Only scripts that put a `##` word of their own in the file are read, never a file the plugin ships, and nothing is written or loaded.
- The preview's notes now say "rows" where they said "verbs", and the Node script note says what is true: rows for variables and for functions that carry a call line act on a node named in the row's On node field.
- Corrected two false statements: `EventSheets.register_provider_script` registers on the open sheet, not project-wide, and the message after sharing a sheet's published functions no longer promises more than it does.

### Added: tests pin how a script of yours reads before the readings are unified

- Five real script files (a Node, a Resource, a class of statics, a script with no class name, and an annotated twin of the Node) are read through all three of the ways a script reaches the picker today, and the exact result - names, sentences, templates, parameters - is kept as text beside them. A later change that moves a reading now moves a visible line of that text. A second test holds the behaviour rows the showcase builder places to the vocabulary of the pack they name, listing the few that spell a baked node path. No behaviour changes.

### Fixed: a function a named sheet publishes calls the node when another sheet uses it

- A sheet that names its class and publishes a function wrote the call line as a bare `fn(args)` into its compiled script. That is a call on itself, correct in its own file, and wrong in any other sheet, where it called a function that sheet does not have even though the status message promised a call on the node. A Node script read as vocabulary now aims that exact bare call at the node by its class, so the row gets an "On node" slot defaulting to `$ClassName`. A call you qualified yourself is left as written. The compiled script is not touched, so no script or showcase file changes, and rows already placed keep the call they were baked with.

### Fixed: writing a sentence or a label into your script no longer drops the lines it did not mention

- Changing one thing about a function from the editor (its name, say) used to rewrite the whole comment block above it from only what that edit carried, so its kind, category, description and parameter lines vanished. An edit now merges: what it does not name stays, a field set to empty text is removed, and a parameter keeps its help text when only its starting value changes.
- The sentence line (`@ace_display_template`) is now a word the writer knows. It lands where the sheet compiler writes it, so a script written this way still opens as a function when you open it as a sheet and saves back byte for byte.

### Changed: Post Kit keeps each stack entry as a small class

- A post-stack entry was a dictionary read by text in about twenty places; it is now a `PostEntry` with typed fields, holding the CompositorEffect that wears it. Every verb behaves as it did, and nothing about the stack was ever saved.

### Changed: Priced Table keeps each entry as a small class

- An entry of the table was a dictionary read by text in about twenty places; it is now a `PriceEntry` with typed fields, and the id index is a typed dictionary of them. The saved state is the same record it was, written and read through the class's `to_dict` and `from_dict`: a shop saved by an older version loads with the stock, locks and prices it was left with, and saving it again gives the identical text. Rows loaded from a price table resource are read as before.

### Changed: Encounter Timeline keeps each beat as a small class

- A beat of the plan was a dictionary read by text in about twenty places; it is now a `Beat` with typed fields. The saved state is the same record it was, written and read through the class's `to_dict` and `from_dict`: a state saved by an older version loads, plays on from where it was, and saving it again gives the identical text. Rows loaded from an encounter resource are read as before.

### Changed: Screen FX keeps each stack entry as a small class

- A post-stack entry was a dictionary read by text in about thirty-five places; it is now a `PostEntry` with typed fields. Every verb behaves as it did. The effect's own dials stay a dictionary (their names are the shader's), and a look file's rows keep their shape: Save Look writes the same rows and Use Look reads them back. An entry whose rectangle was freed behind the pack's back now gets a new one instead of raising.

### Added: a test keeps the plugin's class names prefixed

- No new `class_name` may be added under `addons/eventforge/` or `addons/eventsheet/` without an `EventSheet`, `EventForge` or `ACE` prefix, because Godot keeps one list of class names per project and an unprefixed one can collide with a game's own. The 23 unprefixed names that shipped first are the allow list and are frozen; a name leaving the plugin must also leave the list.

### Added: the Doctor reports a class name your script shares with the plugin

- A script of yours whose `class_name` is one the plugin's own code or a shipped behaviour already uses is now a Doctor finding that names both files. It is an error when the plugin itself, or a behaviour already in your project, holds the name (Godot keeps one class per name, so the plugin cannot load, or one of the two scripts does not), and a warning when only the plugin's behaviour library does, since Add to project will refuse that behaviour until you rename your class.

### Added: Add to project checks class names first

- Godot keeps one list of class names for a project, and a second script with a name in it stops parsing. Adding a behaviour from the Behaviour library now compares the class names it would bring with that list before copying anything; on a clash it copies nothing and says, in a quiet amber note in the window, which name clashes, which of your files holds it, and that you can rename your class or leave the behaviour out. A behaviour's own copy already in the project is not a clash.

### Changed: Stat Forge keeps each buff and threshold rule as a small class

- A buff and a threshold rule were dictionaries read by text in about forty places; they are now a `StatBuff` and a `ThresholdRule` with typed fields. The saved state is the same record it was, written and read through each class's `to_dict` and `from_dict`: a state saved by an older version loads, and saving it again gives the identical text. Stat bases and last totals stay dictionaries, since their keys are your stat names.

### Changed: Storylet Weaver keeps its storylets, choices, requirements and effects as small classes

- A storylet, a choice, a requirement and an effect were dictionaries read by text in about a hundred places; they are now `Storylet`, `StoryChoice`, `StoryRequirement` and `StoryEffect` with typed fields. A storylet's meta stays a dictionary because its keys are yours, and the rows of a book file are read as before. Every verb, trigger and expression behaves as it did, and what the save state holds is unchanged.

### Changed: Drunken Walkers reads a saved walker and mark through small classes

- A saved walker is read back by `Walker.from_dict`, the pair of the `to_dict` that wrote it, and a mark is a `Mark` with its own `to_dict` and `from_dict`, instead of fields picked out of dictionaries by text in `load_state`. The saved state is the same text it was: a state written by an older version loads, and saving it again gives the identical text.

### Changed: Platformer Pathfinding keeps its records as small classes

- A link, a route stop, a portal, a hazard, a moving platform, a pending side request and a map tag's shared map were dictionaries read by text in about a hundred and thirty places; they are now `NavEdge`, `NavWaypoint`, `NavPortal`, `NavHazard`, `NavRide`, `NavSideRequest` and `NavSharedMap` with typed fields. Routes, portals, hazards and platforms behave as before, and the only saved text, the obstacle map JSON, is read and written exactly as it was.
- The mistake check now carries a sheet's own small classes into the probe it loads rows in, and a loop over a list of them no longer counts as a picked node.

### Changed: Status Effects keeps each running status as a small class

- A status that is on was a dictionary of five keys read and written by text in about thirty places; it is now an `ActiveStatus` with typed fields. Applying, stacking, ticking, extending and ending behave exactly as before, and nothing here is saved.

### Changed: Decal Painter keeps its ledger as two small classes

- A stamped decal and a blob shadow were dictionaries read by text; they are now a `TrackedDecal` and a `BlobShadow` with a typed field each. The rows, their words and what they do are unchanged, and nothing here is saved.

### Changed: Platformer Pathfinding checks the version of an obstacle map

- The obstacle map JSON has always carried a `version` that Load Obstacle Map JSON ignored. The number is now one constant, and a map marked newer than this behaviour reads says so once and is read as before; maps with no version or version 1 load exactly as they did, and the exported key is unchanged.

### Changed: Drunken Walkers checks the version of a saved state

- A saved state has always carried a `version` that loading ignored. Loading now says once when the state is newer than the behaviour reading it ("parts of it may be left out") and still reads it; a state with no version or the current one reads exactly as before, and the saved key is unchanged.

### Changed: Juice keeps each moment in the air as a small class

- A moment that is playing was a dictionary of twelve keys read by text from a dozen places; it is now a small class with a typed field for each, so a misspelt key is a parse error. Two keys that were written into it and never read (the strength and the direction the play was started with) are gone. The step cards, the Feedback Player's list and the moment file's rows stay dictionaries on purpose: the user writes them, scenes and files store them, and their rows' words are the file format.

### Changed: Group, Include and System read in Godot's own words by default

- By default the collapsible block of rows reads **Section** ("Group" is Godot's word for a node group, and the Words page's node-group entry is unchanged), a sheet other sheets include reads **Shared sheet** (Add > Shared sheet..., Sheet > Manage Shared Sheets..., Edit > Extract Selection to Shared Sheet..., the bar at the head of the including sheet, the picker window), and the picker's built-in card still reads **System** but now goes through the Words page like every other card. The Familiar preset keeps **Group**, **Include** and **System**. Three new Words keys (`section_block`, `shared_sheet`, `system_card`); no existing key, id, marker or saved byte changes, and the menus relabel when the Words page changes. All eight translations are filled.

### Changed: the vector shapes name their choice words once

- The 2D shapes, the 3D shapes and the shared base spelled the choice words (colour mode, dash space, dash snap, dash style, blend, caps, thickness scale and unit, and the 3D geometry and depth words) as text at every use. The 2D base now names each word once (`COLOUR_MODE_SINGLE`, `DASH_SPACE_COUNT`, `BLEND_ADD` and so on), the shader-order tables are built from those names, and the 3D base reads the same names, so a misspelt word is a parse error. The words stored in saved scenes and the `@export_enum` lines are unchanged, because the editor builds the drop-down from that line and a scene stores the word itself. The Canvas Surface is a separate pack and keeps its own copy of the words, which `tests/shape_words_test.gd` pins to the shapes'.

### Changed: a behaviour's own members are read by name, not by text

- Platformer Pathfinding reads the other agents (their map, host, path and claims) through its own class, Flock and Flock 3D read a neighbour's velocity through theirs, Post Kit sets an effect's strength and the outline's colour, width, fill and mask through the effect scripts it ships, Game Settings and Health name the method they hand on instead of spelling it as text. A misspelt member is now a parse error; behaviour is unchanged, and the gizmo drawers that receive the editor's property dictionary (Bound To, Follow Path, Juice) keep their text keys because the dictionary is the editor's.

### Changed: behaviours that drive a sibling or a named node check every member they use, once

- Platformer Pathfinding, Juice, HUD Kit, Dialogue Kit and NavAgent3D each probed one member of the node they found and then used several. Each now checks every member it uses when it first finds that node and says, once, by name, which are missing (`push_warning`; no `@tool` was added). Nothing is refused that was accepted before, so a driver or label that worked still works; one that lacked a member used to be ignored without a word. The shipped pairs never warn, which `tests/host_member_probes_test.gd` pins against the shipped movement, Screen FX layer, text styles file and controller.

### Changed: the editor Preview's shared table names its keys once

- A behavior that can be watched in the editor keeps the written-down rest values in an Engine meta table shared by every previewing behavior on the host. The table's name and the two field words of an entry (`rest`, `users`) were spelled out as text at every use in the 18 previewing packs; the compiler now emits each once as a private constant and uses the constant, so a misspelling is a parse error. The words themselves are unchanged, so a behavior compiled before this release and one compiled after it read and write the same table entry. The entry stays a plain Dictionary because the packs are separate files that cannot share a class.

### Changed: the last "Include bar" and "Include line" wording, and the name a new block starts with

- The guides and the Theme Editor's colour descriptions that still said "Include bar" or "Include line" now say **head bar** (the bar that names the object) or **Shared sheet line**; the guide for readers coming from another editor keeps its own word. The nine translation files carry the new wording for the five strings it touched.
- A block you add now starts with the Words page's word for it (**Section** by default, **Group** under the Familiar preset) instead of always "Group", including the `#region` name written into a `.gd` sheet. Blocks already in a file keep the name they were saved with, and reopening and saving any existing file still reproduces it byte for byte.

### Added: the Timer behavior's counting is pinned

- New `tests/timer_behavior_pins_test.gd` pins what the Timer behavior does today: its verbs, trigger and variables, what Start and Stop do, how a one-shot and a repeating clock end (the overshoot is dropped, not carried), zero and negative starts, the parked processing of a stopped clock, and the saved state. The behavior is not rebuilt on Godot's Timer node: the pins that make a rebuild safe cannot be run against a node that needs a scene tree, and a Timer node does not keep three of today's meanings on its own: it reads zero seconds left after a stop where the behavior keeps what was left, a start of zero or less reuses its old wait time instead of firing on the next tick, and its time left cannot be set by a Set Variable row. Each would need scaffolding that makes the 90-line pack bigger than the loop it replaces. The pack is unchanged.

### Changed: the vocabulary record in project.godot is written less often, and says so

- The first sheet save after installing or updating wrote `eventsheets/project/vocabulary_version` into `project.godot` with no word about it. Proved in a scratch project: the whole diff is a new four-line `[eventsheets]` section. The only thing that reads the value is the head band's "since" half, and it has to live in the project file for a team to share it, so it stays there. It is now written for the first record and once per minor release (a patch release leaves it alone), and the save puts one line on the status line naming the entry. Projects already carrying the line keep reading it unchanged.

### Changed: the seven Vector Shapes use Godot's own tool button for Save As Style

- Save As Style was a `# @inspector_action` comment line over the Style field, drawn only with the plugin. Each shape now carries Godot's `@export_tool_button` (a new public `save_as_style_button` that is hidden from the picker and never saved into a scene), so the button shows without the plugin. Every existing member, row id, template and saved value is unchanged. A file that still holds the comment-line spelling opens and saves byte for byte as before; the shipped shapes open as a sheet that reads the new line as a variable and re-emit byte for byte.

### Changed: Add > Global Variable says where the autoload it made can be seen

- When the gesture has to make a new global file, the status line now says it added an autoload and names Godot's own place for it, Project Settings > Globals > Autoload, and the new file's doc comment says the same. Adding a variable to an autoload that already exists is unchanged.

### Fixed: the guides say what the code does, and a test now holds them to it

- A survey of the guides found 17 statements that were wrong against the code and 20 behaviour guides that never named 65 rows and 24 variables of their pack. They are fixed: the toolbar guide (the Events | Code | Both switch, the four ways to play, no counts that drift, the buttons that left), the custom inspectors guide (the look picker is a list, not a dropdown; no hand-typed count of looks), the coming-from-GDScript guide (the deleted Object properties window), the README (a test-file floor instead of a count that was already wrong), AGENTS.md (the Manual folder path), and the Manual's own behaviour index, which still said "Object properties".
- New `tests/docs_truth_test.gd` holds five questions the suite can answer exactly: each behaviour guide names every row and exported variable of its pack; every menu path a guide writes in bold or italics ends at an item the editor builds; no current doc describes a removed UI name as present; every repo path a doc writes in backticks exists; and the numbers a doc states about the repo are measured. Each check keeps an allow list only where a miss is deliberate, with the reason beside every entry.
- `docs_integrity_test` now sweeps `docs/previews/` as well as `docs/images/`, and reads a README `<picture>` source as showing its picture. Six unused pictures in `docs/previews/` were removed.
- The Variable window's IN CODE block no longer splits a short word across two lines ("Str" then "ing", "norma" then "l"): it breaks between words. A single run wider than the column, such as `@export_custom(PROPERTY_HINT_NONE,` on a narrow window, still has to break inside itself, because Godot has no wrap mode that breaks after an opening bracket.

### Changed: three looks keep Godot's own export line

- A look used to be written `@export_custom(PROPERTY_HINT_NONE, "eventsheet:<look>...")`, which tells Godot "no hint", so in a project without the plugin a toggle-button variable was a free text box (40 in the packs), a unit number a bare float (15) and a progress bar a bare number. Proven in a scratch project with no plugin: the three now keep the control Godot gives their own annotation.
  - **Toggle buttons** write `@export_enum("a", "b")` under `# @inspector_look toggle_row[:segmented][:icons=...]`. A String stores the same word and an int the same index, so a scene saved either way loads the same value.
  - **Number with its unit** writes `@export_range(0, 1, 0.001, "or_greater", "or_less", "hide_slider", "suffix:<stored unit>")` under `# @inspector_look unit:kinds=...,store=...`, so Godot itself shows `2.0 px`; the stored float is unchanged.
  - **Progress bar** writes `@export_range(min, max)` under `# @inspector_look progress_bar`.
- A new pick in the Variable window writes the new form (its "Writes" hover and IN CODE block say the Godot line and the comment). A script that already holds the old `eventsheet:` marker opens as the same look, shows the same mark and saves back byte for byte; opening such a variable in the Variable window and pressing OK without touching it keeps the old spelling. Nothing is rewritten for you. The marker form stays for looks Godot has no hint for (tables, cards, dials, swatch rows, curves, textures, corners, seeds) and for any look you add.
- The shipped packs were rebuilt through their builders: Feedback Player (2 toggle rows) and the 18 Vector Shape scripts (10 toggle rows and 6 unit numbers in the builder's field text, 40 and 15 in the emitted scripts); the three showcase bars (`enemy_stats`, `inspector_playground`) follow their builder.
- The importer reads a hidden pack field's `## @ace_hidden` line, its doc and its section line through a look comment above them, and a look over a property with a setter, so those fields still open as the look. A hidden field with no look comment is read exactly as before.

### Fixed: Add > Global Variable makes a file Godot can run

- The first global of a project made its file blank: no `extends Node`, so Godot refused to start the autoload, and the first variable was then written above the `extends` line of any file that had none yet. The new file now starts `extends Node` (no generated banner, a one-line class doc), the first global lands after the head, and the sheet carries no class name - Godot refuses a script whose `class_name` equals the autoload it is registered as ("hides an autoload singleton"). The Entity System starter no longer sets a class name equal to its autoload name for the same reason. A sheet that already holds both names emits the same bytes as before.
- Sheet Type > Autoload no longer keeps a class name equal to the autoload name (the same Godot refusal); a class name of its own is kept.
- Stale lines: Keyboard Shortcuts no longer listed under Tools in the Toolbar guide (the keys are rebound in Editor Settings > Shortcuts), and the play button's header counts four ways to play.

### Fixed: a typed enum export wears the choices mark

- Since Drag & Drop and the Virtual Cursor export real enums (`@export var directions: Directions`), their variable rows read with the plain export mark where the old `@export_enum` line read with the dropdown mark. An exported variable typed by an enum the sheet declares now wears the choices mark again, and the Variable window's Inspector preview draws the dropdown of the enum's members (the variable's own chosen) and says "Shown as a dropdown of FREE, UP_DOWN, ...". Only the four enum-typed export rows of those two packs read differently.

### Fixed: the Variable window's look list rows grow with their sentence

- A look's row in the Variable window had a fixed height while its sentence wrapped, so a three-line sentence ran under the next row's title and the last line was clipped. A row is now as tall as its wrapped text at any window width; the list still shows about five rows before it scrolls.

### Fixed: the Variable window's code line is shown whole

- The IN CODE block of the live panel cut its line with an ellipsis (`var stat_hea...`) although it already wrapped. It now shows the whole declaration, wrapped.

### Fixed: the Inspector preview card reads on the light theme

- The card's small "Inspector preview" caption and the sentence under the preview were a white fade, pale on pale in the light preset. Both take the editor theme's ink and keep their contrast against the card's fill, in light and dark.

### Changed: Drag & Drop and Virtual Cursor modes are real enums

- Drag & Drop's `directions` and the Virtual Cursor's `direction_mode`, `hover_mode` and `bounce_mode` were exported whole numbers behind an `@export_enum` list. They are now typed enums with pinned values (`Directions.FOUR_DIR = 3`, `BounceMode.CONSTRAINTS = 2`, ...), so the code reads `directions != Directions.FREE` rather than `directions != 0`. A scene saved before the change stores the same number and loads into the enum unchanged (`saved_int_choices_test` loads such a scene file and pins the values); the Set Directions, Set Bounce, Set Direction Mode and Set Hover Mode rows keep their number parameters. The Inspector dropdown labels now come from the enum names (Up Down, Four Dir) instead of the old lowercase words.

### Changed: a behaviour's exported choices are named in its code

- A behaviour's exported choice keeps the words it stores in a scene and its `@export_enum` line exactly as before, so every saved scene loads unchanged. The pack's own code now names each word through a constant (`BOUND_SPACE_SCREEN`, `PIN_MODE_ROPE`, ...), in every comparison, `match` arm and assignment, so a misspelled word is a parse error instead of a silent miss. Row templates such as `set_bound_space("{space}")` keep their bytes. The option lists of `@export_enum` and `@ace_param_options` stay literal: Godot accepts a constant there, but an opened pack then reads that variable as raw code rather than a variable row. Done: Bound To, Pin, Pin 3D, Rotate, Wrap, Anchor, Follow Path, Stat Forge, Utility AI, Juice (the slowmo fade curve and direction), the Camera Rail pair (the shot ease) and Canvas Surface (the coordinates word). The Camera Rail's running shot, which is never saved, is a real enum with pinned values (`ShotMode`), and Canvas Surface's coordinate words are named too.

### Fixed: a weighted table never cuts its text cells

- A weighted table narrower than its roomy width no longer shows the per-row share column at all (the "Chances" line above the table already says every share, and "Total weight" stays), and the room goes to the text columns. A text cell also asks for the room its longest entry needs, up to a cap, so "common" and "rare,weapon" are whole at the Inspector's default width. The Loot Table's narrowest Inspector grows from 316 to 356 px to hold its tags whole.

### Fixed: the Chances label reads like the labels around it

- The "Chances" row above a weighted table no longer draws a dim label. The row is tied to no property once the Inspector has built it, so it shows neither a second revert arrow nor the dimmed label Godot gives a read-only row.

### Fixed: the amber "?" of a missing look reads on a light theme

- The amber "?" a row shows for a look that is not installed is held to a readable contrast against the tile or row it sits on: darker on a pale theme, unchanged on a dark one. No border or outline is added.

### Fixed: a width and height pair never leaves its x or its link on a line alone

- A width and height on one row (the texture size line and any `# @inspector_side_by_side` pair) wraps in two units: the width with the "x" after it, the height with the link button after it. Side by side while the Inspector has room, one under the other when it has not, and never a lone "x" or a lone link. Each field is only as wide as the digits its range needs, so the pair no longer squeezes the label beside it.

### Fixed: a weighted table's columns share the width by need

- In a weighted table (Loot Table, Random Table, Skin Catalog, Storylet Resource) the text columns now take the room that is left, instead of splitting it with the number column and the share column. A weight column is as wide as its widest number needs, and the share column as wide as its widest percent; the bar beside the percent shows once the table is wide enough to spare it. The tags cell no longer comes up short while the share column has room to spare.

### New: the mark says which look, and a click opens the look list

- Hovering the Inspector mark of a variable that wears a look opens a card that names the look, says its sentence (the limits for a slider), quotes the whole declaration line and ends "Click the mark to change the look."; a look whose file is missing says "Look not installed" and names the file. With tiles off, the glyph at the end of the row opens the same card. A single click on the mark opens the Variable window on its look list; no control enters the row, and a variable shown from another script is changed there.

### Changed: an exported variable's mark is the picture of its look

- The mark at the right of an exported variable row (and its tile, with View > Variable Badges on) is drawn as the small picture of the look the variable wears, in the row's own ink: a slider, a table grid, a menu arrow, a die for a seed, a Color's own colour. A look whose file is not installed is an amber "?" with no border. With tiles on, the separate range tile folds into the slider mark, so a ranged variable shows one mark, not two. A plain `@export` keeps today's mark.

### New: a variable row knows which picture the Inspector will draw

- An exported variable row now works out the picture of its Inspector mark from the same look table the Variable window reads (a slider for a range, a table grid, a menu arrow, a Color's own colour, an amber "?" for a look whose file is not installed), and stamps it on the row. Nothing is drawn differently yet; the reading dump shows it as `mark=<picture>`.

### Changed: the reading dump can carry a variable's mark

- `tools/reading_dump.gd` writes format 3: a span may carry `mark=<picture>`, the picture an exported variable's Inspector mark is drawn with, written only when it is not the plain one. No row carries one yet, so a dump of the shipped tree differs from format 2 in its header line only.

### Changed: the packs wear the new looks

- Loot Table, Random Table, Skin Catalog (rarities) and Storylet Resource tables show each row's share, the odds bar and a roll button; the Loot Table's pity tag is a menu of the tags its rows carry. Advanced Random's seed and Drunken Walkers' start seed have a New seed button. Drawing Canvas width and height are one row with common sizes and a video memory line. Bound To, Wrap, Flock, Flock 3D, Stat Forge, Juice (zoom limits) and Drunken Walkers (grid size) put their paired numbers on one row, keeping their ranges. Pack variables keep their names and values; only comment lines and `@export_custom` hints changed.

### New: a width and a height on one row, with common sizes and what they cost

- Two numbers marked `# @inspector_side_by_side` now keep the `@export_range` limits each declares (they used to lose them). When the pair is also linked (`# @inspector_link`), Godot's link icon sits inside the row instead of a button above it. A new line, `# @inspector_texture_size 256 512 1024 2048`, above the others says the pair is a texture's width and height: the label ends in "Size", an "x" sits between, a strip of the listed sizes sits under the row (one click sets both as one undo step) and one line says what the texture costs ("512 x 512 px, about 1024 KiB of video memory.", in Godot's own size words, worked out at 4 bytes a pixel). A file without the plugin has two ordinary number fields and three comments.

### New: a seed you can re-roll

- A new look, "Seed with a New seed button" (`eventsheet:seed`), for a number or text variable where 0 (or empty) means a new seed every run: the number field with a "New seed" button that writes a fresh positive seed as one undo step, and a quiet line under it while the value is 0 or empty. The button drops under the field in a narrow Inspector.

### New: a tag picked from a table's rows

- A new look, "Tag from a table's rows" (`eventsheet:table_tag:<table>:<column>`), for a text variable beside a table: a field joined to a menu of the tags the rows already carry (comma separated in one column), typing a new one still allowed, and an amber line when no row carries the tag in the field. The menu is filled when it opens, so it is never stale. Without the plugin the variable is a plain text field and the file is byte-exact.

### New: roll a weighted table a thousand times

- A weighted table gets a "Roll 1,000 times" button under it and, after a press, how often each row came up, with a line saying the count is from the weights alone ("Weights only. Rules the game adds, such as pity, are not counted."). The counts live in the Inspector row only, clear when the rows change, and are never stored. The button is off while no row has a weight.

### New: the odds of a weighted table as one bar

- A weighted table draws a "Chances" row above it: one bar split by each row's share (the largest in the accent colour), and one line naming the biggest three ("coin 62.5%, gem 31.3%, sword 6.3% and 2 more"). A table where no row has a weight says so in amber. A look can now hand back rows above and under its field.

### New: a weighted table shows each row's share

- A table whose marker ends `:weight=<column>` (a number column) draws one more column, "share": a bar and the percent each row holds of the whole, and "Total weight N" beside Add row. The shares follow every edit to a weight. A narrow Inspector hides the bars first and keeps the percent whole. A table without the part draws as before.

### Fixed: the look list pictures and the preview card's dial

- "Your own hint" and "Saved but hidden" in the Variable window's look list now draw a small picture of their own instead of a plain line. The dial in the small Inspector preview card takes its inks from the editor theme, so it reads on the light preset as well as the dark. The photo harness can photograph the shipped packs through their own scripts.

### Changed: Inspector notes and buttons sit under their field

- A required note, a failed check, an info line and a field button (`# @inspector_required`, `# @inspector_validate`, `# @inspector_info`, `# @inspector_action`) now sit in the value column directly under the field they are about, in the editor's own font, with colour alone carrying the state. The outlined note box and the 9 px button above the field are gone. The comment lines in your scripts are unchanged. The required sentence now reads "Required. Assign a value."
- New: `tools/render_inspector_looks.ps1` photographs every look in Godot's real Inspector in dark, light and a scaled editor and at a narrow and a wide Inspector, against a separate editor config folder so the developer's own settings are never touched. New: one style file the looks read the editor theme through.

### Changed: the Inspector looks are redrawn to read as part of Godot

- Every look now asks the running editor's theme for its colours, field box, heights, fonts and icons (one file, `EventSheetLookStyle`) and falls back to the sheet theme only where no editor exists, so a look follows the dark theme, the light theme, any accent colour and any editor scale. Sizes Godot has no item for are named constants that go through the editor scale.
- Direction dial: two number fields (x, y) with the dial under them in the value column and a "reach" label under the ring. Corner radii: four number fields, two to a line, each marked with its corner, with a link button that keeps them the same. Table: folds behind one button, cells are real fields, rows move by their grip (or the grip's right-click menu), remove and add use the editor's icons. Progress bar: Godot's ProgressBar with the accent fill and a "60 / 100" reading. Swatches: field height, a tick on the chosen one, Godot's colour picker as the last cell, a neutral hairline on a pale or dark swatch. Min and max: two number fields with a track (grey, filled span, a handle on each end of the fill, the ends of the whole range under it). Unit: a dropdown joined to the number field. Toggle buttons: one joined strip, the chosen one filled with the accent, a picture keeps its word. Heading: a quiet panel with the name in bold (its colour stays in the file, not drawn). Side by side: one label on the left, each field names itself. Tabs: Godot's tab bar under the script heading. Texture: the picture on the editor's checkerboard with its size under it. Curve: a field-coloured panel, half-way grid, accent line; a click opens Godot's curve editor. Cards: a grip, a line with the kind in bold and one grey sentence, a remove button; the coloured bar is no longer drawn (the colour stays in the data).
- A part that does not fit beside its label (the toggle strip, the swatches, the min-max track, the corner fields) goes on its own line, or stacks, instead of being cut short. No look cuts a word or number short while the Inspector has room.
- Variable window: the look is picked from a list with a small picture, the name and one grey sentence under the headings "Godot's own", "EventSheets looks" and "In your project", and each question says what it means and how it is written in the file. "Axis fields" is now "Two number fields" and "Linked axes" is "Linked fields".
- The look list in the Variable window shows about five rows without scrolling and opens scrolled to the chosen look. The chosen row is a plain fill with no outline, and each look has its own small picture (dial, bar, table grid, swatches, strip, slider, menu, curve, picture), all drawn by one painter that takes its colours as arguments. The window's card area grows with the screen so the list is not cut.
- Corner radii: at a narrow Inspector the link button stays icon-sized at the end of the first line of fields instead of sitting alone above them.
- Inspector Look shelf: five more rows for look sheets (a themed panel, a message line, a number field, a joined strip, and "put this under the first row"), hidden outside look sheets like the first six. The toggle strip is built by the same `joined_strip` builder.
- The sums behind a weighted table (each row's share, the odds as one line, a seeded roll) are one pure file, `weight_math.gd`; nothing is stored.
- A table marker can end with `:weight=<column>` naming its number column of weights (new, written only when set, and the Variable window asks for it as "Weight column"). A build without the part leaves the line as written; the file re-saves byte for byte.
- Markers in user scripts, ace_ids and the stored values are unchanged.

### Removed: the Manual no longer draws pages for Godot classes

- A Godot class or method is Godot's own Help now: press F1 on a row that names one, or use Help > Search Help in the Script editor, and the class reference opens at it. An `engine:` link (`engine:Node2D`, `engine:Node2D.position`) opens that topic in Godot's Help instead of a page drawn in the Manual. The Manual's search no longer has an "engine reference" group, and an exported site no longer carries engine pages or their credit line (`tools/export_docs_site.gd` prints a notice for the old `engine` option and carries on). What stays is the one-sentence hover: a derived row, a picker entry and a completion still show Godot's own sentence for a built-in member, read from the cache that Docs housekeeping's harvest and fetch chores (and the `docs-harvest` and `docs-engine-text` commands) fill, with its CC BY credit.

### Removed: the Ctrl+P window no longer lists commands; they are on Godot's own Command Palette

- The Commands tab of the Ctrl+P window is gone: Ctrl+P is now a Go to window with Symbols (the default: every function, signal and variable of the open sheet), Sheets, Docs and Error line. Every command the tab listed - New Sheet, Open, Save, Save As, Export Generated GDScript, Run Scene, Add Event, Add Condition, Add Action, Add Global Variable, Add Function, Go to event, Outline, Toggle GDScript Panel, What Changed Since Save, Toggle Simple Mode, Zoom In and Out, Sheet Type, Export Addon Pack, Open Welcome, Start the Tour and one Add for each block kind - is on Godot's own Command Palette (Ctrl+Shift+P), as are the four that had no other door (Split Scene Into Chunks, Merge Chunks, Export Mod Template, Toggle Rescue Tips). `EventSheets.register_palette_command`, `unregister_palette_command` and `palette_commands` keep their shapes: an entry is kept in the list and put on Godot's palette when it is registered, and taken back when it is unregistered or its workspace is freed. A palette entry reads "EventSheets: <title>", or "<category>: <title>" when the pack gave a category, and Ctrl+Shift+P is no longer taken by the sheet.

### Removed: the Debugger window keeps Watch and Trail, and the Live Values window is gone

- View > Debugger no longer has the Inspect, Profile and Breakpoints tabs, and Tools > Live Values opens no window of its own any more. Godot does these: look at and edit a running object's variables in Debugger > Remote (the Scene dock's Remote tab) or Stack Variables when paused, see the breakpoints you set with F9 in Debugger > Breakpoints, and read the time per event on the rows themselves after Tools > Run With Profiler. Watch and Trail stay (Godot has no expression watch and no state trail), and the Trail tab now carries the "How it got here" mode line the Live Values window used to show. Live Values still streams: the values show beside the variable rows, and feed Watch, Trail, the Why didn't this fire? panel, Live Edit and the replay recorder. Row breakpoints (F9) are unchanged and still compile to Godot's own `breakpoint`.

### Removed: Sheet > New Class and the New global form are gone

- Sheet > "New Class..." is gone. Godot makes a script class with FileSystem > right-click > Create New > Script (Inherits, Class Name); the file opens here as a sheet. Sheet > "New autoload..." and the Start page's Project-wide maker row are gone too: add a global in Project > Project Settings > Globals (Autoload tab), then open its script here. What stays: "New behaviour...", and the settings form of a behaviour or a global that exists (rename across every sheet, change script or scene, picker heading, icon), reached from the picker's global settings link and the sheet head. The three pack pages that said to start from "Copy of ..." in the New global form (Event Bus, Named Scenes, Second View) now say to add the script under Globals.

### Removed: the Translation Studio no longer registers languages, and Language Variants is gone

- The Translation Studio's "Turn on in the game" step and its "Players see it" line are gone, and so is the "Language Variants..." item on a row's menu. Godot does both: turn a finished language on in Project Settings > Localization > Translations, and map one asset per language in Localization > Remaps. The Studio still finds the text, fills the table, checks what is missing, tries a fake language and hands a CSV to a translator, and View > Preview In Language is unchanged.

### Fixed: a variable added to a sheet opened from a .gd was not saved

- On a sheet opened from a `.gd` file, Save wrote the file's own rows and left out the sheet's variable table, where the Variable window keeps an Instance variable. The variable showed on the sheet and Save said it had saved, but it was missing from the file. The save now writes what the table holds beside the file's own variables (after the last one, or under the header lines when the file has none), skips a name a row already declares, and leaves an untouched file byte for byte as it was. Signals and enums were never affected (they are rows and were written). A constant stored in the table is written as a plain `var`, the same as in a sheet saved as `.tres`; that is unchanged and noted here.

### Added: an Inspector look is read and made as an event sheet

- A sheet whose script extends `EventSheetInspectorLook` reads its three Inspector callbacks as triggers: `_look_built`, `_value_shown(value)` and `_value_changed_from_outside(value)` are "On look built", "On value shown" and "On value changed from outside", each with a hover saying when Godot's Inspector calls it. The rows are offered by the picker on such a sheet and on no other (a new closed-list reason, `outside_inspector_look`), and a file with the same function on any other class reads as an ordinary function. The emitted text is the plain function byte for byte, in both directions.
- Three more rows on the same "Inspector Look" shelf: the action "Set the field's value" (`set_field_value(value)`), the action "Make this control the one focus lands on" (`add_focusable(control)`) and the expression "the field's value" (`field_value()`). Their ace_ids are `OnLookBuilt`, `OnValueShown`, `OnValueChangedFromOutside`, `SetFieldValue`, `AddFocusable` and `FieldValue`; like every shipped id they never change.
- A look's question is labelled by its first `##` line in the Variable window, and the hover says the name as written; with no `##` line the label is the name. The shipped looks carry the labels they had before (Min, Max, Reach, Units, Choices, Columns, Table, Name column). Stored keys did not change.
- The Variable window's look list offers "Open as a sheet" on a look that is a file, and "Copy into my project" on a shipped one. The copy is the shipped file byte for byte in `res://eventsheet_addons/looks/`, where the project's file wins by name; nothing is ever overwritten and the window says so.
- Sheet > "New inspector look..." asks a name and what the look works on, writes a small working look (a plain field that shows the value) into `res://eventsheet_addons/looks/` and opens it as a sheet. The written file passes the style gate, opens as rows and saves back byte for byte.
- `EventSheets.register_inspector_look(path) -> bool` adds a look kept anywhere else. It returns true when the file exists, is a `.gd` and reads as a look; the catalogue lists it after the project's own, and a project file of the same name still wins.
- A module guide for the six rows (`docs/Modules/Inspector-Look.md`) and the whole path from "New inspector look" to the Inspector in the make-your-own-look guide.

### Added: an Inspector look is one script file

- A look is now a script that extends `EventSheetInspectorLook`, a thin layer over Godot's `EditorProperty`. Drop one in `res://eventsheet_addons/looks/` and it is a look: nothing is registered. The Variable window and the Inspector Designer list it, ask its questions, and write its marker; the Inspector draws it. The look's name, hover, the types it works on, its questions and the line it writes are all read from the file's text, so nothing is run to list it. A file in the project with a shipped look's name replaces it. Make your own with the new guide "Make Your Own Inspector Look".
- The progress bar is the first look to move onto a file, `addons/eventsheet/looks/progress_bar.gd`. The marker it writes is unchanged byte for byte (a generated corpus of 200 bound pairs proves the two spellings write the same line), and the Inspector draws it with the same pixels as before. Its two questions in the Variable window now read `min` and `max`, the names as written in the file.
- A marker naming a look the project does not have still opens, saves back byte for byte and is kept by the Variable window as "Look not installed", instead of being dropped.
- The compiler and the importer gained one generic spelling for a look with no structured attributes of its own (`look` and `look_args` on a variable). No existing branch changed, and markers already in scripts never do.
- "Save and show": a choice made in the Inspector Designer is saved to the script the way Save does it, with the same guards, and Godot is told the file changed. One `update_file` is all it needs: the selected node's Inspector redraws with the new look at once. The parsed decor lines are forgotten too, so an edit that keeps the script's length is not drawn from the old map.
- `eventsheet_addons/looks/` is skipped by the scan of `eventsheet_addons/` that finds ACE providers, so no reader of that list ever sees a look.
- Seven more looks moved onto files, one script each in `addons/eventsheet/looks/`: Swatch row, Texture preview, Curve preview, Four corners, Direction dial, Min-max range and Pick a row of a data table. Each file wraps the drawing widget it always used, so the Inspector shows the same pixels (a before and after photograph of the real Inspector differs by none), and the marker each writes is unchanged: a generated corpus proves the structured spelling and the file spelling write the same line, and that the line reopens and saves back byte for byte. The window lists them in the same places; their detail fields are now named as the file writes them (`max` for the dial's reach, `table` and `name_column` for the row picker).
- A look can answer `_can_draw()`: when the values the marker carried make no sense (a row picker whose table is not a variable name), the Inspector keeps Godot's plain field, as it did before.
- Number with its unit, Toggle buttons and Editable table moved onto files too (`unit.gd`, `toggle_row.gd`, `table.gd`). Their compiler and importer codes did not change at all: the file supplies the tile, the question (`units`, `choices`, `columns`, the same keys the Variable window always used) and the drawing, and reads the marker's own grammar from a new `marker_args` (the text after the look's name, split on `:` as written), so a hand-written spelling such as `eventsheet:unit:time` or an icon source holding colons still draws exactly as before. The Toggle buttons file keeps offering itself for text only, and still draws an int a script already marked (`const ALSO_DRAWS_ON`).
- A look file can state the sentence the Designer's preview card says under it (`const PREVIEW_SENTENCE`), and every shipped look now does: "Shown as a progress bar." and the other pinned sentences come from the files, byte for byte as before.
- The card list (`eventsheet:cards`) stays on its original code for now: it has no tile in the Variable window today, and giving it one is a new feature, not a move.

### Fixed: searching Clone object finds the copy rows

- Typing "Clone object" in the picker, the sheet's own spelling of Duplicate, found nothing. It now lands on Clone Into first and also finds Duplicate Node.

### Fixed: Add Sprite starts with a picture you can see

- The Picture field of Add Sprite and Add Sprite (3D) started as `PlaceholderTexture2D.new()`, which is 1 by 1 and nearly invisible. It now starts as a 64 by 64 solid square made in code (`ImageTexture.create_from_image(Image.create_empty(64, 64, false, Image.FORMAT_RGB8))`), so the sprite shows the moment the row is dropped and still needs no file. A `GradientTexture2D.new()` was measured and is not used: with no gradient it draws Godot's magenta error square. No template or ace_id changed; only the field's starting text did.

### Fixed: an empty curve slot draws nothing

- The Curve preview look drew a sample S-curve under an empty slot, which read as if a curve existed. An empty slot now shows the quiet word "empty", and the look's hover says the picture is of the curve in the slot.

### Fixed: the Inspector look hovers name the marker the compiler writes, and the Doctor reads .gd sheets for Required

- Ten look hovers in the Look list said `es_drawer:` where the written marker is `eventsheet:`; a test now holds every hover to its own marker word.
- The Doctor's required-field check only read `.tres` sheets. It now reads `.gd` sheets too, the default format, so a Required variable left empty in a scene is reported in a project made of scripts.

### Fixed: the no-collision-shape help strip fits beside its two doors

- The sentence about a node with no collision shape lost its tail behind "Add a shape" and "Show me in the scene". It now says what is wrong and that the row never fires, and leaves the two options to the two doors.

### Fixed: the Manual has one door

- Manual... was in the Menu and again at the end of Tools. It stays at the foot of the Menu, where the unread mark is, and leaves Tools. F1 and Ctrl+F1 are unchanged.

### Changed: a spawn row reads with Godot's word

- A row that instantiates a scene and adds it now reads "Instantiate" and the row that copies a node already in the scene reads "Duplicate", the words Godot uses. "Create object" and "Clone object" are the sheet's own spelling of the same two rows, shown when the Words page has the sheet's verbs on, and still find them in the picker search. No ace_id, template or saved byte changed.

### Fixed: Add Sprite starts with a picture that exists in any project

- The Picture field of Add Sprite and Add Sprite (3D) started as a `load` of `res://icon.svg`, which turned the row amber in a project without that file. It starts as `PlaceholderTexture2D.new()`; choosing a file still writes the `load` of that file.

### Added: Building rows in a tool sheet own what they build, and a rebuild clears the last result

- Dropped into a Tool sheet, an Add New Node, Add Behaviour, Add Sprite, Add Shape or Add Timer row also gives the new node the scene being edited as its owner (`get_tree().edited_scene_root`, only under `Engine.is_editor_hint()`) so it is saved with the scene, and marks it so it can be found again. A new node goes under the scene being edited by default. In a game sheet the same rows write exactly what they wrote before. This is not an editor undo step.
- A new row, Remove What This Sheet Built, frees the marked direct children of a node. A tool event that builds without clearing first wears the quiet amber state, the help strip and the Doctor's Tool edits section say a rebuild adds another copy, and Clear what it built first puts the clearing row at the top of the event in one undo step.

### Added: hand-written code that makes a node opens as the Building row

- Add New Node starts with a name (NewNode), and clearing the field still leaves the node the name Godot gives it. A RemoteTransform made and parented in one run is left to the Copy Place reading it already has, so no existing reading changes for it.
- A person's own lines now open as the row that writes them: a node made from a type and given a parent (named or not), a behaviour looked up and added when it is not there, a behaviour removed, a sprite, a circle, rectangle or capsule shape (and the 3D shapes), a timer, and a branch packed into a variable. Each is read as one run, the values are the ones the lines said, the editor's own baked ids are kept as the author's spelling, and saving the sheet untouched writes the same bytes back. A run short of the whole shape (a node made with an argument, a bare `add_child`, ids that disagree) keeps the ordinary rows it always read as. Add Behaviour with Allow another is three lines identical to Add New Node with the class's own name, so that run opens as Add New Node and writes the same bytes.

### Changed: a node that plays is paused, a behaviour is turned off

- A process-mode write now reads by what the object is: a behaviour or any class of the project is turned off and on, a Timer, an AnimationPlayer, an AnimationTree or a rigid body is paused and resumed, and anything else keeps "Set disabled" and "Set enabled". The line written is exactly the same; a picked Pause Node or Unpause Node row and a hand-written `process_mode` line read alike. Measured in a running game: Disabled stops a node's code, timers, animations, physics and bound tweens, a sound keeps playing and signals still arrive, which the two rows' descriptions and the Scenes, Pausing And Turning Nodes Off guide now say.
- Search finds the existing rows under the board words: turn off, turn on, disable or enable behavior (Pause Node, Unpause Node, beside the rows that are already called Turn Off), has behavior (Has Child Of Type), change behavior, spawn from a prefab (Instantiate) and save a prefab (Save Data Asset). The picker's code preview shows a Building row as a game sheet writes it, without the lines a tool sheet adds.

### Changed: a new copy is added under the running scene, and what a row makes is an object for the rows after it

- The Under field of a new Instantiate row (and its 3D, crowd, formation, launched and free-spot spellings) now starts as the running scene, `get_tree().current_scene`, instead of the node that spawned the copy: a bullet added under its shooter turns, scales and is freed with it. A row already in a sheet keeps whatever it stored, and no template changed, so nothing already written compiles differently.
- The name an Instantiate, Make A Copy, Add New Node or Add Behaviour row leaves behind is now an object in the Add action picker for the rows after it, typed by what it made: the type of Add New Node, the behaviour of Add Behaviour, the class of the root of the scene file an Instantiate names. One table (made_names.gd) now feeds both these objects and the name chips, which also gains the 3D Instantiate that was missing from the chips.

### Added: Building, the rows for making nodes while the game runs

- A new Building page in the picker: Add New Node (any node type, optionally named, added under the running scene and kept in a variable), Add Behaviour (a script node added as a child and named after its class, with Only one or Allow another), Remove Behaviour, Add Sprite, Add Circle, Rectangle and Capsule Shape (and Sphere, Box and Capsule in 3D), Add Timer, Add To Group (Saved With Scene) and Keep As Prefab. Each one writes the plain Godot lines a person would type (`Type.new()`, `add_child`, `get_node_or_null`, `PackedScene.pack`) and needs nothing from the plugin at run time.
- The type field on Add New Node, Add Behaviour and Remove Behaviour completes class names as you type and has a Choose button that opens Godot's own Create New Node window; a script class goes in by its class_name.
- Keep As Prefab lends ownership to the nodes it packs and gives it back (the same walk Save Branch As Scene File uses, now one shared piece of code), so it can run twice on the same branch; its description says a plain Add To Group is not kept by a pack and points at the saved-with-scene row.
- Search finds the page under the other ways of saying it: add node, new node, create node, add behavior, attach behavior, give behavior, remove behavior and prefab.

### Changed: sheet shortcuts are rebound in Godot's Editor Settings > Shortcuts

- The authoring keys (add event, add condition, collapse and the rest) are now registered with Godot's own Editor Settings > Shortcuts, where you search and rebind them like any editor key, and the editor saves the change. The plugin's own Tools > Keyboard Shortcuts window and its `eventforge_shortcuts.cfg` file are gone; keys you had changed are carried into Editor Settings once, and the Output says so. The "Another event-sheet editor" preset went with the window - rebind X, Ctrl+E and the rest there by hand.

### Removed: the plugin's own History panel (Godot's History dock lists the edits)

- Every sheet edit already went through Godot's own undo manager under its plain name ("Add Group", "Extract to Function"), so Godot's History dock lists each one (tick its Global history). The plugin's View > History window repeated that list, so it is gone, along with the "(undone)" markers and the lit-up rows it drew. Ctrl+Z and Ctrl+Y are unchanged.

### Changed: new quality presets go in eventsheet_settings/quality/

- A bare top-level `settings/` folder is a name a project may already use for its own things, so new quality presets are written under `res://eventsheet_settings/quality/`. Presets already in `res://settings/quality/` are still read and listed, by the editor and by the Game Settings pack in a running game. Nothing is moved for you.

### Changed: the plugin speaks Godot's editor language; the separate Language picker is gone

- The plugin's interface now follows Editor Settings > Interface > Editor > Editor Language, so there is one place to choose it. View > Language and the Welcome window's Editor language dropdown are removed. A language you chose before is respected as saved, the Editor Setting `eventsheets/interface/language_override` (empty by default) is the way to differ from the editor on purpose, and dropping a translation CSV into the folders still works. View > Preview In Language is unchanged: it previews the game's languages, not the editor's.

### Removed: Tools > Register Autoload; New autoload is named in Godot's word

- Godot lists and manages autoloads in Project > Project Settings > Globals > Autoload, so the menu item that registered the open sheet's script is gone, and the Doctor and the guides send you there. The New global form stays, since it makes the script and registers it as before, and it is now called **New autoload...** in the menus, the form title and the start page. The Words page still offers "Global" for readers from another editor (the `global_singleton` word).

### Removed: the Preview scene and Preview project buttons

- Godot already has Run Current Scene (F6) and Run Project (F5) in the bar at the top right, and the strip's two Preview buttons were the same runs under other words. They are gone from the play button's dropdown, its Main button choice, the expanded strip and the shortcut list; the guides say F5 and F6. The runs that carry sheet debugging stay: Run Scene, Debug scene, Run with profiler and Play as host + client. A project that had chosen a Preview run as its Main button falls back to Run Scene.

### Fixed: an Ask key is no longer saved into your project

- The key for View > Ask (and the older in-editor generator) was a project setting, so a typed key landed in project.godot and was committed with the repository. It now lives in Editor Settings (per user, shown as a password field) as `eventsheets/ask/api_key`, with the `EVENTSHEETS_ASK_API_KEY` environment variable as the fallback (`EVENTSHEETS_AI_API_KEY` for the generator). A key an earlier version saved into the project is moved to Editor Settings and cleared from project.godot the first time the plugin starts, and the Output says so once.

### Changed: enabling the plugin no longer adds an autoload to your project

- The plugin used to write an `EventForgeBridge` autoload into project.godot, and the game exported it although nothing in a shipped game needs it. The provider registry is now a plain class: code-registered providers and blocks reach the editor with no autoload, and every `EventSheets.*` method works as before. A project that has the old line loses it the first time the plugin starts, and the Output says so (an autoload you made yourself under that name is left alone). A script of yours that named the old singleton should call `EventForgeBridgeRuntime` instead. The uninstall guide is updated.

### Fixed: a project made from addons/ alone runs the rows that call a runtime script

- A free-spot spawn, a retire, a bus mix, a world-look, a haptic or a sequencer row calls a small script that used to live only in this repository's `eventsheet_addons/`, so a project that copied the three addons folders met a parse error the first time such a row ran. The plugin now carries those scripts inside its library and copies the one a row needs into `eventsheet_addons/` the moment the row is applied. The Doctor names any script that calls one the project lacks and offers "Add it to the project". The README no longer asks you to copy them by hand.

### Added: a collision row about a node with no shape says so

- A row that asks about another node (its On node, or the body or area it names) where that node has no collision shape now goes amber, like the check on the sheet's own node did. The help strip says which node and why, and offers Add a shape (a rectangle or box shape under the node, owned by the scene, one undo step) and Show me in the scene. The Doctor files it as collisions-target-no-shape with the same two doors. Nothing is said when the node cannot be found in the one scene that runs the sheet.

### Changed: opacity takes a percent

- Typing 50% or 50 into a percentage field (Set opacity, and the Move toward weight) stores 0.5; 0.5 stays 0.5, and an expression is left exactly as written. The help strip says "0 to 100, or 0 to 1". Rows already in sheets are untouched.
- The everyday object rows are now translated into the nine editor languages.

### Changed: the Family Arena strike hits every member

- The Family Arena showcase's group strike now damages every Enemy in the group each time it fires (it used to give each a 15% chance), so the showcase shows groups plainly.

### Changed: the sheet reads in Godot's own words by default

- A trigger now says the Godot callback it runs on: On ready (on any node, the scene's root included), On enter tree, On exit tree, On process and On physics process, where it used to say On start of layout, On created, On destroyed, Every tick and Every physics tick. The scene rows say scene: Change scene, Reload scene, Add scene on top, Is outside screen. The Inspector is the Inspector on both sides of the Words page.
- The words other event-sheet editors use are one opt-in away, in Settings > Words > Familiar words, and the lifecycle and tick words now live in the Words table, so the page lists and controls them (five new rows: scene_ready, scene_exit, node_enter, node_exit, every_physics_tick). Typing an old word in the picker or the quick-add bar still finds the row (start of layout, every tick, every frame, on created, destroyed, go to layout, restart layout). A row's tooltip names its other word and the Godot function.
- The Welcome answers no longer switch anyone to the other editors' words: all three set Godot words. The answer for people coming from another editor keeps the Classic theme and opens the migration guide, which says where the Familiar words are.
- Wording only: ace ids, templates, emitted GDScript and stored sheets are untouched. Guides, the tutorial, the tour, the Doctor and the nine translations read in the new words, and the README pictures are retaken.

### Changed: the nouns and verbs read in Godot's words too

- Removing a node says Queue free (Queue Free Now, Queue Free After Seconds, Fade Out Then Queue Free), making a copy of a scene says Instantiate (Instantiate, Instantiate Safely, In A Formation, Myself, In A Free Spot, Into The Crowd and the scene rows), a rotation says rotation, an overlap test says Overlaps, and the group triggers say On Body Entered, In Group and On Body Exited, In Group. A row written as code (`queue_free()`, `look_at(p)`, `overlaps_body(b)`) reads the same way. Group and node are the words everywhere; the group lists say Members and Nodes where they said Entities and Instances.
- The other editors' words are the Familiar preset on Settings > Words (Destroy, Spawn a copy of, angle, Is overlapping, On collision with) and the event-sheet-editor words preset for the verb rows. Typing either word in the picker finds the row, and an exact phrase such as go to layout, destroy or spawn now ranks its row first instead of behind every row that shares a word with it.
- Hovering a word says what the other editors call it, or what Godot calls it, and the Godot call or property it writes ("Godot writes this as modulate.a" on Opacity).
- A blank event, the process switches and the pack descriptions say every frame, On Process or process where they said every tick; the guides say scene where they meant a scene. Wording only: ace ids, templates, emitted code and stored sheets are untouched. The translations follow in all eight languages.
- Six guide pictures are retaken in the new words (the Words page, the lifecycle readings, the scene readings, the pause pair, the save-branch pair); the pictures that still show old words are listed in the pictures audit, not hidden.

### New: the everyday object rows, under the names people look for them by

- Set Opacity and Opacity (shown as a percentage, written as Godot's 0 to 1 `modulate.a`), Set Scale, Set Size (a Control's size), Set Sprite Size (the scale that gives a size in pixels), Width, Height, Left, Right, Top and Bottom for a sprite, Instance Id, Marker Position (a Marker2D child), Is Outside The Level Bounds and Is Outside The Camera Limits. Each writes the plain Godot line and its description names the property.
- Once Ever: run an event one time for the life of the object. It keeps one plain true-or-false variable on the script. Trigger Once keeps its meaning (it fires again each time the condition goes false and then true).
- Is On Screen now adds a VisibleOnScreenNotifier2D under the node in the scene when you add the row, as one step of the scene's own undo, and says so on the status line. Ctrl+Z takes both back.

### Changed: Is On-Screen and Is Outside Layout are retired

- Both tested the window rectangle, so they were wrong as soon as a camera moved or zoomed. They keep compiling in the sheets that use them, are hidden from the picker, and point at Is On Screen (Rendering).

### New: press Preview to watch a behaviour in the editor

- Eighteen behaviours that are tuned by eye now carry a Preview button in the Inspector: Sine, Sine 3D, Rotate, Orbit, Orbit 3D, Wave, Flash, Hit Flash, Fade, Light Flicker, Light Pulse, Spring, Juice, Juice 3D, Follow Path, Move To, Move To 3D and Tween. Press it and the behaviour plays on its node in the 2D or 3D view while you drag its values; the button then reads Stop preview. Nothing plays when a scene opens, and every other behaviour is exactly the script it was, with no `@tool`.
- The scene is never changed by a preview. The host's stored values are written down when Preview starts and put back on Stop, on leaving the scene (another scene tab, closing it), and before every save, which includes pressing Play. The values are set straight on the node, so the scene tab never shows as modified and the undo history gains nothing.
- Spring, Juice and Juice 3D, which only move when set off, have a second Nudge button beside Preview. Several behaviours on one node can preview at once.
- Right-click a node in the Scene dock: Preview its behaviours presses Preview on every behaviour under it that has the button, and Stop previews puts it all back. It presses the very same buttons, so it only appears for behaviours that carry one.
- The preview is the behaviour's own code, so it works in a project with no plugin installed: copy the pack's folder in and the button is there. A behaviour declares it in its builder (`previews`), which is the whole list.
- A preview never writes into a material other nodes share. Wave and Hit Flash with Own Material off work on a copy while previewing, and Stop puts the original back, so the other nodes keep their look. This is in the pack's own code, so it holds with no plugin.
- The older Tools > Preview Behaviors on Selected Node item (and its Command Palette entry) is gone, and so is the sampler function the Sine, Rotate, Orbit, Orbit 3D and Bullet 3D packs carried for it: with the Preview button it wrote to the host a second time. `EventSheets.register_editor_preview` and `EventSheets.preview_behaviors` still exist so older code runs, and do nothing. Editor gizmos are unchanged.

### Changed: a node dragged from Godot's Scene dock starts an event on it

- Since the Objects list no longer lists the rest of the scene, Godot's Scene dock is where an unused node comes from. Dragging one onto the empty canvas or onto an event now does exactly what dragging the same object off the Objects list does: the picker opens on that object (Add condition, or Add action when it lands in an event's action lane), with the same offers as before for a node in the secret or water group or one that exports needs_key. A node the sheet already uses lands under the name the sheet gives it. Dropped on a parameter value it still fills that parameter with the node reference, as it did.
- The picture of the Objects rail in the guides is drawn again, now showing only the objects the sheet uses.

### Changed: a behaviour is added with Godot's own Create Node window

- Every Add behavior... door (the Objects list's right-click, the head's Behaviors folder, the picker's suggestion) now opens Godot's own Create Node window, titled "Add a behaviour to <object>". Every behaviour is a plain script with a class name and an icon, so Godot already lists it there. What you choose goes under that object in the open scene as one undo step (Ctrl+Z takes it out) and is selected, so Godot's Inspector shows its values. If the object is not in the open scene, the status line says so and nothing happens. A behaviour that ships a scene or a shader of its own is still added the way its guide says.
- The old Add behaviour window is gone: its shelves of tiles, the Properties card of values (set them in the Inspector now), and the Where choice. Nothing in the editor writes a behaviour into a script any more, because that choice lived only there.
- New: Sheet > Behaviour library... lists the behaviours the plugin carries that the project does not hold yet, each with its icon, what it is and what else comes along with it. One button, Add to project, copies its folder in and lets Godot import it, then says: Now add it with Add Child Node (Ctrl+A) under the node it should act on. A second tab lists the ones the project holds, with Remove from project... as before.
- Sheet > New behaviour... and a behaviour's file opened as a sheet (the head's Behaviors folder) are where they were. The Welcome page, the guides and the Addons index now say: a behaviour is a node, add it with Add Child Node, set its values in the Inspector, and add it from the Behaviour library if it is not listed.

### Fixed: a signal can be offered as a trigger again

- The signal window (Declare > Signal... or double-clicking a signal row) has one tick, "Other sheets can start an event from this". Ticked, every other sheet's picker lists the signal as a trigger; the code is the same plain signal line with the short trigger comment above it. A new signal on a behaviour or a global starts ticked, on an ordinary sheet unticked, and reopening the row changes it later in one undo step. It replaces the Add trigger button of the removed Properties and actions window.

### Removed: the Properties and actions window

- Sheet > Properties and actions... is gone, and a new behaviour or global no longer opens it. It only listed what the open file offers and had Add buttons that opened the ordinary windows, so nothing it did is lost: Add variable is on the Add menus, New Function > Action / Condition / Expression publishes a function, and the Anatomy tab of the side rail lists a behaviour's properties, actions, conditions and triggers. Turning a global on is Godot's own Project Settings > Globals > Autoload.
- The one thing the window alone did was add a published trigger (a signal row marked as a trigger); that now lives as a tick in the signal window.

### Removed: the Project bar

- The Project strip at the foot of the Objects rail is gone, with its View > Project bar item and the saved on/off choice. It listed scenes, scripts, classes, sounds and files, which Godot's FileSystem dock and Quick Open already do. A scene, script or sound is opened, found or dragged the Godot way. Dragging a class, sound or scene out of that strip onto the canvas is gone with it; drag from the Objects list or the FileSystem dock instead.
- The Welcome page's "coming from another event-sheet editor" answer no longer switches the bar on, and its summary lines no longer mention it. The two Project bar colours are gone from the theme tokens. The word the familiar vocabulary used for the FileSystem dock is now "FileSystem dock", and the editor-tool row that reveals a file reads "Show in FileSystem dock" (its id and the code it writes are unchanged).
- The Start page's "This editor" card now just opens the plugin's own script as a sheet.

### Removed: the Objects list no longer lists the rest of the scene

- The "Also in the scene" section is gone. It repeated Godot's Scene dock. The list keeps the objects the sheet itself uses, with their counts, the filter, the right-click menu and dragging onto the sheet. The tab's hover no longer counts the scene's other nodes.

### Removed: object marks - Godot's groups and exported variables decide the canvas offers

- The plugin's own per-project "marks" (secret, water, needs key) are gone, together with the store that held them. Dropping an object on the canvas now asks Godot itself: a node in the group `secret` is offered the secrets counter, a node in the group `water` is offered the two rows that raise and lower the in-water flag, and a node whose script exports `needs_key` is offered the door event. Add a node to a group in the Node dock, Groups; the answer lives in the scene file, so it travels with the scene and the plugin keeps nothing. An object the open scene does not hold is offered nothing extra. Old projects that still hold the three metadata keys load as before and ignore them. The Secrets guide, Working In 3D, the Mark Secret Found and Try Door descriptions and the Keycard door starter note say how. The boomer_level showcase puts its SecretRoom in the group `secret`. No emitted GDScript, `ace_id` or block `kind_id` changed.

### Changed: "Instance variables" now reads "Variables"

- The head folder, the Add menu and context menu items, the Add variable shortcut label, the variable list headings in the picker ("Player - variables"), the guided tour, the tutorials and the guides all say "variable" and "Variables" now. The pack folder "Internal state" is unchanged. Only wording changed: no name in the emitted code, no `ace_id` and no block `kind_id` moved. The nine translation files carry the new words.

### Removed: the Properties bar

- The panel to the right of the sheet that showed the selected condition, action, group, class or object as fields is gone, along with its View > Properties Bar item, its drag handle and edge strip, and its width setting. The sheet now uses the full width. Every edit it offered has a place that stays: double-click a parameter for the Edit Parameter dialog, edit a group's name and switch on its own row, and edit the class name, base type, icon, tool switch and description on the sheet's head row. A selected function still opens in Godot's own Inspector. Layouts saved with the bar open or tucked load as before and simply ignore its width.
- The "Change type" question that listed the members an event uses and the new type lacks was only in the bar, so it is gone too.

### Removed: the Object properties window

- Clicking an object's name in a row no longer opens a window. A click there now only selects the row, like a click anywhere else on the cell. The window repeated what Godot already shows: the Scene dock for the hierarchy, the Inspector for values. It also carried a Hierarchy section (add a child by dragging, unparent, flags), a variables table and the buttons Add condition, Add action, Highlight rows, Select in scene and Show in code. Add condition, Add action, Highlight rows and Select in scene are still on the Objects list (right-click or click an entry). Show in code has no other door. Double-clicking an entry in the Objects list or a class in the Project bar opens nothing now, and View > Object Properties is gone. The flags chip on an Add child row stays.

### Removed: the Inspector's variables table

- Selecting a node whose script came from a sheet no longer shows an "Instance variables" table at the top of the Inspector. Godot's own Inspector already lists every `@export` variable of the script as an ordinary row, so the table repeated them. The "Shape ..." link and the Edit Event Sheet button stay.

### Changed: more air between events in the Editor Native look

- Two events in the Editor Native look are now 6 px apart instead of 1, so each reads as its own event and not as a continuation of the one above. The conditions and actions inside one event are exactly as tight as before, and a sub-event still sits 1 px under its parent. The README pictures of the workspace and of the Generated GDScript panel were retaken to show it.

### Changed: clicking beside the sheet clears the selection

- A click in the strip left of the sheet (the side panel's rail) or right of it, outside every event and variable, now clears the selection, the way a click on the empty canvas does. The sheet keeps keyboard focus, so Delete after that cannot reach the Scene tree. Ctrl and Shift clicks there change nothing.

### Added: a behaviour says what it changes on its parent

- A behaviour that writes into the node it works on now says so in its description, which shows in the Add Node window and the Inspector. For example "Changes on its parent: up_direction, velocity, move_and_slide()." A behaviour that only reads its parent says nothing. The line is read from the behaviour's own code each time the pack is built, so it cannot fall out of date.

### Added: Acts on, for a behaviour that is not a direct child

- Every behaviour that works on a node of a certain type (Platformer Movement, Bullet, Anchor, Sine and the rest) now has an Acts on field at the top of its Inspector. Leave it empty and the behaviour works on its parent, exactly as before. Set it, and the behaviour can sit anywhere in the scene, for example under a Behaviours folder node.
- The Doctor and the warning in the Output both say "or set Acts on" as the second way out. Scenes saved before the field existed load with it empty, so nothing in them changes.

### Added: the Doctor says when a behaviour is under the wrong node

- Check the project now reads every scene and says it when a behaviour sits under the wrong kind of node, before the game runs. For example "Platformer Movement is under a Node2D; it needs a CharacterBody2D: put it under one." The finding offers "Move it under <the nearest node that fits>" and "Show in scene".
- A behaviour that cannot find its host says the same words in the Output while the game runs, in place of "PlatformerMovement behavior requires a CharacterBody2D parent." The behaviour scripts stay ordinary scripts that work in any project without the plugin.

### Changed: the Family Arena showcase teaches call down, signal up

- Each Enemy now moves itself: its own sheet has an Every tick row that moves it by its own fall_speed and wraps it back to the top. The arena sheet no longer reaches into the enemies to move them; it spawns them and runs the one rule that is about the whole family, a strike that walks every Enemy with a typed For each (`for enemy: Enemy in ...`) and may hit each one through Enemy: Take Damage. The showcase plays the same: enemies fall, the strike hits them, they die.

### Added: a picked instance is an object in Add action and Add condition

- Inside a pick (a For each, Pop back / front into, Pick nearest / first where / random, a typed local, or a signal that hands the event its instance) and every sub-event under it, Add action and Add condition list the picked instance at the top of the objects page, by its type (Unit, Enemy; its name as written when two picks share a type). Choosing it offers that class's own rows and those of what it is a kind of (Node2D: Set position, Set tint, Hide), each already aimed at the picked name. Outside the pick it is not offered.
- Rows on a picked instance read as that object's rows, whether hand-written or picked: `unit.start_turn()` reads "Unit | Start turn", and a test such as `unit.health < 20` reads "Unit | health < 20". A For each written with a typed item (`for unit: Unit in selected`) is understood as a pick, and a sub-event or an Else under it keeps it.
- Where a row needs a value, the expression picker has a "Picked here" section with the instances the event picked or was handed by its trigger, so Push back, Delete value and Contains do not need the name typed.

### Changed: findings draw no frame, and long sentences are read whole

- A row with a finding is a faint tint and an amber event number (red for one that cannot run). The amber frame round the whole event is gone.
- A finding's sentence that does not fit the status bar is said whole, wrapped, on a line of its own above it, with the doors left in the bar.
- A For each or other loop cell wraps in the condition lane like any other long condition instead of being cut mid-word.

### Added: a pick lasts for its event and its sub-events, and nowhere else

- A For each, a Pop back / front into and a typed local are picks. A row under one that acts on the picked name now shows the picked TYPE in the object column (Unit, Enemy); when an event holds two picks of one type (an attacker and a target) each shows its name as written instead. A sub-event inherits the pick, and a sibling event starts with nothing picked.
- A row that acts on a name another event picked, where nothing by that name is picked, is an amber row. The help strip and the Doctor say "No Unit is picked here", with the doors Pick the Unit from a group (for a declared family) and Pick the Unit from a list (when the sheet has an Array of that type); each adds the pick to the event in one undo step.

### Changed: the pick rows can choose their set from a group or a list

- Pick Nearest, Pick A Random One, Pick Where, Pick First Where, Pick Last Where, Pick Top and Pick Bottom have a "Choose a group or list" dropdown beside their From box. It lists the project's groups first (a group is Godot's way to keep an unordered set of nodes, and it drops a destroyed one by itself), then the sheet's own list variables, then the lists of nodes below the sheet's node. Choosing writes the expression into the box, which stays free text. A pick never removes from the list; to take the picked one out, follow with Delete value.

### Added: a group is Godot's way to keep a set of nodes, and the sheet says so

- An Array of nodes that the sheet never reads by position or order (only push, delete, contains and For each) is an amber row. The help strip and the Doctor say a group is the Godot way and that it drops a destroyed instance by itself. The door Use a group instead rewrites the rows in one undo step: Push back becomes Add to group, Delete value becomes Remove from group, Contains becomes Is in group, For each over the list becomes For each in group, and the list's declaration goes. The door is only offered when every use of the list is one of those.
- An ordered list of nodes that is looped over and never has a destroyed instance taken out of it anywhere on the sheet is amber too, with the door Drop freed instances first, which adds an event above the loop with that row.
- A row that names a list of a parent, a sibling or an Autoload gets a note (never an error): it keeps working, and the words suggest asking that object through a function or a signal.

### Added: three rows for lists of instances

- Push back, once adds a value only when the list does not hold it already (`if not selected.has(unit): selected.append(unit)`). Push back is unchanged, so a deck can still hold two of a card.
- Set to the instances in a group where a test fills a list from a group in one row (`selected.assign(get_tree().get_nodes_in_group("units").filter(func(one): return box.has_point(one.position)))`). When order does not matter, the group itself is Godot's own tool: it forgets a destroyed instance by itself.
- Drop freed instances from a list removes the entries whose instance was destroyed (`selected.assign(selected.filter(is_instance_valid))`), for ordered lists that nothing else cleans.
- Each spelling, written by hand, opens as its row and saves back to the same bytes.

### Changed: a list row reads under its list

- Every row on the Variables: Array page (Push back, Pop back into, Move back to, Clear, Is empty, For each popped...) now shows the list it acts on in the object column, written as the row writes it (`undo_stack`, `$Enemy.draw_pile`), with the variable mark, where it used to say System. Only the reading changed: the rows, their words and the code they write are the same.

### Changed: the Array dropdown offers only the sheet's own lists and those of nodes below it

- The list fields used to offer the arrays of any object in the scene and of every Autoload. They now offer the sheet's own arrays and the arrays of nodes below the sheet's node (`$Child.items`, `%UniqueChild.items`). A parent, a sibling or an Autoload is asked through a function or a signal instead. A row that already names one keeps working and keeps its text when edited.

### Fixed: the shipped-pack warning and the swap refusal say it once, in full

- The warning on the first edit of a shipped behaviour file ("is a shipped behaviour: adding a newer version of the pack replaces this file and your edits.") used to share the status bar with the counts and was cut off. It now has a line of its own above the status bar, at the dock's whole width, wrapped, with the Edit it anyway door beside it.
- Swapping two typed arrays of different types said the same sentence under the field, in the help card and beside Done. It is now said once, under the field; the help card keeps describing the field, nothing is written beside Done, and Done stays blocked.

### Changed: the help card in every window is a plain panel

- The card that explains the focused field (and the Doctor and row help strips built from it) no longer has a coloured outline or a thick coloured left edge. It keeps the thin hairline every inset panel has, like Godot's own docks. Its heading is the muted caption colour; only a warning (amber) or an error (red) colours the heading.
- The one-sentence note under a field (a name already in use, a node not in the scene yet) lost its coloured left edge too. It keeps the faint tint of its tone.
- The small badges beside a page title ("Action", a pack's name) and the chosen cell of the animation frame strip lost their coloured outlines; each keeps its tint. A field that cannot be accepted still shows its red outline, because that one is a state.
### Added: Pop back into and Pop front into, and Stack and Queue groups in the picker

- Taking an item off a list used to be an expression (`Set last to undo_stack.pop_back()`), so a pop hid inside another row, and a pop used twice in one row, or in a condition that runs every frame, silently ate items. The Variables: Array page now has two actions that keep what they took in a name you choose: Pop back of a list into a name (`var last = undo_stack.pop_back()`) and Pop front of a list into a name (`var job = jobs.pop_front()`). Push back is the row it always was.
- The same page gains two groups that only help you find the words: Stack (a stack pushes and pops at the back: last in, first out) lists Push back, Pop back into and Back, and Queue (a queue pushes at the back and pops at the front: first in, first out) lists Push back, Pop front into and Front. A row says the same thing wherever it is listed.
- A hand-written `var name = list.pop_back()` or `pop_front()` opens as its row and saves back to the same bytes.

### Added: an If empty field on the pops, and Back / Front with a fallback

- Popping an empty array prints an error in Godot and hands back nothing. Pop back into and Pop front into now have an optional If empty field. Filled, the row writes `var last = undo_stack.pop_back() if not undo_stack.is_empty() else Vector2i(-1, -1)` and needs no guard. Left blank it is the plain pop, and the row's help says to guard it with Array Is Empty, inverted (the cross), the guard that already exists. The guarded one-line pop opens as the same row.
- Two new expressions, First Item (or a fallback) and Last Item (or a fallback), read the front or the back without removing it and give your own value when the list is empty. First Item and Last Item are the rows they always were.

### Added: Move back / front to, Move all to and Swap, and the Array dropdown offers another object's arrays

- Moving items between two lists is one row now instead of two hand-joined rows and a temporary: Move back of a list to another (`redo_stack.append(undo_stack.pop_back())`), Move front of a list to another (`pop_front()`), Move all of a list to another (`other.append_array(list)` then `list.clear()`, in order), and Swap two lists (a temporary named `__swap_` plus the row's own id, then the two writes, so two swaps in one event never collide). Each opens again from the same hand-written lines and saves back to the same bytes; a swap through any other temporary stays the plain code it is.
- Every list field is the Array variable dropdown, and it now also offers the arrays of the other objects in the scene after the sheet's own: `$Enemy.draw_pile`, `%Deck.cards`, an Autoload's list. A row that already names one keeps it when you edit it, even with that scene closed.
- Swapping two typed arrays of different element types is refused in the parameters window with one line naming both types ("undo_stack is Array[Vector2i] and scores is Array[int], and a typed array only holds its own type."). An untyped Array on either side is not refused.

### Added: For each popped from the front / back of a list

- Working through a queue used to be a While and a take kept in step by hand, where a forgotten pop is a frozen game. Two loop conditions on the Variables: Array page, For each popped from the front of a list as a name and For each popped from the back, run their event once per item and take each item off the list as it is used (`while not spawn_queue.is_empty():` then `var scene = spawn_queue.pop_front()`). The list is empty when the loop ends, and items pushed while it runs are handled too.
- A hand-written `while not L.is_empty():` whose first line takes from the same list opens as this loop and saves back to the same bytes; a while with any other body, `remove_at(0)` instead of `pop_front`, or a take from another list stays the While it is. The "While nothing inside can end" warning stays quiet for it, because the take changes the list. The For Each dialog gains the two matching collection choices so editing the loop never turns it into a plain walk.

### Added: Push back, keeping the last N

- A trail, a replay buffer, an input buffer for combos or the last few chat lines was an append and a trim loop written separately. One action does both: Push back a value to a list, keeping the last N (`trail.append(point)`, then `while trail.size() > 20:` and `trail.pop_front()`). The oldest items drop off the front, so the newest stays. The three-line run opens as this row; a trim written with `if`, or `remove_at(0)` instead of `pop_front`, stays the rows it is today.

### Fixed: a pop knows its type

- Taking an item off an `Array[Vector2i]` left the local untyped, so autocomplete and the type check knew nothing about it. Pop back into and Pop front into over a typed array now write `var last: Vector2i = undo_stack.pop_back()`, and the loop For each popped from the front / back types its item the same way, so `last.` offers `x` and `y` and a wrong use is caught as you type. An untyped Array gives the untyped local it always did, and a hand-written `var last = undo_stack.pop_back()` keeps its spelling (the type is added only when the row is made on the sheet); a hand-written typed pop opens as the row with its type kept.
### Changed: your own scripts have no lock on their functions

- A function in a script you opened (an `On function` event) is now editable like any event from the first click: drag an action, double-click it, Add action, Delete, with no menu step first. Before, every hand-written function opened read-only until you found Make Function Body Editable in its right-click menu. An edit still rewrites only the lines of the rows it changes, and an untouched function still saves byte for byte. The menu item stays for anyone who wants a function read-only, renamed Lock this function / Unlock this function; a locked function reads grey, and a drag on it says which menu item unlocks it.

### Added: a shipped behaviour pack asks once before its first edit

- A script in one of the plugin's own pack folders (under `eventsheet_addons/`, including a pack copied into your project from the library) keeps its function bodies locked. The first drag, double-click, Add action or Delete on one says in the help strip: "<file> is a shipped behaviour: adding a newer version of the pack replaces this file and your edits.", with one door, Edit it anyway. The door unlocks every function in that file; the gesture that asked is not performed, so you repeat it. Undoing an edit never locks the file again.

### Added: lock and unlock choices are remembered for the project

- A function you lock or unlock, and a pack file you unlock with Edit it anyway, stay that way after you close and reopen the editor. They are kept in the project's editor settings, the same place folded regions are, and never in the `.gd`, so the file and a teammate's copy are untouched.

### Fixed: dragging an action inside a function's body moves it

- In a function you wrote by hand (such as an "On function hit" event), dragging one of its actions to reorder it, or onto another event, did nothing at all and said nothing. The drop marker now shows inside the function, the action moves (with its quiet note, if it has one), the file saves with only those lines moved, and Undo puts it back in one step.

### Fixed: expression conditions that name `delta` keep their colour

- Once `delta` stopped being respelled `dt`, a condition such as `entry.integrate(delta)` or `_separate(delta)` stopped being drawn as the coloured expression it had always been (the reader only coloured an expression it had reworded). It reads exactly as written and wears the expression colour again.

### Changed: a `#` note among a function's statements is the note of the action below it

- A `#` line written directly above a statement inside a function is now that action's quiet note (it reads after the action, muted) instead of a separate comment row in the action lane. Moving the action moves its note, copying it copies it, and the file saves back to the same lines. A TODO or FIXME note, a note kept apart from the statement by an empty line, the note that opens a body, a commented-out statement and a `##` documentation line stay comment rows.

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

### Added: twelve juice cards that change the scene, the light, the look and the sound

The Add box gains Collision For A Time, Collision Layer For A Time, Remove Node, Draw Order For A Time, Switch Node On Or Off, Look At, Rotate By, Rotate To, Rotation Shake, Light, Scene Look and Bus Effect For A Time. A card that changes something for a time writes down what it was before the FIRST card touched it and gives it back when the LAST card holding it is done, even when two cards, or two Juice Players, changed the same thing (a shape switched off by a hit and again by a dodge cannot stay off for good); Stop Juice, Revert, Restore Initial Values and the player leaving the scene give everything back at once, and a Skip To End leaves the timed ones out. Measured frame by frame on a running tree at 60 frames a second: a shape switched off for 0.25 s from inside `body_entered` is off for 15 physics frames and Godot prints nothing (set directly it prints an error and does not apply); a mask layer taken off for 0.25 s gives one `body_exited` and comes back; Remove Node with After this list ends frees the node on the frame the list finishes, hands a node from an object pool back to it, and is cancelled by a Stop before the end; a z index of 5000 or -9000 is held at 4096 or -4096 (Godot refuses past that); a node switched off for 0.25 s is hidden, its scripts stop and its shapes are disabled for 15 frames, and a player under it freezes with it; Rotate By 90 over 0.2 s lands on 90.0 exactly, Rotate To takes the short way round, a Control turns about its middle, a RigidBody is refused with a plain message, and Rotation Shake ends on the angle it started from; Look At ends on the same angle as Godot's own `look_at` (0.463648 in 2D, within 0.000001 in 3D) and a target at the same place or straight above raises no error; a Light flares to 2.948 by the frame it is sampled and lands on exactly 1.000000 and its own colour again on all five light classes, and a light that was off is on for the flare and off after; Scene Look walks `glow_intensity` 0.3 to 2.0 and back to 0.300000 on the scene's own copy of a shared Environment file, with the file's bytes and object untouched and the original put back by Stop; a muffle walks a bus 2000 Hz to 400 and back to exactly 2000, and the way back still happens when the player is freed. Draw Order, Rotate By, Rotate To, Look At, Rotation Shake and Light play in the editor's preview, on the node they point at; the others say in Debug view why they are not shown. A node picked of a class a card cannot use, a RigidBody given to a turning card, a node that holds the player and a camera that ignores rotation each get one quiet amber line. Scene Look offers the glow strength and every value of the environment and the lens the shipped fade rows offer, read off the same word tables. A card of an older kind plays and saves exactly as before.

### Fixed: the head bar reads a list of juice cards that Godot saved over several lines

The head bar's behaviours card was meant to read a Juice Player's list as `steps = 6 cards`, but a scene saved by Godot writes that list across many lines and the card kept only the first, so it read `steps = Array[Dictionary]([{`. The scene reader now joins a value that runs over several lines (a list, a dictionary) until its brackets close, so the card reads the whole of it, and a bracket inside a quoted word does not end it early. Seen in the real editor, before and after, on a scene with three players holding 12, 10 and 7 cards.

### Changed: the preview's tick reads "Repeat the preview", and the line over the list says what its time is

The strip under a Juice Player's list had a Repeat tick that read "plays again each time it ends", which looked like the Loop tick on the node; it now reads "Repeat the preview" under the label Preview, and its tooltip names Loop as the game's own loop. The line over the list read "4 juice cards - 0.40 s total" for a Flash of 0.10 s, a Pause of 0.40 s and a Loop Back of 0.25 s, a number nobody could add up: it is the time of ONE pass (the cards between two Pauses or Holds start together, and what a Loop Back or Loop repeats comes on top), so it now reads "0.40 s once through" and says so in its tooltip.

### Added: three juice cards for springs, time and animation

The Add box gains Spring, Slow One Object and Animation Parameter. Spring kicks a value of a 2D node, a number, a Vector2, a Vector3 or a colour, in its own kind and its own units a second, and lets the Spring node under it bounce it back to rest; the Damping and Swings a second boxes are the Spring node's own two numbers and are left alone until touched. A node with no Spring node, and a Control or a 3D node, each get one quiet amber line instead of a silent nothing. Slow One Object slows the animation players, animated sprites and particles at or under a node through their own speed, then puts it back; a line under the card lists what it found, and says plainly that scripts of your own keep their speed, because Godot has nothing to slow them with, and that the speed multiplies with Slowmo. Animation Parameter moves one parameter of an AnimationTree to a value and brings it back, and lists only the parameters the tree really has and lets you set, never a read-only time, a state machine's playback object or the timers a one-shot keeps for itself. Measured frame by frame on a running tree at 60 frames a second: a scale kick of 3 swings 0.291 from rest and lands on exactly (1, 1); a rotation kick of 8 swings 0.549 radians and lands on exactly 0; a colour kick lands on exactly white; Stop in the middle of a bounce settles the value at rest at once, and a player freed in the middle leaves the Spring node to finish it; a speed of 0.3 for 0.5 s reads 0.3 for 30 frames and 1.0 on the 31st, advances the animation 0.305 s in the 40 frames where an unslowed one advances 0.667, and under a Slowmo of 0.5 at half speed advances 0.129 s in 30 frames (a quarter of the time), with Stop and a freed player both putting the speed back to 1.0; a blend amount walks 0 to 1 in 12 frames and back to exactly 0 in 12 more, Stop leaves it where it got to and Restore puts back 0, and a one-shot's request set to 1 reads 0 again after its time. None of the three plays in the editor's preview (Debug view says why), and a card of an older kind plays and saves exactly as before.

### Added: the Godot name under a card's fields, and three more entries in a card's menu

Under each field that sets something Godot has, a card now shows in small print the Godot name of it (`Light2D.energy`, `CollisionShape2D.disabled`, `Camera2D.offset`), always the class that declares it; hover it for a line on what it is, and the ? beside it opens that member's page in Godot's own help. A card's menu gains Show as rows, which shows the line that adds the card from a sheet or from code (the Add Juice Card row with the card as its value), Show as GDScript, which shows the same effect written by hand in plain GDScript ready to paste into the object's script, and Open in Godot help. Both shown texts are put on the clipboard too, and the GDScript is labelled as what it is: the plain version, without the strength, the accessibility setting, the timing or the way back that Stop and Restore use. Forty-nine of the fifty-seven kinds have a plain version, each one parsed by a test with no plugin in it; the screen effects (Shockwave, Chromatic Kick, Pulse Vignette, Hold Effect) draw over the whole screen with a shader, and Stop Sound, Hold, Loop Start and Loop Back move the head of a list, so Show as GDScript is greyed for them and says so. Every kind can be added from a row of its own words, which a test walks.

### Changed: the Light card says where it starts, Collision Layer For A Time lists the project's layers, and Bus Effect For A Time takes off what it added

The Light card has an Energy box and a Colour box that each begin as "From where it is", which is what every card saved before did, so a saved Light card plays the same frame for frame (1.643, 2.218, 2.663, 2.932, 2.948 and on, as before); type a number or pick a colour to begin somewhere else and the flare still goes back to where the light was. Collision Layer For A Time picks its layer from a list of the thirty-two, each read as its number and the name Project Settings gives it (`3 - Walls`), a layer nobody named reading as its number, and the card still stores the number. A Bus Effect For A Time card that had to add an effect because the bus lacked one used to leave it on the bus for good, and its own help said so; it now takes the effect off again when its way back is done, on Stop and Restore, and when the player is freed, and forgets where the bus rested, so the bus layout ends identical to how it began (measured: no effect before, one while the card holds, none after, for a muffle, a dive and a wash; two overlapping cards share the effect until the last is done; an effect the project put on the bus itself is never touched). The card's help and the three lines under its number now say so.

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
