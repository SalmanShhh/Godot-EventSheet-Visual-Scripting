# EventForge — plugin teardown symmetry test.
# "Easy to remove without breaking the project" depends on _exit_tree fully undoing
# _enter_tree. This guards the contract statically: every EditorPlugin lifecycle add_* the
# plugin performs must have a matching remove_* so disabling the plugin leaves no orphan
# autoload, inspector/export/debugger plugin, or context menu behind.
@tool
class_name PluginTeardownTest
extends RefCounted

const PLUGIN_PATH: String = "res://addons/eventforge/plugin.gd"

# EditorPlugin add_/remove_ pairs the plugin uses (the lifecycle resources it registers).
const LIFECYCLE: Array[String] = [
	"autoload_singleton",
	"context_menu_plugin",
	"inspector_plugin",
	"export_plugin",
	"debugger_plugin",
]


static func run() -> bool:
	var passed: bool = true
	var source: String = FileAccess.get_file_as_string(PLUGIN_PATH)
	passed = _check("plugin.gd is readable", not source.is_empty(), true) and passed
	for resource: String in LIFECYCLE:
		var adds: bool = source.contains("add_%s(" % resource)
		var removes: bool = source.contains("remove_%s(" % resource)
		# Only require the remove when the plugin actually adds that resource type.
		if adds:
			passed = _check("add_%s has a paired remove_%s" % [resource, resource], removes, true) and passed
	# The main-screen editor is add_child'd to the main screen; _exit_tree must free it so the
	# workspace tab disappears on disable.
	passed = _check("the main-screen editor is freed in _exit_tree",
		source.contains("get_editor_main_screen") and (source.contains("queue_free()") or source.contains(".free()")), true) and passed
	return passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] plugin_teardown_test: %s" % label)
		return true
	print("[FAIL] plugin_teardown_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
