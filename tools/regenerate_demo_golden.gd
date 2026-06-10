# EventForge — dev tool: regenerate the demo golden output after intentional codegen
# changes (run headless: godot --headless --script tools/regenerate_demo_golden.gd).
# compile_demo_test compares SheetCompiler output against demo/sheets/player_generated.gd;
# regenerating keeps the golden honest when emission changes on purpose (CHANGELOG it!).
@tool
extends SceneTree

func _init() -> void:
	var sheet: EventSheetResource = load("res://demo/sheets/player.tres") as EventSheetResource
	if sheet == null:
		push_error("demo sheet not found")
		quit(1)
		return
	var result: Dictionary = SheetCompiler.compile(sheet, "res://demo/sheets/player_generated.gd")
	print("[regenerate_demo_golden] success=%s warnings=%s" % [result.get("success"), result.get("warnings")])
	quit(0)
