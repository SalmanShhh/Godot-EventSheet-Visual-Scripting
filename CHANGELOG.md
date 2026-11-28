# Changelog

The work not yet released is listed first, under `[Unreleased]`. Each released version keeps its full notes in its own file under `docs/changelog/`, and the index at the bottom of this file lists them newest first. A release moves its section out of `[Unreleased]` into `docs/changelog/vX.Y.Z.md` when it is cut.

## [Unreleased]

### Added

- **Old moment files become Juice lists, by themselves.** Open an old moment file (alone, or in a Juice Player's Moment File slot) and its steps already show as juice cards instead of raw dictionaries; the first edit turns the file into a Juice list in place, with the same path and uid so every scene and script pointing at it keeps working, and one Ctrl+Z gives the old file back. A file you only look at is never rewritten. The Project Doctor adds a note, "N old moment files can become Juice lists", with a button that converts all of them in one undo step, and the FileSystem right-click menu has **Make a Juice list** for a selected old file. An old file and its converted file play the same cards. A running game never converts anything; a script that does `load("x.tres") as MomentResource` gets nothing back from a converted file, which the Doctor note says in plain words
- **A Vibrate card pulses with its Timing foldout, and Stop quiets it.** Repeat and Every on a Vibrate card buzz it a number of times, and the card's help now says so instead of pointing at Loop Start. Stop, Restore and leaving the scene cancel the pulses still to come and stop the motors the player started (a phone cannot be told to stop). A card with no Repeat buzzes once, as before.
- **A Juice list file to share between objects.** A new `JuiceList` resource holds a Juice Player's whole list, every kind of card with every setting, and is edited in the Inspector with the same card editor the player has, whether the file is opened on its own or shown in a player's Moment File slot (where the Play buttons play it on the selected player). Drop it on the slot of as many players as you like: edit the file once and every one of them changes, in the editor and in a running game, and two players can play it at the same moment because what a play counts down stays with the player. For one object's own tweaks, use Godot's own Make Unique in the slot's menu. Save as file under a player now writes a Juice list with every card in it (a Sound card, a Hold and a Loop are no longer left behind), and old moment files keep loading and playing in the same slot.
- **Choose which controller a Vibrate card rumbles.** The card has a Controller choice: every controller (what older cards do), the one used last, or controller 1 to 4. Scripts get `vibrate_controller(number, weak, strong, seconds)`, `vibrate_last_used(weak, strong, seconds)` and `last_controller()` beside the unchanged `vibrate()`. The card says plainly that a phone has one motor and uses the stronger strength, and that an iPhone may ignore the strength.
- **The Doctor checks the Android Vibrate permission.** When the project vibrates and an Android export preset does not have the Vibrate permission ticked, the Doctor warns in plain words and says where to tick it. It only reads `export_presets.cfg`.
- **A typed function behind every juice card.** On a typed variable (`@onready var juice: JuiceBehavior = $Juice`) Godot's editor now completes every juice effect with named, typed arguments, and a misspelt one is a parse error. The Juice Player gained about fifty (`pop`, `fade_node`, `shake_position`, `restart_particles`, `push_away_from`, `flare_light`, `tween_property` and so on), the Juice nodes gained `shake_timed` (a shake with a shape, also on the 3D node), and Screen FX gained `hold_post_effect`. A card and a line of code reach the same function, so they cannot disagree, and a card list saved in a scene plays as before. Every new function is hidden from the picker. Cards that only move the head of a list (Pause, Hold, Loop Start, Loop Back) have none on purpose; a Juice guide section, "Juice from code", maps each card to its function.
- **A Grayscale card and Screen FX rows.** Puts the colour out of the whole screen or out of a circle that grows from this object or from a place on the screen (or the other way round, a circle of colour in a grey world), with edge softness, and can stay grey until told for a death or a flashback. Rows: Grayscale, Grayscale From Point, Clear Grayscale. It is the shipped Desaturate effect, so the reduced-effects dial and the no-flashing choice hold it, and it works over a 2D and a 3D view.
- **A Position Shake card and rows.** Shakes only a node's position (never the camera, rotation or scale) and puts it back exactly, with fade ticks, a curve, X, Y and Z weights and a jump rate; two at once add and a node that moves meanwhile keeps its own motion. Rows: Shake Position and Stop Position Shake on the Juice and Juice 3D nodes. For a 3D game, put a Juice 3D node beside the Juice Player and the Shake card shakes the 3D camera; a Shake card with ticks or a curve now keeps its shape over a 3D view too.
- **Typed variables for the nodes a sheet calls.** A sheet that calls a behaviour on a child node now compiles `$HudKit.set_text(...)` as `hud_kit.set_text(...)`, with `@onready var hud_kit: HudKitBehavior = $HudKit` written once under the class head, so Godot's editor completes what the node can do and a misspelt method is a parse error rather than a surprise at run time. A script made before this opens and saves byte for byte in its own form; the first edit moves it to the new one (Undo puts the old one back). A handler Godot runs before `@onready` (`_init`, `_enter_tree`), a `static` function, a class inside the file and a node whose class the sheet does not know keep the path. The Doctor says in plain words when the scene's node is not the kind the script declares. The showcases use the new form.
- **Named words for the choices a verb takes.** Each verb whose parameter is a dropdown of words (`ease`, `side`, `space`, `mode`, `direction` and the rest) now has those words as documented constants in its pack (`EASE_EASE_IN`, `DIRECTION_LEFT`), and the verb's description names them. The verbs still take the same text, so saved scenes and shipped rows are untouched.
- **A typed answer from the compile calls.** `EventSheets.compile_result()` and `EventSheets.echo_result()` answer with an `EventSheetCompileResult` (`success`, `output`, `errors`, `warnings`, `source_map`, `refused_path`) beside the Dictionary the existing calls return, which is unchanged.
- **Class names for the Post Kit effects.** The six effect scripts and the base class they share now publish `PostKitVignette`, `PostKitDesaturate`, `PostKitPixelate`, `PostKitTint`, `PostKitFade`, `PostKitOutline` and `PostKitEffect`, so a script can name one.

### Fixed

- **An old moment file's help matches the cards it shows.** The line above its steps still listed verb words (shake, hitstop and the rest) to type into a dictionary; it now says what you see, one card per thing that happens, and that the first edit turns the file into a Juice list with the same path. The class and the file format are unchanged.

## Releases

- **v0.21.0** (2026-11-20) - Small to Large
  This release makes the plugin hold up on a big project and finishes the move to Godot's own words and tools. A sheet opens, saves, renames and checks without holding the editor, a Juice Player can hold hundreds of cards, a script you wrote is never overwritten, and dozens of windows and panels that repeated what Godot already does are gone. It is a large release (about 900 commits since v0.20.0), and a few things in it change what you must do when you upgrade, listed in their own section below.

  **What you can do now**

  - Make a game feel good from one list. The old Feedback Player is now the **Juice Player**: a node that holds a list of juice cards (shake, hitstop, slow motion, zoom, sound, light, particles, spawn a scene, animation, spring, count-to, fill a bar, fade, push, punch, call a method and more). Add a card from a box grouped by family, copy, cut, paste, duplicate and delete cards with Godot's own keys, play one card or play from a card down in the editor without running the game, loop the whole list, stop everything, and switch all juice off at once. A Juice 3D node plays its cards over a 3D view, and you can write a card of your own as a script that extends `JuiceCard`.
  - Draw with the **Drawing Prefab**: arcs, pies, rounded rectangles and regular polygons join the shape list, each shape's line draws its own picture and says its size, and the list can open as a table or as cards. A shape you click in the picture selects its card.
  - Add your own numbers to Godot's **Monitors tab** with four new rows (Show In Monitors, Remove From Monitors, Is In Monitors, Custom Monitor Value), and read a new guide, "Is my game slow", that walks from "is there a problem" to the fix.
  - **Find a row by what you would call it.** Typing slow, lag, stutter, fps or profiler in the picker finds the measuring rows first. Rows now carry search words of their own, the best match is ranked first, and the top row is already selected when the list opens, so a search word and Enter adds it. (A real editor was driven for this: typing "floor" and pressing Enter added Is On Floor, and typing "print" and Enter opened the Print parameters.)
  - **Build at run time with rows**: Add New Node, Add Behaviour, Remove Behaviour, Add Sprite, shapes, Add Timer, Add To Group and Keep As Prefab each write the plain Godot lines you would type.
  - **Press Preview** on eighteen behaviours (Sine, Orbit, Wave, Flash, Spring, Juice and others) to watch them in the editor while you tune their values. Your scene is never changed by a preview.
  - **Make an Inspector look as an event sheet**: a sheet that extends `EventSheetInspectorLook` reads its three Inspector callbacks as triggers.
  - **Edit a theme file in the Theme Editor** and save it; every colour has a dark swatch and a light one, and a sheet wears the side that matches Godot's editor. Right-click a theme in the FileSystem to edit it, and name a project theme in Project Settings.
  - **Rebind the controls and save options and a quick save**, with two new showcases (Input Rebind rebuilt, Options and Quick Save), a Save Studio guide rewritten to its five tabs, and a Game Settings pack whose capture now works with Space, Enter and a pad's A, cancels on Escape, and takes its file from `settings_file`.
  - **Pooling made clear**: a new Object Pooling showcase counts sparks made against sparks reused (ten seconds in the running scene: 1,198 sparks from 146 nodes with the pool, 1,200 sparks from 1,200 nodes without it) and a guide to pooling. **Retire now works when the Object Pool is a child node of a scene**, not only as an autoload: the pool stamps itself on the nodes it holds or hands out, and a chip says "pooled as" for a pool under another name or held in a typed variable.
  - **Stacks, queues and lists of instances** (Pop back into, Pop front into, Push back once, Set to the instances in a group), **Godot's own drawing calls** as actions under On Draw, and **the everyday object rows** (Set Opacity as a percent, Set Scale, Set Size, Once Ever and others).
  - **Tidy This Script** (Sheet menu) writes an older script the way the editor writes it today, after showing every line as `before => after`, as one undo step. It only runs when you choose it.
  - **The picker, the Doctor, the tutorials, the Manual and the Start window read in your language.** The nine tutorials' titles, leads and every step's text (50 steps) and hint lines, the Doctor's sentences, the Manual's contents dividers and fixed words, the Start window's shelf headings and the Manual's tutorial search all work in the nine editor languages. A behaviour pack's own translation file now only adds messages: it can no longer override a word of the editor's (a pack's "Manual" row used to).

  **Safer with your own files**

  - **Save never writes over a script you wrote.** A sheet saved as a resource writes its script beside it; the plugin now overwrites that script only when it can prove it wrote it for this same sheet. Anything else is left byte for byte and one sentence says what to do.
  - **Renaming a file in Godot's FileSystem keeps your work.** The open tab follows a rename, a move or a folder move with its unsaved edits and undo history; a sheet deleted behind unsaved edits keeps them (a copy goes into the backups); the sheet's compiled script goes with it, and what the editor remembered about the file follows too.
  - **Find and replace in the project** lists every place it will change, with a tick on each. Sheets start ticked, scripts you wrote start unticked, behaviour packs are never changed, a replace can be put back whole, and a sheet open in a tab changes through that tab's own Ctrl+Z.
  - **Ctrl+Z works where it did not**: attaching, moving a node's behaviour, Input Map changes, Include sheet and the Doctor's "Move it under". Actions that cannot be undone now say so, and Export Addon, Restore, Save Moment, the grid and chunk files ask before they overwrite.
  - **Quitting, Save All and Run** no longer lose a sheet's unsaved edits; a text saved as csv, ini or xml keeps its line breaks; and a Save Studio that finds a `SaveSystem` global you already had asks first.
  - **A script you open that holds rows with no newer spelling** now answers: its head says "N rows ask you", and clicking that line opens the Migrate window straight away, even while the script is still the read-only preview it opens as. The window lists every such row (it used to hide the last one), the head and the window count the same rows, and nothing is rewritten for you.

  **Fast, and calm, on large projects**

  All figures are in the CHANGELOG unless marked.

  - **Check the project** no longer freezes the editor. On a project of two thousand scripts it took five minutes with the editor frozen and printed two thousand warnings into Output; now it works a few milliseconds at a time, shows its progress, has a Cancel that works and does not print its findings into Output. On a scratch project of ten thousand files the first audit took 278 s with 588 frames over 100 ms (worst 10.3 s); after the last pass the whole audit takes 57 to 67 s (three runs) against 83 to 97 s before that pass, with 5 or 6 frames over 100 ms and a worst frame of 0.33 to 0.37 s. The findings are the same, in the same order, at ten thousand files. The window is up in about 40 ms at every size. It also gains a search box and its sentences read as sentences. (The earlier draft of these notes and the CHANGELOG said 75 s against 133 s; that was the pass before the last one, and the CHANGELOG now carries the later figures.) In a real editor on a small project the Doctor ran to the end in about two seconds, dark and light.
  - **The first scene save with a sheet open** used to take about 7 to 20 seconds in this project; it now takes 130 to 160 ms. At 200 files it fell from 7 to 8 s to 165 to 300 ms, and at 10,000 files from 37 s to 163 to 293 ms (scripts touched: none). The editor also stops pausing for about a tenth of a second half a second after every save.
  - **Renaming or moving a sheet** no longer reads the project on the editor's thread: at 10,000 files the plugin's own share of a rename is about 0.15 s (it was four stretches of about 0.6 s), and 50 files moved at once read the project once instead of fifty times.
  - **The first sheet of a session** no longer waits for the project's scenes to be read: at 10,000 files the worst frame of the first open went from 397 to 499 ms to 210 to 300 ms, and its three later long frames are gone. A sheet whose rows depend on a scene (a trigger on a node wired in the scene) opened on a 10,000-file project did not change the height of any row from the first frame it existed (readiness pass, all six rows watched every frame for 40 s).
  - **A Juice Player with 200 cards** selects in about a tenth of the time (400 to 430 ms down to 90 to 100) and an edit (add, take out a Pause, drag, open or shut a card) takes 16 to 41 ms where it took 370 to 420.
  - **A large Drawing Prefab** answers at once: deleting, duplicating or inserting a card in a 500-shape list took about 680 ms (it redrew every card) and now touches only that card; a held Alt+Down at 200 shapes took about 916 ms a frame and now 13 ms; the picture at the top is drawn in bands and only where each shape lies, pixel for pixel the same picture.
  - **The editor's first open compiles fewer scripts**: about 14,500 lines (315 to 284 files) in the scene reader no longer compile on the first sheet, and 512 more lines of the picker's model load only when asked.

  **What changed that you must know when you upgrade**

  - **Nine plugin classes are renamed**, with no alias kept: `SheetCompiler` is `EventSheetCompiler`, `GDScriptImporter` is `EventSheetGDScriptImporter`, `VariableParser`, `TriggerResolver`, `VariableDialog`, `FunctionParser`, `ParamDefaultResolver`, `ActionCodegen` and `ConditionCodegen` gain the same prefix. A script of yours that names an old one stops parsing until you change the name; the Project Doctor has a Renamed Classes section that lists each line with its replacement.
  - **The plugin no longer adds an autoload when you enable it.** An `EventForgeBridge` line left by an older version is removed the first time the plugin starts and the Output says so (an autoload you made under that name is left alone). A script of yours that named the singleton should call `EventForgeBridgeRuntime`.
  - **Some older rows now say "N rows ask you".** If your scripts or sheets use one of the older rows the picker no longer offers - Move Toward Position, Wrap Around Scene Horizontally or Vertically, Bound To Scene, Wrap Inside The Screen, Wait For The Next Key Or Button, or the two on-screen tests - the head of that sheet reads "N rows ask you" and the Doctor's Migration section lists the sheet. Nothing about the file changes: it opens and saves byte for byte, and the code compiles exactly as before. The notice only says there is a newer row to choose by hand (the "world" twins act on the place in the level rather than inside the parent, so they are not a drop-in swap, which is why nothing is rewritten for you). Look at each listed row, pick the newer one if it suits you, or leave it. If you run the sheet check (`tools/verify_sheets.gd`) in CI over your own scripts, it exits 1 on such a row until you pick a replacement or leave that file out of the paths you check.
  - **The sheet now reads in Godot's own words by default**: On ready, On process, Queue free, Instantiate, scene, group. The other editors' words are one opt-in away in Settings > Words > Familiar words, and typing them in the picker still finds the row. No saved sheet, row id or compiled line changes.
  - **The Feedback Player is now the Juice Player** and its rows say "juice". Nothing you saved changes: every row keeps its id and writes the same code, and scenes and moment files load as before.
  - **Panels and windows removed because Godot already has them**: the Properties bar, the Project bar, the Object properties window, the Properties and actions window, the Objects list's "Also in the scene", the Inspector's variables table, the History panel, the plugin's own Keyboard Shortcuts window (your changed keys are carried into Editor Settings > Shortcuts once), the Language picker (the plugin follows Godot's editor language, with `eventsheets/interface/language_override` to differ), the Commands tab of Ctrl+P (they are on Godot's Command Palette), the Debugger window's Inspect, Profile and Breakpoints tabs and the Live Values window (use Godot's Debugger), the Manual's pages for Godot classes (F1 opens Godot's own Help), the Preview scene and Preview project buttons, Tools > Register Autoload, Sheet > New Class, and the Translation Studio's "turn on in the game" step.
  - **Object marks are gone**: dropping an object on the canvas now asks Godot's groups and exported variables. Old projects that still hold the three metadata keys load as before and ignore them.
  - **Your own scripts have no lock on their functions**: they edit like any event from the first click. A function in one of the plugin's own pack folders asks once before its first edit.
  - **A key typed into View > Ask moves out of project.godot** into Editor Settings the first time the plugin starts, and the Output says so once. New quality presets are written under `res://eventsheet_settings/quality/`; presets already in `res://settings/quality/` are still read.
  - **A handler you place on a node path is named for the path alone** (`_on_services_settings_setting_changed`); a handler saved earlier keeps its number and a file written either way opens and saves back byte for byte.
  - **Themes keep their values but not their bytes.** A theme you saved loads and saves as before and every value is the same, but a save writes the file shorter and in a different order: keys that are equal to their default and the keys the Project bar used are dropped, and Godot gives every sub-resource a fresh id each time it saves. Do not rely on a theme file being byte-identical after you open it in the Theme Editor and press Save. Six bundled demo themes lose the colours nothing drew (pattern chip and drawer-note colours); a theme file that still names them keeps them.
  - **Fixed on purpose**: the coloured bar down the left edge of rows, cells and panels is gone everywhere (the same states are told by a wash and a coloured number), and the compiled code of a sheet whose Save choices are all Manually now carries one `@warning_ignore` line; a file written before still opens and saves back exactly as it was.
  - **Retired rows**: Is On-Screen and Is Outside Layout still compile where used, are hidden from the picker and point at Is On Screen. Wait For The Next Key Or Button is deprecated for Wait For The Next Press.

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
