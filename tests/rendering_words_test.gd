# The rendering words: drawing order, the frame that ran long, and quality as a folder.
#
# Three claims are held to account here, one per family of row this file covers.
#
#   DRAWING ORDER is relative. `z_index = other.z_index + 1` is the one z_index line whose meaning is
#   a sentence rather than a number, and a visibility layer is a set of the PROJECT's own names. Both
#   are pinned twice over: the row writes that line, and a file that already had that line opens as
#   those words and saves back byte for byte.
#
#   THE FRAME BUDGET speaks once. Godot has no signal for a slow frame, so these are conditions - and
#   what makes them usable rather than sixty-times-a-second noise is that each carries its own run
#   counters and fires on ONE frame. The counters are what is pinned: fire on the frame the run is
#   long enough, silence after, and nothing at all out of "recovered" until something was long first.
#
#   QUALITY IS A FOLDER. The word is derived by comparing the values in force against each preset
#   file, so "Custom" cannot fall out of step, a preset deleted from the folder cannot break a save,
#   and a setting declared later belongs in every preset. Those are four separate answers and each
#   one is a value here rather than a count.
@tool
class_name RenderingWordsTest
extends RefCounted

const MODULE := preload("res://addons/eventforge/registration/modules/rendering_aces.gd")
const DEV_MODULE := preload("res://addons/eventforge/registration/modules/dev_aces.gd")

## The three rows this file is about, named rather than matched by prefix - the module also ships a
## Draw Calls expression, and a prefix would sweep it in.
const DRAW_ORDER_ROWS: Array[String] = ["RenderingDrawInFrontOf", "RenderingShowOnlyTo", "RenderingIsOnScreen"]

## A file holding both hand-written drawing-order spellings, and the same file the preview is
## photographed from - so the picture and the byte gate are about the same bytes. It is written in
## the shape the COMPILER emits (one blank line between functions), which is what lets a checked-in
## fixture round-trip at all.
const SOURCE_PATH := "res://tests/fixtures/rendering_scene_crate.gd"


static func run() -> bool:
	var ok: bool = true
	ok = _test_the_draw_order_rows() and ok
	ok = _test_the_notifier_row_compiles() and ok
	ok = _test_hand_written_lines_read_as_the_words() and ok
	ok = _test_the_file_saves_back() and ok
	ok = _test_the_frame_budget_pair() and ok
	ok = _test_quality_is_a_folder() and ok
	ok = _test_quality_membership() and ok
	return ok


## The three rows, by the code they write. A z_index set relative to another node, a visibility layer
## written as the mask the picker submits, and the on-screen question - which is a call into the
## sheet's own helper rather than a property, because Godot answers it with a node.
static func _test_the_draw_order_rows() -> bool:
	var templates: Dictionary = {}
	var hosts: Dictionary = {}
	var undescribed: PackedStringArray = PackedStringArray()
	for descriptor: ACEDescriptor in MODULE.get_descriptors():
		if not DRAW_ORDER_ROWS.has(descriptor.ace_id):
			continue
		templates[descriptor.ace_id] = descriptor.codegen_template
		hosts[descriptor.ace_id] = descriptor.node_type
		if descriptor.description.strip_edges().is_empty():
			undescribed.append(descriptor.ace_id)
		for parameter: ACEParam in descriptor.params:
			if parameter.get_param_description().strip_edges().is_empty():
				undescribed.append("%s.%s" % [descriptor.ace_id, parameter.id])
	var ok: bool = _check("the drawing-order rows write these lines", templates, {
		"RenderingDrawInFrontOf": "{target.}z_index = {other}.z_index + 1",
		"RenderingShowOnlyTo": "{target.}visibility_layer = {layers}",
		"RenderingIsOnScreen": "__on_screen_{uid}({node})"
	})
	ok = _check("the two that write a CanvasItem property are offered on one", hosts, {
		"RenderingDrawInFrontOf": "CanvasItem",
		"RenderingShowOnlyTo": "CanvasItem",
		"RenderingIsOnScreen": ""
	}) and ok
	ok = _check("every one of them, and every field, carries help", ", ".join(undescribed), "") and ok
	# The visibility field is the named-mask picker the collision layers already use, pointed at the
	# other list Godot names in Project Settings. A row that made anyone compute a bitmask would have
	# missed the whole point of the word.
	var hint: String = ""
	for descriptor: ACEDescriptor in MODULE.get_descriptors():
		if descriptor.ace_id != "RenderingShowOnlyTo":
			continue
		for parameter: ACEParam in descriptor.params:
			if parameter.id == "layers":
				hint = parameter.hint
	ok = _check("the visibility field is picked by name, never typed as a number", hint, "render_layer_2d") and ok
	return ok


