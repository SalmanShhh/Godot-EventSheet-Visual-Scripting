# Godot EventSheets - Visual theme editor (designer-facing)
# A live theme workbench: the left pane is a REAL EventSheetViewport rendering a sample
# sheet; the right pane is a token form generated REFLECTIVELY from the style resources'
# exported properties (Color → color picker, float/int → spinbox, bool → checkbox), so new
# tokens added to the style classes appear here automatically - no editor changes needed.
# Edits write into a duplicated working style and repaint live; "Apply" assigns it to the
# current sheet, "Save As Preset…" writes a shareable .tres. Every section folds, a token row is named
# in plain words (the Inspector's way) and the strip at the foot says what the token under the pointer does.
@tool
class_name EventSheetThemeEditor
extends RefCounted

const PREVIEW_BASE_WIDTH: float = 720.0
const PREVIEW_MAX_WIDTH: float = 960.0
## What a condition line's words need beside the margin, padding and columns: the trigger's icon, its chip
## padding and "On process" at the sheet's size.
const PREVIEW_WORDS_ROOM: float = 220.0
## Reached by path, at the moment a theme file is asked about: what may be written and where a copy goes.
const FILES_PATH := "res://addons/eventsheet/theme/theme_files.gd"
## The one shape a quick question takes (Save, Discard, Cancel).
const SMALL_PROMPT_PATH := "res://addons/eventsheet/editor/small_prompt.gd"
## The light side of the window (the light swatches, Preview as, the contrast marks), built by path when a theme is opened.
const LIGHT_SIDE_PATH := "res://addons/eventsheet/editor/theme_editor_light.gd"
const FIELD_WORDS_PATH := "res://addons/eventsheet/editor/theme_field_words.gd"
## The words a token that is not a colour or a number wears in the form, where its field name would not be plain.
const TOKEN_LABELS := {"follow_editor_greys": "Follow the editor in light"}

var _dialog: ConfirmationDialog = null
var _preview_viewport: EventSheetViewport = null
var _preview_scroll: ScrollContainer = null
var _working_style: EventSheetEditorStyle = null
var _dock: Control = null
# Quick Style: derive the whole palette from a few colours (no token-by-token tweaking).
var _detail_form: VBoxContainer = null
var _quick_base: ColorPickerButton = null
var _quick_accent: ColorPickerButton = null
var _quick_font: ColorPickerButton = null
# The foot: the strip names the token under the pointer, the note says what Apply and a save did.
var _strip: EventSheetPopupUI.HelpStrip = null
var _this_field: Label = null
var _in_file: Label = null
var _note: EventSheetPopupUI.StateNote = null
var _focus_name: String = ""
var _focus_resource: Resource = null
## The theme file the window edits ("" for Match Editor, or a look that has no file yet), whether it was
## opened on Match Editor, and what the window's own undo list holds. `_clean_depth` is how many steps the
## list held when the file was last opened or saved: the window has changes while its list is any other length.
var _source_path: String = ""
var _from_editor: bool = true
var _edits: Array = []
var _redone: Array = []
var _clean_depth: int = 0
var _save_button: Button = null
var _save_as_button: Button = null
var _revert_button: Button = null
var _theme_field: OptionButton = null
var _close_prompt: ConfirmationDialog = null
var _light_side: RefCounted = null
var _quick_light_base: ColorPickerButton = null
var _quick_light_font: ColorPickerButton = null
var _quick_light_accent: ColorPickerButton = null
## The dark accent the Quick Style pair last held, so a light accent still sitting on it follows the dark one.
var _quick_accent_was: Color = Color("#569eff")
## The words under the Theme field that say what kind of theme is open.
var _theme_note: Label = null


## Opens the theme editor seeded from the dock's active style (or defaults). A window already open with
## changes asks what to do with them before it takes the other theme.
func open(dock: Control, base_style: EventSheetEditorStyle) -> void:
	if _dialog != null and _dialog.visible and is_changed():
		_dock = dock
		_ask_about_changes(func() -> void: _open_fresh(dock, base_style), Callable())
		return
	_open_fresh(dock, base_style)


func _open_fresh(dock: Control, base_style: EventSheetEditorStyle) -> void:
	_prepare(dock, base_style)
	EventSheetWindowPlacement.popup_centered(_dialog, Vector2i(EventSheetPalette.scaled(1240 + roundi(preview_min_width(_working_style) - PREVIEW_BASE_WIDTH)), EventSheetPalette.scaled(640)))


## Everything an open does short of showing the window, so a second open starts the new theme
## over: the form is rebuilt over the new working copy (a swatch left from the first open would
## still edit the first one), the strip and the note say the new session's words, and Quick Style
## starts from the colours of the theme now open.
func _prepare(dock: Control, base_style: EventSheetEditorStyle) -> void:
	_dock = dock
	_working_style = duplicate_style(base_style)
	_source_path = _files().file_of(base_style)
	_from_editor = base_style == null
	var existed: bool = _dialog != null
	_ensure_dialog()
	_adopt(existed)


## Makes the working copy the theme now open (its file is already named in `_source_path`): a clean undo
## list, a form and a preview over it. `rebuild` is false only when the form was just built.
func _adopt(rebuild: bool) -> void:
	_edits.clear()
	_redone.clear()
	_clean_depth = 0
	if rebuild:
		_focus_name = ""
		_rebuild_detail_form()
	_note.say(opening_note(_dock), EventSheetPopupUI.TONE_WARNING)
	_seed_quick_style()
	_fit_preview_width()
	_repaint_preview()
	_refresh_state()


static func _files() -> GDScript:
	return load(FILES_PATH)


## Draws the sample sheet again for the theme as it now is, as the side Preview as names.
func _repaint_preview() -> void:
	if _preview_viewport == null or _working_style == null:
		return
	if _light_side != null:
		_preview_viewport.editor_base_override = _light_side.preview_base()
	_preview_viewport.set_sheet(build_sample_sheet(_working_style, _light_side != null and _light_side.preview_light))


## What the window says about Apply when it opens. A sheet saved as a resource takes the look into itself;
## a script cannot, so a theme kept in a file is remembered for it in the project instead.
static func opening_note(dock: Control) -> String:
	var path_value: Variant = dock.get("_current_sheet_path") if dock != null else null
	if path_value is String and (path_value as String).get_extension() == "gd":
		return EventSheetL10n.translate("Apply keeps a saved theme for this script in this project. Nothing is written into the script.")
	return EventSheetL10n.translate("Apply writes this look into the open sheet only")


## The preview's width, before the display scale, that gives a condition line the room to say "On process"
## whole under this theme: the conditions lane (the margin, its padding, the badge and object columns and the
## words) is only a share of the row, so the row has to be wide enough that the share holds all of that.
## Never narrower than the 720 the preview has always had, and never wider than 960.
static func preview_min_width(style: EventSheetEditorStyle) -> float:
	var event_style: EventSheetEventStyle = style.event_style if style != null else null
	if event_style == null:
		return PREVIEW_BASE_WIDTH
	var lane: float = float(EventSheetPalette.GUTTER_WIDTH) + event_style.condition_lane_padding * 2.0
	lane += event_style.condition_badge_column_width + event_style.condition_object_column_width + PREVIEW_WORDS_ROOM
	var needed: float = maxf(lane, event_style.minimum_conditions_lane_width) / clampf(event_style.condition_lane_ratio, 0.2, 0.8)
	return clampf(needed, PREVIEW_BASE_WIDTH, PREVIEW_MAX_WIDTH)


func _fit_preview_width() -> void:
	if _preview_scroll != null:
		_preview_scroll.custom_minimum_size.x = EventSheetPalette.scaled_f(preview_min_width(_working_style))


## The three colours Quick Style opens on for a theme: its accent, its text, and its base - the row
## colour lifted back by the step Generate darkens it (Generate writes the row colour as the base
## darkened by 0.15, so dividing by 0.85 returns to within rounding of what was picked).
static func quick_style_seed(style: EventSheetEditorStyle) -> Dictionary:
	var event_style: EventSheetEventStyle = style.event_style if style != null else null
	if event_style == null:
		return {}
	var row: Color = event_style.row_background_color
	var seeds: Dictionary = {
		"base": Color(minf(row.r / 0.85, 1.0), minf(row.g / 0.85, 1.0), minf(row.b / 0.85, 1.0), 1.0),
		"accent": event_style.group_accent_color,
		"text": event_style.group_title_color,
	}
	# A theme that holds light colours opens the light pickers on them; any other leaves the light base and text as
	# they are and gives the light accent the dark one, the way one accent always worked.
	seeds["light_accent"] = event_style.group_accent_color
	if load("res://addons/eventsheet/theme/light_colors.gd").has_entries(style):
		var light: EventSheetEventStyle = EventSheetEditorThemeDeriver.sheet_look(style, EventSheetEditorThemeDeriver.NATIVE_LIGHT_REFERENCE_BASE).event_style
		var light_row: Color = light.row_background_color
		seeds["light_base"] = Color(minf(light_row.r / 0.85, 1.0), minf(light_row.g / 0.85, 1.0), minf(light_row.b / 0.85, 1.0), 1.0)
		seeds["light_text"] = light.group_title_color
		seeds["light_accent"] = light.group_accent_color
	return seeds


## Puts the open theme's colours into the Quick Style pickers. A colour the theme leaves clear
## keeps whatever the picker already holds.
func _seed_quick_style() -> void:
	var seeds: Dictionary = quick_style_seed(_working_style)
	if _quick_base == null or seeds.is_empty():
		return
	for pair: Array in [[_quick_base, "base"], [_quick_accent, "accent"], [_quick_font, "text"],
			[_quick_light_base, "light_base"], [_quick_light_font, "light_text"], [_quick_light_accent, "light_accent"]]:
		if not seeds.has(pair[1]):
			continue
		var seeded: Color = seeds[pair[1]]
		if seeded.a > 0.0:
			(pair[0] as ColorPickerButton).color = Color(seeded.r, seeded.g, seeded.b, 1.0)
	_quick_accent_was = _quick_accent.color


