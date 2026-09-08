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

const SUPPORT := preload("res://tests/support.gd")
const PACK_PATH := "res://eventsheet_addons/fps_controller/fps_controller_behavior.gd"


static func run() -> bool:
	# These assertions pin verb headers WITHOUT "called by" chips, which is what a cold share
	# index renders. Several earlier tests legitimately build that index (the effects Doctor,
	# the lighting facts, the callers question all do), so the precondition is established
	# here rather than hoped for - in one serial process, hope reads someone else's cache.
	EventSheetProjectShareIndex.clear_cache()
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

	# ── 1. The head: ONE bar, and the file's own first lines folded under it ──
	var rows: Array = _all_rows(view)
	ok = _check("the sheet opens on ONE head bar",
		_texts(_row_at(rows, 0)),
		"▣ | FPSController | extends | Node | · reads as events | · 5 input actions") and ok
	ok = _check("the bands are the bar's fold - one band per line of the file",
		_band_kinds(rows), "name | extends | icon | host") and ok
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
	# The `##` block is a COMMENT ROW at the top of the sheet, not a band. As a band it drew its
	# value and its echo of the same line over each other, and this pack's own about-comment said
	# the sentence a second time; one row says it now, and the band that used to is gone.
	var about_bar: EventRowData = _row_with_uid(rows, "head_description_row_")
	ok = _check("the class description is a comment row, not a band",
		about_bar != null and about_bar.row_type == EventRowData.RowType.COMMENT, true) and ok
	ok = _check("it is the file's own \u0023\u0023 block",
		_texts(about_bar).begins_with("A complete first / third person character controller"), true) and ok
	ok = _check("the description band is gone", _band(rows, "description") == null, true) and ok
	ok = _check("and the pack's about text is not hoisted on top of it", _count_about_rows(rows), 1) and ok

	# ── 3. The group bars, in file order, closed ──
	ok = _check("the head bars read in file order, the folded ones first",
		_head_bar_titles(rows),
		"AI Driver | Camera | Crouch & Slide | Jump | Look | Movement | Wall Tech | Weapon Feel | Internal state") and ok
	# A pack's triggers ARE part of the vocabulary it publishes - the picker lists them beside its
	# actions - so they close the Verbs band rather than standing in a folder of their own.
	var verbs_bar: EventRowData = _bar_titled(rows, "Verbs")
	ok = _check("the pack's vocabulary reads under one Verbs bar", _texts(verbs_bar), "Verbs | 49 verbs") and ok
	var trigger_rows: Array = _trigger_children(verbs_bar)
	ok = _check("the triggers it fires close that band", trigger_rows.size(), 11) and ok
	ok = _check("the first trigger reads by its published name, and says what fires it",
		_texts(trigger_rows[0]) if not trigger_rows.is_empty() else "",
		"➜ | On Jumped | emits jumped | fired by Jump") and ok
	var jump_bar: EventRowData = _bar_titled(rows, "Jump")
	ok = _check("a settings bar counts its knobs", _texts(jump_bar), "Jump | 3 settings") and ok
	ok = _check("a settings bar is CLOSED on a preview", jump_bar != null and jump_bar.folded, true) and ok
	ok = _check("its knobs are hidden while it is closed",
		_has_variable_row(view.get_flat_rows(), "jump_velocity"), false) and ok
	var internal_bar: EventRowData = _bar_titled(rows, "Internal state")
	ok = _check("what the settings groups did not claim is the pack's internal state",
		_texts(internal_bar), "Internal state | 72") and ok
	# The grouping rule Godot itself uses: an @export_group runs until the next one, so the knobs
	# declared after it belong to it even though only the first one carries the attribute.
	var camera_bar: EventRowData = _bar_titled(rows, "Camera")
	ok = _check("an export group claims every knob declared under it", _texts(camera_bar), "Camera | 3 settings") and ok

	# ── 4. The reading shape of a knob ──
	view._fold_state[jump_bar.row_uid] = false
	view.set_sheet(sheet)
	rows = _all_rows(view)
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
		_texts(verb_header), "ƒ | Add Look | x | y | action | Set yaw to wrapf(yaw - x * Mouse Sensitivity, -180, 180) | Set pitch to pitch - y * Mouse Sensitivity kept between Pitch Min and Pitch Max | Sway reads the RAW look delta: a weapon lags behind how far the hands moved. | Set sway x to x | Set sway y to y") and ok
	ok = _check("a verb with a step in its right lane is an ordinary two-lane event",
		verb_header != null and not verb_header.full_width_lanes, true) and ok
	# A verb whose first step asks a question of its own keeps that step as a row - only a step that
	# is pure right-lane content folds up beside the name - and with nothing on the right the chips
	# still get the whole row rather than being squeezed into the condition track.
	var guarded_verb: EventRowData = _verb_row(rows, "define_fn_do_jump")
	ok = _check("a verb whose first step has a condition keeps that step as its own row",
		_texts(guarded_verb), "ƒ | Jump | action") and ok
	ok = _check("a verb with an empty right lane still spans both lanes",
		guarded_verb != null and guarded_verb.full_width_lanes, true) and ok
	var canvas_width: float = 1152.0
	var style_tokens: EventSheetEventStyle = view.get_event_style()
	ok = _check("its chips get the whole row's width",
		ViewportRowMetrics.condition_right_limit(
			guarded_verb, canvas_width, view.get_lane_divider_x(canvas_width), float(style_tokens.condition_lane_padding)
		) > view.get_lane_divider_x(canvas_width), true) and ok
	# A row that DOES use its right lane keeps the split - the trigger rows say "emits <signal>" there.
	var trigger_row: EventRowData = trigger_rows[0] if not trigger_rows.is_empty() else null
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
	var bar: EventRowData = _row_with_uid(_all_rows(view), "pack_include_bar_")
	ok = _check("a plain script still gets the Include bar", bar != null, true) and ok
	# And it does not wear the word "Script" either. Its name and its class are the head bands'
	# to say, so all the bar owes a plain script is how much of it read as events.
	ok = _check("but it is not called an Addon Pack", _texts(bar), "⇥ | reads as events") and ok
	ok = _check("the bands name it instead", _texts(_band(_all_rows(view), "name")),
		"▣ | Patrol | class_name Patrol") and ok
	ok = _check("its exported knob lands in the one variable folder",
		_texts(_bar_titled(_all_rows(view), "Instance variables")), "Instance variables | of Patrol") and ok
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
## Every row of the opened pack, parents before children, in the shape `get_flat_rows()` answers
## in. The head is one FOLDED bar now, so the bands and bars it stands for are off screen exactly as
## the Triggers bar's rows have always been - and a test about what the head SAYS has to see them.
static func _all_rows(view: EventSheetViewport) -> Array:
	var found: Array = []
	_sweep_rows(view, view._root_rows, found)
	return found


