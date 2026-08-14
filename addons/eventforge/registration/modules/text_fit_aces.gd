# EventForge module - the drawn side of text: direction, glyph coverage, and fit in PIXELS.
#
# text_format_aces owns what a string SAYS (shortening by characters, columns, translated patterns).
# This module owns what happens when it is drawn: which way it reads, whether the font even has the
# characters, and whether it physically fits the control it was put in. All three are localisation
# failures that look perfect in English and only appear in someone else's language.
#
#  - DIRECTION: one row on the UI root takes the layout direction from the game's language, so
#    containers, anchors and margins mirror for Arabic or Hebrew. Two conditions read it back: one
#    asks the LANGUAGE, one asks a CONTROL, so a hand-placed offset or a slide-in tween flips with it.
#  - GLYPHS: a font's `fallbacks` chain draws whatever the main face has no glyph for, which is the
#    difference between a Japanese build and a wall of empty boxes. Add Font Fallback is idempotent,
#    so it is safe under On Language Changed and on every scene load. Font Can Show answers, at author
#    time, the question nobody on an English-speaking team can answer by looking at the screen.
#  - FIT: Shorten To Fit counts CHARACTERS, which is the wrong unit the moment the font is
#    proportional or the language is German. These four measure the real thing through Godot's own
#    Font.get_string_size. They are not translation-only: a player-typed name, a big number and an
#    item title from a data asset are the same problem, so they pay for themselves in projects that
#    never localise at all.
#
# Verified against Godot 4.7 rather than assumed, because every verb here rests on engine behaviour:
#   * Control.LAYOUT_DIRECTION_APPLICATION_LOCALE is 1 (LAYOUT_DIRECTION_LOCALE is the same value, an
#     older alias). is_locale_right_to_left("ar"/"he"/"fa") is true, "en" is false.
#   * A control's layout_direction starts at LAYOUT_DIRECTION_INHERITED, and a project whose root
#     direction is left on "based on application locale" (the default) already mirrors an untouched
#     control in Arabic. The row earns its keep where something PINNED a direction - that control, or
#     an ancestor - because a pinned control stays left-to-right in Arabic until the row hands it back
#     to the language (checked both ways).
#   * is_layout_rtl() CACHES its answer and re-computes it when the control is told the translation
#     changed - which the engine does for every Control in the tree on a live locale switch (checked
#     with a real main loop: ar -> true, back to en -> false). A Control outside the tree keeps its
#     cached answer, which is why this cannot be checked in a treeless test by flipping the locale
#     under one long-lived Control.
#   * Font.has_char and get_string_size BOTH walk the fallback chain (checked: the bundled default
#     font has no glyph for U+3042, and gains one the moment a font that does is appended to
#     `fallbacks`). So Font Can Show is exactly the "did my Add Font Fallback row work" check.
#   * get_string_size measures in pixels at the font size you pass, with no editor scaling involved:
#     "START GAME" is 98 px and its German "SPIEL STARTEN" is 115 px in the default font at 16, which
#     is the entire reason this module exists.
#   * A Control's `text` is NOT what it draws: the engine auto-translates it at display time, so a
#     Label still holding "START GAME" draws its German translation and measures 160 px while `text`
#     measures 98. Node.atr() is the same lookup the engine does, so every measurement of a control's
#     own text goes through it - measuring `text` would answer about English on every screen.
#   * `size` is clamped up to a Control's combined minimum size, and a Label's minimum size includes
#     its text unless it clips: a Label given size.x = 120 for a 160 px string reports 160 back, and
#     reports 120 once clip_text is on. So an overflow answer is only meaningful on a control that
#     cannot grow - which is exactly the control that clips, i.e. the bug being hunted.
#
# Every template is plain GDScript over native calls: no plugin runtime, no helper library.
# ace_ids and codegen_templates are a compatibility covenant: frozen once shipped (deprecate, never rename).
@tool
class_name EventForgeTextFitACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")
const CAT_TEXT := "Text"
const CAT_UI := "UI"
const CAT_TRANSLATION := "Translation"

## Measuring one line of text with a font: the shape every fitting verb here uses. Godot's own
## Font.get_string_size, with -1.0 meaning "do not wrap" so the answer is the width of ONE line.
const _MEASURE := "%s.get_string_size(%s, HORIZONTAL_ALIGNMENT_LEFT, -1.0, %s).x"

