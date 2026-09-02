# EventForge module - the parts of a localised game that are NOT strings: files, voice, data cells.
#
# translation_aces.gd wraps tr()/tr_n() and TranslationServer; text_format_aces.gd owns the
# translate-first-fill-second patterns. Everything here is about the content AROUND the lookup:
#
#  - AN ASSET THAT HAS A LANGUAGE. Localized File / Load For Language resolve a language variant
#    sitting beside the base file as <name>.<locale>.<ext> (sign.ja.png, sign.pt_BR.png), narrowing
#    pt_BR to pt to the base file. One row serves an image, an audio clip, a font or a whole scene.
#  - A VOICE LINE THAT CANNOT OUT-RUN ITS SUBTITLE. Say Line takes the caption's timing off the CLIP
#    instead of off a hand-typed Wait, so a translation that is longer in German is never cut off;
#    a language that ships no dub holds the caption for its READING time instead, which is also the
#    whole accessibility-subtitle path. Has Voice For Language is the gate between the two, Voice
#    Line Length paces a cutscene off the audio, and Reading Time Of answers the same question for
#    any text that has to stay on screen (a toast, a tutorial hint, a bark).
#  - A DATA CELL THAT HOLDS A KEY. Translated Field Of / Translated Column Of Table read a field as a
#    translation KEY, so one .tres serves every language instead of growing a column per locale.
#
# WHY A PARALLEL CONVENTION RATHER THAN GODOT'S REMAP TABLE (the #11 decision, probed on 4.7).
# Godot ships per-locale resource remapping: ProjectSettings > Localization > Remaps writes
# `internationalization/locale/translation_remaps`, and ResourceLoader resolves it INSIDE load() /
# ResourceLoader.exists(). Probed on 4.7 stable: it works when running from source (not only in an
# exported build), it re-resolves on every call so it follows a live Set Language, and it narrows
# pt_BR to a "pt" entry the same way compare_locales scores. It is a good mechanism.
# It is also unreachable from a row: it is a project-settings table with no runtime API a verb could
# call, so a "use the remap" verb would emit a bare load() and add nothing. These verbs therefore
# provide the simpler convention, which needs zero project configuration and is visible in the sheet.
# Crucially they do not DISABLE the engine's table: when no <name>.<locale>.<ext> sibling exists the
# expression yields the BASE path, and the caller's plain load() still goes through the remap. Probed:
# a base with a remap to a differently-named file (flag.tres -> flag_german.tres) and no flag.de.tres
# on disk still loaded the German one under locale "de". The sibling file wins when it exists (it is
# the more specific statement), the remap wins otherwise, and a project can use either or both.
#
# Every template is plain GDScript with nothing from the plugin at runtime (the parity covenant).
# The path/voice/field resolutions are COMPOSED here once, as strings, so the verbs that share a rule
# can never drift apart - the same shape table_aces.gd uses for Table From File / Table From Text.
# ace_ids and codegen_templates are a compatibility covenant: frozen once shipped (deprecate, never
# rename). Module contract: see ace_factory.gd.
@tool
class_name EventForgeLocaleAssetACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

const CAT_TRANSLATION := "Translation"
const CAT_VOICE := "Translation: Voice"
const CAT_TEXT := "Text"

## The clip-container suggestions for the voice verbs. Values are inserted verbatim, so each entry
## is a GDScript string literal. An editable suggest-combo rather than a fixed dropdown: these three
## are what a voice bank is imported as, but a project holding its clips as .tres AudioStream
## resources (or anything else Godot can load) must still be able to type its own.
const CLIP_FORMAT_SUGGESTIONS: Array[String] = ["\".ogg\"", "\".wav\"", "\".mp3\""]

