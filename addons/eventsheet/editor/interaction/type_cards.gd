# Godot EventSheets - the card a variable's TYPE opens on hover.
#
# Every variable row says its type - int, float, bool, String, an enum, a node or a resource class - and
# every one of those words explains itself: one sentence about what the type is, and the page of
# Godot's own documentation it comes from, so a reader who wants the whole story knows where it lives.
# The sentence is ours and short; the source line is Godot's: the class reference for a built-in type
# and a node or resource class, the GDScript manual for an enum, the project's own script for a class
# it declares.
#
# PURE + STATIC: the sheet it is asked about arrives as an argument, so every word is pinned headless.
@tool
class_name EventSheetTypeCards
extends RefCounted

## How wide the card is, in design pixels.
const CARD_WIDTH: int = 280


## The card for one declared type, in the head card's own shape ({id, title, lines, notes, width,
## anchor}), or {} for a type with nothing to say (an untyped variable, a type nobody can name).
## `sheet` is read only to find an enum the sheet declares by that name.
static func card_for(type_name: String, sheet: EventSheetResource = null) -> Dictionary:
	var wanted: String = type_name.strip_edges()
	if wanted.is_empty() or wanted == "Variant":
		return {}
	var sentence: String = ""
	var source: String = ""
	# A typed array reads "Array[Node2D]": the type is Array, and the card says what is in it.
	if wanted.begins_with("Array[") and wanted.ends_with("]"):
		sentence = EventSheetL10n.translate("A list whose items are all %s. Items are numbered from 0 and the list grows and shrinks as you add and remove.") \
			% wanted.substr(6, wanted.length() - 7)
		source = EventSheetL10n.translate("Godot class reference: Array")
	elif wanted.begins_with("Dictionary[") and wanted.ends_with("]"):
		sentence = EventSheetL10n.translate("A table of keys and values, with the key and value types written in the brackets.")
		source = EventSheetL10n.translate("Godot class reference: Dictionary")
	else:
		sentence = _builtin_sentence(wanted)
		if not sentence.is_empty():
			source = EventSheetL10n.translate("Godot class reference: %s") % wanted
	if sentence.is_empty() and sheet != null:
		var declared: EnumRow = _enum_named(sheet, wanted)
		if declared != null:
			sentence = EventSheetL10n.translate("An enum: one of a fixed set of named values, %s. Under the names they are whole numbers, but the sheet and the code use the names.") \
				% _listed(declared)
			source = EventSheetL10n.translate("Godot manual: GDScript, enums")
	if sentence.is_empty():
		sentence = _class_sentence(wanted)
		if not sentence.is_empty():
			source = EventSheetL10n.translate("Godot class reference: %s") % wanted
	if sentence.is_empty():
		var own: Dictionary = _project_class(wanted)
		if not own.is_empty():
			sentence = EventSheetL10n.translate("A class this project declares, one that extends %s.") % str(own.get("base", "Object"))
			source = EventSheetL10n.translate("This project's own script")
	if sentence.is_empty():
		return {}
	return {
		"id": "type:%s" % wanted,
		"title": wanted,
		"lines": PackedStringArray([sentence]),
		"notes": PackedStringArray([source]),
		"width": CARD_WIDTH,
		"anchor": "left",
	}