## How a Control names the font and size it draws with. Label, Button, LineEdit and TextEdit all
## answer to "font"; a control that has no such theme item answers with the engine's default font
## instead of failing, so a measurement always returns something honest.
const _CONTROL_FONT := "{target.}get_theme_font(&\"font\")"
const _CONTROL_FONT_SIZE := "{target.}get_theme_font_size(&\"font_size\")"

## What the control actually DRAWS, which is not what `text` holds. A Control auto-translates its
## own text at display time, so a Label whose text is still "START GAME" draws "SPIEL STARTEN JETZT"
## under a German locale (checked on 4.7 in a real tree: text is 98 px, atr(text) is 160 px).
## Measuring `text` therefore answers about English on every screen - the exact bug these verbs
## exist to catch - so every measurement of a control's own text goes through Node.atr first.
const _CONTROL_TEXT := "{target.}atr(str({target.}text))"

## Where Fit Text To Label parks the string it was given, so the cut is never one-way: the row can
## run again after a language switch and re-fit from the source instead of re-cutting its own
## leftovers. A plain meta name, readable in the remote inspector and settable by hand.
const _FIT_SOURCE_META := "&\"fit_source_text\""


static func get_descriptors() -> Array[ACEDescriptor]:
	var d: Array[ACEDescriptor] = []

	# ── Direction: right-to-left languages ──
	d.append(F.make_descriptor("Core", "LanguageIsRightToLeft", "Language Reads Right To Left", ACEDescriptor.ACEType.CONDITION,
		"TextServerManager.get_primary_interface().is_locale_right_to_left(TranslationServer.get_locale())", "", [],
		CAT_TRANSLATION, "language reads right to left")
		.described("True while the game is running in a right-to-left language: Arabic, Hebrew, Persian, Urdu. The engine answers, so a language you add later is covered without editing a list of codes."))

	d.append(F.make_descriptor("Core", "MirrorLayoutForLanguage", "Mirror Layout For Language", ACEDescriptor.ACEType.ACTION,
		"layout_direction = Control.LAYOUT_DIRECTION_APPLICATION_LOCALE", "", [],
		CAT_TRANSLATION, "mirror layout for the language", "Control")
		.described("Makes this control - and everything under it - lay itself out from the game's language: containers, anchors and margins mirror for a right-to-left language, and flip back the moment the language changes again. One row on your UI root usually covers the whole game."))

	d.append(F.make_descriptor("Core", "LayoutIsMirrored", "Layout Is Mirrored", ACEDescriptor.ACEType.CONDITION,
		"is_layout_rtl()", "", [],
		CAT_TRANSLATION, "layout is mirrored", "Control")
		.described("True when this control is currently laid out right to left. Ask it before a hand-placed offset or a slide-in tween, so the panel still enters from the side the player reads towards. Godot mirrors containers and anchors for you; this is for the positions you set yourself."))

	# ── Glyphs: the font that draws what yours cannot ──
	# Idempotent on purpose (the Rename Field shape): safe under On Language Changed and safe on every
	# scene load. `fallbacks` must be ASSIGNED back - appending to the value you read does not tell the
	# font to rebuild the chain it draws with. The null guard is what makes the row inert until a font
	# is really named: a default naming a file that only exists in someone else's project would push a
	# load error and append a null into the chain the moment the row is dropped.
	d.append(F.make_descriptor("Core", "AddFontFallback", "Add Font Fallback", ACEDescriptor.ACEType.ACTION,
		"if {fallback} != null and not {font}.fallbacks.has({fallback}):\n\t{font}.fallbacks = {font}.fallbacks + [{fallback}]", "",
		[
			F.make_param("font", "Font", "ThemeDB.fallback_font", "Font", "The font your UI actually draws with. ThemeDB.fallback_font is the engine default every unstyled control uses; for one control's own font, use the Font Of This Control expression.", "expression", [], _font_suggestions()),
			F.make_param("fallback", "Font", "null", "Falls back to", "The font that draws whatever the first one has no glyph for - a CJK face, a Cyrillic face, an emoji face. Point it at a font file you shipped: load(\"res://fonts/your_fallback.ttf\"). Use something that resolves to the SAME resource every run - load(\"res://...\") does, while SystemFont.new() builds a new one each time and would stack up. Left empty the row does nothing.", "expression", [], _font_suggestions()),
		], CAT_UI, "give [i]{font}[/i] the fallback [i]{fallback}[/i]")
		.described("Any character the main font cannot draw is drawn by this one instead, so a Japanese, Russian or emoji-carrying build stops rendering empty boxes while your Latin text keeps the face you chose. Adding the same fallback twice does nothing, so this is safe to run on every load and after every language change.")
		.featured())

	d.append(F.make_descriptor("Core", "UseFont", "Use Font", ACEDescriptor.ACEType.ACTION,
		"add_theme_font_override({slot}, {font})", "",
		[
			F.make_param("font", "Font", "ThemeDB.fallback_font", "Font", "The font to draw this control's text with - usually load(\"res://fonts/your_font.ttf\").", "expression", [], _font_suggestions()),
			_slot_param(),
		], CAT_UI, "draw this control with [i]{font}[/i]", "Control")
		.described("Gives ONE control its own font, without a theme resource: a per-language display face, a monospace font so the column verbs line up, a bigger face for a heading. Run it again with another font and the new one wins."))

	d.append(F.make_descriptor("Core", "ControlFont", "Font Of This Control", ACEDescriptor.ACEType.EXPRESSION,
		"get_theme_font(&\"font\")", "", [],
		CAT_UI, "this control's font", "Control")
		.described("The font this control is actually drawing with right now, whether that came from a theme, a Use Font row or the engine default. Feed it to Font Can Show or Add Font Fallback so those rows are about the real font on screen instead of one you named twice."))

	d.append(F.make_descriptor("Core", "FontCanShow", "Font Can Show", ACEDescriptor.ACEType.CONDITION,
		"({text}.is_empty() or Array(range({text}.length())).all(func(__i): return {font}.has_char({text}.unicode_at(__i))))", "",
		[
			F.make_param("font", "Font", "ThemeDB.fallback_font", "Font", "The font to test. Use the Font Of This Control expression to test the one a label really draws with.", "expression", [], _font_suggestions()),
			F.make_param("text", "String", "tr(\"MENU_START\")", "Can show", "The text it has to draw. Feed it a TRANSLATED string - the source English always fits, which is exactly why nobody catches this.", "expression"),
		], CAT_UI, "[i]{font}[/i] can show [b]{text}[/b]")
		.described("True when the font has a glyph for every character in the text, empty text included. It follows the fallback chain, so a font that has been given a CJK fallback answers true for Japanese. Invert it (right-click the row) and log the failure, and \"we found out from a store review\" becomes something you see while authoring."))

	# ── Fit: overflow measured in pixels, not characters ──
	d.append(F.make_descriptor("Core", "TextOverflows", "Text Overflows", ACEDescriptor.ACEType.CONDITION,
		"%s > {target.}size.x" % (_MEASURE % [_CONTROL_FONT, _CONTROL_TEXT, _CONTROL_FONT_SIZE]), "",
		[_on_node_param()], CAT_TEXT, "text overflows this control", "Control")
		.described("True when the text is wider than the control showing it - the clipped-button bug, answered in pixels with the control's real font instead of a character count. It measures what the control DRAWS, so a label still holding its English source string is measured in the language on screen. This is about controls that cannot grow: a Label or Button free to widen is grown by the engine to fit its text and honestly answers false, so turn on Clip Text (or a Text Overrun Behavior, or put it in a fixed-size container) for the answer to mean anything. It measures ONE line, so for a label that wraps, compare Wrapped Text Height against the box height instead."))

	d.append(F.make_descriptor("Core", "FitTextToLabel", "Fit Text To Label", ACEDescriptor.ACEType.ACTION,
		_fit_template(), "",
		[
			F.make_param("suffix", "String", "\"...\"", "Ending", "What marks the cut, e.g. \"...\". Its own width comes out of the budget. An empty ending simply trims.", "expression"),
			_on_node_param(),
		], CAT_TEXT, "fit this control's text, ending [b]{suffix}[/b]", "Control")
		.described("Backs this control's text up until it MEASURES inside the control, and marks the cut. Whole words first (the Shorten To Whole Words rule), falling back to cutting mid-word when one long word is all there is, and cutting with no marker at all when the control is too narrow to hold even the ending - so the result is never just the ending and never wider than the control. It cuts the TRANSLATED line, and remembers the string it was given in the node's \"fit_source_text\" meta, so running it again after a language switch re-fits the whole sentence instead of trimming its own leftovers - and a line that now fits is put back in full, still translating itself. Needs a control that cannot grow (Clip Text, a Text Overrun Behavior, or a fixed-size container); one free to widen never overflows in the first place."))

	d.append(F.make_descriptor("Core", "TextFitsInWidth", "Text Fits In Width", ACEDescriptor.ACEType.CONDITION,
		"%s <= float({width})" % (_MEASURE % ["{font}", "{text}", "{font_size}"]), "",
		[
			F.make_param("text", "String", "tr(\"START GAME\")", "Text", "The text to measure. Feed it a TRANSLATED string, so the answer is about the language the player will see.", "expression"),
			F.make_param("width", "String", "180", "Width", "The room it has, in pixels.", "expression"),
			_font_param(),
			_font_size_param(),
		], CAT_TEXT, "[b]{text}[/b] fits in [b]{width}[/b] px")
		.described("True when the text would draw no wider than that many pixels - the check for a control you are about to fill or size, before it exists on screen. Invert it and widen the button, or pick a shorter key. The width is in pixels, so it survives the proportional font and the long language that a character count does not."))

	d.append(F.make_descriptor("Core", "WrappedTextHeight", "Wrapped Text Height", ACEDescriptor.ACEType.EXPRESSION,
		"{font}.get_multiline_string_size({text}, HORIZONTAL_ALIGNMENT_LEFT, float({width}), {font_size}).y", "",
		[
			F.make_param("text", "String", "tr(\"DIALOGUE_LINE\")", "Text", "The text that has to fit in the box. Feed it a TRANSLATED string.", "expression"),
			F.make_param("width", "String", "220", "Wrapped into", "The box width in pixels that the text wraps inside.", "expression"),
			_font_param(),
			_font_size_param(),
		], CAT_TEXT, "height of [b]{text}[/b] wrapped into [b]{width}[/b] px")
		.described("How TALL the text becomes once it wraps into a box that wide, in pixels. The answer for a dialogue box or a quest log: compare it with the box height and grow the panel, shrink the font or split the line before the last sentence disappears off the bottom in the one language nobody on the team reads."))

	return d


