# Godot EventSheets - translation coverage as vocabulary, and the two localisation Doctor checks.
#
# Three things ship here and each one is proved twice - the emitted code is pinned AND the behaviour
# is run for real, because an emission pin alone cannot tell a correct expression from a plausible one:
#
#   1. Translation Coverage / Missing Translation Keys / Translation Is Complete
#      (addons/eventforge/registration/modules/translation_quality_aces.gd). Every catalog case is a
#      real .csv written to user:// and read by the REAL emitted expression, compiled and run: a
#      partly filled language, a language with no column at all, a whitespace-only cell, an RTL cell,
#      cells quoting the separator, CRLF line endings, a semicolon catalog, a header-only file and a
#      file that is not there. The missing-file answer is the edge the verb exists for - it must read
#      0 and NOT complete, so a mistyped path fails an export gate loudly instead of passing it.
#
#   2. l10n-unmarked (project_doctor.check_unmarked_player_text). NOT CRYING WOLF IS THE FEATURE, so
#      the clean cases outnumber the accusations here on purpose: a group name, an animation name, a
#      node path, a print message, a number, a clock placeholder, a format-only string, a private
#      `var text` declaration, a comparison, a multi-line literal, a line already using tr(), and a
#      string the project already marks somewhere all have to come back silent. The accusations are
#      driven through the REAL compiler, so the sink patterns are matched against what the plugin
#      actually emits rather than against a hand-typed guess at it.
#
#   3. l10n-stale-label (project_doctor.check_stale_translated_labels). Same discipline, plus the one
#      test that matters most: compiling the sheet WITH the On Language Changed event the finding
#      recommends must produce no finding, so the check can never accuse its own fix.
#
# The engine claims underneath were verified against Godot 4.7 rather than assumed, and the stale
# half is re-proved here at runtime through the real TranslationServer: a value tr() returned does
# NOT follow a later locale switch, which is exactly why an event-filled label goes stale.
@tool
class_name TranslationQualityTest
extends RefCounted

const CATALOG_MAIN := "user://translation_quality_main.csv"
const CATALOG_QUOTED := "user://translation_quality_quoted.csv"
const CATALOG_SEMICOLON := "user://translation_quality_semicolon.csv"
const CATALOG_HEADER_ONLY := "user://translation_quality_header_only.csv"
const CATALOG_ABSENT := "user://translation_quality_absent.csv"

const TRANSLATIONS_SETTING := "internationalization/locale/translations"


static func run() -> bool:
	var ok: bool = true
	ok = _test_descriptors() and ok
	ok = _test_coverage_runtime() and ok
	ok = _test_missing_keys_runtime() and ok
	ok = _test_is_complete_runtime() and ok
	ok = _test_parse_policy_runtime() and ok
	ok = _test_export_gate_compiles() and ok
	ok = _test_unmarked_on_emitted_code() and ok
	ok = _test_unmarked_clean_cases() and ok
	ok = _test_unmarked_accusations() and ok
	ok = _test_stale_on_emitted_code() and ok
	ok = _test_stale_clean_cases() and ok
	ok = _test_stale_bug_is_real() and ok
	ok = _test_doctor_gate() and ok
	ok = _test_local_text_variable_is_not_a_label() and ok
	ok = _test_comment_markers_do_not_silence_the_check() and ok
	ok = _test_only_real_catalogs_are_an_allowlist() and ok
	_cleanup()
	return ok


## A local called `text` is not a Control. `var text := ""` then `text = "Report for the day"` is an
## ordinary string being built, and the receiver-less write looks exactly like a host property write
## - so the DECLARATION has to be what tells them apart. Accusing this shape is the false accusation
## the check's own contract says is impossible.
static func _test_local_text_variable_is_not_a_label() -> bool:
	var building: String = "extends Node\n\n\nfunc build_report() -> String:\n\tvar text: String = \"\"\n\ttext = \"Report for the day\"\n\treturn text\n"
	var ok: bool = _check("a local named text being filled is not player text",
		",".join(EventSheetProjectDoctor.unmarked_player_text(building)), "")
	var parameter: String = "extends Node\n\n\nfunc log_line(text: String) -> void:\n\ttext = \"Report for the day\"\n\tprint(text)\n"
	ok = _check("nor is a parameter of that name",
		",".join(EventSheetProjectDoctor.unmarked_player_text(parameter)), "") and ok
	# The same script still gets judged on a REAL label write, so the narrowing costs no coverage.
	var mixed: String = "extends Node\n\n\nfunc show() -> void:\n\tvar text: String = \"\"\n\ttext = \"internal\"\n\t$Title.text = \"Press any key\"\n"
	ok = _check("...and a real label write in the same script is still judged",
		",".join(EventSheetProjectDoctor.unmarked_player_text(mixed)), "Press any key") and ok
	# And the stale check reads the same rule, so it cannot go stale-blind on the same shape.
	var stale_local: String = "extends Node\n\n\nfunc build() -> String:\n\tvar text: String = \"\"\n\ttext = tr(\"HELLO\")\n\treturn text\n"
	ok = _check("a local filled from tr() is not a label going stale either",
		",".join(EventSheetProjectDoctor.stale_translated_text_functions(stale_local)), "") and ok
	return ok


