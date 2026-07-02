@tool
class_name BehaviourAnatomyPanel
extends VBoxContainer
# The Behaviour Anatomy panel — a left-rail READ MODEL that shows the active sheet as an organism
# with always-visible "organs": Properties (exported knobs) · State (internal vars) · Triggers ·
# Actions · Conditions · Expressions · Uses (outside vocabulary it calls). A behaviour's whole
# public shape becomes one glance, and double-clicking an entry jumps the canvas to its row.
#
# The organ list is CUSTOM-DRAWN with the same pill/badge language as the canvas's Define blocks
# (role-coloured pills, muted labels) rather than a generic Tree — so a verb reads the same in the
# rail as on the sheet. Deliberately NOT an embedded live viewport: the panel must never expose the
# editing machinery on shared resources, and a draw-only list can't mutate anything by construction.
#
# PURE VIEW: the census below only READS the sheet, so the byte round-trip is untouched. Entries are
# gathered from BOTH authoring layers: structured resources (SignalRow triggers, exposed
# EventFunctions, dict + tree variables) and, for opened packs whose verbs are still literal code,
# the `## @ace_*` annotation shells (the same classifier the canvas shells use).

## The user double-clicked an entry — the workspace reveals that resource's row on the canvas.
signal reveal_requested(resource: Resource)

const _ORGAN_ACCENTS: Dictionary = {
	"properties": EventSheetPalette.TEXT_SECONDARY,
	"state": EventSheetPalette.TEXT_SECONDARY,
	"triggers": EventSheetPalette.COLOR_TRIGGER,
	"actions": EventSheetPalette.COLOR_ACTION,
	"conditions": EventSheetPalette.COLOR_CONDITION,
	"expressions": EventSheetPalette.COLOR_EXPRESSION,
	"uses": EventSheetPalette.TEXT_SECONDARY,
}
## The pill drawn before an entry, per organ: [text, bg, fg]. Verb organs reuse the canvas's ACE
## badge pairs so the rail and the sheet speak one colour language.
const _ORGAN_PILLS: Dictionary = {
	"properties": ["@", Color("#2c313a"), Color("#9cc4ef")],
	"state": ["·", Color("#2c313a"), Color("#9aa1ad")],
	"triggers": ["➜", Color("#233b2b"), Color("#7fd494")],
	"actions": ["A", Color("#463414"), Color("#f2c879")],
	"conditions": ["?", Color("#123a30"), Color("#77d3b7")],
	"expressions": ["ƒ", Color("#3a2247"), Color("#d7a6ea")],
	"uses": ["↗", Color("#2c313a"), Color("#9aa1ad")],
}
const _HEADER_HEIGHT: float = 24.0
const _ENTRY_HEIGHT: float = 20.0

var _canvas: Control = null
var _scroll: ScrollContainer = null
var _rows: Array = []            # [{header: bool, organ, title, count, accent} | {header: false, organ, label, resource}]
var _folded: Dictionary = {}     # organ id -> true (session view state)
var _hover_index: int = -1

func _init() -> void:
	name = "Anatomy"
	custom_minimum_size = Vector2(180.0, 120.0)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var title: Label = Label.new()
	title.text = "Anatomy"
	title.add_theme_font_size_override("font_size", 12)
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
			})
	_canvas.custom_minimum_size = Vector2(0.0, _row_offset(_rows.size()))
	_canvas.queue_redraw()

func _row_offset(index: int) -> float:
	var y: float = 0.0
	for row_index: int in range(mini(index, _rows.size())):
		y += _HEADER_HEIGHT if bool((_rows[row_index] as Dictionary).get("header")) else _ENTRY_HEIGHT
	return y

func _row_index_at(y: float) -> int:
	var cursor: float = 0.0
	for index: int in range(_rows.size()):
		cursor += _HEADER_HEIGHT if bool((_rows[index] as Dictionary).get("header")) else _ENTRY_HEIGHT
		if y < cursor:
			return index
	return -1