## The text-fitting action, one emitted line per array entry.
##
## Pixels, not characters, and it mirrors the character-count family's documented edge rules rather
## than inventing new ones (two families that disagree about the same string is worse than one that
## is only approximate):
##   - text that already fits is not touched at all;
##   - the ending's own width comes out of the budget;
##   - a control too narrow to hold the ending hard-cuts with NO ending, so the result can never be
##     wider than the control and can never be the ending on its own - including the case where the
##     ending DOES fit but no glyph of the text does after it (a 64 px heading in a 60 px slot),
##     which is why the mark is dropped again when nothing survived the trim;
##   - the character cut backs up to the last whole word, unless that would leave nothing (one very
##     long word, or a cut whose only space is its first character), in which case the mid-word cut
##     stands.
##
## THE CUT IS NOT ONE-WAY, which is the difference between a fitting row and a row that destroys a
## label. A Control re-translates the string its `text` still HOLDS, so writing a cut translation
## into `text` would freeze the label in that language forever (checked on 4.7: after text is
## replaced with the German cut, switching back to English leaves the German cut on screen). So the
## string this row was handed is parked in a meta the first time, and every run starts from THERE:
## re-run it under On Language Changed and the label re-fits the new language, and a line that now
## fits is written back as the source string - which auto-translates again like an untouched label.
## Locals carry {uid} because the compiler emits this INTO the sheet class, once per applied row.
static func _fit_template() -> String:
	var lines: PackedStringArray = PackedStringArray([
		"if not {target.}has_meta(%s):" % _FIT_SOURCE_META,
		"\t{target.}set_meta(%s, str({target.}text))" % _FIT_SOURCE_META,
		"{target.}text = str({target.}get_meta(%s))" % _FIT_SOURCE_META,
		"var __fit_font_{uid}: Font = %s" % _CONTROL_FONT,
		"var __fit_px_{uid}: int = %s" % _CONTROL_FONT_SIZE,
		"var __fit_room_{uid}: float = {target.}size.x",
		"var __fit_cut_{uid}: String = %s" % _CONTROL_TEXT,
		"if %s > __fit_room_{uid}:" % (_MEASURE % ["__fit_font_{uid}", "__fit_cut_{uid}", "__fit_px_{uid}"]),
		"\tvar __fit_mark_{uid}: String = {suffix}",
		"\tvar __fit_budget_{uid}: float = __fit_room_{uid} - %s" % (_MEASURE % ["__fit_font_{uid}", "__fit_mark_{uid}", "__fit_px_{uid}"]),
		"\tif __fit_budget_{uid} <= 0.0:",
		"\t\t__fit_budget_{uid} = __fit_room_{uid}",
		"\t\t__fit_mark_{uid} = \"\"",
		"\twhile not __fit_cut_{uid}.is_empty() and %s > __fit_budget_{uid}:" % (_MEASURE % ["__fit_font_{uid}", "__fit_cut_{uid}", "__fit_px_{uid}"]),
		"\t\t__fit_cut_{uid} = __fit_cut_{uid}.left(__fit_cut_{uid}.length() - 1)",
		"\tvar __fit_word_{uid}: String = __fit_cut_{uid}.rsplit(\" \", true, 1)[0].strip_edges()",
		"\tif not __fit_word_{uid}.is_empty() and not __fit_cut_{uid}.ends_with(\" \"):",
		"\t\t__fit_cut_{uid} = __fit_word_{uid}",
		"\tif __fit_cut_{uid}.strip_edges().is_empty():",
		"\t\t__fit_mark_{uid} = \"\"",
		"\t{target.}text = __fit_cut_{uid}.strip_edges() + __fit_mark_{uid}",
	])
	return "\n".join(lines)


