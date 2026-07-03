# Version Control for Event Sheets

By default an event sheet is a plain **`.gd`** file - it diffs and merges like any source code, no
tooling required. Legacy **`.tres`** sheets are Godot resources that diff and merge like serialized
resource soup - noisy and, on a real conflict, effectively unmergeable. Three tools make those `.tres`
sheets behave like first-class, team-friendly source (the `.gd` default already is):

## 1. LF + byte-stable regeneration (automatic)
`.gitattributes` enforces LF, and the pack/showcase builders stamp **deterministic row UIDs**,
so regenerating an unchanged sheet is byte-identical - no spurious diff churn, and every row
has a *stable identity* that diff and merge can key on.

## 2. Readable diffs (textconv)
`git diff` can render a `.tres` sheet as legible event text instead of resource soup.

```sh
git config diff.eventsheet.textconv "tools/sheet_diff.sh"
```

`.gitattributes` already maps `*.tres diff=eventsheet`. Now `git diff`, `git log -p`, and PR
views show `EVENT … / IF … / DO …` lines via `EventSheetTextDump`.

## 3. Semantic 3-way merge (opt-in)
A custom merge driver merges sheets at the **row level**, keyed on the stable UIDs. Two people
editing *different* rows merge cleanly; only a genuine same-row edit becomes a conflict (and
even then both versions are kept, fenced by `⚠ MERGE CONFLICT` comment rows, so you resolve it
by deleting the wrong one in the editor - no broken `.tres`).

**Activate it (once per clone - merge drivers live in `.git/config`, which isn't committed):**

```sh
git config merge.eventsheet.name   "EventSheets semantic merge"
git config merge.eventsheet.driver "tools/sheet_merge.sh %O %A %B %P"
```

`.gitattributes` maps the sheet folders to `merge=eventsheet`. Add your own project's sheet
folder the same way, e.g.:

```gitattributes
my_game/sheets/**.tres merge=eventsheet
```

Until the driver is configured, git just falls back to its default merge, so the attribute is
harmless on a fresh clone.

### What it merges
- **Rows** (events/groups) by UID; uid-less rows (comments, raw blocks) by content.
- **Variables** 3-way per key; **functions** 3-way by name.
- **Sheet scalars** (host class, class name) and **includes** (union).

### What stays a conflict (kept for review, exit code 1)
- The same row edited differently on both sides.
- A row deleted on one side and edited on the other.
- The same variable/scalar changed to two different values.

Both sides are preserved in the merged sheet so nothing is lost - open it and keep the right
one. Run the headless suite's `sheet_merge_test` for the exact behaviours that are guaranteed.
