# EventForge - Documentation FIGURES: the figure-mode renderer seam + EventSheetDocFigure
#
# A figure is the real EventSheetViewport drawing a real EventSheetResource as an inline,
# insertable illustration. This test pins the three things that make that safe:
#
#   1. SIZING. A figure is its content in BOTH axes. The editing surface fills its host and
#      never shrinks below 240 px tall or 640 px wide; a figure in a picker panel or a side
#      dock cannot afford either floor, so content_height() / content_width() must beat them.
#      Beating the floor is NOT the same as fitting a narrow host, and the numbers say so:
#      measured here, a one-row action figure settles at ~494 px, a condition or trigger at
#      ~857 px, and the two-lane trigger+action fixture at ~810 px - all wider than the doc
#      panel's 460 px column. What makes a narrow host safe is the CEILING: set_figure_max_width
#      wraps the rows inside the room the host has, and that is pinned below on real content.
#   2. INERTNESS. Figure mode drops the "+ Add event…" footer, refuses pointer input, and
#      leaves focus unfocusable - an illustration that highlights rows reads as an editor.
#   3. INSERTION. EventSheets.insert_snippet() runs the dock's guarded paste path, so the rows
#      land as ONE undo step and undo puts the sheet back.
#
# WHAT THIS SUITE CANNOT REACH (confirm with tools/render_docs_slice_preview.gd, non-headless):
#   - that figure mode actually suppresses _process AFTER tree entry. Under --script the
#     SceneTree's _init runs before the tree exists, so a viewport added under get_root()
#     never runs _ready and reports is_processing() == false whatever the flag says. A test
#     written for it asserts nothing while reading as covered.
#   - that a figure ignores real clicks, hover, right-press and Ctrl+wheel (a real mouse).
#   - that a figure DRAWS correctly at the chosen palette and scale (the preview image).
@tool
class_name DocFigureViewTest
extends RefCounted

const MOCKUP_THEME_PATH := "res://addons/eventsheet/themes/mockup_slate_theme.tres"
const DEMO_THEME_PATH := "res://demo/themes/mockup_slate_theme.tres"


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _test_sizing() and all_passed
	all_passed = _test_inertness() and all_passed
	all_passed = _test_definition_figures() and all_passed
	all_passed = _test_theme_home() and all_passed
	all_passed = _test_insert_snippet() and all_passed
	return all_passed


# ── 1. Sizing: content in both axes, neither floor ────────────────────────────────────────


