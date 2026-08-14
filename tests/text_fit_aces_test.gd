# Godot EventSheets - the direction / font / fit vocabulary (text_fit_aces.gd).
#
# Eleven verbs that all rest on ENGINE behaviour rather than on string handling, so an emission pin
# alone would prove nothing: a template can name a real method, substitute cleanly, parse, and still
# answer the wrong question. Every verb here is therefore pinned as SHIPPED GDScript and then RUN -
# against a real Control, a real font and real pixel measurements - on the edge case it exists for:
#
#   * a locale that reads right to left, and one that does not;
#   * a font that has no glyph for a character, and the same font after a fallback is added;
#   * the same fallback added twice (the row is meant to be safe under On Language Changed);
#   * an English string that fits a button and its German translation that does not;
#   * a control too narrow to hold even the ending, where marking the cut is impossible.
#
# Two engine facts this test is shaped around, both checked rather than assumed:
#   1. Control.is_layout_rtl() CACHES. The cache is refreshed when the control is told the
#      translation changed, which the engine does for every Control IN THE TREE on a live locale
#      switch. A headless test has no main loop and no tree, so flipping the locale under one
#      long-lived Control would silently keep the old answer. Each direction case therefore builds a
#      FRESH Control after the locale is set.
#   2. Font.has_char and Font.get_string_size both walk the `fallbacks` chain, which is what makes
#      Font Can Show a real answer to "did my Add Font Fallback row work".
#
# The fallback font is built here rather than shipped as an asset: a bitmap FontFile carrying exactly
# one glyph (U+3042, Japanese HIRAGANA A) - a character the engine's bundled default font has no
# glyph for, which is the whole failure mode suggestion 09 exists for.
@tool
class_name TextFitACEsTest
extends RefCounted

## U+3042 HIRAGANA A: present in the built fallback font, absent from the bundled default font.
const CJK_CHAR_CODE := 0x3042

## The English string and its German translation, in the default font at size 16: 98 px against
## 115 px. A 100 px button fits one and clips the other, which is the bug this whole group is about.
const ENGLISH := "START GAME"
const GERMAN := "SPIEL STARTEN"


static func run() -> bool:
	var restore_locale: String = TranslationServer.get_locale()
	var passed: bool = true
	passed = _test_registry_pins_shipped_templates() and passed
	passed = _test_language_direction_runtime() and passed
	passed = _test_mirror_layout_runtime() and passed
	passed = _test_direction_sheet_compiles() and passed
	passed = _test_font_fallback_runtime() and passed
	passed = _test_font_can_show_runtime() and passed
	passed = _test_use_font_runtime() and passed
	passed = _test_text_overflows_runtime() and passed
	passed = _test_fit_text_runtime() and passed
	passed = _test_fits_in_width_runtime() and passed
	passed = _test_wrapped_height_runtime() and passed
	passed = _test_fit_sheet_compiles_and_runs() and passed
	passed = _test_overflow_measures_the_translation() and passed
	passed = _test_fit_survives_a_language_switch() and passed
	passed = _test_fit_never_reads_as_the_ending_alone() and passed
	passed = _test_null_fallback_is_inert() and passed
	TranslationServer.set_locale(restore_locale)
	return passed


## THE bug this group exists for, in the shape it really occurs: the label still holds its ENGLISH
## source string, because that is how a Control keeps translating itself, and Godot draws the German
## translation of it. Measuring `text` answers about English on every screen and reports "fits";
## measuring what is drawn reports the overflow. Both numbers are asserted so the test says WHY.
static func _test_overflow_measures_the_translation() -> bool:
	var catalog: Translation = Translation.new()
	catalog.locale = "de"
	catalog.add_message(StringName(ENGLISH), StringName(GERMAN))
	TranslationServer.add_translation(catalog)
	TranslationServer.set_locale("de")
	var label: Label = _label_running(_apply("TextOverflows", {"target": ""}), 105.0, ENGLISH)
	var ok: bool = true
	if label == null:
		ok = _check("Text Overflows compiles on a Control", false, true)
	else:
		ok = _check("the label still holds the English source string", label.text, ENGLISH) and ok
		ok = _check("...but draws its German translation", label.atr(str(label.text)), GERMAN) and ok
		ok = _check("the English source would have measured as fitting", _width(ENGLISH) <= 105.0, true) and ok
		ok = _check("the German it draws does not fit", _width(GERMAN) > 105.0, true) and ok
		ok = _check("so the row answers that the text overflows", bool(label.call("__t")), true) and ok
		label.free()
	# The precondition, pinned rather than left to a reader: a Label free to grow is grown by the
	# engine to hold its text, so `size` can never be smaller than the string and the answer is a
	# truthful false. This is why the description tells you to clip.
	var growing: Label = Label.new()
	growing.text = GERMAN
	growing.size = Vector2(60, 30)
	ok = _check("a label free to grow reports a minimum size that already holds its text",
		growing.get_combined_minimum_size().x >= _width(GERMAN), true) and ok
	growing.free()
	TranslationServer.remove_translation(catalog)
	TranslationServer.set_locale("en")
	return ok