## Deep-duplicates a style so live edits never touch the original resource.
static func duplicate_style(base_style: EventSheetEditorStyle) -> EventSheetEditorStyle:
	# With no theme assigned, the sheet is painted by the editor-matched default - so that, and not
	# a bare resource, is what the workbench has to open on. Otherwise the preview shows a look the
	# user is not looking at, and every token that ships with no opinion (all of the Manual's) opens
	# as an empty swatch, which reads as broken rather than as "follow the editor".
	# Missing sub-styles are seeded first, as the sheet seeds them, so a preset saved before the
	# reading / chrome / Manual tokens existed still has every section to edit.
	var style: EventSheetEditorStyle = base_style.duplicate(true) if base_style != null else EventSheetEditorStyle.new()
	style.ensure_defaults()
	if base_style != null:
		return style
	# In the editor that default is Editor Native followed onto the editor's base colour.
	var editor_base: Color = EventSheetEditorThemeDeriver.running_editor_base()
	if editor_base.a > 0.0:
		var matched: EventSheetEditorStyle = EventSheetEditorThemeDeriver.default_style().duplicate(true) as EventSheetEditorStyle
		if EventSheetEditorThemeDeriver.is_light_base(editor_base):
			# A light editor has already moved that look onto its light greys; the swatches name the colours the
			# theme holds, so the window opens on the file's own colours and the Light preview shows the rest.
			var held: EventSheetEditorStyle = _files().project_default_style()
			if held == null:
				held = load(EventSheetEditorThemeDeriver.NATIVE_STARTER_PATH) as EventSheetEditorStyle
			if held != null:
				matched = held.duplicate(true) as EventSheetEditorStyle
				matched.ensure_defaults()
		return matched
	return EventSheetThemeDerivation.fill_derived_tokens(EventSheetGodotTheme.adapt_to_editor(style))


## The sample sheet shown in the preview: one of everything the theme touches.
## `light_ground` draws the sample note that carries a colour of its own in a pale tone, for a light preview.
static func build_sample_sheet(style: EventSheetEditorStyle, light_ground: bool = false) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.editor_style = style
	sheet.variables = {"health": {"type": "int", "default": 100, "exported": true}}
	var group: EventGroup = EventGroup.new()
	group.name = "Gameplay"
	group.group_name = "Gameplay"
	var event: EventRow = _sample_event("OnProcess")
	event.conditions.append(_core(ACECondition.new(), "IsOnFloor"))
	var negated: ACECondition = _core(ACECondition.new(), "IsOnFloor")
	negated.negated = true
	event.conditions.append(negated)
	event.actions.append(_core(ACEAction.new(), "QueueFree"))
	var note: CommentRow = CommentRow.new()
	note.text = "Sub-event comment"
	event.sub_events.append(note)
	group.events.append(event)
	sheet.events.append(group)
	var comment: CommentRow = CommentRow.new()
	comment.text = "Colored comment\nsecond line"
	comment.custom_color = Color(0.96, 0.90, 0.70, 1.0) if light_ground else Color(0.32, 0.27, 0.14, 1.0)
	sheet.events.append(comment)
	# Newer row kinds so the live preview exercises their tokens too (keyword badges,
	# declaration text, color swatches).
	var sample_enum: EnumRow = EnumRow.new()
	sample_enum.enum_name = "State"
	sample_enum.members = PackedStringArray(["IDLE", "RUN"])
	sheet.events.append(sample_enum)
	var sample_signal: SignalRow = SignalRow.new()
	sample_signal.signal_name = "hit"
	sample_signal.params = PackedStringArray(["damage: int"])
	sheet.events.append(sample_signal)
	var tint_event: EventRow = _sample_event("OnReady")
	var tint: ACEAction = _core(ACEAction.new(), "SetModulate")
	tint.codegen_template = "modulate = {color}"
	tint.params = {"color": "Color(0.4, 0.7, 1.0, 1.0)"}
	tint.comment = "Cell note (⊳)"
	tint_event.actions.append(tint)
	# Loop/pick rows, BBCode comments, and a disabled row - the newest vocabulary, so
	# restyling sees everything the renderer can draw.
	var repeat_pick: PickFilter = PickFilter.new()
	repeat_pick.collection_kind = PickFilter.CollectionKind.REPEAT
	repeat_pick.collection_value = "3"
	repeat_pick.iterator_name = "i"
	tint_event.pick_filters.append(repeat_pick)
	sheet.events.append(tint_event)
	var bbcode_comment: CommentRow = CommentRow.new()
	bbcode_comment.text = "[b]Bold[/b], [i]italic[/i] and [color=orange]colored[/color] BBCode"
	sheet.events.append(bbcode_comment)
	# A language block (a pure-data inner class) so the language_block_accent_color token shows live.
	var language_sample: RawCodeRow = RawCodeRow.new()
	language_sample.code = "class Sample:\n\tvar speed: float = 1.0"
	sheet.events.append(language_sample)
	var disabled_event: EventRow = _sample_event("OnReady")
	disabled_event.enabled = false
	disabled_event.actions.append(_core(ACEAction.new(), "QueueFree"))
	sheet.events.append(disabled_event)
	# PUBLISHED VERBS live in sheet.functions - a separate array from sheet.events - and render through
	# build_trailing_verb_rows, so they need no anchor row here. One verb per ROLE, because a role's
	# accent drives its badge, its verb name, the row wash, the accent bar AND its description caption:
	# without all three present, two thirds of the verb tokens cannot be judged while restyling. The
	# parameters exercise the field cells, and the chips cover waits / static / internal / featured.
	var action_verb: EventFunction = EventFunction.new()
	action_verb.function_name = "spawn_pickup"
	action_verb.ace_display_name = "Spawn Pickup"
	action_verb.description = "Drops a pickup at a point, after a short delay."
	action_verb.return_type = TYPE_NIL
	action_verb.expose_as_ace = true
	action_verb.is_async = true
	action_verb.featured = true
	action_verb.params.append(_sample_param("where", "Vector2"))
	action_verb.params.append(_sample_param("pickup_kind", "String", "\"coin\""))
	# A body row, so the verb's open block (and the in-body "Always" cell) restyles live too.
	var verb_body_event: EventRow = EventRow.new()
	verb_body_event.actions.append(_core(ACEAction.new(), "QueueFree"))
	action_verb.events.append(verb_body_event)
	sheet.functions.append(action_verb)
	var condition_verb: EventFunction = EventFunction.new()
	condition_verb.function_name = "can_afford"
	condition_verb.ace_display_name = "Can Afford"
	condition_verb.description = "Answers whether the player can pay a price."
	condition_verb.return_type = TYPE_BOOL
	condition_verb.expose_as_ace = true
	condition_verb.params.append(_sample_param("cost", "int"))
	sheet.functions.append(condition_verb)
	var expression_verb: EventFunction = EventFunction.new()
	expression_verb.function_name = "distance_to_goal"
	expression_verb.ace_display_name = "Distance To Goal"
	expression_verb.return_type = TYPE_FLOAT
	expression_verb.is_static = true
	expression_verb.expose_as_ace = false
	sheet.functions.append(expression_verb)
	return sheet


## A sample event started by one of the core triggers.
static func _sample_event(trigger_id: String) -> EventRow:
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = trigger_id
	return event


## A sample condition or action cell naming one of the core verbs.
static func _core(cell: Resource, ace_id: String) -> Resource:
	cell.set("provider_id", "Core")
	cell.set("ace_id", ace_id)
	return cell


## A sample published-function parameter.
static func _sample_param(param_id: String, type_name: String, default_code: String = "") -> ACEParam:
	var param: ACEParam = ACEParam.new()
	param.id = param_id
	param.type_name = type_name
	param.gdscript_default = default_code
	return param


