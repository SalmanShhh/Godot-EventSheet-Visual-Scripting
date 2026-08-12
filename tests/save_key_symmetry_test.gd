# Project Doctor: save-key symmetry (a value read back that nothing ever saves), plus the public
# API surface that came with it.
#
# The check scans EMITTED scripts and diffs the save keys a project writes against the ones it
# reads back. Two things are proven here, in this order:
#
#   1. THE DETECTOR IS PROVEN AGAINST REAL COMPILER OUTPUT, not hand-typed strings. A sheet with a
#      Save System row, a Load row and a Remember Between Runs variable is compiled, and the rule
#      is run over what the compiler actually emitted. A regex pinned only against a fixture the
#      test author typed proves the test author's imagination, not the feature.
#   2. EVERY NO-FALSE-POSITIVE CASE IS PINNED EXPLICITLY. A Doctor check that accuses a working
#      game is worse than no check at all, so the cases that must stay SILENT get more coverage
#      than the case that must speak: a key written by another sheet, by a save_state() snapshot,
#      by a pack, by Remember Between Runs, and a key that is computed rather than literal.
#
# WHY EVERY FIXTURE IS ASSEMBLED AT RUNTIME. The check walks every .gd outside addons/ - including
# this file. A fixture written out in one piece would read as a real save call and make the Doctor
# report this repo's own test suite forever, which is the exact noise the check exists to avoid.
# So no fixture below ever spells a call and its key literal adjacently: the key always arrives
# through %s. (The end-to-end case at the bottom asserts precisely that: zero findings on this
# repo.)
class_name SaveKeySymmetryTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _run_against_compiler_output() and all_passed
	all_passed = _run_finding_rules() and all_passed
	all_passed = _run_no_false_positives() and all_passed
	all_passed = _run_end_to_end() and all_passed
	all_passed = _run_api_surface() and all_passed
	return all_passed


# ── 1. The detector, against what the compiler really emits ────────────────────────────


static func _run_against_compiler_output() -> bool:
	var all_passed: bool = true

	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.variables = {"coins": {"type": "float", "default": 0.0, "exported": true, "attributes": {"remember": true}}}
	var boot: EventRow = EventRow.new()
	boot.trigger_provider_id = "Core"
	boot.trigger_id = "OnReady"
	boot.actions.append(_save_system_action("LoadNumber", "coins = SaveSystem.load_number({key})", {"key": _quoted("coins")}))
	boot.actions.append(_save_system_action("SaveNumber", "SaveSystem.save_number({key}, {value})", {"key": _quoted("coins"), "value": "coins"}))
	sheet.events.append(boot)

	var result: Dictionary = SheetCompiler.compile(sheet, "user://save_key_symmetry_out.gd")
	all_passed = _check("the fixture sheet compiles", bool(result.get("success", false)), true) and all_passed
	var output: String = str(result.get("output", ""))

	# The emitted lines this rule has to recognise, pinned so a template change is caught here
	# rather than by the check silently going blind.
	all_passed = _check("compiler emits the save call", output.contains("SaveSystem.save_number(%s, coins)" % _quoted("coins")), true) and all_passed
	all_passed = _check("compiler emits the load call", output.contains("SaveSystem.load_number(%s)" % _quoted("coins")), true) and all_passed
	all_passed = _check("compiler emits the remember store", output.contains("__remember_cfg.set_value(%s, %s, coins)" % [_quoted("vars"), _quoted("coins")]), true) and all_passed

	var usage: Dictionary = EventSheetProjectDoctor.save_key_usage(output)
	all_passed = _check("real output: the save is seen", (usage["saved"] as PackedStringArray).has("coins"), true) and all_passed
	all_passed = _check("real output: the load is seen", (usage["loaded"] as PackedStringArray).has("coins"), true) and all_passed
	all_passed = _check("real output: the remembered variable is seen", (usage["remembered"] as PackedStringArray).has("coins"), true) and all_passed

	# A sheet with no save vocabulary at all contributes nothing (the early-out path).
	var plain: EventSheetResource = EventSheetResource.new()
	plain.variables = {"score": {"type": "int", "default": 0, "exported": true}}
	var plain_usage: Dictionary = EventSheetProjectDoctor.save_key_usage(str(SheetCompiler.compile(plain, "user://save_key_symmetry_plain.gd").get("output", "")))
	all_passed = _check("a sheet with no saves yields no keys", (plain_usage["loaded"] as PackedStringArray).size() + (plain_usage["saved"] as PackedStringArray).size(), 0) and all_passed

	return all_passed


