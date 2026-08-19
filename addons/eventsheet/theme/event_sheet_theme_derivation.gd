@tool
class_name EventSheetThemeDerivation
extends RefCounted

## Fills a theme's READING, CHROME and MANUAL tokens from the tokens it already has.
##
## A preset is written by hand (or generated from a well-known palette) against the tokens that
## existed the day it was written. When a new family of tokens ships, every older preset would keep
## the plugin's own dark defaults for them - which is exactly wrong on a pale theme, where a dark
## chip and a near-black stripe sit on white paper and look broken.
##
## So: one rule, applied to every preset. Read the theme's own background, text, lane and accent
## tokens, and derive the new ones from those. A preset with a real opinion can still overwrite any
## of them afterwards; this only decides what "no opinion" looks like, and it decides it in the
## preset's own colours instead of in EventForge's.
##
## Used by the bundled-preset builder, by the Godot-adaptive default, and by the one-shot backfill
## that brought the hand-written presets forward.


## Derives every reading / chrome / Manual token from the style's own existing tokens. Returns the
## same style, so callers can chain. Safe to run twice: the derivation is a pure function of the
## tokens it reads, none of which it writes.
static func fill_derived_tokens(style: EventSheetEditorStyle) -> EventSheetEditorStyle:
	if style == null:
		return style
	var event_style: EventSheetEventStyle = style.get_event_style()
	var reading: EventSheetReadingStyle = style.get_reading_style()
	var chrome: EventSheetChromeStyle = style.get_chrome_style()
	var manual: EventSheetManualStyle = style.get_manual_style()
	var background: Color = event_style.row_background_color
	var pale: bool = background.get_luminance() > 0.5
	var accent: Color = event_style.group_accent_color
	var surface: Color = event_style.group_fold_background_color
	var ink: Color = _ink_for(background)

	# ── Chips and badges: a plate lifted off the background, with the theme's own ink on it ──
	reading.plain_chip_background_color = background.lerp(ink, 0.12)
	reading.plain_chip_foreground_color = background.lerp(ink, 0.65)
	reading.category_chip_background_color = background.lerp(accent, 0.28)
	reading.category_chip_foreground_color = background.lerp(accent, 0.85)
	reading.inspector_chip_background_color = background.lerp(event_style.column_header_conditions_color, 0.45)
	reading.inspector_chip_foreground_color = background.lerp(event_style.column_header_conditions_color, 0.95)
	reading.constant_badge_background_color = background.lerp(event_style.column_header_actions_color, 0.30)
	reading.constant_badge_foreground_color = background.lerp(event_style.column_header_actions_color, 0.92)
	reading.setup_badge_background_color = background.lerp(ink, 0.08)
	reading.setup_badge_foreground_color = background.lerp(ink, 0.45)
	reading.code_badge_background_color = background.lerp(ink, 0.10)
	reading.code_badge_foreground_color = background.lerp(ink, 0.55)
	reading.lift_note_badge_background_color = background.lerp(event_style.comment_row_background_color, 0.85)
	reading.lift_note_badge_foreground_color = _warning_for(background)
	reading.or_badge_background_color = background.lerp(ink, 0.18)
	reading.or_badge_foreground_color = background.lerp(ink, 0.75)

	# ── How often an event runs: the theme's own warm / cool / accent, filled ──
	reading.tempo_every_tick_background_color = _warning_for(background).darkened(0.25 if not pale else 0.05)
	reading.tempo_every_tick_foreground_color = _on_fill(reading.tempo_every_tick_background_color)
	reading.tempo_input_background_color = event_style.column_header_conditions_color.darkened(0.25)
	reading.tempo_input_foreground_color = _on_fill(reading.tempo_input_background_color)
	reading.tempo_once_background_color = accent.darkened(0.25)
	reading.tempo_once_foreground_color = _on_fill(reading.tempo_once_background_color)

	# ── Text tones: the theme's body ink, stepped down twice ──
	reading.primary_text_color = background.lerp(ink, 0.92)
	reading.secondary_text_color = background.lerp(ink, 0.68)
	reading.muted_text_color = background.lerp(ink, 0.48)
	reading.string_value_color = event_style.column_header_conditions_color
	reading.boolean_value_color = background.lerp(accent, 0.85)

	# ── Flags and stripes: red means broken in every palette, so it is TUNED, not replaced ──
	var flag_red: Color = _error_for(background)
	reading.error_text_color = flag_red
	reading.error_stripe_color = flag_red
	reading.firing_stripe_color = event_style.column_header_conditions_color.lightened(0.15 if not pale else 0.0)
	reading.disabled_row_color = Color(ink.r, ink.g, ink.b, 0.35)
	reading.breakpoint_color = flag_red
	reading.runtime_error_color = _warning_for(background).lerp(flag_red, 0.5)
	reading.debugger_accent_color = reading.firing_stripe_color
	reading.bookmark_color = _warning_for(background)
	reading.event_number_rail_color = event_style.row_border_color

	# ── Guides and gestures ──
	reading.indent_guide_color = Color(ink.r, ink.g, ink.b, 0.08)
	reading.tree_guide_color = Color(ink.r, ink.g, ink.b, 0.20)
	reading.drag_line_color = Color(accent.r, accent.g, accent.b, 0.95)
	reading.drag_refusal_color = flag_red
	reading.drag_bubble_refused_background_color = background.lerp(flag_red, 0.45)
	reading.drag_bubble_background_color = background.lerp(surface, 0.85)
	reading.drag_bubble_text_color = background.lerp(ink, 0.96)
	reading.color_swatch_border_color = Color(ink.r, ink.g, ink.b, 0.55)
	reading.text_selection_color = Color(accent.r, accent.g, accent.b, 0.30)
	reading.default_chip_plate_color = Color(ink.r, ink.g, ink.b, 0.035)

	# ── The bars around the sheet ──
	chrome.object_bar_section_color = reading.muted_text_color
	chrome.object_bar_warning_color = _warning_for(background)
	chrome.object_bar_hover_wash_color = Color(ink.r, ink.g, ink.b, 0.07)
	chrome.object_bar_grip_color = Color(ink.r, ink.g, ink.b, 0.28)
	chrome.object_bar_grip_active_color = Color(ink.r, ink.g, ink.b, 0.62)
	chrome.project_bar_heading_color = reading.muted_text_color
	chrome.project_bar_note_color = reading.muted_text_color
	chrome.status_text_color = reading.primary_text_color
	chrome.status_error_color = flag_red
	chrome.row_address_color = Color(ink.r, ink.g, ink.b, 0.65)
	chrome.unsaved_dot_color = _warning_for(background)
	chrome.title_path_color = reading.secondary_text_color

	# ── The minimap: the sheet's own tints, one per kind of event, over a sunken column ──
	chrome.minimap_background_color = Color(ink.r, ink.g, ink.b, 0.16 if pale else 0.10)
	chrome.minimap_window_color = Color(ink.r, ink.g, ink.b, 0.10)
	chrome.minimap_window_border_color = Color(accent.r, accent.g, accent.b, 0.75)
	chrome.minimap_trigger_color = _warning_for(background)
	chrome.minimap_tick_color = event_style.column_header_conditions_color
	chrome.minimap_function_color = event_style.column_header_actions_color
	chrome.minimap_group_color = accent
	chrome.minimap_comment_color = event_style.comment_row_background_color.lerp(ink, 0.35)
	chrome.minimap_script_color = background.lerp(ink, 0.55)
	chrome.minimap_event_color = Color(ink.r, ink.g, ink.b, 0.42)
	chrome.minimap_disabled_color = Color(ink.r, ink.g, ink.b, 0.16)
	chrome.minimap_bookmark_color = reading.bookmark_color
	chrome.minimap_finding_color = flag_red
	chrome.minimap_band_color = Color(ink.r, ink.g, ink.b, 0.05)
	chrome.minimap_band_text_color = Color(ink.r, ink.g, ink.b, 0.55)

	# ── The Manual: headings and quiet words follow the theme; the rest keeps no opinion, so a
	# reader who never opens the Theme Editor still gets help that matches their editor ──
	manual.heading_color = reading.primary_text_color
	manual.page_muted_text_color = reading.muted_text_color
	manual.table_hairline_color = Color(ink.r, ink.g, ink.b, 0.16)
	manual.note_color = _warning_for(background)
	return style


## The ink a background wants: near-white on a dark theme, near-black on a pale one. Every
## alpha-over-background token above mixes toward this, so one rule covers both kinds of theme.
static func _ink_for(background: Color) -> Color:
	return Color(0.08, 0.09, 0.11) if background.get_luminance() > 0.5 else Color(0.95, 0.96, 0.98)


## "Look at this" in a palette that has to hold on both papers - amber, darkened on a pale theme so
## it does not disappear into the page.
static func _warning_for(background: Color) -> Color:
	var amber := Color("#e8bd73")
	return amber.darkened(0.35) if background.get_luminance() > 0.5 else amber


## "This is broken" - red, held to the same rule.
static func _error_for(background: Color) -> Color:
	var red := Color("#ff5555")
	return red.darkened(0.30) if background.get_luminance() > 0.5 else red


## The text a filled badge wears: whichever of near-white / near-black reads on that fill.
static func _on_fill(fill: Color) -> Color:
	return Color(0.08, 0.09, 0.11) if fill.get_luminance() > 0.45 else Color(0.97, 0.97, 0.99)
