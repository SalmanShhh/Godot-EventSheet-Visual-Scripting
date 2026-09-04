# Godot EventSheets - First Time In This Save, Has Seen, Mark Seen, Forget Seen.
#
# Only Once Ever is true once per COMPUTER, in a file beside the game. These four ask the same
# question of the SAVE SLOT, which is what a first kill, a codex entry and a tutorial a second
# playthrough should see again all actually belong to. Every one of them carries the same two-store
# choice: the SaveSystem autoload when the Save System pack is registered, and the same
# user://remembered.cfg the per-machine rows use when it is not.
#
# What this pins, and nothing else in the suite does:
#   - the emitted helper is the one the row promises: it asks the store ONCE per key and remembers
#     the answer, because the key is an expression and a store read per frame per key would be a
#     file read per frame;
#   - it is true the first time and false ever after, in the same run AND in a fresh one, which is
#     the whole difference between this row and a plain boolean;
#   - Has Seen answers the same question WITHOUT using it up - the trap that makes a codex page
#     unreadable if the two rows share one implementation;
#   - Mark Seen and Forget Seen write the same two stores the readers read, so the four rows are
#     one memory rather than two that agree by accident;
#   - with a real Save System node in the store's place, the memory really does land in the slot
#     under a "seen:" key, which is what makes Start New Run clear it;
#   - with no store at all the fallback is the remembered file, so the rows work in a project that
#     has not installed the save pack - the behaviour the help strip promises;
#   - and the emitted GDScript round-trips byte for byte, so a sheet holding these rows re-opens as
#     the rows rather than as code.
@tool
class_name FirstTimeInSaveTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const SAVE_PACK := "res://eventsheet_addons/save_system/save_system_addon.gd"
const TEST := "first_time_in_save_test"

## This test's own slot and its own key names, so a real save and a real remembered file are never
## touched by it.
const TEST_SLOT := 9
const KEY_A := "first_time_test_a"
const KEY_B := "first_time_test_b"

## Where the fallback keeps its answers, and under which section - the same file Remember Between
## Runs and Only Once Ever use, in a section of this family's own.
const REMEMBERED := "user://remembered.cfg"
const SECTION := "SeenInSave"

## The two lines of the shipped store lookup, which walk the scene tree. A test has no tree, so the
## harnesses below swap exactly these for an injected node and leave every other character of the
## shipped helper alone - the logic under test is the emitted logic, not a copy of it.
const CONDITION_LOOKUP := "\tvar __tree: SceneTree = Engine.get_main_loop() as SceneTree\n\treturn __tree.root.get_node_or_null(^\"SaveSystem\") if __tree != null else null"
const ACTION_LOOKUP := "var __seentree_t: SceneTree = Engine.get_main_loop() as SceneTree\nvar __seenstore_t: Node = __seentree_t.root.get_node_or_null(^\"SaveSystem\") if __seentree_t != null else null"


static func run() -> bool:
	var passed: bool = _the_rows_emit_what_they_promise()
	passed = _the_emitted_sheet_reads_back() and passed
	passed = _the_slot_is_the_memory() and passed
	passed = _without_the_save_pack_it_is_the_remembered_file() and passed
	passed = _marking_and_forgetting_write_the_same_memory() and passed
	passed = _the_doctor_says_which_store_it_landed_in() and passed
	return passed


# ── The note ──────────────────────────────────────────────────────────────────────────────────


## The fallback is honest but it is not what the row's name says, so the Doctor says which of the
## two a project is getting. A NOTE, never a warning - a single-save game has no slots to tell
## apart and may have chosen this deliberately - and silence in a project that registers the pack.
static func _the_doctor_says_which_store_it_landed_in() -> bool:
	var found: Array[Dictionary] = EventSheetSaveMemoryDoctor.report(
		PackedStringArray(["res://game/hud.gd", "res://game/boss.gd"]))
	var first: Dictionary = found[0] if not found.is_empty() else {}
	return SUPPORT.pins(TEST, [
		["one note per script that asks the save", found.size(), 2],
		["and they are sorted, so two runs report in one order",
			str(first.get("path", "")), "res://game/boss.gd"],
		["it is a note, not a warning", str(first.get("severity", "")), "info"],
		["filed under its own check id", str(first.get("check", "")),
			EventSheetSaveMemoryDoctor.CHECK_NO_SAVE_PACK],
		["and it names the file, the store it really landed in, and both ways out",
			str(first.get("message", "")).contains("user://remembered.cfg")
				and str(first.get("message", "")).contains("Only Once Ever")
				and str(first.get("message", "")).contains("boss.gd"), true],
		["a project with nothing to say gets no note",
			EventSheetSaveMemoryDoctor.report(PackedStringArray()).size(), 0],
	])


