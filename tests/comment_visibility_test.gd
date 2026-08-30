# Godot EventSheets - the two comment spellings, and the leak fixture that proves the private one
# never gets out.
#
# WHAT THIS PINS, and why each of these was worth a test:
#  - a comment row is documentation ONLY when the marker it writes opens `##`, so there is no second
#    field two readers could disagree about,
#  - ticking and unticking the box writes exactly `## ` and the ordinary form, and leaves a row that
#    was ALREADY on the wanted side completely untouched, which is what keeps an imported `##` (no
#    trailing space) re-emitting byte for byte,
#  - THE LEAK FIXTURE: a sheet whose private notes say something unmistakable composes a manual page,
#    a search index and a coverage count that contain none of those words - checked by searching the
#    whole page text for the marker word rather than by trusting a walk to have skipped them,
#  - a `#` line is never documentation debt: adding one moves no coverage number at all,
#  - TODO and FIXME notes surface once each as task chips, in a stable order, and nowhere else,
#  - the drift check reaches groups and prose paragraphs by the same rule it judges functions with,
#  - the offer budget spends once per thing and can be forgotten, so nothing nags.
@tool
class_name CommentVisibilityTest
extends RefCounted

## A word no ACE, no descriptor and no fixture name contains, written into every private note the
## leak fixture carries. Searching a composed page for it is a stronger check than asserting a walk
## skipped something: if any reader ever starts including private notes, this word appears.
const LEAK_WORD := "zzprivateleak"


static func run() -> bool:
	var all_passed: bool = true
	# The offer budget is process state and the suite runs serially in one process: a booking left
	# behind here would decide another test's answer.
	EventSheetDescriptionDrafts.clear_offers()

	# ── Two spellings, one row kind ─────────────────────────────────────────────────────────
	var private_note: CommentRow = _comment("Bookkeeping for the jump buffer.", "")
	var doc_note: CommentRow = _comment("Prints landed once the player reaches the ground.", "## ")
	all_passed = _check("a plain comment is not documentation", private_note.is_documentation(), false) and all_passed
	all_passed = _check("a `##` comment is documentation", doc_note.is_documentation(), true) and all_passed
	all_passed = _check("the plain form emits the ordinary marker", private_note.emit_marker(), "# ") and all_passed
	all_passed = _check("the doc form emits its own marker", doc_note.emit_marker(), "## ") and all_passed

	# ── The checkbox writes bytes, and only when the side changes ───────────────────────────
	var promoted: CommentRow = _comment("Caught by the coyote timer.", "")
	promoted.set_documentation(true)
	all_passed = _check("ticking the box writes the doc marker", promoted.source_marker, "## ") and all_passed
	promoted.set_documentation(false)
	all_passed = _check("unticking it restores the ordinary form every existing sheet already stores",
		promoted.source_marker, "") and all_passed
	# BYTE-EXACTNESS: an imported `##` with no trailing space is already documentation, so ticking the
	# box must not respell it - the file would change for a setting that did not.
	var imported: CommentRow = _comment("Lifted from a file.", "##")
	imported.set_documentation(true)
	all_passed = _check("a row already on the wanted side keeps its exact marker",
		imported.source_marker, "##") and all_passed
	all_passed = _check("and its echo is the line it really writes",
		imported.echo_line(0), "##Lifted from a file.") and all_passed
	all_passed = _check("an ordinary note's echo carries the single hash",
		private_note.echo_line(0), "# Bookkeeping for the jump buffer.") and all_passed

	# ── THE LEAK FIXTURE ────────────────────────────────────────────────────────────────────
	var sheet: EventSheetResource = _leaky_sheet()
	var page: String = EventSheetProjectManual.page_for(sheet)
	all_passed = _check("no private note reaches the manual page", page.contains(LEAK_WORD), false) and all_passed
	all_passed = _check("the documentation paragraphs DO reach it",
		page.contains("Prints landed once the player reaches the ground."), true) and all_passed
	var searched: Array[Dictionary] = EventSheetProjectViewModel.find({"res://a.gd": sheet}, LEAK_WORD)
	all_passed = _check("no private note is reachable from the project-wide find", searched.size(), 0) and all_passed
	var prose_hits: Array[Dictionary] = EventSheetProjectViewModel.find({"res://a.gd": sheet}, "reaches the ground")
	all_passed = _check("a documentation paragraph IS reachable from it", prose_hits.size(), 1) and all_passed
	all_passed = _check("and the hit says which chapter it was written in",
		str(prose_hits[0].get("where", "")), "Falling") and all_passed

	# ── A `#` line is never debt ────────────────────────────────────────────────────────────
	var before: Dictionary = EventSheetDescriptions.coverage(sheet)
	sheet.events.append(_comment("%s and another one" % LEAK_WORD, ""))
	var after: Dictionary = EventSheetDescriptions.coverage(sheet)
	all_passed = _check("a private note moves no described count",
		"%d/%d/%d" % [int(after.get("described", 0)), int(after.get("total", 0)), int(after.get("paragraphs", 0))],
		"%d/%d/%d" % [int(before.get("described", 0)), int(before.get("total", 0)), int(before.get("paragraphs", 0))]) and all_passed
	all_passed = _check("coverage counts the documentation paragraphs and only those",
		int(after.get("paragraphs", 0)), 2) and all_passed

	# ── Task chips: the one reading a private note has ──────────────────────────────────────
	var chips: Array[Dictionary] = EventSheetProjectViewModel.tasks({"res://b.gd": sheet, "res://a.gd": sheet})
	var chip_words: PackedStringArray = PackedStringArray()
	for chip: Dictionary in chips:
		chip_words.append("%s %s/%s" % [str(chip.get("word", "")), str(chip.get("path", "")).get_file(),
			str(chip.get("where", ""))])
	all_passed = _check("TODO and FIXME notes surface once each, sorted by path then by sheet order",
		", ".join(chip_words),
		"TODO a.gd/sheet, FIXME a.gd/Falling, TODO b.gd/sheet, FIXME b.gd/Falling") and all_passed
	all_passed = _check("and an ordinary note is not a task", chips.size(), 4) and all_passed

	# ── Drift, by one rule, over three shapes ───────────────────────────────────────────────
	var landed: EventGroup = _group_named(sheet, "Falling")
	all_passed = _check("a group description that still names what its rows do has not drifted",
		EventSheetDescriptionDrafts.group_description_drifted(landed), false) and all_passed
	landed.description = "Handles the shop inventory."
	all_passed = _check("one that names nothing its rows do has",
		EventSheetDescriptionDrafts.group_description_drifted(landed), true) and all_passed
	var drifted: Array[Dictionary] = EventSheetDescriptionDrafts.drifted_paragraphs(sheet)
	all_passed = _check("a paragraph that introduces rows it no longer describes is reported once",
		drifted.size(), 1) and all_passed
	all_passed = _check("and it is reported by its own words",
		str(drifted[0].get("text", "")), "Everything here is about the shop till.") and all_passed

	# ── The offer budget spends once ────────────────────────────────────────────────────────
	all_passed = _check("an undescribed thing with a draft is offered once",
		EventSheetDescriptionDrafts.may_offer("group", "Falling", false, "Draft words"), true) and all_passed
	all_passed = _check("and not a second time in the same session",
		EventSheetDescriptionDrafts.may_offer("group", "Falling", false, "Draft words"), false) and all_passed
	all_passed = _check("a thing that already has words is never offered anything",
		EventSheetDescriptionDrafts.may_offer("group", "Landing", true, "Draft words"), false) and all_passed
	all_passed = _check("and neither is a thing whose rows compose nothing",
		EventSheetDescriptionDrafts.may_offer("group", "Empty", false, "  "), false) and all_passed

	EventSheetDescriptionDrafts.clear_offers()
	return all_passed


