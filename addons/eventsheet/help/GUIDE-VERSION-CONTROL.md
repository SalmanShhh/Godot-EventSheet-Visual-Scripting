# Version Control for Event Sheets

By default an event sheet is a plain **`.gd`** file - it diffs and merges like any source code, no tooling required. Legacy **`.tres`** sheets are Godot resources that diff and merge like serialized resource soup - noisy and, on a real conflict, effectively unmergeable. Three tools make those `.tres` sheets behave like first-class, team-friendly source (the `.gd` default already is): byte-stable regeneration, a readable-diff filter, and a semantic merge driver.

![The same sheet you edit visually is a plain .gd file underneath - so a pull request diff is readable GDScript that reviewers can read line by line without opening Godot](previews/editor-event-sheet.png)

## Table of Contents

1. [LF and Byte-Stable Regeneration (Automatic)](#1-lf-and-byte-stable-regeneration-automatic)
2. [Readable Diffs via textconv](#2-readable-diffs-via-textconv)
3. [Semantic 3-Way Merge (Opt-In)](#3-semantic-3-way-merge-opt-in)
3b. [Showing a Sheet to Someone Who Is Not in the Editor](#3b-showing-a-sheet-to-someone-who-is-not-in-the-editor)
4. [Checking the Contracts from a Command Line](#4-checking-the-contracts-from-a-command-line)
5. [Working on This as a Team](#5-working-on-this-as-a-team)
6. [Use Cases](#6-use-cases)
7. [Tips and Common Mistakes](#7-tips-and-common-mistakes)

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

## 4. Checking the Contracts from a Command Line

The promises this plugin makes are not documentation. They are properties of the files sitting in
your repository, and every one of them can be checked without opening Godot:

```sh
godot --headless --path . --script tools/verify_sheets.gd
```

It reads your project without writing a byte of it, and it exits 0 or 1. Four checks, each one
sentence of the contract spelled out:

| Check | The sentence it is | What a failure means |
| --- | --- | --- |
| `parses` | Every file is valid GDScript | A file nothing loads. Merge markers are named as themselves, with their line numbers |
| `round-trip` | Opening a file as a sheet and saving it untouched reproduces it byte for byte | Saving that file from the editor would change a byte somebody did not ask to change |
| `duplicate-local-token` | No scope declares one baked local twice | Two branches minted the same token and a merge brought both in. Godot refuses the file |
| `migration-asks` | The migration report holds no row waiting on a human | A row whose verb has moved and whose rewrite nobody can make for you |

A failure prints one line in the shape every compiler prints one, so a terminal that turns those into
links does:

```
res://player.gd:41 [duplicate-local-token] Two rows both declare __peer_a3f81c02 in _ready (lines 38, 41). Godot refuses a file that declares one name twice, so this will not run - it is two branches that minted the same token and a merge that brought both in. Re-mint one of them and both rows go on working. Project Doctor lists this line with one chip on it, Re-mint one of them, and the re-mint is an ordinary undoable sheet edit.
verify: 214 file(s) read, 1 failure(s).
```

Every line ends by naming the place in the editor that shows the same thing, because the fix is
made there and not here.

**Hand it paths and it reads exactly those** - which is what makes it usable from a hook:

```sh
godot --headless --path . --script tools/verify_sheets.gd -- player.gd sheets/enemy.gd
```

Paths are accepted the way git prints them (relative to the repository root) or the way Godot writes
them (`res://…`); both are the same file. `--skip <prefix>` leaves out everything under a folder, and
exists for one situation: a folder of deliberately broken GDScript kept as test fixtures is the one
thing this gate cannot tell from a real file, so you name it rather than being told your own fixtures
are broken. `--whole` reads the `.gd` half of the fourth check whole instead of sampling it, and the
verdict line says which of the two ran.

### The plugin ships the command, git decides when it runs

Nothing here installs itself. These are files you write, in your own repository, and you can read
every line of them before you do.

**`.git/hooks/pre-commit`** - the staged files only. Measured on this repository, a file costs about
a third of a second on top of the few seconds a headless engine takes to start, so a normal commit's
worth of files is a pause and not a coffee break:

```sh
#!/bin/sh
# The standing contracts, asked of the sheets this commit touches.
GODOT=${GODOT:-godot}
staged=$(git diff --cached --name-only --diff-filter=ACM -- '*.gd' '*.tres')
[ -z "$staged" ] && exit 0
"$GODOT" --headless --path . --script tools/verify_sheets.gd -- $staged
```

**`.git/hooks/pre-push`** - the whole project, which is the last moment before your work is somebody
else's problem. At a third of a second a file this is a minute for a few hundred files, which is why
it belongs here rather than on every commit:

```sh
#!/bin/sh
GODOT=${GODOT:-godot}
"$GODOT" --headless --path . --script tools/verify_sheets.gd
```

Both need `chmod +x`. Hooks live in `.git/hooks`, which is not committed, so this is a per-clone
setup exactly like the merge driver above - and a teammate who has not run it is not blocked by
anything, which is why the same command belongs in CI.

**The CI job** (GitHub Actions here; the shape is the same anywhere). Import first, because a fresh
checkout has no import cache and a project that has not been imported cannot resolve its own classes:

```yaml
- name: Import project
  run: godot --headless --import --path .

- name: The standing contracts
  run: godot --headless --path . --script tools/verify_sheets.gd
```

This repository runs that job on itself, so the recipe is one that has to keep working: see
`.github/workflows/ci.yml`. It runs it TWICE, and the difference is worth knowing because your
project may need the same shape.

The first form is the one above with two `--skip` prefixes on it, because this repository keeps two
folders of GDScript that is not meant to load - `tests/fixtures/`, which is deliberately broken so
the importer can be tested against it, and `tests/corpus/`, which illustrates code the reader is
being shown rather than code that runs. The gate cannot tell either of them from a real file, which
is exactly what `--skip` is for. Everything else in the repository is read, generated content
included.

The second form hands it an explicit list of the generated sheets (`git ls-files 'demo/*.gd'
'eventsheet_addons/*.gd'`), which is the same shape the pre-commit hook uses, and takes seconds
rather than minutes. A project with no fixture folders needs neither variation: the plain command
above reads everything and is the whole gate.

---

## 5. Working on This as a Team

### Everyone is on the same version because the version is a commit

The plugin lives in `addons/` **inside your repository**. There is no per-machine install to keep in
step, so "which version of the editor are you on" is answered by `git log` like everything else: an
update is a commit, it is reviewed in a pull request, and checking out last month's commit gives you
last month's editor along with last month's sheets. A pack you attach is copied into the project the
same way and is your project's code from that moment.

The one thing the plugin remembers about your project across sessions is a single line in
`project.godot`:

```
eventsheets/project/vocabulary_version="0.17.0"
```

It is written when a sheet is saved from the editor, and only when the value would change. Two
branches that disagree about it resolve by taking either side: the value only moves forward, and the
next edit rewrites it. There is no sidecar file, nothing machine-local, and nothing anybody has to
remember to commit.

### The branch gate is two questions

**Does it hold the contracts?** `tools/verify_sheets.gd`, above. Run it in CI and a branch cannot
merge a file that does not parse, will not come back byte for byte, or declares one local twice.

**Is it leaving a decision for somebody else?** The same command's fourth check. **There is no second
command**: `tools/verify_sheets.gd` is the whole gate, and the fourth check is the migration half of
it. The same answer is public inside the editor, as the twin a Tool sheet or an editor plugin reads -
never as the thing CI calls:

```gdscript
for row: Dictionary in EventSheets.migration_report():
	if row["asks"]:
		print("%s event %d still asks: %s" % [row["sheet"], row["row"], row["before"]])
```

That report samples the `.gd` half of the project and says so in the Doctor's summary line;
`EventSheets.migration_report(true)`, or `tools/verify_sheets.gd -- --whole` on a command line, reads
every script instead - the mode for a release check rather than for a hook, because reading a script
means lifting it.

Each row says which sheet and which event, the spelling it is written in and the one it would be
written in, the line it writes today and the line it would write, and whether it **asks**. A row that
does not ask can be rewritten on one click with a receipt in front of you. A row that asks cannot be
rewritten by anything: the vocabulary has nowhere to send it, or the newer verb keeps state of its
own and has to be picked, or the rewrite could not prove it reads back as itself. Landing a branch
full of those moves the decision onto whoever opens the file next, which is what the gate is for.

### A branch that has been open for three weeks

Nothing goes stale and nothing breaks. A verb that has been superseded keeps its id, its template and
its place in the picker permanently, so a sheet written in an older spelling compiles to exactly the
line it always did. **No sheet is ever rewritten when it is opened or when it is saved** - opening a
file and saving it untouched reproduces it byte for byte whatever spellings it holds, which is the
same law the round-trip check asks about.

So a long-lived branch merges as ordinary code. Afterwards the sheet's head shows its one counting
line again, the **Migrate…** door beside it opens the receipt, and you take the rewrite when you want
it rather than when a merge decided for you. If you never take it, nothing is wrong: it compiles, it
runs, and the Doctor's Migration section keeps saying so in one line.

### Reviewing the migration commit itself

A migration is an ordinary edit in the sheet's own undo history, so it arrives in review as an
ordinary diff: the rows that were rewritten, and nothing else. That diff **is** the receipt, and it
reads as code somebody typed rather than as machine output - a rewritten row lands with the values it
carried under their new names and nothing more, so an argument that would only restate what the
callee already declares as its own default is not written. Reviewing it is reviewing GDScript.

---

## 6. Use Cases

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

### 10. A branch that outlived a vocabulary change

A gameplay branch sits open for three weeks while the vocabulary moves on underneath it. Nothing on
it breaks: superseded verbs keep their templates, so every sheet compiles to the line it always did,
and no sheet is rewritten on open or on save. It merges as ordinary code, and afterwards the head
band counts the rows that now have a newer spelling and offers **Migrate…** on your schedule.

### 11. A pull request that will not compile on somebody else's machine

Two people minted the same baked local on parallel branches and the merge brought both in. The file
declares one name twice, which Godot refuses to parse, and it is only refused when somebody opens the
game. The CI job's `duplicate-local-token` check names it on the pull request instead, with the line
numbers and the one chip that fixes it.

## 7. Tips and Common Mistakes

- **The merge driver is per-clone.** Merge drivers live in `.git/config`, which isn't committed - run the two `git config merge.eventsheet.*` commands once on every fresh clone.
- **The attribute is harmless before setup.** Until the driver is configured, git just falls back to its default merge, so `.gitattributes` can ship the mapping safely.
- **Add your own sheet folders to `.gitattributes`.** The bundled mapping covers the plugin's sheet folders; map your project's own folders (e.g. `my_game/sheets/**.tres merge=eventsheet`) the same way.
- **A conflict never loses work.** Both versions are kept in the merged sheet, fenced by `⚠ MERGE CONFLICT` comment rows - resolve by deleting the wrong one in the editor, never by hand-editing broken `.tres`.
- **No churn means no noise.** Deterministic row UIDs make regenerating an unchanged sheet byte-identical, so a regeneration commit that shows diffs is a real change, not noise.
- **Prefer `.gd` sheets.** The default `.gd` format already diffs and merges like ordinary source code; all of the tooling above exists for legacy `.tres` sheets.
- **Hooks are per-clone too.** `.git/hooks` is not committed, so a teammate who has not set them up is not stopped by anything. Put the same command in CI, where it runs for everybody.
- **A file with no newline at its end fails the round-trip check.** Saving it from the editor adds one, which is a byte, which is the law. Adding the newline yourself is the whole fix.
- **A row that asks is not a broken row.** It compiles and it runs. The gate is there so the decision is made by somebody who is looking at the sheet, not by whoever opens it next month.
