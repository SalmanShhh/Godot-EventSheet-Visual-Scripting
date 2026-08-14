# SPEC: In-Editor Documentation Viewer

Documentation the user reads **inside the Godot editor**, the way the Script editor's class Help
works, but drawn in this project's own visual language: two-lane event rows with an object
sub-column, a badge column, orange object labels, green values, card panels. Not a wall of plain
text, and not a Markdown dump.

> **Revision note (post-review).** This spec has been through two adversarial reviews. Twenty-one
> findings were raised; eighteen held up under re-verification, two were partly wrong in the
> reviewer's favour (the link-gate count is worse than reported, section 3.6), and one was
> out-of-band repo hygiene (appendix B). Everything the reviews disproved has been corrected in
> place rather than footnoted. **Read section 0 first** - it is the yes/no page, and it now
> recommends something smaller than the original plan.

---

## 0. The decision page

### 0.1 What this actually is, honestly

The feature is two independent things that the first draft bundled into one plan:

| Half | What it is | Depends on the other half? |
|------|-----------|----------------------------|
| **A. Live figures** | The real `EventSheetViewport` rendering a real `EventSheetResource` as an inline illustration, with an Insert button. Genuinely novel; nothing else in the Godot ecosystem does it. | **No.** Needs no corpus, no Markdown, no parser, no bundle. |
| **B. A native Markdown reader** | Parse the shipped guides and draw them as Controls: a second, worse browser that renders no images and no real tables, for a corpus that has to be duplicated into `addons/` to exist at all. | **No.** Needs no figures. |

The first draft's headline justification - "the docs corpus does not ship" - is real (verified in
section 1.3), but it is a *shipping* bug with a one-line fix that the draft never evaluated:
`OS.shell_open` to a version-pinned GitHub URL. The repo already does exactly this pattern
(`event_sheet_dock.gd:2701` `ISSUES_URL`, used at :2734). Half B exists to avoid opening a browser
tab. That is a much thinner benefit than the draft implied, and it carries the plan's entire cost.

### 0.2 The costs, sized