## Fitting a label must not be a one-way door. The row runs in German and cuts; the player switches
## to English and it runs again - and the label reads its full English line, still holding the source
## string, so it goes on translating itself like an untouched label.
static func _test_fit_survives_a_language_switch() -> bool:
	var catalog: Translation = Translation.new()
	catalog.locale = "de"
	catalog.add_message(StringName(ENGLISH), StringName(GERMAN))
	TranslationServer.add_translation(catalog)
	TranslationServer.set_locale("de")
	var label: Label = _label_acting(_apply("FitTextToLabel", {"target": "", "suffix": "\"...\""}).replace("{uid}", "t"), 100.0, ENGLISH)
	var ok: bool = true
	if label == null:
		TranslationServer.remove_translation(catalog)
		return _check("Fit Text To Label compiles on a Control", false, true)
	label.call("__act")
	ok = _check("in German the line is cut to fit", label.text, "SPIEL...") and ok
	ok = _check("...and the string it was handed is remembered",
		str(label.get_meta(&"fit_source_text")), ENGLISH) and ok
	label.call("__act")
	ok = _check("running it again re-fits the same source instead of cutting the leftovers",
		label.text, "SPIEL...") and ok
	TranslationServer.set_locale("en")
	label.call("__act")
	ok = _check("back in English the whole line is put back", label.text, ENGLISH) and ok
	ok = _check("...as the SOURCE string, so the label still translates itself",
		label.atr(str(label.text)), ENGLISH) and ok
	label.free()
	TranslationServer.remove_translation(catalog)
	return ok


## The edge the documented guarantee is about: the ending FITS but no glyph of the text does, so the
## trim empties the string. The result must be nothing at all, never a lone "...".
static func _test_fit_never_reads_as_the_ending_alone() -> bool:
	var label: Label = _label_acting(_apply("FitTextToLabel", {"target": "", "suffix": "\"...\""}).replace("{uid}", "t"), 60.0, "Widerstand")
	if label == null:
		return _check("Fit Text To Label compiles on a Control", false, true)
	label.add_theme_font_size_override(&"font_size", 64)
	var ending: float = ThemeDB.fallback_font.get_string_size("...", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 64).x
	var ok: bool = _check("the ending alone fits the control", ending < 60.0, true)
	ok = _check("but the narrowest glyph of the text does not fit what is left",
		ThemeDB.fallback_font.get_string_size("W", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 64).x > 60.0 - ending, true) and ok
	label.call("__act")
	ok = _check("the label is left empty rather than reading as the ending alone", label.text, "") and ok
	label.free()
	return ok


## The row as DROPPED: no font named yet. It must do nothing at all - not push a load error, and
## above all not append a null into a font's fallback chain, where it stays for the whole session.
static func _test_null_fallback_is_inert() -> bool:
	var base: Font = ThemeDB.fallback_font.duplicate()
	var node: Node = _node_acting(_apply("AddFontFallback", {"font": "font", "fallback": _param_default("AddFontFallback", "fallback")}), "Node", "var font: Font\n")
	if node == null:
		return _check("Add Font Fallback compiles with its shipped defaults", false, true)
	node.set("font", base)
	node.call("__act")
	var ok: bool = _check("the dropped row leaves the chain empty", base.fallbacks.size(), 0)
	ok = _check("...and the font still draws what it always did", base.has_char("A".unicode_at(0)), true) and ok
	node.free()
	return ok


