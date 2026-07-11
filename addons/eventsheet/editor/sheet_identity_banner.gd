# EventSheet - Sheet identity banner
# A slim band above the sheet announcing what kind of sheet is being edited:
#   ⚙ PatrolBehavior - Behavior · acts on host: CharacterBody2D
#   ◆ PatrollingGuard - Custom Node · extends CharacterBody2D
# Hidden for plain event sheets. Dual-audience cue (Godot: "custom node with an icon";
# event sheets: "behavior attached to an object"); clicking it opens the Sheet Type dialog.
@tool
class_name SheetIdentityBanner
extends Control

signal edit_requested

const BANNER_HEIGHT := 24.0
const ICON_SIZE := 14.0
## The Publishes Manifest: a second band listing what the behaviour PUBLISHES -
## its ACE dictionary pinned above the sheet. Role hues match the block/badge families elsewhere.
const MANIFEST_HEIGHT := 18.0
const MANIFEST_FONT_SIZE := 12
const _MANIFEST_TRIGGERS := EventSheetPalette.COLOR_MANIFEST_TRIGGERS
const _MANIFEST_ACTIONS := EventSheetPalette.COLOR_MANIFEST_ACTIONS
const _MANIFEST_CONDITIONS := EventSheetPalette.COLOR_MANIFEST_CONDITIONS
const _MANIFEST_EXPRESSIONS := EventSheetPalette.COLOR_MANIFEST_EXPRESSIONS
const _MANIFEST_KNOBS := EventSheetPalette.COLOR_MANIFEST_KNOBS

var _viewport: EventSheetViewport = null
var _label: String = ""
var _is_behavior: bool = false
var _intent: EventSheetScriptIntent.Intent = EventSheetScriptIntent.Intent.EVENT_SHEET
var _icon: Texture2D = null
var _manifest_segments: Array = []  # [{text, color}] - the non-empty role pills, computed on refresh
# Sheet health chip (right end of the identity line): the last diagnostics result, pushed ONLY on a
# save / Check-Sheet run - never an ambient recompile (a full compile is far too costly to run per keystroke). `_health_known` gates its draw
# so a freshly-opened, not-yet-checked sheet shows no (possibly false) green.
var _health_known: bool = false
var _health_count: int = 0
var _health_sheet: EventSheetResource = null


## The health chip {text, color} for the banner's right end: the calm "works" signal (green
## ✓) or the flag count (amber ⚠). Static → testable.
static func health_chip(issue_count: int) -> Dictionary:
	if issue_count <= 0:
		return {"text": "✓ no issues", "color": EventSheetPalette.COLOR_HEALTH_OK}
	return {"text": "⚠ %d flagged" % issue_count, "color": EventSheetPalette.COLOR_HEALTH_WARN}


## Pushes the last diagnostics result to the health chip. Called from the dock's _run_diagnostics only
## (save-time / on-demand), so the chip never triggers a recompile on its own.
func set_health(issue_count: int) -> void:
	_health_known = true
	_health_count = issue_count
	queue_redraw()


## The published-API census behind the manifest pills: trigger signals, exposed functions split by
## return type (void→action, bool→condition, else→expression), and exported "knob" variables - counted
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
			# Un-lifted packs keep their public verbs as annotated GDScript - count those too.
			var code: String = (row as RawCodeRow).code
			counts["triggers"] += code.count("## @ace_trigger")
			counts["actions"] += code.count("## @ace_action")
			counts["conditions"] += code.count("## @ace_condition")
			counts["expressions"] += code.count("## @ace_expression")
		elif row is EventGroup:
			var group: EventGroup = row as EventGroup
			_census_rows(group.events if not group.events.is_empty() else group.rows, counts)


## Builds the ordered non-zero manifest pill segments [{text, color}] from a census - a role with a
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


