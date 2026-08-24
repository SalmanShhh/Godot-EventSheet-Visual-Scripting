# Building a slice of this plugin

The working notes for one unit of work: a feature, a wave of vocabulary, a fix with a gate behind
it. It is written for whoever picks the next one up. Nothing here is a rule for its own sake; every
line of it is either a command you will need or a trap that has already cost somebody an afternoon.

`CONTRIBUTING.md` is the front door and says what the loop is. This says how to run it without
losing a day, and what the tree does when you are not looking.

---

## 1. The pace

**Iterate on the tests your change can plausibly break. Run the full suite once, before you commit.**

```text
$GODOT --headless --path . --script tools/pick_tests.gd -- run     # seconds; an iteration list
$env:GODOT = "<binary>"; powershell -File tools/run_tests_parallel.ps1   # ~5 minutes; the verdict
```

The picker reads `git status`, maps changed files to tests by name plus a small override table, and
runs them in this process. It errs toward picking too many. It is **never** a verdict: a green
picker run means "the tests most likely to notice this did not notice it", and the suite is what
means the rest.

Do not run the full suite "to be sure". Run it when you are done, and again only if it was red.

The parallel launcher shards the parallel-safe tests and runs the timing and teardown tests serially
afterwards. A test joins that serial tail by DECLARING it (a `*BUDGET_MS*` or `PARALLEL_UNSAFE`
constant in its own source), not by what its file is called.

---

## 2. The gates, in the order they are worth running

```text
$GODOT --headless --path . --import                                   # 0 parse errors; see trap 2
$GODOT --headless --path . --script tools/audit_addons.gd             # must print drifted=0
$GODOT --headless --path . --script tools/build_sample_behaviors.gd   # after touching a pack builder
$GODOT --headless --path . --check-only --script <emitted pack>       # the build gate does NOT parse it
$GODOT --headless --path . --script tools/project_doctor.gd           # repo health
$GODOT --headless --path . --script tools/build_help_bundle.gd        # after touching docs/*.md
$GODOT --headless --path . --script tools/vocabulary_doc.gd           # after adding vocabulary
$GODOT --path . --script tools/render_previews.gd -- out=<dir> all    # NON-headless; the pictures
```

Point `$GODOT` at a Godot 4.7 binary. On Windows use the `_console.exe` variant so stdout reaches
the terminal, and note that the extracted folder is often named like the exe, so the binary sits one
level deeper than you expect. **Never write that path into anything committed** - a sweep fails the
suite on a real user path (`tests/personal_paths_test.gd`).

---

## 3. What already exists (reach for these before writing a third one)

| You need | It is already there |
|---|---|
| A dialog that explains itself | `EventSheetPopupUI.help_strip()`, one per dialog, `follow(field, heading, body)` per field, `set_reading(reads_as, in_code)` at the foot |
| To check a dialog you built | `EventSheetPopupUI.probe_help_dialog(node)` - strips, fields, unwired, follows_focus, both reading lines, no display server needed |
| Dialog chrome | `titled_card`, `panel_section`, `form_row`, `form_box`, `margined`, `code_noted_option`, `autocomplete_combo` |
| The line a row compiles to | `EventSheetCodeEcho` / `EventSheets.row_code_line(row)` - the emitter's own string, never a re-implementation |
| To recognise a hand-written spelling | A TABLE ENTRY in `addons/eventforge/importer/lift_table.gd`, not a new matcher (section 5) |
| A picture of a UI change | A module under `tools/previews/`, rendered by `tools/render_previews.gd` in one boot |
| A new behaviour or pack | A builder in `tools/pack_builders/` (auto-registered by glob), never a standalone addon |
| A non-ACE row kind | The Custom Block API (`registration/block_kind.gd`), see the block guide |
| Anything a pack should be able to do too | `addons/eventsheet/api/eventsheets.gd` - extend it, document it in the API guide, and add a test. Shapes freeze once shipped |

---

## 4. What a slice lands with

1. **Tests.** Compare VALUES, never counts, and never `_check(a and b, "expected")` (see trap 6).
2. **A `CHANGELOG.md` `[Unreleased]` entry**, in the group the change belongs to.
3. **Docs** wherever a guide describes the thing you changed, then the help bundle regenerated.
4. **A preview PNG** for anything visual, saved OUTSIDE the repo, shown to whoever asked for it.
5. **Split conventional commits** straight to `main`. No AI attribution trailers.

