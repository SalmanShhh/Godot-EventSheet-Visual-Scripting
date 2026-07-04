# v0.11.0 - The Structure & Vocabulary Update

Big sheets need structure, and a growing project deserves a growing vocabulary. This release makes both first-class: fold thousands of rows into colored regions that read like chapters, and turn the logic you write into named, reusable verbs that every sheet in the project can pick - without ever leaving the event sheet, and without changing a single byte of the GDScript your sheets compile to.

## Highlights

- **Collapsible regions** - `#region` fences become foldable, color-tinted bubble outlines around any run of rows. Groups and every block kind nest inside, regions glow when you drag into them, each carries an editable color and description, and folds survive reopening the project. Byte-identical `.gd` output, always.
- **The abstraction levers, complete** - multi-line actions show a quiet `→N` "compiles to N lines" cue; **Extract to Function** honours a partial selection and turns captured locals into typed parameters automatically; **Teach a Verb** publishes a sheet's functions into every picker in the project (node-targeted and retargetable, with un-teach in Manage Providers); and the picker now leads with **featured intention verbs** (Wait, Play Sound, Destroy, Move Toward...) rendered bold at the top of their categories.
- **Choose Inspector looks by picture** - the **Look Gallery** shows one miniature tile per Inspector widget (checkbox flags, layer grids, file pickers, easing curves) with plain-language explanations, and a live **Inspector preview** card states your choices as one sentence plus the exact `@export` line they ship as.
- **Translate your game from the sheet** - a globe toggle marks any string translatable (`tr()` underneath), a Translation ACE module covers locale switching, context, and plurals, and the Project Doctor flags untranslated projects.
- **Every node speaks EventSheet** - any engine class or your own `class_name` scripts reflect into browsable vocabulary on demand: methods classify by return type, signals become triggers, properties become Set/Get pairs.
- **Terse addon authoring** - a `##` doc comment is the description, one class-level `@ace_category` plus `@ace_expose_all(node)` publishes a whole behavior, and all 31 shipped packs now demonstrate the style - permanently audit-gated so they can never drift.
- **A public API to build on** - the `EventSheets` facade exposes vocabulary, editor, codegen, and project-health services with the same stability covenant as `ace_id`s; the plugin's own features run on the same seams, and the Project Doctor accepts pack-registered health checks.
- **Fixed along the way** - reflected property actions that silently compiled to nothing now write real code; autoload providers call the singleton instead of spawning a second copy; twice-registered providers no longer double-list in the picker; the picker's codegen line is never blank; and the row-type square that cluttered every row is gone.

**Quality:** every feature landed suite-green with byte-exact round-trip gates and `drifted=0` across all 31 packs. Generated code still never depends on the plugin, and output remains performance-identical to hand-written GDScript - all test-enforced.

Full ledger: [CHANGELOG.md](https://github.com/SalmanShhh/Godot-EventSheet-Visual-Scripting/blob/main/CHANGELOG.md)