| Cost | Measured |
|------|----------|
| **Maintenance, permanent** | 394 of 1,315 commits in this repo touch `docs/*.md`. **30% of all commits** would additionally have to regenerate and commit `addons/eventsheet/help/`, and the CLAUDE.md release ritual gains a regeneration step. |
| **Payload** | +753 KB of duplicated Markdown in `addons/`, about +11% on 6.5 MB. |
| **New code** | 8 new runtime classes, 1 build tool, 6 new test files, one renderer seam. |
| **New frozen public surface** | `EventSheets.open_docs`, the doc id scheme, the ` ```eventsheet ` fence grammar, the `[eventsheet-help v1]` manifest header. Four new compatibility promises. |
| **Doc-edit friction** | Once a guide carries a gated fence, breaking the GDScript inside it breaks the suite. |
| **Fidelity loss vs a browser** | No images (5 MB, excluded), no syntax highlighting, tables must be hand-built, search hand-rolled, anchors hand-rolled. |

The precedent the draft invoked for the duplication - the 76 generated packs held honest by
`tools/audit_addons.gd` - **does not transfer**. Packs are compiler output nobody hand-edits.
`docs/*.md` is the most-touched authored surface in the repo.

### 0.3 The recommended cheapest useful version

**Ship Phase 1 + Phase 2 + Phase L (link fix). Stop there. Re-decide Phases 3-6 afterwards with the
figure widget in hand.**

| Step | Work | What the user gets |
|------|------|--------------------|
| **Phase L - link fix** | ~20 lines: a `EventSheets.open_online_doc(path)` helper doing `OS.shell_open("https://github.com/<repo>/blob/v<VERSION>/docs/<path>")`, repoint `welcome_window.gd:160`, and a `sed` in `release.yml` staging that rewrites `README.md`'s 29 relative `docs/` links to absolute tag URLs. | **The shipped-broken-docs bug is fixed**, for the migration button *and* the ~29 README links that the draft missed. Zero bytes shipped, zero drift surface, images and tables render correctly. |
| **Phase 1 - the figure widget** | The renderer seam + `EventSheetDocFigure`, shipped inside the ACE picker's info panel. | A live, themed, insertable row illustration of the selected verb - the genuinely new thing. |
| **Phase 2 - "explain this row"** | The panel, from the live registry. Zero Markdown. | A persistent, navigable reference surface for any row, with a worked figure and an Insert button. |

That is roughly a third of the original scope, carries **no** duplicated corpus, **no** drift gate,
**no** Markdown parser, and **none** of the 30%-of-commits tax. It keeps every part of the plan that
is not reproducible by a browser tab.

**Phases 3-6 are specified in full below and remain a coherent plan.** They are worth doing if and
only if the answer to this question is yes:

> *What does a reader learn from a native Markdown page that they do not learn from a browser tab
> opened on the same guide - enough to justify duplicating the most-edited surface in the repo?*

The honest candidate answers, stated so the user can weigh them rather than have them assumed away:

1. **Live figures inside guides** (Phase 4). A guide that renders real, insertable rows in the
   reader's own theme is something GitHub cannot do. This is the only answer that is *not*
   reproducible in a browser, and it is the strongest case for Phase 3 - Phase 4 needs Phase 3's
   parser to exist. Note the qualifier though: section 4.7 shows Phase 4 can light up 162 existing
   fences automatically, which raises its value considerably relative to the draft's 20 hand-picked
   ones.
2. **No context switch.** Reading beside the sheet instead of alt-tabbing. Real but modest, and the
   Phase 6 dock (which is what actually delivers "beside the sheet") has a width problem, section 3.2.
3. **Offline.** Genuine for users without connectivity. Unquantified.

If the answer is "1 is worth it", build 3+4 and consider 5/6 optional. If the answer is "2 and 3
only", **do not build Phase 3** - `OS.shell_open` already delivers those readers a better page.

### 0.4 What could go wrong

- The bundle drifts and nobody notices because the gate lives in `tools/` (not CI). Mitigated in
  section 7 by mandating the byte-identity check live in `tests/`.
- The Phase 6 dock is unusable because figures force a 640 px minimum width (section 3.2).
- The 30%-of-commits regeneration tax gets skipped under time pressure, and the shipped docs quietly
  fall behind the repo docs - reproducing, in a new form, exactly the bug this feature was justified
  by.
- Anchors ship broken and the suite stays green, because the naive test pins the slug string and
  never the jump (section 3.7).

---

## The one-sentence contract

**A doc page is native Godot Controls, and a doc FIGURE is the real `EventSheetViewport` rendering a
real `EventSheetResource` - so a figure can never disagree with the editor, carries an Insert button
that no static picture can, and is drawn in a deliberately chosen palette (section 3.9).**

---

## 1. Is it possible

**Yes, and the interesting half is already built. The mockups themselves are not displayable, and
that is the one thing this design has to work around.**

### 1.1 What is NOT possible, verified

Probed against the exact binary in use, `Godot Engine v4.7.stable.official.5b4e0cb0f`, by walking
`ClassDB` in a throwaway headless project:

| Probe | Result |
|-------|--------|
| `ClassDB.class_exists("WebView")` | `false` |
| `ClassDB.class_exists("HTMLLabel")` | `false` |
| `ClassDB.class_exists("MarkdownLabel")` | `false` |
| every class name containing `html` / `webview` / `browser` / `markdown` | `[]` (empty) |
| `ClassDB.class_exists("EditorHelp")` / `("EditorHelpBit")` | `false` / `false` |

So: **there is no HTML renderer, no WebView, and no Markdown control** available to a GDScript
plugin, and the editor's own class-Help renderer is internal C++ that is absent from `ClassDB`, so
it cannot be embedded, subclassed, or re-skinned either. The HTML design mockups cannot be
displayed. They stay what they are: a design language written down at
`docs/internal/skills/suggest-new-eventsheet-vocabulary.md`, rendered to a scratchpad and never
committed.

**Rejected alternative: a GDExtension embedding a browser.** It would mean shipping per-platform
native binaries, which breaks the documented install (`README.md:61`: copy `addons/eventforge/` and
`addons/eventsheet/`) and the zero-runtime-dependency covenant. The cost is out of all proportion to
"show a doc page".

**What that costs the design:** every page element must be rebuilt from Controls. Concretely, three
pieces, all of which already exist in this repo:

1. **Prose** - `RichTextLabel` with BBCode. Verified present in 4.7: `push_table`, `push_cell`,
   `push_bold`, `push_italics`, `push_mono`, `push_color`, `push_bgcolor`, `push_indent`,
   `push_list`, `push_meta` (clickable links via `meta_clicked`), `push_hint`, `add_image`,
   `push_font_size`, `push_paragraph`, `push_dropcap`, `push_customfx`.
   It has **no `find()`** (`ClassDB.class_has_method("RichTextLabel", "find")` is `false`), no
   anchor concept, no syntax highlighting, and `[codeblock]` is a docs-tool tag that renders
   literally. Search is hand-built; **anchors are hand-built on Control positions, not on
   `scroll_to_paragraph` - see section 3.7, this was wrong in the first draft.**
2. **Card chrome** - `EventSheetPopupUI` (`addons/eventsheet/editor/popup_ui.gd`):
   `titled_card` (:139), `panel_section` (:109), `section_header` (:121), `form_row` (:42),
   `form_box` (:71), `margined` (:79), `hint_label` (:92), `inset_panel_stylebox` (:151).
3. **Figures** - the real renderer, see below.

### 1.2 What IS possible, verified by running it

**The event-sheet renderer runs standalone.** `EventSheetViewport`
(`addons/eventsheet/editor/event_sheet_viewport.gd:2`, `@tool class_name EventSheetViewport extends
Control`) needs no dock, no plugin, and no registry. The shipped precedent is the Theme Editor's live
preview (`addons/eventsheet/editor/theme_editor_dialog.gd:285-291`): a bare `ScrollContainer`, an
`EventSheetViewport.new()` as its child, then `set_sheet(...)`. About 40 suite tests do the same
(`tests/hit_test_test.gd:18-27`, `tests/footer_rows_test.gd`, `tests/custom_block_test.gd`).

I reproduced the whole figure stack headless inside this project:

```
lifted=true
events=4
row kinds=["raw_code_row.gd", "local_variable.gd", "event_row.gd", "event_row.gd"]
round_trips=true
custom_min=(760.0, 419.0)   total_height=419.0
mockup_theme_loaded=true    object_label_color=(0.8471, 0.6392, 0.3529)   # = #d8a35a
```

That is: a plain-GDScript string lifted to a real sheet, re-emitted byte-identically, rendered by
the real viewport, and repainted in the mockups' own palette.

**The mockup palette already exists as a shipped resource.** `demo/themes/mockup_slate_theme.tres`
carries the mockups' tokens verbatim: `object_label_color = Color(0.847059, 0.639216, 0.352941)` =
`#d8a35a` (:59) and `value_highlight_color = Color(0.623529, 0.831373, 0.478431)` = `#9fd47a` (:60).
Applying it to a standalone figure viewport via `apply_editor_style()` works with no errors.

**Placement is available.** Verified in 4.7:

- `EditorPlugin.add_dock` / `remove_dock` exist, and `EditorDock` is a real class extending
  `MarginContainer` with `title`, `layout_key`, `default_slot`, `available_layouts`, `closable`,
  `open()`, `close()`, `make_visible()`, and `_save_layout_to_config` / `_load_layout_from_config`
  virtuals. `EditorDock.DockLayout` is `VERTICAL=1, HORIZONTAL=2, FLOATING=4, ALL=7`.
  **`add_dock` takes an instance, not a factory** - probed signature `add_dock(dock: EditorDock)`.
  That has a boot consequence, section 5 Phase 6.
- Two enums exist and are **not** the same, which is easy to get wrong:
  `EditorPlugin.DockSlot` runs `NONE=-1 .. RIGHT_BR=7, BOTTOM=8, MAX=9`, while
  `EditorDock.DockSlot` runs `NONE=-1 .. RIGHT_BR=7, BOTTOM=8, BOTTOM_L=9, BOTTOM_R=10, MAX=11`.
  Use `EditorDock.DOCK_SLOT_*` when configuring an `EditorDock`.
- `ScriptEditor.goto_help`, `update_docs_from_script` and `clear_docs_from_script` all exist, so the
  plugin's public classes can be injected into the built-in Help. That renders in the engine's
  class-reference shape with zero visual control and cannot show event-sheet rows, so it is a cheap
  complement, never the plan.
- `EditorInterface` has `get_editor_theme()`, `get_editor_scale()`, `get_command_palette()`,
  `set_main_screen_editor()`, and the `popup_dialog_*` family.

**A second main-screen tab is not possible at runtime.** `_has_main_screen` / `_get_plugin_name` /
`_get_plugin_icon` / `_make_visible` are per-`EditorPlugin` (`addons/eventforge/plugin.gd:58-84`) and
`EditorInterface` exposes no way to register another plugin. A second main screen means a second
`addons/<name>/plugin.cfg` the user enables separately. Rejected.

### 1.3 The shipping bug, and the cheap fix the first draft skipped

**The docs corpus does not ship.** Verified three ways:

- `find addons -name "*.md"` returns **zero files**.
- `.github/workflows/release.yml:66-77` stages `addons/` + `README.md` + `LICENSE` + `CHANGELOG.md`
  into the plugin zip. `docs/` is never copied. `demo/` and `eventsheet_addons/` go into the separate
  samples zip, so `demo/themes/mockup_slate_theme.tres` does not ship with the plugin either. Note
  also that `docs/Addons/` ships in **neither** zip, so pack users have no pack guides.
- `README.md:61` documents the install as copying two `addons/` folders.

The symptom is larger than the first draft reported. It found one hit
(`addons/eventsheet/editor/dock/welcome_window.gd:159-160`, "Open the migration guide" wired to
`OS.shell_open(ProjectSettings.globalize_path("res://docs/GUIDE-C3-MIGRATION.md"))`) and asserted
that was the only one. **True only within `addons/`.** The plugin zip also ships `README.md`
verbatim, and it carries **29 distinct relative `docs/...` links**, every one of them dead in an
installed project: `docs/GUIDE-UNINSTALL.md`, `docs/README.md`, `docs/GUIDE-C3-MIGRATION.md`,
`docs/Addons/README.md` and 25 more.

**Rejected in the first draft only by omission: `OS.shell_open` to a version-pinned URL.** It was
mentioned twice as an escape hatch and never evaluated as the primary answer. It should have been.

```gdscript
## Opens a repo guide in the reader's browser, pinned to the released tag so the page always
## matches the installed plugin. The corpus never has to ship.
static func open_online_doc(relative_path: String, anchor: String = "") -> bool
```

| | `OS.shell_open` to a tag URL | Native Markdown viewer (Phase 3) |
|---|---|---|
| Fixes the shipped bug | Yes, all 30 hits | Yes, one hit; the 29 README links still need the same rewrite |
| Bytes shipped | 0 | +753 KB |
| Drift surface | none | the second copy, on 30% of commits |
| Images | render | excluded (5 MB) |
| Tables | render | hand-built with `push_table` |
| Syntax highlighting | yes | none available |
| Search | GitHub's | hand-rolled |
| Offline | no | yes |
| Live insertable figures | **no** | **yes (Phase 4)** |
| Precedent in repo | `event_sheet_dock.gd:2701/2734` | none |

The last row is the whole argument for Phase 3. Everything above it favours the browser.

Corpus measured on disk today: 39 top-level guides (753,613 bytes, `ls docs/*.md` including
`docs/README.md`), 72 addon guides (1,535,575 bytes), `EVENTSHEETS-VOCABULARY.md` (170,216 bytes),
`docs/images/` 80 PNGs (5,036,228 bytes), `docs/previews/` 8 PNGs. `addons/` is about 6.5 MB.

---

## 2. What the user gets

### 2.1 Where it lives

| Surface | Phase | Why |
|---------|-------|-----|
| **Tools > Documentation...** window | 2 | The repo's proven dialog idiom. Welcome, Tour, Shortcuts, Project Doctor, Find in Project are all windows built with `EventSheetPopupUI`. Cheapest first home. |
| **F1** on the sheet canvas | 2 | `grep KEY_F1 addons/` returns nothing today. F1 is free and is the universal help key. |
| **Row context menu: "What does this do?"** | 2 | Through the already-public `EventSheets.register_row_menu_item` (`api/eventsheets.gd:926`, consumed at `dock/context_menus.gd:245-249`), so the dock is not edited and the extension seam gets dogfooded. |
| **`EditorDock`** ("EventSheets Help") | 6 | Persists in the editor layout via `layout_key`; a bare Window does not. **Conditional on the width problem in section 3.2 being solved** - `DOCK_SLOT_RIGHT_UL` is nowhere near 640 px wide. |
| **Command palette `?` prefix** | 5 | `dock/command_palette.gd` already has `#` (open sheet) and `@` (jump to symbol). `?` becomes "search the docs". |
| **Welcome card + the broken migration button** | L | Repointed at `EventSheets.open_online_doc` in Phase L, and optionally re-repointed at the native viewer in Phase 3. |

**Rejected: the bottom panel.** `add_control_to_bottom_panel` exists, but short-and-wide is the wrong
shape for prose. **Rejected: a bare `Window` as the permanent home** - it is not part of the editor
layout, so it would have to persist its own geometry forever. **Rejected: making the viewer a second
main-screen tab** - impossible without a second `plugin.cfg`.

The content control (`EventSheetDocBrowser`) is host-agnostic from day one: the same `Control` is
parented by the Phase 2 Window and the Phase 6 dock.

### 2.2 How it opens

One public entry point, frozen on ship like every other `EventSheets` method:

```gdscript
EventSheets.open_docs(doc_id: String = "", anchor: String = "") -> bool
```

`doc_id` is a stable id derived from the file stem (`"GUIDE-RECIPES"`, `"Addons/Quest"`), `anchor` is
a GitHub-style heading slug. Empty `doc_id` opens the index. Everything else - the Tools item, F1,
the row menu, the palette, the Welcome buttons - is a caller.

**House-rule ruling required, and made here.** CLAUDE.md states unconditionally: *"Code never
references documentation files (no 'see docs/X.md' in comments); state the point inline."* This
design hardwires doc ids into code (`welcome_window.gd`, the row menu, the palette `?` mode). The
rule targets **explanatory cross-references in comments**, which rot silently and make a reader hop
files. **Navigation code that opens a doc is an explicit, tested exception**, on one condition: the
reference must be *gated*, not trusted. See section 7 - `tests/doc_library_test.gd` must sweep
`addons/` for `open_docs("...")` / `open_online_doc("...")` string literals and assert each id
resolves. Without that gate, a guide rename reproduces the exact
`res://docs/GUIDE-C3-MIGRATION.md` failure in a new costume.

### 2.3 What a page looks like

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [search…………………………]                     Working with Lists (Arrays)          │
├──────────────┬───────────────────────────────────────────────────────────────┤
│ Learn by     │  ══ Working with Lists (Arrays) ══════════════════ (doc_title) │
│  doing       │                                                                │
│  ▸ Recipes   │  Lists are how a sheet holds more than one of something.       │
│  ▸ Common…   │  (doc font, the reader's text_editor/help/help_font_size)      │
│  ▸ Lists  ◀  │                                                                │
│  ▸ Text      │  ┌─ FIGURE ────────────────────────────────────────────────┐   │
│ The Studios  │  │ 1 │➜│ On Ready          │ Inventory | List: Append  ✦   │   │
│  ▸ ACE Studio│  │ 2 │ │ List: Is Empty    │ HUD | Text: Set Text  "None"  │   │
│ Extend       │  └──────────────────────────────────────── [Insert] [Copy] ┘   │
│  ▸ Custom…   │  The rows above are the real renderer.                         │
│ Patterns     │                                                                │
│ Addons       │  ┌─ TABLE (a card, not raw text) ───────────────────────────┐  │
│  ▸ Quest     │  │ Verb          │ Ships as                                 │  │
│  ▸ Weapon Kit│  │ Append        │ arr.append(value)                        │  │
└──────────────┴───────────────────────────────────────────────────────────────┘
```

Concretely, per block kind:

- **Headings** - `EventSheetPopupUI.section_header` for H2/H3; the H1 uses the editor's own
  documentation typography. The editor theme exposes `doc`, `doc_bold`, `doc_italic`, `doc_title`,
  `doc_source` fonts under `EditorFonts`, and the reader's own sizes live in EditorSettings
  (`text_editor/help/help_font_size`, `help_title_font_size`, `help_source_font_size`), so the page
  reads like the built-in class Help by construction rather than by imitation.
- **Prose, lists, bold, inline code, links** - one `RichTextLabel` per contiguous run.
  `selection_enabled` and `context_menu_enabled` both default **false** and must be turned on
  (verified); `shortcut_keys_enabled` defaults true, so Ctrl+C follows for free. **`bbcode_enabled`
  and `fit_content` also both default `false`** and must both be turned on - see the sizing trap in
  section 3.8, which this repo has already been bitten by once.
- **Tables** - a card (`panel_section`) containing a `RichTextLabel` built imperatively with
  `push_table()` / `push_cell()`. **Trap, verified with engine errors:**
  `set_table_column_expand` / `set_cell_padding` / `set_cell_border_color` /
  `set_cell_row_background_color` are push-stack operations. Called after `append_text()` has
  finished parsing they error (`Condition "current->type != ITEM_TABLE" is true`,
  `rich_text_label.cpp:5171`) and silently do nothing. Build tables imperatively, or use the inline
  `[cell bg=… padding=… border=… expand=…]` options which do work.
- **Code fences** - a monospace card, colored by the page emitter. There is no syntax highlighter
  for `RichTextLabel`; `CodeEdit` + `CodeHighlighter` is the only built-in one and the repo already
  configures it at `EventSheetPopupUI.configure_code_editor` (`popup_ui.gd:26`), which is the escape
  hatch if colored code becomes a requirement.
- **Figures** - see section 4.
- **Images** - not shipped in v1 (see the payload decision). An image block renders as a caption card
  showing its alt text with an "Open online" affordance. This repo's alt text is unusually
  descriptive, so the degrade is honest rather than a hole. 31 image links exist across the 39
  shipped guides.

### 2.4 How figures behave

A figure is an `EventSheetDocFigure` control: a caption, a **figure-mode** `EventSheetViewport`
sized to its rows, and two buttons.

- **Insert into my sheet** - serializes the figure's rows through
  `EventSheetSnippet.serialize_rows(rows, sheet)` (`editor/event_sheet_snippet.gd:31`) and hands the
  resulting **text** to a new public API method (see below). That path runs the undo funnel
  (`_dock._perform_undoable_sheet_edit`), creates any `required_variables` the figure needs, assigns
  fresh event uids, and sets the status line. One undo step.
- **Copy** - the same snippet text to the clipboard, so a figure is shareable outside the editor.

**Corrected from the first draft: do not call `clipboard.gd paste_snippet` directly.** Verified:
`_paste_snippet_text` (`dock/clipboard.gd:214-220`) calls `_dock._ensure_sheet_for_editing()`
(`event_sheet_dock.gd:1304-1308`) **before** `paste_snippet`; `paste_snippet` (:229) itself has no
such guard and dereferences `_dock._current_sheet` inside its undo lambda. "Disabled when no sheet is
open" is a UI-state check, not a guard - a docs window that outlives a tab close hits the unguarded
path. There is also no public route: `EventSheets` has no insert/paste method, and
`_paste_snippet_text` is private (`event_sheet_dock.gd:1291`), so a Window-hosted browser would have
to reach through the private static `EventSheets._dock` (`api/eventsheets.gd:1514`) while the same
spec makes a point of dogfooding the public `register_row_menu_item` seam.

Per the standing rule *"extend the Custom Block / EventSheets API whenever it eases any feature"*,
Phase 1 adds and freezes:

```gdscript
## Inserts snippet TEXT (see EventSheetSnippet) below the selection as ONE undo step, creating any
## sheet variables it needs. Returns false when no sheet is open or the text is not a snippet.
static func insert_snippet(text: String, label: String = "Insert Snippet") -> bool
```

which delegates to `_dock._paste_snippet_text(text)` - the already-guarded, already-deserializing
path - so no second insertion route is created.

**Never hold a row or resource reference across the insert.** `EventSheets.edit(label, mutation)`
(`api/eventsheets.gd:203`) commits by replacing resources with snapshot duplicates; re-fetch from
`EventSheets.current_sheet()` inside the mutation. The snippet path already obeys this.

### 2.5 How search works

`RichTextLabel` has no `find()`, so search is built:

- **Index** - built once per session from the shipped bundle: per page, the title, every heading with
  its slug, and a lowercase word set. A full-corpus heading and word pass over all 111 files measured
  40 ms headless, so this is free.
- **Ranking** - the same shape the command palette already uses in `dock/command_palette.gd`
  (`_command_match_score`, :85): prefix beats substring beats subsequence. Title and heading hits
  outrank body hits.
- **Results** - a `Tree`, grouped by page, each row naming its heading; activating one calls
  `EventSheets.open_docs(doc_id, anchor)`.
- **In-page jump** - **see section 3.7. The first draft's mechanism was wrong and would have shipped
  broken while the suite stayed green.**
- **Highlighting** - a match is highlighted by re-emitting the page with `[bgcolor]` around hits.
  There is no post-hoc highlight API.

### 2.6 Context-sensitive "explain this row"

Right-click a row (or press F1 with a row selected) and the viewer opens on a generated page for that
exact ACE or verb. **Zero Markdown is involved** - the content is derived live:

| Piece | Source | Status |
|-------|--------|--------|
| Name, type, category, description, "ships as" | `ACEDefinition` (`ace/ace_definition.gd:11-20`), composed exactly as the picker does at `ace_picker.gd:1818-1840` | exists |
| Deprecation note, param blurbs, async/static/featured markers | `interaction/viewport_tooltip_helper.gd`: `ace_description` (:89), `verb_definition_tooltip` (:136), `codegen_preview_for` (:188) | exists |
| The section blurb | `EventSheetSectionInfo.description_for(name)` (`ace/section_info.gd:26`), keyed by the exact section header string | exists |
| A worked figure | one row built from the definition's parameter defaults, rendered by `EventSheetDocFigure` | Phase 1 |
| Pack-level "read more" | the `@ace_help` annotation | **does NOT exist as a read path - see below** |

**Corrected from the first draft.** `addon_help_url` (`addons/eventforge/resources/event_sheet.gd:83`,
documented at :77-83) is declared as a **URL** (`## @ace_help("https://...")`), not a doc id, and grep
finds **zero editor consumers**: the compiler emits it (`sheet_compiler.gd:155-156`), the importer
lifts it (`gdscript_importer.gd:222-225`), `semantic_analyzer.gd:40` whitelists the annotation, and
nothing reads it back for display. The Phase 2 executor must therefore build the read-more affordance
*and* settle URL-versus-doc-id resolution (recommendation: treat `http(s)://` as `OS.shell_open`, and
any other value as a doc id). Budget it; it is not free.

**What Phase 2 gives a reader that the picker and the row tooltip do not.** The reviews are right
that most of the data above is already drawn twice - by the picker info panel
(`ace_picker.gd:1818-1840`: name / type / category, description, muted "-> ships as", reactive-tip)
and by row hover (`ViewportTooltipHelper`: description, deprecation, codegen preview, per-parameter
detail). The delta is exactly three things, and if these are not judged worth four new files, **fold
the content into the picker panel instead and skip Phase 2's scaffold**:

1. **A rendered figure of the verb**, which neither surface can show (a tooltip cannot host a
   viewport, and the picker's info panel is 110 px tall, `ace_picker.gd:391`).
2. **The `EventSheetSectionInfo` blurb** - "what is this whole category for" - which neither surface
   shows today.
3. **Persistence.** A hover tooltip vanishes; a panel stays open beside the sheet while the reader
   builds the row. This is the real usability delta and the reason it is a surface, not a tooltip.

All 1,040 builtin `ACEDefinition`s carry a non-empty `description`, and building the registry
measured 22 ms (static cache, `ace/ace_registry.gd:16-17`). This page can never rot, because it is
the same data the picker draws.

---

## 3. The architecture

### 3.1 New files

```
addons/eventsheet/editor/docs/
  doc_markdown.gd     EventSheetDocMarkdown   static, pure: Markdown text -> Array[Dictionary] blocks
  doc_library.gd      EventSheetDocLibrary    static: discovery, ids, manifest, search index
  doc_figure.gd       EventSheetDocFigure     Control: figure-mode viewport + caption + Insert/Copy
  doc_page_view.gd    EventSheetDocPageView   Control: blocks -> Controls, anchors, meta_clicked
  doc_browser.gd      EventSheetDocBrowser    Control: tree + search + page (host-agnostic)
  doc_window.gd       EventSheetDocWindow     Window host (Phase 2)
  doc_dock.gd         EventSheetDocDock       EditorDock host (Phase 6)
  doc_explain.gd      EventSheetDocExplain    static: row/definition -> blocks, from the live registry

addons/eventsheet/help/                       [Phase 3 only]
  index.esdoc                                 generated manifest (drift-gated)
  GUIDE-*.md, REFERENCE-*.md, ...             the shipped guides, copied verbatim

addons/eventsheet/themes/
  mockup_slate_theme.tres                     re-homed (see 3.9 - it needs a gate too)

tools/build_help_bundle.gd                    generator + convenience checker (NOT the gate, see 7)
tests/doc_markdown_test.gd
tests/doc_library_test.gd
tests/doc_figures_test.gd
tests/doc_figure_view_test.gd
tests/doc_explain_test.gd
tests/doc_viewer_test.gd
```

`addons/eventsheet/editor/docs/` matches the existing subfolder idiom (`dock/`, `interaction/`,
`ace_dialog/`, `inspector/`, `autocomplete/`, `popup_editors/`).

### 3.2 The one renderer change (corrected: it needs a WIDTH term)

`EventSheetViewport` gains a **figure mode** and **content size accessors**. This is the single
change to existing rendering code the whole plan needs.

Measured behaviour today, in this project, headless:

| Config | `total_height()` | `custom_minimum_size` |
|--------|------------------|------------------------|
| footers on, host 400 px | 419.0 | (760, 419) |
| footers off, host 400 px | 389.0 | (760, 400) |
| footers off, host 1 px | 389.0 | (760, 389) |
| footers off, host 300 px wide, not a ScrollContainer | 509.0 | **(640, 509)** |

So:

- `show_add_event_footers = false` (declared `event_sheet_viewport.gd:240`, honored at :1931 and
  `interaction/viewport_row_builder.gd:2825`) removes the "+ Add event..." strip: 30 px here.
- `_update_canvas_min_size` (:2274-2286) computes
  `max(total_height * zoom, max(_get_viewport_height(), 240.0))` for height, and
  `_get_viewport_height()` (:3388) returns the parent `ScrollContainer`'s height. So a figure
  **always fills its host and never shrinks below 240 px**.
- **The same function computes `canvas_width = max(_get_scroll_width(), 640.0 * zoom)` (:2276), and
  `_get_scroll_width()` (:3395-3399) falls back to `size.x` or `640.0` when the parent is not a
  `ScrollContainer`. So a figure also has a hard 640 px MINIMUM WIDTH.** The first draft's seam fixed
  only height. This is load-bearing at both ends of the plan:
  - **Phase 6**: an `EditorDock` at `DOCK_SLOT_RIGHT_UL` is nowhere near 640 px. Every figure would
    force the dock open to 640 px or push the page into horizontal scroll, which destroys the stated
    rationale ("open beside the sheet"). **Either the width seam lands, or Phase 6 is re-scoped to a
    floating/horizontal-layout-only dock.**
  - **Phase 1**: the ACE picker's info panel fits 640 px, but barely. `ace_picker.gd:267` sets
    `content.custom_minimum_size = Vector2(700.0, 0.0)`; the info panel subtracts 8+8 px of
    `MarginContainer` (:394-398) plus the inset `PanelContainer` stylebox padding
    (`popup_ui.gd:151`, 1 px border + 4 px corners). Roughly 40 px of headroom - thin enough that a
    stylebox change breaks it silently. Do not rely on it; land the width seam in Phase 1.
  - Phase 1 also has a **height** constraint the draft missed: `_info_panel.custom_minimum_size =
    Vector2(0.0, 110.0)` (`ace_picker.gd:391`). A one-row figure plus caption plus two buttons does
    not fit 110 px. The picker ship must give the panel a taller minimum or put the figure in its own
    row below the panel. Decide this with a preview image, not in code review.

The seam:

```gdscript
## Figure mode: this viewport is a read-only doc illustration, not an editing surface.
## Suppresses the footer CTA, ALL pointer interaction, the per-frame scroll poll, and sizes the
## canvas to its rows instead of filling the host - in BOTH axes.
func set_figure_mode(enabled: bool) -> void

## The measured height of the rows, ignoring the host-fill and the 240 px editor floor.
func content_height() -> float

## The measured width of the widest row, ignoring the 640 px canvas floor. Figures in narrow hosts
## (the ACE picker panel, the Help dock) depend on this; without it every figure is >= 640 px.
func content_width() -> float
```

`content_height()` returns `_row_metrics_helper.total_height()`, which already exists at
`interaction/viewport_row_metrics.gd:366` and is only reachable through a private member today.
`content_width()` is new: it must be derived from the built spans, and if no such measurement exists
in `viewport_row_metrics.gd`, the fallback is an explicit width the figure host imposes (a
`figure_width_override` setter), which is acceptable for v1 but must be a real setter, not the 640 px
floor.

`set_figure_mode(true)` sets `companion_mode = true`, `show_add_event_footers = false`,
`focus_mode = Control.FOCUS_NONE`, `mouse_filter = Control.MOUSE_FILTER_IGNORE`, stops the process
poll, and makes `_update_canvas_min_size` use `total_height * zoom` and the content/override width
directly.

### 3.3 Making a figure genuinely inert (corrected and expanded)

The first draft said a figure is made inert by "leaving every viewport signal unconnected and setting
`focus_mode = NONE`". **That is not sufficient.** Four verified problems:

1. **`companion_mode` gates only inline editing.** Declared at :212, honored at exactly one place,
   :2471 (an early return out of `_begin_edit`). Selection, hover repaint, drag start, tooltips,
   context-menu emission and keyboard nav are unaffected. Unconnected signals stop *consumers*, not
   the repaints and state changes the viewport does to itself. `companion_mode` has no production
   consumer today (`tests/multi_view_test.gd:42` asserts the split pane is *not* in it), so a figure
   is its first real one.
2. **The shipped defaults fight you.** Probed on a fresh instance: `focus_mode = FOCUS_ALL (2)` and
   `mouse_filter = STOP (0)`. And `interaction/viewport_input.gd handle_mouse_button` calls
   `_viewport.grab_focus()` **unconditionally** on right-press (:122), and **zooms on Ctrl+wheel**
   (:102-110) before any hit test runs. A doc illustration that highlights rows under the cursor and
   zooms on Ctrl+wheel reads as an editing surface, which is precisely the confusion an illustration
   must avoid. Figure mode must therefore set `mouse_filter = MOUSE_FILTER_IGNORE` **and**
   early-return at the top of `handle_mouse_button` / `handle_mouse_motion`, not only in
   `_begin_edit`.
3. **`set_process(false)` is undone by `_ready`.** `_ready` (:270-273) calls `set_process(true)`
   unconditionally. Calling `set_figure_mode(true)` before `add_child` therefore silently re-enables
   the per-frame poll. Either apply the flag after tree entry, or teach `_ready` to honor it - the
   latter is safer and is what the spec mandates.
4. **Never hand a figure an empty sheet.** `interaction/viewport_empty_state_helper.gd`
   `is_sheet_visually_empty()` (:28) triggers a getting-started overlay with real clickable CTA
   buttons whose hit rects are registered (:55). Verified: an empty `EventSheetResource` reports
   `visually_empty=true`. The figure builder must refuse an empty sheet loudly.

**Rejected: driving `EventRowRenderer.draw_row` from a lightweight control.** `draw_row`
(`event_row_renderer.gd:311`) needs a `layout` Dictionary that only
`interaction/viewport_layout_builder.gd` produces, and that builder makes 63 `_viewport.` accesses
into the layout cache, style signature, span-build choke point and drag state. Reusing the whole
viewport is dramatically cheaper than re-driving the renderer.

### 3.4 Data flow, Markdown source to rendered page

```
docs/*.md  (authoring truth, unchanged, still what GitHub shows)
   │
   │  tools/build_help_bundle.gd            [build time, drift-gated from tests/]
   │    - copies the curated guide set verbatim into addons/eventsheet/help/
   │    - derives index.esdoc from docs/README.md's own grouped link list
   ▼
addons/eventsheet/help/*.md + index.esdoc   (ships in the plugin zip)
   │
   │  EventSheetDocLibrary.pages() / page_source(id) / search(query)
   ▼
raw Markdown text
   │
   │  EventSheetDocMarkdown.parse(text, doc_id) -> Array[Dictionary]
   │    static, pure, no engine dependency beyond String -> headless testable
   ▼
blocks: [{kind:"heading", level, text, slug},
         {kind:"paragraph", bbcode},
         {kind:"list", ordered, items:[bbcode]},
         {kind:"table", headers, rows},
         {kind:"code", language, lines},
         {kind:"figure", source, crop_prelude, caption},
         {kind:"snippet_figure", text, caption},
         {kind:"image", path, alt},
         {kind:"quote", bbcode}, {kind:"rule"}]
   │
   │  EventSheetDocPageView.render(blocks)        [runtime, themed]
   │    headings  -> EventSheetPopupUI.section_header + EditorFonts doc_title
   │                 (each records slug -> the emitted Control, see 3.7)
   │    prose     -> RichTextLabel (bbcode_enabled + fit_content, see 3.8)
   │    table     -> panel_section + push_table/push_cell
   │    code      -> monospace card
   │    figure    -> EventSheetDocFigure -> EventSheetViewport (figure mode)
   ▼
a page of native Controls, themed from the running editor
```

**Decision: one parser, run at runtime, not a build-time transform.** The bundle step is a *copy plus
a manifest*, not a conversion.

*Rejected alternative: compile Markdown to a serialized page model at build time.* It reads
appealing (parse once, render fast) but it forces two implementations the moment the viewer also
reads user-authored docs (Phase 5), and two implementations of a parse is exactly the drift this repo
gates against everywhere else. The performance argument does not survive measurement either: a naive
Markdown-to-BBCode pass over all 111 files measured **49 ms total, 0.44 ms per file**, and the
largest file (`GUIDE-CUSTOM-ACES.md`, 57,385 chars) converted in 2.1 ms. On-demand parsing is free.

### 3.5 Where the corpus lives (Phase 3 only)

**Decision: copy the guides into `addons/eventsheet/help/`, gated by a byte-identity check in
`tests/`.**

*Rejected: move `docs/` under `addons/eventsheet/docs/`.* It breaks every `docs/GUIDE-*.md` link in
`README.md`, every external URL to those paths, and `tests/docs_integrity_test.gd`, which pins
content markers at `res://docs/internal/SPEC-layout-alignment.md`,
`res://docs/internal/SPEC-gdscript-pairing.md`, `res://docs/GUIDE-THEMING.md`, `res://AGENTS.md` and
`res://demo/themes/designer_template_theme_manifest.cfg`.

*Rejected: read `res://docs/` at runtime.* Empty viewer for every installed user.

*Rejected: stage `docs/` into the plugin zip only in `release.yml`.* Then the viewer is empty for
anyone installing from a git clone, and the drift gate cannot run in the suite.

*Not rejected, recommended instead for readers who only want the prose: `OS.shell_open` to a
version-pinned URL.* See section 1.3. **This is the alternative that makes the whole of 3.5 optional.**

**The duplication cost, stated as a number rather than a shrug.** 394 of 1,315 commits touch
`docs/*.md`. Under this decision, **30% of all commits gain a regenerate-and-commit step**, and the
CLAUDE.md release ritual gains one too. The 76 generated packs are **not** a comparable precedent:
they are compiler output nobody hand-edits, while `docs/*.md` is the most-touched authored surface in
the repo. The mitigation is that the gate must fail loudly in CI (section 7), not that the cost is
small.

**Decision: no images in v1.** `docs/images/` is 5,036,228 bytes across 80 PNGs, of which roughly 39
are orphaned (44 distinct filenames are actually referenced from `docs/` + `README.md`). Every PNG
has a `.png.import` sibling, so shipping them would also cost every user's project an import pass and
`.godot/imported` space. Live figures are the point of this feature and are strictly better than a
screenshot of a sheet. Image blocks degrade to alt-text caption cards.

**Decision: the shipped set is the 39 top-level guides (753 KB, about +11% on a 6.5 MB `addons/`).**
The 72 addon guides describe `eventsheet_addons/` packs, which are themselves optional and ship in the
samples zip - so they belong with their packs (Phase 5), discovered per pack the same way
`EventSheetL10n` already discovers `eventsheet_addons/<pack>/translations.csv`
(`editor/l10n.gd:76-85`). `docs/internal/` never ships. Note that `docs/Addons/` currently ships in
**neither** zip, so pack users have no guides at all today - another place the Phase L link rewrite
beats a mirror.

### 3.6 The manifest is derived, not hand-maintained (counts corrected)

`docs/README.md` is already a grouped index. **Corrected measurement:** it carries **nine** `##`
groups, not the seven the first draft listed - `## Learn by doing`, `## The Studios (in-editor
authoring tools)`, `## Extend the plugin`, `## Patterns`, `## Localization`, `## Working with your
project`, `## Coming from Construct 3`, **`## Reference`**, **`## Addon packs`** - and it links
**all 38** top-level guides (every `docs/*.md` except `docs/README.md` itself), not 37.

Two consequences for the executor:

- A build script written against a seven-group model **mis-files the Reference and Addon-packs
  sections**. Derive the groups; do not transcribe them.
- The "Other" group the first draft provisioned for unlinked guides is **dead code today**. Keep it
  as a gate output (the check must report any guide the index forgot), not as a UI group that will
  never populate.

`tools/build_help_bundle.gd` derives the viewer's tree from that structure, so grouping stays authored
where it already is and cannot fall out of sync. This follows the standing preference for derived
tables over hand-maintained ones.

`index.esdoc` uses the versioned-text discipline `EventSheetSnippet` already established
(`editor/event_sheet_snippet.gd:11`, `const HEADER := "[eventsheet-snippet v1]"`): a header line
`[eventsheet-help v1]` followed by a `var_to_str` payload, built in sorted order so regeneration is
byte-stable. An unknown extension is not imported by Godot, so it costs nothing at import time.

### 3.7 Links and anchors (the anchor MECHANISM was wrong - corrected)

#### The slug rule (verified correct, keep it)

Measured over the 39 shipped guides: **316 of 316** in-page anchors resolve with this rule. Measured
over the whole 111-file corpus, 773 of 773. The rule is:

1. lowercase and trim,
2. drop backticks and `*`,
3. delete every character that is not `a-z`, `0-9`, `_`, `-`, or a space,
4. replace each remaining space with `-`, **without collapsing runs**,
5. on a duplicate slug within a page, append `-1`, `-2`, ...

Step 4 is the load-bearing one. `## 3. How it runs - File > Run, editor vs game` becomes
`3-how-it-runs---file--run-editor-vs-game`, because " - " leaves three characters and " > " leaves
two. Collapsing runs is what makes those anchors look broken. Underscores must be kept, or
`#8-the-codegen_template-language` fails.

#### The jump mechanism (the first draft's was a no-op)

The first draft said: the emitter records `slug -> paragraph_index` and jumps with
`scroll_to_paragraph(i)`. **That does not work in this page architecture, and would have shipped
green.** The same spec builds *one RichTextLabel per contiguous run*, with headings as separate
`section_header` Controls inside an outer page container. So:

- paragraph indices are **per-label**, not per-page;
- `scroll_to_paragraph` drives **that label's own internal scrollbar**, not the page's;
- a content-sized (`fit_content`) label inside a page `ScrollContainer` has **zero internal scroll
  range**, so the call does nothing. Probed in 4.7: on a 61-paragraph label,
  `scroll_to_paragraph(40)` set the label's own `VScrollBar` to `value = 100.0` (its max) while
  `visible = false`. `get_paragraph_offset(40)` returned `0.0` outside a laid-out tree.

**The correct mechanism:** the page view records `slug -> the emitted heading Control`. A jump
resolves the Control, computes its position **relative to the outer page container**, and sets the
outer `ScrollContainer.scroll_vertical`. Positions are only valid after layout, so a jump issued
during page build must be deferred one frame (`await get_tree().process_frame` or
`call_deferred`) after the container has sized.

This matters disproportionately because anchors are load-bearing: `EventSheets.open_docs(doc_id,
anchor)` is the frozen public entry point, "explain this row" and search results both land on
anchors, and 316 of 316 in-page links in the shipped guide set are anchors.

**And it is not headless-testable.** `get_paragraph_offset()` / Control positions return 0 without a
laid-out tree, and under `--script` the SceneTree's `_init` runs before the tree exists (probe: a
plain Control added under `get_root()` reported `is_inside_tree() == false` and `_ready` never ran).
The suite can pin the slug string and the `slug -> Control` registration. **It cannot pin the jump.**
Section 7 splits the test rows accordingly, and Phase 3 must include a non-headless harness check of
an actual anchor jump before it is called done.

#### Link classification, and the gate decision the spec has to make

Link targets resolve as: `#slug` -> in-page scroll; `NAME.md` -> doc id; `NAME.md#slug` -> doc id plus
anchor; `http(s)://` -> `OS.shell_open` (verified present). Image paths resolve **relative to the
containing file**, because the corpus uses two prefixes (`images/foo.png` from `docs/*.md`,
`docs/previews/foo.png` from the root `README.md`).

**Measured over the 39 shipped guides: 68 cross-file `.md` links, of which 64 resolve inside the
shipped set and 4 do not.** (The first draft said 143 of 143 over the whole corpus; a review said
67 of 68; both were wrong for the set actually shipped. The real out-of-set targets are:
`../EVENTSHEETS-VOCABULARY.md` x1 from `docs/GUIDE-RECIPES.md:505`, `../README.md` x1, and
`Addons/README.md` x2.) A further 31 links are images, already handled as alt-text cards.

A gate written as "every cross-file link resolves to a shipped id" therefore **fails on its first
run**, which is how drift discipline erodes - the gate gets weakened or disabled. **The spec makes
the call rather than leaving it to implementation time:**

> **Define a third link class: `external_known`.** A link whose target is a real repo file that the
> bundle deliberately excludes resolves to `EventSheets.open_online_doc(<repo-relative path>)` and
> opens the version-pinned URL. The gate asserts every cross-file link is *either* a shipped id *or*
> a real file on disk in `external_known` - and **fails on a link that is neither**, which is the
> failure that actually matters (a typo or a renamed guide).

Rejected: generating a vocabulary page into the bundle. It fixes 1 of the 4 misses, adds 170 KB, and
does nothing for `../README.md` or `Addons/README.md`, which are not guides.

**BBCode escaping trap:** literal `[` and `]` in doc prose must be escaped to `[lb]` / `[rb]` before
any BBCode is inserted, or the parser eats them. This repo has been bitten by it before (the
beginner-readability sentence work built its segments directly for exactly this reason).

### 3.8 The RichTextLabel sizing trap (the repo has already been bitten by this)

The page model is a stack of autowrapping `RichTextLabel`s inside a scrolling container. That is
precisely the configuration `ace_picker.gd:383-384` documents inline as a known failure:

> a container that hugs its content's minimum size makes a `fit_content` + autowrap `RichTextLabel`
> report a huge min height during that pass (it wraps at ~0 width), which would balloon the whole
> dialog

which is why the picker's own info label is deliberately `fit_content = false` with
`scroll_active = true` (`ace_picker.gd:400-403`). The doc page cannot make that choice - a page label
must grow to its content, or the page becomes a stack of tiny scrollboxes.

**The rule for the executor:** every prose label sets `bbcode_enabled = true` (defaults `false`,
verified) **and** `fit_content = true` (defaults `false`, verified), and its **width must be imposed
by the container before the min-size pass** - i.e. the page container is width-driven
(`SIZE_EXPAND_FILL` inside a `ScrollContainer` with `horizontal_scroll_mode = SCROLL_MODE_DISABLED`),
never a container that hugs content in both axes. Get this wrong and the page either collapses to
zero-height labels or balloons its host window. Ship the Phase 3 preview image at a narrow window
width specifically to catch it.

### 3.9 Theming: pick one, do not leave it ambiguous

The first draft contradicted itself. Its one-sentence contract said a figure "is themed by whatever
theme the reader chose"; section 3 said doc figures "explicitly apply the re-homed
`mockup_slate_theme.tres` unless the reader has chosen a theme". It never defined how "has chosen a
theme" is detected, nor what a page looks like with mockup-palette figures inside editor-themed prose.

**Verified context that settles it:** `res://addons/eventsheet/themes/` does not exist today
(`addons/eventsheet` contains `ace`, `api`, `editor`, `elements`, `icons`, `mcp`, `resources`,
`runtime`, `theme`, `translations`), so `EventSheetThemePresets.THEME_DIRS[0]`
(`theme/event_sheet_theme_presets.gd:10-13`) scans nothing, and all 10 bundled themes live in
`demo/themes/` which ships only in the samples zip (`release.yml:74-76`). **So "the reader has chosen
a theme" is false for essentially every plugin-only install.** Mockup-slate figures against
editor-themed prose is not the edge case; it is the default outcome for most users.

**Decision: a figure uses the sheet's theme when a sheet is open and has one, and otherwise uses the
editor-adapted theme (`EventSheetGodotTheme.adapt_to_editor`), NOT the mockup palette.** Rationale: a
figure's contract is *"this is what your editor will look like"*. A figure that is deliberately a
different colour from the editor beside it breaks that contract, and it is unreadable in a light
editor. The mockup palette ships as a **preset the reader can pick**, which also fixes the
zero-presets bug above. If the user prefers mockup-slate-always, that is a legitimate call - but it
must be made against a **preview image of a mockup figure inside an editor-themed page**, not
assumed.

Remaining theme rules:

- Re-homing `mockup_slate_theme.tres` into `addons/eventsheet/themes/` gives an installed
  plugin-only user their first theme preset. **It needs a gate.** The first draft copied the file
  with no drift check while gating the far larger Markdown copy - creating a second silent source of
  truth for the palette the whole visual language is built on. Worse, `list_presets` de-dupes by
  humanized display name, so the duplicate is invisible in the UI. **Either** fold the theme into
  `tools/build_help_bundle.gd`'s byte-identity check, **or** (cleaner) move the file to
  `addons/eventsheet/themes/` and repoint `demo/` at it, so there is one copy.
- Chrome colors derive from the editor theme through the existing `EventSheetGodotTheme.apply` path
  so light, dark and custom-accent editors all work. Read the theme through
  `EditorInterface.get_editor_theme()`, never through an inherited `.theme`: at
  `EditorPlugin._enter_tree` the base control's `theme` is still null while `get_editor_theme()` is
  already populated. Building lazily (the plugin already does, `plugin.gd:316` `_ensure_editor`)
  sidesteps it.
- Do **not** key anything off a theme preset name: `interface/theme/preset` does not exist in 4.7
  EditorSettings.
- Every fixed metric goes through `EventSheetPalette.scaled()` / `scaled_f()`
  (`theme/event_sheet_palette.gd:172-177`) because `tests/ui_scale_test.gd` lints literal font sizes
  and literal `draw_string` sizes plugin-wide. **Row text is the exception** - the palette header
  documents that routing row text through the scale double-applies it, since it already inherits
  scale through `get_theme_default_font_size()`.
- Subscribe to `EditorSettings.settings_changed` to re-theme live.

### 3.10 Localization

- Viewer **chrome** auto-translates: parent the browser under the dock or call
  `EventSheetL10n.apply_to(root)` (`editor/l10n.gd:239`), which assigns the `eventsheets`
  `TranslationDomain` so every descendant Control's text and tooltip translates.
- **Derived reference content** (ACE descriptions, section blurbs) routes through
  `EventSheetL10n.translate` (:229), exactly as `ace_picker.gd:1824` already does. The mechanism is
  wired; the catalogs are empty for those strings today (`TEMPLATE.csv` is 1,133 rows of chrome, and
  only one pack in the repo ships a `translations.csv`). Adding ACE descriptions to the CSVs would
  localize the whole generated reference for nine languages with no code change. Flagged, not scoped.
- **Guide prose stays English.** 40,174 lines against roughly 1,145 chrome strings per locale, with
  zero precedent for translated Markdown. This is a deliberate scope line, stated so nobody discovers
  it as a surprise.

---

## 4. The figure contract

### 4.1 The ladder

**Tier 0 - a bare fence.** Renders as a monospace card, exactly as today, making no correctness
claim. This is the right home for the majority of what is in the corpus now: roughly 1,300 of the
~1,470 fences are untagged, they use at least four hand-written dialects (`->` on 3,218 lines,
`Condition:` on 502, `Else` on 52, unicode arrows, `//` comments, `Inspector:` heads, `?` condition
markers), and about a third of their arrow lines are deliberate prose, not verbs (`-> give the player
200 gold` in `docs/Addons/Quest.md:165`, `-> Respawn at the checkpoint` in
`docs/Addons/Checkpoint.md:123`). **No plan may assume these can be mechanically converted.**

**Tier 1 - the GDScript figure - the recommendation.** The fence body is **plain GDScript**. The
viewer runs `EventSheets.open_gd_as_sheet(body)` (`api/eventsheets.gd:514`) and hands the resulting
`EventSheetResource` to a figure-mode viewport. Zero new notation, the existing lossless lifter does
the work, the figure *is* the emitted code so it cannot become a second source of truth, it stays
readable on GitHub, and it is byte-gatable. **How a Tier-1 fence is recognised is section 4.7 - the
first draft's answer (a new fence tag) is not obviously the right one.**

**Tier 2 - ` ```eventsheet-snippet `.** The body is `[eventsheet-snippet v1]` text produced by the
editor's own Copy (`editor/event_sheet_snippet.gd:11`). Use only where GDScript cannot express picker
state: negated conditions, OR/else modes, event groups, custom block rows. Machine-exact, already
versioned, already deserialized by `EventSheetSnippet.deserialize` (:48) with a whitelist on rebuild,
and click-to-insert is free. Cost: unreadable on GitHub, so **every Tier-2 figure requires a plain
prose sentence immediately above it** - which is the alt text you want anyway.

**Tier 3 - referencing a real `.gd` / `.tres` sample sheet.** Escape hatch only, for the handful of
walkthroughs whose point is "open this file". *Rejected as the primary mechanism*: it re-imports the
shipping problem, makes the doc unreadable on GitHub, and takes control of the figure away from the
guide.

### 4.2 The two rules that make or break a figure

**1. The body must carry a script header.** Verified, and this is the trap:

| Fence body | Lift result | `round_trips` |
|-----------|-------------|---------------|
| starts with `extends CharacterBody2D` | `[raw_code_row, event_row]` | `true` |
| starts directly with `func _physics_process(...)` | `[raw_code_row]` only | **`true`** |

A header-less body lifts to a **single verbatim `RawCodeRow`** and renders as a wall of text - and
`round_trips` still returns `true`, because re-emitting verbatim code is trivially lossless. So:

**2. `round_trips` alone is NOT a sufficient gate.** The gate must also assert the figure lifted to
at least one **non-`RawCodeRow`** row.

**Use `EventSheets.round_trips(source)` (`api/eventsheets.gd:574`), never
`EventSheets.compile(sheet)`.** `compile` without an output path re-emits the
`# AUTO-GENERATED by EventForge vX` banner and duplicates `extends`, so its output can never be
byte-equal to the source. `round_trips` avoids that by setting `sheet.external_source_path` first
(:577-579).

### 4.3 Prelude cropping

- Default: **leading prelude rows are cropped from the display** - the `extends` / `class_name` /
  `@tool` rows that the lift produces at the top - because the guide's prose already established the
  host and `extends CharacterBody2D` is scaffolding, not the lesson. A `full` option shows them.
- Cropping is **display only**. The gate always runs on the complete fence body.

### 4.4 Worked example

Source in the guide:

````markdown
Appending to a list and reacting when it is empty:

```gdscript
extends CharacterBody2D

@export var speed: float = 220.0


func _physics_process(delta: float) -> void:
	if Input.is_action_pressed("ui_right"):
		velocity.x = speed
	move_and_slide()
```
````

Verified behaviour, run headless in this project:

```
EventSheets.open_gd_as_sheet(body) -> 4 rows
   raw_code_row.gd   (extends CharacterBody2D)      <- cropped from display by default
   local_variable.gd (@export var speed)
   event_row.gd
   event_row.gd
EventSheets.round_trips(body) -> true
```

The viewer renders those rows through `EventSheetDocFigure` with Insert and Copy under them.

### 4.5 `tests/doc_figures_test.gd` - the anti-rot gate

Modelled on `tests/personal_paths_test.gd`, which **proves its detector against positive and negative
fixtures before sweeping**, so a gate that silently matches nothing cannot masquerade as a clean
repo.

1. **Prove the detector.** A fixture with a good Tier-1 figure must pass; a header-less fixture must
   fail; a Tier-2 fixture naming a nonexistent `ace_id` must fail. Assert those three verdicts
   first.
2. **Sweep every shipped guide.** For each Tier-1 fence: `EventSheets.round_trips(body) == true`
   **and** the lift yields at least one row whose script is not `raw_code_row.gd`.
3. **Sweep every Tier-2 fence:** `EventSheetSnippet.deserialize(text)` returns rows, and every
   `{provider_id, ace_id}` resolves through the **live** registry.

Rule 3 is precisely "a renamed verb breaks the suite", and it is stronger than name matching because
`ace_id`s are the frozen public API while display names are renameable through `@ace_name` and
`EventSheets.override_verb`.

### 4.6 The advisory sweep, deliberately not a gate

A Tier-0 name sweep, resolved against the **live** registry union, ships as a printed advisory count
(or a Doctor note), never a hard failure - it would fail on hundreds of blocks on day one by design.

**The oracle must be the live registry, never `EVENTSHEETS-VOCABULARY.md`.** The vocabulary doc
parses `@ace_*` annotations only and misses every reflected verb. Proof: `docs/Addons/Sine-3D.md:83`
writes `-> Coin | Sine 3D: Set Magnitude 0.5`; the vocabulary doc lists three Sine3D actions and no
`Set Magnitude`; but `EventSheetACEGenerator.generate_from_object()` on a live `Sine3DBehavior`
yields 21 definitions including `Set Magnitude`, built at `ace/ace_generator.gd:296`
(`"Set %s" % display_name`). Measured, using the vocabulary doc instead of the live registry moved
the match rate from 70.9% to 63.7%: roughly 230 false "rot" reports.

Caveat for the executor: instance reflection is **editor-dead for non-`@tool` scripts** (the standing
project trap). A headless test may reflect instances; anything resolving names inside the running
editor must use the script-level path `editor/addon_guide_scaffold.gd` uses
(`get_script_method_list` plus `@ace_*` annotations read from **disk**).

### 4.7 How a Tier-1 fence is recognised: OPT-IN TAG vs AUTO-DETECT

The first draft minted a new fence tag (` ```eventsheet `, plus a `full` / `caption:` option grammar)
and **froze it as a compatibility promise** without evaluating the alternative. It should be
evaluated, because the numbers favour the alternative.

**Measured fence-tag histogram over `docs/*.md` + `docs/Addons/*.md`:** 162 ` ```gdscript `, 2 `sh`,
2 `json`, 1 each `text` / `gitattributes` / `csv`, and roughly 1,300 untagged.

| | **A. Opt-in `` ```eventsheet `` tag** (first draft) | **B. Auto-detect existing `` ```gdscript `` fences** |
|---|---|---|
| Figures on day one | ~20 hand-converted (Phase 4 budget) | up to **162**, zero authoring churn |
| New frozen public syntax | a fence tag + option grammar | none (a `no-figure` opt-out comment only) |
| Information the tag carries | none the gate cannot derive - Tier 1's body is plain GDScript by design | n/a |
| Risk | authors must remember to opt in; adoption stalls | a fence meant to stay code renders as a figure |
| Fits the standing "derived over hand-maintained" preference | no | yes |

**Recommendation: BOTH, layered - automatic by default, authored as the override.** The two
options are not rivals: they feed the same gate and the same renderer, so a hybrid costs barely
more than B alone. One recognizer decides per fence, in precedence order:

1. ` ```eventsheet ` - the AUTHORED fence. Always a figure (it still must pass the gate; a body
   that fails the gate is a build error naming the fence, never a silent code card). Carries the
   author's intent the detector cannot infer.
2. `<!-- no-figure -->` immediately above a ` ```gdscript ` fence - authored opt-OUT; the fence
   stays a code card forever.
3. ` ```gdscript ` passing `round_trips(body) == true` **and** lifting to at least one
   non-`RawCodeRow` row - AUTOMATIC figure. This is what lights up the existing corpus (up to 162
   fences) and every future guide written in the normal house style, with zero authoring churn.
4. Everything else - a code card, exactly as today.

Captions come from the nearest preceding heading, or from a `<!-- caption: ... -->` comment
(which works above BOTH fence kinds - captioning must not require converting an automatic fence
to an authored one).

The authored grammar goes back on the freeze list, so it must stay SMALL to stay cheap to
promise: the tag itself, `<!-- no-figure -->`, and `<!-- caption: ... -->`. Nothing else in v1.
Any richer option (highlight a row, collapse the trigger, size hints) ships later as an
additive comment marker, never as a change to these three.

Why the layering is the right shape for this repo: the automatic layer preserves the standing
derived-over-hand-maintained preference and the zero-churn expansion story (a guide written the
normal way grows figures for free), while the authored layer answers the one real risk B carried
alone - a fence that passes the gate but reads better as code, or a figure the author wants even
though the body is all raw rows. Instead of measuring the corpus to pick a side, the measurement
(still **the first task of Phase 4**, a 20-minute headless script) now only tunes the DEFAULT:
if many gate-passing fences should stay code, flip the automatic layer to conservative (require
2+ lifted rows) rather than abandoning it.

This changes Phase 4 from "hand-convert 20 fences" to "light up whatever already passes, and
hand-mark the exceptions" - which materially raises Phase 4's value, and with it the case for
Phase 3 (section 0.3).

---

## 5. Phases

Every phase ships on its own, with tests green, a `CHANGELOG.md` `[Unreleased]` entry, and (for UI)
a rendered preview image from a temp `tools/render_*.gd` harness run **non-headless**, deleted before
committing.

### Phase L - fix the shipped links (new; ~half a day)

**Do this first regardless of what is decided about Phases 3-6.**

- `EventSheets.open_online_doc(relative_path, anchor := "") -> bool`: `OS.shell_open` to
  `https://github.com/SalmanShhh/Godot-EventSheet-Visual-Scripting/blob/v<VERSION>/<relative_path>`,
  where `<VERSION>` comes from the same constant the release ritual bumps.
- Repoint `welcome_window.gd:159-160` (and rewrite its tooltip at :158, which names the same
  unreachable path).
- Add a `sed` step to `release.yml` staging that rewrites the **29 relative `docs/...` links in
  `README.md`** to absolute tag URLs in the staged copy only (same shape as the existing
  `sed -i "s/^version=.*/..."` on `plugin.cfg` at :70).
