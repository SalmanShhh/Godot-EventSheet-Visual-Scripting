# Godot EventSheets - Visual theme editor (designer-facing)
# A live theme workbench: the left pane is a REAL EventSheetViewport rendering a sample
# sheet; the right pane is a token form generated REFLECTIVELY from the style resources'
# exported properties (Color → color picker, float/int → spinbox, bool → checkbox), so new
# tokens added to the style classes appear here automatically - no editor changes needed.
# Edits write into a duplicated working style and repaint live; "Apply" assigns it to the
# current sheet, "Save As Preset…" writes a shareable .tres. Every section folds, a token row is named
# as the code names it, and the strip at the foot says what the token under the pointer does.
@tool
class_name EventSheetThemeEditor
extends RefCounted

var _dialog: ConfirmationDialog = null
var _preview_viewport: EventSheetViewport = null
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


## Opens the theme editor seeded from the dock's active style (or defaults).
func open(dock: Control, base_style: EventSheetEditorStyle) -> void:
	_dock = dock
	_working_style = duplicate_style(base_style)
	_ensure_dialog()
	_preview_viewport.set_sheet(build_sample_sheet(_working_style))
	_dialog.popup_centered(Vector2i(EventSheetPalette.scaled(1240), EventSheetPalette.scaled(640)))


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
	return EventSheetThemeDerivation.fill_derived_tokens(EventSheetGodotTheme.adapt_to_editor(style))


