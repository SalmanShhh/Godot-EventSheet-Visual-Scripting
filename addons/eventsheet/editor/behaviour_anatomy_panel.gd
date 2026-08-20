@tool
class_name BehaviourAnatomyPanel
extends VBoxContainer
# The Behaviour Anatomy panel - a left-rail READ MODEL that shows the active sheet as an organism
# with always-visible "organs": Properties (exported knobs) · State (internal vars) · Triggers ·
# Actions · Conditions · Expressions · Uses (outside vocabulary it calls). A behaviour's whole
# public shape becomes one glance, and double-clicking an entry jumps the canvas to its row.
#
# The organ list is CUSTOM-DRAWN with the same pill/badge language as the canvas's Define blocks
# (role-coloured pills, muted labels) rather than a generic Tree - so a verb reads the same in the
# rail as on the sheet. Deliberately NOT an embedded live viewport: the panel must never expose the
# editing machinery on shared resources, and a draw-only list can't mutate anything by construction.
#
# PURE VIEW: the census below only READS the sheet, so the byte round-trip is untouched. Entries are
# gathered from BOTH authoring layers: structured resources (SignalRow triggers, exposed
# EventFunctions, dict + tree variables) and, for opened packs whose verbs are still literal code,
# the `## @ace_*` annotation shells (the same classifier the canvas shells use).

## The user double-clicked an entry - the workspace reveals that resource's row on the canvas.
signal reveal_requested(resource: Resource)

## The user double-clicked a Uses entry - the workspace opens that provider's behaviour
## AS A SHEET (the same jump as Ctrl+Click on one of its verbs).
signal open_provider_requested(provider_id: String)

const _ORGAN_ACCENTS: Dictionary = {
	"properties": EventSheetPalette.TEXT_SECONDARY,
	"state": EventSheetPalette.TEXT_SECONDARY,
	"triggers": EventSheetPalette.COLOR_TRIGGER,
	"actions": EventSheetPalette.COLOR_ACTION,
	"conditions": EventSheetPalette.COLOR_CONDITION,
	"expressions": EventSheetPalette.COLOR_EXPRESSION,
	# R35. What the pack adds to the EDITOR rather than to the game - a different audience from every
	# other organ, so it wears the trigger accent (the editor calls these, the way it calls a trigger).
	"editor_tools": EventSheetPalette.COLOR_TRIGGER,
	"uses": EventSheetPalette.TEXT_SECONDARY,
}
# 1x design heights - _header_height()/_entry_height() apply the editor display scale, and the
# hit-testing below uses the same helpers so click targets always match what was drawn.
const _HEADER_HEIGHT: float = 24.0
const _ENTRY_HEIGHT: float = 20.0


## The pill drawn before an entry, per organ: [text, bg, fg]. Verb organs reuse the canvas's ACE
## badge TOKENS and the neutral organs the reading marks' plain chip pair, so the rail, the sheet
## and the active theme speak one colour language. Read per redraw (the lists are small), which is
## also what lets a preset switch re-dress the rail without the panel being rebuilt.
static func _organ_pill(organ: String) -> Array:
	var event_style: EventSheetEventStyle = EventSheetActiveTheme.active().get_event_style()
	var reading: EventSheetReadingStyle = EventSheetActiveTheme.reading()
	var chrome: EventSheetChromeStyle = EventSheetActiveTheme.chrome()
	match organ:
		"properties":
			return ["@", reading.plain_chip_background_color, chrome.anatomy_knob_pill_foreground_color]
		"triggers":
			return ["➜", chrome.anatomy_trigger_pill_background_color,
				chrome.anatomy_trigger_pill_foreground_color]
		"actions":
			return ["A", event_style.ace_action_badge_background_color,
				event_style.ace_action_accent_color]
		"conditions":
			return ["?", event_style.ace_condition_badge_background_color,
				event_style.ace_condition_accent_color]
		"expressions":
			return ["ƒ", event_style.ace_expression_badge_background_color,
				event_style.ace_expression_accent_color]
		"editor_tools":
			# What the pack adds to the EDITOR rather than to the game - the editor calls these the
			# way it calls a trigger, so the pill wears the trigger pair too.
			return ["⚒", chrome.anatomy_trigger_pill_background_color,
				chrome.anatomy_trigger_pill_foreground_color]
		"uses":
			return ["↗", reading.plain_chip_background_color, reading.plain_chip_foreground_color]
	return ["·", reading.plain_chip_background_color, reading.plain_chip_foreground_color]


