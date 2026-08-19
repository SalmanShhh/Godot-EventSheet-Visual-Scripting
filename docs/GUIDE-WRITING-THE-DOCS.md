# Writing the Docs

How documentation works in this project, and how to add to it. Everything here is enforced by
something - a test, a build tool, or a reader that draws your words - so it is worth knowing
before you write. Read this once; after that the gates will tell you when you slip.

## Table of Contents

1. [Where docs live, and where they show up](#where-docs-live-and-where-they-show-up)
2. [The three doc sets](#the-three-doc-sets)
3. [Naming a guide](#naming-a-guide)
4. [The shape of an addon or module guide](#the-shape-of-an-addon-or-module-guide)
5. [Worked examples that draw themselves - the figure fences](#worked-examples-that-draw-themselves---the-figure-fences)
6. [House rules the suite enforces](#house-rules-the-suite-enforces)
7. [Regenerate before you commit](#regenerate-before-you-commit)
8. [Documenting a third-party pack](#documenting-a-third-party-pack)
9. [The verification loop for a docs change](#the-verification-loop-for-a-docs-change)
10. [Common mistakes](#common-mistakes)

## Where docs live, and where they show up

Every guide is a Markdown file under `docs/`. The same file is read in three places, and you write
it once:

- **On GitHub**, at full fidelity - images, tables, everything.
- **Inside the Godot editor, in the Manual** - Tools > Manual..., F1, the `?` prefix in the
  command palette, or the Manual dock. The editor draws the Markdown natively: headings on
  a real typographic scale, tables, code cards, links that stay in the editor. Images are not
  drawn (they show as an alt-text card with a "See this picture online" button), so write alt text
  as if it will be read.
- **From a shipped plugin**, in the browser: `EventSheets.open_online_doc(path)` opens the page
  pinned to the exact installed version, and every "Open the <Pack> guide" button goes through it.

The editor reader does not read `docs/` directly. A build tool copies the guides into
`addons/eventsheet/help/` and writes a manifest, and the suite fails if that bundle is stale.
Section [Regenerate before you commit](#regenerate-before-you-commit) covers the one command.

## The Manual: what a reader gets, and what it derives

The in-editor reader is called the **Manual**, and it has two halves. Your guides are one of them.
The other is **reference**, and nobody writes it:

| Part of the Manual | Where its pages come from |
|---|---|
| The Manual (first pages) | the tutorials, the icon legend, the glossary for readers coming from another event-sheet editor, and What's new - all four generated from the plugin's own tables |
| The guide groups | the Markdown you write, grouped exactly as `docs/README.md` groups it |
| System reference | one page per picker category, listing every condition, action and expression the builtin vocabulary files under it |
| Behavior reference | one page per behavior pack, listing the same for that pack |

![The Manual docked in a narrow column: the search box, a breadcrumb reading Manual then the page, back and forward arrows, Recent and a bookmark star, the icon legend page with its table of marks, and the footer reading Manual v0.17.0, shipped with the plugin, offline](images/manual-docked.png)

That matters when you write a guide, in three ways:

- **You never hand-write a verb table.** A pack guide's `## ACE reference` section is replaced at
  render time by the live vocabulary, and the behavior reference page is built from it too.
- **A pack with no guide is not a dead link.** Its behavior reference page opens with "No guide yet
  for *Priced Tables* - its conditions, actions and expressions are listed below" and a
  **Write this guide** button that writes the skeleton to `eventsheet_addons/<pack>/guide.md`, which
  the Manual picks up as that pack's page immediately. Fill it in from there.
- **Links to pages that do not exist are drawn muted, never dead**, and a reference page carries no
  "read this online" link at all, because there is no repo file behind it.

![A behavior reference page: the breadcrumb reads Manual, Behavior reference, Quest; the page is titled Quest with a line saying it lists the conditions, actions and expressions Quest publishes, an Open the guide link, and one table per group of verbs](images/manual-reference-page.png)

The reader's own chrome sits around all of it: a breadcrumb starting at *Manual*, an on-this-page
outline that tracks the scroll, back and forward (Alt+Left / Alt+Right), Recent, a bookmark star, a
reading measure of about eighty characters, a scroll position remembered per page, and
**Next: ...** at the foot of a guide - which is the next page of the group your guide is listed in,
so where you put a page in `docs/README.md` decides what a reader reads after it.

**F1 is "help for the selected item"**, not "open the manual": a condition or action row opens its
entry, an object label opens that object's reference page, a group opens the Manual's page on
groups, and a behavior's Include bar opens that behavior's reference. With the Manual docked,
**Follow selection** does the same thing as you click around, and pauses the moment you click
inside the Manual to read (press the pin again to resume).

![Searching the Manual for "wait": the results list tags every row - glossary, System reference, engine reference, guide, behavior reference - and the glossary page is open beside it at the word wait, with the search term highlighted](images/manual-search.png)

**One search box** covers all of it - conditions, actions, expressions, guides, System reference,
behavior reference, the engine's class reference and the glossary - and tags every result with
which of those it is. A verb result also says how many events of the open sheet already use it;
Enter opens it, Ctrl+Enter adds it to the sheet at the caret. A search that finds **nothing** says
*Looking for layout? Here it is called Scene* first, when the word is one the glossary knows, so a
reader never concludes a feature is missing because it is spelled differently here.

![Searching the Manual for layout: the first result row, in the accent colour, reads Looking for layout? Here it is called Scene, the second is Coming from another event-sheet editor, and the ordinary tagged results follow under them](images/manual-search-hint.png)

`/` focuses the search box, Esc gives the sheet its focus back, **A-** and **A+** at the foot of
the page set the Manual's text size, and **Ctrl+F1** reopens the page you were last reading (plain
F1 stays "help for the selected item").

### The fixed shape of a reference page

Every reference page - object, module or behavior - prints the same five sections in the same
order, so a reader's eye learns where to land once:

**Properties · Conditions · Actions · Expressions · Triggers**

![A behavior reference page in the fixed shape: the breadcrumb reads Manual, Behavior reference, Health; under the title and its lead line a Properties table lists destroy on death false, invulnerable false and max health 100.0, and a Conditions table follows with a diamond mark in front of every verb](images/manual-reference-shape.png)

Each is one table of `Mark | Name | Parameters | What it does`, where the mark is the sheet's own
glyph for that kind (`◆` condition, `➜` action, `ƒ` expression, `⟳` trigger). Properties are a
behavior's designer knobs, read off the pack's own scripts with their defaults - so a knob renamed
in the pack renames on the page, and nobody writes that table either. The last column only appears
when at least one row on the page has something to say in it.

### Tutorials, and the scratch sheet examples run in

![Manual, Tutorials: the tree lists Tutorials, What the marks on a sheet mean, Coming from another event-sheet editor and What's new; the page lists five tutorials, each with a lead line, a time estimate and a Start button](images/manual-tutorials.png)

![One tutorial step card: the page is titled Your first event, a small-caps line reads YOUR FIRST EVENT, step 1 of 6, the step itself sits in a quote card, a line says the named control stays highlighted in the toolbar, and Back, Skip and Next sit on one row above the page foot](images/manual-tutorial-step.png)

**Manual ▸ Tutorials** is the hands-on half: step cards that name a real control, make it pulse in
the toolbar, and complete when the open sheet contains what the step asked for. They are authored
as data in `addons/eventsheet/editor/docs/doc_tutorials.gd` - `{text, control, check}` per step,
where `control` is the EXACT label of a toolbar control and `check` names a pure predicate over the
sheet. Adding a step is adding a Dictionary; adding a new kind of check is one `match` arm.

Every figure in a guide also offers **Try it in a scratch sheet**: the example opens in a tab of its
own, editable, in memory, with no path. Nothing is written to the reader's project unless they Save
As, the tab closes without asking, and it is not restored next session. Write your examples knowing
a reader may be about to play with them rather than only read them.

### What's new

`Manual ▸ What's new` is the repository's own `CHANGELOG.md` - the `[Unreleased]` section and the
last release, and nothing older. It is extracted and baked into the bundle by the build tool (the
CHANGELOG itself does not ship with the plugin), so **editing the CHANGELOG means regenerating the
bundle**, exactly as editing a guide does. A reader who has not opened the page since the plugin's
version changed sees a dot on the Manual entry.

![Manual, What's new: a chapter strip above the page reads UNRELEASED and 0.17.0, the page says what changed in the build you have installed, and the unreleased release notes are rendered under a foldable Unreleased chapter](images/manual-whats-new.png)

### Writing the Manual in another language

The Manual is per locale, page by page: a translated page lives at `docs/<locale>/<same file
name>.md` and the bundle builder walks those folders by directory, the way it walks `Addons/` and
`Modules/`. Nothing is required to exist. A page with no copy in the reader's locale is shown in
English with a one-line *This page is not translated yet - help translate it* note that opens the
folder a translation would go in. There is no machine translation, and there will not be one.

Figures need no translating at all: a figure is real rows drawn by the real renderer, whose words
already go through the plugin's translation domain, so an English page shows a Spanish reader
Spanish rows.

## The three doc sets

| Set | Where | What it is | Discovered how |
|---|---|---|---|
| Guides | `docs/GUIDE-*.md`, `docs/*.md` | Topic guides, references, patterns, migration | listed in `docs/README.md` |
| Addon guides | `docs/Addons/<Title-Case-Words>.md` | One per behavior pack (72 and counting) | by directory |
| Module guides | `docs/Modules/<Title-Case-Words>.md` | One per family of builtin vocabulary (36 over 48 modules) | by directory |

The addon and module sets are discovered as **directories** - nothing lists a guide by name, so a
new guide ships by existing. `docs/internal/` never ships; specs and process notes live there.

Which set a new page belongs to:

- Documenting a **behavior pack**: `docs/Addons/`. Companion resource and loader packs are
  documented inside their partner pack's guide, not as separate pages.
- Documenting **builtin verbs** (a module under `addons/eventforge/registration/modules/`): the
  module guide that already covers that family - see `docs/Modules/README.md` for the map. A new
  module gets a new guide only if it is a genuinely new topic; usually the verbs join an existing
  guide's reference table and use cases.
- Anything else - a workflow, a concept, a migration - is a top-level guide, indexed by hand in
  `docs/README.md` under the group it belongs to.

## Naming a guide

Name the file the way a beginner would **search**, in plain words, Title-Case-Words with hyphens:
`Working-With-Files.md`, `Timers-Waiting-And-Cooldowns.md`, `Priced-Tables.md`. Not the class
name (`FileAces.md`), not jargon (`Persistence-Layer.md`), not an abbreviation.

For a pack, the guide name is DERIVED from the pack directory - `priced_table` becomes
`Priced-Tables.md`, `fps_controller` becomes `FPS-Controller.md` - through
`EventSheets.addon_guide_target()`, with an overrides table for the handful the derivation cannot
reach (plurals, product renames). A test sweeps every pack directory and fails if its guide file
does not exist, so **renaming a guide without updating the mapping breaks the suite**, on
purpose: a renamed guide is a 404 in a shipped plugin otherwise.

Every guide starts with a single `# Title` H1 - the editor uses it as the page title and the
window caption.

## The shape of an addon or module guide

The two directory sets follow one standard, and a test enforces the parts it can:

1. **`# Title`**, then a one-paragraph opener saying what this is for and who it serves.
2. **Where this shines** - the situations it is the right tool for, as short bullets.
3. **Core concepts** - the two to five ideas a reader must hold.
4. **Setup** (addon guides) - how the pack attaches, its Inspector fields as a table.
5. **Verb reference** - a table per category: `Verb | What it does | Ships as`. The "Ships as"
   column is the codegen template, the one place GDScript is allowed in the prose. Every verb
   name must be the REAL display name from the source - a test resolves each one against the
   live registry and fails on a name that does not exist. For addon guides, the reader renders
   this section from the live registry instead of the Markdown, so it can never drift.
6. **Use cases** - **fifteen or more**, numbered, each a real situation with the rows written
   as row sentences (and as a figure fence where they are emitted code - next section). Not
   fifteen rewordings of the same use; a reviewer will flag padding.
7. **Other use cases** - a heading followed by **exactly five** bolded one-liners:
   `**Repair station.** Price a repair entry per use ...`. Exactly five - the test counts.
8. **Tips and common mistakes** - the real traps, taken from the descriptors' own descriptions
   and from what bit you while writing.

`docs/Addons/Quest.md` and `docs/Modules/Comparing-Values.md` are good models. For a new pack,
`tools/scaffold_addon_guide.gd` emits this skeleton pre-filled with the pack's real verb tables.

Keep a guide self-contained: inline the information rather than sending the reader to another
file. Cross-reference a sibling guide by name only when the reader would genuinely search there
next.

## Worked examples that draw themselves - the figure fences

This is the part that makes writing docs here different. A fenced code block that holds a real
event-sheet example is drawn in the editor as a **live sheet** - the real renderer, in the
reader's own theme, with an Insert button that drops the rows into the open sheet as one undo
step. You get this by writing the example as compilable rows, which you would do anyway.

One recognizer decides per fence, in this order:

1. ` ```eventsheet ` - the **authored** fence. Always a figure. If its body stops compiling, the
   build fails with an error naming the fence - it never silently degrades to a code card. Use it
   when you want a figure the automatic rule would not pick, or when the example must never
   quietly rot.
2. `<!-- no-figure -->` on the line above a fence - the **authored opt-out**. The fence stays a
   code card forever. Use it for a `gdscript` fence that would pass the gate but reads better as
   code (an API sample the reader copies into a file, say).
3. ` ```gdscript ` that passes the gate - the **automatic** figure. This is what lights up
   existing guides with no authoring at all.
4. Everything else - a code card.

The gate for the automatic layer, measured over every fence in the corpus and tuned from the
numbers: the body must **round-trip** (lifting it and re-emitting reproduces the fence byte for
byte), must lift to at least one real row (not a wall of verbatim code), and must carry a
**script header** - an `extends` line, the way a sheet's compiled file does. The header is what
separates a worked example (rows a reader would author) from an API sample (code a reader copies
into a file); row count does not discriminate, which is why there is no "two rows minimum".

So: to make an example draw itself, write it as the compiled shape a sheet produces, header
included. To keep an example as code, leave the header off or add `<!-- no-figure -->`.

Captions: a figure's caption is the nearest heading above it, or `<!-- caption: ... -->` on the
line above the fence. The caption comment works above **both** fence kinds, so wanting a caption
never forces converting an automatic figure into an authored one.

The frozen grammar is exactly those three markers - the tag, `no-figure`, `caption`. Nothing
else. Any richer option ships later as an additive marker, never as a change to these three.

Every recognized figure is compiled by the suite (`tests/doc_figures_test.gd`), so a verb
renamed under a figure breaks a test instead of a guide. Figure verdicts are baked into the
bundle at build time (a verdict costs a full import and compile), and the suite re-derives every
one live and fails on disagreement.

## House rules the suite enforces

- **No em-dashes or en-dashes anywhere** in repo text. Write ` - ` (space, hyphen, space).
- **No absolute personal paths** (`C:\Users\<who>\...`, `/home/<who>/`). A test sweeps every
  text file. Write a placeholder or an env var.
- **Every guide is indexed.** Top-level guides by hand in `docs/README.md` under a group; addon
  and module guides in their directory `README.md` and in `docs/README.md`. Unindexed guides
  fail the shape test.
- **Code never references doc files** - the rule runs the other way too: a guide names menu
  labels and verbs that exist. Do not invent a menu item; the fact-check pass compares against
  the real menus.
- **Verb names are real.** Copy the display name from the module source or the pack builder,
  not from memory. The registry sweep fails on a name it cannot find.
- **Images** go under `docs/images/` and are embedded with alt text that stands on its own,
  because the editor reader shows the alt text, not the picture. UI screenshots come from a
  `tools/render_*.gd` harness run non-headless (headless cannot render), and are refreshed
  whenever the UI they show changes.

## Regenerate before you commit

Editing any guide changes the shipped bundle. Regenerate it, then run the drift check:

```
godot --headless --path . --script tools/build_help_bundle.gd
godot --headless --path . --script tools/build_help_bundle.gd --check
```

The bundle also carries two derived files the same check covers: `figures.esdoc` (the figure
verdicts) and `whatsnew.esdoc` (the What's new page). So **a CHANGELOG edit needs this regeneration
too**, not only a guide edit.

The second command must print `drifted=0`. `tests/doc_library_test.gd` runs the same
comparison in the suite, so a forgotten regeneration fails the build rather than shipping stale
docs. If you added verbs and their vocabulary should appear in the generated catalog
(`EVENTSHEETS-VOCABULARY.md`), regenerate that too:

```
godot --headless --path . --script tools/vocabulary_doc.gd
```

Both regenerations are byte-stable: running twice produces identical files, so a diff after
regeneration is exactly your change and nothing else. The release ritual in `CONTRIBUTING.md`
includes both steps.

## Documenting a third-party pack

A pack that lives outside this repo ships its guide **with the pack**:
`eventsheet_addons/<pack>/guide.md`. The reader discovers it the same way it discovers the pack's
`translations.csv` - by being there - and lists it under Packs in the tree. The guide follows the
addon-guide shape above; the verb reference section renders from the live registry, so a pack
author writes the prose and use cases and the table takes care of itself.

A pack whose docs live elsewhere sets `addon_help_url` (or `@ace_help` on its script) to an
absolute URL; every "Open the <Pack> guide" button then opens that instead of the derived
`docs/Addons/` page. The override always wins over the derivation.

A project can add its own docs folder to the tree through the `eventsheets/project/docs_dir`
setting (default `res://eventsheet_docs`); Markdown there follows the same rules and gets the same
reader.

## The verification loop for a docs change

1. Write or edit the guide. Copy verb names from source.
2. `godot --headless --path . --script tools/build_help_bundle.gd` and the `--check`.
3. `godot --headless --path . --script tests/run_tests.gd` - and read the literal verdict line
   `All tests passed.`; a crashed test prints no `[FAIL]` at all. The docs tests that matter here
   are `doc_library_test` (bundle drift, links, anchors), `doc_figures_test` (every figure
   compiles), `module_guides_test` and the addon guide-path sweep (naming, shape, indexing).
4. Open the page in the editor once - Tools > Manual... - and look at it. A table with a
   pipe in a cell, a nested fence, or a heading that should have been a figure caption shows up
   there and nowhere else.
5. If you changed a UI screenshot's subject, re-render it from its harness.
6. Commit the guide, the regenerated bundle, and any regenerated catalog together, with a
   `CHANGELOG.md` line if the change is user-visible.

## Common mistakes

- **Writing an example as prose or as a plain code fence and wondering why it is not a figure.**
  Automatic figures need the compiled shape with its `extends` header, and must round-trip.
  Write ` ```eventsheet ` when you want to be sure - a failing authored fence tells you why.
- **Fourteen use cases, or six "Other use cases".** The counts are exact and tested.
- **A verb name from memory.** "Set Text (translated)" versus "Set Text (translated pattern)"
  is a failed sweep. Grep the source.
- **Forgetting the bundle.** The suite fails on `drifted=1` and names the page.
- **A typographic dash in a range** (the long dash between two numbers). Write "0-1" with a plain hyphen, or "0 to 1". The sweep catches every long dash, including one quoted as an example - which is why this line does not show you one.
- **A doc link into `docs/internal/`.** It never ships, so the link is dead in the editor.
- **Cross-linking instead of inlining.** A reader in the editor is one click from a page they
  did not ask for; say the thing where they are.
