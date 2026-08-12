# EventForge module - DISPLAY text: making a value readable before it reaches a Label.
#
# The plain string verbs (Left / Mid / Uppercase / Text Length / Format Decimals / Zero Pad) live in
# system_aces, regex_aces and collection_aces; this module adds the four jobs they leave open, all of
# them things a label needs and a hand-rolled expression gets subtly wrong:
#
#  - FITTING: Shorten To Fit trims by characters and MARKS the cut; Shorten To Whole Words backs up to
#    the last word boundary first, so a clipped name never reads as a whole name. The whole-words form
#    falls back to the character form when the budget holds no whole word (one very long word, or a
#    window whose only space is its first character), which is the case a hand-written "cut at the
#    last space" returns just the ellipsis for. BOTH forms hard-cut with no marker when the width is
#    too narrow to hold the ending at all, so neither can ever return a result wider than the width
#    it was given, and neither can return the ending on its own.
#  - READABLE NUMBERS: thousands separators, a fraction as a percent, seconds as a duration that
#    survives passing an hour (As Clock Time is mm:ss and rolls 1h into "60:00"). The Big Numbers pack
#    ships idle-scale versions of these over its own Decimal type; these are the plain-float ones, so a
#    comma in a score label does not require registering an autoload first.
#  - COLUMNS: Align Left / Align Right / Center In Width pad text to a fixed width (Godot's rpad/lpad,
#    exposed nowhere else in the vocabulary) so rows line up. They only truly line up in a MONOSPACE
#    font, and every one of their descriptions says so.
#  - TRANSLATED PATTERNS: tr() FIRST, .format() second. Composing the shipped Text From Pattern with
#    the shipped Translate the natural way looks up a string that has already had its slots filled -
#    no catalog can contain it, so the label silently stays in the source language forever. These two
#    verbs make the correct order the easy one, and the pattern (slots and all) stays the key.
#
# Every template is a single plain expression: no plugin runtime, no helper library, no state.
# ace_ids and codegen_templates are a compatibility covenant: frozen once shipped (deprecate, never rename).
@tool
class_name EventForgeTextFormatACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")
const CAT := "Text"
const CAT_TRANSLATION := "Translation"

## The character budget shared by both Shorten verbs: how much room is left once the marker is
## accounted for, never below zero. Written out in each template so the emitted line stays plain
## GDScript with nothing to look up.
const _BUDGET := "maxi(int({max_chars}) - {suffix}.length(), 0)"

## What both verbs do when the budget is ZERO - a width at or under the marker's own length, e.g.
## "..." into 2 characters. Marking the cut is impossible there (the marker alone would BE the
## result and would still overrun the stated width), so the text wins: a hard cut to max_chars, no
## marker. Without this clause both verbs returned a bare "..." - three characters for a
## two-character maximum, the exact outcome Shorten To Whole Words promises cannot happen, and an
## overflow for any caller that sized a fixed-width column from max_chars.
const _HARD_CUT := "{text}.left(maxi(int({max_chars}), 0))"