## How fast a reader gets through a caption, and the shortest a caption may ever stay up. Written
## into Say Line's no-clip branch as plain numbers (its row already carries five fields); Reading
## Time Of exposes both as parameters for anyone who wants to tune them.
const DEFAULT_READING_SPEED := "14.0"
const DEFAULT_READING_FLOOR := "1.2"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# -- An asset that has a language --
	descriptors.append(F.expr("LocalizedFile", "Localized File", localized_path_expression("{path}"), CAT_TRANSLATION, "localized file for [b]{path}[/b]", "The path that exists for the player's language. A language variant sits beside the base file as <name>.<locale>.<ext> - sign.ja.png, sign.pt_BR.png - and a player on pt_BR falls back to sign.pt.png and then to the base file, so no variant on disk simply means the base file rather than a missing-file error. Use it when you want the PATH; Load For Language when you want the asset.").param_built(_path_param()))

	descriptors.append(F.expr("LoadLocalized", "Load For Language", "load(%s)" % localized_path_expression("{path}"), CAT_TRANSLATION, "load [b]{path}[/b] for the current language", "Loads the variant of an asset that matches the player's language - a translated sign, a dubbed line, a font with the glyphs that language needs, a re-lettered scene. Name the variant <name>.<locale>.<ext> beside the base file and nothing else has to change. Run it under On Language Changed: a preload freezes its choice when the script loads and never follows a live switch. A project that uses Project Settings > Localization > Remaps instead still gets its remap here, because the no-variant answer is the plain base path.").param_built(_path_param()).featured())

	# -- A voice line that cannot out-run its subtitle --
	descriptors.append(F.act("SayLine", "Say Line", _say_line_template(), CAT_VOICE, "say [b]{key}[/b] with its subtitle", "Plays this key's clip in the player's language and holds the translated line on a label for exactly as long as the clip runs, so a longer translation is never cut off and a shorter one never lingers. A language with no clip holds the caption for its own reading time instead (about 14 characters a second, never under 1.2s), which is also the whole accessibility-subtitle path. The caption goes up with the line and comes down with it, so the two can never drift apart.", "AudioStreamPlayer").param_built(_voice_key_param()).param_built(_voice_folder_param()).param_built(_clip_format_param()).param("caption", "null", "Caption on", "The label the subtitle lands on, e.g. $HUD/Subtitle - a Label, a RichTextLabel, anything with text. Leave it null for voice with no caption.", "expression").param_built(_target_param()).featured())

	descriptors.append(F.cond("HasVoiceForLanguage", "Has Voice For Language", "not %s.is_empty()" % voice_clip_expression("{folder}", "{key}", "{extension}"), CAT_VOICE, "there is a voice line for [b]{key}[/b] in this language", "True when the player's language actually ships a clip for this key - the gate under \"dub it if we have it, subtitle it if we do not\", so a partly dubbed build degrades on purpose instead of going silent. A player on de_AT counts the de folder as theirs.").param_built(_voice_key_param()).param_built(_voice_folder_param()).param_built(_clip_format_param()))

	descriptors.append(F.expr("VoiceLineLength", "Voice Line Length", _voice_length_expression("{folder}", "{key}", "{extension}"), CAT_VOICE, "length of the voice line for [b]{key}[/b]", "How many seconds this key's clip runs in the player's language, for pacing a cutscene off the audio rather than off a guess. A language that ships no clip answers 0.0, so a Wait built on it does not stall a subtitle-only build.").param_built(_voice_key_param()).param_built(_voice_folder_param()).param_built(_clip_format_param()))

	descriptors.append(F.expr("ReadingTimeOf", "Reading Time Of", reading_time_expression("{text}", "{chars_per_second}", "{minimum_seconds}"), CAT_TEXT, "reading time of [b]{text}[/b]", "How long a caption should stay up for text this long, with a floor so a short line is still readable. Feed it the TRANSLATED text and every language gets the time it needs - the honest answer for a toast, a tutorial hint, a bark, or a subtitle in a language you never dubbed.").param("text", "\"You there! Over here!\"", "Text", "The text that has to be read - usually an already translated line, since a translation is a different LENGTH in every language.", "expression").param_typed("String", "chars_per_second", DEFAULT_READING_SPEED, "Characters per second", "How fast a reader gets through it. 14 is a comfortable subtitle pace; lower it for a young audience, or for a language whose characters each carry a whole word.", "expression").param_typed("String", "minimum_seconds", DEFAULT_READING_FLOOR, "Never shorter than", "The floor, so a two-word line is still readable rather than a flash.", "expression"))

	# -- A data cell that holds a key --
	descriptors.append(F.expr("TranslatedField", "Translated Field Of", translated_field_expression("{record}", "{field}"), CAT_TRANSLATION, "translated [b]{field}[/b] of [b]{record}[/b]", "Reads a field as a translation KEY and hands back the player's language, so one .tres serves every language and the grid never needs a column per locale. It is safe to put on a pack that still stores plain English in that cell: an entry no catalog contains comes back exactly as it was written. A key with no entry comes back as the key itself, which is how a missing translation should show up - a visible \"quest.bridge.title\" rather than blank text.").param("record", "item", "Record", "One record: a table row (Table From File, Row Where), a data asset (a Quest, a price entry, a storylet), or the current item of a For Each.", "expression").param("field", "\"title\"", "Field", "Which field holds the text. Reading a field on a data asset and on a table row is the same row here.", "expression"))

	descriptors.append(F.expr("TranslatedColumn", "Translated Column Of Table", "{table}.map(func(__record): return %s)" % translated_field_expression("__record", "{column}"), CAT_TRANSLATION, "translated column [b]{column}[/b] of [b]{table}[/b]", "A whole column read as translated text, in row order - a dropdown's items, a quest log, a shop list. Column Of Table gives you the cells; this gives you the words. A row missing that field contributes empty text rather than dropping out, so the list stays the same length as the table.").param("table", "table", "Table", "The rows-of-records variable a Table From File (or Table From Text) expression filled, or a list of data assets.", "variable_reference:Array").param("column", "\"label\"", "Column", "The field holding the text, spelled as it is in the header row.", "expression"))

	return descriptors