## The "On node" target, written out by hand instead of taking the one registration appends to a
## node-scoped ACE. That transform prefixes each LINE once, which is correct for a one-member call
## and quietly wrong here: these templates touch `text`, `size` and `get_theme_font` in the same
## line, and only the first would have been retargeted. Owning a param called "target" is also what
## tells registration to leave the template alone (builtin_aces.gd), so the two halves agree.
static func _on_node_param() -> ACEParam:
	return F.make_param("target", "String", "", "On node", "Act on another node instead of this one. Leave blank for this node, pick a node, or address one without a tree path - e.g. get_tree().get_first_node_in_group(\"player\").", "expression")


## The font a measurement is taken with, for the verbs that are not attached to a control.
static func _font_param() -> ACEParam:
	return F.make_param("font", "Font", "ThemeDB.fallback_font", "Measured in", "The font the text will be drawn with. ThemeDB.fallback_font is the engine default every unstyled control uses; for a control that has its own, use the Font Of This Control expression.", "expression", [], _font_suggestions())


## The size that font is measured at. Pixels, and the same number the control's theme uses.
static func _font_size_param() -> ACEParam:
	return F.make_param("font_size", "String", "16", "At size", "Font size in pixels, matching the size the control draws at.", "expression")


## Which theme font slot Use Font overrides. Most controls draw with "font"; RichTextLabel keeps four
## separate faces and ignores "font" entirely, which is why this is a list rather than an assumption.
static func _slot_param() -> ACEParam:
	return F.make_param("slot", "String", "&\"font\"", "Slot", "Which font this control draws with. Everything but RichTextLabel uses the main one.", "", [
		{"key": "&\"font\"", "label": "Main font"},
		{"key": "&\"normal_font\"", "label": "Rich text: normal"},
		{"key": "&\"bold_font\"", "label": "Rich text: bold"},
		{"key": "&\"italic_font\"", "label": "Rich text: italic"},
		{"key": "&\"mono_font\"", "label": "Rich text: monospace"},
	])


## Ways of naming a font that actually resolve, offered as suggestions rather than a fixed list so a
## project constant or a preloaded resource can still be typed in.
static func _font_suggestions() -> Array[String]:
	return ["ThemeDB.fallback_font", "load(\"res://fonts/your_fallback.ttf\")", "SystemFont.new()"]
