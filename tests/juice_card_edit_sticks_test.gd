# Godot EventSheets - an edit made in a card list stays on the object when the list is a typed array.
#
# A script marked `@tool` runs as a real instance in the editor, so its `Array[Dictionary]` export refuses a plain
# Array: the Inspector wrote the edited list back, the object kept the old cards, and the list drew the old cards
# again one frame later - a card removed from a Juice Player's list came back. The list now hands the object an
# array of the type the object's own property has. A script that is not `@tool` (a placeholder in the editor) and an
# untyped list keep working as they did.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const SCHEMA_PATH := "res://addons/eventsheet/editor/inspector/feedback_card_schema.gd"
const P := "juice_card_edit_sticks_test"


static func _object(typed: bool) -> Object:
	var script: GDScript = GDScript.new()
	script.source_code = "@tool\nextends Node\nvar steps: %s = []\n" % ("Array[Dictionary]" if typed else "Array")
	script.reload()
	var object: Object = script.new()
	var cards: Array[Dictionary] = [{"verb": "shake", "seconds": 0.1}, {"verb": "flash", "seconds": 0.2}, {"verb": "pulse", "seconds": 0.3}, {"verb": "hitstop", "seconds": 0.4}]
	if typed:
		object.set("steps", cards)
	else:
		var plain: Array = []
		plain.assign(cards)
		object.set("steps", plain)
	return object


## A card list wired the way the Inspector wires it: what the list announces is set on the object, as the property
## editor hands it over (through `typed_like`, which fits the list to the property's own type).
static func _drawer(object: Object) -> EventSheetCardListDrawer:
	var spec: Dictionary = {"kind_key": "verb", "schema_dict": (load(SCHEMA_PATH) as GDScript).call("schema")}
	var drawer: EventSheetCardListDrawer = EventSheetCardListDrawer.new(spec)
	drawer.set_value(object.get("steps"))
	drawer.value_changed.connect(func(cards: Array) -> void: object.set("steps", EventSheetCardListDrawer.typed_like(object.get("steps"), cards)))
	return drawer


static func _verbs(object: Object) -> PackedStringArray:
	var verbs: PackedStringArray = PackedStringArray()
	for card: Variant in object.get("steps") as Array:
		verbs.append(str((card as Dictionary).get("verb", "?")))
	return verbs


static func run() -> bool:
	var ok: bool = true
	for typed: bool in [true, false]:
		var word: String = "typed" if typed else "untyped"
		var object: Object = _object(typed)
		var drawer: EventSheetCardListDrawer = _drawer(object)
		drawer.remove_card(1)
		ok = SUPPORT.check(P, word + ": a removed card is gone from the object", _verbs(object), PackedStringArray(["shake", "pulse", "hitstop"])) and ok
		drawer.duplicate_card(0)
		ok = SUPPORT.check(P, word + ": a duplicated card is on the object", _verbs(object), PackedStringArray(["shake", "shake", "pulse", "hitstop"])) and ok
		drawer.move_card(0, 3)
		ok = SUPPORT.check(P, word + ": a moved card is moved on the object", _verbs(object).size(), 4) and ok
		drawer.add_first_kind()
		ok = SUPPORT.check(P, word + ": an added card is on the object", _verbs(object).size(), 5) and ok
		drawer.write_card_key(0, "seconds", 0.77)
		ok = SUPPORT.check(P, word + ": an edited field is on the object", is_equal_approx(float(((object.get("steps") as Array)[0] as Dictionary).get("seconds", 0.0)), 0.77), true) and ok
		var held: Array = object.get("steps")
		ok = SUPPORT.check(P, word + ": the property keeps its type", [held.is_typed(), held.get_typed_builtin()], [typed, TYPE_DICTIONARY if typed else TYPE_NIL]) and ok
		drawer.free()
		object.free()
	# A plain array handed to a typed property is refused by the object (the fault), and an entry that is not a card
	# cannot sit in a typed list, so it is left out rather than refusing the whole edit.
	var typed_object: Object = _object(true)
	typed_object.set("steps", [{"verb": "shake"}])
	ok = SUPPORT.check(P, "a plain array is refused by a typed property", (typed_object.get("steps") as Array).size(), 4) and ok
	typed_object.set("steps", EventSheetCardListDrawer.typed_like(typed_object.get("steps"), [{"verb": "shake"}, 5, {"verb": "flash"}]))
	ok = SUPPORT.check(P, "an entry that is not a card is left out of a typed list", _verbs(typed_object), PackedStringArray(["shake", "flash"])) and ok
	ok = SUPPORT.check(P, "an untyped value is handed back as it came", EventSheetCardListDrawer.typed_like([], [1, 2]), [1, 2]) and ok
	typed_object.free()
	return ok