## Section blurbs shown when the picker header is selected (the optional module hook).
static func section_descriptions() -> Dictionary:
	return {
		CAT_VOICE: "Spoken lines and the captions that have to match them, in whatever language the player is running."
	}


## The <name>.<locale>.<ext> resolution as ONE expression: the exact-locale variant if it is there,
## else the language-only variant (pt_BR narrows to pt), else the base path untouched. Composed here
## rather than typed twice so Localized File and Load For Language can never disagree; the STRING
## this returns is the frozen artifact, so change it only the way a shipped template changes.
##
## The base path is bound by a lambda so the caller's expression is written ONCE and evaluated once -
## spelled out inline it would appear nine times in the emitted line. The inner lambda names the two
## candidates for the same reason: each is tested and then returned.
static func localized_path_expression(path_expression: String) -> String:
	var candidates: String = "__base.get_basename() + \".\" + TranslationServer.get_locale() + \".\" + __base.get_extension(), __base.get_basename() + \".\" + TranslationServer.get_locale().get_slice(\"_\", 0) + \".\" + __base.get_extension()"
	return "(func(__base: String) -> String: return %s.call(%s)).call(%s)" % [_first_existing_expression("__base"), candidates, path_expression]


## The voice-clip resolution: <folder>/<locale>/<key><extension>, narrowing the locale the same way,
## and "" when the player's language ships no clip at all. "" rather than the base path is the whole
## point - a language with no dub has to be TELLABLE from one with a dub, so the caption path can run.
static func voice_clip_expression(folder_expression: String, key_expression: String, extension_expression: String) -> String:
	var candidates: String = "__folder.path_join(TranslationServer.get_locale()).path_join(__file), __folder.path_join(TranslationServer.get_locale().get_slice(\"_\", 0)).path_join(__file)"
	return "(func(__folder: String, __file: String) -> String: return %s.call(%s)).call(%s, %s + %s)" % [
		_first_existing_expression("\"\""), candidates, folder_expression, key_expression, extension_expression]


## One field of a record as translated text, whatever the record IS. The single-argument get() is the
## point: Dictionary.get(key) and Object.get(property) both answer null for something that is not
## there, so a table row and a data asset (a QuestResource, a price entry, a storylet) read the same
## way and neither errors on a field it does not have. null becomes "" so a missing cell is empty
## text rather than the literal "<null>" str() would produce.
static func translated_field_expression(record_expression: String, field_expression: String) -> String:
	return "(func(__value: Variant) -> String: return tr(str(__value)) if __value != null else \"\").call(%s.get(%s))" % [record_expression, field_expression]


## How long text of this length needs to stay on screen, floored so a very short line is not a flash.
static func reading_time_expression(text_expression: String, speed_expression: String, minimum_expression: String) -> String:
	return "maxf(%s, %s.length() / maxf(%s, 1.0))" % [minimum_expression, text_expression, speed_expression]


