# Godot EventSheets - the head of an opened pack, read in the event-sheet grammar.
#
# A pack opened as a read-only preview used to spend two and a half screens before its first rule: a
# Class setup bar, a `host` variable, a Host binding bar, eleven trigger rows, forty-six variable rows
# in one flat list, and the pack's about text repeated at the END of the file as a grey wall. This
# test pins the reading that replaced them, over the REAL FPS Controller pack (a fixture cannot prove
# a lens that only fires on a file's actual shape):
#
#   1. The Include bar - the pack's identity as ONE bar, the way an event sheet opens with its
#      includes: name, version, and the class it behaves on. The three head bars it replaces are gone.
#   2. The description ONCE, as a comment bar right under it, and never again at the end of the file.
#   3. Group bars in FILE order (Triggers, then each @export_group, then Internal state), closed by
#      default on a preview, with their rows as children.
#   4. Variable rows in the reading shape: the friendly TYPE WORD leads as a chip, the @export and
#      group chips are gone (the bar carries the group), and the knob's doc comment trails it muted.
#   5. The covenant: pure view. The same sheet still re-emits byte-identically.
#
# It also pins the Function-block header fix that shipped with it: a header whose right lane is empty
# spans the WHOLE row, so its input chips are laid out against the row's right edge rather than being
# clipped at the lane divider ("y  number" drawn as "y  numb" at a narrow split).
#
# VALUES are pinned, not counts, wherever a value exists - a count would still pass if the bars said
# the wrong words in the right shape.
@tool
class_name OpenedPackHeadTest
extends RefCounted

const PACK_PATH := "res://eventsheet_addons/fps_controller/fps_controller_behavior.gd"


