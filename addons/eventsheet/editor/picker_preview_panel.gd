# EventSheet - the Picker Preview rail panel: how THIS sheet's published verbs will read in the
# ACE picker - kind badge, display name, featured star, category chip, parameter list - derived
# LIVE from the unsaved sheet, so an author sees the picker's view of their pack while shaping
# it, not after saving. Closes the loop the ACE wizard opened: the wizard previews a SCRIPT, this
# previews the SHEET being edited.
#
# Same construction as the Anatomy panel: a custom-drawn list in the sheet's own pill/badge
# colour language (an action reads amber here exactly as it will in the picker), and a static +
# pure census so what-would-publish is headless-testable.
@tool
class_name EventSheetPickerPreviewPanel
extends VBoxContainer

const _KIND_PILLS: Dictionary = {
	"action": ["A", EventSheetPalette.COLOR_ACE_ACTION_BADGE_BG, EventSheetPalette.COLOR_ACE_ACTION_BADGE_FG],
	"condition": ["?", EventSheetPalette.COLOR_ACE_CONDITION_BADGE_BG, EventSheetPalette.COLOR_ACE_CONDITION_BADGE_FG],
	"expression": ["ƒ", EventSheetPalette.COLOR_ACE_EXPRESSION_BADGE_BG, EventSheetPalette.COLOR_ACE_EXPRESSION_BADGE_FG],
	"trigger": ["➜", Color("#233b2b"), EventSheetPalette.COLOR_MANIFEST_TRIGGERS],
	"knob": ["@", Color("#2c313a"), EventSheetPalette.COLOR_MANIFEST_KNOBS],
}
const _ROW_HEIGHT: float = 22.0

var _canvas: Control = null
var _scroll: ScrollContainer = null
var _entries: Array = []
var _header_button: Button = null
var _expanded: bool = false


func _init() -> void:
	name = "PickerPreview"
	custom_minimum_size = Vector2(EventSheetPalette.scaled_f(180.0), 0.0)
	_header_button = Button.new()
	_header_button.flat = true
	_header_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_header_button.tooltip_text = "How this sheet's published verbs will read in the picker - live, before you save. Kind badge, display name, featured star, category, parameters."
	_header_button.pressed.connect(func() -> void: set_expanded(not _expanded))
	add_child(_header_button)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(0.0, EventSheetPalette.scaled_f(110.0))
	_scroll.visible = false
	add_child(_scroll)
	_canvas = Control.new()
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.draw.connect(_draw_entries)
	_scroll.add_child(_canvas)
	_refresh_header()


func set_expanded(expanded: bool) -> void:
	_expanded = expanded
	_scroll.visible = expanded
	_refresh_header()


func refresh(sheet: EventSheetResource) -> void:
	_entries = collect_preview(sheet)
	_canvas.custom_minimum_size = Vector2(0.0, float(_entries.size()) * _row_height())
	_refresh_header()
	_canvas.queue_redraw()


func _refresh_header() -> void:
	_header_button.text = "%s Picker preview · %d" % ["▼" if _expanded else "▶", _entries.size()]


static func _row_height() -> float:
	return EventSheetPalette.scaled_f(_ROW_HEIGHT)


