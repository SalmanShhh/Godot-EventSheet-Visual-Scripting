# EventForge - The non-string half of a localised game (locale_asset_aces.gd).
#
# Every verb is proven twice: the EMITTED code is pinned (a codegen_template is a compatibility
# covenant, so the exact text a sheet compiles to is asserted), and the BEHAVIOUR is proven at
# runtime - the emitted expression is built into a real GDScript, reloaded and called, against real
# files written to user:// and real catalogs added to TranslationServer. A verb with only an emission
# pin would sail past every failure these verbs exist to prevent.
#
# The edge cases each verb exists for, one case each below:
#   - a language with NO variant of the asset on disk (the base file, never a missing-file error);
#   - pt_BR narrowing to a pt variant, which is the fallback every hand-rolled version forgets;
#   - a language with NO dub at all (the caption path, not silence);
#   - a regional locale (de_AT) counting the de voice folder as its own;
#   - a resolved path that turns out not to be audio (0.0 seconds, not a call on the wrong type);
#   - a translation that is LONGER in another language (the caption holds longer - the whole point);
#   - CJK text, where the character count is not the byte count;
#   - a key with no catalog entry (the key itself, so a missing translation is visible);
#   - a data cell that still holds a plain English LITERAL, which every shipped pack does today and
#     which must keep working unchanged.
#
# TranslationServer and the locale are process-global, so this test removes the catalogs it adds and
# restores the locale it found - a suite that ran after it would otherwise see a German game.
@tool
class_name LocaleAssetACEsTest
extends RefCounted

const PROBE_ROOT := "user://locale_asset_probe"
const ART_DIR := PROBE_ROOT + "/art"
const VOICE_DIR := PROBE_ROOT + "/voice"

## The line every timing case uses. Its German is 42 characters, so at the shipped 14 characters a
## second it needs exactly 3.0s - a number that cannot be reached by accident. Its English is three
## characters, so it lands on the 1.2s floor instead: the same row, two different waits.
const LINE_KEY := "line.greet"
const LINE_EN := "Hi!"
const LINE_DE := "Hier entlang, mein Freund, es ist wichtig!"
const LINE_JA := "こちらへ"

## A data-asset cell that holds a key, and one that still holds plain English.
const TITLE_KEY := "quest.bridge.title"
const TITLE_DE := "Bruecke reparieren"
const TITLE_PT := "Reparar a ponte"
const TITLE_LITERAL := "Repair the Bridge"


static func run() -> bool:
	var restore_locale: String = TranslationServer.get_locale()
	_add_catalogs()
	_write_assets()

	var all_passed: bool = true
	all_passed = _run_registration() and all_passed
	all_passed = _run_emission() and all_passed
	all_passed = _run_asset_runtime() and all_passed
	all_passed = _run_voice_runtime() and all_passed
	all_passed = _run_reading_time_runtime() and all_passed
	all_passed = _run_say_line_runtime() and all_passed
	all_passed = _run_translated_field_runtime() and all_passed

	_remove_catalogs()
	_remove_assets()
	TranslationServer.set_locale(restore_locale)
	if all_passed:
		print("[PASS] locale_asset_aces_test: language variants, voice + captions, keys in data cells (emitted code pinned, values proven at runtime)")
	return all_passed


