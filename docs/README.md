# Documentation Index

Every guide and reference for Godot EventSheets, grouped by what you are trying to do. New here? Start with the [recipes](GUIDE-RECIPES.md). Looking for a bundled behavior pack? See the [addon guides index](Addons/README.md).

Every page below also ships inside the editor: open **Tools > Manual**, or press **F1** with anything selected to land on the page for it. This index is the authoritative list - a suite check fails if a guide is missing from it.

## Learn by doing

- [Recipes](GUIDE-RECIPES.md) - build a platformer, health, pickups, and debugging end to end.
- [Common Game Patterns Without Code](GUIDE-COMMON-GAME-PATTERNS.md) - state machines, timers, cooldowns, remembering variables, tweens, and randomness as rows.
- [Everyday Patterns As Vocabulary](EVERYDAY-PATTERNS-AS-VOCABULARY.md) - the linkable case for event-sheet visual scripting: what a beginner skips, pattern by pattern, and what an expert keeps.
- [Block Styles - How To Read Every Row](GUIDE-BLOCK-STYLES.md) - the field guide to every block kind and the icon legend.
- [Variables, Groups and the Sheet Head](GUIDE-VARIABLES-GROUPS-AND-THE-SHEET-HEAD.md) - the parts of a sheet that are not events: the one sentence every variable reads with, the code echo beside it, the Add variable and Compare dialogs, the parameters dialog and its help strip, the head's bands, and groups and regions.
- [States: What One Object Is Doing Right Now](GUIDE-STATES.md) - patrolling, chasing, staggered as the variable pattern you already build: the states declared once on the head, the four rows and the two triggers, the timed question, the group-named-after-a-state convention, the compiled shape, the hand-written `enum` + `match` machine that opens as those rows, watching it run, the trail of what it just did, and how it meets the game's modes and the State Machine pack.
- [Working with Lists (Arrays)](GUIDE-WORKING-WITH-LISTS.md) - the whole Array vocabulary, including Filter / Map / Reduce / Any Match / All Match and typed lists.
- [Working with Text (and Reading Data Out of It)](GUIDE-WORKING-WITH-TEXT.md) - fitting text to a label, readable numbers, lined-up columns, pulling a piece out of a line, quote-aware splitting, a spreadsheet read as records end to end, and turning a parse failure into a sentence.
- [Working with Values (and Copying Them Around)](GUIDE-WORKING-WITH-VALUES.md) - loaded values that might be missing or the wrong shape: emptiness across types, one-row fallbacks, checked conversions, named parts, the shared-.tres copy trap, presets, share codes and the clipboard, and remember/restore.
- [Seeing What Is There (Raycasting)](GUIDE-SEEING-WHAT-IS-THERE-RAYCASTING.md) - line of sight, hitscan shots, ground checks, click-to-select, and explosion radii: all four kinds of cast in 2D and 3D, with two playable labs that draw every cast as it happens.
- [Collisions: What Touches What](GUIDE-COLLISIONS-WHAT-TOUCHES-WHAT.md) - picking the node (detect, or block and be driven, thrown or standing), layers and the who-sees-whom asymmetry taught once, the touch with a group filter on it, the step something changed, the deep verbs woven in, and the four silent failures the Doctor finds before the game runs.
- [Make a Behaviour Without Writing Code](GUIDE-MAKE-A-BEHAVIOUR-WITHOUT-CODE.md) - author a whole reusable behaviour from event-sheet rows.
- [Saving and Loading Your Game](GUIDE-SAVING-AND-LOADING.md) - the save story: six slot formats, the persist group, the `save_state`/`load_state` seam any behaviour can join, slot cards a load menu reads without loading, an autosave the sheet can veto, save migration, a backup ring, and New Game Plus.
- [Files and Folders](GUIDE-FILES-AND-FOLDERS.md) - where a game may write and what it may trust: the two places and the export trap, the guard written into the line, a spreadsheet read by the engine's own reader, the drop and the ask, the watcher that calls itself a poll, archives with the unpack guard, safe names, and the mod format that is data your game interprets.
- [Scenes: Travelling To Them, Layering Them, and Saving What The Player Built](GUIDE-SCENES.md) - the two jobs one word does, the `%name` habit that stops a path breaking when somebody moves a node, a pause menu put over the running game and the process mode it depends on, the four words for where in 3D, the trigger that hears a node join a group, the owner walk that makes a player-built level save as more than its root, the question to ask before building a scene you did not ship, an editor tool whose whole event is one Ctrl+Z, and a second live view of the world you are already in.
- [Tiles, Streaming and Mods](GUIDE-TILES-STREAMING-AND-MODS.md) - the ground, the world past it, and the folder players add to: the questions a level is asked and the helper written into your file once, the tile raycast that needs no physics, terrain edges healing themselves after a crater, a layer's own bytes as a save file and as an undo step, the GridMap twin and what has no twin, a world that is a folder of scenes named by cell with the split and merge tools both ways, and mods in two tiers with what a script mod costs said out loud.
- [Lighting Your Game](GUIDE-LIGHTING-YOUR-GAME.md) - making a night and lighting it: darkness as a percentage, the five knobs and what Godot calls them in each dimension, shadows that actually appear, the flicker and pulse behaviours, a day/night clock, the 3D World object and the shared-environment trap, and the table of what a project you already lit opens as.
- [Cameras, Views and How The Game Fills The Screen](GUIDE-CAMERAS-AND-VIEWPORTS.md) - the camera in both dimensions: the dead zone a platformer wants, the snap that kills the opening pan, the view rectangle asked from both ends, the level's own edges measured off the painted tiles, the timed look-at that never rolls, what is under the cursor asked by a named camera, the shot list the Camera Rail pack makes of a camera, a second view of the same world and the still it writes, the scaling words a graphics menu needs, and layers and parallax on both of Godot's parallax nodes.
- [The Look of Your Game](GUIDE-THE-LOOK-OF-YOUR-GAME.md) - the four objects a game's look really lives on and the copy every row takes before it writes: the nine words for a 3D surface, one surface slot and the layer over it, a sprite's two words, the twenty-one words for the whole world, tone map and the glow's seven numbers, the two fogs, what each renderer can actually draw, the sky three objects past the node, the lens and what stays sharp behind the speaker, a whole world saved as a file you author, and the seven particle words on the two objects an effect really is.
- [Visual Effects and Shaders](GUIDE-VISUAL-EFFECTS-AND-SHADERS.md) - turning a shader's dials as rows whose names come out of the `.gdshader` file rather than being typed: the picker shelf per wearing node, the muted `effect.` lead, the four verbs, the field a dial edits in, the shared-material trap and the row that fixes it, the one uniform every shader can read, the six effect packs and the full-screen layer, the amber note when a shader stops declaring a dial, the table of what a project that already has shader code opens as, and the five silent failures the Doctor knows.
- [Post-Processing and Juice](GUIDE-POST-PROCESSING-AND-JUICE.md) - making it feel like something: the one-row forms that need no tuning (a pulse, a moment, a blend, a look), the twenty ways one picture meets the one behind it and the preview strip that shows them, masks and a node's children drawn inside its own shape, the post stack as a named list and which side of the interface layer it draws on, colour vision and the reduced-flashing setting that already exists, a look and a moment as files you author rather than presets you pick, the seven shapes a scene change can wear, the camera's own compositor and what each renderer can actually do.
- [Music, Prompts, Text Effects and Animation](GUIDE-MUSIC-PROMPTS-TEXT-AND-ANIMATION.md) - what plays, prompts, speaks and moves: one song at a time with layers that cannot drift, a beat read off the playback position rather than counted, the visible half of a quick-time event with the glyph for the pad actually in the player's hands, a note that lands on the song's own next beat, the six text effects the engine already knows and the line typed out one character at a time, the rest of what a blend tree does in the tree's own names, root motion taken into the body, bones pointed and held, and the two things a blend tree accepts in silence.
- [Multiplayer with Godot's Built-in Tools](GUIDE-MULTIPLAYER-WITH-GODOTS-BUILT-IN-TOOLS.md) - playing together over a network as rows: hosting and joining, the seven things the connection tells you, messages and the `@rpc` words, a group that says who runs it, objects and their owners, spawning a scene on every peer, keeping a value in step and deciding who may see it, the lobby and the authentication handshake, testing it as two players and as a dedicated server, the four mistakes the Doctor knows, and the table of what a project you already wrote opens as.

## The Studios (in-editor authoring tools)

- [Using the ACE Studio](GUIDE-USING-THE-ACE-STUDIO.md) - the "New Function" dialog: the action / condition / expression kind cards, the live picker preview, the Ships-as signature, and publishing (parameters are edited from the function row's cells, guards are condition rows in the body).
- [Using the Save Studio](GUIDE-USING-THE-SAVE-STUDIO.md) - the save window: preview any format on disk, browse and export slots, and generate save support for your own scripts.

## Extend the plugin

- [Custom ACEs](GUIDE-CUSTOM-ACES.md) - turning your logic into curated Actions, Conditions, and Expressions (your own classes are already pickable without this - see the existing-code guide).
- [Designing User-Friendly ACEs](GUIDE-DESIGNING-USER-FRIENDLY-ACES.md) - the craft: naming, parameters, descriptions, and picker UX beginners can use first try.
- [Creating Custom ACE Modules](GUIDE-CREATING-CUSTOM-MODULES.md) - package your own vocabulary as a scanned module.
- [Custom Blocks](GUIDE-CUSTOM-BLOCKS.md) - register new non-ACE row kinds with byte-gated round-trip.
- [Inspector Drawers and Export Options](GUIDE-CUSTOM-INSPECTORS.md) - shape how a variable looks and validates in the Inspector.
- [Data-driven Addons with Custom Resources](GUIDE-DATA-DRIVEN-ADDONS.md) - author content as Inspector-edited `.tres` resources.
- [Building a Data-driven Game](GUIDE-DATA-DRIVEN-GAMES.md) - drive whole games from Custom Resources.
- [Building on EventSheets](GUIDE-BUILDING-ON-EVENTSHEETS.md) - the public `EventSheets` API for plugins, build tools, and CI.
- [Editor Tools](GUIDE-EDITOR-TOOLS.md) - sheets whose events run inside the editor: the one-click chore, an Editor Plugin, an Import Tool and an Export Hook, with a Run now button where you write them, Inspector buttons, and undo done right.
- [Custom Resources](GUIDE-CUSTOM-RESOURCES.md) - your own data assets from the three-question wizard: column language, validation, the .tres workflow.
- [Making Editor Tools from Code](GUIDE-BUILDING-EDITOR-TOOLS.md) - the programmatic side: author tool sheets through the EventSheets API.
- [The Editor, Read as Events](GUIDE-THE-EDITOR-READ-AS-EVENTS.md) - the plugin's own source opened as sheets in its own repository: the This editor folder, the plugin's bar, editing the editor from inside itself, and the numbers that measure it.
- [Writing the Docs](GUIDE-WRITING-THE-DOCS.md) - how documentation works here and how to add to it: the three doc sets, the guide standard, the figure fences that draw themselves in the editor, and the regenerate-before-commit gate.

## Patterns

- [Composition and Systems](GUIDE-COMPOSITION-SYSTEMS.md) - the ECS-lite pattern: entities as grouped nodes, systems as sheets that run over them.
- [Randomness and Procedural Generation](GUIDE-PROCEDURAL-GENERATION.md) - one Advanced Random seed driving maps, loot, and cosmetics.
- [Player and AI Input](GUIDE-PLAYER-AND-AI-INPUT.md) - the one seam that lets every input-reading pack be driven by the player or by your AI.
- [Let Players Rebind the Controls](GUIDE-LET-PLAYERS-REBIND-THE-CONTROLS.md) - a controls screen as four events: wait for the next key, bind it, reset, and the two rows that make a remap survive a restart.
- [Secrets and the End-of-Level Screen](GUIDE-SECRETS-AND-THE-END-OF-LEVEL-SCREEN.md) - mark a room a secret so dropping it offers the counting event, then show kills, secrets and time on a named panel when the level ends.
- [Fighting-Game Combos, Cancel Windows and Hit-Stop](GUIDE-FIGHTING-GAME-COMBOS-CANCEL-WINDOWS-AND-HIT-STOP.md) - the move list as a table of combo-to-animation rows, the slice of a move another move may cancel it in, the freeze on a connecting blow, and the press remembered for six frames so it still comes out.

## Localization

- [Translating Your Game](GUIDE-TRANSLATING-YOUR-GAME.md) - localise game text the Godot way (globe-marked params, POT, Set Language).
- [Translating the Editor](GUIDE-TRANSLATING-THE-EDITOR.md) - drop in a CSV to localise the plugin UI itself (eight translations ship built in, nine languages in all).

## Working with your project

- [Using EventSheets with Your Existing Code](GUIDE-USING-WITH-EXISTING-CODE.md) - how sheets call, and are called by, your GDScript; what a hand-written `.gd` actually looks like when you open it as a sheet (functions, condition/action rows, notes, Declare rows for data tables); your own classes appearing in the picker with zero setup, renaming or hiding those actions and conditions without touching your source, and naming a raw call you already have.
- [How Your Code Reads: Curated Sentences, Derived Rows and Honest Code](GUIDE-HOW-CODE-READS.md) - the three layers every opened line arrives through, the two marks that tell a curated sentence from a derived one at a glance, where a derived row gets its words, the Doctor's Reading ledger and the shape a stays-code line has, six hand-written idioms with the reading they used to get beside the one they get now, and the boundary the top layer is not going to cross.
- [Coming from GDScript](GUIDE-COMING-FROM-GDSCRIPT.md) - you already know Godot: the two dozen words this editor reads your code in (`queue_free` is Destroy, `_process` is Every tick, `await` is Wait for, `signal` is trigger), why a row is one statement, and how to see the GDScript behind any row. The full generated list is Manual ▸ Dictionary: GDScript to events.
- [Describing Your Game](GUIDE-DESCRIBING-YOUR-GAME.md) - one description per thing you made, kept as the `##` line the file already carries; drafts composed out of the thing's own rows; the Doctor's "describe the undescribed" page and its drift note; the manual your game writes about itself; and the Project View with its search across every sheet.
- [Sharing Events Between Scripts](GUIDE-SHARING-EVENTS-BETWEEN-SCRIPTS.md) - shared event sheets: write common events once and include them in many scripts, as a base class or as a helper.
- [Version Control for Event Sheets](GUIDE-VERSION-CONTROL.md) - diffing, merging, committing sheets, resolving a merge conflict as events, the four standing contracts as a headless command you can hang off a hook or a CI job, and what working on this as a team actually looks like.
- [Updating and Refactoring Without Breaking Your Game](GUIDE-UPDATING-AND-REFACTORING.md) - the three promises everything else rests on (a shipped game cannot break, old rows compile forever, opening never rewrites), the quiet amber question, the forwarding address a moved verb carries, the Migrate receipt and the two gates every rewrite passes, the project report, renaming in both directions, a pack update as a proposal, the honest exit for a verb that is simply gone, what a merge leaves behind, and the four contracts as one read-only command.
- [Autocomplete and Quick Add](GUIDE-AUTOCOMPLETE-AND-QUICK-ADD.md) - the names the editor gives back as you type: one suggestion list and one set of keys across dialogs, the value you double-click inside a row, name and type and file fields, plus typing a whole row into the Add picker ("boss fla 0.4") with the value already in place.
- [The Toolbar - The Strip Across The Top](GUIDE-THE-TOOLBAR.md) - the seven controls the strip rests as, the one Menu and its 137 commands, the play button and its Main-button choice, the sheet's own corner links and the seventeen ways to add a row ranked, the chevron and View ▸ Full toolbar, a where-did-it-go table for every retired button (its menu path, its key, its door in the sheet), and what Simple Mode actually does.
- [Theme and Editability](GUIDE-THEMING.md) - restyle the editor, lock a sheet down for a team, and the accessibility settings: reduced motion, dyslexia-friendly text, a reading font, and rows read aloud.
- [Asking for Events in Plain Words](GUIDE-ASKING-FOR-EVENTS-IN-PLAIN-WORDS.md) - the optional Ask box: what is sent (exactly), what can come back, why the answer is rows rather than code, and how to turn it on or leave it off.
- [Removing Godot EventSheets](GUIDE-UNINSTALL.md) - a clean, guided teardown that leaves your game running.

## Coming from Construct 3

- [Migration Guide](GUIDE-MOVING-FROM-ANOTHER-EVENT-SHEET-EDITOR.md) - every concept, behavior, and plugin mapped to its home here.
- [Glossary](REFERENCE-GLOSSARY.md) - the cross-tool term map.

## Reference

- [Engine-Level ACEs](REFERENCE-ENGINE-ACES.md) - the vocabulary that drives the engine itself: graphics settings, world gravity, audio mixing, runtime meshes, camera FOV, animation playback, gradients and curves.
- [MCP Server](REFERENCE-MCP-SERVER.md) - the AI-tooling protocol (list, read, compile, lint, snippets, doctor).
- [Performance](REFERENCE-PERFORMANCE.md) - frame-spreading and time-budgeting.
- [GDScript Basics Coverage](GDSCRIPT-BASICS-COVERAGE.md) - every fundamental on Godot's basics page, as sheet rows (the release-bar receipt).

## Built-in vocabulary

The entry-by-entry reference for everything the picker already offers. The four "Working with…" and
"Seeing What Is There" guides above stay the narrative, learn-by-doing versions of their subjects;
open a Modules guide when you want the full list of actions, conditions and expressions, their
parameters, and what each row ships as.

- [Built-in Module Guides Index](Modules/README.md) - deep-dive guides for the 1,556 actions, conditions and expressions that ship in the picker before you enable a single pack.

## Addon packs

- [Addon Guides Index](Addons/README.md) - deep-dive guides for every bundled behavior pack in `eventsheet_addons/`.

## Learning paths

An ordered reading of guides that are already listed on this page. A path holds nothing of its own -
it is a list, in the order that teaches, and the Manual draws it as a track you can tick off as you
go (the ticks stay on your machine and are never committed). Adding a path to your own project's
docs index, in exactly this format, puts it in the Manual beside these.

### Your first game

You have never built one, and you would like to finish something small.

1. [Recipes](GUIDE-RECIPES.md)
2. [Block Styles - How To Read Every Row](GUIDE-BLOCK-STYLES.md)
3. [Variables, Groups and the Sheet Head](GUIDE-VARIABLES-GROUPS-AND-THE-SHEET-HEAD.md)
4. [Common Game Patterns Without Code](GUIDE-COMMON-GAME-PATTERNS.md)
5. [Collisions: What Touches What](GUIDE-COLLISIONS-WHAT-TOUCHES-WHAT.md)
6. [Saving and Loading Your Game](GUIDE-SAVING-AND-LOADING.md)
7. [Autocomplete and Quick Add](GUIDE-AUTOCOMPLETE-AND-QUICK-ADD.md)

### Coming from another editor

You have shipped games in another event-sheet tool, or you already write GDScript.

1. [Migration Guide](GUIDE-MOVING-FROM-ANOTHER-EVENT-SHEET-EDITOR.md)
2. [Coming from GDScript](GUIDE-COMING-FROM-GDSCRIPT.md)
3. [Using EventSheets with Your Existing Code](GUIDE-USING-WITH-EXISTING-CODE.md)
4. [Glossary](REFERENCE-GLOSSARY.md)
5. [Custom ACEs](GUIDE-CUSTOM-ACES.md)
6. [Version Control for Event Sheets](GUIDE-VERSION-CONTROL.md)
7. [Updating and Refactoring Without Breaking Your Game](GUIDE-UPDATING-AND-REFACTORING.md)

### Multiplayer

Your game is going to be played by more than one person at a time.

1. [Multiplayer with Godot's Built-in Tools](GUIDE-MULTIPLAYER-WITH-GODOTS-BUILT-IN-TOOLS.md)
2. [Sharing Events Between Scripts](GUIDE-SHARING-EVENTS-BETWEEN-SCRIPTS.md)
3. [Saving and Loading Your Game](GUIDE-SAVING-AND-LOADING.md)
4. [Composition and Systems](GUIDE-COMPOSITION-SYSTEMS.md)

### Performance

The game works and now it has to keep working with everything on screen at once.

1. [Performance](REFERENCE-PERFORMANCE.md)
2. [Composition and Systems](GUIDE-COMPOSITION-SYSTEMS.md)
3. [Working with Lists (Arrays)](GUIDE-WORKING-WITH-LISTS.md)
4. [Seeing What Is There (Raycasting)](GUIDE-SEEING-WHAT-IS-THERE-RAYCASTING.md)
5. [Randomness and Procedural Generation](GUIDE-PROCEDURAL-GENERATION.md)
