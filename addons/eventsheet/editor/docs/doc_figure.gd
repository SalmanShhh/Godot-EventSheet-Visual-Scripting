# EventSheet - EventSheetDocFigure: a live, insertable illustration of event-sheet rows.
#
# A figure is the REAL renderer (EventSheetViewport in figure mode) drawing a REAL
# EventSheetResource, wrapped in a caption and two buttons. That is the whole point: a picture
# of a row can disagree with the editor, and a figure cannot - it is the same code path that
# paints the sheet, in the reader's own theme, at the reader's own scale.
#
# What it is NOT: an editing surface. Figure mode suppresses the "+ Add event…" footer, all
# pointer input, the per-frame poll, and the host-fill sizing, so the illustration is inert and
# exactly as large as its rows.
#
# Two affordances no static picture can carry:
#   - Insert  - hands the rows to EventSheets.insert_snippet(), the public, guarded, one-undo-step
#               insert path (it creates any sheet variables the rows reference).
#   - Copy    - the same snippet text to the clipboard, so a figure travels outside the editor.
#
# Hosts (today the ACE picker's info panel; later a docs page) build one, call set_caption() and
# show_sheet(), and optionally attach a guide affordance. An EMPTY sheet is refused loudly:
# the viewport's getting-started overlay draws real clickable buttons, and an illustration that
# offers "create your first event" is worse than no illustration.
@tool
class_name EventSheetDocFigure
extends VBoxContainer

## The stateful-uid token every figure bakes. Stable on purpose: a figure is an illustration, so
## the same verb must draw the same way every time it is shown (the dock mints a FRESH uid at
## apply time - a figure is not an apply).
const FIGURE_UID := "figure"

## The narrowest a figure will wrap its rows into, before display scaling. Rows keep wrapping down
## to here (a doc page, a dock column); below it they pan instead - see _available_width.
const MIN_LEGIBLE_WIDTH := 480.0

## Emitted when the reader activates the optional guide affordance (see set_guide_action).
signal guide_requested()

## Emitted after a successful Insert, so a host can close itself or update its status line.
signal snippet_inserted()

var _caption: Label = null
var _viewport: EventSheetViewport = null
var _frame: ScrollContainer = null
var _insert_button: Button = null
var _copy_button: Button = null
var _guide_button: Button = null
var _sheet: EventSheetResource = null
## The width ceiling actually handed to the viewport, so a resize that ends where it started - a
## drag back and forth, a re-layout that changes nothing - costs no metrics rebuild at all.
var _applied_width: float = -1.0
var _width_pending: bool = false
## The GDScript the figure's rows compile to, filled on the first hover and kept for the rest of
## the figure's life (its rows never change).
var _gdscript_hover: String = ""


func _init() -> void:
	add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(4.0)))
	_caption = Label.new()
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.visible = false
	add_child(_caption)

	_viewport = EventSheetViewport.new()
	# Before add_child, so _ready sees the flag and leaves the per-frame poll off.
	_viewport.set_figure_mode(true)
	# The rows hang in a horizontal scroller, not directly in the card, for two reasons. A CONTAINER
	# adds its child's minimum width to its own, so a figure in a width-driven page would push the
	# whole column out to the width of its widest row - and since the ceiling is read back off that
	# column, the two would chase each other a few pixels per frame instead of settling. And below
	# the legibility floor the rows PAN rather than shrink further (see _available_width).
	_frame = ScrollContainer.new()
	_frame.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_frame.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_frame.add_child(_viewport)
	# The rows sit in their own card so the illustration reads as a figure, not as loose chrome.
	add_child(EventSheetPopupUI.panel_section(_frame))

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(6.0)))
	buttons.alignment = BoxContainer.ALIGNMENT_END
	add_child(buttons)
	_guide_button = Button.new()
	_guide_button.visible = false
	_guide_button.pressed.connect(func() -> void: guide_requested.emit())
	buttons.add_child(_guide_button)
	# Insert is the figure's answer for "let me try this", and it is the only one. Putting the rows
	# into the sheet the reader already has open, as ONE undo step, is what makes the offer safe:
	# undo puts the sheet back exactly as it was. A separate place to practise in would be a second
	# home for the reader's work with none of that guarantee.
	_insert_button = Button.new()
	_insert_button.text = "Add these events"
	_insert_button.tooltip_text = "Puts these events into the open sheet at the caret, as one undo step."
	_insert_button.pressed.connect(_on_insert_pressed)
	buttons.add_child(_insert_button)
	_copy_button = Button.new()
	_copy_button.text = "Copy"
	_copy_button.tooltip_text = "Copy these rows as shareable snippet text."
	_copy_button.pressed.connect(_on_copy_pressed)
	buttons.add_child(_copy_button)


