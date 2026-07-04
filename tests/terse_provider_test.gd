# Godot EventSheets - the terse provider dialect (v0.11 chapter 4, P1).
#
# Three authoring shortcuts, all additive to the frozen annotation vocabulary:
# - plain `##` prose above a member IS its description (@ace_description still wins),
# - class-level @ace_category / @ace_icon default every member (member overrides win),
# - unknown @ace_* tokens are collected and warned about instead of silently vanishing,
#   and annotation dispatch is exact-token so a typo can no longer prefix-match a real
#   annotation (`@ace_names` used to silently behave as @ace_name).
@tool
class_name TerseProviderTest
extends RefCounted

const SAMPLE := preload("res://tests/fixtures/terse_provider_sample.gd")


static func run() -> bool:
	var ok: bool = true
	var sample: Node = SAMPLE.new()
	var registry := EventSheetACERegistry.new()
	registry.refresh_from_sources([sample], true)
	var pid: String = "TerseProviderSample"

	# Prose-as-description: the doc comment is enough, no @ace_description needed.
	var fire: ACEDefinition = registry.find_definition(pid, "method:fire")
	ok = _check("prose doc becomes the description", fire.description if fire != null else "missing", "Fires the weapon once.") and ok
	var reloaded: ACEDefinition = registry.find_definition(pid, "signal:reloaded")
	ok = _check("signal prose becomes the trigger description", reloaded.description if reloaded != null else "missing", "Fires after a reload completes.") and ok

	# Explicit @ace_description still wins over prose.
	var reload: ACEDefinition = registry.find_definition(pid, "method:reload")
	ok = _check("@ace_description outranks prose", reload.description if reload != null else "missing", "Refill the magazine.") and ok

	# Class-level defaults reach members without their own category/icon...
	ok = _check("class-level category defaults the member", fire.category if fire != null else "missing", "Weapons") and ok
	ok = _check("class-level icon defaults the member", fire.icon if fire != null else "missing", "res://addons/eventsheet/icons/eventsheet.svg") and ok
	# ...and member-level annotations outrank the class default.
	var shells: ACEDefinition = registry.find_definition(pid, "method:shells_left")
	ok = _check("member category outranks the class default", shells.category if shells != null else "missing", "Ammo") and ok
	ok = _check("member icon outranks the class default", shells.icon if shells != null else "missing", "res://eventsheet_addons/behavior.svg") and ok

	# Exact-token dispatch: the @ace_names typo may NOT behave as @ace_name.
	var jam: ACEDefinition = registry.find_definition(pid, "method:jam")
	ok = _check("typo annotation does not rename the ACE", jam.display_name if jam != null else "missing", "Jam") and ok

	# Both typos are collected (deduped, exact tokens) for the author warning.
	var analyzer := EventSheetSemanticAnalyzer.new()
	var metadata: Dictionary = analyzer.parse_source_metadata(SAMPLE)
	var unknown: Array = metadata.get("unknown_annotations", [])
	unknown.sort()
	ok = _check("typo tokens are collected for the warning", str(unknown), str(["@ace_categry", "@ace_names"])) and ok

	# The known vocabulary (including compiled-sheet markers) never lands in the list.
	ok = _check("known tokens are not flagged", unknown.has("@ace_category") or unknown.has("@ace_family"), false) and ok

	sample.free()
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] terse_provider_test: %s" % label)
		return true
	print("[FAIL] terse_provider_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