static func _test_sizing() -> bool:
	var all_passed: bool = true

	# THE FLOOR. A short code row wants about 200 px. The editing surface would still hand it a
	# 640 x 240 canvas, which is the whole reason a narrow host could not carry a figure.
	var narrow: EventSheetViewport = _figure_viewport(_code_sheet("print(1)"))
	all_passed = _check("narrow content beats the editing surface's 640 px width floor",
		narrow.custom_minimum_size.x < 640.0, true) and all_passed
	all_passed = _check("narrow content beats the editing surface's 240 px height floor",
		narrow.custom_minimum_size.y < 240.0, true) and all_passed
	all_passed = _check("a longer code row asks for more width than a short one",
		_figure_viewport(_code_sheet("print(\"a much longer line of code than the other one\")")).content_width()
			> narrow.content_width(), true) and all_passed
	# The same rows on the editing surface get the floors instead - so neither check above can
	# pass by accident.
	var narrow_editing := EventSheetViewport.new()
	narrow_editing.set_sheet(_code_sheet("print(1)"))
	narrow_editing._update_canvas_min_size()
	all_passed = _check("the editing surface imposes its 640 px width floor on the same row",
		narrow_editing.custom_minimum_size.x, 640.0) and all_passed
	all_passed = _check("the editing surface imposes its 240 px height floor on the same row",
		narrow_editing.custom_minimum_size.y, 240.0) and all_passed
	narrow_editing.free()
	narrow.free()

	var single_sheet: EventSheetResource = _sheet_with(1, false)
	var single: EventSheetViewport = _figure_viewport(single_sheet)
	all_passed = _check("the figure canvas width IS the measured content width",
		is_equal_approx(single.custom_minimum_size.x, single.content_width()), true) and all_passed
	all_passed = _check("the figure canvas height IS the measured content height",
		is_equal_approx(single.custom_minimum_size.y, single.content_height()), true) and all_passed
	all_passed = _check("content_height() equals the row metrics' own total_height()",
		is_equal_approx(single.content_height(), single._row_metrics_helper.total_height()), true) and all_passed
	var single_height: float = single.content_height()
	all_passed = _check("a one-row figure has a real height", single_height > 0.0, true) and all_passed

	# Row counts: height grows with rows, width does not (the rows say the same thing).
	var triple: EventSheetViewport = _figure_viewport(_sheet_with(3, false))
	all_passed = _check("three rows are taller than one",
		triple.content_height() > single_height, true) and all_passed
	# Three rows are three row heights PLUS the two sibling-block gaps the sheet opens between
	# top-level events - the figure measures the real layout, not rows x height.
	var block_gap: float = EventSheetViewport.EVENT_BLOCK_GAP * EventSheetPalette.row_density()
	all_passed = _check("three rows measure three row heights plus the two sibling-block gaps",
		is_equal_approx(triple.content_height(), single_height * 3.0 + block_gap * 2.0), true) and all_passed
	all_passed = _check("identical rows ask for the same width",
		is_equal_approx(triple.content_width(), single.content_width()), true) and all_passed

	# A WRAPPING row: comments wrap to the canvas width, so they take height and ask for no
	# width. This is the case that breaks a naive "widest row wins" measurement.
	var wrapped: EventSheetViewport = _figure_viewport(_sheet_with(3, true))
	all_passed = _check("a wrapping comment does not widen the figure",
		is_equal_approx(wrapped.content_width(), triple.content_width()), true) and all_passed
	all_passed = _check("a wrapping comment adds height",
		wrapped.content_height() > triple.content_height(), true) and all_passed

	# An explicit host width wins over the measurement, and going back to <= 0 measures again.
	single.set_figure_width_override(320.0)
	all_passed = _check("a width override drives the canvas", single.custom_minimum_size.x, 320.0) and all_passed
	single.set_figure_width_override(-1.0)
	all_passed = _check("clearing the override measures again",
		is_equal_approx(single.custom_minimum_size.x, single.content_width()), true) and all_passed

	single.free()
	triple.free()
	wrapped.free()

	# THE HOST CEILING, on the content figures really carry. A RawCodeRow is one flat lane and is
	# narrow by nature; a verb figure is two lanes with an object sub-column and settles WIDER
	# than the doc panel's own column, so "beats the 640 px floor" is not on its own the property
	# a narrow host needs. What a narrow host needs is that the ceiling holds: the rows wrap
	# inside the room they were given instead of forcing the page sideways.
	var host_width: float = 300.0
	for ace_type: int in [ACEDefinition.ACEType.ACTION, ACEDefinition.ACEType.CONDITION, ACEDefinition.ACEType.TRIGGER]:
		var figure_sheet: EventSheetResource = EventSheetDocFigure.sheet_for_definition(
			_definition(ace_type, "print({message})"))
		var measured: EventSheetViewport = _figure_viewport(figure_sheet)
		# The claim that makes the ceiling load-bearing rather than decorative: unbounded, this
		# content is WIDER than the 460 px page column the doc panel gives it.
		all_passed = _check("an unbounded verb figure is wider than a narrow host (%d)" % ace_type,
			measured.content_width() > host_width, true) and all_passed
		measured.set_figure_max_width(host_width)
		measured._update_canvas_min_size()
		all_passed = _check("a verb figure never exceeds the width its host gave it (%d)" % ace_type,
			measured.custom_minimum_size.x <= host_width, true) and all_passed
		all_passed = _check("a capped verb figure still has a real height (%d)" % ace_type,
			measured.custom_minimum_size.y > 0.0, true) and all_passed
		measured.free()
	return all_passed


