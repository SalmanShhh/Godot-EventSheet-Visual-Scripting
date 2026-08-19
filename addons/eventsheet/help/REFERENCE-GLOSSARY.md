# Glossary - Construct 3 ↔ Godot ↔ Godot EventSheets

A one-page Rosetta Stone. If you come from **Construct 3**, read the left column. If you come from **Godot**, read the middle. The right column is what the thing is called *here*. A short table of EventSheets-only terms follows the main one.

## The Rosetta Table

| Construct 3 | Godot | Godot EventSheets | Notes |
| --- | --- | --- | --- |
| Event sheet | Script (`.gd`) | **Event sheet** (a `.gd` file) | A sheet **is** a plain `.gd` script - open it in Godot's script editor or auto-preview it as events; the round-trip is lossless and editable. (`.tres` still works but is no longer required or the default.) Delete the plugin and the script still runs. |
| Event | `if` block / `func` body | **Event** | A row with **Conditions** (left lane) and **Actions** (right lane). |
| Condition | `if` expression | **Condition** | The "when" of an event. |
| Action | statement | **Action** | The "do" of an event. |
| Expression | GDScript expression | **ƒx expression** | A value typed into a parameter; it *is* plain GDScript, with autocomplete + live validation. |
| Plugin / Behavior ACEs | engine API | **ACE** (Action / Condition / Expression) | The vocabulary you pick from. 920+ builtin, plus your addons. |
| Trigger (e.g. *On start of layout*) | signal / `_ready` / `_process` | **Trigger** | The green "On …" row that starts an event (On Ready, Every Frame, On Pressed, On Input, signals…). |
| Behavior (Platformer, 8-Direction…) | a script/node component | **Behavior pack** | A reusable event-sheet pack you attach as a child node. 76 bundled. |
| Instance variable | member `var` | **Variable** (global) | Compiles to a class member (`var` / `@export var`). Tick **Editable in the Inspector** for a designer knob (an **Inspector chip** shows on the row + in the Inspector); organize knobs with **`@export_group` / `@export_subgroup`** ("Group › Subgroup" chips); typed vars get live Inspector **drawers**. Lossless `.gd` round-trip. |
| Local variable | local `var` | **Local variable** | Scoped to one event body. |
| Family | (no direct equal) | **Family** / Group / Include | Declare a sheet as a **Family** for family-scoped iteration (see the **Family Arena** showcase). Groups organize rows; Includes are shared library sheets. |
| Layout | Scene (`.tscn`) | Scene | Use Godot scenes directly. |
| Layer | CanvasLayer / Z-index | CanvasLayer / Z-index | Native Godot. |
| Object type / Instance | Class / Node | Node | The sheet's **host class** is the node type it runs on. |
| Function | `func` | **Function** | A reusable event block; can be published as an ACE. |
| Wait / Wait for signal | `await` | **Wait / Wait For Signal** | Compiles to `await`. |
| System expressions (`int()`, `random()`…) | GDScript / `@GlobalScope` | **System / Math ACEs** | Plus a **Helpers** set (Set/Get Property, Call Method, Run GDScript) for anything not covered. |
| Debugger | Remote debugger | **Breakpoints + Live Values** | F9 breakpoints (now **conditional**), editable Live Values, and **Tools ▸ Check Sheet for Errors**. |

## EventSheets-Only Terms

