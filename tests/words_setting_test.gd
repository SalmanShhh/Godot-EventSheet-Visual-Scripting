# EventForge - the words the sheet lets you choose (Settings ▸ Words).
#
# Familiar Words used to be one toggle over a fixed table. It is now a per-user CHOICE per word,
# per state: the word with the toggle on and the word with it off are picked separately, because
# the point of the toggle is two vocabularies rather than one.
#
# Everything user-facing reads EventSheetWords.word(key), so this pins the values that helper
# hands back - not counts, and not the store (which needs an editor).
@tool
class_name WordsSettingTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _check("an inheritance set reads as Family with Familiar Words on",
		EventSheetWords.familiar_default("inheritance_set"), "Family") and all_passed
	all_passed = _check("and as Base class with it off",
		EventSheetWords.plain_default("inheritance_set"), "Base class") and all_passed
	all_passed = _check("Kind is offered as well as the two defaults",
		EventSheetWords.choices("inheritance_set"),
		PackedStringArray(["Family", "Base class", "Kind"])) and all_passed
	all_passed = _check("a scene reads as Layout with Familiar Words on",
		EventSheetWords.familiar_default("layout"), "Layout") and all_passed
	all_passed = _check("and as Scene with it off",
		EventSheetWords.plain_default("layout"), "Scene") and all_passed
	all_passed = _check("a Godot group reads as Family (group) with Familiar Words on",
		EventSheetWords.familiar_default("group"), "Family (group)") and all_passed
	all_passed = _check("a word with one honest name reads the same either way",
		EventSheetWords.familiar_default("destroy"), EventSheetWords.plain_default("destroy")) and all_passed
	all_passed = _check("queue_free reads as Destroy",
		EventSheetWords.word_for("destroy", true, {}), "Destroy") and all_passed
	all_passed = _check("_process reads as Every tick",
		EventSheetWords.word_for("every_tick", false, {}), "Every tick") and all_passed
	all_passed = _check("Array / Dictionary read as list / table",
		EventSheetWords.word_for("collection", true, {}), "list / table") and all_passed
	all_passed = _check("the reader is the Manual",
		EventSheetWords.word_for("manual", true, {}), "Manual") and all_passed
	all_passed = _check("an attached pack is a Behavior",
		EventSheetWords.word_for("behavior", true, {}), "Behavior") and all_passed

	# The choice itself: one state at a time, and a typed word wins over both defaults.
	var chosen: Dictionary = {"familiar": {"inheritance_set": "Kind"}}
	all_passed = _check("a word chosen for the Familiar Words state wins there",
		EventSheetWords.word_for("inheritance_set", true, chosen), "Kind") and all_passed
	all_passed = _check("and leaves the other state on its own default",
		EventSheetWords.word_for("inheritance_set", false, chosen), "Base class") and all_passed
	var typed: Dictionary = {"plain": {"layout": "Screen"}}
	all_passed = _check("a word you type is the word the sheet reads",
		EventSheetWords.word_for("layout", false, typed), "Screen") and all_passed
	all_passed = _check("an empty choice falls back to the default",
		EventSheetWords.word_for("layout", false, {"plain": {"layout": "  "}}), "Scene") and all_passed
	all_passed = _check("an unknown key hands back the key rather than an empty label",
		EventSheetWords.word_for("not_a_word", true, {}), "not_a_word") and all_passed

	# The page's own order and labels - what a reader sees down the left column. The eight GAME words
	# lead, unchanged; W21 appended the twenty-four editor-building ones after them, which is the
	# order the mockup fixed (the plugin, then its surfaces, then its shapes, then the code idioms).
	var game_words: Array[String] = ["inheritance_set", "layout", "every_tick", "behavior",
		"group", "collection", "destroy", "manual"]
	var expected_keys: Array[String] = game_words.duplicate()
	expected_keys.append_array(EventSheetWords.EDITOR_KEYS)
	all_passed = _check("the page lists every word in the approved order",
		EventSheetWords.keys(), expected_keys) and all_passed
	all_passed = _check("the game words still lead it",
		EventSheetWords.keys().slice(0, 8), game_words) and all_passed
	all_passed = _check("and the editor words follow, starting with the plugin itself",
		EventSheetWords.keys()[8], "editor_plugin") and all_passed
	all_passed = _check("each row says what it names",
		EventSheetWords.names_what("group"), "a Godot group") and all_passed
	all_passed = _check("the state's store name is the one already written to disk",
		EventSheetWords.state_key(true), "familiar") and all_passed
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] words_setting_test: %s" % label)
		return true
	print("[FAIL] words_setting_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