## The eight verbs register with the ids, names, kinds and categories the picker groups them by.
static func _run_registration() -> bool:
	var ok: bool = true
	var by_id: Dictionary = _by_id()
	for ace_id: String in ["LocalizedFile", "LoadLocalized", "SayLine", "HasVoiceForLanguage",
			"VoiceLineLength", "ReadingTimeOf", "TranslatedField", "TranslatedColumn"]:
		ok = _check("%s is registered" % ace_id, by_id.has(ace_id), true) and ok
	ok = _check("Localized File reads as a name", _display_name(by_id, "LocalizedFile"), "Localized File") and ok
	ok = _check("Load For Language reads as a name", _display_name(by_id, "LoadLocalized"), "Load For Language") and ok
	ok = _check("Say Line reads as a name", _display_name(by_id, "SayLine"), "Say Line") and ok
	ok = _check("Has Voice For Language reads as a name", _display_name(by_id, "HasVoiceForLanguage"), "Has Voice For Language") and ok
	ok = _check("Voice Line Length reads as a name", _display_name(by_id, "VoiceLineLength"), "Voice Line Length") and ok
	ok = _check("Reading Time Of reads as a name", _display_name(by_id, "ReadingTimeOf"), "Reading Time Of") and ok
	ok = _check("Translated Field Of reads as a name", _display_name(by_id, "TranslatedField"), "Translated Field Of") and ok
	ok = _check("Translated Column Of Table reads as a name", _display_name(by_id, "TranslatedColumn"), "Translated Column Of Table") and ok

	ok = _check("the asset verbs sit with the rest of Translation", _category(by_id, "LoadLocalized"), "Translation") and ok
	ok = _check("the field verbs do too", _category(by_id, "TranslatedField"), "Translation") and ok
	ok = _check("the voice verbs get their own section", _category(by_id, "SayLine"), "Translation: Voice") and ok
	ok = _check("Reading Time Of is general text, not voice", _category(by_id, "ReadingTimeOf"), "Text") and ok
	# Every live category needs an icon. "Translation" names an engine class outright; the voice
	# sub-section has none, so the picker derives one from the host its verbs act on - the player.
	ok = _check("the Translation section keeps its icon", ACEPickerDialog.category_icon_name("Translation"), "Translation") and ok
	ok = _check("the voice sub-section derives one from the node it speaks through",
		ACEPickerDialog.category_icon_name("Translation: Voice"), "AudioStreamPlayer") and ok
	ok = _check("the voice section is introduced in the picker",
		EventForgeBuiltinACEs.section_descriptions().has("Translation: Voice"), true) and ok

	ok = _check("Say Line is an action", int(by_id["SayLine"].ace_type), int(ACEDescriptor.ACEType.ACTION)) and ok
	ok = _check("Has Voice For Language is a condition", int(by_id["HasVoiceForLanguage"].ace_type), int(ACEDescriptor.ACEType.CONDITION)) and ok
	ok = _check("Localized File is an expression", int(by_id["LocalizedFile"].ace_type), int(ACEDescriptor.ACEType.EXPRESSION)) and ok
	ok = _check("Say Line is hosted on the player that speaks", str(by_id["SayLine"].node_type), "AudioStreamPlayer") and ok
	ok = _check("an expression verb is host-free", str(by_id["LocalizedFile"].node_type), "") and ok

	# Defaults are what the row shows the moment it is dropped, so each has to stand on its own.
	ok = _check("the base-file default is a literal path", _param_default(by_id, "LocalizedFile", "path"), "\"res://art/sign.png\"") and ok
	ok = _check("the voice folder default is a literal path", _param_default(by_id, "SayLine", "folder"), "\"res://voice\"") and ok
	ok = _check("the clip format default is a quoted extension", _param_default(by_id, "SayLine", "extension"), "\".ogg\"") and ok
	ok = _check("the clip format is a suggest combo, not a fixed list", _autocomplete_size(by_id, "SayLine", "extension"), 3) and ok
	ok = _check("an unset caption is null rather than a bare placeholder", _param_default(by_id, "SayLine", "caption"), "null") and ok
	ok = _check("the reading pace default is the shipped one", _param_default(by_id, "ReadingTimeOf", "chars_per_second"), "14.0") and ok
	ok = _check("the reading floor default is the shipped one", _param_default(by_id, "ReadingTimeOf", "minimum_seconds"), "1.2") and ok
	ok = _check("a record defaults to the For Each item", _param_default(by_id, "TranslatedField", "record"), "item") and ok
	ok = _check("a table param is a variable reference", _param_hint(by_id, "TranslatedColumn", "table"), "variable_reference:Array") and ok
	return ok


