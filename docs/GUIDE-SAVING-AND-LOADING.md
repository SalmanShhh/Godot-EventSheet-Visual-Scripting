# Saving and Loading Your Game

Almost every game needs to remember something between play sessions: the player's coins, their level, which doors they have opened, how far an idle factory has ticked while they were away. Godot EventSheets ships a complete save-and-load workflow that handles all of this with plain, readable data and almost no wiring. This guide explains how the pieces fit together and walks through more than twenty concrete recipes you can copy into your own project.

The whole system is built on one small idea, the save-state seam, and one drop-in addon, the Save System. Once you understand those two things, everything else is a variation on the same pattern.

## Table of Contents

- [Core concepts](#core-concepts)
  - [The save-state seam](#the-save-state-seam)
  - [The persist group](#the-persist-group)
  - [The lifecycle broadcast](#the-lifecycle-broadcast)
  - [Targeted saving vs whole-game saving](#targeted-saving-vs-whole-game-saving)
  - [The six save formats](#the-six-save-formats)
  - [Save Studio](#save-studio)
- [Use cases](#use-cases)
- [Other use cases](#other-use-cases)
- [Tips and common mistakes](#tips-and-common-mistakes)

## Core concepts

### The save-state seam

Every stateful bundled addon exposes two plain methods:

- `save_state() -> Dictionary` returns a plain-data snapshot of everything the addon is tracking at runtime.
- `load_state(state: Dictionary)` puts that snapshot back, tolerating missing keys so an old save never crashes a newer build.

There is no base class to inherit from and nothing to register. The Save System recognises these methods by duck typing: it simply asks each node `has_method("save_state")` and, if the answer is yes, calls it. That means any node can join the convention, including your own scripts. Add the two methods to a script you wrote and the Save System will snapshot and restore it exactly the same way it handles the bundled packs.

The following bundled packs already ship the seam, so their state is savable out of the box:

StatForge (buffs and stats), Health, Currency Ledger, Skin Vault, Timer, State Machine, Idle Generator, Click Power, Boosts, Upgrades, Prestige, Milestones, Weapon Kit (ammo), Storylet Weaver, Loot Table (pity counters), Advanced Random (RNG seed and state), Proc Room (run state), and Abilities (cooldowns and stacks).

### The persist group

The Save System has an Inspector property named `persist_group`, which defaults to `"persist"`. Any node you place in that scene-tree group is automatically included when the whole game is saved or loaded. You add a node to the group the ordinary Godot way, either through the Node dock's Groups tab in the editor or by calling `add_to_group("persist")` in a sheet. When Save Game runs, the Save System snapshots every node in the group by calling its `save_state`, and it also walks that node's behavior children so the behaviors attached to it are captured too. Load Game reverses this, matching each snapshot back to its node by node path. This is the zero-row path to whole-scene persistence: mark the nodes that matter, and saving just works.

### The lifecycle broadcast

Save Game and Load Game do not only touch the persist group. They also broadcast triggers so that every event sheet in your project can contribute its own piece of the save:

- **On Before Save** fires at the start of Save Game, giving each sheet a chance to write its values with Save Number, Save Text, or Save Value before the file is committed.
- **On Save Written** fires after the file has been written, which is the right moment to flash a "Game saved" message.
- **On After Load** fires at the end of Load Game, once every snapshot has been restored, so sheets can read their values back with Load Number and friends and refresh the interface.

Because these are ordinary triggers, saving is never centralised in one giant sheet. Each system writes and reads its own data close to where that data lives.

### Targeted saving vs whole-game saving

There are two ways to save. Whole-game saving (Save Game and Load Game) captures the entire persist group plus everything the On Before Save sheets write, all in one file. Targeted saving captures one specific thing on demand:

- **Save Node State** and **Load Node State** persist a single node together with its behavior children, under a key you choose.
- **Save Group State** and **Load Group State** persist every node in a named scene-tree group, matching each one back by node path on load.
- **Save Singleton State** and **Load Singleton State** persist an autoload addon by its autoload name, for example `CurrencyLedger`.

Targeted verbs are ideal when you want to snapshot one enemy, one squad, or one global system without saving the entire game.

### The six save formats

The `format` Inspector property picks how bytes hit the disk. All six round-trip through the same verbs and preserve exact types, so you can switch formats without changing a single sheet:

- **config** is Godot's ConfigFile format and the default. It preserves full Variant fidelity, so integers stay integers and Vector2 stays Vector2.
- **json** produces human-readable text, which is perfect for modding and hand-editing. Variants that JSON cannot represent natively, such as Vector2 and Color, are wrapped so they round-trip exactly, and integers are wrapped too so a whole number stays an integer instead of reloading as a float (floats, strings, and booleans stay bare, so the file is still easy to read).
- **binary** uses compact `store_var` output. It is small and fast but not meant to be hand-edited.
- **csv** writes spreadsheet-friendly `key,value` rows and can also load a CSV you authored by hand, which makes it handy for balancing tables.
- **ini** writes a plain, portable `[section]` header with `key=value` lines. It is the format other tools and INI libraries can read the structure of, while still preserving exact types.
- **xml** writes structured `<entry key="...">value</entry>` tags inside a `<save>` root. It is the pick when a pipeline, importer, or external tool expects XML.

Related Inspector properties: `encryption_key` (any non-empty value turns on encrypted saves), `slot` (which numbered file to use), `save_directory` (defaults to `user://`), `file_pattern` (the filename template, which must contain `{slot}`), `section` (the section/namespace name), and `autosave_interval` (seconds between automatic saves, `0` means off).

### Reading a whole save

Beyond reading one key at a time with Load Value, three helpers read a save in bulk:

- **Read All** returns the whole active slot as one Dictionary - every key and value at once.
- **List Save Keys** returns the keys in the active slot, so you can loop them (for a debug dump, a save-migration pass, or a "what's in this file" inspector).
- **Read Save File** reads ANY save file at a path in a given format (`config`, `json`, `binary`, `csv`, `ini`, `xml`, or blank to use the active format) and returns its Dictionary. Point it at an imported save, a backup, or a file another tool wrote.

### Save Studio

Save Studio is a tool window you open from the editor's Tools menu. It has three tabs (for a full walkthrough, see the "Using the Save Studio" guide):

1. **Format Preview** lets you pick an addon and a format and see exactly what its save file will look like on disk, before you commit to anything.
2. **Save Slots** browses the real `user://` save files in your project, shows their contents, and exports them to disk in any format, optionally converting the format on the way out.
3. **Add Save Support** points at any script, lets you tick the variables worth persisting (data is pre-ticked while node references are left off by default), and generates a copy-paste `save_state` and `load_state` pair that follows the convention. This is how you give your own addons and tools save support without writing the boilerplate by hand.

## Use cases

### 1. Persist coins and score across sessions

In a sheet that reacts to picking up a coin, add one to your running total, then on the same frame or at a checkpoint call `SaveSystem: Save Number` with a key like `coins`. When the game starts, in an On Ready or menu sheet call `SaveSystem: Load Number` with the same key and feed the result back into your coin counter. This is the smallest possible save loop and a good first thing to wire up.

### 2. Persist the whole scene with the persist group

Select the nodes that hold meaningful state (the player, movable crates, opened chests) and add each of them to the `persist` group through the Node dock's Groups tab. Now a single `SaveSystem: Save Game` snapshots all of them and their behavior children, and `SaveSystem: Load Game` restores every one by node path. You did not write a save row per object, and adding a new persistent object later is just a matter of dropping it into the group.

### 3. Save one enemy's StatForge buffs

When a boss reaches a scripted pause, call `SaveSystem: Save Node State`, target the boss node, and give it a key such as `boss_alpha`. Because Save Node State walks the node's behavior children, the StatForge behavior riding on that boss is captured, so its active buffs, stacks, and modified stats are all in the snapshot. Later, `SaveSystem: Load Node State` with the same node and key brings the exact buff situation back.

### 4. Save an entire squad at once

Put every unit in your party into a scene-tree group named, for example, `squad`, then call `SaveSystem: Save Group State` with that group name. Every unit's node, plus each unit's Health, StatForge, and Weapon Kit behaviors, is written in one call. `SaveSystem: Load Group State` restores the whole squad, matching each snapshot back to its unit by node path, so a mid-mission save captures the party's full condition.

### 5. Persist an autoload economy with the Currency Ledger

If your game routes money through the Currency Ledger autoload, you do not need it to be in any scene group. Call `SaveSystem: Save Singleton State` with the autoload name `CurrencyLedger`, and the ledger's balances are snapshotted through its `save_state`. On load, `SaveSystem: Load Singleton State` with the same name restores every account. This keeps global economy state out of your scenes entirely.

### 6. Keep idle and incremental progress across a restart

Idle and incremental games lean hardest on saving. Add the Idle Generator, Upgrades, Prestige, and Milestones addons to the persist group (or save them as singletons if they are autoloads), then call `SaveSystem: Save Game`. Each pack's `save_state` records its own numbers: generator rates, purchased upgrades, prestige multipliers, and completed milestones. On the next launch, `SaveSystem: Load Game` restores all of it so the player picks up exactly where they left off.

### 7. Remember weapon ammo between levels

The Weapon Kit behavior seams its ammo counts. Before a level transition, call `SaveSystem: Save Node State` on the player (or Save Game if the player is in the persist group). The player's Weapon Kit behavior child is captured, so magazine and reserve counts survive. On the next level's load, the ammo comes back rather than resetting to full.

### 8. Restore a State Machine's current state

The State Machine behavior reports its current state through `save_state`. When you save a node that carries a State Machine (via Save Node State or the persist group), the active state name is stored. On load, `load_state` puts the machine back into that state, so a guard that was mid-patrol resumes patrolling rather than snapping back to its idle default.

### 9. Keep RNG deterministic across save and load

Add the Advanced Random autoload to your save (as a singleton with `SaveSystem: Save Singleton State`, or in the persist group). Its `save_state` records the seed and the current generator state. When you later load, `load_state` restores that exact position in the random sequence, so a loaded game produces the same rolls it would have produced without the interruption. This matters for reproducible runs and for fair daily challenges.

### 10. Save roguelike run state with Proc Room

Proc Room seams the current run's state. At the end of each room, call `SaveSystem: Save Game` (with Proc Room in the persist group or saved as a singleton) so the run's layout progress and flags are recorded. If the player quits mid-run, `SaveSystem: Load Game` on next launch resumes the same run instead of forcing a fresh seed. Pair this with use case 9 so the enemy rolls also stay consistent.

### 11. Switch a save to JSON for modding

If you want players to open and tweak their saves, set the Save System's `format` Inspector property to `json`. Every save and load verb behaves the same, but the file on disk becomes readable text. Vector2 and Color values are wrapped so they round-trip exactly, and integers are wrapped so they stay integers rather than reloading as floats, so your saved values come back with the same types you wrote.

### 12. Export a CSV for a balancing spreadsheet

Set `format` to `csv` (or export a slot to CSV from Save Studio's Save Slots tab) to get `key,value` rows you can open in any spreadsheet program. Designers can eyeball economy numbers, adjust them, and because CSV also loads hand-authored files, feed a tuned table straight back into the game.

### 13. Ship with compact binary saves

For a shipping build where you do not want players hand-editing progress, set `format` to `binary`. This uses `store_var` for a small, fast file that is not meant to be edited by hand. Your sheets do not change; only the on-disk representation does.

### 14. Turn on encrypted saves

Set the `encryption_key` Inspector property to any non-empty string and every save is written encrypted with that key, and loaded transparently with it. This raises the bar against casual save tampering. Keep the key stable across builds, because a save written with one key cannot be read with another.

### 15. Offer three save slots

Expose three buttons in your menu, each of which sets the Save System's `slot` property (0, 1, or 2) before calling Save Game or Load Game. Because `file_pattern` contains `{slot}`, each slot writes to its own file such as `save_0.cfg`. The player can keep three independent playthroughs without any of them colliding.

### 16. Build a save and load menu

Populate a slot menu with `SaveSystem: List Slots` to discover which files exist, and call `SaveSystem: Slot Modified Time` on each to show a "last played" timestamp next to it. When the player clicks a slot, set `slot` and call Load Game. This turns the raw file list into a friendly, informative picker.

### 17. Gate a Continue button on Slot Exists

On the main menu, call `SaveSystem: Slot Exists` for the player's current slot. If it returns false, disable or hide the Continue button so a fresh player is not offered a save that is not there. If it returns true, enable Continue and wire it to Load Game. This is a two-row way to make the menu feel correct.

### 18. Autosave on a timer

Set the `autosave_interval` Inspector property to a number of seconds, for example `120`, and the Save System will automatically run a save on that cadence, firing On Before Save first so every sheet contributes its state. Set it back to `0` to turn autosave off. This gives you crash protection without a single autosave row in your sheets.

### 19. Create checkpoints

At each checkpoint trigger in a level, call `SaveSystem: Save Game` (or Save Node State on the player if you only want to snapshot them). Because On Before Save broadcasts to every sheet, the checkpoint captures the full game state at that moment. On death, call Load Game to send the player back to the last checkpoint with everything as it was.

### 20. Add save support to your own script

Open Save Studio from the Tools menu, go to the Add Save Support tab, and point it at one of your own scripts. Tick the variables worth persisting; data fields come pre-ticked while node references are left unticked because references should not be saved. Save Studio generates a matching `save_state` and `load_state` pair that you paste into your script. From that moment your node is part of the seam and the Save System will snapshot it exactly like a bundled pack.

### 21. Preview a format before committing

Before you settle on a format, open Save Studio's Format Preview tab, choose an addon, and choose a format. You will see exactly what that addon's save file looks like on disk. This lets you compare config, json, binary, csv, ini, and xml side by side and pick the one that fits your modding, size, and readability goals without touching your project.

### 22. Convert an existing save between formats

If you started in config but decide you want readable json, open Save Studio's Save Slots tab, select the existing slot, and export it with the target format selected. Save Studio reads the current file and writes it out converted, so you migrate a real save without regenerating the game state by hand.

### 23. Combine custom On Before Save rows with automatic persistence

You do not have to choose between the persist group and manual saving. Put your physical objects in the `persist` group so their positions and behaviors snapshot automatically, and in the same project respond to On Before Save with Save Number and Save Text rows for the loose values that do not belong to any node, such as the current quest name or difficulty setting. One Save Game call captures both, and On After Load lets your sheets read the loose values back.

### 24. Persist Loot Table pity and Storylet Weaver history

Add the Loot Table and Storylet Weaver addons to your save (persist group or singletons). Loot Table's `save_state` records its pity counters so a player who was close to a guaranteed rare does not lose that progress on reload, and Storylet Weaver's snapshot keeps which story beats have already fired so the narrative does not repeat itself after a load.

### 25. Write portable INI or XML saves for external tools

Set `format` to `ini` when another tool or an INI library needs to read your save's structure, or to `xml` when a pipeline expects XML. Both keep exact types (an integer stays an integer, a Vector2 stays a Vector2), so switching to them costs nothing on the Godot side while giving you a file shape other software understands.

### 26. Read a whole save at once for a debug panel or migration

Call Read All to pull the entire active slot into one Dictionary, or List Save Keys to loop the keys. This is the fast way to build a "what's in this save" debug panel, dump a slot to the output log, or run a one-time migration that rewrites old keys into a new shape before saving again.

### 27. Import a save file that another tool or an older build wrote

Point Read Save File at any path and pass the format it was written in (or leave the format blank to use the active one). It returns that file's Dictionary without touching the active slot, so you can inspect a backup, accept an imported save, or read a file from a companion app and copy the values you want into the current game.

### 28. Read a dropped-in save without knowing its format up front

When a player imports a save file and you do not know how it was written, call Save File Format to detect it (config, json, binary, csv, ini, or xml), then hand that result straight to Read Save File. Or branch with the Save File Is Format condition - "if the file is xml, run the XML import path" - and use Save Format Is to check what the game itself is currently set to write. Together these let a load flow accept whatever file it is handed instead of assuming one format.

## Other use cases

- **Skin selection.** Save the Skin Vault addon so a player's chosen and unlocked cosmetics survive a restart.
- **Click Power upgrades.** Include Click Power and Boosts in the persist set so a clicker game remembers earned multipliers and active boosts.
- **Timers that keep running.** Persist a Timer behavior so a countdown resumes at the correct remaining time rather than restarting.
- **Ability cooldowns.** Save the Abilities behavior so cooldowns and charge stacks are exactly where the player left them.
- **Quick settings persistence.** Use Save Value and Load Value for a handful of options such as volume or control scheme without any addon at all.
- **Has-key branching.** Call Has Save Key to decide whether to show a first-run tutorial or jump straight into the saved game.
- **Deleting a slot.** Wire a "Delete save" menu button to Delete Slot so players can wipe a playthrough cleanly.
- **New Game Plus.** Save a singleton economy, start a fresh scene, then load that singleton state to carry currency into a new run.
- **Per-boss snapshots.** Use Save Node State with a distinct key per boss to bank each encounter's state independently.
- **A toast on write.** React to On Save Written to flash a brief "Saved" confirmation so the player knows it landed.
- **Refresh the HUD after load.** React to On After Load to repaint health bars and counters from the freshly restored values.
- **Directory tidiness.** Point `save_directory` at a subfolder so all slot files live in one place under `user://`.

## Tips and common mistakes

- **Keep your keys stable across versions.** The key you pass to Save Number or Save Node State is the contract with old files. If you rename a key in a later build, existing saves lose that value. Add new keys rather than renaming old ones, and let `load_state` tolerate the missing ones.
- **Node references are not saved, only plain data.** The seam snapshots plain values. A saved dictionary should never contain a live node, a Callable, or another non-data object. If you need to remember which node something pointed at, store a stable identifier such as a name or path and re-resolve it after load.
- **The persist group is matched back by node path.** On load, each snapshot is reunited with its node by that node's path in the scene tree. The node must already exist at the same path when Load Game runs, so restore into the same scene layout you saved from, or spawn the nodes before loading.
- **All six formats preserve exact types.** An integer comes back as an integer, a float as a float, a Vector2 as a Vector2, in every format including json, csv, ini, and xml. You do not need to convert numbers on load. If you hand-edit a json save, note that a value you write as a wrapped object is how the system stores an integer or a rich type.
- **`save_state` must return plain data only.** When you write your own `save_state`, build the dictionary from numbers, strings, booleans, arrays, dictionaries, and the wrapped Variants the system understands. Returning anything that cannot be serialised will break the save. Save Studio's Add Save Support generator picks safe fields for you, which is the easiest way to stay on the right side of this rule.
- **The Project Doctor nudges you when a stateful behavior has no seam.** If a behavior or autoload declares State (non-exported) variables but ships no `save_state`/`load_state`, the Doctor lists it as an info-level "save-support" finding, since that runtime state would not survive Save Game. It is advisory - transient state that does not need saving is fine to ignore - and the one-click fix is Tools > Save Studio > Add Save Support.