# ── 2. The findings themselves ─────────────────────────────────────────────────────────


static func _run_finding_rules() -> bool:
	var all_passed: bool = true

	# THE BUG THIS CHECK EXISTS FOR: "coins" is read back on ready and nothing writes it.
	var findings: Array[Dictionary] = EventSheetProjectDoctor.save_key_findings({
		"res://game/player.gd": EventSheetProjectDoctor.save_key_usage(_reads("coins")),
	})
	all_passed = _check("a read with no writer reports once", findings.size(), 1) and all_passed
	if findings.size() == 1:
		all_passed = _check("severity is warning", str(findings[0].get("severity")), "warning") and all_passed
		all_passed = _check("check id", str(findings[0].get("check")), "save-key-symmetry") and all_passed
		all_passed = _check("the finding is clickable at the reading script", str(findings[0].get("path")), "res://game/player.gd") and all_passed
		all_passed = _check("the message names the key", str(findings[0].get("message")).contains("\"coins\""), true) and all_passed
		all_passed = _check("the message says what goes wrong", str(findings[0].get("message")).contains("reads its default on every run"), true) and all_passed

	# Two unwritten keys report once each, in a stable (sorted) order.
	var pair: Array[Dictionary] = EventSheetProjectDoctor.save_key_findings({
		"res://game/player.gd": EventSheetProjectDoctor.save_key_usage(_reads("wallet") + _reads("armour")),
	})
	all_passed = _check("two unwritten keys report twice", pair.size(), 2) and all_passed
	if pair.size() == 2:
		all_passed = _check("findings are sorted by key", str(pair[0].get("message")).contains("\"armour\""), true) and all_passed

	# THE DOUBLE-STORAGE CASE: one name living in remembered.cfg AND in the slot file.
	var doubled: Array[Dictionary] = EventSheetProjectDoctor.save_key_findings({
		"res://game/player.gd": EventSheetProjectDoctor.save_key_usage(_remembers("coins")),
		"res://game/shop.gd": EventSheetProjectDoctor.save_key_usage(_writes("coins")),
	})
	all_passed = _check("double storage reports once", doubled.size(), 1) and all_passed
	if doubled.size() == 1:
		all_passed = _check("double storage is advisory only", str(doubled[0].get("severity")), "info") and all_passed
		all_passed = _check("double storage names the remembering sheet", str(doubled[0].get("path")), "res://game/player.gd") and all_passed
		all_passed = _check("double storage explains the risk", str(doubled[0].get("message")).contains("can disagree"), true) and all_passed

	# The key families: a slot-state key (second argument) is read back the same way.
	var slot_state: Array[Dictionary] = EventSheetProjectDoctor.save_key_findings({
		"res://game/level.gd": EventSheetProjectDoctor.save_key_usage("\tSaveSystem.load_node_state($Player, %s)\n" % _quoted("player")),
	})
	all_passed = _check("an unwritten node-state key reports", slot_state.size(), 1) and all_passed

	return all_passed


# ── 3. The cases that must stay silent ─────────────────────────────────────────────────