## A COMMENT is not a language-changed handler. Testing the refresh markers against the raw source
## let one TODO ("handle language_changed one day") switch the whole check off for the script - and a
## project mid-localisation is exactly where that comment gets written.
static func _test_comment_markers_do_not_silence_the_check() -> bool:
	var stale: String = "extends Node\n\n\nfunc _ready() -> void:\n\t$Label.text = tr(\"HELLO\")\n"
	var ok: bool = _check("the bare stale shape is named", ",".join(EventSheetProjectDoctor.stale_translated_text_functions(stale)), "_ready")
	var commented: String = "extends Node\n\n\nfunc _ready() -> void:\n\t# emitted for a language_changed refresh later\n\t$Label.text = tr(\"HELLO\")\n"
	ok = _check("a comment promising a refresh does not count as one",
		",".join(EventSheetProjectDoctor.stale_translated_text_functions(commented)), "_ready") and ok
	var real_handler: String = "extends Node\n\n\nfunc _ready() -> void:\n\t$Label.text = tr(\"HELLO\")\n\n\nfunc _notification(what: int) -> void:\n\tif what == NOTIFICATION_TRANSLATION_CHANGED:\n\t\t_ready()\n"
	ok = _check("...while the real handler still silences it",
		",".join(EventSheetProjectDoctor.stale_translated_text_functions(real_handler)), "") and ok
	return ok


## The allowlist must be a CATALOG, not any spreadsheet. Godot's translation CSV names a language in
## every column after the first; a designer's balance grid does not. Without that gate the first
## column of every .csv in the project silences a real finding for every title it holds - including
## the grid files this plugin's own "Export Grid to CSV…" writes.
static func _test_only_real_catalogs_are_an_allowlist() -> bool:
	var ok: bool = _check("a translation catalog header is recognised",
		EventSheetProjectDoctor._is_catalog_header(PackedStringArray(["keys", "en", "fr"])), true)
	ok = _check("...including one whose first column is named something else",
		EventSheetProjectDoctor._is_catalog_header(PackedStringArray(["id", "de"])), true) and ok
	ok = _check("...and the pseudo column counts as a language",
		EventSheetProjectDoctor._is_catalog_header(PackedStringArray(["keys", "qps"])), true) and ok
	ok = _check("a designer's balance grid is not a catalog",
		EventSheetProjectDoctor._is_catalog_header(PackedStringArray(["title", "price", "weight"])), false) and ok
	ok = _check("nor is a single-column file",
		EventSheetProjectDoctor._is_catalog_header(PackedStringArray(["title"])), false) and ok
	ok = _check("nor an empty header", EventSheetProjectDoctor._is_catalog_header(PackedStringArray()), false) and ok
	return ok


## ── The three descriptors as they ship ──────────────────────────────────────────────────────────
static func _test_descriptors() -> bool:
	var ok: bool = true
	for ace_id: String in ["TranslationCoverage", "MissingTranslationKeys", "TranslationIsComplete"]:
		ok = _check("%s is registered" % ace_id, ACERegistry.find_descriptor("Core", ace_id) != null, true) and ok
	var coverage: ACEDescriptor = ACERegistry.find_descriptor("Core", "TranslationCoverage")
	var missing: ACEDescriptor = ACERegistry.find_descriptor("Core", "MissingTranslationKeys")
	var complete: ACEDescriptor = ACERegistry.find_descriptor("Core", "TranslationIsComplete")
	if coverage == null or missing == null or complete == null:
		return false
	ok = _check("Translation Coverage reads as a name", str(coverage.display_name), "Translation Coverage") and ok
	ok = _check("Missing Translation Keys reads as a name", str(missing.display_name), "Missing Translation Keys") and ok
	ok = _check("Translation Is Complete reads as a name", str(complete.display_name), "Translation Is Complete") and ok
	ok = _check("coverage groups under Translation", str(coverage.category), "Translation") and ok
	ok = _check("the missing list groups under Translation", str(missing.category), "Translation") and ok
	ok = _check("the gate groups under Translation", str(complete.category), "Translation") and ok
	ok = _check("coverage is an expression", int(coverage.ace_type), int(ACEDescriptor.ACEType.EXPRESSION)) and ok
	ok = _check("the missing list is an expression", int(missing.ace_type), int(ACEDescriptor.ACEType.EXPRESSION)) and ok
	ok = _check("the gate is a condition", int(complete.ace_type), int(ACEDescriptor.ACEType.CONDITION)) and ok
	ok = _check("the language param defaults to a literal", _param_default(coverage, "locale"), "\"fr\"") and ok
	ok = _check("the catalog param defaults to a literal path", _param_default(coverage, "path"), "\"res://i18n/strings.csv\"") and ok
	ok = _check("the separator param defaults to a quoted comma", _param_default(coverage, "separator"), "\",\"") and ok
	ok = _check("the separator picker offers Comma first", _first_option_label(coverage, "separator"), "Comma") and ok
	# The parity covenant: no plugin reference may reach the emitted line.
	for descriptor: ACEDescriptor in [coverage, missing, complete]:
		ok = _check("%s emits no plugin reference" % str(descriptor.ace_id),
			str(descriptor.codegen_template).contains("EventSheet") or str(descriptor.codegen_template).contains("EventForge"), false) and ok
		ok = _check("%s leaves no unbaked uid" % str(descriptor.ace_id),
			str(descriptor.codegen_template).contains("{uid}"), false) and ok
	return ok


