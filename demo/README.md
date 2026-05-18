# EventForge Demo Project

## Open

Open the repository root project for normal editing, or temporarily rename `demo/demo_project.godot` to `demo/project.godot` if you need to import the demo as a standalone Godot project. Rename it back afterwards so the root project does not start warning about a nested `project.godot` again.

## Compile manually

Use a script or editor tool call equivalent to:

```gdscript
var sheet: EventSheetResource = load("res://sheets/player.tres")
var result: Dictionary = SheetCompiler.compile(sheet, "res://sheets/player_generated.gd")
print(result)
```

## Verify

Compare generated output to `demo/sheets/player_generated.gd`.
The `tests/compile_demo_test.gd` script performs this check automatically.

## Example EventSheet themes

Bundled example themes live in `res://demo/themes/`:

- `construct3_stacked_theme.tres`
- `high_contrast_theme.tres`
- `soft_light_theme.tres`
- `designer_template_theme.tres`
- `designer_template_theme_manifest.cfg`

Load them from the EventSheet dock with **Load Theme**.

The manifest file is a token/package template for designers who want a Construct-style installable theme workflow.