## What a sheet actually compiles to. The two short templates are pinned WHOLE - they are the
## covenant; the long resolutions are pinned by the clauses that carry their meaning.
static func _run_emission() -> bool:
	var ok: bool = true

	var localized: String = _emitted("LocalizedFile", {"path": "\"res://art/sign.png\""})
	ok = _check("the exact-locale variant is tried first",
		localized.contains("__base.get_basename() + \".\" + TranslationServer.get_locale() + \".\" + __base.get_extension()"), true) and ok
	ok = _check("then the language-only one (pt_BR narrows to pt)",
		localized.contains("TranslationServer.get_locale().get_slice(\"_\", 0)"), true) and ok
	ok = _check("and the base path is the answer when neither is on disk",
		localized.contains("else __base"), true) and ok
	ok = _check("the caller's path expression is written exactly once",
		localized.count("res://art/sign.png"), 1) and ok
	ok = _check("existence is asked before the path is used",
		localized.contains("ResourceLoader.exists(__exact)"), true) and ok
	ok = _check("the expression is one line", localized.split("\n").size(), 1) and ok
	ok = _check("no placeholder survives substitution", localized.contains("{path}"), false) and ok
	ok = _check("Load For Language is exactly Localized File inside a load()",
		_emitted("LoadLocalized", {"path": "\"res://art/sign.png\""}), "load(%s)" % localized) and ok

	var clip: String = _emitted("HasVoiceForLanguage", {"key": "\"ilsa.greet.01\"", "folder": "\"res://voice\"", "extension": "\".ogg\""})
	ok = _check("a clip is looked for under the locale's own folder",
		clip.contains("__folder.path_join(TranslationServer.get_locale()).path_join(__file)"), true) and ok
	ok = _check("a language with no folder resolves to empty text, not to the base path",
		clip.contains("else \"\""), true) and ok
	ok = _check("the condition is that emptiness, negated", clip.begins_with("not (func("), true) and ok
	ok = _check("the key and the extension are joined into a file name",
		clip.contains(".call(\"res://voice\", \"ilsa.greet.01\" + \".ogg\")"), true) and ok

	ok = _check("Voice Line Length guards a path that is not audio",
		_emitted("VoiceLineLength", {"key": "\"ilsa.greet.01\"", "folder": "\"res://voice\"", "extension": "\".ogg\""}).contains(
			"__clip.get_length() if __clip is AudioStream else 0.0"), true) and ok
	ok = _check("and never loads an empty path",
		_emitted("VoiceLineLength", {"key": "\"ilsa.greet.01\"", "folder": "\"res://voice\"", "extension": "\".ogg\""}).contains(
			"load(__clip_path) if not __clip_path.is_empty() else null"), true) and ok

	ok = _check("Reading Time Of emits a floored characters-per-second divide",
		_emitted("ReadingTimeOf", {"text": "\"You there!\"", "chars_per_second": "14.0", "minimum_seconds": "1.2"}),
		"maxf(1.2, \"You there!\".length() / maxf(14.0, 1.0))") and ok

	ok = _check("Translated Field Of reads one field as a key",
		_emitted("TranslatedField", {"record": "item", "field": "\"title\""}),
		"(func(__value: Variant) -> String: return tr(str(__value)) if __value != null else \"\").call(item.get(\"title\"))") and ok
	ok = _check("Translated Column Of Table is that field read down a map",
		_emitted("TranslatedColumn", {"table": "rows", "column": "\"label\""}),
		"rows.map(func(__record): return (func(__value: Variant) -> String: return tr(str(__value)) if __value != null else \"\").call(__record.get(\"label\")))") and ok

	var say: String = _emitted("SayLine", {"key": "\"ilsa.greet.01\"", "folder": "\"res://voice\"",
		"extension": "\".ogg\"", "caption": "null", "target": "", "uid": "7"})
	var say_lines: PackedStringArray = say.split("\n")
	ok = _check("Say Line resolves the clip once, into a named local", say_lines[0].begins_with("var __voice_path_7: String = "), true) and ok
	ok = _check("its locals carry the row's uid", say.contains("__voice_caption_7"), true) and ok
	# The caption local is deliberately UNTYPED. Typed `Label`, pointing the row at the RichTextLabel
	# a styled subtitle actually uses is a hard runtime type error that aborts the row before the
	# clip ever plays - so the type is pinned here as the contract it is.
	ok = _check("the caption local takes any text control, not only a Label",
		say.contains("var __voice_caption_7: Variant = null"), true) and ok
	ok = _check("no {uid} survives into the emitted code", say.contains("{uid}"), false) and ok
	ok = _check("the caption goes up before either branch", say.contains("\t__voice_caption_7.text = tr(\"ilsa.greet.01\")"), true) and ok
	ok = _check("no clip means a wait as long as the line takes to READ",
		say.contains("\tawait get_tree().create_timer(maxf(1.2, tr(\"ilsa.greet.01\").length() / maxf(14.0, 1.0))).timeout"), true) and ok
	ok = _check("a clip means a wait as long as the clip RUNS", say.contains("\tawait finished"), true) and ok
	ok = _check("and both branches end at the same clearing line", say_lines[say_lines.size() - 1], "\t__voice_caption_7.text = \"\"") and ok
	ok = _check("the row's target reaches the player it acts on",
		_emitted("SayLine", {"key": "\"k\"", "folder": "\"res://voice\"", "extension": "\".ogg\"",
			"caption": "null", "target": "$Voice", "uid": "3"}).contains("\t$Voice.play()"), true) and ok

	# Through the real compiler, in the row a sheet would author: On Ready -> Say Line.
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "AudioStreamPlayer"
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnReady"
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "SayLine"
	# {uid} is baked at APPLY time by the dock, never by the compiler, so the row carries it baked.
	action.codegen_template = str(_by_id()["SayLine"].codegen_template).replace("{uid}", "1")
	action.params = {"key": "\"ilsa.greet.01\"", "folder": "\"res://voice\"", "extension": "\".ogg\"",
		"caption": "null", "target": ""}
	row.actions.append(action)
	sheet.events.append(row)
	var output: String = str(SheetCompiler.compile(sheet, "user://locale_asset_compile_probe.gd").get("output", ""))
	ok = _check("the whole action compiles into the sheet", output.contains("var __voice_path_"), true) and ok
	ok = _check("and the emitted script parses", _parses(output), true) and ok
	if FileAccess.file_exists("user://locale_asset_compile_probe.gd"):
		DirAccess.remove_absolute("user://locale_asset_compile_probe.gd")
	return ok


