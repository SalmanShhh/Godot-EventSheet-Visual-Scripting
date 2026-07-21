# EventForge - Doctor lint for fragile, over-coupled node paths.
#
# Applies the "your nodes are too connected" learning as guidance: a node reference that reaches the SCENE
# ROOT (absolute /root/...) or climbs two-or-more parents (../../..) assumes exactly where a node lives and
# breaks silently when it moves. The lint flags ONLY those - a single ../Sibling, a $Named ref, and the
# decoupled group forms are left alone, so it never alert-fatigues. Pins the detection rule directly.
@tool
class_name FragilePathDoctorTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	ok = _check("absolute /root path is flagged", _fragile("get_node(\"/root/Main/Player\").health = 0"), ["/root/Main/Player"]) and ok
	ok = _check("deep parent reach (../../) is flagged", _fragile("$\"../../Sibling\".visible = true"), ["../../Sibling"]) and ok
	ok = _check("a leading-slash absolute quoted ref is flagged", _fragile("get_node(\"/Root/UI/Score\")"), ["/Root/UI/Score"]) and ok

	# NOT flagged - these are the fine / decoupled forms, so the lint stays quiet.
	ok = _check("a single ../Sibling reach is NOT flagged", _fragile("get_node(\"../Enemy\").die()").is_empty(), true) and ok
	ok = _check("a plain $Named ref is NOT flagged", _fragile("$Player.position.x").is_empty(), true) and ok
	ok = _check("a scene-unique %Name ref is NOT flagged", _fragile("%HealthBar.value = 3").is_empty(), true) and ok
	ok = _check("the decoupled group form is NOT flagged", _fragile("get_tree().get_first_node_in_group(\"player\")").is_empty(), true) and ok
	ok = _check("empty text yields nothing", _fragile("").is_empty(), true) and ok

	return ok


## Sorted list of the fragile references the Doctor extracts from one expression.
static func _fragile(text: String) -> Array:
	var found: Dictionary = {}
	EventSheetProjectDoctor._note_fragile_paths(text, found)
	var keys: Array = found.keys()
	keys.sort()
	return keys


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] fragile_path_doctor_test: %s" % label)
		return true
	print("[FAIL] fragile_path_doctor_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
