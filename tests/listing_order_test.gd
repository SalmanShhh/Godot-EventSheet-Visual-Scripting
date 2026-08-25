# EventForge - platform-stable listing order gate.
# DirAccess.list_dir_begin()/get_next() hands entries back in filesystem order - near-alphabetical
# on NTFS, hash order on ext4 - so any list collected from a directory walk answers differently per
# platform unless it is sorted at the collection point. These checks pin the project-wide listings
# that feed user-visible output (Find results, Doctor findings, band sentences, MCP tool output) as
# path-sorted, so a walk that loses its sort fails here before it fails on somebody else's OS.
@tool
class_name ListingOrderTest
extends RefCounted


static func run() -> bool:
	var passed: bool = true
	var scene_paths: PackedStringArray = EventSheetSceneConnections.scene_paths()
	var doctor_scripts: PackedStringArray = EventSheetProjectDoctor._walk_project_scripts()
	passed = _check_sorted("scene_paths()", scene_paths) and passed
	passed = _check_sorted("list_project_sheets()", EventSheetProjectFind.list_project_sheets()) and passed
	passed = _check_sorted("doctor project scripts", doctor_scripts) and passed
	passed = _check_sorted("animation fact files", EventSheetAnimationTrackFacts._files_that_could_hold_animations()) and passed
	passed = _check_sorted("export sheet paths", EventSheetExportIntegrityPlugin._find_sheet_paths("res://")) and passed
	# An empty list is sorted by definition, so a walk that found nothing would pass vacuously -
	# these two sweep the repository itself, which is never empty of scenes or scripts.
	passed = _check("scene_paths() found the repository's scenes", scene_paths.is_empty(), false) and passed
	passed = _check("doctor walk found the repository's scripts", doctor_scripts.is_empty(), false) and passed
	return passed


static func _check_sorted(label: String, listing: PackedStringArray) -> bool:
	for index in range(1, listing.size()):
		if listing[index - 1] > listing[index]:
			print("  [FAIL] listing_order_test: %s is path-sorted" % label)
			print("    out of order: %s before %s" % [listing[index - 1], listing[index]])
			return false
	print("[PASS] listing_order_test: %s is path-sorted" % label)
	return true


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] listing_order_test: %s" % label)
		return true
	print("  [FAIL] listing_order_test: %s" % label)
	print("    expected: %s" % str(expected))
	print("    got: %s" % str(actual))
	return false
