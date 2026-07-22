# EventForge - the Tools "Report an Issue…" report skeleton.
#
# The report is pre-filled into a URL and handed to the user's browser, so what it contains is a
# privacy promise as much as a convenience: exactly three environment facts travel (plugin build,
# Godot build, platform) and nothing that could identify the project or the person. This test pins
# both halves - that the useful facts ARE there, and that the identifying ones are NOT - because a
# well-meaning "let's also include the project name" edit would otherwise pass silently.
@tool
class_name ReportIssueTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true
	var body: String = EventSheetDock.issue_report_body()

	# 1. The three facts a maintainer needs to reproduce anything.
	all_passed = _check("names the plugin build", body.contains("- EventSheets: %s" % SheetCompiler.VERSION), true) and all_passed
	all_passed = _check("names the Godot build",
		body.contains("- Godot: %s" % str(Engine.get_version_info().get("string", "unknown"))), true) and all_passed
	all_passed = _check("names the platform", body.contains("- Platform: %s" % OS.get_name()), true) and all_passed

	# 2. The prompts that make a report actionable rather than "it broke".
	for heading: String in ["### What happened", "### What you expected instead", "### Steps to reproduce"]:
		all_passed = _check("asks %s" % heading, body.contains(heading), true) and all_passed

	# 3. Nothing identifying rides along. Paths are the realistic leak - a res:// path globalizes to
	# something like C:/Users/<name>/... and would carry the user's name into a public tracker.
	all_passed = _check("carries no resource paths", body.contains("res://"), false) and all_passed
	all_passed = _check("carries no user paths", body.contains("user://"), false) and all_passed
	all_passed = _check("carries no globalized project path",
		body.contains(ProjectSettings.globalize_path("res://")), false) and all_passed
	all_passed = _check("carries no project name",
		body.contains(str(ProjectSettings.get_setting("application/config/name", "@@none@@"))), false) and all_passed

	# 4. The tracker URL survives encoding as a single query value - an unencoded newline or "#"
	# would truncate the body at the browser.
	var encoded: String = body.uri_encode()
	all_passed = _check("encoded body has no raw newline", encoded.contains("\n"), false) and all_passed
	all_passed = _check("encoded body has no raw fragment marker", encoded.contains("#"), false) and all_passed
	all_passed = _check("tracker is the addon's issue page",
		EventSheetDock.ISSUES_URL.begins_with("https://github.com/"), true) and all_passed

	if all_passed:
		print("[PASS] report_issue: skeleton carries the build facts and nothing identifying.")
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("[FAIL] report_issue: %s - expected %s, got %s" % [label, str(expected), str(actual)])
	return false
