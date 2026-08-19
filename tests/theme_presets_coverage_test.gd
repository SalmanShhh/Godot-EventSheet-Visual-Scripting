# Godot EventSheets - every bundled theme has an opinion about every colour
#
# A preset is written against the tokens that existed the day it was saved. Ship a new colour token
# and every older preset silently keeps the plugin's own dark default for it: a near-black chip on
# pale paper, an EventForge-indigo bar on a green theme, a margin that belongs to another palette.
# High Contrast was gated against that from the start; every other bundled preset was not, and drifted
# up to fifty tokens behind while the gate stayed green.
#
# So the same promise, for all ten, in the two halves a preset is actually made of:
#
#   AUTHORED - the sheet and its cells (event style, condition style, action style). These are the
#   preset's identity, one deliberate colour at a time, and the FILE has to state each one. A `.tres`
#   omits any property equal to the script default, so the file - not the loaded resource - is the
#   only place "this theme chose that colour" and "this theme never heard of it" look different.
#
#   DERIVED - the reading marks, the bars around the sheet and the Manual. These come from ONE shared
#   rule (EventSheetThemeDerivation) applied to the tokens above, so a new token reaches all ten
#   presets the day it ships. A preset may still overrule any of them by stating it; what it may not
#   do is sit on a value nobody chose. Hence: stated, or equal to what the rule derives.
#
# Plus the rule's own coverage, swept with a sentinel: a derived token the rule forgets to write
# would satisfy the check above on every preset at once (they would all agree on the default), which
# is exactly the hole this file exists to close.
@tool
class_name ThemePresetsCoverageTest
extends RefCounted

## Every bundled preset: the six generated from well-known palettes, the three hand-written ones,
## and the Mockup Slate that ships inside the addon.
const PRESET_PATHS := [
	"res://demo/themes/dracula_theme.tres",
	"res://demo/themes/nord_theme.tres",
	"res://demo/themes/gruvbox_dark_theme.tres",
	"res://demo/themes/monokai_theme.tres",
	"res://demo/themes/solarized_light_theme.tres",
	"res://demo/themes/catppuccin_mocha_theme.tres",
	"res://demo/themes/high_contrast_theme.tres",
	"res://demo/themes/soft_light_theme.tres",
	"res://demo/themes/designer_template_theme.tres",
	"res://addons/eventsheet/themes/mockup_slate_theme.tres",
]

## The derived tokens the shared rule deliberately leaves at nothing, in enumeration order. Clear is
## a MEANING here, not a gap: a clear pattern chip follows the plain chip it sits beside, and a clear
## Manual page sits on the editor's own paper the way the Manual ships. Adding a token here is a
## design decision - the default is that the rule dresses it.
const CLEAR_BY_DESIGN := [
	"pattern_chip_background_color", "pattern_chip_foreground_color",
	"page_background_color", "search_hit_color",
	"contents_active_background_color", "contents_active_text_color",
]

## What the sentinel sweep paints over every derived colour before asking the rule to repaint it.
## Any colour, as long as no palette would ever land on it by accident.
const SENTINEL := Color(0.123, 0.456, 0.789, 0.321)


static func run() -> bool:
	var ok: bool = true
	ok = _test_the_rule_dresses_every_derived_colour() and ok
	ok = _test_every_preset_states_its_own_colours() and ok
	ok = _test_every_preset_is_current_with_the_rule() and ok
	return ok


## The shared rule writes every reading / chrome / Manual colour, bar the ones that mean "clear".
static func _test_the_rule_dresses_every_derived_colour() -> bool:
	var probe: EventSheetEditorStyle = EventSheetEditorStyle.new()
	probe.ensure_defaults()
	for section: Resource in _derived_sections(probe):
		for token_name: String in _colour_tokens(section):
			section.set(token_name, SENTINEL)
	EventSheetThemeDerivation.fill_derived_tokens(probe)
	var undressed: Array[String] = []
	for section: Resource in _derived_sections(probe):
		for token_name: String in _colour_tokens(section):
			if section.get(token_name) == SENTINEL:
				undressed.append(token_name)
	return _check("the shared rule dresses every derived colour (undressed: %s)" % str(undressed),
		undressed, _as_string_array(CLEAR_BY_DESIGN))


