# Godot EventSheets - a count is worded in the right number, in every bundled language.
#
# The inherited bar used to read "1 variables · 2 functions". EventSheetL10n.counted picks the
# singular row ("1 variable") for exactly one and the plural row ("%d variables") otherwise, and
# every bundled language carries both rows so each words its own singular and plural.
@tool
class_name CountedPhraseTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	EventSheetL10n.rescan()
	EventSheetL10n.set_locale("en")
	var rows: Array = [
		["one variable is singular", EventSheetL10n.counted("1 variable", "%d variables", 1), "1 variable"],
		["zero variables is plural", EventSheetL10n.counted("1 variable", "%d variables", 0), "0 variables"],
		["two functions is plural", EventSheetL10n.counted("1 function", "%d functions", 2), "2 functions"],
		["one function is singular", EventSheetL10n.counted("1 function", "%d functions", 1), "1 function"],
	]
	for locale: String in ["de", "es", "fr", "it", "ja", "ko", "ru", "zh_CN"]:
		EventSheetL10n.set_locale(locale)
		var one: String = EventSheetL10n.counted("1 variable", "%d variables", 1)
		var many: String = EventSheetL10n.counted("1 variable", "%d variables", 5)
		rows.append(["%s words one variable apart from five" % locale, one != many, true])
		rows.append(["%s singular is not the English plural" % locale, one.contains("variables"), false])
	EventSheetL10n.set_locale("en")
	return SUPPORT.pins("counted_phrase_test", rows)
