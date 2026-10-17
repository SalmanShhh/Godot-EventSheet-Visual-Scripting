# Godot EventSheets - the first read of the editor's translations, in a process of its own.
#
# The engine warns ONCE per session when an OptimizedTranslation is asked to list its messages, so
# the claim "reading the translations prints nothing" can only be checked in a process where nothing
# has read them yet. The suite's own process has read them long before any test runs. This probe
# reads them first, with an ear on the engine log, and prints one `l10n_probe heard=N` line, then a
# `l10n_probe_heard <message>` line for each thing it heard, which editor_l10n_test pins.
#
#     $GODOT --headless --path . --script tests/l10n_first_read_probe.gd
#
# A helper, not a test - it declares no `run` and is not named `*_test.gd`, so the suite's
# discovery never picks it up.
@tool
extends SceneTree


func _init() -> void:
	var ear: Ear = Ear.new()
	OS.add_logger(ear)
	EventSheetL10n.rescan()
	OS.remove_logger(ear)
	for message: String in ear.heard:
		print("l10n_probe_heard %s" % message)
	print("l10n_probe heard=%d" % ear.heard.size())
	quit(0)


## Hears every engine error and warning while it is added.
class Ear extends Logger:
	var heard: PackedStringArray = PackedStringArray()

	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		heard.append(rationale if not rationale.is_empty() else code)
