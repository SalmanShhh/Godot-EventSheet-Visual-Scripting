# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Godot EventSheets (engine codename EventForge): a Godot 4 `@tool` plugin providing a Construct 3-style event sheet editor that compiles sheets to plain, typed GDScript. `addons/eventforge/` is the data model, compiler, importer, and builtin ACE vocabulary; `addons/eventsheet/` is the editor (dock, virtualized viewport, renderer, picker, themes, MCP server, drop-in CSV translations); `eventsheet_addons/` holds the 95 behavior packs (COMPILER OUTPUT, regenerated from `tools/pack_builders/` - builders auto-register by glob, no list to maintain); `demo/showcase/<name>/` holds the playable showcases (also generated - `tools/build_examples.gd`); `AGENTS.md` has the deeper architecture map and standing contracts.

## Commands

Every command below runs through `$GODOT`, the Godot 4.7 binary. Point it at your own install
first - on Windows use the `_console.exe` variant so stdout reaches the terminal, and note that
the extracted folder is often named like the exe, so the binary sits one level deeper than you
expect:

```
GODOT="/path/to/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64_console.exe"
```

- Full test suite (auto-discovers `tests/*_test.gd` with `static func run() -> bool`):
  `"$GODOT" --headless --path . --script tests/run_tests.gd`
- Fast gate: `"$GODOT" --headless --path . --script tests/run_perf.gd`
- Single test: there is no filter flag; run a scratch SceneTree script that calls `MyTest.run()` then `quit(0)`, or just run the full suite and grep for the test's name.
- Pack drift gate (must print `drifted=0`): `"$GODOT" --headless --path . --script tools/audit_addons.gd`
- Rebuild all packs after touching `tools/pack_builders/`: `"$GODOT" --headless --path . --script tools/build_sample_behaviors.gd` - then `--check-only --script` the emitted pack (the build + drift gates do NOT parse-check output).
- Regenerate showcases after touching `tools/build_examples.gd`: `"$GODOT" --headless --path . --script tools/build_examples.gd` (regen must be byte-stable - verify by hashing the showcase folder across two runs, never with `git stash`).
- Regenerate the vocabulary doc: `"$GODOT" --headless --path . --script tools/vocabulary_doc.gd`
- Project health audit (prints `doctor: N error(s), N warning(s), N note(s)`): `"$GODOT" --headless --path . --script tools/project_doctor.gd`
- Release ritual: bump `sheet_compiler.gd` `VERSION` + `addons/eventforge/plugin.cfg`, regenerate the compiler golden (`tools/regenerate_demo_golden.gd`, writes `tests/fixtures/compiler_golden_sheet_generated.gd`), finalize the CHANGELOG header + `docs/internal/RELEASE-NOTES-vX.md`, refresh README status/milestones + pack counts, delete shipped specs from `docs/internal/`, then commit + annotated tag `vX.Y.Z` + `git push --follow-tags`.
- After adding a `class_name`, regenerate the editor class cache, then revert the churn:
  `"$GODOT" --editor --headless --path . --quit-after 3` followed by `git checkout -- project.godot`
- Editor-UI screenshots are possible: run a `tools/render_*.gd` harness NON-headless (set `root.gui_embed_subwindows = true` for dialogs); headless runs cannot render.
- Runtime smokes for showcases use the same pattern: a temp NON-headless SceneTree harness instantiates the scene, lets physics run N frames, asserts behavior (positions, signals), and screenshots - physics does NOT step in `run_tests.gd` (its `_init` runs before the main loop exists, so `Engine.get_main_loop()` is null there and tests cannot reach a scene tree or physics space).

## Verifying results (the traps that bite here)

