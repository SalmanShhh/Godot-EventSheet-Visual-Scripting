@tool
extends SceneTree

const GD_PATH := "res://demo/showcase/_proto_raycast/raycast_lab.gd"
const SCENE_PATH := "res://demo/showcase/_proto_raycast/raycast_lab.tscn"


func _init() -> void:
	var importer: GDScriptImporter = GDScriptImporter.new()
	var sheet: EventSheetResource = importer.import_external(GD_PATH)
	print("[rt] imported=", sheet != null)
	if sheet == null:
		quit(1)
		return
	var result: Dictionary = SheetCompiler.compile(sheet, GD_PATH, true)
	print("[rt] recompile_success=", result.get("success", false), " warnings=", result.get("warnings", []))
	var output: String = str(result.get("output", ""))
	var shipped: String = FileAccess.get_file_as_string(GD_PATH)
	print("[rt] BYTE_IDENTICAL=", output == shipped, " out_len=", output.length(), " shipped_len=", shipped.length())
	if output != shipped:
		var a: PackedStringArray = output.split("\n")
		var b: PackedStringArray = shipped.split("\n")
		for i: int in maxi(a.size(), b.size()):
			var la: String = a[i] if i < a.size() else "<none>"
			var lb: String = b[i] if i < b.size() else "<none>"
			if la != lb:
				print("[rt] first diff line ", i + 1)
				print("[rt]   recompiled: ", la)
				print("[rt]   shipped   : ", lb)
				break
	var packed: PackedScene = load(SCENE_PATH)
	var root: Node = packed.instantiate()
	var wanted: PackedStringArray = PackedStringArray(["Player", "Radar", "Movement", "Gate", "InkLayer", "Ink", "Target0", "Hud", "Readout"])
	for node_name: String in wanted:
		print("[rt] scene has ", node_name, "=", root.find_child(node_name, true, false) != null)
	root.free()
	quit(0)
