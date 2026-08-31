# Reading Spreadsheets And Data Assets

Two pipelines that answer the same question - "where does my game's content live, if not in a wall of
rows?" - plus the expressions that tell you why a load went wrong.

The first pipeline is **a designer edits a spreadsheet**. **Table From File** reads a `.csv` whose
first line is the column names and hands back one record per row, every field reachable as
`row["price"]`. **Column Of Table** and **Row Where** read one column or one record back out.
**Table Of File** is the same job handed to Godot's own CSV reader, and **Write Table To File** is its
inverse, so a table read here and written back comes out byte for byte the way it went in.

The second is **a folder of `.tres` IS my content**. **Resources In Folder** loads every data asset in
a directory as a list, **Resource In Folder** fetches one by file name, and **For Each Resource In
Folder** walks them in the loop lane with no list to maintain.

Around both sit the copy-and-pour rows (making a private copy of a resource, pouring a preset onto a
node) and three reports that turn a silent failure into a sentence you can print.

This is builtin vocabulary: nothing to enable, nothing to attach. Every one compiles to plain,
dependency-free GDScript.

## Table of Contents

1. [Where this shines](#where-this-shines)
2. [Core concepts](#core-concepts)
3. [The CSV parse policy](#the-csv-parse-policy)
4. [Two readers, and which to pick](#two-readers-and-which-to-pick)
5. [Reference tables](#reference-tables)
6. [Use cases](#use-cases)
7. [Tips and common mistakes](#tips-and-common-mistakes)

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

## Two readers, and which to pick

There are two ways to turn a `.csv` into rows, and they differ in exactly one thing: **who does the
quoting**.

- **Table From File** parses the file itself, in one expression, under the policy above. Everything
  in that list is a promise this plugin makes and its tests hold it to.
- **Table Of File** calls `FileAccess.get_csv_line` - **Godot's own CSV reader** - one line at a time.
  Its quoting is therefore whatever the engine does with a quote, not what this plugin decided: a cell
  in `"double quotes"` may hold the separator, and a doubled `""` inside one is a single quote
  character. If the engine's behaviour ever differs from the policy above in a corner you care about,
  this verb is the one that follows the engine.

Two more differences worth knowing before you choose:

- **Table Of File asks whether the first line names the columns at all.** Its **First line** parameter
  has two answers: *the first line names the columns* gives one record per row (`row["price"]`), and
  *every line is a row* gives a plain list of cells per line, which is what a headerless export needs.
  Table From File always treats the first line as the header, so a headerless file loses its first
  line to it.
- **Table Of File is several statements**, because the engine's reader needs a loop and a loop is not
  an expression. It compiles to a lambda called on the spot, so put it in a **Set** action - a
  condition is joined into one `if` line and cannot hold several. Table From File is one expression
  and fits anywhere.

**Write Table To File** is Table Of File's inverse, through `store_csv_line`. A cell holding the
separator or a quote is quoted the way the engine quotes it, which is what makes the pair round-trip:
read a file with Table Of File, write it back with Write Table To File, and the bytes match. Its
**First line** parameter decides whether a header line is written, and when it is, the columns come
from the FIRST record's own field order - the only order your sheet ever stated.

Both of them are separate verbs rather than options on the shipped ones, because a shipped
`ace_id` and its template are a compatibility promise: existing sheets keep compiling to exactly what
they compiled to before.

![The Table Of File parameters dialog: a File box holding "res://data/items.csv" with the muted lead res:// - the game's own files: READ-ONLY once exported under it, a Separator picker reading Comma, and a First line picker reading The first line names the columns; below, the IN CODE strip showing the whole emitted read - FileAccess.open, a while over get_csv_line, and the record it builds per row](images/engine-table-read.png)

**Game saves are still the Save System's territory.** Slots, formats and backups live there; these
verbs are for content a designer edits and for data a game writes out for a human to read.

## Reference tables

Ships as is the template the row compiles to. The table and folder templates are long single
expressions by necessity: an expression lands in a value field, so it has to BE one expression, with
no statements and nothing from the plugin at runtime. They are summarised rather than reproduced
character for character below.

### Files: Tables

| Name | What it does | Ships as |
|------|--------------|----------|
| Table From File | Reads a `.csv` whose first line is the column names into one record per row | A single quote-aware fold over `FileAccess.get_file_as_string({path})`, split by `{separator}` |
| Table From Text | The same parse over text you already hold instead of a file on disk | The same fold over `{text}` |
| Column Of Table | One whole column as a list, in row order | `{table}.map(func(__record): return __record.get({column}, ""))` |
| Row Where | The FIRST record whose column holds this value, empty record when nothing matches | `{table}.reduce(...)` returning the first match, `{}` otherwise |
| Table Of File | Reads a `.csv` with Godot's own CSV reader; the First line parameter says whether that line names the columns | A lambda called on the spot: `FileAccess.open({path}, FileAccess.READ)` then `get_csv_line({separator})` in a `while` |
| Write Table To File | Writes rows back out with Godot's own CSV writer, optionally with a header line | `FileAccess.open({path}, FileAccess.WRITE)` guarded, then `store_csv_line(..., {separator})` per entry |
| Explain Table Problem | The first cell that should be a number and is not, said out loud | A lambda over `{records}` and `{columns}` returning `"row %d, column \"%s\": \"%s\" is not a number"` or `""` |

### Loops

These four are CONDITIONS that land in the event's loop lane, so the event's actions run once per
item and the loop index, frame-spreading and round-trip all come from the pick machinery.

| Name | What it does | Ships as |
|------|--------------|----------|
| For Each Line In Text | Runs the event's actions once per LINE, skipping blank ones. Read the current one as `line` | `{text}.replace("\r\n", "\n").replace("\r", "\n").split("\n", false)` |
| For Each Part In Text | Once per PIECE split by a separator, each trimmed, empties skipped. Read it as `part` | `Array({text}.split({separator}, false)).map(strip_edges).filter(not empty)` |
| For Each Resource In Folder | Once per already-loaded `.tres` / `.res` in a folder. Read it as `entry` | A guarded `DirAccess.get_files_at({folder})` walk that trims `.remap`, filters extensions, loads, and drops nulls |

### Files: a folder of data assets

| Name | What it does | Ships as |
|------|--------------|----------|
| Resources In Folder | Loads every `.tres` / `.res` in a folder as a list (not recursive) | The same guarded walk, as an expression |
| Resource In Folder | One data asset by file name without the extension, or nothing at all | `(load({folder}.path_join({name}) + ".tres") if ResourceLoader.exists(...) else null)` |
| Load Resource Or Default | Loads a file, handing back your fallback when it is missing | `(load({path}) if ResourceLoader.exists({path}) else {fallback})` |
| Count Of Resources In | How many data assets a folder holds, counted without loading any | A filtered `DirAccess.get_files_at({folder})` `.size()` |

### Files: live data (a file that changed while the game is running)

| Name | What it does | Ships as |
|------|--------------|----------|
| Watch Data File | Checks whether a data file has been written since the last check, and fires the sheet's `data_file_changed(path)` signal when it has | A modification-time reading compared with the one remembered in node metadata under the path |
| Reload Data Asset | Re-reads a data asset from disk into the copy every node is already holding | `ResourceLoader.load({path}, "", ResourceLoader.CACHE_MODE_REPLACE)`, guarded by `ResourceLoader.exists` |
| Data Folder Problems | Every structural problem in a folder of data assets, one per line, `""` when it is clean | The folder walk above, mapping each asset to a problem line and joining the non-empty ones |
| Data Folder Is Valid | True when every asset loads, has an id, and has an id no sibling shares | The same expression, `.is_empty()` |
| Validate Data Folder | Writes those problems to the Output as one warning, and says nothing at all when the folder is clean | The same expression into a `push_warning` guarded by `is_empty()` |
| On Data File Changed | Runs when a watched file has been written, handing you the path that changed | connects to the sheet's own `data_file_changed(path)` signal |

The trigger half is a signal you declare on the sheet, because that is what makes the changed path
the row's own payload rather than a "what changed last" value two files landing in the same check
would corrupt. Add a **Signal** row reading `data_file_changed(path: String)` and put the reaction
under **On Data File Changed**; a sheet that declares no such signal simply never fires (the action
checks first), so the watch row is always safe to drop.

### Helpers: copying

| Name | What it does | Ships as |
|------|--------------|----------|
| Copy Resource (Independent) | A private copy right down to the resources inside it | `({resource}.duplicate(true) if {resource} is Resource else null)` |
| Copy Resource (Share Sub-Resources) | A cheap copy whose inner resources and lists stay SHARED | `({resource}.duplicate(false) if {resource} is Resource else null)` |

### Helpers: pouring values between objects

| Name | What it does | Ships as |
|------|--------------|----------|
| Copy Values From | Pours a comma-separated list of named values off another object onto this one (blank list means every variable the source's script declares) | A loop over the names that writes each one the source and target both have |
| Fill Blanks From | Writes a base's values ONLY into fields the target left empty | A loop over the base's script variables that writes only where the target's value is null or an empty String, Array or Dictionary |
| Apply Preset To Node | Pours a data asset's fields onto the same-named properties of a node | A null-guarded loop over the preset's script variables |
| Matches Properties Of | True while the listed properties hold the same values on both objects | `({target} != null and {other} != null and Array({names}.split(",", false)).all(...))` |

### The reports

| Name | What it does | Ships as |
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

**23. Tune a number without restarting.** The balance loop: watch the folder's file while a debug
build runs, and reload it the moment it is written. Declare the signal once (a **Signal** row reading
`data_file_changed(path: String)`), and the trigger hands you the path.

```
Condition: Is Debug Build
  Condition: Every 0.5 seconds
    -> Watch Data File  "res://data/enemies/warden.tres"

On Data File Changed  ( path )
  -> Reload Data Asset  ( path )
```

```gdscript
extends Node

signal data_file_changed(path: String)


func _on_data_file_changed(path: String) -> void:
	if ResourceLoader.exists(path):
		ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
```

**24. Tell everything that cares to re-read itself.** The reload updates the asset; the nodes holding
it may need a nudge. That fan-out is a loop ROW, with the call as its action.

```
On Data File Changed  ( path )
  -> Reload Data Asset  ( path )
  Condition: For Each  ( Everything That Can "reload_data" )
    -> Call Method  "reload_data" on ( Loop Item )
```

**25. Watch several files.** One row per file, all under the same beat - the metadata that remembers
each file's stamp is keyed by path, so they never interfere.

```
Condition: Every 0.5 seconds
  -> Watch Data File  "res://data/balance/player.tres"
  -> Watch Data File  "res://data/balance/economy.tres"
```

**26. Only in a debug build.** Watching reads a timestamp off disk on every check, so leave it out of
the shipped game.

```
Condition: Is Debug Build  (inverted)
  -> stop running the watch event
```

**27. Refuse to load a broken content folder.** Data Folder Is Valid is the guard; the report is the
reason.

```
On Ready
  Condition: Data Folder Is Valid  "res://data/items"  (inverted)
    -> Log Message  ( Data Folder Problems "res://data/items" )
    -> show "Your item data could not be read" and stop
```

**28. Check a mod folder before trusting it.** The same check over a folder the player filled - which
is what makes user content safe to load at all.

```
On mod folder chosen
  -> Validate Data Folder  ( chosen_folder )
  Condition: Data Folder Is Valid  ( chosen_folder )
    -> set mod_items = Resources In Folder( chosen_folder )
```

**29. Fail a build on bad data.** The same condition in an Editor Tool sheet, so a designer's `.tres` edit
is checked by the build server with no second implementation of the rules.

```
On Editor Run
  Condition: Data Folder Is Valid  "res://data/items"  (inverted)
    -> Log Error  ( Data Folder Problems "res://data/items" )
```

**30. Say WHY an item is being ignored.** The most common cause is the quietest one: two files with
the same id, where the second silently wins every lookup.

```
On debug key pressed
  -> Log Message  ( Data Folder Problems "res://data/items" )
```

```gdscript
extends Node


func _on_debug_key_pressed() -> void:
	print("\n".join(PackedStringArray(Array(DirAccess.get_files_at("res://data/items")).map(func(__file): return "res://data/items".path_join(__file.trim_suffix(".remap"))).filter(func(__path): return __path.get_extension() in ["tres", "res"]).map(func(__path): return (__path.get_file() + ": cannot be loaded" if load(__path) == null else "")).filter(func(__message): return not __message.is_empty()))))
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
  folder rows here trim that suffix before testing the extension, which is exactly why a hand-rolled
  version of the same walk finds nothing in an export while working perfectly in the editor.
- **A file that fails to load is left OUT of the list**, not included as nothing. That is deliberate:
  a null in a list your rows call "my content" is a dead item the first `entry.field` trips over.
- **A `.tres` on ten nodes is one object.** If editing one enemy's stats changes every enemy, you
  forgot Copy Resource (Independent). In a `@tool` sheet it is worse: the edit is written back to the
  file on disk.
- **Copy Resource (Share Sub-Resources) is not the safe one.** Its inner resources and array fields
  are still shared with the original. Reach for it only when you want that.
- **The pouring actions skip names the target does not have; the comparison does the opposite.** Copy
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
- **Watch Data File needs a beat.** It checks once per run, so it belongs under Every X Seconds (or a
  per-frame trigger). On its own in a startup event it takes one reading and never looks again.
- **The first check never fires.** It only records where the file stood, which is what stops a
  reload storm the moment the watch event starts running.
- **A file's timestamp has one-second resolution.** Two writes inside the same second look like one,
  so a script that rewrites a file twice quickly may produce a single change - or, if the second
  write lands in the same second as the reading, none at all.
- **Reloading a `.tres` re-reads DATA, not code.** A changed script still needs a restart; this is a
  data hot-reload, and saying so up front saves an afternoon.
- **Watching is a debug-build tool.** It reads a modification time off disk every check. Guard the
  watch event with Is Debug Build so a shipped game never pays for it.
- **The folder report reads an `id` field.** An asset with no `id` property at all is reported as
  having no id, which is correct for a folder that is supposed to be addressable content - and is
  why pointing the check at a folder of textures or materials reports every file.