func _notification(what: int) -> void:
	# A figure is its content, but never WIDER than the surface it sits on: rows that want more
	# room than the host has wrap inside it, exactly as they would in the reader's own sheet at
	# that width. Narrow content still draws narrow - that is the floor this whole seam removed.
	#
	# COALESCED to one apply per frame. Handing the ceiling straight to the viewport rebuilds its
	# row metrics (up to the settle-pass limit), and a resize is not one event: dragging the dock
	# splitter delivers one per pixel, on every figure of the page at once.
	if what == NOTIFICATION_RESIZED and _viewport != null and size.x > 1.0 and not _width_pending:
		_width_pending = true
		_apply_width_ceiling.call_deferred()


func _apply_width_ceiling() -> void:
	_width_pending = false
	if _viewport == null or not is_instance_valid(_viewport):
		return
	var ceiling: float = _available_width()
	if is_equal_approx(ceiling, _applied_width):
		return
	_applied_width = ceiling
	_viewport.set_figure_max_width(ceiling)


## The ceiling the rows wrap into, or 0 for "no ceiling - draw at your natural width".
##
## Down to the legibility floor, a figure re-wraps into its host exactly as the same rows would in
## a sheet that narrow. BELOW the floor it stops shrinking and pans instead: an event row is five
## columns wide by construction, and squeezing them into a dock strip wraps cell text one word -
## and then one LETTER - per line, which illustrates nothing. A figure the reader can push sideways
## still shows real rows; a figure ground into a column of single letters does not.
func _available_width() -> float:
	var available: float = size.x - _card_horizontal_padding()
	if available < EventSheetPalette.scaled_f(MIN_LEGIBLE_WIDTH):
		return 0.0
	return available


## The chrome the rows' card takes out of the widget's own width, so the ceiling handed to the
## viewport is the room the ROWS actually get.
func _card_horizontal_padding() -> float:
	return EventSheetPopupUI.PANEL_SECTION_PAD * 2.0


## The line of prose above the rows. An empty caption hides the label entirely.
func set_caption(text: String) -> void:
	var caption_text: String = EventSheetL10n.translate(text.strip_edges())
	_caption.text = caption_text
	_caption.visible = not caption_text.is_empty()


## Paints `sheet` as the figure. Returns false - and shows nothing - when the sheet is null or
## has no authored rows: an empty sheet would raise the viewport's getting-started overlay,
## whose call-to-action buttons are real click targets, which an illustration must never be.
func show_sheet(sheet: EventSheetResource) -> bool:
	if sheet == null or sheet.events.is_empty():
		push_warning("EventSheetDocFigure: refusing an empty sheet - a figure needs at least one row.")
		_sheet = null
		visible = false
		return false
	_sheet = sheet
	_viewport.set_sheet(sheet)
	visible = true
	# An example is a real event, so it hovers like one: the exact GDScript, one hover away, the
	# same promise the sheet itself makes. Compiled ON DEMAND and remembered - a page can carry a
	# dozen figures, and compiling all of them to fill tooltips nobody may read is a page that
	# stalls when it opens.
	_gdscript_hover = ""
	# Guarded: a host that re-shows a figure (the panel redraws its page on every width change)
	# would otherwise connect the same one-shot twice and the second connect is an error.
	if not _frame.mouse_entered.is_connected(_fill_gdscript_hover):
		_frame.mouse_entered.connect(_fill_gdscript_hover, CONNECT_ONE_SHOT)
	return true


## The GDScript these rows compile to, put on the figure's own hover. Silent when the compiler
## refuses the sheet: a figure with no tooltip reads as a figure, and a figure with an error in
## its tooltip reads as a broken editor.
func _fill_gdscript_hover() -> void:
	if _sheet == null or not _gdscript_hover.is_empty():
		return
	var result: Dictionary = EventSheets.compile(_sheet)
	_gdscript_hover = str(result.get("output", "")).strip_edges()
	if _gdscript_hover.is_empty():
		return
	_frame.tooltip_text = _gdscript_hover