| Term | Meaning |
| --- | --- |
| **Host class** | The node type a sheet runs on (set in the Sheet Type dialog). It decides which members your ƒx expressions can reach. |
| **Compile** | Turn the sheet into its `.gd` output. Happens on save (compile-on-save) and on export, so a stale script can never ship. |
| **Parity contract** | The generated code is plain, idiomatic GDScript with **no runtime dependency** on the plugin and no performance difference from hand-written code (test-enforced). |
| **ACE picker** | The Create-Node-style dialog you add Conditions/Actions/Triggers from (Favorites + Recent panes, a description panel, search with C3 synonyms). |
| **Reverse-lift** | Opening a `.gd` file *as* a sheet, or pasting GDScript, and getting events back. The importer de-codes function bodies, `if/elif/else`, `for`/`while`/`repeat` loops, and `match` into structured rows - lossless and editable both ways. |
| **Family** | A sheet declared as a Family, so its events iterate over a whole family of nodes (family-scoped iteration). See the **Family Arena** showcase. |
| **Extract-to-Function** | Turn a selection of actions into a named, reusable function in place; calls then render as a first-class **ƒ** verb. |
| **Inspector drawer** | A live widget for a typed exported variable: a **progress bar** (int/float) or a **min-max slider** (Vector2), a direction **dial** (Vector2), a colour **swatch** row (Color), a **texture preview** (Texture2D), an inline **curve** (Curve), a **toggle row**, or an editable **table** (whose fixed-choice columns can read as labels while storing their real key). Authored via a per-type picker with a live preview; see the **Inspector Playground** showcase. Degrades to a plain field without the editor plugin (parity-clean). |
| **Simple Mode** | A beginner-friendly audience setting (offered on first run) that trims the options and vocabulary shown, so a newcomer isn't handed the full registry at once. |
| **Number scrubbing** | Drag a parameter's **label** sideways to slide its number, with the value updating as you go (Shift for a fine pass, Ctrl for a coarse one). The gesture only arms when the field currently holds a plain number, so a field reading `speed * delta` can never be flattened into a literal by a stray drag. |
| **Curating a provider** | Editing what one of your own scripts publishes, from the preview table in **Sheet ▸ Custom Actions…**: tick a member to publish or not, correct its kind, rename the verb, re-file its category, and shape its parameters. **Curate Script…** then writes those choices back into the file as `## @ace_*` comments - the file is backed up first, only `##` comment lines are added or removed (no signature and no body is touched), and re-applying the same edits changes nothing. |
| **Forwarding shim** | A deprecated stand-in function of a verb's OLD name, appended by **Keep Old Name…** after you rename the real one. Renaming a member changes the verb's identity, and every sheet already holds the old call *text*, so only a real member of the old name can keep those sheets working. The shim just forwards, and is hidden from the picker so it can't be added to new work. |
| **Orphaned verb** | A row (or a compiled line) calling a provider member that no longer exists - the one failure here that compiles green and only breaks when the game runs it. The **Project Doctor**'s `orphaned-verb` check reads the emitted calls and flags them, and stays silent unless it can prove the member is absent from the script's own API, its inheritance chain, and its engine base class. |
| **Self section** | The pinned first group of the ƒx **Expressions dictionary** - C3's `Self.` reflex. Type `self` in any ƒx field and it scopes to what this sheet's object knows about itself: **Variables** (bare names), **Properties** (the C3 commons under both spellings - `X · position.x`, `Opacity · modulate.a`, host-gated so a 3D body gets no scalar Angle), **Functions** (value-returning ones, as ready calls), a **Host** group in behaviour mode (`host.position.x`), and **Behaviours** - attached packs' knobs and value verbs as `$PackName.member` chains whose node token stays selected for retargeting. A **Robust behaviour lookups** toggle swaps chains to `get_node_or_null("Name")` (default ON for sheets that spawn), selecting your node in the Scene dock grounds the group to its actual children, and while **Live Values** streams the group reads the RUNNING instance - behaviours attached at runtime included, under their real names. Everything inserts plain GDScript; no `Self` token ever reaches your code. |

## The variable verbs, and their older names

The sheet changes a variable with five verbs and asks about one with two conditions. They are named
the same in the picker and in the reading, so what you pick is what you read.

| The verb | What it writes | Older name here |
| --- | --- | --- |
| **Set value** | `hp = 100` | Set Variable |
| **Add to** | `score += 10` | Add Variable |
| **Subtract from** | `hp -= dmg` | Subtract From Variable |
| **Toggle boolean** | `alive = not alive` | Toggle |
| **Set boolean** | `muted = true` | (done with Set Variable) |
| **Compare variable** | `if hp <= 0:` | Compare Variable |
| **Boolean is true / is false** | `if alive:` / `if not muted:` | Is boolean set |

A boolean condition reads as the plain sentence `alive is true` / `muted is false`, never as
"Is alive set", and inverting one flips the word rather than adding a mark. The ids behind all of
them are frozen: only the names you see and where they sit in the picker changed, so every sheet
that already used them keeps working.

See also the [C3 migration guide](GUIDE-MOVING-FROM-ANOTHER-EVENT-SHEET-EDITOR.md) (every C3 plugin/behavior mapped) and the [recipes](GUIDE-RECIPES.md) (build something end to end).
