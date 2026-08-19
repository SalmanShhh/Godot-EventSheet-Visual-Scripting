@tool
class_name EventSheetAccessibility
extends RefCounted

# Godot EventSheets - the reading, for readers who do not read it the same way.
#
# The whole premise of a sheet is that it READS. This file is where that promise is kept for the
# people the drawn canvas alone does not reach:
#
#   * every row's sentence is its accessible name, so a screen reader says what the row says, and
#     "Speak This Row" says it aloud on demand through the platform's own voice;
#   * Reduced Motion turns off every pulse and every fade in the editor - nothing is lost, it just
#     arrives at once. The operating system's own "reduce animation" preference is honoured too,
#     so a reader who already asked once never has to ask again here;
#   * Dyslexia-friendly text opens the letters up (extra space between glyphs and between words)
#     and can point the sheet at a font of the reader's choosing. NO font is bundled: shipping one
#     would put a typeface licence in everyone's project for a preference most readers do not
#     want, so the option uses the editor's own font by default and takes a path to any .ttf/.otf
#     the reader already has (OpenDyslexic and Atkinson Hyperlegible are the usual two);
#   * chips have a floor on their hit size, so a target is never smaller than a finger.
#
# Every preference is per-user editor metadata, like the other View toggles - a personal way of
# reading is not a fact about the project, and it never belongs in project.godot where it would
# arrive in someone else's checkout.
#
# Headless-safe throughout: with no display server every reader here answers false or "" rather
# than reaching for a singleton that is not there, so the suite pins the behaviour without a window.

const METADATA_SECTION := "eventsheets"
const REDUCED_MOTION_KEY := "reduced_motion"
const DYSLEXIA_TEXT_KEY := "dyslexia_friendly_text"
const READING_FONT_KEY := "reading_font_path"

## The smallest a chip may be drawn, in unscaled pixels. A chip is a target: a reader who cannot
## place a pointer precisely still has to be able to hit one.
const MIN_CHIP_HIT_WIDTH := 24.0
const MIN_CHIP_HIT_HEIGHT := 18.0

## How far apart dyslexia-friendly text sets the letters and the spaces, in unscaled pixels.
const DYSLEXIA_GLYPH_SPACING := 1
const DYSLEXIA_SPACE_SPACING := 3


## The preferences, read once and then remembered. `_get_font()` runs on every measurement and
## every repaint; asking the editor's settings store that often would cost more than the whole
## reading layer. Every setter below drops the cache, so the answers can never go stale.
static var _preferences: Dictionary = {}
## base font instance id -> the wrapped font built for it, so a repaint reuses one FontVariation
## instead of minting one per row per frame.
static var _font_cache: Dictionary = {}


## Forgets the remembered preferences. Called by every setter here; call it too if something else
## writes the same editor metadata.
static func invalidate() -> void:
	_preferences.clear()
	_font_cache.clear()


## True when the editor should not animate: either the reader asked here, or the operating system
## already carries the preference for them.
static func reduced_motion() -> bool:
	if _metadata(REDUCED_MOTION_KEY, false):
		return true
	if DisplayServer.get_name() == "headless":
		return false
	return DisplayServer.accessibility_should_reduce_animation()


static func set_reduced_motion(enabled: bool) -> void:
	_set_metadata(REDUCED_MOTION_KEY, enabled)


## True when the reader asked for open letters and generous word spacing.
static func dyslexia_friendly_text() -> bool:
	return _metadata(DYSLEXIA_TEXT_KEY, false)


static func set_dyslexia_friendly_text(enabled: bool) -> void:
	_set_metadata(DYSLEXIA_TEXT_KEY, enabled)


## The font file the reader pointed the sheet at, or "" for the editor's own.
static func reading_font_path() -> String:
	return str(_metadata(READING_FONT_KEY, ""))


static func set_reading_font_path(path: String) -> void:
	_set_metadata(READING_FONT_KEY, path.strip_edges())


## The font the sheet should draw its rows with, given the font it would otherwise use. Returns
## `base` unchanged when nothing was asked for, so the ordinary path costs nothing.
static func reading_font(base: Font) -> Font:
	var path: String = reading_font_path()
	var open_letters: bool = dyslexia_friendly_text()
	if path.is_empty() and not open_letters:
		return base
	var key: int = base.get_instance_id() if base != null else 0
	if _font_cache.has(key):
		return _font_cache[key] as Font
	var chosen: Font = base
	if not path.is_empty() and ResourceLoader.exists(path):
		var loaded: Font = ResourceLoader.load(path) as Font
		if loaded != null:
			chosen = loaded
	if open_letters and chosen != null:
		var variation: FontVariation = FontVariation.new()
		variation.base_font = chosen
		variation.set_spacing(TextServer.SPACING_GLYPH, DYSLEXIA_GLYPH_SPACING)
		variation.set_spacing(TextServer.SPACING_SPACE, DYSLEXIA_SPACE_SPACING)
		chosen = variation
	_font_cache[key] = chosen
	return chosen


## Says `text` aloud through the platform's own voice. Returns false when this machine has no
## speech to offer, so a caller can say so rather than looking like it did nothing.
static func speak(text: String) -> bool:
	var spoken: String = text.strip_edges()
	if spoken.is_empty() or DisplayServer.get_name() == "headless":
		return false
	var voices: PackedStringArray = DisplayServer.tts_get_voices_for_language(
		OS.get_locale_language())
	if voices.is_empty():
		var any_voice: Array = DisplayServer.tts_get_voices()
		if any_voice.is_empty():
			return false
		voices = PackedStringArray([str((any_voice[0] as Dictionary).get("id", ""))])
	DisplayServer.tts_stop()
	DisplayServer.tts_speak(spoken, voices[0])
	return true


## The height a chip is drawn at, never below the floor above.
static func chip_hit_size(width: float, height: float) -> Vector2:
	return Vector2(maxf(width, MIN_CHIP_HIT_WIDTH), maxf(height, MIN_CHIP_HIT_HEIGHT))


static func _metadata(key: String, fallback: Variant) -> Variant:
	if _preferences.has(key):
		return _preferences[key]
	var value: Variant = fallback
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		value = EditorInterface.get_editor_settings().get_project_metadata(METADATA_SECTION, key, fallback)
	_preferences[key] = value
	return value


static func _set_metadata(key: String, value: Variant) -> void:
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		EditorInterface.get_editor_settings().set_project_metadata(METADATA_SECTION, key, value)
	invalidate()
	_preferences[key] = value