## The sentence for a type Godot builds in, "" for anything else. Every string is a literal, so the
## harvest finds each one.
static func _builtin_sentence(type_name: String) -> String:
	match type_name:
		"int":
			return EventSheetL10n.translate("A whole number, positive or negative, with no fraction (a 64-bit signed integer).")
		"float":
			return EventSheetL10n.translate("A number that can have a fraction, like 220.0 or 0.1 (a 64-bit floating-point number).")
		"bool":
			return EventSheetL10n.translate("Either true or false.")
		"String":
			return EventSheetL10n.translate("Text: any run of characters, written between quotes.")
		"StringName":
			return EventSheetL10n.translate("A name Godot compares very quickly, used for things like input actions and animation names.")
		"NodePath":
			return EventSheetL10n.translate("The path to a node in the scene tree, like Player/Sprite2D.")
		"Vector2":
			return EventSheetL10n.translate("Two numbers, x and y: a position, a direction or a size on a 2D plane.")
		"Vector2i":
			return EventSheetL10n.translate("Two whole numbers, x and y: a cell or a pixel on a 2D grid.")
		"Vector3":
			return EventSheetL10n.translate("Three numbers, x, y and z: a position, a direction or a size in 3D space.")
		"Vector3i":
			return EventSheetL10n.translate("Three whole numbers, x, y and z: a cell on a 3D grid.")
		"Vector4":
			return EventSheetL10n.translate("Four numbers, x, y, z and w, used for things like colours and shader values.")
		"Color":
			return EventSheetL10n.translate("A colour: red, green, blue and alpha (see-through), each from 0 to 1.")
		"Rect2":
			return EventSheetL10n.translate("A rectangle on a 2D plane, made of a position and a size.")
		"Transform2D":
			return EventSheetL10n.translate("Where a 2D thing is, how it is turned and how it is scaled, all in one value.")
		"Transform3D":
			return EventSheetL10n.translate("Where a 3D thing is, how it is turned and how it is scaled, all in one value.")
		"Basis":
			return EventSheetL10n.translate("The turn and scale of a 3D thing, without its position.")
		"Quaternion":
			return EventSheetL10n.translate("A 3D rotation stored in a form that does not suffer gimbal lock.")
		"AABB":
			return EventSheetL10n.translate("A box in 3D space aligned to the axes, made of a position and a size.")
		"Plane":
			return EventSheetL10n.translate("A flat surface in 3D space, with a normal and a distance from the origin.")
		"Array":
			return EventSheetL10n.translate("A list of values of any type. Items are numbered from 0 and the list grows and shrinks as you add and remove.")
		"Dictionary":
			return EventSheetL10n.translate("A table of keys and values: look a value up by its key.")
		"Callable":
			return EventSheetL10n.translate("A function that can be stored in a variable and called later.")
		"Signal":
			return EventSheetL10n.translate("A message an object can send, which any other object can listen for.")
		"RID":
			return EventSheetL10n.translate("A low-level handle Godot's servers use to refer to a resource they own.")
		"Object":
			return EventSheetL10n.translate("The base of everything Godot can hold in a variable and call functions on.")
		"PackedStringArray":
			return EventSheetL10n.translate("A compact list of text values.")
		"PackedInt32Array", "PackedInt64Array":
			return EventSheetL10n.translate("A compact list of whole numbers.")
		"PackedFloat32Array", "PackedFloat64Array":
			return EventSheetL10n.translate("A compact list of numbers with fractions.")
		"PackedVector2Array":
			return EventSheetL10n.translate("A compact list of Vector2 values.")
		"PackedVector3Array":
			return EventSheetL10n.translate("A compact list of Vector3 values.")
		"PackedColorArray":
			return EventSheetL10n.translate("A compact list of colours.")
		"PackedByteArray":
			return EventSheetL10n.translate("A compact list of bytes: raw data.")
	return ""


## The sentence for a node or resource class Godot ships, "" for a name that is not one. The class
## it extends is what ClassDB knows, so the sentence says that and nothing it cannot back.
static func _class_sentence(type_name: String) -> String:
	if not ClassDB.class_exists(StringName(type_name)):
		return ""
	var base: String = str(ClassDB.get_parent_class(StringName(type_name)))
	if ClassDB.is_parent_class(StringName(type_name), &"Node"):
		return EventSheetL10n.translate("A %s: a node you place in the scene tree, one that extends %s.") % [type_name, base]
	if ClassDB.is_parent_class(StringName(type_name), &"Resource"):
		return EventSheetL10n.translate("A %s: a resource, a piece of data Godot can save and load, one that extends %s.") % [type_name, base]
	return EventSheetL10n.translate("A %s: an object that extends %s.") % [type_name, base]


static func _enum_named(sheet: EventSheetResource, enum_name: String) -> EnumRow:
	for entry: Variant in sheet.events:
		var row: EnumRow = entry as EnumRow
		if row != null and row.enum_name.strip_edges() == enum_name:
			return row
	return null


## The members of an enum as a sentence's list: "IDLE, RUN or JUMP", with the rest counted.
static func _listed(row: EnumRow) -> String:
	var names: PackedStringArray = PackedStringArray()
	for member: String in row.members:
		names.append(EnumRow.bare_name(member))
	if names.size() <= 4:
		if names.size() == 1:
			return names[0]
		return "%s %s %s" % [", ".join(names.slice(0, names.size() - 1)), EventSheetL10n.translate("or"),
			names[names.size() - 1]]
	return "%s %s" % [", ".join(names.slice(0, 4)), EventSheetL10n.translate("and more")]


## The project's own `class_name` entry by that name, {} when there is none.
static func _project_class(class_name_text: String) -> Dictionary:
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if str(entry.get("class", "")) == class_name_text:
			return entry
	return {}