static func get_descriptors() -> Array[ACEDescriptor]:
	var d: Array[ACEDescriptor] = []

	# ── Fitting text into a fixed width ──
	d.append(F.make_descriptor("Core", "ShortenToFit", "Shorten To Fit", ACEDescriptor.ACEType.EXPRESSION,
		"({text} if {text}.length() <= int({max_chars}) else ({text}.left(%s).strip_edges() + {suffix} if %s > 0 else %s))" % [_BUDGET, _BUDGET, _HARD_CUT], "",
		[
			_text_param("\"Ancient Sword of Thorns\"", "The text that has to fit."),
			_max_chars_param("14"),
			_suffix_param(),
		], CAT, "shorten [b]{text}[/b] to [b]{max_chars}[/b] characters")
		.described("Trims text to a maximum number of characters and marks the cut with the ending you choose, so a clipped name never reads as the whole name. Text that already fits comes back untouched, and the result never runs past the width you gave - a width too narrow to hold the ending simply cuts without one. Cuts mid-word: use Shorten To Whole Words when the cut should land on a word boundary."))

	# Three branches, in the order they matter: back up to a word boundary when there IS one AND the
	# text before it is not empty (a budget window whose only space is its first character would
	# otherwise leave the marker standing alone), cut by characters when there is not, and hard-cut
	# with no marker when the budget is zero.
	d.append(F.make_descriptor("Core", "ShortenToWholeWords", "Shorten To Whole Words", ACEDescriptor.ACEType.EXPRESSION,
		"({text} if {text}.length() <= int({max_chars}) else (({text}.left(%s + 1).rsplit(\" \", true, 1)[0].strip_edges() + {suffix}) if (%s > 0 and {text}.left(%s + 1).contains(\" \") and not {text}.left(%s + 1).rsplit(\" \", true, 1)[0].strip_edges().is_empty()) else ({text}.left(%s).strip_edges() + {suffix} if %s > 0 else %s)))" % [_BUDGET, _BUDGET, _BUDGET, _BUDGET, _BUDGET, _BUDGET, _HARD_CUT], "",
		[
			_text_param("\"Ancient Sword of Thorns\"", "The text that has to fit."),
			_max_chars_param("20"),
			_suffix_param(),
		], CAT, "shorten [b]{text}[/b] to whole words within [b]{max_chars}[/b]")
		.described("Like Shorten To Fit, but backs up to the last complete word before cutting, so \"Ancient Sword of Thorns\" reads \"Ancient Sword...\" instead of \"Ancient Sword of Th\". When the budget holds no whole word (one very long word) it falls back to cutting by characters, and when it is too narrow to hold the ending at all it cuts without one - so the result is never just the ending, and never wider than you asked for."))

	# ── Readable numbers (the plain-float twins of the Big Numbers pack's idle-scale formatters) ──
	d.append(F.make_descriptor("Core", "WithThousandsSeparators", "With Thousands Separators", ACEDescriptor.ACEType.EXPRESSION,
		"((\"-\" if float({value}) < 0.0 else \"\") + RegEx.create_from_string(\"(\\\\d)(?=(\\\\d\\\\d\\\\d)+$)\").sub(str(absi(int({value}))), \"$1,\", true))", "",
		[F.make_param("value", "String", "1234567", "Value", "The number to make readable. Anything after the decimal point is dropped.", "expression")],
		CAT, "[b]{value}[/b] with thousands separators")
		.described("Turns a number into grouped digits a player can take in at a glance: 1234567 reads \"1,234,567\". Whole numbers only (the fraction is dropped); a negative keeps its minus sign. For idle-game scale (1.23e15, \"1.23 Qa\") reach for the Big Numbers pack instead."))

	d.append(F.make_descriptor("Core", "AsPercentText", "As Percent Text", ACEDescriptor.ACEType.EXPRESSION,
		"(String.num(float({value}) * 100.0, maxi(int({decimals}), 0)) + \"%\")", "",
		[
			F.make_param("value", "String", "0.73", "Fraction", "A fraction where 1.0 means full, e.g. health / max_health.", "expression"),
			F.make_param("decimals", "String", "0", "Decimals", "Digits after the decimal point. 0 gives a whole percent.", "expression"),
		], CAT, "[b]{value}[/b] as a percent")
		.described("Turns a fraction into percent TEXT with the sign on it: 0.73 reads \"73%\". Feed it a 0-to-1 value (Percent Of already returns 0-to-100, so divide that by 100 or use the raw fraction)."))

	d.append(F.make_descriptor("Core", "AsDuration", "As Duration", ACEDescriptor.ACEType.EXPRESSION,
		"((\"%dh %02dm\" % [int(maxf({seconds}, 0.0)) / 3600, (int(maxf({seconds}, 0.0)) % 3600) / 60]) if int(maxf({seconds}, 0.0)) >= 3600 else (\"%dm %02ds\" % [int(maxf({seconds}, 0.0)) / 60, int(maxf({seconds}, 0.0)) % 60]))", "",
		[F.make_param("seconds", "String", "3725.0", "Seconds", "A duration in seconds.", "expression")],
		CAT, "[b]{seconds}[/b] as a duration")
		.described("Seconds as a duration that survives passing an hour: 3725 reads \"1h 02m\" and 90 reads \"1m 30s\". A negative duration reads as zero. Use As Clock Time when you want strict mm:ss (it rolls an hour into \"60:00\")."))

	# ── Columns (Godot's lpad/rpad; monospace or it still drifts) ──
	d.append(F.make_descriptor("Core", "AlignLeft", "Align Left", ACEDescriptor.ACEType.EXPRESSION,
		"{text}.rpad(int({width}), {fill})", "",
		[
			_text_param("\"Name\"", "The text to pad out."),
			_width_param("16"),
			_fill_param(),
		], CAT, "[b]{text}[/b] aligned left in [b]{width}[/b]")
		.described("Pads text out on the RIGHT to a fixed width, so every row starts on the same edge and reads as a column. Text longer than the width is left alone (it is never cut - shorten it first). Give the Label a MONOSPACE theme font or the column will still drift."))

	d.append(F.make_descriptor("Core", "AlignRight", "Align Right", ACEDescriptor.ACEType.EXPRESSION,
		"{text}.lpad(int({width}), {fill})", "",
		[
			_text_param("\"1200\"", "The text to pad out - str() a number first."),
			_width_param("8"),
			_fill_param(),
		], CAT, "[b]{text}[/b] aligned right in [b]{width}[/b]")
		.described("Pads text out on the LEFT to a fixed width, so numbers END on the same edge and read as a column of figures. Text longer than the width is left alone. Give the Label a MONOSPACE theme font or the column will still drift."))

	d.append(F.make_descriptor("Core", "CenterInWidth", "Center In Width", ACEDescriptor.ACEType.EXPRESSION,
		"{text}.lpad({text}.length() + (int({width}) - {text}.length()) / 2, {fill}).rpad(int({width}), {fill})", "",
		[
			_text_param("\"TITLE\"", "The text to center."),
			_width_param("20"),
			_fill_param(),
		], CAT, "[b]{text}[/b] centered in [b]{width}[/b]")
		.described("Pads text on BOTH sides to a fixed width, so a heading sits in the middle of a column. An odd leftover space goes on the right. Text longer than the width is left alone. Give the Label a MONOSPACE theme font or the centering will still drift."))

	# ── Case that keeps word shape (Uppercase and Lowercase destroy it) ──
	d.append(F.make_descriptor("Core", "AsTitleText", "As Title Text", ACEDescriptor.ACEType.EXPRESSION,
		"{text}.capitalize()", "",
		[_text_param("\"fire_sword\"", "An id or key, e.g. fire_sword or maxHealth.")],
		CAT, "[b]{text}[/b] as title text")
		.described("Turns a machine id into a readable name: \"fire_sword\" reads \"Fire Sword\", \"maxHealth\" reads \"Max Health\". Use it wherever a key has to be shown to a player, so ids and labels never drift apart in two places."))

	d.append(F.make_descriptor("Core", "AsSentenceText", "As Sentence Text", ACEDescriptor.ACEType.EXPRESSION,
		"({text}.substr(0, 1).to_upper() + {text}.substr(1))", "",
		[_text_param("\"picked up a shield\"", "A sentence that needs its first letter raised.")],
		CAT, "[b]{text}[/b] as sentence text")
		.described("Raises the FIRST letter only and leaves the rest of the text exactly as it is, so \"NPC\" and \"HP\" keep their capitals. Empty text stays empty."))

	# ── Translated patterns: look the WHOLE sentence up first, THEN fill its slots ──
	d.append(F.make_descriptor("Core", "TranslatedTextFromPattern", "Translated Text From Pattern", ACEDescriptor.ACEType.EXPRESSION,
		"tr({pattern}).format({values})", "",
		[_pattern_param(), _values_param()],
		CAT_TRANSLATION, "translated text from [b]{pattern}[/b]")
		.described("Looks the whole sentence up in the current language FIRST, then fills its {slots}. The pattern you type here - slots and all - is the translation key, so it is what goes in the catalog. Filling the slots first (Translate around Text From Pattern) produces a string no catalog can contain, and the text then never translates."))

	d.append(F.make_descriptor("Core", "SetTextTranslatedPattern", "Set Text (translated pattern)", ACEDescriptor.ACEType.ACTION,
		"text = tr({pattern}).format({values})", "",
		[_pattern_param(), _values_param()],
		CAT_TRANSLATION, "set text to translated [b]{pattern}[/b]", "Label")
		.described("Sets this Label's text from a pattern that is translated FIRST and filled second. The pattern - slots and all - is the translation key. Re-run it under On Language Changed so the label follows a live language switch."))

	return d


