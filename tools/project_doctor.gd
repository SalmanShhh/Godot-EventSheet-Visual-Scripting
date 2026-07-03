# Godot EventSheets — headless Project Doctor driver (CI-able).
#
#   godot --headless --path . --script tools/project_doctor.gd
#
# Exit 0 when no errors; pass `-- --strict` to fail on warnings too. The repo's CI
# runs the default form, so byte-drift between sheets and committed generated scripts
# fails the build while advisory notes don't.
@tool
extends SceneTree


func _init() -> void:
	var report: Dictionary = EventSheetProjectDoctor.run()
	for finding: Dictionary in (report.get("findings", []) as Array):
		print("[%s] %s — %s" % [str(finding.get("severity")).to_upper(), str(finding.get("path")), str(finding.get("message"))])
	var errors: int = int(report.get("errors", 0))
	var warnings: int = int(report.get("warnings", 0))
	print("doctor: %d error(s), %d warning(s), %d note(s)" % [errors, warnings, int(report.get("infos", 0))])
	var strict: bool = OS.get_cmdline_user_args().has("--strict")
	quit(1 if errors > 0 or (strict and warnings > 0) else 0)