static func run() -> bool:
	var ok: bool = true
	var source: String = FileAccess.open(PACK_PATH, FileAccess.READ).get_as_text()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(PACK_PATH)
	sheet.read_only = true
	var view: EventSheetViewport = EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	var style := EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	view.set_sheet(sheet)
	view.set_reading_mode(true)

	# ── 1. The Include bar ──
	var rows: Array = view.get_flat_rows()
	var include_bar: EventRowData = _row_at(rows, 0)
	ok = _check("the sheet opens on the Include bar",
		include_bar != null and include_bar.row_uid.begins_with("pack_include_bar_"), true) and ok
	ok = _check("the Include bar reads as the pack's identity",
		_texts(include_bar), "⇥ | Addon Pack | FPSController | v1.0.0 | behaves on a | CharacterBody3D | reads as events") and ok
	ok = _check("it wears the identity bar's presence",
		include_bar != null and is_equal_approx(include_bar.height_scale, 1.5), true) and ok
	ok = _check("the Class setup strip folded into it", _has_uid_prefix(rows, "scaffolding_strip_"), false) and ok
	ok = _check("the Host binding bar folded into it", _has_text(rows, "Host binding"), false) and ok
	ok = _check("the host variable folded into it", _has_variable_row(rows, "host"), false) and ok

	# ── 2. The description, once ──
	var about_bar: EventRowData = _row_at(rows, 1)
	ok = _check("the description reads directly under the identity",
		about_bar != null and about_bar.row_type == EventRowData.RowType.COMMENT, true) and ok
	ok = _check("it is the pack's own about text",
		about_bar != null and _texts(about_bar).begins_with("FPS/TPS controller behavior: mouse look"), true) and ok
	ok = _check("and it is not repeated at the end of the file", _count_about_rows(rows), 1) and ok

	# ── 3. The group bars, in file order, closed ──
	ok = _check("the head bars read in file order",
		_head_bar_titles(rows),
		"Triggers | AI Driver | Camera | Crouch & Slide | Jump | Look | Movement | Wall Tech | Internal state") and ok
	var triggers_bar: EventRowData = _bar_titled(rows, "Triggers")
	ok = _check("the Triggers bar says what it holds", _texts(triggers_bar), "Triggers | this pack fires - 11") and ok
	ok = _check("its children are the pack's trigger rows", triggers_bar.children.size() if triggers_bar != null else -1, 11) and ok
	ok = _check("the first trigger reads by its published name",
		_texts(triggers_bar.children[0]) if triggers_bar != null and not triggers_bar.children.is_empty() else "",
		"➜ | On Jumped | emits jumped") and ok
	var jump_bar: EventRowData = _bar_titled(rows, "Jump")
	ok = _check("a settings bar counts its knobs", _texts(jump_bar), "Jump | 3 settings") and ok
	ok = _check("a settings bar is CLOSED on a preview", jump_bar != null and jump_bar.folded, true) and ok
	ok = _check("its knobs are hidden while it is closed", _has_variable_row(rows, "jump_velocity"), false) and ok
	var internal_bar: EventRowData = _bar_titled(rows, "Internal state")
	ok = _check("the private state reads as the pack's own",
		_texts(internal_bar), "Internal state | values the pack keeps for itself - 21") and ok
	# The grouping rule Godot itself uses: an @export_group runs until the next one, so the knobs
	# declared after it belong to it even though only the first one carries the attribute.
	var camera_bar: EventRowData = _bar_titled(rows, "Camera")
	ok = _check("an export group claims every knob declared under it", _texts(camera_bar), "Camera | 3 settings") and ok

	# ── 4. The reading shape of a knob ──
	view._fold_state[jump_bar.row_uid] = false
	view.set_sheet(sheet)
	rows = view.get_flat_rows()
	var knob: EventRowData = _variable_row(rows, "jump_velocity")
	ok = _check("a knob reads type-word, name, value, description",
		_texts(knob),
		"number | jump_velocity | = | 4.5 | Upward velocity applied on a jump (and on a wall jump).") and ok
	ok = _check("a knob keeps its LocalVariable (the row is a lens, not a copy)",
		knob != null and knob.source_resource is LocalVariable, true) and ok
	ok = _check("the @export chip is gone from the row", _texts(knob).contains("@export"), false) and ok

	# ── 5. Covenant: the preview is a pure view ──
	var reemitted: String = str(SheetCompiler.compile(sheet, PACK_PATH).get("output", ""))
	ok = _check("the pack still re-emits byte-identically", reemitted == source, true) and ok

	# ── The Function block header spans the whole row ──
	var verb_header: EventRowData = _verb_row(rows, "define_fn_add_look")
	ok = _check("a verb header reads as ƒ, its name and its inputs",
		_texts(verb_header), "ƒ | Add Look | x  number | y  number") and ok
	ok = _check("a header with an empty right lane spans both lanes",
		verb_header != null and verb_header.full_width_lanes, true) and ok
	# The chips are laid out against the ROW's right edge now, not the lane divider - at a 1152px
	# canvas the second input chip used to be clipped to a stub by the condition lane's limit.
	var canvas_width: float = 1152.0
	var style_tokens: EventSheetEventStyle = view.get_event_style()
	ok = _check("its chips get the whole row's width",
		ViewportRowMetrics.condition_right_limit(
			verb_header, canvas_width, view.get_lane_divider_x(canvas_width), float(style_tokens.condition_lane_padding)
		) > view.get_lane_divider_x(canvas_width), true) and ok
	# A row that DOES use its right lane keeps the split - the trigger rows say "emits <signal>" there.
	var trigger_row: EventRowData = triggers_bar.children[0] if triggers_bar != null and not triggers_bar.children.is_empty() else null
	ok = _check("a row with something in its right lane keeps the two lanes",
		trigger_row != null and not trigger_row.full_width_lanes, true) and ok

	ok = _test_a_plain_script_is_not_called_a_pack() and ok
	ok = _test_an_editable_sheet_keeps_its_rows() and ok
	view.free()
	return ok


## "Addon Pack" is a claim about the file. A read-only .gd with no @ace_version, living outside the
## addon folder, is a script - and must say so, or a beginner learns the wrong word for what they
## opened.
static func _test_a_plain_script_is_not_called_a_pack() -> bool:
	var ok: bool = true
	var sheet := EventSheetResource.new()
	sheet.read_only = true
	sheet.custom_class_name = "Patrol"
	var prelude := RawCodeRow.new()
	prelude.code = "class_name Patrol\nextends Node2D\n## @ace_tags(movement)"
	sheet.events.append(prelude)
	var speed := LocalVariable.new()
	speed.name = "speed"
	speed.type_name = "float"
	speed.default_value = 200.0
	speed.exported = true
	sheet.events.append(speed)
	var view := EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.set_sheet(sheet)
	var bar: EventRowData = _row_at(view.get_flat_rows(), 0)
	ok = _check("a plain script still gets the Include bar", bar != null and bar.row_uid.begins_with("pack_include_bar_"), true) and ok
	# M34 - and it does not wear the word "Script" either: the bar names the OBJECT the script drives
	# and the class it is, which is what a reader is actually looking at.
	ok = _check("but it is not called an Addon Pack", _texts(bar), "⇥ | Patrol | a | Node | reads as events") and ok
	ok = _check("its exported knob lands in the Settings bar",
		_texts(_bar_titled(view.get_flat_rows(), "Settings")), "Settings | 1 setting") and ok
	view.free()
	return ok


