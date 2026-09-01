# Godot EventSheets - renaming, and being renamed out from under.
#
# THE SPINE LAW IS PINNED FIRST, because everything else is only allowed to exist if it holds:
# opening a sheet whose rows point at names nobody answers to and saving it untouched reproduces the
# file byte for byte. Watching the files, deriving the findings and drawing every receipt are all
# QUESTIONS, and no question here writes anything.
#
# Then the two halves of the gesture. The receipt: every row of this sheet that says the name, as the
# words it says now beside the words it would say, and every other file that calls it named and
# marked as one the rename will not touch. And the evidence rule: a "did you mean" is offered only
# when the file's own last save shows the name going out and one name coming in, and every weaker
# shape of that answers nothing at all.
@tool
class_name RenameReceiptsTest
extends RefCounted

## The rename the fixtures act out, spelled once so every test below asks about the same names.
const OLD_NAME := "sound_alarm"
const NEW_NAME := "ring_alarm"

## Where the watched fixtures and the compiled probe are written. `user://` so nothing under res://
## is touched by a test.
const WATCHED_PATH := "user://eventforge_rename_watched.gd"
const TWIN_PATH := "user://eventforge_rename_twin.gd"
const PROBE_PATH := "user://eventforge_rename_probe.gd"


static func run() -> bool:
	var ok: bool = _test_the_sheet_is_never_written_to()
	ok = _test_the_evidence_rule() and ok
	ok = _test_the_witness_watches_one_save() and ok
	ok = _test_the_finding_and_its_one_door() and ok
	ok = _test_the_node_half() and ok
	ok = _test_the_rename_receipt() and ok
	ok = _test_the_doctor_files_the_same_words() and ok
	return ok


# ── 1. the spine law ──────────────────────────────────────────────────────────────


## A sheet calling a name that went away compiles to exactly what it compiled to before, and goes on
## doing so after every question in this file has been asked of it. No row is touched, no parameter
## is rewritten, and the emitted file does not move a byte.
static func _test_the_sheet_is_never_written_to() -> bool:
	var sheet: EventSheetResource = _sheet_calling(OLD_NAME)
	var before: String = _compiled(sheet)
	var ok: bool = _check("the row still compiles to the call it always compiled to",
		before.contains("%s()" % OLD_NAME), true)
	var witness: Dictionary = _witness_of_one_swap()
	var _found: Array[Dictionary] = EventSheetRenameFindings.findings(sheet, "res://probe.gd",
		witness)
	var _lines: PackedStringArray = EventSheetRenameReceipt.row_lines(sheet, OLD_NAME, NEW_NAME)
	var _summary: String = EventSheetRenameReceipt.summary_text(1, [])
	ok = _check("and asking every question about it changes nothing at all",
		_compiled(sheet), before) and ok
	var action: Resource = (sheet.events[0] as EventRow).actions[0] as Resource
	ok = _check("the row keeps its own id and its own value",
		[str(action.get("ace_id")), str((action.get("params") as Dictionary).get("function_name"))],
		[EventSheetRenameFindings.CALL_ACE, OLD_NAME]) and ok
	return ok


# ── 2. the evidence rule ──────────────────────────────────────────────────────────


## The one rule, on every shape of save it has to answer for. It offers a name only when the save
## proves it, and answers "" for every weaker shape - which is most of them, on purpose.
static func _test_the_evidence_rule() -> bool:
	# One name out and one name in IS the swap, whatever the two are spelled like.
	var ok: bool = _check("one name out and one name in is the answer, however differently spelled",
		EventSheetRenameEvidence.did_you_mean(PackedStringArray([OLD_NAME]),
			PackedStringArray([NEW_NAME]), OLD_NAME), NEW_NAME)
	# A busier save is answered only by nearness, and only when exactly one name is near.
	ok = _check("a busier save is answered by the one near spelling in it",
		EventSheetRenameEvidence.did_you_mean(PackedStringArray(["take_damage"]),
			PackedStringArray(["heal", "take_damages"]), "take_damage"), "take_damages") and ok
	ok = _check("but two near spellings are two answers, which is none",
		EventSheetRenameEvidence.did_you_mean(PackedStringArray(["take_damage"]),
			PackedStringArray(["take_damages", "take_damaged"]), "take_damage"), "") and ok
	ok = _check("and a busy save with nothing near it answers nothing",
		EventSheetRenameEvidence.did_you_mean(PackedStringArray(["take_damage"]),
			PackedStringArray(["heal", "revive"]), "take_damage"), "") and ok
	# THE WEAKER TWIN: the near name was in the file BEFORE the save, so it did not arrive, and
	# nothing about that save says the old name became it.
	ok = _check("a near name that was already there did not arrive, and is not an answer",
		EventSheetRenameEvidence.did_you_mean(PackedStringArray(["take_damage"]),
			PackedStringArray(), "take_damage"), "") and ok
	# A name that never went away was never renamed.
	ok = _check("a name that did not vanish is not a rename at all",
		EventSheetRenameEvidence.did_you_mean(PackedStringArray(["heal"]),
			PackedStringArray([NEW_NAME]), OLD_NAME), "") and ok
	# Short names are not held apart by two edits, so nearness is refused below four characters.
	ok = _check("two edits mean nothing on a three-letter name",
		EventSheetRenameEvidence.is_near("hit", "hip"), false) and ok
	ok = _check("and the declaration reader finds functions and signals, not calls",
		EventSheetRenameEvidence.declared_names(
			"signal hurt(amount)\nfunc take_damage(n):\n\tsound_alarm()\n"),
		PackedStringArray(["hurt", "take_damage"])) and ok
	return ok


