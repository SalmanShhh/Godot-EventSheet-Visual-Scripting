# EventForge - the Platform Info pack (Construct's Platform Info, Godot-shaped). The pack is a
# bank of PURE engine queries, so the test instantiates the shipped addon and calls every verb
# headless: conditions must return bools, expressions their advertised types, and nothing may
# crash under the headless display server (which answers with defaults - values are the OS's
# business, types and safety are ours). Also pins the autoload identity + the guide's presence.
@tool
class_name PlatformInfoPackTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true
	var script: Script = load("res://eventsheet_addons/platform_info/platform_info_addon.gd")
	ok = _check(ok, script != null and script.can_instantiate(), "the pack script loads")
	var addon: Node = script.new() as Node
	ok = _check(ok, addon != null, "the addon instantiates")
	if addon == null:
		return false

	for condition_name: String in ["is_mobile", "is_desktop", "is_web", "has_touchscreen", "is_portrait", "is_debug_build"]:
		ok = _check(ok, typeof(addon.call(condition_name)) == TYPE_BOOL, "%s returns a bool" % condition_name)
	ok = _check(ok, typeof(addon.call("has_feature", "editor")) == TYPE_BOOL, "has_feature returns a bool")
	ok = _check(ok, addon.call("is_debug_build") == true, "a test run IS a debug build")

	var string_expressions: PackedStringArray = ["os_name", "os_version", "device_model", "locale", "locale_language", "engine_version", "gpu_name", "gpu_vendor", "rendering_method", "cpu_name"]
	for expression_name: String in string_expressions:
		ok = _check(ok, typeof(addon.call(expression_name)) == TYPE_STRING, "%s returns text" % expression_name)
	ok = _check(ok, not str(addon.call("os_name")).is_empty(), "os_name is non-empty")
	ok = _check(ok, str(addon.call("engine_version")).begins_with("4."), "engine_version reads the running engine")

	var int_expressions: PackedStringArray = ["screen_width", "screen_height", "screen_dpi", "screen_count", "safe_area_top", "safe_area_left", "safe_area_bottom_inset", "safe_area_right_inset", "cpu_thread_count"]
	for expression_name: String in int_expressions:
		ok = _check(ok, typeof(addon.call(expression_name)) == TYPE_INT, "%s returns a whole number" % expression_name)
	ok = _check(ok, int(addon.call("cpu_thread_count")) >= 1, "cpu_thread_count is at least 1")

	for expression_name: String in ["screen_refresh_rate", "screen_scale", "memory_physical_mb"]:
		ok = _check(ok, typeof(addon.call(expression_name)) == TYPE_FLOAT, "%s returns a number" % expression_name)
	ok = _check(ok, float(addon.call("memory_physical_mb")) >= 0.0, "physical memory is never negative")

	# Identity: ships as the PlatformInfo autoload; the guide exists at the house standard.
	var source: String = FileAccess.get_file_as_string("res://eventsheet_addons/platform_info/platform_info_addon.gd")
	ok = _check(ok, source.contains("class_name PlatformInfoAddon"), "the pack keeps its class name")
	ok = _check(ok, FileAccess.file_exists("res://docs/Addons/Platform-Info.md"), "the guide ships")

	addon.free()
	return ok


static func _check(ok: bool, condition: bool, label: String) -> bool:
	if not condition:
		print("  [FAIL] ", label)
	return ok and condition