## Plain-language descriptions of what each theme token does, shown in the strip when its row is pointed at.
## A token not listed here falls back to its humanized name (still readable, just less descriptive).
const _TOKEN_DESCRIPTIONS := {
	"sheet_background_color": "The colour behind the whole sheet, outside the rows.",
	"row_background_color": "The background of a normal event row.",
	"row_background_alt_color": "The background of every OTHER row (the zebra stripe).",
	"row_border_color": "The thin line between rows.",
	"ace_action_badge_background_color": "The pill behind the word \"Action\" on a published function.",
	"ace_action_accent_color": "The Action colour - its badge text, function name, row wash, accent bar and description band.",
	"ace_condition_badge_background_color": "The pill behind the word \"Condition\" on a published function.",
	"ace_condition_accent_color": "The Condition colour - its badge text, function name, row wash, accent bar and description band.",
	"ace_expression_badge_background_color": "The pill behind the word \"Expression\" on a published function.",
	"ace_expression_accent_color": "The Expression colour - its badge text, function name, row wash, accent bar and description band.",
	"verb_row_tint_strength": "Colour-codes a published function's whole row by its kind. Off by default - the role badge already says which kind it is, and tinting every one made a pack read as a wall of blocks. Raise it to bring the colour-coding back.",
	"verb_chip_background_color": "The pill behind a function's \"gives back\", \"waits\", \"static\", \"internal\" and \"featured\" chips.",
	"verb_chip_foreground_color": "The text on those chips. The quieter ones (static, internal) are mixed from this.",
	"condition_lane_color": "A faint tint over the conditions (left) lane.",
	"action_lane_color": "A faint tint over the actions (right) lane.",
	"lane_divider_color": "The vertical line splitting conditions from actions.",
	"condition_lane_ratio": "How much of the row width the conditions lane takes (0.2 - 0.8).",
	"minimum_conditions_lane_width": "The conditions lane never shrinks below this many pixels.",
	"condition_lane_padding": "Inner padding on the conditions lane, in pixels.",
	"condition_badge_column_width": "Width reserved for the trigger/condition badge column.",
	"action_lane_padding": "Inner padding on the actions lane, in pixels.",
	"lane_divider_width": "Thickness of the conditions/actions divider line.",
	"minimum_row_height": "Height of a single event row, in pixels - raise it for more breathing room.",
	"group_row_height": "Height of a Section header bar, in pixels - double an event row by default; lower it for the classic slim bar.",
	"inspector_variable_rows": "Draw a variable row the way the Inspector lists a property: its type, its name exactly as the code writes it, its value and its ## description, with its attributes as icon tiles - no scope word, no kind mark and no code.",
	"variable_row_cards": "Draw each Inspector-style variable row as its own small card - the event card's fill and edge, with a gap to the next - instead of the flat variable wash.",
	"variable_card_fill_color": "The fill of a variable card. Clear uses the event card's fill.",
	"variable_card_border_color": "The one-pixel edge of a variable card. Clear uses the event card's edge.",
	"variable_group_fill_color": "The box behind a run of variables in one Inspector group. Clear keeps the faint tint over the rows.",
	"variable_group_border_color": "The edge of that box. Clear keeps the folder outline.",
	"variable_group_corner_radius": "How round that box's corners are.",
	"hide_compiler_variables": "Leave the bookkeeping variables the compiler writes out of the variable rows: every name starting with two underscores, an author's own included. They still compile and save.",
	"fold_compiler_helpers": "Inside events, stop showing the compiler's two-underscore bookkeeping names: a scene copy kept in such a local is named by its scene file, the line that adds it reads Spawn, its local's row folds into that, and rows that only keep a hidden member up to date fold away. They still compile and save.",
	"inspector_class_head": "Draw the sheet's head as one class head card: icon, name, kind, what it extends, the share mark and the attached scene - no code, no change… word, no scene-fact rows and no + add row (the + Add… menu and the Sheet Type dialog keep those gestures).",
	"add_lines_on_hover": "Show an event's Add condition and Add action lines only while it is hovered or selected, so an event at rest is as tall as its conditions and actions.",
	"trigger_icon_in_gutter": "Draw the event's number on its first line, with the gutter as one column.",
	"lane_chips_yield": "Give the chips after a condition (a trigger's payload) at most two fifths of the conditions lane, so the condition's own words keep their room.",
	"comment_notes": "Draw a comment as a note: the yellow card with a drag grip and a speech-bubble mark before its words, in its own row and inside the action lane (without its # marker), and no code beside it.",
	"selection_as_outline": "Mark a selected event by its filled number gutter and a frame round it, with nothing washed over its conditions and actions.",
	"row_font_size": "The size the sheet's text is drawn at, in pixels at 100% editor scale - never larger than the editor's own font. 0 follows the editor's font size.",
	"condition_object_column_width":"Fixed width of the object-name column in the conditions lane (0 = text flows after each name). Also set by dragging the name/text gap in a row.",
	"action_object_column_width": "Fixed width of the object-name column in the actions lane (0 = text flows after each name). Also set by dragging the name/text gap in a row.",
	"event_block_gap": "Gap opened before an event or Section that starts a new block, in pixels - the air between one event and the next.",
	"sub_event_indent": "How far one nesting level steps a sub-event in, in pixels.",
	"sub_event_rail_line": "Draw the rail a sub-event hangs from - a vertical line down its parent's indent step.",
	"sub_event_strips": "Draw nesting as one thin line per level in the margin, the fold arrow beside a block's first line, and each condition as its own ruled strip over a quieter cell, in place of connector lines.",
	"event_card_border_width": "Thickness of the border round a whole event, in pixels. 0 draws no card and gives each row its own hairline instead.",
	"event_card_gutter_gap": "Gap kept between the number gutter and the card's left edge, so the number reads as a margin mark outside the event.",
	"trigger_badge_background_color": "Fill of the trigger arrow badge (On Ready, On Signal...).",
	"trigger_badge_foreground_color": "Icon/text colour on the trigger badge.",
	"group_background_color": "Background of a Section header row.",
	"group_background_alt_color": "Alternate Section header background (zebra).",
	"group_accent_color": "The Section's top and bottom hairlines.",
	"group_title_color": "The Section title text colour.",
	"group_fold_background_color": "Background of the collapse triangle box on a Section.",
	"comment_row_background_color": "The banner colour behind a full-width comment.",
	"comment_text_color": "The text colour of comments.",
	"selection_fill_color": "The highlight over a selected row.",
	"hover_fill_color": "The tint over the row under the mouse.",
	"column_header_background_color": "Background of the Conditions / Actions column header bar.",
	"column_header_conditions_color": "The 'Conditions' header label colour.",
	"column_header_actions_color": "The 'Actions' header label colour.",
	"invert_marker_color": "The red X shown on an inverted (negated) condition.",
	"trigger_mark_color": "The green arrow in front of a trigger line's object icon.",
	"behaviour_name_color": "A behaviour's name at the head of its action's words.",
	"object_label_color": "The object/origin label before each condition/action (System, node class).",
	"value_highlight_color": "Parameter values (numbers, strings) highlighted inside ACE text.",
	"cell_hover_color": "Tint over a single condition/action cell under the mouse.",
	"behavior_accent_color": "The soft-purple 'this is a behavior' accent (banner, region default).",
	"head_bar_color": "Flat fill of the head bars (the file's line, Input, Variables, Behaviors).",
	"gutter_background_color": "The strip down the left of the sheet that carries the event numbers.",
	"gutter_text_color": "The event numbers themselves.",
	"language_block_accent_color": "The wash on language blocks (a data class, a host binding, a switch case) so they read as code structure, not regular events.",
	"event_corner_radius": "Corner roundness of the event block, in pixels (0 = square).",
	"cell_corner_radius": "Corner roundness of individual condition/action cells.",
	"group_corner_radius": "Corner roundness of Section rows (0 = square bar).",
	"region_corner_radius": "Corner roundness of region marker bubbles.",
	"region_line_width": "Line thickness of region marker borders.",
	"type_number_color": "The type word of a variable that holds a number (int, float).",
	"type_text_color": "The type word of a variable that holds text (String, StringName).",
	"type_bool_color": "The type word of a variable that holds true or false.",
	"type_vector_color": "The type word of a variable that holds a position or direction (Vector2, Vector3).",
	"type_color_color": "The type word of a variable that holds a colour.",
	"type_object_color": "The type word of a variable that holds a node, a scene or a resource.",
	"type_enum_color": "The type word of a variable that holds one of a list of named states (an enum).",
	"type_collection_color": "The type word of a variable that holds a list or a dictionary.",
	"type_class_color": "The type word of a variable whose type is a class declared in the script.",
	"word_variable_color": "A variable's name inside a condition or action sentence. Clear = as before.",
	"word_text_color": "Quoted text inside a condition or action sentence. Clear = the string colour.",
	"word_number_color": "Numbers inside a condition or action sentence. Clear = the value highlight colour.",
	"word_keyword_color": "true, false and other fixed words inside a sentence. Clear = the true/false colour.",
	"include_border_color": "The edge round the Shared sheet line of a sheet that includes a shared one. Clear = no edge.",
	"include_fill_color": "The fill of the Shared sheet line. Clear = the head bar colour.",
	"include_tag_color": "The leading word (Shared sheet, or Include with the Familiar words) and its arrow on the Shared sheet line. Clear = as before.",
	"include_name_color": "The included sheet's name on the Shared sheet line. Clear = the object label colour.",
	"include_note_color": "The plain description at the end of the Shared sheet line. Clear = muted text.",
	"class_border_color": "The edge round a class declared inside the script.",
	"class_fill_color": "The fill behind a class block's fields.",
	"class_head_color": "The fill of a class block's head line.",
	"class_tag_color": "The word CLASS on a class block's head line.",
	"class_name_color": "The class's own name on its head line.",
	"class_note_color": "The plain description of what the class is for.",
	"comment_border_color": "The edge round a full-width comment, so it reads as a note card. Clear = no edge.",
	"gutter_icon_color": "The fold arrow in the margin of the look that nests by lines, and the small icon that says how an event starts.",
	"selected_gutter_fill_color": "The number gutter of a selected event, filled. Clear = the gutter as it is.",
	"object_hairline_color": "The hairline between an object's name and the sentence after it.",
	"link_color": "Words drawn as links on the sheet (Add condition, Add action).",
	"inspector_badge_foreground_color": "The icon on the badge of a variable shown in the Inspector.",
	"inspector_badge_background_color": "The tile behind the Inspector badge.",
	"range_badge_foreground_color": "The icon on the badge of a variable kept in a range.",
	"range_badge_background_color": "The tile behind the range badge.",
	"tooltip_badge_foreground_color": "The icon on the badge of a variable with a tooltip (its ## comment).",
	"tooltip_badge_background_color": "The tile behind the tooltip badge.",
	"saved_badge_foreground_color": "The icon on the badge of a variable the Save System keeps.",
	"saved_badge_background_color": "The tile behind the saved badge.",
	"follow_editor_greys": "Let the sheet's greys follow the editor - dark in a dark editor, light in a light one. A colour you have changed always stays yours.",
	"toolbar_text_labels": "Lay the toolbar out as words - Sheet, Save, Add Event, Add Condition, Add Action, Find and Sentences. Your own View > Text labels choice always wins.",
	"tabs_above_toolbar": "Put the row of open-sheet tabs above the toolbar instead of under it.",
	"status_bar_selection_line": "Let the status bar say what is selected - Event 3 selected, then its conditions - with No problems, the event count and the zoom at its right.",
	"fold_workspace_bands": "Put the sheet straight under the toolbar: no title strip, identity band, Conditions | Actions header or Add event band, and no edge strip for a tucked side rail. The tab names the sheet, the class head's hover says what kind it is, the divider inside an event drags the lane split, and View > Side Rail brings the rail back.",
	"font_size_delta": "Text size adjustment for this chip kind, relative to the sheet font (+/- points).",
	"horizontal_padding": "Space inside the chip, left and right of its text, in pixels.",
	"vertical_padding": "Space inside the chip, above and below its text, in pixels.",
	"gap_after": "Space between this chip and the next one, in pixels.",
	"badge_extra_width": "Extra width reserved for the role badge on the chip, in pixels.",
	"text_color": "The text colour of the chip.",
	"chip_background_color": "Fill of the condition/action chip.",
	"chip_border_color": "Border of the condition/action chip.",
	"chip_hover_color": "Chip fill when hovered.",
	"badge_background_color": "Fill of the role badge on the chip.",
	"badge_foreground_color": "Text colour of the role badge.",
	"corner_radius": "Corner roundness of the chip, in pixels.",
	# ── Reading marks ────────────────────────────────────────────────────────────────────────
	"plain_chip_background_color": "The plain chip on a head bar button (Run now, Reload, Output), the coverage chip, and every other neutral chip in a row.",
	"plain_chip_foreground_color": "The word on those plain chips.",
	"category_chip_background_color": "The chip that says where something sits in the picker (\"Group › Subgroup\").",
	"category_chip_foreground_color": "The word on the picker-category chip.",
	"inspector_chip_background_color": "The \"Inspector\" chip on a variable the game's designer can edit.",
	"inspector_chip_foreground_color": "The word on the Inspector chip.",
	"constant_badge_background_color": "The badge that says a variable is const or static.",
	"constant_badge_foreground_color": "The word on the const / static badge.",
	"setup_badge_background_color": "The dim badge on a setup strip - the ▣ and ⇥ marks that open a head bar.",
	"setup_badge_foreground_color": "The glyph on a setup badge.",
	"code_badge_background_color": "The \"Script block\" pill on a row that kept its GDScript as it was written.",
	"code_badge_foreground_color": "The words on the Script block pill.",
	"lift_note_badge_background_color": "The \"⚠ code\" badge that asks you to look at a line the sheet could not read.",
	"lift_note_badge_foreground_color": "The words on the ⚠ code badge.",
	"or_badge_background_color": "The hairline ruled beside the \"or\" between two OR'd conditions (mixed with the word's own ink so it stays visible).",
	"or_badge_foreground_color": "The word \"or\" on that divider.",
	"tempo_every_tick_background_color": "The ⟳ badge on an event that runs every frame - a tween beat, a repeating timer.",
	"tempo_every_tick_foreground_color": "The glyph on the every-tick badge.",
	"tempo_input_background_color": "The ⌨ badge on an event a key or a button starts.",
	"tempo_input_foreground_color": "The glyph on the input badge.",
	"tempo_once_background_color": "The ▶ badge on an event that runs once.",
	"tempo_once_foreground_color": "The glyph on the runs-once badge.",
	"primary_text_color": "The main word of a row's sentence.",
	"secondary_text_color": "The quieter half of a sentence.",
	"muted_text_color": "The muted detail after it - a head bar's file name and subtitle, an INPUT row's keys.",
	"string_value_color": "Text values inside a parameter (\"coin\"), so magic words are findable by colour.",
	"boolean_value_color": "true and false inside a parameter.",
	"error_text_color": "\"N errors - the game will not run this script\", and the words on a broken row.",
	"error_stripe_color": "The red wash over a row the engine cannot parse, and its number in the margin.",
	"firing_stripe_color": "The wash and margin number that pulse on an event firing right now while the game runs.",
	"disabled_row_color": "The scrim over a row that is switched off.",
	"breakpoint_color": "The breakpoint dot in the event-number margin.",
	"runtime_error_color": "The strip under the sheet that says what just went wrong in the running game, in the row's own words.",
	"debugger_accent_color": "The Debugger window's accent - the pattern notes on its Trail tab.",
	"bookmark_color": "The bookmark pennant in the event-number margin.",
	"event_number_rail_color": "The hairline down the right edge of the event-number margin.",
	"indent_guide_color": "The faint stop that marks each level of indent.",
	"tree_guide_color": "The stronger line from an event down to its sub-events - the one you follow with your eye.",
	"drag_line_color": "The line that shows where a dragged row will land.",
	"drag_refusal_color": "The red a drop turns when it is not allowed.",
	"drag_bubble_refused_background_color": "The bubble that says why a drop was refused (\"dealt is not visible here\").",
	"drag_bubble_background_color": "The same bubble when the drop is fine.",
	"drag_bubble_text_color": "The words in that bubble.",
	"text_selection_color": "The band behind selected text while you are editing a cell.",
	"default_chip_plate_color": "The plate a chip sits on when it brought no colour of its own.",
	"variable_row_wash_color": "The flat tint behind every variable row, so a declaration never reads as an event.",
	"variable_row_rule_color": "The ink a variable's scope word wears, and the hairline that closes a block of globals.",
	"variable_row_wash_end_color": "The right-edge colour of an optional fade across that wash. Same as the wash means flat.",
	"color_swatch_border_color": "The outline around a colour value's swatch, so a pale colour still reads as a swatch.",
	"name_highlight_strength": "How strongly every other use of a hovered variable lights up, inside that variable's own scope.",
	# ── Bars around the sheet ────────────────────────────────────────────────────────────────
	"object_bar_section_color": "The headings down the Object bar (SCENE, GLOBALS, INPUT) and the row count beside each entry.",
	"object_bar_warning_color": "The amber of every finding - the ⚠ on an Object bar entry, the mark beside a flagged row, the help strip's finding words: a node the scene lost, an action the Input Map does not have.",
	"object_bar_hover_wash_color": "The wash over every row that uses the object you point at in the Object bar.",
	"object_bar_grip_color": "The grab dots on the row under the mouse.",
	"object_bar_grip_active_color": "Those dots once the pointer is in the grab zone.",
	"status_text_color": "The message along the bottom of the dock.",
	"status_error_color": "That message when something went wrong.",
	"row_address_color": "The row address beside it (\"event 12 ▸ action 2\").",
	"unsaved_dot_color": "The ● that says this sheet has edits you have not saved.",
	"title_path_color": "The file path printed beside the sheet's name.",
	"active_tab_edge_color": "A line along the top of the open sheet's tab, so it reads as the one in front. Clear = the tab as the editor draws it.",
	"status_ok_color": "The colour of No problems in the status bar. Clear = the same quiet colour as the counts beside it.",
	# ── The minimap column ───────────────────────────────────────────────────────────────────
	"minimap_background_color": "The sunken column down the right edge of a long sheet.",
	"minimap_window_color": "The box over the part of the sheet you are looking at.",
	"minimap_window_border_color": "The line around that box.",
	"minimap_trigger_color": "A trigger's bar in the column.",
	"minimap_tick_color": "An every-tick event's bar.",
	"minimap_function_color": "A function's bar.",
	"minimap_group_color": "A Section's bar.",
	"minimap_comment_color": "A comment's bar.",
	"minimap_script_color": "A Script block's bar.",
	"minimap_event_color": "Every other event's bar.",
	"minimap_disabled_color": "A disabled row's bar - present, but not asking to be read.",
	"minimap_bookmark_color": "The mark in the margin beside a row you bookmarked.",
	"minimap_finding_color": "The mark beside a row the sheet flagged.",
	"minimap_band_color": "The band a Section paints down the column, from its own row to its last.",
	# ── The Sheet map window ─────────────────────────────────────────────────────────────────
	"sheet_map_sheet_color": "An event sheet's box in the Sheet map.",
	"sheet_map_scene_color": "A scene's box - the scenes that carry the sheets.",
	"sheet_map_global_color": "A global's box - the autoloads and globals the sheets call.",
	"sheet_map_edge_color": "The quiet line between two boxes: an include, a call, a layout change.",
	"sheet_map_signal_edge_color": "The warm line for a signal connection - wiring that fires at runtime.",
	"sheet_map_text_color": "The name written inside every box in the Sheet map.",
	# ── The Inspector drawers ────────────────────────────────────────────────────────────────
	"drawer_accent_color": "The fill of every interactive drawer in the Inspector - a progress bar's filled part, a range slider's span, a dial's vector line.",
	"drawer_ink_color": "The quiet ink the drawers write and rule with - value labels, hairlines, the dial's grid. Each mark keeps its own softness.",
	"drawer_well_color": "The sunken plate a bar, track or preview sits in.",
	"drawer_handle_border_color": "The line around each handle.",
	"drawer_required_color": "The ⚠ that says a required property still has no value.",
	"drawer_validate_color": "The ⚠ message a sheet's own validator function returns while a value is out of bounds.",
	"drawer_checker_dark_color": "The darker square of the checkerboard behind a texture thumbnail.",
	"drawer_checker_light_color": "The lighter square of that checkerboard.",
	# ── The Anatomy rail ─────────────────────────────────────────────────────────────────────
	"anatomy_trigger_pill_background_color": "The ➜ pill beside a trigger in the Anatomy rail (Editor Tools wear it too - the editor calls those the way it calls a trigger).",
	"anatomy_trigger_pill_foreground_color": "The glyph on that pill.",
	"anatomy_knob_pill_foreground_color": "The @ on a designer knob's chip in the Anatomy rail.",
	# ── Manual pages ─────────────────────────────────────────────────────────────────────────
	"page_muted_text_color": "Captions, breadcrumbs and the quiet words on a Manual page. Clear = follow the editor.",
	"page_background_color": "The paper behind a Manual page. Leave it clear and the Manual sits on the editor's own background, the way it ships.",
	"heading_color": "Headings on a Manual page. Clear = follow the editor's own text colour.",
	"search_hit_color": "The highlight behind a search hit inside a page.",
	"contents_active_background_color": "The pill on the contents entry for the page you are reading. Clear = the editor's accent.",
	"contents_active_text_color": "The word on that pill.",
	"note_color": "The note above a row its pack has deprecated.",
	"table_hairline_color": "The rule under a table's header row on a page.",
}