## The sample sheet shown in the preview: one of everything the theme touches.
static func build_sample_sheet(style: EventSheetEditorStyle) -> EventSheetResource:
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
	comment.custom_color = Color(0.32, 0.27, 0.14, 1.0)
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
	"group_row_height": "Height of a group header bar, in pixels - double an event row by default; lower it for the classic slim bar.",
	"inspector_variable_rows": "Draw a variable row the way the Inspector lists a property: its type, its name exactly as the code writes it, its value and its ## description, with its attributes as icon tiles - no scope word, no kind mark and no code.",
	"variable_row_cards": "Draw each Inspector-style variable row as its own small card - the event card's fill and edge, with a gap to the next - instead of the flat variable wash.",
	"hide_compiler_variables": "Leave the bookkeeping variables the compiler writes out of the variable rows: every name starting with two underscores, an author's own included. They still compile and save.",
	"fold_compiler_helpers": "Inside events, stop showing the compiler's two-underscore bookkeeping names: a scene copy kept in such a local is named by its scene file, the line that adds it reads Spawn, its local's row folds into that, and rows that only keep a hidden member up to date fold away. They still compile and save.",
	"pattern_in_help_strip": "Leave the pattern chip (Making an object and putting it somewhere) out of the conditions lane, and say the pattern in the help strip when its event is selected, with a door to its Manual page.",
	"inspector_class_head": "Draw the sheet's head as one class head card: icon, name, kind, what it extends, the share mark and the attached scene - no code, no change… word, no scene-fact rows and no + add row (the + Add… menu and the Sheet Type dialog keep those gestures).",
	"add_lines_on_hover": "Show an event's Add condition and Add action lines only while it is hovered or selected, so an event at rest is as tall as its conditions and actions.",
	"trigger_icon_in_gutter": "Draw the event's number on its first line, with the gutter as one column.",
	"behaviour_in_object_column": "Retired: a behaviour's action always keeps its node and leads with the behaviour's name and a colon.",
	"lane_chips_yield": "Give the chips after a condition (a trigger's payload, the pattern chip) at most two fifths of the conditions lane, so the condition's own words keep their room.",
	"comment_notes": "Draw a comment as a note: the yellow card with a drag grip and a speech-bubble mark before its words, in its own row and inside the action lane (without its # marker), and no code beside it.",
	"selection_as_outline": "Mark a selected event by its filled number gutter and a frame round it, with nothing washed over its conditions and actions.",
	"row_font_size": "The size the sheet's text is drawn at, in pixels at 100% editor scale - never larger than the editor's own font. 0 follows the editor's font size.",
	"condition_object_column_width":"Fixed width of the object-name column in the conditions lane (0 = text flows after each name). Also set by dragging the name/text gap in a row.",
	"action_object_column_width": "Fixed width of the object-name column in the actions lane (0 = text flows after each name). Also set by dragging the name/text gap in a row.",
	"event_block_gap": "Gap opened before an event or group that starts a new block, in pixels - the air between one event and the next.",
	"sub_event_indent": "How far one nesting level steps a sub-event in, in pixels.",
	"sub_event_rail_line": "Draw the rail a sub-event hangs from - a vertical line down its parent's indent step.",
	"event_card_border_width": "Thickness of the border round a whole event, in pixels. 0 draws no card and gives each row its own hairline instead.",
	"event_card_gutter_gap": "Gap kept between the number gutter and the card's left edge, so the number reads as a margin mark outside the event.",
	"trigger_badge_background_color": "Fill of the trigger arrow badge (On Ready, On Signal...).",
	"trigger_badge_foreground_color": "Icon/text colour on the trigger badge.",
	"group_background_color": "Background of a group header row.",
	"group_background_alt_color": "Alternate group header background (zebra).",
	"group_accent_color": "The group's left accent stripe and hairlines.",
	"group_title_color": "The group title text colour.",
	"group_badge_background_color": "Fill of the count badge on a group.",
	"group_badge_foreground_color": "Text colour on the group count badge.",
	"group_fold_background_color": "Background of the collapse triangle box on a group.",
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
	"head_bar_color": "Flat fill of the head bars (the file's line, Input, Instance variables, Behaviors).",
	"gutter_background_color": "The strip down the left of the sheet that carries the event numbers.",
	"gutter_text_color": "The event numbers themselves.",
	"language_block_accent_color": "The stripe + wash on language blocks (a data class, a host binding, a switch case) so they read as code structure, not regular events.",
	"event_corner_radius": "Corner roundness of the event block, in pixels (0 = square).",
	"cell_corner_radius": "Corner roundness of individual condition/action cells.",
	"group_corner_radius": "Corner roundness of group rows (0 = square bar).",
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
	"include_border_color": "The edge round the Include line of a sheet that includes a shared one. Clear = no edge.",
	"include_fill_color": "The fill of the Include line. Clear = the head bar colour.",
	"include_tag_color": "The word Include (and its arrow) on the Include line. Clear = as before.",
	"include_name_color": "The included sheet's name on the Include line. Clear = the object label colour.",
	"include_note_color": "The plain description at the end of the Include line. Clear = muted text.",
	"class_border_color": "The edge round a class declared inside the script.",
	"class_fill_color": "The fill behind a class block's fields.",
	"class_head_color": "The fill of a class block's head line.",
	"class_tag_color": "The word CLASS on a class block's head line.",
	"class_name_color": "The class's own name on its head line.",
	"class_note_color": "The plain description of what the class is for.",
	"comment_border_color": "The edge round a full-width comment, so it reads as a note card. Clear = no edge.",
	"gutter_icon_color": "The small icon in the number gutter that says how an event starts (on ready, every tick).",
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
	"plain_chip_background_color": "The plain chip on an Include bar button (Run now, Reload, Output), the coverage chip, and every other neutral chip in a row.",
	"plain_chip_foreground_color": "The word on those plain chips.",
	"pattern_chip_background_color": "The ⟡ chip that names the pattern an event is (Cooldown, Object pool, Wait sequence). Leave it clear to follow the plain chip.",
	"pattern_chip_foreground_color": "The words on the ⟡ pattern chip. Leave it clear to follow the muted text tone.",
	"category_chip_background_color": "The chip that says where something sits in the picker (\"Group › Subgroup\").",
	"category_chip_foreground_color": "The word on the picker-category chip.",
	"inspector_chip_background_color": "The \"Inspector\" chip on a variable the game's designer can edit.",
	"inspector_chip_foreground_color": "The word on the Inspector chip.",
	"constant_badge_background_color": "The badge that says a variable is const or static.",
	"constant_badge_foreground_color": "The word on the const / static badge.",
	"setup_badge_background_color": "The dim badge on a setup strip - the ▣ and ⇥ marks that open an Include bar.",
	"setup_badge_foreground_color": "The glyph on a setup badge.",
	"code_badge_background_color": "The \"Script block\" pill on a row that kept its GDScript as it was written.",
	"code_badge_foreground_color": "The words on the Script block pill.",
	"lift_note_badge_background_color": "The \"⚠ code\" badge that asks you to look at a line the sheet could not read.",
	"lift_note_badge_foreground_color": "The words on the ⚠ code badge.",
	"or_badge_background_color": "The hairline ruled beside the \"or\" between two OR'd conditions (mixed with the word's own ink so it stays visible).",
	"or_badge_foreground_color": "The word \"or\" on that divider.",
	"tempo_every_tick_background_color": "The ⟳ badge on an event that runs every tick - a tween beat, a repeating timer.",
	"tempo_every_tick_foreground_color": "The glyph on the every-tick badge.",
	"tempo_input_background_color": "The ⌨ badge on an event a key or a button starts.",
	"tempo_input_foreground_color": "The glyph on the input badge.",
	"tempo_once_background_color": "The ▶ badge on an event that runs once.",
	"tempo_once_foreground_color": "The glyph on the runs-once badge.",
	"primary_text_color": "The main word of a row's sentence.",
	"secondary_text_color": "The quieter half of a sentence.",
	"muted_text_color": "The muted detail after it - an Include bar's file name, an INPUT row's keys, a head bar's subtitle.",
	"string_value_color": "Text values inside a parameter (\"coin\"), so magic words are findable by colour.",
	"boolean_value_color": "true and false inside a parameter.",
	"error_text_color": "\"N errors - the game will not run this script\", and the words on a broken row.",
	"error_stripe_color": "The red stripe and wash down a row the engine cannot parse.",
	"firing_stripe_color": "The stripe that pulses on an event firing right now while the game runs.",
	"disabled_row_color": "The scrim over a row that is switched off.",
	"breakpoint_color": "The breakpoint dot in the event-number margin.",
	"runtime_error_color": "The strip under the sheet that says what just went wrong in the running game, in the row's own words.",
	"debugger_accent_color": "The Debugger window's accent - the busiest rows of its Profile tab.",
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
	"variable_row_rule_color": "The 2px rule down the left edge of a variable row, and the ink its scope word wears.",
	"variable_row_wash_end_color": "The right-edge colour of an optional fade across that wash. Same as the wash means flat.",
	"color_swatch_border_color": "The outline around a colour value's swatch, so a pale colour still reads as a swatch.",
	"name_highlight_strength": "How strongly every other use of a hovered variable lights up, inside that variable's own scope.",
	# ── Bars around the sheet ────────────────────────────────────────────────────────────────
	"object_bar_section_color": "The headings down the Object bar (SCENE, GLOBALS, INPUT) and the row count beside each entry.",
	"object_bar_warning_color": "The ⚠ on an Object bar entry the sheet flagged - a node the scene lost, an action the Input Map does not have.",
	"object_bar_hover_wash_color": "The wash over every row that uses the object you point at in the Object bar.",
	"object_bar_grip_color": "The grab dots on the row under the mouse.",
	"object_bar_grip_active_color": "Those dots once the pointer is in the grab zone.",
	"project_bar_heading_color": "The by-kind headings down the Project bar (Scenes, Scripts, Classes, Base classes).",
	"project_bar_note_color": "The quiet note beside a Project bar entry - its file, who extends it, how much of it reads as events.",
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
	"minimap_group_color": "A group's bar.",
	"minimap_comment_color": "A comment's bar.",
	"minimap_script_color": "A Script block's bar.",
	"minimap_event_color": "Every other event's bar.",
	"minimap_disabled_color": "A disabled row's bar - present, but not asking to be read.",
	"minimap_bookmark_color": "The mark in the margin beside a row you bookmarked.",
	"minimap_finding_color": "The mark beside a row the sheet flagged.",
	"minimap_band_color": "The band a group paints down the column, from its own row to its last.",
	"minimap_band_text_color": "The group's name written on that band.",
	# ── The Sheet map window ─────────────────────────────────────────────────────────────────
	"sheet_map_sheet_color": "An event sheet's box in the Sheet map.",
	"sheet_map_scene_color": "A scene's box - the scenes that carry the sheets.",
	"sheet_map_global_color": "A global's box - the autoloads and globals the sheets call.",
	"sheet_map_edge_color": "The quiet line between two boxes: an include, a call, a layout change.",
	"sheet_map_signal_edge_color": "The warm line for a signal connection - wiring that fires at runtime.",
	"sheet_map_text_color": "The name written inside every box in the Sheet map.",
	# ── The Inspector drawers ────────────────────────────────────────────────────────────────
	"drawer_accent_color": "The fill of every interactive drawer in the Inspector - a progress bar's filled part, a range slider's span, a dial's vector line.",
	"drawer_accent_bright_color": "The lit end of that fill - the dial's handle, a curve's plotted line.",
	"drawer_ink_color": "The quiet ink the drawers write and rule with - value labels, hairlines, the dial's grid. Each mark keeps its own softness.",
	"drawer_well_color": "The sunken plate a bar, track or preview sits in.",
	"drawer_handle_color": "The range slider's two round handles.",
	"drawer_handle_border_color": "The line around each handle.",
	"drawer_info_background_color": "The note panel an @inspector_info comment builds.",
	"drawer_info_border_color": "That panel's border, heavier on the left.",
	"drawer_info_text_color": "The words on that panel.",
	"drawer_header_text_color": "An @inspector_header section label that named no accent of its own.",
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
	# Save As Preset… sits between the note and the two closing buttons.
	var save_button: Button = _dialog.add_button(EventSheetL10n.translate("Save As Preset…"), false, "save_preset")
	save_button.get_parent().move_child(save_button, _note.get_index() + 1)
	save_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_dialog.custom_action.connect(func(_action: StringName) -> void: _open_save_dialog())
	_note.say(EventSheetL10n.translate("Apply writes this look into the open sheet only"), EventSheetPopupUI.TONE_WARNING)
	var split: HSplitContainer = HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var preview_scroll: ScrollContainer = ScrollContainer.new()
	preview_scroll.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(720.0), EventSheetPalette.scaled_f(440.0))
	_preview_viewport = EventSheetViewport.new()
	preview_scroll.add_child(_preview_viewport)
	split.add_child(preview_scroll)
	var form_scroll: ScrollContainer = ScrollContainer.new()
	form_scroll.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(460.0), 0.0)
	form_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var form: VBoxContainer = EventSheetPopupUI.form_box()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Quick Style (whole-palette recolour) on top, then how the letters are SHAPED, then the
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
	quick_box.add_child(EventSheetPopupUI.hint_label(EventSheetL10n.translate("Pick a base + accent, then Generate. Fine-tune individual tokens below.")))
	_quick_base = _quick_color_row(quick_box, EventSheetL10n.translate("Base (background tone)"), Color("#252525"))
	_quick_accent = _quick_color_row(quick_box, EventSheetL10n.translate("Accent (groups, selection)"), Color("#569eff"))
	_quick_font = _quick_color_row(quick_box, EventSheetL10n.translate("Text"), Color("#ced0d2"))
	var buttons: HBoxContainer = HBoxContainer.new()
	var reset: Button = Button.new()
	reset.text = EventSheetL10n.translate("Reset To Default")
	reset.tooltip_text = EventSheetL10n.translate("Restore the bundled default look.")
	reset.pressed.connect(_reset_to_default)
	buttons.add_child(reset)
	var generate: Button = Button.new()
	generate.text = EventSheetL10n.translate("Generate Theme")
	generate.tooltip_text = EventSheetL10n.translate("Rebuild every colour token from the three colours above.")
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
		_apply_to_sheet())
	box.add_child(dyslexia_check)
	var font_edit: LineEdit = LineEdit.new()
	font_edit.placeholder_text = EventSheetL10n.translate("res://… .ttf or .otf - blank keeps the editor's own font")
	font_edit.text = EventSheetAccessibility.reading_font_path()
	font_edit.text_submitted.connect(func(path: String) -> void:
		EventSheetAccessibility.set_reading_font_path(path)
		_apply_to_sheet())
	box.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Reading font"), font_edit))
	form.add_child(_fold(EventSheetL10n.translate("Reading Comfort"), box, true))


