# EventForge module - Translation QUALITY: is the catalog actually finished?
#
# The translation vocabulary next door (Set Language, Translate, On Language Changed) assumes the
# catalog is done. Nothing in the project could ASK. This module is the three verbs that ask:
#
#   Translation Coverage        how much of the catalog a language fills, 0 to 100
#   Missing Translation Keys    the actual list of source strings that language has not filled
#   Translation Is Complete     the gate - true only when every source string has a filled cell
#
# WHY A LIST AND NOT JUST A NUMBER. A percentage tells a team there is a problem; a list tells them
# where it is. The same three numbers pay off in three unrelated places: an On Project Export bake
# step that refuses to ship a release build with an unfinished shipped language, a File > Run tool
# that prints a per-language report, and an in-game debug overlay a tester can open on a build.
#
# WHAT A "CATALOG" IS HERE. The translator's spreadsheet, in Godot's own CSV shape: the first line is
# the column names, the FIRST column is the source string (Godot ignores that header cell, so it is
# usually spelled "keys"), and every other column is one language. A row whose source string is blank
# is not a translatable unit and is skipped, so a trailing ",,," line a spreadsheet export leaves
# behind can never drag a finished language below 100.
#
# THE PARSE IS THE SHIPPED ONE. The rows come from EventForgeTableACEs.table_expression - the exact
# expression Table From File uses - so quoted cells containing a comma, doubled "" quotes, CRLF line
# endings and a missing trailing newline behave in the build gate exactly as they do in the game, and
# a fix to that parse policy reaches both at once. A missing or unreadable file reads as no rows.
#
# THE MISSING-FILE ANSWER IS DELIBERATE. No rows means coverage 0 and Translation Is Complete FALSE,
# never "complete". A mistyped path in an export gate must FAIL the build loudly; the opposite
# convention (an empty catalog is vacuously complete) would let a typo ship a half-translated game
# while the gate reported success.
#
# Every template is a single plain expression: no plugin runtime, no helper library, no state, so the
# emitted code keeps working after the plugin is deleted (the parity covenant). ace_ids and
# codegen_templates are a compatibility covenant: frozen once shipped (deprecate, never rename).
# Module contract: see ace_factory.gd.
@tool
class_name EventForgeTranslationQualityACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")
## Loaded by PATH, not by class_name: the module is discovered by glob and must register even when
## the editor's class cache has not been rebuilt since the file appeared.
const TABLES := preload("res://addons/eventforge/registration/modules/table_aces.gd")

const CAT := "Translation"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	descriptors.append(F.make_descriptor("Core", "TranslationCoverage", "Translation Coverage", ACEDescriptor.ACEType.EXPRESSION,
		_coverage_expression(), "",
		_catalog_params("\"fr\""),
		CAT, "translation coverage for [b]{locale}[/b]")
		.described("How much of the translator's spreadsheet that language actually fills, as a number from 0 to 100. A cell holding only spaces counts as unfilled, and a file that is missing or unreadable reads as 0 rather than as finished. Reads the .csv exactly the way Table From File reads it, so the number in a build gate is the number the game sees."))

	descriptors.append(F.make_descriptor("Core", "MissingTranslationKeys", "Missing Translation Keys", ACEDescriptor.ACEType.EXPRESSION,
		_missing_expression(), "",
		_catalog_params("\"fr\""),
		CAT, "missing [b]{locale}[/b] translations in [b]{path}[/b]")
		.described("The list of source strings that language has NOT filled in, in file order - so the Output panel, a debug overlay or an export gate can NAME them instead of only counting them. Empty when the language is finished. Each entry is the first column of its row, which is the string the catalog is keyed by."))

	descriptors.append(F.make_descriptor("Core", "TranslationIsComplete", "Translation Is Complete", ACEDescriptor.ACEType.CONDITION,
		_is_complete_expression(), "",
		_catalog_params("\"fr\""),
		CAT, "[b]{locale}[/b] is fully translated")
		.described("True only when every source string in the spreadsheet has a filled cell for that language. An empty, missing or unreadable catalog is never \"complete\", so a mistyped path fails a build gate loudly instead of passing it. Put it under On Project Export beside Export Has Feature \"release\", inverted, and a release build can refuse to ship half-translated."))

	return descriptors


## The two operands every catalog verb takes, plus the separator picker Table From File uses. Built
## once so the three verbs can never drift into disagreeing about what they are reading.
static func _catalog_params(locale_default: String) -> Array[ACEParam]:
	return [
		F.make_param("locale", "String", locale_default, "Language", "The language column to score, spelled exactly as its column heading in the file - e.g. \"fr\" or \"zh_CN\".", "expression"),
		F.make_param("path", "String", "\"res://i18n/strings.csv\"", "Catalog", "The translator's .csv: first line is the column names, first column is the source string, one column per language.", "expression"),
		F.make_param("separator", "String", "\",\"", "Separator", "What separates the columns in that file.", "", TABLES.SEPARATOR_OPTIONS),
	]


## Every row of the catalog that is a translatable unit: the shipped Table From File parse, minus the
## rows carrying no source string. `values()[0]` is the FIRST column because the parse inserts columns
## in header order - the one assumption this module makes about the file, and the one Godot's own CSV
## format guarantees. The `is_empty()` guard in front of it covers the malformed case where every
## column heading is blank, which leaves records with nothing to index.
static func _catalog_rows() -> String:
	return "%s.filter(func(__entry): return not __entry.is_empty() and not str(__entry.values()[0]).strip_edges().is_empty())" \
		% TABLES.table_expression("FileAccess.get_file_as_string({path})", "{separator}")


## A row this language has not filled. Whitespace counts as unfilled: a translator who left a space
## in the cell has not translated the line, and a gate that called that "done" would be useless.
static func _unfilled_predicate() -> String:
	return "func(__entry): return str(__entry.get({locale}, \"\")).strip_edges().is_empty()"


## Coverage binds the parsed rows to one lambda parameter first, so the file is read and parsed ONCE
## even though the answer needs both the total and the unfilled count. Zero rows answers 0.0 rather
## than dividing by zero (and rather than the vacuous 100.0 that would let a mistyped path ship).
static func _coverage_expression() -> String:
	return "(func(__catalog): return (100.0 * float(__catalog.size() - __catalog.filter(%s).size()) / float(__catalog.size())) if not __catalog.is_empty() else 0.0).call(%s)" \
		% [_unfilled_predicate(), _catalog_rows()]


## The unfilled rows as their source strings - the list a report can print.
static func _missing_expression() -> String:
	return "%s.filter(%s).map(func(__entry): return str(__entry.values()[0]))" % [_catalog_rows(), _unfilled_predicate()]


## Complete is written as "has rows AND none of them are unfilled" rather than as coverage >= 100.0:
## it says the empty-catalog answer out loud instead of leaving it to a float comparison.
static func _is_complete_expression() -> String:
	return "(func(__catalog): return not __catalog.is_empty() and __catalog.filter(%s).is_empty()).call(%s)" \
		% [_unfilled_predicate(), _catalog_rows()]