## The panel's whole render: organ headers (accent title · count · underline) and entry rows drawn
## with the Define-block pill language. Small lists — a full redraw is cheap.
func _draw_rows() -> void:
	var font: Font = get_theme_default_font()
	var width: float = _canvas.size.x
	var y: float = 0.0
	for index: int in range(_rows.size()):
		var row: Dictionary = _rows[index]
		var height: float = _HEADER_HEIGHT if bool(row.get("header")) else _ENTRY_HEIGHT
		if index == _hover_index:
			_canvas.draw_rect(Rect2(0.0, y, width, height), Color(1.0, 1.0, 1.0, 0.06), true)
		if bool(row.get("header")):
			var accent: Color = row.get("accent")
			var header_text: String = "%s · %d" % [str(row.get("title")), int(row.get("count"))]
			if bool(_folded.get(str(row.get("organ")), false)):
				header_text = "▸ " + header_text
			_canvas.draw_string(font, Vector2(4.0, y + 16.0), header_text, HORIZONTAL_ALIGNMENT_LEFT, width - 8.0, 12, accent)
			_canvas.draw_rect(Rect2(4.0, y + height - 3.0, width - 8.0, 1.0), Color(accent.r, accent.g, accent.b, 0.35), true)
		else:
			var pill: Array = _ORGAN_PILLS.get(str(row.get("organ")), ["·", Color("#2c313a"), Color("#9aa1ad")])
			var pill_rect: Rect2 = Rect2(8.0, y + 3.0, 16.0, height - 6.0)
			var pill_box: StyleBoxFlat = StyleBoxFlat.new()
			pill_box.bg_color = pill[1]
			pill_box.set_corner_radius_all(3)
			pill_box.draw(_canvas.get_canvas_item(), pill_rect)
			_canvas.draw_string(font, Vector2(pill_rect.position.x + 4.0, y + 14.0), str(pill[0]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, pill[2])
			var label_color: Color = EventSheetPalette.TEXT_PRIMARY if row.get("resource") != null else EventSheetPalette.TEXT_SECONDARY
			_canvas.draw_string(font, Vector2(30.0, y + 14.0), str(row.get("label")), HORIZONTAL_ALIGNMENT_LEFT, width - 34.0, 11, label_color)
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

## Re-derives the visible rows after a fold toggle without re-running the census: rebuild from the
## header rows we already have is not possible (entries were dropped), so ask the workspace model.
func _refresh_from_rows() -> void:
	# The dock refreshes us on every edit; for a fold toggle just re-run refresh via the last sheet.
	if _last_sheet != null:
		refresh(_last_sheet)

var _last_sheet: EventSheetResource = null

# ── The census (static → headless-testable) ──────────────────────────────────────────────────────

## The seven organs, ordered, as [{id, title, entries: [{label, resource?}]}] — static + pure so the
## census is unit-testable without a panel. `resource` is present when the entry has a canvas row to
## jump to (signals, functions, annotation shells, tree variables); dict globals and providers are
## informational.
static func collect_anatomy(sheet: EventSheetResource) -> Array:
	var organs: Dictionary = {
		"properties": [], "state": [], "triggers": [],
		"actions": [], "conditions": [], "expressions": [], "uses": [],
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
		var provider_names: Array = providers.keys()
		provider_names.sort()
		for provider: Variant in provider_names:
			(organs["uses"] as Array).append({"label": str(provider)})
	return [
		{"id": "properties", "title": "Properties", "entries": organs["properties"]},
		{"id": "state", "title": "State", "entries": organs["state"]},
		{"id": "triggers", "title": "Triggers", "entries": organs["triggers"]},
		{"id": "actions", "title": "Actions", "entries": organs["actions"]},
		{"id": "conditions", "title": "Conditions", "entries": organs["conditions"]},
		{"id": "expressions", "title": "Expressions", "entries": organs["expressions"]},
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
		# Tree variables — how opened packs (and tree-first authors) carry their designer knobs.
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
		# Opened packs keep UNLIFTABLE verbs as annotation shells — same classifier as the canvas.
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
		# "Core" is the built-in vocabulary — Uses lists OUTSIDE vocabulary only.
		if not provider.is_empty() and provider != "Core":
			providers[provider] = true
	for sub_event: Variant in event_row.sub_events:
		_collect_row(sub_event, organs, providers)