# ── 3. the witness ────────────────────────────────────────────────────────────────


## The witness over two real saves of two real files: the one that swapped a name answers, and the
## one whose near name was there all along does not. The first sight of a file files no save at all,
## which is why a rename made while the editor was closed is the "anything weaker" case.
static func _test_the_witness_watches_one_save() -> bool:
	EventSheetRenameEvidence.clear_cache()
	var ok: bool = _check("the first sight of a file has nothing to report",
		_observe(WATCHED_PATH, "func %s() -> void:\n\tpass\n" % OLD_NAME).get("gone",
			PackedStringArray()), PackedStringArray())
	var swap: Dictionary = _observe(WATCHED_PATH, "func %s() -> void:\n\treturn\n" % NEW_NAME)
	ok = _check("one save that swapped a name reports exactly that",
		[swap.get("gone", PackedStringArray()), swap.get("arrived", PackedStringArray())],
		[PackedStringArray([OLD_NAME]), PackedStringArray([NEW_NAME])]) and ok
	ok = _check("and the offer follows from it",
		EventSheetRenameEvidence.evidence_for(WATCHED_PATH, OLD_NAME), NEW_NAME) and ok

	# The weaker twin, as a file: the near name was declared before the save as well as after, so
	# nothing arrived and there is nothing the save proves.
	var _first: Dictionary = _observe(TWIN_PATH,
		"func %s() -> void:\n\tpass\n\n\nfunc %ss() -> void:\n\tpass\n" % [OLD_NAME, OLD_NAME])
	var twin: Dictionary = _observe(TWIN_PATH, "func %ss() -> void:\n\treturn\n" % OLD_NAME)
	ok = _check("the twin's save took a name out and brought none in",
		[twin.get("gone", PackedStringArray()), twin.get("arrived", PackedStringArray())],
		[PackedStringArray([OLD_NAME]), PackedStringArray()]) and ok
	ok = _check("so the near name already in the file is never offered",
		EventSheetRenameEvidence.evidence_for(TWIN_PATH, OLD_NAME), "") and ok
	EventSheetRenameEvidence.clear_cache()
	return ok


# ── 4. the quiet state and its one door ───────────────────────────────────────────


