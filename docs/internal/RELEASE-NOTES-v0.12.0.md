# v0.12.0 - The Inspector Designer Update

Your event-sheet variables were already real `@export` properties. This release lets you design the whole Godot Inspector they produce - visually, from the sheet, with no code - and ships four UI packs plus a faster, lighter plugin load. Everything still compiles to plain, typed GDScript with zero runtime dependency, and every drawer, marker, and pack round-trips byte-for-byte.

## Highlights

- **The Inspector Designer** - a Sheet-menu view lays out every exported variable as a live, stacked preview card exactly as Godot will show it; edit a variable in place or reorder fields without leaving the picture. Hover any exported variable row in the sheet and the same preview floats up as a tooltip.
- **Eight rich drawers**, all authored from the Variable dialog with no code and all round-tripping to plain `@export` GDScript: min-max range sliders (one handle per bound), an editable table (an `Array` becomes an add/remove/reorder grid), toggle-button rows (a `String`'s choices shown as buttons), plus progress bar, direction dial, colour swatch, texture thumbnail, and inline curve.
- **Decor and guard rails from plain comments** - accent section headers, info-note panels, a required badge that lights when a field is empty, inline validation (a sheet function's warning shown under the field), and inline field buttons (run a method from the Inspector). Every marker is a comment the importer reads back, so none of it costs the byte-exact round-trip.
- **A Custom Resource showcase** - `EnemyStats` puts the drawers, decor, required fields, and a loot table together as one designer-tunable resource, and the Custom Block + `EventSheets` APIs gained the matching hooks (`build_inspector_preview`, `describe_inspector`, `variable_code`, block `hover_text`).
- **Four UI packs (now 34 in all)** - a HUD Kit (menus and HUDs addressed by name, every descendant button auto-wired into one On Button Pressed trigger, zero connected signals), Scene Flow (scene changes behind a polished fade that survives the swap), and a Dialogue Kit (typewriter conversations), shipping alongside a ready-to-edit Menu Starter scene you can copy as your project's UI.
- **The Doctor enforces required fields project-wide** - every scene node and saved resource using a script with Required, empty-by-default variables is scanned, and any that leaves one unset gets a warning naming the exact file and property. Runs in the dock, the CLI, CI, and MCP.
- **2D overlap queries** - "what is HERE right now" point / circle / rect checks with no Area2D needed.
- **Born where you already right-click** - the FileSystem dock's native Create New submenu now offers Event Sheet..., which mints a new `.gd` sheet (Blank or a starter) straight into the clicked folder and opens it ready to edit.
- **A faster, lighter load** - the workspace editor is built lazily on first use, so enabling the plugin (or opening a project that never touches event sheets) skips the whole dock construction at editor startup; the top-strip tab still appears instantly.
- **Construct-3 muscle memory** - the row right-click menu gained Insert Above, Cut (copy plus delete as one undo step), and Copy as Text (readable plain-language sentences for an issue or a chat message).
- **Docs, reorganized and illustrated** - every doc file now wears its kind as a prefix (`GUIDE-`, `REFERENCE-`, internal `SPEC-`), eleven guides open with a rendered picture of the feature they teach, and every guide grew a rich set of concrete use-case examples.

**Quality:** every feature landed suite-green with byte-exact round-trip gates and `drifted=0` across all 34 packs. Generated code still never depends on the plugin, templates bake at apply-time, and output remains performance-identical to hand-written GDScript - all test-enforced. Verified on Godot 4.7 stable.

Full ledger: [CHANGELOG.md](https://github.com/SalmanShhh/Godot-EventSheet-Visual-Scripting/blob/main/CHANGELOG.md)
