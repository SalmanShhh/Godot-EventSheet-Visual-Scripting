# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Godot EventSheets (engine codename EventForge): a Godot 4 `@tool` plugin providing a Construct 3-style event sheet editor that compiles sheets to plain, typed GDScript. `addons/eventforge/` is the data model, compiler, importer, and builtin ACE vocabulary; `addons/eventsheet/` is the editor (dock, virtualized viewport, renderer, picker, themes, MCP server); `eventsheet_addons/` holds the 31 behavior packs (COMPILER OUTPUT, regenerated from `tools/pack_builders/`); `AGENTS.md` has the deeper architecture map and standing contracts.

## Commands

Godot 4.7 lives at a nested path on this machine (the folder is named like the exe):

```
GODOT="/c/Users/mrlig/OneDrive/Desktop/GameDev Programs/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64_console.exe"
```

- Full test suite (auto-discovers `tests/*_test.gd` with `static func run() -> bool`):
  `"$GODOT" --headless --path . --script tests/run_tests.gd`
- Fast gate: `"$GODOT" --headless --path . --script tests/run_perf.gd`
- Single test: there is no filter flag; run a scratch SceneTree script that calls `MyTest.run()` then `quit(0)`, or just run the full suite and grep for the test's name.
- Pack drift gate (must print `drifted=0`): `"$GODOT" --headless --path . --script tools/audit_addons.gd`
- Rebuild all packs after touching `tools/pack_builders/`: `"$GODOT" --headless --path . --script tools/build_sample_behaviors.gd`
- Regenerate the vocabulary doc: `"$GODOT" --headless --path . --script tools/vocabulary_doc.gd`
- After adding a `class_name`, regenerate the editor class cache, then revert the churn:
  `"$GODOT" --editor --headless --path . --quit-after 3` followed by `git checkout -- project.godot`
- Editor-UI screenshots are possible: run a `tools/render_*.gd` harness NON-headless (set `root.gui_embed_subwindows = true` for dialogs); headless runs cannot render.

## Verifying results (the traps that bite here)

- **The suite can fail silently.** A test that crashes or returns non-bool produces ZERO `[FAIL]` lines; always check for the literal `All tests passed.` / `Some tests failed.` verdict line, never just grep for FAIL.
- **`_check(a and b, expected_string)` crashes the comparison** (`bool == String` is a runtime error in GDScript) and triggers exactly the silent failure above. Compare values, not boolean-and chains; pin VALUES, not counts.
- A parse error in one core file (e.g. `sheet_compiler.gd`) cascades as baffling "Nonexistent function in base Nil" errors in unrelated tests. Pinpoint with `--check-only --script <file>`.
- Some tests deliberately lint invalid GDScript; "Parse Error" lines naming fixtures like `1 +` or identifier `this` mid-suite are expected noise.
- A tail segfault AFTER the verdict line is a known harmless teardown flake.

## Standing contracts (violating these breaks user projects)

- **Lossless round-trip**: opening a `.gd` as a sheet and saving untouched reproduces the file byte-identically. Every importer lift is gated by byte-exact re-emission; a lift that cannot reproduce the source must not fire (degrade to a verbatim block, never corrupt).
- **Parity**: generated GDScript is plain code with zero plugin dependency; emission must be deterministic (no timestamps/randomness).
- **Public API freezes**: `ace_id`s, ACE `codegen_template`s, and block `kind_id`s are compatibility promises once shipped. Deprecate, never rename.
- **`{uid}` baking happens at APPLY time in the dock**, never in the compiler.
- **ACEDefinitions are immutable after generation** - they are statically cached and shared across every tab for the session (`ace_registry.gd`). Bake changes into row copies only.
- **Lazy-init flags must only be set by the function that does the full initialization** (a rescan that pre-set `_built_ins_registered` silently lost the built-in block kinds).

## Editor architecture in one paragraph

`EventSheetDock` (`event_sheet_dock.gd`) is the coordinator: tab/view lifecycle, the undo funnel, and a facade of thin delegates into ~40 `dock/*.gd` RefCounted helpers that reach back through a `_dock` reference. `EventSheetViewport` is a custom-drawn virtualized canvas (never per-row Control widgets); rows are `EventRowData` with spans, built by `interaction/viewport_row_builder.gd`. All sheet mutations go through `_perform_undoable_sheet_edit`, whose commit REPLACES resources with snapshot duplicates - never hold a row/resource reference across an edit; re-fetch from the live sheet. Non-ACE row kinds (enums, signals, preloads, regions, pack kinds) dispatch through `EventSheetBlockRegistry` (`docs/GUIDE-CUSTOM-BLOCKS.md`); ACE vocabulary comes from builtin modules plus zero-config provider scripts scanned from `eventsheet_addons/`.

## House rules

- **GDScript style guide is suite-enforced** (`tests/style_guide_test.gd`): tabs, `class_name` before `extends`, two blank lines around functions, snake_case. New files must pass it. Compiler OUTPUT keeps single-blank formatting by design.
- **No em-dashes anywhere in repo text** (docs, changelog, commit messages, code comments, emitted strings). Use " - ".
- **Code never references documentation files** (no "see docs/X.md" in comments); state the point inline.
- **Every feature lands with**: tests (suite green), a `CHANGELOG.md` `[Unreleased]` entry, and for UI features a rendered preview image shown to the user (delete the temp harness before committing).
- Commit conventional-style directly to `main` and push. Do NOT add a `Co-Authored-By` (or any AI-attribution) trailer to commit messages.
- Dialogs/popups build with `EventSheetPopupUI` helpers (`titled_card`, `panel_section`, `form_row`), not raw flat controls.
- New behaviors/addons are authored as pack builders (`tools/pack_builders/*.gd`), not standalone addons.
