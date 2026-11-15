# Godot EventSheets - which scripts are a Juice Player, in both shapes the pack has shipped.
#
# The pack's list node is `JuicePlayer` (juice_player.gd, the code). Before that it was one file,
# `feedback_player.gd` with `class_name FeedbackPlayer`; that file now stays where it was and only
# extends the new class, so every scene made before still points at it. A project that was made
# earlier may also hold the OLD single-file copy of the pack, where the same file name holds all the
# code. Every place that recognises "a Juice Player" asks this one file, so none of them can know
# only one shape.
#
# THIS FILE NAMES NO CLASS and has no class_name: the first-open editor and the Inspector plugin
# reach it BY PATH at the moment they need it, and a name written in their code would compile it
# (and what it names) into every editor start. The questions are PURE over names, so the suite pins
# both shapes without loading a second copy of a class.
@tool
extends RefCounted

## The global class names of the node, newest first.
const GLOBAL_NAMES: PackedStringArray = ["JuicePlayer", "FeedbackPlayer"]
## The file names of the node's scripts, newest first. The first one that exists holds the code.
const FILE_NAMES: PackedStringArray = ["juice_player.gd", "feedback_player.gd"]
const PACK_FOLDER: String = "res://eventsheet_addons/juice/"


## Whether a script, or any script it extends, is a Juice Player: by the file it is, or the global
## name it carries. Walked down the base chain, as `is` would answer, so a project's own subclass of
## the node counts and a node wearing the old name counts.
static func is_player_script(script: Script) -> bool:
	while script != null:
		if is_player_names(script.resource_path.get_file(), script.get_global_name()):
			return true
		script = script.get_base_script()
	return false


## One script's file name and global name, asked on their own. PURE.
static func is_player_names(file_name: String, global_name: String) -> bool:
	return FILE_NAMES.has(file_name) or GLOBAL_NAMES.has(global_name)


## Whether a node wears a Juice Player script.
static func is_player(object: Object) -> bool:
	return object != null and is_player_script(object.get_script() as Script)


## The file that holds the pack node's code in this project: the newest shape that is there. The
## old name's file is a thin shell that only extends the class holding the code, so statics and
## constants are read from the code file rather than through it.
static func pack_path() -> String:
	for file_name: String in FILE_NAMES:
		if ResourceLoader.exists(PACK_FOLDER + file_name):
			return PACK_FOLDER + file_name
	return PACK_FOLDER + FILE_NAMES[-1]
