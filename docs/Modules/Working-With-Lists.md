# Working With Lists

Arrays, and the loop rows that walk them.

A list (Godot calls it an **Array**) is the workhorse of any game that has more than one of something: an
inventory, a wave of enemies, a set of high scores, the lines of a file, a folder of item definitions.
This guide covers the whole builtin Array vocabulary - the actions that change a list, the expressions
that read one, the higher-order verbs that transform one, the typed-array queries, and the loop controls
you use inside a For Each.

Everything here is **builtin** - no addon, no autoload, no setup. In the picker the array verbs live under
**Variables: Array** and the loop verbs under **Loops**.

## Table of Contents

1. [Where this shines](#where-this-shines)
2. [Core concepts](#core-concepts)
3. [Verb reference](#verb-reference)
4. [Use cases](#use-cases)
5. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this shines

- **Inventories** - add, remove, count, check, sort.
- **Queues and stacks** - Push Front and Pop Front make a queue; Push Back and Pop Back make a stack.
- **Spawn tables and loot** - Pick Random over a weighted list.
- **Shuffled decks** - Shuffle Array once, then Pop Back to deal.
- **Leaderboards** - Sort Array, Reverse Array, Slice to the top ten.
- **Filtering a list without a loop** - Filter, Map, Reduce, Any Match, All Match.
- **Walking a file** - For Each Line In Text over a text blob, with no split step.
- **Content that lives in files** - For Each Resource In Folder makes a folder of `.tres` your item list.
- **A language menu that builds itself** - For Each Language over the catalogs your build actually ships.

## Core concepts

- **The first cell is always the list.** Every Array verb takes a **var_name** parameter whose dropdown is
  scoped to Array-typed sheet variables (a typed `Array[int]` qualifies too). Its default is `list`.
- **Actions change the list in place; expressions read it.** Push Back, Sort Array and Shuffle Array modify
  the variable. Value At, Array Size and Filter hand you something back and leave the original alone.
  Pop Back and Pop Front are the odd pair: they are expressions, and they also remove the item.
- **Indexes start at 0.** The first item is index 0, the last is `size - 1`, and Slice's To index is
  exclusive.
- **A For Each is a condition, not an action.** The loop verbs sit in the event's loop lane as a pick
  filter, so the event's actions run once per item. That is where the loop index, frame-spreading and the
  byte-exact round-trip all come from.
- **Each loop names its item.** The generic For Each reads `item` (that is what **Current Loop Item**
  gives you). The specialised loops name theirs: For Each Line In Text reads `line`, For Each Part In
  Text reads `part`, For Each Resource In Folder reads `entry`, For Each Language reads `language`.
- **The loop counter is opt-in.** Name it in the loop's **Loop index** field (the convention is
  `loop_index`), and **Loop Index** reads it as a plain local at zero runtime cost. **Loop Index Of**
  reads a differently-named one, which is how you reach an outer loop's counter from inside a nested one.
- **Copy Array is shallow.** It copies the outer level only; lists and records nested inside are still
  shared with the original. **Deep Copy** copies right through.

## Verb reference

### Changing a list (actions)

| Verb | What it does | Ships as |
|------|--------------|----------|
| Push Back | Adds a value to the end. | `{var_name}.append({value})` |
| Insert At | Inserts a value at a position. | `{var_name}.insert({index}, {value})` |
| Delete At | Removes the item at a position. | `{var_name}.remove_at({index})` |
| Delete Value | Removes the FIRST item matching a value. | `{var_name}.erase({value})` |
| Clear Array | Empties the list. | `{var_name}.clear()` |
| Sort Array | Sorts into ascending order, in place. | `{var_name}.sort()` |
| Shuffle Array | Randomly reorders, in place. | `{var_name}.shuffle()` |
| Reverse Array | Flips the order, in place. | `{var_name}.reverse()` |
| Push Front | Inserts a value at the start, shifting the rest along. | `{var_name}.push_front({value})` |
| Append Array | Adds every item of another list onto the end of this one. | `{var_name}.append_array({other})` |
| Resize Array | Changes the length, adding empty slots or trimming items. | `{var_name}.resize({size})` |
| Fill Array | Sets every slot to the same value. | `{var_name}.fill({value})` |
| Assign (Type-Converting) | Replaces the contents with a converted copy of another list - the type-safe way to fill a typed array. | `{var_name}.assign({source})` |

### Asking about a list (conditions)

| Verb | What it does | Ships as |
|------|--------------|----------|
| Contains | True when the list holds the given value somewhere. | `{var_name}.has({value})` |
| Array Is Empty | True when the list has no items at all. | `{var_name}.is_empty()` |
| Any Match | True when AT LEAST ONE element satisfies the test. False for an empty list. | `{var_name}.any(func({element}): return {predicate})` |
| All Match | True when EVERY element satisfies the test. Also true for an empty list. | `{var_name}.all(func({element}): return {predicate})` |
| Is Typed | True when the list is a typed container (`Array[int]`) rather than a plain untyped Array. | `{var_name}.is_typed()` |

### Reading a list (expressions)

| Verb | What it does | Ships as |
|------|--------------|----------|
| Value At | The item at a position. | `{var_name}[{index}]` |
| Array Size | How many items the list holds. | `{var_name}.size()` |
| Pick Random | One random item. | `{var_name}.pick_random()` |
| First Item | The first item. | `{var_name}.front()` |
| Last Item | The last item. | `{var_name}.back()` |
| Index Of | The position of a value, or -1 when it is missing. | `{var_name}.find({value})` |
| Count Of | How many times a value appears. | `{var_name}.count({value})` |
| Pop Back | Removes AND returns the last item. | `{var_name}.pop_back()` |
| Pop Front | Removes AND returns the first item. | `{var_name}.pop_front()` |
| Slice | A sub-section between two indexes (To is exclusive). | `{var_name}.slice({from}, {to})` |
| Join To Text | Joins a list of strings into one piece of text with a separator. | `{separator}.join({var_name})` |
| Array Max | The largest value in the list. | `{var_name}.max()` |
| Array Min | The smallest value in the list. | `{var_name}.min()` |
| Copy Array | An independent copy of the outer level. | `{var_name}.duplicate()` |
| Deep Copy | A copy of the list AND every list or record nested inside it. | `{var_name}.duplicate(true)` |
| Element Type | The element type a typed array holds, as a Variant.Type value; 0 when untyped. | `{var_name}.get_typed_builtin()` |
| Element Class | For an array typed to a class, the class name; empty text otherwise. | `{var_name}.get_typed_class_name()` |

### Transforming a list (higher-order expressions)

Each of these takes a small expression over the current element. You name the element yourself in the
**Element name** field - `x` unless you rename it - because a baked-in name would silently shadow a sheet
variable of the same name, and GDScript gives no warning when it does.

| Verb | What it does | Ships as |
|------|--------------|----------|
| Filter | A NEW list holding only the elements where the test is true. The original is unchanged. | `{var_name}.filter(func({element}): return {predicate})` |
| Map | A NEW list with every element transformed by the expression. The original is unchanged. | `{var_name}.map(func({element}): return {expression})` |
| Reduce | Folds the whole list down to a SINGLE value: the accumulator holds the running result, starting at **Starting value**, and is combined with each element in turn. | `{var_name}.reduce(func({accumulator}, {element}): return {expression}, {seed})` |

Reduce takes a second name too - the **Accumulator name**, `acc` by default, for the same shadowing
reason. `acc + x` from a starting value of `0` sums a list; `max(acc, x)` from the first element finds
the biggest.

### Loops

| Verb | What it does | Ships as |
|------|--------------|----------|
| For Each Line In Text | **Looping condition.** Runs the event's actions once per LINE, skipping blank ones. CRLF and CR endings handled. Reads the current one as `line`. | `{text}.replace("\r\n", "\n").replace("\r", "\n").split("\n", false)` |
| For Each Part In Text | **Looping condition.** Once per PIECE of the text, each trimmed, empty pieces skipped. Reads the current one as `part`. | `Array({text}.split({separator}, false)).map(func(__part): return __part.strip_edges()).filter(func(__part): return not __part.is_empty())` |
| For Each Resource In Folder | **Looping condition.** Once per already-loaded data asset (`.tres` / `.res`) in a folder. Reads the current one as `entry`. | a guarded folder walk that loads each file and skips anything that fails |
| For Each Language | **Looping condition.** Once per language your project actually ships. Reads the current one as `language`. | `TranslationServer.get_loaded_locales()` |
| Break Loop | **Action.** Stops the current loop early and skips any remaining items. | `break` |
| Continue Loop | **Action.** Skips to the next item, ignoring the rest of this pass. | `continue` |
| Current Loop Item | **Expression.** The item the loop is currently working on inside a For Each. | `item` |
| Loop Index | **Expression.** Counts 0, 1, 2… for the current pass. Name the loop's index `loop_index` first. | `loop_index` |
| Loop Index Of | **Expression.** Reads a NAMED loop's counter - for reaching an outer loop from inside a nested one. | `{name}` |

**For Each Resource In Folder** is the one long template here. It reads the folder only when the folder
exists (so a loop running every frame cannot spam engine errors for a mod folder nobody created), trims a
trailing `.remap` before testing the extension (an exported project stores a converted resource as
`<name>.tres.remap`), loads each `.tres` / `.res`, and drops anything that failed to load rather than
handing you a null the first `entry.field` would trip over.

## Use cases

**1. Pick something up.**

```
On item picked up
  -> Push Back  item_id  to  inventory
```

```gdscript
inventory.append(item_id)
```

**2. Drop it again.**

```
On drop pressed
  -> Delete Value  item_id  from  inventory
```

```gdscript
inventory.erase(item_id)
```

**Delete Value** removes the first match by value; **Delete At** removes by position. If the list can hold
duplicates and you meant "this exact one", you want Delete At with an index you already know.

**3. Do I have the key?**

```
On door touched
  Condition: inventory contains "brass_key"
    -> open the door
```

```gdscript
if inventory.has("brass_key"):
```

**4. How many potions?**

```
Every tick
  -> set PotionLabel text = str( Count Of (inventory, "potion") )
```

```gdscript
potion_label.text = str(inventory.count("potion"))
```

**5. A shuffled deck you deal from.**

```
On round started
  -> Append Array  full_deck  to  draw_pile
  -> Shuffle Array  draw_pile

On card drawn
  -> Set Current Card to  Pop Back (draw_pile)
```

```gdscript
draw_pile.append_array(full_deck)
draw_pile.shuffle()
current_card = draw_pile.pop_back()
```

**Pop Back** removes and returns in one go, which is exactly a deal. Guard it with **Array Is Empty**
first, or reshuffle when the pile runs out.

**6. A queue of spawn orders.**

```
On order received
  -> Push Back  order  to  spawn_queue

Every 1.0 seconds
  Condition: spawn_queue is empty  (inverted)
    -> Set Next to  Pop Front (spawn_queue)
    -> spawn Next
```

```gdscript
spawn_queue.append(order)
```

```gdscript
if not spawn_queue.is_empty():
	next = spawn_queue.pop_front()
```

Push Back plus **Pop Front** is a queue (first in, first out). Push Back plus Pop Back is a stack.

**7. A leaderboard's top ten.**

```
On score submitted
  -> Push Back  score  to  scores
  -> Sort Array  scores
  -> Reverse Array  scores
  -> Set Top Ten to  Slice (scores, 0, 10)
```

```gdscript
scores.append(score)
scores.sort()
scores.reverse()
top_ten = scores.slice(0, 10)
```

**Sort Array** is ascending only. Reverse Array after it is the descending sort. Slice's To index is
exclusive, so `0, 10` is exactly ten entries - and it is safe when there are fewer.

**8. Show the inventory as one line of text.**

```
Every tick
  -> set InventoryLabel text = Join To Text (inventory, ", ")
```

```gdscript
inventory_label.text = ", ".join(inventory)
```

**Join To Text** wants a list of strings. Map it through `str(x)` first if it holds anything else.

**9. Random loot.**

```
On chest opened
  -> Set Reward to  Pick Random (loot_table)
```

```gdscript
reward = loot_table.pick_random()
```

Weighting is repetition: put `"common"` in the table five times and `"rare"` once.

**10. Keep only the living enemies.**

```
Every tick
  -> Set Live Enemies to  Filter (enemies) where  is_instance_valid(x)
```

```gdscript
live_enemies = enemies.filter(func(x): return is_instance_valid(x))
```

**Filter** returns a NEW list and leaves `enemies` alone. The element is named `x` unless you rename it -
and you should rename it if your sheet already has a variable called `x`, because GDScript will shadow it
without a word.

**11. Turn a list of records into a list of names.**

```
Set Item Names to  Map (items) with  x["name"]
```

```gdscript
item_names = items.map(func(x): return x["name"])
```

**12. Total up a shopping basket.**

```
Set Total to  Reduce (prices) with  acc + x  from  0
```

```gdscript
total = prices.reduce(func(acc, x): return acc + x, 0)
```

The **Starting value** is required and it is what makes the fold work: `0` to sum, `1` to multiply, `[]`
to build a list. Rename the accumulator if your sheet already has an `acc`.

**13. Is anything on fire?**

```
Every tick
  Condition: Any Match (hazards) where  x.burning
    -> raise the alarm
```

```gdscript
if hazards.any(func(x): return x.burning):
```

**Any Match** is false for an empty list. **All Match** is true for an empty list, because nothing fails -
worth remembering when the list can legitimately be empty.

**14. Are all the objectives done?**

```
Every tick
  Condition: All Match (objectives) where  x.complete
    -> finish the level
```

```gdscript
if objectives.all(func(x): return x.complete):
```

**15. Walk a text file line by line.**

```
For Each Line In Text  FileAccess.get_file_as_string("res://data/names.txt")
  -> Push Back  line  to  name_pool
```

```gdscript
for line in FileAccess.get_file_as_string("res://data/names.txt").replace("\r\n", "\n").replace("\r", "\n").split("\n", false):
	name_pool.append(line)
```

Blank lines are skipped and Windows line endings are handled, so no line arrives with a stray carriage
return - the bug that makes a hand-rolled split fail only on one person's machine.

**16. Split a tag list and act on each piece.**

```
For Each Part In Text  card.tags  split by  ","
  -> Push Back  part  to  active_tags
```

```gdscript
for part in Array(card.tags.split(",", false)).map(func(__part): return __part.strip_edges()).filter(func(__part): return not __part.is_empty()):
	active_tags.append(part)
```

Each piece arrives trimmed and empty pieces are skipped, so `"sword; shield;; bow"` is three parts.

**17. A folder of `.tres` files IS your item list.**

```
On Ready
  For Each Resource In Folder  "res://data/items"
    -> Push Back  entry  to  all_items
```

```gdscript
for entry in Array(DirAccess.get_files_at("res://data/items") if DirAccess.dir_exists_absolute("res://data/items") else PackedStringArray()).map(func(__file): return String(__file).trim_suffix(".remap")).filter(func(__file): return __file.ends_with(".tres") or __file.ends_with(".res")).map(func(__file): return load("res://data/items".path_join(__file))).filter(func(__resource): return __resource != null):
	all_items.append(entry)
```

Add a file, and it is in the game. No manifest to maintain, no list to keep in sync. A folder that is not
there walks nothing, quietly.

**18. A language menu that builds itself.**

```
On settings opened
  For Each Language
    -> add a button labelled  Language Name In Its Own Language (language)
```

```gdscript
for language in TranslationServer.get_loaded_locales():
	add_language_button(language)
```

Only languages with a catalog are listed, so a demo build shipping fewer catalogs shows fewer buttons
without a sheet edit.

**19. Stop early once you have found it.**

```
For Each  in  enemies
  Condition: Current Loop Item .id  =  wanted_id
    -> Set Found to  Current Loop Item
    -> Break Loop
```

```gdscript
for item in enemies:
	if item.id == wanted_id:
		found = item
		break
```

**Current Loop Item** reads the generic loop's `item`. **Break Loop** and **Continue Loop** are bare
keywords, so they must sit inside a loop body - the same contract a raw GDScript block has.

**20. Skip the ones you do not care about.**

```
For Each  in  enemies
  Condition: Current Loop Item is asleep
    -> Continue Loop
  -> update the enemy
```

**21. Number the rows you are drawing.**

Name the loop's **Loop index** field `loop_index`, then:

```
For Each  in  items   (loop index: loop_index)
  -> place the row at y = Loop Index * 24
```

**Loop Index** emits the bare identifier `loop_index`, so it costs nothing at runtime - it is just the
counter the loop already declares. For a nested loop, give the outer one a distinct index name and read
it inside the inner one with **Loop Index Of**.

**22. Fill a typed array safely.**

```
On Ready
  -> Assign (Type-Converting)  raw_numbers  into  scores
```

```gdscript
scores.assign(raw_numbers)
```

**Assign (Type-Converting)** converts each element to the destination's element type. A float `2.7` going
into an `Array[int]` truncates silently to 2; a value that cannot convert at all leaves the destination
EMPTY and pushes an error, which is worth knowing before you point it at user data.

**23. Ask what kind of list this is.**

```
Condition: Is Typed  scores
  -> print type_string( Element Type (scores) )
```

```gdscript
if scores.is_typed():
	print(type_string(scores.get_typed_builtin()))
```

**Element Class** is the companion for arrays typed to a class (`Array[Node]`); it gives empty text for a
builtin-typed or untyped array.

**24. A copy that edits cannot leak back into.**

```
On preview opened
  -> Set Preview Loadout to  Deep Copy (loadout)
```

```gdscript
preview_loadout = loadout.duplicate(true)
```

**Copy Array** copies the outer level only, so a record nested inside is still shared and editing the
"copy" edits the original. **Deep Copy** copies right through.

**25. A fixed-size grid, pre-filled.**

```
On Ready
  -> Resize Array  grid  to  64
  -> Fill Array  grid  with  0
```

```gdscript
grid.resize(64)
grid.fill(0)
```

### Other use cases

**A recently-played list capped at five.** Push Front the new entry, then Resize Array to 5 - the
oldest falls off the end with no index arithmetic at all.

**Damage numbers pooled by index.** Fill Array with nulls at startup, then Index Of a null to find the
next free slot, which turns pooling into two rows.

**A dialogue script read straight from a text file.** For Each Line In Text over the file, with For Each
Part In Text splitting each line into speaker and line on the first colon.

**Difficulty tiers as a folder.** For Each Resource In Folder over `res://data/difficulty`, and adding a
new tier is dropping a `.tres` in - no sheet edit, no enum to extend.

**Localised credits.** For Each Language walking the shipped catalogs, Map turning each into its own-name
label, and Join To Text producing one credits line.

## Tips and common mistakes

- **Copy Array is shallow.** Records and lists nested inside the copy are still the originals. Reach for
  **Deep Copy** whenever the items are themselves lists or records.
- **Sort Array is ascending and in place.** It changes the variable and returns nothing. Reverse Array
  after it for descending; Copy Array first if you need the original order too.
- **Pop Back and Pop Front on an empty list.** They are expressions that also mutate, and popping an empty
  list gives nothing back. Guard with **Array Is Empty** first.
- **Value At is not bounds-checked.** An index past the end errors at runtime. Compare against **Array
  Size** first, or use First Item / Last Item where those are what you meant.
- **Index Of answers -1 when the value is missing**, and -1 is a perfectly valid-looking number. Test for
  it rather than feeding the result straight into Value At.
- **Slice's To index is exclusive.** `Slice(list, 0, 10)` is ten items, indexes 0 through 9.
- **All Match is TRUE for an empty list** and Any Match is FALSE for one. That is logically right but it
  catches people out: an "all objectives complete" gate passes before any objectives are added.
- **Rename the element when your sheet already has an `x`.** Filter, Map, Reduce, Any Match and All Match
  all let you name the current element, precisely so it cannot silently shadow one of your variables.
  GDScript issues no warning when it does, so the row compiles clean and quietly computes the wrong thing.
- **Reduce always needs a Starting value.** There is no "start from the first element" mode; write the
  seed explicitly (`0` to sum, `1` to multiply, `[]` to build a list).
- **Assign (Type-Converting) can empty the destination.** A value that will not convert at all leaves the
  target list empty and pushes an error, rather than converting what it can.
- **Break Loop and Continue Loop must be inside a loop body.** They emit the bare `break` / `continue`
  keywords, so putting one outside a loop is a compile error, not a no-op.
- **Current Loop Item reads the DEFAULT iterator, `item`.** If you renamed the loop's iterator, type the
  new name in the cell instead - the verb has no knowledge of your rename.
- **The loop counter is opt-in.** Loop Index emits the bare identifier `loop_index`, so it only works when
  the loop's **Loop index** field actually declares that name. For nested loops give each a distinct name
  and read the outer one with Loop Index Of.
- **For Each Language lists only languages that HAVE a catalog.** English usually appears only when it has
  a translation file of its own, which surprises people whose source language is English.
- **For Each Resource In Folder is not recursive**, and only `.tres` / `.res` files are loaded - anything
  else in the folder is ignored.
