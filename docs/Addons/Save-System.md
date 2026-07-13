# Save System - Slot-Based Persistence Any Sheet Can Write To

Save System is a Godot EventSheets behavior pack that stores your game's values to disk and reads them back, keyed by name. It is an **autoload singleton**: you register the `SaveSystemAddon` sheet once as the `SaveSystem` autoload, and from then on every sheet in your project calls its ACEs as `SaveSystem: Save Number`, `SaveSystem: Save Game`, and so on. There is no save object to pass around. A save file is just a bag of `key -> value` pairs living in one **slot** (each slot is its own file), and where those files go, what they are named, whether they are encrypted, and whether they are config, JSON, binary, CSV, INI, or XML is all set once in the Inspector. The headline trick is the lifecycle broadcast: calling **Save Game** fires **On Before Save** so every sheet writes its own piece, then confirms with **On Save Written**; calling **Load Game** fires **On After Load** so every sheet reads its own piece back. No sheet needs to know what any other sheet saves. This pack is itself an event sheet, so its deepest extension point is opening it and adding your own functions.

---

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [ACE reference](#ace-reference)
5. [Use cases](#use-cases)
6. [Tips and common mistakes](#tips-and-common-mistakes)

---

## Where this pack shines

- **Coins, score, and currency that survive a restart.** Write a running total with **Save Number** and read it back with **Load Number** on the next launch.
- **Multiple save slots.** Each slot is its own file, so a three-slot menu is just three values of the `slot` property and one **Save Game** call.
- **A proper save/load menu.** **List Slots** gives you the filled slots, **Slot Exists** checks one, and **Slot Modified Time** stamps each entry with when it was last written.
- **Options and settings.** Volume, difficulty, and toggles persist with **Save Number** / **Save Text** and reload with their **Load** partners.
- **Checkpoints and autosave.** Set `autosave_interval` in the Inspector and the pack calls **Save Game** for you on a timer, firing **On Before Save** first.
- **Quest flags and unlocked levels.** Store booleans and progress markers as numbers or text under stable keys.
- **Whole inventories and structured data.** **Save Value** writes any type - a Vector2 position, a Color, or an entire Dictionary - so a bag of items is one key.
- **Every sheet contributes its own state.** A dozen unrelated sheets each answer **On Before Save** by writing their piece and **On After Load** by reading it, with zero central "save manager".
- **A behavior's own runtime state persists.** Stateful packs across the project expose `save_state` and `load_state`, so a StatForge node's buff stack or a Health node's pools ride into the save with **Save Node State** - no manual key-by-key copying.
- **One node, group, or autoload in a single row.** **Save Node State** snapshots an object and every behavior on it, **Save Group State** snapshots a whole squad by group, and **Save Singleton State** snapshots an autoload economy by name.
- **Whole-scene persistence with no extra rows.** Drop nodes into the `persist_group` and **Save Game** snapshots them (and their behaviors) automatically, restoring them on **Load Game**.
- **Continue vs New Game.** **Slot Exists** or **Has Save Key** decides whether the Continue button lights up.
- **Deleting a save.** **Delete Slot** removes the active slot's file straight from a manage-saves screen.
- **Tamper-resistant saves.** Set an `encryption_key` in the Inspector and the files are written encrypted with no change to your sheets.
- **Debuggable, spreadsheet-friendly, or compact saves.** Switch the `format` Inspector property to `json` or `csv` for readable text you can diff and hand-edit, or to `binary` for a compact ship build.

---

## Core concepts

The model is small. Learn these ideas and the rest of the pack is just calling the right verb.

**One shared singleton, called by name.** Save System is registered as the `SaveSystem` autoload, so there is a single instance for the whole game. Any sheet reaches it the same way: `SaveSystem: Save Number`, `Condition: SaveSystem  Has Save Key`, or the inline expression `SaveSystem.Load Number("coins")`. You never create or pass around a save object.

**A save is keys and values.** Everything you store lives under a string **key** you choose - `"coins"`, `"level"`, `"player_pos"`. Writing the same key again overwrites it. Reading a key that was never written gives you the default you pass in. Keep your keys stable across versions and match them exactly between the save and the load.

**Slots are separate files.** The `slot` Inspector property (0 to 9) picks which file you are reading and writing. Slot 0 and slot 1 never see each other's keys. To move to a different slot, set the `SaveSystem.slot` property before you save or load - there is no per-call slot argument on the write and read verbs. The metadata verbs (**Slot Exists**, **List Slots**, **Slot Modified Time**) take a slot number directly so a menu can inspect every slot without switching the active one.

**Two ways to write, two ways to read.** The direct verbs write and read immediately: **Save Number**, **Save Text**, and **Save Value** flush a single key to the active slot's file the instant you call them, and **Load Number**, **Load Text**, and **Load Value** read a single key back. You do not need **Save Game** to persist one value - a direct **Save Number** is already on disk.

**The lifecycle broadcast is the headline.** **Save Game** is the coordinator. It fires **On Before Save** (so every sheet that answers it writes its own piece with the direct verbs), snapshots the persist group, flushes the file, then fires **On Save Written** (your cue for a "Saved!" toast). **Load Game** is its mirror: it restores the persist-group snapshots, then fires **On After Load** so every sheet reads its own keys back with the direct verbs. This is what lets a large project save without any one sheet knowing what the others store - each sheet owns its slice of the save.

**Behaviors carry their own state through the save-state seam.** Stateful addons across the project - StatForge, Health, Currency Ledger, Skin Vault, Timer, State Machine, the incremental packs, Weapon Kit, and more - now expose two plain methods, `save_state() -> Dictionary` and `load_state(state)`. The Save System duck-types these: any node with a `save_state` method participates, no registration needed. This is what lets a behavior's internal runtime state - a StatForge node's buff stack, a Health node's pools - survive a save. Before the seam existed, that state lived only in the behavior and was unreachable by the key-value verbs, so you had to copy each field out by hand; now **Save Node State**, **Save Group State**, and **Save Singleton State** capture it whole.

**The persist group saves a whole scene for free.** The `persist_group` Inspector property (default `"persist"`) names a scene-tree group. **Save Game** automatically snapshots every node in that group (and every behavior on those nodes, through the same `save_state` seam), and **Load Game** restores those snapshots before it fires On After Load. Whole-scene persistence therefore needs zero extra rows - you just add the nodes you care about to the group and let Save Game find them.

**Load takes a default.** **Load Value** takes an explicit `default_value` returned when the key is missing, which is exactly the first-run case. The typed conveniences bake their own default in: **Load Number** returns `0` when missing and **Load Text** returns an empty string. Pair a load with **Has Save Key** when you need to tell "saved a zero" apart from "never saved".

**Storage strategy lives in the Inspector, not your sheets.** Where files go (`save_directory`), how they are named (`file_pattern`, which must contain `{slot}`), which section or namespace holds the values (`section`), the on-disk `format` (config, JSON, binary, CSV, INI, or XML), the `encryption_key`, the `persist_group`, and the optional `autosave_interval` are all Inspector knobs. Your sheets only ever deal in keys and values, so you can change storage strategy without touching a single event row.

**Six on-disk formats.** `config` is the native Godot ConfigFile and round-trips Godot types best. `json` is readable, diffable text, and it preserves rich types like Vector2 and Color through an internal wrapper, and wraps integers too so a whole number stays an integer instead of reloading as a float (floats, strings, and booleans stay bare and readable). `binary` is a compact `store_var` dump - the smallest files, but not meant to be hand-edited. `csv` writes plain `key,value` rows a spreadsheet can open, and a hand-authored CSV in the same shape loads straight back, which makes it a handy balancing surface. `ini` writes a plain, portable `[section]` header with `key=value` lines that other INI tools can read the structure of. `xml` writes structured `<entry>` tags for pipelines and tools that expect XML. Every format reloads your values with the exact types you saved.

---

## Setup

**1. Register the autoload.** In your Godot project settings, add the pack's `SaveSystemAddon` script as an autoload named exactly `SaveSystem` (the pack sheet lives at `eventsheet_addons/save_system/save_system_addon.gd`). Once it is an autoload, every sheet can call `SaveSystem` verbs. The autoload node is a `Node`.

**2. Set the Inspector strategy.** Select the `SaveSystem` autoload and decide how saves are stored:

| Property | Default | What it does |
|---|---|---|
| `slot` | `0` | Active save slot (0 to 9). Each slot is its own file. Set this before Save Game / Load Game to target another slot. |
| `save_directory` | `user://` | Folder the save files live in. |
| `file_pattern` | `save_{slot}.cfg` | File name template. `{slot}` is replaced with the slot number, so keep it in the pattern. |
| `section` | `save` | The config section / JSON namespace the values are grouped under. |
| `format` | `config` | `config` (native ConfigFile), `json` (readable text, rich types preserved), `binary` (compact, not hand-editable), or `csv` (spreadsheet-friendly key,value rows). |
| `persist_group` | `persist` | Scene-tree group Save Game snapshots automatically (nodes plus their behaviors); Load Game restores it before On After Load. |
| `encryption_key` | (empty) | Non-empty means saves are written encrypted. Keep the key out of screenshots and shared code. |
| `autosave_interval` | `0` | Seconds between automatic Save Game calls (0 = off). Fires On Before Save first. |

**3. Wire the golden loop.** The pattern is four moves: each sheet writes its state on **On Before Save**, reads it back on **On After Load**, a Save button calls **Save Game**, and a Load button calls **Load Game**. Here is a complete first setup that persists coins and the current level:

```
On Before Save
  -> SaveSystem: Save Number  "coins", Player.coins
  -> SaveSystem: Save Number  "level", Level.index

On After Load
  -> Set Player.coins to  SaveSystem.Load Number("coins")
  -> Set Level.index to   SaveSystem.Load Number("level")

On Button Pressed "SaveButton"
  -> SaveSystem: Save Game

On Button Pressed "LoadButton"
  -> SaveSystem: Load Game

On Save Written
  -> HUD: show "Game saved" toast
```

**Save Game** broadcasts On Before Save, so both `Save Number` rows run and write to the active slot's file, then On Save Written pops the toast. **Load Game** broadcasts On After Load, so both values are read back into the game. Because the writing and reading live next to the objects that own them, you can add a third sheet that saves its own keys the same way without editing this one.

---

## ACE reference

All ACEs live in the **Save System** category and are called on the `SaveSystem` autoload singleton. There is no save-object parameter anywhere.

### Actions

| Action | Parameters | Description |
|---|---|---|
| Save Value | `key` (String), `value` (any) | Writes any value - a number, text, Vector2, Color, or a whole Dictionary - under the key in the active slot (immediately on disk). |
| Save Number | `key` (String), `value` (float) | Writes a number under the key in the active slot. |
| Save Text | `key` (String), `value` (String) | Writes a string under the key in the active slot. |
| Save Node State | `node` (Node), `key` (String) | Snapshots a node and its behavior children (any child with a `save_state` method) under the key - one player, enemy, or interactive object with all its behaviors at once. |
| Load Node State | `node` (Node), `key` (String) | Restores the node and its behaviors from the snapshot stored under the key. |
| Save Group State | `group` (String), `key` (String) | Snapshots every node in a scene-tree group (plus their behaviors), keyed by scene path, under the key - whole-squad persistence in one row. |
| Load Group State | `key` (String) | Restores the group snapshot under the key, matching each entry back to the node at its saved scene path. |
| Save Singleton State | `singleton_name` (String), `key` (String) | Snapshots an autoload addon (such as CurrencyLedger, Upgrades, or Prestige) by its autoload name under the key. |
| Load Singleton State | `singleton_name` (String), `key` (String) | Restores the autoload named `singleton_name` from the snapshot stored under the key. |
| Delete Slot | (none) | Removes the active slot's save file. |
| Save Game | (none) | Broadcasts On Before Save so every sheet writes its state, snapshots the persist group, flushes the file, then broadcasts On Save Written. |
| Load Game | (none) | Restores the persist-group snapshots, then broadcasts On After Load so every sheet reads its state back. |

### Conditions

| Condition | Parameters | Description |
|---|---|---|
| Has Save Key | `key` (String) | Whether the key exists in the active slot. |
| Slot Exists | `slot_index` (int) | Whether the given slot has a save file. |
| Save File Is Format | `path` (String), `expected_format` (String) | Whether the save file at the path is the given format (`config`/`json`/`binary`/`csv`/`ini`/`xml`). |
| Save Format Is | `expected_format` (String) | Whether the active save format (the Inspector `format` property) equals the given one. |

### Expressions

| Expression | Parameters | Returns | Description |
|---|---|---|---|
| Load Value | `key` (String), `default_value` (any) | any | Reads any value under the key; returns your `default_value` when the key is missing. |
| Load Number | `key` (String) | float | Reads a number under the key; returns 0 when missing. |
| Load Text | `key` (String) | String | Reads a string under the key; returns an empty string when missing. |
| Read All | (none) | Dictionary | The whole active slot as one Dictionary - every saved key and value at once. |
| List Save Keys | (none) | Array | The keys stored in the active slot; loop them to read or migrate a whole save. |
| Read Save File | `path` (String), `file_format` (String) | Dictionary | Reads any save file at `path` in the given format (`config`/`json`/`binary`/`csv`/`ini`/`xml`; blank uses the active format) and returns its Dictionary, without touching the active slot. |
| Save File Format | `path` (String) | String | Detects the format of the save file at the path (by extension, then by content), or `""` when missing or unrecognised. Feed it to Read Save File. |
| List Slots | (none) | Array | The slot numbers that currently have a save file - build a save/load menu from it. |
| Slot Modified Time | `slot_index` (int) | int | Unix modified time of the slot's file, or 0 when the slot has no file. |

### Triggers

| Trigger | Fires when |
|---|---|
| On Before Save | Save Game starts - your cue for every sheet to write its own state before the file is flushed. |
| On Save Written | Save Game has finished flushing the file (also fires per automatic autosave). |
| On After Load | Load Game is called - your cue for every sheet to read its own state back. |

Each trigger passes the slot number that was saved or loaded, so a handler can tell which slot the broadcast is for.

### Inspector properties

| Property | Type | Default | Notes |
|---|---|---|---|
| `slot` | int | `0` | Active slot, 0 to 9. Each slot is a separate file. |
| `save_directory` | String | `user://` | Folder the files live in. |
| `file_pattern` | String | `save_{slot}.cfg` | File name; must contain `{slot}`. |
| `section` | String | `save` | Config section / JSON namespace for the values. |
| `format` | enum | `config` | `config`, `json`, `binary`, or `csv`. |
| `persist_group` | String | `persist` | Scene-tree group Save Game snapshots (and Load Game restores) automatically. |
| `encryption_key` | String | (empty) | Non-empty encrypts the saves. |
| `autosave_interval` | float | `0` | Seconds between automatic Save Game calls (0 = off). |

---

## Use cases

Each example calls the `SaveSystem` autoload. Direct writes and reads hit the active slot; Save Game / Load Game broadcast to every sheet.

### 1. Persist coins across sessions

The simplest possible save. Write the total on Before Save and read it on After Load, so it comes back on the next launch.

```
On Before Save
  -> SaveSystem: Save Number  "coins", Player.coins

On After Load
  -> Set Player.coins to  SaveSystem.Load Number("coins")
```

### 2. A Save button with a confirmation toast

Save Game does the work; On Save Written is the clean hook for feedback, so the toast fires only after the file is actually flushed.

```
On Button Pressed "SaveButton"
  -> SaveSystem: Save Game

On Save Written
  -> HUD: show "Progress saved" for 2 seconds
```

### 3. Three save slots from one menu

Each slot is a separate file, so switching slots is just setting the `SaveSystem.slot` property before you save. Point the active slot at the button that was pressed, then Save Game.

```
On Button Pressed "SlotButton1"
  -> Set SaveSystem.slot to  1
  -> SaveSystem: Save Game

On Button Pressed "SlotButton2"
  -> Set SaveSystem.slot to  2
  -> SaveSystem: Save Game
```

Set `SaveSystem.slot` the same way before Load Game to load a specific slot.

### 4. Build a save/load menu from the filled slots

List Slots returns only the slots that have files, and Slot Modified Time stamps each row so the player can see which save is newest.

```
On Menu Opened
  -> For each slot in  SaveSystem.List Slots()
       -> UI: add a slot row for  loop_value
       -> UI: set row timestamp to  SaveSystem.Slot Modified Time(loop_value)
```

### 5. A Continue button that only lights up with a save

Slot Exists checks the active slot without loading it, so the main menu can enable Continue only when there is something to continue.

```
On Ready
  Condition: SaveSystem  Slot Exists  0
    -> ContinueButton: enable
  Else
    -> ContinueButton: disable
```

### 6. Persist audio and difficulty settings

Options are just more keys. Save each control's value directly (these are on disk immediately) and read them back when the options screen opens.

```
On Button Pressed "ApplySettings"
  -> SaveSystem: Save Number  "master_volume", VolumeSlider.value
  -> SaveSystem: Save Text    "difficulty", DifficultyOption.selected_text

On Options Opened
  -> Set VolumeSlider.value to  SaveSystem.Load Number("master_volume")
  -> Set DifficultyLabel.text to  SaveSystem.Load Text("difficulty")
```

### 7. Autosave on a timer

Set `autosave_interval` to 60 in the Inspector and the pack calls Save Game every 60 seconds. Everything that answers On Before Save is written automatically.

```
On Before Save
  -> SaveSystem: Save Number  "coins", Player.coins
  -> SaveSystem: Save Value   "player_pos", Player.global_position

On Save Written
  -> HUD: flash a small "auto-saved" icon
```

### 8. Checkpoint save when the player reaches a zone

A checkpoint is just a Save Game triggered by gameplay. Store the position as a Vector2 with Save Value so respawning is exact.

```
On Body Entered "CheckpointZone"
  -> SaveSystem: Save Value  "checkpoint", Player.global_position
  -> SaveSystem: Save Game
```

### 9. Store the whole inventory as one Dictionary

Save Value writes any type, so an entire inventory Dictionary is a single key. Load Value reads it back with an empty Dictionary as the first-run default.

```
On Before Save
  -> SaveSystem: Save Value  "inventory", Inventory.items

On After Load
  -> Set Inventory.items to  SaveSystem.Load Value("inventory", {})
```

### 10. First-run defaults with Has Save Key

On a fresh install the key does not exist yet. Has Save Key lets you seed a starting value instead of loading a missing one.

```
On Ready
  Condition: SaveSystem  Has Save Key  "coins"
    -> Set Player.coins to  SaveSystem.Load Number("coins")
  Else
    -> Set Player.coins to  100
```

### 11. Delete a save slot from a manage-saves screen

Point the active slot at the one being deleted, call Delete Slot, then refresh the list so the removed slot drops out.

```
On Button Pressed "DeleteSlot"
  -> Set SaveSystem.slot to  SelectedSlot.index
  -> SaveSystem: Delete Slot
  -> UI: rebuild the slot list from  SaveSystem.List Slots()
```

### 12. Continue the most recently played slot

Slot Modified Time returns a comparable timestamp per slot, so a single Continue button can jump straight to the newest save.

```
On Button Pressed "Continue"
  Condition: [Expression] SaveSystem.Slot Modified Time(1)  >  SaveSystem.Slot Modified Time(2)
    -> Set SaveSystem.slot to  1
  Else
    -> Set SaveSystem.slot to  2
  -> SaveSystem: Load Game
```

### 13. Encrypted saves to deter casual tampering

Set a non-empty `encryption_key` in the Inspector and the files are written encrypted. Your sheets do not change at all - the same Save Game and Load Game just read and write encrypted files.

```
On Button Pressed "SaveButton"
  -> SaveSystem: Save Game
```

With the key set, the resulting `save_0.cfg` cannot be opened and hand-edited in a text editor.

### 14. Readable JSON saves for debugging

Switch the `format` Inspector property to `json` while you are developing, so you can open the save file and see exactly what each key holds.

```
On Before Save
  -> SaveSystem: Save Number  "coins", Player.coins
  -> SaveSystem: Save Number  "level", Level.index
  -> SaveSystem: Save Text    "last_zone", Level.zone_name
  -> SaveSystem: Save Value   "spawn", Player.global_position
```

The saved file is plain text you can read, diff, and sanity-check. JSON preserves rich Godot types through an internal wrapper, so the Vector2 you wrote as `"spawn"` reloads exactly as a Vector2, and integers reload as integers rather than floats, so your values come back with the same types you saved.

### 15. Many sheets, one save file

The point of the broadcast: unrelated sheets each own their keys. The player sheet, the quest sheet, and the settings sheet all answer On Before Save, and none of them knows about the others.

```
(player sheet)
On Before Save
  -> SaveSystem: Save Value  "player_pos", Player.global_position

(quest sheet)
On Before Save
  -> SaveSystem: Save Value  "quest_flags", QuestLog.flags

(settings sheet)
On Before Save
  -> SaveSystem: Save Number  "master_volume", VolumeSlider.value
```

One Save Game call from anywhere writes all three, and each sheet reads its own key back on On After Load.

### 16. Save one enemy's stats and health with Save Node State

A boss node carries a StatForge behavior and a Health behavior. Save Node State snapshots the node and every behavior on it under one key, and Load Node State brings all of it back - buff stack, pools, and all - without touching a single field by hand.

```
On Before Boss Despawn
  -> SaveSystem: Save Node State  Boss, "boss_state"

On Boss Restored
  -> SaveSystem: Load Node State  Boss, "boss_state"
```

### 17. Persist a whole squad with Save Group State

Put every squad member in a scene-tree group and Save Group State snapshots all of them (and their behaviors) at once, keyed by scene path. Load Group State restores by matching those paths, so the squad returns exactly as it was.

```
On Before Save
  -> SaveSystem: Save Group State  "squad", "squad_state"

On After Load
  -> SaveSystem: Load Group State  "squad_state"
```

### 18. Persist an autoload economy with Save Singleton State

CurrencyLedger, Upgrades, and Prestige are autoload addons with their own runtime state. Save Singleton State captures an autoload by its name, so the whole economy rides into the save in one row and returns intact.

```
On Before Save
  -> SaveSystem: Save Singleton State  "CurrencyLedger", "wallet"
  -> SaveSystem: Save Singleton State  "Upgrades", "upgrades"

On After Load
  -> SaveSystem: Load Singleton State  "CurrencyLedger", "wallet"
  -> SaveSystem: Load Singleton State  "Upgrades", "upgrades"
```

### 19. Whole-scene persistence with the persist group

Add every node that should survive a save to the `persist_group` (default `"persist"`) and Save Game snapshots them and their behaviors for you. There is nothing to write on On Before Save - Load Game restores the whole group before On After Load fires.

```
(no save rows needed - just tag the nodes)
On Level Ready
  -> Enemy: add to group  "persist"
  -> Chest:  add to group  "persist"

On Button Pressed "SaveButton"
  -> SaveSystem: Save Game
```

Every tagged node, with its behaviors, is captured and restored automatically.

### 20. A balancing spreadsheet from CSV saves

Set `format` to `csv` and each save is a plain `key,value` file a spreadsheet can open. Tweak the numbers in the sheet, save the CSV in the same shape, and it loads straight back - a quick balancing loop with no code.

```
On Before Save
  -> SaveSystem: Save Number  "enemy_hp", Balance.enemy_hp
  -> SaveSystem: Save Number  "coin_drop", Balance.coin_drop

On After Load
  -> Set Balance.enemy_hp to  SaveSystem.Load Number("enemy_hp")
  -> Set Balance.coin_drop to  SaveSystem.Load Number("coin_drop")
```

### 21. Compact binary saves for a shipped build

Switch `format` to `binary` for the release build and the same Save Game writes the smallest files, stored with `store_var`. Nothing in your sheets changes - only the on-disk shape, which is no longer meant to be hand-edited.

```
On Button Pressed "SaveButton"
  -> SaveSystem: Save Game
```

### Other use cases

**Roguelike meta-progression.** Permanent unlocks - new characters, starting items, discovered recipes - are saved the moment a run ends and read back at the start of the next one, so death wipes the run but never the account.

**New Game Plus.** On finishing the game, write just the keys that should carry over (loadout, cosmetics, gold), start the campaign scene fresh, and load only those keys back - a curated carry-over instead of a full restore.

**Player-built levels.** A level editor stores the whole layout as one Dictionary under a single Save Value key, so sharing, listing, and reloading user creations rides the same slot machinery as normal saves.

**Daily bonus tracking.** Save a timestamp when the player claims the daily reward and compare it against the clock on launch to decide whether the bonus button lights up again.

**Lifetime stats profile.** Reserve one slot as the profile file for totals like playtime, kills, and achievements, switching to it briefly on save and load, so career stats persist no matter which campaign slot the player deletes.

---

## Tips and common mistakes

### Save Studio

Save Studio is an editor window on the Tools menu for working with saves without leaving Godot. It has three tabs. **Format Preview** shows an addon's save output rendered in any of the six formats before you commit to one, so you can eyeball config against JSON, binary, CSV, INI, and XML side by side. **Save Slots** browses the `user://` saves on disk, lets you view a slot's contents, and exports or converts a slot between formats. **Add Save Support** generates a matching `save_state` / `load_state` pair for one of your own scripts, so a script you wrote joins the same seam the built-in behaviors use. If you are authoring a script that should participate in Save Node State, Save Group State, or the persist group, start there.

- **Save Number / Save Text / Save Value are already on disk.** You do not need Save Game to persist a single key - the direct verbs flush immediately. Save Game is the coordinator that asks every sheet to write via On Before Save and then confirms with On Save Written; reach for it when you want a full "save the game now" moment.
- **Load Game does not fill your objects by itself.** It broadcasts On After Load. If nothing seems to load, check that each sheet actually reads its keys back with Load Number / Load Text / Load Value inside an On After Load event - the pack cannot know where your values belong.
- **Match save and load keys exactly.** A key is a plain string, so `"coins"` and `"Coins"` are different keys. A mismatch silently returns the default (0, empty string, or whatever you passed to Load Value) instead of the value you thought you stored.
- **Give Load Value a sensible default.** The `default_value` is returned on the first run when the key is missing, so make it a valid starting value (an empty Dictionary, a zero Vector2, and so on). Use Has Save Key when you must tell "saved a zero" apart from "never saved".
- **Change the slot before you save or load, not during the call.** The write and read verbs use the active `SaveSystem.slot` property; there is no per-call slot argument. Set `SaveSystem.slot` first, then call Save Game or Load Game. The metadata verbs (Slot Exists, List Slots, Slot Modified Time) do take a slot number, so a menu can inspect other slots without switching the active one.
- **Keep `{slot}` in file_pattern.** If the pattern has no `{slot}` token every slot resolves to the same file name and they overwrite each other. The default `save_{slot}.cfg` is correct - preserve the token if you rename it.
- **Guard the encryption_key.** A non-empty key encrypts saves, but keep it out of screenshots and any code you share, and do not change it after players have saves - files written with the old key can no longer be read.
- **Pick the format for the job.** `config` stores Vector2, Color, and Dictionaries natively and is the safe default. `json` is readable and diffable, and it preserves rich Godot types and integer types through an internal wrapper so everything round-trips exactly. `csv` is the most hand-editable and doubles as a balancing spreadsheet, but it suits flat key/value data best. `binary` is the most compact and is the right pick for a shipped build, but it is not meant to be opened and edited by hand.
- **Behavior state rides along only through the state verbs.** Save Node State, Save Group State, Save Singleton State, and the persist group capture a behavior's internal runtime state via its `save_state` method. The plain key/value verbs (Save Number and friends) do not - they only store the exact value you pass. If a buff stack or a health pool is not surviving a save, you are probably copying fields by hand instead of snapshotting the node.
- **Pick your storage strategy early.** Changing `save_directory`, `file_pattern`, `section`, or `format` after players already have saves orphans the old files, because the pack will look in the new location and not find them. Settle these Inspector knobs before you ship.
- **Autosave writers should be cheap.** With `autosave_interval` set, On Before Save runs on a repeating timer. Keep those handlers light so the autosave tick never hitches the game.
