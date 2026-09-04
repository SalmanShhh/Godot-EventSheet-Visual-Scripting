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
	ok = _card_row_pins() and ok
	ok = _array_pins() and ok
	ok = _link_pins() and ok
	ok = _fold_pins() and ok
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
	ok = _eq("a card carrying its own colour is read as that colour, not hashed",
		EventSheetCardSchemas.stripe_color({}, "#4488cc"), Color.from_string("#4488cc", Color.WHITE)) and ok
	return ok


## The card's own two rows - the enable box and the name with its colour - written through the
## drawer, because those two write keys into somebody's file and the rest of the card does not.
static func _card_row_pins() -> bool:
	var ok: bool = true
	var schema: Dictionary = {
		"label_key": "label",
		"enabled_key": "on",
		"kinds": [{"kind": "shake", "category": "camera", "label": "Shake", "fields": [{"key": "amount"}]}],
	}
	var drawer: EventSheetCardListDrawer = EventSheetCardListDrawer.new({"schema_dict": schema})
	drawer.set_value([{"kind": "shake", "amount": 2.0}])
	ok = _eq("a card the designer has not renamed is titled by its kind", drawer.card_labels(), PackedStringArray(["Shake"])) and ok
	drawer.set_card_label(0, "Big hit")
	ok = _eq("renaming a card writes the schema's label key", drawer.get_value(), [{"kind": "shake", "amount": 2.0, "label": "Big hit"}]) and ok
	ok = _eq("the renamed card is titled by its own name", drawer.card_labels(), PackedStringArray(["Big hit"])) and ok
	drawer.set_card_stripe(0, Color.from_string("#4488cc", Color.WHITE))
	ok = _eq("a card's own colour is stored as the text a plain-data list holds",
		str((drawer.get_value()[0] as Dictionary).get("category", "")), "#4488cc") and ok
	drawer.set_card_enabled(0, false)
	ok = _eq("switching the card off writes one key",
		bool((drawer.get_value()[0] as Dictionary).get("on", true)), false) and ok
	drawer.free()

	# A list whose stripe key IS the key holding the kind (the Drawing Prefab) can never be given a
	# colour, because the colour would land where the shape is stored.
	var prefab_drawer: EventSheetCardListDrawer = EventSheetCardListDrawer.new({
		"kind_key": "kind", "stripe_key": "kind", "schema_dict": {"kinds": [{"kind": "circle", "label": "Circle"}]}})
	prefab_drawer.set_value([{"kind": "circle", "p1": 4.0}])
	ok = _eq("a list coloured by its kind offers no colour of its own", prefab_drawer.stripe_editable(), false) and ok
	prefab_drawer.set_card_stripe(0, Color.RED)
	ok = _eq("and a colour written there anyway is refused", prefab_drawer.get_value(), [{"kind": "circle", "p1": 4.0}]) and ok
	prefab_drawer.set_card_label(0, "renamed")
	ok = _eq("a schema with no label key has no name to write", prefab_drawer.get_value(), [{"kind": "circle", "p1": 4.0}]) and ok
	prefab_drawer.free()
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