static func _run_no_false_positives() -> bool:
	var all_passed: bool = true

	# (a) ANOTHER SHEET writes it. The corpus is project-wide, so this is symmetric.
	all_passed = _check("a key written by another sheet is fine", EventSheetProjectDoctor.save_key_findings({
		"res://game/player.gd": EventSheetProjectDoctor.save_key_usage(_reads("coins")),
		"res://game/save_point.gd": EventSheetProjectDoctor.save_key_usage(_writes("coins")),
	}).size(), 0) and all_passed

	# (b) A save_state() SNAPSHOT writes it - the seam every stateful pack ships.
	all_passed = _check("a key in a save_state snapshot is fine", EventSheetProjectDoctor.save_key_findings({
		"res://game/player.gd": EventSheetProjectDoctor.save_key_usage(_reads("wallet")),
		"res://game/wallet.gd": EventSheetProjectDoctor.save_key_usage(_snapshots("wallet")),
	}).size(), 0) and all_passed

	# (c) REMEMBER BETWEEN RUNS writes it, so the accusation must not fire. (What DOES fire is the
	# advisory above, because the same name then lives in two files - that is the honest reading.)
	var remembered_only: Array[Dictionary] = EventSheetProjectDoctor.save_key_findings({
		"res://game/player.gd": EventSheetProjectDoctor.save_key_usage(_remembers("coins") + _reads("coins")),
	})
	all_passed = _check("remembered keys are never accused of being unsaved", _severity_count(remembered_only, "warning"), 0) and all_passed
	all_passed = _check("remembered plus a slot key is the advisory instead", _severity_count(remembered_only, "info"), 1) and all_passed

	# (d) A Remember Between Runs variable the Save System never touches is nobody's business.
	all_passed = _check("a plain remembered variable reports nothing", EventSheetProjectDoctor.save_key_findings({
		"res://game/options.gd": EventSheetProjectDoctor.save_key_usage(_remembers("volume")),
	}).size(), 0) and all_passed

	# (d2) THE double-storage advisory must not fire on a bare NAME collision. A pack's save_state
	# member lives inside that node's own dictionary, so a pack returning {"level": …} shares
	# nothing with an author's remembered `level` but a common word - and "level", "score",
	# "coins", "health" and "seed" are exactly the words that collide in every real project.
	all_passed = _check("a pack's snapshot member is not the same thing as a remembered name",
		EventSheetProjectDoctor.save_key_findings({
			"res://game/options.gd": EventSheetProjectDoctor.save_key_usage(_remembers("level")),
			"res://eventsheet_addons/statforge/statforge_addon.gd": EventSheetProjectDoctor.save_key_usage(_snapshots("level")),
		}).size(), 0) and all_passed
	# ...and a PROJECT script's own snapshot member is not one either.
	all_passed = _check("a project's own snapshot member is not a slot key",
		EventSheetProjectDoctor.save_key_findings({
			"res://game/options.gd": EventSheetProjectDoctor.save_key_usage(_remembers("level")),
			"res://game/wallet.gd": EventSheetProjectDoctor.save_key_usage(_snapshots("level")),
		}).size(), 0) and all_passed
	# ...but a real slot key of the same name still is the advisory, because those two copies
	# really can disagree.
	all_passed = _check("a real Save Value of the same name still advises",
		_severity_count(EventSheetProjectDoctor.save_key_findings({
			"res://game/options.gd": EventSheetProjectDoctor.save_key_usage(_remembers("level")),
			"res://game/shop.gd": EventSheetProjectDoctor.save_key_usage(_writes("level")),
		}), "info"), 1) and all_passed
	# A pack READING the name is not enough either - a pack is not the author's doing.
	all_passed = _check("a pack's read alone does not raise the advisory",
		EventSheetProjectDoctor.save_key_findings({
			"res://game/options.gd": EventSheetProjectDoctor.save_key_usage(_remembers("level")),
			"res://eventsheet_addons/quest/quest_addon.gd": EventSheetProjectDoctor.save_key_usage(_reads("level")),
		}).size(), 0) and all_passed

	# (e) A COMPUTED key is not decidable, so it is neither read nor written as far as this goes.
	var computed: Dictionary = EventSheetProjectDoctor.save_key_usage("\tvar k: String = \"co\" + \"ins\"\n\tcoins = SaveSystem.load_number(k)\n")
	all_passed = _check("a computed key is not read as a key", (computed["loaded"] as PackedStringArray).size(), 0) and all_passed
	var computed_slot: Dictionary = EventSheetProjectDoctor.save_key_usage("\tSaveSystem.save_node_state(get_node(\"Player\"), %s)\n" % _quoted("player"))
	all_passed = _check("a call in the node slot stops the match", (computed_slot["saved"] as PackedStringArray).size(), 0) and all_passed

	# (f) A PACK is shipped vocabulary the author cannot edit, so it is never blamed...
	all_passed = _check("a pack is never blamed for its own read", EventSheetProjectDoctor.save_key_findings({
		"res://eventsheet_addons/quest/quest_addon.gd": EventSheetProjectDoctor.save_key_usage(_reads("quests")),
	}).size(), 0) and all_passed
	# ...but a pack's WRITE still satisfies a project read.
	all_passed = _check("a pack's write satisfies a project read", EventSheetProjectDoctor.save_key_findings({
		"res://game/player.gd": EventSheetProjectDoctor.save_key_usage(_reads("quests")),
		"res://eventsheet_addons/quest/quest_addon.gd": EventSheetProjectDoctor.save_key_usage(_writes("quests")),
	}).size(), 0) and all_passed
	# ...and when a pack and a project script both read it, the project script is the one named.
	var mixed: Array[Dictionary] = EventSheetProjectDoctor.save_key_findings({
		"res://eventsheet_addons/quest/quest_addon.gd": EventSheetProjectDoctor.save_key_usage(_reads("quests")),
		"res://game/player.gd": EventSheetProjectDoctor.save_key_usage(_reads("quests")),
	})
	all_passed = _check("the finding names a file the author can open", str(mixed[0].get("path")) if mixed.size() == 1 else "", "res://game/player.gd") and all_passed

	# (f2) A MIGRATION rewrites the raw payload by subscript, which is a real write with no verb in
	# sight. Found by the sibling save-system work: the check accused a working migration of never
	# saving the field it had just written. The fixture ends the way the PACK documents the flow -
	# Use Upgraded Save, and nothing else - so this proves the flow rather than proving that some
	# unrelated save call happened to be in the same file.
	all_passed = _check("a subscript write into a save payload is a write", EventSheetProjectDoctor.save_key_findings({
		"res://game/player.gd": EventSheetProjectDoctor.save_key_usage(_reads("health")),
		"res://game/migrate.gd": EventSheetProjectDoctor.save_key_usage(_migrates("health", "hp")),
	}).size(), 0) and all_passed
	all_passed = _check("the migration fixture really ends at Use Upgraded Save",
		_migrates("health", "hp").contains("save_game"), false) and all_passed

	# (f2b) SAVE GROUP STATE names its group with a literal, which is exactly how the guide writes
	# it - and its partner Load Group State reads the key back. A write pattern that refused a
	# quoted first argument saw only the read, and accused every documented use of the pair.
	var group_pair: Array[Dictionary] = EventSheetProjectDoctor.save_key_findings({
		"res://game/level.gd": EventSheetProjectDoctor.save_key_usage(_saves_group("enemies", "enemy_state") + _loads_group("enemy_state")),
	})
	all_passed = _check("Save Group State with a literal group is a write", group_pair.size(), 0) and all_passed
	all_passed = _check("and the key it writes is reported as saved",
		(EventSheetProjectDoctor.save_key_usage(_saves_group("enemies", "enemy_state"))["saved"] as PackedStringArray).has("enemy_state"), true) and all_passed
	# ...while a CALL in that first slot still stops the match dead, because a computed group is
	# not decidable and silence is the right answer to what cannot be read.
	all_passed = _check("a call in the group slot is still not a write",
		(EventSheetProjectDoctor.save_key_usage("\tSaveSystem.save_group_state(group_for(level), %s)\n" % _quoted("enemy_state"))["saved"] as PackedStringArray).size(), 0) and all_passed

	# (f2c) An INNER CLASS may carry the save_state seam - the shape a pack author reaches for when
	# several sub-objects each snapshot themselves. Its keys are written just as much as a
	# top-level seam's, so a scanner that only recognised column 0 accused them of never being saved.
	all_passed = _check("a save_state on an inner class is still a write", EventSheetProjectDoctor.save_key_findings({
		"res://game/player.gd": EventSheetProjectDoctor.save_key_usage(_reads("inner_key")),
		"res://game/parts.gd": EventSheetProjectDoctor.save_key_usage(_nested_snapshot("inner_key")),
	}).size(), 0) and all_passed

	# (f2d) A call written out inside a COMMENT is prose, not code. Counting it is how a text
	# scanner accuses a game that never made the call at all.
	all_passed = _check("a read inside a comment is not a read",
		(EventSheetProjectDoctor.save_key_usage("# reads it with SaveSystem.load_number(%s)\nfunc _r() -> void:\n\tpass\n" % _quoted("coins"))["loaded"] as PackedStringArray).size(), 0) and all_passed
	all_passed = _check("and the same line in real code still is",
		(EventSheetProjectDoctor.save_key_usage(_reads("coins"))["loaded"] as PackedStringArray).has("coins"), true) and all_passed
	# ...but only where the file is doing save work, so an unrelated dictionary never hides a gap.
	var unrelated: Dictionary = EventSheetProjectDoctor.save_key_usage("\tvar palette: Dictionary = {}\n\tpalette[%s] = Color.RED\n" % _quoted("health"))
	all_passed = _check("an unrelated dictionary is not a save write", (unrelated["saved"] as PackedStringArray).size(), 0) and all_passed
	# An equality test is not an assignment.
	var comparison: Dictionary = EventSheetProjectDoctor.save_key_usage(_writes("coins") + "\tif data[%s] == 1:\n\t\tpass\n" % _quoted("armour"))
	all_passed = _check("a subscript comparison is not a write", (comparison["saved"] as PackedStringArray).has("armour"), false) and all_passed

	# (f3) The save backend's OWN reserved keys ("__version", "__addons", "__persist") are written
	# from inside the pack where no row exists to find, so they are never blamed on anyone.
	all_passed = _check("a reserved __ key is never reported", EventSheetProjectDoctor.save_key_findings({
		"res://game/menu.gd": EventSheetProjectDoctor.save_key_usage(_reads("__version")),
	}).size(), 0) and all_passed
	all_passed = _check("save_keys_used still reports the reserved key as read", (EventSheetProjectDoctor.save_key_usage(_reads("__version"))["loaded"] as PackedStringArray).has("__version"), true) and all_passed

	# (g) A WRITE is matched loosely (a hand-rolled wrapper counts), a READ strictly (only a real
	# dotted call). Missing a write would be a false accusation; missing a read is only silence.
	var loose: Dictionary = EventSheetProjectDoctor.save_key_usage("\tsave_value(%s, coins)\n" % _quoted("coins"))
	all_passed = _check("a receiver-less write still counts as a write", (loose["saved"] as PackedStringArray).has("coins"), true) and all_passed
	var strict: Dictionary = EventSheetProjectDoctor.save_key_usage("\tcoins = load_number(%s)\n" % _quoted("coins"))
	all_passed = _check("a receiver-less read is not counted", (strict["loaded"] as PackedStringArray).size(), 0) and all_passed
	var declaration: Dictionary = EventSheetProjectDoctor.save_key_usage("func load_text(key: String) -> String:\n\treturn \"\"\n")
	all_passed = _check("a function declaration is not a read", (declaration["loaded"] as PackedStringArray).size(), 0) and all_passed

	return all_passed