# ── What the rows emit ────────────────────────────────────────────────────────────────────────


static func _the_rows_emit_what_they_promise() -> bool:
	var output: String = _emitted()
	return SUPPORT.pins(TEST, [
		["the first-time helper emits with the baked uid",
			output.contains("func __first_time_in_save_f1(key: String) -> bool:"), true],
		["it asks the store once per key and keeps the answer",
			output.contains("\tif __seenkeys_f1.has(key):\n\t\treturn false\n\t__seenkeys_f1[key] = true"), true],
		["Has Seen brings its own reader rather than the consuming one",
			output.contains("func __seen_in_save_h1(key: String) -> bool:"), true],
		["and declares no first-time helper of its own",
			output.contains("__first_time_in_save_h1"), false],
		["the slot key is namespaced so it cannot collide with a game's own",
			output.contains("\"seen:\" + key"), true],
		["Mark Seen writes true", output.contains("__seenstore_m1.call(&\"save_value\", \"seen:\" + str(\"%s\"), true)" % KEY_A), true],
		["Forget Seen writes false", output.contains("__seencfg_g1.set_value(\"SeenInSave\", str(\"%s\"), false)" % KEY_A), true],
		["no {uid} survives", output.contains("{uid}"), false],
		["the emitted source parses", _parses(output), OK],
	])


## The lossless contract, for the one row family whose helper is synthesized rather than written:
## opening the emitted `.gd` and saving it untouched has to reproduce the file byte for byte, or a
## sheet holding these rows would rewrite itself the first time anybody opened it.
##
## The two CONDITIONS read back as themselves - their whole line is one helper call, which is a
## sentence the reverse index can claim. The two ACTIONS are several statements with a local in
## front, which the reverse index deliberately does not claim for anybody: they read back as the
## faithful line-by-line reading, and re-emit character for character, exactly as the shipped
## Forget First Time beside them has always done. That parity is pinned rather than assumed,
## because "my new row degrades" and "this whole family degrades" are different facts.
static func _the_emitted_sheet_reads_back() -> bool:
	var output: String = _emitted()
	var again: String = SUPPORT.reemit(output, "user://first_time_in_save_verify.gd")
	var reopened: EventSheetResource = SUPPORT.reopen(output)
	var ids: Array = []
	for row: Variant in reopened.events:
		if row is EventRow:
			for condition: Variant in (row as EventRow).conditions:
				if condition is ACECondition:
					ids.append((condition as ACECondition).ace_id)
	return SUPPORT.pins(TEST, [
		["the emitted sheet re-emits byte for byte", again, output],
		["the two conditions come back as their own rows, the consuming one last", ids,
			["HasSeenInSave", "FirstTimeInSave"]],
		["and the two write rows round-trip the way the shipped Forget First Time does",
			[_action_round_trips("MarkSeenInSave"), _action_round_trips("ForgetSeenInSave"),
				_action_round_trips("ForgetOnce")],
			[true, true, true]],
	])


## One action alone, emitted, re-opened and re-emitted: true when the second text is the first one
## character for character.
static func _action_round_trips(ace_id: String) -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnReady"
	row.actions.append(_baked_act(ace_id, {"key": "\"%s\"" % KEY_A}, "r1"))
	sheet.events.append(row)
	var output: String = SUPPORT.compile_output(sheet, "user://first_time_in_save_one.gd")
	return SUPPORT.reemit(output, "user://first_time_in_save_one_verify.gd") == output


# ── With the save pack in the tree ────────────────────────────────────────────────────────────