## What the registry actually SHIPS, verbatim. Four of these templates are not the authored ones:
## registration prefixes a node-scoped ACE's lines with {target.} and appends an "On node" param.
## The two fitting verbs opt OUT of that transform by owning a param called "target", because their
## lines touch three members each and a per-line prefix would have retargeted only the first.
static func _test_registry_pins_shipped_templates() -> bool:
	var ok: bool = true
	for row: Array in [
		["LanguageIsRightToLeft", "Language Reads Right To Left", ACEDescriptor.ACEType.CONDITION, "Translation", "",
			"TextServerManager.get_primary_interface().is_locale_right_to_left(TranslationServer.get_locale())"],
		["MirrorLayoutForLanguage", "Mirror Layout For Language", ACEDescriptor.ACEType.ACTION, "Translation", "Control",
			"{target.}layout_direction = Control.LAYOUT_DIRECTION_APPLICATION_LOCALE"],
		["LayoutIsMirrored", "Layout Is Mirrored", ACEDescriptor.ACEType.CONDITION, "Translation", "Control",
			"{target.}is_layout_rtl()"],
		["AddFontFallback", "Add Font Fallback", ACEDescriptor.ACEType.ACTION, "UI", "",
			"if {fallback} != null and not {font}.fallbacks.has({fallback}):\n\t{font}.fallbacks = {font}.fallbacks + [{fallback}]"],
		["UseFont", "Use Font", ACEDescriptor.ACEType.ACTION, "UI", "Control",
			"{target.}add_theme_font_override({slot}, {font})"],
		["ControlFont", "Font Of This Control", ACEDescriptor.ACEType.EXPRESSION, "UI", "Control",
			"{target.}get_theme_font(&\"font\")"],
		["FontCanShow", "Font Can Show", ACEDescriptor.ACEType.CONDITION, "UI", "",
			"({text}.is_empty() or Array(range({text}.length())).all(func(__i): return {font}.has_char({text}.unicode_at(__i))))"],
		["TextOverflows", "Text Overflows", ACEDescriptor.ACEType.CONDITION, "Text", "Control",
			"{target.}get_theme_font(&\"font\").get_string_size({target.}atr(str({target.}text)), HORIZONTAL_ALIGNMENT_LEFT, -1.0, {target.}get_theme_font_size(&\"font_size\")).x > {target.}size.x"],
		["TextFitsInWidth", "Text Fits In Width", ACEDescriptor.ACEType.CONDITION, "Text", "",
			"{font}.get_string_size({text}, HORIZONTAL_ALIGNMENT_LEFT, -1.0, {font_size}).x <= float({width})"],
		["WrappedTextHeight", "Wrapped Text Height", ACEDescriptor.ACEType.EXPRESSION, "Text", "",
			"{font}.get_multiline_string_size({text}, HORIZONTAL_ALIGNMENT_LEFT, float({width}), {font_size}).y"],
	]:
		var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", str(row[0]))
		if descriptor == null:
			ok = _check("%s is registered" % str(row[0]), false, true) and ok
			continue
		ok = _check("%s reads as \"%s\"" % [row[0], row[1]], descriptor.display_name, str(row[1])) and ok
		ok = _check("%s is a %s" % [row[0], _kind(int(row[2]))], descriptor.ace_type, int(row[2])) and ok
		ok = _check("%s sits in %s" % [row[0], row[3]], descriptor.category, str(row[3])) and ok
		ok = _check("%s is scoped to \"%s\"" % [row[0], row[4]], descriptor.node_type, str(row[4])) and ok
		ok = _check("%s ships its template unchanged" % row[0], descriptor.codegen_template, str(row[5])) and ok

	# Fit Text To Label is the one multi-statement template: pin the lines that carry its rules, so a
	# later edit cannot quietly drop the whole-word backup or the too-narrow hard cut.
	var fit: String = _template("FitTextToLabel")
	ok = _check("Fit Text To Label reads the control's own font",
		fit.contains("var __fit_font_{uid}: Font = {target.}get_theme_font(&\"font\")"), true) and ok
	ok = _check("Fit Text To Label budgets the ending's own width",
		fit.contains("var __fit_budget_{uid}: float = __fit_room_{uid} - __fit_font_{uid}.get_string_size(__fit_mark_{uid}, HORIZONTAL_ALIGNMENT_LEFT, -1.0, __fit_px_{uid}).x"), true) and ok
	ok = _check("Fit Text To Label drops the ending when there is no room for it",
		fit.contains("\tif __fit_budget_{uid} <= 0.0:\n\t\t__fit_budget_{uid} = __fit_room_{uid}\n\t\t__fit_mark_{uid} = \"\""), true) and ok
	ok = _check("Fit Text To Label backs up to a whole word only when one survives",
		fit.contains("\tif not __fit_word_{uid}.is_empty() and not __fit_cut_{uid}.ends_with(\" \"):"), true) and ok
	ok = _check("Fit Text To Label writes the result back to the control",
		fit.contains("\t{target.}text = __fit_cut_{uid}.strip_edges() + __fit_mark_{uid}"), true) and ok
	ok = _check("Fit Text To Label remembers the string it was handed, once",
		fit.contains("if not {target.}has_meta(&\"fit_source_text\"):\n\t{target.}set_meta(&\"fit_source_text\", str({target.}text))"), true) and ok
	ok = _check("...and starts every run from that remembered source",
		fit.contains("{target.}text = str({target.}get_meta(&\"fit_source_text\"))"), true) and ok
	ok = _check("Fit Text To Label measures what the control DRAWS, not the source it holds",
		fit.contains("var __fit_cut_{uid}: String = {target.}atr(str({target.}text))"), true) and ok
	ok = _check("Fit Text To Label drops the ending when nothing survived the trim",
		fit.contains("\tif __fit_cut_{uid}.strip_edges().is_empty():\n\t\t__fit_mark_{uid} = \"\""), true) and ok

	# The two fitting verbs own their target param, which is what suppresses the per-line transform.
	ok = _check("Text Overflows owns its On node param", _param_ids("TextOverflows"), "target") and ok
	ok = _check("Fit Text To Label owns its On node param", _param_ids("FitTextToLabel"), "suffix,target") and ok
	# Add Font Fallback's defaults have to stand on their own the moment the row is dropped.
	ok = _check("Add Font Fallback defaults to the engine's own font",
		_param_default("AddFontFallback", "font"), "ThemeDB.fallback_font") and ok
	# The dropped row must be INERT, not broken: a default naming a font file that exists in nobody's
	# project would push a load error and append a null into the chain the moment the row is added.
	ok = _check("Add Font Fallback's fallback default names no file at all",
		_param_default("AddFontFallback", "fallback"), "null") and ok
	ok = _check("...and the template refuses to append a null fallback",
		_template("AddFontFallback").begins_with("if {fallback} != null and not "), true) and ok
	ok = _check("Use Font's slot list opens on the main font slot",
		_param_default("UseFont", "slot"), "&\"font\"") and ok
	return ok


