# Godot EventSheets - the display-text vocabulary (text_format_aces.gd).
#
# Twelve stateless verbs that turn a value into something a Label can show: two that FIT text into a
# width and mark the cut, three that make NUMBERS readable, three that pad text into COLUMNS, two that
# fix CASE without destroying word shape, and two that translate a pattern BEFORE filling its slots.
#
# Every verb is pinned twice, because either pin alone is a lie:
#   1. EMISSION - the row is compiled through the real SheetCompiler and the emitted GDScript line is
#      asserted exactly (for the Label-scoped action, in its POST node-scope form, `{target.}` and all).
#   2. RUNTIME - the SHIPPED template is substituted through the real ActionCodegen, built into a
#      script, reload()ed and RUN, including the edge cases each verb's description promises: empty
#      text, a budget with no space in it, a negative duration, text wider than its column, and the
#      translation catalog actually being hit (plus the wrong order explicitly NOT hitting it).
@tool
class_name TextFormatACEsTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true
	ok = _test_registry_shape() and ok
	ok = _test_emitted_expressions() and ok
	ok = _test_emitted_label_action() and ok
	ok = _test_shorten_runtime() and ok
	ok = _test_readable_numbers_runtime() and ok
	ok = _test_columns_runtime() and ok
	ok = _test_case_runtime() and ok
	ok = _test_translated_pattern_runtime() and ok
	return ok


## All twelve register, under the categories the picker already has icons for, with the right kinds.
static func _test_registry_shape() -> bool:
	var ok: bool = true
	var text_ids: Array[String] = ["ShortenToFit", "ShortenToWholeWords", "WithThousandsSeparators",
		"AsPercentText", "AsDuration", "AlignLeft", "AlignRight", "CenterInWidth",
		"AsTitleText", "AsSentenceText"]
	for ace_id: String in text_ids:
		var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
		ok = _check("%s is registered" % ace_id, descriptor != null, true) and ok
		if descriptor == null:
			continue
		ok = _check("%s sits in the Text category" % ace_id, str(descriptor.category), "Text") and ok
		ok = _check("%s is an expression" % ace_id, descriptor.ace_type, ACEDescriptor.ACEType.EXPRESSION) and ok
		ok = _check("%s carries hover help" % ace_id, str(descriptor.description).is_empty(), false) and ok
	var translated: ACEDescriptor = ACERegistry.find_descriptor("Core", "TranslatedTextFromPattern")
	ok = _check("Translated Text From Pattern is a Translation expression",
		str(translated.category) + "/" + str(translated.ace_type), "Translation/3") and ok
	ok = _check("it looks the sentence up FIRST and fills second",
		str(translated.codegen_template), "tr({pattern}).format({values})") and ok
	var set_text: ACEDescriptor = ACERegistry.find_descriptor("Core", "SetTextTranslatedPattern")
	ok = _check("Set Text (translated pattern) is a Label-scoped action",
		str(set_text.node_type) + "/" + str(set_text.ace_type), "Label/2") and ok
	# The documented trap: the SHIPPED template is not the authored one - the registry prefixes every
	# node-scoped line with {target.} and appends the optional "On node" param.
	ok = _check("the shipped Label template carries the cross-node prefix",
		str(set_text.codegen_template), "{target.}text = tr({pattern}).format({values})") and ok
	ok = _check("and the appended target param is the last one",
		str((set_text.params[set_text.params.size() - 1] as ACEParam).id), "target") and ok
	return ok


