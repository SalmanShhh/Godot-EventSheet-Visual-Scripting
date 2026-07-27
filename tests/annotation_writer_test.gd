# EventForge - the ACE wizard's annotation writer (Phase 2's file-touching half).
#
# This is the only part of the wizard that edits a user's own script, so the bar is: nothing but
# `##` comment lines may move, applying twice must change nothing the second time, and a member
# that cannot be found must be reported rather than quietly skipped.
#
# The tests work on source TEXT rather than a loaded Script on purpose - the writer is pure, which
# is what makes the risky operation testable at all.
@tool
class_name AnnotationWriterTest
extends RefCounted

const SOURCE: String = """@tool
class_name WaveDirector
extends Node

signal wave_started(index: int)

## How hard the waves get.
@export var difficulty: float = 1.0


## Kicks off the next wave.
func start_wave(count: int) -> void:
	pass


func is_wave_active():
	return true
"""


static func run() -> bool:
	var ok: bool = true

	# ---- 1. A first curation pass ----
	var first: Dictionary = EventSheetACEAnnotationWriter.apply(SOURCE, [
		{"source_kind": "method", "member": "start_wave", "name": "Start Wave", "category": "Waves",
			"params": {"count": {"default": "3"}}},
		# The headline Phase 2 fix: an untyped `func is_wave_active():` reflects as an ACTION. The
		# kind is corrected by ANNOTATION, never by editing the signature - rewriting someone's code
		# to change how a picker groups it is not a trade worth offering.
		{"source_kind": "method", "member": "is_wave_active", "kind": "condition", "name": "Wave Active"},
		{"source_kind": "signal", "member": "wave_started", "name": "On Wave Started"},
		{"source_kind": "property", "member": "difficulty", "hidden": true},
	])
	ok = _check("the pass applies", first.get("ok", false), true) and ok
	ok = _check("all four members were found", first.get("changed", 0), 4) and ok
	ok = _check("nothing was skipped", (first.get("skipped", []) as Array).is_empty(), true) and ok
	var written: String = str(first.get("source", ""))

	ok = _check("a label lands above its function",
		written.contains("## @ace_name(\"Start Wave\")\n## @ace_category(\"Waves\")\n## @ace_param(count, default: 3)\nfunc start_wave"), true) and ok
	ok = _check("the kind is fixed by annotation, not by the signature",
		written.contains("## @ace_condition\n## @ace_name(\"Wave Active\")\nfunc is_wave_active():"), true) and ok
	ok = _check("the untyped signature is untouched", written.contains("func is_wave_active():"), true) and ok
	ok = _check("a signal annotates too", written.contains("## @ace_name(\"On Wave Started\")\nsignal wave_started"), true) and ok

	# The author's own prose stays, and stays ABOVE the annotations - the order a compiled pack uses.
	ok = _check("the human's doc comment survives",
		written.contains("## Kicks off the next wave.\n## @ace_name(\"Start Wave\")"), true) and ok
	# An @export decorator has to stay welded to its var, with the annotation above the whole thing.
	ok = _check("a decorator stays welded to its declaration",
		written.contains("## How hard the waves get.\n## @ace_hidden\n@export var difficulty: float = 1.0"), true) and ok
	# Opting out is the whole statement: a hidden member has no label to argue about.
	ok = _check("hidden wins outright", written.contains("@ace_name(\"Difficulty\")"), false) and ok

	# ---- 2. Idempotency ----
	# Re-applying must REPLACE, not accumulate. Appending would double the block on every visit to
	# the dialog, and the analyzer would then read whichever copy it hit first.
	var second: Dictionary = EventSheetACEAnnotationWriter.apply(written, [
		{"source_kind": "method", "member": "start_wave", "name": "Start Wave", "category": "Waves",
			"params": {"count": {"default": "3"}}},
		{"source_kind": "method", "member": "is_wave_active", "kind": "condition", "name": "Wave Active"},
		{"source_kind": "signal", "member": "wave_started", "name": "On Wave Started"},
		{"source_kind": "property", "member": "difficulty", "hidden": true},
	])
	ok = _check("re-applying the same edits changes nothing", str(second.get("source", "")), written) and ok

	# ---- 3. Editing an already-curated member ----
	var renamed: Dictionary = EventSheetACEAnnotationWriter.apply(written, [
		{"source_kind": "method", "member": "start_wave", "name": "Begin Wave", "category": "Waves",
			"params": {"count": {"default": "3"}}},
	])
	var renamed_source: String = str(renamed.get("source", ""))
	ok = _check("the new label is there", renamed_source.contains("## @ace_name(\"Begin Wave\")"), true) and ok
	ok = _check("and the old one is gone", renamed_source.contains("Start Wave"), false) and ok
	ok = _check("the rest of the file is undisturbed",
		renamed_source.contains("## @ace_condition\n## @ace_name(\"Wave Active\")"), true) and ok

	# ---- 4. A member that is not there ----
	# A rename between scanning and applying must not look like a success.
	var missing: Dictionary = EventSheetACEAnnotationWriter.apply(SOURCE, [
		{"source_kind": "method", "member": "no_such_function", "name": "Nope"},
	])
	ok = _check("a missing member is reported", missing.get("skipped", []), ["no_such_function"]) and ok
	ok = _check("and nothing was written", missing.get("changed", 0), 0) and ok
	ok = _check("leaving the source exactly as it was", str(missing.get("source", "")), SOURCE) and ok

	# ---- 5. Only comments move ----
	# The strongest guarantee, checked structurally: every line that is not a `##` comment appears in
	# the output in the same order, unchanged. Any body or signature edit breaks this.
	ok = _check("no non-comment line was altered", _code_lines(written), _code_lines(SOURCE)) and ok

	# ---- 6. Values that would break the comment ----
	var awkward: PackedStringArray = EventSheetACEAnnotationWriter.annotation_lines({
		"name": "Say \"hi\"", "description": "First line\nsecond line"})
	# The reader trims a surrounding quote pair and has no escape, so an inner quote would end the
	# value early and a newline would end the comment entirely.
	ok = _check("an inner quote is folded", awkward[0], "## @ace_name(\"Say 'hi'\")") and ok
	ok = _check("and a newline is flattened", awkward[1], "## @ace_description(\"First line second line\")") and ok

	# ---- 7. Untouched annotations the wizard does not own ----
	# Clearing everything would silently drop an @ace_icon or @ace_deprecated the author hand-wrote.
	var hand_written: String = "## @ace_icon(\"res://icon.svg\")\n## @ace_name(\"Old\")\nfunc ping() -> void:\n\tpass\n"
	var kept: String = str(EventSheetACEAnnotationWriter.apply(hand_written, [
		{"source_kind": "method", "member": "ping", "name": "Ping"}]).get("source", ""))
	ok = _check("an unmanaged annotation survives", kept.contains("## @ace_icon(\"res://icon.svg\")"), true) and ok
	ok = _check("while the managed one is replaced", kept.contains("## @ace_name(\"Ping\")"), true) and ok
	ok = _check("with no duplicate left behind", kept.contains("\"Old\""), false) and ok

	# ---- 8. The round trip: does the SCANNER agree? ----
	# Text that looks right is worth nothing if the analyzer reads it differently, so the written
	# source is compiled and run back through the same generator call the registry makes. This is
	# what proves the headline claim - that an untyped method really does land in the Conditions
	# lane once annotated, without its signature changing.
	# It has to be a real file: the analyzer reads annotations off DISK (a Script's resource_path),
	# so a GDScript built from a string in memory has no source for it to parse and every annotation
	# would silently do nothing here - passing the test for the wrong reason.
	var probe_path: String = "user://eventsheets_annotation_probe.gd"
	var probe_file: FileAccess = FileAccess.open(probe_path, FileAccess.WRITE)
	probe_file.store_string(written.replace("class_name WaveDirector\n", ""))
	probe_file.close()
	var runtime: GDScript = load(probe_path)
	ok = _check("the curated source still compiles", runtime != null and runtime.can_instantiate(), true) and ok
	var instance: Node = runtime.new()
	var definitions: Array[ACEDefinition] = EventSheetACEGenerator.new().generate_from_object(instance)
	var by_id: Dictionary = {}
	for definition: ACEDefinition in definitions:
		by_id[str(definition.id)] = definition
	ok = _check("the curated label is what the picker shows",
		_display(by_id, "method:start_wave"), "Start Wave") and ok
	ok = _check("and the category",
		str((by_id.get("method:start_wave", null) as ACEDefinition).category), "Waves") and ok
	ok = _check("the param default came through",
		_param_default(by_id, "method:start_wave", "count"), "3") and ok
	ok = _check("the untyped method now reads as a Condition",
		int((by_id.get("method:is_wave_active", null) as ACEDefinition).ace_type),
		ACEDefinition.ACEType.CONDITION) and ok
	# @ace_hidden is the opt-out, so the property must not have published anything at all.
	ok = _check("the hidden property published no reader", by_id.has("property:difficulty"), false) and ok
	ok = _check("and no writer", by_id.has("set:difficulty"), false) and ok
	instance.free()

	# ---- 9. The file-level API the wizard actually calls ----
	var curate_path: String = "user://eventsheets_curate_probe.gd"
	var seed_file: FileAccess = FileAccess.open(curate_path, FileAccess.WRITE)
	seed_file.store_string(SOURCE.replace("class_name WaveDirector\n", ""))
	seed_file.close()
	var curated: Dictionary = EventSheets.curate_provider(curate_path, [
		{"source_kind": "method", "member": "start_wave", "name": "Start Wave"}])
	ok = _check("curate_provider writes", curated.get("ok", false), true) and ok
	ok = _check("and backs the file up first",
		FileAccess.file_exists(str(curated.get("backup", ""))), true) and ok
	ok = _check("the file on disk carries the annotation",
		FileAccess.get_file_as_string(curate_path).contains("## @ace_name(\"Start Wave\")"), true) and ok
	# Re-running must not churn a second backup of an identical file.
	var again: Dictionary = EventSheets.curate_provider(curate_path, [
		{"source_kind": "method", "member": "start_wave", "name": "Start Wave"}])
	ok = _check("a second identical run is a no-op", again.get("reason", ""), "Already up to date.") and ok
	ok = _check("and takes no backup", str(again.get("backup", "")), "") and ok
	var absent: Dictionary = EventSheets.curate_provider("user://no_such_provider_xyz.gd", [])
	ok = _check("a missing file fails closed", absent.get("ok", false), false) and ok

	DirAccess.remove_absolute(ProjectSettings.globalize_path(probe_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(curate_path))

	return ok


static func _display(by_id: Dictionary, ace_id: String) -> String:
	var definition: ACEDefinition = by_id.get(ace_id, null)
	return "<missing>" if definition == null else str(definition.display_name)


static func _param_default(by_id: Dictionary, ace_id: String, param_id: String) -> String:
	var definition: ACEDefinition = by_id.get(ace_id, null)
	if definition == null:
		return "<missing>"
	for entry: Variant in definition.parameters:
		var parameter: Dictionary = entry as Dictionary
		if str(parameter.get("id", "")) == param_id:
			return str(parameter.get("default_value", ""))
	return "<no such param>"


## Every line that is not a `##` comment, which the writer must never touch.
static func _code_lines(source: String) -> Array:
	var output: Array = []
	for line: String in source.split("\n"):
		if not line.strip_edges().begins_with("##"):
			output.append(line)
	return output


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] annotation_writer_test: %s" % label)
		return true
	print("[FAIL] annotation_writer_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