## One labelled colour picker, returned so Quick Style can read it back on Generate.
func _quick_color_row(form: VBoxContainer, label_text: String, default_color: Color) -> ColorPickerButton:
	var picker: ColorPickerButton = ColorPickerButton.new()
	picker.color = default_color
	form.add_child(EventSheetPopupUI.form_row(label_text, picker))
	return picker


## Derives the two dark tones from the base, regenerates the whole sheet palette, and
## refreshes the detail form + live preview.
func _generate_quick_style() -> void:
	var base: Color = _quick_base.color
	EventSheetGodotTheme.apply(_working_style, base, base.darkened(0.15), base.darkened(0.25), _quick_accent.color, _quick_font.color)
	_reset_to_default(_working_style)


## Restores the bundled default look - a clean starting point - or shows `style` afresh.
func _reset_to_default(style: EventSheetEditorStyle = duplicate_style(null)) -> void:
	_working_style = style
	_rebuild_detail_form()
	_preview_viewport.set_sheet(build_sample_sheet(_working_style))


## (Re)builds the reflective per-token form into _detail_form, clearing any prior fields so
## the spinboxes/pickers always reflect the current (possibly just-regenerated) style. The token
## the strip was describing is described again from the rebuilt style.
func _rebuild_detail_form() -> void:
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
	var mono: Font = EventSheetPopupUI.editor_font("doc_source")
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
		var row: HBoxContainer = EventSheetPopupUI.form_row(token_name, field)
		# The name is the code's own, so it is never translated.
		row.get_child(0).auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		if mono != null:
			row.get_child(0).add_theme_font_override("font", mono)
		for part: Control in [row, row.get_child(0), field]:
			part.mouse_entered.connect(_focus_token.bind(style_resource, token_name))
		field.focus_entered.connect(_focus_token.bind(style_resource, token_name))
		if _focus_resource == null and (_focus_name.is_empty() or _focus_name == token_name):
			_focus_token(style_resource, token_name)
		section_box.add_child(row)
	form.add_child(_fold(title, section_box, open))


