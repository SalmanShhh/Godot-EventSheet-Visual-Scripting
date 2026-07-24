# Godot EventSheets - storylet_weaver pack (quality-based narrative autoload) smoke + rules.
#
# Loads the COMPILED pack and drives the storylet engine directly (pure Dictionary logic + signals;
# the OnProcess clock never ticks on a bare .new(), so cooldown tests advance _clock by hand).
# Proves requirement gating (with the beginner-friendly "missing quality = 0/\"\"" rule), weighted
# drawing, choices, one-shots, and cooldowns.
@tool
class_name StoryletWeaverTest
extends RefCounted

const PACK := "res://eventsheet_addons/storylet_weaver/storylet_weaver_addon.gd"


static func run() -> bool:
	var all_passed: bool = true
	var script: GDScript = load(PACK)
	all_passed = _check("storylet_weaver pack loads + parses", script != null, true) and all_passed
	if script == null:
		return all_passed

	var sw: Node = script.new()
	var drawn: Array = [0]
	var none: Array = [0]
	var chose: Array = [0]
	sw.on_storylet_drawn.connect(func() -> void: drawn[0] += 1)
	sw.on_none_available.connect(func() -> void: none[0] += 1)
	sw.on_choice_made.connect(func() -> void: chose[0] += 1)

	all_passed = _check("a fresh library is empty", sw.is_library_empty() and sw.storylet_count() == 0, true) and all_passed

	# Requirement gating + the missing-quality rule.
	sw.define_storylet("rescue", "Rescue!", "A cat is stuck in a tree.")
	sw.add_requirement("rescue", "courage", ">=", 3)
	all_passed = _check("defining a storylet fills the library", not sw.is_library_empty() and sw.storylet_count() == 1, true) and all_passed
	sw.set_quality("courage", 1)
	sw.draw()
	all_passed = _check("a failed requirement blocks the draw and fires On None Available",
		none[0] == 1 and not sw.has_active(), true) and all_passed
	sw.set_quality("courage", 5)
	sw.draw()
	all_passed = _check("a met requirement draws the storylet (On Storylet Drawn, active set)",
		drawn[0] == 1 and sw.has_active() and sw.active_id() == "rescue" and sw.active_title() == "Rescue!", true) and all_passed

	# Choices resolve and clear the active storylet.
	sw.add_choice("rescue", "climb", "Climb the tree")
	all_passed = _check("choices are readable on the active storylet",
		sw.active_choice_count() == 1 and sw.choice_id_at(0) == "climb" and sw.choice_text_at(0) == "Climb the tree", true) and all_passed
	sw.choose("climb")
	all_passed = _check("choosing fires On Choice Made and clears the active storylet",
		chose[0] == 1 and sw.chosen_id() == "climb" and not sw.has_active(), true) and all_passed

	# Missing quality reads as 0 (not the C3 "everything fails" rule) + text qualities.
	_reset(sw)
	sw.define_storylet("rich", "Rich", "You strike gold.")
	sw.add_requirement("rich", "gold", ">=", 10)
	sw.define_storylet("bar", "Bar", "At the tavern.")
	sw.add_requirement("bar", "location", "=", "tavern")
	sw.set_quality("location", "tavern")
	sw.evaluate()
	all_passed = _check("an unset numeric quality reads as 0, so gold >= 10 is simply unavailable",
		not sw.is_available("rich") and sw.has_quality("location") and not sw.has_quality("gold"), true) and all_passed
	all_passed = _check("a text quality requirement matches", sw.is_available("bar"), true) and all_passed
	sw.increment_quality("gold", 12.0)
	sw.evaluate()
	all_passed = _check("Increment Quality creates + raises a numeric quality", sw.is_available("rich") and is_equal_approx(sw.quality_number("gold"), 12.0), true) and all_passed

	# Weight ordering: the heavier eligible storylet is drawn first.
	_reset(sw)
	sw.define_storylet("big", "Big", "b")
	sw.set_storylet_weight("big", 10.0)
	sw.define_storylet("small", "Small", "s")
	sw.set_storylet_weight("small", 1.0)
	sw.draw()
	all_passed = _check("Draw picks the highest-weight eligible storylet", sw.active_id() == "big", true) and all_passed

	# One-shot: max plays 1 means it never draws twice.
	_reset(sw)
	sw.define_storylet("intro", "Intro", "once")
	sw.set_storylet_max_plays("intro", 1)
	sw.draw()
	all_passed = _check("a one-shot draws once", sw.active_id() == "intro" and sw.play_count("intro") == 1, true) and all_passed
	sw.dismiss()
	var none_before: int = none[0]
	sw.draw()
	all_passed = _check("a spent one-shot is no longer eligible", none[0] == none_before + 1 and not sw.has_active(), true) and all_passed
	sw.reset_play_count("intro")
	sw.draw()
	all_passed = _check("Reset Play Count makes a one-shot eligible again", sw.active_id() == "intro", true) and all_passed

	# Cooldown: ineligible until the (driven) clock advances past the cooldown.
	_reset(sw)
	sw.define_storylet("nap", "Nap", "rest")
	sw.set_storylet_cooldown("nap", 10.0)
	sw.draw()
	sw.dismiss()
	sw.evaluate()
	all_passed = _check("a storylet is on cooldown right after it plays",
		sw.is_on_cooldown("nap") and not sw.is_available("nap") and sw.cooldown_remaining("nap") > 9.0, true) and all_passed
	sw._clock += 11.0
	sw.evaluate()
	all_passed = _check("the cooldown clears once enough game time passes",
		not sw.is_on_cooldown("nap") and sw.is_available("nap"), true) and all_passed

	# --- Effects + forecasts (data-driven consequences, ported from the C3 addon) ---
	_reset(sw)
	sw.define_storylet("gate", "The Gate", "Pay the toll.")
	sw.add_effect("gate", "inc", "visits", 1)
	sw.add_meta("gate", "speaker", "Gatekeeper")
	all_passed = _check("Forecast Storylet Effects reads without mutating",
		sw.forecast_storylet_effects("gate") == "visits +1" and not sw._qualities.has("visits"), true) and all_passed
	all_passed = _check("Storylet Meta reads a stored payload", sw.storylet_meta("gate", "speaker"), "Gatekeeper") and all_passed
	sw.draw()
	all_passed = _check("a storylet's on-draw effect applies when it is drawn",
		sw.active_id() == "gate" and is_equal_approx(sw.quality_number("visits"), 1.0), true) and all_passed
	all_passed = _check("Active Meta reads the drawn storylet's payload", sw.active_meta("speaker"), "Gatekeeper") and all_passed

	# --- Choice requirements + choice effects (only eligible choices show; picking applies the effect) ---
	_reset(sw)
	sw.define_storylet("toll", "Toll", "Pay to pass.")
	sw.add_choice("toll", "pay", "Pay 10 gold.")
	sw.add_choice_requirement("toll", "pay", "gold", ">=", 10)
	sw.add_choice_effect("toll", "pay", "dec", "gold", 10)
	sw.add_choice("toll", "leave", "Leave.")
	sw.set_quality("gold", 5)
	sw.draw()
	all_passed = _check("a choice whose requirement fails is hidden", sw.active_choice_count(), 1) and all_passed
	all_passed = _check("Forecast Choice Effects previews the consequence", sw.forecast_choice_effects("toll", "pay"), "gold -10") and all_passed
	sw.dismiss()
	sw.set_quality("gold", 20)
	sw.reset_all_history()
	sw.draw()
	all_passed = _check("both choices show once the requirement passes", sw.active_choice_count(), 2) and all_passed
	sw.choose("pay")
	all_passed = _check("picking a choice applies its effect", is_equal_approx(sw.quality_number("gold"), 10.0), true) and all_passed

	# --- Richer requirements: key-vs-key, chance, recency ---
	_reset(sw)
	sw.set_quality("gold", 20)
	sw.set_quality("price", 15)
	sw.define_storylet("afford", "Afford", "")
	sw.add_requirement_key("afford", "gold", ">=", "price")
	sw.define_storylet("cannot", "Cannot", "")
	sw.add_requirement_key("cannot", "price", ">", "gold")
	sw.define_storylet("never", "Never", "")
	sw.add_chance_requirement("never", 0)
	sw.evaluate()
	all_passed = _check("key-vs-key compares two qualities (gold >= price passes, price > gold fails)",
		sw.is_available("afford") and not sw.is_available("cannot"), true) and all_passed
	all_passed = _check("a 0% chance requirement is never eligible", sw.is_available("never"), false) and all_passed

	_reset(sw)
	sw.define_storylet("anti", "Anti", "")
	sw.add_recency_requirement("anti", "not_recent", 2)
	sw.evaluate()
	all_passed = _check("a not-recently-drawn storylet is eligible before it is drawn", sw.is_available("anti"), true) and all_passed
	sw.draw()
	sw.dismiss()
	sw.evaluate()
	all_passed = _check("the anti-repeat gate blocks it right after it was drawn", sw.is_available("anti"), false) and all_passed

	# --- Load From Resource: a whole storybook authored as a StoryletResource (.tres) grid ---
	_reset(sw)
	var res_script: GDScript = load("res://eventsheet_addons/storylet_resource/storylet_resource.gd")
	all_passed = _check("storylet_resource pack loads + parses", res_script != null, true) and all_passed
	if res_script != null:
		var book: Resource = res_script.new()
		book.storylets = [
			{"id": "gate", "title": "The Gate", "body": "Pay the toll.", "weight": 2.0, "cooldown": 0.0, "max_plays": -1},
			{"id": "afford", "title": "Afford", "body": "You can buy it.", "weight": 1.0, "cooldown": 0.0, "max_plays": -1},
		]
		# op stored as a WORD token (a table dropdown cannot hold ">="); the loader maps gte -> >=.
		book.requirements = [{"storylet": "afford", "op": "gte", "key": "gold", "value": "price", "value_is_key": true}]
		book.choices = [{"storylet": "gate", "choice_id": "pay", "text": "Pay 10 gold."}, {"storylet": "gate", "choice_id": "leave", "text": "Leave."}]
		book.choice_requirements = [{"storylet": "gate", "choice_id": "pay", "op": "gte", "key": "gold", "value": "10", "value_is_key": false}]
		book.effects = [{"storylet": "gate", "op": "inc", "key": "visits", "value": "1"}]
		book.choice_effects = [{"storylet": "gate", "choice_id": "pay", "op": "dec", "key": "gold", "value": "10"}]
		book.meta = [{"storylet": "gate", "key": "speaker", "value": "Gatekeeper"}]

		sw.load_from_resource(book)
		all_passed = _check("Load From Resource registers every storylet in the grid", sw.storylet_count(), 2) and all_passed
		all_passed = _check("the loaded storylet's meta round-trips", sw.storylet_meta("gate", "speaker"), "Gatekeeper") and all_passed
		all_passed = _check("the loaded on-draw effect is present (forecast reads it)", sw.forecast_storylet_effects("gate"), "visits +1") and all_passed

		sw.set_quality("gold", 20)
		sw.set_quality("price", 15)
		sw.evaluate()
		all_passed = _check("a loaded key-vs-key requirement gates on the live comparison (gold >= price)",
			sw.is_available("gate") and sw.is_available("afford"), true) and all_passed

		sw.set_quality("gold", 5)
		sw.draw()
		all_passed = _check("the loaded on-draw effect applies when the storylet is drawn",
			sw.active_id() == "gate" and is_equal_approx(sw.quality_number("visits"), 1.0), true) and all_passed
		all_passed = _check("a loaded choice requirement hides its choice", sw.active_choice_count(), 1) and all_passed
		sw.dismiss()
		sw.set_quality("gold", 20)
		sw.reset_all_history()
		sw.draw()
		sw.choose("pay")
		all_passed = _check("a loaded choice effect applies when the choice is picked",
			is_equal_approx(sw.quality_number("gold"), 10.0), true) and all_passed

	# Loading from an actual .tres on disk (the shipped sample) proves the grid columns serialize.
	var sample: Resource = load("res://demo/storylet_book/village_storylets.tres")
	all_passed = _check("the shipped sample .tres loads as a StoryletResource", sample != null, true) and all_passed
	if sample != null:
		_reset(sw)
		sw.load_from_resource(sample)
		all_passed = _check("the sample .tres registers its storylets", sw.storylet_count() > 0, true) and all_passed

	sw.free()
	return all_passed


## Clears live state between test phases so each starts from a clean library.
static func _reset(sw: Node) -> void:
	sw._lib.clear()
	sw._qualities.clear()
	sw._plays.clear()
	sw._last_played.clear()
	sw._available.clear()
	sw._active = ""
	sw._clock = 0.0


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] storylet_weaver_test: %s" % label)
		return true
	print("[FAIL] storylet_weaver_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
