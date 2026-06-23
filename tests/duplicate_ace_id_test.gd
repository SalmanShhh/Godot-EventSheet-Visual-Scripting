# EventForge — built-in ACE ids must be unique per provider.
#
# The registry indexes descriptors by "provider::ace_id" (ace_registry.gd:_ensure_builtin_cache) and a
# duplicate silently shadows the earlier one — and doubles up in the picker. This guards the real
# built-in set against a newly-added ACE colliding with an existing id (a live risk now that the
# behaviour-vocabulary work adds many Core ids), and checks the detector itself with a synthetic pair.
@tool
extends RefCounted
class_name DuplicateAceIdTest

static func run() -> bool:
	var ok: bool = true

	# 1. The shipped built-in set must have zero duplicate provider::ace_id.
	var dupes: PackedStringArray = ACERegistry.find_duplicate_ids()
	ok = _check("built-in ACE ids are unique", dupes.is_empty(), true) and ok
	if not dupes.is_empty():
		print("  duplicates: %s" % ", ".join(dupes))

	# 2. Positive control: two descriptors sharing provider::ace_id are detected; a distinct one is not.
	var a: ACEDescriptor = ACEDescriptor.new()
	a.provider_id = "Core"
	a.ace_id = "DupSample"
	var b: ACEDescriptor = ACEDescriptor.new()
	b.provider_id = "Core"
	b.ace_id = "DupSample"
	var c: ACEDescriptor = ACEDescriptor.new()
	c.provider_id = "Core"
	c.ace_id = "OtherSample"
	var detected: PackedStringArray = ACERegistry.find_duplicate_ids([a, b, c])
	ok = _check("a duplicate id is detected", detected.has("Core::DupSample"), true) and ok
	ok = _check("a distinct id is not flagged", detected.has("Core::OtherSample"), false) and ok

	return ok

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] duplicate_ace_id_test: %s" % label)
		return true
	print("[FAIL] duplicate_ace_id_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
