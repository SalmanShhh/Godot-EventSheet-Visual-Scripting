# Version Control for Event Sheets

By default an event sheet is a plain **`.gd`** file - it diffs and merges like any source code, no tooling required. Legacy **`.tres`** sheets are Godot resources that diff and merge like serialized resource soup - noisy and, on a real conflict, effectively unmergeable. Three tools make those `.tres` sheets behave like first-class, team-friendly source (the `.gd` default already is): byte-stable regeneration, a readable-diff filter, and a semantic merge driver.

![The same sheet you edit visually is a plain .gd file underneath - so a pull request diff is readable GDScript that reviewers can read line by line without opening Godot](previews/editor-event-sheet.png)

## Table of Contents

1. [LF and Byte-Stable Regeneration (Automatic)](#1-lf-and-byte-stable-regeneration-automatic)
2. [Readable Diffs via textconv](#2-readable-diffs-via-textconv)
3. [Semantic 3-Way Merge (Opt-In)](#3-semantic-3-way-merge-opt-in)
4. [Use Cases](#4-use-cases)
5. [Tips and Common Mistakes](#5-tips-and-common-mistakes)

---

## 1. LF and Byte-Stable Regeneration (Automatic)

`.gitattributes` enforces LF, and the pack/showcase builders stamp **deterministic row UIDs**, so regenerating an unchanged sheet is byte-identical - no spurious diff churn, and every row has a *stable identity* that diff and merge can key on.

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
