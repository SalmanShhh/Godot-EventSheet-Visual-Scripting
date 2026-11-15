# Godot EventSheets - the watcher EventSheets.edit() holds over a mutation.
#
# Loaded by path, only for the length of one edit() call. GDScript cannot catch an error, and a
# callable that hits one returns to its caller as if it had finished, so this logger counts the script
# errors raised while it is attached: edit() asks it afterwards whether the mutation ran clean.
@tool
extends Logger

## How many script errors were raised while this watcher was attached.
var errors: int = 0


func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type == ERROR_TYPE_SCRIPT:
		errors += 1