## ── Coverage, run for real over real files ──────────────────────────────────────────────────────
static func _test_coverage_runtime() -> bool:
	_write_catalogs()
	var runtime: Object = _runtime()
	if runtime == null:
		return _check("the coverage expressions compile", false, true)
	var ok: bool = true
	ok = _check("a fully filled language reads 100", runtime.call("coverage", "en", CATALOG_MAIN), 100.0) and ok
	ok = _check("a half filled language reads 50", runtime.call("coverage", "fr", CATALOG_MAIN), 50.0) and ok
	ok = _check("one filled cell of four reads 25", runtime.call("coverage", "de", CATALOG_MAIN), 25.0) and ok
	# An RTL cell is a FILLED cell: the check is emptiness, never script or direction.
	ok = _check("an Arabic cell counts as filled", runtime.call("coverage", "ar", CATALOG_MAIN), 25.0) and ok
	# A language with no column at all is the commonest typo, and it must read 0 - never 100.
	ok = _check("a language with no column reads 0", runtime.call("coverage", "zz", CATALOG_MAIN), 0.0) and ok
	# THE EDGE THE VERB EXISTS FOR: a mistyped path must fail a gate, not pass it.
	ok = _check("a catalog that is not there reads 0", runtime.call("coverage", "fr", CATALOG_ABSENT), 0.0) and ok
	ok = _check("a header-only catalog reads 0", runtime.call("coverage", "fr", CATALOG_HEADER_ONLY), 0.0) and ok
	# The trailing ",,,," line a spreadsheet export leaves behind must not drag a language down: with
	# that row counted, "fr" would read 40 instead of 50.
	ok = _check("a blank trailing row is not a translatable unit", runtime.call("coverage", "fr", CATALOG_MAIN), 50.0) and ok
	return ok


static func _test_missing_keys_runtime() -> bool:
	var runtime: Object = _runtime()
	if runtime == null:
		return _check("the missing-keys expression compiles", false, true)
	var ok: bool = true
	ok = _check("the missing list names the unfilled source strings",
		",".join(PackedStringArray(runtime.call("missing", "fr", CATALOG_MAIN))), "HELLO,BACK") and ok
	ok = _check("a finished language has nothing missing",
		",".join(PackedStringArray(runtime.call("missing", "en", CATALOG_MAIN))), "") and ok
	ok = _check("a language with no column is missing everything",
		",".join(PackedStringArray(runtime.call("missing", "zz", CATALOG_MAIN))), "PLAY,QUIT,HELLO,BACK") and ok
	# A catalog with no rows has no keys to name - the gate below is what catches that case, and the
	# empty list is the honest answer rather than an invented one.
	ok = _check("a catalog that is not there names nothing",
		",".join(PackedStringArray(runtime.call("missing", "fr", CATALOG_ABSENT))), "") and ok
	return ok


static func _test_is_complete_runtime() -> bool:
	var runtime: Object = _runtime()
	if runtime == null:
		return _check("the gate expression compiles", false, true)
	var ok: bool = true
	ok = _check("a fully filled language is complete", runtime.call("complete", "en", CATALOG_MAIN), true) and ok
	ok = _check("a half filled language is not complete", runtime.call("complete", "fr", CATALOG_MAIN), false) and ok
	ok = _check("a language with no column is not complete", runtime.call("complete", "zz", CATALOG_MAIN), false) and ok
	# An empty catalog is never "vacuously complete" - that convention would ship a typo.
	ok = _check("a catalog that is not there is not complete", runtime.call("complete", "fr", CATALOG_ABSENT), false) and ok
	ok = _check("a header-only catalog is not complete", runtime.call("complete", "fr", CATALOG_HEADER_ONLY), false) and ok
	return ok


## The parse policy is inherited from Table From File rather than re-invented, so the cases that
## policy exists for have to survive the trip: a quoted cell holding the separator, a doubled "" inside
## one, CRLF endings, whitespace that is not a translation, and a semicolon catalog.
static func _test_parse_policy_runtime() -> bool:
	var runtime: Object = _runtime()
	if runtime == null:
		return _check("the parse-policy expressions compile", false, true)
	var ok: bool = true
	ok = _check("quoted cells holding a comma still count as filled and as two of three rows",
		runtime.call("coverage", "fr", CATALOG_QUOTED), 200.0 / 3.0) and ok
	ok = _check("a cell holding only spaces is not a translation",
		",".join(PackedStringArray(runtime.call("missing", "fr", CATALOG_QUOTED))), "SPACED") and ok
	# CRLF endings and the quoted separator together: the source strings must arrive whole.
	ok = _check("the source strings survive quoting and CRLF",
		",".join(PackedStringArray(runtime.call("missing", "de", CATALOG_QUOTED))), "GREET,SAY,SPACED") and ok
	ok = _check("a semicolon catalog reads with the semicolon picked",
		runtime.call("coverage_semicolon", "fr", CATALOG_SEMICOLON), 50.0) and ok
	# The wrong separator collapses every line into one column, which reads as 0 rather than as
	# finished - the safe direction again.
	ok = _check("a semicolon catalog read as commas reads 0, not 100",
		runtime.call("coverage", "fr", CATALOG_SEMICOLON), 0.0) and ok
	return ok