## The <name>.<locale>.<ext> convention, against real files, in four languages.
static func _run_asset_runtime() -> bool:
	var ok: bool = true
	var base: String = ART_DIR + "/sign.tres"

	TranslationServer.set_locale("en")
	ok = _check("a language with no variant gets the base file", _localized(base), base) and ok
	TranslationServer.set_locale("de")
	ok = _check("a language with a variant gets the variant", _localized(base), ART_DIR + "/sign.de.tres") and ok
	TranslationServer.set_locale("pt_BR")
	ok = _check("pt_BR narrows to the pt variant", _localized(base), ART_DIR + "/sign.pt.tres") and ok
	TranslationServer.set_locale("ja")
	ok = _check("a language nobody made art for gets the base file", _localized(base), base) and ok
	ok = _check("a base file that is not there is returned untouched, not an error",
		_localized(ART_DIR + "/nothing_here.png"), ART_DIR + "/nothing_here.png") and ok

	# Load For Language hands back the ASSET, not the path - the same choice, resolved.
	TranslationServer.set_locale("de")
	ok = _check("Load For Language loads the German asset", _loaded_name(base), "SIGN_DE") and ok
	TranslationServer.set_locale("pt_BR")
	ok = _check("and the Portuguese one for a pt_BR player", _loaded_name(base), "SIGN_PT") and ok
	TranslationServer.set_locale("ja")
	ok = _check("and the base asset when that language has none", _loaded_name(base), "SIGN_BASE") and ok
	return ok


## The voice half: whether this language ships a clip, and how long it runs.
static func _run_voice_runtime() -> bool:
	var ok: bool = true

	TranslationServer.set_locale("de")
	ok = _check("a dubbed language reports a voice line", _has_voice(), true) and ok
	ok = _check("and its length comes off the clip", _voice_length(), 0.25) and ok
	TranslationServer.set_locale("de_AT")
	ok = _check("a regional locale counts the language's folder as its own", _has_voice(), true) and ok
	ok = _check("and reads the same clip", _voice_length(), 0.25) and ok
	TranslationServer.set_locale("ja")
	ok = _check("a language with no dub reports no voice line", _has_voice(), false) and ok
	ok = _check("and answers 0.0 seconds rather than stalling a Wait", _voice_length(), 0.0) and ok
	TranslationServer.set_locale("pt")
	ok = _check("a file that is not audio still answers 0.0 rather than calling get_length on it",
		_voice_length(), 0.0) and ok
	return ok


