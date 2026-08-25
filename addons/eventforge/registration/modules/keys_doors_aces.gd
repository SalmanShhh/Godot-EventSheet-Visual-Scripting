# EventForge module - Keys and doors: the coloured keycard, said as the sheet's list words.
#
# A keycard is a name in a list and a door is a body that wants one of those names. Every project of
# this shape writes the same four lines: `keys.append("red_key")` on the pickup, `if "red_key" in
# keys:` on the prompt, `if not keys.has(needed):` on the door, and a flag so the door that opened
# stays open. Each of those is one row here, in the words a reader already has for a list.
#
# THE DOOR CONTRACT, in full, because a row that calls a method by name owes the reader the name:
# a door is any node carrying
#   * `needs_key`            - the key it wants, as text ("" means it is not locked at all)
#   * `open_door()`          - what it does when the key fits
#   * `locked_door_tried(k)` - what it does when the key does not, which is the On Locked Door Tried
#                              trigger's own function
# Try Door calls those by NAME rather than through a signal, for the same reason Make Noise calls
# `hear` by name: the doors of a level come and go with it and nothing is connected to them. The
# Keycard Door starter writes all three, so a reader who takes the starter never types one.
#
# Everything compiles to plain list operations and plain calls with zero plugin references, which is
# what lets an opened level read back as these rows.
#
# Module contract: see ace_factory.gd - ace_ids/templates are API (compatibility
# covenant); this file only changes where the descriptors are AUTHORED.
@tool
class_name EventForgeKeysDoorsACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

const KEYS := "Keys & Doors"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	_keys(descriptors)
	_doors(descriptors)
	return descriptors


## The three things a key IS: one you picked up, one you hold, and one you are missing. All three
## are the list words, so a reader who already knows Push Back and Contains is not learning a
## second vocabulary - they are reading the one they have, about keys.
static func _keys(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "PickUpKey", "Pick Up Key", ACEDescriptor.ACEType.ACTION,
		"{keys}.append({key})", "", [
			F.make_param("key", "String", "\"red_key\"", "Key", "The key that was picked up, as text.", "expression"),
			F.make_param("keys", "String", "keys", "Keys", "The list holding the keys carried so far.", "variable_reference")
		], KEYS, "Pick up key [b]{key}[/b]")
		.described("Adds a key to the list the player carries. Drop it on the keycard's walked-into trigger, beside the row that takes the card off the floor.").featured())
	descriptors.append(F.make_descriptor("Core", "HasKey", "Has Key", ACEDescriptor.ACEType.CONDITION,
		"({key} in {keys})", "", [
			F.make_param("key", "String", "\"red_key\"", "Key", "The key to look for, as text.", "expression"),
			F.make_param("keys", "String", "keys", "Keys", "The list holding the keys carried so far.", "variable_reference")
		], KEYS, "Has key [b]{key}[/b]")
		.described("True while this key is in the list. The prompt on the door, the lit-up icon on the HUD, the shortcut only a keyholder may take.").featured())
	descriptors.append(F.make_descriptor("Core", "NeedsKey", "Needs Key", ACEDescriptor.ACEType.CONDITION,
		"(not {key} in {keys})", "", [
			F.make_param("key", "String", "\"red_key\"", "Key", "The key that is missing, as text.", "expression"),
			F.make_param("keys", "String", "keys", "Keys", "The list holding the keys carried so far.", "variable_reference")
		], KEYS, "Needs key [b]{key}[/b]")
		.described("True while this key is still missing - the other half of Has Key, so a locked-door hint reads as the sentence it is rather than as a negated test."))
	descriptors.append(F.make_descriptor("Core", "KeysHeld", "Keys Held", ACEDescriptor.ACEType.EXPRESSION,
		"{keys}.size()", "", [
			F.make_param("keys", "String", "keys", "Keys", "The list holding the keys carried so far.", "variable_reference")
		], KEYS, "keys held")
		.described("How many keys the player is carrying - the number a row of HUD key icons counts up to."))


## The door half. Try Door is the whole gesture in one row: the key fits and the door opens, or it
## does not and the door says so. Open Door is what a door does about it, once.
static func _doors(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "TryDoor", "Try Door", ACEDescriptor.ACEType.ACTION, "\n".join(PackedStringArray([
		# The door is held in an untyped local on purpose: `open_door` and `locked_door_tried` are a
		# CONTRACT a door keeps, not methods every Node has, so the call has to be dispatched at run
		# time exactly the way Make Noise dispatches `hear` on its listeners.
		"var __door_{uid} = {door}",
		"if str(__door_{uid}.needs_key) in {keys}:",
		"\t__door_{uid}.open_door()",
		"else:",
		"\t__door_{uid}.locked_door_tried(str(__door_{uid}.needs_key))"
	])), "", [
		F.make_param("door", "String", "self", "Door", "The door being tried.", "expression"),
		F.make_param("keys", "String", "keys", "Keys", "The list holding the keys carried so far.", "variable_reference")
	], KEYS, "Try door [i]{door}[/i] with [b]{keys}[/b]")
		.described("Opens the door when its key is in the list, and tells the door it was refused when it is not. The door decides what refusing looks like - that is its On Locked Door Tried event.").featured())
	descriptors.append(F.make_descriptor("Core", "OpenDoor", "Open Door", ACEDescriptor.ACEType.ACTION, "\n".join(PackedStringArray([
		"if not {opened}:",
		"\t{opened} = true",
		"\tvar __door_{uid} = {door}",
		# Deferred because the row most often runs from inside a body's own collision callback, and
		# the physics server refuses a layer change while it is flushing its queries.
		"\t__door_{uid}.set_deferred(\"collision_layer\", 0)",
		"\tcreate_tween().tween_property(__door_{uid}, \"position\", __door_{uid}.position + {slide}, {seconds})"
	])), "", [
		F.make_param("door", "String", "self", "Door", "The door that opens.", "expression"),
		F.make_param("opened", "String", "door_open", "Opened flag", "The boolean that remembers the door is open, so it opens once however many times it is tried.", "variable_reference"),
		F.make_param("slide", "String", "Vector3(0.0, 3.2, 0.0)", "Slides by", "How far and which way the door moves out of the way.", "expression"),
		F.make_param("seconds", "String", "0.6", "Over seconds", "How long the slide takes.", "expression")
	], KEYS, "Open door [i]{door}[/i] (stays open)")
		.described("Slides the door out of the way, stops it blocking, and leaves it open. The flag is what makes it happen once - walking back through an open door does not re-run the slide.").featured())
	descriptors.append(F.make_descriptor("Core", "OnLockedDoorTried", "On Locked Door Tried",
		ACEDescriptor.ACEType.TRIGGER, "", "locked_door_tried", [], KEYS,
		"On locked door tried")
		.described("Runs on a door that was tried without its key, with the key it wanted. The thud, the red flash, the \"you need the red keycard\" line - all of them go here."))