# ── 2. Inertness ──────────────────────────────────────────────────────────────────────────


static func _test_inertness() -> bool:
	var all_passed: bool = true
	var sheet: EventSheetResource = _sheet_with(2, false)

	var editing: EventSheetViewport = EventSheetViewport.new()
	editing.set_sheet(sheet)
	var editing_rows: int = editing.get_flat_rows().size()
	all_passed = _check("the editing surface offers the add-event footer", editing.show_add_event_footers, true) and all_passed
	all_passed = _check("the editing surface takes the mouse", editing.mouse_filter, Control.MOUSE_FILTER_STOP) and all_passed
	all_passed = _check("the editing surface is focusable", editing.focus_mode, Control.FOCUS_ALL) and all_passed
	all_passed = _check("two events plus the footer flatten to three rows", editing_rows, 3) and all_passed

	var figure: EventSheetViewport = _figure_viewport(sheet)
	all_passed = _check("figure mode drops the add-event footer", figure.show_add_event_footers, false) and all_passed
	all_passed = _check("the same two events flatten to two rows in a figure", figure.get_flat_rows().size(), 2) and all_passed
	all_passed = _check("a figure ignores the pointer", figure.mouse_filter, Control.MOUSE_FILTER_IGNORE) and all_passed
	all_passed = _check("a figure cannot take focus", figure.focus_mode, Control.FOCUS_NONE) and all_passed
	all_passed = _check("figure mode also turns companion mode on (no inline editing)", figure.companion_mode, true) and all_passed

	# The input handlers early-return BEFORE any hit test: a right-press grabs focus and
	# Ctrl+wheel zooms before a hit is read, so a guard placed at the hit sites is too late.
	var zoom_before: float = figure.get_zoom_factor()
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.ctrl_pressed = true
	wheel.position = Vector2(40.0, 20.0)
	figure._input_handlers.handle_mouse_button(wheel)
	all_passed = _check("Ctrl+wheel does not zoom a figure", figure.get_zoom_factor(), zoom_before) and all_passed

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(40.0, 20.0)
	figure._input_handlers.handle_mouse_button(press)
	all_passed = _check("clicking a figure selects nothing", figure.get_selected_row_index(), -1) and all_passed

	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(60.0, 20.0)
	figure._input_handlers.handle_mouse_motion(motion)
	all_passed = _check("hovering a figure highlights nothing", figure._hovered_row_index, -1) and all_passed

	# The CONTRAST, so none of the three above can pass vacuously: the identical events on an
	# editing surface do select and do hover.
	editing._input_handlers.handle_mouse_button(press)
	all_passed = _check("the same click DOES select on an editing surface", editing.get_selected_row_index(), 0) and all_passed
	editing._input_handlers.handle_mouse_motion(motion)
	all_passed = _check("the same motion DOES hover on an editing surface", editing._hovered_row_index, 0) and all_passed

	# Turning figure mode back off restores the editing surface, so the flag is a mode and
	# not a one-way door (a host that reuses a viewport must be able to hand it back).
	figure.set_figure_mode(false)
	all_passed = _check("leaving figure mode restores the footer", figure.show_add_event_footers, true) and all_passed
	all_passed = _check("leaving figure mode restores the mouse filter", figure.mouse_filter, Control.MOUSE_FILTER_STOP) and all_passed

	editing.free()
	figure.free()
	return all_passed


# ── 3. Figures built from vocabulary ──────────────────────────────────────────────────────


