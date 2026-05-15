# EventForge Demo Project

## Open

Open `demo/` with Godot 4.3.

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
