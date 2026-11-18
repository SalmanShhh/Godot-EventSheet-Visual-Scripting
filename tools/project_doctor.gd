# Godot EventSheets - headless Project Doctor driver (CI-able).
#
#   godot --headless --path . --script tools/project_doctor.gd
#   godot --headless --path . --script tools/project_doctor.gd -- --known-sheets
#
# Every script is checked as a sheet, as it always was; `--known-sheets` checks only the scripts the
# plugin knows are sheets (the compiler's banner, or recorded as saved from the sheet editor in this
# project's editor metadata) and gives the rest only the checks that make sense for any script.
#
# Exit 0 when no errors; pass `-- --strict` to fail on warnings too. The repo's CI
# runs the default form, so byte-drift between sheets and committed generated scripts
# fails the build while advisory notes don't.
@tool
extends SceneTree


func _init() -> void:
	var options: Dictionary = {}
	if OS.get_cmdline_user_args().has("--known-sheets"):
		load("res://addons/eventforge/known_sheets.gd").load_from_project_file()
		options["known_only"] = true
	var report: Dictionary = EventSheetProjectDoctor.run(options)
	for finding: Dictionary in (report.get("findings", []) as Array):
		# A finding about one row is addressed the way the sheet addresses it: "path (event 4)".
		var event_number: int = int(finding.get("event", 0))
		var where: String = str(finding.get("path"))
		if event_number > 0:
			where += " (event %d)" % event_number
		print("[%s] %s - %s" % [str(finding.get("severity")).to_upper(), where, str(finding.get("message"))])
	var errors: int = int(report.get("errors", 0))
	var warnings: int = int(report.get("warnings", 0))
	print("doctor: %d error(s), %d warning(s), %d note(s)" % [errors, warnings, int(report.get("infos", 0))])
	var strict: bool = OS.get_cmdline_user_args().has("--strict")
	quit(1 if errors > 0 or (strict and warnings > 0) else 0)