static func _header_height() -> float:
	return EventSheetPalette.scaled_f(_HEADER_HEIGHT)


static func _entry_height() -> float:
	return EventSheetPalette.scaled_f(_ENTRY_HEIGHT)

var _canvas: Control = null
var _scroll: ScrollContainer = null
var _rows: Array = []            # [{header: bool, organ, title, count, accent} | {header: false, organ, label, resource}]
var _folded: Dictionary = {}     # organ id -> true (session view state)
var _hover_index: int = -1


func _init() -> void:
	name = "Anatomy"
	custom_minimum_size = Vector2(EventSheetPalette.scaled_f(180.0), EventSheetPalette.scaled_f(120.0))
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var title: Label = Label.new()
	title.text = "Anatomy"
	title.add_theme_font_size_override("font_size", EventSheetPalette.scaled(12))
	title.add_theme_color_override("font_color", EventSheetPalette.TEXT_SECONDARY)
	add_child(title)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_canvas = Control.new()
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.draw.connect(_draw_rows)
	_canvas.gui_input.connect(_on_canvas_input)
	_canvas.mouse_exited.connect(func() -> void:
		_hover_index = -1
		_canvas.queue_redraw())
	_scroll.add_child(_canvas)


## Rebuilds the organ list from the sheet (called by the workspace on tab switch + after edits).
func refresh(sheet: EventSheetResource) -> void:
	_last_sheet = sheet  # fold toggles re-run the census against the same sheet
	_rows.clear()
	for organ: Dictionary in collect_anatomy(sheet):
		var organ_id: String = str(organ.get("id"))
		var entries: Array = organ.get("entries", [])
		_rows.append({
			"header": true,
			"organ": organ_id,
			"title": str(organ.get("title")),
			"count": entries.size(),
			"accent": _ORGAN_ACCENTS.get(organ_id, EventSheetPalette.TEXT_SECONDARY),
		})
		if bool(_folded.get(organ_id, false)):
			continue
		for entry: Dictionary in entries:
			_rows.append({
				"header": false,
				"organ": organ_id,
				"label": str(entry.get("label")),
				"resource": entry.get("resource") if entry.get("resource") is Resource else null,
				"provider": str(entry.get("provider", "")),
			})
	_canvas.custom_minimum_size = Vector2(0.0, _row_offset(_rows.size()))
	_canvas.queue_redraw()


func _row_offset(index: int) -> float:
	var y: float = 0.0
	for row_index: int in range(mini(index, _rows.size())):
		y += _header_height() if bool((_rows[row_index] as Dictionary).get("header")) else _entry_height()
	return y


func _row_index_at(y: float) -> int:
	var cursor: float = 0.0
	for index: int in range(_rows.size()):
		cursor += _header_height() if bool((_rows[index] as Dictionary).get("header")) else _entry_height()
		if y < cursor:
			return index
	return -1


