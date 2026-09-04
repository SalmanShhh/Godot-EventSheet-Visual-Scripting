# Godot EventSheets - the card-list drawer (an Array of Dictionaries edited as a list of cards).
#
# The drawer is Inspector chrome: it never reaches a sheet row and never reaches generated game code.
# What it MUST not do is move somebody's saved data, so the pins here are about the array - reorder
# writes it in order, the enable box writes exactly one key (and un-writes it), copy and paste round
# trip through text, a schema derived from ACE descriptors is the values the verbs already declare,
# and the Drawing Prefab's steps keep the eight keys they have always had, in the order they had them.
@tool
class_name CardListDrawerTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")

## A schema name nothing else uses, registered and unregistered inside one run so no other test can
## see it (a leaked static is a red run somewhere else).
const TEST_SCHEMA_NAME: String = "card_list_drawer_test_steps"


static func run() -> bool:
	var ok: bool = true
	ok = _marker_pins() and ok
	ok = _schema_pins() and ok
	ok = _array_pins() and ok
	ok = _prefab_pins() and ok
	return ok


## The marker: what it parses into, what it emits, and that it lifts back byte-exact.
static func _marker_pins() -> bool:
	var ok: bool = true
	ok = _eq("the marker parses into its three words",
		EventSheetCardSchemas.parse_cards_spec("kind=step,schema=feedback_steps,stripes=lane"),
		{"kind_key": "step", "schema": "feedback_steps", "stripe_key": "lane"}) and ok
	ok = _eq("a marker naming only its schema keeps the default key names",
		EventSheetCardSchemas.parse_cards_spec("schema=feedback_steps"),
		{"kind_key": "kind", "schema": "feedback_steps", "stripe_key": "category"}) and ok
	# The shared marker reader hands the whole tail over as one argument (its numeric `min` is the
	# bounds a progress bar would have read there, and means nothing to a card list).
	ok = _eq("the drawer marker reads as the cards drawer",
		str(EventSheetAttributeDrawers.parse_drawer_hint("eventsheet:cards:kind=kind,schema=s,stripes=category").get("args")),
		str(["kind=kind,schema=s,stripes=category"])) and ok

	var line: String = _emit_for("Array[Dictionary]", [], {"drawer": "cards", "cards_schema": "feedback_steps"})
	ok = _eq("cards emits its marker, with the default key names filled in",
		line.begins_with("@export_custom(PROPERTY_HINT_NONE, \"eventsheet:cards:kind=kind,schema=feedback_steps,stripes=category\") var v: Array[Dictionary]"),
		true) and ok
	ok = _eq("the marker carries the key names when they are named",
		_emit_for("Array[Dictionary]", [], {"drawer": "cards", "cards_schema": "s", "cards_kind_key": "step", "cards_stripe_key": "lane"}).contains(
			"eventsheet:cards:kind=step,schema=s,stripes=lane"), true) and ok
	ok = _eq("cards without a schema emits no marker",
		_emit_for("Array[Dictionary]", [], {"drawer": "cards"}).contains("eventsheet:"), false) and ok
	ok = _eq("cards on a float emits no marker",
		_emit_for("float", 1.0, {"drawer": "cards", "cards_schema": "s"}).contains("eventsheet:"), false) and ok
	ok = _eq("a schema name the joined marker could not survive emits no marker",
		_emit_for("Array[Dictionary]", [], {"drawer": "cards", "cards_schema": "a,b"}).contains("eventsheet:"), false) and ok
	ok = _eq("a key name the joined marker could not survive falls back to the default",
		_emit_for("Array[Dictionary]", [], {"drawer": "cards", "cards_schema": "s", "cards_kind_key": "a=b"}).contains(
			"kind=kind,schema=s"), true) and ok

	var sheet: EventSheetResource = GDScriptImporter.new().import_external_source("extends Node2D\n\n" + line + "\n")
	var lifted: LocalVariable = _find(sheet, "v")
	var attributes: Dictionary = lifted.attributes as Dictionary if lifted != null else {}
	ok = _eq("the lift recovers the drawer", str(attributes.get("drawer", "")), "cards") and ok
	ok = _eq("the lift recovers the schema name", str(attributes.get("cards_schema", "")), "feedback_steps") and ok
	ok = _eq("the lift recovers the key names",
		"%s|%s" % [str(attributes.get("cards_kind_key", "")), str(attributes.get("cards_stripe_key", ""))], "kind|category") and ok
	ok = _eq("the marker re-emits byte for byte",
		SheetCompiler._emit_tree_variable_line(lifted) if lifted != null else "", line) and ok
	return ok