## The build gate the suggestion is for, through the REAL compiler: the shipped On Project Export
## trigger (no second export hook), the shipped Export Has Feature condition, and the new gate
## inverted, so an unfinished shipped language stops a release build.
static func _test_export_gate_compiles() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "EditorScript"
	sheet.tool_mode = true
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProjectExport"
	var has_feature: ACECondition = ACECondition.new()
	has_feature.provider_id = "Core"
	has_feature.ace_id = "ExportHasFeature"
	has_feature.params = {"feature": "\"release\""}
	event.conditions.append(has_feature)
	var is_complete: ACECondition = ACECondition.new()
	is_complete.provider_id = "Core"
	is_complete.ace_id = "TranslationIsComplete"
	is_complete.params = {"locale": "\"fr\"", "path": "\"res://i18n/strings.csv\"", "separator": "\",\""}
	is_complete.negated = true
	event.conditions.append(is_complete)
	var complain: ACEAction = ACEAction.new()
	complain.provider_id = "Core"
	complain.ace_id = "PushError"
	complain.params = {"message": "\"fr is not finished\""}
	event.actions.append(complain)
	sheet.events.append(event)
	var output: String = str(SheetCompiler.compile(sheet, "user://translation_quality_gate.gd").get("output", ""))
	var ok: bool = true
	ok = _check("the gate rides the shipped export trigger",
		output.contains("func _on_project_export(is_debug: bool, features: PackedStringArray) -> void:"), true) and ok
	ok = _check("the export feature flag is the shipped one", output.contains("features.has(\"release\")"), true) and ok
	ok = _check("the inverted gate emits as a negation", output.contains("not ("), true) and ok
	ok = _check("the catalog path reaches the emitted line", output.contains("res://i18n/strings.csv"), true) and ok
	ok = _check("no template placeholder survives into the emitted script", output.contains("{locale}"), false) and ok
	ok = _check("the emitted bake step parses", _reload(output) != null, true) and ok
	return ok


## ── l10n-unmarked, judged against what the compiler REALLY emits ─────────────────────────────────
static func _test_unmarked_on_emitted_code() -> bool:
	var ok: bool = true
	# Set Text on a Label sheet, dropped at a bare literal - the "before the fix" row.
	var bare: String = _compile_label_text("\"PLAY\"", "translation_quality_bare")
	ok = _check("Set Text with a bare literal emits the sink the check looks for",
		bare.contains("text = str(\"PLAY\")"), true) and ok
	ok = _check("and the check names that literal",
		",".join(EventSheetProjectDoctor.unmarked_player_text(bare)), "PLAY") and ok
	# The same row with the globe lit - the "after the fix" row. The check must go silent.
	var marked: String = _compile_label_text("tr(\"PLAY\")", "translation_quality_marked")
	ok = _check("the globe ships the value as tr()", marked.contains("tr(\"PLAY\")"), true) and ok
	ok = _check("a marked value is never accused",
		",".join(EventSheetProjectDoctor.unmarked_player_text(marked)), "") and ok
	ok = _check("and it registers as a marked key",
		",".join(EventSheetProjectDoctor.marked_translation_literals(marked)), "PLAY") and ok
	# Set Text (translated pattern) - the shipped verb that keeps the pattern as the key.
	var pattern_sheet: EventSheetResource = EventSheetResource.new()
	pattern_sheet.host_class = "Label"
	var pattern_event: EventRow = EventRow.new()
	pattern_event.trigger_provider_id = "Core"
	pattern_event.trigger_id = "OnReady"
	var pattern_action: ACEAction = ACEAction.new()
	pattern_action.provider_id = "Core"
	pattern_action.ace_id = "SetTextTranslatedPattern"
	pattern_action.params = {"pattern": "\"You have {coins} coins\"", "values": "{\"coins\": 0}"}
	pattern_event.actions.append(pattern_action)
	pattern_sheet.events.append(pattern_event)
	var pattern_output: String = str(SheetCompiler.compile(pattern_sheet, "user://translation_quality_pattern.gd").get("output", ""))
	ok = _check("Set Text (translated pattern) emits its tr() line",
		pattern_output.contains("text = tr(\"You have {coins} coins\")"), true) and ok
	ok = _check("a translated pattern is never accused",
		",".join(EventSheetProjectDoctor.unmarked_player_text(pattern_output)), "") and ok
	return ok