## The language question, run against three real locales. TextServer answers, so a language nobody
## listed is still covered - which is the claim in the description.
static func _test_language_direction_runtime() -> bool:
	var node: Node = _node_running(_apply("LanguageIsRightToLeft", {}), "Node")
	if node == null:
		return _check("Language Reads Right To Left compiles", false, true)
	var ok: bool = true
	for row: Array in [["ar", true], ["he", true], ["fa", true], ["ar_EG", true], ["en", false], ["de", false]]:
		TranslationServer.set_locale(str(row[0]))
		ok = _check("in %s, language reads right to left = %s" % [row[0], row[1]], bool(node.call("__t")), bool(row[1])) and ok
	node.free()
	return ok


## Mirror Layout For Language, run on a real Control, read back by Layout Is Mirrored. A fresh
## Control per case: is_layout_rtl() caches, and a treeless test never receives the notification that
## clears that cache.
static func _test_mirror_layout_runtime() -> bool:
	var ok: bool = true
	for row: Array in [["ar", true], ["he", true], ["en", false], ["pt_BR", false]]:
		TranslationServer.set_locale(str(row[0]))
		var control: Control = _control_running(_apply("MirrorLayoutForLanguage", {"target": ""}), _apply("LayoutIsMirrored", {"target": ""}))
		if control == null:
			ok = _check("Mirror Layout For Language compiles on a Control", false, true) and ok
			continue
		control.call("__act")
		ok = _check("in %s the mirrored layout direction is taken from the language" % row[0],
			control.layout_direction, Control.LAYOUT_DIRECTION_APPLICATION_LOCALE) and ok
		ok = _check("in %s, layout is mirrored = %s" % [row[0], row[1]], bool(control.call("__t")), bool(row[1])) and ok
		control.free()
	# What the row is actually FOR, checked rather than assumed: a fresh control starts on
	# LAYOUT_DIRECTION_INHERITED, and this project's root direction happens to follow the application
	# locale already - so an untouched control IS mirrored in Arabic and the row would look pointless.
	# It stops looking pointless the moment something forced a direction: a control (or an ancestor)
	# pinned to left-to-right stays left-to-right in Arabic until this row hands it back to the
	# language. That is the case pinned here, because it is the one that fails silently in a build.
	TranslationServer.set_locale("ar")
	var untouched: Control = Control.new()
	ok = _check("a fresh control starts on the inherited direction", untouched.layout_direction, Control.LAYOUT_DIRECTION_INHERITED) and ok
	untouched.free()
	var pinned: Control = Control.new()
	pinned.layout_direction = Control.LAYOUT_DIRECTION_LTR
	ok = _check("a control pinned left-to-right is not mirrored in Arabic", pinned.is_layout_rtl(), false) and ok
	pinned.free()
	var rescued: Control = _control_running(_apply("MirrorLayoutForLanguage", {"target": ""}), _apply("LayoutIsMirrored", {"target": ""}))
	if rescued == null:
		return _check("Mirror Layout For Language compiles on a Control", false, true) and ok
	rescued.layout_direction = Control.LAYOUT_DIRECTION_LTR
	rescued.call("__act")
	ok = _check("...and the row hands that control back to the language", bool(rescued.call("__t")), true) and ok
	rescued.free()
	return ok