func _draw_entries() -> void:
	var font: Font = get_theme_default_font()
	var width: float = _canvas.size.x
	var ui: float = EventSheetPalette.ui_scale()
	var name_font: int = EventSheetPalette.scaled(11)
	var pill_font: int = EventSheetPalette.scaled(10)
	var y: float = 0.0
	for entry: Dictionary in _entries:
		var pill: Array = _KIND_PILLS.get(str(entry.get("kind")), _KIND_PILLS["action"])
		var pill_rect: Rect2 = Rect2(4.0 * ui, y + 3.0 * ui, 16.0 * ui, _row_height() - 6.0 * ui)
		var pill_box: StyleBoxFlat = StyleBoxFlat.new()
		pill_box.bg_color = pill[1]
		pill_box.set_corner_radius_all(3)
		pill_box.draw(_canvas.get_canvas_item(), pill_rect)
		_canvas.draw_string(font, Vector2(pill_rect.position.x + 4.0 * ui, y + 15.0 * ui), str(pill[0]),
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, pill_font, pill[2])
		var x: float = 26.0 * ui
		if bool(entry.get("featured", false)):
			_canvas.draw_string(font, Vector2(x, y + 15.0 * ui), "★", HORIZONTAL_ALIGNMENT_LEFT, -1.0, name_font, EventSheetPalette.COLOR_ACTION)
			x += 14.0 * ui
		var title: String = str(entry.get("name"))
		var parameters: Array = entry.get("params", [])
		if not parameters.is_empty():
			title += " (%s)" % ", ".join(PackedStringArray(parameters))
		_canvas.draw_string(font, Vector2(x, y + 15.0 * ui), title,
			HORIZONTAL_ALIGNMENT_LEFT, width - x - 4.0 * ui, name_font, EventSheetPalette.TEXT_PRIMARY)
		var category: String = str(entry.get("category", ""))
		if not category.is_empty():
			var title_width: float = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, name_font).x
			_canvas.draw_string(font, Vector2(x + title_width + 8.0 * ui, y + 15.0 * ui), category,
				HORIZONTAL_ALIGNMENT_LEFT, width - x - title_width - 12.0 * ui, pill_font, EventSheetPalette.COLOR_CAT_CHIP_FG)
		y += _row_height()


## What the picker will show for this sheet, derived from the LIVE model: exposed functions
## (with display-name/category/featured overrides), `## @ace_*` annotation shells still living
## as raw code (an opened pack's un-lifted verbs), signal triggers, and exported knobs (which
## publish get/set/add/subtract in the picker, listed once here). Static + pure.
static func collect_preview(sheet: EventSheetResource) -> Array:
	var entries: Array = []
	if sheet == null:
		return entries
	for entry: Variant in sheet.functions:
		if not (entry is EventFunction) or not (entry as EventFunction).expose_as_ace:
			continue
		var event_function: EventFunction = entry as EventFunction
		var display: String = event_function.ace_display_name.strip_edges()
		if display.is_empty():
			display = event_function.function_name.capitalize()
		var parameter_names: Array = []
		for parameter: Variant in event_function.params:
			if parameter is ACEParam:
				parameter_names.append((parameter as ACEParam).get_param_name())
		entries.append({
			"kind": ViewportRowBuilder.define_role_for(event_function),
			"name": display,
			"category": event_function.ace_category.strip_edges(),
			"featured": event_function.featured,
			"params": parameter_names,
		})
	_collect_rows(sheet.events, entries)
	for var_name: Variant in sheet.variables.keys():
		var descriptor: Variant = sheet.variables[var_name]
		if descriptor is Dictionary and bool((descriptor as Dictionary).get("exported", (descriptor as Dictionary).get("exposed", true))):
			entries.append({"kind": "knob", "name": str(var_name).capitalize(), "category": "get / set / add / subtract", "featured": false, "params": []})
	return entries


static func _collect_rows(rows: Array, entries: Array) -> void:
	for row: Variant in rows:
		if row is EventGroup:
			var group: EventGroup = row as EventGroup
			_collect_rows(group.events if not group.events.is_empty() else group.rows, entries)
		elif row is SignalRow and (row as SignalRow).trigger:
			var signal_row: SignalRow = row as SignalRow
			var trigger_name: String = signal_row.ace_name.strip_edges()
			entries.append({"kind": "trigger",
				"name": trigger_name if not trigger_name.is_empty() else signal_row.signal_name.capitalize(),
				"category": "", "featured": false, "params": []})
		elif row is LocalVariable and (row as LocalVariable).exported:
			entries.append({"kind": "knob", "name": (row as LocalVariable).name.capitalize(),
				"category": "get / set / add / subtract", "featured": false, "params": []})
		elif row is RawCodeRow:
			var shell: Dictionary = ViewportRowBuilder.define_shell_info((row as RawCodeRow).code)
			if not shell.is_empty():
				entries.append({"kind": str(shell.get("kind", "action")), "name": str(shell.get("name", "")),
					"category": str(shell.get("category", "")), "featured": false, "params": []})
