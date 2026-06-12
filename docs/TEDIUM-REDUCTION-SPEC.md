# Tedium Reduction — Tier 2 & 3 (spec)

Status: **in progress** — each item flips to *Delivered* as its slice ships; the
table is the truth.

The Tier 1 items (add-another chaining, per-ACE value memory, apply-with-defaults)
are **out of scope here** — this spec covers the accepted Tier 2 (repetition
killers) and Tier 3 (loop closers). Shared constraints, per the project's standing
contracts:

- **Compatibility covenant**: nothing here changes emitted bytes, ace_ids, or
  template baking. Refactors rewrite *sheet model text*, never generated output
  conventions.
- **Perf budget**: no per-row Controls; canvas work stays inside the virtualized
  renderer/hit-test paths.
- Every feature ships with a headless-testable core; editor-only affordances
  (EditorInterface) are thin wrappers around it.
- Settings use the established namespaces (`eventsheets/editor/*` for workflow,
  `eventsheets/project/*` for committed conventions).

| # | Item | Tier | Status |
|---|---|---|---|
| 5 | True Rename (variables + functions) | 2 | ✅ Delivered |
| 6 | Create-variable quick-fix in expression fields | 2 | ✅ Delivered |
| 4 | Row snippets (project-local) | 2 | 🗺 Planned |
| 7 | Bulk operations on multi-select | 2 | 🗺 Planned |
| 8 | Session restore (tabs) | 3 | 🗺 Planned |
| 9 | Asset drops on the canvas with intent | 3 | 🗺 Planned |
| 10 | Attach behavior to selected node | 3 | 🗺 Planned |
| 11 | Run-from-sheet | 3 | 🗺 Planned |

---

## 5. True Rename (variables + functions)

**Problem.** Renaming `hp` today means Find/Replace and hoping nothing named
`hp_max` gets clipped, then repeating it in every sheet that includes this one.

**Design.** Core in `EventSheetRefactor.rename_symbol(sheet, old_name, new_name)
-> int` (match count) — a *word-boundary* (`\bold\b`) rewrite over every surface a
symbol can appear in: the `variables` key itself (or the function's
`function_name`), ACE param values, raw-code rows (row- and ACE-level), pick
filters, trigger args, other variables' attribute strings (`show_if` etc.), and
function bodies. Comments are deliberately *included* (a rename should keep prose
honest — the opposite trade from usage detection).

**UI.** Variable context menu: **Rename Everywhere…** (functions rename through
the same core; a function-row menu entry can join when function rows grow
context entries) → name dialog prefilled with the old name. Validation: new name
must be a valid identifier and collide with no existing variable/function;
refusal is a status line, never a silent no-op.

**Includers.** After the open sheet, every project sheet whose `includes` lists
this sheet gets the same rename and is saved directly (Replace-in-Project
precedent: closed sheets save, the status names every touched file).

**Undo.** The open sheet's rename rides `_perform_undoable_sheet_edit` (one
whole-sheet snapshot action); includer saves are not undoable (named in status
instead).

**Tests.** Word-boundary safety (`hp` doesn't touch `hp_max`), key rename,
function rename updates call params, includer rewrite, collision refusal.

## 6. Create-variable quick-fix

**Problem.** Typing a not-yet-declared variable in an expression field flags red;
fixing it means cancel → Add Global Var → retype → reopen → retype.

**Design.** When an expression field fails lint and the expression holds a plain
identifier the sheet context can't account for (the engine never exposes parse-error
text to scripts, so the culprit is derived from the expression itself — skipping
literals, member accesses, calls, keywords, sheet symbols, host members, classes
and singletons), the field grows a one-click
**“+ var”** affordance: creates the variable on the sheet (type guessed `float` —
the C3 "number" default — editable later in the variables row), re-lints, clears
the red. The dialog stays dock-agnostic: the dock injects a creator callback
(`set_variable_creator(Callable)`), mirroring `set_lint_context_provider`.

**Tests.** Unknown-identifier derivation (declared vars, calls, literals, member
accesses all accounted for); creator declares a float exactly once; end-to-end:
failing field grows the button, clicking creates the variable and the field
re-lints clean.

## 4. Row snippets (project-local)

**Problem.** Every-X-seconds-spawn, fade-and-free, knockback — rebuilt by hand in
every sheet that needs them.