## The lens is the READING of a preview. An authored sheet keeps every row it always had - the
## variables you are editing must never be one fold away from the sheet you are working on.
static func _test_an_editable_sheet_keeps_its_rows() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(PACK_PATH)
	sheet.read_only = false
	var view := EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.set_sheet(sheet)
	var rows: Array = view.get_flat_rows()
	ok = _check("an editable sheet grows no Include bar", _has_uid_prefix(rows, "pack_include_bar_"), false) and ok
	ok = _check("its class setup strip is still there", _has_uid_prefix(rows, "scaffolding_strip_"), true) and ok
	ok = _check("its knobs are still rows of their own", _has_variable_row(rows, "jump_velocity"), true) and ok
	view.free()
	return ok


static func _row_at(rows: Array, index: int) -> EventRowData:
	return (rows[index] as Dictionary).get("row") if index < rows.size() else null


static func _texts(row_data: EventRowData) -> String:
	if row_data == null:
		return ""
	var parts: PackedStringArray = PackedStringArray()
	for span: SemanticSpan in row_data.spans:
		parts.append(str(span.text))
	return " | ".join(parts)


static func _has_uid_prefix(rows: Array, prefix: String) -> bool:
	for entry: Variant in rows:
		var row_data: EventRowData = (entry as Dictionary).get("row")
		if row_data != null and row_data.row_uid.begins_with(prefix):
			return true
	return false


static func _has_text(rows: Array, needle: String) -> bool:
	for entry: Variant in rows:
		var row_data: EventRowData = (entry as Dictionary).get("row")
		if row_data != null and _texts(row_data).contains(needle):
			return true
	return false


static func _variable_row(rows: Array, var_name: String) -> EventRowData:
	for entry: Variant in rows:
		var row_data: EventRowData = (entry as Dictionary).get("row")
		if row_data == null or not (row_data.source_resource is LocalVariable):
			continue
		if (row_data.source_resource as LocalVariable).name == var_name:
			return row_data
	return null


static func _has_variable_row(rows: Array, var_name: String) -> bool:
	return _variable_row(rows, var_name) != null


static func _verb_row(rows: Array, uid: String) -> EventRowData:
	for entry: Variant in rows:
		var row_data: EventRowData = (entry as Dictionary).get("row")
		if row_data != null and row_data.row_uid == uid:
			return row_data
	return null


## The synthetic head bars, in the order they read - the reading order this whole lens exists for.
static func _head_bar_titles(rows: Array) -> String:
	var titles: PackedStringArray = PackedStringArray()
	for entry: Variant in rows:
		var row_data: EventRowData = (entry as Dictionary).get("row")
		if row_data == null:
			continue
		if row_data.row_uid.begins_with("pack_triggers") or row_data.row_uid.begins_with("pack_settings_") \
				or row_data.row_uid.begins_with("pack_internal_state"):
			titles.append(str(row_data.spans[0].text))
	return " | ".join(titles)


static func _bar_titled(rows: Array, title: String) -> EventRowData:
	for entry: Variant in rows:
		var row_data: EventRowData = (entry as Dictionary).get("row")
		if row_data == null or row_data.spans.is_empty():
			continue
		if row_data.row_type == EventRowData.RowType.GROUP and str(row_data.spans[0].text) == title:
			return row_data
	return null


## How many rows carry the pack's about text - the duplication this lens removed.
static func _count_about_rows(rows: Array) -> int:
	var found: int = 0
	for entry: Variant in rows:
		var row_data: EventRowData = (entry as Dictionary).get("row")
		if row_data != null and row_data.row_type == EventRowData.RowType.COMMENT \
				and _texts(row_data).contains("FPS/TPS controller behavior"):
			found += 1
	return found


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] opened_pack_head_test: %s" % label)
		return true
	print("[FAIL] opened_pack_head_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
