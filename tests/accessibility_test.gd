# Godot EventSheets - the reading, for readers who do not read it the same way.
#
# Three promises, pinned as values: a chip is never smaller than a target, the High Contrast preset
# has an opinion about EVERY theme token (the one preset a reader might actually depend on to see
# the sheet at all, so a new token silently keeping the plugin's own dark default is a regression),
# and the preferences answer sensibly with no display server behind them.
@tool
class_name AccessibilityTest
extends RefCounted

## The preset the sweep is about. High Contrast is not a taste, it is a way of seeing.
const HIGH_CONTRAST_PATH := "res://demo/themes/high_contrast_theme.tres"


static func run() -> bool:
	var ok: bool = true
	ok = _test_hit_size() and ok
	ok = _test_high_contrast_covers_every_token() and ok
	ok = _test_preferences_headless() and ok
	return ok


static func _test_hit_size() -> bool:
	var ok: bool = true
	ok = _check("a chip narrower than a target is caught in a target-sized rectangle",
		ViewportHitTestHelper.hit_rect(Rect2(100.0, 50.0, 8.0, 12.0)),
		Rect2(92.0, 47.0, 24.0, 18.0)) and ok
	ok = _check("a chip already big enough is left exactly as it is",
		ViewportHitTestHelper.hit_rect(Rect2(100.0, 50.0, 90.0, 22.0)),
		Rect2(100.0, 50.0, 90.0, 22.0)) and ok
	ok = _check("the floor is stated once and read from there",
		EventSheetAccessibility.chip_hit_size(8.0, 12.0), Vector2(24.0, 18.0)) and ok
	return ok


static func _test_high_contrast_covers_every_token() -> bool:
	var ok: bool = true
	var preset: EventSheetEditorStyle = load(HIGH_CONTRAST_PATH) as EventSheetEditorStyle
	ok = _check("the High Contrast preset loads", preset != null, true) and ok
	if preset == null:
		return ok
	var source: String = FileAccess.get_file_as_string(HIGH_CONTRAST_PATH)
	var missing: Array[String] = []
	for section: Resource in [preset, preset.get_event_style(), preset.get_condition_style(),
			preset.get_action_style(), preset.get_reading_style(), preset.get_chrome_style(),
			preset.get_manual_style()]:
		if section == null:
			continue
		for token: Dictionary in EventSheetThemeEditor.editable_tokens(section):
			var token_name: String = str(token.get("name"))
			# A .tres omits a property it never set, so the FILE - not the loaded resource - is
			# what proves the preset had an opinion. A token that is absent here is a token the
			# reader gets in EventForge's own dark, on a theme they chose to be able to see at all.
			if not source.contains("%s = " % token_name):
				missing.append(token_name)
	ok = _check("High Contrast has a value for every theme token (missing: %s)" % str(missing),
		missing, [] as Array[String]) and ok
	return ok


static func _test_preferences_headless() -> bool:
	var ok: bool = true
	EventSheetAccessibility.invalidate()
	ok = _check("with no editor behind it, reduced motion is off",
		EventSheetAccessibility.reduced_motion(), false) and ok
	ok = _check("and so is dyslexia-friendly text",
		EventSheetAccessibility.dyslexia_friendly_text(), false) and ok
	ok = _check("no font was asked for, so no font is substituted",
		EventSheetAccessibility.reading_font(ThemeDB.fallback_font), ThemeDB.fallback_font) and ok
	# The setter is honoured in-session even with nowhere to persist it, so a toggle takes effect
	# the moment it is pressed rather than only after a restart.
	EventSheetAccessibility.set_dyslexia_friendly_text(true)
	ok = _check("asking for open letters takes effect at once",
		EventSheetAccessibility.dyslexia_friendly_text(), true) and ok
	var opened: Font = EventSheetAccessibility.reading_font(ThemeDB.fallback_font)
	ok = _check("the sheet's font becomes a spaced-out version of the same font",
		opened is FontVariation, true) and ok
	if opened is FontVariation:
		ok = _check("the letters are set apart",
			(opened as FontVariation).get_spacing(TextServer.SPACING_GLYPH),
			EventSheetAccessibility.DYSLEXIA_GLYPH_SPACING) and ok
		ok = _check("and so are the words",
			(opened as FontVariation).get_spacing(TextServer.SPACING_SPACE),
			EventSheetAccessibility.DYSLEXIA_SPACE_SPACING) and ok
	ok = _check("the same font comes back rather than a new one each repaint",
		EventSheetAccessibility.reading_font(ThemeDB.fallback_font), opened) and ok
	EventSheetAccessibility.set_dyslexia_friendly_text(false)
	EventSheetAccessibility.invalidate()
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] accessibility_test: %s" % label)
		return true
	print("[FAIL] accessibility_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