## How long a caption has to stay up - the number that has to change with the language.
static func _run_reading_time_runtime() -> bool:
	var ok: bool = true
	ok = _check("42 characters at 14 a second is 3 seconds", _reading_time(_quote(LINE_DE)), 3.0) and ok
	ok = _check("a three-character line lands on the floor instead", _reading_time(_quote(LINE_EN)), 1.2) and ok
	ok = _check("empty text is still the floor, never zero", _reading_time("\"\""), 1.2) and ok
	ok = _check("a slower pace holds it longer",
		_eval_float(_emitted("ReadingTimeOf", {"text": _quote(LINE_DE), "chars_per_second": "7.0", "minimum_seconds": "1.2"})), 6.0) and ok
	ok = _check("a zero pace cannot divide by zero",
		_eval_float(_emitted("ReadingTimeOf", {"text": _quote(LINE_DE), "chars_per_second": "0.0", "minimum_seconds": "1.2"})), 42.0) and ok
	# CJK: length() counts CHARACTERS, not bytes, so a four-glyph line is four - it does not read as
	# twelve UTF-8 bytes and hold the caption three times too long.
	ok = _check("a CJK line is measured in characters, not bytes", _reading_time(_quote(LINE_JA)), 1.2) and ok
	ok = _check("and the character count is the glyph count",
		_eval_float("float(\"%s\".length())" % LINE_JA), 4.0) and ok
	return ok


## Say Line itself, run: the caption goes up with the line and comes down with it, and the wait is
## the CLIP's when there is one and the translated line's READING time when there is not. The clip's
## player, the tree and the timer are stood in for, so the emitted code runs with no scene tree -
## which the suite does not have (its tests run before the main loop exists).
static func _run_say_line_runtime() -> bool:
	var ok: bool = true

	# A language that ships a clip: the caption is held until the player says it is finished.
	TranslationServer.set_locale("de")
	var dubbed: RefCounted = _say_line_stub()
	if dubbed == null:
		return _check("the Say Line harness compiles", false, true)
	var label: Label = Label.new()
	dubbed.set("caption", label)
	dubbed.call("say")
	ok = _check("the translated line is on the Label the moment it starts", label.text, LINE_DE) and ok
	ok = _check("the language's clip is on the player", str(dubbed.call("stream_length")), "0.25") and ok
	ok = _check("and it is playing", int(dubbed.get("plays")), 1) and ok
	ok = _check("no timer was started - the clip is the clock", float(dubbed.get("timer_seconds")), -1.0) and ok
	dubbed.emit_signal("finished")
	ok = _check("the caption comes down when the clip ends", label.text, "") and ok

	# The same row in a language with no dub: the caption still runs, timed off its own length.
	TranslationServer.set_locale("ja")
	var subtitled: RefCounted = _say_line_stub()
	subtitled.set("caption", label)
	subtitled.call("say")
	ok = _check("a language with no clip still shows the line", label.text, tr_probe(LINE_KEY)) and ok
	ok = _check("nothing was played", int(subtitled.get("plays")), 0) and ok
	ok = _check("and the wait is that line's reading time", float(subtitled.get("timer_seconds")), 1.2) and ok
	subtitled.emit_signal("timeout")
	ok = _check("the caption comes down when the wait ends", label.text, "") and ok

	# THE drift case: the same row, a language whose line is far longer, holds the caption longer.
	# A hand-typed Wait would have cut this one off in a language nobody on the team reads.
	TranslationServer.set_locale("de")
	var long_line: RefCounted = _say_line_stub(VOICE_DIR + "/none")
	long_line.set("caption", label)
	long_line.call("say")
	ok = _check("a longer translation is given the time it needs", float(long_line.get("timer_seconds")), 3.0) and ok
	long_line.emit_signal("timeout")

	# A styled subtitle is a RichTextLabel, which is the control most subtitle rows really point at.
	# The row must work on it exactly as on a Label - it only ever touches `text`.
	TranslationServer.set_locale("de")
	var rich_row: RefCounted = _say_line_stub()
	var rich: RichTextLabel = RichTextLabel.new()
	rich_row.set("caption", rich)
	rich_row.call("say")
	ok = _check("a RichTextLabel caption is filled like any other", rich.text, LINE_DE) and ok
	rich_row.emit_signal("finished")
	ok = _check("...and cleared like any other", rich.text, "") and ok
	rich.free()

	# No caption at all is the voice-only row: it must not touch a null control.
	var voice_only: RefCounted = _say_line_stub()
	voice_only.call("say")
	ok = _check("a row with no caption still plays", int(voice_only.get("plays")), 1) and ok
	voice_only.emit_signal("finished")
	label.free()
	return ok


