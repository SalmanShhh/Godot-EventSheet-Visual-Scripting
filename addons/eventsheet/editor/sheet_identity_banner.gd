# EventSheet — Sheet identity banner
# A slim band above the sheet announcing what kind of sheet is being edited:
#   ⚙ PatrolBehavior — Behavior · acts on host: CharacterBody2D
#   ◆ PatrollingGuard — Custom Node · extends CharacterBody2D
# Hidden for plain event sheets. Dual-audience cue (Godot: "custom node with an icon";
# event sheets: "behavior attached to an object"); clicking it opens the Sheet Type dialog.
@tool
class_name SheetIdentityBanner
extends Control

signal edit_requested

const BANNER_HEIGHT := 24.0
const ICON_SIZE := 14.0
## The Publishes Manifest (glance layer §11): a second band listing what the behaviour PUBLISHES —
## its ACE dictionary pinned above the sheet. Role hues match the block/badge families elsewhere.
const MANIFEST_HEIGHT := 18.0
const MANIFEST_FONT_SIZE := 12
const _MANIFEST_TRIGGERS := Color("#7fd494")     # ➜ signal triggers
const _MANIFEST_ACTIONS := Color("#f2c879")      # ⚡ exposed actions
const _MANIFEST_CONDITIONS := Color("#69ccb3")   # exposed conditions
const _MANIFEST_EXPRESSIONS := Color("#d7a6ea")  # ƒx exposed expressions
const _MANIFEST_KNOBS := Color("#9cc4ef")        # @ exported designer knobs

var _viewport: EventSheetViewport = null
var _label: String = ""
var _is_behavior: bool = false
var _icon: Texture2D = null
var _manifest_segments: Array = []  # [{text, color}] — the non-empty role pills, computed on refresh

## The published-API census behind the manifest pills: trigger signals, exposed functions split by
## return type (void→action, bool→condition, else→expression), and exported "knob" variables — counted
## from BOTH structured rows (SignalRow/EventFunction/LocalVariable) and un-lifted `## @ace_*` RawCode
## blocks, so it reads right whether a pack lifted to rows or still ships annotated GDScript. Static +
## pure → unit-testable. Returns {triggers, actions, conditions, expressions, knobs}.
static func manifest_for(sheet: EventSheetResource) -> Dictionary:
	var counts: Dictionary = {"triggers": 0, "actions": 0, "conditions": 0, "expressions": 0, "knobs": 0}
	if sheet == null:
		return counts
	_census_rows(sheet.events, counts)
	for function_variant: Variant in sheet.functions:
		if function_variant is EventFunction and (function_variant as EventFunction).expose_as_ace:
			match (function_variant as EventFunction).return_type:
				TYPE_NIL:
					counts["actions"] += 1
				TYPE_BOOL:
					counts["conditions"] += 1
				_:
					counts["expressions"] += 1
	for var_key: Variant in sheet.variables:
		var descriptor: Variant = sheet.variables[var_key]
		if descriptor is Dictionary and bool((descriptor as Dictionary).get("exported", (descriptor as Dictionary).get("exposed", true))):
			counts["knobs"] += 1
	return counts

static func _census_rows(rows: Array, counts: Dictionary) -> void:
	for row: Variant in rows:
		if row is SignalRow:
			if (row as SignalRow).trigger:
				counts["triggers"] += 1
		elif row is LocalVariable:
			if (row as LocalVariable).exported:
				counts["knobs"] += 1
		elif row is RawCodeRow:
			# Un-lifted packs keep their public verbs as annotated GDScript — count those too.
			var code: String = (row as RawCodeRow).code
			counts["triggers"] += code.count("## @ace_trigger")
			counts["actions"] += code.count("## @ace_action")
			counts["conditions"] += code.count("## @ace_condition")
			counts["expressions"] += code.count("## @ace_expression")
		elif row is EventGroup:
			var group: EventGroup = row as EventGroup
			_census_rows(group.events if not group.events.is_empty() else group.rows, counts)

## Builds the ordered non-zero manifest pill segments [{text, color}] from a census — a role with a
## zero count is dropped so the band stays calm. Static so the layout is testable.
static func _build_manifest_segments(counts: Dictionary) -> Array:
	var segments: Array = []
	var triggers: int = int(counts.get("triggers", 0))
	if triggers > 0:
		segments.append({"text": "➜ %d trigger%s" % [triggers, "" if triggers == 1 else "s"], "color": _MANIFEST_TRIGGERS})
	var actions: int = int(counts.get("actions", 0))
	if actions > 0:
		segments.append({"text": "⚡ %d action%s" % [actions, "" if actions == 1 else "s"], "color": _MANIFEST_ACTIONS})
	var conditions: int = int(counts.get("conditions", 0))
	if conditions > 0:
		segments.append({"text": "cond %d" % conditions, "color": _MANIFEST_CONDITIONS})
	var expressions: int = int(counts.get("expressions", 0))
	if expressions > 0:
		segments.append({"text": "ƒx %d" % expressions, "color": _MANIFEST_EXPRESSIONS})
	var knobs: int = int(counts.get("knobs", 0))
	if knobs > 0:
		segments.append({"text": "@ %d knob%s" % [knobs, "" if knobs == 1 else "s"], "color": _MANIFEST_KNOBS})
	return segments

