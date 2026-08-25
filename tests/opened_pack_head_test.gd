# Godot EventSheets - the head of an opened pack, read in the event-sheet grammar.
#
# A pack opened as a read-only preview used to spend two and a half screens before its first rule: a
# Class setup bar, a `host` variable, a Host binding bar, eleven trigger rows, forty-six variable rows
# in one flat list, and the pack's about text repeated at the END of the file as a grey wall. This
# test pins the reading that replaced them, over the REAL FPS Controller pack (a fixture cannot prove
# a lens that only fires on a file's actual shape):
#
#   1. The head bands - one per line of the file (class_name, extends, @icon, the ## block, the host
#      binding) - then ONE Include bar for what no line of the file says: that it is an addon pack,
#      its version, the class it behaves on, and how much of it read as events.
#   2. The pack's own opening comment ONCE, right under the bar, and never again at the end of it.
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

	# ── 1. The head: the file's own first lines, then the bar for what no line says ──
	var rows: Array = view.get_flat_rows()
	ok = _check("the sheet opens on the band that names it",
		_texts(_row_at(rows, 0)), "▣ | FPSController | class_name FPSController") and ok
	ok = _check("the band stack IS the head - one band per line of the file",
		_band_kinds(rows), "name | extends | icon | description | host") and ok
	ok = _check("a band states its line and echoes it",
		_texts(_band(rows, "extends")), "extends | Node | extends Node") and ok
	var include_bar: EventRowData = _row_with_uid(rows, "pack_include_bar_")
	# The identity half is gone from the bar: the name band says FPSController and the extends
	# band says Node, so what is left is what the file is as a PACKAGE. Two patterns since the feel
	# layer landed: the pack's airborne run is READ as air control, beside the look shape it claimed.
	ok = _check("the Include bar says only what no band says",
		_texts(include_bar), "⇥ | Addon Pack | v1.0.0 | behaves on a | CharacterBody3D | reads as events · 2 patterns · 2 adoptable ▸") and ok
	ok = _check("it wears the identity bar's presence",
		include_bar != null and is_equal_approx(include_bar.height_scale, 1.5), true) and ok
	ok = _check("the Host binding bar folded into it", _has_text(rows, "Host binding"), false) and ok
	ok = _check("the host variable folded into it", _has_variable_row(rows, "host"), false) and ok

	# ── 2. The description, once ──
	ok = _check("the class description is a band of the head",
		_texts(_band(rows, "description")).begins_with(
			"## | A complete first / third person character controller"), true) and ok
	var about_bar: EventRowData = _row_at(rows, 6)
	ok = _check("the file's own opening comment reads directly under the bar",
		about_bar != null and about_bar.row_type == EventRowData.RowType.COMMENT, true) and ok
	ok = _check("it is the pack's own about text",
		about_bar != null and _texts(about_bar).begins_with("FPS/TPS controller behavior: mouse look"), true) and ok
	ok = _check("and it is not repeated at the end of the file", _count_about_rows(rows), 1) and ok

	# ── 3. The group bars, in file order, closed ──
	ok = _check("the head bars read in file order",
		_head_bar_titles(rows),
		"Triggers | AI Driver | Camera | Crouch & Slide | Jump | Look | Movement | Wall Tech | Weapon Feel | Instance variables") and ok
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
	var internal_bar: EventRowData = _bar_titled(rows, "Instance variables")
	ok = _check("the one variable folder gathers what the groups did not",
		_texts(internal_bar), "Instance variables | of FPSController") and ok
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
		"x | Instance | number | jump_velocity | ⚙ | = | 4.5 | Upward velocity applied on a jump (and on a wall jump). | @export var jump_velocity: float = 4.5") and ok
	ok = _check("a knob keeps its LocalVariable (the row is a lens, not a copy)",
		knob != null and knob.source_resource is LocalVariable, true) and ok
	ok = _check("the @export pill is gone from the row (a sliders mark says it instead)",
		_span_texts(knob).has("@export"), false) and ok

	# ── 5. Covenant: the preview is a pure view ──
	var reemitted: String = str(SheetCompiler.compile(sheet, PACK_PATH).get("output", ""))
	ok = _check("the pack still re-emits byte-identically", reemitted == source, true) and ok

	# ── A verb reads as a trigger: its name in the condition lane, its first step beside it ──
	var verb_header: EventRowData = _verb_row(rows, "define_fn_add_look")
	ok = _check("a verb reads as the trigger it is, with its first step beside it",
		_texts(verb_header), "ƒ | On Add Look | x | y | Set yaw to wrapf(yaw - x * Mouse Sensitivity, -180, 180) | Set pitch to pitch - y * Mouse Sensitivity kept between Pitch Min and Pitch Max | Sway reads the RAW look delta: a weapon lags behind how far the hands moved. | Set sway x to x | Set sway y to y") and ok
	ok = _check("a verb with a step in its right lane is an ordinary two-lane event",
		verb_header != null and not verb_header.full_width_lanes, true) and ok
	# A verb whose first step asks a question of its own keeps that step as a row - only a step that
	# is pure right-lane content folds up beside the name - and with nothing on the right the chips
	# still get the whole row rather than being squeezed into the condition track.
	var guarded_verb: EventRowData = _verb_row(rows, "define_fn_do_jump")
	ok = _check("a verb whose first step has a condition keeps that step as its own row",
		_texts(guarded_verb), "ƒ | On Jump") and ok
	ok = _check("a verb with an empty right lane still spans both lanes",
		guarded_verb != null and guarded_verb.full_width_lanes, true) and ok
	var canvas_width: float = 1152.0
	var style_tokens: EventSheetEventStyle = view.get_event_style()
	ok = _check("its chips get the whole row's width",
		ViewportRowMetrics.condition_right_limit(
			guarded_verb, canvas_width, view.get_lane_divider_x(canvas_width), float(style_tokens.condition_lane_padding)
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
	var bar: EventRowData = _row_with_uid(view.get_flat_rows(), "pack_include_bar_")
	ok = _check("a plain script still gets the Include bar", bar != null, true) and ok
	# And it does not wear the word "Script" either. Its name and its class are the head bands'
	# to say, so all the bar owes a plain script is how much of it read as events.
	ok = _check("but it is not called an Addon Pack", _texts(bar), "⇥ | reads as events") and ok
	ok = _check("the bands name it instead", _texts(_row_at(view.get_flat_rows(), 0)),
		"▣ | Patrol | class_name Patrol") and ok
	ok = _check("its exported knob lands in the one variable folder",
		_texts(_bar_titled(view.get_flat_rows(), "Instance variables")), "Instance variables | of Patrol") and ok
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
	ok = _check("its head bands are still there", _has_uid_prefix(rows, "sheet_head_"), true) and ok
	ok = _check("its knobs are still rows of their own", _has_variable_row(rows, "jump_velocity"), true) and ok
	view.free()
	return ok


static func _row_at(rows: Array, index: int) -> EventRowData:
	return (rows[index] as Dictionary).get("row") if index < rows.size() else null


## The first row whose uid opens with `prefix`, or null.
static func _row_with_uid(rows: Array, prefix: String) -> EventRowData:
	for entry: Variant in rows:
		var row_data: EventRowData = (entry as Dictionary).get("row")
		if row_data != null and row_data.row_uid.begins_with(prefix):
			return row_data
	return null


## One head band by its kind, or null - `_band(rows, "extends")`.
static func _band(rows: Array, kind: String) -> EventRowData:
	return _row_with_uid(rows, "sheet_head_%s_" % kind)


## The head band stack in reading order, by kind: "name | extends | icon | description | host".
static func _band_kinds(rows: Array) -> String:
	var kinds: PackedStringArray = PackedStringArray()
	for entry: Variant in rows:
		var row_data: EventRowData = (entry as Dictionary).get("row")
		if row_data == null or not row_data.row_uid.begins_with("sheet_head_"):
			continue
		var tail: String = row_data.row_uid.trim_prefix("sheet_head_")
		kinds.append(tail.substr(0, tail.rfind("_")))
	return " | ".join(kinds)


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


## Every span's text as a list - for asking whether the row carries one exact word, which a joined
## line cannot answer once a span holds a whole declaration.
static func _span_texts(row_data: EventRowData) -> PackedStringArray:
	var parts: PackedStringArray = PackedStringArray()
	if row_data == null:
		return parts
	for span: SemanticSpan in row_data.spans:
		parts.append(str(span.text))
	return parts
