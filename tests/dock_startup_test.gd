# Godot EventSheets — dock startup must not stack untitled sheets.
#
# Regression for "two untitled/unsaved event sheets open on project open": _ready() built a demo and
# called setup(), and the plugin called setup() AGAIN right after add_child() (which had already run
# _ready) — two demos. setup(null) is now idempotent: it seeds a single starting sheet only when no
# tab exists yet, so the plugin's defensive second call is a harmless no-op.
@tool
extends RefCounted
class_name DockStartupTest

static func run() -> bool:
	var all_passed: bool = true
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock

	dock.setup(null)
	var first_count: int = dock._open_tabs.size()
	all_passed = _check("first null setup() seeds exactly one starting tab", first_count, 1) and all_passed

	# The plugin's redundant post-add_child setup() must NOT add a second untitled sheet.
	dock.setup(null)
	all_passed = _check("a second null setup() is a no-op (the two-untitled bug)", dock._open_tabs.size(), first_count) and all_passed

	# A non-null setup() is never a no-op — loading a real sheet still opens its tab.
	var real: EventSheetResource = EventSheetResource.new()
	real.resource_path = "res://__dock_startup_probe.tres"
	dock.setup(real)
	all_passed = _check("a non-null setup() still opens its tab", dock._open_tabs.size(), first_count + 1) and all_passed

	dock.free()
	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] dock_startup_test: %s" % label)
		return true
	print("[FAIL] dock_startup_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
