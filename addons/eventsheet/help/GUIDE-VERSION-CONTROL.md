# Version Control for Event Sheets

By default an event sheet is a plain **`.gd`** file - it diffs and merges like any source code, no tooling required. Legacy **`.tres`** sheets are Godot resources that diff and merge like serialized resource soup - noisy and, on a real conflict, effectively unmergeable. Three tools make those `.tres` sheets behave like first-class, team-friendly source (the `.gd` default already is): byte-stable regeneration, a readable-diff filter, and a semantic merge driver.

![The same sheet you edit visually is a plain .gd file underneath - so a pull request diff is readable GDScript that reviewers can read line by line without opening Godot](previews/editor-event-sheet.png)

## Table of Contents

1. [LF and Byte-Stable Regeneration (Automatic)](#1-lf-and-byte-stable-regeneration-automatic)
2. [Readable Diffs via textconv](#2-readable-diffs-via-textconv)
3. [Semantic 3-Way Merge (Opt-In)](#3-semantic-3-way-merge-opt-in)
3b. [Showing a Sheet to Someone Who Is Not in the Editor](#3b-showing-a-sheet-to-someone-who-is-not-in-the-editor)
4. [Use Cases](#4-use-cases)
5. [Tips and Common Mistakes](#5-tips-and-common-mistakes)

---

## 1. LF and Byte-Stable Regeneration (Automatic)

Sheets are written with **Unix line endings on every platform** - that is Godot's own convention, and
it is what byte-identical regeneration depends on. The pack and showcase builders stamp
**deterministic row UIDs** on top of it, so regenerating an unchanged sheet reproduces it byte for
byte: no spurious diff churn, and every row has a *stable identity* that diff and merge can key on.

Git can quietly undo that. With `core.autocrlf=true` - what the Windows installer offers by default -
git rewrites text files to CRLF as it writes them into your working tree, the next save takes those
endings back out, and a one-row change arrives in review as a diff touching every line. Worse, two
people whose git is configured differently produce different bytes from the same edit, so merge
conflicts become routine instead of rare.

The Project Doctor raises a **note** when nothing in `.gitattributes` pins how `.gd` files are
stored, and shows the one line that settles it for every contributor on every platform:

```
*.gd text eol=lf
```

Commit that line and no machine's own setting matters any more. EventSheets never writes git
configuration - not `.git/config`, not `.gitattributes` - so this is a line you put in your own diff.

---

## 2. Readable Diffs via textconv

`git diff` can render a `.tres` sheet as legible event text instead of resource soup.

```sh
git config diff.eventsheet.textconv "tools/sheet_diff.sh"
```

`.gitattributes` already maps `*.tres diff=eventsheet`. Now `git diff`, `git log -p`, and PR views show `EVENT … / IF … / DO …` lines via `EventSheetTextDump`.

---

## 3. Semantic 3-Way Merge (Opt-In)

A custom **merge driver** merges sheets at the **row level**, keyed on the stable UIDs. Two people editing *different* rows merge cleanly; only a genuine same-row edit becomes a conflict (and even then both versions are kept, fenced by `⚠ MERGE CONFLICT` comment rows, so you resolve it by deleting the wrong one in the editor - no broken `.tres`).

**Activate it (once per clone - merge drivers live in `.git/config`, which isn't committed):**

```sh
git config merge.eventsheet.name   "EventSheets semantic merge"
git config merge.eventsheet.driver "tools/sheet_merge.sh %O %A %B %P"
```

`.gitattributes` maps the sheet folders to `merge=eventsheet`. Add your own project's sheet folder the same way, e.g.:

```gitattributes
my_game/sheets/**.tres merge=eventsheet
```

Until the driver is configured, git just falls back to its default merge, so the attribute is harmless on a fresh clone.

### What it merges vs what stays a conflict

| Merges cleanly | Kept as a conflict (for review, exit code 1) |
| --- | --- |
| **Rows** (events/groups) by UID; uid-less rows (comments, raw blocks) by content | The same row edited differently on both sides |
| **Variables** 3-way per key; **functions** 3-way by name | A row deleted on one side and edited on the other |
| **Sheet scalars** (host class, class name) and **includes** (union) | The same variable/scalar changed to two different values |

Both sides are preserved in the merged sheet so nothing is lost - open it and keep the right one. Run the headless suite's `sheet_merge_test` for the exact behaviours that are guaranteed.

### A file with markers in it opens read-only

A `.gd` sheet merges like any source code, which means a genuine same-line conflict comes back the
way every source conflict does - `<<<<<<<`, `=======`, `>>>>>>>`. A file in that state is not
GDScript, so EventSheets does not try to read it as one sheet: **it opens read-only**, with nothing
lifted into rows, Save off, and a banner at the head naming the exact lines the markers are on.

![A .gd still holding merge markers, open read-only: the head banner names the marker lines and says the merge is finished in the tool it was started in, the file shows as verbatim Script blocks, and below it the Project Doctor's inbox row for two rows declaring the same baked local, with its one Re-mint chip](images/merge-guards.png)

There is no "open anyway". Finishing a merge means choosing between two people's work with the whole
history in view, and the tool that has that view is the one the merge was started in - the banner
says so. The guard is **textual and total**: any marker line anywhere blocks the file, including the
leftovers a half-finished resolution produces (a stray `>>>>>>>`, an interrupted rebase's
`|||||||`), which are exactly the files that otherwise look fine until something saves over them.

### Reading the two sides, as events rather than as marker lines

**Show the conflicts** on that banner opens the **conflict view**, which shows each conflicted region
as **OURS** and **THEIRS** columns of events side by side.

![A conflicted file open in the conflict view: the region heading names the two sides the merge wrote (HEAD against feature/jump), the event both sides left alone is greyed and marked "both the same", and the one event that differs carries its own Keep ours / Keep theirs / Keep both](images/conflict-view.png)

- Events **both sides agree on are greyed** - there is nothing to decide about them.
- Every differing event gets its own **Keep ours** / **Keep theirs** / **Keep both**.
- The rest of the file is not shown here at all, because it is not in question.

**Save resolved file** writes the file back with the markers gone and **every byte outside the
conflicted region exactly as it was** - a file with one conflict in it never comes back with the rest
of it reformatted. A region you do not answer keeps its markers, untouched, so a half-finished
resolution is still a file you can come back to.

The Project Doctor reports any file still holding markers as an **error**: it does not compile, and
the worst moment to discover that is when the game will not start.

### After the markers are gone: two rows declaring the same local

Some verbs declare a local of their own - a peer, a spawned node, a timer accumulator - and the row
bakes a short token into that name when you add it, so two copies of the same row never collide:
`__peer_a3f81c02`. A fresh token is drawn against **every token the project's own scripts already
hold**, not just the ones minted since the editor started, which means an ordinary day of work can
never produce two the same.

A merge can. Two branches mint in parallel, both rows come in, and the file now declares one name
twice in one scope - which Godot refuses to parse, loudly, the moment anything touches it. The
Project Doctor names it before that happens:

> Two rows both declare `__peer_a3f81c02` in `_ready` (lines 7, 10). Godot refuses a file that
> declares one name twice, so this will not run - it is two branches that minted the same token and a
> merge that brought both in. Re-mint one of them and both rows go on working.

The finding carries one chip, **Re-mint one of them**. The row that was already in the file keeps the
name it had; the row the merge brought in gets a name of its own, across every baked field of that
row at once. Both rows go on reading and compiling exactly as they did - the only thing that moves is
eight hex digits in a name nobody types - and it is an ordinary edit in the sheet's own undo history,
so Ctrl+Z puts it back.

---

## 3b. Showing a Sheet to Someone Who Is Not in the Editor

A diff answers "what changed"; a review comment, a design document, a bug report or a lesson often
needs "what does this sheet SAY". **Sheet ▸ Export** writes the canvas exactly as it is being read -
the current theme, density, arrangement and reading lenses, with the event numbers on, so the
picture and the reader's screen agree:

- **Image (PNG)…** - the whole sheet as one picture. What you paste into a forum post or an issue.
- **PDF…** - that same picture split into pages, for a document somebody prints or annotates.
- **Markdown with figures…** - the plain listing, with a figure per group. This is the one to
  commit beside a sheet: it diffs as text, and it still shows the rows.

Nothing about the sheet changes and nothing is written next to it - the export is a file you choose
the location of, and the `.gd` is untouched.

**Sheet ▸ Health…** answers the other review question, about the sheet rather than about the change:
one card saying how much of the file reads as events, which patterns it contains and which of them a
shipped behavior could take over, what the Doctor says about it, which Test Sheets cover it and how
they last went, and how much of it nothing uses. Every line clicks through to the panel it came
from, so a health card is a starting point for the work rather than a score.

<img src="images/sheet-health-card.png" alt="The health card for player.gd: reads as events 100% with 4 patterns and 2 adoptable, Doctor 0 errors and 2 notes, tests 3 Test Sheets with the last run green, and unused 1 thing." width="450">

---

## 4. Use Cases

### 1. Reviewing a sheet PR as code

A sheet IS its `.gd`, so the pull request diff is readable GDScript - reviewers see exactly what logic changed without opening Godot.

### 2. Two people edit one sheet

The semantic 3-way merge resolves both edits by row identity instead of line position, so parallel work on different events merges clean.

### 3. Bisecting a gameplay bug

`git bisect` over sheet history works like any code history - each commit is a compiling script you can run.

### 4. A quiet diff after regeneration

Deterministic emission plus stable row uids mean re-saving an unchanged sheet produces a ZERO-line diff - regeneration never pollutes the blame.

### 5. A game-jam branch race

During a 48-hour jam two teammates fork off `main` to build the boss fight and the pause menu on separate sheets. Because unchanged sheets regenerate byte-identically, neither branch carries phantom churn, so the final merge back is a small, honest diff instead of a wall of resource-soup noise nobody has time to read.

### 6. A cherry-pick to the release branch

You land a coin-pickup fix on `main` but the shippable build is frozen on `release/1.0`. `git cherry-pick` lifts just that commit across, and because the sheet is plain GDScript the picked change applies as a clean textual patch rather than a serialized-resource blob that refuses to graft.

### 7. Blaming a broken enemy spawn

QA reports the wave timer fires twice. `git blame` on the sheet's `.gd` points straight at the row - and thanks to the textconv filter on any legacy `.tres`, even the historical revisions read as `EVENT / IF / DO` lines, so you can trace who last touched that spawn logic without checking out each commit into Godot.

### 8. A designer and a programmer on the same sheet

A designer retunes the `enemy_speed` variable while a programmer rewrites an unrelated collision event in the same sheet. The semantic merge resolves variables 3-way per key and events per UID, so the two changes land together cleanly - the designer never has to learn conflict markers to keep balancing numbers.

### 9. Enforcing byte-stability in CI

Your pipeline runs the pack builders and fails the build if any regenerated sheet shows a diff. Because emission is deterministic with no timestamps or randomness, a dirty working tree after regeneration is a real, reviewable change every time, so a green CI run is a trustworthy guarantee that committed sheets match their generators.

## 5. Tips and Common Mistakes

- **The merge driver is per-clone.** Merge drivers live in `.git/config`, which isn't committed - run the two `git config merge.eventsheet.*` commands once on every fresh clone.
- **The attribute is harmless before setup.** Until the driver is configured, git just falls back to its default merge, so `.gitattributes` can ship the mapping safely.
- **Add your own sheet folders to `.gitattributes`.** The bundled mapping covers the plugin's sheet folders; map your project's own folders (e.g. `my_game/sheets/**.tres merge=eventsheet`) the same way.
- **A conflict never loses work.** Both versions are kept in the merged sheet, fenced by `⚠ MERGE CONFLICT` comment rows - resolve by deleting the wrong one in the editor, never by hand-editing broken `.tres`.
- **No churn means no noise.** Deterministic row UIDs make regenerating an unchanged sheet byte-identical, so a regeneration commit that shows diffs is a real change, not noise.
- **Prefer `.gd` sheets.** The default `.gd` format already diffs and merges like ordinary source code; all of the tooling above exists for legacy `.tres` sheets.