## The sheet currently illustrated, or null when the figure is empty.
func figure_sheet() -> EventSheetResource:
	return _sheet


## The figure's viewport, for a host that needs to restyle it (apply_editor_style) or read its
## measured size (content_width / content_height).
func figure_viewport() -> EventSheetViewport:
	return _viewport


## Shows the optional trailing affordance (Phase 2 wires it to the pack's guide). An empty label
## hides the button again. Clicking it emits guide_requested - this widget never navigates itself.
func set_guide_action(label: String) -> void:
	var button_label: String = EventSheetL10n.translate(label.strip_edges())
	_guide_button.text = button_label
	_guide_button.visible = not button_label.is_empty()


## Hides Insert (a figure shown where there is no sheet to insert into - a standalone preview).
func set_insert_enabled(enabled: bool) -> void:
	_insert_button.visible = enabled


## The figure's rows as shareable snippet text, or "" when the figure is empty.
func snippet_text() -> String:
	if _sheet == null:
		return ""
	return EventSheetSnippet.serialize_rows(_sheet.events, _sheet)


func _on_insert_pressed() -> void:
	var text: String = snippet_text()
	if text.is_empty():
		return
	# as_example: a figure IS the worked example, so its literals land wearing the tune-me marks.
	if EventSheets.insert_snippet(text, "Insert Figure", true):
		snippet_inserted.emit()


func _on_copy_pressed() -> void:
	var text: String = snippet_text()
	if text.is_empty() or not DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		return
	DisplayServer.clipboard_set(text)


# ── Building a figure from vocabulary ─────────────────────────────────────────────────────────


## Puts one verb into the reader's open sheet at the caret, as the row the picker would drop -
## the "Add action" / "Add condition" every reference entry offers, and the Ctrl+Enter of the
## Manual's search. Routed through the same public, guarded, one-undo-step insert path the figure's
## own button uses, so there is one way rows reach a sheet rather than two.
##
## False when there is no sheet open, when the verb is an expression (a value inside a cell has no
## row to add), or when the insert itself refuses - the caller says so rather than reporting a
## silent success.
static func insert_definition(definition: ACEDefinition, label: String = "Add From Manual") -> bool:
	var sheet: EventSheetResource = sheet_for_definition(definition)
	if sheet == null:
		return false
	var text: String = EventSheetSnippet.serialize_rows(sheet.events, sheet)
	if text.is_empty():
		return false
	return EventSheets.insert_snippet(text, label, true)


## A one-row sheet showing `definition` exactly as the picker would drop it: every parameter at
## its resolved default, the codegen template baked, and a stable {uid} so the same verb always
## produces the same figure (the dock bakes a fresh uid at APPLY time; a figure is not an apply).
##
## Returns null for an expression - an expression is a value inside a cell, not a row of its own.
static func sheet_for_definition(definition: ACEDefinition) -> EventSheetResource:
	if definition == null or definition.ace_type == ACEDefinition.ACEType.EXPRESSION:
		return null
	var sheet := EventSheetResource.new()
	var event := EventRow.new()
	var params: Dictionary = ParamDefaultResolver.new().resolve_all(definition, {})
	_fill_empty_slots(definition, params)
	match definition.ace_type:
		ACEDefinition.ACEType.TRIGGER:
			event.trigger_provider_id = definition.provider_id
			event.trigger_id = definition.id
			event.trigger = _condition_for(definition, params)
			event.trigger_params = params.duplicate(true)
		ACEDefinition.ACEType.CONDITION:
			event.conditions.append(_condition_for(definition, params))
		_:
			event.actions.append(_action_for(definition, params))
	sheet.events.append(event)
	return sheet