## The description for a token (falls back to its humanized name).
static func _token_description(token_name: String) -> String:
	return str(_TOKEN_DESCRIPTIONS.get(token_name, token_name.capitalize()))


## Exported tokens of a style resource that the form can edit (Color/float/int/bool).
static func editable_tokens(style_resource: Resource) -> Array[Dictionary]:
	var tokens: Array[Dictionary] = []
	if style_resource == null:
		return tokens
	for property_info: Dictionary in style_resource.get_property_list():
		# A stored-only value (a retired token kept so old theme files still load) is not a setting.
		if not (property_info.get("usage", 0) & PROPERTY_USAGE_SCRIPT_VARIABLE) \
				or not (property_info.get("usage", 0) & PROPERTY_USAGE_EDITOR):
			continue
		var token_type: int = int(property_info.get("type", TYPE_NIL))
		if token_type in [TYPE_COLOR, TYPE_FLOAT, TYPE_INT, TYPE_BOOL]:
			tokens.append({
				"name": str(property_info.get("name")),
				"type": token_type,
				"hint": int(property_info.get("hint", PROPERTY_HINT_NONE)),
				"hint_string": str(property_info.get("hint_string", "")),
			})
	return tokens


## The spin box range for one number token: the token's own @export_range when it declares one
## (min, max and step), otherwise a wide default. A float token with no range steps 0.01, an int 1.
static func spin_range(token: Dictionary) -> Dictionary:
	var is_float: bool = int(token.get("type")) == TYPE_FLOAT
	var spin_bounds: Dictionary = {"min": -4096.0, "max": 4096.0, "step": 0.01 if is_float else 1.0}
	if int(token.get("hint", PROPERTY_HINT_NONE)) != PROPERTY_HINT_RANGE:
		return spin_bounds
	var parts: PackedStringArray = str(token.get("hint_string", "")).split(",")
	if parts.size() >= 2 and parts[0].strip_edges().is_valid_float() and parts[1].strip_edges().is_valid_float():
		spin_bounds["min"] = parts[0].strip_edges().to_float()
		spin_bounds["max"] = parts[1].strip_edges().to_float()
	if parts.size() >= 3 and parts[2].strip_edges().is_valid_float():
		spin_bounds["step"] = parts[2].strip_edges().to_float()
	return spin_bounds


