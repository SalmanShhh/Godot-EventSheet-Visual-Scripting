# Godot EventSheets - WRITES THE FINGERPRINT OF EVERY DOCUMENTATION PICTURE into the shot list (dev tool).
#
# Run right after a capture, on the same tree, so the fingerprint says what the picture was taken of:
#
#   "$GODOT" --headless --path . --script tools/doc_shots_fingerprint.gd -- list=res://tools/doc_shots/shots.json write=1
#
# Without `write=1` it only prints what each fingerprint would be. `only=a,b` limits it to some shots.
# The list is rewritten sorted and tab indented, so a rewrite that changes nothing changes no byte.
@tool
extends SceneTree

const FINGERPRINTS := preload("res://tools/doc_shots/fingerprints.gd")


func _init() -> void:
	var arguments: Dictionary = {}
	for argument: String in OS.get_cmdline_user_args():
		var at: int = argument.find("=")
		if at > 0:
			arguments[argument.substr(0, at)] = argument.substr(at + 1)
	var list_path: String = str(arguments.get("list", FINGERPRINTS.DEFAULT_LIST))
	var only: PackedStringArray = str(arguments.get("only", "")).split(",", false)
	var list: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(list_path))
	var written: int = 0
	for shot: Dictionary in list["shots"]:
		if not only.is_empty() and not only.has(str(shot["name"])):
			continue
		var target: String = "res://" + str(shot.get("target", ""))
		shot["fingerprint"] = FINGERPRINTS.of_shot(shot, target)
		written += 1
		print("%s %s" % [shot["name"], JSON.stringify(shot["fingerprint"])])
	if str(arguments.get("write", "")) == "1":
		var file: FileAccess = FileAccess.open(list_path, FileAccess.WRITE)
		file.store_string(JSON.stringify(list, "\t", true) + "\n")
		file.close()
		print("fingerprints written=%d" % written)
	quit(0)