## A reflected method declares no default for its String parameters, so the resolver answers ""
## and the figure draws the verb as `Advance Objective ( , , 0 )` - an illustration of a broken
## call, on exactly the pack verbs this surface exists to explain. An UNDECLARED empty slot is
## filled with the parameter's own name instead, so the figure reads "the quest id goes here".
## A DECLARED default is never touched, even when it is deliberately an empty string: that is
## what dropping the verb would actually produce, and a figure must not improve on the editor.
## Handles BOTH parameter shapes in the registry - authored ACEParam resources and the plain
## Dictionaries reflection produces - because the resolver only reads Dictionaries, so an
## ACEParam-backed verb (which is most of the pack vocabulary) arrives here with NO values at all.
static func _fill_empty_slots(definition: ACEDefinition, params: Dictionary) -> void:
	for parameter: Variant in definition.parameters:
		var param_id: String = ""
		var label: String = ""
		var value_type: int = TYPE_NIL
		var declared: bool = false
		if parameter is ACEParam:
			var param: ACEParam = parameter as ACEParam
			param_id = param.id if not param.id.strip_edges().is_empty() else param.name
			label = param.get_param_name()
			value_type = param.type
			declared = not param.gdscript_default.strip_edges().is_empty()
		elif parameter is Dictionary:
			var entry: Dictionary = parameter as Dictionary
			param_id = str(entry.get("id", ""))
			label = str(entry.get("display_name", param_id))
			value_type = int(entry.get("type", TYPE_NIL))
			# An EMPTY default_value is how reflection spells "this argument has no default" -
			# the key is always written. An author who really wants an empty string writes the
			# literal `""` as source text, which is two characters and survives this check.
			var default_text: Variant = entry.get("default_value", "")
			declared = entry.has("default_value") and not (default_text is String and str(default_text).is_empty())
		if param_id.strip_edges().is_empty() or declared:
			continue
		# An unfilled slot is an empty string OR a null: the resolver answers "" for a String and
		# null for a type it has no zero value for, and both draw as a gap in the row.
		var existing: Variant = params.get(param_id, null)
		if existing != null and not (existing is String and str(existing).strip_edges().is_empty()):
			continue
		var placeholder: String = _placeholder_for(label if not label.strip_edges().is_empty() else param_id, value_type)
		if not placeholder.is_empty():
			params[param_id] = placeholder


## The value an empty slot shows. Types whose zero value reads as a real answer get it; a String
## names itself, so the reader sees where the quest id goes instead of a gap. Anything whose zero
## value would be a made-up literal (a Vector, a node path) is left empty on purpose - a figure's
## rows are INSERTABLE, and inventing a literal that does not compile is worse than a gap.
static func _placeholder_for(label: String, value_type: int) -> String:
	match value_type:
		TYPE_STRING:
			return "\"%s\"" % label.strip_edges().to_lower()
		TYPE_INT:
			return "0"
		TYPE_FLOAT:
			return "0.0"
		TYPE_BOOL:
			return "false"
	return ""


static func _condition_for(definition: ACEDefinition, params: Dictionary) -> ACECondition:
	var condition := ACECondition.new()
	condition.provider_id = definition.provider_id
	condition.ace_id = definition.id
	condition.params = params.duplicate(true)
	condition.codegen_template = _baked_template(definition)
	var member_template: String = str(definition.metadata.get("member_template", ""))
	if not member_template.is_empty():
		condition.member_declaration = member_template.replace("{uid}", FIGURE_UID)
		condition.codegen_prelude = str(definition.metadata.get("codegen_prelude", "")).replace("{uid}", FIGURE_UID)
		condition.codegen_on_true = str(definition.metadata.get("codegen_on_true", "")).replace("{uid}", FIGURE_UID)
		condition.codegen_on_exit = str(definition.metadata.get("codegen_on_exit", "")).replace("{uid}", FIGURE_UID)
	condition.evaluate_last = bool(definition.metadata.get("evaluate_last", false))
	return condition


static func _action_for(definition: ACEDefinition, params: Dictionary) -> ACEAction:
	var action := ACEAction.new()
	action.provider_id = definition.provider_id
	action.ace_id = definition.id
	action.params = params.duplicate(true)
	action.codegen_template = _baked_template(definition)
	return action


## An explicit @ace_codegen_template wins; a template-less addon method previews the same
## owned-instance call the dock would bake. {uid} is resolved here, never left for the compiler.
static func _baked_template(definition: ACEDefinition) -> String:
	var explicit: String = str(definition.metadata.get("codegen_template", ""))
	if explicit.strip_edges().is_empty():
		explicit = definition.instance_backed_template()
	return explicit.replace("{uid}", FIGURE_UID)