## Writes one token and reports whether the value actually changed.
static func apply_token(style_resource: Resource, token_name: String, value: Variant) -> bool:
	if style_resource == null or style_resource.get(token_name) == value:
		return false
	style_resource.set(token_name, value)
	return true


## What a save to `path` will do, for the foot of the save dialog: it names the file it replaces, and
## says nothing for a new one.
static func save_note(path: String) -> String:
	if path.get_file().is_empty() or not FileAccess.file_exists(path):
		return ""
	return EventSheetL10n.translate("Replaces %s") % path.get_file()


## The line a token writes into a saved preset, as the .tres spells it.
static func file_line(style_resource: Resource, token_name: String) -> String:
	return "%s = %s" % [token_name, var_to_str(style_resource.get(token_name))]


func _ensure_dialog() -> void:
	if _dialog != null:
		return
	var parts: Dictionary = EventSheetPopupUI.action_window(EventSheetL10n.translate("Theme Editor"),
		EventSheetL10n.translate("Apply To Current Sheet"), EventSheetL10n.translate("Close"), Vector2i(1000, 600), _dock)
	_dialog = parts["window"]
	_dialog.confirmed.connect(_apply_to_sheet)
	_note = parts["note"]
	# Revert, Save As and Save (or Save a Copy) sit between the note and the two closing buttons, the
	# buttons that write nothing on the left of the ones that write the file.
	_save_button = _dialog.add_button("", false, "save")
	_save_as_button = _dialog.add_button(EventSheetL10n.translate("Save As…"), false, "save_as")
	_revert_button = _dialog.add_button(EventSheetL10n.translate("Revert"), false, "revert")
	for button: Button in [_save_button, _save_as_button, _revert_button]:
		button.get_parent().move_child(button, _note.get_index() + 1)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_dialog.custom_action.connect(_on_custom_action)
	_dialog.canceled.connect(_on_window_closed)
	_dialog.window_input.connect(_on_window_input)
	_light_side = load(LIGHT_SIDE_PATH).new(self)
	var split: HSplitContainer = HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_scroll = ScrollContainer.new()
	_preview_scroll.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(preview_min_width(_working_style)), EventSheetPalette.scaled_f(440.0))
	_preview_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_viewport = EventSheetViewport.new()
	_preview_scroll.add_child(_preview_viewport)
	# Above the sample sheet: which side of the theme it is drawn as.
	var preview_side: VBoxContainer = VBoxContainer.new()
	preview_side.add_child(_light_side.build_preview_header())
	preview_side.add_child(_preview_scroll)
	split.add_child(preview_side)
	var form_scroll: ScrollContainer = ScrollContainer.new()
	form_scroll.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(460.0), 0.0)
	form_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var form: VBoxContainer = EventSheetPopupUI.form_box()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# The theme field first: which theme this window edits, and the way to another without closing it.
	_build_theme_field(form)
	# Quick Style (whole-palette recolour) next, then how the letters are SHAPED, then the
	# per-token detail form below both.
	_build_quick_style(form)
	_build_reading_comfort(form)
	_detail_form = EventSheetPopupUI.form_box()
	form.add_child(_detail_form)
	form_scroll.add_child(form)
	split.add_child(form_scroll)
	var box: VBoxContainer = parts["box"]
	box.add_child(split)
	# The strip says what the token under the pointer does and the line it writes into a preset.
	_strip = EventSheetPopupUI.help_strip()
	_this_field = _strip.add_line(EventSheetL10n.translate("THIS FIELD"), true)
	_in_file = _strip.add_line(EventSheetL10n.translate("IN FILE"))
	_in_file.add_theme_font_override("font", _strip.in_code_value.get_theme_font("font"))
	# What the small signs beside the swatches mean: one line that stays in view under the scrolling form.
	box.add_child(_light_side.build_legend())
	box.add_child(_strip)
	_rebuild_detail_form()


## A section of the form that folds under its title, open or folded to start.
static func _fold(title: String, content: Control, open: bool) -> FoldableContainer:
	var fold: FoldableContainer = FoldableContainer.new()
	fold.title = title
	fold.folded = not open
	fold.add_child(content)
	return fold


## Quick Style - three colours drive the whole palette (base tone, accent, text). One
## button regenerates every colour token via EventSheetGodotTheme.apply, so re-skinning is
## "pick a colour, click Generate" instead of tuning thirty fields by hand.
func _build_quick_style(form: VBoxContainer) -> void:
	var quick_box: VBoxContainer = EventSheetPopupUI.form_box()
	quick_box.add_child(EventSheetPopupUI.hint_label(EventSheetL10n.translate("A base for dark and a base for light, one accent, a text colour for each. Generate fills both columns at once; anything you then change by hand stays yours.")))
	quick_box.add_child(_light_side.column_header())
	var base_pickers: Array[ColorPickerButton] = _quick_pair_row(quick_box, EventSheetL10n.translate("Base (background tone)"), Color("#252525"), Color("#e6e6e6"))
	_quick_base = base_pickers[0]
	_quick_light_base = base_pickers[1]
	var accent_pickers: Array[ColorPickerButton] = _quick_pair_row(quick_box, EventSheetL10n.translate("Accent (Sections, selection)"), Color("#569eff"), Color("#569eff"))
	_quick_accent = accent_pickers[0]
	_quick_light_accent = accent_pickers[1]
	# One accent still works: until the light one is picked on its own it moves with the dark one.
	_quick_accent.color_changed.connect(func(value: Color) -> void:
		if _quick_light_accent.color == _quick_accent_was:
			_quick_light_accent.color = value
		_quick_accent_was = value)
	var font_pickers: Array[ColorPickerButton] = _quick_pair_row(quick_box, EventSheetL10n.translate("Text"), Color("#ced0d2"), Color("#0f0f0f"))
	_quick_font = font_pickers[0]
	_quick_light_font = font_pickers[1]
	var buttons: HBoxContainer = HBoxContainer.new()
	var reset: Button = Button.new()
	reset.text = EventSheetL10n.translate("Reset To Default")
	reset.tooltip_text = EventSheetL10n.translate("Restore the bundled default look.")
	reset.pressed.connect(_reset_to_default)
	buttons.add_child(reset)
	var generate: Button = Button.new()
	generate.text = EventSheetL10n.translate("Generate Theme")
	generate.tooltip_text = EventSheetL10n.translate("Rebuild every colour token, dark and light, from the colours above.")
	generate.pressed.connect(_generate_quick_style)
	buttons.add_child(generate)
	quick_box.add_child(buttons)
	form.add_child(_fold(EventSheetL10n.translate("Quick Style - recolour everything at once"), quick_box, true))