## The finding a broken call earns: the amber state's sentence, and the door - which exists only
## when the file proved where the name went.
static func _test_the_finding_and_its_one_door() -> bool:
	var sheet: EventSheetResource = _sheet_calling(OLD_NAME)
	var found: Array[Dictionary] = EventSheetRenameFindings.findings(sheet, "res://guard.gd",
		_witness_of_one_swap())
	var ok: bool = _check("one row, one finding", found.size(), 1)
	if found.is_empty():
		return false
	ok = _check("it hangs at the event, matched by identity",
		EventSheetRenameFindings.for_event(found, sheet.events[0] as EventRow).size(), 1) and ok
	ok = _check("it says which name went, out of which file, and what arrived beside it",
		str(found[0].get("message", "")),
		EventSheetRenameFindings.call_gone_message(OLD_NAME, "guard.gd", NEW_NAME)) and ok
	ok = _check("and the one door names the answer the file proved",
		[str(found[0].get("fix", "")), str(found[0].get("fix_label", "")),
			str(found[0].get("to", ""))],
		[EventSheetRenameFindings.FIX_POINT_THE_ROWS, "Point the rows at %s" % NEW_NAME,
			NEW_NAME]) and ok
	ok = _check("the receipt behind the door is the two names and nothing else",
		EventSheetRenameFindings.point_receipt(found[0]),
		{"before": OLD_NAME, "after": NEW_NAME,
			"kind": EventSheetRenameFindings.KIND_CALL_GONE}) and ok

	# Without the arrival there is no door at all - the row is plainly amber and the reader types.
	var plain: Array[Dictionary] = EventSheetRenameFindings.findings(sheet, "res://guard.gd",
		{"names_gone": PackedStringArray([OLD_NAME]), "names_arrived": PackedStringArray()})
	ok = _check("a save that proved nothing leaves the row amber with no door",
		[plain.size(), str(plain[0].get("fix", "")), str(plain[0].get("fix_label", ""))],
		[1, "", ""]) and ok

	# WHAT IS NOT A FINDING. A call to a name this sheet declares resolves; a call to a name no save
	# took out of this file is not a rename; a row that is not a call is not this file's business.
	var declared: EventSheetResource = _sheet_calling(OLD_NAME)
	var owned := EventFunction.new()
	owned.function_name = OLD_NAME
	declared.functions = [owned]
	ok = _check("a call to a function this sheet declares is not a finding",
		EventSheetRenameFindings.findings(declared, "res://guard.gd",
			_witness_of_one_swap()).size(), 0) and ok
	ok = _check("nor is a call to a name no save took out of this file",
		EventSheetRenameFindings.findings(sheet, "res://guard.gd",
			{"names_gone": PackedStringArray(["something_else"])}).size(), 0) and ok
	ok = _check("and a verbatim block is not a call by any name",
		EventSheetRenameFindings.findings(_sheet_with(RawCodeRow.new()), "res://guard.gd",
			_witness_of_one_swap()).size(), 0) and ok
	ok = _check("an empty witness is the ordinary case and earns nothing",
		EventSheetRenameFindings.findings(sheet, "res://guard.gd", {}).size(), 0) and ok
	return ok


# ── 5. the node half ──────────────────────────────────────────────────────────────


## The same rule over a scene's node names: the row says `$Torch`, the scene's last save took Torch
## out and brought WallTorch in, and the sentence points at the rows rather than at the scene.
static func _test_the_node_half() -> bool:
	var ok: bool = _check("a path is every name it walks through",
		EventSheetRenameFindings.names_in_reference("$UI/Bars/Torch"),
		PackedStringArray(["UI", "Bars", "Torch"]))
	ok = _check("and a quoted one is read the same way",
		EventSheetRenameFindings.names_in_reference("$\"UI/Wall Torch\""),
		PackedStringArray(["UI", "Wall Torch"])) and ok
	ok = _check("swapping one name of a path leaves the rest of it alone",
		EventSheetRenameFindings.reference_with("$UI/Bars/Torch", "Torch", "WallTorch"),
		"$UI/Bars/WallTorch") and ok
	ok = _check("and a scene-unique reference keeps its own mark",
		EventSheetRenameFindings.reference_with("%Torch", "Torch", "WallTorch"),
		"%WallTorch") and ok

	var sheet: EventSheetResource = _sheet_scoped_to("$Torch")
	var witness: Dictionary = {
		"nodes_gone": PackedStringArray(["Torch"]),
		"nodes_arrived": PackedStringArray(["WallTorch"]),
		"scene": "res://rooms/crypt.tscn",
	}
	var found: Array[Dictionary] = EventSheetRenameFindings.findings(sheet, "res://guard.gd",
		witness)
	ok = _check("one row reaching a node that is gone earns one finding", found.size(), 1) and ok
	if found.is_empty():
		return false
	ok = _check("the sentence names the node, the scene and what the scene gained",
		str(found[0].get("message", "")),
		EventSheetRenameFindings.node_gone_message("$Torch", "crypt.tscn", "$WallTorch")) and ok
	ok = _check("and the door points the rows at the reference the scene now holds",
		[str(found[0].get("fix", "")), str(found[0].get("to", ""))],
		[EventSheetRenameFindings.FIX_POINT_THE_ROWS, "$WallTorch"]) and ok
	# Same evidence rule: a scene that gained nothing this could have become offers no door.
	var plain: Array[Dictionary] = EventSheetRenameFindings.findings(sheet, "res://guard.gd",
		{"nodes_gone": PackedStringArray(["Torch"]), "scene": "res://rooms/crypt.tscn"})
	ok = _check("a scene that gained nothing near leaves the row amber with no door",
		[plain.size(), str(plain[0].get("fix", ""))], [1, ""]) and ok
	return ok


# ── 6. the receipt ────────────────────────────────────────────────────────────────