## Ten expression rows, each dropped at its shipped DEFAULTS into a Set Variable action and compiled
## through the real SheetCompiler. What is asserted is the emitted GDScript line, verbatim.
static func _test_emitted_expressions() -> bool:
	var expected: Dictionary = {
		# Both fitting verbs carry a final `if budget > 0 else <hard cut>` arm: a width too narrow to
		# hold the ending cuts the TEXT rather than returning the ending on its own (which would have
		# been both wider than the stated width and the one outcome the whole-words help rules out).
		"ShortenToFit": "\tlabel_text = (\"Ancient Sword of Thorns\" if \"Ancient Sword of Thorns\".length() <= int(14) else (\"Ancient Sword of Thorns\".left(maxi(int(14) - \"...\".length(), 0)).strip_edges() + \"...\" if maxi(int(14) - \"...\".length(), 0) > 0 else \"Ancient Sword of Thorns\".left(maxi(int(14), 0))))",
		"ShortenToWholeWords": "\tlabel_text = (\"Ancient Sword of Thorns\" if \"Ancient Sword of Thorns\".length() <= int(20) else ((\"Ancient Sword of Thorns\".left(maxi(int(20) - \"...\".length(), 0) + 1).rsplit(\" \", true, 1)[0].strip_edges() + \"...\") if (maxi(int(20) - \"...\".length(), 0) > 0 and \"Ancient Sword of Thorns\".left(maxi(int(20) - \"...\".length(), 0) + 1).contains(\" \") and not \"Ancient Sword of Thorns\".left(maxi(int(20) - \"...\".length(), 0) + 1).rsplit(\" \", true, 1)[0].strip_edges().is_empty()) else (\"Ancient Sword of Thorns\".left(maxi(int(20) - \"...\".length(), 0)).strip_edges() + \"...\" if maxi(int(20) - \"...\".length(), 0) > 0 else \"Ancient Sword of Thorns\".left(maxi(int(20), 0)))))",
		"WithThousandsSeparators": "\tlabel_text = ((\"-\" if float(1234567) < 0.0 else \"\") + RegEx.create_from_string(\"(\\\\d)(?=(\\\\d\\\\d\\\\d)+$)\").sub(str(absi(int(1234567))), \"$1,\", true))",
		"AsPercentText": "\tlabel_text = (String.num(float(0.73) * 100.0, maxi(int(0), 0)) + \"%\")",
		"AsDuration": "\tlabel_text = ((\"%dh %02dm\" % [int(maxf(3725.0, 0.0)) / 3600, (int(maxf(3725.0, 0.0)) % 3600) / 60]) if int(maxf(3725.0, 0.0)) >= 3600 else (\"%dm %02ds\" % [int(maxf(3725.0, 0.0)) / 60, int(maxf(3725.0, 0.0)) % 60]))",
		"AlignLeft": "\tlabel_text = \"Name\".rpad(int(16), \" \")",
		"AlignRight": "\tlabel_text = \"1200\".lpad(int(8), \" \")",
		"CenterInWidth": "\tlabel_text = \"TITLE\".lpad(\"TITLE\".length() + (int(20) - \"TITLE\".length()) / 2, \" \").rpad(int(20), \" \")",
		"AsTitleText": "\tlabel_text = \"fire_sword\".capitalize()",
		"AsSentenceText": "\tlabel_text = (\"picked up a shield\".substr(0, 1).to_upper() + \"picked up a shield\".substr(1))",
		"TranslatedTextFromPattern": "\tlabel_text = tr(\"You have {coins} coins\").format({\"coins\": 0})",
	}
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.events.append(_variable("label_text", "String", ""))
	for ace_id: String in expected:
		var row: EventRow = EventRow.new()
		row.trigger_provider_id = "Core"
		row.trigger_id = "OnReady"
		row.actions.append(_set_var_action("label_text", _baked(ace_id, {})))
		sheet.events.append(row)
	var output: String = _compile(sheet, "user://text_format_expressions.gd")
	var ok: bool = true
	for ace_id: String in expected:
		ok = _check("%s emits its line verbatim" % ace_id, output.contains(str(expected[ace_id])), true) and ok
	# Nothing may reach the emitted file with an unfilled slot in it.
	ok = _check("no template placeholder survives into the emitted script", output.contains("{text}"), false) and ok
	ok = _check("the emitted script parses", _reload_source(output) != null, true) and ok
	return ok