## The direction rows through the real compiler: on a Control host, and retargeted at another node.
static func _test_direction_sheet_compiles() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Control"
	var ready_row: EventRow = EventRow.new()
	ready_row.trigger_provider_id = "Core"
	ready_row.trigger_id = "OnReady"
	ready_row.actions.append(_action("MirrorLayoutForLanguage", {"target": ""}))
	ready_row.actions.append(_action("MirrorLayoutForLanguage", {"target": "$Panel"}))
	sheet.events.append(ready_row)
	var output: String = str(SheetCompiler.compile(sheet, "user://text_fit_direction.gd").get("output", ""))
	var ok: bool = _check("a blank target mirrors the sheet's own control",
		output.contains("\tlayout_direction = Control.LAYOUT_DIRECTION_APPLICATION_LOCALE"), true)
	ok = _check("a chosen target mirrors that node instead",
		output.contains("\t$Panel.layout_direction = Control.LAYOUT_DIRECTION_APPLICATION_LOCALE"), true) and ok
	var script: GDScript = GDScript.new()
	script.source_code = output
	ok = _check("the direction sheet parses", script.reload(), OK) and ok
	return ok


## Add Font Fallback, run for real: the glyph appears, and running the same row twice does not add
## the fallback twice (the promise that makes it safe under On Language Changed).
static func _test_font_fallback_runtime() -> bool:
	var base: Font = ThemeDB.fallback_font.duplicate()
	var extra: FontFile = _one_glyph_font()
	var ok: bool = _check("the bundled default font cannot draw U+3042", base.has_char(CJK_CHAR_CODE), false)
	ok = _check("the built fallback font can", extra.has_char(CJK_CHAR_CODE), true) and ok
	var node: Node = _node_acting(_apply("AddFontFallback", {"font": "font", "fallback": "extra"}), "Node", "var font: Font\nvar extra: Font\n")
	if node == null:
		return _check("Add Font Fallback compiles", false, true) and ok
	node.set("font", base)
	node.set("extra", extra)
	node.call("__act")
	ok = _check("after one row the chain draws U+3042", base.has_char(CJK_CHAR_CODE), true) and ok
	ok = _check("the Latin face is still there", base.has_char("A".unicode_at(0)), true) and ok
	ok = _check("the fallback landed once", base.fallbacks.size(), 1) and ok
	node.call("__act")
	node.call("__act")
	ok = _check("running the same row again adds nothing", base.fallbacks.size(), 1) and ok
	# The engine's own default font is a shared singleton resource - the row must not have touched it.
	ok = _check("the engine's shared default font was left alone", ThemeDB.fallback_font.fallbacks.size(), 0) and ok
	node.free()
	return ok


## Font Can Show, on the character that breaks Japanese builds: false before the fallback, true
## after it, because has_char walks the chain.
static func _test_font_can_show_runtime() -> bool:
	var node: Node = _node_running(_apply("FontCanShow", {"font": "font", "text": "text"}), "Node", "var font: Font\nvar text: String\n")
	if node == null:
		return _check("Font Can Show compiles", false, true)
	var base: Font = ThemeDB.fallback_font.duplicate()
	var japanese: String = String.chr(CJK_CHAR_CODE) + String.chr(CJK_CHAR_CODE)
	node.set("font", base)
	var ok: bool = true
	node.set("text", ENGLISH)
	ok = _check("the default font can show an English string", bool(node.call("__t")), true) and ok
	node.set("text", GERMAN + " Grosse")
	ok = _check("and a German one", bool(node.call("__t")), true) and ok
	node.set("text", japanese)
	ok = _check("but not a Japanese one", bool(node.call("__t")), false) and ok
	node.set("text", "")
	ok = _check("empty text is never a coverage problem", bool(node.call("__t")), true) and ok
	base.fallbacks = [_one_glyph_font()]
	node.set("text", japanese)
	ok = _check("with the fallback added, the same string can be shown", bool(node.call("__t")), true) and ok
	node.set("text", japanese + String.chr(0x6F22))
	ok = _check("a character the fallback also lacks still answers false", bool(node.call("__t")), false) and ok
	node.free()
	return ok


