# Changelog

The work not yet released is listed first, under `[Unreleased]`. Each released version keeps its full notes in its own file under `docs/changelog/`, and the index at the bottom of this file lists them newest first. A release moves its section out of `[Unreleased]` into `docs/changelog/vX.Y.Z.md` when it is cut.

## [Unreleased]

### Fixed: Add > Global Variable makes a file Godot can run

- The first global of a project made its file blank: no `extends Node`, so Godot refused to start the autoload, and the first variable was then written above the `extends` line of any file that had none yet. The new file now starts `extends Node` (no generated banner, a one-line class doc), the first global lands after the head, and the sheet carries no class name - Godot refuses a script whose `class_name` equals the autoload it is registered as ("hides an autoload singleton"). The Entity System starter no longer sets a class name equal to its autoload name for the same reason. A sheet that already holds both names emits the same bytes as before.
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
