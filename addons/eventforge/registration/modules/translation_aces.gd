# EventForge module — Translation vocabulary (localisation the Godot way).
#
# Thin verbs over Godot's own localisation runtime: TranslationServer swaps locales,
# tr()/tr_n() look up the current language, and Project Settings > Localization owns
# the catalogs (its POT generation reads tr() calls straight out of the compiled .gd).
# Nothing here adds runtime - every emission is a bare native call (parity-clean).
#
# On Language Changed compiles to the _notification virtual (the engine has no signal
# for it); applying the trigger auto-adds the "Language Just Changed" gate condition
# so the event only runs for NOTIFICATION_TRANSLATION_CHANGED - visible in the sheet,
# deletable, and round-tripping as the plain event + condition it is.
@tool
class_name EventForgeTranslationACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	descriptors.append(F.make_descriptor("Core", "SetLocale", "Set Language", ACEDescriptor.ACEType.ACTION,
		"TranslationServer.set_locale({locale})", "",
		[F.make_param("locale", "String", "\"en\"", "Locale", "Language code to switch to, e.g. \"en\", \"es\", \"ja\".", "expression")],
		"Translation", "set language to {locale}")
		.described("Switches the game's language live. Auto-translated Controls and every later tr() lookup follow immediately."))

	descriptors.append(F.make_descriptor("Core", "GetLocale", "Current Language", ACEDescriptor.ACEType.EXPRESSION,
		"TranslationServer.get_locale()", "", [],
		"Translation", "current language")
		.described("The active locale code, e.g. \"en\" or \"es\"."))

	descriptors.append(F.make_descriptor("Core", "Translate", "Translate", ACEDescriptor.ACEType.EXPRESSION,
		"tr({text})", "",
		[F.make_param("text", "String", "\"HELLO\"", "Text", "The source string (or key) to look up.", "expression")],
		"Translation", "translate {text}")
		.described("Looks the text up in the current language (tr). For a fixed label, the field's globe toggle does this without an expression."))

	descriptors.append(F.make_descriptor("Core", "TranslateWithContext", "Translate With Context", ACEDescriptor.ACEType.EXPRESSION,
		"tr({text}, {context})", "",
		[
			F.make_param("text", "String", "\"May\"", "Text", "The source string (or key) to look up.", "expression"),
			F.make_param("context", "String", "\"month\"", "Context", "Disambiguates identical strings, e.g. \"May\" the month vs the verb.", "expression"),
		], "Translation", "translate {text} as {context}")
		.described("tr() with a translation context, for strings that read the same but translate differently."))

	descriptors.append(F.make_descriptor("Core", "TranslatePlural", "Translate Plural", ACEDescriptor.ACEType.EXPRESSION,
		"tr_n({singular}, {plural}, {count})", "",
		[
			F.make_param("singular", "String", "\"%d apple\"", "Singular", "The one-item form.", "expression"),
			F.make_param("plural", "String", "\"%d apples\"", "Plural", "The many-items form.", "expression"),
			F.make_param("count", "String", "2", "Count", "How many - picks the right form per language.", "expression"),
		], "Translation", "translate plural for {count}")
		.described("Picks the singular or plural form for the count in the current language (tr_n); languages with more plural forms use their catalog's rules."))

	descriptors.append(F.make_descriptor("Core", "IsLocaleChangeNotification", "Language Just Changed", ACEDescriptor.ACEType.CONDITION,
		"what == NOTIFICATION_TRANSLATION_CHANGED", "", [],
		"Translation", "language just changed")
		.described("The gate under On Language Changed: true only for the engine's translation-changed notification."))

	descriptors.append(F.make_descriptor("Core", "OnLocaleChanged", "On Language Changed", ACEDescriptor.ACEType.TRIGGER,
		"", "", [],
		"Translation", "on language changed")
		.described("Runs when the game's language switches. Compiles to the _notification virtual with the Language Just Changed gate added for you."))

	return descriptors
