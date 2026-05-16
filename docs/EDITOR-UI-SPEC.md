# EventForge Editor UI Spec

Last updated: 2026-05-16

## Phase implementation status

| Phase | Feature | Status |
|---|---|---|
| 2 MVP | Editor shell, dual/split view | ✅ |
| 2.1 | Editable rows, param inspector, save/load | ✅ |
| 2.2 | Sheet variable editor, variable-aware ACE params, copy/paste/duplicate/delete rows | ✅ |
| 2.3 | Sheet functions / local subsheets | ⏳ Deferred |
| 3 | Scripted ACE providers | ⏳ Deferred |
| 4 | Scripted structural blocks | ⏳ Deferred |
| 5 | Importer / editable GDScript round-trip | ⏳ Deferred |

---

## 1) Purpose

Define a practical, implementation-facing editor UI architecture for EventForge: a Godot editor plugin for visual event-sheet authoring that compiles to readable, deterministic GDScript.

The editor should support:

- visual event authoring
- generated GDScript preview
- Event Sheet / GDScript / Split view modes
- sheet-owned variables
- reusable sheet-local functions/subsheets
- copy/paste of event blocks and rows
- custom/scripted ACE providers
- later scripted structural blocks

Generated GDScript remains read-only until the importer/round-trip system is mature.

---

## 2) Main screen architecture

The editor shell is hosted by the EventForge plugin and mounted as an editor panel.
Phase 2 currently uses a bottom panel fallback; this is temporary. The long-term
target is a dedicated Script-editor-style workspace.

The editor controller owns:

- active `EventSheetResource`
- selected row state
- generated preview text
- active view mode
- dirty/compile status
- sheet variable editing state
- sheet function/subsheet editing state
- event-row clipboard state
- registered ACE/block provider data

Core components:

- `SheetToolbar`
- `ACEPalette`
- Event row canvas/list
- Variable panel
- Inspector/config panel
- Sheet function/subsheet panel
- `GDScriptPanel`
- Status bar

---

## 3) Layout

Top-to-bottom structure:

1. Toolbar row
2. Main content region
3. Status bar

Main content can show event UI, code UI, or both depending on mode.

Recommended long-term layout:

```text
┌ Toolbar ───────────────────────────────────────────────────────────────────────┐
├ Left Palette/Vars ┬ Event Sheet Canvas ┬ Inspector ┬ GDScript Preview ────────┤
└ Status Bar ────────────────────────────────────────────────────────────────────┘
```

For the current bottom-panel fallback, some regions may collapse or stack to preserve space.

### Workflow/UX direction (Phase 2.2 follow-up)

- UX inspiration: Construct 3 / GDevelop event sheets adapted to Godot-native
  editor conventions.
- Active-sheet header is always visible and shows:
  - `No Event Sheet Open`
  - `Unsaved Event Sheet`
  - `Event Sheet: <name/path>`
- Header shows `*` when unsaved edits and/or unrefreshed preview changes exist.
- Event canvas empty state is clickable:
  `No events yet. Click here or press Add Event to create one.`
- Clicking blank canvas space below rows supports quick add-event flow.
- New rows are selected immediately and prompt:
  `New Event` and `Choose a Trigger, Condition, or Action from the left panel.`
- Rows with no trigger should show `No Trigger` clearly.
- Copy/paste context is explicit:
  - copy requires open sheet + selected row
  - paste requires open sheet
  - paste inserts after selected row or at end when no row is selected
  - no-sheet paste message: `Open or create an Event Sheet before pasting.`
- Preview refresh is automatic with debounce (~0.4s) after edits, while manual
  `Refresh Preview` remains available.
- Built-in Core ACEs are grouped under `System` for event-sheet-friendly
  presentation, with user-facing labels like `On Ready` and `On Process`.

---

## 4) Core interactions

- New Sheet: creates in-memory sheet (`host_class = "Node"`).
- Open Sheet: loads an existing `.tres` / `.res` sheet resource.
- Save Sheet: saves to existing `resource_path`.
- Save Sheet As: prompts for a destination path and calls `take_over_path(...)` after successful save.
- Add Event: appends blank `EventRow`.
- Row selection: click row card to select/highlight.
- Copy row/block: copies selected event row or selected structural block into an EventForge clipboard payload.
- Paste row/block: inserts a cloned row/block after the selected row or at the end of the current sheet/function body.
- Duplicate row/block: copy + paste in one command.
- ACE palette selection:
  - Trigger: assign to selected row, or create a row first if none selected.
  - Condition: append to selected row.
  - Action: append to selected row.
  - Expression: reserved for future expression insertion.
