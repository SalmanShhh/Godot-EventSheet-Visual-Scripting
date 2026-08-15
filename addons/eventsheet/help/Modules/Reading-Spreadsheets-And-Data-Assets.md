# Reading Spreadsheets And Data Assets

Two pipelines that answer the same question - "where does my game's content live, if not in a wall of
rows?" - plus the verbs that tell you why a load went wrong.

The first pipeline is **a designer edits a spreadsheet**. **Table From File** reads a `.csv` whose
first line is the column names and hands back one record per row, every field reachable as
`row["price"]`. **Column Of Table** and **Row Where** read one column or one record back out.

The second is **a folder of `.tres` IS my content**. **Resources In Folder** loads every data asset in
a directory as a list, **Resource In Folder** fetches one by file name, and **For Each Resource In
Folder** walks them in the loop lane with no list to maintain.

Around both sit the copy-and-pour verbs (making a private copy of a resource, pouring a preset onto a
node) and three reports that turn a silent failure into a sentence you can print.

These are builtin verbs: nothing to enable, nothing to attach. Every one compiles to plain,
dependency-free GDScript.

## Table of Contents

1. [Where this shines](#where-this-shines)
2. [Core concepts](#core-concepts)
3. [The CSV parse policy](#the-csv-parse-policy)
4. [Verb reference](#verb-reference)
5. [Use cases](#use-cases)
6. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this shines

- **Item, weapon and enemy tables** a designer edits in a spreadsheet and exports as `.csv`.
- **Dialogue lines** with speaker, mood and text columns.
- **Loot tables** with a weight column summed straight out of Column Of Table.
- **Level manifests** - one row per level, with its scene path and its par time.
- **A folder of item `.tres` files** that is the item list, with nothing to register.
- **Mod folders** the player drops files into, walked at startup.
- **Difficulty tiers and boss phases** as presets poured onto a node.
- **Paper-doll equipping** - a weapon's stats poured onto the held-weapon node.
- **Ghost and replay doubles** kept in sync with a property comparison.
- **Import validation** - a readable "row 12, column price: abc is not a number" instead of nothing.

## Core concepts

- **A table is a list of records.** Table From File gives an Array of Dictionaries. Store it in an
  Array variable, then walk it with a For Each pick filter or read one row with Row Where.
- **The header row is the vocabulary.** Column names in the first line become the keys. Rename a
  column in the spreadsheet and every `row["..."]` that named it stops finding anything.
- **Every cell is text.** The parse does not convert types, so a price cell reads as `"25"`, not 25.
  Convert with To Integer or To Decimal where you do arithmetic.
- **A folder is a list.** Resources In Folder loads a directory in the folder's own order, and does
  not recurse. Adding an item to the game is dropping a file in.
- **Missing is normal, not a fault.** A missing file reads as no rows, a missing folder walks nothing,
  and Resource In Folder gives nothing back rather than a red error. The mod folder that does not
  exist yet is the ordinary case.
- **A `.tres` dropped on ten nodes is ONE object.** Writing to it at runtime edits the asset all ten
  see, and in a `@tool` sheet it writes back to disk. **Copy Resource (Independent)** is the fix, and
  naming both copy depths is the point: the trap bites precisely because nothing said which copy you
  were getting.
- **Pouring is by name.** Copy Values From, Fill Blanks From and Apply Preset To Node all address
  fields by name and SKIP a name the receiving side does not have, which is what lets one preset serve
  several node types. **Matches Properties Of** is deliberately the other way round: a name the object
  under test does not have reads as NOT matching, so a typo shows up instead of quietly reporting
  "still in sync".
- **An empty report is the all-clear.** Explain JSON Problem, Explain Table Problem and Missing Fields
  all return `""` when there is nothing wrong, so the whole failure branch is the shipped Text Is
  Blank condition, inverted.

## The CSV parse policy

Every clause here is pinned by the plugin's own tests, so you can rely on it:

- A cell wrapped in `"double quotes"` may contain the separator, and a doubled `""` inside such a cell
  is one literal quote character.
- CRLF and lone-CR line endings are normalised, and blank lines are dropped. A missing trailing
  newline is a non-event.
- A **blank** column name is skipped, because no row could address it. A **repeated** column name
  keeps the FIRST column's value, so `row["price"]` and Column Of Table can never disagree about which
  column they mean.
- A **short** row fills its missing columns with `""` rather than being dropped, and cells past the
  last column name are ignored.
- A missing or unreadable file reads as `""`, and so as no rows.
- A line whose quote characters do not PAIR UP (an inches mark, a hand-typed row) is split plainly,
  with the stray quote kept as a literal character. Without that clause the line would silently lose a
  column.

The Separator parameter offers **Comma**, **Semicolon** and **Tab** - deliberately a short list,
because those three are what a spreadsheet export actually writes and the policy above is proven
against them.

## Verb reference

Ships as is the template the row compiles to. The table and folder templates are long single
expressions by necessity: an expression lands in a value field, so it has to BE one expression, with
no statements and nothing from the plugin at runtime. They are summarised rather than reproduced
character for character below.

### Files: Tables

| Verb | What it does | Ships as |
|------|--------------|----------|
| Table From File | Reads a `.csv` whose first line is the column names into one record per row | A single quote-aware fold over `FileAccess.get_file_as_string({path})`, split by `{separator}` |
| Table From Text | The same parse over text you already hold instead of a file on disk | The same fold over `{text}` |
| Column Of Table | One whole column as a list, in row order | `{table}.map(func(__record): return __record.get({column}, ""))` |
| Row Where | The FIRST record whose column holds this value, empty record when nothing matches | `{table}.reduce(...)` returning the first match, `{}` otherwise |
| Explain Table Problem | The first cell that should be a number and is not, said out loud | A lambda over `{records}` and `{columns}` returning `"row %d, column \"%s\": \"%s\" is not a number"` or `""` |

### Loops

These three are CONDITIONS that land in the event's loop lane, so the event's actions run once per
item and the loop index, frame-spreading and round-trip all come from the pick machinery.

| Verb | What it does | Ships as |
|------|--------------|----------|
| For Each Line In Text | Runs the event's actions once per LINE, skipping blank ones. Read the current one as `line` | `{text}.replace("\r\n", "\n").replace("\r", "\n").split("\n", false)` |
| For Each Part In Text | Once per PIECE split by a separator, each trimmed, empties skipped. Read it as `part` | `Array({text}.split({separator}, false)).map(strip_edges).filter(not empty)` |
| For Each Resource In Folder | Once per already-loaded `.tres` / `.res` in a folder. Read it as `entry` | A guarded `DirAccess.get_files_at({folder})` walk that trims `.remap`, filters extensions, loads, and drops nulls |

### Files: a folder of data assets

| Verb | What it does | Ships as |
|------|--------------|----------|
| Resources In Folder | Loads every `.tres` / `.res` in a folder as a list (not recursive) | The same guarded walk, as an expression |
| Resource In Folder | One data asset by file name without the extension, or nothing at all | `(load({folder}.path_join({name}) + ".tres") if ResourceLoader.exists(...) else null)` |
| Load Resource Or Default | Loads a file, handing back your fallback when it is missing | `(load({path}) if ResourceLoader.exists({path}) else {fallback})` |
| Count Of Resources In | How many data assets a folder holds, counted without loading any | A filtered `DirAccess.get_files_at({folder})` `.size()` |

### Helpers: copying

| Verb | What it does | Ships as |
|------|--------------|----------|
| Copy Resource (Independent) | A private copy right down to the resources inside it | `({resource}.duplicate(true) if {resource} is Resource else null)` |
| Copy Resource (Share Sub-Resources) | A cheap copy whose inner resources and lists stay SHARED | `({resource}.duplicate(false) if {resource} is Resource else null)` |

### Helpers: pouring values between objects

| Verb | What it does | Ships as |
|------|--------------|----------|
| Copy Values From | Pours a comma-separated list of named values off another object onto this one (blank list means every variable the source's script declares) | A loop over the names that writes each one the source and target both have |
| Fill Blanks From | Writes a base's values ONLY into fields the target left empty | A loop over the base's script variables that writes only where the target's value is null or an empty String, Array or Dictionary |
| Apply Preset To Node | Pours a data asset's fields onto the same-named properties of a node | A null-guarded loop over the preset's script variables |
| Matches Properties Of | True while the listed properties hold the same values on both objects | `({target} != null and {other} != null and Array({names}.split(",", false)).all(...))` |

### The reports

| Verb | What it does | Ships as |
|------|--------------|----------|
| Explain JSON Problem | Why this JSON failed to parse, with the line: `"line 4: Expected ':'"`. Empty when it parses | A lambda binding a `JSON.new()` so `get_error_line() + 1` and `get_error_message()` can be read |
| Explain Table Problem | The first non-numeric cell in a column that must hold numbers, or a row that is not a record at all | See the Files: Tables table above |
| Missing Fields | The listed fields that are missing or left blank, comma-separated | A lambda over the record and `{fields}.split(",")` joined with `", "` |

## Use cases

**1. The whole spreadsheet pipeline.** Read it once, then walk it.

```
On Ready
  -> set items = Table From File("res://data/items.csv", Comma)

On shop opened
  -> For Each item of items
       -> add a shop row labelled item["name"] costing item["price"]
```

**2. Look one thing up.** Row Where finds the FIRST match and compares as text, so 25 and `"25"` both
match a cell reading 25.

```
On item equipped
  -> set record = Row Where(items, "id", equipped_id)
  -> set damage = To Integer(record["damage"])
```

**3. Guard the lookup.** Row Where gives an EMPTY record when nothing matches, so check before reading
fields.

```
On item equipped
  -> set record = Row Where(items, "id", equipped_id)
  Condition: Dictionary Is Empty  record  (inverted)
    -> apply the item's stats
  Else
    -> show "Unknown item: " + equipped_id
```

**4. One column as a list.** Column Of Table is the dropdown's items, the weights list, the quick sum.

```
On name picker opened
  -> set NamesDropdown.items = Column Of Table(names_table, "name")
```

**5. Parse a blob you already hold.** Table From Text is the same parse over text from anywhere - a
paste box, a downloaded body, a file you read earlier.

```
On import pressed
  -> set imported = Table From Text(ImportBox.text, Comma)
```

**6. A tab-separated export.** Change the Separator dropdown; nothing else moves.

```
On Ready
  -> set enemies = Table From File("res://data/enemies.tsv", Tab)
```

**7. Say what is wrong with the spreadsheet.** Explain Table Problem names the first cell in a
must-be-a-number column that is not one.

```
On import pressed
  -> set problem = Explain Table Problem(imported, ["price", "weight"])
  Condition: Text Is Blank  problem  (inverted)
    -> show "Import failed: " + problem
  Else
    -> accept the import
```

It reads like `row 12, column "price": "abc" is not a number`. Rows are counted from 1 over the rows
you hold, and Table From File has already used up the header line, so row 12 is line 13 of the file.

**8. A folder of items IS the item list.**

```
On Ready
  -> set all_items = Resources In Folder("res://data/items")
```

Dropping a new `.tres` in that folder adds an item to the game with no registry to update.

**9. Walk the folder in the loop lane instead.** For Each Resource In Folder hands you each asset
already loaded, as `entry`.

```
On catalogue opened
  Condition: For Each Resource In Folder  "res://data/items"
    -> add a catalogue card titled entry.display_name priced entry.cost
```

**10. Fetch one asset by name.** Resource In Folder takes the file name WITHOUT the extension, so
`"rusty_sword"` finds `rusty_sword.tres`, and gives nothing at all when there is no such file.

```
On loot rolled
  -> set item = Resource In Folder("res://data/items", rolled_id)
  Condition: Is Nothing  item  (inverted)
    -> grant the item
```

**11. A fallback that keeps a deleted file from crashing the game.**

```
On enemy spawned
  -> set profile = Load Resource Or Default("res://data/enemies/" + kind + ".tres", default_enemy)
```

**12. Show how much content a mod folder holds** without paying to load any of it.

```
On mods menu opened
  -> set ModsLabel text = str(Count Of Resources In("user://mods")) + " mods installed"
```

**13. Stop a node editing the shared asset.** This is the expensive beginner trap: without the copy,
the enemy that levels up writes to the `.tres` every other enemy is using.

```
On enemy spawned
  -> set stats = Copy Resource (Independent)(stats_template)

On enemy levels up
  -> set stats.attack = stats.attack + 2
```

**14. Share sub-resources on purpose.** The cheap copy separates the top-level fields but deliberately
keeps the inner resources and lists shared - pick it only when that sharing is what you want.

```
On variant created
  -> set variant = Copy Resource (Share Sub-Resources)(base_material_set)
```

**15. Pour a preset onto a node.** Apply Preset To Node writes a data asset's fields onto the
same-named properties of a node, so difficulty tiers become a data edit.

```
On difficulty chosen
  -> Apply Preset To Node  hard_preset, Spawner
```

**16. Mirror one node onto another.** Copy Values From takes the names as a comma-separated list.

```
On ghost recorded
  -> Copy Values From  Ghost, Player, "position, rotation, scale"
```

Leave the Names cell blank to copy every variable the source's script declares, which is what lets one
preset serve several kinds of node.

**17. The override chain.** Fill Blanks From writes ONLY into fields the target left empty, so a
rarity variant can fill in whatever the base item did not say.

```
On item generated
  -> Fill Blanks From  rolled_item, base_item
```

Empty means nothing there: no value, blank text, an empty list or an empty record. A `0` and a `false`
are real values and are kept.

**18. Is this ghost still in sync?** Matches Properties Of is the cheap comparison, and a name neither
object has reads as NOT matching, so a typo shows up.

```
Every Frame
  Condition: Matches Properties Of  Ghost, "position, rotation", Player  (inverted)
    -> tint the desync warning red
```

**19. Say which fields a record forgot.** Missing Fields works on a record OR a resource.

```
On level loaded
  -> set gaps = Missing Fields(level_record, "tiles, spawn_point, music")
  Condition: Text Is Blank  gaps  (inverted)
    -> show "This level is missing: " + gaps
```

**20. Explain a bad JSON file instead of failing in silence.** Empty means it parsed fine.

```
On save loaded
  -> set problem = Explain JSON Problem(Read Text File("user://save.json"))
  Condition: Text Is Blank  problem  (inverted)
    -> show "Your save could not be read (" + problem + "). Starting fresh."
    -> set save = {}
```

```gdscript
func _on_save_loaded() -> void:
	problem = (func(__json: JSON) -> String: return "" if __json.parse(FileAccess.get_file_as_string("user://save.json")) == OK else "line %d: %s" % [__json.get_error_line() + 1, __json.get_error_message()]).call(JSON.new())
```

**21. Walk a text file line by line.** For Each Line In Text handles Windows and old-Mac line endings,
so no line arrives with a stray carriage return.

```
On changelog opened
  Condition: For Each Line In Text  Read Text File("res://CHANGELOG.txt")
    -> add a label reading line
```

**22. Break one cell into a list.** For Each Part In Text trims each piece and skips empties, so
`"sword; shield;; bow"` is three parts.

```
On item loaded
  Condition: For Each Part In Text  record["tags"], ";"
    -> add tag part to the item's tag list
```

### Other use cases

**Localisation table.** One column per language and a key column, read once with Table From File and looked up with Row Where, so adding a language is a spreadsheet column rather than a code change.

**Weighted loot roll.** Column Of Table pulls the weight column as a list, a running sum picks an index, and the matching record is the drop - the whole roll is data the designer owns.

**Card game deck.** A folder of card `.tres` files walked by For Each Resource In Folder builds the whole collection screen, and Count Of Resources In tells the player how many exist.

**Boss phase table.** Each phase is a preset resource poured onto the boss with Apply Preset To Node when its health threshold is crossed, so retuning a phase never touches a row.

**Player-supplied content check.** Run Missing Fields over every asset in a mod folder at startup and show one list of what each broken file forgot, instead of failing at the moment it is first used.

## Tips and common mistakes

- **The first line of the CSV must be the column names.** A file exported with a title row above the
  header will use that title row as the vocabulary, and every field lookup will miss.
- **Every cell is TEXT.** `record["price"]` is `"25"`, not 25. `"25" + 1` is not what you want -
  convert with To Integer or To Decimal first. This is the most common table bug.
- **A repeated column name keeps the first column's value**, and a blank column name is skipped
  entirely. If a column seems to be ignored, check the header row for a duplicate or an empty cell.
- **A short row is kept, not dropped**, with its missing columns as `""`. So a truncated row does not
  disappear; it arrives quietly incomplete. Explain Table Problem is how you find it.
- **A missing file reads as no rows.** That is convenient and it is also silent - "the path is wrong"
  and "the table is empty" look identical. Guard with File Exists when it matters.
- **Row Where returns an empty record on a miss**, not nothing at all, so `record["id"]` on a miss
  gives you nothing rather than an error. Check with Dictionary Is Empty first.
- **Row Where compares as TEXT.** That is why 25 matches `"25"`, and it is also why `1.0` does not
  match a cell reading `1`.
- **Resources In Folder is not recursive.** It reads one folder. Nest content and the subfolders are
  ignored.
- **In an exported project a converted `res://` text resource is stored as `<name>.tres.remap`.** The
  folder verbs here trim that suffix before testing the extension, which is exactly why a hand-rolled
  version of the same walk finds nothing in an export while working perfectly in the editor.
- **A file that fails to load is left OUT of the list**, not included as nothing. That is deliberate:
  a null in a list your rows call "my content" is a dead item the first `entry.field` trips over.
- **A `.tres` on ten nodes is one object.** If editing one enemy's stats changes every enemy, you
  forgot Copy Resource (Independent). In a `@tool` sheet it is worse: the edit is written back to the
  file on disk.
- **Copy Resource (Share Sub-Resources) is not the safe one.** Its inner resources and array fields
  are still shared with the original. Reach for it only when you want that.
- **The pouring verbs skip names the target does not have; the comparison does the opposite.** Copy
  Values From ignoring a name is a feature (one preset, several node types). Matches Properties Of
  reading a missing name as NOT matching is also a feature - it turns a rename into a visible false
  instead of a quiet "still in sync".
- **Apply Preset To Node does nothing when the preset slot is empty**, which is the usual cause of "my
  difficulty tier had no effect": the `.tres` was never dragged into the Inspector slot.
- **Fill Blanks From treats 0 and false as real values.** They are kept, not overwritten. Only null,
  blank text, an empty list and an empty record count as blank - the same reading Missing Fields uses.
- **An empty report means nothing is wrong.** All three reports use that convention, so branch on
  Text Is Blank inverted. Never treat an empty string as "the check failed to run".
- **Do not pair JSON Is Valid with Explain JSON Problem.** JSON Is Valid reads a document holding just
  the word `null` as invalid, while Explain JSON Problem correctly has nothing to say about it, so the
  two together log an error with a blank reason. Branch on the report's own emptiness instead.
- **Explain Table Problem counts rows from 1 over the RECORDS you hold.** Table From File has already
  consumed the header line, so its row 12 is line 13 of the file.
