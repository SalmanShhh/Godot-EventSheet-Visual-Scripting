# EventForge - addon guide scaffolder (dev tool). Emits a docs/Addons-style guide skeleton for a
# pack, pre-filled with its REAL verb/knob tables so the 15-use-case house standard is cheap to
# meet. Run headless:
#   godot --headless --path . --script tools/scaffold_addon_guide.gd -- <pack_script_or_dir> [out.md]
# Default output: docs/Addons/_SKELETON-<Class>.md. Refuses to overwrite an existing file -
# a finished guide must never be clobbered by a skeleton.
@tool
extends SceneTree


func _init() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.is_empty():
		print("usage: godot --headless --path . --script tools/scaffold_addon_guide.gd -- <pack_script_or_dir> [out.md]")
		quit(1)
		return
	var target: String = arguments[0]
	if not target.begins_with("res://"):
		target = "res://" + target.trim_prefix("./")
	# A directory resolves to its provider script (the one with a class_name).
	if DirAccess.dir_exists_absolute(target):
		for file: String in DirAccess.get_files_at(target):
			if file.ends_with(".gd"):
				var candidate: Script = load(target.path_join(file)) as Script
				if candidate != null and not str(candidate.get_global_name()).is_empty():
					target = target.path_join(file)
					break
	var markdown: String = EventSheets.addon_guide_skeleton(target)
	if markdown.is_empty():
		print("scaffold: could not read a provider script at %s" % target)
		quit(1)
		return
	var script_class: String = str((load(target) as Script).get_global_name())
	var out_path: String = arguments[1] if arguments.size() > 1 else "res://docs/Addons/_SKELETON-%s.md" % script_class
	if not out_path.begins_with("res://"):
		out_path = "res://" + out_path
	if FileAccess.file_exists(out_path):
		print("scaffold: %s already exists - refusing to overwrite (pass a different out path)" % out_path)
		quit(1)
		return
	var out_file: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
	out_file.store_string(markdown)
	out_file.close()
	print("scaffold: wrote %s (%d lines) - the tables are real, the use cases are yours to write" % [out_path, markdown.split("\n").size()])
	quit(0)
