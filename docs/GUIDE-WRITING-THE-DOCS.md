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
6. [Learning paths](#learning-paths)
7. [When a guide falls behind its pack - Doctor > Docs](#when-a-guide-falls-behind-its-pack---doctor--docs)
8. [House rules the suite enforces](#house-rules-the-suite-enforces)
9. [Regenerate before you commit](#regenerate-before-you-commit)
10. [Documenting a third-party pack](#documenting-a-third-party-pack)
11. [The verification loop for a docs change](#the-verification-loop-for-a-docs-change)
12. [Common mistakes](#common-mistakes)

## Where docs live, and where they show up

![The Welcome window's documentation link, which opens the guide in a browser at the installed version's tag](images/welcome-documentation-link.png)

Every guide is a Markdown file under `docs/`. The same file is read in three places, and you write
it once:

- **On GitHub**, at full fidelity - images, tables, everything.
- **Inside the Godot editor, in the Manual** - Tools > Manual..., F1, the `?` prefix in the
  command palette, or the Manual dock. The editor draws the Markdown natively: headings on
  a real typographic scale, tables, code blocks, links that stay in the editor. Images are not
  drawn (they show as an alt-text card with a "See this picture online" button), so write alt text
  as if it will be read.
- **From a shipped plugin**, in the browser: `EventSheets.open_online_doc(path)` opens the page
  pinned to the exact installed version, and every "Open the <Pack> guide" button goes through it.

The editor reader does not read `docs/` directly. A build tool copies the guides into
`addons/eventsheet/help/` and writes a manifest, and the suite fails if that bundle is stale.
Section [Regenerate before you commit](#regenerate-before-you-commit) covers the one command.

## The Manual: what a reader gets, and what it derives

![A shipped guide drawn natively at a narrow width: headings on a real scale, tables and code cards, no browser](images/doc-guide-page.png)

![The generated "what does this row do?" page for one row, built from the row itself](images/doc-explain-panel.png)

![The Manual in a dock-width column beside a sheet, its prose still wrapping at the reading measure](images/doc-dock-beside-sheet.png)

![The Manual searched: ranked results grouped by page, beside the open page with every hit wrapped](images/doc-search-results.png)

![The same page after an in-page anchor jump, landed on the section heading the link named](images/doc-guide-anchor.png)

The in-editor reader is called the **Manual**, and it has two halves. Your guides are one of them.
The other is **reference**, and nobody writes it:

| Part of the Manual | Where its pages come from |
|---|---|
| The Manual (first pages) | the tutorials, the icon legend, the glossary for readers coming from another event-sheet editor, the behavior index ("Behaviors, by the name you know"), and What's new - all five generated from the plugin's own tables |
| The guide groups | the Markdown you write, grouped exactly as `docs/README.md` groups it |
| System reference | one page per picker category, listing every condition, action and expression the builtin vocabulary files under it |
| Behavior reference | one page per behavior pack, listing the same for that pack |

![The Manual docked in a narrow column: the search box, a breadcrumb reading Manual then the page, back and forward arrows, Recent and a bookmark star, the icon legend page with its table of marks, and the footer reading Manual v0.17.0, shipped with the plugin, offline](images/manual-docked.png)

That matters when you write a guide, in three ways:

- **You never hand-write a reference table for a pack.** A pack guide's `## ACE reference` section is replaced at
  render time by the live vocabulary, and the behavior reference page is built from it too.
- **A pack with no guide is not a dead link.** Its behavior reference page opens with "No guide yet
  for *Priced Tables* - its conditions, actions and expressions are listed below" and a
  **Write this guide** button that writes the skeleton to `eventsheet_addons/<pack>/guide.md`, which
  the Manual picks up as that pack's page immediately. Fill it in from there.
- **Links to pages that do not exist are drawn muted, never dead**, and a reference page carries no
  "read this online" link at all, because there is no repo file behind it.
- **The behavior index is a table, not a page you edit.** "Behaviors, by the name you know" is
  authored as one Dictionary per behavior in
  `addons/eventsheet/editor/docs/doc_behavior_index.gd` - the name a reader arrives holding, what
  the thing is here (the shipped pack, or the Godot node that already did the job), and what a
  hand-written version of it reads like on a sheet. Each row links to the pack's own reference
  page, and every row is searchable from the one Manual box under the same *glossary* heading the
  word list uses, because "what is 8 Direction called here?" and "what is a layout called here?"
  are the same question. Adding a behavior is adding an entry to that array; the page, the
  anchors, the search rows and the pack links all follow from it.

![A behavior reference page: the breadcrumb reads Manual, Behavior reference, Quest; the page is titled Quest with a line saying it lists the conditions, actions and expressions Quest publishes, an Open the guide link, and one table per kind](images/manual-reference-page.png)

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

### One answer, at three depths

What F1 opens for a row is one page carrying three answers, in this order, because they are the
same answer at three levels of knowing:

1. **the entry** - what the verb is, what it ships as, what it takes;
2. **Taught in** - the section of a written guide that teaches it, with a **Learn more** link that
   lands on that heading rather than at the top of the page;
3. **Filling it in** - the sentences the Parameters dialog puts under each of its fields, so you can
   read them before you open the form.

![A row's F1 page: the entry's description, a Taught in line naming the guide section with a Learn more link, and a Filling it in card carrying one paragraph per field, above the syntax and parameters band](images/row-doors.png)

Nothing in the second or third depth is written twice. The section is found by the Manual's own
ranked search over its own index, so a heading you rename here renames the link with it, and a verb
the guides do not cover simply gets no link rather than one that lands on a page with nothing about
it. The field sentences are read out of the same table the dialog's own foot reads. Which is also
why writing a guide section whose **heading names a verb** is the single most useful thing you can
do for that verb's entry: the heading is what the link lands on.

The Parameters dialog carries the same **Learn more** link at the foot, on the row it is writing.

### Your game is the example gallery

An entry also answers backwards: it says where **your** project already uses the verb, and lists the
rows. Clicking one opens that sheet at that event.

![The foot of the same page: an In your project card reading Used 3 times in your project - open one, with three rows naming the file and line of each use](images/row-doors-project.png)

The walk is made fresh every time the entry is drawn and stored nowhere - a cached count is a count
that is wrong the moment somebody adds a row. Sheets there is a model of (the tabs you have open,
the `.tres` files) are walked exactly, and the `.gd` files nobody has opened are recognised by the
literal runs of the verb's own codegen line, because `.gd` is the default sheet format and lifting
every script in a project would cost seconds at the moment you pressed a key. A verb your project
has never used says so plainly - the absence is the answer, and it is worth knowing.

![Searching the Manual for "wait": the results list tags every row - glossary, System reference, engine reference, guide, behavior reference - and the glossary page is open beside it at the word wait, with the search term highlighted](images/manual-search.png)

**One search box** covers all of it - conditions, actions, expressions, guides, System reference,
behavior reference, the engine's class reference and the glossary - and tags every result with
which of those it is. A vocabulary result also says how many events of the open sheet already use it;
Enter opens it, Ctrl+Enter adds it to the sheet at the caret. A search that finds **nothing** says
*Looking for layout? Here it is called Scene* first, when the word is one the glossary knows, so a
reader never concludes a feature is missing because it is spelled differently here.

![Searching the Manual for layout: the first result row, in the accent colour, reads Looking for layout? Here it is called Scene, the second is Coming from another event-sheet editor, and the ordinary tagged results follow under them](images/manual-search-hint.png)

`/` focuses the search box, Esc gives the sheet its focus back, **A-** and **A+** at the foot of
the page set the Manual's text size, and **Ctrl+F1** reopens the page you were last reading (plain
F1 stays "help for the selected item").

### The fixed shape of a reference page

![A pack guide's reference section drawn from the live registry rather than from the Markdown under it](images/doc-ace-reference.png)

Every reference page - object, module or behavior - prints the same five sections in the same
order, so a reader's eye learns where to land once:

**Properties · Conditions · Actions · Expressions · Triggers**

![A behavior reference page in the fixed shape: the breadcrumb reads Manual, Behavior reference, Health; under the title and its lead line a Properties table lists destroy on death false, invulnerable false and max health 100.0, and a Conditions table follows with a diamond mark in front of every condition](images/manual-reference-shape.png)

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

### One search over everything

![One search over the whole Manual: guides, System and behavior reference and the glossary in one tagged list, with the Engine group at its foot](images/doc-search-engine-group.png)

There is one search box, and it searches everything the reader can reach: your guides, the
generated System and Behavior reference, the tutorials, the dictionary, a pack's own `guide.md`, the
project's own notes, and the engine's class reference. Every result row is **tagged** with what it
is - *guide*, *action*, *System reference*, *engine reference* - so one list can hold all of it
without the reader having to know which half their word lived in.

Two rules decide the order, and knowing them is what makes a guide findable:

- **Where the hit landed outranks how it matched.** A page *titled* after the word beats a page with
  a matching *heading*, which beats a page that merely mentions it in prose. So the words you put in
  a title and in headings are the words your page can be found by - a heading of "Slots, formats and
  when to write" is findable; "Some notes" is not.
- **The plugin's own answers come before the engine's.** An exact hit on a Godot class name still
  sorts under a guide that talks about the same thing in the sheet's own words.

The index is **baked into the shipped bundle** at build time (`search.esdoc`), so a keystroke
searches a table that is already in memory rather than reading three megabytes of Markdown on the
reader's first keypress. That is another derived file the drift check covers: edit a guide, forget
to regenerate, and the suite fails rather than shipping a search over a corpus nobody installed.

**A search never comes back empty.** When nothing matches, the reader gets the nearest sections by
similarity - which is what catches a misspelling or a plural - and under them one row offering to
ask for the page, which opens the tracker with their search already in the title. A blank panel
tells a reader their question was wrong; it is far likelier that the corpus is missing a page, and
that row is how you find out which one.

### The engine's own reference, harvested

Half of what a reader wants explained is not this plugin's vocabulary at all - it is
`global_position`, `queue_free`, `body_entered`. That text already exists and is already correct for
the exact build in front of them, so none of it is written here and none of it is downloaded: the
running binary prints its own class reference (`--doctool`), once, in the background, cached under
`user://` keyed by the engine's version string. Upgrade Godot and the key changes, so the next
harvest is the new engine's text; never upgrade and it never runs again.

It shows up in three places, and in all three it is the same text:

- **F1 on a row whose echo names an engine property** opens the engine's own page for it, at that
  member.
- **Pickers describe built-in methods and signals** with the engine's own sentence, in the same slot
  a script's `##` lines fill for the members you wrote.
- **Search gains an Engine group**, ranked below the plugin's own answers as above.

The engine reference is published under CC BY 4.0, so every surface that shows it shows the line
*Godot Engine documentation, used under CC BY 4.0.* with it, and an exported static site carries the
same line onto any page that quotes it. That is a licence term, not decoration - if you add a
surface that shows engine text, it shows the credit.

### The door swings back

`##` comments are **Godot's own documentation convention**, not something this plugin invented. The
engine renders them in its own class reference for any script with a `class_name`, which is why the
descriptions you write on a sheet's functions - and the ones a pack's `@ace_*` annotations put into
emitted code - are readable in Godot's F1 too, with no export step and nothing written twice.

One convention, two viewers. When you are deciding where a description belongs, that is the answer:
write it as a `##` line on the thing it describes, and both readers get it.

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
- Documenting **builtin vocabulary** (a module under `addons/eventforge/registration/modules/`): the
  module guide that already covers that family - see `docs/Modules/README.md` for the map. A new
  module gets a new guide only if it is a genuinely new topic; usually the new entries join an existing
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
5. **Reference tables** - a table per category, headed `Name | What it does | Ships as` (an
   addon guide may head its tables `Action` / `Condition` / `Expression` / `Trigger` instead,
   when each table holds one kind). The "Ships as" column is the codegen template, the one place
   GDScript is allowed in the prose. Every name in the first column must be the REAL display
   name from the source - a test resolves each one against the live registry and fails on a name
   that does not exist. For addon guides, the reader renders this section from the live registry
   instead of the Markdown, so it can never drift.
6. **Use cases** - **fifteen or more**, numbered, each a real situation with the rows written
   as row sentences (and as a figure fence where they are emitted code - next section). Not
   fifteen rewordings of the same use; a reviewer will flag padding.
7. **Other use cases** - a heading followed by **exactly five** bolded one-liners:
   `**Repair station.** Price a repair entry per use ...`. Exactly five - the test counts.
8. **Tips and common mistakes** - the real traps, taken from the descriptors' own descriptions
   and from what bit you while writing.

`docs/Addons/Quest.md` and `docs/Modules/Comparing-Values.md` are good models. For a new pack,
`tools/scaffold_addon_guide.gd` emits this skeleton pre-filled with the pack's real reference tables.

Keep a guide self-contained: inline the information rather than sending the reader to another
file. Cross-reference a sibling guide by name only when the reader would genuinely search there
next.

## Worked examples that draw themselves - the figure fences

![A bare figure: its caption, the live rows underneath, and the Insert and Try it buttons](images/doc-figure.png)

![A shipped guide whose worked examples render as live, insertable rows in the reader's own theme](images/doc-guide-figure.png)

This is the part that makes writing docs here different. A fenced code block that holds a real
event-sheet example is drawn in the editor as a **live sheet** - the real renderer, in the
reader's own theme, with an Insert button that drops the rows into the open sheet as one undo
step. You get this by writing the example as compilable rows, which you would do anyway.

One recognizer decides per fence, in this order:

1. ` ```eventsheet ` - the **authored** fence. Always a figure. If its body stops compiling, the
   build fails with an error naming the fence - it never silently degrades to a code block. Use it
   when you want a figure the automatic rule would not pick, or when the example must never
   quietly rot.
2. `<!-- no-figure -->` on the line above a fence - the **authored opt-out**. The fence stays a
   plain code block forever. Use it for a `gdscript` fence that would pass the gate but reads better as
   code (an API sample the reader copies into a file, say).
3. ` ```gdscript ` that passes the gate - the **automatic** figure. This is what lights up
   existing guides with no authoring at all.
4. Everything else - a plain code block.

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

Every recognized figure is compiled by the suite (`tests/doc_figures_test.gd`), so an action
renamed under a figure breaks a test instead of a guide. Figure verdicts are baked into the
bundle at build time (a verdict costs a full import and compile), and the suite re-derives every
one live and fails on disagreement.

### The rows land wearing tune-me marks

![A figure and its Add these events button, and the same rows inserted with a dashed mark under every value the example chose](images/doc-figure-tune-marks.png)

Pressing **Add these events** puts a figure's rows into the open sheet, at the caret, as one undo
step. What lands is not quite what a typed row looks like: every literal in it - each number, each
string the example picked - carries a dashed rule underneath, drawn in the same stroke the editor
dashes a fold mark's badge with. That is the whole message of the mark: *these are the example's
values, and they are yours to replace.*

The marks are drawn from the row's own typed-value runs, so a figure does not decide separately what
counts as a value; a reading's muted lead (the `effect.` in front of a shader dial) is skipped,
because nobody retypes that. They live in the pane showing them and nowhere else - a marked row and a
typed row compile to identical bytes, and reopening the sheet clears every mark, which is the honest
state by then.

The **picker's recipe shelf** is the same source seen from the other side: the recipes offered when a
search finds nothing are the guides' figures, derived from the figure store rather than kept in a
list beside it, and inserted through the same guarded path - so a recipe lands marked too.

## Learning paths

![The Manual's Learning paths page: four tracks, each with its blurb, an N of M read line, and one numbered row per page with a Mark read tick beside it](images/doc-learning-paths.png)

A **track** is an ordered reading of guides that already exist - and it is a list in a documentation
index, nothing more. `docs/README.md` carries a `## Learning paths` section; each `### Heading` under
it opens a track, the first line of prose is its blurb, and every link below that is a page, in the
order it should be read. That section is the only place a track is written: the build step reads it
into the bundle exactly as it reads the index's grouped link list into the Manual's tree, and it is
deliberately NOT also a tree group - the pages on a track are already grouped by subject above it,
and listing them twice would read as a bug.

A studio declares its own tracks by writing the same section in its own project's docs index. Same
format, same parser; a track whose title matches a shipped one replaces it.

**Ticks.** Opening a guide ticks it off, and the Learning paths page lets you take the tick back. The
ticks live in a `user://` config - this project, this machine - so they are never committed, never
synced, and never seen by anyone you did not show them to.

**Read next.** A project whose sheets already use a family's vocabulary, on a track whose page its
author has not opened, gets that page suggested once, on the status line, through the same offer
budget the rest of the editor spends. The join runs against the Manual's own baked search index, so
nothing anywhere holds a second opinion about which guide teaches which verb - and a page nothing in
your rows points at is never suggested at all.

## The Common Game Patterns page draws itself from fixtures

One Manual page is not written at all. **Common Game Patterns** (`reference:patterns`, one section
per pattern at `reference:pattern/<pattern id>`) is generated from the files under
`tests/fixtures/patterns/`, one per pattern id in `EventSheetPatternFacts.PATTERN_IDS`:

- the LEFT column is that file printed verbatim,
- the RIGHT column is the very same text handed to the renderer as an `eventsheet` figure.

Because both columns are the same bytes, the page cannot show a shape the sheet does not read: a
reading that broke would make the figure refuse to draw, and the reading test over the same
fixture would already have failed. `Add - Pattern...` opens the same page, and `Adopt behavior`
appears on the sections whose pattern names a shipped behavior.

**To add a pattern to the page**, write `tests/fixtures/patterns/<pattern id>.gd` holding the
smallest complete example of the shape - a whole openable script, passing the style gate like
every other file under `tests/` - and give the id a row in `EventSheetPatternVocabulary.ENTRIES`
(its name, its one-line why, the behavior that could replace it, and how common it is). A pattern
with an entry but no fixture simply has no section, which is the honest answer for a shape nothing
reads yet. Nothing else is edited: the page, the Add menu and the reference pages' "Patterns using
this" all list the same fixtures.

## When a guide falls behind its pack - Doctor > Docs

A pack guide is a copy of something the editor already knows, and copies go stale silently: a
renamed verb leaves a sentence that still reads perfectly. **Tools > Project Doctor** carries a
**Docs** section that compares every pack guide against what its pack publishes, and reports four
kinds of rot:

| What it reports | What it means |
|-----------------|---------------|
| A verb the guide never lists | The pack publishes it and no table names it. A reader who searched the guide concluded it does not exist. |
| A name no verb answers to | The guide names it and nothing answers. Almost always a rename, so the line offers the nearest three verbs that do exist. |
| A description that says nothing | The row is there and its "what it does" cell is blank, a dash, or an unfilled stub. |
| A verb the changelog never mentions | The pack is in `CHANGELOG.md`, so it shipped; this verb of it was never written about anywhere in the ledger. |

None of it fails a build. A guide legitimately documents a verb under a friendlier name than the raw
member, and legitimately leaves plumbing out, so every line is something you decide about.

The same answer is printed by the help-bundle build, under `help: ace reference advisory`. Both ask
one shared reader, so the build log and the page cannot disagree about a guide.

Two of the fixes are worth knowing about before you press them:

- **Stub it in the guide** writes a row for the undocumented verb carrying `TODO: describe what this
  does.`, into a "Not written yet" table at the end of the reference. That row keeps reporting itself
  as a description that says nothing until you replace the placeholder. It is deliberate: a fix that
  wrote a plausible sentence would turn the page green while documenting nothing. It only edits a
  guide this project owns (`eventsheet_addons/<pack>/guide.md`) - a shipped guide under
  `addons/eventsheet/help/` is regenerated from `docs/`, so an edit there would be overwritten.
- **Insert the draft** offers a sentence composed from the verb's own name and parameters. It is a
  starting line, marked as a draft, and never a claim about what the verb does.

The section reads a capped number of guides per audit and always says how many of how many it got
through: outside the editor there is no loaded vocabulary, so every script of every pack has to be
read and reflected, and reading a ninety-guide corpus would add minutes to a pre-commit audit.

## House rules the suite enforces

- **No em-dashes or en-dashes anywhere** in repo text. Write ` - ` (space, hyphen, space).
- **No absolute personal paths** (`C:\Users\<who>\...`, `/home/<who>/`). A test sweeps every
  text file. Write a placeholder or an env var.
- **Every guide is indexed.** Top-level guides by hand in `docs/README.md` under a group, each
  with a one-line description of what the page is; addon and module guides in their directory
  `README.md` and in `docs/README.md`. `tests/docs_integrity_test.gd` reads the folder and fails
  on a `docs/*.md` the index does not list, or lists without a description; unindexed addon and
  module guides fail the shape test.
- **Code never references doc files** - the rule runs the other way too: a guide names menu
  labels, actions and conditions that exist. Do not invent a menu item; the fact-check pass compares against
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

The bundle also carries four derived files the same check covers: `figures.esdoc` (the figure
verdicts), `whatsnew.esdoc` (the What's new page), `dictionary.esdoc` (the call dictionary) and
`search.esdoc` (the baked search index). So **a CHANGELOG edit needs this regeneration too**, not
only a guide edit.

The second command must print `drifted=0`. `tests/doc_library_test.gd` runs the same
comparison in the suite, so a forgotten regeneration fails the build rather than shipping stale
docs. If you added actions, conditions or expressions and they should appear in the generated catalog
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
addon-guide shape above; the reference tables render from the live registry, so a pack
author writes the prose and use cases and the table takes care of itself.

A pack whose docs live elsewhere sets `addon_help_url` (or `@ace_help` on its script) to an
absolute URL; every "Open the <Pack> guide" button then opens that instead of the derived
`docs/Addons/` page. The override always wins over the derivation.

A project can add its own docs folder to the tree through the `eventsheets/project/docs_dir`
setting (default `res://eventsheet_docs`); Markdown there follows the same rules and gets the same
reader.

## The verification loop for a docs change

1. Write or edit the guide. Copy display names from source.
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
- **A display name from memory.** "Set Text (translated)" versus "Set Text (translated pattern)"
  is a failed sweep. Grep the source.
- **Forgetting the bundle.** The suite fails on `drifted=1` and names the page.
- **A typographic dash in a range** (the long dash between two numbers). Write "0-1" with a plain hyphen, or "0 to 1". The sweep catches every long dash, including one quoted as an example - which is why this line does not show you one.
- **A doc link into `docs/internal/`.** It never ships, so the link is dead in the editor.
- **Cross-linking instead of inlining.** A reader in the editor is one click from a page they
  did not ask for; say the thing where they are.