static func _test_definition_figures() -> bool:
	var all_passed: bool = true

	var action_definition: ACEDefinition = _definition(ACEDefinition.ACEType.ACTION, "print({message})")
	var action_sheet: EventSheetResource = EventSheetDocFigure.sheet_for_definition(action_definition)
	all_passed = _check("an action makes a one-row figure sheet",
		action_sheet.events.size() if action_sheet != null else -1, 1) and all_passed
	var action_row: EventRow = action_sheet.events[0] as EventRow
	var baked_action: ACEAction = action_row.actions[0] as ACEAction
	all_passed = _check("the figure's action carries its ace id", baked_action.ace_id, "FigureVerb") and all_passed
	all_passed = _check("the figure fills the parameter with its declared default",
		str(baked_action.params.get("message", "")), "\"hello\"") and all_passed
	all_passed = _check("the figure bakes the codegen template", baked_action.codegen_template, "print({message})") and all_passed

	# A reflected pack method declares no default for its String arguments - reflection writes
	# default_value = "" for exactly that case - so the figure used to draw the verb as
	# `Advance Objective ( , , 0 )`: a picture of a broken call, on exactly the pack verbs this
	# surface exists to explain. An empty slot names itself instead. A REAL default is left
	# exactly as dropping the verb would produce it, including the literal empty string `""`,
	# which is two characters of source text and not the same thing as "no default".
	var undeclared: ACEDefinition = _definition(ACEDefinition.ACEType.ACTION, "advance({quest_id})")
	undeclared.parameters = [
		{"id": "quest_id", "display_name": "Quest Id", "type": TYPE_STRING, "default_value": ""},
		{"id": "step", "type": TYPE_INT, "default_value": ""},
		{"id": "note", "type": TYPE_STRING, "default_value": "\"\""},
		{"id": "loud", "type": TYPE_BOOL, "default_value": ""},
		{"id": "target", "type": TYPE_VECTOR2, "default_value": ""},
	]
	var undeclared_action: ACEAction = ((EventSheetDocFigure.sheet_for_definition(undeclared)
		.events[0] as EventRow).actions[0] as ACEAction)
	all_passed = _check("an empty string slot names itself instead of drawing blank",
		str(undeclared_action.params.get("quest_id", "")), "\"quest id\"") and all_passed
	all_passed = _check("an empty number slot shows its zero",
		str(undeclared_action.params.get("step", "")), "0") and all_passed
	all_passed = _check("an empty flag slot shows false",
		str(undeclared_action.params.get("loud", "")), "false") and all_passed
	all_passed = _check("a real empty-string literal is left exactly as it is",
		str(undeclared_action.params.get("note", "unset")), "\"\"") and all_passed
	# A type whose zero value would be an invented literal stays empty on purpose: a figure's
	# rows are INSERTABLE, so a made-up value that does not compile is worse than a gap.
	all_passed = _check("a type with no honest zero literal is left empty",
		str(undeclared_action.params.get("target", "unset")), "") and all_passed

	# {uid} is baked by whoever creates the row - the compiler never does, so an unbaked one
	# would sail straight into emitted GDScript if a figure's rows were ever inserted.
	var stateful: ACEDefinition = _definition(ACEDefinition.ACEType.CONDITION, "_figure_gate_{uid}")
	stateful.metadata["member_template"] = "var _figure_gate_{uid}: bool = false"
	var stateful_sheet: EventSheetResource = EventSheetDocFigure.sheet_for_definition(stateful)
	var stateful_condition: ACECondition = (stateful_sheet.events[0] as EventRow).conditions[0] as ACECondition
	all_passed = _check("a stateful figure bakes {uid} in its template",
		stateful_condition.codegen_template, "_figure_gate_figure") and all_passed
	all_passed = _check("a stateful figure bakes {uid} in its member declaration",
		stateful_condition.member_declaration, "var _figure_gate_figure: bool = false") and all_passed

	var trigger: ACEDefinition = _definition(ACEDefinition.ACEType.TRIGGER, "")
	var trigger_sheet: EventSheetResource = EventSheetDocFigure.sheet_for_definition(trigger)
	all_passed = _check("a trigger figure bakes the trigger identity onto the event",
		(trigger_sheet.events[0] as EventRow).trigger_id, "FigureVerb") and all_passed

	var expression: ACEDefinition = _definition(ACEDefinition.ACEType.EXPRESSION, "value()")
	all_passed = _check("an expression has no figure of its own (it is a value in a cell, not a row)",
		EventSheetDocFigure.sheet_for_definition(expression), null) and all_passed
	all_passed = _check("a missing definition has no figure",
		EventSheetDocFigure.sheet_for_definition(null), null) and all_passed

	# The widget itself: an EMPTY sheet must be refused. The viewport's getting-started overlay
	# draws real clickable call-to-action buttons, and an illustration is never a click target.
	var widget := EventSheetDocFigure.new()
	all_passed = _check("a figure refuses an empty sheet", widget.show_sheet(EventSheetResource.new()), false) and all_passed
	all_passed = _check("a refused figure hides itself", widget.visible, false) and all_passed
	all_passed = _check("a refused figure has no snippet text", widget.snippet_text(), "") and all_passed
	all_passed = _check("a figure accepts a populated sheet", widget.show_sheet(action_sheet), true) and all_passed
	all_passed = _check("an accepted figure shows itself", widget.visible, true) and all_passed
	all_passed = _check("an accepted figure serializes to snippet text",
		EventSheetSnippet.is_snippet_text(widget.snippet_text()), true) and all_passed
	all_passed = _check("the figure's viewport is in figure mode", widget.figure_viewport().figure_mode, true) and all_passed
	widget.free()
	return all_passed


