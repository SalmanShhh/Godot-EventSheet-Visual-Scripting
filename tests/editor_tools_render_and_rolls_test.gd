# EventForge - the two heavy Editor Tools chores: Render Scene To Image + Preview Table Rolls.
#
# Render Scene To Image is pinned by the VALUES it emits (a display probe before anything else, an
# off-screen SubViewport at the asked-for size, a settle frame, a drawn frame, save_png, and the
# viewport freed again) plus the honest-degradation rule: on a run with no display the emitted code
# must WARN and write nothing, never save a blank image or crash on a null texture. It cannot be
# runtime-proven here - a headless suite has no renderer, which is exactly what the branch is for.
#
# Preview Table Rolls IS runtime-proven: the emitted statements are written to a real script, loaded,
# and run over three table shapes (a plain value->weight Dictionary, a resource whose `entries` use
# the `value` key like RandomTableResource, and one using `item` like LootTableResource). Tables whose
# weights force the outcome give EXACT percentages to assert; the weighted table pins the
# weight-implied column exactly and pins that the same seed reproduces the report byte for byte.
@tool
class_name EditorToolsRenderAndRollsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const CODEGEN := preload("res://addons/eventforge/compiler/action_codegen.gd")
const TEMP_DIR := "user://eventforge_table_rolls_test"

## Every probe run gets its own script path: load() caches by path, so reusing one filename would
## silently re-run the FIRST probe for every later table.
static var _probe_index: int = 0