## The text operand every fitting / column / case verb takes first.
static func _text_param(default_value: String, description: String) -> ACEParam:
	return F.make_param("text", "String", default_value, "Text", description, "expression")


## The character budget the Shorten verbs fit into, marker included.
static func _max_chars_param(default_value: String) -> ACEParam:
	return F.make_param("max_chars", "String", default_value, "Max characters", "The widest the result may get, in characters, counting the ending below.", "expression")


## What marks a cut. An empty ending is legal and simply trims.
static func _suffix_param() -> ACEParam:
	return F.make_param("suffix", "String", "\"...\"", "Ending", "What marks the cut, e.g. \"...\" or a single ellipsis character. Its own length is taken out of the budget.", "expression")


## The column width the alignment verbs pad to.
static func _width_param(default_value: String) -> ACEParam:
	return F.make_param("width", "String", default_value, "Width", "Column width in characters. Shorter text is padded; longer text is left as it is.", "expression")


## The padding character. One character - Godot pads with the first one only.
static func _fill_param() -> ACEParam:
	return F.make_param("fill", "String", "\" \"", "Fill with", "What fills the gap: a space, or \".\" for a dotted leader. One character.", "expression")


## The SOURCE sentence, which is also the translation key - slots included.
static func _pattern_param() -> ACEParam:
	return F.make_param("pattern", "String", "\"You have {coins} coins\"", "Pattern", "The source sentence, with {name} slots. This exact string, slots and all, is the translation key that goes in the catalog.", "expression")


## What fills the slots after the lookup.
static func _values_param() -> ACEParam:
	return F.make_param("values", "String", "{\"coins\": 0}", "Values", "What fills the slots: {\"name\": value, ...} - e.g. {\"coins\": coins}.", "expression")