- Re-grep `addons/` for `res://docs/` before shipping.

Ships: the shipped-broken-docs bug, fixed, everywhere.

### Phase 1 - the figure widget (genuinely small; independent of everything else)

Build the illustration, and ship it by upgrading a surface that already exists. **Structurally
independent of Phase 3** - no Markdown, no corpus, no library. Its risk is the width/height
constraint in section 3.2, not a hidden dependency.

- `EventSheetViewport.set_figure_mode(bool)`, `content_height() -> float`, `content_width() -> float`
  (or an explicit width override), and the four inertness fixes in section 3.3 - including teaching
  `_ready` to honor the flag and early-returning in `viewport_input.gd`.
- `addons/eventsheet/editor/docs/doc_figure.gd` (`EventSheetDocFigure`): caption + figure-mode
  viewport sized to content + Insert/Copy buttons.
- `EventSheets.insert_snippet(text, label)` (section 2.4), delegating to the guarded
  `_paste_snippet_text`. Frozen on ship.
- Re-home `mockup_slate_theme.tres` into `addons/eventsheet/themes/` **with a gate or a move, not a
  bare copy** (section 3.9). Gives an installed plugin-only user their first theme preset.
- **The ship:** the ACE picker's info panel gains a live one-row figure of the selected verb, built
  from its parameter defaults. Visible, user-facing, previewable. Settle the 110 px panel height
  against a preview image first.

