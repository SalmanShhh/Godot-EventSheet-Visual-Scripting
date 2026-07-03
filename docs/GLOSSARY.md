# Glossary - Construct 3 ↔ Godot ↔ Godot EventSheets

A one-page Rosetta Stone. If you come from **Construct 3**, read the left column. If you come
from **Godot**, read the middle. The right column is what the thing is called *here*.

| Construct 3 | Godot | Godot EventSheets | Notes |
| --- | --- | --- | --- |
| Event sheet | Script (`.gd`) | **Event sheet** (a `.gd` file) | A sheet **is** a plain `.gd` script - open it in Godot's script editor or auto-preview it as events; the round-trip is lossless and editable. (`.tres` still works but is no longer required or the default.) Delete the plugin and the script still runs. |
| Event | `if` block / `func` body | **Event** | A row with **Conditions** (left lane) and **Actions** (right lane). |
| Condition | `if` expression | **Condition** | The "when" of an event. |
| Action | statement | **Action** | The "do" of an event. |
| Expression | GDScript expression | **ƒx expression** | A value typed into a parameter; it *is* plain GDScript, with autocomplete + live validation. |
| Plugin / Behavior ACEs | engine API | **ACE** (Action / Condition / Expression) | The vocabulary you pick from. ~450 builtin, plus your addons. |
| Trigger (e.g. *On start of layout*) | signal / `_ready` / `_process` | **Trigger** | The green "On …" row that starts an event (On Ready, On Process, On Pressed, On Input, signals…). |
| Behavior (Platformer, 8-Direction…) | a script/node component | **Behavior pack** | A reusable event-sheet pack you attach as a child node. 31 bundled. |
| Instance variable | member `var` | **Variable** (global) | Compiles to a class member (`var` / `@export var`). Tick **@export** for a designer knob (an **@export badge** shows on the row + in the Inspector); organize knobs with **`@export_group` / `@export_subgroup`** ("Group › Subgroup" chips); typed vars get live Inspector **drawers**. Lossless `.gd` round-trip. |
| Local variable | local `var` | **Local variable** | Scoped to one event body. |
| Family | (no direct equal) | **Family** / Group / Include | Declare a sheet as a **Family** for family-scoped iteration (see the **Family Arena** showcase). Groups organize rows; Includes are shared library sheets. |
| Layout | Scene (`.tscn`) | Scene | Use Godot scenes directly. |
| Layer | CanvasLayer / Z-index | CanvasLayer / Z-index | Native Godot. |
| Object type / Instance | Class / Node | Node | The sheet's **host class** is the node type it runs on. |
| Function | `func` | **Function** | A reusable event block; can be published as an ACE. |
| Wait / Wait for signal | `await` | **Wait / Wait For Signal** | Compiles to `await`. |
| System expressions (`int()`, `random()`…) | GDScript / `@GlobalScope` | **System / Math ACEs** | Plus a **Helpers** set (Set/Get Property, Call Method, Run GDScript) for anything not covered. |
| Debugger | Remote debugger | **Breakpoints + Live Values** | F9 breakpoints (now **conditional**), editable Live Values, and **Tools ▸ Check Sheet for Errors**. |

## A few EventSheets-only terms

- **Host class** - the node type a sheet runs on (set in the Sheet Type dialog). It decides which
  members your ƒx expressions can reach.
- **Compile** - turn the sheet into its `.gd` output. Happens on save (compile-on-save) and on
  export, so a stale script can never ship.
- **Parity contract** - the generated code is plain, idiomatic GDScript with **no runtime
  dependency** on the plugin and no performance difference from hand-written code (test-enforced).
- **ACE picker** - the Create-Node-style dialog you add Conditions/Actions/Triggers from
  (Favorites + Recent panes, a description panel, search with C3 synonyms).
- **Reverse-lift** - opening a `.gd` file *as* a sheet, or pasting GDScript, and getting events back.
  The importer de-codes function bodies, `if/elif/else`, `for`/`while`/`repeat` loops, and `match`
  into structured rows - lossless and editable both ways.
- **Family** - a sheet declared as a Family, so its events iterate over a whole family of nodes
  (family-scoped iteration). See the **Family Arena** showcase.
- **Extract-to-Function** - turn a selection of actions into a named, reusable function in place;
  calls then render as a first-class **ƒ** verb.
- **Inspector drawer** - a live widget for a typed exported variable: a progress bar (int/float),
  a direction **dial** (Vector2), a colour **swatch** row (Color), a **texture preview** (Texture2D),
  or an inline **curve** (Curve). Authored via a per-type picker with a live preview; see the
  **Inspector Playground** showcase. Degrades to a plain field without the editor plugin (parity-clean).
- **Simple Mode** - a beginner-friendly audience setting (offered on first run) that trims the
  options and vocabulary shown, so a newcomer isn't handed the full registry at once.

See also the [C3 migration guide](C3-MIGRATION-GUIDE.md) (every C3 plugin/behavior mapped) and the
[recipes](RECIPES.md) (build something end to end).
