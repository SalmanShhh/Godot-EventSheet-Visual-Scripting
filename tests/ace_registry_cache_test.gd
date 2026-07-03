# EventForge - the ACE definition cache (startup / tab-switch speed).
#
# THE CONTRACT: reflecting provider scripts into definitions costs ~200 ms, so refreshes reuse
# cached definitions - safe because definitions are IMMUTABLE after generation (the apply path
# bakes templates into row COPIES, never back into a definition). Builtins cache per session;
# script-backed sources key on path + saved mtime, so saving a provider self-invalidates.
@tool
class_name ACERegistryCacheTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true
	var registry_a: EventSheetACERegistry = EventSheetACERegistry.new()
	registry_a.refresh_from_sources([], true)
	var registry_b: EventSheetACERegistry = EventSheetACERegistry.new()
	registry_b.refresh_from_sources([], true)
	all_passed = _check("both registries carry the builtin vocabulary",
		registry_a.get_all_definitions().size() > 100 and registry_a.get_all_definitions().size() == registry_b.get_all_definitions().size(), true) and all_passed
	all_passed = _check("builtin definitions are SHARED instances (cached, not rebuilt)",
		registry_a.get_all_definitions()[0] == registry_b.get_all_definitions()[0], true) and all_passed

	# Script-backed sources cache by path + mtime and yield shared definition instances too.
	var provider_script: GDScript = load("res://eventsheet_addons/demo_health_addon.gd")
	var source_a: Object = provider_script.new()
	var source_b: Object = provider_script.new()
	var key_a: String = EventSheetACERegistry._source_cache_key(source_a)
	all_passed = _check("a script-backed source gets a path+mtime cache key",
		key_a.begins_with("res://eventsheet_addons/demo_health_addon.gd|"), true) and all_passed
	all_passed = _check("two instances of the same saved script share one key",
		EventSheetACERegistry._source_cache_key(source_b), key_a) and all_passed
	var registry_c: EventSheetACERegistry = EventSheetACERegistry.new()
	registry_c.refresh_from_sources([source_a], false)
	var registry_d: EventSheetACERegistry = EventSheetACERegistry.new()
	registry_d.refresh_from_sources([source_b], false)
	all_passed = _check("provider definitions are reused across refreshes",
		registry_c.get_all_definitions()[0] == registry_d.get_all_definitions()[0], true) and all_passed

	# An unsaved (pathless) source is uncacheable and still reflects fresh - the old behavior.
	var pathless: GDScript = GDScript.new()
	pathless.source_code = "@tool\nextends RefCounted\n"
	pathless.reload()
	all_passed = _check("a pathless source is uncacheable",
		EventSheetACERegistry._source_cache_key(pathless.new()), "") and all_passed

	if source_a is Node:
		(source_a as Node).free()
	if source_b is Node:
		(source_b as Node).free()
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] ace_registry_cache_test: %s" % label)
		return true
	print("[FAIL] ace_registry_cache_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