- Compile / Refresh Preview: run `SheetCompiler.compile(...)` and update code panel.

---

## 5) Row rendering model

Each row card displays:

- enabled checkbox
- trigger display name or `<no trigger>` fallback
- compact condition summary
- compact action summary
- Add Condition button
- Add Action button
- Copy/Duplicate controls or context menu entries
- Delete button

Selection is visualized by a highlighted card background.

Future row types:

- Comment rows
- Loop rows
- Else/Elif rows
- Group rows
- Sheet function body rows
- Scripted structural block rows

---

## 6) Toolbar behavior

Toolbar controls:

- New Sheet
- Open Sheet
- Save Sheet
- Save Sheet As
- Add Event
- Copy
- Paste
- Duplicate
- Compile
- Refresh Preview
- View mode switcher

Toolbar emits intent signals only. `EventSheetEditor` performs mutations.

Future toolbar improvements:

- shorter labels for compact mode
- menu button for file actions
- edit menu for copy/paste/delete/duplicate
- validation summary button
- generated script open button

---

## 7) ACE palette behavior

The ACE palette lists descriptors from `ACERegistry`, grouped by type and category:

- Triggers
- Conditions
- Actions
- Expressions

Search filters by descriptor display name, ACE ID, provider ID, and category.

The palette should eventually show:

- built-in ACEs
- runtime registered ACEs
- scripted ACE provider descriptors
- project-specific custom blocks

---

## 8) Inspector / config editing

Phase 2.1 adds a basic right-side inspector for the selected event row:

- row UID display
- enabled toggle
- editable trigger provider/ID
- editable trigger params
- condition/action parameter editors (`Label + LineEdit`)
- remove condition/action buttons

Parameter edits update row dictionaries immediately and mark preview as dirty.

Later inspector upgrades:

- type-aware parameter widgets
- variable pickers
- expression editors
- node/resource pickers
- enum dropdowns
- validation messages next to fields
- function/subsheet call parameter editors
- scripted provider UI hints

---

## 9) Generated code panel

`GDScriptPanel` is read-only and source-oriented. It displays latest compiler output text from `SheetCompiler.compile(...)`.

For unsaved in-memory sheets, preview output must not dirty the project root. Use:

```gdscript
user://eventforge_preview_generated.gd
```

until the compiler supports pure in-memory generation.

Generated GDScript remains read-only in Event Sheet / Split / GDScript modes. Editable round-trip GDScript synchronization is deferred until importer support matures.

---

## 10) Dual View / Split View modes

Required mode enum:

```gdscript
enum ViewMode {
	EVENT_SHEET,
	GDSCRIPT,
	SPLIT
}
```

### Event Sheet mode

Shows visual authoring UI: palette, sheet canvas, inspector, variables/functions panels as space allows.

### GDScript mode

Shows generated code preview panel only.

### Split mode

Shows event sheet UI and generated code side-by-side.

### Wireframes

Event Sheet mode:

```text
┌ Toolbar: [New] [Open] [Save] [Add Event] [Copy] [Paste] [Compile] [Sheet|Split|Code] ┐
├ ACE Palette / Vars ┬ Event Sheet Canvas ┬ Inspector ─────────────────────────────────┤
└ Status Bar ───────────────────────────────────────────────────────────────────────────┘
```

GDScript mode:

```text
┌ Toolbar: [New] [Open] [Save] [Add Event] [Copy] [Paste] [Compile] [Sheet|Split|Code] ┐
├ Generated GDScript Preview (read-only) ───────────────────────────────────────────────┤
└ Status Bar ───────────────────────────────────────────────────────────────────────────┘
```

Split mode:

```text
┌ Toolbar: [New] [Open] [Save] [Add Event] [Copy] [Paste] [Compile] [Sheet|Split|Code] ┐
├ ACE Palette / Vars ┬ Event Sheet Canvas ┬ GDScript Preview (read-only) ──────────────┤
└ Status Bar ───────────────────────────────────────────────────────────────────────────┘
```

---

## 11) Validation UX

Status examples:

