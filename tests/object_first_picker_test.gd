# Godot EventSheets - the object-first Add flow (the event-sheet add-event gesture)
# Double-clicking empty canvas opens the picker on a front page of OBJECT cards - System
# first, then every provider alphabetically - and picking one scopes the tree to that
# object's verbs. Pins: the card enumeration (distinct, System-folded Core leading,
# alphabetized, empty providers skipped) and the provider scope narrowing an assembled
# definitions list.
@tool
class_name ObjectFirstPickerTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")


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
	# A global - a provider Godot autoloads under its own name - sits straight after System.
	ProjectSettings.set_setting("autoload/StatForge", "*res://zz_stat_forge.gd")
	var global_labels: Array = []
	for card: Dictionary in ACEPickerDialog.object_cards_for(definitions):
		global_labels.append(str(card.get("label")))
	ProjectSettings.set_setting("autoload/StatForge", null)
	all_passed = _check("a global follows System, ahead of the rest",
		global_labels, ["System", "StatForge", "AdvancedRandomAddon", "BulletBehavior"]) and all_passed

	# The builtin registry enumeration leads with the System card (pack providers join at
	# dock scan time; their card behavior is covered by the synthetic block above).
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	registry.refresh_from_sources([])
	var live_cards: Array[Dictionary] = ACEPickerDialog.object_cards_for(registry.get_all_definitions())
	all_passed = _check("the live registry yields a System card", str(live_cards[0].get("label")) if not live_cards.is_empty() else "", "System") and all_passed
	all_passed = _system_card_wears_the_gear(registry) and all_passed

	return all_passed


## System's card wears the gear its rows wear, not the Node ring: a ring of radius 2.2 around an
## empty centre, with spokes out to the edge. Read off the card's own icon - the centre pixel clear,
## a spoke's tip and the ring inked.
static func _system_card_wears_the_gear(registry: EventSheetACERegistry) -> bool:
	var picker: ACEPickerDialog = ACEPickerDialog.new()
	picker._registry = registry
	picker._objects_tree = Tree.new()
	picker._populate_object_cards()
	var system_item: TreeItem = null
	for child: TreeItem in picker._objects_tree.get_root().get_children():
		if str(child.get_metadata(0)) == "Core":
			system_item = child
	var read: Array = ["<no System card>"]
	if system_item != null and system_item.get_icon(0) != null:
		var image: Image = system_item.get_icon(0).get_image()
		var unit: float = float(image.get_width()) / 16.0
		read = [image.get_pixel(int(8.0 * unit), int(8.0 * unit)).a < 0.1,
			image.get_pixel(int(13.0 * unit), int(8.0 * unit)).a > 0.5,
			image.get_pixel(int(10.2 * unit), int(8.0 * unit)).a > 0.3]
	elif system_item != null:
		read = ["<System card has no icon>"]
	picker._objects_tree.free()
	return SUPPORT.check("object_first_picker_test", "the System card wears the gear: a clear centre, a spoke, the ring",
		read, [true, true, true])


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("  [FAIL] object_first_picker_test: %s (got %s, expected %s)" % [label, str(actual), str(expected)])
	return false