# ── 4. Wiring, and the promise that this repo stays quiet ──────────────────────────────


static func _run_end_to_end() -> bool:
	var all_passed: bool = true

	var doctor_source: String = FileAccess.get_file_as_string("res://addons/eventforge/project_doctor.gd")
	all_passed = _check("the check runs in the Doctor's audit", doctor_source.contains("check_save_key_symmetry(sheet_paths, findings)"), true) and all_passed

	# The real scan over the real project: a check that fires on the repo that ships it is noise.
	var findings: Array[Dictionary] = []
	EventSheetProjectDoctor.check_save_key_symmetry(PackedStringArray(), findings)
	if not findings.is_empty():
		for finding: Dictionary in findings:
			print("  unexpected: %s - %s" % [str(finding.get("path")), str(finding.get("message"))])
	all_passed = _check("the real project scan is silent", findings.size(), 0) and all_passed

	return all_passed


# ── 5. The API surface the wave needs ──────────────────────────────────────────────────


static func _run_api_surface() -> bool:
	var all_passed: bool = true

	# save_keys_used: the Doctor's own rule, so tooling can never disagree with the check.
	var api_usage: Dictionary = EventSheets.save_keys_used(_writes("coins") + _reads("gems"))
	all_passed = _check("save_keys_used reports the written key", (api_usage["saved"] as PackedStringArray).has("coins"), true) and all_passed
	all_passed = _check("save_keys_used reports the read key", (api_usage["loaded"] as PackedStringArray).has("gems"), true) and all_passed

	# project_scripts: the corpus a Doctor extension check actually wants (sheet_paths is .tres only).
	var scripts: PackedStringArray = EventSheets.project_scripts()
	all_passed = _check("project_scripts finds this test", scripts.has("res://tests/save_key_symmetry_test.gd"), true) and all_passed
	var leaked_plugin_script: String = ""
	for script_path: String in scripts:
		if script_path.begins_with("res://addons/"):
			leaked_plugin_script = script_path
			break
	all_passed = _check("project_scripts excludes the plugin's own code", leaked_plugin_script, "") and all_passed

	# table_from_text: the Table From File parse as a service. The EDGE CASE it exists for is the
	# quoted cell that contains the separator - the reason nobody should re-implement this parse.
	var rows: Array = EventSheets.table_from_text("name,price\nsword,10\n\"dagger, short\",7\n")
	all_passed = _check("a table reads one record per row", rows.size(), 2) and all_passed
	all_passed = _check("fields are reachable by column name", str((rows[0] as Dictionary).get("price", "")), "10") and all_passed
	all_passed = _check("a quoted cell may contain the separator", str((rows[1] as Dictionary).get("name", "")), "dagger, short") and all_passed
	all_passed = _check("the row after a quoted cell keeps its columns", str((rows[1] as Dictionary).get("price", "")), "7") and all_passed
	var windows_rows: Array = EventSheets.table_from_text("name,price\r\nshield,12\r\n")
	all_passed = _check("Windows line endings are handled", str((windows_rows[0] as Dictionary).get("price", "")), "12") and all_passed
	var short_rows: Array = EventSheets.table_from_text("name,price\nbow\n")
	all_passed = _check("a short row fills the missing column", str((short_rows[0] as Dictionary).get("price", "MISSING")), "") and all_passed
	all_passed = _check("empty text is no rows", EventSheets.table_from_text("").size(), 0) and all_passed
	var semicolons: Array = EventSheets.table_from_text("name;price\ngem;99\n", ";")
	all_passed = _check("the separator is honoured", str((semicolons[0] as Dictionary).get("price", "")), "99") and all_passed

	# table_from_file: the same parse over a real file on disk, and a missing file reads as no rows.
	var csv_path: String = "user://save_key_symmetry_table.csv"
	var handle: FileAccess = FileAccess.open(csv_path, FileAccess.WRITE)
	handle.store_string("name,price\n\"dagger, short\",7\n")
	handle.close()
	var file_rows: Array = EventSheets.table_from_file(csv_path)
	all_passed = _check("a file reads the same records as the text", str((file_rows[0] as Dictionary).get("name", "")), "dagger, short") and all_passed
	DirAccess.remove_absolute(csv_path)
	all_passed = _check("a missing file reads as no rows", EventSheets.table_from_file("user://no_such_table.csv").size(), 0) and all_passed

	return all_passed


