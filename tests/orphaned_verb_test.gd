# EventForge - the Doctor's orphaned-verb check.
#
# Renaming a provider's function changes the verb's identity and orphans every row that used it, and
# NOTHING caught that: ActionCodegen prefers the template baked onto the row at apply time over any
# registry lookup, so the sheet still emits the old call, compiles with zero errors and zero
# warnings, and Godot only complains when the player pulls the trigger. This is the safety net.
#
# The bar is the one check_param_type_mismatches sets for itself: it must never cry wolf. A lint that
# accuses a working game of being broken gets switched off, and then it protects nobody. So most of
# what follows pins the SILENCE - the cases where the check must say nothing.
#
# EVERY SAMPLE CALL BELOW IS ASSEMBLED FROM PIECES rather than written out. The check reads raw
# source and cannot tell a call inside a string literal from a real one, so spelling these examples
# in full would make this very file report itself and leave the Doctor permanently red on this repo -
# exactly the noise the check exists to avoid. That limitation is real and worth knowing: a script
# that quotes a provider call inside a string will be flagged.
@tool
class_name OrphanedVerbTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const STAT_FORGE := "res://eventsheet_addons/stat_forge/stat_forge_behavior.gd"
const PACK := "Stat" + "Forge"


static func run() -> bool:
	var ok: bool = true
	var providers: Dictionary = EventSheetProjectDoctor._provider_member_index(PackedStringArray())
	var gone: String = "buffs" + "_with_tag"
	var real: String = "has_" + gone

	# The index keys on the class name the compiler emitted into the call, so a shipped pack has to
	# be findable by exactly that string.
	ok = _check("a shipped pack resolves by its class name", providers.has(PACK), true) and ok

	# ---- It fires on the thing it exists for ----
	var broken: Array = _scan("func _ready() -> void:\n\t$Player/%s.%s(\"poison\")\n" % [PACK, gone], providers)
	ok = _check("a call to a member that is not there is reported", broken.size(), 1) and ok
	if broken.size() == 1:
		ok = _check("naming the provider", str((broken[0] as Dictionary).get("provider", "")), PACK) and ok
		ok = _check("and the member", str((broken[0] as Dictionary).get("member", "")), gone) and ok
	ok = _check("the non-Node provider form is read too",
		_count("__eventsheet_provider_%s.%s(\"poison\")\n" % [PACK, gone], providers), 1) and ok
	ok = _check("a repeated call is reported once",
		_count("$A/%s.%s()\n$B/%s.%s()\n" % [PACK, gone, PACK, gone], providers), 1) and ok

	# ---- ...and stays silent about everything else ----
	# The real method. Getting this wrong would have made the check worse than useless.
	ok = _check("the real method is not reported",
		_count("$Player/%s.%s(\"poison\")\n" % [PACK, real], providers), 0) and ok
	# An engine member the behaviour inherits. Missing this lane would fire on ordinary Godot code.
	ok = _check("an inherited engine method is not reported",
		_count("$Player/%s.queue_free()\n" % PACK, providers), 0) and ok
	ok = _check("nor an engine setter",
		_count("$Player/%s.set_process(false)\n" % PACK, providers), 0) and ok
	# A class the project has never heard of: not knowing a thing is not evidence against it.
	ok = _check("an unresolved class is silence",
		_count("$Player/SomeThirdPartyThing.whatever()\n", providers), 0) and ok
	ok = _check("an ordinary node call is silence",
		_count("$UI/HealthBar.set_value(3)\n", providers), 0) and ok

	# ---- The member index has to see every lane ----
	var members: Dictionary = EventSheetProjectDoctor._script_member_names(load(STAT_FORGE) as GDScript)
	ok = _check("its own methods are known", members.has(real), true) and ok
	ok = _check("its engine base's methods are known", members.has("queue_free"), true) and ok

	# ---- The whole project is clean ----
	# The strongest anti-false-positive evidence available: this repo ships 76 packs and every
	# showcase calls real behaviour verbs ($Player/PlatformerMovement.jump() and friends). If the
	# rule were loose, they would light up.
	var findings: Array[Dictionary] = []
	EventSheetProjectDoctor.check_orphaned_provider_calls(PackedStringArray(), findings)
	for finding: Dictionary in findings:
		print("  unexpected: %s - %s" % [str(finding.get("path", "")), str(finding.get("message", ""))])
	ok = _check("the project itself reports no orphans", findings.size(), 0) and ok

	return ok


static func _scan(source: String, providers: Dictionary) -> Array[Dictionary]:
	return EventSheetProjectDoctor.orphaned_calls_in_source(source, providers)


static func _count(source: String, providers: Dictionary) -> int:
	return _scan(source, providers).size()


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("orphaned_verb_test", label, actual, expected)