## A real Save System node in the store's place: the answer lands in the SLOT, under a key of this
## family's own, which is what makes Start New Run clear it along with everything else in the slot.
static func _the_slot_is_the_memory() -> bool:
	var save_script: GDScript = load(SAVE_PACK)
	if save_script == null:
		return SUPPORT.check(TEST, "the save pack loads", false, true)
	var keeper: Node = save_script.new()
	keeper.slot = TEST_SLOT
	keeper.delete_slot()

	var run: Variant = _first_time_harness(keeper)
	var first: bool = run.__first_time_in_save_t(KEY_A)
	var again: bool = run.__first_time_in_save_t(KEY_A)
	var other_key: bool = run.__first_time_in_save_t(KEY_B)
	# A SECOND row, so the answer has to have come off disk rather than out of the first one's
	# memory - this is the "next run" the row's own help promises.
	var next_run: Variant = _first_time_harness(keeper)
	var after_restart: bool = next_run.__first_time_in_save_t(KEY_A)
	var asking: Variant = _has_seen_harness(keeper)
	var seen: bool = asking.__seen_in_save_t(KEY_A)
	var seen_again: bool = asking.__seen_in_save_t(KEY_A)
	var never: bool = asking.__seen_in_save_t("first_time_test_never")

	var pins: bool = SUPPORT.pins(TEST, [
		["true the first time", first, true],
		["false the second time, same run", again, false],
		["a different key has its own memory", other_key, true],
		["false on a fresh run, because the slot remembers", after_restart, false],
		["the slot really holds it", keeper.has_save_key("seen:" + KEY_A), true],
		["Has Seen says yes", seen, true],
		["and says yes again, because asking does not use it up", seen_again, true],
		["a key nothing marked is not seen", never, false],
	])
	keeper.delete_slot()
	keeper.free()
	return pins


# ── Without it ────────────────────────────────────────────────────────────────────────────────


## No store at all is a project that has not installed the save pack, and the rows still work: the
## fallback is the same user://remembered.cfg the per-machine rows use. One answer for the whole
## computer rather than one per save, which is exactly what the help strip says and what the
## Doctor's note is about.
static func _without_the_save_pack_it_is_the_remembered_file() -> bool:
	_forget_in_file(KEY_A)
	var run: Variant = _first_time_harness(null)
	var first: bool = run.__first_time_in_save_t(KEY_A)
	var next_run: Variant = _first_time_harness(null)
	var after_restart: bool = next_run.__first_time_in_save_t(KEY_A)
	var file: ConfigFile = ConfigFile.new()
	file.load(REMEMBERED)
	var pins: bool = SUPPORT.pins(TEST, [
		["true the first time with no save pack", first, true],
		["false on a fresh run, because the remembered file kept it", after_restart, false],
		["and it is in that file, in this family's own section", bool(file.get_value(SECTION, KEY_A, false)), true],
	])
	_forget_in_file(KEY_A)
	return pins


# ── The two write rows ────────────────────────────────────────────────────────────────────────


## Mark Seen and Forget Seen are ACTIONS, so they carry no synthesized member and spell the same
## two-store choice inline. The pin that matters is that the four rows are ONE memory: what the
## action writes is what the condition reads, in both stores.
static func _marking_and_forgetting_write_the_same_memory() -> bool:
	var save_script: GDScript = load(SAVE_PACK)
	if save_script == null:
		return SUPPORT.check(TEST, "the save pack loads", false, true)
	var keeper: Node = save_script.new()
	keeper.slot = TEST_SLOT
	keeper.delete_slot()

	var writer: Variant = _write_harness(keeper)
	writer.mark()
	var seen_after_mark: bool = _has_seen_harness(keeper).__seen_in_save_t(KEY_A)
	var first_after_mark: bool = _first_time_harness(keeper).__first_time_in_save_t(KEY_A)
	writer.forget()
	var seen_after_forget: bool = _has_seen_harness(keeper).__seen_in_save_t(KEY_A)
	var first_after_forget: bool = _first_time_harness(keeper).__first_time_in_save_t(KEY_A)

	_forget_in_file(KEY_A)
	var file_writer: Variant = _write_harness(null)
	file_writer.mark()
	var file_seen: bool = _has_seen_harness(null).__seen_in_save_t(KEY_A)
	file_writer.forget()
	var file_forgotten: bool = _has_seen_harness(null).__seen_in_save_t(KEY_A)

	var pins: bool = SUPPORT.pins(TEST, [
		["Mark Seen is read by Has Seen", seen_after_mark, true],
		["and takes First Time In This Save's first away", first_after_mark, false],
		["Forget Seen puts it back", seen_after_forget, false],
		["so the first time happens again", first_after_forget, true],
		["the same pair, in the remembered file", file_seen, true],
		["forgotten there too", file_forgotten, false],
	])
	keeper.delete_slot()
	keeper.free()
	_forget_in_file(KEY_A)
	return pins