## The schema: registered by name through the public API, or derived from a pack's own verbs.
static func _schema_pins() -> bool:
	var ok: bool = true
	EventSheets.register_card_schema(TEST_SCHEMA_NAME, func() -> Dictionary:
		return {"kinds": [{"kind": "pause", "category": "timing", "label": "Pause"}]})
	ok = _eq("a registered schema resolves by name",
		EventSheetCardSchemas.schema_for({"schema": TEST_SCHEMA_NAME}),
		{"kinds": [{"kind": "pause", "category": "timing", "label": "Pause"}]}) and ok
	ok = _eq("a kind is found by its stored word",
		str(EventSheetCardSchemas.kind_entry(EventSheets.card_schema(TEST_SCHEMA_NAME), "pause").get("label", "")), "Pause") and ok
	ok = _eq("an unknown kind is empty, not an error",
		EventSheetCardSchemas.kind_entry(EventSheets.card_schema(TEST_SCHEMA_NAME), "nothing_like_it"), {}) and ok
	EventSheets.unregister_card_schema(TEST_SCHEMA_NAME)
	ok = _eq("an unregistered name resolves to nothing to draw",
		EventSheetCardSchemas.schema_for({"schema": TEST_SCHEMA_NAME}), {}) and ok

	# Derived from descriptors: the card says what the picker says, and its fields are the verb's own
	# parameters - a pack that publishes verbs writes no editor code for their cards.
	ok = _eq("a schema derived from a descriptor is the verb's own words",
		EventSheetCardSchemas.from_aces([_shake_descriptor()], "other"),
		{"kinds": [{
			"kind": "Shake",
			"category": "Camera",
			"label": "Shake",
			"help": "Shakes the camera.",
			"fields": [
				{"key": "strength", "label": "Strength", "drawer": "num", "default": 1.5},
				{"key": "style", "label": "Style", "drawer": "toggle_row:soft,hard", "default": "soft"},
			],
			"live": [],
		}]}) and ok
	ok = _eq("a descriptor with no category of its own falls back",
		str((EventSheetCardSchemas.from_aces([_bare_descriptor()], "other").get("kinds")[0] as Dictionary).get("category", "")), "other") and ok
	ok = _eq("anything that is not a descriptor is skipped",
		EventSheetCardSchemas.from_aces(["not a descriptor", null], ""), {"kinds": []}) and ok

	# The stripe is DERIVED from the category word, so a pack inventing a category gets a stable
	# colour with nothing to register - and a schema may still name one exactly.
	ok = _eq("a category's colour is derived from its word",
		int(round(EventSheetCardSchemas.stripe_color({}, "audio").h * 360.0)), 350) and ok
	ok = _eq("the same word is always the same colour",
		EventSheetCardSchemas.stripe_color({}, "audio") == EventSheetCardSchemas.stripe_color({}, "audio"), true) and ok
	ok = _eq("two categories are two colours",
		EventSheetCardSchemas.stripe_color({}, "audio") == EventSheetCardSchemas.stripe_color({}, "camera"), false) and ok
	ok = _eq("no category is the one colour that is not derived",
		EventSheetCardSchemas.stripe_color({}, ""), EventSheetCardSchemas.UNCATEGORISED_STRIPE) and ok
	ok = _eq("a schema naming a colour wins",
		EventSheetCardSchemas.stripe_color({"stripes": {"audio": "#112233"}}, "audio"), Color.from_string("#112233", Color.WHITE)) and ok
	return ok