## Use Font and Font Of This Control, on real controls: the override lands in the named slot, and the
## expression reads back what the control is really drawing with.
static func _test_use_font_runtime() -> bool:
	var extra: FontFile = _one_glyph_font()
	var label: Label = Label.new()
	var script: GDScript = _script("Label", "var chosen: Font\n", [
		["__act", "void", _apply("UseFont", {"target": "", "slot": "&\"font\"", "font": "chosen"})],
		["__t", "Variant", "return %s" % _apply("ControlFont", {"target": ""})],
	])
	var ok: bool = true
	if script == null:
		return _check("Use Font compiles on a Label", false, true)
	label.set_script(script)
	label.set("chosen", extra)
	ok = _check("before the row, the label draws with the engine default",
		label.call("__t") == ThemeDB.fallback_font, true) and ok
	label.call("__act")
	ok = _check("Use Font overrides the label's main font slot", label.has_theme_font_override(&"font"), true) and ok
	ok = _check("Font Of This Control reads the font actually in use", label.call("__t") == extra, true) and ok
	label.free()
	# The RichTextLabel slot from the dropdown is a real slot on a real control, not a guess.
	var rich: RichTextLabel = RichTextLabel.new()
	var rich_script: GDScript = _script("RichTextLabel", "var chosen: Font\n", [
		["__act", "void", _apply("UseFont", {"target": "", "slot": "&\"normal_font\"", "font": "chosen"})],
	])
	if rich_script == null:
		ok = _check("Use Font compiles on a RichTextLabel", false, true) and ok
	else:
		rich.set_script(rich_script)
		rich.set("chosen", extra)
		rich.call("__act")
		ok = _check("the rich-text slot overrides the face rich text actually draws with",
			rich.has_theme_font_override(&"normal_font"), true) and ok
	rich.free()
	return ok


## Text Overflows, in pixels, on the case it exists for: the English label fits its button and the
## German translation of the same key does not.
static func _test_text_overflows_runtime() -> bool:
	var ok: bool = true
	for row: Array in [[ENGLISH, 100.0, false], [GERMAN, 100.0, true], [GERMAN, 200.0, false], ["", 40.0, false], [ENGLISH, 40.0, true]]:
		var label: Label = _label_running(_apply("TextOverflows", {"target": ""}), float(row[1]), str(row[0]))
		if label == null:
			return _check("Text Overflows compiles on a Control", false, true) and ok
		ok = _check("\"%s\" in %d px overflows = %s" % [row[0], int(row[1]), row[2]], bool(label.call("__t")), bool(row[2])) and ok
		label.free()
	# The measurement is the control's REAL font metric, not a character count: the German string is
	# one character shorter than the English one and still wider.
	ok = _check("the German string is not longer in characters", GERMAN.length() < ENGLISH.length() + 4, true) and ok
	ok = _check("but it is wider in pixels", _width(GERMAN) > _width(ENGLISH), true) and ok
	return ok


## Fit Text To Label, run on real labels. Every case ends up measuring inside the control, which is
## the promise; the exact strings pin HOW it got there (whole word, mid-word, or hard cut).
static func _test_fit_text_runtime() -> bool:
	var ok: bool = true
	for row: Array in [
		[ENGLISH, 100.0, "\"...\"", ENGLISH],
		[GERMAN, 100.0, "\"...\"", "SPIEL..."],
		["Ancient Sword of Thorns", 120.0, "\"...\"", "Ancient..."],
		["Supercalifragilistic", 60.0, "\"...\"", "Super..."],
		[GERMAN, 10.0, "\"...\"", "S"],
		[GERMAN, 100.0, "\"\"", "SPIEL"],
		[" leading space text", 40.0, "\"...\"", "le..."],
	]:
		var label: Label = _label_acting(_apply("FitTextToLabel", {"target": "", "suffix": str(row[2])}).replace("{uid}", "t"), float(row[1]), str(row[0]))
		if label == null:
			return _check("Fit Text To Label compiles on a Control", false, true) and ok
		label.call("__act")
		ok = _check("\"%s\" fitted into %d px ends %s" % [row[0], int(row[1]), row[2]], label.text, str(row[3])) and ok
		ok = _check("...and the result measures inside the control", _width(label.text) <= float(row[1]), true) and ok
		label.free()
	return ok


