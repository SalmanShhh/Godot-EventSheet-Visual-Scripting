@tool
extends RefCounted
# Godot EventSheets - the compiler's "__" bookkeeping inside events
#
# A theme that states fold_compiler_helpers stops showing the compiler's two-underscore names inside
# events: a `__` local holding a fresh copy of a scene is named by its scene file in the object column,
# the line that puts it in the tree reads "Spawn <scene>", the local's own row folds into that one, and
# a row that only keeps a hidden `__` member up to date folds away unless it is all the event does.
# Pinned as values, on the real platformer_shooter showcase:
#   1. the token: off by default, on in the Editor Native starter and its rule, stated off in every
#      other shipped theme;
#   2. the rows the builder makes under Editor Native, word for word;
#   3. the same rows under Classic Sheet, exactly as before;
#   4. an event whose whole content is the upkeep keeps it;
#   5. the file still opens and saves byte for byte;
#   6. a For Each's own "__" name reads as what it walks, under the starter and under the rule a
#      derived Native theme is built by alike, while Classic keeps it and a name the author wrote
#      reads exactly as written.

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "native_compiler_helpers_test"
const SHOWCASE := "res://demo/showcase/platformer_shooter/platformer_shooter.gd"
const NATIVE_THEME := "res://addons/eventsheet/themes/editor_native_theme.tres"
const CLASSIC_THEME := "res://addons/eventsheet/themes/classic_sheet_theme.tres"
const OTHER_THEMES := [
	"res://addons/eventsheet/themes/classic_sheet_theme.tres",
	"res://addons/eventsheet/themes/mockup_slate_theme.tres",
	"res://demo/themes/catppuccin_mocha_theme.tres",
	"res://demo/themes/designer_template_theme.tres",
	"res://demo/themes/dracula_theme.tres",
	"res://demo/themes/gruvbox_dark_theme.tres",
	"res://demo/themes/high_contrast_theme.tres",
	"res://demo/themes/monokai_theme.tres",
	"res://demo/themes/nord_theme.tres",
	"res://demo/themes/soft_light_theme.tres",
	"res://demo/themes/solarized_light_theme.tres",
]


static func run() -> bool:
	var ok: bool = true
	ok = _test_token() and ok
	ok = _test_native_rows() and ok
	ok = _test_classic_rows_unchanged() and ok
	ok = _test_upkeep_alone_stays() and ok
	ok = _test_round_trip() and ok
	ok = _test_loop_names() and ok
	return ok


static func _test_token() -> bool:
	var native: EventSheetEventStyle = (load(NATIVE_THEME) as EventSheetEditorStyle).get_event_style()
	var built: EventSheetEventStyle = EventSheetEditorThemeDeriver.native_style(
		EventSheetEditorThemeDeriver.NATIVE_DARK_REFERENCE_BASE).get_event_style()
	var others: Array = []
	var expected_others: Array = []
	for path: String in OTHER_THEMES:
		var style: EventSheetEditorStyle = load(path) as EventSheetEditorStyle
		others.append([path.get_file(), style.get_event_style().fold_compiler_helpers,
			FileAccess.get_file_as_string(path).contains("fold_compiler_helpers = false")])
		expected_others.append([path.get_file(), false, true])
	return SUPPORT.pins(TEST_NAME, [
		["the token defaults off", EventSheetEventStyle.new().fold_compiler_helpers, false],
		["the starter states it on", native.fold_compiler_helpers, true],
		["and so does the rule it is built by", built.fold_compiler_helpers, true],
		["every other shipped theme states it off", others, expected_others],
	])


static func _test_native_rows() -> bool:
	var viewport: EventSheetViewport = _viewport_for(_shooter(), NATIVE_THEME)
	var rows: Dictionary = _event_lines(viewport)
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["the fire event names its copy by the scene", rows.get("fire", []), [
			"[Weapon] Fire",
			"[shot.tscn] Set position to $Player.position + (32 * $Player/PlatformerMovement.facing_direction(), -6)",
		]],
		["the line that adds it is the Spawn", rows.get("fire_plant", []), ["[System] Spawn shot.tscn"]],
		["and so is each arm of the angle", rows.get("fire_arms", []),
			["[shot.tscn] Set angle to 0", "[shot.tscn] Set angle to 180"]],
		["its sub-event names the parent's copy", rows.get("shots_group", []), ["[shot.tscn] Add to group \"shots\""]],
		["the clock's upkeep folds away beside the clamp", rows.get("clamp", []),
			["[System] Keep $Player.position.x between 40.0 and 1112.0"]],
		["and its wrap beside the spawn", rows.get("timer", []), [
			"[target.tscn] Set position to (1240, random number 120 to 540)",
			"[target.tscn] Set angle to 180",
			"[System] Spawn target.tscn",
		]],
		["the second spawn's sub-event names its own scene", rows.get("targets_group", []),
			["[target.tscn] Add to group \"targets\""]],
		["no Local row is left for a copy", rows.get("locals", []), []],
		["no __ name is left in an action", rows.get("underscored", []), []],
	])
	viewport.free()
	return ok