Out of scope: any Markdown, any corpus, any window, any search, images, the dock.

### Phase 2 - "explain this row"

The panel, with zero Markdown. **Read section 2.6 before starting: the delta over the picker panel
and the row tooltip is three specific things, and the `@ace_help` read path does not exist yet.** If
the delta is judged thin, fold the content into the picker's info panel and skip this phase's
four-file scaffold - `EventSheets.open_docs` can then land in Phase 3 instead.

- `doc_explain.gd`, `doc_page_view.gd`, `doc_browser.gd`, `doc_window.gd`.
- Content from `ACEDefinition`, `ViewportTooltipHelper`, `EventSheetSectionInfo`, plus a Phase 1
  figure, plus a **newly built** read-more affordance for `addon_help_url`.
- Entry points: **Tools > Documentation...** (`dock/menu_bar.gd:279-302`), **F1**, and a **"What does
  this do?"** row-menu item registered through `EventSheets.register_row_menu_item`.
- `EventSheets.open_docs(doc_id, anchor)` lands here, initially serving only generated ids
  (`"ace:Core/MoveAndSlide"`, `"section:Physics"`).

Out of scope: the corpus, the Markdown parser, search, per-pack guides, the dock.

### Phase 3 - the corpus ships, and can be read

**Only build this if section 0.3's question is answered yes.**

