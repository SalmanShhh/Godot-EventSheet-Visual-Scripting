# Contributing to Godot EventSheets

Thanks for helping! This file is the distilled institutional knowledge - the rules that
keep 3,400+ assertions green and users' projects safe. Read it once; it will save you
hours.

## Dev setup

- **Godot 4.5+** (CI uses 4.5.1; the full suite is also verified green on **4.7 stable**,
  the current primary target). Open the repository root as the project.
- Run the suite before and after every change (see *The verification loop*).
- Line endings are **LF and load-bearing**: byte-exact golden tests fail on CRLF.
  `.gitattributes` enforces it; if a fresh checkout fails byte tests, run
  `git rm -rq --cached . && git reset --hard`.

## The verification loop (run all of it, in order)

```text
godot --headless --import --path .                      # 0 script/parse errors required
godot --headless --path . --script tests/run_perf.gd    # headless-safe gate (CI gate)
godot --headless --path . --script tests/run_tests.gd   # full suite
godot --editor --headless --quit-after 170 --path .     # editor smoke (then: git checkout -- project.godot)
godot --headless --path . --script tools/project_doctor.gd  # repo health (CI gate; -- --strict fails on warnings)
```

Quirks worth knowing:
- The **full suite can segfault on exit AFTER printing its summary** - that's harmless;
  count `[FAIL]` lines, ignore the exit code. CI does the same. (This was a 4.5.1 quirk; on
  4.7 the suite exits cleanly, but counting `[FAIL]` is still the version-safe habit.)
- The editor smoke occasionally exits 139 at teardown with zero script errors - re-run;
  clean twice in a row means it's fine.

## House rules (every slice)

1. **Tests + CHANGELOG + spec, always.** A feature lands with a focused test file
   registered in **BOTH** `tests/run_perf.gd` and `tests/run_tests.gd`, a CHANGELOG
   entry, and its spec updated (`docs/internal/SPEC-gdscript-pairing.md`). The README's
   status/milestones refresh with major updates.
2. **The compatibility covenant** (binding):
   - Generated GDScript never depends on the plugin at runtime.
   - Codegen templates **bake at apply** - changing a descriptor must never rewrite
     existing sheets. `ace_id`s are API: retire with `@ace_hidden`, never rename/delete.
   - **The lossless rule**: anything the importer can't model stays verbatim and
     round-trips byte-identically. A lift is valid only if re-emission reproduces the
     source exactly (verify-lift); golden tests enforce it.
3. **Performance parity**: no `call()`/`Callable` indirection, reflection, or plugin
   classes in generated output. `tests/codegen_parity_test.gd` enforces it permanently.
4. **No per-row Control widgets** in the sheet - everything paints through the
   virtualized viewport/renderer (10k-row budget).
5. **Zero-config addons**: no manifests/JSON. Everything derives from the script
   (`class_name`, doc comments, `@ace_*` annotations).
6. **Hidden-optimization rule**: ACE templates may emit expert idioms (e.g. `&"name"`
   StringName literals) - but user ƒx expressions and GDScript blocks are NEVER
   rewritten.
7. **Guardrails over errors**: dialogs sanitize what's fixable and block what isn't -
   broken GDScript must never commit to a sheet.

## Canonical emission (when you touch the compiler)

The importer's verify-lift depends on **exact emission forms**. If you change one, update
its lifter counterpart in the same commit and regenerate goldens:

```text
godot --headless --script tools/regenerate_demo_golden.gd
godot --headless --script tools/build_sample_behaviors.gd  # then tools/audit_addons.gd (drifted=0)
godot --headless --script tools/build_examples.gd          # the playable showcases (carousel/starfall/quest_fsm/platformer_shooter/swarm/family_arena/inspector_playground)
godot --headless --script tools/build_theme_presets.gd     # after theme-token additions
```

Canonical forms live in `sheet_compiler.gd` (`_emit_enum_line`, `_emit_signal_line`,
`_emit_tree_variable_line`, `_to_code_literal`, `_export_enum_prefix`) with matching
`_try_lift_*` parsers in `gdscript_importer.gd` / reverse matching in `ace_lifter.gd`.