## The panel's whole render: organ headers (accent title · count · underline) and entry rows drawn
## with the Define-block pill language. Small lists - a full redraw is cheap.
func _draw_rows() -> void:
	var font: Font = get_theme_default_font()
	var width: float = _canvas.size.x
	var reading: EventSheetReadingStyle = EventSheetActiveTheme.reading()
	var hover_wash: Color = EventSheetActiveTheme.chrome().object_bar_hover_wash_color
	# 1x-authored text sizes and offsets, scaled once per redraw so the rail tracks HiDPI.
	var ui: float = EventSheetPalette.ui_scale()
	var header_font: int = EventSheetPalette.scaled(12)
	var label_font: int = EventSheetPalette.scaled(11)
	var pill_font: int = EventSheetPalette.scaled(10)
	var y: float = 0.0
	for index: int in range(_rows.size()):
		var row: Dictionary = _rows[index]
		var height: float = _header_height() if bool(row.get("header")) else _entry_height()
		if index == _hover_index:
			_canvas.draw_rect(Rect2(0.0, y, width, height), hover_wash, true)
		if bool(row.get("header")):
			var accent: Color = row.get("accent")
			var header_text: String = "%s · %d" % [str(row.get("title")), int(row.get("count"))]
			if bool(_folded.get(str(row.get("organ")), false)):
				header_text = "▸ " + header_text
			_canvas.draw_string(font, Vector2(4.0 * ui, y + 16.0 * ui), header_text, HORIZONTAL_ALIGNMENT_LEFT, width - 8.0 * ui, header_font, accent)
			_canvas.draw_rect(Rect2(4.0 * ui, y + height - 3.0 * ui, width - 8.0 * ui, 1.0), Color(accent.r, accent.g, accent.b, 0.35), true)
		else:
			var pill: Array = _organ_pill(str(row.get("organ")))
			var pill_rect: Rect2 = Rect2(8.0 * ui, y + 3.0 * ui, 16.0 * ui, height - 6.0 * ui)
			var pill_box: StyleBoxFlat = StyleBoxFlat.new()
			pill_box.bg_color = pill[1]
			pill_box.set_corner_radius_all(3)
			pill_box.draw(_canvas.get_canvas_item(), pill_rect)
			_canvas.draw_string(font, Vector2(pill_rect.position.x + 4.0 * ui, y + 14.0 * ui), str(pill[0]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, pill_font, pill[2])
			var label_color: Color = reading.primary_text_color if row.get("resource") != null else reading.secondary_text_color
			_canvas.draw_string(font, Vector2(30.0 * ui, y + 14.0 * ui), str(row.get("label")), HORIZONTAL_ALIGNMENT_LEFT, width - 34.0 * ui, label_font, label_color)
		y += height


func _on_canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hover: int = _row_index_at((event as InputEventMouseMotion).position.y)
		if hover != _hover_index:
			_hover_index = hover
			_canvas.queue_redraw()
		return
	if not (event is InputEventMouseButton) or not (event as InputEventMouseButton).pressed \
			or (event as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT:
		return
	var index: int = _row_index_at((event as InputEventMouseButton).position.y)
	if index < 0:
		return
	var row: Dictionary = _rows[index]
	if bool(row.get("header")):
		# Click a header to fold/unfold its organ (view state only).
		var organ_id: String = str(row.get("organ"))
		_folded[organ_id] = not bool(_folded.get(organ_id, false))
		_refresh_from_rows()
	elif (event as InputEventMouseButton).double_click and row.get("resource") is Resource:
		reveal_requested.emit(row.get("resource"))
	elif (event as InputEventMouseButton).double_click and not str(row.get("provider", "")).is_empty():
		# Uses entries have no canvas row - the jump goes to the provider's own sheet.
		open_provider_requested.emit(str(row.get("provider")))


## Re-derives the visible rows after a fold toggle without re-running the census: rebuild from the
## header rows we already have is not possible (entries were dropped), so ask the workspace model.
func _refresh_from_rows() -> void:
	# The dock refreshes us on every edit; for a fold toggle just re-run refresh via the last sheet.
	if _last_sheet != null:
		refresh(_last_sheet)

var _last_sheet: EventSheetResource = null

# ── The census (static → headless-testable) ──────────────────────────────────────────────────────


## The seven organs, ordered, as [{id, title, entries: [{label, resource?}]}] - static + pure so the
## census is unit-testable without a panel. `resource` is present when the entry has a canvas row to
## jump to (signals, functions, annotation shells, tree variables); dict globals and providers are
## informational.
static func collect_anatomy(sheet: EventSheetResource) -> Array:
	var organs: Dictionary = {
		"properties": [], "state": [], "triggers": [],
		"actions": [], "conditions": [], "expressions": [], "editor_tools": [], "uses": [],
	}
	if sheet != null:
		var names: Array = sheet.variables.keys()
		names.sort()
		for var_name: Variant in names:
			var descriptor: Dictionary = sheet.variables.get(var_name, {})
			var entry: Dictionary = {"label": "%s : %s" % [str(var_name), str(descriptor.get("type", "Variant"))]}
			# Match the compiler default: exported unless explicitly false.
			if bool(descriptor.get("exported", descriptor.get("exposed", true))):
				(organs["properties"] as Array).append(entry)
			else:
				(organs["state"] as Array).append(entry)
		var providers: Dictionary = {}
		for row: Variant in sheet.events:
			_collect_row(row, organs, providers)
		for entry: Variant in sheet.functions:
			if not (entry is EventFunction):
				continue
			var event_function: EventFunction = entry as EventFunction
			if not event_function.expose_as_ace:
				continue  # internal helpers aren't part of the published anatomy
			var label: String = event_function.ace_display_name.strip_edges()
			if label.is_empty():
				label = event_function.function_name.capitalize()
			(organs[ViewportRowBuilder.define_role_for(event_function) + "s"] as Array).append(
				{"label": label, "resource": event_function})
		# R35. What this sheet adds to the editor itself. Derived by the one census every surface
		# shares (the Include bar and the picker's pack card read the same list), so a pack that stops
		# hanging a dock stops claiming one the moment it is rebuilt.
		for entry: Dictionary in EventSheetEditorToolCensus.from_sheet(sheet):
			(organs["editor_tools"] as Array).append({"label": str(entry.get("label", ""))})
		var provider_names: Array = providers.keys()
		provider_names.sort()
		for provider: Variant in provider_names:
			# `provider` makes the entry a JUMP: double-click opens the behaviour as a sheet.
			(organs["uses"] as Array).append({"label": str(provider), "provider": str(provider)})
	return [
		{"id": "properties", "title": "Properties", "entries": organs["properties"]},
		{"id": "state", "title": "State", "entries": organs["state"]},
		{"id": "triggers", "title": "Triggers", "entries": organs["triggers"]},
		{"id": "actions", "title": "Actions", "entries": organs["actions"]},
		{"id": "conditions", "title": "Conditions", "entries": organs["conditions"]},
		{"id": "expressions", "title": "Expressions", "entries": organs["expressions"]},
		{"id": "editor_tools", "title": "Editor Tools", "entries": organs["editor_tools"]},
		{"id": "uses", "title": "Uses", "entries": organs["uses"]},
	]


static func _collect_row(row: Variant, organs: Dictionary, providers: Dictionary) -> void:
	if row is EventGroup:
		var group: EventGroup = row as EventGroup
		var group_rows: Array = group.events if not group.events.is_empty() else group.rows
		for child: Variant in group_rows:
			_collect_row(child, organs, providers)
		return
	if row is LocalVariable:
		# Tree variables - how opened packs (and tree-first authors) carry their designer knobs.
		var variable: LocalVariable = row as LocalVariable
		var organ: String = "properties" if variable.exported else "state"
		(organs[organ] as Array).append({
			"label": "%s : %s" % [variable.name, variable.type_name],
			"resource": variable,
		})
		return
	if row is SignalRow and (row as SignalRow).trigger:
		var signal_row: SignalRow = row as SignalRow
		var label: String = signal_row.ace_name.strip_edges()
		if label.is_empty():
			label = signal_row.signal_name
		(organs["triggers"] as Array).append({"label": label, "resource": signal_row})
		return
	if row is RawCodeRow:
		# Opened packs keep UNLIFTABLE verbs as annotation shells - same classifier as the canvas.
		var shell: Dictionary = ViewportRowBuilder.define_shell_info((row as RawCodeRow).code)
		if not shell.is_empty():
			(organs[str(shell.get("kind")) + "s"] as Array).append(
				{"label": str(shell.get("name")), "resource": row})
		return
	if not (row is EventRow):
		return
	var event_row: EventRow = row as EventRow
	var aces: Array = []
	if event_row.trigger != null:
		aces.append(event_row.trigger)
	aces.append_array(event_row.conditions)
	aces.append_array(event_row.actions)
	if not event_row.trigger_provider_id.is_empty():
		aces.append(event_row)  # trigger identity can live on the row itself
	for ace: Variant in aces:
		var provider: String = ""
		if ace is EventRow:
			provider = (ace as EventRow).trigger_provider_id
		elif ace is Resource and (ace as Resource).get("provider_id") != null:
			provider = str((ace as Resource).get("provider_id"))
		# "Core" is the built-in vocabulary - Uses lists OUTSIDE vocabulary only.
		if not provider.is_empty() and provider != "Core":
			providers[provider] = true
	for sub_event: Variant in event_row.sub_events:
		_collect_row(sub_event, organs, providers)