## THE CLEAN CASES. Every one of these is a working project, and a finding on any of them is worse
## than no check at all.
static func _test_unmarked_clean_cases() -> bool:
	var clean: Dictionary = {
		"a group name": "\tadd_to_group(\"enemies\", true)",
		"an animation name": "\t$AnimationPlayer.play(\"idle\")",
		"an input action": "\tif Input.is_action_just_pressed(\"jump\"):\n\t\tpass",
		"a node path": "\tvar node = get_node(\"../Sibling/Label\")",
		"a resource path": "\tvar scene = load(\"res://levels/one.tscn\")",
		"a print message": "\tprint(\"spawner ready\")",
		"an error message": "\tpush_error(\"bad state\")",
		"a signal name": "\tconnect(\"pressed\", _on_pressed)",
		"text filled from a variable": "\t$Score.text = str(score)",
		"text cleared": "\t$Score.text = \"\"",
		"a number in a label": "\t$Score.text = \"0\"",
		"a clock placeholder": "\t$Clock.text = \"00:00\"",
		"a bare format slot": "\t$Score.text = \"%d\" % [score]",
		"an empty bbcode pair": "\t$Rich.bbcode_text = \"[b][/b]\"",
		"a path shown in a label": "\t$Path.text = \"res://save/slot1.tres\"",
		"a private text buffer": "\tvar text = \"internal buffer\"",
		"a private suffixed buffer": "\tvar label_text = \"internal buffer\"",
		"a comparison, not a write": "\tif $Title.text == \"PLAY\":\n\t\tpass",
		"a commented-out line": "\t# $Title.text = \"PLAY\"",
		"a line that already translates": "\t$Title.text = tr(\"PLAY\") + \" now\"",
		"a plural line": "\t$Count.text = tr_n(\"%d apple\", \"%d apples\", n) % n",
		"a multi-line literal": "\t$Screen.text = \"CHEF PLANNER\n\ttask: %s\" % [task]",
		# THE RECEIVER RULE. `text` is a common field name on ordinary data objects - this plugin's own
		# comment rows have one - so only a receiver that is syntactically a NODE is judged.
		"a data object that happens to have a text field": "\tcomment_row.text = \"short note\"",
		"a cast that hides the node behind an expression": "\t(fields.get(\"label\") as LineEdit).text = \"Combat\"",
		"a label reached through a plain variable": "\tstatus_label.text = \"Ready\"",
		# The argument rule: HUD Kit's set_text names the LABEL first, and that name is an identifier.
		"a label name handed to a pack set_text": "\t$HudKit.set_text(\"StatusLabel\", str(score))",
	}
	var ok: bool = true
	var names: Array = clean.keys()
	names.sort()
	for label: String in names:
		ok = _check("clean: %s is never accused" % label,
			",".join(EventSheetProjectDoctor.unmarked_player_text(_body(str(clean[label])))), "") and ok
	return ok


## The accusations, one sink shape at a time.
static func _test_unmarked_accusations() -> bool:
	var accused: Dictionary = {
		"\t$Title.text = \"PLAY\"": "PLAY",
		"\ttext = str(\"Press any key\")": "Press any key",
		"\t$Start.tooltip_text = \"Begins a new run\"": "Begins a new run",
		"\t$Field.placeholder_text = \"Your name\"": "Your name",
		"\t$Rich.bbcode_text = \"[b]Boss defeated[/b]\"": "[b]Boss defeated[/b]",
		"\t$Hud.set_text(\"Ready\")": "Ready",
		"\t$Score.text += \" points\"": " points",
		"\t$Score.text = \"Score: %d\" % [score]": "Score: %d",
		"\t%Wallet.text = \"Ready\"": "Ready",
		"\tget_node(\"Panel/Label\").text = \"Ready\"": "Ready",
		"\tself.text = \"Ready\"": "Ready",
		# A format string is ONE argument, so it is still judged: the split is on real arguments,
		# never on quotes.
		"\t$Score.set_text(\"Score: %s\" % [name])": "Score: %s",
	}
	var ok: bool = true
	var lines: Array = accused.keys()
	lines.sort()
	for line: String in lines:
		ok = _check("accused: %s" % line.strip_edges(),
			",".join(EventSheetProjectDoctor.unmarked_player_text(_body(line))), str(accused[line])) and ok
	# HUD Kit addresses a label by NAME and then sets it. The name must never reach a translator; the
	# line after it must.
	ok = _check("a pack set_text is judged on its text, never on the label name it addresses",
		",".join(EventSheetProjectDoctor.unmarked_player_text(
			_body("\t$HudKit.set_text(\"StatusLabel\", \"Press any key\")"))), "Press any key") and ok
	# The Dialogue Kit line: the SPEAKER is an id the game matches on, the line is player text, and
	# the comma inside the speaker's own name must not shift which is which.
	ok = _check("a queued dialogue line is accused without its speaker",
		",".join(EventSheetProjectDoctor.unmarked_player_text(
			_body("\t$DialogueKitBehavior.queue_line(\"guard, night watch\", \"Halt, who goes there\")"))),
		"Halt, who goes there") and ok
	# A key the project marks elsewhere is not missing text: the check gathers marked literals from
	# every script before it judges any of them.
	ok = _check("a key another line already marks is gathered as marked",
		",".join(EventSheetProjectDoctor.marked_translation_literals(
			_body("\t$Other.text = tr(\"PLAY\")\n\t$Title.text = \"PLAY\""))), "PLAY") and ok
	return ok


