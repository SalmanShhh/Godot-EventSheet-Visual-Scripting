# EventSheet - baking catalog overrides into the source. The catalog keeps a
# user's script untouched by default; bake is the opt-out for teams who want the script to
# describe itself. Pins the id -> member translation, the edit shape handed to the writer,
# and the end-to-end write: annotations appear, the code is untouched, and the now-redundant
# overrides are dropped so source stays the single truth.
@tool
class_name VocabularyBakeTest
extends RefCounted

const SCRATCH_CATALOG: String = "user://scratch_bake_catalog.tres"
const SCRATCH_SCRIPT: String = "user://scratch_bake_provider.gd"

const SOURCE: String = """class_name ScratchBakeProvider
extends Node


func take_damage(amount: float) -> void:
	pass


func heal(amount: float) -> void:
	pass
"""


static func run() -> bool:
	var ok: bool = true
	EventSheetVocabularyCatalog.reset_for_tests(SCRATCH_CATALOG)

	# ── id -> member translation (every shape the reflection produces) ──
	ok = _check("a method id names its method",
		EventSheetVocabularyCatalog.member_from_ace_id("method:take_damage"),
		{"source_kind": "method", "member": "take_damage"}) and ok
	ok = _check("a signal id names its signal",
		EventSheetVocabularyCatalog.member_from_ace_id("signal:on_died"),
		{"source_kind": "signal", "member": "on_died"}) and ok
	ok = _check("a property setter id names the property",
		EventSheetVocabularyCatalog.member_from_ace_id("property:set:health"),
		{"source_kind": "property", "member": "health"}) and ok
	ok = _check("a property getter id names the same property",
		EventSheetVocabularyCatalog.member_from_ace_id("property:get:health"),
		{"source_kind": "property", "member": "health"}) and ok
	# An unrecognised shape must NOT be guessed at - writing an annotation onto the wrong
	# declaration would corrupt someone's script.
	ok = _check("an unknown id shape is not bakeable",
		EventSheetVocabularyCatalog.member_from_ace_id("weird:thing"), {}) and ok

	# ── Overrides translate to the writer's edit shape, scoped to one class ──
	EventSheetVocabularyCatalog.set_override("ScratchBakeProvider", "method:take_damage",
		{"display_name": "Wound", "category": "Combat"})
	EventSheetVocabularyCatalog.set_override("ScratchBakeProvider", "method:heal", {"hidden": true})
	EventSheetVocabularyCatalog.set_override("OtherClass", "method:zzz", {"display_name": "Nope"})
	var edits: Array = EventSheetVocabularyCatalog.bake_edits_for("ScratchBakeProvider")
	ok = _check("only this class's overrides are baked", edits.size(), 2) and ok
	var by_member: Dictionary = {}
	for edit: Dictionary in edits:
		by_member[str(edit.get("member"))] = edit
	ok = _check("a rename becomes a name edit", str((by_member["take_damage"] as Dictionary).get("name")), "Wound") and ok
	ok = _check("a category rides along", str((by_member["take_damage"] as Dictionary).get("category")), "Combat") and ok
	ok = _check("a hidden verb becomes a hidden edit", bool((by_member["heal"] as Dictionary).get("hidden")), true) and ok
	ok = _check("the declaration kind is carried", str((by_member["heal"] as Dictionary).get("source_kind")), "method") and ok

	# ── End to end: the annotations land, the CODE is untouched, overrides are dropped ──
	var file: FileAccess = FileAccess.open(SCRATCH_SCRIPT, FileAccess.WRITE)
	file.store_string(SOURCE)
	file.close()
	var result: Dictionary = EventSheets.bake_overrides(SCRATCH_SCRIPT, "ScratchBakeProvider")
	ok = _check("the bake reports success", bool(result.get("ok")), true) and ok
	ok = _check("both overrides were baked", int(result.get("baked", 0)), 2) and ok
	var baked: String = FileAccess.get_file_as_string(SCRATCH_SCRIPT)
	ok = _check("the rename is now in the script", baked.contains("## @ace_name(\"Wound\")"), true) and ok
	ok = _check("the category is now in the script", baked.contains("## @ace_category(\"Combat\")"), true) and ok
	ok = _check("the hidden verb is marked in the script", baked.contains("## @ace_hidden"), true) and ok
	# The covenant of every annotation write: comments only.
	for code_line: String in ["func take_damage(amount: float) -> void:", "func heal(amount: float) -> void:",
			"class_name ScratchBakeProvider", "extends Node"]:
		ok = _check("the code line survives verbatim: %s" % code_line, baked.contains(code_line), true) and ok
	ok = _check("no statement was added or altered",
		_code_lines(baked), _code_lines(SOURCE)) and ok
	# Source now owns these facts, so the catalog must not keep a silent duplicate.
	ok = _check("baked overrides leave the catalog",
		EventSheetVocabularyCatalog.bake_edits_for("ScratchBakeProvider").size(), 0) and ok
	ok = _check("another class's override is untouched",
		EventSheetVocabularyCatalog.bake_edits_for("OtherClass").size(), 1) and ok

	# Nothing to bake is a clean no-op, not an error.
	var empty: Dictionary = EventSheets.bake_overrides(SCRATCH_SCRIPT, "ScratchBakeProvider")
	ok = _check("baking with no overrides is a clean no-op", bool(empty.get("ok")), true) and ok
	ok = _check("and reports nothing baked", int(empty.get("baked", 0)), 0) and ok

	# ── REGRESSION: an override the writer could NOT anchor must survive ──
	# The member was renamed in the script (or the path is simply wrong), so the annotation
	# never reaches the file. Clearing it anyway would destroy the user's curation on a
	# SUCCESS path, with no backup taken - the worst failure this feature could have.
	var rewritten: FileAccess = FileAccess.open(SCRATCH_SCRIPT, FileAccess.WRITE)
	rewritten.store_string(SOURCE)
	rewritten.close()
	EventSheetVocabularyCatalog.set_override("ScratchBakeProvider", "method:take_damage", {"display_name": "Wound"})
	EventSheetVocabularyCatalog.set_override("ScratchBakeProvider", "method:gone_away", {"display_name": "Ghost"})
	var partial: Dictionary = EventSheets.bake_overrides(SCRATCH_SCRIPT, "ScratchBakeProvider")
	ok = _check("a partial bake still succeeds", bool(partial.get("ok")), true) and ok
	ok = _check("only the written edit is counted", int(partial.get("baked", 0)), 1) and ok
	var remaining: Array = EventSheetVocabularyCatalog.bake_edits_for("ScratchBakeProvider")
	ok = _check("the unwritable override is KEPT, not destroyed", remaining.size(), 1) and ok
	if remaining.size() == 1:
		ok = _check("and it is the one that never reached the file",
			str((remaining[0] as Dictionary).get("member")), "gone_away") and ok

	# The catastrophic case: a path holding NONE of the members. Everything skips, the source
	# is unchanged, the write short-circuits as "already up to date" - and every override for
	# the class must still be there afterwards.
	var stranger: String = "user://scratch_bake_stranger.gd"
	var other: FileAccess = FileAccess.open(stranger, FileAccess.WRITE)
	other.store_string("class_name ScratchBakeStranger\nextends Node\n")
	other.close()
	var before_count: int = EventSheetVocabularyCatalog.bake_edits_for("ScratchBakeProvider").size()
	var wrong: Dictionary = EventSheets.bake_overrides(stranger, "ScratchBakeProvider")
	ok = _check("baking against the wrong script writes nothing", int(wrong.get("baked", 0)), 0) and ok
	ok = _check("and destroys NO overrides",
		EventSheetVocabularyCatalog.bake_edits_for("ScratchBakeProvider").size(), before_count) and ok
	DirAccess.remove_absolute(stranger)

	# ── REGRESSION: a property's Set and Get overrides must not collapse into one write ──
	# A genuinely clean slate needs the FILE gone, not just the cache: the catalog validates
	# its cache against disk (that is what makes "delete the .tres" a real undo), so a bare
	# reset would faithfully reload every override this test made earlier.
	if ResourceLoader.exists(SCRATCH_CATALOG):
		DirAccess.remove_absolute(SCRATCH_CATALOG)
	EventSheetVocabularyCatalog.reset_for_tests(SCRATCH_CATALOG)
	EventSheetVocabularyCatalog.set_override("ScratchBakeProvider", "property:set:health", {"display_name": "Assign HP"})
	EventSheetVocabularyCatalog.set_override("ScratchBakeProvider", "property:get:health", {"display_name": "HP"})
	var property_edits: Array = EventSheetVocabularyCatalog.bake_edits_for("ScratchBakeProvider")
	ok = _check("a property bakes ONE edit, not two colliding ones", property_edits.size(), 1) and ok
	if property_edits.size() == 1:
		ok = _check("and it is the getter's name (the verb named after the property)",
			str((property_edits[0] as Dictionary).get("name")), "HP") and ok

	DirAccess.remove_absolute(SCRATCH_SCRIPT)
	if ResourceLoader.exists(SCRATCH_CATALOG):
		DirAccess.remove_absolute(SCRATCH_CATALOG)
	EventSheetVocabularyCatalog.reset_for_tests()
	return ok


## Every non-blank, non-`##` line: the CODE. Baking may only add comment lines, so this count
## must be identical before and after.
static func _code_lines(source: String) -> Array:
	var code: Array = []
	for line: String in source.split("\n"):
		var stripped: String = line.strip_edges()
		if not stripped.is_empty() and not stripped.begins_with("##"):
			code.append(stripped)
	return code


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("[FAIL] vocabulary_bake_test: %s - expected %s, got %s" % [label, str(expected), str(actual)])
	return false
