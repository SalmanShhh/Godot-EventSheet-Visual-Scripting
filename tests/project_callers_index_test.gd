# "Who else calls this?" - one project index, three readers.
#
# A function's head band says it, a rename has to say it before it changes anything, and both come
# off the SAME scan the shared-resource facts come off: one pass over the project, dropped whole when
# the filesystem changes. A second scan for a second question is how two answers about one project
# come to disagree.
#
# The answer is BY NAME and every reader's wording says so. Reading the types instead would need the
# whole project's inference to be right; being plainly approximate costs a glance, being quietly
# wrong about who calls a function costs somebody a broken game.
@tool
class_name ProjectCallersIndexTest
extends RefCounted

## Two beginner-shaped scripts of the corpus: `progress.gd` declares `grant_xp` and calls it from its
## own `complete_quest`, and nothing else in the project calls it. `collect` is called from
## `pickup.gd` and from a shipped pack, which is what makes the "and N more" wording testable.
const PROGRESS: String = "res://tests/fixtures/interop_corpus/progress.gd"
const PICKUP: String = "res://tests/fixtures/interop_corpus/pickup.gd"

## Rebuilding the whole index after the filesystem ping drops it. The scan is dropped WHOLE every
## time anything in the project is saved, so this is the number that decides whether the caller
## answers are affordable at all: what one file changing costs is a re-read of that file, never of
## the other thousand. Measured 70.4, 69.3 and 71.1 ms over 1,119 scripts and 59 scenes, against
## 970 ms when every script was read again. The budget is a claim that the rebuild is CHEAP rather
## than that it is fast - a per-file identity that stops working lands straight back at a second.
const INDEX_REBUILD_BUDGET_MS: int = 200


static func run() -> bool:
	var ok: bool = true
	# Headless has no frames to slice the scan across, so it is built outright - the same answer,
	# without the timing (see EventSheetProjectShareIndex).
	EventSheetProjectShareIndex.clear_cache()
	EventSheetProjectShareIndex.build_now()

	# ── The index itself ────────────────────────────────────────────────────────────────────
	ok = _check("a function called from one file is filed under it",
		EventSheets.scripts_calling("grant_xp"), PackedStringArray([PROGRESS])) and ok
	ok = _check("and the asker's own file is left out of its own answer",
		EventSheets.scripts_calling("grant_xp", PROGRESS), PackedStringArray()) and ok
	ok = _check("a name nothing calls has no callers",
		EventSheets.scripts_calling("no_function_is_called_this"), PackedStringArray()) and ok
	ok = _check("and neither has a nameless question", EventSheets.scripts_calling(""),
		PackedStringArray()) and ok
	# A DECLARATION is not a call. `progress.gd` declares `complete_quest` and never calls it, so it
	# is not among its callers; `pickup.gd` declares `collect` AND calls it from a lambda, so it is.
	ok = _check("declaring a function does not count as calling it",
		EventSheets.scripts_calling("complete_quest").has(PROGRESS), false) and ok
	ok = _check("but calling one in the same file does",
		EventSheets.scripts_calling("collect").has(PICKUP), true) and ok
	ok = _check("and a signal declaration is not a call either",
		EventSheets.scripts_calling("health_changed").has(
			"res://tests/fixtures/interop_corpus/player.gd"), false) and ok

	# ── What the head band says ─────────────────────────────────────────────────────────────
	ok = _check("the band names the file that calls it",
		ViewportRowBuilder.called_by_words("grant_xp", ""), "called by progress.gd") and ok
	ok = _check("and says nothing at all when nobody does",
		ViewportRowBuilder.called_by_words("no_function_is_called_this", ""), "") and ok
	ok = _check("nor when the question has no name",
		ViewportRowBuilder.called_by_words("", ""), "") and ok
	# The band scale law: a few names, then a count. Never a hundred file names on one row.
	var many: String = ViewportRowBuilder.called_by_words("take_damage", "")
	ok = _check("a much-called function names three files and counts the rest",
		many.count("·") >= 3 and many.contains("more"), true) and ok

	# ── What a rename says about the code it will not touch ─────────────────────────────────
	var note: String = EventSheetRenameRefactor.hand_written_callers_note("grant_xp", "")
	ok = _check("the rename note names the caller it did not change",
		note.contains("progress.gd"), true) and ok
	ok = _check("and says the code was not changed", note.contains("not changed"), true) and ok
	ok = _check("a rename nothing else calls says nothing",
		EventSheetRenameRefactor.hand_written_callers_note("no_function_is_called_this", ""), "") and ok

	# ── One scan, dropped whole, and cheap to build again ───────────────────────────────────
	EventSheetProjectShareIndex.clear_cache()
	ok = _check("a dropped index answers nothing until it is built again",
		EventSheetProjectShareIndex.callers_of("grant_xp"), PackedStringArray()) and ok
	var started: int = Time.get_ticks_usec()
	EventSheetProjectShareIndex.build_now()
	var rebuild_ms: float = float(Time.get_ticks_usec() - started) / 1000.0
	ok = _check("and the rebuilt one answers as it did",
		EventSheetProjectShareIndex.callers_of("grant_xp"), PackedStringArray([PROGRESS])) and ok
	ok = _check("rebuilding after a save costs under %d ms (took %.1f ms)" % [
		INDEX_REBUILD_BUDGET_MS, rebuild_ms],
		rebuild_ms <= float(INDEX_REBUILD_BUDGET_MS), true) and ok
	# The scene half is what "who else holds this file" blocks on, and it must not have grown a wait
	# on the script half: a question about scenes never asked one about scripts.
	EventSheetProjectShareIndex.clear_cache()
	EventSheetProjectShareIndex.build_scenes_now()
	ok = _check("the scene half can be final on its own",
		EventSheetProjectShareIndex.scenes_ready(), true) and ok
	ok = _check("without the script half being read yet",
		EventSheetProjectShareIndex.is_ready(), false) and ok

	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] project_callers_index_test: %s" % label)
		return true
	print("[FAIL] project_callers_index_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