# ── Fixtures ───────────────────────────────────────────────────────────────────────────
#
# The key always arrives through %s: see the header note on why this file must never contain a
# save call and its literal key side by side.


static func _quoted(key: String) -> String:
	return "\"%s\"" % key


static func _reads(key: String) -> String:
	return "func _ready() -> void:\n\tcoins = SaveSystem.load_number(%s)\n" % _quoted(key)


static func _writes(key: String) -> String:
	return "func _on_before_save() -> void:\n\tSaveSystem.save_number(%s, coins)\n" % _quoted(key)


static func _snapshots(key: String) -> String:
	return "func save_state() -> Dictionary:\n\treturn {\n\t\t%s: _wallet\n\t}\n" % _quoted(key)


## A migration handed the raw slot Dictionary, rewriting one field into its new name and handing it
## back - the exact shape the Save System's On Save Needs Upgrade / Use Upgraded Save pair documents,
## with no other save call in the file to supply the marker by accident.
static func _migrates(new_key: String, old_key: String) -> String:
	return "func _on_upgrade(save_data: Dictionary) -> void:\n\tsave_data[%s] = save_data[%s]\n\tsave_data.erase(%s)\n\tSaveSystem.use_upgraded_save(save_data)\n" % [_quoted(new_key), _quoted(old_key), _quoted(old_key)]


