# Working with Values (and Copying Them Around)

A value you TYPED into a row is a known quantity. A value that was LOADED is not. It came out of a
save slot, a JSON field, a spreadsheet cell, a `.tres` somebody half-filled in, a method that can
hand back nothing, or another sheet entirely - and it might be missing, it might be the wrong shape,
and it might be a `0` that only looks like a failure.

This guide is about the second kind: asking whether a value is really there, giving it a fallback in
one row, naming one part of it in words, and then the other half of the same story - copying values
around safely. Copying between objects (presets, mirrors, pooled nodes), copying a resource without
editing the asset on disk, copying a value out to the player's clipboard as a share code, and copying
a value aside now so you can put it back later.

Everything here compiles to plain GDScript with no plugin dependency at runtime.
`(score if typeof(score) in [TYPE_INT, TYPE_FLOAT] else 0)` is exactly what ships.

## Table of Contents

1. [Is there anything there?](#1-is-there-anything-there)
2. [Give a value a fallback in one row](#2-give-a-value-a-fallback-in-one-row)
3. [Text that has to become a number](#3-text-that-has-to-become-a-number)
4. [Named parts of a pair, a colour, or a record](#4-named-parts-of-a-pair-a-colour-or-a-record)
5. [The shared .tres trap, and the copy that fixes it](#5-the-shared-tres-trap-and-the-copy-that-fixes-it)
6. [Pouring values from one object into another](#6-pouring-values-from-one-object-into-another)
7. [A folder of data assets as content](#7-a-folder-of-data-assets-as-content)
8. [Data that outlives the shape it was written in](#8-data-that-outlives-the-shape-it-was-written-in)
9. [Share codes and the clipboard](#9-share-codes-and-the-clipboard)
10. [Copying a live node in one row](#10-copying-a-live-node-in-one-row)
11. [Copying through time: remember and restore](#11-copying-through-time-remember-and-restore)
12. [Full reference](#12-full-reference)
13. [Use cases](#13-use-cases)
14. [Tips and common mistakes](#14-tips-and-common-mistakes)

---

## 1. Is there anything there?

"Is this empty" used to take four different rows and prior knowledge of the value's type: Text Is
Empty, Array Is Empty, Dictionary Is Empty, Is Null. Two conditions now ask it once, whatever the
value turns out to be:

- **Is Nothing** - true when there is nothing there.
- **Has Something** - the exact opposite, for when the FILLED case is the one you want to act on.

```
On Ready

  Is Nothing   save_data.get("name")
    -> Show           Control "NameEntry"
    -> Set Variable   first_run = true

  Else
    -> Set Text of "Greeting"   "Welcome back, " + Text Or(save_data.get("name"), "Player")
```

**In the editor**: Add Condition › **Compare: Types** › **Is Nothing** - the folder where Value Is Of
Type already lives. The opposite branch is either the shipped **Add 'Else'** or Has Something picked
directly.

Nothing is spelled as the four empty values a sheet actually meets: **no value at all, empty text, an
empty list, an empty record.** Two deliberate exclusions:

- **A `0` is NOT nothing**, and neither is `false`. A score of zero and a switch that is off are real
  values, and a guard that swallowed them would be a bug factory.
- **Text made only of spaces is not nothing** either - that is the shipped **Text Is Blank**, which
  is a different question.

An empty **Split Text** result counts as nothing, which is worth saying out loud: Split Text hands
back a `PackedStringArray`, and an empty one does not equal an empty `Array`, so a hand-rolled
comparison would have read "there is something" there.

---

## 2. Give a value a fallback in one row

Five expressions hand a value back only when it really is the kind of thing you asked for, and your
own default otherwise. One row replaces a guard row plus a conversion, and an untyped value can go
straight into a typed variable.

| Name | Hands the value back when it is | Otherwise |
| --- | --- | --- |
| **Number Or** | an int or a float (a `0` counts) | your default |
| **Text Or** | text with something in it | your default |
| **List Or** | a list with items in it (a Split Text result counts) | your default |
| **Record Or** | a record with keys in it | your default |
| **Value Or** | anything at all that is not null | your default |

```
On After Load
  -> Set Variable   score       = Number Or(save_data.get("score"), 0)
  -> Set Variable   player_name = Text Or(save_data.get("name"), "Player")
  -> Set Variable   inventory   = List Or(save_data.get("items"), [])
  -> Set Variable   settings    = Record Or(save_data.get("options"), {})
```

**In the editor**: Add Action › Variables › **Set Variable**, then press **ƒx** on the Value field ›
**Variables** › **Number Or**. That is the real category where Set Variable and Toggle already live.

Three things to know:

- **Number Or keeps a zero.** A score of `0` is a real number and passes through. Only Text Or, List
  Or and Record Or treat emptiness as a miss, and Value Or guards nothing but null - a `0`, a blank
  text and an empty list are all real values there.
- **Pair them with Get Key (with default)**, do not replace it. That shipped expression covers a MISSING
  key; these cover a key that is present but holds the wrong shape. `Record Or(save.get("options"),
  {})` plus Get Key on the result means a whole missing settings block reads as defaults.
- **Keep the value a plain read.** The guard re-reads the value expression in the emitted line, so
  something that CHANGES the game each time it is read (a method that consumes, deals or advances)
  would run twice per row.

---

## 3. Text that has to become a number

The shipped To Integer, To Decimal, Text To Int and Text To Float all answer `0` for `"abc"`, for
`""` and for `"0"` alike, so a typo in an amount box arrives as a real-looking bet of nothing. Two
conditions ask first, and two expressions convert with a fallback YOU chose:

```
LineEdit "Amount"   On Text Submitted

  Text Is A Number   $Amount.text
    -> Set Variable   bet = Number From Text($Amount.text, 0)

  Else
    -> Set Text of "Hint"   "Numbers only, please"
```

**Text Is A Number** and **Text Is A Whole Number** are in **Compare: Text**; **Number From Text** and
**Whole Number From Text** are in **Variables: String**, right beside the silent-zero conversions they
exist to replace. `"12.5"` is not a whole number, so Whole Number From Text lands on the fallback
rather than quietly becoming `12`.

The shipped templates are unchanged and still ship - the checked pair sits beside them, so nothing
you already built moves.

---

## 4. Named parts of a pair, a colour, or a record

`velocity.y` works, but it does not read as a sentence and it is not discoverable in a picker. Two
rows name the piece instead:

- **Part Of** reads one named part of a Vector2, a Vector3, a Color or a record.
- **Set Part Of** writes one, and leaves the rest alone.

The part is a dropdown in plain words: X (left / right), Y (up / down), Z (forward / back), Red,
Green, Blue, Alpha (see-through).

```
Every Frame

  Compare Values   Part Of(velocity, Y (up / down)) > 0
    -> Play animation   "fall"

  Compare Values   Part Of(velocity, Y (up / down)) < 0
    -> Play animation   "jump"

Area2D "Water"   On Body Entered
  -> Set Part Of    velocity, Y (up / down), 0
  -> Set Variable   fade_from = Part Of(modulate, Alpha (see-through))
```

**In the editor**: in any number field press **ƒx** › **Variables: Vector** › **Part Of**, then pick
the part from the dropdown. The write side is Add Action › **Variables: Vector** › **Set Part Of**.

Four notes:

- **One row covers four types.** The emitted access is a subscript with a quoted key, which Godot
  resolves as a component on Vector2 / Vector3 / Color and as a field on a Dictionary. That is why a
  saved `{"x": …, "y": …}` position needs no special case.
- **Set Part Of on a record ADDS the field** when it is not there yet.
- **Pick a part the value actually has.** For a record field that might be missing, the shipped
  **Get Key (with default)** is the right expression, because it takes a fallback and Part Of does not.
- **The target of Set Part Of is a property field**, not a variables dropdown, because the headline
  targets are a node's own members (`velocity`, `modulate`, `position`) which a closed variables list
  cannot name at all. A sheet variable is typed into the same cell.

---

## 5. The shared .tres trap, and the copy that fixes it

This is Godot's most expensive beginner trap, and it is worth stating plainly:

> A `.tres` dropped on ten nodes is ONE object. Writing to it at runtime edits the asset that all ten
> see - and in a `@tool` sheet, it writes back to disk.

So the enemy that scales its stats on ready scales EVERY enemy, permanently, including the copy in
your repository. Three rows name the fix, and naming the deep-versus-shallow choice is the point -
the trap bites precisely because nothing said which copy you were getting:

| Name | Copies | Reach for it when |
| --- | --- | --- |
| **Copy Resource (Independent)** | the resource AND the resources inside it | a node is about to edit its own stats |
| **Copy Resource (Share Sub-Resources)** | the outer fields only; inner resources stay shared | you WANT that sharing, deliberately |
| **Deep Copy** | an array or a record, right through every nested list | Copy Array / Copy Dictionary only copy the outer level |

```
Enemy   On Ready
  -> Set Property   "stats" of Enemy to Copy Resource (Independent) of enemy_stats
  -> Set Property   "stats.health" of Enemy to stats.health * difficulty_scale
```

The DETECTION half needs nothing new. The shipped **Is The Same Object** (Add Condition ›
**Compare: Objects**) answers "are these two actually one object", and pointing it at two resources
IS the whole check:

```
  Is The Same Object   this_enemy.stats, enemy_stats
    -> Log            "still pointing at the asset - edits would leak"   as Warning
    -> Set Property   "stats" of Enemy to Copy Resource (Independent) of stats
```

**In the editor**: Add Action › Variables › **Set Variable**, then **ƒx** › **Helpers** ›
**Copy Resource (Independent)**. Deep Copy sits beside the shipped Copy Array under **Variables:
Array** and beside Copy Dictionary under **Variables: Dictionary**.

Anything that is not a resource - including nothing at all - gives nothing back rather than erroring,
so a preset slot nobody filled in is not a crash.

---

## 6. Pouring values from one object into another

Set Property does ONE property per row, so a six-property mirror is six rows. Duplicate Node clones
wholesale but cannot write onto a node that already exists. Four rows cover the middle ground, and
all four address fields BY NAME:

| Name | Kind | Does |
| --- | --- | --- |
| **Copy Values From** | Action | pours a named list of values off another object onto this one (blank list = every variable the source's script declares) |
| **Fill Blanks From** | Action | writes a base's values ONLY into fields the target left empty |
| **Apply Preset To Node** | Action | pours a data asset's fields onto the same-named properties of a node |
| **Matches Properties Of** | Condition | true while the listed properties hold the same values on both objects |

```
Object Pool   On Spawned
  -> Copy values   "speed, damage, modulate"   from $EnemyTemplate
  -> Copy values   "global_position, rotation" from $SpawnPoint

Enemy   On Ready
  -> Apply preset     difficulty_presets[chosen_difficulty]   to Enemy
  -> Fill blanks in   Enemy   from base_enemy_tuning

  Matches properties   "position, rotation"   of $Player
    -> Set Variable   ghost_is_synced = true
```

**In the editor**: Add Action › **Helpers** › **Copy Values From**. "Helpers" is the real category
where Set Property and Get Property already live.

The asymmetry between the three POURING actions and the one COMPARISON is deliberate:

- The pouring actions **skip a name the receiving side does not have**, which is exactly what lets one
  preset serve several node types.
- Matches Properties Of goes the other way: **a name the object under test does not have reads as NOT
  matching**, so a misspelled or renamed field shows up instead of quietly reporting "still in sync".
  Either side being gone also reads as not matching, because "the ghost was freed" is precisely when
  this condition gets asked.

Fill Blanks From is the override chain: a base item plus a rarity variant, a shipped table plus a mod
file. Empty means nothing there - no value at all, blank text, an empty list or an empty record -
and a `0` or a `false` is a real value that is kept, exactly as Is Nothing and Missing Fields read
them.

---

## 7. A folder of data assets as content

"Content lives in files" becomes vocabulary with four expressions, so a folder of `.tres` IS your item
list, enemy roster, level manifest, card set, or the mod folder a player dropped things into:

| Name | Gives you |
| --- | --- |
| **Resources In Folder** | every `.tres` / `.res` in a folder, loaded, as a list |
| **Resource In Folder** | one of them by file name, or nothing when there is no such file |
| **Load Resource Or Default** | a load that hands back YOUR fallback instead of erroring |
| **Count Of Resources In** | how many there are, counted without loading any |

```
On Ready
  -> Set Property   "weapon" of Player to Resource In Folder("res://data/weapons", "rusty_sword")
  -> Set Property   "stats" of Boss   to Load Resource Or Default("res://mods/boss.tres", fallback_stats)

  Compare Values   Count Of Resources In("res://mods") > 0
    -> Log   "mod content loaded"
```

**In the editor**: Add Action › Variables › **Set Variable**, then **ƒx** on the Value field ›
**Files** › **Resource In Folder**. "Files" is the real folder holding File Exists and Read Text File.

Three guarantees these carry that a hand-rolled walk usually does not:

- **A missing folder is not a fault.** "The mod folder does not exist yet" is the normal case, so the
  directory is tested first and the walk quietly yields nothing. Without that test the engine prints
  a red error, and a loop that runs every frame would spam it.
- **An exported project still finds the files.** A converted `res://` text resource is stored as
  `<name>.tres.remap` in an export, so the trailing `.remap` is trimmed BEFORE the extension test - a
  naive extension check finds nothing there while working perfectly in the editor.
- **A file that fails to load is left out**, not handed to you as nothing. A null in a list your help
  calls "your content" is a dead item the first `entry.field` trips over.

The looping form is **For Each Resource In Folder** (folder: Loops), which walks a folder as a real
loop row with the current entry available as `entry`.

---

## 8. Data that outlives the shape it was written in

A save file written by last month's build, a downloaded payload, a mod manifest, a config, a `.tres`
whose fields were renamed. Three rows turn "old saves crash" into a visible, editable rule:

```
On After Load
  -> Parse JSON Into Variable   save   from Read Text File("user://save.json")

  Data Is Older Than Version   save, "version", 3
    -> Rename field       "hp" to "health" in save
    -> Set Key            save["room"] to Get Key (with default) save, "room", "start"
    -> Stamp data version save, "version", 3
    -> Log                "migrated a v1 save"

  Has All Keys   save, ["health", "room"]
    -> Call Function   apply_save(save)
```

**In the editor**: Add Condition › **Variables: Dictionary** › **Data Is Older Than Version**, then
Add Action › **Variables: Dictionary** › **Rename Field** and **Stamp Data Version**. One older shape
per branch reads well with the shipped **Add 'Else If'**.

- **A record with NO version field counts as 0**, so the very first format upgrades too - and so does
  one whose version field is empty, is null, or holds a word rather than a number. That matters,
  because a migration gate that crashed on a null would take down the very thing that makes old data
  safe.
- **Rename Field does nothing at all when the old name is not there**, so a migration is safe to run
  twice.
- **Stamp Data Version writes the number back** so the next load knows the record has already been
  migrated.

One honest note about reopening: Stamp Data Version emits a plain subscript write, character for
character what the shipped **Set Key** emits. The code is identical either way, but a `.gd`-backed
sheet reopened later reads that row back as Set Key. That was the deliberate trade - the alternative
was re-labelling every hand-written `config["count"] = value` in your project as a version stamp.

---

## 9. Share codes and the clipboard

### Any value in, one pasteable line out

Four rows turn any value into a compact tagged code and back again. Because the payload is a plain
Variant, the same four carry a run seed, a loadout, a colour preset, a whole save record, or a level
layout:

```
On Action Just Pressed   "copy_seed"
  -> Copy share code for   run_seed   to clipboard
  -> Show toast            "Seed copied - paste it to a friend"

On Action Just Pressed   "paste_seed"
  -> Set Variable   pasted = Clipboard Text

  Share Code Is Valid   pasted
    -> Set Variable        run_seed = Value From Share Code(pasted)
    -> Generate from seed  run_seed, 5 depths, 4 rooms each

  Else
    -> Show toast   "That code did not decode"
```

**In the editor**: Add Action › **Utility: Window** › **Copy Share Code To Clipboard** - the real
folder where Set Clipboard Text already lives. The gate is Add Condition › **Utility: Window** ›
**Share Code Is Valid**.

Why the encoding is what it is, since it decides what you can send:

- **Types survive the round trip.** An int comes back an int, a Vector2 comes back a Vector2, and
  nested lists and records keep their shape. JSON would flatten every number to a float and has no
  Vector at all.
- **It is one line with no spaces or newlines**, so it survives a chat box.
- **A hostile code cannot instantiate anything.** The decoder refuses to build objects by default.

**Share Code Is Valid** is the load-bearing one: ask it when the pasted text CHANGES (a Paste button,
On Text Changed) rather than every frame. A code a chat client truncated is refused in silence three
times out of four, but a tagged payload that is the right shape and still garbage does reach the
decoder, and the engine logs a line each time it refuses.

### Reading the clipboard

The shipped clipboard vocabulary is write-only plus one blind read. Four more rows are the gates a
paste box actually needs:

```
Has Changed   Clipboard Text

  Clipboard Has Text
    -> Set Variable      pending_code = Clipboard Text
    -> Set Text of "CodeBox"   pending_code

On Action Just Pressed   "paste"

  Clipboard Has Image
    -> Set Variable   pasted_image = Clipboard Image
    -> Set Property   "texture" of $Avatar to ImageTexture.create_from_image(pasted_image)
```

**Clipboard Text Is** compares the clipboard against a value with the full operator dropdown. There
is deliberately no "On Clipboard Changed" trigger: the shipped **Has Changed** already turns any
expression, including Clipboard Text, into an edge.

---

## 10. Copying a live node in one row

The shipped **Duplicate Node** is an expression whose own help tells you to add the clone yourself, so
the everyday copy costs three rows and a throwaway variable. **Clone Into** does duplicate, add, place
and optionally group in one action:

```
On Action Just Pressed   "split"
  -> Clone   self   into get_parent()   at global_position + Vector2(24, 0),   group "enemies"

Health   On Death
  Compare Values   drop_chance > randf()
    -> Clone   $LootTemplate   into get_parent()   at global_position,   group "pickups"
```

**In the editor**: Add Action › **Nodes** › **Clone Into**, where Duplicate Node and Add Child already
sit.

The position is only used when the copy actually has one (a Node2D, Node3D or Control), so pointing it
at a plain Node is harmless. The group is added as a PERSISTENT group, which matters more than it
sounds: a non-persistent group is dropped when a node is packed into a scene, and every group check
then silently never fires.

Starting from a `.tscn` file instead? That is **Spawn Scene (Full)**, which already does position,
rotation and an optional group in one row. Reusing nodes rather than making new ones? That is the
Object Pool pack.

---

## 11. Copying through time: remember and restore

The other copy is the one that travels through TIME rather than between objects: put a value aside
now under a label, pour it back later. Preview-then-cancel in a settings panel, before-the-buff values
for a temporary modifier, a camera pose stashed before a cutscene, undo in an in-game level editor.

| Name | Kind | Does |
| --- | --- | --- |
| **Remember Value As** | Action | copies any value aside under a name |
| **Restore Value Into** | Action | pours it back into a variable (left alone when nothing was remembered) |
| **Remembered Value** | Expression | reads it without pouring it back, with your fallback |
| **Has Remembered** | Condition | true when something was remembered under that name this run |
| **Forget Remembered** | Action | drops it, so Has Remembered reads false again |

```
On Button Pressed

  Button is   "Preview"
    -> Remember       ui_scale as "ui_scale_before"
    -> Set Variable   ui_scale = preview_scale

  Button is   "Cancel"
    Has Remembered   "ui_scale_before"
      -> Restore           "ui_scale_before" into ui_scale
      -> Forget remembered "ui_scale_before"

  Button is   "Apply"
    -> Forget remembered   "ui_scale_before"
```

**In the editor**: Add Action › **Run Context** › **Remember Value As** - the real folder where Has
Changed, Trigger Once and Only Once Ever already live. The gate is Add Condition › **Run Context** ›
**Has Remembered**.

Values are keyed by NAME in node metadata, exactly like the shipped named cooldowns, so a Remember in
one row and a Restore in a completely different event agree with no declared variable between them and
no member state to maintain.

Three neighbours read similarly and it is worth being clear which is which:

- **Remember Value As** - this run only, in memory. Closing the game forgets it.
- **Remember Between Runs** (on the variable's own menu) - persists to disk across runs.
- The **Save System pack** - a full slot on disk, with formats, backups and a load menu.

---

## 12. Full reference

### Asking and defaulting (folders: Compare: Types, Variables, Compare: Text, Variables: String)

| Name | Kind | Emits |
| --- | --- | --- |
| Is Nothing | Condition | an `in [null, "", [], {}]` test plus the packed-array clause |
| Has Something | Condition | the same, negated |
| Number Or | Expression | `(value if typeof(value) in [TYPE_INT, TYPE_FLOAT] else fallback)` |
| Text Or | Expression | the same with `TYPE_STRING`, plus a not-empty test |
| List Or | Expression | the same for `TYPE_ARRAY` and the packed families |
| Record Or | Expression | the same with `TYPE_DICTIONARY` |
| Value Or | Expression | `(value if value != null else fallback)` |
| Text Is A Number | Condition | `str(text).strip_edges().is_valid_float()` |
| Text Is A Whole Number | Condition | `str(text).strip_edges().is_valid_int()` |
| Number From Text | Expression | the checked `to_float()`, else your fallback |
| Whole Number From Text | Expression | the checked `to_int()`, else your fallback |

### Named parts (folder: Variables: Vector)

| Name | Kind | Emits |
| --- | --- | --- |
| Part Of | Expression | `(value)["y"]` - a component on a Vector or Color, a field on a record |
| Set Part Of | Action | `target["y"] = value` |

### Copying objects and data (folders: Helpers, Variables: Array, Variables: Dictionary, Nodes)

| Name | Kind | Emits |
| --- | --- | --- |
| Copy Resource (Independent) | Expression | `resource.duplicate(true)`, guarded |
| Copy Resource (Share Sub-Resources) | Expression | `resource.duplicate(false)`, guarded |
| Deep Copy | Expression | `list.duplicate(true)` (also on Dictionary variables) |
| Copy Values From | Action | a named-field loop, or the source script's declared variables |
| Fill Blanks From | Action | the same loop, writing only into empty fields |
| Apply Preset To Node | Action | the resource's script variables onto same-named node properties |
| Matches Properties Of | Condition | an `all()` over the named properties, both sides null-guarded |
| Clone Into | Action | `duplicate()`, `add_child()`, place, optional persistent group |

### Data assets and migration (folders: Files, Variables: Dictionary)

| Name | Kind | Emits |
| --- | --- | --- |
| Resources In Folder | Expression | the guarded folder walk, `.remap` trimmed, loaded, nulls dropped |
| Resource In Folder | Expression | `load(folder/name.tres)` when `ResourceLoader.exists`, else null |
| Load Resource Or Default | Expression | `(load(path) if ResourceLoader.exists(path) else fallback)` |
| Count Of Resources In | Expression | the same walk, counted, nothing loaded |
| Data Is Older Than Version | Condition | `(str(record.get(field, 0)).to_int() < version)` |
| Rename Field | Action | the has-then-move-then-erase trio |
| Stamp Data Version | Action | `record[field] = version` |

### Copying out and back (folders: Utility: Window, Run Context)

| Name | Kind | Emits |
| --- | --- | --- |
| Share Code For | Expression | the tag plus `Marshalls.variant_to_base64(value)` |
| Copy Share Code To Clipboard | Action | the same, straight into `DisplayServer.clipboard_set` |
| Share Code Is Valid | Condition | tag test, two shape tests, then the decode |
| Value From Share Code | Expression | `Marshalls.base64_to_variant` on the untagged payload |
| Clipboard Has Text | Condition | `DisplayServer.clipboard_has()` |
| Clipboard Has Image | Condition | `DisplayServer.clipboard_has_image()` |
| Clipboard Image | Expression | `DisplayServer.clipboard_get_image()` |
| Clipboard Text Is | Condition | `DisplayServer.clipboard_get() {op} value` |
| Remember Value As | Action | `set_meta(&"__ef_mem_" + name, value)` |
| Restore Value Into | Action | `var_name = get_meta(&"__ef_mem_" + name, var_name)` |
| Remembered Value | Expression | `get_meta(&"__ef_mem_" + name, fallback)` |
| Has Remembered | Condition | `has_meta(&"__ef_mem_" + name)` |
| Forget Remembered | Action | a guarded `remove_meta` |

---

## 13. Use cases

### 1. A save slot that was never written

Is Nothing on the loaded name shows the name-entry panel and sets `first_run`, instead of greeting
"Welcome back, ".

### 2. A save file from a build that stored less

Number Or, Text Or, List Or and Record Or turn four possibly-missing fields into four typed variables
in four rows, with no guard row in front of any of them.

### 3. A jump-or-fall animation gate

Part Of(velocity, Y (up / down)) reads as a sentence in the row and drives the two animation branches.

### 4. Zeroing vertical speed on landing

Set Part Of leaves the horizontal speed exactly as it was, which is what a landing needs and what a
whole-vector assignment destroys.

### 5. An enemy that scales its own stats

Copy Resource (Independent) first, THEN multiply - otherwise every enemy in the game (and the `.tres`
in your repository) gets the boss's difficulty scaling.

### 6. Catching the leak you already have

Is The Same Object between a node's stats and the shared asset prints a warning the first time you
run, and the fix is one Copy Resource (Independent) row.

### 7. Difficulty tiers as data

Apply Preset To Node pours a `.tres` per difficulty onto the boss, so "hard mode is different" is a
data edit rather than a wall of Set Property rows.

### 8. A pooled node reset to its template

Copy Values From with `"speed, damage, modulate"` on the pool's spawn event puts a reused node back to
factory settings in one row.

### 9. A ghost that must stay in sync

Matches Properties Of over `"position, rotation"` is the cheap per-frame check, and a renamed property
reads as NOT matching so the typo surfaces.

### 10. Base item plus rarity variant

Fill Blanks From writes the base tuning only into the fields the variant left empty, which is the
override chain a content pipeline reaches eventually.

### 11. A mod folder the player fills

Resources In Folder over `res://mods` loads whatever is there, gives an empty list when the folder does
not exist yet, and never hands you a null for a file that failed.

### 12. Old saves that keep working

Data Is Older Than Version gates a Rename Field and a Stamp Data Version, and a save with no version
field at all counts as 0 so the very first format upgrades too.

### 13. A run seed a player can paste to a friend

Copy Share Code To Clipboard on a hotkey, Share Code Is Valid gating the paste, Value From Share Code
feeding the generator.

### 14. A paste box that refuses garbage

Clipboard Has Text gates the button, Share Code Is Valid gates the decode, and the Else branch says so
instead of generating a broken level.

### 15. Preview-then-cancel in the options menu

Remember Value As on Preview, Has Remembered plus Restore Value Into on Cancel, Forget Remembered on
Apply - three buttons, no extra variable, no member state.

**Other use cases**: **a pasted avatar screenshot** (Clipboard Has Image plus Clipboard Image into an
ImageTexture), **an afterimage trail** (Clone Into the live sprite, then tint the copy), **a
character creator's colour swatch** (Part Of on the Alpha part to fade only transparency), **a working
copy of a level record in an in-game editor** (Deep Copy so undo can restore the original), and **a
shop whose stock is decremented per visit** (Copy Resource (Independent) of the table so the shipped
asset stays clean).

---

## 14. Tips and common mistakes

- **A `0` is a real value.** Is Nothing does not treat it as empty and Number Or keeps it. If you
  genuinely want "zero or missing", compare the value after defaulting it.
- **A `.tres` on ten nodes is one object.** Copy Resource (Independent) BEFORE the first write, or the
  asset on disk changes - and in a `@tool` sheet it changes now, not at runtime.
- **Copy Array and Copy Dictionary are shallow.** A nested list inside the copy is still the
  original's list. Deep Copy is the one that goes all the way down.
- **Keep a guarded value expression a plain read.** Number Or, Text Or, List Or, Record Or, Value Or,
  Number From Text and Whole Number From Text all read their input twice in the emitted line.
- **Pouring skips unknown names; comparing does not.** That asymmetry is on purpose: one preset
  serving several node types needs the skip, and a renamed field must not report "still in sync".
- **Apply Preset To Node does nothing when the preset slot is empty**, which is the common case for a
  slot nobody filled in - so check it with Is Nothing if silence would hide a bug.
- **Ask Share Code Is Valid on a change, not every frame.** A malformed but correctly shaped code
  reaches the decoder, and the engine logs a line each time it is refused.
- **Remember Value As does not survive closing the game.** For that, use Remember Between Runs on the
  variable, or the Save System pack.
- **Restore Value Into leaves the variable alone** when nothing was remembered under that name, so a
  Cancel button that never previewed does nothing rather than writing a null.
- **A missing folder is normal.** Resources In Folder and Count Of Resources In check the directory
  first and quietly answer empty, so a per-frame loop cannot spam engine errors.