## The on-screen row in a whole file: the helper it calls is emitted with it, so a sheet that uses
## the row compiles. The row also states its promise in code - a node that has no notifier gets one,
## and a node that HAS one keeps the author's own.
static func _test_the_notifier_row_compiles() -> bool:
	var member: String = ""
	for descriptor: ACEDescriptor in MODULE.get_descriptors():
		if descriptor.ace_id == "RenderingIsOnScreen":
			member = descriptor.member_template
	var ok: bool = _check("the row finds an existing notifier before making one",
		member.contains("get_node_or_null(^\"VisibleOnScreenNotifier2D\")"), true)
	ok = _check("and adds a plain child when there is none", member.contains("who.add_child("), true) and ok
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnProcess"
	var asked: ACECondition = ACECondition.new()
	asked.provider_id = "Core"
	asked.ace_id = "RenderingIsOnScreen"
	asked.codegen_template = "__on_screen_r(self)"
	asked.member_declaration = member.replace("{uid}", "r")
	row.conditions.append(asked)
	var acted: ACEAction = ACEAction.new()
	acted.provider_id = "Core"
	acted.ace_id = "RenderingShowOnlyTo"
	acted.codegen_template = "visibility_layer = 2"
	row.actions.append(acted)
	sheet.events.append(row)
	var output: String = str(SheetCompiler.compile(sheet, "user://eventforge_on_screen.gd").get("output", ""))
	var script: GDScript = GDScript.new()
	script.source_code = output
	return _check("a sheet asking whether a node is on screen compiles", script.reload(), OK) and ok


## The hand-written spellings, in the words the whole path gives them - the file opened as a sheet
## and walked row by row, so a reading that stops reaching the canvas is caught even when the grammar
## still answers on its own.
##
## The two lines take DIFFERENT roads on purpose. `z_index = other.z_index + 1` becomes the Draw In
## Front Of row, because that row reads as well as the line and is the editable one. A visibility
## layer does not: the row could only repeat the bitmask, and what a reader can act on is the name
## the PROJECT gave that layer - so the row authors and the reading speaks.
static func _test_hand_written_lines_read_as_the_words() -> bool:
	var had_layer: Variant = ProjectSettings.get_setting("layer_names/2d_render/layer_2", null)
	ProjectSettings.set_setting("layer_names/2d_render/layer_2", "minimap")
	var context: Dictionary = {"self_object": "Crate", "script_object": "Crate", "self_class": "Node2D"}
	var named: String = _joined_segments(EventSheetSentence.statement("visibility_layer = 2", context))
	var unnamed: String = _joined_segments(EventSheetSentence.statement("visibility_layer = 16", context))
	var readings: PackedStringArray = _open_and_read()
	ProjectSettings.set_setting("layer_names/2d_render/layer_2", had_layer)
	var ok: bool = _check("a visibility layer reads by the name the project gave it", named,
		"Crate ▸ Show only to \"minimap\"")
	ok = _check("and a layer the project never named keeps the number it already had", unnamed,
		"Crate ▸ Set visibility_layer to 16") and ok
	ok = _check("the opened file says both, on its own rows",
		[_has_reading(readings, "draw in front of $Player"),
			_has_reading(readings, "Show only to \"minimap\"")], [true, true]) and ok
	if not ok:
		print("  rows read: %s" % " | ".join(readings))
	return ok