## A data cell that holds a KEY - and one that still holds plain English, which is what every
## shipped data-asset pack stores today and what this verb must not break.
static func _run_translated_field_runtime() -> bool:
	var ok: bool = true
	var record: String = "{\"title\": \"%s\", \"id\": \"bridge\"}" % TITLE_KEY

	TranslationServer.set_locale("de")
	ok = _check("a cell holding a key reads as the player's language", _field(record, "\"title\""), TITLE_DE) and ok
	TranslationServer.set_locale("pt_BR")
	ok = _check("the same .tres serves the next language with no new column", _field(record, "\"title\""), TITLE_PT) and ok
	TranslationServer.set_locale("ja")
	ok = _check("a key no catalog covers shows the key itself, not blank text", _field(record, "\"title\""), TITLE_KEY) and ok

	TranslationServer.set_locale("de")
	ok = _check("a cell still holding plain English comes back unchanged",
		_field("{\"title\": \"%s\"}" % TITLE_LITERAL, "\"title\""), TITLE_LITERAL) and ok
	ok = _check("a field the record does not have is empty text, not <null>",
		_field(record, "\"nope\""), "") and ok
	ok = _check("an empty record is empty text too", _field("{}", "\"title\""), "") and ok
	ok = _check("a number in the cell is read as text", _field("{\"title\": 42}", "\"title\""), "42") and ok

	# A data ASSET on disk reads the same way a table row does: the single-argument get() answers
	# null for a field neither shape has, so one verb serves a .tres and a CSV record alike.
	ok = _check("a data asset reads by property name",
		_field("load(\"%s\")" % (ART_DIR + "/entry.tres"), "\"resource_name\""), TITLE_DE) and ok
	ok = _check("a property the asset does not have is empty text",
		_field("load(\"%s\")" % (ART_DIR + "/entry.tres"), "\"no_such_property\""), "") and ok

	# A whole column: keys translate, literals pass through, a row missing the field stays in place
	# so the list is still the same length as the table.
	var table: String = "[{\"label\": \"%s\"}, {\"label\": \"%s\"}, {}]" % [TITLE_KEY, TITLE_LITERAL]
	var column: Variant = _eval(_emitted("TranslatedColumn", {"table": table, "column": "\"label\""}))
	ok = _check("a column comes back translated, in row order", column, [TITLE_DE, TITLE_LITERAL, ""] as Array) and ok
	ok = _check("and stays as long as the table it came from",
		(column as Array).size() if column is Array else -1, 3) and ok
	return ok


# -- fixtures ------------------------------------------------------------------------------------


## The catalogs the runtime cases read. Added to the live TranslationServer because that is what the
## emitted tr() calls reach; removed again in run().
static func _add_catalogs() -> void:
	var german: Translation = Translation.new()
	german.locale = "de"
	german.add_message(StringName(LINE_KEY), StringName(LINE_DE))
	german.add_message(StringName(TITLE_KEY), StringName(TITLE_DE))
	var english: Translation = Translation.new()
	english.locale = "en"
	english.add_message(StringName(LINE_KEY), StringName(LINE_EN))
	var portuguese: Translation = Translation.new()
	portuguese.locale = "pt"
	portuguese.add_message(StringName(TITLE_KEY), StringName(TITLE_PT))
	for catalog: Translation in [german, english, portuguese]:
		TranslationServer.add_translation(catalog)


static func _remove_catalogs() -> void:
	for locale: String in ["de", "en", "pt"]:
		var catalog: Translation = TranslationServer.get_translation_object(locale)
		if catalog != null:
			TranslationServer.remove_translation(catalog)