## Refreshes the banner from the sheet; hides itself only when there is no sheet at all.
func update_from_sheet(sheet: EventSheetResource) -> void:
	_icon = null
	# Every sheet gets its identity strip - INCLUDING the plain event sheets beginners make.
	# Hiding it for exactly those sheets (the old rule) meant the newcomers who most needed the
	# "what is this / click to configure" cue and the save-time health chip never saw either.
	if sheet == null:
		visible = false
		queue_redraw()
		return
	_is_behavior = sheet.behavior_mode
	_intent = EventSheetScriptIntent.of_sheet(sheet)
	var intent_label: String = str(EventSheetScriptIntent.display(_intent).get("label", ""))
	var display_name: String = sheet.custom_class_name.strip_edges()
	if display_name.is_empty():
		display_name = sheet.autoload_name.strip_edges() if sheet.autoload_mode else intent_label
	# Each intent reads distinctly at a glance: what it IS, then how it meets the project. The
	# banner draws on canvas (no auto-translation), so the TEMPLATES translate explicitly -
	# names/classes stay verbatim inside the placeholders.
	match _intent:
		EventSheetScriptIntent.Intent.BEHAVIOUR:
			_label = EventSheetL10n.translate("%s - Behavior · acts on host: %s") % [display_name, sheet.host_class]
		EventSheetScriptIntent.Intent.AUTOLOAD:
			_label = EventSheetL10n.translate("%s - Autoload · one instance, project-wide") % display_name
		EventSheetScriptIntent.Intent.EDITOR_TOOL:
			_label = EventSheetL10n.translate("%s - Editor Tool · runs in the editor (File > Run)") % display_name
		EventSheetScriptIntent.Intent.CUSTOM_RESOURCE:
			_label = EventSheetL10n.translate("%s - Custom Resource · every .tres of it is a data asset") % display_name
		EventSheetScriptIntent.Intent.EVENT_SHEET:
			# The plain sheet a beginner makes: say what it is and where it runs, in one line.
			_label = EventSheetL10n.translate("Event Sheet · a script for the %s it's attached to") % sheet.host_class
		_:
			_label = EventSheetL10n.translate("%s - Custom Node · extends %s") % [display_name, sheet.host_class]
	var icon_path: String = sheet.custom_class_icon.strip_edges()
	if icon_path.begins_with("res://") and ResourceLoader.exists(icon_path):
		var loaded: Resource = load(icon_path)
		if loaded is Texture2D:
			_icon = loaded
	# A different sheet's health is unknown until it's checked - never carry the old result across.
	if sheet != _health_sheet:
		_health_known = false
		_health_sheet = sheet
	# Publishes Manifest: what this behaviour exposes, pinned above the sheet.
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
		# Fallback glyphs keep the types visually distinct without custom art (one per intent).
		var glyph: String = str(EventSheetScriptIntent.display(_intent).get("glyph", "◆"))
		draw_string(ThemeDB.fallback_font, Vector2(x, identity_baseline), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, accent)
		x += 18.0
	# Health chip on the right end of the identity line (drawn first so the label reserves room for it).
	var label_right: float = size.x - 8.0
	if _health_known:
		var chip: Dictionary = health_chip(_health_count)
		var chip_text: String = str(chip.get("text"))
		var chip_width: float = ThemeDB.fallback_font.get_string_size(chip_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, MANIFEST_FONT_SIZE).x
		var chip_x: float = size.x - chip_width - 10.0
		draw_string(ThemeDB.fallback_font, Vector2(chip_x, identity_baseline), chip_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, MANIFEST_FONT_SIZE, chip.get("color"))
		label_right = chip_x - 8.0
	draw_string(ThemeDB.fallback_font, Vector2(x, identity_baseline), _label, HORIZONTAL_ALIGNMENT_LEFT, max(label_right - x, 10.0), 13, accent)
	# Second band - the Publishes Manifest pills, each in its role hue, " · "-separated.
	if not _manifest_segments.is_empty():
		var font: Font = ThemeDB.fallback_font
		var mx: float = 12.0
		var manifest_baseline: float = BANNER_HEIGHT + MANIFEST_HEIGHT * 0.5 + 4.0
		var separator_color: Color = EventSheetPalette.COLOR_BANNER_SEPARATOR
		for segment_index: int in range(_manifest_segments.size()):
			if segment_index > 0:
				draw_string(font, Vector2(mx, manifest_baseline), " · ", HORIZONTAL_ALIGNMENT_LEFT, -1.0, MANIFEST_FONT_SIZE, separator_color)
				mx += font.get_string_size(" · ", HORIZONTAL_ALIGNMENT_LEFT, -1.0, MANIFEST_FONT_SIZE).x
			var segment: Dictionary = _manifest_segments[segment_index]
			var segment_text: String = str(segment.get("text"))
			draw_string(font, Vector2(mx, manifest_baseline), segment_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, MANIFEST_FONT_SIZE, segment.get("color"))
			mx += font.get_string_size(segment_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, MANIFEST_FONT_SIZE).x
