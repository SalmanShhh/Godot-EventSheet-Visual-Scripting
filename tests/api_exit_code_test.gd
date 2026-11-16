# Godot EventSheets - a headless script that registers a lambda and quits gets its own exit code.
#
# A script that registers a Doctor check or a palette command as a lambda and then quits used to end
# the process in a segfault (exit 139) whatever it asked for: the registries are static, so the
# lambda outlived the script that made it. CI read every such run as a crash. This test runs that
# script in a child Godot and reads the exit code it really gets. It names the API in a second
# process, so it runs alone after the parallel shards.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "api_exit_code_test"
const PARALLEL_UNSAFE := true
const PROBE := """extends SceneTree


func _init() -> void:
	EventSheets.register_doctor_check("api_exit_code_test.lambda", func(_paths: PackedStringArray, _findings: Array) -> void: pass)
	EventSheets.register_palette_command("Exit Code Probe", func() -> void: pass)
	EventSheets.register_row_menu_item("Exit Code Probe", func(_row: Resource) -> bool: return true, func(_row: Resource) -> void: pass)
	EventSheets.on_sheet_saved(func(_payload: Dictionary) -> void: pass)
	quit(%d)
"""


static func run() -> bool:
	var ok: bool = true
	for wanted: int in [0, 1]:
		var path: String = SUPPORT.own_path("exit_code_probe_%d.gd" % wanted)
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(PROBE % wanted)
		file.close()
		var output: Array = []
		var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", ProjectSettings.globalize_path(path)], output, true)
		ok = SUPPORT.check(P, "a script quitting with %d after registering lambdas exits %d" % [wanted, wanted], code, wanted) and ok
	return ok