## Puts one token in the strip: what it does, and the line it writes into a saved preset.
func _focus_token(style_resource: Resource, token_name: String) -> void:
	_focus_name = token_name
	_focus_resource = style_resource
	if _strip != null:
		_strip.set_line(_this_field, "%s: %s" % [token_name, EventSheetL10n.translate(_token_description(token_name))])
		_strip.set_line(_in_file, file_line(style_resource, token_name))


func _on_token_edited(style_resource: Resource, token_name: String, value: Variant) -> void:
	if apply_token(style_resource, token_name, value) and _preview_viewport != null:
		# Rebuild the sample sheet so BOTH colour and STRUCTURAL tokens (row height, corner radii, lane
		# widths, line thickness) show live - a plain repaint keeps the old cached layout.
		_preview_viewport.set_sheet(build_sample_sheet(_working_style))
		_focus_token(style_resource, token_name)


func _apply_to_sheet() -> void:
	if _dock != null and _dock.has_method("apply_theme_style"):
		_dock.call("apply_theme_style", _working_style.duplicate(true))


## The editor's own save dialog, with one line at its foot naming the file a Save would replace.
func _open_save_dialog() -> void:
	var browser: ConfirmationDialog = EventSheetPopupUI.browse_file(_dialog, PackedStringArray(["*.tres ; EventSheetEditorStyle"]),
		func(path: String) -> void: save_preset(path), {"title": EventSheetL10n.translate("Save Theme Preset"), "save": true, "size": Vector2i(720, 480)})
	if browser == null:
		return
	var reason: Label = Label.new()
	reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	reason.add_theme_color_override("font_color", EventSheetPopupUI.tone_color(EventSheetPopupUI.TONE_WARNING))
	browser.call("get_vbox").add_child(reason)
	poll_save_note(browser, reason)


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


## Saves the working style as a shareable preset .tres, and says how it went in the window's foot and
## on the status bar. Returns OK on success.
func save_preset(path: String) -> Error:
	var error: Error = ResourceSaver.save(_working_style.duplicate(true), path)
	var said: String = EventSheetL10n.translate("Theme preset saved: %s") % path.get_file() if error == OK \
		else EventSheetL10n.translate("Theme preset could not be saved: %s (%s)") % [path.get_file(), error_string(error)]
	if _note != null:
		_note.say(said, EventSheetPopupUI.TONE_OK if error == OK else EventSheetPopupUI.TONE_ERROR)
	if _dock != null and _dock.has_method("_set_status"):
		_dock.call("_set_status", said, error != OK)
	return error