static func _test_classic_rows_unchanged() -> bool:
	var viewport: EventSheetViewport = _viewport_for(_shooter(), CLASSIC_THEME)
	var rows: Dictionary = _event_lines(viewport)
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["classic: the copy keeps its local's name", rows.get("fire", []), [
			"[PlatformerShooter] Weapon  Fire",
			"[__spawn_shot] Set position to $Player.position + (32 * $Player/PlatformerMovement.facing_direction(), -6)",
		]],
		["classic: the plant reads as the file writes it", rows.get("fire_plant", []), ["[System] add child __spawn_shot"]],
		["classic: the upkeep is listed", rows.get("clamp", []), [
			"[System] Keep $Player.position.x between 40.0 and 1112.0",
			"[System] Add dt to __every_ps_spawn",
		]],
		["classic: both Local rows are drawn", (rows.get("locals", []) as Array).size(), 2],
	])
	viewport.free()
	return ok


static func _test_upkeep_alone_stays() -> bool:
	var sheet: EventSheetResource = SUPPORT.reopen("extends Node2D\n\nvar __every_x: float = 0.0\n\n"
		+ "func _process(delta: float) -> void:\n\t__every_x += delta\n")
	var viewport: EventSheetViewport = _viewport_for(sheet, NATIVE_THEME)
	var actions: Array = []
	for index: int in range(viewport._flat_rows.size()):
		var row: EventRowData = viewport._row_at(index)
		if row != null and row.source_resource is EventRow:
			viewport._row_builder._ensure_event_spans(row)
			actions.append_array(_lane_words(row, "action"))
	viewport.free()
	return SUPPORT.pins(TEST_NAME, [
		["an event that only keeps the clock keeps its row", actions, ["[System] Add dt to __every_x"]],
	])


static func _test_round_trip() -> bool:
	var source: String = FileAccess.get_file_as_string(SHOWCASE)
	return SUPPORT.pins(TEST_NAME, [
		["the showcase still opens and saves byte for byte", SUPPORT.reemit(source, SHOWCASE) == source, true],
	])


static func _shooter() -> EventSheetResource:
	return GDScriptImporter.new().import_external(SHOWCASE)


static func _viewport_for(sheet: EventSheetResource, theme_path: String) -> EventSheetViewport:
	return _viewport_with(sheet, (load(theme_path) as EventSheetEditorStyle).duplicate(true))


static func _viewport_with(sheet: EventSheetResource, style: EventSheetEditorStyle) -> EventSheetViewport:
	sheet.editor_style = style
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_ace_registry(EventSheetACERegistry.new())
	viewport.set_sheet(sheet)
	return viewport


## The rows these pins read, by what they are: each one's action words as "[object] words".
static func _event_lines(viewport: EventSheetViewport) -> Dictionary:
	var found: Dictionary = {"locals": [], "underscored": [], "fire_arms": []}
	for index: int in range(viewport._flat_rows.size()):
		var row: EventRowData = viewport._row_at(index)
		if row == null:
			continue
		if row.row_uid.begins_with("local_declaration_"):
			(found["locals"] as Array).append(row.row_uid)
			continue
		if not (row.source_resource is EventRow):
			continue
		viewport._row_builder._ensure_event_spans(row)
		var actions: Array = _lane_words(row, "action")
		var conditions: Array = _lane_words(row, "condition")
		for line: Variant in actions:
			if str(line).contains("__spawn") or str(line).contains("__every"):
				(found["underscored"] as Array).append(line)
		var said: String = " ".join(conditions)
		if row.row_uid.contains("_branch_") and not found.has("fire_plant") and found.has("fire"):
			(found["fire_arms"] as Array).append_array(actions)
		elif row.row_uid.contains("_after") and found.has("fire") and not found.has("fire_plant"):
			found["fire_plant"] = actions
		elif said.contains("\"ui_accept\" is down"):
			found["fire"] = actions
		elif said.contains("\"shots\" ≠"):
			found["shots_group"] = actions
		elif said.contains("\"targets\" ≠"):
			found["targets_group"] = actions
		elif said.contains("Every 1.5 seconds"):
			found["timer"] = actions
		elif not found.has("clamp") and actions.size() > 0 and str(actions[0]).contains("Keep $Player.position.x"):
			found["clamp"] = actions
	return found


