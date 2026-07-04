# AGENTS.md

## Repo overview

GodotEventSheet (EventForge) is a Godot 4.x plugin (verified through **Godot 4.7 stable**) that provides a Construct-style EventSheet editor and compiler pipeline. The active editor pass keeps a custom-rendered viewport, semantic row/span data, and Godot Resource-based authoring for themes and sheet data.

## Architecture notes

- Plugin entry: `res://addons/eventforge/plugin.gd` (registers the workspace, export
  integrity, the Live Values debugger bridge and the attribute-drawers inspector plugin)
- Main workspace/editor surface: `res://addons/eventsheet/editor/event_sheet_dock.gd`
- Custom-rendered row viewport: `res://addons/eventsheet/editor/event_sheet_viewport.gd`
- Row chrome/text drawing: `res://addons/eventsheet/editor/event_row_renderer.gd`
- Compiler (pipeline overview in its header comment): `res://addons/eventforge/compiler/sheet_compiler.gd`
- Builtin ACE vocabularies: per-module files in `res://addons/eventforge/registration/modules/`
  (`core`/`system`/`device`/`audio`/`native_3d`/`collection`/`collision`/`ui`/`particle`/`tilemap`/`physics`/`loop`/`helper`) built via
  `ace_factory.gd` (module contract documented there); `builtin_aces.gd` concatenates them
  in registry order. `helper_aces.gd` is the generic "structured escape hatch" vocabulary -
  registered LAST and excluded from the reverse-lifter so its catch-all templates
  (`{target}.{method}(…)`, `Run GDScript {code}`) never shadow specific ACEs.
- Importer/lifter (lossless GDScript pairing): `res://addons/eventforge/importer/` - the
  lifter sets `RawCodeRow.lift_note` ("no matching ACE template") on lines it can't lift,
  surfaced as an editor hint.
- MCP server (AI tooling, policy-aware): `res://addons/eventsheet/mcp/mcp_server.gd`
- Theme resources: `res://addons/eventsheet/theme/*.gd`
- Headless suites: `res://tests/run_perf.gd` (safe gate) and `res://tests/run_tests.gd`
  (full; a tail segfault AFTER the summary is a known harmless teardown flake - count
  `[FAIL]` lines)
- Maintenance tools: `tools/` (per-pack builders in `tools/pack_builders/` run by
  `build_sample_behaviors.gd`; `build_examples.gd` for the playable showcases;
  demo-golden regenerator; theme presets + header backfill; `audit_addons.gd` drift gate)

## EventSheet editor structure

- `EventSheetDock` owns toolbar, dialogs, ACE picker, variable workflows, context menus, undo/redo wiring, and theme load/reload.
- `EventSheetViewport` owns hit-testing, stacked event layout, selection state, inline editing, drag/drop, zoom, and keyboard navigation.
- `EventRowRenderer` paints event/group/comment rows from `EventRowData` plus theme resources.
- `ACEPickerDialog` and `ACEParamsDialog` are the main existing extension points for adding new event/condition/action flows.

## Theme system notes

- `EventSheetEditorStyle` is the installable theme resource.
- `EventSheetEventStyle` now covers structural tokens: sheet background, event block shell, lane colors, group/comment chrome, and interaction fills.
- `EventSheetElementStyle` covers condition/action entry tokens.
- Designers edit `.tres` token resources directly (or through the Theme Editor dialog);
  the tokens are the single source of truth for the renderer.
- Theme docs:
  - `docs/EVENTSHEET_THEME_EDITABILITY.md`
  - `docs/EVENTSHEET_ALIGNMENT_GUIDE.md`

## Docs map

