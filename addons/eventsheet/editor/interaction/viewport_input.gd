@tool
class_name ViewportInputHandlers
extends RefCounted
# The INPUT handling of the event sheet's virtualized viewport, extracted from
# event_sheet_viewport.gd to keep that file maintainable. The four handlers behind
# the viewport's _gui_input virtual live here:
#
#   - MOUSE MOTION: hover tracking, drag-target updates, lane-resize affordance,
#   - MOUSE BUTTONS: the whole click grammar - select / range / toggle, fold arrows,
#     breakpoint gutter, inline edit triggers, drag begins/completes, wheel zoom,
#     context-menu requests,
#   - KEYS: the row-scope keyboard map (navigation, folding incl. the region bracket
#     shortcuts, bookmarks, breakpoints, param scope entry, clipboard, zoom),
#   - EDITING KEYS: the inline cell editor's caret/typing/commit/cancel handling.
#
# All interaction STATE stays on the viewport (selection, hover, drag, editing
# buffers) - handlers read and write it through the `_viewport.` back-reference,
# so multi-view panes and the layout cache behave exactly as before. Bodies were
# moved VERBATIM; the viewport keeps its _gui_input virtual plus one-line handler
# delegates, so the input flow and every test stay untouched.

var _viewport: Control = null

## Where the reading-coverage chip has walked to. One click is one script block, so the cursor rides
## with the VIEW - a second tab keeps its own place in its own file.
var _script_block_cursor: int = 0


func init(viewport: Control) -> void:
	_viewport = viewport


## W13 - go to the function a ƒ chip names. The same two calls the Outline makes when one of its
## entries is picked, so the chip and the panel land the reader in the very same place; a name whose
## function this sheet does not declare simply does nothing, which is what the chip promised.
func _jump_to_function(function_name: String) -> bool:
	if function_name.strip_edges().is_empty():
		return false
	var target: EventFunction = ViewportRowBuilder.find_function_by_name(
		_viewport._sheet, function_name)
	if target == null:
		return false
	_viewport.reveal_resource(target)
	_viewport.select_resource(target)
	return true


## P3 / S25 - the coverage chip's click: reveal the next place the chip counted and select it,
## wrapping round at the end. The chip says how many there are; this is how a reader goes and looks
## at them, one click at a time, without leaving the sheet.
##
## The walk is every script block in file order and then every ⟡ event, which is exactly what the
## chip's two halves count - a reader who keeps clicking sees each thing the chip mentioned once.
func _walk_to_next_script_block() -> bool:
	var sheet: EventSheetResource = _viewport._sheet
	var stops: Array[Resource] = []
	for block: RawCodeRow in EventSheetReadingCoverage.script_blocks(sheet):
		stops.append(block)
	for pattern_event: EventRow in _pattern_events(sheet):
		stops.append(pattern_event)
	if stops.is_empty():
		return false
	if _script_block_cursor >= stops.size():
		_script_block_cursor = 0
	var target: Resource = stops[_script_block_cursor]
	_script_block_cursor = (_script_block_cursor + 1) % stops.size()
	return _viewport.reveal_resource(target)


## S25 - the events that OWN a pattern claim, in sheet order and each one once, however many
## patterns it was claimed for. Resolved from the registry's row uids against the live sheet, so a
## claim left over from a shape that has since been edited away simply has nowhere to land.
func _pattern_events(sheet: EventSheetResource) -> Array[EventRow]:
	var found: Array[EventRow] = []
	if sheet == null:
		return found
	EventSheetViewportReadingRows.ensure_claims(sheet)
	var wanted: Dictionary = {}
	for claim: Variant in EventSheetPatternFacts.claims(sheet):
		wanted[str((claim as Dictionary).get("row_uid", ""))] = true
	_collect_pattern_events(sheet.events, wanted, found)
	for function_entry: Variant in sheet.functions:
		if function_entry is EventFunction:
			_collect_pattern_events((function_entry as EventFunction).events, wanted, found)
	return found


func _collect_pattern_events(events: Array, wanted: Dictionary, found: Array[EventRow]) -> void:
	for entry: Variant in events:
		if not (entry is EventRow):
			continue
		if wanted.has((entry as EventRow).event_uid):
			found.append(entry as EventRow)
		_collect_pattern_events((entry as EventRow).sub_events, wanted, found)


## Whether the pointer sits on a cell's colour swatch (the clickable box that opens the
## inline picker) - drives the hand-cursor affordance below.
func _over_color_swatch(hit: Dictionary, local_position: Vector2) -> bool:
	var metadata: Variant = hit.get("span_metadata", {})
	if not (metadata is Dictionary):
		return false
	var swatch_rect: Variant = (metadata as Dictionary).get("swatch_rect")
	return swatch_rect is Rect2 and (swatch_rect as Rect2).has_point(local_position)


## True when the viewport is a documentation FIGURE. A figure is an illustration, not an editing
## surface: it takes no pointer input at all. MOUSE_FILTER_IGNORE already stops most of it, but
## the handlers below are also reachable through forwarded input, and two of them act BEFORE any
## hit test runs (a right-press grabs focus; Ctrl+wheel zooms), so the refusal belongs at the top
## of each handler rather than only at the places that read a hit.
func _is_inert_figure() -> bool:
	return bool(_viewport.figure_mode)


func handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _is_inert_figure():
		return
	# Ctrl-hover affordance: the hand cursor advertises the Ctrl+Click jump on resolvable cells.
	if _viewport.navigation_probe.is_valid() and (event.ctrl_pressed or event.meta_pressed):
		var nav_hit: Dictionary = _viewport._hit_test(_viewport._to_logical_position(event.position))
		var nav_row: EventRowData = _viewport._row_at(int(nav_hit.get("row_index", -1)))
		var navigable: bool = nav_row != null and bool(_viewport.navigation_probe.call(nav_row, nav_hit.get("span_metadata", {})))
		_viewport.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if navigable else Control.CURSOR_ARROW
	elif _viewport.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND:
		_viewport.mouse_default_cursor_shape = Control.CURSOR_ARROW
	var local_position: Vector2 = _viewport._to_logical_position(event.position)
	if _viewport._dragging_lane_divider:
		_viewport._set_lane_ratio_from_x(local_position.x)
		return
	if not _viewport._dragging_object_column_lane.is_empty():
		_viewport._set_object_column_width_from_x(local_position.x)
		return
	if _viewport._box_select_active:
		_viewport._box_select_current = local_position
		_viewport.queue_redraw()
		return
	var hit: Dictionary = _viewport._hit_test(local_position)
	_viewport._set_hover_state(int(hit.get("row_index", -1)), int(hit.get("span_index", -1)))
	# Cursor affordance, in priority order: the lane divider resizes (↔); the empty non-cell area of
	# an event row is the whole-event DRAG handle (✥ move cursor) - dragging there reorders the event
	# or nests it as a sub-event, so the previously-dead space now reads as grabbable; everything else
	# is the arrow. (Ctrl-hover's hand cursor is set above and left alone here.)
	var over_drag_zone: bool = _viewport.is_event_drag_zone(_viewport._row_at(int(hit.get("row_index", -1))), int(hit.get("span_index", -1)))
	if _viewport._hover_is_drag_zone != over_drag_zone:
		_viewport._hover_is_drag_zone = over_drag_zone
		_viewport.queue_redraw()  # brighten the grip handle on the hovered row
	# The ↔ cursor alone does not say WHERE the boundary is, and a per-row divider is a broken dashed
	# hint at best (the object-column boundary draws nothing at rest). Hovering either one lights the
	# full-sheet guide, so the line you are about to drag is visible before you press the button.
	var object_column_hover: Dictionary = _viewport.object_column_boundary_hit(local_position)
	if _viewport._is_near_lane_divider(local_position):
		_viewport.mouse_default_cursor_shape = Control.CURSOR_HSIZE
		_viewport.set_divider_guide(_viewport.get_lane_divider_x(_viewport._get_logical_canvas_width()), false)
	elif not object_column_hover.is_empty():
		# The object-name / display-text gap is an event-sheet sub-lane divider: same ↔ affordance.
		_viewport.mouse_default_cursor_shape = Control.CURSOR_HSIZE
		_viewport.set_divider_guide(float(object_column_hover.get("boundary_x", -1.0)), false)
	elif over_drag_zone:
		_viewport.clear_divider_guide()
		_viewport.mouse_default_cursor_shape = Control.CURSOR_MOVE
	elif _over_color_swatch(hit, local_position):
		# The colour swatch is clickable (opens the inline picker) - advertise it like a link.
		_viewport.clear_divider_guide()
		_viewport.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		_viewport.clear_divider_guide()
		_viewport.mouse_default_cursor_shape = Control.CURSOR_ARROW
	_viewport._drag_pointer_position = local_position
	if not _viewport._drag_ace_entries.is_empty():
		_viewport._drag_ace_copy_mode = event.ctrl_pressed or event.meta_pressed
		_viewport._update_ace_drag_target(hit, local_position)
	elif _viewport._drag_row_index >= 0:
		_viewport._drag_row_copy_mode = event.ctrl_pressed or event.meta_pressed
		# A ternary pair is one statement: a target that landed between its rows is snapped out to
		# before or after the whole pair, so the indicator can never promise a drop the sheet has no
		# place for.
		var drop_target: Dictionary = _viewport.normalize_row_drop_target(
			int(hit.get("row_index", -1)), _viewport._resolve_drop_mode(hit, local_position))
		_viewport._drag_target_index = int(drop_target.get("index", -1))
		_viewport._drag_target_mode = str(drop_target.get("mode", "before"))
		_viewport.queue_redraw()