## The "=" inside a card is the SAME tie the property-level "=" is: a ratio remembered when it is
## pressed, never a copy of the leader's value into its partner.
static func _link_pins() -> bool:
	var ok: bool = true
	var drawer: EventSheetCardListDrawer = EventSheetCardListDrawer.new({"schema_dict": {"kinds": [{"kind": "dash",
		"fields": [{"key": "count", "link": "spacing"}, {"key": "spacing"}, {"key": "note", "drawer": "text"}]}]}})
	drawer.set_value([{"kind": "dash", "count": 8.0, "spacing": 2.0, "note": "hi"}])
	ok = _eq("the ratio is what the partner is worth per unit of this field",
		drawer.link_ratio_for(0, "count", "spacing"), 0.25) and ok
	drawer.write_linked_pair(0, "count", "spacing", 0.25, 16.0)
	ok = _eq("a linked edit moves the partner by that ratio, not by copying the value",
		drawer.get_value(), [{"kind": "dash", "count": 16.0, "spacing": 4.0, "note": "hi"}]) and ok
	ok = _eq("a key holding text has no ratio to read, so the pair keeps a ratio of one",
		drawer.link_ratio_for(0, "note", "count"), 1.0) and ok
	drawer.free()

	# The stored spelling still decides the written type: a pair of whole numbers stays whole.
	var whole: EventSheetCardListDrawer = EventSheetCardListDrawer.new({"schema_dict": {"kinds": [{"kind": "dash",
		"fields": [{"key": "count", "link": "spacing"}, {"key": "spacing"}]}]}})
	whole.set_value([{"kind": "dash", "count": 8, "spacing": 2}])
	whole.write_linked_pair(0, "count", "spacing", 0.25, 16.0)
	ok = _eq("a tie between two whole numbers writes two whole numbers",
		whole.get_value(), [{"kind": "dash", "count": 16, "spacing": 4}]) and ok
	whole.free()
	return ok


## Folding is a view keyed by position, so every reorder has to carry it - and one click still adds
## the thing a list of one kind is made of.
static func _fold_pins() -> bool:
	var ok: bool = SUPPORT.pins("card_list_drawer_test", [
		["a card dragged to the top takes its open state with it",
			EventSheetCardSchemas.remapped_folds({2: true}, [2, 0, 1]), {0: true}],
		["a duplicated card starts shut and the original stays open",
			EventSheetCardSchemas.remapped_folds({0: true}, [0, -1, 1]), {0: true}],
		["a removed card takes only its own state",
			EventSheetCardSchemas.remapped_folds({2: true}, [0, 2]), {1: true}],
		["a shut list stays shut", EventSheetCardSchemas.remapped_folds({}, [0, 1]), {}]
	])

	var drawer: EventSheetCardListDrawer = EventSheetCardListDrawer.new({"schema_dict": {"kinds": [
		{"kind": "circle", "label": "Circle", "defaults": {"r": 4.0}}, {"kind": "square", "label": "Square"}]}})
	drawer.add_first_kind()
	ok = _eq("one click adds one card of the list's first kind",
		drawer.get_value(), [{"kind": "circle", "r": 4.0}]) and ok
	drawer.free()

	var nothing: EventSheetCardListDrawer = EventSheetCardListDrawer.new({"schema_dict": {"kinds": []}})
	nothing.add_first_kind()
	ok = _eq("a list with no kinds to add adds nothing", nothing.get_value(), []) and ok
	nothing.free()
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
	ok = _tres_round_trip() and ok
	return ok


## A saved prefab opened in the cards editor and saved again is the SAME FILE. This is the contract
## the whole drawer is built around, and the only pin that asks the question in the designer's own
## terms: the bytes on disk.
static func _tres_round_trip() -> bool:
	var path: String = "user://card_list_drawer_test_prefab.tres"
	var prefab: DrawingPrefabResource = DrawingPrefabResource.new()
	prefab.prefab_name = "marker"
	prefab.steps = [
		{"kind": "circle", "x": 0.0, "y": 0.0, "p1": 9.0, "p2": 0.0, "p3": 0.0, "color": "#ffcc00", "texture": ""},
		{"kind": "line", "x": -4.0, "y": 0.0, "p1": 12.0, "p2": 0.0, "p3": 2.0, "color": "red"},
	]
	ResourceSaver.save(prefab, path)
	var before: String = FileAccess.get_file_as_string(path)
	var reopened: DrawingPrefabResource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as DrawingPrefabResource
	var editor: EventSheetDrawingPrefabInspector.ShapeStepsEditor = EventSheetDrawingPrefabInspector.ShapeStepsEditor.new()
	editor.set_steps(reopened.steps)
	reopened.steps = editor.get_steps()
	editor.free()
	ResourceSaver.save(reopened, path)
	var after: String = FileAccess.get_file_as_string(path)
	var ok: bool = _eq("a prefab opened in the cards editor and saved again is the same file", after, before)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
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