## Every cell reading of the opened fixture - "object ▸ text" where the row names an object, the bare
## text otherwise.
static func _open_and_read() -> PackedStringArray:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SOURCE_PATH)
	sheet.read_only = true
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_ace_registry(EventSheetACERegistry.new())
	viewport.set_sheet(sheet)
	viewport.set_reading_mode(true)
	var readings: PackedStringArray = PackedStringArray()
	for row_data: EventRowData in _walk(viewport._root_rows, viewport):
		for span: SemanticSpan in row_data.spans:
			readings.append(span.text.strip_edges())
	viewport.free()
	return readings


## Every row in the tree, parents before children.
static func _walk(rows: Array, viewport: EventSheetViewport) -> Array:
	var found: Array = []
	for row_data: EventRowData in rows:
		viewport._row_builder._ensure_event_spans(row_data)
		found.append(row_data)
		found.append_array(_walk(row_data.children, viewport))
	return found


## Whether ANY row's reading says this. A `contains` against a "no row containing X" miss message
## would pass whether the row was there or not, which is why this answers a plain bool.
static func _has_reading(readings: PackedStringArray, needle: String) -> bool:
	for reading: String in readings:
		if reading.contains(needle):
			return true
	return false


## The promise the reading rests on: a file holding both spellings opens as a sheet and saves back
## with every byte where the author left it.
static func _test_the_file_saves_back() -> bool:
	var source: String = FileAccess.get_file_as_string(SOURCE_PATH)
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SOURCE_PATH)
	# Compiled to user://, never back over the fixture: compile(sheet, "") writes to the sheet's own
	# external source path, and a probe that rewrote the repository would be testing itself.
	var output: String = str(SheetCompiler.compile(sheet, "user://eventforge_rendering_words.gd").get("output", ""))
	return _check("the drawing-order file saves back byte for byte", output, source)


## The hysteresis pair, walked frame by frame against the real emitted helpers. What is asserted is
## the SHAPE of the answer over a run of frames - fire once, then silence - because that is the whole
## reason these exist beside the "is it slow right now" conditions that already shipped.
static func _test_the_frame_budget_pair() -> bool:
	var members: Dictionary = {}
	var templates: Dictionary = {}
	for descriptor: ACEDescriptor in DEV_MODULE.get_descriptors():
		if descriptor.ace_id == "FrameRunningLong" or descriptor.ace_id == "FrameRecovered":
			members[descriptor.ace_id] = descriptor.member_template
			templates[descriptor.ace_id] = descriptor.codegen_template
	var ok: bool = _check("the pair calls its own helper, one counter set each", templates, {
		"FrameRunningLong": "__frame_long_{uid}({ms}, {frames})",
		"FrameRecovered": "__frame_calm_{uid}({ms}, {frames})"
	})
	# Both helpers read the frame length off the engine, which a test cannot stage - so the helper is
	# compiled with that one call replaced by a value the test feeds it. Everything else about the
	# helper (the counters, the latch, the thresholds) is the real emitted code.
	var long_answers: PackedStringArray = _run_watcher(str(members.get("FrameRunningLong", "")),
		"__frame_long_w", [20.0, 20.0, 20.0, 20.0, 20.0, 5.0, 20.0, 20.0, 20.0], 16.0, 3)
	ok = _check("a long run fires once, on the frame it becomes long, and again after it breaks",
		"".join(long_answers), "..X.....X") and ok
	var calm_answers: PackedStringArray = _run_watcher(str(members.get("FrameRecovered", "")),
		"__frame_calm_w", [5.0, 5.0, 5.0, 5.0, 20.0, 5.0, 5.0, 5.0, 5.0], 12.0, 3)
	ok = _check("recovered says nothing until something was long, then fires once",
		"".join(calm_answers), ".......X.") and ok
	return ok