static func run() -> bool:
	var ok: bool = true
	var descriptors: Dictionary = _descriptors_by_id()

	# ── 1. Render Scene To Image: the emitted values ──
	ok = _check("Render Scene To Image is registered", descriptors.has("RenderSceneToImage"), true) and ok
	if descriptors.has("RenderSceneToImage"):
		var render: ACEDescriptor = descriptors["RenderSceneToImage"]
		ok = _check("Render Scene To Image is an Editor Tools action", "%s/%d" % [render.category, render.ace_type],
			"Editor Tools/%d" % ACEDescriptor.ACEType.ACTION) and ok
		ok = _check("its scene param opens the scene picker", _param_hint(render, "scene_path"), "scene_path") and ok
		var emitted: String = CODEGEN._apply_template(render.codegen_template, {
			"uid": "7", "scene_path": "\"res://enemy.tscn\"", "width": "320", "height": "240",
			"save_path": "\"res://art/enemy_thumb.png\"",
		})
		for expected_line: String in [
			"var __shot_7: PackedScene = (load(\"res://enemy.tscn\") as PackedScene) if ResourceLoader.exists(\"res://enemy.tscn\") else null",
			"if DisplayServer.get_name() == \"headless\":",
			"\t__shot_view_7.size = Vector2i(int(320), int(240))",
			"\t__shot_view_7.render_target_update_mode = SubViewport.UPDATE_ALWAYS",
			"\tEditorInterface.get_base_control().add_child(__shot_view_7)",
			"\t__shot_view_7.add_child(__shot_7.instantiate())",
			"\tawait __shot_view_7.get_tree().process_frame",
			"\tawait RenderingServer.frame_post_draw",
			"\t__shot_view_7.get_texture().get_image().save_png(\"res://art/enemy_thumb.png\")",
			"\t__shot_view_7.queue_free()",
		]:
			ok = _check("emits %s" % expected_line.strip_edges(), emitted.contains(expected_line), true) and ok
		# Honest degradation: the display probe leads, and its branch only warns - no save, no viewport.
		var headless_branch: String = emitted.substr(emitted.find("if DisplayServer"), emitted.find("elif") - emitted.find("if DisplayServer"))
		ok = _check("the headless branch warns", headless_branch.contains("push_warning("), true) and ok
		ok = _check("the headless branch saves nothing", headless_branch.contains("save_png"), false) and ok
		ok = _check("the headless branch builds no viewport", headless_branch.contains("SubViewport.new()"), false) and ok
		ok = _check("the headless warning names the windowed editor", headless_branch.contains("windowed editor"), true) and ok
		ok = _check("emission bakes no random value", render.codegen_template.contains("randi"), false) and ok
		ok = _check("emission bakes no clock reading", render.codegen_template.contains("Time."), false) and ok

	# ── 2. Preview Table Rolls: the descriptor ──
	ok = _check("Preview Table Rolls is registered", descriptors.has("PreviewTableRolls"), true) and ok
	if not descriptors.has("PreviewTableRolls"):
		return ok
	var rolls: ACEDescriptor = descriptors["PreviewTableRolls"]
	ok = _check("Preview Table Rolls is an Editor Tools action", "%s/%d" % [rolls.category, rolls.ace_type],
		"Editor Tools/%d" % ACEDescriptor.ACEType.ACTION) and ok
	ok = _check("it defaults to 1000 rolls", _param_default(rolls, "rolls"), "1000") and ok
	ok = _check("it defaults to printing only (empty save path)", _param_default(rolls, "save_path"), "\"\"") and ok
	ok = _check("it seeds its own generator", rolls.codegen_template.contains("RandomNumberGenerator.new()"), true) and ok

	# ── 3. Preview Table Rolls, run for real ──
	DirAccess.make_dir_recursive_absolute(TEMP_DIR)

	# 3a. A plain value->weight Dictionary where one entry cannot lose: exact percentages.
	var forced: String = _run_preview(rolls, "{\"only\": 1.0, \"never\": 0.0}", "10", "7", "")
	ok = _check("a forced Dictionary table reports exactly", forced, "\n".join(PackedStringArray([
		"Table roll preview - 10 rolls, seed 7",
		"entry | rolled | expected | delta",
		"only | 100.00% | 100.00% | +0.00%",
		"never | 0.00% | 0.00% | +0.00%",
	]))) and ok

	# 3b. The RandomTableResource shape (`entries` of {value, weight}), also forced.
	var value_table: String = _table_resource_expression("value", [["gold", 2.0], ["gem", 0.0]])
	var value_report: String = _run_preview(rolls, value_table, "5", "3", "")
	ok = _check("a value-keyed resource table reports exactly", value_report, "\n".join(PackedStringArray([
		"Table roll preview - 5 rolls, seed 3",
		"entry | rolled | expected | delta",
		"gold | 100.00% | 100.00% | +0.00%",
		"gem | 0.00% | 0.00% | +0.00%",
	]))) and ok

	# 3c. The LootTableResource shape (`entries` of {item, weight, tags}), genuinely weighted 3:1.
	var item_table: String = _table_resource_expression("item", [["sword", 3.0], ["shield", 1.0]])
	var weighted: String = _run_preview(rolls, item_table, "10000", "99", "")
	var sword_line: String = weighted.split("\n")[2]
	var shield_line: String = weighted.split("\n")[3]
	ok = _check("the sword entry is named from its item key", sword_line.begins_with("sword | "), true) and ok
	ok = _check("the shield entry is named from its item key", shield_line.begins_with("shield | "), true) and ok
	ok = _check("3:1 weights imply 75.00% expected", sword_line.split(" | ")[2], "75.00%") and ok
	ok = _check("3:1 weights imply 25.00% expected", shield_line.split(" | ")[2], "25.00%") and ok
	var rolled_sword: float = _rolled_percent(sword_line)
	var rolled_shield: float = _rolled_percent(shield_line)
	ok = _check("the rolled percentages account for every roll", snappedf(rolled_sword + rolled_shield, 0.01), 100.0) and ok
	ok = _check("10000 rolls land the 3:1 split within 3 points", absf(rolled_sword - 75.0) < 3.0, true) and ok
	ok = _check("the delta column is rolled minus expected",
		absf(float(sword_line.split(" | ")[3].trim_suffix("%")) - (rolled_sword - 75.0)) <= 0.01, true) and ok
	# Reproducible: same seed, same report, byte for byte.
	ok = _check("the same seed reproduces the report", _run_preview(rolls, item_table, "10000", "99", ""), weighted) and ok
	ok = _check("a different seed moves the rolled numbers", _run_preview(rolls, item_table, "10000", "100", "") == weighted, false) and ok

	# 3d. An empty table says so instead of dividing by zero.
	var empty_report: String = _run_preview(rolls, "{}", "50", "1", "")
	ok = _check("an empty table reports the reason", empty_report, "\n".join(PackedStringArray([
		"Table roll preview - 50 rolls, seed 1",
		"(no entry has a weight above zero - nothing to roll)",
	]))) and ok

	# 3e. A path that is not there NAMES itself, instead of throwing an engine load error or reading
	# like a table that is merely unweighted - the two failures look identical until the report says so.
	var missing_report: String = _run_preview(rolls, "\"res://no_such_table_at_all.tres\"", "20", "2", "")
	ok = _check("a missing table path names the path it could not find", missing_report, "\n".join(PackedStringArray([
		"Table roll preview - 20 rolls, seed 2",
		"(no table at res://no_such_table_at_all.tres - nothing to roll)",
	]))) and ok
	ok = _check("which is not the empty-table wording", missing_report.contains("no entry has a weight above zero"), false) and ok

	# 3f. A save path writes the same report to disk.
	var report_path: String = TEMP_DIR + "/report.txt"
	var saved_source: String = _run_preview(rolls, "{\"only\": 1.0}", "4", "5", "\"%s\"" % report_path)
	ok = _check("the report file is written", FileAccess.file_exists(report_path), true) and ok
	ok = _check("the file holds the printed report", FileAccess.get_file_as_string(report_path), saved_source + "\n") and ok

	_clear_temp_dir()
	return ok