## Save Group State written the way the guide writes it: a literal group name, then the key.
static func _saves_group(group: String, key: String) -> String:
	return "func _on_before_save() -> void:\n\tSaveSystem.save_group_state(%s, %s)\n" % [_quoted(group), _quoted(key)]


static func _loads_group(key: String) -> String:
	return "func _on_after_load() -> void:\n\tSaveSystem.load_group_state(%s)\n" % _quoted(key)


## The save seam on an INNER class - several sub-objects each snapshotting themselves.
static func _nested_snapshot(key: String) -> String:
	return "class Inner:\n\textends RefCounted\n\n\tfunc save_state() -> Dictionary:\n\t\treturn {\n\t\t\t%s: 1\n\t\t}\n" % _quoted(key)


static func _remembers(key: String) -> String:
	return "func _ef_store_remembered() -> void:\n\t__remember_cfg.set_value(\"vars\", %s, coins)\n" % _quoted(key)


static func _save_system_action(ace_id: String, template: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "SaveSystemAddon"
	action.ace_id = ace_id
	action.codegen_template = template
	action.params = params
	return action


static func _severity_count(findings: Array[Dictionary], severity: String) -> int:
	var total: int = 0
	for finding: Dictionary in findings:
		if str(finding.get("severity")) == severity:
			total += 1
	return total


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] save_key_symmetry_test: %s" % label)
		return true
	print("[FAIL] save_key_symmetry_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