# ── The fixtures ──────────────────────────────────────────────────────────────────────────────


## One sheet holding all four rows, compiled - the bytes every pin above is read out of.
static func _emitted() -> String:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnProcess"
	row.conditions.append(_baked_cond("FirstTimeInSave", {"key": "\"%s\"" % KEY_A}, "f1"))
	row.conditions.append(_baked_cond("HasSeenInSave", {"key": "\"%s\"" % KEY_B}, "h1"))
	row.actions.append(_baked_act("MarkSeenInSave", {"key": "\"%s\"" % KEY_A}, "m1"))
	row.actions.append(_baked_act("ForgetSeenInSave", {"key": "\"%s\"" % KEY_A}, "g1"))
	sheet.events.append(row)
	return SUPPORT.compile_output(sheet, "user://first_time_in_save_out.gd")


## The shipped First Time In This Save helper, with only its scene-tree store lookup swapped for
## an injected node, so the reader, the writer and the once-per-key memory under test are the
## emitted ones character for character.
static func _first_time_harness(store: Node) -> Variant:
	return _harness("FirstTimeInSave", store)


## The same, for Has Seen - which brings its own reader and no marker, because asking must not use
## the memory up.
static func _has_seen_harness(store: Node) -> Variant:
	return _harness("HasSeenInSave", store)


static func _harness(ace_id: String, store: Node) -> Variant:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	var member: String = descriptor.member_template.replace("{uid}", "t").replace(
		CONDITION_LOOKUP, "\treturn store")
	var script: GDScript = GDScript.new()
	script.source_code = "extends RefCounted\nvar store: Node = null\n\n%s\n" % member
	script.reload()
	var instance: Variant = script.new()
	instance.store = store
	return instance


## Mark Seen and Forget Seen as two methods on one object, each holding the shipped action template
## with its own uid baked in and its store lookup swapped the same way.
static func _write_harness(store: Node) -> Variant:
	var script: GDScript = GDScript.new()
	script.source_code = "extends RefCounted\nvar store: Node = null\n\nfunc mark() -> void:\n%s\n\nfunc forget() -> void:\n%s\n" % [
		_indented("MarkSeenInSave", "m"), _indented("ForgetSeenInSave", "g")]
	script.reload()
	var instance: Variant = script.new()
	instance.store = store
	return instance


## One action template, baked, its store lookup replaced and every line pushed in by a tab so it
## reads as a function body.
static func _indented(ace_id: String, uid: String) -> String:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	var body: String = descriptor.codegen_template.replace("{key}", "\"%s\"" % KEY_A).replace("{uid}", uid)
	body = body.replace(ACTION_LOOKUP.replace("_t", "_" + uid), "var __seenstore_%s: Node = store" % uid)
	var lines: PackedStringArray = PackedStringArray()
	for line: String in body.split("\n"):
		lines.append("\t" + line)
	return "\n".join(lines)


## The fallback's own answer for one key, cleared - so a run of this test never depends on what an
## earlier one left in the shared remembered file.
static func _forget_in_file(key: String) -> void:
	var file: ConfigFile = ConfigFile.new()
	file.load(REMEMBERED)
	file.set_value(SECTION, key, false)
	file.save(REMEMBERED)


static func _parses(source: String) -> int:
	var script: GDScript = GDScript.new()
	script.source_code = source
	return script.reload()


static func _baked_cond(ace_id: String, params: Dictionary, uid: String) -> ACECondition:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = ace_id
	condition.params = params
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	condition.codegen_template = descriptor.codegen_template.replace("{uid}", uid)
	condition.member_declaration = descriptor.member_template.replace("{uid}", uid)
	return condition


static func _baked_act(ace_id: String, params: Dictionary, uid: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	action.codegen_template = descriptor.codegen_template.replace("{uid}", uid)
	return action