- `EventSheetDocMarkdown` (parser, slugs, inline BBCode, bracket escaping, link classification
  including the `external_known` class, fence classification).
- `EventSheetDocLibrary` (ids, manifest, page source).
- `tools/build_help_bundle.gd`: copies the 39 top-level guides into `addons/eventsheet/help/`,
  derives `index.esdoc` from `docs/README.md`'s **nine** grouped link sections, and in `--check` mode
  prints `help: pages=N drifted=0`. **This is a convenience wrapper. The gate is
  `tests/doc_library_test.gd`** (section 7).
- The browser grows the guide tree and renders real pages: headings, prose, lists, tables, code
  cards, image alt-text cards, **Control-position in-page anchors (section 3.7)**, cross-doc links,
  external links via `OS.shell_open`.
- The `open_docs` id gate (section 2.2): sweep `addons/` for hardwired doc ids and assert each
  resolves.
- Amend the CLAUDE.md release ritual and CONTRIBUTING.md with the regeneration step.
- **Non-headless harness check required before this phase is done:** an actual anchor jump lands on
  the right heading, and `meta_clicked` fires for a `[url]`.

Out of scope: live figures in guides (Tier-0 monospace cards only), search, images, addon guides,
user docs, the dock.

### Phase 4 - live figures in the guides

