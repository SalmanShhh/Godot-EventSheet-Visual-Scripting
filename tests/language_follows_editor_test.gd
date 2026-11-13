# Godot EventSheets - the plugin speaks the language Godot's editor does.
#
# There is no Language picker of the plugin's own: the language FOLLOWS Editor Settings > Interface >
# Editor > Editor Language, with an explicit saved choice (or the eventsheets/interface/language_override
# Editor Setting) as the one way to differ. The matching of an editor language code to a catalog the
# plugin carries is pure and pinned here by value; the menus are held to have no Language entry.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "language_follows_editor_test"


static func run() -> bool:
	var carried: PackedStringArray = PackedStringArray(["de", "es", "fr", "it", "ja", "ko", "ru", "zh_CN"])
	var menu_source: String = FileAccess.get_file_as_string("res://addons/eventsheet/editor/dock/menu_bar.gd")
	var welcome_source: String = FileAccess.get_file_as_string("res://addons/eventsheet/editor/dock/welcome_window.gd")
	return SUPPORT.pins(P, [
		["an editor in German gets German", EventSheetL10n.locale_for_editor_language("de", carried), "de"],
		["a regional German editor gets the German catalog", EventSheetL10n.locale_for_editor_language("de_AT", carried), "de"],
		["Simplified Chinese matches its own code", EventSheetL10n.locale_for_editor_language("zh_CN", carried), "zh_CN"],
		["a Chinese editor code with a script suffix still finds the Chinese catalog", EventSheetL10n.locale_for_editor_language("zh_Hans", carried), "zh_CN"],
		["a hyphenated code is read as an underscore one", EventSheetL10n.locale_for_editor_language("fr-CA", carried), "fr"],
		["English stays English", EventSheetL10n.locale_for_editor_language("en_GB", carried), "en"],
		["a language nobody translated falls back to English", EventSheetL10n.locale_for_editor_language("sv", carried), "en"],
		["an empty code is English", EventSheetL10n.locale_for_editor_language("", carried), "en"],
		["the View menu has no Language picker of its own", menu_source.contains("EventSheetLanguageMenu"), false],
		["the Welcome window has no editor-language picker", welcome_source.contains("_language_picker"), false],
		["the override setting lives under eventsheets/", EventSheetL10n.OVERRIDE_SETTING.begins_with("eventsheets/"), true],
	])