- **The suite can fail silently.** A test that crashes or returns non-bool produces ZERO `[FAIL]` lines; always check for the literal `All tests passed.` / `Some tests failed.` verdict line, never just grep for FAIL.
- **A brand-new test file is invisible until the project is imported.** `run_tests.gd` discovers `tests/*_test.gd` through the resource filesystem, so a file added in a fresh worktree (or after a rebase that brought new tests) is skipped without a word until `"$GODOT" --headless --path . --import` has run. A suite that goes green without ever printing your test's name did not run it.
- **Grep the verdict, never the `[FAIL]` lines.** They can be INDENTED (some tests print through a nested reporter, so the line reads `  [FAIL] ...`) - a `grep "^\[FAIL\]"` anchor therefore reports a clean run on a failing suite. They can also appear UNDER a green `All tests passed.`, printed by a probe a test runs deliberately and does not count. The verdict line is the answer in BOTH directions: no `[FAIL]` lines does not mean green, and a `[FAIL]` line does not mean red.
- **`_check(a and b, expected_string)` crashes the comparison** (`bool == String` is a runtime error in GDScript) and triggers exactly the silent failure above. Compare values, not boolean-and chains; pin VALUES, not counts.
- A parse error in one core file (e.g. `sheet_compiler.gd`) cascades as baffling "Nonexistent function in base Nil" errors in unrelated tests. Pinpoint with `--check-only --script <file>`.
- Some tests deliberately lint invalid GDScript; "Parse Error" lines naming fixtures like `1 +` or identifier `this` mid-suite are expected noise.
- A tail segfault AFTER the verdict line is a known harmless teardown flake.
- **`builtin_ace_compile_test` fills each ACE's param DEFAULTS and compiles it inside its host class.** So a default naming something the host lacks (`global_position` on a plain `Node`, `velocity`, a bare `target`) FAILS the gate - correctly, since the default is what the row shows the moment it is dropped. Defaults must stand on their own.
- **A node-scoped ACE's SHIPPED template is not the one you authored.** `_make_node_scoped_targetable` prefixes every line with `{target.}` and appends an "On node" param, so a test asserting the authored string fails. Assert the post-transform form. The prefix is only added when every line is a member operation, which is why a template leading with `not` / `and` / `is` gets no target at all.
- **A builder must pre-bake `{uid}` itself** - the dock bakes it at apply time and the compiler never does, so an unbaked `{uid}` sails straight into the emitted GDScript. Fetch the shipped descriptor and `.replace("{uid}", <stable id>)`.
- **`add_to_group(name)` is NOT persistent.** `PackedScene.pack()` saves persistent groups only, so a group added in a scene builder vanishes from the `.tscn` and every group-based check silently never fires. Pass `true`.
- **The analyzer reads `@ace_*` annotations off DISK** (`script.resource_path`). A `GDScript` built from a `source_code` string in memory has no file, so every annotation silently does nothing - an annotation round-trip test written that way PASSES for the wrong reason. Write a real file (`user://` is fine) and `load()` it.
- **`EventSheetProjectFind.list_project_sheets()` only finds `.tres`**, but `.gd` is the default sheet format. Any Doctor check built on `sheet_paths` therefore skips most real projects while looking like it works. Check emitted output instead when the failure lives in emitted code.

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
- **Never put an absolute path out of anyone's home directory into repo text.** This repo is public: `C:\Users\<who>\...`, `/c/Users/<who>/...`, `/home/<who>/` and `/Users/<who>/` publish an account name and a folder layout, and help nobody but the one machine they came from. Write a placeholder or an env var instead. `tests/personal_paths_test.gd` sweeps every text file and fails the suite on a real one.
- **Code never references documentation files** (no "see docs/X.md" in comments); state the point inline.
- **Every feature lands with**: tests (suite green), a `CHANGELOG.md` `[Unreleased]` entry, and for UI features a rendered preview image shown to the user (delete the temp harness before committing).
- Commit conventional-style directly to `main` and push proactively (split unrelated work into separate commits).
- Dialogs/popups build with `EventSheetPopupUI` helpers (`titled_card`, `panel_section`, `form_row`), not raw flat controls.
- New behaviors/addons are authored as pack builders (`tools/pack_builders/*.gd`), not standalone addons.