## Text Fits In Width: the same measurement without a control, for something not on screen yet.
static func _test_fits_in_width_runtime() -> bool:
	var node: Node = _node_running(_apply("TextFitsInWidth", {"font": "ThemeDB.fallback_font", "text": "text", "width": "width", "font_size": "16"}), "Node", "var text: String\nvar width: float\n")
	if node == null:
		return _check("Text Fits In Width compiles", false, true)
	var ok: bool = true
	for row: Array in [[ENGLISH, 180.0, true], [ENGLISH, 100.0, true], [ENGLISH, 90.0, false], [GERMAN, 100.0, false], [GERMAN, 180.0, true], ["", 1.0, true]]:
		node.set("text", str(row[0]))
		node.set("width", float(row[1]))
		ok = _check("\"%s\" fits in %d px = %s" % [row[0], int(row[1]), row[2]], bool(node.call("__t")), bool(row[2])) and ok
	# A bigger font size is the same string not fitting any more - the size really is read.
	var big: Node = _node_running(_apply("TextFitsInWidth", {"font": "ThemeDB.fallback_font", "text": "text", "width": "width", "font_size": "32"}), "Node", "var text: String\nvar width: float\n")
	if big != null:
		big.set("text", ENGLISH)
		big.set("width", 100.0)
		ok = _check("the same string at twice the size does not fit", bool(big.call("__t")), false) and ok
		big.free()
	node.free()
	return ok


## Wrapped Text Height: the vertical question a single-line width cannot answer.
static func _test_wrapped_height_runtime() -> bool:
	var node: Node = _node_running(_apply("WrappedTextHeight", {"font": "ThemeDB.fallback_font", "text": "text", "width": "width", "font_size": "16"}), "Node", "var text: String\nvar width: float\n")
	if node == null:
		return _check("Wrapped Text Height compiles", false, true)
	var sentence: String = "the quick brown fox jumps over the lazy dog"
	node.set("text", sentence)
	node.set("width", 2000.0)
	var one_line: float = float(node.call("__t"))
	node.set("width", 60.0)
	var wrapped: float = float(node.call("__t"))
	var ok: bool = _check("a box wide enough needs one line", one_line > 0.0, true)
	ok = _check("a narrow box needs several", wrapped >= one_line * 4.0, true) and ok
	node.set("width", 120.0)
	var middle: float = float(node.call("__t"))
	ok = _check("a wider box needs fewer lines than a narrow one", middle < wrapped, true) and ok
	ok = _check("...and never fewer than one", middle >= one_line, true) and ok
	node.free()
	return ok


## The end-to-end shape from the suggestion: under On Ready, IF the text overflows, fit it. Compiled
## by the real compiler, then run on a real Label carrying the compiled script.
static func _test_fit_sheet_compiles_and_runs() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Label"
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnReady"
	row.conditions.append(_condition("TextOverflows", {"target": ""}))
	row.actions.append(_action("FitTextToLabel", {"target": "", "suffix": "\"...\""}, "r1"))
	sheet.events.append(row)
	var output: String = str(SheetCompiler.compile(sheet, "user://text_fit_overflow.gd").get("output", ""))
	var ok: bool = _check("the overflow test lands in the condition",
		output.contains("if get_theme_font(&\"font\").get_string_size(atr(str(text)), HORIZONTAL_ALIGNMENT_LEFT, -1.0, get_theme_font_size(&\"font_size\")).x > size.x:"), true)
	ok = _check("the fit action's locals carry the row id",
		output.contains("var __fit_cut_r1: String = atr(str(text))"), true) and ok
	ok = _check("nothing left an unbaked placeholder behind", output.contains("{uid}"), false) and ok
	var script: GDScript = GDScript.new()
	script.source_code = output
	if script.reload() != OK:
		return _check("the compiled overflow sheet parses", false, true) and ok
	ok = _check("the compiled overflow sheet parses", true, true) and ok
	var label: Label = Label.new()
	label.set_script(script)
	label.clip_text = true
	label.size = Vector2(100, 30)
	label.text = GERMAN
	label.call("_ready")
	ok = _check("the German label was shortened until it fits", label.text, "SPIEL...") and ok
	var kept: Label = Label.new()
	kept.set_script(script)
	kept.clip_text = true
	kept.size = Vector2(100, 30)
	kept.text = ENGLISH
	kept.call("_ready")
	ok = _check("the English label was left exactly as it was", kept.text, ENGLISH) and ok
	label.free()
	kept.free()
	return ok


## A bitmap font carrying exactly one glyph, U+3042 - a real Font the default font has no answer for.
static func _one_glyph_font() -> FontFile:
	var font: FontFile = FontFile.new()
	font.fixed_size = 16
	font.set_cache_ascent(0, 16, 12.0)
	font.set_cache_descent(0, 16, 4.0)
	font.set_glyph_advance(0, 16, CJK_CHAR_CODE, Vector2(16, 0))
	return font


