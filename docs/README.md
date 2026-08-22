# Documentation Index

Every guide and reference for Godot EventSheets, grouped by what you are trying to do. New here? Start with the [recipes](GUIDE-RECIPES.md). Looking for a bundled behavior pack? See the [addon guides index](Addons/README.md).

Every page below also ships inside the editor: open **Tools > Manual**, or press **F1** with anything selected to land on the page for it. This index is the authoritative list - a suite check fails if a guide is missing from it.

## Learn by doing

- [Recipes](GUIDE-RECIPES.md) - build a platformer, health, pickups, and debugging end to end.
- [Common Game Patterns Without Code](GUIDE-COMMON-GAME-PATTERNS.md) - state machines, timers, cooldowns, remembering variables, tweens, and randomness as rows.
- [Everyday Patterns As Vocabulary](EVERYDAY-PATTERNS-AS-VOCABULARY.md) - the linkable case for event-sheet visual scripting: what a beginner skips, pattern by pattern, and what an expert keeps.
- [Block Styles - How To Read Every Row](GUIDE-BLOCK-STYLES.md) - the field guide to every block kind and the icon legend.
- [Working with Lists (Arrays)](GUIDE-WORKING-WITH-LISTS.md) - the whole Array vocabulary, including Filter / Map / Reduce / Any Match / All Match and typed lists.
- [Working with Text (and Reading Data Out of It)](GUIDE-WORKING-WITH-TEXT.md) - fitting text to a label, readable numbers, lined-up columns, pulling a piece out of a line, quote-aware splitting, a spreadsheet read as records end to end, and turning a parse failure into a sentence.
- [Working with Values (and Copying Them Around)](GUIDE-WORKING-WITH-VALUES.md) - loaded values that might be missing or the wrong shape: emptiness across types, one-row fallbacks, checked conversions, named parts, the shared-.tres copy trap, presets, share codes and the clipboard, and remember/restore.
- [Seeing What Is There (Raycasting)](GUIDE-SEEING-WHAT-IS-THERE-RAYCASTING.md) - line of sight, hitscan shots, ground checks, click-to-select, and explosion radii: all four kinds of cast in 2D and 3D, with two playable labs that draw every cast as it happens.
- [Make a Behaviour Without Writing Code](GUIDE-MAKE-A-BEHAVIOUR-WITHOUT-CODE.md) - author a whole reusable behaviour from event-sheet rows.
- [Saving and Loading Your Game](GUIDE-SAVING-AND-LOADING.md) - the save story: six slot formats, the persist group, the `save_state`/`load_state` seam any behaviour can join, slot cards a load menu reads without loading, an autosave the sheet can veto, save migration, a backup ring, and New Game Plus.

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
- [Coming from GDScript](GUIDE-COMING-FROM-GDSCRIPT.md) - you already know Godot: the two dozen words this editor reads your code in (`queue_free` is Destroy, `_process` is Every tick, `await` is Wait for, `signal` is trigger), why a row is one statement, and how to see the GDScript behind any row. The full generated list is Manual ▸ Dictionary: GDScript to events.
- [Sharing Events Between Scripts](GUIDE-SHARING-EVENTS-BETWEEN-SCRIPTS.md) - shared event sheets: write common events once and include them in many scripts, as a base class or as a helper.
- [Version Control for Event Sheets](GUIDE-VERSION-CONTROL.md) - diffing, merging, committing sheets, and resolving a merge conflict as events.
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