## Three language variants of one asset, and a voice folder that covers de but not ja - plus a pt
## folder holding something that is NOT audio, for the guard in Voice Line Length.
static func _write_assets() -> void:
	DirAccess.make_dir_recursive_absolute(ART_DIR)
	DirAccess.make_dir_recursive_absolute(VOICE_DIR + "/de")
	DirAccess.make_dir_recursive_absolute(VOICE_DIR + "/pt")
	for pair: Array in [["/sign.tres", "SIGN_BASE"], ["/sign.de.tres", "SIGN_DE"], ["/sign.pt.tres", "SIGN_PT"]]:
		var asset: Resource = Resource.new()
		asset.resource_name = str(pair[1])
		ResourceSaver.save(asset, ART_DIR + str(pair[0]))
	# 2000 frames of silence at 8 kHz, 16-bit mono: exactly 0.25 seconds.
	var clip: AudioStreamWAV = AudioStreamWAV.new()
	clip.format = AudioStreamWAV.FORMAT_16_BITS
	clip.mix_rate = 8000
	clip.stereo = false
	var frames: PackedByteArray = PackedByteArray()
	frames.resize(4000)
	clip.data = frames
	ResourceSaver.save(clip, VOICE_DIR + "/de/" + LINE_KEY + ".tres")
	var not_audio: Resource = Resource.new()
	not_audio.resource_name = "NOT_A_CLIP"
	ResourceSaver.save(not_audio, VOICE_DIR + "/pt/" + LINE_KEY + ".tres")
	# A data asset whose text field holds a translation key rather than display text.
	var entry: Resource = Resource.new()
	entry.resource_name = TITLE_KEY
	ResourceSaver.save(entry, ART_DIR + "/entry.tres")