## Every preset states, in its own file, every colour of the sheet and of both kinds of cell.
static func _test_every_preset_states_its_own_colours() -> bool:
	var ok: bool = true
	var wanted: Dictionary = {
		"event_sheet_event_style.gd": _colour_tokens(EventSheetEventStyle.new()),
		"event_sheet_element_style.gd": _colour_tokens(EventSheetElementStyle.new()),
	}
	for preset_path: String in PRESET_PATHS:
		var blocks: Array[Dictionary] = EventSheetThemePresets.stated_tokens(preset_path)
		var authored_blocks: int = 0
		var missing: Array[String] = []
		for block: Dictionary in blocks:
			var script_name: String = str(block.get("script"))
			if not wanted.has(script_name):
				continue
			authored_blocks += 1
			var stated: Array = block.get("tokens", [])
			for token_name: String in wanted[script_name]:
				if not stated.has(token_name):
					missing.append("%s.%s" % [script_name.trim_suffix(".gd"), token_name])
		# One sheet block and two cell blocks (conditions and actions), or the sweep above looked at
		# a preset that never wrote one of them and reported it clean.
		ok = _check("%s carries a sheet block and both cell blocks" % preset_path.get_file(),
			authored_blocks, 3) and ok
		ok = _check("%s states every colour it owns (missing: %s)" % [preset_path.get_file(), str(missing)],
			missing, [] as Array[String]) and ok
	return ok


## Every derived token of every preset is either stated by that preset or exactly what the rule
## derives for it. A token that is neither is one nobody chose.
static func _test_every_preset_is_current_with_the_rule() -> bool:
	var ok: bool = true
	for preset_path: String in PRESET_PATHS:
		var preset: EventSheetEditorStyle = load(preset_path) as EventSheetEditorStyle
		if preset == null:
			ok = _check("preset loads: %s" % preset_path.get_file(), false, true) and ok
			continue
		var stated: Dictionary = {}
		for block: Dictionary in EventSheetThemePresets.stated_tokens(preset_path):
			for token_name: String in block.get("tokens", []):
				stated["%s.%s" % [block.get("script"), token_name]] = true
		var derived: EventSheetEditorStyle = EventSheetThemeDerivation.fill_derived_tokens(preset.duplicate(true))
		var stale: Array[String] = []
		var derived_sections: Array[Resource] = _derived_sections(derived)
		var index: int = 0
		for section: Resource in _derived_sections(preset):
			var script_name: String = _script_file_name(section)
			for token_name: String in _colour_tokens(section):
				if stated.has("%s.%s" % [script_name, token_name]):
					continue
				if section.get(token_name) != derived_sections[index].get(token_name):
					stale.append(token_name)
			index += 1
		ok = _check("%s is current with the shared rule (stale: %s)" % [preset_path.get_file(), str(stale)],
			stale, [] as Array[String]) and ok
	return ok


## The three sub-styles the shared rule owns, in the order it fills them.
static func _derived_sections(style: EventSheetEditorStyle) -> Array[Resource]:
	return [style.get_reading_style(), style.get_chrome_style(), style.get_manual_style()]


## The colour tokens of a style resource, in declaration order. Sizes and ratios are left out on
## purpose: a row height or a corner radius carries no palette, so a preset that keeps the shipped
## one has made a choice rather than missed a token.
static func _colour_tokens(style_resource: Resource) -> Array[String]:
	var names: Array[String] = []
	for token: Dictionary in EventSheetThemeEditor.editable_tokens(style_resource):
		if int(token.get("type", TYPE_NIL)) == TYPE_COLOR:
			names.append(str(token.get("name")))
	return names


## The file name of the script behind a style resource, which is how a `.tres` names its blocks.
static func _script_file_name(style_resource: Resource) -> String:
	var script: Script = style_resource.get_script() as Script
	return script.resource_path.get_file() if script != null else ""


static func _as_string_array(values: Array) -> Array[String]:
	var typed: Array[String] = []
	for value: Variant in values:
		typed.append(str(value))
	return typed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] theme_presets_coverage_test: %s" % label)
		return true
	print("[FAIL] theme_presets_coverage_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
