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
	all_passed = _check("a script-backed source gets a path+mtime+length cache key",
		key_a.begins_with("res://eventsheet_addons/demo_health_addon.gd|") and key_a.split("|").size() == 3, true) and all_passed
	# A stale key for the same script (an older mtime) is pruned when the fresh one lands, so a
	# long session never accumulates dead reflections. Clear this path's entries first: the
	# cache is static and earlier suite tests may have already warmed the real key (a warm HIT
	# skips the prune-and-store path on purpose).
	for warm_key: Variant in EventSheetACERegistry._source_definition_cache.keys():
		if str(warm_key).begins_with("res://eventsheet_addons/demo_health_addon.gd|"):
			EventSheetACERegistry._source_definition_cache.erase(warm_key)
	EventSheetACERegistry._source_definition_cache["res://eventsheet_addons/demo_health_addon.gd|1|1"] = []
	all_passed = _check("two instances of the same saved script share one key",
		EventSheetACERegistry._source_cache_key(source_b), key_a) and all_passed
	var registry_c: EventSheetACERegistry = EventSheetACERegistry.new()
	registry_c.refresh_from_sources([source_a], false)
	var registry_d: EventSheetACERegistry = EventSheetACERegistry.new()
	registry_d.refresh_from_sources([source_b], false)
	all_passed = _check("provider definitions are reused across refreshes",
		registry_c.get_all_definitions()[0] == registry_d.get_all_definitions()[0], true) and all_passed
	var live_keys: int = 0
	for cache_key: Variant in EventSheetACERegistry._source_definition_cache.keys():
		if str(cache_key).begins_with("res://eventsheet_addons/demo_health_addon.gd|"):
			live_keys += 1
	all_passed = _check("stale keys for the same script are pruned (one live entry)", live_keys, 1) and all_passed

	# An unsaved (pathless) source is uncacheable and still reflects fresh - the old behavior.
	var pathless: GDScript = GDScript.new()
	pathless.source_code = "@tool\nextends RefCounted\n"
	pathless.reload()
	all_passed = _check("a pathless source is uncacheable",
		EventSheetACERegistry._source_cache_key(pathless.new()), "") and all_passed

	# The same provider reachable through TWO registration channels in one build (scanned
	# addon + registered autoload, or a sheet re-registering a scanned script) must not
	# double-list in the picker: the flat list dedups by provider+id, newest wins.
	var registry_e: EventSheetACERegistry = EventSheetACERegistry.new()
	var source_c: Object = provider_script.new()
	var source_d: Object = provider_script.new()
	registry_e.refresh_from_sources([source_c, source_d], false)
	var seen_keys: Dictionary = {}
	var duplicate_keys: int = 0
	for definition: ACEDefinition in registry_e.get_all_definitions():
		var flat_key: String = "%s::%s" % [definition.provider_id, definition.id]
		if seen_keys.has(flat_key):
			duplicate_keys += 1
		seen_keys[flat_key] = true
	all_passed = _check("a twice-registered provider lists each ACE once", duplicate_keys, 0) and all_passed
	if source_c is Node:
		(source_c as Node).free()
	if source_d is Node:
		(source_d as Node).free()

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