## ── l10n-stale-label, judged against what the compiler REALLY emits ──────────────────────────────
static func _test_stale_on_emitted_code() -> bool:
	var ok: bool = true
	var stale_sheet: EventSheetResource = _hud_sheet()
	var stale_output: String = str(SheetCompiler.compile(stale_sheet, "user://translation_quality_stale.gd").get("output", ""))
	# Set Text ships as `text = str({value})`, so the emitted line really is a tr() nested inside a
	# str() - which is exactly the shape a substring scan for "tr(" cannot tell from `str(` itself.
	ok = _check("the HUD sheet emits its tr() text assignment inside _ready",
		stale_output.contains("text = str(tr(\"WALLET\"))"), true) and ok
	ok = _check("the check names the function that fills it",
		",".join(EventSheetProjectDoctor.stale_translated_text_functions(stale_output)), "_ready") and ok
	# THE FIX MUST NOT BE ACCUSED. The same sheet plus the On Language Changed event the finding
	# recommends compiles to the _notification virtual, and the check has to go silent on it.
	var fixed_sheet: EventSheetResource = _hud_sheet()
	var refresh: EventRow = EventRow.new()
	refresh.trigger_provider_id = "Core"
	refresh.trigger_id = "OnLocaleChanged"
	var gate: ACECondition = ACECondition.new()
	gate.provider_id = "Core"
	gate.ace_id = "IsLocaleChangeNotification"
	refresh.conditions.append(gate)
	var refill: ACEAction = ACEAction.new()
	refill.provider_id = "Core"
	refill.ace_id = "SetLabelText"
	refill.params = {"value": "tr(\"WALLET\")"}
	refresh.actions.append(refill)
	fixed_sheet.events.append(refresh)
	var fixed_output: String = str(SheetCompiler.compile(fixed_sheet, "user://translation_quality_fixed.gd").get("output", ""))
	ok = _check("the fix compiles to the translation-changed notification",
		fixed_output.contains("if what == NOTIFICATION_TRANSLATION_CHANGED:"), true) and ok
	ok = _check("and the check never accuses its own fix",
		",".join(EventSheetProjectDoctor.stale_translated_text_functions(fixed_output)), "") and ok
	return ok


static func _test_stale_clean_cases() -> bool:
	var ok: bool = true
	var refreshing: String = "extends Node\n\n\nfunc _notification(what: int) -> void:\n\tif what == NOTIFICATION_TRANSLATION_CHANGED:\n\t\t$Wallet.text = tr(\"WALLET\")\n"
	ok = _check("clean: a script that already reacts is never accused",
		",".join(EventSheetProjectDoctor.stale_translated_text_functions(refreshing)), "") and ok
	var custom_signal: String = "extends Node\n\n\nfunc _ready() -> void:\n\tSettings.language_changed.connect(_refill)\n\t$Wallet.text = tr(\"WALLET\")\n\n\nfunc _refill() -> void:\n\t$Wallet.text = tr(\"WALLET\")\n"
	ok = _check("clean: a project routing its own language_changed signal is never accused",
		",".join(EventSheetProjectDoctor.stale_translated_text_functions(custom_signal)), "") and ok
	var per_frame: String = "extends Node\n\n\nfunc _process(delta: float) -> void:\n\t$Wallet.text = tr(\"WALLET\")\n"
	ok = _check("clean: text refilled every frame cannot go stale",
		",".join(EventSheetProjectDoctor.stale_translated_text_functions(per_frame)), "") and ok
	var bare_only: String = "extends Node\n\n\nfunc _ready() -> void:\n\t$Wallet.text = \"Wallet\"\n"
	ok = _check("clean: a bare literal is the other check's business",
		",".join(EventSheetProjectDoctor.stale_translated_text_functions(bare_only)), "") and ok
	var plain_variable: String = "extends Node\n\n\nfunc _ready() -> void:\n\tstatus_label.text = tr(\"WALLET\")\n"
	ok = _check("clean: a label behind a plain variable is silence on purpose, never an accusation",
		",".join(EventSheetProjectDoctor.stale_translated_text_functions(plain_variable)), "") and ok
	var not_a_sink: String = "extends Node\n\n\nfunc _ready() -> void:\n\tvar greeting: String = tr(\"HELLO\")\n\tprint(greeting)\n"
	ok = _check("clean: tr() that never reaches a label is never accused",
		",".join(EventSheetProjectDoctor.stale_translated_text_functions(not_a_sink)), "") and ok
	var two_functions: String = "extends Node\n\n\nfunc _ready() -> void:\n\t$Wallet.text = tr(\"WALLET\")\n\n\nfunc refresh_hud() -> void:\n\t$Coins.set_text(tr(\"COINS\"))\n"
	ok = _check("every function that fills text is named",
		",".join(EventSheetProjectDoctor.stale_translated_text_functions(two_functions)), "_ready,refresh_hud") and ok
	return ok


## THE BUG ITSELF, run for real. A value tr() returned is a plain String: it does not follow a later
## locale switch, which is precisely why a label an event filled keeps the old language while one
## typed into the scene does not. Verified through the real TranslationServer, then cleaned up so no
## later test inherits a locale or a catalog.
static func _test_stale_bug_is_real() -> bool:
	var previous_locale: String = TranslationServer.get_locale()
	var french: Translation = Translation.new()
	french.locale = "fr"
	french.add_message("WALLET", "Portefeuille")
	var german: Translation = Translation.new()
	german.locale = "de"
	german.add_message("WALLET", "Geldbeutel")
	TranslationServer.add_translation(french)
	TranslationServer.add_translation(german)
	TranslationServer.set_locale("fr")
	# The other half of the sentence the finding prints: text typed INTO THE SCENE follows the switch
	# by itself, because a Control auto-translates its own text at display time.
	var scene_label: Label = Label.new()
	scene_label.text = "WALLET"
	var event_label: Label = Label.new()
	var filled_once: String = TranslationServer.translate("WALLET")
	TranslationServer.set_locale("de")
	var ok: bool = true
	ok = _check("the value an event stored keeps the old language", filled_once, "Portefeuille") and ok
	ok = _check("while running the lookup again gives the new one", TranslationServer.translate("WALLET"), "Geldbeutel") and ok
	event_label.text = filled_once
	ok = _check("a Control auto-translates the source string it was given", scene_label.atr(scene_label.text), "Geldbeutel") and ok
	ok = _check("while a label an event filled cannot be rescued by auto-translation",
		event_label.atr(event_label.text), "Portefeuille") and ok
	scene_label.free()
	event_label.free()
	ok = _check("and a string the catalog does not know comes back unchanged",
		TranslationServer.translate("Portefeuille"), "Portefeuille") and ok
	TranslationServer.remove_translation(french)
	TranslationServer.remove_translation(german)
	TranslationServer.set_locale(previous_locale)
	return ok


