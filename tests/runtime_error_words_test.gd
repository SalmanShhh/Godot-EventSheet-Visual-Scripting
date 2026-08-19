# Godot EventSheets - a runtime error, re-said in the sheet's words.
# The engine reports a crash in the vocabulary of the file it crashed in; the sheet knows which row
# that line came from and what the row was trying to do, so the same failure is said again as the
# row said it. Pins: the translation table by cause, the sentence's shape and every part of it
# going missing, the pass-through for a message nobody wrote a translation of, the Output lines
# keeping Godot's own words, and every Explain page resolving to a real Manual page.
@tool
class_name RuntimeErrorWordsTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# ── The table, one message per cause, in the engine's real phrasings ──
	var null_call: Dictionary = EventSheetRuntimeErrorWords.translate(
		"Invalid call. Nonexistent function 'hit' in base 'null instance'.")
	ok = _check("an empty target is recognised", str(null_call.get("key", "")),
		"null_instance") and ok
	ok = _check("an empty target is said in the sheet's words", str(null_call.get("said", "")),
		"target is empty") and ok
	ok = _check("and the reason is what the author did", str(null_call.get("why", "")),
		"nothing was picked before this action") and ok

	ok = _check("a list overrun is recognised", str(EventSheetRuntimeErrorWords.translate(
		"Out of bounds get index '7' (on base: 'Array')").get("key", "")), "out_of_bounds") and ok
	ok = _check("a list overrun is said as a position", str(EventSheetRuntimeErrorWords.translate(
		"Invalid get index '7' (on base: 'Array'). Index out of bounds.").get("said", "")),
		"there is no item at that position") and ok
	ok = _check("a missing action is recognised", str(EventSheetRuntimeErrorWords.translate(
		"Invalid call. Nonexistent function 'jump' in base 'Node2D (enemy.gd)'.").get("key", "")),
		"nonexistent_function") and ok
	ok = _check("a divide by zero is recognised", str(EventSheetRuntimeErrorWords.translate(
		"Division by zero in operator '/'.").get("key", "")), "division_by_zero") and ok
	ok = _check("a missing name is recognised", str(EventSheetRuntimeErrorWords.translate(
		"Invalid access to property or key 'speed' on a base object of type 'Node'.")
		.get("key", "")), "invalid_index") and ok

	# ── Nothing is invented: an unknown message is repeated, and says so ──
	var unknown: Dictionary = EventSheetRuntimeErrorWords.translate("Something new went wrong.")
	ok = _check("an unknown message is not translated", bool(unknown.get("translated", true)),
		false) and ok
	ok = _check("an unknown message is repeated verbatim", str(unknown.get("said", "")),
		"Something new went wrong.") and ok
	ok = _check("an unknown message offers no Explain",
		EventSheetRuntimeErrorWords.can_explain(unknown), false) and ok
	ok = _check("a known message does offer Explain",
		EventSheetRuntimeErrorWords.can_explain(null_call), true) and ok

	# ── The sentence: the whole address, then the failure ──
	var full: Dictionary = EventSheetRuntimeErrorWords.report(
		"Invalid call. Nonexistent function 'hit' in base 'null instance'.",
		"res://game/player.gd", 12, "Enemy ▸ Call Hit")
	ok = _check("the sentence reads as the row said it", str(full.get("sentence", "")),
		"player.gd · event 12 · Enemy ▸ Call Hit: target is empty (nothing was picked before this action)") and ok

	# Each part of the address can be missing, and the sentence still says the one thing it knows.
	ok = _check("with no row reading the address stops at the event",
		str(EventSheetRuntimeErrorWords.report("Division by zero in operator '/'.",
			"res://game/player.gd", 4, "").get("sentence", "")),
		"player.gd · event 4: divided by zero (the value this row divided by was 0 at that moment)") and ok
	ok = _check("with no row at all the failure is still said",
		str(EventSheetRuntimeErrorWords.report("Division by zero in operator '/'.", "", 0, "")
			.get("sentence", "")),
		"divided by zero (the value this row divided by was 0 at that moment)") and ok

	# ── Godot's own words are never hidden ──
	var lines: PackedStringArray = EventSheetRuntimeErrorWords.output_lines(full)
	ok = _check("the Output line leads with the sheet", lines[0],
		"Event sheet: player.gd · event 12 · Enemy ▸ Call Hit: target is empty (nothing was picked before this action)") and ok
	ok = _check("Godot's own message rides under it", lines[1] if lines.size() > 1 else "",
		"  Godot's words: Invalid call. Nonexistent function 'hit' in base 'null instance'.") and ok
	ok = _check("an untranslated message is not repeated twice",
		EventSheetRuntimeErrorWords.output_lines(EventSheetRuntimeErrorWords.report(
			"Something new went wrong.", "", 0, "")).size(), 1) and ok

	# ── Every cause is complete, uniquely keyed, and its Explain page really exists ──
	var seen: Dictionary = {}
	var duplicates: int = 0
	var missing_pages: PackedStringArray = PackedStringArray()
	var incomplete: PackedStringArray = PackedStringArray()
	for cause: Dictionary in EventSheetRuntimeErrorWords.CAUSES:
		var key: String = str(cause.get("key", ""))
		if seen.has(key):
			duplicates += 1
		seen[key] = true
		if str(cause.get("said", "")).is_empty() or str(cause.get("why", "")).is_empty() \
				or (cause.get("needles", []) as Array).is_empty():
			incomplete.append(key)
		var page: String = str(cause.get("explain", ""))
		if page.begins_with("reference:"):
			if not EventSheetDocReference.has_page(page):
				missing_pages.append(page)
		elif page.begins_with("guide:"):
			if not EventSheetDocLibrary.has_page(page.substr("guide:".length())):
				missing_pages.append(page)
		else:
			missing_pages.append(page)
	ok = _check("no two causes share a key", duplicates, 0) and ok
	ok = _check("every cause is complete", ",".join(incomplete), "") and ok
	ok = _check("every Explain page exists", ",".join(missing_pages), "") and ok

	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("  [FAIL] runtime_error_words_test: %s (got %s, expected %s)" % [label, str(actual), str(expected)])
	return false