## The array operations: everything a designer's gesture writes back into the property.
static func _array_pins() -> bool:
	var ok: bool = true
	var cards: Array = [{"kind": "a"}, {"kind": "b"}, {"kind": "c"}]
	ok = _eq("a card dragged to the top writes the array in that order",
		EventSheetCardSchemas.move_card(cards, 2, 0), [{"kind": "c"}, {"kind": "a"}, {"kind": "b"}]) and ok
	ok = _eq("a card dragged down writes the array in that order",
		EventSheetCardSchemas.move_card(cards, 0, 2), [{"kind": "b"}, {"kind": "c"}, {"kind": "a"}]) and ok
	ok = _eq("a drop onto nothing leaves the list alone",
		EventSheetCardSchemas.move_card(cards, 0, 9), cards) and ok
	ok = _eq("a duplicated card lands directly below itself",
		EventSheetCardSchemas.duplicate_card(cards, 0), [{"kind": "a"}, {"kind": "a"}, {"kind": "b"}, {"kind": "c"}]) and ok
	ok = _eq("a removed card is gone and the rest keep their order",
		EventSheetCardSchemas.remove_card(cards, 1), [{"kind": "a"}, {"kind": "c"}]) and ok

	# The enable box writes ONE key, and un-writes it: absent already means on, so a card ticked off
	# and on again leaves the file exactly as it was.
	var enable_schema: Dictionary = {"enabled_key": "on", "kinds": [{"kind": "a"}]}
	var card: Dictionary = {"kind": "a"}
	ok = _eq("a card with no enable key reads as on", EventSheetCardSchemas.card_enabled(enable_schema, card), true) and ok
	var switched_off: Dictionary = EventSheetCardSchemas.set_card_enabled(enable_schema, card, false)
	ok = _eq("switching a card off writes exactly one key", switched_off, {"kind": "a", "on": false}) and ok
	ok = _eq("a card switched off reads as off", EventSheetCardSchemas.card_enabled(enable_schema, switched_off), false) and ok
	ok = _eq("switching it back on leaves the card as it was",
		EventSheetCardSchemas.set_card_enabled(enable_schema, switched_off, true), {"kind": "a"}) and ok
	ok = _eq("a schema declaring no enable key writes nothing",
		EventSheetCardSchemas.set_card_enabled({}, card, false), {"kind": "a"}) and ok

	# Copy and paste go through text, in Godot's own variant spelling, so an int stays an int.
	var copied: Array = [{"kind": "a", "count": 3, "amount": 1.5, "note": "hi", "on": false}]
	var text: String = EventSheetCardSchemas.cards_to_text(copied)
	ok = _eq("copied cards paste back as themselves", EventSheetCardSchemas.cards_from_text(text), copied) and ok
	ok = _eq("a pasted number keeps the type it was copied as",
		typeof((EventSheetCardSchemas.cards_from_text(text)[0] as Dictionary).get("count")), TYPE_INT) and ok
	ok = _eq("text that is not a card list pastes nothing",
		EventSheetCardSchemas.cards_from_text("some sentence somebody copied"), []) and ok
	ok = _eq("a card list that is not ours pastes nothing",
		EventSheetCardSchemas.cards_from_text("[{\"kind\": \"a\"}]"), []) and ok

	# A field with a show-if appears only while the card's own key is on.
	ok = _eq("a field with no show-if always shows",
		EventSheetCardSchemas.field_visible({"key": "a"}, {}), true) and ok
	ok = _eq("a show-if field hides while its key is off",
		EventSheetCardSchemas.field_visible({"key": "a", "show_if": "dashed"}, {"dashed": false}), false) and ok
	ok = _eq("a show-if field shows while its key is on",
		EventSheetCardSchemas.field_visible({"key": "a", "show_if": "dashed"}, {"dashed": true}), true) and ok
	return ok