static func _remove_assets() -> void:
	for path: String in [ART_DIR + "/sign.tres", ART_DIR + "/sign.de.tres", ART_DIR + "/sign.pt.tres",
			ART_DIR + "/entry.tres", VOICE_DIR + "/de/" + LINE_KEY + ".tres",
			VOICE_DIR + "/pt/" + LINE_KEY + ".tres"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	for folder: String in [ART_DIR, VOICE_DIR + "/de", VOICE_DIR + "/pt", VOICE_DIR, PROBE_ROOT]:
		DirAccess.remove_absolute(folder)


# -- runners -------------------------------------------------------------------------------------


## The resolved path for a base asset, through the shipped Localized File template.
static func _localized(base_path: String) -> String:
	return str(_eval(_emitted("LocalizedFile", {"path": _quote(base_path)})))


## The resource_name of whatever Load For Language hands back for a base asset.
static func _loaded_name(base_path: String) -> String:
	var loaded: Variant = _eval(_emitted("LoadLocalized", {"path": _quote(base_path)}))
	return str((loaded as Resource).resource_name) if loaded is Resource else "<nothing loaded>"


static func _has_voice(folder: String = VOICE_DIR) -> bool:
	return bool(_eval(_emitted("HasVoiceForLanguage", {"key": _quote(LINE_KEY), "folder": _quote(folder), "extension": "\".tres\""})))


static func _voice_length(folder: String = VOICE_DIR) -> float:
	return _eval_float(_emitted("VoiceLineLength", {"key": _quote(LINE_KEY), "folder": _quote(folder), "extension": "\".tres\""}))


static func _reading_time(text_expression: String) -> float:
	return _eval_float(_emitted("ReadingTimeOf", {"text": text_expression, "chars_per_second": "14.0", "minimum_seconds": "1.2"}))


static func _field(record_expression: String, field_expression: String) -> String:
	return str(_eval(_emitted("TranslatedField", {"record": record_expression, "field": field_expression})))


## What tr() answers for a key right now - the value the caption cases compare against, read the
## same way the emitted code reads it rather than restated as a literal.
static func tr_probe(key: String) -> String:
	return str(_eval("tr(\"%s\")" % key))


## Say Line's emitted body, running in a stand-in for the AudioStreamPlayer it is hosted on: the
## stream, play(), the finished signal, get_tree() and create_timer() are all answered here, so the
## action's real control flow can be stepped through without a scene tree.
static func _say_line_stub(folder: String = VOICE_DIR) -> RefCounted:
	var body: String = _emitted("SayLine", {"key": _quote(LINE_KEY), "folder": _quote(folder),
		"extension": "\".tres\"", "caption": "caption", "target": "", "uid": "1"})
	var lines: Array[String] = [
		"@tool",
		"extends RefCounted",
		"",
		"signal finished",
		"signal timeout",
		"",
		"var caption: Variant = null",
		"var stream: Variant = null",
		"var plays: int = 0",
		"var timer_seconds: float = -1.0",
		"",
		"func get_tree() -> Variant:",
		"\treturn self",
		"",
		"func create_timer(seconds: float) -> Variant:",
		"\ttimer_seconds = seconds",
		"\treturn self",
		"",
		"func play() -> void:",
		"\tplays += 1",
		"",
		"func stream_length() -> String:",
		"\treturn str((stream as AudioStream).get_length()) if stream is AudioStream else \"<no stream>\"",
		"",
		"func say() -> void:",
	]
	for statement: String in body.split("\n"):
		lines.append("\t" + statement)
	var script: GDScript = GDScript.new()
	script.source_code = "\n".join(lines) + "\n"
	if script.reload() != OK:
		print("  [FAIL] locale_asset_aces_test: the Say Line body did not compile:\n%s" % script.source_code)
		return null
	return script.new()


# -- helpers -------------------------------------------------------------------------------------


## Every descriptor, by ace_id, read from the LIVE registry - so a module that failed to
## auto-discover fails here rather than passing against a direct load of its file.
static func _by_id() -> Dictionary:
	var by_id: Dictionary = {}
	for descriptor: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		by_id[descriptor.ace_id] = descriptor
	return by_id


## The emitted code for one ACE with a row's params substituted - the real compiler path.
static func _emitted(ace_id: String, params: Dictionary) -> String:
	var by_id: Dictionary = _by_id()
	if not by_id.has(ace_id):
		return ""
	return ActionCodegen._apply_template(str(by_id[ace_id].codegen_template), params)


## Runs an emitted expression for real: builds it into a GDScript, reloads it, and returns what it
## evaluates to. tr() needs an Object to be called on, which is why the probe is a RefCounted.
static func _eval(expression: String) -> Variant:
	var script: GDScript = GDScript.new()
	script.source_code = "@tool\nextends RefCounted\n\n\nfunc probe() -> Variant:\n\treturn %s\n" % expression
	if script.reload() != OK:
		print("  [FAIL] locale_asset_aces_test: an emitted expression did not compile: %s" % expression)
		return null
	return script.new().call("probe")


static func _eval_float(expression: String) -> float:
	var value: Variant = _eval(expression)
	return float(value) if value is float or value is int else -1.0


## True when a whole emitted script parses as GDScript.
static func _parses(source: String) -> bool:
	var script: GDScript = GDScript.new()
	script.source_code = source
	return script.reload() == OK


## A GDScript string literal for arbitrary text.
static func _quote(text: String) -> String:
	return "\"%s\"" % text.c_escape()


static func _display_name(by_id: Dictionary, ace_id: String) -> String:
	return str(by_id[ace_id].display_name) if by_id.has(ace_id) else ""


static func _category(by_id: Dictionary, ace_id: String) -> String:
	return str(by_id[ace_id].category) if by_id.has(ace_id) else ""


static func _param_default(by_id: Dictionary, ace_id: String, param_id: String) -> String:
	for param: ACEParam in _params(by_id, ace_id):
		if param.id == param_id:
			return str(param.default_value)
	return ""


static func _param_hint(by_id: Dictionary, ace_id: String, param_id: String) -> String:
	for param: ACEParam in _params(by_id, ace_id):
		if param.id == param_id:
			return str(param.hint)
	return ""


static func _autocomplete_size(by_id: Dictionary, ace_id: String, param_id: String) -> int:
	for param: ACEParam in _params(by_id, ace_id):
		if param.id == param_id:
			return param.autocomplete.size()
	return -1


static func _params(by_id: Dictionary, ace_id: String) -> Array[ACEParam]:
	var empty: Array[ACEParam] = []
	return by_id[ace_id].params if by_id.has(ace_id) else empty


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("  [FAIL] locale_asset_aces_test: %s (got %s, expected %s)" % [label, str(actual), str(expected)])
	return false