func handle_mouse_button(event: InputEventMouseButton) -> void:
	if _is_inert_figure():
		return
	if event.pressed and (event.ctrl_pressed or event.meta_pressed):
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_viewport.zoom_in(event.position)
			_viewport.accept_event()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_viewport.zoom_out(event.position)
			_viewport.accept_event()
			return
	var local_position: Vector2 = _viewport._to_logical_position(event.position)
	if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and _viewport._box_select_active:
		_viewport._box_select_current = local_position
		_viewport._complete_box_selection()
		_viewport.accept_event()
		return
	var hit: Dictionary = _viewport._hit_test(local_position)
	var row_index: int = int(hit.get("row_index", -1))
	var span_index: int = int(hit.get("span_index", -1))
	if event.button_index == MOUSE_BUTTON_RIGHT:
		if not event.pressed:
			return
		_viewport.grab_focus()
		# Footer "Add event…" rows are pure affordances - no context menu / selection.
		if _viewport._row_is_add_event_footer(_viewport._row_at(row_index)):
			_viewport.accept_event()
			return
		if row_index >= 0:
			if not _viewport._is_selection_hit(row_index, span_index):
				_viewport._select_from_click(row_index, span_index, false)
			var row_data: EventRowData = _viewport._row_at(row_index)
			if row_data != null:
				_viewport.context_menu_requested.emit(
					row_data,
					hit.duplicate(true),
					DisplayServer.mouse_get_position()
				)
				_viewport.accept_event()
		else:
			_viewport.empty_space_context_menu_requested.emit(DisplayServer.mouse_get_position())
			_viewport.accept_event()
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		_viewport.grab_focus()
		if _viewport._is_near_lane_divider(local_position):
			_viewport._dragging_lane_divider = true
			_viewport.accept_event()
			return
		var object_column_hit: Dictionary = _viewport.object_column_boundary_hit(local_position)
		if not object_column_hit.is_empty():
			_viewport._dragging_object_column_lane = str(object_column_hit.get("lane", ""))
			_viewport._object_column_drag_anchor_x = float(object_column_hit.get("anchor_x", 0.0))
			_viewport.accept_event()
			return
		if row_index < 0:
			# The centered getting-started CTAs are real buttons: a single click activates them.
			# "add_event" routes through the same signal as the double-click gesture, so the dock's
			# self-healing (open the starter menu when no sheet is loaded) covers both.
			var cta_action: String = _viewport._empty_state_helper.cta_action_at(local_position)
			if cta_action == "add_event":
				_viewport.empty_space_double_clicked.emit()
				_viewport.accept_event()
				return
			if cta_action == "template_menu":
				_viewport.template_menu_requested.emit()
				_viewport.accept_event()
				return
			if event.double_click:
				_viewport.empty_space_double_clicked.emit()
				_viewport.accept_event()
				return
			_viewport._begin_box_selection(local_position, event.ctrl_pressed or event.meta_pressed)
			_viewport.accept_event()
			return
		var row_data: EventRowData = _viewport._row_at(row_index)
		var metadata: Dictionary = hit.get("span_metadata", {})
		# Click the inline colour swatch -> open the colour picker directly (no params dialog). The
		# renderer stored the swatch's drawn rect in span.metadata; if the click landed inside
		# it and the cell's ACE has a Color param, hand off to the dock's picker popup.
		# R37 - the same swatch, the same picker, on a VARIABLE row. A colour is a colour wherever it
		# is written; the write-back keeps the spelling the line already used.
		if row_data != null and metadata.get("swatch_color") is Color and metadata.get("swatch_rect") is Rect2 \
				and (metadata["swatch_rect"] as Rect2).has_point(local_position) \
				and str(metadata.get("kind", "")) == "variable" and row_data.source_resource is LocalVariable:
			_viewport.color_swatch_edit_requested.emit(
				row_data.source_resource, "", metadata["swatch_color"] as Color
			)
			_viewport.accept_event()
			return
		if row_data != null and metadata.get("swatch_color") is Color and metadata.get("swatch_rect") is Rect2 \
				and (metadata["swatch_rect"] as Rect2).has_point(local_position) and row_data.source_resource is EventRow:
			var swatch_kind: String = str(metadata.get("kind", ""))
			var swatch_ace: Resource = (row_data.source_resource as EventRow).trigger if swatch_kind == "trigger" else _viewport._resolve_ace_resource(row_data.source_resource, "action" if swatch_kind == "action" else "condition", int(metadata.get("ace_index", -1)))
			if swatch_ace != null:
				var color_param: String = _viewport._first_color_param_id(swatch_ace)
				if not color_param.is_empty():
					_viewport.color_swatch_edit_requested.emit(swatch_ace, color_param, metadata["swatch_color"] as Color)
					_viewport.accept_event()
					return
		if row_data != null and row_data.source_resource != null and str(metadata.get("kind", "")) == "add_action":
			_viewport.ace_picker_requested.emit(row_data, "action")
			_viewport.accept_event()
			return
		if row_data != null and row_data.source_resource != null and str(metadata.get("kind", "")) == "add_condition":
			_viewport.ace_picker_requested.emit(row_data, "condition")
			_viewport.accept_event()
			return
		if row_data != null and str(metadata.get("kind", "")) == "add_event":
			_viewport.add_event_requested.emit(metadata.get("add_event_owner", null))
			_viewport.accept_event()
			return
		# The head's Include bar says "open as a sheet", so ONE click does exactly that. It carries
		# its own path, and the dock's navigation probe already knows how to reach it, so this is the
		# same jump Ctrl+Click makes anywhere else - just without the modifier, because the bar offers
		# it in words.
		# P4 - an object bar inside a scene view: a DOUBLE-click opens that node's script as its own
		# sheet, which is where editing happens. A scene view never writes anything itself, so this is
		# the gesture that leads out of it.
		if event.double_click and str(metadata.get("kind", "")) == "scene_object_open" and _viewport.navigation_probe.is_valid() and bool(_viewport.navigation_probe.call(row_data, metadata)):
			_viewport.navigate_requested.emit(row_data, span_index, metadata)
			_viewport.accept_event()
			return
		if not event.double_click and str(metadata.get("kind", "")) == "include_open" and _viewport.navigation_probe.is_valid() and bool(_viewport.navigation_probe.call(row_data, metadata)):
			_viewport.navigate_requested.emit(row_data, span_index, metadata)
			_viewport.accept_event()
			return
		# The head bar's coverage chip counts the script blocks; clicking it walks them, one per
		# click. Same one-click grammar as the Include bar beside it, because the chip ends in ▸ and
		# an arrow that does nothing is worse than no arrow.
		if not event.double_click and str(metadata.get("kind", "")) == "reading_coverage":
			_walk_to_next_script_block()
			_viewport.accept_event()
			return
		# S19 - the ⟡ chip names a pattern; clicking it opens that pattern's page in the Manual, with
		# the hand-written shape and the events shape side by side. The hover already promised this,
		# so the click has to keep the promise.
		if not event.double_click and str(metadata.get("kind", "")) == "pattern_chip":
			EventSheetPatternManual.open_page(str(metadata.get("pattern", "")))
			_viewport.accept_event()
			return
		# W13 - the ƒ chip names a function this sheet declares; clicking it goes there, the way the
		# Outline does. One click, no modifier: the chip is the sheet's own word for "a function, by
		# name", and a name a reader can see is a name they want to be at.
		if not event.double_click and str(metadata.get("kind", "")) == "function_ref":
			_jump_to_function(str(metadata.get("name", "")))
			_viewport.accept_event()
			return
		# X11 - the flags… chip at the end of an Add child row reopens the four ticks the row was
		# written with. One click, like every other chip that ends in an affordance; the viewport
		# only names what was clicked, and the dock owns the dialog and the undoable write.
		if not event.double_click and str(metadata.get("kind", "")) == "hierarchy_flags":
			_viewport.hierarchy_flags_requested.emit(metadata.get("hierarchy_flags", {}))
			_viewport.accept_event()
			return
		# R33. A tool sheet's own buttons, next to the coverage chip and read the same way: one click,
		# one thing happens. The viewport only names the button - compiling and running belong to the
		# dock, which owns the sheet's path and its status line.
		if not event.double_click and str(metadata.get("kind", "")).begins_with("editor_tool_"):
			_viewport.editor_tool_action_requested.emit(str(metadata.get("kind", "")))
			_viewport.accept_event()
			return
		# W20. The same one-click grammar on a sheet that is part of the running editor: Enabled,
		# Reload, Output, plugin.cfg, Edit anyway. The muted words beside them carry a kind too, so a
		# click on "part of this editor · read-only" is swallowed here rather than selecting the bar.
		if not event.double_click and str(metadata.get("kind", "")).begins_with("this_editor_"):
			_viewport.this_editor_action_requested.emit(str(metadata.get("kind", "")))
			_viewport.accept_event()
			return
		if bool(hit.get("fold", false)):
			_viewport._select_from_click(row_index, span_index, false)
			_viewport._toggle_row_fold(row_index)
			return
		# A published verb's Function-block header: ONE click opens its ACE properties. The header
		# carries only ƒ, the name and the input chips, so everything else the verb IS has to be one
		# click away - and the fold arrow (handled just above) still folds, while a parameter cell keeps
		# its own kind, and so its own double-click editor.
		if not event.double_click and not event.ctrl_pressed and not event.meta_pressed and not event.shift_pressed 				and row_data != null and row_data.source_resource is EventFunction 				and row_data.row_type == EventRowData.RowType.EVENT 				and str(metadata.get("kind", "")) == "define_function":
			_viewport._select_from_click(row_index, span_index, false)
			_viewport.verb_properties_requested.emit(row_data.source_resource)
			_viewport.accept_event()
			return
		# N10 - ONE click on a row's OBJECT name opens the object popup: what type it is, where in the
		# scene it lives, which verbs this file uses it with, which of its signals it listens to. The
		# label is drawn inside the leading edge of the cell rather than as its own span, so the
		# renderer stamps its drawn bounds and this hit-tests them - the same seam the colour swatch
		# above uses. Deliberately AFTER the verb header: a ƒ header carries no object label today, so
		# the two cannot collide, and keeping this second means they still cannot if one ever does.
		# Skipped on a double-click or with a modifier, so editing a cell and multi-select are untouched.
		if not event.double_click and not event.ctrl_pressed and not event.meta_pressed and not event.shift_pressed \
				and metadata.get("object_label_rect") is Rect2 \
				and (metadata["object_label_rect"] as Rect2).has_point(local_position) \
				and not str(metadata.get("object_label", "")).is_empty():
			_viewport._select_from_click(row_index, span_index, false)
			_viewport.object_properties_requested.emit(str(metadata.get("object_label", "")))
			_viewport.accept_event()
			return
		# Ctrl+Click go-to-definition: when the clicked cell resolves to a jump target (the dock's
		# probe decides), navigate instead of toggling multi-select - unresolvable cells keep
		# Ctrl+Click's multi-select meaning, so both gestures coexist.
		if (event.ctrl_pressed or event.meta_pressed) and not event.double_click and row_data != null 				and _viewport.navigation_probe.is_valid() and bool(_viewport.navigation_probe.call(row_data, metadata)):
			_viewport.navigate_requested.emit(row_data, span_index, metadata)
			_viewport.accept_event()
			return
		if event.shift_pressed and _viewport._selection_anchor_index >= 0:
			# Shift+click extends a whole-row range from the anchor to the clicked row.
			_viewport._select_range(row_index)
			_viewport.accept_event()
			return
		_viewport._select_from_click(row_index, span_index, event.ctrl_pressed or event.meta_pressed)
		if event.double_click:
			# In-flow GDScript blocks (actions) open the code dialog, not the ACE editor.
			var double_click_meta: Dictionary = hit.get("span_metadata", {})
			if bool(double_click_meta.get("match_action", false)) and row_data != null and row_data.source_resource is EventRow:
				var match_target: Resource = _viewport._resolve_ace_resource(row_data.source_resource, "action", int(double_click_meta.get("ace_index", -1)))
				if match_target is MatchRow:
					_viewport.match_edit_requested.emit(match_target)
					_viewport.accept_event()
					return
			if bool(double_click_meta.get("raw_action", false)) and row_data != null and row_data.source_resource is EventRow:
				var inline_raw: Resource = _viewport._resolve_ace_resource(row_data.source_resource, "action", int(double_click_meta.get("ace_index", -1)))
				if inline_raw is RawCodeRow:
					_viewport.raw_code_edit_requested.emit(inline_raw, true)
					_viewport.accept_event()
					return
			# Action-cell comments open the comment dialog (text + color).
			if bool(double_click_meta.get("action_comment", false)) and row_data != null and row_data.source_resource is EventRow:
				var inline_comment: Resource = _viewport._resolve_ace_resource(row_data.source_resource, "action", int(double_click_meta.get("ace_index", -1)))
				if inline_comment is CommentRow:
					_viewport.comment_edit_requested.emit(inline_comment)
					_viewport.accept_event()
					return
			# Enum rows open the enum dialog.
			if row_data != null and row_data.source_resource is EnumRow:
				_viewport.enum_edit_requested.emit(row_data.source_resource)
				_viewport.accept_event()
				return
			# Custom Block API rows open the kind's schema dialog.
			if row_data != null and row_data.source_resource is CustomBlockRow:
				_viewport.custom_block_edit_requested.emit(row_data.source_resource)
				_viewport.accept_event()
				return
			# Signal rows open the signal dialog.
			if row_data != null and row_data.source_resource is SignalRow:
				_viewport.signal_edit_requested.emit(row_data.source_resource)
				_viewport.accept_event()
				return
			# Define blocks (published verbs) and their description caption. Which double-click does what
			# depends on the CELL: a parameter cell opens the focused param dialog, an inline-editable
			# metadata cell (the name, the category chip, or the description caption) edits that field in
			# place, and anywhere else on the row opens the whole Edit Function dialog. Checked BEFORE the
			# generic open-the-dialog fallthrough, which would otherwise swallow every cell on the row.
			if row_data != null and row_data.source_resource is EventFunction:
				if str(double_click_meta.get("kind", "")) in ["verb_param", "verb_param_add"]:
					if _viewport._maybe_request_ace_edit(hit, row_index):
						_viewport.accept_event()
						return
				if str(double_click_meta.get("edit_kind", "")) in ["verb_display_name", "verb_description", "verb_category"]:
					_viewport._begin_edit(row_index, span_index)
					_viewport.accept_event()
					return
				# The description caption is a COMMENT row whose whole body is the description, so a
				# double-click anywhere on it (not only the exact span) edits the description.
				if row_data.row_type == EventRowData.RowType.COMMENT:
					_viewport._begin_edit(row_index, span_index)
					_viewport.accept_event()
					return
				_viewport.function_edit_requested.emit(row_data.source_resource)
				_viewport.accept_event()
				return
			# Pick-filter rows open the pick-filter dialog.
			if str(double_click_meta.get("kind", "")) == "pick_filter" and row_data != null and row_data.source_resource is EventRow:
				_viewport.pick_filter_edit_requested.emit(row_data.source_resource, int(double_click_meta.get("pick_index", -1)))
				_viewport.accept_event()
				return
			# "With node X:" scope chip opens the target editor.
			if str(double_click_meta.get("kind", "")) == "with_node" and row_data != null and row_data.source_resource is EventRow:
				_viewport.with_node_edit_requested.emit(row_data.source_resource)
				_viewport.accept_event()
				return
			# A collection-declaration entry VALUE edits in place, exactly like a param chip - checked
			# before the generic action branch, which would otherwise try to resolve it as an ACE param.
			if str(double_click_meta.get("edit_kind", "")).begins_with("decl_entry_line:") \
					or str(double_click_meta.get("edit_kind", "")).begins_with("literal_entry_line:"):
				_viewport._begin_edit(row_index, span_index)
				_viewport.accept_event()
				return
			# Single-param inline editing: a double-click landing on a highlighted VALUE
			# within an ACE edits just that parameter.
			var value_kind: String = str(double_click_meta.get("kind", ""))
			if value_kind in ["condition", "trigger", "action"] and row_data != null and row_data.source_resource is EventRow and span_index >= 0 and span_index < row_data.spans.size():
				var value_hit: Array = _viewport._value_text_at(row_data.spans[span_index], local_position.x, _viewport._get_font(), _viewport._get_font_size())
				if not value_hit.is_empty():
					var clicked_lane: String = "action" if value_kind == "action" else "condition"
					var clicked_ace: Resource = row_data.source_resource.trigger if value_kind == "trigger" else _viewport._resolve_ace_resource(row_data.source_resource, clicked_lane, int(double_click_meta.get("ace_index", -1)))
					if clicked_ace != null:
						var clicked_param: String = _viewport.param_id_for_value(clicked_ace, str(value_hit[0]), int(value_hit[1]))
						if not clicked_param.is_empty():
							_viewport.param_value_edit_requested.emit(clicked_ace, clicked_param, str(value_hit[0]))
							_viewport.accept_event()
							return
			# Double-clicking a comment opens its edit dialog (text + colour) - what the user expects
			# from "edit this comment", instead of dropping into a per-line inline caret that reads as a
			# whole-row highlight. The dialog is also the only safe editor for multi-line comment text.
			if row_data != null and row_data.source_resource is CommentRow:
				_viewport.comment_edit_requested.emit(row_data.source_resource)
				_viewport.accept_event()
				return
			if _viewport._maybe_request_ace_edit(hit, row_index):
				_viewport.accept_event()
				return
			# The variable-group chip renames the folder (empty name in the popup ungroups).
			if bool(double_click_meta.get("group_chip", false)) \
					and not str(double_click_meta.get("variable_group", "")).is_empty():
				_viewport.variable_group_rename_requested.emit(str(double_click_meta.get("variable_group")))
				_viewport.accept_event()
				return
			if _viewport._maybe_request_variable_edit(hit, row_index):
				_viewport.accept_event()
				return
			# A "Data class" field value (name / type / default) edits inline: the field rows are inert
			# (null source) so this is the ONLY mutation gesture that reaches them. The raw_row and the
			# field's index ride in the span metadata; the dock re-emits the class from its model.
			if bool(double_click_meta.get("data_class_field_edit", false)) and span_index >= 0 and span_index < row_data.spans.size():
				var field_raw: Variant = double_click_meta.get("raw_row")
				if field_raw is RawCodeRow:
					_viewport.data_class_field_edit_requested.emit(
						field_raw,
						int(double_click_meta.get("field_index", -1)),
						str(double_click_meta.get("part", "")),
						str(row_data.spans[span_index].text)
					)
					_viewport.accept_event()
					return
			if row_data != null and row_data.source_resource is RawCodeRow:
				_viewport.raw_code_edit_requested.emit(row_data.source_resource, false)
				_viewport.accept_event()
				return
			# A ternary pair is a reading of ONE statement, so a double-click anywhere on it - the
			# condition cell and the plain Else row included, neither of which is a real cell - opens that
			# statement's own editor: the code dialog for a hand-written line, the ACE editor for a
			# lifted row.
			if _viewport.request_ternary_statement_edit(row_data):
				_viewport.accept_event()
				return
			_viewport._begin_edit(row_index, span_index)
			_viewport.accept_event()
			return
		if _viewport._maybe_begin_slow_edit(row_index, span_index):
			_viewport.accept_event()
			return
		_viewport._drag_ace_copy_mode = event.ctrl_pressed or event.meta_pressed
		_viewport._drag_row_copy_mode = event.ctrl_pressed or event.meta_pressed
		if _viewport._maybe_begin_ace_drag(hit, row_index):
			# Accept so this control keeps receiving motion/release for the drag.
			_viewport.accept_event()
			return
		_viewport._begin_row_drag(row_index)
		_viewport.accept_event()
		return
	if _viewport._dragging_lane_divider:
		_viewport._dragging_lane_divider = false
		# The guide is a DRAG cue - drop it on release. The next motion re-lights it as a hover cue if
		# the pointer is still on the boundary, so letting go never leaves a stray line on the canvas.
		_viewport.clear_divider_guide()
		_viewport.lane_ratio_changed.emit(_viewport._get_event_style().condition_lane_ratio)
		_viewport.accept_event()
		return
	if not _viewport._dragging_object_column_lane.is_empty():
		var resized_lane: String = _viewport._dragging_object_column_lane
		_viewport._dragging_object_column_lane = ""
		_viewport.clear_divider_guide()
		var event_style: EventSheetEventStyle = _viewport._get_event_style()
		var resized_width: int = event_style.condition_object_column_width if resized_lane == "condition" else event_style.action_object_column_width
		_viewport.object_column_width_changed.emit(resized_lane, resized_width)
		_viewport.accept_event()
		return
	if not _viewport._drag_ace_entries.is_empty():
		_viewport._drag_ace_copy_mode = event.ctrl_pressed or event.meta_pressed
		_viewport._complete_ace_drag()
		_viewport._clear_ace_drag()
		_viewport.queue_redraw()
		return
	if _viewport._drag_row_index >= 0 and _viewport._drag_target_index >= 0 and not _viewport._drag_row_indices.has(_viewport._drag_target_index):
		var target_row: EventRowData = _viewport._row_at(_viewport._drag_target_index)
		# A drop onto another reading of a statement already being dragged is the same no-op as a drop
		# onto the dragged row itself - the index differs, the statement does not.
		if target_row != null and _viewport.drag_targets_dragged_statement(target_row):
			target_row = null
		if target_row != null:
			if _viewport._drag_row_indices.size() > 1:
				var dragged_rows: Array = []
				for source_index in _viewport._drag_row_indices:
					var source_row: EventRowData = _viewport._row_at(source_index)
					if source_row != null:
						dragged_rows.append(source_row)
				if not dragged_rows.is_empty():
					_viewport.rows_drop_requested.emit(dragged_rows, target_row, _viewport._drag_target_mode, _viewport._drag_row_copy_mode)
			else:
				var source_row: EventRowData = _viewport._row_at(_viewport._drag_row_index)
				if source_row != null:
					if _viewport._drag_target_mode == "group":
						# Variable dropped ONTO a variable: fold them into one Inspector-group
						# "folder" (named right after, like a fresh Discord folder) - not a reorder.
						_viewport.variable_group_requested.emit(source_row, target_row)
					else:
						_viewport.row_drop_requested.emit(source_row, target_row, _viewport._drag_target_mode, _viewport._drag_row_copy_mode)
	_viewport._clear_row_drag()
	_viewport.queue_redraw()


