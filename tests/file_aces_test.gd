# Godot EventSheets - File-management ACEs (read / write / JSON / directories).
#
# Verifies the Files / Files: Directories vocabulary registers, the codegen templates are the exact
# native FileAccess / DirAccess calls, and - critically - that the multi-line guarded write templates
# COMPILE to valid GDScript and actually round-trip on disk (a wrong static method would compile fine
# as a string but fail silently at runtime, so this runs the generated code).
@tool
class_name FileAcesTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_DIR := "user://__fileace_test"

## The path this test compiles TO. A compile writes its output where it is told, so the file is one
## more thing this test made and one more thing it takes away.
const COMPILE_OUTPUT: String = "user://__fileace_compiled.gd"


static func run() -> bool:
	var all_passed: bool = true
	var by_id: Dictionary = {}
	for descriptor in EventForgeBuiltinACEs.get_descriptors():
		by_id[descriptor.ace_id] = descriptor

	# Registration: the full vocabulary is present, grouped under Files / Files: Directories.
	for ace_id: String in ["FileExists", "ReadTextFile", "GetFileSize", "WriteTextFile", "AppendTextFile", "DeleteFile", "CopyFile", "MoveFile", "DirExists", "MakeDir", "RemoveDir", "ListFiles", "ListDirs"]:
		all_passed = _check("ACE registered: %s" % ace_id, by_id.has(ace_id), true) and all_passed
	all_passed = _check("file ACEs group under Files", str(by_id["ReadTextFile"].category), "Files") and all_passed
	all_passed = _check("directory ACEs group under Files: Directories", str(by_id["ListFiles"].category), "Files: Directories") and all_passed

	# Templates are the exact native calls; reads use the null-safe static accessors.
	all_passed = _check("read uses the null-safe static accessor", str(by_id["ReadTextFile"].codegen_template), "FileAccess.get_file_as_string({path})") and all_passed
	all_passed = _check("file-exists wraps FileAccess.file_exists", str(by_id["FileExists"].codegen_template), "FileAccess.file_exists({path})") and all_passed
	all_passed = _check("list-files wraps DirAccess.get_files_at", str(by_id["ListFiles"].codegen_template), "DirAccess.get_files_at({path})") and all_passed
	all_passed = _check("delete wraps DirAccess.remove_absolute", str(by_id["DeleteFile"].codegen_template), "DirAccess.remove_absolute({path})") and all_passed
	all_passed = _check("write guards the FileAccess handle (no null-deref)",
		str(by_id["WriteTextFile"].codegen_template).contains("if __file_{uid}:") and str(by_id["WriteTextFile"].codegen_template).contains("FileAccess.WRITE"), true) and all_passed

	# Runtime round-trip: compile a sheet that makes a dir, writes, appends, and saves JSON, confirm
	# the generated script PARSES (the multi-line guarded templates), then run it and read the result.
	_cleanup()
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	event.actions.append(_action("MakeDir", by_id, {"path": "\"%s\"" % TEST_DIR}, ""))
	event.actions.append(_action("WriteTextFile", by_id, {"path": "\"%s/a.txt\"" % TEST_DIR, "text": "\"hello\""}, "w1"))
	event.actions.append(_action("AppendTextFile", by_id, {"path": "\"%s/a.txt\"" % TEST_DIR, "text": "\" world\""}, "w2"))
	sheet.events.append(event)
	var output: String = str(SheetCompiler.compile(sheet, COMPILE_OUTPUT).get("output", ""))
	var script: GDScript = GDScript.new()
	script.source_code = output
	var reload_ok: bool = script.reload() == OK
	all_passed = _check("file-ACE sheet compiles to valid GDScript (multi-line guarded writes)", reload_ok, true) and all_passed
	if reload_ok:
		var node: Node = script.new()
		node._ready()
		all_passed = _check("Write created the file", FileAccess.file_exists(TEST_DIR + "/a.txt"), true) and all_passed
		all_passed = _check("Write + Append produced the combined content", FileAccess.get_file_as_string(TEST_DIR + "/a.txt"), "hello world") and all_passed
		node.free()
	_cleanup()
	return all_passed


## ACEAction with the registered template, baking {uid} -> the given token (distinct per multi-line
## ACE so the `var __file_<uid>` locals never collide), exactly as the dock does at apply time.
static func _action(ace_id: String, by_id: Dictionary, params: Dictionary, uid: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.codegen_template = str(by_id[ace_id].codegen_template).replace("{uid}", uid)
	action.params = params
	return action


## Everything this test wrote, the compile's own output included: it lands where the compile was
## told to write it, which is beside the folder rather than inside it.
static func _cleanup() -> void:
	DirAccess.remove_absolute(TEST_DIR + "/a.txt")
	DirAccess.remove_absolute(TEST_DIR + "/b.json")
	DirAccess.remove_absolute(TEST_DIR)
	if FileAccess.file_exists(COMPILE_OUTPUT):
		DirAccess.remove_absolute(COMPILE_OUTPUT)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("file_aces_test", label, actual, expected)