## The Label-scoped action, dropped at its defaults on a Label sheet: the target is blank, so it
## compiles to the plain host assignment, byte-for-byte as if the cross-node param never existed.
static func _test_emitted_label_action() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Label"
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnReady"
	row.actions.append(_defaults_action("SetTextTranslatedPattern"))
	sheet.events.append(row)
	var output: String = _compile(sheet, "user://text_format_label_action.gd")
	var ok: bool = _check("Set Text (translated pattern) emits the translate-then-fill assignment",
		output.contains("\ttext = tr(\"You have {coins} coins\").format({\"coins\": 0})"), true)
	ok = _check("a blank On node target leaves no stray dot", output.contains(".text = "), false) and ok
	var label: Node = _instantiate(output, "Label")
	if label == null:
		return _check("the compiled Label sheet instantiates", false, true) and ok
	label.call("_ready")
	ok = _check("running it fills the Label's own text", str(label.get("text")), "You have 0 coins") and ok
	label.free()
	return ok


## Both Shorten verbs, run for real - including the two cases a hand-rolled truncation gets wrong.
static func _test_shorten_runtime() -> bool:
	var source: String = "\n".join([
		"@tool",
		"extends RefCounted",
		"func fit(text: String, max_chars: int, suffix: String) -> String:",
		"\treturn %s" % _baked("ShortenToFit", {"text": "text", "max_chars": "max_chars", "suffix": "suffix"}),
		"func words(text: String, max_chars: int, suffix: String) -> String:",
		"\treturn %s" % _baked("ShortenToWholeWords", {"text": "text", "max_chars": "max_chars", "suffix": "suffix"}),
		"",
	])
	var script: GDScript = _reload_source(source)
	if script == null:
		return _check("the Shorten templates build a script that parses", false, true)
	var inst: RefCounted = script.new()
	var ok: bool = _check("text that already fits comes back untouched",
		str(inst.call("fit", "Short", 14, "...")), "Short")
	ok = _check("text exactly at the limit is untouched",
		str(inst.call("fit", "Exactly14chars", 14, "...")), "Exactly14chars") and ok
	ok = _check("empty text stays empty", str(inst.call("fit", "", 14, "...")), "") and ok
	ok = _check("a long name is cut and MARKED",
		str(inst.call("fit", "Ancient Sword of Thorns", 14, "...")), "Ancient Swo...") and ok
	ok = _check("the marked result never exceeds the budget",
		str(inst.call("fit", "Ancient Sword of Thorns", 14, "...")).length(), 14) and ok
	# A width at or under the marker's own length: marking the cut is impossible there, because the
	# marker alone would BE the result AND would still overrun the stated width. The text wins - a
	# hard cut to max_chars, no marker. Both verbs used to answer a bare "..." here: three characters
	# for a two-character maximum, an overflow for any caller that sized a column from max_chars, and
	# the exact outcome Shorten To Whole Words promises cannot happen.
	ok = _check("a budget narrower than the marker cuts the text instead of returning the marker",
		str(inst.call("fit", "Ancient Sword of Thorns", 2, "...")), "An") and ok
	ok = _check("and never runs past the width it was given",
		str(inst.call("fit", "Ancient Sword of Thorns", 2, "...")).length() <= 2, true) and ok
	ok = _check("a budget exactly the marker's length is the same case",
		str(inst.call("fit", "Ancient Sword", 3, "...")), "Anc") and ok
	ok = _check("a zero width is empty text, not a marker",
		str(inst.call("fit", "Ancient Sword", 0, "...")), "") and ok
	ok = _check("a negative width cannot produce a negative-length cut",
		str(inst.call("fit", "Ancient Sword", -5, "...")), "") and ok
	ok = _check("an empty ending simply trims with no marker",
		str(inst.call("fit", "Ancient Sword of Thorns", 7, "")), "Ancient") and ok
	# Whole words: back up to the last complete word.
	ok = _check("whole words backs up to a word boundary",
		str(inst.call("words", "Ancient Sword of Thorns", 16, "...")), "Ancient Sword...") and ok
	ok = _check("a word that ends exactly on the budget is kept whole",
		str(inst.call("words", "Ancient Sword of Thorns", 20, "...")), "Ancient Sword of...") and ok
	ok = _check("a tighter budget drops the partial word",
		str(inst.call("words", "Ancient Sword of Thorns", 14, "...")), "Ancient...") and ok
	ok = _check("whole words never exceeds the budget either",
		str(inst.call("words", "Ancient Sword of Thorns", 16, "...")).length() <= 16, true) and ok
	# THE promised edge: one very long word means there is no space to back up to. Falling back to the
	# character form is what keeps this from returning a bare "...".
	ok = _check("a budget holding no space at all falls back to the character form",
		str(inst.call("words", "Supercalifragilistic", 10, "...")), "Superca...") and ok
	ok = _check("so it is never just the marker",
		str(inst.call("words", "Supercalifragilistic", 10, "...")) == "...", false) and ok
	ok = _check("whole words leaves empty text empty", str(inst.call("words", "", 14, "...")), "") and ok
	ok = _check("whole words leaves fitting text untouched",
		str(inst.call("words", "Short", 14, "...")), "Short") and ok
	# The same degenerate widths on the whole-words form, which is the one whose help says out loud
	# that the result is never just the ending - so it is the one that has to prove it.
	ok = _check("whole words with a budget under the marker cuts the text too",
		str(inst.call("words", "Ancient Sword of Thorns", 2, "...")), "An") and ok
	ok = _check("and stays inside the width",
		str(inst.call("words", "Ancient Sword of Thorns", 2, "...")).length() <= 2, true) and ok
	ok = _check("so it is never just the marker at ANY width",
		str(inst.call("words", "Ancient Sword of Thorns", 2, "...")) == "...", false) and ok
	# The other degenerate window: the only space in the budget is its FIRST character, so backing up
	# to a word boundary leaves nothing before it. Cutting by characters is what saves it from
	# returning the bare marker again.
	ok = _check("a window whose only space leads it falls back to the character form",
		str(inst.call("words", " Supercalifragilistic", 5, "...")), "S...") and ok
	ok = _check("which is still not the marker alone",
		str(inst.call("words", " Supercalifragilistic", 5, "...")) == "...", false) and ok
	return ok