**Design.** The existing shareable **text-snippet format is the file format**
(one serializer, no new dialect). `EventSheetSnippets` (eventforge):
`snippets_dir()` (`eventsheets/project/snippets_dir`, default
`res://eventsheet_snippets`), `list_snippets()` (sorted `.txt` files),
`save_snippet(name, text) -> path` (suffix `-2/-3`, never overwrites —
templates rule), `read_snippet(path)`. Insert goes through the **existing paste
path**, so fresh event uids re-bake exactly like a paste (the stateful-accumulator
lesson is inherited, not re-implemented).

**UI.** Row context menu: **Save Selection as Snippet…** (name dialog) on any
selection; **Insert Snippet ▸** submenu (rescanned per open, templates-style) on
the canvas menu. Files are committed → snippets are team-shared by git, same as
templates and packs.

**Tests.** Save→file content equals the copy-as-text form; insert→rows appended
with re-baked uids; suffix-on-collision; menu listing.

## 7. Bulk operations on multi-select

**Problem.** The viewport already supports multi-row selection
(`_selected_row_uids`), but the context menu only acts on the clicked row.

**Design.** When the selection holds >1 row, the row context menu gains a
**“Selection (N rows)”** section: **Disable/Enable**, **Duplicate**, **Delete**,
**Group into New Group**. Disable/enable/duplicate/delete act on every selected
row wherever it lives; group-into-group requires a same-parent selection (refused
with a status line otherwise — silent reparenting across depths is how sheets get
scrambled). All wrapped in **one** undo action.

**Tests.** Each op across a 3-row selection; mixed-parent group refusal; single
undo restores all.

## 8. Session restore (tabs)

**Problem.** Every editor launch starts with re-opening every sheet by hand.

**Design.** `user://eventsheets_session.cfg` (ConfigFile) holds the open tab
paths + active index; written on tab open/close/switch, restored on dock startup
when `eventsheets/editor/restore_session` (default true) and the editor is
running. Unsaved sheets (no path) are skipped at write; missing files are skipped
at restore. user:// is per-project, so sessions never leak across projects.

**Tests.** Persist/restore round-trip via the statics; missing-file resilience;
the setting gates restore.

## 9. Asset drops on the canvas with intent

**Problem.** “Spawn that scene / play that sound” starts with two dialogs even
though the FileSystem dock is right there holding the asset.

**Design.** The viewport accepts FileSystem `files` drops **onto an event row**:
`.tscn/.scn` → a pre-filled **Spawn Scene At** action, audio (`.ogg/.wav/.mp3`)
→ a pre-filled **Play Sound** action, appended to that event through the normal
(undoable) apply path with the descriptor's template baked as usual. Drops on
empty canvas set a status hint (“drop onto an event row”) — creating implicit
events would guess intent. Other extensions are ignored. This is the C3
drag-into-layout reflex, grafted onto events.

**Tests.** Drop payload → correct ace_id + quoted path param per extension;
non-asset extensions ignored; empty-space drop hints.

## 10. Attach behavior to selected node

**Problem.** After authoring a behavior the loop is: save, find the scene, add a
Node child, attach the script — four manual steps the Doctor then nags about.

**Design.** Core `EventSheetAuthorLoop.attach_behavior(sheet, host) -> String`
(“” or problem): ensures the sheet is saved+compiled, adds a child Node named
after the sheet's class with the generated script, sets owner for serialization.
Host-class mismatch **warns but attaches** (`_get_configuration_warnings`
already surfaces it in-scene — blocking would just re-route through the same
manual steps). Editor wrapper: Tools → **Attach to Selected Node** reads the
scene-dock selection and marks the scene modified.

**Tests.** Child created, script + name right, owner set; mismatch warning text;
non-behavior sheets refused.

## 11. Run-from-sheet

**Problem.** Sheet → playing the game requires remembering which scene uses it.

**Design.** The Doctor's reverse scene lookup becomes a shared static
(`scenes_attaching(script_path)`); **Run Scene** (toolbar) saves the sheet
(compile-on-save keeps the script fresh), then: one attaching scene →
`EditorInterface.play_custom_scene`; several → a pick menu; none → status hint
(behaviors are pointed at the Test Bench instead). Headless core = the lookup;
playing is editor-only.

**Tests.** Lookup finds the showcase pairing; multi/none branches return the
right shape.