## ── The gate, and the two checks running end to end over the real project ────────────────────────
static func _test_doctor_gate() -> bool:
	var ok: bool = true
	# This repo registers no catalog, so neither check contributes a finding here - which is what
	# keeps the Doctor's report on this repo honest.
	ok = _check("with no catalog registered the localisation gate is shut",
		EventSheetProjectDoctor._project_has_translation_catalogs(), false) and ok
	var had_setting: bool = ProjectSettings.has_setting(TRANSLATIONS_SETTING)
	var previous: Variant = ProjectSettings.get_setting(TRANSLATIONS_SETTING) if had_setting else null
	ProjectSettings.set_setting(TRANSLATIONS_SETTING, PackedStringArray(["res://i18n/strings.en.translation"]))
	ok = _check("with a catalog registered the gate opens",
		EventSheetProjectDoctor._project_has_translation_catalogs(), true) and ok
	# No REAL script in this repo leaves a label in the old language. The suite's own fixtures are
	# excluded and only those: a test that embeds emitted GDScript as a string literal in order to
	# assert on it is indistinguishable from a script that runs it, and a game project has no such
	# file. Anything the check finds outside tests/ would be a live accusation, so that set must be
	# empty and is named rather than counted, so a regression says WHICH script it broke on.
	var stale_findings: Array[Dictionary] = []
	EventSheetProjectDoctor.check_stale_translated_labels(PackedStringArray(), stale_findings)
	var stale_paths: PackedStringArray = PackedStringArray()
	var stale_shape: PackedStringArray = PackedStringArray()
	for finding: Dictionary in stale_findings:
		if str(finding.get("check")) != "l10n-stale-label" or str(finding.get("severity")) != "info":
			stale_shape.append(str(finding.get("check")))
		if not str(finding.get("path")).begins_with("res://tests/"):
			stale_paths.append(str(finding.get("path")))
	ok = _check("no shipped script in this repo leaves a label in the old language",
		",".join(stale_paths), "") and ok
	ok = _check("every stale finding is an info-tier l10n-stale-label", ",".join(stale_shape), "") and ok
	var unmarked_findings: Array[Dictionary] = []
	EventSheetProjectDoctor.check_unmarked_player_text(PackedStringArray(), unmarked_findings)
	var wrong_shape: PackedStringArray = PackedStringArray()
	for finding: Dictionary in unmarked_findings:
		if str(finding.get("check")) != "l10n-unmarked" or str(finding.get("severity")) != "info":
			wrong_shape.append(str(finding.get("check")))
		# A pack is shipped vocabulary: it may never be blamed for the author's untranslated text.
		if str(finding.get("path")).begins_with("res://eventsheet_addons/"):
			wrong_shape.append(str(finding.get("path")))
	ok = _check("every unmarked finding is an info-tier l10n-unmarked on a non-pack script",
		",".join(wrong_shape), "") and ok
	# ...and WHICH scripts, by name. Shape alone cannot see the failure this check is one bad rule
	# away from: quietly starting to accuse working scripts. The suite's own fixtures and the build
	# tools embed emitted GDScript as string literals, so they are expected here and excluded by
	# path; everything else must be exactly the seven showcase games, which really are written in one
	# language on purpose (batch fourteen's Combo Fighter is the ninth). A regression names the
	# script it broke on instead of moving a number.
	var accused: PackedStringArray = PackedStringArray()
	for finding: Dictionary in unmarked_findings:
		var path: String = str(finding.get("path"))
		if path.begins_with("res://tests/") or path.begins_with("res://tools/"):
			continue
		accused.append(path)
	accused.sort()
	ok = _check("the accusations over this repo are exactly the one-language showcases",
		"\n".join(accused), "\n".join(PackedStringArray([
			"res://demo/showcase/boomer_level/boomer_level.gd",
			"res://demo/showcase/combo_fighter/combo_fighter.gd",
			"res://demo/showcase/family_arena/family_arena.gd",
			"res://demo/showcase/hierarchy_playground/hierarchy_playground.gd",
			"res://demo/showcase/input_rebind/input_rebind.gd",
			"res://demo/showcase/menu_starter/menu_starter.gd",
			"res://demo/showcase/platformer_shooter/platformer_shooter.gd",
			"res://demo/showcase/raycast_lab/raycast_lab.gd",
			"res://demo/showcase/raycast_lab_3d/raycast_lab_3d.gd",
			"res://demo/showcase/skill_tree/skill_tree.gd",
			"res://demo/showcase/starfall/starfall.gd",
			"res://demo/showcase/traversal_course/traversal_course.gd",
			"res://demo/showcase/traversal_course_3d/traversal_course_3d.gd",
		]))) and ok
	ProjectSettings.set_setting(TRANSLATIONS_SETTING, previous)
	ok = _check("the gate is restored to what this repo actually has",
		EventSheetProjectDoctor._project_has_translation_catalogs(), false) and ok
	return ok