## The Drawing Prefab's steps: the same eight keys, in the same order, whatever the card list does.
static func _prefab_pins() -> bool:
	var ok: bool = true
	var editor: EventSheetDrawingPrefabInspector.ShapeStepsEditor = EventSheetDrawingPrefabInspector.ShapeStepsEditor.new()
	editor.set_steps([
		{"kind": "line", "x": 1.0, "y": 2.0, "p1": 5.0, "p2": 6.0, "p3": 3.0, "color": "red"},
		{"kind": "circle", "x": 0.0, "y": 0.0, "p1": 8.0, "p2": 0.0, "p3": 0.0, "color": "#ffffff", "texture": ""},
	])
	var loaded: Array = editor.get_steps()
	ok = _eq("loading a step writes nothing into it",
		"|".join((loaded[0] as Dictionary).keys()), "kind|x|y|p1|p2|p3|color") and ok
	ok = _eq("the cards read out in list order", editor.card_labels(), PackedStringArray(["Line", "Circle"])) and ok

	var emitted: Array = []
	editor.value_changed.connect(func(value: Array) -> void: emitted.append(value))
	editor.move_card(1, 0)
	ok = _eq("reordering writes the array in the new order", editor.card_labels(), PackedStringArray(["Circle", "Line"])) and ok
	ok = _eq("reordering emits the reordered array once", emitted.size(), 1) and ok
	ok = _eq("the emitted array is the one the list shows",
		str((emitted[0][0] as Dictionary).get("kind", "")) if not emitted.is_empty() else "", "circle") and ok

	editor.set_steps([])
	editor.add_default_step()
	var added: Dictionary = editor.get_steps()[0]
	ok = _eq("an added step is a circle with every stored slot seeded, in storage order",
		"|".join(added.keys()), "kind|x|y|p1|p2|p3|color|texture") and ok
	ok = _eq("an added step is visible immediately", "%s|%s" % [str(added.get("kind")), str(added.get("p1"))], "circle|12.0") and ok
	editor.free()

	# The shape vocabulary is the schema's: each shape still titles its own slots, never p1/p2/p3.
	var schema: Dictionary = EventSheetDrawingPrefabInspector.ShapeStepsEditor.build_schema()
	ok = _eq("line still titles p1/p2/p3 as End X/End Y/Thickness", _field_labels(schema, "line"), "Shape|End X|End Y|Thickness|Offset X|Offset Y|Color") and ok
	ok = _eq("circle still titles p1 as Radius", _field_labels(schema, "circle"), "Shape|Radius|Offset X|Offset Y|Color") and ok
	ok = _eq("a stamp still names its texture", _field_labels(schema, "stamp"), "Shape|Scale|Spin|Texture|Offset X|Offset Y|Color") and ok
	ok = _eq("the prefab declares no enable key (nothing would honour it)",
		EventSheetCardSchemas.enabled_key(schema), "") and ok
	return ok


## The field titles of one shape, pipe-joined in display order.
static func _field_labels(schema: Dictionary, kind: String) -> String:
	var labels: PackedStringArray = PackedStringArray()
	for field: Variant in EventSheetCardSchemas.fields_of(EventSheetCardSchemas.kind_entry(schema, kind)):
		labels.append(str((field as Dictionary).get("label", "")))
	return "|".join(labels)


## A verb with two parameters - one number, one pair of fixed choices - as the derivation reads it.
static func _shake_descriptor() -> ACEDescriptor:
	var descriptor: ACEDescriptor = ACEDescriptor.new()
	descriptor.ace_id = "Shake"
	descriptor.display_name = "Shake"
	descriptor.description = "Shakes the camera."
	descriptor.category = "Camera"
	var strength: ACEParam = ACEParam.new()
	strength.id = "strength"
	strength.display_name = "Strength"
	strength.type_name = "float"
	strength.default_value = "1.5"
	var style: ACEParam = ACEParam.new()
	style.id = "style"
	style.display_name = "Style"
	style.type_name = "String"
	style.default_value = "soft"
	style.options = ["soft", "hard"]
	descriptor.params = [strength, style] as Array[ACEParam]
	return descriptor


static func _bare_descriptor() -> ACEDescriptor:
	var descriptor: ACEDescriptor = ACEDescriptor.new()
	descriptor.ace_id = "Plain"
	return descriptor


static func _emit_for(type_name: String, default_value: Variant, attributes: Dictionary) -> String:
	var local: LocalVariable = LocalVariable.new()
	local.name = "v"
	local.type_name = type_name
	local.default_value = default_value
	local.exported = true
	local.attributes = attributes
	return SheetCompiler._emit_tree_variable_line(local)


static func _find(sheet: EventSheetResource, var_name: String) -> LocalVariable:
	for entry: Variant in sheet.events:
		if entry is LocalVariable and (entry as LocalVariable).name == var_name:
			return entry as LocalVariable
	return null


static func _eq(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("card_list_drawer_test", label, actual, expected)