## How to add things

- **A builtin ACE**: add it to the right per-vocabulary module in
  `addons/eventforge/registration/modules/` (`core_aces`, `system_aces`, `device_aces`,
  `audio_aces`, `native_3d_aces`, `collection_aces`, `collision_aces`, `ui_aces`, `particle_aces`,
  `tilemap_aces`, `physics_aces`, `loop_aces`, or `helper_aces`); `builtin_aces.gd`
  concatenates them **in order** (order is API - the reverse-lifter tries templates in
  registry order). Wrap NATIVE engine features (lane 1: the engine maintains the
  implementation, we maintain vocabulary). Use `node_type` for picker grouping, C3 names
  as display names, and add picker synonyms in `ace_picker.gd` if C3 users call it
  something else. **Helpers** is the generic "structured escape hatch" module - it stays
  registered LAST and is excluded from the reverse-lifter (`ace_lifter.gd` skips
  `category == "Helpers"`) so its catch-all templates never shadow a specific ACE.
- **An addon**: drop a script in `res://eventsheet_addons/` - see
  `demo_health_addon.gd` and the pack folders for every annotation in use.
- **A behavior pack**: add a per-pack builder in `tools/pack_builders/<slug>.gd`
  (mirror `line_of_sight.gd` for conditions or `sine_3d.gd` for `@export` dropdowns +
  exposed actions; `_lib.gd` has the `save_pack` helper), register the slug in
  `tools/build_sample_behaviors.gd`, run it, then run `tools/audit_addons.gd` (must report
  `drifted=0` - the committed `.gd`/`.tres` must match a recompile). Add the pack path to
  `tests/sample_behavior_pack_test.gd` - the generic no-drift/load/publish asserts cover
  it automatically.
- **A theme preset**: add a palette to `tools/build_theme_presets.gd` and rerun it;
  presets are auto-discovered by the picker and Theme Editor.

## GDScript gotchas that have bitten before

- `"\b"` in a GDScript string is the **backspace** escape - word-boundary regexes need
  `"\\b"` in source.
- `Dictionary.get(key, fallback)` does **not** fall back on empty values, only missing
  keys.
- `EditorProperty` (and friends) are editor-only-instantiable - headless tests assert
  class *mappings*, not constructions.
- Docks/viewports run **outside the scene tree** in tests - never gate logic on
  `is_inside_tree()` unless you mean it.
- `ACEDefinition.codegen_template` lives in `definition.metadata`, not as a property.
- Typed-array `duplicate()` is **shallow** - restoring a backup does not undo mutations
  to shared row objects.

## Releases

Push a `v*` tag: `.github/workflows/release.yml` runs the gate, stamps `plugin.cfg`, and
publishes `godot-eventsheets-<v>.zip` + `godot-eventsheets-samples-<v>.zip`. Roll the
CHANGELOG `[Unreleased]` section into a dated version section in the same commit.

## Code style

Match the file you're in (tabs in `addons/eventforge/`, spaces in
`addons/eventsheet/editor/` - yes, really; don't "fix" it). Comment for contributors:
document schemas, extension points, and constraints the code can't show - not what the
next line does.

## Reviewable sheet diffs (teams)

`.tres` diffs are unreadable; the repo ships a git `textconv` driver that renders
sheets as rows (events, conditions, actions) in `git diff` and PR reviews. One-time
setup per clone:

```text
git config diff.eventsheet.textconv "sh tools/sheet_diff.sh"
```

(`.gitattributes` already maps `*.tres` to the driver; it needs Godot on PATH or in
`$GODOT`, prints non-sheet `.tres` verbatim, and never modifies files.)

## Release ritual

Tagging `vX.Y.Z` (push the tag; CI publishes the zips) also means:
1. Roll `[Unreleased]` into the version section in `CHANGELOG.md`.
2. Refresh `README.md` + `demo/README.md` (status, milestones, counts).
3. **Refresh the demo showcase**: `demo/` must exercise the release's headline
   features - every release ships a playable example making full use of what's new
   (sheets + scene + a "what to look at" note in `demo/README.md`).
