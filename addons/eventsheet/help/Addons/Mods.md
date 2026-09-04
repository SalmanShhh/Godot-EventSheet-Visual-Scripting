# Mods

**Mods** ships as the `Mods` autoload: the folder players put their own content in, and the rows that
read it. It loads every mod it finds in a folder, in a load order you set, and it does that in one of
two tiers you choose per row. A **data-only** load takes resources, scenes, textures and sounds, and
before it takes anything it reads the mod's own contents and refuses one that carries a script. A
**script** load takes a mod that carries code, and you should know exactly what that means before you
ship a row that does it: code in a mod runs with everything your game itself can reach, which is the
player's files, their network and their machine. Godot has no sandbox to put it in, this pack does
not pretend otherwise, and nothing here will make an untrusted mod safe. Data-only is the tier to
ship unless you have a reason.

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [The manifest](#the-manifest)
5. [ACE reference](#ace-reference)
6. [The doors onto a mod's content](#the-doors-onto-a-mods-content)
7. [Export Mod Template](#export-mod-template)
8. [Use cases](#use-cases)
9. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this pack shines

- **A skins folder.** Players drop a folder of textures and palettes in and pick them in the menu.
- **Community item packs.** A mod folder of `.tres` items joins the game's own list at boot.
- **Level packs.** Extra scenes shipped as a `.pck`, loaded on top of the game's own files.
- **Total conversions**, for a game that has decided to allow code and says so to its players.
- **An options screen that builds itself** from what is actually installed, with a switch per mod.
- **A modding page you can hand out** - the Export Mod Template tool writes the folder a modder
  copies, with its manifest already filled in.

## Core concepts

- **A mod is a folder or a pack file.** A folder with a manifest in it, or a `.pck` / `.zip` that
  Godot loads on top of the game's own files. Both are mods; they differ in what can be done to them
  afterwards.
- **Two tiers, and the row picks one.** Every loading row takes `data only`. On, the mod's actual
  contents are read - a pack file's own file table, a folder's own files - and a mod carrying any
  script, library or native binary is refused with that reason. Off, code loads and runs.
- **The manifest is the mod's own file**, not a list your game keeps. `mod.json` for a modder in a
  text editor, `mod.tres` for one working in Godot.
- **Load order is a sentence, not a database.** Name the mods you care about, in order; the rest
  follow in name order. Later mods replace what earlier ones brought, which is what a load order is
  for.
- **Switched off is the player's word.** A mod is on unless it was switched off, so a mod nobody has
  seen yet arrives enabled. The choice is remembered through the Game Settings autoload when your
  project has one.
- **A pack file cannot be unloaded.** Once Godot has loaded one, its files are part of the running
  game until it starts again. **Unload Mod** says so rather than pretending; switching the mod off
  and restarting is the way.

## Setup

1. Attach `ModsAddon` as an autoload named **Mods** (Project Settings ▸ Autoload).
2. Decide where mods live. `user://mods` is the default and the right answer: a folder under
   `res://` is packed into the export, and a player cannot put anything into it once you ship.
3. Load them at boot, data only.

```
On Ready
  -> Mods: Set Load Order  "Big Swords, Winter Skins"
  -> Mods: Load Mods From  "user://mods", true
```

4. Read what arrived, and show it.

```
On Mods Changed
  -> Set Label Text  ( "Mods: " + str( Mod Count() ) )
```

## The manifest

Five fields, in either spelling. A `mod.json` a modder writes in any text editor:

```json
{
	"name": "Big Swords",
	"version": "2.1",
	"author": "Ada",
	"replaces": "the sword icons",
	"scripts": false
}
```

Or a `mod.tres` saved from **ModManifest**, filled in the Inspector:

| Field | Default | What it means |
|---|---|---|
| `mod_name` | `""` | What the mod is shown and addressed by. Blank means the folder's own name. |
| `version` | `1.0` | The mod's own version, in its author's spelling. Nothing compares two of them. |
| `author` | `""` | The credit line beside the name. |
| `replaces` | `""` | What it replaces, in the author's words. Nothing reads it: it is the sentence a player reads before switching two mods on together. |
| `scripts` | `false` | Whether the mod says it carries code. |

**The scripts flag is a declaration, not a guarantee.** A data-only load checks the mod's real
contents as well, so a manifest claiming innocence cannot smuggle a `.gd` in. A pack file's file
table is read straight off the file, without loading it, because a loaded pack can never be taken
back out.

A pack file declares itself in a `.json` beside it (`big_swords.pck` and `big_swords.json`), or in a
`mod.json` inside it when it is a `.zip`. A pack that declares nothing is named after its file.

## ACE reference

On the canvas these rows read as styled sentences - parameter values in **bold**, exactly as the
rows draw them:

- Load mods from **user://mods**, data only **true**
- Mod **Big Swords** is loaded
- folder of mod **Big Swords**

| Kind | Name | Parameters | Description |
|---|---|---|---|
| Action | Load Mods From | `folder`, `data_only` | Loads every mod in a folder, in load order. With data only on, a mod carrying code is refused through On Mod Refused instead of loading. A mod switched off is skipped in silence. |
| Action | Load Mod | `path`, `data_only` | Loads one mod by path - a mod folder or a pack file - under the same two tiers. A path with no mod at it is refused with that reason. |
| Action | Unload Mod | `unloading_name` | Takes a FOLDER mod back out of the loaded list. A pack file cannot be unloaded while the game runs, and this row refuses with that reason. |
| Action | Set Load Order | `names` | Says which mods load first, as a comma-separated list. Everything not named follows in name order, and later mods replace what earlier ones brought. |
| Action | Enable Mod | `enabling_name` | Switches a mod back on. Remembered through the Settings autoload when the project has one. |
| Action | Disable Mod | `disabling_name` | Switches a mod off: skipped at the next load, and a folder mod drops out of the list at once. Remembered the same way. |
| Condition | Mod Is Loaded | `wanted` | Whether a mod of that name is loaded right now - the check in front of using what it brought. |
| Loop | For Each Mod | (none) | Runs the actions once per loaded mod, in load order. Read the current one as `mod`, then `mod.name`, `mod.version`, `mod.author`, `mod.kind`, `mod.folder`. |
| Expression | Mod Count | (none) | How many mods are loaded - the number on the options screen's mods line. |
| Expression | Mod Name | (none) | The name of the mod the last Mods event was about, loaded or refused. |
| Expression | Mod Version | (none) | The version of the mod the last Mods event was about, as its manifest spells it. |
| Expression | Mod Author | (none) | The author of the mod the last Mods event was about. |
| Expression | Mod Reason | (none) | Why the last refused mod was refused, in plain words a player can read, and nothing when none has been. |
| Expression | Mod Folder | `wanted` | Where a loaded mod's files live, for the rows that read folders. A pack file has no folder of its own, so this is empty for one. |
| Expression | Mod Folders | `subfolder` | The same folder inside every loaded folder mod, in load order, skipping those without one. |
| Expression | Mod Content Problems | `subfolder` | Every structural problem in the loaded mods' content, one per line: a data asset that will not load, and a file two mods both bring. |
| Trigger | On Mod Loaded | `loaded_name`, `loaded_version` | Fires once per mod that loaded, in load order. |
| Trigger | On Mod Refused | `refused_name`, `reason` | Fires once per mod that did not load, with the reason in plain words. |
| Trigger | On Mods Changed | (none) | Fires once after anything changes what is loaded or switched on - the moment to redraw a mod list. |

### Inspector properties

| Property | Default | What it does |
|---|---|---|
| `mods_folder` | `user://mods` | Where Load Mods From looks by default. Prefer `user://`: a folder under `res://` is packed into the export. |
| `settings_key` | `disabled_mods` | The setting the switched-off mods are remembered under, through the Settings autoload. |
| `debug_mode` | `false` | Warns about a missing folder, a folder with no manifest, a pack whose file list could not be read, and a name two mods both claim. |

## The doors onto a mod's content

The pack adds no vocabulary for reading a mod's files, because the vocabulary is already here. **Mod
Folder** hands back a path, and every row that takes a folder takes that path:

```
On Mods Changed
  -> Set Items  ( Resources In Folder( Mod Folder("Big Swords") + "/items" ) )
```

**Mod Folders** does the same for all of them at once, so one loop reads every installed mod's items,
skins or levels. And **Mod Content Problems** asks the structural questions **Data Folder Problems**
asks, over those same folders, plus the one only a mod folder raises: a file two mods both bring,
where the one loaded last wins.

## Export Mod Template

Command palette ▸ **Export Mod Template** writes the folder your modders copy: a `mod.json` with its
five fields filled in, an optional `mod.tres` beside it, an empty content folder, and a README saying
what each field means and what a mod carrying code costs the player who runs it. Point it somewhere
that is not your mods folder - it is the example, not a mod - and it refuses a folder that already
holds a manifest rather than writing over somebody's work.

## Use cases

**1. Load the folder at boot, data only.** The row most games need, and the only one many ship.

```
On Ready
  -> Mods: Load Mods From  "user://mods", true
```

**2. A mod list on the options screen.** One row per installed mod, redrawn when anything changes.

```
On Mods Changed
  -> Clear Mod List
  For Each Mod
    -> Add Mod Row  ( mod.name + " " + mod.version + " by " + mod.author )
```

**3. Tell the player why one did not load.** The reason is already a sentence.

```
On Mod Refused
  -> Show Toast  ( Mod Name() + " was not loaded: " + Mod Reason() )
```

**4. A switch per mod.** The player's checkbox, remembered between sessions.

```
On mod switch toggled
  Condition: switch.button_pressed
    -> Mods: Enable Mod  ( row.mod_name )
```

```
On mod switch toggled
  Condition: not switch.button_pressed
    -> Mods: Disable Mod  ( row.mod_name )
```

**5. Read a mod's items into the game's own list.** The additive door, in one row.

```
On Mod Loaded
  -> Add Items  ( Resources In Folder( Mod Folder( Mod Name() ) + "/items" ) )
```

**6. Every mod's items at once.** One loop instead of one row per mod.

```
On Mods Changed
  For Each Mod
    -> Add Items  ( Resources In Folder( mod.folder + "/items" ) )
```

**7. Refuse to start with broken content.** The structural check in front of the game, not after it.

```
On Mods Changed
  Condition: Mod Content Problems("items") is not ""
    -> Show Warning  ( Mod Content Problems("items") )
```

**8. Let the player order two mods that fight.** Later wins, so the order is the answer.

```
On order list changed
  -> Mods: Set Load Order  ( order_list.as_comma_text )
```

**9. Reload after a change, from a clean start.** Folder mods can be taken back out, so a restart is
only needed for pack files.

```
On Apply pressed
  -> Mods: Unload Mod  ( selected.mod_name )
  -> Mods: Load Mods From  "user://mods", true
```

**10. A trusted mod loaded with its code.** One named mod, one row, and the player told what it is.

```
On Enable Scripting confirmed
  -> Mods: Load Mod  "user://mods/total_conversion", false
```

**11. Show what is installed before anything is loaded.** A count is enough for a menu line.

```
On options screen opened
  -> Set Label Text  ( str( Mod Count() ) + " mods installed" )
```

**12. Gate a feature on a mod being there.** The check in front of using what it brought.

```
On Ready
  Condition: Mods: Mod Is Loaded  "Big Swords"
    -> Enable Big Sword Slot
```

**13. Credit the authors.** A credits screen built from the manifests, with no list to maintain.

```
On credits screen opened
  For Each Mod
    -> Add Credit Line  ( mod.name + " by " + mod.author )
```

**14. Watch the folder while the player is in the menu.** The Folder Watcher notices a mod appearing,
and the load row does the rest.

```
On Folder Changed
  -> Mods: Load Mods From  "user://mods", true
```

**15. A skins catalog that includes the mods.** The Skin Vault reads a mod's folder the way it reads
your own.

```
On Mod Loaded
  -> Skin Vault: Load Catalog From  ( Mod Folder( Mod Name() ) + "/skins" )
```

**16. Say what was skipped, not just what loaded.** Two triggers, two sentences, one honest screen.

```
On Mod Loaded
  -> Add Mod Row  ( Mod Name() + " " + Mod Version() )
```

```
On Mod Refused
  -> Add Refused Row  ( Mod Name() + ": " + Mod Reason() )
```

### Other use cases

**Level packs as pack files.** A community `.pck` of extra levels loads on top of the game's own, and
the level select reads the same folder it always did.

**Localisation mods.** A folder of translation CSVs a player wrote for a language you do not ship,
registered from a mod folder at boot.

**A jam build's cheat pack.** A script mod you load only when a debug setting is on, so the cheats
ship as a separate folder nobody has to install.

**Seasonal content the community writes.** Winter tiles, a music pack, a palette: data mods that need
no code and no update to the game.

**A modding contest.** Every entry is a folder in `user://mods`, the load order decides which is
showing, and the switch turns each one on for judging.

## Tips and common mistakes

- **Ship data only, unless you have decided otherwise.** A script mod is code running with everything
  your game can reach. If you allow it, say so where the player switches it on, not in a changelog.
- **`user://`, not `res://`.** A mods folder inside the export is a folder no player can add to.
- **A pack file is a one-way door.** It cannot be unloaded, so a game that lets players swap mods
  freely wants folder mods, or a restart between changes.
- **Name your mods once.** Two mods claiming the same name means the first one loaded keeps it, and
  the second is refused. Turn `debug_mode` on while you are building and it says so.
- **Set the load order before you load.** Setting it afterwards re-lists what is already loaded, which
  fixes the display, but the files a pack brought are already in place.
- **A mod folder with no manifest is not a mod.** It is skipped in silence unless `debug_mode` is on.
  That is deliberate: a player's mods folder collects README files and screenshots too.
- **Mod Content Problems is not a security check.** It reports broken and duplicated data assets. The
  code question is the tier, and it is asked by the loading row.
