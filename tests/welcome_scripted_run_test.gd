# EventForge - an editor a tool or a render harness starts with --script is not a person opening the
# project, so its first run neither pops the Welcome nor switches the project to Simple Mode (which
# would hand the reader's next session a "+ Event / + Sub-event" strip they never chose).
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "welcome_scripted_run_test"


static func run() -> bool:
	return SUPPORT.pins(P, [
		["a render harness run is scripted",
			EventSheetWelcomeWindow.is_scripted_run(PackedStringArray(["--editor", "--path", ".", "--script", "tools/render_x.gd"])), true],
		["so is the short spelling", EventSheetWelcomeWindow.is_scripted_run(PackedStringArray(["-e", "-s", "x.gd"])), true],
		["a person opening the editor is not", EventSheetWelcomeWindow.is_scripted_run(PackedStringArray(["--editor", "--path", "."])), false],
	])