## What the reader is shown before the button exists: every row of this sheet that says the name, as
## the words it says now beside the words it would say, and every other file named and left.
static func _test_the_rename_receipt() -> bool:
	var sheet: EventSheetResource = _sheet_calling(OLD_NAME)
	var ok: bool = _check("every calling row is shown twice over, now and would-be",
		EventSheetRenameReceipt.row_lines(sheet, OLD_NAME, NEW_NAME),
		PackedStringArray(["%s → %s" % [OLD_NAME, NEW_NAME]]))
	var others: Array[Dictionary] = [
		{"path": "res://enemies/enemy.gd", "count": 4},
		{"path": "res://traps/traps.gd", "count": 2},
	]
	ok = _check("the other files are listed by name with their counts",
		EventSheetRenameReceipt.elsewhere_lines(others),
		PackedStringArray(["enemy.gd - 4 row(s)", "traps.gd - 2 row(s)"])) and ok
	ok = _check("and the summary says who calls it and what this will not touch",
		EventSheetRenameReceipt.summary_text(1, others),
		"Called by enemy.gd · traps.gd - 6 row(s) in 2 other file(s). This rewrites the 1 row(s) in this sheet and leaves those exactly as they are.") and ok
	ok = _check("a name nothing else calls says so instead",
		EventSheetRenameReceipt.summary_text(3, []),
		"3 row(s) in this sheet, and nothing else in the project calls it by that name.") and ok
	ok = _check("the node half counts by running the very rewrite the button runs",
		EventSheetRenameReceipt.node_lines(_sheet_scoped_to("$Torch"), "$Torch", "%WallTorch"),
		PackedStringArray(["$Torch → %WallTorch"])) and ok
	return ok


# ── 7. one finding, two roofs ─────────────────────────────────────────────────────


## The Doctor files the same sentence the sheet's own help strip shows, under the finding's own id -
## so a reader meeting it in the inbox and a reader meeting it under the selected row read one
## wording, not two.
static func _test_the_doctor_files_the_same_words() -> bool:
	var sheet: EventSheetResource = _sheet_calling(OLD_NAME)
	var found: Array[Dictionary] = EventSheetRenameFindings.findings(sheet, "res://guard.gd",
		_witness_of_one_swap())
	var filed: Array[Dictionary] = EventSheetRenameDoctor.sheet_findings("res://guard.gd", found)
	var ok: bool = _check("one finding, filed once", filed.size(), 1)
	if filed.is_empty():
		return false
	return _check("with the same words, the same subject and its own check id",
		[str(filed[0].get("check", "")), str(filed[0].get("subject", "")),
			str(filed[0].get("message", "")), str(filed[0].get("severity", ""))],
		[EventSheetRenameDoctor.CHECK_CALL_GONE, OLD_NAME, str(found[0].get("message", "")),
			"warning"]) and ok


# ── fixtures ──────────────────────────────────────────────────────────────────────


## One save of one watched file: write it, drop the held stamp so the next question re-stats it, and
## hand back what the witness made of the change.
static func _observe(path: String, text: String) -> Dictionary:
	_write(path, text)
	EventForgeFileStamp.forget(path)
	EventSheetRenameEvidence.observe(path, EventSheetRenameEvidence.declared_names(text))
	return EventSheetRenameEvidence.last_save(path)


## The witness a file that swapped one name for another leaves behind.
static func _witness_of_one_swap() -> Dictionary:
	return {
		"names_gone": PackedStringArray([OLD_NAME]),
		"names_arrived": PackedStringArray([NEW_NAME]),
	}


## One event whose action lane calls a sheet function by name.
static func _sheet_calling(function_name: String) -> EventSheetResource:
	var call := ACEAction.new()
	call.provider_id = EventSheetRenameFindings.CALL_PROVIDER
	call.ace_id = EventSheetRenameFindings.CALL_ACE
	call.codegen_template = "{function_name}({args})"
	call.params = {"function_name": function_name, "args": ""}
	return _sheet_with(call)


## One event scoped to a node reference, which is the surface a node rename breaks first.
static func _sheet_scoped_to(reference: String) -> EventSheetResource:
	var sheet: EventSheetResource = _sheet_with(RawCodeRow.new())
	(sheet.events[0] as EventRow).with_node_target = reference
	return sheet


static func _sheet_with(row: Resource) -> EventSheetResource:
	var event := EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	event.actions = [row] as Array[Resource]
	var sheet := EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.events = [event] as Array[Resource]
	return sheet


static func _compiled(sheet: EventSheetResource) -> String:
	return str(SheetCompiler.compile(sheet, PROBE_PATH).get("output", ""))


static func _write(path: String, text: String) -> Error:
	var handle: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if handle == null:
		return FileAccess.get_open_error()
	handle.store_string(text)
	handle.close()
	return OK


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] rename_receipts_test: %s" % label)
		return true
	print("[FAIL] rename_receipts_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
