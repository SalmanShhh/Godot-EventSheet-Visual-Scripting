# Data-driven design with Custom Resources

Building a game with a lot of content - loot tables, cosmetics catalogs, enemy stats, dialogue trees -
gets painful when every entry is a row of events. Change the drop rates and you are rewiring actions;
add a skin and you copy a Register block. **Data-driven design** fixes this: the content lives in a
`.tres` asset you edit in the Inspector, and the game just loads it. Designers tune numbers in a grid;
programmers never touch it.

Godot EventSheets supports this two ways: **Custom Resources** hold the data, and a small **loader**
loads them - with a built-in warning if you forget to attach one. This guide shows how to use the
bundled examples and how to make your own addon data-driven. For a cookbook of data-driven game systems
(enemies, items, levels, quests, and more), see [Building a data-driven game](GUIDE-DATA-DRIVEN-GAMES.md).

## Table of Contents

1. [The idea](#1-the-idea)
2. [The bundled examples](#2-the-bundled-examples)
3. [The "you forgot to attach it" warning](#3-the-you-forgot-to-attach-it-warning)
4. [Make your own addon data-driven](#4-make-your-own-addon-data-driven)
5. [Tips](#5-tips)

## 1. The idea

There are two pieces:

- **A Custom Resource** - a class that `extends Resource` with `@export` fields. You create a `.tres`
  file from it and fill it in the Inspector; that file is your data. It is plain Godot data, so it works
  in the file system and the Inspector with no plugin at runtime.
- **A loader** - a small behavior with a required resource slot. Drop your `.tres` on it, and on ready it
  hands the data to the system that uses it (a runtime autoload). Or skip the loader and call the
  system's "Load From Resource" action yourself.

You author a Custom Resource the same way EnemyStats in the showcase is authored: a sheet whose Sheet
Type is a **Custom Resource** (it `extends Resource`), with exported variables - including an editable
**table** grid for rows of data. See the exported-variable options in the Variable dialog; the table
drawer is what turns an `Array` into a spreadsheet in the Inspector.

## 2. The bundled examples

Two packs ship data-driven already, and they are the template for your own.

**Loot Table.** Instead of Create Table plus a string of Add Entry actions, make a
**LootTableResource** `.tres`, fill its entries grid (item / weight / tags) and its pity fields, then:

- drop it on a **Loot Table Loader** node, which loads it into the LootBox autoload on ready, or
- call **LootBox: Load From Resource** yourself with the resource.

```
On Ready
  -> LootBox: Load From Resource  MyChestTable
On chest opened
  -> LootBox: Roll  "chest"
```

**SkinVault.** Make a **SkinCatalogResource** `.tres` with a rarities grid (name / weight / tier) and a
skins grid (id / name / rarity / cost / tags), then drop it on a **Skin Catalog Loader** node, or call
**SkinVault: Load Catalog**. Your whole cosmetics catalog becomes an Inspector-edited asset.

## 3. The "you forgot to attach it" warning

A loader's resource slot is **required**. While it is empty, the Inspector shows a required warning on
the field - a designer cannot silently ship a loader with no data. This is the plugin's own
required-field marker (the same one the EnemyStats showcase uses for its portrait), so it needs no extra
code and stays out of your compiled game.

That is what makes the loader worth having over a bare Load action: the loader is where the data is
attached, so the loader is where the "you forgot it" warning belongs.

## 4. Make your own addon data-driven

Say you built an autoload addon (a `WaveSpawner`) and you want its waves as data. Three steps:

**Step 1 - a Custom Resource for the data.** In a pack builder, author a `Resource`-host sheet with the
fields you need, using the table drawer for lists:

```gdscript
var sheet := EventSheetResource.new()
sheet.host_class = "Resource"
sheet.custom_class_name = "WaveSetResource"
sheet.variables = {
    "waves": {"type": "Array", "default": [], "exported": true,
        "attributes": {"drawer": "table", "table_columns": [
            {"name": "enemy", "type": "String"},
            {"name": "count", "type": "int"},
            {"name": "delay", "type": "float"}]}}
}
Lib.save_pack(sheet, "res://eventsheet_addons/wave_set_resource/wave_set_resource")
```

**Step 2 - a "Load From Resource" action** on your autoload that reads the resource dynamically (so it
does not depend on the resource class existing at build time) and applies it:

```gdscript
Lib.append_function(sheet, "load_from_resource", "Load From Resource", "Waves", "Loads a wave set.",
    [["wave_set", "Resource"]],
    "if wave_set == null:\n\treturn\nvar rows: Variant = wave_set.get(\"waves\")\nif rows is Array:\n\tfor row: Variant in (rows as Array):\n\t\tif row is Dictionary:\n\t\t\tadd_wave(str((row as Dictionary).get(\"enemy\", \"\")), int((row as Dictionary).get(\"count\", 1)), float((row as Dictionary).get(\"delay\", 1.0)))")
```

**Step 3 - a loader behavior** with a required slot, using the one-line helper:

```gdscript
var sheet := EventSheetResource.new()
sheet.behavior_mode = true
sheet.host_class = "Node"
sheet.custom_class_name = "WaveSetLoader"
Lib.require_resource(sheet, "wave_set", "Wave Set resource", "The .tres holding this level's waves.")
# ... an On Ready event that calls get_node_or_null("/root/WaveSpawner").call("load_from_resource", wave_set)
```

`Lib.require_resource(...)` adds the exported `Resource` slot AND marks it required, so the Inspector
warns until a designer attaches a `.tres`. That is the whole "built into the tooling" story: one line to
make any addon data-driven with a missing-resource warning.

Why the resource slot is typed `Resource` and not your class name: a pack cannot reference another
pack's class at build time. Any resource - including your Custom Resource `.tres` - is a `Resource`, and
reading its fields with `resource.get("field")` works regardless. The tooltip tells the designer which
resource to drop in.

## 5. Tips

- **Use the table drawer for lists.** An `Array` with `drawer: "table"` and `table_columns` becomes an
  editable grid in the Inspector - the heart of data-driven authoring.
- **Read fields dynamically** in the loader/action (`resource.get("name")`), so a pack never hard-depends
  on another pack's class name at build time.
- **Reach the autoload dynamically** too (`get_node_or_null("/root/MyAutoload").call(...)`), so the loader
  works even if the autoload is registered under a different name or added later.
- **Mark the slot required** with `Lib.require_resource(...)` so a forgotten resource shows in the
  Inspector, not as a silent runtime nothing.
- **A Custom Resource is just data** - keep game logic in the autoload or behavior that consumes it, not
  in the resource.
- **Ship the resource class in its own folder** under `eventsheet_addons/`; it round-trips like any pack,
  so the drift gate keeps it honest.