func handle_key(event: InputEventKey) -> void:
	if _is_inert_figure():
		return
	if not event.pressed or event.echo:
		return
	if _viewport._editing_row_index >= 0:
		_viewport._handle_editing_key(event)
		return
	# Param scope owns Tab / Esc / Enter / typing while active. The scope is entered explicitly
	# (Enter below), so Tab at plain row scope still falls through to the dock's nest/outdent -
	# the two Tabs never fight.
	if _viewport.param_scope_active():
		if event.keycode in [KEY_TAB, KEY_BACKTAB]:
			_viewport._param_scope_step(-1 if (event.shift_pressed or event.keycode == KEY_BACKTAB) else 1)
			_viewport.accept_event()
			return
		if event.keycode == KEY_ESCAPE:
			_viewport.exit_param_scope()
			_viewport.accept_event()
			return
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER] or (event.unicode > 32 and not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed):
			_viewport._open_param_cursor_editor()
			_viewport.accept_event()
			return
	if (event.keycode == KEY_UP or event.keycode == KEY_DOWN) and event.shift_pressed and not event.alt_pressed:
		# Shift+Arrow grows or shrinks a whole-row range from the selection anchor. From an empty
		# selection it lands on the first row (Shift+Down used to skip past row 0 to row 1).
		if _viewport._selected_row_index < 0:
			_viewport._select_range(0)
		else:
			_viewport._select_range(_viewport.step_selection_index(
				_viewport._selected_row_index, -1 if event.keycode == KEY_UP else 1))
		_viewport.ensure_selection_visible()
		_viewport.accept_event()
	elif event.keycode == KEY_UP and not event.alt_pressed:
		# A ternary pair steps as the ONE row it reads as; Left/Right still walk the cells of whichever
		# row of it the caret is on.
		_viewport._select_row(_viewport.step_selection_index(_viewport._selected_row_index, -1), _viewport._selected_span_index)
		_viewport.ensure_selection_visible()
		_viewport.accept_event()
	elif event.keycode == KEY_DOWN and not event.alt_pressed:
		_viewport._select_row(_viewport.step_selection_index(_viewport._selected_row_index, 1), _viewport._selected_span_index)
		_viewport.ensure_selection_visible()
		_viewport.accept_event()
	elif event.keycode == KEY_BRACKETLEFT and event.ctrl_pressed and event.shift_pressed:
		# Ctrl+Shift+[ collapses the WHOLE sheet - every event and function block, not only
		# the regions. A sheet is browsed by collapsing, so the whole-sheet sweep is what the
		# gesture is worth. Collapsing one block is still one keystroke: plain Left collapses
		# the selected row (left_key_folds / right_key_unfolds on the viewport), which is
		# where the region-scoped gesture this used to run now lives.
		_viewport.collapse_all()
		_viewport.accept_event()
	elif event.keycode == KEY_BRACKETRIGHT and event.ctrl_pressed and event.shift_pressed:
		# Ctrl+Shift+] expands the whole sheet again (plain Right expands one row).
		_viewport.expand_all()
		_viewport.accept_event()
	elif event.keycode == KEY_LEFT and not event.alt_pressed:
		# Plain Left folds; Alt+Left is the dock's jump-history Back and must pass through.
		# With a cell focused OR nothing to fold, Left walks the cell focus instead
		# (the event-sheet arrow-through-cells) - left_key_folds gates on both.
		if _viewport.left_key_folds():
			_viewport._toggle_row_fold(_viewport._selected_row_index)
			_viewport.accept_event()
		elif _viewport.step_cell_focus(-1):
			_viewport.accept_event()
	elif event.keycode == KEY_RIGHT and not event.alt_pressed:
		# Plain Right unfolds; Alt+Right is the dock's jump-history Forward. With a cell
		# focused OR nothing to unfold, Right walks the cell focus instead - the mirror
		# of left_key_folds, so folding can't hijack the walk from either side.
		if _viewport.right_key_unfolds():
			_viewport._toggle_row_fold(_viewport._selected_row_index)
			_viewport.accept_event()
		elif _viewport.step_cell_focus(1):
			_viewport.accept_event()
	elif event.keycode == KEY_B and (event.ctrl_pressed or event.meta_pressed):
		_viewport._toggle_breakpoint(_viewport._selected_row_index)
		_viewport.accept_event()
	elif event.keycode == KEY_M and (event.ctrl_pressed or event.meta_pressed):
		_viewport.toggle_bookmark_selected()
		_viewport.accept_event()
	elif event.keycode == KEY_F4:
		_viewport.jump_to_bookmark(-1 if event.shift_pressed else 1)
		_viewport.accept_event()
	elif event.keycode == KEY_F9:
		# Script-editor convention (Ctrl+B remains as an alias).
		_viewport._toggle_breakpoint(_viewport._selected_row_index)
		_viewport.accept_event()
	elif event.keycode == KEY_SLASH and (event.ctrl_pressed or event.meta_pressed):
		# Ctrl+/: the "comment out" of event sheets - toggle the row's enabled state.
		_viewport.row_disable_toggle_requested.emit()
		_viewport.accept_event()
	elif event.keycode == KEY_UP and event.alt_pressed:
		_viewport.row_move_requested.emit(-1)
		_viewport.accept_event()
	elif event.keycode == KEY_DOWN and event.alt_pressed:
		_viewport.row_move_requested.emit(1)
		_viewport.accept_event()
	elif event.keycode == KEY_F and (event.ctrl_pressed or event.meta_pressed):
		_viewport.find_requested.emit()
		_viewport.accept_event()
	elif event.keycode == KEY_F3:
		_viewport.find_step_requested.emit(-1 if event.shift_pressed else 1)
		_viewport.accept_event()
	elif event.keycode in [KEY_DELETE, KEY_BACKSPACE]:
		# Consume here (the focused viewport) so Delete acts on the event sheet and can NEVER reach
		# the editor's Scene-tree dock, which would delete the selected scene node. The dock does the
		# actual removal via _delete_selected_content (same as its _unhandled_key_input fallback).
		_viewport.delete_requested.emit()
		_viewport.accept_event()
	elif event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		# Param-scope aware: a row with parameter values enters the value cursor; anything else
		# falls back to inline span editing. F2 below stays a pure begin-edit escape hatch.
		_viewport.handle_enter_key()
		_viewport.accept_event()
	elif event.keycode == KEY_F2:
		_viewport._begin_edit(_viewport._selected_row_index, _viewport._selected_span_index)
		_viewport.accept_event()
	elif event.keycode == KEY_ESCAPE:
		# Esc from a focused cell drops back to row selection; with no cell focus the key
		# passes through (lens clear, dialog close keep their meanings).
		if _viewport.clear_cell_focus():
			_viewport.accept_event()


