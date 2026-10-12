@tool
extends RefCounted
# Godot EventSheets - the pattern line in the help strip
#
# A theme that states pattern_in_help_strip keeps the conditions lane to conditions: the ⟡ chip that
# names the pattern an event was read as ("Making an object and putting it somewhere") leaves the
# lane, and selecting the event says it in the help strip instead, muted, with the chip's door to its
# Manual page. A finding on the same row outranks it, and the strip's hover still carries it.
# Pinned as values, on the real platformer_shooter showcase:
#   1. the token: off by default, on in the Editor Native starter and its rule, stated off in every
#      other shipped theme;
#   2. Editor Native draws no pattern chip; Classic Sheet draws the same chips as before;
#   3. the strip over an event that owns the pattern and nothing wrong: words, colour, door;
#   4. the strip over an event that also has a finding: the finding, with the pattern in its hover;
#   5. under Classic Sheet the strip says nothing about patterns.

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "native_pattern_strip_test"
const SHOWCASE := "res://demo/showcase/platformer_shooter/platformer_shooter.gd"
const NATIVE_THEME := "res://addons/eventsheet/themes/editor_native_theme.tres"
const CLASSIC_THEME := "res://addons/eventsheet/themes/classic_sheet_theme.tres"
const PATTERN_WORDS := "⟡ Making an object and putting it somewhere"
const SPAWN_FINDING := "This adds a node to the tree while the physics server is busy, and Godot refuses it. Add it on the next idle moment instead."
const OTHER_THEMES := [
	"res://addons/eventsheet/themes/classic_sheet_theme.tres",
	"res://addons/eventsheet/themes/mockup_slate_theme.tres",
	"res://demo/themes/catppuccin_mocha_theme.tres",
	"res://demo/themes/designer_template_theme.tres",
	"res://demo/themes/dracula_theme.tres",
	"res://demo/themes/gruvbox_dark_theme.tres",
	"res://demo/themes/high_contrast_theme.tres",
	"res://demo/themes/monokai_theme.tres",
	"res://demo/themes/nord_theme.tres",
	"res://demo/themes/soft_light_theme.tres",
	"res://demo/themes/solarized_light_theme.tres",
]


static func run() -> bool:
	var ok: bool = true
	ok = _test_token() and ok
	ok = _test_lane_chips() and ok
	ok = _test_strip() and ok
	return ok


static func _test_token() -> bool:
	var native: EventSheetEventStyle = (load(NATIVE_THEME) as EventSheetEditorStyle).get_event_style()
	var built: EventSheetEventStyle = EventSheetEditorThemeDeriver.native_style(
		EventSheetEditorThemeDeriver.NATIVE_DARK_REFERENCE_BASE).get_event_style()
	var others: Array = []
	var expected_others: Array = []
	for path: String in OTHER_THEMES:
		var style: EventSheetEditorStyle = load(path) as EventSheetEditorStyle
		others.append([path.get_file(), style.get_event_style().pattern_in_help_strip,
			FileAccess.get_file_as_string(path).contains("pattern_in_help_strip = false")])
		expected_others.append([path.get_file(), false, true])
	return SUPPORT.pins(TEST_NAME, [
		["the token defaults off", EventSheetEventStyle.new().pattern_in_help_strip, false],
		["the starter states it on", native.pattern_in_help_strip, true],
		["and so does the rule it is built by", built.pattern_in_help_strip, true],
		["every other shipped theme states it off", others, expected_others],
	])


static func _test_lane_chips() -> bool:
	var native: EventSheetViewport = _viewport_for(NATIVE_THEME)
	var classic: EventSheetViewport = _viewport_for(CLASSIC_THEME)
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["Editor Native draws no pattern chip in the conditions lane", _pattern_chips(native), []],
		["Classic Sheet draws the same two chips as before", _pattern_chips(classic),
			[PATTERN_WORDS, PATTERN_WORDS]],
	])
	native.free()
	classic.free()
	return ok


