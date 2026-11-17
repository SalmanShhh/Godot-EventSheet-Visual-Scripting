# Godot EventSheets - a behaviour with no host says WHICH one it is.
#
# The scaffold's `push_warning` used to say only "Sine Behavior needs a Node2D: put it under one, or set
# Acts on." - true, and no help in a scene with forty of them. New emission adds the node's path. An
# existing behaviour file keeps the sentence it has: the host binding is read back as the file wrote
# it, so an untouched open and save is byte-identical in either spelling.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "host_warning_names_node_test"
const NEW_TAIL := " This one is at \" + str(get_path()) + \".\")"


static func run() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = EventSheets.new_sheet({"class_name": "ProbeHover", "host_class": "Node2D", "behavior_mode": true})
	var text: String = str(EventSheets.echo(sheet).get("output", ""))
	ok = SUPPORT.check(P, "a new behaviour names its node in the warning",
		text.contains("\t\tpush_warning(\"Probe Hover needs a Node2D: put it under one, or set Acts on." + NEW_TAIL), true) and ok
	ok = SUPPORT.check(P, "the new behaviour parses", _parses(text), true) and ok
	# The shipped pack is written with the new sentence; the old form is the same file with that tail taken
	# off, which is how every behaviour written before this change still reads.
	var new_source: String = FileAccess.get_file_as_string("res://eventsheet_addons/sine/sine_behavior.gd")
	ok = SUPPORT.check(P, "the shipped pack holds the new sentence", new_source.contains("put it under one, or set Acts on." + NEW_TAIL), true) and ok
	var old_source: String = new_source.replace("put it under one, or set Acts on." + NEW_TAIL, "put it under one, or set Acts on.\")")
	ok = SUPPORT.check(P, "the old form holds the old sentence", old_source.contains("push_warning(\"Sine Behavior needs a Node2D: put it under one, or set Acts on.\")"), true) and ok
	ok = SUPPORT.check(P, "a pack with the old sentence opens and saves back byte for byte", SUPPORT.reemit(old_source, SUPPORT.own_path("host_warning_old.gd")), old_source) and ok
	ok = SUPPORT.check(P, "a pack with the new sentence opens and saves back byte for byte", SUPPORT.reemit(new_source, SUPPORT.own_path("host_warning_new.gd")), new_source) and ok
	# The Doctor's sentence about a scene is unchanged: it names the scene node itself.
	ok = SUPPORT.check(P, "the shared sentence is unchanged",
		EventSheetCompiler.host_warning_sentence("SineBehavior", "Node2D"), "Sine Behavior needs a Node2D: put it under one, or set Acts on.") and ok
	return ok


static func _parses(source: String) -> bool:
	var script: GDScript = GDScript.new()
	script.source_code = source.replace("class_name ProbeHover", "")
	return script.reload() == OK