func handle_editing_key(event: InputEventKey) -> void:
	if event.keycode == KEY_ESCAPE:
		_viewport._cancel_edit()
		_viewport.accept_event()
		return
	if event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		_viewport._commit_edit()
		_viewport.accept_event()
		return
	if event.keycode == KEY_BACKSPACE:
		# A selection deletes as one unit (standard text-editing semantics).
		if _viewport._editing_has_selection():
			_viewport._delete_editing_selection()
			_viewport._update_inline_format_bar()
			_viewport.queue_redraw()
		elif _viewport._editing_caret > 0:
			_viewport._editing_buffer = _viewport._editing_buffer.substr(0, _viewport._editing_caret - 1) + _viewport._editing_buffer.substr(_viewport._editing_caret)
			_viewport._editing_caret -= 1
			_viewport.queue_redraw()
		_viewport.accept_event()
		return
	if event.keycode == KEY_LEFT:
		# Shift extends the selection (anchoring on the first shifted move); a plain
		# arrow collapses it.
		if event.shift_pressed and _viewport._editing_select_anchor < 0:
			_viewport._editing_select_anchor = _viewport._editing_caret
		elif not event.shift_pressed:
			_viewport._editing_select_anchor = -1
		_viewport._editing_caret = maxi(_viewport._editing_caret - 1, 0)
		_viewport._update_inline_format_bar()
		_viewport.queue_redraw()
		_viewport.accept_event()
		return
	if event.keycode == KEY_RIGHT:
		if event.shift_pressed and _viewport._editing_select_anchor < 0:
			_viewport._editing_select_anchor = _viewport._editing_caret
		elif not event.shift_pressed:
			_viewport._editing_select_anchor = -1
		_viewport._editing_caret = mini(_viewport._editing_caret + 1, _viewport._editing_buffer.length())
		_viewport._update_inline_format_bar()
		_viewport.queue_redraw()
		_viewport.accept_event()
		return
	if event.keycode == KEY_A and (event.ctrl_pressed or event.meta_pressed):
		_viewport._editing_select_anchor = 0
		_viewport._editing_caret = _viewport._editing_buffer.length()
		_viewport._update_inline_format_bar()
		_viewport.queue_redraw()
		_viewport.accept_event()
		return
	# Discord keyboard parity on comment rows: Ctrl+B/I/U toggles the BBCode wrap on the
	# inline selection (same shortcuts the comment dialog's bar answers to).
	if (event.ctrl_pressed or event.meta_pressed) and event.keycode in [KEY_B, KEY_I, KEY_U] and _viewport._editing_has_selection() and _viewport._editing_span_is_comment():
		match event.keycode:
			KEY_B:
				_viewport._wrap_editing_selection("[b]", "[/b]")
			KEY_I:
				_viewport._wrap_editing_selection("[i]", "[/i]")
			KEY_U:
				_viewport._wrap_editing_selection("[u]", "[/u]")
		_viewport.accept_event()
		return
	if event.unicode > 0 and not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed:
		var typed_char: String = char(event.unicode)
		if not typed_char.is_empty():
			# Typing over a selection replaces it (standard text-editing semantics).
			if _viewport._editing_has_selection():
				_viewport._delete_editing_selection()
				_viewport._update_inline_format_bar()
			_viewport._editing_buffer = _viewport._editing_buffer.substr(0, _viewport._editing_caret) + typed_char + _viewport._editing_buffer.substr(_viewport._editing_caret)
			_viewport._editing_caret += typed_char.length()
			_viewport.queue_redraw()
			_viewport.accept_event()
