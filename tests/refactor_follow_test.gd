# EventSheet - refactor-following. When a renamed member orphans a row, the
# Doctor should name the member you almost certainly renamed it to. The MUST-NOT-FIRE cases
# are as prominent as the fire cases here, on purpose: a confident wrong suggestion sends
# someone to "fix" a call that was never the problem, and one such miss teaches users to
# ignore the whole panel.
@tool
class_name RefactorFollowTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# ── Fires: an obvious rename ──
	ok = _check("a close rename is named",
		EventSheetRefactorFollow.closest_member("start_wave",
			PackedStringArray(["begin_wave", "stop", "reset"])), "begin_wave") and ok
	ok = _check("a prefix change is named",
		EventSheetRefactorFollow.closest_member("do_fire",
			PackedStringArray(["fire", "reload", "aim"])), "fire") and ok

	# ── Must NOT fire ──
	ok = _check("nothing similar suggests nothing",
		EventSheetRefactorFollow.closest_member("fire",
			PackedStringArray(["quit", "zoom", "persist"])), "") and ok
	ok = _check("an empty candidate set suggests nothing",
		EventSheetRefactorFollow.closest_member("fire", PackedStringArray()), "") and ok
	ok = _check("an empty needle suggests nothing",
		EventSheetRefactorFollow.closest_member("", PackedStringArray(["fire"])), "") and ok
	# The member is actually PRESENT - the orphan is something else, so never blame a rename.
	ok = _check("a member that still exists is never called a rename",
		EventSheetRefactorFollow.closest_member("fire",
			PackedStringArray(["fire", "fired", "firer"])), "") and ok
	# Ambiguity: two members equally plausible means the tool does not know.
	ok = _check("two equally close candidates suggest nothing",
		EventSheetRefactorFollow.closest_member("set_value",
			PackedStringArray(["set_valve", "set_valid"])), "") and ok

	# ── The Doctor sentence ──
	var hint: String = EventSheetRefactorFollow.rename_hint("start_wave",
		PackedStringArray(["begin_wave", "stop"]))
	ok = _check("the hint names the suggestion", hint.contains("begin_wave()"), true) and ok
	ok = _check("the hint points at the stand-in flow", hint.contains("Keep Old Name"), true) and ok
	ok = _check("no suggestion means no hint (the message stays as it was)",
		EventSheetRefactorFollow.rename_hint("fire", PackedStringArray(["quit"])), "") and ok

	# ── The member-name reader tolerates the index shapes it is given ──
	ok = _check("reads members from the Doctor's index entry",
		EventSheetRefactorFollow.member_names({"members": {"fire": true, "reload": true}, "path": "x.gd"}).size(), 2) and ok
	ok = _check("reads a plain list", EventSheetRefactorFollow.member_names(["a", "b"]).size(), 2) and ok
	ok = _check("an unknown provider yields no candidates (and so no suggestion)",
		EventSheetRefactorFollow.member_names({}).size(), 0) and ok

	# ── End to end through the real Doctor check ──
	# A source calling a member the provider does not have, with a near-twin present.
	# The call is BUILT, never written literally: the Doctor scans project source (tests
	# included), and a literal `$Player/Pack.member(` in this file would look exactly like a
	# real orphaned call and make the repo permanently doctor-dirty. That limitation is
	# documented on the check itself, and the existing orphaned-verb test dodges it the same
	# way.
	const PACK: String = "WeaponKit"
	var providers: Dictionary = {PACK: {"members": {"begin_fire": true, "reload": true}, "path": "res://weapon_kit.gd"}}
	var orphans: Array = EventSheetProjectDoctor.orphaned_calls_in_source(
		"func _ready():\n\t$Player/%s.%s()\n" % [PACK, "start_fire"], providers)
	ok = _check("the Doctor still detects the orphan", orphans.size(), 1) and ok
	if orphans.size() == 1:
		var suggestion: String = EventSheetRefactorFollow.rename_hint(str(orphans[0]["member"]),
			EventSheetRefactorFollow.member_names(providers.get(str(orphans[0]["provider"]), {})))
		ok = _check("and the message would name the likely rename",
			suggestion.contains("begin_fire()"), true) and ok
	# A source calling a member that EXISTS must stay silent (the conservatism contract).
	ok = _check("a valid call is never reported",
		EventSheetProjectDoctor.orphaned_calls_in_source(
			"func _ready():\n\t$Player/%s.%s()\n" % [PACK, "reload"], providers).size(), 0) and ok
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("[FAIL] refactor_follow_test: %s - expected %s, got %s" % [label, str(expected), str(actual)])
	return false