## ── Fixtures ────────────────────────────────────────────────────────────────────────────────────


## A Label sheet whose On Ready fills the wallet label from tr() - the stale-label shape.
static func _hud_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Label"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	var fill: ACEAction = ACEAction.new()
	fill.provider_id = "Core"
	fill.ace_id = "SetLabelText"
	fill.params = {"value": "tr(\"WALLET\")"}
	event.actions.append(fill)
	sheet.events.append(event)
	return sheet


## A Label sheet whose On Ready sets the text to `value`, compiled.
static func _compile_label_text(value: String, file_name: String) -> String:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Label"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "SetLabelText"
	action.params = {"value": value}
	event.actions.append(action)
	sheet.events.append(event)
	return str(SheetCompiler.compile(sheet, "user://%s.gd" % file_name).get("output", ""))


## One or more statement lines wrapped as a real script body, so the scanner sees the indentation and
## the surrounding function it would see in an emitted file.
static func _body(lines: String) -> String:
	return "extends Node\n\n\nfunc _ready() -> void:\n%s\n" % lines


## The three shipped expressions compiled into one runnable object, with the params pointed at the
## function arguments so every case is one call.
static var _runtime_instance: Object = null


static func _runtime() -> Object:
	if _runtime_instance != null:
		return _runtime_instance
	var source: String = "\n".join(PackedStringArray([
		"extends RefCounted",
		"",
		"",
		"func coverage(locale: String, path: String) -> float:",
		"\treturn %s" % _baked("TranslationCoverage", "\",\""),
		"",
		"",
		"func coverage_semicolon(locale: String, path: String) -> float:",
		"\treturn %s" % _baked("TranslationCoverage", "\";\""),
		"",
		"",
		"func missing(locale: String, path: String) -> Array:",
		"\treturn %s" % _baked("MissingTranslationKeys", "\",\""),
		"",
		"",
		"func complete(locale: String, path: String) -> bool:",
		"\treturn %s" % _baked("TranslationIsComplete", "\",\""),
		"",
	]))
	var script: GDScript = _reload(source)
	if script == null:
		return null
	_runtime_instance = script.new()
	return _runtime_instance


## The shipped descriptor's template with the two operands pointed at local identifiers - the same
## single-pass substitution the dock performs the moment a row is applied.
static func _baked(ace_id: String, separator: String) -> String:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	if descriptor == null:
		return "null"
	return ActionCodegen._apply_template(str(descriptor.codegen_template),
		{"locale": "locale", "path": "path", "separator": separator})


static func _write_catalogs() -> void:
	# One trailing ",,,," row on purpose: a spreadsheet export leaves them behind, and it is not a
	# translatable unit. The Arabic cell proves an RTL value is read as filled like any other.
	_write(CATALOG_MAIN, "keys,en,fr,de,ar\nPLAY,Play,Jouer,Spielen,العب\nQUIT,Quit,Quitter,,\nHELLO,Hello,,,\nBACK,Back,,,\n,,,,\n")
	# CRLF endings, a quoted cell holding the separator, a doubled \"\" inside one, and a cell holding
	# only spaces (which is not a translation).
	_write(CATALOG_QUOTED, "keys,en,fr\r\nGREET,\"Hello, friend\",\"Bonjour, ami\"\r\nSAY,\"He said \"\"hi\"\"\",\"Il a dit \"\"salut\"\"\"\r\nSPACED,Spaced,   \r\n")
	_write(CATALOG_SEMICOLON, "keys;en;fr\nPLAY;Play;Jouer\nQUIT;Quit;\n")
	_write(CATALOG_HEADER_ONLY, "keys,en,fr\n")
	DirAccess.remove_absolute(CATALOG_ABSENT)


static func _write(path: String, body: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(body)
	file.close()


static func _cleanup() -> void:
	_runtime_instance = null
	for path: String in [CATALOG_MAIN, CATALOG_QUOTED, CATALOG_SEMICOLON, CATALOG_HEADER_ONLY,
			"user://translation_quality_gate.gd", "user://translation_quality_bare.gd",
			"user://translation_quality_marked.gd", "user://translation_quality_pattern.gd",
			"user://translation_quality_stale.gd", "user://translation_quality_fixed.gd"]:
		DirAccess.remove_absolute(path)


static func _param_default(descriptor: ACEDescriptor, param_id: String) -> String:
	for parameter: ACEParam in descriptor.params:
		if str(parameter.id) == param_id:
			return str(parameter.default_value)
	return "(no such param)"


static func _first_option_label(descriptor: ACEDescriptor, param_id: String) -> String:
	for parameter: ACEParam in descriptor.params:
		if str(parameter.id) != param_id or parameter.options.is_empty():
			continue
		var option: Variant = parameter.options[0]
		return str((option as Dictionary).get("label", "")) if option is Dictionary else str(option)
	return "(no options)"


static func _reload(source: String) -> GDScript:
	var script: GDScript = GDScript.new()
	script.source_code = source
	if script.reload() != OK:
		print("  source failed to reload:\n%s" % source)
		return null
	return script


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] translation_quality_test: %s" % label)
		return true
	print("[FAIL] translation_quality_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