- **First task: measure the auto-detect question (section 4.7)** over the 162 existing ` ```gdscript `
  fences. Choose opt-in or auto-detect on that measurement, then implement.
- Tier 1 and Tier 2 handling in `EventSheetDocMarkdown` and `EventSheetDocFigure`, including prelude
  cropping.
- `tests/doc_figures_test.gd` with its detector proved first.
- **Measure per-frame draw cost with several figures visible** (section 6). Pool only if the
  measurement says so.
- The advisory Tier-0 name sweep, printed only.

Out of scope: converting the ~1,300 untagged fences, addon guides.

### Phase 5 - findable, and open to packs

- Search: index, ranked results tree, in-page highlight, plus the `?` prefix mode in
  `dock/command_palette.gd` alongside `#` and `@`.
- Per-pack guides: `eventsheet_addons/<pack>/guide.md`, discovered the way `EventSheetL10n` already
  discovers `eventsheet_addons/<pack>/translations.csv` (`editor/l10n.gd:76-85`). Third-party packs
  become first-class in the viewer.
- The `## ACE reference` section (present in 70 of 72 addon guides) renders from the **live**
  registry rather than from Markdown, reusing what `EventSheetAddonGuideScaffold.generate`
  (`editor/addon_guide_scaffold.gd:16`, public at `api/eventsheets.gd:1419`) already computes. Same
  for `## Reading it from expressions - the Self section` (67 guides). The build step diffs
  Markdown against the registry as an advisory report.