## One lane's cells as "[object] words", in order, without the add lines.
static func _lane_words(row: EventRowData, lane: String) -> Array:
	var words: Array = []
	for span: SemanticSpan in row.spans:
		if span == null or not (span.metadata is Dictionary):
			continue
		var meta: Dictionary = span.metadata
		if str(meta.get("lane", "")) != lane or str(meta.get("kind", "")).begins_with("add_"):
			continue
		if span.text.begins_with("+ Add") or span.text.begins_with("⟡"):
			continue
		var label: String = str(meta.get("object_label", ""))
		words.append(("[%s] %s" % [label, span.text]) if not label.is_empty() else span.text)
	return words


static func _test_loop_names() -> bool:
	var expected: Array = [
		"[System] Every tick (physics) | [shots] For each shots",
		"[targets] For each targets",
		"[System] shots still exists | [System] targets still exists | [shots] is within 42 of targets.global_position"
			+ " || [shots] Destroy | [targets] Destroy | [System] Add 1 to score | [System] Stop loop",
		"[System] Every tick (physics) | [shots/targets] For each shots/targets",
		"[System] shots/targets.global_position.x < -60 | [System] shots/targets.global_position.x > 1300"
			+ " || [shots/targets] Destroy",
	]
	var starter: EventSheetViewport = _viewport_for(_shooter(), NATIVE_THEME)
	var native_loops: Array = _loop_lines(starter)
	starter.free()
	var derived: EventSheetViewport = _viewport_with(_shooter(), EventSheetEditorThemeDeriver.native_style(
		EventSheetEditorThemeDeriver.NATIVE_DARK_REFERENCE_BASE))
	var derived_loops: Array = _loop_lines(derived)
	derived.free()
	var classic: EventSheetViewport = _viewport_for(_shooter(), CLASSIC_THEME)
	var classic_loops: Array = _loop_lines(classic)
	classic.free()
	var written: EventSheetResource = SUPPORT.reopen("extends Node2D

"
		+ "func _physics_process(_delta: float) -> void:
"
		+ "	for shot in get_tree().get_nodes_in_group(\"shots\"):
"
		+ "		if shot.global_position.x < -60.0:
			shot.queue_free()
")
	var authored: EventSheetViewport = _viewport_for(written, NATIVE_THEME)
	var authored_loops: Array = _loop_lines(authored)
	authored.free()
	var family_sheet: EventSheetResource = SUPPORT.reopen("extends Node2D

"
		+ "func _physics_process(_delta: float) -> void:
"
		+ "	for __each in get_tree().get_nodes_in_group(\"family_enemy\"):
"
		+ "		if __each.global_position.x < -60.0:
			__each.queue_free()
")
	var family: EventSheetViewport = _viewport_for(family_sheet, NATIVE_THEME)
	var family_loops: Array = _loop_lines(family)
	family.free()
	return SUPPORT.pins(TEST_NAME, [
		["native: each loop name reads as what it walks", native_loops, expected],
		["a derived Native theme reads the same", derived_loops, expected],
		["classic: the loop names read as the file writes them", classic_loops, [
			"⟳ | [System] Every tick (physics) | [System] For each __shot in get_tree().get_nodes_in_group(\"shots\")",
			"[System] For each __target in get_tree().get_nodes_in_group(\"targets\")",
			"[System] __shot still exists | [System] __target still exists | [__shot] is within 42 of __target.global_position"
				+ " || [__shot] Destroy | [__target] Destroy | [System] Add 1 to score | [System] Stop loop",
			"⟳ | [System] Every tick (physics) | [System] For each __node in get_tree().get_nodes_in_group(\"shots\")"
				+ " + get_tree().get_nodes_in_group(\"targets\")",
			"[System] __node.global_position.x < -60 | [System] __node.global_position.x > 1300 || [__node] Destroy",
		]],
		["a loop name the author wrote reads exactly as written", authored_loops, [
			"[System] Every tick (physics) | [System] For each shot in get_tree().get_nodes_in_group(\"shots\")",
			"[System] shot.global_position.x < -60 || [shot] Destroy",
		]],
		["a walk over a family's group reads as the family", family_loops, [
			"[System] Every tick (physics) | [Enemy] For each Enemy",
			"[System] Enemy.global_position.x < -60 || [Enemy] Destroy",
		]],
	])


## The rows from the first loop on, each as "conditions || actions" in "[object] words".
static func _loop_lines(viewport: EventSheetViewport) -> Array:
	var lines: Array = []
	var started: bool = false
	for index: int in range(viewport._flat_rows.size()):
		var row: EventRowData = viewport._row_at(index)
		if row == null or not (row.source_resource is EventRow):
			continue
		viewport._row_builder._ensure_event_spans(row)
		var conditions: Array = _lane_words(row, "condition")
		var said: String = " | ".join(conditions)
		if not started and not said.contains("For each"):
			continue
		if started and (said.contains("is reloading") or said.contains("Else")):
			break
		started = true
		var actions: Array = _lane_words(row, "action")
		lines.append(said if actions.is_empty() else "%s || %s" % [said, " | ".join(actions)])
	return lines