## How the letters are shaped, as opposed to what colour they are. Two settings, both personal
## rather than part of the theme file: they follow the reader from project to project instead of
## arriving in a teammate's checkout inside a saved preset.
##
## No typeface is bundled with the plugin - shipping one would put a font licence into everyone's
## project for a preference most readers will not turn on. Left empty, the sheet keeps the
## editor's own font and simply opens the spacing up, which is most of what helps; readers who
## already have a dyslexia-friendly face installed (OpenDyslexic and Atkinson Hyperlegible are
## the two usually meant) point the field at it.
func _build_reading_comfort(form: VBoxContainer) -> void:
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	box.add_child(EventSheetPopupUI.hint_label(EventSheetL10n.translate("Personal, not part of the theme file - these follow you, not the project.")))
	var dyslexia_check: CheckBox = CheckBox.new()
	dyslexia_check.text = EventSheetL10n.translate("Dyslexia-friendly text")
	dyslexia_check.tooltip_text = EventSheetL10n.translate("Opens the letters and the word spaces up. Works with any font.")
	dyslexia_check.button_pressed = EventSheetAccessibility.dyslexia_friendly_text()
	dyslexia_check.toggled.connect(func(pressed: bool) -> void:
		EventSheetAccessibility.set_dyslexia_friendly_text(pressed)
		_repaint_personal())
	box.add_child(dyslexia_check)
	var font_edit: LineEdit = LineEdit.new()
	# The field is short; the words that say what goes in it have a line of their own, whole, above it.
	font_edit.placeholder_text = "res://…"
	font_edit.text = EventSheetAccessibility.reading_font_path()
	font_edit.text_submitted.connect(func(path: String) -> void:
		EventSheetAccessibility.set_reading_font_path(path)
		_repaint_personal())
	box.add_child(EventSheetPopupUI.hint_label(EventSheetL10n.translate("res://… .ttf or .otf - blank keeps the editor's own font")))
	box.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Reading font"), font_edit))
	form.add_child(_fold(EventSheetL10n.translate("Reading Comfort"), box, true))


## A labelled row of two colour pickers, the dark one and the light one, returned in that order.
func _quick_pair_row(form: VBoxContainer, label_text: String, dark_default: Color, light_default: Color) -> Array[ColorPickerButton]:
	var dark_picker: ColorPickerButton = ColorPickerButton.new()
	dark_picker.color = dark_default
	var row: HBoxContainer = EventSheetPopupUI.form_row(label_text, dark_picker, EventSheetPalette.scaled_f(load(LIGHT_SIDE_PATH).NAME_COLUMN_WIDTH))
	var light_picker: ColorPickerButton = ColorPickerButton.new()
	light_picker.color = light_default
	light_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var link_room: Control = Control.new()
	link_room.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(28.0), 0.0)
	row.add_child(link_room)
	row.add_child(light_picker)
	form.add_child(row)
	return [dark_picker, light_picker]


## Derives the two dark tones from the base, regenerates the whole sheet palette, then does the same again
## for the light pickers and keeps what differs as the theme's light colours, and refreshes the detail
## form + live preview.
func _generate_quick_style() -> void:
	var base: Color = _quick_base.color
	var before: EventSheetEditorStyle = _working_style.duplicate(true) as EventSheetEditorStyle
	EventSheetGodotTheme.apply(_working_style, base, base.darkened(0.15), base.darkened(0.25), _quick_accent.color, _quick_font.color)
	_light_side.generate(_quick_light_base.color, _quick_light_accent.color, _quick_light_font.color)
	_record_whole(before, _working_style)
	_reset_to_default(_working_style, false)


## Restores the bundled default look - a clean starting point - or shows `style` afresh.
func _reset_to_default(style: EventSheetEditorStyle = duplicate_style(null), reseed: bool = true) -> void:
	if style != _working_style:
		_record_whole(_working_style, style)
		restore_values(_working_style, style)
	_rebuild_detail_form()
	_fit_preview_width()
	if reseed:
		_seed_quick_style()
	_repaint_preview()
	_refresh_state()


## (Re)builds the reflective per-token form into _detail_form, clearing any prior fields so
## the spinboxes/pickers always reflect the current (possibly just-regenerated) style. The token
## the strip was describing is described again from the rebuilt style.
func _rebuild_detail_form() -> void:
	_light_side.forget_rows()
	for child: Node in _detail_form.get_children():
		_detail_form.remove_child(child)
		child.queue_free()
	_focus_resource = null
	_build_section(_detail_form, EventSheetL10n.translate("Editor (hover, selection, lanes)"), _working_style, true)
	_build_section(_detail_form, EventSheetL10n.translate("Sheet & rows (event style)"), _working_style.event_style, true)
	_build_section(_detail_form, EventSheetL10n.translate("Condition cells"), _working_style.condition_style, false)
	_build_section(_detail_form, EventSheetL10n.translate("Action cells"), _working_style.action_style, false)
	_build_section(_detail_form, EventSheetL10n.translate("Reading marks - chips, badges, guides, stripes"), _working_style.reading_style, false)
	_build_section(_detail_form, EventSheetL10n.translate("Bars around the sheet - Object bar, status strip, tab title"), _working_style.chrome_style, false)
	_build_section(_detail_form, EventSheetL10n.translate("Manual pages"), _working_style.manual_style, false)


## One row per editable token, reflectively, in a section that folds. A row is named exactly as the
## code names the token, and pointing at it puts its description and its preset line in the strip.
func _build_section(form: VBoxContainer, title: String, style_resource: Resource, open: bool) -> void:
	# A section with nothing to edit is not shown at all. The top-level style carries only the
	# sub-styles themselves, so its card came up empty under a heading that promised hover and
	# selection colours - a designer reasonably read that as "the tokens failed to load".
	var section_tokens: Array[Dictionary] = editable_tokens(style_resource)
	if section_tokens.is_empty():
		return
	var section_box: VBoxContainer = EventSheetPopupUI.form_box()
	var has_light_side: bool = _light_side.supports(style_resource)
	if has_light_side:
		section_box.add_child(_light_side.column_header())
	for token: Dictionary in section_tokens:
		var token_name: String = str(token.get("name"))
		var field: Control = null
		match int(token.get("type")):
			TYPE_COLOR:
				var picker: ColorPickerButton = ColorPickerButton.new()
				picker.color = style_resource.get(token_name)
				picker.color_changed.connect(func(value: Color) -> void: _on_token_edited(style_resource, token_name, value))
				field = picker
			TYPE_BOOL:
				var check: CheckBox = CheckBox.new()
				check.button_pressed = bool(style_resource.get(token_name))
				check.toggled.connect(func(value: bool) -> void: _on_token_edited(style_resource, token_name, value))
				field = check
			_:
				var spin: SpinBox = SpinBox.new()
				var spin_bounds: Dictionary = spin_range(token)
				spin.step = float(spin_bounds["step"])
				spin.min_value = float(spin_bounds["min"])
				spin.max_value = float(spin_bounds["max"])
				spin.value = float(style_resource.get(token_name))
				spin.value_changed.connect(func(value: float) -> void: _on_token_edited(style_resource, token_name, value if int(token.get("type")) == TYPE_FLOAT else int(value)))
				field = spin
		# The label is the field's name in plain words, the way Godot's own Inspector spells a property
		# (follow_editor_greys reads "Follow Editor Greys"); the exact field name is in the strip.
		var row: HBoxContainer = EventSheetPopupUI.form_row(token_label(token_name), field)
		row.get_child(0).auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		row.set_meta("token", token_name)
		row.set_meta("style_id", style_resource.get_instance_id())
		for part: Control in [row, row.get_child(0), field]:
			part.mouse_entered.connect(_focus_token.bind(style_resource, token_name))
		field.focus_entered.connect(_focus_token.bind(style_resource, token_name))
		# A colour has a light side beside it: the chain, the light swatch and the mark of a hard-to-read pair.
		if has_light_side and int(token.get("type")) == TYPE_COLOR:
			_light_side.add_controls(row, style_resource, token_name, _focus_token.bind(style_resource, token_name))
		if _focus_resource == null and (_focus_name.is_empty() or _focus_name == token_name):
			_focus_token(style_resource, token_name)
		section_box.add_child(row)
	form.add_child(_fold(title, section_box, open))


## A description written with the word Section, said with the word the sheet uses for that block: Section
## by default, Group under the Familiar words preset.
static func fit_section_word(text: String) -> String:
	var word: String = EventSheetWords.word("section_block")
	if word == "Section":
		return text
	return text.replace("Section", word).replace("section", word.to_lower())


## The name a token wears in the form: its field name in plain words, the way Godot's own Inspector spells a
## property, unless the field name would not be plain.
static func token_label(token_name: String) -> String:
	if TOKEN_LABELS.has(token_name):
		return EventSheetL10n.translate(str(TOKEN_LABELS[token_name]))
	return token_name.capitalize()


## Puts one token in the strip: what it does, how it reads when it is words on a ground, and the lines it
## writes into a saved preset (the dark one and, for a colour with a light side, the light one).
func _focus_token(style_resource: Resource, token_name: String) -> void:
	_focus_name = token_name
	_focus_resource = style_resource
	if _strip != null:
		var said: String = "%s: %s" % [token_name, fit_section_word(EventSheetL10n.translate(_token_description(token_name)))]
		var in_file: String = file_line(style_resource, token_name)
		if _light_side != null and _light_side.supports(style_resource) and typeof(style_resource.get(token_name)) == TYPE_COLOR:
			var contrast: String = _light_side.contrast_sentence(style_resource, token_name)
			if not contrast.is_empty():
				said += " " + contrast
			in_file += "\n" + _light_side.light_file_line(style_resource, token_name)
		_strip.set_line(_this_field, said)
		_strip.set_line(_in_file, in_file)