static func _test_strip() -> bool:
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	var sheet: EventSheetResource = _shooter(NATIVE_THEME)
	dock.setup(sheet)
	var clean: EventRowData = null
	var flagged: EventRowData = null
	for index: int in range(dock._viewport._flat_rows.size()):
		var row: EventRowData = dock._viewport._row_at(index)
		if row == null or not (row.source_resource is EventRow):
			continue
		if ViewportTooltipHelper.pattern_strip_line(sheet, (row.source_resource as EventRow).event_uid).is_empty():
			continue
		if row.attention_note.is_empty() and clean == null:
			clean = row
		elif not row.attention_note.is_empty() and flagged == null:
			flagged = row
	dock._update_row_help_strip(clean)
	var clean_said: Array = [dock._row_help_label.visible, dock._row_help_label.text,
		dock._row_help_label.modulate == EventSheetActiveTheme.reading().muted_text_color,
		dock._row_help_button.visible, dock._row_help_button.text,
		str(dock._row_help_finding.get("pattern", ""))]
	dock._update_row_help_strip(flagged)
	var flagged_said: Array = [dock._row_help_label.text, dock._row_help_button.text,
		dock._row_help_label.tooltip_text]
	dock._update_row_help_strip(EventRowData.new())
	var nothing_said: Array = [dock._row_help_label.visible, dock._row_help_button.visible]
	dock.free()
	var classic_dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	var classic_sheet: EventSheetResource = _shooter(CLASSIC_THEME)
	classic_dock.setup(classic_sheet)
	var classic_said: Array = []
	for index: int in range(classic_dock._viewport._flat_rows.size()):
		var row: EventRowData = classic_dock._viewport._row_at(index)
		if row == null or not (row.source_resource is EventRow) or not row.attention_note.is_empty():
			continue
		if ViewportTooltipHelper.pattern_strip_line(classic_sheet, (row.source_resource as EventRow).event_uid).is_empty():
			continue
		classic_dock._update_row_help_strip(row)
		classic_said = [classic_dock._row_help_label.visible, classic_dock._row_help_button.visible]
		break
	classic_dock.free()
	return SUPPORT.pins(TEST_NAME, [
		["the showcase has a pattern event with nothing wrong and one with a finding",
			[clean != null, flagged != null], [true, true]],
		["selected, the clean one says its pattern, muted, with the Manual door", clean_said,
			[true, PATTERN_WORDS, true, true, "Open in the Manual", "create_object"]],
		["the one with a finding says the finding, and its hover adds the pattern", flagged_said,
			[SPAWN_FINDING, "Use the safe spawn row", "%s\n\n%s" % [SPAWN_FINDING, PATTERN_WORDS]]],
		["a row with nothing to say clears the strip", nothing_said, [false, false]],
		["under Classic Sheet the strip says nothing about patterns", classic_said, [false, false]],
	])


static func _shooter(theme_path: String) -> EventSheetResource:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SHOWCASE)
	sheet.editor_style = (load(theme_path) as EventSheetEditorStyle).duplicate(true)
	return sheet


static func _viewport_for(theme_path: String) -> EventSheetViewport:
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_ace_registry(EventSheetACERegistry.new())
	viewport.set_sheet(_shooter(theme_path))
	return viewport


## Every pattern chip the viewport draws, by its words, in sheet order.
static func _pattern_chips(viewport: EventSheetViewport) -> Array:
	var chips: Array = []
	for index: int in range(viewport._flat_rows.size()):
		var row: EventRowData = viewport._row_at(index)
		if row == null or not (row.source_resource is EventRow):
			continue
		viewport._ensure_event_spans(row)
		for span: SemanticSpan in row.spans:
			if span != null and span.metadata is Dictionary \
					and str((span.metadata as Dictionary).get("kind", "")) == "pattern_chip":
				chips.append(span.text)
	return chips
