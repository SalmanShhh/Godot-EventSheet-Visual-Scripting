# Working With Records

Dictionaries: values addressed by name instead of by position.

Where a list answers "the third one", a record answers "the gold". Godot calls it a **Dictionary**, and it
is what a save file, a settings block, a JSON payload, a spreadsheet row and an item definition all are
once they are in memory: a set of named fields you read and write by key.

This guide covers the whole builtin Dictionary vocabulary, plus the three rows that migrate a record
written by an older build of your game.

Everything here is **builtin** - no addon, no autoload, no setup. In the picker it lives under
**Variables: Dictionary**.

## Table of Contents

1. [Where this shines](#where-this-shines)
2. [Core concepts](#core-concepts)
3. [Reference tables](#reference-tables)
4. [Migrating old data](#migrating-old-data)
5. [Use cases](#use-cases)
6. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this shines

- **Save files** - one record holding score, level, position and a settings block.
- **Settings** - volume, language, difficulty, addressed by name so a new option is a new key.
- **JSON from anywhere** - a downloaded payload, a mod manifest, a config file.
- **Item and enemy definitions** - a record per thing, with fields you can add without touching rows.
- **Counters keyed by name** - kills per enemy type, resources per material, votes per option.
- **Lookup tables** - a row out of a spreadsheet is exactly a record, keyed by column name.
- **Migrations** - the three rows that let last month's save file open in this month's build.

## Core concepts

- **A key is usually text, and the quotes matter.** `"gold"` is the key; `gold` without quotes is a
  variable. Every key parameter here is an expression cell, so both are possible and the quotes are how
  you say which you meant.
- **Set Key both adds and overwrites.** There is no separate "add" action - writing a key that is not there
  yet creates it.
- **Reading a missing key with plain subscript access errors.** That is why **Get Key (with default)**
  exists: it takes a fallback and hands that back when the key is not present.
- **A dictionary variable's dropdown is scoped.** Every row here takes a **var_name** whose picker offers
  Dictionary-typed sheet variables (and untyped ones). Its default is `dict`.
- **Copy Dictionary is shallow.** It copies the outer level only; lists and records nested inside are
  still shared with the original. **Deep Copy** copies right through. This matters most for a settings
  block inside a save record - a shallow copy of the save still shares the settings.
- **Merge overwrites.** Merge Dictionary copies another record's keys in and clashes go to the incoming
  value, which is what makes it the "apply overrides" action.
- **Godot's `.get` does not fall back on an empty value.** Only a MISSING key reaches the default. A key
  holding `""`, `0` or `null` hands that back, because those are real values.

## Reference tables

### Changing a record (actions)

| Name | What it does | Ships as |
|------|--------------|----------|
| Set Key | Stores a value under a key, adding it or overwriting it. | `{var_name}[{key}] = {value}` |
| Delete Key | Removes a key and its value. | `{var_name}.erase({key})` |
| Clear Dictionary | Empties the record, removing every key and value. | `{var_name}.clear()` |
| Merge Dictionary | Copies another record's keys into this one, overwriting any clashes. | `{var_name}.merge({other}, true)` |

### Asking about a record (conditions)

| Name | What it does | Ships as |
|------|--------------|----------|
| Has Key | True when the record contains the given key. | `{var_name}.has({key})` |
| Has All Keys | True when the record contains every key in the given list. | `{var_name}.has_all({keys})` |
| Has Value | True when the record contains the given value anywhere. | `{var_name}.values().has({value})` |
| Dictionary Is Empty | True when the record has no keys at all. | `{var_name}.is_empty()` |

### Reading a record (expressions)

| Name | What it does | Ships as |
|------|--------------|----------|
| Get Key (with default) | The key's value, or your fallback when the key is missing. | `{var_name}.get({key}, {default})` |
| Dictionary Size | How many keys the record holds. | `{var_name}.size()` |
| Dictionary Keys | A list of all the keys. | `{var_name}.keys()` |
| Dictionary Values | A list of all the values. | `{var_name}.values()` |
| Copy Dictionary | An independent copy of the outer level. | `{var_name}.duplicate()` |
| Deep Copy | A copy of the record AND every list or record nested inside it. | `{var_name}.duplicate(true)` |

### Migrating a record written by an older build

| Name | What it does | Ships as |
|------|--------------|----------|
| Data Is Older Than Version | **Condition.** True when a loaded record was written by an older build than this one. | `(str({record}.get({field}, 0)).to_int() < {version})` |
| Rename Field | **Action.** Moves a value to its new field name, doing nothing when the old name is not there. | see below |
| Stamp Data Version | **Action.** Writes the current format number onto the record. | `{record}[{field}] = {version}` |

Rename Field emits three lines:

```gdscript
if save.has("hp"):
	save["health"] = save["hp"]
	save.erase("hp")
```

## Migrating old data

Data outlives the shape it was written in. A player's save file, a downloaded payload, a mod manifest, a
config, a `.tres` written by last month's build - all of them can arrive with fields you have since
renamed, or fields that did not exist yet.

The three rows above are a complete migration step, in the order you use them:

1. **Data Is Older Than Version** gates the migration. It reads the version field as text and converts,
   so a record with NO version field counts as 0 - which is how the very first format upgrades too - and
   so does one whose version field is empty, is `null`, or holds a word.
2. **Rename Field** moves each renamed value across. It does nothing at all when the old name is not
   there, which makes the whole migration safe to run twice.
3. **Stamp Data Version** writes the new number back, so the next load knows the record is current.

```
On save loaded
  Condition: Data Is Older Than Version  save, "version", 2
    -> Rename Field  save: "hp" -> "health"
    -> Rename Field  save: "mp" -> "mana"
    -> Set Key  save["difficulty"]  to  "normal"
    -> Stamp Data Version  save, "version", 2
```

```gdscript
if (str(save.get("version", 0)).to_int() < 2):
	if save.has("hp"):
		save["health"] = save["hp"]
		save.erase("hp")
	if save.has("mp"):
		save["mana"] = save["mp"]
		save.erase("mp")
	save["difficulty"] = "normal"
	save["version"] = 2
```

Note the new key with a sensible default in the middle: that is the other half of a migration, and Set
Key is all it needs.

## Use cases

**1. A save record built one field at a time.**

```
On save pressed
  -> Set Key  save["score"]  to  score
  -> Set Key  save["level"]  to  current_level
  -> Set Key  save["position"]  to  player.global_position
```

```gdscript
save["score"] = score
save["level"] = current_level
save["position"] = player.global_position
```

**2. Read it back without risking a missing key.**

```
On save loaded
  -> Set Score to  Get Key (with default)  save, "score", 0
  -> Set Level to  Get Key (with default)  save, "level", 1
```

```gdscript
score = save.get("score", 0)
level = save.get("level", 1)
```

Plain subscript access on a key that is not there errors. **Get Key (with default)** is the whole reason
a load routine does not need a guard row per field.

**3. Refuse to load a save that is missing the essentials.**

```
On save loaded
  Condition: Has All Keys  save, ["score", "level"]
    -> apply the save
  Else
    -> show "That save file is damaged."
```

```gdscript
if save.has_all(["score", "level"]):
```

**4. A first-run check.**

```
On Ready
  Condition: Dictionary Is Empty  settings
    -> write the default settings
```

```gdscript
if settings.is_empty():
```

**5. Settings with a user override layer.**

```
On settings loaded
  -> Set Defaults to  Copy Dictionary (shipped_settings)
  -> Merge Dictionary  user_settings  into  Defaults
```

```gdscript
defaults = shipped_settings.duplicate()
defaults.merge(user_settings, true)
```

**Merge Dictionary** overwrites on a clash, so the user's value wins - which is what an override layer
means. Copying the shipped record first keeps the shipped defaults intact for a "reset to defaults"
button.

**6. Kill counts keyed by enemy type.**

```
On enemy died
  -> Set Key  kills[enemy_type]  to  Get Key (with default) (kills, enemy_type, 0) + 1
```

```gdscript
kills[enemy_type] = kills.get(enemy_type, 0) + 1
```

The Get-with-default inside the Set is the count-up idiom: a type nobody has killed yet reads as 0 rather
than erroring, so there is no "first time" special case.

**7. Have I seen this enemy at all?**

```
On bestiary opened
  Condition: Has Key  kills, "slime"
    -> show the slime entry
  Else
    -> show a silhouette
```

```gdscript
if kills.has("slime"):
```

**8. List everything the player has killed.**

```
On bestiary opened
  For Each in  Dictionary Keys (kills)
    -> add a bestiary row for the current item
```

```gdscript
for item in kills.keys():
	add_bestiary_row(item)
```

**Dictionary Keys** and **Dictionary Values** both hand back a list, so every list row applies - Sort
Array on the keys for an alphabetical bestiary, Array Max on the values for the most-killed type.

**9. Total everything in a record.**

```
Set Total Kills to  Reduce ( Dictionary Values (kills) )  with  acc + x  from  0
```

```gdscript
total_kills = kills.values().reduce(func(acc, x): return acc + x, 0)
```

**10. Is anybody using this colour?**

```
On colour picked
  Condition: Has Value  player_colours, chosen_colour
    -> show "Someone already picked that colour."
```

```gdscript
if player_colours.values().has(chosen_colour):
```

**Has Value** scans the values, which is a linear search - fine for a lobby of eight, not for a record of
thousands. Keep a reverse record if you need that check to be cheap.

**11. Forget one setting.**

```
On reset binding pressed
  -> Delete Key  "jump"  from  keybinds
```

```gdscript
keybinds.erase("jump")
```

**12. Start a new game.**

```
On new game pressed
  -> Clear Dictionary  save
  -> Set Key  save["version"]  to  2
```

```gdscript
save.clear()
save["version"] = 2
```

**13. How many things are in this record?**

```
Every tick
  -> set CountLabel text = str( Dictionary Size (inventory_counts) ) + " kinds of item"
```

```gdscript
count_label.text = str(inventory_counts.size()) + " kinds of item"
```

**14. A preview the player can cancel out of.**

```
On preview opened
  -> Set Preview Save to  Deep Copy (save)
  -> apply Preview Save to the preview scene
```

```gdscript
preview_save = save.duplicate(true)
```

**Copy Dictionary** would share every nested record and list, so editing the "copy" would edit the real
save. **Deep Copy** is the one you want whenever the record has records inside it.

**15. Migrate a save written by an older build.**

```
On save loaded
  Condition: Data Is Older Than Version  save, "version", 2
    -> Rename Field  save: "hp" -> "health"
    -> Stamp Data Version  save, "version", 2
```

```gdscript
if (str(save.get("version", 0)).to_int() < 2):
	if save.has("hp"):
		save["health"] = save["hp"]
		save.erase("hp")
	save["version"] = 2
```

A record with no version field at all counts as version 0, so the very first save format your game ever
shipped migrates too, without a special case.

**16. Chain two migrations.**

```
On save loaded
  Condition: Data Is Older Than Version  save, "version", 2
    -> Rename Field  save: "hp" -> "health"
  Condition: Data Is Older Than Version  save, "version", 3
    -> Rename Field  save: "inv" -> "inventory"
  -> Stamp Data Version  save, "version", 3
```

Because Rename Field does nothing when the old name is absent, each step is safe whether or not the
previous one ran, and stamping once at the end is enough.

**17. Migrate a mod manifest, not just a save.**

```
For Each Resource In Folder  "res://mods"
  Condition: Data Is Older Than Version  entry.manifest, "format", 2
    -> Rename Field  entry.manifest: "author_name" -> "author"
    -> Stamp Data Version  entry.manifest, "format", 2
```

The same three rows serve a downloaded payload, a config, a spreadsheet row and a `.tres` - anywhere a
record outlives the build that wrote it. The version field does not have to be called `"version"`.

### Other use cases

**A quest log keyed by quest id.** Set Key writes the state, Has Key answers "is this quest known", and
Dictionary Keys drives the log's list without a second array to keep in sync.

**Per-language text overrides.** Merge Dictionary a language record on top of the base record and every
key the translation did not touch falls through to the original.

**A cooldown table keyed by ability name.** Get Key (with default) with a fallback of 0 makes an ability
that has never been used read as "ready" with no setup pass.

**Sparse tile metadata.** A record keyed by tile coordinate holds only the interesting tiles, so a large
map costs what the decorations cost rather than what the grid costs.

**Analytics counters.** One record of event-name to count, incremented with the Get-with-default idiom,
and Dictionary Keys plus Dictionary Values dumped as two lists when the run ends.

## Tips and common mistakes

- **Quote your keys.** `"gold"` is the key; `gold` is a variable. The key cell is an expression, so both
  compile - and pointing a row at an empty variable instead of the key you meant is the commonest way a
  record silently gains a key called `<null>`.
- **Get Key (with default) falls back only on a MISSING key.** A key holding `""`, `0` or `null` gives
  you that value, not your default. If empty should mean missing, test it explicitly - the Is Nothing
  condition covers all four empty shapes in one row.
- **Plain subscript reads error on a missing key.** Prefer Get Key (with default) unless you have just
  checked with Has Key.
- **Set Key adds as well as overwrites.** There is no separate add action, and no warning when you create a
  key by typo. A misspelled key writes fine and reads back as missing.
- **Copy Dictionary is shallow.** A settings record inside a copied save record is still the same object.
  Use **Deep Copy** whenever the record holds records or lists.
- **Merge Dictionary always overwrites on a clash.** There is no "keep mine" mode here - if you want the
  destination to win, merge the other way round.
- **Has Value is a linear scan** over every value in the record. Has Key is not. Do not put Has Value in a
  per-frame event over a large record.
- **Dictionary Keys and Dictionary Values give copies as lists.** Changing the list you get back does not
  change the record.
- **Data Is Older Than Version reads the version as text and converts.** That is deliberate: a payload
  carrying `"version": null` would crash a plain integer conversion, and taking down the gate that exists
  to make old data safe is the one failure it must not have. `null`, a word, and a missing field all read
  as 0, meaning "oldest".
- **Rename Field overwrites the destination** if the new name is already there. Run the renames in an
  order where that cannot bite, or delete the stale key first.
- **Stamp Data Version emits a plain key write**, so a stamped row reads back as a Set Key row when you
  reopen a `.gd`-backed sheet. The emitted code is identical either way - what changes on a reopen is the
  sentence the row draws, not the behaviour.
- **A record is not ordered the way a list is.** Godot preserves insertion order, but do not build logic
  that depends on a particular key coming first - sort Dictionary Keys when order matters.