func _on_token_edited(style_resource: Resource, token_name: String, value: Variant) -> void:
	var old_value: Variant = style_resource.get(token_name)
	if apply_token(style_resource, token_name, value) and _preview_viewport != null:
		_record_edit({"style": style_resource, "token": token_name, "from": old_value, "to": value})
		_light_side.invalidate()
		_light_side.refresh_all()
		# Rebuild the sample sheet so BOTH colour and STRUCTURAL tokens (row height, corner radii, lane
		# widths, line thickness) show live - a plain repaint keeps the old cached layout.
		_repaint_preview()
		_focus_token(style_resource, token_name)


## Redraws the preview and the open sheet after a personal reading setting changed. Nothing is written
## into the sheet: the workbench theme is still unsaved, and these settings belong to the reader.
func _repaint_personal() -> void:
	if _preview_viewport != null and _working_style != null:
		_repaint_preview()
	if _dock == null:
		return
	var dock_viewport: Variant = _dock.get("_viewport")
	var dock_sheet: Variant = _dock.get("_current_sheet")
	if dock_viewport is EventSheetViewport and dock_sheet != null:
		(dock_viewport as EventSheetViewport).set_sheet(dock_sheet)


func _apply_to_sheet() -> void:
	if _dock == null or not _dock.has_method("apply_theme_style"):
		return
	# A script cannot hold a look, so a theme kept in a saved file is remembered for it by that file;
	# anything else is worn for the session.
	if not _source_path.is_empty() and not is_changed() and _is_script_sheet() and _dock.has_method("load_theme_style_from_path"):
		_dock.call("load_theme_style_from_path", _source_path)
		return
	_dock.call("apply_theme_style", _working_style.duplicate(true))


func _is_script_sheet() -> bool:
	var path_value: Variant = _dock.get("_current_sheet_path") if _dock != null else null
	return path_value is String and (path_value as String).get_extension() == "gd"


# ── The file the window edits ─────────────────────────────────────────────────────────────────────


## Whether the window holds changes the file does not: its undo list is not the length it had when the
## file was opened or last saved.
func is_changed() -> bool:
	return _edits.size() != _clean_depth


## The name the window gives the theme it edits: the file's, Match Editor while nothing is changed, or an
## untitled theme once a look with no file has been changed.
func theme_name() -> String:
	if not _source_path.is_empty():
		return _source_path.get_file()
	if _from_editor and not is_changed():
		return EventSheetL10n.translate("Match Editor")
	return EventSheetL10n.translate("Untitled theme")


func window_title() -> String:
	var title: String = EventSheetL10n.translate("Theme Editor - %s") % theme_name()
	if is_changed():
		title = EventSheetL10n.translate("%s (changed)") % title
	return title


## The words on the button that writes the file: Save for a theme of the project's own, Save a Copy for a
## starter or a demo (the plugin's own files are never written), nothing where there is no file yet.
func save_button_text() -> String:
	if _source_path.is_empty():
		return ""
	if _files().can_save_in_place(_source_path):
		return EventSheetL10n.translate("Save")
	return EventSheetL10n.translate("Save a Copy…")


## What the question on closing says its main button does.
func _commit_text() -> String:
	var text: String = save_button_text()
	return text if not text.is_empty() else EventSheetL10n.translate("Save As…")


## Brings the title, the buttons and the theme field in line with what the window holds.
func _refresh_state() -> void:
	if _dialog == null:
		return
	_dialog.title = window_title()
	var save_text: String = save_button_text()
	_save_button.text = save_text
	_save_button.visible = not save_text.is_empty()
	_save_as_button.visible = not _files().is_shipped(_source_path)
	_revert_button.disabled = not is_changed()
	_sync_theme_field()


# ── The window's own undo list ────────────────────────────────────────────────────────────────────


func _record_edit(entry: Dictionary) -> void:
	# A new step after undoing past the saved point leaves no way back to the saved state.
	if _clean_depth > _edits.size():
		_clean_depth = -1
	_edits.append(entry)
	_redone.clear()
	_refresh_state()


## A change to the whole palette (Generate Theme, Reset To Default): both sides are kept as copies.
func _record_whole(before: EventSheetEditorStyle, after: EventSheetEditorStyle) -> void:
	_record_edit({"whole": true, "from": before.duplicate(true), "to": after.duplicate(true)})


func undo_edit() -> void:
	if _edits.is_empty():
		return
	var entry: Dictionary = _edits.pop_back()
	_redone.append(entry)
	_step(entry, "from")


func redo_edit() -> void:
	if _redone.is_empty():
		return
	var entry: Dictionary = _redone.pop_back()
	_edits.append(entry)
	_step(entry, "to")


## Puts one side of an undo step on the working theme and on what the window shows.
func _step(entry: Dictionary, side: String) -> void:
	if bool(entry.get("whole", false)):
		restore_values(_working_style, entry[side] as Resource)
		_rebuild_detail_form()
		_fit_preview_width()
	elif bool(entry.get("light", false)):
		_light_side.step(entry, side)
	else:
		var style: Resource = entry["style"]
		style.set(str(entry["token"]), entry[side])
		_show_value(style, str(entry["token"]), entry[side])
		_light_side.invalidate()
		_light_side.refresh_all()
	_repaint_preview()
	if not bool(entry.get("whole", false)):
		_focus_token(entry["style"], str(entry["token"]))
	_refresh_state()


## Copies every stored value of `source` onto `target`, a block at a time, so the blocks keep the identity
## the window's undo steps point at.
static func restore_values(target: Resource, source: Resource) -> void:
	for info: Dictionary in source.get_property_list():
		var usage: int = int(info.get("usage", 0))
		if not (usage & PROPERTY_USAGE_SCRIPT_VARIABLE and usage & PROPERTY_USAGE_STORAGE):
			continue
		var property_name: String = str(info["name"])
		var value: Variant = source.get(property_name)
		var current: Variant = target.get(property_name)
		if value is Resource and current is Resource:
			restore_values(current as Resource, value as Resource)
		elif value is Resource:
			target.set(property_name, (value as Resource).duplicate(true))
		elif value is Dictionary:
			target.set(property_name, (value as Dictionary).duplicate(true))
		else:
			target.set(property_name, value)


## Shows a token's value in its swatch without editing it again.
func _show_value(style: Resource, token_name: String, value: Variant) -> void:
	for row: Node in _detail_form.find_children("*", "HBoxContainer", true, false):
		if not row.has_meta("token") or str(row.get_meta("token")) != token_name or row.get_child_count() < 2:
			continue
		if int(row.get_meta("style_id", 0)) != style.get_instance_id():
			continue
		var field: Node = row.get_child(1)
		if field is ColorPickerButton:
			(field as ColorPickerButton).color = value
		elif field is CheckBox:
			(field as CheckBox).set_pressed_no_signal(bool(value))
		elif field is SpinBox:
			(field as SpinBox).set_value_no_signal(float(value))


## Goes back to the file as it was last saved, or to the editor-matched look for Match Editor. Nothing is
## written.
func revert() -> void:
	var base: EventSheetEditorStyle = null
	if not _source_path.is_empty():
		base = ResourceLoader.load(_source_path, "", ResourceLoader.CACHE_MODE_IGNORE) as EventSheetEditorStyle
	_working_style = duplicate_style(base)
	_adopt(true)


func _on_window_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or not key.is_command_or_control_pressed():
		return
	# A text box that is being typed in keeps its own Ctrl+Z, and a spin box's number is typed the same way.
	var focus: Control = _dialog.gui_get_focus_owner()
	if focus is LineEdit and not (focus.get_parent() is SpinBox) and (focus as LineEdit).editable:
		return
	match key.keycode:
		KEY_S:
			_save_pressed()
		KEY_Z:
			if key.shift_pressed:
				redo_edit()
			else:
				undo_edit()
		KEY_Y:
			redo_edit()
		_:
			return
	_dialog.set_input_as_handled()


func _on_custom_action(action: StringName) -> void:
	match action:
		&"save":
			_save_pressed()
		&"save_as":
			_open_save_dialog()
		&"revert":
			revert()


# ── Saving ────────────────────────────────────────────────────────────────────────────────────────


## Save: a theme of the project's own is written where it is; a starter, a demo theme or a look with no file
## asks where a new file goes.
func _save_pressed() -> void:
	if _files().can_save_in_place(_source_path):
		save()
	else:
		_open_save_dialog()


## Writes the theme the window opened. Every sheet wearing that file repaints.
func save() -> Error:
	var error: Error = _files().write_in_place(_source_path, _working_style)
	if error == OK:
		_clean_depth = _edits.size()
		_refresh_state()
	_report(error, _source_path)
	return error


## Writes the working theme to a NEW file and makes the window edit that file from then on. A copy of a
## starter also puts the open sheet on the copy, so the sheet leaves the starter that stays as shipped.
func save_preset(path: String) -> Error:
	var from_shipped: bool = _files().is_shipped(_source_path)
	var error: Error = _files().write_in_place(path, _working_style)
	if error == OK:
		_source_path = path
		_from_editor = false
		_clean_depth = _edits.size()
		_refresh_state()
		if from_shipped and _dock != null and _dock.has_method("load_theme_style_from_path"):
			_dock.call("load_theme_style_from_path", path)
	_report(error, path)
	return error