## Quality as a folder: the three words this repository ships, the values they stand for, and the
## label derived from what is in force. Nothing here is stored - the word is a comparison.
static func _test_quality_is_a_folder() -> bool:
	var paths: PackedStringArray = EventSheetQualityPresets.preset_paths()
	var words: PackedStringArray = PackedStringArray()
	for path: String in paths:
		words.append(EventSheetQualityPresets.word_for(path))
	var ok: bool = _check("the folder IS the list, lightest first", words,
		PackedStringArray(["Low", "Medium", "High"]))
	var medium: Dictionary = EventSheetQualityPresets.values_of("res://settings/quality/medium.tres")
	ok = _check("a preset is values over settings that already exist", medium,
		{"msaa": 2, "resolution_scale": 1.0, "debanding": true, "shadow_size": 2048}) and ok
	ok = _check("the values in force name their preset",
		EventSheetQualityPresets.word_in_force(medium), "Medium") and ok
	var nudged: Dictionary = medium.duplicate()
	nudged["msaa"] = 8
	ok = _check("nudging one setting flips the label on its own, with nothing stored",
		EventSheetQualityPresets.word_in_force(nudged), "Custom") and ok
	# A preset file deleted (or never installed) cannot break a player's setup: the values still hold,
	# and the label simply says Custom.
	ok = _check("with no preset files at all, what a player has is still theirs",
		EventSheetQualityPresets.word_in_force(medium, PackedStringArray(["res://settings/quality/gone.tres"])),
		"Custom") and ok
	return ok


## The other half of "the preset is a macro": a graphics setting declared later belongs in every
## preset file, and the difference is what the plugin fills in.
static func _test_quality_membership() -> bool:
	var declared: PackedStringArray = PackedStringArray(["msaa", "resolution_scale", "motion_blur"])
	var preset: Dictionary = {"msaa": 2, "resolution_scale": 1.0, "shadow_size": 2048}
	var ok: bool = _check("a setting declared later is what the file has not answered yet",
		EventSheetQualityPresets.missing_fields(preset, declared), PackedStringArray(["motion_blur"]))
	ok = _check("a value nothing declares is reported, never deleted",
		EventSheetQualityPresets.unknown_fields(preset, declared), PackedStringArray(["shadow_size"])) and ok
	ok = _check("filling it in takes the declared default and leaves the rest alone",
		EventSheetQualityPresets.fill_missing(preset, declared, {"motion_blur": false}),
		{"msaa": 2, "resolution_scale": 1.0, "shadow_size": 2048, "motion_blur": false}) and ok
	ok = _check("a new preset lands beside the one it copied",
		EventSheetQualityPresets.next_free_path("res://settings/quality/high.tres",
			PackedStringArray(["res://settings/quality/high.tres", "res://settings/quality/high_2.tres"])),
		"res://settings/quality/high_3.tres") and ok
	return ok


## Compiles one emitted watcher helper with its engine reading swapped for a fed value, then walks it
## over a run of frame lengths. "X" is a frame it fired on, "." one it stayed quiet on.
static func _run_watcher(member: String, function_name: String, frame_lengths: Array,
		ms: float, frames: int) -> PackedStringArray:
	var answers: PackedStringArray = PackedStringArray()
	if member.is_empty():
		return answers
	var source: String = "extends RefCounted\nvar fed: float = 0.0\n" \
		+ member.replace("{uid}", "w").replace("get_process_delta_time() * 1000.0", "fed")
	var script: GDScript = GDScript.new()
	script.source_code = source
	if script.reload() != OK:
		return PackedStringArray(["the watcher did not compile"])
	var watcher: RefCounted = script.new()
	for length: float in frame_lengths:
		watcher.set("fed", length)
		answers.append("X" if bool(watcher.call(function_name, ms, frames)) else ".")
	return answers


## One statement reading as "object ▸ sentence".
static func _joined_segments(reading: Dictionary) -> String:
	var text: String = ""
	for segment: Variant in (reading.get("segments", []) as Array):
		text += str((segment as Dictionary).get("text", ""))
	var object_label: String = str(reading.get("object", ""))
	return "%s ▸ %s" % [object_label, text.strip_edges()] if not object_label.is_empty() else text.strip_edges()


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] rendering_words_test: %s" % label)
		return true
	print("[FAIL] rendering_words_test: %s - expected %s, got %s" % [label, expected, actual])
	return false