## Separators, percent text and durations, run for real.
static func _test_readable_numbers_runtime() -> bool:
	var source: String = "\n".join([
		"@tool",
		"extends RefCounted",
		"func commas(value: float) -> String:",
		"\treturn %s" % _baked("WithThousandsSeparators", {"value": "value"}),
		"func percent(value: float, decimals: int) -> String:",
		"\treturn %s" % _baked("AsPercentText", {"value": "value", "decimals": "decimals"}),
		"func duration(seconds: float) -> String:",
		"\treturn %s" % _baked("AsDuration", {"seconds": "seconds"}),
		"",
	])
	var script: GDScript = _reload_source(source)
	if script == null:
		return _check("the number templates build a script that parses", false, true)
	var inst: RefCounted = script.new()
	var ok: bool = _check("a seven-digit score groups into threes", str(inst.call("commas", 1234567.0)), "1,234,567")
	ok = _check("a four-digit number gets one separator", str(inst.call("commas", 1000.0)), "1,000") and ok
	ok = _check("three digits get none", str(inst.call("commas", 999.0)), "999") and ok
	ok = _check("zero reads as zero", str(inst.call("commas", 0.0)), "0") and ok
	ok = _check("a negative keeps its minus sign", str(inst.call("commas", -1234567.0)), "-1,234,567") and ok
	ok = _check("the fraction is dropped, not rounded up", str(inst.call("commas", 1234.99)), "1,234") and ok
	ok = _check("a fraction reads as a whole percent", str(inst.call("percent", 0.73, 0)), "73%") and ok
	ok = _check("decimals are honoured", str(inst.call("percent", 0.5, 1)), "50.0%") and ok
	ok = _check("empty reads as 0%", str(inst.call("percent", 0.0, 0)), "0%") and ok
	ok = _check("full reads as 100%", str(inst.call("percent", 1.0, 0)), "100%") and ok
	ok = _check("past an hour reads in hours and minutes", str(inst.call("duration", 3725.0)), "1h 02m") and ok
	ok = _check("a round hour keeps the padded minutes", str(inst.call("duration", 3600.0)), "1h 00m") and ok
	ok = _check("under an hour reads in minutes and seconds", str(inst.call("duration", 90.0)), "1m 30s") and ok
	ok = _check("under a minute still names the minute", str(inst.call("duration", 59.0)), "0m 59s") and ok
	ok = _check("a negative duration clamps to zero", str(inst.call("duration", -30.0)), "0m 00s") and ok
	return ok


