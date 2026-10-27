# Godot EventSheets - loads the scripts named after `--`, nothing else, so a `-d` run prints the GDScript
# warnings Godot reports for them (the ones a user sees in the Debugger's Errors tab). Driven by
# emitted_code_warnings_test, which reads them back. Not a test: it has no `run()`.
#
# The files must already be known to parse: under -d a parse error stops in the debugger's prompt.
@tool
extends SceneTree


func _init() -> void:
	for path: String in OS.get_cmdline_user_args():
		if load(path) == null:
			print("PROBE could not load %s" % path)
	print("PROBE done")
	quit()