- A user docs folder: a `ProjectSettings` key mirroring the existing
  `eventsheets/project/vocabulary_doc_path` / `templates_dir` / `snippets_dir` pattern
  (`addons/eventforge/settings.gd:25-31`).

Out of scope: translated prose, images.

### Phase 6 - lives where the reader wants it

**Gated on the width seam (section 3.2). If `content_width()` did not land, re-scope this phase to a
floating-layout-only dock, or drop it.**

- `EventSheetDocDock` (`EditorDock`, `default_slot = EditorDock.DOCK_SLOT_RIGHT_UL`,
  `available_layouts` including `DOCK_LAYOUT_FLOATING`, `closable = true`, a stable `layout_key`),
  registered with `EditorPlugin.add_dock`.
- **The boot contract, which the first draft omitted entirely.** `add_dock` takes an **instance**, so
  registering the dock means constructing `EventSheetDocDock` inside `plugin.gd _enter_tree`, and
  naming (or building) it pulls the browser -> page view -> `EventSheetViewport` -> registry subtree
  into **every editor boot**. That is exactly the regression `tests/plugin_boot_lazy_test.gd` and the
  `plugin.gd:11-15` header comment exist to prevent (the 1.8s -> 85ms win), and the test's `FORBIDDEN`
  table is per-file, so it would **not** catch a new class name in `plugin.gd` unless someone adds the
  entry. Mandatory:
  1. load the dock script **by path** at call time, never by `class_name` in `plugin.gd`;
  2. build the dock's content **lazily** on first `make_visible()` / `open()` - the registered
     `EditorDock` is an empty `MarginContainer` until then;
  3. add `EventSheetDocDock` and `EventSheetDocBrowser` to
     `FORBIDDEN["res://addons/eventforge/plugin.gd"]` in `tests/plugin_boot_lazy_test.gd`, and add
     the dock script path to `LAZY_PATHS`.
- Register the public `EventSheets` API classes into the built-in Help with
  `ScriptEditor.update_docs_from_script`, so **Search Help** finds them. Expectations stay low: it
  renders in the engine's class-reference shape with no visual control and cannot show rows.