## The seconds a key's clip runs, or 0.0 when the language ships none. Two lambdas: the outer names
## the resolved path (so the resolution is written once), the inner names the loaded resource, so a
## path that turns out not to be an audio stream answers 0.0 instead of calling a method on null.
static func _voice_length_expression(folder_expression: String, key_expression: String, extension_expression: String) -> String:
	var loaded: String = "load(__clip_path) if not __clip_path.is_empty() else null"
	return "(func(__clip_path: String) -> float: return (func(__clip: Variant) -> float: return __clip.get_length() if __clip is AudioStream else 0.0).call(%s)).call(%s)" % [
		loaded, voice_clip_expression(folder_expression, key_expression, extension_expression)]


## The shared tail of both resolutions: a lambda taking the exact-locale and language-only candidates
## and returning the first that exists on disk, or `fallback_expression` when neither does.
static func _first_existing_expression(fallback_expression: String) -> String:
	return "(func(__exact: String, __language: String) -> String: return __exact if ResourceLoader.exists(__exact) else (__language if ResourceLoader.exists(__language) else %s))" % fallback_expression


## Say Line, authored with its own "On node" target so the row can point at any AudioStreamPlayer.
## (The automatic cross-node pass in builtin_aces.gd only prefixes templates whose every line is a
## member operation, and this one opens with `var`, so the target has to be declared here.)
##
## The caption is bound to a local before the first await: the row's expression is read ONCE, at the
## moment the line starts, so nothing can re-point it half way through and leave a caption stranded
## on screen. Both branches end at the same clearing lines, which is what makes the clip and its
## subtitle impossible to drift apart.
##
## That local is deliberately untyped. Typing it `Label` looks tidier and breaks the common case: a
## subtitle that wants an outline or BBCode is a RichTextLabel, and GDScript refuses the assignment
## outright ("Trying to assign value of type 'RichTextLabel' to a variable of type 'Label'"), which
## aborts the row before the clip ever plays. The template only ever touches `.text`, which every
## text control answers to.
static func _say_line_template() -> String:
	var reading_time: String = reading_time_expression("tr({key})", DEFAULT_READING_SPEED, DEFAULT_READING_FLOOR)
	return "\n".join([
		"var __voice_path_{uid}: String = %s" % voice_clip_expression("{folder}", "{key}", "{extension}"),
		"var __voice_caption_{uid}: Variant = {caption}",
		"if __voice_caption_{uid} != null:",
		"\t__voice_caption_{uid}.text = tr({key})",
		"if __voice_path_{uid}.is_empty():",
		"\tawait get_tree().create_timer(%s).timeout" % reading_time,
		"else:",
		"\t{target.}stream = load(__voice_path_{uid})",
		"\t{target.}play()",
		"\tawait {target.}finished",
		"if __voice_caption_{uid} != null:",
		"\t__voice_caption_{uid}.text = \"\"",
	])


## The base asset every language-variant verb resolves from.
static func _path_param() -> ACEParam:
	return F.make_param("path", "String", "\"res://art/sign.png\"", "File", "The base file. A language variant sits beside it as <name>.<locale>.<ext> - sign.ja.png, sign.pt_BR.png. No variant on disk means this file.", "expression")


## The line's key: the same string the translation catalog holds AND the clip's file name.
static func _voice_key_param() -> ACEParam:
	return F.make_param("key", "String", "\"ilsa.greet.01\"", "Line", "The line's key - the catalog holds its words under this name and the folder holds its clip under this file name.", "expression")


## Where the per-language clip folders live.
static func _voice_folder_param() -> ACEParam:
	return F.make_param("folder", "String", "\"res://voice\"", "Voice folder", "One subfolder per language inside it: voice/en/, voice/ja/. A language with no folder is subtitle-only.", "expression")


## Which container the clips were imported as. Pick one or type your own.
static func _clip_format_param() -> ACEParam:
	return F.make_param("extension", "String", "\".ogg\"", "Clip format", "The file extension the clips use in that folder. Pick one or type your own.", "", [], CLIP_FORMAT_SUGGESTIONS)


## The optional "On node" target, worded exactly as the automatic cross-node pass words it.
static func _target_param() -> ACEParam:
	return F.make_param("target", "String", "", "On node", "Act on another node instead of this one. Leave blank for this node, pick a node, or address one without a tree path - e.g. get_tree().get_first_node_in_group(\"player\").", "expression")