# ── 4. The re-homed theme: ONE copy, and it is the palette the mockups defined ─────────────


static func _test_theme_home() -> bool:
	var all_passed: bool = true
	all_passed = _check("the mockup-slate theme ships inside the plugin",
		ResourceLoader.exists(MOCKUP_THEME_PATH), true) and all_passed
	# A copy left behind in demo/ would be a second source of truth for the palette the whole
	# visual language is built on - and list_presets() de-dupes by display name, so the
	# duplicate would be invisible in the theme switcher.
	all_passed = _check("the theme was MOVED, not copied (no second source of truth)",
		FileAccess.file_exists(DEMO_THEME_PATH), false) and all_passed
	var style: EventSheetEditorStyle = ResourceLoader.load(MOCKUP_THEME_PATH) as EventSheetEditorStyle
	all_passed = _check("the re-homed file is a real editor style", style != null, true) and all_passed
	if style == null:
		return false
	var viewport: EventSheetViewport = _figure_viewport(_sheet_with(1, false))
	viewport.apply_editor_style(style)
	all_passed = _check("the mockups' orange object label survives the move",
		viewport._get_event_style().object_label_color, Color(0.847059, 0.639216, 0.352941)) and all_passed
	all_passed = _check("the mockups' green value highlight survives the move",
		viewport._get_event_style().value_highlight_color, Color(0.623529, 0.831373, 0.478431)) and all_passed
	# The point of the move: a plugin-only install had ZERO theme presets, because the bundled
	# themes all live in demo/, which ships in the samples zip and not the plugin zip.
	var addon_presets: int = 0
	for preset: Dictionary in EventSheetThemePresets.list_presets():
		if str(preset.get("path", "")).begins_with("res://addons/eventsheet/themes/"):
			addon_presets += 1
	all_passed = _check("a plugin-only install now has a theme preset", addon_presets, 1) and all_passed
	viewport.free()
	return all_passed


# ── 5. Insert through the REAL funnel ─────────────────────────────────────────────────────