func setup(viewport: EventSheetViewport) -> void:
	_viewport = viewport
	name = "SheetIdentityBanner"
	custom_minimum_size = Vector2(0.0, BANNER_HEIGHT)
	tooltip_text = "Click to edit the sheet type (name, icon, host class)."
	visible = false

## Refreshes the banner from the sheet; hides itself for plain event sheets.
func update_from_sheet(sheet: EventSheetResource) -> void:
	_icon = null
	if sheet == null or (not sheet.behavior_mode and sheet.custom_class_name.strip_edges().is_empty()):
		visible = false
		queue_redraw()
		return
	_is_behavior = sheet.behavior_mode
	var display_name: String = sheet.custom_class_name.strip_edges()
	if display_name.is_empty():
		display_name = "Behavior"
	if _is_behavior:
		_label = "%s — Behavior · acts on host: %s" % [display_name, sheet.host_class]
	else:
		_label = "%s — Custom Node · extends %s" % [display_name, sheet.host_class]
	var icon_path: String = sheet.custom_class_icon.strip_edges()
	if icon_path.begins_with("res://") and ResourceLoader.exists(icon_path):
		var loaded: Resource = load(icon_path)
		if loaded is Texture2D:
			_icon = loaded
	# Publishes Manifest (glance §11): what this behaviour exposes, pinned above the sheet.
	_manifest_segments = _build_manifest_segments(manifest_for(sheet))
	var total_height: float = BANNER_HEIGHT + (MANIFEST_HEIGHT if not _manifest_segments.is_empty() else 0.0)
	custom_minimum_size = Vector2(0.0, total_height)
	visible = true
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		edit_requested.emit()
		accept_event()

func _draw() -> void:
	if _viewport == null:
		return
	var style: EventSheetEventStyle = _viewport.get_event_style()
	var accent: Color = style.behavior_accent_color if _is_behavior else style.column_header_conditions_color
	var background: Color = style.column_header_background_color
	draw_rect(Rect2(Vector2.ZERO, size), background, true)
	draw_rect(Rect2(0.0, 0.0, 3.0, size.y), accent, true)
	# Top band = identity; positions anchor to BANNER_HEIGHT (not size.y) so the manifest band below
	# doesn't drag the identity line off-centre.
	var identity_baseline: float = BANNER_HEIGHT * 0.5 + 5.0
	var x: float = 10.0
	if _icon != null:
		var icon_y: float = (BANNER_HEIGHT - ICON_SIZE) * 0.5
		draw_texture_rect(_icon, Rect2(x, icon_y, ICON_SIZE, ICON_SIZE), false)
		x += ICON_SIZE + 6.0
	else:
		# Fallback glyphs keep the types visually distinct without custom art.
		var glyph: String = "⚙" if _is_behavior else "◆"
		draw_string(ThemeDB.fallback_font, Vector2(x, identity_baseline), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, accent)
		x += 18.0
	draw_string(ThemeDB.fallback_font, Vector2(x, identity_baseline), _label, HORIZONTAL_ALIGNMENT_LEFT, max(size.x - x - 8.0, 10.0), 13, accent)
	# Second band — the Publishes Manifest pills, each in its role hue, " · "-separated.
	if not _manifest_segments.is_empty():
		var font: Font = ThemeDB.fallback_font
		var mx: float = 12.0
		var manifest_baseline: float = BANNER_HEIGHT + MANIFEST_HEIGHT * 0.5 + 4.0
		var separator_color: Color = Color(0.62, 0.64, 0.68, 0.55)
		for segment_index: int in range(_manifest_segments.size()):
			if segment_index > 0:
				draw_string(font, Vector2(mx, manifest_baseline), " · ", HORIZONTAL_ALIGNMENT_LEFT, -1.0, MANIFEST_FONT_SIZE, separator_color)
				mx += font.get_string_size(" · ", HORIZONTAL_ALIGNMENT_LEFT, -1.0, MANIFEST_FONT_SIZE).x
			var segment: Dictionary = _manifest_segments[segment_index]
			var segment_text: String = str(segment.get("text"))
			draw_string(font, Vector2(mx, manifest_baseline), segment_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, MANIFEST_FONT_SIZE, segment.get("color"))
			mx += font.get_string_size(segment_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, MANIFEST_FONT_SIZE).x
