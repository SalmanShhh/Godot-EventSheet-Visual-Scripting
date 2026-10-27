# EventSheet - a window is as big as what it holds, and no bigger.
#
# Three ways a window opened far bigger than its content:
#   1. The help strip's READS AS and IN CODE lines never wrapped, so a long comment, group
#      description or variable value made its window as wide as the whole line (2400 px and more).
#   2. A window built once and opened again kept the size of the biggest thing it ever held:
#      popup_centered() with no size reuses the window's current size, and a window only grows.
#   3. The Variable window asked for 600 px of height whatever it held, so a plain local opened
#      with a third of the window empty under its cards.
# Measured without a display server: a window's content minimum is what it opens at.
@tool
class_name WindowFitTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "window_fit_test"
const LONG := "a deliberately long line that goes on and on so that a window holding it would have to be very wide indeed if nothing wrapped it, and then goes on for a while longer still"


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _run_help_strip() and all_passed
	all_passed = _run_fitted_size() and all_passed
	all_passed = _run_dock_dialogs() and all_passed
	return all_passed


## A long reading line wraps inside the strip instead of widening it.
static func _run_help_strip() -> bool:
	var short_strip: EventSheetPopupUI.HelpStrip = EventSheetPopupUI.help_strip("Name", "What it is.", "x", "x")
	var long_strip: EventSheetPopupUI.HelpStrip = EventSheetPopupUI.help_strip("Name", "What it is.", LONG, LONG)
	var short_width: float = short_strip.get_combined_minimum_size().x
	var long_width: float = long_strip.get_combined_minimum_size().x
	short_strip.free()
	long_strip.free()
	return SUPPORT.pins(TEST_NAME, [
		["a long READS AS / IN CODE line leaves the strip as wide as a short one", long_width, short_width],
	])


## A window opened again opens at what it holds now, not at the biggest thing it ever held.
static func _run_fitted_size() -> bool:
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	var label: Label = Label.new()
	label.text = "Short."
	dialog.add_child(label)
	# The size a past, longer content left it at.
	dialog.size = Vector2i(1900, 900)
	var content: Vector2i = Vector2i(dialog.get_contents_minimum_size().ceil()).max(dialog.min_size)
	var fitted: Vector2i = EventSheetPopupUI.fitted_size(dialog)
	var fitted_wide: Vector2i = EventSheetPopupUI.fitted_size(dialog, Vector2i(560, 0))
	dialog.free()
	return SUPPORT.pins(TEST_NAME, [
		["a reopened window shrinks to its content", fitted, content],
		["a width asked for is kept, the height is the content's", fitted_wide, Vector2i(maxi(560, content.x), content.y)],
	])


## The windows that ballooned, through the real dock: long content opens them no wider than short.
static func _run_dock_dialogs() -> bool:
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.setup(EventSheetResource.new())
	var comment_long: CommentRow = CommentRow.new()
	comment_long.text = LONG
	var comment_short: CommentRow = CommentRow.new()
	comment_short.text = "Short."
	dock._comments.open_comment_dialog(comment_long)
	var comment_dialog: Window = dock._comments._comment_dialog
	var comment_long_width: float = comment_dialog.get_contents_minimum_size().x
	dock._comments.open_comment_dialog(comment_short)
	var comment_short_width: float = comment_dialog.get_contents_minimum_size().x

	var group_long: EventGroup = EventGroup.new()
	group_long.group_name = "combat"
	group_long.description = LONG
	var group_short: EventGroup = EventGroup.new()
	group_short.group_name = "g"
	group_short.description = "Short."
	dock._quick_prompts.on_group_edit_requested(group_long)
	var group_dialog: Window = dock._quick_prompts._group_edit_dialog
	var group_long_width: float = group_dialog.get_contents_minimum_size().x
	dock._quick_prompts.on_group_edit_requested(group_short)
	var group_short_width: float = group_dialog.get_contents_minimum_size().x

	var variables: RefCounted = dock._variable_dlg
	variables.open_for_edit("local", {}, "a_variable_with_a_long_name", "String", "\"%s\"" % LONG, false, "Edit Variable")
	var variable_dialog: Window = variables._dialog
	var variable_long_width: float = variable_dialog.get_contents_minimum_size().x
	variables.open_for_edit("local", {}, "", "int", "", false, "Create Variable")
	var variable_short_width: float = variable_dialog.get_contents_minimum_size().x
	var variable_height_floor: int = variable_dialog.min_size.y
	var form_scroll: ScrollContainer = variables._form_scroll
	var form_height: float = form_scroll.get_child(0).get_combined_minimum_size().y
	var scroll_height: float = form_scroll.custom_minimum_size.y
	dock.free()
	return SUPPORT.pins(TEST_NAME, [
		["Edit comment: a long comment opens it no wider than a short one", comment_long_width, comment_short_width],
		["Edit group: a long description opens it no wider than a short one", group_long_width, group_short_width],
		["Variable: a long value opens it no wider than an empty one", variable_long_width, variable_short_width],
		["Variable: the window asks for no height of its own", variable_height_floor, 0],
		["Variable: the cards are shown whole up to the most they get before scrolling", scroll_height,
			minf(form_height, EventSheetPalette.scaled_f(VariableDialog.FORM_MAX_HEIGHT))],
	])
