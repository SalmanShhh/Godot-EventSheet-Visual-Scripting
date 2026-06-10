# Godot EventSheets — Demo Project

The demo assets exercised by the test suite and the quickest way to poke at the plugin.

## What's here

| Path | What it is |
|---|---|
| `sheets/player.tres` | The demo event sheet (variables, triggers, conditions, actions) |
| `sheets/player_generated.gd` | Its compiled output — also the **golden file** `tests/compile_demo_test.gd` checks against |
| `scenes/player.tscn` | A minimal CharacterBody2D with the generated script attached |
| `themes/` | Bundled editor themes + the designer template/manifest |
| `demo_project.godot` | Rename to `project.godot` only if you need the demo as a standalone project (rename back afterwards) |

The sample **behavior packs** (PlatformerMovement, EightDirectionMovement) live in
`res://eventsheet_addons/`, not here — they double as zero-config addon examples.

## Try it

1. Open the repository root project in Godot 4.5+ and open the **EventSheet** tab.
2. Open `demo/sheets/player.tres` — edit events, watch the GDScript panel (toolbar →
   "GDScript") highlight both ways.
3. Compile; the output is `sheets/player_generated.gd`, attached to `scenes/player.tscn`.

## Compile manually

```gdscript
var sheet: EventSheetResource = load("res://demo/sheets/player.tres")
var result: Dictionary = SheetCompiler.compile(sheet, "res://demo/sheets/player_generated.gd")
print(result.get("warnings"))
```

`tests/compile_demo_test.gd` performs the golden comparison automatically; after an
intentional codegen change, regenerate the golden with
`godot --headless --script tools/regenerate_demo_golden.gd`.

## Themes

Bundled in `res://demo/themes/` and listed in the dock's **toolbar theme switcher**
(no file dialog needed): `construct3_stacked_theme`, `high_contrast_theme`,
`soft_light_theme`, plus `designer_template_theme.tres` +
`designer_template_theme_manifest.cfg` as the duplicate-me starting point for designers.
The **Theme Editor…** toolbar dialog edits any of them live (reflective token form,
preset saving); with no theme assigned, the editor derives a Godot-native look from your
editor theme.