- Success: `Preview updated.`
- Success + warnings: `Compile succeeded with warnings: ...`
- Failure: `Compile failed: ...`
- Dirty state after edits: `Preview update scheduled...`
- Missing row selection: `Select an event row first.`
- Copy without selection: `Select an event row before copying.`
- Paste without open sheet: `Open or create an Event Sheet before pasting.`
- Paste with empty clipboard: `Nothing to paste.`

Validation should eventually exist at three levels:

1. Field-level validation in the inspector.
2. Row-level warning/error badges.
3. Compile-level summary in the status panel.

---

## 12) Copy/paste event blocks

EventForge should support copying, pasting, duplicating, and eventually cutting event rows and structural event blocks.

### MVP scope

Phase 2.2 should support copying and pasting `EventRow` resources within the same `EventSheetResource`.

MVP commands:

- Copy selected row
- Paste after selected row
- Paste at end if no row is selected
- Duplicate selected row
- Delete selected row

Recommended shortcuts:

- `Ctrl/Cmd+C`: copy selected row/block
- `Ctrl/Cmd+V`: paste after selection
- `Ctrl/Cmd+D`: duplicate selected row/block
- `Delete` or `Backspace`: delete selected row/block, with safe focus handling

### Clipboard model

Use an editor-local EventForge clipboard first, not the system clipboard.

Recommended state:

```gdscript
var _row_clipboard: Resource = null
var _row_clipboard_kind: String = ""
```

When copying, duplicate the selected resource deeply:

```gdscript
_row_clipboard = selected_row.duplicate(true)
_row_clipboard_kind = selected_row.get_row_kind()
```

When pasting, duplicate the clipboard again before insertion:

```gdscript
var pasted: Resource = _row_clipboard.duplicate(true)
```

### UID handling

Pasted rows must receive new stable IDs so generated code/source mapping does not confuse originals and clones.

For `EventRow`, regenerate:

```gdscript
event_uid
```

For group/function/block resources, regenerate their equivalent stable IDs when those types become copyable.

If resources do not yet expose a public UID regeneration method, add one such as:

```gdscript
func regenerate_uid() -> void
```

or implement an editor helper:

```gdscript
func _regenerate_row_identity(resource: Resource) -> void
```

### Insertion behavior

- If a row is selected, paste immediately after it.
- If no row is selected, paste at the end of the active body.
- After paste, select the newly pasted row.
- Mark preview dirty.
- Refresh rows and inspector.

### Cross-sheet behavior

Near-term behavior may be limited to the current sheet/editor session.

Later behavior should support:

- copy/paste between sheets
- copy/paste between sheet functions/subsheets
- optional plain-text JSON clipboard format
- paste validation when referenced variables/functions/providers are missing

### Reference behavior

When pasted rows reference variables, functions, or custom provider ACEs:

- keep references unchanged
- validate missing references after paste
- show warnings rather than silently rewriting references

Examples:

- If pasted row references `health` but target sheet lacks `health`, show warning.
- If pasted row calls sheet function `apply_damage` but target sheet lacks it, show warning.
- If pasted row uses provider `MyGame.Combat` but provider is unavailable, show warning.

### Structural blocks

When scripted structural blocks land, copy/paste must support deep-copying full nested bodies:

```text
If health < 50
  Then:
    Print "low"
  Else:
    Print "ok"
```

Pasting this block should preserve child rows and body-slot structure while regenerating identities for every copied row/block.

---

## 13) Sheet variables

Sheet variables are sheet-owned, editor-managed values that compile to GDScript member variables.

Current data shape:

```gdscript
variables = {
	"health": {
		"type": "int",
		"default": 100,
		"exported": true
	}
}
```

MVP variable UI should support:

- Add Variable
- Delete Variable
- Rename Variable
- Type dropdown
- Default value editor
- Export checkbox
- Validation for duplicate/invalid names

Initial types:

- `int`
- `float`
- `String`
- `bool`
- `NodePath`
- `Variant`

Compiler output example:

```gdscript
@export var health: int = 100
@export var speed: float = 200.0
@export var can_move: bool = true
```

Variable-aware ACE behavior:

- `SetVar`, `AddVar`, and `CompareVar` should prefer a variable picker instead of raw text.
- If `SetVar` / `AddVar` defaults to `my_var`, the editor may auto-create:

```gdscript
current_sheet.variables["my_var"] = {
	"type": "int",
	"default": 0
}
```

only when the variable does not already exist.

Rename behavior:

- MVP may warn that existing references must be updated manually.
- Later versions should offer safe rename with reference updates across conditions/actions/functions.

---

## 14) Sheet functions / local subsheets

Sheet functions, also called local subsheets, are reusable visual logic blocks owned by a single `EventSheetResource`.

They solve repeated action sequences such as:

- move player
- apply damage
- recalculate stats
- transition sequence
- dialogue sequence

Data model foundation:

```gdscript
@export var functions: Array[Resource] = []
```

on `EventSheetResource`, using `EventFunction` resources.

Recommended UI:

```text
Sheet Functions
[+] Add Function
- apply_damage
- recalculate_stats
- run_transition
```

MVP scope:

- create/delete/rename sheet function
- no parameters initially
- action/event-row body
- `Call Sheet Function` action
- compile each sheet function to a private generated GDScript function

Generated output example:

```gdscript
func _ef_func_recalculate_stats() -> void:
	max_health = base_health + level * 10
	attack = base_attack + level * 2
```

Call action output:

```gdscript
_ef_func_recalculate_stats()
```

Deferred features:

- function parameters
- return values
- async flags
- recursion/call graph validation
- find usages
- safe rename

---

## 15) Scripted ACE providers

Scripted ACE providers let project code define custom visual scripting blocks using GDScript.

A provider can define:

- provider ID
- display name
- trigger descriptors
- condition descriptors
- action descriptors
- expression descriptors
- params / UI hints
- codegen templates

MVP provider base class concept:

```gdscript
@tool
extends Resource
class_name EventForgeProvider

func get_provider_id() -> String:
	return ""

func get_display_name() -> String:
	return ""

func get_descriptors() -> Array[ACEDescriptor]:
	return []
```

Example custom action provider:

```gdscript
@tool
extends EventForgeProvider
class_name CombatACEProvider

func get_provider_id() -> String:
	return "MyGame.Combat"

func get_display_name() -> String:
	return "Combat"

func get_descriptors() -> Array[ACEDescriptor]:
	var descriptor: ACEDescriptor = ACEDescriptor.new()
	descriptor.provider_id = get_provider_id()
	descriptor.ace_id = "ApplyDamage"
	descriptor.display_name = "Apply Damage"
	descriptor.ace_type = ACEDescriptor.ACEType.ACTION
	descriptor.codegen_template = "{target}.apply_damage({amount})"

	var target: ACEParam = ACEParam.new()
	target.id = "target"
	target.display_name = "Target"
	target.type_name = "Node"
	target.default_value = "self"

	var amount: ACEParam = ACEParam.new()
	amount.id = "amount"
	amount.display_name = "Amount"
	amount.type_name = "int"
	amount.default_value = "10"

	descriptor.params = [target, amount]
	return [descriptor]
```

Visual UI example:

```text
Apply Damage
Target: [ self ]
Amount: [ 10 ]
```

Generated code:

```gdscript
self.apply_damage(10)
```

Discovery/registration options:

- explicit project setting list of provider scripts
- provider folder scan, e.g. `res://eventforge_providers/`
- runtime registration through `EventForgeBridge.register_provider(...)`

Security note:

> Scripted providers are trusted project/editor code. Because they are `@tool` scripts, they can run in the Godot editor. Users should only install providers from trusted sources.

---

## 16) Scripted structural blocks

Scripted structural blocks are advanced provider-defined visual blocks with custom codegen and body slots.

Examples:

- If block
- For loop
- While loop
- Sequence block
- Await block
- Quest branch block
- Dialogue choice block

This is distinct from simple ACE descriptors because structural blocks may contain nested visual bodies.

Conceptual base class:

```gdscript
@tool
extends Resource
class_name EventForgeBlockDefinition

func get_descriptor() -> Dictionary:
	return {}

func validate(_context: EventForgeValidationContext) -> Array[String]:
	return []

func generate_code(_context: EventForgeCodegenContext) -> PackedStringArray:
	return PackedStringArray()
```

Example If block definition:

```gdscript
@tool
extends EventForgeBlockDefinition
class_name IfBlockDefinition

func get_descriptor() -> Dictionary:
	return {
		"id": "Core.IfBlock",
		"display_name": "If",
		"category": "Flow",
		"kind": "block",
		"inputs": [
			{
				"id": "condition",
				"display_name": "Condition",
				"type": "expression",
				"ui": "expression_editor",
				"default": "true",
				"required": true
			}
		],
		"body_slots": [
			{"id": "then", "display_name": "Then"},
			{"id": "else", "display_name": "Else", "optional": true}
		]
	}

func generate_code(context: EventForgeCodegenContext) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var condition: String = context.get_input("condition", "true")
	lines.append("if %s:" % condition)
	lines.append_array(context.generate_body("then", "\t"))
	if context.has_body("else"):
		lines.append("else:")
		lines.append_array(context.generate_body("else", "\t"))
	return lines
```

Deferred dependencies:

- stable nested row/body model
- type-aware inspector widgets
- compiler context object
- validation context object
- source mapping from rows to generated line ranges

---

## 17) Phase breakdown

- Phase 1: data model, registry, compiler path, runtime bridge
- Phase 1.1: cleanup and project structure alignment
- Phase 2 MVP: functional editor shell + dual/split view + read-only preview
- Phase 2.1: trigger/condition/action insertion from palette, param inspector, save/load sheet operations
- Phase 2.2: sheet variable editor, variable-aware ACE params, and row copy/paste/duplicate
- Phase 2.3: sheet functions/local subsheets without parameters
- Phase 3: scripted ACE providers with template-based codegen
- Phase 4: scripted structural blocks with ports/body slots/custom codegen
- Phase 5: importer and editable GDScript round-trip

---

## 18) Implementation notes

- UI is currently built programmatically; `.tscn` editor scenes are optional later.
- Keep plugin startup behavior and autoload bridge compatibility.
- Keep bridge class name as `EventForgeBridgeRuntime` while autoload singleton remains `EventForgeBridge`.
- Bottom panel integration is acceptable Phase 2 fallback for reduced complexity.
- Prefer typed GDScript and tabs for indentation.
- Avoid writing generated preview files into `res://` for unsaved sheets.
- Copy/paste should deep-copy resources and regenerate row/block identities.
- Copy/paste should validate references but should not silently rewrite variables/functions/providers.

---

## 19) MVP success criteria

Reviewer can:

1. Open repository root project in Godot.
2. Enable EventForge and see `[EventForge] v0.1.0 loaded`.
3. Open EventForge UI panel.
4. Create new sheet and add event row(s).
5. Switch between Event Sheet, GDScript, and Split modes.
6. Select triggers/conditions/actions from the palette.
7. Edit params in the inspector.
8. Copy, paste, and duplicate event rows.
9. Refresh/Compile and see read-only generated code preview update.
10. Save and load `.tres` sheets.
11. Observe status feedback (success/error/dirty preview).

Phase 2.1 behavior details:

### Palette-driven editing

- `ACEPalette.ace_selected` is connected in the editor controller.
- Trigger selection assigns the selected row trigger.
- If no row is selected and a trigger is chosen, a new row is created and selected first.
- Condition/action selection requires a selected row; otherwise status shows `Select an event row first.`
- Expressions are currently not inserted directly and report: `Expressions are not inserted directly yet.`

### Default parameter materialization

- Trigger/condition/action instances are materialized from descriptor params.
- Built-in defaults are set for Phase 1 ACEs to keep generated code valid (for example `PrintLog.message`, `SetVar`, `AddVar`, `CompareVar`, `EmitSignal`, `HasGroupMember`, `OnSignal`).
- When inserting `SetVar` or `AddVar`, the editor auto-creates `variables["my_var"] = { "type": "int", "default": 0 }` if it is missing.
- Picker-created conditions/actions are normalized to include descriptor defaults when added.

### Save and load operations

- Toolbar includes: **Open Sheet**, **Save Sheet**, **Save Sheet As**.
- Open uses `EditorFileDialog` and loads `.tres`/Resource files.
- Save writes to existing `resource_path` when present.
- Save As prompts for a destination path.
- Persistence is done via `ResourceSaver.save(sheet, path)` and `load(path)` + `set_sheet(...)`.
- Fallback paths remain available for constrained contexts:
  - Open: `res://demo/sheets/player.tres`
  - Save: `res://demo/sheets/editor_saved_sheet.tres`

### GDScript preview scope

- GDScript preview remains read-only in Event Sheet / Split / GDScript modes.
- Round-trip GDScript editing is still deferred to later importer-focused phases.

Future expansion criteria include:

- edit sheet variables visually
- call sheet functions/subsheets
- register a custom scripted ACE provider
- define a scripted structural block with body slots