## The three column verbs, run for real - including text WIDER than its column.
static func _test_columns_runtime() -> bool:
	var source: String = "\n".join([
		"@tool",
		"extends RefCounted",
		"func left(text: String, width: int, fill: String) -> String:",
		"\treturn %s" % _baked("AlignLeft", {"text": "text", "width": "width", "fill": "fill"}),
		"func right(text: String, width: int, fill: String) -> String:",
		"\treturn %s" % _baked("AlignRight", {"text": "text", "width": "width", "fill": "fill"}),
		"func center(text: String, width: int, fill: String) -> String:",
		"\treturn %s" % _baked("CenterInWidth", {"text": "text", "width": "width", "fill": "fill"}),
		"",
	])
	var script: GDScript = _reload_source(source)
	if script == null:
		return _check("the column templates build a script that parses", false, true)
	var inst: RefCounted = script.new()
	var ok: bool = _check("align left keeps the text at the start", str(inst.call("left", "Name", 8, " ")), "Name    ")
	ok = _check("align right ends the text on the column edge", str(inst.call("right", "1200", 8, " ")), "    1200") and ok
	ok = _check("a dot leader fills the gap", str(inst.call("right", "1200", 8, ".")), "....1200") and ok
	# The whole point: two rows of different lengths end up the same width.
	ok = _check("two names of different lengths pad to the same width",
		str(inst.call("left", "Al", 8, " ")).length() == str(inst.call("left", "Alexa", 8, " ")).length(), true) and ok
	ok = _check("text wider than the column is left alone, never cut",
		str(inst.call("left", "Alexandra", 8, " ")), "Alexandra") and ok
	ok = _check("align right leaves wide text alone too",
		str(inst.call("right", "123456789", 8, " ")), "123456789") and ok
	ok = _check("empty text pads to the full width", str(inst.call("left", "", 4, " ")), "    ") and ok
	ok = _check("centering splits the padding", str(inst.call("center", "Hi", 6, " ")), "  Hi  ") and ok
	ok = _check("an odd leftover goes on the right", str(inst.call("center", "Hi", 7, " ")), "  Hi   ") and ok
	ok = _check("centering fills to the exact width", str(inst.call("center", "TITLE", 20, " ")).length(), 20) and ok
	ok = _check("centering leaves wide text alone", str(inst.call("center", "TooLongForThis", 6, " ")), "TooLongForThis") and ok
	return ok


## Title case and sentence case, run for real - including the capitals that must SURVIVE.
static func _test_case_runtime() -> bool:
	var source: String = "\n".join([
		"@tool",
		"extends RefCounted",
		"func title(text: String) -> String:",
		"\treturn %s" % _baked("AsTitleText", {"text": "text"}),
		"func sentence(text: String) -> String:",
		"\treturn %s" % _baked("AsSentenceText", {"text": "text"}),
		"",
	])
	var script: GDScript = _reload_source(source)
	if script == null:
		return _check("the case templates build a script that parses", false, true)
	var inst: RefCounted = script.new()
	var ok: bool = _check("a snake_case id becomes a readable name", str(inst.call("title", "fire_sword")), "Fire Sword")
	ok = _check("a camelCase key splits into words", str(inst.call("title", "maxHealth")), "Max Health") and ok
	ok = _check("title case leaves empty text empty", str(inst.call("title", "")), "") and ok
	ok = _check("sentence case raises only the first letter",
		str(inst.call("sentence", "picked up a shield")), "Picked up a shield") and ok
	ok = _check("an existing acronym keeps its capitals",
		str(inst.call("sentence", "NPC waved at you")), "NPC waved at you") and ok
	ok = _check("a mid-sentence acronym is untouched",
		str(inst.call("sentence", "your HP is low")), "Your HP is low") and ok
	ok = _check("sentence case leaves empty text empty", str(inst.call("sentence", "")), "") and ok
	return ok