- `README.md` - install + high-level workflow
- `docs/GDSCRIPT-PAIRING-SPEC.md` - how the sheet pairs with GDScript (blocks, codegen tooltips, expressions, C3 synonyms, importer round-trip)
- `docs/EVENTSHEET_THEME_EDITABILITY.md` - designer-facing theme workflow
- `docs/EVENTSHEET_ALIGNMENT_GUIDE.md` - stacked layout tuning
- `docs/C3-MIGRATION-GUIDE.md` - user-facing C3→Godot concept/behavior/plugin map
- `docs/CUSTOM-BLOCKS-GUIDE.md` - the Custom Block API (register non-ACE row kinds; contract, built-ins, use cases)
- `docs/TRANSLATING-YOUR-GAME.md` - localisation the Godot way (globe-marked params, POT, Set Language)
- `docs/MCP-SERVER.md` - the AI-tooling protocol (list/read/compile/lint/snippets)
- `docs/UNINSTALL.md` - clean-removal guide (keep/remove table; the zero-runtime-dependency covenant as a guided teardown)
- `docs/INSPECTOR-ATTRIBUTES-SPEC.md` - Unity-style rich-inspector attributes (all tiers shipped)
- `docs/ADDON-COMPOSITION-SPEC.md` - meta-packs, uses/requires, project policy (shipped)
- `docs/PROGRESSIVE-DISCLOSURE-SPEC.md` - tiered disclosure of dialog complexity (C3-migrant-first; shipped)
- `docs/INCLUDES-SPEC.md` - Construct "Include event sheet" → compile-time merge (not yet `.gd` round-tripping)
- `docs/GROUPS-ROUNDTRIP-SPEC.md` - event-group round-trip (SHIPPED: groups survive `.gd` round-trips)
- `CONTRIBUTING.md` - dev setup, verification loop, house rules, gotcha list
- `CHANGELOG.md` - the authoritative feature ledger per release

## Standing contracts (read before changing the compiler or descriptors)

- **Parity**: generated GDScript is plain code - no plugin runtime, no indirection.
- **Lossless**: GDScript-backed sheets round-trip byte-identically (verify-lift gates).
- **Bake-at-apply**: templates bake onto ACEs when applied; descriptor changes never
  rewrite sheets. `ace_id`s are API - hide with `@ace_hidden`, never rename.
- **Policy gates, never bytes**: composition ProjectSettings only allow/warn/error.
- Indentation: **tabs everywhere** (the whole plugin was converted; the suite's style gate
  enforces it, with class_name-first headers and two blank lines around functions).
  See `CONTRIBUTING.md` for the gotcha list (e.g. `""` is a backspace escape;
  `Dictionary.get` doesn't fall back on empty values).

## Current known gaps

- Condition/action name vs description cells are documented as separate roles but still share one text token in the current renderer.
- The theme package manifest is documentation/template only; it is not auto-imported yet.
- UI screenshots require a Godot runtime run NON-headless: the `tools/render_*.gd` harness scripts generate real editor-UI PNGs (headless runs cannot render).
- The parallel Control-widget editor prototypes (`EventRowUI`, `GroupRowUI`, `CommentRowUI`, `VariableRowUI`, `SheetToolbar`, and assorted stubs) were **removed** - they could not scale to large sheets. The custom-rendered virtualized viewport (`EventSheetDock`/`EventSheetViewport`/`EventRowRenderer`) is the sole editor architecture. Variable-row text formatting that the removed widget owned now lives in `addons/eventsheet/editor/variable_row_format.gd` (`VariableRowFormat`).

## Guidance for future LLM-assisted work

- Keep the custom-rendered viewport/event-row approach; do not replace it with per-row Control widgets.
- Prefer surgical changes in `EventSheetDock`, `EventSheetViewport`, and theme resources over large rewrites.
- When adding interactions, preserve undo/redo and keep right-click selection preservation intact.
- When adding theme features, update both docs and bundled example themes together.
- Add focused tests in `tests/event_sheet_editor_test.gd`, `tests/event_sheet_style_test.gd`, and `tests/docs_integrity_test.gd` when changing editor behavior, theme assets, or documentation contracts.