## THE LEAK FIXTURE: a sheet whose private notes all carry an unmistakable word, alongside two
## documentation paragraphs and two rows that give the drift check something to judge. Built in
## memory so nothing on disk decides what these values are.
static func _leaky_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = "Faller"
	sheet.class_description = "How the player leaves the ground and comes back."

	var group: EventGroup = EventGroup.new()
	group.name = "Falling"
	group.description = "Prints landed when the player lands."
	var landed_row: EventRow = EventRow.new()
	landed_row.actions = [_print_action("landed")]
	group.events = [
		_comment("Prints landed once the player reaches the ground.", "## "),
		landed_row,
		_comment("%s throwaway arithmetic nobody should read" % LEAK_WORD, ""),
		_comment("FIXME %s tidy this up" % LEAK_WORD, ""),
	]

	# A paragraph introducing rows that stopped being about it - the prose drift case.
	var till_row: EventRow = EventRow.new()
	till_row.actions = [_print_action("landed")]
	sheet.events = [
		_comment("TODO %s write the rest" % LEAK_WORD, ""),
		group,
		_comment("Everything here is about the shop till.", "## "),
		till_row,
	]
	return sheet


static func _comment(text: String, marker: String) -> CommentRow:
	var comment_row: CommentRow = CommentRow.new()
	comment_row.text = text
	comment_row.source_marker = marker
	return comment_row


static func _print_action(message: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "PrintLog"
	action.params = {"message": "\"%s\"" % message}
	return action


static func _group_named(sheet: EventSheetResource, name: String) -> EventGroup:
	for entry: Variant in sheet.events:
		if entry is EventGroup and (entry as EventGroup).name == name:
			return entry as EventGroup
	return null


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] comment_visibility_test: %s" % label)
		return true
	print("[FAIL] comment_visibility_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
