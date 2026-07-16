# SPEC: Beginner-friendly editor tools + custom resources with EventSheets

Status: PROPOSAL - nothing here is built. Surface for a decision per slice.
Date: 2026-07-17

## The user story

Two creator journeys today require knowing Godot internals that EventSheets otherwise hides:

1. **"I want a little editor tool"** - a batch renamer, a level-stamping brush, a CSV importer.
   Today: you must know about `@tool`, `EditorScript`/File > Run, `EditorInterface`, and when
   code runs in-editor vs in-game. The `tool_mode` sheet type and the Editor Tools ACE category
   (18 ACEs) exist, but nothing TEACHES the journey.
2. **"I want my own data asset with a nice Inspector"** - loot tables, dialogue, plans, stats.
   Today: UHTNPlanResource/LootTableResource prove the ceiling (grouped grids, dropdown columns,
   required slots, tooltips), but reaching it means hand-writing Inspector Designer annotations
   (`drawer/table_columns/group/required`) on a Resource-host sheet - discoverable only by
   reading a shipped pack.

Both journeys map cleanly onto the condition/action model (STANDING PRINCIPLE): an editor tool
is events (On Editor Run / On Files Selected -> actions on the edited scene); a custom resource
is a sheet whose variables ARE the Inspector.

## Slice 1 - "New Editor Tool" starter (smallest, do first)

Add an **Editor Tool** entry to the existing new-sheet starters (beside behaviour/addon):

- Scaffolds a `tool_mode` sheet with an `On Editor Run` event, one sample action
  (`Print "Hello from the editor"`), and a commented Ghost Row trail of next steps.
- The Sheet Type dialog's contextual fields already handle tool_mode; the starter only needs a
  template + a menu item (Sheet > New Editor Tool...).
- Ships-as line explains the plain-GDScript output: "Runs from File > Run (Ctrl+Shift+X)".
- Doctor check: a tool sheet that mutates the scene without `EditorUndo` actions gets a nudge.

API touch: none - template only. Effort: S.

## Slice 2 - "New Custom Resource" wizard (the hero slice)

A guided flow (Sheet menu + FileSystem "Create New Event Sheet" dialog) that asks three
beginner questions and emits a Resource-host sheet:

1. "What is one entry called?" (e.g. "Loot Drop") -> a grid variable with a `table` drawer and
   starter columns.
2. "What columns does an entry have?" -> the enum(...) column syntax generated from plain
   choices ("kind: coin|gem|key" becomes a dropdown column) - the user never types the hint
   string.
3. "Anything required before it works?" -> `required: true` on the named slot.

Output: a `.gd` Resource sheet identical in shape to UHTNPlanResource (groups, tooltips,
`class_name`), opened in the dock with the Inspector Designer panel focused. Round-trip is
already byte-gated by the drawer machinery - the wizard only WRITES the annotations users
cannot remember.

API touch (the sustainable seam): add `EventSheets.resource_grid(name, columns, options)` -
a codegen-group helper that returns the exact variable-attributes payload the wizard, packs,
and third-party tools would otherwise hand-assemble. The wizard, `tools/pack_builders/_lib.gd`
(uhtn_plan_resource, loot_table_resource, ...), and the Inspector Designer dialog all converge
on it, so column-hint syntax gets ONE owner. Effort: M.

## Slice 3 - Custom Block kinds for the two journeys

Two registry-shipped block kinds (EventSheetBlockRegistry, like preload/region):

- **`core.editor_button`**: "Add a button to the Inspector that runs these actions" - emits a
  `@export_tool_button` var wired to a generated method whose body is the block's child
  actions. Reads as a block, compiles to the annotation + function. The beginner never learns
  the annotation exists.
- **`core.resource_validator`**: "Check this resource before it saves" - emits
  `_validate_property`-adjacent guard code from condition rows (the condition lane IS the
  validation). Pairs with the `validate:` drawer attribute that already exists.

API touch: none new - proves the existing Custom Block API carries editor-side features.
Effort: M per kind; editor_button first (visible payoff).

## Slice 4 - docs + discoverability glue

- `docs/GUIDE-EDITOR-TOOLS.md` + `docs/GUIDE-CUSTOM-RESOURCES.md` at the Addons-guide standard
  (15+ numbered use cases, 5 bolded "Other use cases") - named the way a beginner searches.
- Welcome tour gains a "Make your own data asset" stop pointing at the Slice 2 wizard.
- ACE Studio's verb-kind cards mention the editor context ("this runs in the editor") when the
  sheet is tool_mode.

## Ordering + decision asked

1 (starter, S) -> 2 (wizard + `resource_grid` API, M) -> 3 (`editor_button` kind, M) ->
4 (docs, S) -> 3b (`resource_validator`). Each slice lands with tests + CHANGELOG + previews.
Decision: green-light slice order, or re-rank (the wizard is the biggest beginner win; the
starter is the cheapest).