## Runs the ACE's emitted statements for real and returns the report it printed. The statements are
## written to a script file and loaded (never a source string alone) so what runs is exactly what a
## compiled sheet would run.
static func _run_preview(descriptor: ACEDescriptor, table_expression: String, roll_count: String, table_seed: String, save_path: String) -> String:
	_probe_index += 1
	var statements: String = CODEGEN._apply_template(descriptor.codegen_template, {
		"uid": "1", "table": table_expression, "rolls": roll_count, "seed": table_seed,
		"save_path": save_path if not save_path.is_empty() else "\"\"",
	})
	var source: PackedStringArray = PackedStringArray(["@tool", "extends RefCounted", "", "", "static func go() -> String:"])
	for line: String in statements.split("\n"):
		# The ACE prints its report; the probe returns it too, so the assertions see the real text.
		source.append("\t" + line)
	source.append("\treturn \"\\n\".join(__tbl_out_1)")
	var script_path: String = TEMP_DIR + "/probe_%d.gd" % _probe_index
	var file: FileAccess = FileAccess.open(script_path, FileAccess.WRITE)
	file.store_string("\n".join(source) + "\n")
	file.close()
	var script: GDScript = load(script_path) as GDScript
	if script == null:
		return "<probe script failed to load>"
	return str(script.call("go"))


## A stand-in weighted-table resource: a script exposing the `entries` Array the shipped table
## resources export, so the ACE meets the real shape without depending on a generated pack.
static func _table_resource_expression(label_key: String, rows: Array) -> String:
	var script_path: String = TEMP_DIR + "/table_%s.gd" % label_key
	var source: PackedStringArray = PackedStringArray(["@tool", "extends Resource", "", "", "var entries: Array = ["])
	for row: Array in rows:
		source.append("\t{\"%s\": \"%s\", \"weight\": %s}," % [label_key, str(row[0]), str(row[1])])
	source.append("]")
	var file: FileAccess = FileAccess.open(script_path, FileAccess.WRITE)
	file.store_string("\n".join(source) + "\n")
	file.close()
	return "load(\"%s\").new()" % script_path


## "sword | 74.63% | 75.00% | -0.37%" -> 74.63
static func _rolled_percent(report_line: String) -> float:
	return float(report_line.split(" | ")[1].trim_suffix("%"))


static func _descriptors_by_id() -> Dictionary:
	var by_id: Dictionary = {}
	for descriptor: ACEDescriptor in EventForgeToolingACEs.get_descriptors():
		by_id[descriptor.ace_id] = descriptor
	return by_id


static func _param_hint(descriptor: ACEDescriptor, param_id: String) -> String:
	for param: ACEParam in descriptor.params:
		if param.id == param_id:
			return str(param.hint)
	return "<missing>"


static func _param_default(descriptor: ACEDescriptor, param_id: String) -> String:
	for param: ACEParam in descriptor.params:
		if param.id == param_id:
			return str(param.default_value)
	return "<missing>"


static func _clear_temp_dir() -> void:
	var dir: DirAccess = DirAccess.open(TEMP_DIR)
	if dir == null:
		return
	for entry: String in dir.get_files():
		DirAccess.remove_absolute(TEMP_DIR + "/" + entry)
	DirAccess.remove_absolute(TEMP_DIR)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("editor_tools_render_and_rolls_test", label, actual, expected)