static func _sweep_rows(view: EventSheetViewport, rows: Array, into: Array) -> void:
	for row_data: EventRowData in rows:
		view._ensure_event_spans(row_data)
		into.append({"row": row_data})
		_sweep_rows(view, row_data.children, into)


static func _band(rows: Array, kind: String) -> EventRowData:
	return _row_with_uid(rows, "sheet_head_%s_" % kind)


## The head band stack in reading order, by kind: "name | extends | icon | host" - the lines the
## FILE opens with. The bands read out of a `.tscn` are left out: which lights reach this pack's host
## is a fact of somebody's scene, and a project that grew one would otherwise change what this file
## is said to say.
static func _band_kinds(rows: Array) -> String:
	var kinds: PackedStringArray = PackedStringArray()
	for entry: Variant in rows:
		var row_data: EventRowData = (entry as Dictionary).get("row")
		if row_data == null or not row_data.row_uid.begins_with("sheet_head_") \
				or row_data.row_uid.begins_with("sheet_head_bar_"):
			continue
		var tail: String = row_data.row_uid.trim_prefix("sheet_head_")
		if _is_scene_band(tail):
			continue
		kinds.append(tail.substr(0, tail.rfind("_")))
	return " | ".join(kinds)


## True for a band read out of a `.tscn` - the lights, the spawners, the collisions - asked of the
## one table that says which kinds those are.
static func _is_scene_band(uid_tail: String) -> bool:
	for kind: String in EventSheetHeadBands.SCENE_BANDS.keys():
		if uid_tail.begins_with(kind):
			return true
	return false


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


## The trigger rows a Verbs bar closes on - the signal rows among its members, in band order.
static func _trigger_children(bar: EventRowData) -> Array:
	var found: Array = []
	if bar == null:
		return found
	for child: EventRowData in bar.children:
		if child.row_uid.begins_with("signal_"):
			found.append(child)
	return found


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
	return SUPPORT.check("opened_pack_head_test", label, actual, expected)


## Every span's text as a list - for asking whether the row carries one exact word, which a joined
## line cannot answer once a span holds a whole declaration.
static func _span_texts(row_data: EventRowData) -> PackedStringArray:
	var parts: PackedStringArray = PackedStringArray()
	if row_data == null:
		return parts
	for span: SemanticSpan in row_data.spans:
		parts.append(str(span.text))
	return parts