- `OS.shell_open` to the online docs (Phase L's helper) as the escape hatch for anything the native
  page cannot show.

Out of scope: a second main screen (impossible without a second `plugin.cfg`).

---

## 6. Risks and open questions

### Performance

- **Cold start is the real risk.** Measured headless: the first `EventSheetBlockRegistry.get_kind()`
  costs 672-773 ms (it runs `_ensure_built_ins`, `addons/eventforge/registration/block_registry.gd:105`);
  the second call costs 0.006 ms. `EventSheetL10n.ensure_loaded()` costs 96-141 ms
  (`editor/l10n.gd:44`). A further ~690 ms sits inside the first `set_sheet` that warming both of
  those did **not** remove. Worst case is roughly 1.5 s if a docs click is the first thing in a
  session to touch the vocabulary, and roughly zero if the workspace was opened first. **Mitigation:**
  warm the caches once off the click path (on first workspace open, or a deferred idle tick). **The
  residual ~690 ms is unattributed - attribute it before promising a fast cold open.**
- **Steady-state figures are cheaper than the first draft claimed, and they do not compound.**
  Re-measured on this repo with a **warm** registry, headless: construction + `add_child` +
  `set_sheet` of a 5-event sheet scaled **linearly** - 1 figure 1,830 us; 2 figures 1,830 us each;
  4 figures 1,464 us each; 8 figures 1,447 us each; 16 figures 1,451 us each. No superlinear blowup
  from stacking figures in one container, and per-figure cost is roughly **10x cheaper** than the
  first draft's "about 16 ms fixed" - that number evidently included cold registry warm-up.
  **Consequence for the design:** the pooling-plus-lazy-build machinery the first draft proposed as a
  mitigation is probably unnecessary complexity for v1. **Re-scope it to "measure draw first, pool
  only if needed".**
- **What is still unmeasured is per-frame DRAW cost with several canvases visible**, which headless
  cannot answer. Phase 4's preview harness must measure it directly.
- **Prose is a non-issue.** Reading all 111 files: 38 ms. Converting all of them: 49 ms. Appending
  2,000 styled lines to a `RichTextLabel`: 13.2 ms (though `get_content_height()` on that page then
  shaped for 132 ms, so avoid forcing a height measurement on a huge page).
- All timings are headless on one Windows machine. Re-measure on target hardware. And per the standing
  trap: a perf budget that flaps under load needs three runs at HEAD before blaming a diff.

### Payload and maintenance

- +753 KB of duplicated Markdown in `addons/`, about +11%. Gzipping the bundle into one compressed
  file is the lever if that ever hurts, at the cost of diffability and byte-stability confidence.
- **A second copy of the guides is a drift surface, and it is a big one: 394 of 1,315 commits touch
  `docs/*.md` - 30% of all commits.** It is gated (`drifted=0`), but the gate must live in `tests/`
  (CI-discovered), not only in `tools/` (section 7). The 76 generated packs are **not** a comparable
  precedent (section 3.5).
- **Guides gain a gated fence.** Once a guide carries a Tier-1 figure, an author breaking the
  GDScript inside it breaks the suite. That is the point, but it is new friction for doc edits and
  must be documented in CONTRIBUTING.md.
- **`AGENTS.md` "Docs map" and `tests/docs_integrity_test.gd` both pin doc structure.** Neither is
  broken by this plan (nothing moves), but both must be re-checked in Phase 3.
- **The CLAUDE.md release ritual gains a regeneration step** in Phase 3. Amend it in the same commit.

### Standing rules in tension

- **"Docs: self-contained, minimize cross-links" versus a hyperlinked viewer.** The standing
  preference is that a reader should not hop between files; a viewer's whole value is navigation.
  **This must be re-litigated with the user explicitly rather than assumed away.** The middle position
  this spec assumes: pages stay self-contained prose, and the viewer's navigation is *additive*
  (tree, search, "explain this row"), not a licence to start splitting guides into fragments.
- **"Code never references documentation files."** Ruled on in section 2.2: navigation code is an
  exception, **conditional on a gate** that every hardwired doc id resolves. Without the gate this
  design reproduces the `res://docs/GUIDE-C3-MIGRATION.md` bug in a new form after any guide rename.
- **Freezes.** `EventSheets.open_docs`, `EventSheets.insert_snippet`, `EventSheets.open_online_doc`,
  the doc id scheme, and the `[eventsheet-help v1]` manifest header become compatibility promises the
  moment they ship. **The fence grammar on this list is deliberately three items** under section
  4.7's hybrid recommendation: the ` ```eventsheet ` tag, `<!-- no-figure -->`, and
  `<!-- caption: ... -->`. The automatic layer (auto-detected ` ```gdscript ` fences) freezes
  nothing; anything richer than the three authored markers ships later as an additive comment
  marker, never as a change to them.

### Could not verify - settle these before relying on them

1. **`EditorDock` reveal after `open()`** - `visible_in_tree` was `true` in one headless run and
   `false` in another. Confirm in a real editor before Phase 6.
2. **`meta_clicked` firing for `[url]`** - the signal exists, but a real mouse is needed to confirm
   the click path. Confirm with a non-headless harness in Phase 3.
3. **Whether `goto_help` on a class registered via `update_docs_from_script` renders a *populated*
   page** - no error was raised and a help tab was created, but its contents could not be inspected
   headless.
4. **The residual ~690 ms in the first `set_sheet`** (see Performance).
5. **Per-frame draw cost of N visible figures** (construction cost is now measured and is fine, see
   Performance). Phase 4.
6. **Whether `content_width()` is derivable from `viewport_row_metrics.gd`** or needs a new span pass.
   This decides whether Phase 6 is viable as specified. Settle it in Phase 1.
7. **The 70.9% Tier-0 verb match rate is a lower bound** - the measuring parser counted object-scoped
   expression forms (`LootBox.Roll Item`) as misses. The order of magnitude - roughly a third of
   figure lines are prose by design - is solid; the exact number is not.
8. **Pipe tables inside fenced blocks** - `docs/GUIDE-EDITOR-TOOLS.md:141` contains fenced console
   output that is itself pipe-delimited (`common | 59.70% | 60.00% | -0.30%`). The parser must not
   table-ify fence contents. Fixture this.

### Open questions for the user

- **The big one, section 0.3:** is a native Markdown page worth 30%-of-commits maintenance over
  `OS.shell_open` to a tag URL? Live figures inside guides are the only answer a browser cannot give.
- Mockup palette or editor palette for figures (section 3.9)? This spec recommends the editor
  palette with mockup-slate as a pickable preset, but the call should be made against a preview image.
- Should the 72 addon guides **move** to `eventsheet_addons/<pack>/guide.md` (one source, packs own
  their docs, README links change) or be **mirrored** there by the build step? This spec assumes
  mirrored; a move is cleaner long term, and note that `docs/Addons/` ships in neither zip today.
- Is a curated handful of images worth shipping after all (for example the 8 `docs/previews/` PNGs at
  1.7 MB), or do live figures fully replace them?
- Should the viewer become the **default** target of the doc links in `README.md`'s "Quick start", or
  stay an in-editor alternative to reading on GitHub?

---

## 7. The tests

All tests are suite-discovered: a script in `tests/` with `static func run() -> bool`
(`tests/run_tests.gd` auto-discovers, and a parse-broken file now fails loudly via `can_instantiate()`
rather than vanishing).

**Where the gate lives matters.** `.github/workflows/ci.yml:47-54` runs `run_perf.gd`,
`project_doctor.gd` and `run_tests.gd`. **`tools/audit_addons.gd` is NOT in CI** - so the precedent
the first draft cited for gating the bundle is local-and-manual only. **The bundle's byte-identity
check must therefore live in `tests/doc_library_test.gd`** (suite-discovered, therefore in CI);
`tools/build_help_bundle.gd --check` is a convenience wrapper for local use, not the gate.

**Non-negotiable verification discipline for every phase:**

- Check the literal verdict line - `All tests passed.` or `Some tests failed.` A crashing test
  produces **zero** `[FAIL]` lines, so grepping for FAIL is a false green.
- **Never write `_check(a and b, expected_string)`** - `bool == String` is a runtime error in
  GDScript and triggers exactly that silent failure.
- **Pin VALUES, not counts.**
- A tail segfault *after* the verdict line is a known harmless teardown flake.
- Anything constructing UI guards on `DisplayServer.get_name() == "headless"` so the suite never pops
  a window (precedent: `editor/dock/welcome_window.gd:29`).

### 7.1 What the headless suite CAN pin

| Phase | Test | What it pins |
|-------|------|--------------|
| 1 | `tests/doc_figure_view_test.gd` | `content_height()` equals `ViewportRowMetrics.total_height()`; figure mode drops the footer strip (a known fixture measured 419.0 with footers and 389.0 without); figure mode ignores the 240 px height floor **and the 640 px width floor** (pin `custom_minimum_size.x < 640.0` in a 300 px host - it is (640, 509) today); an empty sheet is refused (guarding `is_sheet_visually_empty()` and its clickable CTA rects); `apply_editor_style(mockup)` yields `object_label_color == Color(0.847059, 0.639216, 0.352941)`. |
| 1 | existing suite | `tests/ui_scale_test.gd` and `tests/style_guide_test.gd` stay green on the new files. |
| 2 | `tests/doc_explain_test.gd` | A known `{provider_id, ace_id}` produces a block list whose heading is that verb's `display_name`, whose body contains its `description`, and whose "ships as" line contains its `codegen_template`. A section id produces `EventSheetSectionInfo.description_for(name)` verbatim. Pin the strings. |
| 2 | `tests/doc_viewer_test.gd` | The browser constructs headless behind the `DisplayServer` guard; `EventSheets.open_docs` with an unknown id returns `false` rather than erroring; `EventSheets.insert_snippet` with no sheet open returns `false` and does not error. |
| 3 | `tests/doc_markdown_test.gd` | Pinned values: `slug("3. How it runs - File > Run, editor vs game") == "3-how-it-runs---file--run-editor-vs-game"`; `slug("8. The codegen_template language") == "8-the-codegen_template-language"`; `**a**` -> `[b]a[/b]`; a literal `[` -> `[lb]`; a 3-column pipe table -> 3 headers and N row arrays; a pipe-delimited line **inside** a fence stays a code line. |
| 3 | `tests/doc_library_test.gd` | Every shipped page id resolves to a readable file; **the bundle is byte-identical to its `docs/` sources** (this is THE drift gate); every in-page anchor resolves to a heading slug in its own page (**316 of 316** resolve today over the 39 guides); every cross-file link is either a shipped id or a real on-disk file in the `external_known` class (**64 shipped + 4 external_known = 68** today), and a link that is neither **fails**; every doc id hardwired in an `open_docs("...")` / `open_online_doc("...")` literal under `addons/` resolves. |
| 3 | drift, convenience | `--script tools/build_help_bundle.gd --check` prints `help: pages=N drifted=0`. Regeneration must be byte-stable: verify by hashing `addons/eventsheet/help/` across two runs, never with `git stash`. |
| 3 | perf | Parsing the whole shipped bundle stays under a stated budget (about 100 ms is the measured shape: 49 ms for all 111 files today). Three runs at HEAD before blaming a diff. |
| 4 | `tests/doc_figures_test.gd` | **Detector proved first**: a good Tier-1 fixture passes, a header-less fixture fails, a Tier-2 fixture with a bogus `ace_id` fails. **Then sweep**: every Tier-1 body satisfies `round_trips(body) == true` **and** lifts to at least one non-`RawCodeRow` row; every Tier-2 fence deserializes and every `{provider_id, ace_id}` resolves in the live registry. |
| 4 | `tests/doc_figures_test.gd` | Prelude cropping: a body starting `extends CharacterBody2D` displays without that row by default and with it under `full`; cropping never changes what the gate ran on. |
| 5 | `tests/doc_library_test.gd` | A pack folder carrying `guide.md` appears in the tree; a pack without one does not; the derived `## ACE reference` names exactly the verbs the live registry offers for that pack. |
| 5 | `tests/doc_search_test.gd` | Ranked search is a pure static function: a query matching a title outranks the same query matching body text; a subsequence match ranks below a substring match. Pin the ordering, not the score. |
| 6 | `tests/plugin_boot_lazy_test.gd` | `EventSheetDocDock` / `EventSheetDocBrowser` added to `FORBIDDEN["res://addons/eventforge/plugin.gd"]`; the dock script path added to `LAZY_PATHS`. |

### 7.2 What the headless suite CANNOT pin (do not write these as tests)

The first draft listed figure-mode process suppression among the things `doc_figure_view_test.gd`
pins. **It is not reachable in this suite.** Existing viewport tests never enter the scene tree
(`tests/hit_test_test.gd:13-26` constructs the viewport and calls methods directly), and under
`--script` the SceneTree's `_init` runs before the tree exists - probe: a plain `Control` added under
`get_root()` reported `is_inside_tree() == false`, `_ready` never ran, and the viewport reported
`is_processing() == false` regardless of the flag. A test written for it silently asserts nothing and
reads as covered.

| Claim | Confirmed by |
|-------|--------------|
| Figure mode actually suppresses `_process` after `_ready` | non-headless preview harness (print `is_processing()` after tree entry) |
| A figure ignores clicks, hover, right-click and Ctrl+wheel | non-headless harness, by hand |
| A figure draws correctly at the chosen palette and scale | the rendered preview image (house rule) |
| An in-page anchor jump lands on the right heading | non-headless harness (Control positions are 0 without layout) |
| `meta_clicked` fires for `[url]` | non-headless harness, real mouse |
| `EditorDock` reveal after `open()` | a real editor |

**Preview images (house rule):** each UI phase lands with a rendered preview from a temp
`tools/render_docs_*_preview.gd` harness run **non-headless** (headless cannot render; set
`root.gui_embed_subwindows = true` for dialogs), shown to the user, and the harness deleted before
committing. Precedent: the ~40 existing `tools/render_*_preview.gd` scripts. Phase 3's preview must
be taken at a **narrow** window width, to catch the sizing trap in section 3.8.

---

## Appendix A - findings that were raised and DISPROVED or corrected against the reviewer

Recorded so a later reader does not re-litigate them.

- **"143 of 143 cross-file links resolve" (first draft) and "67 of 68" (review) are both wrong.**
  Measured over the 39 shipped guides: 68 cross-file `.md` links, **4** of which point outside the
  shipped set - `../EVENTSHEETS-VOCABULARY.md` (1), `../README.md` (1), `Addons/README.md` (2). The
  review's proposed fix (generate a vocabulary page into the bundle) would fix only 1 of the 4. Hence
  the `external_known` link class in section 3.7.
- **"Phase 1 depends on Phase 3" - false.** Phase 1 involves no Markdown, no corpus and no library.
  Its real risk is the 640 px width floor, which is now section 3.2.
- **"`docs/README.md` links 37 of 39 guides across seven groups" - wrong twice.** It links all 38
  (every `docs/*.md` but itself) across **nine** groups. Section 3.6.
- **"Creating a figure costs about 16 ms fixed" - wrong.** That measurement included cold registry
  warm-up. Warm, it is ~1.5-1.8 ms and scales linearly to 16 figures. The proposed pooling machinery
  is likely unnecessary; section 6.
- **"`companion_mode` plus unconnected signals plus `focus_mode = NONE` makes a figure inert" -
  insufficient.** Verified: `mouse_filter` defaults to `STOP`, `handle_mouse_button` calls
  `grab_focus()` unconditionally on right-press (`viewport_input.gd:122`) and zooms on Ctrl+wheel
  (:102-110), and `_ready` (:270-273) re-enables processing. Section 3.3.
- **"`scroll_to_paragraph(i)` implements in-page anchors" - a no-op in this architecture.**
  Section 3.7.
- **"welcome_window.gd:160 is the only shipped broken doc link" - true only within `addons/`.** The
  plugin zip also ships `README.md` with 29 dead relative `docs/` links. Section 1.3.
- **"`@ace_help` already exists as a source" - it exists as an emitted/lifted URL field with zero
  editor consumers.** Section 2.6.
- **"`tools/audit_addons.gd` is the precedent gate" - it is not in CI.** Section 7.

## Appendix B - out-of-band repo note (not a spec finding)

During review, `eventsheet_addons/health/health_behavior.gd` was found overwritten with a 27-line
ACE-annotation fixture (banner `# AUTO-GENERATED by EventForge v0.16.0` with an empty `Source:` line)
instead of the committed 524-line `SimpleHealthBehavior`, and was restored with
`git checkout --`. The working tree's untracked set also changed during the session, so another
session was writing to this tree concurrently (the current untracked set is translation-feature work).

Two things to check before trusting the tree, neither of which this spec touches:

1. whether that revert stomped concurrent in-progress work;
2. **whether some test or tool writes an annotation fixture over a real shipped pack path.** The
   standing project trap is that annotation round-trips must write to `user://`, never into
   `eventsheet_addons/` - a test that does this silently breaks `tools/audit_addons.gd`'s `drifted=0`
   gate for whoever runs it next.
</content>
