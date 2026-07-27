# EventForge - the ACE wizard's curation table (Phase 2's UI half).
#
# The preview table is now the editing surface: Publish / Kind / Verb / Category are editable in
# place, and "Curate Script" writes the DIFFERENCES back as `## @ace_*` comments. Only differences,
# because annotating every member with whatever reflection already inferred would bury the author's
# real decisions in a wall of comments that says nothing.
#
# The untyped fixture is the case that justifies the whole feature: `func is_wave_active():` with no
# return type can only reflect as an Action, and the fix has to be an annotation rather than an edit
# to the user's signature.
@tool
class_name ProviderCurateTest
extends RefCounted

const UNTYPED := "res://tests/fixtures/untyped_provider_fixture.gd"


static func run() -> bool:
	var ok: bool = true

	var dock: EventSheetDock = EventSheetDock.new()
	dock._build_provider_dialog()
	dock._preview_provider_script(UNTYPED, true)

	var glue: EventSheetProviderRegistryGlue = dock._providers_glue
	# Worth pinning literally: ONE numeric `@export` publishes four rows (read, set, add, subtract),
	# and all four share a single `var` - so all four share one annotation block. That is why the
	# writer merges edits by declaration instead of rewriting the block once per row.
	ok = _check("the preview filled the table", _members(dock), [
		"signal:wave_started", "property:difficulty", "set:difficulty", "add:difficulty",
		"subtract:difficulty", "method:start_wave", "method:is_wave_active"]) and ok
	# Untouched, the table describes the file exactly, so there is nothing to write.
	ok = _check("an unedited table produces no edits", glue.collect_curation_edits(), []) and ok
	ok = _check("and the Curate button is offered", dock._provider_curate_button.visible, true) and ok

	# ── The headline case: move an untyped method into the Conditions lane ──
	var is_active: TreeItem = _row_for(dock, "is_wave_active")
	ok = _check("the untyped method reflected as an Action", is_active.get_text(1).split(",")[int(is_active.get_range(1))], "Action") and ok
	is_active.set_range(1, float(EventSheetProviderRegistryGlue.KIND_CHOICES.find("Condition")))
	is_active.set_text(2, "Wave Active")

	# ── Opting a member out entirely ──
	_row_for(dock, "difficulty").set_checked(0, false)

	var edits: Array = glue.collect_curation_edits()
	ok = _check("only the edited members are written", edits.size(), 2) and ok
	var by_member: Dictionary = {}
	for edit: Variant in edits:
		by_member[str((edit as Dictionary).get("member", ""))] = edit
	ok = _check("the kind change is captured",
		(by_member.get("is_wave_active", {}) as Dictionary).get("kind", ""), "condition") and ok
	ok = _check("along with the new label",
		(by_member.get("is_wave_active", {}) as Dictionary).get("name", ""), "Wave Active") and ok
	ok = _check("and the opt-out",
		(by_member.get("difficulty", {}) as Dictionary).get("hidden", false), true) and ok
	# The member kind decides the anchor the writer searches for, so a property edit must not go
	# looking for a `func`.
	ok = _check("a property edit carries its own source kind",
		(by_member.get("difficulty", {}) as Dictionary).get("source_kind", ""), "property") and ok

	# ── The diff the user confirms before anything is written ──
	var diff: String = glue.curation_diff_text(edits)
	ok = _check("the diff names the member", diff.contains("method is_wave_active"), true) and ok
	ok = _check("and shows the exact lines", diff.contains("+ ## @ace_condition"), true) and ok
	ok = _check("with the opt-out spelled out", diff.contains("+ ## @ace_hidden"), true) and ok
	# Nothing may reach disk before the confirm: the fixture is a checked-in file.
	ok = _check("the fixture on disk is untouched",
		FileAccess.get_file_as_string(UNTYPED).contains("@ace_"), false) and ok

	# ── Phase 3: shaping a PARAMETER, not just the verb ──
	# A param spec has no cell in the table (a hint is not a column), so it is recorded alongside and
	# folded in at collection time. A member whose ONLY change is a param spec must still be written -
	# that is the entire point of the editor.
	glue.set_param_spec("start_wave", "index", {"hint": "comparison", "default": "0"})
	var with_params: Array = glue.collect_curation_edits()
	var start_wave_edit: Dictionary = {}
	for edit: Variant in with_params:
		if str((edit as Dictionary).get("member", "")) == "start_wave":
			start_wave_edit = edit
	ok = _check("a param-only change still produces an edit", start_wave_edit.is_empty(), false) and ok
	ok = _check("carrying the param spec",
		(start_wave_edit.get("params", {}) as Dictionary).get("index", {}),
		{"hint": "comparison", "default": "0"}) and ok
	# And it reaches the annotation the writer emits, which is what the analyzer reads back.
	ok = _check("which becomes an @ace_param line",
		glue.curation_diff_text([start_wave_edit]).contains("+ ## @ace_param(index, hint: comparison, default: 0)"),
		true) and ok
	# Clearing a spec removes it rather than writing an empty annotation.
	glue.set_param_spec("start_wave", "index", {})
	ok = _check("clearing a spec drops it", glue.param_specs_for("start_wave"), {}) and ok
	# Specs are per-script: carrying them across would annotate a member that merely shares a name.
	glue.set_param_spec("start_wave", "index", {"hint": "comparison"})
	dock._preview_provider_script("res://tests/fixtures/typed_provider_fixture.gd", false)
	ok = _check("switching provider clears pending specs", glue.param_specs_for("start_wave"), {}) and ok

	dock.free()
	return ok


## Every row's ace_id, in table order - more useful than a count when it disagrees.
static func _members(dock: EventSheetDock) -> Array:
	var output: Array = []
	var item: TreeItem = dock._provider_preview_tree.get_root().get_first_child()
	while item != null:
		output.append(str((item.get_metadata(0) as Dictionary).get("ace_id", "")))
		item = item.get_next()
	return output


static func _row_for(dock: EventSheetDock, member: String) -> TreeItem:
	var item: TreeItem = dock._provider_preview_tree.get_root().get_first_child()
	while item != null:
		var row: Dictionary = item.get_metadata(0) as Dictionary
		if row != null and str(row.get("member", "")) == member:
			return item
		item = item.get_next()
	return null


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] provider_curate_test: %s" % label)
		return true
	print("[FAIL] provider_curate_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