## Says how a write went, in the window's foot and on the status bar.
func _report(error: Error, path: String) -> void:
	var said: String = EventSheetL10n.translate("Theme saved: %s") % path.get_file() if error == OK \
		else EventSheetL10n.translate("Theme could not be saved: %s (%s)") % [path.get_file(), error_string(error)]
	if error == OK and _sheet_wears_a_copy():
		said += " " + EventSheetL10n.translate("The open sheet keeps its own copy of a theme; pick the theme again to update it.")
	if _note != null:
		_note.say(said, EventSheetPopupUI.TONE_OK if error == OK else EventSheetPopupUI.TONE_ERROR)
	if _dock != null and _dock.has_method("_set_status"):
		_dock.call("_set_status", said, error != OK)


## Whether the open sheet carries a copy of a theme inside itself rather than wearing a theme file: such a
## sheet does not take up what is saved into the file.
func _sheet_wears_a_copy() -> bool:
	var sheet: Variant = _dock.get("_current_sheet") if _dock != null else null
	if not (sheet is EventSheetResource):
		return false
	var worn: EventSheetEditorStyle = (sheet as EventSheetResource).editor_style as EventSheetEditorStyle
	return worn != null and _files().file_of(worn).is_empty()


## The editor's own save dialog, with one line at its foot naming the file a Save would replace. It starts
## in the project's themes folder with a free name, or beside the theme being copied.
func _open_save_dialog(then: Callable = Callable(), on_cancel: Callable = Callable()) -> void:
	var shipped_source: bool = _files().is_shipped(_source_path)
	var folder: String = _source_path.get_base_dir() if _files().can_save_in_place(_source_path) else EventSheetThemePresets.PROJECT_DIR
	# The project's own themes folder is where a saved theme is listed from, so the dialog starts there.
	# Saving is the moment a project asks for that folder; one made for a dialog that is then cancelled
	# is taken away again.
	var made: bool = not DirAccess.dir_exists_absolute(folder) and DirAccess.make_dir_recursive_absolute(folder) == OK
	var suggested: String = _files().copy_path(_source_path, folder) if not _source_path.is_empty() \
		else _files().unique_path(folder, "my_theme.tres")
	var browser: ConfirmationDialog = EventSheetPopupUI.browse_file(_dialog, PackedStringArray(["*.tres ; EventSheetEditorStyle"]),
		func(path: String) -> void: _save_chosen(path, then),
		{"title": EventSheetL10n.translate("Save a Copy") if shipped_source else EventSheetL10n.translate("Save Theme As"),
			"save": true, "size": Vector2i(720, 480), "dir": folder, "path": suggested})
	if browser == null:
		if made:
			DirAccess.remove_absolute(folder)
		return
	browser.canceled.connect(func() -> void:
		if made:
			DirAccess.remove_absolute(folder)
		if on_cancel.is_valid():
			on_cancel.call())
	var reason: Label = Label.new()
	reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	reason.add_theme_color_override("font_color", EventSheetPopupUI.tone_color(EventSheetPopupUI.TONE_WARNING))
	browser.call("get_vbox").add_child(reason)
	poll_save_note(browser, reason)


## A file chosen in the save dialog: written, and the question that waited on it goes on.
func _save_chosen(path: String, then: Callable) -> void:
	var target: String = path if not path.get_extension().is_empty() else path + ".tres"
	if save_preset(target) == OK and then.is_valid():
		then.call()


## The dialog reports no signal when a file in its list is clicked, so `reason` is re-read on a short
## timer while `browser` is up. The timer goes the first time it finds the browser hidden, so a browser
## kept alive after it closes never polls on.
static func poll_save_note(browser: Window, reason: Label) -> Timer:
	var poll: Timer = Timer.new()
	poll.wait_time = 0.2
	poll.autostart = true
	poll.timeout.connect(func() -> void:
		if not browser.visible:
			poll.queue_free()
			return
		reason.text = save_note(str(browser.get("current_path"))))
	browser.add_child(poll)
	return poll


# ── Changes left in the window ────────────────────────────────────────────────────────────────────


## Closing the window with changes asks Save / Discard / Cancel the way Godot asks for a changed scene.
## True when it asked.
func request_close() -> bool:
	if not is_changed():
		return false
	_ask_about_changes(_dialog.hide, Callable(), revert)
	return true


## The window was closed by its Close button, Esc or its title bar: with changes it comes back to ask.
func _on_window_closed() -> void:
	if not is_changed():
		return
	# Godot has hidden the window by now. It is shown again before a frame is drawn, so the question stands
	# over a window that never went away. Save and Discard close it afterwards; Cancel leaves it as it is.
	_dialog.show.call_deferred()
	_ask_about_changes.call_deferred(_dialog.hide, _dialog.grab_focus, revert)


## Asks what to do with the changes before `then` (opening another theme, or nothing when the window is
## closing). Save writes them first and goes on once they are written; Discard goes on without them;
## Cancel runs `on_cancel` and stays. `on_discard` runs first when the changes are thrown away (the window
## closing puts the file's own colours back in it).
func _ask_about_changes(then: Callable, on_cancel: Callable, on_discard: Callable = Callable()) -> void:
	if _close_prompt != null and is_instance_valid(_close_prompt):
		return
	var go_on: Callable = func() -> void:
		if then.is_valid():
			then.call()
	_close_prompt = load(SMALL_PROMPT_PATH).open(_dock if _dock != null else _dialog, {
		"title": EventSheetL10n.translate("Save changes to %s?") % theme_name(),
		"say": EventSheetL10n.translate("The swatches you changed are not in the file yet."),
		"note": EventSheetL10n.translate("Discard throws the changes away. Cancel keeps the window as it is."),
		"glyph": "!",
		"main": _commit_text(),
		"danger": EventSheetL10n.translate("Discard"),
		"on_main": func() -> void:
			if _files().can_save_in_place(_source_path):
				if save() == OK:
					go_on.call()
			else:
				_open_save_dialog(go_on, on_cancel),
		"on_danger": func() -> void:
			if on_discard.is_valid():
				on_discard.call()
			go_on.call(),
		"on_cancel": func() -> void:
			if on_cancel.is_valid():
				on_cancel.call(),
	})


# ── Another theme ─────────────────────────────────────────────────────────────────────────────────


## Every theme the window can switch to, grouped the way the Sheet theme menu groups them: Match Editor,
## the project's own, the demos, the starters. A theme open from anywhere else is listed too.
func theme_choices() -> Array[Dictionary]:
	var choices: Array[Dictionary] = [{"name": EventSheetL10n.translate("Match Editor"), "path": "", "group": EventSheetL10n.translate("Follows the editor")}]
	var listed: Array[Dictionary] = EventSheetThemePresets.list_presets()
	var groups: Array = [
		[EventSheetThemePresets.PROJECT_DIR, EventSheetL10n.translate("Your themes")],
		["res://demo/", EventSheetL10n.translate("In this project")],
		["res://addons/", EventSheetL10n.translate("Starters (copy to edit)")],
	]
	for group: Array in groups:
		for preset: Dictionary in listed:
			if str(preset.get("path", "")).begins_with(str(group[0])):
				choices.append({"name": str(preset.get("name", "")), "path": str(preset["path"]), "group": str(group[1])})
	if not _source_path.is_empty():
		var listed_here: bool = false
		for choice: Dictionary in choices:
			listed_here = listed_here or str(choice["path"]) == _source_path
		if not listed_here:
			choices.append({"name": _source_path.get_file(), "path": _source_path, "group": EventSheetL10n.translate("Open now")})
	return choices


func _build_theme_field(form: VBoxContainer) -> void:
	_theme_field = OptionButton.new()
	_theme_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_theme_field.item_selected.connect(func(index: int) -> void:
		if not switch_to(str(_theme_field.get_item_metadata(index))):
			_sync_theme_field())
	form.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Theme"), _theme_field))
	# One plain sentence under the field about the theme that is open.
	_theme_note = EventSheetPopupUI.hint_label("")
	form.add_child(_theme_note)
	_fill_theme_field()


func _fill_theme_field() -> void:
	load(FIELD_WORDS_PATH).fill(_theme_field, theme_choices())
	_select_theme_field()


## Selects the entry for the theme the window edits, and lists it first when it is not listed yet.
func _sync_theme_field() -> void:
	if _theme_field == null:
		return
	if not _select_theme_field():
		_fill_theme_field()


func _select_theme_field() -> bool:
	for index: int in range(_theme_field.item_count):
		if str(_theme_field.get_item_metadata(index)) == _source_path and not _theme_field.is_item_separator(index):
			_theme_field.select(index)
			# The closed field names the theme; the folder is for the list.
			_theme_field.text = load(FIELD_WORDS_PATH).name_of(_theme_field.get_item_text(index))
			_theme_note.text = load(FIELD_WORDS_PATH).sentence(_source_path)
			return true
	return false


## Makes the window edit another theme ("" is Match Editor). With changes it asks first, and the answer
## decides; true means the window switched right now.
func switch_to(path: String) -> bool:
	if path == _source_path and (not path.is_empty() or _from_editor):
		return true
	if not is_changed():
		_switch_now(path)
		return true
	_ask_about_changes(func() -> void: _switch_now(path), func() -> void: _sync_theme_field())
	return false


func _switch_now(path: String) -> void:
	var base: EventSheetEditorStyle = null
	if not path.is_empty():
		base = ResourceLoader.load(path) as EventSheetEditorStyle
		if base == null:
			_report(ERR_FILE_UNRECOGNIZED, path)
			_sync_theme_field()
			return
	_working_style = duplicate_style(base)
	_source_path = path
	_from_editor = base == null
	_adopt(true)
