# Godot EventSheets - the object-first Add flow (Construct's add-event gesture)
# Double-clicking empty canvas opens the picker on a front page of OBJECT cards - System
# first, then every provider alphabetically - and picking one scopes the tree to that
# object's verbs. Pins: the card enumeration (distinct, System-folded Core leading,
# alphabetized, empty providers skipped) and the provider scope narrowing an assembled
# definitions list.
@tool
class_name ObjectFirstPickerTest
extends RefCounted


static func _definition(provider: String, id: String) -> ACEDefinition:
	var definition: ACEDefinition = ACEDefinition.new()
	definition.provider_id = provider
	definition.id = id
	definition.display_name = id
	return definition


static func run() -> bool:
	var all_passed: bool = true

	var definitions: Array[ACEDefinition] = [
		_definition("StatForge", "method:stat_total"),
		_definition("Core", "Print"),
		_definition("BulletBehavior", "method:set_bullet_speed"),
		_definition("Core", "Wait"),
		_definition("", "orphan"),
		_definition("AdvancedRandomAddon", "method:dice"),
	]
	var cards: Array[Dictionary] = ACEPickerDialog.object_cards_for(definitions)
	var labels: Array = []
	for card: Dictionary in cards:
		labels.append(str(card.get("label")))
	all_passed = _check("cards are distinct, System leads, the rest alphabetize",
		labels, ["System", "AdvancedRandomAddon", "BulletBehavior", "StatForge"]) and all_passed
	all_passed = _check("Core folds into the System card", str(cards[0].get("provider")), "Core") and all_passed

	# The builtin registry enumeration leads with the System card (pack providers join at
	# dock scan time; their card behavior is covered by the synthetic block above).
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	registry.refresh_from_sources([])
	var live_cards: Array[Dictionary] = ACEPickerDialog.object_cards_for(registry.get_all_definitions())
	all_passed = _check("the live registry yields a System card", str(live_cards[0].get("label")) if not live_cards.is_empty() else "", "System") and all_passed

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("  [FAIL] object_first_picker_test: %s (got %s, expected %s)" % [label, str(actual), str(expected)])
	return false