---

## 5. Recognisers are table entries

Opening somebody's hand-written GDScript as a sheet means recognising their spelling and writing
their own bytes back when the sheet saves. That is one engine, not one function per family:

```gdscript
static func lift_entries() -> Array[Dictionary]:
	return [{
		"id": "leave_by_closing_the_peer",     # stable; the harness names failures by it
		"ace_id": "LeaveGame",                 # the row this spelling means
		"pattern": "^(?<peer>[A-Za-z_][A-Za-z0-9_]*)\\.close\\(\\)$",
		"params": ["message"],                 # the captures that become row values
		"defaults": {"args": ""},              # values the row has and the line does not say
		"guard": Callable(Family, "_peer_is_declared"),   # optional second opinion
		"shape": "peer.close()",               # the canonical spelling
		"slots": {}                            # what the harness fills it with
	}]
```

Put that static on a script in `addons/eventforge/importer/`. `tests/lift_table_test.gd` finds it by
scanning, GENERATES a fixture line per entry from the shape and the samples, and asserts the byte
round-trip through the real emitter. There is no list to join, and an entry that cannot generate its
own fixture cannot be committed.

The stored spelling is the matched line with each value spliced out for its slot, so substituting
them back is the exact inverse: everything outside a param capture (a receiver prefix, an `&` before
a quoted name, the author's own spacing) rides along verbatim. Keep values OUT of the pattern's
scenery and the byte gate takes care of itself.

What does not belong in a table: a spelling that is several statements only meaning something
together, or one that has to read the scene to know what it is looking at. Those stay hand-written
matchers, and they say so in a comment.

---

## 6. The traps

1. **The suite can fail silently.** A test that crashes or returns a non-bool prints zero `[FAIL]`
   lines. Grep the literal `All tests passed.` / `Some tests failed.` verdict, and grep it in BOTH
   directions: `[FAIL]` lines can be indented (a nested reporter), and they can appear UNDER a green
   verdict (a probe a test runs deliberately). No `[FAIL]` is not a pass; a `[FAIL]` is not a fail.
2. **A brand-new test file is invisible until the project is imported.** Discovery goes through the
   resource filesystem. A suite that goes green without ever printing your test's name did not run
   it. Run `--import` once after adding one.
3. **A new `class_name` does not exist until the editor class cache is regenerated.**
   `$GODOT --editor --headless --path . --quit-after 3`, then put `project.godot` back. In a tree
   another session may be working in, restore it from a COPY you took first, never with
   `git checkout --`.
4. **`compile(sheet, "")` WRITES to the sheet's own `external_source_path`.** A probe pointed at a
   fixture rewrites the repository as a side effect of being tested. Point test sheets at `user://`.
5. **A parse error in one core file cascades** as "Nonexistent function in base Nil" in unrelated
   tests. Pinpoint with `--check-only --script <file>`.
6. **`_check(a and b, expected_string)` crashes the comparison** (`bool == String` is a runtime error)
   and triggers trap 1. Compare values, not boolean-and chains.
7. **A dropdown's every option has to compile, and so does every default on its own.** The built-in
   compile gate fills each param with its DEFAULT and then tries every other item in every list. A
   default naming something the host lacks fails it, correctly: the default is what the row shows the
   moment it is dropped.
8. **A node-scoped ACE's shipped template is not the one you authored** - `_make_node_scoped_targetable`
   prefixes every line with `{target.}` and appends an "On node" param. Assert the post-transform form.
9. **A pack builder must pre-bake `{uid}` itself.** The dock bakes it at apply time and the compiler
   never does, so an unbaked `{uid}` sails straight into the emitted GDScript.
10. **`add_to_group(name)` is not persistent.** `PackedScene.pack()` saves persistent groups only.
    Pass `true`.
11. **The analyzer reads `@ace_*` annotations off DISK.** A `GDScript` built from a source string in
    memory has no file, so every annotation silently does nothing and a round-trip test written that
    way passes for the wrong reason. Write a real file (`user://` is fine) and `load()` it.
12. **Adding a file can turn an unrelated file red.** The dogfood gate samples forty files a day from
    a corpus of ~660 under `addons/` and `tools/`, seeded by the day, so growing OR SHRINKING the
    corpus moves the sample - deleting your own scratch harnesses at the end of a slice is enough to
    swap files in and out of it. Delete them before the run you intend to trust. The failure names
    the file and the seed; fix what it found, or write the cause down beside it in the gate's own
    known-list. Do not add an entry to make a red run green.
13. **A table of literals reads as rows that say nothing.** The same gate measures the share of a
    file's rows with no words of their own, and one line of a list or a dictionary standing alone is
    one of those. A declarative table written out in full is therefore a readability regression in a
    file of statements: eight recogniser entries took one importer file from 6% to 25% against a 12%
    ceiling. Say the regularity once and build the rest (three audiences plus a builder, not six
    entries) - which is the better code anyway, and is what the ceiling is really asking for.
14. **Writing a repo file from a script can turn it CRLF.** The tree is LF everywhere (`.gitattributes`
    enforces it), `git add` normalises the file back so `git status` goes quiet, and meanwhile every
    reader that matches a line exactly (`@tool`, the preload head) sees `@tool\r` and stops
    recognising it. Write files with explicit LF endings.
15. **Per-compile scratch is shared process-wide.** Anything the compiler stores in a static must be
    cleared by every public emission entry point, or a compile in one file changes what an unrelated
    file opens as, minutes later, with nothing naming the cause. `tests/compiler_state_leak_test.gd`
    sweeps for it; if you add a static, that test will tell you to classify it.
16. **Local `const` in a function cannot hold a `PackedStringArray(...)` call** - it is not a constant
    expression. Use `const X: Array[String] = [...]`.
17. **Statics are reached through the SCRIPT OBJECT, not the class name.** `MyClass.get("_x")` is a
    parse error; `(load("res://...gd") as Object).get("_x")` works, and so does `set`. For reflection:
    `get_property_list()` entries with usage `PROPERTY_USAGE_SCRIPT_VARIABLE` are the script's own
    statics, `get_script_constant_map()` holds its consts, and `get_script_method_list()` flags say
    which methods are static.
18. **A shared checkout is shared.** Another session may be committing to `main` while you work.
    Stage explicit paths, never `git add -A`; never `git stash`; never `git checkout --` a file you
    did not edit.
19. **Some tests deliberately lint invalid GDScript.** "Parse Error" lines naming fixtures mid-suite
    are expected noise, and a segfault AFTER the verdict line is a known harmless teardown flake.

20. **A whole picker CATEGORY can be barred from the reverse index.** `ace_lifter.gd`'s
    `REVERSE_LIFT_EXCLUDED_CATEGORIES` names six ("Lighting", "AJAX", "Video", the three 3D pages),
    and a descriptor filed under one of them never claims a line however specific its template is.
    That is a feature - it is what lets a family gate its own lifts on something a template match
    cannot know, like the attached scene saying a node really is a light - but it also means adding
    a row to such a category and expecting hand-written code to open on it will silently do nothing.
    Ask the family's own matcher first (the `EventForge*Lift.match_line` call in
    `_consume_action_line`), and leave the general index to the lines nobody can say more about.

21. **The l10n sweep matches the CALL, not the class.** Any `translate("...")` literal the editor
    reaches needs a row in `TEMPLATE.csv` and a filled cell in all eight locales, in the SAME ORDER
    in every file. One new word in a picker shelf label is one append to nine files; forgetting it
    fails the suite in a place that names the locale, not the feature.

---

## 7. House style, in one place

Tabs. `class_name` before `extends`. Two blank lines around functions. snake_case. Real `##` comments
on anything public, saying WHY rather than what. No em-dashes anywhere in repo text (write " - ").
Never name the other event-sheet editor in code, identifiers, UI strings, translations or test labels
(prose in docs may). Code never points at a documentation file; state the point inline. Compiler
OUTPUT keeps its own single-blank formatting by design.

And the one that is easy to forget while adding something: **the codebase should read as though it
were always this size.** Prefer one shared helper to three near-copies, delete the branch you
replace, fold special cases into data tables, and say in the commit what you removed.
