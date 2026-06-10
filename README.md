# Godot EventSheets

**Godot EventSheets** (engine codename *EventForge* — you'll see that prefix on internal class names) brings **Construct 3-style event sheets to Godot 4.x**. Sheets are authored in a
fast visual editor and **compile to plain, readable, typed GDScript** — no runtime
interpreter, no plugin dependency in your exported game, and **zero performance difference
from hand-written code** (a guarded, tested contract).

```text
Conditions                        | Actions
----------------------------------+--------------------------------
▶ Every tick                      |
   [icon] System  Is on floor     | [icon] System  Queue free
								  | GDScript  health -= 1
```

## Install

1. Copy `addons/eventforge/` and `addons/eventsheet/` into your Godot project.
2. In **Project > Project Settings > Plugins**, enable **Godot EventSheets**.
3. Open the **EventSheet** workspace tab in the main editor strip (next to Script/2D/3D).
4. Optional: copy `eventsheet_addons/` for the sample behaviors and demo custom ACEs.

## Quickstart

1. Open the repository project (`project.godot`) in Godot **4.5+**.
2. Open `demo/sheets/player.tres` in the EventSheet tab, or just start a new sheet.
3. Add events from the picker (live search, C3 synonym aliases like "every tick"),
   double-click anything to edit, and press **Compile** — the generated `.gd` is the
   script you attach and ship.

## What's implemented (major phases)

### The editor (C3-parity UX on a virtualized canvas)
- **Custom-rendered virtualized viewport** — tens of thousands of events/ACEs scroll,
  zoom, and edit fluidly; only visible rows are drawn, never per-row widgets.
- Construct-style grammar: two-lane condition/action rows, **object icons + labels** per
  cell, flat cells, per-cell hover, whole-cell click targets, value highlighting, crisp
  text at every zoom, drag/drop with insertion arrows and drag ghosts, footer
  "Add event…" rows, drag-resizable lane divider, groups/comments/variables as rows,
  multi-select, copy/paste, collective enable/disable with strikethrough, full undo/redo.
- **Theming**: every color/metric is a token on `EventSheetEditorStyle` resources —
  bundled presets, per-sheet overrides, and a **Godot-adaptive default** that derives the
  sheet look from your editor theme. (`docs/EVENTSHEET_THEME_TOKEN_SPEC.md`; element
  visual scenes under `addons/eventsheet/elements/` remain supported.)

### The compiler (sheets → plain GDScript)
- Events group by trigger into handler functions; conditions become `if` expressions,
  actions direct statements; **sub-events compile nested** under their parent's
  conditions; **Else / Else-If chains** emit `elif`/`else`; nested comments become `#`
  lines; variables in the event flow become function locals.
- **Signal triggers really connect**: `_ready` gets `signal.connect(handler)` lines —
  self signals (compile-time validated against the host class + block-declared signals),
  **other nodes' signals** (`trigger_source_path`), and custom addon signal triggers with
  baked argument signatures.
- **Performance-parity contract** (`docs/GDSCRIPT-PAIRING-SPEC.md`, Principles #5): no
  `call()`/`Callable` indirection, no reflection, no plugin classes in output, static
  types wherever known — enforced permanently by `tests/codegen_parity_test.gd`.
- Source maps: every row knows exactly which generated lines it produced.

### GDScript pairing (two languages, one project)
- **GDScript panel with provenance both ways**: select a row → its generated lines
  highlight; **click a line → the row that generated it is selected**.
- **GDScript blocks in sheets**: class-level blocks (helpers, signals, `@onready`) and
  **in-flow blocks inside events** (C3 inline scripting) with compile-check linting and
  sheet-aware completion. Expression (`ƒx`) fields are plain GDScript with **live
  validation** against your sheet's variables and host members.
- **Open ANY `.gd` file as an event sheet** (GDScript-backed sheets): the file stays the
  single source of truth, everything unrecognized is preserved verbatim, and untouched
  files round-trip **byte-identically** (golden-tested). **ACE-level lifting** reverses
  codegen templates, so EventForge-generated scripts re-open as real events — verified by
  byte-identical recompile, with graceful fallback to code blocks.
- **Shareable snippets**: copying rows also puts a portable text snippet on the system
  clipboard — paste into another project (or a forum post); variables auto-create, UIDs
  refresh, baked templates keep addon ACEs compiling. And **pasting raw GDScript converts
  to events automatically** (trigger functions lift, declarations become variables, the
  rest stays as code blocks).

### Extending the vocabulary (zero configuration, no JSON)
- **Custom ACE addons**: drop a script into `res://eventsheet_addons/` — `class_name` is
  the provider, `##` doc comment the description, and `@ace_*` annotations
  (`@ace_action/condition/trigger`, `@ace_name`, `@ace_category`, `@ace_icon`,
  `@ace_display_template`, `@ace_codegen_template`, `@ace_param_hint`, `@ace_hidden`)
  shape picker display and generated code. Annotated signals become triggers. Other
  plugins can register providers from code via
  `EventForgeBridge.register_script_as_provider`; methods without a codegen template
  compile **instance-backed** (the generated script owns a plain instance of the addon —
  still zero plugin classes in output).
- **Custom node types from sheets**: set `custom_class_name`/`custom_class_icon` (or use
  the **Sheet Type…** toolbar dialog) and the generated script emits
  `@icon(...)` + `class_name X` — your sheet-defined node appears in Godot's Create Node
  dialog like any GDScript class.
- **Behaviors authored as event sheets**: behavior sheets compile to attachable Node
  components with a typed `host` accessor (the parent), exported parameters, and
  **expose-as-ACE functions** that publish the behavior's own actions project-wide via the
  addon folder. Identity UX everywhere: ⚙ tab badges, in-sheet banner, host-aware column
  header. **Fourteen sample packs included**: `PlatformerMovement`, `EightDirectionMovement`,
  `TimerBehavior`, `FlashBehavior`, and `StateMachineBehavior` (with an annotated
  block-condition example) — all shipped as editable sheets + compiled scripts.
- **Use it all from hand-written GDScript** like regular code — typed autocomplete,
  signals, `extends` — because generated classes *are* regular code.

## Project layout

| Path | What it is |
|---|---|
| `addons/eventforge/` | Data model, compiler, importer, builtin ACEs, runtime bridge |
| `addons/eventsheet/` | The editor: dock, virtualized viewport, renderer, picker, themes, lint, addon scanner |
| `eventsheet_addons/` | Zero-config ACE addons + the sample behavior packs |
| `demo/` | Demo sheets, themes, and the golden compiled output |
| `tests/` | Headless test suite (580+ assertions) — `tests/run_tests.gd` (full) and `tests/run_perf.gd` (headless-safe subset) |
| `docs/` | Specs: editor UI, GDScript pairing, theme tokens, architecture |

## Verifying a change

```text
godot --headless --path . --script tests/run_perf.gd    # fast, headless-safe suite
godot --headless --path . --script tests/run_tests.gd   # full suite
```

Every feature lands with tests, a CHANGELOG entry, and its spec updated — see
`docs/GDSCRIPT-PAIRING-SPEC.md` and `docs/EDITOR-UI-SPEC.md` for the authoritative
feature-by-feature status.

## Releases & CI

Pushes and PRs run the headless test suite (`.github/workflows/ci.yml`). Pushing a tag
like `v0.2.0` runs the test gate, stamps the version into `plugin.cfg`, and publishes a
GitHub Release with two zips (`.github/workflows/release.yml`):
`godot-eventsheets-<v>.zip` (the addons, drop-in layout) and `godot-eventsheets-samples-<v>.zip`
(behavior packs + demo project).

## Road to 1.0 (remaining)

All planned 1.0 phases are implemented — including multiline/colored comments with
comment↔action conversion, the **export-integrity hook** (every sheet recompiles when an
export starts, so stale generated scripts can never ship), and the designer-facing
**visual theme editor** (live preview + reflective token form, preset saving). Release housekeeping is
done too: the test suite is fully green (594 passing, 0 failures), the
[C3 migration guide](docs/C3-MIGRATION-GUIDE.md) is in, and the 10k-row perf baseline
holds (~490 ms build, 8-row draw window, zero per-row widgets). Post-1.0 candidates: MCP server for AI tooling, expression
autocomplete, more behavior packs.

## License

MIT. See `LICENSE`.
