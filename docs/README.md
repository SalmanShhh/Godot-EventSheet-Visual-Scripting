# Documentation Index

Every guide and reference for Godot EventSheets, grouped by what you are trying to do. New here? Start with the [recipes](GUIDE-RECIPES.md). Looking for a bundled behavior pack? See the [addon guides index](Addons/README.md).

## Learn by doing

- [Recipes](GUIDE-RECIPES.md) - build a platformer, health, pickups, and debugging end to end.
- [Common Game Patterns Without Code](GUIDE-COMMON-GAME-PATTERNS.md) - state machines, timers, cooldowns, remembering variables, tweens, and randomness as rows.
- [Working with Lists (Arrays)](GUIDE-WORKING-WITH-LISTS.md) - the whole Array vocabulary, including Filter / Map / Reduce / Any Match / All Match and typed lists.
- [Seeing What Is There (Raycasting)](GUIDE-SEEING-WHAT-IS-THERE-RAYCASTING.md) - line of sight, hitscan shots, ground checks, click-to-select, and explosion radii: all four kinds of cast in 2D and 3D, with two playable labs that draw every cast as it happens.
- [Make a Behaviour Without Writing Code](GUIDE-MAKE-A-BEHAVIOUR-WITHOUT-CODE.md) - author a whole reusable behaviour from event-sheet rows.
- [Saving and Loading Your Game](GUIDE-SAVING-AND-LOADING.md) - the save story: six slot formats, the persist group, and the `save_state`/`load_state` seam any behaviour can join.

## The Studios (in-editor authoring tools)

- [Using the ACE Studio](GUIDE-USING-THE-ACE-STUDIO.md) - the "New Function" dialog: verb-kind cards, the live picker preview, the Ships-as signature, and publishing (parameters are edited from the verb row's cells, guards are condition rows in the body).
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
- [Editor Tools](GUIDE-EDITOR-TOOLS.md) - one-click editor chores from Sheet > New Editor Tool: File > Run, Inspector buttons, undo done right.
- [Custom Resources](GUIDE-CUSTOM-RESOURCES.md) - your own data assets from the three-question wizard: column language, validation, the .tres workflow.
- [Making Editor Tools from Code](GUIDE-BUILDING-EDITOR-TOOLS.md) - the programmatic side: author tool sheets through the EventSheets API.

## Patterns

- [Composition and Systems](GUIDE-COMPOSITION-SYSTEMS.md) - the ECS-lite pattern: entities as grouped nodes, systems as sheets that run over them.
- [Randomness and Procedural Generation](GUIDE-PROCEDURAL-GENERATION.md) - one Advanced Random seed driving maps, loot, and cosmetics.
- [Player and AI Input](GUIDE-PLAYER-AND-AI-INPUT.md) - the one seam that lets every input-reading pack be driven by the player or by your AI.

## Localization

- [Translating Your Game](GUIDE-TRANSLATING-YOUR-GAME.md) - localise game text the Godot way (globe-marked params, POT, Set Language).
- [Translating the Editor](GUIDE-TRANSLATING-THE-EDITOR.md) - drop in a CSV to localise the plugin UI itself (eight translations ship built in, nine languages in all).

## Working with your project

- [Using EventSheets with Your Existing Code](GUIDE-USING-WITH-EXISTING-CODE.md) - how sheets call, and are called by, your GDScript; what a hand-written `.gd` actually looks like when you open it as a sheet (functions, condition/action rows, notes, Declare rows for data tables); your own classes appearing in the picker with zero setup, renaming or hiding those verbs without touching your source, and naming a raw call you already have.
- [Version Control for Event Sheets](GUIDE-VERSION-CONTROL.md) - diffing, merging, and committing sheets.
- [Theme and Editability](GUIDE-THEMING.md) - restyle the editor, or lock a sheet down for a team.
- [Removing Godot EventSheets](GUIDE-UNINSTALL.md) - a clean, guided teardown that leaves your game running.

## Coming from Construct 3

- [Migration Guide](GUIDE-C3-MIGRATION.md) - every concept, behavior, and plugin mapped to its home here.
- [Glossary](REFERENCE-GLOSSARY.md) - the cross-tool term map.

## Reference

- [Engine-Level ACEs](REFERENCE-ENGINE-ACES.md) - the vocabulary that drives the engine itself: graphics settings, world gravity, audio mixing, runtime meshes, camera FOV, animation playback, gradients and curves.
- [MCP Server](REFERENCE-MCP-SERVER.md) - the AI-tooling protocol (list, read, compile, lint, snippets, doctor).
- [Performance](REFERENCE-PERFORMANCE.md) - frame-spreading and time-budgeting.
- [GDScript Basics Coverage](GDSCRIPT-BASICS-COVERAGE.md) - every fundamental on Godot's basics page, as sheet rows (the release-bar receipt).

## Addon packs

- [Addon Guides Index](Addons/README.md) - deep-dive guides for every bundled behavior pack in `eventsheet_addons/`.