## One line of text measured in the engine's default font at 16 - the same call the verbs emit.
static func _width(text: String) -> float:
	return ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16).x


## The SHIPPED template with its params filled, through the compiler's own substitution pass (so the
## optional {target.} prefix behaves exactly as it does in emitted code).
static func _apply(ace_id: String, params: Dictionary) -> String:
	return ActionCodegen._apply_template(_template(ace_id), params)


static func _template(ace_id: String) -> String:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	return str(descriptor.codegen_template) if descriptor != null else ""


## An action row carrying the real descriptor's template plus the params the dock would store.
static func _action(ace_id: String, params: Dictionary, uid: String = "u") -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.codegen_template = _template(ace_id).replace("{uid}", uid)
	action.params = params
	return action


static func _condition(ace_id: String, params: Dictionary) -> ACECondition:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = ace_id
	condition.codegen_template = _template(ace_id)
	condition.params = params
	return condition


## Builds a script for `host` with the given members and one function per entry:
## [name, return type, body] - the body already indented one level by the caller's template.
static func _script(host: String, members: String, functions: Array) -> GDScript:
	var source: String = "@tool\nextends %s\n%s" % [host, members]
	for entry: Array in functions:
		source += "\n\nfunc %s() -> %s:\n\t%s\n" % [str(entry[0]), str(entry[1]), str(entry[2]).replace("\n", "\n\t")]
	var script: GDScript = GDScript.new()
	script.source_code = source
	if script.reload() != OK:
		print("  [text_fit_aces_test] source did not compile:\n%s" % source)
		return null
	return script


## A Node whose __t() returns the given EXPRESSION.
static func _node_running(expression: String, host: String, members: String = "") -> Node:
	var script: GDScript = _script(host, members, [["__t", "Variant", "return (%s)" % expression]])
	if script == null:
		return null
	var node: Node = Node.new()
	node.set_script(script)
	return node


## A Node whose __act() runs the given STATEMENTS.
static func _node_acting(statements: String, host: String, members: String = "") -> Node:
	var script: GDScript = _script(host, members, [["__act", "void", statements]])
	if script == null:
		return null
	var node: Node = Node.new()
	node.set_script(script)
	return node


## A Control that can run an action and read a condition back on itself.
static func _control_running(statements: String, expression: String) -> Control:
	var script: GDScript = _script("Control", "", [
		["__act", "void", statements],
		["__t", "Variant", "return (%s)" % expression],
	])
	if script == null:
		return null
	var control: Control = Control.new()
	control.set_script(script)
	return control


## A sized Label with text, whose __t() answers the given condition about itself.
static func _label_running(expression: String, width: float, text: String) -> Label:
	var script: GDScript = _script("Label", "", [["__t", "Variant", "return (%s)" % expression]])
	if script == null:
		return null
	return _sized_label(script, width, text)


## A sized Label with text, whose __act() runs the given statements on itself.
static func _label_acting(statements: String, width: float, text: String) -> Label:
	var script: GDScript = _script("Label", "", [["__act", "void", statements]])
	if script == null:
		return null
	return _sized_label(script, width, text)


## A Label that CANNOT grow, which is the only shape an overflow question means anything on: Godot
## clamps `size` up to a Control's minimum size, and a Label's minimum size includes its own text
## unless it clips. Clip Text is therefore set FIRST - set afterwards, the cached minimum size has
## already swallowed the width and the label reports 115 px where 100 was asked for (checked on 4.7).
static func _sized_label(script: GDScript, width: float, text: String) -> Label:
	var label: Label = Label.new()
	label.set_script(script)
	label.clip_text = true
	label.size = Vector2(width, 30)
	label.text = text
	return label


static func _param_ids(ace_id: String) -> String:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	if descriptor == null:
		return ""
	var ids: PackedStringArray = PackedStringArray()
	for parameter: ACEParam in descriptor.params:
		ids.append(str(parameter.id))
	return ",".join(ids)


static func _param_default(ace_id: String, param_id: String) -> String:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	if descriptor == null:
		return ""
	for parameter: ACEParam in descriptor.params:
		if str(parameter.id) == param_id:
			return str(parameter.default_value)
	return ""


static func _kind(ace_type: int) -> String:
	match ace_type:
		ACEDescriptor.ACEType.CONDITION: return "condition"
		ACEDescriptor.ACEType.ACTION: return "action"
		ACEDescriptor.ACEType.EXPRESSION: return "expression"
	return "trigger"


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] text_fit_aces_test: %s" % label)
		return true
	print("[FAIL] text_fit_aces_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