static func _test_insert_snippet() -> bool:
	var all_passed: bool = true
	var figure_sheet: EventSheetResource = EventSheetDocFigure.sheet_for_definition(
		_definition(ACEDefinition.ACEType.ACTION, "print({message})"))
	var snippet_text: String = EventSheetSnippet.serialize_rows(figure_sheet.events, figure_sheet)

	# The dock registers itself with the API on construction, so this is the same route a
	# figure's Insert button takes in the editor.
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	var undo: RefCounted = EventSheetEditorTest.FakeEditorUndoRedoManager.new()
	dock.set_undo_redo_manager(undo)

	# NO SHEET OPEN - the state a docs window that outlived a tab close sees. The dock's paste
	# path answers TRUE here, but it is answering a different question ("the text WAS a snippet,
	# do not fall back to the internal clipboard"); inheriting that answer had the figure's
	# Insert button report success and write "Inserted the illustrated rows…" into the status
	# line while the sheet stayed untouched.
	all_passed = _check("no sheet is open yet", EventSheets.current_sheet(), null) and all_passed
	all_passed = _check("inserting with no sheet open is refused",
		EventSheets.insert_snippet(snippet_text, "Insert Figure"), false) and all_passed
	all_passed = _check("and nothing was inserted anywhere", EventSheets.current_sheet(), null) and all_passed

	var target := EventSheetResource.new()
	dock.setup(target)

	all_passed = _check("plain text is refused", EventSheets.insert_snippet("not a snippet"), false) and all_passed
	all_passed = _check("target sheet starts empty", target.events.size(), 0) and all_passed
	all_passed = _check("snippet text inserts", EventSheets.insert_snippet(snippet_text, "Insert Figure"), true) and all_passed
	all_passed = _check("the figure's row landed in the live sheet", EventSheets.current_sheet().events.size(), 1) and all_passed
	all_passed = _check("the insert is undoable", undo.has_undo(), true) and all_passed

	# ONE undo step, not one per row: a single undo puts the sheet back the way it was.
	undo.undo()
	all_passed = _check("one undo removes the whole insert", EventSheets.current_sheet().events.size(), 0) and all_passed
	all_passed = _check("redo puts it back", _redo_count(undo, dock), 1) and all_passed

	dock.free()
	return all_passed


static func _redo_count(undo: RefCounted, _dock: EventSheetDock) -> int:
	undo.redo()
	var sheet: EventSheetResource = EventSheets.current_sheet()
	return sheet.events.size() if sheet != null else -1


# ── Fixtures ──────────────────────────────────────────────────────────────────────────────


## `count` identical one-action events, optionally followed by a long comment row (which wraps
## to the canvas width, so its height depends on the width the figure settles on).
static func _sheet_with(count: int, with_comment: bool) -> EventSheetResource:
	var sheet := EventSheetResource.new()
	for index in range(count):
		var row := EventRow.new()
		row.trigger_provider_id = "Core"
		row.trigger_id = "OnReady"
		var action := ACEAction.new()
		action.provider_id = "Core"
		action.ace_id = "Print"
		action.codegen_template = "print({message})"
		action.params = {"message": "\"hello\""}
		row.actions.append(action)
		sheet.events.append(row)
	if with_comment:
		var comment := CommentRow.new()
		comment.text = "A deliberately long comment line that wraps more than once at a narrow canvas width, so this row's height is a function of the width the figure settles on."
		sheet.events.append(comment)
	return sheet


## A single verbatim code row - the narrowest real figure content there is.
static func _code_sheet(code: String) -> EventSheetResource:
	var sheet := EventSheetResource.new()
	var row := RawCodeRow.new()
	row.code = code
	sheet.events.append(row)
	return sheet


static func _figure_viewport(sheet: EventSheetResource) -> EventSheetViewport:
	var viewport := EventSheetViewport.new()
	viewport.set_figure_mode(true)
	viewport.set_sheet(sheet)
	viewport._update_canvas_min_size()
	return viewport


static func _definition(ace_type: int, template: String) -> ACEDefinition:
	var definition := ACEDefinition.new()
	definition.provider_id = "FigureFixture"
	definition.id = "FigureVerb"
	definition.display_name = "Figure Verb"
	definition.ace_type = ace_type
	definition.description = "A fixture verb, used to build a figure."
	definition.parameters = [{"id": "message", "type": TYPE_STRING, "default_value": "\"hello\""}]
	definition.metadata = {"codegen_template": template}
	return definition


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] doc_figure_view_test: %s" % label)
		return true
	print("[FAIL] doc_figure_view_test: %s (expected %s, got %s)" % [label, expected, actual])
	return false