## The order that actually works, proven against a REAL catalog: the pattern (slots and all) is the
## key, so the lookup hits; filling the slots first produces a string the catalog cannot hold, and is
## asserted to come back untranslated. That failure is the whole reason this verb exists.
static func _test_translated_pattern_runtime() -> bool:
	var source: String = "\n".join([
		"@tool",
		"extends RefCounted",
		"func translated(pattern: String, values: Dictionary) -> String:",
		"\treturn %s" % _baked("TranslatedTextFromPattern", {"pattern": "pattern", "values": "values"}),
		"func filled_first(pattern: String, values: Dictionary) -> String:",
		"\treturn tr(pattern.format(values))",
		"",
	])
	var script: GDScript = _reload_source(source)
	if script == null:
		return _check("the translated-pattern template builds a script that parses", false, true)
	var inst: RefCounted = script.new()
	var pattern: String = "You have {coins} coins"
	var ok: bool = _check("with no catalog it still fills the slots",
		str(inst.call("translated", pattern, {"coins": 7})), "You have 7 coins")
	# Register a catalog for the CURRENT locale, so nothing global has to be switched (and restored).
	var catalog: Translation = Translation.new()
	catalog.locale = TranslationServer.get_locale()
	catalog.add_message(pattern, "Vi havas {coins} monerojn")
	TranslationServer.add_translation(catalog)
	ok = _check("the pattern itself is the translation key, so the lookup HITS",
		str(inst.call("translated", pattern, {"coins": 7})), "Vi havas 7 monerojn") and ok
	ok = _check("filling the slots first looks up a string no catalog holds, so it stays untranslated",
		str(inst.call("filled_first", pattern, {"coins": 7})), "You have 7 coins") and ok
	TranslationServer.remove_translation(catalog)
	ok = _check("the catalog is removed again, so the lookup stops hitting",
		str(inst.call("translated", pattern, {"coins": 7})), "You have 7 coins") and ok
	return ok


## The shipped descriptor's template with its DEFAULTS baked in, then any overrides applied - the
## same single-pass substitution the dock performs the moment a row is applied.
static func _baked(ace_id: String, overrides: Dictionary) -> String:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	if descriptor == null:
		return ""
	var values: Dictionary = {}
	for parameter: ACEParam in descriptor.params:
		values[parameter.id] = str(parameter.default_value)
	for key: Variant in overrides:
		values[str(key)] = str(overrides[key])
	return ActionCodegen._apply_template(str(descriptor.codegen_template), values)


## An action row carrying the REAL descriptor's template with every param at its shipped default.
static func _defaults_action(ace_id: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.codegen_template = _baked(ace_id, {})
	return action


## A Set Variable row whose value is the already-baked expression - how an expression reaches a sheet.
static func _set_var_action(variable_name: String, expression: String) -> ACEAction:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", "SetVar")
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "SetVar"
	action.codegen_template = ActionCodegen._apply_template(str(descriptor.codegen_template),
		{"var_name": variable_name, "value": expression})
	return action


static func _variable(variable_name: String, type_name: String, default_value: Variant) -> LocalVariable:
	var variable: LocalVariable = LocalVariable.new()
	variable.name = variable_name
	variable.type_name = type_name
	variable.default_value = default_value
	return variable


static func _compile(sheet: EventSheetResource, path: String) -> String:
	return str(SheetCompiler.compile(sheet, path).get("output", ""))


static func _reload_source(source: String) -> GDScript:
	var script: GDScript = GDScript.new()
	script.source_code = source
	if script.reload() != OK:
		print("  source failed to reload:\n%s" % source)
		return null
	return script


static func _instantiate(source: String, host_class: String) -> Node:
	var script: GDScript = _reload_source(source)
	if script == null:
		return null
	var node: Node = ClassDB.instantiate(host_class)
	node.set_script(script)
	return node


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] text_format_aces_test: %s" % label)
		return true
	print("[FAIL] text_format_aces_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
